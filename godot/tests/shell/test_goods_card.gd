## GUT tests for the Goods mode's HUD (docs/architecture/map-overview-build-spec.md R20, R22, R24, R25, D10): the goods
## card (one button a good with its tooltip, picking, the selected state, the keyboard), the Return button and the
## Layers popover's Parchment map row. The card and the row read and write settings of the map scene's wiring
## (state/map_good, map/parchment): ExtraSettings stands for settings that know them, or do not.
extends GutTest

const HUD_SCENE := preload("res://shell/hud/hud.tscn")
const MAP_SCENE := preload("res://shell/map/map_scene.tscn")
const GEN := &"GEN"
const GOOD := "state/map_good"
const PARCHMENT := "map/parchment"


## Settings whose two parchment keys are held here: a key absent from `extra` is unknown (get null, set refused).
class ExtraSettings extends Settings:
	var extra: Dictionary = {}
	var writes: Array[Array] = []

	func get_value(key: String) -> Variant:
		if key == "state/map_good" or key == "map/parchment":
			return extra.get(key)
		return super(key)

	func set_value(key: String, value: Variant) -> bool:
		if key != "state/map_good" and key != "map/parchment":
			return super(key, value)
		if not extra.has(key):
			return false
		extra[key] = value
		writes.append([key, value])
		changed.emit(key, value)
		return true


## The keys that reach the map's unhandled input.
class KeyCatcher extends Node:
	var keys: Array[Key] = []

	func _unhandled_input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key != null and key.pressed:
			keys.append(key.keycode)


var _harness: UIHarness = null
var _hud: Hud = null
var _settings: ExtraSettings = null
var _catcher: KeyCatcher = null
var _prev_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	assert_eq(Session.new_scenario("north_italy_1480", 1480, GEN), "")
	_harness = UIHarness.new()
	_harness.mount(self)
	_catcher = KeyCatcher.new()
	_harness.viewport.add_child(_catcher)
	_settings = ExtraSettings.new()
	_settings.extra = {GOOD: "grain", PARCHMENT: true}
	_hud = HUD_SCENE.instantiate() as Hud
	_harness.viewport.add_child(_hud)
	_hud.root().theme = KitTheme.load_for(1.0)
	_hud.configure(_settings)


func after_each() -> void:
	_hud = null
	_harness = null
	_settings = null
	_catcher = null
	Session.game = _prev_game
	Bindings.reset_defaults()


func _open() -> GoodsCard:
	_hud.show_mode_parts(MapModes.Mode.GOODS)
	await _harness.wait_frames(self, 3)
	return _hud.goods_card()


## The districts the viewer has discovered that make the good, counted here from Economy.good_of.
func _districts(good_id: int) -> int:
	var game := Session.game
	var view := StateView.of(game.state)
	var seen := MapModes.discovered_bytes(game, GEN)
	var out := 0
	for i: int in game.map.hex_count():
		if seen[i] == 1 and game.map.land[i] == 1 and Economy.good_of(game, view, game.map.hex_of(i)) == good_id:
			out += 1
	return out


func _expected_tip(good: Dictionary) -> String:
	var n := _districts(int(good["id"]))
	var words := "none you know"
	if n == 1:
		words = "1 district you know makes it"
	elif n > 1:
		words = "%d districts you know make it" % n
	return "%s: %s" % [good["name"], words]


## The names of the card's buttons that have no tooltip.
func _untooltipped(card: GoodsCard) -> Array[String]:
	var out: Array[String] = []
	for button: KitButton in card.buttons():
		if button.tooltip_text.strip_edges().is_empty():
			out.append(String(button.name))
	return out


