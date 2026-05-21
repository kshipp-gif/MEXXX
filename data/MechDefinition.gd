## MechDefinition — data resource describing a selectable Mech type.
## Authored in the Godot editor and referenced by CharacterSelectScreen.
extends Resource
class_name MechDefinition

## Internal identifier used to distinguish mech types in code.
@export var mech_id: String = ""

## Human-readable name shown on the character select screen.
@export var display_name: String = ""

## Short description shown on the character select screen.
@export var description: String = ""

## Items the player starts with when this mech is chosen.
## Typed as Array[Resource] to avoid circular class dependency; at runtime these are Item instances.
## These are added to GameState.inventory at run start.
@export var starting_items: Array[Resource] = []

func _init() -> void:
	starting_items = []
