## The M7 App flow (docs/architecture/m7-build-spec.md sections 6.1, 6.4 to 6.11 and 9; B28; done-when 10): New game as Savoy ->
## the console's Milanese army -> the declaration through the country panel's Confirm -> a raise and a march with the odds card
## and its toast -> seasons with a siege of Pavia -> the replay's battle badge, the report's War section and its battle link ->
## B and Esc with the dock -> F5 and F9 in the siege -> a peace from the country panel. Smaller tests: the war alert at idle and
## in DECISIONS, Storm (Shift+O and Shift+right click), the Castle areas switch and its Options row both ways, the milestone
## gate and the sandbox. The App runs headless in a SubViewport on a temporary save folder; every event comes from the rules.
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")
const SAV := &"SAV"
const MLO := &"MLO"
const ALESS := Vector2i(7, 9)
const VERCELLI := Vector2i(6, 9)
const PAVIA := Vector2i(10, 9)

var _prev_game: Game = null
var _old_save_dir: String = ""
var _old_lock_path: String = ""


func before_each() -> void:
	Session.ai_enabled = false  # M3 to M7 pin a passive world (M8 D47)
	Bindings.reset_defaults()
	_prev_game = Session.game
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_flow_m7_saves"
	RunLock.path = "user://test_flow_m7_running.lock"


func after_each() -> void:
	for slot: String in SaveFile.SLOTS + SaveFile.AUTO_SLOTS:
		SaveFile.remove(slot, Session.save_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.save_dir))
	RunLock.clear()
	Session.save_dir = _old_save_dir
	RunLock.path = _old_lock_path
	Session.game = _prev_game
	Movement.clear_test_hostility()
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


func _key(vp: SubViewport, keycode: Key, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.shift_pressed = shift
		ev.pressed = pressed
		vp.push_input(ev)


## The first key of an action as the Bindings have it.
func _press(vp: SubViewport, action: StringName) -> void:
	var base := Bindings.events_for(action)[0] as InputEventKey
	for pressed: bool in [true, false]:
		var ev := base.duplicate() as InputEventKey
		ev.pressed = pressed
		vp.push_input(ev)


func _app_with(args: Array, movement: String = "instant") -> Dictionary:
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
	s.set_value("game/movement", movement)
	app.set_settings_override(s)
	vp.add_child(app)
	return {"vp": vp, "app": app}


func _savoy() -> Dictionary:
	var env := await _app_with(["--new-game", "--country=SAV", "--seed=1480"])
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting()), "the game is up")
	await _wait_frames(3)
	return env


func _guard_over(app: App) -> bool:
	return Time.get_ticks_msec() > app.requests().flow.guard_until


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


func _find_button(node: Node, match_fn: Callable) -> Button:
	for child: Node in node.get_children():
		if child is Button and bool(match_fn.call(child)):
			return child as Button
		var deeper := _find_button(child, match_fn)
		if deeper != null:
			return deeper
	return null


## A button of the country panel's war section by the key of its action ("declare_war:", "make_peace:take").
func _war_button(app: App, key: String) -> Button:
	return _find_button(app.hud().country_panel().war_section(), func(b: Button) -> bool:
		return str(b.get_meta(&"key", "")) == key)


## The top screen is a Confirm: its words, and the answer pressed.
func _answer(app: App, choice: StringName) -> void:
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is Confirm), "a question is asked")
	(app.stack().top() as Confirm).button_for(choice).pressed.emit()
	await _wait_frames(2)


func _give_money(game: Game, tag: StringName) -> void:
	var c := Countries.by_tag(game, tag)
	Session.dev_money(tag, 1500 - c.treasury)
	var iron := game.defs.good_id(&"iron")
	Session.dev_goods(tag, iron, 20 - c.stock[iron])


