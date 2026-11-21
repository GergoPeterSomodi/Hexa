## The supply line and the armies' food (docs/architecture/m6-build-spec.md sections 4.8, 4.9, 5.0 R5, R8 (b) and 5.3): the
## depots of a country, its supply field (the cost of its own land from its depots, within supply_reach), the supply phase
## (the armies in supply eat grain, then fish, from the stores; the others forage their hex; unfed men are lost to hunger)
## and the armies' food for the economy. `country_step` is that arithmetic as a pure function: it writes nothing, and the
## phase applies its result through the doors (Stores, People, Armies). Integer maths; no luck; no engine calls.
##
## The fields are derived, not saved. They sit in the view cache (`game.view_cache`, its pinned slots) under keys made of
## the map, the defs' supply numbers and the owner, settlement and level bytes, so a change of land, of a settlement or
## of a level makes them lazy again. A field is built only when a country asks for it, so a country without armies never
## pays. Pure reads of `game.state` are the only input.
class_name Supply
extends RefCounted

@warning_ignore_start("integer_division")

const OWNS: Array[String] = []
## The state an army is left in (Army.supply, A7): fed from the stores, fed by the land, or hungry.
const FED := 0
const FORAGED := 1
const HUNGRY := 2
## The food goods in the order they are eaten (4.8, step 1).
const FOOD_KEYS: Array[StringName] = [&"grain", &"fish"]
## The pinned view-cache slots: the land masks of the countries, and the depots and fields of the current keys.
const LAND_SLOT := &"supply_land"
const DEPOT_SLOT := &"supply_depots"


# --- depots and the field --------------------------------------------------------------------------------------------


## True when `hex` is a depot of `tag` (4.8, R5): a settlement of the country at depot_min_level or more, or a settlement
## of level 1 or more with a port on the coast.
static func is_depot(game: Game, tag: StringName, hex: Vector2i) -> bool:
	var c := Countries.by_tag(game, tag)
	if c == null or not _usable(game):
		return false
	var i := game.map.index_of(hex)
	return i >= 0 and game.map.land[i] == 1 and int(game.state.owner[i]) == c.id and _depot_at(game, i)


## The supply field of `tag` (4.8): one byte a hex, 1 where the hex is within supply_reach of a depot of the country through
## its own land, with the winter rules when `winter`. An empty array for an unknown tag or a game without countries.
static func field(game: Game, tag: StringName, winter: bool) -> PackedByteArray:
	var c := Countries.by_tag(game, tag)
	if c == null or not _usable(game):
		return PackedByteArray()
	var parts: Dictionary = game.view_cache.pinned(DEPOT_SLOT, _depot_key(game), Callable(Supply, "_new_parts").bind(game))
	var fields: Dictionary = parts["fields"]
	var k := c.id * 2 + (1 if winter else 0)
	if not fields.has(k):
		fields[k] = _make_field(game, c.id, winter, parts["depots"])
	return fields[k]


## True when `hex` is in the supply field of `tag` in the given rules.
static func in_supply(game: Game, tag: StringName, hex: Vector2i, winter: bool) -> bool:
	if game == null or game.map == null:
		return false
	var i := game.map.index_of(hex)
	var f := field(game, tag, winter)
	return i >= 0 and i < f.size() and f[i] == 1


## The food the armies of `tag` eat in the season the game is in (R8 b): the men whose hex is in the field, times
## army_food_milli, rounded up, in loads. The economy's production reads it; the supply phase eats it.
static func army_food(game: Game, tag: StringName) -> int:
	if not _usable(game):
		return 0
	# One field for the country (not one per army: each lookup hashes the owner, main_use and level bytes).
	var f := field(game, tag, Calendar.is_winter(game.turn))
	var men := 0
	for a: Army in Armies.of_country(game, tag):
		var i := game.map.index_of(a.hex)
		if i >= 0 and i < f.size() and f[i] == 1:
			men += a.men()
	return food_need(game, men)


# --- the rules of a season, as numbers -------------------------------------------------------------------------------


## The loads `men` soldiers eat in a season: ceil(men x army_food_milli / 1,000,000) (4.8 step 1).
static func food_need(game: Game, men: int) -> int:
	if game == null or game.defs == null or men <= 0:
		return 0
	return _ceil_div(men * game.defs.army_food_milli, 1000000)


## The men the land of hex `hex` feeds to an army in a season (4.8 step 2): the people x the cover's forage permille, then
## x forage_percent of the season's slot, each floored. 0 for sea, off the map or an unknown cover.
static func forage_cap(game: Game, view: StateView, hex: Vector2i, season: int) -> int:
	var i := game.map.index_of(hex)
	if i < 0 or game.map.land[i] == 0:
		return 0
	var t := game.defs.terrain(int(game.map.cover[i]))
	if t == null:
		return 0
	var people := view.people_at(i) * t.forage_permille / 1000
	return people * game.defs.forage_percent[_slot(game, i, season)] / 100


