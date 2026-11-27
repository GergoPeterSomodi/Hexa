## GUT tests for where the HUD's movable parts go (shell/hud/hud_layout.gd; map-overview-build-spec.md R20, R22): the
## goods card at small logical sizes, the open action log beside it, and the Return button clear of the minimap's corner.
## The HUD has a bound map scene, so the minimap, the task flag and the key hints stand where the game puts them.
extends GutTest

const HUD_SCENE := preload("res://shell/hud/hud.tscn")
const MAP_SCENE := preload("res://shell/map/map_scene.tscn")
const GEN := &"GEN"
const LOG_OPEN := "state/log_open"
## The logical sizes without the dock at which the card, the legend and the rest of the HUD all find room.
const ROOMY: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1024, 576), Vector2i(960, 540), Vector2i(853, 480),
	Vector2i(683, 400)]
## Under 699 px the top bar is wider than the window: at the smallest size there is room for the card, not the legend.
const SMALLEST := Vector2i(640, 360)


class WatchedSettings extends Settings:
	var writes: Array[String] = []

	func set_value(key: String, value: Variant) -> bool:
		writes.append(key)
		return super(key, value)


var _harness: UIHarness = null
var _hud: Hud = null
var _scene: MapScene = null
var _settings: WatchedSettings = null
var _prev_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	assert_eq(Session.new_scenario("north_italy_1480", 1480, GEN), "")
	_harness = UIHarness.new()
	_harness.mount(self)
	_settings = WatchedSettings.new()
	_settings.set_value("accessibility/reduce_motion", true)  # the log's card is where it belongs at once
	_scene = MAP_SCENE.instantiate() as MapScene
	_scene.preload_next_season = false
	_scene.configure(_settings)
	_harness.viewport.add_child(_scene)
	_hud = HUD_SCENE.instantiate() as Hud
	_harness.viewport.add_child(_hud)
	_hud.root().theme = KitTheme.load_for(1.0)
	_hud.configure(_settings)
	_hud.bind_map_scene(_scene)


func after_each() -> void:
	_hud = null
	_scene = null
	_harness = null
	_settings = null
	Session.game = _prev_game
	Bindings.reset_defaults()


## The window at `view`, with the tile window open or closed, showing the mode `mode`.
func _show(view: Vector2i, mode: int, docked: bool = false) -> void:
	_harness.viewport.size = view
	_hud.tile_window().visible = docked
	_hud.show_mode_parts(mode)
	await _harness.wait_frames(self, 6)


func _rect(part: Control) -> Rect2:
	return Hud.screen_rect(part)


## The key hints' rect as wide as their words (the node is wider).
func _hints() -> Rect2:
	var out := _rect(_hud.key_hints())
	out.size.x = _hud.key_hints().get_combined_minimum_size().x
	return out


func _log_card() -> Control:
	return _hud.action_log().get_node("Card") as Control


## The control the pointer finds at `at`.
func _under(at: Vector2) -> Control:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	_harness.push_input(motion)
	return _harness.viewport.gui_get_hovered_control()


## The points of `part` (left, middle, right) where the pointer finds something else.
func _unreachable(part: Control) -> Array[String]:
	var out: Array[String] = []
	var rect := _rect(part)
	for across: float in [0.08, 0.5, 0.92]:
		var at := rect.position + rect.size * Vector2(across, 0.5)
		var found := _under(at)
		if found != part:
			out.append("%s at %s: %s" % [part.name, at, "nothing" if found == null else str(found.name)])
	return out


## What `part` runs into: the screen's edges, the top bar, and each of `others` that shows.
func _clashes(name_of: String, rect: Rect2, others: Array[Control]) -> Array[String]:
	var out: Array[String] = []
	var screen := Rect2(Vector2.ZERO, _harness.viewport.size)
	if not screen.encloses(rect):
		out.append("%s leaves the screen %s" % [name_of, rect])
	if rect.position.y < _rect(_hud.top_bar()).end.y:
		out.append("%s under the top bar %s" % [name_of, rect])
	for other: Control in others:
		if not other.is_visible_in_tree():
			continue
		var theirs := _hints() if other == _hud.key_hints() else _rect(other)
		if rect.intersects(theirs):
			out.append("%s %s over %s %s" % [name_of, rect, other.name, theirs])
	return out


## Everything wrong with the card's place and its buttons.
func _card_problems(with_flag: bool = true) -> Array[String]:
	var card := _hud.goods_card()
	var others: Array[Control] = [_hud.mode_legend(), _hud.minimap(), _hud.zoom_control(), _hud.scale_bar(),
		_hud.return_button(), _hud.action_log(), _hud.key_hints()]
	if with_flag:
		others.append(_hud.task_flag())
	var out := _clashes("card", _rect(card), others)
	var window := _rect(card.body_scroll())
	for button: KitButton in card.buttons():
		if window.grow(0.5).encloses(_rect(button)):
			out.append_array(_unreachable(button))
		elif not card.body_scroll().get_v_scroll_bar().visible:
			out.append("%s is cut off with no scroll bar" % button.name)
	return out


