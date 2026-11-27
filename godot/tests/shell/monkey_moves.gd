## The moves part of the UI monkey (MonkeyInput extends this, which extends MonkeyTile; moves-build-spec.md 8.4; MV15). A moves step picks one of the player's armies (a raise and a season
## when none can walk), selects it and orders it: a short march by a right click (then a second order on purpose), a march by O
## at the order cursor, a march past the season's points, a risky march or a storm (the question answered Move and Cancel in
## turn), Continue by R, F5 and F9 in the middle of the season, or End season. A live walk is watched a few frames and often
## skipped by a click, Esc, Space or F5. The multi-leg step stages one to four stops by Shift+left click or V (water, the
## army's own hex, the last stop and the same hex twice among them), drops them by V, Esc or "Clear stops", commits them by a
## right click, O or "March", and saves and loads with stops left.
## The invariants are monkey_moves_checks.gd's.
class_name MonkeyMoves
extends MonkeyMovesChecks

## The counters a moves seed must raise above 0.
const MOVES_REQUIRED: Array[String] = [
	"moves_walked", "moves_second", "moves_standing", "moves_confirms", "moves_live_skips", "moves_mid_saves",
	"moves_stops_staged", "moves_stops_removed", "moves_stops_cleared", "moves_via_committed", "moves_via_saves",
]
## The counters the log shows (not asserted).
const MOVES_LOGGED: Array[String] = [
	"moves_steps", "moves_orders", "moves_cancels", "moves_loads", "moves_storms", "moves_continues", "moves_frames",
	"moves_checks", "moves_marks",
]
## One M8 step in this many is a moves step (when the turn is idle and no screen is up).
const MOVES_STEP_ODDS := 3
## From this step on, a required counter still short gets a forced moves step after each step, up to MOVES_FORCED_MAX.
const MOVES_FORCE_STEP := 150
const MOVES_FORCED_MAX := 150
## Hexes tried for a goal before an order gives up.
const MOVES_GOAL_TRIES := 40
const MOVES_NO_HEX := Vector2i(-9999, -9999)

## The moves actions are on (a moves seed).
var _moves: bool = false
## Army id -> the turn of its last accepted order (a second order in one season counts moves_second).
var _moves_ordered: Dictionary = {}
## The answer the next question gets (Move and Cancel in turn).
var _moves_say_yes: bool = true
var _moves_forced: int = 0


## Starts the moves counters, the walk listener and the frame watch on a moves seed (after the tile ones).
func _moves_begin(on: bool, app: App) -> void:
	_moves = on
	_moves_app = app
	_moves_ordered = {}
	_moves_ends = {}
	_moves_look = {}
	_moves_frame_seen = {}
	_moves_say_yes = true
	_moves_forced = 0
	if not on:
		return
	for key: String in MOVES_REQUIRED + MOVES_LOGGED:
		_n[key] = 0
	Events.unit_moved.connect(_moves_on_unit_moved)
	get_tree().process_frame.connect(_moves_on_frame)


## Stops the watch and checks that every required counter was raised.
func _moves_end(on: bool, seed_value: int) -> void:
	_moves = false
	if not on:
		return
	Events.unit_moved.disconnect(_moves_on_unit_moved)
	get_tree().process_frame.disconnect(_moves_on_frame)
	_moves_app = null
	gut.p("monkey moves seed %d counters: %s" % [seed_value, JSON.stringify(_n)])
	for key: String in MOVES_REQUIRED:
		assert_gt(int(_n[key]), 0, "seed %d: the moves monkey did %s" % [seed_value, key])


## The M8 step, with a moves step on some of them (the tile, fog and M8 ones keep the rest).
func _m8_step(rng: Rng, vp: SubViewport, app: App) -> void:
	if _moves and _moves_ready(app) and rng.randi_range(0, MOVES_STEP_ODDS - 1) == 0:
		_m4_note("moves")
		await _moves_step(rng, vp, app, "")
		await _wait_frames(2)
		return
	await super._m8_step(rng, vp, app)


