## Base class for all Passive components in the MEXXX Mech Deckbuilder.
## Passives are Resource subclasses applied to nodes (typically the Mech)
## when a Head Item is equipped, and removed when it is unequipped.
## Subclasses override apply() and remove() to implement specific behaviour.
## Requirements: 11.3, 11.4
extends Resource
class_name Passive

## Apply this passive's effect to the target node.
## Override in subclasses to implement specific stat modifications.
func apply(target: Node) -> void:
	pass  # no-op override point

## Remove this passive's effect from the target node.
## Override in subclasses to reverse the stat modifications made in apply().
func remove(target: Node) -> void:
	pass  # no-op override point
