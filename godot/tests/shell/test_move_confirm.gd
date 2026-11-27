## The confirm of a risky move and the dock after a battle (docs/architecture/moves-build-spec.md R48, R49, R52, R53, D18, D21;
## MV10): a march into a seen enemy army, into land of a country at war and to a hex out of supply, a storm and a Continue each
## ask once before they act; a plain march and a halt never ask; Cancel (and Esc) changes nothing and says nothing; the setting
## game/confirm_moves off asks nothing; the battle dock opens only after the live walk has played or been skipped, and at once
## when nothing plays. The scene tests give the map's orders a callable that keeps the questions; the App tests answer them on the
## App's stack. The war began last season, so fair warning (R73) stands aside.
## Planted faults: an act before the answer; a confirm on a plain march; a march into a seen enemy army with no confirm; a
## Cancel that toasts; the dock opened before the walk ends.
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")
const SAV := MovesFixture.SAVOY
const MLO := MovesFixture.MILAN

var _game: Game = null
var _scene: MapScene = null
var _asked: Array[Confirm] = []
var _said: Array = []
var _reasons: Array[String] = []
var _battles: Array[int] = []
var _settings: Settings = null
var _prev_game: Game = null
var _old_save_dir := ""
var _old_lock_path := ""


func before_each() -> void:
	_asked = []
	_said = []
	_reasons = []
	_battles = []
	_scene = null
	_settings = Settings.new("macOS", true)
	Session.ai_enabled = false
	Bindings.reset_defaults()
	_prev_game = Session.game
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_move_confirm_saves"
	RunLock.path = "user://test_move_confirm_running.lock"


func after_each() -> void:
	Session.end_game()
	RunLock.clear()
	Session.save_dir = _old_save_dir
	RunLock.path = _old_lock_path
	Session.game = _prev_game
	Bindings.reset_defaults()
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)


# ----- the scene ----------------------------------------------------------------------------------------------------------


## Savoy against Milan since last season: the duel's armies, the war a season old. The home army stands on (5, 6); the hex
## south of it, (5, 7), is Savoy's, and (6, 6), east of it, Milan's.
func _duel() -> Game:
	var g := MovesFixture.duel()
	g.wars[0].start_turn = g.turn - 1
	g.version += 1
	return g


func _home(g: Game) -> Army:
	return MovesFixture.named(g, MovesFixture.NAME_HOME)


func _south(g: Game) -> Vector2i:
	return _neighbour_of_owner(g, _home(g).hex, SAV, Vector2i(0, 1))


## The neighbour of `hex` held by `tag`: `prefer` as an offset when it is one, else the first.
func _neighbour_of_owner(g: Game, hex: Vector2i, tag: StringName, prefer: Vector2i = Vector2i.ZERO) -> Vector2i:
	if prefer != Vector2i.ZERO and Territory.owner_tag(g, hex + prefer) == tag:
		return hex + prefer
	for d: int in 6:
		var n := g.map.neighbour(hex, d)
		if g.map.is_land(n) and Territory.owner_tag(g, n) == tag:
			return n
	return Army.NO_HEX


## A Milanese army on `hex`, seen by Savoy.
func _foe(g: Game, hex: Vector2i) -> Army:
	var a := ArmyFixture.army(g, MLO, hex, 0, 2)
	g.version += 1
	Sight.refresh(g)
	assert_true(Sight.sees(g, SAV, hex), "Savoy sees the Milanese army")
	return a


## Starts `g` on a map scene with the orders' questions kept in _asked, the army `army` selected.
func _open(g: Game, army: Army) -> void:
	_game = g
	Session.start_game(g)
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()
	var orders := _armies().orders()
	orders.settings = _settings
	orders.ask = func(screen: Screen) -> void:
		add_child_autofree(screen)
		_asked.append(screen as Confirm)
	_armies().said.connect(func(text: String, tone: StringName) -> void: _said.append([text, tone]))
	_armies().battle_opened.connect(func(record: int) -> void: _battles.append(record))
	_scene.refused.connect(func(reason: String) -> void: _reasons.append(reason))
	assert_true(_armies().select_army(army.id))


func _armies() -> MapArmies:
	return _scene.get_node("MapArmies") as MapArmies


## The state an order may change: the digest, the version, the actions done and the army's hex.
func _state(army_id: int) -> Array:
	var a := Armies.by_id(_game, army_id)
	return [_game.digest(), _game.version, Session.unsaved_actions, a.hex, a.order, a.points]


func _kinds(risks: Array) -> Array:
	var out: Array = []
	for r: Dictionary in risks:
		out.append(r["kind"])
	return out


