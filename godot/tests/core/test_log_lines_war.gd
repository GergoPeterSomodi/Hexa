## LogLinesWar (docs/architecture/m7-build-spec.md 4.14, 4.15, 9): the sentences of the six war kinds for the player, a known
## other and an unknown one; the fog of battles and sieges; the War and Mine filters; the battle record; save and load.
## Kept apart from test_log_lines.gd, which is near the 800-line limit.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"
const PAVIA := Vector2i(10, 9)
const HEX_A := Vector2i(7, 6)
const HEX_B := Vector2i(6, 9)

var _g: Game


func before_each() -> void:
	var defs := load(DEFS_PATH) as GameDefs
	_g = Game.new_scenario(load(MAP_PATH) as MapData, defs, defs.scenarios[defs.scenarios.size() - 1], 1480)
	assert_true(bool(_g.act("choose_country", {"tag": &"GEN"})["ok"]))


## The entry the chronicle stored for the event (the plain form, as the log reads it).
func _emit(kind: String, extra: Dictionary) -> Dictionary:
	var event := {"kind": kind}
	event.merge(extra)
	_g.emit(event)
	return _g.chronicle.entries[_g.chronicle.entries.size() - 1]


func _known() -> StringName:
	return Knowledge.known(_g, &"GEN")[0]


func _stranger() -> StringName:
	for c: Country in _g.countries:
		if c.tag != &"GEN" and not Knowledge.knows(_g, &"GEN", c.tag):
			return c.tag
	return &""


## Two countries the player does not know, neither the player's own.
func _two_strangers() -> Array[StringName]:
	var out: Array[StringName] = []
	for c: Country in _g.countries:
		if c.tag != &"" and c.tag != &"GEN" and not Knowledge.knows(_g, &"GEN", c.tag):
			out.append(c.tag)
	return out


func _living() -> Array[String]:
	var out: Array[String] = []
	for c: Country in _g.countries:
		if c.tag != &"":
			out.append(String(c.tag))
	return out


func _the(tag: StringName) -> String:
	return Words.country_the(_g, tag)


func _line(kind: String, extra: Dictionary, viewer: StringName = &"GEN") -> Dictionary:
	return LogLines.line_of(_g, _emit(kind, extra), viewer)


func _battle(attacker: StringName, defender: StringName, winner: StringName, loser: StringName, extra: Dictionary = {}) -> Dictionary:
	var event := {"tag": attacker, "hex": PAVIA, "others": [defender], "defender": defender, "attacker": attacker,
		"assault": false, "how": "broke", "cause": "morale", "seasons": 1, "days": 4, "name": "Alessandria", "year": 1480,
		"killed": {String(attacker): 120, String(defender): 410}, "wounded": {String(attacker): 60, String(defender): 0},
		"retreat": Vector2i(8, 8), "record": 3, "stormed": false, "winner": winner, "loser": loser,
		"witnesses": _living()}
	event.merge(extra, true)  # overwrite: a test's extra fields replace the defaults
	return event


func test_war_declared_by_the_player_and_on_the_player() -> void:
	var known := _known()
	var mine := _line("war_declared", {"tag": &"GEN", "target": known, "war": 1, "witnesses": _living()})
	assert_eq(mine["text"], "You declared war on %s." % _the(known))
	assert_eq([mine["keyword"], mine["tone"], mine["notify"], mine["floating"], mine["mine"]],
		["War", "bad", false, "War!", true])
	var on_you := _line("war_declared", {"tag": known, "target": &"GEN", "war": 2, "witnesses": _living()})
	assert_eq(on_you["text"], "%s declared war on you!" % LogLines.capital(_the(known)))
	assert_true(bool(on_you["notify"]), "a war on the player notifies")
	assert_eq(on_you["hex"], Countries.by_tag(_g, &"GEN").capital)
	assert_eq(on_you["filters"], [&"all", &"mine", &"war"] as Array[StringName])


