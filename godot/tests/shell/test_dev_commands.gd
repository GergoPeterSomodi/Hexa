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


# ----- M4's money, goods and tax (docs/architecture/m4-build-spec.md 6.11) ----------------------------------------------


func _treasury(tag: StringName) -> int:
	return Countries.by_tag(_game(), tag).treasury


func _stock(tag: StringName, key: StringName) -> int:
	return Countries.by_tag(_game(), tag).stock[_game().defs.good_id(key)]


func test_the_three_commands_parse_to_their_kinds_and_arguments() -> void:
	var money := DevCommands.parse("money 500", _game())
	assert_eq([money["kind"], money["problem"]], [&"money", ""])
	assert_eq(money["args"], {"tag": &"GEN", "amount": 500}, "the player is the default")
	assert_eq(DevCommands.parse("money -40 mlo", _game())["args"], {"tag": &"MLO", "amount": -40}, "a tag, in any case")
	var goods := DevCommands.parse("goods stone 40", _game())
	assert_eq(goods["kind"], &"goods")
	assert_eq(goods["args"], {"tag": &"GEN", "good": _game().defs.good_id(&"stone"), "amount": 40})
	assert_eq(DevCommands.parse("goods SALT 3 MLO", _game())["args"]["tag"], &"MLO")
	var tax := DevCommands.parse("tax HIGH", _game())
	assert_eq([tax["kind"], tax["action"], tax["args"]], [&"act", "set_tax", {"level": 2}])
	assert_eq(DevCommands.parse("tax low", _game())["args"], {"level": 0})
	assert_eq(DevCommands.parse("tax normal", _game())["args"], {"level": 1})


func test_planted_bad_money_goods_and_tax_lines_give_a_problem() -> void:
	assert_eq(_problem("money"), "Use: money N [TAG]")
	assert_eq(_problem("money x"), "'x' is not a number.")
	assert_eq(_problem("money 1 2 3"), "Use: money N [TAG]")
	assert_eq(_problem("money 5 ZZZ"), "No country ZZZ.", "an unknown tag")
	assert_eq(_problem("money 99999999999"), "'99999999999' is too large.")
	assert_eq(_problem("goods"), "Use: goods KEY N [TAG]")
	assert_eq(_problem("goods wheat 5"), "No good 'wheat'.", "an unknown good")
	assert_eq(_problem("goods stone y"), "'y' is not a number.")
	assert_eq(_problem("goods stone 5 ZZZ"), "No country ZZZ.")
	assert_eq(_problem("tax"), "Use: tax low|normal|high")
	assert_eq(_problem("tax extreme"), "Use: tax low|normal|high")
	assert_eq(_problem("tax low high"), "Use: tax low|normal|high")


func test_the_money_commands_need_a_game_with_countries_and_a_player() -> void:
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	for line: String in ["money 5", "goods stone 5", "tax low"]:
		assert_eq(_problem(line), "This map has no countries.", line)
	Session.game = null
	for line: String in ["money 5", "goods stone 5", "tax low"]:
		assert_eq(DevCommands.parse(line, null)["problem"], "There is no game.", line)
	assert_eq(Session.new_scenario(SCENARIO, 5), "")
	assert_eq(_problem("money 5"), "Choose your country first.", "before the pick")
	assert_eq(DevCommands.parse("money 5 GEN", _game())["problem"], "", "a tag needs no pick")


func test_run_money_changes_the_treasury_and_asks_for_the_chips_to_refresh() -> void:
	var before := _treasury(&"GEN")
	assert_eq(DevCommands.run("money 500", _ctx), "Done: +500 ducats to GEN.")
	assert_eq(_treasury(&"GEN"), before + 500)
	assert_eq(_sent, [[&"refresh_hud", {}]], "dev_money sends no event: the chips are asked")
	assert_eq(DevCommands.run("money -100 GEN", _ctx), "Done: −100 ducats to GEN.")
	assert_eq(_treasury(&"GEN"), before + 400)
	assert_eq(_sent.size(), 2)
	assert_eq(_game().action_log.back()["action"], "dev_money", "logged for the replay")
	# A sum past the treasury's limit is refused by the treasury and says so.
	assert_eq(DevCommands.run("money 999999999 GEN", _ctx), "Done: +999,999,999 ducats to GEN.", "up to a billion")
	var rich := DevCommands.run("money 999999999 GEN", _ctx)  # two billion and a little: past the limit
	assert_true(rich.begins_with("Refused:"), rich)
	assert_eq(_treasury(&"GEN"), before + 400 + 999999999, "a refused line changes nothing")
	assert_true(DevCommands.run("money -999999999 GEN", _ctx).begins_with("Done"))
	assert_eq(_treasury(&"GEN"), before + 400, "back to where it was")


