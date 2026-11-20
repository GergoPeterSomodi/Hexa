## The one what-if of the economy (docs/architecture/m4-build-spec.md 4.17 and 5.6): a country's next seasons with calm
## weather, from its stock and tax level now, with its works under way standing from their ready turns and, when asked,
## a change laid over them (a piece on a hex, another tax level). It runs the same functions the phases run
## (SeasonProfile and Economy for what the land makes, EconomySeason for the towns, the stores and the money lines), so
## it equals the real seasons to the unit. Pure core/views/ code: it never writes the game (only its view cache), reads no
## Settings and draws no luck. Both measures of 5.0 R2 are in every season: `net` (the treasury's: the money lines'
## sum) and `realm` (goods made at price + taxes on people + port dues - upkeep - walls).
##
## The delta method: the country's land for the seasons asked is summed once a version (the baseline, kept in the game's
## view cache); a change re-runs the district on its hex and the six round it and replaces those hexes' part; the
## country's step (needs, sales, money) then runs whole for each season.
class_name EconomyPreview
extends RefCounted

@warning_ignore_start("integer_division")

## The seasons a baseline keeps at most (a longer ask is cut).
const MAX_SEASONS := 16


## The next `seasons` seasons of `tag`: {seasons: [{turn, season (0 spring to 3 winter), made (loads by good id), used,
## sold, stock (after), content (permille), lines ([{why, hex, amount, count}]), net, realm, town, rest, tax}], year:
## {net, realm}} (the sums). `changes`: {hexes: {hex index -> Vector2i(main_use, level)}, tax: int (-1: keep), detail:
## bool, lines: bool (default true)}. Every change stands from the first season; the country's works stand from their ready turns. With `detail`
## each season also has `hexes`: one entry for each land hex the change touches (the hexes and the six round them),
## {hex, i, owner, from (the hex's base before), to (after), from_goods, to_goods (PackedInt32Array), from_dues,
## to_dues, from_cost, to_cost (upkeep + walls)}. With `lines` false the port dues and the walls come as one line each
## (at no hex): the same net and realm to the unit, without a copy of the country's lists (the works card's way). An unknown country, a map-only game or a game with no goods gives {seasons: [], year: zeros}.
static func with(game: Game, tag: StringName, changes: Dictionary, seasons: int = 4) -> Dictionary:
	var out: Dictionary = {"seasons": [] as Array[Dictionary], "year": {"net": 0, "realm": 0}}
	var c := Countries.by_tag(game, tag)
	if c == null or not c.alive or game.defs == null or game.defs.goods.is_empty() or seasons < 1 \
			or c.stock.size() != game.defs.goods.size():
		return out
	var count := mini(seasons, MAX_SEASONS)
	var tax := int(changes.get("tax", -1))
	if tax < 0 or tax > 2:
		tax = c.tax
	var over: Dictionary = changes.get("hexes", {})
	var detail := bool(changes.get("detail", false))
	var lists := bool(changes.get("lines", true))
	var memo: Dictionary = {}
	var around := _around(game, over.keys()) if not over.is_empty() else PackedInt32Array()
	var from_view: StateView = null
	var to_view: StateView = null
	var column := baseline(game, tag, count, tax)
	var stock := c.stock.duplicate()
	var list: Array[Dictionary] = out["seasons"]
	var net_sum := 0
	var realm_sum := 0
	for k: int in count:
		var rec: Dictionary = column[k]
		var view: StateView = rec["view"]
		var made_info := rec
		var touched: Array[Dictionary] = []
		if not over.is_empty():
			made_info = _copy_of(rec, lists)
			if rec["view"] != from_view:  # the same works standing: the same view with the change (and its bases)
				from_view = rec["view"]
				to_view = from_view.with(over)
			view = to_view
			_adjust(game, c, made_info, from_view, view, around, int(rec["season"]), tax, touched, false, lists, memo)
		var entry := _step(game, c, tax, made_info, view, stock, lists)
		entry["turn"] = rec["turn"]
		entry["season"] = rec["season"]
		if detail:
			entry["hexes"] = touched
		stock = entry["stock"]
		net_sum += int(entry["net"])
		realm_sum += int(entry["realm"])
		list.append(entry)
	out["year"] = {"net": net_sum, "realm": realm_sum}
	return out


