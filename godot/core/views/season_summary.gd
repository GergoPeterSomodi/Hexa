## The season report's content for one country (docs/architecture/m3-build-spec.md 4.9, 5.6; style spec 6.4): what the
## season that ended brought, as sections of lines. Built from the saved chronicle, action log, stats and works, so the
## report of a loaded game equals the live one. M4 (docs/architecture/m4-build-spec.md 4.19) adds the money: the Treasury
## and Goods sections and the glance's chips come from the country's closed ledger and closed goods of that season (only
## the last closed season has them; an older report has no money sections), Standing from the stats and the known
## countries' closed ledgers. Pure core/views/ code: reads the game, writes nothing.
class_name SeasonSummary
extends RefCounted

@warning_ignore_start("integer_division")

const SECTIONS: Array[StringName] = [&"glance", &"before", &"treasury", &"goods", &"works", &"people", &"armies",
	&"war", &"orders", &"befell", &"standing"]
## Toast kinds dropped while a season runs (the report says them): M3 raises none; M6 adds the hunger and the losses; M7 the
## battles, captures, lifts and peaces (SummaryWar says them).
const COVERED: Array[String] = ["work_finished", "work_cancelled", "owners_changed", "goods_short", "army_starved", "unit_lost",
	"battle_ended", "district_captured", "siege_lifted", "peace_made"]
const SHOWN := 6
const BEFORE_SHOWN := 5
const TOP := 3
## The order kinds, in the order their lines come.
const ORDER_KINDS: Array[String] = ["build", "upgrade", "clear", "cancel_work", "choose_country", "set_tax"]
## The order of the Treasury section's lines (by reason).
const MONEY_ORDER: Array[StringName] = [&"tax_people", &"tax_goods", &"port_dues", &"upkeep_districts", &"upkeep_walls",
	&"upkeep_army", &"work", &"refund", &"raise", &"dev"]
## A season is quiet in money when the treasury moved less than this many permille of its opening and no stock moved by
## QUIET_PERCENT of its opening.
const QUIET_PERMILLE := 20
const QUIET_PERCENT := 2
## Goods chips of the glance (at most), and the chips of the glance in all.
const GLANCE_GOODS := 3
const GLANCE_CHIPS := 5


## {turn, title, next, lede, seal_letter, quiet, serious, swing_permille, toast, sections}; {} when turn < 1 or turn >=
## game.turn. Cached in game.view_cache by [&"summary", game.version, turn, tag].
static func of(game: Game, tag: StringName, turn: int) -> Dictionary:
	if game == null or game.state == null or turn < 1 or turn >= game.turn:
		return {}
	var key: Array = [&"summary", game.version, turn, tag]
	var cached := game.view_cache.get_or_make(key, func() -> Dictionary: return _build(game, tag, turn)) as Dictionary
	return cached.duplicate(true)  # the cache is shared: a caller gets its own copy