func test_run_goods_changes_the_stores_and_asks_for_the_chips_to_refresh() -> void:
	var before := _stock(&"GEN", &"stone")
	assert_eq(DevCommands.run("goods stone 40", _ctx), "Done: +40 stone to GEN.")
	assert_eq(_stock(&"GEN", &"stone"), before + 40)
	assert_eq(_sent, [[&"refresh_hud", {}]])
	assert_eq(DevCommands.run("goods stone -10", _ctx), "Done: −10 stone to GEN.")
	assert_eq(_stock(&"GEN", &"stone"), before + 30)
	assert_eq(_game().action_log.back()["action"], "dev_goods")


func test_run_tax_sets_the_level_through_session_act() -> void:
	assert_eq(DevCommands.run("tax high", _ctx), "Done: tax high.")
	assert_eq(Countries.by_tag(_game(), &"GEN").tax, 2)
	assert_eq(DevCommands.run("tax low", _ctx), "Done: tax low.")
	assert_eq(Countries.by_tag(_game(), &"GEN").tax, 0)
	assert_eq(DevCommands.run("tax low", _ctx), "Refused: taxes are already Low", "the rule's own words")
	assert_true(_sent.is_empty(), "tax sends an event, not a request")


## M6 (L24): raise, march, hold, armies and as TAG parse to their actions, and each planted fault says its problem.
func test_m6_commands_parse_to_their_actions() -> void:
	var hex := _capital()
	var pikes := _kind_id(&"pikemen")
	var raise := DevCommands.parse("raise %d %d pikemen 2" % [hex.x, hex.y], _game())
	assert_eq(raise["kind"], &"act")
	assert_eq(raise["action"], "raise")
	assert_eq(raise["args"], {"hex": hex, "kind": pikes, "count": 2}, "a key names the kind, a count is given")
	assert_eq((DevCommands.parse("raise %d %d %d" % [hex.x, hex.y, pikes], _game())["args"] as Dictionary)["count"], 1, "one company by default, an id works")
	assert_eq(DevCommands.parse("as GEN raise %d %d pikemen" % [hex.x, hex.y], _game())["args"]["tag"], &"GEN", "as TAG sets the tag")
	assert_eq(_problem("hold 3"), "no army ID 3.", "hold needs an army that exists")
	assert_eq(_problem("raise 999 999 pikemen"), "no such hex 999 999.")
	assert_eq(_problem("raise %d %d nosuchkind" % [hex.x, hex.y]), "no such kind 'nosuchkind'.")
	assert_eq(_problem("raise %d %d pikemen x" % [hex.x, hex.y]), "'x' is not a number.")
	assert_eq(_problem("raise 1 2"), "Use: raise c r kind [n]")
	assert_eq(_problem("march 999 1 1"), "no army ID 999.")
	assert_eq(_problem("hold x"), "no army ID x.")
	assert_eq(_problem("as ZZZ raise %d %d pikemen" % [hex.x, hex.y]), "no country ZZZ.")
	assert_true(_problem("as GEN money 5").begins_with("as takes an action"), "as takes an action, not money")
	assert_eq(_problem("as"), "Use: as TAG action ...")


## M6 (L24): a raise, then armies, a march and a hold, through the console; the sandbox refuses the army commands.
func test_m6_raise_armies_march_hold_run_through_the_console() -> void:
	assert_eq(DevCommands.run("armies", _ctx), "You have no army.")
	var hex := _capital()
	var said := DevCommands.run("as GEN raise %d %d pikemen 1" % [hex.x, hex.y], _ctx)
	assert_true(said.begins_with("Done"), said)
	var army := Armies.of_country(_game(), &"GEN")[0]
	assert_true(DevCommands.run("armies", _ctx).begins_with("%d " % army.id), "armies lists the army by id")
	var goal := _march_goal(army, hex)
	assert_ne(goal, Vector2i(-1, -1), "a hex the army can march to")
	assert_true(DevCommands.run("march %d %d %d" % [army.id, goal.x, goal.y], _ctx).begins_with("Done"), "march is done")
	assert_eq(Armies.by_id(_game(), army.id).goal, goal, "the army's goal is the hex")
	assert_true(DevCommands.run("hold %d" % army.id, _ctx).begins_with("Done"), "hold is done")
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	assert_eq(DevCommands.run("raise 6 13 pikemen", _ctx), "Refused: the sandbox has no armies", "the sandbox refuses raise")
	assert_eq(DevCommands.run("armies", _ctx), "You have no army.")


