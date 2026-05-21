## APManager — tracks and manages Action Points for the Mech during combat.
## Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7
extends Node

@export var max_ap: int = 4
var current_ap: int = 0

## EventBus instance used for emitting events.
## Defaults to the EventBus autoload; can be overridden in tests with a local instance.
var _event_bus: Node = null

func _ready() -> void:
	_event_bus = EventBus

func _emit(event_name: String, payload: Dictionary) -> void:
	if _event_bus != null:
		_event_bus.emit(event_name, payload)

## Reset AP to max at the start of a player turn; emit ap_changed.
func reset() -> void:
	current_ap = max_ap
	_emit("ap_changed", { "current_ap": current_ap, "max_ap": max_ap })

## Spend amount AP if sufficient; emit ap_changed and return true.
## If insufficient, emit action_rejected and return false without changing AP.
func spend(amount: int) -> bool:
	if amount > current_ap:
		_emit("action_rejected", { "reason": "insufficient_ap" })
		return false
	current_ap -= amount
	_emit("ap_changed", { "current_ap": current_ap, "max_ap": max_ap })
	return true

## Grant amount AP, capped at max_ap; emit ap_changed.
func grant(amount: int) -> void:
	current_ap = min(current_ap + amount, max_ap)
	_emit("ap_changed", { "current_ap": current_ap, "max_ap": max_ap })
