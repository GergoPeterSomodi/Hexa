## The M6 part of the UI monkey (test_ui_monkey.gd extends this, which extends MonkeyM5): the armies' inputs (m6-build-spec.md
## sections 6 and 9). Key 6 (the Supply mode and its legend); a click on an army's token, or Tab, selects an army; a right click,
## O, R and the army panel's Hold, Continue, Split, Join and Disband (with its Confirm); the Raise tab and the console's `raise`;
## the hex menu (O on an own hex with no army selected); the Military page; End season with its replay, skipped by Space, Esc or
## a click; F5 and F9. Invariants: the army panel shows exactly while an own army is selected; no order is accepted while the
## replay runs (the digest, the version and the stores stay); men and people add up the same before and after a raise, a split,
## a merge or a disband (none of them ends a season); no army of yours is selected after a load. The Supply legend and the
## treasury and stock checks are MonkeyM4's, which already name Supply. Split out of the monkey like MonkeyM5.
class_name MonkeyM6
extends MonkeyM5

## An M6 action a seed must do runs from this step on when its counter is still 0 (after the M5 ones).
const FORCE_M6_STEP := 300
## The M6 counters a seed must raise above 0 (so its invariants cannot pass empty).
const M6_REQUIRED: Array[String] = [
	"m6_supply_keys", "m6_selects", "m6_orders", "m6_panel_actions", "m6_raises", "m6_hex_menus", "m6_military_pages",
	"m6_replays", "m6_replay_blocked", "m6_file_keys", "m6_checks",
]
## The season flow's guard after a report closes (SeasonFlow.GUARD_MS, a double Space); an End season waits this long.
const GUARD_MSEC := 500
## The kinds the console's `raise` takes (their keys).
const CONSOLE_KINDS: Array[String] = ["pikemen", "crossbowmen", "knights", "bombards"]
## The Military page's buttons the monkey presses (their texts; PageMilitary's).
const MILITARY_BUTTONS: Array[String] = ["Look there", "Show on the map"]
## The M6 actions are on (a country game with the armies).
var _m6: bool = false


## The next M6 action, by the dice. During the replay only the replay's rules are tried.
func _m6_step(rng: Rng, vp: SubViewport, app: App) -> void:
	if _m6_replaying(app):
		await _m6_during_replay(rng, vp, app)
		return
	if not _m4_ready(app):
		return
	_m4_note("m6")
	match rng.randi_range(0, 13):
		0:
			await _m6_supply_key(rng, vp, app)
		1, 2:
			await _m6_select(rng, vp, app)
		3, 4:
			await _m6_order(rng, vp, app)
		5, 6:
			await _m6_panel(rng, vp, app)
		7:
			await _m6_raise(rng, vp, app, false)
		8:
			await _m6_hex_menu(rng, vp, app)
		9:
			await _m6_military(rng, vp, app)
		10, 11:
			await _m6_end(rng, vp, app)
		12:
			await _m6_file(rng, vp, app)
		_:
			await _m6_raise(rng, vp, app, true)


## From FORCE_M6_STEP on, the first M6 action whose counter is still 0 (one a step, so a seed never passes empty). With no army of
## yours, a raise comes first: the money is topped up and the console's `raise` tried on each step until one stands.
func _m6_force(rng: Rng, vp: SubViewport, app: App) -> void:
	if not _m4_ready(app):
		if app.stack().count() > 0 and not _m6_replaying(app):
			await _m6_clear(vp, app)  # the screens the random steps opened (a report, a Confirm, the help) block the forced ones
		return
	if Armies.of_country(Session.game, Session.player_tag()).is_empty():
		await _m6_raise(rng, vp, app, true)
	elif int(_n["m6_supply_keys"]) == 0:
		await _m6_supply_key(rng, vp, app)
	elif int(_n["m6_selects"]) == 0:
		await _m6_select(rng, vp, app)
	elif int(_n["m6_orders"]) == 0 or (int(_n["m6_replays"]) == 0 and not _m6_has_march()):
		await _m6_march(rng, vp, app)
	elif int(_n["m6_panel_actions"]) == 0:
		await _m6_panel(rng, vp, app, true)
	elif int(_n["m6_raises"]) == 0:
		await _m6_raise(rng, vp, app, false)
	elif int(_n["m6_hex_menus"]) == 0:
		await _m6_hex_menu(rng, vp, app)
	elif int(_n["m6_military_pages"]) == 0:
		await _m6_military(rng, vp, app)
	elif int(_n["m6_file_keys"]) == 0:
		await _m6_file(rng, vp, app)
	elif int(_n["m6_replays"]) == 0:
		await _m6_end(rng, vp, app)


