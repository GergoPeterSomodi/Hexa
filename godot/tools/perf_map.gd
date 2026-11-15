## The map speed tool (docs/architecture/m1-build-spec.md section 9): builds the made-up Europe (FakeMap, 494 x 247 =
## 122,018 hexes), fills the tile stack with the full tileset (the committed tiles_<season>.tres) and measures what the
## budget names: the fill, the frame at each zoom while the camera pans, one build action, the season swaps, the
## chunk rebuild, memory. Prints the table and writes JSON; exits 1 when a limit of tests/perf_budget.json is passed.
##
## Windowed (a GPU, or Mesa's software renderer under xvfb in CI), sync off, 1920 x 1080:
##   godot --path godot -s res://tools/perf_map.gd -- [--gpu-limits] [--out=perf.json] [--summary=summary.md]
##         [--cols=494 --rows=247 --seed=1480] [--budget=res://tests/perf_budget.json] [--frames=240]
##         [--cpu-scale=2.0]
## Limits have a class (the budget file): cpu and mem always fail the run; gpu (frame times) only with --gpu-limits,
## because a CI runner has no GPU and its frame times say nothing about a player's PC. --cpu-scale multiplies the cpu
## limits (a CI runner is slower than the PC the limits were read on). Never run by GUT.
extends SceneTree

const BUDGET := "res://tests/perf_budget.json"
const FRAME := Vector2i(1920, 1080)
const ZOOMS: Array[float] = [2.0, 1.0, 0.5, 0.25, 0.12]
const FAR_ZOOMS: Array[float] = [0.12, 0.04]
const SETTLE := 20
const SWAPS: Array[String] = ["winter", "autumn", "spring", "summer"]
const BUILDS := 24
const MB := 1048576.0
const FILL_MS := 5.0  # what the map scene's loading takes of a frame (a little less than its SLICE_MS)

var _cols := 494
var _rows := 247
var _seed := 1480
var _timed := 240
var _gpu_limits := false
var _cpu_scale := 1.0
var _out := ""
var _summary := ""
var _budget_path := BUDGET
var _map: MapData = null
var _state: MapState = null
var _view: TileMapView = null
var _camera: Camera2D = null
var _far: Sprite2D = null
var _tiles: TilesetBuilder = null
var _r: Dictionary = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--gpu-limits":
			_gpu_limits = true
		elif arg.begins_with("--cpu-scale="):
			_cpu_scale = float(arg.substr(12))
		elif arg.begins_with("--cols="):
			_cols = int(arg.substr(7))
		elif arg.begins_with("--rows="):
			_rows = int(arg.substr(7))
		elif arg.begins_with("--seed="):
			_seed = int(arg.substr(7))
		elif arg.begins_with("--frames="):
			_timed = int(arg.substr(9))
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--summary="):
			_summary = arg.substr(10)
		elif arg.begins_with("--budget="):
			_budget_path = arg.substr(9)
	DisplayServer.window_set_size(FRAME)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_run()


func _run() -> void:
	await process_frame
	var code := await _measure()
	quit(code)


func _measure() -> int:
	_r["renderer"] = "%s / %s / %s" % [DisplayServer.get_name(), RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name()]
	_r["window"] = "%dx%d" % [root.size.x, root.size.y]
	var video_before := _video_mb()
	var t := Time.get_ticks_usec()
	_map = FakeMap.build(_cols, _rows, _seed)
	_state = MapState.create(_map)
	_r["map_build_ms"] = _ms_since(t)
	_r["hexes"] = _map.hex_count()
	_tiles = TilesetBuilder.load_season("summer")
	if _tiles.tile_set == null:
		printerr("perf_map: %s" % _tiles.error)
		return 1
	_view = TileMapView.new()
	root.add_child(_view)
	_view.setup(_tiles)
	_view.set_climates(_map.cols, _map.climate)
	_camera = Camera2D.new()
	root.add_child(_camera)
	_camera.make_current()
	await process_frame
	_r["video_mb_summer"] = _video_mb() - video_before
	await _fill()
	_chunk_lines()
	await _frame_times()
	await _builds()
	await _season_swaps(video_before)
	return _finish()


