## The parchment map in the map scene (docs/architecture/map-overview-build-spec.md R16 to R18, R22, R24, R25, R29, D2, D4,
## D5, D13): what it hides and keeps, the cross-fade, Events.map_parchment, the switch, the modes, the pick, the setting
## that comes back, keys 7, [ and ], and the loading. Terrain and Owner show the parchment only well past the whole-map
## view (the camera's side of that: test_parchment_zoom.gd). Each planted case (P) feeds a check what a fault would leave.
extends GutTest

const MAP_SCENE := preload("res://shell/map/map_scene.tscn")
const HUD_SCENE := preload("res://shell/hud/hud.tscn")
const GEN := &"GEN"
const SCREEN := Vector2i(1920, 1080)
const SAVED := "user://test_parchment_settings.cfg"
## The tile view's parts under the parchment, and the marks that stay over it.
const GROUPS: Array[String] = ["Lines", "Borders", "Areas", "Shadows", "Standing"]
const MARKS: Array[String] = ["reach", "reach_next", "marks"]

var _harness: UIHarness = null
var _settings: Settings = null
var _scene: MapScene = null
var _told: Array[bool] = []
var _prev_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_harness = UIHarness.new(SCREEN)
	_harness.mount(self)
	_settings = _harness.settings
	_told.clear()
	Events.map_parchment.connect(_on_told)
	assert_eq(Session.new_scenario("north_italy_1480", 1480, GEN), "")


func after_each() -> void:
	Events.map_parchment.disconnect(_on_told)
	for action: StringName in [&"ui_left", &"cam_pan_left"]:
		Input.action_release(action)
	_scene = null
	_harness = null
	_settings = null
	Session.game = _prev_game
	Bindings.reset_defaults()
	if FileAccess.file_exists(SAVED):
		DirAccess.remove_absolute(SAVED)


func _on_told(solid: bool) -> void:
	_told.append(solid)


## A map scene in the 1920 x 1080 view, configured with the settings, two frames old.
func _open(settings: Settings = null) -> MapScene:
	var scene := MAP_SCENE.instantiate() as MapScene
	scene.preload_next_season = false
	scene.configure(settings if settings != null else _settings)
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


func _fit_zoom() -> float:
	return _scene.camera_rig().fit_zoom()


## The zoom-out limit, well past the whole-map view: where Terrain and Owner show the parchment (D2).
func _limit() -> float:
	return _scene.camera_rig().min_zoom()


## How strongly a node under the view is drawn: 0 when hidden, else its alphas multiplied up to the view.
func _drawn(node: CanvasItem) -> float:
	if not node.is_visible_in_tree():
		return 0.0
	var alpha := 1.0
	var at: Node = node
	while at != _scene:
		alpha *= (at as CanvasItem).modulate.a
		at = at.get_parent()
	return alpha


## What is wrong with the scene if the parchment should lie solid over it (R17).
func _solid_problems() -> Array[String]:
	var out: Array[String] = []
	var parchment := _scene.parchment()
	if not parchment.visible or parchment.is_fading():
		out.append("the parchment is not solid")
	var view := _scene.view()
	if view.ground_shown():
		out.append("the ground is shown")
	for group: String in GROUPS:
		if _drawn(view.get_node(group) as CanvasItem) > 0.0:
			out.append("%s is drawn" % group)
	for layer_name: String in TileMapView.LAYERS:
		for layer: TileMapLayer in view.layers_of(layer_name):
			if _drawn(layer) > 0.0:
				out.append("layer %s is drawn" % layer_name)
				break
	for layer_name: String in MARKS:
		if not is_equal_approx(_drawn(view.layer(layer_name)), view.layer(layer_name).modulate.a) \
				or not view.layer(layer_name).is_visible_in_tree():
			out.append("%s is not shown" % layer_name)
	if _scene.far().visible:
		out.append("the far picture is shown")
	if _scene.capital_marks().visible:
		out.append("the pennants are shown")
	if _scene.country_labels().modulate.a != 0.0:
		out.append("the tile view's country names show")
	if not _scene.parchment_names().visible or _scene.parchment_names().modulate.a != 1.0:
		out.append("the parchment's names are not solid")
	return out


