## Measures M1.5 UI screen instantiation/first-frame push budgets, HUD frame time, and 1x/2x kit memory
## against tests/perf_ui_budget.json (docs/architecture/ui-style-and-feedback-spec.md sections 4.10, 11).
## M2 (m2-build-spec.md section 10): the worst frame with the minimap in a country game and with the country pick open,
## each inside the same 16 ms as the HUD frame.
##
## M3 (m3-build-spec.md section 8): the season report's push, the Save and Load screen's push with 12 rows and the log
## opening, each inside 16 ms; 16 live ribbons under 1 ms a frame; the season fade's capture frame under 50 ms (gpu class,
## enforced with --gpu-limits). The M3 rows run in a country game on a temporary save folder and lock.
##
## M4 (m4-build-spec.md section 8): the works card's push and the study's push inside 16 ms each, the chips' refresh inside 1 ms,
## the map marks' show inside 2 ms (see _measure_m4).
##
## M4.5 (m4-5-build-spec.md section 8; the rows are in perf_ui_m45.gd): the five study pages cold, on the made-up Europe and
## between tabs, the Yields switch and its update, the table's 100 rows, the timeline's draw and the legend's show (see
## _measure_m45). The Europe game takes minutes: it is skipped headless unless --europe-seasons=N is given.
##
## Windowed (GPU or xvfb + Mesa in CI):
##   godot --path godot -s res://tools/ui/perf_ui.gd -- [--gpu-limits] [--cpu-scale=2.0] [--out=perf_ui.json] [--summary=summary.md] [--europe-seasons=N]
## Headless: exercises every M1.5 screen push and checks memory budgets; GPU frame times are reported only.
extends SceneTree

const M45 := preload("res://tools/ui/perf_ui_m45.gd")
const M5 := preload("res://tools/ui/perf_ui_m5.gd")
const M6 := preload("res://tools/ui/perf_ui_m6.gd")
const M7 := preload("res://tools/ui/perf_ui_m7.gd")
const M8 := preload("res://tools/ui/perf_ui_m8.gd")
const TILE := preload("res://tools/ui/perf_ui_tile.gd")
const BUDGET := "res://tests/perf_ui_budget.json"
const APP_SCENE_PATH := "res://shell/app/app.tscn"
const SCREEN_IDS_PATH := "res://shell/screens/screen_ids.gd"
const FRAME := Vector2i(1920, 1080)
const MB := 1048576.0
const HUD_FRAMES := 30
const M3_SAVE_DIR := "user://perf_ui_saves"
const M3_LOCK := "user://perf_ui_running.lock"
const RIBBONS := 16
const RIBBON_FRAMES := 30
const M4_VINEYARD := Vector2i(7, 12)
const M4_PUSH_RUNS := 3
const M4_REFRESH_RUNS := 30

var _gpu_limits := false
var _cpu_scale := 1.0
var _out := ""
var _summary := ""
var _budget_path := BUDGET
var _europe_seasons := -1
## M8 (perf_ui_m8.gd): --ai-map and --ai-scenario run the windowed AI rows on that game alone (the E3 table), --ai-seasons how many.
var _ai_map := ""
var _ai_scenario := ""
var _ai_seasons := -1
var _r: Dictionary = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--gpu-limits":
			_gpu_limits = true
		elif arg.begins_with("--cpu-scale="):
			_cpu_scale = float(arg.substr(12))
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--summary="):
			_summary = arg.substr(10)
		elif arg.begins_with("--europe-seasons="):
			_europe_seasons = int(arg.substr(17))
		elif arg.begins_with("--ai-map="):
			_ai_map = arg.substr(9)
		elif arg.begins_with("--ai-scenario="):
			_ai_scenario = arg.substr(14)
		elif arg.begins_with("--ai-seasons="):
			_ai_seasons = int(arg.substr(13))
		elif arg.begins_with("--budget="):
			_budget_path = arg.substr(9)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(FRAME)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	_run()


func _run() -> void:
	await process_frame
	var code := await _measure()
	quit(code)


