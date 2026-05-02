## Deals a fixed amount of damage to the target unit.
## Requirements: 16.1, 16.2, 16.3, 16.4, 16.5
extends Effect
class_name DamageEffect

## Amount of damage to deal to the target.
@export var amount: int = 0

## Calls target.take_damage(amount) if the target supports that method.
func execute(context: Dictionary) -> void:
	if not context.has("target"):
		return
	var target = context["target"]
	if target != null and target.has_method("take_damage"):
		target.take_damage(amount)
