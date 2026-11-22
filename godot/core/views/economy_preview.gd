## The one what-if of the economy (docs/architecture/m4-build-spec.md 4.17 and 5.6): a country's next seasons with calm
## weather, from its stock and tax level now, with its works under way standing from their ready turns and, when asked,
## a change laid over them (a piece on a hex, another tax level). It runs the same functions the phases run
## (SeasonProfile and Economy for what the land makes, EconomySeason for the towns, the stores and the money lines), so
## it equals the real seasons to the unit. Pure core/views/ code: it never writes the game (only its view cache), reads no
## Settings and draws no luck. Both measures of 5.0 R2 are in every season: `net` (the treasury's: the money lines'
## sum) and `realm` (goods made at price + taxes on people + port dues - upkeep - walls).
##
## The people (docs/architecture/m5-build-spec.md 4.10 and 5.0 R4, R5): every previewed season runs the people step of the
## phase after production and income, on a what-if view: the rule of 4.4 on each hex that can change, then the level step
## (grow_check and decline_check, each change laid on the view before the next settlement is checked). The phase and the
## preview share the rules (People); the preview writes nothing.
##
## The delta method: the country's land for the seasons asked is summed once a version (the baseline, kept in the game's
## view cache, with the people stepped season by season: the people, the levels, what each season's food gave); a change
## re-runs the district on its hex and the six round it and replaces those hexes' part, and steps only the hexes whose people
## or piece differ from the baseline's (the changed hex, and every settlement from the first season whose food differs); the
## country's step (needs, sales, money) then runs whole for each season. Equal to the played seasons by induction.
class_name EconomyPreview
extends RefCounted

@warning_ignore_start("integer_division")

## The seasons a baseline keeps at most (a longer ask is cut).
const MAX_SEASONS := 16


## The next `seasons` seasons of `tag`: {seasons: [{turn, season (0 spring to 3 winter), made (loads by good id), used,
## sold, stock (after), content (permille), lines ([{why, hex, amount, count}]), net, realm, town, rest (the people at the
## season's start), tax, and the people step of the season: people (the country's total at its end), towns (the settlements'
## people at its end), fed (permille), grew, starved, left (positive), levels ([{hex, from, to}], the people's level changes)}],
## year: {net, realm}} (the sums). `changes`: {hexes: {hex index -> Vector2i(main_use, level)}, tax: int (-1: keep), detail:
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
	var column := baseline(game, tag, count, tax)
	var memo: Dictionary = (game.view_cache.get_or_make([&"made", game.version, tag, tax],
		func() -> Dictionary: return _new_holder(game, tag)) as Dictionary)["memo"]  # bases by signature, shared by the version
	var stock := c.stock.duplicate()
	var list: Array[Dictionary] = out["seasons"]
	var net_sum := 0
	var realm_sum := 0
	# Where this run differs from the baseline (5.0 R5): `lam` the pieces (hex index -> Vector2i(main_use, level)) and `delta`
	# the people (hex index -> people), each only for the hexes that differ.
	var run: Dictionary = {"lam": over.duplicate(), "delta": {}}
	var track := ArmyPreviewStep.track(game, tag)  # the country's armies (M6 R9): copies, stepped season by season
	var armed := not (track["armies"] as Array).is_empty()
	for k: int in count:
		var rec: Dictionary = column[k]
		var view: StateView = rec["view"]
		var made_info := rec
		var touched: Array[Dictionary] = []
		var lam: Dictionary = run["lam"]
		var delta: Dictionary = run["delta"]
		var army := {}
		if armed:  # the supply phase: the armies eat, forage and starve before production; the foragers' people come off
			army = ArmyPreviewStep.supply(game, (rec["view"] as StateView).with(lam).with_people(delta), track, stock,
				int(rec["turn"]))
			stock = ArmyPreviewStep.after_eating(stock, army["eaten"])
			for i: int in army["foraged"]:  # only the country's own hexes: a foreign hex's people are not this country's
				if int(game.state.owner[i]) == c.id:
					delta[i] = _people_before(game, rec, delta, i) - int(army["foraged"][i])
		var diverged := not lam.is_empty() or not delta.is_empty()
		if diverged:
			made_info = _copy_of(rec, lists)
			view = (rec["view"] as StateView).with(lam).with_people(delta)
			var keys: Array = lam.keys()
			keys.append_array(delta.keys())
			_adjust(game, c, made_info, rec["view"], view, _around(game, keys), int(rec["season"]), tax, touched, false, lists, memo)
		var entry := _step(game, c, tax, made_info, view, stock, lists, army)
		entry["turn"] = rec["turn"]
		entry["season"] = rec["season"]
		if diverged or int(entry["fed"]) != int(rec["fed"]):
			_option_people(game, c, rec, run, entry, tax)
		else:
			_same_people(rec, entry)
		if armed:  # the ready_units phase: the men raised come off the people the next season starts with
			_refill(game, rec, run, entry, track, view)
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
## records; the array may be longer than `seasons`). Each record also holds the people step of its season (5.0 R5): p_start and
## p_next (the people of the hexes that differ from the game's, hex index -> people, at the season's start and end), view_p
## (the view the step ran on: the works landed by the season's end), view_p2 (after the people moved), view_next (after the
## level step: the next record's view), steps (hex index -> Vector2i(amount, flow) for each hex that changed), cands (the
## settlements the level step looked at), towns_list, gone (the works finished by then), fed, grew, starved, left, people,
## towns, levels, and dirty (the hexes whose part of the land differs from the game's). Read-only.
static func baseline(game: Game, tag: StringName, seasons: int, tax: int) -> Array:
	var key: Array = [&"made", game.version, tag, tax]
	var holder := game.view_cache.get_or_make(key, func() -> Dictionary: return _new_holder(game, tag)) as Dictionary
	var records: Array = holder["records"]
	var want := mini(seasons, MAX_SEASONS)
	if int(holder["stepped"]) < want and holder["country"] != null:
		_extend(game, holder, tax, want)
	return records


