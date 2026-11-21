## The Economy page's "This season" tab (docs/architecture/m4-build-spec.md 5.6 and 6.7): the closed ledger of the last
## season in the page's words, the season in play (EconomyPreview.expected, calm weather), the tax levels and what the
## land earns and costs most. Own country only, so nothing here is banded or hidden. Pure core/views/ code: it reads the
## game and never writes it, calls no engine, reads no Settings and draws no luck. Both measures (5.0 R2) are
## returned: `expected` holds the treasury's `net` and the realm's `realm`; the shell picks the one it shows.
## Cached in game.view_cache by [&"study_economy", version, turn, tag].
class_name StudyEconomy
extends RefCounted

## Entries in Earns most and Costs most.
const TOP := 3
## Seasons in the chart.
const CHART_SEASONS := 12
## A season whose spending is over this share (percent) of its income is marked on the chart.
const MARK_PERCENT := 25
## Seasons of a year: the Districts tab's four seasons from now, the Goods tab's made and used a year.
const YEAR := 4
## The spans the pages chart, in seasons.
const SPANS: Array[int] = [12, 40]
## `lasts` values: the stock is 0 and the need is not met this season; a need met over the whole run; a good no town needs.
const LASTS_NONE_LEFT := 0
const LASTS_OVER := 99
const LASTS_NOT_NEEDED := 999


## {date (the season in play, "Spring 1480"), turn (the season in play), has_season (a season has ended), closed_turn,
## closed_date ("" before any season ended), money_in: {total, lines: [{label, amount, hex}]}, money_out (the same, the
## amounts negative), left_over (in + out), spending ({total, lines}: works and refunds, negative when spent),
## change (closing - opening of the closed season: all lines, the console's too), expected: {net, realm, lines},
## tax: {level, options: [{level, label, change (expected net at that level - now), realm_change, note}]},
## earns_most / costs_most (up to three {label, amount, hex}), chart: {treasury, change, labels, marks: [{index, text,
## tone}]}}. An unknown or dead country, a map-only game or one without goods gives has_season false and nothing else.
static func this_season(game: Game, tag: StringName) -> Dictionary:
	if game == null or game.view_cache == null:
		return _empty(game)
	var key: Array = [&"study_economy", game.version, game.turn, tag]
	var cached := game.view_cache.get_or_make(key, func() -> Dictionary: return _build(game, tag)) as Dictionary
	return cached.duplicate(true)  # the cache is shared: a caller gets its own copy


## The page's name of a ledger line: "Taxes on people", "Port dues, Genoa (8, 13)", "Works, near Savona (7, 12)".
static func line_label(game: Game, line: Dictionary) -> String:
	var why: StringName = line["why"]
	var hex: Vector2i = line["hex"]
	var where := Words.place(game, hex) if hex != Treasury.NO_HEX else ""
	match why:
		&"tax_people":
			return "Taxes on people"
		&"tax_goods":
			return "Taxes on goods sold"
		&"port_dues":
			return "Port dues, %s" % where if where != "" else "Port dues"
		&"upkeep_districts":
			return "Upkeep of districts"
		&"upkeep_walls":
			return "Walls, %s" % where if where != "" else "Walls"
		&"work":
			return "Works, %s" % where if where != "" else "Works"
		&"refund":
			return "Refund, %s" % where if where != "" else "Refund"
		&"upkeep_army":
			return "Army upkeep"
		&"raise":
			return "Raised, %s" % where if where != "" else "Raised"
		&"dev":
			return "Console"
	return String(why)


