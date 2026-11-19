## Unit tests for CountryNames (docs/architecture/m2-build-spec.md sections 5.7 and 10).
extends GutTest

const DEFS_PATH := "res://data/defs/game_defs.tres"
const MAP_PATH := "res://data/maps/north_italy.tres"
const SCEN_PATH := "res://data/scenarios/north_italy_1480.tres"


func _make_custom_game(cols: int, rows: int, owners_by_id: Dictionary) -> Game:
	var map := MapData.new()
	map.id = "names_fixture"
	map.allocate(cols, rows)
	for i: int in map.hex_count():
		map.land[i] = 1
		map.cover[i] = WorldCover.FARMLAND
	var defs := GameDefs.new()
	defs.tinctures = GameDefs.default_tinctures()
	defs.cb_palette = GameDefs.default_cb_palette()
	var scen := ScenarioDef.new()
	scen.id = "names_scen"
	scen.map_id = map.id
	scen.map_digest = map.digest()
	scen.owner.resize(map.hex_count())
	scen.owner.fill(0)
	var cid := 1
	for tag: StringName in owners_by_id.keys():
		var cdef := ScenarioFixture.make_country(tag, "Country %s" % String(tag), "Long %s" % String(tag),
			"Adj %s" % String(tag), Color("#b3261e"))
		defs.countries.append(cdef)
		scen.countries.append(tag)
		var hexes: Array = owners_by_id[tag] as Array
		scen.capitals.append(hexes[0] as Vector2i)
		scen.cb_colours.append(cid - 1)
		for hv: Variant in hexes:
			scen.owner[map.index_of(hv as Vector2i)] = cid
		cid += 1
	defs.scenarios = [scen]
	return Game.new_scenario(map, defs, scen, 1480)


func test_null_and_map_only_return_empty() -> void:
	assert_eq(CountryNames.places(null), [] as Array[Dictionary])
	assert_eq(CountryNames.places_of(null, PackedInt32Array([1])), [] as Array[Dictionary])
	var map := MapData.new()
	map.allocate(4, 4)
	var sandbox := Game.new_game(map, 1480)
	assert_eq(CountryNames.places(sandbox), [] as Array[Dictionary])


func test_min_region_size_deepest_hex_and_lowest_index_tie() -> void:
	# 7-hex flower around (2, 2) for AAA (deepest hex must be (2, 2));
	# 2-hex disconnected enclave at (4, 0)-(5, 0) for AAA (skipped, < 3 hexes);
	# 3-hex horizontal strip (0, 5)-(2, 5) for BBB (all boundary -> tie breaks by lowest index (0, 5)).
	var grid := HexGrid.new(28.0, 111.2, 45.0, 0.0, 0.0)
	var center := Vector2i(2, 2)
	var flower: Array[Vector2i] = [center]
	for d: int in 6:
		flower.append(grid.neighbour(center, d))
	var aaa_hexes: Array[Vector2i] = [Vector2i(4, 0), Vector2i(5, 0)]
	aaa_hexes.append_array(flower)
	var bbb_hexes: Array[Vector2i] = [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5)]

	var game := _make_custom_game(6, 7, {&"AAA": aaa_hexes, &"BBB": bbb_hexes})
	var entries := CountryNames.places(game)
	assert_eq(entries.size(), 2, "2-hex enclave skipped; one label for AAA flower and one for BBB strip")

	var first := entries[0]
	assert_eq(int(first["id"]), 1)
	assert_eq(first["tag"], &"AAA")
	assert_eq(str(first["text"]), "Country AAA")
	assert_eq(first["at"], MapTiles.cell_centre(center), "7-hex flower puts label at deepest center hex")
	assert_eq(int(first["hexes"]), 7)
	assert_eq(float(first["span_px"]), 3.0 * 104.0)

	var second := entries[1]
	assert_eq(int(second["id"]), 2)
	assert_eq(second["tag"], &"BBB")
	assert_eq(second["at"], MapTiles.cell_centre(Vector2i(0, 5)), "flat strip breaks tie by lowest hex index")
	assert_eq(int(second["hexes"]), 3)
	assert_eq(float(second["span_px"]), 3.0 * 104.0)


