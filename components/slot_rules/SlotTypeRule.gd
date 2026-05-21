## SlotTypeRule rejects equip attempts where the item's slot_type does not match
## the expected type for the target slot.
##
## Slot → expected SlotType mapping:
##   L_Arm, R_Arm → Enums.SlotType.ARM
##   Legs         → Enums.SlotType.LEG
##   Back         → Enums.SlotType.BACK
##   Head         → Enums.SlotType.HEAD
##
extends SlotRule
class_name SlotTypeRule

## Maps each named slot to its required SlotType enum value.
const SLOT_TYPE_MAP: Dictionary = {
	"L_Arm": Enums.SlotType.ARM,
	"R_Arm": Enums.SlotType.ARM,
	"Legs":  Enums.SlotType.LEG,
	"Back":  Enums.SlotType.BACK,
	"Head":  Enums.SlotType.HEAD,
}

## Returns { "permitted": false, "reason": "slot_type_mismatch" } when the item's
## slot_type does not match the expected type for the given slot; otherwise permitted.
func check(slot: String, item: Item, slot_state: Dictionary) -> Dictionary:
	if not SLOT_TYPE_MAP.has(slot):
		# Unknown slot — permit and let other rules handle it.
		return { "permitted": true, "reason": "" }

	var expected_type: Enums.SlotType = SLOT_TYPE_MAP[slot]
	if item.slot_type != expected_type:
		return { "permitted": false, "reason": "slot_type_mismatch" }

	return { "permitted": true, "reason": "" }