func test_a_witnessed_other_war_is_muted_and_names_both() -> void:
	var known := _known()
	var stranger := _stranger()
	var line := _line("war_declared", {"tag": known, "target": stranger, "war": 3, "witnesses": _living()})
	assert_eq(line["text"], "%s declared war on %s." % [LogLines.capital(_the(known)), _the(stranger)])
	assert_eq([line["tone"], line["notify"], line["floating"], line["mine"]], ["muted", false, "", false])


func test_peace_terms_for_the_player_on_both_sides() -> void:
	var known := _known()
	var two := [Vector2i(1, 1), Vector2i(1, 2)] as Array
	var took := _line("peace_made", {"tag": &"GEN", "target": known, "war": 1, "terms": "take", "moved": two,
		"released": [], "witnesses": _living()})
	assert_eq(took["text"], "Peace with %s: you took 2 districts." % _the(known))
	assert_eq([took["keyword"], took["tone"], took["notify"], took["floating"]], ["Peace", "plain", true, "Peace"])
	var gave := _line("peace_made", {"tag": known, "target": &"GEN", "war": 1, "terms": "take", "moved": two,
		"released": [], "witnesses": _living()})
	assert_eq(gave["text"], "Peace with %s: you gave up 2 districts." % _the(known), "the actor takes: the player loses land")
	var yielded := _line("peace_made", {"tag": &"GEN", "target": known, "war": 1, "terms": "yield", "moved": [Vector2i(1, 1)],
		"released": [], "witnesses": _living()})
	assert_eq(yielded["text"], "Peace with %s: you gave up 1 district." % _the(known))
	var white := _line("peace_made", {"tag": &"GEN", "target": known, "war": 1, "terms": "white", "moved": [],
		"released": [], "witnesses": _living()})
	assert_eq(white["text"], "Peace with %s: a white peace." % _the(known))


func test_the_timer_peace_counts_the_seasons_of_its_war() -> void:
	var known := _known()
	_g.turn = 2
	_emit("war_declared", {"tag": &"GEN", "target": known, "war": 9, "witnesses": _living()})
	_g.turn = 5
	var timed := _line("peace_made", {"tag": &"GEN", "target": known, "war": 9, "terms": "timer", "moved": [],
		"released": [], "witnesses": _living()})
	assert_eq(timed["text"], "Peace with %s: the war ended after 3 seasons." % _the(known))
	var orphan := _line("peace_made", {"tag": &"GEN", "target": known, "war": 77, "terms": "timer", "moved": [],
		"released": [], "witnesses": _living()})
	assert_eq(orphan["text"], "Peace with %s: the war ended by the timer." % _the(known),
		"a war the chronicle no longer holds: no count, never a wrong one")


func test_a_battle_won_by_the_player_has_the_spec_sentence_and_its_record() -> void:
	var known := _known()
	var line := _line("battle_ended", _battle(&"GEN", known, &"GEN", known))
	assert_eq(line["text"], "Battle of Alessandria, 1480: you won in 4 days. You lost 120 men (60 wounded), %s 410; "
		% _the(known) + "they fled to (8, 8).")
	assert_eq([line["keyword"], line["tone"], line["notify"], line["floating"], line["hex"]],
		["Battle", "good", true, "Victory!", PAVIA])
	assert_eq(line["record"], 3, "the record id is the line's")
	assert_eq(line["filters"], [&"all", &"mine", &"war"] as Array[StringName])


func test_a_battle_lost_and_a_draw_by_the_player() -> void:
	var known := _known()
	var lost := _line("battle_ended", _battle(&"GEN", known, known, &"GEN", {"days": 1, "retreat": Army.NO_HEX}))
	assert_eq(lost["text"], "Battle of Alessandria, 1480: you lost in 1 day. You lost 120 men (60 wounded), %s 410."
		% _the(known))
	assert_eq([lost["tone"], lost["floating"]], ["bad", "Defeat!"])
	var draw := _line("battle_ended", _battle(&"GEN", known, &"", &"", {"how": "gone", "retreat": Army.NO_HEX,
		"wounded": {"GEN": 0, String(known): 0}}))
	assert_eq(draw["text"], "Battle of Alessandria, 1480: no side won in 4 days. You lost 120 men, %s 410." % _the(known))
	assert_eq([draw["tone"], draw["floating"]], ["plain", ""])


