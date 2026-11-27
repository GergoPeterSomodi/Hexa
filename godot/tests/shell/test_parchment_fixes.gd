## The parchment map in the map scene, the faults its review found (docs/architecture/map-overview-build-spec.md R10,
## R15 to R18, D1, D2): the fallback season fade, the tile view and the far picture under it, the place plates, the
## country pick, a parchment nothing shows, and the army tokens over its names. Each case fails without its fix.
extends GutTest

const MAP_SCENE := preload("res://shell/map/map_scene.tscn")
const GEN := &"GEN"
const SCREEN := Vector2i(1920, 1080)
const MARKS: Array[String] = ["reach", "reach_next", "marks"]
const TILE_MODES: Array[int] = [MapModes.Mode.RELIEF, MapModes.Mode.YIELDS, MapModes.Mode.FOOD, MapModes.Mode.SUPPLY]

var _harness: UIHarness = null
var _settings: Settings = null
var _scene: MapScene = null
var _prev_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_harness = UIHarness.new(SCREEN)
	_harness.mount(self)
	_settings = _harness.settings
	assert_eq(Session.new_scenario("north_italy_1480", 1480, GEN), "")


func after_each() -> void:
	_scene = null
	_harness = null
	_settings = null
	Session.game = _prev_game
	Bindings.reset_defaults()


## A map scene in the 1920 x 1080 view, configured with the settings, two frames old.
func _open() -> MapScene:
	var scene := MAP_SCENE.instantiate() as MapScene
	scene.preload_next_season = false
	scene.configure(_settings)
	_harness.viewport.add_child(scene)
	scene.finish_loading()
	await _harness.wait_frames(self, 2)
	_scene = scene
	return scene


## Frames the middle of the map at a zoom, lets a frame pass and spends a second of time (a cross-fade ends).
func _at(zoom: float) -> void:
	_scene.frame_at(_scene.map_size() / 2.0, zoom)
	await _harness.wait_frames(self, 2)
	_scene._process(1.0)


## The modulate a node is drawn with: its own and every parent's, up to the scene.
func _modulate_of(node: CanvasItem) -> Color:
	var out := Color.WHITE
	var at: Node = node
	while at is CanvasItem:
		out *= (at as CanvasItem).modulate
		at = at.get_parent()
	return out


# ----- the fallback season fade (the hatch keeps a hex index in its vertex colour) -----------------------------------


func test_the_fallback_season_fade_never_modulates_the_parchment() -> void:
	await _open()
	var fade := _scene.season_fade()
	fade.method = SeasonFade.Method.FALLBACK
	fade.run_headless = true
	var hatch := _scene.parchment().layer(&"hatch")
	assert_true(hatch.is_visible_in_tree(), "the parchment is up")
	_scene.show_season(2, true)
	var tinted := 0
	var covered := 0
	for _i: int in 6:
		await wait_seconds(0.03)
		tinted += int(_modulate_of(hatch) != Color.WHITE)
		for rect: Node in fade.find_children("*", "ColorRect", false, false):
			var cover := rect as ColorRect
			covered += int(cover.visible and cover.color == Tokens.BG and cover.modulate.a > 0.0)
	assert_eq(tinted, 0, "no modulate reaches the hatch: it would read another hex's index")
	assert_gt(covered, 0, "the background colour covers the map instead")
	if fade.is_fading():
		await wait_for_signal(fade.finished, 2.0)
	assert_false(fade.is_fading(), "and is gone again")
	_scene.modulate = Tokens.BG
	assert_ne(_modulate_of(hatch), Color.WHITE, "P: the check sees a modulate on the scene")
	_scene.modulate = Color.WHITE


# ----- the tile view and the far picture under the parchment ---------------------------------------------------------


func test_a_mode_switch_at_a_far_zoom_never_hides_the_tile_view() -> void:
	await _open()
	await _at(0.1)
	var view := _scene.view()
	var toggles: Array[bool] = []
	view.visibility_changed.connect(func() -> void: toggles.append(view.visible))
	for mode: int in TILE_MODES + [MapModes.Mode.GOODS, MapModes.Mode.OWNER, MapModes.Mode.RELIEF,
			MapModes.Mode.TERRAIN]:
		_scene.set_mode(mode)
		await _harness.wait_frames(self, 2)
		var tiles := TILE_MODES.has(mode)
		assert_eq(view.ground_shown(), false, "mode %d: no ground at this zoom" % mode)
		for layer_name: String in MARKS:
			assert_eq(view.layer(layer_name).is_visible_in_tree(), not tiles, "mode %d: %s" % [mode, layer_name])
		assert_eq(_scene.far().visible, tiles, "mode %d: the far picture where there is no parchment" % mode)
	assert_eq(toggles, [] as Array[bool], "showing the view builds every tile layer: never with the parchment on")
	_scene.set_mode(MapModes.Mode.RELIEF)
	await _at(1.0)
	assert_true(view.ground_shown() and view.layer("marks").is_visible_in_tree(), "the tiles come back")