static func _build(game: Game, tag: StringName, turn: int) -> Dictionary:
	var memo := {}
	var mine_works: Array[Dictionary] = []
	var befell: Array[Dictionary] = []
	var started: Dictionary = {}
	var cancelled: Dictionary = {}
	var counts := {"work_finished": 0, "work_started": 0, "work_cancelled": 0}
	for entry: Dictionary in game.chronicle.of_turn(turn):
		var kind := str(entry.get("kind", ""))
		var work := _work_of(entry)
		var is_mine := StringName(str(entry.get("tag", ""))) == tag and kind.begins_with("work_")
		if is_mine and work != null:
			counts[kind] = int(counts[kind]) + 1
			if kind == "work_started":
				started[work.hex] = work
			elif kind == "work_cancelled":
				cancelled[work.hex] = work
			var line := LogLines.line_of(game, entry, tag, memo)
			if not line.is_empty():
				var work_line := _from_log(line, work.seasons)
				if kind == "work_finished":
					work_line["detail"] = _brings(game, tag, work)
				mine_works.append(work_line)
		elif kind == "owners_changed" or kind == "tax_set" or kind.begins_with("work_"):
			var line := LogLines.line_of(game, entry, tag, memo)
			if not line.is_empty() and not bool(line["mine"]):  # one's own land is the Land chip's
				befell.append(_from_log(line, 0))
	var order_lines := _orders(game, tag, turn, started, cancelled)
	var armies := SummaryArmies.of(game, tag, turn)
	order_lines.append_array(SummaryArmies.orders(game, tag, turn))
	befell.append_array(SummaryArmies.witnessed(game, tag, turn))
	var war := SummaryWar.of(game, tag, turn)
	order_lines.append_array(SummaryWar.orders(game, tag, turn))
	befell.append_array(SummaryWar.witnessed(game, tag, turn))
	var land := _land(game, tag, turn)
	var finished := int(counts["work_finished"])
	var begun := int(counts["work_started"])
	var stopped := int(counts["work_cancelled"])
	var money := _money(game, tag, turn, started, cancelled)
	var people := SummaryPeople.of(game, tag, turn)
	var quiet := finished + begun + stopped == 0 and order_lines.is_empty() and befell.is_empty() \
			and int(land["delta"]) == 0 and bool(money.get("quiet", true)) and bool(people["quiet"]) \
			and bool(armies["quiet"]) and bool(war["quiet"])
	var news := not befell.is_empty()
	befell.append_array(armies["sight"] as Array[Dictionary])  # foreign armies in sight: not news of the season
	# Reminders are of the season in play: only the report of the season that just closed carries them.
	var reminders: Array[Dictionary] = []
	if turn == game.turn - 1:
		reminders = Reminders.unfinished(game, tag)
	var serious := false
	var before: Array[Dictionary] = []
	for r: Dictionary in reminders:
		serious = serious or int(r["severity"]) >= 2
		if before.size() < BEFORE_SHOWN:
			before.append(_reminder_line(r))
	var under_way := _under_way(game, tag, turn)
	var by_id := {
		&"glance": _glance(game, tag, turn, quiet, finished, land, money, people, armies, war["chips"]),
		&"before": _section(&"before", "Before %s" % Calendar.season_name(turn + 1), before, false),
		&"works": _section(&"works", "Works", mine_works + under_way, true),
		&"orders": _section(&"orders", "Your orders", order_lines, false),
		&"befell": _section(&"befell", _befell_title(game, tag), befell, false),
	}
	if not (people["section"] as Dictionary).is_empty():
		by_id[&"people"] = people["section"]
	if not (armies["section"] as Dictionary).is_empty():
		by_id[&"armies"] = armies["section"]
	if not (war["section"] as Dictionary).is_empty():
		by_id[&"war"] = war["section"]
	if not money.is_empty():
		by_id[&"treasury"] = money["treasury"]
		by_id[&"goods"] = money["goods"]
		by_id[&"standing"] = _standing(game, tag, turn, money)
	if quiet:
		for id: StringName in [&"works", &"treasury", &"goods", &"people", &"armies", &"war", &"standing"]:
			by_id.erase(id)
	var sections: Array[Dictionary] = []
	for id: StringName in SECTIONS:
		if by_id.has(id) and (id == &"glance" or not ((by_id[id] as Dictionary)["lines"] as Array).is_empty()
				or not ((by_id[id] as Dictionary)["total"] as Dictionary).is_empty()):
			sections.append(by_id[id])
	_mark_top(sections)
	var title := Calendar.date_text(turn, game.start_year)
	var next := Calendar.date_text(turn + 1, game.start_year)
	return {
		"turn": turn, "title": title, "next": next, "lede": _lede(game, tag, quiet, next),
		"seal_letter": _seal(game, tag), "quiet": quiet, "serious": serious,
		"swing_permille": absi(int(money["change"])) * 1000 / maxi(1, absi(int(money["opening"]))) if not money.is_empty() else 0,
		"toast": _toast(title, quiet, [finished, begun, stopped], int(land["delta"]), news, money),
		"sections": sections,
	}


# ----- the sentences around the sections -------------------------------------------------------------------------


static func _lede(game: Game, tag: StringName, quiet: bool, next: String) -> String:
	if quiet:
		return "A quiet season."
	if not game.has_countries():
		return "The sandbox of %s, seed %d. %s begins." % [game.map.id.replace("_", " ").capitalize(), game.seed_value, next]
	var def := Countries.def_of(game, tag)
	if def == null or def.ruler.is_empty():
		return "The Chancellor's report. %s begins." % next
	return "The Chancellor's report to %s. %s begins." % [def.ruler, next]


static func _seal(game: Game, tag: StringName) -> String:
	if not game.has_countries():
		return "S"
	var name := LogLines.short_name(game, tag)
	return name.left(1).to_upper() if not name.is_empty() else "?"


static func _befell_title(game: Game, tag: StringName) -> String:
	if not game.has_countries():
		return "What befell the map"
	return "What befell %s" % LogLines.short_name(game, tag)


