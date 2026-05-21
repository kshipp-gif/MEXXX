# Feature: mech-deckbuilder-core-systems, Property 11: AP grant is capped at max_ap
# Validates: Requirements 6.6
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

		var before_ap: int = ap.current_ap
		var grant_amount: int = rng.randi_range(0, 20)

		ap.grant(grant_amount)

		var expected: int = min(before_ap + grant_amount, max_val)

		if ap.current_ap != expected:
			push_error(
				"FAIL iter %d: grant(%d) from current_ap=%d with max_ap=%d → current_ap=%d, expected %d"
				% [i, grant_amount, before_ap, max_val, ap.current_ap, expected]
			)
			failures += 1

		if ap.current_ap > ap.max_ap:
			push_error(
				"FAIL iter %d (cap): current_ap=%d exceeds max_ap=%d after grant(%d)"
				% [i, ap.current_ap, ap.max_ap, grant_amount]
			)
			failures += 1

		ap.free()

	if failures == 0:
		print("PASS: Property 11 — AP grant is capped at max_ap (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 11 — %d/%d iterations failed" % [failures, ITERATIONS])
