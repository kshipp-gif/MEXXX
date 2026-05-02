# Feature: mech-deckbuilder-core-systems, Property 23: SlotTypeRule rejects items equipped into the wrong slot type
# Validates: Requirements 1.2, 19.6
@tool
extends EditorScript

const ITERATIONS := 100

const SLOT_TYPE_MAP: Dictionary = {
	"L_Arm": Enums.SlotType.ARM,
	"R_Arm": Enums.SlotType.ARM,
	"Legs":  Enums.SlotType.LEG,
	"Back":  Enums.SlotType.BACK,
	"Head":  Enums.SlotType.HEAD,
}

const ALL_SLOTS: Array = ["L_Arm", "R_Arm", "Legs", "Back", "Head"]
const ALL_TYPES: Array = [
	Enums.SlotType.ARM,
	Enums.SlotType.LEG,
	Enums.SlotType.BACK,
	Enums.SlotType.HEAD,
]

func _run() -> void:
	var rule: Resource = load("res://components/slot_rules/SlotTypeRule.gd").new()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	var slot_state: Dictionary = {
		"L_Arm": null, "R_Arm": null,
		"Legs": null, "Back": null, "Head": null,
	}

	for i in range(ITERATIONS):
		var slot: String = ALL_SLOTS[rng.randi_range(0, ALL_SLOTS.size() - 1)]
		var item_type: Enums.SlotType = ALL_TYPES[rng.randi_range(0, ALL_TYPES.size() - 1)]

		var item: Item = load("res://data/Item.gd").new()
		item.slot_type = item_type

		var expected_type: Enums.SlotType = SLOT_TYPE_MAP[slot]
		var result: Dictionary = rule.check(slot, item, slot_state)

		if item_type == expected_type:
			if not result.get("permitted", false):
				push_error(
					"FAIL iter %d: slot=%s item_type=%d (matches) — expected permitted=true, got %s"
					% [i, slot, item_type, str(result)]
				)
				failures += 1
		else:
			if result.get("permitted", true):
				push_error(
					"FAIL iter %d: slot=%s item_type=%d expected_type=%d — expected permitted=false, got %s"
					% [i, slot, item_type, expected_type, str(result)]
				)
				failures += 1
			elif result.get("reason", "") != "slot_type_mismatch":
				push_error(
					"FAIL iter %d: slot=%s item_type=%d — expected reason='slot_type_mismatch', got '%s'"
					% [i, slot, item_type, result.get("reason", "")]
				)
				failures += 1

	if failures == 0:
		print(
			"PASS: Property 23 — SlotTypeRule rejects items equipped into the wrong slot type (%d iterations)"
			% ITERATIONS
		)
	else:
		push_error("FAIL: Property 23 — %d/%d iterations failed" % [failures, ITERATIONS])
