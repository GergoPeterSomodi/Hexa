## The big games of the speed rigs (docs/architecture/m4-5-build-spec.md 8): tools/perf_core.gd and the probes share them.
##   europe_game(seasons):      the made-up Europe (FakeMap 494 x 247, FakeScenario with 60 countries, seed 1480) with the
##                              real goods and families and work_slots_base 10; the largest country is the player. Each
##                              season every country begins works up to its free slots at random allowed options (Rng
##                              seeded 1480), paid with Game.dev_money and Game.dev_goods when short (the rig, not the
##                              rules); then Season.run. At 40 seasons the ring is full and the chronicle holds its 3,000.
##   north_italy_game(seasons): the 1480 scenario on seed 1480 as Genoa, calm weather, the same seeded works for Genoa only.
##   largest_tag(game):         the country holding the most land, ties by id.
## Headless, no window; the games take minutes to build, so a rig builds one and keeps it.
class_name PerfFixture
extends RefCounted

const GAME_DEFS := "res://data/defs/game_defs.tres"
const COLS := 494
const ROWS := 247
const SEED := 1480
const COUNTRIES := 60
const WORK_SLOTS := 10
const TRIES := 40
const MONEY_FLOOR := 20000
const MONEY_TOP_UP := 100000
const GOODS_FLOOR := 60
const GOODS_TOP_UP := 120
const GENOA := &"GEN"
## The armies of the speed rigs (m6-build-spec.md 8, 5.0 R10): as tools/probes/probe_movement.gd.
const ARMIES_PER_COUNTRY := 10
const MAX_COMPANIES := 8
const NEAR := 6
const SEASONS_MAX := 4
const ORDER_TRIES := 60
## The movement numbers copied from the committed definitions (the made-up Europe's own come from FakeScenario).
const MOVEMENT_FIELDS: Array[String] = ["units", "terrains", "relief_move_add", "highway_cap", "road_cap", "track_divisor",
	"winter_snow_percent", "pass_closing_climate", "stream_cost", "river_cost", "ford_cost", "ferry_cost",
	"river_wade_class", "river_wall_class", "wade_plan_cost", "supply_reach", "supply_wade_cost", "depot_min_level",
	"army_food_milli", "forage_percent", "forage_loss_permille", "starve_permille", "stack_limit", "march_seasons_max",
	"wait_ratio_percent", "wait_extra_seasons", "land_sight"]


