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


## Random action with an actor tag for the 2,000-action scenario property test.
func _random_scenario_action(game: Game) -> Array:
	var m := game.map
	var hex := Vector2i(_luck.randi_range(-1, m.cols), _luck.randi_range(-1, m.rows))
	if _luck.randi_range(0, 9) > 0:
		hex = m.hex_of(_luck.randi_range(0, m.hex_count() - 1))
	var tag := ScenarioFixture.ALL_ACTORS[_luck.randi_range(0, ScenarioFixture.ALL_ACTORS.size() - 1)]
	var roll := _luck.randi_range(0, 9)
	if roll < 4:
		var family := _luck.randi_range(-1, ImproveRules.FAMILIES)
		var options := game.improvement.build_options(hex)
		if not options.is_empty() and _luck.randi_range(0, 9) < 7:
			family = int(options[_luck.randi_range(0, options.size() - 1)]["family_id"])
		return ["build", {"hex": hex, "family": family, "tag": tag}]
	if roll < 8:
		return ["upgrade", {"hex": hex, "tag": tag}]
	return ["clear", {"hex": hex, "tag": tag}]


func test_home_rule_on_build_upgrade_and_clear() -> void:
	var g := ScenarioFixture.game()
	var alpha_hex := Vector2i(0, 2)
	var beta_hex := Vector2i(4, 2)
	assert_eq(Territory.owner_tag(g, alpha_hex), &"AAA")
	assert_eq(Territory.owner_tag(g, beta_hex), &"BBB")
	g.act("clear", {"hex": alpha_hex, "tag": &"AAA"})
	g.act("clear", {"hex": beta_hex, "tag": &"BBB"})
	g.events.clear()

	# No tag -> "choose your country first".
	for pick: Array in [
		["build", {"hex": alpha_hex, "family": ImproveRules.WHEAT}],
		["upgrade", {"hex": alpha_hex}],
		["clear", {"hex": alpha_hex}],
	]:
		var res := g.act(pick[0] as String, pick[1] as Dictionary)
		assert_false(bool(res["ok"]))
		assert_eq(str(res["reason"]), "choose your country first")

	# Another country's land -> "not your land: the %s holds it".
	var foreign := g.act("build", {"hex": beta_hex, "family": ImproveRules.WHEAT, "tag": &"AAA"})
	assert_false(bool(foreign["ok"]))
	assert_eq(str(foreign["reason"]), "not your land: the Duchy of Beta holds it")

	# Unowned land -> "no one holds this land".
	var unowned := g.act("build", {
		"hex": ScenarioFixture.UNOWNED_HEXES[0], "family": ImproveRules.WHEAT, "tag": &"AAA",
	})
	assert_false(bool(unowned["ok"]))
	assert_eq(str(unowned["reason"]), "no one holds this land")

	# Sea hex still gives the acting system's "not a land hex" even without tag.
	var sea := g.act("build", {"hex": ScenarioFixture.SEA_HEX, "family": ImproveRules.WHEAT})
	assert_false(bool(sea["ok"]))
	assert_eq(str(sea["reason"]), "not a land hex")

	# Own land -> build, upgrade, clear all succeed.
	assert_true(bool(g.act("build", {"hex": alpha_hex, "family": ImproveRules.WHEAT, "tag": &"AAA"})["ok"]))
	assert_true(bool(g.act("upgrade", {"hex": alpha_hex, "tag": &"AAA"})["ok"]))
	assert_true(bool(g.act("clear", {"hex": alpha_hex, "tag": &"AAA"})["ok"]))
	assert_eq(g.events.size(), 3)