# ----- C: the card at small sizes ------------------------------------------------------------------------------------


func test_the_card_fits_every_small_size_with_all_its_goods() -> void:
	for view: Vector2i in ROOMY:
		await _show(view, MapModes.Mode.GOODS)
		var tag := str(view)
		var card := _hud.goods_card()
		assert_true(_hud.minimap().is_visible_in_tree(), "%s: the minimap is there to run into" % tag)
		assert_eq(_card_problems(), [] as Array[String], tag)
		assert_eq(card.layout().z, 0, "%s: every good without scrolling" % tag)
		assert_eq(card.size, card.size_for(card.layout()), "%s: the card is the size it was placed as" % tag)
		var legend := _hud.mode_legend()
		assert_true(legend.is_visible_in_tree(), "%s: the legend shows" % tag)
		assert_eq(_clashes("legend", _rect(legend), [card, _hud.minimap(), _hud.zoom_control(), _hud.scale_bar(),
				_hud.return_button(), _hud.action_log()] as Array[Control]), [] as Array[String], tag)
		assert_true(_hud.cover_rects().has(_rect(card)), "%s: a cover rect" % tag)


func test_at_the_smallest_size_the_card_stays_clear_and_the_legend_gives_way() -> void:
	await _show(SMALLEST, MapModes.Mode.GOODS)
	assert_eq(_card_problems(), [] as Array[String])
	assert_eq(_hud.goods_card().layout().z, 0, "every good without scrolling")
	assert_false(_hud.mode_legend().visible, "no room for both: the legend is left out")
	await _show(Vector2i(1280, 720), MapModes.Mode.GOODS)
	assert_true(_hud.mode_legend().visible, "and it comes back with the room")
	assert_eq(_hud.goods_card().layout(), Vector3i(GoodsCard.COLUMNS, 1, 0), "with the soon rows, six a row")
	var area := _hud.map_area().get_global_rect()
	var rect := _hud.goods_card().get_global_rect()
	assert_almost_eq(rect.position.x - area.position.x, HudLayout.LEFT, 0.5, "bottom left again")
	assert_almost_eq(area.end.y - rect.end.y, HudLayout.CARD_FOOT, 0.5)
	assert_almost_eq(_hud.mode_legend().offset_left, HudLayout.LEFT, 0.5)
	assert_almost_eq(_hud.mode_legend().offset_top, Hud.LEGEND_TOP, 0.5)


func test_with_the_dock_open_the_card_still_keeps_clear() -> void:
	for view: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 576), Vector2i(960, 540), Vector2i(853, 480)]:
		await _show(view, MapModes.Mode.GOODS, true)
		var tag := str(view)
		# At 853 the dock leaves 305 px, where the HUD's own legend and task flag already overlap.
		assert_eq(_card_problems(), [] as Array[String], tag)
		if _hud.mode_legend().visible:
			assert_false(_rect(_hud.mode_legend()).intersects(_rect(_hud.goods_card())), "%s: the legend" % tag)


func test_a_card_that_scrolls_follows_the_keyboard() -> void:
	await _show(Vector2i(853, 480), MapModes.Mode.GOODS, true)
	var card := _hud.goods_card()
	assert_gt(card.layout().z, 0, "P: short of room, the card shows only some rows")
	assert_true(card.focus_selected())
	var last := card.buttons()[-1]
	var columns := card.layout().x
	var rows := ceili(float(card.buttons().size()) / columns)
	assert_gt(rows, card.layout().z, "P: more rows than show")
	var walk: Array[Key] = []
	for i: int in rows - 1:
		walk.append(KEY_DOWN)
	for i: int in columns - 1:
		walk.append(KEY_RIGHT)
	for keycode: Key in walk:
		_harness.send_key(keycode, true)
		_harness.send_key(keycode, false)
		await _harness.wait_frames(self, 1)
		var focused := _harness.viewport.gui_get_focus_owner()
		assert_true(_rect(card.body_scroll()).grow(0.5).encloses(_rect(focused)), "%s is in view" % focused.name)
	assert_eq(_harness.viewport.gui_get_focus_owner(), last, "down to the last good")


func test_a_settled_layout_asks_for_nothing_more() -> void:
	for view: Vector2i in [Vector2i(683, 400), SMALLEST]:
		await _show(view, MapModes.Mode.GOODS)
		var count := [0]
		var counted := func() -> void: count[0] += 1
		_hud.cover_changed.connect(counted)
		await _harness.wait_frames(self, 12)
		assert_eq(count[0], 0, "%s: no layout that keeps asking for the next" % view)
		_hud.cover_changed.disconnect(counted)


