## GUT test for the top bar's mode segments (docs/architecture/m5-build-spec.md 6.1, 6.10): Food, key 5, only in a game with a
## player; Goods, key 7, with the bar's width, and the hover card's one line on the parchment (map-overview-build-spec.md
## R19, R23). It sits beside test_hud.gd, whose size it keeps down.
extends GutTest

const HUD_SCENE := preload("res://shell/hud/hud.tscn")

var _harness: UIHarness = null
var _hud: Hud = null
var _prev_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	_harness = UIHarness.new()
	_harness.mount(self)
	_hud = HUD_SCENE.instantiate() as Hud
	_harness.viewport.add_child(_hud)
	_hud.root().theme = KitTheme.load_for(1.0)
	_hud.setup(_harness.ctx)


func after_each() -> void:
	_hud = null
	_harness = null
	Session.game = _prev_game
	Bindings.reset_defaults()


func test_the_mode_switch_has_seven_segments_food_is_key_5_supply_6_and_goods_7() -> void:
	await _harness.wait_frames(self, 2)
	var top := _hud.top_bar()
	var seg := top.mode_segmented()
	var food := int(MapModes.Mode.FOOD)
	assert_null(seg.button_for(food), "no Food in a sandbox")
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "")
	top.refresh_game()
	assert_null(seg.button_for(food), "no Food while picking")
	assert_true(bool(Session.act("choose_country", {"tag": "GEN"})["ok"]))
	await _harness.wait_frames(self, 1)
	var btn := seg.button_for(food)
	assert_not_null(btn, "Food is the fifth segment once you play")
	assert_eq(btn.text, "Food")
	assert_true(btn.tooltip_text.contains("[5]"), "its tooltip names key 5")
	assert_eq(TopBar.MODE_LABELS.size(), 7, "seven mode segments: Goods is the seventh")
	assert_eq(TopBar.MODE_KEYS.size(), 7)
	assert_eq(TopBar.MODE_LABELS.size(), MapModes.MODE_KEYS.size(), "a segment for every mode")
	var goods := seg.button_for(int(MapModes.Mode.GOODS))
	assert_not_null(goods, "Goods is the seventh segment once you play")
	assert_eq(goods.text, "Goods")
	assert_true(goods.tooltip_text.contains("[7]"), "its tooltip names key 7")
	var supply := seg.button_for(int(MapModes.Mode.SUPPLY))
	assert_not_null(supply, "Supply is the sixth segment once you play")
	assert_eq(supply.text, "Supply")
	assert_true(supply.tooltip_text.contains("[6]"), "its tooltip names key 6")
	var chosen: Array[int] = []
	_hud.mode_requested.connect(func(mode: int) -> void: chosen.append(mode))
	seg.select(food, true)
	assert_eq(chosen, [4], "the fifth segment reaches the Hud as mode 4")
	seg.select(int(MapModes.Mode.SUPPLY), true)
	assert_eq(chosen, [4, 5], "the sixth segment reaches the Hud as mode 5 (Supply)")
	top.set_mode(food)
	assert_true(btn.button_pressed, "Food is shown selected, not Yields")
	assert_false(seg.button_for(int(MapModes.Mode.YIELDS)).button_pressed)
	top.set_mode(int(MapModes.Mode.SUPPLY))
	assert_true(supply.button_pressed, "Supply is shown selected when set")
	seg.select(int(MapModes.Mode.GOODS), true)
	assert_eq(chosen, [4, 5, 6], "the seventh segment reaches the Hud as mode 6 (Goods)")
	top.set_mode(food)
	top.set_mode(int(MapModes.Mode.GOODS))
	assert_true(goods.button_pressed, "Goods is shown selected when set")


# ----- Goods, the seventh segment, and the hover's one line (map-overview-build-spec.md R19, R23) --------------------


func test_goods_is_offered_where_yields_is_once() -> void:
	await _harness.wait_frames(self, 2)
	var seg := _hud.top_bar().mode_segmented()
	var goods := int(MapModes.Mode.GOODS)
	assert_null(seg.button_for(goods), "no Goods in a sandbox")
	assert_false(TopBar.offered_modes(Session.game).has(goods))
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "")
	_hud.top_bar().refresh_game()
	assert_null(seg.button_for(goods), "no Goods while picking")
	assert_true(bool(Session.act("choose_country", {"tag": "GEN"})["ok"]))
	await _harness.wait_frames(self, 1)
	assert_not_null(seg.button_for(goods), "Goods once you play")
	assert_eq(TopBar.offered_modes(Session.game).count(goods), 1)
	assert_eq(TopBar.offered_modes(Session.game).size(), 7)


