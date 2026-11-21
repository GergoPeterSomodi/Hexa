## StepCosts (docs/architecture/m6-build-spec.md sections 4.3, 5.0 R6 and 5.3; task L3): every rule of 4.3 on a fixture map
## built here, the worked steps of 4.3 on north Italy, the supply cost, the lazy fill equal to `compute` everywhere, the memo,
## and planted faults (P) on copies of the defs.
extends GutTest

## Table 4.3 move points by cover id: farmland, grassland, woods, marsh, rock, snow, tundra, sand.
const MOVE := [2, 2, 3, 4, 4, 6, 3, 2]
const RELIEF_ADD := [0, 0, 0, 0, 1, 2, 3]

var _map: MapData
var _defs: GameDefs


func before_each() -> void:
	StepCosts.clear_all()
	_map = PathFixture.open_map()
	_defs = PathFixture.defs_copy()


func after_each() -> void:
	StepCosts.clear_all()


## The step from `hex` east (direction 0) or west (3), on the fixture map with the fixture defs.
func _step(hex: Vector2i, d: int, winter: bool) -> int:
	return StepCosts.compute(_map, _defs, _map.index_of(hex), d, winter)


func _set_cover(hex: Vector2i, cover: int, climate: int = 2) -> void:
	var i := _map.index_of(hex)
	_map.cover[i] = cover
	_map.climate[i] = climate


func test_committed_numbers_are_the_spec_values() -> void:
	var defs := EconomyFixture.committed()
	assert_eq(defs.relief_move_add, PackedInt32Array(RELIEF_ADD))
	assert_eq(defs.highway_cap, 1)
	assert_eq(defs.road_cap, 2)
	assert_eq(defs.track_divisor, 2)
	assert_eq(defs.winter_snow_percent, 200)
	assert_eq(defs.pass_closing_climate, 0)
	assert_eq(defs.stream_cost, 1)
	assert_eq(defs.river_cost, 2)
	assert_eq(defs.ford_cost, 1)
	assert_eq(defs.ferry_cost, 2)
	assert_eq(defs.river_wade_class, 2)
	assert_eq(defs.river_wall_class, 3)
	assert_eq(defs.wade_plan_cost, 12)
	assert_eq(defs.supply_wade_cost, 3)


func test_each_cover_costs_its_move_points() -> void:
	for cover: int in 8:
		_map = PathFixture.open_map()
		_set_cover(Vector2i(4, 3), cover)
		assert_eq(_step(Vector2i(3, 3), 0, false), MOVE[cover], "cover %d summer" % cover)
		assert_eq(_step(Vector2i(3, 3), 0, true), MOVE[cover], "cover %d winter, temperate climate: no doubling" % cover)


func test_each_relief_adds_its_move_points() -> void:
	for relief: int in 7:
		_map = PathFixture.open_map()
		_map.relief[_map.index_of(Vector2i(4, 3))] = relief
		assert_eq(_step(Vector2i(3, 3), 0, false), 2 + RELIEF_ADD[relief], "relief %d" % relief)


func test_sea_and_the_map_edge_are_blocked() -> void:
	_map.land[_map.index_of(Vector2i(4, 3))] = 0
	_map.cover[_map.index_of(Vector2i(4, 3))] = MapData.COVER_SEA
	assert_eq(_step(Vector2i(3, 3), 0, false), StepCosts.BLOCKED, "into the sea")
	assert_eq(_step(Vector2i(0, 3), 3, false), StepCosts.BLOCKED, "west off the map")
	assert_eq(_step(Vector2i(8, 3), 0, false), StepCosts.BLOCKED, "east off the map")


func test_a_crest_blocks_unless_it_is_a_pass() -> void:
	PathFixture.set_edge(_map, Vector2i(3, 3), 0, &"crest", 1)
	assert_eq(_step(Vector2i(3, 3), 0, false), StepCosts.BLOCKED, "a crest")
	assert_eq(_step(Vector2i(4, 3), 3, false), StepCosts.BLOCKED, "the same crest from the other side")
	PathFixture.set_edge(_map, Vector2i(3, 3), 0, &"pass_edge", 1)
	assert_eq(_step(Vector2i(3, 3), 0, false), 2, "a crest with a pass is walked")
	assert_eq(_step(Vector2i(3, 3), 0, true), 2, "a pass in a mild winter is walked")


func test_a_pass_beside_snow_closes_in_winter_only() -> void:
	PathFixture.set_edge(_map, Vector2i(3, 3), 0, &"pass_edge", 1)
	_map.climate[_map.index_of(Vector2i(4, 3))] = 0
	assert_eq(_step(Vector2i(3, 3), 0, true), StepCosts.CLOSED, "winter, snow beside the pass")
	assert_eq(_step(Vector2i(3, 3), 0, false), 2, "summer, the same pass is open")
	assert_eq(_step(Vector2i(4, 3), 3, true), StepCosts.CLOSED, "from the snow side too")


