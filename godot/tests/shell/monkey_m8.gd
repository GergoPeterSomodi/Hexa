## The M8 part of the UI monkey (test_ui_monkey.gd extends this, which extends MonkeyM7): the computer plays the other countries
## (m8-build-spec.md section 9). With the AI on, End season (Space) runs the countries' turns in slices over frames. While they
## move, the map takes camera moves only: a drag pans, a click on the map is refused, F5 and F9 are refused (Session.in_season),
## Space does nothing. In the replay Space skips the walks and F5 saves mid-flow. Between seasons the console's `ai` and `watch`
## lines run. Invariants while a season runs: the turn does not move, the player's unsaved count does not move, the flow is RUNNING
## exactly while the session's season runs, and every record the season writes after its own end_season is the computer's (a
## record with a tag other than the player's) or the season's mark, so no player act is accepted in it. Split out of the monkey
## like MonkeyM7.
class_name MonkeyM8
extends MonkeyM7

## The M8 counters a seed must raise above 0 (so its invariants cannot pass empty).
const M8_REQUIRED: Array[String] = [
	"m8_seasons", "m8_pans", "m8_blocked_clicks", "m8_refused_files", "m8_mid_saves", "m8_skips", "m8_console", "m8_checks",
]
## The main counters every M8 seed must raise too (the picks, seasons, saves and the clicks a stuck modal would stop).
const M8_MAIN: Array[String] = ["picks", "seasons", "saves", "chip_clicks", "row_clicks", "m8_seasons"]
## The share of the steps that are M8 steps (the rest are the earlier milestones' steps).
const M8_STEP_PERCENT := 30
## Frames a skip or a refused input waits before it is judged.
const M8_WAIT_LIMIT := 240
## Frames a whole season (the countries' turn and the phases) may take before a step gives up waiting for its end.
const M8_SEASON_WAIT := 2400
## The console lines the M8 steps type: the computer's switches and the watch (refused once the game has begun).
const M8_CONSOLE_LINES: Array[String] = ["ai MLO", "ai off", "ai on", "ai pass MLO", "ai play MLO", "ai", "watch"]

## The M8 actions are on (a country game with the computer playing the others).
var _m8: bool = false
## The seasons ended before the step (the step's own check judges only a season that did not end in it).
var _m8_seasons0: int = 0


## Starts the M8 counters on an M8 seed (after the monkey's own counters are set up).
func _m8_begin(on: bool) -> void:
	_m8 = on
	if on:
		for key: String in M8_REQUIRED:
			_n[key] = 0


## Stops the M8 actions and checks that each M8 counter was raised.
func _m8_end(on: bool, seed_value: int) -> void:
	_m8 = false
	if not on:
		return
	gut.p("monkey m8 seed %d counters: %s" % [seed_value, JSON.stringify(_n)])
	for key: String in M8_REQUIRED + M8_MAIN:
		assert_gt(int(_n[key]), 0, "seed %d: the monkey did %s" % [seed_value, key])


## The action log's length before a step (0 with the computer off, or no game). Also the seasons ended so far (_n["seasons"]).
func _m8_mark(game: Game) -> int:
	_m8_seasons0 = int(_n.get("seasons", 0))
	return game.action_log.size() if (_m8 and game != null and game.map != null) else 0


## After a step with the computer on: the M8 invariants. True when a season ran or runs (the digest then moves in slices).
func _m8_check(app: App, prev_game: Game, from_len: int, prev_turn: int, prev_unsaved: int) -> bool:
	if not _m8:
		return false
	var touched := _m8_season_touched(prev_game, from_len)
	_m8_assert_invariants(app, _tag, prev_game, from_len, prev_turn, prev_unsaved)
	return touched


func _m8_wait_until(done: Callable, limit: int) -> bool:
	var frames := 0
	while not bool(done.call()) and frames < limit:
		await _wait_frames(1)
		frames += 1
	return bool(done.call())


