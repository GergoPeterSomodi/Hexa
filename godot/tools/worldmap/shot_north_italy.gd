## Pictures of the north Italy map scene (shell/worldmap/north_italy_map.tscn) and its frame rate: the whole map and
## one close crop, in summer and in winter, as PNGs of the window (1600 x 900).
## Windowed, not headless (the headless driver draws nothing). Run with the console build, from the repository root:
##   godot --path godot -s res://tools/worldmap/shot_north_italy.gd -- [--out=<absolute folder>] [--seed=N] [--villages=0]
##         [--art=<the folder of another bake, with the last slash>]
## Without --out the pictures go to docs/design/map/godot_map/ beside the project. Prints the search's counts and the
## frames a second with the display's sync off (the whole map standing still, and a pan across the close zoom).
extends SceneTree

const SCENE := "res://shell/worldmap/north_italy_map.tscn"
const FRAME := Vector2i(1600, 900)
const SETTLE_FRAMES := 6  # frames given to draw a view before its picture is taken
const TIMED_FRAMES := 240
## The close crop: the plain south of the Po, the Apennines and Genoa, at twice the baked size.
const CLOSE_CENTRE := Vector2(0.47, 0.50)  # as a share of the map's size
const CLOSE_ZOOM := 2.0

var _map: NorthItalyMap = null
var _out := ""
var _jobs: Array[Dictionary] = []
var _job := 0
var _settle := 0
var _timed := 0
var _timed_start := 0
var _frames := 0


func _initialize() -> void:
	_out = _argument("--out=", ProjectSettings.globalize_path("res://").path_join("../docs/design/map/godot_map").simplify_path())
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(FRAME)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var scene := load(SCENE) as PackedScene
	_map = scene.instantiate() as NorthItalyMap
	_map.art_dir = _argument("--art=", NorthItalyMap.DEFAULT_DIR)
	root.add_child(_map)
	for season: String in ["summer", "winter"]:
		_jobs.append({"season": season, "view": "whole", "file": "north_italy_%s.png" % season, "hud": true})
		_jobs.append({"season": season, "view": "close", "file": "north_italy_%s_close.png" % season, "hud": false})
	_jobs.append({"season": "summer", "view": "whole", "file": "", "hud": true, "time": "whole map, still"})
	_jobs.append({"season": "summer", "view": "close", "file": "", "hud": true, "time": "close zoom, panning"})


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	if not _map.is_loaded():
		printerr("shot: the baked art is missing (res://assets/worldmap/north_italy/)")
		quit(1)
		return true
	if _frames == 3:
		if _argument("--villages=", "1") == "0":
			_map.set_villages(false)
		var seed_text := _argument("--seed=", "")
		if seed_text != "":
			_map.reroll(int(seed_text))
		print("shot: viewport %s, seed %d" % [root.get_visible_rect().size, _map.seed_value])
		print("shot: ", JSON.stringify(_map.improve.summary()))
		print("shot: ", JSON.stringify(_map.stats))
		print("shot: rule breaks %d, fixed place pairs %d" % [_map.improve.violations().size(), _map.improve.fixed_conflicts.size()])
		return false
	if _job >= _jobs.size():
		print("shot: done, pictures in %s" % _out)
		quit(0)
		return true
	var job: Dictionary = _jobs[_job]
	if _settle == 0:
		_map.set_season(str(job["season"]))
		_map.set_hud_visible(bool(job["hud"]))
		if str(job["view"]) == "whole":
			_map.frame_all()
		else:
			_map.frame_at(_map.map_size() * CLOSE_CENTRE, CLOSE_ZOOM)
	_settle += 1
	if _settle < SETTLE_FRAMES:
		return false
	if job.has("time"):
		if _timed == 0:
			_timed_start = Time.get_ticks_usec()
		if str(job["view"]) == "close":
			var sweep := sin(float(_timed) / float(TIMED_FRAMES) * TAU) * 0.2
			_map.frame_at(_map.map_size() * (CLOSE_CENTRE + Vector2(sweep, sweep * 0.5)), CLOSE_ZOOM)
		_timed += 1
		if _timed <= TIMED_FRAMES:
			return false
		var seconds := float(Time.get_ticks_usec() - _timed_start) / 1000000.0
		print("shot: %s: %.0f frames a second (%.2f ms a frame, sync off, %s)" % [job["time"],
			float(TIMED_FRAMES) / seconds, seconds * 1000.0 / float(TIMED_FRAMES), root.get_visible_rect().size])
		_timed = 0
	else:
		var image := root.get_texture().get_image()
		var path := _out.path_join(str(job["file"]))
		image.save_png(path)
		print("shot: wrote %s (%d x %d)" % [path, image.get_width(), image.get_height()])
	_settle = 0
	_job += 1
	return false


func _argument(prefix: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return fallback
