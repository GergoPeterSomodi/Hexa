## The read model of the armies on the map and in the Army panel (docs/architecture/m6-build-spec.md sections 4.12, 5.6,
## 6.3 and 6.5; L11). `tokens`: one token per (hex, country) the viewer sees; `panel`: one army; `needing_orders`: the
## armies of a country in the order they want; `hex_text`: the Armies line of the hex card; `token_text`: a men count as
## the badge reads it. Pure core/views/ code: a function of the game and the viewer, no nodes, no engine calls, no luck.
## The viewer "" sees every army exact. Any other viewer sees its own armies exact, and the foreign armies on a hex it sees
## (R23, Sight): their men exact (R25, D7), no army ids, no order (D8).
@warning_ignore_start("integer_division")
class_name ArmyView
extends RefCounted

const TOKEN_ROUND := 50
const K_UNIT := 1000
## The morale from which a company is Steady (the morale words of morale_word; the other two bands are WarDef's).
const STEADY_MORALE := 750


## One token per (hex, country) the viewer sees, in the order of the first army of each (id order). A token is
## {hex, tag, armies: PackedInt32Array, men, text, figure, mustering, marching, waiting, hungry, besieging, shaken, mine,
## points_left, points_full}. A foreign token carries its men exact but no army ids, no flags and no points (points_left and
## points_full are -1: the orders are not the viewer's to know; moves-build-spec.md R51). Cached in
## the view cache by [&"tokens", version, viewer].
static func tokens(game: Game, viewer: StringName) -> Array[Dictionary]:
	var empty: Array[Dictionary] = []
	if game == null or game.map == null or not game.has_countries():
		return empty
	# The sight's revision is in the key: the army part of the sight moves inside a season (a phase, a computer's turn) before the
	# version does, and a token list made before that would still show an army that has left the viewer's sight.
	var key: Array = [&"tokens", game.version, game.sight.revision(), viewer]
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
	var own := viewer == &"" or first.tag == viewer
	var men := 0
	var ids := PackedInt32Array()
	var by_kind: Dictionary = {}
	var mustering := false
	var marching := false
	var waiting := false
	var hungry := false
	var points_left := -1
	var points_full := -1
	for item: Variant in armies:
		var a := item as Army
		men += a.men()
		for u: Unit in a.units:
			by_kind[u.kind] = int(by_kind.get(u.kind, 0)) + u.men
		if own:
			ids.append(a.id)
			mustering = mustering or a.mustering(game.turn)
			marching = marching or a.order == Army.ORDER_MARCH
			waiting = waiting or a.waiting != &""
			hungry = hungry or a.supply == Supply.HUNGRY
			# The lowest left and the lowest full of the armies on the token (R51).
			points_left = a.points if points_left < 0 else mini(points_left, a.points)
			var top := Allowance.full(game, a)
			points_full = top if points_full < 0 else mini(points_full, top)
	if not own:
		ids = PackedInt32Array()
	var siege := Occupation.siege_at(game, first.hex)
	return {
		"hex": first.hex,
		"tag": first.tag,
		"armies": ids,
		"men": men,
		"text": token_text(men),
		"figure": _figure(game, by_kind),
		"mustering": mustering and own,
		"marching": marching and own,
		"waiting": waiting and own,
		"hungry": hungry and own,
		"besieging": own and siege != null and siege.besieger == first.tag,
		"shaken": own and _any_shaken(game, armies),
		"mine": viewer != &"" and first.tag == viewer,
		"points_left": points_left,
		"points_full": points_full,
	}


## True when one of the armies is too shaken to attack (its morale under WarDef.attack_morale).
static func _any_shaken(game: Game, armies: Array) -> bool:
	for item: Variant in armies:
		if Armies.morale_of(item as Army) < game.defs.war.attack_morale:
			return true
	return false


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


## True when the viewer may see `army` (R23): its own (or the viewer ""), or a foreign one on a hex it sees whose country it knows.
static func visible(game: Game, viewer: StringName, army: Army) -> bool:
	if viewer == &"" or army.tag == viewer:
		return true
	return Knowledge.sees(game, viewer, army.hex)


## The badge text of a men count (A9, D7: exact everywhere): under 1,000 the number, else tenths of a thousand as "1.0k"
## or "1.2k".
static func token_text(men: int) -> String:
	if men < K_UNIT:
		return str(men)
	var t := (men + TOKEN_ROUND) / 100
	return "%d.%dk" % [t / 10, t % 10]


## The Army panel's model of one army (6.5), {} when the viewer does not see it. Its own army (or any army for the viewer
## ""): {mine, id, name, tag, country, hex, place, men, limit, here, units, order, supply, upkeep, mp, points, sight,
## others_here}; `points` is {left, full, text} ("8 of 12 left this season", R51).
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
			"men_text": Words.men(a.men()),
		}
	return _own_panel(game, a, viewer)


