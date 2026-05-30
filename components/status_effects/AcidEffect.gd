## AcidEffect — deals halving damage each turn, bypassing armor.
## Stacks = current damage amount. Halves (rounded down) each tick.
## Removed after ticking when stacks reach 1.
## Example: 10 → 5 → 2 → 1 (removed after dealing 1).
extends StatusEffect
class_name AcidEffect

## Stored reference to the unit this effect is on.
var _host: Node = null

func _init() -> void:
	status_name = "acid"

func apply(unit: Node) -> void:
	_host = unit

func remove(_unit: Node) -> void:
	_host = null

## Deal current stacks as damage directly to HP (bypasses armor), then halve stacks.
## If stacks was 1 this tick, it becomes 0 and is_expired() returns true.
func tick() -> void:
	if _host != null:
		if "current_hp" in _host:
			_host.current_hp = max(0, _host.current_hp - stacks)
		elif "hp" in _host:
			_host.hp = max(0, _host.hp - stacks)

	if stacks <= 1:
		stacks = 0
	else:
		stacks = stacks / 2
