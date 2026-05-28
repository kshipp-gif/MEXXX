## StatusDisplay — shows active status effects and their stack counts on the Mech.
## Positioned in the top-right corner via the scene file.
extends Label

func _ready() -> void:
	EventBus.subscribe("status_effect_applied", _on_status_changed)
	EventBus.subscribe("status_effect_removed", _on_status_changed)
	EventBus.subscribe("turn_started", _on_status_changed)
	# Show initial state after a short delay (Mech needs to be ready first).
	call_deferred("_refresh")

func _exit_tree() -> void:
	EventBus.unsubscribe("status_effect_applied", _on_status_changed)
	EventBus.unsubscribe("status_effect_removed", _on_status_changed)
	EventBus.unsubscribe("turn_started", _on_status_changed)

func _on_status_changed(_payload: Dictionary) -> void:
	_refresh()

func _refresh() -> void:
	var mech: Node = get_tree().get_first_node_in_group("mech")
	if mech == null:
		text = ""
		return

	var mgr: StatusEffectManager = null
	for child in mech.get_children():
		if child is StatusEffectManager:
			mgr = child
			break

	if mgr == null:
		text = ""
		return

	var effects: Array = mgr.get_active_effects()
	if effects.is_empty():
		text = ""
		return

	var lines: Array[String] = []
	for effect in effects:
		var name_str: String = effect.status_name.capitalize()
		lines.append("%s: %d" % [name_str, effect.stacks])
	text = "\n".join(lines)