# ----- helpers ----------------------------------------------------------------------------------------------------------------------


## The map's army node (MapArmies), null before a map.
func _m6_map_armies(app: App) -> MapArmies:
	var scene := app.map_scene()
	if scene == null:
		return null
	return scene.get_node_or_null("MapArmies") as MapArmies


## True while the movement replay runs (the season's moves are played; no order may be given).
func _m6_replaying(app: App) -> bool:
	return app.requests().flow.state() == SeasonFlow.State.REPLAY


## A hex's place in the viewport's pixels.
## Where a click selects `army`: its token's click area (the token on its hex), else the hex's centre.
func _m6_unit_pos(app: App, army: Army) -> Vector2:
	var token := (app.map_scene().get_node("MapArmies") as MapArmies).tokens().token_at(army.hex, army.tag)
	if token == null:
		return _m6_screen_pos(app, army.hex)
	return token.get_global_transform_with_canvas() * Vector2(0.0, -25.0)


func _m6_screen_pos(app: App, hex: Vector2i) -> Vector2:
	var view := app.map_scene().view()
	return view.get_global_transform_with_canvas() * view.centre_of(hex)


## The people and the men of every army, all countries: a raise, a split, a merge or a disband moves them, none creates them.
static func _m6_total(game: Game) -> int:
	var total := 0
	for value: int in game.state.people:
		total += value
	for country: Country in game.countries:
		total += Armies.men_of_country(game, country.tag)
	return total


## The Confirm of a disband, when one is up: its Confirm or Keep (or Esc, when the button is not there).
func _m6_answer_confirm(rng: Rng, vp: SubViewport, app: App) -> void:
	var top := app.stack().top()
	if not (top is Confirm):
		return
	var choice: StringName = &"confirm" if rng.randi_range(0, 1) == 0 else &"cancel"
	var button := (top as Confirm).button_for(choice)
	if button != null:
		_m4_press(vp, button)
	else:
		_send_chord(vp, KEY_ESCAPE)
	await _wait_frames(2)


## Every screen is closed: Esc, and the stack's back when Esc does not close the top one (a Confirm keeps its Esc).
func _m6_clear(vp: SubViewport, app: App) -> void:
	var guard := 0
	while app.stack().count() > 0 and guard < 6:
		_send_chord(vp, KEY_ESCAPE)
		await _wait_frames(2)
		if app.stack().count() > 0 and not app.stack().back():
			app.stack().pop()
		await _wait_frames(1)
		guard += 1


## Esc until the report (or any screen but the study) is closed; a few tries, then whatever is left stays for the next step.
func _m6_close_screens(vp: SubViewport, app: App) -> void:
	var guard := 0
	while app.stack().count() > 0 and not app.stack().has_screen(&"study") and guard < 3:
		_send_chord(vp, KEY_ESCAPE)
		await _wait_frames(2)
		guard += 1


# ----- key 6 --------------------------------------------------------------------------------------------------------------------------


## Key 6 (Supply: its legend shows with its own title), the pointer over some land, then a map mode key (no change to the game).
func _m6_supply_key(rng: Rng, vp: SubViewport, app: App) -> void:
	var before := _m4_snapshot()
	_send_chord(vp, KEY_6)
	_bump("m6_supply_keys")
	await _wait_frames(3)
	if app.hud().is_hud_visible() and not app.hides_world():  # H hides the HUD
		assert_eq(app.map_scene().mode(), int(MapModes.Mode.SUPPLY), "%s: key 6 shows the Supply mode" % _tag)
		assert_true(app.hud().mode_legend().visible, "%s: Supply: the legend shows" % _tag)
		_bump("m6_checks")
	for _i: int in range(rng.randi_range(1, 3)):
		_m45_move(vp, Vector2(float(rng.randi_range(200, vp.size.x - 200)), float(rng.randi_range(120, vp.size.y - 120))))
		await _wait_frames(2)
	_m4_assert_untouched(before, "key 6 and the pointer over the map")
	if rng.randi_range(0, 2) != 0:
		_send_chord(vp, [KEY_1, KEY_2, KEY_3, KEY_4][rng.randi_range(0, 3)] as Key)
		await _wait_frames(3)
	_m4_assert_untouched(before, "a map mode key")


