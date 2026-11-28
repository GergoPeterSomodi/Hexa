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
## The armies in id order; written only by Armies (docs/architecture/m6-build-spec.md 5.0 R2, 5.2).
var armies: Array[Army] = []
## The next army id and the next unit id (from 1, never reused); written only by Armies.
var next_army_id: int = 1
var next_unit_id: int = 1
## The war state (docs/architecture/m7-build-spec.md 5.2); the writers are named beside each field.
var wars: Array[War] = []                     # Wars; id order
var next_war_id: int = 1                      # Wars
var battles: Array[Battle] = []               # Battles; hex index order; empty at idle
var battle_records: Array[BattleRecord] = []  # Battles; id order, the newest kept
var next_record_id: int = 1                   # Battles
var battle_names: Dictionary = {}             # Battles: place (String) -> battles named there
var sieges: Array[Siege] = []                 # Sieges; hex index order
var siege_names: Dictionary = {}              # Sieges: place -> sieges named there
## The End-turn leg's marks (moves-build-spec.md R22a), army id -> &"phase" (its walk took a step in this End turn's movement
## phase: no End-turn leg) or &"next" (its points are the next season's already: the End-turn leg walked it, or a battle of that
## leg ended its season; ready_units keeps them). Written by MovementPhase (season, next_leg) and cleared by Allowance.refill:
## empty at idle, not saved, not in the digest.
var leg_marks: Dictionary = {}
## Human player's country tag, or &"" before picking, in AI-only games, or in a map-only game.
var player: StringName = &""
## Who gives the other countries' orders in the ai_orders phase, or null (M8 4.2): not saved, not in the digest; set by
## Session, the tools and the tests. Game.new_scenario attaches none.
var orders: OrdersHook = null
## True when every country is played by the computer (M8 D31, 4.12): saved, in the digest, written only by watch().
var ai_only := false
## The fields only the door (emit, act, Season) writes (docs/architecture/m3-build-spec.md 5.7).
const DOOR_FIELDS: Array[String] = ["events", "action_log", "chronicle", "version", "view_cache", "districts", "sight",
	"war_cache"]
## The largest developer transfer of ducats or loads at once (dev_money, dev_goods).
const DEV_LIMIT := 1000000000
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
## Per climate (snow, frost, mild): 0 calm, 1 good, 2 poor. Written only by Calendar; a new game starts calm.
var weather: PackedByteArray = PackedByteArray([0, 0, 0])
## The season-free part of every land hex's district output; derived, not saved, not in the digest. Forgets a hex and
## its ring on a hex_changed (emit); cleared by a new game, a load and any replaced MapState.
var districts: DistrictCache = DistrictCache.new()
## The sight cache (the army part, the land sight, what each viewer has learned); derived, not saved, not in the digest.
## Written only through Sight (by reference).
var sight: SightCache = SightCache.new()
## The occupation door's derived lists (castle areas, control); not saved, not in the digest. Written only through Occupation.
var war_cache: WarCache = WarCache.new()


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
	People.setup.call(out)
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
	out.districts.clear()
	# Called by reference (A14): nobody occupies anything and every fortress holds its full garrison (M7 4.3, B13).
	Occupation.setup.call(out)
	Recruiting.setup.call(out, p_scenario)  # the scenario's barracks, or the capitals' (recruitment-queue.md 4.1)
	# Called by reference (the layer rule: a typed call from game into systems makes the files need each other to parse).
	People.setup.call(out)  # before the purse: the start treasury counts the people (M5 spec 5.4)
	Treasury.setup.call(out)
	Stores.setup.call(out)
	# The scenario's starting armies (none in 1480): after the purse and the people, so their men are levied from the final table.
	Military.setup_start_armies.call(out, p_scenario)
	StatsSystem.setup.call(out)  # again, now that the countries are known
	Sight.setup.call(out)  # explored = the land sight (5.0 R11: only here, never on a load)
	Sight.refresh.call(out)
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
	out.districts.clear()
	if p_defs != null and p_state.people.count(0) == p_state.people.size():
		People.setup.call(out)  # a state with no people yet (a test's, an older save's) starts with M4's table
	return out


## True when playing a scenario with countries (false in a map-only sandbox).
func has_countries() -> bool:
	return scenario != null


## Queues an event for the shell, stamps it with the turn, and chronicles it when it is notable. Rules call this and
## never append to `events` themselves.
func emit(event: Dictionary) -> void:
	if not event.has("turn"):
		event["turn"] = turn
	# Called by reference: owners_changed updates the sight cache; a sighted event gets its witnesses (4.11).
	Sight.on_emit.call(self, event)
	# M7 (5.4): the war cache is dropped by the changes it reads (owners, controllers, a fortress's level).
	var kind := str(event.get("kind", ""))
	if kind == "owners_changed":
		war_cache.forget_areas()
		war_cache.forget_control()
	elif kind == "controllers_changed":
		war_cache.forget_control()
	elif kind == "hex_changed" and event.get("hex") is Vector2i and map != null:
		war_cache.on_hex_changed.call(self, event["hex"] as Vector2i)  # by reference: WarCache takes a Game, Game holds a WarCache
	events.append(event)
	if event.get("kind", "") == "hex_changed" and event.get("hex") is Vector2i and map != null:
		districts.touch.call(self, event["hex"] as Vector2i)  # by reference: a typed call makes Game and DistrictCache need each other to parse
	if Chronicle.NOTABLE.has(str(event.get("kind", ""))):
		chronicle.add(event)


