## The parchment map's pictures of tools/ui/shot_ui.gd (map-overview-build-plan.md section 3, names pm_*), split out like
## shot_ui_m5.gd to keep that script under the lint's 800 lines. Each is made in a Genoa game on seed 1480 with
## map/parchment on, and is taken only when the map has finished loading and shows what the name says. "Two notches" is the
## whole-map view and then two wheel notches farther out (what the "-" key does), where the parchment lies (spec D2). The
## pictures:
##   pm_fit_terrain, pm_fit_owner, pm_fit_owner_colour_blind  two notches, Terrain, Owner, Owner with the colour-blind
##                  country colours
##   pm_band        the same zoom with the cross-fade stopped half way (the map scene's frame is switched off for it)
##   pm_goods_wine  Goods mode at the whole-map view with Wine: the goods card, the legend and the Return button
##   pm_goods_close Goods mode at zoom 1 on the part of the map with the most wine districts
##   pm_hover       two notches, Terrain, the pointer on the place nearest Genoa that makes a good: the one-line card
##   pm_fog_thin    two notches, Owner, Genoa's map made thin (FogFixture.thin at radius 1)
##   pm_high_contrast, pm_text_150   two notches, Terrain, with accessibility/high_contrast and text_size 150
##   pm_army_over   two notches, an army of Genoa with its move points selected: its reach, the path to the pointer on
##                  the farthest land of Genoa it can be ordered to, and the move card
## The toasts are hidden (they lie over the map and fade by the clock). Everything of the shell is reached through call()
## and get(), as in the M3 to M5 pictures: shot_ui compiles before the autoloads. Headless the same code runs on the dummy
## renderer.
extends RefCounted

const SCENES: Array[String] = [
	"pm_fit_terrain",
	"pm_fit_owner",
	"pm_fit_owner_colour_blind",
	"pm_band",
	"pm_goods_wine",
	"pm_goods_close",
	"pm_hover",
	"pm_fog_thin",
	"pm_high_contrast",
	"pm_text_150",
	"pm_army_over",
]
const TAG := &"GEN"
const GENOA := Vector2i(8, 13)
const WINE := &"wine"
## Two default wheel notches out.
const NOTCHES_OUT := -2.0
const FRAMES_MAX := 1200
## Frames for the camera, the names and the HUD's cover rects to come to rest.
const SETTLE_FRAMES := 12
## Half of what a zoom 1 view shows around its middle, in map px (inside the HUD's parts).
const CLOSE_HALF := Vector2(480.0, 250.0)
const NO_HEX := Vector2i(-1, -1)


## The settings of a scene, over shot_ui's own (which keep map/parchment off for the older pictures).
static func settings_for(scene_name: String) -> Dictionary:
	var out := {
		"map/parchment": true,
		"game/season_report": "full",
		"game/autosave": "off",
		"game/movement": "instant",
		"graphics/season_change": "instant",
		"accessibility/tooltip_delay": "short",
		"state/map_mode": "terrain",
		"state/map_good": String(WINE),
	}
	match scene_name:
		"pm_fit_owner", "pm_fog_thin":
			out["state/map_mode"] = "owner"
		"pm_fit_owner_colour_blind":
			out["state/map_mode"] = "owner"
			out["accessibility/country_colours"] = "colour_blind"
		"pm_goods_wine", "pm_goods_close":
			out["state/map_mode"] = "goods"
		"pm_high_contrast":
			out["accessibility/high_contrast"] = true
		"pm_text_150":
			out["accessibility/text_size"] = 150
	return out


## The picture `scene_name` on a Genoa game; false when something it shows did not come up.
static func prepare(tree: SceneTree, app: Node, scene_name: String) -> bool:
	var session := tree.root.get_node_or_null("Session")
	if session == null or not await _wait_up(tree, app, session):
		return _fail(scene_name, "the game did not come up")
	var g: Game = session.get("game") as Game
	var ms := app.call("map_scene") as Node
	var hud := app.call("hud") as Node
	ms.call("finish_loading")
	(hud.call("toast_host") as CanvasItem).visible = false
	await _frames(tree, SETTLE_FRAMES)
	var ok := false
	match scene_name:
		"pm_fit_terrain", "pm_fit_owner", "pm_fit_owner_colour_blind", "pm_high_contrast", "pm_text_150":
			await _two_notches(tree, ms)
			ok = _is_solid(ms)
		"pm_band":
			ok = await _band(tree, ms)
		"pm_goods_wine":
			ms.call("fit")
			await _frames(tree, SETTLE_FRAMES)
			ok = _is_solid(ms) and _goods_up(hud, ms)
		"pm_goods_close":
			var middle := _wine_middle(g)
			if middle == NO_HEX:
				return _fail(scene_name, "no wine district")
			ms.call("frame_at", (ms.call("view") as Node).call("centre_of", middle), 1.0)
			await _frames(tree, SETTLE_FRAMES)
			ok = _is_solid(ms) and _goods_up(hud, ms) and _count(ms, &"icon") > 0
		"pm_hover":
			ok = await _hover(tree, g, ms, hud)
		"pm_fog_thin":
			FogFixture.thin(g, TAG, 1)
			await _two_notches(tree, ms)
			ok = _is_solid(ms) and MapModes.discovered_bytes(g, TAG).has(0)
		"pm_army_over":
			ok = await _army_over(tree, g, ms, hud)
	await _frames(tree, SETTLE_FRAMES)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	_say(scene_name, ms)
	return ok or _fail(scene_name, "the map does not show what the picture is of")


