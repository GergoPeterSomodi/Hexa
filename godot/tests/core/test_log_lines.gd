## LogLines (docs/architecture/m3-build-spec.md 4.4, 5.6, 9): each kind's sentence for the actor, a known other and an
## unknown other; keyword, tone, filters, notify, floating; `entries` newest season first, 8 seasons, 60 lines.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"
const SAVONA := Vector2i(7, 12)
const WOODS := Vector2i(9, 11)
const GENOA := Vector2i(8, 13)

var _g: Game


func before_each() -> void:
	var defs := load(DEFS_PATH) as GameDefs
	_g = Game.new_scenario(load(MAP_PATH) as MapData, defs, defs.scenarios[defs.scenarios.size() - 1], 1480)
	assert_true(bool(_g.act("choose_country", {"tag": &"GEN"})["ok"]))


func _work(action: StringName, family: int, level_to: int, hex: Vector2i, seasons: int, tag: StringName = &"GEN") -> Work:
	var w := Work.new()
	w.id = 1
	w.tag = tag
	w.hex = hex
	w.action = action
	w.family = family
	w.level_to = level_to
	w.started_turn = _g.turn
	w.seasons = seasons
	w.seasons_left = seasons
	return w


func _emit(kind: String, w: Work, extra: Dictionary = {}) -> Dictionary:
	var event := {"kind": kind, "tag": w.tag, "hex": w.hex, "work": w.to_dict()}
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


func test_the_actors_own_lines() -> void:
	var started := LogLines.line_of(_g, _emit("work_started", _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4)), &"GEN")
	assert_eq(started["text"], "Begun: vineyard, first stage, near Savona (7, 12). Ready Spring 1481.")
	assert_eq([started["keyword"], started["tone"], started["floating"], started["mine"], started["notify"]],
		["Begun", "plain", "Begun", true, false])
	assert_eq(started["hex"], SAVONA)
	assert_eq(started["filters"], [&"all", &"works", &"mine"] as Array[StringName])
	assert_eq(started["turn"], 1)
	var done := LogLines.line_of(_g, _emit("work_finished", _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4)), &"GEN")
	assert_eq(done["text"], "Finished: vineyard, first stage, near Savona (7, 12).")
	assert_eq([done["keyword"], done["tone"], done["floating"], done["notify"]], ["Finished", "good", "Finished", true])


func test_the_ready_date_skips_a_snow_winter() -> void:
	_g.turn = 2
	var summer := LogLines.line_of(_g, _emit("work_started", _work(Works.BUILD, ImproveRules.TIMBER, 1, WOODS, 4)), &"GEN")
	assert_eq(summer["text"], "Begun: timber, first stage, %s. Ready Autumn 1481." % Words.place(_g, WOODS))


func test_cancelled_by_order_by_loss_and_by_block() -> void:
	var w := _work(Works.UPGRADE, ImproveRules.SETTLEMENT, 5, GENOA, 8)
	var order := LogLines.line_of(_g, _emit("work_cancelled", w, {"why": &"order", "reason": "", "refund": 0}), &"GEN")
	assert_eq(order["text"], "Cancelled: walled town to city, Genoa (8, 13).")
	assert_eq([order["keyword"], order["tone"], order["floating"], order["notify"]], ["Cancelled", "bad", "Cancelled", false])
	var lost := LogLines.line_of(_g, _emit("work_cancelled", w, {"why": &"lost", "reason": "not your land", "refund": 0}), &"GEN")
	assert_eq(lost["text"], "Cancelled: walled town to city, Genoa (8, 13), the land was lost.")
	assert_true(lost["notify"])
	var blocked := LogLines.line_of(_g, _emit("work_cancelled", w, {"why": &"blocked", "reason": "something already stands here",
		"refund": 0}), &"GEN")
	assert_eq(blocked["text"], "Cancelled: walled town to city, Genoa (8, 13): something already stands here.")
	assert_true(blocked["notify"])


