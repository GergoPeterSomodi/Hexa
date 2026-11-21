## The M5 pictures of tools/ui/shot_ui.gd (m5-build-spec.md section 9, names m5_*), split out like shot_ui_m45.gd to keep that
## script under the lint's 800 lines. Each is made in a Genoa game on seed 1480 with calm weather and the committed defs (the
## people grow), a few seasons played through Session. The pictures:
##   m5_people_page (the People page after 12 seasons), m5_top_bar_chips (the four chips and the People card hanging under its
##   chip), m5_food_chip_card (the Food card), m5_hex_panel_yours (Genoa's People section), m5_hex_panel_known (a known country's
##   hex: banded "about"), m5_hex_panel_unknown (an unknown country's: no people shown), m5_country_panel (the people row),
##   m5_food_map (north Italy in the Food mode with its legend), m5_report_people (the season report's People section),
##   m5_hunger_notification (Savona fallen to a village from hunger, in the notifications), m5_hunger_flag (the task flag's
##   hunger line), m5_village_before and m5_village_after (the village near Turin at zoom 1 the season before and the season it
##   grew into a town; always-fed defs, as spec 4.11 (d)).
## Everything of the shell is reached through call() and get(), as in the M3 to M4.5 pictures: shot_ui compiles before the
## autoloads. Headless the same code runs on the dummy renderer.
extends RefCounted

const SCENES: Array[String] = [
	"m5_people_page",
	"m5_top_bar_chips",
	"m5_food_chip_card",
	"m5_hex_panel_yours",
	"m5_hex_panel_known",
	"m5_hex_panel_unknown",
	"m5_country_panel",
	"m5_food_map",
	"m5_report_people",
	"m5_hunger_notification",
	"m5_hunger_flag",
	"m5_village_before",
	"m5_village_after",
]
const SCREEN_IDS_PATH := "res://shell/screens/screen_ids.gd"
const GENOA := Vector2i(8, 13)
const SAVONA := Vector2i(6, 13)
const VILLAGE := Vector2i(6, 11)
const TAG := &"GEN"
const SEASONS := 12
const PANEL_SEASONS := 3
const HUNGRY_SEASONS := 2
const VILLAGE_BEFORE_TURN := 34
const CARD_KEY := "card"
const DEV_LIMIT := 100000


