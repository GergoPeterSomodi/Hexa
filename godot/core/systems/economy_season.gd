## A country's season (docs/architecture/m4-build-spec.md 4.7 to 4.10 and 5.3): its people, needs and reserve, what its land
## makes, what the towns use and the stores sell, and the money lines of the income phase. The functions here are pure;
## the phases `production` and `income` and the tax pair `set_tax_check` / `set_tax` are the impure part (4.7 to 4.10).
class_name EconomySeason
extends RefCounted

@warning_ignore_start("integer_division")

const OWNS: Array[String] = ["tax", "short_mask"]
## The needs of the towns, in the order of Country.short_mask's bits.
const NEEDS: Array[StringName] = [&"food", &"wine", &"salt", &"oil"]
## The tax levels' names, by level (Words.tax_name is a view's; a system keeps its own).
const TAX_NAMES: Array[String] = ["Low", "Normal", "High"]


## The people of a country's settlement hexes.
static func town_people(game: Game, view: StateView, tag: StringName) -> int:
	return int(counts(game, view, tag)["town_tax"])


## The people of the rest of a country's land, the tax count (see counts).
static func country_people(game: Game, view: StateView, tag: StringName) -> int:
	return int(counts(game, view, tag)["rest_tax"])


## The loads a season the towns need: {food, wine, salt, oil} (String keys); ceil(town people x need_milli / 1,000,000),
## and army_food, the loads the country's armies in supply eat this season (5.0 R8 a, b).
static func needs_of(game: Game, view: StateView, tag: StringName) -> Dictionary:
	return needs_for(game, int(counts(game, view, tag)["town"]), Supply.army_food(game, tag))


## needs_of from the town people already counted (and the armies' food, 0 when none).
static func needs_for(game: Game, town: int, army_food: int = 0) -> Dictionary:
	var defs := game.defs
	var out: Dictionary = {"food": need_loads(town, defs.food_need_milli), "army_food": army_food}
	for g: GoodDef in defs.goods:
		if g.kind == &"staple":
			out[String(g.key)] = need_loads(town, g.need_milli)
	for need: StringName in NEEDS:
		if not out.has(String(need)):
			out[String(need)] = 0
	return out


## ceil(town people x need_milli / 1,000,000); 0 town people need nothing.
static func need_loads(town: int, need_milli: int) -> int:
	return (town * need_milli + 999999) / 1000000


## The stock a country keeps per good id (4.2): grain four seasons of food, a needed good four seasons of its need, a
## material its fixed reserve, the rest 0.
static func reserve_of(game: Game, view: StateView, tag: StringName) -> PackedInt32Array:
	return reserve_for(game, needs_of(game, view, tag))


## reserve_of from needs already worked out (needs_of's result). Grain keeps the towns' food and the armies' (a missing
## army_food is 0).
static func reserve_for(game: Game, needs: Dictionary) -> PackedInt32Array:
	var defs := game.defs
	var out := PackedInt32Array()
	out.resize(defs.goods.size())
	var army_food := int(needs.get("army_food", 0))
	for i: int in out.size():
		var g := defs.goods[i]
		if g.kind == &"food":
			out[i] = defs.reserve_seasons * (int(needs["food"]) + army_food) if g.key == &"grain" else 0
		elif g.kind == &"staple":
			out[i] = defs.reserve_seasons * int(needs[String(g.key)])
		else:
			out[i] = g.reserve_fixed
	return out


