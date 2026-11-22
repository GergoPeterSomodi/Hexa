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


## The first land hex the viewer Genoa does not see, or (-1, -1).
func _unseen_hex() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if _g.map.is_land(hex) and not Sight.sees(_g, &"GEN", hex):
			return hex
	return Vector2i(-1, -1)


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
	# A hex Genoa does not see (M6 4.11: witnesses are the countries whose sight holds the hex when it is made).
	var far_hex := _unseen_hex()
	assert_ne(far_hex, Vector2i(-1, -1), "a land hex Genoa does not see")
	var far := _emit("work_finished", _work(Works.BUILD, ImproveRules.VINEYARD, 1, far_hex, 4, stranger))
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
	assert_eq(_count(LogLines.entries(_g, &"GEN", &"money")), 0, "no money lines yet")
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


func _short(tag: StringName, good: StringName, need: int, taken: int) -> Dictionary:
	_g.emit({"kind": "goods_short", "tag": tag, "good": good, "need": need, "taken": taken, "witnesses": [tag]})
	return _g.chronicle.entries[_g.chronicle.entries.size() - 1]


func _tax(tag: StringName, level: int) -> Dictionary:
	_g.emit({"kind": "tax_set", "tag": tag, "level": level, "from": 1})
	return _g.chronicle.entries[_g.chronicle.entries.size() - 1]


func test_goods_short_is_the_owners_line() -> void:
	var line := LogLines.line_of(_g, _short(&"GEN", &"salt", 1, 0), &"GEN")
	assert_eq(line["text"], "Your towns ran short of salt: 0 of 1.")
	assert_eq([line["keyword"], line["tone"], line["notify"], line["mine"]], ["Short", "bad", true, true])
	assert_eq(line["filters"], [&"all", &"mine", &"money"] as Array[StringName])
	assert_eq(line["hex"], Countries.by_tag(_g, &"GEN").capital)


func test_goods_short_is_never_witnessed_by_others() -> void:
	var entry := _short(&"GEN", &"wine", 4, 1)
	assert_eq(LogLines.line_of(_g, entry, _known()), {}, "a known country hears nothing")
	var stranger := _stranger()
	if stranger != &"":
		assert_eq(LogLines.line_of(_g, entry, stranger), {})
	var others := _short(_known(), &"oil", 2, 0)
	assert_eq(LogLines.line_of(_g, others, &"GEN"), {}, "nor does the player hear of a known country's shortage")


func test_tax_set_lines() -> void:
	var mine := LogLines.line_of(_g, _tax(&"GEN", 2), &"GEN")
	assert_eq(mine["text"], "You set taxes to High.")
	assert_eq([mine["keyword"], mine["tone"], mine["notify"]], ["Taxes", "plain", false])
	assert_eq(mine["filters"], [&"all", &"mine", &"money"] as Array[StringName])
	var other := _known()
	var theirs := LogLines.line_of(_g, _tax(other, 2), &"GEN")
	assert_eq(theirs["text"], "%s set taxes to High." % LogLines.short_name(_g, other))
	assert_eq(theirs["tone"], "muted")
	assert_eq(theirs["filters"], [&"all", &"money"] as Array[StringName], "not in Mine")
	var stranger := _stranger()
	if stranger != &"":
		assert_eq(LogLines.line_of(_g, _tax(stranger, 0), &"GEN"), {}, "an unknown country's change is not told")


func test_the_money_filter_shows_money_lines_only() -> void:
	_emit("work_started", _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4))
	_short(&"GEN", &"salt", 1, 0)
	_tax(&"GEN", 0)
	_tax(_known(), 2)
	_g.turn = 2
	_g.version += 1
	assert_eq(_count(LogLines.entries(_g, &"GEN", &"money")), 3, "a free work is not a money line")
	assert_eq(_count(LogLines.entries(_g, &"GEN", &"mine")), 4)
	var lines := LogLines.entries(_g, &"GEN", &"money")[0]["lines"] as Array
	assert_eq((lines[0] as Dictionary)["text"], "%s set taxes to High." % LogLines.short_name(_g, _known()), "newest first")
	var other_view := LogLines.entries(_g, _known(), &"money")
	for season: Dictionary in other_view:
		for l: Dictionary in season["lines"]:
			assert_false(str(l["text"]).begins_with("Your towns ran short"), "never the shortage")


