## What must hold after every season of any game (docs/architecture/m8-build-spec.md 4.17; v0.2.2's tests/support/invariants.py): the
## soak's checks and test_invariants' subject. Tests and tools only; nothing here changes the game.
##   before(game) -> Dictionary                 what the season's checks need from before it (take it before Season.run)
##   check(game, before, extra) -> PackedStringArray   one line a broken invariant, "name: what", empty when all hold; `extra` may
##                                              carry {"contract": PackedStringArray (the judge's problems), "errors": int (the
##                                              logger's count), "moves": Moves (the season's watch), "reload": bool (I6 now)}
##   Moves.start(game), watch.look(game, where)   the watch of a season's moves: a look after every act (where Moves.ACT) and
##                                              after every phase (where the phase's name); its lines are in `lines`
## Moves in the month (moves-build-spec.md 8.4): I1 `points` (0 to the full), I2 `spent` (a season's walks cost at most what the
## army had), I3 `grown` (points grow only in ready_units), I4 `battles` (none open at idle or after an act), I5 `armies` (also
## after every act), I6 `saved` (save, load: the same digest), I7 `walks` (no walk at once of the player in a season's records),
## I8 `stood` (a standing march with no points does not move in the movement phase). I2, I3 and I8 need the watch.
## The names: turn, money, goods, people, men, districts, armies, battles, garrisons, morale, wars, chronicle, stats, explored,
## controlled, contract, errors. `explored` (spec R4, the explored set only grows) and `controlled` (every land hex a country
## controls is explored by it) are the fog invariants of FG14; `Invariants.planted = "fog"` (tests only) breaks `explored`,
## "moves" gives an army its points back in the middle of a season, which breaks `grown` and `spent`.
class_name Invariants
extends RefCounted

const NAMES: Array[String] = ["turn", "money", "goods", "people", "men", "districts", "armies", "battles", "garrisons", "morale",
	"wars", "chronicle", "stats", "explored", "controlled", "contract", "errors", "points", "spent", "grown", "saved", "walks",
	"stood"]
## A war lives at most this many seasons (WarDef.war_timer_seasons, 40): the timer ends it in the war phase.
const WAR_MAX := 40
const MORALE_MAX := Unit.MAX_MORALE
## Country ids run 1 to 254; slot 0 is the unowned.
const SLOTS := 256
## Tests and tools only: the soak's planted fault (`soak --plant=fog` sets it per game). "fog" clears one explored hex that
## the country's sight does not reach, once, in the check of the first season that has one; check() then names it.
## "moves" (`soak --plant=moves`) is read by Moves.look before the movement phase, once, in the first season with an army to
## give its points back to.
static var planted := ""


## The numbers the season's checks compare with: the turn, the land count, every country's people, men under arms and garrison men,
## its open people flows, the owners, the chronicle's size and the event mark (the events of the season are those from it on).
static func before(game: Game) -> Dictionary:
	var census := _census(game)
	var flows := {}
	for c: Country in game.countries:
		flows[c.tag] = c.people_flows.duplicate()
	var explored := {}
	for c: Country in game.countries:
		explored[c.tag] = c.explored.duplicate()
	return {"turn": game.turn, "land": _land(game), "census": census, "open": flows, "owner": game.state.owner.duplicate(),
		"events": game.events.size(), "stats": game.stats.count if game.stats != null else 0, "explored": explored}


## Every broken invariant after a season, named first. `before` is Invariants.before taken ahead of it.
static func check(game: Game, before_state: Dictionary, extra: Dictionary = {}) -> PackedStringArray:
	var out := PackedStringArray()
	if planted == "fog":
		_plant_fog(game)
	_turn(game, before_state, out)
	_money(game, before_state, out)
	_goods(game, out)
	_hexes(game, before_state, out)
	_explored_grows(game, before_state, out)
	_controlled(game, out)
	_men(game, before_state, out)
	_armies(game, out)
	if not game.battles.is_empty():
		out.append("battles: %d battle(s) alive at idle" % game.battles.size())
	_wars(game, out)
	_chronicle(game, out)
	_stats(game, out)
	out.append_array(point_lines(game))
	_season_walks(game, before_state, out)
	var moves := extra.get("moves", null) as Moves
	if moves != null:
		for line: String in moves.lines:
			if not out.has(line):
				out.append(line)
	if bool(extra.get("reload", false)):
		out.append_array(reload_lines(game))
	for line: String in extra.get("contract", PackedStringArray()) as PackedStringArray:
		out.append("contract: " + line)
	var errors := int(extra.get("errors", 0))
	if errors > 0:
		out.append("errors: %d engine or script error(s) logged" % errors)
	return out


