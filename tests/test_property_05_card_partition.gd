# Feature: mech-deckbuilder-core-systems, Property 5: Card partition invariant — every card is in exactly one collection
# Validates: Requirements 4.3, 4.7, 4.8
@tool
extends EditorScript

const ITERATIONS := 100

func make_card(card_name: String) -> Card:
	var c: Card = load("res://data/Card.gd").new()
	c.display_name = card_name
	return c

func make_item_with_cards(slot_type: Enums.SlotType, card_names: Array) -> Item:
	var item: Item = load("res://data/Item.gd").new()
	item.slot_type = slot_type
	item.tags = ["1H"]
	var cs: CardSet = load("res://data/CardSet.gd").new()
	for cname in card_names:
		cs.cards.append(make_card(cname))
	item.card_set = cs
	return item

func make_slot_manager() -> Node:
	var sm: Node = load("res://components/managers/SlotManager.gd").new()
	sm.slot_rules = [
		load("res://components/slot_rules/SlotOccupiedRule.gd").new(),
		load("res://components/slot_rules/SlotTypeRule.gd").new(),
		load("res://components/slot_rules/TwoHandedExclusiveRule.gd").new(),
	]
	return sm

func card_in_exactly_one(card: Card, dm: Node) -> bool:
	var count := 0
	if card in dm.deck:
		count += 1
	if card in dm.hand:
		count += 1
	if card in dm.discard_pile:
		count += 1
	return count == 1

func all_cards(dm: Node) -> Array:
	var result: Array = []
	for c in dm.deck:
		result.append(c)
	for c in dm.hand:
		result.append(c)
	for c in dm.discard_pile:
		result.append(c)
	return result

func check_partition(dm: Node, original_cards: Array, iter: int) -> bool:
	var current := all_cards(dm)
	if current.size() != original_cards.size():
		push_error(
			"FAIL iter %d: total card count changed — expected %d, got %d"
			% [iter, original_cards.size(), current.size()]
		)
		return false
	for card in original_cards:
		if not card_in_exactly_one(card, dm):
			push_error(
				"FAIL iter %d: card '%s' is not in exactly one collection"
				% [iter, card.display_name]
			)
			return false
	return true

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		var sm := make_slot_manager()
		var num_items := rng.randi_range(1, 3)

		var slot_configs: Array = [
			{ "slot": "L_Arm", "type": Enums.SlotType.ARM },
			{ "slot": "Legs",  "type": Enums.SlotType.LEG },
			{ "slot": "Back",  "type": Enums.SlotType.BACK },
		]

		var card_counter := 0
		for j in range(num_items):
			var cfg = slot_configs[j]
			var names: Array = []
			for k in range(5):
				names.append("card_%d_%d" % [i, card_counter])
				card_counter += 1
			var item := make_item_with_cards(cfg["type"], names)
			sm.equip(cfg["slot"], item)

		var dm: Node = load("res://components/managers/DeckManager.gd").new()
		dm.build_deck(sm)

		var original_cards: Array = []
		for c in dm.deck:
			original_cards.append(c)

		if original_cards.is_empty():
			continue

		var ops := rng.randi_range(5, 20)
		for _op in range(ops):
			var op_type := rng.randi_range(0, 3)
			match op_type:
				0:
					dm.draw(rng.randi_range(1, 3))
				1:
					if not dm.hand.is_empty():
						var idx := rng.randi_range(0, dm.hand.size() - 1)
						dm.discard_card(dm.hand[idx])
				2:
					dm.discard_hand()
				3:
					if not dm.discard_pile.is_empty():
						dm.recycle_discard()

		if not check_partition(dm, original_cards, i):
			failures += 1

	if failures == 0:
		print(
			"PASS: Property 5 — Card partition invariant — every card is in exactly one collection (%d iterations)"
			% ITERATIONS
		)
	else:
		push_error("FAIL: Property 5 — %d/%d iterations failed" % [failures, ITERATIONS])
