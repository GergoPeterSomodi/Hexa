## The moves App flow (docs/architecture/moves-build-spec.md done-when 2 and section 5; MV18, issue #432): north Italy's 1480
## game as Savoy through the App headless, with real pointer and key events. The season of section 5: an army selected (the
## points on its token and panel), the move card's walk, a right click that walks at once, a march past the season's points
## kept as a standing march, a walk that stops on sight (Halted, Continue), F5 and F9 in the middle of the season, a battle
## in the act with its question and its dock after the live walk, End season (the standing march walks only at the end of the
## next season) and End season with the computer playing (its walk and battle in its turn, the replay, the report's army
## lines). A second test is the multi-leg march (R58 to R72): Shift+right click and V order the path, the preview's legs, Esc on the
## stops, a right click, the walk past a stop, F5 and F9 with a stop left, and the standing leg that passes it.
## The places are the map's (Novara is (7, 8)). The Milanese armies are made by a state edit, as the M7 flow's.
## A sighted halt leaves the enemy two hexes off, and the zone of control stops a walk beside it (R25), so the attack of
## section 5 comes a season later, from the hex beside it. Over a war target the hover card is M7's odds card: this season's
## walk and its risks are read from the preview and from the question the order asks.
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")
const SAV := &"SAV"
const MLO := &"MLO"
const TURIN := Vector2i(5, 9)
const CHIVASSO := Vector2i(5, 10)
const VERCELLI := Vector2i(6, 9)
const NOVARA := Vector2i(7, 8)
const BESIDE_COMO := Vector2i(7, 7)
const COMO := Vector2i(8, 6)
const PAVIA := Vector2i(10, 9)
const NICE := Vector2i(4, 16)
const CUNEO := Vector2i(5, 13)
const WEST_OF_CHIVASSO := Vector2i(4, 10)
const TOKEN_LIFT := Vector2(0.0, -25.0)

var _prev_game: Game = null
var _old_save_dir: String = ""
var _old_lock_path: String = ""
## The walks heard: {tag, army, path, now, season (heard while a season ran)}.
var _walks: Array[Dictionary] = []


func before_each() -> void:
	Session.ai_enabled = false  # a passive world until the last season of section 5
	Bindings.reset_defaults()
	_walks = []
	_prev_game = Session.game
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_flow_moves_saves"
	RunLock.path = "user://test_flow_moves_running.lock"
	Events.unit_moved.connect(_on_unit_moved)


func after_each() -> void:
	Events.unit_moved.disconnect(_on_unit_moved)
	Session.end_game()
	for slot: String in SaveFile.SLOTS + SaveFile.AUTO_SLOTS:
		SaveFile.remove(slot, Session.save_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.save_dir))
	RunLock.clear()
	Session.save_dir = _old_save_dir
	RunLock.path = _old_lock_path
	Session.game = _prev_game
	Session.ai_enabled = true
	Bindings.reset_defaults()
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)


func _on_unit_moved(tag: StringName, army: int, path: Array[Vector2i], _seen: PackedByteArray, _ticks: PackedInt32Array,
		now: bool) -> void:
	_walks.append({"tag": tag, "army": army, "path": path.duplicate(), "now": now, "season": Session.in_season()})


# ----- the App -------------------------------------------------------------------------------------------------------------


func _wait_frames(frames: int = 3) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame


func _wait_until(done: Callable, limit: int = 3000) -> bool:
	var frames := 0
	while not bool(done.call()) and frames < limit:
		await get_tree().process_frame
		frames += 1
	return bool(done.call())


## The App as Savoy, the movement replay at Slow (so a live walk takes frames), no autosave.
func _savoy() -> Dictionary:
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
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("game/autosave", "off")
	s.set_value("graphics/season_change", "instant")
	s.set_value("game/season_report", "full")
	s.set_value("game/movement", "slow")
	s.set_value("accessibility/reduce_motion", false)
	app.set_settings_override(s)
	vp.add_child(app)
	assert_true(await _wait_until(func() -> bool:
		return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting()), "the game is up")
	await _wait_frames(3)
	return {"vp": vp, "app": app}


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


