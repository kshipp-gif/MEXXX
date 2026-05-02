## TwoHandedExclusiveRule enforces two-handed weapon exclusivity:
##
##   • A 2H item cannot be equipped if either arm slot is already occupied.
##   • A 1H item cannot be equipped into an arm slot if a 2H item already
##     occupies both arm slots (i.e., the other arm slot holds the same 2H item).
##
## On rejection, returns { "permitted": false, "reason": "arm_slots_occupied" }.
##
## Requirements: 1.4, 1.5, 1.7
extends SlotRule
class_name TwoHandedExclusiveRule

func check(slot: String, item: Item, slot_state: Dictionary) -> Dictionary:
	# --- 2H equip: reject if either arm slot is occupied ---
	if item.has_tag("2H"):
		var l_arm = slot_state.get("L_Arm")
		var r_arm = slot_state.get("R_Arm")
		if l_arm != null or r_arm != null:
			return { "permitted": false, "reason": "arm_slots_occupied" }
		return { "permitted": true, "reason": "" }

	# --- 1H equip into an arm slot: reject if the other arm holds a 2H item ---
	if item.has_tag("1H") and (slot == "L_Arm" or slot == "R_Arm"):
		var other_slot: String = "R_Arm" if slot == "L_Arm" else "L_Arm"
		var other_item = slot_state.get(other_slot)
		if other_item != null and other_item.has_tag("2H"):
			return { "permitted": false, "reason": "arm_slots_occupied" }

	return { "permitted": true, "reason": "" }
