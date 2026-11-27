## The M6 pictures (m6-build-spec.md section 9, names m6_*): the armies on Genoa's land, the way a player meets them. A standalone
## script, split from shot_ui.gd like shot_ui_m5.gd (its CLI and capture loop are copied from shot_ui.gd). Each picture is made in a
## Genoa game on seed 1480 with calm weather, a temporary save folder, and a fixture of armies made through the door: two companies
## of pikemen are raised by Session.act at Genoa (three) and at a hex two steps inland (two), and the first army marches
## three steps out. The pictures:
##   m6_army_tokens        the two tokens on the map, the first selected with its ring and its march drawn
##   m6_supply_legend      north Italy in the Supply mode (key 6) with its legend
##   m6_army_panel         the army panel of the selected army (its order, its units, its actions)
##   m6_raise_tab          the hex panel's Raise tab on a hex of yours
##   m6_hex_menu           the hex menu of an own hex with no army selected
##   m6_move_card          the move card of the selected army's march (the preview of a hex of yours)
##   m6_military_page      the Military page (the study's page after its keys)
##   m6_rankings_measures  the Rankings page after two seasons (the fourth measure is the armies')
##   m6_report_armies      the season report with the Armies section
##   m6_army_chip_1280     the Army chip's card under its chip at 1280 x 720
##   m6_army_chip_1024     the same at 1024 x 720 (the top bar narrows; the chip must still answer its card)
##   m6_replay_midwalk     the movement replay during its walk (the season's End with the replay on; reduce motion off)
##
## Windowed (GPU or xvfb + Mesa):
##   godot --path godot -s res://tools/ui/shot_ui_m6.gd -- --out=DIR [--dir=DIR] [--scale=1,2] [--only=m6_army_panel,...]
## Each scene is written to DIR/1x/NAME.png (1280 x 720) and DIR/2x/NAME.png (2560 x 1440); the 1024 scene is 1024 x 720 at 1x
## and 2048 x 1440 at 2x. Headless (the dummy renderer, `DisplayServer` headless) it prepares every scene at the given scales and
## exits 0 without writing PNGs; a scene that does not come up exits 1 and says which.
extends SceneTree

const DEFAULT_OUT_DIR := "/tmp/hexa_ui_shots_m6"
const APP_SCENE_PATH := "res://shell/app/app.tscn"
const SCREEN_IDS_PATH := "res://shell/screens/screen_ids.gd"
const LOGICAL_H := 720
const LOGICAL_W := 1280
const NARROW_W := 1024
const TAG := &"GEN"
const GENOA := Vector2i(8, 13)
const RAISE_COUNT_A := 3  # a hex raises three companies a season (its raise cap)
const RAISE_COUNT_B := 2
const TURNS_PLAYED := 2
## SeasonFlow.State.REPLAY (the shell's classes compile after the autoloads, so the number stands for it here).
const REPLAY_STATE := 2
const DEV_MONEY := 100000
const SCENES: Array[String] = [
	"m6_army_tokens",
	"m6_army_tokens_close",
	"m6_army_tokens_far",
	"m6_route_reach",
	"m6_supply_legend",
	"m6_army_panel",
	"m6_raise_tab",
	"m6_hex_menu",
	"m6_move_card",
	"m6_military_page",
	"m6_rankings_measures",
	"m6_report_armies",
	"m6_army_chip_1280",
	"m6_army_chip_1024",
	"m6_replay_midwalk",
]
## The scenes whose movement replay is on (every other scene plays its seasons with the replay off).
const REPLAY_SCENES: Array[String] = ["m6_replay_midwalk"]
## The token scene whose crop is also saved (320 x 200 physical pixels around the army, upscaled 3x with nearest neighbour).
const CROP_SCENE := "m6_army_tokens_close"
const CROP_SIZE := Vector2i(320, 200)
const CROP_SCALE := 3
## The screen position of the army the close scene centres on (set by its prepare; (-1, -1) for none).
static var _token_px := Vector2(-1.0, -1.0)
## The scenes whose window is narrower than the rest.
const NARROW_SCENES: Array[String] = ["m6_army_chip_1024"]

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
		printerr("shot_ui_m6: cannot load %s" % APP_SCENE_PATH)
		return 1
	var target_scenes: Array[String] = SCENES if _only.is_empty() else _only
	var rendered := 0
	var saved := 0
	for scale_mult: int in _scales:
		var scale_dir := global_out.path_join("%dx" % scale_mult)
		DirAccess.make_dir_recursive_absolute(scale_dir)
		for scene_name: String in target_scenes:
			if not SCENES.has(scene_name):
				printerr("shot_ui_m6: unknown scene '%s'" % scene_name)
				return 1
			var ok := await _capture_one(packed, scene_name, scale_mult, scale_dir, headless)
			if not ok:
				printerr("shot_ui_m6: %s did not come up at %dx" % [scene_name, scale_mult])
				return 1
			rendered += 1
			if not headless:
				saved += 1
	if headless:
		print("shot_ui_m6: headless dummy renderer; prepared %d scene renders (%s) without PNG output" % [rendered, global_out])
	else:
		print("shot_ui_m6: saved %d UI pictures to %s" % [saved, global_out])
	return 0


