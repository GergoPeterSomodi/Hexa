## The three games of M4.5's tests (docs/architecture/m4-5-build-spec.md 4.10, 4.11, 9): Genoa on seed 1480 with calm
## weather (a copy of the definitions with `weather_odds` 100, 0, 0), each played through `Season.run`.
##   genoa_first_year(): the first-year game of 4.10, played to turn 5 (Spring 1481).
##   genoa_1483():       4.11's setup at turn 13 (Spring 1483): timber on (10, 13) at the start, the walled town's
##                       upgrade to a city on (8, 13) in Winter 1481.
##   forty_seasons():    the forty-season rig of M3 (the 1480 scenario as Genoa, works at random valid options up to the
##                       free slots, a cancel now and then, a tax change and the console's money), 40 seasons.
## Games are fresh each call (the map and the definitions are shared and read-only, as EconomyFixture's).
class_name InsightsFixture
extends RefCounted

const TAG := &"GEN"
const SEED := 1480
const TIMBER_HEX := Vector2i(10, 13)
const GENOA_HEX := Vector2i(8, 13)
const SEASONS := 40


## The 1480 scenario as Genoa, played to turn 5 with nothing built.
static func genoa_first_year() -> Game:
	var g := EconomyFixture.game(TAG)
	for _n: int in 4:
		Season.run(g)
	return g


## 4.11's game at turn 13: Build timber on (10, 13) at turn 1, seven seasons to Winter 1481, the upgrade of Genoa to a city
## (1,000 ducats), five seasons to Spring 1483.
static func genoa_1483() -> Game:
	var g := EconomyFixture.game(TAG)
	_act(g, "build", {"hex": TIMBER_HEX, "family": ImproveRules.TIMBER, "tag": TAG})
	for _n: int in 7:
		Season.run(g)
	_act(g, "upgrade", {"hex": GENOA_HEX, "tag": TAG})
	for _n: int in 5:
		Season.run(g)
	return g


## The forty-season game. `each` (optional) is called as each.call(game, ended_turn) after every season, with the game at
## the start of the next one: the place for a test to compare a view with the season that just ended.
static func forty_seasons(each: Callable = Callable()) -> Game:
	var g := EconomyFixture.game(TAG)
	var luck := Rng.new()
	luck.seed_with(SEED)
	for n: int in SEASONS:
		_fund(g, n)
		_cancel_one(g, luck)
		_begin_works(g, luck)
		var ended := g.turn
		Season.run(g)
		if each.is_valid():
			each.call(g, ended)
	return g


static func _act(g: Game, action: String, args: Dictionary) -> void:
	var verdict := g.act(action, args)
	if not bool(verdict["ok"]):
		push_error("InsightsFixture: %s refused: %s" % [action, str(verdict.get("reason", ""))])


## Works at random valid options until the slots are full (or 40 tries fail).
static func _begin_works(g: Game, luck: Rng) -> void:
	var country := Countries.by_tag(g, TAG)
	var districts := Territory.districts(g, country.id)
	var tries := 0
	while Works.in_use(g, TAG) < Works.slots(g, TAG) and tries < 40:
		tries += 1
		var hex := g.map.hex_of(districts[luck.randi_range(0, districts.size() - 1)])
		var kind := luck.randi_range(0, 5)
		if kind == 0:
			g.act("upgrade", {"hex": hex, "tag": TAG})
		elif kind == 1:
			g.act("clear", {"hex": hex, "tag": TAG})
		else:
			var options: Array[Dictionary] = []
			for o: Dictionary in g.improvement.build_options(hex):
				if bool(o["ok"]):
					options.append(o)
			if options.is_empty():
				continue
			var pick := options[luck.randi_range(0, options.size() - 1)]
			g.act("build", {"hex": hex, "family": int(pick["family_id"]), "tag": TAG})


## Money for the works and now and then a tax change (the console's door, so the ledgers see a `dev` line too).
static func _fund(g: Game, n: int) -> void:
	if n % 3 == 0:
		g.dev_money(TAG, 400)
	if n % 8 == 0:
		g.dev_goods(TAG, 11, 20)
		g.dev_goods(TAG, 12, 40)
	if n % 7 == 3:
		g.act("set_tax", {"level": int(n / 7.0) % 3, "tag": TAG})


## Cancels one work of TAG now and then (a refund in its first season).
static func _cancel_one(g: Game, luck: Rng) -> void:
	var mine: Array[Work] = []
	for w: Work in g.state.works:
		if w.tag == TAG:
			mine.append(w)
	if mine.is_empty() or luck.randi_range(0, 3) != 0:
		return
	g.act("cancel_work", {"hex": mine[luck.randi_range(0, mine.size() - 1)].hex, "tag": TAG})
