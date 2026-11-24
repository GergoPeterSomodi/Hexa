## LogLines' rules for what others did (docs/architecture/m8-build-spec.md 4.14, D39): the viewer's lines first, at most
## OTHERS_PER_SEASON of others' with one muted "more" line, and another's raise notifies only at war with the viewer or within
## NOTIFY_RANGE of the viewer's land. Split from test_log_lines.gd to keep both under the size limit.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"
const SAVONA := Vector2i(7, 12)

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


# ----- M8 (m8-build-spec.md 4.14, D39): what others did in the log ---------------------------------------------------

## A raise of `tag` at `hex` in this season, from the real producer's event shape (Military.raise_check's army_raised).
func _raise(tag: StringName, hex: Vector2i) -> Dictionary:
	_g.emit({"kind": "army_raised", "tag": tag, "hex": hex, "army": 1, "units": [], "kind_id": 0, "count": 2,
		"men": 1000, "ducats": 0, "goods": {}, "name": "Army", "witnesses": ["GEN", String(tag)]})
	return _g.chronicle.entries[_g.chronicle.entries.size() - 1]


## The first land hex at least NOTIFY_RANGE + 1 from every district of Genoa (or (-1, -1)).
func _far_from_genoa() -> Vector2i:
	var mine := Territory.districts(_g, Countries.by_tag(_g, &"GEN").id)
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if not _g.map.is_land(hex):
			continue
		var near := false
		for d: int in mine:
			if ImproveRules.hex_distance(hex, _g.map.hex_of(d)) <= LogLines.NOTIFY_RANGE:
				near = true
				break
		if not near:
			return hex
	return Vector2i(-1, -1)


func test_others_are_capped_a_season_and_the_rest_counted() -> void:
	var known := _known()
	var own := _emit("work_started", _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4))  # the viewer's, first in time
	var others := LogLines.OTHERS_PER_SEASON + 6
	for k: int in others:
		_emit("work_finished", _work(Works.BUILD, ImproveRules.VINEYARD, 1, Vector2i(k % 20, 3 + k % 9), 4, known),
			{"witnesses": ["GEN", String(known)]})
	assert_false(LogLines.line_of(_g, own, &"GEN").is_empty(), "the viewer's own line exists")
	var seasons := LogLines.entries(_g, &"GEN", &"all")
	assert_eq(seasons.size(), 1, "one season")
	var lines: Array = seasons[0]["lines"]
	# The choice of Genoa is the viewer's line of the same season too (the game emits it).
	assert_eq(lines.size(), _mine_count(lines) + LogLines.OTHERS_PER_SEASON + 1, "the viewer's lines, 24 of others, the more line")
	assert_eq(_mine_count(lines), 2, "the choice and the viewer's own work")
	assert_true(bool(lines[0]["mine"]), "the viewer's lines come first, though the others are newer")
	assert_eq(_others_count(lines), LogLines.OTHERS_PER_SEASON, "24 of others")
	var more: Dictionary = lines[lines.size() - 1]
	assert_eq(str(more["text"]), "and 6 more about other countries", "the count of the others the cap leaves out")
	assert_eq(more["hex"], WorksView.NO_HEX, "the more line has no link")
	assert_eq(more["tone"], "muted", "the more line is muted")


func test_exactly_the_cap_of_others_has_no_more_line() -> void:
	var known := _known()
	for k: int in LogLines.OTHERS_PER_SEASON:
		_emit("work_finished", _work(Works.BUILD, ImproveRules.VINEYARD, 1, Vector2i(k % 20, 3 + k % 9), 4, known),
			{"witnesses": ["GEN", String(known)]})
	var lines: Array = LogLines.entries(_g, &"GEN", &"all")[0]["lines"]
	assert_eq(_others_count(lines), LogLines.OTHERS_PER_SEASON, "24 others")
	for line: Dictionary in lines:
		assert_ne(str(line["text"]).begins_with("and "), true, "P: no more line at the cap")


func _mine_count(lines: Array) -> int:
	var n := 0
	for line: Dictionary in lines:
		if bool(line["mine"]):
			n += 1
	return n


func _others_count(lines: Array) -> int:
	var n := 0
	for line: Dictionary in lines:
		if not bool(line["mine"]) and str(line["text"]) != "" and not str(line["text"]).begins_with("and "):
			n += 1
	return n


func test_a_raise_near_the_viewer_notifies_and_a_far_one_at_peace_does_not() -> void:
	var near_hex := _g.map.hex_of(Territory.districts(_g, Countries.by_tag(_g, &"GEN").id)[0])
	var other := _known()
	assert_true(bool(LogLines.line_of(_g, _raise(other, near_hex), &"GEN")["notify"]), "a raise within the range notifies")
	var far := _far_from_genoa()
	assert_ne(far, Vector2i(-1, -1), "a land hex far from Genoa")
	assert_false(Wars.at_war(_g, other, &"GEN"), "the other is at peace with Genoa")
	assert_false(bool(LogLines.line_of(_g, _raise(other, far), &"GEN")["notify"]), "P: a far raise at peace does not notify")


func test_a_far_raise_by_a_country_at_war_notifies() -> void:
	var far := _far_from_genoa()
	var enemy := _known()
	WarFixture.at_war(_g, enemy, &"GEN")
	assert_true(bool(LogLines.line_of(_g, _raise(enemy, far), &"GEN")["notify"]), "a country at war with the viewer notifies from anywhere")



## A capture between two others (owners_changed, a land event: fog build R10, R29, R30) is told to Genoa by the hexes Genoa has
## discovered, and names only those: a hex it has not discovered is never named (a planted fault would name both).
func test_a_capture_between_others_names_only_the_hexes_the_viewer_discovered() -> void:
	FogFixture.thin(_g, &"GEN", 0)  # Genoa keeps its land sight: Savona is its, the far hex is not discovered
	var far := _far_from_genoa()
	assert_ne(far, Vector2i(-1, -1), "a land hex far from Genoa")
	assert_true(Knowledge.discovered(_g, &"GEN", SAVONA), "precondition: Genoa discovered Savona")
	assert_false(Knowledge.discovered(_g, &"GEN", far), "precondition: Genoa has not discovered the far hex")
	_g.emit({"kind": "owners_changed", "tag": &"SAV", "others": [&"MLO"], "hexes": [SAVONA, far]})
	var entry := _g.chronicle.entries[_g.chronicle.entries.size() - 1]
	var line := LogLines.line_of(_g, entry, &"GEN")
	assert_false(line.is_empty(), "Genoa is told of a capture on a hex it discovered")
	assert_true(str(line["text"]).contains(Words.place(_g, SAVONA)), str(line["text"]))
	assert_false(str(line["text"]).contains(Words.place(_g, far)), "P: an undiscovered hex is not named: %s" % str(line["text"]))
	assert_false(LogLines.filters_of(_g, entry, &"GEN").is_empty(), "the filters agree with the line")
	# Planted fault: a capture on the far hex alone reaches no line of Genoa's, though Genoa knows the actor's neighbours.
	_g.emit({"kind": "owners_changed", "tag": &"SAV", "others": [&"MLO"], "hexes": [far]})
	var alone := _g.chronicle.entries[_g.chronicle.entries.size() - 1]
	assert_true(LogLines.line_of(_g, alone, &"GEN").is_empty(), "P: no discovered hex, no line")
	assert_true(LogLines.filters_of(_g, alone, &"GEN").is_empty(), "and no filter")