## What a country's land makes in a season (district_output's step over every hex it owns): {made: PackedInt32Array by
## good id, dues: [{hex, amount}], upkeep (ducats, positive), upkeep_count (districts with upkeep), walls: [{hex, amount}]}.
## `weather` is Game.weather (per climate); the hex's own climate picks its entry. The game's own view reads the
## DistrictCache (when the game has one, or `with_cache` is given: Game.districts is read until the field exists); any
## other view computes each hex.
static func made_of(game: Game, view: StateView, tag: StringName, season: int, weather: PackedByteArray, tax: int, with_cache: DistrictCache = null) -> Dictionary:
	var map := game.map
	var defs := game.defs
	var made := PackedInt32Array()
	made.resize(defs.goods.size())
	var dues_list: Array[Dictionary] = []
	var walls: Array[Dictionary] = []
	var upkeep := 0
	var count := 0
	var c := Countries.by_tag(game, tag)
	var out := {"made": made, "dues": dues_list, "upkeep": 0, "upkeep_count": 0, "walls": walls}
	if c == null:
		return out
	var cache: Variant = with_cache
	if cache == null and view.state == game.state and view.changed().is_empty() and view.people_changed().is_empty():
		cache = game.get("districts")
		if cache is DistrictCache and game.defs.wild_yield.size() > 0:
			# The game's own view: the country's land summed up (SeasonProfile), exact and a pass over its few special hexes.
			var held := SeasonProfile.table(game)
			return SeasonProfile.made(game, SeasonProfile.of(game, held, c.id), SeasonProfile.live(game, held, c.id), season,
				weather, tax)
	var fams: Array[FamilyDef] = []
	for id: int in FamilyIds.COUNT:
		fams.append(defs.family(id))
	var settle := fams[Economy.SETTLEMENTS]
	var besieged := besieged_set(game)
	var share := occupied_permille(game, &"output")
	for i: int in Occupation.controlled(game, c.id):
		if besieged.has(i):
			continue
		var climate := int(map.climate[i])
		var w := int(weather[climate]) if climate < weather.size() else Economy.CALM
		if int(game.state.owner[i]) != c.id:
			# Land held for an occupier (4.10): the hex's own district_output at the output permille; no upkeep or walls.
			var got := Economy.district_output(game, view, map.hex_of(i), season, w, -1)
			var goods: PackedInt32Array = got["goods"]
			for g: int in made.size():
				made[g] += goods[g] * share / 1000
			var amount := int(got["ducats"]) * share / 1000
			if amount > 0:
				dues_list.append({"hex": map.hex_of(i), "amount": amount})
			continue
		var slot := Economy.slot_for(climate, season)
		var dues := 0
		var up := 0
		var wall := 0
		if cache is DistrictCache:
			var ints := (cache as DistrictCache).ints_of(game, i)
			var o := i * DistrictCache.FIELDS
			var raw := ints[o + Economy.F_RAW]
			var a0 := Economy.staffed(game, view, i, raw, ints[o + Economy.F_LIFT]).y if raw > 0 else 0
			dues = Economy.accumulate(fams[ints[o + Economy.F_FAMILY]], settle, ints[o + Economy.F_GOOD], a0,
				ints[o + Economy.F_BOUND] != 0, ints[o + Economy.F_WILD_GOOD], ints[o + Economy.F_COVER],
				ints[o + Economy.F_KEEP], ints[o + Economy.F_PORT], slot, w, tax, defs, made)
			up = ints[o + Economy.F_UPKEEP]
			wall = ints[o + Economy.F_WALLS]
		else:
			var base := Economy.district_base(game, view, map.hex_of(i))
			var rest := Economy.add_output(base, slot, w, tax, defs, made)
			dues = int(rest["ducats"])
			up = int(rest["upkeep"])
			wall = int(rest["walls"])
		if dues > 0:
			dues_list.append({"hex": map.hex_of(i), "amount": dues})
		if up > 0:
			upkeep += up
			count += 1
		if wall > 0:
			walls.append({"hex": map.hex_of(i), "amount": wall})
	out["upkeep"] = upkeep
	out["upkeep_count"] = count
	return out


