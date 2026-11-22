## What must hold after every season of any game (docs/architecture/m8-build-spec.md 4.17; v0.2.2's tests/support/invariants.py): the
## soak's checks and test_invariants' subject. Tests and tools only; nothing here changes the game.
##   before(game) -> Dictionary                 what the season's checks need from before it (take it before Season.run)
##   check(game, before, extra) -> PackedStringArray   one line a broken invariant, "name: what", empty when all hold; `extra` may
##                                              carry {"contract": PackedStringArray (the judge's problems), "errors": int (the
##                                              logger's count)}
## The names: turn, money, goods, people, men, districts, armies, battles, garrisons, morale, wars, chronicle, stats, contract, errors.
class_name Invariants
extends RefCounted

const NAMES: Array[String] = ["turn", "money", "goods", "people", "men", "districts", "armies", "battles", "garrisons", "morale",
	"wars", "chronicle", "stats", "contract", "errors"]
## A war lives at most this many seasons (WarDef.war_timer_seasons, 40): the timer ends it in the war phase.
const WAR_MAX := 40
const MORALE_MAX := Unit.MAX_MORALE
## Country ids run 1 to 254; slot 0 is the unowned.
const SLOTS := 256


## The numbers the season's checks compare with: the turn, the land count, every country's people, men under arms and garrison men,
## its open people flows, the owners, the chronicle's size and the event mark (the events of the season are those from it on).
static func before(game: Game) -> Dictionary:
	var census := _census(game)
	var flows := {}
	for c: Country in game.countries:
		flows[c.tag] = c.people_flows.duplicate()
	return {"turn": game.turn, "land": _land(game), "census": census, "open": flows, "owner": game.state.owner.duplicate(),
		"events": game.events.size(), "stats": game.stats.count if game.stats != null else 0}


## Every broken invariant after a season, named first. `before` is Invariants.before taken ahead of it.
static func check(game: Game, before_state: Dictionary, extra: Dictionary = {}) -> PackedStringArray:
	var out := PackedStringArray()
	_turn(game, before_state, out)
	_money(game, before_state, out)
	_goods(game, out)
	_hexes(game, before_state, out)
	_men(game, before_state, out)
	_armies(game, out)
	if not game.battles.is_empty():
		out.append("battles: %d battle(s) alive at idle" % game.battles.size())
	_wars(game, out)
	_chronicle(game, out)
	_stats(game, out)
	for line: String in extra.get("contract", PackedStringArray()) as PackedStringArray:
		out.append("contract: " + line)
	var errors := int(extra.get("errors", 0))
	if errors > 0:
		out.append("errors: %d engine or script error(s) logged" % errors)
	return out


## The report of a broken game: its lines, one after the other.
static func report(lines: PackedStringArray) -> String:
	return "\n".join(lines)


# --- the censuses ----------------------------------------------------------------------------------------------------------


## {tag: [people on its land, men under arms, garrison men]} in one pass over the hexes.
static func _census(game: Game) -> Dictionary:
	var people := PackedInt64Array()
	people.resize(SLOTS)
	var garrison := PackedInt64Array()
	garrison.resize(SLOTS)
	var state := game.state
	for i: int in game.map.hex_count():
		if game.map.land[i] == 1:
			var o := int(state.owner[i])
			people[o] += int(state.people[i])
			garrison[o] += int(state.garrison[i]) if i < state.garrison.size() else 0
	var out := {}
	for c: Country in game.countries:
		out[c.tag] = [int(people[c.id]), Armies.men_of_country(game, c.tag), int(garrison[c.id])]
	return out


static func _land(game: Game) -> int:
	var n := 0
	for i: int in game.map.hex_count():
		n += game.map.land[i]
	return n


# --- turn, money, goods ----------------------------------------------------------------------------------------------------


static func _turn(game: Game, before_state: Dictionary, out: PackedStringArray) -> void:
	if game.turn != int(before_state["turn"]) + 1:
		out.append("turn: %d after %d (want one more)" % [game.turn, int(before_state["turn"])])


## Per country: its closed ledger's closing less opening is the sum of its lines, and every line's reason is a Treasury.WHY.
static func _money(game: Game, before_state: Dictionary, out: PackedStringArray) -> void:
	for c: Country in game.countries:
		var closed := c.ledger_closed
		if closed.is_empty() or int(closed["turn"]) != int(before_state["turn"]):
			out.append("money: %s has no closed ledger for turn %d" % [c.tag, int(before_state["turn"])])
			continue
		var sum := 0
		for line: Dictionary in closed["lines"]:
			sum += int(line["amount"])
			if not Treasury.WHY.has(line["why"] as StringName):
				out.append("money: %s has a line with the reason '%s'" % [c.tag, str(line["why"])])
		var change := int(closed["closing"]) - int(closed["opening"])
		if change != sum:
			out.append("money: %s ledger closed %+d, its lines sum %+d (a treasury edited outside a ledger: %+d)" % [
				c.tag, change, sum, change - sum])


