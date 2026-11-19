## The map speed tool (docs/architecture/m1-build-spec.md section 9): builds the made-up Europe (FakeMap, 494 x 247 =
## 122,018 hexes), fills the tile stack with the full tileset (the committed tiles_<season>.tres) and measures what the
## budget names: the fill, the frame at each zoom while the camera pans, one build action, the season swaps, the
## chunk rebuild, memory. Prints the table and writes JSON; exits 1 when a limit of tests/perf_budget.json is passed.
##
## Windowed (a GPU, or Mesa's software renderer under xvfb in CI), sync off, 1920 x 1080:
##   godot --path godot -s res://tools/perf_map.gd -- [--gpu-limits] [--out=perf.json] [--summary=summary.md]
##         [--cols=494 --rows=247 --seed=1480] [--budget=res://tests/perf_budget.json] [--frames=240]
##         [--cpu-scale=2.0] [--countries=60]
## M2 (m2-build-spec.md section 9): after the map passes a `--countries=N` pass (60 by default, 0 = off) puts the made-up
## scenario (FakeScenario) on the map and measures the overlay, the borders, an owner change, the country names and the
## owner-mode frames (rows `owner_*`, `height_bytes_ms`, `overlay_setup_ms`, `mode_switch_ms`, `borders_all_ms`,
## `border_chunk_ms`, `country_names_ms`, `scenario_grow_ms`).
## `--dry-run` runs only the CPU rows of that pass and opens no game window: run it with `--headless`
## (`godot --headless --path godot -s res://tools/perf_map.gd -- --dry-run`); the frame rows are then "not measured".
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
const OWNER_CHANGES := 24
const BIG_CHANGE := 200
## The rows only the countries pass measures (a run with --countries=0 or --dry-run may leave them out).
const M2_KEYS: Array[String] = [
	"owner_frame_worst_ms", "owner_frame_mean_ms", "height_bytes_ms", "overlay_setup_ms", "mode_switch_ms",
	"borders_all_ms", "border_chunk_ms", "owner_change_frame_ms", "owner_change_200_ms", "country_names_ms",
	"scenario_grow_ms", "owner_mem_mb",
]

var _cols := 494
var _rows := 247
var _seed := 1480
var _timed := 240
var _gpu_limits := false
var _cpu_scale := 1.0
var _out := ""
var _summary := ""
var _budget_path := BUDGET
var _countries := 60
var _dry := false
var _game: Game = null
var _overlay: ModeOverlay = null
var _labels: CountryLabels = null
var _pan_hook := Callable()
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
		elif arg == "--dry-run":
			_dry = true
		elif arg.begins_with("--countries="):
			_countries = int(arg.substr(12))
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
	if not _dry:
		DisplayServer.window_set_size(FRAME)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	# The game sleeps up to 7 ms a frame when nothing changes (run/low_processor_mode): that wait is not work, and the
	# rows that run "to the next frame" would measure it.
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
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
	if _dry:
		await process_frame
		await _countries_pass()
		return _finish()
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
	await _countries_pass()
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
		if _pan_hook.is_valid():
			_pan_hook.call()
		await process_frame
	var last := Time.get_ticks_usec()
	var worst := 0
	var start := last
	for i: int in _timed:
		var sweep := float(i) / float(_timed)
		_camera.position = size * Vector2(0.3 + 0.4 * sweep, 0.4 + 0.2 * sin(sweep * TAU))
		if _pan_hook.is_valid():
			_pan_hook.call()
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


