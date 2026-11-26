## Military (docs/architecture/m6-build-spec.md 4.5, 4.6, 4.9, 5.3, 5.0 A3 to A8, A10, A15): raising companies in towns and
## villages, disbanding, splitting and merging armies, the room of a hex (`can_stand`), the refill of the ready_units phase,
## the upkeep, the names and the options a raise menu shows. Every change of an army goes through Armies, every ducat
## through Treasury.move (reason raise, refund), every good through Stores.move, every man through People (levy, give_back).
## Each check returns {ok, reason} with the first refusal as the verdict; each action checks again, then acts.
class_name Military
extends RefCounted

const OWNS: Array[String] = []
const NO_HEX := Vector2i(-1, -1)
## Army ordinals from the second army of one name on: "Second Army of Turin" ... "Tenth", then "11th" ... (A8).
const ORDINALS: Array[String] = ["Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Ninth", "Tenth"]
## How far a place is searched for a name, in rings (Words.place's NEAR).
const NEAR := 2
const SETTLEMENTS := Economy.SETTLEMENTS


# --- definitions and numbers -----------------------------------------------------------------------------------------


## The kind's UnitDef, or null for an unknown kind or a game without definitions.
static func unit_def(game: Game, kind: int) -> UnitDef:
	return game.defs.unit_def(kind) if game != null and game.defs != null else null


## Companies a hex holds from one country (GameDefs.stack_limit, D12; M7 adds generals).
static func stack_limit(game: Game, _tag: StringName) -> int:
	return game.defs.stack_limit if game != null and game.defs != null else 0


## Companies a settlement may raise on its hex in one season: FamilyDef.raise_cap of its level; 0 on any other hex.
static func raise_cap(game: Game, hex: Vector2i) -> int:
	if game == null or game.map == null or game.state == null or game.defs == null:
		return 0
	var i := game.map.index_of(hex)
	if i < 0 or i >= game.state.main_use.size() or int(game.state.main_use[i]) != SETTLEMENTS:
		return 0
	var fam := game.defs.family(SETTLEMENTS)
	var level := int(game.state.level[i])
	if fam == null or level < 0 or level >= fam.raise_cap.size():
		return 0
	return fam.raise_cap[level]


## The Raise tab is offered on a settlement of the player's own land, in a game with countries (M6, 6.8; L19). Moved here
## from the old raise list (TW1) so that TileView may read it; the raise list calls this.
static func raise_offered(game: Game, tag: StringName, hex: Vector2i) -> bool:
	if game == null or game.map == null or game.state == null or tag == &"" or not game.has_countries():
		return false
	if not game.map.has(hex) or not game.map.is_land(hex):
		return false
	if Territory.owner_tag(game, hex) != tag:
		return false
	return int(game.state.main_use[game.map.index_of(hex)]) == SETTLEMENTS


## Companies of `tag` raised on `hex` this season (their home is the hex and their raising turn is now).
static func raised_here(game: Game, tag: StringName, hex: Vector2i) -> int:
	var n := 0
	for a: Army in Armies.of_country(game, tag):
		for u: Unit in a.units:
			if u.home == hex and u.raised_turn == game.turn:
				n += 1
	return n


## The men a levy can take on `hex` and on its ring held by `tag` (direction order 0 to 5). A hex counts only when People.levy
## would take from it (owned by tag and not occupied: an occupied hex refuses every levy, so its men are not at hand). Counting
## what the levy refuses would let a raise mint the men it could not take (K24b: the men identity).
static func men_at_hand(game: Game, tag: StringName, hex: Vector2i) -> int:
	var total := _levyable(game, tag, hex)
	for d: int in 6:
		var beside := ImproveRules.neighbour(hex, d)
		if Territory.owner_tag(game, beside) == tag:
			total += _levyable(game, tag, beside)
	return total


## The men People.levy takes from `spot` for `tag`: its people at the levy permille, 0 on an occupied hex.
static func _levyable(game: Game, tag: StringName, spot: Vector2i) -> int:
	if Occupation.is_occupied(game, spot):
		return 0
	return People.available(game, spot)


