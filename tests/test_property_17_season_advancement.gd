# Feature: mech-deckbuilder-core-systems, Property 17: Season advances by exactly 1 each turn; combat triggers every 4 seasons
# Tests that advance_season() increments current_season by exactly 1 per call, and that
# combat_triggered is emitted exactly once for every season number divisible by 4.
# Validates: Requirements 12.1, 12.2
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		# Pick a random starting season (0 to 20) and number of advances (1 to 20).
		var start_season: int = rng.randi_range(0, 20)
		var advances: int = rng.randi_range(1, 20)

		# Create a fresh BaseManager instance.
		var base_manager := BaseManager.new()
		base_manager.current_season = start_season
		# _ready() is not called in EditorScript context, so set current_hp manually.
		base_manager.current_hp = base_manager.max_base_hp

		# Use a local EventBus instance to avoid autoload placeholder issues in tool mode.
		var bus: Node = load("res://autoload/EventBus.gd").new()
		base_manager._event_bus = bus

		# Track combat_triggered events via local bus.
		var combat_count := [0]
		var combat_cb := func(_p: Dictionary) -> void:
			combat_count[0] += 1
		bus.subscribe("combat_triggered", combat_cb)

		# Track season_advanced events and the season values they carry.
		var season_values: Array = []
		var season_cb := func(p: Dictionary) -> void:
			season_values.append(p.get("season", -1))
		bus.subscribe("season_advanced", season_cb)

		# Advance the season N times.
		for _k in range(advances):
			base_manager.advance_season()

		# Unsubscribe to avoid accumulation across iterations.
		bus.unsubscribe("combat_triggered", combat_cb)
		bus.unsubscribe("season_advanced", season_cb)

		# --- Verify property: current_season == start_season + advances ---
		var expected_season: int = start_season + advances
		if base_manager.current_season != expected_season:
			push_error(
				"FAIL iteration %d: expected current_season=%d but got %d (start=%d, advances=%d)"
				% [i, expected_season, base_manager.current_season, start_season, advances]
			)
			failures += 1
			bus.free()
			continue

		# --- Verify property: season_advanced emitted with correct season numbers ---
		if season_values.size() != advances:
			push_error(
				"FAIL iteration %d: expected %d season_advanced events but got %d"
				% [i, advances, season_values.size()]
			)
			failures += 1
			bus.free()
			continue

		var season_signal_ok := true
		for k in range(advances):
			var expected_val: int = start_season + k + 1
			if season_values[k] != expected_val:
				push_error(
					"FAIL iteration %d: season_advanced[%d] expected season=%d but got %d"
					% [i, k, expected_val, season_values[k]]
				)
				season_signal_ok = false
		if not season_signal_ok:
			failures += 1
			bus.free()
			continue

		# --- Verify property: combat_triggered fires exactly when season % 4 == 0 ---
		var expected_combat: int = 0
		for k in range(1, advances + 1):
			if (start_season + k) % 4 == 0:
				expected_combat += 1

		if combat_count[0] != expected_combat:
			push_error(
				"FAIL iteration %d: expected %d combat_triggered events but got %d (start=%d, advances=%d)"
				% [i, expected_combat, combat_count[0], start_season, advances]
			)
			failures += 1

		bus.free()

	if failures == 0:
		print(
			"PASS: Property 17 — Season advances by exactly 1 each turn; combat triggers every 4 seasons (%d iterations)"
			% ITERATIONS
		)
	else:
		push_error("FAIL: Property 17 — %d/%d iterations failed" % [failures, ITERATIONS])
