## GUT tests for Session lifecycle (unsaved_actions, start_game/new_game reset, end_game -> Events.game_ended)
## (docs/architecture/ui-and-controls-spec.md section 3.6; ui-and-controls-plan.md U8).
extends GutTest

var _prev_game: Game = null
var _prev_unsaved: int = 0
var _prev_defs: GameDefs = null
var _prev_origin: Dictionary = {}


func before_each() -> void:
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	_prev_defs = Session._defs
	_prev_origin = Session._origin


func after_each() -> void:
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	Session._defs = _prev_defs
	Session._origin = _prev_origin


func _first_buildable() -> Dictionary:
	var g := Session.game
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 0 or not Improve.piece_at(g, hex).is_empty():
			continue
		for option: Dictionary in Improve.build_options(g, hex):
			if bool(option["ok"]):
				return {"hex": hex, "family": int(option["family_id"])}
	return {}


func test_unsaved_actions_counts_successful_acts_and_resets_on_new_or_start_game() -> void:
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	assert_not_null(Session.game)
	assert_eq(Session.unsaved_actions, 0, "new_game resets unsaved_actions to 0")

	# Refused act must not increment unsaved_actions
	var refused := Session.act("upgrade", {"hex": Vector2i(-1, -1)})
	assert_false(bool(refused.get("ok", false)))
	assert_eq(Session.unsaved_actions, 0, "refused act leaves unsaved_actions unchanged")

	var target := _first_buildable()
	assert_false(target.is_empty(), "north_italy has a buildable hex")
	var hex := target["hex"] as Vector2i
	var built := Session.act("build", {"hex": hex, "family": int(target["family"])})
	assert_true(bool(built.get("ok", false)))
	assert_eq(Session.unsaved_actions, 1, "successful build increments unsaved_actions")

	# A build is a work now: the clear is refused until it stands (each season end is unsaved play too).
	assert_false(bool(Session.act("clear", {"hex": hex}).get("ok", true)), "a hex under work cannot be cleared")
	var guard := 0
	while Session.game.state.work_at(hex) != null and guard < 40:
		Session.end_season()
		guard += 1
	assert_null(Session.game.state.work_at(hex), "the build stands")
	var before_clear := Session.unsaved_actions
	var cleared := Session.act("clear", {"hex": hex})
	assert_true(bool(cleared.get("ok", false)))
	assert_eq(Session.unsaved_actions, before_clear + 1, "successful clear increments unsaved_actions")

	# new_game resets unsaved_actions
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED + 1)
	assert_eq(Session.unsaved_actions, 0, "second new_game resets unsaved_actions")

	# start_game with existing Game also resets unsaved_actions
	assert_true(bool(Session.act("build", {"hex": _first_buildable()["hex"], "family": int(_first_buildable()["family"])}).get("ok", false)))
	assert_eq(Session.unsaved_actions, 1)
	var fake := FakeMap.build(10, 10, 1)
	Session.start_game(Game.with_state(fake, MapState.create(fake)))
	assert_eq(Session.unsaved_actions, 0, "start_game resets unsaved_actions")


func test_end_game_clears_game_resets_unsaved_and_emits_game_ended() -> void:
	var ended_count := [0]
	var on_ended := func() -> void: ended_count[0] += 1
	Events.game_ended.connect(on_ended)

	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	var target := _first_buildable()
	assert_true(bool(Session.act("build", {"hex": target["hex"], "family": int(target["family"])}).get("ok", false)))
	assert_eq(Session.unsaved_actions, 1)

	Session.end_game()
	Events.game_ended.disconnect(on_ended)

	assert_null(Session.game, "end_game clears Session.game")
	assert_eq(Session.unsaved_actions, 0, "end_game resets unsaved_actions")
	assert_eq(ended_count[0], 1, "end_game emits Events.game_ended once")

	var check_res := Session.check("build", {"hex": Vector2i.ZERO, "family": 1})
	assert_false(bool(check_res.get("ok", false)))
	assert_eq(str(check_res.get("reason", "")), "no game")