func _measure() -> int:
	var headless := DisplayServer.get_name() == "headless"
	_r["headless"] = headless
	_r["renderer"] = "%s / %s / %s" % [
		DisplayServer.get_name(),
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(),
	]

	_measure_kit_memory()

	var budget := _read_budget()
	var screen_names: Array = budget.get("screens", [
		"main_menu", "sandbox", "credits", "pause_menu", "options", "about", "help", "confirm", "loading"
	])

	var packed := ResourceLoader.load(APP_SCENE_PATH) as PackedScene
	if packed == null:
		printerr("perf_ui: cannot load %s" % APP_SCENE_PATH)
		return 1
	var screen_ids := ResourceLoader.load(SCREEN_IDS_PATH) as GDScript
	if screen_ids == null:
		printerr("perf_ui: cannot load %s" % SCREEN_IDS_PATH)
		return 1

	if _ai_map != "" or _ai_scenario != "":
		# The E3 rows alone: the AI's windowed rows on the given game (the made-up Europe when no scenario is given).
		var seasons := _ai_seasons if _ai_seasons > 0 else 2
		var code := await M8.new(self, _r).measure_e3(packed, _ai_scenario, seasons)
		if code == 0:
			print("E3 windowed rows (map %s, scenario %s, %d measured seasons, 60 frames a second):" % [
				_ai_map if _ai_map != "" else "fake", _ai_scenario if _ai_scenario != "" else "fake", int(_r["e3_ai_seasons_measured"])])
			print("  ai_turn_wall_ms  worst %.0f ms, mean %.0f ms   (8.3 limit 10000 ms)" % [float(_r["e3_ai_turn_wall_ms"]), float(_r["e3_ai_turn_wall_mean_ms"])])
			print("  ai_frame_ms      worst %.2f ms, mean %.2f ms   (8.3 limits 24 worst, 16 mean)" % [float(_r["e3_ai_frame_ms"]), float(_r["e3_ai_frame_mean_ms"])])
			print("  busy_pill_ms     %.4f ms a pill update" % float(_r["e3_busy_pill_ms"]))
		return code

	var vp := SubViewport.new()
	vp.size = FRAME
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var app := packed.instantiate()
	app.set("settings_path", "")
	app.set("allow_tree_quit", false)
	app.set("pause_tree_when_modal", false)
	app.set("skip_loading_frames", true)
	app.set("cli_args_override", PackedStringArray(["--sandbox", "--seed=1480"]))
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("accessibility/reduce_motion", true)
	app.call("set_settings_override", s)
	vp.add_child(app)
	await _wait_frames(3)

	# Each screen is pushed twice: the first push is cold (its scene is read, shared resources are built), the second is what
	# a player feels from then on. The 16 ms budget is the warm one; the cold one has its own, looser limit (a hitch).
	var screen_rows: Array = []
	var cpu_worst := 0.0
	var cold_worst := 0.0
	var warm_worst := 0.0
	for raw_name: Variant in screen_names:
		var sid := StringName(str(raw_name))
		var row := await _measure_screen(app, screen_ids, sid)
		var warm := await _measure_screen(app, screen_ids, sid)
		row["warm_cpu_ms"] = float(warm["cpu_ms"])
		row["warm_first_frame_ms"] = float(warm["first_frame_ms"])
		screen_rows.append(row)
		cpu_worst = maxf(cpu_worst, float(row["cpu_ms"]))
		cold_worst = maxf(cold_worst, float(row["first_frame_ms"]))
		warm_worst = maxf(warm_worst, float(warm["first_frame_ms"]))

	_r["screens"] = screen_rows
	_r["screen_push_cpu_worst_ms"] = cpu_worst
	_r["screen_push_cold_worst_ms"] = cold_worst
	_r["screen_push_worst_ms"] = warm_worst
	_r["hud_frame_worst_ms"] = await _measure_hud_frames(app)

	var session := root.get_node_or_null("Session")
	if session != null:
		session.call("end_game")
	root.remove_child(vp)
	vp.queue_free()
	await _wait_frames(3)

	# M2: each in its own app, after the sandbox above has gone (one Session game at a time).
	_r["minimap_frame_worst_ms"] = await _measure_cli_frames(
		packed, PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"]), true)
	_r["pick_frame_worst_ms"] = await _measure_cli_frames(
		packed, PackedStringArray(["--new-game", "--seed=1480"]), false)

	await _measure_m3(packed, headless)
	await _measure_m4(packed)
	await _measure_m45(packed, headless)
	await M8.new(self, _r).measure_budget(packed)

	return _finish(budget, headless)


func _measure_kit_memory() -> void:
	var doc_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string(KitTheme.KIT_JSON))
	var kit_1x_bytes := 0
	var kit_2x_bytes := 0
	if typeof(doc_variant) == TYPE_DICTIONARY:
		var doc := doc_variant as Dictionary
		var bytes_dict: Dictionary = doc.get("bytes_rgba", {})
		kit_1x_bytes = int(bytes_dict.get("kit_1x", 0))
		kit_2x_bytes = int(bytes_dict.get("kit_2x", 0))
	var theme_1x := KitTheme.load_for(1.0, &"1x", false)
	var theme_2x := KitTheme.load_for(2.0, &"2x", false)
	_r["kit_1x_theme_ok"] = theme_1x != null
	_r["kit_2x_theme_ok"] = theme_2x != null
	_r["kit_1x_mb"] = float(kit_1x_bytes) / MB
	_r["kit_2x_mb"] = float(kit_2x_bytes) / MB


