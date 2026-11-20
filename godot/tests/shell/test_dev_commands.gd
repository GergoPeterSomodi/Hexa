## GUT tests for the developer console's command table (docs/architecture/m3-build-spec.md section 6.13): every command
## parses and runs, each bad line gives its problem (P) and changes nothing.
extends GutTest

const SCENARIO := "north_italy_1480"

var _prev_game: Game = null
var _ctx: ShellContext = null
var _sent: Array = []


func before_each() -> void:
	_prev_game = Session.game
	_ctx = ShellContext.new()
	_sent = []
	_ctx.app_requested.connect(func(what: StringName, args: Dictionary) -> void: _sent.append([what, args]))
	assert_eq(Session.new_scenario(SCENARIO, 5, &"GEN"), "")


func after_each() -> void:
	Session.game = _prev_game


func _game() -> Game:
	return Session.game


func _owned_hex(tag: StringName) -> Vector2i:
	var id := _game().scenario.id_of(tag)
	for i: int in _game().map.hex_count():
		if int(_game().state.owner[i]) == id and _game().map.land[i] != 0:
			return _game().map.hex_of(i)
	return Vector2i(-1, -1)


func _buildable(family: int) -> Vector2i:
	for i: int in _game().map.hex_count():
		var hex := _game().map.hex_of(i)
		if int(_game().state.owner[i]) == _game().scenario.id_of(&"GEN") and \
				bool(Session.check("build", {"hex": hex, "family": family})["ok"]):
			return hex
	return Vector2i(-1, -1)


func _problem(line: String) -> String:
	var parsed := DevCommands.parse(line, _game())
	assert_eq(parsed["kind"], &"", "'%s' is no command" % line)
	return str(parsed["problem"])


func test_every_command_parses_to_its_kind() -> void:
	var cases := {
		"build 9 9 wheat": &"act", "upgrade 9 9": &"act", "clear 9 9": &"act", "cancel 9 9": &"act",
		"choose GEN": &"act", "end": &"end", "end 4": &"end", "goto 15 8": &"goto", "look spring": &"look",
		"look calendar": &"look", "give 9 9 GEN": &"give", "give 9 9 10 9 none": &"give", "digest": &"digest",
		"seed": &"seed", "help": &"help",
	}
	for line: String in cases:
		var parsed := DevCommands.parse(line, _game())
		assert_eq(parsed["problem"], "", line)
		assert_eq(parsed["kind"], cases[line], line)


func test_parse_fills_actions_and_arguments() -> void:
	var build := DevCommands.parse("build 9 9 wheat", _game())
	assert_eq(build["action"], "build")
	assert_eq(build["args"], {"hex": Vector2i(9, 9), "family": ImproveRules.WHEAT})
	assert_eq(DevCommands.parse("build 9 9 7", _game())["args"]["family"], 7, "a family by its id")
	assert_eq(DevCommands.parse("BUILD 9 9 Vineyard", _game())["args"]["family"], ImproveRules.VINEYARD)
	assert_eq(DevCommands.parse("upgrade 9 9", _game())["action"], "upgrade")
	assert_eq(DevCommands.parse("clear 9 9", _game())["action"], "clear")
	assert_eq(DevCommands.parse("cancel 9 9", _game())["action"], "cancel_work")
	assert_eq(DevCommands.parse("choose gen", _game())["args"], {"tag": &"GEN"})
	assert_eq(DevCommands.parse("end", _game())["args"], {"count": 1})
	assert_eq(DevCommands.parse("end 4", _game())["args"], {"count": 4})
	assert_eq(DevCommands.parse("end 40", _game())["args"], {"count": 40})
	assert_eq(DevCommands.parse("goto 15 8", _game())["args"], {"hex": Vector2i(15, 8), "select": true})
	assert_eq(DevCommands.parse("look winter", _game())["args"], {"season": 3})
	assert_eq(DevCommands.parse("look calendar", _game())["args"], {"season": -1})
	var give := DevCommands.parse("give 9 9 10 9 GEN", _game())
	assert_eq(give["args"]["hexes"], [Vector2i(9, 9), Vector2i(10, 9)])
	assert_eq(give["args"]["tag"], &"GEN")
	assert_eq(DevCommands.parse("give 9 9 none", _game())["args"]["tag"], &"")