func _screen_of(app: App, hex: Vector2i) -> Vector2:
	var view := app.map_scene().view()
	return view.get_global_transform_with_canvas() * view.centre_of(hex)


## The camera frames `hex` (it lands in the middle of the viewport, clear of the panels).
func _frame(app: App, hex: Vector2i) -> void:
	app.map_scene().frame_at(app.map_scene().view().centre_of(hex), 1.0)
	await _wait_frames(4)


func _motion(vp: SubViewport, pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	vp.push_input(ev)


func _click_at(vp: SubViewport, pos: Vector2, button: MouseButton, shift: bool = false) -> void:
	_motion(vp, pos)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.position = pos
		ev.global_position = pos
		ev.shift_pressed = shift
		ev.pressed = pressed
		vp.push_input(ev)


func _click_hex(vp: SubViewport, app: App, hex: Vector2i, button: MouseButton, shift: bool = false) -> void:
	await _frame(app, hex)
	_click_at(vp, _screen_of(app, hex), button, shift)
	await _wait_frames(1)


## The pointer rests on `hex`; the move card of it, once it is up.
func _hover(vp: SubViewport, app: App, hex: Vector2i) -> MoveCard:
	await _frame(app, hex)
	var at := _screen_of(app, hex)
	_motion(vp, at + Vector2(6.0, 0.0))
	await _wait_frames(1)
	_motion(vp, at)
	var move := app.hud().map_hover().move_card()
	var odds := app.hud().odds_card()
	var title := Words.place(Session.game, hex)
	assert_true(await _wait_until(func() -> bool: return _titled(move, title) or _titled(odds, title), 300),
		"the card of %s (move '%s', odds '%s')" % [title, move.title_text(), odds.title_text()])
	return odds if odds.is_open() else move


func _titled(card: MoveCard, title: String) -> bool:
	return card.is_open() and card.title_text() == title


func _armies_node(app: App) -> MapArmies:
	return app.map_scene().get_node("MapArmies") as MapArmies


func _army(id: int) -> Army:
	return Armies.by_id(Session.game, id)


## A left click on the army's token selects it.
func _select(vp: SubViewport, app: App, id: int) -> void:
	_armies_node(app).clear_army()
	await _frame(app, _army(id).hex)
	var token := _armies_node(app).tokens().token_at(_army(id).hex, SAV)
	assert_not_null(token, "the army has a token")
	if token == null:
		return
	_click_at(vp, token.get_global_transform_with_canvas() * TOKEN_LIFT, MOUSE_BUTTON_LEFT)
	await _wait_frames(2)
	assert_eq(_armies_node(app).selected_army(), id, "the click on the token selects the army")


func _panel_words(app: App) -> String:
	return " | ".join(AppFlowHelpers.labels_under(app.hud().army_panel()))


func _mark(app: App, id: int) -> StringName:
	var token := _armies_node(app).tokens().token_at(_army(id).hex, SAV)
	return token.points_state() if token != null else &"no token"


func _toast_with(app: App, part: String) -> void:
	assert_true(AppFlowHelpers.has_toast(app, part), "the toast '%s' in: %s" % [part, str(AppFlowHelpers.toasts(app))])


func _lines(card: MoveCard) -> String:
	return " | ".join(card.line_texts())


## The preview's lines for the army at `hex` (a war target's hover card is the odds card, which shows its own lines).
func _preview_lines(id: int, hex: Vector2i) -> String:
	var out := PackedStringArray()
	for line: Array in MovePreview.to(Session.game, SAV, id, hex)["lines"] as Array:
		out.append(str(line[0]))
	return " | ".join(out)


## The top screen is a question: its words are returned and `choice` pressed.
func _answer(app: App, choice: StringName) -> String:
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is Confirm, 120), "a question is asked")
	if not (app.stack().top() is Confirm):
		return ""
	var screen := app.stack().top() as Confirm
	var words := " | ".join(AppFlowHelpers.labels_under(screen))
	screen.button_for(choice).pressed.emit()
	assert_true(await _wait_until(func() -> bool: return app.stack().top() != screen, 120), "the question closes")
	await _wait_frames(1)
	return words


