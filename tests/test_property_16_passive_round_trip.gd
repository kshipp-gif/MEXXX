# Feature: mech-deckbuilder-core-systems, Property 16: Passive apply/remove round-trip
# Tests that applying a passive to a target and then removing it returns the target's
# stats to their original values — i.e., apply followed by remove is a no-op.
# Validates: Requirements 11.1, 11.2
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		# --- Generate random passive values ---
		var armor_amount: int = rng.randi_range(1, 20)
		var regen_amount: int = rng.randi_range(1, 10)

		# --- Create a plain Node as the mock target ---
		var target: Node = load("res://tests/MockUnit.gd").new()

		# --- Create passives ---
		var armor_passive := ArmorPassive.new()
		armor_passive.armor_amount = armor_amount

		var regen_passive := RegenPassive.new()
		regen_passive.regen_amount = regen_amount

		# --- Apply both passives ---
		armor_passive.apply(target)
		regen_passive.apply(target)

		# --- Verify stats were applied correctly ---
		var armor_after_apply = target.get("armor_bonus")
		var regen_after_apply = target.get("regen_per_turn")

		if armor_after_apply != armor_amount:
			push_error(
				"FAIL iteration %d: after apply, armor_bonus expected %d but got %s"
				% [i, armor_amount, str(armor_after_apply)]
			)
			failures += 1
			target.free()
			continue

		if regen_after_apply != regen_amount:
			push_error(
				"FAIL iteration %d: after apply, regen_per_turn expected %d but got %s"
				% [i, regen_amount, str(regen_after_apply)]
			)
			failures += 1
			target.free()
			continue

		# --- Remove both passives ---
		armor_passive.remove(target)
		regen_passive.remove(target)

		# --- Verify stats returned to zero (original values) ---
		var armor_after_remove = target.get("armor_bonus")
		var regen_after_remove = target.get("regen_per_turn")

		if armor_after_remove != 0:
			push_error(
				"FAIL iteration %d: after remove, armor_bonus expected 0 but got %s (armor_amount=%d)"
				% [i, str(armor_after_remove), armor_amount]
			)
			failures += 1
			target.free()
			continue

		if regen_after_remove != 0:
			push_error(
				"FAIL iteration %d: after remove, regen_per_turn expected 0 but got %s (regen_amount=%d)"
				% [i, str(regen_after_remove), regen_amount]
			)
			failures += 1
			target.free()
			continue

		target.free()

	if failures == 0:
		print("PASS: Property 16 — Passive apply/remove round-trip (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 16 — %d/%d iterations failed" % [failures, ITERATIONS])
