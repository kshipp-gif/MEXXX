## Helper script for property tests.
## Records the index of this effect into a shared log array when executed.
## Used by test_property_19_effects_in_order.gd to verify execution order.
extends Effect

## The index assigned to this effect instance (set before executing).
var index: int = 0

## Shared log array injected from the test; each execute() appends self.index.
var log: Array = []

func execute(_context: Dictionary) -> void:
	log.append(index)
