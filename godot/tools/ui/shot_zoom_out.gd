## The zoom-out pictures (docs/architecture/map-overview-build-spec.md D2): Genoa on seed 1480 in the real app with its
## HUD at 1920 x 1080: the whole-map view, one, two and three wheel notches past it, and the Goods mode at the zoom-out
## limit. The wheel turns through the viewport, as a player turns it. A standalone script like shot_ui.gd; the shell is
## reached through call() and get() only, so it compiles before the autoloads.
##
## Windowed, ONE process and one window for every picture:
##   godot --path godot -s res://tools/ui/shot_zoom_out.gd -- --out=DIR
## Each picture goes to DIR/NAME.png and prints its zoom and what shows. Headless it plays every step and writes no PNG.
## A step that does not show what the switch says it should prints "CHECK FAILED" and the exit code is then 1.
extends SceneTree

const APP_SCENE_PATH := "res://shell/app/app.tscn"
const SIZE := Vector2i(1920, 1080)
const GEN := &"GEN"
const MODE_GOODS := 6
const FRAMES_MAX := 1200

var _out_dir := ""
var _headless := false
var _failed := 0
var _vp: SubViewport = null
var _app: Node = null
var _session: Node = null


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)
	if _out_dir == "":
		printerr("shot_zoom_out: give --out=DIR")
		quit(1)
		return
	_run()


func _run() -> void:
	await process_frame
	_headless = DisplayServer.get_name() == "headless"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_session = root.get_node_or_null("Session")
	if await _open():
		await _pictures()
	if _session != null:
		_session.call("end_game")
	print("shot_zoom_out: %d failed checks%s" % [_failed, " (headless: no PNG)" if _headless else ""])
	quit(1 if _failed > 0 else 0)


func _pictures() -> void:
	var ms := _app.call("map_scene") as Node
	var rig := ms.call("camera_rig") as Node
	ms.call("fit")
	await _frames(6)
	await _shot("zoom_0_whole_map", false)
	var names: Array[String] = ["zoom_1_notch_out", "zoom_2_notches_out", "zoom_3_notches_out"]
	for k: int in names.size():
		await _wheel_out()
		await _shot(names[k], k > 0)
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_7
		key.physical_keycode = KEY_7
		key.pressed = pressed
		_vp.push_input(key, true)
		await process_frame
	rig.call("zoom_to", float(rig.call("min_zoom")))
	await _frames(8)
	_check(int(ms.call("mode")) == MODE_GOODS, "key 7 did not set Goods")
	await _shot("zoom_limit_goods", true)


## A fresh app in a viewport of SIZE in a new Genoa game; false when it did not come up.
func _open() -> bool:
	_vp = SubViewport.new()
	_vp.gui_embed_subwindows = true
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.gui_disable_input = false
	root.add_child(_vp)
	_app = (load(APP_SCENE_PATH) as PackedScene).instantiate()
	_app.set("settings_path", "")
	_app.set("allow_tree_quit", false)
	_app.set("pause_tree_when_modal", false)
	_app.set("skip_loading_frames", true)
	_app.set("cli_args_override", PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"]))
	var settings := Settings.new("Windows", true)
	for pair: Array in [["state/help_seen", true], ["graphics/preload_next_season", false], ["game/autosave", "off"],
			["accessibility/reduce_motion", true], ["display/ui_scale", "100"]]:
		settings.set_value(str(pair[0]), pair[1])
	_app.call("set_settings_override", settings)
	_vp.add_child(_app)
	for _i: int in FRAMES_MAX:
		await process_frame
		var ms := _app.call("map_scene") as Node
		var game := _session.get("game") as Game
		if ms != null and not bool(_app.call("is_starting")) and int((_app.call("stack") as Object).call("count")) == 0 \
				and not bool(ms.call("is_loading")) and game != null and game.player == GEN:
			await _frames(8)
			((_app.call("hud") as Node).call("toast_host") as CanvasItem).visible = false  # they lie over the map
			return true
	_check(false, "the app did not come up")
	return false


## One wheel notch out with the pointer in the middle of the screen.
func _wheel_out() -> void:
	var at := Vector2(SIZE) / 2.0
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	_vp.push_input(motion, true)
	await _frames(2)
	for pressed: bool in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_WHEEL_DOWN
		button.position = at
		button.global_position = at
		button.pressed = pressed
		_vp.push_input(button, true)
	await _frames(8)


## Takes the picture `name` and checks that the parchment shows exactly when `parchment` says.
func _shot(name: String, parchment: bool) -> void:
	await _frames(8)
	var ms := _app.call("map_scene") as Node
	var rig := ms.call("camera_rig") as Node
	var shown := (ms.call("parchment") as CanvasItem).visible
	var kinds: Dictionary[String, int] = {}
	for entry: Dictionary in (ms.call("parchment_names") as Object).call("placed") as Array:
		var kind := str(entry["kind"])
		if kind != "icon" and str(entry["text"]) == "":
			kind += "_dot"
		kinds[kind] = int(kinds.get(kind, 0)) + 1
	var zoom := float(ms.call("zoom"))
	print("shot %s: zoom %.4f = %.4f of the fit %.4f (limit %.4f), parchment %s, names %s, far picture %s" % [name, zoom,
		zoom / float(rig.call("fit_zoom")), float(rig.call("fit_zoom")), float(rig.call("min_zoom")), str(shown),
		str(kinds) if shown else "-", str((ms.call("far") as CanvasItem).visible)])
	_check(shown == parchment, "%s: the parchment is %s" % [name, "shown" if shown else "not shown"])
	if _headless:
		return
	await RenderingServer.frame_post_draw
	var image := _vp.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(_out_dir.path_join(name + ".png")) != OK:
		_check(false, "no picture %s" % name)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
		print("CHECK FAILED: %s" % what)


func _frames(count: int) -> void:
	for _i: int in count:
		await process_frame