func test_a_known_others_lines_and_an_unknown_other_is_nothing() -> void:
	var other := _known()
	var who := LogLines.short_name(_g, other)
	var done := _emit("work_finished", _work(Works.BUILD, ImproveRules.VINEYARD, 1, WOODS, 4, other))
	var line := LogLines.line_of(_g, done, &"GEN")
	assert_eq(line["text"], "%s finished a vineyard at (9, 11)." % who)
	assert_eq([line["keyword"], line["tone"], line["floating"], line["mine"], line["notify"]],
		["Built", "muted", "Built", false, false])
	assert_eq(line["filters"], [&"all", &"works"] as Array[StringName])
	var begun := LogLines.line_of(_g, _emit("work_started", _work(Works.BUILD, ImproveRules.TIMBER, 1, WOODS, 4, other)), &"GEN")
	assert_eq(begun["text"], "%s began work on a woodland at (9, 11)." % who)
	assert_eq(begun["floating"], "")
	var stopped := LogLines.line_of(_g, _emit("work_cancelled", _work(Works.UPGRADE, ImproveRules.SETTLEMENT, 3, WOODS, 8, other),
		{"why": &"order", "reason": "", "refund": 0}), &"GEN")
	assert_eq(stopped["text"], "%s cancelled work on a town at (9, 11)." % who)
	var cleared := LogLines.line_of(_g, _emit("work_finished", _work(Works.CLEAR, ImproveRules.OLIVES, 0, WOODS, 1, other)), &"GEN")
	assert_eq(cleared["text"], "%s cleared an olive grove at (9, 11)." % who)
	assert_eq([cleared["keyword"], cleared["floating"]], ["Cleared", "Cleared"], "a clearing is not Built")
	var pans := LogLines.line_of(_g, _emit("work_finished", _work(Works.BUILD, ImproveRules.SALT, 1, WOODS, 4, other)), &"GEN")
	assert_eq(pans["text"], "%s finished salt pans at (9, 11)." % who, "no article before salt pans")
	var stranger := _stranger()
	assert_ne(stranger, &"", "the scenario has a country Genoa does not know")
	var far := _emit("work_finished", _work(Works.BUILD, ImproveRules.VINEYARD, 1, WOODS, 4, stranger))
	assert_eq(LogLines.line_of(_g, far, &"GEN"), {}, "P: an unwitnessed event is no line")
	assert_false(LogLines.line_of(_g, far, &"").is_empty(), "the viewer of everything sees it")


func test_land_lines() -> void:
	var other := _known()
	var hexes: Array[Vector2i] = [Vector2i(11, 8), Vector2i(11, 9), Vector2i(12, 9)]
	var long_other := Words.country_the(_g, other)
	var spots := "%s and 2 more" % Words.place(_g, hexes[0])
	_g.emit({"kind": "owners_changed", "hexes": hexes, "tag": &"GEN", "others": [other]})
	var gained := LogLines.line_of(_g, _g.chronicle.entries.back(), &"GEN")
	assert_eq(gained["text"], "Took 3 districts from %s: %s." % [long_other, spots])
	assert_eq([gained["keyword"], gained["tone"], gained["floating"], gained["notify"], gained["mine"]],
		["Gained", "good", "Gained", true, true])
	assert_eq(gained["hex"], hexes[0])
	_g.emit({"kind": "owners_changed", "hexes": hexes, "tag": other, "others": [&"GEN"]})
	var lost := LogLines.line_of(_g, _g.chronicle.entries.back(), &"GEN")
	assert_eq(lost["text"], "Lost 3 districts to %s: %s." % [long_other, spots])
	assert_eq([lost["keyword"], lost["tone"], lost["floating"], lost["notify"], lost["mine"]],
		["Lost", "bad", "Lost", true, true])
	var third := _stranger()
	_g.emit({"kind": "owners_changed", "hexes": hexes, "tag": other, "others": [third]})
	var taken := LogLines.line_of(_g, _g.chronicle.entries.back(), &"")
	assert_eq(taken["text"], "%s took 3 districts from %s: %s." % [LogLines.capital(long_other), Words.country_the(_g, third), spots])
	assert_eq([taken["keyword"], taken["tone"], taken["floating"], taken["notify"], taken["mine"]],
		["Taken", "muted", "Taken", false, false])


