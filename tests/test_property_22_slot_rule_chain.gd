# Feature: mech-deckbuilder-core-systems, Property 22: SlotRule chain — any rejection blocks equip; unanimous permit allows equip
# Validates: Requirements 19.1, 19.4, 19.5
@tool
extends EditorScript

const ITERATIONS := 100

func make_arm_item(tag: String = "1H") -> Item:
	var item: Item = load("res://data/Item.gd").new()
	item.slot_type = Enums.SlotType.ARM
	item.tags = [tag]
	return item

func make_leg_item() -> Item:
	var item: Item = load("res://data/Item.gd").new()
	item.slot_type = Enums.SlotType.LEG
	item.tags = []
	return item

func _run() -> void:
	var failures := 0

	for i in range(ITERATIONS):
		# --- Case A: Only SlotOccupiedRule, empty slot → equip succeeds ---
		var sm_a: Node = load("res://components/managers/SlotManager.gd").new()
		sm_a.slot_rules = [
			load("res://components/slot_rules/SlotOccupiedRule.gd").new(),
		]
		var item_a := make_arm_item("1H")
		var result_a: bool = sm_a.equip("L_Arm", item_a)
		if not result_a:
			push_error(
				"FAIL iter %d Case A: SlotOccupiedRule only, empty slot — expected equip=true, got false"
				% i
			)
			failures += 1

		# --- Case B: Only SlotOccupiedRule, occupied slot → equip fails ---
		var sm_b: Node = load("res://components/managers/SlotManager.gd").new()
		sm_b.slot_rules = [
			load("res://components/slot_rules/SlotOccupiedRule.gd").new(),
		]
		var first_item_b := make_arm_item("1H")
		sm_b.equip("L_Arm", first_item_b)
		var second_item_b := make_arm_item("1H")
		var result_b: bool = sm_b.equip("L_Arm", second_item_b)
		if result_b:
			push_error(
				"FAIL iter %d Case B: SlotOccupiedRule only, occupied slot — expected equip=false, got true"
				% i
			)
			failures += 1

		# --- Case C: SlotOccupiedRule + SlotTypeRule, both permit (ARM item into L_Arm) → equip succeeds ---
		var sm_c: Node = load("res://components/managers/SlotManager.gd").new()
		sm_c.slot_rules = [
			load("res://components/slot_rules/SlotOccupiedRule.gd").new(),
			load("res://components/slot_rules/SlotTypeRule.gd").new(),
		]
		var item_c := make_arm_item("1H")
		var result_c: bool = sm_c.equip("L_Arm", item_c)
		if not result_c:
			push_error(
				"FAIL iter %d Case C: SlotOccupiedRule+SlotTypeRule, ARM into L_Arm — expected equip=true, got false"
				% i
			)
			failures += 1

		# --- Case D: SlotOccupiedRule (permits) + SlotTypeRule (rejects: LEG item into L_Arm) → equip fails ---
		var sm_d: Node = load("res://components/managers/SlotManager.gd").new()
		sm_d.slot_rules = [
			load("res://components/slot_rules/SlotOccupiedRule.gd").new(),
			load("res://components/slot_rules/SlotTypeRule.gd").new(),
		]
		var item_d := make_leg_item()
		var result_d: bool = sm_d.equip("L_Arm", item_d)
		if result_d:
			push_error(
				"FAIL iter %d Case D: SlotOccupiedRule+SlotTypeRule, LEG into L_Arm — expected equip=false, got true"
				% i
			)
			failures += 1

	if failures == 0:
		print(
			"PASS: Property 22 — SlotRule chain: any rejection blocks equip; unanimous permit allows equip (%d iterations)"
			% ITERATIONS
		)
	else:
		push_error("FAIL: Property 22 — %d/%d iterations failed" % [failures, ITERATIONS])
