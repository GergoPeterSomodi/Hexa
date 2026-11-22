## The war report (docs/architecture/m7-build-spec.md 4.6, 4.5, 10 and D50; M7 plan B18): plays seasons of "Italy, 1480" for each
## seed with the wars staged at turn 1 (the lowest-id neighbour pairs, each pair once, through the door: declare_war) and, unless
## --armies=march (default), every country's armies are raised on its land (PerfFixture.seed_armies) and one in two of the armies
## of a country at war marches at the nearest enemy (PerfFixture.war_march) each season. Unless
## --actions=none, seeded random picks (RandomPlayer, --picks each) for every country every season. Per seed it prints per country:
## the live wars, the score against its enemies (Wars.score summed), the districts it holds of its enemies and that they hold of
## it, the fortresses it controls, the garrison men in them, and its men under arms; then the battles (their outcomes, who won,
## the causes of the end, the assaults, the mean days) and the sieges (started, lifted by cause, fallen). --picks is the random
## picks a country makes a season (8). The numbers are data
## for Opus's balance gate before group F and the owner; no rule reads them. Headless, no GUT.
##
##   godot --headless --path godot -s res://tools/war_report.gd -- [--seed=1480 | --seeds=1480-1484] [--seasons=12] [--wars=6]
##       [--picks=8] [--armies=march|none] [--actions=none|random] [--weather=calm|real]
extends SceneTree

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"
const PLAYER := &"GEN"

var _seeds: Array[int] = [1480, 1481, 1482, 1483, 1484]
var _seasons := 12
var _wars := 6
var _random := true
var _picks := 8
var _armies := true
var _calm := true


func _initialize() -> void:  # not _init: the classes are known to the parser only from here on
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
		elif arg.begins_with("--armies="):
			_armies = arg.substr(9) != "none"
		elif arg.begins_with("--picks="):
			_picks = maxi(int(arg.substr(8)), 0)
		elif arg.begins_with("--wars="):
			_wars = maxi(int(arg.substr(7)), 0)
		elif arg.begins_with("--actions="):
			_random = arg.substr(10) != "none"
		elif arg.begins_with("--weather="):
			_calm = arg.substr(10) != "real"
	var totals := {"battles": 0, "attackers": 0, "defenders": 0, "sieges": 0, "falls": 0, "assaults": 0}
	for s: int in _seeds:
		print(_report(s, totals))
	print("## Totals over %d seeds: %d battles (attacker won %d, defender won %d; %d assaults), %d sieges started, %d fallen" % [
		_seeds.size(), totals["battles"], totals["attackers"], totals["defenders"], totals["assaults"], totals["sieges"], totals["falls"]])
	quit()


