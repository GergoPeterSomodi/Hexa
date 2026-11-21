## The People section of the season report (docs/architecture/m5-build-spec.md 4.15, 4.11 b): the country's people at the
## start and the end of the season that ended, one line for each settlement whose people changed and one for the
## countryside, the level lines (grew into a town, fell to a village) and the food line. SeasonSummary asks for it and
## puts it in the report; it lives apart to keep that file small. The place lines are of the last season ended only
## (the state holds one season's start and end people); an older turn has only its total, from the Stats rows. The lines
## add up to the total by construction: the countryside is the total less the settlements. Pure core/views/ code.
class_name SummaryPeople
extends RefCounted

@warning_ignore_start("integer_division")

## The people's change under this many percent of the opening (and no level line) leaves the season quiet.
const QUIET_PERCENT := 2
## Place lines shown, as every section of the report (SeasonSummary.SHOWN); the rest is one "N more places" line that
## carries their change, so the lines still add up to the total.
const SHOWN := 6


## {known (the country's people are told), from, to, change, levels (a level line in the season), quiet (the people's
## part of a quiet season), section (the report's People section; {} when nothing is known, the people did not change or the country has no row)}.
static func of(game: Game, tag: StringName, turn: int) -> Dictionary:
	var out := {"known": false, "from": 0, "to": 0, "change": 0, "levels": false, "quiet": true, "section": {}}
	var country := Countries.by_tag(game, tag) if game.has_countries() else null
	if country == null or game.defs == null or game.state == null or game.stats == null:
		return out
	var level_lines := _level_lines(game, tag, turn)
	out["levels"] = not level_lines.is_empty()
	var last := turn == game.turn - 1 and game.state.people_start.size() == game.state.owner.size() \
			and game.state.people_end.size() == game.state.owner.size()
	var lines: Array[Dictionary] = []
	var place_count := 0
	if last:
		var rows := _rows(game, country)
		out["from"] = rows["from"]
		out["to"] = rows["to"]
		place_count = (rows["places"] as Array).size()
		lines = _place_lines(game, rows)
	elif game.stats.has_row(turn) and game.stats.has_row(turn - 1):
		out["from"] = game.stats.value(tag, turn - 1, "people")
		out["to"] = game.stats.value(tag, turn, "people")
	else:
		return out
	var change := int(out["to"]) - int(out["from"])
	out["known"] = true
	out["change"] = change
	out["quiet"] = absi(change) * 100 < QUIET_PERCENT * maxi(1, int(out["from"])) and level_lines.is_empty()
	var total := _line("%s → %s" % [Words.number(int(out["from"])), Words.number(int(out["to"]))], _tone_of(change))
	total["from"] = int(out["from"])
	total["to"] = int(out["to"])
	total["amount"] = change
	var count := lines.size()
	if last:
		lines.append_array(level_lines)
		var food := _food_line(game, country, turn)
		if not food.is_empty():
			lines.append(food)
	if change == 0 and level_lines.is_empty():
		return out  # people who did not change have no section (the totals are the Stats rows')
	out["section"] = {"id": &"people", "title": "People", "count": count, "total": total, "lines": lines,
		"more": maxi(place_count - SHOWN, 0), "unchanged": ""}
	return out


## {from, to, places: [{hex, level, end, change}] (settlements, index order, whose people changed), countryside: {count,
## end, change}}: the people of the hexes `country` holds now, at the start and at the end of the season.
static func _rows(game: Game, country: Country) -> Dictionary:
	var from := 0
	var to := 0
	var places: Array[Dictionary] = []
	var count := 0
	var end := 0
	var delta := 0
	var state := game.state
	for i: int in Territory.districts(game, country.id):  # index order, the country's land only
		var change := state.people_end[i] - state.people_start[i]
		from += state.people_start[i]
		to += state.people_end[i]
		if int(state.main_use[i]) == People.SETTLEMENTS:
			if change != 0:
				places.append({"hex": game.map.hex_of(i), "level": int(state.level[i]), "end": state.people_end[i],
					"change": change})
		else:
			count += 1
			end += state.people_end[i]
			delta += change
	return {"from": from, "to": to, "places": places, "countryside": {"count": count, "end": end, "change": delta}}


