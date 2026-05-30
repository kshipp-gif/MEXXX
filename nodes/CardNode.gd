extends Area2D

signal hovered
signal hovered_off
signal inspect_requested(card_node)

## The Card resource this visual node represents.
## Set by whatever system instantiates and populates card nodes.
## When assigned, automatically updates the card art sprite.
var card_data: Card = null:
	set(value):
		card_data = value
		_update_art()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Only connect card signals if the parent is a CardManager that supports it.
	if get_parent().has_method("connect_card_signals"):
		get_parent().connect_card_signals(self)
	# Apply art if card_data was set before entering the tree.
	_update_art()

## Update the CardImage sprite to show this card's art, scaled to fit the card bounds.
func _update_art() -> void:
	if not is_inside_tree():
		return
	if card_data == null or card_data.card_art == null:
		return
	var sprite: Sprite2D = $CardImage
	if sprite == null:
		return
	sprite.texture = card_data.card_art
	# Scale the art to fit within the card's collision bounds (118x166).
	var tex_size: Vector2 = sprite.texture.get_size()
	if tex_size.x > 0 and tex_size.y > 0:
		var target_size: Vector2 = Vector2(118.0, 166.0)
		sprite.scale = target_size / tex_size


func _on_mouse_entered() -> void:
	emit_signal("hovered", self)


func _on_mouse_exited() -> void:
	emit_signal("hovered_off", self)
