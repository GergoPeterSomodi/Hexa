## The M4.5 pictures of tools/ui/shot_ui.gd (m4-5-build-spec.md section 9, names m45_*), split out to keep that script under the
## lint's 800 lines. Each is made in a Genoa game on seed 1480 with the plan's setup played through Session (the owner's
## playtest, m4-5-build-plan.md section 4): Build timber on (10, 13), seven seasons to Winter 1481, the upgrade of Genoa to a
## city, five seasons to Spring 1483, with calm weather (so the numbers are the spec's and the references of
## tests/fixtures/mockup/study_*.png can be compared). The pictures:
##   m45_study_districts, m45_study_goods, m45_study_history_tab (Economy's History tab, cursor on Winter 1481),
##   m45_study_rankings, m45_study_history (the History page, cursor on Winter 1481), m45_yields_map (north Italy in Yields with
##   the legend and the hex panel on Genoa, its Worth row), m45_yields_hover (the map's hover card on Genoa: the Worth line),
##   m45_log_headers (the action log open with older seasons as buttons), m45_timeline (History after 40 seasons: the
##   timeline's labels thinned).
## Everything of the shell is reached through call() and get(), as in the M3 and M4 pictures: shot_ui compiles before the
## autoloads. Headless the same code runs on the dummy renderer.
extends RefCounted

const SCENES: Array[String] = [
	"m45_study_districts",
	"m45_study_goods",
	"m45_study_history_tab",
	"m45_study_rankings",
	"m45_study_history",
	"m45_yields_map",
	"m45_yields_hover",
	"m45_log_headers",
	"m45_timeline",
]
const GENOA := Vector2i(8, 13)
const TIMBER := Vector2i(10, 13)
const TAG := &"GEN"
const SEASONS_TO_WINTER := 7
const SEASONS_AFTER_CITY := 5
const LONG_RUN := 40


## The setup of the plan's section 4 on the running game; false when an action was refused or the date is not Spring 1483.
static func play_setup(tree: SceneTree, g: Game) -> bool:
	var session := tree.root.get_node("Session")
	g.defs = EconomyFixture.defs()  # calm weather: a copy of the definitions with weather_odds 100, 0, 0
	if not bool((session.call("act", "build", {"hex": TIMBER, "family": ImproveRules.TIMBER}) as Dictionary).get("ok", false)):
		printerr("shot_ui m45: Build timber was refused")
		return false
	for _n: int in SEASONS_TO_WINTER:
		session.call("end_season")
	if not bool((session.call("act", "upgrade", {"hex": GENOA}) as Dictionary).get("ok", false)):
		printerr("shot_ui m45: the upgrade of Genoa was refused")
		return false
	for _n: int in SEASONS_AFTER_CITY:
		session.call("end_season")
	await tree.process_frame
	return g.turn == Calendar.FIRST_TURN + SEASONS_TO_WINTER + SEASONS_AFTER_CITY


static func _top(app: Node) -> Node:
	return (app.call("stack") as Control).call("top") as Node


static func _open_study(tree: SceneTree, app: Node, page: StringName, focus: Dictionary = {}) -> Node:
	var works: Object = (app.call("requests") as Object).get("works")
	works.call("open_study", page, focus)
	for _i: int in 4:
		await tree.process_frame
	var top := _top(app)
	return top if top != null and top.get("screen_id") == &"study" else null


static func _press_key(app: Node, key: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.pressed = pressed
		app.get_viewport().push_input(ev)


## The picture `scene_name` on a Genoa game; false when something it shows did not come up.
static func prepare(tree: SceneTree, app: Node, scene_name: String) -> bool:
	var session := tree.root.get_node_or_null("Session")
	var g: Game = session.get("game") as Game if session != null else null
	var scene := app.call("map_scene") as Node
	var hud_node := app.call("hud") as Node
	if g == null or scene == null or hud_node == null or not g.has_countries() or g.player != TAG:
		return false
	if not await play_setup(tree, g):
		return false
	var winter_1481 := Calendar.FIRST_TURN + SEASONS_TO_WINTER
	match scene_name:
		"m45_study_districts":
			var study := await _open_study(tree, app, &"economy", {"tab": &"districts"})
			return study != null and (study.call("current_page") as Node).call("current_tab") == &"districts"
		"m45_study_goods":
			var study := await _open_study(tree, app, &"economy", {"tab": &"goods"})
			return study != null and (study.call("current_page") as Node).call("current_tab") == &"goods"
		"m45_study_history_tab":
			var study := await _open_study(tree, app, &"economy", {"tab": &"history"})
			if study == null:
				return false
			var tab := (study.call("current_page") as Node).get_node("history")
			var seasons := StudyEconomy.history(g, TAG, 12)["seasons"] as Array
			for i: int in seasons.size():
				if int((seasons[i] as Dictionary)["turn"]) == winter_1481:
					(tab.call("chart") as Object).emit_signal("point_activated", i)  # the ledger follows the cursor
					await tree.process_frame
					return true
			return false
		"m45_study_rankings":
			var study := await _open_study(tree, app, &"rankings")
			return study != null and study.call("current_page_id") == &"rankings"
		"m45_study_history":
			var study := await _open_study(tree, app, &"history", {"turn": winter_1481})
			return study != null and int((study.call("current_page") as Node).call("cursor_turn")) == winter_1481
		"m45_yields_map":
			_press_key(app, KEY_4)
			scene.call("fit")
			scene.call("select_hex", GENOA)
			for _i: int in 4:
				await tree.process_frame
			return int(scene.call("mode")) == int(MapModes.Mode.YIELDS) and bool((hud_node.call("mode_legend") as CanvasItem).visible)
		"m45_yields_hover":
			_press_key(app, KEY_4)
			var view_node := scene.call("view") as Node
			scene.call("frame_at", view_node.call("centre_of", GENOA), 1.0)
			for _i: int in 4:
				await tree.process_frame
			var hover := hud_node.call("map_hover") as Node
			hover.call("on_hover_changed", GENOA, Vector2(640.0, 360.0))
			hover.call("_show_current")  # the card a pointer resting on Genoa shows after the hover delay
			await tree.process_frame
			await tree.process_frame
			return int(scene.call("mode")) == int(MapModes.Mode.YIELDS) and bool(hover.call("is_card_visible"))
		"m45_log_headers":
			var log_card := hud_node.call("action_log") as Node
			log_card.call("open")
			await tree.process_frame
			await tree.process_frame
			return bool(log_card.call("is_open")) and (log_card.call("header_buttons") as Array).size() > 0
		"m45_timeline":
			var session_node := tree.root.get_node("Session")
			for _n: int in LONG_RUN - (g.turn - Calendar.FIRST_TURN):
				session_node.call("end_season")
			var study := await _open_study(tree, app, &"history", {"turn": g.turn - 1})
			return study != null and study.call("current_page_id") == &"history"
	return false