## Whether the scene shows its tiles with no parchment at all.
func _tiles_problems() -> Array[String]:
	var out: Array[String] = []
	if _scene.parchment().visible:
		out.append("the parchment is shown")
	if _scene.parchment_names().visible:
		out.append("the parchment's names are shown")
	# (the view keeps a lines alpha that is equal to 1 but for the rounding of a fade's last steps)
	if not _scene.view().ground_shown() or not is_equal_approx(_scene.view().lines_alpha(), 1.0):
		out.append("the tiles are covered")
	if _scene.country_labels().modulate.a != 1.0:
		out.append("the tile view's country names are faded")
	return out


## Words said twice running: what a signal sent every frame leaves.
static func _repeats(log: Array[bool]) -> int:
	var count := 0
	for i: int in range(1, log.size()):
		count += int(log[i] == log[i - 1])
	return count


func test_the_nodes_stand_where_the_spec_puts_them() -> void:
	await _open()
	assert_eq(_scene.get_node("Overlay").get_index() + 1, _scene.parchment().get_index(), "Parchment after Overlay")
	assert_eq(_scene.parchment().name, &"Parchment")
	assert_eq(_scene.parchment().z_index, ParchmentMap.LAYER_Z)
	assert_eq(_scene.parchment().get_index() + 1, _scene.parchment_names().get_index(), "the names after it (D1)")
	assert_eq(_scene.parchment_names().get_parent(), _scene as Node, "in the world, under the armies")
	assert_eq(_scene.parchment_names().z_index, ParchmentMap.LAYER_Z)


func test_past_the_fit_the_parchment_covers_the_tiles_and_keeps_the_marks() -> void:
	await _open()
	_scene.set_mode(MapModes.Mode.OWNER)
	assert_between(_fit_zoom(), 0.5, 0.8, "north Italy's fit at 1920 x 1080")
	_scene.fit()
	await _harness.wait_frames(self, 2)
	assert_eq(_tiles_problems(), [] as Array[String], "the whole map: the tiles")
	await _at(_limit())
	assert_eq(_solid_problems(), [] as Array[String])
	assert_gt(_scene.parchment_names().placed().size(), 0, "names are laid out")
	assert_gt(_scene.country_labels().placed().size(), 0, "the covered names are laid out still, at alpha 0")
	_settings.set_value("map/parchment", false)  # P: tiles at the same view
	await _harness.wait_frames(self, 2)
	var left := _solid_problems()
	for part: String in ["the ground is shown", "Borders is drawn", "the pennants are shown"]:
		assert_has(left, part, "P: the check sees tiles")


func test_the_marks_stay_shown_at_a_far_zoom_and_the_view_is_not_toggled() -> void:
	await _open()
	await _at(0.1)
	assert_eq(_solid_problems(), [] as Array[String])
	var toggles: Array[bool] = []
	_scene.view().visibility_changed.connect(func() -> void: toggles.append(_scene.view().visible))
	await _harness.wait_frames(self, 5)
	assert_eq(toggles, [] as Array[bool], "showing the view builds the tile layers: not once a frame")
	_settings.set_value("map/parchment", false)
	await _harness.wait_frames(self, 2)
	assert_true(_scene.far().visible and not _scene.view().visible, "without the parchment: the far picture, as before")


