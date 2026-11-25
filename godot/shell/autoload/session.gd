## The current game and the one door from the shell to the rules (autoload "Session"; docs/architecture/m1-build-spec.md
## section 8). The shell asks `check` and calls `act`; it never calls the rules directly and never writes the state. After
## an action Session empties the game's event queue and emits one Events signal per event. `core/` never reads this.
extends Node

## The current game, or null before the first new_game.
var game: Game = null
## Number of successful player actions since the game started (or was saved).
var unsaved_actions: int = 0
## Seconds played in the current game, counted while a game runs and the tree is not paused.
var play_seconds: float = 0.0
## The slot last saved or loaded ("" for none).
var current_slot: String = ""
## Phase name -> milliseconds the last season spent in it (F3, perf); M4 adds production and income, M5 people, M6 the
## movement, supply, ready_units and vision phases (Season.PHASES).
var last_phase_ms: Dictionary = {}
## False: every seat is passive (the console's `ai off`; tests/shell/ui_harness.gd). Read when a game starts.
var ai_enabled := true:
	set(value):
		ai_enabled = value
		var hook := ai()
		if hook != null:
			hook.enabled = value
## The worst single AI step of the last season, in milliseconds (F3, perf_ui).
var ai_worst_step_ms: float = 0.0

## The folder of the saves; tests point it at a temporary folder.
var save_dir: String = SaveFile.DIR
## Also write `<slot>.body.json` with each save (the App sets it from the dev/save_json setting).
var save_json: bool = false

const DEFS := "res://data/defs/game_defs.tres"
const DAMAGED := "The save is damaged"
const NO_GAME := "no game"
const WAIT_TEXT := "wait for the season to end"

## The ui block of the last load ({} after a new game).
var _loaded_ui: Dictionary = {}
## MapData instance id -> MapData.digest(), cached.
var _map_digests: Dictionary = {}
## scenario id -> digest, valid for the defs instance in _scenario_digests_of.
var _scenario_digests: Dictionary = {}
var _scenario_digests_of: GameDefs = null

var _maps: Dictionary[String, MapData] = {}
var _defs: GameDefs = null
## What the current game was made from, for reseed: {map_id, scenario_id, player}; empty for a game put in place.
var _origin: Dictionary = {}
## Between begin_season and finish_season: check and act are refused (M8 D40).
var _in_season := false
var _finish_next := 0  # the next step of finish_step (0 is the orders' end)
var _ended_turn := 0  # the turn the season that finish_step ends was played in
## The tags the AI leaves alone; kept across games and given to each new hook.
var _passive: Array[StringName] = []


## A new game on a map of data/maps/<map_id>.tres (or .res): runs the improvement search for the seed.
func new_game(map_id: String, seed_value: int) -> void:
	var map := map_of(map_id)
	if map == null:
		push_error("Session: no map '%s' in res://data/maps/" % map_id)
		return
	start_game(Game.new_game(map, seed_value, defs()))
	_origin = {"map_id": map_id, "scenario_id": "", "player": &""}


## The fixed game definitions, loaded once; push_error and null when they fail validate().
func defs() -> GameDefs:
	if _defs != null:
		return _defs
	var loaded := load(DEFS) as GameDefs
	if loaded == null:
		push_error("Session: cannot load %s" % DEFS)
		return null
	var problems := loaded.validate()
	if not problems.is_empty():
		push_error("Session: %s is invalid: %s" % [DEFS, problems[0]])
		return null
	_defs = loaded
	return _defs


