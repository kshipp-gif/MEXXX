## CodexScreen — full-screen overlay that shows every unlocked Item from
## GameState.inventory and all cards in each Item's CardSet.
##
## Layout:
##   ScrollContainer → VBoxContainer
##     For each Item:
##       Label (item display_name, bold/large)
##       HBoxContainer rows of up to 5 CardNode instances
##   If inventory is empty:
##       Label "No items unlocked yet."
##
## Right-clicking a card opens the embedded CardInspectPanel.
## process_mode = ALWAYS so the Codex works while the game is paused.
extends Control

const CARD_NODE_SCENE: PackedScene = preload("res://nodes/CardNode.tscn")

## Card dimensions matching CardNode.tscn CollisionShape2D size.
const CARD_W: float = 118.0
const CARD_H: float = 166.0

## Cards per row in the Codex layout.
const CARDS_PER_ROW: int = 5

## Horizontal gap between card centres in a row.
const CARD_SPACING: float = 130.0

@onready var _content_vbox: VBoxContainer = $MarginContainer/VBox/ScrollContainer/ContentVBox
@onready var _close_button: Button = $MarginContainer/VBox/CloseButton
@onready var _inspect_panel = $CardInspectPanel

## All spawned card nodes, used for right-click hit-testing.
var _card_nodes: Array = []

func _ready() -> void:
	_close_button.pressed.connect(hide)
	hide()

## Populate and show the Codex.
func open_codex() -> void:
	_rebuild_content()
	show()

## Rebuild the scroll content from GameState.inventory.
func _rebuild_content() -> void:
	# Clear previous content.
	for child in _content_vbox.get_children():
		child.queue_free()
	_card_nodes.clear()

	var inventory: Array = GameState.inventory

	if inventory.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No items unlocked yet."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_vbox.add_child(empty_label)
		return

	for item in inventory:
		if not item is Item:
			continue

		# Section header.
		var header: Label = Label.new()
		header.text = item.display_name
		header.add_theme_font_size_override("font_size", 20)
		_content_vbox.add_child(header)

		# Cards from the item's CardSet.
		var card_set: CardSet = item.card_set
		if card_set == null or card_set.cards.is_empty():
			var no_cards: Label = Label.new()
			no_cards.text = "  (no cards)"
			_content_vbox.add_child(no_cards)
			continue

		var cards: Array = card_set.cards
		var row_index: int = 0

		while row_index < cards.size():
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", int(CARD_SPACING - CARD_W))
			_content_vbox.add_child(row)

			for col in range(CARDS_PER_ROW):
				var card_idx: int = row_index + col
				if card_idx >= cards.size():
					break

				var card_data: Card = cards[card_idx]
				var card_node = CARD_NODE_SCENE.instantiate()

				# CardNode is an Area2D; wrap it in a Control so it sits in the HBox.
				var wrapper: Control = Control.new()
				wrapper.custom_minimum_size = Vector2(CARD_W, CARD_H)
				wrapper.add_child(card_node)

				# Centre the Area2D within the wrapper.
				card_node.position = Vector2(CARD_W * 0.5, CARD_H * 0.5)

				card_node.card_data = card_data
				# Ensure source_item is set for the inspect panel.
				if card_data != null:
					card_data.source_item = item

				row.add_child(wrapper)
				_card_nodes.append(card_node)

			row_index += CARDS_PER_ROW

		# Spacer between items.
		var spacer: Control = Control.new()
		spacer.custom_minimum_size = Vector2(0, 16)
		_content_vbox.add_child(spacer)

## Handle right-click for card inspection via global position hit-testing.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_try_inspect(event.global_position)

func _try_inspect(mouse_global: Vector2) -> void:
	for card_node in _card_nodes:
		if not is_instance_valid(card_node):
			continue
		# card_node is an Area2D; its parent wrapper is a Control.
		var wrapper: Control = card_node.get_parent()
		if wrapper == null:
			continue
		var rect: Rect2 = Rect2(wrapper.global_position, wrapper.size)
		if rect.has_point(mouse_global):
			if _inspect_panel != null and card_node.card_data != null:
				_inspect_panel.show_for_card(card_node.card_data)
			get_viewport().set_input_as_handled()
			return