func test_a_battle_by_peace_has_no_days_and_no_notice() -> void:
	var known := _known()
	var line := _line("battle_ended", _battle(&"GEN", known, &"", &"", {"how": "peace", "record": -1}))
	assert_eq(line["text"], "Battle of Alessandria, 1480: the fight ended with the peace.")
	assert_false(bool(line["notify"]))
	assert_eq(line["record"], -1)


func test_a_witnessed_battle_of_others_names_only_the_known() -> void:
	var known := _known()
	var stranger := _stranger()
	var line := _line("battle_ended", _battle(known, stranger, known, stranger, {"name": "Gavi", "year": 1481,
		"killed": {String(known): 5, String(stranger): 9}, "wounded": {}, "retreat": Army.NO_HEX, "record": 4}))
	assert_eq(line["text"], "Battle of Gavi, 1481: %s beat a country." % LogLines.short_name(_g, known))
	assert_eq([line["keyword"], line["tone"], line["notify"], line["floating"], line["mine"]],
		["Battle", "muted", false, "Battle", false])
	assert_false(str(line["text"]).contains(LogLines.short_name(_g, stranger)), "the unknown side is not named")


func test_a_battle_between_strangers_and_no_witness_is_nothing() -> void:
	var pair := _two_strangers()
	assert_gt(pair.size(), 1, "the scenario has two countries GEN does not know")
	var seen_by_none := _battle(pair[0], pair[1], pair[0], pair[1], {"witnesses": []})
	assert_eq(LogLines.line_of(_g, _emit("battle_ended", seen_by_none), &"GEN"), {},
		"a battle the viewer did not witness is told to nobody")


func test_siege_lines_for_the_besieger_the_defender_and_a_witness() -> void:
	var known := _known()
	var mine := _line("siege_started", {"tag": &"GEN", "hex": PAVIA, "others": [known], "name": "Pavia", "need": 10,
		"level": 2, "garrison": 800, "men": 1000, "witnesses": _living()})
	assert_eq(mine["text"], "You besiege Pavia (10, 9): it needs 10.")
	assert_eq([mine["keyword"], mine["tone"], mine["notify"], mine["floating"]], ["Siege", "warn", true, "Siege"])
	var yours := _line("siege_started", {"tag": known, "hex": PAVIA, "others": [&"GEN"], "name": "Pavia", "need": 10,
		"level": 2, "garrison": 800, "men": 1000, "witnesses": _living()})
	assert_eq(yours["text"], "%s besieges your Pavia (10, 9)." % LogLines.short_name(_g, known))
	var stranger := _stranger()
	var seen := _line("siege_started", {"tag": stranger, "hex": PAVIA, "others": [known], "name": "Pavia", "need": 10,
		"level": 2, "garrison": 800, "men": 1000, "witnesses": [&"GEN"]})
	assert_eq(seen["text"], "A country besieges Pavia (10, 9).", "an unknown besieger is unnamed, and the witness is muted")
	assert_eq([seen["tone"], seen["notify"]], ["muted", false])