func test_the_bar_fits_1280_by_720_with_seven_segments() -> void:
	await _harness.wait_frames(self, 2)
	assert_eq(Session.new_scenario("north_italy_1480", 1480, &"GEN"), "")
	var top := _hud.top_bar()
	top.refresh_game()
	await _harness.wait_frames(self, 3)
	var seg := top.mode_segmented()
	var row := seg.get_node("Buttons") as HBoxContainer
	for view: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 600), Vector2i(1280, 720)]:
		_harness.viewport.size = view
		await _harness.wait_frames(self, 4)
		var tag := str(view)
		assert_eq(row.get_child_count(), 7, "%s: seven segments" % tag)
		assert_lte(top.get_combined_minimum_size().x, float(view.x), "%s: the bar fits" % tag)
		assert_lte(top.size.x, float(view.x), "%s: no wider than the window" % tag)
		assert_lte(top.menu_button().get_global_rect().end.x, float(view.x), "%s: Menu is not clipped" % tag)
		var edge := seg.get_global_rect().position.x
		for button: Button in row.get_children():
			assert_true(button.is_visible_in_tree(), "%s: %s shows" % [tag, button.text])
			assert_gte(button.get_global_rect().position.x, edge, "%s: %s follows the one before" % [tag, button.text])
			assert_gte(button.size.x, button.get_combined_minimum_size().x, "%s: %s is not squeezed" % [tag, button.text])
			edge = button.get_global_rect().end.x
		assert_lte(edge, float(view.x), "%s: the segments are inside" % tag)
	top.fit_width(700.0)
	assert_lte(top.get_combined_minimum_size().x, 700.0, "even 700 px")
	assert_eq(row.get_theme_constant(&"separation"), TopBar.COMPACT_GAP, "tight: the gap closes")
	row.remove_theme_constant_override(&"separation")
	assert_gt(top.get_combined_minimum_size().x, 700.0, "P: seven segments with the wide gap do not fit")
	top.fit_width(4000.0)
	assert_gt(row.get_theme_constant(&"separation"), TopBar.COMPACT_GAP, "wide: the usual gap")
	top.fit_width(700.0)
	top.refresh_game()  # new buttons: the gap is put right with them
	top.fit_width(4000.0)
	assert_gt(row.get_theme_constant(&"separation"), TopBar.COMPACT_GAP)
	_harness.viewport.size = Vector2i(1280, 720)


## A discovered hex of Genoa's that makes a good, and that good's id.
func _producer() -> Array:
	var game := Session.game
	var view := StateView.of(game.state)
	for i: int in game.map.hex_count():
		var good := Economy.good_of(game, view, game.map.hex_of(i))
		if good >= 0 and Territory.owner_tag(game, game.map.hex_of(i)) == &"GEN":
			return [game.map.hex_of(i), good]
	return []


func _hover_on(hex: Vector2i) -> MapHover:
	var hover := _hud.map_hover()
	hover.hover_delay_sec = 0.0
	_hud.on_hover_changed(MapInput.NO_HEX)
	_hud.on_hover_changed(hex, Vector2(400.0, 300.0))
	return hover


## The card's rows as words, its title first when it shows one.
func _card_words(hover: MapHover) -> Array[String]:
	var out: Array[String] = []
	var title := hover.card().get_node("VBox/Title") as Label
	if title.visible:
		out.append(title.text)
	for row: Node in hover.card().rows_container().get_children():
		if row is HBoxContainer:
			out.append((row.get_child(0) as Label).text)
	return out


