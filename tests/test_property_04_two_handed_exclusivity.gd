# Feature: mech-deckbuilder-core-systems, Property 4: 2H item occupies both arm slots; 2H equip fails if either arm is occupied
# Validates: Requirements 1.4, 1.7
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
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		# --- Case A: Both arms empty → equip 2H → both slots occupied by that item ---
		var sm_a := make_slot_manager()
		var two_h_item := make_arm_item("2H")

		var equipped_a: bool = sm_a.equip("L_Arm", two_h_item)
		if not equipped_a:
			push_error(
				"FAIL iter %d Case A: equip 2H into empty arms returned false, expected true"
				% i
			)
			failures += 1
		else:
			var l_arm = sm_a.get_item("L_Arm")
			var r_arm = sm_a.get_item("R_Arm")
			if l_arm != two_h_item:
				push_error(
					"FAIL iter %d Case A: L_Arm contains %s, expected 2H item"
					% [i, str(l_arm)]
				)
				failures += 1
			if r_arm != two_h_item:
				push_error(
					"FAIL iter %d Case A: R_Arm contains %s, expected 2H item"
					% [i, str(r_arm)]
				)
				failures += 1

		# --- Case B: One arm occupied → equip 2H → must fail ---
		var sm_b := make_slot_manager()
		var blocking_item := make_arm_item("1H")
		var occupied_slot: String = "L_Arm" if rng.randi_range(0, 1) == 0 else "R_Arm"
		sm_b.equip(occupied_slot, blocking_item)

		var two_h_item_b := make_arm_item("2H")
		var free_slot: String = "R_Arm" if occupied_slot == "L_Arm" else "L_Arm"
		var equipped_b: bool = sm_b.equip(free_slot, two_h_item_b)
		if equipped_b:
			push_error(
				"FAIL iter %d Case B: equip 2H with %s occupied returned true, expected false"
				% [i, occupied_slot]
			)
			failures += 1

	if failures == 0:
		print(
			"PASS: Property 4 — 2H item occupies both arm slots; 2H equip fails if either arm is occupied (%d iterations)"
			% ITERATIONS
		)
	else:
		push_error("FAIL: Property 4 — %d/%d iterations failed" % [failures, ITERATIONS])
