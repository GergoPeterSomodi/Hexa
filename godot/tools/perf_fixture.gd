## The big games of the speed rigs (docs/architecture/m4-5-build-spec.md 8): tools/perf_core.gd and the probes share them.
##   europe_game(seasons):      the made-up Europe (FakeMap 494 x 247, FakeScenario with 60 countries, seed 1480) with the
##                              real goods and families and work_slots_base 10; the largest country is the player. Each
##                              season every country begins works up to its free slots at random allowed options (Rng
##                              seeded 1480), paid with Game.dev_money and Game.dev_goods when short (the rig, not the
##                              rules); then Season.run. At 40 seasons the ring is full and the chronicle holds its 3,000.
##   north_italy_game(seasons): the 1480 scenario on seed 1480 as Genoa, calm weather, the same seeded works for Genoa only.
##   largest_tag(game):         the country holding the most land, ties by id.
## Headless, no window; the games take minutes to build, so a rig builds one and keeps it.
## Moves in the month (moves-build-spec.md 9, MV16): an order of march walks at once, which would leave the movement phase
## nothing to walk. With `standing` the rig's armies get their points and a march that only stands (the order and the route
## stored, nothing walked), so the phase rows keep measuring the walks; without it every march goes through Game.act.
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
const WAR_PAIRS := 30
## The war march (m7-build-spec.md 8): an army of a country at war goes at the nearest enemy army or hostile garrisoned fortress
## within WAR_NEAR hexes, for one army in two (the luck stream's pick).
const WAR_NEAR := 12
## The war rows' fixtures (m7-build-spec.md 8): the companies of each battle side and of each siege's army.
const FIGHT_COMPANIES := 8
## The movement numbers copied from the committed definitions (the made-up Europe's own come from FakeScenario).
const MOVEMENT_FIELDS: Array[String] = ["units", "terrains", "relief_move_add", "highway_cap", "road_cap", "track_divisor",
	"winter_snow_percent", "pass_closing_climate", "stream_cost", "river_cost", "ford_cost", "ferry_cost",
	"river_wade_class", "river_wall_class", "wade_plan_cost", "supply_reach", "supply_wade_cost", "depot_min_level",
	"army_food_milli", "forage_percent", "forage_loss_permille", "starve_permille", "stack_limit", "march_seasons_max",
	"wait_ratio_percent", "wait_extra_seasons", "land_sight"]


## The made-up Europe, `seasons` seasons played. Null when the committed definitions cannot be read. With `watched` (M8, K23: the
## AI's rig) the game is watched (Game.watch() before its first season: every country AI-played, no player) and the AI is attached;
## the seeded random works are left out, the AI begins its own.
static func europe_game(seasons: int, watched: bool = false) -> Game:
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
	if watched:
		if not game.watch():
			printerr("PerfFixture: cannot watch the made-up Europe")
			return null
		AiPlayers.attach(game)
	else:
		var largest := largest_tag(game)
		if not bool(game.act("choose_country", {"tag": largest})["ok"]):
			printerr("PerfFixture: cannot choose %s" % largest)
			return null
	var luck := Rng.new()
	luck.seed_with(SEED)
	for _n: int in seasons:
		if not watched:
			for c: Country in game.countries:
				_begin_works(game, c.tag, luck)
		var t0 := Time.get_ticks_usec()
		Season.run(game)
		if watched:
			PerfAiRows.progress("warm-up turn %d: %.0f ms (all phases)" % [game.turn, float(Time.get_ticks_usec() - t0) / 1000.0])
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


## M7 (m7-build-spec.md 8): the made-up Europe, `seasons` seasons played, and WAR_PAIRS wars between neighbouring pairs (the
## lowest-id countries first, each pair once), declared through the door (Game.act "declare_war"; a refusal is skipped). Null
## when the game cannot be built.
static func europe_war(seasons: int, watched: bool = false) -> Game:
	var game := europe_game(seasons, watched)
	if game == null:
		return null
	var made := 0
	for a: Country in game.countries:
		for b: Country in game.countries:
			if made >= WAR_PAIRS:
				return game
			if b.id <= a.id:
				continue
			if bool(game.act("declare_war", {"target": b.tag, "tag": a.tag})["ok"]):
				made += 1
	return game


