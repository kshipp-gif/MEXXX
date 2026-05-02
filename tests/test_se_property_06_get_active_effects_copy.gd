# Feature: status-effects, Property 6: get_active_effects() returns a copy — mutations do not affect internal state
# Validates: Requirements 2.7
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		# Generate a random list of 1–5 effects with unique status_names
		var effect_count: int = rng.randi_range(1, 5)

		# Create a mock host node
		var host: Node = Node.new()

		# Instantiate StatusEffectManager and set _host directly (no scene tree needed)
		var manager: Node = load("res://components/managers/StatusEffectManager.gd").new()
		manager._host = host

		# Add effect_count effects with unique status_names
		var original_names: Array = []
		for j in range(effect_count):
			var effect: StatusEffect = load("res://components/status_effects/StatusEffect.gd").new()
			effect.status_name = "effect_%d_%d" % [i, j]
			effect.duration = rng.randi_range(1, 10)
			manager.add_effect(effect)
			original_names.append(effect.status_name)

		# Get the first copy of active effects
		var first_copy: Array = manager.get_active_effects()

		# Verify the first copy has the expected size before mutating
		if first_copy.size() != effect_count:
			push_error(
				"FAIL iter %d (pre-mutation size): expected %d effects, got %d"
				% [i, effect_count, first_copy.size()]
			)
			failures += 1
			manager.free()
			host.free()
			continue

		# Mutate the returned array: randomly either append a dummy effect or erase an element
		var mutation_type: int = rng.randi_range(0, 1)
		if mutation_type == 0:
			# Append a new dummy effect to the returned copy
			var dummy: StatusEffect = load("res://components/status_effects/StatusEffect.gd").new()
			dummy.status_name = "dummy_extra_%d" % i
			dummy.duration = 1
			first_copy.append(dummy)
		else:
			# Erase the first element from the returned copy
			if first_copy.size() > 0:
				first_copy.erase(first_copy[0])

		# Get a second copy — internal state must be unchanged
		var second_copy: Array = manager.get_active_effects()

		# Assertion 1: second copy has the original size (mutation did not affect internal state)
		if second_copy.size() != effect_count:
			push_error(
				"FAIL iter %d (post-mutation size): expected %d effects after mutating returned copy, got %d (mutation_type=%d)"
				% [i, effect_count, second_copy.size(), mutation_type]
			)
			failures += 1
		else:
			# Assertion 2: second copy contains all the original status_names
			var second_names: Array = []
			for eff in second_copy:
				second_names.append(eff.status_name)

			for name in original_names:
				if not second_names.has(name):
					push_error(
						"FAIL iter %d (post-mutation content): status_name '%s' missing from second get_active_effects() call"
						% [i, name]
					)
					failures += 1
					break

		# Clean up
		manager.free()
		host.free()

	if failures == 0:
		print(
			"PASS: Property 6 — get_active_effects() returns a copy — mutations do not affect internal state (%d iterations)"
			% ITERATIONS
		)
	else:
		push_error("FAIL: Property 6 — %d/%d iterations failed" % [failures, ITERATIONS])