## The tile and fog invariants, then the moves ones, then a forced moves step while a required counter is still short.
func _fog_after_step(app: App, seed_value: int, step: int) -> void:
	await super._fog_after_step(app, seed_value, step)
	if not _moves:
		return
	_moves_invariants(app, "seed %d step %d" % [seed_value, step])
	var want := _moves_missing()
	if want == "" or step < MOVES_FORCE_STEP or _moves_forced >= MOVES_FORCED_MAX:
		return
	var vp := app.get_viewport() as SubViewport
	if vp == null or Session.game == null or Session.player_tag() == &"" or app.is_starting():
		return
	if not _moves_ready(app):
		# A screen the random steps opened blocks the forced step; a season or its replay is left to its own steps.
		if app.stack().count() > 0 and app.requests().flow.state() == SeasonFlow.State.IDLE:
			await _m6_clear(vp, app)
		if not _moves_ready(app):
			return
	_moves_forced += 1
	var rng := Rng.new()
	rng.seed_with(seed_value * 7000 + step)
	_tag = "seed %d step %d (forced %s)" % [seed_value, step, want]
	await _moves_step(rng, vp, app, want)
	await _wait_frames(2)
	_moves_invariants(app, _tag)


## The first required counter still at 0, "" when none.
func _moves_missing() -> String:
	for key: String in MOVES_REQUIRED:
		if int(_n[key]) <= 0:
			return key
	return ""


## A game with a player, no screen, the turn idle and no text box holding the keys.
func _moves_ready(app: App) -> bool:
	return _tile_ready(app) and _m4_ready(app) and _m6_map_armies(app) != null


## One moves step; `want` names the counter a forced step is after ("" for the dice).
func _moves_step(rng: Rng, vp: SubViewport, app: App, want: String) -> void:
	_bump("moves_steps")
	if app.hud().debug_overlay().is_open():  # it covers the map and takes the clicks
		app.hud().debug_overlay().set_open(false)
	app.hud().set_hud_visible(true)
	if want != "":  # a random click in Options may have turned the live walk or the question off
		app.settings().set_value("game/movement", "normal")
		app.settings().set_value("accessibility/reduce_motion", false)
		app.settings().set_value("game/confirm_moves", true)
	_moves_look_now()
	var id := await _moves_pick_army(rng, vp, app, want == "moves_confirms")
	if id < 0 or not _moves_ready(app) or not await _moves_select(vp, app, id):
		return
	var kind := _moves_kind(rng, want)
	match kind:
		0:
			await _moves_short(rng, vp, app, id, want == "moves_live_skips")
		1:
			await _moves_by_key(rng, vp, app, id)
		2:
			await _moves_long(rng, vp, app, id)
		3:
			await _moves_risky(rng, vp, app, id)
		4:
			await _moves_continue(rng, vp, app, id)
		5:
			await _moves_storm(rng, vp, app, id)
		6, 7, 8:
			await _moves_multi_leg(rng, vp, app, id, want)
		9:
			await _moves_save_load(rng, vp, app, id, want == "moves_mid_saves")
		_:
			await _m6_end(rng, vp, app)


func _moves_kind(rng: Rng, want: String) -> int:
	match want:
		"":
			return rng.randi_range(0, 10)
		"moves_walked", "moves_second", "moves_live_skips":
			return 0
		"moves_standing":
			return 2
		"moves_confirms":
			return 3
		"moves_mid_saves":
			return 9
	return 6


# ----- the army ----------------------------------------------------------------------------------------------------------------


