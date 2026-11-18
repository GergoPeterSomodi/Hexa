## MapData and MapState (core/defs/map_data.gd, core/state/map_state.gd; docs/architecture/m1-build-spec.md section 4
## and 14): index and edge index from both sides, validate, digest, MapState round trip.
extends GutTest


## A 7 x 5 map: sea on the west two columns and the top row, land elsewhere, a river to the sea, a road between two places.
func _map() -> MapData:
	var m := MapData.new()
	m.id = "fixture"
	m.hex_w_km = 28.0
	m.ref_lat = 45.0
	m.allocate(7, 5)
	for r: int in 5:
		for c: int in 7:
			var i := r * 7 + c
			if c >= 2 and r >= 1:
				m.land[i] = 1
				m.cover[i] = 0
				m.depth[i] = 0
				m.height_m[i] = 100 + c
				m.relief[i] = 1
	m.places = [{"name": "A", "hex": Vector2i(3, 2), "level": 1}, {"name": "B", "hex": Vector2i(5, 2), "level": 1}]
	m.place_id[m.index_of(Vector2i(3, 2))] = 0
	m.place_id[m.index_of(Vector2i(5, 2))] = 1
	m.passes = [{"name": "P", "hex": Vector2i(4, 3), "metres": 900}]
	m.pass_id[m.index_of(Vector2i(4, 3))] = 0
	# A road from A to B: edge E of A (3,2) leads to (4,2); edge E of (4,2) leads to B.
	m.road[m.edge_index(Vector2i(3, 2), 0)] = 2
	m.road[m.edge_index(Vector2i(4, 2), 0)] = 2
	# A river on the west edge of (2,2): to the sea hex (1,2).
	m.river[m.edge_index(Vector2i(2, 2), 3)] = 2
	return m


func test_index_round_trip_and_bounds() -> void:
	var m := _map()
	for i: int in 35:
		assert_eq(m.index_of(m.hex_of(i)), i, "index %d" % i)
	assert_eq(m.index_of(Vector2i(-1, 0)), -1)
	assert_eq(m.index_of(Vector2i(7, 0)), -1)
	assert_eq(m.index_of(Vector2i(0, 5)), -1)
	assert_true(m.has(Vector2i(6, 4)))
	assert_false(m.has(Vector2i(6, 5)))
	assert_true(m.is_land(Vector2i(3, 2)))
	assert_false(m.is_land(Vector2i(0, 2)), "sea")
	assert_false(m.is_land(Vector2i(-3, 2)), "off the map")


func test_edge_index_is_equal_from_both_sides_for_every_edge() -> void:
	var m := _map()
	var seen: Dictionary = {}
	for i: int in 35:
		var hex := m.hex_of(i)
		for d: int in 6:
			var nb := m.neighbour(hex, d)
			var e := m.edge_index(hex, d)
			if not m.has(nb):
				# Owned edges still have a slot at the map border; the other three belong to nobody.
				assert_eq(e >= 0, d < 3, "border edge %s dir %d" % [hex, d])
				continue
			assert_eq(e, m.edge_index(nb, (d + 3) % 6), "edge %s dir %d from both sides" % [hex, d])
			assert_true(e >= 0 and e < m.edge_count(), "in range")
			seen[e] = true
	# Every slot is some inner edge or a border edge; no two edges share a slot.
	var slots: Dictionary = {}
	for i: int in 35:
		for d: int in 3:
			var e := m.edge_index(m.hex_of(i), d)
			assert_false(slots.has(e), "slot %d used twice" % e)
			slots[e] = true
	assert_eq(slots.size(), 105)
	assert_eq(m.edge_index(Vector2i(-1, 0), 0), -1, "off the map")