## `lines` (ledger lines) as [{label, amount, hex}], in their order.
static func entries(game: Game, lines: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line: Dictionary in lines:
		out.append({"label": line_label(game, line), "amount": int(line["amount"]), "hex": line["hex"]})
	return out


static func _empty(game: Game) -> Dictionary:
	var turn := game.turn if game != null else 0
	var date := Calendar.date_text(turn, game.start_year) if game != null else ""
	return {
		"date": date, "turn": turn, "has_season": false, "closed_turn": 0, "closed_date": "",
		"money_in": _group([] as Array[Dictionary]), "money_out": _group([] as Array[Dictionary]), "left_over": 0,
		"spending": _group([] as Array[Dictionary]), "change": 0,
		"expected": {"net": 0, "realm": 0, "lines": [] as Array[Dictionary]},
		"tax": {"level": 1, "options": [] as Array[Dictionary]},
		"earns_most": [] as Array[Dictionary], "costs_most": [] as Array[Dictionary],
		"chart": {"treasury": PackedInt32Array(), "change": PackedInt32Array(), "labels": [] as Array[String],
			"marks": [] as Array[Dictionary]},
	}


static func _group(lines: Array[Dictionary]) -> Dictionary:
	var total := 0
	for line: Dictionary in lines:
		total += int(line["amount"])
	return {"total": total, "lines": lines}


static func _build(game: Game, tag: StringName) -> Dictionary:
	var out := _empty(game)
	var c := Countries.by_tag(game, tag)
	if c == null or not c.alive or game.defs == null or game.defs.goods.is_empty():
		return out
	var closed := c.ledger_closed
	if not closed.is_empty():
		out["has_season"] = true
		out["closed_turn"] = int(closed["turn"])
		out["closed_date"] = Calendar.date_text(int(closed["turn"]), game.start_year)
		out["change"] = int(closed["closing"]) - int(closed["opening"])
		var ins: Array[Dictionary] = []
		var outs: Array[Dictionary] = []
		var spent: Array[Dictionary] = []
		for line: Dictionary in closed["lines"]:
			var why: StringName = line["why"]
			if Treasury.SPENDING.has(why):
				spent.append(line)
			elif why != &"dev":
				(ins if int(line["amount"]) >= 0 else outs).append(line)
		out["money_in"] = _group(entries(game, ins))
		out["money_out"] = _group(entries(game, outs))
		out["spending"] = _group(entries(game, spent))
		out["left_over"] = int((out["money_in"] as Dictionary)["total"]) + int((out["money_out"] as Dictionary)["total"])
	var now := EconomyPreview.expected(game, tag)
	var net := int(now.get("net", 0))
	out["expected"] = {"net": net, "realm": int(now.get("realm", 0)),
		"lines": entries(game, now.get("lines", []) as Array)}
	out["tax"] = _tax(game, tag, c.tax, net, int(now.get("realm", 0)))
	var worth := EconomyPreview.worth_by_hex(game, tag)
	out["earns_most"] = _top(worth, "worth")
	out["costs_most"] = _top(worth, "upkeep")
	out["chart"] = _chart(game, c)
	return out


## The three levels: each one's change of the season's net against the level now.
static func _tax(game: Game, tag: StringName, level: int, net: int, realm: int) -> Dictionary:
	var options: Array[Dictionary] = []
	for l: int in 3:
		var change := 0
		var realm_change := 0
		if l != level:
			var list: Array = EconomyPreview.with(game, tag, {"tax": l}, 1)["seasons"]
			if not list.is_empty():
				change = int((list[0] as Dictionary)["net"]) - net
				realm_change = int((list[0] as Dictionary)["realm"]) - realm
		var note := "%s: as now" % Words.tax_name(l) if l == level \
				else "%s: %s a season" % [Words.tax_name(l), Words.signed_ducats(change)]
		note += _people_note(game, l, level)
		options.append({"level": l, "label": Words.tax_name(l), "change": change, "realm_change": realm_change,
			"note": note})
	return {"level": level, "options": options}


## "; people grow 0.5 % a season, not 1 %." (a level other than now), "; people grow 1 % a season." (the level now): the
## people's growth at a tax level, from the definitions' growth_bp.
static func _people_note(game: Game, l: int, level: int) -> String:
	if game.defs == null or game.defs.growth_bp.size() < 3:
		return ""
	if l == level:
		return "; people grow %s a season." % _percent(game.defs.growth_bp[l])
	return "; people grow %s a season, not %s." % [_percent(game.defs.growth_bp[l]), _percent(game.defs.growth_bp[clampi(level, 0, 2)])]


## Basis points as a percent: 50 -> "0.5 %", 100 -> "1 %", 125 -> "1.25 %".
static func _percent(bp: int) -> String:
	var text := str(floori(bp / 100.0))
	if bp % 100 != 0:
		text += "." + ("%02d" % (bp % 100)).rstrip("0")
	return text + " %"


## Up to TOP hexes of `worth_by_hex` with the most `field` (> 0), ties by hex (row, then column).
static func _top(worth: Array[Dictionary], field: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for entry: Dictionary in worth:
		if int(entry[field]) > 0:
			list.append(entry)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a[field]) != int(b[field]):
			return int(a[field]) > int(b[field])
		var ha: Vector2i = a["hex"]
		var hb: Vector2i = b["hex"]
		return ha.y < hb.y or (ha.y == hb.y and ha.x < hb.x))
	var out: Array[Dictionary] = []
	for entry: Dictionary in list.slice(0, TOP):
		out.append({"label": entry["label"], "amount": int(entry[field]), "hex": entry["hex"]})
	return out