## True when the step ran a season, or is running one (the digest then moves in slices and the M8 invariants read the records
## instead), or a new game began (a load). A season that finished in the step leaves the digest to the base check.
func _m8_season_touched(game: Game, from_len: int) -> bool:
	if game == null:
		return false
	if Session.in_season() or Session.game != game:
		return true
	if game.action_log.size() < from_len:
		return true
	for idx: int in range(from_len, game.action_log.size()):
		var action := str((game.action_log[idx] as Dictionary).get("action", ""))
		if action == "end_season" or action == LogOrders.MARK:
			return true
	return false


## One M8 step, by the flow's state.
func _m8_step(rng: Rng, vp: SubViewport, app: App) -> void:
	var state := app.requests().flow.state()
	if app.stack().top() is Confirm:
		# A decision alert (a war the computer declared on the seat, a peace) waits for the player's answer: the step gives it one,
		# and the monkey's stuck-Confirm check (monkey_m7) counts the steps it stays up.
		await _m7_answer(rng, vp, app, rng.randi_range(0, 1) == 0)
		await _wait_frames(2)
		return
	if state == SeasonFlow.State.RUNNING:
		await _m8_while_moving(rng, vp, app)
	elif state == SeasonFlow.State.REPLAY:
		await _m8_while_replaying(rng, vp, app)
	elif state == SeasonFlow.State.IDLE and _m3_calm(app):
		await _m8_between(rng, vp, app)
	await _wait_frames(2)


## Between seasons: Space begins one (the guard may refuse it), F5 saves mid-flow, or a console line runs.
func _m8_between(rng: Rng, vp: SubViewport, app: App) -> void:
	var roll := rng.randi_range(0, 9)
	if roll < 5:
		_send_chord(vp, KEY_SPACE)
		var began := await _m8_wait_until(func() -> bool: return app.requests().flow.state() != SeasonFlow.State.IDLE, 60)
		if began:
			_bump("m8_seasons")  # the next steps play the countries' turn (RUNNING) and the replay (REPLAY) as they come
	elif roll == 5:
		_send_chord(vp, KEY_F5)
		_bump("m8_mid_saves")
	elif roll == 6:
		_m8_console(rng, vp, app)


## While the countries move: a drag pans (free), a click and Space are refused, F5 and F9 are refused.
func _m8_while_moving(rng: Rng, vp: SubViewport, app: App) -> void:
	var game := Session.game
	var map := app.map_scene()
	var cam_before := map.camera().position if map != null else Vector2.ZERO
	var roll := rng.randi_range(0, 9)
	var files := false
	if roll <= 2:
		_m8_drag(rng, vp)
	elif roll <= 4:
		_send_click(vp, _m8_point(rng, vp), MOUSE_BUTTON_LEFT)
		_bump("m8_blocked_clicks")
	elif roll <= 6:
		files = true
		_send_chord(vp, KEY_F9 if roll == 5 else KEY_F5)
	elif roll == 7:
		_send_chord(vp, KEY_SPACE)
	elif roll == 8:
		_m8_console(rng, vp, app)
	elif roll == 9:
		# Waits out the season (the countries' turn and the phases) and skips its replay when it has one (the skip's counter).
		await _m8_wait_until(func() -> bool: return app.requests().flow.state() != SeasonFlow.State.RUNNING, M8_SEASON_WAIT)
		if app.requests().flow.state() == SeasonFlow.State.REPLAY:
			_send_chord(vp, KEY_SPACE)
			if await _m8_wait_until(func() -> bool: return app.requests().flow.state() != SeasonFlow.State.REPLAY, M8_WAIT_LIMIT):
				_bump("m8_skips")
	await _wait_frames(1)
	if not Session.in_season():
		return
	if map != null and map.camera().position != cam_before:
		_bump("m8_pans")
	if files:
		assert_eq(Session.game, game, "%s: F5 and F9 do nothing while the countries move" % _tag)
		_bump("m8_refused_files")


