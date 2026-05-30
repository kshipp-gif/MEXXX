## HandManager — tracks the player's hand and manages card playability.
## Subscribes to ap_changed on EventBus to refresh playability whenever AP changes.
extends Node

const MultiTileEffect = preload("res://components/effects/MultiTileEffect.gd")

var deck_manager: Node = null
var ap_manager: Node = null
var battlefield_manager: Node = null
var mech: Node = null

var _current_ap: int = 0
var _hand_size: int = 5  # configurable hand size
var _playing_card: bool = false  # prevents double-play during tile selection

func _ready() -> void:
	EventBus.subscribe("ap_changed", _on_ap_changed)
	EventBus.subscribe("turn_started", on_turn_started)
	EventBus.subscribe("card_play_requested", _on_card_play_requested)

func _exit_tree() -> void:
	EventBus.unsubscribe("ap_changed", _on_ap_changed)
	EventBus.unsubscribe("turn_started", on_turn_started)
	EventBus.unsubscribe("card_play_requested", _on_card_play_requested)

func _on_ap_changed(payload: Dictionary) -> void:
	_current_ap = payload.get("current_ap", 0)

## Handle card play request from the UI (drag-to-play).
## If the payload includes "target" and "target_pos", the card is played directly
## against that target without prompting for tile selection.
func _on_card_play_requested(payload: Dictionary) -> void:
	if _playing_card:
		return  # already playing a card (waiting for tile selection)
	var card: Card = payload.get("card") as Card
	if card == null:
		print("HandManager: card_play_requested but card is null")
		return
	print("HandManager: attempting to play '%s' (ap_cost=%d)" % [card.display_name, card.ap_cost])
	_playing_card = true

	# If the UI already resolved a target (drag-to-enemy targeting), use it directly.
	var pre_resolved_target: Node = payload.get("target") as Node
	var pre_resolved_pos = payload.get("target_pos")

	if pre_resolved_target != null and pre_resolved_pos != null:
		var result: bool = play_card_on_target(card, pre_resolved_target, pre_resolved_pos as Vector2i)
		_playing_card = false
		print("HandManager: play_card_on_target returned %s" % str(result))
	else:
		var result = await play_card(card)
		_playing_card = false
		print("HandManager: play_card returned %s" % str(result))

## Called at turn start; requests draw from DeckManager if this is the player's turn.
func on_turn_started(payload: Dictionary) -> void:
	if payload.get("owner", "") == "player":
		if deck_manager != null:
			deck_manager.draw(_hand_size)

## Attempt to play a card; checks AP and ammo; executes effects; emits card_played.
## Returns true if the card was played successfully, false otherwise.
func play_card(card: Card) -> bool:
	if ap_manager == null:
		print("  play_card FAIL: ap_manager is null")
		return false
	# Check AP — spend returns false and emits action_rejected if insufficient
	if not ap_manager.spend(card.ap_cost):
		print("  play_card FAIL: not enough AP (need %d)" % card.ap_cost)
		return false
	# Check ammo — if the source item is ammo-based and depleted, refund and reject
	var source_item: Item = card.source_item as Item
	if source_item != null and source_item.has_tag("ammo"):
		if source_item.max_ammo > 0 and source_item.current_ammo <= 0:
			print("  play_card FAIL: ammo depleted")
			ap_manager.grant(card.ap_cost)
			return false
		if source_item.max_ammo > 0:
			source_item.decrement_ammo()
	
	# Build base context with all required keys for multi-tile effects
	var context: Dictionary = {
		"caster": mech,
		"ap_manager": ap_manager,
		"deck_manager": deck_manager,
		"event_bus": EventBus,
		"card_effects": card.effects,
		"source_item": source_item,
		"caster_id": &"mech",
		"battlefield_manager": battlefield_manager
	}
	
	# Determine what selections are needed based on card flags and effects.
	var needs_movement: bool = false
	for effect in card.effects:
		if effect is MoveEffect:
			needs_movement = true
			break

	# Handle selections in effect order.
	# Walk through effects to determine prompt order.
	var target_prompted: bool = false
	var movement_prompted: bool = false

	for effect in card.effects:
		# If we hit a damage/status effect and card is TARGETABLE, prompt for target.
		if not target_prompted and card.target_mode == Enums.TargetMode.TARGETABLE:
			if effect is DamageEffect or effect is MultiHitDamageEffect or effect is ScalingDamageEffect or effect is StackDamageEffect or effect is ThresholdDamageEffect or effect is MultiHitStatusEffect or (effect is ApplyStatusEffect and effect.target_type == "target"):
				var selected_tile: Vector2i = await _prompt_target_selection(context)
				if selected_tile == Vector2i(-1, -1):
					ap_manager.grant(card.ap_cost)
					return false
				var target_node: Node = battlefield_manager.get_unit_node_at(selected_tile)
				if target_node != null:
					context["target"] = target_node
					context["target_pos"] = selected_tile
				target_prompted = true

		# If we hit a MoveEffect, prompt for movement tile.
		if not movement_prompted and effect is MoveEffect:
			var move_tile: Vector2i = await _prompt_tile_selection(card, context)
			if move_tile == Vector2i(-1, -1):
				ap_manager.grant(card.ap_cost)
				return false
			context["target_pos"] = move_tile
			movement_prompted = true

	# AOE mode: prompt for tile placement (ranged multi-tile effects).
	if card.target_mode == Enums.TargetMode.AOE:
		var selected_tile: Vector2i = await _prompt_tile_selection(card, context)
		if selected_tile == Vector2i(-1, -1):
			ap_manager.grant(card.ap_cost)
			if source_item != null and source_item.has_tag("ammo") and source_item.max_ammo > 0:
				source_item.current_ammo += 1
				source_item.ammo_changed.emit(source_item.id, source_item.current_ammo, source_item.max_ammo)
			return false
		context["origin_tile"] = selected_tile
		context["target_pos"] = selected_tile
	
	# Execute effects in order
	for i in range(card.effects.size()):
		context["current_effect_index"] = i
		card.effects[i].execute(context)
	# Discard the card from hand
	if deck_manager != null:
		deck_manager.discard_card(card)
	EventBus.emit("card_played", { "card": card, "playable": true })
	return true

