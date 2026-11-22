## The armies' moves (docs/architecture/m6-build-spec.md sections 4.4, 4.7, 5.0 R3, R6, R7, D13, D20, D21 and 5.3): the land an
## army of a country may stand on (`open_to`, and `open_mask` kept per owner bytes), the route of an order (`plan`: A* in the
## season's rules, with the winter rule of D20), the walk of a season (`walk_plan`, the stops it gives), the winter wait
## (`winter_at`), and the three orders with their checks (`march`, `halt`, `continue_march`). The movement phase, which walks
## every marching army, is MovementPhase (movement_phase.gd); it calls these rules, so this file never refers to it (a cycle
## of typed references would stop either script from parsing). Armies are written only through Armies. No luck; integer costs.
class_name Movement
extends RefCounted

const OWNS: Array[String] = []
const NO_HEX := Vector2i(-1, -1)
## Why an army halted (Army.halt_why); the same words are the `why` of march_halted.
const WHY_NO_WAY := &"no_way"
const WHY_BLOCKED := &"blocked"
const WHY_WINTER := &"winter"
## M7 (4.8, 4.14): the halts of a war. Shaken: too shaken to attack; battle: a battle of the other side is fought on the hex;
## enemy: a zone of control ended the leg beside an enemy army or a hostile fortress (D21, D40).
const WHY_SHAKEN := &"shaken"
const WHY_BATTLE := &"battle"
const WHY_ENEMY := &"enemy"
## A walk stopped because its army is fought in a battle (the attacker's step came first): not a halt. The order and the route
## stay (4.8: a winner goes on next season), so it is no halt word and no march_halted.
const WHY_FOUGHT := &"fought"
## The halt of a storm order: the army's order goes to none and its halt_why is this word, so continue_march resumes the storm
## (when its checks still pass) and never turns it into a march. Shown as "Halted: ..." with the halt_text.
const WHY_STORM := &"storm"
const STORM_HALT_TEXT := "its storm is halted: continue resumes it"
## Every halt a walk may end with: the army's order goes to none and its goal is kept.
const HALT_WHYS: Array[StringName] = [WHY_NO_WAY, WHY_BLOCKED, WHY_ENEMY, WHY_BATTLE, WHY_SHAKEN]
## D40: a hostile garrisoned fortress ends a leg beside it too. One line to turn off (the playtest's march to Pavia).
const ZOC_FORTRESSES := true
## The key of the shared unowned-land mask in the open-mask table (no country has an empty tag).
const UNOWNED_KEY := &""
## Plans kept per game version before the table is emptied (5.0 R3 b).
const PLANS_MAX := 256
const NO_WAY_TEXT := "no way there by land: a ridge, a great river or another country's land lies between"
const TOO_FAR_TEXT := "too far: more than %d seasons' march"
## Re-plans a walk may make in one leg before it halts (a guard; a plan never leads into a blocked step).
const MAX_REPLANS := 4

## Test seams (5.0 A12): the country pairs a test registered as at war. Cleared by clear_test_hostility in after_each.
static var _hostile: Dictionary = {}
## Counts every change of the test pairs: a plan's key holds it, so a plan made before a registration is not kept after it.
## M7's war and peace change the hostility through the game (their actions bump game.version too; see spec 4.4).
static var _hostile_revision: int = 0
## The armies by hex for one movement phase (MovementPhase builds it at its start, moves it with each step and drops it after the
## ticks): armies_on reads it while it is on, so a zone of control and a contact cost a lookup, not a scan of every army.
static var _index: Dictionary = {}
static var _indexed: bool = false
## Test seam: false makes every read the plain scan of game.armies (the equality test of the index, see test_movement_index.gd).
static var use_index: bool = true


# --- hostility (D21, D13: M7 makes it war) ---------------------------------------------------------------------------


## True when `a` and `b` are hostile: at war (Wars.at_war, M7), or a pair a test registered (the seam wins as well).
static func hostile(game: Game, a: StringName, b: StringName) -> bool:
	if a == b or a == &"" or b == &"":
		return false
	if _hostile.has(_pair(a, b)):
		return true
	return game != null and Wars.at_war(game, a, b)


