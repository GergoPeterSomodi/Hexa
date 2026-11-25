## The App's M3 handlers (docs/architecture/m3-build-spec.md 6.15), kept out of app.gd so that stays under its size limit:
## the season flow and the report screen, quicksave and quickload, Save and Load, Continue, the camera bookmarks, undo,
## the toasts of works (M4: with their ducats, "-40 ducats" and "+40 ducats back"), the floating ribbons' view, the running
## lock and the recovery question. The M4 requests (the works card, begin and cancel, the study, the tax toast) are WorksFlow's:
## this class owns one (`works`) and passes them on. The App makes one with itself and connects the signals below to it; this
## class reads the App only through its public accessors and changes the game only through Session.
class_name GameRequests
extends RefCounted

const UNDO_NOTHING := "Nothing to undo this season."
const NO_QUICKSAVE := "No quicksave yet."
const NO_GAME_TO_SAVE := "There is no game to save."
## The save's refusal while a season runs or its movement replay plays (spec 6.4; the pause menu's Save says the same).
const SEASON_RUNNING := "Wait for the season to end"
const NO_SAVE_TO_CONTINUE := "There is no save to continue."
const END_SEASONS_MAX := 40
const ARMY_GONE := "That army is gone."

## The running lock is written, cleared and checked only when this is true (the App sets it: a real run, or a test that
## points RunLock at a temporary file).
var lock_enabled: bool = false
var flow: SeasonFlow = null
var bookmarks: Bookmarks = Bookmarks.new()
## The works card, Begin and Cancel, the study and the tax toast (spec 6.12).
var works: WorksFlow = null
## Warms the study's views after a season (M4.5 spec 6.8): a child of the App, made in setup.
var warm: StudyWarm = null
## The movement replay of the season that just ended (M6 6.4): a child of the App, made in setup.
var replay: MoveReplay = null
## The computer's turn in the App: the pill, the order block, the replay's focus, watch (AiTurnUI, M8 6.1 to 6.3).
var ai_turn: AiTurnUI = null
## What the player must decide before the report (M7 6.6): a war declared on the player, one Confirm each.
var decisions := DecisionQueue.new()
## The war's requests (M7 6.11): Storm, B, the battle dock, the war alert and the Castle areas switch (WarRequests).
var war: WarRequests = null
## The map's ribbons are held (the season and its replay run); bind_scene applies it to a new map.
var _ribbons_held := false

var _app: App = null
var _scene: MapScene = null
var _floaters: Floaters = null
## A save or a load is under way: a second one is ignored.
var _busy: bool = false
var _top_inset: float = 0.0
## An autosave came due while a run of several seasons went by (the console's `end 3`): it is made when the run is done.
var _due_seen: bool = false


func _init(app: Node) -> void:
	_app = app as App
	works = WorksFlow.new(app)
	war = WarRequests.new(app, self)


## Makes the flow (a child of the App) with its callables, and lets the pause menu ask whether the season runs.
func setup() -> void:
	flow = SeasonFlow.new()
	flow.name = "SeasonFlow"
	flow.settings = _app.settings()
	flow.clock = Callable(SimClock, "msec")
	ai_turn = AiTurnUI.new(_app, flow)
	flow.show_season = _show_season
	flow.push_report = _push_report
	flow.toast = _flow_toast
	flow.autosave = _autosave
	_app.add_child(flow)
	replay = MoveReplay.new()
	replay.name = "MoveReplay"
	_app.add_child(replay)
	flow.replay_start = func(speed: StringName) -> bool: return replay.start(speed, ai_turn.replay_focus())
	flow.replay_skip = replay.skip
	flow.hold_ribbons = _hold_ribbons
	decisions.emptied.connect(flow.decisions_done)
	flow.decisions_start = func(_on_done: Callable) -> bool:
		return decisions.next(_app.context())
	warm = StudyWarm.new()
	warm.name = "StudyWarm"
	warm.setup(_app.settings())
	warm.yields_active = func() -> bool:
		return _scene != null and is_instance_valid(_scene) and _scene.mode() == int(MapModes.Mode.YIELDS)
	warm.food_active = func() -> bool:
		return _scene != null and is_instance_valid(_scene) and _scene.mode() == int(MapModes.Mode.FOOD)
	warm.supply_active = func() -> bool:
		return _scene != null and is_instance_valid(_scene) and _scene.mode() == int(MapModes.Mode.SUPPLY)
	_app.add_child(warm)
	_app.hud().debug_overlay().study_info_func = study_info
	_app.context().season_running_func = func() -> bool:
		return _season_busy()
	on_setting("dev/save_json")
	on_setting("accessibility/reduce_motion")


