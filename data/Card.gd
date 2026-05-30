## Represents a single card in the MEXXX Mech Deckbuilder.
## Cards are data Resources assembled into a Deck from equipped Item CardSets.
## Tags belong to the source Item, not the card — use source_item.has_tag() for tag checks.
extends Resource
class_name Card

## The human-readable name shown on the card face.
@export var display_name: String = ""

## Action Point cost to play this card.
@export var ap_cost: int = 0

## Broad category of the card (ATTACK, DEFENSE, MOVEMENT, UTILITY, COMBO).
@export var card_type: Enums.CardType = Enums.CardType.UTILITY

## Targeting mode: NOT_TARGETABLE (no selection), TARGETABLE (pick enemy), AOE (pick tile for area).
@export var target_mode: Enums.TargetMode = Enums.TargetMode.NOT_TARGETABLE

## Drop rarity of the card's source item.
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON

## Ordered list of effects executed when the card is played.
@export var effects: Array[Resource] = []

## The Item this card belongs to; used for ammo tracking, tag display, and reload logic.
## Not stored on the Card resource to avoid circular references (Item → CardSet → Card → Item).
## Resolved at runtime by DeckManager and passed through the play context.
var source_item: Item = null

## Effective range in tiles (Chebyshev distance). Only meaningful for ranged items.
@export var range_value: int = 0

## Ammo consumed per play. Only meaningful for ammo-based items.
@export var ammo_count: int = 0

func _init() -> void:
	effects = []
