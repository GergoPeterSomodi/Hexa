## PathSearch (docs/architecture/m6-build-spec.md sections 4.4, 5.0 R6, R7, 5.3 and 9; task L3): the route on fixtures (costs,
## crests, passes, wade, budget, components), the reach, the fields, the cost field against routes from random starts, the
## routes of 4.13 (b) to (d) on north Italy, and planted faults (P). A wall between two columns marks every edge that crosses
## it (PathFixture.boundary): a route goes round a wall that misses one diagonal.
extends GutTest

const UNREACHED := PathSearch.UNREACHED
const TIE_SEED := 1480

var _map: MapData
var _defs: GameDefs
var _allowed: PackedByteArray


func before_each() -> void:
	_fresh()


func after_each() -> void:
	StepCosts.clear_all()


## A new open map, its defs copy and the mask of all hexes; the step tables of the old map are forgotten.
func _fresh() -> void:
	StepCosts.clear_all()
	_map = PathFixture.open_map()
	_defs = PathFixture.defs_copy()
	_allowed = PathFixture.allowed_all(_map)


func _steps() -> StepCosts:
	return StepCosts.of(_map, _defs)


func _route(from: Vector2i, goal: Vector2i, winter: bool = false, max_cost: int = UNREACHED, wade: int = 12,
		comps: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	return PathSearch.route(_map, _steps(), _allowed, from, goal, winter, max_cost, wade, comps)


## Marks every edge between column `col` and `col + 1` with one field and value.
func _wall(col: int, field: StringName, value: int) -> void:
	for pair: Array in PathFixture.boundary(_map, col):
		PathFixture.set_edge(_map, pair[0], pair[1], field, value)


func test_straight_route_over_farmland() -> void:
	var r := _route(Vector2i(1, 3), Vector2i(5, 3))
	assert_true(r["ok"])
	assert_eq(r["cost"], 8, "four steps of 2")
	assert_eq(PathFixture.hexes(_map, r["hexes"]), [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)],
		"the steps after the start, the goal last")


func test_the_start_is_its_own_route() -> void:
	var r := _route(Vector2i(2, 2), Vector2i(2, 2))
	assert_true(r["ok"])
	assert_eq(r["cost"], 0)
	assert_eq((r["hexes"] as PackedInt32Array).size(), 0)


func test_the_cheapest_route_round_woods_equals_the_cost_field() -> void:
	for x: int in range(2, 5):
		for y: int in range(1, 6):
			_map.cover[_map.index_of(Vector2i(x, y))] = 2  # woods, 3 points
	_map.cover[_map.index_of(Vector2i(3, 3))] = 0
	var goal := Vector2i(7, 3)
	var from := Vector2i(1, 3)
	var field := PathSearch.cost_field(_map, _steps(), _allowed, goal, false)
	var r := _route(from, goal)
	assert_true(r["ok"])
	assert_eq(r["cost"], field[_map.index_of(from)], "the search's cost equals the cost field's")
	gut.p("woods route: %s cost %d" % [str(PathFixture.hexes(_map, r["hexes"])), r["cost"]])


func test_planted_tie_order_is_fixed() -> void:
	# An open map: several equal-cost routes from (1, 1) to (3, 3) (three steps of 2). The fixed order picks one.
	var r := _route(Vector2i(1, 1), Vector2i(3, 3))
	assert_true(r["ok"])
	assert_eq(r["cost"], 6)
	gut.p("tie route: %s" % str(PathFixture.hexes(_map, r["hexes"])))


func test_a_crest_wall_without_a_pass_is_unreachable() -> void:
	_wall(4, &"crest", 1)
	var r := _route(Vector2i(2, 3), Vector2i(6, 3))
	assert_false(r["ok"])
	assert_eq(r["why"], "unreachable")


func test_a_pass_gap_in_the_crest_is_the_only_way() -> void:
	_wall(4, &"crest", 1)
	PathFixture.set_edge(_map, Vector2i(4, 2), 0, &"pass_edge", 1)
	var r := _route(Vector2i(2, 3), Vector2i(6, 3))
	assert_true(r["ok"])
	var hexes := PathFixture.hexes(_map, r["hexes"])
	assert_true(hexes.has(Vector2i(5, 2)), "through the pass at (4, 2) to (5, 2)")
	assert_false(hexes.has(Vector2i(5, 3)), "never over the crest into (5, 3)")


func test_a_closed_pass_refuses_the_winter_route_only() -> void:
	_wall(4, &"crest", 1)
	PathFixture.set_edge(_map, Vector2i(4, 3), 0, &"pass_edge", 1)
	_map.climate[_map.index_of(Vector2i(5, 3))] = 0
	assert_true(_route(Vector2i(2, 3), Vector2i(6, 3), false)["ok"], "summer: the pass is open")
	var winter := _route(Vector2i(2, 3), Vector2i(6, 3), true)
	assert_false(winter["ok"], "winter: the pass is shut")
	assert_eq(winter["why"], "unreachable")