## Makes `a` and `b` hostile for the tests (their land opens to each other and their armies stop each other).
static func register_test_hostility(a: StringName, b: StringName) -> void:
	_hostile[_pair(a, b)] = true
	_hostile_revision += 1


static func clear_test_hostility() -> void:
	_hostile.clear()
	_hostile_revision += 1


## True while a test has registered a hostile pair; then the caches hold nothing (the open land changes with the pair).
static func has_hostility() -> bool:
	return not _hostile.is_empty()


static func _pair(a: StringName, b: StringName) -> String:
	var x := String(a)
	var y := String(b)
	return x + "|" + y if x < y else y + "|" + x


## True when a neighbour of `hex` holds an army of a country hostile to `tag`, or a hostile garrisoned fortress (D21, D40).
static func zoc_halts(game: Game, tag: StringName, hex: Vector2i) -> bool:
	return zoc_text(game, tag, hex) != ""


## The words of the zone of control beside `hex` ("" when none applies): the first neighbour, in direction order, that holds a
## hostile army or a hostile garrisoned fortress. Nothing while no war is live (contested).
static func zoc_text(game: Game, tag: StringName, hex: Vector2i) -> String:
	if not contested(game):
		return ""
	for d: int in 6:
		var n := game.map.neighbour(hex, d)
		for a: Army in armies_on(game, n):
			if hostile(game, tag, a.tag):
				return "an army of %s stands beside it" % country_name(game, a.tag)
		if ZOC_FORTRESSES and game.map.index_of(n) >= 0 and closed_fortress(game, tag, n):
			return "a fortress of %s stands beside it" % country_name(game, Occupation.controller_tag(game, n))
	return ""


## True while a war is live or a test registers hostility: the open land and the plans then depend on the wars.
static func contested(game: Game) -> bool:
	if has_hostility():
		return true
	for w: War in game.wars:
		if w.live():
			return true
	return false


## The war state in a cache key: the pairs of the live wars, sorted (a declaration or a peace changes it).
static func war_key(game: Game) -> String:
	var pairs := PackedStringArray()
	for w: War in game.wars:
		if w.live():
			pairs.append(_pair(w.a, w.b))
	pairs.sort()
	return ";".join(pairs)


## True when `hex` holds a fortress with men in its garrison that is controlled by a country at war with `tag` (4.8: the mask
## closes it, but for the march's goal).
static func closed_fortress(game: Game, tag: StringName, hex: Vector2i) -> bool:
	if Occupation.fortress_level(game, hex) == 0 or Occupation.garrison_of(game, hex) <= 0:
		return false
	var ctl := Occupation.controller_tag(game, hex)
	return ctl != &"" and hostile(game, tag, ctl)


## Starts the phase's index of the armies by hex (the phase's own moves are kept with index_move).
static func begin_index(game: Game) -> void:
	_index.clear()
	_indexed = use_index
	if not _indexed:
		return
	for a: Army in game.armies:
		_add_to_index(game, a, a.hex)


## Drops the phase's index: every read is the plain scan again.
static func end_index() -> void:
	_index.clear()
	_indexed = false


## An army of the phase moved from `from` to `to` (index only; the army's hex is set by Armies).
static func index_move(game: Game, army: Army, from: Vector2i, to: Vector2i) -> void:
	if not _indexed:
		return
	var i := game.map.index_of(from)
	if _index.has(i):
		(_index[i] as Array).erase(army)
	_add_to_index(game, army, to)


static func _add_to_index(game: Game, army: Army, hex: Vector2i) -> void:
	var k := game.map.index_of(hex)
	if k < 0:
		return
	if not _index.has(k):
		_index[k] = []
	(_index[k] as Array).append(army)


## Every army (any country) standing on `hex`: the phase's index while one is on, else Armies.at.
static func armies_on(game: Game, hex: Vector2i) -> Array[Army]:
	if not _indexed:
		return Armies.at(game, hex)
	var out: Array[Army] = []
	var k := game.map.index_of(hex)
	if k >= 0 and _index.has(k):
		for a: Variant in _index[k] as Array:
			out.append(a as Army)
	return out