## The towns' needs and the stores' sales of one season (4.7, 4.8), all pure. The goods made join the stock; the towns take
## food (fish first, then grain), then wine, salt and oil; the stock above `reserve` is sold at `prices`.
## {used: PackedInt32Array (positive loads by good id), sold, stock (after), taken: {food, wine, salt, oil}, satisfaction
## (permille, the same keys), content (permille), sales_milli (the sum of sold x prices)}.
static func goods_step(game: Game, needs: Dictionary, reserve: PackedInt32Array, stock: PackedInt32Array, made: PackedInt32Array, prices: PackedInt32Array) -> Dictionary:
	var defs := game.defs
	var count := defs.goods.size()
	var held := PackedInt32Array()
	var used := PackedInt32Array()
	var sold := PackedInt32Array()
	held.resize(count)
	used.resize(count)
	sold.resize(count)
	for g: int in count:
		held[g] = (stock[g] if g < stock.size() else 0) + (made[g] if g < made.size() else 0)
	var taken: Dictionary = {}
	# Food: fish, then grain (food_order).
	var remaining := int(needs["food"])
	for order: int in count:
		for g: int in count:
			if defs.goods[g].kind == &"food" and defs.goods[g].food_order == order:
				var take := mini(held[g], remaining)
				held[g] -= take
				used[g] += take
				remaining -= take
	taken["food"] = int(needs["food"]) - remaining
	for g: int in count:
		if defs.goods[g].kind == &"staple":
			var key := String(defs.goods[g].key)
			var take := mini(held[g], int(needs.get(key, 0)))
			held[g] -= take
			used[g] = take
			taken[key] = take
	var sales := 0
	for g: int in count:
		var keep := reserve[g] if g < reserve.size() else 0
		if held[g] > keep:
			sold[g] = held[g] - keep
			held[g] = keep
			sales += sold[g] * (prices[g] if g < prices.size() else 0)
	var satisfaction: Dictionary = {}
	for need: StringName in NEEDS:
		satisfaction[String(need)] = _satisfaction(int(taken.get(String(need), 0)), int(needs.get(String(need), 0)))
	return {
		"used": used, "sold": sold, "stock": held, "taken": taken, "satisfaction": satisfaction,
		"content": content_of(game, needs, used), "sales_milli": sales,
	}


## Contentment (permille, 4.7) from the loads the towns used (positive, by good id): food counts fish and grain together.
static func content_of(game: Game, needs: Dictionary, used: PackedInt32Array) -> int:
	var defs := game.defs
	var food_taken := 0
	var total := 0
	for g: int in defs.goods.size():
		var def := defs.goods[g]
		var loads := used[g] if g < used.size() else 0
		if def.kind == &"food":
			food_taken += loads
		elif def.kind == &"staple":
			total += def.need_weight * _satisfaction(loads, int(needs.get(String(def.key), 0)))
	total += defs.food_weight * _satisfaction(food_taken, int(needs.get("food", 0)))
	return total / 1000


## The factor (permille, 750 to 1,000) that contentment puts on the towns' taxes.
static func factor_of(game: Game, content: int) -> int:
	return game.defs.content_floor + content * (1000 - game.defs.content_floor) / 1000


## The income phase's lines (4.9), in order: tax_people, tax_goods, port_dues (each port), upkeep_districts, upkeep_walls
## (each walled hex), upkeep_army (M6: one line for the armies, count = armies, 5.0 R8 c); [{why, hex, amount, count}], a
## zero line left out. `made_info` is made_of's result.
static func money_lines(game: Game, view: StateView, tag: StringName, tax: int, content: int, sales_milli: int, made_info: Dictionary,
		town_known: int = -1, rest_known: int = -1, army_upkeep: int = 0, army_count: int = 0) -> Array[Dictionary]:
	var defs := game.defs
	var t := clampi(tax, 0, 2)
	var lines: Array[Dictionary] = []
	var town := town_known if town_known >= 0 else town_people(game, view, tag)
	var rest := rest_known if rest_known >= 0 else country_people(game, view, tag)
	var people := (town * defs.town_tax_milli * factor_of(game, content) / 1000 + rest * defs.country_tax_milli) \
			* defs.tax_permille[t] / 1000000000
	_add_line(lines, &"tax_people", Treasury.NO_HEX, people, 1)
	_add_line(lines, &"tax_goods", Treasury.NO_HEX, sales_milli * defs.goods_share_permille[t] / 1000000, 1)
	for due: Dictionary in made_info.get("dues", []):
		_add_line(lines, &"port_dues", due["hex"], int(due["amount"]), 1)
	_add_line(lines, &"upkeep_districts", Treasury.NO_HEX, -int(made_info.get("upkeep", 0)), int(made_info.get("upkeep_count", 0)))
	for wall: Dictionary in made_info.get("walls", []):
		_add_line(lines, &"upkeep_walls", wall["hex"], -int(wall["amount"]), 1)
	_add_line(lines, &"upkeep_army", Treasury.NO_HEX, -army_upkeep, army_count)
	return lines


