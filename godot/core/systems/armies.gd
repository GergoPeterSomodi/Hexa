## The armies' door (docs/architecture/m6-build-spec.md 5.0 R2, 5.2, 5.3): the only writer of game.armies, next_army_id,
## next_unit_id and of every Army and Unit field. Military, Movement and Supply call its create, add_*, lose_men, add_men,
## remove*, move_units, set_* and clear_moved; nothing else assigns to an army. Ids start at 1, grow by one and are never
## reused; game.armies and each Army.units stay sorted by id (append on create and add, erase on remove, sort on move).
## by_id is a binary search. The door emits unit_lost only (from lose_men); the callers emit the rest. Integer maths; no
## luck; no engine calls.
class_name Armies
extends RefCounted

const OWNS: Array[String] = ["armies", "next_army_id", "next_unit_id"]
const SCHEMA := "hexa-godot/armies/1"
## The problem a refused body reports (Snapshot's word for an unreadable body).
const PROBLEM_BODY := "body"
const INT32_MAX := 2147483647


# --- reads -----------------------------------------------------------------------------------------------------------


## The army with this id, or null. A binary search on game.armies, which is sorted by id.
static func by_id(game: Game, id: int) -> Army:
	var at_index := _index_of(game, id)
	return game.armies[at_index] if at_index >= 0 else null


## The armies of one country, in id order.
static func of_country(game: Game, tag: StringName) -> Array[Army]:
	var out: Array[Army] = []
	for a: Army in game.armies:
		if a.tag == tag:
			out.append(a)
	return out


## Every army (any country) standing on `hex`, in id order.
static func at(game: Game, hex: Vector2i) -> Array[Army]:
	var out: Array[Army] = []
	for a: Army in game.armies:
		if a.hex == hex:
			out.append(a)
	return out


## True when an army of a country other than `tag` stands on `hex`. Outside a battle no two countries' armies may share a hex
## (the armies invariant), so every placement that is not a battle's walk asks this first.
static func held_by_other(game: Game, tag: StringName, hex: Vector2i) -> bool:
	for a: Army in at(game, hex):
		if a.tag != tag:
			return true
	return false


## The companies of `tag` on `hex`, not counting the armies whose ids are in `leaving` (the ones that march away).
static func units_at(game: Game, tag: StringName, hex: Vector2i, leaving: PackedInt32Array = PackedInt32Array()) -> int:
	var n := 0
	for a: Army in game.armies:
		if a.tag == tag and a.hex == hex and not leaving.has(a.id):
			n += a.units.size()
	return n


## The men of all the armies of `tag`.
static func men_of_country(game: Game, tag: StringName) -> int:
	var total := 0
	for a: Army in game.armies:
		if a.tag == tag:
			total += a.men()
	return total


# --- writes: units and armies ----------------------------------------------------------------------------------------


## A new army of `tag` on `hex` with no units and no order; its id is the next one. Returns it.
static func create(game: Game, tag: StringName, hex: Vector2i, name: String) -> Army:
	var a := Army.new()
	a.id = game.next_army_id
	game.next_army_id += 1
	a.tag = tag
	a.name = name
	a.hex = hex
	a.created_turn = game.turn
	game.armies.append(a)
	return a


## Adds `count` companies of kind `kind` (their men at full strength) to `army`. Each gets the next unit id and the same
## raising facts: its home, its raising turn, the ducats and the goods per unit. Returns the new unit ids (empty for an
## unknown kind or a count under 1).
static func add_units(game: Game, army: Army, kind: int, count: int, raised_turn: int, home: Vector2i, paid: int,
		paid_goods: Dictionary) -> PackedInt32Array:
	var ids := PackedInt32Array()
	var ud := game.defs.unit_def(kind) if game.defs != null else null
	if ud == null or count < 1:
		return ids
	var goods := {}
	for key: Variant in paid_goods:
		goods[String(key)] = int(paid_goods[key])
	for _n: int in count:
		var u := Unit.new()
		u.id = game.next_unit_id
		game.next_unit_id += 1
		u.kind = kind
		u.men = ud.men
		u.home = home
		u.raised_turn = raised_turn
		u.paid = paid
		u.paid_goods = goods.duplicate()
		army.units.append(u)
		ids.append(u.id)
	return ids


