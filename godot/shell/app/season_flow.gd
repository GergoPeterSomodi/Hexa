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

signal state_changed(state: State)

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
## (on: bool) -> void: holds the map's new ribbons while the season and its replay run (Floaters.hold).
var hold_ribbons: Callable = Callable()
## (turn: int) -> Dictionary: the summary of a season; the default reads Session. Tests may replace it.
var summarize: Callable = Callable()
## The clock value before which End season is refused.
var guard_until: int = 0

var _state: State = State.IDLE
var _reopened: bool = false


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
	if _state != State.IDLE or _now() < guard_until:
		return false
	var verdict := Session.end_season_check()
	if not bool(verdict.get("ok", false)):
		_toast(String(verdict.get("reason", "")), &"bad", &"")
		return false
	_set_state(State.RUNNING)
	_hold(true)
	_run(maxi(count, 1))
	return true


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


## The movement replay ended (its finished signal, or skip): the decisions (none before M7), then the report as M3.
func replay_done() -> void:
	if _state != State.REPLAY:
		return
	_set_state(State.DECISIONS)
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


func _run(count: int) -> void:
	if is_inside_tree():
		await get_tree().process_frame  # the busy ring is drawn before the season blocks the thread
	var played := 0
	for i in count:
		if Session.game == null:
			return  # the game ended while the flow was busy: stop quietly (reset() already ran)
		if i > 0 and not bool(Session.end_season_check().get("ok", false)):
			break
		var verdict := Session.end_season()
		if not bool(verdict.get("ok", false)):
			if played == 0:
				_toast(String(verdict.get("reason", "")), &"bad", &"")
			break
		played += 1
	if Session.game == null:
		return
	if _replay_begin(_speed()):
		_set_state(State.REPLAY)  # replay_done (the replay's finished) goes on to the decisions and the report
		return
	_set_state(State.DECISIONS)
	if played == 0:
		_back_to_idle()
		return
	_report()


## Starts the replay of the season that just ended; false when there is none to show (the replay_start callable says).
func _replay_begin(speed: StringName) -> bool:
	return replay_start.is_valid() and replay_start.call(speed) == true


## The replay's speed: instant under reduce motion, else the game/movement setting.
func _speed() -> StringName:
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
	return int(clock.call()) if clock.is_valid() else Time.get_ticks_msec()


func _setting(key: String, fallback: String) -> String:
	return String(settings.get_value(key)) if settings != null else fallback


func _reduce_motion() -> bool:
	return settings != null and bool(settings.get_value("accessibility/reduce_motion"))


func _set_state(next: State) -> void:
	if next == _state:
		return
	_state = next
	state_changed.emit(next)
