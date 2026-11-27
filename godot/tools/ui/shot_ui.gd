## Renders key Studiolo UI screens at 1x (1280x720) and 2x (2560x1440) into PNG files
## (docs/architecture/ui-and-controls-spec.md section 9; ui-style-and-feedback-spec.md section 11).
## M2 pictures (m2-build-spec.md section 10, names m2_*): the pick with Genoa's panel, the country panel, New game,
## the place search with results, the minimap, Terrain / Owner / Relief at fit and zoom 1 on Genoa, and Owner in the
## colour-blind palette. The arms sheet of all 13 is made by its own tool (C7), not here.
##
## Windowed (GPU or xvfb + Mesa in CI):
##   godot --path godot -s res://tools/ui/shot_ui.gd -- [--out=/tmp/hexa_ui_shots] [--dir=/tmp/hexa_ui_shots] [--scale=1,2]
## M3 pictures (m3-build-spec.md section 9, names m3_*): the season report (an M3 season of Genoa, the quiet one, the
## fixture's nine sections), the top bar with the date and End season, the log open, notifications, the task flag, Save and
## Load with thumbnails (a temporary save folder with three saves), the pause and main menus with Save, Load and Continue,
## and work marks with ribbons. They never touch the real saves or the running lock.
## M4 pictures (m4-build-spec.md section 9, names m4_*): the works card for the vineyard, for Genoa (refused for the ducats) and
## for Savona (refused by a rule), two options pinned, a refused row's hover, the study's This season after a season, the top
## bar with its chips and a chip's hover card, the season report with the Treasury and Goods sections, the card's marks on the
## map, the hex panel's rows and the country panel's treasury. They are made in a Genoa game on a temporary save folder like
## the M3 ones and are compared with the mockups of docs/design/ui/studiolo (works_vineyard, works_genoa, study_econ,
## play_m4, report_m4).
## M4.5 pictures (m4-5-build-spec.md section 9, names m45_*; the scenes are in shot_ui_m45.gd): the study's Districts, Goods,
## Economy History tab, Rankings and History pages, Yields on north Italy with its legend and its hover card, the action log
## with older headers and the timeline after 40 seasons. They are made in the owner's playtest game (Genoa on seed 1480 at
## Spring 1483, calm weather) on a temporary save folder and are compared with the mockup renders of tests/fixtures/mockup.
## M5 pictures (m5-build-spec.md section 9, names m5_*; the scenes are in shot_ui_m5.gd): the People page, the top bar chips
## with the People and Food cards, the hex panel People section for a hex of yours, a known and an unknown country, the
## country panel people row, the Food mode with its legend, the report People section, the hunger notification and flag line,
## and the village near Turin before and after it grew. Genoa on seed 1480, calm weather, on a temporary save folder.
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
const M2_SCENES: Array[String] = [
	"m2_pick",
	"m2_country_panel",
	"m2_new_game",
	"m2_find_place",
	"m2_minimap",
	"m2_terrain_fit",
	"m2_terrain_zoom1",
	"m2_owner_fit",
	"m2_owner_zoom1",
	"m2_relief_fit",
	"m2_relief_zoom1",
	"m2_owner_fit_colour_blind",
]
const M3_SCENES: Array[String] = [
	"m3_report_genoa",
	"m3_report_quiet",
	"m3_report_nine",
	"m3_top_bar",
	"m3_log_open",
	"m3_notifications",
	"m3_task_flag",
	"m3_save_screen",
	"m3_load_screen",
	"m3_pause_menu",
	"m3_main_menu",
	"m3_work_marks",
]
const M4_SCENES: Array[String] = [
	"m4_card_vineyard",
	"m4_card_genoa",
	"m4_card_savona",
	"m4_card_pinned",
	"m4_row_refused_hover",
	"m4_study_economy",
	"m4_top_bar_chips",
	"m4_report_money",
	"m4_map_marks",
	"m4_hex_panel_rows",
	"m4_country_panel",
]
const M45 := preload("res://tools/ui/shot_ui_m45.gd")
const M5 := preload("res://tools/ui/shot_ui_m5.gd")
const M3_SAVE_DIR := "user://shot_ui_saves"
const M3_LOCK := "user://shot_ui_running.lock"
const M3_SAVES: Array[Dictionary] = [
	{"slot": "quick", "name": ""},
	{"slot": "1", "name": "Before the vintage"},
	{"slot": "2", "name": "Walls for Genoa"},
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

	var known := _all_scenes()
	var target_scenes: Array[String] = known if _only.is_empty() else _only
	var rendered := 0
	var saved := 0

	for scale_mult: int in _scales:
		var scale_dir := global_out.path_join("%dx" % scale_mult)
		DirAccess.make_dir_recursive_absolute(scale_dir)
		for scene_name: String in target_scenes:
			if not known.has(scene_name):
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
	var m3 := scene_name.begins_with("m3_") or scene_name.begins_with("m4_") or scene_name.begins_with("m45_") or scene_name.begins_with("m5_")
	if m3:
		_m3_disk_begin()
	var vp := SubViewport.new()
	var phys_size := LOGICAL_SIZE * scale_mult
	vp.size = phys_size
	if scale_mult > 1:
		vp.size_2d_override = LOGICAL_SIZE
		vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	root.add_child(vp)

	var app := packed.instantiate()
	app.set("settings_path", "")
	app.set("allow_tree_quit", false)
	app.set("pause_tree_when_modal", false)
	app.set("skip_loading_frames", true)
	var cli := _cli_for(scene_name)
	if cli.size() > 0:
		app.set("cli_args_override", cli)
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("map/parchment", false)  # these pictures show the tiles, framed whole too (map-overview PM5)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("accessibility/reduce_motion", true)
	s.set_value("display/ui_scale", "100" if scale_mult == 1 else "200")
	var extra := _settings_for(scene_name)
	for key: String in extra.keys():
		s.set_value(key, extra[key])
	app.call("set_settings_override", s)
	vp.add_child(app)

	await _wait_frames(3)

	var ok: bool = await _prepare_scene(app, scene_name)
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
	if m3:
		_m3_disk_end()
	return ok


func _prepare_scene(app: Node, scene_name: String) -> bool:
	var stack := app.call("stack") as Control
	var ctx := app.call("context") as ShellContext
	if stack == null or ctx == null:
		return false
	if scene_name.begins_with("m2_"):
		return _prepare_m2(app, stack, ctx, scene_name)
	if scene_name.begins_with("m3_"):
		return await _prepare_m3(app, stack, ctx, scene_name)
	if scene_name.begins_with("m4_"):
		return await _prepare_m4(app, scene_name)
	if scene_name.begins_with("m45_"):
		return await M45.prepare(self, app, scene_name)
	if scene_name.begins_with("m5_"):
		return await M5.prepare(self, app, scene_name)
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
			var hex_panel := hud_node.call("tile_window") as CanvasItem
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


func _all_scenes() -> Array[String]:
	var out: Array[String] = []
	out.append_array(SCENES)
	out.append_array(M2_SCENES)
	out.append_array(M3_SCENES)
	out.append_array(M4_SCENES)
	out.append_array(M45.SCENES)
	out.append_array(M5.SCENES)
	return out


## The command line of a scene: the M2 pictures start a New game (the pick, or Genoa from --country=GEN).
func _cli_for(scene_name: String) -> PackedStringArray:
	if scene_name == "m2_new_game":
		return PackedStringArray()
	if scene_name == "m2_pick":
		return PackedStringArray(["--new-game", "--seed=1480"])
	if scene_name.begins_with("m2_") or scene_name.begins_with("m3_") or scene_name.begins_with("m4_") or scene_name.begins_with("m45_") or scene_name.begins_with("m5_"):
		return PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"])
	if scene_name in ["hud", "pause_menu", "options", "about", "help", "confirm"]:
		return PackedStringArray(["--sandbox", "--seed=1480"])
	return PackedStringArray()


## Settings of a scene: the map mode and the palette of the M2 map pictures.
func _settings_for(scene_name: String) -> Dictionary:
	var out := {}
	if scene_name.begins_with("m3_") or scene_name.begins_with("m4_") or scene_name.begins_with("m45_") or scene_name.begins_with("m5_"):
		out["game/season_report"] = "full"
		out["game/autosave"] = "off"
		out["graphics/season_change"] = "instant"
		return out
	if not scene_name.begins_with("m2_"):
		return out
	if scene_name.contains("terrain"):
		out["state/map_mode"] = "terrain"
	elif scene_name.contains("owner"):
		out["state/map_mode"] = "owner"
	elif scene_name.contains("relief"):
		out["state/map_mode"] = "relief"
	if scene_name.ends_with("colour_blind"):
		out["accessibility/country_colours"] = "colour_blind"
	return out


func _prepare_m2(app: Node, stack: Control, ctx: ShellContext, scene_name: String) -> bool:
	if scene_name == "m2_new_game":
		ctx.request(&"open_screen", {"id": &"new_game"})
		var top_n := stack.call("top") as Node
		return top_n != null and top_n.get("screen_id") == &"new_game"
	if scene_name == "m2_pick":
		var top_p := stack.call("top") as Node
		if top_p == null or top_p.get("screen_id") != &"country_pick":
			return false
		top_p.call("show_country", &"GEN")
		return true
	var session := root.get_node_or_null("Session")
	var g: Game = session.get("game") as Game if session != null else null
	var ms := app.call("map_scene") as Node
	var hud_node := app.call("hud") as Node
	if g == null or ms == null or hud_node == null or not g.has_countries() or g.player == &"":
		return false
	if scene_name == "m2_country_panel":
		hud_node.call("show_country", g.player, false)
		return true
	if scene_name == "m2_find_place":
		var screen_ids := ResourceLoader.load(SCREEN_IDS_PATH) as GDScript
		if screen_ids == null:
			return false
		var find := screen_ids.call("make", &"find_place") as Node
		if find == null:
			return false
		stack.call("push", find)
		find.call("set_query", "Gen")
		return stack.call("top") == find
	if scene_name == "m2_minimap":
		return hud_node.call("minimap") != null
	# The map pictures: Genoa at fit, or at zoom 1 (the art size) centred on her focus hex.
	if scene_name.contains("zoom1"):
		var card := CountryCard.of(g, g.player)
		var focus := card["focus"] as Vector2i
		var view_node := ms.call("view") as Node
		if view_node == null:
			return false
		ms.call("frame_at", view_node.call("centre_of", focus), 1.0)
	else:
		ms.call("fit")
	return true


# ----- M3 pictures ----------------------------------------------------------------------------------------------------------


var _m3_old_dir := ""
var _m3_old_lock := ""


## Points the saves and the running lock at temporary places; nothing of the player's is read or written.
func _m3_disk_begin() -> void:
	var session := root.get_node_or_null("Session")
	if session == null:
		return
	_m3_old_dir = str(session.get("save_dir"))
	_m3_old_lock = RunLock.path
	session.set("save_dir", M3_SAVE_DIR)
	RunLock.path = M3_LOCK
	_m3_clean()


func _m3_disk_end() -> void:
	var session := root.get_node_or_null("Session")
	_m3_clean()
	if session != null:
		session.set("save_dir", _m3_old_dir)
	RunLock.path = _m3_old_lock


func _m3_clean() -> void:
	var dir := DirAccess.open(M3_SAVE_DIR)
	if dir != null:
		for file: String in dir.get_files():
			DirAccess.remove_absolute(M3_SAVE_DIR.path_join(file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(M3_SAVE_DIR))
	RunLock.clear()


## Starts one work on each of `count` hexes the player owns, nearest to `near` first; returns the hexes.
func _m3_begin_works(g: Game, count: int, near: Vector2i) -> Array[Vector2i]:
	var session := root.get_node("Session")
	var found: Array[Dictionary] = []
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 0 or Territory.owner_tag(g, hex) != g.player or not Improve.piece_at(g, hex).is_empty():
			continue
		for option: Dictionary in Improve.build_options(g, hex):
			if bool(option["ok"]) and bool((session.call("check", "build", {"hex": hex, "family": int(option["family_id"])}) as Dictionary)["ok"]):
				found.append({"hex": hex, "family": int(option["family_id"]), "d": (hex - near).length_squared()})
				break
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["d"]) < int(b["d"]))
	var out: Array[Vector2i] = []
	for entry: Dictionary in found:
		if out.size() >= count:
			break
		var verdict := session.call("act", "build", {"hex": entry["hex"], "family": entry["family"]}) as Dictionary
		if bool(verdict.get("ok", false)):
			out.append(entry["hex"] as Vector2i)
	return out


