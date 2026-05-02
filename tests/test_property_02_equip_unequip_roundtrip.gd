# Feature: mech-deckbuilder-core-systems, Property 2: Equipping then querying a slot returns the same item (round-trip)
# Validates: Requirements 1.8, 1.9
@tool
extends EditorScript

const ITERATIONS := 100

func make_arm_item(tag: String = "1H") -> Item:
	var item: Item = load("res://data/Item.gd").new()
	item.slot_type = Enums.SlotType.ARM
	item.tags = [tag]
	return item

func make_slot_manager() -> Node:
	var sm: Node = load("res://components/managers/SlotManager.gd").new()
	sm.slot_rules = [
		load("res://components/slot_rules/SlotOccupiedRule.gd").new(),
		load("res://components/slot_rules/SlotTypeRule.gd").new(),
		load("res://components/slot_rules/TwoHandedExclusiveRule.gd").new(),
	]
	return sm

func _run() -> void:
	var failures := 0

	for i in range(ITERATIONS):
		var sm := make_slot_manager()
		var item := make_arm_item("1H")

		# Equip into L_Arm
		var equipped: bool = sm.equip("L_Arm", item)
		if not equipped:
			push_error(
				"FAIL iter %d: equip returned false for a valid ARM 1H item into empty L_Arm"
				% i
			)
			failures += 1
			continue

		# get_item should return the exact same item
		var retrieved = sm.get_item("L_Arm")
		if retrieved != item:
			push_error(
				"FAIL iter %d: get_item('L_Arm') returned %s, expected the equipped item"
				% [i, str(retrieved)]
			)
			failures += 1
			continue

		# Unequip
		sm.unequip("L_Arm")

		# get_item should now return null
		var after_unequip = sm.get_item("L_Arm")
		if after_unequip != null:
			push_error(
				"FAIL iter %d: get_item('L_Arm') returned %s after unequip, expected null"
				% [i, str(after_unequip)]
			)
			failures += 1

	if failures == 0:
		print(
			"PASS: Property 2 — Equip/unequip round-trip (%d iterations)"
			% ITERATIONS
		)
	else:
		push_error("FAIL: Property 2 — %d/%d iterations failed" % [failures, ITERATIONS])
