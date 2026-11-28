## The army's next-season reach on the drawn map (docs/architecture/map-overview-build-spec.md, amendment of
## 2026-11-28): the hexes only the next season reaches are hatched while the parchment shows, in Terrain, Owner and
## Goods, in both contrasts and both country palettes; the tile view's reach is as it was. The renderer of a headless run
## draws nothing, so these checks read the layers, the material, its settings and the colours; the stripes themselves are
## seen in the pictures (pm_army_over). (P): a pale pair of stripes, and a layer with no hatch: the checks report them.
extends GutTest

const MAP_SCENE := preload("res://shell/map/map_scene.tscn")
const GEN := &"GEN"
const SCREEN := Vector2i(1920, 1080)
const DRAWN_MODES: Array[int] = [MapModes.Mode.TERRAIN, MapModes.Mode.OWNER, MapModes.Mode.GOODS]
const MARK_MIN := 3.0

var _harness: UIHarness = null
var _scene: MapScene = null
var _prev_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_harness = UIHarness.new(SCREEN)
	_harness.mount(self)
	assert_eq(Session.new_scenario("north_italy_1480", 1480, GEN), "")


func after_each() -> void:
	_scene = null
	_harness = null
	Session.game = _prev_game
	Bindings.reset_defaults()


## A map scene with an army of Genoa selected on its capital.
func _open() -> void:
	_scene = MAP_SCENE.instantiate() as MapScene
	_scene.preload_next_season = false
	_scene.configure(_harness.settings)
	_harness.viewport.add_child(_scene)
	_scene.finish_loading()
	await _harness.wait_frames(self, 2)
	var g := Session.game
	var army := ArmyFixture.army(g, GEN, Countries.by_tag(g, GEN).capital, 0, 2)
	g.version += 1
	var armies := _scene.get_node("MapArmies") as MapArmies
	armies.sync()
	assert_true(armies.select_army(army.id))
	assert_gt(armies.reach_count("reach"), 0, "the case holds a reach")
	assert_gt(armies.reach_count("reach_next"), 0, "and a next season's")


func _at(zoom: float) -> void:
	_scene.frame_at(_scene.map_size() / 2.0, zoom)
	await _harness.wait_frames(self, 2)
	_scene._process(1.0)


## What is wrong with the reach on the solid drawn map.
func _drawn_problems(high: bool) -> Array[String]:
	var out: Array[String] = []
	var view := _scene.view()
	var layer := view.layer("reach_ahead")
	var hatched := layer.material as ShaderMaterial
	if view.layer("reach").material != null or view.layer("reach_next").material != null:
		out.append("this season's reach is not the flat fill")
	if layer.modulate.a < 1.0 or layer.get_used_cells().is_empty():
		out.append("the next season's reach is not drawn")
	if hatched == null or hatched.shader != ParchmentReach.SHADER:
		out.append("the next season's reach is not hatched")
		return out
	var colours := ParchmentTokens.colours(high)
	var want := {&"zoom": _scene.zoom(), &"ink": colours[&"reach_ink"], &"light": colours[&"reach_light"],
		&"period_px": ParchmentTokens.REACH_PERIOD_PX, &"ink_px": ParchmentTokens.reach_ink_px(high),
		&"light_px": ParchmentTokens.REACH_LIGHT_PX}
	for key: StringName in want:
		if hatched.get_shader_parameter(key) != want[key]:
			out.append("%s is %s, not %s" % [key, hatched.get_shader_parameter(key), want[key]])
		if not ParchmentReach.SHADER.code.contains(" %s" % key):
			out.append("the shader has no %s" % key)
	if not layer.is_visible_in_tree():
		out.append("the layer is hidden")
	return out