func _measure_screen(app: Node, screen_ids: GDScript, sid: StringName) -> Dictionary:
	var stack := app.call("stack") as Control
	stack.call("clear")
	await _wait_frames(1)

	var t0 := Time.get_ticks_usec()
	var screen := screen_ids.call("make", sid) as Node
	if screen != null:
		if sid == &"confirm":
			screen.call("configure", {"title": "Confirm", "body": "Perf probe check"})
		stack.call("push", screen)
	var cpu_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	await process_frame
	var first_frame_ms := float(Time.get_ticks_usec() - t0) / 1000.0

	stack.call("clear")
	await _wait_frames(1)
	return {
		"screen": String(sid),
		"cpu_ms": cpu_ms,
		"first_frame_ms": first_frame_ms,
	}


func _measure_hud_frames(app: Node, select: bool = true) -> float:
	var ms := app.call("map_scene") as Node
	var session := root.get_node_or_null("Session")
	var g: Game = session.get("game") as Game if session != null else null
	if select and ms != null and g != null and g.map != null:
		for i: int in g.map.hex_count():
			if g.map.land[i] == 1:
				ms.call("select_hex", g.map.hex_of(i))
				break
	await _wait_frames(3)
	var worst := 0.0
	var last := Time.get_ticks_usec()
	for _i: int in range(HUD_FRAMES):
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
	return worst


## One app started by `cli` (a New game), its HUD frames measured with `select` (a hex picked); returns the worst frame.
func _measure_cli_frames(packed: PackedScene, cli: PackedStringArray, select: bool) -> float:
	var vp := SubViewport.new()
	vp.size = FRAME
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var app := packed.instantiate()
	app.set("settings_path", "")
	app.set("allow_tree_quit", false)
	app.set("pause_tree_when_modal", false)
	app.set("skip_loading_frames", true)
	app.set("cli_args_override", cli)
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("accessibility/reduce_motion", true)
	s.set_value("map/minimap", true)
	app.call("set_settings_override", s)
	vp.add_child(app)
	await _wait_frames(3)

	var worst := await _measure_hud_frames(app, select)

	var session := root.get_node_or_null("Session")
	if session != null:
		session.call("end_game")
	root.remove_child(vp)
	vp.queue_free()
	await _wait_frames(3)
	return worst


