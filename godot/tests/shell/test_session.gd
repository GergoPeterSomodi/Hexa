## GUT tests for Session lifecycle (unsaved_actions, start_game/new_game reset, end_game -> Events.game_ended)
## (docs/architecture/ui-and-controls-spec.md section 3.6; ui-and-controls-plan.md U8).
extends GutTest

var _prev_game: Game = null
var _prev_unsaved: int = 0
var _prev_defs: GameDefs = null
var _prev_origin: Dictionary = {}
var _prev_dir: String = ""
var _prev_json: bool = false
var _dir: String = "user://test_saves_session"
var _prev_ai: bool = true



func before_each() -> void:
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	_prev_defs = Session._defs
	_prev_origin = Session._origin
	_prev_dir = Session.save_dir
	_prev_json = Session.save_json
	Session.save_dir = _dir
	_prev_ai = Session.ai_enabled
	Session.ai_enabled = false  # M3 to M7 pinned a passive world (M8 D47); the M8 cases turn it on
	_wipe()


func after_each() -> void:
	Session.ai_enabled = _prev_ai
	Session._passive = []
	Session._in_season = false
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	Session._defs = _prev_defs
	Session._origin = _prev_origin
	Session.save_dir = _prev_dir
	Session.save_json = _prev_json
	_wipe()
	DirAccess.remove_absolute(_dir)


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
	assert_eq(game.action_log[game.action_log.size() - 2]["action"], "end_season")
	assert_eq(Session.unsaved_actions, unsaved + 1)
	assert_eq(Session.last_phase_ms.keys(), ["ai_orders", "movement", "battles", "supply", "sieges", "war", "production", "income", "works", "people", "stats", "calendar", "ready_units", "vision"])
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


func _wipe() -> void:
	if not DirAccess.dir_exists_absolute(_dir):
		return
	for file: String in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(file))


func _thumb() -> Image:
	return Image.create_empty(192, 108, false, Image.FORMAT_RGBA8)


func _read_bytes(slot: String) -> PackedByteArray:
	var f := FileAccess.open(Session.save_dir.path_join(slot + ".sav"), FileAccess.READ)
	var bytes := f.get_buffer(f.get_length())
	f.close()
	return bytes


