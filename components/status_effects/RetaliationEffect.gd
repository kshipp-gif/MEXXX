## RetaliationEffect — when the affected unit takes damage from an attacker,
## the attacker receives damage equal to the number of stacks.
## Consumed after firing once (stacks set to 0 by _trigger_retaliation).
## If not triggered during the enemy turn, removed on the next tick (all stacks zeroed).
extends StatusEffect
class_name RetaliationEffect

func _init() -> void:
	status_name = "retaliation"

func apply(_unit: Node) -> void:
	pass

func remove(_unit: Node) -> void:
	pass

## Wipe all stacks on tick — Retaliation only lasts one turn.
func tick() -> void:
	stacks = 0