## What is wrong with the shown selection: exactly the button of `key` is held down and carries a visible tick.
func _selection_problems(card: GoodsCard, key: StringName) -> Array[String]:
	var out: Array[String] = []
	for good: Dictionary in ParchmentView.goods_list(Session.game):
		var button := card.button_for(good["key"])
		var chosen: bool = good["key"] == key
		var tick := button.get_node("Tick") as TextureRect
		if button.button_pressed != chosen:
			out.append("%s pressed %s" % [good["key"], button.button_pressed])
		if tick.visible != chosen:
			out.append("%s tick %s" % [good["key"], tick.visible])
		if chosen and tick.texture == null:
			out.append("%s tick has no picture" % good["key"])
	return out


func _focused() -> Control:
	return _harness.viewport.gui_get_focus_owner()


func _mouse(at: Vector2, button: MouseButton, down: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	_harness.push_input(motion)
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.global_position = at
	event.pressed = down
	_harness.push_input(event)


func _press(keycode: Key) -> void:
	_harness.send_key(keycode, true)
	_harness.send_key(keycode, false)
	await _harness.wait_frames(self, 1)


# ----- the card ------------------------------------------------------------------------------------------------------


func test_the_card_shows_in_goods_mode_only_and_not_in_the_pick_or_under_a_screen() -> void:
	await _harness.wait_frames(self, 2)
	var card := _hud.goods_card()
	assert_false(card.visible, "no map: no card")
	for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.OWNER, MapModes.Mode.RELIEF, MapModes.Mode.YIELDS,
			MapModes.Mode.FOOD, MapModes.Mode.SUPPLY]:
		_hud.show_mode_parts(mode)
		assert_false(card.visible, "mode %d: no card" % mode)
	_hud.show_mode_parts(MapModes.Mode.GOODS)
	assert_true(card.visible, "Goods: the card")
	_hud.set_covered(true, true)
	assert_false(card.visible, "a screen hides it")
	_hud.set_covered(false, false)
	assert_true(card.visible)
	_hud.show_mode_parts(MapModes.Mode.GOODS, true)
	assert_false(card.visible, "none during the pick")
	_hud.show_mode_parts(MapModes.Mode.GOODS)
	_hud.set_hud_visible(false)
	assert_false(card.is_visible_in_tree(), "photo mode hides it")


func test_it_is_a_kit_frame_with_one_button_a_good_six_a_row() -> void:
	var card: GoodsCard = await _open()
	assert_true(card is PanelFrame, "the kit's frame")
	assert_eq(card.cartouche().text, "Goods produced")
	assert_true(card.cartouche().visible)
	assert_false(card.close_button().visible, "no close button")
	var goods := ParchmentView.goods_list(Session.game)
	assert_gt(goods.size(), GoodsCard.COLUMNS, "more than a row of goods")
	var buttons := card.buttons()
	assert_eq(buttons.size(), goods.size(), "one button a good")
	var grid := buttons[0].get_parent() as GridContainer
	assert_eq(grid.columns, 6)
	assert_eq(grid.get_child_count(), goods.size())
	for i: int in goods.size():
		assert_eq(buttons[i], grid.get_child(i), "GameDefs order")
		assert_eq(buttons[i], card.button_for(goods[i]["key"]))
		assert_eq(buttons[i].icon_name, goods[i]["icon"] as StringName)
		assert_not_null(buttons[i].icon, "the Kit has the icon of %s" % goods[i]["key"])
		assert_eq(buttons[i].accessibility_name, str(goods[i]["name"]))
		var style := &"ButtonChoice" if goods[i]["key"] == &"grain" else &"ButtonToggle"
		assert_eq(buttons[i].theme_type_variation, style, "the kit's toggle; the chosen one the kit's filled choice")


