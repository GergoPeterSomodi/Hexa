## Measures the core's speed on a big made-up world against tests/perf_core_budget.json
## (docs/architecture/m3-build-spec.md and m4-build-spec.md section 8): the season phases (production and income
## included), the cold DistrictCache fill, a digest, a snapshot, a save and a load, the season summary, the reminders, one
## works check, ImprovePreview (of, options_of) and EconomyPreview.expected. Headless, no window, no GUT.
## The M4.5 and M5 rows (m4-5-build-spec.md 8, m5-build-spec.md 8: study_people_ms, food_bytes_ms) run on a second game, PerfFixture.europe_game(SEASONS_45): the study's views and the
## Yields bytes of the largest country, each on a new game version (cold; the owner index of the territories, keyed on the owner bytes, stays), the worst of RUNS_45.
## A row may carry "known_over": {"issue", "note"} in the budget: over its limit it prints KNOWN OVER and is listed
## in the report and the JSON, but does not fail the run (a row that is back within the limit says so: drop the key).
##
##   godot --headless --path godot -s res://tools/perf_core.gd -- [--cpu-scale=2.0] [--out=perf_core.json] [--summary=summary.md]
##
## The world: FakeMap 494 x 247 (seed 1480), FakeScenario with 60 countries, the 14 FamilyDefs of
## data/defs/game_defs.tres and its 16 goods, work_slots_base 10, 600 works begun (10 a country, each a valid option, Rng seeded 1480),
## then 8 seasons through the phases, then a save and a load in user://perf/. Exit 1 when a row is over its limit.
extends SceneTree

const BUDGET := "res://tests/perf_core_budget.json"
const GAME_DEFS := "res://data/defs/game_defs.tres"
const SAVE_DIR := "user://perf"
const COLS := 494
const ROWS := 247
const SEED := 1480
const COUNTRIES := 60
const PER_COUNTRY := 10
const SEASONS := 8
const MB := 1048576.0
const RUNS := 20
const SEASONS_45 := 40
const RUNS_45 := 5
const FIELDS := 20
## The M6 rows of m6-build-spec.md 8: the phases of army_phases_ms, the samples of the route, reach and step rows.
const ARMY_PHASES: Array[StringName] = [&"movement", &"supply", &"ready_units", &"vision"]
const ROUTES := 200
const ROUTE_NEAR := 12
const REACH_ARMIES := 200
const STEP_HEXES := 500
const TOKEN_RUNS := 5
const WAR_SEASONS := 2
const WAR_RUNS := 8
const COLD_RUNS := 3

var _cpu_scale := 1.0
var _out := ""
var _summary := ""
var _budget_path := BUDGET
var _r: Dictionary = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cpu-scale="):
			_cpu_scale = float(arg.substr(12))
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--summary="):
			_summary = arg.substr(10)
		elif arg.begins_with("--budget="):
			_budget_path = arg.substr(9)
	var code := _measure()
	if code == 0:
		code = _war_rows()
	if code == 0:
		code = _europe_40()
	quit(_finish() if code == 0 else code)


func _ms(from_usec: int) -> float:
	return float(Time.get_ticks_usec() - from_usec) / 1000.0


