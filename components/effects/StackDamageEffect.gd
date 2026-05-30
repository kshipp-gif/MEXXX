## StackDamageEffect — deals damage equal to the target's stacks of a given status effect.
## Optionally applies a multiplier to the stack count.
##
## Examples:
##   - "Detonate Acid": status_name = "acid", multiplier = 1.0 → deals damage = acid stacks
##   - "Exploit Weakness": status_name = "vulnerable", multiplier = 2.0 → deals 2x vuln stacks
extends Effect
class_name StackDamageEffect

## The status_name to read stacks from on the target.
@export var status_name: String = ""

## Multiplier applied to the stack count. Default 1.0 (damage = stacks).
@export var multiplier: float = 1.0

func execute(context: Dictionary) -> void:
	var target = context.get("target")
	if target == null or not target.has_method("take_damage"):
		return
	if status_name == "":
		return

	# Find the target's StatusEffectManager and read stacks.
	var stacks: int = 0
	for child in target.get_children():
		if child is StatusEffectManager:
			for effect in child.get_active_effects():
				if effect.status_name == status_name:
					stacks = effect.stacks
					break
			break

	if stacks <= 0:
		return

	var damage: int = max(1, roundi(stacks * multiplier))
	var caster = context.get("caster")
	target.take_damage(damage, caster)
