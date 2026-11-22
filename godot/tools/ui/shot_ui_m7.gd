## The M7 pictures (m7-build-spec.md section 9, names m7_*): the war on north Italy's map the way a player meets it. A standalone
## script, split from shot_ui.gd like shot_ui_m6.gd (its CLI and capture loop are copied from there). Each picture is made in a
## Savoy game on seed 1480 with calm weather, a temporary save folder and the war sample of tests/fixtures/ui_sample.gd: Milan's
## army at Alessandria and Savoy's at Vercelli, the war declared through the door, a battle Savoy won at Alessandria and one it lost
## at Vercelli (last season), a siege of Pavia with Savoy's army before it and a Milanese district held by Savoy. The pictures:
##   m7_dock_live          the battle dock on day 1 of the battle Savoy won
##   m7_dock_after         the same dock on its last day, with the result
##   m7_dock_lost          the dock of the battle Savoy lost
##   m7_odds_card          the odds card of Savoy's army against Milan's army at Alessandria
##   m7_odds_siege         the odds card of Savoy's army against the castle of Pavia, which Savoy besieges
##   m7_odds_held          the odds card over Milanese land that its castle holds
##   m7_hex_panel_war      the hex panel of Pavia: the fortress, its area, the siege block
##   m7_army_panel_war     the army panel of the besieging army: standing, morale, the siege and Storm now
##   m7_military_page      the Military page with its Wars and Battles tables
##   m7_report_war         the season report with its War section after a battle fought in the season
##   m7_overlay_stripes    Owner mode with the occupied district's stripes (the standard palette)
##   m7_overlay_stripes_cb the same with the colour-blind safe palette
##   m7_castle_areas       the castle areas (tint and dashed lines) with an army selected
##   m7_war_marks          the battle badges and the siege dial on the map
##   m7_siege_dial_close   the siege dial of Pavia, close
##   m7_country_war        Milan's country panel at war: its war section and the peace options
##   m7_declare_confirm    the Confirm of a declaration of war (no war yet)
##   m7_war_alert          the war alert: a war declared on Savoy
##   m7_replay_badge       the movement replay of the season with a battle: the faint battle badge
##
## Windowed (GPU or xvfb + Mesa):
##   godot --path godot -s res://tools/ui/shot_ui_m7.gd -- --out=DIR [--dir=DIR] [--scale=1,2] [--only=m7_dock_live,...]
## Each scene is written to DIR/1x/NAME.png (1280 x 720) and DIR/2x/NAME.png (2560 x 1440). Headless (the dummy renderer,
## `DisplayServer` headless) it prepares every scene at the given scales and exits 0 without writing PNGs; a scene that does
## not come up exits 1 and says which.
extends SceneTree

const DEFAULT_OUT_DIR := "/tmp/hexa_ui_shots_m7"
const APP_SCENE_PATH := "res://shell/app/app.tscn"
const SCREEN_IDS_PATH := "res://shell/screens/screen_ids.gd"
const LOGICAL_H := 720
const LOGICAL_W := 1280
const TAG := &"SAV"
const MLO := &"MLO"
const VERCELLI := Vector2i(6, 9)
const ALESS := Vector2i(7, 9)
const PAVIA := Vector2i(10, 9)
## SeasonFlow.State.REPLAY (the shell's classes compile after the autoloads, so the number stands for it here).
const REPLAY_STATE := 2
const SCENES: Array[String] = [
	"m7_dock_live",
	"m7_dock_after",
	"m7_dock_lost",
	"m7_odds_card",
	"m7_odds_siege",
	"m7_odds_held",
	"m7_hex_panel_war",
	"m7_army_panel_war",
	"m7_military_page",
	"m7_report_war",
	"m7_overlay_stripes",
	"m7_overlay_stripes_cb",
	"m7_castle_areas",
	"m7_war_marks",
	"m7_siege_dial_close",
	"m7_country_war",
	"m7_declare_confirm",
	"m7_war_alert",
	"m7_replay_badge",
]
## The scenes whose movement replay is on (every other scene plays its seasons with the replay off).
const REPLAY_SCENES: Array[String] = ["m7_replay_badge"]
## The scenes made in a game with no war yet (no sample).
const PEACE_SCENES: Array[String] = ["m7_declare_confirm", "m7_war_alert"]
## The scenes drawn with the colour-blind safe country colours.
const COLOUR_BLIND_SCENES: Array[String] = ["m7_overlay_stripes_cb"]
const SEASONS_MAX := 5
## Frames at most the replay scene waits for the faint battle badge.
const REPLAY_FRAMES := 240

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
		printerr("shot_ui_m7: cannot load %s" % APP_SCENE_PATH)
		return 1
	var target_scenes: Array[String] = SCENES if _only.is_empty() else _only
	var rendered := 0
	var saved := 0
	for scale_mult: int in _scales:
		var scale_dir := global_out.path_join("%dx" % scale_mult)
		DirAccess.make_dir_recursive_absolute(scale_dir)
		for scene_name: String in target_scenes:
			if not SCENES.has(scene_name):
				printerr("shot_ui_m7: unknown scene '%s'" % scene_name)
				return 1
			var ok := await _capture_one(packed, scene_name, scale_mult, scale_dir, headless)
			if not ok:
				printerr("shot_ui_m7: %s did not come up at %dx" % [scene_name, scale_mult])
				return 1
			rendered += 1
			if not headless:
				saved += 1
	if headless:
		print("shot_ui_m7: headless dummy renderer; prepared %d scene renders (%s) without PNG output" % [rendered, global_out])
	else:
		print("shot_ui_m7: saved %d UI pictures to %s" % [saved, global_out])
	return 0


