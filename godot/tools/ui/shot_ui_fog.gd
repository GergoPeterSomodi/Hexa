## The fog pictures (docs/architecture/fog-build-spec.md section 7, names fog_*): Genoa on seed 1480 with its map made thin
## (UiSample.fog: FogFixture.thin at radius 1, so there is deep fog, light fog and land in sight on one screen). A standalone script
## like shot_ui_m8.gd; the shell is reached through call() and get() only, so it compiles before the autoloads.
##   fog_map_terrain, fog_map_owner, fog_map_relief, fog_map_yields, fog_map_food, fog_map_supply
##                     the map at zoom 1 on Genoa in each mode: deep fog (flat fill, sea too), light fog with the veil, in sight
##   fog_minimap       the minimap alone (cropped from the Owner picture): the same deep-fog fill and no owners in deep fog
##   fog_card_deep     the hex card of a deep-fog hex: "Unexplored" and nothing else
##   fog_card_light    the hex card of a light-fog fortress of another country: the holder, people and the exact garrison
##   fog_siege_light   a light-fog siege of another country's hex: the map's dial without the besieger's colour, the card's siege block
##   fog_standing      the season report's Standing section (13 known countries; the full start, every country known)
##   fog_rankings      the study's Rankings page (13 known countries, exact numbers; the full start)
##   fog_log_others    the action log open with others' lines on light-fog land (the thin game)
##
## Windowed (GPU or xvfb + Mesa):
##   godot --path godot -s res://tools/ui/shot_ui_fog.gd -- --out=DIR [--scale=1,2] [--only=fog_map_owner,...]
## Each scene is written to DIR/1x/NAME.png (1280 x 720) and DIR/2x/NAME.png (2560 x 1440). Headless it prepares every scene and
## exits 0 without writing PNGs; a scene that does not come up exits 1 and says which.
extends SceneTree

const DEFAULT_OUT_DIR := "/tmp/hexa_ui_shots_fog"
const APP_SCENE_PATH := "res://shell/app/app.tscn"
const LOGICAL_H := 720
const LOGICAL_W := 1280
const GEN := &"GEN"
const GENOA := Vector2i(8, 13)
const SCENES: Array[String] = ["fog_map_terrain", "fog_map_owner", "fog_map_relief", "fog_map_yields", "fog_map_food",
	"fog_map_supply", "fog_minimap", "fog_card_deep", "fog_card_light", "fog_siege_light", "fog_standing", "fog_rankings",
	"fog_log_others"]
## The map mode of each map picture (the setting state/map_mode; the minimap picture is the Owner mode).
const MODE_OF: Dictionary = {"fog_map_terrain": "terrain", "fog_map_owner": "owner", "fog_map_relief": "relief",
	"fog_map_yields": "yields", "fog_minimap": "owner", "fog_map_food": "food", "fog_map_supply": "supply"}
## Scenes that play on the full start (every country knows every other); the rest on the thin game.
const FULL_START: Array[String] = ["fog_standing", "fog_rankings"]
## Others' lines of one season in the log (the cap is 24, so the "more" line shows).
const OTHER_LINES := 30
## Pixels around the minimap's rectangle in the cropped picture.
const MINIMAP_MARGIN := 8
const FRAMES_MAX := 1200

var _out_dir := DEFAULT_OUT_DIR
var _scales: Array[int] = [1, 2]
var _only: Array[String] = []
var _picks: Dictionary = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out=") or arg.begins_with("--dir="):
			_out_dir = arg.substr(arg.find("=") + 1)
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
		printerr("shot_ui_fog: cannot load %s" % APP_SCENE_PATH)
		return 1
	var target_scenes: Array[String] = SCENES if _only.is_empty() else _only
	var rendered := 0
	var saved := 0
	for scale_mult: int in _scales:
		var scale_dir := global_out.path_join("%dx" % scale_mult)
		DirAccess.make_dir_recursive_absolute(scale_dir)
		for scene_name: String in target_scenes:
			if not SCENES.has(scene_name):
				printerr("shot_ui_fog: unknown scene '%s'" % scene_name)
				return 1
			var ok := await _capture_one(packed, scene_name, scale_mult, scale_dir, headless)
			if not ok:
				printerr("shot_ui_fog: %s did not come up at %dx" % [scene_name, scale_mult])
				return 1
			rendered += 1
			if not headless:
				saved += 1
	if headless:
		print("shot_ui_fog: headless dummy renderer; prepared %d scene renders (%s) without PNG output" % [rendered, global_out])
	else:
		print("shot_ui_fog: saved %d fog pictures to %s" % [saved, global_out])
	return 0


func _capture_one(packed: PackedScene, scene_name: String, scale_mult: int, scale_dir: String, headless: bool) -> bool:
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
	s.set_value("map/minimap", true)
	s.set_value("map/sight_veil", true)
	if MODE_OF.has(scene_name):
		s.set_value("state/map_mode", MODE_OF[scene_name])
	app.call("set_settings_override", s)
	vp.add_child(app)
	await _wait_frames(3)

	var session := root.get_node_or_null("Session")
	var ok: bool = await _wait_up(app) and await _prepare(app, scene_name, session, vp)
	await _wait_frames(3)
	if ok and not headless:
		var tex := vp.get_texture()
		var img := tex.get_image() if tex != null else null
		if img == null or img.is_empty():
			printerr("shot_ui_fog: empty viewport image for %s (%dx)" % [scene_name, scale_mult])
			ok = false
		else:
			if scene_name == "fog_minimap":
				img = _minimap_crop(app, img, scale_mult)
			var png_path := scale_dir.path_join("%s.png" % scene_name)
			if img.save_png(png_path) != OK:
				printerr("shot_ui_fog: failed saving %s" % png_path)
				ok = false

	if session != null:
		session.call("end_game")
	root.remove_child(vp)
	vp.queue_free()
	await _wait_frames(2)
	return ok


