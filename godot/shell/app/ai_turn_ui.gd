## The computer's turn in the App (docs/architecture/m8-build-spec.md 6.1 to 6.3 and 6.6; M8 K28): the busy pill counts the seats
## ("Countries are moving 3 / 12"), says the moves of the season that just ended during the replay, and the map takes no orders
## while the turn or the replay runs (a click toasts; panning stays free). The camera's moves shorten the AI's slices, the replay
## focuses on the hexes in view grown by two, and the console's watch ends the country pick. GameRequests owns one and binds it to
## each map scene; it reads the App only through its accessors and changes the game only through Session.
class_name AiTurnUI
extends RefCounted

const BLOCK_ORDERS := "Countries are moving: the map takes orders when they are done."
const BLOCK_REPLAY := "The moves are still playing: Space skips them."
const WATCH_TOAST := "Watching: the computer plays every country."
## The replay's focus is the hexes in view grown by this many hexes (M8 6.3).
const REPLAY_GROW := 2

var _app: App = null
var _flow: SeasonFlow = null
var _scene: MapScene = null


func _init(app: App, flow: SeasonFlow) -> void:
	_app = app
	_flow = flow


## Connects the flow's signals: the pill's count and text (the count, "The season ends" once the seats are done), and the map's
## order block at each state change.
func connect_signals(link: Callable) -> void:
	link.call(_flow, &"progressed", _on_progressed)
	link.call(_flow, &"state_changed", _on_state)
	link.call(_flow, &"phases_started", _on_phases)


## The map scene came: its input refuses orders while the turn runs, and its camera tells the flow when it moves.
func bind_scene(scene: MapScene) -> void:
	unbind_scene(_scene)
	_scene = scene
	var input := scene.map_input()
	if not input.blocked.is_connected(_on_blocked):
		input.blocked.connect(_on_blocked)
	var rig := scene.camera_rig()
	if rig != null and not rig.view_changed.is_connected(_on_view_changed):
		rig.view_changed.connect(_on_view_changed)
	_sync_block()


func unbind_scene(scene: MapScene) -> void:
	if scene != null and is_instance_valid(scene):
		var input := scene.map_input()
		if input != null:
			input.block_orders("")
			if input.blocked.is_connected(_on_blocked):
				input.blocked.disconnect(_on_blocked)
		var rig := scene.camera_rig()
		if rig != null and rig.view_changed.is_connected(_on_view_changed):
			rig.view_changed.disconnect(_on_view_changed)
	if scene == _scene:
		_scene = null


## The replay's focus (M8 6.3): the hexes in view grown by REPLAY_GROW; an empty rect with no map scene.
func replay_focus() -> Rect2i:
	if _scene == null or not is_instance_valid(_scene):
		return Rect2i()
	return _scene.view_hexes().grow(REPLAY_GROW)


## The console's watch succeeded (Session.watch): the country pick's screen goes, the map's pick marks go and the mode
## returns, and the top bar shows the sandbox seal.
func on_watch() -> void:
	var stack := _app.stack()
	var top := stack.top()
	if top != null and top.screen_id == &"country_pick":
		stack.pop().queue_free()  # the stack leaves the freeing to its caller
	if _scene != null and is_instance_valid(_scene):
		_scene.end_pick()
	_app.hud().top_bar().refresh_game()
	_app.hud().date_end().refresh()  # End turn: a watched game ends seasons (no player to choose)
	_app.hud().toast(WATCH_TOAST, &"plain", &"")


func _on_progressed(done: int, total: int) -> void:
	_app.hud().busy_pill().show_orders(done, total)


func _on_phases() -> void:
	_app.hud().busy_pill().show_text(BusyPill.SEASON_ENDS_TEXT)


func _on_state(state: SeasonFlow.State) -> void:
	if state == SeasonFlow.State.REPLAY:
		_app.hud().busy_pill().show_text(_replay_words())
	elif state != SeasonFlow.State.RUNNING:
		_app.hud().busy_pill().hide_pill()
	_sync_block()


## "The moves of Summer 1480 · Space skips them": the season that just ended is the turn before the one now.
func _replay_words() -> String:
	var game := Session.game
	var season := Calendar.date_text(game.turn - 1, game.start_year) if game != null else ""
	return "The moves of %s · Space skips them" % season


## The map takes no orders while the turn runs (its clicks toast) or the replay plays; "" lifts it.
func _sync_block() -> void:
	if _scene == null or not is_instance_valid(_scene):
		return
	var reason := ""
	match _flow.state():
		SeasonFlow.State.RUNNING:
			reason = BLOCK_ORDERS
		SeasonFlow.State.REPLAY:
			reason = BLOCK_REPLAY
	_scene.map_input().block_orders(reason)


func _on_blocked(reason: String) -> void:
	_app.hud().toast(reason, &"plain", &"")


func _on_view_changed(_zoom: float, _rect: Rect2) -> void:
	_flow.camera_moved()
