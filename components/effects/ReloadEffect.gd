## Reloads the ammo on the caster's source item.
extends Effect
class_name ReloadEffect

## Calls caster.source_item.reload_ammo() if caster and source_item are available.
func execute(context: Dictionary) -> void:
	if not context.has("caster"):
		return
	var caster = context["caster"]
	if caster == null:
		return
	if not "source_item" in caster:
		return
	var source_item = caster.source_item
	if source_item != null and source_item.has_method("reload_ammo"):
		source_item.reload_ammo()