## The report of a broken game: its lines, one after the other.
static func report(lines: PackedStringArray) -> String:
	return "\n".join(lines)


# --- the moves of the month (moves-build-spec.md 8.4) -----------------------------------------------------------------------


## I1: every army's move points are 0 to its full.
static func point_lines(game: Game) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in Allowance.check(game):
		out.append("points: " + line)
	return out


## I4 and I5 as they hold after any act: a battle fought at once leaves none open, and every army stands where it may.
static func act_lines(game: Game) -> PackedStringArray:
	var out := PackedStringArray()
	if not game.battles.is_empty():
		out.append("battles: %d battle(s) alive after an act" % game.battles.size())
	_armies(game, out)
	return out


## I6: the game saved and loaded again has the same digest.
static func reload_lines(game: Game) -> PackedStringArray:
	var back := Snapshot.restore(Snapshot.of(game), game.map, game.defs)
	var loaded := back["game"] as Game
	if loaded == null:
		return PackedStringArray(["saved: the save of turn %d does not load (%s)" % [game.turn, str(back["problem"])]])
	if loaded.digest() != game.digest():
		return PackedStringArray(["saved: the game of turn %d loads with another digest" % game.turn])
	return PackedStringArray()


## I7: the records of a season hold no walk at once of the player's country (its walks are made, and played, at idle). The
## retreat of its army from a battle a computer opened is a record of the season and is not a walk.
static func _season_walks(game: Game, before_state: Dictionary, out: PackedStringArray) -> void:
	if game.player == &"":
		return
	for k: int in range(int(before_state["events"]), game.events.size()):
		var e := game.events[k]
		if str(e.get("kind", "")) == "unit_moved" and bool(e.get("now", false)) and str(e.get("why", "")) == "march" \
				and StringName(str(e.get("tag", ""))) == game.player:
			out.append("walks: a walk at once of the player's army %d is in the season's records" % int(e.get("army", 0)))


