# Feature: status-effects, Property 12: ApplyStatusEffect.duplicate() gives each target an independent instance
# Validates: Requirements 7.4
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		# Generate a random target count (2–5) and a random base duration (1–10)
		var target_count: int = rng.randi_range(2, 5)
		var base_duration: int = rng.randi_range(1, 10)

		# Create the ApplyStatusEffect with a base StatusEffect resource
		var apply_effect: ApplyStatusEffect = load("res://components/effects/ApplyStatusEffect.gd").new()
		apply_effect.target_type = "target"
		var base_se: StatusEffect = load("res://components/status_effects/StatusEffect.gd").new()
		base_se.status_name = "test_effect"
		base_se.duration = base_duration
		apply_effect.status_effect_resource = base_se

		# Create unit nodes, each with a StatusEffectManager child
		var units: Array = []
		var managers: Array = []
		for _j in range(target_count):
			var unit: Node = load("res://tests/MockUnit.gd").new()
			var manager: Node = load("res://components/managers/StatusEffectManager.gd").new()
			manager._host = unit
			unit.add_child(manager)
			units.append(unit)
			managers.append(manager)

		# Execute ApplyStatusEffect for each unit individually
		for unit in units:
			apply_effect.execute({"target": unit})

		# Verify each unit received exactly one active effect with the correct duration
		var setup_ok := true
		for j in range(target_count):
			var active: Array = managers[j].get_active_effects()
			if active.size() != 1 or active[0].duration != base_duration:
				push_error(
					"FAIL iter %d (setup): unit %d expected 1 effect with duration %d, got size=%d"
					% [i, j, base_duration, active.size()]
				)
				failures += 1
				setup_ok = false
				break

		if not setup_ok:
			for unit in units:
				unit.free()
			continue

		# Mutate the duration on the FIRST unit's active effect
		var first_active: Array = managers[0].get_active_effects()
		# get_active_effects() returns a copy of the array, but the StatusEffect objects
		# inside are the same references. We need to access the internal effect directly.
		# Use the returned reference — it IS the same object stored internally.
		first_active[0].duration = 999

		# Verify all OTHER units' effects still have the original duration
		for j in range(1, target_count):
			var other_active: Array = managers[j].get_active_effects()
			if other_active.size() != 1:
				push_error(
					"FAIL iter %d (independence size): unit %d expected 1 effect, got %d"
					% [i, j, other_active.size()]
				)
				failures += 1
			elif other_active[0].duration != base_duration:
				push_error(
					"FAIL iter %d (independence duration): unit %d expected duration %d after mutating unit 0, got %d"
					% [i, j, base_duration, other_active[0].duration]
				)
				failures += 1

		# Clean up — freeing each unit also frees its StatusEffectManager child
		for unit in units:
			unit.free()

	if failures == 0:
		print("PASS: Property 12 — ApplyStatusEffect.duplicate() gives each target an independent instance (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 12 — %d/%d iterations failed" % [failures, ITERATIONS])