func test_a_crossing_fades_the_lines_and_the_names_and_the_tiles_come_back() -> void:
	await _open()
	_scene.set_mode(MapModes.Mode.OWNER)
	var fit := _fit_zoom()
	await _at(_limit())
	await _at(fit * 0.82)
	assert_eq(_solid_problems(), [] as Array[String], "between the thresholds: still the parchment")
	_scene.frame_at(_scene.map_size() / 2.0, fit)
	_scene._process(0.125)
	var alpha := 1.0 - _scene.view().lines_alpha()
	assert_between(alpha, 0.3, 0.7, "half way through the cross-fade")
	assert_true(_scene.parchment().visible and _scene.parchment().is_fading())
	assert_true(_scene.view().ground_shown(), "both are drawn while it fades")
	assert_almost_eq(_scene.view().lines_alpha(), 1.0 - alpha, 0.001)
	for group: String in ["Lines", "Borders", "Areas"]:
		assert_almost_eq((_scene.view().get_node(group) as CanvasItem).modulate.a, 1.0 - alpha, 0.001, group)
	assert_eq((_scene.view().get_node("Standing") as CanvasItem).modulate.a, 1.0)
	assert_almost_eq(_scene.country_labels().modulate.a, 1.0 - alpha, 0.001)
	assert_almost_eq(_scene.parchment_names().modulate.a, alpha, 0.001)
	assert_true(_scene.capital_marks().visible, "the pennants go only under a solid parchment")
	assert_eq(_scene.parchment().modulate, Color.WHITE, "the fade is on the picture, not the node")
	_scene._process(0.125)
	assert_eq(_tiles_problems(), [] as Array[String], "after a quarter second: the tiles whole")
	assert_true(_scene.capital_marks().visible)
	await _at(fit * 0.82)
	assert_eq(_tiles_problems(), [] as Array[String], "between the thresholds: still the tiles")
	_scene.frame_at(_scene.map_size() / 2.0, _limit())
	_scene._process(0.25)
	assert_eq(_solid_problems(), [] as Array[String], "back out to the limit: the parchment whole")


func test_map_parchment_is_told_once_at_the_start_and_once_a_change() -> void:
	_settings.set_value("map/parchment", false)
	await _open()
	await _harness.wait_frames(self, 3)
	assert_eq(_told, [false] as Array[bool], "a new scene says so, though nothing is solid")
	_settings.set_value("map/parchment", true)
	_scene.fit()
	await _harness.wait_frames(self, 4)
	assert_eq(_told, [false] as Array[bool], "the whole map: tiles, nothing new")
	await _at(_limit())
	assert_eq(_told, [false, true] as Array[bool])
	await _at(_fit_zoom() * 0.82)
	assert_eq(_told, [false, true] as Array[bool], "between the thresholds: solid still")
	await _at(_fit_zoom())
	await _at(_fit_zoom() * 1.5)
	await _harness.wait_frames(self, 3)
	assert_eq(_told, [false, true, false] as Array[bool], "told once, and nothing new farther in")
	assert_eq(_repeats(_told), 0)
	for _i: int in 3:  # P: a scene that forgot what it said, every frame
		_scene._parchment._told = -1
		_scene._process(0.0)
	assert_gt(_repeats(_told), 0, "P: the check sees a signal sent every frame")


func test_the_switch_off_keeps_tiles_in_terrain_and_the_parchment_in_goods() -> void:
	_settings.set_value("map/parchment", false)
	await _open()
	for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.OWNER]:
		_scene.set_mode(mode)
		await _at(_limit())
		assert_eq(_tiles_problems(), [] as Array[String], "mode %d" % mode)
	_scene.set_mode(MapModes.Mode.GOODS)
	await _harness.wait_frames(self, 2)
	assert_eq(_solid_problems(), [] as Array[String], "Goods is the goods map")


func test_the_data_modes_keep_the_tiles_at_every_zoom() -> void:
	await _open()
	for mode: int in [MapModes.Mode.RELIEF, MapModes.Mode.YIELDS, MapModes.Mode.FOOD, MapModes.Mode.SUPPLY]:
		_scene.set_mode(mode)
		for zoom: float in [_limit(), _fit_zoom(), 0.3, 1.0]:
			await _at(zoom)
			assert_eq(_tiles_problems(), [] as Array[String], "mode %d at %f" % [mode, zoom])
	await _at(0.1)
	assert_true(_scene.far().visible and not _scene.view().ground_shown(), "their far picture, as before")
	assert_true(_scene.view().visible, "the view stays shown with the parchment on (never built again)")
	for layer_name: String in MARKS:
		assert_false(_scene.view().layer(layer_name).is_visible_in_tree(), "%s hidden with the tiles" % layer_name)


