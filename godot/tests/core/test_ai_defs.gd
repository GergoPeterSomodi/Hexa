## AiDef, AiTemperDef and the AI part of GameDefs and ScenarioDef (core/defs/ai_def.gd, ai_temper_def.gd;
## docs/architecture/m8-build-spec.md sections 4.4, 5.1 and 9): data/defs/ai.tres and the five temperaments against the
## spec's numbers, the scenario's 13 assignments, the rows of tools/ai_tables.gd, and planted faults (P). Every planted
## fault works on a copy (a fresh load or a duplicate): a shared cached def would pollute later tests.
extends GutTest

const AiTables := preload("res://tools/ai_tables.gd")
const KEYS: Array[StringName] = [&"builder", &"cautious", &"steadfast", &"aggressive", &"opportunist"]
## Spec 4.4's temperament table: field -> the value of each temperament, in KEYS order.
const TEMPER_TABLE := {
	"reserve_seasons": [6, 12, 8, 4, 6],
	"payback_max": [40, 28, 32, 20, 28],
	"works_at_war": [true, true, true, false, false],
	"army_permille": [3, 5, 6, 9, 6],
	"war_army_permille": [8, 10, 14, 18, 14],
	"army_upkeep_share": [200, 250, 350, 500, 400],
	"max_wars": [1, 1, 1, 2, 2],
	"rest_seasons": [16, 16, 12, 6, 8],
	"war_chest_seasons": [12, 12, 10, 6, 8],
	"declare_ratio": [2500, 2000, 2000, 1200, 1500],
	"busy_bonus": [0, 0, 0, 0, 400],
	"declare_chance": [100, 150, 100, 600, 450],
	"attack_ratio": [1500, 1600, 1300, 1100, 1300],
	"siege_max": [4, 4, 5, 6, 4],
	"storm_share": [600, 700, 500, 400, 500],
	"storm_ratio": [1300, 1500, 1200, 1000, 1200],
	"relief_ratio": [900, 1000, 700, 800, 900],
	"withdraw_ratio": [1100, 1000, 1500, 1800, 1300],
	"take_score": [2, 2, 3, 4, 3],
	"tired_seasons": [8, 8, 16, 24, 12],
	"sue_ratio": [1300, 1200, 2000, 2500, 1500],
	"yield_after": [8, 6, 16, 20, 10],
	"fortify": [false, false, true, false, false],
}
const MIXES: Array = [
	[600, 400, 0, 0], [550, 350, 100, 0], [500, 400, 50, 50], [600, 150, 200, 50], [500, 250, 200, 50],
]
## Spec 4.4's shared table: field -> value.
const SHARED_TABLE := {
	"think_every": 4, "min_upkeep": 10, "min_army_men": 500, "min_war_men": 1000, "threat_permille": 1500,
	"threat_range": 3, "prize_range": 3, "attack_range": 6, "relief_range": 8, "target_range": 12, "relief_last": 600,
	"rest_morale": 600, "switch_permille": 1300, "scan_hexes": 48, "scan_per_step": 24, "works_cards": 4,
	"works_per_season": 2, "raises_peace": 2, "raises_war": 4, "merges_per_season": 4, "order_tries": 2,
	"food_priority": 3000, "walls_priority": 2000, "fortify_priority": 2000, "jitter_permille": 50,
	"disband_surplus": 2000, "peace_order_every": 1, "yield_ratio": 2000,
}
## Spec 4.4 "Who has which": the 13 countries in the scenario's order.
const WHO: Array[StringName] = [
	&"opportunist", &"aggressive", &"aggressive", &"steadfast", &"opportunist", &"aggressive", &"builder", &"builder",
	&"opportunist", &"cautious", &"steadfast", &"cautious", &"builder",
]


func _has(errors: Array[String], fragment: String) -> bool:
	for e: String in errors:
		if e.contains(fragment):
			return true
	return false


