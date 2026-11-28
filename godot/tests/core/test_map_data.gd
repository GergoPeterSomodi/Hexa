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
	assert_eq(MapState.SCHEMA, "hexa-godot/map-state/6")
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


func _state_with_works(m: MapData) -> MapState:
	var s := MapState.create(m)
	for spec: Array in [[1, Vector2i(3, 2), &"build", 3, 1, 4, 3], [3, Vector2i(5, 2), &"upgrade", 1, 4, 8, 8]]:
		var w := Work.new()
		w.id = int(spec[0])
		w.tag = &"GEN"
		w.hex = spec[1]
		w.action = spec[2]
		w.family = int(spec[3])
		w.level_to = int(spec[4])
		w.started_turn = 2
		w.seasons = int(spec[5])
		w.seasons_left = int(spec[6])
		s.works.append(w)
	s.next_work_id = 4
	return s


func test_map_state_schema_3_round_trip_with_works() -> void:
	var m := _map()
	var s := _state_with_works(m)
	var d := s.to_dict()
	assert_eq(d["schema"], "hexa-godot/map-state/6")
	var back := MapState.from_dict(JSON.parse_string(JSON.stringify(d)) as Dictionary, m)
	assert_not_null(back)
	assert_eq(back.works.size(), 2)
	assert_eq(back.next_work_id, 4)
	assert_eq(back.works[1].digest_text(), s.works[1].digest_text())
	assert_eq(back.digest(), s.digest())
	assert_eq(back.work_at(Vector2i(5, 2)).id, 3)
	assert_null(back.work_at(Vector2i(0, 0)))
	var again := MapState.from_dict(back.to_dict(), m)
	assert_eq(again.digest(), s.digest(), "save, load, save")


func test_map_state_digest_moves_with_a_work_and_copies_are_independent() -> void:
	var m := _map()
	var s := _state_with_works(m)
	var copy := s.duplicate_state()
	assert_eq(copy.digest(), s.digest())
	copy.works[0].seasons_left -= 1
	assert_ne(copy.digest(), s.digest(), "the digest moves with one seasons_left")
	assert_eq(s.works[0].seasons_left, 3, "duplicate_state copies the works")
	var next := s.duplicate_state()
	next.next_work_id = 9
	assert_ne(next.digest(), s.digest(), "and with next_work_id")


func test_map_state_schemas_1_and_2_load_with_no_works() -> void:
	var m := _map()
	var s := MapState.create(m)
	s.main_use[8] = 3
	var v2 := {
		"schema": MapState.SCHEMA_V2,
		"size": 35,
		"main_use": Marshalls.raw_to_base64(s.main_use),
		"level": Marshalls.raw_to_base64(s.level),
		"owner": Marshalls.raw_to_base64(s.owner),
	}
	var back := MapState.from_dict(v2, m)
	assert_not_null(back)
	assert_true(back.works.is_empty())
	assert_eq(back.next_work_id, 1)
	assert_eq(back.digest(), s.digest())
	v2["schema"] = MapState.SCHEMA_V1
	assert_not_null(MapState.from_dict(v2, m))


func test_map_state_refuses_damaged_works() -> void:
	var m := _map()
	var d := _state_with_works(m).to_dict()
	var bad := d.duplicate(true)
	((bad["works"] as Array)[0] as Dictionary)["seasons_left"] = "3"
	assert_null(MapState.from_dict(bad, m), "P: a string for seasons_left")
	bad = d.duplicate(true)
	bad.erase("works")
	assert_null(MapState.from_dict(bad, m), "schema 3 needs works")
	bad = d.duplicate(true)
	bad.erase("next_work_id")
	assert_null(MapState.from_dict(bad, m), "schema 3 needs next_work_id")
	bad = d.duplicate(true)
	bad["next_work_id"] = 2
	assert_null(MapState.from_dict(bad, m), "next_work_id must pass every id")
	bad = d.duplicate(true)
	((bad["works"] as Array)[1] as Dictionary)["hex"] = [3, 2]
	assert_null(MapState.from_dict(bad, m), "two works on one hex")
	bad = d.duplicate(true)
	((bad["works"] as Array)[0] as Dictionary)["hex"] = [99, 99]
	assert_null(MapState.from_dict(bad, m), "a work off the map")


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


