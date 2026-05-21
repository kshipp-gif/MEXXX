## Moves the caster N tiles toward the target via BattlefieldManager.
extends Effect
class_name MoveEffect

## Number of tiles to move.
@export var tiles: int = 1

## Calls battlefield_manager.move_unit(caster_id, target_pos) if available in context.
func execute(context: Dictionary) -> void:
	if not context.has("battlefield_manager"):
		return
	var battlefield_manager = context["battlefield_manager"]
	if battlefield_manager == null:
		return
	if not context.has("caster_id") or not context.has("target_pos"):
		return
	battlefield_manager.move_unit(context["caster_id"], context["target_pos"])