## True when an army of a country at war with `tag` stands on `hex` (the armies' hexes as they are now). The test seam does not
## count: a registered pair is blocked on the walk (M6), it is not a battle.
static func enemy_army_at(game: Game, tag: StringName, hex: Vector2i) -> bool:
	for a: Army in armies_on(game, hex):
		if a.tag != tag and Wars.at_war(game, tag, a.tag):
			return true
	return false


## The open step of a leg (4.8): the land is open to `tag`, and no hostile garrisoned fortress stands on it unless it is the goal.
static func open_step(game: Game, tag: StringName, hex: Vector2i, goal: Vector2i) -> bool:
	if not open_to(game, tag, hex):
		return false
	return hex == goal or not closed_fortress(game, tag, hex)


# --- reads -----------------------------------------------------------------------------------------------------------


## The move points of an army: its slowest company's (the least UnitDef.mp); 0 for an army with no company.
static func mp_of(game: Game, army: Army) -> int:
	var out := 0
	for u: Unit in army.units:
		var ud := Military.unit_def(game, u.kind)
		if ud != null and (out == 0 or ud.mp < out):
			out = ud.mp
	return out


## Is this season a winter (the snow closes the passes and slows the snowfields).
static func winter_now(game: Game) -> bool:
	return Calendar.is_winter(game.turn)


## A country's name for a message ("the Duchy of Milan"), or its tag when it has no definition.
static func country_name(game: Game, tag: StringName) -> String:
	var cdef := Countries.def_of(game, tag)
	if cdef != null and not cdef.name.is_empty():
		return cdef.name
	return String(tag)


## True when an army of `tag` may stand on `hex` (4.4, D13): a land hex held by `tag` or by no one, or the land of a country
## hostile to `tag` (none in M6 but a test's pair).
static func open_to(game: Game, tag: StringName, hex: Vector2i) -> bool:
	if game == null or game.map == null or game.state == null:
		return false
	var i := game.map.index_of(hex)
	if i < 0 or game.map.land[i] != 1 or i >= game.state.owner.size():
		return false
	var owner := int(game.state.owner[i])
	if owner == 0:
		return true
	var mine := Countries.by_tag(game, tag)
	if mine != null and mine.id == owner:
		return true
	var theirs := Countries.by_id(game, owner)
	return theirs != null and hostile(game, tag, theirs.tag)


## The open mask of `tag`: one byte a hex, 1 where open_to holds. Kept per owner bytes in the view cache's pinned slot
## `open_masks` (R3 a); never kept while a test registers hostility.
static func open_mask(game: Game, tag: StringName) -> PackedByteArray:
	var area := _area(game, tag)
	return area["mask"] as PackedByteArray


## The direction (0 to 5) from hex `i` to its neighbour `j`, or -1 when `j` is not next to `i`.
static func direction(map: MapData, i: int, j: int) -> int:
	for d: int in 6:
		if StepCosts.neighbour_index(map.cols, map.rows, i, d) == j:
			return d
	return -1


## The name of the pass on the edge between hexes `i` and `j` ("a pass" when it has none).
static func pass_name(map: MapData, i: int, j: int) -> String:
	for k: int in [i, j]:
		var p := int(map.pass_id[k]) if k < map.pass_id.size() else -1
		if p >= 0 and p < map.passes.size():
			var nm := str(map.passes[p].get("name", ""))
			if nm != "":
				return nm
	return "a pass"


# --- the open land (cached per owner bytes) --------------------------------------------------------------------------


## The mask and the components of `tag`'s open land. Kept in the view cache's `open_masks` table (the key is the owner bytes),
## so the unowned mask is made once and each country's mask is a copy of it with its own districts set.
static func _area(game: Game, tag: StringName) -> Dictionary:
	if game == null or game.map == null or game.state == null:
		return {"mask": PackedByteArray(), "comps": PackedInt32Array()}
	if has_hostility():
		return _make_area(game, tag, _unowned(game))
	var table := _table(game)
	if not table.has(UNOWNED_KEY):
		table[UNOWNED_KEY] = _unowned(game)
	if not table.has(tag):
		table[tag] = _make_area(game, tag, table[UNOWNED_KEY] as PackedByteArray)
	return table[tag] as Dictionary


