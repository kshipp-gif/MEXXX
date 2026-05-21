## Base class for all card Effects in the MEXXX Mech Deckbuilder.
## Effects are Resource subclasses executed when a Card is played.
## Subclasses override execute() to implement specific behaviour.
extends Resource
class_name Effect

## Execute this effect using the provided context dictionary.
## context keys: "caster", "target", "battlefield_manager",
##               "ap_manager", "deck_manager", "event_bus", "caster_id", "target_pos"
## Override in subclasses to implement specific behaviour.
func execute(context: Dictionary) -> void:
	pass  # no-op override point
