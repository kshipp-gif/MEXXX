# Feature: mech-deckbuilder-core-systems, Property 6: Deck assembly contains exactly the cards from all equipped non-Head sets
# Validates: Requirements 4.1
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

	var slot_configs: Array = [
		{ "slot": "L_Arm", "type": Enums.SlotType.ARM },
		{ "slot": "R_Arm", "type": Enums.SlotType.ARM },
		{ "slot": "Legs",  "type": Enums.SlotType.LEG },
		{ "slot": "Back",  "type": Enums.SlotType.BACK },
	]

	for i in range(ITERATIONS):
		var sm := make_slot_manager()
		var expected_cards: Array = []
		var card_counter := 0

		var shuffled_configs: Array = slot_configs.duplicate()
		shuffled_configs.shuffle()

		var num_to_equip := rng.randi_range(0, shuffled_configs.size())
		for j in range(num_to_equip):
			var cfg = shuffled_configs[j]
			var names: Array = []
			for k in range(5):
				var cname := "iter%d_slot%d_card%d" % [i, j, k]
				names.append(cname)
				card_counter += 1
			var item := make_item_with_cards(cfg["type"], names)
			var ok: bool = sm.equip(cfg["slot"], item)
			if ok:
				for cname in names:
					expected_cards.append(cname)

		# Equip a Head item — its cards must NOT appear in deck
		var head_item: Item = load("res://data/Item.gd").new()
		head_item.slot_type = Enums.SlotType.HEAD
		head_item.tags = []
		var head_cs: CardSet = load("res://data/CardSet.gd").new()
		for k in range(3):
			head_cs.cards.append(make_card("head_card_%d_%d" % [i, k]))
		head_item.card_set = head_cs
		sm.equip("Head", head_item)

		var dm: Node = load("res://components/managers/DeckManager.gd").new()
		dm.build_deck(sm)

		var actual_names := card_multiset(dm.deck)
		expected_cards.sort()

		if actual_names != expected_cards:
			push_error(
				"FAIL iter %d: deck multiset mismatch.\n  Expected (%d): %s\n  Got (%d): %s"
				% [i, expected_cards.size(), str(expected_cards), actual_names.size(), str(actual_names)]
			)
			failures += 1

		for c in dm.deck:
			if c.display_name.begins_with("head_card_"):
				push_error(
					"FAIL iter %d: Head item card '%s' found in deck — should be excluded"
					% [i, c.display_name]
				)
				failures += 1
				break

	if failures == 0:
		print(
			"PASS: Property 6 — Deck assembly contains exactly the cards from all equipped non-Head sets (%d iterations)"
			% ITERATIONS
		)
	else:
		push_error("FAIL: Property 6 — %d/%d iterations failed" % [failures, ITERATIONS])
