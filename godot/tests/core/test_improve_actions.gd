## The game core's actions (docs/architecture/m1-build-spec.md sections 8 and 10): build, upgrade and clear through
## Game.act. Check and action agree for thousands of random actions (a refused action changes nothing and queues
## nothing; an accepted one succeeds and queues exactly one hex_changed), the same seed and the same actions give the
## same Game.digest(), and the improvement writes only what OWNS says.
extends GutTest

const MAP_FILE := "res://data/maps/north_italy.tres"
const ACTIONS := 2000

var _map: MapData = null
var _luck := Rng.new()


func before_all() -> void:
	_map = load(MAP_FILE) as MapData


func _game(seed_value: int = 1480) -> Game:
	return Game.new_game(_map, seed_value)


## A random action, biased so that most kinds succeed now and then: a build is mostly a family the hex lists.
func _random_action(game: Game) -> Array:
	var hex := Vector2i(_luck.randi_range(-1, _map.cols), _luck.randi_range(-1, _map.rows))
	if _luck.randi_range(0, 9) > 0:
		hex = _map.hex_of(_luck.randi_range(0, _map.hex_count() - 1))
	var roll := _luck.randi_range(0, 9)
	if roll < 4:
		var family := _luck.randi_range(-1, ImproveRules.FAMILIES)
		var options := game.improvement.build_options(hex)
		if not options.is_empty() and _luck.randi_range(0, 9) < 7:
			family = int(options[_luck.randi_range(0, options.size() - 1)]["family_id"])
		return ["build", {"hex": hex, "family": family}]
	if roll < 8:
		return ["upgrade", {"hex": hex}]
	return ["clear", {"hex": hex}]


func test_check_and_action_agree_for_two_thousand_random_actions() -> void:
	assert_not_null(_map, "the map file loads")
	var game := _game()
	_luck.seed_with(42)
	var done := {"build": 0, "upgrade": 0, "clear": 0}
	var refused := 0
	for n: int in ACTIONS:
		var pick := _random_action(game)
		var action: String = pick[0]
		var args: Dictionary = pick[1]
		var before := game.digest()
		game.events.clear()
		var verdict := game.check(action, args)
		assert_eq(game.digest(), before, "a check changes nothing (%s %s)" % [action, args])
		assert_eq(game.events.size(), 0, "a check queues nothing")
		var result := game.act(action, args)
		assert_eq(bool(result["ok"]), bool(verdict["ok"]), "check and action agree (%s %s)" % [action, args])
		assert_eq(str(result["reason"]), str(verdict["reason"]), "and say the same reason")
		if bool(verdict["ok"]):
			done[action] = int(done[action]) + 1
			assert_ne(game.digest(), before, "an accepted %s changes the state" % action)
			assert_eq(game.events.size(), 1, "exactly one event")
			assert_eq(str(game.events[0]["kind"]), "hex_changed")
			assert_eq(game.events[0]["hex"], args["hex"])
			assert_eq(str(result["reason"]), "", "no reason when ok")
		else:
			refused += 1
			assert_eq(game.digest(), before, "a refused %s changes nothing (%s)" % [action, verdict["reason"]])
			assert_eq(game.events.size(), 0, "and queues nothing")
			assert_ne(str(verdict["reason"]), "", "a refusal says why")
	for action: String in done.keys():
		assert_gt(int(done[action]), 20, "enough %s actions were accepted (%d)" % [action, int(done[action])])
	assert_gt(refused, 100, "and enough refused")


func test_the_same_seed_and_the_same_actions_give_the_same_digest() -> void:
	var a := _game(7)
	var b := _game(7)
	assert_eq(a.digest(), b.digest(), "the same seed, the same game")
	assert_ne(_game(8).digest(), a.digest(), "another seed, another game")
	_luck.seed_with(5)
	var played: Array = []
	for n: int in 600:
		played.append(_random_action(a))
	for pick: Array in played:
		a.act(pick[0], pick[1])
		b.act(pick[0], pick[1])
		a.events.clear()
		b.events.clear()
	assert_eq(a.digest(), b.digest(), "the same actions, the same game")
	assert_ne(a.digest(), _game(7).digest(), "and the actions changed it")


