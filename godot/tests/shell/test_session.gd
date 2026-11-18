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

	var cleared := Session.act("clear", {"hex": hex})
	assert_true(bool(cleared.get("ok", false)))
	assert_eq(Session.unsaved_actions, 2, "successful clear increments unsaved_actions")

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