func _body(screen: Confirm) -> String:
	return " | ".join(AppFlowHelpers.labels_under(screen))


func _answer(choice: StringName) -> void:
	var screen: Confirm = _asked.back()
	screen.button_for(choice).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame


## One question about the army's order, its title and one line for each risk of the preview; nothing done yet.
func _expect_asked(army: Army, risks: Array, before: Array) -> void:
	assert_eq(_asked.size(), 1, "P: a risky order asks once")
	assert_eq(_state(army.id), before, "P: nothing is done before the answer")
	assert_true(_said.is_empty(), "and nothing is said")
	if _asked.is_empty():
		return
	var words := _body(_asked[0])
	assert_string_contains(words, ("Move the %s?" % army.name).to_upper())  # the sheet writes its title in capitals
	var lines: Array[String] = []
	for r: Dictionary in risks:
		lines.append(str(r["text"]))
	assert_string_contains(words, "\n".join(lines))
	assert_eq(_asked[0].button_for(&"confirm").text, "Move")
	assert_eq(_asked[0].button_for(&"cancel").text, "Cancel")


func test_a_march_into_a_seen_enemy_army_asks_then_fights_on_move() -> void:
	var g := _duel()
	var army := _home(g)
	var goal := _south(g)
	_foe(g, goal)
	_open(g, army)
	var risks := MovePreview.to(g, SAV, army.id, goal)["risks"] as Array
	assert_eq(_kinds(risks)[0], MovePreview.RISK_BATTLE, "the first risk is the battle: %s" % str(risks))
	var before := _state(army.id)
	_armies().command(goal)
	_expect_asked(army, risks, before)
	assert_true(_battles.is_empty(), "no battle before the answer")
	var id := army.id
	await _answer(&"confirm")
	assert_eq(Session.unsaved_actions, int(before[2]) + 1, "Move gives the order, once")
	assert_eq(_battles, [BattleView.latest_of(g, SAV)] as Array[int], "the battle the walk fought is told")
	assert_eq(_said.size(), 1, "one toast")
	assert_string_contains(str(_said[0][0]), "attacks at %s" % Words.place(g, goal))
	assert_eq(_said[0][1], MovePreview.TONE_WARN)
	var left := Armies.by_id(g, id)
	assert_true(left == null or left.points == 0, "the army's season is over")


func test_cancel_and_esc_change_nothing_and_say_nothing() -> void:
	var g := _duel()
	var army := _home(g)
	var goal := _south(g)
	_foe(g, goal)
	_open(g, army)
	var before := _state(army.id)
	_armies().command(goal)
	await _answer(&"cancel")
	assert_eq(_state(army.id), before, "P: Cancel changes nothing")
	_armies().command(goal)
	assert_eq(_asked.size(), 2, "the next order asks again")
	assert_true(_asked[1].back(), "Esc answers the question")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_state(army.id), before, "Esc is Cancel")
	assert_true(_said.is_empty(), "P: Cancel toasts nothing")
	assert_true(_reasons.is_empty())
	assert_true(_battles.is_empty())


func test_a_march_into_land_at_war_asks() -> void:
	var g := _duel()
	var army := _home(g)
	var goal := _neighbour_of_owner(g, army.hex, MLO, Vector2i(1, 0))
	_open(g, army)
	var risks := MovePreview.to(g, SAV, army.id, goal)["risks"] as Array
	assert_true(_kinds(risks).has(MovePreview.RISK_ENEMY_LAND), "the march enters Milan's land: %s" % str(risks))
	var before := _state(army.id)
	_armies().command(goal)
	_expect_asked(army, risks, before)
	await _answer(&"confirm")
	assert_eq(Armies.by_id(g, army.id).hex, goal, "Move walks the army")
	assert_string_contains(str(_said[0][0]), "walks to %s" % Words.place(g, goal))


func test_a_march_that_ends_out_of_supply_asks() -> void:
	var g := _duel()
	var army := _home(g)
	var goal := Army.NO_HEX
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if hex != army.hex and ImproveRules.hex_distance(hex, army.hex) <= 3 \
				and _kinds(MovePreview.to(g, SAV, army.id, hex)["risks"] as Array) == [MovePreview.RISK_OUT_OF_SUPPLY]:
			goal = hex
			break
	assert_ne(goal, Army.NO_HEX, "a hex whose one risk is the supply")
	_open(g, army)
	var risks := MovePreview.to(g, SAV, army.id, goal)["risks"] as Array
	var before := _state(army.id)
	_armies().command(goal)
	_expect_asked(army, risks, before)


