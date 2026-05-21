## EventBus autoload singleton for MEXXX Mech Deckbuilder.
## Routes named game signals between Components without direct references.
extends Node

# Internal registry: event_name -> Array[Callable]
var _listeners: Dictionary = {}

## Subscribe a callable to a named event.
func subscribe(event_name: String, callable: Callable) -> void:
	if not _listeners.has(event_name):
		_listeners[event_name] = []
	_listeners[event_name].append(callable)

## Unsubscribe a callable from a named event.
func unsubscribe(event_name: String, callable: Callable) -> void:
	if _listeners.has(event_name):
		_listeners[event_name].erase(callable)

## Emit a named event with an arbitrary payload dictionary.
## Silently ignores events with no subscribers.
func emit(event_name: String, payload: Dictionary = {}) -> void:
	if not _listeners.has(event_name):
		return  # silently ignore unknown event names
	for cb in _listeners[event_name]:
		cb.call(payload)
