## Times the M4 season on the made-up Europe (docs/architecture/m4-build-spec.md 8 and 10): the production and income
## phases, the whole season and the cold DistrictCache, on the world of perf_core.gd (FakeMap 494 x 247, 60 countries, the
## real families, seed 1480). Headless, no window, no GUT. A probe: it prints a table and fails on nothing (the budgets
## are perf_core's: production 60 ms, season 150 ms, cache build 400 ms).
##
##   godot --headless --path godot -s res://tools/perf_season.gd -- [--seasons=8]
extends SceneTree

const GAME_DEFS := "res://data/defs/game_defs.tres"
const COLS := 494
const ROWS := 247
const SEED := 1480
const COUNTRIES := 60

var _seasons := 8


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seasons="):
			_seasons = maxi(int(arg.substr(10)), 1)
	quit(_run())


func _ms(from_usec: int) -> float:
	return float(Time.get_ticks_usec() - from_usec) / 1000.0


func _median(values: Array[float]) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[int(sorted.size() * 0.5)]


func _run() -> int:
	var map := FakeMap.build(COLS, ROWS, SEED)
	var built := FakeScenario.build(map, COUNTRIES, SEED)
	var defs := built["defs"] as GameDefs
	var real := ResourceLoader.load(GAME_DEFS, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	if real == null:
		printerr("perf_season: cannot load %s" % GAME_DEFS)
		return 1
	defs.families = real.families
	defs.goods = real.goods
	var t := Time.get_ticks_usec()
	var game := Game.new_scenario(map, defs, built["scenario"] as ScenarioDef, SEED)
	var setup_ms := _ms(t)
	var land := 0
	for i: int in map.hex_count():
		land += map.land[i]
	game.act("choose_country", {"tag": game.countries[0].tag})
	print("fake Europe %d x %d: %d land hexes, %d countries; new_scenario (search, purses, stores) %.0f ms" % [
		COLS, ROWS, land, game.countries.size(), setup_ms])

	# Cold: the first production fills the DistrictCache; clear it to time that on its own.
	game.districts.clear()
	t = Time.get_ticks_usec()
	for i: int in map.hex_count():
		if map.land[i] == 1:
			game.districts.base_of(game, i)
	var cache_ms := _ms(t)
	print("DistrictCache filled for %d hexes from cold: %.0f ms" % [game.districts.size(), cache_ms])

	var production: Array[float] = []
	var income: Array[float] = []
	var rest: Array[float] = []
	var season: Array[float] = []
	for n: int in _seasons:
		var whole := Time.get_ticks_usec()
		Season.begin(game)
		t = Time.get_ticks_usec()
		Season.run_phase(game, &"production")
		production.append(_ms(t))
		t = Time.get_ticks_usec()
		Season.run_phase(game, &"income")
		income.append(_ms(t))
		t = Time.get_ticks_usec()
		for phase: StringName in [&"works", &"stats", &"calendar"]:
			Season.run_phase(game, phase)
		rest.append(_ms(t))
		Season.finish(game)
		season.append(_ms(whole))
	print("per season over %d seasons (warm cache)      median    worst" % _seasons)
	print("  production                                 %7.1f  %7.1f   (budget 60)" % [_median(production), production.max()])
	print("  income                                     %7.1f  %7.1f   (budget 20)" % [_median(income), income.max()])
	print("  works, stats, calendar                     %7.1f  %7.1f" % [_median(rest), rest.max()])
	print("  the whole season                           %7.1f  %7.1f   (budget 150)" % [_median(season), season.max()])
	var tags := 0
	var c0 := game.countries[0]
	var view := StateView.of(game.state)
	t = Time.get_ticks_usec()
	for c: Country in game.countries:
		EconomySeason.made_of(game, view, c.tag, 0, game.weather, c.tax)
		tags += 1
	print("made_of for %d countries, warm: %.1f ms (largest country %s: %d districts)" % [
		tags, _ms(t), c0.tag, Territory.districts(game, c0.id).size()])
	return 0
