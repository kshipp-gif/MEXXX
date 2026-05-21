## RetaliationEffect — when the affected unit takes damage from an attacker,
## the attacker receives 1 damage per stack of Retaliation.
## Stacks are tracked via the StatusEffectManager's additive duration system:
## each application adds to duration, and duration == number of stacks.
## Requirements: status-effects
extends StatusEffect
class_name RetaliationEffect

func _init() -> void:
	status_name = "retaliation"

## No persistent property to set — retaliation is checked reactively in take_damage().
func apply(_unit: Node) -> void:
	pass

func remove(_unit: Node) -> void:
	pass
