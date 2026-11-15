## M1 trial speed probe (the standard's E1, a first reading): fills the tile stack with a made-up map the size of
## Europe at 28 km (494 x 247 = 122,018 hexes) using the trial tileset, and times a frame at several zooms while the
## camera pans. Windowed, sync off:
##   godot --path godot -s res://tools/mapview/probe_fake_europe.gd [-- --cols=494 --rows=247]
## The map is noise: land and sea, cover, heights, a piece on one land hex in seven, a river every few rows. Coast
## tiles are used where the trial tileset has the shape. It is a speed test, not a picture.
extends SceneTree

const TILES_DIR := "res://assets/tiles/trial/"
const FRAME := Vector2i(1920, 1080)
const ZOOMS: Array[float] = [2.0, 1.0, 0.5, 0.25, 0.12]
const SETTLE := 20
const TIMED := 240
const COVERS: Array[String] = ["farmland", "grassland", "woods", "woods", "rock", "farmland", "marsh", "snow"]

var _cols := 494
var _rows := 247
## --hide=<kinds>: leave out the layers of these kinds (plain, mul, add, shadow, stand) or the lines, to see what each costs.
var _hide := ""
var _view: TileMapView = null
var _camera: Camera2D = null
var _noise := FastNoiseLite.new()
var _job := 0
var _frames := 0
var _timed := 0
var _start := 0
var _worst := 0
var _last := 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cols="):
			_cols = int(arg.substr(7))
		elif arg.begins_with("--rows="):
			_rows = int(arg.substr(7))
		elif arg.begins_with("--hide="):
			_hide = arg.substr(7)
	DisplayServer.window_set_size(FRAME)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_noise.seed = 1480
	_noise.frequency = 0.045
	var tiles := TilesetBuilder.build(TILES_DIR)
	if tiles.tile_set == null:
		printerr("probe_fake_europe: %s" % tiles.error)
		quit(1)
		return
	_view = TileMapView.new()
	root.add_child(_view)
	_view.setup(tiles)
	_camera = Camera2D.new()
	root.add_child(_camera)
	var memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var start := Time.get_ticks_msec()
	var piece_names := _piece_names(tiles)
	var land_count := 0
	for row: int in _rows:
		for column: int in _cols:
			land_count += _fill(Vector2i(column, row), piece_names, tiles)
	var lines: Array[Dictionary] = []
	for row: int in range(4, _rows, 6):
		var pts := PackedVector2Array()
		for column: int in range(0, _cols, 2):
			pts.append(MapTiles.cell_centre(Vector2i(column, row + ((column >> 1) & 1))) + Vector2(0.0, 51.0))
		lines.append(EdgeLines.river(pts, 1 + row % 3, float(row)))
	if not _hide.split(",").has("lines"):
		_view.set_lines(lines)
	for layer_name: String in TileMapView.LAYERS:
		var kind := str(TileMapView.LAYERS[layer_name][1])
		if _hide.split(",").has(kind if kind != "" else "plain"):
			_view.layer(layer_name).enabled = false
	print("probe_fake_europe: %d x %d = %d hexes (%d land), %d cells set in %d ms, %.0f MB more static memory, window %s" % [
		_cols, _rows, _cols * _rows, land_count, _view.cell_count(), Time.get_ticks_msec() - start,
		(Performance.get_monitor(Performance.MEMORY_STATIC) - memory_before) / 1048576.0, FRAME])


func _height(hex: Vector2i) -> float:
	return maxf(0.0, _noise.get_noise_2d(float(hex.x) + 0.5 * float(hex.y & 1), float(hex.y) * 0.87) + 0.12) * 4200.0


func _land(hex: Vector2i) -> bool:
	return _height(hex) > 0.0


func _piece_names(tiles: TilesetBuilder) -> Array[String]:
	var out: Array[String] = []
	for tile_name: String in tiles.names:
		if tile_name.begins_with("piece/") and tile_name.ends_with("/front") and not tile_name.contains("harbour_addon"):
			out.append(tile_name.trim_suffix("/front"))
	out.sort()
	return out


func _fill(hex: Vector2i, piece_names: Array[String], tiles: TilesetBuilder) -> int:
	var height := _height(hex)
	var sea_near: Array[bool] = []
	var heights := PackedFloat32Array()
	var any_land := false
	for d: int in 6:
		var n := ImproveRules.neighbour(hex, d)
		var h := _height(n)
		sea_near.append(h <= 0.0)
		any_land = any_land or h > 0.0
		heights.append(h if h > 0.0 else height)
	if height <= 0.0:
		_view.set_tile("sea", hex, MapTiles.sea("deep" if MapTiles.pick(hex, 3, 9) == 0 else "sea", any_land, hex))
		return 0
	var cover := COVERS[MapTiles.pick(Vector2i(int(float(hex.x) / 3.0), int(float(hex.y) / 3.0)), COVERS.size(), 7)]  # patches of cover
	if height > 2200.0:
		cover = "rock"
	var level := ReliefLevels.level_of(height)
	var built := MapTiles.pick(hex, 7, 5) == 0 and not piece_names.is_empty()
	_view.set_tile("ground", hex, MapTiles.ground(cover, height, hex))
	var tone := MapTiles.slope_tone(height, heights)
	_view.set_tile("shade", hex, "shade/%d" % tone.x if tone.x > 0 else "")
	_view.set_tile("light", hex, "light/%d" % tone.y if tone.y > 0 else "")
	var coast := MapTiles.coast(MapTiles.coast_mask(sea_near), hex, level, false, false)
	if coast != "" and not tiles.names.has(coast):
		coast = "coast/beach/24/0"  # the trial tileset has few shapes: any coast tile costs the same to draw
	_view.set_tile("coast", hex, coast)
	var relief := MapTiles.relief(level, MapTiles.pick(hex, 2, 6) == 0, built, false, hex)
	_view.set_tile("relief", hex, relief)
	for d: int in 6:
		_view.set_tile("trees%d" % d, hex, MapTiles.trees(d, cover, height, "" if sea_near[d] else cover, false, false, built,
			relief != "", hex))
	if built:
		var piece := piece_names[MapTiles.pick(hex, piece_names.size(), 8)]
		for part: String in ["ground", "shadow", "back", "front"]:
			_view.set_tile("piece_" + part, hex, piece + "/" + part)
	return 1


func _process(_delta: float) -> bool:
	if _view == null:
		return true
	_frames += 1
	if _job >= ZOOMS.size():
		quit(0)
		return true
	var zoom := ZOOMS[_job]
	var size := Vector2(float(_cols) * 104.0, float(_rows) * 76.5)
	var sweep := float(_timed) / float(TIMED)
	_camera.zoom = Vector2(zoom, zoom)
	_camera.position = size * Vector2(0.3 + 0.4 * sweep, 0.4 + 0.2 * sin(sweep * TAU))
	if _frames < SETTLE:
		return false
	var now := Time.get_ticks_usec()
	if _timed == 0:
		_start = now
		_worst = 0
	else:
		_worst = maxi(_worst, now - _last)
	_last = now
	_timed += 1
	if _timed <= TIMED:
		return false
	var hexes := (float(FRAME.x) / zoom / 104.0) * (float(FRAME.y) / zoom / 76.5)
	print("probe_fake_europe: zoom %.2f (about %d hexes on screen): %.2f ms a frame, worst %.2f ms, %d draw calls, %d objects drawn" % [
		zoom, int(hexes), float(now - _start) / 1000.0 / float(TIMED), float(_worst) / 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])
	_timed = 0
	_frames = 0
	_job += 1
	return false