func _kind_id(key: StringName) -> int:
	for i: int in _game().defs.units.size():
		if _game().defs.units[i].key == key:
			return i
	return -1


func _capital() -> Vector2i:
	return Countries.by_tag(_game(), &"GEN").capital


## A hex near `from` the army can march to (MovePreview says it is ok), or (-1, -1).
func _march_goal(army: Army, from: Vector2i) -> Vector2i:
	for i: int in _game().map.hex_count():
		var hex := _game().map.hex_of(i)
		if hex == from or absi(hex.x - from.x) + absi(hex.y - from.y) > 4:
			continue
		var preview := MovePreview.to(_game(), &"GEN", army.id, hex)
		if bool((preview["verdict"] as Dictionary).get("ok", false)):
			return hex
	return Vector2i(-1, -1)


func test_help_names_the_money_commands() -> void:
	var help := DevCommands.run("help", _ctx)
	for word: String in ["money", "goods", "tax low|normal|high"]:
		assert_true(help.contains(word), "help names " + word)


func test_people_sets_the_hexs_people_logs_it_and_asks_for_a_refresh() -> void:
	var hex := Vector2i(6, 13)
	var parsed := DevCommands.parse("people 6 13 3990", _game())
	assert_eq([parsed["kind"], parsed["args"], parsed["problem"]], [&"people", {"hex": hex, "people": 3990}, ""])
	assert_eq(DevCommands.run("people 6 13 3990", _ctx), "Done: 3,990 people at 6, 13.")
	assert_eq(_game().state.people[_game().map.index_of(hex)], 3990)
	assert_eq(_game().action_log.back()["action"], "dev_people", "logged for the replay")
	assert_eq(_sent, [[&"refresh_hud", {}]])
	assert_eq(DevCommands.run("people 6 13 1", _ctx), "Done: 1 person at 6, 13.")
	assert_true(DevCommands.run("help", _ctx).contains("people c r N"))


func test_planted_bad_people_lines_give_their_problem_and_change_nothing() -> void:
	var before := _game().digest()
	assert_eq(_problem("people"), "Use: people c r N")
	assert_eq(_problem("people 6 13"), "Use: people c r N")
	assert_eq(_problem("people 999 999 5"), "no such hex")
	assert_eq(_problem("people x 13 5"), "no such hex")
	assert_eq(_problem("people 6 13 x"), "N must be a whole number of 0 or more")
	assert_eq(_problem("people 6 13 -5"), "N must be a whole number of 0 or more")
	assert_eq(_problem("people 6 13 99999999999"), "N must be a whole number of 0 or more")
	assert_eq(_problem("people 6 13 2000000"), "N must be a whole number from 0 to 1,000,000")
	assert_eq(DevCommands.parse("people 6 13 1000000", _game())["problem"], "", "the limit itself parses")
	var sea := Vector2i.ZERO
	for k: int in _game().map.hex_count():
		if _game().map.land[k] == 0:
			sea = _game().map.hex_of(k)
			break
	assert_eq(DevCommands.run("people %d %d 5" % [sea.x, sea.y], _ctx), "Refused: no one keeps people there.", "sea")
	assert_eq(_game().digest(), before, "a refused line changes nothing")
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	assert_eq(_problem("people 6 13 5"), "the sandbox has no countries")
	Session.game = null
	assert_eq(DevCommands.parse("people 6 13 5", null)["problem"], "There is no game.")


