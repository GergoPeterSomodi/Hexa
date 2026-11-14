## Start-up probe (0.3.0 item 7 and the start budget): opens the main scene in a window and times, in milliseconds from the
## script's own start, the moment the map view is built (the file read, the view, the atlas), then the first drawn frame.
## Windowed, not headless (the headless driver draws nothing). The engine's own start-up is not in these numbers; the
## caller times the whole process with a stopwatch. Run with the windowed console build:
##   Godot_v4.7.2-stable_win64.exe --path godot -s res://tools/startup_probe.gd
## Pass -- --build-map to time the staged build instead of the map file.
extends SceneTree

const LIMIT_FRAMES := 3000

var _started := 0
var _frames := 0
var _main: Control
var _view_ms := -1
var _first_draw_ms := -1
var _built_frame := -1


func _initialize() -> void:
	_started = Time.get_ticks_msec()
	var scene := load("res://shell/app/main.tscn") as PackedScene
	_main = scene.instantiate() as Control
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _view_ms < 0:
		for child: Node in _main.get_children():
			if child is MapView:
				_view_ms = Time.get_ticks_msec() - _started
				_built_frame = _frames
				print("startup: map view built at %d ms (frame %d)" % [_view_ms, _frames])
		if _frames > LIMIT_FRAMES:
			print("startup: the map view was not built in %d frames" % LIMIT_FRAMES)
			quit(1)
			return true
		return false
	if _first_draw_ms < 0 and _frames > _built_frame + 1:
		_first_draw_ms = Time.get_ticks_msec() - _started
		print("startup: first frame with the map at %d ms" % _first_draw_ms)
		quit(0)
		return true
	return false