func _defs() -> GameDefs:
	return ResourceLoader.load("res://data/defs/game_defs.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs


func _ai() -> AiDef:
	return ResourceLoader.load("res://data/defs/ai.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as AiDef


func _temper(key: StringName) -> AiTemperDef:
	return ResourceLoader.load(
		"res://data/defs/tempers/%s.tres" % String(key), "", ResourceLoader.CACHE_MODE_IGNORE
	) as AiTemperDef


func _map() -> MapData:
	return ResourceLoader.load("res://data/maps/north_italy.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as MapData


## A copy of the 1480 scenario with its own arrays, so a planted change never reaches the committed one.
func _scenario_copy(defs: GameDefs) -> ScenarioDef:
	var s := defs.scenario("north_italy_1480").duplicate() as ScenarioDef
	s.tempers = s.tempers.duplicate()
	s.start_armies = s.start_armies.duplicate(true)
	return s


func test_the_six_files_load_and_validate() -> void:
	var defs := _defs()
	assert_not_null(defs.ai, "GameDefs lists the ai")
	assert_eq(defs.tempers.size(), 5, "five temperaments")
	assert_eq(_ai().validate(), [] as Array[String], "ai.tres validates")
	for key: StringName in KEYS:
		var t := _temper(key)
		assert_not_null(t, "%s loads" % String(key))
		assert_eq(t.validate(defs.units.size()), [] as Array[String], "%s validates" % String(key))
	assert_eq(defs.validate(), [] as Array[String], "committed defs validate with the AI")


func test_tempers_equal_spec_4_4() -> void:
	var defs := _defs()
	for i: int in KEYS.size():
		var t := defs.temper(KEYS[i])
		assert_not_null(t, "temper() finds %s" % String(KEYS[i]))
		assert_eq(defs.tempers[i].key, KEYS[i], "GameDefs lists %s at %d" % [String(KEYS[i]), i])
		assert_eq(t.name, String(KEYS[i]).capitalize(), "the name of %s" % String(KEYS[i]))
		assert_eq(Array(t.mix), MIXES[i], "mix of %s" % String(KEYS[i]))
		for field: String in TEMPER_TABLE:
			assert_eq(t.get(field), (TEMPER_TABLE[field] as Array)[i], "%s of %s" % [field, String(KEYS[i])])
	assert_null(defs.temper(&"gambler"), "an unknown key is null")


func test_ai_numbers_equal_spec_4_4() -> void:
	var a := _ai()
	for field: String in SHARED_TABLE:
		assert_eq(a.get(field), SHARED_TABLE[field], field)
	assert_eq(SHARED_TABLE.size(), 28, "every row of the shared table is pinned")


func test_the_scenarios_thirteen_tempers() -> void:
	var defs := _defs()
	var s := defs.scenario("north_italy_1480")
	assert_eq(s.tempers.size(), 13)
	assert_eq(Array(s.tempers), Array(WHO), "the assignments of spec 4.4")
	assert_eq(s.start_armies.size(), 0, "1480 starts with no armies")
	for i: int in s.countries.size():
		assert_not_null(defs.temper(s.tempers[i]), "%s has a known temper" % String(s.countries[i]))
	assert_eq(s.validate(_map(), defs, true), [] as Array[String], "the scenario validates deep")


func test_ai_tables_rows() -> void:
	var defs := _defs()
	var rows := AiTables.temper_rows(defs)
	assert_eq(rows.size(), 3 + TEMPER_TABLE.size(), "header, rule and a row a field (mix too)")
	assert_eq(rows[0], "| Field | builder | cautious | steadfast | aggressive | opportunist |")
	assert_eq(rows[2], "| `reserve_seasons` | 6 | 12 | 8 | 4 | 6 |")
	assert_eq(rows[4], "| `works_at_war` | yes | yes | yes | no | no |")
	assert_eq(rows[8], "| `mix` | 600, 400, 0, 0 | 550, 350, 100, 0 | 500, 400, 50, 50 | 600, 150, 200, 50 | 500, 250, 200, 50 |")
	assert_eq(rows[rows.size() - 1], "| `fortify` | no | no | yes | no | no |")
	var shared := AiTables.shared_rows(defs)
	assert_eq(shared.size(), 2 + SHARED_TABLE.size(), "header, rule and a row a number")
	assert_eq(shared[2], "| `think_every` | 4 |")
	assert_eq(shared[shared.size() - 1], "| `yield_ratio` | 2000 |")
	assert_eq(AiTables.tables(defs).size(), rows.size() + 1 + shared.size(), "both tables and a blank line")


func test_planted_fault_ai_not_set_and_tempers_miscounted() -> void:
	var defs := _defs()
	defs.ai = null
	assert_true(_has(defs.validate(), "ai is not set"), "a missing ai refused")
	defs = _defs()
	defs.tempers = [defs.tempers[0], defs.tempers[1]] as Array[AiTemperDef]
	assert_true(_has(defs.validate(), "tempers has 2 entries, expected 5"), "two tempers refused")
	defs = _defs()
	var twin := defs.tempers[1].duplicate() as AiTemperDef
	twin.key = &"builder"
	defs.tempers = [defs.tempers[0], twin, defs.tempers[2], defs.tempers[3], defs.tempers[4]] as Array[AiTemperDef]
	assert_true(_has(defs.validate(), "duplicate temper key 'builder'"), "a repeated key refused")


func test_planted_fault_mix_sums_to_900() -> void:
	var defs := _defs()
	var t := _temper(&"builder")
	t.mix = PackedInt32Array([500, 400, 0, 0])
	assert_true(_has(t.validate(defs.units.size()), "mix sums to 900, expected 1000"), "900 refused")
	t = _temper(&"builder")
	t.mix = PackedInt32Array([600, 400, 0])
	assert_true(_has(t.validate(defs.units.size()), "mix has 3 entries, expected 4"), "three kinds refused")
	t = _temper(&"builder")
	t.mix = PackedInt32Array([1200, -200, 0, 0])
	assert_true(_has(t.validate(defs.units.size()), "mix[0] is 1200, expected 0 to 1000"), "a share over 1000 refused")


func test_planted_fault_declare_ratio_zero() -> void:
	var defs := _defs()
	var t := _temper(&"aggressive")
	t.declare_ratio = 0
	assert_true(_has(t.validate(defs.units.size()), "declare_ratio is 0, expected 100 to 10000"), "ratio 0 refused")
	t = _temper(&"aggressive")
	t.busy_bonus = 1300
	assert_true(_has(t.validate(defs.units.size()), "busy_bonus is 1300, expected 0 to 1200"), "a bonus over the ratio refused")


func test_planted_fault_temper_ranges_and_key() -> void:
	var defs := _defs()
	var t := _temper(&"cautious")
	t.war_army_permille = 2
	assert_true(_has(t.validate(defs.units.size()), "war_army_permille 2 should not be under army_permille 5"), "war army under peace army")
	t = _temper(&"cautious")
	t.key = &"Bad Key"
	assert_true(_has(t.validate(defs.units.size()), "key is not a lower-case word"), "a bad key refused")
	var cases: Array = [["reserve_seasons", 41, "0 to 40"], ["payback_max", 0, "1 to 400"], ["max_wars", 6, "0 to 5"],
			["siege_max", 0, "1 to 20"], ["take_score", 21, "1 to 20"], ["declare_chance", 1001, "0 to 1000"],
			["storm_share", 1001, "0 to 1000"], ["sue_ratio", 99, "100 to 10000"], ["tired_seasons", 81, "0 to 80"]]
	for case: Array in cases:
		t = _temper(&"cautious")
		t.set(case[0], case[1])
		assert_true(_has(t.validate(defs.units.size()), "%s is %d, expected %s" % [case[0], case[1], case[2]]), "%s refused" % case[0])


func test_planted_fault_scan_per_step_over_scan_hexes() -> void:
	var a := _ai()
	a.scan_per_step = 49
	assert_true(_has(a.validate(), "scan_per_step is 49, expected 1 to 48"), "a step over the scan refused")
	var cases: Array = [["think_every", 0, "1 to 20"], ["peace_order_every", 5, "1 to 4"], ["attack_range", 41, "1 to 40"],
			["works_cards", 21, "0 to 20"], ["jitter_permille", 501, "0 to 500"], ["rest_morale", 1001, "0 to 1000"],
			["food_priority", 0, "1 to 10000"], ["yield_ratio", 10001, "0 to 10000"]]
	for case: Array in cases:
		a = _ai()
		a.set(case[0], case[1])
		assert_true(_has(a.validate(), "%s is %d, expected %s" % [case[0], case[1], case[2]]), "%s refused" % case[0])


func test_planted_fault_scenario_unknown_temper_and_count() -> void:
	var defs := _defs()
	var map := _map()
	var s := _scenario_copy(defs)
	s.tempers[4] = &"gambler"
	assert_true(_has(s.validate(map, defs, false), "tempers[4]: unknown temper 'gambler'"), "an unknown key refused")
	s = _scenario_copy(defs)
	s.tempers.remove_at(12)
	assert_true(_has(s.validate(map, defs, false), "tempers has 12 entries, expected 13"), "12 tempers for 13 countries")
	assert_eq(defs.scenario("north_italy_1480").tempers.size(), 13, "the committed scenario is untouched")


func test_planted_fault_start_armies() -> void:
	var defs := _defs()
	var map := _map()
	var s := _scenario_copy(defs)
	var clean := s.digest()
	s.start_armies = [{"tag": &"MLO", "hex": Vector2i(9, 9), "kind": 0, "count": 2}] as Array[Dictionary]
	assert_eq(s.validate(map, defs, false), [] as Array[String], "an army on its own land is valid")
	assert_ne(s.digest(), clean, "start_armies are in the digest")
	s.start_armies = [{"tag": &"MLO", "hex": Vector2i(5, 9), "kind": 0, "count": 2}] as Array[Dictionary]
	assert_true(_has(s.validate(map, defs, false), "start_armies[0]: hex (5, 9) is not owned by 'MLO'"), "another's land refused")
	s.start_armies = [{"tag": &"MLO", "hex": Vector2i(9, 9), "kind": 4, "count": 2}] as Array[Dictionary]
	assert_true(_has(s.validate(map, defs, false), "start_armies[0]: unknown kind 4"), "an unknown kind refused")
	s.start_armies = [{"tag": &"MLO", "hex": Vector2i(9, 9), "kind": 0, "count": 9}] as Array[Dictionary]
	assert_true(_has(s.validate(map, defs, false), "start_armies[0]: count is 9, expected 1 to 8"), "nine companies refused")
	s.start_armies = [{"tag": &"XXX", "hex": Vector2i(9, 9), "kind": 0, "count": 1}] as Array[Dictionary]
	assert_true(_has(s.validate(map, defs, false), "start_armies[0]: tag 'XXX' is not listed"), "an unlisted tag refused")
	s.start_armies = [{"tag": &"MLO", "hex": Vector2i(19, 7), "kind": 0, "count": 1}] as Array[Dictionary]
	assert_true(_has(s.validate(map, defs, false), "start_armies[0]: hex (19, 7) is not on land"), "the sea refused")


func test_tempers_are_in_the_scenario_digest() -> void:
	var defs := _defs()
	var s := _scenario_copy(defs)
	var base := s.digest()
	s.tempers[0] = &"builder"
	assert_ne(s.digest(), base, "a changed temper changes the digest")