static func _own_panel(game: Game, a: Army, viewer: StringName) -> Dictionary:
	var units: Array[Dictionary] = []
	var sight := 1
	for u: Unit in a.units:
		var ud := Military.unit_def(game, u.kind)
		var rank := Armies.rank_of(game, u)
		units.append({
			"id": u.id,
			"kind": u.kind,
			"name": ud.name if ud != null else "",
			"men": u.men,
			"full": ud.men if ud != null else 0,
			"raised_text": "Raised " + Calendar.date_text(u.raised_turn, game.start_year),
			"mustering": u.raised_turn == game.turn,
			"morale": u.morale,
			"morale_word": morale_word(game, u.morale),
			"xp": u.xp,
			"rank": rank,
			"rank_name": rank_name(game, rank),
		})
		if ud != null:
			sight = maxi(sight, ud.sight)
	var others: Array[Dictionary] = []
	for o: Army in Armies.at(game, a.hex):
		if o.id != a.id and o.tag == a.tag:
			others.append({"id": o.id, "name": o.name, "men": o.men()})
	var out := {
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
		"points": points_of(game, a),
		"sight": sight,
		"others_here": others,
	}
	out.merge(_war_parts(game, viewer, a))
	return out


## The war parts of an army's panel (6.8, M7): its standing (Hold or Withdraw) and the words of its morale; its battle when it
## is in one; its siege and the storm of its hex when it besieges; its last battle as the country's newest. Keys: standing,
## standing_text, morale (permille), morale_text ("Morale 62 %"), morale_word, too_shaken, battle {name, hex} or {}, siege {hex,
## name, progress, need, falls_in} or {}, storm_verdict {ok, reason} or {}, storm_word, last_battle {record, name, result} or {}.
static func _war_parts(game: Game, viewer: StringName, a: Army) -> Dictionary:
	var morale := Armies.morale_of(a)
	var out := {
		"standing": String(a.standing),
		"standing_text": "Withdraw" if a.standing == Army.STANDING_WITHDRAW else "Hold",
		"morale": morale,
		"morale_text": "Morale %d %%" % (morale / 10),
		"morale_word": morale_word(game, morale),
		"too_shaken": morale < game.defs.war.attack_morale,
		"battle": _battle_of(game, a),
		"siege": {},
		"storm_verdict": {},
		"storm_word": "",
		"last_battle": _last_battle(game, viewer, a.tag),
	}
	var s := Occupation.siege_at(game, a.hex)
	if s != null and s.besieger == a.tag:
		var v := SiegeView.at(game, viewer, a.hex)
		out.siege = {"hex": a.hex, "name": str(v.get("name", s.name)), "progress": int(v.get("progress", s.progress)),
			"need": int(v.get("need", Occupation.siege_need(game, a.hex))), "falls_in": int(v.get("falls_in", -1))}
		out.storm_verdict = Movement.storm_check(game, {"army": a.id, "goal": a.hex, "tag": a.tag})
		out.storm_word = str(OddsView.of(game, viewer, a.id, a.hex, true).get("word", ""))
	return out


## The word of a morale (permille): Steady from 750, Wavering from attack_morale, Shaken from withdraw_morale, else Broken.
static func morale_word(game: Game, morale: int) -> String:
	var war := game.defs.war
	if morale >= STEADY_MORALE:
		return "Steady"
	if morale >= war.attack_morale:
		return "Wavering"
	if morale >= war.withdraw_morale:
		return "Shaken"
	return "Broken"


## The army's move points this season: {left, full, text}, the text "8 of 12 left this season" (R51).
static func points_of(game: Game, a: Army) -> Dictionary:
	var full := Allowance.full(game, a)
	return {"left": a.points, "full": full, "text": "%d of %d left this season" % [a.points, full]}


## A company's rank name (WarDef.rank_names); the first rank, with no name in the data, is "Recruit".
static func rank_name(game: Game, rank: int) -> String:
	var names := game.defs.war.rank_names
	if rank < 0 or rank >= names.size() or names[rank].is_empty():
		return "Recruit" if rank <= 0 else ""
	return names[rank]


static func _battle_of(game: Game, a: Army) -> Dictionary:
	var b := Battles.of_army(game, a.id)
	if b == null:
		return {}
	return {"name": b.name, "hex": b.hex}


## The newest battle the country fought in, with its name and result as the viewer reads it ("won", "lost", "drawn").
static func _last_battle(game: Game, viewer: StringName, tag: StringName) -> Dictionary:
	var record := BattleView.latest_of(game, tag)
	if record < 0:
		return {}
	var v := BattleView.of(game, viewer, record)
	if v.is_empty():
		return {}
	var winner := str(v.result.winner)
	var result := "drawn" if winner == "" else ("won" if winner == String(tag) else "lost")
	return {"record": record, "name": str(v.name), "result": result}


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
## there, "Milan: 1,000 men" for a foreign one; "" for none.
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
			# Another country's armies on one hex are one figure, as their token is: summed.
			if not foreign_tags.has(a.tag):
				foreign_tags.append(a.tag)
			foreign_men[a.tag] = int(foreign_men.get(a.tag, 0)) + a.men()
	for tag: StringName in foreign_tags:
		parts.append("%s: %s" % [_country_name(game, tag), Words.men(int(foreign_men[tag]))])
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