func _capture_one(packed: PackedScene, scene_name: String, scale_mult: int, scale_dir: String, headless: bool) -> bool:
	var vp := SubViewport.new()
	vp.gui_embed_subwindows = true  # the hex menu is a PopupMenu (a window): embedded, the viewport's capture holds it
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
	app.set("cli_args_override", PackedStringArray(["--new-game", "--country=SAV", "--seed=1480"]))
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("accessibility/reduce_motion", not REPLAY_SCENES.has(scene_name))
	s.set_value("display/ui_scale", "100" if scale_mult == 1 else "200")
	s.set_value("game/season_report", "full")
	s.set_value("game/autosave", "off")
	s.set_value("graphics/season_change", "instant")
	s.set_value("game/movement", "normal" if REPLAY_SCENES.has(scene_name) else "instant")
	if COLOUR_BLIND_SCENES.has(scene_name):
		s.set_value("accessibility/country_colours", "colour_blind")
	app.call("set_settings_override", s)
	vp.add_child(app)
	await _wait_frames(3)

	var ok: bool = await _prepare_scene(app, scene_name)
	await _wait_frames(3)
	_quiet(app)  # the notifications and ribbons of the sample's events would sit on the picture
	await _wait_frames(2)
	if ok and not headless:
		var tex := vp.get_texture()
		var img := tex.get_image() if tex != null else null
		if img == null or img.is_empty():
			printerr("shot_ui_m7: empty viewport image for %s (%dx)" % [scene_name, scale_mult])
			ok = false
		else:
			var png_path := scale_dir.path_join("%s.png" % scene_name)
			if img.save_png(png_path) != OK:
				printerr("shot_ui_m7: failed saving %s" % png_path)
				ok = false

	var session := root.get_node_or_null("Session")
	if session != null:
		session.call("end_game")
	root.remove_child(vp)
	vp.queue_free()
	await _wait_frames(2)
	return ok


func _wait_frames(n: int) -> void:
	for _i: int in n:
		await process_frame


static func _frames(tree: SceneTree, n: int) -> void:
	for _i: int in n:
		await tree.process_frame


