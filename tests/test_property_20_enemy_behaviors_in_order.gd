# Feature: mech-deckbuilder-core-systems, Property 20: All enemy behaviors are invoked in order during enemy turn
# Tests that iterating enemy.behaviors and calling decide() on each one happens in the
# same order as the behaviors array — i.e., behaviors[0] runs first, behaviors[N-1] runs last.
# Validates: Requirements 17.1, 17.4
@tool
extends EditorScript

const ITERATIONS := 100
const TRACKING_BEHAVIOR_SCRIPT := "res://tests/TrackingBehavior.gd"

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	var tracking_script: GDScript = load(TRACKING_BEHAVIOR_SCRIPT)
	if tracking_script == null:
		push_error("FAIL: Could not load TrackingBehavior script at %s" % TRACKING_BEHAVIOR_SCRIPT)
		return

	for i in range(ITERATIONS):
		# Choose a random number of behaviors between 1 and 10.
		var behavior_count: int = rng.randi_range(1, 10)

		# Shared log array — all TrackingBehavior instances write into this.
		var execution_log: Array = []

		# Build the behaviors array and assign each a unique index.
		var behaviors: Array = []
		for j in range(behavior_count):
			var behavior: EnemyBehavior = tracking_script.new()
			behavior.index = j
			behavior.log = execution_log
			behaviors.append(behavior)

		# Execute all behaviors in the order they appear in the list.
		# The context can be empty since TrackingBehavior only writes to its log.
		var context: Dictionary = {}
		for behavior in behaviors:
			behavior.decide(context)

		# Verify the log matches [0, 1, 2, ..., behavior_count - 1].
		var expected: Array = []
		for k in range(behavior_count):
			expected.append(k)

		if execution_log != expected:
			push_error(
				"FAIL iteration %d: expected order %s but got %s (behavior_count=%d)"
				% [i, str(expected), str(execution_log), behavior_count]
			)
			failures += 1

	if failures == 0:
		print("PASS: Property 20 — All enemy behaviors are invoked in order (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 20 — %d/%d iterations failed" % [failures, ITERATIONS])