## Takes `amount` men from the army, shared by its companies in proportion to their men (A6): each loses
## floor(amount x its men / the army's men); the remainder goes one man each to the companies in id order, skipping
## the empty ones. A company that reaches 0 is removed with `unit_lost`; an army with no company is removed. Returns the
## men lost (`amount` is cut to the army's men).
static func lose_men(game: Game, army: Army, amount: int, why: StringName) -> int:
	var total := army.men()
	var lost := clampi(amount, 0, total)
	if lost == 0:
		return 0
	var taken := PackedInt32Array()
	var rest := lost
	for u: Unit in army.units:
		var share := Economy.floor_div(lost * u.men, total)
		taken.append(share)
		rest -= share
	while rest > 0:
		for k: int in army.units.size():
			if rest > 0 and army.units[k].men - taken[k] > 0:
				taken[k] += 1
				rest -= 1
	var gone: Array[Unit] = []
	for k: int in army.units.size():
		var u := army.units[k]
		u.men -= taken[k]
		if u.men == 0:
			gone.append(u)
	for u: Unit in gone:
		army.units.erase(u)
		game.emit({"kind": "unit_lost", "tag": army.tag, "army": army.id, "unit": u.id, "kind_id": u.kind,
			"hex": army.hex, "why": why, "army_left": army.units.size(), "name": army.name})
	if army.units.is_empty():
		remove(game, army)
	return lost


## Adds up to `amount` men to one company, never past its full strength; returns the men added.
static func add_men(game: Game, army: Army, unit_id: int, amount: int) -> int:
	var u := army.unit(unit_id)
	if u == null or amount < 1 or game.defs == null:
		return 0
	var ud := game.defs.unit_def(u.kind)
	if ud == null:
		return 0
	var added := mini(amount, ud.men - u.men)
	if added <= 0:
		return 0
	u.men += added
	return added


## Removes the companies with these ids from `army` (the ones it does not have are skipped); returns the removed units
## in id order. The caller removes an army left empty.
static func remove_units(_game: Game, army: Army, ids: PackedInt32Array) -> Array[Unit]:
	var out: Array[Unit] = []
	for id: int in ids:
		var k := _unit_index(army, id)
		if k >= 0:
			out.append(army.units[k])
			army.units.remove_at(k)
	out.sort_custom(func(a: Unit, b: Unit) -> bool: return a.id < b.id)
	return out


## Moves the companies with these ids from one army to another on the same hex; `to_army` keeps its units sorted by id.
static func move_units(game: Game, from_army: Army, to_army: Army, ids: PackedInt32Array) -> void:
	for u: Unit in remove_units(game, from_army, ids):
		to_army.units.append(u)
	to_army.units.sort_custom(func(a: Unit, b: Unit) -> bool: return a.id < b.id)


## Removes the army from game.armies (its units go with it). Its id is never reused.
static func remove(game: Game, army: Army) -> void:
	var at_index := _index_of(game, army.id)
	if at_index >= 0:
		game.armies.remove_at(at_index)


# --- writes: the fields of an army -----------------------------------------------------------------------------------


## The army stands on `hex`; `moved_from` is where it stood before this movement phase (NO_HEX when it did not move).
static func set_hex(_game: Game, army: Army, hex: Vector2i, moved_from: Vector2i) -> void:
	army.hex = hex
	army.moved_from = moved_from


## The order, its goal (NO_HEX for hold and none) and its stored route (copied).
static func set_order(_game: Game, army: Army, order: StringName, goal: Vector2i, route: PackedInt32Array) -> void:
	army.order = order
	army.goal = goal
	army.route = route.duplicate()


## The stored route alone (copied): the next step first, the goal last.
static func set_route(_game: Game, army: Army, route: PackedInt32Array) -> void:
	army.route = route.duplicate()


## Why the army halted (order none, goal kept) and its words.
static func set_halt(_game: Game, army: Army, why: StringName, text: String) -> void:
	army.halt_why = why
	army.halt_text = text


## &"winter" while the army waits at a closed pass, &"" otherwise.
static func set_waiting(_game: Game, army: Army, waiting: StringName) -> void:
	army.waiting = waiting


## The supply state of the last supply phase (0 fed from the stores, 1 fed by the land, 2 hungry) and the men it lost.
static func set_supply(_game: Game, army: Army, state: int, lost: int) -> void:
	army.supply = state
	army.lost_last = lost


