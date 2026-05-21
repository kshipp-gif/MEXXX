## Represents a single choice within a RandomEvent in the MEXXX Mech Deckbuilder.
## Each choice has a label shown to the player, an optional item reward,
## and an optional custom outcome script.
## Requirements: 12.3, 12.4
extends Resource
class_name EventChoice

@export var label: String = ""
@export var item_reward: Item = null          # null if no item reward
@export var outcome_script: GDScript = null   # optional custom outcome
