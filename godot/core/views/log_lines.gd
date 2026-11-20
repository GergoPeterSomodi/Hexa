## The action log's lines, built from the chronicle (docs/architecture/m3-build-spec.md 4.4, 5.6, 6.5, D43): the sentence,
## keyword chip, tone and floating word of each notable event for one viewer. A line is the same live and after a load,
## because it is built from the saved chronicle entry alone. Pure core/views/ code: reads the game, writes nothing.
class_name LogLines
extends RefCounted

const FILTERS: Array[Dictionary] = [{id = &"all", since = "3"}, {id = &"works", since = "3"}, {id = &"mine", since = "3"},
	{id = &"money", since = "4"}, {id = &"war", since = "7"}]
const SEASONS_SHOWN := 8
const PER_SEASON := 60


## {} when `viewer` is not told of the entry (Knowledge.witnessed) or it cannot be described; else {text, keyword, tone
## (good, plain, bad, muted), hex, mine, filters: Array[StringName], notify, floating, turn}. `memo` lets a caller that
## reads many entries share the answers of "does the viewer know this actor" (the key is the entry's parties).
static func line_of(game: Game, entry: Dictionary, viewer: StringName, memo: Dictionary = {}) -> Dictionary:
	if game == null or not _seen(game, entry, viewer, memo):
		return {}
	var tag := StringName(str(entry.get("tag", "")))
	var others := _tags(entry.get("others", []))
	var mine := tag == viewer
	var line: Dictionary
	match str(entry.get("kind", "")):
		"work_started", "work_finished", "work_cancelled":
			line = _work_line(game, entry, mine)
		"owners_changed":
			mine = mine or others.has(viewer)
			line = _land_line(game, entry, viewer, tag, others)
		"country_chosen":
			line = _rule_line(game, entry, mine)
		"goods_short":
			line = _short_line(game, entry, mine)
		"tax_set":
			line = _tax_line(game, entry, mine)
		_:
			return {}
	if line.is_empty():
		return {}
	line["mine"] = mine
	line["turn"] = int(entry.get("turn", 0))
	line["filters"] = _filters_of(entry, mine)
	return line