func _m3_season(g: Game, near: Vector2i) -> void:
	_m3_begin_works(g, 2, near)
	root.get_node("Session").call("end_season")


## Saves the three pictures' games: the real map as the thumbnail (null headless), a season between each.
func _m3_make_saves(app: Node, g: Game, near: Vector2i) -> void:
	var session := root.get_node("Session")
	var layers: Array[CanvasLayer] = []
	var hud_layer := app.call("hud") as CanvasLayer
	if hud_layer != null:
		layers.append(hud_layer)
	var screens := app.get_node_or_null("Screens") as CanvasLayer
	if screens != null:
		layers.append(screens)
	for entry: Dictionary in M3_SAVES:
		_m3_season(g, near)
		await _wait_frames(2)
		var thumb: Image = await Thumbnail.take(app.get_viewport(), layers)
		session.call("save_game", str(entry["slot"]), thumb, {}, str(entry["name"]))


func _prepare_m3(app: Node, stack: Control, ctx: ShellContext, scene_name: String) -> bool:
	var session := root.get_node_or_null("Session")
	var g: Game = session.get("game") as Game if session != null else null
	var ms := app.call("map_scene") as Node
	var hud_node := app.call("hud") as Node
	if g == null or ms == null or hud_node == null or not g.has_countries() or g.player == &"":
		return false
	var focus := CountryCard.of(g, g.player)["focus"] as Vector2i
	var view_node := ms.call("view") as Node
	var screen_ids := ResourceLoader.load(SCREEN_IDS_PATH) as GDScript
	match scene_name:
		"m3_report_genoa":
			_m3_begin_works(g, 3, focus)
			session.call("end_season")
			_m3_begin_works(g, 2, focus)
			session.call("end_season")
			var summary := SeasonSummary.of(g, g.player, g.turn - 1)
			return _m3_push_report(stack, screen_ids, summary)
		"m3_report_quiet":
			return _m3_push_report(stack, screen_ids, ReportSample.quiet_season())
		"m3_report_nine":
			return _m3_push_report(stack, screen_ids, ReportSample.genoa_spring())
		"m3_top_bar":
			_m3_season(g, focus)
			await _wait_frames(2)
			return hud_node.call("date_end") != null
		"m3_log_open":
			_m3_season(g, focus)
			_m3_season(g, focus)
			await _wait_frames(2)
			var log_card := hud_node.call("action_log") as Node
			log_card.call("open")
			return bool(log_card.call("is_open"))
		"m3_notifications":
			var notes := hud_node.call("notifications") as Node
			var lines: Array[Dictionary] = [
				{"text": "Finished: a vineyard near Genoa.", "tone": "good", "hex": focus, "turn": g.turn, "notify": true},
				{"text": "Cancelled: the walls, the land was lost.", "tone": "bad", "hex": focus, "turn": g.turn, "notify": true},
				{"text": "Finished: a granary at the harbour.", "tone": "good", "hex": focus, "turn": g.turn, "notify": true},
			]
			for line: Dictionary in lines:
				notes.call("add_line", line)
			await _wait_frames(2)
			return int(notes.call("card_count")) > 0
		"m3_task_flag":
			var flag := hud_node.call("task_flag") as Node
			flag.call("refresh")
			flag.call("open_list")
			await _wait_frames(2)
			return bool(flag.call("is_list_open"))
		"m3_save_screen", "m3_load_screen":
			await _m3_make_saves(app, g, focus)
			var save_load := screen_ids.call("make", &"save_load") as Node
			if save_load == null:
				return false
			save_load.set("start_tab", &"save" if scene_name == "m3_save_screen" else &"load")
			stack.call("push", save_load)
			await _wait_frames(6)  # the thumbnails load two a frame
			return _top_is(stack, &"save_load")
		"m3_pause_menu":
			await _m3_make_saves(app, g, focus)
			ctx.request(&"pause")
			return _top_is(stack, &"pause_menu")
		"m3_main_menu":
			await _m3_make_saves(app, g, focus)
			ctx.request(&"main_menu")
			await _wait_frames(2)
			return _top_is(stack, &"main_menu")
		"m3_work_marks":
			if view_node == null:
				return false
			ms.call("frame_at", view_node.call("centre_of", focus), 1.0)
			await _wait_frames(3)  # the floaters learn the view
			var hexes := _m3_begin_works(g, 4, focus)
			await _wait_frames(2)
			var floaters := ms.get_node_or_null("Names/Floaters")
			if floaters != null:
				floaters.call("advance", 0.35)  # ribbons mid-rise
			return not hexes.is_empty()
	return false


