## Base class for all Status Effects in the MEXXX Mech Deckbuilder.
## Status effects are temporary conditions applied to units, tracked by stacks.
##
## For most effects, stacks = duration (decrements by 1 each turn, removed at 0).
## Subclasses can override tick() to implement custom stack behavior
## (e.g., Acid uses stacks as damage and halves each turn).
extends Resource
class_name StatusEffect

## String identifier used for deduplication in StatusEffectManager.
## Set by subclasses in _init(). Not exported — subclasses own this value.
var status_name: String = ""

## Number of stacks. For most effects this is the duration (turns remaining).
## Subclasses may interpret stacks differently (e.g., damage amount).
@export var stacks: int = 1

## Activate this effect's modifier on the target unit.
## Subclasses set properties on the unit (e.g. unit.is_pinned = true).
func apply(unit: Node) -> void:
	pass  # no-op override point

## Reverse this effect's modifier on the target unit.
## Subclasses restore the properties they set in apply().
func remove(unit: Node) -> void:
	pass  # no-op override point

## Called each turn by StatusEffectManager.tick_effects().
## Default behavior: decrement stacks by 1 (acts as duration countdown).
## Subclasses override this for custom behavior (e.g., deal damage then halve stacks).
func tick() -> void:
	stacks -= 1

## Returns true when the effect should be removed (stacks <= 0).
func is_expired() -> bool:
	return stacks <= 0
