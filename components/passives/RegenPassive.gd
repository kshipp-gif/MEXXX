## Passive that adds a per-turn HP regeneration bonus to the target node.
## Adds regen_amount to target.regen_per_turn on apply,
## and subtracts it on remove.
extends Passive
class_name RegenPassive

## The per-turn HP regeneration amount to add/remove from the target.
@export var regen_amount: int = 0

## Adds regen_amount to target.regen_per_turn.
## If the property does not exist on the target it is treated as 0.
func apply(target: Node) -> void:
	var current: int = target.get("regen_per_turn") if target.get("regen_per_turn") != null else 0
	target.set("regen_per_turn", current + regen_amount)

## Removes regen_amount from target.regen_per_turn.
func remove(target: Node) -> void:
	var current: int = target.get("regen_per_turn") if target.get("regen_per_turn") != null else 0
	target.set("regen_per_turn", current - regen_amount)