func test_the_improvement_writes_only_what_it_owns() -> void:
	assert_eq(Improve.OWNS, ["main_use", "level"])
	var state := MapState.create(_map)
	var known_fields: Array[String] = ["main_use", "level", "owner"]
	for property: Dictionary in state.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			assert_true(known_fields.has(str(property["name"])), "%s is a known MapState field" % property["name"])
	var game := _game()
	var owner_before := game.state.owner.duplicate()
	var map_before := _map.digest()
	_luck.seed_with(11)
	for n: int in 500:
		var pick := _random_action(game)
		game.act(pick[0], pick[1])
	assert_eq(_map.digest(), map_before, "the fixed map is never written")
	assert_eq(game.state.owner, owner_before, "the improvement never writes owner")
	for i: int in _map.hex_count():
		if _map.land[i] == 0:
			assert_eq(game.state.main_use[i], 0, "no sea hex has a use")
			assert_eq(game.state.level[i], 0)


func test_the_actions_table_and_the_refusals() -> void:
	var game := _game()
	assert_eq(Actions.pair_of("build").size(), 2, "a check and an action")
	assert_true(Actions.pair_of("trade").is_empty(), "no such action")
	for name: String in Actions.NAMES:
		assert_eq(Actions.pair_of(name).size(), 2)
	var no := game.act("trade", {})
	assert_false(bool(no["ok"]))
	assert_true(str(no["reason"]).contains("unknown"), str(no["reason"]))
	assert_false(bool(game.check("upgrade", {})["ok"]), "no hex given")
	assert_false(bool(game.check("clear", {"hex": "x"})["ok"]), "a hex that is not a hex")
	assert_false(bool(game.check("build", {"hex": Vector2i(0, 0)})["ok"]), "no family given")
	assert_false(bool(game.act("build", {"hex": Vector2i(-5, 0), "family": ImproveRules.WHEAT})["ok"]), "off the map")
	assert_eq(game.events.size(), 0, "refusals queue nothing")
	var sea := Vector2i(-1, -1)
	for i: int in _map.hex_count():
		if _map.land[i] == 0:
			sea = _map.hex_of(i)
			break
	assert_false(bool(game.act("build", {"hex": sea, "family": ImproveRules.WHEAT})["ok"]), "sea")
	assert_false(bool(game.act("upgrade", {"hex": sea})["ok"]))
	assert_false(bool(game.act("clear", {"hex": sea})["ok"]))


func test_build_upgrade_clear_on_a_known_hex() -> void:
	var m := ImproveFixture.block(5, 5, {}, {Vector2i(2, 2): {"place": ImproveFixture.place(2)}})
	var game := Game.new_game(m, 3)
	for hex: Vector2i in game.improvement.hexes:
		game.act("clear", {"hex": hex})  # the village of the data stays, the search's choices go
	game.events.clear()
	assert_eq(game.state.main_use[m.index_of(Vector2i(2, 2))], ImproveRules.SETTLEMENT, "a place is never pulled down")
	var hex := Vector2i(3, 2)
	var built := game.act("build", {"hex": hex, "family": ImproveRules.WHEAT})
	assert_true(bool(built["ok"]), str(built["reason"]))
	assert_eq(game.state.main_use[m.index_of(hex)], ImproveRules.WHEAT)
	assert_eq(game.state.level[m.index_of(hex)], 1)
	assert_eq(Improve.piece_at(game, hex)["family"], "wheat")
	assert_eq(MapCells.piece_of(m, game.state, hex), Improve.piece_at(game, hex), "the map view and the rules share one piece")
	var again := game.act("build", {"hex": hex, "family": ImproveRules.WHEAT})
	assert_false(bool(again["ok"]), "no second piece on one hex")
	assert_true(bool(game.act("upgrade", {"hex": hex})["ok"]))
	assert_eq(game.state.level[m.index_of(hex)], 2)
	assert_true(bool(game.act("clear", {"hex": hex})["ok"]))
	assert_eq(game.state.main_use[m.index_of(hex)], 0)
	assert_eq(game.events.size(), 3, "one event for each change")
	assert_eq(Improve.build_options(game, hex).is_empty(), false, "a wild hex lists what it may take again")
