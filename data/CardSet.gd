## Represents a set of cards associated with an equipped Item in the MEXXX Mech Deckbuilder.
## CardSets are contributed to the player's Deck when their source Item is equipped.
## Requirements: 2.4, 4.1
## Note: Each CardSet must contain a minimum of 5 cards per design spec.
extends Resource
class_name CardSet

@export var cards: Array[Card] = []

func _init() -> void:
	cards = []
