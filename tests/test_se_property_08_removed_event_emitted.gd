# Feature: status-effects, Property 8: status_effect_removed is emitted for every expired effect
# Validates: Requirements 2.8
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		# Create a mock host node
		var host: Node = Node.new()

		# Instantiate StatusEffectManager and set _host directly (no scene tree needed)
		var manager: Node = load("res://components/managers/StatusEffectManager.gd").new()
		manager._host = host

		# Use a local EventBus instance to avoid autoload placeholder issues in tool mode
		var bus: Node = load("res://autoload/EventBus.gd").new()
		manager._event_bus = bus

		# Generate 1–4 effects, ALL with duration = 1 so they all expire on the first tick
		var effect_count: int = rng.randi_range(1, 4)
		var effects: Array = []
		for j in range(effect_count):
			var effect: StatusEffect = load("res://components/status_effects/StatusEffect.gd").new()
			effect.status_name = "effect_%d_%d" % [i, j]
			effect.duration = 1
			effects.append(effect)

		# Add all effects to the manager
		for effect in effects:
			manager.add_effect(effect)

		# Subscribe to the local EventBus BEFORE calling tick_effects()
		var received_events: Array = []
		var cb := func(payload: Dictionary) -> void:
			received_events.append(payload)

		bus.subscribe("status_effect_removed", cb)

		# Tick once — all effects with duration == 1 should expire
		manager.tick_effects()

		# Unsubscribe
		bus.unsubscribe("status_effect_removed", cb)

		# Assertion 1: exactly one status_effect_removed event per expired effect
		if received_events.size() != effect_count:
			push_error(
				"FAIL iter %d (event count): expected %d status_effect_removed events, got %d"
				% [i, effect_count, received_events.size()]
			)
			failures += 1
			manager.free()
			host.free()
			continue

		# Assertion 2: each event has correct status_name and unit
		var all_payloads_correct := true
		for j in range(effect_count):
			var expected_effect: StatusEffect = effects[j]
			var payload: Dictionary = received_events[j]

			if not payload.has("status_name") or payload["status_name"] != expected_effect.status_name:
				push_error(
					"FAIL iter %d event %d (status_name): expected '%s', got '%s'"
					% [i, j, expected_effect.status_name, str(payload.get("status_name", "<missing>"))]
				)
				failures += 1
				all_payloads_correct = false

			if not payload.has("unit") or payload["unit"] != host:
				push_error(
					"FAIL iter %d event %d (unit): expected host node, got %s"
					% [i, j, str(payload.get("unit", "<missing>"))]
				)
				failures += 1
				all_payloads_correct = false

		# Clean up
		manager.free()
		host.free()
		bus.free()

	if failures == 0:
		print(
			"PASS: Property 8 — status_effect_removed is emitted for every expired effect (%d iterations)"
			% ITERATIONS
		)
	else:
		push_error("FAIL: Property 8 — %d/%d iterations failed" % [failures, ITERATIONS])
