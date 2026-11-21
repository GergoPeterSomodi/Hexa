## Warms the Statesman's Study's views after a season ends (docs/architecture/m4-5-build-spec.md 6.8 and 4.12): a child of the
## App that keeps a queue of read-only view calls (Economy's four, Rankings, History's timeline and first page, the People page's view,
## and the Yields or Food bytes while the map is in that mode) and runs one a frame, so no frame is long and a page opens from the game's view cache.
## It calls only views: nothing here changes the game. A newer game version (a work begun, a tax set, the next season) or a
## new game clears what is left of the queue; the next season ended or game started fills it again.
class_name StudyWarm
extends Node

const SPAN_KEY := "state/study_span"
const DEFAULT_SPAN := 12

## True while the map is in Yields (the App's GameRequests sets it); then the Yields bytes are warmed too.
var yields_active: Callable = Callable()
## True while the map is in Food (the App's GameRequests sets it); then the Food bytes are warmed too.
var food_active: Callable = Callable()
## True while the map is in Supply (M6); then the Supply bytes are warmed too.
var supply_active: Callable = Callable()

var _settings: Settings = null
var _queue: Array[Callable] = []
## A weak reference: the warmer never keeps a finished game (its state and view cache) alive.
var _game: WeakRef = null
var _version: int = -1
var _wired: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wire(true)


func _exit_tree() -> void:
	_wire(false)


## The shell's settings: the span (state/study_span) the views are warmed for.
func setup(settings: Settings) -> void:
	_settings = settings


## Fills the queue for the player's country in the game now: nothing without a game with countries or before the pick.
## The version of the game is noted; a newer one empties the queue.
func queue_views() -> void:
	_queue.clear()
	var game := Session.game
	_game = weakref(game) if game != null else null
	if game == null or not game.has_countries() or Session.player_tag() == &"":
		return
	_version = game.version
	var tag := Session.player_tag()
	var span := _span()
	_queue.append(func() -> void: StudyEconomy.this_season(game, tag))
	_queue.append(func() -> void: StudyEconomy.districts(game, tag))
	_queue.append(func() -> void: StudyEconomy.goods(game, tag, span))
	_queue.append(func() -> void: StudyEconomy.history(game, tag, span))
	_queue.append(func() -> void: StudyRankings.of(game, tag, span))
	_queue.append(func() -> void: StudyHistory.timeline(game, tag))
	_queue.append(func() -> void: StudyHistory.chronicle(game, tag, &"all", game.turn - 1, StudyHistory.PAGE))
	_queue.append(func() -> void: StudyPeople.of(game, tag, span))
	_queue.append(func() -> void: StudyMilitary.of(game, tag, span))
	if yields_active.is_valid() and bool(yields_active.call()):
		_queue.append(func() -> void: MapModes.yield_bytes(game, tag))
	if food_active.is_valid() and bool(food_active.call()):
		_queue.append(func() -> void: MapModes.food_bytes(game, tag))
	if supply_active.is_valid() and bool(supply_active.call()):
		_queue.append(func() -> void: MapModes.supply_bytes(game, tag))


## Runs the whole queue at once (tools and tests).
func warm_now() -> void:
	while pending() > 0:
		_run_next()


## The views still to warm (0 when the queue is empty or out of date).
func pending() -> int:
	_drop_if_stale()
	return _queue.size()


func _process(_delta: float) -> void:
	if not _queue.is_empty():
		_run_next()


func _run_next() -> void:
	_drop_if_stale()
	if _queue.is_empty():
		return
	var step: Callable = _queue.pop_front()
	step.call()


func _drop_if_stale() -> void:
	if _queue.is_empty():
		return
	var game := Session.game
	if game == null or _game == null or _game.get_ref() != game or game.version != _version:
		_queue.clear()


func _span() -> int:
	var span := DEFAULT_SPAN
	if _settings != null:
		span = int(_settings.get_value(SPAN_KEY))
	return span if StudyEconomy.SPANS.has(span) else DEFAULT_SPAN


func _wire(on: bool) -> void:
	if on == _wired:
		return
	_wired = on
	for sig: Signal in [Events.season_ended, Events.game_started]:
		if on and not sig.is_connected(_on_event):
			sig.connect(_on_event)
		elif not on and sig.is_connected(_on_event):
			sig.disconnect(_on_event)
	if on and not Events.game_ended.is_connected(_on_game_ended):
		Events.game_ended.connect(_on_game_ended)
	elif not on and Events.game_ended.is_connected(_on_game_ended):
		Events.game_ended.disconnect(_on_game_ended)


## A season ended or a game started: the queue is made once the signals of this moment are done (the version is final).
func _on_event(_arg: Variant = null) -> void:
	queue_views.call_deferred()


## The game ended: nothing queued may hold it (the queue's calls capture the game).
func _on_game_ended() -> void:
	_queue.clear()
	_game = null