func test_work_lines_carry_their_ducats() -> void:
	var paid := _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4)
	paid.paid = 40
	var started := LogLines.line_of(_g, _emit("work_started", paid), &"GEN")
	assert_eq(started["text"], "Begun: vineyard, first stage, near Savona (7, 12). Ready Spring 1481. (\u221240 ducats)")
	assert_eq(started["floating"], "Begun \u221240")
	assert_true((started["filters"] as Array).has(&"money"))
	var cancelled := LogLines.line_of(_g, _emit("work_cancelled", paid, {"why": &"order", "reason": "", "refund": 40}), &"GEN")
	assert_eq(cancelled["text"], "Cancelled: vineyard, first stage, near Savona (7, 12). (+40 ducats back)")
	assert_true((cancelled["filters"] as Array).has(&"money"))
	var lost := LogLines.line_of(_g, _emit("work_cancelled", paid, {"why": &"lost", "reason": "", "refund": 0}), &"GEN")
	assert_false((lost["filters"] as Array).has(&"money"), "nothing came back")
	var other := _work(Works.BUILD, ImproveRules.VINEYARD, 1, WOODS, 4, _known())
	other.paid = 40
	var theirs := LogLines.line_of(_g, _emit("work_started", other), &"GEN")
	assert_false(str(theirs["text"]).contains("ducats"), "another country's price is not told")
	assert_false((theirs["filters"] as Array).has(&"money"))


func test_money_lines_are_equal_after_a_save_and_load() -> void:
	_short(&"GEN", &"salt", 1, 0)
	_tax(&"GEN", 2)
	_g.turn = 3
	_g.version += 1
	var before := LogLines.entries(_g, &"GEN", &"money")
	assert_eq(_count(before), 2)
	var back := _round_trip(_g)
	assert_not_null(back)
	assert_eq(LogLines.entries(back, &"GEN", &"money"), before)


func test_filters_of_equals_the_lines_filters_for_every_kind_and_viewer() -> void:
	var known := _known()
	var stranger := _stranger()
	var paid := _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4)
	paid.paid = 40
	var entries: Array[Dictionary] = []
	for tag: StringName in [&"GEN", known, stranger]:
		var by := _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4, tag)
		entries.append_array([_emit("work_started", by), _emit("work_finished", by),
			_emit("work_cancelled", by, {"why": &"order", "reason": "", "refund": 0}),
			_emit("work_cancelled", by, {"why": &"lost", "reason": "", "refund": 0}),
			_emit("work_cancelled", by, {"why": &"order", "reason": "", "refund": 12})])
		_g.emit({"kind": "goods_short", "tag": tag, "good": "Salt", "need": 1, "taken": 0, "witnesses": [tag]})
		_g.emit({"kind": "tax_set", "tag": tag, "level": 2})
		_g.emit({"kind": "tax_set", "tag": tag, "level": 9})
		_g.emit({"kind": "country_chosen", "tag": tag})
		_g.emit({"kind": "owners_changed", "hexes": [Vector2i(11, 8)], "tag": tag, "others": [&"GEN"]})
		_g.emit({"kind": "owners_changed", "hexes": [Vector2i(11, 8)], "tag": &"GEN", "others": [tag]})
		_g.emit({"kind": "owners_changed", "hexes": [], "tag": tag, "others": [&"GEN"]})
	entries.append(_emit("work_started", paid))
	_g.emit({"kind": "owners_changed", "hexes": [Vector2i(11, 8)], "tag": &"", "others": []})
	_g.emit({"kind": "work_started", "tag": &"GEN", "hex": SAVONA, "work": {"schema": "bad"}})
	_g.emit({"kind": "country_chosen", "tag": &""})
	_g.emit({"kind": "nonsense", "tag": &"GEN"})
	var count := 0
	var empty := 0
	for entry: Dictionary in _g.chronicle.entries:
		for viewer: StringName in [&"GEN", known, stranger, &""]:
			var line := LogLines.line_of(_g, entry, viewer)
			var filters := LogLines.filters_of(_g, entry, viewer)
			if line.is_empty():
				assert_eq(filters, [] as Array[StringName], "no line, no filters: %s for %s" % [entry["kind"], viewer])
				empty += 1
			else:
				assert_eq(filters, line["filters"], "%s for %s" % [entry["kind"], viewer])
				assert_false(filters.is_empty())
			count += 1
	assert_gt(count, 100)
	assert_gt(empty, 10, "the cases with no line were reached")