func test_goods_mode_is_solid_at_every_zoom_and_gives_the_tile_parts_terrain() -> void:
	await _open()
	_scene.set_mode(MapModes.Mode.OWNER)
	_scene.set_mode(MapModes.Mode.GOODS)
	assert_eq(_scene.mode(), int(MapModes.Mode.GOODS))
	assert_eq(_scene.overlay().mode(), int(MapModes.Mode.TERRAIN))
	assert_eq(_scene.parchment().mode(), int(MapModes.Mode.GOODS))
	assert_eq(_scene.parchment().good(), Session.game.defs.good_id(&"grain"), "grain at first")
	for zoom: float in [0.1, _limit(), _fit_zoom(), 1.0, 2.0]:
		await _at(zoom)
		assert_eq(_solid_problems(), [] as Array[String], "zoom %f" % zoom)
	assert_gt(_scene.parchment_names().placed().filter(
		func(item: Dictionary) -> bool: return item["kind"] == ParchmentLabels.KIND_ICON).size(), 0, "goods icons")
	_scene.set_mode(MapModes.Mode.TERRAIN)
	await _at(1.0)
	assert_eq(_tiles_problems(), [] as Array[String])


func test_the_pick_shows_no_parchment_and_choosing_a_country_brings_it() -> void:
	_settings.set_value("state/map_mode", "goods")
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "")
	await _open()
	assert_true(_scene.picking())
	await _at(_limit())
	assert_eq(_tiles_problems(), [] as Array[String], "no parchment during the pick")
	assert_eq(_told, [false] as Array[bool])
	assert_true(bool(Session.act("choose_country", {"tag": GEN})["ok"]))
	await _harness.wait_frames(self, 2)
	assert_eq(_scene.mode(), int(MapModes.Mode.GOODS), "the remembered mode")
	assert_eq(_solid_problems(), [] as Array[String])
	assert_eq(_told, [false, true] as Array[bool])


func test_goods_and_wine_come_back_after_a_settings_reload() -> void:
	await _open()
	_scene.set_mode(MapModes.Mode.GOODS)
	assert_true(_settings.set_value("state/map_good", "wine"))
	var wine := Session.game.defs.good_id(&"wine")
	assert_eq(_scene.parchment().good(), wine, "the scene hears the setting")
	assert_true(_settings.save_to(SAVED))
	_scene.free()
	var loaded := Settings.load_from(SAVED, "Windows", false)
	assert_eq(str(loaded.get_value("state/map_good")), "wine")
	await _open(loaded)
	assert_eq(_scene.mode(), int(MapModes.Mode.GOODS))
	assert_eq(_scene.parchment().good(), wine)
	assert_true(loaded.set_value("state/map_good", "no such good"))
	assert_eq(_scene.parchment().good(), int(ParchmentView.goods_list(Session.game)[0]["id"]), "unknown: the first")


func _hud() -> Hud:
	var hud := HUD_SCENE.instantiate() as Hud
	_harness.viewport.add_child(hud)
	hud.root().theme = KitTheme.load_for(1.0)
	hud.configure(_settings)
	return hud


## A Hud over the open scene, bound to it.
func _bound_hud() -> Hud:
	var hud := _hud()
	hud.bind_map_scene(_scene)
	return hud


func _press(keycode: Key) -> void:
	_harness.send_key(keycode)
	_harness.send_key(keycode, false)


func _focused() -> Control:
	return _harness.viewport.gui_get_focus_owner()