func test_the_next_seasons_reach_is_hatched_on_the_drawn_map() -> void:
	await _open()
	var found: Array[String] = []
	for high: bool in [false, true]:
		_harness.settings.set_value("accessibility/high_contrast", high)
		for blind: bool in [false, true]:
			_scene.set_colour_blind(blind)
			for mode: int in DRAWN_MODES:
				_scene.set_mode(mode)
				await _at(_scene.camera_rig().min_zoom())
				if not _scene.parchment().visible or _scene.parchment().is_fading():
					found.append("high %s, blind %s, mode %d: the drawn map is not solid" % [high, blind, mode])
				for line: String in _drawn_problems(high):
					found.append("high %s, blind %s, mode %d: %s" % [high, blind, mode, line])
	assert_eq(found, [] as Array[String])
	# Goods shows the drawn map at every zoom, and the stripes keep their screen size there.
	await _at(1.3)
	assert_eq(_drawn_problems(true), [] as Array[String], "Goods, close in")
	_scene.view().layer("reach_ahead").material = null
	assert_gt(_drawn_problems(true).size(), 0, "(P) a layer with no hatch is reported")


func test_only_what_the_next_season_alone_reaches_is_hatched() -> void:
	await _open()
	var armies := _scene.get_node("MapArmies") as MapArmies
	var reach := MovePreview.reach(Session.game, GEN, armies.selected_army())
	var want: Array[Vector2i] = []
	for i: int in reach["next"] as PackedInt32Array:
		if not (reach["season"] as PackedInt32Array).has(i):
			want.append(Session.game.map.hex_of(i))
	assert_gt(want.size(), 0)
	var got: Array[Vector2i] = []
	got.assign(_scene.view().layer("reach_ahead").get_used_cells())
	got.sort()
	want.sort()
	assert_eq(got, want, "this season's hexes keep their flat fill alone")
	armies.clear_army()
	assert_eq(_scene.view().layer("reach_ahead").get_used_cells().size(), 0, "it goes with the army")


func test_the_tile_views_reach_is_as_it_was() -> void:
	await _open()
	var found: Array[String] = []
	for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.OWNER, MapModes.Mode.RELIEF]:
		_scene.set_mode(mode)
		await _at(_scene.camera_rig().min_zoom())
		await _at(1.0)
		found.append_array(_tile_problems("mode %d" % mode))
	_scene.set_mode(MapModes.Mode.RELIEF)
	await _at(_scene.camera_rig().min_zoom())
	found.append_array(_tile_problems("Relief far out"))
	assert_eq(found, [] as Array[String])


## What differs from the tile view's reach: its two fills as the armies set them, and no stripes.
func _tile_problems(what: String) -> Array[String]:
	var out: Array[String] = []
	var view := _scene.view()
	if view.layer("reach_ahead").modulate.a > 0.0:
		out.append("%s: hatched with no drawn map" % what)
	var fills := {"reach": Tokens.MAP_REACH, "reach_next": Tokens.MAP_REACH_NEXT}
	for layer_name: String in fills:
		var layer := view.layer(layer_name)
		if layer.material != null or layer.modulate != fills[layer_name]:
			out.append("%s: %s is %s" % [what, layer_name, layer.modulate])
	return out


func test_the_hatch_comes_in_with_the_drawn_map() -> void:
	await _open()
	await _at(1.0)
	_scene.set_process(false)
	_scene.parchment().set_instant(false)
	_scene.frame_at(_scene.map_size() / 2.0, _scene.camera_rig().min_zoom())
	_scene._process(ParchmentSwitch.FADE_SEC * 0.5)
	assert_true(_scene.parchment().is_fading(), "the case is mid-fade")
	var layer := _scene.view().layer("reach_ahead")
	assert_not_null(layer.material)
	assert_almost_eq(layer.modulate.a, _scene.parchment().picture().self_modulate.a, 0.001,
		"as far as the drawn map shows")


# ----- the fog --------------------------------------------------------------------------------------------------------


## A thin start for Genoa: no other country holds land (so its army may march anywhere) and Genoa has discovered only
## what its land and armies see. An army on its capital is selected.
func _open_thin() -> void:
	var g := Session.game
	var mine := Countries.by_tag(g, GEN).id
	for i: int in g.state.owner.size():
		if g.state.owner[i] != mine:
			g.state.owner[i] = 0
	FogFixture.thin(g, GEN, 0)
	await _open()