static func _press_key(app: Node, key: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.pressed = pressed
		app.get_viewport().push_input(ev)


static func _frames(tree: SceneTree, n: int) -> void:
	for _i: int in n:
		await tree.process_frame


## Calm weather on a copy of the defs; `fed` is &"always_fed" (the towns eat nothing) or &"no_food" for the special pictures.
static func _defs(g: Game, fed: StringName = &"") -> void:
	var d := PeopleFixture.copy_of(g.defs)
	if fed == &"always_fed":
		d = PeopleFixture.always_fed(g.defs)
	elif fed == &"no_food":
		d = PeopleFixture.no_food(g.defs)
	d.weather_odds = PackedInt32Array([100, 0, 0])
	g.defs = d


static func _play(session: Node, seasons: int) -> void:
	for _n: int in seasons:
		session.call("end_season")


## A land hex of another country: a known one (a neighbour) when `known`, else an unknown one; (-1, -1) when none.
static func _other_hex(g: Game, known: bool) -> Vector2i:
	for i: int in g.map.hex_count():
		if g.map.land[i] == 0:
			continue
		var hex := g.map.hex_of(i)
		var tag := Territory.owner_tag(g, hex)
		if tag == &"" or tag == g.player:
			continue
		if Knowledge.knows(g, g.player, tag) == known:
			return hex
	return Vector2i(-1, -1)


static func _show_hex(tree: SceneTree, scene: Node, hud_node: Node, hex: Vector2i) -> bool:
	scene.call("select_hex", hex)
	var view_node := scene.call("view") as Node
	if view_node != null:
		scene.call("frame_at", view_node.call("centre_of", hex), 1.0)
	await _frames(tree, 4)
	var panel := hud_node.call("hex_panel") as Control
	return panel.is_visible_in_tree() and panel.call("shown_hex") == hex


static func _chip_card(tree: SceneTree, hud_node: Node, chip_getter: String) -> bool:
	var chips := hud_node.call("chips") as Control
	var chip := chips.call(chip_getter) as Control
	if not chip.is_visible_in_tree():
		return false
	var hover := chip.call("_make_custom_tooltip", CARD_KEY) as Control
	if hover == null:
		return false
	hud_node.add_child(hover)  # the card a pointer on the chip shows, drawn under it
	var at := chip.get_global_rect()
	hover.position = Vector2(at.position.x, at.end.y + 6.0)
	await _frames(tree, 3)
	return true


## The picture `scene_name` on a Genoa game; false when something it shows did not come up.
static func prepare(tree: SceneTree, app: Node, scene_name: String) -> bool:
	var session := tree.root.get_node_or_null("Session")
	var g: Game = session.get("game") as Game if session != null else null
	var scene := app.call("map_scene") as Node
	var hud_node := app.call("hud") as Node
	if g == null or scene == null or hud_node == null or not g.has_countries() or g.player != TAG:
		return false
	match scene_name:
		"m5_people_page":
			_defs(g)
			_play(session, SEASONS)
			await _frames(tree, 3)
			var works: Object = (app.call("requests") as Object).get("works")
			works.call("open_study", &"people", {})
			await _frames(tree, 4)
			var top := (app.call("stack") as Control).call("top") as Node
			return top != null and top.get("screen_id") == &"study" and top.call("current_page_id") == &"people"
		"m5_top_bar_chips":
			_defs(g)
			_play(session, PANEL_SEASONS)
			await _frames(tree, 3)
			return await _chip_card(tree, hud_node, "people_chip")
		"m5_food_chip_card":
			_defs(g)
			_play(session, PANEL_SEASONS)
			await _frames(tree, 3)
			return await _chip_card(tree, hud_node, "food_chip")
		"m5_hex_panel_yours":
			_defs(g)
			_play(session, PANEL_SEASONS)
			return await _show_hex(tree, scene, hud_node, GENOA)
		"m5_hex_panel_known", "m5_hex_panel_unknown":
			_defs(g)
			_play(session, PANEL_SEASONS)
			var other := _other_hex(g, scene_name == "m5_hex_panel_known")
			if other.x < 0:
				return false
			return await _show_hex(tree, scene, hud_node, other)
		"m5_country_panel":
			_defs(g)
			_play(session, PANEL_SEASONS)
			hud_node.call("show_country", g.player, false)
			await _frames(tree, 3)
			return (hud_node.call("country_panel") as Control).is_visible_in_tree()
		"m5_food_map":
			_defs(g)
			_play(session, PANEL_SEASONS)
			_press_key(app, KEY_5)
			scene.call("fit")
			scene.call("select_hex", GENOA)
			await _frames(tree, 4)
			return int(scene.call("mode")) == int(MapModes.Mode.FOOD) and bool((hud_node.call("mode_legend") as CanvasItem).visible)
		"m5_report_people":
			_defs(g)
			_play(session, PANEL_SEASONS)
			var screen_ids := ResourceLoader.load(SCREEN_IDS_PATH) as GDScript
			var report := screen_ids.call("make", &"season_report") as Node if screen_ids != null else null
			if report == null:
				return false
			report.call("show_summary", SeasonSummary.of(g, g.player, g.turn - 1), false)
			var stack := app.call("stack") as Control
			stack.call("push", report)
			await _frames(tree, 3)
			return stack.call("top") == report
		"m5_hunger_notification", "m5_hunger_flag":
			return await _hunger(tree, session, g, hud_node, scene_name == "m5_hunger_flag")
		"m5_village_before", "m5_village_after":
			return await _village(tree, session, g, scene, scene_name == "m5_village_after")
	return false


## No food, Savona at 2,100 people: it falls to a village in the second season (spec 4.11 (e)); the notification or the task
## flag's hunger line.
static func _hunger(tree: SceneTree, session: Node, g: Game, hud_node: Node, flag: bool) -> bool:
	_defs(g, &"no_food")
	if not bool(session.call("dev_people", SAVONA, 2100)):
		printerr("shot_ui m5: dev_people at Savona was refused")
		return false
	for key: StringName in [&"grain", &"fish"]:  # the stores hold none, so the towns eat nothing
		session.call("dev_goods", TAG, g.defs.good_id(key), -DEV_LIMIT)
	_play(session, HUNGRY_SEASONS)
	await _frames(tree, 3)
	if flag:
		var task_flag := hud_node.call("task_flag") as Node
		task_flag.call("refresh")
		task_flag.call("open_list")
		await _frames(tree, 2)
		return bool(task_flag.call("is_list_open"))
	var notes := hud_node.call("notifications") as Node
	return int(notes.call("card_count")) > 0


## The village near Turin at zoom 1: the season before it grows (turn 34, a village) or the season after (a town). Always-fed
## defs, so the 4,000 are reached at turn 34 whatever the land makes.
static func _village(tree: SceneTree, session: Node, g: Game, scene: Node, after: bool) -> bool:
	_defs(g, &"always_fed")
	var i := g.map.index_of(VILLAGE)
	var level := int(g.state.level[i])
	var target := VILLAGE_BEFORE_TURN + (1 if after else 0)
	var guard := 0
	while g.turn < target and guard < 60:
		session.call("end_season")
		guard += 1
	var view_node := scene.call("view") as Node
	scene.call("frame_at", view_node.call("centre_of", VILLAGE), 1.0)
	await _frames(tree, 4)
	var now := int(g.state.level[i])
	return g.turn == target and (now > level if after else now == level)