## "Spring 1480 ended: ▲ +48 ducats. J: the report" when the season has a ledger; else (a map-only game, an older
## season) "Spring 1480 ended: 1 work finished. J: the report"; a quiet season: "... ended: a quiet season. J: the report".
static func _toast(title: String, quiet: bool, works: Array[int], land_delta: int, news: bool, money: Dictionary = {}) -> String:
	if not quiet and not money.is_empty():
		var change := int(money["change"])
		var body := "the treasury unchanged" if change == 0 else "%s %s" % ["▲" if change > 0 else "▼", Words.signed_ducats(change)]
		return "%s ended: %s. J: the report" % [title, body]
	var parts: Array[String] = []
	for i: int in 3:
		if works[i] > 0:
			parts.append("%s %s" % [Words.plural(works[i], "work", "works"), ["finished", "begun", "cancelled"][i]])
	if land_delta != 0:
		parts.append("%s %s" % [Words.plural(absi(land_delta), "district", "districts"), "gained" if land_delta > 0 else "lost"])
	var body := "a quiet season"
	if not quiet:
		body = ", ".join(PackedStringArray(parts)) if not parts.is_empty() else ("news from abroad" if news else "orders given")
	return "%s ended: %s. J: the report" % [title, body]


# ----- the sections ----------------------------------------------------------------------------------------------


static func _line(text: String, tone: String, rank: int = 0) -> Dictionary:
	return {
		"text": text, "detail": "", "amount": 0, "unit": &"", "tone": tone, "value": 0, "from": 0, "to": 0,
		"hex": WorksView.NO_HEX, "rank": rank, "top": false, "sub": false, "action": [], "action_label": "",
	}


static func _from_log(log_line: Dictionary, rank: int) -> Dictionary:
	var tone := str(log_line["tone"])
	var out := _line(str(log_line["text"]), "plain" if tone == "muted" else tone, rank)
	out["hex"] = log_line["hex"]
	return out


static func _reminder_line(r: Dictionary) -> Dictionary:
	var severity := int(r["severity"])
	var out := _line(str(r["text"]), "bad" if severity >= 2 else ("warn" if severity == 1 else "plain"))
	out["detail"] = str(r["hint"])
	out["hex"] = r["hex"]
	out["action"] = r["action"]
	out["action_label"] = str(r["action_label"])
	return out


## Sorts by rank (largest first, stable), keeps SHOWN, counts the rest in `more`.
static func _section(id: StringName, title: String, lines: Array[Dictionary], by_rank: bool) -> Dictionary:
	var ordered: Array[Dictionary] = lines.duplicate()
	if by_rank:
		var indexed: Array[Array] = []
		for i: int in ordered.size():
			indexed.append([int(ordered[i]["rank"]), i])
		indexed.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
		var sorted: Array[Dictionary] = []
		for pair: Array in indexed:
			sorted.append(ordered[int(pair[1])])
		ordered = sorted
	var shown: Array[Dictionary] = ordered.slice(0, SHOWN)
	return {"id": id, "title": title, "count": ordered.size(), "total": {}, "lines": shown,
		"more": maxi(ordered.size() - SHOWN, 0), "unchanged": ""}


## The three largest ranks of the report carry `top` (ties: the earlier line).
static func _mark_top(sections: Array[Dictionary]) -> void:
	var all: Array[Dictionary] = []
	for section: Dictionary in sections:
		for line: Dictionary in section["lines"] as Array:
			if int(line["rank"]) > 0:
				all.append(line)
	var order: Array[int] = []
	for i: int in all.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return int(all[a]["rank"]) > int(all[b]["rank"]) or (int(all[a]["rank"]) == int(all[b]["rank"]) and a < b))
	for n: int in mini(TOP, order.size()):
		all[order[n]]["top"] = true