## The game is up: Genoa's, its map loaded, no screen over it.
static func _wait_up(tree: SceneTree, app: Node, session: Node) -> bool:
	for _i: int in FRAMES_MAX:
		var g: Game = session.get("game") as Game
		var ms := app.call("map_scene") as Node
		if g != null and g.player == TAG and ms != null and not bool(app.call("is_starting")) \
				and int((app.call("stack") as Object).call("count")) == 0 and not bool(ms.call("is_loading")):
			return true
		await tree.process_frame
	return false


static func _two_notches(tree: SceneTree, ms: Node) -> void:
	ms.call("fit")
	await _frames(tree, 4)
	(ms.call("camera_rig") as Node).call("zoom_by", NOTCHES_OUT)
	await _frames(tree, SETTLE_FRAMES)


## The cross-fade half way: the scene's own frame is switched off so that no time passes in the fade, the switch is told to
## fade (reduce motion, which the pictures set, switches at once), the camera zooms past the switch and half of the fade's
## time is spent.
static func _band(tree: SceneTree, ms: Node) -> bool:
	ms.call("fit")
	await _frames(tree, SETTLE_FRAMES)
	var parchment := ms.call("parchment") as CanvasItem
	if parchment.visible:
		return false
	ms.set_process(false)
	parchment.call("set_instant", false)
	(ms.call("camera_rig") as Node).call("zoom_by", NOTCHES_OUT)
	await _frames(tree, 4)
	parchment.call("step_fade", ParchmentSwitch.FADE_SEC * 0.5)
	ms.call("_sync_view")  # what lies under the parchment follows its alpha
	await _frames(tree, SETTLE_FRAMES)
	return bool(parchment.call("is_fading")) \
		and is_equal_approx((parchment.call("picture") as CanvasItem).self_modulate.a, 0.5)


static func _hover(tree: SceneTree, g: Game, ms: Node, hud: Node) -> bool:
	await _two_notches(tree, ms)
	var hex := _place_with_good(g)
	var hover := _map_hover(hud)
	if hex == NO_HEX or hover == null:
		return false
	_point_at(ms, hex)
	for _i: int in FRAMES_MAX:
		if bool(hover.call("is_card_visible")):
			break
		await tree.process_frame
	print("shot_ui parchment: the pointer is on %s: \"%s\"" % [hex,
		ParchmentView.tip(g, TAG, hex, int(ms.call("mode")), -1)])
	return _is_solid(ms) and hover.call("hovered_hex") == hex and bool(hover.call("is_card_visible"))


## An army of two companies on Genoa, selected, with the pointer on the farthest own land it can be ordered to.
static func _army_over(tree: SceneTree, g: Game, ms: Node, hud: Node) -> bool:
	var army := Armies.create(g, TAG, GENOA, "Army of Genoa")
	var kind := 0
	for unit: UnitDef in g.defs.units:
		if unit.key == &"pikemen":
			kind = unit.id
	Armies.add_units(g, army, kind, 2, g.turn - 1, GENOA, 0, {})
	Armies.set_points(g, army, Allowance.full(g, army))  # a season's move points, as an army raised before has
	g.version += 1
	var armies := ms.get_node("MapArmies")
	armies.call("sync")
	await _two_notches(tree, ms)
	if not bool(armies.call("select_army", army.id)):
		return false
	await _frames(tree, 4)
	var goal := NO_HEX
	var far := 0.0
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 0 or Territory.owner_tag(g, hex) != TAG:
			continue
		var d := MapTiles.cell_centre(hex).distance_squared_to(MapTiles.cell_centre(GENOA))
		if d <= far:
			continue
		var preview := MovePreview.to(g, TAG, army.id, hex)
		if not bool((preview.get("verdict", {}) as Dictionary).get("ok", false)):
			continue
		goal = hex
		far = d
	if goal == NO_HEX:
		return false
	var hover := _map_hover(hud)
	if hover == null:
		return false
	_point_at(ms, goal)
	var card := hover.call("move_card") as Node
	for _i: int in FRAMES_MAX:
		if bool(card.call("is_open")):
			break
		await tree.process_frame
	print("shot_ui parchment: army %d, pointer on %s, reach %d and %d hexes" % [army.id, goal,
		int(armies.call("reach_count", "reach")), int(armies.call("reach_count", "reach_next"))])
	return (_is_solid(ms) and int(armies.call("selected_army")) == army.id and int(armies.call("reach_count", "reach")) > 0
		and hover.call("hovered_hex") == goal and bool(card.call("is_open")))