## The season in play, calm: with(game, tag, {}, 1).seasons[0]; {} when there is none.
static func expected(game: Game, tag: StringName) -> Dictionary:
	var list: Array = with(game, tag, {}, 1)["seasons"]
	return list[0] if not list.is_empty() else {}


## The country's land, season by season, with its works under way standing from their ready turns, at tax level `tax`:
## one record for each of the next seasons, {turn, season, made, dues, dues_sum, upkeep, upkeep_count, walls, walls_sum, town,
## rest, view (the StateView with the works that stand by then)}. Kept in the game's view cache by [&"made", version, tag,
## tax] and extended in place, a season at a time, to the longest horizon asked (so a short ask and a long one share the
## records; the array may be longer than `seasons`). Read-only.
static func baseline(game: Game, tag: StringName, seasons: int, tax: int) -> Array:
	var key: Array = [&"made", game.version, tag, tax]
	var holder := game.view_cache.get_or_make(key, func() -> Dictionary: return _new_holder(game, tag)) as Dictionary
	var records: Array = holder["records"]
	var want := mini(seasons, MAX_SEASONS)
	if records.size() < want and holder["country"] != null:
		_extend(game, holder, tax, want)
	return records


## [{hex, worth, upkeep, label}] for the country's land in the season in play (D34): each hex's goods at price, its port
## dues and its people's taxes less its upkeep and walls (floored for each hex), by hex index; hexes that give and cost
## nothing are left out. Cached by [&"worth", version, tag].
static func worth_by_hex(game: Game, tag: StringName) -> Array[Dictionary]:
	var key: Array = [&"worth", game.version, tag]
	return game.view_cache.get_or_make(key, func() -> Array[Dictionary]: return _make_worth(game, tag)) as Array[Dictionary]


## The entry of worth_by_hex for one hex ({hex, worth, upkeep, label}), worked out on that hex alone; {} for a hex the
## country does not hold or one that gives and costs nothing. Equal to the list's entry (the hex panel's Worth row).
static func worth_of(game: Game, tag: StringName, hex: Vector2i) -> Dictionary:
	var c := Countries.by_tag(game, tag)
	var i := game.map.index_of(hex)
	if c == null or i < 0 or game.defs == null or game.defs.goods.is_empty() or game.map.land[i] == 0 \
			or int(game.state.owner[i]) != c.id:
		return {}
	var ctx := _worth_context(game, c)
	return _worth_row(game, ctx, i)


# --- the baseline ---------------------------------------------------------------------------------------------------


static func _new_holder(game: Game, tag: StringName) -> Dictionary:
	var c := Countries.by_tag(game, tag)
	var holder: Dictionary = {"records": [] as Array[Dictionary], "country": c, "memo": {}, "views": {}, "standing": [] as Array[Dictionary],
		"profile": {}, "own": StateView.of(game.state)}
	if c == null or game.defs == null:
		holder["country"] = null
		return holder
	holder["profile"] = SeasonProfile.of(game, SeasonProfile.table(game), c.id)
	holder["standing"] = _standing(game, c, MAX_SEASONS)
	return holder


## Adds the records up to `want` seasons to the holder.
static func _extend(game: Game, holder: Dictionary, tax: int, want: int) -> void:
	var c: Country = holder["country"]
	var records: Array = holder["records"]
	var profile: Dictionary = holder["profile"]
	var own: StateView = holder["own"]
	var standing: Array = holder["standing"]
	var views: Dictionary = holder["views"]
	for k: int in range(records.size(), want):
		var turn := game.turn + k
		var season := Calendar.season_of(turn)
		var landed := 0
		while landed < standing.size() and int((standing[landed] as Dictionary)["ready"]) <= turn:
			landed += 1
		var changes: Dictionary = {}
		var seeds: Array = []
		for n: int in landed:
			changes[int((standing[n] as Dictionary)["i"])] = (standing[n] as Dictionary)["pair"]
			seeds.append(int((standing[n] as Dictionary)["i"]))
		if landed > 0 and not views.has(landed):
			views[landed] = own.with(changes)
		var view: StateView = views[landed] if landed > 0 else own
		var info := SeasonProfile.made(game, profile, season, _calm(), tax)
		var rec: Dictionary = {
			"turn": turn, "season": season, "made": info["made"], "dues": info["dues"], "upkeep": int(info["upkeep"]),
			"upkeep_count": int(info["upkeep_count"]), "walls": info["walls"], "dues_sum": _sum_of(info["dues"] as Array),
			"walls_sum": _sum_of(info["walls"] as Array), "town": int(profile["town"]),
			"rest": int(profile["rest"]), "view": view,
		}
		if landed > 0:
			_adjust(game, c, rec, own, view, _around(game, seeds), season, tax, [], true, true, holder["memo"] as Dictionary)
		records.append(rec)