func _ms_since(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0


func _video_mb() -> float:
	return Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / MB


## The sliced fill as the map scene does it: FILL_MS of fill_for a frame, nearest the middle first. The CPU time is the
## time inside the slices; `fill_first_ms` is the time until the screen at zoom 0.5 (about 1,000 hexes) is in; the frame
## times while filling are the time from one frame to the next (the slice, what the engine builds after it, the drawing).
func _fill() -> void:
	var static_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var map := _map
	var state := _state
	var provider := func(hex: Vector2i, names: PackedStringArray) -> void: MapCells.fill_hex(map, state, hex, names)
	var wall := Time.get_ticks_usec()
	_view.begin_fill(_cols, _rows, provider, Vector2i(_cols >> 1, _rows >> 1), MapCells.LAYERS)
	_view.set_process(false)  # the slices are taken by hand here, so each is timed
	_camera.position = Vector2(float(_cols) * MapTiles.CELL.x, float(_rows) * MapTiles.ROW) * 0.5
	_camera.zoom = Vector2(0.5, 0.5)
	var screen := 1000.0 / float(_cols * _rows)
	var cpu := 0.0
	var slices := 0
	var first := -1.0
	var worst := 0.0
	var frame_worst := 0.0
	var last := Time.get_ticks_usec()
	while _view.is_filling():
		var s := Time.get_ticks_usec()
		_view.fill_for(FILL_MS)
		var one := _ms_since(s)
		worst = maxf(worst, one)
		cpu += one
		slices += 1
		if first < 0.0 and _view.fill_progress() >= screen:
			first = cpu
		await process_frame
		var now := Time.get_ticks_usec()
		if slices > 1:
			frame_worst = maxf(frame_worst, float(now - last) / 1000.0)
		last = now
	_r["fill_first_ms"] = maxf(first, 0.0)
	_r["fill_slice_worst_ms"] = worst
	_r["fill_frame_worst_ms"] = frame_worst
	_r["fill_all_ms"] = cpu
	_r["fill_wall_ms"] = _ms_since(wall)
	_r["fill_slices"] = slices
	_r["cells"] = _view.cell_count()
	_r["cells_static_mb"] = (Performance.get_monitor(Performance.MEMORY_STATIC) - static_before) / MB
	_r["static_mb_total"] = Performance.get_monitor(Performance.MEMORY_STATIC) / MB
	_r["missing_tiles"] = _view.missing_names().size()
	_r["missing_names"] = ", ".join(_view.missing_names())


## Every chunk's lines, as the scene would build them at start; then the rebuild of each chunk alone.
func _chunk_lines() -> void:
	var across := ceili(float(_cols) / EdgeLines.CHUNK)
	var down := ceili(float(_rows) / EdgeLines.CHUNK)
	var t := Time.get_ticks_usec()
	for cy: int in down:
		for cx: int in across:
			_view.set_chunk_lines(Vector2i(cx, cy), EdgeLines.for_chunk(_map, _state, Vector2i(cx, cy)))
	_r["chunks"] = across * down
	_r["chunk_lines_all_ms"] = _ms_since(t)
	var worst := 0.0
	var total := 0.0
	var count := 0
	for cy: int in down:
		for cx: int in across:
			var s := Time.get_ticks_usec()
			var lines := EdgeLines.for_chunk(_map, _state, Vector2i(cx, cy))
			_view.set_chunk_lines(Vector2i(cx, cy), lines)
			var one := _ms_since(s)
			worst = maxf(worst, one)
			total += one
			count += 1
	_r["chunk_rebuild_ms"] = worst
	_r["chunk_rebuild_mean_ms"] = total / float(maxi(count, 1))


## The frame time at each zoom while the camera pans, and the far picture.
func _frame_times() -> void:
	var rows: Array = []
	for zoom: float in ZOOMS:
		rows.append(await _pan(zoom, "tiles"))
	var t := Time.get_ticks_usec()
	var bytes := FarPicture.pixels(_map, _state)
	var size := FarPicture.size_of(_map)
	_r["far_build_ms"] = _ms_since(t)
	var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, bytes)
	_far = Sprite2D.new()
	_far.texture = ImageTexture.create_from_image(image)
	_far.centered = false
	_far.scale = Vector2(float(MapTiles.CELL.x) / float(FarPicture.PX.x), MapTiles.ROW / float(FarPicture.PX.y))
	root.add_child(_far)
	_view.visible = false
	for zoom: float in FAR_ZOOMS:
		rows.append(await _pan(zoom, "far picture"))
	_view.visible = true
	_far.queue_free()
	_r["frames"] = rows
	var worst := 0.0
	var mean := 0.0
	for row: Dictionary in rows:
		worst = maxf(worst, float(row["worst_ms"]))
		mean = maxf(mean, float(row["mean_ms"]))
	_r["frame_worst_ms"] = worst
	_r["frame_mean_ms"] = mean


func _pan(zoom: float, what: String) -> Dictionary:
	var size := Vector2(float(_cols) * MapTiles.CELL.x, float(_rows) * MapTiles.ROW)
	_camera.zoom = Vector2(zoom, zoom)
	for i: int in SETTLE:
		_camera.position = size * Vector2(0.3, 0.4)
		await process_frame
	var last := Time.get_ticks_usec()
	var worst := 0
	var start := last
	for i: int in _timed:
		var sweep := float(i) / float(_timed)
		_camera.position = size * Vector2(0.3 + 0.4 * sweep, 0.4 + 0.2 * sin(sweep * TAU))
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
	return {
		"what": what, "zoom": zoom,
		"hexes_on_screen": int((float(FRAME.x) / zoom / MapTiles.CELL.x) * (float(FRAME.y) / zoom / MapTiles.ROW)),
		"mean_ms": float(last - start) / 1000.0 / float(_timed), "worst_ms": float(worst) / 1000.0,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
	}