func test_river_road_and_coast_lookups() -> void:
	var m := _map()
	assert_eq(m.river_on(Vector2i(2, 2), 3), 2)
	assert_eq(m.river_on(Vector2i(1, 2), 0), 2, "the same edge from the sea side")
	assert_eq(m.river_on(Vector2i(4, 4), 1), 0)
	assert_eq(m.road_on(Vector2i(3, 2), 0), 2)
	assert_eq(m.road_on(Vector2i(4, 2), 3), 2, "from the other side")
	assert_eq(m.road_on(Vector2i(-1, 0), 0), 0)
	# (2, 2) is even: its west neighbour (1, 2) is sea; its top row neighbours (1,1) and (2,1): NW is (1,1) sea.
	var mask := m.coast_mask(Vector2i(2, 2))
	assert_true((mask & (1 << 3)) != 0, "west is sea")
	assert_true((mask & (1 << 2)) != 0, "north-west is sea")
	assert_eq(mask & (1 << 0), 0, "east is land")
	# Off the map counts as land: (6, 4) is land on the border, with land on the other sides.
	assert_eq(m.coast_mask(Vector2i(6, 4)), 0)


func test_validate_accepts_the_fixture_and_finds_faults() -> void:
	var m := _map()
	assert_eq(m.validate(), [] as Array[String], "fixture is sound")
	var bad := _map()
	bad.land.resize(10)
	assert_false(bad.validate().is_empty(), "short array")
	bad = _map()
	bad.road[bad.edge_index(Vector2i(6, 4), 1)] = 1
	assert_false(bad.validate().is_empty(), "a road with no place")
	bad = _map()
	# A river in the middle of land that reaches neither sea nor edge.
	bad.river[bad.edge_index(Vector2i(4, 3), 0)] = 1
	assert_false(bad.validate().is_empty(), "a river that goes nowhere")
	bad = _map()
	bad.place_id[3] = 5
	assert_false(bad.validate().is_empty(), "place index out of range")
	bad = _map()
	bad.relief[8] = 9
	assert_false(bad.validate().is_empty(), "relief out of range")


func test_validate_checks_shoreline_and_height_grid() -> void:
	var m := _map()
	var g := m.grid()
	# A shoreline: a vertical line through every coast crossing is enough for the test; build one segment per
	# land/sea neighbour pair, across the line between their centres.
	var line := PackedVector2Array()
	var lines: Array[PackedVector2Array] = []
	for i: int in 35:
		for k: int in 3:
			var hex := m.hex_of(i)
			var nb := m.neighbour(hex, k)
			if m.has(nb) and m.is_land(hex) != m.is_land(nb):
				var mid := (g.centre_km(hex) + g.centre_km(nb)) * 0.5
				lines.append(PackedVector2Array([mid + Vector2(0, -3), mid + Vector2(0, 3)]))
	assert_true(lines.size() > 4)
	line = lines[0]
	m.shoreline = lines
	assert_eq(m.validate(), [] as Array[String], "shoreline agrees with the land")
	m.shoreline = [line] as Array[PackedVector2Array]
	assert_false(m.validate().is_empty(), "one short line cannot be the whole coast")
	m.shoreline = lines
	# A raster that covers the map.
	var step := m.hex_w_km / float(MapData.HEIGHT_GRID_STEP)
	var w := int(ceil(28.0 * 7.5 / step)) + 2
	var h := int(ceil((g.hex_r_km * 2.0 + g.hex_h_km * 4.0) / step)) + 2
	m.height_grid_origin_km = Vector2(-step, -step)
	m.height_grid_size = Vector2i(w, h)
	m.height_grid.resize(w * h)
	assert_eq(m.validate(), [] as Array[String], "raster covers the map")
	m.height_grid_size = Vector2i(w - 20, h)
	m.height_grid.resize((w - 20) * h)
	assert_false(m.validate().is_empty(), "raster too small")
	m.height_grid_size = Vector2i(w, h)
	m.height_grid.resize(w * h - 1)
	assert_false(m.validate().is_empty(), "raster size does not match")