func test_filters_of_gives_nothing_for_an_unwitnessed_entry() -> void:
	# A hex Genoa does not see: nobody but the stranger holds the event (M6 4.11).
	var entry := _emit("work_started", _work(Works.BUILD, ImproveRules.VINEYARD, 1, _unseen_hex(), 4, _stranger()))
	assert_eq(LogLines.filters_of(_g, entry, &"GEN"), [] as Array[StringName])
	assert_ne(LogLines.filters_of(_g, entry, &""), [] as Array[StringName], "the sandbox is told everything")
	var short := {"kind": "goods_short", "tag": _known(), "good": "Salt", "need": 1, "taken": 0, "witnesses": [&"GEN"]}
	_g.emit(short)
	assert_eq(LogLines.filters_of(_g, _g.chronicle.entries[_g.chronicle.entries.size() - 1], &"GEN"), [] as Array[StringName],
		"another country's shortage is nobody else's line")


func test_seen_equals_knowledge_witnessed() -> void:
	var known := _known()
	var stranger := _stranger()
	var parties: Array[StringName] = [&"GEN", known, stranger, &""]
	var entries: Array[Dictionary] = []
	for tag: StringName in parties:
		entries.append({"kind": "tax_set", "tag": tag, "level": 1})
		entries.append({"kind": "tax_set", "tag": tag, "level": 1, "others": [&"GEN"]})
		entries.append({"kind": "tax_set", "tag": tag, "level": 1, "others": PackedStringArray([String(known)])})
		entries.append({"kind": "tax_set", "tag": tag, "level": 1, "witnesses": [&"GEN"]})
		entries.append({"kind": "tax_set", "tag": tag, "level": 1, "witnesses": PackedStringArray([String(stranger)])})
		entries.append({"kind": "tax_set", "tag": tag, "level": 1, "others": "GEN", "witnesses": 3})
	var checked := 0
	for viewer: StringName in parties:
		var memo := {}
		for e: Dictionary in entries:
			assert_eq(LogLines._seen(_g, e, viewer, memo), Knowledge.witnessed(_g, e, viewer), "%s sees %s" % [viewer, e])
			checked += 1
	assert_gt(checked, 80)


func test_the_work_checks_agree_with_work_from_dict() -> void:
	var good := _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4).to_dict()
	var variants: Array[Dictionary] = [good]
	for key: String in good.keys():
		var gone := good.duplicate(true)
		gone.erase(key)
		variants.append(gone)
		var wrong := good.duplicate(true)
		wrong[key] = "x"
		variants.append(wrong)
		var floaty := good.duplicate(true)
		floaty[key] = 2.5
		variants.append(floaty)
	var old := good.duplicate(true)
	old["schema"] = Work.SCHEMA_V1
	old.erase("paid_goods")
	variants.append(old)
	var odd := good.duplicate(true)
	odd["schema"] = "other"
	variants.append(odd)
	var act := good.duplicate(true)
	act["action"] = "teleport"
	variants.append(act)
	var vec := good.duplicate(true)
	vec["hex"] = SAVONA
	variants.append(vec)
	var long := good.duplicate(true)
	long["hex"] = [1, 2, 3]
	variants.append(long)
	var neg := good.duplicate(true)
	neg["paid_goods"] = {"Salt": -1}
	variants.append(neg)
	for v: Dictionary in variants:
		var entry := {"kind": "work_started", "tag": &"GEN", "work": v}
		assert_eq(LogLines._describable(entry, &"GEN"), Work.from_dict(v) != null, str(v))
		assert_eq(LogLines.line_of(_g, entry, &"GEN").is_empty(), Work.from_dict(v) == null, str(v))


