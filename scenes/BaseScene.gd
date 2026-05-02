## BaseScene — root script that subscribes to EventBus events and updates UI labels.
## Handles season_advanced and base_health_changed signals from BaseManager.
## Emits scene_transition when combat is triggered so Main.tscn can switch scenes.
## Requirements: 12.1, 12.5, 12.6
extends Node

## Emitted when the base phase should hand off to the combat scene.
signal scene_transition(target: String)

func _ready() -> void:
	EventBus.subscribe("season_advanced", _on_season_advanced)
	EventBus.subscribe("base_health_changed", _on_base_health_changed)
	EventBus.subscribe("combat_triggered", _on_combat_triggered)
	$UI/LetTimePassButton.pressed.connect(_on_let_time_pass)

func _on_let_time_pass() -> void:
	$BaseManager.advance_season()

func _on_season_advanced(payload: Dictionary) -> void:
	var season: int = payload.get("season", 0)
	$UI/SeasonLabel.text = "Season: " + str(season)
	_log_event("Season " + str(season) + " begins.")

func _on_base_health_changed(payload: Dictionary) -> void:
	var current: int = payload.get("current_hp", 0)
	var maximum: int = payload.get("max_hp", 20)
	$UI/BaseHPLabel.text = "Base HP: " + str(current) + "/" + str(maximum)

func _on_combat_triggered(_payload: Dictionary) -> void:
	_log_event("Combat incoming! Preparing battlefield...")
	scene_transition.emit("combat")

func _log_event(message: String) -> void:
	var log_label: Label = $UI/EventLog
	log_label.text = log_label.text + message + "\n"