## [{hex, worth, upkeep, label}] for the country's land in the season in play (D34): each hex's goods at price, its port
## dues and its people's taxes less its upkeep and walls (floored for each hex), by hex index; hexes that give and cost
## nothing are left out. Cached by [&"worth", version, tag].
static func worth_by_hex(game: Game, tag: StringName) -> Array[Dictionary]:
	var key: Array = [&"worth", game.version, tag]
	return game.view_cache.get_or_make(key, func() -> Array[Dictionary]: return _make_worth(game, tag)) as Array[Dictionary]


## What every hex of the country's land gives in each of the next `seasons` seasons, as `with(game, tag, {}, seasons)` runs
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
	var count := clampi(seasons, 1, MAX_SEASONS)
	var out: Dictionary = {"turn": game.turn, "seasons": count, "hexes": PackedInt32Array(), "worth": PackedInt32Array(),
		"upkeep": PackedInt32Array(), "dues": PackedInt32Array(), "goods": PackedInt32Array(), "total": PackedInt32Array(),
		"top": PackedInt32Array()}
	var c := Countries.by_tag(game, tag)
	if c == null or not c.alive or game.defs == null or game.defs.goods.is_empty() or c.stock.size() != game.defs.goods.size():
		return out
	var defs := game.defs
	var records := baseline(game, tag, count, c.tax)
	var run: Array = with(game, tag, {}, count)["seasons"]
	var hexes := Territory.districts(game, c.id)
	var goods_n := defs.goods.size()
	var worth := PackedInt32Array()
	worth.resize(hexes.size() * count)
	var upkeep := worth.duplicate()
	var dues := worth.duplicate()
	var loads := PackedInt32Array()
	loads.resize(hexes.size() * count * goods_n)
	var total := _zeros(goods_n, 0)
	var top := _zeros(goods_n, -1)
	var best := _zeros(goods_n, 0)
	var prices := Economy.market_prices(game, null, Economy.market_of(game, c.tag), c.stock)
	var level := clampi(c.tax, 0, 2)
	var fams := _families(defs)
	var inputs := _season_inputs(game, records, run, count)
	var factors: PackedInt32Array = inputs["factors"]
	var affected: Array = inputs["affected"]  # by season: hex index -> true for the hexes the standing works change
	var any_affected := bool(inputs["any"])
	var cache := game.districts
	var own := StateView.of(game.state)
	var scratch := _zeros(goods_n, 0)
	var sums := _zeros(goods_n, 0)
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