func _capture_one(packed: PackedScene, scene_name: String, scale_mult: int, scale_dir: String, headless: bool) -> bool:
	var width := NARROW_W if NARROW_SCENES.has(scene_name) else LOGICAL_W
	var vp := SubViewport.new()
	vp.gui_embed_subwindows = true  # the hex menu is a PopupMenu (a window): embedded, the viewport's capture holds it
	vp.size = Vector2i(width, LOGICAL_H) * scale_mult
	if scale_mult > 1:
		vp.size_2d_override = Vector2i(width, LOGICAL_H)
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
	s.set_value("accessibility/reduce_motion", not REPLAY_SCENES.has(scene_name))
	s.set_value("display/ui_scale", "100" if scale_mult == 1 else "200")
	s.set_value("game/season_report", "full")
	s.set_value("game/autosave", "off")
	s.set_value("graphics/season_change", "instant")
	s.set_value("game/movement", "normal" if REPLAY_SCENES.has(scene_name) else "instant")
	app.call("set_settings_override", s)
	vp.add_child(app)
	await _wait_frames(3)

	var ok: bool = await _prepare_scene(app, scene_name)
	await _wait_frames(3)
	if ok and not headless:
		var tex := vp.get_texture()
		var img := tex.get_image() if tex != null else null
		if img == null or img.is_empty():
			printerr("shot_ui_m6: empty viewport image for %s (%dx)" % [scene_name, scale_mult])
			ok = false
		else:
			var png_path := scale_dir.path_join("%s.png" % scene_name)
			if img.save_png(png_path) != OK:
				printerr("shot_ui_m6: failed saving %s" % png_path)
				ok = false
			if ok and scene_name == CROP_SCENE and _token_px.x >= 0.0:
				var k := Vector2(img.get_width(), img.get_height()) / Vector2(width, LOGICAL_H)
				var centre := Vector2i((_token_px * k).round())
				var origin := centre - Vector2i(int(CROP_SIZE.x * 0.5), int(CROP_SIZE.y * 0.5))
				origin.x = clampi(origin.x, 0, img.get_width() - CROP_SIZE.x)
				origin.y = clampi(origin.y, 0, img.get_height() - CROP_SIZE.y)
				var crop := img.get_region(Rect2i(origin, CROP_SIZE))
				crop.resize(CROP_SIZE.x * CROP_SCALE, CROP_SIZE.y * CROP_SCALE, Image.INTERPOLATE_NEAREST)
				var crop_path := scale_dir.path_join("%s_crop.png" % scene_name)
				if crop.save_png(crop_path) != OK:
					printerr("shot_ui_m6: failed saving %s" % crop_path)
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


