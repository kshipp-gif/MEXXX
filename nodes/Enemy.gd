## Enemy node — an enemy unit on the Battlefield.
## Extends Node2D; behaviour is driven by an array of EnemyBehavior resources.
## The inherited `name` property serves as the unit_id for BattlefieldManager.
extends Node2D

## Maximum hit points for this Enemy.
@export var max_hp: int = 10

## Current hit points; initialised to max_hp in _ready().
var hp: int = 0

## Ordered list of behaviors executed each enemy turn.
@export var behaviors: Array[EnemyBehavior] = []

## Whether this enemy is pinned (cannot move). Set by PinnedEffect.
var is_pinned: bool = false

## Multiplier applied to block gains. Set by BrittleEffect (0.5 when brittle).
var block_multiplier: float = 1.0

## Multiplier applied to incoming damage. Set by VulnerableEffect (1.25 when vulnerable).
var damage_multiplier: float = 1.0

## Current block points; absorbs incoming damage before HP is reduced.
var block: int = 0

func _ready() -> void:
	hp = max_hp

## Reduce hp by amount, applying block absorption first, then damage_multiplier.
## If attacker is provided and this unit has Retaliation stacks, the attacker
## takes 1 damage per stack.
func take_damage(amount: int, attacker: Node = null) -> void:
	var absorbed: int = min(block, amount)
	block -= absorbed
	amount -= absorbed
	if amount <= 0:
		return
	var effective: int = roundi(amount * damage_multiplier)
	hp = max(0, hp - effective)
	_trigger_retaliation(attacker)

## Deal retaliation damage back to the attacker if this unit has Retaliation active.
func _trigger_retaliation(attacker: Node) -> void:
	if attacker == null:
		return
	for child in get_children():
		if child is StatusEffectManager:
			if child.has_effect("retaliation"):
				var stacks: int = 0
				for effect in child.get_active_effects():
					if effect.status_name == "retaliation":
						stacks = effect.duration
						break
				if stacks > 0 and attacker.has_method("take_damage"):
					attacker.take_damage(stacks)
			return

## Returns true if the Enemy still has HP remaining.
func is_alive() -> bool:
	return hp > 0
