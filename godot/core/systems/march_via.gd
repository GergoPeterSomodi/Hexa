## Multi-leg marches (docs/architecture/moves-build-spec.md section 3.11, R63 to R66, D29 to D31, D36): a march may pass stops
## (`via`, the hexes in order, the goal not among them) on its way to its goal. A stop is a place the route must pass, not a place
## the army halts (D29): the legs are planned one after another and joined into one route, walked under one allowance by the same
## engine (MarchLeg), which pops a stop when a step lands on it and re-plans through the stops left, never straight to the goal.
## Here: the check of the legs (`legs_verdict`, which march_check, march, continue_check and continue_march read), the plan of a
## leg from a stop (cached per game version, so a check and the act that follows plan once), the re-plans through the stops
## (`route_through`, `winter_through`) and the reads of the stops left (`left`, `ahead`). Army.via is written only by
## Armies.set_order. Movement calls this file by reference (A14), as it calls WalkNow. No luck; integer maths.
class_name MarchVia
extends RefCounted

const OWNS: Array[String] = []
const NO_HEX := Vector2i(-1, -1)
## Leg plans kept per game version before the table is emptied.
const PLANS_MAX := 256
const TOO_MANY_TEXT := "path is full: at most %d path points before the goal"
const BAD_STOPS_TEXT := "the path points are not places on the map"
const SAME_AS_ARMY_TEXT := "the army stands there already"
const SAME_AS_BEFORE_TEXT := "the same place as the path point before it"


## The stops of an order's args (`args["via"]`): an Array of Vector2i (a typed or a plain array, as a log record keeps it), or
## null when it is anything else. A missing or null `via` is no stops.
static func read_via(raw: Variant) -> Variant:
	var out: Array[Vector2i] = []
	if raw == null:
		return out
	if not (raw is Array):
		return null
	for item: Variant in raw as Array:
		if not (item is Vector2i):
			return null
		out.append(item as Vector2i)
	return out


## The check of a march through `via` to `goal` for `army` of `tag` (R63): {ok, reason, plan ({ok, hexes (the legs' hexes joined),
## cost, waits, reason}, as Movement.plan's), legs ([{from, to, hexes}]), via (the stops as hex indices)}. At most max_stops stops;
## each point differs from the one before it (the first from the army's hex); every leg is Movement.goal_verdict from the point
## before it, the room checked for the goal only (a stop is passed through). The first refusing leg's words are prefixed
## "Point 2: " (or "The goal: "). With no stops it is goal_verdict itself: today's order and today's words.
static func legs_verdict(game: Game, army: Army, tag: StringName, raw_via: Variant, goal: Vector2i) -> Dictionary:
	var read: Variant = read_via(raw_via)
	if read == null:
		return _refused(BAD_STOPS_TEXT)
	var via: Array[Vector2i] = read
	if via.is_empty():
		var g := Movement.goal_verdict(game, army, tag, goal)
		if not bool(g.ok):
			return _refused(str(g.reason), goal)
		var one := g.plan as Dictionary
		return {"ok": true, "reason": "", "plan": one, "via": PackedInt32Array(),
			"legs": [{"from": army.hex, "to": goal, "hexes": one.hexes, "cost": int(one.cost)}]}
	if via.size() > game.defs.max_stops:
		return _refused(TOO_MANY_TEXT % game.defs.max_stops)
	var points: Array[Vector2i] = via.duplicate()
	points.append(goal)
	var from := army.hex
	var hexes := PackedInt32Array()
	var legs: Array = []
	var cost := 0
	var waits := ""
	for k: int in points.size():
		var to := points[k]
		var last := k == points.size() - 1
		var prefix := "The goal: " if last else "Point %d: " % (k + 1)
		if to == from:
			return _refused(prefix + (SAME_AS_ARMY_TEXT if k == 0 else SAME_AS_BEFORE_TEXT), to)
		var g := Movement.goal_verdict(game, army, tag, to, from if k > 0 else NO_HEX, last)
		if not bool(g.ok):
			return _refused(prefix + str(g.reason), to)
		var plan := g.plan as Dictionary
		legs.append({"from": from, "to": to, "hexes": plan.hexes, "cost": int(plan.cost)})
		hexes.append_array(plan.hexes as PackedInt32Array)
		cost += int(plan.cost)
		if waits == "":
			waits = str(plan.get("waits", ""))
		from = to
	var stops := PackedInt32Array()
	for h: Vector2i in via:
		stops.append(game.map.index_of(h))
	return {"ok": true, "reason": "", "legs": legs, "via": stops,
		"plan": {"ok": true, "hexes": hexes, "cost": cost, "waits": waits, "reason": ""}}


## The verdict of a halted march's Continue (R64): its kept goal through its kept stops, from where the army stands.
static func resume_verdict(game: Game, army: Army) -> Dictionary:
	return legs_verdict(game, army, army.tag, hexes_of(game, army.via), army.goal)