func test_committed_1480_regions_and_places_of_subset() -> void:
	var defs := ResourceLoader.load(DEFS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	var map := ResourceLoader.load(MAP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as MapData
	var scen := ResourceLoader.load(SCEN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ScenarioDef
	var game := Game.new_scenario(map, defs, scen, 1480)

	var all := CountryNames.places(game)
	# 13 countries: FRA has 2 regions >= 3, VEN has 1 >= 3 (Ravenna is 2), LUC has 1 region of 2 (skipped) -> 13 labels.
	assert_eq(all.size(), 13)
	var fra_count := 0
	var ven_count := 0
	var luc_count := 0
	for entry: Dictionary in all:
		if entry["tag"] == &"FRA":
			fra_count += 1
		elif entry["tag"] == &"VEN":
			ven_count += 1
		elif entry["tag"] == &"LUC":
			luc_count += 1
	assert_eq(fra_count, 2, "France has two regions >= 3")
	assert_eq(ven_count, 1, "Venice's 2-hex Ravenna exclave is skipped")
	assert_eq(luc_count, 0, "Lucca's 2-hex territory is skipped")

	# places_of with unsorted / duplicate / out-of-range ids equals the matching slice of places().
	var mlo_id := scen.id_of(&"MLO")
	var fra_id := scen.id_of(&"FRA")
	var subset := CountryNames.places_of(game, PackedInt32Array([mlo_id, 0, fra_id, mlo_id, 99]))
	var expected: Array[Dictionary] = []
	for entry: Dictionary in all:
		var eid := int(entry["id"])
		if eid == fra_id or eid == mlo_id:
			expected.append(entry)
	assert_eq(subset, expected, "places_of equals the matching part of places in id then region order")


## The plain way, one hex at a time through HexGrid: what the fast regions and label search must give.
func _reference_regions(map: MapData, owner: PackedByteArray, id: int) -> Array[PackedInt32Array]:
	var grid := map.grid()
	var seen: Dictionary[int, bool] = {}
	var out: Array[PackedInt32Array] = []
	for start: int in map.hex_count():
		if seen.has(start) or map.land[start] == 0 or int(owner[start]) != id:
			continue
		var comp := PackedInt32Array()
		var queue: Array[int] = [start]
		seen[start] = true
		while not queue.is_empty():
			var cur: int = queue.pop_front()
			comp.append(cur)
			for d: int in 6:
				var nb := map.index_of(grid.neighbour(map.hex_of(cur), d))
				if nb >= 0 and not seen.has(nb) and map.land[nb] != 0 and int(owner[nb]) == id:
					seen[nb] = true
					queue.append(nb)
		comp.sort()
		out.append(comp)
	return out


func _reference_label_hex(map: MapData, region: PackedInt32Array) -> Vector2i:
	var grid := map.grid()
	var dist: Dictionary[int, int] = {}
	for idx: int in region:
		dist[idx] = -1
	var queue: Array[int] = []
	for idx: int in region:
		for d: int in 6:
			if not dist.has(map.index_of(grid.neighbour(map.hex_of(idx), d))):
				dist[idx] = 0
				queue.append(idx)
				break
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for d: int in 6:
			var nb := map.index_of(grid.neighbour(map.hex_of(cur), d))
			if nb >= 0 and dist.get(nb, 0) == -1:
				dist[nb] = dist[cur] + 1
				queue.append(nb)
	var best := region[0]
	for idx: int in region:
		if dist[idx] > dist[best]:
			best = idx
	return map.hex_of(best)


func test_regions_and_label_hex_match_the_plain_search_on_a_scrambled_map() -> void:
	var map := MapData.new()
	map.allocate(13, 12)
	var owner := PackedByteArray()
	owner.resize(map.hex_count())
	for i: int in map.hex_count():
		var h := (i * 73856093) ^ (i * i * 19349663)
		h = (h ^ (h >> 11)) & 0x7fffffff
		map.land[i] = 0 if h % 9 == 0 else 1  # a little sea
		owner[i] = 1 if h % 7 < 5 else (2 if h % 7 == 5 else 0)  # country 1 is most of it, so its regions touch the rim
	for id: int in [1, 2]:
		var fast := ScenarioGrowth.regions(map, owner, id)
		var plain := _reference_regions(map, owner, id)
		assert_eq(fast.size(), plain.size(), "country %d: the same number of regions" % id)
		for r: int in mini(fast.size(), plain.size()):
			assert_eq(fast[r], plain[r], "country %d region %d: the same hexes" % [id, r])
			assert_eq(CountryNames.region_label_hex(map, fast[r]), _reference_label_hex(map, plain[r]),
				"country %d region %d: the same label hex" % [id, r])
