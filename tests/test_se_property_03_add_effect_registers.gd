# Feature: status-effects, Property 3: add_effect() registers the effect and calls apply()
# Validates: Requirements 2.3
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		# Generate random status_name ("effect_0" through "effect_9") and duration (1–10)
		var effect_index: int = rng.randi_range(0, 9)
		var effect_name: String = "effect_%d" % effect_index
		var effect_duration: int = rng.randi_range(1, 10)

		# Create a mock host node with is_pinned property
		var host: Node = load("res://tests/MockUnit.gd").new()
		host.set("is_pinned", false)

		# Instantiate StatusEffectManager and set _host directly (no scene tree needed)
		var manager: Node = load("res://components/managers/StatusEffectManager.gd").new()
		manager._host = host

		# Create a PinnedEffect so we can verify apply() was called via is_pinned == true
		var effect: StatusEffect = load("res://components/status_effects/PinnedEffect.gd").new()
		effect.status_name = effect_name
		effect.duration = effect_duration

		# Call add_effect()
		manager.add_effect(effect)

		# Assertion 1: get_active_effects() should contain exactly 1 effect
		var active: Array = manager.get_active_effects()
		if active.size() != 1:
			push_error(
				"FAIL iter %d (size): expected 1 active effect after add_effect(), got %d"
				% [i, active.size()]
			)
			failures += 1
		else:
			# Assertion 2: the effect in get_active_effects() has the correct status_name
			var registered: StatusEffect = active[0]
			if registered.status_name != effect_name:
				push_error(
					"FAIL iter %d (status_name): expected '%s', got '%s'"
					% [i, effect_name, registered.status_name]
				)
				failures += 1

		# Assertion 3: apply() was called — PinnedEffect.apply() sets is_pinned = true on host
		# Node.get() returns null for undeclared properties; treat null as "not true"
		var is_pinned_val = host.get("is_pinned")
		if is_pinned_val != true:
			push_error(
				"FAIL iter %d (apply): expected host.is_pinned == true after add_effect(), got %s"
				% [i, str(is_pinned_val)]
			)
			failures += 1

		# Clean up
		manager.free()
		host.free()

	if failures == 0:
		print("PASS: Property 3 — add_effect() registers the effect and calls apply() (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 3 — %d/%d iterations failed" % [failures, ITERATIONS])
