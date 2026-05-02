# Feature: mech-deckbuilder-core-systems, Property 18: has_tag is a correct membership test
# Tests that Card.has_tag(tag) is a correct membership test for the tags array.
# Validates: Requirements 15.2, 15.4
@tool
extends EditorScript

const ITERATIONS := 100

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var failures := 0

	for i in range(ITERATIONS):
		# Generate a random tag list of length 0–10 using "tag_0" .. "tag_N" style names.
		var tag_count: int = rng.randi_range(0, 10)
		var tags: Array[String] = []
		for j in range(tag_count):
			tags.append("tag_%d" % rng.randi_range(0, 9))

		# Build a Card and assign the generated tags.
		var card := Card.new()
		card.tags = tags

		# --- Positive case: every tag that IS in the list must return true ---
		for tag in tags:
			if not card.has_tag(tag):
				push_error(
					"FAIL iteration %d (positive): has_tag('%s') returned false but tag is in %s"
					% [i, tag, str(tags)]
				)
				failures += 1

		# --- Negative case: a tag that is NOT in the list must return false ---
		# Build a candidate tag that is guaranteed to be absent.
		var absent_tag := "tag_absent_%d" % i
		# Make sure it really isn't in the list (it shouldn't be, but be explicit).
		while absent_tag in tags:
			absent_tag += "_x"

		if card.has_tag(absent_tag):
			push_error(
				"FAIL iteration %d (negative): has_tag('%s') returned true but tag is NOT in %s"
				% [i, absent_tag, str(tags)]
			)
			failures += 1

		# --- Extra negative case: pick a tag name just outside the generated range ---
		# Tags are "tag_0".."tag_9"; use "tag_10" which is never generated above.
		var out_of_range_tag := "tag_10"
		if out_of_range_tag in tags:
			# Shouldn't happen, but skip this check if it somehow ended up in the list.
			pass
		else:
			if card.has_tag(out_of_range_tag):
				push_error(
					"FAIL iteration %d (negative-range): has_tag('%s') returned true but tag is NOT in %s"
					% [i, out_of_range_tag, str(tags)]
				)
				failures += 1

	if failures == 0:
		print("PASS: Property 18 — has_tag membership correctness (%d iterations)" % ITERATIONS)
	else:
		push_error("FAIL: Property 18 — %d/%d iterations failed" % [failures, ITERATIONS])