func test_every_button_has_its_tooltip_with_the_count_you_know() -> void:
	var card: GoodsCard = await _open()
	assert_eq(_untooltipped(card), [] as Array[String])
	var none := 0
	var many := 0
	for good: Dictionary in ParchmentView.goods_list(Session.game):
		var button := card.button_for(good["key"])
		assert_eq(button.tooltip_text, _expected_tip(good))
		assert_false(button.disabled, "every good can be picked: %s" % good["key"])
		if button.tooltip_text.ends_with("none you know"):
			none += 1
			card.pick(good["key"])
			assert_eq(card.good_key(), good["key"] as StringName, "a good nobody makes is pickable")
		elif button.tooltip_text.ends_with("districts you know make it"):
			many += 1
	assert_gt(many, 0, "north Italy makes some goods in several districts")
	gut.p("goods with none you know: %d" % none)
	card.buttons()[3].tooltip_text = ""
	assert_eq(_untooltipped(card).size(), 1, "P: a button without a tooltip is reported")


func test_the_counts_follow_the_world() -> void:
	var card: GoodsCard = await _open()
	var game := Session.game
	var grain := game.defs.good_id(&"grain")
	var before := _districts(grain)
	var button := card.button_for(&"grain")
	var view := StateView.of(game.state)
	var taken := Vector2i(-1, -1)
	for i: int in game.map.hex_count():
		if Economy.good_of(game, view, game.map.hex_of(i)) == grain:
			taken = game.map.hex_of(i)
			break
	game.state.main_use[game.map.index_of(taken)] = 0
	game.state.level[game.map.index_of(taken)] = 0
	game.version += 1
	Events.hex_changed.emit(taken)
	await _harness.wait_frames(self, 2)
	assert_eq(_districts(grain), before - 1)
	assert_eq(button.tooltip_text, "Grain: %d districts you know make it" % (before - 1))
	assert_eq(str(_hud.mode_legend().rows()[-1]["text"]), "%d districts you know make it" % (before - 1),
		"the legend's count follows")


func test_the_soon_rows_are_population_and_unrest_under_the_grid() -> void:
	var card: GoodsCard = await _open()
	var body := card.body()
	assert_eq(body.get_child_count(), 3, "the grid and two rows")
	assert_true(body.get_child(0) is GridContainer)
	var words: Array[String] = []
	for i: int in [1, 2]:
		var line := body.get_child(i) as HBoxContainer
		var label := line.get_child(0) as Label
		words.append(label.text)
		assert_eq(label.theme_type_variation, &"Hint", "greyed")
		assert_true(line.get_child(1) is SoonTag, "the existing soon tag")
		assert_eq(line.find_children("*", "BaseButton", true, false).size(), 0, "nothing to press")
	assert_eq(words, ["Population", "Unrest"] as Array[String])


func test_picking_writes_the_setting_and_says_so() -> void:
	var card: GoodsCard = await _open()
	var told: Array[int] = []
	card.good_changed.connect(func(id: int) -> void: told.append(id))
	assert_eq(card.good_key(), &"grain", "the default")
	card.button_for(&"wine").pressed.emit()
	assert_eq(_settings.writes, [[GOOD, "wine"]] as Array[Array], "state/map_good is written, once")
	var wine := Session.game.defs.good_id(&"wine")
	assert_eq(told, [wine] as Array[int])
	assert_eq(card.good_key(), &"wine")
	assert_eq(card.good_id(), wine)
	assert_eq((_hud.mode_legend().get_node("Column").get_child(0) as Label).text, "Wine", "the legend follows")
	card.button_for(&"wine").pressed.emit()
	assert_eq(told.size(), 1, "the same good again is no change")
	assert_eq(_selection_problems(card, &"wine"), [] as Array[String], "and it stays held down")


func test_a_setting_changed_elsewhere_moves_the_choice_and_an_unknown_key_is_the_first_good() -> void:
	var card: GoodsCard = await _open()
	assert_true(_settings.set_value(GOOD, "salt"))
	assert_eq(card.good_key(), &"salt")
	assert_eq(_selection_problems(card, &"salt"), [] as Array[String])
	assert_eq((_hud.mode_legend().get_node("Column").get_child(0) as Label).text, "Salt")
	_settings.set_value(GOOD, "unicorns")
	var first := ParchmentView.goods_list(Session.game)[0]
	assert_eq(card.good_key(), first["key"] as StringName, "an unknown key falls back to the first good")
	assert_eq(card.good_id(), int(first["id"]))
	assert_eq(_selection_problems(card, first["key"]), [] as Array[String])


