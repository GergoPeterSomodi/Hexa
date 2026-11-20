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
		options.append({"level": l, "label": Words.tax_name(l), "change": change, "realm_change": realm_change,
			"note": note})
	return {"level": level, "options": options}


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
