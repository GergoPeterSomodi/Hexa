## The History page's read model (docs/architecture/m4-5-build-spec.md 4.7, 4.9, 5.6, D12 to D14): the chronicle as the viewer may
## read it (Knowledge.witnessed, through LogLines), a timeline with one mark a season, a season's numbers and the list of
## lines in pages of whole seasons. Every view is of one viewer; the viewer `&""` reads everything. Pure core/views/ code:
## it reads the game and writes only game.view_cache. The chronicle is not saved by the views and can be written without a
## version change (a test's hand-made entry), so each cache key ends with the chronicle's size.
class_name StudyHistory
extends RefCounted

const PAGE := 120
const MARK_KINDS: Array[StringName] = [&"land", &"finished", &"stopped", &"short", &"begun", &"tax", &"chosen"]  # priority
const MARK_ICONS: Dictionary = {land = &"settlement", finished = &"district", stopped = &"district", short = &"warning",
	begun = &"spending", tax = &"tax", chosen = &"study"}
const FILTER_ORDER: Array[StringName] = [&"all", &"war", &"money", &"works", &"mine"]  # shown when LogLines.FILTERS allows
const KEPT_NONE_TEXT := "Numbers are kept for the last 40 seasons and each winter."


## {entries: PackedInt32Array (chronicle indices the viewer is told of), turns: PackedInt32Array (their turns), filters:
## PackedInt32Array (a bit per LogLines filter: bit i is LogLines.FILTERS[i])}. Cached [&"history_index", version, viewer, size].
static func index(game: Game, viewer: StringName) -> Dictionary:
	if game == null or game.view_cache == null:
		return _empty_index()
	var key: Array = [&"history_index", game.version, viewer, game.chronicle.entries.size()]
	var cached := game.view_cache.get_or_make(key, func() -> Dictionary: return _build_index(game, viewer)) as Dictionary
	return cached.duplicate(true)


static func _empty_index() -> Dictionary:
	return {"entries": PackedInt32Array(), "turns": PackedInt32Array(), "filters": PackedInt32Array()}


static func _build_index(game: Game, viewer: StringName) -> Dictionary:
	var out := _empty_index()
	var entries := PackedInt32Array()
	var turns := PackedInt32Array()
	var bits := PackedInt32Array()
	var memo := {}
	var all := game.chronicle.entries
	for i: int in all.size():
		var filters := LogLines.filters_of(game, all[i], viewer, memo)
		if filters.is_empty():
			continue
		entries.append(i)
		turns.append(int(all[i].get("turn", 0)))
		bits.append(_bits_of(filters))
	out["entries"] = entries
	out["turns"] = turns
	out["filters"] = bits
	return out


## The bit mask of filter ids (bit i for LogLines.FILTERS[i]).
static func _bits_of(filters: Array[StringName]) -> int:
	var bits := 0
	for i: int in LogLines.FILTERS.size():
		if filters.has(LogLines.FILTERS[i]["id"] as StringName):
			bits |= 1 << i
	return bits


## The bit of a filter id; 0 for an unknown id.
static func _bit(filter: StringName) -> int:
	for i: int in LogLines.FILTERS.size():
		if (LogLines.FILTERS[i]["id"] as StringName) == filter:
			return 1 << i
	return 0


## {first_turn (1), last_turn (game.turn - 1), start_year, counts (lines the viewer is told of, by turn - 1),
## marks: [{turn, kind, tone, icon, text, hex, more (the viewer's other marks that season)}]}. A mark is the viewer's own
## event, the first kind of MARK_KINDS in a season. The viewer `&""` has no events of its own: no marks.
## Cached [&"history_timeline", version, viewer, size].
static func timeline(game: Game, viewer: StringName) -> Dictionary:
	if game == null or game.view_cache == null:
		return {"first_turn": 1, "last_turn": 0, "start_year": 0, "counts": PackedInt32Array(), "marks": [] as Array[Dictionary]}
	var key: Array = [&"history_timeline", game.version, viewer, game.chronicle.entries.size()]
	var cached := game.view_cache.get_or_make(key, func() -> Dictionary: return _build_timeline(game, viewer)) as Dictionary
	return cached.duplicate(true)


