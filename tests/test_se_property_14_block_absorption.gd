# Feature: status-effects, Property 14: Block absorbs damage before HP is reduced; block is consumed correctly
# Validates: Requirements 8.2, 8.3, 8.4
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		var block_val: int
		var damage: int

		# Alternate between the two cases to ensure both are covered:
		# Even iterations: damage <= block (block fully absorbs)
		# Odd iterations:  damage > block  (block partially absorbs, HP reduced)
		if i % 2 == 0:
			block_val = rng.randi_range(10, 50)
			damage = rng.randi_range(0, block_val)
		else:
			block_val = rng.randi_range(0, 40)
			damage = rng.randi_range(block_val + 1, 50)

		var enemy = load("res://nodes/Enemy.gd").new()
		enemy.set("hp", 1000)
		enemy.set("block", block_val)
		enemy.set("damage_multiplier", 1.0)

		enemy.take_damage(damage)

		if damage <= block_val:
			# Case 1: block fully absorbs — HP unchanged, block reduced by damage
			var expected_block: int = block_val - damage
			var expected_hp: int = 1000

			if enemy.get("hp") != expected_hp:
				push_error(
					"FAIL iter %d (damage<=block): block=%d damage=%d => expected_hp=%d got=%d"
					% [i, block_val, damage, expected_hp, enemy.get("hp")]
				)
				failures += 1
			elif enemy.get("block") != expected_block:
				push_error(
					"FAIL iter %d (damage<=block): block=%d damage=%d => expected_block=%d got=%d"
					% [i, block_val, damage, expected_block, enemy.get("block")]
				)
				failures += 1
		else:
			# Case 2: damage exceeds block — block drained to 0, HP reduced by remainder
			var remainder: int = damage - block_val
			var expected_hp: int = 1000 - roundi(remainder * 1.0)
			var expected_block: int = 0

			if enemy.get("block") != expected_block:
				push_error(
					"FAIL iter %d (damage>block): block=%d damage=%d => expected_block=%d got=%d"
					% [i, block_val, damage, expected_block, enemy.get("block")]
				)
				failures += 1
			elif enemy.get("hp") != expected_hp:
				push_error(
					"FAIL iter %d (damage>block): block=%d damage=%d => expected_hp=%d got=%d"
					% [i, block_val, damage, expected_hp, enemy.get("hp")]
				)
				failures += 1

		enemy.free()

	if failures == 0:
		print(
			"PASS: Property 14 — Block absorbs damage before HP is reduced; block is consumed correctly (%d iterations)"
			% [ITERATIONS]
		)
	else:
		push_error("FAIL: Property 14 — %d/%d iterations failed" % [failures, ITERATIONS])
