# Feature: mech-deckbuilder-core-systems, Property 15: Ammo decrement and reload round-trip
# Validates: Requirements 10.1, 10.3
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		var max_ammo: int = rng.randi_range(1, 20)
		var item := Item.new()
		item.id = &"test_item_%d" % i
		item.max_ammo = max_ammo
		item.current_ammo = max_ammo  # start full

		# Track signal emissions
		var signal_count := [0]
		item.ammo_changed.connect(func(_id, _cur, _max): signal_count[0] += 1)

		# Decrement a random number of times (may exceed max_ammo to test floor)
		var decrements: int = rng.randi_range(0, max_ammo + 5)
		for _d in range(decrements):
			item.decrement_ammo()

		# --- Property: decrement correctness — current_ammo never goes below 0 ---
		var expected_ammo: int = max(0, max_ammo - decrements)
		if item.current_ammo != expected_ammo:
			push_error(
				"FAIL iter %d (decrement): expected current_ammo=%d after %d decrements from max=%d, got %d"
				% [i, expected_ammo, decrements, max_ammo, item.current_ammo]
			)
			failures += 1

		# --- Property: reload round-trip — reload restores current_ammo to max_ammo exactly ---
		item.reload_ammo()
		if item.current_ammo != max_ammo:
			push_error(
				"FAIL iter %d (reload): after reload, expected current_ammo=%d, got %d"
				% [i, max_ammo, item.current_ammo]
			)
			failures += 1

		# --- Property: signal emission — ammo_changed emitted on decrement and reload ---
		# Each decrement_ammo() call emits once (even past floor), plus reload emits once.
		# Total expected = decrements + 1 (for reload).
		var expected_signals := decrements + 1
		if signal_count[0] != expected_signals:
			push_error(
				"FAIL iter %d (signals): expected %d ammo_changed signals (%d decrements + 1 reload), got %d"
				% [i, expected_signals, decrements, signal_count[0]]
			)
			failures += 1

	if failures == 0:
		print("PASS: Property 15 — Ammo decrement and reload round-trip (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 15 — %d/%d iterations failed" % [failures, ITERATIONS])