func test_keys_7_and_the_brackets_choose_the_goods_mode_and_its_good() -> void:
	await _open()
	var hud := _bound_hud()
	await _harness.wait_frames(self, 3)
	var card := hud.goods_card()
	var goods := ParchmentView.goods_list(Session.game)
	_press(KEY_BRACKETRIGHT)
	assert_eq(card.good_key(), &"grain", "outside Goods the brackets do nothing")
	_press(KEY_7)
	await _harness.wait_frames(self, 3)
	assert_eq(_scene.mode(), int(MapModes.Mode.GOODS), "7")
	assert_true(card.is_visible_in_tree())
	assert_null(_focused(), "the first 7 only switches")
	_press(KEY_7)
	assert_eq(_focused(), card.button_for(&"grain") as Control, "7 again: the keyboard is in the card")
	var at := 0
	for i: int in goods.size():
		if goods[i]["key"] == &"grain":
			at = i
	var next: Dictionary = goods[posmod(at + 1, goods.size())]
	_press(KEY_BRACKETRIGHT)
	assert_eq(card.good_key(), next["key"], "]")
	assert_eq(str(_settings.get_value("state/map_good")), String(next["key"]))
	assert_eq(_scene.parchment().good(), int(next["id"]))
	assert_eq(_focused(), card.button_for(next["key"]) as Control, "the keyboard goes with the choice")
	_press(KEY_BRACKETLEFT)
	_press(KEY_BRACKETLEFT)
	assert_eq(card.good_key(), goods[posmod(at - 1, goods.size())]["key"], "[ twice, round the list")
	_press(KEY_ESCAPE)
	assert_null(_focused(), "Esc gives the keyboard back to the map")
	_press(KEY_1)
	await _harness.wait_frames(self, 2)
	assert_eq(_scene.mode(), int(MapModes.Mode.TERRAIN))


func test_the_arrows_move_in_the_card_and_pan_nothing() -> void:
	await _open()
	var hud := _bound_hud()
	_scene.set_mode(MapModes.Mode.GOODS)
	await _at(1.0)
	var camera := _scene.camera()
	var rig := _scene.camera_rig()
	Input.action_press(&"cam_pan_left")
	Input.action_press(&"ui_left")
	var before := camera.position
	rig._process(0.1)
	assert_lt(camera.position.x, before.x, "P: with no focus in the card the held arrow pans")
	assert_true(hud.goods_card().focus_selected())
	before = camera.position
	rig._process(0.1)
	assert_eq(camera.position, before, "the arrow is the card's")
	Input.action_release(&"ui_left")
	rig._process(0.1)
	assert_lt(camera.position.x, before.x, "a pan key that is no arrow (A) still pans")


func test_the_settings_reach_the_parchment_and_the_names() -> void:
	await _open()
	await _at(0.2)
	var borders := _scene.parchment().layer(&"borders")
	assert_true(borders.visible)
	_settings.set_value("map/borders", false)
	assert_false(borders.visible, "R18")
	_settings.set_value("map/borders", true)
	_scene.apply_debug_layer(&"borders", false)
	assert_false(borders.visible, "the debug switch too")
	var land := _scene.parchment().layer_material(&"land")
	assert_gt(float(land.get_shader_parameter(&"owner_strength")), 0.0)
	_settings.set_value("map/owner_tint", false)
	assert_eq(float(land.get_shader_parameter(&"owner_strength")), 0.0)
	var palette := _scene.parchment().palette_image().get_data()
	_settings.set_value("accessibility/country_colours", "colour_blind")
	assert_ne(_scene.parchment().palette_image().get_data(), palette)
	var coast := _scene.parchment().layer_material(&"coast")
	var thin := float(coast.get_shader_parameter(&"width_px"))
	_settings.set_value("accessibility/high_contrast", true)
	assert_eq(float(coast.get_shader_parameter(&"width_px")), thin + 1.0, "R26")
	_settings.set_value("accessibility/text_size", 150)
	await _harness.wait_frames(self, 2)
	var capitals := _scene.parchment_names().placed().filter(func(item: Dictionary) -> bool:
		return item["kind"] == ParchmentLabels.KIND_COUNTRY)
	assert_gt(capitals.size(), 0)
	assert_eq(_scene.parchment_names()._text_scale, 1.5)


