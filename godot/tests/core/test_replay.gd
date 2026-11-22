## Replay (docs/architecture/m3-build-spec.md 4.5, 5.4, 9): 20 seasons of seeded random actions and one dev_transfer;
## the same seed and the same log give the same digest; one changed logged argument gives another.
extends GutTest

var _fx: Dictionary = {}


func before_each() -> void:
	_fx = ScenarioFixture.build()


func _map() -> MapData:
	return _fx["map"] as MapData


func _defs() -> GameDefs:
	return _fx["defs"] as GameDefs


## A game of 20 seasons: some random works actions each season, a dev_transfer in the 10th.
func _played(seed_value: int) -> Game:
	var g := Game.new_scenario(_map(), _defs(), _fx["scenario"] as ScenarioDef, seed_value)
	var luck := Rng.new()
	luck.seed_with(seed_value)
	assert_true(bool(g.act("choose_country", {"tag": &"AAA"})["ok"]))
	for season: int in 20:
		for k: int in 4:
			var hex := _map().hex_of(luck.randi_range(0, _map().hex_count() - 1))
			var options := g.improvement.build_options(hex)
			if luck.randi_range(0, 2) == 0:
				g.act("clear", {"hex": hex, "tag": &"AAA"})
			elif luck.randi_range(0, 3) == 0:
				g.act("upgrade", {"hex": hex, "tag": &"AAA"})
			elif luck.randi_range(0, 5) == 0:
				g.act("cancel_work", {"hex": hex, "tag": &"AAA"})
			elif not options.is_empty():
				var o := options[luck.randi_range(0, options.size() - 1)]
				g.act("build", {"hex": hex, "family": int(o["family_id"]), "tag": &"AAA"})
		if season == 9:
			var moved: Array[Vector2i] = [ScenarioFixture.UNOWNED_HEXES[0], ScenarioFixture.UNOWNED_HEXES[1]]
			assert_gt(g.dev_transfer(moved, 1), 0)
		Season.run(g)
	return g


func _replay(g: Game, log: Array[Dictionary]) -> Game:
	return Replay.run(_map(), _defs(), g.scenario.id, g.seed_value, log)


## 20 seasons with real growth (north Italy, Genoa), a level change and dev_people in the log.
func _grown() -> Game:
	var g := PeopleFixture.genoa(PeopleFixture.always_fed())
	g.dev_people(Vector2i(6, 11), 3990)  # the village near Turin is nearly full and grows into a town
	for season: int in 20:
		if season == 5:
			g.dev_people(Vector2i(6, 13), 2500)
		Season.run(g)
	return g


func test_growth_a_level_change_and_dev_people_replay_to_the_same_digest() -> void:
	var g := _grown()
	var kinds := {}
	for e: Dictionary in g.events:
		kinds[e["kind"]] = true
	assert_true(kinds.has("town_grew"), "a village grew in the run: %s" % str(kinds.keys()))
	var again := Replay.run(g.map, g.defs, g.scenario.id, g.seed_value, g.action_log)
	assert_not_null(again)
	assert_eq(again.digest(), g.digest())
	assert_eq(again.state.people, g.state.people)


func test_p_a_changed_dev_people_value_gives_another_digest() -> void:
	var g := _grown()
	var log: Array[Dictionary] = []
	for r: Dictionary in g.action_log:
		log.append(r.duplicate(true))
	var found := false
	for r: Dictionary in log:
		if r["action"] == "dev_people" and (r["args"] as Dictionary)["people"] == 2500:
			(r["args"] as Dictionary)["people"] = 2600
			found = true
	assert_true(found)
	assert_ne(Replay.run(g.map, g.defs, g.scenario.id, g.seed_value, log).digest(), g.digest())


func test_the_same_seed_and_log_give_the_same_digest() -> void:
	for seed_value: int in [1480, 7]:
		var g := _played(seed_value)
		var kinds := {}
		for r: Dictionary in g.action_log:
			kinds[r["action"]] = true
		assert_true(kinds.has("build") and kinds.has("end_season") and kinds.has("dev_transfer"), str(kinds.keys()))
		assert_eq(g.turn, 21)
		var again := _replay(g, g.action_log)
		assert_not_null(again)
		assert_eq(again.digest(), g.digest(), "seed %d" % seed_value)
		assert_eq(again.action_log, g.action_log, "the replay writes the same log")


