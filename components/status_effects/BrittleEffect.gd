## Status effect that halves the armor a unit gains from card effects.
extends StatusEffect
class_name BrittleEffect

func _init() -> void:
	status_name = "brittle"

## Sets armor_multiplier = 0.5 on the unit, halving armor gains.
func apply(unit: Node) -> void:
	unit.set("armor_multiplier", 0.5)

## Restores armor_multiplier = 1.0 on the unit.
func remove(unit: Node) -> void:
	unit.set("armor_multiplier", 1.0)