## The M2 pass (spec section 9): the made-up scenario on the map, then the overlay, the borders, owner changes, the
## country names and (windowed only) the owner-mode frames.
func _countries_pass() -> void:
	if _countries <= 0:
		return
	var t := Time.get_ticks_usec()
	var built := FakeScenario.build(_map, _countries, _seed)
	_r["scenario_build_ms"] = _ms_since(t)
	var defs := built["defs"] as GameDefs
	var scenario := built["scenario"] as ScenarioDef
	_r["countries"] = scenario.countries.size()
	t = Time.get_ticks_usec()
	var grown := ScenarioGrowth.grow(_map, scenario)
	_r["scenario_grow_ms"] = _ms_since(t)
	_r["scenario_grow_matches"] = grown == scenario.owner
	_game = Game.with_state(_map, _state, _seed)
	_game.defs = defs
	_game.scenario = scenario
	Countries.setup(_game, scenario)
	Territory.setup(_game, scenario)
	t = Time.get_ticks_usec()
	MapModes.height_bytes(_map)
	_r["height_bytes_ms"] = _ms_since(t)
	var static_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var video_before := _video_mb()
	_overlay = ModeOverlay.new()
	root.add_child(_overlay)
	t = Time.get_ticks_usec()
	_overlay.setup(_game)
	_r["overlay_setup_ms"] = _ms_since(t)
	await _mode_switches()
	await _all_borders()
	_r["owner_mem_mb"] = (Performance.get_monitor(Performance.MEMORY_STATIC) - static_before) / MB + _video_mb() - video_before
	_r["overlay_texture_mb"] = float(_overlay.texture_bytes()) / MB
	_names_row()
	if not _dry:
		_add_labels()
	await _owner_changes()
	await _owner_frames()


## CPU time of `set_mode`, worst of four switches (it ends in Owner mode). The frame wait sits outside the timing:
## windowed, it would add a whole vsync frame to a CPU row.
func _mode_switches() -> void:
	var worst := 0.0
	for mode: MapModes.Mode in [MapModes.Mode.OWNER, MapModes.Mode.RELIEF, MapModes.Mode.TERRAIN, MapModes.Mode.OWNER]:
		var t := Time.get_ticks_usec()
		_overlay.set_mode(mode)
		worst = maxf(worst, _ms_since(t))
		await process_frame
	_r["mode_switch_ms"] = worst


## Every border chunk, FILL_MS of work a frame: the total CPU and the worst chunk (BorderLines.for_chunk and the mesh).
func _all_borders() -> void:
	var palette := MapModes.palette(_game, false)
	var across := ceili(float(_cols) / EdgeLines.CHUNK)
	var down := ceili(float(_rows) / EdgeLines.CHUNK)
	var total := 0.0
	var worst := 0.0
	var slice := 0.0
	for cy: int in down:
		for cx: int in across:
			var chunk := Vector2i(cx, cy)
			var t := Time.get_ticks_usec()
			_view.set_chunk_borders(chunk, BorderLines.for_chunk(_map, _game.state.owner, chunk, palette))
			var one := _ms_since(t)
			worst = maxf(worst, one)
			total += one
			slice += one
			if slice >= FILL_MS:
				slice = 0.0
				await process_frame
	_r["borders_all_ms"] = total
	_r["border_chunk_ms"] = worst
	_r["border_chunks"] = across * down


func _largest_country() -> int:
	var best := 1
	var best_count := -1
	for id: int in range(1, _game.countries.size() + 1):
		var n := Territory.count(_game, id)
		if n > best_count:
			best_count = n
			best = id
	return best


func _names_row() -> void:
	var big := _largest_country()
	var t := Time.get_ticks_usec()
	var names := CountryNames.places_of(_game, PackedInt32Array([big]))
	_r["country_names_ms"] = _ms_since(t)
	_r["country_names_count"] = names.size()


func _add_labels() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	_labels = CountryLabels.new()
	layer.add_child(_labels)
	_labels.setup(_game)
	_labels.set_mode(MapModes.Mode.OWNER)