## The last CHART_SEASONS seasons: the treasury after each, the change each season made, the date, and the seasons whose
## spending was over a quarter of their income.
static func _chart(game: Game, c: Country) -> Dictionary:
	var chart := {"treasury": PackedInt32Array(), "change": PackedInt32Array(), "labels": [] as Array[String],
		"marks": [] as Array[Dictionary]}
	var stats := game.stats
	if stats == null or stats.count == 0:
		return chart
	var span := CHART_SEASONS + 1
	var treasury := stats.series(c.tag, "treasury", span)
	var people := stats.series(c.tag, "income_people", span)
	var goods := stats.series(c.tag, "income_goods", span)
	var dues := stats.series(c.tag, "income_dues", span)
	var spending := stats.series(c.tag, "spending", span)
	if treasury.is_empty():
		return chart
	var first_turn := stats.last_turn - treasury.size() + 1
	var from := 0
	var before := Treasury.start_amount(game, c.tag)
	if treasury.size() == span:
		before = treasury[0]
		from = 1
	var shown := PackedInt32Array()
	var change := PackedInt32Array()
	var labels: Array[String] = []
	var marks: Array[Dictionary] = []
	for k: int in range(from, treasury.size()):
		shown.append(treasury[k])
		change.append(treasury[k] - before)
		before = treasury[k]
		var date := Calendar.date_text(first_turn + k, game.start_year)
		labels.append(date)
		var income := people[k] + goods[k] + dues[k]
		if spending[k] > 0 and spending[k] * 100 > income * MARK_PERCENT:
			marks.append({"index": labels.size() - 1, "text": "%s: works" % date, "tone": &"warn"})
	chart["treasury"] = shown
	chart["change"] = change
	chart["labels"] = labels
	chart["marks"] = marks
	return chart


# --- the Insights pages: Districts, Goods, History (docs/architecture/m4-5-build-spec.md 4.3 to 4.5, 5.6) -------------


## The words of the piece on `hex`: "walled town, port", "vineyard, second stage", "castle", "town"; "" for wild land, the
## sea or a hex off the map. A settlement that is a port adds ", port".
static func piece_words(game: Game, hex: Vector2i) -> String:
	if game == null or game.map == null or game.state == null or not game.map.has(hex):
		return ""
	var i := game.map.index_of(hex)
	if game.map.land[i] == 0 or i >= game.state.main_use.size():
		return ""
	return _piece_words_at(game, i)


static func _piece_words_at(game: Game, i: int) -> String:
	var f := int(game.state.main_use[i])
	if f <= 0 or f >= FamilyIds.COUNT:
		return ""
	var level := int(game.state.level[i])
	var family := FamilyIds.NAMES[f]
	var text := ""
	if HexCard.LEVEL_WORDS.has(family):
		var words: Array = HexCard.LEVEL_WORDS[family]
		text = str(words[clampi(level, 0, words.size() - 1)])
	else:
		text = "%s, %s" % [family, HexCard.word(HexCard.STAGE_WORDS, level)]
	if int(game.districts.ints_of(game, i)[i * DistrictCache.FIELDS + Economy.F_PORT]) > 0:
		text += ", port"
	return text


