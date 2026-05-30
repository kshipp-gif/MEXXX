## HandDisplay — renders the player's hand, draw pile, and discard pile in screen space.
## Lives on a CanvasLayer so all positions are in viewport pixels.
##
## Card interaction:
##   - Left-click + drag a TARGETABLE card: card raises, targeting arrow appears,
##     release over a valid in-range enemy plays the card; release elsewhere or
##     right-click cancels and snaps the card back.
##   - Left-click + drag a NON-TARGETABLE card: drag to upper half to play,
##     release in lower half to snap back (legacy behavior).
##   - Right-click a card: opens the inspect panel.
extends Node2D

const TEST_CARD_SCENE: PackedScene = preload("res://TestCard.tscn")

## Card dimensions (matches TestCard.tscn CollisionShape2D size).
const CARD_W: float = 118.0
const CARD_H: float = 166.0

## How far up from the bottom edge the hand sits (centre of cards).
const HAND_MARGIN_BOTTOM: float = 110.0

## Horizontal gap between card centres in hand.
const CARD_SPACING: float = 128.0

## How far the card raises above its home position when targeting.
const RAISE_OFFSET: float = 40.0

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
var _dragged_index: int = -1

## Targeting state (for TARGETABLE cards).
var _targeting: bool = false
var _targeting_arrow: Node2D = null

## Reference to BattlefieldManager (wired from CombatScene).
var battlefield_manager: Node = null

## Reference to BattlefieldGrid (wired from CombatScene) for coordinate conversion.
var battlefield_grid: Node2D = null

## Current AP — used to check if a card is playable before allowing drag.
var _current_ap: int = 0

func _ready() -> void:
	EventBus.subscribe("hand_updated", _on_hand_updated)
	EventBus.subscribe("ap_changed", _on_ap_changed)
	# Create the targeting arrow as a child node.
	var arrow_script = preload("res://scenes/TargetingArrow.gd")
	_targeting_arrow = Node2D.new()
	_targeting_arrow.set_script(arrow_script)
	_targeting_arrow.name = "TargetingArrow"
	add_child(_targeting_arrow)

func _exit_tree() -> void:
	EventBus.unsubscribe("hand_updated", _on_hand_updated)
	EventBus.unsubscribe("ap_changed", _on_ap_changed)

func _process(_delta: float) -> void:
	if _dragged_node != null and not _targeting:
		# Free-drag mode (non-targetable cards): follow the mouse.
		_dragged_node.position = get_viewport().get_mouse_position() + _drag_offset
		_dragged_node.z_index = 10

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_try_start_drag(event.position)
			else:
				_finish_drag()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _targeting:
				# Right-click during targeting: cancel.
				_cancel_targeting()
			else:
				_try_inspect(event.position)

## Try to pick up a hand card under the mouse.
func _try_start_drag(mouse_pos: Vector2) -> void:
	# Iterate in reverse so topmost (last drawn) card is picked first.
	for i in range(_hand_nodes.size() - 1, -1, -1):
		var node = _hand_nodes[i]
		var half = Vector2(CARD_W, CARD_H) * 0.5
		var rect = Rect2(node.position - half, Vector2(CARD_W, CARD_H))
		if rect.has_point(mouse_pos):
			var card_data: Card = node.card_data if "card_data" in node else null

			# Check if the card is playable (enough AP). If not, shake and reject.
			if card_data != null and card_data.ap_cost > _current_ap:
				_shake_card(node, i)
				get_viewport().set_input_as_handled()
				return

			_dragged_node = node
			_dragged_index = i
			_drag_offset = node.position - mouse_pos

			if card_data != null and card_data.target_mode == Enums.TargetMode.TARGETABLE:
				# Targetable card: raise it and start the arrow.
				_start_targeting(node)
			else:
				# Non-targetable card: free drag.
				_targeting = false

			get_viewport().set_input_as_handled()
			return

## Start the targeting mode: raise the card and show the arrow.
func _start_targeting(card_node) -> void:
	_targeting = true
	var idx: int = _hand_nodes.find(card_node)
	var home: Vector2 = _home_positions[idx]
	# Raise the card above its home position.
	card_node.position = home + Vector2(0, -RAISE_OFFSET)
	card_node.z_index = 10

	# Activate the targeting arrow from the card's raised position.
	_targeting_arrow.start_pos = card_node.position
	_targeting_arrow.active = true

## Cancel targeting: snap card back, hide arrow.
func _cancel_targeting() -> void:
	if _dragged_node == null:
		return
	_targeting_arrow.active = false
	_targeting = false

	# Snap card back to home.
	var idx: int = _hand_nodes.find(_dragged_node)
	if idx >= 0:
		_dragged_node.position = _home_positions[idx]
		_dragged_node.z_index = idx + 1
	_dragged_node = null
	_dragged_index = -1

## Open the inspect panel for the topmost card under the mouse.
func _try_inspect(mouse_pos: Vector2) -> void:
	for i in range(_hand_nodes.size() - 1, -1, -1):
		var node = _hand_nodes[i]
		var half = Vector2(CARD_W, CARD_H) * 0.5
		var rect = Rect2(node.position - half, Vector2(CARD_W, CARD_H))
		if rect.has_point(mouse_pos):
			if inspect_panel != null:
				inspect_panel.show_for_card(node.card_data)
			get_viewport().set_input_as_handled()
			return

