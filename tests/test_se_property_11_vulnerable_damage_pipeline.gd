# Feature: status-effects, Property 11: Vulnerable damage pipeline is roundi((raw - armor - block) * multiplier)
# Validates: Requirements 6.2, 6.4, 8.2
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	# --- Mech tests (has armor_bonus) ---
	for i in range(ITERATIONS):
		var raw_damage: int = rng.randi_range(0, 50)
		var armor: int = rng.randi_range(0, 20)
		var block_val: int = rng.randi_range(0, 30)

		# Instantiate Mech script; CharacterBody2D can be created outside scene tree
		# but _ready() calls EventBus.subscribe — we skip _ready() by not adding to tree
		var mech = load("res://nodes/Mech.gd").new()
		mech.set("current_hp", 1000)
		mech.set("armor_bonus", armor)
		mech.set("block", block_val)
		mech.set("damage_multiplier", 1.25)

		mech.take_damage(raw_damage)

		# Expected: block absorbs first, then armor, then multiplier
		var after_block: int = max(0, raw_damage - block_val)
		var after_armor: int = max(0, after_block - armor)
		var expected_reduction: int = roundi(after_armor * 1.25)
		var expected_hp: int = max(0, 1000 - expected_reduction)

		if mech.get("current_hp") != expected_hp:
			push_error(
				"FAIL Mech iter %d: raw=%d armor=%d block=%d => expected_hp=%d got=%d"
				% [i, raw_damage, armor, block_val, expected_hp, mech.get("current_hp")]
			)
			failures += 1

		mech.free()

	# --- Enemy tests (no armor_bonus) ---
	for i in range(ITERATIONS):
		var raw_damage: int = rng.randi_range(0, 50)
		var block_val: int = rng.randi_range(0, 30)

		var enemy = load("res://nodes/Enemy.gd").new()
		enemy.set("hp", 1000)
		enemy.set("block", block_val)
		enemy.set("damage_multiplier", 1.25)

		enemy.take_damage(raw_damage)

		# Expected: block absorbs first, then multiplier (no armor on Enemy)
		var after_block: int = max(0, raw_damage - block_val)
		var expected_reduction: int = roundi(after_block * 1.25)
		var expected_hp: int = max(0, 1000 - expected_reduction)

		if enemy.get("hp") != expected_hp:
			push_error(
				"FAIL Enemy iter %d: raw=%d block=%d => expected_hp=%d got=%d"
				% [i, raw_damage, block_val, expected_hp, enemy.get("hp")]
			)
			failures += 1

		enemy.free()

	if failures == 0:
		print(
			"PASS: Property 11 — Vulnerable damage pipeline is roundi((raw - armor - block) * multiplier) (%d Mech + %d Enemy iterations)"
			% [ITERATIONS, ITERATIONS]
		)
	else:
		push_error("FAIL: Property 11 — %d/%d total iterations failed" % [failures, ITERATIONS * 2])
