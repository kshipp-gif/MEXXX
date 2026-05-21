# Feature: status-effects, Property 5: tick_effects() removes expired effects and keeps live ones
# Validates: Requirements 2.5, 3.3
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		# Generate 2–6 effects with a mix of duration == 1 (will expire) and duration > 1 (will survive)
		var count: int = rng.randi_range(2, 6)

		# Build a shuffled list of durations ensuring at least one == 1 and at least one > 1
		var durations: Array = []
		for j in range(count):
			durations.append(0)  # placeholder

		# Guarantee at least one expiring and one surviving effect
		var expire_idx: int = rng.randi_range(0, count - 1)
		var survive_idx: int = rng.randi_range(0, count - 1)
		while survive_idx == expire_idx:
			survive_idx = rng.randi_range(0, count - 1)

		for j in range(count):
			if j == expire_idx:
				durations[j] = 1
			elif j == survive_idx:
				durations[j] = rng.randi_range(2, 5)
			else:
				# Randomly assign either 1 (expire) or 2–5 (survive)
				if rng.randi_range(0, 1) == 0:
					durations[j] = 1
				else:
					durations[j] = rng.randi_range(2, 5)

		# Create a plain host node
		var host: Node = Node.new()

		# Instantiate StatusEffectManager and set _host directly
		var manager: Node = load("res://components/managers/StatusEffectManager.gd").new()
		manager._host = host

		# Track which names should expire and which should survive (with expected post-tick duration)
		var should_expire: Array = []   # status_name strings
		var should_survive: Dictionary = {}  # status_name -> expected_duration_after_tick

		# Create and add effects
		for j in range(count):
			var effect: StatusEffect = load("res://components/status_effects/StatusEffect.gd").new()
			effect.status_name = "effect_%d" % j
			effect.duration = durations[j]

			if durations[j] == 1:
				should_expire.append(effect.status_name)
			else:
				should_survive[effect.status_name] = durations[j] - 1

			manager.add_effect(effect)

		# Call tick_effects() once
		manager.tick_effects()

		# Retrieve active effects after tick
		var active: Array = manager.get_active_effects()

		# Build a lookup of active effect names -> duration for easy checking
		var active_map: Dictionary = {}
		for eff in active:
			active_map[eff.status_name] = eff.duration

		# Assertion 1: Effects with initial duration == 1 must NOT be in active effects
		for name in should_expire:
			if active_map.has(name):
				push_error(
					"FAIL iter %d: effect '%s' (duration was 1) should have been removed but is still active"
					% [i, name]
				)
				failures += 1

		# Assertion 2: Effects with initial duration > 1 must still be active with decremented duration
		for name in should_survive:
			var expected_dur: int = should_survive[name]
			if not active_map.has(name):
				push_error(
					"FAIL iter %d: effect '%s' (duration was %d) should still be active but was removed"
					% [i, name, expected_dur + 1]
				)
				failures += 1
			elif active_map[name] != expected_dur:
				push_error(
					"FAIL iter %d: effect '%s' expected duration %d after tick, got %d"
					% [i, name, expected_dur, active_map[name]]
				)
				failures += 1

		# Clean up
		manager.free()
		host.free()

	if failures == 0:
		print(
			"PASS: Property 5 — tick_effects() removes expired effects and keeps live ones (%d iterations)"
			% ITERATIONS
		)
	else:
		push_error("FAIL: Property 5 — %d/%d iterations failed" % [failures, ITERATIONS])