# ----- selection ------------------------------------------------------------------------------------------------------------------------


## Tab (the next army that needs orders) or a click on one of your armies' hexes (its first army; the next on each further click).
func _m6_select(rng: Rng, vp: SubViewport, app: App) -> void:
	if _m6_map_armies(app) == null or Session.game == null:
		return
	var mine: Array[Army] = Armies.of_country(Session.game, Session.player_tag())
	if mine.is_empty():
		return
	var army := mine[rng.randi_range(0, mine.size() - 1)]
	var pos := _m6_unit_pos(app, army)
	if rng.randi_range(0, 2) == 0 or not Rect2(Vector2.ZERO, Vector2(vp.size)).has_point(pos):
		_send_chord(vp, KEY_TAB)
	else:
		_send_click(vp, pos, MOUSE_BUTTON_LEFT)
	_bump("m6_selects")
	await _wait_frames(2)


# ----- orders ---------------------------------------------------------------------------------------------------------------------------


## A right click, O or R with an army of yours selected (a march, a halt, a march on). Selects one first when none is.
func _m6_order(rng: Rng, vp: SubViewport, app: App) -> void:
	var armies := _m6_map_armies(app)
	if armies == null:
		return
	if armies.selected_army() < 0 or rng.randi_range(0, 2) == 0:
		await _m6_march(rng, vp, app)
		return
	match rng.randi_range(0, 2):
		0:
			_send_chord(vp, KEY_O)
		1:
			var pos := Vector2(float(rng.randi_range(200, vp.size.x - 200)), float(rng.randi_range(120, vp.size.y - 120)))
			_send_click(vp, pos, MOUSE_BUTTON_RIGHT)
		_:
			_send_chord(vp, KEY_R)
	_bump("m6_orders")
	await _wait_frames(2)


## A march: the camera frames one of your armies, a click selects it, then a right click orders it to one of the own hexes on
## screen that the preview accepts (a march of the rules, the way the player gives it). Nothing is ordered when none is.
func _m6_march(rng: Rng, vp: SubViewport, app: App) -> void:
	var game := Session.game
	var tag := Session.player_tag()
	if game == null or tag == &"" or _m6_map_armies(app) == null:
		return
	var mine: Array[Army] = Armies.of_country(game, tag)
	if mine.is_empty():
		return
	var army := mine[rng.randi_range(0, mine.size() - 1)]
	var view := app.map_scene().view()
	app.map_scene().frame_at(view.centre_of(army.hex), 1.0)
	await _wait_frames(3)
	_send_click(vp, _m6_unit_pos(app, army), MOUSE_BUTTON_LEFT)
	await _wait_frames(2)
	var inside := Rect2(Vector2.ZERO, Vector2(vp.size))
	var goals: Array[Vector2i] = []
	for i: int in range(0, game.map.hex_count(), 2):
		var hex := game.map.hex_of(i)
		if game.map.land[i] == 0 or hex == army.hex or Territory.owner_tag(game, hex) != tag:
			continue
		if inside.has_point(_m6_screen_pos(app, hex)):
			goals.append(hex)
	if goals.is_empty():
		return
	# issue 457: an open debug overlay (F3) covers the map and takes the clicks: the march goals are clicked with it closed
	if app.hud().debug_overlay().is_open():
		app.hud().debug_overlay().set_open(false)
		await _wait_frames(1)
	var start := rng.randi_range(0, goals.size() - 1)
	for step: int in mini(goals.size(), 4):
		var goal := goals[(start + step) % goals.size()]
		var verdict := MovePreview.to(game, tag, army.id, goal)["verdict"] as Dictionary
		if bool(verdict.get("ok", false)):
			_send_click(vp, _m6_screen_pos(app, goal), MOUSE_BUTTON_RIGHT)
			_bump("m6_orders")
			await _wait_frames(2)
			return
	await _wait_frames(1)


## Whether one of yours is on a march (a season's walk, and so a replay, needs one).
func _m6_has_march() -> bool:
	for army: Army in Armies.of_country(Session.game, Session.player_tag()):
		if army.order == Army.ORDER_MARCH:
			return true
	return false


