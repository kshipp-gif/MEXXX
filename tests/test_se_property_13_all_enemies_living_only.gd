# Feature: status-effects, Property 13: ApplyStatusEffect with target_type "all_enemies" reaches every living enemy
# Validates: Requirements 7.5
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		# Generate a random enemy count (2–6)
		var enemy_count: int = rng.randi_range(2, 6)

		# Randomly assign alive/dead states; ensure at least one is alive
		var alive_flags: Array = []
		for _j in range(enemy_count):
			alive_flags.append(rng.randi_range(0, 1) == 1)

		# If all are dead, force the first one alive
		var any_alive := false
		for flag in alive_flags:
			if flag:
				any_alive = true
				break
		if not any_alive:
			alive_flags[0] = true

		# Create Enemy nodes with StatusEffectManager children
		var enemies: Array = []
		var managers: Array = []
		for j in range(enemy_count):
			var enemy: Node = load("res://nodes/Enemy.gd").new()
			# _ready() is not called outside the scene tree, so set hp directly
			if alive_flags[j]:
				enemy.hp = 10   # alive: hp > 0
			else:
				enemy.hp = 0    # dead: hp == 0

			var manager: Node = load("res://components/managers/StatusEffectManager.gd").new()
			manager._host = enemy
			enemy.add_child(manager)

			enemies.append(enemy)
			managers.append(manager)

		# Create ApplyStatusEffect with target_type "all_enemies"
		var apply_effect: ApplyStatusEffect = load("res://components/effects/ApplyStatusEffect.gd").new()
		apply_effect.target_type = "all_enemies"
		var base_se: StatusEffect = load("res://components/status_effects/StatusEffect.gd").new()
		base_se.status_name = "test_effect"
		base_se.duration = 2
		apply_effect.status_effect_resource = base_se

		# Execute against the enemy list
		apply_effect.execute({"enemies": enemies})

		# Verify: living enemies received the effect; dead enemies did not
		for j in range(enemy_count):
			var active: Array = managers[j].get_active_effects()
			if alive_flags[j]:
				# Living enemy must have exactly 1 active effect
				if active.size() != 1:
					push_error(
						"FAIL iter %d: living enemy %d expected 1 active effect, got %d"
						% [i, j, active.size()]
					)
					failures += 1
			else:
				# Dead enemy must have no active effects
				if active.size() != 0:
					push_error(
						"FAIL iter %d: dead enemy %d expected 0 active effects, got %d"
						% [i, j, active.size()]
					)
					failures += 1

		# Clean up — freeing each enemy also frees its StatusEffectManager child
		for enemy in enemies:
			enemy.free()

	if failures == 0:
		print("PASS: Property 13 — ApplyStatusEffect with target_type \"all_enemies\" reaches every living enemy (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 13 — %d/%d iterations failed" % [failures, ITERATIONS])
