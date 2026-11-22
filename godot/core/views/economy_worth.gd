## The worth of a country's land (D34, docs/architecture/m4-build-spec.md 4.17): what each hex gives in the season in play
## and in the next seasons, worked out from the same baseline and calm weather as the preview (EconomyPreview). Pure
## core/views/ code; the answers are kept in the game's view cache by the game's version. Split out of economy_preview.gd
## (B10 step 1); EconomyPreview keeps facades for its public functions.
class_name EconomyWorth
extends RefCounted

@warning_ignore_start("integer_division")


## [{hex, worth, upkeep, label}] for the country's land in the season in play (D34): each hex's goods at price, its port
## dues and its people's taxes less its upkeep and walls (floored for each hex), by hex index; hexes that give and cost
## nothing are left out. Cached by [&"worth", version, tag].
static func worth_by_hex(game: Game, tag: StringName) -> Array[Dictionary]:
	var key: Array = [&"worth", game.version, tag]
	return game.view_cache.get_or_make(key, func() -> Array[Dictionary]: return _make_worth(game, tag)) as Array[Dictionary]


## What every hex of the country's land gives in each of the next `seasons` seasons, as `EconomyPreview.with(game, tag, {}, seasons)` runs
## them (calm weather, the works under way standing from their ready turns, the towns' contentment of each season):
## {turn, seasons, hexes (the land hex indices, ascending), worth, upkeep (upkeep and walls, positive), dues (all
## PackedInt32Array [h * seasons + k]), goods (loads, [(h * seasons + k) * G + g]), total (loads of each good over all
## hexes and seasons), top (for each good, the hex index that makes most of it, -1 for none)}. A hex's worth is D34's,
## floored for each hex. Cached by [&"worth_seasons", version, tag, seasons]. worth_by_hex is its first season (the
## per-hex step is shared). An unknown country, a map-only game or one without goods gives no hexes. One pass a hex on
## the district cache's ints; a hex with no piece and the same cover, people and climate as one seen is not worked out
## again (spec 10's fallback, with the same numbers).
## The caller gets its own copy (the arrays are copied, the cache is never shared); views in core/views/ that only read
## use worth_seasons_shared.
static func worth_seasons(game: Game, tag: StringName, seasons: int = 4) -> Dictionary:
	return worth_seasons_shared(game, tag, seasons).duplicate(true)


## worth_seasons without the copy: the cached dictionary itself. READ-ONLY: never write into it or its arrays.
static func worth_seasons_shared(game: Game, tag: StringName, seasons: int = 4) -> Dictionary:
	var key: Array = [&"worth_seasons", game.version, tag, seasons]
	return game.view_cache.get_or_make(key, func() -> Dictionary: return _make_worth_seasons(game, tag, seasons)) as Dictionary


