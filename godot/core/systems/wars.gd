## The war door (docs/architecture/m7-build-spec.md 4.2, 4.9, 5.3; M7 plan B5): declaring a war, the score, the peace terms and
## their checks, what a peace would cede, the truce, the books of a fought battle, and the wars' digest and save body. The
## only writer of game.wars and next_war_id. Land and armies are read here, never written. The peace itself (make_peace,
## end_war) and the timer (season) are B11: they need Occupation.release (B6) and the armies' moves (B8, B12).
## Words name a country by "the " + its long name, as the spec says; a verdict is {ok, reason}, "" when ok.
class_name Wars
extends RefCounted

const OWNS: Array[String] = ["wars", "next_war_id"]
## The terms a peace may take (4.9); the timer's term (&"timer") is written by B11, never asked for.
const TERMS: Array[StringName] = [&"take", &"white", &"yield"]
## The text a refused saved body gives (Armies.PROBLEM_BODY's form).
const PROBLEM_BODY := "body"


# --- queries ---------------------------------------------------------------------------------------------------------


## True while a live war joins a and b (in either order).
static func at_war(game: Game, a: StringName, b: StringName) -> bool:
	return War.live_between(game.wars, a, b) != null


## The countries at war with tag through a live war, in country id order.
static func enemies(game: Game, tag: StringName) -> Array[StringName]:
	var ids := PackedInt32Array()
	for w: War in game.wars:
		var other := w.other(tag) if w.live() else &""
		var c := Countries.by_tag(game, other)
		if c != null and not ids.has(c.id):
			ids.append(c.id)
	ids.sort()
	var out: Array[StringName] = []
	for id: int in ids:
		out.append(Countries.by_id(game, id).tag)
	return out


## The live war between a and b, or null.
static func war_between(game: Game, a: StringName, b: StringName) -> War:
	return War.live_between(game.wars, a, b)


## Every war tag is in, live and ended, in war id order.
static func of_country(game: Game, tag: StringName) -> Array[War]:
	var out: Array[War] = []
	for w: War in game.wars:
		if w.a == tag or w.b == tag:
			out.append(w)
	return out


## The men tag has under arms (every army it owns, every company).
static func men_under_arms(game: Game, tag: StringName) -> int:
	return Armies.men_of_country(game, tag)


## The number of districts of `of_tag` whose occupier is `by` (4.2: occupied(by in of_tag)).
static func occupied_count(game: Game, by: StringName, of_tag: StringName) -> int:
	var held := Countries.by_tag(game, of_tag)
	var occupant := Countries.by_tag(game, by)
	if held == null or occupant == null or game.state == null:
		return 0
	var total := 0
	for i: int in Territory.districts(game, held.id):
		if i < game.state.occupier.size() and int(game.state.occupier[i]) == occupant.id:
			total += 1
	return total


## The score of a against b (4.2, the M9 seam): the districts a holds of b's, less those b holds of a's, with the capital
## term (capital_score each) for a capital held. Antisymmetric: score(b, a) == -score(a, b). 0 for an unknown tag or
## the same country.
static func score(game: Game, a: StringName, b: StringName) -> int:
	var ca := Countries.by_tag(game, a)
	var cb := Countries.by_tag(game, b)
	if ca == null or cb == null or ca.id == cb.id:
		return 0
	var capital := _def(game).capital_score if _def(game) != null else 0
	var total := occupied_count(game, a, b) - occupied_count(game, b, a)
	if _holds_capital(game, ca, cb):
		total += capital
	if _holds_capital(game, cb, ca):
		total -= capital
	return total


## The truce between a and b: the first season either may declare again, from the newest ended war between them
## (end_turn + truce_seasons). 0 when no war between them has ended.
static func truce_until(game: Game, a: StringName, b: StringName) -> int:
	var newest: War = null
	for w: War in game.wars:
		if w.live():
			continue
		if (w.a == a and w.b == b) or (w.a == b and w.b == a):
			if newest == null or w.id > newest.id:
				newest = w
	var numbers := _def(game)
	if newest == null or numbers == null:
		return 0
	return newest.end_turn + numbers.truce_seasons


# --- declaring -------------------------------------------------------------------------------------------------------