## M8 (m8-build-spec.md 8.1, K23): M7's europe_war made with Game.watch() before its first season and the AI attached: `seasons`
## seasons played by the AI, then WAR_PAIRS wars declared through the door. Null when the game cannot be built.
static func europe_ai(seasons: int) -> Game:
	return europe_war(seasons, true)


## The armies of the speed rigs (m6-build-spec.md 8, 5.0 R10) a country of 1 to MAX_COMPANIES pikemen on
## random land of its own, through Armies.create and Armies.add_units with raised_turn = turn - 1 (none musters): the rig, not
## raise. The movement numbers are copied from the committed definitions first (as probe_movement does), then each army is
## ordered out. Returns the armies in id order.
static func seed_armies(game: Game, luck: Rng, standing: bool = false) -> Array[Army]:
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
			if standing:
				Armies.set_points(game, a, Allowance.full(game, a))
			out.append(a)
	for a: Army in out:
		march_out(game, a, luck, standing)
	return out


## M7 (m7-build-spec.md 8): one army in two of each country at war marches at the nearest enemy army or hostile garrisoned
## fortress within WAR_NEAR hexes (the luck stream picks the half; a march refused is kept as it is). Returns the number ordered.
static func war_march(game: Game, armies: Array[Army], luck: Rng, standing: bool = false) -> int:
	var ordered := 0
	var forts := game.war_cache.fortresses(game)
	for a: Army in armies:
		if Armies.by_id(game, a.id) == null or luck.randi_range(0, 1) == 0:
			continue
		var goal := _nearest_enemy(game, a, forts)
		if goal == Army.NO_HEX:
			continue
		if _march(game, a, goal, standing):
			ordered += 1
	return ordered


## The nearest hex of an enemy army or of a hostile fortress with a garrison, within WAR_NEAR hexes (Army.NO_HEX when none).
static func _nearest_enemy(game: Game, a: Army, forts: PackedInt32Array) -> Vector2i:
	var best := Army.NO_HEX
	var best_d := WAR_NEAR + 1
	for e: Army in game.armies:
		if e.tag == a.tag or not Wars.at_war(game, a.tag, e.tag):
			continue
		var d := ImproveRules.hex_distance(e.hex, a.hex)
		if d < best_d:
			best_d = d
			best = e.hex
	for i: int in forts:
		var hex := game.map.hex_of(i)
		var holder := Occupation.controller_tag(game, hex)
		if holder == a.tag or holder == &"" or not Wars.at_war(game, a.tag, holder) or Occupation.garrison_of(game, hex) <= 0:
			continue
		var df := ImproveRules.hex_distance(hex, a.hex)
		if df < best_d:
			best_d = df
			best = hex
	return best


## Between seasons: an army that arrived (it holds) is given a new march (the rig, outside the timed phases).
static func rearm(game: Game, luck: Rng, armies: Array[Army], standing: bool = false) -> void:
	for a: Army in armies:
		if a.order == Army.ORDER_HOLD and Armies.by_id(game, a.id) != null:
			march_out(game, a, luck, standing)


## A march (see _march) to a hex of the army's own land near it, kept when its plan walks in 1 to SEASONS_MAX seasons.
static func march_out(game: Game, a: Army, luck: Rng, standing: bool = false) -> bool:
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
		return _march(game, a, goal, standing)
	return false


## The army ordered to `goal`: through Game.act (it walks at once), or with `standing` a march that only stands: the check,
## the planned route stored through the armies' door, the old halt and wait cleared, nothing walked (a rig, not the rules).
## False when the check refuses.
static func _march(game: Game, a: Army, goal: Vector2i, standing: bool) -> bool:
	var args := {"army": a.id, "goal": goal, "tag": a.tag}
	if not standing:
		return bool(game.act("march", args)["ok"])
	if not bool(game.check("march", args)["ok"]):
		return false
	Armies.set_order(game, a, Army.ORDER_MARCH, goal, Movement.plan(game, a, goal)["hexes"])
	Armies.set_halt(game, a, &"", "")
	Armies.set_waiting(game, a, &"")
	game.version += 1
	return true