## "" when `adding` more companies of `tag` fit on `hex` (leaving: armies whose ids march away and do not count), else
## the words of 4.7 row 7: another country's army on the hex, or the stack limit.
static func can_stand(game: Game, tag: StringName, hex: Vector2i, adding: int,
		leaving: PackedInt32Array = PackedInt32Array()) -> String:
	for a: Army in Armies.at(game, hex):
		if a.tag != tag and not Wars.at_war(game, tag, a.tag):
			return "another country's army stands at %s" % hex_text(game, hex)
	var present := Armies.units_at(game, tag, hex, leaving)
	var limit := stack_limit(game, tag)
	if present + adding > limit:
		return "no room at %s: %d of %d companies" % [hex_text(game, hex), present + adding, limit]
	return ""


## {ducats, goods: {good key: loads}} of `count` companies of a kind (A4: the loads multiplied by the count).
static func cost_of(game: Game, kind: int, count: int) -> Dictionary:
	var ud := unit_def(game, kind)
	var goods := {}
	if ud != null:
		for key: Variant in ud.cost_goods:
			goods[String(key)] = int(ud.cost_goods[key]) * count
		return {"ducats": ud.cost * count, "goods": goods}
	return {"ducats": 0, "goods": goods}


## Ducats a season for one army: the sum over its companies of ceil(upkeep x men / full) (4.9, D29).
static func upkeep_of(game: Game, army: Army) -> int:
	var total := 0
	for u: Unit in army.units:
		var ud := unit_def(game, u.kind)
		if ud != null and ud.men > 0:
			total += Economy.floor_div(ud.upkeep * u.men + ud.men - 1, ud.men)
	return total


## The upkeep of every army of `tag`: the income phase's upkeep_army line.
static func upkeep_country(game: Game, tag: StringName) -> int:
	var total := 0
	for a: Army in Armies.of_country(game, tag):
		total += upkeep_of(game, a)
	return total


## One row per kind in id order for a raise menu: {kind, name, men, mp, verdict (raise_check of one company), cost_text
## ("25 · 1 iron" ; goods joined by ", ")}.
static func raise_options(game: Game, tag: StringName, hex: Vector2i) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if game == null or game.defs == null:
		return rows
	for ud: UnitDef in game.defs.units:
		if ud == null:
			continue
		var cost := cost_of(game, ud.id, 1)
		var parts: Array[String] = []
		for gid: int in game.defs.goods.size():
			var g := game.defs.good(gid)
			var key := String(g.key)
			if (cost["goods"] as Dictionary).has(key):
				parts.append("%d %s" % [int(cost["goods"][key]), g.name.to_lower()])
		var text := str(cost["ducats"])
		if not parts.is_empty():
			text += " · " + ", ".join(parts)
		rows.append({
			"kind": ud.id, "name": ud.name, "men": ud.men, "mp": ud.mp,
			"verdict": raise_check(game, {"hex": hex, "kind": ud.id, "count": 1, "tag": tag}), "cost_text": text,
		})
	return rows


# --- names -----------------------------------------------------------------------------------------------------------


## The place of a hex as the player reads it: "Turin (5, 9)" when the hex holds a named place (Improve.place_of), else
## "(3, 8)".
static func hex_text(game: Game, hex: Vector2i) -> String:
	var coords := "(%d, %d)" % [hex.x, hex.y]
	if game == null or game.map == null:
		return coords
	var place := Improve.place_of(game.map, hex)
	var place_name := str(place.get("name", ""))
	return "%s %s" % [place_name, coords] if place_name != "" else coords


## The name of a new army of `tag` on `hex` (D37, A8): "Army of <the place of its hex, else the nearest named place within
## two rings, else its country>"; a name in use by a living army of the country takes "Second" ... "Tenth", then "11th".
static func army_name(game: Game, tag: StringName, hex: Vector2i) -> String:
	var place_name := _place_near(game, hex)
	if place_name == "":
		var cdef := Countries.def_of(game, tag)
		place_name = cdef.name if cdef != null and not cdef.name.is_empty() else String(tag)
	var taken := {}
	for a: Army in Armies.of_country(game, tag):
		taken[a.name] = true
	var base := "Army of %s" % place_name
	var k := 1
	while taken.has(_numbered(base, k)):
		k += 1
	return _numbered(base, k)


