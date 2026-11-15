## M1 trial pictures: today's map scene and the tile trial at the same views, as PNGs of the window (1280 x 720 each),
## and the frame time of each. Windowed (nothing is drawn headless):
##   godot --path godot -s res://tools/mapview/shot_trial.gd -- --out=<absolute folder> [--only=tiles]
## Writes today_whole.png, tiles_whole.png, today_close.png, tiles_close.png; a Python step puts them side by side
## (tools/worldmap/tileset_bake/side_by_side.py).
extends SceneTree

const TODAY := "res://shell/worldmap/north_italy_map.tscn"
const FRAME := Vector2i(1280, 720)
const SETTLE := 8
const TIMED := 200
## The views, in today's picture px (1280 x 720) and zoom: the whole picture, and Genoa with the plain and the woods.
const VIEWS: Array[Dictionary] = [
	{"name": "whole", "centre": Vector2(640.0, 360.0), "zoom": 1.0},
	{"name": "close", "centre": Vector2(640.0, 400.0), "zoom": 2.0},
]

var _today: NorthItalyMap = null
var _trial: TileTrial = null
var _out := ""
var _jobs: Array[Dictionary] = []
var _job := 0
var _settle := 0
var _timed := 0
var _start := 0
var _frames := 0


func _initialize() -> void:
	var only := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--only="):
			only = arg.substr(7)
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(FRAME)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if only != "tiles":
		_today = (load(TODAY) as PackedScene).instantiate() as NorthItalyMap
		root.add_child(_today)
	_trial = TileTrial.new()
	root.add_child(_trial)
	for view: Dictionary in VIEWS:
		for which: String in ["today", "tiles"]:
			if which == "today" and _today == null:
				continue
			_jobs.append({"which": which, "view": view, "file": "%s_%s.png" % [which, str(view["name"])]})
			_jobs.append({"which": which, "view": view, "file": ""})


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	if _job >= _jobs.size():
		print("shot_trial: done, pictures in %s" % _out)
		quit(0)
		return true
	var job: Dictionary = _jobs[_job]
	var view: Dictionary = job["view"]
	var tiles := str(job["which"]) == "tiles"
	if _settle == 0:
		if _today != null:
			_today.visible = not tiles
			_today.set_hud_visible(false)
			_today.set_grid_visible(true)
			if not tiles:
				_today.frame_at(view["centre"], float(view["zoom"]))
				(_today.get_node("Camera") as Camera2D).make_current()
		_trial.visible = tiles
		if tiles:
			_trial.frame_today(view["centre"], float(view["zoom"]))
			(_trial.get_child(0) as Camera2D).make_current()
			if _frames < 20:
				print("shot_trial: tiles ", JSON.stringify(_trial.stats), " missing ", _trial.view.missing_names().slice(0, 6))
	_settle += 1
	if _settle < SETTLE:
		return false
	if str(job["file"]) != "":
		var image := root.get_texture().get_image()
		image.save_png(_out.path_join(str(job["file"])))
		print("shot_trial: wrote %s" % str(job["file"]))
	else:
		if _timed == 0:
			_start = Time.get_ticks_usec()
		_timed += 1
		if _timed <= TIMED:
			return false
		var ms := float(Time.get_ticks_usec() - _start) / 1000.0 / float(TIMED)
		print("shot_trial: %s %s: %.2f ms a frame (sync off)" % [str(job["which"]), str(view["name"]), ms])
		_timed = 0
	_settle = 0
	_job += 1
	return false
