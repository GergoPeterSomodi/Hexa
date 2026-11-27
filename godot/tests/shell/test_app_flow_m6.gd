## The M6 App flow (docs/architecture/m6-build-spec.md sections 6.1, 6.5, 6.8, 6.10, 6.11 and 9; L24): New game as Genoa ->
## Tab with no army says so -> the Raise tab raises a company at the capital (the Army chip comes) -> the army selected: its
## panel in the dock -> Tab, R, O -> a season (the muster) -> a march order, walked in the order -> a season -> the report's
## Armies section -> Esc clears the army before anything else -> the Military page from the Army chip -> F5, F9: the army and
## its panel come back -> the Sight switch -> key 6, the Supply mode -> the disband's Confirm through the App.
## A second test: the pick and the sandbox refuse the army commands, have no Army chip and no Supply mode.
## The App runs headless in a SubViewport on a temporary save folder.
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")
const GENOA := &"GEN"

var _prev_game: Game = null
var _old_save_dir: String = ""
var _old_lock_path: String = ""


func before_each() -> void:
	Session.ai_enabled = false  # M3 to M7 pin a passive world (M8 D47)
	Bindings.reset_defaults()
	_prev_game = Session.game
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_flow_m6_saves"
	RunLock.path = "user://test_flow_m6_running.lock"


func after_each() -> void:
	for slot: String in SaveFile.SLOTS + SaveFile.AUTO_SLOTS:
		SaveFile.remove(slot, Session.save_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.save_dir))
	RunLock.clear()
	Session.save_dir = _old_save_dir
	RunLock.path = _old_lock_path
	Session.game = _prev_game
	Bindings.reset_defaults()
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)


func _wait_frames(frames: int = 3) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame


func _wait_until(done: Callable, limit: int = 3000) -> bool:
	var frames := 0
	while not bool(done.call()) and frames < limit:
		await get_tree().process_frame
		frames += 1
	return bool(done.call())


func _key(vp: SubViewport, keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		vp.push_input(ev)


## The first key of an action as the Bindings have it.
func _press(vp: SubViewport, action: StringName) -> void:
	var base := Bindings.events_for(action)[0] as InputEventKey
	for pressed: bool in [true, false]:
		var ev := base.duplicate() as InputEventKey
		ev.pressed = pressed
		vp.push_input(ev)


func _app_with(args: Array) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	add_child_autofree(vp)
	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.cli_args_override = PackedStringArray(args)
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("game/autosave", "off")
	s.set_value("graphics/season_change", "instant")
	s.set_value("game/season_report", "full")
	s.set_value("game/movement", "instant")  # the replay of 6.4 is instant here; the replay's own tests play it
	app.set_settings_override(s)
	vp.add_child(app)
	return {"vp": vp, "app": app}


func _guard_over(app: App) -> bool:
	return Time.get_ticks_msec() > app.requests().flow.guard_until


## Space, then the report is up.
func _end_season(vp: SubViewport, app: App) -> void:
	await _wait_until(func() -> bool: return _guard_over(app), 600)
	_key(vp, KEY_SPACE)
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is SeasonReport), "the report opens")


func _close_report(vp: SubViewport, app: App) -> void:
	_key(vp, KEY_SPACE)
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0), "the report closes")


func _words(node: Node) -> String:
	return " | ".join(AppFlowHelpers.labels_under(node))


func _armies_node(app: App) -> MapArmies:
	return app.map_scene().get_node("MapArmies") as MapArmies


func _men_of(game: Game, tag: StringName) -> int:
	return Armies.men_of_country(game, tag)


func _genoa_army(game: Game) -> Army:
	var list := Armies.of_country(game, GENOA)
	return list[0] if not list.is_empty() else null


