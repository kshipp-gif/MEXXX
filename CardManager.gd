extends Node2D


const COLLISION_MASK_CARD = 1


var screen_size
var card_being_dragged
var is_hovering_on_card


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport_rect().size


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if card_being_dragged:
		var mouse_pos = get_global_mouse_position()
		card_being_dragged.position = Vector2(clamp(mouse_pos.x, 0, screen_size.x),
			clamp(mouse_pos.y, 0, screen_size.y))


func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var card = raycast_check_for_card()
			if card:
				start_drag(card)
		else:
			finish_drag()


func start_drag(card):
	card_being_dragged = card
	card.scale = Vector2(1, 1)
	card.get_parent().move_child(card, -1)

func finish_drag():
	if card_being_dragged:
		card_being_dragged.scale = Vector2(1.05, 1.05)
	card_being_dragged = null

func connect_card_signals(card):
	card.connect("hovered", on_hovered_over_card)
	card.connect("hovered_off", on_hovered_off_card)


func on_hovered_over_card(card):\
	if !is_hovering_on_card:
		is_hovering_on_card = true
		highlight_card(card, true)
		print("hovering")

func on_hovered_off_card(card):
	if !card_being_dragged:
		highlight_card(card, false)
		# Check if hovered off card straight on to another card
		var new_card_hovered = raycast_check_for_card()
		if new_card_hovered and new_card_hovered != card:
			highlight_card(new_card_hovered, true)
		else:
			is_hovering_on_card = false
			print("not hovering")


func highlight_card(card, hovered):
	if hovered:
		card.scale = Vector2(1.05, 1.05)
		card.z_index = 2
	else:
		card.scale = Vector2(1, 1)
		card.z_index = 1


func raycast_check_for_card():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		#return result[0].collider
		return get_card_with_highest_z_index(result)
		return null


func get_card_with_highest_z_index(cards):
	# Assume the first card in cards array has the highest z-index
	var highest_z_card = cards[0].collider
	var highest_z_index = highest_z_card.z_index
	
	# Loop through the rest of the cards checking for a higher z-index
	for i in range(1, cards.size()):
		var current_card = cards[1].collider
		if current_card.z_index > highest_z_index:
			highest_z_card = current_card
			highest_z_index = current_card.z_index
	return highest_z_card