static func _glance(game: Game, tag: StringName, turn: int, quiet: bool, finished: int, land: Dictionary,
		money: Dictionary, people: Dictionary, armies: Dictionary, war_chips: Array[Dictionary]) -> Dictionary:
	var lines: Array[Dictionary] = []
	var countries := game.has_countries()
	if quiet:
		var under := WorksView.of_country(game, tag).size()
		var text := "No works under way." if under == 0 else "%s under way; nothing else of note." % Words.plural(under, "work", "works")
		if not money.is_empty():
			var change := int(money["change"])
			text = "The treasury did not change; nothing else of note." if change == 0 else \
					"The treasury %s by %s; nothing else of note." % ["grew" if change > 0 else "fell", Words.ducats(absi(change))]
		var line := _line(text, "plain")
		if countries:
			var link := Reminders.capital_link(game, tag)
			line["hex"] = link["hex"]
			line["action"] = link["action"]
			line["action_label"] = link["action_label"]
		lines.append(line)
		return _section(&"glance", "At a glance", lines, false)
	if not money.is_empty():
		var chip := _line("Treasury", _tone_of(int(money["change"])))
		chip["detail"] = Words.number(int(money["closing"]))
		chip["amount"] = int(money["change"])
		chip["value"] = int(money["closing"])
		lines.append(chip)
	if bool(people["known"]) and int(people["change"]) != 0:
		var chip := _line("People", _tone_of(int(people["change"])))
		chip["detail"] = Words.number(int(people["to"]))
		chip["amount"] = int(people["change"])
		chip["value"] = int(people["to"])
		lines.append(chip)
	var running := WorksView.of_country(game, tag).size()
	if bool(armies["had"]):
		var army_chip := _line("Men under arms", _tone_of(int(armies["change"])))
		army_chip["detail"] = Words.number(int(armies["men"]))
		army_chip["amount"] = int(armies["change"])
		army_chip["value"] = int(armies["men"])
		lines.append(army_chip)
	for chip: Dictionary in war_chips:
		lines.append(chip)
	var works := _line("Works", "good" if finished > 0 else "plain")
	if finished > 0:
		works["detail"] = "%d finished, %d under way" % [finished, running]
	else:
		works["detail"] = "%d under way" % running if running > 0 else "no works"
	lines.append(works)
	if countries and bool(land["known"]) and int(land["delta"]) != 0:
		var chip := _line("Land", "plain")
		chip["detail"] = Words.plural(int(land["now"]), "district", "districts")
		chip["amount"] = int(land["delta"])
		chip["unit"] = &"districts"
		chip["value"] = int(land["now"])
		lines.append(chip)
	var weather := Calendar.weather_text(game, tag) if countries and turn == game.turn - 1 else ""
	var room := GLANCE_CHIPS - lines.size() - (1 if not weather.is_empty() else 0)
	if not money.is_empty():
		var shown := 0
		for row: Dictionary in money["rows"] as Array:
			if shown >= mini(GLANCE_GOODS, room):
				break
			if int(row["change"]) != 0:
				var chip := _line(str(row["name"]), _tone_of(int(row["change"])))
				chip["detail"] = Words.number(int(row["stock"]))
				chip["amount"] = int(row["change"])
				chip["value"] = int(row["stock"])
				lines.append(chip)
				shown += 1
	if not weather.is_empty():
		var chip := _line("Weather", "warn")
		chip["detail"] = weather
		lines.append(chip)
	return _section(&"glance", "At a glance", lines.slice(0, GLANCE_CHIPS), false)


static func _tone_of(amount: int) -> String:
	return "good" if amount > 0 else ("bad" if amount < 0 else "plain")


## {known, now, delta}: the land of `tag` after season `turn` and its change since the season before (0 when either row
## is missing).
static func _land(game: Game, tag: StringName, turn: int) -> Dictionary:
	var stats := game.stats
	if not game.has_countries() or stats == null or not stats.has_row(turn):
		return {"known": false, "now": 0, "delta": 0}
	var now := stats.value(tag, turn, "land")
	var delta := now - stats.value(tag, turn - 1, "land") if turn > 1 and stats.has_row(turn - 1) else 0
	return {"known": true, "now": now, "delta": delta}


