## Restores a fixed amount of HP to the target unit.
## Requirements: 16.1, 16.2, 16.3, 16.4, 16.5
extends Effect
class_name HealEffect

## Amount of HP to restore to the target.
@export var amount: int = 0

## Calls target.heal(amount) if the target supports that method.
func execute(context: Dictionary) -> void:
	if not context.has("target"):
		return
	var target = context["target"]
	if target != null and target.has_method("heal"):
		target.heal(amount)
