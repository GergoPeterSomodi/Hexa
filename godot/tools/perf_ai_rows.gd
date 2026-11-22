## The AI rows of tools/perf_core.gd (docs/architecture/m8-build-spec.md 8.1 to 8.3, K23), each season played by the AI (Game.watch,
## AiPlayers.attach), the ai_orders phase driven a step at a time and timed:
##   ai_season_ms / ai_season_worst_ms  the ai_orders phase, mean and worst of the measured seasons
##   ai_seat_ms / ai_seat_worst_ms      one seat's turn (its steps summed), mean and worst over every seat of every measured season
##   ai_step_worst_ms                   the worst single step
##   ai_brief_ms                        AiBrief.make for the largest seat, warm (the mean of BRIEF_RUNS); ai_brief_cold_ms: the first make on a new version
##   ai_season_ni_ms                    north Italy (seed 1480, AI-only), the worst ai_orders phase of seasons 9 to 24
##   ai_save_mb, ai_load_ms             the made-up Europe after TOTAL_SEASONS AI seasons: the .sav size, the load with the digest check
## Also written: ai_other_phases_ms (the thirteen other phases, worst season), ai_seasons_measured, ai_steps, ai_end_check_failed.
## The table of 8.3 (E3) is printed by print_e3: the windowed rows are estimates from the headless numbers (perf_ui measures them).
class_name PerfAiRows
extends RefCounted

const FAKE := "fake"
const WARM_FAKE := 8
const MEASURED := 8
const WARM_NI := 8
const MEASURED_NI := 16
const WARM_MAP := 16
const TOTAL_SEASONS := 40
const BRIEF_RUNS := 5
const SEED := 1480
const SAVE_DIR := "user://perf_ai"
## The AI's slice a frame while the camera moves (shell/app/season_flow.gd AI_SLICE_MS) and the frames a second.
const SLICE_MS := 5.0
const FPS := 60.0
const WALL_LIMIT_S := 10.0
const FRAME_MEAN_LIMIT_MS := 16.0
const FRAME_WORST_LIMIT_MS := 24.0
const OTHER_PHASES_LIMIT_MS := 380.0
const MB := 1048576.0
const PROGRESS_FILE := "user://perf_ai_progress.txt"
## Seasons played in all before the save row (--ai-total=N shortens a probe).
static var total_seasons := TOTAL_SEASONS
## Step kind -> {ms, n, worst}: where the time of the measured seasons went (printed by run).
static var kinds: Dictionary = {}


## The made-up Europe (map "fake") or the committed map and scenario; the rows go into `r`. `warm` seasons are played first
## unless the fake Europe's rig (which plays WARM_FAKE itself). Returns 0, or 1 when the game cannot be made.
static func run(r: Dictionary, map_id: String, scenario_id: String) -> int:
	var fake := map_id == "" or map_id == FAKE
	var game: Game = null
	var measured := MEASURED
	if fake:
		game = PerfFixture.europe_ai(WARM_FAKE)
	else:
		game = _game_of(map_id, scenario_id)
		if game != null:
			play(game, WARM_MAP)
	if game == null:
		printerr("perf_ai_rows: cannot make the game (map %s, scenario %s)" % [map_id, scenario_id])
		return 1
	r["ai_map"] = FAKE if fake else map_id
	kinds = {}
	var stats := play(game, measured)
	print_kinds()
	_fill(r, stats)
	r["ai_seats"] = game.orders.seats()
	_brief(game, r)
	if fake:
		var played := WARM_FAKE + measured
		play(game, maxi(total_seasons - played, 0))
		_save_load(game, r)
	return 0


## North Italy, seed 1480, AI-only: ai_season_ni_ms is the worst ai_orders phase of seasons 9 to 24.
static func run_ni(r: Dictionary) -> int:
	var game := _game_of("north_italy", "north_italy_1480")
	if game == null:
		return 1
	play(game, WARM_NI)
	var stats := play(game, MEASURED_NI)
	r["ai_season_ni_ms"] = float(stats["season_worst"])
	r["ai_step_ni_ms"] = float(stats["step_worst"])
	return 0