const SCENARIO := "north_italy_1480"


func _count_signal_emissions(sig: Signal, log: Array) -> Callable:
	var handler := func(value: Variant = null) -> void: log.append(value)
	sig.connect(handler)
	return handler


func test_new_scenario_without_a_player_starts_a_scenario_game() -> void:
	assert_not_null(Session.defs(), "the defs load and validate")
	assert_eq(Session.new_scenario(SCENARIO, 7), "")
	assert_not_null(Session.game)
	assert_true(Session.game.has_countries())
	assert_eq(Session.game.seed_value, 7)
	assert_eq(Session.player_tag(), &"", "no pick yet")


func test_new_scenario_with_a_player_chooses_it_and_announces_once() -> void:
	var log: Array = []
	var handler := _count_signal_emissions(Events.country_chosen, log)
	var problem := Session.new_scenario(SCENARIO, 3, &"GEN")
	Events.country_chosen.disconnect(handler)
	assert_eq(problem, "")
	assert_eq(Session.player_tag(), &"GEN")
	assert_eq(log, [&"GEN"], "country_chosen emitted once")
	assert_true(Session.game.events.is_empty(), "the queue is drained")
	assert_eq(Session.unsaved_actions, 1, "choose_country counts as an action")


func test_new_scenario_planted_problems_return_the_problem_and_start_nothing() -> void:
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	var before := Session.game
	assert_ne(Session.new_scenario("no_such_scenario", 1), "", "unknown scenario")
	assert_same(Session.game, before, "nothing started")
	var bad := Session.defs().duplicate() as GameDefs
	var scen := Session.defs().scenario(SCENARIO).duplicate() as ScenarioDef
	scen.owner = PackedByteArray([1, 2, 3])
	bad.scenarios = [scen] as Array[ScenarioDef]
	Session._defs = bad
	var problem := Session.new_scenario(SCENARIO, 1)
	assert_ne(problem, "", "a bad owner grid is reported")
	assert_false("\n" in problem, "the first line only")
	assert_same(Session.game, before, "a bad scenario starts nothing")
	scen.map_id = "no_such_map"
	assert_string_contains(Session.new_scenario(SCENARIO, 1), "no_such_map")
	assert_same(Session.game, before)


func test_act_and_check_fill_the_players_tag_without_touching_the_args() -> void:
	Session.new_scenario(SCENARIO, 5, &"GEN")
	var args: Dictionary = {"hex": Vector2i(-1, -1)}
	var verdict := Session.check("clear", args)
	assert_false(bool(verdict["ok"]))
	assert_false(args.has("tag"), "the caller's dictionary is not changed")
	var home := Session.game.countries[Session.game.scenario.id_of(&"GEN") - 1].capital
	var own := Session.check("clear", {"hex": home})
	assert_ne(str(own["reason"]), "unknown action: clear")
	# choose_country with no tag: after the pick the tag is filled with the player's, so it is refused as chosen.
	var again := Session.check("choose_country", {})
	assert_false(bool(again["ok"]))
	assert_string_contains(str(again["reason"]), "chosen already")
	# an explicit tag is kept
	var explicit := Session.check("choose_country", {"tag": &"VEN"})
	assert_string_contains(str(explicit["reason"]), "chosen already")


func test_act_fills_tag_for_player_actions_in_a_scenario_game() -> void:
	Session.new_scenario(SCENARIO, 5, &"GEN")
	var game := Session.game
	var own_hex := Vector2i(-1, -1)
	var gen_id := game.scenario.id_of(&"GEN")
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if int(game.state.owner[i]) == gen_id and Improve.piece_at(game, hex).is_empty():
			for option: Dictionary in Improve.build_options(game, hex):
				if bool(option["ok"]):
					own_hex = hex
					break
		if own_hex != Vector2i(-1, -1):
			break
	assert_ne(own_hex, Vector2i(-1, -1), "Genoa has a buildable hex")
	var options := Improve.build_options(game, own_hex)
	var family := 0
	for option: Dictionary in options:
		if bool(option["ok"]):
			family = int(option["family_id"])
			break
	var verdict := Session.act("build", {"hex": own_hex, "family": family})
	assert_true(bool(verdict.get("ok", false)), str(verdict.get("reason", "")))