func test_a_replay_through_a_save_gives_the_same_digest() -> void:
	var g := _played(1480)
	var body := bytes_to_var(var_to_bytes(Snapshot.of(g))) as Dictionary
	var back := Snapshot.restore(body, _map(), _defs())["game"] as Game
	assert_eq(_replay(back, back.action_log).digest(), g.digest())


## Armies: 20 seasons of the random player for two countries (raises, marches, splits, merges, disbands) replay to the
## same digest, the log written the same (M6 L13: "replay equals live").
func _armies_played(seed_value: int) -> Game:
	var g := EconomyFixture.game(&"GEN", false, false, seed_value, false)
	var luck := Rng.new()
	luck.seed_with(seed_value)
	# Every rig goes through the log: money, goods, people (dev_*), and one raise per country at a settlement of its own;
	# then each army is sent off to a hex of its country (a march that the door accepts is logged).
	var armies: Array[int] = []
	for tag: StringName in [&"GEN", &"SAV"]:
		g.dev_money(tag, 100000)
		for good: int in g.defs.goods.size():
			g.dev_goods(tag, good, 200)
		var c := Countries.by_tag(g, tag)
		for i: int in Territory.districts(g, c.id):
			if g.state.main_use[i] == Economy.SETTLEMENTS:
				var hex := g.map.hex_of(i)
				g.dev_people(hex, 10000)
				var raised := g.act("raise", {"hex": hex, "kind": 0, "count": 2, "tag": tag})
				if bool(raised["ok"]):
					armies.append(int(raised["army"]))
				break
	for id: int in armies:
		var own := Territory.districts(g, Countries.by_tag(g, Armies.by_id(g, id).tag).id)
		for k: int in mini(own.size(), 40):
			var goal := g.map.hex_of(own[k * 7 % own.size()])
			if bool(g.act("march", {"army": id, "goal": goal, "tag": Armies.by_id(g, id).tag})["ok"]):
				break
	for season: int in 20:
		for tag: StringName in [&"GEN", &"SAV"]:
			for _k: int in 4:
				var pick: Dictionary = RandomPlayer.next(g, tag, luck)
				g.act(str(pick["action"]), pick["args"])
		Season.run(g)
	return g


func test_armies_replay_to_the_same_digest() -> void:
	var g := _armies_played(1480)
	var logged := {}
	for r: Dictionary in g.action_log:
		logged[r["action"]] = true
	assert_true(logged.has("raise") and logged.has("march"), "raises and marches were logged: %s" % str(logged.keys()))
	var again := Replay.run(g.map, g.defs, g.scenario.id, g.seed_value, g.action_log)
	assert_not_null(again)
	assert_eq(again.digest(), g.digest(), "the replay equals the live game")
	assert_eq(again.action_log, g.action_log, "the replay writes the same log")


func test_p_a_changed_raise_gives_another_game() -> void:
	# The first logged raise with one company fewer: the replay is another game (or refused: null), never the same digest.
	var g := _armies_played(1480)
	var log: Array[Dictionary] = []
	for r: Dictionary in g.action_log:
		log.append(r.duplicate(true))
	var first := -1
	for n: int in log.size():
		if log[n]["action"] == "raise":
			first = n
			break
	assert_gte(first, 0, "a raise was logged")
	(log[first]["args"] as Dictionary)["count"] = 1
	var again := Replay.run(g.map, g.defs, g.scenario.id, g.seed_value, log)
	assert_true(again == null or again.digest() != g.digest(), "one company fewer gives another game")


func test_a_map_only_replay() -> void:
	var g := Game.new_game(_map(), 5, _defs())
	g.act("build", {"hex": Vector2i(1, 1), "family": ImproveRules.WHEAT})
	Season.run(g)
	Season.run(g)
	var again := Replay.run(_map(), _defs(), "", 5, g.action_log)
	assert_eq(again.digest(), g.digest())


func test_an_unknown_scenario_gives_null() -> void:
	assert_null(Replay.run(_map(), _defs(), "no_such", 1, [] as Array[Dictionary]))


