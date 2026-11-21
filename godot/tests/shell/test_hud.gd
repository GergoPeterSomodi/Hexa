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

	# The season preview lives only in F3's Look control; the Layers popover has none (M3).
	assert_null(_hud.layers_popover().get_node_or_null("VBox/SeasonSeg"))
	_hud.debug_overlay().season_segmented().select(2, true)
	_hud.debug_overlay().season_segmented().select(-1, true)
	assert_eq(seasons, [2, -1], "F3's Look sends 0 to 3 and -1 for the calendar")

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


func _find_hex_owned_by(tag: StringName) -> Vector2i:
	var game := Session.game
	for i: int in game.map.hex_count():
		if game.map.land[i] == 1 and Territory.owner_tag(game, game.map.hex_of(i)) == tag:
			return game.map.hex_of(i)
	return Vector2i(-1, -1)


func test_dock_shows_one_panel_at_a_time_and_closes() -> void:
	await _harness.wait_frames(self, 2)
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "", "the scenario starts")
	var asked: Array[StringName] = []
	_hud.country_requested.connect(func(tag: StringName) -> void: asked.append(tag))

	_hud.show_country(&"GEN", false)
	await _harness.wait_frames(self, 2)
	assert_true(_hud.country_panel().visible, "the country panel shows")
	assert_eq(_hud.country_panel().shown_tag(), &"GEN")
	assert_false(_hud.hex_panel().visible, "the hex panel is closed")
	assert_true(_hud.dock().visible, "the dock opens")

	_hud.hex_panel().show_hex(_find_land_hex())
	await _harness.wait_frames(self, 1)
	assert_false(_hud.country_panel().visible, "a hex replaces the country panel")
	assert_true(_hud.hex_panel().visible)

	_hud.show_country(&"SAV", false)
	assert_false(_hud.hex_panel().visible, "a country replaces the hex panel")
	assert_true(_hud.country_panel().visible)

	_hud.country_panel().country_requested.emit(&"MLO")
	assert_eq(asked, [&"MLO"], "a neighbour link reaches the Hud")

	_hud.close_dock()
	await _harness.wait_frames(self, 2)
	assert_false(_hud.dock().visible, "close_dock closes the dock")
	assert_false(_hud.country_panel().visible)
	assert_false(_hud.hex_panel().visible)


func test_top_bar_names_the_country_and_switches_modes() -> void:
	await _harness.wait_frames(self, 2)
	var top := _hud.top_bar()
	assert_false(top.country_button().visible, "a map-only game has no country name")
	assert_true(top.map_info_label().visible, "a map-only game keeps its map info")
	assert_null(top.mode_segmented().button_for(1), "no Owner mode in a map-only game")

	assert_eq(Session.new_scenario("north_italy_1480", 1480), "")
	top.refresh_game()
	assert_false(top.map_info_label().visible)
	assert_not_null(top.mode_segmented().button_for(1), "Owner is offered with countries")
	assert_true(top.country_button().visible, "the pick's title shows")
	assert_true(top.country_button().text.contains("choose your country"))
	assert_false(top.arms().visible, "no arms before a country is chosen")

	var chosen: Array[int] = []
	_hud.mode_requested.connect(func(mode: int) -> void: chosen.append(mode))
	top.mode_segmented().select(2, true)
	assert_eq(chosen, [2], "the mode switch reaches the Hud")

	assert_true(bool(Session.act("choose_country", {"tag": "GEN"})["ok"]))
	await _harness.wait_frames(self, 1)
	var card := CountryCard.of(Session.game, &"GEN")
	assert_eq(top.country_button().text, str(card["long_name"]), "the long name after the choice")
	assert_true(top.arms().visible, "the arms show for the player's country")


func test_narrow_top_bar_hides_the_name_before_the_switch() -> void:
	await _harness.wait_frames(self, 2)
	Session.new_scenario("north_italy_1480", 1480, &"GEN")
	var top := _hud.top_bar()
	top.refresh_game()
	await _harness.wait_frames(self, 1)
	top.fit_width(4000.0)
	assert_true(top.name_shown(), "the name shows when there is room")
	top.fit_width(300.0)
	assert_false(top.name_shown(), "the name hides first when narrow")
	assert_true(top.arms().visible, "the arms stay")
	assert_true(top.mode_segmented().visible, "the mode switch stays")
	assert_true(top.menu_button().visible, "the menu stays")
	top.fit_width(4000.0)
	assert_true(top.name_shown(), "the name returns when there is room")