## A new game of a scenario on its map. On a problem returns its first line and starts nothing (the App toasts it);
## otherwise starts the game, chooses `player` when given (the command line, reseed), and returns "".
func new_scenario(scenario_id: String, seed_value: int, player: StringName = &"") -> String:
	var game_defs := defs()
	if game_defs == null:
		return "the game definitions did not load"
	var scenario := game_defs.scenario(scenario_id)
	if scenario == null:
		return "no scenario '%s'" % scenario_id
	var map := map_of(scenario.map_id)
	if map == null:
		return "scenario '%s': no map '%s' in res://data/maps/" % [scenario_id, scenario.map_id]
	var problems := scenario.validate(map, game_defs, false)
	if not problems.is_empty():
		return problems[0]
	start_game(Game.new_scenario(map, game_defs, scenario, seed_value))
	_origin = {"map_id": scenario.map_id, "scenario_id": scenario_id, "player": player}
	if player != &"":
		var verdict := act("choose_country", {"tag": player})
		if not bool(verdict.get("ok", false)):
			push_warning("Session: cannot choose %s: %s" % [String(player), str(verdict.get("reason", ""))])
	return ""


## The human player's country tag, or &"" with no game.
func player_tag() -> StringName:
	return game.player if game != null else &""


## The same map or scenario and player with seed + 1 (Ctrl/Cmd+R). Does nothing for a game put in place.
func reseed() -> void:
	if game == null or _origin.is_empty():
		return
	var next_seed := game.seed_value + 1
	var origin := _origin.duplicate()
	var scenario_id := str(origin["scenario_id"])
	if scenario_id.is_empty():
		new_game(str(origin["map_id"]), next_seed)
	else:
		new_scenario(scenario_id, next_seed, origin["player"] as StringName)


func _process(delta: float) -> void:
	if game != null and not get_tree().paused:
		play_seconds += SimClock.delta(delta)


## Puts a game that exists already in place (a loaded save, a test's game over a made-up map).
func start_game(new_game_value: Game, slot: String = "", seconds: float = 0.0, ui: Dictionary = {}) -> void:
	game = new_game_value
	_in_season = false
	if game.has_countries() and game.orders == null:
		AiPlayers.attach(game, _passive).enabled = ai_enabled
	_origin = {}
	unsaved_actions = 0
	play_seconds = seconds
	current_slot = slot
	last_phase_ms = {}
	_loaded_ui = ui
	Events.game_started.emit()


## Ends the current game cleanly, resets unsaved_actions, and emits Events.game_ended.
func end_game() -> void:
	game = null
	_in_season = false
	_origin = {}
	unsaved_actions = 0
	play_seconds = 0.0
	current_slot = ""
	last_phase_ms = {}
	_loaded_ui = {}
	Events.game_ended.emit()


## The fixed map of an id, read once.
func map_of(map_id: String) -> MapData:
	if _maps.has(map_id):
		return _maps[map_id]
	for ext: String in ["tres", "res"]:
		var path := "res://data/maps/%s.%s" % [map_id, ext]
		if ResourceLoader.exists(path):
			var map := load(path) as MapData
			if map != null:
				_maps[map_id] = map
				return map
	return null


## Whether the action may be done now: {ok, reason}. Changes nothing.
func check(action: String, args: Dictionary) -> Dictionary:
	if game == null:
		return {"ok": false, "reason": "no game"}
	if _in_season:
		return {"ok": false, "reason": WAIT_TEXT}
	return game.check(action, _for_player(args))


## Does the action: {ok, reason}. Each event the rules queued becomes one Events signal.
func act(action: String, args: Dictionary) -> Dictionary:
	if game == null:
		return {"ok": false, "reason": "no game"}
	if _in_season:
		return {"ok": false, "reason": WAIT_TEXT}
	var verdict := game.act(action, _for_player(args))
	if bool(verdict.get("ok", false)):
		unsaved_actions += 1
	drain()
	return verdict


## May the season end now: {ok, reason}. Changes nothing.
func end_season_check() -> Dictionary:
	if game == null:
		return {"ok": false, "reason": "no game"}
	return Season.end_check(game)


## The computer's turn of the game, or null (no hook, or another kind).
func ai() -> AiTurn:
	return game.orders as AiTurn if game != null else null


## Between begin_season and finish_season.
func in_season() -> bool:
	return _in_season