# ----- M4 pictures ----------------------------------------------------------------------------------------------------------
# Everything of the shell is reached through call() and get(), as in the M3 pictures: this script compiles before the autoloads.


## Hexes of the Genoa scenario on seed 1480 (m4-build-spec.md 1.1): Genoa the walled town, Savona the town, the vineyard
## above Savona, and the wild woods by the sea east of Genoa.
const M4_GENOA := Vector2i(8, 13)
const M4_SAVONA := Vector2i(6, 13)
const M4_VINEYARD := Vector2i(7, 12)
const M4_WOODS := Vector2i(10, 13)
const M4_CARD_KEY := "card"


## The row U acts on (WorksFlow.upgrade_row): the upgrade of a piece, even refused, else the first build wild land allows.
func _m4_upgrade_row(g: Game, hex: Vector2i) -> Dictionary:
	var rows := ImprovePreview.options_of(g, g.player, hex)
	for row: Dictionary in rows:
		if StringName(str(row["action"])) == Works.UPGRADE:
			return row
	for row: Dictionary in rows:
		if StringName(str(row["action"])) == Works.BUILD and bool((row["verdict"] as Dictionary)["ok"]):
			return row
	return {}


func _m4_top_id(app: Node) -> StringName:
	var top := (app.call("stack") as Control).call("top") as Node
	return StringName(str(top.get("screen_id"))) if top != null else &""