## The lines of the newest SEASONS_SHOWN seasons that have any, as [{turn, title ("Spring 1480"), lines}], newest season
## first, each season's lines newest first, at most PER_SEASON a season. Unknown filters (war: a later milestone)
## give no seasons. Cached in game.view_cache by [&"log", version, turn, viewer, filter].
static func entries(game: Game, viewer: StringName, filter: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null:
		return out
	var key: Array = [&"log", game.version, game.turn, viewer, filter, game.chronicle.entries.size()]
	var cached: Variant = game.view_cache.get_or_make(key, func() -> Array[Dictionary]: return _build(game, viewer, filter))
	out.assign((cached as Array).duplicate(true))  # the cache is shared: a caller gets its own copy
	return out


static func _build(game: Game, viewer: StringName, filter: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _filter_ids().has(filter):
		return out
	var memo := {}
	var all := game.chronicle.entries
	var current: Dictionary = {}
	var i := all.size() - 1
	while i >= 0:
		var entry: Dictionary = all[i]
		i -= 1
		if not _may_pass(entry, viewer, filter):
			continue
		var turn := int(entry.get("turn", 0))
		if current.is_empty() or int(current["turn"]) != turn:
			if out.size() >= SEASONS_SHOWN:
				break
			current = {}
		if not current.is_empty() and int(current["turn"]) == turn and (current["lines"] as Array).size() >= PER_SEASON:
			continue  # the season is full: its older entries are never read
		var line := line_of(game, entry, viewer, memo)
		if line.is_empty() or not (line["filters"] as Array).has(filter):
			continue
		if current.is_empty():
			current = {"turn": turn, "title": Calendar.date_text(turn, game.start_year), "lines": [] as Array[Dictionary]}
			out.append(current)
		var lines: Array[Dictionary] = current["lines"]
		if lines.size() < PER_SEASON:
			lines.append(line)
	return out


static func _filter_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for f: Dictionary in FILTERS:
		ids.append(f["id"] as StringName)
	return ids


## A cheap test before the line is built: a filter that is sure to drop the entry skips the work.
static func _may_pass(entry: Dictionary, viewer: StringName, filter: StringName) -> bool:
	match filter:
		&"works":
			return str(entry.get("kind", "")).begins_with("work_")
		&"money":
			return _money_kind(str(entry.get("kind", "")))
		&"mine":
			return StringName(str(entry.get("tag", ""))) == viewer or _tags(entry.get("others", [])).has(viewer)
	return true


static func _filters_of(entry: Dictionary, mine: bool) -> Array[StringName]:
	var kind := str(entry.get("kind", ""))
	var out: Array[StringName] = [&"all"]
	if kind.begins_with("work_"):
		out.append(&"works")
	if mine:
		out.append(&"mine")
	if kind == "goods_short" or kind == "tax_set" or (mine and not _paid_text(entry).is_empty()):
		out.append(&"money")
	return out


## The kinds that can carry the Money filter (a work does when its ducats moved: checked on the built line).
static func _money_kind(kind: String) -> bool:
	return kind == "goods_short" or kind == "tax_set" or kind.begins_with("work_")


# ----- who is told -----------------------------------------------------------------------------------------------


## Knowledge.witnessed, remembered per set of parties: the answer depends on the actor, the others and the witnesses
## only, and "knows" costs a pass over the map.
static func _seen(game: Game, entry: Dictionary, viewer: StringName, memo: Dictionary) -> bool:
	var key := "%s|%s|%s" % [str(entry.get("tag", "")), str(entry.get("others", "")), str(entry.get("witnesses", ""))]
	if not memo.has(key):
		memo[key] = Knowledge.witnessed(game, entry, viewer)
	return bool(memo[key])


static func _tags(value: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if typeof(value) != TYPE_ARRAY and typeof(value) != TYPE_PACKED_STRING_ARRAY:
		return out
	for item: Variant in value:
		out.append(StringName(str(item)))
	return out


# ----- works -----------------------------------------------------------------------------------------------------


static func _work_line(game: Game, entry: Dictionary, mine: bool) -> Dictionary:
	var work_value: Variant = entry.get("work", null)
	if not (work_value is Dictionary):
		return {}
	var work := Work.from_dict(work_value as Dictionary)
	if work == null:
		return {}
	var kind := str(entry.get("kind", ""))
	var turn := int(entry.get("turn", 0))
	var why := str(entry.get("why", ""))
	var line := {"hex": work.hex, "notify": false, "floating": ""}
	if mine:
		var place := WorksView.line(game, work)
		match kind:
			"work_started":
				line.merge({"keyword": "Begun", "tone": "plain",
					"floating": ("Begun %s" % Words.signed(-work.paid)) if work.paid > 0 else "Begun",
					"text": "Begun: %s. Ready %s.%s" % [place, ready_text(game, work, turn), _paid_text(entry)]}, true)
			"work_finished":
				line.merge({"keyword": "Finished", "tone": "good", "floating": "Finished", "notify": true,
					"text": "Finished: %s." % place}, true)
			_:
				line.merge({"keyword": "Cancelled", "tone": "bad", "floating": "Cancelled",
					"notify": why == "lost" or why == "blocked",
					"text": cancelled_text(place, why, str(entry.get("reason", ""))) + _paid_text(entry)}, true)
		return line
	var who := short_name(game, StringName(str(entry.get("tag", ""))))
	var at := "(%d, %d)" % [work.hex.x, work.hex.y]
	match kind:
		"work_started":
			line.merge({"keyword": "Begun", "tone": "muted",
				"text": "%s began work on %s at %s." % [who, noun_of(work), at]}, true)
		"work_finished":
			var cleared := work.action == Works.CLEAR
			var word := "Cleared" if cleared else "Built"
			line.merge({"keyword": word, "tone": "muted", "floating": word,
				"text": "%s %s %s at %s." % [who, "cleared" if cleared else "finished", noun_of(work), at]}, true)
		_:
			line.merge({"keyword": "Cancelled", "tone": "muted",
				"text": "%s cancelled work on %s at %s." % [who, noun_of(work), at]}, true)
	return line


## The money a work line adds when the viewer's own ducats moved: " (−40 ducats)" for a begun work that was paid,
## " (+40 ducats back)" for a cancelled one with a refund; "" otherwise.
static func _paid_text(entry: Dictionary) -> String:
	match str(entry.get("kind", "")):
		"work_started":
			var work_value: Variant = entry.get("work", null)
			var paid := int((work_value as Dictionary).get("paid", 0)) if work_value is Dictionary else 0
			if paid > 0:
				return " (%s)" % Words.signed_ducats(-paid)
		"work_cancelled":
			var refund := int(entry.get("refund", 0))
			if refund > 0:
				return " (+%s back)" % Words.ducats(refund)
	return ""


## "Cancelled: <place>." (by order), "Cancelled: <place>, the land was lost." or "Cancelled: <place>: <reason>."
static func cancelled_text(place: String, why: String, reason: String) -> String:
	if why == "lost":
		return "Cancelled: %s, the land was lost." % place
	if why == "blocked":
		return "Cancelled: %s: %s." % [place, reason]
	return "Cancelled: %s." % place


## "Spring 1481": the season a work begun in season `turn` stands from, skipping halted seasons (as Works.ready_turn,
## which walks from the current turn; an old entry needs the walk from its own).
static func ready_text(game: Game, work: Work, turn: int) -> String:
	var left := work.seasons
	var t := turn
	for n: int in Works.HORIZON:
		if not Works.halted(game, work, t):
			left -= 1
			if left <= 0:
				t += 1
				break
		t += 1
	return Calendar.date_text(t, game.start_year)


## "a vineyard", "a walled town", "an olive grove": the piece a work makes (or, for a clearing, takes off).
static func noun_of(work: Work) -> String:
	var piece := FamilyIds.NAMES[clampi(work.family, 0, FamilyIds.COUNT - 1)]
	var base := WorksView.piece_name(work.family)
	if HexCard.LEVEL_WORDS.has(piece) and work.action != Works.CLEAR:
		base = HexCard.level_label(piece, work.level_to)
	return Words.with_article(base)


## The short name of a country ("Milan"); its tag when it has none.
static func short_name(game: Game, tag: StringName) -> String:
	var def := Countries.def_of(game, tag)
	return def.name if def != null and not def.name.is_empty() else String(tag)


## The text with its first letter in capitals.
static func capital(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


# ----- money: shortages and taxes ---------------------------------------------------------------------------------


## "Your towns ran short of salt: 0 of 1." Only the owner is told: the event's witnesses are its actor alone, and any
## other viewer gets no line even from a hand-made entry.
static func _short_line(game: Game, entry: Dictionary, mine: bool) -> Dictionary:
	if not mine:
		return {}
	var tag := StringName(str(entry.get("tag", "")))
	var c := Countries.by_tag(game, tag)
	var hex: Vector2i = c.capital if c != null else WorksView.NO_HEX
	var text := "Your towns ran short of %s: %s of %s." % [str(entry.get("good", "")).to_lower(),
		Words.number(int(entry.get("taken", 0))), Words.number(int(entry.get("need", 0)))]
	return {"keyword": "Short", "tone": "bad", "hex": hex, "notify": true, "floating": "", "text": text}


## "You set taxes to High." or, for a known other, "Milan set taxes to High." (muted).
static func _tax_line(game: Game, entry: Dictionary, mine: bool) -> Dictionary:
	var tag := StringName(str(entry.get("tag", "")))
	var level := Words.tax_name(int(entry.get("level", -1)))
	if level.is_empty():
		return {}
	var c := Countries.by_tag(game, tag)
	var hex: Vector2i = c.capital if c != null else WorksView.NO_HEX
	if mine:
		return {"keyword": "Taxes", "tone": "plain", "hex": hex, "notify": false, "floating": "",
			"text": "You set taxes to %s." % level}
	return {"keyword": "Taxes", "tone": "muted", "hex": hex, "notify": false, "floating": "",
		"text": "%s set taxes to %s." % [short_name(game, tag), level]}


# ----- land and rule ---------------------------------------------------------------------------------------------


static func _land_line(game: Game, entry: Dictionary, viewer: StringName, tag: StringName, others: Array[StringName]) -> Dictionary:
	var hexes := _hexes(entry.get("hexes", []))
	if hexes.is_empty():
		return {}
	var gained := tag == viewer and viewer != &""
	var lost := others.has(viewer) and viewer != &""
	var districts := Words.plural(hexes.size(), "district", "districts")
	var places := _places(game, hexes)
	if tag == &"" and others.is_empty():
		return {}  # land that nobody gave and nobody got: nothing to say
	var names: Array[String] = []
	for other: StringName in others:
		if Knowledge.knows(game, viewer, other):  # a victim the viewer does not know stays unnamed
			names.append(Words.country_the(game, other))
	if names.is_empty() and not others.is_empty():
		names.append("another country")
	var from := Words.list(names)
	var line := {"hex": hexes[0], "notify": gained or lost, "floating": ""}
	if gained:
		var text := "Took %s" % districts + ((" from %s" % from) if not names.is_empty() else "")
		line.merge({"keyword": "Gained", "tone": "good", "floating": "Gained", "text": "%s: %s." % [text, places]}, true)
	elif lost:
		var to := (" to %s" % Words.country_the(game, tag)) if tag != &"" else ""
		line.merge({"keyword": "Lost", "tone": "bad", "floating": "Lost", "text": "Lost %s%s: %s." % [districts, to, places]}, true)
	else:
		var text := ""
		if tag == &"":
			text = "%s lost %s" % [capital(from), districts]
		else:
			text = "%s took %s" % [capital(Words.country_the(game, tag)), districts]
			if not names.is_empty():
				text += " from %s" % from
		line.merge({"keyword": "Taken", "tone": "muted", "floating": "Taken", "text": "%s: %s." % [text, places]}, true)
	return line


static func _hexes(value: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for item: Variant in value as Array:
		if item is Vector2i:
			out.append(item as Vector2i)
	return out


## "Bergamo (11, 8) and 2 more": only the first is looked up.
static func _places(game: Game, hexes: Array[Vector2i]) -> String:
	var items: Array[String] = []
	for i: int in hexes.size():
		items.append(Words.place(game, hexes[i]) if i < 1 else "")
	return Words.list(items, 1)


static func _rule_line(game: Game, entry: Dictionary, mine: bool) -> Dictionary:
	var tag := StringName(str(entry.get("tag", "")))
	var c := Countries.by_tag(game, tag)
	var hex: Vector2i = c.capital if c != null else WorksView.NO_HEX
	var the := Words.country_the(game, tag)
	var text := "Took the rule of %s." % the if mine else "%s passed to a new ruler." % capital(the)
	if the == "":
		return {}
	return {"keyword": "Rule", "tone": "plain", "hex": hex, "notify": false, "floating": "", "text": text}
