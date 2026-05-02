## Represents a single card in the MEXXX Mech Deckbuilder.
## Cards are data Resources assembled into a Deck from equipped Item CardSets.
## Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 15.4
extends Resource
class_name Card

## The human-readable name shown on the card face.
@export var display_name: String = ""

## Action Point cost to play this card.
@export var ap_cost: int = 0

## Broad category of the card (ATTACK, DEFENSE, MOVEMENT, UTILITY, COMBO).
@export var card_type: Enums.CardType = Enums.CardType.UTILITY

## Arbitrary string tags (e.g. "ranged", "ammo", "melee", "aoe").
@export var tags: Array[String] = []

## Drop rarity of the card's source item.
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON

## Ordered list of effects executed when the card is played.
## Typed as Array[Resource] until Effect.gd exists; at runtime these will be Effect instances.
@export var effects: Array[Resource] = []

## The Item this card belongs to; used for ammo tracking and reload logic.
## Typed as Resource until Item.gd exists; at runtime this will be an Item instance.
@export var source_item: Resource = null

## Effective range in tiles (Chebyshev distance). Only meaningful when has_tag("ranged").
@export var range_value: int = 0

## Ammo consumed per play. Only meaningful when has_tag("ammo").
@export var ammo_count: int = 0

func _init() -> void:
	tags = []
	effects = []


## Returns true if this card carries the given tag.
func has_tag(tag: String) -> bool:
	return tag in tags