func test_the_saved_good_is_read_when_the_settings_come() -> void:
	var other := ExtraSettings.new()
	other.extra = {GOOD: "timber"}
	_hud.configure(other)
	var card: GoodsCard = await _open()
	assert_eq(card.good_key(), &"timber")
	assert_eq(other.writes, [] as Array[Array], "reading writes nothing")


func test_without_the_setting_the_card_remembers_the_choice() -> void:
	var bare := ExtraSettings.new()  # neither key known
	_hud.configure(bare)
	var card: GoodsCard = await _open()
	assert_eq(card.good_key(), &"grain")
	card.button_for(&"wine").pressed.emit()
	assert_eq(card.good_key(), &"wine")
	assert_eq(bare.writes, [] as Array[Array])
	_hud.show_mode_parts(MapModes.Mode.TERRAIN)
	_hud.show_mode_parts(MapModes.Mode.GOODS)
	assert_eq(_selection_problems(card, &"wine"), [] as Array[String], "kept across a mode change")


func test_the_chosen_good_is_marked_by_more_than_colour() -> void:
	var card: GoodsCard = await _open()
	assert_eq(_selection_problems(card, &"grain"), [] as Array[String])
	card.pick(&"wine")
	assert_eq(_selection_problems(card, &"wine"), [] as Array[String])
	(card.button_for(&"wine").get_node("Tick") as TextureRect).visible = false
	assert_eq(_selection_problems(card, &"wine").size(), 1, "P: a choice told by its fill alone is reported")


func test_the_keyboard_walks_the_grid_and_picks_without_reaching_the_map() -> void:
	var card: GoodsCard = await _open()
	var buttons := card.buttons()
	for button: KitButton in buttons:
		assert_eq(button.focus_mode, Control.FOCUS_ALL)
	card.focus_selected()
	assert_eq(_focused(), card.button_for(&"grain"), "the chosen good takes the focus")
	var at := buttons.find(card.button_for(&"grain"))
	assert_eq(at, 0, "grain is the first")
	await _press(KEY_LEFT)
	assert_eq(_focused(), buttons[0], "the left edge holds")
	await _press(KEY_UP)
	assert_eq(_focused(), buttons[0], "the top edge holds")
	await _press(KEY_RIGHT)
	assert_eq(_focused(), buttons[1])
	await _press(KEY_DOWN)
	assert_eq(_focused(), buttons[7], "down a row")
	await _press(KEY_ENTER)
	assert_eq(card.good_id(), int(ParchmentView.goods_list(Session.game)[7]["id"]), "Enter picks")
	var repeat := InputEventKey.new()
	repeat.keycode = KEY_SPACE
	repeat.physical_keycode = KEY_SPACE
	repeat.pressed = true
	repeat.echo = true
	_harness.push_input(repeat)
	assert_eq(_focused(), buttons[7], "a keyboard pick keeps the focus")
	await _press(KEY_RIGHT)
	await _press(KEY_SPACE)
	assert_eq(card.good_id(), int(ParchmentView.goods_list(Session.game)[8]["id"]), "Space picks")
	for i: int in 6:
		await _press(KEY_RIGHT)
	assert_eq(_focused(), buttons[11], "the right edge holds")
	await _press(KEY_DOWN)
	assert_eq(_focused(), buttons[buttons.size() - 1], "above a short last row: its last button")
	await _press(KEY_DOWN)
	assert_eq(_focused(), buttons[buttons.size() - 1], "the bottom edge holds")
	assert_false(_catcher.keys.has(KEY_ENTER) or _catcher.keys.has(KEY_SPACE), "no End turn under the card")
	assert_false(_catcher.keys.has(KEY_RIGHT) or _catcher.keys.has(KEY_DOWN), "the arrows stay in the card")