## The watch of the moves (I1 to I5 and I8), told of every act and every phase: it keeps what each army had at the last look,
## reads the walks (unit_moved, why march) queued since and prices their steps itself (StepCosts, the points the army had).
## Look before the game's events are drained or cleared.
class Moves extends RefCounted:
	## The `where` of a look after one act (a player's or a computer's); any other `where` is a phase of Season.PHASES.
	const ACT := &"act"

	var lines := PackedStringArray()
	var _events := 0
	## Army id -> its points, and its full points, at the last look.
	var _points := {}
	var _full := {}
	## Army id -> the points it had when first seen this season, and the points its walks have cost since.
	var _allowance := {}
	var _spent := {}
	## Tag -> its explored bits at the last look, for the countries with armies (a fog step is read from them).
	var _explored := {}
	## Army id -> hex: the standing marches with no points at the last look.
	var _standing := {}


	static func start(game: Game) -> Moves:
		var out := Moves.new()
		out._events = game.events.size()
		out._take(game)
		return out


	## Reads what happened since the last look; `where` is ACT or the phase just run.
	func look(game: Game, where: StringName) -> void:
		_walked(game)
		if Invariants.planted == "moves" and where == &"ai_orders":
			_plant(game)
		if where == &"ready_units":
			_allowance.clear()  # the new season's points: a new count
			_spent.clear()
		else:
			_grown(game, where)
		if where == &"movement":
			_stood(game)
		for line: String in Invariants.point_lines(game):
			_add(line)
		if where == ACT:
			for line: String in Invariants.act_lines(game):
				_add(line)
		_take(game)


	func _add(line: String) -> void:
		if not lines.has(line):
			lines.append(line)


	func _take(game: Game) -> void:
		_points.clear()
		_full.clear()
		_explored.clear()
		_standing.clear()
		for a: Army in game.armies:
			_points[a.id] = a.points
			_full[a.id] = Allowance.full(game, a)
			if not _allowance.has(a.id):
				_allowance[a.id] = a.points
			if not _explored.has(a.tag):
				_explored[a.tag] = FogStep.mapped(game, a.tag).duplicate()
			if a.points == 0 and (a.order == Army.ORDER_MARCH or a.order == Army.ORDER_STORM):
				_standing[a.id] = a.hex


	## I2: the walks queued since the last look, added to what each army has spent this season.
	func _walked(game: Game) -> void:
		if game.events.size() < _events:
			_events = 0
		for k: int in range(_events, game.events.size()):
			var e := game.events[k]
			if str(e.get("kind", "")) != "unit_moved" or str(e.get("why", "")) != "march":
				continue
			var id := int(e.get("army", 0))
			var tag := StringName(str(e.get("tag", "")))
			var had := int(_points.get(id, 0))
			var fresh := had > 0 and had == int(_full.get(id, 0))
			var bits: PackedByteArray = _explored.get(tag, PackedByteArray())
			_spent[id] = int(_spent.get(id, 0)) + _cost(game, e["path"] as Array, had, fresh, bits)
			var allowed := int(_allowance.get(id, 0))
			if int(_spent[id]) > allowed:
				_add("spent: army %d of %s walked %d move points this season, it had %d" % [id, tag, int(_spent[id]), allowed])
		_events = game.events.size()


	## What a walk along `path` (its start first) costs an army that had `had` points: each step's StepCosts in the season's
	## rules. The first step of a fresh army that wades, costs more than it had or enters unmapped land takes the points it had
	## (a fog step: GameDefs.fog_step_cost of them).
	func _cost(game: Game, path: Array, had: int, fresh: bool, bits: PackedByteArray) -> int:
		var steps := StepCosts.of(game.map, game.defs)
		var winter := Movement.winter_now(game)
		var total := 0
		for k: int in range(1, path.size()):
			var from := game.map.index_of(path[k - 1] as Vector2i)
			var to := game.map.index_of(path[k] as Vector2i)
			var d := Movement.direction(game.map, from, to)
			var c: int = steps.cost(from, d, winter) if d >= 0 else StepCosts.BLOCKED
			if k == 1 and fresh and FogStep.is_fog(bits, to):
				c = had - FogStep.after(game.defs.fog_step_cost, had)
			elif k == 1 and fresh and c != StepCosts.BLOCKED and (c == StepCosts.WADE or c > had):
				c = had
			total += c
		return total


	## I3: no army has more points than at the last look.
	func _grown(game: Game, where: StringName) -> void:
		for a: Army in game.armies:
			if _points.has(a.id) and a.points > int(_points[a.id]):
				_add("grown: army %d of %s went from %d to %d move points in %s, not in ready_units" % [a.id, a.tag,
					int(_points[a.id]), a.points, "an act" if where == ACT else str(where)])


	## I8: a standing march that had no points before the movement phase stands where it stood.
	func _stood(game: Game) -> void:
		for id: int in _standing:
			var a := Armies.by_id(game, id)
			if a != null and a.hex != _standing[id]:
				_add("stood: army %d of %s, a standing march with no points, moved from %s to %s in the movement phase" % [id,
					a.tag, str(_standing[id]), str(a.hex)])


	## Tests only (`soak --plant=moves`): one army that walked this season and has a march left gets its full points back before
	## the movement phase, where its next leg takes it past what it had; `grown` names the points and `spent` the walk. Clears
	## Invariants.planted when it fires; a season with no such army leaves it armed.
	func _plant(game: Game) -> void:
		var steps := StepCosts.of(game.map, game.defs)
		for a: Army in game.armies:
			var full := Allowance.full(game, a)
			var spent := int(_spent.get(a.id, 0))
			if spent <= 0 or a.points >= full or a.mustering(game.turn) \
					or (a.order != Army.ORDER_MARCH and a.order != Army.ORDER_STORM):
				continue
			var leg := MarchLeg.leg(game, steps, a, Movement.winter_now(game), full, false)
			var path: Array = [a.hex]
			for i: int in leg.walked:
				var hex := game.map.hex_of(i)
				if Battles.at(game, hex) != null or not Armies.at(game, hex).is_empty() \
						or FairWarning.enemy_on(game, a.tag, hex) != &"":
					break  # a step the phase may not take
				path.append(hex)
			if spent + _cost(game, path, full, true, FogStep.mapped(game, a.tag)) <= int(_allowance.get(a.id, 0)):
				continue
			Armies.set_points(game, a, full)
			Invariants.planted = ""
			return


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
	for r: BattleRecord in game.battle_records:
		if r.turn != ended:
			continue
		var sides: Array[StringName] = [r.attacker, r.defender]
		var returned := r.returned_by_side()  # by the fight's fighters: a company gone since counts too
		for side: int in 2:
			var lost := int(r.end["killed"][side]) + int(r.end["wounded_total"][side]) - returned[side]
			out[sides[side]] = int(out.get(sides[side], 0)) + lost
	return out