## "Under way: <label>, <place>: 1 of 8 seasons. Ready Spring 1482." for the works begun in an earlier season; "stopped
## for the winter" (warn) when the season that ended halted it.
static func _under_way(game: Game, tag: StringName, turn: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for work: Work in game.state.works:
		if work.tag != tag or work.started_turn >= turn:
			continue
		var info := WorksView.at(game, work.hex)
		var halted := Works.halted(game, work, turn)
		var middle := "stopped for the winter" if halted else str(info["progress"])
		var line := _line("Under way: %s: %s. Ready %s." % [WorksView.line(game, work), middle, info["ready"]],
			"warn" if halted else "plain", work.seasons)
		line["hex"] = work.hex
		out.append(line)
	return out


# ----- orders ----------------------------------------------------------------------------------------------------


## One line a kind from the accepted actions of `turn` by `tag`, from the action log.
static func _orders(game: Game, tag: StringName, turn: int, started: Dictionary, cancelled: Dictionary) -> Array[Dictionary]:
	var items: Dictionary = {}
	var firsts: Dictionary = {}
	var i := game.action_log.size() - 1
	while i >= 0:
		var record: Dictionary = game.action_log[i]
		i -= 1
		var at := int(record.get("turn", 0))
		if at < turn:
			break
		var action := str(record.get("action", ""))
		var args: Variant = record.get("args", {})
		if at != turn or not ORDER_KINDS.has(action) or not (args is Dictionary):
			continue
		var a := args as Dictionary
		if StringName(str(a.get("tag", ""))) != tag:
			continue
		var hex: Variant = a.get("hex", null)
		var item := ""
		if action == "set_tax":
			if not items.has(action) and not Words.tax_name(int(a.get("level", -1))).is_empty():
				items[action] = [Words.tax_name(int(a["level"]))] as Array[String]  # the newest of the season
				firsts[action] = _capital(game, tag)
			continue
		if action == "choose_country":
			item = Words.country_the(game, tag)
			hex = _capital(game, tag)
		elif typeof(hex) == TYPE_VECTOR2I:
			item = _item(game, action, a, hex as Vector2i, started, cancelled)
		else:
			continue
		if not items.has(action):
			items[action] = [] as Array[String]
		(items[action] as Array[String]).push_front(item)  # the log is read newest first
		firsts[action] = hex  # ends as the oldest: the first of the kind
	var out: Array[Dictionary] = []
	for action: String in ORDER_KINDS:
		if not items.has(action):
			continue
		var list: Array[String] = items[action]
		var text := ""
		match action:
			"choose_country":
				text = "Took the rule of %s." % list[0]
			"cancel_work":
				text = "Cancelled: %s." % Words.list(list)
			"set_tax":
				text = "Set taxes to %s." % list[0]
			_:
				text = "Ordered to %s: %s." % [action, Words.list(list)]
		var line := _line(text, "plain")
		line["hex"] = firsts[action]
		out.append(line)
	return out


static func _capital(game: Game, tag: StringName) -> Vector2i:
	var c := Countries.by_tag(game, tag)
	return c.capital if c != null else WorksView.NO_HEX


## "vineyard near Savona (7, 12)"; "walled town to city at Genoa (8, 13)".
static func _item(game: Game, action: String, args: Dictionary, hex: Vector2i, started: Dictionary, cancelled: Dictionary) -> String:
	var piece := "work"
	var work: Work = null
	if action == "build" and typeof(args.get("family", null)) == TYPE_INT:
		piece = WorksView.piece_name(int(args["family"]))
	elif action == "cancel_work":
		work = cancelled.get(hex, null) as Work
	else:
		work = started.get(hex, null) as Work
	if work != null and work.action == Works.UPGRADE:
		return WorksView.line(game, work)  # "vineyard, first to second stage, near Savona (7, 12)"
	if work != null:
		piece = WorksView.piece_name(work.family)
	var where := Words.place(game, hex)
	return "%s %s" % [piece, where if where.begins_with("near ") else "at " + where]


static func _work_of(entry: Dictionary) -> Work:
	var value: Variant = entry.get("work", null)
	return Work.from_dict(value as Dictionary) if value is Dictionary else null


# ----- the money (spec 4.19) ---------------------------------------------------------------------------------------


## {} when `tag` has no closed ledger and goods of season `turn`; else {opening, closing, change, lines (the closed
## ledger's), treasury (the section), goods (the section), rows (the goods that moved, worst first), quiet}.
static func _money(game: Game, tag: StringName, turn: int, started: Dictionary, cancelled: Dictionary) -> Dictionary:
	var c := Countries.by_tag(game, tag)
	if c == null or game.defs == null or int(c.ledger_closed.get("turn", -1)) != turn \
			or int(c.goods_closed.get("turn", -1)) != turn:
		return {}
	var lines := _lines_of(c.ledger_closed)
	var opening := int(c.ledger_closed["opening"])
	var closing := int(c.ledger_closed["closing"])
	var rows := _goods_rows(game, c.goods_closed)
	var quiet := absi(closing - opening) * 1000 < QUIET_PERMILLE * maxi(1, absi(opening))
	var goods_lines: Array[Dictionary] = []
	var unchanged: Array[String] = []
	for row: Dictionary in rows:
		quiet = quiet and absi(int(row["change"])) * 100 < QUIET_PERCENT * maxi(1, int(row["opening"]))
		if bool(row["active"]):
			goods_lines.append(_goods_line(row))
		elif int(row["stock"]) > 0:
			unchanged.append(str(row["name"]).to_lower())
	var shown: Array[Dictionary] = []
	for row: Dictionary in rows:
		if int(row["change"]) != 0:
			shown.append(row)
	var goods := {"id": &"goods", "title": "Goods", "count": goods_lines.size(), "total": {}, "lines": goods_lines, "more": 0,
		"unchanged": "Unchanged: %s" % ", ".join(PackedStringArray(_in_id_order(rows, unchanged))) if not unchanged.is_empty() else ""}
	return {
		"opening": opening, "closing": closing, "change": closing - opening, "lines": lines, "rows": shown,
		"treasury": _treasury_section(game, lines, opening, closing, started, cancelled), "goods": goods, "quiet": quiet,
	}


## The ledger's lines as typed dictionaries.
static func _lines_of(ledger: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line: Variant in ledger.get("lines", []) as Array:
		out.append(line as Dictionary)
	return out


## The unchanged names in good id order (the rows are in worth order).
static func _in_id_order(rows: Array[Dictionary], names: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var by_id: Array[Dictionary] = rows.duplicate()
	by_id.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["good"]) < int(b["good"]))
	for row: Dictionary in by_id:
		if names.has(str(row["name"]).to_lower()):
			out.append(str(row["name"]).to_lower())
	return out


## The Treasury section: the total "610 → 658", a line for each reason in MONEY_ORDER (port dues and walls of every
## hex merged, a work or refund for each hex), then the two `sub` lines. No line is left out, so the lines add up to the
## total's amount (the subs are not counted).
static func _treasury_section(game: Game, lines: Array[Dictionary], opening: int, closing: int, started: Dictionary,
		cancelled: Dictionary) -> Dictionary:
	var out: Array[Dictionary] = []
	var spending := 0
	for why: StringName in MONEY_ORDER:
		var amount := 0
		var count := 0
		var hexes: Array[Vector2i] = []
		for line: Dictionary in lines:
			if line["why"] == why:
				amount += int(line["amount"])
				count += int(line["count"])
				hexes.append(line["hex"] as Vector2i)
				if Treasury.SPENDING.has(why):
					var at := line["hex"] as Vector2i
					out.append(_money_line(_spending_text(game, why, line, started, cancelled), int(line["amount"]), at))
					spending += int(line["amount"])
		if amount == 0 or Treasury.SPENDING.has(why):
			continue
		match why:
			&"tax_people":
				out.append(_money_line("Taxes on people", amount, WorksView.NO_HEX))
			&"tax_goods":
				out.append(_money_line("Taxes on goods", amount, WorksView.NO_HEX))
			&"port_dues":
				out.append(_money_line("Port dues, %s" % Words.list(_names_at(game, hexes)), amount, hexes[0]))
			&"upkeep_districts":
				out.append(_money_line("District upkeep, %s" % Words.plural(count, "district", "districts"), amount, WorksView.NO_HEX))
			&"upkeep_walls":
				out.append(_money_line("Walls of %s" % Words.list(_names_at(game, hexes)), amount, hexes[0]))
			&"upkeep_army":
				out.append(_money_line("Army upkeep, %s" % Words.plural(count, "army", "armies"), amount, WorksView.NO_HEX))
			_:
				out.append(_money_line("Developer", amount, WorksView.NO_HEX))
	var total := _line("%s → %s" % [Words.number(opening), Words.number(closing)], _tone_of(closing - opening))
	total["from"] = opening
	total["to"] = closing
	total["amount"] = closing - opening
	var main_count := out.size()
	var left := Treasury.left_over(lines)
	for pair: Array in [["Left over each season", left], ["With your spending", left + spending]]:
		var sub := _line(str(pair[0]), _tone_of(int(pair[1])))
		sub["amount"] = int(pair[1])
		sub["sub"] = true
		out.append(sub)
	return {"id": &"treasury", "title": "Treasury", "count": main_count, "total": total, "lines": out, "more": 0, "unchanged": ""}


## The text of one spending line: "Work begun: ..." or "Refund: ..." (several payments on one hex: the place and the count),
## "Raised: 2 companies at Genoa (8, 13)" for raising.
static func _spending_text(game: Game, why: StringName, line: Dictionary, started: Dictionary, cancelled: Dictionary) -> String:
	var at := line["hex"] as Vector2i
	var count := int(line["count"])
	if why == &"raise":
		return "Raised: %s at %s" % [Words.plural(count, "company", "companies"), Words.place(game, at)]
	var works := started if why == &"work" else cancelled
	if count > 1:  # several payments merged on one hex: the label would name only the last work
		return "%s: %s (%d)" % ["Works begun" if why == &"work" else "Refunds", Words.place(game, at), count]
	return "%s: %s" % ["Work begun" if why == &"work" else "Refund", _work_label(game, at, works)]


static func _money_line(text: String, amount: int, hex: Vector2i) -> Dictionary:
	var line := _line(text, _tone_of(amount), absi(amount))
	line["amount"] = amount
	line["hex"] = hex
	return line


## "vineyard, first stage, near Savona (7, 12)" of the work the chronicle has at `hex` for the season; the place alone
## when it has none.
static func _work_label(game: Game, hex: Vector2i, works: Dictionary) -> String:
	var work: Work = works.get(hex, null)
	return WorksView.line(game, work) if work != null else Words.place(game, hex)


## The names of the places at `hexes` ("Genoa"; the nearest name, or the coordinates, when a hex has no name of its own).
static func _names_at(game: Game, hexes: Array[Vector2i]) -> Array[String]:
	var out: Array[String] = []
	for hex: Vector2i in hexes:
		var place := Words.place(game, hex)
		var at := place.rfind(" (")
		out.append(place.left(at) if at > 0 else place)
	return out


## One row for each good: {good, name, stock (closing), opening, change, parts (flow words), rank_milli, flow_milli,
## active (a flow or a change)}, the worthiest first (|change| x price, then the flows' worth, then the later good).
static func _goods_rows(game: Game, closed: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var opening := closed.get("opening", PackedInt32Array()) as PackedInt32Array
	var closing := closed.get("closing", PackedInt32Array()) as PackedInt32Array
	var flows := closed.get("flows", PackedInt32Array()) as PackedInt32Array
	var count := closing.size()
	for g: int in mini(count, game.defs.goods.size()):
		var def := game.defs.goods[g]
		var parts: Array[String] = []
		var flow_milli := 0
		for f: int in Stores.FLOWS.size():
			var at := f * count + g
			var amount := flows[at] if at < flows.size() else 0
			if amount != 0:
				flow_milli += absi(amount) * def.price_milli
				parts.append("%s %s" % [_flow_word(def, f), Words.signed(amount) if Stores.FLOWS[f] == &"dev" else Words.number(absi(amount))])
		var change := closing[g] - (opening[g] if g < opening.size() else 0)
		out.append({
			"good": g, "name": def.name, "stock": closing[g], "opening": opening[g] if g < opening.size() else 0,
			"change": change, "parts": parts, "rank_milli": absi(change) * def.price_milli, "flow_milli": flow_milli,
			"active": change != 0 or not parts.is_empty(),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["rank_milli"]) != int(b["rank_milli"]):
			return int(a["rank_milli"]) > int(b["rank_milli"])
		if int(a["flow_milli"]) != int(b["flow_milli"]):
			return int(a["flow_milli"]) > int(b["flow_milli"])
		return int(a["good"]) > int(b["good"]))
	return out


## The word of a flow for a good: made (caught for fish), used (eaten for food, drunk for wine), sold, for works, back
## from works, by the developer.
static func _flow_word(def: GoodDef, flow: int) -> String:
	match Stores.FLOWS[flow]:
		&"made":
			return "caught" if def.key == &"fish" else "made"
		&"used":
			return "eaten" if def.kind == &"food" else ("drunk" if def.key == &"wine" else "used")
		&"sold":
			return "sold"
		&"work":
			return "for works"
		&"refund":
			return "back from works"
		&"army":
			return "eaten by the army"
		&"raise":
			return "for raising"
	return "by the developer"


## "Wine 3" with its change, "(drunk 1)" under it.
static func _goods_line(row: Dictionary) -> Dictionary:
	var line := _line("%s %s" % [row["name"], Words.number(int(row["stock"]))], _tone_of(int(row["change"])),
		int((int(row["rank_milli"]) + 500) / 1000))
	line["amount"] = int(row["change"])
	line["value"] = int(row["stock"])
	var parts: Array[String] = row["parts"]
	line["detail"] = "(%s)" % ", ".join(PackedStringArray(parts)) if not parts.is_empty() else ""
	return line


## "Brings wine 12 a year; upkeep 1 a season." for a finished work: the hex's calm year (its own good, or all it gives when it has none) and the season's upkeep and
## walls from district_output on the state now ("" when the hex gives and costs nothing).
static func _brings(game: Game, tag: StringName, work: Work) -> String:
	var c := Countries.by_tag(game, tag)
	if c == null or game.defs == null or game.defs.goods.is_empty() or game.state == null:
		return ""
	var view := StateView.of(game.state)
	var year := PackedInt32Array()
	year.resize(game.defs.goods.size())
	var cost := 0
	for season: int in 4:
		var put := Economy.district_output(game, view, work.hex, season, Economy.CALM, c.tax)
		var goods: PackedInt32Array = put["goods"]
		var own := int(put["good"])  # a goods district brings its own good (the wild remainder is not the work's)
		for g: int in mini(goods.size(), year.size()):
			if own < 0 or g == own:
				year[g] += goods[g]
		if season == 0:
			cost = int(put["upkeep"]) + int(put["walls"])
	var parts: Array[String] = []
	for g: int in year.size():
		if year[g] > 0:
			parts.append("%s %s" % [game.defs.goods[g].name.to_lower(), Words.number(year[g])])
	var text := "Brings %s a year" % ", ".join(PackedStringArray(parts)) if not parts.is_empty() else ""
	if cost > 0:
		text = "%s; upkeep %s a season." % [text, Words.number(cost)] if not text.is_empty() else "Upkeep %s a season." % Words.number(cost)
	elif not text.is_empty():
		text += "."
	return text


## The Standing section's lines (spec 4.19): where `tag` stands among the countries it knows in land and in income (the
## closed ledger without work, refund and dev), then a banded line for each known country, the larger land first.
static func _standing(game: Game, tag: StringName, turn: int, money: Dictionary) -> Dictionary:
	var lines: Array[Dictionary] = []
	var stats := game.stats
	if tag != &"" and stats != null and stats.has_row(turn):
		var others: Array[Dictionary] = []
		for other: StringName in Knowledge.known(game, tag):
			var c := Countries.by_tag(game, other)
			if c != null and c.alive and int(c.ledger_closed.get("turn", -1)) == turn:
				others.append({"tag": other, "land": stats.value(other, turn, "land"), "people": stats.value(other, turn, "people"),
					"army": stats.value(other, turn, "army_men"),
					"income": Treasury.left_over(_lines_of(c.ledger_closed)), "n": others.size()})
		if not others.is_empty():
			var land := stats.value(tag, turn, "land")
			var income := Treasury.left_over(money["lines"] as Array[Dictionary])
			var land_rank := 1
			var income_rank := 1
			var people := stats.value(tag, turn, "people")
			var people_rank := 1
			var army := stats.value(tag, turn, "army_men")
			var army_rank := 1
			# The men under arms are told only when a country in view has some: a world with no armies reads as before M6.
			var armed := army > 0
			for o: Dictionary in others:
				land_rank += 1 if int(o["land"]) > land else 0
				income_rank += 1 if int(o["income"]) > income else 0
				people_rank += 1 if int(o["people"]) > people else 0
				army_rank += 1 if int(o["army"]) > army else 0
				armed = armed or int(o["army"]) > 0
			if armed:
				lines.append(_line("Among the %d countries you know, you are %s in land (%s), %s in income (%s a season), %s in people (%s) and %s in men under arms (%s)." % [
					others.size() + 1, _ordinal(land_rank), Words.plural(land, "district", "districts"), _ordinal(income_rank),
					Words.signed(income), _ordinal(people_rank), Words.number(people), _ordinal(army_rank), Words.number(army)], "plain"))
			else:
				lines.append(_line("Among the %d countries you know, you are %s in land (%s), %s in income (%s a season) and %s in people (%s)." % [
					others.size() + 1, _ordinal(land_rank), Words.plural(land, "district", "districts"), _ordinal(income_rank),
					Words.signed(income), _ordinal(people_rank), Words.number(people)], "plain"))
			others.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a["land"]) > int(b["land"]) or (int(a["land"]) == int(b["land"]) and int(a["n"]) < int(b["n"])))
			for o: Dictionary in others:
				var name := LogLines.short_name(game, o["tag"] as StringName)
				if armed:
					lines.append(_line("%s: about %s districts, about %s, about %s people, about %s men." % [name,
						Words.number(Knowledge.band(int(o["land"]))), Words.signed(Knowledge.band(int(o["income"]))),
						Words.number(Knowledge.band(int(o["people"]))), Words.number(Knowledge.band(int(o["army"])))], "plain"))
				else:
					lines.append(_line("%s: about %s districts, about %s, about %s people." % [name,
						Words.number(Knowledge.band(int(o["land"]))), Words.signed(Knowledge.band(int(o["income"]))),
						Words.number(Knowledge.band(int(o["people"])))], "plain"))
	return _section(&"standing", "Standing", lines, false)


## 1st, 2nd, 3rd, 4th ... 11th, 12th, 13th, 21st.
static func _ordinal(n: int) -> String:
	var tail := n % 100
	if tail >= 11 and tail <= 13:
		return "%dth" % n
	return "%d%s" % [n, {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")]