func test_a_lifted_siege_gives_its_reason_for_the_besieger() -> void:
	var expect := {"left": "your army left", "relief": "a relief army beat yours",
		"outnumbered": "your army is too small for its garrison", "peace": "peace was made"}
	for why: String in expect:
		var line := _line("siege_lifted", {"tag": &"GEN", "hex": PAVIA, "others": [_known()], "why": why, "name": "Pavia",
			"progress": 3, "need": 10, "seasons": 2, "witnesses": _living()})
		assert_eq(line["text"], "The siege of Pavia (10, 9) is lifted: %s." % expect[why], why)
	var yours := _line("siege_lifted", {"tag": _known(), "hex": PAVIA, "others": [&"GEN"], "why": "left", "name": "Pavia",
		"progress": 3, "need": 10, "seasons": 2, "witnesses": _living()})
	assert_eq([yours["text"], yours["tone"]], ["The siege of your Pavia (10, 9) is lifted.", "good"])


func test_a_lifted_siege_for_the_player_needs_a_reason() -> void:
	var line := LogLines.line_of(_g, _emit("siege_lifted", {"tag": &"GEN", "hex": PAVIA, "others": [_known()], "why": "magic",
		"name": "Pavia", "progress": 3, "need": 10, "seasons": 2, "witnesses": _living()}), &"GEN")
	assert_eq(line, {}, "a reason the log does not know is no line (no sentence made up)")


func test_districts_taken_lost_retaken_and_freed() -> void:
	var known := _known()
	var taken := _line("district_captured", {"tag": &"GEN", "hex": HEX_A, "others": [known], "owner": known, "by": "walk",
		"garrison_lost": 0, "witnesses": _living()})
	assert_eq(taken["text"], "Taken: %s from %s." % [Words.place(_g, HEX_A), _the(known)])
	assert_eq([taken["keyword"], taken["tone"], taken["floating"], taken["notify"]], ["Taken", "good", "Taken", true])
	var lost := _line("district_captured", {"tag": known, "hex": HEX_B, "others": [&"GEN"], "owner": &"GEN", "by": "walk",
		"garrison_lost": 0, "witnesses": _living()})
	assert_eq(lost["text"], "Lost: %s to %s." % [Words.place(_g, HEX_B), _the(known)])
	assert_eq([lost["keyword"], lost["tone"], lost["floating"]], ["Lost", "bad", "Lost"])
	var retaken := _line("district_captured", {"tag": &"GEN", "hex": HEX_A, "others": [known], "owner": &"GEN", "by": "retaken",
		"garrison_lost": 0, "witnesses": _living()})
	assert_eq(retaken["text"], "Retaken: %s." % Words.place(_g, HEX_A))
	var freed := _line("district_captured", {"tag": &"GEN", "hex": HEX_A, "others": [known], "owner": &"GEN", "by": "freed",
		"garrison_lost": 0, "witnesses": _living()})
	assert_eq(freed["text"], "Freed: %s went back to %s." % [Words.place(_g, HEX_A), _the(&"GEN")])


func test_a_fortress_fall_names_the_seasons_and_the_open_land() -> void:
	var known := _known()
	var opened: Array[Vector2i] = [HEX_A, HEX_B]
	var fall := _line("district_captured", {"tag": &"GEN", "hex": PAVIA, "others": [known], "owner": known, "by": "siege",
		"name": "Pavia", "seasons": 4, "opened": opened, "garrison_lost": 800, "witnesses": _living()})
	assert_eq(fall["text"], "Pavia (10, 9) has fallen after 4 seasons: its land lies open (2 districts).")
	assert_eq([fall["keyword"], fall["tone"], fall["floating"]], ["Fallen", "good", "Taken"])
	var lost := _line("district_captured", {"tag": known, "hex": PAVIA, "others": [&"GEN"], "owner": &"GEN", "by": "siege",
		"name": "Pavia", "seasons": 4, "opened": [], "garrison_lost": 800, "witnesses": _living()})
	assert_eq(lost["text"], "Pavia (10, 9) has fallen after 4 seasons.")
	assert_eq([lost["tone"], lost["floating"]], ["bad", "Lost"])