## What the map scene does on `owners_changed`: the texels, the touched border chunks (all at once, or FILL_MS of them a
## frame when `sliced`), the names. Returns {cpu_ms, frame_worst_ms}: the CPU time of the work itself (the waits for
## frames taken off) and the worst frame of a sliced run.
func _apply_owner_change(ids: PackedInt32Array, sliced: bool) -> Dictionary:
	var cpu := 0.0
	var t := Time.get_ticks_usec()
	var changed: Array[Vector2i] = []
	for event: Dictionary in _game.events:
		if str(event.get("kind", "")) == "owners_changed":
			changed.append_array(event["hexes"] as Array[Vector2i])
	_game.events.clear()
	_overlay.update_hexes(changed)
	var palette := MapModes.palette(_game, false)
	var frame_worst := 0.0
	var slice := 0.0
	cpu += _ms_since(t)
	for chunk: Vector2i in BorderLines.chunks_touched(_map, changed):
		t = Time.get_ticks_usec()
		_view.set_chunk_borders(chunk, BorderLines.for_chunk(_map, _game.state.owner, chunk, palette))
		var one := _ms_since(t)
		cpu += one
		slice += one
		if sliced and slice >= FILL_MS:
			slice = 0.0
			var f := Time.get_ticks_usec()
			await process_frame
			frame_worst = maxf(frame_worst, _ms_since(f))
	t = Time.get_ticks_usec()
	if _labels != null:
		_labels.on_owners_changed(changed)
	else:
		CountryNames.places_of(_game, ids)
	cpu += _ms_since(t)
	return {"cpu_ms": cpu, "frame_worst_ms": frame_worst}


## One-hex transfers on borders (`owner_change_frame_ms`: Territory.transfer, the drain, the texel, the chunks, the
## names, to the next frame; worst of OWNER_CHANGES) and one transfer of BIG_CHANGE hexes (`owner_change_200_ms`).
func _owner_changes() -> void:
	var worst := 0.0
	var done := 0
	for pick: Dictionary in _border_picks():
		var hexes: Array[Vector2i] = [pick["hex"] as Vector2i]
		var ids := PackedInt32Array([int(pick["from"]), int(pick["to"])])
		var t := Time.get_ticks_usec()
		Territory.transfer(_game, hexes, int(pick["to"]))
		await _apply_owner_change(ids, false)
		await process_frame
		worst = maxf(worst, _ms_since(t))
		done += 1
	_r["owner_change_samples"] = done
	_r["owner_change_frame_ms"] = worst
	var big := _largest_country()
	var around := Territory.neighbours(_game, big)
	var to := int(around[0]) if not around.is_empty() else big % _game.countries.size() + 1
	var many: Array[Vector2i] = []
	for idx: int in Territory.districts(_game, big):
		many.append(_map.hex_of(idx))
		if many.size() >= BIG_CHANGE:
			break
	var t := Time.get_ticks_usec()
	var moved := Territory.transfer(_game, many, to)
	var transfer_ms := _ms_since(t)
	var run: Dictionary = await _apply_owner_change(PackedInt32Array([big, to]), true)
	_r["owner_change_200_ms"] = transfer_ms + float(run["cpu_ms"])
	_r["owner_change_200_frame_worst_ms"] = float(run["frame_worst_ms"])
	_r["owner_change_200_hexes"] = moved


## Up to OWNER_CHANGES land hexes of one country that touch another's land, spread over the map, with the owner to give
## them to.
func _border_picks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := 0
	var owned := _game.state.owner
	for idx: int in _map.hex_count():
		if _map.land[idx] == 0 or owned[idx] == 0:
			continue
		var hex := _map.hex_of(idx)
		for d: int in 6:
			var other := _map.index_of(_map.neighbour(hex, d))
			if other < 0 or _map.land[other] == 0 or owned[other] == 0 or owned[other] == owned[idx]:
				continue
			seen += 1
			if seen % 50 == 0:
				out.append({"hex": hex, "from": int(owned[idx]), "to": int(owned[other])})
			break
		if out.size() >= OWNER_CHANGES:
			break
	return out