## `count` seasons played with every phase timed. Returns season_mean, season_worst, seat_mean, seat_worst, step_worst, other_worst,
## steps, seasons, bad (end_check refusals: the season was not played).
static func play(game: Game, count: int) -> Dictionary:
	var totals: Array[float] = []
	var seats: Array[float] = []
	var step_worst := 0.0
	var other_worst := 0.0
	var steps := 0
	var bad := 0
	for _n: int in count:
		if not bool(Season.end_check(game)["ok"]):
			bad += 1
			break
		Season.begin(game)
		var other := 0.0
		for phase: StringName in Season.PHASES:
			if phase == &"ai_orders":
				var one := _orders(game, seats)
				totals.append(float(one["total"]))
				step_worst = maxf(step_worst, float(one["step_worst"]))
				steps += int(one["steps"])
			else:
				var t := Time.get_ticks_usec()
				Season.run_phase(game, phase)
				other += float(Time.get_ticks_usec() - t) / 1000.0
		Season.finish(game)
		other_worst = maxf(other_worst, other)
		progress("turn %d: ai_orders %.0f ms, other phases %.0f ms" % [game.turn, totals[totals.size() - 1], other])
	return {"season_mean": _mean(totals), "season_worst": _max(totals), "seat_mean": _mean(seats), "seat_worst": _max(seats),
		"step_worst": step_worst, "other_worst": other_worst, "steps": steps, "seasons": totals.size(), "bad": bad}


## The ai_orders phase a step at a time; appends each seat's summed ms to `seats`.
static func _orders(game: Game, seats: Array[float]) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	Season.orders_begin(game)
	var per_seat: Dictionary = {}
	var worst := 0.0
	var steps := 0
	while true:
		var at := game.orders.seats_done()
		var kind := _kind_of(game.orders)
		var t := Time.get_ticks_usec()
		var done := Season.orders_step(game)
		var ms := float(Time.get_ticks_usec() - t) / 1000.0
		worst = maxf(worst, ms)
		_tally(kind, ms)
		per_seat[at] = float(per_seat.get(at, 0.0)) + ms
		steps += 1
		if done:
			break
	Season.orders_end(game)
	for key: Variant in per_seat:
		seats.append(float(per_seat[key]))
	return {"total": float(Time.get_ticks_usec() - t0) / 1000.0, "step_worst": worst, "steps": steps}


static func _fill(r: Dictionary, s: Dictionary) -> void:
	r["ai_season_ms"] = float(s["season_mean"])
	r["ai_season_worst_ms"] = float(s["season_worst"])
	r["ai_seat_ms"] = float(s["seat_mean"])
	r["ai_seat_worst_ms"] = float(s["seat_worst"])
	r["ai_step_worst_ms"] = float(s["step_worst"])
	r["ai_other_phases_ms"] = float(s["other_worst"])
	r["ai_seasons_measured"] = int(s["seasons"])
	r["ai_steps"] = int(s["steps"])
	r["ai_end_check_failed"] = int(s["bad"])


## AiBrief.make for the largest seat: the first make on a new version (cold) and the mean of BRIEF_RUNS more (warm).
static func _brief(game: Game, r: Dictionary) -> void:
	var tag := PerfFixture.largest_tag(game)
	game.version += 1
	game.view_cache.clear()
	var t := Time.get_ticks_usec()
	AiBrief.make(game, tag)
	r["ai_brief_cold_ms"] = float(Time.get_ticks_usec() - t) / 1000.0
	t = Time.get_ticks_usec()
	for _n: int in BRIEF_RUNS:
		AiBrief.make(game, tag)
	r["ai_brief_ms"] = float(Time.get_ticks_usec() - t) / 1000.0 / float(BRIEF_RUNS)
	r["ai_brief_seat"] = String(tag)