## Every army's moved_from becomes NO_HEX: called at the start of the movement phase.
static func clear_moved(game: Game) -> void:
	for a: Army in game.armies:
		a.moved_from = Army.NO_HEX


# --- battles (M7 B8, 4.6, 4.12, 5.3): the morale, the experience, the standing and the ranks ---------------------------


## Takes `amount` men from one company (a battle's losses, or a surrender): the men are cut to the company's men. A company
## at 0 is removed with unit_lost (`why`); an army left with no company is removed. Returns the men lost.
static func lose_unit_men(game: Game, army: Army, unit_id: int, amount: int, why: StringName) -> int:
	var u := army.unit(unit_id)
	if u == null:
		return 0
	var lost := clampi(amount, 0, u.men)
	if lost == 0:
		return 0
	u.men -= lost
	if u.men == 0:
		army.units.remove_at(_unit_index(army, unit_id))
		game.emit({"kind": "unit_lost", "tag": army.tag, "army": army.id, "unit": u.id, "kind_id": u.kind,
			"hex": army.hex, "why": why, "army_left": army.units.size(), "name": army.name})
		if army.units.is_empty():
			remove(game, army)
	return lost


## A company's morale, 0 to Unit.MAX_MORALE (4.6, 4.12).
static func set_morale(_game: Game, army: Army, unit_id: int, morale: int) -> void:
	var u := army.unit(unit_id)
	if u != null:
		u.morale = clampi(morale, 0, Unit.MAX_MORALE)


## Adds experience to one company (0 and up); its rank follows from rank_of.
static func add_xp(_game: Game, army: Army, unit_id: int, xp: int) -> void:
	var u := army.unit(unit_id)
	if u != null:
		u.xp = maxi(0, u.xp + xp)


## The army's standing order (4.7): Army.STANDING_HOLD or Army.STANDING_WITHDRAW.
static func set_standing(_game: Game, army: Army, standing: StringName) -> void:
	army.standing = standing


## The ready_units phase (4.12): every company of an army fed from the stores or the land (supply 0 or 1) gains morale_recovery,
## up to the maximum. Hungry armies (supply 2) recover nothing.
static func recover_morale(game: Game) -> void:
	if game == null or game.defs == null or game.defs.war == null:
		return
	var gain := game.defs.war.morale_recovery
	for a: Army in game.armies:
		if a.supply == 2:
			continue
		for u: Unit in a.units:
			u.morale = mini(Unit.MAX_MORALE, u.morale + gain)


## The men-weighted morale of an army, permille (0 with no man).
static func morale_of(army: Army) -> int:
	var men := army.men()
	if men <= 0:
		return 0
	var weighted := 0
	for u: Unit in army.units:
		weighted += u.men * u.morale
	return Economy.floor_div(weighted, men)


## The rank of a company by its experience: the highest k with xp at least WarDef.rank_xp[k] (0 Recruit, 1 Veteran, 2 Elite).
static func rank_of(game: Game, unit: Unit) -> int:
	var war: WarDef = game.defs.war if game != null and game.defs != null else null
	if war == null or unit == null:
		return 0
	var rank := 0
	for k: int in mini(war.rank_xp.size(), WarDef.RANK_COUNT):
		if unit.xp >= war.rank_xp[k]:
			rank = k
	return rank


# --- save and digest -------------------------------------------------------------------------------------------------


## {schema, next_army_id, next_unit_id, list: [Army.to_dict] in id order} (5.2, 5.0 R11).
static func to_dict(game: Game) -> Dictionary:
	var list: Array = []
	for a: Army in game.armies:
		list.append(a.to_dict())
	return {"schema": SCHEMA, "next_army_id": game.next_army_id, "next_unit_id": game.next_unit_id, "list": list}