## During the replay: an order (blocked, the game unchanged) or, now and then, a skip (Space or Esc). The skip ends the replay.
func _m6_during_replay(rng: Rng, vp: SubViewport, app: App) -> void:
	await _m6_blocked_order(rng, vp, app)
	if rng.randi_range(0, 2) == 0:
		return
	var screens := app.stack().count()
	if rng.randi_range(0, 1) == 0:
		_send_chord(vp, KEY_SPACE)
		await _wait_frames(3)
	else:
		await _m6_esc(vp, app)
	if screens == 0:  # with a screen up (the study opened by a click) the key is the screen's: Esc closes it, and skips the replay on the next
		assert_false(_m6_replaying(app), "%s: Space or Esc skips the replay" % _tag)


## Esc while a replay runs: the ladder first lets go of the console's focus and closes an open popover, so a second or third Esc
## is the one that skips (Esc up to three times, until the replay is over).
func _m6_esc(vp: SubViewport, app: App) -> void:
	for _i: int in 3:
		_send_chord(vp, KEY_ESCAPE)
		await _wait_frames(3)
		if not _m6_replaying(app):
			return


## An order during the replay: a right click, O, R or Tab. Nothing is accepted: the digest, the version and the stores stay.
func _m6_blocked_order(rng: Rng, vp: SubViewport, app: App) -> void:
	if Session.game == null or Session.player_tag() == &"":
		return
	var before := _m4_snapshot()
	match rng.randi_range(0, 3):
		0:
			_send_chord(vp, KEY_R)
		1:
			_send_chord(vp, KEY_O)
		2:
			_send_click(vp, Vector2(float(rng.randi_range(200, vp.size.x - 200)), float(rng.randi_range(120, vp.size.y - 120))), MOUSE_BUTTON_RIGHT)
		_:
			_send_chord(vp, KEY_TAB)
	await _wait_frames(2)
	if _m6_replaying(app):
		_m4_assert_untouched(before, "an order during the replay")
		_bump("m6_replay_blocked")


# ----- the army panel -----------------------------------------------------------------------------------------------------------------

## One of the panel's buttons: Split off, Join, Disband (its Confirm answered at random), Hold or Continue march. The men of the
## world add up the same after a split, a join or a disband.
func _m6_panel(rng: Rng, vp: SubViewport, app: App, forced: bool = false) -> void:
	var armies := _m6_map_armies(app)
	if armies == null or Session.game == null:
		return
	if armies.selected_army() < 0:
		await _m6_select(rng, vp, app)
		if armies.selected_army() < 0:
			return
	var names: Array[String] = ["split_army", "merge_armies", "disband", "halt", "continue_march"]
	var start := rng.randi_range(0, names.size() - 1)
	var action := names[start]
	var btn := app.hud().army_panel().action_button(action)
	for i: int in range(1, names.size()):  # a forced step takes the first button that is enabled, so the counter does not wait on the dice
		if not forced or (btn != null and btn.is_visible_in_tree() and not btn.disabled):
			break
		action = names[(start + i) % names.size()]
		btn = app.hud().army_panel().action_button(action)
	if btn == null or not btn.is_visible_in_tree() or btn.disabled:
		return
	var game := Session.game
	var total := _m6_total(game)
	var pressed := _m4_press(vp, btn)
	await _wait_frames(2)
	if action == "disband":
		await _m6_answer_confirm(rng, vp, app)
	if pressed:
		_bump("m6_panel_actions")
	await _wait_frames(2)
	if action in ["split_army", "merge_armies", "disband"] and Session.game == game and not _m6_replaying(app):
		assert_eq(_m6_total(game), total, "%s: %s creates or loses no men or people" % [_tag, action])


# ----- the Raise tab and the console's raise -----------------------------------------------------------------------------------------