## An army of the player's that can walk now (not mustering, points left). With none, one is raised and a season played, and
## -1 comes back. `risky` makes sure the player is at war with someone first (a risk needs an enemy or a long march).
func _moves_pick_army(rng: Rng, vp: SubViewport, app: App, risky: bool) -> int:
	var game := Session.game
	var tag := Session.player_tag()
	if risky or rng.randi_range(0, 9) == 0:
		var other := &"MLO" if tag != &"MLO" else &"SAV"
		if Wars.enemies(game, tag).is_empty() and bool(Session.check("declare_war", {"target": other}).get("ok", false)):
			Session.act("declare_war", {"target": other})
			_dev_changed = true
			_changed_hexes.clear()
			await _wait_frames(2)
			if not _moves_ready(app):
				return -1
	var ready: Array[int] = []
	for a: Army in Armies.of_country(Session.game, tag):
		if not a.mustering(Session.game.turn) and a.points > 0:
			ready.append(a.id)
	if not ready.is_empty():
		return ready[rng.randi_range(0, ready.size() - 1)]
	if Armies.of_country(Session.game, tag).size() < 3:
		await _m6_raise(rng, vp, app, true)
		_dev_changed = true
		_changed_hexes.clear()
	if _moves_ready(app):
		await _m6_end(rng, vp, app)
	return -1


## The army's token clicked (the camera frames it), else the layer's own selection (a stack, a panel over the token).
func _moves_select(vp: SubViewport, app: App, id: int) -> bool:
	var army := Armies.by_id(Session.game, id)
	var armies := _m6_map_armies(app)
	if army == null or armies == null:
		return false
	if armies.has_stops():
		armies.clear_army()
	await _moves_frame_on(app, army.hex)
	if armies.selected_army() != id:
		_send_click(vp, _m6_unit_pos(app, army), MOUSE_BUTTON_LEFT)
		await _wait_frames(2)
	if app.stack().count() != 0:  # a click that landed a live walk with a battle opens its dock
		return false
	if armies.selected_army() != id and Armies.by_id(Session.game, id) != null:
		armies.select_army(id)
		await _wait_frames(1)
	return armies.selected_army() == id


func _moves_frame_on(app: App, hex: Vector2i) -> void:
	app.map_scene().frame_at(app.map_scene().view().centre_of(hex), 1.0)
	await _wait_frames(3)


## A random land hex between `near` and `far` hexes from the army that the rules accept as a march (`risky`: one whose order
## would ask a question); MOVES_NO_HEX when the sample finds none.
func _moves_goal(rng: Rng, id: int, near: int, far: int, risky: bool = false) -> Vector2i:
	var game := Session.game
	var army := Armies.by_id(game, id)
	if army == null:
		return MOVES_NO_HEX
	var pool: Array[Vector2i] = []
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		var d := ImproveRules.hex_distance(army.hex, hex)
		if game.map.land[i] == 1 and d >= near and d <= far:
			pool.append(hex)
	for _t: int in mini(MOVES_GOAL_TRIES * (3 if risky else 1), pool.size()):
		var k := rng.randi_range(0, pool.size() - 1)
		var hex := pool[k]
		pool.remove_at(k)
		var preview := MovePreview.to(game, Session.player_tag(), id, hex)
		if not bool((preview["verdict"] as Dictionary).get("ok", false)):
			continue
		if risky and (preview["risks"] as Array).is_empty():
			continue
		return hex
	return MOVES_NO_HEX


# ----- an order --------------------------------------------------------------------------------------------------------------------


## What an army has that an order may change.
func _moves_state(id: int) -> Array:
	var a := Armies.by_id(Session.game, id)
	if a == null:
		return []
	return [a.hex, a.points, a.order, a.halt_why, a.goal, Array(a.route), Array(a.via)]