static func _make_worth_seasons(game: Game, tag: StringName, seasons: int) -> Dictionary:
	var count := clampi(seasons, 1, EconomyPreview.MAX_SEASONS)
	var out: Dictionary = {"turn": game.turn, "seasons": count, "hexes": PackedInt32Array(), "worth": PackedInt32Array(),
		"upkeep": PackedInt32Array(), "dues": PackedInt32Array(), "goods": PackedInt32Array(), "total": PackedInt32Array(),
		"top": PackedInt32Array()}
	var c := Countries.by_tag(game, tag)
	if c == null or not c.alive or game.defs == null or game.defs.goods.is_empty() or c.stock.size() != game.defs.goods.size():
		return out
	var defs := game.defs
	var records := EconomyPreview.baseline(game, tag, count, c.tax)
	var run: Array = EconomyPreview.with(game, tag, {}, count)["seasons"]
	var hexes := Territory.districts(game, c.id)
	var goods_n := defs.goods.size()
	var worth := PackedInt32Array()
	worth.resize(hexes.size() * count)
	var upkeep := worth.duplicate()
	var dues := worth.duplicate()
	var loads := PackedInt32Array()
	loads.resize(hexes.size() * count * goods_n)
	var total := EconomyPreview.zeros(goods_n, 0)
	var top := EconomyPreview.zeros(goods_n, -1)
	var best := EconomyPreview.zeros(goods_n, 0)
	var prices := Economy.market_prices(game, null, Economy.market_of(game, c.tag), c.stock)
	var level := clampi(c.tax, 0, 2)
	var fams := EconomyPreview.families(defs)
	var inputs := _season_inputs(game, records, run, count)
	var factors: PackedInt32Array = inputs["factors"]
	var affected: Array = inputs["affected"]  # by season: hex index -> true for the hexes the standing works change
	var any_affected := bool(inputs["any"])
	var cache := game.districts
	var own := StateView.of(game.state)
	var scratch := EconomyPreview.zeros(goods_n, 0)
	var sums := EconomyPreview.zeros(goods_n, 0)
	var wild_memo: Dictionary = {}  # (cover, wild good, keep, people, climate) -> [worth k..., loads k...] of a hex with no piece
	for h: int in hexes.size():
		var i := hexes[h]
		var ints := cache.ints_of(game, i)
		var o := i * DistrictCache.FIELDS
		var climate := int(game.map.climate[i])
		var people := own.people_at(i)
		var wild_key := -1
		if ints[o] == 0 and people < 65536 and ints[o + Economy.F_KEEP] < 128 and not (any_affected and _touched(affected, i)):
			wild_key = (((ints[o + Economy.F_COVER] * 32 + ints[o + Economy.F_WILD_GOOD] + 1) * 128 + ints[o + Economy.F_KEEP]) \
				* 65536 + people) * 4 + climate
			var memo: Variant = wild_memo.get(wild_key)
			if memo != null:
				var m := memo as PackedInt32Array
				var wg := ints[o + Economy.F_WILD_GOOD]
				var gained := 0
				for k: int in count:
					worth[h * count + k] = m[k]
					if m[count + k] != 0:
						loads[(h * count + k) * goods_n + wg] = m[count + k]
						gained += m[count + k]
				if gained > 0:
					total[wg] += gained
					if gained > best[wg]:
						best[wg] = gained
						top[wg] = i
				continue
		sums.fill(0)
		var record := PackedInt32Array()
		var raw := ints[o + Economy.F_RAW]
		var own_a0 := Economy.staffed(game, own, i, raw, ints[o + Economy.F_LIFT]).y if raw > 0 else 0
		for k: int in count:
			var rec: Dictionary = records[k]
			var step: Vector3i
			scratch.fill(0)
			var slot := Economy.slot_for(climate, int(rec["season"]))
			if (affected[k] as Dictionary).has(i):
				var base := Economy.district_base(game, rec["view"] as StateView, game.map.hex_of(i))
				step = _worth_step(defs, fams, _ints_of_base(base), 0, slot, level, prices, factors[k], scratch, int(base["a0"]),
					int(base["people"]))
			else:
				step = _worth_step(defs, fams, ints, o, slot, level, prices, factors[k], scratch, own_a0, people)
			var at := h * count + k
			worth[at] = step.x
			upkeep[at] = step.y
			dues[at] = step.z
			for g: int in goods_n:
				if scratch[g] != 0:
					loads[at * goods_n + g] = scratch[g]
					sums[g] += scratch[g]
			record.append(step.x)
		for g: int in goods_n:
			if sums[g] > 0:
				total[g] += sums[g]
				if sums[g] > best[g]:
					best[g] = sums[g]
					top[g] = i
		if wild_key >= 0:
			var wg := ints[o + Economy.F_WILD_GOOD]
			for k: int in count:
				record.append(loads[(h * count + k) * goods_n + wg] if wg >= 0 else 0)
			wild_memo[wild_key] = record
	out.merge({"hexes": hexes, "worth": worth, "upkeep": upkeep, "dues": dues, "goods": loads, "total": total, "top": top}, true)
	return out


## The towns' factor of each season and the hexes whose part of the land differs from the game's in it (the baseline's dirty): {factors, affected (an Array of sets),
## any (some set is not empty)}.
static func _season_inputs(game: Game, records: Array, run: Array, count: int) -> Dictionary:
	var factors := PackedInt32Array()
	var affected: Array = []
	var any := false
	for k: int in count:
		var rec: Dictionary = records[k]
		factors.append(EconomySeason.factor_of(game, int((run[k] as Dictionary)["content"]) if k < run.size() else 1000))
		var set: Dictionary = (rec["dirty"] as Dictionary).duplicate()
		set.merge(rec["dirty_people"] as Dictionary)
		any = any or not set.is_empty()
		affected.append(set)
	return {"factors": factors, "affected": affected, "any": any}


