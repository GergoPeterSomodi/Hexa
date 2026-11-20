## The season report's content for one country (docs/architecture/m3-build-spec.md 4.9, 5.6; style spec 6.4): what the
## season that ended brought, as sections of lines. Built from the saved chronicle, action log, stats and works, so the
## report of a loaded game equals the live one. Pure core/views/ code: reads the game, writes nothing.
class_name SeasonSummary
extends RefCounted

const SECTIONS: Array[StringName] = [&"glance", &"before", &"treasury", &"goods", &"works", &"people", &"orders",
	&"befell", &"standing"]
## Toast kinds dropped while a season runs (the report says them): M3 raises none.
const COVERED: Array[String] = ["work_finished", "work_cancelled", "owners_changed"]
const SHOWN := 6
const BEFORE_SHOWN := 5
const TOP := 3
## The order kinds, in the order their lines come.
const ORDER_KINDS: Array[String] = ["build", "upgrade", "clear", "cancel_work", "choose_country"]


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
			(started if kind == "work_started" else cancelled)[work.hex] = work
			var line := LogLines.line_of(game, entry, tag, memo)
			if not line.is_empty():
				mine_works.append(_from_log(line, work.seasons))
		elif kind == "owners_changed" or kind.begins_with("work_"):
			var line := LogLines.line_of(game, entry, tag, memo)
			if not line.is_empty() and not bool(line["mine"]):  # one's own land is the Land chip's
				befell.append(_from_log(line, 0))
	var order_lines := _orders(game, tag, turn, started, cancelled)
	var land := _land(game, tag, turn)
	var finished := int(counts["work_finished"])
	var begun := int(counts["work_started"])
	var stopped := int(counts["work_cancelled"])
	var quiet := finished + begun + stopped == 0 and order_lines.is_empty() and befell.is_empty() \
			and int(land["delta"]) == 0
	var reminders := Reminders.unfinished(game, tag)
	var serious := false
	var before: Array[Dictionary] = []
	for r: Dictionary in reminders:
		serious = serious or int(r["severity"]) >= 2
		if before.size() < BEFORE_SHOWN:
			before.append(_reminder_line(r))
	var under_way := _under_way(game, tag, turn)
	var by_id := {
		&"glance": _glance(game, tag, quiet, finished, land),
		&"before": _section(&"before", "Before %s" % Calendar.season_name(turn + 1), before, false),
		&"works": _section(&"works", "Works", mine_works + under_way, true),
		&"orders": _section(&"orders", "Your orders", order_lines, false),
		&"befell": _section(&"befell", _befell_title(game, tag), befell, false),
	}
	if quiet:
		by_id.erase(&"works")
	var sections: Array[Dictionary] = []
	for id: StringName in SECTIONS:
		if by_id.has(id) and (id == &"glance" or not ((by_id[id] as Dictionary)["lines"] as Array).is_empty()):
			sections.append(by_id[id])
	_mark_top(sections)
	var title := Calendar.date_text(turn, game.start_year)
	var next := Calendar.date_text(turn + 1, game.start_year)
	return {
		"turn": turn, "title": title, "next": next, "lede": _lede(game, tag, quiet, next),
		"seal_letter": _seal(game, tag), "quiet": quiet, "serious": serious, "swing_permille": 0,
		"toast": _toast(title, quiet, [finished, begun, stopped], int(land["delta"]), not befell.is_empty()),
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


## "Spring 1480 ended: 1 work finished. J: the report"; a quiet season: "... ended: a quiet season. J: the report".
static func _toast(title: String, quiet: bool, works: Array[int], land_delta: int, news: bool) -> String:
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


static func _glance(game: Game, tag: StringName, quiet: bool, finished: int, land: Dictionary) -> Dictionary:
	var lines: Array[Dictionary] = []
	var countries := game.has_countries()
	if quiet:
		var under := WorksView.of_country(game, tag).size()
		var text := "No works under way." if under == 0 else "%s under way; nothing else of note." % Words.plural(under, "work", "works")
		var line := _line(text, "plain")
		if countries:
			var link := Reminders.capital_link(game, tag)
			line["hex"] = link["hex"]
			line["action"] = link["action"]
			line["action_label"] = link["action_label"]
		lines.append(line)
		return _section(&"glance", "At a glance", lines, false)
	var running := WorksView.of_country(game, tag).size()
	var works := _line("Works", "good" if finished > 0 else "plain")
	works["detail"] = "%d finished, %d under way" % [finished, running] if finished + running > 0 else "no works"
	lines.append(works)
	if countries:
		var slots := WorksView.slots(game, tag)
		if int(slots["total"]) >= 0:
			var chip := _line("Work slots", "plain")
			chip["detail"] = "%d of %d in use" % [int(slots["used"]), int(slots["total"])]
			lines.append(chip)
		if bool(land["known"]):
			var chip := _line("Land", "plain")
			chip["detail"] = Words.plural(int(land["now"]), "district", "districts")
			chip["amount"] = int(land["delta"])
			chip["unit"] = &"districts"
			chip["value"] = int(land["now"])
			lines.append(chip)
	return _section(&"glance", "At a glance", lines, false)


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