static func _press_key(app: Node, key: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.pressed = pressed
		app.get_viewport().push_input(ev)


## Calm weather on a copy of the defs (the war pictures show the fighting, not the weather).
static func _calm(g: Game) -> void:
	var d := PeopleFixture.copy_of(g.defs)
	d.weather_odds = PackedInt32Array([100, 0, 0])
	g.defs = d


static func _play(session: Node, seasons: int) -> void:
	for _n: int in seasons:
		session.call("end_season")


static func _armies(app: Node) -> Node:
	var scene := app.call("map_scene") as Node
	return scene.get_node_or_null("MapArmies") if scene != null else null


## The map's war layer takes the sample's records, siege and district (written into the game, not made by events).
static func _refresh_war(app: Node) -> void:
	var scene := app.call("map_scene") as Node
	var wars := scene.get_node_or_null("MapWars") as Node if scene != null else null
	if wars != null:
		wars.call("_on_war_event")


## The camera on `hex` at `zoom`, a few frames to settle.
static func _frame_on(tree: SceneTree, scene: Node, hex: Vector2i, zoom: float) -> void:
	var view_node := scene.call("view") as Node
	scene.call("frame_at", view_node.call("centre_of", hex), zoom)
	await _frames(tree, 4)


## Clears what the play left on the map: the floating ribbons and the toasts.
static func _quiet(app: Node) -> void:
	var scene := app.call("map_scene") as Node
	var floaters: Node = scene.get_node_or_null("Names/Floaters") if scene != null else null
	if floaters != null:
		floaters.call("clear")
	var hud_node := app.call("hud") as Node
	var notes: Node = hud_node.call("notifications") as Node if hud_node != null else null
	if notes != null:
		notes.call("clear")
	var host: Node = hud_node.call("toast_host") as Node if hud_node != null else null
	if host != null:
		if host.has_method("clear"):
			host.call("clear")
		else:
			for child: Node in host.get_children():
				(child as CanvasItem).visible = false


## The picture `scene_name`; false when something it shows did not come up.
static func _prepare_scene(app: Node, scene_name: String) -> bool:
	var session := app.get_tree().root.get_node_or_null("Session")
	var g: Game = session.get("game") as Game if session != null else null
	var scene := app.call("map_scene") as Node
	var hud_node := app.call("hud") as Node
	if g == null or scene == null or hud_node == null or not g.has_countries() or g.player != TAG:
		printerr("shot_ui_m7: no Savoy game (game %s, player %s)" % [str(g != null), str(g.player) if g != null else "-"])
		return false
	var tree: SceneTree = app.get_tree()
	_calm(g)
	var sample := {}
	if not PEACE_SCENES.has(scene_name):
		sample = UiSample.war(session, g)
		if not bool(sample["ok"]):
			printerr("shot_ui_m7: the war sample did not come up: %s" % str(sample["problem"]))
			return false
		_refresh_war(app)
		await _frames(tree, 3)
		_quiet(app)
	match scene_name:
		"m7_dock_live", "m7_dock_after", "m7_dock_lost":
			return await _dock(tree, app, scene_name, sample)
		"m7_odds_card", "m7_odds_siege", "m7_odds_held":
			return await _odds(tree, app, scene, hud_node, scene_name, sample)
		"m7_hex_panel_war":
			await _frame_on(tree, scene, PAVIA, 0.7)
			scene.call("select_hex", PAVIA)
			await _frames(tree, 4)
			var panel := scene.call("panel") as Control
			return panel != null and panel.is_visible_in_tree()
		"m7_army_panel_war":
			_armies(app).call("select_army", int(sample["siege_army"]))
			await _frames(tree, 4)
			var army_panel := hud_node.call("army_panel") as Control
			return army_panel.visible and int(army_panel.call("shown_army")) == int(sample["siege_army"])
		_:
			return await _prepare_more(tree, session, app, g, hud_node, scene, scene_name, sample)


## The dock: on the first day of the won battle, on its last day, and on the lost one.
static func _dock(tree: SceneTree, app: Node, scene_name: String, sample: Dictionary) -> bool:
	var war := (app.call("requests") as Object).get("war") as Object
	var record := int(sample["lost"]) if scene_name == "m7_dock_lost" else int(sample["won"])
	if not bool(war.call("open_battle", record)):
		return false
	await _frames(tree, 3)
	var dock := war.call("dock") as Object
	if dock == null:
		return false
	if scene_name == "m7_dock_live":
		dock.call("go_to_day", 1)
	await _frames(tree, 4)
	return dock.call("shown_record") == record


## The odds card over the target of the selected army: Milan's army, the castle under siege, held land.
static func _odds(tree: SceneTree, app: Node, scene: Node, hud_node: Node, scene_name: String, sample: Dictionary) -> bool:
	var armies := _armies(app)
	var goal := ALESS
	var army := int(sample["savoy_army"])
	if scene_name == "m7_odds_siege":
		goal = PAVIA
	elif scene_name == "m7_odds_held":
		goal = sample["area"] as Vector2i
	await _frame_on(tree, scene, goal if scene_name != "m7_odds_card" else VERCELLI, 0.9)
	armies.call("select_army", army)
	await _frames(tree, 3)
	var at := (scene.call("view") as CanvasItem).get_global_transform_with_canvas() * ((scene.call("view") as Node).call("centre_of", goal) as Vector2)
	(hud_node.call("map_hover") as Object).call("order_cursor_moved", goal, at)
	await _frames(tree, 4)
	var card := (hud_node.call("map_hover") as Object).call("odds_card") as Object
	var open := card != null and bool(card.call("is_open"))
	if not open:
		var game := app.get_tree().root.get_node("Session").get("game") as Game
		var preview := MovePreview.to(game, TAG, army, goal)
		printerr("shot_ui_m7: no odds card at %s: the march says '%s', the odds kind is '%s'" % [str(goal),
			str((preview["verdict"] as Dictionary).get("reason", "ok")), str((preview.get("odds", {}) as Dictionary).get("kind", ""))])
	return open


## The pages, the report, the overlay, the marks, the country panel, the Confirms and the replay.
static func _prepare_more(tree: SceneTree, session: Node, app: Node, g: Game, hud_node: Node, scene: Node, scene_name: String,
		sample: Dictionary) -> bool:
	var works: Object = (app.call("requests") as Object).get("works")
	match scene_name:
		"m7_military_page":
			works.call("open_study", &"military", {})
			await _frames(tree, 4)
			var top := (app.call("stack") as Control).call("top") as Node
			return top != null and top.get("screen_id") == &"study" and top.call("current_page_id") == &"military"
		"m7_overlay_stripes", "m7_overlay_stripes_cb":
			_press_key(app, KEY_2)
			await _frame_on(tree, scene, sample["occupied"] as Vector2i, 0.9)
			return int(scene.call("mode")) == int(MapModes.Mode.OWNER)
		"m7_castle_areas":
			await _frame_on(tree, scene, PAVIA, 0.55)
			_armies(app).call("select_army", int(sample["savoy_army"]))
			await _frames(tree, 4)
			var wars := scene.get_node_or_null("MapWars") as Node
			if wars == null:
				return false
			wars.call("finish_areas")
			await _frames(tree, 3)
			return bool(wars.call("area_gate"))
		"m7_war_marks", "m7_siege_dial_close":
			var close := scene_name == "m7_siege_dial_close"
			await _frame_on(tree, scene, PAVIA if close else Vector2i(floori(float(ALESS.x + PAVIA.x) / 2.0), ALESS.y), 1.5 if close else 0.6)
			var marks := scene.get_node_or_null("WarMarks") as Node
			return marks != null and int(marks.call("mark_count")) >= 3
		"m7_country_war":
			(app.call("context") as Object).call("request", &"country", {"tag": MLO})
			await _frames(tree, 4)
			var panel := hud_node.call("country_panel") as Control
			return panel != null and panel.visible
		"m7_declare_confirm":
			(app.call("context") as Object).call("request", &"declare_war", {"target": MLO})
			await _frames(tree, 4)
			return _confirm_up(app)
		"m7_war_alert":
			var declared := session.call("act", "declare_war", {"target": TAG, "tag": MLO}) as Dictionary
			await _frames(tree, 4)
			return bool(declared.get("ok", false)) and _confirm_up(app)
	return await _prepare_season(tree, session, app, g, scene_name, sample)


## The report and the replay: both need a battle fought in a season of the sample (Savoy's army at Vercelli marches on Milan's
## at Alessandria once its company has mustered).
static func _prepare_season(tree: SceneTree, session: Node, app: Node, g: Game, scene_name: String, sample: Dictionary) -> bool:
	_play(session, 1)  # the raised armies muster this season: the next one walks them
	await _frames(tree, 2)
	var verdict := session.call("act", "march", {"army": int(sample["savoy_army"]), "goal": ALESS}) as Dictionary
	if not bool(verdict.get("ok", false)):
		printerr("shot_ui_m7: the march on Alessandria was refused: %s" % str(verdict.get("reason", "")))
		return false
	if scene_name == "m7_replay_badge":
		var flow := (app.call("requests") as Object).get("flow") as Object
		if flow == null or not bool(flow.call("request_end")):
			return false
		var guard := 0
		while int(flow.call("state")) != REPLAY_STATE and guard < 60:
			await _frames(tree, 1)
			guard += 1
		var marks := (app.call("map_scene") as Node).get_node_or_null("WarMarks") as Node
		var seen := 0  # frames since the faint battle badge came up, so the picture holds the badge and the walk
		for _frame: int in REPLAY_FRAMES:
			await _frames(tree, 1)
			if int(flow.call("state")) != REPLAY_STATE:
				break
			if marks != null and _replay_badge_up(marks):
				seen += 1
				if seen >= 2:
					break
		_quiet(app)
		return int(flow.call("state")) == REPLAY_STATE and seen > 0
	for _n: int in SEASONS_MAX:
		_play(session, 1)
		if _has_battle_entry(g):
			break
	if not _has_battle_entry(g):
		printerr("shot_ui_m7: no battle was fought in %d seasons" % SEASONS_MAX)
		return false
	var screen_ids := ResourceLoader.load(SCREEN_IDS_PATH) as GDScript
	var report := screen_ids.call("make", &"season_report") as Node if screen_ids != null else null
	if report == null:
		return false
	report.call("show_summary", SeasonSummary.of(g, g.player, g.turn - 1), false)
	var stack := app.call("stack") as Control
	stack.call("push", report)
	await _frames(tree, 3)
	(report.call("sheet") as Object).call("scroll_to", &"war")  # the War section is the picture
	await _frames(tree, 4)
	return stack.call("top") == report


## Whether a faint replay badge shows on the war marks.
static func _replay_badge_up(marks: Node) -> bool:
	for child: Node in marks.get_children():
		if child is WarMark and (child as WarMark).kind == WarMark.KIND_REPLAY and (child as WarMark).visible:
			return true
	return false


## Whether the top screen is a Confirm.
static func _confirm_up(app: Node) -> bool:
	var top := (app.call("stack") as Control).call("top") as Node
	return top != null and top.get_script() != null and (top.get_script() as Script).get_global_name() == &"Confirm"


static func _has_battle_entry(g: Game) -> bool:
	for entry: Dictionary in g.chronicle.entries:
		if str(entry.get("kind", "")) == "battle_ended":
			return true
	return false
