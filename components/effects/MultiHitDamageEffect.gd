## MultiHitDamageEffect — deals damage to the target a fixed number of times.
## Each hit is independent: block, damage_multiplier, and retaliation apply per hit.
## Example: hits = 3, amount = 2 → three separate 2-damage hits.
extends Effect
class_name MultiHitDamageEffect

## Damage dealt per hit.
@export var amount: int = 0

## Number of times to hit.
@export var hits: int = 2

func execute(context: Dictionary) -> void:
	var target = context.get("target")
	if target == null or not target.has_method("take_damage"):
		return
	var caster = context.get("caster")
	for _i in range(hits):
		target.take_damage(amount, caster)