## Per country and good: the closed stock's change is the sum of its flows; no stock below 0.
static func _goods(game: Game, out: PackedStringArray) -> void:
	var goods := game.defs.goods.size()
	for c: Country in game.countries:
		for g: int in c.stock.size():
			if c.stock[g] < 0:
				out.append("goods: %s has %d of good %d" % [c.tag, c.stock[g], g])
		var closed := c.goods_closed
		if closed.is_empty():
			continue
		var opening := closed["opening"] as PackedInt32Array
		var closing := closed["closing"] as PackedInt32Array
		var flows := closed["flows"] as PackedInt32Array
		for g: int in mini(goods, closing.size()):
			var sum := 0
			for f: int in Stores.FLOWS.size():
				sum += int(flows[f * goods + g])
			if int(closing[g]) - int(opening[g]) != sum:
				out.append("goods: %s good %d closed %+d, its flows sum %+d" % [c.tag, g, int(closing[g]) - int(opening[g]), sum])


# --- the hexes: people, districts, garrisons, morale ----------------------------------------------------------------------


static func _hexes(game: Game, before_state: Dictionary, out: PackedStringArray) -> void:
	var state := game.state
	var land := 0
	for i: int in game.map.hex_count():
		if game.map.land[i] != 1:
			if state.people[i] != 0:
				out.append("people: %d people on the sea hex %s" % [state.people[i], str(game.map.hex_of(i))])
			continue
		land += 1
		if state.people[i] < 0:
			out.append("people: %d people on %s" % [state.people[i], str(game.map.hex_of(i))])
		if int(state.owner[i]) == 0:
			out.append("districts: %s has no owner" % str(game.map.hex_of(i)))
		_occupier(game, i, out)
		_garrison(game, i, out)
	if land != int(before_state["land"]):
		out.append("districts: land count %d, was %d" % [land, int(before_state["land"])])
	for a: Army in game.armies:
		for u: Unit in a.units:
			if u.morale < 0 or u.morale > MORALE_MAX:
				out.append("morale: unit %d of army %d has %d" % [u.id, a.id, u.morale])


static func _occupier(game: Game, i: int, out: PackedStringArray) -> void:
	var occ := int(game.state.occupier[i])
	if occ == 0:
		return
	var by := Countries.by_id(game, occ)
	var owner := Countries.by_id(game, int(game.state.owner[i]))
	if by == null or not by.alive or owner == null or not Wars.at_war(game, by.tag, owner.tag):
		out.append("districts: %s occupied by %d, not a living country at war with its owner" % [str(game.map.hex_of(i)), occ])


static func _garrison(game: Game, i: int, out: PackedStringArray) -> void:
	var men := int(game.state.garrison[i])
	if men == 0:
		return
	var hex := game.map.hex_of(i)
	var full := Occupation.garrison_full(game, hex)
	if men < 0 or men > full:
		out.append("garrisons: %s holds %d of a full %d" % [str(hex), men, full])
	elif int(game.state.occupier[i]) != 0:
		out.append("garrisons: the occupied fortress %s holds %d" % [str(hex), men])


# --- armies ---------------------------------------------------------------------------------------------------------------


static func _armies(game: Game, out: PackedStringArray) -> void:
	var holders := {}
	var companies := {}
	for a: Army in game.armies:
		var label := "army %d (%s) at %s" % [a.id, a.tag, str(a.hex)]
		var i := game.map.index_of(a.hex)
		if i < 0 or game.map.land[i] != 1:
			out.append("armies: %s is not on land" % label)
		elif not Movement.open_to(game, a.tag, a.hex):
			out.append("armies: %s stands on land not open to it" % label)
		if a.units.is_empty():
			out.append("armies: %s has no unit" % label)
		for u: Unit in a.units:
			var def := game.defs.unit_def(u.kind)
			if u.men < 1 or (def != null and u.men > def.men):
				out.append("armies: %s unit %d has %d men (full %d)" % [label, u.id, u.men, def.men if def != null else -1])
		var key := a.hex
		if holders.has(key) and holders[key] != a.tag:
			out.append("armies: %s and %s share %s" % [a.tag, str(holders[key]), str(a.hex)])
		holders[key] = a.tag
		var here := str(a.tag) + str(a.hex)
		companies[here] = int(companies.get(here, 0)) + a.units.size()
		if int(companies[here]) > Military.stack_limit(game, a.tag):
			out.append("armies: %s holds %d companies of %s (limit %d)" % [str(a.hex), int(companies[here]), a.tag,
				Military.stack_limit(game, a.tag)])


# --- the men ---------------------------------------------------------------------------------------------------------------


