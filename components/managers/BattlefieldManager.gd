## BattlefieldManager — tracks unit positions on the square-tile grid.
extends Node

@export var grid_width: int = 8
@export var grid_height: int = 6

# StringName -> Vector2i
var _positions: Dictionary = {}

# StringName -> Node (optional; populated by place_unit when a node is provided)
var _unit_nodes: Dictionary = {}

## EventBus instance used for emitting events.
## Defaults to the EventBus autoload; can be overridden in tests with a local instance.
var _event_bus: Node = null

func _ready() -> void:
	_event_bus = EventBus

## Emit a named event via the configured EventBus.
func _emit(event_name: String, payload: Dictionary) -> void:
	if _event_bus != null:
		_event_bus.emit(event_name, payload)

## Register a unit at a starting position (no validation).
## Optionally associate a unit_node for is_pinned checks in move_unit().
func place_unit(unit_id: StringName, pos: Vector2i, unit_node: Node = null) -> void:
	_positions[unit_id] = pos
	_unit_nodes[unit_id] = unit_node

## Return the Node associated with unit_id, or null if none was registered.
func _get_unit_node(unit_id: StringName) -> Node:
	return _unit_nodes.get(unit_id, null)

## Attempt to move unit to dest; validate bounds and occupancy.
## Emits move_rejected on failure; returns false.
func move_unit(unit_id: StringName, dest: Vector2i) -> bool:
	# Reject move if the unit is pinned
	var unit = _get_unit_node(unit_id)
	if unit != null and unit.get("is_pinned") == true:
		_emit("move_rejected", {
			"from": _positions.get(unit_id, Vector2i(-1, -1)),
			"to": dest,
			"reason": "unit_pinned"
		})
		return false
	if dest.x < 0 or dest.x >= grid_width or dest.y < 0 or dest.y >= grid_height:
		_emit("move_rejected", {
			"from": _positions.get(unit_id, Vector2i(-1, -1)),
			"to": dest,
			"reason": "out_of_bounds"
		})
		return false
	if not is_tile_free(dest):
		_emit("move_rejected", {
			"from": _positions.get(unit_id, Vector2i(-1, -1)),
			"to": dest,
			"reason": "tile_occupied"
		})
		return false
	_positions[unit_id] = dest
	return true

## Return Chebyshev distance between two tile coordinates.
func tile_distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

## Validate that target is within range_val tiles (Chebyshev) from caster.
## Emits action_rejected { reason: "out_of_range" } on failure.
func validate_range(caster_id: StringName, target: Vector2i, range_val: int) -> bool:
	var caster_pos: Vector2i = _positions.get(caster_id, Vector2i(0, 0))
	if tile_distance(caster_pos, target) > range_val:
		_emit("action_rejected", { "reason": "out_of_range" })
		return false
	return true

## Return the registered position of a unit (defaults to (0,0) if unknown).
func get_position(unit_id: StringName) -> Vector2i:
	return _positions.get(unit_id, Vector2i(0, 0))

## Return true if no unit currently occupies pos.
func is_tile_free(pos: Vector2i) -> bool:
	for uid in _positions:
		if _positions[uid] == pos:
			return false
	return true
