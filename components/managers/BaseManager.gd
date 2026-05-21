## BaseManager — tracks Base health and manages the out-of-combat phase.
## Advances seasons, triggers combat every seasons_per_combat turns,
## generates weighted-random events, and applies event outcomes to GameState.
extends Node
class_name BaseManager

## Maximum HP of the Base.
@export var max_base_hp: int = 20

## Number of seasons between each combat encounter.
@export var seasons_per_combat: int = 4

## Pool of RandomEvent resources available for selection each season.
@export var event_pool: Array[RandomEvent] = []

## Current HP of the Base.
var current_hp: int

## Current season number (starts at 0; incremented by advance_season).
var current_season: int = 0

## EventBus instance used for emitting events.
## Defaults to the EventBus autoload; can be overridden in tests with a local instance.
var _event_bus: Node = null

func _ready() -> void:
	current_hp = max_base_hp
	_event_bus = EventBus

func _emit(event_name: String, payload: Dictionary) -> void:
	if _event_bus != null:
		_event_bus.emit(event_name, payload)

## Advance the season by 1, emit season_advanced, and trigger combat if needed.
func advance_season() -> void:
	current_season += 1
	_emit("season_advanced", { "season": current_season })
	if current_season % seasons_per_combat == 0:
		_emit("combat_triggered", {})

## Generate a weighted-random selection of 0–3 RandomEvent resources from event_pool.
## Uses the event's `weight` property if present; otherwise treats all events equally.
func generate_events() -> Array[RandomEvent]:
	if event_pool.is_empty():
		return []

	# Determine how many events to return (0 to 3, capped by pool size).
	var count: int = randi() % min(4, event_pool.size() + 1)
	if count == 0:
		return []

	# Build a working copy so we can sample without replacement.
	var available: Array = event_pool.duplicate()
	var selected: Array[RandomEvent] = []

	for _i in range(count):
		if available.is_empty():
			break

		# Compute total weight.
		var total_weight: float = 0.0
		for ev in available:
			if ev.get("weight") != null:
				total_weight += float(ev.weight)
			else:
				total_weight += 1.0

		# Pick a random point in [0, total_weight).
		var roll: float = randf() * total_weight
		var cumulative: float = 0.0
		var chosen: RandomEvent = null
		for ev in available:
			var w: float = 1.0
			if ev.get("weight") != null:
				w = float(ev.weight)
			cumulative += w
			if roll < cumulative:
				chosen = ev
				break

		# Fallback: pick last element if floating-point rounding missed.
		if chosen == null:
			chosen = available.back()

		selected.append(chosen)
		available.erase(chosen)

	return selected

## Apply the outcome of a player's choice within a RandomEvent.
## If the chosen EventChoice has an item_reward, it is added to GameState inventory.
func apply_event_outcome(event: RandomEvent, choice_index: int) -> void:
	if event == null:
		return
	if choice_index < 0 or choice_index >= event.choices.size():
		return
	var choice: EventChoice = event.choices[choice_index]
	if choice == null:
		return
	if choice.item_reward != null:
		GameState.add_item(choice.item_reward)

## Modify the Base's HP by delta (positive = heal, negative = damage).
## Clamps result to [0, max_base_hp] and emits base_health_changed.
func modify_hp(delta: int) -> void:
	current_hp = clamp(current_hp + delta, 0, max_base_hp)
	_emit("base_health_changed", { "current_hp": current_hp, "max_hp": max_base_hp })
