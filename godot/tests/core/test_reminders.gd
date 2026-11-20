## Reminders (docs/architecture/m3-build-spec.md 4.8, 5.6, 9): `free_slot` (0 of 2: a line; 2 of 2: none; map-only: none),
## `winter_halt` only in Autumn with snow works, worst first, the cache, equal after a save and load.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"
const WOODS := Vector2i(9, 11)
const SAVONA := Vector2i(7, 12)
const AUTUMN := 3

var _g: Game


func before_each() -> void:
	var defs := load(DEFS_PATH) as GameDefs
	_g = Game.new_scenario(load(MAP_PATH) as MapData, defs, defs.scenarios[defs.scenarios.size() - 1], 1480)
	assert_true(bool(_g.act("choose_country", {"tag": &"GEN"})["ok"]))
	_g.improvement.clear(SAVONA)


func _build(hex: Vector2i, family: int) -> bool:
	return bool(_g.act("build", {"hex": hex, "family": family, "tag": &"GEN"})["ok"])


## A Genoese wild hex of snow climate other than WOODS where a timber work may begin.
func _second_snow_hex() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if hex != WOODS and int(_g.map.climate[i]) == 0 and Territory.owner_tag(_g, hex) == &"GEN" \
				and bool(_g.check("build", {"hex": hex, "family": ImproveRules.TIMBER, "tag": &"GEN"})["ok"]):
			return hex
	return WorksView.NO_HEX


func test_a_free_slot() -> void:
	var line := Reminders.free_slot(_g, &"GEN")
	assert_eq(line["text"], "A work slot is free: 0 of 2 in use.")
	assert_eq([line["kind"], line["severity"], line["hint"]], [&"free_slot", 1, ""])
	assert_eq(line["action"], [&"look_at", Countries.by_tag(_g, &"GEN").capital])
	assert_eq(line["action_label"], "Show Genoa")
	assert_true(_build(SAVONA, ImproveRules.VINEYARD))
	assert_eq(Reminders.free_slot(_g, &"GEN")["text"], "A work slot is free: 1 of 2 in use.")
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	assert_eq(Reminders.free_slot(_g, &"GEN"), {}, "2 of 2: no line")


func test_no_free_slot_in_a_map_only_game_or_for_no_country() -> void:
	var sandbox := Game.new_game(_g.map, 1, _g.defs)
	assert_eq(Reminders.free_slot(sandbox, &""), {})
	assert_eq(Reminders.unfinished(sandbox, &""), [] as Array[Dictionary])
	assert_eq(Reminders.free_slot(_g, &"ZZZ"), {}, "no such country")
	assert_eq(Reminders.free_slot(_g, &""), {})


func test_winter_halt_only_in_autumn_with_snow_works() -> void:
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	assert_true(_build(SAVONA, ImproveRules.VINEYARD))
	assert_eq(Reminders.winter_halt(_g, &"GEN"), {}, "Spring")
	for turn: int in [2, 4, 5]:
		_g.turn = turn
		assert_eq(Reminders.winter_halt(_g, &"GEN"), {}, "turn %d is not Autumn" % turn)
	_g.turn = AUTUMN
	var line := Reminders.winter_halt(_g, &"GEN")
	assert_eq(line["text"], "Winter comes: 1 work in the snow stops until spring: timber, first stage, %s." % Words.place(_g, WOODS),
		"the vineyard on frost land is not named")
	assert_eq([line["kind"], line["severity"], line["hint"]], [&"winter_halt", 2, ""])
	assert_eq(line["action"], [&"look_at", WOODS])
	assert_eq(line["action_label"], "Go to (9, 11)")
	assert_eq(line["hex"], WOODS)
	assert_eq(Reminders.winter_halt(_g, &"BBB"), {}, "another country's works are not named")


func test_two_works_in_the_snow_are_listed() -> void:
	var other := _second_snow_hex()
	assert_ne(other, WorksView.NO_HEX, "Genoa has a second snow hex to work")
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	assert_true(_build(other, ImproveRules.TIMBER))
	_g.turn = AUTUMN
	var both := "timber, first stage, %s and timber, first stage, %s" % [Words.place(_g, WOODS), Words.place(_g, other)]
	assert_eq(Reminders.winter_halt(_g, &"GEN")["text"], "Winter comes: 2 works in the snow stop until spring: %s." % both)
	assert_eq(Reminders.winter_halt(_g, &"GEN")["hex"], WOODS, "the first work's hex")


func test_the_defs_switch_turns_the_winter_rule_off() -> void:
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	_g.turn = AUTUMN
	_g.defs.works_halt_in_snow_winter = false
	assert_eq(Reminders.winter_halt(_g, &"GEN"), {})
	_g.defs.works_halt_in_snow_winter = true


func test_worst_first_and_the_cache() -> void:
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	_g.turn = AUTUMN
	_g.version += 1
	var lines := Reminders.unfinished(_g, &"GEN")
	assert_eq(lines.size(), 2)
	assert_eq([lines[0]["kind"], lines[1]["kind"]], [&"winter_halt", &"free_slot"], "severity 2 before 1")
	assert_eq(lines, Reminders.unfinished(_g, &"GEN"), "the cached answer is the same")
	assert_eq(_g.view_cache.size(), 1)
	assert_true(_build(SAVONA, ImproveRules.VINEYARD))
	var after := Reminders.unfinished(_g, &"GEN")
	assert_eq(after.size(), 1, "the slots are full: the version moved, the cache did not serve the old answer")
	assert_eq(after[0]["kind"], &"winter_halt")
	_g.turn = 2
	_g.version += 1
	assert_eq(Reminders.unfinished(_g, &"GEN"), [] as Array[Dictionary], "Summer, no slot free")


func test_cached_lines_are_copies() -> void:
	_g.turn = AUTUMN
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	var first := Reminders.unfinished(_g, &"GEN")
	var text := str(first[0]["text"])
	first[0]["text"] = "changed"
	(first[0]["action"] as Array).clear()
	first.clear()
	var again := Reminders.unfinished(_g, &"GEN")
	assert_eq(again.size(), 2)
	assert_eq(again[0]["text"], text)
	assert_eq((again[0]["action"] as Array).size(), 2)


func test_a_free_slot_alone_is_not_serious() -> void:
	var lines := Reminders.unfinished(_g, &"GEN")
	assert_eq(lines.size(), 1)
	assert_eq(lines[0]["severity"], 1)
	assert_eq(Reminders.RULES, [&"winter_halt", &"free_slot"] as Array[StringName])


func test_reminders_are_equal_after_a_save_and_load() -> void:
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	_g.turn = AUTUMN
	var before := Reminders.unfinished(_g, &"GEN")
	var dir := "user://test_reminders_%d/" % Time.get_ticks_usec()
	assert_eq(SaveFile.write(_g, "1", {"saved_unix": 1}, {}, dir), "")
	var read := SaveFile.read("1", dir)
	var back := Snapshot.restore(read["body"] as Dictionary, _g.map, _g.defs)["game"] as Game
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	DirAccess.remove_absolute(dir)
	assert_not_null(back)
	assert_eq(Reminders.unfinished(back, &"GEN"), before)