## Builds on made-up land hexes near the middle: the CPU part is MapCells.of_hex and set_tile for the touched hexes
## (what Events.hex_changed makes the scene do); the frame part runs on to the next frame.
func _builds() -> void:
	_camera.zoom = Vector2.ONE
	_camera.position = Vector2(float(_cols) * MapTiles.CELL.x, float(_rows) * MapTiles.ROW) * 0.5
	var cpu_worst := 0.0
	var cpu_total := 0.0
	var frame_worst := 0.0
	var done := 0
	var step := 0
	while done < BUILDS and step < 4000:
		step += 1
		var hex := Vector2i((_cols >> 1) + (step * 7) % 40 - 20, (_rows >> 1) + (step * 3) % 20 - 10)
		var i := _map.index_of(hex)
		if i < 0 or _map.land[i] == 0 or _state.main_use[i] != 0:
			continue
		_state.main_use[i] = ImproveRules.SETTLEMENT
		_state.level[i] = 1
		var t := Time.get_ticks_usec()
		for h: Vector2i in MapCells.touched_by(_map, hex):
			_view.set_hex(h, MapCells.of_hex(_map, _state, h))
		var cpu := _ms_since(t)
		await process_frame
		var to_frame := _ms_since(t)
		cpu_worst = maxf(cpu_worst, cpu)
		cpu_total += cpu
		frame_worst = maxf(frame_worst, to_frame)
		done += 1
	_r["build_samples"] = done
	_r["build_action_ms"] = cpu_worst
	_r["build_action_mean_ms"] = cpu_total / float(maxi(done, 1))
	_r["build_to_frame_ms"] = frame_worst


## Swaps through the seasons, each requested ahead (the load is done before the swap, as the game does it), then the
## swap back to summer cold. As the scene does it: the screen at zoom 1 first (`cpu_ms`, the time until its chunks have
## the new TileSet), then the rest FILL_MS a frame; `to_frame_ms` is the first frame after the first step and
## `frame_worst_ms` the worst frame of the whole swap. The video memory is read once the old season's pictures are freed.
func _season_swaps(video_before: float) -> void:
	var swaps: Array = []
	var writes := _view.cell_writes
	var worst := 0.0
	var frame_worst_all := 0.0
	_camera.zoom = Vector2.ONE
	_camera.position = Vector2(float(_cols) * MapTiles.CELL.x, float(_rows) * MapTiles.ROW) * 0.5
	var middle := _view.hex_at(_camera.position)
	var half := Vector2i(int(float(FRAME.x) / MapTiles.CELL.x / 2.0) + 1, int(float(FRAME.y) / MapTiles.ROW / 2.0) + 1)
	var focus := Rect2i(middle - half, half * 2 + Vector2i.ONE)
	for season: String in SWAPS:
		var ahead := season != "summer"  # the last one (summer again) is cold: nobody asked for it
		if ahead:
			TilesetBuilder.request_season(season)
			var path := TilesetBuilder.tres_path(season)
			while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await process_frame
		var t := Time.get_ticks_usec()
		var next := TilesetBuilder.load_season(season)
		var load_ms := _ms_since(t)
		var started := Time.get_ticks_usec()
		_view.begin_season_swap(next, focus)
		_tiles = next
		while not _view.swap_focus_done() and _view.swap_step(FILL_MS):
			pass
		var cpu := _ms_since(started)
		await process_frame
		var to_frame := _ms_since(started)
		var frame_worst := to_frame
		var last := Time.get_ticks_usec()
		var rest_cpu := 0.0
		var frames := 0
		while _view.is_swapping():
			var r := Time.get_ticks_usec()
			_view.swap_step(FILL_MS)
			rest_cpu += _ms_since(r)
			await process_frame
			var now := Time.get_ticks_usec()
			frame_worst = maxf(frame_worst, float(now - last) / 1000.0)
			last = now
			frames += 1
		await process_frame
		await process_frame
		frame_worst_all = maxf(frame_worst_all, frame_worst)
		swaps.append({"season": season, "ahead": ahead, "cpu_ms": cpu, "load_ms": load_ms, "to_frame_ms": to_frame,
			"rest_ms": rest_cpu, "rest_frames": frames, "frame_worst_ms": frame_worst,
			"video_mb": _video_mb() - video_before})
		if ahead:
			worst = maxf(worst, cpu + load_ms)
	_r["swaps"] = swaps
	_r["season_swap_ms"] = worst
	_r["season_swap_frame_worst_ms"] = frame_worst_all
	_r["season_swap_cell_writes"] = _view.cell_writes - writes
	var most := float(_r["video_mb_summer"])
	for row: Dictionary in swaps:
		most = maxf(most, float(row["video_mb"]))
	_r["video_mb_per_season"] = most