## The hexes each reach layer is to hold for the selected army, by layer: all that MovePreview.reach gives, or on the
## drawn map only those of them Genoa has discovered.
func _wanted_reach(drawn: bool) -> Dictionary[String, Array]:
	var g := Session.game
	var armies := _scene.get_node("MapArmies") as MapArmies
	var reach := MovePreview.reach(g, GEN, armies.selected_army())
	var season := reach["season"] as PackedInt32Array
	var out: Dictionary[String, Array] = {"reach": [], "reach_next": [], "reach_ahead": []}
	for i: int in reach["next"] as PackedInt32Array:
		var hex := g.map.hex_of(i)
		if drawn and not Knowledge.discovered(g, GEN, hex):
			continue
		out["reach_next"].append(hex)
		out["reach_ahead" if not season.has(i) else "reach"].append(hex)
	return out


## What is wrong with the reach layers' cells, tiles (all of the reach) or drawn map (none on unexplored paper).
func _fog_problems(drawn: bool, what: String) -> Array[String]:
	var out: Array[String] = []
	if _scene.parchment().visible != drawn:
		out.append("%s: the drawn map shows %s" % [what, _scene.parchment().visible])
	var wanted := _wanted_reach(drawn)
	for layer_name: String in wanted:
		var want: Array = wanted[layer_name]
		var got: Array = Array(_scene.view().layer(layer_name).get_used_cells())
		want.sort()
		got.sort()
		if got != want:
			var extra := got.filter(func(hex: Vector2i) -> bool: return not want.has(hex))
			out.append("%s: %s holds %d hexes, not %d; too many: %s" % [what, layer_name, got.size(), want.size(),
				extra.slice(0, 6)])
	return out


## How many hexes of each reach layer's whole reach Genoa has not discovered.
func _unknown_in_reach() -> Dictionary[String, int]:
	var whole := _wanted_reach(false)
	var known := _wanted_reach(true)
	var out: Dictionary[String, int] = {}
	for layer_name: String in whole:
		out[layer_name] = whole[layer_name].size() - known[layer_name].size()
	return out


func test_no_reach_lies_on_unexplored_paper_and_the_tiles_keep_it_whole() -> void:
	await _open_thin()
	var unknown := _unknown_in_reach()
	for layer_name: String in ["reach", "reach_next", "reach_ahead"]:
		assert_gt(unknown.get(layer_name, 0), 0, "the case: %s reaches into the unknown" % layer_name)
		assert_gt((_wanted_reach(true)[layer_name] as Array).size(), 0, "and holds known hexes too: %s" % layer_name)
	var far := _scene.camera_rig().min_zoom()
	var found: Array[String] = []
	# [mode, zoom, whether the drawn map shows], in an order that goes back and forth.
	for view: Array in [[MapModes.Mode.TERRAIN, 1.0, false], [MapModes.Mode.TERRAIN, far, true],
			[MapModes.Mode.TERRAIN, 1.0, false], [MapModes.Mode.OWNER, far, true], [MapModes.Mode.RELIEF, far, false],
			[MapModes.Mode.GOODS, 1.0, true], [MapModes.Mode.TERRAIN, 1.0, false]]:
		_scene.set_mode(view[0])
		await _at(view[1])
		found.append_array(_fog_problems(view[2], "mode %d at %.2f" % [view[0], view[1]]))
	for on: bool in [false, true]:
		_harness.settings.set_value("map/parchment", on)
		await _at(far)
		found.append_array(_fog_problems(on, "map/parchment %s" % on))
	var armies := _scene.get_node("MapArmies") as MapArmies
	var army := armies.selected_army()
	armies.clear_army()
	assert_true(armies.select_army(army))
	found.append_array(_fog_problems(true, "an army selected on the drawn map"))
	assert_eq(found, [] as Array[String])


