## GUT tests for the Studiolo Hud frame: click-blocking, dock shift, TopBar, LayersPopover,
## ZoomControl, KeyHints, MapHover, DebugOverlay F3, and ToastHost
## (docs/architecture/ui-and-controls-spec.md sections 3.1, 3.3, 7, 9; ui-style-and-feedback-plan.md U14).
extends GutTest

const HUD_SCENE := preload("res://shell/hud/hud.tscn")


class MapClickCatcher:
	extends Node

	var clicks: Array[Vector2] = []

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				clicks.append(mb.position)


var _harness: UIHarness = null
var _hud: Hud = null
var _catcher: MapClickCatcher = null
var _prev_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	_harness = UIHarness.new()
	_harness.mount(self)

	_catcher = MapClickCatcher.new()
	_harness.viewport.add_child(_catcher)

	_hud = HUD_SCENE.instantiate() as Hud
	_harness.viewport.add_child(_hud)
	_hud.root().theme = KitTheme.load_for(1.0)
	_hud.setup(_harness.ctx)


func after_each() -> void:
	_hud = null
	_catcher = null
	_harness = null
	Session.game = _prev_game
	Bindings.reset_defaults()


func _find_land_hex() -> Vector2i:
	var game := Session.game
	for i: int in game.map.hex_count():
		if game.map.land[i] == 1:
			return game.map.hex_of(i)
	return Vector2i.ZERO


func test_clicks_on_hud_panels_never_reach_map_while_open_canvas_does() -> void:
	await _harness.wait_frames(self, 2)

	# Click open canvas in MapArea -> reaches map catcher
	_harness.send_click(Vector2(640.0, 360.0))
	await _harness.wait_frames(self, 1)
	assert_eq(_catcher.clicks.size(), 1, "open canvas click propagates to map")

	# Click TopBar -> blocked
	_catcher.clicks.clear()
	_harness.send_click(_hud.top_bar().get_global_rect().get_center())
	await _harness.wait_frames(self, 1)
	assert_eq(_catcher.clicks.size(), 0, "TopBar blocks map clicks")

	# Click ZoomControl -> blocked
	_harness.send_click(_hud.zoom_control().get_global_rect().get_center())
	await _harness.wait_frames(self, 1)
	assert_eq(_catcher.clicks.size(), 0, "ZoomControl blocks map clicks")

	# Open LayersPopover and click inside -> blocked
	_hud.set_layers_open(true)
	await _harness.wait_frames(self, 2)
	assert_true(_hud.layers_popover().visible)
	_harness.send_click(_hud.layers_popover().get_global_rect().get_center())
	await _harness.wait_frames(self, 1)
	assert_eq(_catcher.clicks.size(), 0, "LayersPopover blocks map clicks")
	_hud.set_layers_open(false)

	# Open DebugOverlay and click inside -> blocked
	_hud.set_debug_open(true)
	await _harness.wait_frames(self, 2)
	assert_true(_hud.debug_overlay().visible)
	_harness.send_click(_hud.debug_overlay().get_global_rect().get_center())
	await _harness.wait_frames(self, 1)
	assert_eq(_catcher.clicks.size(), 0, "DebugOverlay blocks map clicks")
	_hud.set_debug_open(false)

	# Open HexPanel and click inside -> blocked; click below HexPanel in Dock area -> reaches map
	_hud.hex_panel().show_hex(_find_land_hex())
	await _harness.wait_frames(self, 2)
	assert_true(_hud.hex_panel().visible)
	_harness.send_click(_hud.hex_panel().get_global_rect().get_center())
	await _harness.wait_frames(self, 1)
	assert_eq(_catcher.clicks.size(), 0, "HexPanel blocks map clicks")

	var below_panel := Vector2(_hud.hex_panel().get_global_rect().get_center().x, 700.0)
	_harness.send_click(below_panel)
	await _harness.wait_frames(self, 1)
	assert_eq(_catcher.clicks.size(), 1, "transparent Dock space below HexPanel lets clicks reach map")

	# Photo mode (view_hud hidden): clicking where TopBar was reaches map
	_catcher.clicks.clear()
	_hud.set_hud_visible(false)
	await _harness.wait_frames(self, 1)
	_harness.send_click(Vector2(200.0, 20.0))
	await _harness.wait_frames(self, 1)
	assert_eq(_catcher.clicks.size(), 1, "hidden HUD lets clicks reach map")


