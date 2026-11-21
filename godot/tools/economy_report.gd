## The economy report (docs/architecture/m4-build-plan.md N10): plays seasons of "Italy, 1480" for a seed, with no actions or
## seeded random ones for every country, and prints per country the treasury, the season's income lines added up over the
## run and the goods in store, and (M5) a second table of the people: people and towns at the start and the end, the people
## that starved, the seasons the towns went hungry, the levels gained and lost. For Opus's review of the numbers (spec 4.2 to 4.12) and the owner. Headless, no GUT.
##
##   godot --headless --path godot -s res://tools/economy_report.gd -- [--seed=1480 | --seeds=1480-1484] [--seasons=12]
##       [--actions=none|random] [--weather=real|calm]
extends SceneTree

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"
const LINES: Array[StringName] = [&"tax_people", &"tax_goods", &"port_dues", &"upkeep_districts", &"upkeep_walls", &"work", &"refund", &"dev"]

var _seeds: Array[int] = [1480]
var _seasons := 12
var _random := false
var _calm := false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_seeds = [int(arg.substr(7))]
		elif arg.begins_with("--seeds="):
			var parts := arg.substr(8).split("-")
			_seeds = []
			for s: int in range(int(parts[0]), int(parts[parts.size() - 1]) + 1):
				_seeds.append(s)
		elif arg.begins_with("--seasons="):
			_seasons = maxi(int(arg.substr(10)), 1)
		elif arg.begins_with("--actions="):
			_random = arg.substr(10) == "random"
		elif arg.begins_with("--weather="):
			_calm = arg.substr(10) == "calm"
	for s: int in _seeds:
		print(_report(s))
	quit()


func _report(seed_value: int) -> String:
	var defs := (ResourceLoader.load(DEFS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs).duplicate() as GameDefs
	if _calm:
		defs.weather_odds = PackedInt32Array([100, 0, 0])
	var map := ResourceLoader.load(MAP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as MapData
	var g := Game.new_scenario(map, defs, defs.scenarios[defs.scenarios.size() - 1], seed_value)
	g.act("choose_country", {"tag": &"GEN"})
	var luck := Rng.new()
	luck.seed_with(seed_value)
	var start := {}
	var sums := {}
	var people := {}
	for c: Country in g.countries:
		start[c.tag] = c.treasury
		sums[c.tag] = {}
		people[c.tag] = {"people": _people(g, c.id, false), "towns": _people(g, c.id, true), "hungry": 0, "starved": 0, "gained": 0, "lost": 0}
	for n: int in _seasons:
		if _random:
			for c: Country in g.countries:
				_act(g, c, luck, n)
		g.events.clear()
		Season.run(g)
		for e: Dictionary in g.events:
			var kind := str(e.get("kind", ""))
			if (kind == "town_grew" or kind == "district_declined") and people.has(e["tag"]):
				var counts := people[e["tag"]] as Dictionary
				counts["gained" if kind == "town_grew" else "lost"] += 1
		for c: Country in g.countries:
			var counts := people[c.tag] as Dictionary
			if c.food_fed < 1000:
				counts["hungry"] += 1
			if c.people_closed.has("flows"):
				counts["starved"] -= int((c.people_closed["flows"] as PackedInt32Array)[People.STARVED])
			for line: Dictionary in c.ledger_closed["lines"] as Array:
				var d := sums[c.tag] as Dictionary
				d[line["why"]] = int(d.get(line["why"], 0)) + int(line["amount"])
	var text := "## Economy report: seed %d, %d seasons (%s), %s weather\n\n" % [
		seed_value, _seasons, "random works, cancels, taxes" if _random else "no actions", "calm" if _calm else "real"]
	text += "| Tag | start | treasury | net | tax people | tax goods | dues | upkeep | walls | work | refund | dev | tax | stores (good:loads) |\n"
	text += "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n"
	for c: Country in g.countries:
		var d := sums[c.tag] as Dictionary
		var row := PackedStringArray([String(c.tag), str(start[c.tag]), str(c.treasury), str(c.treasury - int(start[c.tag]))])
		for why: StringName in LINES:
			row.append(str(int(d.get(why, 0))))
		row.append(EconomySeason.TAX_NAMES[c.tax])
		row.append(_stores(g, c))
		text += "| " + " | ".join(row) + " |\n"
	text += "\n| Tag | people start | people end | towns start | towns end | starved | hungry seasons | levels gained | levels lost | grain | fish | fed now |\n"
	text += "|---|---|---|---|---|---|---|---|---|---|---|---|\n"
	var grain := g.defs.good_id(&"grain")
	var fish := g.defs.good_id(&"fish")
	for c: Country in g.countries:
		var p := people[c.tag] as Dictionary
		text += "| %s | %d | %d | %d | %d | %d | %d of %d | %d | %d | %d | %d | %d |\n" % [String(c.tag), p["people"], _people(g, c.id, false),
			p["towns"], _people(g, c.id, true), p["starved"], p["hungry"], _seasons, p["gained"], p["lost"], c.stock[grain], c.stock[fish], c.food_fed]
	return text


## The people of a country's land (or of its settlements only).
func _people(g: Game, id: int, towns_only: bool) -> int:
	var total := 0
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1 and int(g.state.owner[i]) == id and (not towns_only or g.state.main_use[i] == Economy.SETTLEMENTS):
			total += g.state.people[i]
	return total


func _stores(g: Game, c: Country) -> String:
	var parts := PackedStringArray()
	for i: int in c.stock.size():
		if c.stock[i] != 0:
			parts.append("%s:%d" % [String(g.defs.good(i).key), c.stock[i]])
	return " ".join(parts)


## Some money, a work begun or cancelled, now and then a tax change (the same kinds of action as the money property).
func _act(g: Game, c: Country, luck: Rng, n: int) -> void:
	if luck.randi_range(0, 3) == 0:
		g.dev_money(c.tag, luck.randi_range(50, 300))
	var districts := Territory.districts(g, c.id)
	if not districts.is_empty() and luck.randi_range(0, 1) == 0:
		var hex := g.map.hex_of(districts[luck.randi_range(0, districts.size() - 1)])
		var options: Array[Dictionary] = []
		for o: Dictionary in g.improvement.build_options(hex):
			if bool(o["ok"]):
				options.append(o)
		if not options.is_empty():
			g.act("build", {"hex": hex, "family": int(options[luck.randi_range(0, options.size() - 1)]["family_id"]), "tag": c.tag})
	if n % 5 == 4 and luck.randi_range(0, 1) == 0:
		g.act("set_tax", {"level": luck.randi_range(0, 2), "tag": c.tag})
	for w: Work in g.state.works:
		if w.tag == c.tag and luck.randi_range(0, 9) == 0:
			g.act("cancel_work", {"hex": w.hex, "tag": c.tag})
			break
