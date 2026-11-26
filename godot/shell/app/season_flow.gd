## The season flow (docs/architecture/m3-build-spec.md 6.3): End season pressed -> busy ring -> the season runs -> the
## report (Full), a toast (Brief, Off) -> back to the map with the guard, the season swap and the autosave. The App owns
## it and hands it callables for everything it does not know itself (the map, the report screen, the toasts, the
## autosave step), so it is tested with a fake clock and no scene.
class_name SeasonFlow
extends Node

enum State { IDLE, RUNNING, REPLAY, DECISIONS, REPORT }

## A second End season inside this many milliseconds of the report closing is refused (a double Space).
const GUARD_MS := 400
const SWING_BRIEF_PERMILLE := 100
const NO_SEASON_TEXT := "No season has ended yet."

## The AI's slice of a frame while the camera moved in the last CAMERA_QUIET_MS, and while it did not (M8 4.2).
const AI_SLICE_MS := 5.0
const AI_SLICE_IDLE_MS := 10.0
const CAMERA_QUIET_MS := 500
const SYNC_STEP_CAP := 1000000

signal state_changed(state: State)
## The computer's turn moved on: seats done, seats (once after the begin, then after each slice).
signal progressed(done: int, total: int)
## The computer's seats are all done: the phases run next frame (M8 K28, the pill's "The season ends").
signal phases_started

var settings: Settings = null
## () -> int, milliseconds. The App gives Time.get_ticks_msec; tests a fake.
var clock: Callable = Callable()
## (season: int, fade: bool) -> void: MapScene.show_season.
var show_season: Callable = Callable()
## (summary: Dictionary, reopened: bool) -> bool: pushes the season_report screen; true when it is up. reopened is
## true for J (the screen says "Back to the map"). A callable that is invalid or returns anything but true means no
## screen: the flow goes straight back to IDLE.
var push_report: Callable = Callable()
## (text: String, tone: StringName, key_action: StringName) -> void.
var toast: Callable = Callable()
## () -> void: the App's autosave step (thumbnail, Session.autosave_game, toast).
var autosave: Callable = Callable()
## (speed: StringName) -> bool: starts the movement replay of the season that just ended (MoveReplay.start); false means no
## replay (instant, nothing seen). An invalid callable means no replay.
var replay_start: Callable = Callable()
## () -> void: skips the running replay (MoveReplay.skip; its finished signal then calls replay_done).
var replay_skip: Callable = Callable()
## () -> bool: skips a running live walk (MoveReplay.skip_live; moves-build-spec.md R49): End season does it first.
var live_skip: Callable = Callable()
## (on: bool) -> void: holds the map's new ribbons while the season and its replay run (Floaters.hold).
var hold_ribbons: Callable = Callable()
## (on_done: Callable) -> bool: shows the next decision of the queue (DecisionQueue.next); true when one is up, and then
## the queue calls decisions_done() when it is empty. False (or no callable) means nothing to decide: the report follows.
var decisions_start: Callable = Callable()
## (turn: int) -> Dictionary: the summary of a season; the default reads Session. Tests may replace it.
var summarize: Callable = Callable()
## () -> Dictionary: begins the season ({ok, reason}); the default is Session.begin_season. Tests inject.
var begin_season: Callable = Callable()
## (budget_ms: float) -> bool: runs AI steps for about that long; true when the turn is over (Session.step_orders).
var step_orders: Callable = Callable()
## () -> void: Session.finish_season. When set, it ends the season in one call (tests); when not, the end runs in steps.
var finish_season: Callable = Callable()
## () -> bool: one step of the season's end, true when the season is over (Session.finish_step). The steps run one a frame
## of the phases stage (issue 441), so the season-end frame holds one phase and its drain.
var finish_step: Callable = Callable()
## () -> Vector2i: (seats done, seats) (Session.orders_progress).
var orders_progress: Callable = Callable()
## The clock value before which End season is refused.
var guard_until: int = 0

var _state: State = State.IDLE
var _reopened: bool = false
## RUNNING: &"orders" (the begin and the slices), &"phases" (the season's end); &"" outside RUNNING.
var _stage: StringName = &""
var _armed := false  # the frame after End season is drawn before the season begins
var _begun := false  # begin_season ran for the season in hand
var _left := 0  # seasons still to play (count)
var _played := 0
var _camera_at := -CAMERA_QUIET_MS * 100


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _enter_tree() -> void:
	Events.game_started.connect(reset)
	Events.game_ended.connect(reset)


func _exit_tree() -> void:
	if Events.game_started.is_connected(reset):
		Events.game_started.disconnect(reset)
	if Events.game_ended.is_connected(reset):
		Events.game_ended.disconnect(reset)