func test_a_mouse_pick_lets_the_focus_go() -> void:
	var card: GoodsCard = await _open()
	_harness.send_click(card.button_for(&"wine").get_global_rect().get_center())
	await _harness.wait_frames(self, 1)
	assert_eq(card.good_key(), &"wine", "the click picks")
	assert_null(_focused(), "Space ends the turn again")
	await _press(KEY_SPACE)
	assert_true(_catcher.keys.has(KEY_SPACE))


func test_a_press_dragged_off_a_button_lets_the_focus_go() -> void:
	var card: GoodsCard = await _open()
	var from := card.button_for(&"wine").get_global_rect().get_center()
	var away := Vector2(900.0, 300.0)
	for button: MouseButton in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		_catcher.keys.clear()
		_mouse(from, button, true)
		_mouse(away, button, false)
		await _harness.wait_frames(self, 1)
		assert_eq(card.good_key(), &"grain", "button %d: dragged off, nothing is picked" % button)
		assert_null(_focused(), "button %d: and nothing holds the focus" % button)
		await _press(KEY_SPACE)
		assert_true(_catcher.keys.has(KEY_SPACE), "button %d: Space ends the season" % button)
	card.focus_selected()
	_mouse(from, MOUSE_BUTTON_LEFT, true)
	_mouse(from, MOUSE_BUTTON_LEFT, false)
	await _harness.wait_frames(self, 1)
	assert_eq(card.good_key(), &"wine", "a click still picks, from the keyboard's focus too")
	assert_null(_focused())


func test_the_keyboard_comes_in_by_focus_selected_and_leaves_by_esc() -> void:
	var input := AppInput.new()
	_harness.viewport.add_child(input)
	var backs: Array[int] = []
	input.back_requested.connect(func() -> void: backs.append(1))
	await _harness.wait_frames(self, 2)
	var card := _hud.goods_card()
	assert_false(card.focus_selected(), "hidden: nothing takes the focus")
	card = await _open()
	card.pick(&"wine")
	assert_true(card.focus_selected())
	assert_eq(_focused(), card.button_for(&"wine"), "the chosen good")
	await _press(KEY_ESCAPE)
	assert_null(_focused(), "Esc: the focus is the map's again")
	assert_eq(backs.size(), 0, "and Esc did nothing else: no Esc ladder, no pause menu")
	assert_false(_catcher.keys.has(KEY_ESCAPE))
	await _press(KEY_SPACE)
	assert_true(_catcher.keys.has(KEY_SPACE), "Space is the map's")
	await _press(KEY_ESCAPE)
	assert_eq(backs.size(), 1, "with no focus in the card Esc goes up the ladder as ever")


func test_the_card_fits_the_map_area_clear_of_the_legend_and_the_log() -> void:
	var card: GoodsCard = await _open()
	for view: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 600)]:
		_harness.viewport.size = view
		await _harness.wait_frames(self, 4)
		var rect := card.get_global_rect()
		var tag := str(view)
		assert_true(_hud.map_area().get_global_rect().encloses(rect), "%s: inside the map area %s" % [tag, rect])
		assert_almost_eq(rect.position.x, _hud.map_area().get_global_rect().position.x + 12.0, 0.5, "%s: left" % tag)
		assert_gt(rect.position.y, _hud.mode_legend().get_global_rect().end.y, "%s: under the legend" % tag)
		assert_lt(rect.end.y, _hud.action_log().get_global_rect().position.y, "%s: above the log's button" % tag)
		assert_false(rect.intersects(_hud.return_button().get_global_rect()), "%s: clear of Return" % tag)
		assert_false(rect.intersects(_hud.minimap().get_global_rect()), "%s: clear of the minimap" % tag)
		assert_true(_hud.cover_rects().has(Hud.screen_rect(card)), "%s: it is a cover rect" % tag)
	_hud.show_mode_parts(MapModes.Mode.TERRAIN)
	assert_eq(_hud.cover_rects().filter(func(r: Rect2) -> bool: return r == Hud.screen_rect(card)).size(), 0,
		"hidden: it covers nothing")


