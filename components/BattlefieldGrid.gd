## BattlefieldGrid — renders the tactical grid and manages unit sprite positions.
class_name BattlefieldGrid
extends Node2D

## Exported configuration
@export var tile_size: int = 48
@export var grid_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var grid_line_width: float = 2.0

## Reference to BattlefieldManager (wired in CombatScene._ready)
var battlefield_manager: Node = null:
	set(value):
		battlefield_manager = value
		if is_inside_tree():
			queue_redraw()

## Maps unit_id (StringName) to its Sprite2D node for quick lookup
var _unit_sprites: Dictionary = {}

## Middle-mouse panning state
var _panning: bool = false
var _pan_start: Vector2 = Vector2.ZERO

## Zoom state
const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 1.0
const ZOOM_STEP: float = 0.1
var _zoom: float = 1.0


## Lifecycle — subscribe to EventBus events when entering the tree.
func _ready() -> void:
	EventBus.subscribe("unit_placed", _on_unit_placed)
	EventBus.subscribe("unit_moved", _on_unit_moved)


## Lifecycle — unsubscribe from EventBus events when exiting the tree.
func _exit_tree() -> void:
	EventBus.unsubscribe("unit_placed", _on_unit_placed)
	EventBus.unsubscribe("unit_moved", _on_unit_moved)


## Handle middle-mouse-button panning and scroll-wheel zoom.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_panning = true
				_pan_start = event.position
			else:
				_panning = false
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = minf(_zoom + ZOOM_STEP, ZOOM_MAX)
			scale = Vector2(_zoom, _zoom)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = maxf(_zoom - ZOOM_STEP, ZOOM_MIN)
			scale = Vector2(_zoom, _zoom)
	elif event is InputEventMouseMotion and _panning:
		var delta: Vector2 = event.position - _pan_start
		position += delta
		_pan_start = event.position


## Handler for unit_placed events.
func _on_unit_placed(payload: Dictionary) -> void:
	var unit_id: StringName = payload["unit_id"]
	var pos: Vector2i = payload["pos"]
	var side: String = payload["side"]
	add_unit_sprite(unit_id, pos, side)


## Handler for unit_moved events.
func _on_unit_moved(payload: Dictionary) -> void:
	var unit_id: StringName = payload["unit_id"]
	var to: Vector2i = payload["to"]
	move_unit_sprite(unit_id, to)


## Convert grid coordinates to world pixel position (center of tile).
## Out-of-bounds positions are clamped to valid range with a warning.
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var clamped := grid_pos
	if battlefield_manager != null:
		var max_x: int = battlefield_manager.grid_width - 1
		var max_y: int = battlefield_manager.grid_height - 1
		if grid_pos.x < 0 or grid_pos.x > max_x or grid_pos.y < 0 or grid_pos.y > max_y:
			clamped = Vector2i(
				clampi(grid_pos.x, 0, max_x),
				clampi(grid_pos.y, 0, max_y)
			)
			push_warning(
				"BattlefieldGrid: grid_to_world received out-of-bounds position %s, clamped to %s"
				% [grid_pos, clamped]
			)
	return Vector2(
		clamped.x * tile_size + tile_size / 2.0,
		clamped.y * tile_size + tile_size / 2.0
	)


## Convert world pixel position to grid coordinates.
## Out-of-bounds positions are clamped to valid range with a warning.
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var result := Vector2i(int(world_pos.x / tile_size), int(world_pos.y / tile_size))
	if battlefield_manager != null:
		var max_x: int = battlefield_manager.grid_width - 1
		var max_y: int = battlefield_manager.grid_height - 1
		if result.x < 0 or result.x > max_x or result.y < 0 or result.y > max_y:
			var clamped := Vector2i(
				clampi(result.x, 0, max_x),
				clampi(result.y, 0, max_y)
			)
			push_warning(
				"BattlefieldGrid: world_to_grid result %s out of bounds for world_pos %s, clamped to %s"
				% [result, world_pos, clamped]
			)
			result = clamped
	return result


## Draw the grid lines. Called automatically by Godot when queue_redraw() is triggered.
func _draw() -> void:
	if battlefield_manager == null:
		push_warning("BattlefieldGrid: battlefield_manager is not set, skipping grid draw.")
		return

	var w: int = battlefield_manager.grid_width
	var h: int = battlefield_manager.grid_height

	# Draw vertical lines
	for x in range(w + 1):
		var from := Vector2(x * tile_size, 0)
		var to := Vector2(x * tile_size, h * tile_size)
		draw_line(from, to, grid_color, grid_line_width)

	# Draw horizontal lines
	for y in range(h + 1):
		var from := Vector2(0, y * tile_size)
		var to := Vector2(w * tile_size, y * tile_size)
		draw_line(from, to, grid_color, grid_line_width)


## Create and position a unit sprite on the grid.
## If unit_id already exists, updates position instead of creating a duplicate.
func add_unit_sprite(unit_id: StringName, grid_pos: Vector2i, side: String) -> void:
	if _unit_sprites.has(unit_id):
		# Unit already exists — update position only
		var existing_sprite: Sprite2D = _unit_sprites[unit_id]
		existing_sprite.position = grid_to_world(grid_pos)
		return

	var sprite := Sprite2D.new()
	sprite.texture = load("res://icon.svg")
	var scale_factor: float = float(tile_size) / 128.0 * 0.8
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.position = grid_to_world(grid_pos)

	if side == "enemy":
		sprite.modulate = Color(1.0, 0.4, 0.4)
	else:
		sprite.modulate = Color(0.4, 0.6, 1.0)

	add_child(sprite)
	_unit_sprites[unit_id] = sprite


## Move an existing unit sprite to a new grid position.
## If unit_id is not found in the registry, emits a warning and returns.
func move_unit_sprite(unit_id: StringName, grid_pos: Vector2i) -> void:
	if not _unit_sprites.has(unit_id):
		push_warning("BattlefieldGrid: move_unit_sprite called with unknown unit_id '%s'" % unit_id)
		return

	var sprite: Sprite2D = _unit_sprites[unit_id]
	sprite.position = grid_to_world(grid_pos)


## Remove a unit sprite from the grid and free it from the scene tree.
## If unit_id is not found in the registry, emits a warning and returns.
func remove_unit_sprite(unit_id: StringName) -> void:
	if not _unit_sprites.has(unit_id):
		push_warning("BattlefieldGrid: remove_unit_sprite called with unknown unit_id '%s'" % unit_id)
		return

	var sprite: Sprite2D = _unit_sprites[unit_id]
	sprite.queue_free()
	_unit_sprites.erase(unit_id)