## The game is up: its map, no screen over it.
func _wait_up(app: Node) -> bool:
	for _i: int in FRAMES_MAX:
		var stack: Object = app.call("stack") as Object
		if app.call("map_scene") != null and not bool(app.call("is_starting")) and int(stack.call("count")) == 0:
			return true
		await process_frame
	return false


## The scene's state. The thin game is made here (UiSample.fog) unless the scene plays on the full start.
func _prepare(app: Node, scene_name: String, session: Node, vp: SubViewport) -> bool:
	var g: Game = session.get("game") as Game if session != null else null
	if g == null:
		return false
	var ms := app.call("map_scene") as Object
	var hud := app.call("hud") as Object
	if not FULL_START.has(scene_name):
		_picks = UiSample.fog(g)
		print("shot_ui_fog: %s picks deep %s light %s fortress %s in sight %s siege %s by %s" % [scene_name,
			_picks["deep"], _picks["light"], _picks["fortress"], _picks["in_sight"], _picks["siege"], _picks["besieger"]])
	if MODE_OF.has(scene_name) or scene_name == "fog_minimap":
		ms.call("frame_at", (ms.call("view") as Object).call("centre_of", GENOA), 1.0)
		await _wait_frames(4)
		return int(ms.call("mode")) == _mode_index(MODE_OF.get(scene_name, "terrain"))
	match scene_name:
		"fog_card_deep":
			return await _select(ms, hud, _picks["deep"])
		"fog_card_light":
			return await _select(ms, hud, _picks["fortress"])
		"fog_siege_light":
			var hex: Vector2i = _picks["siege"]
			ms.call("frame_at", (ms.call("view") as Object).call("centre_of", hex), 1.0)
			return await _select(ms, hud, hex)
		"fog_standing":
			return await _season_standing(app)
		"fog_rankings":
			session.call("end_season")  # the study's numbers are the last closed season's: one season first
			await _wait_frames(4)
			return await _open_rankings(app)
		"fog_log_others":
			return await _others_log(app, session, g)
	return false


func _mode_index(key: String) -> int:
	return ["terrain", "owner", "relief", "yields", "food", "supply"].find(key)


## Selects `hex` on the map and waits for the hex panel to show it; false when it is not selected (or none was found).
func _select(ms: Object, hud: Object, hex: Vector2i) -> bool:
	if hex == Vector2i(-1, -1):
		return false
	ms.call("select_hex", hex)
	await _wait_frames(4)
	var panel := hud.call("tile_window") as CanvasItem
	return ms.get("selected") == hex and panel != null and panel.visible


## The Standing section of the season report: the season ends, the report opens, its Standing section is the picture.
func _season_standing(app: Node) -> bool:
	var flow: Object = (app.call("requests") as Object).get("flow")
	flow.call("request_end", false)
	for _i: int in FRAMES_MAX:
		await _wait_frames(1)
		var st := (app.call("stack") as Object).call("top") as Object
		if st != null and str(st.get("screen_id")) == "season_report":
			(st.call("sheet") as Object).call("scroll_to", &"standing")
			await _wait_frames(3)
			return true
	return false


## The study's Rankings page (the same page as the M4.5 picture).
func _open_rankings(app: Node) -> bool:
	var works: Object = (app.call("requests") as Object).get("works")
	works.call("open_study", &"rankings", {})
	await _wait_frames(4)
	var top := (app.call("stack") as Object).call("top") as Object
	return top != null and top.get("screen_id") == &"study" and top.call("current_page_id") == &"rankings"


## The log with others' lines on light-fog land: the first OTHER_LINES land hexes of another country that Genoa has discovered
## and does not see, a work finished on each this season, then the action log opened.
func _others_log(app: Node, session: Node, g: Game) -> bool:
	var n := 0
	for i: int in g.map.hex_count():
		if n >= OTHER_LINES:
			break
		if g.map.land[i] != 1:
			continue
		var hex := g.map.hex_of(i)
		var holder := Territory.owner_tag(g, hex)
		if holder == GEN or holder == &"" or not Knowledge.discovered(g, GEN, hex) or Knowledge.sees(g, GEN, hex):
			continue
		var w := Work.new()
		w.id = 1000 + n
		w.tag = holder
		w.hex = hex
		w.action = Works.BUILD
		w.family = ImproveRules.VINEYARD
		w.level_to = 1
		w.started_turn = g.turn
		w.seasons = 4
		w.seasons_left = 4
		g.emit({"kind": "work_finished", "tag": holder, "hex": hex, "work": w.to_dict(),
			"witnesses": ["GEN", String(holder)]})
		n += 1
	session.call("drain")
	await _wait_frames(2)
	var log_card: Object = (app.call("hud") as Object).call("action_log")
	log_card.call("open")
	await _wait_frames(3)
	return n > 0 and bool(log_card.call("is_open"))


## The minimap's rectangle out of the full picture, with a margin (the minimap of the Owner picture).
func _minimap_crop(app: Node, img: Image, scale_mult: int) -> Image:
	var mini := (app.call("hud") as Object).call("minimap") as Control
	var rect := mini.get_global_rect()
	var grown := Rect2i(int(rect.position.x) - MINIMAP_MARGIN, int(rect.position.y) - MINIMAP_MARGIN,
		int(rect.size.x) + 2 * MINIMAP_MARGIN, int(rect.size.y) + 2 * MINIMAP_MARGIN)
	var scaled := Rect2i(grown.position * scale_mult, grown.size * scale_mult)
	return img.get_region(scaled)


func _wait_frames(n: int) -> void:
	for _i: int in n:
		await process_frame
