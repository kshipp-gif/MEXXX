## MainMenu — the initial screen shown when the game boots.
## Emits scene_transition("game") when New Game is selected,
## or handles Quit to Desktop directly.
## Load Game, Codex, and Settings are stubs for future implementation.
extends Control

signal scene_transition(target: String)
signal codex_requested

func _ready() -> void:
	$VBox/NewGameButton.pressed.connect(_on_new_game)
	$VBox/LoadGameButton.pressed.connect(_on_load_game)
	$VBox/CodexButton.pressed.connect(_on_codex)
	$VBox/SettingsButton.pressed.connect(_on_settings)
	$VBox/QuitButton.pressed.connect(_on_quit)

func _on_new_game() -> void:
	scene_transition.emit("game")

func _on_load_game() -> void:
	# Stub — load game functionality not yet implemented.
	push_warning("MainMenu: Load Game not yet implemented.")

func _on_codex() -> void:
	codex_requested.emit()

func _on_settings() -> void:
	# Stub — Settings not yet implemented.
	push_warning("MainMenu: Settings not yet implemented.")

func _on_quit() -> void:
	get_tree().quit()