## The scene's own node, one wheel notch in and panned: the map's (0, 0) is off the screen, and the renderer's culling
## rect still holds every entry.
func test_the_names_are_not_culled_with_the_maps_corner_off_the_screen() -> void:
	await _open()
	var names := _scene.parchment_names()
	for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.GOODS]:
		_scene.set_mode(mode)
		if mode == MapModes.Mode.GOODS:
			await _at(_fit_zoom() * 1.15)
			_scene.camera_rig().pan_by(Vector2(300.0, 200.0))
		else:  # the parchment only past the fit, where the rig centres the map: framed off its middle instead
			_scene.frame_at(_scene.map_size() * 0.9, _limit())
			_scene._process(1.0)
		await _harness.wait_frames(self, 2)
		var origin := names.draw_base().affine_inverse() * Vector2.ZERO
		assert_false(Rect2(Vector2.ZERO, Vector2(SCREEN)).has_point(origin), "(0, 0) at %s" % origin)
		assert_true(names.visible)
		assert_gt(names.placed().size(), 0)
		assert_eq(ParchmentLabelsCase.culled(names), [] as Array[String], "mode %d" % mode)


func test_the_huds_cover_reaches_the_names() -> void:
	await _open()
	await _at(0.5)
	var count := _scene.parchment_names().layout_count
	var rects: Array[Rect2] = [Rect2(0.0, 0.0, 600.0, 400.0)]
	_scene.set_screen_cover(rects)
	assert_eq(_scene.parchment_names().layout_count, count + 1)
	assert_eq(_scene.parchment_names()._cover, rects)


func test_the_names_follow_the_camera_and_rest_while_it_does() -> void:
	await _open()
	_scene.set_mode(MapModes.Mode.GOODS)
	await _at(1.5)  # (the map is wider than the view, so it can be panned)
	var names := _scene.parchment_names()
	var count := names.layout_count
	await _harness.wait_frames(self, 10)
	assert_eq(names.layout_count, count, "R11: no layout while nothing changes")
	_scene.camera_rig().pan_by(Vector2(40.0, 0.0))
	await _harness.wait_frames(self, 2)
	assert_eq(names.layout_count, count + 1, "view_changed lays them out")


func test_owners_changed_writes_the_texel_and_reads_the_names_again() -> void:
	await _open()
	_scene.set_mode(MapModes.Mode.OWNER)
	await _at(0.5)
	var game := Session.game
	var hex := Countries.by_tag(game, GEN).capital
	var milan := game.scenario.id_of(&"MLO")
	var names := _scene.parchment_names()
	var count := names.layout_count
	Territory.transfer(game, [hex], milan)
	game.events.clear()
	Events.owners_changed.emit([hex] as Array[Vector2i])
	assert_eq(_scene.parchment().owner_image().get_pixelv(hex).r8, milan, "at once")
	await _harness.wait_frames(self, 2)
	assert_gt(names.layout_count, count)
	assert_eq(names._owners[game.map.index_of(hex)], milan, "the names read the new owner")
	assert_eq(_scene.parchment().geometry_builds, 1, "R28")


func test_a_cards_preview_is_drawn_over_the_parchment() -> void:
	await _open()
	await _at(1.0)
	var hex := Countries.by_tag(Session.game, GEN).capital
	var ghost: Dictionary = {}
	for layer_name: String in MapCells.LAYERS:
		for layer: TileMapLayer in _scene.view().layers_of(layer_name):
			if ghost.is_empty() and layer_name == "ground" and layer.get_cell_source_id(hex) != -1:
				ghost = {"ground": "mark/select"}
	_scene.show_preview({"ghost": {"hex": hex, "tiles": {"piece_front": "mark/select"}}, "map_marks": {}})
	var node := _scene.preview_marks().get_node_or_null("Ghost") as CanvasItem
	assert_not_null(node, "a ghost is shown")
	if node == null:
		return
	assert_eq(node.z_index, PreviewMarks.GHOST_Z, "over the tiles as before")
	_scene.set_mode(MapModes.Mode.GOODS)
	assert_gt(node.z_index, ParchmentMap.LAYER_Z, "R17: over the parchment")
	_scene.set_mode(MapModes.Mode.TERRAIN)
	assert_eq(node.z_index, PreviewMarks.GHOST_Z)


