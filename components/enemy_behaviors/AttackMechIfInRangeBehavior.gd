extends EnemyBehavior
class_name AttackMechIfInRangeBehavior

## Attacks the Mech if it is within attack_range tiles (Chebyshev distance).
## Requirements: 8.4, 17.1

@export var attack_range: int = 1
@export var damage: int = 1

func decide(context: Dictionary) -> void:
	var enemy = context["enemy"]
	var mech = context["mech"]
	var bm = context["battlefield_manager"]

	var enemy_pos: Vector2i = bm.get_position(enemy.name)
	var mech_pos: Vector2i = bm.get_position(mech.name)

	if bm.tile_distance(enemy_pos, mech_pos) <= attack_range:
		mech.take_damage(damage)
