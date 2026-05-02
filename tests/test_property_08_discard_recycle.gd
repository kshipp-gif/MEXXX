# Feature: mech-deckbuilder-core-systems, Property 8: Discard recycle round-trip
# Validates: Requirements 4.6
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

		# Draw all cards into hand, then discard all to populate discard_pile
		var total: int = dm.deck_size()
		dm.draw(total)
		dm.discard_hand()

		if not dm.deck.is_empty():
			push_error(
				"FAIL iter %d: deck should be empty before recycle, has %d cards"
				% [i, dm.deck.size()]
			)
			failures += 1
			continue

		var discard_before := card_multiset(dm.discard_pile)
		var discard_refs: Array = dm.discard_pile.duplicate()

		dm.recycle_discard()

		if not dm.discard_pile.is_empty():
			push_error(
				"FAIL iter %d: discard_pile not empty after recycle_discard — has %d cards"
				% [i, dm.discard_pile.size()]
			)
			failures += 1
			continue

		var deck_after := card_multiset(dm.deck)
		if deck_after != discard_before:
			push_error(
				"FAIL iter %d: deck after recycle does not match pre-recycle discard.\n  Expected: %s\n  Got:      %s"
				% [i, str(discard_before), str(deck_after)]
			)
			failures += 1
			continue

		for card in discard_refs:
			if card not in dm.deck:
				push_error(
					"FAIL iter %d: card '%s' was in discard but is missing from deck after recycle"
					% [i, card.display_name]
				)
				failures += 1
				break

	if failures == 0:
		print("PASS: Property 8 — Discard recycle round-trip (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 8 — %d/%d iterations failed" % [failures, ITERATIONS])