## Gives the order that `send` sends (a click or a key) for army `id`, answers its question (Move and Cancel in turn), counts
## what it did and checks the invariants. True when the order was accepted. The live walk, when one plays, is left playing.
func _moves_give(vp: SubViewport, app: App, id: int, send: Callable) -> bool:
	var game := Session.game
	var turn := game.turn
	var before := _moves_state(id)
	var unsaved := Session.unsaved_actions
	var digest := game.digest()
	_moves_ends = {}
	send.call()
	await _wait_frames(1)
	if app.stack().top() is Confirm and Session.unsaved_actions == unsaved:
		var yes := _moves_say_yes
		_moves_say_yes = not _moves_say_yes
		var button := (app.stack().top() as Confirm).button_for(&"confirm" if yes else &"cancel")
		assert_not_null(button, "%s: the question of a risky move has Move and Cancel" % _tag)
		assert_eq(game.digest(), digest, "%s: nothing walks before the answer" % _tag)
		if button == null or not _m4_press(vp, button):
			return false
		_bump("moves_confirms")
		await _wait_frames(2)
		if not yes:
			_bump("moves_cancels")
			assert_eq(game.digest(), digest, "%s: Cancel changes nothing" % _tag)
			return false
	_changed_hexes.clear()  # a walk and its battle change land by the rules, never by a works action
	if Session.game != game or Session.unsaved_actions <= unsaved:
		return false
	_bump("moves_orders")
	var army := Armies.by_id(game, id)
	if army != null:
		if not before.is_empty() and army.hex != before[0]:
			_bump("moves_walked")
		if army.order == Army.ORDER_MARCH and army.goal != army.hex:
			_bump("moves_standing")
	if int(_moves_ordered.get(id, -1)) == turn:
		_bump("moves_second")
	_moves_ordered[id] = turn
	_moves_check_ends(game)
	_moves_check_game(game, "after an order")
	return true


## A right click on `goal` (framed first).
func _moves_right_click(vp: SubViewport, app: App, id: int, goal: Vector2i) -> bool:
	await _moves_frame_on(app, goal)
	if app.stack().count() != 0 or _m6_map_armies(app).selected_army() != id:
		return false
	var pos := _m6_screen_pos(app, goal)
	_m45_move(vp, pos)
	return await _moves_give(vp, app, id, _send_click.bind(vp, pos, MOUSE_BUTTON_RIGHT))


## A short march by a right click, its live walk, and at once a second order to the same army.
func _moves_short(rng: Rng, vp: SubViewport, app: App, id: int, skip: bool) -> void:
	var goal := _moves_goal(rng, id, 1, 3)
	if goal == MOVES_NO_HEX:
		return
	if not await _moves_right_click(vp, app, id, goal):
		return
	await _moves_live(rng, vp, app, skip)
	var army := Armies.by_id(Session.game, id) if Session.game != null else null
	if army == null or army.points <= 0 or not _moves_ready(app) or not await _moves_select(vp, app, id):
		return
	goal = _moves_goal(rng, id, 1, 2)
	if goal != MOVES_NO_HEX and await _moves_right_click(vp, app, id, goal):
		await _moves_live(rng, vp, app, false)


## O at the order cursor, moved off the army by Alt+arrows.
func _moves_by_key(rng: Rng, vp: SubViewport, app: App, id: int) -> void:
	await _moves_cursor(rng, vp, app)
	if app.stack().count() != 0 or _m6_map_armies(app).selected_army() != id:
		return
	if await _moves_give(vp, app, id, _send_chord.bind(vp, KEY_O)):
		await _moves_live(rng, vp, app, false)


## A few Alt+arrows.
func _moves_cursor(rng: Rng, vp: SubViewport, app: App) -> void:
	var side: Key = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN][rng.randi_range(0, 3)] as Key
	for _i: int in rng.randi_range(1, 3):
		for pressed: bool in [true, false]:
			var ev := InputEventKey.new()
			ev.keycode = side
			ev.physical_keycode = side
			ev.alt_pressed = true
			ev.pressed = pressed
			vp.push_input(ev)
		await _wait_frames(1)
		if app.stack().count() != 0:
			return


## A march past the season's points: the first leg now, the rest standing.
func _moves_long(rng: Rng, vp: SubViewport, app: App, id: int) -> void:
	await _moves_march_to(rng, vp, app, id, _moves_goal(rng, id, 8, 20))


## A march whose order asks (enemy land, a battle, out of supply).
func _moves_risky(rng: Rng, vp: SubViewport, app: App, id: int) -> void:
	await _moves_march_to(rng, vp, app, id, _moves_goal(rng, id, 1, 14, true))