func test_its_files_add_no_look_of_their_own() -> void:
	for path: String in ["res://shell/hud/goods_card.gd", "res://shell/hud/goods_card.tscn"]:
		var text := FileAccess.get_file_as_string(path)
		assert_false(text.is_empty(), path)
		assert_false(text.contains("StyleBox") or text.contains("Color(") or text.contains("theme_override"), path)


# ----- the Return button ----------------------------------------------------------------------------------------------


func test_return_shows_in_every_mode_but_terrain_and_asks_for_terrain() -> void:
	await _harness.wait_frames(self, 2)
	var button := _hud.return_button()
	assert_false(button.visible, "no map: no button")
	for mode: int in [MapModes.Mode.OWNER, MapModes.Mode.RELIEF, MapModes.Mode.YIELDS, MapModes.Mode.FOOD,
			MapModes.Mode.SUPPLY, MapModes.Mode.GOODS]:
		_hud.show_mode_parts(mode)
		assert_true(button.visible, "mode %d: shown" % mode)
		_hud.show_mode_parts(mode, true)
		assert_false(button.visible, "mode %d: not during the pick" % mode)
	_hud.show_mode_parts(MapModes.Mode.TERRAIN)
	assert_false(button.visible, "hidden in Terrain")
	_hud.show_mode_parts(MapModes.Mode.GOODS)
	assert_eq(button.text, "Return to default map")
	assert_eq(button.focus_mode, Control.FOCUS_NONE)
	var asked: Array[int] = []
	_hud.mode_requested.connect(func(mode: int) -> void: asked.append(mode))
	await _harness.wait_frames(self, 2)
	_harness.send_click(button.get_global_rect().get_center())
	await _harness.wait_frames(self, 1)
	assert_eq(asked, [int(MapModes.Mode.TERRAIN)] as Array[int])


func test_return_names_its_key_and_follows_a_rebinding() -> void:
	await _harness.wait_frames(self, 2)
	var button := _hud.return_button()
	assert_eq(button.tooltip_text, "Show the terrain map [1]")
	assert_true(bool(Bindings.apply_overrides({"view_mode_1": "K"})["ok"]))
	_hud.refresh_bindings()
	assert_eq(button.tooltip_text, "Show the terrain map [K]")


func test_return_sits_at_the_foot_clear_of_what_covers_the_map() -> void:
	await _harness.wait_frames(self, 2)
	var button := _hud.return_button()
	for view: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 600)]:
		for docked: bool in [false, true]:
			_harness.viewport.size = view
			if docked:
				_hud.show_country(&"SAV", false)
			else:
				_hud.close_dock()
			_hud.show_mode_parts(MapModes.Mode.OWNER)
			await _harness.wait_frames(self, 4)
			var tag := "%s dock %s" % [view, docked]
			var rect := button.get_global_rect()
			var area := _hud.map_area().get_global_rect()
			assert_true(area.encloses(rect), "%s: in the map area %s %s" % [tag, area, rect])
			var own := Hud.screen_rect(button)
			assert_true(_hud.cover_rects().has(own), "%s: it is a cover rect" % tag)
			for r: Rect2 in _hud.cover_rects():
				if r != own:
					assert_false(r.intersects(own), "%s: clear of %s (button %s)" % [tag, r, own])
			assert_false(rect.intersects(_hud.key_hints().get_global_rect()), "%s: above the key hints" % tag)
			assert_false(rect.intersects(_hud.action_log().get_global_rect()), "%s: beside the log's button" % tag)
			assert_lte(_hud.toast_host().get_global_rect().end.y, rect.position.y, "%s: the toasts keep above" % tag)
			if view.x == 1280 and not docked:
				assert_almost_eq(rect.get_center().x, area.get_center().x, 1.0, "%s: the middle" % tag)
	_hud.show_mode_parts(MapModes.Mode.TERRAIN)
	await _harness.wait_frames(self, 2)
	assert_eq(_hud.toast_host().offset_bottom, Hud.TOASTS_BOTTOM, "the toasts come back down")