func test_zoom_cluster_shifts_left_when_hex_panel_opens_and_returns_on_clear() -> void:
	await _harness.wait_frames(self, 2)
	assert_false(_hud.dock().visible)
	var zoom_rect_closed := _hud.zoom_control().get_global_rect()
	var scale_rect_closed := _hud.scale_bar().get_global_rect()

	_hud.hex_panel().show_hex(_find_land_hex())
	await _harness.wait_frames(self, 2)
	assert_true(_hud.dock().visible)
	var panel_rect := _hud.hex_panel().get_global_rect()
	var zoom_rect_open := _hud.zoom_control().get_global_rect()
	var scale_rect_open := _hud.scale_bar().get_global_rect()

	assert_lt(zoom_rect_open.position.x, zoom_rect_closed.position.x - 200.0, "ZoomControl shifts left when HexPanel opens")
	assert_lt(scale_rect_open.position.x, scale_rect_closed.position.x - 200.0, "ScaleBar shifts left when HexPanel opens")
	assert_lte(zoom_rect_open.end.x, panel_rect.position.x, "ZoomControl never overlaps HexPanel")

	_hud.hex_panel().clear()
	await _harness.wait_frames(self, 2)
	assert_false(_hud.dock().visible)
	var zoom_rect_restored := _hud.zoom_control().get_global_rect()
	assert_almost_eq(zoom_rect_restored.position.x, zoom_rect_closed.position.x, 1.0, "ZoomControl returns when HexPanel closes")


func test_top_bar_and_layers_popover() -> void:
	await _harness.wait_frames(self, 2)

	var seasons: Array[int] = []
	var layers: Array[Array] = []
	var helps := [0]
	var menus := [0]

	_hud.season_preview_requested.connect(func(i: int) -> void: seasons.append(i))
	_hud.layer_toggled.connect(func(n: StringName, on: bool) -> void: layers.append([n, on]))
	_hud.help_requested.connect(func() -> void: helps[0] += 1)
	_hud.menu_requested.connect(func() -> void: menus[0] += 1)

	_hud.set_map_info("North Italy", 1492)
	assert_eq(_hud.top_bar().brand_label().text, "HEXA")
	assert_true(_hud.top_bar().map_info_label().text.contains("1492"))
	assert_eq(_hud.top_bar().layers_button().focus_mode, Control.FOCUS_NONE)
	assert_eq(_hud.top_bar().help_button().focus_mode, Control.FOCUS_NONE)
	assert_eq(_hud.top_bar().menu_button().focus_mode, Control.FOCUS_NONE)

	_hud.top_bar().season_segmented().select(2, true)
	assert_eq(seasons, [2])
	assert_eq(_hud.layers_popover().season_segmented().selected_id(), 2, "LayersPopover season stays synced")

	_hud.top_bar().help_button().pressed.emit()
	_hud.top_bar().menu_button().pressed.emit()
	assert_eq(helps[0], 1)
	assert_eq(menus[0], 1)

	_hud.top_bar().layers_button().button_pressed = true
	await _harness.wait_frames(self, 1)
	assert_true(_hud.is_layers_open())

	_hud.layers_popover().grid_switch().button_pressed = true
	assert_true(bool(_harness.settings.get_value("map/grid")))
	assert_true(layers.has([&"map/grid", true]))

	_hud.layers_popover().names_switch().button_pressed = true
	assert_true(bool(_harness.settings.get_value("map/place_names")))
	assert_true(layers.has([&"map/place_names", true]))

	_hud.layers_popover().relief_switch().button_pressed = false
	assert_false(bool(_harness.settings.get_value("graphics/relief_shading")))
	assert_true(layers.has([&"graphics/relief_shading", false]))

	_harness.send_key(KEY_ESCAPE)
	await _harness.wait_frames(self, 1)
	assert_false(_hud.is_layers_open(), "Esc closes LayersPopover")
	assert_false(_hud.top_bar().layers_button().button_pressed, "TopBar Layers button untoggles on close")

	_hud.set_layers_open(true)
	await _harness.wait_frames(self, 1)
	_harness.send_click(Vector2(200.0, 300.0))
	await _harness.wait_frames(self, 1)
	assert_false(_hud.is_layers_open(), "outside click closes LayersPopover")


