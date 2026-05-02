# Feature: status-effects, Property 4: Re-adding an effect with the same name adds to duration without stacking a second instance
# Validates: Requirements 2.4
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		# Generate random durations d1 and d2 in range 1–10
		var d1: int = rng.randi_range(1, 10)
		var d2: int = rng.randi_range(1, 10)

		# Create a mock host node with is_pinned property
		var host: Node = load("res://tests/MockUnit.gd").new()
		host.set("is_pinned", false)

		# Instantiate StatusEffectManager and set _host directly (no scene tree needed)
		var manager: Node = load("res://components/managers/StatusEffectManager.gd").new()
		manager._host = host

		# First add_effect() — creates a PinnedEffect with duration d1
		var effect1: StatusEffect = load("res://components/status_effects/PinnedEffect.gd").new()
		effect1.duration = d1
		manager.add_effect(effect1)

		# Verify apply() was called: is_pinned should be true after first add
		if host.get("is_pinned") != true:
			push_error(
				"FAIL iter %d (first apply): expected host.is_pinned == true after first add_effect(), got %s"
				% [i, str(host.get("is_pinned"))]
			)
			failures += 1
			manager.free()
			host.free()
			continue

		# Reset is_pinned to false to detect if apply() is called a second time
		host.set("is_pinned", false)

		# Second add_effect() — same status_name "pinned", duration d2
		var effect2: StatusEffect = load("res://components/status_effects/PinnedEffect.gd").new()
		effect2.duration = d2
		manager.add_effect(effect2)

		# Assertion 1: get_active_effects() should still contain exactly 1 effect (no stacking)
		var active: Array = manager.get_active_effects()
		if active.size() != 1:
			push_error(
				"FAIL iter %d (size): expected 1 active effect after re-add, got %d (d1=%d, d2=%d)"
				% [i, active.size(), d1, d2]
			)
			failures += 1

		# Assertion 2: the single effect's duration should equal d1 + d2
		if active.size() >= 1:
			var registered: StatusEffect = active[0]
			if registered.duration != d1 + d2:
				push_error(
					"FAIL iter %d (duration): expected duration %d, got %d (d1=%d, d2=%d)"
					% [i, d1 + d2, registered.duration, d1, d2]
				)
				failures += 1

		# Assertion 3: apply() was NOT called again — is_pinned should remain false
		# (we reset it to false before the second add_effect())
		if host.get("is_pinned") != false:
			push_error(
				"FAIL iter %d (no re-apply): expected host.is_pinned == false after re-add (apply should not be called again), got %s (d1=%d, d2=%d)"
				% [i, str(host.get("is_pinned")), d1, d2]
			)
			failures += 1

		# Clean up
		manager.free()
		host.free()

	if failures == 0:
		print("PASS: Property 4 — Re-adding an effect with the same name adds to duration without stacking a second instance (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 4 — %d/%d iterations failed" % [failures, ITERATIONS])
