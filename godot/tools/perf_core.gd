## Measures the core's speed on a big made-up world against tests/perf_core_budget.json
## (docs/architecture/m3-build-spec.md and m4-build-spec.md section 8): the season phases (production and income
## included), the cold DistrictCache fill, a digest, a snapshot, a save and a load, the season summary, the reminders, one
## works check, ImprovePreview (of, options_of) and EconomyPreview.expected. Headless, no window, no GUT.
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
	quit(_measure())


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
	return _finish()


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
	_r["stats_phase_ms"] = worst[&"stats"]
	_r["stats_ms_per_country"] = float(worst[&"stats"]) / float(maxi(game.countries.size(), 1))
	return true


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
	s += "| Season | works under way | works ms | stats ms | calendar ms | whole ms |\n|---|---|---|---|---|---|\n"
	for row: Dictionary in _r.get("seasons", []):
		s += "| %d | %d | %.2f | %.2f | %.2f | %.2f |\n" % [row["season"], row["works"], row["works_ms"], row["stats_ms"],
			row["calendar_ms"], row["total_ms"]]
	s += "\nStats phase: %.3f ms a country. Save and load: digest matches %s.\n" % [
		_r.get("stats_ms_per_country", 0.0), str(_r.get("load_digest_matches", false))]
	s += "\n| Row | measured | limit | what | verdict |\n|---|---|---|---|---|\n" + limit_rows
	return s