## Begins the season: checks, logs it, begins the computer's turn and drains. {ok, reason}; refused with nothing changed.
func begin_season() -> Dictionary:
	if _in_season:
		return {"ok": false, "reason": "the season is running"}
	var verdict := end_season_check()
	if not bool(verdict.get("ok", false)):
		return verdict
	last_phase_ms = {"ai_orders": 0.0}
	ai_worst_step_ms = 0.0
	Season.begin(game)
	Season.orders_begin(game)
	drain()
	_in_season = true
	return verdict


## Runs AI steps while the time since the call is under `budget_ms` (one at least), draining after each; true when the
## turn is over. last_phase_ms["ai_orders"] sums the steps, ai_worst_step_ms is the worst one.
func step_orders(budget_ms: float) -> bool:
	if not _in_season:
		return true
	var started := SimClock.usec()
	while true:
		var t0 := SimClock.usec()
		var done := Season.orders_step(game)
		drain()
		var now := SimClock.usec()
		var step_ms := float(now - t0) / 1000.0
		last_phase_ms["ai_orders"] = float(last_phase_ms.get("ai_orders", 0.0)) + step_ms
		ai_worst_step_ms = maxf(ai_worst_step_ms, step_ms)
		if done:
			return true
		if float(now - started) / 1000.0 >= budget_ms:
			return false
	return true


## (seats done, seats) of the computer's turn; (0, 0) with no hook.
func orders_progress() -> Vector2i:
	var hook: OrdersHook = game.orders if game != null else null
	return Vector2i(hook.seats_done(), hook.seats()) if hook != null else Vector2i.ZERO


## Ends the orders and runs each phase from movement on (draining after each), then emits season_ended once. A played
## season counts as an unsaved action.
func finish_season() -> void:
	while not finish_step():
		pass


## One step of the season's end (issue 441, the flow runs one a frame): step 0 is the orders' end, then each phase from
## movement on (draining after each), then the finish, whose step emits season_ended once. The same calls in the same
## order as finish_season, which runs them all. Returns true when the season is over (or was not running). Nothing else
## can act between the steps: act and check are refused while in season.
func finish_step() -> bool:
	if not _in_season:
		_finish_next = 0
		return true
	var phases: Array[StringName] = []
	for phase: StringName in Season.PHASES:
		if phase != &"ai_orders":
			phases.append(phase)
	if _finish_next == 0:
		_ended_turn = game.turn
		var started := SimClock.usec()
		Season.orders_end(game)
		drain()
		last_phase_ms["ai_orders"] = float(last_phase_ms.get("ai_orders", 0.0)) + float(SimClock.usec() - started) / 1000.0
	elif _finish_next <= phases.size():
		var phase: StringName = phases[_finish_next - 1]
		var started := SimClock.usec()
		Season.run_phase(game, phase)
		last_phase_ms[String(phase)] = float(SimClock.usec() - started) / 1000.0
		drain()
	else:
		Season.finish(game)
		unsaved_actions += 1
		_in_season = false
		_finish_next = 0
		Events.season_ended.emit(_ended_turn)
		return true
	_finish_next += 1
	return false


## Ends the season at once: begin_season, every AI step, finish_season. Refused with {ok: false, reason} and nothing
## changed. The console's and the tests' way; the flow slices the same calls.
func end_season() -> Dictionary:
	var verdict := begin_season()
	if not bool(verdict.get("ok", false)):
		return verdict
	step_orders(INF)
	finish_season()
	return verdict


## Developer console: makes the game AI-only (Game.watch, during the country pick). False when refused.
func watch() -> bool:
	if game == null or _in_season:
		return false
	var done := game.watch()
	drain()
	if done:
		unsaved_actions += 1
	return done


## Developer console: the AI leaves a country alone (or plays it again). Kept for later games.
func set_seat_passive(tag: StringName, on: bool) -> void:
	_passive.erase(tag)
	if on:
		_passive.append(tag)
	var hook := ai()
	if hook != null:
		hook.passive = _passive.duplicate()