func test_layers_popover_has_the_three_m2_switches_and_fits() -> void:
	await _harness.wait_frames(self, 2)
	var pop := _hud.layers_popover()
	pop.set_open(true)
	await _harness.wait_frames(self, 2)
	pop.borders_switch().button_pressed = false
	assert_false(bool(_harness.settings.get_value("map/borders")), "Borders writes its setting")
	pop.tint_switch().button_pressed = false
	assert_false(bool(_harness.settings.get_value("map/owner_tint")), "Country tint writes its setting")
	pop.minimap_switch().button_pressed = false
	assert_false(bool(_harness.settings.get_value("map/minimap")), "Minimap writes its setting")
	_harness.settings.set_value("map/borders", true)
	assert_true(pop.borders_switch().button_pressed, "the switch follows Settings")
	assert_true(pop.get_combined_minimum_size().y <= pop.size.y, "the popover is tall enough for its rows")
	pop.set_open(false)


func test_minimap_sits_above_the_zoom_control_and_forwards_its_signals() -> void:
	await _harness.wait_frames(self, 2)
	var mini := _hud.minimap()
	var zoom := _hud.zoom_control()
	assert_eq(mini.get_parent(), zoom.get_parent(), "the minimap shares the zoom column")
	assert_lt(mini.get_index(), zoom.get_index(), "the minimap sits above the zoom control")
	assert_false(mini.is_bound(), "no game scene: the minimap is unbound and hidden")
	assert_false(mini.visible)

	var looks: Array[Vector2] = []
	var jumps: Array[Vector2] = []
	_hud.look_at_requested.connect(func(p: Vector2) -> void: looks.append(p))
	_hud.jump_requested.connect(func(p: Vector2) -> void: jumps.append(p))
	mini.look_at_requested.emit(Vector2(10.0, 20.0))
	mini.jump_requested.emit(Vector2(30.0, 40.0))
	assert_eq(looks, [Vector2(10.0, 20.0)])
	assert_eq(jumps, [Vector2(30.0, 40.0)])


func test_f3_m2_line_counts_countries_and_mode() -> void:
	await _harness.wait_frames(self, 1)
	_hud.debug_overlay().refresh_metrics()
	assert_true(_hud.debug_overlay().metrics_text().contains("countries 0 · mode Terrain"), "a map-only game has no countries")
	Session.new_scenario("north_italy_1480", 1480)
	_hud.debug_overlay().refresh_metrics()
	assert_true(_hud.debug_overlay().metrics_text().contains("countries 13 · mode Terrain · border chunks 0"))


func test_m3_slots_the_date_and_end_season_the_log_and_the_top_right_column() -> void:
	await _harness.wait_frames(self, 2)
	assert_not_null(_hud.date_end(), "DateEnd sits in the top bar")
	assert_true(_hud.top_bar().is_ancestor_of(_hud.date_end()))
	assert_true(_hud.map_area().is_ancestor_of(_hud.action_log()), "the action log is in MapArea")
	var top_right := _hud.map_area().get_node("TopRight")
	assert_eq(_hud.task_flag().get_parent(), top_right, "TaskFlag is in the TopRight column")
	assert_eq(_hud.notifications().get_parent(), top_right, "Notifications is in the TopRight column")
	assert_null(_hud.layers_popover().get_node_or_null("VBox/SeasonSeg"), "no season buttons in Layers")
	assert_null(_hud.top_bar().get_node_or_null("HBox/SeasonSeg"), "no season preview in the top bar")