## Whether hex index `i` is changed by the standing works in any season.
static func _touched(affected: Array, i: int) -> bool:
	for set: Dictionary in affected:
		if set.has(i):
			return true
	return false


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


## What the worth of every hex of a country shares: the season, the prices, the tax level and the towns' factor (the
## expected season's contentment, kept in the view cache).
static func _worth_context(game: Game, c: Country) -> Dictionary:
	var key: Array = [&"content", game.version, c.tag]
	var content := int(game.view_cache.get_or_make(key, func() -> int: return int(EconomyPreview.expected(game, c.tag).get("content", 1000))))
	return {
		"defs": game.defs, "season": Calendar.season_of(game.turn), "factor": EconomySeason.factor_of(game, content),
		"prices": Economy.market_prices(game, null, Economy.market_of(game, c.tag), c.stock), "level": clampi(c.tax, 0, 2),
		"fams": EconomyPreview.families(game.defs), "view": StateView.of(game.state),
	}


## One hex's part of one season for the worth (D34), from its base ints (`ints[o + field]`, Economy.BASE_FIELDS order):
## the base in `slot` of the year at tax `level`, calm. `goods` (zeroed, one place a good) receives the loads. Returns
## (worth, upkeep and walls, port dues): the goods at the fixed prices, the dues and its people's taxes (the towns' factor
## for a settlement), less upkeep and walls, floored once for the hex. The one step under worth_by_hex, worth_of and
## worth_seasons; `fams` are the families by id; `a0` and `people` are the hex's live numbers (the cache keeps neither).
static func _worth_step(defs: GameDefs, fams: Array[FamilyDef], ints: PackedInt32Array, o: int, slot: int, level: int,
		prices: PackedInt32Array, factor: int, goods: PackedInt32Array, a0: int, people: int) -> Vector3i:
	var family := ints[o]
	var dues := Economy.accumulate(fams[family], fams[Economy.SETTLEMENTS], ints[o + Economy.F_GOOD], a0,
		ints[o + Economy.F_BOUND] != 0, ints[o + Economy.F_WILD_GOOD], ints[o + Economy.F_COVER], ints[o + Economy.F_KEEP],
		ints[o + Economy.F_PORT], slot, Economy.CALM, level, defs, goods)
	var milli := 0
	for g: int in goods.size():
		if goods[g] != 0:
			milli += goods[g] * (prices[g] if g < prices.size() else 0)
	var rate: int = defs.town_tax_milli * factor / 1000 if family == Economy.SETTLEMENTS else defs.country_tax_milli
	var taxes := people * rate * defs.tax_permille[level] / 1000000000 if level < defs.tax_permille.size() else 0
	var upkeep := ints[o + Economy.F_UPKEEP] + ints[o + Economy.F_WALLS]
	return Vector3i(milli / 1000 + dues + taxes - upkeep, upkeep, dues)


## A base dictionary as the ints the cache keeps (Economy.BASE_FIELDS order).
static func _ints_of_base(base: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	for key: String in Economy.BASE_FIELDS:
		out.append(int(bool(base[key])) if key == "weather_bound" else int(base[key]))
	return out


## The worth entry of hex index `i` of the country, from the district cache (no second base); {} when it gives and costs nothing.
static func _worth_row(game: Game, ctx: Dictionary, i: int) -> Dictionary:
	var defs: GameDefs = ctx["defs"]
	var goods := PackedInt32Array()
	goods.resize(defs.goods.size())
	var ints := game.districts.ints_of(game, i)
	var o := i * DistrictCache.FIELDS
	var raw := ints[o + Economy.F_RAW]
	var own: StateView = ctx["view"]
	var a0 := Economy.staffed(game, own, i, raw, ints[o + Economy.F_LIFT]).y if raw > 0 else 0
	var step := _worth_step(defs, ctx["fams"] as Array[FamilyDef], ints, o,
		Economy.slot_for(int(game.map.climate[i]), int(ctx["season"])), int(ctx["level"]), ctx["prices"] as PackedInt32Array,
		int(ctx["factor"]), goods, a0, own.people_at(i))
	if step.x == 0 and step.y == 0:
		return {}
	var hex := game.map.hex_of(i)
	return {"hex": hex, "worth": step.x, "upkeep": step.y, "label": Words.place(game, hex)}


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
