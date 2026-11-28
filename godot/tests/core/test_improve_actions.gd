## The game core's actions (docs/architecture/m1-build-spec.md sections 8 and 10, m3-build-spec.md 4.3 and 9): build,
## upgrade, clear and cancel_work through Game.act. Since M3 the first three begin a work and the works phase puts the
## piece. Check and action agree for thousands of random actions with season ends among them (a refused action changes
## nothing and queues nothing; an accepted one adds exactly one work and one event), the same seed and the same actions
## give the same Game.digest(), and only the owners write what they own.
extends GutTest

const MAP_FILE := "res://data/maps/north_italy.tres"
const DEFS_FILE := "res://data/defs/game_defs.tres"
const ACTIONS := 2000
const SEASON_EVERY := 50  # 2,000 actions hold 40 season ends

var _map: MapData = null
var _defs: GameDefs = null
var _luck := Rng.new()


func before_all() -> void:
	_map = load(MAP_FILE) as MapData
	_defs = load(DEFS_FILE) as GameDefs


func _game(seed_value: int = 1480) -> Game:
	return Game.new_game(_map, seed_value, _defs)


## Plays one picked action: a season end or a game action. Returns the verdict.
func _apply(game: Game, pick: Array) -> Dictionary:
	if pick[0] == "end_season":
		return Season.run(game)
	return game.act(pick[0] as String, pick[1] as Dictionary)


## A random action, biased so that most kinds succeed now and then: a build is mostly a family the hex lists, a cancel
## mostly a hex with a work; every SEASON_EVERY-th pick ends the season.
func _random_action(game: Game, n: int, tags: Array[StringName] = [&""]) -> Array:
	if n % SEASON_EVERY == SEASON_EVERY - 1:
		return ["end_season", {}]
	var m := game.map
	var hex := Vector2i(_luck.randi_range(-1, m.cols), _luck.randi_range(-1, m.rows))
	if _luck.randi_range(0, 9) > 0:
		hex = m.hex_of(_luck.randi_range(0, m.hex_count() - 1))
	var tag := tags[_luck.randi_range(0, tags.size() - 1)]
	var roll := _luck.randi_range(0, 9)
	if roll < 4:
		var family := _luck.randi_range(-1, ImproveRules.FAMILIES)
		var options := game.improvement.build_options(hex)
		if not options.is_empty() and _luck.randi_range(0, 9) < 7:
			family = int(options[_luck.randi_range(0, options.size() - 1)]["family_id"])
		return ["build", {"hex": hex, "family": family, "tag": tag}]
	if roll < 7:
		return ["upgrade", {"hex": hex, "tag": tag}]
	if roll < 8:
		return ["clear", {"hex": hex, "tag": tag}]
	if not game.state.works.is_empty() and _luck.randi_range(0, 9) < 8:
		var w := game.state.works[_luck.randi_range(0, game.state.works.size() - 1)]
		hex = w.hex
		if _luck.randi_range(0, 9) < 7:
			tag = w.tag
	return ["cancel_work", {"hex": hex, "tag": tag}]


## What the property tests assert about one accepted works action; `before` is the digest and `works_before` the count.
func _assert_accepted(game: Game, action: String, args: Dictionary, works_before: int) -> void:
	assert_eq(game.events.size(), 1, "exactly one event")
	if action == "cancel_work":
		assert_eq(game.state.works.size(), works_before - 1, "one work less")
		assert_eq(str(game.events[0]["kind"]), "work_cancelled")
		assert_eq(str(game.events[0]["why"]), "order")
	else:
		assert_eq(game.state.works.size(), works_before + 1, "exactly one work more")
		assert_eq(str(game.events[0]["kind"]), "work_started")
		assert_eq(game.state.works[game.state.works.size() - 1].action, StringName(action))
	assert_eq(game.events[0]["hex"], args["hex"])


