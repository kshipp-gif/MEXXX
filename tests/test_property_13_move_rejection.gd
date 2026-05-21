# Feature: mech-deckbuilder-core-systems, Property 13: Out-of-bounds and occupied moves are rejected
# Validates: Requirements 7.1, 7.4, 7.5
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		var bm: Node = load("res://components/managers/BattlefieldManager.gd").new()

		var unit_id: StringName = &"unit_a"
		var start_pos := Vector2i(rng.randi_range(0, 7), rng.randi_range(0, 5))
		bm.place_unit(unit_id, start_pos)

		# --- Case A: move to an out-of-bounds tile returns false ---
		var oob_tile: Vector2i
		var side: int = rng.randi_range(0, 3)
		match side:
			0: oob_tile = Vector2i(-rng.randi_range(1, 5), rng.randi_range(0, 5))
			1: oob_tile = Vector2i(8 + rng.randi_range(0, 5), rng.randi_range(0, 5))
			2: oob_tile = Vector2i(rng.randi_range(0, 7), -rng.randi_range(1, 5))
			3: oob_tile = Vector2i(rng.randi_range(0, 7), 6 + rng.randi_range(0, 5))

		var pos_before_oob: Vector2i = bm.get_position(unit_id)
		var result_oob: bool = bm.move_unit(unit_id, oob_tile)
		if result_oob:
			push_error(
				"FAIL iter %d (out-of-bounds): move_unit to %s returned true, expected false"
				% [i, oob_tile]
			)
			failures += 1
		if bm.get_position(unit_id) != pos_before_oob:
			push_error(
				"FAIL iter %d (oob-position-unchanged): position changed after rejected oob move"
				% [i]
			)
			failures += 1

		# --- Case B: move to a tile occupied by another unit returns false ---
		var blocker_id: StringName = &"unit_b"
		var blocker_pos: Vector2i
		var attempts := 0
		blocker_pos = Vector2i(rng.randi_range(0, 7), rng.randi_range(0, 5))
		while blocker_pos == start_pos and attempts < 20:
			blocker_pos = Vector2i(rng.randi_range(0, 7), rng.randi_range(0, 5))
			attempts += 1
		bm.place_unit(blocker_id, blocker_pos)

		var pos_before_occ: Vector2i = bm.get_position(unit_id)
		var result_occ: bool = bm.move_unit(unit_id, blocker_pos)
		if result_occ:
			push_error(
				"FAIL iter %d (occupied): move_unit to occupied tile %s returned true, expected false"
				% [i, blocker_pos]
			)
			failures += 1
		if bm.get_position(unit_id) != pos_before_occ:
			push_error(
				"FAIL iter %d (occ-position-unchanged): position changed after rejected occupied move"
				% [i]
			)
			failures += 1

		# --- Case C: move to a valid empty tile returns true ---
		var free_tile: Vector2i
		var found := false
		for _try in range(50):
			var candidate := Vector2i(rng.randi_range(0, 7), rng.randi_range(0, 5))
			if bm.is_tile_free(candidate):
				free_tile = candidate
				found = true
				break

		if found:
			var result_free: bool = bm.move_unit(unit_id, free_tile)
			if not result_free:
				push_error(
					"FAIL iter %d (valid-move): move_unit to free tile %s returned false, expected true"
					% [i, free_tile]
				)
				failures += 1
			if bm.get_position(unit_id) != free_tile:
				push_error(
					"FAIL iter %d (valid-move-position): after successful move, position is %s, expected %s"
					% [i, bm.get_position(unit_id), free_tile]
				)
				failures += 1

		bm.free()

	if failures == 0:
		print("PASS: Property 13 — Out-of-bounds and occupied moves are rejected (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 13 — %d/%d iterations failed" % [failures, ITERATIONS])
