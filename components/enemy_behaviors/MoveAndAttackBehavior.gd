extends EnemyBehavior
class_name MoveAndAttackBehavior

## Composite behavior: moves toward the Base end (x = 0), then attacks the
## Mech if it is within attack_range tiles (Chebyshev distance).
## Requirements: 8.4, 17.4

@export var attack_range: int = 1
@export var damage: int = 1

func decide(context: Dictionary) -> void:
	_move(context)
	_attack(context)


## Move one tile toward x = 0 (same row preferred, then diagonals).
func _move(context: Dictionary) -> void:
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


## Attack the Mech if it is within attack_range (Chebyshev distance).
func _attack(context: Dictionary) -> void:
	var enemy = context["enemy"]
	var mech = context["mech"]
	var bm = context["battlefield_manager"]

	var enemy_pos: Vector2i = bm.get_position(enemy.name)
	var mech_pos: Vector2i = bm.get_position(mech.name)

	if bm.tile_distance(enemy_pos, mech_pos) <= attack_range:
		mech.take_damage(damage)