# ----- A: the open action log -----------------------------------------------------------------------------------------


func test_an_open_log_leaves_the_card_and_itself_usable_and_the_setting_alone() -> void:
	for view: Vector2i in ROOMY + [SMALLEST] as Array[Vector2i]:
		_hud.action_log().close()
		await _show(view, MapModes.Mode.TERRAIN)
		_settings.set_value(LOG_OPEN, true)  # saved open: the HUD reads it when the settings come
		_hud.action_log().bind_settings(_settings)
		await _harness.wait_frames(self, 2)
		_settings.writes.clear()
		_hud.show_mode_parts(MapModes.Mode.GOODS)
		await _harness.wait_frames(self, 6)
		var tag := str(view)
		var card := _hud.goods_card()
		var log_card := _log_card()
		assert_true(log_card.is_visible_in_tree(), "%s: the log stays open" % tag)
		assert_false(_rect(log_card).intersects(_rect(card)), "%s: apart %s %s" % [tag, _rect(log_card), _rect(card)])
		var covered: Array[String] = []
		for button: KitButton in card.buttons():
			if _rect(card.body_scroll()).grow(0.5).encloses(_rect(button)):
				covered.append_array(_unreachable(button))
		assert_eq(covered, [] as Array[String], "%s: every button in view takes the pointer" % tag)
		var close := _hud.action_log().get_node("Card/VBox/Head/Close") as Control
		assert_eq(_unreachable(close), [] as Array[String], "%s: the log's Close takes the pointer" % tag)
		assert_eq(_unreachable(_hud.return_button()), [] as Array[String], "%s: and Return" % tag)
		var wine := card.button_for(&"wine")
		card.pick(&"grain")
		if _rect(card.body_scroll()).encloses(_rect(wine)):
			_harness.send_click(_rect(wine).get_center())
			await _harness.wait_frames(self, 1)
			assert_eq(card.good_key(), &"wine", "%s: a click picks" % tag)
		assert_true(bool(_settings.get_value(LOG_OPEN)), "%s: saved open still" % tag)
		assert_false(_settings.writes.has(LOG_OPEN), "%s: and never written" % tag)


func test_a_log_opened_in_goods_mode_moves_clear_and_goes_home_after() -> void:
	await _show(Vector2i(1280, 720), MapModes.Mode.GOODS)
	var log_widget := _hud.action_log()
	var card := _hud.goods_card()
	var card_at := _rect(card)
	log_widget.open()
	await _harness.wait_frames(self, 1)
	assert_eq(_rect(card), card_at, "the goods card stays")
	assert_false(_rect(_log_card()).intersects(card_at), "the log opens beside it")
	assert_almost_eq(_rect(_log_card()).end.y, _rect(log_widget).position.y - ActionLog.CARD_GAP, 0.5, "as low as ever")
	log_widget.close()
	log_widget.open()
	await _harness.wait_frames(self, 1)
	assert_false(_rect(_log_card()).intersects(card_at), "opened again: beside it")
	_hud.show_mode_parts(MapModes.Mode.TERRAIN)
	await _harness.wait_frames(self, 2)
	assert_almost_eq(_rect(_log_card()).position.x, _rect(log_widget).position.x, 0.5, "home above its button")
	assert_eq(_log_card().size, Vector2(ActionLog.CARD_W, ActionLog.CARD_H))


# ----- B: the Return button -------------------------------------------------------------------------------------------


func test_return_is_fully_clickable_where_the_foot_has_no_room() -> void:
	var raised := 0
	for view: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 576), Vector2i(960, 540), Vector2i(853, 480)]:
		for docked: bool in [false, true]:
			await _show(view, MapModes.Mode.OWNER, docked)
			var tag := "%s dock %s" % [view, docked]
			var button := _hud.return_button()
			assert_eq(_clashes("return", _rect(button), [_hud.minimap(), _hud.zoom_control(), _hud.scale_bar(),
					_hud.action_log(), _hud.key_hints()] as Array[Control]), [] as Array[String], tag)
			assert_eq(_unreachable(button), [] as Array[String], tag)
			assert_lte(_rect(_hud.toast_host()).end.y, _rect(button).position.y, "%s: the toasts keep above" % tag)
			if _rect(button).end.y <= _rect(_hud.minimap()).position.y:
				raised += 1
				assert_true(docked, "%s: raised only where the dock takes the room" % tag)
	assert_gte(raised, 2, "P: 960 and 853 with the dock put it above the minimap")
	var asked: Array[int] = []
	_hud.mode_requested.connect(func(mode: int) -> void: asked.append(mode))
	_harness.send_click(_rect(_hud.return_button()).get_center())
	await _harness.wait_frames(self, 1)
	assert_eq(asked, [int(MapModes.Mode.TERRAIN)] as Array[int], "and it can be clicked there")
