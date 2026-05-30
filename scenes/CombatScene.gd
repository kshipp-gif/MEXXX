## CombatScene — root script that wires cross-manager references on startup
## and exposes _start_combat() for Main to call after instantiation.
extends Node

func _ready() -> void:
	# Wire HandManager references.
	$HandManager.deck_manager = $DeckManager
	$HandManager.ap_manager = $Mech/APManager
	$HandManager.battlefield_manager = $BattlefieldManager
	$HandManager.mech = $Mech

	# Wire CombatTurnManager references.
	$CombatTurnManager.mech = $Mech
	$CombatTurnManager.battlefield_manager = $BattlefieldManager
	$CombatTurnManager.ap_manager = $Mech/APManager

	# Wire HandDisplay pile count labels and inspect panel.
	$UI/HandDisplay.draw_count_label = $UI/DrawPile/DrawCountLabel
	$UI/HandDisplay.discard_count_label = $UI/DiscardPile/DiscardCountLabel
	$UI/HandDisplay.inspect_panel = $UI/CardInspectPanel

	# Wire BattlefieldGrid to BattlefieldManager for grid display.
	if $GridLayer/BattlefieldGrid == null:
		push_warning("CombatScene: BattlefieldGrid node not found — skipping grid wiring.")
	elif $BattlefieldManager == null:
		push_warning("CombatScene: BattlefieldManager node not found — skipping grid wiring.")
	else:
		$GridLayer/BattlefieldGrid.battlefield_manager = $BattlefieldManager
		$BattlefieldManager.grid_width = 12
		$BattlefieldManager.grid_height = 12
		$BattlefieldManager.place_unit(&"mech", Vector2i(6, 11), $Mech)
		# Place test enemy on the grid.
		if $Enemies/TestDummy != null:
			$BattlefieldManager.place_unit(&"TestDummy", Vector2i(6, 3), $Enemies/TestDummy)

	# Subscribe DeckManager to slot_changed so it rebuilds the deck on equip changes.
	EventBus.subscribe("slot_changed", _on_slot_changed)

	# Subscribe to turn_started so we can enable/disable the End Turn button.
	EventBus.subscribe("turn_started", _on_turn_started)
	EventBus.subscribe("combat_ended", _on_combat_ended)

	# Wire the End Turn button.
	$UI/EndTurnButton.pressed.connect(_on_end_turn)

	# Build a test deck of 15 TestCard instances directly in DeckManager.
	_build_test_deck()

func _exit_tree() -> void:
	EventBus.unsubscribe("slot_changed", _on_slot_changed)
	EventBus.unsubscribe("turn_started", _on_turn_started)
	EventBus.unsubscribe("combat_ended", _on_combat_ended)

## Called by Main after the scene is added to the tree.
## Collects enemy nodes from the Enemies container and starts combat.
func _start_combat() -> void:
	var enemy_nodes: Array[Node] = []
	for child in $Enemies.get_children():
		enemy_nodes.append(child)
	$CombatTurnManager.start_combat(enemy_nodes)

## Load the Broadsword item and populate DeckManager directly.
## Stamps source_item on each card so inspect panel shows item name and tags.
func _build_test_deck() -> void:
	$DeckManager.deck.clear()
	$DeckManager.hand.clear()
	$DeckManager.discard_pile.clear()

	var broadsword: Item = load("res://data/arms/broadsword/item.tres") as Item
	if broadsword == null or broadsword.card_set == null:
		push_warning("CombatScene: broadsword.tres not found or has no card_set — deck will be empty.")
		return

	for card in broadsword.card_set.cards:
		card.source_item = broadsword
		$DeckManager.deck.append(card)

	$DeckManager.deck.shuffle()

## Rebuild the deck whenever a slot changes (e.g., mid-combat equip swap).
func _on_slot_changed(_payload: Dictionary) -> void:
	$DeckManager.build_deck($Mech/SlotManager)

## Enable the button only during the player's turn.
func _on_turn_started(payload: Dictionary) -> void:
	var is_player_turn: bool = payload.get("owner", "") == "player"
	$UI/EndTurnButton.disabled = not is_player_turn

## Disable the button when combat ends.
func _on_combat_ended(_payload: Dictionary) -> void:
	$UI/EndTurnButton.disabled = true

## Called when the player clicks "End Turn".
func _on_end_turn() -> void:
	$UI/EndTurnButton.disabled = true
	# Discard remaining hand cards before the enemy turn begins.
	$HandManager.end_turn()
	$CombatTurnManager.end_player_turn()

## Check each frame if any enemy has died; remove from grid and respawn a new one.
func _process(_delta: float) -> void:
	for enemy in $Enemies.get_children():
		if enemy.has_method("is_alive") and not enemy.is_alive():
			_respawn_enemy(enemy)

## Remove a dead enemy from the grid and spawn a fresh TestDummy.
func _respawn_enemy(dead_enemy: Node) -> void:
	var unit_id: StringName = dead_enemy.name
	# Remove from grid display.
	$BattlefieldManager._positions.erase(unit_id)
	$BattlefieldManager._unit_nodes.erase(unit_id)
	$GridLayer/BattlefieldGrid.remove_unit_sprite(unit_id)

	# Remove from CombatTurnManager's enemy list.
	$CombatTurnManager.enemies.erase(dead_enemy)

	# Free the dead enemy node.
	dead_enemy.queue_free()

	# Spawn a new TestDummy.
	var dummy_scene: PackedScene = load("res://nodes/TestDummy.tscn")
	var new_dummy: Node = dummy_scene.instantiate()
	new_dummy.name = "TestDummy"
	$Enemies.add_child(new_dummy)

	# Place on grid at starting position.
	$BattlefieldManager.place_unit(&"TestDummy", Vector2i(6, 3), new_dummy)
	$CombatTurnManager.enemies.append(new_dummy)
