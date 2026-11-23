## The M8 windowed AI rows of tools/ui/perf_ui.gd (m8-build-spec.md section 8.1 and 8.2), split out like perf_ui_m7.gd. A game in a
## window (the App, the map, the HUD, the busy pill), reports measured after a warm season:
##   ai_frame_ms         the worst frame while the countries move (End season with the camera still), north Italy, seasons measured
##   ai_turn_wall_ms     the wall time from End season to the phases (the flow leaves RUNNING), the worst measured season
##   busy_pill_ms        one pill update (show_orders), the mean of BUSY_RUNS calls
## The replay and the report are off (their frames are not the AI's). The budget rows are north Italy's; the E3 rows (--ai-map,
## --ai-scenario, --ai-seasons) run the same measures on another game and print the table of 8.3 (their keys carry the prefix "e3_").
## The made-up Europe (--ai-map=fake or no scenario) is PerfFixture.europe_ai(0) started with Session.start_game in an empty App.
## Everything of the shell is reached through call() and get(): perf_ui compiles before the autoloads.
extends RefCounted

## North Italy: the seasons measured after one warm season.
const SEASONS := 3
const BUSY_RUNS := 30
const PILL_TOTAL := 12
## SeasonFlow.State values (the shell's classes compile after the autoloads, so the numbers stand for them here).
const STATE_IDLE := 0
const STATE_RUNNING := 1
const FRAMES_MAX := 60000
const WAIT_MAX := 1200
const FRAME := Vector2i(1920, 1080)
const NI_CLI := ["--new-game", "--country=GEN", "--seed=1480"]

var _tree: SceneTree = null
var _r: Dictionary = {}


func _init(tree: SceneTree, result: Dictionary) -> void:
	_tree = tree
	_r = result


func _frames(n: int) -> void:
	for _i: int in n:
		await _tree.process_frame


## North Italy's budget rows (ai_frame_ms, ai_turn_wall_ms, busy_pill_ms) in the App's own game.
func measure_budget(packed: PackedScene) -> int:
	return await _measure(packed, PackedStringArray(NI_CLI), null, "", SEASONS)


## The E3 rows: `scenario` (a scenario id of data/scenarios) or the made-up Europe (`fake`, a watched game of 60 seats).
func measure_e3(packed: PackedScene, scenario: String, seasons: int) -> int:
	if scenario == "" or scenario == "fake":
		var europe := PerfFixture.europe_ai(0)
		if europe == null:
			printerr("perf_ui: the made-up Europe cannot be made")
			return 1
		return await _measure(packed, PackedStringArray(["--sandbox", "--seed=1480"]), europe, "e3_", seasons)
	return await _measure(packed, PackedStringArray(["--new-game", "--scenario=%s" % scenario, "--seed=1480"]), null, "e3_", seasons)


## One App in a window: the game (`game` started through Session, or the App's own from `cli`), then `seasons` measured seasons
## after a warm one. Writes prefix + the three rows. Returns 0, or 1 when the App does not come up.
func _measure(packed: PackedScene, cli: PackedStringArray, game: Object, prefix: String, seasons: int) -> int:
	var vp := SubViewport.new()
	vp.size = FRAME
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_tree.root.add_child(vp)
	var app := packed.instantiate()
	app.set("settings_path", "")
	app.set("allow_tree_quit", false)
	app.set("pause_tree_when_modal", false)
	app.set("skip_loading_frames", true)
	app.set("cli_args_override", cli)
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", true)  # as in play (the default; perf_ui.gd's M3 rows): with it off the season's TileSet loads in the end frame, 260 to 430 ms
	s.set_value("accessibility/reduce_motion", true)
	s.set_value("game/season_report", "off")
	s.set_value("game/movement", "off")  # the replay is not the AI's turn: its frames are left out
	s.set_value("game/autosave", "off")
	s.set_value("display/background_fps", 0)
	app.call("set_settings_override", s)
	vp.add_child(app)
	await _frames(3)
	var session := _tree.root.get_node_or_null("Session")
	if game != null and session != null:
		session.call("start_game", game)
	var waited := 0
	while (app.call("map_scene") == null or bool(app.call("is_starting"))) and waited < WAIT_MAX:
		await _frames(1)
		waited += 1
	await _frames(3)
	if app.call("map_scene") == null:
		printerr("perf_ui: the game does not come up in a window (%s)" % prefix)
		_close(app, vp, session)
		return 1
	var flow := (app.call("requests") as Object).get("flow") as Object
	var frame_worst := 0.0
	var frame_sum := 0.0
	var frame_n := 0
	var wall_worst := 0.0
	var wall_sum := 0.0
	var seasons_done := 0
	for season: int in seasons + 1:
		var measured := season > 0  # the first season is warm: the country caches fill
		await _wait_idle(flow)
		var t0 := Time.get_ticks_usec()
		if not bool(flow.call("request_end", false)):
			printerr("perf_ui: End season refused (%s)" % prefix)
			break
		var frames := 0
		while int(flow.call("state")) == STATE_RUNNING and frames < FRAMES_MAX:
			var f0 := Time.get_ticks_usec()
			await _tree.process_frame
			var ms := float(Time.get_ticks_usec() - f0) / 1000.0
			frames += 1
			if measured:
				frame_worst = maxf(frame_worst, ms)
				frame_sum += ms
				frame_n += 1
		var wall := float(Time.get_ticks_usec() - t0) / 1000.0
		if measured:
			wall_worst = maxf(wall_worst, wall)
			wall_sum += wall
			seasons_done += 1
	var pill := (app.call("hud") as Object).call("busy_pill") as Object
	var p0 := Time.get_ticks_usec()
	for i: int in BUSY_RUNS:
		pill.call("show_orders", i % PILL_TOTAL, PILL_TOTAL)
	var pill_ms := float(Time.get_ticks_usec() - p0) / 1000.0 / BUSY_RUNS
	_r[prefix + "ai_frame_ms"] = frame_worst
	_r[prefix + "ai_frame_mean_ms"] = frame_sum / maxf(frame_n, 1)
	_r[prefix + "ai_turn_wall_ms"] = wall_worst
	_r[prefix + "ai_turn_wall_mean_ms"] = wall_sum / maxf(seasons_done, 1)
	_r[prefix + "ai_seasons_measured"] = seasons_done
	_r[prefix + "busy_pill_ms"] = pill_ms
	_close(app, vp, session)
	return 0


## Waits for the flow to be idle and the guard to pass (a season may be ended once per guard window).
func _wait_idle(flow: Object) -> void:
	var waited := 0
	while (int(flow.call("state")) != STATE_IDLE or Time.get_ticks_msec() < int(flow.get("guard_until"))) and waited < WAIT_MAX * 10:
		await _frames(1)
		waited += 1


func _close(_app: Node, vp: SubViewport, session: Node) -> void:
	if session != null:
		session.call("end_game")
	_tree.root.remove_child(vp)
	vp.queue_free()
