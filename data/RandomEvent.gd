## Represents a random narrative event in the MEXXX Mech Deckbuilder.
## Events present the player with a description and one or more choices.
## Requirements: 12.3, 12.4, 13.1
extends Resource
class_name RandomEvent

@export var description: String = ""
@export var choices: Array[EventChoice] = []