func test_a_big_map_builds_the_parchment_in_slices_before_its_tiles() -> void:
	await _open()
	var map := FakeMap.build(80, 60, 3)  # 4,800 hexes: over MapScene.SYNC_LOAD_HEXES
	Session.start_game(Game.with_state(map, MapState.create(map)))
	var parchment := _scene.parchment()
	assert_true(parchment.is_building() and _scene.is_loading())
	assert_false(parchment.visible, "nothing while it is built")
	var steps := 0
	while parchment.is_building() and steps < 10000:
		_scene._load_step(2.0)
		steps += 1
	assert_gt(steps, 1, "it took several slices")
	_scene.finish_loading()
	assert_false(_scene.is_loading())
	_scene.frame_at(_scene.map_size() / 2.0, 0.1)
	assert_true(parchment.visible)
	assert_true(_scene.view().visible and not _scene.far().visible)
	Session.start_game(Game.with_state(map, MapState.create(map)))
	assert_false(parchment.is_building(), "the same map keeps its geometry")


func test_a_load_that_is_all_parchment_is_done_by_finish_loading() -> void:
	await _open()
	var map := FakeMap.build(80, 60, 4)
	Session.start_game(Game.with_state(map, MapState.create(map)))
	assert_true(_scene.parchment().is_building())
	_scene.finish_loading()
	assert_false(_scene.parchment().is_building())


func test_the_far_lock_leaves_the_parchment_to_the_camera() -> void:
	await _open()
	await _at(1.0)
	_scene.apply_debug_layer(&"far_locked", true)
	assert_false(_scene.parchment().visible, "the camera is close: no parchment")
	assert_true(_scene.far().visible)
	await _at(0.1)
	assert_eq(_solid_problems(), [] as Array[String])


func test_a_game_that_ends_drops_the_parchment() -> void:
	await _open()
	await _at(_limit())
	assert_true(_scene.parchment().visible)
	Session.end_game()
	await _harness.wait_frames(self, 2)
	assert_false(_scene.parchment().visible)
	assert_null(_scene.parchment().owner_image())
	assert_eq(_scene.parchment_names().placed().size(), 0)


func test_the_hover_card_is_one_line_over_the_solid_parchment() -> void:
	var hud := _hud()
	var scene := MAP_SCENE.instantiate() as MapScene  # the App's order: the Hud binds before the scene's first frame
	scene.preload_next_season = false
	_harness.viewport.add_child(scene)
	scene.configure(_settings)
	hud.bind_map_scene(scene)
	_scene = scene
	scene.frame_at(scene.map_size() / 2.0, _limit())  # solid by the scene's first frame
	await _harness.wait_frames(self, 3)
	assert_true(hud.map_hover().shows_line(), "the HUD heard the scene")
	await _at(_fit_zoom() * 1.5)
	assert_false(hud.map_hover().shows_line())
	await _at(_fit_zoom())
	assert_false(hud.map_hover().shows_line(), "the whole map: the tiles' card")
	await _at(_limit())
	assert_true(hud.map_hover().shows_line())
	_scene.set_mode(MapModes.Mode.RELIEF)
	assert_false(hud.map_hover().shows_line(), "at once: no parchment in Relief")


