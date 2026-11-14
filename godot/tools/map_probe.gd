## Windowed probe of the map view at 1280 x 720: screenshots of the far, middle and close zooms over Iberia and Italy in
## both views, and frame times while panning, zooming and idle. Not headless: the headless driver draws nothing.
## Run with the windowed editor (not the console build), from the repository root:
##   Godot_v4.7.2-stable_win64.exe --path godot -s res://tools/map_probe.gd
## It writes the PNGs and probe.txt into OUT_DIR (an absolute folder outside the repository).
extends SceneTree

const OUT_DIR := "C:/hxr/view-shots"
const SETTLE_FRAMES := 6  # frames a view is given to draw before its picture is taken
const PAN_FRAMES := 300
const ZOOM_FRAMES := 300
const IDLE_FRAMES := 120
const SKIP_FRAMES := 20  # the first frames of a phase are not timed (shader and layer warm-up)

var _main: Control
var _view: MapView
var _frames := 0
var _phase := 0
var _phase_frames := 0
var _shot := 0
var _settle := 0
var _shots: Array[Dictionary] = []
var _log := PackedStringArray()
var _times := PackedFloat64Array()  # the frame times of the phase now running


func _initialize() -> void:
	var scene := load("res://shell/app/main.tscn") as PackedScene
	_main = scene.instantiate() as Control
	root.add_child(_main)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	# Without vsync the frame time is the real cost, not the 60 Hz cap.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(delta: float) -> bool:
	_frames += 1
	if _view == null:
		_view = _find_view()
		if _view == null:
			return _frames > 1200
		_log.append("view built after %d frames; viewport %s" % [_frames, root.get_visible_rect().size])
		_shots = _shot_list()
		return false
	if _phase == 0:
		return _shooting()
	if _phase == 1:
		return _timing(delta, PAN_FRAMES, _pan)
	if _phase == 2:
		return _timing(delta, ZOOM_FRAMES, _zoom)
	if _phase == 3:
		return _timing(delta, IDLE_FRAMES, _idle)
	return true


func _find_view() -> MapView:
	for child: Node in _main.get_children():
		if child is MapView:
			return child as MapView
	return null


func _shot_list() -> Array[Dictionary]:
	# Zooms are Python's radius / 60, so the hex is the same size on both sides: far r=3, tile zoom r=13.
	var europe := _view.map
	var whole := MapGeometry.map_size(europe.cols, europe.rows) * 0.5
	var iberia_mid := (_city("Lisbon") + _city("Granada")) * 0.5
	var italy_mid := (_city("Rome") + _city("Venice")) * 0.5
	var far := 3.0 / 60.0
	var middle := 13.0 / 60.0
	var shots: Array[Dictionary] = []
	shots.append({"name": "far_europe_terrain", "centre": whole, "zoom": far, "view": MapView.VIEW_TERRAIN})
	shots.append({"name": "far_europe_countries", "centre": whole, "zoom": far, "view": MapView.VIEW_COUNTRIES})
	shots.append({"name": "middle_iberia_terrain", "centre": iberia_mid, "zoom": middle, "view": MapView.VIEW_TERRAIN})
	shots.append({"name": "middle_po_terrain", "centre": _city("Milan"), "zoom": middle, "view": MapView.VIEW_TERRAIN})
	shots.append({"name": "middle_italy_terrain", "centre": italy_mid, "zoom": middle, "view": MapView.VIEW_TERRAIN})
	shots.append({"name": "middle_iberia_countries", "centre": iberia_mid, "zoom": middle, "view": MapView.VIEW_COUNTRIES})
	shots.append({"name": "middle_italy_countries", "centre": italy_mid, "zoom": middle, "view": MapView.VIEW_COUNTRIES})
	shots.append({"name": "close_lisbon_terrain", "centre": _city("Lisbon"), "zoom": 0.5, "view": MapView.VIEW_TERRAIN})
	shots.append({"name": "close_venice_terrain", "centre": _city("Venice"), "zoom": 0.5, "view": MapView.VIEW_TERRAIN})
	return shots


## The centre of a city's hex, or the map centre when the name is not on the map.
func _city(name: String) -> Vector2:
	var map := _view.map
	for pos: Vector2i in map.city_names.keys():
		if map.city_names[pos] == name:
			return MapGeometry.centre(pos)
	_log.append("city not found: " + name)
	return MapGeometry.map_size(map.cols, map.rows) * 0.5


func _shooting() -> bool:
	if _shot >= _shots.size():
		_phase = 1
		_phase_frames = 0
		return false
	var shot: Dictionary = _shots[_shot]
	var zoom: float = shot["zoom"]
	if zoom == 0.0:
		zoom = _fit_zoom()  # the whole map on the window
	_view.set_view(shot["view"])
	_view.frame(shot["centre"], zoom)
	_settle += 1
	if _settle < SETTLE_FRAMES:
		return false
	_settle = 0
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, shot["name"]]
	image.save_png(path)
	_log.append("shot %s zoom %.3f far %s" % [shot["name"], _view.zoom(), _view.is_far()])
	_shot += 1
	return false


func _fit_zoom() -> float:
	var size := MapGeometry.map_size(_view.map.cols, _view.map.rows)
	var view := root.get_visible_rect().size
	return minf(view.x / size.x, view.y / size.y)


func _timing(delta: float, frames: int, step: Callable) -> bool:
	_phase_frames += 1
	step.call(_phase_frames)
	if _phase_frames > SKIP_FRAMES:
		_times.append(delta * 1000.0)
	if _phase_frames < frames:
		return false
	_log.append(_stats_line(_phase_name(), _times))
	_times = PackedFloat64Array()
	_phase += 1
	_phase_frames = 0
	if _phase > 3:
		_write()
		return true
	return false


func _phase_name() -> String:
	match _phase:
		1:
			return "pan at zoom 0.30"
		2:
			return "zoom 0.06 to 0.50 and back"
		3:
			return "idle, close zoom"
	return "?"


func _pan(n: int) -> void:
	var size := MapGeometry.map_size(_view.map.cols, _view.map.rows)
	var t := float(n) / 60.0
	var centre := size * 0.5 + Vector2(cos(t) * size.x * 0.3, sin(t * 0.7) * size.y * 0.3)
	_view.frame(centre, 0.3)


func _zoom(n: int) -> void:
	var size := MapGeometry.map_size(_view.map.cols, _view.map.rows)
	var t := float(n) / 45.0
	var zoom := lerpf(0.06, 0.5, 0.5 + 0.5 * sin(t))
	_view.frame(size * 0.5, zoom)


func _idle(_n: int) -> void:
	_view.frame(_city("Lisbon"), 0.5)


func _stats_line(name: String, times: PackedFloat64Array) -> String:
	var sorted := times.duplicate()
	sorted.sort()
	var total := 0.0
	for t: float in times:
		total += t
	var mean := total / float(maxi(1, times.size()))
	var p95 := sorted[int(float(sorted.size() - 1) * 0.95)] if sorted.size() > 0 else 0.0
	var worst := sorted[sorted.size() - 1] if sorted.size() > 0 else 0.0
	return "%s: %d frames, mean %.2f ms (%.0f fps), p95 %.2f ms, worst %.2f ms" % [name, times.size(),
			mean, 1000.0 / maxf(mean, 0.001), p95, worst]


func _write() -> void:
	var file := FileAccess.open(OUT_DIR + "/probe.txt", FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_log) + "\n")
	file.close()