## "Winter 1480".
func date_text() -> String:
	return Calendar.date_text(turn, start_year)


## Makes the game AI-only (the developer's Watch, tools and tests): only during the pick (no player yet), in a game with
## countries, once. Logged for the replay; false (nothing changed or logged) otherwise.
func watch() -> bool:
	if not has_countries() or player != &"" or ai_only:
		return false
	ai_only = true
	action_log.append({"turn": turn, "action": "watch", "args": {}})
	version += 1
	return true


## Developer transfer of land (logged for the replay): Territory.transfer plus its action log record.
func dev_transfer(hexes: Array[Vector2i], to_id: int) -> int:
	# M7 (5.4): the land that will change owner is released from any occupation first (one controllers_changed); a refused
	# or no-op transfer releases nothing.
	var moving: Array[Vector2i] = Occupation.changing_hexes.call(self, hexes, to_id)
	if not moving.is_empty():
		Occupation.release.call(self, moving)
		Occupation.flush.call(self)
	# Called by reference: a typed call would make Game and Territory need each other to parse.
	var changed: int = Territory.transfer.call(self, hexes, to_id)
	action_log.append({"turn": turn, "action": "dev_transfer", "args": Chronicle.plain({"hexes": hexes, "to_id": to_id})})
	Sight.refresh.call(self)
	if changed > 0:
		version += 1  # owner-derived views are cached by version
	return changed


## Developer transfer of ducats (logged for the replay): Treasury.move with the reason `dev`; the amount is cut to
## plus or minus DEV_LIMIT. False in a map-only game, for an unknown tag or when the treasury would pass its limit.
func dev_money(tag: StringName, amount: int) -> bool:
	if not has_countries():
		return false
	var cut := clampi(amount, -DEV_LIMIT, DEV_LIMIT)
	var done: bool = Treasury.move.call(self, tag, cut, &"dev")
	if done:
		action_log.append({"turn": turn, "action": "dev_money", "args": {"tag": String(tag), "amount": cut}})
		version += 1
	return done


## Developer set of the people on a hex (logged for the replay, M5 spec 5.4): People.move with the flow `dev` for the
## difference. False (nothing logged) for a value below 0 or when People.move refuses (sea, off the map, unowned land, a
## map-only game, a result over People.PEOPLE_MAX).
func dev_people(hex: Vector2i, people_value: int) -> bool:
	var i := map.index_of(hex) if map != null else -1
	if i < 0 or state == null or people_value < 0 or i >= state.people.size():
		return false
	var done: bool = People.move.call(self, hex, people_value - state.people[i], &"dev")
	if done:
		action_log.append({"turn": turn, "action": "dev_people", "args": {"hex": hex, "people": people_value}})
		version += 1
	return done


## Developer transfer of goods (logged for the replay): Stores.move with the flow `dev`; the amount is cut to plus or
## minus DEV_LIMIT and a take to what the stores hold. False in a map-only game, for an unknown tag or good.
func dev_goods(tag: StringName, good: int, amount: int) -> bool:
	if not has_countries():
		return false
	var cut := clampi(amount, -DEV_LIMIT, DEV_LIMIT)
	var held: Country = Countries.by_tag.call(self, tag)
	if held != null and good >= 0 and good < held.stock.size():
		cut = maxi(cut, -held.stock[good])
	var done: bool = Stores.move.call(self, tag, good, cut, &"dev")
	if done:
		action_log.append({"turn": turn, "action": "dev_goods", "args": {"tag": String(tag), "good": good, "amount": cut}})
		version += 1
	return done


## Developer barracks (logged for the replay, recruitment-queue.md 6): Recruiting.finish on a settlement, whatever its
## size and owner. False (nothing logged) in a map-only game, on a hex with no settlement or one with a barracks.
func dev_barracks(hex: Vector2i) -> bool:
	if not has_countries():
		return false
	var verdict: Dictionary = Recruiting.finish.call(self, hex)
	if bool(verdict["ok"]):
		action_log.append({"turn": turn, "action": "dev_barracks", "args": {"hex": hex}})
		version += 1
	return bool(verdict["ok"])


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


## SHA-256 (hex text) of the game: map id, seed, scenario id, player and ai_only (M8), start year, turn, state digest, each country's
## digest_text, the armies (M6), the war state (M7: wars, battles and records, sieges), stats (R5), chronicle and luck; the weather (as "s,f,m") follows the turn.
func digest() -> String:
	var map_id := map.id if map != null else ""
	var scen_id := scenario.id if scenario != null else ""
	var state_digest := state.digest() if state != null else ""
	var parts: PackedStringArray = [map_id, str(seed_value), scen_id, String(player), "1" if ai_only else "0", str(start_year), str(turn),
		"%d,%d,%d" % [weather[0], weather[1], weather[2]], state_digest]
	for c: Country in countries:
		parts.append(c.digest_text() if c != null else "")
	# Called by reference (A14): the armies' digest is "next_army|next_unit" and one line per army (4.17).
	parts.append(str(Armies.digest.call(self)))
	# M7 (4.20): the war state, each system's digest by reference (the wars, the battles and records, the sieges).
	parts.append(str(Wars.digest.call(self)))
	parts.append(str(Battles.digest.call(self)))
	parts.append(str(Sieges.digest.call(self)))
	parts.append(stats.digest() if stats != null else "")
	parts.append(chronicle.digest())
	parts.append(luck.digest_text() if luck != null else "")
	return "|".join(parts).sha256_text()
