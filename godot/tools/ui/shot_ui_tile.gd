## The tile window pictures (tile-window spec 7.4; build plan TW19, issue 436): every case of the window on each of its live
## tabs, made in a Genoa game on seed 1480 the way a player meets them. A standalone script like shot_ui_fog.gd; the shell is
## reached through call() and get() only, so it compiles before the autoloads.
##   tile_own_town, tile_own_army, tile_own_ships
##                         Genoa (an own walled port town) on each tab; one company raised there (an army stands on it)
##   tile_own_town_facts   the Town tab scrolled to its foot (the land facts under the strips)
##   tile_own_town_hover   the Town tab with the first buildable tile hovered (its hover card beside the window)
##   tile_own_army_cap     the Army tab after the season's three companies are raised (every row refused by the cap)
##   tile_wild_town        own land with no settlement (the bare-land picture; Army dimmed)
##   tile_castle_town      a castle (an own one when Genoa has one, else the first discovered; the picture's castle kind)
##   tile_foreign_town     a light-fog fortress of another country on the thin game (Army dimmed, its reason under the facts)
##   tile_sight_town       another country's land in sight
##   tile_sea_town         a sea hex beside Genoa (no chips, no tab strip)
##   tile_deep             a deep-fog hex on the thin game ("Unexplored" only)
##   tile_own_army_1024, tile_own_town_1024
##                         the same window in a 1024 x 600 window
##   tile_queue_idle       another own town of Genoa's with no work (the queue's idle line, issue 436 round 3 H2)
##   tile_building         Genoa with its upgrade under way (the building tile's bar and hourglass, the queue's row and Cancel)
##   tile_short            Genoa short of ducats (the short tile's red rim and "!", the line under the strip)
##   tile_many             the Town tab with the 26-tile fixture of test_tile_window_strips.gd (the strips wrap)
##   tile_own_town_folded  the Town tab with People and food and Made here folded (M8)
## Every scene prints the window's rect and the map's ("shot_ui_tile: <scene> ... window <rect> map <rect>"): the window is one
## size for all of them, and the map keeps its room.
##
## Windowed (GPU or xvfb + Mesa), ONE process for every run and scene (one window, closed at the end):
##   godot --path godot -s res://tools/ui/shot_ui_tile.gd -- --out=DIR [--scale=1,2] [--sizes=1920x1080@auto,...] [--only=...]
##   --scale=1,2           the 1280 x 720 game (1024 x 600 for the _1024 scenes) at UI scale 1 and 2: DIR/<s>x/
##   --sizes=WxH@S,...     real windows of W x H pixels at UI scale S (1.25, 1.5... or auto: the scale the game picks on this
##                         screen, printed); the logical viewport is the size over the scale: DIR/<W>x<H>@<S>/. With --sizes and no
##                         --scale only the sizes are made.
## Each scene is written to <run dir>/NAME.png and the window alone, cropped, to <run dir>/NAME_win.png. Headless it prepares
## every scene and exits 0 without writing PNGs; a scene that does not come up exits 1 and says which.
extends SceneTree