static func _build_timeline(game: Game, viewer: StringName) -> Dictionary:
	var last := maxi(game.turn - 1, 0)
	var counts := PackedInt32Array()
	counts.resize(last)
	counts.fill(0)
	var marks: Array[Dictionary] = []
	var idx := index(game, viewer)
	var entries: PackedInt32Array = idx["entries"]
	var turns: PackedInt32Array = idx["turns"]
	var memo := {}
	var best := {}  # turn -> the mark so far
	var seen := {}  # turn -> marks found
	for n: int in entries.size():
		var turn := turns[n]
		if turn < 1 or turn > last:
			continue
		counts[turn - 1] += 1
		if viewer == &"":
			continue
		var entry: Dictionary = game.chronicle.entries[entries[n]]
		var kind := _mark_kind(entry, viewer)
		if kind == &"":
			continue
		seen[turn] = int(seen.get(turn, 0)) + 1
		var rank := MARK_KINDS.find(kind)
		if best.has(turn) and MARK_KINDS.find(best[turn]["kind"]) <= rank:
			continue
		var line := LogLines.line_of(game, entry, viewer, memo)
		best[turn] = {"turn": turn, "kind": kind, "tone": _tone(kind, entry, viewer), "icon": MARK_ICONS[kind],
			"text": str(line.get("text", "")), "hex": line.get("hex", WorksView.NO_HEX), "more": 0}
	var turn_list: Array = best.keys()
	turn_list.sort()
	for t: int in turn_list:
		var mark: Dictionary = best[t]
		mark["more"] = int(seen[t]) - 1
		marks.append(mark)
	return {"first_turn": 1, "last_turn": last, "start_year": game.start_year, "counts": counts, "marks": marks}


## The mark kind of the viewer's own event, or &"" (an event of another, a plain cancel by order).
static func _mark_kind(entry: Dictionary, viewer: StringName) -> StringName:
	var tag := StringName(str(entry.get("tag", "")))
	var others := _tags(entry.get("others", []))
	match str(entry.get("kind", "")):
		"owners_changed":
			return &"land" if tag == viewer or others.has(viewer) else &""
		"work_finished":
			return &"finished" if tag == viewer else &""
		"work_cancelled":
			var why := str(entry.get("why", ""))
			return &"stopped" if tag == viewer and (why == "lost" or why == "blocked") else &""
		"goods_short":
			return &"short" if tag == viewer else &""
		"work_started":
			return &"begun" if tag == viewer else &""
		"tax_set":
			return &"tax" if tag == viewer else &""
		"country_chosen":
			return &"chosen" if tag == viewer else &""
	return &""


static func _tone(kind: StringName, entry: Dictionary, viewer: StringName) -> StringName:
	match kind:
		&"land":
			return &"good" if StringName(str(entry.get("tag", ""))) == viewer else &"bad"
		&"finished":
			return &"good"
		&"stopped", &"short":
			return &"bad"
	return &"plain"


## {turn, title, kept (&"season": the ring row, &"year": the winter's year row, &"none"), text, opening, closing, change, land,
## income}. The numbers are 0 when kept is &"none". The viewer `&""` and a map-only game have none.
static func season(game: Game, viewer: StringName, turn: int) -> Dictionary:
	var out := {"turn": turn, "title": Calendar.date_text(turn, game.start_year) if game != null else "", "kept": &"none",
		"text": KEPT_NONE_TEXT, "opening": 0, "closing": 0, "change": 0, "land": 0, "income": 0}
	if game == null or game.stats == null or viewer == &"" or game.stats.index_of(viewer) < 0 or turn < 1:
		return out
	var stats := game.stats
	if stats.has_row(turn):
		var closing := stats.value(viewer, turn, "treasury")
		var income := StudyRankings.income_of(stats, viewer, turn)
		var spent := stats.value(viewer, turn, "spending")
		var opening := stats.value(viewer, turn - 1, "treasury") if stats.has_row(turn - 1) else closing - (income - spent)  # D7
		var land := stats.value(viewer, turn, "land")
		out.merge({"kept": &"season", "opening": opening, "closing": closing, "change": closing - opening, "land": land,
			"income": income, "text": "Treasury %s → %s %s · land %d · income %s" % [Words.number(opening), Words.number(closing),
			_arrow(closing - opening), land, _arrow(income)]}, true)
		return out
	if Calendar.is_winter(turn):
		var row := stats.year_row(viewer, Calendar.year_of(turn, game.start_year) - game.start_year)
		if not row.is_empty():
			var closing := row[Stats.column("treasury")]
			var land := row[Stats.column("land")]
			out.merge({"kept": &"year", "closing": closing, "land": land,
				"text": "At the year's end: treasury %s · land %d" % [Words.number(closing), land]}, true)
	return out


## "▲ +85", "▼ −12", "0".
static func _arrow(n: int) -> String:
	if n == 0:
		return "0"
	return "%s %s" % ["▲" if n > 0 else "▼", Words.signed(n)]