## M7 4.14: per country Δ people + Δ men + Δ garrison = the flows that move no man between the three, less the losses (hunger,
## battle, a capture's garrison); the world's change always, a country's only in a season no peace moved land in.
static func _men(game: Game, before_state: Dictionary, out: PackedStringArray) -> void:
	var losses := _losses(game, int(before_state["turn"]), int(before_state["events"]))
	var moved: bool = game.state.owner != (before_state["owner"] as PackedByteArray)
	var post := _census(game)
	var pre: Dictionary = before_state["census"]
	var world_change := 0
	var world_flows := 0
	for c: Country in game.countries:
		var window := _window(c, before_state)
		var change := 0
		for k: int in 3:
			change += int(post[c.tag][k]) - int(pre[c.tag][k])
		var flows := window - int(losses.get(c.tag, 0))
		world_change += change
		world_flows += flows
		if not moved and change != flows:
			out.append("men: %s people, men and garrisons changed %+d, its flows less losses are %+d" % [c.tag, change, flows])
	if world_change != world_flows:
		out.append("men: the world changed %+d people, men and garrisons, its flows less losses are %+d" % [world_change, world_flows])


## The season's flows of a country that move people in or out of its three stocks: the closed flows less what was open before the
## season, plus what is open now (the refill after the calendar books to the next close), without the three inner moves.
static func _window(c: Country, before_state: Dictionary) -> int:
	var closed := c.people_closed["flows"] as PackedInt32Array
	var was: PackedInt32Array = before_state["open"][c.tag]
	var sum := 0
	for f: int in closed.size():
		if f == People.FLOWS.find(&"raised") or f == People.FLOWS.find(&"returned") or f == People.FLOWS.find(&"garrisoned"):
			continue
		sum += closed[f] - was[f] + c.people_flows[f]
	return sum


## {tag: men lost this season}: hunger, battles (killed and wounded not returned) and a capture's garrison men, by country.
static func _losses(game: Game, ended: int, from_event: int) -> Dictionary:
	var out := {}
	for k: int in range(from_event, game.events.size()):
		var e := game.events[k]
		var kind := str(e.get("kind", ""))
		if kind == "army_starved":
			var t := StringName(str(e["tag"]))
			out[t] = int(out.get(t, 0)) + int(e["lost"])
		elif kind == "district_captured":
			var t := StringName(str(e.get("owner", "")))
			out[t] = int(out.get(t, 0)) + int(e.get("garrison_lost", 0))
	var owner_of := {}
	for a: Army in game.armies:
		for u: Unit in a.units:
			owner_of[u.id] = a.tag
	for r: BattleRecord in game.battle_records:
		if r.turn != ended:
			continue
		var sides: Array[StringName] = [r.attacker, r.defender]
		var returned: Dictionary = r.end["returned"]
		for side: int in 2:
			var back := 0
			for uid: Variant in returned:
				if owner_of.get(int(uid), &"") == sides[side]:
					back += int(returned[uid])
			out[sides[side]] = int(out.get(sides[side], 0)) + int(r.end["killed"][side]) + int(r.end["wounded_total"][side]) - back
	return out


# --- wars, chronicle, stats -----------------------------------------------------------------------------------------------


static func _wars(game: Game, out: PackedStringArray) -> void:
	var truce := game.defs.war.truce_seasons if game.defs.war != null else 0
	for w: War in game.wars:
		if not w.live():
			continue
		if game.turn - w.start_turn > WAR_MAX:
			out.append("wars: war %d (%s on %s) is %d seasons old" % [w.id, w.a, w.b, game.turn - w.start_turn])
		for other: War in game.wars:
			if other.id == w.id or other.id > w.id:
				continue
			if not ((other.a == w.a and other.b == w.b) or (other.a == w.b and other.b == w.a)):
				continue
			if other.live():
				out.append("wars: two live wars between %s and %s" % [w.a, w.b])
			elif w.start_turn < other.end_turn + truce:
				out.append("wars: war %d between %s and %s began in turn %d, in the truce to turn %d" % [w.id, w.a, w.b,
					w.start_turn, other.end_turn + truce])


static func _chronicle(game: Game, out: PackedStringArray) -> void:
	var entries := game.chronicle.entries
	if entries.size() > Chronicle.KEEP:
		out.append("chronicle: %d entries (keep %d)" % [entries.size(), Chronicle.KEEP])
	var last := -1
	for e: Dictionary in entries:
		var turn := int(e.get("turn", 0))
		if turn < last:
			out.append("chronicle: turn %d after turn %d" % [turn, last])
			return
		last = turn


static func _stats(game: Game, out: PackedStringArray) -> void:
	if game.stats != null and game.stats.count != game.turn - Calendar.FIRST_TURN:
		out.append("stats: %d rows after %d seasons" % [game.stats.count, game.turn - Calendar.FIRST_TURN])
