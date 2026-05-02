# Feature: mech-deckbuilder-core-systems, Property 19: All effects on a card are executed in order
# Tests that iterating card.effects and calling execute() on each one happens in the
# same order as the effects array — i.e., effects[0] runs first, effects[N-1] runs last.
# Validates: Requirements 16.2, 16.5
@tool
extends EditorScript

const ITERATIONS := 100
const TRACKING_EFFECT_SCRIPT := "res://tests/TrackingEffect.gd"

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	var tracking_script: GDScript = load(TRACKING_EFFECT_SCRIPT)
	if tracking_script == null:
		push_error("FAIL: Could not load TrackingEffect script at %s" % TRACKING_EFFECT_SCRIPT)
		return

	for i in range(ITERATIONS):
		# Choose a random number of effects between 1 and 10.
		var effect_count: int = rng.randi_range(1, 10)

		# Shared log array — all TrackingEffect instances write into this.
		var execution_log: Array = []

		# Build the effects array and assign each a unique index.
		var effects: Array[Resource] = []
		for j in range(effect_count):
			var effect: Effect = tracking_script.new()
			effect.index = j
			effect.log = execution_log
			effects.append(effect)

		# Attach effects to a Card.
		var card := Card.new()
		card.effects = effects

		# Execute all effects in the order they appear on the card.
		var context: Dictionary = {}
		for effect in card.effects:
			effect.execute(context)

		# Verify the log matches [0, 1, 2, ..., effect_count - 1].
		var expected: Array = []
		for k in range(effect_count):
			expected.append(k)

		if execution_log != expected:
			push_error(
				"FAIL iteration %d: expected order %s but got %s (effect_count=%d)"
				% [i, str(expected), str(execution_log), effect_count]
			)
			failures += 1

	if failures == 0:
		print("PASS: Property 19 — All effects on a card are executed in order (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 19 — %d/%d iterations failed" % [failures, ITERATIONS])
