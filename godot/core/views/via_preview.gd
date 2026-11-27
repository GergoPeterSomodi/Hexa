## The picture of a multi-leg march before it is ordered (docs/architecture/moves-build-spec.md R59, R67, D29, D32): the route of
## army `army_id` through the staged stops in order to the pointer's hex, as MovePreview.to gives a plain march (the verdict, the
## route, the season stops, crossings, supply, the war words, this season's `leg` and `risks` read on the whole route), plus
## `legs` ([{from, to, hexes, cost, seasons, arrives_turn, fog}]), `via` (the staged stops) and `total` ({cost (the sum of the
## legs), seasons, arrives_turn, legs}), and a line for each leg and one for the whole route. The stops are the shell's
## (MapArmies); nothing here changes the game. A refusal names the stop or the goal it is about ("Stop 2: ...") in the words the
## viewer may read (MovePreview.refused, R57). Kept in the pinned slot &"via_previews" keyed by [version, army, tag, stops], a
## table by the pointer's hex; the legs' plans are MarchVia's (kept per version, army, start and end), so moving the pointer plans
## only the last leg. Pure core/views/ code: no nodes, no engine calls, no luck.
class_name ViaPreview
extends RefCounted

const PREVIEWS_MAX := 256
const NO_HEX := Vector2i(-1, -1)


## See the header. With no stops it is MovePreview.to with one leg.
static func via(game: Game, tag: StringName, army_id: int, stops: Array[Vector2i], hex: Vector2i) -> Dictionary:
	if game == null or game.map == null or game.defs == null or not game.has_countries() or game.map.index_of(hex) < 0:
		return _bare(MovePreview.to(game, tag, army_id, hex), stops)
	var key: Array = [game.version, army_id, tag, stops.duplicate()]
	var table: Dictionary = game.view_cache.pinned(&"via_previews", key, func() -> Dictionary: return {}) as Dictionary
	if table.has(hex):
		return table[hex] as Dictionary
	if table.size() >= PREVIEWS_MAX:
		table.clear()
	var out := _make(game, tag, army_id, stops, hex)
	table[hex] = out
	return out


static func _make(game: Game, tag: StringName, army_id: int, stops: Array[Vector2i], hex: Vector2i) -> Dictionary:
	var verdict := Movement.march_check(game, {"army": army_id, "goal": hex, "tag": tag, "via": stops})
	var a := Armies.by_id(game, army_id)
	if not bool(verdict.ok):
		return _refusal(game, tag, a, stops, hex, str(verdict.reason))
	var lv := MarchVia.legs_verdict(game, a, tag, stops, hex)
	var plan := lv.plan as Dictionary
	var route := plan.hexes as PackedInt32Array
	var pa := _copy(a, lv.via as PackedInt32Array, hex, route)
	var out := MovePreview.route_words(game, tag, pa, hex, verdict, route, str(plan.get("waits", "")) != "")
	out["via"] = stops.duplicate()
	_legs(game, pa, lv.legs as Array, route, out)
	return out


## The legs of the route and the total (R59), and their lines after the preview's own.
static func _legs(game: Game, pa: Army, raw: Array, route: PackedInt32Array, out: Dictionary) -> void:
	var walk := Movement.walk_plan(game, pa, route, game.turn)
	var mapped := FogStep.mapped(game, pa.tag)
	var legs: Array[Dictionary] = []
	var lines: Array = out.lines
	var at := 0
	var before := game.turn - 1
	var cost := 0
	for k: int in raw.size():
		var leg: Dictionary = raw[k]
		var hexes := leg.hexes as PackedInt32Array
		at += hexes.size()
		var arrives := _arrives(walk.stops as Array, at)
		var fog := false
		for i: int in hexes:
			fog = fog or FogStep.is_fog(mapped, i)
		var seasons := arrives - before if arrives >= 0 else 0
		var made := {"from": leg.from, "to": leg.to, "hexes": MarchVia.hexes_of(game, hexes), "cost": int(leg.cost),
			"seasons": seasons, "arrives_turn": arrives, "fog": fog}
		legs.append(made)
		cost += int(leg.cost)
		if arrives >= 0:
			before = arrives
		lines.append([_leg_text(game, k + 1, made), MovePreview.TONE_WARN if fog else MovePreview.TONE_PLAIN])
	var total := {"cost": cost, "seasons": int(walk.seasons), "arrives_turn": int(walk.arrives_turn), "legs": legs.size()}
	lines.append([_total_text(game, total), MovePreview.TONE_PLAIN])
	out["legs"] = legs
	out["total"] = total


