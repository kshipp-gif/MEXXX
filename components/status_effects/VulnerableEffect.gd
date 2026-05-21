## Status effect that increases damage received by 25%.
## Requirements: 6.1, 6.3
extends StatusEffect
class_name VulnerableEffect

func _init() -> void:
	status_name = "vulnerable"

## Sets damage_multiplier = 1.25 on the unit, increasing damage taken.
func apply(unit: Node) -> void:
	unit.set("damage_multiplier", 1.25)

## Restores damage_multiplier = 1.0 on the unit.
func remove(unit: Node) -> void:
	unit.set("damage_multiplier", 1.0)
