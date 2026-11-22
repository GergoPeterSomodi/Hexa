## The App's M7 handlers (docs/architecture/m7-build-spec.md 6.11; B28), kept out of game_requests.gd and app.gd so those stay
## under their size limits: Storm (Shift+right click and Shift+O), B and every opener of the battle dock (a badge, a log line, a
## report line, a notification's Go, the army panel, the Military page, the hex menu), the siege click, the castle-area item of
## the hex menu, the war alert (a war declared on the player), the declare and peace requests, the Castle areas switch's
## availability and the map's war layer (MapWars) getting its settings. GameRequests owns one (`war`) and passes the signals and
## requests on. It reads the App only through its public accessors and changes the game only through Session. The whole war UI
## answers only from milestone 7 (`milestone`, the App's Bindings.SHELL_MILESTONE), as M6's army chip does.
class_name WarRequests
extends RefCounted

const SINCE := 7.0
const NO_BATTLE := "You have fought no battle."
const NOT_SEEN := "You did not see that battle."
const NO_ARMY := "Select an army first."
## The zoom a glide to a battle reaches when the view is further out than this (AppRoutes.GLIDE_ZOOM).
const GLIDE_MIN_ZOOM := 0.6
## The requests this class answers (ShellContext.request): the battle dock, and a declaration or a peace for a country.
const REQUESTS: Array[StringName] = [&"battle", &"declare_war", &"peace"]

## The milestone the war UI is built at: before 7 the keys, the dock, the alert and the switch stay out (a test sets it).
var milestone: String = Bindings.SHELL_MILESTONE

var _app: App = null
var _req: GameRequests = null
var _scene: MapScene = null
var _dock: BattleDock = null
var _links: Array[Array] = []


func _init(app: Node, requests: RefCounted) -> void:
	_app = app as App
	_req = requests as GameRequests


## Whether the war UI is in this milestone.
func enabled() -> bool:
	return float(milestone) >= SINCE


## Connects the signals this class answers; `link` is the App's `_link(emitter, signal, handler)`.
func connect_signals(link: Callable) -> void:
	link.call(_app.hud(), &"battle_requested", open_battle)
	link.call(_app.hud(), &"confirm_requested", _push_screen)
	link.call(Events, &"battle_mark_clicked", open_battle)
	link.call(Events, &"war_declared", _on_war_declared)
	link.call(Events, &"game_started", _on_game_started)


## A request from a screen, the report, the log or the console that this class answers. False for any other.
func handle(what: StringName, args: Dictionary) -> bool:
	if not REQUESTS.has(what):
		return false
	if not enabled():
		return true
	match what:
		&"battle":
			open_battle(int(args.get("record", -1)))
		&"declare_war":
			_ask_war(StringName(str(args.get("target", &""))), "declare_war", &"")
		&"peace":
			_ask_war(StringName(str(args.get("target", &""))), "make_peace", StringName(str(args.get("terms", &""))))
	return true


# ----- the map ------------------------------------------------------------------------------------------------------------


## The map scene came: Storm and B are heard, the war layer gets the settings, the hex menu's and the marks' clicks are heard.
func bind_scene(scene: MapScene) -> void:
	unbind_scene(_scene)
	_scene = scene
	var input := scene.map_input()
	input.storm_ready = _army_selected
	_connect(input.storm_requested, _on_storm_clicked)
	_connect(input.storm_key_requested, _on_storm_key)
	_connect(input.battle_requested, open_last_battle)
	var wars := scene.get_node_or_null("MapWars") as MapWars
	if wars != null:
		wars.configure(_app.settings())
	var marks := scene.get_node_or_null("WarMarks") as WarMarks
	if marks != null:
		_connect(marks.siege_clicked, _on_siege_clicked)
	var armies := scene.get_node_or_null("MapArmies") as MapArmies
	if armies != null and armies.hex_menu() != null:
		_connect(armies.hex_menu().chosen, _on_menu_chosen)


func unbind_scene(scene: MapScene) -> void:
	for pair: Array in _links:
		var sig := pair[0] as Signal
		var fn := pair[1] as Callable
		if sig.is_connected(fn):
			sig.disconnect(fn)
	_links.clear()
	if scene != null and is_instance_valid(scene) and scene.map_input() != null:
		scene.map_input().storm_ready = Callable()
	if scene == _scene:
		_scene = null


func _connect(sig: Signal, fn: Callable) -> void:
	if not sig.is_connected(fn):
		sig.connect(fn)
		_links.append([sig, fn])


func _armies() -> MapArmies:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.get_node_or_null("MapArmies") as MapArmies


func _army_selected() -> bool:
	var armies := _armies()
	return enabled() and armies != null and armies.selected_army() >= 0


## Shift+right click with an army selected (MapInput asks storm_ready first): storm at that hex.
func _on_storm_clicked(map_px: Vector2) -> void:
	if enabled() and _scene != null and _scene.view() != null:
		storm_at(_scene.view().hex_at(map_px))


## Shift+O: storm at the cursor (the order cursor with an army selected).
func _on_storm_key() -> void:
	if not enabled():
		return
	var armies := _armies()
	if armies == null or armies.selected_army() < 0:
		_toast(NO_ARMY, &"warn")
		return
	storm_at(armies.cursor_hex())


