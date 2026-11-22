## The games and helpers of the AI's tests (docs/architecture/m8-build-spec.md 9). Every game has its own copies of the
## definitions (EconomyFixture.defs / ArmyFixture.defs), so a planted number never reaches the committed ones; a test that plants
## a fault in the AI's numbers duplicates the sub-resource (`ai`, a temperament) first.
##   watch(defs, seed):  the 1480 scenario AI-only (Game.watch), calm weather, the AI attached (AiPlayers.attach).
##   duel(defs):         Milan (MLO)'s seat alone, Genoa (GEN) the passive player, every other neighbour of Milan with 4
##                       companies (WarFixture.army_at on its first free hex); the AI attached.
##   seat(game, tag):    one seat's turn run alone on the game as it is; the acts it did, {tag, action, args}.
##   solo(game, tag):    an AiTurn with every other country passive (the game's `orders` is not touched).
##   run(game, hook):    begin and step until over; the acts (the hook's judge fills them).
##   land_hex(game, tag, unseen_by): the first land hex of tag's country; with unseen_by, one that country does not see.
class_name AiFixture
extends RefCounted

const MILAN := &"MLO"
const GENOA := &"GEN"
const VENICE := &"VEN"


static func watch(defs: GameDefs = null, seed_value: int = EconomyFixture.SEED) -> Game:
	var d := defs if defs != null else EconomyFixture.defs(true, true)
	var g := Game.new_scenario(EconomyFixture.map(), d, d.scenarios[d.scenarios.size() - 1], seed_value)
	g.watch()
	AiPlayers.attach(g)
	return g


static func duel(defs: GameDefs = null) -> Game:
	var d := defs if defs != null else ArmyFixture.defs()
	var g := Game.new_scenario(EconomyFixture.map(), d, d.scenarios[d.scenarios.size() - 1], EconomyFixture.SEED)
	g.act("choose_country", {"tag": GENOA})
	for other: StringName in AiKnow.neighbours(g, MILAN):
		var hex := land_hex(g, other)
		if hex != Army.NO_HEX:
			WarFixture.army_at(g, other, hex, 4)
	var passive: Array[StringName] = []
	for c: Country in g.countries:
		if c.tag != MILAN:
			passive.append(c.tag)
	AiPlayers.attach(g, passive)
	return g


static func solo(game: Game, tag: StringName) -> AiTurn:
	var hook := AiTurn.new()
	for c: Country in game.countries:
		if c.tag != tag:
			hook.passive.append(c.tag)
	return hook


static func run(game: Game, hook: AiTurn) -> Array[Dictionary]:
	var acts: Array[Dictionary] = []
	hook.judge = func(t: StringName, action: String, args: Dictionary, _verdict: Dictionary, _result: Dictionary) -> void:
		acts.append({"tag": t, "action": action, "args": args})
	hook.begin(game)
	while not hook.step(game):
		pass
	return acts


static func seat(game: Game, tag: StringName) -> Array[Dictionary]:
	return run(game, solo(game, tag))


## The first land hex of the country's own land; with `unseen_by`, the first that country does not see now. Army.NO_HEX when none.
static func land_hex(game: Game, tag: StringName, unseen_by: StringName = &"") -> Vector2i:
	for i: int in AiKnow.land_of(game, tag):
		var hex := game.map.hex_of(i)
		if game.map.is_land(hex) and (unseen_by == &"" or not Sight.sees(game, unseen_by, hex)):
			return hex
	return Army.NO_HEX