## After a season: every finished work's hex holds its target.
func _assert_finished_stand(game: Game) -> int:
	var finished := 0
	for event: Dictionary in game.events:
		if str(event["kind"]) != "work_finished":
			continue
		finished += 1
		var work := Work.from_dict(event["work"] as Dictionary)
		assert_not_null(work)
		var i := game.map.index_of(work.hex)
		match work.action:
			&"build":
				assert_eq(int(game.state.main_use[i]), work.family, "a finished build stands")
				assert_eq(int(game.state.level[i]), 1)
			&"upgrade":
				assert_eq(int(game.state.level[i]), work.level_to, "a finished upgrade stands")
			&"clear":
				assert_eq(int(game.state.main_use[i]), 0, "a finished clearing leaves wild land")
	return finished


func test_check_and_action_agree_for_two_thousand_random_actions() -> void:
	assert_not_null(_map, "the map file loads")
	var game := _game()
	_luck.seed_with(42)
	var done := {"build": 0, "upgrade": 0, "clear": 0, "cancel_work": 0, "end_season": 0}
	var refused := 0
	var finished := 0
	for n: int in ACTIONS:
		var pick := _random_action(game, n)
		var action: String = pick[0]
		var args: Dictionary = pick[1]
		game.events.clear()
		if action == "end_season":
			assert_true(bool(Season.run(game)["ok"]))
			done[action] = int(done[action]) + 1
			finished += _assert_finished_stand(game)
			continue
		var before := game.digest()
		var works_before := game.state.works.size()
		var verdict := game.check(action, args)
		assert_eq(game.digest(), before, "a check changes nothing (%s %s)" % [action, args])
		assert_eq(game.events.size(), 0, "a check queues nothing")
		var result := game.act(action, args)
		assert_eq(bool(result["ok"]), bool(verdict["ok"]), "check and action agree (%s %s)" % [action, args])
		assert_eq(str(result["reason"]), str(verdict["reason"]), "and say the same reason")
		if bool(verdict["ok"]):
			done[action] = int(done[action]) + 1
			assert_ne(game.digest(), before, "an accepted %s changes the state" % action)
			_assert_accepted(game, action, args, works_before)
			assert_eq(str(result["reason"]), "", "no reason when ok")
		else:
			refused += 1
			assert_eq(game.digest(), before, "a refused %s changes nothing (%s)" % [action, verdict["reason"]])
			assert_eq(game.events.size(), 0, "and queues nothing")
			assert_ne(str(verdict["reason"]), "", "a refusal says why")
	assert_eq(int(done["end_season"]), 40, "forty season ends")
	assert_eq(game.turn, 41)
	for action: String in ["build", "upgrade", "clear", "cancel_work"]:
		assert_gt(int(done[action]), 10, "enough %s actions were accepted (%d)" % [action, int(done[action])])
	assert_gt(refused, 100, "and enough refused")
	assert_gt(finished, 5, "and works finished")


func test_the_same_seed_and_the_same_actions_give_the_same_digest() -> void:
	var a := _game(7)
	var b := _game(7)
	assert_eq(a.digest(), b.digest(), "the same seed, the same game")
	assert_ne(_game(8).digest(), a.digest(), "another seed, another game")
	_luck.seed_with(5)
	var played: Array = []
	for n: int in 600:
		played.append(_random_action(a, n))
	for pick: Array in played:
		_apply(a, pick)
		_apply(b, pick)
		a.events.clear()
		b.events.clear()
	assert_eq(a.digest(), b.digest(), "the same actions, the same game")
	assert_ne(a.digest(), _game(7).digest(), "and the actions changed it")


