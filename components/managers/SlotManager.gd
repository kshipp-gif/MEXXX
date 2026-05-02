## SlotManager manages the Mech's five named Slots and enforces equip rules
## via a composable list of SlotRule resources.
## Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 19.1, 19.3, 19.4, 19.5
extends Node

const SLOT_NAMES := ["L_Arm", "R_Arm", "Legs", "Back", "Head"]

@export var slot_rules: Array = []

## EventBus instance used for emitting events.
## Defaults to the EventBus autoload; can be overridden in tests with a local instance.
var _event_bus: Node = null

func _ready() -> void:
	_event_bus = EventBus

func _emit(event_name: String, payload: Dictionary) -> void:
	if _event_bus != null:
		_event_bus.emit(event_name, payload)

# slot_name -> Item or null
var _slots: Dictionary = {
	"L_Arm": null, "R_Arm": null,
	"Legs":  null, "Back":  null, "Head": null
}

## Attempt to equip an item into a slot.
## Iterates all SlotRules; emits equip_failed and returns false if any rule rejects.
## On success, assigns the item, handles 2H dual-slot assignment, emits slot_changed,
## and returns true.
func equip(slot: String, item: Item) -> bool:
	var slot_state := get_slot_state()
	for rule in slot_rules:
		var result: Dictionary = rule.check(slot, item, slot_state)
		if not result.get("permitted", true):
			_emit("equip_failed", {
				"slot": slot,
				"item": item,
				"reason": result.get("reason", "")
			})
			return false

	# All rules passed — assign the item
	_slots[slot] = item

	# For 2H items, also occupy the other arm slot
	if item.has_tag("2H"):
		_slots["L_Arm"] = item
		_slots["R_Arm"] = item

	_emit("slot_changed", { "slot": slot, "item": item })
	return true

## Unequip the item from a slot.
## Clears both arm slots if the item is 2H; otherwise clears only the given slot.
## Emits slot_changed with item: null.
func unequip(slot: String) -> void:
	var item = _slots.get(slot)
	if item != null and item.has_tag("2H"):
		# Clear both arm slots for 2H items
		_slots["L_Arm"] = null
		_slots["R_Arm"] = null
	else:
		_slots[slot] = null
	_emit("slot_changed", { "slot": slot, "item": null })

## Return the item in a slot, or null if the slot is empty.
func get_item(slot: String) -> Item:
	return _slots.get(slot)

## Return a snapshot of all slots (used by SlotRules).
func get_slot_state() -> Dictionary:
	return _slots.duplicate()
