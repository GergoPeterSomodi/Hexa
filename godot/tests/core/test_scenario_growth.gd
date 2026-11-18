## ScenarioGrowth (core/defs/scenario_growth.gd; docs/architecture/m2-build-spec.md sections 4.3, 5.1, and 10):
## step costs (normal, crest, pass, river, stream, sea), deterministic Dijkstra growth, tie-breaking,
## town vs anchor start, reach, pins, hand-computed 9x7 ownership grid, neighbour_pairs, and regions.
extends GutTest


func _blank_land_map(cols: int, rows: int) -> MapData:
	var m := MapData.new()
	m.id = "growth_fixture"
	m.hex_w_km = 28.0
	m.ref_lat = 45.0
	m.allocate(cols, rows)
	m.land.fill(1)
	m.cover.fill(0)
	m.depth.fill(0)
	m.relief.fill(1)
	return m


func _scen_base(countries: Array[StringName]) -> ScenarioDef:
	var s := ScenarioDef.new()
	s.id = "growth_test"
	s.countries = countries
	return s


func test_step_costs_and_sea_bounds() -> void:
	var m := _blank_land_map(9, 7)
	for c: int in 9:
		m.land[m.index_of(Vector2i(c, 0))] = 0  # sea row 0
	var s := _scen_base([&"AAA"])

	# Normal land-to-land step = 2.
	assert_eq(ScenarioGrowth.step(m, s, Vector2i(2, 2), 0), 2)

	# Crest without pass = 2 + 3 = 5.
	var e_crest := m.edge_index(Vector2i(3, 2), 0)
	m.crest[e_crest] = 1
	assert_eq(ScenarioGrowth.step(m, s, Vector2i(3, 2), 0), 5)
	assert_eq(ScenarioGrowth.step(m, s, Vector2i(4, 2), 3), 5, "same cost from opposite side")

	# Crest with pass = 2.
	var e_pass := m.edge_index(Vector2i(3, 3), 0)
	m.crest[e_pass] = 1
	m.pass_edge[e_pass] = 1
	assert_eq(ScenarioGrowth.step(m, s, Vector2i(3, 3), 0), 2)

	# River (class 1..3) = 2 + 1 = 3.
	var e_river := m.edge_index(Vector2i(2, 3), 0)
	m.river[e_river] = 2
	assert_eq(ScenarioGrowth.step(m, s, Vector2i(2, 3), 0), 3)

	# Stream (class 4) = 2.
	var e_stream := m.edge_index(Vector2i(2, 4), 0)
	m.river[e_stream] = 4
	assert_eq(ScenarioGrowth.step(m, s, Vector2i(2, 4), 0), 2)

	# Crest + river combined = 2 + 3 + 1 = 6.
	m.river[e_crest] = 1
	assert_eq(ScenarioGrowth.step(m, s, Vector2i(3, 2), 0), 6)

	# Sea or off-map returns -1.
	assert_eq(ScenarioGrowth.step(m, s, Vector2i(2, 1), 1), -1, "step into sea")
	assert_eq(ScenarioGrowth.step(m, s, Vector2i(2, 0), 5), -1, "step from sea")
	assert_eq(ScenarioGrowth.step(m, s, Vector2i(8, 2), 0), -1, "step off map")


func test_tie_breaking_and_town_vs_anchor() -> void:
	var m := _blank_land_map(7, 5)
	var s := _scen_base([&"AAA", &"BBB"])
	s.seeds = [
		{"hex": Vector2i(1, 2), "tag": &"AAA", "kind": &"town", "note": ""},
		{"hex": Vector2i(5, 2), "tag": &"BBB", "kind": &"town", "note": ""},
	]
	var owner_ab := ScenarioGrowth.grow(m, s)
	assert_eq(owner_ab[m.index_of(Vector2i(3, 2))], 1, "tie at cost 4 goes to earlier seed AAA")

	# Reverse seed order: tie now goes to BBB.
	s.seeds = [
		{"hex": Vector2i(5, 2), "tag": &"BBB", "kind": &"town", "note": ""},
		{"hex": Vector2i(1, 2), "tag": &"AAA", "kind": &"town", "note": ""},
	]
	var owner_ba := ScenarioGrowth.grow(m, s)
	assert_eq(owner_ba[m.index_of(Vector2i(3, 2))], 2, "tie at cost 4 goes to earlier seed BBB")

	# Anchor starts at cost 1, so town (start 0) wins equidistant hex even if anchor is listed first.
	s.seeds = [
		{"hex": Vector2i(1, 2), "tag": &"AAA", "kind": &"anchor", "note": ""},
		{"hex": Vector2i(5, 2), "tag": &"BBB", "kind": &"town", "note": ""},
	]
	var owner_anchor := ScenarioGrowth.grow(m, s)
	assert_eq(owner_anchor[m.index_of(Vector2i(1, 2))], 1)
	assert_eq(owner_anchor[m.index_of(Vector2i(3, 2))], 2, "town (cost 4) beats anchor (cost 5)")


