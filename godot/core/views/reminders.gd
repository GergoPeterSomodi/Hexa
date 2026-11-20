## What is still to do this season, as lines for the task flag and the report's "Before" section
## (docs/architecture/m3-build-spec.md 4.8, 5.6; docs/architecture/m4-build-spec.md 4.18). Five rules: an empty treasury and
## a need that will run out (severity 2 or 1), winter stops works in the snow (2), a treasury that will fall (1) and a free
## work slot (1). Pure core/views/ code: reads the game (and EconomyPreview, which writes only the view cache), writes nothing.
class_name Reminders
extends RefCounted

const RULES: Array[StringName] = [&"treasury_empty", &"goods_running_out", &"winter_halt", &"treasury_falling", &"free_slot"]
## The seasons `goods_running_out` looks ahead (spec 4.18).
const WINDOW := 8
## Food that runs out within this many seasons is serious (severity 2).
const FOOD_SERIOUS := 2
## The study's economy page: the action of the money rules.
const STUDY_ACTION: Array = [&"study", &"economy"]


## Lines worst first (severity descending, then the order of RULES): {kind, severity, text, hint, action: Array,
## action_label, hex}. Cached in game.view_cache by [&"reminders", game.version, game.turn, tag].
static func unfinished(game: Game, tag: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null or game.state == null:
		return out
	var key: Array = [&"reminders", game.version, game.turn, tag]
	var cached: Variant = game.view_cache.get_or_make(key, func() -> Array[Dictionary]: return _build(game, tag))
	out.assign((cached as Array).duplicate(true))  # the cache is shared: a caller gets its own copy
	return out


static func _build(game: Game, tag: StringName) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for rule: StringName in RULES:
		match rule:
			&"treasury_empty":
				_add(lines, treasury_empty(game, tag))
			&"goods_running_out":
				lines.append_array(goods_running_out(game, tag))
			&"winter_halt":
				_add(lines, winter_halt(game, tag))
			&"treasury_falling":
				_add(lines, treasury_falling(game, tag))
			&"free_slot":
				_add(lines, free_slot(game, tag))
	# A stable sort: equal severities keep the order of RULES.
	var ordered: Array[Dictionary] = []
	for severity: int in [2, 1, 0]:
		for line: Dictionary in lines:
			if int(line["severity"]) == severity:
				ordered.append(line)
	return ordered


static func _add(lines: Array[Dictionary], line: Dictionary) -> void:
	if not line.is_empty():
		lines.append(line)


## {} when it does not apply: the treasury of `tag` is under 0 (4.18, severity 2).
static func treasury_empty(game: Game, tag: StringName) -> Dictionary:
	var country := _country(game, tag)
	if country == null or country.treasury >= 0:
		return {}
	return {
		"kind": &"treasury_empty", "severity": 2, "hint": "", "hex": WorksView.NO_HEX,
		"text": "The treasury is empty: %s owed. Upkeep is still paid; no work can begin." % Words.ducats(-country.treasury),
		"action": STUDY_ACTION.duplicate(), "action_label": "Open the study",
	}


## {} when it does not apply: the treasury of `tag` is 0 or more and the season in play (calm, EconomyPreview.expected)
## spends more than it earns, its works left out (4.18, severity 1).
static func treasury_falling(game: Game, tag: StringName) -> Dictionary:
	var country := _country(game, tag)
	if country == null or country.treasury < 0:
		return {}
	var net := int(EconomyPreview.expected(game, tag).get("net", 0))
	if net >= 0:
		return {}
	return {
		"kind": &"treasury_falling", "severity": 1, "hint": "", "hex": WorksView.NO_HEX,
		"text": "The treasury will fall by %s this season." % Words.ducats(-net),
		"action": STUDY_ACTION.duplicate(), "action_label": "Open the study",
	}


## One line for each need (food, wine, salt, oil, in that order) that the next WINDOW seasons (EconomyPreview, calm
## weather) leave not fully met: "Wine runs out in 4 seasons; the first vintage is Autumn 1481." when the land makes it
## only after that season, "...; none of your land makes it." when it makes none in the window, no second part when it
## already makes some. Severity 2 for food within FOOD_SERIOUS seasons, else 1. The action looks at the first district,
## else the first work under way within the window, that makes the need; else at the capital.
static func goods_running_out(game: Game, tag: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var country := _country(game, tag)
	if country == null or not country.alive or game.defs.goods.is_empty():
		return out
	var seasons: Array = EconomyPreview.with(game, tag, {}, WINDOW)["seasons"]
	for need: StringName in EconomySeason.NEEDS:
		var goods := _goods_of(game, need)
		var short := 0
		var made := 0
		var made_good := -1
		for k: int in seasons.size():
			var entry: Dictionary = seasons[k]
			if made == 0:
				for g: int in goods:
					if int((entry["made"] as PackedInt32Array)[g]) > 0:
						made = k + 1
						made_good = g
						break
			if short == 0:
				var needs := EconomySeason.needs_for(game, int(entry["town"]))
				if _taken(goods, entry["used"] as PackedInt32Array) < int(needs[String(need)]):
					short = k + 1
		if short > 0:
			out.append(_running_out_line(game, country, need, goods, seasons, short, made, made_good))
	return out


static func _running_out_line(game: Game, country: Country, need: StringName, goods: Array[int], seasons: Array, short: int,
		made: int, made_good: int) -> Dictionary:
	var name := "Food" if need == &"food" else game.defs.goods[game.defs.good_id(need)].name
	var text := "%s runs out next season" % name if short == 1 else "%s runs out in %d seasons" % [name, short]
	if made == 0:
		text += "; none of your land makes it."
	elif made > short:
		var word := game.defs.goods[made_good].harvest_word
		text += "; the first %s is %s." % [word if not word.is_empty() else "harvest",
			Calendar.date_text(int((seasons[made - 1] as Dictionary)["turn"]), game.start_year)]
	else:
		text += "."
	var line := {
		"kind": &"goods_running_out", "severity": 2 if need == &"food" and short <= FOOD_SERIOUS else 1, "text": text,
		"hint": "", "action": [], "action_label": "", "hex": WorksView.NO_HEX,
	}
	var hex := _maker(game, country, goods, game.turn + WINDOW - 1)
	if hex != WorksView.NO_HEX:
		line["action"] = [&"look_at", hex]
		line["action_label"] = "Go to (%d, %d)" % [hex.x, hex.y]
		line["hex"] = hex
	else:
		var link := capital_link(game, country.tag)
		line["action"] = link["action"]
		line["action_label"] = link["action_label"]
		line["hex"] = link["hex"]
	return line


## The good ids a need is met from: food is every food good, another need its own good.
static func _goods_of(game: Game, need: StringName) -> Array[int]:
	var out: Array[int] = []
	for g: int in game.defs.goods.size():
		var def := game.defs.goods[g]
		if (need == &"food" and def.kind == &"food") or (need != &"food" and def.key == need):
			out.append(g)
	return out


## The loads of `goods` the towns took in a season (`used`, positive loads by good id).
static func _taken(goods: Array[int], used: PackedInt32Array) -> int:
	var total := 0
	for g: int in goods:
		total += used[g] if g < used.size() else 0
	return total


## The first land hex of the country that makes one of `goods` now, else the hex of the first work (by ready turn, then
## id) standing by `last_turn` that will; NO_HEX when none.
static func _maker(game: Game, country: Country, goods: Array[int], last_turn: int) -> Vector2i:
	var view := StateView.of(game.state)
	for i: int in Territory.districts(game, country.id):
		var base := game.districts.base_of(game, i) if game.districts != null else Economy.district_base(game, view, game.map.hex_of(i))
		if goods.has(int(base["good"])):
			return game.map.hex_of(i)
	var best: Work = null
	var best_ready := 0
	for work: Work in game.state.works:
		var i := game.map.index_of(work.hex)
		if work.tag != country.tag or work.action == Works.CLEAR or i < 0:
			continue
		var ready := Works.ready_turn(game, work)
		if ready > last_turn or (best != null and (ready > best_ready or (ready == best_ready and work.id > best.id))):
			continue
		var base := Economy.district_base(game, view.with({i: Vector2i(work.family, work.level_to)}), work.hex)
		if goods.has(int(base["good"])):
			best = work
			best_ready = ready
	return best.hex if best != null else WorksView.NO_HEX


## The country of `tag` in a game with countries; null otherwise.
static func _country(game: Game, tag: StringName) -> Country:
	if game == null or game.state == null or game.defs == null or not game.has_countries():
		return null
	return Countries.by_tag(game, tag)


## {} when it does not apply: the current season is Autumn and some work of `tag` stands on a hex that the coming winter
## stops (snow climate, the rule on in the definitions).
static func winter_halt(game: Game, tag: StringName) -> Dictionary:
	if game == null or game.state == null or Calendar.season_of(game.turn) != Calendar.AUTUMN:
		return {}
	var items: Array[String] = []
	var first := WorksView.NO_HEX
	for work: Work in game.state.works:
		if work.tag != tag or not Works.halted(game, work, game.turn + 1):
			continue
		if items.is_empty():
			first = work.hex
		items.append(WorksView.line(game, work))
	if items.is_empty():
		return {}
	var count := items.size()
	var text := "Winter comes: %d work in the snow stops until spring: %s." if count == 1 \
			else "Winter comes: %d works in the snow stop until spring: %s."
	return {
		"kind": &"winter_halt", "severity": 2, "text": text % [count, Words.list(items, 2, "; ")], "hint": "",
		"action": [&"look_at", first], "action_label": "Go to (%d, %d)" % [first.x, first.y], "hex": first,
	}


## {} when it does not apply: a game with countries, `tag` a country with fewer works under way than slots.
static func free_slot(game: Game, tag: StringName) -> Dictionary:
	if game == null or game.state == null or not game.has_countries():
		return {}
	var country := Countries.by_tag(game, tag)
	if country == null:
		return {}
	var slots := WorksView.slots(game, tag)
	var total := int(slots["total"])
	var used := int(slots["used"])
	if total < 0 or used >= total:
		return {}
	var link := capital_link(game, tag)
	return {
		"kind": &"free_slot", "severity": 1, "text": "A work slot is free: %d of %d in use." % [used, total], "hint": "",
		"action": link["action"], "action_label": link["action_label"], "hex": link["hex"],
	}


## {action, action_label, hex} that looks at the capital of `tag`: [&"look_at", capital], "Show Genoa"; no action
## (an empty list and label) when the country or its capital is missing.
static func capital_link(game: Game, tag: StringName) -> Dictionary:
	var country := Countries.by_tag(game, tag)
	if country == null or country.capital == Country.NO_HEX:
		return {"action": [], "action_label": "", "hex": WorksView.NO_HEX}
	var def := Countries.def_of(game, tag)
	var name := def.capital_name if def != null else ""
	if name.is_empty():
		var place := game.map.place_id[game.map.index_of(country.capital)] if game.map.index_of(country.capital) >= 0 else -1
		name = str(game.map.places[place].get("name", "")) if place >= 0 and place < game.map.places.size() else ""
	if name.is_empty():
		name = "the capital"
	return {"action": [&"look_at", country.capital], "action_label": "Show %s" % name, "hex": country.capital}
