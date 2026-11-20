## Words (docs/architecture/m3-build-spec.md 5.6, 9): number, signed, plural, place, list, country_the, seasons.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"

var _game: Game = null


func before_all() -> void:
	var defs := load(DEFS_PATH) as GameDefs
	var scenario: ScenarioDef = null
	for s: ScenarioDef in defs.scenarios:
		scenario = s
	_game = Game.new_scenario(load(MAP_PATH) as MapData, defs, scenario, 1480)


func test_number() -> void:
	assert_eq(Words.number(0), "0")
	assert_eq(Words.number(999), "999")
	assert_eq(Words.number(1240), "1,240")
	assert_eq(Words.number(1234567), "1,234,567")
	assert_eq(Words.number(-1240), "−1,240")


func test_signed_uses_the_true_minus() -> void:
	assert_eq(Words.signed(86), "+86")
	assert_eq(Words.signed(-6), "−6")
	assert_eq(Words.signed(0), "0")
	assert_eq(Words.signed(-6).unicode_at(0), 0x2212)
	assert_eq(Words.signed(1500), "+1,500")


func test_plural_and_seasons() -> void:
	assert_eq(Words.plural(1, "work", "works"), "1 work")
	assert_eq(Words.plural(2, "work", "works"), "2 works")
	assert_eq(Words.plural(0, "work", "works"), "0 works")
	assert_eq(Words.seasons(1), "1 season")
	assert_eq(Words.seasons(4), "4 seasons")


func test_place_named_near_and_bare() -> void:
	assert_eq(Words.place(_game, Vector2i(6, 13)), "Savona (6, 13)")
	assert_eq(Words.place(_game, Vector2i(7, 12)), "near Savona (7, 12)")
	assert_eq(Words.place(_game, Vector2i(0, 0)), "(0, 0)")
	assert_eq(Words.place(null, Vector2i(3, 4)), "(3, 4)")
	assert_eq(Words.place(Game.new(), Vector2i(3, 4)), "(3, 4)")


func test_place_nearest_wins_and_ties_go_to_place_order() -> void:
	var m := ImproveFixture.block(9, 5, {}, {
		Vector2i(1, 2): {"place": {"name": "Alpha", "level": 1}},
		Vector2i(5, 2): {"place": {"name": "Beta", "level": 1}},
		Vector2i(7, 2): {"place": {"name": "Gamma", "level": 1}},
	})
	var g := Game.new_game(m, 1)
	assert_eq(Words.place(g, Vector2i(3, 2)), "near Alpha (3, 2)", "a tie: the first place")
	assert_eq(Words.place(g, Vector2i(4, 2)), "near Beta (4, 2)", "the nearer one")
	assert_eq(Words.place(g, Vector2i(8, 2)), "near Gamma (8, 2)")


func test_list() -> void:
	var four: Array[String] = ["a", "b", "c", "d"]
	assert_eq(Words.list(four), "a, b and 2 more")
	assert_eq(Words.list(four, 3), "a, b, c and 1 more")
	var none: Array[String] = []
	var one: Array[String] = ["a"]
	var two: Array[String] = ["a", "b"]
	assert_eq(Words.list(none), "")
	assert_eq(Words.list(one), "a")
	assert_eq(Words.list(two), "a and b")


func test_country_the() -> void:
	var tag: StringName = _game.defs.countries[0].tag
	var def := Countries.def_of(_game, tag)
	assert_eq(Words.country_the(_game, tag), "the " + def.long_name)
	assert_eq(Words.country_the(_game, &""), "")
	assert_eq(Words.country_the(_game, &"ZZZ"), "the ZZZ")