func _measure() -> int:
	var t := Time.get_ticks_usec()
	var map := FakeMap.build(COLS, ROWS, SEED)
	_r["map_build_ms"] = _ms(t)
	_r["hexes"] = map.hex_count()
	t = Time.get_ticks_usec()
	var built := FakeScenario.build(map, COUNTRIES, SEED)
	var defs := built["defs"] as GameDefs
	var scenario := built["scenario"] as ScenarioDef
	var real := ResourceLoader.load(GAME_DEFS, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	if real == null or real.families.size() != FamilyIds.COUNT - 1:
		printerr("perf_core: cannot load the families of %s" % GAME_DEFS)
		return 1
	defs.families = real.families
	defs.goods = real.goods
	defs.work_slots_base = PER_COUNTRY
	var game := Game.new_scenario(map, defs, scenario, SEED)
	_r["scenario_build_ms"] = _ms(t)
	_r["countries"] = game.countries.size()
	var largest := _largest(game)
	if not bool(game.act("choose_country", {"tag": largest})["ok"]):
		printerr("perf_core: cannot choose %s" % largest)
		return 1
	_r["works_begun"] = _begin_works(game)
	_r["cache_build_ms"] = _cache_build(game)
	_r["works_at_start"] = game.state.works.size()

	_r["work_check_ms"] = _work_check(game, largest)
	if not _seasons(game):
		return 1
	_armies(game)
	_army_rows(game, largest)

	t = Time.get_ticks_usec()
	var digest := game.digest()
	_r["digest_ms"] = _ms(t)

	t = Time.get_ticks_usec()
	var body := Snapshot.of(game, {})
	_r["snapshot_ms"] = _ms(t)
	_r["body_keys"] = body.size()

	_save_and_load(game, map, defs, digest)
	_previews(game, largest)

	game.version += 1  # a new version: the views are made again (the index of the owners stays: it is keyed on the owner bytes)
	t = Time.get_ticks_usec()
	var summary := SeasonSummary.of(game, largest, game.turn - 1)
	_r["summary_ms"] = _ms(t)
	_r["summary_sections"] = (summary.get("sections", []) as Array).size()
	game.version += 1  # a new version: the views are made again (the index of the owners stays: it is keyed on the owner bytes)
	t = Time.get_ticks_usec()
	var lines := Reminders.unfinished(game, largest)
	_r["reminders_ms"] = _ms(t)
	_r["reminder_lines"] = lines.size()
	_r["largest"] = String(largest)
	return 0


## The M4.5 rows on the made-up Europe after SEASONS_45 seasons (the ring full, the chronicle at its 3,000).
func _europe_40() -> int:
	var t := Time.get_ticks_usec()
	var game := PerfFixture.europe_game(SEASONS_45)
	if game == null:
		return 1
	_r["europe_40_build_ms"] = _ms(t)
	var tag := PerfFixture.largest_tag(game)
	_r["chronicle_entries"] = game.chronicle.entries.size()
	_r["turn_45"] = game.turn
	Knowledge.known(game, tag)  # the owner index of the territories is built once per owner change, not per view
	_r["worth_seasons_ms"] = _worst(game, func() -> void: EconomyPreview.worth_seasons_shared(game, tag, 4))
	_r["study_districts_ms"] = _worst(game, func() -> void: StudyEconomy.districts(game, tag))
	_r["study_goods_ms"] = _worst(game, func() -> void: StudyEconomy.goods(game, tag, 40))
	_r["study_history_ms"] = _worst(game, func() -> void: StudyEconomy.history(game, tag, 40))
	_r["study_rankings_ms"] = _worst(game, func() -> void: StudyRankings.of(game, tag, 40))
	_r["history_index_ms"] = _worst(game, func() -> void: StudyHistory.index(game, tag))
	var last := game.turn - 1
	var worst := 0.0
	for n: int in RUNS_45:
		game.version += 1
		StudyHistory.index(game, tag)  # warm: the page is measured on top of it
		var t2 := Time.get_ticks_usec()
		StudyHistory.timeline(game, tag)
		StudyHistory.chronicle(game, tag, &"all", last, StudyHistory.PAGE)
		worst = maxf(worst, _ms(t2))
	_r["history_page_ms"] = worst
	_r["yield_bytes_ms"] = _worst(game, func() -> void: MapModes.yield_bytes(game, tag))
	_r["study_people_ms"] = _worst(game, func() -> void: StudyPeople.of(game, tag, 40))  # M5 (m5-build-spec.md 8)
	_r["food_bytes_ms"] = _worst(game, func() -> void: MapModes.food_bytes(game, tag))  # M5: worth_seasons cold, then the bytes
	return 0


## The worst of RUNS_45 calls of `call`, each on a new game version (cold: the views are made again, the owner index of the territories stays, as after an action).
## M7 rows (m7-build-spec.md 8): the war phases on the made-up Europe with WAR_PAIRS wars (PerfFixture.europe_war), the worst of
## WAR_RUNS runs of Wars.season and of Sieges.season. The sieges row has no standing siege on this fixture (the 100-siege
## fixture of the spec is not built yet); the battles rows wait for their fixture too.
func _war_rows() -> int:
	var game := PerfFixture.europe_war(WAR_SEASONS)
	if game == null:
		printerr("perf_core: cannot build the war fixture")
		return 1
	_r["wars_declared"] = game.wars.size()
	_r["war_ms"] = _worst_of(game, Callable(Season, "run_phase").bind(game, &"war"), WAR_RUNS)
	_r["sieges_ms"] = _worst_of(game, Callable(Season, "run_phase").bind(game, &"sieges"), WAR_RUNS)
	return 0


func _worst(game: Game, call: Callable) -> float:
	var worst := 0.0
	for n: int in RUNS_45:
		game.version += 1
		var t := Time.get_ticks_usec()
		call.call()
		worst = maxf(worst, _ms(t))
	return worst


## DistrictCache filled for every land hex from cold (a new game, a load); leaves it warm.
func _cache_build(game: Game) -> float:
	game.districts.clear()
	var t := Time.get_ticks_usec()
	for i: int in game.map.hex_count():
		if game.map.land[i] == 1:
			game.districts.base_of(game, i)
	return _ms(t)


## ImprovePreview.of (the country's base warm, the option cold), options_of on the hex with the most options (cold: a new
## game version each time) and EconomyPreview.expected (uncached), each the mean of RUNS calls (the works card's views).
func _previews(game: Game, tag: StringName) -> void:
	var c := Countries.by_tag(game, tag)
	var hex := Vector2i(-1, -1)
	var most := 0
	for i: int in Territory.districts(game, c.id):
		var n := Improve.build_options(game, game.map.hex_of(i)).size()
		if n > most:
			most = n
			hex = game.map.hex_of(i)
	var rows := ImprovePreview.options_of(game, tag, hex)
	_r["options_rows"] = rows.size()
	if rows.is_empty():
		printerr("perf_core: no hex with build options for %s" % tag)
		return
	var option := {"action": rows[0]["action"], "family": rows[0]["family"]}
	var t := Time.get_ticks_usec()
	for n: int in RUNS:
		game.version += 1
		ImprovePreview.options_of(game, tag, hex)
	_r["options_ms"] = _ms(t) / float(RUNS)
	game.version += 1
	ImprovePreview.of(game, tag, hex, option)  # the country's land summed up for this version
	t = Time.get_ticks_usec()
	for n: int in RUNS:
		ImprovePreview._make(game, tag, hex, option["action"], int(option["family"]))
	_r["preview_ms"] = _ms(t) / float(RUNS)
	t = Time.get_ticks_usec()
	for n: int in RUNS:
		game.version += 1
		EconomyPreview.expected(game, tag)
	_r["expected_ms"] = _ms(t) / float(RUNS)


## The tag of the country with the most hexes (the one the summary and the reminders are measured for).
func _largest(game: Game) -> StringName:
	var best := game.countries[0]
	var best_n := -1
	for c: Country in game.countries:
		var n := Territory.count(game, c.id)
		if n > best_n:
			best = c
			best_n = n
	_r["largest_hexes"] = best_n
	return best.tag


## PER_COUNTRY valid build options a country, picked at random on its own land. Returns how many were begun.
func _begin_works(game: Game) -> int:
	var luck := Rng.new()
	luck.seed_with(SEED)
	var begun := 0
	for c: Country in game.countries:
		game.dev_money(c.tag, 1000000)  # the works cost ducats and goods now (4.11): fund them
		for good: int in game.defs.goods.size():
			game.dev_goods(c.tag, good, 1000)
		var districts := Territory.districts(game, c.id)
		var got := 0
		var tries := 0
		while got < PER_COUNTRY and tries < 4000 and districts.size() > 0:
			tries += 1
			var hex := game.map.hex_of(districts[luck.randi_range(0, districts.size() - 1)])
			var options: Array[Dictionary] = []
			for o: Dictionary in game.improvement.build_options(hex):
				if bool(o["ok"]):
					options.append(o)
			if options.is_empty():
				continue
			var pick := options[luck.randi_range(0, options.size() - 1)]
			var verdict := Works.build(game, {"hex": hex, "family": int(pick["family_id"]), "tag": c.tag})
			if bool(verdict["ok"]):
				got += 1
		begun += got
	return begun


## One Works.build_check on free hexes of `tag` with all the works under way (mean of 20 calls).
func _work_check(game: Game, tag: StringName) -> float:
	var c := Countries.by_tag(game, tag)
	var args := {"tag": tag, "family": ImproveRules.WHEAT, "hex": Vector2i.ZERO}
	var total := 0.0
	var n := 0
	for idx: int in Territory.districts(game, c.id):
		var hex := game.map.hex_of(idx)
		if game.state.work_at(hex) != null:
			continue
		args["hex"] = hex
		var t := Time.get_ticks_usec()
		Works.build_check(game, args)
		total += _ms(t)
		n += 1
		if n == 20:
			break
	return total / float(maxi(n, 1))


## SEASONS seasons through the phases, each timed; the worst of each row is kept. False when a season cannot end.
func _seasons(game: Game) -> bool:
	var worst_season := 0.0
	var worst := {}
	var rows: Array = []
	for phase: StringName in Season.PHASES:
		worst[phase] = 0.0
	for n: int in SEASONS:
		var works_before := game.state.works.size()
		var season_t := Time.get_ticks_usec()
		var verdict := Season.end_check(game)
		if not bool(verdict["ok"]):
			printerr("perf_core: the season cannot end: %s" % verdict["reason"])
			return false
		Season.begin(game)
		var row := {"season": n + 1, "works": works_before}
		for phase: StringName in Season.PHASES:
			var t := Time.get_ticks_usec()
			Season.run_phase(game, phase)
			var spent := _ms(t)
			row[String(phase) + "_ms"] = spent
			worst[phase] = maxf(float(worst[phase]), spent)
		Season.finish(game)
		row["total_ms"] = _ms(season_t)
		worst_season = maxf(worst_season, float(row["total_ms"]))
		rows.append(row)
	_r["seasons"] = rows
	_r["season_ms"] = worst_season
	_r["production_ms"] = worst[&"production"]
	_r["income_ms"] = worst[&"income"]
	_r["works_phase_ms"] = worst[&"works"]
	_r["people_ms"] = worst[&"people"]
	_r["stats_phase_ms"] = worst[&"stats"]
	_r["stats_ms_per_country"] = float(worst[&"stats"]) / float(maxi(game.countries.size(), 1))
	return true


## The M6 rows (m6-build-spec.md 8): ten armies a country seeded through the door (PerfFixture.seed_armies), then SEASONS
## seasons of every phase with the arrivals re-ordered between them (outside the timed phases). movement_ms, supply_ms and
## vision_ms are the worst of each phase; cost_field_ms the worst of FIELDS cost fields over the whole map. The armies stay in
## the game, so the digest, the save and the rows after this one carry them.
func _armies(game: Game) -> void:
	var luck := Rng.new()
	luck.seed_with(SEED)
	var armies := PerfFixture.seed_armies(game, luck)
	_r["armies"] = armies.size()
	var worst := {&"movement": 0.0, &"supply": 0.0, &"vision": 0.0, &"ready_units": 0.0}
	var army_phases := 0.0  # the worst season's sum of ARMY_PHASES (m6-build-spec.md 5.0 R10)
	for _n: int in SEASONS:
		Season.begin(game)
		var season_army := 0.0
		for phase: StringName in Season.PHASES:
			var t := Time.get_ticks_usec()
			Season.run_phase(game, phase)
			var spent := _ms(t)
			if worst.has(phase):
				worst[phase] = maxf(float(worst[phase]), spent)
			if ARMY_PHASES.has(phase):
				season_army += spent
		army_phases = maxf(army_phases, season_army)
		Season.finish(game)
		PerfFixture.rearm(game, luck, armies)
	_r["movement_ms"] = worst[&"movement"]
	_r["supply_ms"] = worst[&"supply"]
	_r["vision_ms"] = worst[&"vision"]
	_r["ready_units_ms"] = worst[&"ready_units"]
	_r["army_phases_ms"] = army_phases
	_r["cost_field_ms"] = _cost_fields(game, luck)


## The M6 rows that read the armies once they are in the game (m6-build-spec.md 8): supply_cold_ms (every country's two
## fields from cold), route_ms and route_worst_ms (Movement.plan, seeded), reach_ms (MovePreview.reach, uncached),
## step_fill_us (one hex's twelve step costs from a fresh table), tokens_ms (ArmyView.tokens of the largest country,
## uncached) and supply_bytes_ms (MapModes.supply_bytes, cold). Each uncached call makes a new game version first.
func _army_rows(game: Game, largest: StringName) -> void:
	var luck := Rng.new()
	luck.seed_with(SEED + 6)
	_r["supply_cold_ms"] = _supply_cold(game)
	var routes := _routes(game, luck)
	_r["route_ms"] = routes[0]
	_r["route_worst_ms"] = routes[1]
	_r["reach_ms"] = _reach(game)
	_r["step_fill_us"] = _step_fill(game, luck)
	_r["tokens_ms"] = _worst_of(game, func() -> void: ArmyView.tokens(game, largest), TOKEN_RUNS)
	_r["supply_bytes_ms"] = _cold_worst(game, func() -> void: MapModes.supply_bytes(game, largest), TOKEN_RUNS)


## Every country's supply fields (winter and summer) from cold: the view cache is cleared first, worst of COLD_RUNS.
func _supply_cold(game: Game) -> float:
	var worst := 0.0
	for _n: int in COLD_RUNS:
		game.view_cache.clear()
		var t := Time.get_ticks_usec()
		for c: Country in game.countries:
			Supply.field(game, c.tag, false)
			Supply.field(game, c.tag, true)
		worst = maxf(worst, _ms(t))
	return worst


## Movement.plan for ROUTES seeded (army, goal) pairs: an army of the game to a land hex of its country within ROUTE_NEAR
## hexes (about one to four seasons of march). Returns [mean ms, worst ms].
func _routes(game: Game, luck: Rng) -> Array[float]:
	var total := 0.0
	var worst := 0.0
	var n := 0
	if game.armies.is_empty():
		return [0.0, 0.0]
	for _k: int in ROUTES:
		var a := game.armies[luck.randi_range(0, game.armies.size() - 1)]
		var land := Territory.districts(game, Countries.by_tag(game, a.tag).id)
		if land.is_empty():
			continue
		var goal := game.map.hex_of(land[luck.randi_range(0, land.size() - 1)])
		if ImproveRules.hex_distance(goal, a.hex) > ROUTE_NEAR:
			continue
		var t := Time.get_ticks_usec()
		Movement.plan(game, a, goal)
		var spent := _ms(t)
		total += spent
		worst = maxf(worst, spent)
		n += 1
	return [total / float(maxi(n, 1)), worst]


## MovePreview.reach of the first REACH_ARMIES armies, each on a new version (uncached): the worst.
func _reach(game: Game) -> float:
	var worst := 0.0
	var n := 0
	for a: Army in game.armies:
		if n >= REACH_ARMIES:
			break
		game.version += 1
		var t := Time.get_ticks_usec()
		MovePreview.reach(game, a.tag, a.id)
		worst = maxf(worst, _ms(t))
		n += 1
	return worst


## One hex's twelve step costs filled from a fresh table (StepCosts fills a hex on its first cost): the mean in microseconds.
func _step_fill(game: Game, luck: Rng) -> float:
	var steps := StepCosts.new(game.map, game.defs)
	var total := 0.0
	var n := 0
	for _k: int in STEP_HEXES:
		var i := luck.randi_range(0, game.map.hex_count() - 1)
		var t := Time.get_ticks_usec()
		steps.cost(i, 0, false)
		total += float(Time.get_ticks_usec() - t)
		n += 1
	return total / float(maxi(n, 1))


## The worst of `runs` calls of `call`, each on a new game version (uncached).
func _worst_of(game: Game, call: Callable, runs: int) -> float:
	var worst := 0.0
	for _n: int in runs:
		game.version += 1
		var t := Time.get_ticks_usec()
		call.call()
		worst = maxf(worst, _ms(t))
	return worst


## The worst of `runs` calls of `call` with the view cache cleared first (the fields from cold).
func _cold_worst(game: Game, call: Callable, runs: int) -> float:
	var worst := 0.0
	for _n: int in runs:
		game.view_cache.clear()
		game.version += 1
		var t := Time.get_ticks_usec()
		call.call()
		worst = maxf(worst, _ms(t))
	return worst


## PathSearch.cost_field over the whole map (every land hex allowed), worst of FIELDS goals: M8's march (m6 spec 8).
func _cost_fields(game: Game, luck: Rng) -> float:
	var map := game.map
	var steps := StepCosts.of(map, game.defs)
	var allowed := PackedByteArray()
	allowed.resize(map.hex_count())
	var land: Array[int] = []
	for i: int in map.hex_count():
		allowed[i] = map.land[i]
		if map.land[i] == 1:
			land.append(i)
	var worst := 0.0
	for _n: int in FIELDS:
		var goal := land[luck.randi_range(0, land.size() - 1)]
		var t := Time.get_ticks_usec()
		PathSearch.cost_field(map, steps, allowed, map.hex_of(goal), false)
		worst = maxf(worst, _ms(t))
	return worst


## Writes the game to user://perf/, reads it back, restores it and checks the digest.
func _save_and_load(game: Game, map: MapData, defs: GameDefs, digest: String) -> void:
	_remove_dir()
	var info := {"build": "perf", "name": "perf", "saved_unix": 0, "play_seconds": 0}
	var t := Time.get_ticks_usec()
	var problem := SaveFile.write(game, "1", info, {}, SAVE_DIR)
	_r["save_ms"] = _ms(t)
	if not problem.is_empty():
		printerr("perf_core: the save failed: %s" % problem)
		_r["load_digest_matches"] = false
		return
	_r["save_mb"] = float(FileAccess.get_file_as_bytes(SaveFile.path_of("1", SAVE_DIR)).size()) / MB
	t = Time.get_ticks_usec()
	var read := SaveFile.read("1", SAVE_DIR)
	var back: Game = null
	if str(read["problem"]).is_empty():
		back = Snapshot.restore(read["body"] as Dictionary, map, defs)["game"] as Game
	var header_digest := str((read["header"] as Dictionary).get("digest", ""))
	_r["load_digest_matches"] = back != null and back.digest() == digest and header_digest == digest
	_r["load_ms"] = _ms(t)
	_remove_dir()


func _remove_dir() -> void:
	var abs_dir := ProjectSettings.globalize_path(SAVE_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	for file: String in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(file))
	DirAccess.remove_absolute(abs_dir)


## The table, the JSON, the verdict.
func _finish() -> int:
	var limits: Dictionary = _read_budget().get("limits", {})
	var failed: Array[String] = []
	var known: Array[String] = []
	var rows := ""
	for key: String in limits:
		var spec: Dictionary = limits[key]
		var value := float(_r.get(key, INF))
		var limit := float(spec["limit"]) * (_cpu_scale if str(spec["class"]) == "cpu" else 1.0)
		var verdict := "ok"
		var accepted: Dictionary = spec.get("known_over", {})
		if value > limit and not accepted.is_empty():
			verdict = "KNOWN OVER (#%s)" % str(int(accepted.get("issue", 0)))
			known.append("%s %.2f > %.2f: issue #%s, %s" % [key, value, limit, str(int(accepted.get("issue", 0))), str(accepted.get("note", ""))])
		elif value > limit:
			verdict = "FAIL"
			failed.append("%s %.2f > %.2f" % [key, value, limit])
		elif not accepted.is_empty():
			verdict = "ok (known_over is no longer needed: remove it)"
		rows += "| %s | %.2f | %.2f | %s | %s |\n" % [key, value, limit, str(spec["what"]), verdict]
	if not bool(_r.get("load_digest_matches", false)):
		failed.append("the loaded game's digest differs")
	var text := _markdown(rows)
	print(text)
	_r["failed"] = failed
	_r["known_over"] = known
	for line: String in known:
		print("perf_core: KNOWN OVER, not hidden: %s" % line)
	if _out != "":
		var file := FileAccess.open(_out, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_r, "  "))
	if _summary != "":
		var file := FileAccess.open(_summary, FileAccess.READ_WRITE if FileAccess.file_exists(_summary) else FileAccess.WRITE)
		if file != null:
			file.seek_end()
			file.store_string(text + "\n")
	if failed.is_empty():
		print("perf_core: within the limits")
		return 0
	printerr("perf_core: over the limits: %s" % ", ".join(failed))
	return 1


