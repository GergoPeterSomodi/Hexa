## What is still to do this season, as lines for the task flag and the report's "Before" section
## (docs/architecture/m3-build-spec.md 4.8, 5.6). Two rules in M3: winter stops works in the snow (severity 2) and a free
## work slot (severity 1). Pure core/views/ code: reads the game, writes nothing.
class_name Reminders
extends RefCounted

const RULES: Array[StringName] = [&"winter_halt", &"free_slot"]


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
		var line := {}
		match rule:
			&"winter_halt":
				line = winter_halt(game, tag)
			&"free_slot":
				line = free_slot(game, tag)
		if not line.is_empty():
			lines.append(line)
	# A stable sort: equal severities keep the order of RULES.
	var ordered: Array[Dictionary] = []
	for severity: int in [2, 1, 0]:
		for line: Dictionary in lines:
			if int(line["severity"]) == severity:
				ordered.append(line)
	return ordered


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
