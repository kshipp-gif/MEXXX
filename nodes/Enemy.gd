## Enemy node — an enemy unit on the Battlefield.
## Extends Node2D; behaviour is driven by an array of EnemyBehavior resources.
## The inherited `name` property serves as the unit_id for BattlefieldManager.
## Requirements: 17.1, 17.3
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
func take_damage(amount: int) -> void:
	var absorbed: int = min(block, amount)
	block -= absorbed
	amount -= absorbed
	if amount <= 0:
		return
	var effective: int = roundi(amount * damage_multiplier)
	hp = max(0, hp - effective)

## Returns true if the Enemy still has HP remaining.
func is_alive() -> bool:
	return hp > 0
