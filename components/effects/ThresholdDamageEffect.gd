## ThresholdDamageEffect — deals base_amount damage normally.
## If the target's current HP is below hp_threshold_percent of their max HP,
## deals bonus_amount instead.
##
## Example — "Execute" style card:
##   base_amount = 4
##   bonus_amount = 10
##   hp_threshold_percent = 0.5   (50% HP)
##
## Works with any unit that has current HP and max HP properties.
## Mech uses current_hp / max_hp; Enemy uses hp / max_hp.
extends Effect
class_name ThresholdDamageEffect

## Damage dealt when the target is above the HP threshold.
@export var base_amount: int = 4

## Damage dealt when the target is at or below the HP threshold.
@export var bonus_amount: int = 10

## HP percentage threshold (0.0 – 1.0). Default 0.5 = 50%.
@export_range(0.0, 1.0, 0.05) var hp_threshold_percent: float = 0.5

func execute(context: Dictionary) -> void:
	var target = context.get("target")
	if target == null or not target.has_method("take_damage"):
		return

	var caster = context.get("caster")
	var damage: int = base_amount

	# Resolve current and max HP for either Mech (current_hp/max_hp) or Enemy (hp/max_hp).
	var current_hp = target.get("current_hp") if target.get("current_hp") != null else target.get("hp")
	var max_hp = target.get("max_hp")

	if current_hp != null and max_hp != null and max_hp > 0:
		var hp_ratio: float = float(current_hp) / float(max_hp)
		if hp_ratio <= hp_threshold_percent:
			damage = bonus_amount

	target.take_damage(damage, caster)