## One long flow in the order of spec 9 (done-when 10).
func test_m7_flow_declare_march_odds_battle_siege_dock_save_and_peace() -> void:
	var env := await _savoy()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	var game := Session.game
	_give_money(game, SAV)
	assert_eq(Bindings.SHELL_MILESTONE, "7", "the shell is at milestone 7")

	# The console makes Milan's army; the war is declared from the country panel's Confirm.
	var made := DevCommands.run("as MLO raise 7 9 pikemen 2", app.context())
	assert_true(made.begins_with("Done"), made)
	assert_eq(DevCommands.run("wars", app.context()), "You are at war with no one.", "no war yet")
	app.context().request(&"declare_war", {"target": MLO})
	await _wait_frames(2)
	assert_true(app.hud().country_panel().visible, "the country panel shows Milan")
	await _answer(app, &"confirm")
	assert_not_null(Wars.war_between(game, SAV, MLO), "the war is declared")
	assert_true(AppFlowHelpers.has_toast(app, "War with the Duchy of Milan"), "the toast says so")
	assert_true(DevCommands.run("wars", app.context()).contains("Duchy of Milan"), "wars lists it")
	app.hud().debug_overlay().refresh_metrics()
	assert_true(app.hud().debug_overlay().m7_text().begins_with("wars 1 · "), app.hud().debug_overlay().m7_text())

	# Savoy raises at Vercelli; the army is selected; the odds card of Alessandria; the march says "marches on".
	assert_true(DevCommands.run("raise 6 9 pikemen 2", app.context()).begins_with("Done"), "Savoy raises two companies")
	var army := Armies.at(game, VERCELLI)[0]
	_armies_node(app).select_army(army.id)
	await _wait_frames(2)
	app.hud().map_hover().order_cursor_moved(ALESS, Vector2(640.0, 360.0))
	await _wait_frames(2)
	var odds := app.hud().odds_card()
	assert_true(odds.is_open(), "the odds card shows over Milan's army")
	assert_true(_words(odds).contains("Attack"), _words(odds))
	assert_true(_armies_node(app).command(ALESS), "the order is given")
	await _wait_frames(2)
	assert_true(AppFlowHelpers.has_toast(app, "marches on"), "the attack toast: " + str(AppFlowHelpers.toasts(app)))
	_armies_node(app).clear_army()

	# Savoy's other army sits before Pavia (the siege); the seasons run until the battle is fought.
	ArmyFixture.army(game, SAV, PAVIA, 0, 4)
	game.version += 1
	var fought := -1
	for _season: int in 6:
		await _end_season(vp, app)
		if fought < 0:
			fought = BattleView.latest_of(game, SAV)
			if fought >= 0:
				break
		await _close_report(vp, app)
	assert_gte(fought, 0, "a battle was fought")
	var report := app.stack().top() as SeasonReport
	assert_true(_words(report).contains("War"), "the report has its War section: " + _words(report))
	var marks := app.map_scene().get_node("WarMarks") as WarMarks
	assert_not_null(marks.mark_at(ALESS), "the battle badge stands on Alessandria")
	assert_not_null(marks.siege_mark(PAVIA), "the siege dial stands on Pavia")
	var link := _find_button(report, func(b: Button) -> bool: return b.tooltip_text == "Open the battle")
	assert_not_null(link, "the report's war line is a battle link")
	link.pressed.emit()
	assert_true(await _wait_until(func() -> bool: return app.requests().war.dock() != null), "the link opens the dock")
	var dock := app.requests().war.dock()
	assert_eq(dock.shown_record(), fought, "at that battle")
	dock.play()
	dock.go_to_day(dock.day_count())
	_key(vp, KEY_ESCAPE)
	assert_true(await _wait_until(func() -> bool: return app.requests().war.dock() == null), "Esc closes the dock first")
	_press(vp, &"game_battle")
	assert_true(await _wait_until(func() -> bool: return app.requests().war.dock() != null), "B opens the last battle")
	Events.battle_mark_clicked.emit(fought)
	await _wait_frames(2)
	assert_eq(app.stack().count(), 1, "a badge click re-uses the open dock")
	_key(vp, KEY_ESCAPE)
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0), "Esc closes it again")

	# The hex menu's war items reach the App: the battle opens the dock, the castle area looks at its castle.
	var menu := _armies_node(app).hex_menu()
	menu.chosen.emit([&"battle", fought])
	assert_true(await _wait_until(func() -> bool: return app.requests().war.dock() != null), "the menu's battle item opens the dock")
	_key(vp, KEY_ESCAPE)
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0), "Esc closes it")
	menu.chosen.emit([&"castle_area", PAVIA])
	await _wait_frames(2)
	assert_eq(app.map_scene().selected, PAVIA, "the castle area's item selects its castle")
	marks.siege_clicked.emit(PAVIA)
	assert_eq(app.map_scene().selected, PAVIA, "a siege dial's click selects its hex")

	await _save_and_load(vp, app)
	await _make_peace(app)