func _settle(kind: String, tag: StringName, hex: Vector2i, level: int, from: int, why: StringName = &"") -> Dictionary:
	var event := {"kind": kind, "tag": tag, "hex": hex, "level": level, "from": from, "people": 4000}
	if kind == "district_declined":
		event["family"] = 1
		event["why"] = why
	_g.emit(event)
	return _g.chronicle.entries.back()


func test_people_lines_for_the_player() -> void:
	var grew := LogLines.line_of(_g, _settle("town_grew", &"GEN", Vector2i(6, 13), 3, 2), &"GEN")
	assert_eq(grew["text"], "Savona (6, 13) grew into a town.")
	assert_eq([grew["keyword"], grew["tone"], grew["floating"], grew["notify"], grew["mine"]], ["Grew", "good", "Grew", true, true])
	assert_eq(grew["hex"], Vector2i(6, 13))
	assert_eq(grew["filters"], [&"all", &"mine"] as Array[StringName])
	var fell := LogLines.line_of(_g, _settle("district_declined", &"GEN", Vector2i(6, 13), 2, 3, &"hunger"), &"GEN")
	assert_eq(fell["text"], "Savona (6, 13) fell to a village: hunger.")
	assert_eq([fell["keyword"], fell["tone"], fell["floating"], fell["notify"]], ["Declined", "bad", "Declined", true])
	var few := LogLines.line_of(_g, _settle("district_declined", &"GEN", Vector2i(6, 13), 1, 2, &"people"), &"GEN")
	assert_eq(few["text"], "Savona (6, 13) fell to a hamlet: too few people.")
	var unnamed := LogLines.line_of(_g, _settle("town_grew", &"GEN", Vector2i(7, 12), 3, 2), &"GEN")
	assert_eq(unnamed["text"], "the village near Savona (7, 12) grew into a town.")
	assert_eq(LogLines.line_of(_g, _settle("district_declined", &"GEN", Vector2i(6, 13), 2, 3, &"sacked"), &"GEN"), {},
		"P: a reason the log does not know")
	assert_eq(LogLines.line_of(_g, _settle("town_grew", &"GEN", Vector2i(6, 13), 9, 2), &"GEN"), {}, "P: a level past the words")
	var sacked := _settle("district_declined", &"GEN", Vector2i(6, 13), 2, 3, &"sacked")
	assert_eq(LogLines.filters_of(_g, sacked, &"GEN"), [] as Array[StringName], "P: no line, so no filters (History counts none)")


func test_people_lines_for_a_known_and_an_unknown_other() -> void:
	var other := _known()
	var who := LogLines.short_name(_g, other)
	var grew := LogLines.line_of(_g, _settle("town_grew", other, Vector2i(7, 12), 3, 2), &"GEN")
	assert_eq(grew["text"], "%s: the village near Savona (7, 12) grew into a town." % who)
	assert_eq([grew["keyword"], grew["tone"], grew["floating"], grew["notify"], grew["mine"]], ["Grew", "muted", "Grew", false, false])
	assert_eq(grew["filters"], [&"all"] as Array[StringName], "not in Mine")
	var fell := LogLines.line_of(_g, _settle("district_declined", other, Vector2i(6, 13), 2, 3, &"hunger"), &"GEN")
	assert_eq(fell["text"], "%s: Savona (6, 13) fell to a village." % who, "no reason for another's town")
	assert_eq([fell["keyword"], fell["tone"], fell["floating"], fell["notify"]], ["Declined", "muted", "Declined", false])
	var stranger := _stranger()
	var far := _settle("town_grew", stranger, _unseen_hex(), 3, 2)
	assert_eq(LogLines.line_of(_g, far, &"GEN"), {}, "P: never witnessed")
	assert_eq(LogLines.filters_of(_g, far, &"GEN"), [] as Array[StringName])
	assert_false(LogLines.line_of(_g, far, &"").is_empty(), "the viewer of everything sees it")