static func _table(game: Game) -> Dictionary:
	var key: Array = [hash(game.state.owner), game.state.owner.size(), game.map.hex_count(), hash(game.state.occupier),
		hash(game.state.garrison), war_key(game)]
	return game.view_cache.pinned(&"open_masks", key, func() -> Dictionary: return {}) as Dictionary


static func _unowned(game: Game) -> PackedByteArray:
	var n := game.map.hex_count()
	var out := PackedByteArray()
	out.resize(n)
	out.fill(0)
	for i: int in mini(n, game.state.owner.size()):
		if game.map.land[i] == 1 and game.state.owner[i] == 0:
			out[i] = 1
	return out


static func _make_area(game: Game, tag: StringName, base: PackedByteArray) -> Dictionary:
	var mask := base.duplicate()
	var mine := Countries.by_tag(game, tag)
	if mine != null:
		for i: int in Territory.districts(game, mine.id):
			mask[i] = 1
	if contested(game):
		for c: Country in game.countries:
			if c != null and hostile(game, tag, c.tag):
				for i: int in Territory.districts(game, c.id):
					mask[i] = 1
		for i: int in game.war_cache.fortresses(game):
			if closed_fortress(game, tag, game.map.hex_of(i)):
				mask[i] = 0
	return {"mask": mask, "comps": PackedInt32Array()}


## The components of the open land (PathSearch.components, R7), made on first need and kept with the area.
static func _components(game: Game, tag: StringName) -> PackedInt32Array:
	var area := _area(game, tag)
	if (area["comps"] as PackedInt32Array).is_empty():
		area["comps"] = PathSearch.components(game.map, StepCosts.of(game.map, game.defs), area["mask"] as PackedByteArray)
	return area["comps"] as PackedInt32Array


# --- routes ----------------------------------------------------------------------------------------------------------


## The route of `army` to `goal` (4.4, cached per game version in the pinned slot `plans`, R3 b): {ok, hexes (from the next
## step, the goal last), cost, waits (the name of the pass the army waits at, or ""), reason ("" | "unreachable" | "too_far")}.
## A check and the order that follows it plan once.
static func plan(game: Game, army: Army, goal: Vector2i) -> Dictionary:
	var mp := mp_of(game, army)
	var key: Array = [army.id, army.hex, goal, mp, game.turn, army.tag, _hostile_revision, war_key(game),
		hash(game.state.occupier), hash(game.state.garrison)]
	var table: Dictionary = game.view_cache.pinned(&"plans", game.version, func() -> Dictionary: return {}) as Dictionary
	if table.has(key):
		return table[key] as Dictionary
	if table.size() >= PLANS_MAX:
		table.clear()
	var out := replan(game, army.tag, army.hex, goal, mp)
	table[key] = out
	return out


## The route for `tag` with `mp` move points from `from_hex` to `goal`, planned now and not kept (the phase re-plans with it).
## In winter it is planned twice, with the winter rules and the summer ones (D20): a summer route that crosses a pass closed now
## is kept (waits at the pass) unless the winter detour costs at most wait_ratio_percent of it and less than wait_extra_seasons
## of move points more.
static func replan(game: Game, tag: StringName, from_hex: Vector2i, goal: Vector2i, mp: int) -> Dictionary:
	var m := game.map
	var i_from := m.index_of(from_hex)
	if i_from < 0 or m.index_of(goal) < 0 or mp <= 0:
		return _refused("unreachable")
	var steps := StepCosts.of(m, game.defs)
	var mask := open_mask(game, tag)
	var comps := _components(game, tag)
	var i_goal := m.index_of(goal)
	var open_goal := i_goal >= 0 and mask[i_goal] == 0 and open_to(game, tag, goal)
	if mask[i_from] == 0 or open_goal:
		# An army on land no longer open to it (its hex changed owner) still walks out: its own hex is open to the search,
		# in a copy of the mask, so the cached mask and components stay as they are (a bug the L6 repro r1 showed). A march
		# ends on a hostile fortress (4.8): the goal is open to the search in the copy too.
		mask = mask.duplicate()
		mask[i_from] = 1
		if open_goal:
			mask[i_goal] = 1
		comps = PathSearch.components(m, steps, mask)
	var wade := game.defs.wade_plan_cost
	var max_cost := game.defs.march_seasons_max * mp
	if not winter_now(game):
		return _from_route(PathSearch.route(m, steps, mask, from_hex, goal, false, max_cost, wade, comps), "")
	var rw := PathSearch.route(m, steps, mask, from_hex, goal, true, max_cost, wade, comps)
	var rs := PathSearch.route(m, steps, mask, from_hex, goal, false, max_cost, wade, comps)
	if not rs.ok:
		return _from_route(rw, "")
	var closed := _closed_on(m, steps, i_from, rs.hexes)
	if closed == "":
		return _from_route(rw, "")
	var rw_cost := int(rw.cost)
	var rs_cost := int(rs.cost)
	if rw.ok and rw_cost * 100 <= rs_cost * game.defs.wait_ratio_percent \
			and rw_cost - rs_cost < game.defs.wait_extra_seasons * mp:
		return _from_route(rw, "")
	return _from_route(rs, closed)