## Selects `hex`, then opens the works card of its upgrade beside the hex panel as U does; the card's ghost and marks go on
## the map. False when the hex has no such row or the card did not open.
func _m4_card_for(app: Node, g: Game, hex: Vector2i) -> bool:
	var row := _m4_upgrade_row(g, hex)
	if row.is_empty():
		return false
	(app.call("map_scene") as Node).call("select_hex", hex)
	await _wait_frames(2)
	var works: Object = (app.call("requests") as Object).get("works")
	works.call("show_card", hex, {"action": row["action"], "family": row["family"]}, true)
	await _wait_frames(3)
	return _m4_top_id(app) == &"works_preview"


## The tile window's action buttons (Cancel the work, then the row hammers), as an untyped list of Buttons.
func _m4_rows(app: Node) -> Array[Button]:
	var out: Array[Button] = []
	var panel := (app.call("hud") as Node).call("tile_window") as Node
	for raw: Variant in panel.call("action_buttons"):
		out.append(raw as Button)
	return out


func _m4_row(app: Node, prefix: String) -> Button:
	for button: Button in _m4_rows(app):
		if button.text.begins_with(prefix):
			return button
	return null


func _prepare_m4(app: Node, scene_name: String) -> bool:
	var session := root.get_node_or_null("Session")
	var g: Game = session.get("game") as Game if session != null else null
	var scene := app.call("map_scene") as Node
	var hud_node := app.call("hud") as Node
	if g == null or scene == null or hud_node == null or not g.has_countries() or g.player == &"":
		return false
	var focus := CountryCard.of(g, g.player)["focus"] as Vector2i
	var view_node := scene.call("view") as Node
	var works: Object = (app.call("requests") as Object).get("works")
	match scene_name:
		"m4_card_vineyard":
			return await _m4_card_for(app, g, M4_VINEYARD)
		"m4_card_genoa":
			return await _m4_card_for(app, g, M4_GENOA)
		"m4_card_savona":
			return await _m4_card_for(app, g, M4_SAVONA)
		"m4_card_pinned":
			scene.call("select_hex", M4_WOODS)
			await _wait_frames(3)
			var rows := _m4_rows(app)
			var first := _m4_row(app, "Build woodland")
			var second := _m4_row(app, "Build harbour")
			if first == null and not rows.is_empty():
				first = rows[0]
			if second == null and rows.size() > 1:
				second = rows[rows.size() - 1]
			if first == null or second == null or first == second:
				return false
			first.mouse_entered.emit()
			await _wait_frames(2)
			var card := (app.call("stack") as Control).call("top") as Node
			if card == null or _m4_top_id(app) != &"works_preview":
				return false
			card.call("pin", true)
			first.mouse_exited.emit()
			await _wait_frames(2)
			second.mouse_entered.emit()  # the next option opens beside the pinned one, on one scale
			await _wait_frames(3)
			return (app.call("stack") as Control).call("top") == card and bool(card.call("pinned"))
		"m4_row_refused_hover":
			# A row the treasury or a rule refuses: Genoa's city (ducats), else Savona's walls (the town rule).
			for hex: Vector2i in [M4_GENOA, M4_SAVONA]:
				scene.call("select_hex", hex)
				await _wait_frames(3)
				for button: Button in _m4_rows(app):
					if button.disabled:
						button.mouse_entered.emit()
						await _wait_frames(3)
						return _m4_top_id(app) == &"works_preview"
			return false
		"m4_study_economy":
			_m3_season(g, focus)
			await _wait_frames(2)
			works.call("open_study", &"economy")
			await _wait_frames(4)
			return _m4_top_id(app) == &"study"
		"m4_top_bar_chips":
			_m3_season(g, focus)
			await _wait_frames(3)
			var chips := hud_node.call("chips") as Control
			var chip := chips.call("ducats_chip") as Control
			var hover := chip.call("_make_custom_tooltip", M4_CARD_KEY) as Control
			if hover == null:
				return false
			hud_node.add_child(hover)  # the card a pointer on the chip shows, drawn under it
			var at := chip.get_global_rect()
			hover.position = Vector2(at.position.x, at.end.y + 6.0)
			await _wait_frames(3)
			return chips.is_visible_in_tree()
		"m4_report_money":
			_m3_begin_works(g, 2, focus)
			session.call("end_season")
			var screen_ids := ResourceLoader.load(SCREEN_IDS_PATH) as GDScript
			return _m3_push_report(app.call("stack") as Control, screen_ids, SeasonSummary.of(g, g.player, g.turn - 1))
		"m4_map_marks":
			if view_node == null:
				return false
			scene.call("frame_at", view_node.call("centre_of", M4_VINEYARD), 1.0)
			await _wait_frames(3)
			var opened := await _m4_card_for(app, g, M4_VINEYARD)
			return opened and bool((scene.call("preview_marks") as Object).call("shown"))
		"m4_hex_panel_rows":
			scene.call("select_hex", M4_WOODS)
			if view_node != null:
				scene.call("frame_at", view_node.call("centre_of", M4_WOODS), 1.0)
			await _wait_frames(3)
			var panel := hud_node.call("tile_window") as Control
			return panel.is_visible_in_tree() and not _m4_rows(app).is_empty()
		"m4_country_panel":
			hud_node.call("show_country", g.player, false)
			await _wait_frames(3)
			var country_panel := hud_node.call("country_panel") as Control
			return country_panel.is_visible_in_tree() and bool(country_panel.call("treasury_visible"))
	return false


func _top_is(stack: Control, screen_id: StringName) -> bool:
	var top := stack.call("top") as Node
	return top != null and top.get("screen_id") == screen_id


func _m3_push_report(stack: Control, screen_ids: GDScript, summary: Dictionary) -> bool:
	if screen_ids == null:
		return false
	var report := screen_ids.call("make", &"season_report") as Node
	if report == null:
		return false
	report.call("show_summary", summary, false)
	stack.call("push", report)
	return stack.call("top") == report


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