func test_a_victim_the_viewer_does_not_know_is_not_named() -> void:
	var other := _known()
	var third := _stranger()
	var hexes: Array[Vector2i] = [Vector2i(11, 8)]
	_g.emit({"kind": "owners_changed", "hexes": hexes, "tag": other, "others": [third]})
	var taken := LogLines.line_of(_g, _g.chronicle.entries.back(), &"GEN")
	assert_eq(taken["text"], "%s took 1 district from another country: %s." % [LogLines.capital(Words.country_the(_g, other)),
		Words.place(_g, hexes[0])])
	_g.emit({"kind": "owners_changed", "hexes": hexes, "tag": &"GEN", "others": [third]})
	assert_string_contains(str(LogLines.line_of(_g, _g.chronicle.entries.back(), &"GEN")["text"]), "from another country")
	_g.emit({"kind": "owners_changed", "hexes": hexes, "tag": &"", "others": [third]})
	assert_string_starts_with(str(LogLines.line_of(_g, _g.chronicle.entries.back(), &"")["text"]),
		"%s lost 1 district" % LogLines.capital(Words.country_the(_g, third)))


func test_land_nobody_gave_and_nobody_got_is_no_line() -> void:
	_g.emit({"kind": "owners_changed", "hexes": [Vector2i(11, 8)] as Array[Vector2i], "tag": &"", "others": []})
	assert_eq(LogLines.line_of(_g, _g.chronicle.entries.back(), &""), {}, "no line with a leading space")


func test_cached_results_are_copies() -> void:
	_emit("work_started", _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4))
	_g.turn = 2
	_g.version += 1
	var first := LogLines.entries(_g, &"GEN", &"all")
	var text := str(((first[0]["lines"] as Array)[0] as Dictionary)["text"])
	((first[0]["lines"] as Array)[0] as Dictionary)["text"] = "changed"
	first[0]["title"] = "changed"
	first.clear()
	var again := LogLines.entries(_g, &"GEN", &"all")
	assert_eq(str(((again[0]["lines"] as Array)[0] as Dictionary)["text"]), text, "mutating a result leaves the next call alone")
	assert_ne(again[0]["title"], "changed")


func test_a_full_season_is_not_read_beyond_its_cap() -> void:
	for n: int in 3000:
		_emit("work_started", _work(Works.BUILD, ImproveRules.VINEYARD, 1, Vector2i(n % 30, 5), 4))
	_g.turn = 2
	_g.version += 1
	var start := Time.get_ticks_usec()
	var seasons := LogLines.entries(_g, &"GEN", &"all")
	gut.p("one season of 3,000 entries: %.2f ms" % ((Time.get_ticks_usec() - start) / 1000.0))
	assert_eq(seasons.size(), 1)
	assert_eq((seasons[0]["lines"] as Array).size(), LogLines.PER_SEASON)


func test_the_choice_of_a_country() -> void:
	var line := LogLines.line_of(_g, _g.chronicle.entries[0], &"GEN")
	assert_eq(line["text"], "Took the rule of the Republic of Genoa.")
	assert_eq([line["keyword"], line["tone"], line["mine"]], ["Rule", "plain", true])
	assert_eq(line["hex"], Countries.by_tag(_g, &"GEN").capital)
	assert_eq(line["filters"], [&"all", &"mine"] as Array[StringName])
	var other := _known()
	_g.emit({"kind": "country_chosen", "tag": other})
	assert_eq(LogLines.line_of(_g, _g.chronicle.entries.back(), &"GEN")["text"],
		"%s passed to a new ruler." % LogLines.capital(Words.country_the(_g, other)))


