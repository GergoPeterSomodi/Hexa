## Renders key M1.5 Studiolo UI screens at 1x (1280x720) and 2x (2560x1440) into PNG files
## (docs/architecture/ui-and-controls-spec.md section 9; ui-style-and-feedback-spec.md section 11).
##
## Windowed (GPU or xvfb + Mesa in CI):
##   godot --path godot -s res://tools/ui/shot_ui.gd -- [--out=/tmp/hexa_ui_shots] [--dir=/tmp/hexa_ui_shots] [--scale=1,2]
## Headless (dummy renderer): exercises all screens at 1x and 2x without writing empty PNGs and exits 0.
extends SceneTree

const DEFAULT_OUT_DIR := "/tmp/hexa_ui_shots"
const APP_SCENE_PATH := "res://shell/app/app.tscn"
const SCREEN_IDS_PATH := "res://shell/screens/screen_ids.gd"
const LOGICAL_SIZE := Vector2i(1280, 720)
const SCENES: Array[String] = [
	"main_menu",
	"sandbox",
	"credits",
	"hud",
	"pause_menu",
	"options",
	"about",
	"help",
	"confirm",
]

var _out_dir := DEFAULT_OUT_DIR
var _scales: Array[int] = [1, 2]
var _only: Array[String] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)
		elif arg.begins_with("--dir="):
			_out_dir = arg.substr(6)
		elif arg.begins_with("--scale="):
			_scales.clear()
			for part: String in arg.substr(8).split(",", false):
				var s := int(part.strip_edges())
				if s == 1 or s == 2:
					_scales.append(s)
		elif arg.begins_with("--only="):
			_only.clear()
			for part: String in arg.substr(7).split(",", false):
				_only.append(part.strip_edges())
	if _scales.is_empty():
		_scales = [1, 2]
	_run()


func _run() -> void:
	await process_frame
	var code := await _capture_all()
	quit(code)


func _capture_all() -> int:
	var headless := DisplayServer.get_name() == "headless"
	var global_out := ProjectSettings.globalize_path(_out_dir) if _out_dir.begins_with("res://") or _out_dir.begins_with("user://") else _out_dir
	DirAccess.make_dir_recursive_absolute(global_out)

	var packed := ResourceLoader.load(APP_SCENE_PATH) as PackedScene
	if packed == null:
		printerr("shot_ui: cannot load %s" % APP_SCENE_PATH)
		return 1

	var target_scenes: Array[String] = SCENES if _only.is_empty() else _only
	var rendered := 0
	var saved := 0

	for scale_mult: int in _scales:
		var scale_dir := global_out.path_join("%dx" % scale_mult)
		DirAccess.make_dir_recursive_absolute(scale_dir)
		for scene_name: String in target_scenes:
			if not SCENES.has(scene_name):
				printerr("shot_ui: unknown scene '%s'" % scene_name)
				return 1
			var ok := await _capture_one(packed, scene_name, scale_mult, scale_dir, headless)
			if not ok:
				return 1
			rendered += 1
			if not headless:
				saved += 1

	if headless:
		print("shot_ui: headless dummy renderer; verified %d screen renders (%s) without PNG output" % [rendered, global_out])
	else:
		print("shot_ui: saved %d UI pictures to %s" % [saved, global_out])
	return 0


func _capture_one(
	packed: PackedScene,
	scene_name: String,
	scale_mult: int,
	scale_dir: String,
	headless: bool
) -> bool:
	var vp := SubViewport.new()
	var phys_size := LOGICAL_SIZE * scale_mult
	vp.size = phys_size
	if scale_mult > 1:
		vp.size_2d_override = LOGICAL_SIZE
		vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	root.add_child(vp)

	var start_in_sandbox := scene_name in ["hud", "pause_menu", "options", "about", "help", "confirm"]
	var app := packed.instantiate()
	app.set("settings_path", "")
	app.set("allow_tree_quit", false)
	app.set("pause_tree_when_modal", false)
	app.set("skip_loading_frames", true)
	if start_in_sandbox:
		app.set("cli_args_override", PackedStringArray(["--sandbox", "--seed=1480"]))
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("accessibility/reduce_motion", true)
	s.set_value("display/ui_scale", "100" if scale_mult == 1 else "200")
	app.call("set_settings_override", s)
	vp.add_child(app)

	await _wait_frames(3)

	var ok := _prepare_scene(app, scene_name)
	await _wait_frames(3)

	if ok and not headless:
		var tex := vp.get_texture()
		var img := tex.get_image() if tex != null else null
		if img == null or img.is_empty():
			printerr("shot_ui: empty viewport image for %s (%dx)" % [scene_name, scale_mult])
			ok = false
		else:
			var png_path := scale_dir.path_join("%s.png" % scene_name)
			var err := img.save_png(png_path)
			if err != OK:
				printerr("shot_ui: failed saving %s (err=%d)" % [png_path, err])
				ok = false

	var session := root.get_node_or_null("Session")
	if session != null:
		session.call("end_game")
	root.remove_child(vp)
	vp.queue_free()
	await _wait_frames(2)
	return ok


func _prepare_scene(app: Node, scene_name: String) -> bool:
	var stack := app.call("stack") as Control
	var ctx := app.call("context") as ShellContext
	if stack == null or ctx == null:
		return false
	match scene_name:
		"main_menu":
			var top_m := stack.call("top") as Node
			return top_m != null and top_m.get("screen_id") == &"main_menu"
		"sandbox", "credits", "pause_menu", "options", "about", "help":
			ctx.request(&"open_screen", {"id": StringName(scene_name)})
			var top_s := stack.call("top") as Node
			return top_s != null and top_s.get("screen_id") == StringName(scene_name)
		"hud":
			var ms := app.call("map_scene") as Node
			var hud_node := app.call("hud") as Node
			var session := root.get_node_or_null("Session")
			var g: Game = session.get("game") as Game if session != null else null
			if ms == null or hud_node == null or g == null:
				return false
			var hex := _sample_land_hex(g)
			ms.call("select_hex", hex)
			var view_node := ms.call("view") as Node
			if view_node != null:
				ms.call("frame_at", view_node.call("centre_of", hex), 1.0)
			var hex_panel := hud_node.call("hex_panel") as CanvasItem
			return ms.get("selected") == hex and hex_panel != null and hex_panel.visible
		"confirm":
			var screen_ids := ResourceLoader.load(SCREEN_IDS_PATH) as GDScript
			if screen_ids == null:
				return false
			var confirm := screen_ids.call("make", &"confirm") as Node
			if confirm == null:
				return false
			confirm.call("configure", {
				"title": "Keep these display settings?",
				"lines": ["Display settings were applied. Keep them or revert to the previous settings?"],
				"choices": [
					{"id": &"keep", "label": "Keep", "kind": "primary", "safe": false},
					{"id": &"revert", "label": "Revert", "kind": "secondary", "safe": true},
				],
				"timeout_s": 10.0,
				"timeout_id": &"revert",
				"safe_choice": &"revert",
				"seal_letter": "!",
			})
			stack.call("push", confirm)
			return stack.call("top") == confirm
	return false


func _sample_land_hex(g: Game) -> Vector2i:
	if g == null or g.map == null:
		return Vector2i.ZERO
	var mid := Vector2i(g.map.cols >> 1, g.map.rows >> 1)
	if g.map.has(mid) and g.map.land[g.map.index_of(mid)] == 1:
		return mid
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1:
			return g.map.hex_of(i)
	return Vector2i.ZERO


func _wait_frames(n: int) -> void:
	for _i: int in range(n):
		await process_frame