func test_m3_hud_signals_for_end_report_and_looking() -> void:
	await _harness.wait_frames(self, 2)
	var seen := {"end": 0, "report": 0, "hex": []}
	_hud.end_season_requested.connect(func() -> void: seen["end"] += 1)
	_hud.report_requested.connect(func() -> void: seen["report"] += 1)
	_hud.hex_look_requested.connect(func(hex: Vector2i) -> void: (seen["hex"] as Array).append(hex))
	_hud.date_end().end_season_requested.emit()
	_hud.date_end().report_requested.emit()
	_hud.action_log().report_requested.emit()
	_hud.task_flag().go_requested.emit(Vector2i(3, 4))
	_hud.notifications().go_requested.emit(Vector2i(5, 6))
	_hud.action_log().line_activated.emit(Vector2i(7, 8))
	assert_eq(seen["end"], 1)
	assert_eq(seen["report"], 2)
	assert_eq(seen["hex"], [Vector2i(3, 4), Vector2i(5, 6), Vector2i(7, 8)])


func test_m3_covering_and_the_look_control_returns_to_the_calendar() -> void:
	await _harness.wait_frames(self, 2)
	_hud.set_covered(true, true)
	assert_true(_hud.notifications().is_covered())
	assert_true(_hud.task_flag().is_covered())
	_hud.set_covered(false, false)
	assert_false(_hud.notifications().is_covered())
	_hud.debug_overlay().season_segmented().select(2, false)
	Events.season_ended.emit(1)
	assert_eq(_hud.debug_overlay().season_segmented().selected_id(), -1, "Look is back on Calendar when a season ends")
	assert_false(_hud.has_open_list(), "no log or flag list is open")
	_hud.action_log().open()
	assert_true(_hud.has_open_list())
	assert_true(_hud.close_lists(), "Esc closes the open log")
	assert_false(_hud.action_log().is_open())



func test_the_top_bar_fits_700_px_in_a_sandbox_the_pick_and_a_game() -> void:
	await _harness.wait_frames(self, 2)
	var bar := _hud.top_bar()
	bar.fit_width(700.0)
	assert_lte(bar.get_combined_minimum_size().x, 700.0, "a sandbox bar fits 700 px")
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "")
	bar.refresh_game()
	_hud.date_end().refresh()
	await _harness.wait_frames(self, 2)
	bar.fit_width(700.0)
	assert_lte(bar.get_combined_minimum_size().x, 700.0, "the pick bar (with its refusal line) fits 700 px")
	assert_false(bar.name_shown(), "the name hides first")
	assert_true(bar.date_end().end_button().visible, "End turn never hides")
	assert_true(bar.date_end().date_button().visible)
	Session.act("choose_country", {"tag": &"GEN"})
	await _harness.wait_frames(self, 2)
	bar.fit_width(700.0)
	assert_lte(bar.get_combined_minimum_size().x, 700.0, "a game bar fits 700 px")
	bar.fit_width(1600.0)
	assert_true(bar.name_shown(), "the name comes back when there is room")
	assert_true(bar.brand_label().visible)


# ----- M4: the chips and the study button in the top bar (docs/architecture/m4-build-spec.md 6.3, 6.12) -----------------------


func _genoa_bar() -> TopBar:
	assert_eq(Session.new_scenario("north_italy_1480", 1480, &"GEN"), "")
	var bar := _hud.top_bar()
	bar.refresh_game()
	return bar


func test_the_chips_sit_after_the_mode_switch_and_before_the_date() -> void:
	await _harness.wait_frames(self, 2)
	var bar := _genoa_bar()
	await _harness.wait_frames(self, 3)
	var box := bar.get_node("HBox") as HBoxContainer
	var chips_at := bar.chips().get_index()
	assert_eq(chips_at, bar.mode_segmented().get_index() + 1, "right after the mode switch")
	assert_lt(chips_at, bar.date_end().get_index(), "before the date and End turn")
	assert_eq(box.get_child(bar.study_button().get_index()), bar.study_button())
	assert_true(bar.chips().visible, "a player: chips")
	assert_true(bar.study_button().visible)
	assert_eq(bar.chips().ducats_chip().value_label().text, "610")
	assert_eq(bar.study_button().tooltip_text, "The Statesman's Study [I]")
	assert_eq(_hud.chips(), bar.chips())


func test_no_chips_and_no_study_button_in_the_sandbox_and_the_pick() -> void:
	await _harness.wait_frames(self, 2)
	var bar := _hud.top_bar()
	assert_false(bar.chips().visible, "the sandbox has no treasury")
	assert_false(bar.study_button().visible)
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "")
	bar.refresh_game()
	await _harness.wait_frames(self, 2)
	assert_false(bar.chips().visible, "the pick: no player yet")
	assert_false(bar.study_button().visible)
	Session.act("choose_country", {"tag": &"GEN"})
	await _harness.wait_frames(self, 2)
	assert_true(bar.chips().visible, "chosen: the chips come")
	assert_true(bar.study_button().visible)
	Session.end_game()
	bar.refresh_game()
	await _harness.wait_frames(self, 2)
	assert_false(bar.chips().visible, "no game: no chips")