## The works that touch the country's land (a hex it owns, or one beside), ready within the window, as {i, pair, ready}
## in ready order (ties: work id).
static func _standing(game: Game, c: Country, seasons: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var last := game.turn + seasons - 1
	for work: Work in game.state.works:
		var i := game.map.index_of(work.hex)
		if i < 0:
			continue
		if not _touches(game, i, c.id):
			continue
		var ready := Works.ready_turn(game, work)
		if ready > last:
			continue
		var pair := Vector2i(0, 0) if work.action == Works.CLEAR else Vector2i(work.family, work.level_to)
		out.append({"i": i, "pair": pair, "ready": ready, "id": work.id})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["ready"]) < int(b["ready"]) or (int(a["ready"]) == int(b["ready"]) and int(a["id"]) < int(b["id"])))
	return out


static func _touches(game: Game, i: int, id: int) -> bool:
	if game.state.owner[i] == id:
		return true
	for j: int in _ring(game.map, i):
		if j >= 0 and game.state.owner[j] == id:
			return true
	return false


# --- the delta ------------------------------------------------------------------------------------------------------


## The land hexes (sea left out) of `indices` and the six round each, ascending and once each.
static func _around(game: Game, indices: Array) -> PackedInt32Array:
	var seen: Dictionary = {}
	for key: Variant in indices:
		var i := int(key)
		seen[i] = true
		for j: int in _ring(game.map, i):
			if j >= 0:
				seen[j] = true
	var out := PackedInt32Array()
	for i: Variant in seen:
		if game.map.land[int(i)] == 1:
			out.append(int(i))
	out.sort()
	return out


## Replaces the part of each hex in `hexes` (land indices) in `rec`: its goods, dues, upkeep, walls and people go from
## what `from_view` gives to what `to_view` gives. Only the hexes of country `c` count in the country's sums; `touched`
## (when given) receives every hex's before and after for `season`. `from_own`: from_view is the game's own state, so the
## DistrictCache answers it.
static func _adjust(game: Game, c: Country, rec: Dictionary, from_view: StateView, to_view: StateView, hexes: PackedInt32Array,
		season: int, tax: int, touched: Array, from_own: bool, lists: bool, memo: Dictionary) -> void:
	var map := game.map
	var defs := game.defs
	var made: PackedInt32Array = rec["made"]
	var goods := defs.goods.size()
	for i: int in hexes:
		var hex := map.hex_of(i)
		var slot := Economy.slot_for(int(map.climate[i]), season)
		var owner_id := int(game.state.owner[i])
		var level := tax if owner_id == c.id else _owner_tax(game, owner_id)
		var from_base := _base(game, from_view, i, from_own, memo)
		var to_base := _base(game, to_view, i, false, memo)
		if _same(from_base, to_base):
			continue  # nothing of this hex changes (a wild hex beside a change): it needs no part in the delta
		var from_goods := PackedInt32Array()
		from_goods.resize(goods)
		var to_goods := PackedInt32Array()
		to_goods.resize(goods)
		var from_out := Economy.add_output(from_base, slot, Economy.CALM, level, defs, from_goods)
		var to_out := Economy.add_output(to_base, slot, Economy.CALM, level, defs, to_goods)
		touched.append({
			"hex": hex, "i": i, "owner": owner_id, "from": from_base, "to": to_base, "from_goods": from_goods,
			"to_goods": to_goods, "from_dues": int(from_out["ducats"]), "to_dues": int(to_out["ducats"]),
			"from_cost": int(from_out["upkeep"]) + int(from_out["walls"]), "to_cost": int(to_out["upkeep"]) + int(to_out["walls"]),
		})
		if owner_id != c.id:
			continue
		for g: int in goods:
			made[g] += to_goods[g] - from_goods[g]
		rec["dues_sum"] = int(rec["dues_sum"]) + int(to_out["ducats"]) - int(from_out["ducats"])
		rec["walls_sum"] = int(rec["walls_sum"]) + int(to_out["walls"]) - int(from_out["walls"])
		if lists:
			_set_entry(rec["dues"] as Array, map, i, int(to_out["ducats"]))
			_set_entry(rec["walls"] as Array, map, i, int(to_out["walls"]))
		rec["upkeep"] = int(rec["upkeep"]) + int(to_out["upkeep"]) - int(from_out["upkeep"])
		rec["upkeep_count"] = int(rec["upkeep_count"]) + int(int(to_out["upkeep"]) > 0) - int(int(from_out["upkeep"]) > 0)
		var from_room := int(from_base["room"])
		var to_room := int(to_base["room"])
		if int(from_base["family"]) == Economy.SETTLEMENTS:
			rec["town"] = int(rec["town"]) - from_room
		else:
			rec["rest"] = int(rec["rest"]) - from_room
		if int(to_base["family"]) == Economy.SETTLEMENTS:
			rec["town"] = int(rec["town"]) + to_room
		else:
			rec["rest"] = int(rec["rest"]) + to_room


