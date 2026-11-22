## What is still to do this season, as lines for the task flag and the report's "Before" section
## (docs/architecture/m3-build-spec.md 4.8, 5.6; docs/architecture/m4-build-spec.md 4.18). Eleven rules: an empty treasury, hunger
## and a need that will run out (severity 2 or 1), winter stops works in the snow (2), a treasury that will fall (1), a
## full town (1) and a free work slot (1) (docs/architecture/m5-build-spec.md 4.14) and four army rules (docs/architecture/m6-build-spec.md 4.15). Pure core/views/ code: reads the game (and EconomyPreview, which writes only the view cache), writes nothing.
class_name Reminders
extends RefCounted

const RULES: Array[StringName] = [&"treasury_empty", &"hunger", &"army_hungry", &"army_stores",
	&"goods_running_out", &"winter_halt", &"winter_passes", &"treasury_falling", &"town_full",
	&"army_idle", &"free_slot"]
## The seasons `goods_running_out` looks ahead (spec 4.18).
const WINDOW := 8
## Food that runs out within this many seasons is serious (severity 2).
const FOOD_SERIOUS := 2
## The study's economy page: the action of the money rules.
const STUDY_ACTION: Array = [&"study", &"economy"]
## The study's people page: the action of `hunger`.
const PEOPLE_ACTION: Array = [&"study", &"people"]
## The study's military page: the action of `army_stores`.
const MILITARY_ACTION: Array = [&"study", &"military"]
## A hunger line is of a season whose towns ate under this many permille of their need.
const FED_FULL := 1000


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
			&"hunger":
				_add(lines, hunger(game, tag))
			&"goods_running_out":
				lines.append_array(goods_running_out(game, tag))
			&"winter_halt":
				_add(lines, winter_halt(game, tag))
			&"treasury_falling":
				_add(lines, treasury_falling(game, tag))
			&"town_full":
				_add(lines, town_full(game, tag))
			&"army_hungry":
				lines.append_array(army_hungry(game, tag))
			&"army_stores":
				_add(lines, army_stores(game, tag))
			&"winter_passes":
				_add(lines, winter_passes(game, tag))
			&"army_idle":
				_add(lines, army_idle(game, tag))
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


## {} when it does not apply: the towns of `tag` ate under their need in the last season ended (severity 2): "Your towns
## went hungry: 8 of 9 food. They lose people each season until they are fed."
static func hunger(game: Game, tag: StringName) -> Dictionary:
	var country := _country(game, tag)
	if country == null or not country.alive or country.food_fed >= FED_FULL or country.food_need <= 0:
		return {}
	@warning_ignore("integer_division")
	var eaten := country.food_need * country.food_fed / 1000
	var closed := country.goods_closed
	var flows := closed.get("flows", PackedInt32Array()) as PackedInt32Array
	var closing := closed.get("closing", PackedInt32Array()) as PackedInt32Array
	if int(closed.get("turn", -1)) == game.turn - 1 and not closing.is_empty():
		eaten = 0  # the closed flows say exactly how much was eaten
		for key: StringName in [&"grain", &"fish"]:
			var g := game.defs.good_id(key)
			var at := Stores.FLOWS.find(&"used") * closing.size() + g
			if g >= 0 and g < closing.size() and at < flows.size():
				eaten += absi(flows[at])
	return {
		"kind": &"hunger", "severity": 2, "hint": "", "hex": WorksView.NO_HEX,
		"text": "Your towns went hungry: %d of %d food. They lose people each season until they are fed." % [
			mini(eaten, country.food_need), country.food_need],
		"action": PEOPLE_ACTION.duplicate(), "action_label": "Open People",
	}