func test_a_chip_and_the_study_button_reach_the_hud_as_study_requests() -> void:
	await _harness.wait_frames(self, 2)
	var bar := _genoa_bar()
	await _harness.wait_frames(self, 3)
	var asked: Array[StringName] = []
	var tabs: Array[String] = []
	_hud.study_requested.connect(func(page: StringName) -> void: asked.append(page))
	_hud.study_tab_requested.connect(func(page: StringName, tab: StringName) -> void: tabs.append("%s/%s" % [page, tab]))
	bar.chips().ducats_chip().pressed.emit()
	bar.chips().stores_chip().pressed.emit()
	bar.study_button().pressed.emit()
	_hud.country_panel().study_requested.emit()
	_hud.task_flag().study_requested.emit(&"economy")
	assert_eq(tabs, ["economy/this_season", "economy/goods"] as Array[String], "the Ducats chip asks This season, the Stores chip Goods")
	assert_eq(asked, [&"", &"economy", &"economy"], "the button asks its last page, the panel and the flag Economy")


# The narrowing order with People, Food and the fifth mode button (top_bar.gd _fit, spec 6.2): gap, Stores name and
# change, Food name and change, the mode buttons compact, the country name, People's name and change, Ducats' name,
# Ducats' change, the brand, Stores, Food, the study button, and the chips last. First hidden at (px, 5 compact mode buttons with
# 2 px padding): Stores' name 1603, the compact modes 1489, the country 1345, People's name 1223, Ducats' name 1186, Ducats' change
# 1149, the brand 1096, Stores 1016, Food 941, the study button 873, the chips 837.
func test_the_chips_narrow_in_the_order_of_the_spec_and_fit_the_window() -> void:
	await _harness.wait_frames(self, 2)
	var bar := _genoa_bar()
	await _harness.wait_frames(self, 3)
	var ducats := bar.chips().ducats_chip()
	var stores := bar.chips().stores_chip()
	bar.fit_width(1600.0)
	assert_true(stores.visible and bar.name_shown(), "wide: the Stores chip and the country name are there")
	assert_true(ducats.delta_chip().visible, "wide: the change shows")
	bar.fit_width(1280.0)
	assert_lte(bar.get_combined_minimum_size().x, 1280.0, "1280 px fits")
	assert_true(bar.chips().visible and ducats.value_label().visible and ducats.medallion().visible, "1280: the medal and value")
	# Tight: the gap first, then the Stores chip, then the country name, then the Ducats change, the brand last.
	var seen: Array[String] = []
	for width: float in [1100.0, 1000.0, 900.0, 800.0, 790.0]:
		bar.fit_width(width)
		seen.append("%d: stores %s name %s change %s brand %s chips %s" % [int(width), stores.visible, bar.name_shown(), ducats.delta_chip().visible, bar.brand_label().visible, bar.chips().visible])
		assert_lte(bar.get_combined_minimum_size().x, width, "fits %d px: %s" % [int(width), seen[-1]])
	bar.fit_width(1024.0)
	assert_lte(bar.get_combined_minimum_size().x, 1024.0, "the smallest window fits")
	assert_true(bar.chips().visible and bar.study_button().visible, "the chips and the study button stay at 1024 px")
	assert_true(bar.chips().people_chip().value_label().visible and bar.chips().people_chip().medallion().visible, "People keeps its medal and value")
	assert_true(ducats.value_label().visible, "the Ducats value never hides in a real window")
	# The order: whenever the name is still there the Stores chip may be gone, but never the other way round.
	for width: float in [1400.0, 1300.0, 1200.0, 1100.0, 1000.0, 950.0, 900.0, 850.0, 800.0]:
		bar.fit_width(width)
		if bar.name_shown():
			assert_true(ducats.delta_chip().visible, "%d: the Ducats change goes after the name" % int(width))
		if not stores.visible and width >= 850.0:
			assert_true(bar.chips().visible, "%d: the Stores chip goes before the Ducats chip" % int(width))
		if not ducats.delta_chip().visible:
			assert_false(bar.name_shown(), "%d: the name is gone before the Ducats change" % int(width))
	bar.fit_width(4000.0)
	assert_true(stores.visible and bar.name_shown() and ducats.delta_chip().visible and bar.brand_label().visible, "everything comes back")