## A right click on `goal` (nothing with none) and its live walk.
func _moves_march_to(rng: Rng, vp: SubViewport, app: App, id: int, goal: Vector2i) -> void:
	if goal != MOVES_NO_HEX and await _moves_right_click(vp, app, id, goal):
		await _moves_live(rng, vp, app, false)


## R: a halted march walks on (or the refusal's toast). With none halted, the selected army is ordered a few hexes off and
## held first (a right click on its own hex keeps the march).
func _moves_continue(rng: Rng, vp: SubViewport, app: App, id: int) -> void:
	var halted: Array[int] = []
	for a: Army in Armies.of_country(Session.game, Session.player_tag()):
		if a.halt_why != &"" and a.goal != Army.NO_HEX and a.points > 0:
			halted.append(a.id)
	var which := id
	if not halted.is_empty():
		which = halted[rng.randi_range(0, halted.size() - 1)]
		if not await _moves_select(vp, app, which):
			return
	else:
		await _moves_march_to(rng, vp, app, id, _moves_goal(rng, id, 6, 12))
		var army := Armies.by_id(Session.game, id) if Session.game != null else null
		if army == null or army.order != Army.ORDER_MARCH or not _moves_ready(app) or not await _moves_select(vp, app, id):
			return
		await _moves_right_click(vp, app, id, army.hex)
		if not _moves_ready(app) or not await _moves_select(vp, app, id):
			return
	if await _moves_give(vp, app, which, _send_chord.bind(vp, KEY_R)):
		_bump("moves_continues")
		await _moves_live(rng, vp, app, false)


## Shift+right click on an enemy's fortress near the army (a storm of the rules, or its toast).
func _moves_storm(rng: Rng, vp: SubViewport, app: App, id: int) -> void:
	var game := Session.game
	var army := Armies.by_id(game, id)
	var found: Array[Vector2i] = []
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if ImproveRules.hex_distance(army.hex, hex) <= 20 and bool(Session.check("storm", {"army": id, "goal": hex}).get("ok", false)):
			found.append(hex)
	if found.is_empty():
		await _moves_risky(rng, vp, app, id)
		return
	var goal := found[rng.randi_range(0, found.size() - 1)]
	await _moves_frame_on(app, goal)
	if app.stack().count() != 0 or _m6_map_armies(app).selected_army() != id:
		return
	if await _moves_give(vp, app, id, _m7_shift_click.bind(vp, _m6_screen_pos(app, goal))):
		_bump("moves_storms")
		await _moves_live(rng, vp, app, false)


# ----- the live walk ----------------------------------------------------------------------------------------------------------------


## A live walk watched a few frames (the digest and the version stand), then skipped by a click, Esc, Space or F5 (`skip`:
## always; else most of the time, and the rest play on). A skip changes nothing of the game.
func _moves_live(rng: Rng, vp: SubViewport, app: App, skip: bool) -> void:
	var replay := app.requests().replay
	await _wait_frames(rng.randi_range(0, 3))
	if not replay.live_active() or app.stack().count() != 0 or Session.game == null:
		return
	if not skip and rng.randi_range(0, 3) == 0:
		return
	var game := Session.game
	var digest := game.digest()
	var version := game.version
	var how := rng.randi_range(0, 3)
	match how:
		0:
			_send_click(vp, Vector2(vp.size) * 0.5, MOUSE_BUTTON_LEFT)
		1:
			_send_chord(vp, KEY_ESCAPE)
		2:
			_send_chord(vp, KEY_SPACE)
		_:
			_send_chord(vp, KEY_F5)
			_dev_changed = true  # the step's order and then a save: the base check's unsaved count starts again at 0
	await _wait_frames(1)
	var named: String = ["a click", "Esc", "Space", "F5"][how]
	assert_false(replay.live_active(), "%s: %s skips the live walk" % [_tag, named])
	assert_eq(Session.game, game, "%s: the skip of a live walk keeps the game" % _tag)
	assert_eq(game.digest(), digest, "%s: %s on a live walk changes no digest" % [_tag, named])
	assert_eq(game.version, version, "%s: %s on a live walk is no action" % [_tag, named])
	assert_false(Session.in_season(), "%s: a skip of a live walk ends no season" % _tag)
	_bump("moves_live_skips")
	await _wait_frames(1)