## Connects the signals this class answers. `link` is the App's `_link(emitter, signal, handler)`, which also takes them
## apart when the App leaves the tree.
func connect_signals(link: Callable) -> void:
	var hud := _app.hud()
	link.call(flow, &"state_changed", _on_flow_state)
	ai_turn.connect_signals(link)
	link.call(replay, &"finished", flow.replay_done)
	link.call(hud, &"end_season_requested", _on_end_pressed)
	link.call(hud, &"report_requested", flow.reopen_report)
	link.call(hud, &"hex_look_requested", _on_hex_look)
	link.call(hud, &"army_requested", _on_army_requested)
	var army_panel := hud.army_panel()
	link.call(army_panel, &"look_at_requested", _on_hex_look)
	link.call(army_panel, &"confirm_requested", _on_army_confirm)
	link.call(army_panel, &"toast_requested", _toast)
	link.call(army_panel, &"closed", _on_army_panel_closed)
	link.call(Events, &"army_selected", _on_army_selected)
	link.call(Events, &"army_cleared", _on_army_cleared)
	link.call(Events, &"game_ended", _on_army_cleared)
	link.call(_app.app_input(), &"quicksave_requested", quicksave)
	link.call(_app.app_input(), &"quickload_requested", quickload)
	link.call(_app.app_input(), &"console_requested", _on_console_requested)
	link.call(Events, &"game_started", _on_game_started)
	link.call(Events, &"game_started", decisions.clear)
	link.call(Events, &"game_ended", decisions.clear)
	link.call(Events, &"season_ended", _on_season_ended)
	link.call(Events, &"work_started", _on_work_started)
	link.call(Events, &"work_cancelled", _on_work_cancelled)
	works.connect_signals(link)
	war.connect_signals(link)


## What the F3 line says of the study: {page, tab, ms} of the last open (WorksFlow.study_info) and `warm`, the views the
## warmer still has to run.
func study_info() -> Dictionary:
	var info := works.study_info()
	info["warm"] = warm.pending() if warm != null and is_instance_valid(warm) else 0
	return info


## The map scene came: its keys, its camera and its ribbons are bound.
func bind_scene(scene: MapScene) -> void:
	unbind_scene(_scene)
	_scene = scene
	var input := scene.map_input()
	input.end_season_requested.connect(_on_map_end)
	input.report_requested.connect(flow.reopen_report)
	input.undo_work_requested.connect(undo_work)
	input.bookmark_requested.connect(on_bookmark)
	input.orders_blocked = replay.active
	input.blocked_click.connect(_on_blocked_click)
	if scene.camera_rig() != null:
		scene.camera_rig().view_changed.connect(_on_view_changed)
	_floaters = scene.get_node_or_null("Names/Floaters") as Floaters
	if _floaters != null:
		_floaters.setup(Session.game)
		_floaters.hold(_ribbons_held)
	works.bind_scene(scene)
	war.bind_scene(scene)
	ai_turn.bind_scene(scene)
	var armies := scene.get_node_or_null("MapArmies") as MapArmies
	if armies != null and not armies.said.is_connected(_on_order_said):
		armies.said.connect(_on_order_said)
	if armies != null:
		replay.bind(armies.tokens(), _follow_walker)
		armies.orders_blocked = replay.active
	on_setting("accessibility/reduce_motion")
	on_stack_changed()
	sync_floaters()