# ---- armies (m6-build-spec.md 4.11, L9): raised, disbanded, halted, hungry, lost --------------------------------------

## Emits an army event with its witnesses named; returns the chronicle entry, as a saved game reads it.
func _army(kind: String, extra: Dictionary) -> Dictionary:
	var event := {"kind": kind}
	event.merge(extra)
	_g.emit(event)
	return _g.chronicle.entries[_g.chronicle.entries.size() - 1]


func test_raised_lines_for_the_player_and_a_witnessed_other() -> void:
	var at := Words.at(_g, SAVONA)
	var mine := _army("army_raised", {"tag": &"GEN", "hex": SAVONA, "army": 1, "units": [1, 2], "kind_id": 0,
		"count": 2, "men": 2000, "ducats": 50, "goods": {}, "witnesses": [&"GEN"]})
	var line := LogLines.line_of(_g, mine, &"GEN")
	assert_eq(line["text"], "You raised 2 companies of pikemen %s (−50 ducats)." % at)
	assert_eq([line["keyword"], line["tone"], line["floating"], line["notify"]], ["Raised", "plain", "Raised", false])
	assert_eq(line["filters"], [&"all", &"mine", &"money", &"war"] as Array[StringName])  # M7: army lines join War
	var stranger := _stranger()
	var other := _army("army_raised", {"tag": stranger, "hex": SAVONA, "army": 9, "units": [5], "kind_id": 0,
		"count": 2, "men": 1000, "ducats": 0, "goods": {}, "witnesses": [&"GEN"]})
	var seen := LogLines.line_of(_g, other, &"GEN")
	assert_eq(seen["text"], "An army raised 2 companies %s: about 1,000 men." % at, "a country the viewer does not know is not named")
	assert_eq([seen["keyword"], seen["tone"], seen["notify"], seen["mine"]], ["Raised", "warn", true, false])
	assert_eq(seen["floating"], "", "no ribbon for another's raise")
	assert_eq(seen["filters"], [&"all", &"war"] as Array[StringName], "not in Mine, not in Money; in War (M7)")


func test_disband_lines_name_the_army_and_give_back_the_refund() -> void:
	var mine := _army("army_disbanded", {"tag": &"GEN", "hex": SAVONA, "army": 1, "units": [1], "men": 1000,
		"refund": 25, "name": "Army of Savona", "kind_id": 0, "witnesses": [&"GEN"]})
	var line := LogLines.line_of(_g, mine, &"GEN")
	assert_eq(line["text"], "You disbanded 1 company of pikemen of the Army of Savona (+25 ducats back).")
	assert_eq([line["keyword"], line["tone"], line["notify"]], ["Disbanded", "plain", false])
	assert_true((line["filters"] as Array).has(&"money"), "a refund is money")
	var bare := _army("army_disbanded", {"tag": &"GEN", "hex": SAVONA, "army": 2, "units": [3, 4], "men": 900,
		"refund": 0, "witnesses": [&"GEN"]})
	assert_eq(LogLines.line_of(_g, bare, &"GEN")["text"], "You disbanded 2 companies.", "no name, no kind, no refund")
	var stranger := _stranger()
	var other := _army("army_disbanded", {"tag": stranger, "hex": SAVONA, "army": 9, "units": [7], "men": 500,
		"refund": 0, "witnesses": [&"GEN"]})
	var seen := LogLines.line_of(_g, other, &"GEN")
	assert_eq(seen["text"], "An army disbanded about 500 men %s." % Words.at(_g, SAVONA))
	assert_eq([seen["tone"], seen["filters"]], ["muted", [&"all", &"war"]])


