## The moves fixtures (docs/architecture/moves-build-spec.md 8, MV0): north Italy's 1480 game where Savoy (SAV) is the player and
## Milan (MLO) its war enemy. Every game has its own copies of the definitions (ArmyFixture.defs), so a planted number never
## reaches the committed ones. A test's state edit, as WarFixture does; never used by the game.
##   duel():           Savoy and Milan at war since the season before (WarFixture.at_war: fair warning, R73, shuts no land);
##                     three armies, all named, made through the armies' door (ArmyFixture.army):
##                     NAME_HOME, a Savoyard army on its first own land hex that has Milanese land three hexes away; NAME_NEAR, a Milanese army three hexes from it;
##                     NAME_UNSEEN, a Milanese army two hexes beyond Savoy's sight (no hex next to it is seen by Savoy, and a
##                     hex two steps from it is), on a hex of its own (never the near army's). Milan is an AI seat
##                     (AiPlayers.attach), Savoy the passive player.
##   declared_now():   duel() with Savoy's war on Milan declared this season (start_turn = the turn), for the fair-warning cases.
##   thin():           duel() with Savoy thin at radius 2 (FogFixture.thin).
##   standing(g, army, goal): the army gets a march order to goal with the stored route Movement.plan gives, and nothing walks:
##                     its hex and moved_from stay (the walk of MV4 is never called). False when Movement.plan refuses the goal.
##   named(g, name):   the first army of the game with that name (NAME_HOME and friends), or null.
class_name MovesFixture
extends RefCounted

const SAVOY := &"SAV"
const MILAN := &"MLO"
const NAME_HOME := "Savoyard fixture"
const NAME_NEAR := "Milanese near fixture"
const NAME_UNSEEN := "Milanese unseen fixture"
const NEAR_DISTANCE := 3
const UNSEEN_DISTANCE := 2
const COMPANIES := 2


## Savoy and Milan at war on north Italy, the three named armies of the duel (see the header), Milan an AI seat.
static func duel(defs: GameDefs = null) -> Game:
	var d := defs if defs != null else ArmyFixture.defs()
	var g := Game.new_scenario(EconomyFixture.map(), d, d.scenarios[d.scenarios.size() - 1], EconomyFixture.SEED)
	g.act("choose_country", {"tag": SAVOY})
	WarFixture.at_war(g, SAVOY, MILAN)
	var home := _home_hex(g)
	_named(ArmyFixture.army(g, SAVOY, home, 0, COMPANIES), NAME_HOME)
	var near := _land_at(g, MILAN, home, NEAR_DISTANCE)
	_named(ArmyFixture.army(g, MILAN, near, 0, COMPANIES), NAME_NEAR)
	Sight.refresh(g)
	var unseen := _unseen(g, MILAN)
	_named(ArmyFixture.army(g, MILAN, unseen, 0, COMPANIES), NAME_UNSEEN)
	Sight.refresh(g)
	var passive: Array[StringName] = []
	for c: Country in g.countries:
		if c.tag != MILAN:
			passive.append(c.tag)
	AiPlayers.attach(g, passive)
	return g


## The duel with its war declared this season by Savoy: Milan's land is shut to Savoy's armies until the next (R73).
static func declared_now() -> Game:
	var g := duel()
	Wars.war_between(g, SAVOY, MILAN).start_turn = g.turn
	g.version += 1
	return g


## The duel with Savoy thin at radius 2: its explored set is its land sight grown by two hexes, the rest is undiscovered.
static func thin() -> Game:
	var g := duel()
	FogFixture.thin(g, SAVOY, 2)
	return g


## Gives `army` a standing march to `goal` by the route Movement.plan gives, without walking it. False when the plan refuses.
static func standing(g: Game, army: Army, goal: Vector2i) -> bool:
	var plan := Movement.plan(g, army, goal)
	if not bool(plan.ok):
		return false
	Armies.set_order(g, army, Army.ORDER_MARCH, goal, plan.hexes)
	g.version += 1
	return true


## The first army of the game with this name, or null.
static func named(g: Game, name: String) -> Army:
	for a: Army in g.armies:
		if a.name == name:
			return a
	return null


static func _named(a: Army, name: String) -> void:
	a.name = name


static func _owner_is(g: Game, hex: Vector2i, tag: StringName) -> bool:
	return g.map.is_land(hex) and Territory.owner_id(g, hex) == ArmyFixture.id_of(g, tag)


## The first Savoyard land hex (index order) that has a Milanese land hex at NEAR_DISTANCE: Savoy's very first hex lies in the
## far west, with no Milanese land within three hexes, so the first hex that does is the home.
static func _home_hex(g: Game) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if _owner_is(g, hex, SAVOY) and _land_at(g, MILAN, hex, NEAR_DISTANCE) != Army.NO_HEX:
			return hex
	return Army.NO_HEX


## The first land hex of `tag` at hex distance `distance` from `from`, in index order.
static func _land_at(g: Game, tag: StringName, from: Vector2i, distance: int) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if _owner_is(g, hex, tag) and ImproveRules.hex_distance(hex, from) == distance:
			return hex
	return Army.NO_HEX


## The first land hex of `tag` with no army on it that Savoy does not see, no neighbour of which Savoy sees, and with a hex two
## steps away that it sees (the near army's hex fits the sight rule too, so a held hex is passed over).
static func _unseen(g: Game, tag: StringName) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if not _owner_is(g, hex, tag) or Sight.sees(g, SAVOY, hex) or not Armies.at(g, hex).is_empty():
			continue
		if _two_steps_seen(g, hex):
			return hex
	return Army.NO_HEX


## True when no neighbour of `hex` is seen by Savoy and some hex two steps away is.
static func _two_steps_seen(g: Game, hex: Vector2i) -> bool:
	var reached := false
	for d: int in 6:
		var beside := ImproveRules.neighbour(hex, d)
		if g.map.index_of(beside) < 0:
			continue
		if Sight.sees(g, SAVOY, beside):
			return false
		for e: int in 6:
			var far := ImproveRules.neighbour(beside, e)
			if g.map.index_of(far) >= 0 and Sight.sees(g, SAVOY, far):
				reached = true
	return reached
