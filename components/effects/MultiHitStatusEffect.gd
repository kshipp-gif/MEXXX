## MultiHitStatusEffect — deals damage multiple times and optionally applies a status
## effect to the target after each hit. Generalizes any "hit N times + apply debuff per hit" pattern.
##
## Examples:
##   - Crossfang Strike: damage=3, hits=3, status=VulnerableEffect
##   - Poison Barrage: damage=2, hits=4, status=PoisonEffect
##   - Pure multi-hit: damage=5, hits=2, status=null (same as MultiHitDamageEffect)
extends Effect
class_name MultiHitStatusEffect

## Damage dealt per hit.
@export var damage_per_hit: int = 0

## Number of times to hit.
@export var hits: int = 1

## Optional status effect to apply after each hit. Duplicated per application.
## Leave null for pure damage with no status.
@export var status_effect: StatusEffect = null

## Who receives the status effect: "target" or "caster".
@export var status_target: String = "target"

func execute(context: Dictionary) -> void:
	var target = context.get("target")
	if target == null or not target.has_method("take_damage"):
		return

	var caster = context.get("caster")

	for _i in range(hits):
		# Stop hitting if target is dead.
		if target.has_method("is_alive") and not target.is_alive():
			break

		# Deal damage.
		target.take_damage(damage_per_hit, caster)

		# Apply status effect if configured.
		if status_effect != null:
			var unit = target if status_target == "target" else caster
			if unit != null:
				var mgr: StatusEffectManager = _get_status_manager(unit)
				if mgr != null:
					mgr.add_effect(status_effect.duplicate())


func _get_status_manager(unit: Node) -> StatusEffectManager:
	for child in unit.get_children():
		if child is StatusEffectManager:
			return child
	return null