## The lines of a filter from `upto_turn` back (0: the newest), whole seasons, newest season first and each season's lines in
## the chronicle's order, until the next season would pass `limit` rows (the newest season is always whole):
## {rows: [{id (chronicle index), turn, title, keyword, text, tone, hex, mine}], upto_turn, from_turn (the oldest shown; 0 with
## no row), older_turn (the newest season older than the page with lines; 0: none), total (the viewer's lines in the filter)}.
## An unknown filter is read as all. Cached [&"history_chronicle", version, viewer, filter, upto_turn, limit, size].
static func chronicle(game: Game, viewer: StringName, filter: StringName, upto_turn: int, limit: int = PAGE) -> Dictionary:
	if game == null or game.view_cache == null:
		return {"rows": [] as Array[Dictionary], "upto_turn": upto_turn, "from_turn": 0, "older_turn": 0, "total": 0}
	var key: Array = [&"history_chronicle", game.version, viewer, filter, upto_turn, limit, game.chronicle.entries.size()]
	var cached := game.view_cache.get_or_make(key, func() -> Dictionary: return _build_page(game, viewer, filter, upto_turn, limit)) as Dictionary
	return cached.duplicate(true)


static func _build_page(game: Game, viewer: StringName, filter: StringName, upto_turn: int, limit: int) -> Dictionary:
	var bit := _bit(filter)
	if bit == 0:
		bit = _bit(&"all")
	var idx := index(game, viewer)
	var entries: PackedInt32Array = idx["entries"]
	var turns: PackedInt32Array = idx["turns"]
	var bits: PackedInt32Array = idx["filters"]
	var cap := upto_turn if upto_turn > 0 else 0x7fffffff
	var picks := PackedInt32Array()  # positions in the index, oldest first
	for n: int in entries.size():
		if (bits[n] & bit) != 0:
			picks.append(n)
	var total := picks.size()
	var end := picks.size()
	while end > 0 and turns[picks[end - 1]] > cap:
		end -= 1
	var start := end
	var rows: Array[Dictionary] = []
	var memo := {}
	while start > 0:
		var turn := turns[picks[start - 1]]
		var seg := start
		while seg > 0 and turns[picks[seg - 1]] == turn:
			seg -= 1
		if start < end and (end - seg) > limit:
			break
		start = seg
	for p: int in range(start, end):
		var entry: Dictionary = game.chronicle.entries[entries[picks[p]]]
		var line := LogLines.line_of(game, entry, viewer, memo)
		rows.append({"id": entries[picks[p]], "turn": turns[picks[p]], "title": Calendar.date_text(turns[picks[p]], game.start_year),
			"keyword": line.get("keyword", ""), "text": line.get("text", ""), "tone": line.get("tone", "plain"),
			"hex": line.get("hex", WorksView.NO_HEX), "mine": bool(line.get("mine", false))})
	# whole seasons newest first, each in the chronicle's order
	var ordered: Array[Dictionary] = []
	var i := rows.size()
	while i > 0:
		var turn := int(rows[i - 1]["turn"])
		var j := i
		while j > 0 and int(rows[j - 1]["turn"]) == turn:
			j -= 1
		ordered.append_array(rows.slice(j, i))
		i = j
	return {"rows": ordered, "upto_turn": upto_turn, "from_turn": turns[picks[start]] if start < end else 0,
		"older_turn": turns[picks[start - 1]] if start > 0 else 0, "total": total}


## The filters a milestone shows: FILTER_ORDER with LogLines.FILTERS' `since` at most `milestone` (a version text such as "4.5").
static func filters(milestone: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in FILTER_ORDER:
		for f: Dictionary in LogLines.FILTERS:
			if (f["id"] as StringName) == id and _version_le(str(f["since"]), milestone):
				out.append(id)
	return out


## Whether version text `a` is at most `b`, compared part by part ("4" <= "4.5", "7" > "4.5").
static func _version_le(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for n: int in maxi(pa.size(), pb.size()):
		var x := int(pa[n]) if n < pa.size() else 0
		var y := int(pb[n]) if n < pb.size() else 0
		if x != y:
			return x < y
	return true


## The tags of an entry's `others` (an Array or the PackedStringArray the chronicle stores).
static func _tags(value: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if typeof(value) != TYPE_ARRAY and typeof(value) != TYPE_PACKED_STRING_ARRAY:
		return out
	for item: Variant in value:
		out.append(StringName(str(item)))
	return out
