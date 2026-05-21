## Represents an equippable Item in the MEXXX Mech Deckbuilder.
## Items are equipped into Mech Slots and may contribute a CardSet to the Deck.
extends Resource
class_name Item

@export var id: StringName = ""
@export var display_name: String = ""
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON
@export var slot_type: Enums.SlotType = Enums.SlotType.ARM
@export var tags: Array[String] = []          # includes "1H" or "2H"
@export var passives: Array[Resource] = []    # Array[Passive] — typed as Resource until Passive exists
@export var card_set: CardSet = null          # null for Head items
@export var max_ammo: int = 0                 # 0 = not ammo-based
@export var flavor_text: String = ""          # Lore/flavor text shown in the card inspect panel
var current_ammo: int = 0

signal ammo_changed(item_id: StringName, current: int, maximum: int)

func _init() -> void:
	tags = []
	passives = []

## Returns true if this item has the given tag.
func has_tag(tag: String) -> bool:
	return tag in tags

## Decrements current ammo by 1 (floor 0) and emits ammo_changed.
func decrement_ammo() -> void:
	current_ammo = max(0, current_ammo - 1)
	ammo_changed.emit(id, current_ammo, max_ammo)

## Restores current ammo to max_ammo and emits ammo_changed.
func reload_ammo() -> void:
	current_ammo = max_ammo
	ammo_changed.emit(id, current_ammo, max_ammo)
