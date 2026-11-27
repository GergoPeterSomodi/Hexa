## The unit-select pictures (issue #433; docs/architecture/ui-and-controls-spec.md section 4): a stack of three armies on Genoa's
## hex, its token clicked (the first army is selected: the stack's ring is up, and the army panel shows which), and one army on
## its own hex selected by a click on its token (the ring on that single token). Each is written at 1x (1280 x 720) and 2x
## (2560 x 1440) as DIR/NAME_1x.png and DIR/NAME_2x.png. The clicks go through the viewport like a player's.
##   godot --path godot -s res://tools/ui/shot_unit_select.gd -- --out=DIR
## Windowed (GPU or xvfb + Mesa). Headless (the dummy renderer) it prepares every scene at the given scales and exits 0 without PNGs.
extends SceneTree

const APP_SCENE_PATH := "res://shell/app/app.tscn"
const TAG := &"GEN"
const GENOA := Vector2i(8, 13)
const LOGICAL_W := 1280
const LOGICAL_H := 720
const STACK_SIZE := 3
## The point on a token that a click selects its unit at: 25 px above the token's foot (the plate, the badge).
const TOKEN_POINT := Vector2(0.0, -25.0)
const SCENES: Array[String] = ["unit_select_stack", "unit_select_ring"]

var _out_dir := ""
var _scales: Array[int] = [1, 2]


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)
		elif arg.begins_with("--scale="):
			_scales.clear()
			for part: String in arg.substr(8).split(",", false):
				var s := int(part.strip_edges())
				if s == 1 or s == 2:
					_scales.append(s)
	if _out_dir == "":
		printerr("shot_unit_select: give --out=DIR")
		quit(1)
		return
	if _scales.is_empty():
		_scales = [1, 2]
	_run()


func _run() -> void:
	await process_frame
	var code := await _capture_all()
	quit(code)


func _capture_all() -> int:
	var headless := DisplayServer.get_name() == "headless"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var packed := ResourceLoader.load(APP_SCENE_PATH) as PackedScene
	if packed == null:
		printerr("shot_unit_select: cannot load %s" % APP_SCENE_PATH)
		return 1
	var saved := 0
	for scale_mult: int in _scales:
		for scene_name: String in SCENES:
			var ok := await _capture_one(packed, scene_name, scale_mult, headless)
			if not ok:
				printerr("shot_unit_select: %s did not come up at %dx" % [scene_name, scale_mult])
				return 1
			if not headless:
				saved += 1
	if headless:
		print("shot_unit_select: headless dummy renderer; prepared the scenes without PNG output")
	else:
		print("shot_unit_select: saved %d pictures to %s" % [saved, _out_dir])
	return 0