## The plan of a leg of `army` from `from` (a stop; not where it stands) to `goal`: Movement.replan with the army's move points,
## kept per game version in the pinned slot `via_plans` (nothing kept while a test registers hostility, as Movement.plan).
static func plan_from(game: Game, army: Army, from: Vector2i, goal: Vector2i) -> Dictionary:
	var mp := Movement.mp_of(game, army)
	if Movement.has_hostility():
		return Movement.replan(game, army.tag, from, goal, mp)
	var key: Array = [army.id, from, goal, mp, Movement.rules_turn(game), army.tag, Movement.war_key(game), hash(game.state.occupier),
		hash(game.state.garrison)]
	var table: Dictionary = game.view_cache.pinned(&"via_plans", game.version, func() -> Dictionary: return {}) as Dictionary
	if table.has(key):
		return table[key] as Dictionary
	if table.size() >= PLANS_MAX:
		table.clear()
	var out := Movement.replan(game, army.tag, from, goal, mp)
	table[key] = out
	return out


## The season-by-season walk (Movement.walk_plan) of a leg's `route` from `from` (a stop), as an army there with its full points.
static func walk_from(game: Game, army: Army, from: Vector2i, route: PackedInt32Array) -> Dictionary:
	var probe := army.copy_for(from, Army.ORDER_MARCH, army.goal, route, PackedInt32Array(), Allowance.full(game, army))
	return Movement.walk_plan(game, probe, route, game.turn)


## The route for `tag` with `mp` points from `from_hex` through the stops (hex indices, in order) to `goal`, planned now
## (Movement.replan leg by leg; a stop where it stands is passed): {ok, hexes, to (the point no leg reaches, when not ok)}.
static func route_through(game: Game, tag: StringName, from_hex: Vector2i, stops: PackedInt32Array, goal: Vector2i,
		mp: int) -> Dictionary:
	var hexes := PackedInt32Array()
	var cur := from_hex
	var points: Array[Vector2i] = hexes_of(game, stops)
	points.append(goal)
	for to: Vector2i in points:
		if to == cur:
			continue
		var res := Movement.replan(game, tag, cur, to, mp)
		if not bool(res.ok):
			return {"ok": false, "hexes": PackedInt32Array(), "to": to}
		hexes.append_array(res.hexes as PackedInt32Array)
		cur = to
	return {"ok": true, "hexes": hexes, "to": goal}


## D20 at a closed pass for a march through stops (Movement.winter_at to the next stop, then the rest of the route planned from
## it): {ok, waits, pass_name, detour}. With no stops it is winter_at to the goal.
static func winter_through(game: Game, tag: StringName, from_hex: Vector2i, stops: PackedInt32Array, goal: Vector2i,
		mp: int) -> Dictionary:
	var rest := stops
	while not rest.is_empty() and game.map.hex_of(rest[0]) == from_hex:
		rest = rest.slice(1)
	if rest.is_empty():
		return Movement.winter_at(game, tag, from_hex, goal, mp)
	var first := game.map.hex_of(rest[0])
	var ww := Movement.winter_at(game, tag, from_hex, first, mp)
	if not bool(ww.ok) or bool(ww.waits):
		return ww
	var on := route_through(game, tag, first, rest.slice(1), goal, mp)
	if not bool(on.ok):
		return {"ok": false, "waits": false, "pass_name": "", "detour": PackedInt32Array()}
	var detour := (ww.detour as PackedInt32Array).duplicate()
	detour.append_array(on.hexes as PackedInt32Array)
	return {"ok": true, "waits": false, "pass_name": "", "detour": detour}


## The stops of `via` left after the steps `walked` (hex indices, in order): a step onto the next stop passes it (R65).
static func left(via: PackedInt32Array, walked: PackedInt32Array) -> PackedInt32Array:
	var k := 0
	for h: int in walked:
		if k < via.size() and h == via[k]:
			k += 1
	return via.slice(k) if k > 0 else via


## The stops of `via` still ahead on the route `rem` (the next step first): the longest tail of `via` found on `rem` in order.
static func ahead(via: PackedInt32Array, rem: PackedInt32Array) -> PackedInt32Array:
	if via.is_empty():
		return via
	var k := via.size() - 1
	for i: int in range(rem.size() - 1, -1, -1):
		if k >= 0 and rem[i] == via[k]:
			k -= 1
	return via.slice(k + 1)


## `army` itself when its stops are `via`, else a copy of it holding `via` (the preview's march with other stops than the kept
## ones: MovePreview's plain march, ViaPreview's path). The copy is read only; the army is never changed.
static func with_stops(army: Army, via: PackedInt32Array) -> Army:
	if army == null or army.via == via:
		return army
	var order := army.order if via.is_empty() else Army.ORDER_MARCH
	return army.copy_for(army.hex, order, army.goal, army.route, via, army.points)


## The hexes of a list of hex indices.
static func hexes_of(game: Game, indices: PackedInt32Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in indices:
		out.append(game.map.hex_of(i))
	return out


## A refusal; `at` is the point of the leg that refused (its words are about it), NO_HEX for the stops as a whole.
static func _refused(reason: String, at: Vector2i = NO_HEX) -> Dictionary:
	return {"ok": false, "reason": reason, "plan": {}, "legs": [], "via": PackedInt32Array(), "at": at}
