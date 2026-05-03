## Main — top-level scene controller that manages transitions between
## the MainMenu, BaseScene (out-of-combat phase), and CombatScene (combat phase).
## Owns the PauseMenu overlay and applies a blur shader to the game viewport when paused.
##
## Scene transitions:
##   Boot                              → MainMenu
##   MainMenu.scene_transition("game") → BaseScene
##   BaseScene.scene_transition("combat") → CombatScene
##   EventBus "combat_ended"           → BaseScene
##
## Requirements: 8.7, 9.1, 9.2, 12.2
extends Node

const BLUR_SHADER: Shader = preload("res://assets/shaders/blur.gdshader")
const BLUR_AMOUNT: float = 4.0

@export var main_menu_path: String = "res://scenes/MainMenu.tscn"
@export var combat_scene_path: String = "res://scenes/CombatScene.tscn"
@export var base_scene_path: String = "res://scenes/BaseScene.tscn"

var _active_scene: Node = null
var _run_active: bool = false

## References to scene nodes (set in _ready after the scene tree is ready).
@onready var _viewport_container: SubViewportContainer = $GameViewportContainer
@onready var _game_viewport: SubViewport = $GameViewportContainer/GameViewport
@onready var _pause_menu = $PauseLayer/PauseMenu

## Shared ShaderMaterial applied to the viewport container for blur.
var _blur_material: ShaderMaterial = null

func _ready() -> void:
	# Build the blur material once.
	_blur_material = ShaderMaterial.new()
	_blur_material.shader = BLUR_SHADER
	_blur_material.set_shader_parameter("blur_amount", 0.0)

	# Wire pause menu actions.
	_pause_menu.action_requested.connect(_on_pause_action)

	EventBus.subscribe("combat_ended", _on_combat_ended)
	_switch_to_main_menu()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _run_active:
		if _pause_menu.visible:
			_close_pause_menu()
		else:
			_open_pause_menu()
		get_viewport().set_input_as_handled()

## Open the pause menu and blur the game viewport.
func _open_pause_menu() -> void:
	# Apply blur to the viewport container.
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_blur_material.set_shader_parameter("texture_size", vp_size)
	_blur_material.set_shader_parameter("blur_amount", BLUR_AMOUNT)
	_viewport_container.material = _blur_material

	get_tree().paused = true
	_pause_menu.show()

## Close the pause menu and remove the blur.
func _close_pause_menu() -> void:
	get_tree().paused = false
	_pause_menu.hide()
	_blur_material.set_shader_parameter("blur_amount", 0.0)
	_viewport_container.material = null

## Show the main menu.
func _switch_to_main_menu() -> void:
	_run_active = false
	_remove_active_scene()

	var packed: PackedScene = load(main_menu_path)
	if packed == null:
		push_error("Main: could not load MainMenu from " + main_menu_path)
		return

	_active_scene = packed.instantiate()
	_game_viewport.add_child(_active_scene)

	if _active_scene.has_signal("scene_transition"):
		_active_scene.scene_transition.connect(_on_main_menu_transition)

## Load and activate the BaseScene.
func _switch_to_base() -> void:
	_run_active = true
	_remove_active_scene()

	var packed: PackedScene = load(base_scene_path)
	if packed == null:
		push_error("Main: could not load BaseScene from " + base_scene_path)
		return

	_active_scene = packed.instantiate()
	_game_viewport.add_child(_active_scene)

	if _active_scene.has_signal("scene_transition"):
		_active_scene.scene_transition.connect(_on_base_scene_transition)

## Load and activate the CombatScene.
func _switch_to_combat() -> void:
	_run_active = true
	_remove_active_scene()

	var packed: PackedScene = load(combat_scene_path)
	if packed == null:
		push_error("Main: could not load CombatScene from " + combat_scene_path)
		return

	_active_scene = packed.instantiate()
	_game_viewport.add_child(_active_scene)

	_active_scene.call_deferred("_start_combat")

## Remove and free the currently active scene.
func _remove_active_scene() -> void:
	if _active_scene != null:
		_active_scene.queue_free()
		_active_scene = null

func _on_main_menu_transition(target: String) -> void:
	if target == "game":
		_switch_to_base()

func _on_base_scene_transition(target: String) -> void:
	if target == "combat":
		_switch_to_combat()

func _on_combat_ended(payload: Dictionary) -> void:
	var outcome: String = payload.get("outcome", "unknown")
	print("Main: combat ended with outcome = ", outcome)
	_switch_to_base()

func _on_pause_action(action: String) -> void:
	match action:
		"resume":
			_close_pause_menu()
		"abandon":
			_close_pause_menu()
			_switch_to_main_menu()
		"save_main_menu":
			push_warning("Main: save not yet implemented — returning to main menu.")
			_close_pause_menu()
			_switch_to_main_menu()
		"save_quit":
			push_warning("Main: save not yet implemented — quitting.")
			_close_pause_menu()
			get_tree().quit()