## Back to IDLE with no guard: a new game or none (a report left open must not block End season for good).
func reset() -> void:
	_stage = &""
	_reopened = false
	guard_until = 0
	_hold(false)
	_set_state(State.IDLE)


func state() -> State:
	return _state


## True when the season that begins (turn) is one the autosave setting saves at (D35): Spring, every year or every
## fifth year counted from start_year. "off" and unknown values are never due.
static func autosave_due(turn: int, start_year: int, every: String) -> bool:
	if Calendar.season_of(turn) != Calendar.SPRING:
		return false
	match every:
		"yearly":
			return true
		"five_years":
			return posmod(Calendar.year_of(turn, start_year) - start_year, 5) == 0
	return false


## Starts the season; true when it began. Refused on an echo (a held key), outside IDLE, inside the guard, or when the
## rules refuse (the reason is toasted, tone bad). The season itself runs after one drawn frame (the busy ring).
## During the movement replay the same request skips it instead and starts no season (M6 6.4); it returns false.
func request_end(echo: bool = false, count: int = 1) -> bool:
	if echo:
		return false
	if _state == State.REPLAY:
		skip_replay()
		return false
	if live_skip.is_valid():
		live_skip.call()  # the player's own walk lands first (R49); the season goes on
	if _state != State.IDLE or _now() < guard_until:
		return false
	var verdict := Session.end_season_check()
	if not bool(verdict.get("ok", false)):
		_toast(String(verdict.get("reason", "")), &"bad", &"")
		return false
	_stage = &"orders"
	_armed = false
	_begun = false
	_left = maxi(count, 1)
	_played = 0
	_set_state(State.RUNNING)
	_hold(true)
	if not is_inside_tree():  # no frames to wait for: run the season through at once (tests without a tree)
		_armed = true
		var guard := 0
		while _state == State.RUNNING and _stage != &"" and guard < SYNC_STEP_CAP:
			_tick()
			guard += 1
	return true


## The camera moved (the App connects CameraRig.view_changed): the AI's slices shrink for CAMERA_QUIET_MS.
func camera_moved() -> void:
	_camera_at = _now()


## The game ended while RUNNING: the hook's turn is dropped and the flow is IDLE again.
func abort() -> void:
	if _state != State.RUNNING:
		return
	_stage = &""
	var hook := Session.ai()
	if hook != null:
		hook.clear()
	_hold(false)
	_set_state(State.IDLE)


## &"orders", &"phases", or &"" outside RUNNING.
func running_stage() -> StringName:
	return _stage if _state == State.RUNNING else &""


func _process(_delta: float) -> void:
	if _state == State.RUNNING:
		_tick()


## Skips the running movement replay (Space, Enter, Esc, a click on the map, the End season plate): true when one was.
## The replay's finished signal calls replay_done; a replay with no skip callable is ended here.
func skip_replay() -> bool:
	if _state != State.REPLAY:
		return false
	if replay_skip.is_valid():
		replay_skip.call()
	if _state == State.REPLAY:
		replay_done()
	return true


## The movement replay ended (its finished signal, or skip): the decisions, then the report as M3.
func replay_done() -> void:
	if _state != State.REPLAY:
		return
	_decisions()


## The decision queue is empty (its emptied signal): the report follows. Only from DECISIONS.
func decisions_done() -> void:
	if _state != State.DECISIONS:
		return
	_report()


## DECISIONS (M7 6.6): the queue's first Confirm is up; decisions_done follows its last answer. With nothing queued the
## state passes at once to the report.
func _decisions() -> void:
	_set_state(State.DECISIONS)
	if not (decisions_start.is_valid() and decisions_start.call(decisions_done) == true):
		_report()


## J: the report of the season that last ended. Only from IDLE.
func reopen_report() -> void:
	if _state != State.IDLE:
		return
	var game := Session.game
	if game == null or game.turn <= Calendar.FIRST_TURN:
		_toast(NO_SEASON_TEXT, &"plain", &"")
		return
	var summary := _summary(game.turn - 1)
	if summary.is_empty():
		_toast(NO_SEASON_TEXT, &"plain", &"")
		return
	_reopened = true
	_set_state(State.REPORT)
	if not _push(summary, true):
		_back_to_idle()


## The report screen closed (its on_exit, through the ctx request report_closed).
func report_closed() -> void:
	if _state != State.REPORT:
		return
	_back_to_idle()


## One frame of RUNNING: arm, begin, one AI slice, or the season's end.
func _tick() -> void:
	if Session.game == null:
		abort()
		return
	if not _armed:
		_armed = true
		return
	if _stage == &"phases":
		_finish_one()
	elif not _begun:
		_begin_one()
	else:
		_slice()


