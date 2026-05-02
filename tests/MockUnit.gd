## Mock unit node for status-effect property tests.
## Declares the modifier properties that StatusEffect subclasses read and write,
## plus stat properties used by Passive tests.
extends Node

var is_pinned: bool = false
var block_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var block: int = 0
var armor_bonus: int = 0
var regen_per_turn: int = 0
