## The HUD over the parchment map, the faults its review found (docs/architecture/map-overview-build-spec.md R20, R23,
## R25): the goods card gives the keyboard back to the map, the hover card stands at the pointer, the chosen good is
## clearly marked, and a small window (1280 x 720 at UI scale 150 %) keeps the card bottom left, the toasts off it and
## the mode switch off the date. Each case fails without its fix.
extends GutTest

const MAP_SCENE := preload("res://shell/map/map_scene.tscn")
const HUD_SCENE := preload("res://shell/hud/hud.tscn")
const APP_SCENE := preload("res://shell/app/app.tscn")
const GEN := &"GEN"
const SCREEN := Vector2i(1920, 1080)
const START_TOAST := "You rule the Republic of Genoa from Genoa."
## [logical window, display/ui_scale]: 1280 x 720 at 100 % and at 150 %, and between.
const SIZES: Array[Array] = [[Vector2i(853, 480), "150"], [Vector2i(960, 540), "100"], [Vector2i(1280, 720), "100"]]

var _harness: UIHarness = null
var _hud: Hud = null
var _scene: MapScene = null
var _prev_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	assert_eq(Session.new_scenario("north_italy_1480", 1480, GEN), "")


func after_each() -> void:
	_hud = null
	_scene = null
	_harness = null
	Session.game = _prev_game
	Bindings.reset_defaults()


## A map scene and a Hud bound to it in the 1920 x 1080 view.
func _open() -> void:
	_harness = UIHarness.new(SCREEN)
	_harness.mount(self)
	_scene = MAP_SCENE.instantiate() as MapScene
	_scene.preload_next_season = false
	_scene.configure(_harness.settings)
	_harness.viewport.add_child(_scene)
	_scene.finish_loading()
	_hud = HUD_SCENE.instantiate() as Hud
	_harness.viewport.add_child(_hud)
	_hud.root().theme = KitTheme.load_for(1.0)
	_hud.configure(_harness.settings)
	_hud.bind_map_scene(_scene)
	await _harness.wait_frames(self, 3)


func _press(keycode: Key) -> void:
	_harness.send_key(keycode)
	_harness.send_key(keycode, false)


# ----- the keyboard ---------------------------------------------------------------------------------------------------


func test_a_press_on_the_map_takes_the_keyboard_back_from_the_goods_card() -> void:
	await _open()
	_press(KEY_7)
	await _harness.wait_frames(self, 3)
	var ends: Array[bool] = []
	_scene.map_input().end_season_requested.connect(func(echo: bool) -> void: ends.append(echo))
	for button: MouseButton in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		_press(KEY_7)
		assert_not_null(_harness.viewport.gui_get_focus_owner(), "7 again: the keyboard is in the card")
		_harness.send_click(Vector2(900.0, 400.0), MOUSE_BUTTON_WHEEL_UP)
		assert_not_null(_harness.viewport.gui_get_focus_owner(), "the wheel only zooms")
		_harness.send_click(Vector2(900.0, 400.0), button)
		assert_null(_harness.viewport.gui_get_focus_owner(), "button %d on the map" % button)
	_press(KEY_SPACE)
	assert_eq(ends, [false] as Array[bool], "Space ends the turn again")
	var good := _hud.goods_card().good_key()
	_press(KEY_RIGHT)
	assert_eq(_hud.goods_card().good_key(), good)
	assert_null(_harness.viewport.gui_get_focus_owner(), "the arrows do not walk the card")


# ----- the hover card -------------------------------------------------------------------------------------------------


func test_the_hover_card_stands_at_the_pointer() -> void:
	await _open()
	_hud.map_hover().hover_delay_sec = 0.0
	var offset := MapHover.CURSOR_OFFSET
	for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.RELIEF]:  # the one line and the hex card
		_scene.set_mode(mode)
		_hud.on_hover_changed(MapInput.NO_HEX)
		var at := Vector2(700.0, 300.0)
		_hud.on_hover_changed(Countries.by_tag(Session.game, GEN).capital, at)
		await _harness.wait_frames(self, 3)
		var card := _hud.map_hover().card()
		assert_true(card.visible, "mode %d" % mode)
		var drawn := Hud.screen_rect(card).position
		assert_almost_eq(drawn.x, at.x + offset.x, 0.6, "mode %d: beside the pointer" % mode)
		assert_almost_eq(drawn.y, at.y + offset.y, 0.6, "mode %d: not a top bar too low" % mode)


# ----- the chosen good ------------------------------------------------------------------------------------------------


## The buttons whose held-down look does not set them apart: the chosen one must wear the kit's filled gold plate.
func _unmarked(card: GoodsCard, chosen: StringName) -> Array[String]:
	var out: Array[String] = []
	var theme := _hud.root().theme
	var gold := (theme.get_stylebox(&"normal", &"ButtonPrimary") as StyleBoxTexture).texture
	for button: KitButton in card.buttons():
		var held := button.get_theme_stylebox(&"pressed" if button.button_pressed else &"normal") as StyleBoxTexture
		var filled := held != null and held.texture == gold
		if filled != (button == card.button_for(chosen)):
			out.append("%s filled %s" % [button.name, filled])
	return out