func _capture_one(packed: PackedScene, scene_name: String, scale_mult: int, headless: bool) -> bool:
	var vp := SubViewport.new()
	vp.gui_embed_subwindows = true
	vp.size = Vector2i(LOGICAL_W, LOGICAL_H) * scale_mult
	if scale_mult > 1:
		vp.size_2d_override = Vector2i(LOGICAL_W, LOGICAL_H)
		vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	root.add_child(vp)

	var app := packed.instantiate()
	app.set("settings_path", "")
	app.set("allow_tree_quit", false)
	app.set("pause_tree_when_modal", false)
	app.set("skip_loading_frames", true)
	app.set("cli_args_override", PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"]))
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("map/parchment", false)  # these pictures show the tiles, framed whole too (map-overview PM5)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("accessibility/reduce_motion", true)
	s.set_value("display/ui_scale", "100" if scale_mult == 1 else "200")
	s.set_value("game/season_report", "full")
	s.set_value("game/autosave", "off")
	s.set_value("graphics/season_change", "instant")
	s.set_value("game/movement", "instant")
	app.call("set_settings_override", s)
	vp.add_child(app)
	await _frames(3)

	var ok: bool = await _prepare(app, vp, scene_name, scale_mult)
	await _frames(3)
	if ok and not headless:
		var tex := vp.get_texture()
		var img := tex.get_image() if tex != null else null
		if img == null or img.is_empty():
			printerr("shot_unit_select: empty viewport image for %s (%dx)" % [scene_name, scale_mult])
			ok = false
		else:
			var png_path := _out_dir.path_join("%s_%dx.png" % [scene_name, scale_mult])
			if img.save_png(png_path) != OK:
				printerr("shot_unit_select: failed saving %s" % png_path)
				ok = false

	var session := root.get_node_or_null("Session")
	if session != null:
		session.call("end_game")
	root.remove_child(vp)
	vp.queue_free()
	await _frames(2)
	return ok


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


## The scene's state: a stack of three armies on Genoa (the stack scene), then one army on its own hex (the ring scene). Each
## is selected by a click on its token; false when the click did not select the army.
func _prepare(app: Node, vp: SubViewport, scene_name: String, scale_mult: int) -> bool:
	var session := app.get_tree().root.get_node_or_null("Session")
	var g: Game = null
	for _i: int in 600:  # the new game's map fills in slices; wait for the country's game
		g = session.get("game") as Game if session != null else null
		if g != null and g.has_countries() and g.player == TAG:
			break
		await _frames(1)
	var scene: Node = app.call("map_scene")  # untyped: the shell classes compile after the autoloads
	if g == null or scene == null or not g.has_countries() or g.player != TAG:
		printerr("shot_unit_select: no Genoa game")
		return false
	_calm(g)
	var armies: Node = scene.get_node("MapArmies")
	var kind := _kind_id(g, &"pikemen")
	var stack_ids: Array[int] = []
	for i: int in STACK_SIZE:
		var a := Armies.create(g, TAG, GENOA, "Army of Genoa %d" % (i + 1))
		Armies.add_units(g, a, kind, 2, g.turn - 1, GENOA, 0, {})
		stack_ids.append(a.id)
	var inland := _own_hex_at(g, GENOA, 2)
	if inland.x < 0:
		printerr("shot_unit_select: no own hex two steps from Genoa")
		return false
	var single := Armies.create(g, TAG, inland, "Army of Savona")
	Armies.add_units(g, single, kind, 2, g.turn - 1, inland, 0, {})
	g.version += 1
	armies.call("sync")
	var view: Node = scene.call("view")
	if scene_name == "unit_select_stack":
		scene.call("frame_at", view.call("centre_of", GENOA), 1.0)
		await _frames(4)
		armies.call("sync")
		_select(vp, armies, _token_point(armies, GENOA), scale_mult)
	else:
		scene.call("frame_at", view.call("centre_of", inland), 1.0)
		await _frames(4)
		armies.call("sync")
		_select(vp, armies, _token_point(armies, inland), scale_mult)
	await _frames(3)
	return int(armies.call("selected_army")) >= 0


## The viewport point of the click that selects the unit on the token at `hex`.
static func _token_point(armies: Node, hex: Vector2i) -> Vector2:
	var tokens: Node = armies.call("tokens")
	var token: Node2D = tokens.call("token_at", hex, TAG)
	if token == null:
		return Vector2.ZERO
	return token.get_global_transform_with_canvas() * TOKEN_POINT


## The click that selects the unit at `pos`: a real click through the viewport at 1x; at 2x (the size override takes the input
## in another space) the path the click ends in, MapArmies._on_unit_requested. The click path itself is GUT-tested.
static func _select(vp: SubViewport, armies: Node, pos: Vector2, scale_mult: int) -> void:
	if scale_mult == 1:
		_click(vp, pos)
	else:
		armies.call("_on_unit_requested", pos)


## A left click (a motion, then press and release) at the viewport point `pos`.
static func _click(vp: SubViewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = pos
		ev.global_position = pos
		ev.pressed = pressed
		vp.push_input(ev)


## Calm weather on a copy of the defs (the pictures show the armies, not the weather).
static func _calm(g: Game) -> void:
	var d := PeopleFixture.copy_of(g.defs)
	d.weather_odds = PackedInt32Array([100, 0, 0])
	g.defs = d


static func _kind_id(g: Game, key: StringName) -> int:
	for unit: UnitDef in g.defs.units:
		if unit.key == key:
			return unit.id
	return 0


## The own land hex `steps` neighbour-steps from `from` (the first one the walk finds); (-1, -1) when none.
static func _own_hex_at(g: Game, from: Vector2i, steps: int) -> Vector2i:
	var frontier: Array[Vector2i] = [from]
	var seen := {from: true}
	for _step: int in steps:
		var next: Array[Vector2i] = []
		for hex: Vector2i in frontier:
			for d: int in 6:
				var beside := ImproveRules.neighbour(hex, d)
				if seen.has(beside) or not g.map.has(beside) or not g.map.is_land(beside):
					continue
				if Territory.owner_tag(g, beside) != TAG:
					continue
				seen[beside] = true
				next.append(beside)
		frontier = next
	return frontier[0] if not frontier.is_empty() else Vector2i(-1, -1)
