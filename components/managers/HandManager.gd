## HandManager — tracks the player's hand and manages card playability.
## Subscribes to ap_changed on EventBus to refresh playability whenever AP changes.
extends Node

const MultiTileEffect = preload("res://components/effects/MultiTileEffect.gd")

var deck_manager: Node = null
var ap_manager: Node = null

var _current_ap: int = 0
var _hand_size: int = 5  # configurable hand size

func _ready() -> void:
	EventBus.subscribe("ap_changed", _on_ap_changed)
	EventBus.subscribe("turn_started", on_turn_started)

func _exit_tree() -> void:
	EventBus.unsubscribe("ap_changed", _on_ap_changed)
	EventBus.unsubscribe("turn_started", on_turn_started)

func _on_ap_changed(payload: Dictionary) -> void:
	_current_ap = payload.get("current_ap", 0)

## Called at turn start; requests draw from DeckManager if this is the player's turn.
func on_turn_started(payload: Dictionary) -> void:
	if payload.get("owner", "") == "player":
		if deck_manager != null:
			deck_manager.draw(_hand_size)

## Attempt to play a card; checks AP and ammo; executes effects; emits card_played.
## Returns true if the card was played successfully, false otherwise.
func play_card(card: Card) -> bool:
	if ap_manager == null:
		return false
	# Check AP — spend returns false and emits action_rejected if insufficient
	if not ap_manager.spend(card.ap_cost):
		return false
	# Check ammo — if the source item is ammo-based and depleted, refund and reject
	var source_item: Item = card.source_item as Item
	if source_item != null and source_item.has_tag("ammo"):
		if source_item.max_ammo > 0 and source_item.current_ammo <= 0:
			ap_manager.grant(card.ap_cost)
			return false
		if source_item.max_ammo > 0:
			source_item.decrement_ammo()
	
	# Build base context with all required keys for multi-tile effects
	var context: Dictionary = {
		"caster": self,
		"ap_manager": ap_manager,
		"deck_manager": deck_manager,
		"event_bus": EventBus,
		"card_effects": card.effects,
		"source_item": source_item,
		"caster_id": &"player",
		"battlefield_manager": get_node("/root/CombatScene/BattlefieldManager")
	}
	
	# Check if card has ranged multi-tile effects that need tile selection
	var needs_tile_selection: bool = false
	if source_item != null and source_item.has_tag("ranged"):
		for effect in card.effects:
			if effect is MultiTileEffect:
				needs_tile_selection = true
				break
	
	# If ranged multi-tile, prompt tile selection
	if needs_tile_selection:
		var selected_tile: Vector2i = await _prompt_tile_selection(card, context)
		if selected_tile == Vector2i(-1, -1):
			# Selection cancelled — refund resources
			ap_manager.grant(card.ap_cost)
			if source_item != null and source_item.has_tag("ammo") and source_item.max_ammo > 0:
				source_item.current_ammo += 1
				source_item.ammo_changed.emit(source_item.id, source_item.current_ammo, source_item.max_ammo)
			return false
		context["origin_tile"] = selected_tile
	
	# Execute effects in order
	for i in range(card.effects.size()):
		context["current_effect_index"] = i
		card.effects[i].execute(context)
	# Discard the card from hand
	if deck_manager != null:
		deck_manager.discard_card(card)
	EventBus.emit("card_played", { "card": card, "playable": true })
	return true

## Discard remaining hand at turn end.
func end_turn() -> void:
	if deck_manager != null:
		deck_manager.discard_hand()

## Returns cards in hand that are currently playable (AP sufficient and ammo available).
func get_playable_cards() -> Array[Card]:
	if deck_manager == null:
		return []
	var playable: Array[Card] = []
	for card in deck_manager.hand:
		if card.ap_cost > _current_ap:
			continue
		var item: Item = card.source_item as Item
		if item != null and item.has_tag("ammo") and item.max_ammo > 0 and item.current_ammo <= 0:
			continue  # ammo depleted
		playable.append(card)
	return playable

## Prompt the player to select a target tile for a ranged multi-tile effect.
## Validates range and bounds, retrying on rejection.
## Returns the selected tile, or Vector2i(-1, -1) if cancelled.
func _prompt_tile_selection(card: Card, context: Dictionary) -> Vector2i:
	var battlefield: Node = context["battlefield_manager"]
	var caster_pos: Vector2i = battlefield.get_position(context["caster_id"])
	
	# Emit event to show tile selection UI
	EventBus.emit("tile_selection_started", {
		"range": card.range_value,
		"caster_pos": caster_pos
	})
	
	# Wait for player to select a tile (UI emits tile_selected event)
	var selected_tile: Vector2i = await _wait_for_tile_selection()
	
	# Check if selection was cancelled
	if selected_tile == Vector2i(-1, -1):
		return selected_tile
	
	# Validate bounds first (x in [0, grid_width), y in [0, grid_height))
	if selected_tile.x < 0 or selected_tile.x >= battlefield.grid_width:
		EventBus.emit("tile_selection_rejected", { "reason": "out_of_bounds" })
		return await _prompt_tile_selection(card, context)
	if selected_tile.y < 0 or selected_tile.y >= battlefield.grid_height:
		EventBus.emit("tile_selection_rejected", { "reason": "out_of_bounds" })
		return await _prompt_tile_selection(card, context)
	
	# Validate range using Chebyshev distance
	if not battlefield.validate_range(context["caster_id"], selected_tile, card.range_value):
		# validate_range already emits action_rejected, but we need tile_selection_rejected
		EventBus.emit("tile_selection_rejected", { "reason": "out_of_range" })
		return await _prompt_tile_selection(card, context)
	
	# Valid selection - emit completion event and return
	EventBus.emit("tile_selection_completed", { "tile": selected_tile })
	return selected_tile

## Wait for the UI to emit a tile_selected event.
## Returns the selected tile, or Vector2i(-1, -1) if cancelled.
## TODO: This is a placeholder implementation. The actual implementation should:
##   - Listen for "tile_selected" event from EventBus with payload { "tile": Vector2i }
##   - Listen for "tile_selection_cancelled" event from EventBus
##   - Return the selected tile when "tile_selected" is emitted
##   - Return Vector2i(-1, -1) when "tile_selection_cancelled" is emitted
func _wait_for_tile_selection() -> Vector2i:
	# Placeholder: wait briefly and return cancellation signal
	await get_tree().create_timer(0.1).timeout
	return Vector2i(-1, -1)