func _report(seed_value: int, totals: Dictionary) -> String:
	var defs := (ResourceLoader.load(DEFS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs).duplicate() as GameDefs
	if _calm:
		defs.weather_odds = PackedInt32Array([100, 0, 0])
	var map := ResourceLoader.load(MAP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as MapData
	var g := Game.new_scenario(map, defs, defs.scenarios[defs.scenarios.size() - 1], seed_value)
	g.act("choose_country", {"tag": PLAYER})
	var staged := _stage_wars(g)
	var luck := Rng.new()
	luck.seed_with(seed_value)
	var armies := PerfFixture.seed_armies(g, luck) if _armies else [] as Array[Army]
	var fought := {"battles": 0, "attackers": 0, "defenders": 0, "assaults": 0, "days": 0}
	var hows := {}
	var lifts := {}
	var captures := {}
	var sieges := 0
	var last_id := 0
	for n: int in _seasons:
		if _armies:
			PerfFixture.rearm(g, luck, armies)
			PerfFixture.war_march(g, armies, luck)
		if _random:
			for c: Country in g.countries:
				for _t: int in _picks:
					var pick: Dictionary = RandomPlayer.next(g, c.tag, luck)
					g.act(str(pick["action"]), pick["args"])
		g.events.clear()
		Season.run(g)
		for e: Dictionary in g.events:
			var kind := str(e.get("kind", ""))
			if kind == Sieges.SIEGE_STARTED:
				sieges += 1
			elif kind == Sieges.SIEGE_LIFTED:
				lifts[str(e.get("why", ""))] = int(lifts.get(str(e.get("why", "")), 0)) + 1
			elif kind == Occupation.DISTRICT_CAPTURED:
				captures[str(e.get("by", ""))] = int(captures.get(str(e.get("by", "")), 0)) + 1
		for r: BattleRecord in g.battle_records:
			if r.id <= last_id:
				continue
			last_id = maxi(last_id, r.id)
			fought["battles"] = int(fought["battles"]) + 1
			fought["days"] = int(fought["days"]) + int(r.end.get("days", 0))
			if bool(r.input.get("assault", false)):
				fought["assaults"] = int(fought["assaults"]) + 1
			if int(r.end.get("winner", -1)) == 0:
				fought["attackers"] = int(fought["attackers"]) + 1
			elif int(r.end.get("winner", -1)) == 1:
				fought["defenders"] = int(fought["defenders"]) + 1
			var how := str(r.end.get("how", ""))
			hows[how] = int(hows.get(how, 0)) + 1
	totals["battles"] = int(totals["battles"]) + int(fought["battles"])
	totals["attackers"] = int(totals["attackers"]) + int(fought["attackers"])
	totals["defenders"] = int(totals["defenders"]) + int(fought["defenders"])
	totals["assaults"] = int(totals["assaults"]) + int(fought["assaults"])
	totals["sieges"] = int(totals["sieges"]) + sieges
	var falls := 0
	for by: String in captures:
		if by == "siege":
			falls += int(captures[by])
	totals["falls"] = int(totals["falls"]) + falls
	var out := "## War report, Italy 1480, seed %d, %s weather, %d seasons, %d wars staged, %s\n\n" % [seed_value,
		"calm" if _calm else "real", _seasons, staged, "random picks" if _random else "no picks"]
	out += "| Country | live wars | score | held of enemies | held by enemies | fortresses | garrison men | men under arms |\n"
	out += "|---|---|---|---|---|---|---|---|\n"
	for c: Country in g.countries:
		out += _row(g, c) + "\n"
	out += "\nBattles: %d (attacker won %d, defender won %d, assaults %d, mean days %.1f). Ends: %s.\n" % [
		int(fought["battles"]), int(fought["attackers"]), int(fought["defenders"]), int(fought["assaults"]),
		float(fought["days"]) / float(maxi(int(fought["battles"]), 1)), _pairs(hows)]
	out += "Sieges: %d started; lifted %s; fallen %d (captures by siege; captures by cause %s).\n" % [sieges, _pairs(lifts), falls,
		_pairs(captures)]
	return out


## Wars staged at turn 1: each country with a neighbour declares on its lowest-id neighbour, each pair once, up to _wars wars.
## Returns the number declared.
func _stage_wars(g: Game) -> int:
	var made := 0
	for a: Country in g.countries:
		if made >= _wars:
			break
		for id: int in Territory.neighbours(g, a.id):
			if made >= _wars:
				break
			var b := Countries.by_id(g, id)
			if b == null or b.id <= a.id or Wars.at_war(g, a.tag, b.tag):
				continue
			if bool(g.act("declare_war", {"target": b.tag, "tag": a.tag})["ok"]):
				made += 1
			break
	return made


## One country's row: its live wars, its score and its occupations against its enemies, its fortresses and their garrisons.
func _row(g: Game, c: Country) -> String:
	var live := 0
	for w: War in Wars.of_country(g, c.tag):
		if w.live():
			live += 1
	var score := 0
	var held := 0
	var held_by := 0
	for enemy: StringName in Wars.enemies(g, c.tag):
		score += Wars.score(g, c.tag, enemy)
		held += Wars.occupied_count(g, c.tag, enemy)
		held_by += Wars.occupied_count(g, enemy, c.tag)
	var fortresses := 0
	var garrison := 0
	for i: int in Occupation.controlled(g, c.id):
		var hex := g.map.hex_of(i)
		if Occupation.fortress_level(g, hex) > 0:
			fortresses += 1
			garrison += Occupation.garrison_of(g, hex)
	return "| %s | %d | %+d | %d | %d | %d | %d | %d |" % [String(c.tag), live, score, held, held_by, fortresses, garrison,
		Wars.men_under_arms(g, c.tag)]


## "a 3, b 1" in the key order, or "none".
func _pairs(counts: Dictionary) -> String:
	if counts.is_empty():
		return "none"
	var keys: Array = counts.keys()
	keys.sort()
	var parts: Array[String] = []
	for key: Variant in keys:
		parts.append("%s %d" % [str(key), int(counts[key])])
	return ", ".join(parts)