static func _zeros(n: int, value: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(n)
	out.fill(value)
	return out


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


# --- the baseline ---------------------------------------------------------------------------------------------------


static func _new_holder(game: Game, tag: StringName) -> Dictionary:
	var c := Countries.by_tag(game, tag)
	var own := StateView.of(game.state)
	var holder: Dictionary = {"records": [] as Array[Dictionary], "country": c, "memo": {}, "standing": [] as Array[Dictionary],
		"profile": {}, "live": {}, "own": own, "stepped": 0, "p": {}, "lv": {}, "act": {}, "gone": {}, "landed": 0,
		"stock": PackedInt32Array(), "view_next": own,
		"cum_town": 0, "cum_rest": 0, "dirty_cum": {}, "cand": {}, "losers": {}, "staff": {}}
	if c == null or game.defs == null:
		holder["country"] = null
		return holder
	var held := SeasonProfile.table(game)
	holder["profile"] = SeasonProfile.of(game, held, c.id)
	holder["live"] = SeasonProfile.live(game, held, c.id)
	holder["standing"] = _standing(game, c, MAX_SEASONS)
	holder["stock"] = c.stock.duplicate()
	var act: Dictionary = {}
	for i: int in People.active(game, own, c.id):
		act[i] = true
	holder["act"] = act
	return holder


## Makes and steps the records up to `want` seasons: each is built from the people and pieces the step before it left, then
## its own economy and people are stepped.
static func _extend(game: Game, holder: Dictionary, tax: int, want: int) -> void:
	var records: Array = holder["records"]
	while int(holder["stepped"]) < want:
		if records.size() <= int(holder["stepped"]):
			records.append(_record(game, holder, tax, records.size()))
		_step_record(game, holder, tax)


## The record of season `k` of the baseline: what the land makes with the people and pieces of the season's start.
static func _record(game: Game, holder: Dictionary, tax: int, k: int) -> Dictionary:
	var c: Country = holder["country"]
	var own: StateView = holder["own"]
	var lv: Dictionary = holder["lv"]
	var turn := game.turn + k
	var season := Calendar.season_of(turn)
	var view: StateView = holder["view_next"]
	var info := SeasonProfile.made(game, holder["profile"], holder["live"], season, _calm(), tax)
	var live: Dictionary = holder["live"]
	var rec: Dictionary = {
		"turn": turn, "season": season, "made": info["made"], "dues": info["dues"], "upkeep": int(info["upkeep"]),
		"upkeep_count": int(info["upkeep_count"]), "walls": info["walls"], "dues_sum": _sum_of(info["dues"] as Array),
		"walls_sum": _sum_of(info["walls"] as Array), "town": int(live["town"]), "rest": int(live["rest"]), "view": view,
		"p_start": holder["p"],
	}
	var dirty: Dictionary = {}
	var heavy := PackedInt32Array()
	if not lv.is_empty():
		heavy = _around(game, lv.keys())
		_adjust(game, c, rec, own, view, heavy, season, tax, [], true, true, holder["memo"] as Dictionary)
		for i: int in heavy:
			dirty[i] = true
	_light(game, holder, rec, view, heavy, season, tax, dirty)
	rec["dirty"] = dirty
	rec["dirty_people"] = holder["dirty_cum"]  # the hexes whose people moved so far (a later season may add more: read-only, a superset is safe)
	return rec


## The people's part of a record that the pieces' delta (`_adjust`) did not cover: the town and country sums of the hexes
## whose people moved (kept as running sums by `_step_record`, less the hexes `_adjust` already counted), and the goods
## districts whose staffing moved (5.0 R5: only an under-staffed one near a change, or one beside a hex that lost people:
## growth alone never lowers a staffing of 1,000).
static func _light(game: Game, holder: Dictionary, rec: Dictionary, view: StateView, heavy: PackedInt32Array, season: int,
		tax: int, dirty: Dictionary) -> void:
	var p: Dictionary = holder["p"]
	if p.is_empty():
		return
	var state := game.state
	var map := game.map
	rec["town"] = int(rec["town"]) + int(holder["cum_town"])
	rec["rest"] = int(rec["rest"]) + int(holder["cum_rest"])
	var skip: Dictionary = {}
	for i: int in heavy:
		skip[i] = true
		if p.has(i):
			var d := int(p[i]) - state.people[i]
			if state.main_use[i] == Economy.SETTLEMENTS:
				rec["town"] = int(rec["town"]) - d
			else:
				rec["rest"] = int(rec["rest"]) - d
	var rowat := _rows_at(holder)
	var cand: Dictionary = holder["cand"]
	var losers: Dictionary = holder["losers"]
	var near: Dictionary = {}
	for key: Variant in losers:
		for n: int in Economy.ring_of(map, int(key)):
			if n >= 0 and rowat.has(n):
				near[n] = true
		if rowat.has(key):
			near[key] = true
	if cand.is_empty():
		return
	var defs := game.defs
	var cache := game.districts
	var fams := _families(defs)
	var settle := fams[Economy.SETTLEMENTS]
	var made: PackedInt32Array = rec["made"]
	var was := _zeros(made.size(), 0)
	var now := _zeros(made.size(), 0)
	var rows: PackedInt32Array = (holder["profile"] as Dictionary)["rows"]
	var staff: Dictionary = holder["staff"]
	for key: Variant in cand:
		var j := int(key)
		if skip.has(j):
			continue
		if not staff.has(j):
			var o_row: int = rowat[j]
			staff[j] = cache.staffed_of(game, j, rows[o_row + 2], rows[o_row + 10])
		var own_staff: Vector2i = staff[j]
		if own_staff.x >= 1000 and not near.has(j):
			continue  # fully staffed and nobody beside it lost people: more hands change nothing
		var ints := cache.ints_of(game, j)
		var o := j * DistrictCache.FIELDS
		var a0 := Economy.staffed(game, view, j, ints[o + Economy.F_RAW], ints[o + Economy.F_LIFT]).y
		if a0 == own_staff.y:
			continue
		dirty[j] = true
		var slot := Economy.slot_for(int(map.climate[j]), season)
		for pass_n: int in 2:
			Economy.accumulate(fams[ints[o + Economy.F_FAMILY]], settle, ints[o + Economy.F_GOOD], a0 if pass_n == 1 else own_staff.y,
				ints[o + Economy.F_BOUND] != 0, ints[o + Economy.F_WILD_GOOD], ints[o + Economy.F_COVER], ints[o + Economy.F_KEEP],
				ints[o + Economy.F_PORT], slot, Economy.CALM, tax, defs, now if pass_n == 1 else was)
		for g: int in made.size():
			made[g] += now[g] - was[g]
			now[g] = 0
			was[g] = 0


## The profile's goods rows (raw above 0) by hex index: hex index -> the row's offset in the profile's rows. Made on first use.
static func _rows_at(holder: Dictionary) -> Dictionary:
	if holder.has("rowat"):
		return holder["rowat"]
	var rows: PackedInt32Array = (holder["profile"] as Dictionary)["rows"]
	var out: Dictionary = {}
	for o: int in range(0, rows.size(), SeasonProfile.ROW):
		if rows[o + 2] > 0:
			out[rows[o + 9]] = o
	holder["rowat"] = out
	return out


## The baseline's step moved hex index `i` by `amount` to `after` people: the running sums, the hexes whose people differ from
## the game's, the ones that lost people, and (the first time) the goods districts round it whose staffing may follow.
static func _note_moved(game: Game, holder: Dictionary, i: int, amount: int, after: int) -> void:
	var state := game.state
	if state.main_use[i] == Economy.SETTLEMENTS:
		holder["cum_town"] = int(holder["cum_town"]) + amount
	else:
		holder["cum_rest"] = int(holder["cum_rest"]) + amount
	var seen: Dictionary = holder["dirty_cum"]
	if not seen.has(i):
		seen[i] = true
		var rowat := _rows_at(holder)
		var cand: Dictionary = holder["cand"]
		if rowat.has(i):
			cand[i] = true
		for n: int in Economy.ring_of(game.map, i):
			if n >= 0 and rowat.has(n):
				cand[n] = true
	if after < state.people[i]:
		(holder["losers"] as Dictionary)[i] = true
	else:
		(holder["losers"] as Dictionary).erase(i)


static func _rates3(defs: GameDefs, season: int, tax: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for climate: int in 3:
		out.append(People.rates_of(defs, Economy.slot_for(climate, season), tax))
	return out


## The works that finish in the works phase of the season at `turn` (ready the turn after): laid on the baseline's pieces, marked
## gone (they no longer block a level change) and their hexes made active. Returns hex index -> pair.
static func _land_works(game: Game, holder: Dictionary, turn: int) -> Dictionary:
	var c: Country = holder["country"]
	var lv: Dictionary = holder["lv"]
	var act: Dictionary = holder["act"]
	var gone: Dictionary = holder["gone"]
	var standing: Array = holder["standing"]
	var landing: Dictionary = {}
	var landed := int(holder["landed"])
	while landed < standing.size() and int((standing[landed] as Dictionary)["ready"]) <= turn + 1:
		var entry: Dictionary = standing[landed]
		var at := int(entry["i"])
		lv[at] = entry["pair"]
		landing[at] = entry["pair"]
		gone[entry["work"]] = true
		if int(game.state.owner[at]) == c.id:
			act[at] = true
		landed += 1
	holder["landed"] = landed
	return landing


## Steps the record of the baseline's next season: the towns' food (the stock chain gives `fed`), then the people step of the
## phase (4.1): the works that finish this season land, every hex that can change moves, then the level step.
static func _step_record(game: Game, holder: Dictionary, tax: int) -> void:
	var records: Array = holder["records"]
	var rec: Dictionary = records[int(holder["stepped"])]
	var c: Country = holder["country"]
	var defs := game.defs
	var state := game.state
	var stock: PackedInt32Array = holder["stock"]
	var needs := EconomySeason.needs_for(game, int(rec["town"]))
	var prices := Economy.market_prices(game, null, Economy.market_of(game, c.tag), stock)
	var step := EconomySeason.goods_step(game, needs, EconomySeason.reserve_for(game, needs), stock, rec["made"], prices)
	holder["stock"] = step["stock"]
	var fed := int((step["satisfaction"] as Dictionary)["food"])
	var turn := int(rec["turn"])
	var season := int(rec["season"])
	var lv: Dictionary = holder["lv"]
	var act: Dictionary = holder["act"]
	var gone: Dictionary = holder["gone"]
	var landing := _land_works(game, holder, turn)
	var view_p: StateView = rec["view"]
	if not landing.is_empty():
		view_p = view_p.with(landing)
	var p: Dictionary = holder["p"]
	var p_next := p.duplicate()
	var rates := _rates3(defs, season, tax)
	var keys: Array = act.keys()
	keys.sort()
	var cache := game.districts
	var steps: Dictionary = {}
	var moved: Dictionary = {}
	var towns := PackedInt32Array()
	var flows := PackedInt32Array([0, 0, 0])
	var all_d := 0
	var town_d := 0
	for key: Variant in keys:
		var i := int(key)
		var settlement: bool
		var room: int
		if lv.has(i) or landing.has(i):  # a piece the view changed: its room is worked out on the view
			settlement = view_p.main_use_at(i) == Economy.SETTLEMENTS
			room = People.room_i(game, view_p, i)
		else:  # the game's piece: the district cache has its room
			var ints := cache.ints_of(game, i)
			settlement = ints[i * DistrictCache.FIELDS + Economy.F_FAMILY] == Economy.SETTLEMENTS
			room = ints[i * DistrictCache.FIELDS + Economy.F_ROOM]
		var people := int(p.get(i, state.people[i]))
		if settlement:
			towns.append(i)
		var change := People.rule_of(defs, people, room, settlement, rates[mini(int(game.map.climate[i]), 2)], fed)
		var after := people + change.x
		if change.x != 0:
			_note_moved(game, holder, i, change.x, after)
			steps[i] = change
			moved[i] = after
			p_next[i] = after
			flows[change.y] += absi(change.x)
			all_d += change.x
			if settlement:
				town_d += change.x
		if not settlement and after == room:
			act.erase(i)
	var view_p2 := view_p.with_people(moved)
	var cands := PackedInt32Array()
	var levels: Array[Dictionary] = []
	var view_cur := view_p2
	for i: int in towns:
		if not People.can_change_level(game, view_cur, i):
			continue
		cands.append(i)
		var change := _level_change(game, view_cur, i, fed, gone)
		if not change.is_empty():
			view_cur = view_cur.with({i: change["pair"]})
			lv[i] = change["pair"]
			levels.append({"hex": change["hex"], "from": change["from"], "to": change["to"]})
	rec["fed"] = fed
	rec["grew"] = flows[People.GREW]
	rec["starved"] = flows[People.STARVED]
	rec["left"] = flows[People.LEFT]
	rec["people"] = int(rec["town"]) + int(rec["rest"]) + all_d
	rec["towns"] = int(rec["town"]) + town_d
	rec["levels"] = levels
	rec["steps"] = steps
	rec["cands"] = cands
	rec["towns_list"] = towns
	rec["gone"] = gone.duplicate()
	rec["view_p"] = view_p
	rec["view_p2"] = view_p2
	rec["view_next"] = view_cur
	rec["p_next"] = p_next
	holder["p"] = p_next
	holder["view_next"] = view_cur
	holder["stepped"] = int(holder["stepped"]) + 1


## One settlement's level step (4.5) on the view: {} when it neither grows nor falls, else {hex, from, to, pair}.
static func _level_change(game: Game, view: StateView, i: int, fed: int, gone: Dictionary) -> Dictionary:
	var hex := game.map.hex_of(i)
	var level := view.level_at(i)
	var to := 0
	if bool(People.grow_check(game, view, hex, fed, gone)["ok"]):
		to = level + 1
	elif bool(People.decline_check(game, view, hex, gone)["ok"]):
		to = level - 1
	if to <= 0:
		return {}
	return {"hex": hex, "from": level, "to": to, "pair": Vector2i(Economy.SETTLEMENTS, to)}


## The people fields of an entry of a run that equals the baseline.
static func _same_people(rec: Dictionary, entry: Dictionary) -> void:
	for key: String in ["people", "towns", "fed", "grew", "starved", "left"]:
		entry[key] = rec[key]
	entry["levels"] = _levels_out(rec["levels"] as Array)


static func _levels_out(levels: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l: Dictionary in levels:
		out.append({"hex": l["hex"], "from": l["from"], "to": l["to"]})
	return out


## The people an armed run's season starts with on hex `i` before the supply phase: the run's delta, else the baseline's start.
static func _people_before(game: Game, rec: Dictionary, delta: Dictionary, i: int) -> int:
	return int(delta.get(i, (rec["p_start"] as Dictionary).get(i, game.state.people[i])))


## The ready_units phase of an armed run (M6 R9): the men raised from the people left at each army's hex come off the people
## the next season starts with (the run's delta) and the entry's people and towns (the season's end is after the refill).
static func _refill(game: Game, rec: Dictionary, run: Dictionary, entry: Dictionary, track: Dictionary, view: StateView) -> void:
	var delta: Dictionary = run["delta"]
	var ends := {}
	for i: int in ArmyPreviewStep.hexes_of(game, track):
		ends[i] = int(delta.get(i, (rec["p_next"] as Dictionary).get(i, game.state.people[i])))
	var raised := ArmyPreviewStep.refill(game, track, ends)
	for i: int in raised:
		delta[i] = ends[i]
		entry["people"] = int(entry["people"]) - int(raised[i])
		if view.main_use_at(i) == Economy.SETTLEMENTS:
			entry["towns"] = int(entry["towns"]) - int(raised[i])


## The people step of a run that differs from the baseline (5.0 R5): only the hexes whose people or piece differ from the
## baseline's (and every settlement when the food differs) are stepped; the rest is the baseline's. Fills the people fields
## of `entry` and the run's next `lam` (pieces) and `delta` (people).
static func _option_people(game: Game, c: Country, rec: Dictionary, run: Dictionary, entry: Dictionary, tax: int) -> void:
	var defs := game.defs
	var state := game.state
	var lam: Dictionary = run["lam"]
	var delta: Dictionary = run["delta"]
	var fed := int(entry["fed"])
	var wanted: Dictionary = {}
	for key: Variant in delta:
		wanted[key] = true
	for key: Variant in lam:
		if int(state.owner[int(key)]) == c.id:
			wanted[key] = true
	if fed != int(rec["fed"]):
		for i: int in rec["towns_list"] as PackedInt32Array:
			wanted[i] = true
	var keys: Array = wanted.keys()
	keys.sort()
	var base_p: StateView = rec["view_p"]
	var view_p := base_p.with(lam).with_people(delta)
	var rates := _rates3(defs, int(rec["season"]), tax)
	var p_start: Dictionary = rec["p_start"]
	var p_next: Dictionary = rec["p_next"]
	var b_steps: Dictionary = rec["steps"]
	var flows := PackedInt32Array([int(rec["grew"]), int(rec["starved"]), int(rec["left"])])
	var people_end := int(rec["people"])
	var towns_end := int(rec["towns"])
	var moved: Dictionary = {}
	var next_delta: Dictionary = {}
	for key: Variant in keys:
		var i := int(key)
		var people := int(delta.get(i, p_start.get(i, state.people[i])))
		var settlement := view_p.main_use_at(i) == Economy.SETTLEMENTS
		var change := People.rule_of(defs, people, People.room_i(game, view_p, i), settlement,
			rates[mini(int(game.map.climate[i]), 2)], fed)
		var after := people + change.x
		var then := int(p_next.get(i, state.people[i]))
		if b_steps.has(i):
			var b: Vector2i = b_steps[i]
			flows[b.y] -= absi(b.x)
		if change.x != 0:
			flows[change.y] += absi(change.x)
		people_end += after - then
		if settlement:
			towns_end += after
		if base_p.main_use_at(i) == Economy.SETTLEMENTS:
			towns_end -= then
		moved[i] = after
		if after != then:
			next_delta[i] = after
	var cands: Dictionary = {}
	for i: int in rec["cands"] as PackedInt32Array:
		cands[i] = true
	for key: Variant in keys:
		cands[key] = true
	var order: Array = cands.keys()
	order.sort()
	var view_cur := (rec["view_p2"] as StateView).with(lam).with_people(moved)
	var gone: Dictionary = rec["gone"]
	var levels: Array = []
	for key: Variant in order:
		var i := int(key)
		if int(state.owner[i]) != c.id or view_cur.main_use_at(i) != Economy.SETTLEMENTS \
				or not People.can_change_level(game, view_cur, i):
			continue
		var change := _level_change(game, view_cur, i, fed, gone)
		if not change.is_empty():
			view_cur = view_cur.with({i: change["pair"]})
			levels.append({"hex": change["hex"], "from": change["from"], "to": change["to"]})
	var b_next: StateView = rec["view_next"]
	var next_lam: Dictionary = {}
	var seen: Dictionary = {}
	for key: Variant in lam:
		seen[key] = true
	for key: Variant in order:
		seen[key] = true
	for key: Variant in seen:
		var i := int(key)
		var ours := Vector2i(view_cur.main_use_at(i), view_cur.level_at(i))
		if ours != Vector2i(b_next.main_use_at(i), b_next.level_at(i)):
			next_lam[i] = ours
	run["lam"] = next_lam
	run["delta"] = next_delta
	entry["people"] = people_end
	entry["towns"] = towns_end
	entry["grew"] = flows[People.GREW]
	entry["starved"] = flows[People.STARVED]
	entry["left"] = flows[People.LEFT]
	entry["levels"] = levels


## The works that touch the country's land (a hex it owns, or one beside), ready within the window (and the season after, for
## the people step that follows the works phase), as {i, pair, ready, work} in ready order (ties: work id).
static func _standing(game: Game, c: Country, seasons: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var last := game.turn + seasons
	for work: Work in game.state.works:
		var i := game.map.index_of(work.hex)
		if i < 0:
			continue
		if not _touches(game, i, c.id):
			continue
		var ready := Works.ready_turn(game, work)
		if ready == Works.NO_DATE or ready > last:
			continue
		var pair := Vector2i(0, 0) if work.action == Works.CLEAR else Vector2i(work.family, work.level_to)
		out.append({"i": i, "pair": pair, "ready": ready, "id": work.id, "work": work})
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
		var from_people := int(from_base["people"])
		var to_people := int(to_base["people"])
		if int(from_base["family"]) == Economy.SETTLEMENTS:
			rec["town"] = int(rec["town"]) - from_people
		else:
			rec["rest"] = int(rec["rest"]) - from_people
		if int(to_base["family"]) == Economy.SETTLEMENTS:
			rec["town"] = int(rec["town"]) + to_people
		else:
			rec["rest"] = int(rec["rest"]) + to_people


## Whether two bases hold the same numbers.
static func _same(a: Dictionary, b: Dictionary) -> bool:
	for key: String in Economy.BASE_FIELDS:
		if a[key] != b[key]:
			return false
	return a["good"] == b["good"] and a["people"] == b["people"] and a["staffing"] == b["staffing"] and a["a0"] == b["a0"]


## A hex's base in `view`; the game's own state reads the DistrictCache.
static func _base(game: Game, view: StateView, i: int, own: bool, memo: Dictionary) -> Dictionary:
	var key := i if own else _signature(game, view, i)
	if memo.has(key):
		return memo[key]
	var base: Dictionary = game.districts.base_of(game, i) if own else Economy.district_base(game, view, game.map.hex_of(i))
	memo[key] = base
	return base


## A negative key that stands for everything a hex's base reads from a view: the piece and the people of the hex and the six
## round it (the owner never changes within a version). The same numbers in another view (the next season's, an option's)
## share one base instead of working it out again.
static func _signature(game: Game, view: StateView, i: int) -> int:
	var h := i + 1
	h = h * 1000003 + view.main_use_at(i)
	h = h * 1000003 + view.level_at(i)
	h = h * 1000003 + view.people_at(i)
	for j: int in Economy.ring_of(game.map, i):
		if j >= 0:
			h = h * 1000003 + view.main_use_at(j)
			h = h * 1000003 + view.level_at(j)
			h = h * 1000003 + view.people_at(j)
		else:
			h = h * 1000003 - 1
	return -1 - (h & 0x3FFFFFFFFFFFFFFF)


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
static func _step(game: Game, c: Country, tax: int, rec: Dictionary, view: StateView, stock: PackedInt32Array, lists: bool,
		army: Dictionary = {}) -> Dictionary:
	var needs := EconomySeason.needs_for(game, int(rec["town"]), int(army.get("food", 0)))
	var prices := Economy.market_prices(game, view, Economy.market_of(game, c.tag), stock)
	var made: PackedInt32Array = rec["made"]
	var step := EconomySeason.goods_step(game, needs, EconomySeason.reserve_for(game, needs), stock, made, prices)
	var info := {"made": made, "dues": rec["dues"], "upkeep": rec["upkeep"], "upkeep_count": rec["upkeep_count"],
		"walls": rec["walls"]}
	if not lists:
		info["dues"] = [{"hex": Treasury.NO_HEX, "amount": int(rec["dues_sum"])}]
		info["walls"] = [{"hex": Treasury.NO_HEX, "amount": int(rec["walls_sum"])}]
	var lines := EconomySeason.money_lines(game, view, c.tag, tax, int(step["content"]), int(step["sales_milli"]), info,
		int(rec["town"]), int(rec["rest"]), int(army.get("upkeep", 0)), int(army.get("count", 0)))
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
		"town": rec["town"], "rest": rec["rest"], "tax": tax, "fed": int((step["satisfaction"] as Dictionary)["food"]),
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
		"fams": _families(game.defs), "view": StateView.of(game.state),
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


## The families of the defs by id (index 0, no piece, is null).
static func _families(defs: GameDefs) -> Array[FamilyDef]:
	var out: Array[FamilyDef] = []
	for id: int in FamilyIds.COUNT:
		out.append(defs.family(id))
	return out


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