## The live walk plays frame after frame without touching the game, and ends.
func _watch_live_walk(app: App) -> void:
	var replay := app.requests().replay
	assert_true(replay.live_active(), "the walk plays live")
	var digest := Session.game.digest()
	var version := Session.game.version
	var frames := 0
	while replay.live_active() and frames < 3000:
		assert_eq(Session.game.version, version, "a live walk never changes the version")
		await get_tree().process_frame
		frames += 1
	assert_false(replay.live_active(), "the live walk ends")
	assert_gt(frames, 1, "it took frames")
	assert_eq(Session.game.digest(), digest, "a live walk never changes the digest")


## What of Savoy's armies a save must bring back.
func _army_states() -> Array:
	var out: Array = []
	for a: Army in Armies.of_country(Session.game, SAV):
		out.append([a.id, a.hex, a.points, a.order, a.halt_why, a.halt_text, a.goal, Array(a.route), Array(a.via),
			a.units.size(), a.season_from])
	return out


func _quicksave(vp: SubViewport) -> void:
	_key(vp, KEY_F5)
	assert_true(await _wait_until(func() -> bool:
		return Session.current_slot == SaveRows.QUICK_SLOT and Session.unsaved_actions == 0), "the quicksave is written")


func _quickload(vp: SubViewport, app: App) -> void:
	var before := Session.game
	_key(vp, KEY_F9)
	if await _wait_until(func() -> bool: return app.stack().top() is Confirm or Session.game != before, 120):
		if app.stack().top() is Confirm:
			(app.stack().top() as Confirm).button_for(&"confirm").pressed.emit()
	assert_true(await _wait_until(_loaded.bind(app, before)), "the quicksave loads")
	await _wait_frames(3)


## A game other than `before` is up, with no screen.
func _loaded(app: App, before: Game) -> bool:
	if Session.game == before or app.stack().count() != 0 or app.is_starting():
		return false
	return app.map_scene() != null and not app.map_scene().is_loading()


## Space, the season (a war's alert answered on the way), the report.
func _end_season(vp: SubViewport, app: App) -> void:
	await _wait_until(func() -> bool: return Time.get_ticks_msec() > app.requests().flow.guard_until, 600)
	_key(vp, KEY_SPACE)
	var frames := 0
	while not (app.stack().top() is SeasonReport) and frames < 6000:
		if app.stack().top() is Confirm:
			var alert := app.stack().top() as Confirm
			var button := alert.button_for(&"report")
			if button != null:
				button.pressed.emit()
		await get_tree().process_frame
		frames += 1
	assert_true(app.stack().top() is SeasonReport, "the report opens")


func _close_report(vp: SubViewport, app: App) -> void:
	_key(vp, KEY_SPACE)
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0), "the report closes")
	await _wait_frames(2)


func _console(app: App, line: String) -> void:
	var out := DevCommands.run(line, app.context())
	assert_true(out.begins_with("Done"), "%s: %s" % [line, out])


func _give_goods() -> void:
	var c := Countries.by_tag(Session.game, SAV)
	Session.dev_money(SAV, 1500 - c.treasury)
	for good: StringName in [&"iron", &"horses"]:
		var id := Session.game.defs.good_id(good)
		Session.dev_goods(SAV, id, 20 - c.stock[id])


## A Milanese army of `companies` pikemen put on `hex` by a state edit.
func _milan(hex: Vector2i, companies: int) -> Army:
	var a := ArmyFixture.army(Session.game, MLO, hex, 0, companies, 0)
	Session.game.version += 1
	Sight.refresh(Session.game)
	return a


# ----- section 5: one season and the next from the player's chair ------------------------------------------------------------