## What the work under way on a hex does, for the Districts "What" column: "to city", "to second stage", "clearing the
## vineyard", "vineyard, first stage" (a build).
static func work_words(game: Game, work: Work) -> String:
	if work.action != Works.UPGRADE:
		return WorksView.label(game, work)
	var family := FamilyIds.NAMES[clampi(work.family, 0, FamilyIds.COUNT - 1)]
	if HexCard.LEVEL_WORDS.has(family):
		var words: Array = HexCard.LEVEL_WORDS[family]
		return "to %s" % str(words[clampi(work.level_to, 0, words.size() - 1)])
	return "to %s" % HexCard.word(HexCard.STAGE_WORDS, work.level_to)


## "22 fish · dues 114": the loads by good id, then the port dues; "" for nothing.
static func gives_words(game: Game, loads: PackedInt32Array, dues: int) -> String:
	var parts := PackedStringArray()
	for g: int in mini(loads.size(), game.defs.goods.size()):
		if loads[g] > 0:
			parts.append(Words.loads(loads[g], game.defs.goods[g].name))
	if dues > 0:
		parts.append("dues %s" % Words.number(dues))
	return " · ".join(parts)


## The Districts tab (spec 4.3): {has_land, date (the season in play), rows (a district, a town or a castle each, "A year"
## highest first, ties by hex index: {id (hex index), hex, place, what (the piece, then " · under way: to city, ready
## Winter 1483"), work (WorksView.at, {} for none), gives ("22 fish · dues 114"), season (the worth of the season in
## play), year (the four seasons), upkeep (negative, the four seasons of upkeep and walls), seasons (the four worths, the
## season in play first)}), wild ({count, gives, year}: the land with no piece, in one line), total_year (all the land;
## every place rounded down)}. For the PLAYER's tag only (your land): another country's tag, in a game with countries, gives
## the empty shape (has_land false, no rows), never exact figures. Cached in game.view_cache by [&"study_districts", version, tag].
static func districts(game: Game, tag: StringName) -> Dictionary:
	if game == null or game.view_cache == null or game.state == null:
		return _empty_districts(game)
	if _foreign(game, tag):
		return _empty_districts(game)
	var key: Array = [&"study_districts", game.version, tag]
	var cached := game.view_cache.get_or_make(key, func() -> Dictionary: return _build_districts(game, tag)) as Dictionary
	return cached.duplicate(true)  # the cache is shared: a caller gets its own copy


## Whether `tag` is not the player's country in a game with countries (Districts, Goods and History show your land only).
static func _foreign(game: Game, tag: StringName) -> bool:
	return game.has_countries() and tag != game.player


static func _empty_districts(game: Game) -> Dictionary:
	return {
		"has_land": false, "date": Calendar.date_text(game.turn, game.start_year) if game != null else "",
		"rows": [] as Array[Dictionary], "wild": {"count": 0, "gives": "", "year": 0}, "total_year": 0,
	}


