# Feature: mech-deckbuilder-core-systems, Property 1: Slot set is always exactly the five named slots
# Validates: Requirements 1.1
@tool
extends EditorScript

const ITERATIONS := 100
const EXPECTED_SLOTS: Array = ["Back", "Head", "L_Arm", "Legs", "R_Arm"]  # sorted

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
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	# All valid slots and their matching item types for random operations
	const SLOT_NAMES: Array = ["L_Arm", "R_Arm", "Legs", "Back", "Head"]

	for i in range(ITERATIONS):
		var sm := make_slot_manager()

		# Perform 0–10 random equip/unequip operations
		var ops := rng.randi_range(0, 10)
		for _op in range(ops):
			var slot: String = SLOT_NAMES[rng.randi_range(0, SLOT_NAMES.size() - 1)]
			if rng.randi_range(0, 1) == 0:
				# equip: create an item matching the slot type
				var item: Item = load("res://data/Item.gd").new()
				match slot:
					"L_Arm", "R_Arm":
						item.slot_type = Enums.SlotType.ARM
						item.tags = ["1H"]
					"Legs":
						item.slot_type = Enums.SlotType.LEG
					"Back":
						item.slot_type = Enums.SlotType.BACK
					"Head":
						item.slot_type = Enums.SlotType.HEAD
				sm.equip(slot, item)
			else:
				# unequip
				sm.unequip(slot)

		# Assert the slot set is exactly the five named slots
		var state: Dictionary = sm.get_slot_state()
		var keys: Array = state.keys()
		keys.sort()

		if keys != EXPECTED_SLOTS:
			push_error(
				"FAIL iter %d: expected keys %s, got %s"
				% [i, str(EXPECTED_SLOTS), str(keys)]
			)
			failures += 1

	if failures == 0:
		print(
			"PASS: Property 1 — Slot set is always exactly the five named slots (%d iterations)"
			% ITERATIONS
		)
	else:
		push_error("FAIL: Property 1 — %d/%d iterations failed" % [failures, ITERATIONS])
