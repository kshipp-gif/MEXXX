## CombatTurnManager — sequences player and enemy turns; checks end conditions.
extends Node

enum TurnOwner { PLAYER, ENEMY }

var current_turn: TurnOwner = TurnOwner.PLAYER
var enemies: Array[Node] = []

## External references — set from the scene before calling start_combat().
var mech: Node = null
var battlefield_manager: Node = null
var ap_manager: Node = null
var base_manager: Node = null

## Start combat with the given enemy nodes; emit turn_started for the player.
## APManager and HandManager subscribe to turn_started and react accordingly.
func start_combat(enemy_nodes: Array[Node]) -> void:
	enemies = enemy_nodes
	current_turn = TurnOwner.PLAYER
	_reset_mech_block()
	_reset_mech_damage_flag()
	EventBus.emit("turn_started", { "owner": "player" })

## Called when the player presses "End Turn".
## Discards the hand (HandManager subscribes to turn_started { owner: "enemy" }),
## then processes all enemy behaviors.
func end_player_turn() -> void:
	current_turn = TurnOwner.ENEMY
	# Tick mech status effects at the start of the enemy turn (for Acid/poison).
	_tick_unit_effects(mech)
	# Tick all enemy status effects at the start of the enemy turn.
	for enemy in enemies:
		if enemy.has_method("is_alive") and enemy.is_alive():
			_tick_unit_effects(enemy)
	EventBus.emit("turn_started", { "owner": "enemy" })
	_process_enemy_turn()

## Internal: iterate every living enemy and execute each of its behaviors in order.
## Emits enemy_action_taken after each enemy acts, then checks end conditions.
## If no end condition is met after all enemies have acted, begins the next player turn.
func _process_enemy_turn() -> void:
	for enemy in enemies:
		# Skip destroyed enemies (hp <= 0 or is_alive() returns false)
		if enemy.has_method("is_alive"):
			if not enemy.is_alive():
				continue
		elif enemy.get("hp") != null:
			if enemy.hp <= 0:
				continue

		_tick_unit_effects(enemy)

		var context: Dictionary = {
			"enemy": enemy,
			"mech": mech,
			"battlefield_manager": battlefield_manager,
			"ap_manager": ap_manager,
			"event_bus": EventBus,
		}

		var behaviors = enemy.get("behaviors")
		if behaviors != null:
			for behavior in behaviors:
				behavior.decide(context)

		EventBus.emit("enemy_action_taken", { "enemy": enemy, "action": context })

	_check_end_conditions()

## Check victory/defeat conditions and emit combat_ended if one is met.
## Victory: all enemies have hp <= 0 (or is_alive() returns false).
## Defeat: base_manager exists and its current_hp <= 0.
## If neither condition is met, loop back to the player turn.
func _check_end_conditions() -> void:
	# Check defeat first — base destroyed
	if base_manager != null:
		var base_hp = base_manager.get("current_hp")
		if base_hp != null and base_hp <= 0:
			EventBus.emit("combat_ended", { "outcome": "defeat" })
			return

	# Check victory — all enemies destroyed
	var all_dead: bool = true
	for enemy in enemies:
		var alive: bool = false
		if enemy.has_method("is_alive"):
			alive = enemy.is_alive()
		elif enemy.get("hp") != null:
			alive = enemy.hp > 0
		else:
			# Cannot determine — assume alive to be safe
			alive = true
		if alive:
			all_dead = false
			break

	if all_dead and enemies.size() > 0:
		EventBus.emit("combat_ended", { "outcome": "victory" })
		return

	# No end condition met — begin the next player turn
	current_turn = TurnOwner.PLAYER
	_reset_mech_block()
	_reset_mech_damage_flag()
	EventBus.emit("turn_started", { "owner": "player" })

## Reset the mech's damage flag at the start of each player turn.
func _reset_mech_damage_flag() -> void:
	if mech != null:
		mech.set("took_damage_last_enemy_turn", false)

## Reset mech block at the start of each player turn (block doesn't carry over).
func _reset_mech_block() -> void:
	if mech != null:
		mech.set("block", 0)

## Tick status effects on a unit at the start of its turn.
## Resets block to 0 first (block does not carry over between turns),
## then finds the first StatusEffectManager child and calls tick_effects() on it.
func _tick_unit_effects(unit: Node) -> void:
	if unit == null:
		return
	unit.set("block", 0)   # block does not carry over between turns
	for child in unit.get_children():
		if child is StatusEffectManager:
			child.tick_effects()
			return