## The table, the JSON, the verdict.
func _finish() -> int:
	var budget := _read_budget()
	var limits: Dictionary = budget.get("limits", {})
	var failed: Array[String] = []
	var rows := ""
	for key: String in limits:
		var spec: Dictionary = limits[key]
		var value := float(_r.get(key, INF))
		var limit := float(spec["limit"]) * (_cpu_scale if str(spec["class"]) == "cpu" else 1.0)
		var kind := str(spec["class"])
		var over := value > limit
		var enforced := kind != "gpu" or _gpu_limits
		var verdict := "ok"
		if over and enforced:
			verdict = "FAIL"
			failed.append("%s %.2f > %.2f" % [key, value, limit])
		elif over:
			verdict = "over (gpu limit, not enforced here)"
		rows += "| %s | %.2f | %.2f | %s | %s |\n" % [key, value, limit, kind, verdict]
	var text := _markdown(rows)
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
		print("perf_map: within the limits")
		return 0
	printerr("perf_map: over the limits: %s" % ", ".join(failed))
	return 1


func _read_budget() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_budget_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("perf_map: %s does not read" % _budget_path)
		return {}
	var out: Dictionary = parsed
	return out


func _markdown(limit_rows: String) -> String:
	var s := "## Map speed (fake Europe %d x %d = %d hexes, seed %d)\n\n" % [_cols, _rows, _r["hexes"], _seed]
	s += "Renderer: %s, window %s, %d timed frames a zoom. GPU limits %s.\n\n" % [
		_r["renderer"], _r["window"], _timed, "enforced" if _gpu_limits else "reported only"]
	s += "| Frame (panning) | hexes on screen | mean ms | worst ms | draw calls | objects |\n|---|---|---|---|---|---|\n"
	for row: Dictionary in _r["frames"]:
		s += "| %s, zoom %s | %d | %.2f | %.2f | %d | %d |\n" % [row["what"], str(row["zoom"]), row["hexes_on_screen"],
			row["mean_ms"], row["worst_ms"], row["draw_calls"], row["objects"]]
	s += "\n| Fill | value |\n|---|---|\n"
	s += "| map built (FakeMap) | %.0f ms |\n" % _r["map_build_ms"]
	s += "| first screen (zoom 0.5) | %.1f ms |\n| all slices (CPU) | %.0f ms in %d slices, worst slice %.1f ms, worst frame while filling %.1f ms |\n" % [
		_r["fill_first_ms"], _r["fill_all_ms"], _r["fill_slices"], _r["fill_slice_worst_ms"], _r["fill_frame_worst_ms"]]
	s += "| all, wall clock | %.0f ms |\n| cells set | %d (missing tile names: %d %s) |\n" % [
		_r["fill_wall_ms"], _r["cells"], _r["missing_tiles"], _r["missing_names"]]
	s += "| chunk lines, all %d chunks | %.0f ms (rebuild of one: mean %.2f, worst %.2f ms) |\n" % [
		_r["chunks"], _r["chunk_lines_all_ms"], _r["chunk_rebuild_mean_ms"], _r["chunk_rebuild_ms"]]
	s += "| far picture built | %.1f ms |\n" % _r["far_build_ms"]
	s += "| one build action | CPU mean %.2f, worst %.2f ms; to the next frame worst %.1f ms (%d samples) |\n" % [
		_r["build_action_mean_ms"], _r["build_action_ms"], _r["build_to_frame_ms"], _r["build_samples"]]
	s += "\n| Season swap | screen CPU ms | load ms | to next frame ms | rest ms in frames | worst frame ms | video MB (all, since start) |\n|---|---|---|---|---|---|---|\n"
	for row: Dictionary in _r["swaps"]:
		s += "| %s (%s) | %.1f | %.1f | %.1f | %.0f in %d | %.1f | %.0f |\n" % [row["season"], "requested ahead" if row["ahead"] else "cold",
			row["cpu_ms"], row["load_ms"], row["to_frame_ms"], row["rest_ms"], row["rest_frames"], row["frame_worst_ms"], row["video_mb"]]
	s += "\nCell writes during the swaps: %d. Static memory: cells %.0f MB, whole process %.0f MB. Video memory of the first season (summer): %.0f MB.\n" % [
		_r["season_swap_cell_writes"], _r["cells_static_mb"], _r["static_mb_total"], _r["video_mb_summer"]]
	s += "\n| Limit | measured | limit | class | verdict |\n|---|---|---|---|---|\n" + limit_rows
	return s