const DEFAULT_OUT_DIR := "/tmp/hexa_ui_shots_tile"
const APP_SCENE_PATH := "res://shell/app/app.tscn"
const LOGICAL := Vector2i(1280, 720)
const SMALL := Vector2i(1024, 600)
const GEN := &"GEN"
const GENOA := Vector2i(8, 13)
const DEV_MONEY := 100000
const RAISE_CAP := 3
const CROP_MARGIN := 6
const FRAMES_MAX := 1200
const SCENES: Array[String] = [
	"tile_own_town", "tile_own_town_facts", "tile_own_town_hover", "tile_own_army", "tile_own_ships", "tile_own_army_cap",
	"tile_wild_town", "tile_castle_town", "tile_foreign_town", "tile_sight_town", "tile_sea_town", "tile_deep",
	"tile_own_army_1024", "tile_own_town_1024", "tile_queue_idle", "tile_building", "tile_short", "tile_many",
	"tile_own_town_folded",
]
const LAND_FACTS := preload("res://shell/panels/tile_tabs/land_facts.gd")
## The 26-tile fixture's Town tab (as test_tile_window_strips.gd's).
const MANY_STUB := """extends TileTab
const ID := &"town"
const LABEL := "Town"
const ORDER := 10
const STRIPS := preload("res://shell/panels/tile_tabs/building_strips.gd")
static func applies(view: Dictionary) -> bool:
	return str(view.get("case", "")) != "unexplored"

func fill(game: Game, viewer: StringName, hex: Vector2i, _view: Dictionary) -> void:
	var part := STRIPS.new() as TileTab
	add_child(part)
	part.call("fill_groups", game, viewer, hex, Engine.get_meta(&"tile_fixture_groups", []))
"""
const MANY_STATES: Array[StringName] = [&"built", &"building", &"ready", &"short", &"locked", &"refused"]
## The scenes played on the thin game (UiSample.fog): deep fog and light fog exist there.
const THIN: Array[String] = ["tile_foreign_town", "tile_deep"]

var _out_dir := DEFAULT_OUT_DIR
var _scales: Array[int] = []
var _sizes: Array[String] = []
var _only: Array[String] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out=") or arg.begins_with("--dir="):
			_out_dir = arg.substr(arg.find("=") + 1)
		elif arg.begins_with("--scale="):
			for part: String in arg.substr(8).split(",", false):
				var s := int(part.strip_edges())
				if s == 1 or s == 2:
					_scales.append(s)
		elif arg.begins_with("--sizes="):
			for part: String in arg.substr(8).split(",", false):
				_sizes.append(part.strip_edges())
		elif arg.begins_with("--only="):
			_only.clear()
			for part: String in arg.substr(7).split(",", false):
				_only.append(part.strip_edges())
	if _scales.is_empty() and _sizes.is_empty():
		_scales = [1, 2]
	_run()


func _run() -> void:
	await process_frame
	var code := await _capture_all()
	quit(code)


## The runs: {name, phys (a Vector2i, or ZERO: the scene's logical size times ui), ui}.
func _runs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: int in _scales:
		out.append({"name": "%dx" % s, "phys": Vector2i.ZERO, "ui": float(s)})
	for spec: String in _sizes:
		var at := spec.split("@")
		var wh := at[0].split("x")
		if wh.size() != 2:
			continue
		var ui := _auto_scale() if at.size() < 2 or at[1] == "auto" else float(at[1])
		out.append({"name": "%s@%s" % [at[0], str(ui)], "phys": Vector2i(int(wh[0]), int(wh[1])), "ui": ui})
	return out


func _capture_all() -> int:
	var headless := DisplayServer.get_name() == "headless"
	var global_out := ProjectSettings.globalize_path(_out_dir) if _out_dir.begins_with("res://") or _out_dir.begins_with("user://") else _out_dir
	DirAccess.make_dir_recursive_absolute(global_out)
	var packed := ResourceLoader.load(APP_SCENE_PATH) as PackedScene
	if packed == null:
		printerr("shot_ui_tile: cannot load %s" % APP_SCENE_PATH)
		return 1
	var target_scenes: Array[String] = SCENES if _only.is_empty() else _only
	var rendered := 0
	for run: Dictionary in _runs():
		var run_dir := global_out.path_join(str(run["name"]))
		DirAccess.make_dir_recursive_absolute(run_dir)
		for scene_name: String in target_scenes:
			if not SCENES.has(scene_name):
				printerr("shot_ui_tile: unknown scene '%s'" % scene_name)
				return 1
			var ok := await _capture_one(packed, scene_name, run, run_dir, headless)
			if not ok:
				printerr("shot_ui_tile: %s did not come up in run %s" % [scene_name, run["name"]])
				return 1
			rendered += 1
	if headless:
		print("shot_ui_tile: headless dummy renderer; prepared %d scene renders (%s) without PNG output" % [rendered, global_out])
	else:
		print("shot_ui_tile: saved %d tile window pictures to %s" % [rendered, global_out])
	return 0


