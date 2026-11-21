## Times the path searches on the made-up Europe (docs/architecture/m6-build-spec.md sections 5.0 R7 and 10; task L3): the step
## fill, 200 reachable routes of 1 to 4 seasons, 20 unreachable goals across a wall (the components refuse them at once), 20
## routes planned twice (winter and summer, D20), and 20 cost fields. The map is walled down one column (a river of class 3),
## so the unreachable goals are real. The allowed mask is every land hex (no borders: the search cost is what is measured).
## Headless, no window, no GUT. A probe: it prints a table and fails on nothing.
##
##   godot --headless --path godot -s res://tools/probes/probe_paths.gd
extends SceneTree

const GAME_DEFS := "res://data/defs/game_defs.tres"
const SEED := 1480
const COLS := 494
const ROWS := 247
const WALL_COLUMN := 247
const MP := 12
const SEASONS_MAX := 4
const ROUTES := 200
const UNREACHABLE := 20
const PLANS := 20
const FIELDS := 20
const NEAR := 6


func _initialize() -> void:
	quit(_run())


func _ms(from_usec: int) -> float:
	return float(Time.get_ticks_usec() - from_usec) / 1000.0


func _mean(values: Array[float]) -> float:
	var total := 0.0
	for v: float in values:
		total += v
	return total / maxf(float(values.size()), 1.0)


func _worst(values: Array[float]) -> float:
	var worst := 0.0
	for v: float in values:
		worst = maxf(worst, v)
	return worst


func _run() -> int:
	var map := FakeMap.build(COLS, ROWS, SEED)
	var defs := ResourceLoader.load(GAME_DEFS, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	if defs == null:
		printerr("probe_paths: cannot load %s" % GAME_DEFS)
		return 1
	for r: int in ROWS:
		var e := map.edge_index(Vector2i(WALL_COLUMN, r), 0)
		if e >= 0:
			map.river[e] = 3
			map.crossing[e] = 0
	var allowed := PackedByteArray()
	allowed.resize(map.hex_count())
	var land: Array[int] = []
	for i: int in map.hex_count():
		allowed[i] = map.land[i]
		if map.land[i] == 1:
			land.append(i)
	var rng := Rng.new()
	rng.seed_with(SEED)

	StepCosts.clear_all()
	var steps := StepCosts.of(map, defs)
	var fill_start := Time.get_ticks_usec()
	for i: int in land:
		for d: int in 6:
			steps.cost(i, d, false)
			steps.cost(i, d, true)
	var fill_us := float(Time.get_ticks_usec() - fill_start) / float(maxi(land.size(), 1))
	var comps := PathSearch.components(map, steps, allowed)

	var routes: Array[float] = []
	var found := 0
	var tries := 0
	while found < ROUTES and tries < ROUTES * 20:
		tries += 1
		var from := _random_land(map, land, rng)
		var goal := _near_land(map, from, allowed, comps, rng)
		if goal < 0:
			continue
		var seasons := rng.randi_range(1, SEASONS_MAX)
		var t := Time.get_ticks_usec()
		var r := PathSearch.route(map, steps, allowed, map.hex_of(from), map.hex_of(goal), false, seasons * MP,
			defs.wade_plan_cost, comps)
		routes.append(_ms(t))
		if bool(r["ok"]):
			found += 1

	var unreachable: Array[float] = []
	var west := _random_in(map, land, rng, true)
	for _n: int in UNREACHABLE:
		var goal := _random_in(map, land, rng, false)
		var t := Time.get_ticks_usec()
		PathSearch.route(map, steps, allowed, map.hex_of(west), map.hex_of(goal), false, SEASONS_MAX * MP,
			defs.wade_plan_cost, comps)
		unreachable.append(_ms(t))

	var plans: Array[float] = []
	for _n: int in PLANS:
		var from := _random_land(map, land, rng)
		var goal := _near_land(map, from, allowed, comps, rng)
		if goal < 0:
			continue
		var t := Time.get_ticks_usec()
		PathSearch.route(map, steps, allowed, map.hex_of(from), map.hex_of(goal), true, SEASONS_MAX * MP,
			defs.wade_plan_cost, comps)
		PathSearch.route(map, steps, allowed, map.hex_of(from), map.hex_of(goal), false, SEASONS_MAX * MP,
			defs.wade_plan_cost, comps)
		plans.append(_ms(t))

	var fields: Array[float] = []
	for _n: int in FIELDS:
		var goal := _random_land(map, land, rng)
		var t := Time.get_ticks_usec()
		PathSearch.cost_field(map, steps, allowed, map.hex_of(goal), false)
		fields.append(_ms(t))

	print("probe_paths: %d x %d hexes, %d land, wall at column %d, filled %d" % [COLS, ROWS, land.size(), WALL_COLUMN,
		steps.filled()])
	print("  step_fill_us      mean %.1f  (both seasons, all land hexes; limit 40)" % fill_us)
	print("  route_ms          mean %.2f  worst %.2f  (%d reachable of %d tried, 1 to 4 seasons; limit 2 mean, 8 worst)" % [
		_mean(routes), _worst(routes), found, tries])
	print("  unreachable_ms    mean %.3f  worst %.3f  (%d goals across the wall)" % [
		_mean(unreachable), _worst(unreachable), unreachable.size()])
	print("  plan_pair_ms      mean %.2f  worst %.2f  (%d winter + summer pairs)" % [_mean(plans), _worst(plans), plans.size()])
	print("  cost_field_ms     mean %.2f  worst %.2f  (%d goals; limit 120 worst)" % [_mean(fields), _worst(fields), fields.size()])
	return 0


func _random_land(map: MapData, land: Array[int], rng: Rng) -> int:
	return land[rng.randi_range(0, land.size() - 1)]


## A land hex of the same component as `from`, within NEAR hexes of it on the grid (-1 when none was found).
func _near_land(map: MapData, from: int, allowed: PackedByteArray, comps: PackedInt32Array, rng: Rng) -> int:
	var h := map.hex_of(from)
	for _k: int in 8:
		var g := Vector2i(h.x + rng.randi_range(-NEAR, NEAR), h.y + rng.randi_range(-NEAR, NEAR))
		var j := map.index_of(g)
		if j >= 0 and allowed[j] == 1 and comps[j] == comps[from] and j != from:
			return j
	return -1


## A random land hex on the west (`west`) or the east of the wall.
func _random_in(map: MapData, land: Array[int], rng: Rng, west: bool) -> int:
	while true:
		var i := _random_land(map, land, rng)
		var on_west := map.hex_of(i).x < WALL_COLUMN
		if on_west == west:
			return i
	return -1