func test_the_reach_is_kept_off_the_paper_as_the_drawn_map_comes_in() -> void:
	await _open_thin()
	await _at(1.0)
	_scene.set_process(false)
	(_scene.get_node("MapArmies") as MapArmies).set_process(false)  # the scene alone: no frame may show it unfiltered
	_scene.parchment().set_instant(false)
	_scene.frame_at(_scene.map_size() / 2.0, _scene.camera_rig().min_zoom())
	_scene._process(ParchmentSwitch.FADE_SEC * 0.5)
	assert_true(_scene.parchment().is_fading(), "the case is mid-fade")
	assert_eq(_fog_problems(true, "mid-fade"), [] as Array[String])
	_scene.parchment().set_instant(true)
	_scene.frame_at(_scene.map_size() / 2.0, 1.0)
	assert_eq(_fog_problems(false, "back on the tiles, in the same call"), [] as Array[String])


func test_the_reach_on_the_drawn_map_follows_discovery_and_the_viewer() -> void:
	await _open_thin()
	await _at(_scene.camera_rig().min_zoom())
	assert_eq(_fog_problems(true, "thin"), [] as Array[String])
	var armies := _scene.get_node("MapArmies") as MapArmies
	var before := armies.reach_count("reach_next")
	FogFixture.thin(Session.game, GEN, 2)  # discovered with no army event
	await _harness.wait_frames(self, 2)
	assert_eq(_fog_problems(true, "two rings more discovered"), [] as Array[String])
	assert_gt(armies.reach_count("reach_next"), before, "the case: more of the reach is known now")
	Session.game.player = &""  # the army is the viewer's no longer
	await _harness.wait_frames(self, 2)
	assert_eq(armies.reach_count("reach") + armies.reach_count("reach_next") + armies.reach_count("reach_ahead"), 0,
		"another viewer keeps none of it")


## Every colour the drawn map's land can be under the reach, by name.
func _lands(high: bool) -> Dictionary[String, Color]:
	var colours := ParchmentTokens.colours(high)
	var out: Dictionary[String, Color] = {"land": colours[&"land"]}
	for shade: StringName in [&"goods_1", &"goods_2", &"goods_3"]:
		out[String(shade)] = colours[shade]
	for blind: bool in [false, true]:
		var palette := MapModes.palette(Session.game, blind)
		for country: Country in Session.game.countries:
			var own := Color(palette[country.id], 1.0)
			for strength: float in [ParchmentTokens.OWNER_MIX, MapModes.TINT_ALPHA]:
				out["%s %.2f blind %s" % [country.tag, strength, blind]] = (colours[&"land"] as Color).lerp(own, strength)
	return out


## The lands neither stripe stands out on, and stripes that do not stand apart from each other.
func _stripe_problems(ink: Color, light: Color, high: bool) -> Array[String]:
	var out: Array[String] = []
	if Tokens.contrast_ratio(ink, light) < MARK_MIN:
		out.append("the stripes are alike")
	var lands := _lands(high)
	for what: String in lands:
		var best := maxf(Tokens.contrast_ratio(ink, lands[what]), Tokens.contrast_ratio(light, lands[what]))
		if best < MARK_MIN:
			out.append("%.2f on %s" % [best, what])
	return out


func test_the_hatch_reads_on_every_land_by_pattern() -> void:
	for high: bool in [false, true]:
		var colours := ParchmentTokens.colours(high)
		assert_gt(_lands(high).size(), 20)
		assert_eq(_stripe_problems(colours[&"reach_ink"], colours[&"reach_light"], high), [] as Array[String],
			"high contrast %s" % high)
		var inked := ParchmentTokens.reach_ink_px(high) + ParchmentTokens.REACH_LIGHT_PX
		assert_lt(inked, ParchmentTokens.REACH_PERIOD_PX * 0.7, "land shows between the stripes: a pattern, not a fill")
		assert_gte(ParchmentTokens.reach_ink_px(high), 2.0, "a stripe wide enough to see")
	assert_gt(_stripe_problems(Tokens.MAP_REACH, Color("#fff3b8"), false).size(), 0, "(P) a pale pair is reported")
