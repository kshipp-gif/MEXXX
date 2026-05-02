## HandDisplay — renders the player's hand, draw pile, and discard pile in screen space.
## Lives on a CanvasLayer so all positions are in viewport pixels.
## Handles card drag (left-click) with snap-back on release.
## Right-click on a card emits inspect_requested (handled by CardInspectPanel).
extends Node2D

const TEST_CARD_SCENE: PackedScene = preload("res://TestCard.tscn")

## Card dimensions (matches TestCard.tscn CollisionShape2D size).
const CARD_W: float = 118.0
const CARD_H: float = 166.0

## How far up from the bottom edge the hand sits (centre of cards).
const HAND_MARGIN_BOTTOM: float = 110.0

## Horizontal gap between card centres in hand.
const CARD_SPACING: float = 128.0

## Pile positions are set at runtime from viewport size.
var _draw_pile_pos: Vector2 = Vector2.ZERO
var _discard_pile_pos: Vector2 = Vector2.ZERO

## Count labels wired from CombatScene.
var draw_count_label: Label = null
var discard_count_label: Label = null

## Inspect panel wired from CombatScene.
var inspect_panel = null

## Hand card nodes and their home positions.
var _hand_nodes: Array = []
var _home_positions: Array = []

## Drag state.
var _dragged_node = null
var _drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	EventBus.subscribe("hand_updated", _on_hand_updated)

func _process(_delta: float) -> void:
	if _dragged_node != null:
		_dragged_node.position = get_viewport().get_mouse_position() + _drag_offset
		_dragged_node.z_index = 10

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_try_start_drag(event.position)
			else:
				_finish_drag()

## Try to pick up a hand card under the mouse.
func _try_start_drag(mouse_pos: Vector2) -> void:
	# Iterate in reverse so topmost (last drawn) card is picked first.
	for i in range(_hand_nodes.size() - 1, -1, -1):
		var node = _hand_nodes[i]
		var half = Vector2(CARD_W, CARD_H) * 0.5
		var rect = Rect2(node.position - half, Vector2(CARD_W, CARD_H))
		if rect.has_point(mouse_pos):
			_dragged_node = node
			_drag_offset = node.position - mouse_pos
			get_viewport().set_input_as_handled()
			return

## Release the dragged card and snap it back to its home position.
func _finish_drag() -> void:
	if _dragged_node == null:
		return
	var idx: int = _hand_nodes.find(_dragged_node)
	if idx >= 0:
		_dragged_node.position = _home_positions[idx]
	_dragged_node.z_index = idx + 1
	_dragged_node = null

## Called when DeckManager emits hand_updated.
func _on_hand_updated(payload: Dictionary) -> void:
	var hand: Array = payload.get("hand", [])
	var deck_size: int = payload.get("deck_size", 0)
	var discard_size: int = payload.get("discard_size", 0)
	_rebuild_hand(hand)
	_update_pile_labels(deck_size, discard_size)

## Remove old hand card nodes and spawn fresh ones.
func _rebuild_hand(hand: Array) -> void:
	# Cancel any active drag first.
	_dragged_node = null

	for node in _hand_nodes:
		node.queue_free()
	_hand_nodes.clear()
	_home_positions.clear()

	var count: int = hand.size()
	if count == 0:
		return

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var hand_y: float = vp_size.y - HAND_MARGIN_BOTTOM
	var hand_centre_x: float = vp_size.x / 2.0

	var total_width: float = (count - 1) * CARD_SPACING
	var start_x: float = hand_centre_x - total_width / 2.0

	for i in range(count):
		var card_node = TEST_CARD_SCENE.instantiate()
		var home: Vector2 = Vector2(start_x + i * CARD_SPACING, hand_y)
		card_node.position = home
		card_node.z_index = i + 1

		# Assign Card resource for inspect.
		if hand[i] is Card:
			card_node.card_data = hand[i]

		# Wire right-click inspect.
		if card_node.has_signal("inspect_requested"):
			card_node.inspect_requested.connect(_on_inspect_requested)

		add_child(card_node)
		_hand_nodes.append(card_node)
		_home_positions.append(home)

## Open the inspect panel for the given card node.
func _on_inspect_requested(card_node) -> void:
	if inspect_panel != null and card_node.card_data != null:
		inspect_panel.show_for_card(card_node.card_data)

## Update draw and discard count labels.
func _update_pile_labels(deck_size: int, discard_size: int) -> void:
	if draw_count_label != null:
		draw_count_label.text = str(deck_size)
	if discard_count_label != null:
		discard_count_label.text = str(discard_size)
