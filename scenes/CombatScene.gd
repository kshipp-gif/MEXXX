## CombatScene — root script that wires cross-manager references on startup
## and exposes _start_combat() for Main to call after instantiation.
## Requirements: 8.1, 8.2, 8.3, 14.6, 18.5
extends Node

func _ready() -> void:
	# Wire HandManager references.
	$HandManager.deck_manager = $DeckManager
	$HandManager.ap_manager = $Mech/APManager

	# Wire CombatTurnManager references.
	$CombatTurnManager.mech = $Mech
	$CombatTurnManager.battlefield_manager = $BattlefieldManager
	$CombatTurnManager.ap_manager = $Mech/APManager

	# Wire HandDisplay pile count labels and inspect panel.
	$UI/HandDisplay.draw_count_label = $UI/DrawPile/DrawCountLabel
	$UI/HandDisplay.discard_count_label = $UI/DiscardPile/DiscardCountLabel
	$UI/HandDisplay.inspect_panel = $UI/CardInspectPanel

	# Subscribe DeckManager to slot_changed so it rebuilds the deck on equip changes.
	EventBus.subscribe("slot_changed", _on_slot_changed)

	# Subscribe to turn_started so we can enable/disable the End Turn button.
	EventBus.subscribe("turn_started", _on_turn_started)
	EventBus.subscribe("combat_ended", _on_combat_ended)

	# Wire the End Turn button.
	$UI/EndTurnButton.pressed.connect(_on_end_turn)

	# Build a test deck of 15 TestCard instances directly in DeckManager.
	_build_test_deck()

## Called by Main after the scene is added to the tree.
## Collects enemy nodes from the Enemies container and starts combat.
func _start_combat() -> void:
	var enemy_nodes: Array[Node] = []
	for child in $Enemies.get_children():
		enemy_nodes.append(child)
	$CombatTurnManager.start_combat(enemy_nodes)

## Create 15 Card resources and load them directly into DeckManager.deck.
## This bypasses SlotManager/CardSet so combat works without equipped items.
func _build_test_deck() -> void:
	$DeckManager.deck.clear()
	$DeckManager.hand.clear()
	$DeckManager.discard_pile.clear()
	for i in range(15):
		var card := Card.new()
		card.display_name = "Test Card %d" % (i + 1)
		card.ap_cost = 1
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
	$CombatTurnManager.end_player_turn()
