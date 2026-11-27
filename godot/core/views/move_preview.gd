## The read model of an army's reach and of a march to one hex (docs/architecture/m6-build-spec.md sections 4.4, 4.13, 5.0 R3
## c, 5.6, 6.3 and 6.7; L11). `reach`: the hexes an army can stand on at the end of this season and of the next. `to`: the
## words of a march to a hex, for the move card and the route marks: the verdict of march_check, the plan's stops and
## crossings, the winter line and the supply at the end. Pure core/views/ code: no nodes, no engine calls, no luck. Reads
## only; the plan comes from Movement.plan (cached per version there).
@warning_ignore_start("integer_division")
class_name MovePreview
extends RefCounted

const PREVIEWS_MAX := 256
const TONE_GOOD := &"good"
const TONE_BAD := &"bad"
const TONE_WARN := &"warn"
const TONE_MUTED := &"muted"
const TONE_PLAIN := &"plain"
const NOT_YOUR_LAND := "not your land"
const WAY_OUT_TEXT := "Go round their land."
const RIVER_NAME := "the river"
const FOG_NO_WAY_TEXT := "no way there by land"
## The `why` of a leg (moves-build-spec.md R45): how the walk of this season ends. `fog` comes with the walk's own rules (MV7)
## and `warned` with fair warning (R73: the leg ends before land the viewer knows is closed this season, and the leg names its
## country in `border`); `sighted` never comes from a preview (an army the viewer sees now cannot be newly sighted). `blocked`
## and `no_way` are the engine's other ends: an army of another country the viewer sees in the way, and a route with no way on.
## `room` is the walk's room cut (R23: the leg ends on the last hex with room for the army), and the halt words of a contact the
## walk is refused (Movement.WHY_SHAKEN, WHY_ENEMY, WHY_BATTLE with the leg's `text`, R28) on an enemy army the viewer sees.
const WHY_ARRIVES := &"arrives"
const WHY_POINTS := &"points"
const WHY_WINTER := &"winter"
const WHY_ZOC := &"zoc"
const WHY_BATTLE := &"battle"
const WHY_MUSTERING := &"mustering"
const WHY_NO_POINTS := &"no_points"
const WHY_BLOCKED := &"blocked"
const WHY_NO_WAY := &"no_way"
## MV7: a deep-fog step ends the leg (FogStep, R36); `sighted` is a why of the walk the preview never gives (R45).
const WHY_FOG := FogStep.WHY
const WHY_SIGHTED := Movement.WHY_SIGHTED
const WHY_WARNED := FairWarning.WHY
const WHY_ROOM := WalkNow.ROOM
const BORDER_TEXT := "Stops at the border of %s: you declared war this season."
const RISK_BATTLE := &"battle"
const RISK_ENEMY_LAND := &"enemy_land"
const RISK_OUT_OF_SUPPLY := &"out_of_supply"


## The hexes (indices) an army can stand on at the end of this season (`season`) and by the end of the next (`next`), from
## its own hex with its move points under the current rules (PathSearch.reach, the open mask of its country). A mustering
## army stands still this season: `season` is empty and `next` is one season's walk. Includes the army's own hex. Cached in
## the view cache by [&"reach", version, viewer, army]. Only the owner's own army has a reach: for any other viewer, or a
## viewer "", or an army that does not exist, the result is empty (the route of another country is not the viewer's to know).
static func reach(game: Game, viewer: StringName, army_id: int) -> Dictionary:
	var empty := {"season": PackedInt32Array(), "next": PackedInt32Array()}
	if game == null or game.map == null or game.defs == null or not game.has_countries() or viewer == &"":
		return empty
	var a := Armies.by_id(game, army_id)
	if a == null or a.tag != viewer:
		return empty
	var key: Array = [&"reach", game.version, viewer, army_id]
	return game.view_cache.get_or_make(key, func() -> Dictionary: return _make_reach(game, army_id)) as Dictionary


static func _make_reach(game: Game, army_id: int) -> Dictionary:
	var a := Armies.by_id(game, army_id)
	if a == null:
		return {"season": PackedInt32Array(), "next": PackedInt32Array()}
	var mp := Movement.mp_of(game, a)
	var steps := StepCosts.of(game.map, game.defs)
	var allowed := Movement.open_mask(game, a.tag)
	var winter := Calendar.is_winter(game.turn)
	var mustering := a.mustering(game.turn)
	var season := PackedInt32Array()
	if not mustering:
		season = _indices(PathSearch.reach(game.map, steps, allowed, a.hex, mp, winter))
	var budget := mp if mustering else 2 * mp
	var next := _indices(PathSearch.reach(game.map, steps, allowed, a.hex, budget, winter))
	return {"season": season, "next": next}