func _begin_one() -> void:
	var verdict := (begin_season.call() if begin_season.is_valid() else Session.begin_season()) as Dictionary
	if not bool(verdict.get("ok", false)):
		if _played == 0:
			_toast(String(verdict.get("reason", "")), &"bad", &"")
		_ended()
		return
	_begun = true
	_emit_progress()


func _slice() -> void:
	var quiet := _now() - _camera_at >= CAMERA_QUIET_MS
	var budget := AI_SLICE_IDLE_MS if quiet else AI_SLICE_MS
	var done: bool = (step_orders.call(budget) if step_orders.is_valid() else Session.step_orders(budget)) == true
	_emit_progress()
	if done:
		_stage = &"phases"  # one frame shows "The season ends", then the phases run
		phases_started.emit()


func _finish_one() -> void:
	if finish_season.is_valid():
		finish_season.call()
	elif not _finish_step():
		return  # the next step of the season's end runs next frame
	_played += 1
	_left -= 1
	_begun = false
	_stage = &"orders"
	if _left > 0 and Session.game != null and bool(Session.end_season_check().get("ok", false)):
		return  # the next season begins on the next tick
	_ended()


## One step of the season's end; true when the season is over.
func _finish_step() -> bool:
	if finish_step.is_valid():
		return finish_step.call() == true
	return Session.finish_step()


func _emit_progress() -> void:
	var p := (orders_progress.call() if orders_progress.is_valid() else Session.orders_progress()) as Vector2i
	progressed.emit(p.x, p.y)


## The seasons are played (or the first was refused): the replay, the decisions and the report as M6 and M7.
func _ended() -> void:
	_stage = &""
	if Session.game == null:
		return
	if _replay_begin(speed()):
		_set_state(State.REPLAY)  # replay_done (the replay's finished) goes on to the decisions and the report
		return
	if _played == 0:
		_set_state(State.DECISIONS)
		_back_to_idle()
		return
	_decisions()


## Starts the replay of the season that just ended; false when there is none to show (the replay_start callable says).
func _replay_begin(speed: StringName) -> bool:
	return replay_start.is_valid() and replay_start.call(speed) == true


## The speed of the season replay and of a live walk: instant under reduce motion, else the game/movement setting.
func speed() -> StringName:
	if _reduce_motion():
		return &"instant"
	return StringName(_setting("game/movement", "normal"))


func _hold(on: bool) -> void:
	if hold_ribbons.is_valid():
		hold_ribbons.call(on)


func _report() -> void:
	var game := Session.game
	var summary := _summary(game.turn - 1) if game != null else {}
	if summary.is_empty():
		_back_to_idle()
		return
	var mode := _setting("game/season_report", "full")
	var shown := mode == "full"
	if mode == "brief":
		shown = bool(summary.get("serious", false)) or int(summary.get("swing_permille", 0)) > SWING_BRIEF_PERMILLE
	if shown:
		_reopened = false
		_set_state(State.REPORT)
		if not _push(summary, false):
			_back_to_idle()
	else:
		_toast(String(summary.get("toast", "")), &"plain", &"game_report")
		_back_to_idle()


func _back_to_idle() -> void:
	_hold(false)
	var reopened := _reopened
	_reopened = false
	guard_until = _now() + GUARD_MS
	_set_state(State.IDLE)
	if reopened:
		return
	var game := Session.game
	if game == null:
		return
	if show_season.is_valid():
		var fade := _setting("graphics/season_change", "fade") == "fade" and not _reduce_motion()
		show_season.call(Calendar.season_of(game.turn), fade)
	if autosave.is_valid() and autosave_due(game.turn, game.start_year, _setting("game/autosave", "yearly")):
		autosave.call()


func _summary(turn: int) -> Dictionary:
	if summarize.is_valid():
		return summarize.call(turn) as Dictionary
	return SeasonSummary.of(Session.game, Session.player_tag(), turn)


func _push(summary: Dictionary, reopened: bool) -> bool:
	return push_report.is_valid() and push_report.call(summary, reopened) == true


func _toast(text: String, tone: StringName, key_action: StringName) -> void:
	if toast.is_valid():
		toast.call(text, tone, key_action)


func _now() -> int:
	return int(clock.call()) if clock.is_valid() else SimClock.msec()


func _setting(key: String, fallback: String) -> String:
	return String(settings.get_value(key)) if settings != null else fallback


func _reduce_motion() -> bool:
	return settings != null and bool(settings.get_value("accessibility/reduce_motion"))


func _set_state(next: State) -> void:
	if next == _state:
		return
	_state = next
	state_changed.emit(next)