func _write_bytes(slot: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(Session.save_dir.path_join(slot + ".sav"), FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _damage(slot: String) -> void:
	var bytes := _read_bytes(slot)
	bytes[bytes.size() - 1] = bytes[bytes.size() - 1] ^ 0xFF
	_write_bytes(slot, bytes)


## Changes one value of a save's header line as text (JSON.stringify would write ints as floats, which a header refuses).
func _rewrite_header(slot: String, key: String, value: Variant) -> void:
	var bytes := _read_bytes(slot)
	var end := bytes.find(10)
	var line := bytes.slice(0, end).get_string_from_utf8()
	var json := JSON.new()
	json.parse(line)
	var old: Variant = (json.data as Dictionary)[key]
	var shown := str(int(old)) if old is float else JSON.stringify(old)
	var from := "\"%s\":%s" % [key, shown]
	assert_true(line.contains(from), "the header has " + from)
	var out := (line.replace(from, "\"%s\":%s" % [key, JSON.stringify(value)]) + "
").to_utf8_buffer()
	out.append_array(bytes.slice(end + 1))
	_write_bytes(slot, out)


func test_save_then_load_keeps_the_digest_clock_slot_and_ui() -> void:
	Session.new_scenario(SCENARIO, 5, &"GEN")
	Session.game.defs = EconomyFixture.defs()  # calm weather: a save carries the weather only from N5 on
	Session.end_season()
	var digest := Session.game.digest()
	Session.play_seconds = 125.0
	assert_gt(Session.unsaved_actions, 0)
	var ui := {"map_mode": "owner", "camera": {"zoom": 2.0}}
	assert_eq(Session.save_game("3", _thumb(), ui, "My game"), "")
	assert_eq(Session.unsaved_actions, 0, "saved")
	assert_eq(Session.current_slot, "3")
	assert_true(FileAccess.file_exists(_dir.path_join("3.png")), "thumbnail written")
	Session.end_season()
	assert_eq(Session.load_game("3"), "")
	assert_eq(Session.game.digest(), digest)
	assert_eq(Session.play_seconds, 125.0)
	assert_eq(Session.current_slot, "3")
	assert_eq(Session.unsaved_actions, 0)
	assert_eq(Session.loaded_ui(), ui)
	Session.new_game(MapScene.MAP_ID, 1)
	assert_eq(Session.loaded_ui(), {}, "a new game clears loaded_ui")


func test_save_refusals_and_no_thumbnail_removes_the_old_picture() -> void:
	Session.game = null
	assert_ne(Session.save_game("1"), "", "no game")
	Session.new_game(MapScene.MAP_ID, 1)
	assert_ne(Session.save_game("nope"), "", "an unknown slot")
	assert_eq(Session.save_game("1", _thumb()), "")
	assert_true(FileAccess.file_exists(_dir.path_join("1.png")))
	assert_eq(Session.save_game("1"), "")
	assert_false(FileAccess.file_exists(_dir.path_join("1.png")))


func test_autosave_fills_empty_slots_then_replaces_the_oldest() -> void:
	Session.new_game(MapScene.MAP_ID, 1)
	for i: int in 3:
		assert_eq(Session.autosave_game(null, {}), "")
		assert_eq(Session.current_slot, "auto%d" % (i + 1))
	assert_eq(Session.list_saves()[0]["state"], &"ok")


func test_list_saves_order_states_and_newest_save() -> void:
	Session.new_game(MapScene.MAP_ID, 1)
	var rows := Session.list_saves()
	assert_eq(rows.size(), 12)
	assert_eq(rows[0]["slot"], "auto1")
	assert_eq(rows[3]["slot"], "quick")
	for row: Dictionary in rows:
		assert_eq(row["state"], &"empty")
	assert_true(Session.newest_save().is_empty())
	Session.save_game("2", _thumb())
	rows = Session.list_saves()
	assert_eq(rows[5]["slot"], "2")
	assert_eq(rows[5]["state"], &"ok")
	assert_ne(rows[5]["thumbnail"], "")
	assert_eq(Session.newest_save()["slot"], "2")
	Session.save_game("quick")
	assert_eq(Session.list_saves()[3]["thumbnail"], "")
	assert_false(Session.newest_save().is_empty())


func test_list_saves_maps_a_foreign_map_or_scenario_and_load_refuses_them() -> void:
	Session.new_scenario(SCENARIO, 1)
	assert_eq(Session.save_game("1"), "")
	assert_eq(Session.save_game("2"), "")
	assert_eq(Session.save_game("3"), "")
	_rewrite_header("2", "map_digest", "0000")
	_rewrite_header("3", "scenario_digest", "0000")
	var rows := Session.list_saves()
	assert_eq(rows[4]["state"], &"ok")
	assert_eq(rows[5]["state"], &"other_map")
	assert_eq(rows[6]["state"], &"other_build")
	var game_before := Session.game
	assert_eq(Session.load_game("2"), Snapshot.PROBLEM_OTHER_MAP)
	assert_eq(Session.load_game("3"), Snapshot.PROBLEM_OTHER_BUILD)
	assert_same(Session.game, game_before, "nothing started")
	assert_eq(Session.newest_save()["slot"], "1", "only an ok save counts")


func test_load_refuses_broken_and_damaged_saves_and_starts_nothing() -> void:
	Session.new_game(MapScene.MAP_ID, 1)
	var game_before := Session.game
	assert_eq(Session.load_game("1"), "Empty slot")
	Session.save_game("1")
	_damage("1")
	assert_eq(Session.load_game("1"), Snapshot.PROBLEM_UNREADABLE, "a flipped body byte")
	Session.save_game("2")
	_rewrite_header("2", "digest", "ffff")
	assert_eq(Session.load_game("2"), "The save is damaged", "a header digest that differs")
	assert_same(Session.game, game_before, "nothing started on any problem")
	assert_eq(Session.list_saves()[4]["state"], &"ok", "list_saves reads headers only; the body is checked at load")


func test_load_of_a_newer_format_returns_its_problem() -> void:
	Session.new_game(MapScene.MAP_ID, 1)
	Session.save_game("1")
	_rewrite_header("1", "format", SaveFile.FORMAT + 1)
	assert_eq(Session.load_game("1"), Snapshot.PROBLEM_NEWER)
	assert_eq(Session.list_saves()[4]["state"], &"newer")
	_rewrite_header("1", "format", 7)  # MV2 (R55, D22): the fog build's format is an older test build
	assert_eq(Session.load_game("1"), Snapshot.PROBLEM_OLDER)
	assert_eq(Session.list_saves()[4]["state"], &"older")


func test_load_refuses_a_name_that_is_not_a_slot() -> void:
	Session.new_game(MapScene.MAP_ID, 1)
	Session.save_game("1")
	var outside := "user://test_outside"
	DirAccess.copy_absolute(_dir.path_join("1.sav"), outside + ".sav")
	var game_before := Session.game
	for bad: String in ["../test_outside", "x", "", "1/../1"]:
		assert_ne(Session.load_game(bad), "", "refused: " + bad)
	assert_eq(Session.load_game("../test_outside"), "no slot '../test_outside'")
	assert_same(Session.game, game_before)
	assert_eq(Session.current_slot, "1")
	assert_eq(SaveFile.path_of("../x", _dir), "")
	assert_eq(SaveFile.read("../x", _dir)["header"], {})
	assert_eq(SaveFile.read_header("../x", _dir)["state"], &"empty")
	assert_false(SaveFile.remove("../x", _dir))
	assert_ne(SaveFile.write(game_before, "../x", {}, {}, _dir), "")
	DirAccess.remove_absolute(outside + ".sav")


func _on_started(seen: Array) -> void:
	seen.append({"slot": Session.current_slot, "seconds": Session.play_seconds, "ui": Session.loaded_ui()})


func test_game_started_listeners_see_the_loaded_slot_clock_and_ui() -> void:
	Session.new_game(MapScene.MAP_ID, 1)
	Session.play_seconds = 61.0
	Session.save_game("2", null, {"camera": 3})
	var seen: Array = []
	var handler := _on_started.bind(seen)
	Events.game_started.connect(handler)
	var problem := Session.load_game("2")
	Events.game_started.disconnect(handler)
	assert_eq(problem, "")
	assert_eq(seen, [{"slot": "2", "seconds": 61.0, "ui": {"camera": 3}}])


func test_digest_caches_follow_the_instance_and_scenario() -> void:
	Session.new_scenario(SCENARIO, 1)
	var first := Session._map_digest(Session.game.map)
	var copy := Session.game.map.duplicate() as MapData
	assert_eq(Session._map_digest(copy), first, "a copy has the same digest")
	assert_true(Session._map_digests.has(copy.get_instance_id()), "keyed by instance")
	Session.save_game("1")
	Session.list_saves()
	assert_false(Session._scenario_digests.is_empty(), "scenario digests cached")
	var again := Session._scenario_digests.duplicate()
	Session.list_saves()
	assert_eq(Session._scenario_digests, again)


func test_delete_save_removes_every_file_and_save_json_writes_the_dev_copy() -> void:
	Session.new_game(MapScene.MAP_ID, 1)
	Session.save_json = true
	Session.save_game("4", _thumb())
	assert_true(FileAccess.file_exists(_dir.path_join("4.body.json")))
	assert_true(Session.delete_save("4"))
	assert_eq(DirAccess.get_files_at(_dir).size(), 0)
	assert_eq(Session.current_slot, "", "the deleted slot is no longer current")
	assert_false(Session.delete_save("../x"))


func test_dev_money_and_dev_goods_move_the_stores_log_and_refuse_bad_asks() -> void:
	Session.game = null  # an earlier test file may have left a game in the autoload
	assert_false(Session.dev_money(&"GEN", 5), "no game")
	Session.new_scenario(SCENARIO, 5, &"GEN")
	var game := Session.game
	var c := Countries.by_tag(game, &"GEN")
	var purse := c.treasury
	assert_true(Session.dev_money(&"GEN", 100))
	assert_eq(c.treasury, purse + 100)
	assert_eq(game.action_log.back()["action"], "dev_money")
	assert_false(Session.dev_money(&"NOPE", 100), "an unknown tag")
	var salt := game.defs.good_id(&"salt")
	var held := c.stock[salt]
	assert_true(Session.dev_goods(&"GEN", salt, 3))
	assert_eq(c.stock[salt], held + 3)
	assert_eq(game.action_log.back()["action"], "dev_goods")
	assert_false(Session.dev_goods(&"GEN", 999, 3), "an unknown good")
	assert_true(game.events.is_empty())
	Session.end_game()
	assert_false(Session.dev_goods(&"GEN", salt, 1), "no game")


func test_drain_sends_goods_short_and_tax_set_and_chronicles_them() -> void:
	Session.new_scenario(SCENARIO, 5, &"GEN")
	var game := Session.game
	var log: Array = []
	var on_short := func(tag: StringName, good: StringName) -> void: log.append(["short", tag, good])
	var on_tax := func(tag: StringName, level: int) -> void: log.append(["tax", tag, level])
	var on_chron := func(entry: Dictionary) -> void: log.append(["chron", entry["kind"]])
	Events.goods_short.connect(on_short)
	Events.tax_set.connect(on_tax)
	Events.chronicled.connect(on_chron)
	game.emit({"kind": "goods_short", "tag": &"GEN", "good": &"salt", "need": 1, "taken": 0, "witnesses": [&"GEN"]})
	var verdict := Session.act("set_tax", {"level": 2})
	Events.goods_short.disconnect(on_short)
	Events.tax_set.disconnect(on_tax)
	Events.chronicled.disconnect(on_chron)
	assert_true(bool(verdict["ok"]))
	assert_eq(log, [["short", &"GEN", &"salt"], ["chron", "goods_short"], ["tax", &"GEN", 2], ["chron", "tax_set"]])
	assert_true(game.events.is_empty())
	assert_eq(game.chronicle.entries.back()["kind"], "tax_set")


func test_dev_people_logs_and_drains() -> void:
	Session.game = null
	assert_false(Session.dev_people(Vector2i(6, 13), 5), "no game")
	Session.new_scenario(SCENARIO, 5, &"GEN")
	var game := Session.game
	var hex := Vector2i(6, 13)
	var i := game.map.index_of(hex)
	assert_eq(game.state.owner[i], game.scenario.id_of(&"GEN"), "Savona is Genoa's")
	assert_true(Session.dev_people(hex, 3990))
	assert_eq(game.state.people[i], 3990)
	assert_eq(game.action_log.back()["action"], "dev_people")
	assert_eq(game.action_log.back()["args"], {"hex": hex, "people": 3990})
	assert_true(game.events.is_empty(), "drained")
	assert_false(Session.dev_people(hex, -1), "below 0")
	var sea := Vector2i.ZERO
	for k: int in game.map.hex_count():
		if game.map.land[k] == 0:
			sea = game.map.hex_of(k)
			break
	assert_false(Session.dev_people(sea, 10), "sea")
	assert_eq(game.state.people[i], 3990, "a refusal changes nothing")
	Session.end_game()
	assert_false(Session.dev_people(hex, 5), "no game")


func test_drain_sends_town_grew_and_district_declined_before_chronicled() -> void:
	Session.new_scenario(SCENARIO, 5, &"GEN")
	var game := Session.game
	var log: Array = []
	var on_grew := func(tag: StringName, hex: Vector2i, level: int) -> void: log.append(["grew", tag, hex, level])
	var on_fell := func(tag: StringName, hex: Vector2i, level: int, why: StringName) -> void:
		log.append(["fell", tag, hex, level, why])
	var on_chron := func(entry: Dictionary) -> void: log.append(["chron", entry["kind"]])
	Events.town_grew.connect(on_grew)
	Events.district_declined.connect(on_fell)
	Events.chronicled.connect(on_chron)
	var hex := Vector2i(6, 13)
	game.emit({"kind": "town_grew", "tag": &"GEN", "hex": hex, "level": 3, "from": 2, "people": 4000})
	game.emit({"kind": "district_declined", "tag": &"GEN", "hex": hex, "family": 1, "level": 2, "from": 3, "people": 1900,
		"why": &"hunger"})
	Session.drain()
	Events.town_grew.disconnect(on_grew)
	Events.district_declined.disconnect(on_fell)
	Events.chronicled.disconnect(on_chron)
	assert_eq(log, [["grew", &"GEN", hex, 3], ["chron", "town_grew"], ["fell", &"GEN", hex, 2, &"hunger"],
		["chron", "district_declined"]])
	assert_true(game.events.is_empty())
	assert_eq(game.chronicle.entries.back()["why"], "hunger")


func test_drain_sends_the_army_signals_and_chronicles_the_notable_ones() -> void:
	Session.new_scenario(SCENARIO, 5, &"GEN")
	var game := Session.game
	var hex := Vector2i(7, 12)
	var hex2 := Vector2i(6, 13)
	var log: Array = []
	var on_raised := func(tag: StringName, at: Vector2i, army: int) -> void: log.append(["raised", tag, at, army])
	var on_disbanded := func(tag: StringName, at: Vector2i, army: int) -> void: log.append(["disbanded", tag, at, army])
	var on_changed := func(tag: StringName, army: int) -> void: log.append(["changed", tag, army])
	var on_moved := func(tag: StringName, army: int, path: Array[Vector2i], seen: PackedByteArray,
			ticks: PackedInt32Array) -> void:
		log.append(["moved", tag, army, path, seen, ticks])
	var on_halted := func(tag: StringName, army: int, why: StringName) -> void: log.append(["halted", tag, army, why])
	var on_starved := func(tag: StringName, army: int, lost: int) -> void: log.append(["starved", tag, army, lost])
	var on_lost := func(tag: StringName, army: int, unit: int) -> void: log.append(["lost", tag, army, unit])
	Events.army_raised.connect(on_raised)
	Events.army_disbanded.connect(on_disbanded)
	Events.army_changed.connect(on_changed)
	Events.unit_moved.connect(on_moved)
	Events.march_halted.connect(on_halted)
	Events.army_starved.connect(on_starved)
	Events.unit_lost.connect(on_lost)
	var before := game.chronicle.entries.size()
	game.emit({"kind": "army_raised", "tag": &"GEN", "hex": hex, "army": 1, "units": [1], "kind_id": 0, "count": 1,
		"men": 1000, "ducats": 0, "goods": {}, "witnesses": [&"GEN"]})
	game.emit({"kind": "army_changed", "tag": &"GEN", "hex": hex, "army": 1, "gone": false})
	game.emit({"kind": "unit_moved", "tag": &"GEN", "army": 1, "path": [hex, hex2], "ticks": PackedInt32Array([1]),
		"seen": PackedByteArray([1, 1]), "witnesses": [&"GEN"], "arrived": true})
	game.emit({"kind": "march_halted", "tag": &"GEN", "army": 1, "hex": hex2, "why": "winter", "reason": "Mont Cenis",
		"waits": true, "witnesses": [&"GEN"]})
	game.emit({"kind": "army_starved", "tag": &"GEN", "army": 1, "hex": hex, "lost": 10, "men": 990,
		"why": "out_of_supply", "witnesses": [&"GEN"]})
	game.emit({"kind": "unit_lost", "tag": &"GEN", "army": 1, "unit": 1, "kind_id": 0, "hex": hex, "why": "starved",
		"army_left": 0, "witnesses": [&"GEN"]})
	game.emit({"kind": "army_disbanded", "tag": &"GEN", "hex": hex, "army": 2, "units": [2], "men": 500, "refund": 0,
		"witnesses": [&"GEN"]})
	assert_eq(game.chronicle.entries.size() - before, 5, "army_changed and unit_moved are not notable")
	Session.drain()
	Events.army_raised.disconnect(on_raised)
	Events.army_disbanded.disconnect(on_disbanded)
	Events.army_changed.disconnect(on_changed)
	Events.unit_moved.disconnect(on_moved)
	Events.march_halted.disconnect(on_halted)
	Events.army_starved.disconnect(on_starved)
	Events.unit_lost.disconnect(on_lost)
	assert_eq(log, [["raised", &"GEN", hex, 1], ["changed", &"GEN", 1],
		["moved", &"GEN", 1, [hex, hex2], PackedByteArray([1, 1]), PackedInt32Array([1])],
		["halted", &"GEN", 1, &"winter"], ["starved", &"GEN", 1, 10], ["lost", &"GEN", 1, 1],
		["disbanded", &"GEN", hex, 2]])
	assert_true(game.events.is_empty(), "drained")


func test_drain_sends_the_war_signals_in_order_and_chronicles_the_notable_ones() -> void:
	# M7 (m7-build-spec.md 5.5, 4.14): each war event reaches its typed signal in queue order; the notable ones then chronicle.
	Session.new_scenario(SCENARIO, 5, &"GEN")
	var game := Session.game
	var hex := Vector2i(7, 12)
	var log: Array = []
	var on_war := func(tag: StringName, target: StringName) -> void: log.append(["war", tag, target])
	var on_peace := func(tag: StringName, target: StringName, terms: StringName) -> void:
		log.append(["peace", tag, target, terms])
	var on_started := func(at: Vector2i, attacker: StringName, defender: StringName) -> void:
		log.append(["started", at, attacker, defender])
	var on_joined := func(at: Vector2i, tag: StringName) -> void: log.append(["joined", at, tag])
	var on_fought := func(at: Vector2i) -> void: log.append(["fought", at])
	var on_ended := func(at: Vector2i, record: int, winner: StringName) -> void: log.append(["ended", at, record, winner])
	var on_siege := func(at: Vector2i, tag: StringName) -> void: log.append(["siege", at, tag])
	var on_progress := func(at: Vector2i, tag: StringName, progress: int, need: int) -> void:
		log.append(["progress", at, tag, progress, need])
	var on_lifted := func(at: Vector2i, tag: StringName, why: StringName) -> void: log.append(["lifted", at, tag, why])
	var on_captured := func(at: Vector2i, tag: StringName, by: StringName) -> void: log.append(["captured", at, tag, by])
	var on_changed := func(hexes: Array[Vector2i]) -> void: log.append(["controllers", hexes])
	var on_chron := func(entry: Dictionary) -> void: log.append(["chron", entry["kind"]])
	var pairs: Array = [[Events.war_declared, on_war], [Events.peace_made, on_peace], [Events.battle_started, on_started],
		[Events.battle_joined, on_joined], [Events.battle_fought, on_fought], [Events.battle_ended, on_ended],
		[Events.siege_started, on_siege], [Events.siege_progress, on_progress], [Events.siege_lifted, on_lifted],
		[Events.district_captured, on_captured], [Events.controllers_changed, on_changed], [Events.chronicled, on_chron]]
	for pair: Array in pairs:
		(pair[0] as Signal).connect(pair[1] as Callable)
	game.emit({"kind": "war_declared", "tag": &"GEN", "target": &"SAV", "war": 1, "witnesses": [&"GEN", &"SAV"]})
	game.emit({"kind": "battle_started", "tag": &"GEN", "hex": hex, "others": [&"SAV"], "defender": &"SAV", "tick": 1,
		"name": "Alessandria", "year": 1480, "assault": false, "witnesses": [&"GEN"]})
	game.emit({"kind": "battle_joined", "tag": &"SAV", "hex": hex, "army": 2, "side": "defender", "men": 300,
		"witnesses": [&"SAV"]})
	game.emit({"kind": "battle_fought", "tag": &"GEN", "hex": hex, "others": [&"SAV"], "days": 2,
		"killed": {"GEN": 1, "SAV": 2}, "wounded": {}, "morale": {}, "witnesses": [&"GEN"]})
	game.emit({"kind": "battle_ended", "tag": &"GEN", "hex": hex, "others": [&"SAV"], "attacker": &"GEN",
		"defender": &"SAV", "winner": &"GEN", "loser": &"SAV", "how": "broke", "cause": "morale", "days": 2,
		"name": "Alessandria", "year": 1480, "killed": {"GEN": 1, "SAV": 2}, "wounded": {},
		"retreat": Vector2i(-1, -1), "record": 5, "stormed": false, "witnesses": [&"GEN"]})
	game.emit({"kind": "siege_progress", "tag": &"GEN", "hex": hex, "others": [&"SAV"], "progress": 2, "need": 5,
		"rate": 1, "hunger": 0, "seasons": 2, "name": "Pavia", "witnesses": [&"GEN"]})
	game.emit({"kind": "controllers_changed", "hexes": [hex], "tag": &"GEN", "others": [&"SAV"]})
	game.emit({"kind": "district_captured", "tag": &"GEN", "hex": hex, "others": [&"SAV"], "owner": &"SAV",
		"by": "walk", "witnesses": [&"GEN"]})
	game.emit({"kind": "siege_lifted", "tag": &"GEN", "hex": hex, "others": [&"SAV"], "why": "peace", "name": "Pavia",
		"progress": 2, "need": 5, "seasons": 2, "witnesses": [&"GEN"]})
	game.emit({"kind": "peace_made", "tag": &"GEN", "target": &"SAV", "war": 1, "terms": "white", "moved": [],
		"released": [], "witnesses": [&"GEN"]})
	Session.drain()
	for pair: Array in pairs:
		(pair[0] as Signal).disconnect(pair[1] as Callable)
	assert_eq(log, [
		["war", &"GEN", &"SAV"], ["chron", "war_declared"],
		["started", hex, &"GEN", &"SAV"],
		["joined", hex, &"SAV"],
		["fought", hex],
		["ended", hex, 5, &"GEN"], ["chron", "battle_ended"],
		["progress", hex, &"GEN", 2, 5],
		["controllers", [hex]],
		["captured", hex, &"GEN", &"walk"], ["chron", "district_captured"],
		["lifted", hex, &"GEN", &"peace"], ["chron", "siege_lifted"],
		["peace", &"GEN", &"SAV", &"white"], ["chron", "peace_made"]])
	assert_true(game.events.is_empty(), "drained")