func unbind_scene(scene: MapScene) -> void:
	works.unbind_scene(scene)
	war.unbind_scene(scene)
	ai_turn.unbind_scene(scene)
	var armies := scene.get_node_or_null("MapArmies") as MapArmies if scene != null and is_instance_valid(scene) else null
	if armies != null and armies.said.is_connected(_on_order_said):
		armies.said.disconnect(_on_order_said)
	if armies != null:
		armies.orders_blocked = Callable()
	if scene != null and is_instance_valid(scene):
		var input := scene.map_input()
		if input != null:
			for pair: Array in [[input.end_season_requested, _on_map_end], [input.report_requested, flow.reopen_report],
					[input.undo_work_requested, undo_work], [input.bookmark_requested, on_bookmark]]:
				if (pair[0] as Signal).is_connected(pair[1] as Callable):
					(pair[0] as Signal).disconnect(pair[1] as Callable)
		if input != null:
			input.orders_blocked = Callable()
			if input.blocked_click.is_connected(_on_blocked_click):
				input.blocked_click.disconnect(_on_blocked_click)
		replay.bind(null, Callable())
		if scene.camera_rig() != null and scene.camera_rig().view_changed.is_connected(_on_view_changed):
			scene.camera_rig().view_changed.disconnect(_on_view_changed)
	if scene == _scene:
		_scene = null
		_floaters = null


## Skips the movement replay (Esc, the App's back key): true when one was running. Esc skips only over the bare map: with a
## screen or a popover open, or the console's field holding the cursor, the back ladder closes those first (spec 6.4).
func skip_replay() -> bool:
	if flow == null or _app.stack().top() != null or _app.hud().has_open_popover():
		return false
	var console := _app.hud().debug_overlay().console()
	if console != null and console.has_line_focus():
		return false
	return flow.skip_replay()


## A click on the map while the replay runs (spec 6.4): it selects and orders nothing, says so, and does not skip. Space,
## Esc and End season skip.
func _on_blocked_click(_map_px: Vector2) -> void:
	_on_order_said("The moves are still playing: Space skips them.", &"plain")


## The map's ribbons wait while the season and its replay run (SeasonFlow's hold_ribbons).
func _hold_ribbons(on: bool) -> void:
	_ribbons_held = on
	if _floaters != null:
		_floaters.hold(on)


## The replay's camera follow: glides to a walker's hex when it steps off the view (at once under reduce motion).
func _follow_walker(hex: Vector2i) -> void:
	if _scene == null or not is_instance_valid(_scene) or _scene.camera() == null:
		return
	var cam := _scene.camera()
	var half := _app.get_viewport().get_visible_rect().size * 0.5 / cam.zoom.x
	var at := _scene.view().centre_of(hex)
	if absf(at.x - cam.position.x) > half.x * 0.8 or absf(at.y - cam.position.y) > half.y * 0.8:
		_scene.glide_to_hex(hex, -1.0, bool(_app.settings().get_value("accessibility/reduce_motion")))


## A request from a screen or the console (ShellContext.request) that this class answers. False for any other.
func handle(what: StringName, args: Dictionary) -> bool:
	match what:
		&"save":
			save(str(args.get("slot", "")), str(args.get("name", "")))
		&"load":
			# The main menu's Continue asks for the newest slot: it falls back to older saves (spec 6.11).
			if _app.stack().top() != null and _app.stack().top().screen_id == &"main_menu":
				continue_game()
			else:
				load_slot(str(args.get("slot", "")))
		&"continue":
			continue_game()
		&"report_closed":
			flow.report_closed()
		&"select_army":
			_on_army_requested(int(args.get("army", -1)), _hex_arg(args.get("hex", null)))
		&"end_seasons":
			flow.request_end(false, clampi(int(args.get("count", 1)), 1, END_SEASONS_MAX))
		&"watch":
			ai_turn.on_watch()
		&"dev_look":
			var season := int(args.get("season", -1))
			if _scene != null:
				_scene.preview_season(season)
			_app.hud().set_look(season)
		_:
			return war.handle(what, args) or works.handle(what, args)
	return true