## The selected army storms the fortress at `hex` (Session.act "storm"); the toast of 6.10 or the refusal's reason. True when
## the order was given.
func storm_at(hex: Vector2i) -> bool:
	var armies := _armies()
	var game := Session.game
	if armies == null or game == null or armies.selected_army() < 0 or game.map == null or not game.map.has(hex):
		return false
	if _req.replay != null and _req.replay.active():
		_toast(MapArmies.REPLAY_BLOCKED, &"plain")
		return false
	var tag := Session.player_tag()
	var army := armies.selected_army()
	var name := str(ArmyView.panel(game, tag, army).get("name", "The army"))
	var odds := OddsView.of(game, tag, army, hex, true)
	var verdict := Session.act("storm", {"army": army, "goal": hex})
	if not bool(verdict.get("ok", false)):
		_toast(str(verdict.get("reason", "")), &"warn")
		return false
	var word := str(odds.get("word", ""))
	if word.is_empty():
		word = str(odds.get("storm_word", ""))
	var tail := ": %s" % word if not word.is_empty() else ""
	_toast("The %s marches to storm %s%s." % [name, Words.place(game, hex), tail], &"plain")
	return true


## A siege dial was clicked: its hex is selected (the hex panel shows the siege).
func _on_siege_clicked(hex: Vector2i) -> void:
	if enabled() and _scene != null:
		_scene.select_hex(hex)


## A war item of the hex menu: the battle opens in the dock; the castle area is shown by looking at its castle.
func _on_menu_chosen(action: Array) -> void:
	if not enabled() or action.size() < 2:
		return
	match StringName(str(action[0])):
		&"battle":
			open_battle(int(action[1]))
		&"castle_area":
			show_castle_area(action[1] as Vector2i)


## The castle that holds the land at `hex`: selected and glided to (its panel names the area and its state).
func show_castle_area(hex: Vector2i) -> void:
	var game := Session.game
	if _scene == null or game == null:
		return
	var castle := AreaLines.held_by(game, hex)["fortress"] as Vector2i
	if castle == Army.NO_HEX:
		castle = hex
	_scene.select_hex(castle)
	_scene.glide_to_hex(castle, _glide_zoom(), _reduce_motion())


# ----- the battle dock ----------------------------------------------------------------------------------------------------


## B: the dock on the newest battle the player fought, or the toast that there is none.
func open_last_battle() -> void:
	if not enabled():
		return
	var game := Session.game
	var latest := BattleView.latest_of(game, Session.player_tag()) if game != null and game.has_countries() else -1
	if latest < 0:
		_toast(NO_BATTLE, &"plain")
		return
	open_battle(latest)


## Opens the battle dock at `record` and glides the camera so its hex sits in the free part of the map right of the dock. A
## battle the player did not see says so and shows nothing. The study (a screen that hides the map) closes first.
func open_battle(record: int) -> bool:
	var game := Session.game
	if not enabled() or game == null:
		return false
	if BattleView.of(game, Session.player_tag(), record).is_empty():
		_toast(NOT_SEEN, &"warn")
		return false
	_req.works.close_study()
	if _dock == null or not is_instance_valid(_dock) or not _app.stack().has_screen(&"battle_dock"):
		_dock = ScreenIds.make(&"battle_dock") as BattleDock
		if _dock == null:
			return false
		_dock.look_at_requested.connect(_glide_clear_of_dock)
		_app.stack().push(_dock)
	if not _dock.show_record(record):
		return false
	_glide_clear_of_dock((_dock.shown_hex()))
	return true


## The battle dock on the stack, or null.
func dock() -> BattleDock:
	if _dock != null and is_instance_valid(_dock) and _app.stack().has_screen(&"battle_dock"):
		return _dock
	return null


func _glide_clear_of_dock(hex: Vector2i) -> void:
	if _scene == null or hex == Army.NO_HEX or _scene.camera_rig() == null or _scene.view() == null:
		return
	var zoom := _glide_zoom()
	var at := _scene.view().centre_of(hex) - Vector2(BattleDock.WIDTH * 0.5 / maxf(zoom, 0.01), 0.0)
	_scene.camera_rig().look_at(at, zoom, _reduce_motion())


func _glide_zoom() -> float:
	if _scene == null or _scene.camera_rig() == null:
		return -1.0
	return maxf(_scene.camera_rig().target_zoom(), GLIDE_MIN_ZOOM)


func _reduce_motion() -> bool:
	return _app.settings() != null and bool(_app.settings().get_value("accessibility/reduce_motion"))


# ----- the war alert, the country panel ---------------------------------------------------------------------------------


## A war declared on the player queues its Confirm (D44): at once when the flow is idle, else in DECISIONS.
func _on_war_declared(tag: StringName, target: StringName) -> void:
	if not enabled() or target == &"" or target != Session.player_tag():
		return
	_req.decisions.push({"kind": DecisionQueue.KIND_WAR, "tag": tag, "target": target})
	if _req.flow.state() == SeasonFlow.State.IDLE:
		_req.decisions.next(_app.context(), true)


## The Castle areas switch of the Layers popover is there in a game with countries only (the sandbox has no war).
func _on_game_started() -> void:
	var has_war := enabled() and Session.game != null and Session.game.has_countries()
	_app.hud().layers_popover().set_castle_available(has_war)


## The Confirm of the country panel's war section (a declaration or a peace) goes on the App's stack.
func _push_screen(screen: Screen) -> void:
	_app.stack().push(screen)


## The request "declare_war" or "peace": the country's panel is shown and its war section asks the Confirm of 6.7.
func _ask_war(target: StringName, action: String, terms: StringName) -> void:
	if target == &"" or Session.game == null or not Session.game.has_countries():
		return
	var verdict := Session.check(action, {"target": target} if action == "declare_war" else {"target": target, "terms": terms})
	if not bool(verdict.get("ok", false)):  # the section's button would be locked: no panel, no question, only the reason
		_toast(str(verdict.get("reason", "")), &"warn")
		return
	_app.context().request(&"country", {"tag": target})
	var panel := _app.hud().country_panel()
	if panel != null and panel.visible:
		panel.war_section().ask(action, terms)


func _toast(text: String, tone: StringName) -> void:
	_app.hud().toast(text, tone, &"")