func test_p_one_changed_argument_gives_another_digest() -> void:
	var g := _played(1480)
	var base := g.digest()
	var changed := 0
	var built := false
	for i: int in g.action_log.size():
		var record := g.action_log[i]
		if record["action"] == "dev_transfer":
			var log := g.action_log.duplicate(true)
			(log[i]["args"] as Dictionary)["to_id"] = 2
			assert_ne(_replay(g, log).digest(), base, "dev_transfer to another country")
			changed += 1
		elif record["action"] == "build" and not built:
			var log := g.action_log.duplicate(true)
			(log[i]["args"] as Dictionary)["family"] = ImproveRules.TIMBER if int(record["args"]["family"]) != ImproveRules.TIMBER else ImproveRules.WHEAT
			assert_ne(_replay(g, log).digest(), base, "build of another family, record %d" % i)
			changed += 1
			built = true
	assert_eq(changed, 2)
	var dropped := g.action_log.duplicate(true)
	dropped.remove_at(dropped.size() - 1)  # the season ends with its mark (M8): drop both
	dropped.remove_at(dropped.size() - 1)
	assert_ne(_replay(g, dropped).digest(), base, "a missing last season")


func test_the_developer_transfers_replay_to_the_same_game() -> void:
	var g := Game.new_scenario(_map(), _defs(), _fx["scenario"] as ScenarioDef, 3)
	assert_true(bool(g.act("choose_country", {"tag": &"AAA"})["ok"]))
	assert_true(g.dev_money(&"AAA", 700))
	assert_true(g.dev_goods(&"AAA", 12, 25))
	assert_true(bool(g.act("set_tax", {"level": 2, "tag": &"AAA"})["ok"]))
	Season.run(g)
	assert_true(g.dev_money(&"AAA", -40))
	Season.run(g)
	var kinds := {}
	for r: Dictionary in g.action_log:
		kinds[r["action"]] = true
	assert_true(kinds.has("dev_money") and kinds.has("dev_goods") and kinds.has("set_tax"), str(kinds.keys()))
	var again := _replay(g, g.action_log)
	assert_eq(again.digest(), g.digest())
	assert_eq(again.action_log, g.action_log, "the replay writes the same log")
	assert_eq(Countries.by_tag(again, &"AAA").treasury, Countries.by_tag(g, &"AAA").treasury)
	var changed: Array[Dictionary] = []
	for r: Dictionary in g.action_log:
		var copy := r.duplicate(true)
		if copy["action"] == "dev_money" and int(copy["args"]["amount"]) == 700:
			copy["args"]["amount"] = 701
		changed.append(copy)
	assert_ne(_replay(g, changed).digest(), g.digest(), "one changed logged amount gives another game")


# ----- M8: AI-only seasons replay from the log with no AI (m8-build-spec.md 4.15) ---------------------------------------------


func test_forty_ai_only_seasons_replay_to_the_same_digest_with_no_hook() -> void:
	var g := OrdersFixture.watched()
	for n: int in 40:
		assert_true(bool(Season.run(g)["ok"]))
	var kinds := {}
	for r: Dictionary in g.action_log:
		kinds[r["action"]] = true
	assert_true(kinds.has("watch") and kinds.has("set_tax") and kinds.has("orders_done"), str(kinds.keys()))
	var again := _replay(g, g.action_log)
	assert_not_null(again)
	assert_null(again.orders, "nothing attached")
	assert_true(again.ai_only, "the watch record")
	assert_eq(again.digest(), g.digest())
	assert_eq(again.action_log, g.action_log)


func test_p_one_changed_ai_record_gives_another_digest() -> void:
	var g := OrdersFixture.watched()
	for n: int in 6:
		Season.run(g)
	var log: Array[Dictionary] = []
	for r: Dictionary in g.action_log:
		log.append(r.duplicate(true))
	var mark := 0
	while str(log[mark]["action"]) != "orders_done":
		mark += 1
	assert_eq(str(log[mark - 1]["action"]), "set_tax")
	var args := log[mark - 1]["args"] as Dictionary
	args["level"] = (int(args["level"]) + 1) % 3
	assert_ne(_replay(g, log).digest(), g.digest())


func test_a_watch_record_is_replayed_and_a_pre_pick_game_is_not_ai_only() -> void:
	var g := ScenarioFixture.game()
	g.watch()
	assert_true(_replay(g, g.action_log).ai_only)
	var none: Array[Dictionary] = []
	assert_false(_replay(g, none).ai_only)
