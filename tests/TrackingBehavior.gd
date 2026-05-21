## Helper script for property tests.
## Records the index of this behavior into a shared log array when decide() is called.
## Used by test_property_20_enemy_behaviors_in_order.gd to verify execution order.
extends EnemyBehavior

## The index assigned to this behavior instance (set before calling decide()).
var index: int = 0

## Shared log array injected from the test; each decide() appends self.index.
var log: Array = []

func decide(_context: Dictionary) -> void:
	log.append(index)