## The made-up Europe, `seasons` seasons played. Null when the committed definitions cannot be read.
static func europe_game(seasons: int) -> Game:
	var map := FakeMap.build(COLS, ROWS, SEED)
	var built := FakeScenario.build(map, COUNTRIES, SEED)
	var defs := built["defs"] as GameDefs
	var real := ResourceLoader.load(GAME_DEFS, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	if real == null or real.families.size() != FamilyIds.COUNT - 1:
		printerr("PerfFixture: cannot load the families of %s" % GAME_DEFS)
		return null
	defs.families = real.families
	defs.goods = real.goods
	defs.work_slots_base = WORK_SLOTS
	var game := Game.new_scenario(map, defs, built["scenario"] as ScenarioDef, SEED)
	var largest := largest_tag(game)
	if not bool(game.act("choose_country", {"tag": largest})["ok"]):
		printerr("PerfFixture: cannot choose %s" % largest)
		return null
	var luck := Rng.new()
	luck.seed_with(SEED)
	for _n: int in seasons:
		for c: Country in game.countries:
			_begin_works(game, c.tag, luck)
		Season.run(game)
	return game


## The 1480 scenario as Genoa, `seasons` seasons played with seeded random works for Genoa. Null when the game cannot start.
static func north_italy_game(seasons: int) -> Game:
	var game := EconomyFixture.game(GENOA)
	if game.player != GENOA:
		printerr("PerfFixture: cannot choose %s" % GENOA)
		return null
	var luck := Rng.new()
	luck.seed_with(SEED)
	for _n: int in seasons:
		_begin_works(game, GENOA, luck)
		Season.run(game)
	return game


## The tag of the country holding the most land, ties by id (the first in the list).
static func largest_tag(game: Game) -> StringName:
	var best := game.countries[0]
	var best_n := -1
	for c: Country in game.countries:
		var n := Territory.count(game, c.id)
		if n > best_n:
			best = c
			best_n = n
	return best.tag


## Works at random allowed options on `tag`'s land until its slots are full (or TRIES tries fail); the purse and the stores
## are topped up first when low, as the works cost ducats and goods.
static func _begin_works(game: Game, tag: StringName, luck: Rng) -> void:
	var country := Countries.by_tag(game, tag)
	if country.treasury < MONEY_FLOOR:
		game.dev_money(tag, MONEY_TOP_UP)
	for good: int in game.defs.goods.size():
		if country.stock[good] < GOODS_FLOOR:
			game.dev_goods(tag, good, GOODS_TOP_UP)
	var districts := Territory.districts(game, country.id)
	var tries := 0
	while districts.size() > 0 and tries < TRIES and Works.in_use(game, tag) < Works.slots(game, tag):
		tries += 1
		var hex := game.map.hex_of(districts[luck.randi_range(0, districts.size() - 1)])
		var options: Array[Dictionary] = []
		for o: Dictionary in game.improvement.build_options(hex):
			if bool(o["ok"]):
				options.append(o)
		if options.is_empty():
			continue
		var pick := options[luck.randi_range(0, options.size() - 1)]
		game.act("build", {"hex": hex, "family": int(pick["family_id"]), "tag": tag})


## The armies of the speed rigs (m6-build-spec.md 8, 5.0 R10): ARMIES_PER_COUNTRY a country of 1 to MAX_COMPANIES pikemen on
## random land of its own, through Armies.create and Armies.add_units with raised_turn = turn - 1 (none musters): the rig, not
## raise. The movement numbers are copied from the committed definitions first (as probe_movement does), then each army is
## ordered out. Returns the armies in id order.
static func seed_armies(game: Game, luck: Rng) -> Array[Army]:
	var real := ResourceLoader.load(GAME_DEFS, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	var out: Array[Army] = []
	if real == null:
		printerr("PerfFixture: cannot load %s" % GAME_DEFS)
		return out
	for field: String in MOVEMENT_FIELDS:
		game.defs.set(field, real.get(field))
	for c: Country in game.countries:
		var land := Territory.districts(game, c.id)
		if land.is_empty() or not c.alive:
			continue
		for _k: int in ARMIES_PER_COUNTRY:
			var hex := game.map.hex_of(land[luck.randi_range(0, land.size() - 1)])
			var a := Armies.create(game, c.tag, hex, "Army of perf")
			Armies.add_units(game, a, 0, luck.randi_range(1, MAX_COMPANIES), game.turn - 1, hex, 0, {})
			out.append(a)
	for a: Army in out:
		march_out(game, a, luck)
	return out


## Between seasons: an army that arrived (it holds) is given a new march (the rig, outside the timed phases).
static func rearm(game: Game, luck: Rng, armies: Array[Army]) -> void:
	for a: Army in armies:
		if a.order == Army.ORDER_HOLD and Armies.by_id(game, a.id) != null:
			march_out(game, a, luck)


## A march (Game.act "march") to a hex of the army's own land near it, kept when its plan walks in 1 to SEASONS_MAX seasons.
static func march_out(game: Game, a: Army, luck: Rng) -> bool:
	var country := Countries.by_tag(game, a.tag)
	var land := Territory.districts(game, country.id) if country != null else PackedInt32Array()
	if land.is_empty():
		return false
	for _k: int in ORDER_TRIES:
		var goal := game.map.hex_of(land[luck.randi_range(0, land.size() - 1)])
		if ImproveRules.hex_distance(goal, a.hex) > NEAR or goal == a.hex:
			continue
		var res := Movement.plan(game, a, goal)
		if not bool(res["ok"]):
			continue
		var walk := Movement.walk_plan(game, a, res["hexes"], game.turn)
		if int(walk["seasons"]) < 1 or int(walk["seasons"]) > SEASONS_MAX:
			continue
		return bool(game.act("march", {"army": a.id, "goal": goal, "tag": a.tag})["ok"])
	return false