## "Army of X" for k 1, "Second Army of X" ... "Tenth Army of X", then "11th Army of X" (English ordinal endings).
static func _numbered(base: String, k: int) -> String:
	if k <= 1:
		return base
	if k - 2 < ORDINALS.size():
		return "%s %s" % [ORDINALS[k - 2], base]
	var suffix := "th"
	if k % 100 not in [11, 12, 13]:
		match k % 10:
			1:
				suffix = "st"
			2:
				suffix = "nd"
			3:
				suffix = "rd"
	return "%d%s %s" % [k, suffix, base]


## The name of the place on or nearest to `hex` within NEAR rings, the way Words.place picks it: the first named place of
## each hex (in map order), the lowest place order among the hexes of a ring; "" when none.
static func _place_near(game: Game, hex: Vector2i) -> String:
	if game == null or game.map == null:
		return ""
	var names := {}
	for order: int in game.map.places.size():
		var entry: Dictionary = game.map.places[order]
		var place_name := str(entry.get("name", ""))
		var at: Variant = entry.get("hex", null)
		if place_name != "" and typeof(at) == TYPE_VECTOR2I and not names.has(at):
			names[at] = [place_name, order]
	var seen: Dictionary = {hex: true}
	var ring: Array[Vector2i] = [hex]
	for _distance: int in NEAR + 1:
		var best_name := ""
		var best_order := 1 << 30
		for at: Vector2i in ring:
			var held: Variant = names.get(at)
			if held != null and int((held as Array)[1]) < best_order:
				best_order = int((held as Array)[1])
				best_name = str((held as Array)[0])
		if best_name != "":
			return best_name
		var next: Array[Vector2i] = []
		for at: Vector2i in ring:
			for d: int in 6:
				var beside := ImproveRules.neighbour(at, d)
				if not seen.has(beside):
					seen[beside] = true
					next.append(beside)
		ring = next
	return ""


# --- raising ---------------------------------------------------------------------------------------------------------


## Whether `tag` may raise `count` companies of `kind` on `hex` now (4.5): the first refusal in the table's order.
static func raise_check(game: Game, args: Dictionary) -> Dictionary:
	if not (args.get("hex") is Vector2i):
		return _refusal("no hex given")
	var kind: Variant = args.get("kind", null)
	if typeof(kind) != TYPE_INT:
		return _refusal("no kind given")
	var hex: Vector2i = args["hex"]
	var count := int(args.get("count", 1))
	var tag := StringName(str(args.get("tag", "")))
	if count < 1:
		return _refusal("count the companies: 1 or more")
	if game == null or not game.has_countries():
		return _refusal("the sandbox has no armies")
	var home := Territory.at_home_check(game, tag, hex)
	if not bool(home["ok"]):
		return _refusal(str(home["reason"]))
	if Occupation.is_occupied(game, hex):
		return _refusal("held by the %s: no men can be raised here" % Occupation.occupier_long_name(game, hex))
	var i := game.map.index_of(hex)
	if i < 0 or int(game.state.main_use[i]) != SETTLEMENTS:
		return _refusal("companies are raised in towns and villages: no settlement here")
	var ud := unit_def(game, int(kind))
	if ud == null:
		return _refusal("no such kind of company")
	var level := int(game.state.level[i])
	if level < ud.min_level:
		return _refusal("%s are raised in a %s or larger" % [ud.name, FamilyIds.LEVEL_WORDS["settlements"][ud.min_level]])
	var cap := raise_cap(game, hex)
	var raised := raised_here(game, tag, hex)
	if raised + count > cap:
		var left := cap - raised
		if left <= 0:
			return _refusal("%s has raised its %d companies this season" % [hex_text(game, hex), cap])
		return _refusal("%s can raise %s this season" % [hex_text(game, hex),
			"1 more company" if left == 1 else "%d more companies" % left])
	if Armies.held_by_other(game, tag, hex):
		return _refusal("another country's army stands at %s" % hex_text(game, hex))
	var stand := can_stand(game, tag, hex, count)
	if stand != "":
		return _refusal(stand)
	var need := count * ud.men
	var have := men_at_hand(game, tag, hex)
	if have < need:
		return _refusal("only %d men can be raised here this season: %d are needed" % [have, need])
	var cost := cost_of(game, ud.id, count)
	var c := Countries.by_tag(game, tag)
	if not Treasury.can_pay(game, tag, int(cost["ducats"])):
		return _refusal("not enough ducats: %d needed, %d in the treasury" % [int(cost["ducats"]), c.treasury])
	var short := Stores.short_of(game, tag, cost["goods"])
	if short != "":
		return _refusal(short)
	var signed := {}
	for key: Variant in cost["goods"]:
		signed[key] = -int(cost["goods"][key])
	var books := _books_room(game, tag, hex, -int(cost["ducats"]), signed, &"raise")
	if books != "":
		return _refusal(books)
	return {"ok": true, "reason": ""}


