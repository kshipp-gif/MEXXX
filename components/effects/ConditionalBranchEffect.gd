## ConditionalBranchEffect — executes one of two sub-effects based on a caster flag.
## Used by Shed Skin: if already attacked this turn → gain 2 AP, else → draw 2 cards.
extends Effect
class_name ConditionalBranchEffect

## The name of a boolean property on the caster node to check.
@export var caster_flag: String = ""

## Effect to execute if the condition is true.
@export var effect_if_true: Effect = null

## Effect to execute if the condition is false.
@export var effect_if_false: Effect = null

func execute(context: Dictionary) -> void:
	var caster = context.get("caster")
	if caster == null:
		return

	var condition_met: bool = false
	if caster_flag != "" and caster_flag in caster:
		condition_met = (caster.get(caster_flag) == true)

	if condition_met and effect_if_true != null:
		effect_if_true.execute(context)
	elif not condition_met and effect_if_false != null:
		effect_if_false.execute(context)