## The whole App on Genoa: the whole-map view under the HUD's free area and one wheel notch past it are the tiles, two
## notches bring the parchment, one notch back in or Fit the tiles; key 7 and ] work through the App, and a quickload
## brings back the Goods mode with its good.
func test_in_the_app_the_whole_map_view_is_tiles_and_two_notches_out_bring_the_parchment() -> void:
	var old_dir := Session.save_dir
	var old_lock := RunLock.path
	var ai := Session.ai_enabled
	Session.ai_enabled = false
	Session.save_dir = "user://test_parchment_saves"
	RunLock.path = "user://test_parchment_running.lock"
	var app := (load("res://shell/app/app.tscn") as PackedScene).instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.cli_args_override = PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"])
	var s := Settings.new("macOS", true)
	for pair: Array in [["state/help_seen", true], ["graphics/preload_next_season", false], ["game/autosave", "off"],
			["accessibility/reduce_motion", true]]:
		s.set_value(pair[0], pair[1])
	app.set_settings_override(s)
	_harness.viewport.add_child(app)
	for _i: int in 600:
		if app.map_scene() != null and app.stack().count() == 0 and not app.is_starting():
			break
		await get_tree().process_frame
	await _harness.wait_frames(self, 4)
	_scene = app.map_scene()
	assert_almost_eq(_scene.zoom(), _fit_zoom(), 0.0001, "the game opens on the whole map")
	assert_eq(_tiles_problems(), [] as Array[String], "a new game on the whole map: the tiles")
	assert_false(app.hud().map_hover().shows_line())
	assert_gt(_scene.parchment_names()._cover.size(), 0, "the HUD's cover reached the names")
	assert_eq(_told.back(), false)
	_scene.camera_rig().zoom_by(-1.0)
	await _harness.wait_frames(self, 3)
	assert_eq(_tiles_problems(), [] as Array[String], "one notch out: the tiles still")
	_scene.camera_rig().zoom_by(-1.0)
	await _harness.wait_frames(self, 3)
	assert_eq(_solid_problems(), [] as Array[String], "two notches out: the parchment")
	assert_true(app.hud().map_hover().shows_line())
	assert_eq(_told.back(), true)
	_scene.camera_rig().zoom_by(1.0)
	await _harness.wait_frames(self, 3)
	assert_eq(_tiles_problems(), [] as Array[String], "one notch back in: the tiles")
	_scene.camera_rig().zoom_by(-2.0)
	await _harness.wait_frames(self, 3)
	assert_eq(_solid_problems(), [] as Array[String])
	app.hud().zoom_control().fit_requested.emit()
	await _harness.wait_frames(self, 3)
	assert_eq(_tiles_problems(), [] as Array[String], "the Fit button: the tiles")
	assert_almost_eq(_scene.zoom(), _fit_zoom(), 0.0001)
	_press(KEY_7)
	await _harness.wait_frames(self, 3)
	_press(KEY_BRACKETRIGHT)
	await _harness.wait_frames(self, 2)
	var good := app.hud().goods_card().good_key()
	assert_ne(good, &"grain", "] stepped")
	assert_eq(_solid_problems(), [] as Array[String], "Goods at this zoom")
	assert_eq(_scene.parchment().good(), app.hud().goods_card().good_id())
	_press(KEY_F5)
	for _i: int in 600:
		if SaveFile.read_header(SaveRows.QUICK_SLOT, Session.save_dir)["state"] == &"ok":
			break
		await get_tree().process_frame
	app.hud().return_button().pressed.emit()
	await _harness.wait_frames(self, 2)
	assert_eq(_scene.mode(), int(MapModes.Mode.TERRAIN), "Return to default map")
	assert_eq(Session.load_game(SaveRows.QUICK_SLOT), "")
	app.requests().restore_view()
	await _harness.wait_frames(self, 4)
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.GOODS), "the save brings Goods back")
	assert_eq(app.hud().goods_card().good_key(), good)
	assert_eq(app.map_scene().parchment().good(), app.hud().goods_card().good_id())
	app.free()
	Session.end_game()
	for slot: String in SaveFile.SLOTS + SaveFile.AUTO_SLOTS:
		SaveFile.remove(slot, Session.save_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.save_dir))
	RunLock.clear()
	Session.save_dir = old_dir
	RunLock.path = old_lock
	Session.ai_enabled = ai
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)
