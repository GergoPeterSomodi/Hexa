## Contact sheet frames of the Godot map (0.3.0 item 4): the twelve regions and the whole map, in the terrain and the
## countries views, one PNG per frame at 1280 x 720, the same frames as tools/contact_sheet_python.py (the spec is
## tools/contact_sheet_regions.json). The map is the map file (the map that ships). The HUD is hidden: the frame is the map.
## Windowed, not headless (the headless driver draws nothing). Run with the windowed console build:
##   Godot_v4.7.2-stable_win64.exe --path godot -s res://tools/contact_sheet.gd -- --out=<absolute folder>
extends SceneTree

const SPEC := "res://../tools/contact_sheet_regions.json"
const FRAME := Vector2i(1280, 720)
const PYTHON_RADIUS := 60.0  # the hex radius the map view is baked at: zoom = radius / 60
const SETTLE_FRAMES := 4  # frames given to draw a frame before its picture is taken

var _main: Control
var _view: MapView
var _jobs: Array[Dictionary] = []
var _job := 0
var _settle := 0
var _out := ""
var _frames := 0


func _initialize() -> void:
	_out = _argument("--out=", "")
	if _out == "":
		printerr("contact sheet: give --out=<absolute folder>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(FRAME)
	_jobs = _make_jobs()
	var scene := load("res://shell/app/main.tscn") as PackedScene
	_main = scene.instantiate() as Control
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _view == null:
		for child: Node in _main.get_children():
			if child is MapView:
				_view = child as MapView
		if _view == null:
			if _frames > 3000:
				printerr("contact sheet: the map view was not built")
				quit(1)
				return true
			return false
		print("contact sheet: viewport %s, %d frames to write" % [root.get_visible_rect().size, _jobs.size()])
		return false
	if _job >= _jobs.size():
		print("contact sheet: done, %d frames in %s" % [_jobs.size(), _out])
		quit(0)
		return true
	var job: Dictionary = _jobs[_job]
	if _settle == 0:
		_hide_hud()  # before the picture: the frame drawn now is the one the picture takes
		_view.set_view(str(job["mode"]))
		var centre: Vector2i = job["centre"]
		var radius: float = float(job["radius"])
		_view.frame(MapGeometry.centre(centre), radius / PYTHON_RADIUS)
	_settle += 1
	if _settle < SETTLE_FRAMES:
		return false
	_hide_hud()
	var image := root.get_texture().get_image()
	var path := _out.path_join(str(job["file"]))
	image.save_png(path)
	print("contact sheet: %s zoom %.4f centre %s camera %s" % [job["file"], _view.zoom(), job["centre"],
			_view.camera_centre()])
	_settle = 0
	_job += 1
	return false


## The HUD (added after the view) is hidden before the picture is taken, so that the frame is the map alone.
func _hide_hud() -> void:
	for child: Node in _main.get_children():
		if child is MapHud:
			(child as CanvasLayer).visible = false


## The frames in order: each region in the terrain then the countries view, then the whole map.
func _make_jobs() -> Array[Dictionary]:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
	var jobs: Array[Dictionary] = []
	var middle := int(spec["middle_radius"])
	var whole := int(spec["whole_radius"])
	for region: Dictionary in spec["regions"]:
		jobs.append_array(_views_of(str(region["id"]), _hex(region["centre"]), middle))
	var whole_spec: Dictionary = spec["whole"]
	jobs.append_array(_views_of(str(whole_spec["id"]), _hex(whole_spec["centre"]), whole))
	return jobs


func _views_of(id: String, centre: Vector2i, radius: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"file": "%s-terrain.png" % id, "mode": MapView.VIEW_TERRAIN, "centre": centre, "radius": radius})
	out.append({"file": "%s-countries.png" % id, "mode": MapView.VIEW_COUNTRIES, "centre": centre, "radius": radius})
	return out


static func _hex(raw: Variant) -> Vector2i:
	var a: Array = raw
	return Vector2i(int(a[0]), int(a[1]))


func _argument(prefix: String, default_value: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return default_value
