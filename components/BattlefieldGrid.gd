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

## Tile selection state
var _selecting: bool = false
var _valid_tiles: Array[Vector2i] = []
var _hovered_tile: Vector2i = Vector2i(-1, -1)
const HIGHLIGHT_COLOR: Color = Color(1.0, 1.0, 0.0, 0.3)  # yellow, semi-transparent
const HOVER_COLOR: Color = Color(1.0, 1.0, 0.0, 0.6)  # brighter yellow for hovered tile


## Lifecycle — subscribe to EventBus events when entering the tree.
func _ready() -> void:
	EventBus.subscribe("unit_placed", _on_unit_placed)
	EventBus.subscribe("unit_moved", _on_unit_moved)
	EventBus.subscribe("tile_selection_started", _on_tile_selection_started)
	EventBus.subscribe("target_selection_started", _on_target_selection_started)
	EventBus.subscribe("tile_selection_completed", _on_tile_selection_ended)
	EventBus.subscribe("tile_selection_cancelled", _on_tile_selection_ended)


## Lifecycle — unsubscribe from EventBus events when exiting the tree.
func _exit_tree() -> void:
	EventBus.unsubscribe("unit_placed", _on_unit_placed)
	EventBus.unsubscribe("unit_moved", _on_unit_moved)
	EventBus.unsubscribe("tile_selection_started", _on_tile_selection_started)
	EventBus.unsubscribe("target_selection_started", _on_target_selection_started)
	EventBus.unsubscribe("tile_selection_completed", _on_tile_selection_ended)
	EventBus.unsubscribe("tile_selection_cancelled", _on_tile_selection_ended)


## Handle middle-mouse-button panning, scroll-wheel zoom, and tile selection clicks.
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
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _selecting:
			_handle_tile_click(event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and _selecting:
			# Right-click cancels tile selection
			_selecting = false
			_valid_tiles.clear()
			queue_redraw()
			EventBus.emit("tile_selection_cancelled", {})
	elif event is InputEventMouseMotion and _panning:
		var delta: Vector2 = event.position - _pan_start
		position += delta
		_pan_start = event.position
	elif event is InputEventMouseMotion and _selecting:
		# Track hovered tile for highlight feedback.
		var local_pos: Vector2 = (event.position - position) / scale
		var grid_pos := Vector2i(int(local_pos.x / tile_size), int(local_pos.y / tile_size))
		if grid_pos != _hovered_tile:
			_hovered_tile = grid_pos
			queue_redraw()


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


## Handler for tile_selection_started — highlight valid tiles.
func _on_tile_selection_started(payload: Dictionary) -> void:
	if battlefield_manager == null:
		return
	var range_val: int = payload.get("range", 1)
	var caster_pos: Vector2i = payload.get("caster_pos", Vector2i(0, 0))

	_valid_tiles.clear()
	# Find all tiles within range that are free.
	for dx in range(-range_val, range_val + 1):
		for dy in range(-range_val, range_val + 1):
			if dx == 0 and dy == 0:
				continue  # skip the caster's own tile
			var tile := Vector2i(caster_pos.x + dx, caster_pos.y + dy)
			if tile.x < 0 or tile.x >= battlefield_manager.grid_width:
				continue
			if tile.y < 0 or tile.y >= battlefield_manager.grid_height:
				continue
			if battlefield_manager.is_tile_free(tile):
				_valid_tiles.append(tile)

	_selecting = true
	queue_redraw()


## Handler for tile_selection_completed/cancelled — clear highlights.
func _on_tile_selection_ended(_payload: Dictionary) -> void:
	_selecting = false
	_valid_tiles.clear()
	_hovered_tile = Vector2i(-1, -1)
	queue_redraw()


## Handler for target_selection_started — highlight tiles with enemies.
func _on_target_selection_started(_payload: Dictionary) -> void:
	if battlefield_manager == null:
		return

	_valid_tiles.clear()
	# Find all tiles occupied by enemies (not the mech).
	for x in range(battlefield_manager.grid_width):
		for y in range(battlefield_manager.grid_height):
			var pos := Vector2i(x, y)
			var unit_id: StringName = battlefield_manager.get_unit_at(pos)
			if unit_id != &"" and unit_id != &"mech":
				_valid_tiles.append(pos)

	_selecting = true
	_hovered_tile = Vector2i(-1, -1)
	queue_redraw()


## Handle a left-click during tile selection.
func _handle_tile_click(screen_pos: Vector2) -> void:
	# Convert screen position to local grid coordinates.
	# The grid is inside a CanvasLayer, so position is in canvas space.
	# screen_pos is in viewport coords. Subtract our position and divide by scale.
	var local_pos: Vector2 = (screen_pos - position) / scale
	var grid_pos := Vector2i(int(local_pos.x / tile_size), int(local_pos.y / tile_size))

	print("  tile_click: screen=%s, local=%s, grid=%s, valid=%s" % [screen_pos, local_pos, grid_pos, grid_pos in _valid_tiles])

	if grid_pos in _valid_tiles:
		_selecting = false
		_valid_tiles.clear()
		queue_redraw()
		EventBus.emit("tile_selected", {"tile": grid_pos})


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

	# Draw highlighted tiles during selection
	if _selecting:
		for tile in _valid_tiles:
			var rect := Rect2(tile.x * tile_size, tile.y * tile_size, tile_size, tile_size)
			if tile == _hovered_tile:
				draw_rect(rect, HOVER_COLOR, true)
			else:
				draw_rect(rect, HIGHLIGHT_COLOR, true)


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