## The game as it is saved to user://perf_ai/ and read back: ai_save_mb, ai_load_ms and whether the digest matches.
static func _save_load(game: Game, r: Dictionary) -> void:
	var digest := game.digest()
	_remove_dir()
	var info := {"build": "perf", "name": "perf", "saved_unix": 0, "play_seconds": 0}
	var problem := SaveFile.write(game, "1", info, {}, SAVE_DIR)
	r["ai_turn_saved"] = game.turn
	if not problem.is_empty():
		printerr("perf_ai_rows: the save failed: %s" % problem)
		r["ai_load_digest_matches"] = false
		return
	r["ai_save_mb"] = float(FileAccess.get_file_as_bytes(SaveFile.path_of("1", SAVE_DIR)).size()) / MB
	var t := Time.get_ticks_usec()
	var read := SaveFile.read("1", SAVE_DIR)
	var back: Game = null
	if str(read["problem"]).is_empty():
		back = Snapshot.restore(read["body"] as Dictionary, game.map, game.defs)["game"] as Game
	r["ai_load_ms"] = float(Time.get_ticks_usec() - t) / 1000.0
	r["ai_load_digest_matches"] = back != null and back.digest() == digest
	_remove_dir()


static func _remove_dir() -> void:
	var abs_dir := ProjectSettings.globalize_path(SAVE_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	for file: String in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(file))
	DirAccess.remove_absolute(abs_dir)


## A game of a committed map and scenario, AI-only on seed 1480, the AI attached; null when either is missing.
static func _game_of(map_id: String, scenario_id: String) -> Game:
	var path := "res://data/maps/%s.tres" % map_id
	if not ResourceLoader.exists(path):
		return null
	var map := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MapData
	var defs := EconomyFixture.defs(true, true)
	var scenario: ScenarioDef = null
	for s: ScenarioDef in defs.scenarios:
		if s.map_id == map_id and (scenario_id == "" or s.id == scenario_id):
			scenario = s
	if map == null or scenario == null:
		return null
	var game := Game.new_scenario(map, defs, scenario, SEED)
	if not game.watch():
		return null
	AiPlayers.attach(game)
	return game


