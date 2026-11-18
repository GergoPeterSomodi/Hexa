## The current game and the one door from the shell to the rules (autoload "Session"; docs/architecture/m1-build-spec.md
## section 8). The shell asks `check` and calls `act`; it never calls the rules directly and never writes the state. After
## an action Session empties the game's event queue and emits one Events signal per event. `core/` never reads this.
extends Node

## The current game, or null before the first new_game.
var game: Game = null
## Number of successful player actions since the game started (or was saved).
var unsaved_actions: int = 0

var _maps: Dictionary[String, MapData] = {}


## A new game on a map of data/maps/<map_id>.tres (or .res): runs the improvement search for the seed.
func new_game(map_id: String, seed_value: int) -> void:
	var map := map_of(map_id)
	if map == null:
		push_error("Session: no map '%s' in res://data/maps/" % map_id)
		return
	start_game(Game.new_game(map, seed_value))


## Puts a game that exists already in place (a loaded save, a test's game over a made-up map).
func start_game(new_game_value: Game) -> void:
	game = new_game_value
	unsaved_actions = 0
	Events.game_started.emit()


## Ends the current game cleanly, resets unsaved_actions, and emits Events.game_ended.
func end_game() -> void:
	game = null
	unsaved_actions = 0
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
	return game.check(action, args)


## Does the action: {ok, reason}. Each event the rules queued becomes one Events signal.
func act(action: String, args: Dictionary) -> Dictionary:
	if game == null:
		return {"ok": false, "reason": "no game"}
	var verdict := game.act(action, args)
	if bool(verdict.get("ok", false)):
		unsaved_actions += 1
	_drain()
	return verdict


func _drain() -> void:
	var queued := game.events.duplicate()
	game.events.clear()
	for event: Dictionary in queued:
		match str(event.get("kind", "")):
			"hex_changed":
				Events.hex_changed.emit(event["hex"])
