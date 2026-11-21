## The distance tables of a searched WorldImprove (place_distance, town_distance, city_distance) move one settlement
## change at a time (core/systems/settle_distances.gd, issue #413) and stay exactly what a full recompute gives: a property
## over random sequences of level changes, new settlements and cleared ones on a mid-size map, and a count of the hex
## distances a level change works out on a large map (a count, never a time).
extends GutTest


## The reference: every land hex against every settlement of the state, as the full recompute did it.
func _reference(imp: WorldImprove) -> Dictionary:
	var settled: Array[Vector3i] = []
	for hex: Vector2i in imp.hexes:
		if imp.family_at(hex) == ImproveRules.SETTLEMENT:
			settled.append(Vector3i(hex.x, hex.y, imp.level_at(hex)))
	var out: Dictionary = {}
	for hex: Vector2i in imp.hexes:
		var near := [99, 99, 99]
		for s: Vector3i in settled:
			var d := ImproveRules.hex_distance(hex, Vector2i(s.x, s.y))
			if d == 0:
				continue
			near[0] = mini(near[0], d)
			if s.z >= 3:
				near[1] = mini(near[1], d)
			if s.z >= 4:
				near[2] = mini(near[2], d)
		out[hex] = near
	return out


## "" when the facts of every hex equal the reference, else the first difference.
func _difference(imp: WorldImprove) -> String:
	var want := _reference(imp)
	for hex: Vector2i in imp.hexes:
		var facts := imp.facts_at(hex)
		var near: Array = want[hex]
		for t: int in 3:
			if int(facts[SettleDistances.KEYS[t]]) != int(near[t]):
				return "%s %s: %d, a full recompute says %d" % [hex, SettleDistances.KEYS[t], int(facts[SettleDistances.KEYS[t]]), int(near[t])]
	return ""


func _map(cols: int, rows: int, settlements: int, seed_value: int) -> MapData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var over: Dictionary = {}
	while over.size() < settlements:
		over[Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))] = {"place": ImproveFixture.place(rng.randi_range(1, 5))}
	return ImproveFixture.block(cols, rows, {}, over)


func test_the_start_equals_a_full_recompute() -> void:
	var imp := WorldImprove.build(_map(60, 40, 40, 5), 1)
	assert_eq(_difference(imp), "")


func test_random_changes_keep_the_tables_equal_to_a_full_recompute() -> void:
	for seed_value: int in [3, 11]:
		var imp := WorldImprove.build(_map(60, 40, 40, seed_value), 1)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value * 101
		var settled: Array[Vector2i] = []
		for hex: Vector2i in imp.hexes:
			if imp.family_at(hex) == ImproveRules.SETTLEMENT:
				settled.append(hex)
		assert_gt(settled.size(), 20, "the map has settlements to change")
		for step: int in 70:
			var roll := rng.randi_range(0, 9)
			var hex := settled[rng.randi_range(0, settled.size() - 1)] if roll < 6 else Vector2i(rng.randi_range(0, 59), rng.randi_range(0, 39))
			var label := "seed %d step %d at %s" % [seed_value, step, hex]
			if roll < 6:  # a level change of a settlement, any level to any other (up and down, across 3 and 4 or not)
				imp.put_piece(hex, ImproveRules.SETTLEMENT, rng.randi_range(1, 5))
			elif roll < 8:  # a settlement where there was none (or a level change if there was one)
				imp.put_piece(hex, ImproveRules.SETTLEMENT, rng.randi_range(1, 5))
				if not settled.has(hex):
					settled.append(hex)
			else:  # a settlement pulled down, or another piece on the hex
				imp.put_piece(hex, ImproveRules.NONE if roll == 8 else ImproveRules.WHEAT, 0 if roll == 8 else 1)
				settled.erase(hex)
			var wrong := _difference(imp)
			if wrong != "":
				fail_test("%s: %s" % [label, wrong])
				return
		assert_eq(_difference(imp), "", "after 70 changes")


func test_the_player_actions_move_the_tables_too() -> void:
	var map := ImproveFixture.block(20, 12, {}, {Vector2i(5, 5): {"place": ImproveFixture.place(2)}, Vector2i(15, 6): {"place": ImproveFixture.place(4)}})
	var imp := WorldImprove.build(map, 1)
	assert_true(bool(imp.upgrade(Vector2i(5, 5))["ok"]), "village to town")
	assert_eq(int(imp.facts_at(Vector2i(8, 5))["town_distance"]), 3)
	assert_eq(_difference(imp), "")
	assert_true(bool(imp.lower(Vector2i(15, 6))["ok"]), "city to town")
	assert_eq(_difference(imp), "")
	assert_true(bool(imp.lower(Vector2i(5, 5))["ok"]), "town to village")
	assert_eq(int(imp.facts_at(Vector2i(8, 5))["town_distance"]), int(_reference(imp)[Vector2i(8, 5)][1]))
	assert_eq(_difference(imp), "")


func test_a_level_change_costs_far_less_than_a_full_refresh() -> void:
	var cols := 120
	var rows := 80
	var imp := WorldImprove.build(_map(cols, rows, 220, 9), 1)
	var full := imp.hexes.size() * 220  # what the full recompute worked out for every change: land hexes x settlements
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var settled: Array[Vector2i] = []
	for hex: Vector2i in imp.hexes:
		if imp.family_at(hex) == ImproveRules.SETTLEMENT:
			settled.append(hex)
	var worst := 0
	for step: int in 12:
		var hex := settled[rng.randi_range(0, settled.size() - 1)]
		var before := imp.distance_evals()
		imp.put_piece(hex, ImproveRules.SETTLEMENT, 3 if imp.level_at(hex) != 3 else 4)  # crosses 3 or 4 each time
		worst = maxi(worst, imp.distance_evals() - before)
	assert_gt(worst, 0, "a change across a level works something out")
	assert_lt(worst * 20, full, "a level change works out under 5 %% of a full refresh (%d of %d)" % [worst, full])
	assert_eq(_difference(imp), "")