## The production phase (4.7, 4.8), per living country in id order: what its land makes joins the stores (`made`), the
## towns take their needs (`used`), the stock above the reserve is sold (`sold`); every change a Stores.move. A need not
## fully met whose bit in Country.short_mask was clear emits goods_short; the mask is then set to what is short now.
static func production(game: Game) -> void:
	if not game.has_countries() or game.defs == null or game.defs.goods.is_empty():
		return
	var view := StateView.of(game.state)
	var season := Calendar.season_of(game.turn)
	var held := SeasonProfile.table(game)
	for c: Country in game.countries:
		if not c.alive or c.stock.size() != game.defs.goods.size():
			continue
		var profile := SeasonProfile.of(game, held, c.id)
		var live := SeasonProfile.live(game, held, c.id)
		var made_info := SeasonProfile.made(game, profile, live, season, game.weather, c.tax)
		var needs := needs_for(game, int(live["town"]), Supply.army_food(game, c.tag))
		var prices := Economy.market_prices(game, view, Economy.market_of(game, c.tag), c.stock)
		var step := goods_step(game, needs, reserve_for(game, needs), c.stock, made_info["made"], prices)
		var made: PackedInt32Array = made_info["made"]
		var used: PackedInt32Array = step["used"]
		var sold: PackedInt32Array = step["sold"]
		for g: int in made.size():
			if made[g] != 0:
				Stores.move(game, c.tag, g, made[g], &"made")
		for g: int in used.size():
			if used[g] != 0:
				Stores.move(game, c.tag, g, -used[g], &"used")
		for g: int in sold.size():
			if sold[g] != 0:
				Stores.move(game, c.tag, g, -sold[g], &"sold")
		_report_shortages(game, c, needs, step["taken"])


## The income phase (4.9), per living country in id order: the season's flows give the contentment and the goods sold, the
## land gives the dues, upkeep and walls, and every line is a Treasury.move at the country's tax level.
static func income(game: Game) -> void:
	if not game.has_countries() or game.defs == null:
		return
	var view := StateView.of(game.state)
	var season := Calendar.season_of(game.turn)
	var goods := game.defs.goods.size()
	var held := SeasonProfile.table(game)
	for c: Country in game.countries:
		if not c.alive:
			continue
		var profile := SeasonProfile.of(game, held, c.id)
		var used := PackedInt32Array()
		used.resize(goods)
		var sold_milli := 0
		var prices := Economy.market_prices(game, view, Economy.market_of(game, c.tag), c.stock)
		for g: int in goods:
			used[g] = -Stores.flow(c, g, &"used")
			sold_milli += -Stores.flow(c, g, &"sold") * (prices[g] if g < prices.size() else 0)
		var live := SeasonProfile.live(game, held, c.id)
		var needs := needs_for(game, int(live["town"]))
		var made_info := SeasonProfile.made(game, profile, live, season, game.weather, c.tax)
		var lines := money_lines(game, view, c.tag, c.tax, content_of(game, needs, used), sold_milli, made_info,
			int(live["town_tax"]), int(live["rest_tax"]), Military.upkeep_country(game, c.tag), Armies.of_country(game, c.tag).size())
		for line: Dictionary in lines:
			Treasury.move(game, c.tag, int(line["amount"]), line["why"], line["hex"], int(line["count"]))


## The tax change's check (4.10), in the order of its table.
static func set_tax_check(game: Game, args: Dictionary) -> Dictionary:
	if game == null or not game.has_countries() or game.countries.is_empty():
		return _refusal("this map has no countries")
	var tag := _tag_of(args)
	if tag == &"":
		return _refusal("choose your country first")
	var c := Countries.by_tag(game, tag)
	if c == null:
		return _refusal("no country %s" % String(tag))
	if not c.alive:
		return _refusal("%s is no more" % _name_of(game, tag))
	var level: Variant = args.get("level", null)
	if typeof(level) != TYPE_INT or int(level) < 0 or int(level) > 2:
		return _refusal("no such tax level")
	if int(level) == c.tax:
		return _refusal("taxes are already %s" % TAX_NAMES[c.tax])
	return {"ok": true, "reason": ""}


## The tax change (after checking again): writes Country.tax and emits tax_set {tag, level, from}.
static func set_tax(game: Game, args: Dictionary) -> Dictionary:
	var verdict := set_tax_check(game, args)
	if bool(verdict["ok"]):
		var c := Countries.by_tag(game, _tag_of(args))
		var from := c.tax
		c.tax = int(args["level"])
		game.emit({"kind": "tax_set", "tag": c.tag, "level": c.tax, "from": from})
	return verdict


