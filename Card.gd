extends Area2D

signal hovered
signal hovered_off
signal inspect_requested(card_node)

## The Card resource this visual node represents.
## Set by whatever system instantiates and populates card nodes.
var card_data: Card = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Only connect card signals if the parent is a CardManager that supports it.
	if get_parent().has_method("connect_card_signals"):
		get_parent().connect_card_signals(self)


func _on_mouse_entered() -> void:
	emit_signal("hovered", self)


func _on_mouse_exited() -> void:
	emit_signal("hovered_off", self)


func _input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			emit_signal("inspect_requested", self)
			get_viewport().set_input_as_handled()