func test_the_chosen_good_is_filled_with_the_kits_gold_plate() -> void:
	await _open()
	_scene.set_mode(MapModes.Mode.GOODS)
	await _harness.wait_frames(self, 2)
	var card := _hud.goods_card()
	assert_eq(_unmarked(card, &"grain"), [] as Array[String])
	card.pick(&"wine")
	assert_eq(_unmarked(card, &"wine"), [] as Array[String], "the mark moves with the choice")
	card.button_for(&"wine").theme_type_variation = &"ButtonToggle"
	assert_eq(_unmarked(card, &"wine").size(), 1, "P: a choice in the other buttons' plate is reported")
	for contrast: bool in [true]:
		_hud.root().theme = KitTheme.load_for(1.0, &"auto", contrast)
		card.pick(&"grain")
		await _harness.wait_frames(self, 2)
		var chosen := card.button_for(&"grain").get_theme_stylebox(&"pressed") as StyleBoxFlat
		var other := card.button_for(&"wine").get_theme_stylebox(&"normal") as StyleBoxFlat
		assert_ne(chosen.bg_color, other.bg_color, "high contrast: filled")
		assert_gt(chosen.border_width_left, other.border_width_left, "and a thicker border")


# ----- small windows ---------------------------------------------------------------------------------------------------


## Everything wrong with the top bar, the goods card and the toasts of an app now.
func _small_problems(app: App) -> Array[String]:
	var out: Array[String] = []
	var hud := app.hud()
	var card := Hud.screen_rect(hud.goods_card())
	var area := Hud.screen_rect(hud.map_area())
	if absf(card.position.x - area.position.x - HudLayout.LEFT) > 0.5 \
			or absf(area.end.y - card.end.y - HudLayout.CARD_FOOT) > 0.5:
		out.append("the goods card is not bottom left: %s in %s" % [card, area])
	for banner: Control in hud.toast_host().get_children():
		var rect := Hud.screen_rect(banner)
		for other: Control in [hud.goods_card(), hud.return_button(), hud.minimap(), hud.zoom_control()]:
			if rect.intersects(Hud.screen_rect(other)):
				out.append("a toast %s covers %s" % [rect, other.name])
		if not Rect2(Vector2.ZERO, Vector2(hud.map_area().get_viewport_rect().size)).encloses(rect):
			out.append("a toast leaves the window: %s" % rect)
	var bar := hud.top_bar()
	var shown: Array[Control] = [bar.date_end().date_button(), bar.date_end().end_button(), bar.layers_button()]
	var switch := Hud.screen_rect(bar.mode_segmented())
	for button: Control in bar.mode_segmented().get_node("Buttons").get_children():
		var rect := Hud.screen_rect(button)
		if not switch.grow(0.5).encloses(rect):
			out.append("%s leaves the mode switch: %s" % [(button as Button).text, rect])
		for other: Control in shown:
			if rect.intersects(Hud.screen_rect(other)):
				out.append("%s under %s" % [(button as Button).text, (other as Button).text])
	return out


func test_a_small_window_keeps_the_card_bottom_left_the_toasts_off_it_and_the_date_clear() -> void:
	var old_dir := Session.save_dir
	var old_lock := RunLock.path
	var ai := Session.ai_enabled
	Session.ai_enabled = false
	Session.save_dir = "user://test_parchment_small_saves"
	RunLock.path = "user://test_parchment_small_running.lock"
	for size: Array in SIZES:
		_harness = UIHarness.new(size[0])
		_harness.mount(self)
		var app := APP_SCENE.instantiate() as App
		app.settings_path = ""
		app.allow_tree_quit = false
		app.pause_tree_when_modal = false
		app.cli_args_override = PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"])
		var s := Settings.new("macOS", true)
		for pair: Array in [["state/help_seen", true], ["graphics/preload_next_season", false], ["game/autosave", "off"],
				["accessibility/reduce_motion", true], ["display/ui_scale", size[1]]]:
			s.set_value(pair[0], pair[1])
		app.set_settings_override(s)
		_harness.viewport.add_child(app)
		for _i: int in 600:
			if app.map_scene() != null and app.stack().count() == 0 and not app.is_starting():
				break
			await get_tree().process_frame
		await _harness.wait_frames(self, 2)
		app.hud().toast_host().clear()
		app.map_scene().set_mode(MapModes.Mode.GOODS)
		await _harness.wait_frames(self, 6)
		app.hud().toast(START_TOAST, &"good")
		await _harness.wait_frames(self, 6)
		assert_eq(app.hud().toast_host().active_count(), 1)
		assert_eq(_small_problems(app), [] as Array[String], "%s at %s %%" % size)
		app.hud().toast("Work begun: a vineyard, ready in two seasons.", &"good")
		app.hud().toast("Bookmark 3 set.", &"plain")
		await _harness.wait_frames(self, 6)
		assert_eq(_small_problems(app), [] as Array[String], "%s at %s %%: three toasts" % size)
		app.free()
		Session.end_game()
		_harness.viewport.queue_free()
	RunLock.clear()
	Session.save_dir = old_dir
	RunLock.path = old_lock
	Session.ai_enabled = ai
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)