## Whether two bases hold the same numbers.
static func _same(a: Dictionary, b: Dictionary) -> bool:
	for key: String in Economy.BASE_FIELDS:
		if a[key] != b[key]:
			return false
	return a["good"] == b["good"]


## A hex's base in `view`; the game's own state reads the DistrictCache.
static func _base(game: Game, view: StateView, i: int, own: bool, memo: Dictionary) -> Dictionary:
	var key := i if own else (view.get_instance_id() << 24) | i
	if memo.has(key):
		return memo[key]
	var base: Dictionary = game.districts.base_of(game, i) if own else Economy.district_base(game, view, game.map.hex_of(i))
	memo[key] = base
	return base


## Sets the {hex, amount} entry of hex index `i` in a list kept in ascending hex index order: replaced, removed for 0, or
## inserted.
static func _set_entry(list: Array, map: MapData, i: int, amount: int) -> void:
	var hex := map.hex_of(i)
	var at := list.size()
	for n: int in list.size():
		var entry: Dictionary = list[n]
		if entry["hex"] == hex:
			if amount > 0:
				entry["amount"] = amount
			else:
				list.remove_at(n)
			return
		if at == list.size() and map.index_of(entry["hex"] as Vector2i) > i:
			at = n
	if amount > 0:
		list.insert(at, {"hex": hex, "amount": amount})


static func _sum_of(list: Array) -> int:
	var total := 0
	for entry: Dictionary in list:
		total += int(entry["amount"])
	return total


## The record with its own made array; with `lists` also its own dues and walls lists.
static func _copy_of(rec: Dictionary, lists: bool) -> Dictionary:
	var out := rec.duplicate()
	out["made"] = (rec["made"] as PackedInt32Array).duplicate()
	if not lists:
		return out
	var dues: Array = []
	for entry: Dictionary in rec["dues"]:
		dues.append(entry.duplicate())
	out["dues"] = dues
	var walls: Array = []
	for entry: Dictionary in rec["walls"]:
		walls.append(entry.duplicate())
	out["walls"] = walls
	return out


# --- the country's step ---------------------------------------------------------------------------------------------