## The table of 8.3 for the rows in `r` (the made-up Europe), each criterion with its verdict. `limits` is the budget's limits.
static func print_e3(r: Dictionary, limits: Dictionary, scale: float) -> void:
	var wall := float(r.get("ai_season_worst_ms", 0.0)) / SLICE_MS / FPS
	var frame_mean := SLICE_MS
	var frame_worst := SLICE_MS + float(r.get("ai_step_worst_ms", 0.0))
	var rows: Array[Array] = [
		["ai_season_ms mean", float(r.get("ai_season_ms", INF)), _lim(limits, "ai_season_ms", scale), _known(limits, "ai_season_ms")],
		["ai_season_ms worst", float(r.get("ai_season_worst_ms", INF)), _lim(limits, "ai_season_worst_ms", scale), _known(limits, "ai_season_worst_ms")],
		["ai_step_worst_ms", float(r.get("ai_step_worst_ms", INF)), _lim(limits, "ai_step_worst_ms", scale), _known(limits, "ai_step_worst_ms")],
		["season_ms (the thirteen other phases, worst)", float(r.get("ai_other_phases_ms", INF)), OTHER_PHASES_LIMIT_MS * scale, ""],
		["AI turn wall time, s (estimate: worst turn / %.0f ms slice / %.0f fps; windowed: perf_ui)" % [SLICE_MS, FPS], wall, WALL_LIMIT_S, ""],
		["frame while the AI runs, mean ms (estimate: the slice; windowed: perf_ui)", frame_mean, FRAME_MEAN_LIMIT_MS, ""],
		["frame while the AI runs, worst ms (estimate: slice + worst step; windowed: perf_ui)", frame_worst, FRAME_WORST_LIMIT_MS, ""],
		["save_mb after 40 AI seasons", float(r.get("ai_save_mb", INF)), _lim(limits, "ai_save_mb", scale), _known(limits, "ai_save_mb")],
		["load_ms after 40 AI seasons", float(r.get("ai_load_ms", INF)), _lim(limits, "ai_load_ms", scale), _known(limits, "ai_load_ms")],
	]
	print("## E3: an AI season on the %s map (%d seasons measured after the warm-up, %d seats a season)\n" % [
		str(r.get("ai_map", FAKE)), int(r.get("ai_seasons_measured", 0)), int(r.get("ai_seats", 0))])
	print("| Criterion | measured | limit | verdict |\n|---|---|---|---|")
	for row: Array in rows:
		var value := float(row[1])
		var limit := float(row[2])
		var verdict := "ok"
		if value > limit:
			verdict = ("KNOWN OVER (#%s)" % str(row[3])) if str(row[3]) != "" else "OVER"
		print("| %s | %.2f | %.2f | %s |" % [row[0], value, limit, verdict])
	print("| the soak's europe suite (4 games x 40 seasons) | not measured here | no crash, no broken invariant | tools/soak.gd (K22) |")
	print("| a frame at every zoom (M1) | not measured here | 16 | tools/map/perf_map.gd |")
	print("| the loaded game's digest equals the saved one | %s | true | %s |" % [str(r.get("ai_load_digest_matches", false)),
		"ok" if bool(r.get("ai_load_digest_matches", false)) else "FAIL"])
	print("| end_check refusals while playing | %d | 0 | %s |" % [int(r.get("ai_end_check_failed", 0)),
		"ok" if int(r.get("ai_end_check_failed", 0)) == 0 else "FAIL"])


static func _lim(limits: Dictionary, key: String, scale: float) -> float:
	if not limits.has(key):
		return INF
	var spec: Dictionary = limits[key]
	return float(spec["limit"]) * (scale if str(spec["class"]) == "cpu" else 1.0)


static func _known(limits: Dictionary, key: String) -> String:
	var spec: Dictionary = limits.get(key, {})
	var accepted: Dictionary = spec.get("known_over", {})
	return str(int(accepted.get("issue", 0))) if not accepted.is_empty() else ""


static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for v: float in values:
		sum += v
	return sum / float(values.size())


static func _max(values: Array[float]) -> float:
	var out := 0.0
	for v: float in values:
		out = maxf(out, v)
	return out


## One line to the progress file (PROGRESS_FILE, flushed at once): a long run is watched from outside.
static func progress(text: String) -> void:
	var file := FileAccess.open(PROGRESS_FILE, FileAccess.READ_WRITE if FileAccess.file_exists(PROGRESS_FILE) else FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line(text)


## The name of the step the hook runs next (its queue is read through get: a tool, not the rules).
static func _kind_of(hook: Object) -> String:
	var queue: Array = hook.get("_queue")
	var cursor := int(hook.get("_cursor"))
	if queue.is_empty() or cursor >= queue.size():
		return "brief"
	return String((queue[cursor] as Dictionary)["name"])


static func _tally(kind: String, ms: float) -> void:
	var row: Dictionary = kinds.get(kind, {"ms": 0.0, "n": 0, "worst": 0.0})
	row["ms"] = float(row["ms"]) + ms
	row["n"] = int(row["n"]) + 1
	row["worst"] = maxf(float(row["worst"]), ms)
	kinds[kind] = row


static func print_kinds() -> void:
	print("| step kind | total ms | steps | mean ms | worst ms |\n|---|---|---|---|---|")
	for kind: String in kinds:
		var row: Dictionary = kinds[kind]
		print("| %s | %.0f | %d | %.2f | %.2f |" % [kind, row["ms"], row["n"], float(row["ms"]) / maxf(float(row["n"]), 1.0), row["worst"]])