## Raises the companies (after checking again): the ducats and the goods are paid, the men levied (the hex, then its ring
## in direction order), and the companies join the first army of `tag` on the hex that is fresh and does not march (R15),
## else a new army; the army's points are its full after the companies are in.
static func raise(game: Game, args: Dictionary) -> Dictionary:
	var verdict := raise_check(game, args)
	if not bool(verdict["ok"]):
		return verdict
	var hex: Vector2i = args["hex"]
	var kind := int(args["kind"])
	var count := int(args.get("count", 1))
	var tag := StringName(str(args.get("tag", "")))
	var ud := unit_def(game, kind)
	var cost := cost_of(game, kind, count)
	var goods: Dictionary = cost["goods"]
	var per_unit: Dictionary = cost_of(game, kind, 1)["goods"]
	for gid: int in game.defs.goods.size():
		var key := String(game.defs.good(gid).key)
		if goods.has(key):
			var moved := Stores.move(game, tag, gid, -int(goods[key]), &"raise")
			assert(moved, "the stores refused a raise the check passed")
	var paid := Treasury.move(game, tag, -int(cost["ducats"]), &"raise", hex, count)
	assert(paid, "the treasury refused a raise the check passed")
	_levy_ring(game, tag, hex, count * ud.men)
	var army: Army = null
	for a: Army in Armies.at(game, hex):
		if a.tag == tag and a.order != Army.ORDER_MARCH and Allowance.fresh(game, a):
			army = a
			break
	if army == null:
		army = Armies.create(game, tag, hex, army_name(game, tag, hex))
	var ids := Armies.add_units(game, army, kind, count, game.turn, hex, ud.cost, per_unit)
	Armies.set_points(game, army, Allowance.full(game, army))
	Sight.refresh(game)  # the army part of the sight (5.0 R4): a live game sees what a loaded one does
	game.emit({"kind": "army_raised", "tag": tag, "hex": hex, "army": army.id, "units": Array(ids), "kind_id": kind,
		"count": count, "men": count * ud.men, "ducats": int(cost["ducats"]), "goods": goods, "name": army.name})
	return {"ok": true, "reason": "", "army": army.id}


## Takes `men` for a raise from the hex, then from its ring held by `tag` in direction order (People.levy each).
static func _levy_ring(game: Game, tag: StringName, hex: Vector2i, men: int) -> void:
	var left := men
	var spots: Array[Vector2i] = [hex]
	for d: int in 6:
		spots.append(ImproveRules.neighbour(hex, d))
	for spot: Vector2i in spots:
		if left <= 0:
			break
		if spot != hex and Territory.owner_tag(game, spot) != tag:
			continue
		var take := mini(left, People.available(game, spot))
		if take > 0:
			left -= People.levy(game, tag, spot, take)
	assert(left == 0, "the raise's men were not all levied: the check counted men that cannot be taken")


# --- the scenario's starting armies ---------------------------------------------------------------------------------------