## The name of the pass that a route (walked from hex index `from_i`) crosses while it is closed in winter, or "" when none.
static func _closed_on(m: MapData, steps: StepCosts, from_i: int, hexes: PackedInt32Array) -> String:
	var cur := from_i
	for h: int in hexes:
		var d := direction(m, cur, h)
		if d < 0:
			return ""
		if steps.cost(cur, d, true) == StepCosts.CLOSED:
			return pass_name(m, cur, h)
		cur = h
	return ""


static func _from_route(r: Dictionary, waits: String) -> Dictionary:
	if not bool(r.ok):
		return _refused(str(r.why))
	return {"ok": true, "hexes": r.hexes, "cost": r.cost, "waits": waits, "reason": ""}


static func _refused(why: String) -> Dictionary:
	return {"ok": false, "hexes": PackedInt32Array(), "cost": PathSearch.UNREACHED, "waits": "", "reason": why}


## D20 for an army of `tag` at `from_hex` whose next step is closed: {ok, waits, pass_name, detour}. It waits at the pass
## (waits, with the pass's name) or takes the winter detour (detour, from the next step). ok false: no way at all.
static func winter_at(game: Game, tag: StringName, from_hex: Vector2i, goal: Vector2i, mp: int) -> Dictionary:
	var res := replan(game, tag, from_hex, goal, mp)
	if not bool(res.ok):
		return {"ok": false, "waits": false, "pass_name": "", "detour": PackedInt32Array()}
	var waits := str(res.waits)
	if waits != "":
		return {"ok": true, "waits": true, "pass_name": waits, "detour": PackedInt32Array()}
	return {"ok": true, "waits": false, "pass_name": "", "detour": res.hexes}


## D20 for an army standing where it stands (see winter_at).
static func winter_wait(game: Game, army: Army) -> Dictionary:
	return winter_at(game, army.tag, army.hex, army.goal, mp_of(game, army))


## One season's walk of a stored route from hex index `cur`, the next step at route index `idx`, with `mp` points in the
## season's rules: the steps taken, where it stands and what is left. A WADE step only as the first step (it spends all the
## points); a step costing more than the points left only as the first step of the season (it spends them all); a BLOCKED
## or CLOSED step ends the season. {cur, idx, pts}.
static func walk_season(map: MapData, steps: StepCosts, cur: int, route: PackedInt32Array, idx: int, mp: int,
		winter: bool) -> Dictionary:
	var pts := mp
	var first := true
	while idx < route.size():
		var nxt := route[idx]
		var d := direction(map, cur, nxt)
		if d < 0:
			break
		var c := steps.cost(cur, d, winter)
		if c == StepCosts.BLOCKED or c == StepCosts.CLOSED:
			break
		if c == StepCosts.WADE or c > pts:
			if not first:
				break
			pts = 0
		else:
			pts -= c
		cur = nxt
		idx += 1
		first = false
		if pts <= 0:
			break
	return {"cur": cur, "idx": idx, "pts": pts}