func test_halt_lines_are_the_players_alone() -> void:
	var at := Words.at(_g, SAVONA)
	var winter := _army("march_halted", {"tag": &"GEN", "army": 1, "name": "Army of Savona", "hex": SAVONA,
		"why": "winter", "reason": "Mont Cenis", "waits": true, "witnesses": [&"GEN"]})
	var line := LogLines.line_of(_g, winter, &"GEN")
	assert_eq(line["text"], "The Army of Savona waits for spring %s: the Mont Cenis is closed by snow." % at)
	assert_eq([line["keyword"], line["tone"], line["floating"], line["notify"]], ["Halted", "warn", "Halted", true])
	assert_eq(line["filters"], [&"all", &"mine", &"war"] as Array[StringName])
	var no_way := _army("march_halted", {"tag": &"GEN", "army": 1, "name": "Army of Savona", "hex": SAVONA,
		"why": "no_way", "reason": "no way to Hospice Mont Cenis (3, 8)", "waits": false, "witnesses": [&"GEN"]})
	assert_eq(LogLines.line_of(_g, no_way, &"GEN")["text"],
		"The Army of Savona halted %s: no way to Hospice Mont Cenis (3, 8) by land." % at)
	var blocked := _army("march_halted", {"tag": &"GEN", "army": 2, "hex": SAVONA, "why": "blocked",
		"reason": "an army of Milan is at Susa (4, 9)", "waits": false, "witnesses": [&"GEN"]})
	assert_eq(LogLines.line_of(_g, blocked, &"GEN")["text"],
		"Your army halted %s: an army of Milan is at Susa (4, 9)." % at, "no name: your army")
	var stranger := _stranger()
	var theirs := _army("march_halted", {"tag": stranger, "army": 9, "hex": SAVONA, "why": "winter", "reason": "Mont Cenis",
		"waits": true, "witnesses": [stranger]})
	assert_eq(LogLines.line_of(_g, theirs, &"GEN"), {}, "never witnessed by others")
	assert_eq(LogLines.filters_of(_g, theirs, &"GEN"), [] as Array[StringName])


func test_hunger_lines() -> void:
	var at := Words.at(_g, SAVONA)
	var mine := _army("army_starved", {"tag": &"GEN", "army": 1, "name": "Army of Savona", "hex": SAVONA,
		"lost": 100, "men": 900, "why": "out_of_supply", "witnesses": [&"GEN"]})
	var line := LogLines.line_of(_g, mine, &"GEN")
	assert_eq(line["text"], "The Army of Savona lost 100 men to hunger %s: out of supply." % at)
	assert_eq([line["keyword"], line["tone"], line["floating"], line["notify"]], ["Hunger", "bad", "Hunger −100", true])
	assert_eq(line["filters"], [&"all", &"mine", &"war"] as Array[StringName])
	var stores := _army("army_starved", {"tag": &"GEN", "army": 2, "hex": SAVONA, "lost": 40, "men": 10,
		"why": "stores_empty", "witnesses": [&"GEN"]})
	assert_eq(LogLines.line_of(_g, stores, &"GEN")["text"], "Your army lost 40 men to hunger %s: the stores are empty." % at)
	var stranger := _stranger()
	var other := _army("army_starved", {"tag": stranger, "army": 9, "hex": SAVONA, "lost": 90, "men": 10,
		"why": "out_of_supply", "witnesses": [&"GEN"]})
	var seen := LogLines.line_of(_g, other, &"GEN")
	assert_eq(seen["text"], "An army lost men to hunger %s." % at, "unnamed for a country the viewer does not know")
	assert_eq([seen["tone"], seen["notify"], seen["floating"]], ["muted", false, ""], "no number for another's army")
	var unknown := _army("army_starved", {"tag": &"GEN", "army": 3, "hex": SAVONA, "lost": 5, "men": 5,
		"why": "", "witnesses": [&"GEN"]})
	assert_eq(LogLines.line_of(_g, unknown, &"GEN"), {}, "a loss with no known cause is no line")


