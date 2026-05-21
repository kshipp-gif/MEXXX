## ConditionalRepeatEffect — re-executes a sibling effect if a condition is met.
## By default repeats the effect immediately before this one in the card's effects array.
## Because it re-executes the same effect instance with the same context, any runtime
## buffs (attack multipliers, etc.) that affected the original hit apply equally to the repeat.
##
## Usage on Riposte:
##   effects[0] = DamageEffect { amount = 4 }
##   effects[1] = ConditionalRepeatEffect {
##       caster_flag = "took_damage_last_enemy_turn"
##       repeat_index = 0   (optional — defaults to the effect just before this one)
##   }
extends Effect
class_name ConditionalRepeatEffect

## The name of a boolean property on the caster node to check.
## If the property is true, the target effect is re-executed.
@export var caster_flag: String = ""

## Index of the effect in the card's effects array to repeat.
## -1 means "the effect immediately before this one" (default).
## Any other value is a literal array index (0, 1, 2, ...).
@export var repeat_index: int = -1

func execute(context: Dictionary) -> void:
	if caster_flag == "":
		return

	var caster = context.get("caster")
	if caster == null:
		return

	if caster.get(caster_flag) != true:
		return

	# Resolve which effect to repeat.
	var effects: Array = context.get("card_effects", [])
	var this_index: int = context.get("current_effect_index", -1)

	var target_index: int = repeat_index
	if target_index == -1:
		# Default: the effect immediately before this one.
		target_index = this_index - 1

	if target_index < 0 or target_index >= effects.size():
		push_warning("ConditionalRepeatEffect: repeat_index %d is out of range." % target_index)
		return

	effects[target_index].execute(context)