## F5 and F9 in the siege: the same game after the load.
func _save_and_load(vp: SubViewport, app: App) -> void:
	var digest := Session.game.digest()
	var sieges := Session.game.sieges.size()
	_key(vp, KEY_F5)
	assert_true(await _wait_until(func() -> bool: return SaveFile.read_header(SaveRows.QUICK_SLOT, Session.save_dir)["state"] == &"ok"), "the quicksave is written")
	_key(vp, KEY_F9)
	if await _wait_until(func() -> bool: return app.stack().top() is Confirm, 60):
		(app.stack().top() as Confirm).button_for(&"confirm").pressed.emit()
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0 and not app.is_starting() and app.map_scene() != null and not app.map_scene().is_loading()), "the quicksave loads")
	await _wait_frames(3)
	assert_eq(Session.game.digest(), digest, "the same game after the load")
	assert_eq(Session.game.sieges.size(), sieges, "the sieges come back")


## The peace: the first term the panel offers (take, white or yield), asked and accepted.
func _make_peace(app: App) -> void:
	app.context().request(&"country", {"tag": MLO})
	await _wait_frames(2)
	var peace := _war_button(app, "make_peace:take")
	for key: String in ["make_peace:take", "make_peace:white", "make_peace:yield"]:
		peace = _war_button(app, key)
		if peace != null and not peace.disabled:
			break
	assert_not_null(peace, "the war section has a peace button")
	peace.pressed.emit()
	await _answer(app, &"confirm")
	assert_null(Wars.war_between(Session.game, SAV, MLO), "the war is over")
	assert_true(AppFlowHelpers.has_toast(app, "Peace with the Duchy of Milan"), "the peace toast")


## The war alert: a war declared on the player at idle shows its Confirm at once; declared while the season runs it waits in
## DECISIONS and comes after the movement, before the report.
func test_the_war_alert_at_idle_and_in_decisions() -> void:
	var env := await _savoy()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	assert_true(DevCommands.run("as MLO declare SAV", app.context()).begins_with("Done"), "Milan declares war on Savoy")
	var alert := app.stack().top() as Confirm
	assert_not_null(alert, "the alert is up at idle")
	assert_true(_words(alert).contains("The Duchy of Milan has declared war on the Duchy of Savoy."), _words(alert))
	assert_true(_words(alert).contains("To the map"), "its choice reads 'To the map' at idle")
	alert.button_for(&"show").pressed.emit()
	await _wait_frames(3)
	assert_true(app.hud().country_panel().visible, "Show opens Milan's panel")
	assert_eq(app.stack().count(), 0, "and the alert is gone")
	assert_true(DevCommands.run("peace MLO white", app.context()).begins_with("Refused"), "a white peace needs four seasons of war")


## Declared while the season runs, the war waits in DECISIONS: the Confirm comes after the movement and before the report, its
## choice reads "To the report", and the answer lets the report come. Save is refused while it is up.
func test_the_war_alert_waits_in_decisions_before_the_report() -> void:
	var env := await _savoy()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	var flow := app.requests().flow
	var once := {"done": false}
	flow.state_changed.connect(func(state: int) -> void:
		if state == SeasonFlow.State.RUNNING and not bool(once["done"]):
			once["done"] = true
			assert_true(bool(Session.act("declare_war", {"target": SAV, "tag": MLO}).get("ok", false)), "Milan declares in the season"))
	await _wait_until(func() -> bool: return _guard_over(app), 600)
	_key(vp, KEY_SPACE)
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is Confirm), "the alert comes before the report")
	assert_eq(flow.state(), SeasonFlow.State.DECISIONS, "the flow is in DECISIONS")
	var alert := app.stack().top() as Confirm
	assert_true(_words(alert).contains("To the report"), "its choice reads 'To the report'")
	assert_true(app.requests()._season_busy(), "Save is refused while the decisions are up")
	alert.button_for(&"report").pressed.emit()
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is SeasonReport), "the report follows the answer")
	assert_eq(app.requests().decisions.count(), 0, "the queue is empty")


## Shift+O and Shift+right click storm with the selected army; with none Shift+O says so.
func test_storm_by_key_and_by_click() -> void:
	var env := await _savoy()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	_key(vp, KEY_O, true)
	await _wait_frames(2)
	assert_true(AppFlowHelpers.has_toast(app, WarRequests.NO_ARMY), "Shift+O with no army says so")
	_give_money(Session.game, SAV)
	DevCommands.run("raise 6 9 pikemen 2", app.context())
	var army := Armies.at(Session.game, VERCELLI)[0]
	_armies_node(app).select_army(army.id)
	await _wait_frames(2)
	assert_true(app.map_scene().map_input().storm_ready.call(), "Shift+right click storms while an army is selected")
	assert_false(app.requests().war.storm_at(ALESS), "a storm with no war is refused")
	assert_gt(AppFlowHelpers.toasts(app).size(), 1, "and says why")
	DevCommands.run("declare MLO", app.context())
	DevCommands.run("as MLO raise 7 9 pikemen 2", app.context())
	assert_false(app.requests().war.storm_at(ALESS), "there is no fortress at Alessandria to storm")
	var verdict := Session.check("storm", {"army": army.id, "goal": PAVIA})
	assert_eq(app.requests().war.storm_at(PAVIA), bool(verdict["ok"]), "Storm follows the rules' verdict")
	_armies_node(app).clear_army()
	app.map_scene().map_input().storm_ready = Callable()
	assert_false(app.requests().war._army_selected(), "no army, no storm click")