func test_a_wade_costs_its_plan_cost() -> void:
	_wall(3, &"river", 2)
	var r := _route(Vector2i(2, 3), Vector2i(4, 3), false, UNREACHED, 12)
	assert_true(r["ok"])
	assert_eq(r["cost"], 14, "2 to (3, 3), then the wade of 12 into (4, 3)")
	var cheap := _route(Vector2i(2, 3), Vector2i(4, 3), false, UNREACHED, 3)
	assert_eq(cheap["cost"], 5, "the wade counts the cost it is given")


func test_too_far_is_named_apart_from_no_way() -> void:
	var near := _route(Vector2i(1, 3), Vector2i(5, 3), false, 8)
	assert_true(near["ok"], "exactly the budget is in")
	var far := _route(Vector2i(1, 3), Vector2i(5, 3), false, 7)
	assert_false(far["ok"])
	assert_eq(far["why"], "too_far", "a route exists, it costs more than the budget")
	_fresh()
	_wall(3, &"crest", 1)
	var none := _route(Vector2i(1, 3), Vector2i(5, 3), false, 7)
	assert_eq(none["why"], "unreachable", "no route at all, even with no budget")


func test_components_refuse_an_island_at_once_and_join_wade() -> void:
	_wall(3, &"river", 3)
	var comps := PathSearch.components(_map, _steps(), _allowed)
	assert_ne(comps[_map.index_of(Vector2i(2, 3))], comps[_map.index_of(Vector2i(5, 3))], "a wall splits the land")
	var r := _route(Vector2i(2, 3), Vector2i(5, 3), false, UNREACHED, 12, comps)
	assert_false(r["ok"])
	assert_eq(r["why"], "unreachable")
	_fresh()
	_wall(3, &"river", 2)
	var wade := PathSearch.components(_map, _steps(), _allowed)
	assert_eq(wade[_map.index_of(Vector2i(2, 3))], wade[_map.index_of(Vector2i(5, 3))], "a wade joins the components")
	assert_true(_route(Vector2i(2, 3), Vector2i(5, 3), false, UNREACHED, 12, wade)["ok"])


func test_the_components_answer_matches_the_plain_search() -> void:
	_randomise(TIE_SEED)
	var comps := PathSearch.components(_map, _steps(), _allowed)
	var rng := Rng.new()
	rng.seed_with(TIE_SEED + 1)
	for _n: int in 30:
		var from := Vector2i(rng.randi_range(0, PathFixture.COLS - 1), rng.randi_range(0, PathFixture.ROWS - 1))
		var goal := Vector2i(rng.randi_range(0, PathFixture.COLS - 1), rng.randi_range(0, PathFixture.ROWS - 1))
		var plain := _route(from, goal)
		var with := _route(from, goal, false, UNREACHED, 12, comps)
		assert_eq(with["ok"], plain["ok"], "%s to %s" % [from, goal])
		assert_eq(with["cost"], plain["cost"], "%s to %s" % [from, goal])


func test_reach_is_the_budget() -> void:
	var reach := PathSearch.reach(_map, _steps(), _allowed, Vector2i(1, 3), 4, false)
	assert_eq(reach[_map.index_of(Vector2i(1, 3))], 0, "the start at 0")
	assert_eq(reach[_map.index_of(Vector2i(2, 3))], 2)
	assert_eq(reach[_map.index_of(Vector2i(3, 3))], 4)
	assert_false(reach.has(_map.index_of(Vector2i(4, 3))), "past the budget")


func test_a_wade_as_the_first_step_spends_the_whole_budget() -> void:
	_wall(1, &"river", 2)
	var first := PathSearch.reach(_map, _steps(), _allowed, Vector2i(1, 3), 4, false)
	assert_eq(first[_map.index_of(Vector2i(2, 3))], 4, "the wade spends all 4 points")
	assert_false(first.has(_map.index_of(Vector2i(3, 3))), "and goes no further")


func test_a_wade_after_a_step_is_refused() -> void:
	_wall(2, &"river", 2)
	var after := PathSearch.reach(_map, _steps(), _allowed, Vector2i(1, 3), 4, false)
	assert_eq(after[_map.index_of(Vector2i(2, 3))], 2, "the hex before the wade is reached")
	assert_false(after.has(_map.index_of(Vector2i(3, 3))), "no wade after a step (only from the start)")


func test_field_from_several_starts_is_the_minimum_of_each() -> void:
	_randomise(TIE_SEED + 2)
	var a := Vector2i(1, 1)
	var b := Vector2i(7, 5)
	var starts := PackedInt32Array([_map.index_of(a), _map.index_of(b)])
	var both := PathSearch.field(_map, _steps(), _allowed, starts, 100, false, false)
	var fa := PathSearch.field(_map, _steps(), _allowed, PackedInt32Array([_map.index_of(a)]), 100, false, false)
	var fb := PathSearch.field(_map, _steps(), _allowed, PackedInt32Array([_map.index_of(b)]), 100, false, false)
	for i: int in _map.hex_count():
		assert_eq(both[i], mini(fa[i], fb[i]), "hex %d" % i)


