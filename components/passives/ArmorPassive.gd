## Passive that adds a flat armor bonus to the target node.
## Adds armor_amount to target.armor_bonus on apply,
## and subtracts it on remove.
## Requirements: 11.1, 11.2, 11.3, 11.4
extends Passive
class_name ArmorPassive

## The flat armor bonus to add/remove from the target.
@export var armor_amount: int = 0

## Adds armor_amount to target.armor_bonus.
## If the property does not exist on the target it is treated as 0.
func apply(target: Node) -> void:
	var current: int = target.get("armor_bonus") if target.get("armor_bonus") != null else 0
	target.set("armor_bonus", current + armor_amount)

## Removes armor_amount from target.armor_bonus.
func remove(target: Node) -> void:
	var current: int = target.get("armor_bonus") if target.get("armor_bonus") != null else 0
	target.set("armor_bonus", current - armor_amount)