## A raise at one of your hexes: the Raise tab's first enabled kind (`console` false) or the console's `raise c r kind n`. A
## developer gift of ducats first, so a raise is not refused for money; the men come out of the hex's people.
func _m6_raise(rng: Rng, vp: SubViewport, app: App, console: bool) -> void:
	var game := Session.game
	if game == null or Session.player_tag() == &"" or app.map_scene() == null:
		return
	_m4_fund(app)
	var hex := _m4_pick_hex(rng, true)
	if hex == MapScene.NO_HEX:
		return
	_bump("m6_raises")
	var total := _m6_total(game)
	if console:
		var dev := app.hud().debug_overlay().console()
		if dev == null:
			return
		var kind: String = CONSOLE_KINDS[rng.randi_range(0, CONSOLE_KINDS.size() - 1)]
		dev.submit("raise %d %d %s %d" % [hex.x, hex.y, kind, rng.randi_range(1, 2)])
		await _wait_frames(2)
	else:
		app.map_scene().select_hex(hex)
		await _wait_frames(2)
		var panel := app.map_scene().panel() as HexPanel
		if panel == null:
			return
		panel.show_raise()
		await _wait_frames(2)
		var enabled: Array[KitButton] = []
		for button: KitButton in panel.raise_list().raise_buttons():
			if button.is_visible_in_tree() and not button.disabled:
				enabled.append(button)
		if enabled.is_empty():
			return
		_m4_press(vp, enabled[rng.randi_range(0, enabled.size() - 1)])
		await _wait_frames(2)
	if Session.game == game and not _m6_replaying(app):
		assert_eq(_m6_total(game), total, "%s: a raise moves men out of the people, it creates none" % _tag)


# ----- the hex menu -------------------------------------------------------------------------------------------------------------------

## O on one of your hexes with no army selected opens the hex menu; one of its items is chosen, or the menu is hidden.
func _m6_hex_menu(rng: Rng, vp: SubViewport, app: App) -> void:
	var armies := _m6_map_armies(app)
	if armies == null or armies.selected_army() >= 0:
		return
	var hex := _m4_pick_hex(rng, true)
	if hex == MapScene.NO_HEX:
		return
	app.map_scene().select_hex(hex)
	await _wait_frames(1)
	_send_chord(vp, KEY_O)
	await _wait_frames(2)
	var found := armies.find_children("*", "HexMenu", false, false)
	if found.is_empty() or not (found[0] as HexMenu).visible:
		return
	var menu := found[0] as HexMenu
	var entries := menu.entries()
	assert_gt(entries.size(), 0, "%s: the hex menu of your hex has items" % _tag)
	_bump("m6_hex_menus")
	if rng.randi_range(0, 2) == 0:
		menu.hide()
	else:
		var enabled: Array[Dictionary] = []
		for entry: Dictionary in entries:
			if bool(entry["enabled"]):
				enabled.append(entry)
		if not enabled.is_empty():
			menu.id_pressed.emit(int(enabled[rng.randi_range(0, enabled.size() - 1)]["id"]))
	await _wait_frames(2)


# ----- the Military page --------------------------------------------------------------------------------------------------------------

## The Military page by its keys (the study's [ and ]), then Look there or Show on the map when they show. The page changes nothing.
func _m6_military(rng: Rng, vp: SubViewport, app: App) -> void:
	if Session.game == null or Session.player_tag() == &"":
		return
	var before := _m4_snapshot()
	var study := await _m45_goto(vp, app, &"military", 0)
	if study == null:
		return
	_bump("m6_military_pages")
	await _wait_frames(2)
	var page := study.current_page() as PageMilitary
	if page == null:
		await _m4_close_study(rng, vp, app)
		return
	_m4_assert_untouched(before, "the Military page")
	var buttons: Array[Button] = []
	for node: Node in page.find_children("*", "Button", true, false):
		if (node as Button).is_visible_in_tree() and (node as Button).text in MILITARY_BUTTONS:
			buttons.append(node as Button)
	if not buttons.is_empty() and rng.randi_range(0, 1) == 0:
		_m4_press(vp, buttons[rng.randi_range(0, buttons.size() - 1)])
		await _wait_frames(3)
	_m4_assert_untouched(before, "a button of the Military page")
	await _m4_close_study(rng, vp, app)


# ----- End season and its replay ---------------------------------------------------------------------------------------------------