## The season the walk stands at or past route index `at` at its end (the leg's end reached), or -1.
static func _arrives(season_stops: Array, at: int) -> int:
	for s: Dictionary in season_stops:
		if int(s.index) >= at:
			return int(s.turn)
	return -1


## "Leg 2: Vercelli (6, 9) to Novara (8, 9): 5 move points, 1 season, there in Summer 1481." (and the unmapped land, R67).
static func _leg_text(game: Game, n: int, leg: Dictionary) -> String:
	var text := "Leg %d: %s to %s: %d move points, %s" % [n, Words.place(game, leg.from), Words.place(game, leg.to), int(leg.cost),
		_when(game, int(leg.seasons), int(leg.arrives_turn))]
	return text + (" Unmapped land on the way." if bool(leg.fog) else "")


## "Whole route: 3 legs, 14 move points, 2 seasons, there in Autumn 1481."
static func _total_text(game: Game, total: Dictionary) -> String:
	return "Whole route: %d legs, %d move points, %s" % [int(total.legs), int(total.cost),
		_when(game, int(total.seasons), int(total.arrives_turn))]


static func _when(game: Game, seasons: int, arrives: int) -> String:
	var span := Words.seasons(seasons) if seasons > 0 else "the same season"
	if arrives < 0:
		return span + "."
	return "%s, there in %s." % [span, Calendar.date_text(arrives, game.start_year)]


## A refusal with the stop or the goal it is about: the words of the leg's point worded for the viewer, the prefix kept.
static func _refusal(game: Game, tag: StringName, a: Army, stops: Array[Vector2i], hex: Vector2i, reason: String) -> Dictionary:
	var prefix := ""
	var tail := reason
	if reason.begins_with("Stop ") or reason.begins_with("The goal: "):
		var cut := reason.find(": ")
		prefix = reason.substr(0, cut + 2)
		tail = reason.substr(cut + 2)
	var at := hex
	if a != null and prefix != "":
		var lv := MarchVia.legs_verdict(game, a, tag, stops, hex)
		if (lv.at as Vector2i) != NO_HEX:
			at = lv.at as Vector2i
	var out := MovePreview.refused(game, tag, at, tail).duplicate(true)
	out["title"] = Words.place(game, hex)
	if prefix != "":
		out["verdict"] = {"ok": false, "reason": prefix + str((out.verdict as Dictionary).reason)}
		var lines: Array = out.lines
		if not lines.is_empty():
			lines[0] = [prefix + str(lines[0][0]), lines[0][1]]
	return _bare(out, stops)


## A preview without legs: the route's keys of a refusal, the staged stops and an empty total.
static func _bare(out: Dictionary, stops: Array[Vector2i]) -> Dictionary:
	var shaped := out.duplicate()
	var legs: Array[Dictionary] = []
	shaped["via"] = stops.duplicate()
	shaped["legs"] = legs
	shaped["total"] = {"cost": 0, "seasons": 0, "arrives_turn": -1, "legs": 0}
	return shaped


## A read-only copy of the army ordered to `goal` by `route` through `via` (the walk's engine reads the order from the army).
static func _copy(a: Army, via: PackedInt32Array, goal: Vector2i, route: PackedInt32Array) -> Army:
	return a.copy_for(a.hex, Army.ORDER_MARCH, goal, route, via, a.points)
