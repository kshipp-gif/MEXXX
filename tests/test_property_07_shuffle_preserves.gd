# Feature: mech-deckbuilder-core-systems, Property 7: Shuffle preserves deck contents
# Validates: Requirements 4.2
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

func card_multiset(cards: Array) -> Array:
	var names: Array = []
	for c in cards:
		names.append(c.display_name)
	names.sort()
	return names

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

		for j in range(num_items):
			var cfg = slot_configs[j]
			var names: Array = []
			for k in range(5):
				names.append("iter%d_item%d_card%d" % [i, j, k])
			var item := make_item_with_cards(cfg["type"], names)
			sm.equip(cfg["slot"], item)

		var dm: Node = load("res://components/managers/DeckManager.gd").new()
		dm.build_deck(sm)

		var before_multiset := card_multiset(dm.deck)
		var before_size: int = dm.deck.size()

		dm.deck.shuffle()

		var after_multiset := card_multiset(dm.deck)
		var after_size: int = dm.deck.size()

		if after_size != before_size:
			push_error(
				"FAIL iter %d: deck size changed after shuffle — before %d, after %d"
				% [i, before_size, after_size]
			)
			failures += 1
			continue

		if after_multiset != before_multiset:
			push_error(
				"FAIL iter %d: deck multiset changed after shuffle.\n  Before: %s\n  After:  %s"
				% [i, str(before_multiset), str(after_multiset)]
			)
			failures += 1

	if failures == 0:
		print("PASS: Property 7 — Shuffle preserves deck contents (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 7 — %d/%d iterations failed" % [failures, ITERATIONS])