func _state_with_people(m: MapData) -> MapState:
	var s := _state_with_works(m)
	for i: int in m.hex_count():
		if m.land[i] != 0:
			s.people[i] = 800 + i * 13
			s.people_start[i] = 790 + i * 13
			s.people_end[i] = 800 + i * 13
	return s


func test_map_state_4_create_sizes_and_copies_the_people() -> void:
	var m := _map()
	var s := MapState.create(m)
	assert_eq(s.people.size(), 35)
	assert_eq(s.people_start.size(), 35)
	assert_eq(s.people_end.size(), 35)
	assert_eq(s.people.count(0), 35, "wild people are zero")
	var p := _state_with_people(m)
	var copy := p.duplicate_state()
	assert_eq(copy.people, p.people)
	assert_eq(copy.people_start, p.people_start)
	assert_eq(copy.people_end, p.people_end)
	copy.people[10] += 1
	copy.people_start[10] += 1
	copy.people_end[10] += 1
	assert_ne(copy.people[10], p.people[10], "a copy is independent")
	assert_ne(copy.people_start[10], p.people_start[10])
	assert_ne(copy.people_end[10], p.people_end[10])


func test_map_state_4_round_trip_with_the_people() -> void:
	var m := _map()
	var s := _state_with_people(m)
	var d := s.to_dict()
	assert_eq(d["schema"], "hexa-godot/map-state/6")
	assert_true(d["people"] is PackedInt32Array, "packed as they are")
	for form: int in 2:
		var src: Dictionary = d
		if form == 0:
			src = JSON.parse_string(JSON.stringify(d)) as Dictionary
		else:
			src = bytes_to_var(var_to_bytes(d)) as Dictionary
		var back := MapState.from_dict(src, m)
		assert_not_null(back, "form %d" % form)
		assert_eq(back.people, s.people)
		assert_eq(back.people_start, s.people_start)
		assert_eq(back.people_end, s.people_end)
		assert_eq(back.digest(), s.digest())
		assert_eq(var_to_bytes(back.to_dict()), var_to_bytes(d), "save, load, save equal")


func test_map_state_digest_moves_with_one_person() -> void:
	var m := _map()
	var s := _state_with_people(m)
	var base := s.digest()
	assert_eq(_state_with_people(m).digest(), base, "the same state, the same digest")
	var seen: Dictionary = {base: true}
	for field: String in ["people", "people_start", "people_end"]:
		for hex_i: int in [8, 20]:
			var c := s.duplicate_state()
			match field:
				"people":
					c.people[hex_i] += 1
				"people_start":
					c.people_start[hex_i] += 1
				_:
					c.people_end[hex_i] += 1
			var dg := c.digest()
			assert_false(seen.has(dg), "one person in %s at %d moves the digest" % [field, hex_i])
			seen[dg] = true
	# The three arrays are told apart: the same number in one array or the next gives another digest.
	var a := MapState.create(m)
	var b := MapState.create(m)
	a.people[9] = 5
	b.people_start[9] = 5
	assert_ne(a.digest(), b.digest())


func test_map_state_schema_3_loads_with_people_at_zeros() -> void:
	var m := _map()
	var s := _state_with_works(m)
	var v3 := s.to_dict()
	v3["schema"] = MapState.SCHEMA_V3
	for key: String in ["people", "people_start", "people_end"]:
		v3.erase(key)
	var back := MapState.from_dict(v3, m)
	assert_not_null(back)
	assert_eq(back.works.size(), 2, "the works of schema 3 are read")
	assert_eq(back.people.size(), 35)
	assert_eq(back.people.count(0), 35)
	assert_eq(back.people_start.count(0), 35)
	assert_eq(back.people_end.count(0), 35)
	assert_eq(back.digest(), s.digest(), "the zero people of a fresh state")
	assert_eq(back.to_dict()["schema"], MapState.SCHEMA, "saved again as map-state/6")
	var v2 := {"schema": MapState.SCHEMA_V2, "main_use": Marshalls.raw_to_base64(s.main_use),
		"level": Marshalls.raw_to_base64(s.level), "owner": Marshalls.raw_to_base64(s.owner)}
	var back2 := MapState.from_dict(v2, m)
	assert_not_null(back2)
	assert_eq(back2.people.size(), 35)
	assert_eq(back2.people_end.count(0), 35)