func test_a_plain_march_and_a_halt_ask_nothing() -> void:
	var g := _duel()
	var army := _home(g)
	var goal := _south(g)
	_open(g, army)
	assert_true((MovePreview.to(g, SAV, army.id, goal)["risks"] as Array).is_empty(), "a plain march")
	_armies().command(goal)
	assert_eq(_asked.size(), 0, "P: a plain march is one click")
	assert_eq(army.hex, goal, "walked in the click")
	assert_eq(_said.size(), 1)
	assert_eq(str(_said[0][0]), "The %s walks to %s: %d of %d move points left." % [army.name, Words.place(g, goal),
		army.points, Allowance.full(g, army)])
	assert_eq(_said[0][1], MovePreview.TONE_PLAIN)
	MovesFixture.standing(g, army, _neighbour_of_owner(g, goal, SAV))
	_armies().command(goal)
	assert_eq(_asked.size(), 0, "a halt asks nothing")
	assert_eq(army.order, Army.ORDER_NONE)
	assert_string_contains(str(_said.back()[0]), "holds at")


func test_the_setting_off_asks_nothing() -> void:
	var g := _duel()
	var army := _home(g)
	var goal := _south(g)
	_foe(g, goal)
	assert_true(_settings.set_value(MoveOrders.SETTING, false))
	_open(g, army)
	var before := Session.unsaved_actions
	_armies().command(goal)
	assert_eq(_asked.size(), 0, "P: the setting off asks nothing")
	assert_eq(Session.unsaved_actions, before + 1, "the order is given at once")
	assert_eq(_battles.size(), 1)


## A halted march into Milan's land: R and the army panel's Continue both ask; Move walks on.
func test_continue_of_a_risky_march_asks_from_r_and_from_the_panel() -> void:
	var g := _duel()
	var army := _home(g)
	var goal := _neighbour_of_owner(g, army.hex, MLO, Vector2i(1, 0))
	assert_true(MovesFixture.standing(g, army, goal))
	assert_true(bool(g.act("halt", {"army": army.id, "tag": SAV})["ok"]))
	_open(g, army)
	var risks := MoveOrders.continue_risks(g, SAV, army.id)
	assert_true(_kinds(risks).has(MovePreview.RISK_ENEMY_LAND), str(risks))
	var before := _state(army.id)
	assert_true(_armies().continue_march())
	_expect_asked(army, risks, before)
	await _answer(&"cancel")
	assert_eq(_state(army.id), before, "Cancel keeps the march halted")
	assert_true(_said.is_empty())
	var panel := (load("res://shell/panels/army_panel.tscn") as PackedScene).instantiate() as ArmyPanel
	panel.theme = KitTheme.load_for(1.0)
	add_child_autofree(panel)
	panel.show_army(army.id)
	await get_tree().process_frame
	panel.action_button("continue_march").pressed.emit()
	assert_eq(_asked.size(), 2, "the panel's Continue asks too")
	assert_eq(_state(army.id), before, "P: the panel acted before the answer")
	await _answer(&"confirm")
	assert_eq(Armies.by_id(g, army.id).hex, goal, "Move walks on")
	assert_string_contains(str(_said.back()[0]), "walks to %s" % Words.place(g, goal))


## An army of Savoy's before a Milanese fortress with a garrison.
func _at_fortress(g: Game) -> Array:
	var fort := Army.NO_HEX
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if Occupation.fortress_level(g, hex) > 0 and Occupation.garrison_of(g, hex) > 0 \
				and Occupation.controller_tag(g, hex) == MLO:
			fort = hex
			break
	assert_ne(fort, Army.NO_HEX, "a Milanese fortress with a garrison")
	var a := ArmyFixture.army(g, SAV, fort, 0, 4)
	a.name = "Storming fixture"
	g.version += 1
	Sight.refresh(g)
	return [a, fort]


func test_a_storm_asks_about_its_battle() -> void:
	var g := _duel()
	var set_up := _at_fortress(g)
	var army: Army = set_up[0]
	var fort: Vector2i = set_up[1]
	_open(g, army)
	var risks := MoveOrders.storm_risks(g, SAV, army.id, fort)
	assert_eq(_kinds(risks), [MovePreview.RISK_BATTLE], "the storm's risk is its battle")
	assert_eq(str(risks[0]["text"]), "This opens a battle at %s." % Words.place(g, fort))
	var before := _state(army.id)
	assert_true(_armies().storm(army.id, fort), "the storm is accepted")
	_expect_asked(army, risks, before)
	await _answer(&"confirm")
	assert_eq(Session.unsaved_actions, int(before[2]) + 1)
	assert_eq(_battles.size(), 1, "the assault is fought at once")
	assert_string_contains(str(_said.back()[0]), "attacks at %s" % Words.place(g, fort))