func _capture_one(packed: PackedScene, scene_name: String, run: Dictionary, scale_dir: String, headless: bool) -> bool:
	var logical := SMALL if scene_name.ends_with("_1024") else LOGICAL
	var ui := float(run["ui"])
	var phys: Vector2i = run["phys"]
	if phys == Vector2i.ZERO:
		phys = Vector2i(roundi(logical.x * ui), roundi(logical.y * ui))
	else:
		logical = Vector2i(roundi(phys.x / ui), roundi(phys.y / ui))
	var vp := SubViewport.new()
	vp.gui_embed_subwindows = true
	vp.size = phys
	if phys != logical:
		vp.size_2d_override = logical
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
	s.set_value("graphics/preload_next_season", false)
	s.set_value("accessibility/reduce_motion", true)
	s.set_value("display/ui_scale", str(roundi(ui * 100.0)))
	s.set_value("game/season_report", "full")
	s.set_value("game/autosave", "off")
	s.set_value("graphics/season_change", "instant")
	s.set_value("game/movement", "instant")
	app.call("set_settings_override", s)
	vp.add_child(app)
	await _wait_frames(3)

	var session := root.get_node_or_null("Session")
	var ok: bool = await _wait_up(app) and await _prepare(app, scene_name, session)
	await _wait_frames(4)
	var window := (app.call("hud") as Object).call("tile_window") as Control
	if ok:
		var map_area := (app.call("hud") as Object).call("map_area") as Control
		print("shot_ui_tile: %s %sx (viewport %s) window %s map %s" % [scene_name, str(ui), str(logical), str(window.get_global_rect()),
			str(map_area.get_global_rect()) if map_area != null else "-"])
	if ok and not headless:
		var tex := vp.get_texture()
		var img := tex.get_image() if tex != null else null
		if img == null or img.is_empty():
			printerr("shot_ui_tile: empty viewport image for %s (%s)" % [scene_name, str(run["name"])])
			ok = false
		else:
			ok = _save(img, scale_dir.path_join("%s.png" % scene_name))
			var rect := window.get_global_rect().grow(CROP_MARGIN)
			var crop := Rect2i(Vector2i(rect.position * ui), Vector2i(rect.size * ui))
			crop = crop.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			ok = ok and _save(img.get_region(crop), scale_dir.path_join("%s_win.png" % scene_name))

	if Engine.has_meta(&"tile_fixture_groups"):
		Engine.remove_meta(&"tile_fixture_groups")
	LAND_FACTS.folded = {}
	if session != null:
		session.call("end_game")
	root.remove_child(vp)
	vp.queue_free()
	await _wait_frames(2)
	return ok


## The UI scale the game picks on this screen with display/ui_scale "auto" (App._resolved_ui_scale's rule), printed.
func _auto_scale() -> float:
	var scr := DisplayServer.get_primary_screen()
	var scale := Display.resolve_ui_scale("auto", OS.get_name(), DisplayServer.screen_get_scale(scr), DisplayServer.screen_get_dpi(scr))
	print("shot_ui_tile: auto UI scale %s (screen scale %s, dpi %d)" % [str(scale), str(DisplayServer.screen_get_scale(scr)),
		DisplayServer.screen_get_dpi(scr)])
	return scale


func _save(img: Image, path: String) -> bool:
	if img.save_png(path) != OK:
		printerr("shot_ui_tile: failed saving %s" % path)
		return false
	return true


## The game is up: its map, no screen over it.
func _wait_up(app: Node) -> bool:
	for _i: int in FRAMES_MAX:
		var stack: Object = app.call("stack") as Object
		if app.call("map_scene") != null and not bool(app.call("is_starting")) and int(stack.call("count")) == 0:
			return true
		await process_frame
	return false