## The place nearest Genoa whose district makes a good; (-1, -1) when none.
static func _place_with_good(g: Game) -> Vector2i:
	var goods := ParchmentView.goods_bytes(g, TAG)
	var best := NO_HEX
	var near := INF
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if goods[i * ParchmentView.GOODS_STRIDE] == 0 or str(Improve.place_of(g.map, hex).get("name", "")) == "":
			continue
		var d := MapTiles.cell_centre(hex).distance_squared_to(MapTiles.cell_centre(GENOA))
		if d < near:
			best = hex
			near = d
	return best


## The wine district with the most wine districts in a zoom 1 view round it (the first by hex index); (-1, -1) when none.
static func _wine_middle(g: Game) -> Vector2i:
	var wine := -1
	for good: Dictionary in ParchmentView.goods_list(g):
		if good["key"] == WINE:
			wine = int(good["id"])
	var goods := ParchmentView.goods_bytes(g, TAG)
	var districts: Array[Vector2i] = []
	for i: int in g.map.hex_count():
		if wine >= 0 and goods[i * ParchmentView.GOODS_STRIDE] == wine + 1:
			districts.append(g.map.hex_of(i))
	var best := NO_HEX
	var most := 0
	for hex: Vector2i in districts:
		var n := 0
		for other: Vector2i in districts:
			var d := (MapTiles.cell_centre(other) - MapTiles.cell_centre(hex)).abs()
			if d.x <= CLOSE_HALF.x and d.y <= CLOSE_HALF.y:
				n += 1
		if n > most:
			best = hex
			most = n
	return best


## The pointer comes to rest on the middle of `hex`: a mouse motion through the picture's viewport, as a player's, so
## that the map, the armies and the cards hear it. (The window's own mouse does not reach that viewport.)
static func _point_at(ms: Node, hex: Vector2i) -> void:
	var view := ms.call("view") as CanvasItem
	var at: Vector2 = view.get_global_transform_with_canvas() * (view.call("centre_of", hex) as Vector2)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	ms.get_viewport().push_input(motion, true)


## The HUD's hover card controller, or null.
static func _map_hover(hud: Node) -> Node:
	var found := hud.find_children("*", "MapHover", true, false)
	return found[0] if not found.is_empty() else null


## The parchment lies solid.
static func _is_solid(ms: Node) -> bool:
	var parchment := ms.call("parchment") as CanvasItem
	return parchment.visible and not bool(parchment.call("is_fading"))


static func _goods_up(hud: Node, ms: Node) -> bool:
	return int(ms.call("mode")) == int(MapModes.Mode.GOODS) and (hud.call("goods_card") as Control).is_visible_in_tree() \
		and (hud.call("mode_legend") as Control).is_visible_in_tree() \
		and (hud.call("return_button") as Control).is_visible_in_tree()


## How many entries of `kind` the parchment's names layout holds.
static func _count(ms: Node, kind: StringName) -> int:
	var n := 0
	for entry: Dictionary in (ms.call("parchment_names") as Object).call("placed") as Array:
		if entry["kind"] == kind:
			n += 1
	return n


## One line a picture for the log: the zoom against the fit zoom, the parchment's alpha and what its names hold.
static func _say(scene_name: String, ms: Node) -> void:
	var rig := ms.call("camera_rig") as Node
	var parchment := ms.call("parchment") as CanvasItem
	var alpha := 0.0
	if parchment.visible:
		alpha = (parchment.call("picture") as CanvasItem).self_modulate.a
	var names := PackedStringArray()
	for entry: Dictionary in (ms.call("parchment_names") as Object).call("placed") as Array:
		if entry["kind"] == &"country":
			names.append("%s %d" % [entry["text"], int(entry["size"])])
	print("shot_ui parchment: %s zoom %.4f = %.3f of the fit, alpha %.2f, countries [%s], capitals %d, towns %d, icons %d" % [
		scene_name, float(ms.call("zoom")), float(ms.call("zoom")) / float(rig.call("fit_zoom")), alpha, ", ".join(names),
		_count(ms, &"capital"), _count(ms, &"town"), _count(ms, &"icon")])


static func _fail(scene_name: String, why: String) -> bool:
	printerr("shot_ui parchment: %s: %s" % [scene_name, why])
	return false


static func _frames(tree: SceneTree, n: int) -> void:
	for _i: int in n:
		await tree.process_frame