## {} when it does not apply: a settlement of `tag` at its room whose next level only a work gives (a level from
## people_top_level up, short of a city) and with no work under way there (severity 1); the action looks at the first.
static func town_full(game: Game, tag: StringName) -> Dictionary:
	var country := _country(game, tag)
	if country == null or not country.alive or game.districts == null:
		return {}
	var top := game.defs.people_top_level
	var open := game.districts.open_hexes(game)
	var keys := open.keys()
	keys.sort()
	var names: Array[String] = []
	var first := WorksView.NO_HEX
	var first_text := ""
	var city := FamilyIds.LEVEL_WORDS["settlements"].size() - 1  # no work gives more than the top level
	for i: int in keys:
		var level := int(game.state.level[i])
		var mine := int(game.state.owner[i]) == country.id and int(game.state.main_use[i]) == People.SETTLEMENTS
		if not mine or level < top or level >= city or int(game.state.people[i]) < int(open[i]):
			continue
		var hex := game.map.hex_of(i)
		if game.state.work_at(hex) != null:
			continue
		var place := Words.settlement(game, hex, level)
		names.append(place)
		if first == WorksView.NO_HEX:
			first = hex
			first_text = "%s is full at %s people: %s would give it room." % [place, Words.number(int(game.state.people[i])),
				"walls" if level + 1 == 4 else "a city"]
	if names.is_empty():
		return {}
	var text := first_text
	if names.size() > 1:  # the names hold commas ("Savona (6, 13)"): the list is joined with semicolons
		text = "%d towns are full: %s." % [names.size(), Words.list(names, names.size(), "; ")]
	var at := names[0].rfind(" (")
	return {
		"kind": &"town_full", "severity": 1, "hint": "", "text": text, "hex": first,
		"action": [&"look_at", first], "action_label": "Go to %s" % (names[0].left(at) if at > 0 else names[0]),
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
		if ready == Works.NO_DATE or ready > last_turn or (best != null and (ready > best_ready or (ready == best_ready and work.id > best.id))):
			continue
		var base := Economy.district_base(game, view.with({i: Vector2i(work.family, work.level_to)}), work.hex)
		if goods.has(int(base["good"])):
			best = work
			best_ready = ready
	return best.hex if best != null else WorksView.NO_HEX


## The hunger reminders of the armies of `tag` (docs/architecture/m6-build-spec.md 4.15; severity 2). An army out of supply now
## is named when it lost men in the last supply phase, or when the end hex of this season's walk is not in supply: "The Army of
## Turin at Turin (5, 9) is out of supply: it lost 100 men and will lose about 90 more." (two or more: "2 armies are out of
## supply: ..."). An army in supply that lost men (its stores ran out) is named too: "The Army of Turin at Turin (5, 9) lost 100 men
## to hunger: the stores are empty." An army out of supply whose walk ends in supply, with no losses, is not named. The action
## selects the first army named.
static func army_hungry(game: Game, tag: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null or game.state == null or tag == &"":
		return out
	var winter := Calendar.is_winter(game.turn)
	var out_now: Array[Army] = []
	for a: Army in Armies.of_country(game, tag):
		if Supply.in_supply(game, tag, a.hex, winter):
			if a.lost_last > 0:
				out.append(_starving_line(game, a))
			continue
		if a.lost_last > 0 or not Supply.in_supply(game, tag, season_end(game, a), winter):
			out_now.append(a)
	if not out_now.is_empty():
		out.push_front(_out_of_supply_line(game, tag, out_now))
	return out


## The hex where `a` stands at the end of this season's walk (Movement.walk_plan's first stop): its hex when it does not march
## or does not move this season.
static func season_end(game: Game, a: Army) -> Vector2i:
	if a.order != Army.ORDER_MARCH or a.route.is_empty() or a.mustering(game.turn):
		return a.hex
	var stops: Array = Movement.walk_plan(game, a, a.route, game.turn).get("stops", [])
	if stops.is_empty():
		return a.hex
	var now := int((stops[0] as Dictionary)["index"])
	return game.map.hex_of(int(a.route[now - 1])) if now > 0 else a.hex


static func _out_of_supply_line(game: Game, tag: StringName, hungry: Array[Army]) -> Dictionary:
	var first := hungry[0]
	var text := ""
	if hungry.size() == 1:
		var more := Supply.starve_loss(game, first.hex, Calendar.season_of(game.turn), first.men())
		var place := "The %s %s is out of supply" % [first.name, Words.at(game, first.hex)]
		text = "%s: it lost %s men and will lose about %s more." % [place, Words.number(first.lost_last), Words.number(more)] \
			if first.lost_last > 0 else "%s: it will lose about %s men." % [place, Words.number(Supply.starve_loss(game, first.hex, Calendar.season_of(game.turn), first.men()))]
	else:
		var names: Array[String] = []
		for a: Army in hungry:
			names.append("the " + a.name)
		text = "%s armies are out of supply: %s." % [Words.number(hungry.size()), Words.list(names, 2)]
	return {
		"kind": &"army_hungry", "severity": 2, "text": text, "hint": "", "hex": first.hex,
		"action": [&"select_army", first.id], "action_label": "Show the army",
	}


static func _starving_line(game: Game, a: Army) -> Dictionary:
	return {
		"kind": &"army_hungry", "severity": 2, "hint": "", "hex": a.hex,
		"text": "The %s %s lost %s men to hunger: the stores are empty." % [a.name, Words.at(game, a.hex), Words.number(a.lost_last)],
		"action": [&"select_army", a.id], "action_label": "Show the army",
	}


## {} when it does not apply: the grain and fish in the store of `tag` are under the food its supplied armies eat this season
## (Supply.army_food; severity 2): "Your stores cannot feed your armies: 0 grain and fish for 1 needed. Unfed men starve."
static func army_stores(game: Game, tag: StringName) -> Dictionary:
	var country := _country(game, tag)
	if country == null:
		return {}
	var need := Supply.army_food(game, tag)
	var stock := 0
	for key: StringName in [&"grain", &"fish"]:
		var g := game.defs.good_id(key)
		if g >= 0 and g < country.stock.size():
			stock += country.stock[g]
	if need <= 0 or stock >= need:
		return {}
	return {
		"kind": &"army_stores", "severity": 2, "hint": "", "hex": WorksView.NO_HEX,
		"text": "Your stores cannot feed your armies: %s grain and fish for %s needed. Unfed men starve." % [
			Words.number(stock), Words.number(need)],
		"action": MILITARY_ACTION.duplicate(), "action_label": "Open Military",
	}


## {} when it does not apply: it is Autumn and a march of `tag` stops this season short of its goal and will wait in Winter at a
## pass that winter closes (its walk does not move in the winter season, and the next step crosses a pass; severity 1): "Winter
## closes the Little St Bernard: the Army of Turin waits for spring at (3, 7) near Hospice Little St Bernard unless it crosses this
## season." The walk is Movement.walk_plan of the stored route (4.13 (c)). The action selects the army.
static func winter_passes(game: Game, tag: StringName) -> Dictionary:
	if game == null or game.state == null or Calendar.season_of(game.turn) != Calendar.AUTUMN or not Calendar.is_winter(game.turn + 1):
		return {}
	for a: Army in Armies.of_country(game, tag):
		if a.order != Army.ORDER_MARCH or a.route.is_empty() or a.mustering(game.turn):
			continue
		var stops: Array = Movement.walk_plan(game, a, a.route, game.turn).get("stops", [])
		if stops.size() < 2:
			continue
		var now := int((stops[0] as Dictionary)["index"])
		if int((stops[1] as Dictionary)["index"]) != now or now >= a.route.size():
			continue  # the walk goes on in winter: nothing waits
		var at := game.map.index_of(a.hex) if now == 0 else int(a.route[now - 1])
		var pass_name := Movement.pass_name(game.map, at, int(a.route[now]))
		if pass_name.is_empty():
			continue  # held by the snow, not by a pass
		return {
			"kind": &"winter_passes", "severity": 1, "hint": "", "hex": game.map.hex_of(at),
			"text": "Winter closes the %s: the %s waits for spring %s unless it crosses this season." % [
				pass_name, a.name, Words.at(game, game.map.hex_of(at))],
			"action": [&"select_army", a.id], "action_label": "Show the army",
		}
	return {}


## {} when it does not apply: an army of `tag` has no order (new, or halted; severity 1): "1 army awaits orders: the Army of
## Turin at Turin (5, 9)." or "2 armies wait for orders: the Army of Turin and the Second Army of Turin." The action selects the first.
static func army_idle(game: Game, tag: StringName) -> Dictionary:
	if game == null or game.state == null or tag == &"":
		return {}
	var idle: Array[Army] = []
	for a: Army in Armies.of_country(game, tag):
		if a.order == Army.ORDER_NONE:
			idle.append(a)
	if idle.is_empty():
		return {}
	var first := idle[0]
	var text := ""
	if idle.size() == 1:
		text = "1 army awaits orders: the %s %s." % [first.name, Words.at(game, first.hex)]
	else:
		var names: Array[String] = []
		for a: Army in idle:
			names.append("the " + a.name)
		text = "%s armies wait for orders: %s." % [Words.number(idle.size()), Words.list(names, 2)]
	return {
		"kind": &"army_idle", "severity": 1, "text": text, "hint": "", "hex": first.hex,
		"action": [&"select_army", first.id], "action_label": "Show the army",
	}


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