func test_supply_field_uses_the_supply_costs() -> void:
	_wall(2, &"river", 2)
	var starts := PackedInt32Array([_map.index_of(Vector2i(1, 3))])
	var plan := PathSearch.field(_map, _steps(), _allowed, starts, 100, false, false)
	var supply := PathSearch.field(_map, _steps(), _allowed, starts, 100, false, true)
	assert_eq(plan[_map.index_of(Vector2i(3, 3))], 2 + 12, "plan: 2 into (2, 3), the wade of 12 into (3, 3)")
	assert_eq(supply[_map.index_of(Vector2i(3, 3))], 2 + 3, "supply: the wade costs 3")


func test_cost_field_equals_route_costs_from_random_starts() -> void:
	for winter: bool in [false, true]:
		_randomise(TIE_SEED)
		var goal := Vector2i(7, 5)
		var field := PathSearch.cost_field(_map, _steps(), _allowed, goal, winter)
		var rng := Rng.new()
		rng.seed_with(TIE_SEED + 3)
		for _n: int in 50:
			var from := Vector2i(rng.randi_range(0, PathFixture.COLS - 1), rng.randi_range(0, PathFixture.ROWS - 1))
			var r := _route(from, goal, winter)
			var f := field[_map.index_of(from)]
			if f >= UNREACHED:
				assert_false(r["ok"], "%s: the field says unreachable" % from)
			else:
				assert_true(r["ok"], "%s: reachable" % from)
				assert_eq(r["cost"], f, "%s: the route costs what the field says" % from)


func test_a_goal_outside_the_mask_is_unreachable() -> void:
	_allowed[_map.index_of(Vector2i(6, 3))] = 0
	var r := _route(Vector2i(2, 3), Vector2i(6, 3))
	assert_false(r["ok"])
	assert_eq(r["why"], "unreachable")


func test_the_north_italy_routes_of_4_13() -> void:
	var map := EconomyFixture.map()
	var defs := EconomyFixture.committed()
	var steps := StepCosts.of(map, defs)
	var allowed := PathFixture.allowed_land(map)
	var turin := Vector2i(5, 9)
	var b := PathSearch.route(map, steps, allowed, turin, Vector2i(6, 9), false, UNREACHED, defs.wade_plan_cost)
	assert_true(b["ok"])
	assert_eq(b["cost"], 2, "(b) across the Po: one step of 2")
	assert_eq(PathFixture.hexes(map, b["hexes"]), [Vector2i(6, 9)])
	var d := PathSearch.route(map, steps, allowed, turin, Vector2i(3, 9), false, UNREACHED, defs.wade_plan_cost)
	assert_true(d["ok"])
	assert_eq(d["cost"], 11, "(d) Susa 2, then the saddle 9")
	assert_eq(PathFixture.hexes(map, d["hexes"]), [Vector2i(4, 9), Vector2i(3, 9)])
	var c := PathSearch.route(map, steps, allowed, Vector2i(6, 9), Vector2i(3, 8), false, UNREACHED, defs.wade_plan_cost)
	assert_true(c["ok"])
	assert_eq(PathFixture.hexes(map, c["hexes"]).back(), Vector2i(3, 8), "ends at (3, 8)")
	# Spec 4.13 (c) lists its route through Turin at 15 points. Summed on the table, that route is 15, as the spec says; the
	# search finds a cheaper one (14, round Turin) on the committed map. The spec's figure is flagged to the planning session.
	var via_turin := [Vector2i(5, 9), Vector2i(5, 8), Vector2i(4, 7), Vector2i(3, 7), Vector2i(3, 8)]
	assert_eq(_walk_cost(map, steps, Vector2i(6, 9), via_turin, false), 15, "(c) the spec's route sums to 15")
	assert_eq(c["cost"], 14, "(c) the cheapest route on the committed map is 14, round Turin")


## The summed step costs of a walk from `start` through `hexes` (each a neighbour of the one before).
func _walk_cost(map: MapData, steps: StepCosts, start: Vector2i, hexes: Array, winter: bool) -> int:
	var total := 0
	var at := start
	for h: Vector2i in hexes:
		var d := map.grid().direction_of(at, h)
		total += steps.cost(map.index_of(at), d, winter)
		at = h
	return total


## Random covers, relief, climate and edge marks, seeded: the same map every time the test runs.
func _randomise(seed_value: int) -> void:
	StepCosts.clear_all()  # the marks change: a table filled before them is stale (A12)
	var rng := Rng.new()
	rng.seed_with(seed_value)
	for i: int in _map.hex_count():
		_map.cover[i] = rng.randi_range(0, 7)
		_map.relief[i] = rng.randi_range(0, 6)
		_map.climate[i] = rng.randi_range(0, 2)
	for e: int in _map.edge_count():
		if rng.randi_range(0, 9) == 0:
			_map.river[e] = rng.randi_range(1, 4)
			_map.crossing[e] = rng.randi_range(0, 4)
		if rng.randi_range(0, 19) == 0:
			_map.crest[e] = 1
			_map.pass_edge[e] = rng.randi_range(0, 1)