# ----- F5 and F9 in the middle of the season -----------------------------------------------------------------------------------------


## F5 after an army was ordered this season (one is ordered first when none was), sometimes another order, then F9: the
## same game, the same armies, no stops staged.
func _moves_save_load(rng: Rng, vp: SubViewport, app: App, id: int, forced: bool) -> void:
	if not _moves_ordered.values().has(Session.game.turn):
		await _moves_short(rng, vp, app, id, false)
		if not _moves_ready(app) or not _moves_ordered.values().has(Session.game.turn):
			return
	var game := Session.game
	var digest := game.digest()
	var armies_before := _moves_all_states()
	var stops_left := false
	for a: Army in Armies.of_country(game, Session.player_tag()):
		stops_left = stops_left or not a.via.is_empty()
	_send_chord(vp, KEY_F5)
	_dev_changed = true  # an order and a save in one step: the base check's unsaved count starts again at 0
	await _m8_wait_until(func() -> bool: return Session.unsaved_actions == 0 and Session.current_slot == SaveRows.QUICK_SLOT, 120)
	if Session.game != game or Session.unsaved_actions != 0 or Session.current_slot != SaveRows.QUICK_SLOT:
		return
	_bump("moves_mid_saves")
	if not forced and rng.randi_range(0, 2) == 0:
		return
	if rng.randi_range(0, 1) == 0 and _moves_ready(app) and await _moves_select(vp, app, id):
		var goal := _moves_goal(rng, id, 1, 3)  # no _moves_live: a skip by F5 would save again
		if goal != MOVES_NO_HEX:
			await _moves_right_click(vp, app, id, goal)
	if not _moves_ready(app) or Session.game != game:
		return
	_send_chord(vp, KEY_F9)
	await _wait_frames(2)
	if app.stack().top() is Confirm and Session.game == game:
		var button := (app.stack().top() as Confirm).button_for(&"confirm")
		if button != null:
			_m4_press(vp, button)
	await _m8_wait_until(func() -> bool: return Session.game != game and not app.is_starting(), 900)
	if Session.game == game or Session.game == null:
		return
	await _wait_frames(3)
	_bump("moves_loads")
	if stops_left:
		_bump("moves_via_saves")
	_moves_ordered = {}
	for a: Army in Armies.of_country(Session.game, Session.player_tag()):
		if a.points < Allowance.full(Session.game, a):
			_moves_ordered[a.id] = Session.game.turn
	# A thin seed thins the loaded game after the step (MonkeyFog): read before that, it is the saved game.
	assert_eq(Session.game.digest(), digest, "%s: F9 gives the game of F5 in the middle of the season" % _tag)
	assert_eq(_moves_all_states(), armies_before, "%s: the same armies, points, halts, marches and stops" % _tag)
	var layer := _m6_map_armies(app)
	if layer != null:
		assert_false(layer.has_stops(), "%s: staged stops are not saved" % _tag)
		assert_eq(layer.selected_army(), -1, "%s: no army stays selected after a load" % _tag)


func _moves_all_states() -> Array:
	var out: Array = []
	for a: Army in Armies.of_country(Session.game, Session.player_tag()):
		out.append([a.id, _moves_state(a.id), a.season_from, a.halt_text])
	return out


# ----- multi-leg ---------------------------------------------------------------------------------------------------------------------