func test_unit_lost_lines() -> void:
	var at := Words.at(_g, SAVONA)
	var mine := _army("unit_lost", {"tag": &"GEN", "army": 1, "unit": 1, "kind_id": 0, "name": "Army of Savona",
		"hex": SAVONA, "why": "starved", "army_left": 1, "witnesses": [&"GEN"]})
	var line := LogLines.line_of(_g, mine, &"GEN")
	assert_eq(line["text"], "A company of pikemen of the Army of Savona is gone: starved %s." % at)
	assert_eq([line["keyword"], line["tone"], line["notify"]], ["Lost", "bad", true])
	var bare := _army("unit_lost", {"tag": &"GEN", "army": 2, "unit": 3, "kind_id": 0, "hex": SAVONA, "why": "starved",
		"army_left": 0, "witnesses": [&"GEN"]})
	assert_eq(LogLines.line_of(_g, bare, &"GEN")["text"], "A company of pikemen is gone: starved %s." % at, "no name")
	var stranger := _stranger()
	var other := _army("unit_lost", {"tag": stranger, "army": 9, "unit": 7, "kind_id": 0, "hex": SAVONA,
		"why": "starved", "army_left": 2, "witnesses": [&"GEN"]})
	var seen := LogLines.line_of(_g, other, &"GEN")
	assert_eq(seen["text"], "A company starved %s." % at, "unnamed for a country the viewer does not know")
	assert_eq([seen["tone"], seen["notify"]], ["muted", false])


func test_army_lines_filters_agree_and_reach_the_log() -> void:
	var raised := _army("army_raised", {"tag": &"GEN", "hex": SAVONA, "army": 1, "units": [1], "kind_id": 0,
		"count": 1, "men": 1000, "ducats": 50, "goods": {}, "witnesses": [&"GEN"]})
	var line := LogLines.line_of(_g, raised, &"GEN")
	assert_eq(LogLines.filters_of(_g, raised, &"GEN"), line["filters"], "filters_of equals the line's filters")
	var money := LogLines.entries(_g, &"GEN", &"money")
	assert_eq(money[0]["lines"][0]["text"], line["text"], "the newest money line is the raise")
	var no_hex := _army("army_raised", {"tag": &"GEN", "army": 4, "count": 1, "witnesses": [&"GEN"]})
	assert_eq(LogLines.line_of(_g, no_hex, &"GEN"), {}, "no hex, no line")
	assert_eq(LogLines.filters_of(_g, no_hex, &"GEN"), [] as Array[StringName])


## The newest chronicle entry of one kind, as the log reads it ({} when there is none).
func _last_of(g: Game, kind: String) -> Dictionary:
	for i: int in range(g.chronicle.entries.size() - 1, -1, -1):
		if str(g.chronicle.entries[i].get("kind", "")) == kind:
			return g.chronicle.entries[i]
	return {}


func test_the_live_game_names_the_army_and_the_kind() -> void:
	var g := ArmyFixture.game()
	ArmyFixture.rich(g)
	var town := ArmyFixture.find_town(g)
	ArmyFixture.town(g, town)
	assert_true(bool(g.act("raise", {"hex": town, "kind": 0, "count": 1, "tag": ArmyFixture.TAG})["ok"]))
	var raised := _last_of(g, "army_raised")
	var army := Armies.by_id(g, int(raised["army"]))
	assert_eq(raised["kind_id"], 0, "the raise names its kind")
	assert_eq(raised["name"], army.name, "and its army")
	assert_true(str(LogLines.line_of(g, raised, ArmyFixture.TAG)["text"]).begins_with("You raised 1 company of pikemen "))
	var name := army.name
	assert_true(bool(g.act("disband", {"army": army.id, "unit": army.units[0].id, "tag": ArmyFixture.TAG})["ok"]))
	var gone := _last_of(g, "army_disbanded")
	assert_eq(gone["name"], name, "the disband names the army it left")
	assert_eq(gone["kind_id"], 0, "and its kind")
	assert_true(str(LogLines.line_of(g, gone, ArmyFixture.TAG)["text"]).begins_with(
		"You disbanded 1 company of pikemen of the %s (" % name))
	var lost_army := ArmyFixture.army(g, ArmyFixture.TAG, town, 0, 2)
	var lost_name := lost_army.name
	Armies.lose_men(g, lost_army, lost_army.men(), &"starved")
	var lost := _last_of(g, "unit_lost")
	assert_eq(lost["name"], lost_name, "a company lost still names its army (the army is gone now)")
	assert_eq(LogLines.line_of(g, lost, ArmyFixture.TAG)["text"],
		"A company of pikemen of the %s is gone: starved %s." % [lost_name, Words.at(g, town)])
	var back := _round_trip(g)
	for i: int in g.chronicle.entries.size():
		var entry: Dictionary = g.chronicle.entries[i]
		if str(entry.get("kind", "")).begins_with("army_") or entry.get("kind", "") == "unit_lost":
			assert_eq(LogLines.line_of(back, back.chronicle.entries[i], ArmyFixture.TAG),
				LogLines.line_of(g, entry, ArmyFixture.TAG), "a save and load keeps the line of %s" % entry["kind"])