## End season (Enter or Space). With a replay running: a refused order, then the replay is watched a little and skipped (Space,
## Esc or a click), and the report closed. The movement is normal on every M6 seed, so the replay is there to be skipped.
func _m6_end(rng: Rng, vp: SubViewport, app: App) -> void:
	if Session.game == null or Session.player_tag() == &"":
		return
	# An army raised this season musters, and a winter may hold a walk: with a march of yours and no walk, End again (five at most;
	# a march is given first while none of yours is on one).
	for _attempt: int in 5:
		if await _m6_end_once(rng, vp, app) or Session.game == null:
			return
		var opened := SimClock.msec()
		while SimClock.msec() - opened < GUARD_MSEC:  # the report's guard refuses an End season this soon after it closed
			await _wait_frames(2)
		if not _m6_has_march():
			await _m6_march(rng, vp, app)
			if not _m6_has_march():
				return


## One End season: its key, and when the movement replay runs, a refused order, a watch, then a skip (Space, Esc or a click).
## True when a replay ran.
func _m6_end_once(rng: Rng, vp: SubViewport, app: App) -> bool:
	_send_chord(vp, KEY_ENTER if rng.randi_range(0, 1) == 0 else KEY_SPACE)
	await _wait_frames(2)
	var waited := 0
	while app.requests().flow.state() == SeasonFlow.State.RUNNING and waited < 120:  # the sliced season takes a few frames (M8)
		await _wait_frames(1)
		waited += 1
	var replayed := _m6_replaying(app)
	if replayed:
		_bump("m6_replays")
		await _m6_blocked_order(rng, vp, app)
		await _wait_frames(rng.randi_range(0, 6))
		match rng.randi_range(0, 2):
			0:
				var screens := app.stack().count()
				_send_chord(vp, KEY_SPACE)
				await _wait_frames(3)
				if screens == 0:  # with a screen up the key is the screen's
					assert_false(_m6_replaying(app), "%s: Space skips the replay" % _tag)
			1:
				var screens := app.stack().count()
				await _m6_esc(vp, app)
				if screens == 0:  # with a screen up the key is the screen's
					assert_false(_m6_replaying(app), "%s: Esc skips the replay" % _tag)
			_:
				_send_click(vp, Vector2(float(rng.randi_range(200, vp.size.x - 200)), float(rng.randi_range(120, vp.size.y - 120))), MOUSE_BUTTON_LEFT)
				await _wait_frames(2)
	var guard := 0
	while _m6_replaying(app) and guard < 400:  # the rest of the replay (a click may not skip it): it ends by itself
		await _wait_frames(1)
		guard += 1
	await _m6_close_screens(vp, app)
	return replayed


# ----- files --------------------------------------------------------------------------------------------------------------------------

## F5 (quicksave) or F9 (quickload). After a load nothing of yours stays selected: the army, the panel and the move card.
func _m6_file(rng: Rng, vp: SubViewport, app: App) -> void:
	var before_game := Session.game
	_send_chord(vp, KEY_F5 if rng.randi_range(0, 1) == 0 else KEY_F9)
	_bump("m6_file_keys")
	await _wait_frames(4)
	var armies := _m6_map_armies(app)
	if armies != null and Session.game != null and Session.game != before_game:
		assert_eq(armies.selected_army(), -1, "%s: no army stays selected after a load" % _tag)
		assert_eq(app.hud().army_panel().shown_army(), -1, "%s: the army panel is clear after a load" % _tag)
		assert_false(app.hud().map_hover().move_card().is_open(), "%s: the move card is closed after a load" % _tag)
		_bump("m6_checks")


# ----- after every step ---------------------------------------------------------------------------------------------------------------

## The selected army is yours and exists; the army panel shows exactly while one is selected (with the HUD up and no screen);
## no army of yours has negative men.
func _m6_assert_invariants(app: App, tag: String) -> void:
	var game := Session.game
	if game == null or not game.has_countries() or game.player == &"" or app.is_starting() or app.map_scene() == null:
		return
	var armies := _m6_map_armies(app)
	if armies == null:
		return
	var sel := armies.selected_army()
	if sel >= 0:
		var army := Armies.by_id(game, sel)
		assert_not_null(army, "%s: the selected army exists" % tag)
		if army != null:
			assert_eq(army.tag, game.player, "%s: the selected army is yours" % tag)
	if app.hud().is_hud_visible() and app.stack().count() == 0 and not app.hides_world():
		assert_eq(app.hud().army_panel().visible, sel >= 0, "%s: the army panel shows exactly while an own army is selected" % tag)
		_bump("m6_checks")
	for army: Army in Armies.of_country(game, game.player):
		assert_gte(army.men(), 0, "%s: no army of yours has negative men" % tag)
