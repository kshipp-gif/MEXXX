# Feature: status-effects, Property 9: Pinned unit's move is always rejected
# Validates: Requirements 4.2
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		var bm: Node = load("res://components/managers/BattlefieldManager.gd").new()

		# Use a local EventBus instance to avoid autoload placeholder issues in tool mode
		var bus: Node = load("res://autoload/EventBus.gd").new()
		bm._event_bus = bus

		# Create a mock unit node with is_pinned = true
		var unit_node: Node = load("res://tests/MockUnit.gd").new()
		unit_node.set("is_pinned", true)

		var unit_id: StringName = &"pinned_unit"
		var start_pos := Vector2i(rng.randi_range(1, 6), rng.randi_range(1, 4))

		# Register the unit with its node so the pinned check can find it
		bm.place_unit(unit_id, start_pos, unit_node)

		# Generate a random destination — mix of in-bounds and out-of-bounds
		var dest: Vector2i
		if rng.randi_range(0, 1) == 0:
			# In-bounds destination
			dest = Vector2i(rng.randi_range(0, 7), rng.randi_range(0, 5))
		else:
			# Out-of-bounds destination
			var side: int = rng.randi_range(0, 3)
			match side:
				0: dest = Vector2i(-rng.randi_range(1, 5), rng.randi_range(0, 5))
				1: dest = Vector2i(8 + rng.randi_range(0, 5), rng.randi_range(0, 5))
				2: dest = Vector2i(rng.randi_range(0, 7), -rng.randi_range(1, 5))
				3: dest = Vector2i(rng.randi_range(0, 7), 6 + rng.randi_range(0, 5))

		# Subscribe to local EventBus before calling move_unit
		var received_events: Array = []
		var cb := func(payload: Dictionary) -> void:
			received_events.append(payload)
		bus.subscribe("move_rejected", cb)

		var pos_before: Vector2i = bm.get_position(unit_id)
		var result: bool = bm.move_unit(unit_id, dest)

		bus.unsubscribe("move_rejected", cb)

		# Assertion 1: move_unit must return false
		if result != false:
			push_error(
				"FAIL iter %d: move_unit returned true for pinned unit (dest=%s)"
				% [i, dest]
			)
			failures += 1

		# Assertion 2: position must not have changed
		if bm.get_position(unit_id) != pos_before:
			push_error(
				"FAIL iter %d: position changed after pinned move rejection (was %s, now %s)"
				% [i, pos_before, bm.get_position(unit_id)]
			)
			failures += 1

		# Assertion 3: exactly one move_rejected event must have been emitted
		if received_events.size() != 1:
			push_error(
				"FAIL iter %d: expected 1 move_rejected event, got %d"
				% [i, received_events.size()]
			)
			failures += 1
		else:
			var payload: Dictionary = received_events[0]

			# Assertion 4: reason must be "unit_pinned"
			if payload.get("reason") != "unit_pinned":
				push_error(
					"FAIL iter %d: move_rejected reason is '%s', expected 'unit_pinned'"
					% [i, str(payload.get("reason", "<missing>"))]
				)
				failures += 1

			# Assertion 5: 'to' field must match the requested destination
			if payload.get("to") != dest:
				push_error(
					"FAIL iter %d: move_rejected 'to' is %s, expected %s"
					% [i, str(payload.get("to", "<missing>")), dest]
				)
				failures += 1

			# Assertion 6: 'from' field must match the unit's position before the move
			if payload.get("from") != pos_before:
				push_error(
					"FAIL iter %d: move_rejected 'from' is %s, expected %s"
					% [i, str(payload.get("from", "<missing>")), pos_before]
				)
				failures += 1

		bm.free()
		unit_node.free()
		bus.free()

	if failures == 0:
		print(
			"PASS: Property 9 — Pinned unit's move is always rejected (%d iterations)"
			% ITERATIONS
		)
	else:
		push_error("FAIL: Property 9 — %d/%d iterations failed" % [failures, ITERATIONS])