## The season-by-season walk of a stored route from `from_turn` (4.4): {stops: [{turn, index}] (where the army stands at the
## end of each season: its route index), arrives_turn (the season it stands on the goal at the end of, or -1), seasons (from
## from_turn to the arrival, inclusive)}. A season the army is mustering is skipped (it stands still).
static func walk_plan(game: Game, army: Army, route: PackedInt32Array, from_turn: int) -> Dictionary:
	var stops: Array = []
	if route.is_empty():
		return {"stops": stops, "arrives_turn": from_turn, "seasons": 0}
	var steps := StepCosts.of(game.map, game.defs)
	var mp := mp_of(game, army)
	var cur := game.map.index_of(army.hex)
	var idx := 0
	var arrives := -1
	var limit := from_turn + 4 * game.defs.march_seasons_max + 2 * route.size() + 4
	var t := from_turn
	while t <= limit:
		if not army.mustering(t):
			var r := walk_season(game.map, steps, cur, route, idx, mp, Calendar.is_winter(t))
			cur = int(r.cur)
			idx = int(r.idx)
		stops.append({"turn": t, "index": idx})
		if idx >= route.size():
			arrives = t
			break
		t += 1
	var last := arrives if arrives >= 0 else limit + 1
	return {"stops": stops, "arrives_turn": arrives, "seasons": last - from_turn + 1}


## The whole-map cost to `goal` from every open hex in this season's rules (PathSearch.cost_field; M8's march).
static func cost_field(game: Game, tag: StringName, goal: Vector2i) -> PackedInt32Array:
	return PathSearch.cost_field(game.map, StepCosts.of(game.map, game.defs), open_mask(game, tag), goal, winter_now(game))


# --- orders ----------------------------------------------------------------------------------------------------------


## The check of a march (4.7): {ok, reason}.
static func march_check(game: Game, args: Dictionary) -> Dictionary:
	var v := _march_verdict(game, args)
	return {"ok": bool(v.ok), "reason": str(v.reason)}


## Orders the army to march to `goal` (its route stored, the old order and halt replaced): {ok, reason}. A refused march
## changes nothing.
static func march(game: Game, args: Dictionary) -> Dictionary:
	var v := _march_verdict(game, args)
	if not bool(v.ok):
		return {"ok": false, "reason": str(v.reason)}
	var army: Army = v.army
	var goal: Vector2i = args["goal"]
	var res: Dictionary = v.plan
	Armies.set_order(game, army, Army.ORDER_MARCH, goal, res.hexes)
	_clear_halt(game, army)
	_changed(game, army)
	return {"ok": true, "reason": ""}


## The check of a halt (the army stops where it stands): {ok, reason}. Only an army holding already is refused: a march halts,
## and a halted march (order none, goal kept) becomes a hold on a second halt.
static func halt_check(game: Game, args: Dictionary) -> Dictionary:
	var v := army_check(game, args)
	if not bool(v.ok):
		return {"ok": false, "reason": str(v.reason)}
	if (v.army as Army).order == Army.ORDER_HOLD:
		return {"ok": false, "reason": "the army holds already"}
	return {"ok": true, "reason": ""}


## Halts the army (D1, D2): a march stops with its goal and route kept, so continue_march resumes it. A halt on an army
## already halted (no order, goal kept) or with no goal gives the hold order and clears the goal and route, so the army stops
## asking for orders. Waiting is cleared. {ok, reason}.
static func halt(game: Game, args: Dictionary) -> Dictionary:
	var v := halt_check(game, args)
	if not bool(v.ok):
		return v
	var army := army_check(game, args).army as Army
	var storming := army.order == Army.ORDER_STORM
	if army.order == Army.ORDER_MARCH or storming:
		Armies.set_order(game, army, Army.ORDER_NONE, army.goal, army.route)
	else:
		Armies.set_order(game, army, Army.ORDER_HOLD, NO_HEX, PackedInt32Array())
	_clear_halt(game, army)
	if storming:
		Armies.set_halt(game, army, WHY_STORM, STORM_HALT_TEXT)
	_changed(game, army)
	return {"ok": true, "reason": ""}