func test_return_moves_clear_when_the_minimap_comes_back() -> void:
	_harness.viewport.size = Vector2i(880, 600)  # narrow enough, with the dock, for the minimap to reach the middle
	_hud.show_country(&"SAV", false)
	await _harness.wait_frames(self, 2)
	_hud.minimap().visible = false
	_hud.show_mode_parts(MapModes.Mode.OWNER)
	await _harness.wait_frames(self, 4)
	var button := _hud.return_button()
	var without := button.get_global_rect()
	_hud.minimap().visible = true
	await _harness.wait_frames(self, 4)
	var mini := _hud.minimap().get_global_rect()
	assert_true(without.intersects(mini), "P: where it sat without the minimap would run into it %s %s" % [without, mini])
	assert_false(button.get_global_rect().intersects(mini), "it moved: %s %s" % [button.get_global_rect(), mini])


func test_the_pick_ending_brings_the_button_when_the_mode_stays() -> void:
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "")
	_settings.set_value("state/map_mode", "owner")  # the pick shows Owner too: no mode change when it ends
	var scene := MAP_SCENE.instantiate() as MapScene
	scene.preload_next_season = false
	scene.configure(_settings)
	_harness.viewport.add_child(scene)
	_hud.bind_map_scene(scene)
	await _harness.wait_frames(self, 2)
	assert_true(scene.picking())
	assert_false(_hud.return_button().visible, "none during the pick")
	assert_true(bool(Session.act("choose_country", {"tag": "GEN"})["ok"]))
	await _harness.wait_frames(self, 2)
	assert_eq(scene.mode(), int(MapModes.Mode.OWNER))
	assert_true(_hud.return_button().visible, "the pick ended in Owner mode")
	scene.set_mode(MapModes.Mode.TERRAIN)
	assert_false(_hud.return_button().visible, "and the scene's mode changes are followed")


# ----- the Layers popover --------------------------------------------------------------------------------------------


func test_the_layers_popover_has_the_parchment_switch() -> void:
	await _harness.wait_frames(self, 2)
	var popover := _hud.layers_popover()
	var switch := popover.parchment_switch()
	var row := switch.get_parent() as Control
	assert_true(row.visible)
	assert_eq((row.get_node("Label") as Label).text, "Parchment map")
	assert_true(switch.button_pressed, "follows the setting")
	assert_eq(switch.focus_mode, Control.FOCUS_NONE)
	var told: Array[Array] = []
	_hud.layer_toggled.connect(func(key: StringName, on: bool) -> void: told.append([key, on]))
	switch.button_pressed = false
	assert_eq(_settings.writes, [[PARCHMENT, false]] as Array[Array], "writes map/parchment")
	assert_eq(told, [[LayersPopover.LAYER_PARCHMENT, false]] as Array[Array])
	_settings.set_value(PARCHMENT, true)
	assert_true(switch.button_pressed, "follows a change elsewhere")
	popover.set_open(true)
	await _harness.wait_frames(self, 2)
	assert_lte(popover.get_global_rect().end.y, _hud.map_area().get_global_rect().end.y, "the popover still fits")


func test_the_parchment_row_waits_for_its_setting() -> void:
	await _harness.wait_frames(self, 2)
	_hud.configure(ExtraSettings.new())
	assert_false((_hud.layers_popover().parchment_switch().get_parent() as Control).visible,
		"no row while the settings do not know the key")