func test_reach_pins_sea_and_determinism() -> void:
	var m := _blank_land_map(9, 7)
	m.land[m.index_of(Vector2i(0, 2))] = 0  # sea hex
	var s := _scen_base([&"AAA", &"BBB"])
	s.reach = 4
	s.seeds = [
		{"hex": Vector2i(2, 2), "tag": &"AAA", "kind": &"town", "note": ""},
		{"hex": Vector2i(0, 2), "tag": &"BBB", "kind": &"town", "note": "on sea, ignored"},
	]
	var owner := ScenarioGrowth.grow(m, s)
	assert_eq(owner[m.index_of(Vector2i(0, 2))], 0, "sea stays 0 even with seed")
	assert_eq(owner[m.index_of(Vector2i(2, 2))], 1)
	assert_eq(owner[m.index_of(Vector2i(4, 2))], 1, "cost 4 within reach")
	assert_eq(owner[m.index_of(Vector2i(5, 2))], 0, "cost 6 beyond reach=4 stays 0")

	# Pins overwrite single land hexes, &"" frees to 0, sea pin stays 0.
	s.pins = [
		{"hex": Vector2i(7, 5), "tag": &"BBB", "note": "claim"},
		{"hex": Vector2i(3, 2), "tag": &"", "note": "free"},
		{"hex": Vector2i(0, 2), "tag": &"AAA", "note": "sea ignored"},
	]
	var pinned := ScenarioGrowth.grow(m, s)
	assert_eq(pinned[m.index_of(Vector2i(7, 5))], 2)
	assert_eq(pinned[m.index_of(Vector2i(3, 2))], 0)
	assert_eq(pinned[m.index_of(Vector2i(0, 2))], 0)

	# Determinism across repeated runs.
	assert_eq(ScenarioGrowth.grow(m, s), pinned)


