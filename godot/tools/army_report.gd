## The army report (docs/architecture/m6-build-spec.md section 10, the balance risk of "armies feel slow or fast", L13): for
## every country of "Italy, 1480", its supply coverage in summer and winter (land hexes its supply field reaches, of its land),
## its raise capacity in one season (companies the towns can raise, and the men at hand in them), and the route seasons from
## its capital to its farthest town (a test army of one pikeman company, ordered by the door: Movement.plan and walk_plan).
## Opus reads it before group F (m6-build-plan.md); the numbers are data, not rules. Headless, no GUT.
##
##   godot --headless --path godot -s res://tools/army_report.gd -- [--seed=1480 | --seeds=1480-1484] [--weather=calm|real]
extends SceneTree

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"

var _seeds: Array[int] = [1480]
var _calm := true


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_seeds = [int(arg.substr(7))]
		elif arg.begins_with("--seeds="):
			var parts := arg.substr(8).split("-")
			_seeds = []
			for s: int in range(int(parts[0]), int(parts[parts.size() - 1]) + 1):
				_seeds.append(s)
		elif arg.begins_with("--weather="):
			_calm = arg.substr(10) != "real"
	for s: int in _seeds:
		print(_report(s))
	quit()


func _report(seed_value: int) -> String:
	var defs := (ResourceLoader.load(DEFS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs).duplicate() as GameDefs
	if _calm:
		defs.weather_odds = PackedInt32Array([100, 0, 0])
	var map := ResourceLoader.load(MAP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as MapData
	var g := Game.new_scenario(map, defs, defs.scenarios[defs.scenarios.size() - 1], seed_value)
	var out := "## Army report, Italy 1480, seed %d, %s weather (one pikeman company = %d men)\n\n" % [
		seed_value, "calm" if _calm else "real", _pikemen(g)]
	out += "| Country | land | summer supply | winter supply | towns | raise: companies a season | men at hand | route seasons, capital to farthest town |\n"
	out += "|---|---|---|---|---|---|---|---|\n"
	for c: Country in g.countries:
		out += _row(g, c) + "\n"
	return out


func _pikemen(g: Game) -> int:
	var ud := g.defs.unit_def(0)
	return ud.men if ud != null else 0


## One country's row: its supply coverage, its towns, its raise capacity and its farthest route.
func _row(g: Game, c: Country) -> String:
	var land := Territory.districts(g, c.id)
	var summer := _covered(g, c.tag, land, false)
	var winter := _covered(g, c.tag, land, true)
	var towns := 0
	var companies := 0
	var at_hand := 0
	for i: int in land:
		if g.state.main_use[i] != Economy.SETTLEMENTS:
			continue
		var hex := g.map.hex_of(i)
		towns += 1
		companies += Military.raise_cap(g, hex)
		at_hand += Military.men_at_hand(g, c.tag, hex)
	var far := _farthest(g, c, land)
	return "| %s | %d | %d (%d %%) | %d (%d %%) | %d | %d | %d | %s |" % [String(c.tag), land.size(), summer,
		_percent(summer, land.size()), winter, _percent(winter, land.size()), towns, companies, at_hand, far]


## Land hexes of the country (its own land) that its supply field reaches in the given rules.
func _covered(g: Game, tag: StringName, land: PackedInt32Array, winter: bool) -> int:
	var field := Supply.field(g, tag, winter)
	var n := 0
	for i: int in land:
		if i < field.size() and field[i] == 1:
			n += 1
	return n


func _percent(part: int, whole: int) -> int:
	return int(round(100.0 * float(part) / float(maxi(whole, 1))))


## The season count of a one-company test army from the capital to the country's farthest town ("" when none or no
## capital): the army is made through the door and removed again after the report reads it.
func _farthest(g: Game, c: Country, land: PackedInt32Array) -> String:
	if c.capital == Country.NO_HEX or not g.map.is_land(c.capital):
		return "no capital"
	var best := c.capital
	var best_d := -1
	for i: int in land:
		if g.state.main_use[i] != Economy.SETTLEMENTS:
			continue
		var hex := g.map.hex_of(i)
		var d := ImproveRules.hex_distance(hex, c.capital)
		if d > best_d:
			best_d = d
			best = hex
	if best == c.capital:
		return "at the capital"
	var a := Armies.create(g, c.tag, c.capital, "Report army")
	Armies.add_units(g, a, 0, 1, g.turn - 1, c.capital, 0, {})
	var text := "no way"
	var plan := Movement.plan(g, a, best)
	if bool(plan["ok"]):
		var walk := Movement.walk_plan(g, a, plan["hexes"], g.turn)
		text = "%d seasons (%d points) to %s" % [int(walk["seasons"]), int(plan["cost"]), str(best)]
	Armies.remove(g, a)
	return text