## How far into debt a country may go: 0 in M4 (M12 changes it).
static func debt_limit(_game: Game, _tag: StringName) -> int:
	return 0


# --- internals -----------------------------------------------------------------------------------------------------

## Sets the bit of each need not fully met; emits goods_short for a need that is short now with its bit clear.
static func _report_shortages(game: Game, c: Country, needs: Dictionary, taken: Dictionary) -> void:
	var mask := 0
	for n: int in NEEDS.size():
		var key := String(NEEDS[n])
		var need := int(needs.get(key, 0))
		var got := int(taken.get(key, 0))
		if got >= need:
			continue
		mask |= 1 << n
		if c.short_mask & (1 << n) == 0:
			game.emit({"kind": "goods_short", "tag": c.tag, "good": NEEDS[n], "need": need, "taken": got,
				"witnesses": [c.tag]})
	c.short_mask = mask


static func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


static func _tag_of(args: Dictionary) -> StringName:
	var raw: Variant = args.get("tag", &"")
	if raw is StringName:
		return raw
	if raw is String:
		return StringName(raw as String)
	return &""


static func _name_of(game: Game, tag: StringName) -> String:
	var def := Countries.def_of(game, tag)
	return def.name if def != null and not def.name.is_empty() else String(tag)


static func _add_line(lines: Array[Dictionary], why: StringName, hex: Vector2i, amount: int, count: int) -> void:
	if amount != 0:
		lines.append({"why": why, "hex": hex, "amount": amount, "count": count})


static func _satisfaction(taken: int, need: int) -> int:
	return 1000 if need <= 0 else mini(1000, taken * 1000 / need)


## The people of a country by the war rules (4.10): {town, rest} the full counts (the towns' needs: an occupier's towns need
## its stores in full) and {town_tax, rest_tax} the counts the taxes read. Besieged land counts for nothing.
static func counts(game: Game, view: StateView, tag: StringName) -> Dictionary:
	var c := Countries.by_tag(game, tag)
	if c == null:
		return {"town": 0, "rest": 0, "town_tax": 0, "rest_tax": 0}
	return counts_of(game, view, c.id)


## counts of a country by its id. Its own unoccupied land in full for the tax; the land it holds for an occupier (its
## owner's land is not its own) at occupied_tax_permille.
static func counts_of(game: Game, view: StateView, id: int) -> Dictionary:
	var besieged := besieged_set(game)
	var share := occupied_permille(game, &"tax")
	var town_own := 0
	var town_held := 0
	var rest_own := 0
	var rest_held := 0
	for i: int in Occupation.controlled(game, id):
		if besieged.has(i):
			continue
		var people := Economy.people_i(game.map, view, i)
		var own := int(game.state.owner[i]) == id
		if view.main_use_at(i) == Economy.SETTLEMENTS:
			town_own += people if own else 0
			town_held += 0 if own else people
		else:
			rest_own += people if own else 0
			rest_held += 0 if own else people
	return {"town": town_own + town_held, "rest": rest_own + rest_held,
		"town_tax": town_own + town_held * share / 1000, "rest_tax": rest_own + rest_held * share / 1000}


## The land indices under a siege (Occupation.besieged: the besieger is at war with the hex's controller), as a set.
static func besieged_set(game: Game) -> Dictionary:
	var out: Dictionary = {}
	for s: Siege in game.sieges:
		var i := game.map.index_of(s.hex)
		if i >= 0 and Occupation.besieged(game, s.hex):
			out[i] = true
	return out


## A key of the wars by their sides and end turns: the season profile's table is dropped when a war starts, ends or changes.
static func wars_key(game: Game) -> int:
	var rows: Array = []
	for w: War in game.wars:
		rows.append([w.a, w.b, w.end_turn])
	return hash(rows)


## A key of the sieges by their hexes: the season profile's table is dropped when one starts or lifts.
static func sieges_key(game: Game) -> int:
	var hexes: Array = []
	for s: Siege in game.sieges:
		hexes.append(s.hex)
	return hash(hexes)


## The WarDef's permille for held land: &"output" (goods and dues) or &"tax" (the people's tax). 0 with no war numbers.
static func occupied_permille(game: Game, which: StringName) -> int:
	var w: WarDef = game.defs.war if game != null and game.defs != null else null
	if w == null:
		return 0
	return w.occupied_output_permille if which == &"output" else w.occupied_tax_permille