static func _build_districts(game: Game, tag: StringName) -> Dictionary:
	var out := _empty_districts(game)
	var c := Countries.by_tag(game, tag)
	if c == null or not c.alive or game.defs == null or game.defs.goods.is_empty() or c.stock.size() != game.defs.goods.size():
		return out
	var ws := EconomyPreview.worth_seasons_shared(game, tag, YEAR)
	var hexes: PackedInt32Array = ws["hexes"]
	if hexes.is_empty():
		return out
	out["has_land"] = true
	var worth: PackedInt32Array = ws["worth"]
	var upkeep: PackedInt32Array = ws["upkeep"]
	var dues: PackedInt32Array = ws["dues"]
	var loads: PackedInt32Array = ws["goods"]
	var goods_n := game.defs.goods.size()
	var cache := game.districts
	var rows: Array[Dictionary] = []
	var wild_count := 0
	var wild_year := 0
	var wild_loads := PackedInt32Array()
	wild_loads.resize(goods_n)
	var total := 0
	for h: int in hexes.size():
		var i := hexes[h]
		var at := h * YEAR
		var seasons := worth.slice(at, at + YEAR)
		var year := 0
		for k: int in YEAR:
			year += seasons[k]
		total += year
		if int(game.state.main_use[i]) <= 0 or int(game.state.main_use[i]) >= FamilyIds.COUNT:
			wild_count += 1
			wild_year += year
			var wild_good := cache.ints_of(game, i)[i * DistrictCache.FIELDS + Economy.F_WILD_GOOD]
			var worked := _has_work(game, i)
			for k: int in YEAR:  # a wild hex gives its cover's good, or what its work will (the rare case: every good)
				if wild_good >= 0 and not worked:
					wild_loads[wild_good] += loads[(at + k) * goods_n + wild_good]
				elif worked:
					for g: int in goods_n:
						wild_loads[g] += loads[(at + k) * goods_n + g]
			continue
		var hex := game.map.hex_of(i)
		var made := PackedInt32Array()
		made.resize(goods_n)
		var due := 0
		var cost := 0
		for k: int in YEAR:
			due += dues[at + k]
			cost += upkeep[at + k]
			for g: int in goods_n:
				made[g] += loads[(at + k) * goods_n + g]
		var work := WorksView.at(game, hex)
		var what := _piece_words_at(game, i)
		if not work.is_empty():
			what += " · under way: %s, ready %s" % [work_words(game, game.state.work_at(hex)), work["ready"]]
		rows.append({
			"id": i, "hex": hex, "place": Words.place(game, hex), "what": what, "work": work,
			"gives": gives_words(game, made, due), "season": seasons[0], "year": year, "upkeep": -cost, "seasons": seasons,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["year"]) > int(b["year"]) or (int(a["year"]) == int(b["year"]) and int(a["id"]) < int(b["id"])))
	out["rows"] = rows
	out["wild"] = {"count": wild_count, "gives": gives_words(game, wild_loads, 0), "year": wild_year}
	out["total_year"] = total
	return out


static func _has_work(game: Game, i: int) -> bool:
	return game.state.work_at(game.map.hex_of(i)) != null


## The loads of the needs `food`, `wine`, `salt`, `oil` and the run of them over the next WINDOW seasons: {lasts: {good id ->
## {value, text}}, need: {good id -> loads a season}}. Cached by [&"study_lasts", version, tag].
static func _lasts_data(game: Game, tag: StringName) -> Dictionary:
	var key: Array = [&"study_lasts", game.version, tag]
	return game.view_cache.get_or_make(key, func() -> Dictionary: return _make_lasts(game, tag)) as Dictionary


static func _make_lasts(game: Game, tag: StringName) -> Dictionary:
	var out: Dictionary = {"lasts": {}, "need": {}}
	var c := Countries.by_tag(game, tag)
	if c == null or not c.alive or game.defs == null or game.defs.goods.is_empty() or c.stock.size() != game.defs.goods.size():
		return out
	var seasons: Array = EconomyPreview.with(game, tag, {}, Reminders.WINDOW)["seasons"]
	if seasons.is_empty():
		return out
	var lasts: Dictionary = out["lasts"]
	var need_of: Dictionary = out["need"]
	for g: int in game.defs.goods.size():
		lasts[g] = {"value": LASTS_NOT_NEEDED, "text": "—"}
		need_of[g] = 0
	var first_needs := EconomySeason.needs_for(game, int((seasons[0] as Dictionary)["town"]))
	for need: StringName in EconomySeason.NEEDS:
		var goods: Array[int] = []
		for g: int in game.defs.goods.size():
			var def := game.defs.goods[g]
			if (need == &"food" and def.kind == &"food") or (need != &"food" and def.key == need):
				goods.append(g)
		var short := 0
		var biggest := 0
		for k: int in seasons.size():
			var entry: Dictionary = seasons[k]
			var wanted := int(EconomySeason.needs_for(game, int(entry["town"]))[String(need)])
			biggest = maxi(biggest, wanted)
			if short == 0:
				var taken := 0
				for g: int in goods:
					taken += int((entry["used"] as PackedInt32Array)[g])
				if taken < wanted:
					short = k + 1
		var stock := 0
		for g: int in goods:
			stock += c.stock[g]
		var value := LASTS_NOT_NEEDED
		var text := "—"
		if biggest > 0:
			if short == 0:
				value = LASTS_OVER
				text = "over %d seasons" % Reminders.WINDOW
			elif short == 1:
				value = LASTS_NONE_LEFT if stock == 0 else 1
				text = "none left" if stock == 0 else "this season"
			else:
				value = short
				text = "in %d seasons" % short
		for g: int in goods:
			lasts[g] = {"value": value, "text": text}
			need_of[g] = int(first_needs[String(need)])
	return out