# ----- settings, stack, view ------------------------------------------------------------------------------------------


## A setting changed (the App calls it for every key, and with the two this class reads at the start).
func on_setting(key: String) -> void:
	var settings := _app.settings()
	if settings == null:
		return
	if key == "dev/save_json":
		Session.save_json = bool(settings.get_value("dev/save_json"))
	elif key == "accessibility/reduce_motion" and _floaters != null:
		_floaters.set_reduce_motion(bool(settings.get_value("accessibility/reduce_motion")))


## What a request for one of the player's armies does (a report line, a task flag row, a notification's Go, the request
## "select_army"): the army is selected and glided to; when it is not the player's or is gone, the hex is looked at; with no
## hex or no map scene, the player is told the army is gone. The hex comes with the request, so a gone army still leads somewhere.
func _on_army_requested(army: int, hex: Vector2i) -> void:
	var has_scene := _scene != null and is_instance_valid(_scene)
	var moved := false
	if has_scene:
		var armies := _scene.get_node_or_null("MapArmies") as MapArmies
		moved = armies != null and armies.show_army(army)
	match army_outcome(moved, hex, has_scene):
		&"look":
			_on_hex_look(hex)
		&"gone":
			_toast(ARMY_GONE, &"warn")


## The outcome of an army request, pure: &"moved" when the army was selected, &"look" when it was not but there is a hex
## and a map to look at it on, else &"gone".
static func army_outcome(moved: bool, hex: Vector2i, has_scene: bool) -> StringName:
	if moved:
		return &"moved"
	if has_scene and hex != WorksView.NO_HEX:
		return &"look"
	return &"gone"


## Whether an army of the player's is selected on the map (the Esc ladder's has_army).
func has_army() -> bool:
	var armies := _armies()
	return armies != null and armies.selected_army() >= 0


## The Esc ladder's clear step (M6 6.4): the army selection and its panel go first, then the country panel's dock, then the
## hex selection (or the tile window when there is no map).
func clear_selection() -> void:
	var armies := _armies()
	if armies != null and armies.selected_army() >= 0:
		armies.clear_army()
		return
	var hud := _app.hud()
	if hud == null:
		return
	if hud.country_panel() != null and hud.country_panel().visible:
		hud.close_dock()
	elif _app.map_scene() != null:
		_app.map_scene().select_hex(MapScene.NO_HEX)
	else:
		hud.tile_window().clear()


func _armies() -> MapArmies:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.get_node_or_null("MapArmies") as MapArmies


## An army was selected on the map (or from a line): the dock shows its panel alone.
func _on_army_selected(army_id: int) -> void:
	_app.hud().close_dock()
	_app.hud().army_panel().show_army(army_id)


func _on_army_cleared() -> void:
	_app.hud().army_panel().clear()


## The panel's close button lets the selection go too (the map and the panel stay in step).
func _on_army_panel_closed() -> void:
	var armies := _armies()
	if armies != null:
		armies.clear_army()


## A disband that needs its Confirm: the screen goes on the stack over the map.
func _on_army_confirm(screen: Screen) -> void:
	_app.stack().push(screen)