func test_planted_bad_lines_give_a_problem() -> void:
	assert_true(_problem("").contains("help"), "an empty line")
	assert_true(_problem("dance").contains("Unknown command"))
	assert_true(_problem("build 9 9 gizmo").contains("No family"), "an unknown family")
	assert_true(_problem("build 9 9 0").contains("No family"), "family 0 is none")
	assert_true(_problem("build 9 9 15").contains("No family"), "family past the last")
	assert_true(_problem("build 9 9").begins_with("Use: build"))
	assert_true(_problem("build x 9 wheat").contains("not a hex"), "a bad hex")
	assert_true(_problem("build 9999 9 wheat").contains("not on the map"), "off the map")
	assert_true(_problem("goto -1 -1").contains("not on the map"))
	assert_true(_problem("goto 5").begins_with("Use: goto"))
	assert_true(_problem("upgrade 9").begins_with("Use: upgrade"))
	assert_true(_problem("clear 9 9 9").begins_with("Use: clear"))
	assert_true(_problem("cancel 9999 9999").contains("not on the map"))
	assert_true(_problem("end 41").contains("1 to 40"), "end 41")
	assert_true(_problem("end 0").contains("1 to 40"), "end 0")
	assert_true(_problem("end -3").contains("1 to 40"))
	assert_true(_problem("end many").contains("not a number"))
	assert_true(_problem("end 1 2").begins_with("Use: end"))
	assert_true(_problem("choose").begins_with("Use: choose"))
	assert_true(_problem("choose ZZZ").contains("No country"), "an unknown tag")
	assert_true(_problem("look sometime").begins_with("Use: look"))
	assert_true(_problem("look").begins_with("Use: look"))
	assert_true(_problem("give 9 9").begins_with("Use: give"), "no tag")
	assert_true(_problem("give 9 9 10 GEN").begins_with("Use: give"), "a half hex")
	assert_true(_problem("give 9 9 ZZZ").contains("No country"), "give to an unknown tag")
	assert_true(_problem("give 9999 9 GEN").contains("not on the map"))
	assert_true(_problem("digest now").contains("no arguments"))


func test_huge_numbers_are_refused_not_truncated() -> void:
	var before := _game().digest()
	var logged := _game().action_log.size()
	for line: String in ["upgrade 4294967297 4294967296", "build 4294967297 4294967296 wheat", "clear 4294967297 0",
			"cancel 0 4294967296", "goto 4294967297 4294967296", "give 4294967297 4294967296 GEN",
			"give 1 1 4294967297 4294967296 none", "upgrade 1234567890 1"]:
		assert_true(_problem(line).contains("too large"), line)
		assert_true(DevCommands.run(line, _ctx).contains("too large"), line)
	assert_true(_problem("upgrade 999999999 1").contains("not on the map"), "nine digits are read, then fall off the map")
	assert_true(_problem("upgrade -4294967297 1").contains("too large"))
	assert_true(_problem("upgrade -1 -1").contains("not on the map"), "negative stays refused")
	assert_true(_problem("upgrade a 1").contains("not a hex"), "non-numeric stays refused")
	assert_eq(_game().digest(), before)
	assert_eq(_game().action_log.size(), logged)
	assert_true(_sent.is_empty())


func test_end_refuses_huge_numbers_with_a_problem() -> void:
	for word: String in ["99999999999999999999", "4294967297", "1234567890", "-99999999999999999999"]:
		assert_true(_problem("end " + word).contains("1 to 40"), word)
		assert_true(DevCommands.run("end " + word, _ctx).contains("1 to 40"), word)
	assert_true(_sent.is_empty())
	assert_eq(DevCommands.parse("end 000000040", _game())["args"], {"count": 40}, "leading zeros within nine digits")


func test_end_and_look_say_no_game_without_a_game() -> void:
	Session.game = null
	assert_eq(DevCommands.parse("end 4", null)["problem"], "There is no game.")
	assert_eq(DevCommands.parse("end", null)["problem"], "There is no game.")
	assert_eq(DevCommands.parse("look spring", null)["problem"], "There is no game.")
	assert_eq(DevCommands.run("end 2", _ctx), "There is no game.")
	assert_eq(DevCommands.run("look calendar", _ctx), "There is no game.")
	assert_true(_sent.is_empty())


func test_a_map_only_game_and_no_game_give_problems() -> void:
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	assert_true(_problem("choose GEN").contains("no countries"))
	assert_true(_problem("give 9 9 GEN").contains("no countries"))
	assert_eq(DevCommands.parse("give 9 9 none", _game())["problem"], "", "freeing land needs no country")
	Session.game = null
	assert_true(str(DevCommands.parse("goto 1 1", null)["problem"]).contains("no game"))
	assert_true(str(DevCommands.parse("digest", null)["problem"]).contains("no game"))
	assert_eq(DevCommands.parse("help", null)["problem"], "", "help needs no game")
	assert_true(DevCommands.run("seed", _ctx).contains("no game"))


func test_run_digest_seed_and_help() -> void:
	assert_eq(DevCommands.run("digest", _ctx), _game().digest().substr(0, 12))
	assert_eq(DevCommands.run("digest", _ctx).length(), 12)
	assert_eq(DevCommands.run("seed", _ctx), "5")
	var help := DevCommands.run("help", _ctx)
	for word: String in ["build", "upgrade", "clear", "cancel", "choose", "end", "goto", "look", "give", "digest", "seed"]:
		assert_true(help.contains(word), "help names " + word)
	assert_true(_sent.is_empty())


