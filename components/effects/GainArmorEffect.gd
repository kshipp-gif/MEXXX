## Grants armor to the target unit, scaled by the unit's armor_multiplier.
## Armor is floored (not rounded) and clamped to a minimum of 0.
extends Effect
class_name GainArmorEffect

## Base amount of armor to grant before applying the unit's armor_multiplier.
@export var amount: int = 0

## Adds armor to the target unit, applying armor_multiplier (e.g. 0.5 when Brittle).
func execute(context: Dictionary) -> void:
	var unit = context.get("target")
	if unit == null:
		return
	var multiplier: float = unit.get("armor_multiplier") if unit.get("armor_multiplier") != null else 1.0
	var final_armor: int = max(0, floori(amount * multiplier))
	var current_armor = unit.get("armor")
	unit.set("armor", (current_armor if current_armor != null else 0) + final_armor)