## The men an army loses to hunger out of `unfed` men at `hex` (4.8 step 3), before the cap at the army's men:
## ceil(unfed x starve_permille of the slot / 1000). 0 when nothing is unfed.
static func starve_loss(game: Game, hex: Vector2i, season: int, unfed: int) -> int:
	var i := game.map.index_of(hex)
	if i < 0 or unfed <= 0:
		return 0
	return _ceil_div(unfed * game.defs.starve_permille[_slot(game, i, season)], 1000)


## The season's supply arithmetic of one country as a pure function (4.8; no writes). `armies` is [{id, hex, men}] in id
## order and `stock` the country's stock (read only). Returns {food_taken: {good key: loads}, fed: {army id: men fed},
## foraged: {hex index: people taken}, losses: {army id: men lost}, states: {army id: FED, FORAGED or HUNGRY},
## why: {army id: reason}}. The supply phase applies exactly this result.
static func country_step(game: Game, view: StateView, tag: StringName, season: int, stock: PackedInt32Array,
		armies: Array[Dictionary]) -> Dictionary:
	var out := {"food_taken": {}, "fed": {}, "foraged": {}, "losses": {}, "states": {}, "why": {}}
	if not _usable(game) or view == null or Countries.by_tag(game, tag) == null:
		return out
	var fld := field(game, tag, Calendar.is_winter(season))
	var supplied: Array[Dictionary] = []
	var land: Array[Dictionary] = []
	for a: Dictionary in armies:
		var i := game.map.index_of(a["hex"])
		if i >= 0 and i < fld.size() and fld[i] == 1:
			supplied.append(a)
		else:
			land.append(a)
	var eaten := _eat(game, stock, supplied, out)
	for a: Dictionary in supplied:
		var fed := int(a["men"]) * eaten / 1000
		var unfed := int(a["men"]) - fed
		_record(game, season, a, fed, FED if unfed == 0 else HUNGRY, &"stores_empty", out)
	_forage(game, view, season, land, out)
	return out


# --- the phase -------------------------------------------------------------------------------------------------------


## The supply phase (4.8): every living country in id order, its armies in id order. Food through Stores (flow army),
## foraging through People (flow foraged), hunger through Armies.lose_men (`army_starved`, then `unit_lost`), and each
## army's supply state through Armies.set_supply.
static func season(game: Game) -> void:
	if not _usable(game):
		return
	for c: Country in game.countries:
		if c != null and c.alive and not Armies.of_country(game, c.tag).is_empty():
			_season_of(game, c)


static func _season_of(game: Game, c: Country) -> void:
	var mine := Armies.of_country(game, c.tag)
	var list: Array[Dictionary] = []
	for a: Army in mine:
		list.append({"id": a.id, "hex": a.hex, "men": a.men()})
	var res := country_step(game, StateView.of(game.state), c.tag, game.turn, c.stock, list)
	var food: Dictionary = res["food_taken"]
	for key: String in food:
		Stores.move(game, c.tag, game.defs.good_id(StringName(key)), -int(food[key]), &"army")
	var foraged: Dictionary = res["foraged"]
	for i: int in foraged:
		People.move(game, game.map.hex_of(i), -int(foraged[i]), &"foraged")
	for a: Army in mine:
		_apply_army(game, a, res)


static func _apply_army(game: Game, a: Army, res: Dictionary) -> void:
	var id := a.id
	var losses: Dictionary = res["losses"]
	var states: Dictionary = res["states"]
	var whys: Dictionary = res["why"]
	var lost := int(losses.get(id, 0))
	var men := a.men()
	Armies.set_supply(game, a, int(states.get(id, FED)), lost)
	if lost <= 0:
		return
	game.emit({"kind": "army_starved", "tag": a.tag, "army": id, "hex": a.hex, "lost": lost, "men": men - lost,
		"why": whys.get(id, &""), "name": a.name})
	Armies.lose_men(game, a, lost, &"starved")


# --- helpers ---------------------------------------------------------------------------------------------------------


## The armies of `out` who ate from the stores, by the goods in FOOD_KEYS order; returns the fed permille of the group.
static func _eat(game: Game, stock: PackedInt32Array, supplied: Array[Dictionary], out: Dictionary) -> int:
	var men := 0
	for a: Dictionary in supplied:
		men += int(a["men"])
	var need := food_need(game, men)
	var taken := 0
	for key: StringName in FOOD_KEYS:
		var g := game.defs.good_id(key)
		if taken >= need or g < 0 or g >= stock.size():
			continue
		var take := mini(need - taken, stock[g])
		if take > 0:
			taken += take
			out["food_taken"][String(key)] = take
	return 1000 if need == 0 else taken * 1000 / need