func test_a_road_caps_or_divides_the_cost() -> void:
	_set_cover(Vector2i(4, 3), 2)  # woods, 3
	PathFixture.set_edge(_map, Vector2i(3, 3), 0, &"road", 1)
	assert_eq(_step(Vector2i(3, 3), 0, false), 2, "a track: ceil(3 / 2)")
	PathFixture.set_edge(_map, Vector2i(3, 3), 0, &"road", 2)
	assert_eq(_step(Vector2i(3, 3), 0, false), 2, "a road caps at 2")
	PathFixture.set_edge(_map, Vector2i(3, 3), 0, &"road", 3)
	assert_eq(_step(Vector2i(3, 3), 0, false), 1, "a highway caps at 1")
	_set_cover(Vector2i(4, 3), 0)  # farmland, 2
	PathFixture.set_edge(_map, Vector2i(3, 3), 0, &"road", 1)
	assert_eq(_step(Vector2i(3, 3), 0, false), 1, "a track over farmland")


func test_a_winter_on_snow_climate_doubles_the_cost() -> void:
	_set_cover(Vector2i(4, 3), 0, 0)  # farmland on snow climate
	assert_eq(_step(Vector2i(3, 3), 0, false), 2, "summer: no snow")
	assert_eq(_step(Vector2i(3, 3), 0, true), 4, "winter: 2 x 200 %")


func test_streams_and_rivers_follow_their_crossings() -> void:
	_set_cover(Vector2i(4, 3), 0)
	var at := Vector2i(3, 3)
	PathFixture.set_edge(_map, at, 0, &"river", 4)
	assert_eq(_step(at, 0, false), 3, "a stream without a bridge: +1")
	PathFixture.set_edge(_map, at, 0, &"crossing", 2)
	assert_eq(_step(at, 0, false), 2, "a stream with a wooden bridge: +0")
	PathFixture.set_edge(_map, at, 0, &"crossing", 0)
	PathFixture.set_edge(_map, at, 0, &"river", 1)
	assert_eq(_step(at, 0, false), 4, "a class 1 river with no crossing: +2")
	PathFixture.set_edge(_map, at, 0, &"crossing", 1)
	assert_eq(_step(at, 0, false), 3, "a ford: +1")
	PathFixture.set_edge(_map, at, 0, &"crossing", 4)
	assert_eq(_step(at, 0, false), 4, "a ferry: +2")
	PathFixture.set_edge(_map, at, 0, &"crossing", 3)
	assert_eq(_step(at, 0, false), 2, "a stone bridge: +0")


func test_a_class_2_river_without_crossing_is_wade_and_class_3_is_a_wall() -> void:
	var at := Vector2i(3, 3)
	PathFixture.set_edge(_map, at, 0, &"river", 2)
	assert_eq(_step(at, 0, false), StepCosts.WADE, "class 2 wades")
	PathFixture.set_edge(_map, at, 0, &"crossing", 2)
	assert_eq(_step(at, 0, false), 2, "class 2 with a bridge is walked")
	PathFixture.set_edge(_map, at, 0, &"crossing", 0)
	PathFixture.set_edge(_map, at, 0, &"river", 3)
	assert_eq(_step(at, 0, false), StepCosts.BLOCKED, "class 3 is a wall")
	PathFixture.set_edge(_map, at, 0, &"crossing", 3)
	assert_eq(_step(at, 0, false), 2, "class 3 with a bridge is walked")
	PathFixture.set_edge(_map, at, 0, &"crossing", 5)
	PathFixture.set_edge(_map, at, 0, &"river", 2)
	assert_eq(_step(at, 0, false), StepCosts.WADE, "a pass mark on a river is no crossing (decision, L3)")


func test_the_first_rule_that_applies_ends_it() -> void:
	# A river wall beside snow in winter: the wall decides before the snow does.
	_set_cover(Vector2i(4, 3), 5, 0)
	PathFixture.set_edge(_map, Vector2i(3, 3), 0, &"river", 3)
	assert_eq(_step(Vector2i(3, 3), 0, true), StepCosts.BLOCKED, "a wall, not 12")
	# A crest with no pass beats a road.
	_set_cover(Vector2i(4, 3), 0)
	PathFixture.set_edge(_map, Vector2i(3, 3), 0, &"river", 0)
	PathFixture.set_edge(_map, Vector2i(3, 3), 0, &"crest", 1)
	PathFixture.set_edge(_map, Vector2i(3, 3), 0, &"road", 3)
	assert_eq(_step(Vector2i(3, 3), 0, false), StepCosts.BLOCKED, "a crest, not a highway")


func test_planted_defs_change_the_rules() -> void:
	PathFixture.set_edge(_map, Vector2i(3, 3), 0, &"river", 2)
	_defs.river_wade_class = 1
	assert_eq(_step(Vector2i(3, 3), 0, false), StepCosts.WADE, "a class 2 river wades")
	_defs.river_wall_class = 2
	assert_eq(_step(Vector2i(3, 3), 0, false), StepCosts.BLOCKED, "the wall now starts at class 2")
	_defs = PathFixture.defs_copy()
	_map = PathFixture.open_map()
	_set_cover(Vector2i(4, 3), 5, 0)
	_defs.winter_snow_percent = 300
	assert_eq(_step(Vector2i(3, 3), 0, true), 18, "snow winter at 300 %")
	_defs = PathFixture.defs_copy()
	_map.climate[_map.index_of(Vector2i(4, 3))] = 1
	PathFixture.set_edge(_map, Vector2i(3, 3), 0, &"pass_edge", 1)
	_defs.pass_closing_climate = 1
	assert_eq(_step(Vector2i(3, 3), 0, true), StepCosts.CLOSED, "a pass closes beside climate 1 when it is set")


