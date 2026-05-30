## EnemyHealthDisplay — shows enemy HP in the top-left area below the End Turn button.
## Updates every frame to reflect current health values.
extends Label

func _ready() -> void:
	# Position below the End Turn button.
	offset_left = 16.0
	offset_top = 56.0
	offset_right = 250.0
	offset_bottom = 200.0

func _process(_delta: float) -> void:
	var enemies_node: Node = get_node_or_null("/root/Main/GameViewportContainer/GameViewport/CombatScene/Enemies")
	if enemies_node == null:
		text = ""
		return

	var lines: Array[String] = []
	for enemy in enemies_node.get_children():
		if "hp" in enemy and "max_hp" in enemy:
			var armor_str: String = ""
			if "armor" in enemy and enemy.armor > 0:
				armor_str = " [Armor: %d]" % enemy.armor
			lines.append("%s: %d/%d%s" % [enemy.name, enemy.hp, enemy.max_hp, armor_str])

	text = "\n".join(lines) if lines.size() > 0 else ""
