extends Resource
class_name EnemyBehavior

## Execute this behavior for one enemy turn.
## context keys: "enemy", "mech", "battlefield_manager", "ap_manager", "event_bus"
func decide(context: Dictionary) -> void:
	pass  # override in subclasses