## Spring: the war, the two armies raised and a Milanese army out of sight; a season passes (the muster; fair warning is
## over). Returns {turin, second, foe} army ids.
func _setup_war(vp: SubViewport, app: App) -> Dictionary:
	_give_goods()
	_console(app, "declare MLO")
	_console(app, "raise 5 9 pikemen 1")
	_console(app, "raise 5 9 knights 1")  # sight 2: pikemen alone (sight 1) meet an unseen army only in its zone of control
	_console(app, "raise 5 10 pikemen 2")
	var turin := Armies.at(Session.game, TURIN)[0].id
	var second := Armies.at(Session.game, CHIVASSO)[0].id
	var foe := _milan(COMO, 1).id
	await _end_season(vp, app)
	await _close_report(vp, app)
	assert_eq(_army(turin).units.size(), 2, "pikemen and knights in one army")
	assert_false(Sight.sees(Session.game, SAV, COMO), "Milan's army at Como is out of sight")
	return {"turin": turin, "second": second, "foe": foe}


## Steps 1 and 2: the selected army shows full points; the card says the walk; the right click walks it in the same act.
func _select_and_walk(vp: SubViewport, app: App, turin: int) -> void:
	var full := Allowance.full(Session.game, _army(turin))
	assert_eq(_army(turin).points, full, "a fresh army")
	await _select(vp, app, turin)
	assert_eq(_mark(app, turin), &"full", "the token's points mark is full")
	assert_true(_panel_words(app).contains("%d of %d left this season" % [full, full]), _panel_words(app))
	var card := await _hover(vp, app, VERCELLI)
	var leg := MovePreview.leg_of(Session.game, SAV, turin, VERCELLI)
	var left := int(leg["points_after"])
	assert_true(_lines(card).contains("Walks 1 hex now: %d of %d move points, %d left." % [int(leg["cost"]), full, left]),
		_lines(card))
	assert_true(_lines(card).contains("In supply."), _lines(card))
	await _click_hex(vp, app, VERCELLI, MOUSE_BUTTON_RIGHT)
	assert_eq(app.stack().count(), 0, "a plain march asks nothing")
	assert_eq(_army(turin).hex, VERCELLI, "the army has walked when the click is done")
	assert_eq(_army(turin).points, left)
	_toast_with(app, "The Army of Turin walks to Vercelli (6, 9): %d of %d move points left." % [left, full])
	await _watch_live_walk(app)
	assert_eq(_mark(app, turin), &"half", "the token's mark shrank")
	assert_true(_panel_words(app).contains("%d of %d left this season" % [left, full]), _panel_words(app))


## A march past the season's points: the first leg now, the rest a standing march.
func _order_a_long_march(vp: SubViewport, app: App, second: int) -> void:
	await _select(vp, app, second)
	var from := _army(second).hex
	var preview := MovePreview.to(Session.game, SAV, second, NICE)
	assert_gt(int(preview["seasons"]), 1, "Nice is more than a season away")
	await _click_hex(vp, app, NICE, MOUSE_BUTTON_RIGHT)
	if app.stack().top() is Confirm:
		await _answer(app, &"confirm")
	var a := _army(second)
	assert_ne(a.hex, from, "the first leg is walked now")
	assert_ne(a.hex, NICE)
	assert_eq(a.order, Army.ORDER_MARCH, "the rest stands")
	assert_eq(a.goal, NICE)
	_toast_with(app, "it marches on to Nice (4, 16) at End turn.")
	await _watch_live_walk(app)


