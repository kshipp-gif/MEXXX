## Manages active StatusEffects on a single unit (host).
## Attach as a child Node to any unit that should support status effects.
## Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9
extends Node
class_name StatusEffectManager

## The unit node this manager is attached to. Set automatically in _ready().
var _host: Node = null

## List of currently active StatusEffect resources.
var _active_effects: Array = []

## EventBus instance used for emitting events.
## Defaults to the EventBus autoload; can be overridden in tests with a local instance.
var _event_bus: Node = null

func _ready() -> void:
	_host = get_parent()
	_event_bus = EventBus

## Emit a named event via the configured EventBus.
func _emit(event_name: String, payload: Dictionary) -> void:
	if _event_bus != null:
		_event_bus.emit(event_name, payload)

## Add a StatusEffect to the active list.
## If an effect with the same status_name already exists, ADD the new duration
## to the existing duration (do NOT call apply() again). Otherwise append and call apply().
## Emits status_effect_applied in both cases.
func add_effect(effect: StatusEffect) -> void:
	for existing in _active_effects:
		if existing.status_name == effect.status_name:
			existing.duration += effect.duration
			_emit("status_effect_applied", {
				"unit": _host,
				"status_name": effect.status_name,
				"duration": existing.duration
			})
			return
	_active_effects.append(effect)
	effect.apply(_host)
	_emit("status_effect_applied", {
		"unit": _host,
		"status_name": effect.status_name,
		"duration": effect.duration
	})

## Tick all active effects; remove and call remove() on any that have expired.
## Emits status_effect_removed for each expired effect.
func tick_effects() -> void:
	for effect in _active_effects.duplicate():
		effect.tick()
		if effect.is_expired():
			effect.remove(_host)
			_active_effects.erase(effect)
			_emit("status_effect_removed", {
				"unit": _host,
				"status_name": effect.status_name
			})

## Returns true if an effect with the given name is currently active.
func has_effect(status_name: String) -> bool:
	for effect in _active_effects:
		if effect.status_name == status_name:
			return true
	return false

## Returns a shallow copy of the active effects list.
## Callers may not modify the returned array to affect internal state.
func get_active_effects() -> Array:
	return _active_effects.duplicate()