## The narrowing order of top_bar.gd _fit (DESIGN CALL, owner to confirm): the width at which each step first happens
## falls as the window narrows, one step after the other.
func test_the_narrowing_steps_happen_in_the_pinned_order() -> void:
	await _harness.wait_frames(self, 2)
	var bar := _genoa_bar()
	await _harness.wait_frames(self, 3)
	var ducats := bar.chips().ducats_chip()
	var stores := bar.chips().stores_chip()
	var food := bar.chips().food_chip()
	var people := bar.chips().people_chip()
	var steps := [&"gap", &"stores_name", &"food_name", &"modes", &"country", &"people_name", &"ducats_name",
		&"ducats_change", &"brand", &"stores", &"food", &"study", &"chips"]
	var first := {}
	var width := 1700.0
	while width >= 600.0:
		bar.fit_width(width)
		var now := {
			&"gap": not (bar.get_node("HBox/Gap") as Control).visible,
			&"stores_name": not stores.name_label().visible,
			&"food_name": not food.name_label().visible,
			&"people_name": not people.name_label().visible,
			&"modes": bar.mode_segmented().button_for(0).has_theme_font_size_override(&"font_size"),
			&"country": not bar.name_shown(),
			&"ducats_name": not ducats.name_label().visible,
			&"ducats_change": not ducats.delta_chip().visible,
			&"brand": not bar.brand_label().visible,
			&"stores": not stores.visible,
			&"food": not food.visible,
			&"study": not bar.study_button().visible,
			&"chips": not bar.chips().visible,
		}
		for step: StringName in now:
			if now[step] and not first.has(step):
				first[step] = width
		width -= 5.0
	bar.fit_width(4000.0)
	var seen: Array[StringName] = []
	for step: StringName in steps:
		assert_true(first.has(step), "the step %s happens somewhere from 1700 to 600 px" % step)
		seen.append(step)
	for i: int in range(steps.size() - 1):
		var a: StringName = steps[i]
		var b: StringName = steps[i + 1]
		if first.has(a) and first.has(b):
			assert_gte(float(first[a]), float(first[b]), "%s happens before %s as the window narrows" % [a, b])


func test_both_chips_and_the_study_button_show_at_1280_and_1024_px() -> void:
	await _harness.wait_frames(self, 2)
	var bar := _genoa_bar()
	await _harness.wait_frames(self, 3)
	var ducats := bar.chips().ducats_chip()
	var stores := bar.chips().stores_chip()
	for width: int in [1280, 1024]:
		_harness.viewport.size = Vector2i(width, 720)  # the real resize path
		await _harness.wait_frames(self, 4)
		var tag := "%d px" % width
		assert_true(bar.chips().visible and bar.study_button().visible, "%s: the chips and the study button" % tag)
		assert_true(ducats.visible and bar.chips().people_chip().visible, "%s: Ducats and People show" % tag)
		assert_true(ducats.value_label().visible and bar.chips().people_chip().value_label().visible, "%s: the values show" % tag)
		assert_true(stores.visible and bar.chips().food_chip().visible, "%s: Stores and Food show too (the approved design)" % tag)
		assert_true(bar.date_end().date_button().visible and bar.date_end().end_button().visible, "%s: date and End turn" % tag)
		assert_true(bar.layers_button().visible and bar.help_button().visible and bar.menu_button().visible, "%s: the buttons" % tag)
		assert_lte(bar.get_combined_minimum_size().x, float(width), "%s: the bar fits" % tag)
		assert_lte(bar.size.x, float(width), "%s: the bar is no wider than the window" % tag)
		assert_lte(bar.menu_button().get_global_rect().end.x, float(width), "%s: Menu is not clipped" % tag)
		if width == 1280:
			assert_true(bar.brand_label().visible, "1280 px: the brand shows")
			assert_false(bar.name_shown(), "1280 px: the country name hides (owner to confirm)")
			assert_true(ducats.name_label().visible and ducats.delta_chip().visible, "1280 px: Ducats with name and change")
		else:
			assert_false(bar.brand_label().visible, "1024 px: the brand hides (owner to confirm)")
	for width: int in [900, 800, 700, 1280]:
		_harness.viewport.size = Vector2i(width, 720)
		await _harness.wait_frames(self, 4)
		assert_lte(bar.size.x, float(width), "%d px: the bar is no wider than the window" % width)
		assert_lte(bar.menu_button().get_global_rect().end.x, float(width), "%d px: Menu is not clipped" % width)
	assert_true(stores.visible and bar.brand_label().visible, "back at 1280 everything returns")
	_harness.viewport.size = Vector2i(1280, 720)


