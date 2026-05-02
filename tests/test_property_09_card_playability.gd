# Feature: mech-deckbuilder-core-systems, Property 9: Card playability reflects current AP and ammo state
# Validates: Requirements 5.2, 10.2, 10.5
@tool
extends EditorScript

const ITERATIONS := 100

func make_card(card_name: String, ap_cost: int, tags: Array[String] = []) -> Card:
	var c: Card = load("res://data/Card.gd").new()
	c.display_name = card_name
	c.ap_cost = ap_cost
	c.tags = tags
	return c

func make_item_with_ammo(max_ammo: int, current_ammo: int) -> Item:
	var item: Item = load("res://data/Item.gd").new()
	item.max_ammo = max_ammo
	item.current_ammo = current_ammo
	return item

func make_hand_manager(current_ap: int) -> Node:
	var dm: Node = load("res://components/managers/DeckManager.gd").new()
	var ap: Node = load("res://components/managers/APManager.gd").new()
	ap.max_ap = current_ap
	ap.current_ap = current_ap
	var hm: Node = load("res://components/managers/HandManager.gd").new()
	hm.deck_manager = dm
	hm.ap_manager = ap
	# Manually sync _current_ap since _ready() won't fire outside the scene tree
	hm._current_ap = current_ap
	return hm

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	# --- Sub-property A: card with ap_cost > current_ap is NOT playable ---
	for i in range(ITERATIONS):
		var current_ap: int = rng.randi_range(0, 5)
		var ap_cost: int = current_ap + rng.randi_range(1, 4)

		var hm := make_hand_manager(current_ap)
		var card := make_card("expensive_card_%d" % i, ap_cost)
		hm.deck_manager.hand.append(card)

		var playable: Array = hm.get_playable_cards()
		if card in playable:
			push_error(
				"FAIL [A] iter %d: card with ap_cost=%d should NOT be playable at current_ap=%d"
				% [i, ap_cost, current_ap]
			)
			failures += 1

	# --- Sub-property B: card with ap_cost <= current_ap IS playable (no ammo issue) ---
	for i in range(ITERATIONS):
		var current_ap: int = rng.randi_range(1, 6)
		var ap_cost: int = rng.randi_range(0, current_ap)

		var hm := make_hand_manager(current_ap)
		var card := make_card("affordable_card_%d" % i, ap_cost)
		hm.deck_manager.hand.append(card)

		var playable: Array = hm.get_playable_cards()
		if card not in playable:
			push_error(
				"FAIL [B] iter %d: card with ap_cost=%d SHOULD be playable at current_ap=%d"
				% [i, ap_cost, current_ap]
			)
			failures += 1

	# --- Sub-property C: card with "ammo" tag and current_ammo == 0 is NOT playable ---
	for i in range(ITERATIONS):
		var current_ap: int = rng.randi_range(2, 6)
		var ap_cost: int = rng.randi_range(0, current_ap)
		var max_ammo: int = rng.randi_range(1, 6)

		var hm := make_hand_manager(current_ap)
		var item := make_item_with_ammo(max_ammo, 0)  # current_ammo == 0 (depleted)
		var card := make_card("ammo_card_%d" % i, ap_cost, ["ammo"])
		card.source_item = item
		hm.deck_manager.hand.append(card)

		var playable: Array = hm.get_playable_cards()
		if card in playable:
			push_error(
				"FAIL [C] iter %d: ammo card with current_ammo=0 should NOT be playable (ap_cost=%d, current_ap=%d)"
				% [i, ap_cost, current_ap]
			)
			failures += 1

	if failures == 0:
		print("PASS: Property 9 — Card playability reflects current AP and ammo state (%d iterations each sub-property)" % ITERATIONS)
	else:
		push_error("FAIL: Property 9 — %d failure(s) across all sub-properties" % failures)