## How long each good lasts (spec D5): good id -> {value, text}, from `EconomyPreview.with(game, tag, {}, 8)`, the run the
## money reminder makes. The first season k (1 to 8) whose need is not fully met: "none left" (value 0: k is 1 and the
## stock is 0), "this season" (1), "in k seasons" (k), "over 8 seasons" (LASTS_OVER) and "—" (LASTS_NOT_NEEDED) for a good
## no town needs. Fish and grain share the food need's value. Empty for an unknown country.
static func lasts(game: Game, tag: StringName) -> Dictionary:
	if game == null or game.view_cache == null or game.defs == null:
		return {}
	return (_lasts_data(game, tag)["lasts"] as Dictionary).duplicate(true)


## The Goods tab (spec 4.4): {has_data (a season has ended), span, labels (the season titles of the series, oldest first),
## rows ({id (good id), key, name, icon, stock, change (the last season's), made_year, used_year (the last four seasons
## ended), sold_last, need (loads a season the towns want), lasts, lasts_text, makes_here (some district or wild hex of
## yours makes it in the next four seasons), note, stock_series, made_series (over the span)}: a row for every good in
## store, made or used in the span or needed, soonest to run out first, ties by good id)}. For the PLAYER's tag only:
## another country's tag gives no rows. Cached by [&"study_goods", version, tag, span].
static func goods(game: Game, tag: StringName, span: int) -> Dictionary:
	if game == null or game.view_cache == null or game.state == null:
		return {"has_data": false, "span": span, "labels": [] as Array[String], "rows": [] as Array[Dictionary]}
	if _foreign(game, tag):
		return {"has_data": false, "span": span, "labels": [] as Array[String], "rows": [] as Array[Dictionary]}
	var key: Array = [&"study_goods", game.version, tag, span]
	var cached := game.view_cache.get_or_make(key, func() -> Dictionary: return _build_goods(game, tag, span)) as Dictionary
	return cached.duplicate(true)


