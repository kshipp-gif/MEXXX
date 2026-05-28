## NextAttackBuffEffect — applies a damage multiplier to the caster's next attack this turn.
## The buff is stored on the caster as `next_attack_multiplier` and should be consumed
## by the damage pipeline when the next attack is dealt. Expires at end of turn if unused.
##
## Examples:
##   - Slither: multiplier=1.2 (next attack deals 20% more)
##   - Power Charge: multiplier=1.5 (next attack deals 50% more)
##   - Precision: multiplier=2.0 (next attack deals double)
extends Effect
class_name NextAttackBuffEffect

## Damage multiplier applied to the next attack this turn.
@export var multiplier: float = 1.0

func execute(context: Dictionary) -> void:
	var caster = context.get("caster")
	if caster == null:
		return
	caster.set("next_attack_multiplier", multiplier)
	caster.set("next_attack_multiplier_expires_end_of_turn", true)