func test_hand_computed_9x7_ridge_pass_river_grid() -> void:
	var m := _blank_land_map(9, 7)
	for c: int in 9:
		m.land[m.index_of(Vector2i(c, 0))] = 0  # row 0 is sea

	# Complete mountain ridge between cols <= 4 and cols >= 5, with a single pass at (4,2)-(5,2).
	var ridge_edges: Array[Array] = [
		[Vector2i(4, 1), 0], [Vector2i(4, 1), 5],
		[Vector2i(4, 2), 0],
		[Vector2i(4, 3), 1], [Vector2i(4, 3), 0], [Vector2i(4, 3), 5],
		[Vector2i(4, 4), 0],
		[Vector2i(4, 5), 1], [Vector2i(4, 5), 0], [Vector2i(4, 5), 5],
		[Vector2i(4, 6), 0],
	]
	for re: Array in ridge_edges:
		m.crest[m.edge_index(re[0] as Vector2i, int(re[1]))] = 1
	m.pass_edge[m.edge_index(Vector2i(4, 2), 0)] = 1

	# Rivers (+1) south-west and south-east of (3,2); stream (+0) north-west of (3,2).
	m.river[m.edge_index(Vector2i(3, 2), 4)] = 2
	m.river[m.edge_index(Vector2i(3, 2), 5)] = 2
	m.river[m.edge_index(Vector2i(3, 2), 2)] = 4

	var s := _scen_base([&"AAA", &"BBB", &"CCC"])
	s.seeds = [
		{"hex": Vector2i(3, 2), "tag": &"AAA", "kind": &"town", "note": ""},
		{"hex": Vector2i(7, 4), "tag": &"BBB", "kind": &"town", "note": ""},
		{"hex": Vector2i(1, 5), "tag": &"CCC", "kind": &"anchor", "note": ""},
	]
	s.pins = [
		{"hex": Vector2i(8, 1), "tag": &"AAA", "note": "pin override"},
		{"hex": Vector2i(0, 1), "tag": &"", "note": "free corner"},
	]
	var got := ScenarioGrowth.grow(m, s)

	# Legend: 0 = sea/free, 1 = AAA, 2 = BBB, 3 = CCC.
	var expected_rows: Array[Array] = [
		[0, 0, 0, 0, 0, 0, 0, 0, 0],  # row 0 (sea)
		[0, 1, 1, 1, 1, 1, 2, 2, 1],  # row 1: (0,1) freed by pin; (5,1) tie cost 6 -> AAA; (8,1) pinned AAA
		[1, 1, 1, 1, 1, 1, 2, 2, 2],  # row 2: (5,2) reached via pass by AAA at cost 4 (< BBB cost 6)
		[3, 1, 1, 1, 1, 2, 2, 2, 2],  # row 3: (0,3) CCC 5 < AAA 6; (5,3) BBB cost 4 < AAA cost 6
		[3, 3, 3, 1, 1, 2, 2, 2, 2],  # row 4: (3,4) tie cost 5 -> AAA; (4,4) AAA 5 < CCC 9
		[3, 3, 3, 3, 1, 2, 2, 2, 2],  # row 5: (4,5) tie cost 7 (AAA via (3,3)->(4,4)->(4,5)) -> AAA
		[3, 3, 3, 3, 3, 2, 2, 2, 2],  # row 6
	]
	for r: int in 7:
		for c: int in 9:
			assert_eq(int(got[m.index_of(Vector2i(c, r))]), int(expected_rows[r][c]),
				"hex (%d, %d)" % [c, r])


func test_neighbour_pairs_and_regions() -> void:
	var m := _blank_land_map(6, 4)
	# Sea barrier down col 2 on rows 1..3; sea on row 0 except (0,0) and (5,0).
	for c: int in 6:
		m.land[m.index_of(Vector2i(c, 0))] = 0
	for r: int in 4:
		m.land[m.index_of(Vector2i(2, r))] = 0

	var owner := PackedByteArray()
	owner.resize(m.hex_count())
	owner.fill(0)
	# Country 1 split into two disconnected land components: west (0..1, 1..2) and east (5, 2..3).
	for hex: Vector2i in [Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2),
			Vector2i(5, 2), Vector2i(5, 3)]:
		owner[m.index_of(hex)] = 1
	# Country 2 on (0..1, 3) and (3..4, 1..2).
	for hex: Vector2i in [Vector2i(0, 3), Vector2i(1, 3), Vector2i(3, 1), Vector2i(4, 1),
			Vector2i(3, 2), Vector2i(4, 2)]:
		owner[m.index_of(hex)] = 2
	# Country 3 on (3..4, 3) touching country 2 and country 1.
	for hex: Vector2i in [Vector2i(3, 3), Vector2i(4, 3)]:
		owner[m.index_of(hex)] = 3
	# (5, 1) left unowned (0) so it touches 2 and 1 without producing a 0-pair.

	var pairs := ScenarioGrowth.neighbour_pairs(m, owner)
	assert_eq(pairs, [Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3)] as Array[Vector2i])

	var reg1 := ScenarioGrowth.regions(m, owner, 1)
	assert_eq(reg1.size(), 2, "country 1 has two disconnected regions")
	assert_eq(reg1[0], PackedInt32Array([
		m.index_of(Vector2i(0, 1)), m.index_of(Vector2i(1, 1)),
		m.index_of(Vector2i(0, 2)), m.index_of(Vector2i(1, 2)),
	]))
	assert_eq(reg1[1], PackedInt32Array([
		m.index_of(Vector2i(5, 2)), m.index_of(Vector2i(5, 3)),
	]))
	assert_eq(ScenarioGrowth.regions(m, owner, 0).size(), 0)
	assert_eq(ScenarioGrowth.regions(m, owner, 9).size(), 0)