## The check of continuing a halted march toward its kept goal (R: "continue"): {ok, reason}.
static func continue_check(game: Game, args: Dictionary) -> Dictionary:
	var v := army_check(game, args)
	if not bool(v.ok):
		return {"ok": false, "reason": str(v.reason)}
	var army: Army = v.army
	if army.goal == NO_HEX:
		return {"ok": false, "reason": "no march to continue"}
	if army.order == Army.ORDER_MARCH:
		return {"ok": false, "reason": "the march goes on by itself"}
	if army.order == Army.ORDER_STORM:
		return {"ok": false, "reason": "the storm goes on by itself"}
	if army.halt_why == WHY_STORM:
		# A halted storm resumes as a storm: its checks again (a war may have ended, a garrison gone).
		var s := storm_check(game, {"army": army.id, "goal": army.goal, "tag": army.tag})
		return {"ok": bool(s.ok), "reason": str(s.reason)}
	var g := goal_verdict(game, army, army.tag, army.goal)
	return {"ok": bool(g.ok), "reason": str(g.reason)}


## Continues a halted march to its kept goal: {ok, reason}.
static func continue_march(game: Game, args: Dictionary) -> Dictionary:
	var v := continue_check(game, args)
	if not bool(v.ok):
		return v
	var army := army_check(game, args).army as Army
	if army.halt_why == WHY_STORM:
		return storm(game, {"army": army.id, "goal": army.goal, "tag": army.tag})
	var res: Dictionary = goal_verdict(game, army, army.tag, army.goal).plan
	Armies.set_order(game, army, Army.ORDER_MARCH, army.goal, res.hexes)
	_clear_halt(game, army)
	_changed(game, army)
	return {"ok": true, "reason": ""}


## The verdict of a goal for an army of `tag` (4.7 rows 4 to 9) and its plan: {ok, reason, plan}.
static func goal_verdict(game: Game, army: Army, tag: StringName, goal: Vector2i) -> Dictionary:
	if game.map.index_of(goal) < 0:
		return _verdict("that is off the map")
	if not game.map.is_land(goal):
		return _verdict("armies cannot walk on water")
	if goal == army.hex:
		return _verdict("the army stands there already")
	if not open_to(game, tag, goal):
		var holder := country_name(game, Territory.owner_tag(game, goal))
		return _verdict("not your land: the %s holds it, and your armies cross no border in peace" % holder)
	if enemy_army_at(game, tag, goal):
		var attack := Battles.engage_check(game, {"army": army.id, "hex": goal, "tag": tag})
		if not bool(attack.ok):
			return _verdict(str(attack.reason))
	else:
		var stand := Military.can_stand(game, tag, goal, _adding(game, army, goal), _leaving(game, army, goal))
		if stand != "":
			return _verdict(stand)
	var res := plan(game, army, goal)
	if not bool(res.ok):
		if str(res.reason) == "too_far":
			return _verdict(TOO_FAR_TEXT % game.defs.march_seasons_max)
		return _verdict(NO_WAY_TEXT)
	var w := walk_plan(game, army, res.hexes, game.turn)
	if int(w.seasons) > game.defs.march_seasons_max:
		return _verdict(TOO_FAR_TEXT % game.defs.march_seasons_max)
	return {"ok": true, "reason": "", "plan": res}


## The check of a storm (4.7): {ok, reason}. A fortress of a country at war with the army's, with men in it, not its own walls;
## the engage check (rows 3 and 4); then the route when the army does not stand on the goal.
static func storm_check(game: Game, args: Dictionary) -> Dictionary:
	var v := _storm_verdict(game, args)
	return {"ok": bool(v.ok), "reason": str(v.reason)}


## Orders the army to storm the fortress at its goal: the route stored (none when it stands there), the order storm.
## A refused storm changes nothing. {ok, reason}.
static func storm(game: Game, args: Dictionary) -> Dictionary:
	var v := _storm_verdict(game, args)
	if not bool(v.ok):
		return {"ok": false, "reason": str(v.reason)}
	var army: Army = v.army
	var goal: Vector2i = args["goal"]
	var route := PackedInt32Array()
	if army.hex != goal:
		var res: Dictionary = v.plan
		route = res.hexes as PackedInt32Array
	Armies.set_order(game, army, Army.ORDER_STORM, goal, route)
	_clear_halt(game, army)
	_changed(game, army)
	return {"ok": true, "reason": ""}


