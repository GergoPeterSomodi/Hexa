## The People page's read model (docs/architecture/m5-build-spec.md 5.6 and 6.6): the head, the table of the player's
## settlements with their outlook, the countryside's line, the food and the series of the charts. Own country only (another
## country's tag, in a game with countries, gives the empty page). Pure core/views/ code: reads the game and never writes it.
## Cached by [&"study_people", version, tag, span].
class_name StudyPeople
extends RefCounted

const SERIES: Array[String] = ["people", "people_towns", "people_grew", "people_starved", "people_left", "food_made",
	"food_eaten", "food_need"]


## {has_data (a season has ended), date (the season in play), head: {people, change, towns, countryside, room, room_left,
## expected (the season in play's change, calm weather)}, rows: Array[{id (hex index), hex, place, what, people, room,
## change, outlook, tone}] (your settlements; people descending, ties by id), countryside: {count, people, room, change},
## food: {made, eaten, need, fed, text (the report's food line), lasts_text}, labels (the season titles of the series, oldest
## first), series: {people, towns, grew, starved, left, food_made, food_eaten, food_need} (PackedInt32Array; starved and left
## as positive numbers, as Stats keeps them)}.
static func of(game: Game, tag: StringName, span: int) -> Dictionary:
	if game == null or game.view_cache == null or game.state == null or game.defs == null:
		return _empty(game)
	if game.has_countries() and tag != game.player:
		return _empty(game)
	var key: Array = [&"study_people", game.version, tag, span]
	var cached := game.view_cache.get_or_make(key, func() -> Dictionary: return _build(game, tag, span)) as Dictionary
	return cached.duplicate(true)


static func _empty(game: Game) -> Dictionary:
	var series: Dictionary = {}
	for name: String in SERIES:
		series[name.trim_prefix("people_") if name.begins_with("people_") else name] = PackedInt32Array()
	return {
		"has_data": false, "date": Calendar.date_text(game.turn, game.start_year) if game != null else "",
		"head": {"people": 0, "change": 0, "towns": 0, "countryside": 0, "room": 0, "room_left": 0, "expected": 0},
		"rows": [] as Array[Dictionary], "countryside": {"count": 0, "people": 0, "room": 0, "change": 0},
		"food": {"made": 0, "eaten": 0, "need": 0, "fed": 1000, "text": "No season has ended yet.", "lasts_text": ""},
		"labels": [] as Array[String], "series": series,
	}


static func _build(game: Game, tag: StringName, span: int) -> Dictionary:
	var out := _empty(game)
	var c := Countries.by_tag(game, tag)
	var sums := PeopleView.totals(game, tag)
	if c == null or sums.is_empty():
		return out
	var stats := game.stats
	out["has_data"] = stats != null and stats.count > 0 and not c.people_closed.is_empty()
	var expected := int(EconomyPreview.expected(game, tag).get("people", sums["people"]))
	out["head"] = {"people": sums["people"], "change": sums["change"], "towns": sums["towns"],
		"countryside": sums["countryside"], "room": sums["room"], "room_left": sums["room_left"],
		"expected": expected - int(sums["people"])}
	out["countryside"] = {"count": sums["places"], "people": sums["countryside"], "room": sums["country_room"],
		"change": sums["country_change"]}
	out["rows"] = _rows(game, c)
	out["food"] = _food(game, c)
	_series(game, tag, span, out)
	return out


static func _rows(game: Game, c: Country) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var s := game.state
	for i: int in Territory.districts(game, c.id):
		if s.main_use[i] != People.SETTLEMENTS:
			continue
		var hex := game.map.hex_of(i)
		var level := int(s.level[i])
		var outlook := PeopleView.outlook(game, hex)
		rows.append({"id": i, "hex": hex, "place": Words.settlement(game, hex, level), "what": _what(game, hex, level),
			"people": int(s.people[i]), "room": game.districts.room_of(game, i),
			"change": int(s.people_end[i]) - int(s.people_start[i]), "outlook": str(outlook.get("text", "")),
			"tone": outlook.get("tone", &"plain")})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["people"] != b["people"]:
			return int(a["people"]) > int(b["people"])
		return int(a["id"]) < int(b["id"]))
	return rows


## "walled town", " · port" for a port, " · under way: to city" with a work.
static func _what(game: Game, hex: Vector2i, level: int) -> String:
	var words: Array = FamilyIds.LEVEL_WORDS["settlements"]
	var text := str(words[clampi(level, 0, words.size() - 1)])
	if bool(Improve.place_of(game.map, hex).get("port", false)):
		text += " · port"
	var work := game.state.work_at(hex)
	if work != null:
		var label := WorksView.label(game, work)
		var cut := label.find(" to ")
		text += " · under way: %s" % ("to " + label.substr(cut + 4) if cut >= 0 else label)
	return text


static func _food(game: Game, c: Country) -> Dictionary:
	var made := 0
	var eaten := 0
	var stock := 0
	for key: StringName in [&"grain", &"fish"]:
		var g := game.defs.good_id(key)
		if g < 0 or c.stock.size() <= g:
			continue
		stock += c.stock[g]
		made += maxi(Stores.flow(c, g, &"made", true), 0)
		eaten += absi(Stores.flow(c, g, &"used", true))
	var lasts := str((StudyEconomy.lasts(game, c.tag).get(game.defs.good_id(&"grain"), {}) as Dictionary).get("text", ""))
	var starved := 0
	if not c.people_closed.is_empty():
		var flows: PackedInt32Array = c.people_closed["flows"]
		starved = -int(flows[People.STARVED]) if flows.size() > People.STARVED else 0
	return {"made": made, "eaten": eaten, "need": c.food_need, "fed": c.food_fed,
		"text": food_line(c, made, eaten, stock, starved), "lasts_text": "" if lasts == "—" else lasts}


## The report's food line (spec 4.15) from a closed season's grain and fish: made, eaten, the stock left and the people the
## hunger took; "No season has ended yet." before the first.
static func food_line(c: Country, made: int, eaten: int, stock: int, starved: int) -> String:
	if c.goods_closed.is_empty():
		return "No season has ended yet."
	if c.food_fed >= 1000:
		if made >= eaten:
			return "Food: %d made for %d eaten. Fed, %d to spare." % [made, eaten, made - eaten]
		return "Food: %d made for %d eaten. Fed from the stores: %d left." % [made, eaten, stock]
	return "Food: %d made for %d needed. %d short: your towns lost %s to hunger." % [made, c.food_need,
		maxi(c.food_need - eaten, 0), Words.people(starved)]


static func _series(game: Game, tag: StringName, span: int, out: Dictionary) -> void:
	var stats := game.stats
	if stats == null or stats.count == 0 or stats.index_of(tag) < 0:
		return
	var series: Dictionary = out["series"]
	for name: String in SERIES:
		var short := name.trim_prefix("people_") if name.begins_with("people_") else name
		series[short] = stats.series(tag, name, span)
	var n := mini(mini(span, Stats.RING), stats.count)
	var labels: Array[String] = []
	for t: int in range(stats.last_turn - n + 1, stats.last_turn + 1):
		labels.append(Calendar.date_text(t, game.start_year))
	out["labels"] = labels