## One season of the country on the land of `rec`: the towns take their needs, the stores sell, the money lines come.
static func _step(game: Game, c: Country, tax: int, rec: Dictionary, view: StateView, stock: PackedInt32Array, lists: bool) -> Dictionary:
	var needs := EconomySeason.needs_for(game, int(rec["town"]))
	var prices := Economy.market_prices(game, view, Economy.market_of(game, c.tag), stock)
	var made: PackedInt32Array = rec["made"]
	var step := EconomySeason.goods_step(game, needs, EconomySeason.reserve_for(game, needs), stock, made, prices)
	var info := {"made": made, "dues": rec["dues"], "upkeep": rec["upkeep"], "upkeep_count": rec["upkeep_count"],
		"walls": rec["walls"]}
	if not lists:
		info["dues"] = [{"hex": Treasury.NO_HEX, "amount": int(rec["dues_sum"])}]
		info["walls"] = [{"hex": Treasury.NO_HEX, "amount": int(rec["walls_sum"])}]
	var lines := EconomySeason.money_lines(game, view, c.tag, tax, int(step["content"]), int(step["sales_milli"]), info,
		int(rec["town"]), int(rec["rest"]))
	var net := Treasury.left_over(lines)
	var made_milli := 0
	for g: int in made.size():
		made_milli += made[g] * (prices[g] if g < prices.size() else 0)
	var tax_goods := 0
	for line: Dictionary in lines:
		if line["why"] == &"tax_goods":
			tax_goods += int(line["amount"])
	return {
		"made": made.duplicate(), "used": step["used"], "sold": step["sold"], "stock": step["stock"],
		"content": step["content"], "lines": lines, "net": net, "realm": made_milli / 1000 + net - tax_goods,
		"town": rec["town"], "rest": rec["rest"], "tax": tax,
	}


static func _calm() -> PackedByteArray:
	return PackedByteArray([0, 0, 0])


static func _ring(map: MapData, i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var hex := map.hex_of(i)
	for d: int in 6:
		out.append(map.index_of(map.neighbour(hex, d)))
	return out


static func _owner_tax(game: Game, owner_id: int) -> int:
	if owner_id == 0:
		return 1
	var c := Countries.by_id(game, owner_id)
	return c.tax if c != null else 1


# --- worth ----------------------------------------------------------------------------------------------------------


## What the worth of every hex of a country shares: the season, the prices, the tax level and the towns' factor (the
## expected season's contentment, kept in the view cache).
static func _worth_context(game: Game, c: Country) -> Dictionary:
	var key: Array = [&"content", game.version, c.tag]
	var content := int(game.view_cache.get_or_make(key, func() -> int: return int(expected(game, c.tag).get("content", 1000))))
	return {
		"defs": game.defs, "season": Calendar.season_of(game.turn), "factor": EconomySeason.factor_of(game, content),
		"prices": Economy.market_prices(game, null, Economy.market_of(game, c.tag), c.stock), "level": clampi(c.tax, 0, 2),
	}


## The worth entry of hex index `i` of the country, from the district cache (no second base); {} when it gives and costs nothing.
static func _worth_row(game: Game, ctx: Dictionary, i: int) -> Dictionary:
	var defs: GameDefs = ctx["defs"]
	var level: int = ctx["level"]
	var prices: PackedInt32Array = ctx["prices"]
	var base := game.districts.base_of(game, i)
	var goods := PackedInt32Array()
	goods.resize(defs.goods.size())
	var out := Economy.add_output(base, Economy.slot_for(int(game.map.climate[i]), int(ctx["season"])), Economy.CALM, level, defs, goods)
	var milli := 0
	for g: int in goods.size():
		milli += goods[g] * (prices[g] if g < prices.size() else 0)
	var rate: int = defs.town_tax_milli * int(ctx["factor"]) / 1000 if int(base["family"]) == Economy.SETTLEMENTS else defs.country_tax_milli
	var taxes := int(base["room"]) * rate * defs.tax_permille[level] / 1000000000 if level < defs.tax_permille.size() else 0
	var upkeep := int(out["upkeep"]) + int(out["walls"])
	var worth := milli / 1000 + int(out["ducats"]) + taxes - upkeep
	if worth == 0 and upkeep == 0:
		return {}
	var hex := game.map.hex_of(i)
	return {"hex": hex, "worth": worth, "upkeep": upkeep, "label": Words.place(game, hex)}


static func _make_worth(game: Game, tag: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var c := Countries.by_tag(game, tag)
	if c == null or game.defs == null or game.defs.goods.is_empty():
		return out
	var ctx := _worth_context(game, c)
	for i: int in Territory.districts(game, c.id):
		var row := _worth_row(game, ctx, i)
		if not row.is_empty():
			out.append(row)
	return out
