## PauseMenu — shown when the player presses Esc during a run.
## Main.gd controls pausing and blur; this script only handles button wiring.
extends Control

signal action_requested(action: String)

func _ready() -> void:
	$VBox/ResumeButton.pressed.connect(_on_resume)
	$VBox/CodexButton.pressed.connect(_on_codex)
	$VBox/SettingsButton.pressed.connect(_on_settings)
	$VBox/AbandonButton.pressed.connect(_on_abandon)
	$VBox/SaveMainMenuButton.pressed.connect(_on_save_main_menu)
	$VBox/SaveQuitButton.pressed.connect(_on_save_quit)
	hide()

func _on_resume() -> void:
	# Tell Main to close the menu (which also unpauses and removes blur).
	action_requested.emit("resume")

func _on_codex() -> void:
	push_warning("PauseMenu: Codex not yet implemented.")

func _on_settings() -> void:
	push_warning("PauseMenu: Settings not yet implemented.")

func _on_abandon() -> void:
	action_requested.emit("abandon")

func _on_save_main_menu() -> void:
	action_requested.emit("save_main_menu")

func _on_save_quit() -> void:
	action_requested.emit("save_quit")
