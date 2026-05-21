## Base class for all Status Effects in the MEXXX Mech Deckbuilder.
## Status effects are temporary, turn-counted conditions applied to units.
## Subclasses override apply() and remove() to implement specific modifiers.
extends Resource
class_name StatusEffect

## String identifier used for deduplication in StatusEffectManager.
## Set by subclasses in _init(). Not exported — subclasses own this value.
var status_name: String = ""

## Number of turns remaining. Decremented by tick(). Effect expires when 0.
@export var duration: int = 1

## Activate this effect's modifier on the target unit.
## Subclasses set properties on the unit (e.g. unit.is_pinned = true).
func apply(unit: Node) -> void:
	pass  # no-op override point

## Reverse this effect's modifier on the target unit.
## Subclasses restore the properties they set in apply().
func remove(unit: Node) -> void:
	pass  # no-op override point

## Decrement duration by 1. Called by StatusEffectManager.tick_effects().
func tick() -> void:
	duration -= 1

## Returns true when the effect has expired (duration <= 0).
func is_expired() -> bool:
	return duration <= 0