## The Castle areas switch of the Layers popover and the Options row are the same setting, both ways; the sandbox has no switch.
func test_the_castle_areas_switch_and_the_options_row_are_one_setting() -> void:
	var env := await _savoy()
	var app := env["app"] as App
	var popover := app.hud().layers_popover()
	assert_true((popover.castle_switch().get_parent() as Control).visible, "a real game shows the switch")
	assert_true(popover.castle_switch().button_pressed, "on by default")
	popover.castle_switch().toggled.emit(false)
	assert_false(bool(app.settings().get_value("map/castle_areas")), "the switch writes the setting")
	var wars := app.map_scene().get_node("MapWars") as MapWars
	assert_false(wars.area_gate(), "and the war layer's gate follows")
	app.settings().set_value("map/castle_areas", true)
	assert_true(popover.castle_switch().button_pressed, "the Options row's change moves the switch")
	var row := Options.new()
	row.setup(app.context())
	var found := false
	for entry: Dictionary in Settings.SCHEMA.values():
		found = found or str(entry.get("label", "")) == "Castle areas with an army selected"
	assert_true(found, "the setting has its Options label")
	row.free()
	assert_true(float(str(Settings.SCHEMA["map/castle_areas"]["since"])) <= Options.TARGET_MILESTONE, "and the Options screen shows milestone 7 rows")


func test_the_sandbox_has_no_castle_switch_and_refuses_declare() -> void:
	var env := await _app_with(["--sandbox", "--seed=1480"])
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and not app.is_starting()), "the sandbox is up")
	await _wait_frames(2)
	assert_false((app.hud().layers_popover().castle_switch().get_parent() as Control).visible, "no Castle areas switch")
	assert_true(DevCommands.run("declare MLO", app.context()).contains("no countries"), "declare is refused")
	app.requests().war.open_last_battle()
	assert_true(AppFlowHelpers.has_toast(app, WarRequests.NO_BATTLE), "B with no battle says so")


## Savoy and Milan go to war, Savoy raises at Vercelli and marches on Alessandria; seasons run until Savoy has fought a battle.
## Returns its record id (the report is closed; no army is selected).
func _fight_a_battle(vp: SubViewport, app: App) -> int:
	var game := Session.game
	_give_money(game, SAV)
	DevCommands.run("as MLO raise 7 9 pikemen 2", app.context())
	DevCommands.run("declare MLO", app.context())
	DevCommands.run("raise 6 9 pikemen 2", app.context())
	var army := Armies.at(game, VERCELLI)[0]
	DevCommands.run("march %d 7 9" % army.id, app.context())
	for _season: int in 6:
		await _end_season(vp, app)
		await _close_report(vp, app)
		if BattleView.latest_of(game, SAV) >= 0:
			return BattleView.latest_of(game, SAV)
	return -1


## The war UI answers from milestone 7 and not before: the dock opens for a real battle at 7 and not at 6; Storm is ready with
## an army selected at 7 and not at 6; the war alert shows at 7 and not at 6.
func test_the_war_ui_answers_at_milestone_seven_and_not_at_six() -> void:
	var env := await _savoy()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	var fought := await _fight_a_battle(vp, app)
	assert_gte(fought, 0, "a battle was fought")
	var war := app.requests().war
	assert_true(war.enabled(), "the shell is at 7")
	assert_true(war.open_battle(fought), "the dock opens at 7")
	assert_not_null(war.dock(), "on the stack")
	_key(vp, KEY_ESCAPE)
	assert_true(await _wait_until(func() -> bool: return war.dock() == null), "Esc closes it")
	var army := Armies.of_country(Session.game, SAV)[0]
	_armies_node(app).select_army(army.id)
	assert_true(bool(app.map_scene().map_input().storm_ready.call()), "Storm is ready with an army selected at 7")
	war.milestone = "6"
	assert_false(war.enabled(), "milestone 6")
	assert_false(war.open_battle(fought), "no dock at 6")
	assert_eq(app.stack().count(), 0, "nothing opened")
	assert_false(bool(app.map_scene().map_input().storm_ready.call()), "Storm is not ready at 6")
	# The alert: two other neighbours of Savoy declare on it, the first at milestone 6, the second at 7.
	var others: Array[StringName] = []
	for id: int in Territory.neighbours(Session.game, Countries.by_tag(Session.game, SAV).id):
		var other := Countries.by_id(Session.game, id)
		if other != null and other.tag != MLO:
			others.append(other.tag)
	assert_gte(others.size(), 2, "Savoy has two more neighbours")
	assert_true(DevCommands.run("as %s declare SAV" % others[0], app.context()).begins_with("Done"), "the first declares")
	assert_eq(app.stack().count(), 0, "no war alert at 6")
	war.milestone = "7"
	assert_true(DevCommands.run("as %s declare SAV" % others[1], app.context()).begins_with("Done"), "the second declares")
	assert_true(app.stack().top() is Confirm, "the war alert shows at 7")