## M3: one country game (Genoa) on a temporary save folder; fills `report_push_ms`, `save_load_push_ms`, `log_open_ms`,
## `ribbons_16_frame_ms` and `season_fade_capture_ms` (0 headless: there is no picture to capture).
func _measure_m3(packed: PackedScene, headless: bool) -> void:
	var session := root.get_node("Session")
	var old_dir := str(session.get("save_dir"))
	var old_lock := RunLock.path
	session.set("save_dir", M3_SAVE_DIR)
	RunLock.path = M3_LOCK
	_clean_m3_disk()

	var vp := SubViewport.new()
	vp.size = FRAME
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var app := packed.instantiate()
	app.set("settings_path", "")
	app.set("allow_tree_quit", false)
	app.set("pause_tree_when_modal", false)
	app.set("skip_loading_frames", true)
	app.set("cli_args_override", PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"]))
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("accessibility/reduce_motion", true)
	s.set_value("game/autosave", "off")
	s.set_value("graphics/preload_next_season", true)  # as in play: the next season's pictures load in the background
	app.call("set_settings_override", s)
	vp.add_child(app)
	await _wait_frames(5)

	var stack := app.call("stack") as Control
	var hud_node := app.call("hud") as Node
	var ms := app.call("map_scene") as Node
	var g: Game = session.get("game") as Game
	var screen_ids := ResourceLoader.load(SCREEN_IDS_PATH) as GDScript
	if g == null or ms == null or hud_node == null or stack == null or screen_ids == null or g.player == &"":
		printerr("perf_ui: the M3 country game did not start")
		_r["report_push_ms"] = INF
		_r["save_load_push_ms"] = INF
		_r["log_open_ms"] = INF
		_r["ribbons_16_frame_ms"] = INF
		_r["season_fade_capture_ms"] = INF
	else:
		var focus := CountryCard.of(g, g.player)["focus"] as Vector2i
		var report_args := {"summary": ReportSample.genoa_spring()}
		_r["report_push_cold_ms"] = await _push_ms(stack, screen_ids, &"season_report", report_args)
		_r["report_push_ms"] = await _push_ms(stack, screen_ids, &"season_report", report_args)
		_r["save_load_push_ms"] = await _measure_save_load(session, g, stack, screen_ids)
		_r["log_open_ms"] = await _measure_log_open(session, g, hud_node, focus)
		_r["ribbons_16_frame_ms"] = await _measure_ribbons(ms, g, focus)
		var fade := await _measure_fade(ms, g, s, headless)
		_r["season_fade_capture_ms"] = fade["warm"]
		_r["season_fade_capture_cold_ms"] = fade["cold"]
		_r["season_fade_total_ms"] = fade["total"]

	session.call("end_game")
	root.remove_child(vp)
	vp.queue_free()
	await _wait_frames(3)
	_clean_m3_disk()
	session.set("save_dir", old_dir)
	RunLock.path = old_lock


## M4 (m4-build-spec.md section 8): the works card's push and the study's push, each inside 16 ms (the call, then one forced draw:
## never a vsync frame, never frame_post_draw: the project runs in low-processor mode); the chips' refresh inside 1 ms and the
## map marks' show inside 2 ms (the call alone). One country game (Genoa) on a temporary save folder; fills
## `works_card_push_ms`, `study_push_ms`, `chips_refresh_ms` and `marks_show_ms`. Headless the same calls run (the draw is the
## dummy renderer's) and the gpu rows are reported only.
func _measure_m4(packed: PackedScene) -> void:
	var session := root.get_node("Session")
	var old_dir := str(session.get("save_dir"))
	var old_lock := RunLock.path
	session.set("save_dir", M3_SAVE_DIR)
	RunLock.path = M3_LOCK
	_clean_m3_disk()

	var vp := SubViewport.new()
	vp.size = FRAME
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var app := packed.instantiate()
	app.set("settings_path", "")
	app.set("allow_tree_quit", false)
	app.set("pause_tree_when_modal", false)
	app.set("skip_loading_frames", true)
	app.set("cli_args_override", PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"]))
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("accessibility/reduce_motion", true)
	s.set_value("game/autosave", "off")
	app.call("set_settings_override", s)
	vp.add_child(app)
	await _wait_frames(5)

	var g: Game = session.get("game") as Game
	var ms := app.call("map_scene") as Node
	var hud_node := app.call("hud") as Node
	var requests := app.call("requests") as Object
	var works: Object = requests.get("works") if requests != null else null
	var row := _m4_upgrade_row(g, M4_VINEYARD) if g != null and g.has_countries() and g.player != &"" else {}
	if g == null or ms == null or hud_node == null or works == null or row.is_empty():
		printerr("perf_ui: the M4 country game did not start")
		_r["works_card_push_ms"] = INF
		_r["study_push_ms"] = INF
		_r["chips_refresh_ms"] = INF
		_r["marks_show_ms"] = INF
	else:
		var option := {"action": row["action"], "family": row["family"]}
		var view_node := ms.call("view") as Node
		ms.call("frame_at", view_node.call("centre_of", M4_VINEYARD), 1.0)
		ms.call("select_hex", M4_VINEYARD)
		await _wait_frames(4)
		var open_card := func() -> void: works.call("show_card", M4_VINEYARD, option, true)
		var close_card := func() -> void: works.call("close_card")
		var open_study := func() -> void: works.call("open_study", &"economy")
		var close_study := func() -> void: works.call("close_study")
		_r["works_card_push_cold_ms"] = await _m4_push_ms(open_card, close_card)
		var warm := 0.0
		for _i: int in M4_PUSH_RUNS:
			warm = maxf(warm, await _m4_push_ms(open_card, close_card))
		_r["works_card_push_ms"] = warm
		_r["study_push_cold_ms"] = await _m4_push_ms(open_study, close_study)
		warm = 0.0
		for _i: int in M4_PUSH_RUNS:
			warm = maxf(warm, await _m4_push_ms(open_study, close_study))
		_r["study_push_ms"] = warm

		var chips := hud_node.call("chips") as Node
		chips.call("refresh")
		var total := 0.0
		for _i: int in M4_REFRESH_RUNS:
			var t0 := Time.get_ticks_usec()
			chips.call("refresh")
			total += float(Time.get_ticks_usec() - t0) / 1000.0
		_r["chips_refresh_ms"] = total / float(M4_REFRESH_RUNS)

		works.call("show_card", M4_VINEYARD, option, true)
		await _wait_frames(3)
		var card := (app.call("stack") as Control).call("top") as Node
		if card == null or not card.has_method("preview"):
			_r["marks_show_ms"] = INF
		else:
			var preview := card.call("preview") as Dictionary
			ms.call("show_preview", preview)
			total = 0.0
			for _i: int in M4_REFRESH_RUNS:
				var t1 := Time.get_ticks_usec()
				ms.call("show_preview", preview)
				total += float(Time.get_ticks_usec() - t1) / 1000.0
			_r["marks_show_ms"] = total / float(M4_REFRESH_RUNS)
			_r["marks_shown"] = bool((ms.call("preview_marks") as Object).call("shown"))
		works.call("close_card")

	session.call("end_game")
	root.remove_child(vp)
	vp.queue_free()
	await _wait_frames(3)
	_clean_m3_disk()
	session.set("save_dir", old_dir)
	RunLock.path = old_lock


## M4.5 (m4-5-build-spec.md section 8): one country game (Genoa) on a temporary save folder, played 40 seasons; the rows are
## measured by perf_ui_m45.gd (the pages cold, between tabs and on the made-up Europe, the Yields switch and update, the
## table's rows, the timeline's draw, the legend's show).
func _measure_m45(packed: PackedScene, headless: bool) -> void:
	var session := root.get_node("Session")
	var old_dir := str(session.get("save_dir"))
	var old_lock := RunLock.path
	session.set("save_dir", M3_SAVE_DIR)
	RunLock.path = M3_LOCK
	_clean_m3_disk()

	var vp := SubViewport.new()
	vp.size = FRAME
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var app := packed.instantiate()
	app.set("settings_path", "")
	app.set("allow_tree_quit", false)
	app.set("pause_tree_when_modal", false)
	app.set("skip_loading_frames", true)
	app.set("cli_args_override", PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"]))
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("accessibility/reduce_motion", true)
	s.set_value("game/autosave", "off")
	app.call("set_settings_override", s)
	vp.add_child(app)
	await _wait_frames(5)
	await M45.new(self, _r).measure(app, vp, headless, _europe_seasons)
	await M5.new(self, _r).measure(app, vp)  # M5 (perf_ui_m5.gd): the People page cold and key 5, on the same game
	await M6.new(self, _r).measure(app, vp)  # M6 (perf_ui_m6.gd): the armies' panel, tokens, route, replay, Supply, Military page
	await M7.new(self, _r).measure(app)  # M7 (perf_ui_m7.gd): the battle dock, the war marks, the odds card, the hex menu, the castle areas
	await TILE.new(self, _r).measure(app, ResourceLoader.load(SCREEN_IDS_PATH) as GDScript)  # TW18 (perf_ui_tile.gd): the tile window rows

	session.call("end_game")
	root.remove_child(vp)
	vp.queue_free()
	await _wait_frames(3)
	_clean_m3_disk()
	session.set("save_dir", old_dir)
	RunLock.path = old_lock


## One push, in ms: `open` runs, then one forced draw (RenderingServer.force_draw: the project is in low-processor mode, so no
## frame is waited for); `close` runs after and two frames pass.
func _m4_push_ms(open: Callable, close: Callable) -> float:
	var t0 := Time.get_ticks_usec()
	open.call()
	RenderingServer.force_draw(false)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	close.call()
	await _wait_frames(2)
	return ms


## The row U acts on (WorksFlow.upgrade_row, which this script cannot name: it compiles before the autoloads).
func _m4_upgrade_row(g: Game, hex: Vector2i) -> Dictionary:
	var rows := ImprovePreview.options_of(g, g.player, hex)
	for row: Dictionary in rows:
		if StringName(str(row["action"])) == Works.UPGRADE:
			return row
	for row: Dictionary in rows:
		if StringName(str(row["action"])) == Works.BUILD and bool((row["verdict"] as Dictionary)["ok"]):
			return row
	return {}


func _clean_m3_disk() -> void:
	var dir := DirAccess.open(M3_SAVE_DIR)
	if dir != null:
		for file: String in dir.get_files():
			DirAccess.remove_absolute(M3_SAVE_DIR.path_join(file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(M3_SAVE_DIR))
	RunLock.clear()


## Cold make + push + the first drawn frame of a screen, in ms; the stack is cleared before and after.
func _push_ms(stack: Control, screen_ids: GDScript, sid: StringName, extra: Dictionary = {}) -> float:
	stack.call("clear")
	await _wait_frames(1)
	var t0 := Time.get_ticks_usec()
	var screen := screen_ids.call("make", sid) as Node
	if screen != null:
		if extra.has("summary"):
			screen.call("show_summary", extra["summary"], false)
		if extra.has("tab"):
			screen.set("start_tab", extra["tab"])
		stack.call("push", screen)
	await process_frame
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	stack.call("clear")
	await _wait_frames(1)
	return ms


## Save and Load with 12 rows (the quick slot, the eight numbered ones and the three autosaves, every one a real save).
func _measure_save_load(session: Node, g: Game, stack: Control, screen_ids: GDScript) -> float:
	var slots: Array[String] = []
	slots.append_array(SaveFile.SLOTS)
	slots.append_array(SaveFile.AUTO_SLOTS)
	for slot: String in slots:
		session.call("save_game", slot, null, {}, "")
	var worst := 0.0
	_r["save_load_push_cold_ms"] = await _push_ms(stack, screen_ids, &"save_load", {"tab": &"save"})
	for tab: StringName in [&"save", &"load"]:
		worst = maxf(worst, await _push_ms(stack, screen_ids, &"save_load", {"tab": tab}))
	_r["save_load_rows"] = slots.size()
	return worst


## Two seasons of works make log lines; the card opens and draws once.
func _measure_log_open(session: Node, g: Game, hud_node: Node, focus: Vector2i) -> float:
	for _i: int in 2:
		_begin_works(session, g, 2, focus)
		session.call("end_season")
	await _wait_frames(2)
	var log_card := hud_node.call("action_log") as Node
	var t0 := Time.get_ticks_usec()
	log_card.call("open")
	await process_frame
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	log_card.call("close")
	await _wait_frames(1)
	return ms


## The mean CPU time of Floaters.advance with 16 live ribbons, over RIBBON_FRAMES frames.
func _measure_ribbons(ms: Node, g: Game, focus: Vector2i) -> float:
	var view_node := ms.call("view") as Node
	ms.call("frame_at", view_node.call("centre_of", focus), 1.0)
	await _wait_frames(3)
	var floaters := ms.get_node_or_null("Names/Floaters")
	if floaters == null:
		return INF
	var hexes: Array[Vector2i] = []
	for dy: int in range(-4, 5):
		for dx: int in range(-4, 5):
			var hex := focus + Vector2i(dx, dy)
			if g.map.has(hex) and g.map.land[g.map.index_of(hex)] == 1:
				hexes.append(hex)
	var total := 0.0
	for _i: int in RIBBON_FRAMES:
		var at := 0
		while int(floaters.call("live_count")) < RIBBONS and at < hexes.size() * 3:
			floaters.call("spawn", "Begun", &"plain", hexes[at % hexes.size()])
			at += 1
		var t0 := Time.get_ticks_usec()
		floaters.call("advance", 0.016)
		total += float(Time.get_ticks_usec() - t0) / 1000.0
		await process_frame
	_r["ribbons_live"] = int(floaters.call("live_count"))
	return total / float(RIBBON_FRAMES)


## The season fade, split in two. The capture (the forced draw, the read of the picture, its texture) is five runs on the real
## map: the first is cold, the worst of the other four is the row. The swap (show_season with the next season preloaded, as in
## play) is measured whole and reported apart: it is the TileSet swap, which the map does a slice a frame. Nothing runs headless
## (there is no picture): 0 is returned.
func _measure_fade(ms: Node, g: Game, s: Settings, headless: bool) -> Dictionary:
	var out := {"cold": 0.0, "warm": 0.0, "total": 0.0}
	if headless:
		return out
	s.set_value("accessibility/reduce_motion", false)
	var curtain := ms.call("season_fade") as Node
	curtain.set("reduce_motion", false)
	var next := (Calendar.season_of(g.turn) + 1) % 4
	var next_name: String = TilesetBuilder.SEASONS[next]
	var waited := 0
	while not TilesetBuilder.is_loaded(next_name, false) and waited < 600:
		await _wait_frames(1)
		waited += 1
	for run: int in 5:
		var t0 := Time.get_ticks_usec()
		await curtain.call("capture")
		var cost := float(Time.get_ticks_usec() - t0) / 1000.0
		(curtain.get_node("Capture") as CanvasItem).visible = false
		await _wait_frames(2)
		if run == 0:
			out["cold"] = cost
		else:
			out["warm"] = maxf(float(out["warm"]), cost)
	var t1 := Time.get_ticks_usec()
	ms.call("show_season", next, true)
	await process_frame
	out["total"] = float(Time.get_ticks_usec() - t1) / 1000.0
	ms.call("finish_swap")
	return out


## Starts one work on each of `count` hexes the player owns, nearest to `near` first.
func _begin_works(session: Node, g: Game, count: int, near: Vector2i) -> void:
	var found: Array[Dictionary] = []
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 0 or Territory.owner_tag(g, hex) != g.player or not Improve.piece_at(g, hex).is_empty():
			continue
		for option: Dictionary in Improve.build_options(g, hex):
			var args := {"hex": hex, "family": int(option["family_id"])}
			if bool(option["ok"]) and bool((session.call("check", "build", args) as Dictionary)["ok"]):
				found.append({"args": args, "d": (hex - near).length_squared()})
				break
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["d"]) < int(b["d"]))
	for k: int in mini(count, found.size()):
		session.call("act", "build", found[k]["args"])


func _finish(budget: Dictionary, headless: bool) -> int:
	var limits: Dictionary = budget.get("limits", {})
	var failed: Array[String] = []
	var rows := ""
	for key: String in limits:
		var spec: Dictionary = limits[key]
		var value := float(_r.get(key, INF))
		var scale := _cpu_scale if str(spec["class"]) == "cpu" else 1.0
		var limit := float(spec["limit"]) * scale
		var kind := str(spec["class"])
		var over := value > limit
		var enforced := (kind == "mem") or (not headless and (kind != "gpu" or _gpu_limits))
		var verdict := "ok"
		var known: Dictionary = spec.get("known_over", {})  # an open issue: printed and listed, not a failure
		if over and enforced and known.is_empty():
			verdict = "FAIL"
			failed.append("%s %.2f > %.2f" % [key, value, limit])
		elif over and not known.is_empty():
			verdict = "KNOWN OVER (issue #%d)" % int(known.get("issue", 0))
		elif over:
			verdict = "over (not enforced in %s)" % ("headless" if headless else "no --gpu-limits")
		rows += "| %s | %.2f | %.2f | %s | %s |\n" % [key, value, limit, kind, verdict]

	var text := _markdown(rows, headless)
	print(text)
	_r["failed"] = failed

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
		print("perf_ui: within the limits")
		return 0
	printerr("perf_ui: over the limits: %s" % ", ".join(failed))
	return 1


func _read_budget() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_budget_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("perf_ui: %s does not read" % _budget_path)
		return {}
	return parsed as Dictionary


func _markdown(limit_rows: String, headless: bool) -> String:
	var s := "## UI speed & memory (%s)\n\n" % ("headless" if headless else "windowed")
	s += "Renderer: %s.\n\n" % str(_r["renderer"])
	s += "| Screen | cold CPU ms | cold first-frame ms | warm CPU ms | warm first-frame ms |\n|---|---|---|---|---|\n"
	for row: Dictionary in _r["screens"]:
		s += "| %s | %.2f | %.2f | %.2f | %.2f |\n" % [
			row["screen"], float(row["cpu_ms"]), float(row["first_frame_ms"]),
			float(row.get("warm_cpu_ms", 0.0)), float(row.get("warm_first_frame_ms", 0.0)),
		]
	s += "\nKit memory: 1x %.2f MB, 2x %.2f MB. HUD worst frame: %.2f ms.\n" % [
		float(_r["kit_1x_mb"]), float(_r["kit_2x_mb"]), float(_r["hud_frame_worst_ms"])
	]
	s += "M3 (warm; cold in brackets): report push %.2f ms [%.2f], Save and Load (%d rows) %.2f ms [%.2f], log opening %.2f ms, 16 ribbons %.3f ms a frame.\n" % [
		float(_r.get("report_push_ms", 0.0)), float(_r.get("report_push_cold_ms", 0.0)), int(_r.get("save_load_rows", 0)),
		float(_r.get("save_load_push_ms", 0.0)), float(_r.get("save_load_push_cold_ms", 0.0)),
		float(_r.get("log_open_ms", 0.0)), float(_r.get("ribbons_16_frame_ms", 0.0)),
	]
	s += "M4 (warm; cold in brackets): works card push %.2f ms [%.2f], study push %.2f ms [%.2f], chips refresh %.3f ms, marks show %.3f ms.\n" % [
		float(_r.get("works_card_push_ms", 0.0)), float(_r.get("works_card_push_cold_ms", 0.0)),
		float(_r.get("study_push_ms", 0.0)), float(_r.get("study_push_cold_ms", 0.0)),
		float(_r.get("chips_refresh_ms", 0.0)), float(_r.get("marks_show_ms", 0.0)),
	]
	s += "M4.5 (north Italy after %d seasons; first build in brackets): five pages cold %.2f ms [%.2f], warm %.2f ms; Europe %s; tab switch %.2f ms; Yields key 4 %.2f ms, update %.3f ms; table rows %.2f ms; timeline draw %.2f ms; legend show %.3f ms.
" % [
		int(_r.get("m45_turn", 1)) - 1, float(_r.get("study_open_cold_ms", 0.0)), float(_r.get("study_first_build_ms", 0.0)),
		float(_r.get("study_open_warm_ms", 0.0)),
		"skipped" if bool(_r.get("study_open_europe_skipped", false)) else "%.2f ms" % float(_r.get("study_open_europe_ms", 0.0)),
		float(_r.get("study_tab_switch_ms", 0.0)), float(_r.get("yields_mode_ms", 0.0)), float(_r.get("yields_update_ms", 0.0)),
		float(_r.get("study_table_rows_ms", 0.0)), float(_r.get("timeline_draw_ms", 0.0)), float(_r.get("legend_show_ms", 0.0)),
	]
	s += "M5: People page cold %.2f ms [first build %.2f], Food key 5 %.2f ms.
" % [
		float(_r.get("people_page_open_ms", 0.0)), float(_r.get("people_page_first_build_ms", 0.0)), float(_r.get("food_mode_ms", 0.0)),
	]
	s += "Season fade: capture warm %.2f ms (cold %.2f), whole show_season with the next season preloaded %.2f ms.\n\n" % [
		float(_r.get("season_fade_capture_ms", 0.0)), float(_r.get("season_fade_capture_cold_ms", 0.0)), float(_r.get("season_fade_total_ms", 0.0)),
	]
	s += "| Limit | measured | limit | class | verdict |\n|---|---|---|---|---|\n" + limit_rows
	return s


func _wait_frames(n: int) -> void:
	for _i: int in range(n):
		await process_frame
