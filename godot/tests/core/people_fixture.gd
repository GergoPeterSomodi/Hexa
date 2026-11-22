## The games and definitions copies of M5's people tests (docs/architecture/m5-build-spec.md 4.12, 9). Every function returns
## a copy: the committed definitions (EconomyFixture.committed) are never touched.
##   genoa(defs):       the first-year game of 4.11 (a): "Italy, 1480" on seed 1480 as Genoa, calm weather, `defs` (the
##                      committed ones when null); `fixture` makes (7, 12) wild as M4's fixture does.
##   still(defs):       people never change: growth 0, 0, 0; hunger 0; left 0 (M4's and M4.5's numbers are about the economy
##                      alone: the tests that pin them run on this).
##   always_fed(defs):  the towns need no food, so every country is fed whatever its land makes.
##   no_food(defs):     the settlements catch no fish and farmland and grassland give no wild grain: Genoa makes no food.
##   season(game), play(game, n): a season with the people phase between works and stats, as Season.PHASES runs it (kept
##                      as a loop of its own for the tests that want a step between the phases).
class_name PeopleFixture
extends RefCounted


## A copy of `defs` (the committed ones when null) that is yours to change: its families are copies too.
static func copy_of(defs: GameDefs = null) -> GameDefs:
	var out := (defs if defs != null else EconomyFixture.committed()).duplicate() as GameDefs
	var families: Array[FamilyDef] = []
	for f: FamilyDef in out.families:
		families.append(f.duplicate() as FamilyDef if f != null else null)
	out.families = families
	out.war = EconomyFixture.war_copy(out.war)
	return out


## People never change (growth, hunger and crowding all 0).
static func still(defs: GameDefs = null) -> GameDefs:
	var out := copy_of(defs)
	out.growth_bp = PackedInt32Array([0, 0, 0])
	out.hunger_bp = 0
	out.left_bp = 0
	return out


## The towns eat nothing: every country is always fed.
static func always_fed(defs: GameDefs = null) -> GameDefs:
	var out := copy_of(defs)
	out.food_need_milli = 0
	return out


## No fish from the settlements and no wild grain from farmland and grassland.
static func no_food(defs: GameDefs = null) -> GameDefs:
	var out := copy_of(defs)
	var settlements := out.family(Economy.SETTLEMENTS)
	settlements.port_fish = PackedInt32Array([0, 0, 0, 0, 0, 0])
	var wild := out.wild_yield.duplicate()
	for cover: int in [0, 1]:  # farmland, grassland
		for slot: int in FamilyDef.SLOTS:
			wild[cover * FamilyDef.SLOTS + slot] = 0
	out.wild_yield = wild
	return out


## The 1480 scenario as Genoa on seed 1480 with calm weather (a copy of `defs` with weather_odds 100, 0, 0).
static func genoa(defs: GameDefs = null, fixture: bool = false) -> Game:
	var d := copy_of(defs)
	d.weather_odds = PackedInt32Array([100, 0, 0])
	var g := Game.new_scenario(EconomyFixture.map(), d, d.scenarios[d.scenarios.size() - 1], EconomyFixture.SEED)
	if fixture:
		g.improvement.clear(EconomyFixture.VINEYARD_HEX)
		g.districts.clear()
		g.version += 1
	g.act("choose_country", {"tag": &"GEN"})
	return g


## One season: production, income, works, the people phase, stats and the people's close, calendar.
static func season(game: Game) -> Dictionary:
	var verdict := Season.end_check(game)
	if not bool(verdict["ok"]):
		return verdict
	Season.begin(game)
	for phase: StringName in [&"production", &"income", &"works"]:
		Season.run_phase(game, phase)
	People.season(game)
	Season.run_phase(game, &"stats")  # People.close runs inside it
	Season.run_phase(game, &"calendar")
	Season.finish(game)
	return verdict


static func play(game: Game, seasons: int) -> void:
	for _n: int in seasons:
		season(game)
