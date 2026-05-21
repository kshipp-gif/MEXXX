# Feature: status-effects, Property 2: tick() decrements duration by exactly 1
# Validates: Requirements 1.4, 1.5
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		var d: int = rng.randi_range(1, 20)
		var effect: StatusEffect = load("res://components/status_effects/StatusEffect.gd").new()
		effect.duration = d

		effect.tick()

		if effect.duration != d - 1:
			push_error(
				"FAIL iter %d: expected duration %d after tick(), got %d (initial duration was %d)"
				% [i, d - 1, effect.duration, d]
			)
			failures += 1

	if failures == 0:
		print("PASS: Property 2 — tick() decrements duration by exactly 1 (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 2 — %d/%d iterations failed" % [failures, ITERATIONS])