## The replay: Space skips it (it ends at once), F5 saves mid-flow, a click is refused.
func _m8_while_replaying(rng: Rng, vp: SubViewport, app: App) -> void:
	var roll := rng.randi_range(0, 3)
	if roll == 0 or roll == 3:
		_send_chord(vp, KEY_SPACE)
		var skipped := await _m8_wait_until(func() -> bool: return app.requests().flow.state() != SeasonFlow.State.REPLAY, M8_WAIT_LIMIT)
		assert_true(skipped, "%s: Space skips the replay" % _tag)
		if skipped:
			_bump("m8_skips")
	elif roll == 1:
		_send_chord(vp, KEY_F5)
		_bump("m8_mid_saves")
	else:
		_send_click(vp, _m8_point(rng, vp), MOUSE_BUTTON_LEFT)
		_bump("m8_blocked_clicks")


func _m8_console(rng: Rng, vp: SubViewport, app: App) -> void:
	var line := M8_CONSOLE_LINES[rng.randi_range(0, M8_CONSOLE_LINES.size() - 1)]
	var answer := DevCommands.run(line, app.context())
	_bump("m8_console")
	assert_false(answer.is_empty(), "%s: the console answers '%s'" % [_tag, line])


func _m8_point(rng: Rng, vp: SubViewport) -> Vector2:
	return Vector2(float(rng.randi_range(120, vp.size.x - 120)), float(rng.randi_range(100, vp.size.y - 100)))


## A left drag across the viewport: the camera pans (the map takes it while the countries move).
func _m8_drag(rng: Rng, vp: SubViewport) -> void:
	var start := _m8_point(rng, vp)
	var delta := Vector2(float(rng.randi_range(-90, 90)), float(rng.randi_range(-70, 70)))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = start
	press.global_position = start
	press.pressed = true
	vp.push_input(press)
	for pt: Vector2 in [start + delta * 0.5, start + delta]:
		var motion := InputEventMouseMotion.new()
		motion.position = pt
		motion.global_position = pt
		motion.relative = pt - start
		vp.push_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = start + delta
	release.global_position = start + delta
	release.pressed = false
	vp.push_input(release)


## The M8 invariants of one step. Only a season still running after the step is judged (a finished one is the base check's).
func _m8_assert_invariants(app: App, tag: String, prev_game: Game, from_len: int, prev_turn: int, prev_unsaved: int) -> void:
	var game := Session.game
	if game == null or game != prev_game or not game.has_countries() or app.is_starting() or app.map_scene() == null:
		return
	# A season that ended in this step (and maybe another began) moved the turn and the unsaved count: the base check's business.
	if not Session.in_season() or int(_n.get("seasons", 0)) != _m8_seasons0:
		return
	_bump("m8_checks")
	assert_eq(app.requests().flow.state(), SeasonFlow.State.RUNNING, "%s: the flow runs while the session's season runs" % tag)
	assert_eq(Session.unsaved_actions, prev_unsaved, "%s: no player act is accepted while the season runs" % tag)
	if app.requests().flow.running_stage() == &"phases":
		# The season's end runs one phase a frame (issue 441): the calendar moves the turn inside it, and the phases write the
		# game's own records. What holds here: the flow runs and the unsaved count does not move (it moves at the finish).
		return
	assert_eq(game.turn, prev_turn, "%s: the turn does not move while the countries move" % tag)
	assert_eq(Session.unsaved_actions, prev_unsaved, "%s: no player act is accepted while the countries move" % tag)
	# The records after this season's own end_season (or all of the step's, when the season began earlier) are the computer's.
	var first := from_len
	for idx: int in range(from_len, game.action_log.size()):
		if str((game.action_log[idx] as Dictionary).get("action", "")) == "end_season":
			first = idx + 1
	for idx: int in range(first, game.action_log.size()):
		var record := game.action_log[idx] as Dictionary
		var action := str(record.get("action", ""))
		if action == LogOrders.MARK:
			continue
		var who := str((record.get("args", {}) as Dictionary).get("tag", ""))
		assert_true(who != "" and StringName(who) != game.player,
			"%s: the player's record '%s' was written while the countries move" % [tag, action])
