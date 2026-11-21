## Times the people rules on the made-up Europe (docs/architecture/m5-build-spec.md 5.0 R2, 8 and 10; task P4): the production
## phase with the people read live (budget 70 ms), the people phase (People.season, budget 30 ms), the walk People.active
## and the live part of the season profile on their own, over seasons played with the people phase between works and stats,
## as Season.PHASES runs it. Headless, no window, no GUT. A probe: it prints a table and fails on nothing.
##
##   godot --headless --path godot -s res://tools/probes/probe_people_perf.gd -- [--seasons=8] [--cols=494 --rows=247 --countries=60]
## A smaller world (say --cols=247 --rows=124 --countries=15) builds in a minute and scales close to linearly.
extends SceneTree

const GAME_DEFS := "res://data/defs/game_defs.tres"
const SEED := 1480

var _seasons := 8
var _cols := 494
var _rows := 247
var _countries := 60


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seasons="):
			_seasons = maxi(int(arg.substr(10)), 1)
		elif arg.begins_with("--cols="):
			_cols = maxi(int(arg.substr(7)), 20)
		elif arg.begins_with("--rows="):
			_rows = maxi(int(arg.substr(7)), 20)
		elif arg.begins_with("--countries="):
			_countries = maxi(int(arg.substr(12)), 2)
	quit(_run())


func _ms(from_usec: int) -> float:
	return float(Time.get_ticks_usec() - from_usec) / 1000.0


func _median(values: Array[float]) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[int(sorted.size() * 0.5)]


func _run() -> int:
	var map := FakeMap.build(_cols, _rows, SEED)
	var built := FakeScenario.build(map, _countries, SEED)
	var defs := built["defs"] as GameDefs
	var real := ResourceLoader.load(GAME_DEFS, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	if real == null:
		printerr("probe_people_perf: cannot load %s" % GAME_DEFS)
		return 1
	defs.families = real.families
	defs.goods = real.goods
	var t := Time.get_ticks_usec()
	var game := Game.new_scenario(map, defs, built["scenario"] as ScenarioDef, SEED)
	var setup_ms := _ms(t)
	game.act("choose_country", {"tag": game.countries[0].tag})
	var land := 0
	var owned := 0
	for i: int in map.hex_count():
		land += map.land[i]
		if game.state.owner[i] != 0:
			owned += 1
	print("fake Europe %d x %d: %d land hexes, %d owned, %d countries; new_scenario (search, people, purses, stores) %.0f ms" % [
		_cols, _rows, land, owned, game.countries.size(), setup_ms])

	# The walk on its own, cold (the district cache fills) and warm.
	var view := StateView.of(game.state)
	t = Time.get_ticks_usec()
	var total := 0
	for c: Country in game.countries:
		total += People.active(game, view, c.id).size()
	print("People.active, every country, cold: %.1f ms (%d hexes of %d owned)" % [_ms(t), total, owned])
	t = Time.get_ticks_usec()
	for c: Country in game.countries:
		People.active(game, view, c.id)
	print("People.active, every country, warm: %.1f ms" % _ms(t))

	var production: Array[float] = []
	var income: Array[float] = []
	var people: Array[float] = []
	var walk: Array[float] = []
	var stats: Array[float] = []
	var rest: Array[float] = []
	var season: Array[float] = []
	var active_counts: Array[int] = []
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
		Season.run_phase(game, &"works")
		rest.append(_ms(t))
		# The public walk for every country, timed on its own and kept out of the season's total below.
		t = Time.get_ticks_usec()
		var sum := 0
		var plain := StateView.of(game.state)
		for c: Country in game.countries:
			sum += People.active(game, plain, c.id).size()
		walk.append(_ms(t))
		active_counts.append(sum)
		t = Time.get_ticks_usec()
		People.season(game)
		people.append(_ms(t))
		t = Time.get_ticks_usec()
		Season.run_phase(game, &"stats")  # People.close runs inside it
		stats.append(_ms(t))
		t = Time.get_ticks_usec()
		Season.run_phase(game, &"calendar")
		rest.append(_ms(t))
		Season.finish(game)
		season.append(_ms(whole) - walk[n])
		print("  season %d: production %.1f, people %.1f (the walk alone %.1f, %d hexes), stats %.1f" % [
			n + 1, production[n], people[n], walk[n], sum, stats[n]])
	print("per season over %d seasons                    median    worst" % _seasons)
	print("  production_ms (budget 70)                  %7.1f  %7.1f" % [_median(production), production.max()])
	print("  income                                     %7.1f  %7.1f" % [_median(income), income.max()])
	print("  people_ms (budget 30)                      %7.1f  %7.1f" % [_median(people), people.max()])
	print("    People.active called for every country   %7.1f  %7.1f   (a diagnostic: the phase groups the set once)" % [_median(walk), walk.max()])
	print("  stats phase with People.close (budget 60)  %7.1f  %7.1f" % [_median(stats), stats.max()])
	print("  the whole season, people between           %7.1f  %7.1f   (budget 190; the diagnostic walk left out)" % [_median(season), season.max()])

	_profile_rows(game)
	return 0


## The season profile built cold for every country, then its live part, and the hash that keys it: the costs under production
## and stats once the people moved.
func _profile_rows(game: Game) -> void:
	# The live part of the profile, built cold for every country: the cost under production and stats once the people moved.
	game.view_cache.clear()
	var t := Time.get_ticks_usec()
	var held := SeasonProfile.table(game)
	for c: Country in game.countries:
		SeasonProfile.of(game, held, c.id)
	var profile_ms := _ms(t)
	t = Time.get_ticks_usec()
	held = SeasonProfile.table(game)
	for c: Country in game.countries:
		SeasonProfile.live(game, held, c.id)
	print("SeasonProfile, people-free part, cold, every country: %.1f ms; the live totals: %.1f ms (the rows' a0 come with production)" % [profile_ms, _ms(t)])
	t = Time.get_ticks_usec()
	var key_hash := hash(game.state.people)
	print("hash of the people array (%d hexes): %.2f ms (hash %d)" % [game.state.people.size(), _ms(t), key_hash])
