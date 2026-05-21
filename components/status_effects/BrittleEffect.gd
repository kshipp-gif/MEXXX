## Status effect that halves the block a unit gains.
extends StatusEffect
class_name BrittleEffect

func _init() -> void:
	status_name = "brittle"

## Sets block_multiplier = 0.5 on the unit, halving block gains.
func apply(unit: Node) -> void:
	unit.set("block_multiplier", 0.5)

## Restores block_multiplier = 1.0 on the unit.
func remove(unit: Node) -> void:
	unit.set("block_multiplier", 1.0)