## Developer console only: gives land to a country by tag ("" frees it), logged for the replay, then drains. Returns how
## many hexes changed; 0 with no game or an unknown tag.
func dev_transfer(hexes: Array[Vector2i], tag: StringName) -> int:
	if game == null:
		return 0
	var to_id := 0
	if tag != &"":
		if not game.has_countries():
			return 0
		to_id = game.scenario.id_of(tag)
		if to_id == 0:
			return 0
	var changed := game.dev_transfer(hexes, to_id)
	drain()
	return changed


## Developer console only: gives (or takes, with a negative amount) ducats, logged for the replay, then drains. False
## with no game, in a map-only game, for an unknown tag or when the treasury would pass its limit.
func dev_money(tag: StringName, amount: int) -> bool:
	if game == null:
		return false
	var done := game.dev_money(tag, amount)
	drain()
	return done


## Developer console only: gives (or takes) loads of a good by its id, logged for the replay, then drains. False with no
## game, in a map-only game or for an unknown tag or good.
func dev_goods(tag: StringName, good: int, amount: int) -> bool:
	if game == null:
		return false
	var done := game.dev_goods(tag, good, amount)
	drain()
	return done


## Developer console only: sets the people of a hex, logged for the replay, then drains. False with no game, for a value
## below 0 or when People.move refuses (sea, off the map, unowned land, a map-only game, a result over its limit).
func dev_people(hex: Vector2i, people_value: int) -> bool:
	if game == null:
		return false
	var done := game.dev_people(hex, people_value)
	drain()
	return done


## Saves the game to a slot ("quick", "1" to "8", "auto1" to "auto3"): the file with the wall clock, play_seconds and the
## build, then the thumbnail PNG (a null thumbnail removes an old picture). On success unsaved_actions is 0 and
## current_slot the slot. Returns "" or the problem; nothing changes on a problem.
func save_game(slot: String, thumbnail: Image = null, ui: Dictionary = {}, name: String = "") -> String:
	if game == null:
		return NO_GAME
	if not (SaveFile.SLOTS.has(slot) or SaveFile.AUTO_SLOTS.has(slot)):
		return "no slot '%s'" % slot
	var info := {
		"build": str(ProjectSettings.get_setting("application/config/version", "0.3.0")),
		"name": name, "saved_unix": int(Time.get_unix_time_from_system()), "play_seconds": int(play_seconds),
		"map_digest": _map_digest(game.map),
	}
	var problem := SaveFile.write(game, slot, info, ui, save_dir, save_json)
	if not problem.is_empty():
		return problem
	var png := save_dir.path_join(slot + ".png")
	if thumbnail != null and not thumbnail.is_empty():
		thumbnail.save_png(png)
	elif FileAccess.file_exists(png):
		DirAccess.remove_absolute(png)
	unsaved_actions = 0
	current_slot = slot
	return ""


## Saves to the next autosave slot (the first empty, else the oldest).
func autosave_game(thumbnail: Image, ui: Dictionary) -> String:
	return save_game(SaveFile.auto_slot(save_dir), thumbnail, ui)


## Loads a slot and starts its game. Returns "" or the problem ("Cannot be read", "Made for another map", "The save is
## damaged" ...); nothing starts on a problem. The ui block is then in loaded_ui().
func load_game(slot: String) -> String:
	if not SaveFile.is_slot(slot):
		return "no slot '%s'" % slot
	var read := SaveFile.read(slot, save_dir)
	if not str(read["problem"]).is_empty():
		return str(read["problem"])
	var header := read["header"] as Dictionary
	var mismatch := _mismatch(header)
	if not mismatch.is_empty():
		return mismatch
	var map := map_of(str(header["map_id"]))
	var restored := Snapshot.restore(read["body"] as Dictionary, map, defs())
	if not str(restored["problem"]).is_empty():
		return str(restored["problem"])
	var loaded := restored["game"] as Game
	if loaded == null:
		return Snapshot.PROBLEM_UNREADABLE
	if loaded.digest() != str(header["digest"]):
		return DAMAGED
	start_game(loaded, slot, float(int(header["play_seconds"])), restored["ui"] as Dictionary)
	return ""