func test_only_the_owners_write_what_they_own() -> void:
	assert_eq(Improve.OWNS, ["main_use", "level"])
	assert_eq(Works.OWNS, ["works", "next_work_id"])
	var state := MapState.create(_map)
	# M7 (5.2): the occupation arrays are MapState fields too; RQ1 (recruitment-queue.md 6): so are the barracks.
	var known_fields: Array[String] = ["main_use", "level", "owner", "works", "next_work_id", "people", "people_start", "people_end",
		"occupier", "garrison", "unsupported", "barracks"]
	for property: Dictionary in state.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			assert_true(known_fields.has(str(property["name"])), "%s is a known MapState field" % property["name"])
	var game := _game()
	var owner_before := game.state.owner.duplicate()
	var map_before := _map.digest()
	_luck.seed_with(11)
	for n: int in 500:
		var pick := _random_action(game, n)
		var use_before := game.state.main_use.duplicate()
		var level_before := game.state.level.duplicate()
		_apply(game, pick)
		if pick[0] != "end_season":
			assert_eq(game.state.main_use, use_before, "an action writes no piece (%s)" % pick[0])
			assert_eq(game.state.level, level_before)
	assert_eq(_map.digest(), map_before, "the fixed map is never written")
	assert_eq(game.state.owner, owner_before, "no work writes owner")
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
	assert_true(Actions.NAMES.has("cancel_work"))
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
	assert_false(bool(game.act("cancel_work", {"hex": sea})["ok"]))


func test_build_upgrade_clear_on_a_known_hex() -> void:
	var m := ImproveFixture.block(5, 5, {}, {Vector2i(2, 2): {"place": ImproveFixture.place(2)}})
	var game := Game.new_game(m, 3, _defs)
	for hex: Vector2i in game.improvement.hexes:
		game.improvement.clear(hex)  # the village of the data stays, the search's choices go
	assert_eq(game.state.main_use[m.index_of(Vector2i(2, 2))], ImproveRules.SETTLEMENT, "a place is never pulled down")
	var hex := Vector2i(3, 2)
	var i := m.index_of(hex)
	var built := game.act("build", {"hex": hex, "family": ImproveRules.WHEAT})
	assert_true(bool(built["ok"]), str(built["reason"]))
	assert_eq(game.state.main_use[i], 0, "nothing stands yet")
	assert_eq(game.state.works.size(), 1)
	assert_eq(game.state.works[0].seasons, 4)
	assert_false(bool(game.act("build", {"hex": hex, "family": ImproveRules.WHEAT})["ok"]), "no second work on one hex")
	for n: int in 3:
		Season.run(game)
		assert_eq(game.state.main_use[i], 0, "still under way")
	Season.run(game)
	assert_eq(game.turn, 5)
	assert_eq(game.state.main_use[i], ImproveRules.WHEAT, "it stands from the fifth season")
	assert_eq(game.state.level[i], 1)
	assert_eq(Improve.piece_at(game, hex)["family"], "wheat")
	assert_eq(MapCells.piece_of(m, game.state, hex), Improve.piece_at(game, hex), "the map view and the rules share one piece")
	assert_true(game.state.works.is_empty())
	assert_true(bool(game.act("upgrade", {"hex": hex})["ok"]))
	for n: int in 8:
		Season.run(game)
	assert_eq(game.state.level[i], 2)
	assert_true(bool(game.act("clear", {"hex": hex})["ok"]))
	Season.run(game)
	assert_eq(game.state.main_use[i], 0)
	assert_false(Improve.build_options(game, hex).is_empty(), "a wild hex lists what it may take again")


func _scenario_game(seed_value: int = 1480) -> Game:
	var g := ScenarioFixture.game(seed_value)
	g.act("choose_country", {"tag": &"AAA"})
	return g


func test_home_rule_on_build_upgrade_and_clear() -> void:
	var g := ScenarioFixture.game()
	var alpha_hex := Vector2i(0, 2)
	var beta_hex := Vector2i(4, 2)
	assert_eq(Territory.owner_tag(g, alpha_hex), &"AAA")
	assert_eq(Territory.owner_tag(g, beta_hex), &"BBB")
	g.improvement.clear(alpha_hex)
	g.improvement.clear(beta_hex)
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

	# Own land: a build begins a work; once it stands, an upgrade and a clearing begin theirs.
	assert_true(bool(g.act("build", {"hex": alpha_hex, "family": ImproveRules.WHEAT, "tag": &"AAA"})["ok"]))
	g.act("choose_country", {"tag": &"AAA"})
	for n: int in 4:
		Season.run(g)
	assert_eq(Improve.piece_at(g, alpha_hex)["family"], "wheat")
	assert_true(bool(g.act("upgrade", {"hex": alpha_hex, "tag": &"AAA"})["ok"]))
	assert_eq(g.state.works.size(), 1)
	assert_true(bool(g.act("cancel_work", {"hex": alpha_hex, "tag": &"AAA"})["ok"]))
	assert_true(bool(g.act("clear", {"hex": alpha_hex, "tag": &"AAA"})["ok"]))