## The place lines: the settlements (the larger change first, ties by hex index), then the countryside when it changed.
static func _place_lines(game: Game, rows: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var places: Array[Dictionary] = []
	places.assign(rows["places"])
	var order: Array[Array] = []
	for n: int in places.size():
		order.append([absi(int(places[n]["change"])), n])
	order.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
	var hidden := 0
	var hidden_change := 0
	for n: int in order.size():
		var pair: Array = order[n]
		var p := places[int(pair[1])]
		if n >= SHOWN:
			hidden += 1
			hidden_change += int(p["change"])
			continue
		var line := _place("%s %s" % [Words.settlement(game, p["hex"] as Vector2i, int(p["level"])), Words.number(int(p["end"]))],
			int(p["change"]), game)
		line["hex"] = p["hex"]
		out.append(line)
	if hidden > 0:
		out.append(_place("%d more places" % hidden, hidden_change, game))
	var land: Dictionary = rows["countryside"]
	if int(land["change"]) != 0:
		out.append(_place("The countryside, %s, %s" % [Words.plural(int(land["count"]), "place", "places"),
			Words.number(int(land["end"]))], int(land["change"]), game))
	return out


static func _place(text: String, change: int, game: Game) -> Dictionary:
	var line := _line(text, _tone_of(change), absi(change) * game.defs.town_tax_milli / 1000000)
	line["amount"] = change
	return line


## The level lines (sub): the country's `town_grew` and `district_declined` of the season, in the chronicle's order.
static func _level_lines(game: Game, tag: StringName, turn: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var memo := {}
	for entry: Dictionary in game.chronicle.of_turn(turn):
		var kind := str(entry.get("kind", ""))
		if (kind != "town_grew" and kind != "district_declined") or StringName(str(entry.get("tag", ""))) != tag:
			continue
		var log_line := LogLines.line_of(game, entry, tag, memo)
		if log_line.is_empty():
			continue
		var line := _line(str(log_line["text"]), str(log_line["tone"]))
		line["hex"] = log_line["hex"]
		line["sub"] = true
		out.append(line)
	return out


## The food line (sub) from the closed flows of grain and fish and the food need; {} without the closed goods of `turn`.
static func _food_line(game: Game, country: Country, turn: int) -> Dictionary:
	var closed := country.goods_closed
	if int(closed.get("turn", -1)) != turn:
		return {}
	var flows := closed.get("flows", PackedInt32Array()) as PackedInt32Array
	var closing := closed.get("closing", PackedInt32Array()) as PackedInt32Array
	var count := closing.size()
	var made := 0
	var eaten := 0
	var left := 0
	for key: StringName in [&"grain", &"fish"]:
		var g := game.defs.good_id(key)
		if g < 0 or g >= count:
			continue
		var at_made := Stores.FLOWS.find(&"made") * count + g
		var at_used := Stores.FLOWS.find(&"used") * count + g
		made += maxi(flows[at_made], 0) if at_made < flows.size() else 0
		eaten += absi(flows[at_used]) if at_used < flows.size() else 0
		left += closing[g]
	var need := country.food_need
	if made == 0 and eaten == 0 and need == 0:
		return {}
	var text := ""
	var tone := "good"
	if country.food_fed < 1000:
		var lost := 0
		var flows_p: Variant = country.people_closed.get("flows", null)
		if flows_p is PackedInt32Array and (flows_p as PackedInt32Array).size() > People.STARVED:
			lost = -(flows_p as PackedInt32Array)[People.STARVED]
		text = "Food: %d made for %d needed. %d short: your towns lost %s to hunger." % [made, need, maxi(need - eaten, 0),
			Words.people(maxi(lost, 0))]
		tone = "bad"
	elif made >= eaten:
		text = "Food: %d made for %d eaten. Fed, %d to spare." % [made, eaten, made - eaten]
	else:
		text = "Food: %d made for %d eaten. Fed from the stores: %d left." % [made, eaten, left]
		tone = "warn"
	var line := _line(text, tone)
	line["sub"] = true
	return line


static func _tone_of(amount: int) -> String:
	return "good" if amount > 0 else ("bad" if amount < 0 else "plain")


static func _line(text: String, tone: String, rank: int = 0) -> Dictionary:
	return {
		"text": text, "detail": "", "amount": 0, "unit": &"", "tone": tone, "value": 0, "from": 0, "to": 0,
		"hex": WorksView.NO_HEX, "rank": rank, "top": false, "sub": false, "action": [], "action_label": "",
	}