## Verdict for declare_war {target, tag} (4.2), in the spec's order; the first refusal is the reason.
static func declare_war_check(game: Game, args: Dictionary) -> Dictionary:
	var target := _name_arg(args, "target")
	if target == &"":
		return _refusal("no country given")
	var tag := _name_arg(args, "tag")
	var gate := _roster_problem(game, tag, target)
	if gate != "":
		return _refusal(gate)
	var actor := Countries.by_tag(game, tag)
	var victim := Countries.by_tag(game, target)
	if actor.id == victim.id:
		return _refusal("a country cannot make war on itself")
	if not actor.alive or not victim.alive:
		var gone := actor if not actor.alive else victim
		return _refusal("%s is no more" % _name(game, gone.tag))
	if War.live_between(game.wars, tag, target) != null:
		return _refusal("already at war with %s" % _the(game, target))
	var until := truce_until(game, tag, target)
	if until > game.turn:
		return _refusal("a truce with %s holds until %s (%d more seasons)" % [_the(game, target),
			Calendar.date_text(until, game.start_year), until - game.turn])
	if not Territory.neighbours(game, actor.id).has(victim.id):
		return _refusal("only neighbours go to war: %s shares no border with %s" % [_the(game, target), _the(game, tag)])
	return _ok()


## Declares the war after checking again: a War with the next id, a = the actor, b = the target, starting this season;
## queues war_declared (witnesses: every living country). A refused declaration changes nothing.
static func declare_war(game: Game, args: Dictionary) -> Dictionary:
	var verdict := declare_war_check(game, args)
	if not bool(verdict["ok"]):
		return verdict
	var tag := _name_arg(args, "tag")
	var target := _name_arg(args, "target")
	var w := War.new()
	w.id = game.next_war_id
	w.a = tag
	w.b = target
	w.start_turn = game.turn
	game.next_war_id += 1
	game.wars.append(w)
	game.emit({"kind": "war_declared", "tag": tag, "target": target, "war": w.id, "witnesses": living_tags(game)})
	return verdict


## Verdict for make_peace {target, terms, tag} (4.9), in the spec's order. The peace itself is B11.
static func make_peace_check(game: Game, args: Dictionary) -> Dictionary:
	var target := _name_arg(args, "target")
	if target == &"":
		return _refusal("no country given")
	var terms := _name_arg(args, "terms")
	if terms == &"":
		return _refusal("no terms given")
	var tag := _name_arg(args, "tag")
	var gate := _roster_problem(game, tag, target)
	if gate != "":
		return _refusal(gate)
	var war := War.live_between(game.wars, tag, target)
	if war == null:
		return _refusal("not at war with %s" % _the(game, target))
	if not TERMS.has(terms):
		return _refusal("no such terms: take, white or yield")
	var numbers := _def(game)
	if numbers == null:
		return _refusal("this game has no war numbers")
	if terms == &"white":
		return _white_verdict(game, war, numbers, tag, target)
	if terms == &"take":
		return _take_verdict(game, numbers, tag, target)
	return _ok()