func test_a_district_of_others_is_muted_and_unknown_is_unnamed() -> void:
	var stranger := _stranger()
	var known := _known()
	var line := _line("district_captured", {"tag": stranger, "hex": HEX_A, "others": [known], "owner": known, "by": "walk",
		"garrison_lost": 0, "witnesses": [&"GEN"]})
	assert_eq(line["text"], "A country took %s." % Words.place(_g, HEX_A), "a witnessed take by an unknown country")
	assert_eq([line["tone"], line["notify"]], ["muted", false])


func test_an_unknown_country_at_war_with_the_player_is_named() -> void:
	# The player's own affairs name a country at war with the player by its real name (it declared war by name, 4.15).
	var stranger := _stranger()
	var siege := _line("siege_started", {"tag": stranger, "hex": PAVIA, "others": [&"GEN"], "name": "Pavia", "need": 3,
		"witnesses": _living()})
	assert_eq(siege["text"], "%s besieges your Pavia (10, 9)." % LogLines.capital(LogLines.short_name(_g, stranger)),
		"the attacker's name starts the sentence in capitals")
	assert_true(bool(siege["notify"]))
	var battle := _line("battle_ended", _battle(stranger, &"GEN", stranger, &"GEN", {"days": 4, "retreat": Army.NO_HEX,
		"killed": {String(stranger): 120, "GEN": 410}, "wounded": {}}))
	assert_eq(battle["text"], "Battle of Alessandria, 1480: you lost in 4 days. You lost 410 men, %s 120."
		% Words.country_the(_g, stranger), "the opponent is named by its real name in the player's battle")
	var taken := _line("district_captured", {"tag": stranger, "hex": HEX_B, "others": [&"GEN"], "owner": &"GEN",
		"by": "walk", "witnesses": _living()})
	assert_eq(taken["text"], "Lost: %s to %s." % [Words.place(_g, HEX_B), Words.country_the(_g, stranger)],
		"a district taken from the player names its taker")
	var gained := _line("district_captured", {"tag": &"GEN", "hex": HEX_A, "others": [stranger], "owner": stranger,
		"by": "walk", "witnesses": _living()})
	assert_eq(gained["text"], "Taken: %s from %s." % [Words.place(_g, HEX_A), Words.country_the(_g, stranger)],
		"a district the player takes names the country it came from")


func test_the_same_unknown_country_in_others_affairs_stays_unnamed() -> void:
	# A witnessed affair of others that the player does not know: the unknown country is "a country" (4.15).
	var stranger := _stranger()
	var other := _two_strangers()
	var siege := _line("siege_started", {"tag": stranger, "hex": PAVIA, "others": [other[1] if other[1] != stranger else other[0]],
		"name": "Pavia", "need": 3, "witnesses": [&"GEN"]})
	assert_eq(siege["text"], "A country besieges Pavia (10, 9).", "not the player's affair: unnamed")


func test_a_war_line_the_entry_cannot_make_is_nothing() -> void:
	var no_hex := LogLines.line_of(_g, _emit("battle_ended", _battle(&"GEN", _known(), &"GEN", _known(),
		{"hex": "bad"})), &"GEN")
	assert_eq(no_hex, {}, "a battle with no hex has no line")
	var no_terms := LogLines.line_of(_g, _emit("peace_made", {"tag": &"GEN", "target": _known(), "war": 1, "terms": "steal",
		"moved": [], "witnesses": _living()}), &"GEN")
	assert_eq(no_terms, {}, "unknown terms have no line")
	var no_by := LogLines.line_of(_g, _emit("district_captured", {"tag": &"GEN", "hex": HEX_A, "others": [_known()],
		"by": "bribe", "witnesses": _living()}), &"GEN")
	assert_eq(no_by, {}, "an unknown way of taking has no line")