## The scenario's start_armies through the Armies door (M8 5.3, D30): each entry's companies at full men, raised_turn 0, paid
## nothing, their men levied from their hex and its ring (People.levy, the flow raised); they join an army of the country on
## the hex that does not march, else a new one. No event. Called by Game.new_scenario once the people are set up; nothing for 1480.
static func setup_start_armies(game: Game, scenario: ScenarioDef) -> void:
	if game == null or scenario == null or game.defs == null or game.map == null:
		return
	for entry: Dictionary in scenario.start_armies:
		var tag := StringName(str(entry.get("tag", "")))
		var at: Variant = entry.get("hex", null)
		var ud := unit_def(game, int(entry.get("kind", -1)))
		var count := int(entry.get("count", 0))
		if typeof(at) != TYPE_VECTOR2I or ud == null or count < 1 or Countries.by_tag(game, tag) == null:
			continue
		var hex: Vector2i = at
		_levy_ring(game, tag, hex, count * ud.men)
		var army: Army = null
		for a: Army in Armies.at(game, hex):
			if a.tag == tag and a.order != Army.ORDER_MARCH and Allowance.fresh(game, a):
				army = a
				break
		if army == null:
			army = Armies.create(game, tag, hex, army_name(game, tag, hex))
		Armies.add_units(game, army, ud.id, count, 0, hex, 0, {})
		Armies.set_points(game, army, Allowance.full(game, army))


# --- disbanding ------------------------------------------------------------------------------------------------------


## Whether `tag` may disband companies of its army (4.6, A5): one company (args unit: its id), the whole army (unit -1, the
## default), or a set (args units: an array of company ids, one action). A set is checked as a whole: the return plan
## shares one pending count over every company, so the men of all of them must find room, and the refunds must fit the
## books together. A refused set changes nothing.
static func disband_check(game: Game, args: Dictionary) -> Dictionary:
	var why := _missing(game, args)
	if why != "":
		return _refusal(why)
	var army := Armies.by_id(game, int(args["army"]))
	var tag := StringName(str(args.get("tag", "")))
	var ids := _disband_ids(args)
	if army.tag != tag:
		return _refusal("not your army: %s" % _foreign_army_text(game, tag, army))
	if ids.is_empty():
		return _refusal("no companies given")
	for id: int in ids:
		if id != -1 and army.unit(id) == null:
			return _refusal("company %d is not in the %s" % [id, army.name])
	if Territory.owner_tag(game, army.hex) != tag:
		return _refusal("disband only in your own land: (%d, %d) is not yours" % [army.hex.x, army.hex.y])
	var drop := _drop_of(army, ids)
	var plan := _return_plan(game, army, drop)
	if not bool(plan["ok"]):
		return _refusal(str(plan["reason"]))
	var refund := 0
	var back := {}
	for u: Unit in drop:
		if u.raised_turn == game.turn and u.home == army.hex:
			refund += u.paid
			for key: Variant in u.paid_goods:
				back[key] = int(back.get(key, 0)) + int(u.paid_goods[key])
	var books := _books_room(game, tag, army.hex, refund, back, &"refund")
	if books != "":
		return _refusal(books)
	return {"ok": true, "reason": ""}