func test_transfer_then_drain_emits_owners_changed_once_with_the_changed_hexes() -> void:
	Session.new_scenario(SCENARIO, 5)
	var game := Session.game
	var log: Array = []
	var handler := _count_signal_emissions(Events.owners_changed, log)
	var target: Array[Vector2i] = []
	var from_id := 0
	for i: int in game.map.hex_count():
		if game.map.land[i] != 0 and int(game.state.owner[i]) != 0:
			from_id = int(game.state.owner[i])
			target.append(game.map.hex_of(i))
			break
	var to_id := 1 if from_id != 1 else 2
	assert_eq(Territory.transfer(game, target, to_id), 1)
	assert_eq(log.size(), 0, "nothing is emitted before drain")
	Session.drain()
	Session.drain()
	Events.owners_changed.disconnect(handler)
	assert_eq(log.size(), 1, "owners_changed once")
	assert_eq(log[0], target)
	assert_true(game.events.is_empty())


func test_drain_with_no_game_is_harmless() -> void:
	Session.game = null
	Session.drain()
	assert_null(Session.game)


func test_reseed_keeps_scenario_and_player_and_adds_one_to_the_seed() -> void:
	Session.new_scenario(SCENARIO, 10, &"GEN")
	Session.reseed()
	assert_eq(Session.game.seed_value, 11)
	assert_eq(Session.game.scenario.id, SCENARIO)
	assert_eq(Session.player_tag(), &"GEN")
	Session.new_game(MapScene.MAP_ID, 4)
	Session.reseed()
	assert_eq(Session.game.seed_value, 5)
	assert_false(Session.game.has_countries(), "a map-only game stays map-only")


func test_two_autoloads_only() -> void:
	var autoloads: Array[String] = []
	for prop: Dictionary in ProjectSettings.get_property_list():
		if str(prop["name"]).begins_with("autoload/"):
			autoloads.append(str(prop["name"]))
	assert_eq(autoloads.size(), 2, "Session and Events only: %s" % [autoloads])


