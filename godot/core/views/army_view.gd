## The read model of the armies on the map and in the Army panel (docs/architecture/m6-build-spec.md sections 4.12, 5.6,
## 6.3 and 6.5; L11). `tokens`: one token per (hex, country) the viewer sees; `panel`: one army; `needing_orders`: the
## armies of a country in the order they want; `hex_text`: the Armies line of the hex card; `token_text`: a men count as
## the badge reads it. Pure core/views/ code: a function of the game and the viewer, no nodes, no engine calls, no luck.
## The viewer "" sees every army exact. Any other viewer sees its own armies exact, and the foreign armies it sees (Sight)
## of a country it knows (Knowledge.knows): their men banded, no army ids, no order (4.12).
@warning_ignore_start("integer_division")
class_name ArmyView
extends RefCounted

const TOKEN_ROUND := 50
const K_UNIT := 1000


## One token per (hex, country) the viewer sees, in the order of the first army of each (id order). A token is
## {hex, tag, armies: PackedInt32Array, men, text, exact, figure, mustering, marching, waiting, hungry, mine}. A foreign
## token carries no army ids, a banded men count and no flags (the order is not the viewer's to know). Cached in the view
## cache by [&"tokens", version, viewer].
static func tokens(game: Game, viewer: StringName) -> Array[Dictionary]:
	var empty: Array[Dictionary] = []
	if game == null or game.map == null or not game.has_countries():
		return empty
	var key: Array = [&"tokens", game.version, viewer]
	return game.view_cache.get_or_make(key, func() -> Array[Dictionary]: return _make_tokens(game, viewer)) as Array[Dictionary]


static func _make_tokens(game: Game, viewer: StringName) -> Array[Dictionary]:
	var groups: Dictionary = {}
	var keys: Array[String] = []
	for army: Army in game.armies:
		if not visible(game, viewer, army):
			continue
		var k := "%d,%d,%s" % [army.hex.x, army.hex.y, String(army.tag)]
		if not groups.has(k):
			groups[k] = []
			keys.append(k)
		(groups[k] as Array).append(army)
	var out: Array[Dictionary] = []
	for k: String in keys:
		out.append(_token(game, viewer, groups[k] as Array))
	return out


static func _token(game: Game, viewer: StringName, armies: Array) -> Dictionary:
	var first := armies[0] as Army
	var exact := viewer == &"" or first.tag == viewer
	var men := 0
	var ids := PackedInt32Array()
	var by_kind: Dictionary = {}
	var mustering := false
	var marching := false
	var waiting := false
	var hungry := false
	for item: Variant in armies:
		var a := item as Army
		men += a.men()
		for u: Unit in a.units:
			by_kind[u.kind] = int(by_kind.get(u.kind, 0)) + u.men
		if exact:
			ids.append(a.id)
			mustering = mustering or a.mustering(game.turn)
			marching = marching or a.order == Army.ORDER_MARCH
			waiting = waiting or a.waiting != &""
			hungry = hungry or a.supply == Supply.HUNGRY
	if not exact:
		ids = PackedInt32Array()
	return {
		"hex": first.hex,
		"tag": first.tag,
		"armies": ids,
		"men": men if exact else Knowledge.band(men),
		"text": token_text(men, exact),
		"exact": exact,
		"figure": _figure(game, by_kind),
		"mustering": mustering and exact,
		"marching": marching and exact,
		"waiting": waiting and exact,
		"hungry": hungry and exact,
		"mine": viewer != &"" and first.tag == viewer,
	}


## The figure of the kind with the most men on a token (ties: the lower kind id); &"" for none.
static func _figure(game: Game, by_kind: Dictionary) -> StringName:
	var best := -1
	var best_men := -1
	var kinds: Array = by_kind.keys()
	kinds.sort()
	for k: Variant in kinds:
		if int(by_kind[k]) > best_men:
			best_men = int(by_kind[k])
			best = int(k)
	var ud := Military.unit_def(game, best)
	return ud.figure if ud != null else &""


## True when the viewer may see `army`: its own (or the viewer ""), or a foreign one on a hex it sees whose country it knows.
static func visible(game: Game, viewer: StringName, army: Army) -> bool:
	if viewer == &"" or army.tag == viewer:
		return true
	return Knowledge.sees(game, viewer, army.hex) and Knowledge.knows(game, viewer, army.tag)


## The badge text of a men count (A9): exact, under 1,000 the number, else tenths of a thousand as "1.0k" or "1.2k";
## banded (another's), the band (Knowledge.band) as "~450", "~1k" or "~1.2k".
static func token_text(men: int, exact: bool) -> String:
	if exact:
		if men < K_UNIT:
			return str(men)
		var t := (men + TOKEN_ROUND) / 100
		return "%d.%dk" % [t / 10, t % 10]
	var n := Knowledge.band(men)
	if n < K_UNIT:
		return "~%d" % n
	var tt := (n + TOKEN_ROUND) / 100
	if tt % 10 == 0:
		return "~%dk" % (tt / 10)
	return "~%d.%dk" % [tt / 10, tt % 10]


## The Army panel's model of one army (6.5), {} when the viewer does not see it. Its own army (or any army for the viewer
## ""): {mine, id, name, tag, country, hex, place, men, limit, here, units, order, supply, upkeep, mp, sight, others_here}.
## A foreign army seen: {mine: false, country, hex, men_text}. Units: [{id, kind, name, men, full, raised_text, mustering}].
static func panel(game: Game, viewer: StringName, army_id: int) -> Dictionary:
	var a := Armies.by_id(game, army_id)
	if a == null or not visible(game, viewer, a):
		return {}
	if a.tag != viewer and viewer != &"":
		return {
			"mine": false,
			"country": _country_name(game, a.tag),
			"hex": a.hex,
			"men_text": Knowledge.band_text(a.men(), "men"),
		}
	return _own_panel(game, a, viewer)