## Step 3: the march toward Pavia asks about its risks, stops when the army at Como comes into sight and keeps its points;
## the panel offers Continue.
func _walk_into_sight(vp: SubViewport, app: App, turin: int) -> void:
	await _select(vp, app, turin)
	var before := _army(turin).points
	var card := await _hover(vp, app, PAVIA)
	assert_true(card is OddsCard, "Pavia is a war target: the odds card")
	assert_true(_lines(card).contains("Besiege"), _lines(card))
	var words := _preview_lines(turin, PAVIA)
	assert_true(words.contains("Walks 4 hexes now: ") and words.contains("its season is over"), words)
	assert_false(words.contains("Como") or _lines(card).contains("Como"), "nothing of the unseen army: " + words)
	await _click_hex(vp, app, PAVIA, MOUSE_BUTTON_RIGHT)
	assert_eq(_army(turin).hex, VERCELLI, "nothing walks before the answer")
	var asked := await _answer(app, &"confirm")
	assert_true(asked.to_upper().contains("MOVE THE ARMY OF TURIN?"), asked)
	assert_true(asked.contains("Enters land held by the Duchy of Milan"), asked)
	var a := _army(turin)
	assert_eq(a.hex, NOVARA, "the walk stops at Novara, on its second step")
	assert_eq(a.halt_why, Movement.WHY_SIGHTED)
	assert_true(a.points > 0 and a.points < before, "points are kept (%d of %d)" % [a.points, before])
	assert_true(Sight.sees(Session.game, SAV, COMO), "the army at Como is in sight now")
	_toast_with(app, "The Army of Turin stops at Novara (7, 8): an army of")
	await _watch_live_walk(app)
	await _select(vp, app, turin)
	assert_true(_panel_words(app).contains("Halted"), _panel_words(app))
	var go_on := app.hud().army_panel().action_button("continue_march")
	assert_true(go_on != null and go_on.is_visible_in_tree() and not go_on.disabled, "Continue is offered")
	var digest := Session.game.digest()
	_press(vp, &"game_continue_march")
	if await _wait_until(func() -> bool: return app.stack().top() is Confirm, 30):
		await _answer(app, &"cancel")
	assert_eq(Session.game.digest(), digest, "Continue asked and cancelled changes nothing")


## F5 with one army walked and halted and one on a standing march; R and Move: the halted army walks on at once, not stopped
## again by the army it has seen (R35); F9 brings the season's middle back, the halt included.
func _save_in_the_season(vp: SubViewport, app: App, turin: int) -> void:
	var digest := Session.game.digest()
	var states := _army_states()
	await _quicksave(vp)
	await _select(vp, app, turin)
	var here := _army(turin).hex
	var points := _army(turin).points
	_press(vp, &"game_continue_march")
	if await _wait_until(func() -> bool: return app.stack().top() is Confirm, 30):
		await _answer(app, &"confirm")
	assert_ne(_army(turin).hex, here, "Continue walks at once")
	assert_lt(_army(turin).points, points, "with the points left")
	assert_eq(_army(turin).halt_why, &"", "and the halt is over")
	assert_ne(Session.game.digest(), digest)
	await _watch_live_walk(app)
	await _quickload(vp, app)
	assert_eq(Session.game.digest(), digest, "F9 gives the game of F5")
	assert_eq(_army_states(), states, "the same armies, points, halts and marches")
	assert_eq(_armies_node(app).selected_army(), -1, "no army stays selected")


## The walk to the hex beside the army at Como: its zone of control holds the army there.
func _march_beside(vp: SubViewport, app: App, turin: int) -> void:
	await _select(vp, app, turin)
	var card := await _hover(vp, app, COMO)
	assert_true(card is OddsCard and _lines(card).contains("Attack"), _lines(card))
	var words := _preview_lines(turin, COMO)
	assert_true(words.contains("Attacks the Duchy of Milan: odds "), words)
	assert_true(words.contains("its season is over"), "two hexes off, this season ends beside it: " + words)
	assert_false(words.contains("This opens a battle"), words)
	await _click_hex(vp, app, BESIDE_COMO, MOUSE_BUTTON_RIGHT)
	if app.stack().top() is Confirm:
		await _answer(app, &"confirm")
	assert_eq(_army(turin).hex, BESIDE_COMO, "a new order to the halted army walks at once")
	assert_eq(_army(turin).order, Army.ORDER_HOLD)
	await _watch_live_walk(app)


