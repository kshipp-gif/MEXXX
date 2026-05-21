## Applies a Passive resource to the target node.
extends Effect
class_name ApplyPassiveEffect

## The Passive resource to apply. Typed as Resource until Passive class is available.
@export var passive: Resource = null

## Calls passive.apply(target) if both passive and target are available in context.
func execute(context: Dictionary) -> void:
	if passive == null:
		return
	if not context.has("target"):
		return
	var target = context["target"]
	if target != null and passive.has_method("apply"):
		passive.apply(target)
