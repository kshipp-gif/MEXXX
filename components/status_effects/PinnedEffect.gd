## Status effect that prevents a unit from moving.
extends StatusEffect
class_name PinnedEffect

func _init() -> void:
	status_name = "pinned"

## Sets is_pinned = true on the unit, blocking movement.
func apply(unit: Node) -> void:
	unit.set("is_pinned", true)

## Restores is_pinned = false on the unit, re-enabling movement.
func remove(unit: Node) -> void:
	unit.set("is_pinned", false)
