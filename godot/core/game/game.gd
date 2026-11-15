## The game core, in its smallest form (docs/architecture/m1-build-spec.md section 8): the fixed map, what changed on
## it (MapState) and the door every player action goes through. No seasons, no saves, no costs yet. The rules append
## events ({kind: "hex_changed", hex}) and the shell's Session drains them; the game never reads an autoload.
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


## A new game: the improvement search (the wave function collapse) chooses what stands on the map for this seed.
static func new_game(p_map: MapData, p_seed: int) -> Game:
	var out := Game.new()
	out.map = p_map
	out.seed_value = p_seed
	out.improvement = WorldImprove.build(p_map, p_seed)
	out.state = out.improvement.state
	return out


## A game over a state that exists already (a test, a load): no search.
static func with_state(p_map: MapData, p_state: MapState, p_seed: int = 0) -> Game:
	var out := Game.new()
	out.map = p_map
	out.seed_value = p_seed
	out.state = p_state
	out.improvement = WorldImprove.over(p_map, p_state)
	return out


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


## SHA-256 (hex text) of the game: the map's id, the seed and the state. Equal games have equal digests.
func digest() -> String:
	return ("%s|%d|%s" % [map.id, seed_value, state.digest()]).sha256_text()