func _record(sig: Signal, log: Array, label: String) -> Callable:
	var handler := func(a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void:
		log.append([label, a])
	sig.connect(handler)
	return handler


func test_end_season_refused_before_the_pick_changes_nothing() -> void:
	Session.new_scenario(SCENARIO, 5)
	var turn := Session.game.turn
	var log: Array = []
	var handler := _record(Events.season_ended, log, "ended")
	assert_false(bool(Session.end_season_check()["ok"]))
	var verdict := Session.end_season()
	Events.season_ended.disconnect(handler)
	assert_false(bool(verdict["ok"]))
	assert_string_contains(str(verdict["reason"]), "choose your country")
	assert_eq(Session.game.turn, turn)
	assert_true(Session.game.action_log.is_empty())
	assert_eq(Session.unsaved_actions, 0)
	assert_true(log.is_empty())
	Session.game = null
	assert_eq(str(Session.end_season()["reason"]), "no game")
	assert_eq(str(Session.end_season_check()["reason"]), "no game")


func test_end_season_runs_phases_drains_and_emits_season_ended_once_last() -> void:
	Session.new_scenario(SCENARIO, 5, &"GEN")
	var game := Session.game
	var ended_turn := game.turn
	var version := game.version
	var unsaved := Session.unsaved_actions
	var log: Array = []
	var h1 := _record(Events.hex_changed, log, "hex")
	var h2 := _record(Events.season_ended, log, "ended")
	game.emit({"kind": "hex_changed", "hex": Vector2i(1, 1)})
	var verdict := Session.end_season()
	Events.hex_changed.disconnect(h1)
	Events.season_ended.disconnect(h2)
	assert_true(bool(verdict["ok"]))
	assert_eq(log, [["hex", Vector2i(1, 1)], ["ended", ended_turn]], "the queue drains, season_ended once and last")
	assert_true(game.events.is_empty())
	assert_eq(game.turn, ended_turn + 1, "the calendar phase ran")
	assert_eq(game.version, version + 1)
	assert_eq(game.action_log.back()["action"], "end_season")
	assert_eq(Session.unsaved_actions, unsaved + 1)
	assert_eq(Session.last_phase_ms.keys(), ["works", "stats", "calendar"])
	for phase: String in Session.last_phase_ms:
		assert_true(float(Session.last_phase_ms[phase]) >= 0.0)


func test_drain_sends_the_work_signals_and_chronicles_notable_events() -> void:
	Session.new_scenario(SCENARIO, 5, &"GEN")
	var game := Session.game
	var log: Array = []
	var handlers: Array[Callable] = [
		_record(Events.work_started, log, "started"),
		_record(Events.work_finished, log, "finished"),
		_record(Events.work_cancelled, log, "cancelled"),
		_record(Events.chronicled, log, "chron"),
	]
	var work := {"id": 1}
	game.emit({"kind": "work_started", "tag": &"GEN", "hex": Vector2i(2, 3), "work": work})
	game.emit({"kind": "work_finished", "tag": &"GEN", "hex": Vector2i(2, 3), "work": work})
	game.emit({"kind": "work_cancelled", "tag": &"GEN", "hex": Vector2i(2, 3), "work": work, "why": &"order"})
	game.emit({"kind": "hex_changed", "hex": Vector2i(2, 3)})
	Session.drain()
	Events.work_started.disconnect(handlers[0])
	Events.work_finished.disconnect(handlers[1])
	Events.work_cancelled.disconnect(handlers[2])
	Events.chronicled.disconnect(handlers[3])
	var labels: Array = []
	for item: Array in log:
		labels.append(item[0])
	assert_eq(labels, ["started", "chron", "finished", "chron", "cancelled", "chron"], "hex_changed is not chronicled")
	assert_eq(log[0][1], &"GEN")
	var entry := log[1][1] as Dictionary
	assert_eq(entry["kind"], "work_started")
	assert_true(entry["tag"] is String, "the entry is plain")
	assert_true(game.events.is_empty())


func test_dev_transfer_logs_drains_and_refuses_an_unknown_tag() -> void:
	Session.new_scenario(SCENARIO, 5)
	var game := Session.game
	var target: Array[Vector2i] = []
	for i: int in game.map.hex_count():
		if game.map.land[i] != 0 and int(game.state.owner[i]) != game.scenario.id_of(&"VEN"):
			target.append(game.map.hex_of(i))
			break
	var log: Array = []
	var handler := _record(Events.owners_changed, log, "owners")
	assert_eq(Session.dev_transfer(target, &"NOPE"), 0)
	assert_eq(Session.dev_transfer(target, &"VEN"), 1)
	Events.owners_changed.disconnect(handler)
	assert_eq(log.size(), 1)
	assert_true(game.events.is_empty())
	assert_eq(game.action_log.back()["action"], "dev_transfer")
	assert_eq(Session.dev_transfer(target, &""), 1, "an empty tag frees the land")
	Session.game = null
	assert_eq(Session.dev_transfer(target, &"VEN"), 0)


func test_play_seconds_counts_while_a_game_runs_and_resets_on_a_new_game() -> void:
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	Session.play_seconds = 0.0
	Session._process(0.5)
	assert_almost_eq(Session.play_seconds, 0.5, 0.0001)
	Session.current_slot = "3"
	Session.last_phase_ms = {"works": 1.0}
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	assert_eq(Session.play_seconds, 0.0)
	assert_eq(Session.current_slot, "")
	assert_true(Session.last_phase_ms.is_empty())
	Session.game = null
	Session._process(1.0)
	assert_eq(Session.play_seconds, 0.0, "no game, no count")