func test_the_live_halt_and_hunger_name_the_army() -> void:
	var g := ArmyFixture.game()
	var savoy := &"SAV"
	g.turn = 4  # Winter 1480
	var halted := ArmyFixture.army(g, savoy, Vector2i(3, 7), 0, 2, 0)
	Movement.march(g, {"army": halted.id, "goal": Vector2i(3, 8), "tag": savoy})
	MovementPhase.season(g)
	var halt := _last_of(g, "march_halted")
	assert_eq(halt["name"], halted.name, "the halt names the army")
	assert_true(str(LogLines.line_of(g, halt, savoy)["text"]).begins_with("The %s waits for spring " % halted.name))
	var hungry := ArmyFixture.game()
	hungry.turn = 2  # Summer 1480: the snow of (4, 8) feeds no one
	var starving := ArmyFixture.army(hungry, savoy, Vector2i(4, 8), 0, 2, 0)
	Supply.season(hungry)
	var starved := _last_of(hungry, "army_starved")
	assert_false(starved.is_empty(), "out of supply, the army starves")
	assert_eq(starved["name"], starving.name, "the hunger names the army")
	assert_true(str(LogLines.line_of(hungry, starved, savoy)["text"]).begins_with("The %s lost " % starving.name))


func test_a_foreign_army_names_only_a_country_the_viewer_knows() -> void:
	# Two countries GEN witnesses an army of: one it knows (named) and one it does not (unnamed, 4.12).
	var known := _known()
	var unknown := _stranger()
	var at := Words.at(_g, SAVONA)
	for tag: StringName in [known, unknown]:
		var told: StringName = tag if tag == known else &""
		var subject := LogLines.short_name(_g, told) if told != &"" else "An army"
		var raised := _army("army_raised", {"tag": tag, "hex": SAVONA, "army": 1, "units": [1, 2], "kind_id": 0,
			"count": 2, "men": 1000, "ducats": 0, "goods": {}, "witnesses": [&"GEN"]})
		assert_eq(LogLines.line_of(_g, raised, &"GEN")["text"],
			"%s raised 2 companies %s: about 1,000 men." % [subject, at], "raised: %s" % tag)
		var disbanded := _army("army_disbanded", {"tag": tag, "hex": SAVONA, "army": 2, "units": [3], "men": 500,
			"refund": 0, "witnesses": [&"GEN"]})
		assert_eq(LogLines.line_of(_g, disbanded, &"GEN")["text"],
			"%s disbanded about 500 men %s." % [subject, at], "disbanded: %s" % tag)
		var starved := _army("army_starved", {"tag": tag, "army": 3, "hex": SAVONA, "lost": 90, "men": 10,
			"why": "out_of_supply", "witnesses": [&"GEN"]})
		assert_eq(LogLines.line_of(_g, starved, &"GEN")["text"],
			"%s lost men to hunger %s." % [Words.army_of(_g, told), at], "starved: %s" % tag)
		var lost := _army("unit_lost", {"tag": tag, "army": 4, "unit": 7, "kind_id": 0, "hex": SAVONA,
			"why": "starved", "army_left": 2, "witnesses": [&"GEN"]})
		assert_eq(LogLines.line_of(_g, lost, &"GEN")["text"],
			"%s starved %s." % [Words.company_of(_g, told), at], "lost: %s" % tag)
		if tag == unknown:
			for entry: Dictionary in [raised, disbanded, starved, lost]:
				assert_false(str(LogLines.line_of(_g, entry, &"GEN")["text"]).contains(
					LogLines.short_name(_g, unknown)), "the name of an unknown country is not written")
