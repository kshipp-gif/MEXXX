extends EnemyBehavior
class_name MoveTowardBaseBehavior

## Moves the enemy one tile toward the Base end (x = 0) each turn.
## Requirements: 8.4, 17.1

func decide(context: Dictionary) -> void:
	var enemy = context["enemy"]
	var bm = context["battlefield_manager"]

	var unit_id: StringName = enemy.name
	var current_pos: Vector2i = bm.get_position(unit_id)

	# Already at the Base end — nothing to do.
	if current_pos.x == 0:
		return

	# Try to step one tile toward x = 0 (same row first).
	var preferred: Vector2i = Vector2i(current_pos.x - 1, current_pos.y)
	if bm.is_tile_free(preferred):
		bm.move_unit(unit_id, preferred)
		return

	# Preferred tile is blocked — try adjacent rows (y - 1, then y + 1).
	var alt_up: Vector2i = Vector2i(current_pos.x - 1, current_pos.y - 1)
	if bm.is_tile_free(alt_up):
		bm.move_unit(unit_id, alt_up)
		return

	var alt_down: Vector2i = Vector2i(current_pos.x - 1, current_pos.y + 1)
	if bm.is_tile_free(alt_down):
		bm.move_unit(unit_id, alt_down)
		return

	# All forward tiles are blocked; enemy cannot advance this turn.
