## CharacterSelectScreen — shown after "New Game" is pressed.
## Displays available Mech types; emits mech_selected(definition) when the
## player confirms their choice, or scene_transition("main_menu") to go back.
extends Control

signal mech_selected(definition: MechDefinition)
signal scene_transition(target: String)

## Registered mech definitions. Add new MechDefinition resources here
## (or load them from a data folder) as more mechs are designed.
const MECH_DEFINITIONS: Array[String] = [
	"res://data/mechs/mech_a.tres",
]

## Currently highlighted mech index.
var _selected_index: int = 0
var _definitions: Array[MechDefinition] = []

@onready var _name_label: Label = $VBox/SelectionArea/InfoPanel/NameLabel
@onready var _desc_label: Label = $VBox/SelectionArea/InfoPanel/DescLabel
@onready var _items_label: Label = $VBox/SelectionArea/InfoPanel/ItemsLabel
@onready var _confirm_button: Button = $VBox/ButtonRow/ConfirmButton
@onready var _back_button: Button = $VBox/ButtonRow/BackButton
@onready var _mech_list: VBoxContainer = $VBox/SelectionArea/MechList

func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm)
	_back_button.pressed.connect(_on_back)
	_load_definitions()
	_build_mech_list()
	_refresh_info()

## Load all MechDefinition resources.
func _load_definitions() -> void:
	_definitions.clear()
	for path in MECH_DEFINITIONS:
		var def: MechDefinition = load(path) as MechDefinition
		if def != null:
			_definitions.append(def)

## Build the clickable mech list on the left panel.
func _build_mech_list() -> void:
	for child in _mech_list.get_children():
		child.queue_free()

	for i in range(_definitions.size()):
		var btn: Button = Button.new()
		btn.text = _definitions[i].display_name
		btn.toggle_mode = false
		var idx := i  # capture for closure
		btn.pressed.connect(func(): _select(idx))
		_mech_list.add_child(btn)

## Select a mech by index and refresh the info panel.
func _select(index: int) -> void:
	_selected_index = index
	_refresh_info()

## Update the info panel to reflect the currently selected mech.
func _refresh_info() -> void:
	if _definitions.is_empty():
		_name_label.text = "No mechs available."
		_desc_label.text = ""
		_items_label.text = ""
		_confirm_button.disabled = true
		return

	var def: MechDefinition = _definitions[_selected_index]
	_name_label.text = def.display_name
	_desc_label.text = def.description

	if def.starting_items.is_empty():
		_items_label.text = "Starting items: none"
	else:
		var names: Array[String] = []
		for res in def.starting_items:
			var item: Item = res as Item
			if item != null:
				names.append(item.display_name)
		_items_label.text = "Starting items: " + ", ".join(names)

	_confirm_button.disabled = false

func _on_confirm() -> void:
	if _definitions.is_empty():
		return
	mech_selected.emit(_definitions[_selected_index])

func _on_back() -> void:
	scene_transition.emit("main_menu")