static func _storm_verdict(game: Game, args: Dictionary) -> Dictionary:
	var goal: Variant = args.get("goal", null)
	if not (goal is Vector2i) or goal == NO_HEX:
		return _verdict("no goal given")
	var v := army_check(game, args)
	if not bool(v.ok):
		return _verdict(str(v.reason))
	var army: Army = v.army
	var g: Vector2i = goal
	if game.map.index_of(g) < 0:
		return _verdict("that is off the map")
	if not game.map.is_land(g):
		return _verdict("armies cannot walk on water")
	if Occupation.fortress_level(game, g) == 0:
		return _verdict("no walls to storm at %s" % Military.hex_text(game, g))
	var ctl := Occupation.controller_tag(game, g)
	if ctl == army.tag:
		return _verdict("your own walls")
	if not Wars.at_war(game, army.tag, ctl):
		return _verdict("not at war with %s" % _long_name(game, ctl))
	if Occupation.garrison_of(game, g) <= 0:
		return _verdict("its garrison is gone: march in to take it")
	var engage := Battles.engage_check(game, {"army": army.id, "hex": g, "tag": army.tag})
	if not bool(engage.ok):
		return _verdict(str(engage.reason))
	if army.hex == g:
		return {"ok": true, "reason": "", "army": army, "plan": {}}
	var res := goal_verdict(game, army, army.tag, g)
	return {"ok": bool(res.ok), "reason": str(res.reason), "army": army, "plan": res.plan}


## The long name of a country for a sentence ("the Duchy of Milan" with its article in the text), or "nobody".
static func _long_name(game: Game, tag: StringName) -> String:
	if tag == &"":
		return "nobody"
	var cdef := Countries.def_of(game, tag)
	if cdef != null and not cdef.long_name.is_empty():
		return cdef.long_name
	return country_name(game, tag)


static func _verdict(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "plan": {}}


## The companies an army of its country brings to `goal`: its own plus those of the country's other armies marching there.
static func _adding(game: Game, army: Army, goal: Vector2i) -> int:
	var n := army.units.size()
	for a: Army in Armies.of_country(game, army.tag):
		if a.id != army.id and a.order == Army.ORDER_MARCH and a.goal == goal:
			n += a.units.size()
	return n


## The armies of the country on `goal` that march away (they stop counting there).
static func _leaving(game: Game, army: Army, goal: Vector2i) -> PackedInt32Array:
	var out := PackedInt32Array()
	for a: Army in Armies.of_country(game, army.tag):
		if a.id != army.id and a.hex == goal and a.order == Army.ORDER_MARCH:
			out.append(a.id)
	return out


## The march's verdict with its army and plan: rows 1 to 9 of 4.7. The goal is checked before the army exists.
static func _march_verdict(game: Game, args: Dictionary) -> Dictionary:
	var goal: Variant = args.get("goal", null)
	if not (goal is Vector2i) or goal == NO_HEX:
		return {"ok": false, "reason": "no goal given", "army": null, "plan": {}}
	var v := army_check(game, args)
	if not bool(v.ok):
		return {"ok": false, "reason": str(v.reason), "army": null, "plan": {}}
	var army: Army = v.army
	var g := goal_verdict(game, army, army.tag, goal as Vector2i)
	return {"ok": bool(g.ok), "reason": str(g.reason), "army": army, "plan": g.plan}


## Rows 1 to 3 of 4.7 for an order: the army id given and existing, and the army of the country the args name.
static func army_check(game: Game, args: Dictionary) -> Dictionary:
	var id := int(args.get("army", 0))
	if id < 1:
		return {"ok": false, "reason": "no army given", "army": null}
	var army := Armies.by_id(game, id)
	if army == null:
		return {"ok": false, "reason": "no army %d" % id, "army": null}
	var tag := StringName(str(args.get("tag", "")))
	if army.tag != tag:
		return {"ok": false, "reason": "not your army: the %s commands it" % country_name(game, army.tag), "army": null}
	return {"ok": true, "reason": "", "army": army}


static func _clear_halt(game: Game, army: Army) -> void:
	Armies.set_halt(game, army, &"", "")
	Armies.set_waiting(game, army, &"")


static func _changed(game: Game, army: Army) -> void:
	game.emit({"kind": "army_changed", "tag": army.tag, "hex": army.hex, "army": army.id, "gone": false})
