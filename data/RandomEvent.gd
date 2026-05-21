## Represents a random narrative event in the MEXXX Mech Deckbuilder.
## Events present the player with a description and one or more choices.
extends Resource
class_name RandomEvent

@export var description: String = ""
@export var choices: Array[EventChoice] = []
