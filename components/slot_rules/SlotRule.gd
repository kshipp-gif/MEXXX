## Base class for all SlotRule components.
## SlotRules are Resource subclasses that can be attached to a SlotManager
## to enforce equip constraints in a composable, data-driven way.
## Requirements: 19.2
extends Resource
class_name SlotRule

## Check whether equipping `item` into `slot` is permitted given the current slot state.
## Returns a Dictionary with:
##   "permitted": bool  — true if the equip is allowed
##   "reason":    String — empty string when permitted; a reason code when rejected
func check(slot: String, item: Item, slot_state: Dictionary) -> Dictionary:
	return { "permitted": true, "reason": "" }