func test_below_any_real_window_the_chips_and_the_button_give_way_to_the_rest() -> void:
	await _harness.wait_frames(self, 2)
	var bar := _genoa_bar()
	await _harness.wait_frames(self, 3)
	bar.fit_width(700.0)
	assert_lte(bar.get_combined_minimum_size().x, 700.0, "a game bar fits 700 px")
	assert_false(bar.chips().visible, "the last thing to go")
	assert_true(bar.date_end().end_button().visible, "End turn never hides")
	bar.fit_width(1280.0)
	assert_true(bar.chips().visible and bar.study_button().visible, "and they come back")


func test_the_hex_panel_gets_the_settings_and_refresh_economy_reads_the_chips_again() -> void:
	await _harness.wait_frames(self, 2)
	assert_eq(_hud.hex_panel().settings, _harness.settings, "the panel reads game/confirm_works from the App's settings")
	var bar := _genoa_bar()
	await _harness.wait_frames(self, 3)
	assert_true(Session.dev_money(&"GEN", 90))
	assert_eq(bar.chips().ducats_chip().value_label().text, "610", "dev_money sends no event")
	_hud.refresh_economy()
	assert_eq(bar.chips().ducats_chip().value_label().text, "700")


## The hex panel's rows scroll inside the panel: the HUD column never grows past the window (top bar at y 0, root = viewport).
func test_a_tall_hex_panel_never_pushes_the_hud_past_the_window() -> void:
	Session.start_game(EconomyFixture.game(&"GEN", true))
	for view: Vector2i in [Vector2i(1280, 720), Vector2i(2560, 1440)]:
		_harness.viewport.size = view
		for hex: Vector2i in [Vector2i(10, 13), Vector2i(7, 12)]:
			_hud.hex_panel().show_hex(hex)
			await _harness.wait_frames(self, 3)
			assert_true(_hud.hex_panel().visible)
			assert_eq(_hud.root().get_global_rect(), Rect2(Vector2.ZERO, Vector2(view)), "HUD root is the viewport at %s, %s" % [str(view), str(hex)])
			assert_eq(_hud.top_bar().get_global_position().y, 0.0, "top bar at y 0 at %s, %s" % [str(view), str(hex)])
			assert_lte(_hud.hex_panel().get_global_rect().end.y, float(view.y) + 0.5, "the panel ends inside the window")
	Session.end_game()


func test_the_mode_switch_offers_yields_only_to_a_player_and_fits_1024_px() -> void:
	await _harness.wait_frames(self, 2)
	var top := _hud.top_bar()
	var seg := top.mode_segmented()
	assert_null(seg.button_for(int(MapModes.Mode.YIELDS)), "no Yields in a sandbox")
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "")
	top.refresh_game()
	assert_null(seg.button_for(int(MapModes.Mode.YIELDS)), "no Yields while picking")
	assert_true(bool(Session.act("choose_country", {"tag": "GEN"})["ok"]))
	await _harness.wait_frames(self, 1)
	var yields := seg.button_for(int(MapModes.Mode.YIELDS))
	assert_not_null(yields, "Yields is the fourth segment once you play")
	assert_eq(yields.text, "Yields")
	assert_true(yields.tooltip_text.contains("[4]"))
	var chosen: Array[int] = []
	_hud.mode_requested.connect(func(mode: int) -> void: chosen.append(mode))
	seg.select(int(MapModes.Mode.YIELDS), true)
	assert_eq(chosen, [3], "the fourth segment reaches the Hud as mode 3")
	for width: int in [1024, 1280]:
		top.fit_width(float(width))
		assert_lte(top.get_combined_minimum_size().x, float(width), "the bar fits %d px" % width)
	top.fit_width(4000.0)
	top.set_mode(int(MapModes.Mode.YIELDS))
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	top.refresh_game()
	assert_null(seg.button_for(int(MapModes.Mode.YIELDS)), "a new sandbox takes it away again")