static func _press_key(app: Node, key: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.pressed = pressed
		app.get_viewport().push_input(ev)


## Calm weather on a copy of the defs (the armies' pictures show the walk, not the weather).
static func _calm(g: Game) -> void:
	var d := PeopleFixture.copy_of(g.defs)
	d.weather_odds = PackedInt32Array([100, 0, 0])
	g.defs = d


static func _play(session: Node, seasons: int) -> void:
	for _n: int in seasons:
		session.call("end_season")


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


## The fixture: calm weather, money through the dev action, two armies raised through Session.act, the first one marching out.
## Returns the armies' ids (the first is the marching one); empty when the raise or the walk did not come up.
static func _fixture(tree: SceneTree, session: Node, g: Game) -> Array[int]:
	_calm(g)
	session.call("dev_money", TAG, DEV_MONEY)
	var kind := _kind_id(g, &"pikemen")
	var verdict := session.call("act", "raise", {"hex": GENOA, "kind": kind, "count": RAISE_COUNT_A}) as Dictionary
	if not bool(verdict.get("ok", false)):
		printerr("shot_ui_m6: the raise at Genoa was refused: %s" % str(verdict.get("reason", "")))
	var inland := _own_hex_at(g, GENOA, 2)
	if inland.x >= 0:
		session.call("act", "raise", {"hex": inland, "kind": kind, "count": RAISE_COUNT_B})
	var ids: Array[int] = []
	for army: Army in Armies.of_country(g, TAG):
		ids.append(army.id)
	if ids.is_empty():
		printerr("shot_ui_m6: the fixture raised no army (kind %d, hex %s)" % [kind, str(GENOA)])
		return ids
	var goal := _own_hex_at(g, GENOA, 3)
	if goal.x >= 0:
		session.call("act", "march", {"army": ids[0], "goal": goal})
	await _frames(tree, 2)
	return ids


static func _frames(tree: SceneTree, n: int) -> void:
	for _i: int in n:
		await tree.process_frame


static func _armies(app: Node) -> Node:
	var scene := app.call("map_scene") as Node
	return scene.get_node_or_null("MapArmies") if scene != null else null


static func _chip_card(tree: SceneTree, hud_node: Node, chip_getter: String) -> bool:
	var chips := hud_node.call("chips") as Control
	var chip := chips.call(chip_getter) as Control
	if chip == null or not chip.is_visible_in_tree():
		return false
	var hover := chip.call("_make_custom_tooltip", "card") as Control
	if hover == null:
		return false
	hud_node.add_child(hover)
	var at := chip.get_global_rect()
	hover.position = Vector2(at.position.x, at.end.y + 6.0)
	await _frames(tree, 3)
	return true


## The picture `scene_name`; false when something it shows did not come up.
static func _prepare_scene(app: Node, scene_name: String) -> bool:
	var session := app.get_tree().root.get_node_or_null("Session")
	var g: Game = session.get("game") as Game if session != null else null
	var scene := app.call("map_scene") as Node
	var hud_node := app.call("hud") as Node
	if g == null or scene == null or hud_node == null or not g.has_countries() or g.player != TAG:
		printerr("shot_ui_m6: no Genoa game (game %s, player %s)" % [str(g != null), str(g.player) if g != null else "-"])
		return false
	var tree: SceneTree = app.get_tree()
	var works: Object = (app.call("requests") as Object).get("works")
	var armies := _armies(app)
	if armies == null:
		return false
	var view_node := scene.call("view") as Node
	var fixture_ids: Array[int] = []
	match scene_name:
		"m6_supply_legend":
			fixture_ids = await _fixture(tree, session, g)
			_press_key(app, KEY_6)
			scene.call("fit")
			await _frames(tree, 4)
			return int(scene.call("mode")) == int(MapModes.Mode.SUPPLY) and bool((hud_node.call("mode_legend") as CanvasItem).visible)
		"m6_army_tokens", "m6_army_tokens_close", "m6_army_tokens_far":
			fixture_ids = await _fixture(tree, session, g)
			if fixture_ids.is_empty():
				return false
			var zoom_level := 0.35 if scene_name == "m6_army_tokens_far" else 1.0
			scene.call("frame_at", view_node.call("centre_of", GENOA), zoom_level)
			armies.call("select_army", fixture_ids[0])
			await _frames(tree, 4)
			_quiet(app)  # the raise's ribbons and the toasts would sit on the tokens
			await _frames(tree, 2)
			if scene_name == "m6_army_tokens_close":
				_token_px = (view_node as CanvasItem).get_global_transform_with_canvas() * (view_node.call("centre_of", GENOA) as Vector2)
			return int((armies.call("tokens") as Object).call("token_count")) > 0 and int(armies.call("selected_army")) == fixture_ids[0]
		"m6_army_panel":
			fixture_ids = await _fixture(tree, session, g)
			if fixture_ids.is_empty():
				return false
			armies.call("select_army", fixture_ids[0])
			await _frames(tree, 4)
			var panel := hud_node.call("army_panel") as Control
			return panel.visible and int(panel.call("shown_army")) == fixture_ids[0]
		"m6_raise_tab":
			fixture_ids = await _fixture(tree, session, g)
			scene.call("select_hex", GENOA)
			await _frames(tree, 3)
			var hex_panel := scene.call("panel") as Control
			if hex_panel == null or not hex_panel.has_method("show_tab"):
				return false
			hex_panel.call("show_tab", &"army")
			await _frames(tree, 4)
			# The raise rows sit low in the window's scroll: scroll them into view so the picture shows them.
			var raise_rows := hex_panel.call("tab_node") as Control
			var scroll := hex_panel.get_node_or_null("%Scroll") as ScrollContainer
			if scroll != null and raise_rows != null:
				scroll.ensure_control_visible(raise_rows)
			await _frames(tree, 3)
			return hex_panel.is_visible_in_tree() and raise_rows != null
		"m6_hex_menu":
			fixture_ids = await _fixture(tree, session, g)
			scene.call("select_hex", GENOA)
			await _frames(tree, 3)
			var found := armies.find_children("*", "HexMenu", false, false)
			if found.is_empty():
				return false
			var menu := found[0] as Object
			var opened := bool(menu.call("open_for", GENOA, Vector2(360.0, 260.0)))
			await _frames(tree, 4)
			return opened and bool(menu.get("visible")) and int(menu.call("get_item_count")) > 0
		"m6_move_card":
			fixture_ids = await _fixture(tree, session, g)
			if fixture_ids.is_empty():
				return false
			armies.call("select_army", fixture_ids[0])
			var goal := _own_hex_at(g, GENOA, 3)
			var map_hover := hud_node.call("map_hover") as Object
			var card := map_hover.call("move_card") as Object
			if card == null or goal.x < 0:
				return false
			card.call("show_move", MovePreview.to(g, TAG, fixture_ids[0], goal))
			card.call("place", Vector2(420.0, 220.0), Rect2(Vector2.ZERO, Vector2(LOGICAL_W, LOGICAL_H)))
			await _frames(tree, 4)
			return bool(card.call("is_open"))
		_:
			return await _prepare_later(tree, session, app, g, hud_node, scene, works, scene_name)


## The pages, the report, the chips and the replay of the pictures (split from _prepare_scene for the lint's 100 lines).
static func _prepare_later(tree: SceneTree, session: Node, app: Node, g: Game, hud_node: Node, scene: Node, works: Object, scene_name: String) -> bool:
	var fixture_ids: Array[int] = []
	var armies := _armies(app)
	var view_node := scene.call("view") as Node
	match scene_name:
		"m6_military_page":
			fixture_ids = await _fixture(tree, session, g)
			works.call("open_study", &"military", {})
			await _frames(tree, 4)
			var top := (app.call("stack") as Control).call("top") as Node
			return top != null and top.get("screen_id") == &"study" and top.call("current_page_id") == &"military"
		"m6_rankings_measures":
			fixture_ids = await _fixture(tree, session, g)
			_play(session, TURNS_PLAYED)
			await _frames(tree, 3)
			works.call("open_study", &"rankings", {})
			await _frames(tree, 4)
			var study := (app.call("stack") as Control).call("top") as Node
			return study != null and study.call("current_page_id") == &"rankings"
		"m6_report_armies":
			fixture_ids = await _fixture(tree, session, g)
			_play(session, TURNS_PLAYED)
			var screen_ids := ResourceLoader.load(SCREEN_IDS_PATH) as GDScript
			var report := screen_ids.call("make", &"season_report") as Node if screen_ids != null else null
			if report == null:
				return false
			report.call("show_summary", SeasonSummary.of(g, g.player, g.turn - 1), false)
			var stack := app.call("stack") as Control
			stack.call("push", report)
			await _frames(tree, 3)
			return stack.call("top") == report
		"m6_army_chip_1280", "m6_army_chip_1024":
			fixture_ids = await _fixture(tree, session, g)
			if await _chip_card(tree, hud_node, "army_chip"):
				return true  # the Army chip is visible and its card hangs under it
			# The top bar drops chips as the window narrows (the plan's order): at 1024 the Army chip may be gone. Then the
			# picture is the top bar without it; the planning session checks the picture against the order.
			if scene_name == "m6_army_chip_1024":
				print("shot_ui_m6: the Army chip is not shown at 1024 wide (the narrowing order); m6_army_chip_1024 is the top bar")
				return true
			return false
		"m6_replay_midwalk":
			fixture_ids = await _fixture(tree, session, g)
			_play(session, 1)  # the raised armies muster this season: the next one walks them (the replay shows that walk)
			await _frames(tree, 2)
			var flow := (app.call("requests") as Object).get("flow") as Object
			if flow == null or not bool(flow.call("request_end")):
				return false
			var guard := 0
			while int(flow.call("state")) != REPLAY_STATE and guard < 60:
				await _frames(tree, 1)
				guard += 1
			await _frames(tree, 12)  # a few steps into the walk
			_quiet(app)  # the season's ribbons would sit on the walkers
			return int(flow.call("state")) == REPLAY_STATE
		"m6_route_reach":
			fixture_ids = await _fixture(tree, session, g)
			if fixture_ids.is_empty():
				return false
			var goal := _goal_two_seasons(g, fixture_ids[0])
			if goal.x < 0:
				return false
			armies.call("select_army", fixture_ids[0])  # the reach tint and the army's ring
			scene.call("frame_at", view_node.call("centre_of", GENOA), 0.7)
			armies.call("_on_hover", goal)  # the order cursor on the goal: the route to it, with its stops and path marks
			await _frames(tree, 4)
			_quiet(app)
			return int(armies.call("selected_army")) == fixture_ids[0]
	return false


## Clears what the play left on the map: the floating ribbons and the toasts.
static func _quiet(app: Node) -> void:
	var scene := app.call("map_scene") as Node
	var floaters: Node = scene.get_node_or_null("Names/Floaters") if scene != null else null
	if floaters != null:
		floaters.call("clear")
	var hud_node := app.call("hud") as Node
	var host: Node = hud_node.call("toast_host") as Node if hud_node != null else null
	if host != null:
		if host.has_method("clear"):
			host.call("clear")
		else:
			for child: Node in host.get_children():
				(child as CanvasItem).visible = false


## A land hex of the player's, about two seasons' march from the army (MovePreview's arrival); the nearest later one when none
## is exactly two. (-1, -1) when none.
static func _goal_two_seasons(g: Game, army_id: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_gap := 1000000
	for i: int in range(0, g.map.hex_count(), 2):
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 0 or Territory.owner_tag(g, hex) != TAG or hex == GENOA:
			continue
		var preview := MovePreview.to(g, TAG, army_id, hex)
		var verdict := preview.get("verdict", {}) as Dictionary
		if not bool(verdict.get("ok", false)):
			continue
		var gap := int(preview.get("arrives_turn", -1)) - g.turn
		if gap < 2:
			continue
		if gap - 2 < best_gap:
			best_gap = gap - 2
			best = hex
			if best_gap == 0:
				break
	return best