## Step 4: the attack asks (Cancel changes nothing); Move walks, fights in the act and opens the dock after the live walk.
func _attack_como(vp: SubViewport, app: App, turin: int) -> void:
	await _select(vp, app, turin)
	var card := await _hover(vp, app, COMO)
	assert_true(card is OddsCard and _lines(card).contains("Attack"), _lines(card))
	assert_true(_preview_lines(turin, COMO).contains("This opens a battle at near Como (8, 6)."), _preview_lines(turin, COMO))
	var digest := Session.game.digest()
	await _click_hex(vp, app, COMO, MOUSE_BUTTON_RIGHT)
	var asked := await _answer(app, &"cancel")
	assert_true(asked.to_upper().contains("MOVE THE ARMY OF TURIN?") and asked.contains("This opens a battle at "), asked)
	assert_eq(Session.game.digest(), digest, "Cancel changes nothing")
	assert_lt(BattleView.latest_of(Session.game, SAV), 0, "nothing is fought")
	await _click_hex(vp, app, COMO, MOUSE_BUTTON_RIGHT)
	await _answer(app, &"confirm")
	var replay := app.requests().replay
	assert_true(await _wait_until(func() -> bool: return replay.live_active(), 30), "the walk plays live")
	var fought := BattleView.latest_of(Session.game, SAV)
	assert_gte(fought, 0, "the battle was fought in the act")
	assert_true(Session.game.battles.is_empty(), "no battle is left open")
	assert_null(app.requests().war.dock(), "no dock while the walk plays")
	_toast_with(app, "The Army of Turin attacks at ")
	assert_not_null(_army(turin), "the army lives")
	assert_eq(_army(turin).points, 0, "the battle took its season")
	await _watch_live_walk(app)
	assert_true(await _wait_until(func() -> bool: return app.requests().war.dock() != null, 60), "the dock opens after the walk")
	if app.requests().war.dock() != null:
		assert_eq(app.requests().war.dock().shown_record(), fought, "at that battle")
	_key(vp, KEY_ESCAPE)
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0), "Esc closes the dock")
	digest = Session.game.digest()
	var states := _army_states()
	await _quicksave(vp)
	await _quickload(vp, app)
	assert_eq(Session.game.digest(), digest, "after a battle in the season: the same game")
	assert_eq(_army_states(), states)


## Step 5: the computer plays. A Milanese army beside the Army of Turin marches on it and fights in its turn; the replay
## plays it and the report names the player's walk of the season; the standing march walks on now.
func _the_computer_answers(vp: SubViewport, app: App, turin: int, second: int) -> void:
	assert_eq(_army(turin).hex, COMO, "the winner stands at Como")
	assert_true(Armies.at(Session.game, BESIDE_COMO).is_empty(), "the hex beside it is free")
	var attacker := _milan(BESIDE_COMO, 8).id
	var second_from := _army(second).hex
	Session.ai_enabled = true
	_walks.clear()
	var states: Array[int] = []
	var pills: Array[String] = []
	app.requests().flow.state_changed.connect(func(state: int) -> void: states.append(state))
	var watch := func() -> void:
		var text := app.hud().busy_pill().text()
		if Session.in_season() and not pills.has(text):
			pills.append(text)
	get_tree().process_frame.connect(watch)
	var latest := BattleView.latest_of(Session.game, SAV)
	await _end_season(vp, app)
	get_tree().process_frame.disconnect(watch)
	Session.ai_enabled = false
	assert_true(pills.any(func(t: String) -> bool: return t.begins_with("Countries are moving")), "the pill: " + str(pills))
	assert_true(states.has(SeasonFlow.State.REPLAY), "the computer's walks are replayed")
	assert_true(_walks.any(func(w: Dictionary) -> bool:
		return w["tag"] == MLO and w["army"] == attacker and bool(w["now"]) and bool(w["season"])),
		"Milan's army walked at once in its turn: " + str(_walks))
	assert_gt(BattleView.latest_of(Session.game, SAV), latest, "and fought the Army of Turin")
	var report := app.stack().top() as SeasonReport
	var words := " | ".join(AppFlowHelpers.labels_under(report))
	assert_true(words.contains("Army of Turin: near Novara (7, 7) → "), "the report's line of the season's walk: " + words)
	assert_true(_army(second).hex == NICE or _army(second).hex != second_from, "the standing march walked on, or is there")
	await _close_report(vp, app)