func test_the_table_fills_a_hex_on_first_use_and_equals_compute() -> void:
	var steps := StepCosts.of(_map, _defs)
	assert_eq(steps.filled(), 0)
	var i := _map.index_of(Vector2i(3, 3))
	assert_eq(steps.cost(i, 0, false), StepCosts.compute(_map, _defs, i, 0, false))
	assert_eq(steps.filled(), 1, "one hex filled by one ask")
	for j: int in _map.hex_count():
		for d: int in 6:
			for w: bool in [false, true]:
				assert_eq(steps.cost(j, d, w), StepCosts.compute(_map, _defs, j, d, w), "hex %d dir %d" % [j, d])
	assert_eq(steps.filled(), _map.hex_count())


func test_supply_cost_swaps_wade_and_closes_passes() -> void:
	var steps := StepCosts.of(_map, _defs)
	PathFixture.set_edge(_map, Vector2i(3, 3), 0, &"river", 2)
	assert_eq(steps.cost(_map.index_of(Vector2i(3, 3)), 0, false), StepCosts.WADE)
	assert_eq(steps.supply_cost(_map.index_of(Vector2i(3, 3)), 0, false), 3, "WADE is supply_wade_cost")
	PathFixture.set_edge(_map, Vector2i(5, 3), 0, &"pass_edge", 1)
	PathFixture.set_edge(_map, Vector2i(5, 3), 0, &"crest", 1)
	_map.climate[_map.index_of(Vector2i(6, 3))] = 0
	var closed := StepCosts.of(_map, _defs)
	assert_eq(closed.supply_cost(_map.index_of(Vector2i(5, 3)), 0, true), StepCosts.BLOCKED, "CLOSED is blocked for supply")


func test_the_memo_gives_one_table_per_map_and_defs() -> void:
	var a := StepCosts.of(_map, _defs)
	assert_same(StepCosts.of(_map, _defs), a, "the same pair gives the same table")
	var other := PathFixture.defs_copy()
	assert_not_same(StepCosts.of(_map, other), a, "another defs copy gives its own table")
	StepCosts.clear_all()
	assert_not_same(StepCosts.of(_map, _defs), a, "cleared, the table is made again")


func test_north_italy_worked_steps_of_4_3() -> void:
	var map := EconomyFixture.map()
	var defs := EconomyFixture.committed()
	var steps := StepCosts.of(map, defs)
	var turin := Vector2i(5, 9)
	var susa := Vector2i(4, 9)
	var saddle := Vector2i(3, 9)
	assert_eq(steps.cost(map.index_of(turin), 0, false), 2, "Turin to Vercelli, over the bridge")
	assert_eq(steps.cost(map.index_of(turin), 3, false), 2, "Turin to Susa")
	assert_eq(steps.cost(map.index_of(susa), 3, false), 9, "Susa to the Mont Cenis saddle: snow 6 + high peaks 3")
	assert_eq(steps.cost(map.index_of(susa), 3, true), 18, "the same step in winter")
	assert_eq(steps.cost(map.index_of(saddle), 2, false), 5, "the saddle to (3, 8) across the pass on a track")
	assert_eq(steps.cost(map.index_of(saddle), 2, true), StepCosts.CLOSED, "the pass is shut in winter")
	assert_eq(steps.cost(map.index_of(turin), 3, true), 2, "Turin to Susa in winter (frost, no doubling)")


func test_north_italy_lazy_fill_equals_compute_everywhere() -> void:
	var map := EconomyFixture.map()
	var defs := EconomyFixture.committed()
	var steps := StepCosts.of(map, defs)
	for j: int in map.hex_count():
		for d: int in 6:
			for w: bool in [false, true]:
				assert_eq(steps.cost(j, d, w), StepCosts.compute(map, defs, j, d, w))
	assert_eq(steps.filled(), map.hex_count())


func test_neighbour_index_equals_hexgrid_on_every_hex() -> void:
	var map := EconomyFixture.map()
	for i: int in map.hex_count():
		for d: int in 6:
			var expected := map.index_of(map.neighbour(map.hex_of(i), d))
			assert_eq(StepCosts.neighbour_index(map.cols, map.rows, i, d), expected, "hex %d dir %d" % [i, d])
	for i: int in _map.hex_count():
		for d: int in 6:
			var expected := _map.index_of(_map.neighbour(_map.hex_of(i), d))
			assert_eq(StepCosts.neighbour_index(_map.cols, _map.rows, i, d), expected, "fixture hex %d dir %d" % [i, d])