## The scene's state, the hex selected and its tab open; false when something it shows did not come up.
func _prepare(app: Node, scene_name: String, session: Node) -> bool:
	var g: Game = session.get("game") as Game if session != null else null
	if g == null or g.player != GEN:
		return false
	var ms := app.call("map_scene") as Object
	var picks: Dictionary = UiSample.fog(g) if THIN.has(scene_name) else {}
	LAND_FACTS.folded = {}
	if scene_name == "tile_short":
		session.call("dev_money", GEN, 150 - Countries.by_tag(g, GEN).treasury)
	else:
		session.call("dev_money", GEN, DEV_MONEY)
	var hex := Vector2i(-1, -1)
	var tab := &"town"
	match scene_name:
		"tile_own_town", "tile_own_town_facts", "tile_own_town_hover", "tile_own_army", "tile_own_ships", "tile_own_army_1024", "tile_own_town_1024":
			_raise(session, g, 1)
			hex = GENOA
			tab = StringName(scene_name.trim_prefix("tile_own_").trim_suffix("_1024").trim_suffix("_facts").trim_suffix("_hover"))
		"tile_queue_idle":
			hex = _find(g, func(view: Dictionary) -> bool:
				return str(view.get("case", "")) == "own" and bool(view["army"]["raise_offered"]) and view["hex"] != GENOA)
		"tile_building":
			var verdict := session.call("act", "upgrade", {"hex": GENOA, "tag": GEN}) as Dictionary
			if not bool(verdict.get("ok", false)):
				printerr("shot_ui_tile: the upgrade at Genoa was refused: %s" % str(verdict.get("reason", "")))
			hex = GENOA
		"tile_short", "tile_many", "tile_own_town_folded":
			hex = GENOA
		"tile_own_army_cap":
			_raise(session, g, RAISE_CAP)
			hex = GENOA
			tab = &"army"
		"tile_wild_town":
			hex = _find(g, func(view: Dictionary) -> bool:
				return str(view.get("case", "")) == "own" and (view["header"]["picture"] as Dictionary).is_empty())
		"tile_castle_town":
			hex = _find(g, func(view: Dictionary) -> bool:
				return str(view.get("case", "")) == "own" and str((view["header"]["picture"] as Dictionary).get("kind", "")) == "castle")
			if hex.x < 0:
				hex = _find(g, func(view: Dictionary) -> bool:
					return str((view["header"]["picture"] as Dictionary).get("kind", "")) == "castle")
		"tile_foreign_town":
			hex = picks.get("fortress", Vector2i(-1, -1))
		"tile_sight_town":
			hex = _find(g, func(view: Dictionary) -> bool:
				return str(view.get("case", "")) == "foreign" and str(view.get("sight", "")) == "sight")
		"tile_sea_town":
			hex = _find(g, func(view: Dictionary) -> bool:
				return str(view.get("case", "")) == "sea" and (view["hex"] as Vector2i).distance_to(GENOA) < 3.0)
		"tile_deep":
			hex = picks.get("deep", Vector2i(-1, -1))
	if hex.x < 0:
		printerr("shot_ui_tile: %s found no hex" % scene_name)
		return false
	ms.call("frame_at", (ms.call("view") as Object).call("centre_of", hex), 1.0)
	ms.call("select_hex", hex)
	await _wait_frames(4)
	var window := (app.call("hud") as Object).call("tile_window") as Control
	if window == null or not window.visible:
		return false
	if scene_name == "tile_many":
		var stub := GDScript.new()
		stub.source_code = MANY_STUB
		if stub.reload() != OK:
			return false
		Engine.set_meta(&"tile_fixture_groups", _many_groups())
		window.call("use_tabs", [stub] as Array[GDScript])
		await _wait_frames(2)
	var no_tabs := (window.call("tab_ids") as Array).is_empty()
	if not no_tabs and window.call("tab_open") != tab:
		if not bool(window.call("show_tab", tab)):
			printerr("shot_ui_tile: %s: the %s tab is not live" % [scene_name, tab])
			return false
	var node := window.call("tab_node") as Object
	if node != null and node.has_method("finish_now"):
		node.call("finish_now")
	await _wait_frames(2)
	if scene_name == "tile_own_town_facts":
		(window.get_node("%Scroll") as ScrollContainer).scroll_vertical = 100000
	elif scene_name == "tile_own_town_folded":
		var facts := (window.call("tab_node") as Object).call("facts") as Object
		facts.call("set_folded", LAND_FACTS.HEAD_PEOPLE, true)
		facts.call("set_folded", LAND_FACTS.HEAD_MADE, true)
	elif scene_name == "tile_own_town_hover":
		for tile: Control in window.call("building_rows") as Array:
			if not (tile.call("hammer") as Button).disabled:
				tile.mouse_entered.emit()
				break
	_quiet(app)
	await _wait_frames(3)
	print("shot_ui_tile: %s hex %s tabs %s live %s" % [scene_name, str(hex), str(window.call("tab_ids")),
		str(window.call("live_tab_ids"))])
	return true


