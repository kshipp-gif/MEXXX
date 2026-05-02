# Feature: mech-deckbuilder-core-systems, Property 14: Range validation matches Chebyshev distance
# Validates: Requirements 7.7, 7.8
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		var bm: Node = load("res://components/managers/BattlefieldManager.gd").new()

		var caster_id: StringName = &"caster"
		var caster_pos := Vector2i(rng.randi_range(0, 7), rng.randi_range(0, 5))
		bm.place_unit(caster_id, caster_pos)

		var target := Vector2i(rng.randi_range(0, 7), rng.randi_range(0, 5))
		var range_val: int = rng.randi_range(0, 8)

		var dist: int = bm.tile_distance(caster_pos, target)
		var expected_result: bool = dist <= range_val

		var actual_result: bool = bm.validate_range(caster_id, target, range_val)

		if actual_result != expected_result:
			push_error(
				"FAIL iter %d: validate_range(caster=%s, target=%s, range=%d) returned %s, expected %s (dist=%d)"
				% [i, caster_pos, target, range_val, actual_result, expected_result, dist]
			)
			failures += 1

		bm.free()

	if failures == 0:
		print("PASS: Property 14 — Range validation matches Chebyshev distance (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 14 — %d/%d iterations failed" % [failures, ITERATIONS])