func test_zoom_control_key_hints_and_toasts() -> void:
	await _harness.wait_frames(self, 2)

	var zoom_steps: Array[float] = []
	var zoom_sets: Array[float] = []
	var fits := [0]

	_hud.zoom_step_requested.connect(func(n: float) -> void: zoom_steps.append(n))
	_hud.zoom_set_requested.connect(func(z: float) -> void: zoom_sets.append(z))
	_hud.fit_requested.connect(func() -> void: fits[0] += 1)

	_hud.set_zoom(1.5, 0.4, 2.0)
	assert_eq(_hud.zoom_control().readout_button().text, "150%")
	assert_eq(_hud.scale_bar().current_km(), 20)
	_hud.set_zoom(2.0, 0.4, 2.0)
	assert_eq(_hud.scale_bar().current_km(), 10)
	_hud.zoom_control().zoom_in_button().pressed.emit()
	_hud.zoom_control().zoom_out_button().pressed.emit()
	_hud.zoom_control().readout_button().pressed.emit()
	_hud.zoom_control().fit_button().pressed.emit()
	assert_eq(zoom_steps, [CameraRig.KEY_ZOOM_NOTCHES, -CameraRig.KEY_ZOOM_NOTCHES])
	assert_eq(zoom_sets, [1.0])
	assert_eq(fits[0], 1)

	var idle_actions := _hud.key_hints().hint_actions()
	assert_true(idle_actions.has(&"view_grid"))
	assert_true(bool(Bindings.apply_overrides({"view_grid": "K"})["ok"]))
	_hud.refresh_bindings()
	var grid_cap_text := ""
	for child: Node in _hud.key_hints().get_children():
		for sub: Node in child.get_children():
			if sub is KeyCap and (sub as KeyCap).action == &"view_grid":
				grid_cap_text = (sub as KeyCap).label().text
	assert_eq(grid_cap_text, "K", "KeyHints updates when Bindings rebind")

	_hud.hex_panel().show_hex(_find_land_hex())
	await _harness.wait_frames(self, 1)
	assert_true(_hud.key_hints().hint_actions().has(&"game_upgrade"), "KeyHints switches to selection context")

	_hud.key_hints().set_hints_enabled(false)
	assert_false(_hud.key_hints().visible)

	_harness.ctx.toast("Saved map", &"good")
	assert_eq(_hud.toast_host().active_count(), 1)
	assert_eq(_hud.toast_host().messages(), ["Saved map"])


func test_map_hover_delay_clamping_and_hiding() -> void:
	await _harness.wait_frames(self, 2)
	var hover := _hud.map_hover()
	hover.hover_delay_sec = 0.2
	var hex := _find_land_hex()

	# Place pointer near bottom-right corner to verify clamping inside MapArea
	_hud.on_hover_changed(hex, Vector2(1260.0, 660.0))
	assert_false(hover.is_card_visible(), "waits for tooltip delay")
	hover._process(0.25)
	assert_true(hover.is_card_visible(), "shows HoverCard after delay")
	var card_rect := hover.card().get_rect()
	var area_size := _hud.map_area().size
	assert_lte(card_rect.end.x, area_size.x, "clamped inside right edge")
	assert_lte(card_rect.end.y, area_size.y, "clamped inside bottom edge")

	hover.set_dragging(true)
	assert_false(hover.is_card_visible(), "hides while dragging")
	hover.set_dragging(false)

	_hud.on_hover_changed(MapInput.NO_HEX)
	assert_false(hover.is_card_visible(), "hides on NO_HEX")