func test_two_thousand_random_actions_with_actors_respect_home_rule() -> void:
	var game := ScenarioFixture.game(1480)
	_luck.seed_with(99)
	var done := {"build": 0, "upgrade": 0, "clear": 0}
	var refused := 0
	var played: Array = []
	for n: int in ACTIONS:
		var pick := _random_scenario_action(game)
		played.append(pick)
		var action: String = pick[0]
		var args: Dictionary = pick[1]
		var before := game.digest()
		game.events.clear()
		var verdict := game.check(action, args)
		assert_eq(game.digest(), before, "check changes nothing (%s %s)" % [action, args])
		assert_eq(game.events.size(), 0)
		var result := game.act(action, args)
		assert_eq(bool(result["ok"]), bool(verdict["ok"]))
		assert_eq(str(result["reason"]), str(verdict["reason"]))
		if bool(verdict["ok"]):
			done[action] = int(done[action]) + 1
			var hex: Vector2i = args["hex"]
			var tag: StringName = args["tag"]
			assert_ne(tag, &"", "accepted action has an actor")
			assert_eq(Territory.owner_tag(game, hex), tag, "accepted %s must be on actor's land" % action)
			assert_ne(game.digest(), before)
			assert_eq(game.events.size(), 1)
			assert_eq(str(game.events[0]["kind"]), "hex_changed")
		else:
			refused += 1
			assert_eq(game.digest(), before, "refused %s changes nothing" % action)
			assert_eq(game.events.size(), 0)
			assert_ne(str(verdict["reason"]), "")
	for action: String in done.keys():
		assert_gt(int(done[action]), 15, "enough %s actions accepted (%d)" % [action, int(done[action])])
	assert_gt(refused, 500, "enough refused actions including home-rule refusals")

	# Determinism: replaying the same seed and actions yields the same digest.
	var replay := ScenarioFixture.game(1480)
	for pick: Array in played:
		replay.act(pick[0] as String, pick[1] as Dictionary)
		replay.events.clear()
	assert_eq(replay.digest(), game.digest())


static func _snapshot_owned_fields(game: Game) -> Dictionary:
	var country_digests: Array[String] = []
	for c: Country in game.countries:
		country_digests.append(c.digest_text() if c != null else "")
	return {
		"main_use": game.state.main_use.duplicate(),
		"level": game.state.level.duplicate(),
		"owner": game.state.owner.duplicate(),
		"countries": country_digests,
		"player": game.player,
	}


static func _owns_violations(before: Dictionary, after: Dictionary, allowed: Array[String]) -> Array[String]:
	var violations: Array[String] = []
	for field: String in ["main_use", "level", "owner", "countries", "player"]:
		if not allowed.has(field) and before[field] != after[field]:
			violations.append(field)
	return violations


func test_owns_boundaries_and_planted_fault() -> void:
	assert_eq(Improve.OWNS, ["main_use", "level"])
	assert_eq(Territory.OWNS, ["owner"])
	assert_eq(Countries.OWNS, ["countries", "player"])

	var game := ScenarioFixture.game(1480)
	_luck.seed_with(21)
	for n: int in 300:
		var pick := _random_scenario_action(game)
		var snap := _snapshot_owned_fields(game)
		game.act(pick[0] as String, pick[1] as Dictionary)
		assert_eq(_owns_violations(snap, _snapshot_owned_fields(game), Improve.OWNS), [] as Array[String])

	var before_transfer := _snapshot_owned_fields(game)
	Territory.transfer(game, [ScenarioFixture.BETA_CAPITAL], 1)
	assert_eq(_owns_violations(before_transfer, _snapshot_owned_fields(game), Territory.OWNS), [] as Array[String])

	var before_choose := _snapshot_owned_fields(game)
	game.act("choose_country", {"tag": &"AAA"})
	assert_eq(_owns_violations(before_choose, _snapshot_owned_fields(game), Countries.OWNS), [] as Array[String])

	# Planted fault: a stub action registered by the test that writes `owner` is reported.
	var stub_check := func(_g: Game, _args: Dictionary) -> Dictionary: return {"ok": true, "reason": ""}
	var stub_do := func(g: Game, args: Dictionary) -> Dictionary:
		var idx := g.map.index_of(args["hex"] as Vector2i)
		g.state.owner[idx] = 2
		return {"ok": true, "reason": ""}
	Actions.register_test_action("_planted_owner_write", stub_check, stub_do)
	var before_fault := _snapshot_owned_fields(game)
	game.act("_planted_owner_write", {"hex": ScenarioFixture.ALPHA_CAPITAL})
	var violations := _owns_violations(before_fault, _snapshot_owned_fields(game), Improve.OWNS)
	Actions.clear_test_actions()
	assert_eq(violations, ["owner"] as Array[String], "planted fault writing owner must be reported")