## The 26-tile fixture of test_tile_window_strips.gd: three groups of 12, 8 and 6 tiles in every state.
func _many_groups() -> Array:
	var out: Array = []
	var n := 0
	for spec: Array in [[&"settlement", "Settlement", 12], [&"land", "Land", 8], [&"harbour", "Harbour", 6]]:
		var rows: Array = []
		for i: int in int(spec[2]):
			var state: StringName = MANY_STATES[n % MANY_STATES.size()]
			rows.append({"id": "fixture:%d" % n, "group": spec[0], "name": "Fixture building %d" % n,
				"icon": ["settlements", "wheat", "vineyard", "harbour", "mines", "timber"][n % 6],
				"option": {} if state == &"built" or state == &"building" else {"action": &"build", "family": 1},
				"state": state, "state_text": "opens in 1495" if state == &"locked" else "state line %d" % n, "tone": &"plain",
				"progress": 0.5, "gain": null, "upkeep": null, "cost": {}, "build_seasons": 2, "payback": {},
				"hammer": state == &"ready", "reason": "" if state == &"ready" else "a fixture reason", "gate": {},
				"level": 2})
			n += 1
		out.append({"id": spec[0], "name": spec[1], "slots": {}, "rows": rows})
	return out


## Raises `count` companies of pikemen at Genoa through the door (an army then stands on the town).
func _raise(session: Node, g: Game, count: int) -> void:
	var kind := 0
	for unit: UnitDef in g.defs.units:
		if unit.key == &"pikemen":
			kind = unit.id
	var verdict := session.call("act", "raise", {"hex": GENOA, "kind": kind, "count": count}) as Dictionary
	if not bool(verdict.get("ok", false)):
		printerr("shot_ui_tile: the raise at Genoa was refused: %s" % str(verdict.get("reason", "")))


## The first hex (by index) whose TileView for Genoa passes `pred`; (-1, -1) when none.
func _find(g: Game, pred: Callable) -> Vector2i:
	for i: int in g.map.hex_count():
		var view := TileView.of(g, GEN, g.map.hex_of(i))
		if not view.is_empty() and bool(pred.call(view)):
			return g.map.hex_of(i)
	return Vector2i(-1, -1)


## Clears what the play left on the map: the floating ribbons and the toasts.
func _quiet(app: Node) -> void:
	var scene := app.call("map_scene") as Node
	var floaters: Node = scene.get_node_or_null("Names/Floaters") if scene != null else null
	if floaters != null:
		floaters.call("clear")
	var host: Node = (app.call("hud") as Node).call("toast_host") as Node
	if host != null:
		for child: Node in host.get_children():
			(child as CanvasItem).visible = false


func _wait_frames(n: int) -> void:
	for _i: int in n:
		await process_frame
