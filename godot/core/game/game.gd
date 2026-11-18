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


## A new map-only game: the improvement search chooses what stands on the map for this seed.
static func new_game(p_map: MapData, p_seed: int) -> Game:
	var out := Game.new()
	out.map = p_map
	out.seed_value = p_seed
	out.improvement = WorldImprove.build(p_map, p_seed)
	out.state = out.improvement.state
	return out


## A new scenario game: runs the improvement search, then sets up countries and territory ownership.
static func new_scenario(p_map: MapData, p_defs: GameDefs, p_scenario: ScenarioDef, p_seed: int) -> Game:
	assert(p_map != null, "new_scenario requires a map")
	assert(p_scenario != null, "new_scenario requires a scenario")
	assert(p_scenario.map_id == p_map.id, "scenario map_id '%s' does not match map.id '%s'" % [
		p_scenario.map_id, p_map.id])
	var out := new_game(p_map, p_seed)
	out.defs = p_defs
	out.scenario = p_scenario
	Countries.setup(out, p_scenario)
	Territory.setup(out, p_scenario)
	return out


## A game over a state that exists already (a test, a load): no search.
static func with_state(p_map: MapData, p_state: MapState, p_seed: int = 0) -> Game:
	var out := Game.new()
	out.map = p_map
	out.seed_value = p_seed
	out.state = p_state
	out.improvement = WorldImprove.over(p_map, p_state)
	return out


## True when playing a scenario with countries (false in a map-only sandbox).
func has_countries() -> bool:
	return scenario != null


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
	return pair[1].call(self, args)


## SHA-256 (hex text) of the game: map id, seed, scenario id, player, state digest, and each country's digest_text.
func digest() -> String:
	var map_id := map.id if map != null else ""
	var scen_id := scenario.id if scenario != null else ""
	var state_digest := state.digest() if state != null else ""
	var parts: PackedStringArray = [map_id, str(seed_value), scen_id, String(player), state_digest]
	for c: Country in countries:
		parts.append(c.digest_text() if c != null else "")
	return "|".join(parts).sha256_text()
