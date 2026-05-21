# Feature: status-effects, Property 1: apply() then remove() is a no-op on the unit
# Validates: Requirements 1.3, 4.3, 5.3, 6.3
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	# --- PinnedEffect ---
	# apply() sets is_pinned = true; remove() restores is_pinned = false (Req 4.3).
	# Baseline is a random bool to ensure remove() always produces the canonical default,
	# not just a no-op when the node happens to start at false.
	for i in range(ITERATIONS):
		var node: Node = load("res://tests/MockUnit.gd").new()
		var baseline_pinned: bool = rng.randi_range(0, 1) == 1
		node.set("is_pinned", baseline_pinned)

		var effect = load("res://components/status_effects/PinnedEffect.gd").new()
		effect.apply(node)
		effect.remove(node)

		var after = node.get("is_pinned")
		# After remove(), is_pinned must be false (canonical default per Req 4.3)
		if after != false:
			push_error(
				"FAIL PinnedEffect iter %d: expected is_pinned=false after apply+remove, got %s (baseline was %s)"
				% [i, str(after), str(baseline_pinned)]
			)
			failures += 1

		node.free()

	# --- BrittleEffect ---
	# apply() sets block_multiplier = 0.5; remove() restores block_multiplier = 1.0 (Req 5.3).
	# Baseline is a random float from a representative set to ensure remove() always
	# produces the canonical default regardless of prior state.
	var brittle_baselines := [0.5, 1.0, 1.5, 2.0]
	for i in range(ITERATIONS):
		var node: Node = load("res://tests/MockUnit.gd").new()
		var baseline_block: float = brittle_baselines[rng.randi_range(0, brittle_baselines.size() - 1)]
		node.set("block_multiplier", baseline_block)

		var effect = load("res://components/status_effects/BrittleEffect.gd").new()
		effect.apply(node)
		effect.remove(node)

		var after = node.get("block_multiplier")
		# After remove(), block_multiplier must be 1.0 (canonical default per Req 5.3)
		if not is_equal_approx(float(after), 1.0):
			push_error(
				"FAIL BrittleEffect iter %d: expected block_multiplier=1.0 after apply+remove, got %.4f (baseline was %.4f)"
				% [i, after, baseline_block]
			)
			failures += 1

		node.free()

	# --- VulnerableEffect ---
	# apply() sets damage_multiplier = 1.25; remove() restores damage_multiplier = 1.0 (Req 6.3).
	# Baseline is a random float from a representative set to ensure remove() always
	# produces the canonical default regardless of prior state.
	var vulnerable_baselines := [0.5, 1.0, 1.25, 2.0]
	for i in range(ITERATIONS):
		var node: Node = load("res://tests/MockUnit.gd").new()
		var baseline_damage: float = vulnerable_baselines[rng.randi_range(0, vulnerable_baselines.size() - 1)]
		node.set("damage_multiplier", baseline_damage)

		var effect = load("res://components/status_effects/VulnerableEffect.gd").new()
		effect.apply(node)
		effect.remove(node)

		var after = node.get("damage_multiplier")
		# After remove(), damage_multiplier must be 1.0 (canonical default per Req 6.3)
		if not is_equal_approx(float(after), 1.0):
			push_error(
				"FAIL VulnerableEffect iter %d: expected damage_multiplier=1.0 after apply+remove, got %.4f (baseline was %.4f)"
				% [i, after, baseline_damage]
			)
			failures += 1

		node.free()

	if failures == 0:
		print(
			"PASS: Property 1 — apply() then remove() is a no-op on the unit (%d iterations x 3 subclasses)"
			% ITERATIONS
		)
	else:
		push_error("FAIL: Property 1 — %d/%d iterations failed" % [failures, ITERATIONS * 3])
