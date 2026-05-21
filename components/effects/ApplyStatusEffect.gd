## Applies a StatusEffect resource to one or more targets when a card is played.
## target_type controls who receives the effect: "target", "caster", or "all_enemies".
extends Effect
class_name ApplyStatusEffect

## The StatusEffect resource to apply. Duplicated before each application so
## each target receives an independent instance.
@export var status_effect_resource: StatusEffect = null

## Who receives the effect.
## Valid values: "target", "caster", "all_enemies"
@export var target_type: String = "target"

## Execute the effect: resolve targets and apply a duplicate of the resource to each.
func execute(context: Dictionary) -> void:
	if status_effect_resource == null:
		push_warning("ApplyStatusEffect: status_effect_resource is null")
		return

	var targets: Array = _resolve_targets(context)
	for unit in targets:
		var mgr = _get_manager(unit)
		if mgr == null:
			push_warning("ApplyStatusEffect: unit %s has no StatusEffectManager" % str(unit))
			continue
		mgr.add_effect(status_effect_resource.duplicate())

## Resolve the list of target units from the context dictionary based on target_type.
func _resolve_targets(context: Dictionary) -> Array:
	match target_type:
		"target":
			var t = context.get("target")
			return [t] if t != null else []
		"caster":
			var c = context.get("caster")
			return [c] if c != null else []
		"all_enemies":
			var enemies = context.get("enemies", [])
			return enemies.filter(func(e): return e.has_method("is_alive") and e.is_alive())
		_:
			push_warning("ApplyStatusEffect: unknown target_type '%s'" % target_type)
			return []

## Find and return the StatusEffectManager child of the given unit node.
## Returns null if no StatusEffectManager child is found.
func _get_manager(unit: Node) -> StatusEffectManager:
	for child in unit.get_children():
		if child is StatusEffectManager:
			return child
	return null