## Stops staged for the selected army, some dropped, then committed (or left to Esc); with stops left on the army, F5 and F9.
func _moves_multi_leg(rng: Rng, vp: SubViewport, app: App, id: int, want: String) -> void:
	var layer := _m6_map_armies(app)
	var committing := want == "moves_via_committed" or want == "moves_via_saves"
	for k: int in rng.randi_range(1, 4 if not committing else 2):
		if not await _moves_stage_one(rng, vp, app, id, k == 0 or committing):
			return
	if layer.has_stops() and (want == "moves_stops_removed" or (want == "" and rng.randi_range(0, 3) == 0)):
		await _moves_toggle(rng, vp, app, id, layer.stops().back())  # V or Shift+left on the last stop takes it off
	if not layer.has_stops() or app.stack().count() != 0:
		return
	if want == "moves_stops_cleared" or (not committing and rng.randi_range(0, 4) == 0):
		await _moves_clear(rng, vp, app, id)
		return
	if not await _moves_commit(rng, vp, app, id):
		return
	await _moves_live(rng, vp, app, false)
	var army := Armies.by_id(Session.game, id) if Session.game != null else null
	if army != null and not army.via.is_empty() and _moves_ready(app) and (want == "moves_via_saves" or rng.randi_range(0, 1) == 0):
		if await _moves_select(vp, app, id):
			await _moves_save_load(rng, vp, app, id, true)


## The hex of the next staging act: a far or near land hex, water, the army's own hex, or the last stop.
func _moves_stop_hex(rng: Rng, app: App, id: int, good: bool) -> Vector2i:
	var game := Session.game
	var army := Armies.by_id(game, id)
	var layer := _m6_map_armies(app)
	var roll := 9 if good else rng.randi_range(0, 9)
	if roll == 0 and layer.has_stops():
		return layer.stops().back()
	if roll == 1:
		return army.hex
	if roll == 2:
		for _t: int in 200:
			var i := rng.randi_range(0, game.map.hex_count() - 1)
			if game.map.land[i] != 1 and ImproveRules.hex_distance(army.hex, game.map.hex_of(i)) <= 14:
				return game.map.hex_of(i)
	var from: Vector2i = layer.stops().back() if layer.has_stops() else army.hex
	for _t: int in MOVES_GOAL_TRIES:
		var hex := _moves_goal(rng, id, 2, 5) if rng.randi_range(0, 2) == 0 else _moves_goal(rng, id, 8, 18)
		if hex != MOVES_NO_HEX and hex != from and bool(Movement.goal_verdict(game, army, army.tag, hex,
				from if layer.has_stops() else Movement.NO_HEX, false).ok):
			return hex
	return MOVES_NO_HEX


## One staging act at `hex`: Shift+left click, or V with the pointer there. Counts a stop added or taken off; I10 holds.
func _moves_toggle(rng: Rng, vp: SubViewport, app: App, id: int, hex: Vector2i) -> bool:
	var layer := _m6_map_armies(app)
	await _moves_frame_on(app, hex)
	if app.stack().count() != 0 or layer.selected_army() != id:
		return false
	var game := Session.game
	var before := layer.stops()
	var digest := game.digest()
	var version := game.version
	var unsaved := Session.unsaved_actions
	var pos := _m6_screen_pos(app, hex)
	_m45_move(vp, pos)
	await _wait_frames(1)
	var card := app.hud().map_hover().move_card()
	for button: Button in [card.march_button(), card.clear_button()]:
		if button != null and button.is_visible_in_tree() and button.get_global_rect().has_point(pos):
			return true  # the pinned card's button is under the pointer: the click would be the card's
	if rng.randi_range(0, 2) == 0:
		await _wait_frames(1)
		_send_chord(vp, KEY_V)
	else:
		_moves_shift_left(vp, pos)
	await _wait_frames(2)
	if Session.game != game:
		return false
	_moves_check_staged(game, digest, version, "a staging act")
	assert_eq(Session.unsaved_actions, unsaved, "%s: a staging act is no action" % _tag)
	var after := layer.stops()
	if after.size() > before.size():
		_bump("moves_stops_staged")
		assert_eq(after.size(), before.size() + 1, "%s: one stop a click" % _tag)
		assert_ne(Armies.by_id(game, id).hex, after.back(), "%s: the army's own hex is never a stop" % _tag)
		assert_eq(game.map.land[game.map.index_of(after.back())], 1, "%s: water is never a stop" % _tag)
		assert_lte(after.size(), game.defs.max_stops, "%s: no more stops than the defs allow" % _tag)
	elif after.size() < before.size() and layer.selected_army() == id:
		_bump("moves_stops_removed")
		assert_eq(after, before.slice(0, before.size() - 1), "%s: only the last stop comes off" % _tag)
	return true


