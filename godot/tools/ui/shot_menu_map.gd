## Captures the 1920x1080 North Italy summer map backdrop for the UI bake (tools/ui_bake/inputs/menu_map.png).
## Windowed (nothing renders headless):
##   /opt/homebrew/bin/godot --path godot -s res://tools/ui/shot_menu_map.gd
## Optional: -- --out=/abs/or/rel/path.png
extends SceneTree

const DEFAULT_OUT := "../tools/ui_bake/inputs/menu_map.png"
const TARGET_SIZE := Vector2i(1920, 1080)
const SEA_COLOUR := Color("#3f7fae")

var _scene: Node2D = null
var _out_path := DEFAULT_OUT
var _frames := 0
var _ready_done := false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_path = arg.substr(6)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(TARGET_SIZE)
	root.size = TARGET_SIZE
	RenderingServer.set_default_clear_color(SEA_COLOUR)


func _setup_scene() -> void:
	_ready_done = true
	var session := root.get_node_or_null("Session")
	if session != null and session.get("game") == null:
		session.call("new_game", "north_italy", 1480)
	var packed := load("res://shell/map/map_scene.tscn") as PackedScene
	if packed == null:
		printerr("shot_menu_map: cannot load res://shell/map/map_scene.tscn")
		quit(1)
		return
	_scene = packed.instantiate() as Node2D
	_scene.set("preload_next_season", false)
	var settings := Settings.new("macOS", false)
	settings.set_value("map/parchment", false)  # the menu's backdrop is the tile map, framed whole (map-overview PM5)
	settings.set_value("graphics/preload_next_season", false)
	_scene.call("configure", settings)
	root.add_child(_scene)
	_scene.call("finish_loading")
	_scene.call("set_hud_visible", false)
	var lbl := _scene.call("labels") as CanvasItem
	if lbl != null:
		lbl.visible = false
	_scene.call("fit")


func _process(_delta: float) -> bool:
	_frames += 1
	if not _ready_done:
		_setup_scene()
		return false
	if _scene == null:
		return true
	if _frames == 3:
		_scene.call("fit")
	if _frames < 10:
		return false
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("shot_menu_map: empty viewport image (must run windowed, not --headless)")
		quit(1)
		return true
	if img.get_size() != TARGET_SIZE:
		img.resize(TARGET_SIZE.x, TARGET_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var global_out := ProjectSettings.globalize_path("res://" + _out_path) if not _out_path.begins_with("/") else _out_path
	DirAccess.make_dir_recursive_absolute(global_out.get_base_dir())
	var err := img.save_png(global_out)
	if err != OK:
		printerr("shot_menu_map: save_png(%s) failed with %d" % [global_out, err])
		quit(1)
		return true
	print("shot_menu_map: wrote %s (%dx%d)" % [global_out, img.get_width(), img.get_height()])
	quit(0)
	return true