func test_under_a_solid_parchment_the_far_picture_is_decided_once() -> void:
	await _open()
	await _at(0.1)
	assert_true(_scene.parchment().visible and not _scene.far().visible)
	var writes: Array[bool] = []
	var far := _scene.far()
	far.visibility_changed.connect(func() -> void: writes.append(far.visible))
	await _harness.wait_frames(self, 10)
	assert_eq(writes, [] as Array[bool], "not shown and hidden again every frame")


# ----- the place plates ----------------------------------------------------------------------------------------------


func test_the_place_plates_fade_with_the_parchment_and_faded_country_names_block_none() -> void:
	_settings.set_value("map/place_names", true)
	await _open()
	_scene.set_mode(MapModes.Mode.OWNER)
	_scene.fit()
	await _harness.wait_frames(self, 3)
	var plates := _scene.labels()
	assert_true(plates.visible, "key N is on")
	assert_gt(_scene.country_labels().obstacles().size(), 0, "P: the covered names are laid out, with boxes")
	assert_eq(plates.modulate.a, 0.0, "no plate over the solid parchment (nor a name twice)")
	assert_eq(plates.obstacles, [] as Array[Rect2], "invisible names block nothing")
	_scene.frame_at(_scene.map_size() / 2.0, _scene.camera_rig().fit_zoom() * 1.4)
	_scene._process(0.125)
	assert_between(plates.modulate.a, 0.3, 0.7, "they come in as the parchment goes")
	assert_almost_eq(plates.modulate.a, _scene.country_labels().modulate.a, 0.001)
	_scene._process(0.25)
	await _harness.wait_frames(self, 2)
	assert_eq(plates.modulate.a, 1.0)
	assert_gt(plates.obstacles.size(), 0)
	assert_eq(plates.obstacles, _scene.country_labels().obstacles(), "shown names are kept off")


# ----- the country pick ----------------------------------------------------------------------------------------------


