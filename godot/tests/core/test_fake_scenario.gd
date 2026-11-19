## The made-up scenario (core/mapgen/fake_scenario.gd; docs/architecture/m2-build-spec.md section 9): 60 countries on the
## made-up Europe (494 x 247) and on a small map, every country owns land, every land hex is owned, the countries are
## mostly one piece, the scenario validates deep, the same map gives the same bytes. Time is never asserted here
## (tools/perf_map.gd measures it).
extends GutTest

var _map: MapData = null
var _built: Dictionary = {}


func before_all() -> void:
	_map = FakeMap.build(494, 247, 1480)
	_built = FakeScenario.build(_map, 60, 1480)


func _scenario() -> ScenarioDef:
	return _built["scenario"] as ScenarioDef


func test_sixty_countries_with_defs() -> void:
	var scenario := _scenario()
	var defs := _built["defs"] as GameDefs
	assert_eq(scenario.countries.size(), 60)
	assert_eq(scenario.capitals.size(), 60)
	assert_eq(scenario.cb_colours.size(), 60)
	assert_eq(defs.countries.size(), 60)
	assert_eq(defs.validate(), [] as Array[String])
	assert_eq(scenario.countries[0], &"FAA")
	assert_eq(scenario.countries[59], &"FCH")


func test_capitals_are_places_on_land_owned_by_their_country() -> void:
	var scenario := _scenario()
	for i: int in 60:
		var idx := _map.index_of(scenario.capitals[i])
		assert_true(_map.land[idx] != 0, "capital %d on land" % i)
		assert_true(_map.place_id[idx] >= 0, "capital %d holds a place" % i)
		assert_eq(int(scenario.owner[idx]), i + 1)


func test_every_country_owns_land() -> void:
	var counts := PackedInt32Array()
	counts.resize(61)
	for i: int in _map.hex_count():
		counts[scenario_owner(i)] += 1
	for id: int in range(1, 61):
		assert_gt(counts[id], 0, "country %d owns land" % id)


func scenario_owner(i: int) -> int:
	return int(_scenario().owner[i])


func test_owners_cover_all_land_and_no_sea() -> void:
	var bad_land := 0
	var bad_sea := 0
	for i: int in _map.hex_count():
		var o := scenario_owner(i)
		if _map.land[i] != 0 and o == 0:
			bad_land += 1
		elif _map.land[i] == 0 and o != 0:
			bad_sea += 1
	assert_eq(bad_land, 0, "unowned land hexes")
	assert_eq(bad_sea, 0, "owned sea hexes")


func test_countries_are_mostly_one_piece() -> void:
	var scenario := _scenario()
	var all_total := 0
	var all_main := 0
	for id: int in range(1, 61):
		var total := 0
		var biggest := 0
		for region: PackedInt32Array in ScenarioGrowth.regions(_map, scenario.owner, id):
			total += region.size()
			biggest = maxi(biggest, region.size())
		all_total += total
		all_main += biggest
		# Islands and inland seas cut a made-up country in pieces; none may be mostly scattered.
		assert_gte(float(biggest), 0.3 * float(total), "country %d: main region %d of %d" % [id, biggest, total])
	assert_gte(float(all_main), 0.7 * float(all_total), "land in each country's main region: %d of %d" % [all_main, all_total])


func test_owner_is_the_growth_of_the_scenario_and_validates_deep() -> void:
	var scenario := _scenario()
	assert_eq(ScenarioGrowth.grow(_map, scenario), scenario.owner)
	var errors := scenario.validate(_map, _built["defs"] as GameDefs, true)
	# Neighbour contrast is not promised by the golden-angle colours; everything else must hold.
	var other: Array[String] = []
	for line: String in errors:
		if not line.begins_with("colour contrast between"):
			other.append(line)
	assert_eq(other, [] as Array[String])


func test_same_map_same_bytes() -> void:
	var again := FakeScenario.build(_map, 60, 1480)
	assert_eq((again["scenario"] as ScenarioDef).digest(), _scenario().digest())
	assert_eq((again["defs"] as GameDefs).digest(), (_built["defs"] as GameDefs).digest())
	assert_eq((again["scenario"] as ScenarioDef).owner, _scenario().owner)


func test_small_map_gets_its_countries() -> void:
	var small := FakeMap.build(120, 60, 1480)
	var built := FakeScenario.build(small, 60, 1480)
	var scenario := built["scenario"] as ScenarioDef
	assert_eq(scenario.countries.size(), mini(60, small.places.size()))
	var counts := PackedInt32Array()
	counts.resize(scenario.countries.size() + 1)
	for i: int in small.hex_count():
		counts[int(scenario.owner[i])] += 1
		if small.land[i] != 0:
			assert_true(scenario.owner[i] != 0, "land owned")
	for id: int in range(1, scenario.countries.size() + 1):
		assert_gt(counts[id], 0, "country %d owns land" % id)


func test_fewer_countries_and_none() -> void:
	var few := FakeScenario.build(_map, 5, 1)
	assert_eq((few["scenario"] as ScenarioDef).countries.size(), 5)
	var none := FakeScenario.build(_map, 0, 1)
	assert_eq((none["scenario"] as ScenarioDef).countries.size(), 0)