func test_filters_of_equals_the_lines_filters_for_every_war_kind_and_viewer() -> void:
	var known := _known()
	var stranger := _stranger()
	_emit("war_declared", {"tag": &"GEN", "target": known, "war": 1, "witnesses": _living()})
	_emit("war_declared", {"tag": known, "target": stranger, "war": 2, "witnesses": _living()})
	_emit("peace_made", {"tag": known, "target": &"GEN", "war": 1, "terms": "white", "moved": [], "released": [],
		"witnesses": _living()})
	_emit("battle_ended", _battle(&"GEN", known, &"GEN", known))
	_emit("battle_ended", _battle(known, stranger, known, stranger, {"witnesses": []}))
	_emit("siege_started", {"tag": known, "hex": PAVIA, "others": [&"GEN"], "name": "Pavia", "need": 3, "witnesses": _living()})
	_emit("siege_lifted", {"tag": &"GEN", "hex": PAVIA, "others": [known], "why": "peace", "name": "Pavia",
		"witnesses": _living()})
	_emit("district_captured", {"tag": &"GEN", "hex": HEX_A, "others": [known], "owner": known, "by": "walk",
		"witnesses": _living()})
	var count := 0
	for entry: Dictionary in _g.chronicle.entries:
		if not LogLinesWar.is_war_kind(str(entry["kind"])):
			continue
		for viewer: StringName in [&"GEN", known, stranger, &""]:
			var line := LogLines.line_of(_g, entry, viewer)
			var filters := LogLines.filters_of(_g, entry, viewer)
			if line.is_empty():
				assert_eq(filters, [] as Array[StringName], "%s for %s" % [entry["kind"], viewer])
			else:
				assert_eq(filters, line["filters"], "%s for %s" % [entry["kind"], viewer])
			count += 1
	assert_gt(count, 20)


func test_the_war_filter_holds_war_and_army_kinds_and_mine_holds_the_players() -> void:
	var known := _known()
	_emit("war_declared", {"tag": known, "target": _stranger(), "war": 1, "witnesses": _living()})
	_emit("war_declared", {"tag": &"GEN", "target": known, "war": 2, "witnesses": _living()})
	_g.turn = 2
	_g.version += 1
	var war := LogLines.entries(_g, &"GEN", &"war")
	var seen: Array[String] = []
	for season: Dictionary in war:
		for line: Dictionary in season["lines"]:
			seen.append(str(line["text"]))
	assert_eq(seen.size(), 2, "the witnessed other's war and the player's")
	var mine := LogLines.entries(_g, &"GEN", &"mine")
	var mine_wars: Array[String] = []
	for season: Dictionary in mine:
		for line: Dictionary in season["lines"]:
			if str(line["keyword"]) == "War":
				mine_wars.append(str(line["text"]))
	assert_eq(mine_wars, ["You declared war on %s." % _the(_known())], "only the player's own declaration is a mine war line")


func test_war_lines_are_equal_after_a_save_and_load() -> void:
	var known := _known()
	_emit("war_declared", {"tag": &"GEN", "target": known, "war": 1, "witnesses": _living()})
	_g.turn = 3
	_emit("battle_ended", _battle(&"GEN", known, &"GEN", known))
	_emit("district_captured", {"tag": &"GEN", "hex": PAVIA, "others": [known], "owner": known, "by": "siege",
		"name": "Pavia", "seasons": 2, "opened": [HEX_A], "garrison_lost": 0, "witnesses": _living()})
	_g.version += 1
	var before := LogLines.entries(_g, &"GEN", &"war")
	assert_gt(before.size(), 0)
	var back := _round_trip(_g)
	assert_not_null(back)
	assert_eq(LogLines.entries(back, &"GEN", &"war"), before)


func _round_trip(game: Game) -> Game:
	var dir := "user://test_log_lines_war_%d/" % Time.get_ticks_usec()
	assert_eq(SaveFile.write(game, "1", {"saved_unix": 1}, {}, dir), "")
	var read := SaveFile.read("1", dir)
	assert_eq(read["problem"], "")
	var restored := Snapshot.restore(read["body"] as Dictionary, game.map, game.defs)
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	DirAccess.remove_absolute(dir)
	return restored["game"] as Game