## M7 (B28, D57): declare, peace, storm, standing and wars parse to their actions; each planted fault says its problem.
func test_m7_commands_parse_to_their_actions() -> void:
	var neighbour := WarFixture.neighbour_of(_game(), &"GEN")
	var declare := DevCommands.parse("declare %s" % String(neighbour).to_lower(), _game())
	assert_eq(declare["problem"], "", "a tag in lower case is read")
	assert_eq(declare["action"], "declare_war")
	assert_eq(declare["args"], {"target": neighbour})
	var peace := DevCommands.parse("peace %s yield" % neighbour, _game())
	assert_eq(peace["action"], "make_peace")
	assert_eq(peace["args"], {"target": neighbour, "terms": &"yield"})
	assert_eq(DevCommands.parse("as %s declare GEN" % neighbour, _game())["args"], {"target": &"GEN", "tag": neighbour}, "as TAG declares for TAG")
	assert_eq(DevCommands.parse("wars", _game())["kind"], &"wars")
	assert_eq(_problem("declare ZZZ"), "no country ZZZ.", "planted: a country that is not there")
	assert_eq(_problem("peace ZZZ take"), "no country ZZZ.")
	assert_eq(_problem("peace %s sue" % neighbour), "no such terms 'sue': take, white or yield.", "planted: terms that do not exist")
	assert_eq(_problem("declare"), "Use: declare TAG")
	assert_eq(_problem("peace GEN"), "Use: peace TAG take|white|yield")
	assert_eq(_problem("storm 99 1 1"), "no army ID 99.", "planted: an army that is not there")
	assert_eq(_problem("storm x 1 1"), "no army ID x.")
	assert_eq(_problem("storm 1 2"), "Use: storm ID c r")
	assert_eq(_problem("standing 99 hold"), "no army ID 99.")
	assert_eq(_problem("standing 1"), "Use: standing ID hold|withdraw")
	assert_eq(_problem("wars now"), "wars takes no arguments.")
	var hex := _capital()
	assert_true(DevCommands.run("raise %d %d pikemen 1" % [hex.x, hex.y], _ctx).begins_with("Done"))
	var army := Armies.of_country(_game(), &"GEN")[0]
	assert_eq(_problem("standing %d stand" % army.id), "no such standing order 'stand': hold or withdraw.", "planted: an order that does not exist")
	assert_eq(_problem("storm %d 999 999" % army.id), "no such hex 999 999.")


func test_m7_commands_run_through_the_console() -> void:
	assert_eq(DevCommands.run("wars", _ctx), "You are at war with no one.")
	var neighbour := WarFixture.neighbour_of(_game(), &"GEN")
	var hex := _capital()
	assert_true(DevCommands.run("raise %d %d pikemen 1" % [hex.x, hex.y], _ctx).begins_with("Done"))
	var army := Armies.of_country(_game(), &"GEN")[0]
	assert_true(DevCommands.run("standing %d withdraw" % army.id, _ctx).begins_with("Done"), "the standing order is set")
	assert_eq(Armies.by_id(_game(), army.id).standing, Army.STANDING_WITHDRAW)
	assert_true(DevCommands.run("standing %d withdraw" % army.id, _ctx).begins_with("Refused"), "the rules refuse the same order twice")
	assert_true(DevCommands.run("peace %s white" % neighbour, _ctx).begins_with("Refused"), "no peace without a war")
	assert_true(DevCommands.run("declare %s" % neighbour, _ctx).begins_with("Done"), "the war is declared")
	assert_true(DevCommands.run("declare %s" % neighbour, _ctx).contains("already at war"), "and not twice")
	var listed := DevCommands.run("wars", _ctx)
	assert_true(listed.contains("since Spring 1480") and listed.contains("score 0"), listed)
	assert_true(DevCommands.run("storm %d %d %d" % [army.id, hex.x, hex.y], _ctx).begins_with("Refused"), "a storm needs a fortress to storm")
	assert_true(DevCommands.run("peace %s yield" % neighbour, _ctx).begins_with("Done"), "the peace is made")
	assert_eq(DevCommands.run("wars", _ctx), "You are at war with no one.")
	assert_true(DevCommands.run("help", _ctx).contains("declare TAG"), "help names the war commands")


func test_the_sandbox_refuses_declare_and_peace() -> void:
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	assert_eq(DevCommands.run("declare MLO", _ctx), "the sandbox has no countries, so no war")
	assert_eq(DevCommands.run("peace MLO take", _ctx), "the sandbox has no countries, so no war")
	assert_eq(DevCommands.run("wars", _ctx), "You are at war with no one.")


## 4.15: the console's storm (and `as`) tells nothing of a place the country cannot see: one sentence for walls and none.
func test_storm_on_an_unseen_place_gets_the_one_sentence() -> void:
	var hex := _capital()
	assert_true(DevCommands.run("raise %d %d pikemen 1" % [hex.x, hex.y], _ctx).begins_with("Done"))
	var army := Armies.of_country(_game(), &"GEN")[0]
	var said: Array[String] = []
	for i: int in _game().map.hex_count():
		var far := _game().map.hex_of(i)
		if _game().map.land[i] == 1 and not Sight.sees(_game(), &"GEN", far) and Territory.owner_tag(_game(), far) != &"GEN":
			said.append(DevCommands.run("storm %d %d %d" % [army.id, far.x, far.y], _ctx))
			if said.size() == 6:
				break
	assert_eq(said.size(), 6, "unseen places were found")
	for line: String in said:
		assert_eq(line, "Refused: You cannot see that place.", "walls or none, the same words")
	assert_eq(DevCommands.run("as GEN storm %d 0 0" % army.id, _ctx).contains("walls"), false, "as TAG leaks nothing either")