func test_two_thousand_random_actions_with_actors_respect_home_rule() -> void:
	var game := _scenario_game()
	_luck.seed_with(99)
	var done := {"build": 0, "upgrade": 0, "clear": 0, "cancel_work": 0, "end_season": 0}
	var refused := 0
	var finished := 0
	var played: Array = []
	for n: int in ACTIONS:
		var pick := _random_action(game, n, ScenarioFixture.ALL_ACTORS)
		played.append(pick)
		var action: String = pick[0]
		var args: Dictionary = pick[1]
		game.events.clear()
		if action == "end_season":
			assert_true(bool(Season.run(game)["ok"]))
			done[action] = int(done[action]) + 1
			finished += _assert_finished_stand(game)
			_assert_people_closed(game)
			for c: Country in game.countries:
				var total := Works.slots(game, c.tag)
				assert_true(total < 0 or Works.in_use(game, c.tag) <= total, "slots are never exceeded")
			continue
		var before := game.digest()
		var works_before := game.state.works.size()
		var verdict := game.check(action, args)
		assert_eq(game.digest(), before, "check changes nothing (%s %s)" % [action, args])
		assert_eq(game.events.size(), 0)
		var result := game.act(action, args)
		assert_eq(bool(result["ok"]), bool(verdict["ok"]))
		assert_eq(str(result["reason"]), str(verdict["reason"]))
		if bool(verdict["ok"]):
			done[action] = int(done[action]) + 1
			var tag: StringName = args["tag"]
			assert_ne(tag, &"", "accepted action has an actor")
			if action != "cancel_work":
				assert_eq(Territory.owner_tag(game, args["hex"] as Vector2i), tag,
					"accepted %s must be on actor's land" % action)
			assert_ne(game.digest(), before)
			_assert_accepted(game, action, args, works_before)
			var total := Works.slots(game, tag)
			assert_true(total < 0 or Works.in_use(game, tag) <= total, "slots are never exceeded")
		else:
			refused += 1
			assert_eq(game.digest(), before, "refused %s changes nothing" % action)
			assert_eq(game.events.size(), 0)
			assert_ne(str(verdict["reason"]), "")
	assert_eq(int(done["end_season"]), 40)
	for action: String in ["build", "upgrade", "clear", "cancel_work"]:
		assert_gt(int(done[action]), 2, "enough %s actions accepted (%d)" % [action, int(done[action])])
	assert_gt(refused, 500, "enough refused actions including home-rule refusals")
	assert_gt(finished, 0, "and works finished")

	# Determinism: replaying the same seed and actions yields the same digest.
	var replay := _scenario_game()
	for pick: Array in played:
		_apply(replay, pick)
		replay.events.clear()
	assert_eq(replay.digest(), game.digest())


## The people phase inside the season end (M5): nobody below 0 or at sea, and every country's closed flows are the change of its
## hexes' people over the season ended (the actions never move people, and no hex changes hands here).
func _assert_people_closed(game: Game) -> void:
	var change := {}
	for i: int in game.map.hex_count():
		assert_gte(int(game.state.people[i]), 0, "no hex below 0")
		if game.map.land[i] == 0:
			assert_eq(int(game.state.people[i]), 0, "no people at sea")
		var id := int(game.state.owner[i])
		change[id] = int(change.get(id, 0)) + int(game.state.people_end[i]) - int(game.state.people_start[i])
	for c: Country in game.countries:
		var sum := 0
		for f: int in (c.people_closed["flows"] as PackedInt32Array):
			sum += f
		assert_eq(int(change.get(c.id, 0)), sum, "%s: the closed flows are the change" % c.tag)