## The ui block of the last load ({} after a new game).
func loaded_ui() -> Dictionary:
	return _loaded_ui


## One row per slot, the three autosaves first, then quick and 1 to 8: {slot, state, header, thumbnail}. Headers only.
## `state` is empty, ok, newer, older, broken, other_map or other_build.
func list_saves() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var slots: Array[String] = []
	slots.append_array(SaveFile.AUTO_SLOTS)
	slots.append_array(SaveFile.SLOTS)
	for slot: String in slots:
		var info := SaveFile.read_header(slot, save_dir)
		var header := info["header"] as Dictionary
		var state := info["state"] as StringName
		if state == &"ok":
			var mismatch := _mismatch(header)
			if mismatch == Snapshot.PROBLEM_OTHER_MAP:
				state = &"other_map"
			elif mismatch == Snapshot.PROBLEM_OTHER_BUILD:
				state = &"other_build"
		var png := save_dir.path_join(slot + ".png")
		rows.append({"slot": slot, "state": state, "header": header,
				"thumbnail": png if FileAccess.file_exists(png) else ""})
	return rows


## The loadable save (state ok) with the newest saved_unix, or {} (the first of equals in list order).
func newest_save() -> Dictionary:
	var best := {}
	var best_unix := -1
	for row: Dictionary in list_saves():
		if row["state"] != &"ok":
			continue
		var stamp := int((row["header"] as Dictionary)["saved_unix"])
		if stamp > best_unix:
			best = row
			best_unix = stamp
	return best


## Deletes every file of a slot (.sav, .bak, .tmp, .png, .body.json).
func delete_save(slot: String) -> bool:
	if not (SaveFile.SLOTS.has(slot) or SaveFile.AUTO_SLOTS.has(slot)):
		return false
	var ok := SaveFile.remove(slot, save_dir)
	if current_slot == slot:
		current_slot = ""
	return ok


## "" when the header's map and scenario are here and unchanged, else PROBLEM_OTHER_MAP or PROBLEM_OTHER_BUILD.
func _mismatch(header: Dictionary) -> String:
	var map := map_of(str(header["map_id"]))
	if map == null or _map_digest(map) != str(header["map_digest"]):
		return Snapshot.PROBLEM_OTHER_MAP
	var scenario_id := str(header["scenario_id"])
	if not scenario_id.is_empty():
		var game_defs := defs()
		var scenario := game_defs.scenario(scenario_id) if game_defs != null else null
		if scenario == null or _scenario_digest(game_defs, scenario) != str(header["scenario_digest"]):
			return Snapshot.PROBLEM_OTHER_BUILD
	return ""


## Cached per map instance (a different MapData with the same id hashes again).
func _map_digest(map: MapData) -> String:
	var key := map.get_instance_id()
	if not _map_digests.has(key):
		_map_digests[key] = map.digest()
	return _map_digests[key]


## Cached per scenario id for one defs instance; a new GameDefs empties the cache.
func _scenario_digest(game_defs: GameDefs, scenario: ScenarioDef) -> String:
	if _scenario_digests_of != game_defs:
		_scenario_digests = {}
		_scenario_digests_of = game_defs
	var key := "%s:%d" % [scenario.id, scenario.get_instance_id()]
	if not _scenario_digests.has(key):
		_scenario_digests[key] = scenario.digest()
	return _scenario_digests[key]


