## TargetingArrow — draws a line from a start point to the current mouse position.
## Used during card targeting to show where the player is aiming.
## Lives on the same CanvasLayer as HandDisplay so coordinates are in viewport space.
extends Node2D

## The starting point of the arrow (in viewport/canvas coordinates).
var start_pos: Vector2 = Vector2.ZERO

## Whether the arrow is currently visible and tracking the mouse.
var active: bool = false:
	set(value):
		active = value
		visible = value
		queue_redraw()

## Arrow line color.
@export var line_color: Color = Color(1.0, 0.3, 0.2, 0.9)

## Arrow line width.
@export var line_width: float = 3.0

## Arrowhead size in pixels.
@export var arrowhead_size: float = 12.0

func _ready() -> void:
	visible = false
	# Ensure this draws on top of everything in the UI layer.
	z_index = 100

func _process(_delta: float) -> void:
	if active:
		queue_redraw()

func _draw() -> void:
	if not active:
		return

	var end_pos: Vector2 = get_viewport().get_mouse_position()
	var direction: Vector2 = (end_pos - start_pos)

	if direction.length() < 5.0:
		return

	# Draw the line from start to end.
	draw_line(start_pos, end_pos, line_color, line_width, true)

	# Draw arrowhead at the end.
	var dir_norm: Vector2 = direction.normalized()
	var perp: Vector2 = Vector2(-dir_norm.y, dir_norm.x)
	var tip: Vector2 = end_pos
	var left: Vector2 = tip - dir_norm * arrowhead_size + perp * arrowhead_size * 0.5
	var right: Vector2 = tip - dir_norm * arrowhead_size - perp * arrowhead_size * 0.5
	var points: PackedVector2Array = PackedVector2Array([tip, left, right])
	draw_colored_polygon(points, line_color)