## Done-when 2 and spec section 5, steps 1 to 5.
func test_a_season_of_moves_through_the_app() -> void:
	var env := await _savoy()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	var made := await _setup_war(vp, app)
	var turin := int(made["turin"])
	var second := int(made["second"])
	await _select_and_walk(vp, app, turin)
	await _order_a_long_march(vp, app, second)
	await _walk_into_sight(vp, app, turin)
	await _save_in_the_season(vp, app, turin)
	await _march_beside(vp, app, turin)
	var second_hex := _army(second).hex
	await _end_season(vp, app)
	# Issue 474 (owner playtest 2026-11-27, moves-build-spec.md R22a): End turn walks the standing march's next leg, with the
	# next season's points.
	assert_ne(_army(second).hex, second_hex, "P: End turn does not move the standing march (issue 474)")
	assert_true(_army(second).hex == NICE or _army(second).order == Army.ORDER_MARCH, "there, or still marching")
	assert_true(_army(second).points < Allowance.full(Session.game, _army(second)), "the leg spent the next season's points")
	await _close_report(vp, app)
	await _attack_como(vp, app, turin)
	await _the_computer_answers(vp, app, turin, second)


# ----- the multi-leg march --------------------------------------------------------------------------------------------------


func _preview_state() -> Array:
	return [Session.game.digest(), Session.game.version, Session.unsaved_actions]


func _has_pin(app: App, pins: Array[Vector2], hex: Vector2i) -> bool:
	return pins.has(app.map_scene().view().centre_of(hex))


## Shift+right click on Cuneo and V near Chivasso order the path at once: the army walks in the first click, the second adds.
func _order_a_path(vp: SubViewport, app: App, army: int) -> void:
	await _select(vp, app, army)
	var before := Session.unsaved_actions
	_walks.clear()
	await _click_hex(vp, app, CUNEO, MOUSE_BUTTON_RIGHT, true)
	assert_eq(Session.unsaved_actions, before + 1, "the first click is the order")
	assert_eq(_army(army).goal, CUNEO)
	assert_ne(_army(army).hex, TURIN, "the first season walks now")
	assert_eq(_walks.size(), 1, "one walk")
	assert_true(bool(_walks[0]["now"]) if not _walks.is_empty() else false)
	await _watch_live_walk(app)
	await _select(vp, app, army)
	await _frame(app, WEST_OF_CHIVASSO)
	_motion(vp, _screen_of(app, WEST_OF_CHIVASSO))
	await _wait_frames(2)
	_press(vp, &"map_waypoint_key")
	await _wait_frames(2)
	assert_eq(Session.unsaved_actions, before + 2, "V orders at the hovered hex: %s" % str(AppFlowHelpers.toasts(app)))
	assert_eq(app.stack().count(), 0, "a plain path asks nothing")
	assert_eq([_army(army).goal, Array(_army(army).via)], [WEST_OF_CHIVASSO, [Session.game.map.index_of(CUNEO)]])