## What a peace on these terms would move (4.9's take and yield; white and an empty list for no move): the districts the
## winner holds of the loser's, in hex index order, never the loser's capital and never its last district (a take that
## would empty the loser lists one less). The actor is the side that asks.
static func ceded(game: Game, war: War, terms: StringName, actor: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if war == null or game.state == null or game.map == null:
		return out
	var winner: StringName = &""
	var loser: StringName = &""
	if terms == &"take":
		winner = actor
		loser = war.other(actor)
	elif terms == &"yield":
		loser = actor
		winner = war.other(actor)
	else:
		return out
	var won := Countries.by_tag(game, winner)
	var lost := Countries.by_tag(game, loser)
	if won == null or lost == null:
		return out
	var held := Territory.districts(game, lost.id)
	for i: int in held:
		if i >= game.state.occupier.size():
			continue
		var hex := game.map.hex_of(i)
		if int(game.state.occupier[i]) == won.id and hex != lost.capital:
			out.append(hex)
	if not out.is_empty() and out.size() >= held.size():
		out.pop_back()
	return out


## Books a fought battle to its live war (4.2): the battles each side won and the men each lost (killed, plus the wounded
## who did not return). A battle with no live war between its two sides books nothing. The record's end gives killed and
## wounded_total per side (0 attacker, 1 defender) and returned by unit key; a key's side is read from the record's input
## fighters. The writer of the war's counts is this function only.
static func book_battle(game: Game, record: BattleRecord) -> void:
	var w := War.live_between(game.wars, record.attacker, record.defender)
	if w == null:
		return
	var killed := _pair_of(record.end.get("killed", null))
	var wounded := _pair_of(record.end.get("wounded_total", null))
	if killed.is_empty() or wounded.is_empty():
		return
	var returned := _returned_by_side(record)
	for side: int in 2:
		var tag := record.attacker if side == 0 else record.defender
		var lost: int = killed[side] + wounded[side] - returned[side]
		if w.a == tag:
			w.lost_a += lost
		else:
			w.lost_b += lost
	# Combat's winner is an int: 0 the attacker, 1 the defender, -1 a draw (it books no win).
	var winner_side := int(record.end.get("winner", -1))
	var won: StringName = record.attacker if winner_side == 0 else (record.defender if winner_side == 1 else &"")
	if won == w.a:
		w.won_a += 1
	elif won == w.b:
		w.won_b += 1


## Two counts of a record's end (per side, attacker first) as a PackedInt32Array, or empty when the value is not two numbers
## (a packed array, or an array of two; a JSON round trip gives the array form).
static func _pair_of(value: Variant) -> PackedInt32Array:
	var out := PackedInt32Array()
	if value is PackedInt32Array and (value as PackedInt32Array).size() == 2:
		return value as PackedInt32Array
	if value is Array and (value as Array).size() == 2:
		for n: Variant in value as Array:
			out.append(int(n))
	return out


# --- the saved body and the digest -----------------------------------------------------------------------------------


## The war body (5.2, 4.20): {schema: War.SCHEMA, next_war_id, wars: [War.to_dict] in id order}.
static func to_dict(game: Game) -> Dictionary:
	var list: Array = []
	for w: War in game.wars:
		list.append(w.to_dict())
	return {"schema": War.SCHEMA, "next_war_id": game.next_war_id, "wars": list}


## Fills game.wars and next_war_id from a saved body, or refuses with PROBLEM_BODY and changes nothing. It refuses a wrong
## schema, a next id out of int32 or below 1, a war that fails War.from_dict, a war id not ascending or not below the next
## id, a counter past WarDef.MAX_COUNT, a war that names a country the game lacks or one not alive (both sides, every war),
## a start or an end past the current season, a moved count past the map's hexes, and two live wars between one pair. A
## live war names two living countries; an ended war names two countries that exist (they may have died since).
static func from_dict(d: Dictionary, game: Game) -> String:
	if game == null or not game.has_countries() or game.map == null:
		return PROBLEM_BODY
	if str(d.get("schema", "")) != War.SCHEMA:
		return PROBLEM_BODY
	var next_id: Variant = Unit.int32(d.get("next_war_id", null))
	var raw: Variant = d.get("wars", null)
	if next_id == null or int(next_id) < 1 or not (raw is Array):
		return PROBLEM_BODY
	var list: Array[War] = []
	var last_id := 0
	for item: Variant in raw as Array:
		if not (item is Dictionary):
			return PROBLEM_BODY
		var w := War.from_dict(item as Dictionary)
		if w == null or w.id <= last_id or w.id >= int(next_id) or not _war_ok(game, w):
			return PROBLEM_BODY
		last_id = w.id
		list.append(w)
	if not _pairs_ok(list):
		return PROBLEM_BODY
	game.wars = list
	game.next_war_id = int(next_id)
	return ""


## "next_war_id" then each war's digest text in id order, one per line (4.20: Game.digest joins it, B13).
static func digest(game: Game) -> String:
	var lines := PackedStringArray()
	for w: War in game.wars:
		lines.append(w.digest_text())
	return "%d\n%s" % [game.next_war_id, "\n".join(lines)]


## The tags of every living country in id order (the witnesses of a war's event, 4.14).
static func living_tags(game: Game) -> PackedStringArray:
	var out := PackedStringArray()
	for c: Country in game.countries:
		if c != null and c.alive:
			out.append(String(c.tag))
	return out


# --- helpers ---------------------------------------------------------------------------------------------------------


## The white peace verdict (4.9 rows 5 and 6): the war is old enough and the other side is not winning.
static func _white_verdict(game: Game, war: War, numbers: WarDef, tag: StringName, target: StringName) -> Dictionary:
	var age := game.turn - war.start_turn
	if age < numbers.peace_min_seasons:
		return _refusal("a white peace needs %d seasons of war: %d more" % [numbers.peace_min_seasons,
			numbers.peace_min_seasons - age])
	var total := score(game, tag, target)
	if total < numbers.white_score_min:
		return _refusal("they are winning (score %+d): they refuse a white peace" % total)
	return _ok()


## The take verdict (4.9 rows 7 and 8): the actor holds one of their districts, and the score or the armies carry it.
static func _take_verdict(game: Game, numbers: WarDef, tag: StringName, target: StringName) -> Dictionary:
	if occupied_count(game, tag, target) == 0:
		return _refusal("you hold none of their districts")
	var total := score(game, tag, target)
	var beat_armies := men_under_arms(game, target) <= men_under_arms(game, tag)
	if total < numbers.take_score and not (total >= numbers.take_score_weak and beat_armies):
		return _refusal("they refuse: score %+d; hold %d or more of their districts, or beat their armies"
			% [total, numbers.take_score])
	return _ok()


## Rows 2 to 4 of 4.2: the map has countries, tag is chosen and both countries exist. "" when they hold.
static func _roster_problem(game: Game, tag: StringName, target: StringName) -> String:
	if game == null or not game.has_countries():
		return "this map has no countries"
	if tag == &"":
		return "choose your country first"
	if Countries.by_tag(game, tag) == null:
		return "no country %s" % String(tag)
	if Countries.by_tag(game, target) == null:
		return "no country %s" % String(target)
	return ""


## True when `by` holds the capital of `of` (the capital is `of`'s, the occupier is `by`). A capital off the map counts for
## nobody.
static func _holds_capital(game: Game, by: Country, of: Country) -> bool:
	if game.map == null or game.state == null:
		return false
	var i := game.map.index_of(of.capital)
	if i < 0 or i >= game.state.owner.size() or i >= game.state.occupier.size():
		return false
	return int(game.state.owner[i]) == of.id and int(game.state.occupier[i]) == by.id


## One saved war checked against the game: both countries exist; a live war names two living countries (an ended one may
## name a country that died after the peace: extinction comes later), and the season and the counts are in range.
static func _war_ok(game: Game, w: War) -> bool:
	for tag: StringName in [w.a, w.b]:
		var c := Countries.by_tag(game, tag)
		if c == null or (w.live() and not c.alive):
			return false
	if w.start_turn > game.turn or w.end_turn > game.turn:
		return false
	for n: int in [w.won_a, w.won_b, w.lost_a, w.lost_b]:
		if n > WarDef.MAX_COUNT:
			return false
	return w.moved <= game.map.hex_count()


## No two live wars between one pair of countries (the declaration's row 7 holds on a load too).
static func _pairs_ok(list: Array[War]) -> bool:
	for i: int in list.size():
		for j: int in range(i + 1, list.size()):
			if list[i].live() and list[j].live() and list[i].other(list[j].a) != &"" \
					and list[i].other(list[j].b) != &"" and list[i].other(list[j].a) == list[j].b:
				return false
	return true


## The men each side returned (0 attacker, 1 defender): end.returned by unit key, the key's side from the input fighters.
static func _returned_by_side(record: BattleRecord) -> PackedInt32Array:
	var out := PackedInt32Array([0, 0])
	var side_of: Dictionary = {}
	var fighters: Variant = record.input.get("fighters", [])
	if fighters is Array:
		for f: Variant in fighters as Array:
			if f is Dictionary:
				var fd := f as Dictionary
				side_of[int(str(fd.get("key", 0)))] = int(str(fd.get("side", -1)))
	var returned: Variant = record.end.get("returned", {})
	if returned is Dictionary:
		var map := returned as Dictionary
		for k: Variant in map:
			var side := int(side_of.get(int(str(k)), -1))
			if side == 0 or side == 1:
				out[side] += int(map[k])
	return out


static func _def(game: Game) -> WarDef:
	return game.defs.war if game != null and game.defs != null else null


## A name argument as a StringName (a String or a StringName; anything else is &"").
static func _name_arg(args: Dictionary, key: String) -> StringName:
	var raw: Variant = args.get(key, &"")
	if raw is StringName:
		return raw
	if raw is String:
		return StringName(raw as String)
	return &""


## A country's long name (its CountryDef's), or its tag when it has none.
static func _name(game: Game, tag: StringName) -> String:
	var cdef := Countries.def_of(game, tag)
	if cdef != null and not cdef.name.is_empty():
		return cdef.name
	return String(tag)


## "the " + the long name.
static func _the(game: Game, tag: StringName) -> String:
	var cdef := Countries.def_of(game, tag)
	if cdef != null and not cdef.long_name.is_empty():
		return "the " + cdef.long_name
	return "the " + _name(game, tag)


static func _ok() -> Dictionary:
	return {"ok": true, "reason": ""}


static func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
