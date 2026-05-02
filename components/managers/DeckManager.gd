## DeckManager assembles, shuffles, and manages the three card collections:
## deck, hand, and discard_pile.
## Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8
extends Node

var deck: Array[Card] = []
var hand: Array[Card] = []
var discard_pile: Array[Card] = []

## EventBus instance used for emitting events.
## Defaults to the EventBus autoload; can be overridden in tests with a local instance.
var _event_bus: Node = null

func _ready() -> void:
	_event_bus = EventBus

func _emit(event_name: String, payload: Dictionary) -> void:
	if _event_bus != null:
		_event_bus.emit(event_name, payload)

## Build deck from all equipped non-Head sets; shuffle.
## Skips Head slot and null items. Avoids duplicating 2H items that occupy both arm slots.
func build_deck(slot_manager: Node) -> void:
	deck.clear()
	hand.clear()
	discard_pile.clear()
	var slot_state: Dictionary = slot_manager.get_slot_state()
	var added_items: Array = []  # track item references to avoid 2H duplicates
	for slot_name in slot_state:
		if slot_name == "Head":
			continue
		var item = slot_state[slot_name]
		if item == null:
			continue
		if item.card_set == null:
			continue
		# Avoid duplicating 2H items (same item reference in both arm slots)
		if item in added_items:
			continue
		added_items.append(item)
		for card in item.card_set.cards:
			deck.append(card)
	deck.shuffle()

## Shuffle discard_pile into deck; clear discard_pile.
func recycle_discard() -> void:
	for card in discard_pile:
		deck.append(card)
	deck.shuffle()
	discard_pile.clear()

## Draw n cards from deck to hand; recycle discard if deck runs out.
## Stops early if both deck and discard are empty. Emits hand_updated.
func draw(n: int) -> void:
	for _i in range(n):
		if deck.is_empty():
			if discard_pile.is_empty():
				break  # nothing left to draw
			recycle_discard()
		if not deck.is_empty():
			hand.append(deck.pop_back())
	_emit("hand_updated", { "hand": hand, "deck_size": deck_size(), "discard_size": discard_size() })

## Move a card from hand to discard_pile; emit hand_updated.
func discard_card(card: Card) -> void:
	hand.erase(card)
	discard_pile.append(card)
	_emit("hand_updated", { "hand": hand, "deck_size": deck_size(), "discard_size": discard_size() })

## Move all hand cards to discard_pile; emit hand_updated.
func discard_hand() -> void:
	for card in hand:
		discard_pile.append(card)
	hand.clear()
	_emit("hand_updated", { "hand": hand, "deck_size": deck_size(), "discard_size": discard_size() })

## Return the number of cards in the deck.
func deck_size() -> int:
	return deck.size()

## Return the number of cards in hand.
func hand_size() -> int:
	return hand.size()

## Return the number of cards in the discard pile.
func discard_size() -> int:
	return discard_pile.size()