# --- the discovery: the explored set only grows, every controlled hex is explored ---------------------------------------


## R4 (spec 3.1, a soak invariant): a country's explored set after a season is a superset of its set before it.
static func _explored_grows(game: Game, before_state: Dictionary, out: PackedStringArray) -> void:
	var was: Dictionary = before_state["explored"]
	for c: Country in game.countries:
		if not was.has(c.tag):
			continue
		var old: PackedByteArray = was[c.tag]
		if old.is_empty():
			continue
		if c.explored.size() != old.size():
			out.append("explored: %s has %d bytes of explored, was %d" % [c.tag, c.explored.size(), old.size()])
			continue
		var lost := _lost_bits(old, c.explored)
		if not lost.is_empty():
			out.append("explored: %s lost %d explored hex(es), first %s" % [c.tag, lost.size(), str(game.map.hex_of(lost[0]))])


## The hex indices set in `old` and clear in `now`.
static func _lost_bits(old: PackedByteArray, now: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k: int in old.size():
		var gone: int = old[k] & ~now[k]
		for b: int in 8:
			if ((gone >> b) & 1) == 1:
				out.append(k * 8 + b)
	return out


## Spec 7 (a soak invariant): every land hex is explored by its controller, the occupier where one stands, else the owner.
static func _controlled(game: Game, out: PackedStringArray) -> void:
	var by_id := {}
	for c: Country in game.countries:
		by_id[c.id] = c
	var state := game.state
	var missed := PackedInt32Array()
	var holder := ""
	for i: int in game.map.hex_count():
		if game.map.land[i] != 1:
			continue
		var ctl := int(state.owner[i])
		if i < state.occupier.size() and state.occupier[i] != 0:
			ctl = int(state.occupier[i])
		if ctl == 0 or not by_id.has(ctl):
			continue
		var held: Country = by_id[ctl]
		if not SightCache.bit_is(held.explored, i):
			if missed.is_empty():
				holder = str(held.tag)
			missed.append(i)
	if not missed.is_empty():
		out.append("controlled: %d controlled hex(es) not explored by their controller, first %s held by %s" % [missed.size(),
			str(game.map.hex_of(missed[0])), holder])


## Tests only (`soak --plant=fog`): clears one explored hex that the country's sight does not reach, before the check reads
## the game, so `explored` must name it. Clears `planted` after it fires; a game with no such hex is left as it is.
static func _plant_fog(game: Game) -> void:
	var n := game.map.hex_count()
	for c: Country in game.countries:
		if c.explored.size() != (n + 7) >> 3:
			continue
		for i: int in n:
			if SightCache.bit_is(c.explored, i) and not Sight.sees(game, c.tag, game.map.hex_of(i)):
				c.explored[i >> 3] = c.explored[i >> 3] & ~(1 << (i & 7))
				planted = ""
				return


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
