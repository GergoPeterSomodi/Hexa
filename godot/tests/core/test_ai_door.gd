## The door's text rule (docs/architecture/m8-build-spec.md 4.3, 9): outside core/ai/ai_know.gd no file of core/ai/ names the game's own
## fields or the systems whose state the AI may not read, or calls the game's check and act (AiKnow.check and AiKnow.act are the
## door's); `game.player` is read only by ai_turn.gd, which skips the player's seat. P: fixture texts with each token are reported.
extends GutTest

const ROOT := "res://core/ai"
const TOKENS: Array[String] = ["game.state", "game.armies", "game.countries", "game.wars", "game.sieges", "game.battles",
	"game.battle_records", "game.luck", "game.stats", "game.chronicle", "Armies.", "Stats.", "Sieges.", "Occupation.", "Treasury.",
	"Stores.", "People.", "Wars.men_under_arms", "Sight.", "Knowledge.discovered"]
const CALLS := "(?<!AiKnow)\\.(act|check)\\("


## The problems of one file's text: [] when it keeps the rule.
func _problems(text: String, file: String) -> Array[String]:
	var out: Array[String] = []
	if file != "ai_know.gd":
		for token: String in TOKENS:
			if text.contains(token):
				out.append("%s: %s" % [file, token])
		if RegEx.create_from_string(CALLS).search(text) != null:
			out.append("%s: a call of the game's act or check" % file)
	if file != "ai_turn.gd" and text.contains("game.player"):
		out.append("%s: game.player" % file)
	return out


func _files() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(ROOT)
	for name: String in dir.get_files():
		if name.ends_with(".gd"):
			out.append(name)
	out.sort()
	return out


func test_the_ai_files_keep_the_rule() -> void:
	var files := _files()
	assert_gte(files.size(), 9, "the nine files of the frame")
	for name: String in files:
		assert_eq(_problems(FileAccess.get_file_as_string("%s/%s" % [ROOT, name]), name), [] as Array[String], name)


func test_p_every_token_is_reported_outside_the_door() -> void:
	for token: String in TOKENS:
		assert_eq(_problems("var x := %s(1)" % token, "ai_war.gd").size(), 1, token)
		assert_eq(_problems("var x := %s(1)" % token, "ai_know.gd").size(), 0, "the door itself may: " + token)


func test_p_the_games_act_and_check_are_reported_the_doors_are_not() -> void:
	assert_eq(_problems("game.act(\"raise\", {})", "ai_peace.gd").size(), 1)
	assert_eq(_problems("game.check(\"raise\", {})", "ai_peace.gd").size(), 1)
	assert_eq(_problems("var v := AiKnow.check(game, tag, \"raise\", {})", "ai_peace.gd").size(), 0)
	assert_eq(_problems("AiKnow.act(turn, game, tag, \"raise\", {})", "ai_peace.gd").size(), 0)


func test_p_game_player_is_reported_outside_the_turn() -> void:
	assert_eq(_problems("if tag == game.player:", "ai_war.gd").size(), 1)
	assert_eq(_problems("if tag == game.player:", "ai_know.gd").size(), 1, "even the door leaves the player to the turn")
	assert_eq(_problems("if tag == game.player:", "ai_turn.gd").size(), 0)


## FG12 (R35): the discovery and the sight are read only by the door; a step module that asks them directly is reported.
func test_p_sight_and_discovery_read_outside_the_door_are_reported() -> void:
	assert_eq(_problems("var x := Sight.sees(game, tag, hex)", "ai_war.gd").size(), 1, "Sight.")
	assert_eq(_problems("var x := Knowledge.discovered(game, tag, hex)", "ai_brief.gd").size(), 1, "Knowledge.discovered")
	assert_eq(_problems("var x := AiKnow.discovered(game, tag, hex)", "ai_war.gd").size(), 0, "the door's own gate is allowed")
	assert_eq(_problems("var x := Sight.sees(game, tag, hex)", "ai_know.gd").size(), 0, "the door itself may")


func test_p_a_step_module_that_reads_the_armies_is_reported() -> void:
	var text := FileAccess.get_file_as_string("%s/ai_forces.gd" % ROOT) + "\nvar leak := game.armies\n"
	assert_eq(_problems(text, "ai_forces.gd"), ["ai_forces.gd: game.armies"] as Array[String])