## Play a card directly against a pre-resolved target (used by drag-to-enemy targeting).
## Skips the tile selection prompt since the target is already known.
## Returns true if the card was played successfully, false otherwise.
func play_card_on_target(card: Card, target_node: Node, target_pos: Vector2i) -> bool:
	if ap_manager == null:
		print("  play_card_on_target FAIL: ap_manager is null")
		return false
	# Check AP
	if not ap_manager.spend(card.ap_cost):
		print("  play_card_on_target FAIL: not enough AP (need %d)" % card.ap_cost)
		return false
	# Check ammo
	var source_item: Item = card.source_item as Item
	if source_item != null and source_item.has_tag("ammo"):
		if source_item.max_ammo > 0 and source_item.current_ammo <= 0:
			print("  play_card_on_target FAIL: ammo depleted")
			ap_manager.grant(card.ap_cost)
			return false
		if source_item.max_ammo > 0:
			source_item.decrement_ammo()

	# Build context with the pre-resolved target.
	var context: Dictionary = {
		"caster": mech,
		"target": target_node,
		"target_pos": target_pos,
		"ap_manager": ap_manager,
		"deck_manager": deck_manager,
		"event_bus": EventBus,
		"card_effects": card.effects,
		"source_item": source_item,
		"caster_id": &"mech",
		"battlefield_manager": battlefield_manager
	}

	# Execute effects in order.
	for i in range(card.effects.size()):
		context["current_effect_index"] = i
		card.effects[i].execute(context)

	# Discard the card from hand.
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

	# For movement cards, also validate the tile is unoccupied
	var has_move_effect: bool = false
	for effect in card.effects:
		if effect is MoveEffect:
			has_move_effect = true
			break
	if has_move_effect and not battlefield.is_tile_free(selected_tile):
		EventBus.emit("tile_selection_rejected", { "reason": "tile_occupied" })
		return await _prompt_tile_selection(card, context)

	# Valid selection - emit completion event and return
	EventBus.emit("tile_selection_completed", { "tile": selected_tile })
	return selected_tile

## Wait for the UI to emit a tile_selected or tile_selection_cancelled event.
## Returns the selected tile, or Vector2i(-1, -1) if cancelled.
func _wait_for_tile_selection() -> Vector2i:
	var state: Array = [false, Vector2i(-1, -1)]  # [resolved, result]

	var on_selected := func(payload: Dictionary) -> void:
		state[1] = payload.get("tile", Vector2i(-1, -1))
		state[0] = true
		print("  _wait_for_tile_selection: received tile_selected, tile=%s" % str(state[1]))

	var on_cancelled := func(_payload: Dictionary) -> void:
		state[1] = Vector2i(-1, -1)
		state[0] = true
		print("  _wait_for_tile_selection: received tile_selection_cancelled")

	EventBus.subscribe("tile_selected", on_selected)
	EventBus.subscribe("tile_selection_cancelled", on_cancelled)

	print("  _wait_for_tile_selection: waiting for tile_selected or tile_selection_cancelled...")

	while not state[0]:
		await get_tree().process_frame

	EventBus.unsubscribe("tile_selected", on_selected)
	EventBus.unsubscribe("tile_selection_cancelled", on_cancelled)
	print("  _wait_for_tile_selection: resolved with %s" % str(state[1]))
	return state[1]

## Prompt the player to select an enemy target.
## Emits target_selection_started so the grid highlights enemy tiles.
## Returns the selected tile, or Vector2i(-1, -1) if cancelled.
func _prompt_target_selection(context: Dictionary) -> Vector2i:
	var caster_pos: Vector2i = battlefield_manager.get_position(context["caster_id"])

	# Emit event so BattlefieldGrid highlights enemy tiles.
	EventBus.emit("target_selection_started", {
		"caster_pos": caster_pos
	})

	# Wait for player to click an enemy tile.
	var selected_tile: Vector2i = await _wait_for_tile_selection()

	if selected_tile == Vector2i(-1, -1):
		EventBus.emit("tile_selection_cancelled", {})
		return selected_tile

	# Validate that the selected tile has an enemy on it.
	var unit_id: StringName = battlefield_manager.get_unit_at(selected_tile)
	if unit_id == &"" or unit_id == &"mech":
		# Not a valid enemy — retry.
		EventBus.emit("tile_selection_rejected", { "reason": "no_enemy" })
		return await _prompt_target_selection(context)

	EventBus.emit("tile_selection_completed", { "tile": selected_tile })
	return selected_tile