func test_the_solid_parchment_turns_the_hover_card_into_one_line_and_back() -> void:
	assert_eq(Session.new_scenario("north_italy_1480", 1480, &"GEN"), "")
	await _harness.wait_frames(self, 2)
	var found := _producer()
	assert_eq(found.size(), 2, "Genoa makes something")
	var hex: Vector2i = found[0]
	_hud.show_mode_parts(MapModes.Mode.TERRAIN)
	var hover := _hover_on(hex)
	var full := _card_words(hover)
	var title := str(HexCard.of(Session.game, hex)["title"])
	assert_eq(full[0], title, "the hex card")
	var full_height := hover.card().get_combined_minimum_size().y
	Events.map_parchment.emit(true)
	var line := ParchmentView.tip(Session.game, &"GEN", hex, MapModes.Mode.TERRAIN, int(found[1]))
	assert_true(line.contains("Genoa"), line)
	assert_eq(_card_words(hover), [line] as Array[String], "the card on show changes at once")
	assert_eq(hover.card().accessibility_name, line)
	assert_lt(hover.card().size.y, full_height, "and shrinks to its line")
	_hover_on(hex)
	assert_eq(_card_words(hover), [line] as Array[String], "a new hover too")
	Events.map_parchment.emit(false)
	assert_eq(_card_words(hover), full, "the hex card again")
	_hover_on(hex)
	assert_eq(_card_words(hover), full)


## A map scene in the harness, bound to the Hud.
func _bound_scene() -> MapScene:
	var scene := (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	scene.preload_next_season = false
	scene.configure(_harness.settings)
	_harness.viewport.add_child(scene)
	_hud.bind_map_scene(scene)
	return scene


func test_a_new_map_scene_forgets_that_the_parchment_was_solid() -> void:
	assert_eq(Session.new_scenario("north_italy_1480", 1480, &"GEN"), "")
	await _harness.wait_frames(self, 2)
	var hover := _hud.map_hover()
	var first := _bound_scene()
	Events.map_parchment.emit(true)
	_hud.bind_map_scene(first)
	assert_true(hover.shows_line(), "the same scene bound again: it will not say it twice, so it stands")
	_bound_scene()
	assert_false(hover.shows_line(), "another scene: the hex card until it says otherwise")
	Events.map_parchment.emit(true)
	_hud.bind_map_scene(null)
	assert_false(hover.shows_line(), "the game left: forgotten")
	Events.map_parchment.emit(true)
	assert_true(hover.shows_line(), "P: the signal still works")
	_hud.bind_map_scene(null)
	assert_eq(Session.new_scenario("north_italy_1480", 1481, &"GEN"), "")
	_bound_scene()
	assert_true(hover.shows_line(), "said before its first bind: the new scene's word is kept")


func test_goods_mode_names_the_chosen_good_and_its_stage_on_hover() -> void:
	assert_eq(Session.new_scenario("north_italy_1480", 1480, &"GEN"), "")
	await _harness.wait_frames(self, 2)
	var found := _producer()
	var hex: Vector2i = found[0]
	var good: GoodDef = Session.game.defs.good(int(found[1]))
	_hud.show_mode_parts(MapModes.Mode.GOODS)
	_hud.goods_card().pick(good.key)
	var hover := _hover_on(hex)
	var with_stage := ParchmentView.tip(Session.game, &"GEN", hex, MapModes.Mode.GOODS, good.id)
	assert_true(with_stage.contains(good.name + ", ") and with_stage.ends_with("stage"), with_stage)
	assert_eq(_card_words(hover), [with_stage] as Array[String])
	var other: StringName = &"salt" if good.key != &"salt" else &"grain"
	_hud.goods_card().pick(other)
	var without := ParchmentView.tip(Session.game, &"GEN", hex, MapModes.Mode.GOODS, Session.game.defs.good_id(other))
	assert_ne(without, with_stage)
	assert_eq(_card_words(hover), [without] as Array[String], "another good: the card on show follows")
	_hud.show_mode_parts(MapModes.Mode.OWNER)
	assert_eq(_card_words(hover)[0], str(HexCard.of(Session.game, hex)["title"]), "out of Goods: the hex card")


func test_an_undiscovered_hex_reads_unexplored_in_the_line() -> void:
	assert_eq(Session.new_scenario("north_italy_1480", 1480, &"GEN"), "")
	FogFixture.thin(Session.game, &"GEN", 0)
	await _harness.wait_frames(self, 2)
	var seen := MapModes.discovered_bytes(Session.game, &"GEN")
	var at := seen.find(0)
	assert_gte(at, 0, "the thin fixture leaves hexes undiscovered")
	_hud.show_mode_parts(MapModes.Mode.GOODS)
	var hover := _hover_on(Session.game.map.hex_of(at))
	assert_eq(_card_words(hover), ["Unexplored"] as Array[String])
