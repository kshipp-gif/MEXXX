# Feature: status-effects, Property 10: Brittle block gain is always floor(raw * 0.5), clamped to 0
# Validates: Requirements 5.2, 5.4, 8.5
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		# Generate a random non-negative raw_block value in range 0–100
		var raw_block: int = rng.randi_range(0, 100)

		# Create a plain Node as the mock unit
		var node: Node = load("res://tests/MockUnit.gd").new()
		node.set("block_multiplier", 0.5)
		node.set("block", 0)

		# Load and configure GainBlockEffect
		var effect = load("res://components/effects/GainBlockEffect.gd").new()
		effect.amount = raw_block

		# Execute the effect
		effect.execute({"target": node})

		# Compute expected block: floor(raw_block * 0.5), clamped to 0
		var expected: int = max(0, floori(raw_block * 0.5))
		var actual: int = node.get("block")

		if actual != expected:
			push_error(
				"FAIL iter %d: raw_block=%d, block_multiplier=0.5 — expected block=%d, got %d"
				% [i, raw_block, expected, actual]
			)
			failures += 1

		# Clean up
		node.free()

	if failures == 0:
		print("PASS: Property 10 — Brittle block gain is always floor(raw * 0.5), clamped to 0 (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 10 — %d/%d iterations failed" % [failures, ITERATIONS])
