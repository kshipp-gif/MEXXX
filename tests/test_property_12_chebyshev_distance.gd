# Feature: mech-deckbuilder-core-systems, Property 12: Chebyshev distance is symmetric and correct
# Validates: Requirements 7.6
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		var bm: Node = load("res://components/managers/BattlefieldManager.gd").new()

		var ax: int = rng.randi_range(-20, 20)
		var ay: int = rng.randi_range(-20, 20)
		var bx: int = rng.randi_range(-20, 20)
		var by: int = rng.randi_range(-20, 20)
		var a := Vector2i(ax, ay)
		var b := Vector2i(bx, by)

		var dist_ab: int = bm.tile_distance(a, b)
		var dist_ba: int = bm.tile_distance(b, a)
		if dist_ab != dist_ba:
			push_error(
				"FAIL iter %d (symmetry): tile_distance(%s, %s)=%d != tile_distance(%s, %s)=%d"
				% [i, a, b, dist_ab, b, a, dist_ba]
			)
			failures += 1

		var expected: int = max(abs(ax - bx), abs(ay - by))
		if dist_ab != expected:
			push_error(
				"FAIL iter %d (correctness): tile_distance(%s, %s)=%d, expected %d"
				% [i, a, b, dist_ab, expected]
			)
			failures += 1

		var dist_aa: int = bm.tile_distance(a, a)
		if dist_aa != 0:
			push_error(
				"FAIL iter %d (reflexivity): tile_distance(%s, %s)=%d, expected 0"
				% [i, a, a, dist_aa]
			)
			failures += 1

		bm.free()

	if failures == 0:
		print("PASS: Property 12 — Chebyshev distance is symmetric and correct (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 12 — %d/%d iterations failed" % [failures, ITERATIONS])
