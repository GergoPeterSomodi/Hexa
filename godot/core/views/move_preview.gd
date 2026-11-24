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


## The words of a march of army `army_id` of `tag` to `hex` (4.7 checks, 4.13 worked examples). Keys: verdict ({ok, reason}
## of Movement.march_check), kind (&"go"; &"note" for a march that musters, waits or ends out of supply; &"refusal"),
## title (the place), hexes (Array[Vector2i], the goal last), stops ([{hex, turn, text}] at each season's end), arrives_turn
## (-1 when none), arrives_text, seasons, crossings ([{hex, to, kind (&"bridge", &"ford", &"ferry", &"wade", &"pass"),
## name, text, closed}]), winter ({pass, closes, waits}), supply_end ({in_supply, feeds, loss}), lines ([[text, tone]]) and
## way_out. Kept in the pinned slot &"move_previews" keyed by [version, army, tag], at most PREVIEWS_MAX hexes (R3 c).
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


static func _make_to(game: Game, tag: StringName, army_id: int, hex: Vector2i) -> Dictionary:
	var verdict := Movement.march_check(game, {"army": army_id, "goal": hex, "tag": tag})
	if not bool(verdict.ok):
		var reason := _fog_safe(game, tag, hex, str(verdict.reason))
		if reason.begins_with(NOT_YOUR_LAND):
			reason = _foreign_reason(game, tag, hex)
		return _refusal(game, hex, reason)
	var a := Armies.by_id(game, army_id)
	var res := Movement.plan(game, a, hex)
	if not bool(res.ok):
		return _refusal(game, hex, _fog_safe(game, tag, hex, str(res.reason)))
	var route: PackedInt32Array = res.hexes
	var waits := str(res.waits) != ""
	var walk := Movement.walk_plan(game, a, route, game.turn)
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
	var empty := {"hexes": [], "stops": [], "crossings": [], "arrives_turn": -1, "seasons": 0}
	if game == null or game.map == null or game.defs == null or not game.has_countries():
		return empty
	var a := Armies.by_id(game, army_id)
	if a == null or a.tag != tag or a.order != Army.ORDER_MARCH or a.route.is_empty():
		return empty
	var key: Array = [&"stored_route", game.version, tag, army_id]
	return game.view_cache.get_or_make(key, func() -> Dictionary: return _make_stored(game, a)) as Dictionary


static func _make_stored(game: Game, a: Army) -> Dictionary:
	var route := a.route
	var walk := Movement.walk_plan(game, a, route, game.turn)
	return {
		"hexes": _hexes(game, route),
		"stops": _stops(game, a, route, walk),
		"crossings": _crossings(game, a, route, false).list,
		"arrives_turn": int(walk.arrives_turn),
		"seasons": int(walk.seasons),
	}


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
	}


## A refusal with its reason in BAD and, for a foreign land, the way out in Hint.
static func _refusal(game: Game, hex: Vector2i, reason: String) -> Dictionary:
	var out := _shell(game, hex)
	out["verdict"] = {"ok": false, "reason": reason}
	out["kind"] = &"refusal"
	out["lines"] = [[reason, TONE_BAD]]
	out["way_out"] = WAY_OUT_TEXT if reason.begins_with(NOT_YOUR_LAND) else ""
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