## Disbands the company or the whole army: a company raised this season on its home, while the army stands there, gives
## its ducats and goods back (refund lines); its men go home (or to the army's hex) by People.give_back.
static func disband(game: Game, args: Dictionary) -> Dictionary:
	var verdict := disband_check(game, args)
	if not bool(verdict["ok"]):
		return verdict
	var army := Armies.by_id(game, int(args["army"]))
	var tag := army.tag
	var drop := _drop_of(army, _disband_ids(args))
	var plan: Dictionary = _return_plan(game, army, drop)
	var refund := 0
	var men := 0
	var ids := PackedInt32Array()
	for u: Unit in drop:
		ids.append(u.id)
		men += u.men
		if u.raised_turn == game.turn and u.home == army.hex:
			refund += u.paid
			var paid := Treasury.move(game, tag, u.paid, &"refund", army.hex)
			assert(paid, "the treasury refused a refund the check passed")
			for gid: int in game.defs.goods.size():
				var key := String(game.defs.good(gid).key)
				if u.paid_goods.has(key):
					var back := Stores.move(game, tag, gid, int(u.paid_goods[key]), &"refund")
					assert(back, "the stores refused a refund the check passed")
	for give: Array in plan["plan"]:
		People.give_back(game, give[0], give[1])
	var hex := army.hex
	var army_id := army.id
	var army_name := army.name
	# the kind when every company dropped is of one kind (the line names it); else the event has none
	var kind_id := drop[0].kind if not drop.is_empty() and drop.all(func(u: Unit) -> bool: return u.kind == drop[0].kind) else -1
	Armies.remove_units(game, army, ids)
	if army.units.is_empty():
		Armies.remove(game, army)
	else:
		Allowance.after_disband(game, army)
	Sight.refresh(game)
	var event := {"kind": "army_disbanded", "tag": tag, "hex": hex, "army": army_id, "units": Array(ids), "men": men,
		"refund": refund, "name": army_name}
	if kind_id >= 0:
		event["kind_id"] = kind_id
	game.emit(event)
	return {"ok": true, "reason": "", "men": men}


## Where the men of the companies go, in id order: each one's home when `tag` holds it and it has room, else the army's
## hex. {ok, plan: [[hex, men], ...], reason} (A5: a refusal when neither can take them, "no room for %d people at %s").
static func _return_plan(game: Game, army: Army, drop: Array[Unit]) -> Dictionary:
	var pending := {}
	var plan: Array = []
	for u: Unit in drop:
		var target := army.hex
		if Territory.owner_tag(game, u.home) == army.tag and _room_for(game, u.home, pending, u.men):
			target = u.home
		elif not _room_for(game, army.hex, pending, u.men):
			return {"ok": false, "reason": "no room for %d people at %s" % [u.men, hex_text(game, army.hex)], "plan": []}
		var index := game.map.index_of(target)
		pending[index] = int(pending.get(index, 0)) + u.men
		plan.append([target, u.men])
	return {"ok": true, "reason": "", "plan": plan}


static func _room_for(game: Game, hex: Vector2i, pending: Dictionary, men: int) -> bool:
	var i := game.map.index_of(hex)
	if i < 0 or i >= game.state.people.size():
		return false
	return game.state.people[i] + int(pending.get(i, 0)) + men <= People.PEOPLE_MAX


## "" when the country's books can take these money and goods moves (the limits of Treasury.move and Stores.move and the
## open lines), else the refusal's words. The check asks it, so an action never meets a refused move half way: `goods` is
## {good key: signed loads}.
static func _books_room(game: Game, tag: StringName, hex: Vector2i, ducats: int, goods: Dictionary, why: StringName) -> String:
	var c := Countries.by_tag(game, tag)
	var word := "spending" if why == &"raise" else "refund"
	if c == null:
		return "no country %s" % String(tag)
	if not _money_fits(c, ducats, why, hex):
		return "the treasury cannot take that %s" % word
	for key: Variant in goods:
		var gid := game.defs.good_id(StringName(str(key)))
		if gid < 0 or not _goods_fit(c, gid, int(goods[key]), why):
			return "the stores cannot take that %s" % word
	return ""


## Whether Treasury.move would take `amount` on the line (why, hex): its limit, the treasury's and the open line's.
static func _money_fits(c: Country, amount: int, why: StringName, hex: Vector2i) -> bool:
	if absi(amount) > Treasury.LIMIT or absi(c.treasury + amount) > Treasury.LIMIT:
		return false
	for line: Dictionary in c.ledger_open:
		if line["why"] == why and line["hex"] == hex:
			return absi(int(line["amount"]) + amount) <= Treasury.LIMIT
	return true


## Whether Stores.move would take `amount` of a good on the flow `why`: the stock's and the flow cell's limits.
static func _goods_fit(c: Country, good: int, amount: int, why: StringName) -> bool:
	var flow := Stores.FLOWS.find(why)
	if good < 0 or good >= c.stock.size() or flow < 0:
		return false
	var slot := flow * c.stock.size() + good
	if slot >= c.flows_open.size():
		return false
	if c.stock[good] + amount < 0 or c.stock[good] + amount > Stores.LIMIT:
		return false
	return absi(c.flows_open[slot] + amount) <= Stores.LIMIT