## Empties game.events into Events signals. act() calls it; so do tools and tests that call a system directly.
func drain() -> void:
	if game == null:
		return
	var queued := game.events.duplicate()
	game.events.clear()
	for event: Dictionary in queued:
		match str(event.get("kind", "")):
			"hex_changed":
				Events.hex_changed.emit(event["hex"])
			"owners_changed":
				var hexes: Array[Vector2i] = []
				hexes.assign(event["hexes"] as Array)
				Events.owners_changed.emit(hexes)
			"country_chosen":
				Events.country_chosen.emit(StringName(event["tag"]))
			"work_started":
				Events.work_started.emit(StringName(event["tag"]), event["hex"], event["work"])
			"work_finished":
				Events.work_finished.emit(StringName(event["tag"]), event["hex"], event["work"])
			"work_cancelled":
				Events.work_cancelled.emit(StringName(event["tag"]), event["hex"], event["work"], StringName(event["why"]))
			"goods_short":
				Events.goods_short.emit(StringName(event["tag"]), StringName(event["good"]))
			"tax_set":
				Events.tax_set.emit(StringName(event["tag"]), int(event["level"]))
			"town_grew":
				Events.town_grew.emit(StringName(event["tag"]), event["hex"], int(event["level"]))
			"district_declined":
				Events.district_declined.emit(StringName(event["tag"]), event["hex"], int(event["level"]),
					StringName(event["why"]))
			"army_raised":
				Events.army_raised.emit(StringName(event["tag"]), event["hex"], int(event["army"]))
			"army_disbanded":
				Events.army_disbanded.emit(StringName(event["tag"]), event["hex"], int(event["army"]))
			"army_changed":
				Events.army_changed.emit(StringName(event["tag"]), int(event["army"]))
			"unit_moved":
				var path: Array[Vector2i] = []
				path.assign(event["path"] as Array)  # typed before the emit (A11)
				Events.unit_moved.emit(StringName(event["tag"]), int(event["army"]), path,
					event["seen"] as PackedByteArray, event["ticks"] as PackedInt32Array)
			"march_halted":
				Events.march_halted.emit(StringName(event["tag"]), int(event["army"]), StringName(event["why"]))
			"army_starved":
				Events.army_starved.emit(StringName(event["tag"]), int(event["army"]), int(event["lost"]))
			"unit_lost":
				Events.unit_lost.emit(StringName(event["tag"]), int(event["army"]), int(event["unit"]))
			"war_declared":
				Events.war_declared.emit(StringName(event["tag"]), StringName(event["target"]))
			"peace_made":
				Events.peace_made.emit(StringName(event["tag"]), StringName(event["target"]), StringName(event["terms"]))
			"battle_started":
				Events.battle_started.emit(event["hex"], StringName(event["tag"]), StringName(event["defender"]))
			"battle_joined":
				Events.battle_joined.emit(event["hex"], StringName(event["tag"]))
			"battle_fought":
				Events.battle_fought.emit(event["hex"])
			"battle_ended":
				Events.battle_ended.emit(event["hex"], int(event["record"]), StringName(event["winner"]))
			"siege_started":
				Events.siege_started.emit(event["hex"], StringName(event["tag"]))
			"siege_progress":
				Events.siege_progress.emit(event["hex"], StringName(event["tag"]), int(event["progress"]), int(event["need"]))
			"siege_lifted":
				Events.siege_lifted.emit(event["hex"], StringName(event["tag"]), StringName(event["why"]))
			"district_captured":
				Events.district_captured.emit(event["hex"], StringName(event["tag"]), StringName(event["by"]))
			"controllers_changed":
				var changed: Array[Vector2i] = []
				changed.assign(event["hexes"] as Array)  # typed before the emit (A11)
				Events.controllers_changed.emit(changed)
		if Chronicle.NOTABLE.has(str(event.get("kind", ""))):
			Events.chronicled.emit(Chronicle.plain(event))


## In a game with countries, args without a `tag` speak for the player: a copy gets tag = game.player.
func _for_player(args: Dictionary) -> Dictionary:
	if game == null or not game.has_countries() or args.has("tag"):
		return args
	var filled := args.duplicate()
	filled["tag"] = game.player
	return filled
