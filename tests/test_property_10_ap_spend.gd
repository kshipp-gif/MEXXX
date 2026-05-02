# Feature: mech-deckbuilder-core-systems, Property 10: AP spend is exact and rejects insufficient funds
# Validates: Requirements 6.2, 6.3, 6.4, 6.5
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		var ap: Node = load("res://components/managers/APManager.gd").new()

		var max_val: int = rng.randi_range(1, 10)
		ap.max_ap = max_val
		ap.current_ap = rng.randi_range(0, max_val)

		var starting_ap: int = ap.current_ap

		# --- Case A: spend(amount) where amount <= current_ap ---
		var affordable_cost: int = rng.randi_range(0, starting_ap)
		var result_a: bool = ap.spend(affordable_cost)

		if not result_a:
			push_error(
				"FAIL iter %d (spend-success): spend(%d) with current_ap=%d returned false, expected true"
				% [i, affordable_cost, starting_ap]
			)
			failures += 1

		var expected_ap_after: int = starting_ap - affordable_cost
		if ap.current_ap != expected_ap_after:
			push_error(
				"FAIL iter %d (spend-exact): after spend(%d) from %d, current_ap=%d, expected %d"
				% [i, affordable_cost, starting_ap, ap.current_ap, expected_ap_after]
			)
			failures += 1

		# --- Case B: spend(amount) where amount > current_ap ---
		var ap2: Node = load("res://components/managers/APManager.gd").new()
		ap2.max_ap = max_val
		ap2.current_ap = rng.randi_range(0, max_val)
		var ap2_before: int = ap2.current_ap

		var unaffordable_cost: int = ap2.current_ap + rng.randi_range(1, 10)
		var result_b: bool = ap2.spend(unaffordable_cost)

		if result_b:
			push_error(
				"FAIL iter %d (spend-reject): spend(%d) with current_ap=%d returned true, expected false"
				% [i, unaffordable_cost, ap2_before]
			)
			failures += 1

		if ap2.current_ap != ap2_before:
			push_error(
				"FAIL iter %d (spend-unchanged): after rejected spend(%d), current_ap changed from %d to %d"
				% [i, unaffordable_cost, ap2_before, ap2.current_ap]
			)
			failures += 1

		ap.free()
		ap2.free()

	if failures == 0:
		print("PASS: Property 10 — AP spend is exact and rejects insufficient funds (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 10 — %d/%d iterations failed" % [failures, ITERATIONS])