## The map layer follows map/castle_areas: with a war on and an army selected the area gate and the overlay's area tint are on
## and F3 counts area hexes; with the setting off the gate, the tint and the F3 count are off.
func test_the_castle_area_layer_follows_the_setting() -> void:
	var env := await _savoy()
	var app := env["app"] as App
	_give_money(Session.game, SAV)
	DevCommands.run("raise 6 9 pikemen 2", app.context())
	var army := Armies.at(Session.game, VERCELLI)[0]
	var wars := app.map_scene().get_node("MapWars") as MapWars
	_armies_node(app).select_army(army.id)
	await _wait_frames(2)
	assert_false(wars.area_gate(), "no war: no area gate")
	DevCommands.run("declare MLO", app.context())
	await _wait_frames(3)
	assert_true(wars.area_gate(), "a war, an army selected, the setting on: the gate is open")
	assert_true(app.map_scene().overlay().is_areas_on(), "the overlay's tint is on")
	app.hud().debug_overlay().refresh_metrics()
	assert_false(app.hud().debug_overlay().m7_text().ends_with("areas 0"), app.hud().debug_overlay().m7_text())
	app.settings().set_value("map/castle_areas", false)
	await _wait_frames(3)
	assert_false(wars.area_gate(), "the setting off closes the gate")
	assert_false(app.map_scene().overlay().is_areas_on(), "and the tint")
	app.hud().debug_overlay().refresh_metrics()
	assert_true(app.hud().debug_overlay().m7_text().ends_with("areas 0"), "F3 counts no area hexes while they are off")
	app.settings().set_value("map/castle_areas", true)
	await _wait_frames(3)
	assert_true(wars.area_gate(), "and on again")


func test_a_battle_the_player_did_not_see_is_refused() -> void:
	var env := await _savoy()
	var app := env["app"] as App
	assert_false(app.requests().war.open_battle(999), "an unknown record shows nothing")
	assert_true(AppFlowHelpers.has_toast(app, WarRequests.NOT_SEEN), "and says so")
	assert_eq(app.stack().count(), 0, "no dock")


## The declare and peace requests ask only when the section's button would be enabled: a declaration on a country at war, a peace
## with no war and a peace on unknown terms show no panel and no question, only the reason.
func test_the_declare_and_peace_requests_ask_only_when_the_button_is_enabled() -> void:
	var env := await _savoy()
	var app := env["app"] as App
	app.context().request(&"peace", {"target": MLO, "terms": &"white"})
	await _wait_frames(2)
	assert_eq(app.stack().count(), 0, "a peace with no war asks nothing")
	assert_false(app.hud().country_panel().visible, "and shows no panel")
	assert_true(AppFlowHelpers.has_toast(app, "not at war"), "it says why")
	assert_true(DevCommands.run("declare MLO", app.context()).begins_with("Done"), "the war is declared")
	app.context().request(&"declare_war", {"target": MLO})
	await _wait_frames(2)
	assert_eq(app.stack().count(), 0, "a declaration on a country at war asks nothing")
	assert_true(AppFlowHelpers.has_toast(app, "already at war"), "it says why")
	app.context().request(&"peace", {"target": MLO, "terms": &"sue"})
	app.context().request(&"peace", {"target": MLO})
	await _wait_frames(2)
	assert_eq(app.stack().count(), 0, "unknown and empty terms ask nothing")
	assert_true(AppFlowHelpers.has_toast(app, "no such terms"), "unknown terms say so")
	app.context().request(&"peace", {"target": MLO, "terms": &"yield"})
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is Confirm), "an allowed peace asks")