static func _indices(found: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k: Variant in found.keys():
		out.append(int(k))
	out.sort()
	return out


## The leg of a march alone: this season's walk of army `army_id` of `tag` to `hex` (R45), cached with `to`. An empty leg
## (no hexes, why &"") for a refused march.
static func leg_of(game: Game, tag: StringName, army_id: int, hex: Vector2i) -> Dictionary:
	return to(game, tag, army_id, hex).get("leg", _empty_leg()) as Dictionary


## The words of a march of army `army_id` of `tag` to `hex` (4.7 checks, 4.13 worked examples). Keys: verdict ({ok, reason}
## of Movement.march_check), kind (&"go"; &"note" for a march that musters, waits or ends out of supply; &"refusal"),
## title (the place), hexes (Array[Vector2i], the goal last), stops ([{hex, turn, text}] at each season's end), arrives_turn
## (-1 when none), arrives_text, seasons, crossings ([{hex, to, kind (&"bridge", &"ford", &"ferry", &"wade", &"pass"),
## name, text, closed}]), winter ({pass, closes, waits}), supply_end ({in_supply, feeds, loss}), lines ([[text, tone]]) and
## way_out, leg ({hexes, cost, points_before, points_after, full, end, why}: this season's walk, R45) and risks ([{kind, text}],
## R46), both cached with the preview. Kept in the pinned slot &"move_previews" keyed by [version, army, tag], at most PREVIEWS_MAX hexes (R3 c).
static func to(game: Game, tag: StringName, army_id: int, hex: Vector2i) -> Dictionary:
	if game == null or game.map == null or game.defs == null or not game.has_countries() or game.map.index_of(hex) < 0:
		return _bare({"ok": false, "reason": "that is off the map"})
	var table: Dictionary = game.view_cache.pinned(&"move_previews", [game.version, army_id, tag],
		func() -> Dictionary: return {}) as Dictionary
	if table.has(hex):
		return table[hex] as Dictionary
	if table.size() >= PREVIEWS_MAX:
		table.clear()
	var out := _make_to(game, tag, army_id, hex)
	table[hex] = out
	return out


## The march through staged stops (moves-build-spec.md R59, ViaPreview.via): to()'s keys plus the legs, the stops and the total.
static func via(game: Game, tag: StringName, army_id: int, stops: Array[Vector2i], hex: Vector2i) -> Dictionary:
	return ViaPreview.via.call(game, tag, army_id, stops, hex)  # by reference (A14): ViaPreview reads MovePreview


static func _make_to(game: Game, tag: StringName, army_id: int, hex: Vector2i) -> Dictionary:
	var verdict := Movement.march_check(game, {"army": army_id, "goal": hex, "tag": tag})
	if not bool(verdict.ok):
		return refused(game, tag, hex, str(verdict.reason))
	var a := MarchVia.with_stops(Armies.by_id(game, army_id), PackedInt32Array())  # a march with no stops: the army's kept stops are not this route's
	var res := Movement.plan(game, a, hex)
	if not bool(res.ok):
		return _refusal(game, hex, _fog_safe(game, tag, hex, str(res.reason)))
	return route_words(game, tag, a, hex, verdict, res.hexes, str(res.waits) != "")


## The refusal of a march to `hex` worded for the viewer: fair warning's words and hint, else fog-safe (R57).
static func refused(game: Game, tag: StringName, hex: Vector2i, why: String) -> Dictionary:
	if FairWarning.is_refusal(why):
		return _warned_refusal(game, hex, why)
	var reason := _fog_safe(game, tag, hex, why)
	if reason.begins_with(NOT_YOUR_LAND):
		reason = _foreign_reason(game, tag, hex)
	return _refusal(game, hex, reason)


## The words of an allowed march of `a` (the army, or ViaPreview's copy holding the stops) by `route` to `hex` (see to()).
static func route_words(game: Game, tag: StringName, a: Army, hex: Vector2i, verdict: Dictionary, route: PackedInt32Array,
		waits: bool) -> Dictionary:
	var army_id := a.id
	var walk := _season_walk(game, a, route)
	var out := _shell(game, hex)
	out["verdict"] = verdict
	out["hexes"] = _hexes(game, route)
	out["stops"] = _stops(game, a, route, walk)
	out["arrives_turn"] = int(walk.arrives_turn)
	out["seasons"] = int(walk.seasons)
	var lines: Array = []
	var arrives := int(walk.arrives_turn)
	if arrives >= 0:
		var text := "There in %s (%s)" % [Calendar.date_text(arrives, game.start_year), Words.seasons(int(walk.seasons))]
		out["arrives_text"] = text
		lines.append([text, TONE_PLAIN])
	if a.mustering(game.turn):
		lines.append(["Musters first: marches from %s." % Calendar.date_text(game.turn + 1, game.start_year), TONE_MUTED])
	var crossed := _crossings(game, a, route, waits)
	out["crossings"] = crossed.list
	out["winter"] = crossed.winter
	for c: Dictionary in crossed.list:
		lines.append([c.text, TONE_BAD if bool(c.closed) else TONE_PLAIN])
	if waits:
		lines.append(["Waits for spring %s: the pass is closed." % Words.at(game, crossed.waits_at, "at"), TONE_WARN])
	var fin := game.map.hex_of(route[route.size() - 1]) if not route.is_empty() else hex
	var season_turn := arrives if arrives >= 0 else game.turn
	var end := _supply_end(game, tag, a, fin, season_turn)
	out["supply_end"] = end
	lines.append(_supply_line(end))
	out["kind"] = &"note" if (a.mustering(game.turn) or waits or not bool(end.in_supply)) else &"go"
	var stand := game.map.hex_of(route[route.size() - 2]) if route.size() >= 2 else a.hex
	_war_words(game, tag, army_id, hex, stand, out, lines)
	var leg := _leg(game, tag, a, hex, route, StringName((out.war as Dictionary).kind))
	var risks := _risks(game, tag, a, leg)
	if StringName(leg.why) == WHY_WARNED:
		out["way_out"] = FairWarning.HINT_TEXT
	out["leg"] = leg
	out["risks"] = risks
	_leg_lines(game, a, leg, route, risks, lines, 1 if str((out.war as Dictionary).text) != "" else 0)
	out["lines"] = lines
	return out


## The war words of a march that is allowed (M7, 6.4): the odds card's kind and its odds (OddsView.of) for an attack, a siege,
## a storm, a walk in or a walk in held by a castle, and the first line of the hover card in the same words ("Attacks the Duchy
## of Milan: odds Even."). war {kind, text, tone}; odds {} for any other march.
static func _war_words(game: Game, tag: StringName, army_id: int, hex: Vector2i, stand: Vector2i, out: Dictionary,
		lines: Array) -> void:
	var odds := OddsView.of(game, tag, army_id, hex, false, stand)
	var kind: StringName = odds.get("kind", OddsView.KIND_NONE)
	var text := ""
	var tone := TONE_PLAIN
	var word := str(odds.get("word", ""))
	match kind:
		OddsView.KIND_ATTACK:
			text = "Attacks %s: odds %s." % [_enemy_name(game, tag, hex), word if word != "" else "unknown"]
			tone = TONE_GOOD if str(odds.get("tone", "")) == "good" else (TONE_BAD if str(odds.get("tone", "")) == "bad" else TONE_PLAIN)
		OddsView.KIND_SIEGE:
			text = "Besieges %s: %s." % [Words.place(game, hex), word]
		OddsView.KIND_STORM:
			text = "Storms %s: %s." % [Words.place(game, hex), word]
		OddsView.KIND_WALK_IN, OddsView.KIND_HELD:
			text = str((odds.get("notes", []) as Array)[0]) if kind == OddsView.KIND_HELD else "Takes it at the end of the season."
	if text == "":
		out["war"] = {"kind": OddsView.KIND_NONE, "text": "", "tone": TONE_PLAIN}
		out["odds"] = {}
		return
	out["war"] = {"kind": kind, "text": text, "tone": tone}
	out["odds"] = odds
	lines.push_front([text, tone])


## The country a march to hex would fight, as the viewer names it (its long name when the viewer sees the army, R23, R32;
## else "a country").
static func _enemy_name(game: Game, tag: StringName, hex: Vector2i) -> String:
	for other: Army in Armies.at(game, hex):
		if other.tag != tag:
			if Knowledge.sees(game, tag, hex):
				return Words.country_the(game, other.tag)
			return "a country"
	return "a country"


## The stored route of a march in progress (Army.route, kept when the march was ordered; the walk of Movement.walk_plan from
## this season): {hexes, stops, crossings, arrives_turn, seasons}, the shape of `to` for the map's thin line (L16). Empty
## hexes when the army is not marching or has no route. Cached in the view cache by [&"stored_route", version, tag, army].
static func stored(game: Game, tag: StringName, army_id: int) -> Dictionary:
	var empty := {"hexes": [], "stops": [], "crossings": [], "arrives_turn": -1, "seasons": 0, "via": []}
	if game == null or game.map == null or game.defs == null or not game.has_countries():
		return empty
	var a := Armies.by_id(game, army_id)
	if a == null or a.tag != tag or a.order != Army.ORDER_MARCH or a.route.is_empty():
		return empty
	var key: Array = [&"stored_route", game.version, tag, army_id]
	return game.view_cache.get_or_make(key, func() -> Dictionary: return _make_stored(game, a)) as Dictionary


static func _make_stored(game: Game, a: Army) -> Dictionary:
	var route := a.route
	var walk := _season_walk(game, a, route)
	return {
		"hexes": _hexes(game, route),
		"via": MarchVia.hexes_of(game, a.via),  # R68: the stops left
		"stops": _stops(game, a, route, walk),
		"crossings": _crossings(game, a, route, false).list,
		"arrives_turn": int(walk.arrives_turn),
		"seasons": int(walk.seasons),
	}


## The season-by-season walk of a route (Movement.walk_plan) under fair warning (R73): when this season's walk would cross into
## land closed to the army's country, this season ends before it and the rest is walked from the next season on.
static func _season_walk(game: Game, a: Army, route: PackedInt32Array) -> Dictionary:
	var walk := Movement.walk_plan(game, a, route, game.turn)
	var bar := FairWarning.first_barred(game, a.tag, _hexes(game, route))
	if bar < 0 or int((walk.stops as Array)[0].index) <= bar:
		return walk
	var probe := _probe(a, a.hex if bar == 0 else game.map.hex_of(route[bar - 1]), a.goal, route.slice(bar))
	var rest := Movement.walk_plan(game, probe, probe.route, game.turn + 1)
	var stops: Array = [{"turn": game.turn, "index": bar}]
	for s: Dictionary in rest.stops:
		stops.append({"turn": s.turn, "index": int(s.index) + bar})
	return {"stops": stops, "arrives_turn": rest.arrives_turn, "seasons": int(rest.seasons) + 1}


static func _shell(game: Game, hex: Vector2i) -> Dictionary:
	var hexes: Array[Vector2i] = []
	var stops: Array[Dictionary] = []
	var crossings: Array[Dictionary] = []
	return {
		"verdict": {"ok": false, "reason": ""},
		"kind": &"go",
		"title": Words.place(game, hex),
		"hexes": hexes,
		"stops": stops,
		"arrives_turn": -1,
		"arrives_text": "",
		"seasons": 0,
		"crossings": crossings,
		"winter": {"pass": "", "closes": false, "waits": false},
		"supply_end": {"in_supply": false, "feeds": 0, "loss": 0},
		"lines": [],
		"way_out": "",
		"leg": _empty_leg(),
		"risks": [],
	}


## A refusal with its reason in BAD and, for a foreign land, the way out in Hint.
static func _refusal(game: Game, hex: Vector2i, reason: String) -> Dictionary:
	var out := _shell(game, hex)
	out["verdict"] = {"ok": false, "reason": reason}
	out["kind"] = &"refusal"
	out["lines"] = [[reason, TONE_BAD]]
	out["way_out"] = WAY_OUT_TEXT if reason.begins_with(NOT_YOUR_LAND) else ""
	return out


## Fair warning's refusal (R73): its words in the warning tone and its hint where the way out goes. The verdict keeps both lines,
## so an order's toast says them too; the words name only the country the viewer declared war on, on a hex it has discovered.
static func _warned_refusal(game: Game, hex: Vector2i, reason: String) -> Dictionary:
	var out := _refusal(game, hex, reason)
	out["lines"] = [[reason.get_slice("\n", 0), TONE_WARN]]
	out["way_out"] = FairWarning.HINT_TEXT
	return out


## The refusal of a foreign hex, worded for the viewer: the owner is named (Words.country_the, which carries its own article)
## only when the viewer knows that country and has discovered the hex (R32, D15); otherwise "another country holds it".
static func _foreign_reason(game: Game, tag: StringName, hex: Vector2i) -> String:
	var owner := Territory.owner_tag(game, hex)
	var tail := ", and your armies cross no border in peace"
	if owner != &"" and Knowledge.knows(game, tag, owner) and Knowledge.discovered(game, tag, hex):
		return "%s: %s holds it%s" % [NOT_YOUR_LAND, Words.country_the(game, owner), tail]
	return "%s: another country holds it%s" % [NOT_YOUR_LAND, tail]


## A refusal's reason as the viewer may read it (4.15): a reason that names a hex the viewer does not see (the goal, or a hex in
## its words) is the generic no-way words, naming nothing; a reason on seen hexes, and the foreign-land reason (owners are public),
## stay as the check gave them.
static func _fog_safe(game: Game, tag: StringName, goal: Vector2i, reason: String) -> String:
	if reason == "" or reason.begins_with(NOT_YOUR_LAND):
		return reason
	var hexes := _named_hexes(reason)
	hexes.append(goal)
	for h: Vector2i in hexes:
		if game.map.index_of(h) >= 0 and not _seen(game, tag, h):
			return FOG_NO_WAY_TEXT
	return reason


## True when the viewer may read a hex: it sees it, or it is its own land or held by it.
static func _seen(game: Game, tag: StringName, hex: Vector2i) -> bool:
	if Knowledge.sees(game, tag, hex):
		return true
	return Occupation.controller_tag(game, hex) == tag or Territory.owner_tag(game, hex) == tag


## The hexes written as "(x, y)" in a text, in order (MoveWords reads them to keep a toast fog-safe).
static func named_hexes(text: String) -> Array[Vector2i]:
	return _named_hexes(text)


## The hexes written as "(x, y)" in a text, in order.
static func _named_hexes(text: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var parts := text.split("(")
	for k: int in range(1, parts.size()):
		var close := parts[k].find(")")
		if close < 0:
			continue
		var inner := parts[k].substr(0, close).split(",")
		if inner.size() != 2:
			continue
		var x := inner[0].strip_edges()
		var y := inner[1].strip_edges()
		if x.is_valid_int() and y.is_valid_int():
			out.append(Vector2i(x.to_int(), y.to_int()))
	return out


## A refusal for a call that has no game to name a place from (an off-map hex or no countries).
static func _bare(verdict: Dictionary) -> Dictionary:
	return {
		"verdict": verdict,
		"kind": &"refusal",
		"title": "",
		"hexes": [],
		"stops": [],
		"arrives_turn": -1,
		"arrives_text": "",
		"seasons": 0,
		"crossings": [],
		"winter": {"pass": "", "closes": false, "waits": false},
		"supply_end": {"in_supply": false, "feeds": 0, "loss": 0},
		"lines": [[str(verdict.reason), TONE_BAD]],
		"way_out": "",
		"leg": _empty_leg(),
		"risks": [],
	}


static func _hexes(game: Game, route: PackedInt32Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in route:
		out.append(game.map.hex_of(i))
	return out


## The season ends of the walk: where the army stands at the end of each season (its start while it musters).
static func _stops(game: Game, a: Army, route: PackedInt32Array, walk: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in walk.stops:
		var idx := int(s.index)
		var at_hex := a.hex if idx == 0 else game.map.hex_of(route[idx - 1])
		var turn := int(s.turn)
		out.append({"hex": at_hex, "turn": turn, "text": Calendar.date_text(turn, game.start_year)})
	return out


## The crossings of a route from the army's hex, the pass line of the winter rule and the hex it waits at. A crossing is a
## step that wades or sits on a crossing tile of the map (ford, bridge, ferry, pass).
static func _crossings(game: Game, a: Army, route: PackedInt32Array, waits: bool) -> Dictionary:
	var m := game.map
	var steps := StepCosts.of(m, game.defs)
	var list: Array[Dictionary] = []
	var winter := {"pass": "", "closes": false, "waits": waits}
	var waits_at := a.hex
	var waits_set := false
	var prev := m.index_of(a.hex)
	for nxt: int in route:
		var d := Movement.direction(m, prev, nxt)
		if d >= 0:
			var kind := _kind_of(game, steps, prev, d)
			if kind != "":
				var to_hex := m.hex_of(nxt)
				var name := Movement.pass_name(m, prev, nxt) if kind == "pass" else RIVER_NAME
				var closed := kind == "pass" and steps.cost(prev, d, true) == StepCosts.CLOSED
				list.append({"hex": m.hex_of(prev), "to": to_hex, "kind": StringName(kind), "name": name,
					"closed": closed, "text": _text(game, kind, name, to_hex, closed)})
				if kind == "pass" and str(winter.pass) == "":
					winter.pass = name
					winter.closes = closed
				if closed and not waits_set:
					waits_at = m.hex_of(prev)
					waits_set = true
		prev = nxt
	return {"list": list, "winter": winter, "waits_at": waits_at}


## The kind of the step from hex index `i` in direction `d`: "wade" for a river step with no crossing, else the crossing tile
## of the edge ("ford", "bridge", "ferry", "pass"); "" for a plain step.
static func _kind_of(game: Game, steps: StepCosts, i: int, d: int) -> String:
	if steps.cost(i, d, false) == StepCosts.WADE or steps.cost(i, d, true) == StepCosts.WADE:
		return "wade"
	var m := game.map
	var e := m.edge_index(m.hex_of(i), d)
	var k := int(m.crossing[e]) if e >= 0 and e < m.crossing.size() else 0
	match k:
		1:
			return "ford"
		2, 3:
			return "bridge"
		4:
			return "ferry"
		5:
			return "pass"
	return ""


static func _text(game: Game, kind: String, name: String, to_hex: Vector2i, closed: bool) -> String:
	match kind:
		"bridge":
			return "Crosses %s on the bridge at %s." % [name, Words.place(game, to_hex)]
		"ford":
			return "Fords %s at %s." % [name, Words.place(game, to_hex)]
		"ferry":
			return "Crosses %s by the ferry at %s." % [name, Words.place(game, to_hex)]
		"wade":
			return "Wades %s: a whole season." % name
	return "Crosses %s: closed in winter." % name if closed else "Crosses %s." % name


## The supply at the army's end hex in the season it arrives: in supply, or the land's feed and the hunger a season out of it.
static func _supply_end(game: Game, tag: StringName, a: Army, fin: Vector2i, season_turn: int) -> Dictionary:
	var inside := Supply.in_supply(game, tag, fin, Calendar.is_winter(season_turn))
	var feeds := 0
	var loss := 0
	if not inside:
		feeds = Supply.forage_cap(game, StateView.of(game.state), fin, season_turn)
		var unfed := maxi(0, a.men() - feeds)
		loss = mini(a.men(), Supply.starve_loss(game, fin, season_turn, unfed))
	return {"in_supply": inside, "feeds": feeds, "loss": loss}


static func _supply_line(end: Dictionary) -> Array:
	if bool(end.in_supply):
		return ["In supply.", TONE_GOOD]
	var feeds := int(end.feeds)
	var text := "Out of supply: %s" % ("the land feeds no one" if feeds == 0 else "the land feeds %s men a season" % Words.number(feeds))
	if int(end.loss) > 0:
		text += "; %s lost a season" % Words.men(int(end.loss))
	return [text + ".", TONE_BAD]


# --- the leg, the risks and their lines (moves-build-spec.md R45 to R47, R57) ------------------------------------------------


static func _empty_leg() -> Dictionary:
	var hexes: Array[Vector2i] = []
	return {"hexes": hexes, "cost": 0, "points_before": 0, "points_after": 0, "full": 0, "end": Vector2i(-1, -1), "why": &""}


## The walk the army would do now: the engine's own leg (MarchLeg.leg, with the points left) on a copy of the army that holds the
## route, made fog-safe: the engine stops a leg beside any enemy army (R25), seen or not, so a stop with no seen cause is walked on
## (`_walk`); an army the viewer sees on the leg is met (a battle, or blocked) and the leg ends there (R57).
static func _leg(game: Game, tag: StringName, a: Army, goal: Vector2i, route: PackedInt32Array, war_kind: StringName) -> Dictionary:
	var before := a.points
	var out := _empty_leg()
	out["full"] = Allowance.full(game, a)
	out["points_before"] = before
	out["points_after"] = before
	out["end"] = a.hex
	if a.mustering(game.turn):
		out["why"] = WHY_MUSTERING
		return out
	if before <= 0:
		out["why"] = WHY_NO_POINTS
		return out
	var steps := StepCosts.of(game.map, game.defs)
	var winter := Movement.winter_now(game)
	var walk := _walk(game, tag, a, goal, route, before, winter, steps)
	var hexes: Array[Vector2i] = walk.hexes
	var why: StringName = WHY_POINTS
	var met := _met(game, tag, a, hexes)
	var bar := FairWarning.first_barred(game, tag, hexes)
	if bar >= 0 and (int(met.cut) < 0 or bar <= int(met.at)):
		why = WHY_WARNED
		out["border"] = FairWarning.enemy_on(game, tag, hexes[bar])
		hexes = _head(hexes, bar)
	elif int(met.cut) >= 0:
		hexes = _head(hexes, int(met.cut))
		why = StringName(met.kind)
		if met.has("text"):
			out["text"] = met.text
	elif bool(walk.zoc):
		why = WHY_ZOC
	elif StringName(walk.status) == Movement.WHY_WINTER:
		why = WHY_WINTER
	elif StringName(walk.status) == Movement.WHY_NO_WAY:
		why = WHY_NO_WAY
	elif not hexes.is_empty() and hexes.back() == goal:
		why = WHY_BATTLE if (war_kind == OddsView.KIND_ATTACK or war_kind == OddsView.KIND_STORM) else WHY_ARRIVES
	elif StringName(walk.status) == FogStep.WHY:
		why = WHY_FOG
	# R23: the walk's room cut (MarchLeg.room_kept, the country's own companies only); none after a battle opened.
	if why != WHY_BATTLE or out.has("text"):
		var keep := MarchLeg.room_kept(game, a, _indices_of(game, hexes))
		if keep < hexes.size():
			hexes = _head(hexes, keep)
			why = WHY_ROOM
			out.erase("text")
			out.erase("border")
	var fought := why == WHY_ZOC or (why == WHY_BATTLE and not out.has("text"))
	var cost := _spent(game, steps, a.hex, hexes, winter, before, FogStep.mapped(game, a.tag))
	out["hexes"] = hexes
	out["cost"] = cost
	out["end"] = hexes.back() if not hexes.is_empty() else a.hex
	# R25 and D11: a zone of control and a battle end the army's season.
	out["points_after"] = 0 if fought else before - cost
	out["why"] = why
	return out


## The engine's leg, segment by segment: {hexes, status (the engine's own halt or wait), zoc (a seen zone of control ended it)}.
static func _walk(game: Game, tag: StringName, a: Army, goal: Vector2i, route: PackedInt32Array, points: int, winter: bool,
		steps: StepCosts) -> Dictionary:
	var m := game.map
	var hexes: Array[Vector2i] = []
	var out := {"hexes": hexes, "status": &"", "zoc": false}
	var cur := a.hex
	var rem := route
	var left := points
	var mapped := FogStep.mapped(game, tag)
	for _segment: int in 64:
		var w := MarchLeg.leg(game, steps, _probe(a, cur, goal, rem), winter, left, false)
		var taken := _hexes(game, w.walked)
		left = w.points_left()
		hexes.append_array(taken)
		if w.status != &"":
			out["status"] = w.status
			break
		if w.arrived() or w.walked.is_empty() or left <= 0:
			break
		var end_hex := m.hex_of(w.end)
		if not Movement.zoc_halts(game, tag, end_hex):
			break
		if _sees_zoc(game, tag, end_hex):
			out["zoc"] = true
			break
		# The stop was caused by an army the viewer does not see: walk on as if it were not there.
		if _next_is_dear(game, steps, w.end, w.rem, left, winter, mapped):
			break
		cur = end_hex
		rem = w.rem
	return out


## A copy of the army standing on `hex` with a march to `goal` by `route` (the engine's leg reads the order from the army).
static func _probe(a: Army, hex: Vector2i, goal: Vector2i, route: PackedInt32Array) -> Army:
	var p := Army.new()
	p.id = a.id
	p.tag = a.tag
	p.name = a.name
	p.hex = hex
	p.units = a.units
	p.order = Army.ORDER_MARCH
	p.goal = goal
	p.route = route
	# R65: the stops still ahead on this part of the route (a copy holding them: Army.via is written only through Armies).
	return p if a.via.is_empty() else p.copy_for(hex, p.order, goal, route, MarchVia.ahead(a.via, route), 0)


## The move points the steps onto `hexes` from `from` spend out of `points`: a wade, or a step dearer than what is left, spends
## all that is left (the engine's rule); a fog step (`mapped`, FogStep) spends fog_step_cost.
static func _spent(game: Game, steps: StepCosts, from: Vector2i, hexes: Array[Vector2i], winter: bool, points: int,
		mapped: PackedByteArray) -> int:
	var m := game.map
	var left := points
	var prev := m.index_of(from)
	for h: Vector2i in hexes:
		var i := m.index_of(h)
		var d := Movement.direction(m, prev, i)
		var c: int = steps.cost(prev, d, winter) if d >= 0 else 0
		if FogStep.is_fog(mapped, i):
			left = FogStep.after(game.defs.fog_step_cost, left)
		else:
			left = 0 if (c == StepCosts.WADE or c > left) else left - c
		prev = i
	return points - left


## True when the next step of the rest would be a wade, a fog step or dearer than the points left: the engine ends a leg there
## when the army has walked already, so a leg walked on past an unseen zone of control ends there too.
static func _next_is_dear(game: Game, steps: StepCosts, at: int, rem: PackedInt32Array, left: int, winter: bool,
		mapped: PackedByteArray) -> bool:
	if rem.is_empty():
		return false
	if FogStep.is_fog(mapped, rem[0]):
		return true
	var d := Movement.direction(game.map, at, rem[0])
	if d < 0:
		return false
	var c: int = steps.cost(at, d, winter)
	return c == StepCosts.WADE or (c < StepCosts.CLOSED and c > left)


## True when the viewer sees an army of a country hostile to it beside `hex`, or a hostile fortress it sees (the zone of
## control the viewer may know of, R57).
static func _sees_zoc(game: Game, tag: StringName, hex: Vector2i) -> bool:
	for d: int in 6:
		var n := game.map.neighbour(hex, d)
		if game.map.index_of(n) < 0 or not Knowledge.sees(game, tag, n):
			continue
		for o: Army in Movement.armies_on(game, n):
			if Movement.hostile(game, tag, o.tag):
				return true
		if Movement.ZOC_FORTRESSES and Movement.closed_fortress(game, tag, n):
			return true
	return false


## The first army of another country on the leg that the viewer sees, met as the walk meets it: {cut (hexes kept; -1 none), at
## (its place on the leg), kind, hex, and text for a refused contact}. An army at war is a contact (FogVerdict.contact, the walk's
## engage rule): battle when it opens (the walk ends on its hex), else the walk's halt word before it with the check's words;
## any other country's army: blocked, before it.
static func _met(game: Game, tag: StringName, a: Army, hexes: Array[Vector2i]) -> Dictionary:
	for k: int in hexes.size():
		var h := hexes[k]
		if not Knowledge.sees(game, tag, h):
			continue
		if Movement.enemy_army_at(game, tag, h):
			var c := FogVerdict.contact(game, a, h)
			if bool(c.ok):
				return {"cut": k + 1, "at": k, "kind": WHY_BATTLE, "hex": h}
			return {"cut": k, "at": k, "kind": c.why, "hex": h, "text": c.text}
		for o: Army in Movement.armies_on(game, h):
			if o.tag != tag:
				return {"cut": k, "at": k, "kind": WHY_BLOCKED, "hex": h}
	return {"cut": -1}


static func _indices_of(game: Game, hexes: Array[Vector2i]) -> PackedInt32Array:
	var out := PackedInt32Array()
	for h: Vector2i in hexes:
		out.append(game.map.index_of(h))
	return out


static func _head(hexes: Array[Vector2i], n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k: int in n:
		out.append(hexes[k])
	return out


## The risks of the leg (R46) from what the viewer knows: a battle (its last step is onto an army at war it sees, or the storm's
## fortress), land held by a country at war that the army does not stand in now and the viewer has discovered, and an end this
## season out of supply.
static func _risks(game: Game, tag: StringName, a: Army, leg: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hexes: Array[Vector2i] = leg.hexes
	if hexes.is_empty():
		return out
	if StringName(leg.why) == WHY_BATTLE and not leg.has("text"):
		out.append({"kind": RISK_BATTLE, "text": "This opens a battle at %s." % Words.place(game, leg.end)})
	var here := Occupation.controller_tag(game, a.hex)
	var named: Array[StringName] = []
	for h: Vector2i in hexes:
		var held := Occupation.controller_tag(game, h)
		if held == &"" or held == tag or held == here or named.has(held) or not Wars.at_war(game, tag, held):
			continue
		if not Knowledge.discovered(game, tag, h) or not Knowledge.knows(game, tag, held):
			continue
		named.append(held)
		out.append({"kind": RISK_ENEMY_LAND, "text": "Enters land held by %s, a country at war with you." % Words.country_the(game, held)})
	var end := _supply_end(game, tag, a, leg.end, game.turn)
	if not bool(end.in_supply):
		out.append({"kind": RISK_OUT_OF_SUPPLY, "text": str(_supply_line(end)[0])})
	return out


## The lines of the leg and its risks (R47), put into `lines` from index `at` (after the war line): the walk now, the stop of a
## route longer than the season, the zone of control, a blocked way, the unmapped land of a fog step (MV7, R47: the hex by its
## coordinates alone, never explored), then a line for each risk.
static func _leg_lines(game: Game, a: Army, leg: Dictionary, route: PackedInt32Array, risks: Array[Dictionary], lines: Array,
		at: int) -> void:
	var made: Array = []
	var why := StringName(leg.why)
	var hexes: Array[Vector2i] = leg.hexes
	if why == WHY_NO_POINTS:
		made.append(["No move points left this season: it sets out at the end of next season.", TONE_WARN])
	if not hexes.is_empty():
		made.append([_walks_text(leg, why), TONE_PLAIN])
	if leg.has("text"):
		made.append(["Stops at %s: %s." % [Words.place(game, leg.end), str(leg.text)], TONE_WARN])
	match why:
		WHY_WARNED:
			made.append([BORDER_TEXT % Words.country_the(game, StringName(leg.border)), TONE_WARN])
		WHY_POINTS:
			made.append([_stop_text(game, a, leg, route), TONE_PLAIN])
		WHY_ZOC:
			made.append(["Stops beside an enemy at %s: its season is over." % Words.place(game, leg.end), TONE_WARN])
		WHY_BLOCKED:
			made.append(["Stops at %s: another country's army stands in the way." % Words.place(game, leg.end), TONE_WARN])
		WHY_ROOM:
			made.append(["Stops at %s: no room for more of your companies further on." % Words.place(game, leg.end), TONE_WARN])
		WHY_FOG:
			var fog := _fog_hex(game, a, leg, route)
			made.append(["Unmapped land at (%d, %d): the army spends its season finding the way." % [fog.x, fog.y], TONE_WARN])
	for r: Dictionary in risks:
		made.append([str(r.text), TONE_WARN])
	for k: int in made.size():
		lines.insert(at + k, made[k])


## The hex of the fog step that ended the leg: its last hex when the step was taken, else the route's next step after its end.
static func _fog_hex(game: Game, a: Army, leg: Dictionary, route: PackedInt32Array) -> Vector2i:
	var end: Vector2i = leg.end
	var i := game.map.index_of(end)
	if end != a.hex and FogStep.is_fog(FogStep.mapped(game, a.tag), i):
		return end
	var at := route.find(i) + 1 if end != a.hex else 0
	return game.map.hex_of(route[at]) if at < route.size() else end


static func _walks_text(leg: Dictionary, why: StringName) -> String:
	var n := (leg.hexes as Array).size()
	var head := "Walks %d hex%s now: %d of %d move points" % [n, "" if n == 1 else "es", int(leg.cost), int(leg.points_before)]
	if why == WHY_ZOC or (why == WHY_BATTLE and not leg.has("text")):
		return head + "; its season is over."
	return head + ", %d left." % int(leg.points_after)


## "Stops at Cerano (7, 9) this season; walks on at the end of next season, there in Autumn 1481." The arrival is the rest of the
## route walked from the next season on with full points.
static func _stop_text(game: Game, a: Army, leg: Dictionary, route: PackedInt32Array) -> String:
	var head := "Stops at %s this season; walks on at the end of next season" % Words.place(game, leg.end)
	var at := route.find(game.map.index_of(leg.end))
	if at < 0:
		return head + "."
	var probe := _probe(a, leg.end, a.goal, route.slice(at + 1))
	var walk := Movement.walk_plan(game, probe, probe.route, game.turn + 1)
	if int(walk.arrives_turn) < 0:
		return head + "."
	return head + ", there in %s." % Calendar.date_text(int(walk.arrives_turn), game.start_year)
