# Feature: mech-deckbuilder-core-systems, Property 21: EventBus delivers events only to matching subscribers with correct payload
# Validates: Requirements 18.1, 18.2, 18.3, 18.4
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		var bus: Node = load("res://autoload/EventBus.gd").new()

		var received_a := []
		var received_b := []
		var cb_a := func(p): received_a.append(p)
		var cb_b := func(p): received_b.append(p)

		bus.subscribe("event_A", cb_a)
		bus.subscribe("event_B", cb_b)

		var payload_a := { "value": rng.randi_range(0, 1000), "iter": i }
		bus.emit("event_A", payload_a)

		if received_a.size() != 1:
			push_error(
				"FAIL iter %d (delivery): subscriber to 'event_A' expected 1 call, got %d"
				% [i, received_a.size()]
			)
			failures += 1

		if received_b.size() != 0:
			push_error(
				"FAIL iter %d (isolation): subscriber to 'event_B' received %d calls when 'event_A' was emitted"
				% [i, received_b.size()]
			)
			failures += 1

		if received_a.size() == 1:
			var got: Dictionary = received_a[0]
			if got != payload_a:
				push_error(
					"FAIL iter %d (payload): expected payload %s, got %s"
					% [i, str(payload_a), str(got)]
				)
				failures += 1

		bus.unsubscribe("event_A", cb_a)
		var received_after_unsub := []
		bus.emit("event_A", { "after": true })

		if received_a.size() != 1:
			push_error(
				"FAIL iter %d (unsubscribe): after unsubscribe, 'event_A' subscriber was called again (total calls: %d)"
				% [i, received_a.size()]
			)
			failures += 1

		if received_after_unsub.size() != 0:
			push_error(
				"FAIL iter %d (unsubscribe-new): unregistered callable received %d unexpected calls"
				% [i, received_after_unsub.size()]
			)
			failures += 1

		var unknown_event := "unknown_event_%d_%d" % [i, rng.randi_range(0, 9999)]
		bus.emit(unknown_event, { "x": 1 })
		if received_b.size() != 0:
			push_error(
				"FAIL iter %d (unknown-event): emitting unknown event triggered 'event_B' subscriber (%d calls)"
				% [i, received_b.size()]
			)
			failures += 1

		var bus2: Node = load("res://autoload/EventBus.gd").new()
		var sub_count: int = rng.randi_range(2, 6)
		var multi_received := []
		for _s in range(sub_count):
			var idx := multi_received.size()
			multi_received.append([])
			var slot_ref := multi_received
			var slot_idx := idx
			bus2.subscribe("multi_event", func(p): slot_ref[slot_idx].append(p))

		var multi_payload := { "round": i, "rand": rng.randi_range(0, 500) }
		bus2.emit("multi_event", multi_payload)

		for s in range(sub_count):
			if multi_received[s].size() != 1:
				push_error(
					"FAIL iter %d (multi-sub): subscriber %d/%d expected 1 call, got %d"
					% [i, s, sub_count, multi_received[s].size()]
				)
				failures += 1
			elif multi_received[s][0] != multi_payload:
				push_error(
					"FAIL iter %d (multi-payload): subscriber %d/%d got wrong payload: expected %s, got %s"
					% [i, s, sub_count, str(multi_payload), str(multi_received[s][0])]
				)
				failures += 1

		bus.free()
		bus2.free()

	if failures == 0:
		print("PASS: Property 21 — EventBus delivers events only to matching subscribers with correct payload (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 21 — %d/%d iterations failed" % [failures, ITERATIONS])
