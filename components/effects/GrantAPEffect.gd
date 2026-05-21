## Grants a fixed amount of Action Points via APManager.
extends Effect
class_name GrantAPEffect

## Amount of AP to grant.
@export var amount: int = 0

## Calls ap_manager.grant(amount) if ap_manager is present in context.
func execute(context: Dictionary) -> void:
	if not context.has("ap_manager"):
		return
	var ap_manager = context["ap_manager"]
	if ap_manager != null:
		ap_manager.grant(amount)