## The company ids a disband names: args units (an array: one action for the set) or else the single unit (-1 the whole
## army). Duplicates are dropped; an args units that is not an array names none.
static func _disband_ids(args: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	if not args.has("units"):
		out.append(int(args.get("unit", -1)))
		return out
	var raw: Variant = args["units"]
	if typeof(raw) != TYPE_ARRAY and typeof(raw) != TYPE_PACKED_INT32_ARRAY:
		return out
	for id: Variant in raw:
		if not out.has(int(id)):
			out.append(int(id))
	return out


## The companies a disband takes, in unit order: all of them when the ids hold -1, else those the ids name.
static func _drop_of(army: Army, ids: PackedInt32Array) -> Array[Unit]:
	var out: Array[Unit] = []
	for u: Unit in army.units:
		if ids.has(-1) or ids.has(u.id):
			out.append(u)
	return out


# --- splitting and merging -------------------------------------------------------------------------------------------


## Whether `tag` may split the given companies off its army (4.6): one or more, not all of them.
static func split_check(game: Game, args: Dictionary) -> Dictionary:
	var why := _missing(game, args)
	if why != "":
		return _refusal(why)
	var army := Armies.by_id(game, int(args["army"]))
	var tag := StringName(str(args.get("tag", "")))
	if army.tag != tag:
		return _refusal("not your army: %s" % _foreign_army_text(game, tag, army))
	var ids: Variant = args.get("units", PackedInt32Array())
	var unique := {}
	for id: Variant in ids:
		unique[int(id)] = true
	if unique.is_empty():
		return _refusal("no companies given")
	for id: int in unique:
		if army.unit(id) == null:
			return _refusal("company %d is not in the %s" % [id, army.name])
	if unique.size() >= army.units.size():
		return _refusal("a split must leave at least one company behind")
	return {"ok": true, "reason": ""}


## Makes a new army on the same hex from the given companies, on hold (its name by D37); two army_changed events.
static func split_army(game: Game, args: Dictionary) -> Dictionary:
	var verdict := split_check(game, args)
	if not bool(verdict["ok"]):
		return verdict
	var army := Armies.by_id(game, int(args["army"]))
	var tag := army.tag
	var ids := _id_array(args.get("units", PackedInt32Array()))
	var fresh := Armies.create(game, tag, army.hex, army_name(game, tag, army.hex))
	var before := army.points
	Armies.move_units(game, army, fresh, ids)
	Allowance.after_split(game, army, fresh, before)
	Armies.set_order(game, fresh, Army.ORDER_HOLD, NO_HEX, PackedInt32Array())
	Sight.refresh(game)  # a company's sight may have moved to the new army
	_changed(game, army, false)
	_changed(game, fresh, false)
	return {"ok": true, "reason": "", "army": fresh.id}


## Whether `tag` may join `army` into `into` (4.6): two different armies of its own on one hex.
static func merge_check(game: Game, args: Dictionary) -> Dictionary:
	var why := _missing(game, args)
	if why != "":
		return _refusal(why)
	var army := Armies.by_id(game, int(args["army"]))
	var tag := StringName(str(args.get("tag", "")))
	var into := Armies.by_id(game, int(args.get("into", -1)))
	if into == null:
		return _refusal("no army %d" % int(args.get("into", -1)))
	if army.tag != tag or into.tag != tag:
		return _refusal("not your army: %s" % _foreign_army_text(game, tag, army))
	if army.id == into.id:
		return _refusal("an army cannot join itself")
	if army.hex != into.hex:
		return _refusal("the armies stand on different hexes")
	return {"ok": true, "reason": ""}


## Moves every company of `army` into `into` (which keeps its order); `army` is removed. army_changed for both.
static func merge_armies(game: Game, args: Dictionary) -> Dictionary:
	var verdict := merge_check(game, args)
	if not bool(verdict["ok"]):
		return verdict
	var army := Armies.by_id(game, int(args["army"]))
	var into := Armies.by_id(game, int(args["into"]))
	var ids := PackedInt32Array()
	for u: Unit in army.units:
		ids.append(u.id)
	var a_points := army.points
	var into_points := into.points
	Armies.move_units(game, army, into, ids)
	Allowance.after_merge(game, into, a_points, into_points)
	_changed(game, army, true)
	Armies.remove(game, army)
	Sight.refresh(game)
	_changed(game, into, false)
	return {"ok": true, "reason": "", "army": into.id}


# --- refill (ready_units) and the door's checks -----------------------------------------------------------------------


## The ready_units phase (4.9): every army in id order with supply 0 on land its country holds refills each company up to
## its full men, by at most UnitDef.refill, from the people of its hex (People.levy, the flow raised). army_changed once
## per army that gained men.
static func refill(game: Game) -> void:
	if game == null or game.defs == null:
		return
	for a: Army in game.armies:
		if a.supply != 0 or Territory.owner_tag(game, a.hex) != a.tag:
			continue
		var gained := false
		for u: Unit in a.units:
			var ud := unit_def(game, u.kind)
			if ud == null:
				continue
			var want := mini(ud.men - u.men, ud.refill)
			want = mini(want, People.available(game, a.hex))
			if want <= 0:
				continue
			var taken := People.levy(game, a.tag, a.hex, want)
			if taken > 0 and Armies.add_men(game, a, u.id, taken) > 0:
				gained = true
		if gained:
			_changed(game, a, false)


# --- helpers ---------------------------------------------------------------------------------------------------------


## "" when args names an army that exists; else the words "no army given" or "no army <id>".
static func _missing(game: Game, args: Dictionary) -> String:
	var raw: Variant = args.get("army", null)
	if typeof(raw) != TYPE_INT:
		return "no army given"
	if Armies.by_id(game, int(raw)) == null:
		return "no army %d" % int(raw)
	return ""


static func _changed(game: Game, army: Army, gone: bool) -> void:
	game.emit({"kind": "army_changed", "tag": army.tag, "hex": army.hex, "army": army.id, "gone": gone})


static func _id_array(raw: Variant) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id: Variant in raw:
		out.append(int(id))
	return out


static func _country_name(game: Game, tag: StringName) -> String:
	var cdef := Countries.def_of(game, tag)
	if cdef != null and not cdef.name.is_empty():
		return cdef.name
	return String(tag)


## The check of a standing order (4.7: what the army does when it is attacked): {ok, reason}. Changes nothing.
static func standing_check(game: Game, args: Dictionary) -> Dictionary:
	var v := Movement.army_check(game, args)
	if not bool(v.ok):
		return _refusal(str(v.reason))
	var army: Army = v.army
	var standing := str(args.get("standing", ""))
	if standing == "":
		return _refusal("no standing order given")
	if standing != String(Army.STANDING_HOLD) and standing != String(Army.STANDING_WITHDRAW):
		return _refusal("no such standing order: hold or withdraw")
	if String(army.standing) == standing:
		var word := "holds" if standing == String(Army.STANDING_HOLD) else "withdraws"
		return _refusal("%s already %s when attacked" % [army.name, word])
	return {"ok": true, "reason": ""}


## Sets the standing order of an army (Army.STANDING_HOLD or Army.STANDING_WITHDRAW) after checking it again: {ok, reason}.
static func set_standing(game: Game, args: Dictionary) -> Dictionary:
	var v := standing_check(game, args)
	if not bool(v.ok):
		return v
	var army := Movement.army_check(game, args).army as Army
	Armies.set_standing(game, army, StringName(str(args["standing"])))
	_changed(game, army, false)
	return {"ok": true, "reason": ""}


static func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


## The owner of an army of another country, as a refusal words it: its country's name when the actor sees the army's hex
## (R23, R32), else "another country commands it" with no name.
static func _foreign_army_text(game: Game, tag: StringName, a: Army) -> String:
	if Sight.sees(game, tag, a.hex):
		return "the %s commands it" % _country_name(game, a.tag)
	return "another country commands it"