## A hex a few steps from `from` that the army walks to this season with no risk (MovePreview says so), or (-1, -1).
func _march_goal(game: Game, army_id: int, from: Vector2i) -> Vector2i:
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if hex == from or absi(hex.x - from.x) + absi(hex.y - from.y) > 4:
			continue
		var preview := MovePreview.to(game, GENOA, army_id, hex)
		if bool((preview["verdict"] as Dictionary).get("ok", false)) and (preview["risks"] as Array).is_empty() \
				and not ((preview["leg"] as Dictionary)["hexes"] as Array).is_empty():
			return hex
	return Vector2i(-1, -1)


## The Raise tab of the capital: the first kind whose row is not refused is raised once.
func _raise_at(app: App, vp: SubViewport, hex: Vector2i) -> void:
	app.map_scene().select_hex(hex)
	await _wait_frames(2)
	assert_true(app.hud().tile_window().show_tab(&"army"), "the Army tab opens")
	await _wait_frames(2)
	var raised := false
	for row: CompanyRow in (app.hud().tile_window().tab_node() as ArmyTab).company_rows():
		if not row.hammer().disabled:
			row.hammer().pressed.emit()
			raised = true
			break
	assert_true(raised, "the Raise tab offers a company it can pay for")
	await _wait_frames(2)
	app.map_scene().select_hex(MapScene.NO_HEX)
	await _wait_frames(2)


## One long flow in the order of the spec (6.1, 6.5, 6.8, 6.10, 6.11 and 9).
func test_m6_flow_raise_orders_seasons_report_ladder_save_and_supply() -> void:
	var env := await _app_with(["--new-game", "--country=GEN", "--seed=1480"])
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting()), "the game is up")
	await _wait_frames(3)
	var game := Session.game
	var capital := Countries.by_tag(game, GENOA).capital
	assert_true(app.hud().chips().army_chip().visible, "a player's Army chip shows, at 0 men")
	assert_eq(app.hud().chips().army_chip().value_label().text, "0", "no men yet")
	app.hud().chips().milestone = "5"  # before milestone 6 the Army chip stays hidden whatever the army
	app.hud().chips().refresh()
	assert_false(app.hud().chips().army_chip().visible, "milestone 5: no Army chip")
	app.hud().chips().milestone = Bindings.SHELL_MILESTONE
	app.hud().chips().refresh()
	assert_true(app.hud().chips().army_chip().visible, "milestone 6: the Army chip is back")

	_press(vp, &"game_next_unit")  # Tab with no army says so
	await _wait_frames(2)
	assert_true(AppFlowHelpers.has_toast(app, "You have no army."), "Tab with no army")

	# The Raise tab of the capital raises a company (ducats and iron are the player's: a short purse is topped up first).
	Session.dev_money(GENOA, 500)
	Session.dev_goods(GENOA, game.defs.good_id(&"iron"), 2)
	await _raise_at(app, vp, capital)
	assert_eq(Armies.of_country(game, GENOA).size(), 1, "one army of Genoa's")
	assert_true(AppFlowHelpers.has_toast(app, "Raised"), "the raise says so")
	assert_eq(app.hud().chips().army_chip().value_label().text, Words.number(_men_of(game, GENOA)), "the Army chip shows the men raised")

	# The army selected (a token's click): its panel is in the dock, the hex panel is not.
	var army := _genoa_army(game)
	_armies_node(app).select_army(army.id)
	await _wait_frames(3)
	assert_true(app.hud().army_panel().visible, "the army panel shows")
	assert_eq(app.hud().army_panel().shown_army(), army.id, "for that army")
	assert_false(app.hud().tile_window().visible, "the tile window gives way")

	# Tab selects the next army needing orders (the same one here); R refuses a march that is not halted; O orders a halt on its own hex.
	_press(vp, &"game_next_unit")
	await _wait_frames(2)
	assert_eq(app.hud().army_panel().shown_army(), army.id, "Tab keeps the army")
	_press(vp, &"game_continue_march")
	await _wait_frames(2)
	assert_true(AppFlowHelpers.toasts(app).size() > 0, "R says why not")
	_press(vp, &"map_command_key")  # O at the cursor, which stands on the army
	await _wait_frames(2)
	assert_true(AppFlowHelpers.has_toast(app, "holds at"), "O holds the army on its hex")

	# The first season musters the army.
	await _end_season(vp, app)
	assert_true(_words(app.stack().top()).contains("Armies"), "the report has its Armies section: " + _words(app.stack().top()))
	await _close_report(vp, app)

	# moves in the month: a march order (a right click on a reachable hex) walks the army before End season. The goal asks
	# nothing (no risk).
	army = Armies.by_id(game, army.id)
	var goal := _march_goal(game, army.id, capital)
	assert_ne(goal, Vector2i(-1, -1), "a hex the army can march to")
	_armies_node(app).select_army(army.id)
	_armies_node(app).command(goal)
	await _wait_frames(2)
	assert_eq(app.stack().count(), 0, "a plain march asks nothing")
	assert_true(AppFlowHelpers.has_toast(app, "walks to"), "the march says so")
	var stood := Armies.by_id(game, army.id).hex
	assert_ne(stood, capital, "the army walked from the capital in the order")

	# The next season: the report, and no season replay (instant under game/movement).
	await _end_season(vp, app)
	assert_false(app.requests().replay.active(), "no replay runs at instant speed")
	assert_true(_words(app.stack().top()).contains("Armies"), "the report has its Armies section: " + _words(app.stack().top()))
	await _close_report(vp, app)
	await _ladder_and_pages(vp, app, army.id)
	await _save_and_load(vp, app, army.id)
	await _sight_and_supply(vp, app)
	await _disband_through_the_app(vp, app)