static func _build_goods(game: Game, tag: StringName, span: int) -> Dictionary:
	var out: Dictionary = {"has_data": false, "span": span, "labels": [] as Array[String], "rows": [] as Array[Dictionary]}
	var c := Countries.by_tag(game, tag)
	if c == null or not c.alive or game.defs == null or game.defs.goods.is_empty() or c.stock.size() != game.defs.goods.size():
		return out
	var stats := game.stats
	var have := stats != null and stats.count > 0 and stats.goods == game.defs.goods.size()
	out["has_data"] = have
	var labels: Array[String] = []
	if have:
		var n := mini(mini(span, Stats.RING), stats.count)
		for t: int in range(stats.last_turn - n + 1, stats.last_turn + 1):
			labels.append(Calendar.date_text(t, game.start_year))
	out["labels"] = labels
	var data := _lasts_data(game, tag)
	var lasts_of: Dictionary = data["lasts"]
	var need_of: Dictionary = data["need"]
	var ws := EconomyPreview.worth_seasons_shared(game, tag, YEAR)
	var totals: PackedInt32Array = ws["total"]
	var tops: PackedInt32Array = ws["top"]
	var rows: Array[Dictionary] = []
	for g: int in game.defs.goods.size():
		var def := game.defs.goods[g]
		var stock_series := stats.goods_series(tag, g, Stats.STOCK, span) if have else PackedInt32Array()
		var made_series := stats.goods_series(tag, g, Stats.MADE, span) if have else PackedInt32Array()
		var used_series := stats.goods_series(tag, g, Stats.USED, span) if have else PackedInt32Array()
		var need := int(need_of.get(g, 0))
		if c.stock[g] == 0 and need == 0 and _sum(made_series) == 0 and _sum(used_series) == 0:
			continue
		var change := 0
		var sold := 0
		if not c.goods_closed.is_empty():
			change = int((c.goods_closed["closing"] as PackedInt32Array)[g]) - int((c.goods_closed["opening"] as PackedInt32Array)[g])
			sold = -Stores.flow(c, g, &"sold", true)
		var lasts_entry: Dictionary = lasts_of.get(g, {"value": LASTS_NOT_NEEDED, "text": "—"})
		var makes := g < totals.size() and totals[g] > 0
		rows.append({
			"id": g, "key": def.key, "name": def.name, "icon": def.icon, "stock": c.stock[g], "change": change,
			"made_year": _sum(made_series.slice(maxi(made_series.size() - YEAR, 0))),
			"used_year": _sum(used_series.slice(maxi(used_series.size() - YEAR, 0))),
			"sold_last": sold, "need": need, "lasts": int(lasts_entry["value"]), "lasts_text": str(lasts_entry["text"]),
			"makes_here": makes, "note": _goods_note(game, def, need, makes, int(tops[g]) if g < tops.size() else -1),
			"stock_series": stock_series, "made_series": made_series,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["lasts"]) < int(b["lasts"]) or (int(a["lasts"]) == int(b["lasts"]) and int(a["id"]) < int(b["id"])))
	out["rows"] = rows
	return out


## The note under a good's chart: what the towns want of it, then who makes it.
static func _goods_note(game: Game, def: GoodDef, need: int, makes: bool, top: int) -> String:
	var wanted := ""
	if need > 0:
		wanted = "Your towns eat %s food a season, fish first, then grain" % Words.number(need) if def.kind == &"food" \
				else "Your towns need %s %s a season" % [Words.number(need), def.name.to_lower()]
	var maker := "none of your land makes it" if not makes or top < 0 \
			else "most of it from %s" % Words.place(game, game.map.hex_of(top))
	if wanted == "":
		return maker.left(1).to_upper() + maker.substr(1) + "."
	return "%s; %s." % [wanted, maker]


static func _sum(values: PackedInt32Array) -> int:
	var total := 0
	for v: int in values:
		total += v
	return total


## The Economy History tab (spec 4.5, D6 to D8; for the PLAYER's tag only, another country's tag gives no seasons and no years): {has_data (a season has ended), span, seasons (the last `span` rows of the
## ring, oldest first: {turn, title, opening (D7), closing, change, people, goods, dues, trade, upkeep, walls, army
## (the lines, positive), spending (positive when spent), other (the console's money: the change less every line),
## works ({text, hex, amount}: the works begun, amount negative, and the refunds, positive), works_missing (the season's
## spending is not all in the chronicle any more)}), years (every year row: {year, closing, land})}. The rows add up:
## people + goods + dues + trade - upkeep - walls - army - spending + other = change. Cached by [&"study_history",
## version, tag, span].
static func history(game: Game, tag: StringName, span: int) -> Dictionary:
	if game == null or game.view_cache == null or game.state == null:
		return {"has_data": false, "span": span, "seasons": [] as Array[Dictionary], "years": [] as Array[Dictionary]}
	if _foreign(game, tag):
		return {"has_data": false, "span": span, "seasons": [] as Array[Dictionary], "years": [] as Array[Dictionary]}
	var key: Array = [&"study_history", game.version, tag, span]
	var cached := game.view_cache.get_or_make(key, func() -> Dictionary: return _build_history(game, tag, span)) as Dictionary
	return cached.duplicate(true)


