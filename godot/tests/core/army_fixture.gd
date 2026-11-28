## The games and definitions of the armies' tests (docs/architecture/m6-build-spec.md 9, L4). Every function returns a game
## that is yours to change: the definitions are copies (their families and their unit kinds too, so a planted fault never
## touches EconomyFixture.committed()).
##   game():            the 1480 scenario on seed 1480, calm weather, Genoa (TAG) chosen; the map is the shared read-only one.
##   town(game, hex):   makes a land hex of TAG a town (level 3, 20,000 people) with no works on it.
##   rich(game):        TAG has ducats and every good in store.
##   find_town(game):   a land hex of TAG with six land neighbours of TAG, or NO_HEX.
##   other_tag(game):   the first country that is not TAG.
##   army(game, tag, hex, kind, count, raised_turn): an army of `tag` on `hex` made through the door (no raise), with its full
##                      move points (a fresh army).
##   spent(game, army, points): the army has only `points` move points left (moves-build-spec.md R12; cut to 0 and its full).
##   raise_now(game, args, door): a setup's raise, its companies standing now (the action `raise`; its verdict).
class_name ArmyFixture
extends RefCounted

const TAG := &"GEN"
const NO_HEX := Vector2i(-1, -1)


## A copy of the 1480 definitions with calm weather, still people (EconomyFixture.defs) and its own unit kinds.
static func defs() -> GameDefs:
	var out := EconomyFixture.defs(true, true)
	var units: Array[UnitDef] = []
	for u: UnitDef in out.units:
		units.append(u.duplicate() as UnitDef)
	out.units = units
	out.war = EconomyFixture.war_copy(out.war)
	return out


static func game() -> Game:
	var d := defs()
	var g := Game.new_scenario(EconomyFixture.map(), d, d.scenarios[d.scenarios.size() - 1], EconomyFixture.SEED)
	g.act("choose_country", {"tag": TAG})
	return g


static func id_of(g: Game, tag: StringName) -> int:
	return Countries.by_tag(g, tag).id


## A land hex of TAG whose six neighbours are land held by TAG; NO_HEX when none.
static func find_town(g: Game) -> Vector2i:
	var owner := id_of(g, TAG)
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if not g.map.is_land(hex) or int(g.state.owner[i]) != owner:
			continue
		var all := true
		for d: int in 6:
			var beside := ImproveRules.neighbour(hex, d)
			if not g.map.is_land(beside) or Territory.owner_id(g, beside) != owner:
				all = false
				break
		if all:
			return hex
	return NO_HEX


## Makes `hex` a settlement of `level` with `people` people on it, and clears the derived caches.
static func town(g: Game, hex: Vector2i, level: int = 3, people: int = 20000) -> void:
	var i := g.map.index_of(hex)
	g.state.main_use[i] = Economy.SETTLEMENTS
	g.state.level[i] = level
	g.state.people[i] = people
	g.districts.clear()
	g.version += 1


## Sets the people of a hex (a test's number, not a rule).
static func people_at(g: Game, hex: Vector2i, people: int) -> void:
	g.state.people[g.map.index_of(hex)] = people


static func rich(g: Game) -> void:
	var c := Countries.by_tag(g, TAG)
	c.treasury = 1000000
	for i: int in c.stock.size():
		c.stock[i] = 1000


static func other_tag(g: Game) -> StringName:
	for c: Country in g.countries:
		if c.tag != TAG:
			return c.tag
	return &""


## An army made through the door: `count` companies of `kind` raised on `hex` at `raised_turn`, its order none.
static func army(g: Game, tag: StringName, hex: Vector2i, kind: int, count: int, raised_turn: int = -1) -> Army:
	var a := Armies.create(g, tag, hex, "Army of test")
	var turn := raised_turn if raised_turn >= 0 else g.turn - 1
	Armies.add_units(g, a, kind, count, turn, hex, 0, {})
	Armies.set_points(g, a, Allowance.full(g, a))
	return a


## A raised company, standing now (docs/design/recruitment-queue.md, task RQ0): paid, levied and in an army this season.
## A test that needs a raised company only as its setup gets it here, so the recruitment queue changes this function and not
## the tests; a test about raising calls the action itself. Today the action `raise` does all of it at once and the action
## log holds its record. `args` are the action's, {hex, kind, count, tag}; `door` takes (action, args) and is g.act when none
## is given (Session.act in a window test, which adds the player's tag and sends the events). The verdict: {ok, reason, army}.
static func raise_now(g: Game, args: Dictionary, door: Callable = Callable()) -> Dictionary:
	var through: Callable = g.act if door.is_null() else door
	return through.call("raise", args)


## The army has `points` move points left: what a walk would leave it (the walks come with the moves build).
static func spent(g: Game, a: Army, points: int) -> void:
	Armies.set_points(g, a, points)


## The copy of the game's own state a planted check changes: the game's armies as a saved body.
static func saved(g: Game) -> Dictionary:
	return Armies.to_dict(g)
