## Main — top-level scene controller that manages transitions between
## the MainMenu, BaseScene (out-of-combat phase), and CombatScene (combat phase).
##
## Scene transitions:
##   Boot                          → MainMenu
##   MainMenu.scene_transition("game") → BaseScene
##   BaseScene.scene_transition("combat") → CombatScene
##   EventBus "combat_ended"       → BaseScene
##
## Requirements: 8.7, 9.1, 9.2, 12.2
extends Node

@export var main_menu_path: String = "res://scenes/MainMenu.tscn"
@export var combat_scene_path: String = "res://scenes/CombatScene.tscn"
@export var base_scene_path: String = "res://scenes/BaseScene.tscn"

var _active_scene: Node = null

func _ready() -> void:
	EventBus.subscribe("combat_ended", _on_combat_ended)
	_switch_to_main_menu()

## Show the main menu.
func _switch_to_main_menu() -> void:
	_remove_active_scene()

	var packed: PackedScene = load(main_menu_path)
	if packed == null:
		push_error("Main: could not load MainMenu from " + main_menu_path)
		return

	_active_scene = packed.instantiate()
	add_child(_active_scene)

	if _active_scene.has_signal("scene_transition"):
		_active_scene.scene_transition.connect(_on_main_menu_transition)

## Load and activate the BaseScene; connect its scene_transition signal.
func _switch_to_base() -> void:
	_remove_active_scene()

	var packed: PackedScene = load(base_scene_path)
	if packed == null:
		push_error("Main: could not load BaseScene from " + base_scene_path)
		return

	_active_scene = packed.instantiate()
	add_child(_active_scene)

	if _active_scene.has_signal("scene_transition"):
		_active_scene.scene_transition.connect(_on_base_scene_transition)

## Load and activate the CombatScene; start combat with any enemies present.
func _switch_to_combat() -> void:
	_remove_active_scene()

	var packed: PackedScene = load(combat_scene_path)
	if packed == null:
		push_error("Main: could not load CombatScene from " + combat_scene_path)
		return

	_active_scene = packed.instantiate()
	add_child(_active_scene)

	_active_scene.call_deferred("_start_combat")

## Remove and free the currently active scene, if any.
func _remove_active_scene() -> void:
	if _active_scene != null:
		_active_scene.queue_free()
		_active_scene = null

## Called when MainMenu emits scene_transition("game").
func _on_main_menu_transition(target: String) -> void:
	if target == "game":
		_switch_to_base()

## Called when BaseScene emits scene_transition("combat").
func _on_base_scene_transition(target: String) -> void:
	if target == "combat":
		_switch_to_combat()

## Called when EventBus emits "combat_ended".
func _on_combat_ended(payload: Dictionary) -> void:
	var outcome: String = payload.get("outcome", "unknown")
	print("Main: combat ended with outcome = ", outcome)
	_switch_to_base()