## M7 (m7-build-spec.md 8): `count` battles of FIGHT_COMPANIES pikemen companies against FIGHT_COMPANIES, each on a land hex and
## the free land hex beside it held by a country at war with the first one's holder. The two armies are made through the
## armies' door (Armies.create, Armies.add_units) and the battle through Battles.engage at tick 0 (a rig: the battles phase
## fights them). Hexes with an army or a battle are skipped, so a second call takes the next free pairs. Returns the number made.
static func battle_set(game: Game, count: int) -> int:
	var made := 0
	for i: int in game.map.hex_count():
		if made >= count:
			break
		var h := game.map.hex_of(i)
		if not game.map.is_land(h) or not Armies.at(game, h).is_empty() or Battles.at(game, h) != null:
			continue
		var near := _enemy_beside(game, h)
		if near == Army.NO_HEX:
			continue
		var defender := _rig_army(game, Occupation.controller_tag(game, near), near, FIGHT_COMPANIES)
		var attacker := _rig_army(game, Occupation.controller_tag(game, h), h, FIGHT_COMPANIES)
		if Battles.engage(game, attacker, near, 0, -1):
			made += 1
		else:
			Armies.remove(game, attacker)
			Armies.remove(game, defender)
	return made


## M7 (m7-build-spec.md 8): `sieges` sieges, one army of FIGHT_COMPANIES companies on each garrisoned fortress (in hex index order)
## held by a country with an enemy, and `occupied` land districts (not fortresses) taken by the holder's enemies (Occupation.capture,
## by &"perf"). The sieges phase starts the sieges: one run of it is the caller's. Returns {sieges, occupied}: the numbers made.
static func siege_set(game: Game, sieges: int, occupied: int) -> Dictionary:
	var made := 0
	for i: int in game.war_cache.fortresses(game):
		if made >= sieges:
			break
		var hex := game.map.hex_of(i)
		var holder := Occupation.controller_tag(game, hex)
		var enemies: Array[StringName] = Wars.enemies(game, holder)
		if enemies.is_empty() or Occupation.garrison_of(game, hex) <= 0 or not Armies.at(game, hex).is_empty():
			continue
		_rig_army(game, enemies[0], hex, FIGHT_COMPANIES)
		made += 1
	var taken := 0
	for i: int in game.map.hex_count():
		if taken >= occupied:
			break
		var h := game.map.hex_of(i)
		if not game.map.is_land(h) or Occupation.fortress_level(game, h) > 0:
			continue
		var enemies := Wars.enemies(game, Occupation.controller_tag(game, h))
		if enemies.is_empty():
			continue
		Occupation.capture(game, h, enemies[0], &"perf", {})
		taken += 1
	return {"sieges": made, "occupied": taken}


## M7 (m7-build-spec.md 8): an army and an enemy army beside it, made for the odds card's row (no battle is engaged). Returns
## {viewer, army (id), hex (the enemy's)}; {} when no free pair is left. The armies stay on the map.
static func odds_pair(game: Game) -> Dictionary:
	for i: int in game.map.hex_count():
		var h := game.map.hex_of(i)
		if not game.map.is_land(h) or not Armies.at(game, h).is_empty() or Battles.at(game, h) != null:
			continue
		var near := _enemy_beside(game, h)
		if near == Army.NO_HEX:
			continue
		var viewer := Occupation.controller_tag(game, h)
		_rig_army(game, Occupation.controller_tag(game, near), near, FIGHT_COMPANIES)
		var mine := _rig_army(game, viewer, h, FIGHT_COMPANIES)
		Sight.refresh(game)  # the rig's armies see their surroundings (the vision phase has not run)
		game.version += 1
		return {"viewer": viewer, "army": mine.id, "hex": near}
	return {}


## An army of `companies` pikemen of `tag` on hex (through the armies' door; the rig of seed_armies).
static func _rig_army(game: Game, tag: StringName, hex: Vector2i, companies: int) -> Army:
	var a := Armies.create(game, tag, hex, "Army of perf")
	Armies.add_units(game, a, 0, companies, game.turn - 1, hex, 0, {})
	return a


## A land hex beside h held by a country at war with h's holder, with no army and no battle on it (Army.NO_HEX when none).
static func _enemy_beside(game: Game, h: Vector2i) -> Vector2i:
	var holder := Occupation.controller_tag(game, h)
	for d: int in 6:
		var n := game.map.neighbour(h, d)
		if not game.map.has(n) or not game.map.is_land(n) or not Armies.at(game, n).is_empty() or Battles.at(game, n) != null:
			continue
		var other := Occupation.controller_tag(game, n)
		if other != holder and Wars.at_war(game, holder, other):
			return n
	return Army.NO_HEX