func test_map_state_4_refuses_mistyped_or_wrongly_sized_people() -> void:
	var m := _map()
	var d := _state_with_people(m).to_dict()
	for key: String in ["people", "people_start", "people_end"]:
		var bad := d.duplicate(true)
		bad[key] = "text"
		assert_null(MapState.from_dict(bad, m), "P: a string in %s" % key)
		bad = d.duplicate(true)
		bad[key] = Marshalls.raw_to_base64(PackedByteArray([1, 2, 3]))
		assert_null(MapState.from_dict(bad, m), "P: base64 text in %s" % key)
		bad = d.duplicate(true)
		bad[key] = PackedInt32Array([1, 2, 3])
		assert_null(MapState.from_dict(bad, m), "P: %s of the wrong size" % key)
		bad = d.duplicate(true)
		bad[key] = PackedInt32Array()
		assert_null(MapState.from_dict(bad, m), "P: %s empty" % key)
		bad = d.duplicate(true)
		bad[key] = PackedByteArray([0, 0, 0])
		assert_null(MapState.from_dict(bad, m), "P: %s as bytes" % key)
		bad = d.duplicate(true)
		bad.erase(key)
		assert_null(MapState.from_dict(bad, m), "P: %s missing in schema 4" % key)
		bad = d.duplicate(true)
		bad[key] = null
		assert_null(MapState.from_dict(bad, m), "P: %s null" % key)
		bad = d.duplicate(true)
		var list: Array = []
		for i: int in 35:
			list.append(1)
		list[4] = "7"
		bad[key] = list
		assert_null(MapState.from_dict(bad, m), "P: a string inside a list for %s" % key)
		list[4] = 1.5
		bad[key] = list
		assert_null(MapState.from_dict(bad, m), "P: a fraction inside a list for %s" % key)
		list[4] = -3
		bad[key] = list
		assert_null(MapState.from_dict(bad, m), "P: a negative person in %s" % key)
		bad[key] = list.slice(0, 20)
		assert_null(MapState.from_dict(bad, m), "P: a list of 20 for %s" % key)
	var negative := d.duplicate(true)
	var packed: PackedInt32Array = (negative["people"] as PackedInt32Array).duplicate()
	packed[8] = -1
	negative["people"] = packed
	assert_null(MapState.from_dict(negative, m), "P: a packed negative")


func test_map_state_5_occupation_round_trip_and_copies() -> void:
	var m := _map()
	var s := _state_with_people(m)
	var i := 10
	s.occupier[i] = 3
	s.garrison[i] = 250
	s.unsupported[i] = 2
	var d := s.to_dict()
	assert_eq(d["schema"], "hexa-godot/map-state/6")
	var back := MapState.from_dict(JSON.parse_string(JSON.stringify(d)) as Dictionary, m)
	assert_not_null(back)
	assert_eq(back.occupier[i], 3)
	assert_eq(back.garrison[i], 250)
	assert_eq(back.unsupported[i], 2)
	assert_eq(back.digest(), s.digest(), "the occupation is in the digest and survives a save")
	var copy := s.duplicate_state()
	copy.occupier[i] = 9
	assert_eq(s.occupier[i], 3, "a copy is independent")


func test_map_state_4_loads_with_the_occupation_at_zeros() -> void:
	var m := _map()
	var s := _state_with_people(m)
	var n := m.hex_count()
	var v4 := s.to_dict()
	v4["schema"] = MapState.SCHEMA_V4
	for key: String in ["occupier", "garrison", "unsupported"]:
		v4.erase(key)
	var back := MapState.from_dict(v4, m)
	assert_not_null(back, "schema 4 is still read (tests only)")
	assert_eq(back.occupier.count(0), n)
	assert_eq(back.garrison.count(0), n)
	assert_eq(back.unsupported.count(0), n)
	assert_eq(back.people, s.people, "the people come through")