func test_the_mode_buttons_stay_normal_at_1280_and_nothing_clips_down_to_800() -> void:
	await _harness.wait_frames(self, 2)
	var bar := _genoa_bar()
	await _harness.wait_frames(self, 3)
	for width: int in [1280, 1024, 900, 800]:
		bar.fit_width(float(width))
		assert_lte(bar.get_combined_minimum_size().x, float(width), "%d px: nothing clips" % width)
		if width >= 900:
			assert_true(bar.chips().visible and bar.study_button().visible, "%d px: the chips and the study button" % width)
		if width >= 900:
			assert_true(bar.chips().visible, "%d px: the chips (Ducats and People)" % width)



## M4.5 spec 6.7: the Yields legend has its slot top left of the map area, 12 px under the bar; a screen that hides the
## world and photo mode hide it; the F3 panel pushes it down.
func test_the_yields_legend_has_a_slot_follows_the_covers_and_sits_under_f3() -> void:
	await _harness.wait_frames(self, 2)
	var legend := _hud.mode_legend()
	assert_not_null(legend, "the Hud has the legend")
	assert_false(legend.visible, "no map and no Yields: nothing shows")
	legend.show_mode(MapModes.Mode.YIELDS)
	assert_true(legend.visible)
	var map_area := _hud.get_node("Root/Column/Main/MapArea") as Control
	assert_eq(legend.get_parent(), map_area, "a child of the map area")
	assert_almost_eq(legend.offset_top, Hud.LEGEND_TOP, 0.01, "12 px under the bar")
	_hud.set_covered(true, true)
	assert_true(legend.is_covered(), "a screen that hides the world covers it")
	assert_false(legend.visible)
	_hud.set_covered(false, false)
	assert_true(legend.visible)
	_hud.set_hud_visible(false)
	assert_true(legend.is_hidden_by_hud(), "photo mode hides it")
	_hud.set_hud_visible(true)
	assert_false(legend.is_hidden_by_hud())
	assert_true(legend.visible)
	_harness.settings.set_value("dev/developer_tools", true)
	_hud.set_debug_open(true)
	await _harness.wait_frames(self, 3)
	var overlay := _hud.debug_overlay()
	assert_true(overlay.visible, "F3 is open")
	assert_gte(legend.offset_top, overlay.offset_top + overlay.size.y, "the legend sits under the F3 panel")
	_hud.set_debug_open(false)
	await _harness.wait_frames(self, 2)
	assert_almost_eq(legend.offset_top, Hud.LEGEND_TOP, 0.01, "and back under the bar when F3 closes")


## M4.5 spec 6.8: an older header of the action log asks for History at its turn through the shell context.
func test_an_older_log_header_requests_history_at_its_turn() -> void:
	await _harness.wait_frames(self, 1)
	var sent: Array[Array] = []
	_harness.ctx.app_requested.connect(func(what: StringName, args: Dictionary) -> void: sent.append([what, args]))
	_hud.action_log().history_requested.emit(9)
	assert_eq(sent, [[&"study", {"page": &"history", "turn": 9}]])


## The Yields legend ends at least 8 px above the action log's closed bar at 1280 x 720.
func test_the_yields_legend_ends_above_the_closed_log_bar() -> void:
	assert_eq(_harness.viewport.size, Vector2i(1280, 720))
	_hud.action_log().close()
	_hud.mode_legend().show_mode(MapModes.Mode.YIELDS)
	await _harness.wait_frames(self, 3)
	var legend := _hud.mode_legend().get_global_rect()
	var bar := _hud.action_log().get_global_rect()
	assert_lte(legend.end.y + 8.0, bar.position.y, "legend bottom %.0f + 8 <= log bar top %.0f" % [legend.end.y, bar.position.y])
