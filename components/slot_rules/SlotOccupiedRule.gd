## SlotOccupiedRule rejects any equip attempt into a slot that is already occupied.
## Requirements: 1.3, 1.6, 19.1
extends SlotRule
class_name SlotOccupiedRule

## Returns { "permitted": false, "reason": "slot_occupied" } if the target slot
## already contains an item; otherwise delegates to the base (permitted).
func check(slot: String, item: Item, slot_state: Dictionary) -> Dictionary:
	if slot_state.get(slot) != null:
		return { "permitted": false, "reason": "slot_occupied" }
	return { "permitted": true, "reason": "" }