static func _own_panel(game: Game, a: Army, viewer: StringName) -> Dictionary:
	var units: Array[Dictionary] = []
	var sight := 1
	for u: Unit in a.units:
		var ud := Military.unit_def(game, u.kind)
		units.append({
			"id": u.id,
			"kind": u.kind,
			"name": ud.name if ud != null else "",
			"men": u.men,
			"full": ud.men if ud != null else 0,
			"raised_text": "Raised " + Calendar.date_text(u.raised_turn, game.start_year),
			"mustering": u.raised_turn == game.turn,
		})
		if ud != null:
			sight = maxi(sight, ud.sight)
	var others: Array[Dictionary] = []
	for o: Army in Armies.at(game, a.hex):
		if o.id != a.id and o.tag == a.tag:
			others.append({"id": o.id, "name": o.name, "men": o.men()})
	return {
		"mine": a.tag == viewer,
		"id": a.id,
		"name": a.name,
		"tag": a.tag,
		"country": _country_name(game, a.tag),
		"hex": a.hex,
		"place": Words.place(game, a.hex),
		"men": a.men(),
		"limit": Military.stack_limit(game, a.tag),
		"here": Armies.units_at(game, a.tag, a.hex),
		"units": units,
		"order": _order(game, a),
		"supply": _supply(a),
		"upkeep": Military.upkeep_of(game, a),
		"mp": Movement.mp_of(game, a),
		"sight": sight,
		"others_here": others,
	}


static func _order(game: Game, a: Army) -> Dictionary:
	var text := "Holding"
	var stops: Array[Dictionary] = []
	var arrives_text := ""
	if a.mustering(game.turn):
		text = "Musters this season"
	elif a.halt_why != &"":
		text = "Halted: " + a.halt_text
	elif a.order == Army.ORDER_MARCH:
		text = "Marching " + Words.at(game, a.goal, "to")
		var walk := Movement.walk_plan(game, a, a.route, game.turn)
		stops.assign(walk.stops)
		if int(walk.arrives_turn) >= 0:
			arrives_text = "Arrives in " + Calendar.date_text(int(walk.arrives_turn), game.start_year)
	elif a.order == Army.ORDER_NONE and a.goal != Army.NO_HEX:
		text = "Halted, can march on"  # a halted march keeps its goal: continue_march resumes it
	var waiting_text := ""
	if a.waiting == &"winter":
		waiting_text = "Waits for spring %s: the pass is closed." % Words.at(game, a.hex, "at")
	return {
		"kind": a.order,
		"text": text,
		"goal": a.goal,
		"stops": stops,
		"arrives_text": arrives_text,
		"waiting_text": waiting_text,
		"halt_text": a.halt_text,
	}


static func _supply(a: Army) -> Dictionary:
	var text := "Fed from the stores"
	var fed := "All its men are fed"
	if a.supply == Supply.FORAGED:
		text = "Out of supply: fed by the land"
	elif a.supply == Supply.HUNGRY:
		text = "Hungry: out of supply or short of food"
		fed = "Not all its men are fed"
	return {"state": a.supply, "text": text, "fed_text": fed, "lost_last": a.lost_last}


## The armies of `tag` that want an order: those with no order first, then the rest, each in id order.
static func needing_orders(game: Game, tag: StringName) -> PackedInt32Array:
	var none := PackedInt32Array()
	var rest := PackedInt32Array()
	for a: Army in Armies.of_country(game, tag):
		if a.order == Army.ORDER_NONE:
			none.append(a.id)
		else:
			rest.append(a.id)
	none.append_array(rest)
	return none


## The Armies line of a hex card for the viewer: "Army of Turin: 1,000 men, holding; ..." for the armies the viewer sees
## there, "Milan: about 1,000 men" for a foreign one; "" for none.
static func hex_text(game: Game, viewer: StringName, hex: Vector2i) -> String:
	if game == null or game.map == null or not game.has_countries():
		return ""
	var parts := PackedStringArray()
	var foreign_tags: Array[StringName] = []
	var foreign_men: Dictionary = {}
	for a: Army in Armies.at(game, hex):
		if not visible(game, viewer, a):
			continue
		if a.tag == viewer or viewer == &"":
			parts.append("%s: %s, %s" % [a.name, Words.men(a.men()), _word(game, a)])
		else:
			# Another country's armies on one hex are one figure, as their token is: summed, then banded once.
			if not foreign_tags.has(a.tag):
				foreign_tags.append(a.tag)
			foreign_men[a.tag] = int(foreign_men.get(a.tag, 0)) + a.men()
	for tag: StringName in foreign_tags:
		parts.append("%s: %s" % [_country_name(game, tag), Knowledge.band_text(int(foreign_men[tag]), "men")])
	return "; ".join(parts)


static func _word(game: Game, a: Army) -> String:
	if a.mustering(game.turn):
		return "mustering"
	if a.halt_why != &"":
		return "halted"
	if a.waiting != &"":
		return "waiting"
	if a.order == Army.ORDER_MARCH:
		return "marching"
	if a.order == Army.ORDER_NONE and a.goal != Army.NO_HEX:
		return "halted, can march on"
	return "holding"


## A country's short name for a message (its definition's name, else its tag).
static func _country_name(game: Game, tag: StringName) -> String:
	var cdef := Countries.def_of(game, tag)
	if cdef != null and not cdef.name.is_empty():
		return cdef.name
	return String(tag)
