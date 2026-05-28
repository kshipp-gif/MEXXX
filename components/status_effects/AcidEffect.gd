## Status effect that deals damage at the beginning of the enemies turn.
extends StatusEffect
class_name AcidEffect

@export var damage_per_tick: int = 1

var _host: Node = null

func _init() -> void:
	status_name = "acid"
	duration = 999

func apply(unit: Node) -> void:
	_host = unit

func remove(_unit: Node) -> void:
	_host = null

func tick() -> void:
	if _host != null:
		if "current_hp" in _host:
			_host.current_hp = max(0, _host.current_hp - damage_per_tick)
		elif "hp" in _host:
			_host.hp = max(0,_host.hp - damage_per_tick)
	if damage_per_tick <= 1:
		duration = 0
	else:
		damage_per_tick = damage_per_tick / 2

func is_expired() -> bool:
	return duration <= 0