## Fills game.armies and the counters from a saved body, or refuses with PROBLEM_BODY and changes nothing. It refuses a
## wrong schema, a duplicate or unsorted army id, an id at or above its counter, a unit id twice or at or above its
## counter, a tag that is no country of the game, a hex off the map or at sea, a company whose kind is no UnitDef or whose
## men are outside 1 to its full strength, an empty army, a route index off the map, a march whose goal is off the map,
## and a coordinate outside the 32-bit range.
static func from_dict(d: Dictionary, game: Game) -> String:
	if game == null or game.map == null or game.defs == null:
		return PROBLEM_BODY
	if str(d.get("schema", "")) != SCHEMA:
		return PROBLEM_BODY
	var next_army: Variant = Unit.whole(d.get("next_army_id", null))
	var next_unit: Variant = Unit.whole(d.get("next_unit_id", null))
	var raw: Variant = d.get("list", null)
	if next_army == null or next_unit == null or int(next_army) < 1 or int(next_unit) < 1 or not (raw is Array):
		return PROBLEM_BODY
	var list: Array[Army] = []
	var unit_ids: Dictionary = {}
	var last_id := 0
	for item: Variant in raw as Array:
		if not (item is Dictionary) or not _raw_ok(item as Dictionary, game):
			return PROBLEM_BODY
		var a := Army.from_dict(item as Dictionary)
		if a == null or a.id <= last_id or a.id >= int(next_army):
			return PROBLEM_BODY
		last_id = a.id
		if not _army_ok(game, a, unit_ids, int(next_unit)):
			return PROBLEM_BODY
		list.append(a)
	game.armies = list
	game.next_army_id = int(next_army)
	game.next_unit_id = int(next_unit)
	return ""


## "next_army|next_unit" then each army's digest text in id order, one per line.
static func digest(game: Game) -> String:
	var lines := PackedStringArray()
	for a: Army in game.armies:
		lines.append(a.digest_text())
	return "%d|%d\n%s" % [game.next_army_id, game.next_unit_id, "\n".join(lines)]


# --- helpers ---------------------------------------------------------------------------------------------------------


## The position of the army with this id in game.armies, or -1.
static func _index_of(game: Game, id: int) -> int:
	var lo := 0
	var hi := game.armies.size() - 1
	while lo <= hi:
		var mid := (lo + hi) >> 1
		var found := game.armies[mid].id
		if found == id:
			return mid
		if found < id:
			lo = mid + 1
		else:
			hi = mid - 1
	return -1


## The position of the unit with this id in the army, or -1.
static func _unit_index(army: Army, id: int) -> int:
	for k: int in army.units.size():
		if army.units[k].id == id:
			return k
	return -1


## The raw numbers of a saved army are checked before Army.from_dict narrows them to 32 bits: every coordinate of a hex,
## every route index (0 to the hex count less one) and every unit's home.
static func _raw_ok(item: Dictionary, game: Game) -> bool:
	for key: String in ["hex", "goal", "moved_from"]:
		if not _raw_cell_ok(item.get(key, null)):
			return false
	var route: Variant = item.get("route", null)
	if route is Array:
		for value: Variant in route as Array:
			var n: Variant = Unit.whole(value)
			if n == null or int(n) < 0 or int(n) >= game.map.hex_count():
				return false
	var units: Variant = item.get("units", null)
	if units is Array:
		for raw_unit: Variant in units as Array:
			if raw_unit is Dictionary and not _raw_cell_ok((raw_unit as Dictionary).get("home", null)):
				return false
	return true


static func _raw_cell_ok(value: Variant) -> bool:
	if not (value is Array):
		return true  # Army.from_dict refuses the shape itself
	if (value as Array).size() != 2:
		return true
	for part: Variant in value as Array:
		var n: Variant = Unit.whole(part)
		if n == null or int(n) < -INT32_MAX or int(n) > INT32_MAX:
			return false
	return true


## The rules of one saved army against the game: its tag, its hex on the map and on land, its companies (ids unused and
## below the counter, kinds known, men in range), a route on the map, a march's goal on the map.
static func _army_ok(game: Game, a: Army, unit_ids: Dictionary, next_unit: int) -> bool:
	if a.id < 1 or a.tag == &"" or Countries.by_tag(game, a.tag) == null or a.units.is_empty():
		return false
	if not game.map.is_land(a.hex):
		return false
	for u: Unit in a.units:
		var ud := game.defs.unit_def(u.kind)
		if u.id < 1 or u.id >= next_unit or unit_ids.has(u.id) or ud == null:
			return false
		if u.men < 1 or u.men > ud.men:
			return false
		unit_ids[u.id] = true
	for index: int in a.route:
		if index < 0 or index >= game.map.hex_count():
			return false
	if (a.order == Army.ORDER_MARCH or a.order == Army.ORDER_STORM) and game.map.index_of(a.goal) < 0:
		return false
	return true
