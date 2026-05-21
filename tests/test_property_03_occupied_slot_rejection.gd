# Feature: mech-deckbuilder-core-systems, Property 3: Occupied slot rejects any equip attempt
# Validates: Requirements 1.3, 1.6
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

		# Equip the first item into L_Arm
		var first_item := make_arm_item("1H")
		var first_equipped: bool = sm.equip("L_Arm", first_item)
		if not first_equipped:
			push_error(
				"FAIL iter %d: initial equip of first item failed unexpectedly"
				% i
			)
			failures += 1
			continue

		# Try to equip a second item into the same occupied slot
		var second_item := make_arm_item("1H")
		var second_equipped: bool = sm.equip("L_Arm", second_item)

		if second_equipped:
			push_error(
				"FAIL iter %d: equip into occupied slot returned true, expected false"
				% i
			)
			failures += 1
			continue

		# The original item must still be in the slot
		var current = sm.get_item("L_Arm")
		if current != first_item:
			push_error(
				"FAIL iter %d: slot contains %s after rejected equip, expected original item"
				% [i, str(current)]
			)
			failures += 1

	if failures == 0:
		print(
			"PASS: Property 3 — Occupied slot rejects any equip attempt (%d iterations)"
			% ITERATIONS
		)
	else:
		push_error("FAIL: Property 3 — %d/%d iterations failed" % [failures, ITERATIONS])
