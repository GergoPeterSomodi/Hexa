## Times the movement phase on the made-up Europe (docs/architecture/m6-build-spec.md sections 8 and 10; task L6): about ten
## armies a country (600 in all, 1 to 8 pikemen each) ordered by march to a hex of their own land 1 to 6 hexes away (kept only
## when the plan walks in 1 to 4 seasons), walked for SEASONS seasons. Re-orders on arrival run between seasons, outside the
## timed phase. Prints the movement phase's mean and worst time, the sight refresh inside it, the walks and the arrivals.
## Headless, no window, no GUT. A probe: it prints a table and fails on nothing.
##
##   godot --headless --path godot -s res://tools/probes/probe_movement.gd
extends SceneTree

const GAME_DEFS := "res://data/defs/game_defs.tres"
const SEASONS := 8
const ARMIES_PER_COUNTRY := 10
const MAX_MEN_COMPANIES := 8
const SEED := 1480
const NEAR := 6
const TRIES := 60
const SEASONS_MAX := 4
## The movement numbers copied from the committed definitions (the made-up Europe's own come from FakeScenario).
const MOVEMENT_FIELDS: Array[String] = ["units", "terrains", "relief_move_add", "highway_cap", "road_cap", "track_divisor",
	"winter_snow_percent", "pass_closing_climate", "stream_cost", "river_cost", "ford_cost", "ferry_cost",
	"river_wade_class", "river_wall_class", "wade_plan_cost", "supply_reach", "supply_wade_cost", "depot_min_level",
	"army_food_milli", "forage_percent", "forage_loss_permille", "starve_permille", "stack_limit", "march_seasons_max",
	"wait_ratio_percent", "wait_extra_seasons", "land_sight"]


func _initialize() -> void:
	quit(_run())


func _ms(from_usec: int) -> float:
	return float(Time.get_ticks_usec() - from_usec) / 1000.0


func _run() -> int:
	var armies_per := _arg("armies", ARMIES_PER_COUNTRY)
	var seasons := _arg("seasons", SEASONS)
	var game := PerfFixture.europe_game(0)
	if game == null:
		printerr("probe_movement: cannot build the made-up Europe")
		return 1
	var real := ResourceLoader.load(GAME_DEFS, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	if real == null:
		printerr("probe_movement: cannot load %s" % GAME_DEFS)
		return 1
	for field: String in MOVEMENT_FIELDS:
		game.defs.set(field, real.get(field))
	var rng := Rng.new()
	rng.seed_with(SEED)
	var armies := _raise(game, rng, armies_per)
	var orders := 0
	for a: Army in armies:
		if _order(game, a, rng):
			orders += 1
	var season_ms: Array[float] = []
	var refresh_ms: Array[float] = []
	var parts: Dictionary = {"legs": 0.0, "ticks": 0.0, "room": 0.0, "apply": 0.0}
	var moved_total := 0
	var arrived_total := 0
	for _s: int in seasons:
		var t := Time.get_ticks_usec()
		var split := _timed_season(game)
		season_ms.append(_ms(t))
		for key: String in split:
			parts[key] = float(parts[key]) + float(split[key]) / float(seasons)
		var r := Time.get_ticks_usec()
		Sight.refresh(game)
		refresh_ms.append(_ms(r))
		for a: Army in game.armies:
			if a.moved_from != Movement.NO_HEX:
				moved_total += 1
		arrived_total += _rearm(game, rng, armies)
		game.turn += 1
	print("probe_movement: %d countries, %d armies, %d marches ordered, %d seasons" % [
		game.countries.size(), armies.size(), orders, seasons])
	print("  movement_ms      mean %.2f  worst %.2f  (limit 25 mean-of-600)" % [_mean(season_ms), _worst(season_ms)])
	print("  refresh_ms       mean %.2f  worst %.2f  (inside the phase's time, the sight's army part)" % [
		_mean(refresh_ms), _worst(refresh_ms)])
	print("  split_ms         legs %.2f  ticks %.2f  room %.2f  apply %.2f  (mean a season)" % [
		float(parts.legs), float(parts.ticks), float(parts.room), float(parts.apply)])
	print("  walks            %.1f a season  (armies that moved)" % (float(moved_total) / seasons))
	print("  arrivals         %d  (re-ordered between seasons, outside the timed phase)" % arrived_total)
	return 0


## An integer from the user arguments (--armies=N, --seasons=N), or the default.
func _arg(name: String, default: int) -> int:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return int(a.substr(name.length() + 3))
	return default


## MovementPhase.season, step by step, with the time of each step in ms (the same calls, in the same order).
func _timed_season(game: Game) -> Dictionary:
	var out := {"legs": 0.0, "ticks": 0.0, "room": 0.0, "apply": 0.0}
	Armies.clear_moved(game)
	var steps := StepCosts.of(game.map, game.defs)
	var winter := Movement.winter_now(game)
	var occ := MovementPhase._occupancy(game)
	var walks: Array = []
	var by_id: Dictionary = {}
	var t := Time.get_ticks_usec()
	for army: Army in game.armies:
		if army.order != Army.ORDER_MARCH or army.mustering(game.turn):
			continue
		var w: MovementPhase.Walk = MovementPhase._leg(game, steps, army, winter)
		walks.append(w)
		by_id[army.id] = w
	out.legs = _ms(t)
	t = Time.get_ticks_usec()
	MovementPhase._ticks(game, walks, occ)
	out.ticks = _ms(t)
	t = Time.get_ticks_usec()
	MovementPhase._room(game, walks, by_id)
	out.room = _ms(t)
	t = Time.get_ticks_usec()
	MovementPhase._apply(game, walks, {})
	out.apply = _ms(t)
	return out


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


## Ten armies a country of seeded companies on random land of its own, mustering in an earlier season.
func _raise(game: Game, rng: Rng, armies_per: int) -> Array[Army]:
	var out: Array[Army] = []
	for c: Country in game.countries:
		var land := Territory.districts(game, c.id)
		if land.is_empty() or not c.alive:
			continue
		for _k: int in armies_per:
			var hex := game.map.hex_of(land[rng.randi_range(0, land.size() - 1)])
			var a := Armies.create(game, c.tag, hex, "Army of probe")
			Armies.add_units(game, a, 0, rng.randi_range(1, MAX_MEN_COMPANIES), game.turn - 1, hex, 0, {})
			out.append(a)
	return out


## A march to a hex of the army's own land near it, kept when its plan walks in 1 to SEASONS_MAX seasons.
func _order(game: Game, a: Army, rng: Rng) -> bool:
	var land := Territory.districts(game, Countries.by_tag(game, a.tag).id)
	for _k: int in TRIES:
		var goal := game.map.hex_of(land[rng.randi_range(0, land.size() - 1)])
		if ImproveRules.hex_distance(goal, a.hex) > NEAR or goal == a.hex:
			continue
		var res := Movement.plan(game, a, goal)
		if not bool(res.ok):
			continue
		var seasons := int(Movement.walk_plan(game, a, res.hexes, game.turn).seasons)
		if seasons < 1 or seasons > SEASONS_MAX:
			continue
		return bool(Movement.march(game, {"army": a.id, "goal": goal, "tag": a.tag}).ok)
	return false


## Between seasons: an army that arrived holds; it is given a new march (the rig, outside the timed phase). Returns arrivals.
func _rearm(game: Game, rng: Rng, armies: Array[Army]) -> int:
	var arrived := 0
	for a: Army in armies:
		if Armies.by_id(game, a.id) == null:
			continue
		if a.order == Army.ORDER_HOLD:
			arrived += 1
			_order(game, a, rng)
	return arrived
