## Moves the enemy one tile toward the Mech each turn (Chebyshev step).
extends EnemyBehavior
class_name MoveTowardMechBehavior

func decide(context: Dictionary) -> void:
	var enemy = context["enemy"]
	var mech = context["mech"]
	var bm = context["battlefield_manager"]

	var unit_id: StringName = enemy.name
	var current_pos: Vector2i = bm.get_position(unit_id)
	var mech_pos: Vector2i = bm.get_position(&"mech")

	# Already adjacent or on top of mech — don't move.
	if bm.tile_distance(current_pos, mech_pos) <= 1:
		return

	# Compute direction toward mech (one step in each axis).
	var dx: int = signi(mech_pos.x - current_pos.x)
	var dy: int = signi(mech_pos.y - current_pos.y)

	# Try diagonal first, then cardinal directions.
	var candidates: Array[Vector2i] = []
	if dx != 0 and dy != 0:
		candidates.append(Vector2i(current_pos.x + dx, current_pos.y + dy))
	if dx != 0:
		candidates.append(Vector2i(current_pos.x + dx, current_pos.y))
	if dy != 0:
		candidates.append(Vector2i(current_pos.x, current_pos.y + dy))

	for dest in candidates:
		if bm.is_tile_free(dest):
			bm.move_unit(unit_id, dest)
			return