## Release the dragged card.
func _finish_drag() -> void:
	if _dragged_node == null:
		return

	if _targeting:
		# Targeting mode: check if we released over a valid enemy.
		_finish_targeting()
	else:
		# Non-targetable card: play if released in upper half, else snap back.
		_finish_free_drag()

## Finish a targeting drag: check if the cursor is over a valid in-range enemy.
func _finish_targeting() -> void:
	_targeting_arrow.active = false
	_targeting = false

	var card_data: Card = _dragged_node.card_data if "card_data" in _dragged_node else null
	if card_data == null:
		_snap_back()
		return

	# Determine what tile the mouse is over on the battlefield grid.
	var target_tile: Vector2i = _get_grid_tile_under_mouse()
	if target_tile == Vector2i(-1, -1):
		_snap_back()
		return

	# Check if there's an enemy on that tile.
	if battlefield_manager == null:
		_snap_back()
		return

	var unit_id: StringName = battlefield_manager.get_unit_at(target_tile)
	if unit_id == &"" or unit_id == &"mech":
		# Not a valid enemy — cancel.
		_snap_back()
		return

	# Check range from the mech to the target.
	var mech_pos: Vector2i = battlefield_manager.get_position(&"mech")
	var distance: int = battlefield_manager.tile_distance(mech_pos, target_tile)
	if card_data.range_value > 0 and distance > card_data.range_value:
		# Out of range — cancel.
		_snap_back()
		return

	# Valid target! Play the card against this enemy.
	var target_node: Node = battlefield_manager.get_unit_node_at(target_tile)
	_dragged_node.z_index = 0
	_dragged_node = null
	_dragged_index = -1

	# Emit a targeted play request with the resolved target.
	EventBus.emit("card_play_requested", {
		"card": card_data,
		"target": target_node,
		"target_pos": target_tile
	})

## Finish a free drag (non-targetable cards): play if in upper half, else snap back.
func _finish_free_drag() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var release_pos: Vector2 = get_viewport().get_mouse_position()

	# If released in the upper half, attempt to play the card.
	if release_pos.y < vp_size.y * 0.5:
		var card_data: Card = _dragged_node.card_data if "card_data" in _dragged_node else null
		if card_data != null:
			_dragged_node.z_index = 0
			_dragged_node = null
			_dragged_index = -1
			EventBus.emit("card_play_requested", {"card": card_data})
			return

	# Snap back to home position.
	_snap_back()

## Snap the currently dragged card back to its home position.
func _snap_back() -> void:
	if _dragged_node == null:
		return
	var idx: int = _hand_nodes.find(_dragged_node)
	if idx >= 0:
		_dragged_node.position = _home_positions[idx]
		_dragged_node.z_index = idx + 1
	_dragged_node = null
	_dragged_index = -1

## Convert the current mouse position to a grid tile on the BattlefieldGrid.
## Returns Vector2i(-1, -1) if the mouse is not over the grid.
func _get_grid_tile_under_mouse() -> Vector2i:
	if battlefield_grid == null or battlefield_manager == null:
		return Vector2i(-1, -1)

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	# The BattlefieldGrid lives on a CanvasLayer. Its position and scale
	# transform viewport coords into grid-local coords.
	var grid_pos: Vector2 = battlefield_grid.position
	var grid_scale: Vector2 = battlefield_grid.scale
	var tile_size: int = battlefield_grid.tile_size

	# Convert mouse position to grid-local coordinates.
	var local_pos: Vector2 = (mouse_pos - grid_pos) / grid_scale
	var tile_x: int = int(local_pos.x / tile_size)
	var tile_y: int = int(local_pos.y / tile_size)

	# Bounds check.
	if tile_x < 0 or tile_x >= battlefield_manager.grid_width:
		return Vector2i(-1, -1)
	if tile_y < 0 or tile_y >= battlefield_manager.grid_height:
		return Vector2i(-1, -1)

	return Vector2i(tile_x, tile_y)

## Called when APManager emits ap_changed.
func _on_ap_changed(payload: Dictionary) -> void:
	_current_ap = payload.get("current_ap", 0)

## Shake a card left-right to indicate it can't be played.
func _shake_card(card_node: Node, index: int) -> void:
	var home: Vector2 = _home_positions[index]
	var tween: Tween = create_tween()
	# Quick left-right-left-right-center shake.
	tween.tween_property(card_node, "position", home + Vector2(-6, 0), 0.04)
	tween.tween_property(card_node, "position", home + Vector2(6, 0), 0.04)
	tween.tween_property(card_node, "position", home + Vector2(-4, 0), 0.04)
	tween.tween_property(card_node, "position", home + Vector2(4, 0), 0.04)
	tween.tween_property(card_node, "position", home, 0.04)

## Called when DeckManager emits hand_updated.
func _on_hand_updated(payload: Dictionary) -> void:
	var hand: Array = payload.get("hand", [])
	var deck_size: int = payload.get("deck_size", 0)
	var discard_size: int = payload.get("discard_size", 0)
	_rebuild_hand(hand)
	_update_pile_labels(deck_size, discard_size)

## Remove old hand card nodes and spawn fresh ones.
func _rebuild_hand(hand: Array) -> void:
	# Cancel any active drag/targeting first.
	if _targeting:
		_targeting_arrow.active = false
		_targeting = false
	_dragged_node = null
	_dragged_index = -1

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

		# Assign Card resource for inspect and play.
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