func test_entries_newest_season_first_and_eight_seasons() -> void:
	for t: int in range(1, 13):
		_g.turn = t
		_emit("work_started", _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4))
	_g.turn = 13
	_g.version += 1
	var seasons := LogLines.entries(_g, &"GEN", &"all")
	assert_eq(seasons.size(), LogLines.SEASONS_SHOWN)
	assert_eq(seasons[0]["turn"], 12)
	assert_eq(seasons[0]["title"], "Winter 1482")
	assert_eq(seasons[7]["turn"], 5)
	assert_eq((seasons[0]["lines"] as Array).size(), 1)


func test_sixty_lines_a_season_newest_first() -> void:
	for n: int in 70:
		_emit("work_started", _work(Works.BUILD, ImproveRules.VINEYARD, 1, Vector2i(n % 20, 3), 4))
	_g.turn = 2
	_g.version += 1
	var seasons := LogLines.entries(_g, &"GEN", &"all")
	assert_eq(seasons.size(), 1)
	var lines := seasons[0]["lines"] as Array
	assert_eq(lines.size(), LogLines.PER_SEASON)
	assert_eq((lines[0] as Dictionary)["hex"], Vector2i(69 % 20, 3), "the newest line first")


func test_the_filters() -> void:
	_emit("work_started", _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4))
	_emit("work_finished", _work(Works.BUILD, ImproveRules.VINEYARD, 1, WOODS, 4, _known()))
	_g.turn = 2
	_g.version += 1
	assert_eq(_count(LogLines.entries(_g, &"GEN", &"all")), 3, "the choice, the begun work, the other's finish")
	assert_eq(_count(LogLines.entries(_g, &"GEN", &"works")), 2)
	assert_eq(_count(LogLines.entries(_g, &"GEN", &"mine")), 2)
	assert_eq(_count(LogLines.entries(_g, &"GEN", &"money")), 0, "money arrives with M4")
	assert_eq(_count(LogLines.entries(_g, &"GEN", &"war")), 0, "war arrives with M7")
	assert_eq(_count(LogLines.entries(_g, &"GEN", &"nonsense")), 0)
	var since: Array[String] = []
	for f: Dictionary in LogLines.FILTERS:
		since.append("%s@%s" % [f["id"], f["since"]])
	assert_eq(since, ["all@3", "works@3", "mine@3", "money@4", "war@7"] as Array[String])


func _count(seasons: Array[Dictionary]) -> int:
	var n := 0
	for s: Dictionary in seasons:
		n += (s["lines"] as Array).size()
	return n


func test_lines_are_equal_after_a_save_and_load() -> void:
	_emit("work_started", _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4))
	_g.emit({"kind": "owners_changed", "hexes": [Vector2i(11, 8)], "tag": &"GEN", "others": [_known()]})
	_g.turn = 3
	_g.version += 1
	var before := LogLines.entries(_g, &"GEN", &"all")
	assert_gt(_count(before), 2)
	var back := _round_trip(_g)
	assert_not_null(back)
	assert_eq(LogLines.entries(back, &"GEN", &"all"), before)


func test_the_whole_chronicle_is_read_quickly() -> void:
	var known := _known()
	for n: int in 3000:
		_g.turn = 1 + floori(n / 20.0)
		_emit("work_started", _work(Works.BUILD, ImproveRules.VINEYARD, 1, Vector2i(n % 30, 5), 4, known if n % 2 == 0 else &"GEN"))
	_g.turn = 200
	_g.version += 1
	var start := Time.get_ticks_usec()
	var seasons := LogLines.entries(_g, &"GEN", &"all")
	var ms := (Time.get_ticks_usec() - start) / 1000.0
	assert_eq(seasons.size(), LogLines.SEASONS_SHOWN)
	gut.p("LogLines.entries over 3,000 entries: %.2f ms (Y17 measures)" % ms)


func _round_trip(game: Game) -> Game:
	var dir := "user://test_log_lines_%d/" % Time.get_ticks_usec()
	assert_eq(SaveFile.write(game, "1", {"saved_unix": 1}, {}, dir), "")
	var read := SaveFile.read("1", dir)
	assert_eq(read["problem"], "")
	var restored := Snapshot.restore(read["body"] as Dictionary, game.map, game.defs)
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	DirAccess.remove_absolute(dir)
	return restored["game"] as Game