static func _build_history(game: Game, tag: StringName, span: int) -> Dictionary:
	var out: Dictionary = {"has_data": false, "span": span, "seasons": [] as Array[Dictionary], "years": [] as Array[Dictionary]}
	var stats := game.stats
	var c := Countries.by_tag(game, tag)
	if stats == null or c == null or stats.index_of(tag) < 0 or stats.count == 0:
		return out
	out["has_data"] = true
	var n := mini(mini(span, Stats.RING), stats.count)
	var first := stats.last_turn - n + 1
	var works := _works_by_turn(game, tag, first)
	var seasons: Array[Dictionary] = []
	for t: int in range(first, stats.last_turn + 1):
		var row := stats.row(tag, t)
		if row.is_empty():
			continue
		var people := row[Stats.column("income_people")]
		var goods := row[Stats.column("income_goods")]
		var dues := row[Stats.column("income_dues")]
		var trade := row[Stats.column("income_trade")]
		var upkeep := row[Stats.column("upkeep_districts")]
		var walls := row[Stats.column("upkeep_walls")]
		var army := row[Stats.column("upkeep_army")]
		var spending := row[Stats.column("spending")]
		var closing := row[Stats.column("treasury")]
		var lines := people + goods + dues + trade - upkeep - walls - army - spending
		var opening := stats.value(tag, t - 1, "treasury") if stats.has_row(t - 1) else closing - lines  # D7
		var list: Array[Dictionary] = works.get(t, [] as Array[Dictionary])
		var listed := 0
		for w: Dictionary in list:
			listed += int(w["amount"])
		seasons.append({
			"turn": t, "title": Calendar.date_text(t, game.start_year), "opening": opening, "closing": closing,
			"change": closing - opening, "people": people, "goods": goods, "dues": dues, "trade": trade, "upkeep": upkeep,
			"walls": walls, "army": army, "spending": spending, "other": closing - opening - lines, "works": list,
			"works_missing": spending != 0 and listed != -spending,
		})
	out["seasons"] = seasons
	var years: Array[Dictionary] = []
	for y: int in stats.year_count():
		var row := stats.year_row(tag, y)
		if not row.is_empty():
			years.append({"year": game.start_year + y, "closing": row[Stats.column("treasury")], "land": row[Stats.column("land")]})
	out["years"] = years
	return out


## The works the chronicle holds for `tag` from turn `first` on, by turn: {turn -> [{text, hex, amount}]}, in the
## chronicle's order: "Begun: walled town to city, Genoa (8, 13)" (amount -paid) and "Refund: ..." (+refund).
static func _works_by_turn(game: Game, tag: StringName, first: int) -> Dictionary:
	var out: Dictionary = {}
	var entries := game.chronicle.entries
	var start := entries.size()
	while start > 0 and int(entries[start - 1].get("turn", 0)) >= first:
		start -= 1
	for n: int in range(start, entries.size()):
		var entry: Dictionary = entries[n]
		var kind := str(entry.get("kind", ""))
		if (kind != "work_started" and kind != "work_cancelled") or str(entry.get("tag", "")) != String(tag):
			continue
		var work := Work.from_dict(entry.get("work", {}) as Dictionary)
		var at: Variant = entry.get("hex", null)
		if work == null or typeof(at) != TYPE_VECTOR2I:
			continue
		var amount := -work.paid if kind == "work_started" else int(entry.get("refund", 0))
		if kind == "work_cancelled" and amount <= 0:
			continue
		var turn := int(entry.get("turn", 0))
		if not out.has(turn):
			out[turn] = [] as Array[Dictionary]
		(out[turn] as Array[Dictionary]).append({
			"text": "%s: %s, %s" % ["Begun" if kind == "work_started" else "Refund", WorksView.label(game, work),
				Words.place(game, at as Vector2i)],
			"hex": at as Vector2i, "amount": amount,
		})
	return out