## The frame time at each zoom in Owner mode with the borders and the names on (windowed runs only).
func _owner_frames() -> void:
	if _dry:
		return
	_view.visible = true
	_pan_hook = _place_labels
	var rows: Array = []
	for zoom: float in ZOOMS:
		rows.append(await _pan(zoom, "owner mode"))
	_pan_hook = Callable()
	_r["owner_frames"] = rows
	var worst := 0.0
	var mean := 0.0
	for row: Dictionary in rows:
		worst = maxf(worst, float(row["worst_ms"]))
		mean = maxf(mean, float(row["mean_ms"]))
	_r["owner_frame_worst_ms"] = worst
	_r["owner_frame_mean_ms"] = mean


func _place_labels() -> void:
	if _labels == null:
		return
	var z := _camera.zoom.x
	var origin := Vector2(FRAME) * 0.5 - _camera.position * z
	_labels.set_view(Transform2D(Vector2(z, 0.0), Vector2(0.0, z), origin), z, Vector2(FRAME))


## The table, the JSON, the verdict.
func _finish() -> int:
	var budget := _read_budget()
	var limits: Dictionary = budget.get("limits", {})
	var failed: Array[String] = []
	var rows := ""
	for key: String in limits:
		var spec: Dictionary = limits[key]
		if not _r.has(key) and (_dry or (_countries <= 0 and M2_KEYS.has(key))):
			rows += "| %s | not measured | %.2f | %s | skipped (%s) |\n" % [key, float(spec["limit"]), str(spec["class"]),
				"--dry-run" if _dry else "--countries=0"]
			continue
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
	if _dry:
		return _markdown_dry(limit_rows)
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
	s += _markdown_countries()
	s += "\n| Limit | measured | limit | class | verdict |\n|---|---|---|---|---|\n" + limit_rows
	return s


## The M2 part of the table: the owner-mode frames and what the countries pass built.
func _markdown_countries() -> String:
	if not _r.has("countries"):
		return ""
	var s := "\n| Owner mode (panning, borders and names on) | hexes on screen | mean ms | worst ms | draw calls | objects |\n|---|---|---|---|---|---|\n"
	for row: Dictionary in _r.get("owner_frames", []):
		s += "| zoom %s | %d | %.2f | %.2f | %d | %d |\n" % [str(row["zoom"]), row["hexes_on_screen"], row["mean_ms"],
			row["worst_ms"], row["draw_calls"], row["objects"]]
	s += "\n| Countries | value |\n|---|---|\n"
	s += "| made-up scenario | %d countries, built in %.0f ms (growth alone %.0f ms, equals the stored owner: %s) |\n" % [
		_r["countries"], _r["scenario_build_ms"], _r["scenario_grow_ms"], str(_r["scenario_grow_matches"])]
	s += "| overlay | setup %.1f ms, textures %.2f MB; mode switch worst %.2f ms |\n" % [
		_r["overlay_setup_ms"], _r["overlay_texture_mb"], _r["mode_switch_ms"]]
	s += "| borders | %d chunks, %.0f ms in all, worst chunk %.2f ms |\n" % [
		_r["border_chunks"], _r["borders_all_ms"], _r["border_chunk_ms"]]
	s += "| owner change | one hex: worst %.2f ms of %d; %d hexes: %.1f ms, worst frame %.1f ms |\n" % [
		_r["owner_change_frame_ms"], _r["owner_change_samples"], _r["owner_change_200_hexes"], _r["owner_change_200_ms"],
		_r["owner_change_200_frame_worst_ms"]]
	s += "| names of the largest country | %.2f ms (%d labels) |\n" % [_r["country_names_ms"], _r["country_names_count"]]
	return s


## The table of a `--dry-run`: the CPU rows only, nothing windowed.
func _markdown_dry(limit_rows: String) -> String:
	var s := "## Map speed, dry run (fake Europe %d x %d = %d hexes, seed %d; CPU rows only, no window)\n\n" % [
		_cols, _rows, _r["hexes"], _seed]
	s += "Renderer: %s.\n" % _r["renderer"]
	s += _markdown_countries()
	s += "\n| Limit | measured | limit | class | verdict |\n|---|---|---|---|---|\n" + limit_rows
	return s
