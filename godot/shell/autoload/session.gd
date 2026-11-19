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
## Phase name -> milliseconds the last season spent in it (F3, perf).
var last_phase_ms: Dictionary = {}

const DEFS := "res://data/defs/game_defs.tres"

var _maps: Dictionary[String, MapData] = {}
var _defs: GameDefs = null
## What the current game was made from, for reseed: {map_id, scenario_id, player}; empty for a game put in place.
var _origin: Dictionary = {}


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
		play_seconds += delta


## Puts a game that exists already in place (a loaded save, a test's game over a made-up map).
func start_game(new_game_value: Game) -> void:
	game = new_game_value
	_origin = {}
	unsaved_actions = 0
	play_seconds = 0.0
	current_slot = ""
	last_phase_ms = {}
	Events.game_started.emit()


## Ends the current game cleanly, resets unsaved_actions, and emits Events.game_ended.
func end_game() -> void:
	game = null
	_origin = {}
	unsaved_actions = 0
	play_seconds = 0.0
	current_slot = ""
	last_phase_ms = {}
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
	return game.check(action, _for_player(args))


## Does the action: {ok, reason}. Each event the rules queued becomes one Events signal.
func act(action: String, args: Dictionary) -> Dictionary:
	if game == null:
		return {"ok": false, "reason": "no game"}
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


## Ends the season: checks, logs it, runs each phase and drains the events after it, then emits season_ended once.
## Refused with {ok: false, reason} and nothing changed. A played season counts as an unsaved action.
func end_season() -> Dictionary:
	var verdict := end_season_check()
	if not bool(verdict.get("ok", false)):
		return verdict
	var ended_turn := game.turn
	last_phase_ms = {}
	Season.begin(game)
	for phase: StringName in Season.PHASES:
		var started := Time.get_ticks_usec()
		Season.run_phase(game, phase)
		last_phase_ms[String(phase)] = float(Time.get_ticks_usec() - started) / 1000.0
		drain()
	Season.finish(game)
	unsaved_actions += 1
	Events.season_ended.emit(ended_turn)
	return verdict


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
		if Chronicle.NOTABLE.has(str(event.get("kind", ""))):
			Events.chronicled.emit(Chronicle.plain(event))


## In a game with countries, args without a `tag` speak for the player: a copy gets tag = game.player.
func _for_player(args: Dictionary) -> Dictionary:
	if game == null or not game.has_countries() or args.has("tag"):
		return args
	var filled := args.duplicate()
	filled["tag"] = game.player
	return filled