static func _snapshot_owned_fields(game: Game) -> Dictionary:
	var country_digests: Array[String] = []
	var purse: Array = []
	var stores: Array = []
	for c: Country in game.countries:
		# the countries' own fields; the money and the goods are the doors' (Treasury's and Stores')
		country_digests.append("%d|%s|%s|%s|%d|%d" % [c.id, c.tag, c.capital, c.alive, c.tax, c.short_mask] if c != null else "")
		purse.append(var_to_bytes([c.treasury, c.ledger_open, c.ledger_from, c.ledger_closed]))
		stores.append(var_to_bytes([c.stock, c.flows_open, c.stock_from, c.goods_closed]))
	var work_texts: Array[String] = []
	for w: Work in game.state.works:
		work_texts.append(w.digest_text())
	return {
		"main_use": game.state.main_use.duplicate(),
		"level": game.state.level.duplicate(),
		"owner": game.state.owner.duplicate(),
		"works": work_texts,
		"next_work_id": game.state.next_work_id,
		"countries": country_digests,
		"purse": purse,
		"stores": stores,
		"player": game.player,
	}


static func _owns_violations(before: Dictionary, after: Dictionary, allowed: Array[String]) -> Array[String]:
	var violations: Array[String] = []
	for field: String in ["main_use", "level", "owner", "works", "next_work_id", "countries", "purse", "stores", "player"]:
		if not allowed.has(field) and before[field] != after[field]:
			violations.append(field)
	return violations


func test_owns_boundaries_and_planted_fault() -> void:
	assert_eq(Improve.OWNS, ["main_use", "level"])
	assert_eq(Works.OWNS, ["works", "next_work_id"])
	assert_eq(Territory.OWNS, ["owner"])
	assert_eq(Countries.OWNS, ["countries", "player"])

	var game := ScenarioFixture.game(1480)
	_luck.seed_with(21)
	for n: int in 300:
		var pick := _random_action(game, 0, ScenarioFixture.ALL_ACTORS)
		var snap := _snapshot_owned_fields(game)
		game.act(pick[0] as String, pick[1] as Dictionary)
		var allowed_by_action: Array[String] = ["works", "next_work_id", "purse", "stores"]  # a work is paid through the doors
		assert_eq(_owns_violations(snap, _snapshot_owned_fields(game), allowed_by_action), [] as Array[String],
			"an action writes only works, next_work_id and, through the doors, the purse and the stores")

	var before_transfer := _snapshot_owned_fields(game)
	Territory.transfer(game, [ScenarioFixture.BETA_CAPITAL], 1)
	assert_eq(_owns_violations(before_transfer, _snapshot_owned_fields(game), Territory.OWNS), [] as Array[String])

	var before_choose := _snapshot_owned_fields(game)
	game.act("choose_country", {"tag": &"AAA"})
	assert_eq(_owns_violations(before_choose, _snapshot_owned_fields(game), Countries.OWNS), [] as Array[String])

	# The works phase writes works and, through Improve, main_use and level; nothing else.
	for n: int in 12:
		var snap := _snapshot_owned_fields(game)
		Works.season(game)
		var allowed: Array[String] = ["works", "next_work_id", "main_use", "level"]
		assert_eq(_owns_violations(snap, _snapshot_owned_fields(game), allowed), [] as Array[String])
		game.turn += 1

	# Planted fault: a stub action registered by the test that writes `owner` is reported.
	var stub_check := func(_g: Game, _args: Dictionary) -> Dictionary: return {"ok": true, "reason": ""}
	var stub_do := func(g: Game, args: Dictionary) -> Dictionary:
		var idx := g.map.index_of(args["hex"] as Vector2i)
		g.state.owner[idx] = 2
		return {"ok": true, "reason": ""}
	Actions.register_test_action("_planted_owner_write", stub_check, stub_do)
	var before_fault := _snapshot_owned_fields(game)
	game.act("_planted_owner_write", {"hex": ScenarioFixture.ALPHA_CAPITAL})
	var violations := _owns_violations(before_fault, _snapshot_owned_fields(game), Works.OWNS)
	Actions.clear_test_actions()
	assert_eq(violations, ["owner"] as Array[String], "planted fault writing owner must be reported")
