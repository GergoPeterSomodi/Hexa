## The Rankings page's read model (docs/architecture/m4-5-build-spec.md 4.6, 4.9, 5.6, D9 to D11): where the viewer stands among
## the countries it knows in land and in income, each a ranked list and a line through time. Both measures are of the last
## season ended and come from Stats, the same numbers as the report's Standing (SeasonSummary): the viewer's own values are
## exact, the others' are Knowledge.band'ed, and a country the viewer does not know is only counted. Ranks come from the
## exact values (a tie shares the better rank, as Standing's; the rows of a tie are in country id order). The viewer `&""`
## (the sandbox) sees every country exact. Pure core/views/ code: it reads the game and writes only game.view_cache.
class_name StudyRankings
extends RefCounted

## The measures, in the page's order; later milestones append (M5 people, M6 army, M12 score).
const MEASURES: Array[Dictionary] = [{id = &"land", title = "Land, districts", since = "4.5"},
	{id = &"income", title = "Income, a season", since = "4.5"}]
const _DOWN := "fell to"
const _UP := "rose to"


## The season's money in less its upkeep, walls and army (D9): Treasury.left_over of the closed ledger. 0 for an unknown
## tag or a season out of the ring.
static func income_of(stats: Stats, tag: StringName, turn: int) -> int:
	if stats == null:
		return 0
	var row := stats.row(tag, turn)
	if row.is_empty():
		return 0
	return row[Stats.column("income_people")] + row[Stats.column("income_goods")] + row[Stats.column("income_dues")] \
		+ row[Stats.column("income_trade")] - row[Stats.column("upkeep_districts")] - row[Stats.column("upkeep_walls")] \
		- row[Stats.column("upkeep_army")]


## One measure (&"land" or &"income") of a country in a season; 0 for an unknown measure.
static func value_of(stats: Stats, measure: StringName, tag: StringName, turn: int) -> int:
	if stats == null:
		return 0
	match measure:
		&"land":
			return stats.value(tag, turn, "land")
		&"income":
			return income_of(stats, tag, turn)
	return 0


## "3rd of 3".
static func rank_text(rank: int, total: int) -> String:
	return "%s of %d" % [ordinal(rank), total]