func test_digest_is_stable_and_sees_every_field() -> void:
	var a := _map()
	var b := _map()
	assert_eq(a.digest(), b.digest(), "same map, same digest")
	assert_eq(a.digest().length(), 64)
	var base := a.digest()
	var edits: Array[Callable] = [
		func(m: MapData) -> void: m.height_m[9] += 1,
		func(m: MapData) -> void: m.river[20] = 3,
		func(m: MapData) -> void: m.crossing[4] = 1,
		func(m: MapData) -> void: m.places[0]["level"] = 2,
		func(m: MapData) -> void: m.rivers.append({"name": "R", "class": 1, "corners": PackedVector2Array([Vector2(1, 2)])}),
		func(m: MapData) -> void: m.shoreline = [PackedVector2Array([Vector2(1, 2), Vector2(3, 4)])] as Array[PackedVector2Array],
		func(m: MapData) -> void: m.height_grid = PackedInt32Array([1]),
		func(m: MapData) -> void: m.height_grid_origin_km = Vector2(1, 1),
		func(m: MapData) -> void: m.id = "other",
	]
	var seen: Dictionary = {base: true}
	for edit: Callable in edits:
		var m := _map()
		edit.call(m)
		var d := m.digest()
		assert_false(seen.has(d), "an edit changed the digest")
		seen[d] = true


func test_map_state_round_trip() -> void:
	var m := _map()
	var s := MapState.create(m)
	assert_eq(s.main_use.size(), 35)
	assert_eq(s.level.size(), 35)
	assert_eq(s.owner.size(), 35)
	for i: int in 35:
		assert_eq(s.owner[i], 0, "default owner is 0")
	s.main_use[8] = 3
	s.level[8] = 2
	s.main_use[30] = 255
	s.owner[m.index_of(Vector2i(3, 2))] = 7
	s.owner[m.index_of(Vector2i(5, 2))] = 254
	var d := s.to_dict()
	assert_eq(d["schema"], MapState.SCHEMA)
	# JSON-safe: survives text.
	var parsed: Variant = JSON.parse_string(JSON.stringify(d))
	assert_true(parsed is Dictionary)
	var back := MapState.from_dict(parsed as Dictionary, m)
	assert_not_null(back)
	assert_eq(back.main_use, s.main_use)
	assert_eq(back.level, s.level)
	assert_eq(back.owner, s.owner)
	assert_eq(back.digest(), s.digest())
	var copy := s.duplicate_state()
	copy.level[0] = 1
	assert_ne(copy.digest(), s.digest())
	assert_eq(s.level[0], 0, "a copy is independent")
	var owner_copy := s.duplicate_state()
	owner_copy.owner[m.index_of(Vector2i(4, 2))] = 5
	assert_ne(owner_copy.digest(), s.digest(), "digest moves with one owner byte")
	assert_eq(s.owner[m.index_of(Vector2i(4, 2))], 0, "owner copy is independent")


func test_map_state_schema_1_loads_with_zero_owners() -> void:
	var m := _map()
	var s := MapState.create(m)
	s.main_use[8] = 3
	s.level[8] = 2
	var v1 := {
		"schema": MapState.SCHEMA_V1,
		"size": 35,
		"main_use": Marshalls.raw_to_base64(s.main_use),
		"level": Marshalls.raw_to_base64(s.level),
	}
	var parsed: Variant = JSON.parse_string(JSON.stringify(v1))
	assert_true(parsed is Dictionary)
	var back := MapState.from_dict(parsed as Dictionary, m)
	assert_not_null(back)
	assert_eq(back.main_use, s.main_use)
	assert_eq(back.level, s.level)
	assert_eq(back.owner.size(), 35)
	for i: int in 35:
		assert_eq(back.owner[i], 0, "schema 1 loads with owner 0")
	assert_eq(back.digest(), s.digest())


func test_map_state_refuses_a_wrong_map_or_schema() -> void:
	var m := _map()
	var s := MapState.create(m)
	var other := MapData.new()
	other.allocate(3, 3)
	assert_null(MapState.from_dict(s.to_dict(), other), "size mismatch")
	var d := s.to_dict()
	d["schema"] = "nope"
	assert_null(MapState.from_dict(d, m), "schema mismatch")
	var missing_owner := s.to_dict()
	missing_owner.erase("owner")
	assert_null(MapState.from_dict(missing_owner, m), "schema 2 missing owner")
	var bad_owner := s.to_dict()
	bad_owner["owner"] = Marshalls.raw_to_base64(PackedByteArray([1, 2, 3]))
	assert_null(MapState.from_dict(bad_owner, m), "schema 2 owner size mismatch")
	assert_null(MapState.from_dict({}, m), "empty")
