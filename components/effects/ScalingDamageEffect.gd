## ScalingDamageEffect — deals base damage plus a flat bonus per damage instance dealt this turn.
## Used by Serpent Strike: deal 2 + 1 per previous damage instance this turn.
extends Effect
class_name ScalingDamageEffect

## Base damage dealt.
@export var base_amount: int = 2

## Bonus damage per damage instance dealt this turn.
@export var bonus_per_hit: int = 1

func execute(context: Dictionary) -> void:
	var target = context.get("target")
	if target == null or not target.has_method("take_damage"):
		return

	var caster = context.get("caster")

	# Count how many times we've dealt damage this turn (tracked on caster).
	var hits_this_turn: int = 0
	if caster != null and "damage_instances_this_turn" in caster:
		hits_this_turn = caster.damage_instances_this_turn

	var total_damage: int = base_amount + (bonus_per_hit * hits_this_turn)
	target.take_damage(total_damage, caster)

	# Increment the counter after dealing damage.
	if caster != null and "damage_instances_this_turn" in caster:
		caster.damage_instances_this_turn += 1