## A made-up map with deep fog and the real goods.
func _fogged_game() -> Game:
	var map := FakeMap.build(100, 60, 1480)
	var built := FakeScenario.build(map, 20, 1480)
	var defs := built["defs"] as GameDefs
	var real := ResourceLoader.load("res://data/defs/game_defs.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	defs.families = real.families
	defs.goods = real.goods
	return Game.new_scenario(map, defs, built["scenario"] as ScenarioDef, 1480)


## What the names show that the player must not see: an entry on an undiscovered hex, or a country the player's facts
## do not name.
func _unseen(names: ParchmentLabels) -> Array[String]:
	var game := Session.game
	var allowed: Dictionary = {}
	for entry: Dictionary in ParchmentView.country_names(game, game.player):
		allowed[entry["tag"]] = true
	var out: Array[String] = []
	for item: Dictionary in names.placed():
		if item["kind"] == ParchmentLabels.KIND_COUNTRY:
			if not allowed.has(item["tag"]):
				out.append(str(item["tag"]))
		elif not Knowledge.discovered(game, game.player, item["hex"]):
			out.append("%s %s" % [item["kind"], item["hex"]])
	return out


func test_the_country_pick_never_lays_out_all_seeing_names() -> void:
	for remembered: String in ["terrain", "goods"]:
		Session.start_game(_fogged_game())
		_settings.set_value("state/map_mode", remembered)
		await _open()
		_scene.fit()
		await _harness.wait_frames(self, 2)
		assert_true(_scene.picking())
		var tag := Session.game.countries[2].tag
		var same_call: Array[String] = []
		var viewers: Array[StringName] = []
		var watch := func(_t: StringName) -> void:  # heard after the scene: what it laid out within the pick
			same_call.append_array(_unseen(_scene.parchment_names()))
			viewers.append(_scene.parchment_names()._viewer)
		Events.country_chosen.connect(watch)
		assert_true(bool(Session.act("choose_country", {"tag": tag})["ok"]))
		Events.country_chosen.disconnect(watch)
		assert_gt(MapModes.discovered_bytes(Session.game, tag).count(0), 0, "the case holds fog")
		assert_eq(viewers, [tag] as Array[StringName], "%s: the player's facts within the pick" % remembered)
		assert_eq(same_call, [] as Array[String], "%s: nothing unseen is laid out" % remembered)
		assert_gt(_scene.parchment_names().placed().size(), 0)
		_scene.free()


# ----- a parchment nothing shows -------------------------------------------------------------------------------------


## Whether the parchment had any mesh while the tiles were still being filled, loading in slices of 2 ms.
func _meshes_before_the_tiles_end(map: MapData) -> bool:
	Session.start_game(Game.with_state(map, MapState.create(map)))
	var seen := false
	var steps := 0
	while _scene.view().is_filling() and steps < 20000:
		seen = seen or _scene.parchment().chunk_mesh(&"land", Vector2i.ZERO) != null
		_scene._load_step(2.0)
		steps += 1
	assert_gt(steps, 1, "the load took several slices")
	return seen


func test_a_switched_off_parchment_builds_after_the_tiles() -> void:
	_settings.set_value("map/parchment", false)
	await _open()
	_scene.set_process(false)
	var map := FakeMap.build(80, 60, 3)
	assert_false(_meshes_before_the_tiles_end(map), "off: the tiles first")
	_scene.finish_loading()
	assert_not_null(_scene.parchment().chunk_mesh(&"land", Vector2i.ZERO), "and it is built in the end")
	_settings.set_value("map/parchment", true)
	assert_true(_meshes_before_the_tiles_end(FakeMap.build(80, 60, 4)), "P: on: the parchment first")


func test_hidden_names_read_no_facts_until_they_show() -> void:
	_settings.set_value("map/parchment", false)
	await _open()
	var names := _scene.parchment_names()
	assert_true(names._owners.is_empty(), "a new game: nothing read")
	var game := Session.game
	var hex := Countries.by_tag(game, GEN).capital
	Territory.transfer(game, [hex], game.scenario.id_of(&"MLO"))
	game.events.clear()
	Events.owners_changed.emit([hex] as Array[Vector2i])
	var me := Countries.by_tag(game, GEN)
	game.sight.grew(me.id)
	game.version += 1
	await _harness.wait_frames(self, 3)
	assert_true(names._owners.is_empty(), "an owner change and a discovery only mark them stale")
	_settings.set_value("map/parchment", true)
	await _at(_scene.camera_rig().fit_zoom())
	assert_false(names._owners.is_empty(), "shown: read")
	assert_eq(int(names._owners[game.map.index_of(hex)]), game.scenario.id_of(&"MLO"), "as it is now")
	assert_gt(names.placed().size(), 0)


# ----- the armies over the names -------------------------------------------------------------------------------------


## What would put the names over an army, its path or the reach.
func _over_the_armies(names: CanvasItem) -> Array[String]:
	var out: Array[String] = []
	var armies := _scene.get_node("MapArmies") as MapArmies
	var tokens := armies.tokens()
	if names.get_canvas_layer_node() != tokens.get_canvas_layer_node():
		out.append("the names are on a canvas layer over the map's")
	for mark: Node2D in [tokens, armies.route_marks(), armies.stored_marks(), _scene.preview_marks()]:
		if names.z_index >= mark.z_index:
			out.append("the names are not under %s" % mark.name)
	if names.z_index >= int(TileMapView.OVERLAYS["reach"][0]):
		out.append("the names are not under the reach")
	var parchment := _scene.parchment()
	if names.z_index < parchment.z_index or names.get_parent() != parchment.get_parent() \
			or names.get_index() < parchment.get_index():
		out.append("the names are not over the parchment")
	return out


func test_army_tokens_paths_and_reach_are_drawn_over_the_names() -> void:
	await _open()
	_scene.fit()
	ArmyFixture.army(Session.game, GEN, Countries.by_tag(Session.game, GEN).capital, 0, 2)
	Session.game.version += 1
	(_scene.get_node("MapArmies") as MapArmies).sync()
	await _harness.wait_frames(self, 2)
	var names := _scene.parchment_names()
	assert_gt((_scene.get_node("MapArmies") as MapArmies).tokens().token_count(), 0, "an army stands on the map")
	assert_eq(_over_the_armies(names), [] as Array[String])
	assert_gt(_over_the_armies(_scene.country_labels()).size(), 0, "P: names in the Names layer are reported")


func test_the_names_in_the_world_still_land_on_their_screen_spots() -> void:
	await _open()
	var names := _scene.parchment_names()
	for zoom: float in [0.1, _scene.camera_rig().fit_zoom(), 1.3]:
		await _at(zoom)
		_scene.set_mode(MapModes.Mode.GOODS)
		_scene.camera_rig().pan_by(Vector2(37.0, -21.0))
		await _harness.wait_frames(self, 2)
		assert_gt(names.placed().size(), 0)
		var on_screen: Transform2D = names.get_global_transform_with_canvas() * names.draw_base()
		assert_true(on_screen.x.is_equal_approx(Vector2.RIGHT) and on_screen.y.is_equal_approx(Vector2.DOWN),
			"unscaled at %s: %s" % [zoom, on_screen])
		assert_lt(on_screen.origin.length(), 0.05, "and where the layout put them at %s: %s" % [zoom, on_screen.origin])
		_scene.set_mode(MapModes.Mode.TERRAIN)
