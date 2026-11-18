## Measures M1.5 UI screen instantiation/first-frame push budgets, HUD frame time, and 1x/2x kit memory
## against tests/perf_ui_budget.json (docs/architecture/ui-style-and-feedback-spec.md sections 4.10, 11).
##
## Windowed (GPU or xvfb + Mesa in CI):
##   godot --path godot -s res://tools/ui/perf_ui.gd -- [--gpu-limits] [--cpu-scale=2.0] [--out=perf_ui.json] [--summary=summary.md]
## Headless: exercises every M1.5 screen push and checks memory budgets; GPU frame times are reported only.
extends SceneTree

const BUDGET := "res://tests/perf_ui_budget.json"
const APP_SCENE_PATH := "res://shell/app/app.tscn"
const SCREEN_IDS_PATH := "res://shell/screens/screen_ids.gd"
const FRAME := Vector2i(1920, 1080)
const MB := 1048576.0
const HUD_FRAMES := 30

var _gpu_limits := false
var _cpu_scale := 1.0
var _out := ""
var _summary := ""
var _budget_path := BUDGET
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

	var screen_rows: Array = []
	var cpu_worst := 0.0
	var frame_worst := 0.0
	for raw_name: Variant in screen_names:
		var sid := StringName(str(raw_name))
		var row := await _measure_screen(app, screen_ids, sid)
		screen_rows.append(row)
		cpu_worst = maxf(cpu_worst, float(row["cpu_ms"]))
		frame_worst = maxf(frame_worst, float(row["first_frame_ms"]))

	_r["screens"] = screen_rows
	_r["screen_push_cpu_worst_ms"] = cpu_worst
	_r["screen_push_worst_ms"] = frame_worst
	_r["hud_frame_worst_ms"] = await _measure_hud_frames(app)

	var session := root.get_node_or_null("Session")
	if session != null:
		session.call("end_game")
	root.remove_child(vp)
	vp.queue_free()
	await _wait_frames(3)

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


func _measure_hud_frames(app: Node) -> float:
	var ms := app.call("map_scene") as Node
	var session := root.get_node_or_null("Session")
	var g: Game = session.get("game") as Game if session != null else null
	if ms != null and g != null and g.map != null:
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
		if over and enforced:
			verdict = "FAIL"
			failed.append("%s %.2f > %.2f" % [key, value, limit])
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
	s += "| Screen | CPU ms | First-frame ms |\n|---|---|---|\n"
	for row: Dictionary in _r["screens"]:
		s += "| %s | %.2f | %.2f |\n" % [row["screen"], float(row["cpu_ms"]), float(row["first_frame_ms"])]
	s += "\nKit memory: 1x %.2f MB, 2x %.2f MB. HUD worst frame: %.2f ms.\n\n" % [
		float(_r["kit_1x_mb"]), float(_r["kit_2x_mb"]), float(_r["hud_frame_worst_ms"])
	]
	s += "| Limit | measured | limit | class | verdict |\n|---|---|---|---|---|\n" + limit_rows
	return s


func _wait_frames(n: int) -> void:
	for _i: int in range(n):
		await process_frame