static func _hex_arg(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value as Vector2i
	return WorksView.NO_HEX


## The screen stack changed: the notifications and the task flag hide under a screen, the ribbons wait under a modal. The
## works card is no cover: it opens on a hover, beside the panel, over a live map.
func on_stack_changed() -> void:
	works.on_stack_changed()
	var screens := _app.stack().count() - (1 if _app.stack().has_screen(&"works_preview") else 0)
	_app.hud().set_covered(_app.hides_world(), screens > 0)
	if _floaters != null:
		if _app.wants_pause() or _app.hides_world():
			_floaters.wait()
		else:
			_floaters.resume()


## The HUD's cover changed: the ribbons follow, and screens under the top bar are told when its bottom edge moved.
func on_cover_changed() -> void:
	sync_floaters()
	var inset := _app.context().top_inset()
	if not is_equal_approx(inset, _top_inset):
		_top_inset = inset
		_app.context().top_inset_changed.emit()


## Puts the ribbons' screen transform, the view they must stay inside and the dock they must stay clear of in step with the
## camera and the HUD.
func sync_floaters() -> void:
	if _floaters == null or _scene == null or _scene.camera() == null:
		return
	var size := _app.get_viewport().get_visible_rect().size
	var z := _scene.camera().zoom.x
	_floaters.set_xform(Transform2D(Vector2(z, 0.0), Vector2(0.0, z), size * 0.5 - _scene.camera().position * z))
	_floaters.set_zoom(z)
	var bar := Hud.screen_rect(_app.hud().top_bar())
	var view := Rect2(0.0, bar.end.y, size.x, maxf(1.0, size.y - bar.end.y))
	var dock := Hud.screen_rect(_app.hud().dock()) if _app.hud().dock().is_visible_in_tree() else Rect2()
	_floaters.set_view(view, dock)


## The shell's ui block of a save: the bookmarks, the camera and the map mode.
func ui_block() -> Dictionary:
	var ui := {"bookmarks": bookmarks.to_dict()}
	if _scene != null and _scene.camera() != null:
		var c := _scene.camera().position
		ui["camera"] = {"centre": [c.x, c.y], "zoom": _scene.camera().zoom.x}
		ui["map_mode"] = _scene.mode()
	return ui


## After a load: the camera and the map mode of the save's ui block (the map was fitted first).
func restore_view() -> void:
	if _scene == null:
		return
	var ui := Session.loaded_ui()
	var cam: Variant = ui.get("camera")
	if cam is Dictionary:
		var centre: Variant = (cam as Dictionary).get("centre")
		var zoom: Variant = (cam as Dictionary).get("zoom")
		if centre is Array and (centre as Array).size() == 2 and (zoom is float or zoom is int):
			var parts := centre as Array
			if (parts[0] is float or parts[0] is int) and (parts[1] is float or parts[1] is int) and float(zoom) > 0.0:
				_scene.frame_at(Vector2(float(parts[0]), float(parts[1])), float(zoom))
	var mode: Variant = ui.get("map_mode")
	if mode is int or mode is float:
		_scene.set_mode(int(mode))


# ----- the flow ---------------------------------------------------------------------------------------------------------


func _show_season(season: int, fade: bool) -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.show_season(season, fade)
	# The flow autosaves when the turn it stops on is due; a due turn passed on the way is saved here.
	var skipped := _due_seen
	_due_seen = false
	var game := Session.game
	if skipped and game != null and not _autosave_due(game.turn):
		_autosave()


func _autosave_due(turn: int) -> bool:
	var game := Session.game
	var every := str(_app.settings().get_value("game/autosave")) if _app.settings() != null else "off"
	return game != null and SeasonFlow.autosave_due(turn, game.start_year, every)


## A season ended: the turn that begins may be an autosave turn the run goes past.
func _on_season_ended(turn: int) -> void:
	if _autosave_due(turn + 1):
		_due_seen = true


## Pushes the season report; true when it is up (the flow treats anything else as no screen).
func _push_report(summary: Dictionary, reopened: bool) -> bool:
	var screen := ScreenIds.make(&"season_report") as SeasonReport
	if screen == null:
		return false
	screen.show_summary(summary, reopened)
	_app.stack().push(screen)
	return true


func _flow_toast(text: String, tone: StringName, key_action: StringName) -> void:
	_app.hud().toast(text, tone, key_action)


## An order's words from the map's armies (spec 6.10: "The Army of Turin marches to Vercelli (6, 9): ..."): a plain toast.
func _on_order_said(text: String, tone: StringName) -> void:
	if _app != null and _app.hud() != null and not text.is_empty():
		_app.hud().toast(text, tone, &"")


## The season runs or its replay or decisions are up: Save waits and the pause menu greys it (M3 D48, M6 6.4).
func _season_busy() -> bool:
	return flow.state() == SeasonFlow.State.RUNNING or flow.state() == SeasonFlow.State.REPLAY \
		or flow.state() == SeasonFlow.State.DECISIONS


func _on_flow_state(state: SeasonFlow.State) -> void:
	var date := _app.hud().date_end()
	date.set_busy(state == SeasonFlow.State.RUNNING)
	date.refresh()


func _on_end_pressed() -> void:
	flow.request_end(false)


func _on_map_end(echo: bool) -> void:
	flow.request_end(echo)


func _on_hex_look(hex: Vector2i) -> void:
	_app.context().request(&"look_at", {"hex": hex, "select": true})


func _on_console_requested() -> void:
	_app.hud().debug_overlay().focus_console()


func _on_view_changed(_zoom: float, _rect: Rect2) -> void:
	sync_floaters()


func _on_game_started() -> void:
	var saved: Variant = Session.loaded_ui().get("bookmarks")
	bookmarks = Bookmarks.from_dict(saved if saved is Dictionary else {})
	_due_seen = false
	_app.hud().layers_popover().set_sight_available(Session.game != null and Session.game.has_countries())
	if _floaters != null:
		_floaters.setup(Session.game)
	if lock_enabled and Session.game != null:
		RunLock.write(Session.game.map.id, int(Time.get_unix_time_from_system()))


# ----- undo, bookmarks, work toasts -------------------------------------------------------------------------------------


## Ctrl/Cmd+Z: cancels the newest work the player began this season.
func undo_work() -> void:
	var game := Session.game
	if game == null or flow.state() != SeasonFlow.State.IDLE:
		return
	var hex := WorksView.last_begun(game, Session.player_tag())
	if hex == WorksView.NO_HEX:
		_toast(UNDO_NOTHING)
		return
	var verdict := Session.act("cancel_work", {"hex": hex})
	if not bool(verdict.get("ok", false)):
		_toast(str(verdict.get("reason", "")), &"bad")


## Ctrl/Cmd+Shift+1..9 sets a bookmark, Ctrl/Cmd+1..9 glides to it.
func on_bookmark(index: int, set_it: bool) -> void:
	if _scene == null or _scene.camera() == null:
		return
	if set_it:
		bookmarks.set_at(index, _scene.camera().position, _scene.camera().zoom.x)
		_toast("Bookmark %d set." % index)
		return
	var slot := bookmarks.get_at(index)
	if slot.is_empty():
		var caps := Bindings.key_caps_for(StringName("cam_bookmark_set_%d" % index), _app.settings().platform)
		_toast("Bookmark %d is empty: %s sets it." % [index, "+".join(caps)])
	elif _scene.camera_rig() != null:
		_scene.camera_rig().look_at(slot["centre"] as Vector2, float(slot["zoom"]))


func _on_work_started(tag: StringName, _hex: Vector2i, work: Dictionary) -> void:
	var game := Session.game
	var w := Work.from_dict(work)
	if game == null or w == null or tag != game.player:
		return
	var ready := "Halted by war" if Works.ready_turn(game, w) == Works.NO_DATE else "Ready " + Works.ready_words(game, w)
	var paid := _paid_words(game, w)
	var text := "Work begun: %s." % WorksView.line(game, w)
	if paid != "":
		text += " %s." % paid
	_toast("%s %s." % [text, ready], &"plain", &"game_undo_work")


func _on_work_cancelled(tag: StringName, _hex: Vector2i, work: Dictionary, why: StringName) -> void:
	var game := Session.game
	var w := Work.from_dict(work)
	if game == null or w == null or tag != game.player or why != &"order":
		return
	var text := "Work cancelled: %s." % WorksView.line(game, w)
	var back := _refund_words(game, w)
	if back != "":
		text += " %s back." % back
	_toast(text)


## What a begun work took: "−40 ducats", "−60 ducats, −10 timber" ("" for a free work). The work's own record of it.
func _paid_words(game: Game, w: Work) -> String:
	var parts: PackedStringArray = []
	if w.paid > 0:
		parts.append(Words.signed_ducats(-w.paid))
	parts.append_array(_goods_words(game, w.paid_goods, -1))
	return ", ".join(parts)


## What a cancelled work gives back at once (Works.refund and refund_goods: all of it in the season it began, else nothing):
## "+40 ducats", "+60 ducats, +10 timber".
func _refund_words(game: Game, w: Work) -> String:
	var parts: PackedStringArray = []
	var ducats := Works.refund(game, w)
	if ducats > 0:
		parts.append(Words.signed_ducats(ducats))
	parts.append_array(_goods_words(game, Works.refund_goods(game, w), 1))
	return ", ".join(parts)


## "−10 timber" (sign -1) or "+10 timber" (sign 1) for each good of `loads` (key -> n), in the goods' id order.
func _goods_words(game: Game, loads: Dictionary, sign: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for g: int in game.defs.goods.size():
		var good := game.defs.good(g)
		var n := int(loads.get(String(good.key), 0))
		if n > 0:
			out.append("%s %s" % [Words.signed(sign * n), good.name.to_lower()])
	return out


# ----- save, load -------------------------------------------------------------------------------------------------------


## The Save screen's request, and F5 through quicksave: the thumbnail, the file, a toast, ctx.saved.
func save(slot: String, save_name: String) -> void:
	if _busy:
		return
	var problem := _save_refusal()
	if problem.is_empty():
		_busy = true
		problem = await _write(slot, save_name)
		_busy = false
	var words := "" if problem.is_empty() else "Could not save: %s." % problem
	_app.context().saved.emit(slot, words)
	if problem.is_empty():
		_toast("Saved: %s." % SaveRows.label_of(slot), &"good")
	elif not _app.stack().has_screen(&"save_load"):
		_toast(words, &"bad")


## F5.
func quicksave() -> void:
	if Session.game == null:
		_toast(NO_GAME_TO_SAVE)
		return
	save(SaveRows.QUICK_SLOT, "")


## F9: asks before losing unsaved actions.
func quickload() -> void:
	if _busy or _app.is_starting() or flow.state() == SeasonFlow.State.RUNNING:
		return
	if SaveFile.read_header(SaveRows.QUICK_SLOT, Session.save_dir)["state"] == &"empty":
		_toast(NO_QUICKSAVE)
		return
	if Session.game != null and Session.unsaved_actions > 0:
		_ask("Load the quicksave?", "Load the quicksave? Unsaved changes are lost.", "Load", load_slot.bind(SaveRows.QUICK_SLOT))
	else:
		load_slot(SaveRows.QUICK_SLOT)


## Loads a slot: the screens go, Loading shows, the game starts, the camera and the bookmarks come from the save.
func load_slot(slot: String) -> void:
	if _busy or _app.is_starting() or flow.state() == SeasonFlow.State.RUNNING:
		return
	_busy = true
	var text := "Loading %s..." % SaveRows.label_of(slot)
	await _app.launch("Reading the save", text, func() -> String: return Session.load_game(slot), true)
	_busy = false


## The main menu's Continue: the newest save, then the next newest while one is damaged; the last problem is toasted.
func continue_game() -> void:
	if _busy or _app.is_starting():
		return
	_busy = true
	await _app.launch("Reading the save", "Reading the newest save...", _load_newest, true)
	_busy = false


## After a load: the saved camera and a toast.
func after_load() -> void:
	restore_view()
	var game := Session.game
	if game != null:
		_toast("Loaded: %s, %s." % [SaveRows.label_of(Session.current_slot), game.date_text()], &"good")


func _load_newest() -> String:
	var rows: Array[Dictionary] = []
	for row: Dictionary in Session.list_saves():
		if row["state"] == &"ok":
			rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int((a["header"] as Dictionary)["saved_unix"]) > int((b["header"] as Dictionary)["saved_unix"]))
	var problem := NO_SAVE_TO_CONTINUE
	for row: Dictionary in rows:
		problem = Session.load_game(str(row["slot"]))
		if problem.is_empty():
			return ""
	return problem


func _save_refusal() -> String:
	if Session.game == null:
		return "there is no game"
	if _season_busy():
		return SEASON_RUNNING
	return ""


## The picture and the file; the time of the write goes to F3.
func _write(slot: String, save_name: String) -> String:
	var image := await _thumbnail()
	var started := SimClock.usec()
	var problem := Session.save_game(slot, image, ui_block(), save_name)
	_app.hud().debug_overlay().record_save_ms(float(SimClock.usec() - started) / 1000.0)
	return problem


## The flow's autosave step, after a report closes: "Autosaved." or the failure.
func _autosave() -> void:
	if Session.game == null or _busy:
		return
	_busy = true
	var image := await _thumbnail()
	var started := SimClock.usec()
	var problem := Session.autosave_game(image, ui_block())
	_app.hud().debug_overlay().record_save_ms(float(SimClock.usec() - started) / 1000.0)
	_busy = false
	if problem.is_empty():
		_toast("Autosaved.")
	else:
		_toast("Could not autosave: %s." % problem, &"bad")


## The map without the HUD, the screens and the fade, 192 x 108; null headless.
func _thumbnail() -> Image:
	var layers: Array[CanvasLayer] = [_app.hud(), _app.get_node("Screens") as CanvasLayer]
	if _scene != null:
		_scene.finish_swap()
		layers.append(_scene.season_fade())
	return await Thumbnail.take(_app.get_viewport(), layers)


# ----- the running lock and the recovery --------------------------------------------------------------------------------


## The lock is gone (the main menu, a clean quit): only this process's own, or one that cannot be read; another running
## instance's lock stays.
func clear_lock() -> void:
	if not lock_enabled or not FileAccess.file_exists(RunLock.path):
		return
	var pid := int(RunLock.read().get("pid", 0))
	if pid <= 0 or pid == OS.get_process_id():
		RunLock.clear()


## At the start of the program, before the main menu clears the lock: {slot, date} of the autosave to offer when the last
## run did not close properly and that autosave is newer than every other save, else {}.
func recovery_candidate() -> Dictionary:
	if not lock_enabled or not RunLock.left_behind():
		return {}
	var best := {}
	var best_stamp := -1
	var other_stamp := -1
	for row: Dictionary in Session.list_saves():
		if row["state"] != &"ok":
			continue
		var header := row["header"] as Dictionary
		var stamp := int(header["saved_unix"])
		if SaveFile.AUTO_SLOTS.has(str(row["slot"])):
			if stamp > best_stamp:
				best_stamp = stamp
				best = {"slot": str(row["slot"]), "date": str(header["date"])}
		else:
			other_stamp = maxi(other_stamp, stamp)
	return best if best_stamp > other_stamp else {}


## Pushes the recovery question over the main menu.
func offer_recovery(candidate: Dictionary) -> void:
	if candidate.is_empty():
		return
	var confirm := Confirm.ask(
		"Hexa did not close properly",
		["Hexa did not close properly. Load the autosave from %s?" % str(candidate["date"])],
		[
			{"id": &"confirm", "label": "Load autosave", "kind": "primary", "safe": false},
			{"id": &"cancel", "label": "Not now", "kind": "secondary", "safe": true},
		],
		{"on_result": func(accepted: bool) -> void:
			if accepted:
				load_slot(str(candidate["slot"]))}
	)
	if confirm != null:
		_app.stack().push(confirm)


# ----- small helpers ----------------------------------------------------------------------------------------------------


func _ask(title: String, body: String, confirm_label: String, on_yes: Callable) -> void:
	var confirm := Confirm.make({
		"title": title, "body": body, "confirm_label": confirm_label, "cancel_label": "Stay", "danger": true,
		"on_result": func(accepted: bool) -> void:
			if accepted:
				on_yes.call(),
	})
	if confirm != null:
		_app.stack().push(confirm)


func _toast(text: String, tone: StringName = &"plain", key_action: StringName = &"") -> void:
	_app.hud().toast(text, tone, key_action)
