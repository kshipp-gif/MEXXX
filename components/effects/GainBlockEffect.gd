## Grants block to the target unit, scaled by the unit's block_multiplier.
## Block is floored (not rounded) and clamped to a minimum of 0.
## Requirements: 8.1, 8.5, 8.6, 8.7
extends Effect
class_name GainBlockEffect

## Base amount of block to grant before applying the unit's block_multiplier.
@export var amount: int = 0

## Adds block to the target unit, applying block_multiplier (e.g. 0.5 when Brittle).
func execute(context: Dictionary) -> void:
	var unit = context.get("target")
	if unit == null:
		return
	var multiplier: float = unit.get("block_multiplier") if unit.get("block_multiplier") != null else 1.0
	var final_block: int = max(0, floori(amount * multiplier))
	var current_block = unit.get("block")
	unit.set("block", (current_block if current_block != null else 0) + final_block)