func _read_budget() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_budget_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("perf_core: %s does not read" % _budget_path)
		return {}
	return parsed as Dictionary


func _markdown(limit_rows: String) -> String:
	var s := "## Core speed (fake world %d x %d = %d hexes, %d countries, seed %d)\n\n" % [
		COLS, ROWS, _r["hexes"], _r["countries"], SEED]
	s += "Built: map %.0f ms, scenario and game %.0f ms; %d works begun (%d under way at the start); the largest country is %s with %d hexes.\n\n" % [
		_r["map_build_ms"], _r["scenario_build_ms"], _r["works_begun"], _r["works_at_start"], _r.get("largest", "?"), _r["largest_hexes"]]
	s += "| Season | works under way | works ms | people ms | stats ms | calendar ms | whole ms |\n|---|---|---|---|---|---|---|\n"
	for row: Dictionary in _r.get("seasons", []):
		s += "| %d | %d | %.2f | %.2f | %.2f | %.2f | %.2f |\n" % [row["season"], row["works"], row["works_ms"], row["people_ms"], row["stats_ms"],
			row["calendar_ms"], row["total_ms"]]
	s += "\nStats phase: %.3f ms a country. Save and load: digest matches %s.\n" % [
		_r.get("stats_ms_per_country", 0.0), str(_r.get("load_digest_matches", false))]
	s += "\n| Row | measured | limit | what | verdict |\n|---|---|---|---|---|\n" + limit_rows
	return s