func test_a_storm_too_far_for_this_season_names_no_battle() -> void:
	var g := _duel()
	var army := _home(g)
	var fort: Vector2i = _at_fortress(g)[1]
	var leg := MovePreview.leg_of(g, SAV, army.id, fort)
	assert_ne(leg["end"], fort, "the fortress is more than this season's walk away")
	assert_false(_kinds(MoveOrders.storm_risks(g, SAV, army.id, fort)).has(MovePreview.RISK_BATTLE), "no battle this season")


func test_a_refused_storm_says_why_and_asks_nothing() -> void:
	var g := _duel()
	var army := _home(g)
	var goal := _south(g)
	_open(g, army)
	assert_false(_armies().storm(army.id, goal))
	assert_eq(_asked.size(), 0)
	assert_eq(_reasons, [str(Session.check("storm", {"army": army.id, "goal": goal})["reason"])] as Array[String])


func test_an_answer_after_the_game_changed_orders_nothing() -> void:
	var g := _duel()
	var army := _home(g)
	var goal := _south(g)
	_foe(g, goal)
	_open(g, army)
	_armies().command(goal)
	var other := _duel()
	Session.start_game(other)
	var digest := other.digest()
	await _answer(&"confirm")
	assert_eq(other.digest(), digest, "the question of the old game orders nothing in the new one")
	assert_eq(Session.unsaved_actions, 0)


func test_an_order_lands_a_live_walk_first() -> void:
	var g := _duel()
	var army := _home(g)
	var goal := _south(g)
	_open(g, army)
	var skipped: Array = []
	_armies().orders().live_skip = func() -> bool:
		skipped.append(Session.unsaved_actions)
		return true
	_armies().command(goal)
	assert_eq(skipped, [0], "the skip comes before the act (R49)")


## An attack whose army is gone afterwards still says what it did (MoveWords reads no army).
func test_the_words_of_an_army_lost_in_its_battle() -> void:
	var g := _duel()
	var walk := {"battle": 0, "to": _south(g), "stopped": &"battle"}
	var words := MoveOrders.words(g, SAV, 99999, "Army of Turin", walk)
	assert_eq(words["text"], "The Army of Turin attacks at %s: a battle." % Words.place(g, walk["to"]))
	assert_eq(words["tone"], MovePreview.TONE_WARN)


func test_a_storm_that_only_stands_says_it_marches_to_storm() -> void:
	var g := _duel()
	var army := _home(g)
	var words := MoveOrders.storm_words(g, SAV, army.id, army.name, {"stopped": &"no_points"}, _south(g), "Even")
	assert_eq(words["text"], "The %s marches to storm %s: Even." % [army.name, Words.place(g, _south(g))])


# ----- the App ------------------------------------------------------------------------------------------------------------


## The App as Savoy with a war a season old, a Savoyard army on (5, 6) and a Milanese one south of it; the army selected.
func _app(movement: String) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	add_child_autofree(vp)
	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.cli_args_override = PackedStringArray(["--new-game", "--country=SAV", "--seed=1480"])
	var s := Settings.new("macOS", false)  # motion on: the live walk plays at the movement speed
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("game/autosave", "off")
	s.set_value("game/movement", movement)
	app.set_settings_override(s)
	vp.add_child(app)
	var up := func() -> bool: return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting()
	assert_true(await _wait_until(up), "the game is up")
	await _frames(3)
	_game = Session.game
	WarFixture.at_war(_game, SAV, MLO).start_turn = _game.turn - 1
	var home := Vector2i(5, 6)
	var south := _neighbour_of_owner(_game, home, SAV, Vector2i(0, 1))
	var army := ArmyFixture.army(_game, SAV, home, 0, 2)
	army.name = "Attacking fixture"
	_foe(_game, south)
	_scene = app.map_scene()
	_armies().sync()
	assert_true(_armies().select_army(army.id))
	await _frames(2)
	return {"vp": vp, "app": app, "army": army, "goal": south}


func _frames(count: int) -> void:
	for _i: int in count:
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


## Gives the attack through the App and answers its question with Move.
func _attack(env: Dictionary) -> void:
	var app := env["app"] as App
	_armies().command(env["goal"] as Vector2i)
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is Confirm, 60), "P: the App asks first")
	(app.stack().top() as Confirm).button_for(&"confirm").pressed.emit()