func _moves_shift_left(vp: SubViewport, pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = pos
		ev.global_position = pos
		ev.shift_pressed = true
		ev.pressed = pressed
		vp.push_input(ev)


## One stop staged (`good`: a hex the leg accepts), now and then the same hex twice.
func _moves_stage_one(rng: Rng, vp: SubViewport, app: App, id: int, good: bool) -> bool:
	var hex := _moves_stop_hex(rng, app, id, good)
	if hex == MOVES_NO_HEX or not await _moves_toggle(rng, vp, app, id, hex):
		return false
	if not good and rng.randi_range(0, 4) == 0:
		return await _moves_toggle(rng, vp, app, id, hex)
	return true


## Every staged stop dropped by Esc or the card's "Clear stops"; the army stays selected.
func _moves_clear(rng: Rng, vp: SubViewport, app: App, id: int) -> void:
	var layer := _m6_map_armies(app)
	var game := Session.game
	var digest := game.digest()
	var version := game.version
	app.hud().release_console_focus()
	var button := app.hud().map_hover().move_card().clear_button()
	if rng.randi_range(0, 2) == 0 and button != null and button.is_visible_in_tree():
		_m4_press(vp, button)
		await _wait_frames(2)
	else:
		# The ladder's earlier rungs (a popover, the HUD's lists) may take the first Esc.
		for _i: int in 3:
			if not layer.has_stops():
				break
			_send_chord(vp, KEY_ESCAPE)
			await _wait_frames(2)
	if Session.game != game or app.stack().count() != 0:
		return
	_moves_check_staged(game, digest, version, "clearing the stops")
	assert_false(layer.has_stops(), "%s: Esc or Clear stops drops every stop" % _tag)
	assert_eq(layer.selected_army(), id, "%s: the army stays selected" % _tag)
	_bump("moves_stops_cleared")


## The staged march ordered by a right click, O or the card's "March". A refused order keeps the stops.
func _moves_commit(rng: Rng, vp: SubViewport, app: App, id: int) -> bool:
	var layer := _m6_map_armies(app)
	var staged := layer.stops()
	var goal := _moves_goal(rng, id, 2, 16)
	if goal == MOVES_NO_HEX or goal == staged.back():
		goal = staged.back()
	var how := rng.randi_range(0, 5)
	var done := false
	if how == 0:
		await _moves_cursor(rng, vp, app)
		var army := Armies.by_id(Session.game, id)
		if app.stack().count() != 0 or layer.selected_army() != id or army == null or layer.cursor_hex() == army.hex:
			return false
		done = await _moves_give(vp, app, id, _send_chord.bind(vp, KEY_O))
	else:
		await _moves_frame_on(app, goal)
		if app.stack().count() != 0 or layer.selected_army() != id or layer.stops() != staged:
			return false
		var pos := _m6_screen_pos(app, goal)
		_m45_move(vp, pos)
		await _wait_frames(1)
		var button := app.hud().map_hover().move_card().march_button()
		if how == 1 and button != null and button.is_visible_in_tree():
			done = await _moves_give(vp, app, id, func() -> void: _m4_press(vp, button))
		else:
			done = await _moves_give(vp, app, id, _send_click.bind(vp, pos, MOUSE_BUTTON_RIGHT))
	if done:
		_bump("moves_via_committed")
		assert_false(layer.has_stops(), "%s: an order given empties the staged stops" % _tag)
	return done