## Esc: the army goes first (the panel with it), the next Esc has nothing to clear and opens the pause menu; the Army chip
## opens the Military page; key 6 is the Supply mode with its legend.
func _ladder_and_pages(vp: SubViewport, app: App, army_id: int) -> void:
	_armies_node(app).select_army(army_id)
	await _wait_frames(2)
	assert_true(app.hud().army_panel().visible, "an army selected again")
	_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	assert_eq(_armies_node(app).selected_army(), -1, "Esc clears the army")
	assert_false(app.hud().army_panel().visible, "and its panel")
	assert_eq(app.stack().count(), 0, "no pause menu for that Esc")
	_key(vp, KEY_ESCAPE)
	assert_true(await _wait_until(func() -> bool: return app.stack().top() != null and app.stack().top().screen_id == &"pause_menu"), "Esc with nothing selected opens the pause menu")
	_key(vp, KEY_ESCAPE)
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0), "and Esc closes it")

	app.hud().chips().army_chip().pressed.emit()
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is Study), "the Army chip opens the study")
	assert_eq((app.stack().top() as Study).current_page_id(), &"military", "at the Military page")
	_key(vp, KEY_ESCAPE)
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0), "the study closes")

	_press(vp, &"view_mode_6")
	await _wait_frames(3)
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.SUPPLY), "key 6 is the Supply mode")
	assert_eq(app.hud().mode_legend().mode(), int(MapModes.Mode.SUPPLY), "with its legend")
	_press(vp, &"view_mode_5")
	await _wait_frames(3)


## F5 keeps the army and F9 brings it back, with its panel's words the same once it is selected again.
func _save_and_load(vp: SubViewport, app: App, army_id: int) -> void:
	_armies_node(app).select_army(army_id)
	await _wait_frames(2)
	var panel_before := AppFlowHelpers.labels_under(app.hud().army_panel())
	var digest := Session.game.digest()
	_key(vp, KEY_F5)
	assert_true(await _wait_until(func() -> bool: return SaveFile.read_header(SaveRows.QUICK_SLOT, Session.save_dir)["state"] == &"ok"), "the quicksave is written")
	_armies_node(app).clear_army()
	await _wait_frames(2)
	_key(vp, KEY_F9)
	if await _wait_until(func() -> bool: return app.stack().top() is Confirm, 60):
		(app.stack().top() as Confirm).button_for(&"confirm").pressed.emit()  # unsaved changes: load anyway
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0 and not app.is_starting() and app.map_scene() != null and app.map_scene().is_loading() == false), "the quicksave loads")
	await _wait_frames(3)
	assert_eq(Session.game.digest(), digest, "the same game after the load")
	assert_eq(Armies.of_country(Session.game, GENOA).size(), 1, "the army is back")
	_armies_node(app).select_army(army_id)
	await _wait_frames(2)
	assert_eq(AppFlowHelpers.labels_under(app.hud().army_panel()), panel_before, "its panel says the same")


