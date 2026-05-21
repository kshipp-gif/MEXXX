## Deals a fixed amount of damage to the target unit.
extends Effect
class_name DamageEffect

## Amount of damage to deal to the target.
@export var amount: int = 0

## Calls target.take_damage(amount, caster) if the target supports that method.
## Passing caster allows the target to trigger retaliation effects.
func execute(context: Dictionary) -> void:
	if not context.has("target"):
		return
	var target = context["target"]
	var caster = context.get("caster")
	if target != null and target.has_method("take_damage"):
		target.take_damage(amount, caster)
