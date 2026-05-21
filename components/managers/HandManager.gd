## HandManager — tracks the player's hand and manages card playability.
## Subscribes to ap_changed on EventBus to refresh playability whenever AP changes.
## Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 10.2, 10.5
extends Node

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
	# Execute effects in order, passing the full effects list and current index into context.
	var context: Dictionary = {
		"caster": self,
		"ap_manager": ap_manager,
		"deck_manager": deck_manager,
		"event_bus": EventBus,
		"card_effects": card.effects,
	}
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