## The Sight switch of the Layers popover is the setting map/sight_veil, both ways.
func _sight_and_supply(vp: SubViewport, app: App) -> void:
	var sight := app.hud().layers_popover().sight_switch()
	assert_true((sight.get_parent() as Control).visible, "a real game shows the Sight switch")
	sight.toggled.emit(false)
	assert_false(bool(app.settings().get_value("map/sight_veil")), "Sight off writes the setting")
	sight.toggled.emit(true)
	assert_true(bool(app.settings().get_value("map/sight_veil")), "and on again")


## The disband of the whole army asks first through the App's stack: its Confirm, accepted, disbands it.
func _disband_through_the_app(_vp: SubViewport, app: App) -> void:
	var game := Session.game
	var army := _genoa_army(game)
	_armies_node(app).select_army(army.id)
	await _wait_frames(2)
	# The panel's place link looks at the army's hex and selects it (the same route as a report line).
	app.hud().army_panel().look_at_requested.emit(army.hex)
	await _wait_frames(3)
	assert_eq(app.map_scene().selected, army.hex, "the place link selects the army's hex")
	_armies_node(app).select_army(army.id)
	await _wait_frames(2)
	var disband := app.hud().army_panel().action_button("disband")
	assert_not_null(disband, "the army panel has Disband")
	disband.pressed.emit()
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is Confirm), "the disband asks first")
	var confirm := app.stack().top() as Confirm
	assert_true(_words(confirm).contains("Disband"), "the Confirm names the disband")
	confirm.button_for(&"confirm").pressed.emit()
	assert_true(await _wait_until(func() -> bool: return Armies.by_id(Session.game, army.id) == null), "the army is disbanded")
	assert_true(AppFlowHelpers.has_toast(app, "Disbanded"), "and the toast says so")


## The pick has no Army chip and refuses the army commands before a country is chosen.
func test_the_pick_has_no_army_chip_and_refuses_the_army_commands() -> void:
	var env := await _app_with(["--new-game", "--seed=1480"])
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and app.map_scene().picking() and not app.is_starting()), "the pick is up")
	await _wait_frames(2)
	assert_false(app.hud().chips().army_chip().visible, "the pick has no Army chip")
	assert_eq(DevCommands.run("armies", app.context()), "You have no army.", "armies with no player")
	var refused := Session.act("raise", {"hex": Vector2i(6, 11), "kind": 0, "count": 1})
	assert_false(bool(refused.get("ok", false)), "raise is refused before a country is chosen")


## The sandbox has no Army chip, refuses raise, and has no Supply mode (key 6 says why).
func test_the_sandbox_has_no_army_chip_no_raise_and_no_supply_mode() -> void:
	var env := await _app_with(["--sandbox", "--seed=1480"])
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and not app.is_starting()), "the sandbox is up")
	await _wait_frames(2)
	assert_false(app.hud().chips().army_chip().visible, "the sandbox has no Army chip")
	assert_eq(DevCommands.run("raise 6 11 pikemen", app.context()), "Refused: the sandbox has no armies", "the sandbox refuses raise")
	_press(vp, &"view_mode_6")
	await _wait_frames(3)
	assert_ne(app.map_scene().mode(), int(MapModes.Mode.SUPPLY), "no Supply mode in the sandbox")
	assert_gt(AppFlowHelpers.toasts(app).size(), 0, "key 6 says why")