## With Shift held the pointer on a third place: one path with its points pinned, a line a leg and the total. Shift+right click
## there adds it, again there takes it off; Esc lets the army go and keeps its order.
func _preview_the_longer_path(vp: SubViewport, app: App, army: int) -> void:
	var armies := _armies_node(app)
	var before := _preview_state()
	await _select(vp, app, army)
	await _frame(app, VERCELLI)
	var shift := InputEventKey.new()
	shift.keycode = KEY_SHIFT
	shift.physical_keycode = KEY_SHIFT
	shift.shift_pressed = true
	shift.pressed = true
	vp.push_input(shift)
	var at := _screen_of(app, VERCELLI)
	for offset: Vector2 in [Vector2(5.0, 0.0), Vector2.ZERO]:
		var moved := InputEventMouseMotion.new()
		moved.position = at + offset
		moved.global_position = at + offset
		moved.shift_pressed = true
		vp.push_input(moved)
		await _wait_frames(1)
	var card := app.hud().map_hover().move_card()
	assert_true(await _wait_until(func() -> bool: return _lines(card).contains("Whole route: 3 legs"), 300), _lines(card))
	var text := _lines(card).replace("\n", " ")
	for part: String in ["Leg 1: ", " to Cuneo (5, 13): ", "Leg 2: Cuneo (5, 13) to near Chivasso (4, 10): ",
			"Leg 3: near Chivasso (4, 10) to Vercelli (6, 9): ", " move points, ", "there in "]:
		assert_true(text.contains(part), "'%s' in: %s" % [part, text])
	var pins := armies.route_marks().pins()
	assert_eq(pins.size(), 2, "a marker on each point of the path")
	assert_true(_has_pin(app, pins, CUNEO) and _has_pin(app, pins, WEST_OF_CHIVASSO))
	assert_eq(_preview_state(), before, "the preview never changes the game")
	var up := shift.duplicate() as InputEventKey
	up.pressed = false
	up.shift_pressed = false
	vp.push_input(up)
	await _wait_frames(2)
	await _click_hex(vp, app, VERCELLI, MOUSE_BUTTON_RIGHT, true)
	assert_eq(_army(army).goal, VERCELLI, "added")
	assert_eq(_army(army).via.size(), 2)
	await _click_hex(vp, app, VERCELLI, MOUSE_BUTTON_RIGHT, true)
	assert_eq([_army(army).goal, _army(army).via.size()], [WEST_OF_CHIVASSO, 1], "and taken off again")
	before = _preview_state()
	_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	assert_eq(armies.selected_army(), -1, "one Esc lets the army go")
	assert_eq(app.stack().count(), 0, "no menu")
	assert_eq(_preview_state(), before, "and keeps its order")


## A multi-leg march through the App (MV18; R58 to R72).
func test_a_multi_leg_march_through_the_app() -> void:
	var env := await _savoy()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	_give_goods()
	_console(app, "raise 5 9 pikemen 2")
	var army := Armies.at(Session.game, TURIN)[0].id
	await _end_season(vp, app)
	await _close_report(vp, app)
	await _order_a_path(vp, app, army)
	await _preview_the_longer_path(vp, app, army)
	await _select(vp, app, army)
	var armies := _armies_node(app)
	await _frame(app, TURIN)
	var stored := armies.stored_marks()
	assert_true(stored.is_thin(), "the stored route is drawn thin")
	assert_eq(stored.pins().size(), 1, "one marker: the point still ahead")
	assert_true(_has_pin(app, stored.pins(), CUNEO))
	assert_true(_panel_words(app).contains("Marching to (4, 10) near Chivasso by Cuneo (5, 13)"), _panel_words(app))
	await _save_with_a_stop_left(vp, app, army)
	await _walk_on_past_the_stop(vp, app, army)


func _save_with_a_stop_left(vp: SubViewport, app: App, army: int) -> void:
	var digest := Session.game.digest()
	var states := _army_states()
	await _quicksave(vp)
	await _select(vp, app, army)
	await _click_hex(vp, app, _army(army).hex, MOUSE_BUTTON_RIGHT)  # halt
	assert_ne(Session.game.digest(), digest)
	await _quickload(vp, app)
	assert_eq(Session.game.digest(), digest, "F9 gives the game with the stop left")
	assert_eq(_army_states(), states)
	assert_eq(_army(army).via.size(), 1, "the stop is kept in the save")


## The next ends of a season: the first walks the standing leg (issue 474, R22a), and the march passes the stop.
func _walk_on_past_the_stop(vp: SubViewport, app: App, army: int) -> void:
	var here := _army(army).hex
	await _end_season(vp, app)
	await _close_report(vp, app)
	assert_ne(_army(army).hex, here, "P: the End turn after the order walks nothing (issue 474)")
	for _season: int in 4:
		await _end_season(vp, app)
		await _close_report(vp, app)
		if _army(army).via.is_empty():
			break
	assert_ne(_army(army).hex, here, "the standing march walked on")
	assert_true(_army(army).via.is_empty(), "the stop is passed")
	await _select(vp, app, army)
	assert_eq(_armies_node(app).stored_marks().pins().size(), 0, "and its marker is gone")