func test_run_end_goto_and_look_send_their_requests() -> void:
	assert_eq(DevCommands.run("end 4", _ctx), "Ending 4 seasons.")
	assert_eq(DevCommands.run("end", _ctx), "Ending 1 season.")
	assert_eq(DevCommands.run("goto 15 8", _ctx), "Going to 15 8.")
	DevCommands.run("look autumn", _ctx)
	DevCommands.run("look calendar", _ctx)
	assert_eq(_sent, [
		[&"end_seasons", {"count": 4}], [&"end_seasons", {"count": 1}],
		[&"look_at", {"hex": Vector2i(15, 8), "select": true}],
		[&"dev_look", {"season": 2}], [&"dev_look", {"season": -1}],
	])


func test_run_a_bad_line_sends_nothing_and_changes_nothing() -> void:
	var before := _game().digest()
	var logged := _game().action_log.size()
	for line: String in ["end 41", "goto 9999 1", "look never", "build 1 1 gizmo", "give 1 1 ZZZ", "nonsense"]:
		DevCommands.run(line, _ctx)
	assert_true(_sent.is_empty())
	assert_eq(_game().digest(), before)
	assert_eq(_game().action_log.size(), logged)


func test_run_build_upgrade_clear_cancel_go_through_session_act() -> void:
	var hex := _buildable(ImproveRules.GRAZING)
	assert_ne(hex, Vector2i(-1, -1), "Genoa has a hex where grazing can be built")
	var line := "build %d %d grazing" % [hex.x, hex.y]
	assert_eq(DevCommands.run(line, _ctx), "Done: %s." % line)
	assert_eq(_game().action_log.back()["action"], "build")
	assert_not_null(_game().state.work_at(hex))
	var again := DevCommands.run(line, _ctx)
	assert_true(again.begins_with("Refused: "), "a second work on the hex is refused with the rules' reason")
	var count := _game().action_log.size()
	assert_eq(DevCommands.run("cancel %d %d" % [hex.x, hex.y], _ctx), "Done: cancel %d %d." % [hex.x, hex.y])
	assert_eq(_game().action_log.back()["action"], "cancel_work")
	assert_null(_game().state.work_at(hex))
	assert_eq(_game().action_log.size(), count + 1)
	assert_true(DevCommands.run("upgrade %d %d" % [hex.x, hex.y], _ctx).begins_with("Refused: "), "nothing to upgrade")
	assert_true(DevCommands.run("clear %d %d" % [hex.x, hex.y], _ctx).begins_with("Refused: "), "nothing to clear")
	assert_true(DevCommands.run("cancel %d %d" % [hex.x, hex.y], _ctx).begins_with("Refused: "), "no work to cancel")


func test_run_choose_picks_a_country_once() -> void:
	Session.new_scenario(SCENARIO, 3)
	assert_eq(_game().player, &"")
	assert_eq(DevCommands.run("choose VEN", _ctx), "Done: choose VEN.")
	assert_eq(_game().player, &"VEN")
	assert_true(DevCommands.run("choose GEN", _ctx).begins_with("Refused: "), "a country is chosen already")
	assert_eq(_game().player, &"VEN")


func test_run_give_moves_land_logs_it_and_frees_it() -> void:
	var hex := _owned_hex(&"GEN")
	var other := &"VEN"
	assert_eq(DevCommands.run("give %d %d %s" % [hex.x, hex.y, other], _ctx), "1 hex given to VEN.")
	assert_eq(int(_game().state.owner[_game().map.index_of(hex)]), _game().scenario.id_of(other))
	assert_eq(_game().action_log.back()["action"], "dev_transfer")
	assert_eq(DevCommands.run("give %d %d none" % [hex.x, hex.y], _ctx), "1 hex given to no one.")
	assert_eq(int(_game().state.owner[_game().map.index_of(hex)]), 0)
	assert_eq(DevCommands.run("give %d %d none" % [hex.x, hex.y], _ctx), "0 hexes given to no one.", "no change")


func test_run_give_several_hexes_at_once() -> void:
	var first := _owned_hex(&"GEN")
	var second := Vector2i(-1, -1)
	for i: int in _game().map.hex_count():
		var h := _game().map.hex_of(i)
		if h != first and int(_game().state.owner[i]) == _game().scenario.id_of(&"GEN") and _game().map.land[i] != 0:
			second = h
			break
	var text := DevCommands.run("give %d %d %d %d VEN" % [first.x, first.y, second.x, second.y], _ctx)
	assert_eq(text, "2 hexes given to VEN.")