## The armies out of supply: each hex feeds its armies in id order from one cap; a hex that fed anyone loses people.
static func _forage(game: Game, view: StateView, season: int, land: Array[Dictionary], out: Dictionary) -> void:
	var by_hex := {}
	for a: Dictionary in land:
		var i := game.map.index_of(a["hex"])
		var group: Array = by_hex.get(i, [])
		group.append(a)
		by_hex[i] = group
	for i: int in by_hex:
		var rem := forage_cap(game, view, game.map.hex_of(i), season)
		var fed_any := false
		for a: Dictionary in by_hex[i]:
			var men := int(a["men"])
			var fed := mini(men, rem)
			rem -= fed
			fed_any = fed_any or fed > 0
			_record(game, season, a, fed, FORAGED if fed == men else HUNGRY, &"out_of_supply", out)
		var loss := _ceil_div(view.people_at(i) * game.defs.forage_loss_permille, 1000)
		if fed_any and loss > 0 and int(game.state.owner[i]) > 0:
			out["foraged"][i] = loss


## Writes one army's row of country_step's result: the men fed, the state, the hunger and its reason (none when all fed).
static func _record(game: Game, season: int, a: Dictionary, fed: int, state: int, why: StringName, out: Dictionary) -> void:
	var id := int(a["id"])
	var men := int(a["men"])
	var unfed := men - fed
	out["fed"][id] = fed
	out["states"][id] = state
	out["losses"][id] = mini(men, starve_loss(game, a["hex"], season, unfed))
	out["why"][id] = why if unfed > 0 else &""


## The slot of the forage and starve tables for hex `i` in `season`: 0 outside winter; in winter 3 + the hex's climate
## (snow 0, frost 1, mild 2), as the 4.8 numbers name them.
static func _slot(game: Game, i: int, season: int) -> int:
	if not Calendar.is_winter(season):
		return 0
	return 3 + clampi(int(game.map.climate[i]), 0, 2)


## One depot per settlement that counts (4.8): a settlement of depot_min_level or more, or a port on the coast of level 1 or
## more. Only a settlement held by someone is a depot.
static func _depot_at(game: Game, i: int) -> bool:
	if int(game.state.main_use[i]) != Economy.SETTLEMENTS:
		return false
	var level := int(game.state.level[i])
	if level >= game.defs.depot_min_level:
		return true
	if level < 1:
		return false
	var hex := game.map.hex_of(i)
	var place := Improve.place_of(game.map, hex)
	return bool(place.get("port", false)) and int(place.get("level", 0)) >= 1 and game.map.coast_mask(hex) != 0


## The depots of every country (country id -> sorted hex indices) and an empty field table, made when the key changes.
static func _new_parts(game: Game) -> Dictionary:
	return {"depots": _depots_of(game), "fields": {}}


static func _depots_of(game: Game) -> Dictionary:
	var out := {}
	var s := game.state
	for i: int in game.map.hex_count():
		if game.map.land[i] == 0 or int(s.owner[i]) == 0 or not _depot_at(game, i):
			continue
		var oid := int(s.owner[i])
		var arr: PackedInt32Array = out.get(oid, PackedInt32Array())
		arr.append(i)
		out[oid] = arr
	return out


## The field of one country: a multi-source search from its depots over its own land (4.8), one byte a hex.
static func _make_field(game: Game, oid: int, winter: bool, depots: Dictionary) -> PackedByteArray:
	var n := game.map.hex_count()
	var out := PackedByteArray()
	out.resize(n)
	out.fill(0)
	var starts: PackedInt32Array = depots.get(oid, PackedInt32Array())
	if starts.is_empty():
		return out
	var cost := PathSearch.field(game.map, StepCosts.of(game.map, game.defs), _land_mask(game, oid), starts,
		game.defs.supply_reach, winter, true)
	var reach := game.defs.supply_reach
	for i: int in n:
		if cost[i] <= reach:
			out[i] = 1
	return out


## The land of one country as one byte a hex (1: its own land), built on first ask and kept until the owners change.
static func _land_mask(game: Game, oid: int) -> PackedByteArray:
	var masks: Dictionary = game.view_cache.pinned(LAND_SLOT, _land_key(game),
		Callable(Supply, "_no_masks"))
	if not masks.has(oid):
		var n := game.map.hex_count()
		var mask := PackedByteArray()
		mask.resize(n)
		for i: int in n:
			mask[i] = 1 if game.map.land[i] == 1 and int(game.state.owner[i]) == oid else 0
		masks[oid] = mask
	return masks[oid]


static func _no_masks() -> Dictionary:
	return {}


static func _land_key(game: Game) -> Array:
	return [game.map.get_instance_id(), hash(game.state.owner)]


static func _depot_key(game: Game) -> Array:
	return [game.map.get_instance_id(), game.defs.get_instance_id(), game.defs.supply_reach, game.defs.depot_min_level,
		game.defs.supply_wade_cost, hash(game.state.owner), hash(game.state.main_use), hash(game.state.level)]


static func _usable(game: Game) -> bool:
	return game != null and game.map != null and game.state != null and game.defs != null and game.has_countries()


static func _ceil_div(a: int, b: int) -> int:
	return (a + b - 1) / b