## 1st, 2nd, 3rd, 4th ... 11th, 12th, 13th, 21st.
static func ordinal(n: int) -> String:
	var tail := n % 100
	if tail >= 11 and tail <= 13:
		return "%dth" % n
	return "%d%s" % [n, {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")]


## {has_data (a season has ended and the viewer is a country or `&""`), turn (the last season ended), known (the countries
## in the lists, the viewer among them), unknown (countries the viewer does not know), head,
## measures: [{id, title, rank, total, you_text ("You are 3rd of 3."), rows: [{id (country id), tag, name, short, rank,
## value (exact for the viewer, banded for others), text ("14", "about 58"), mine, bar (permille of the largest shown)}],
## line: {caption, labels, you, best (the largest known other's banded value; empty with no other), marks: [{index, turn,
## text ("rose to 2nd"), tone}]}}]}. Cached in game.view_cache by [&"rankings", version, viewer, span].
static func of(game: Game, viewer: StringName, span: int) -> Dictionary:
	if game == null or game.view_cache == null:
		return _empty(0, 0, 0)
	var key: Array = [&"rankings", game.version, viewer, span]
	var cached := game.view_cache.get_or_make(key, func() -> Dictionary: return _build(game, viewer, span)) as Dictionary
	return cached.duplicate(true)  # the cache is shared: a caller gets its own copy


static func _empty(known: int, unknown: int, turn: int) -> Dictionary:
	return {"has_data": false, "turn": turn, "known": known, "unknown": unknown, "head": "No season has ended yet.",
		"measures": [] as Array[Dictionary]}


static func _build(game: Game, viewer: StringName, span: int) -> Dictionary:
	var stats := game.stats
	if stats == null or stats.count == 0 or game.countries.is_empty():
		return _empty(0, 0, 0)
	var sees_all := viewer == &""
	if not sees_all and (Countries.by_tag(game, viewer) == null or stats.index_of(viewer) < 0):
		return _empty(0, 0, 0)
	var turn := stats.last_turn
	var tags := _listed(game, viewer)
	var unknown := 0 if sees_all else Knowledge.unknown_count(game, viewer)
	var measures: Array[Dictionary] = []
	for m: Dictionary in MEASURES:
		measures.append(_measure(game, viewer, m, tags, turn, span))
	return {"has_data": true, "turn": turn, "known": tags.size(), "unknown": unknown,
		"head": _head(tags.size(), unknown, sees_all), "measures": measures}


## The tags in the lists: the viewer (not for `&""`) and the alive countries it knows, in country id order.
static func _listed(game: Game, viewer: StringName) -> Array[StringName]:
	var wanted: Array[StringName] = Knowledge.known(game, viewer)
	if viewer != &"":
		wanted.append(viewer)
	var out: Array[StringName] = []
	for c: Country in game.countries:
		if c != null and c.tag != &"" and wanted.has(c.tag) and (c.alive or c.tag == viewer):
			out.append(c.tag)
	return out


static func _head(known: int, unknown: int, sees_all: bool) -> String:
	if sees_all:
		return "The %s on the map. Their numbers are exact." % Words.plural(known, "country", "countries")
	var text := "The %d countries you know, you among them." % known if known > 1 else "You know no other country yet."
	if unknown > 0:
		text += " %s unknown." % Words.plural(unknown, "country", "countries")
	if known > 1:
		text += " Their numbers are rounded."
	return text


static func _measure(game: Game, viewer: StringName, def: Dictionary, tags: Array[StringName], turn: int, span: int) -> Dictionary:
	var id: StringName = def["id"]
	var stats := game.stats
	var sees_all := viewer == &""
	var rows: Array[Dictionary] = []
	for tag: StringName in tags:
		var c := Countries.by_tag(game, tag)
		var exact := value_of(stats, id, tag, turn)
		var mine := tag == viewer
		var shown := exact if (mine or sees_all) else Knowledge.band(exact)
		var text := Words.signed(shown) if id == &"income" else Words.number(shown)
		if not mine and not sees_all:
			text = "about " + text
		var short := LogLines.short_name(game, tag)
		rows.append({"id": c.id, "tag": tag, "name": short + " (you)" if mine else short, "short": short, "rank": 1,
			"value": shown, "text": text, "mine": mine, "bar": 0, "exact": exact})
	_rank(rows)
	var largest := 0
	for r: Dictionary in rows:
		largest = maxi(largest, int(r["value"]))
	var mine_rank := 0
	for r: Dictionary in rows:
		r["bar"] = floori(float(int(r["value"]) * 1000) / float(largest)) if largest > 0 and int(r["value"]) > 0 else 0
		if bool(r["mine"]):
			mine_rank = int(r["rank"])
		r.erase("exact")
	return {"id": id, "title": def["title"], "rank": mine_rank, "total": rows.size(),
		"you_text": "You are %s." % rank_text(mine_rank, rows.size()) if mine_rank > 0 else "", "rows": rows,
		"line": _line(game, viewer, id, tags, turn, span)}


## Orders `rows` by exact value, largest first, ties by country id; each row's rank is one more than the rows with a
## larger exact value (a tie shares the better rank: the report's Standing counts the same way).
static func _rank(rows: Array[Dictionary]) -> void:
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["exact"]) > int(b["exact"]) or (int(a["exact"]) == int(b["exact"]) and int(a["id"]) < int(b["id"])))
	for r: Dictionary in rows:
		var rank := 1
		for o: Dictionary in rows:
			if int(o["exact"]) > int(r["exact"]):
				rank += 1
		r["rank"] = rank


## The viewer's value a season over the last `span` seasons, the largest known other's banded value, and a mark where
## the viewer's rank changed from the season before ("known" is known now, D11).
static func _line(game: Game, viewer: StringName, id: StringName, tags: Array[StringName], turn: int, span: int) -> Dictionary:
	var stats := game.stats
	var n := mini(mini(maxi(span, 1), Stats.RING), stats.count)
	var first := turn - n + 1
	var labels: Array[String] = []
	var you := PackedInt32Array()
	var best := PackedInt32Array()
	var marks: Array[Dictionary] = []
	var others: Array[StringName] = []
	for tag: StringName in tags:
		if tag != viewer:
			others.append(tag)
	var before := 0
	for t: int in range(first, turn + 1):
		labels.append(Calendar.date_text(t, game.start_year))
		var mine := value_of(stats, id, viewer, t)
		you.append(mine)
		if not others.is_empty():
			var top := value_of(stats, id, others[0], t)
			var rank := 1
			for o: StringName in others:
				var v := value_of(stats, id, o, t)
				top = maxi(top, v)
				rank += 1 if v > mine else 0
			best.append(Knowledge.band(top))
			if before > 0 and rank != before and viewer != &"":
				marks.append({"index": t - first, "turn": t, "text": "%s %s" % [_UP if rank < before else _DOWN, ordinal(rank)],
					"tone": "good" if rank < before else "bad"})
			before = rank
	var what := "land" if id == &"land" else "income"
	var caption := "Your %s, the last %s" % [what, "season" if n == 1 else "%d seasons" % n]
	return {"caption": caption, "labels": labels, "you": you, "best": best, "marks": marks}
