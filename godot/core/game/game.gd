## The game core (docs/architecture/m1-build-spec.md section 8, m2-build-spec.md section 5.4 and 5.9):
## the fixed map, definitions, scenario, what changed on the map (MapState), countries, and the door every player
## action goes through. The rules append events and the shell's Session drains them; the game never reads an autoload.
class_name Game
extends RefCounted

var map: MapData = null
var state: MapState = null
var seed_value: int = 0
## Appended by the rules, drained by Session.
var events: Array[Dictionary] = []
## The improvement rules' working context (facts, neighbour tables, counts). Derived from map and state; it writes
## `state` and nothing else. Use Improve, not this, from outside core/game.
var improvement: WorldImprove = null
## Fixed game definitions; null in a map-only game in M2.
var defs: GameDefs = null
## Fixed scenario data; null in a map-only game.
var scenario: ScenarioDef = null
## Country state in 1-based id order (`countries[id - 1]`).
var countries: Array[Country] = []
## Human player's country tag, or &"" before picking, in AI-only games, or in a map-only game.
var player: StringName = &""
## The fields only the door (emit, act, Season) writes (docs/architecture/m3-build-spec.md 5.7).
const DOOR_FIELDS: Array[String] = ["events", "action_log", "chronicle", "version", "view_cache"]
## The year of turn 1 (the scenario's year; 1480 in a sandbox).
var start_year: int = Calendar.DEFAULT_YEAR
## The season count, from 1. Written by Calendar only.
var turn: int = Calendar.FIRST_TURN
## The notable events, written only by emit.
var chronicle: Chronicle = Chronicle.new()
## Every accepted action, the season ends and developer transfers: {turn, action, args}.
var action_log: Array[Dictionary] = []
## The three luck streams (rules, AI, looks).
var luck: Luck = null
## One more for each accepted action and each season; not saved. View caches key on it.
var version: int = 0
## Derived views; not saved.
var view_cache: ViewCache = ViewCache.new()
## The ring and year rows of numbers; written only by StatsSystem.
var stats: Stats = null


## A new map-only game: the improvement search chooses what stands on the map for this seed.
static func new_game(p_map: MapData, p_seed: int, p_defs: GameDefs = null) -> Game:
	var out := Game.new()
	out.map = p_map
	out.seed_value = p_seed
	out.defs = p_defs
	out.luck = Luck.seeded(p_seed)
	out.improvement = WorldImprove.build(p_map, p_seed)
	out.state = out.improvement.state
	# Called by reference: a typed call would make Game and StatsSystem need each other to parse.
	StatsSystem.setup.call(out)
	return out


## A new scenario game: runs the improvement search, then sets up countries and territory ownership.
static func new_scenario(p_map: MapData, p_defs: GameDefs, p_scenario: ScenarioDef, p_seed: int) -> Game:
	assert(p_map != null, "new_scenario requires a map")
	assert(p_scenario != null, "new_scenario requires a scenario")
	assert(p_scenario.map_id == p_map.id, "scenario map_id '%s' does not match map.id '%s'" % [
		p_scenario.map_id, p_map.id])
	var out := new_game(p_map, p_seed, p_defs)
	out.scenario = p_scenario
	out.start_year = p_scenario.year
	Countries.setup(out, p_scenario)
	Territory.setup(out, p_scenario)
	StatsSystem.setup.call(out)  # again, now that the countries are known
	return out


## A game over a state that exists already (a test, a load): no search.
static func with_state(p_map: MapData, p_state: MapState, p_seed: int = 0, p_defs: GameDefs = null) -> Game:
	var out := Game.new()
	out.map = p_map
	out.seed_value = p_seed
	out.defs = p_defs
	out.luck = Luck.seeded(p_seed)
	out.state = p_state
	out.improvement = WorldImprove.over(p_map, p_state)
	return out


## True when playing a scenario with countries (false in a map-only sandbox).
func has_countries() -> bool:
	return scenario != null


## Queues an event for the shell, stamps it with the turn, and chronicles it when it is notable. Rules call this and
## never append to `events` themselves.
func emit(event: Dictionary) -> void:
	if not event.has("turn"):
		event["turn"] = turn
	events.append(event)
	if Chronicle.NOTABLE.has(str(event.get("kind", ""))):
		chronicle.add(event)


## "Winter 1480".
func date_text() -> String:
	return Calendar.date_text(turn, start_year)


## Developer transfer of land (logged for the replay): Territory.transfer plus its action log record.
func dev_transfer(hexes: Array[Vector2i], to_id: int) -> int:
	# Called by reference: a typed call would make Game and Territory need each other to parse.
	var changed: int = Territory.transfer.call(self, hexes, to_id)
	action_log.append({"turn": turn, "action": "dev_transfer", "args": Chronicle.plain({"hexes": hexes, "to_id": to_id})})
	if changed > 0:
		version += 1  # owner-derived views are cached by version
	return changed


## Whether the action may be done now: {ok, reason} ("" when ok). Changes nothing.
func check(action: String, args: Dictionary) -> Dictionary:
	var pair := Actions.pair_of(action)
	if pair.is_empty():
		return {"ok": false, "reason": "unknown action: " + action}
	return pair[0].call(self, args)


## Does the action (after checking again): {ok, reason}. A refused action changes nothing and queues nothing.
func act(action: String, args: Dictionary) -> Dictionary:
	var pair := Actions.pair_of(action)
	if pair.is_empty():
		return {"ok": false, "reason": "unknown action: " + action}
	var verdict: Dictionary = pair[1].call(self, args)
	if bool(verdict.get("ok", false)):
		action_log.append({"turn": turn, "action": action, "args": Chronicle.plain(args)})
		version += 1
	return verdict


## SHA-256 (hex text) of the game: map id, seed, scenario id, player, start year, turn, state digest, each country's
## digest_text, stats (R5), chronicle and luck.
func digest() -> String:
	var map_id := map.id if map != null else ""
	var scen_id := scenario.id if scenario != null else ""
	var state_digest := state.digest() if state != null else ""
	var parts: PackedStringArray = [map_id, str(seed_value), scen_id, String(player), str(start_year), str(turn),
		state_digest]
	for c: Country in countries:
		parts.append(c.digest_text() if c != null else "")
	parts.append(stats.digest() if stats != null else "")
	parts.append(chronicle.digest())
	parts.append(luck.digest_text() if luck != null else "")
	return "|".join(parts).sha256_text()