func test_the_app_asks_and_cancel_toasts_nothing() -> void:
	var env := await _app("instant")
	var app := env["app"] as App
	var army: Army = env["army"]
	var before := _state(army.id)
	var toasts := AppFlowHelpers.toasts(app)
	_armies().command(env["goal"] as Vector2i)
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is Confirm, 60), "the question is on the stack")
	assert_string_contains(_body(app.stack().top() as Confirm), "MOVE THE ATTACKING FIXTURE?")
	_key(env["vp"] as SubViewport, KEY_ESCAPE)
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0), "Esc cancels")
	await _frames(3)
	assert_eq(_state(army.id), before)
	assert_eq(AppFlowHelpers.toasts(app), toasts, "P: Cancel toasts nothing")
	assert_null(app.requests().war.dock())


func test_the_dock_opens_only_after_the_live_walk() -> void:
	var env := await _app("slow")
	var app := env["app"] as App
	var replay := app.requests().replay
	await _attack(env)
	assert_true(await _wait_until(func() -> bool: return replay.live_active(), 30), "the walk plays live")
	assert_null(app.requests().war.dock(), "P: no dock while the walk plays")
	var frames := 0
	while replay.live_active() and frames < 3000:
		assert_null(app.requests().war.dock(), "P: the dock opened before the walk ended")
		await get_tree().process_frame
		frames += 1
	assert_false(replay.live_active(), "the walk ends by its clock")
	assert_gt(frames, 1, "it took frames to play")
	assert_not_null(app.requests().war.dock(), "the dock opens when the walk has played")
	if app.requests().war.dock() != null:
		assert_eq(app.requests().war.dock().shown_record(), BattleView.latest_of(_game, SAV))


func test_skipping_the_live_walk_opens_the_dock() -> void:
	var env := await _app("slow")
	var app := env["app"] as App
	var replay := app.requests().replay
	await _attack(env)
	assert_true(await _wait_until(func() -> bool: return replay.live_active(), 30), "the walk plays live")
	assert_null(app.requests().war.dock())
	_key(env["vp"] as SubViewport, KEY_ESCAPE)
	await _frames(2)
	assert_false(replay.live_active(), "Esc skips the walk")
	assert_not_null(app.requests().war.dock(), "and the dock opens")


func test_at_instant_speed_the_dock_opens_at_once() -> void:
	var env := await _app("instant")
	var app := env["app"] as App
	await _attack(env)
	assert_true(await _wait_until(func() -> bool: return app.requests().war.dock() != null, 10), "no walk plays: the dock opens")
	assert_eq(app.stack().count(), 1, "the question is gone, the dock is there")
	assert_true(AppFlowHelpers.has_toast(app, "attacks at"))


func test_the_apps_setting_off_asks_nothing() -> void:
	var env := await _app("instant")
	var app := env["app"] as App
	app.settings().set_value(MoveOrders.SETTING, false)
	var before := Session.unsaved_actions
	_armies().command(env["goal"] as Vector2i)
	assert_eq(Session.unsaved_actions, before + 1, "the order is given at once")
	await _frames(2)
	assert_false(app.stack().top() is Confirm)


## In the App the real pointer on a token's points mark brings its words up on the HUD's hover card.
func test_the_apps_pointer_on_a_points_mark_shows_its_words() -> void:
	var env := await _app("instant")
	var app := env["app"] as App
	var army: Army = env["army"]
	_armies().clear_army()
	app.settings().set_value("accessibility/tooltip_delay", "short")
	_scene.select_hex(MapScene.NO_HEX)
	_scene.camera_rig().look_at(_scene.view().centre_of(army.hex), 1.0, true)
	await _frames(5)
	var token := _armies().tokens().token_at(army.hex, SAV)
	var at := token.get_global_transform_with_canvas() * ArmyToken.POINTS_BAR.get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	(env["vp"] as SubViewport).push_input(motion)
	var words := "%d of %d move points left this season" % [army.points, Allowance.full(_game, army)]
	var hover := app.hud().map_hover()
	var shown := func() -> bool: return hover.is_card_visible() and (hover.card().get_node("VBox/Title") as Label).text == words
	assert_true(await _wait_until(shown, 600), "the mark's words show under the pointer")


## The line that moves are final shows in the App's key hints while an army is selected, inside their room.
func test_the_key_hints_say_moves_are_final_while_an_army_is_selected() -> void:
	var env := await _app("instant")
	var app := env["app"] as App
	var hints := app.hud().key_hints()
	assert_eq(hints.note_text(), KeyHints.MOVES_NOTE)
	await _frames(3)
	assert_true(hints.note_label().is_visible_in_tree(), "the line is shown at 1280 x 720")
	_armies().clear_army()
	await _frames(2)
	assert_eq(hints.note_text(), "", "gone with the selection")