func test_map_state_5_refuses_damaged_occupation() -> void:
	var m := _map()
	var s := _state_with_people(m)
	var text := s.to_dict()
	text["occupier"] = Marshalls.raw_to_base64(PackedByteArray([1, 2, 3]))
	assert_null(MapState.from_dict(text, m), "P: an occupier of the wrong size")
	var short := s.to_dict()
	short["garrison"] = [1, 2]
	assert_null(MapState.from_dict(short, m), "P: a garrison of the wrong size")
	var neg := s.to_dict()
	var g := Array(s.garrison)
	g[0] = -1
	neg["garrison"] = g
	assert_null(MapState.from_dict(neg, m), "P: a negative garrison")
	var missing := s.to_dict()
	missing.erase("unsupported")
	assert_null(MapState.from_dict(missing, m), "P: unsupported missing")
	var wrong_schema := s.to_dict()
	wrong_schema["schema"] = "hexa-godot/map-state/7"
	assert_null(MapState.from_dict(wrong_schema, m), "P: a schema that is not known")


func test_map_state_5_occupation_refuses_sea_and_out_of_range_values() -> void:
	var m := _map()
	var s := _state_with_people(m)
	var n := m.hex_count()
	var sea := -1
	var land := -1
	for i: int in n:
		if m.land[i] == 0 and sea < 0:
			sea = i
		if m.land[i] != 0 and land < 0:
			land = i
	assert_gt(sea, -1, "the fixture has sea")
	assert_gt(land, -1, "the fixture has land")
	var bytes := PackedByteArray()
	bytes.resize(n)
	bytes[land] = 3
	var ok := s.to_dict()
	ok["occupier"] = Marshalls.raw_to_base64(bytes)
	assert_not_null(MapState.from_dict(ok, m), "an occupier of a country id on land reads")
	bytes[land] = 255
	var top := s.to_dict()
	top["occupier"] = Marshalls.raw_to_base64(bytes)
	assert_null(MapState.from_dict(top, m), "P: 255 is no country id")
	var bytes_sea := PackedByteArray()
	bytes_sea.resize(n)
	bytes_sea[sea] = 3
	var at_sea := s.to_dict()
	at_sea["occupier"] = Marshalls.raw_to_base64(bytes_sea)
	assert_null(MapState.from_dict(at_sea, m), "P: an occupier on a sea hex")
	var g := Array(s.garrison)
	g[sea] = 1
	var garrison_sea := s.to_dict()
	garrison_sea["garrison"] = g
	assert_null(MapState.from_dict(garrison_sea, m), "P: a garrison on a sea hex")
	var g2 := Array(s.garrison)
	g2[land] = 3000000000
	var huge := s.to_dict()
	huge["garrison"] = g2
	assert_null(MapState.from_dict(huge, m), "P: a garrison above int32")


func test_the_projected_size_of_the_made_up_europe() -> void:
	var big := MapData.new()
	big.allocate(346, 353)
	assert_eq(big.hex_count(), 122138)
	var s := MapState.create(big)
	# The countryside at its room: long runs of equal numbers, a few villages and towns.
	for i: int in s.people.size():
		var run := floori(float(i) / 400.0)
		var v := 0 if run % 5 == 0 else 2000 + (run % 7) * 1000
		s.people[i] = v
		s.people_start[i] = v
		s.people_end[i] = v + (4 if i % 97 == 0 and v > 0 else 0)
	var raw := s.people.to_byte_array().size() * 3
	assert_eq(raw, 3 * 4 * big.hex_count())
	assert_lt(raw, 1_500_000, "about 1.46 MB before compression")
	var packed := var_to_bytes(s.to_dict()).compress(FileAccess.COMPRESSION_ZSTD)
	assert_lt(packed.size(), 600_000, "mostly equal runs: well under the raw size")
	var back := MapState.from_dict(bytes_to_var(var_to_bytes(s.to_dict())) as Dictionary, big)
	assert_not_null(back)
	assert_eq(back.digest(), s.digest())
