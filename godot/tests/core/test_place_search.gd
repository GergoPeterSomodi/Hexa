## Unit tests for PlaceSearch (docs/architecture/m2-build-spec.md sections 5.7 and 10).
extends GutTest

const DEFS_PATH := "res://data/defs/game_defs.tres"
const MAP_PATH := "res://data/maps/north_italy.tres"
const SCEN_PATH := "res://data/scenarios/north_italy_1480.tres"

var _game: Game = null


func before_all() -> void:
	var defs := ResourceLoader.load(DEFS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	var map := ResourceLoader.load(MAP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as MapData
	var scen := ResourceLoader.load(SCEN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ScenarioDef
	_game = Game.new_scenario(map, defs, scen, 1480)


func test_fold_normalizes_diacritics_and_spaces() -> void:
	assert_eq(PlaceSearch.fold("Città"), "citta")
	assert_eq(PlaceSearch.fold("  Città   di\tCastello  "), "citta di castello")
	assert_eq(PlaceSearch.fold("Côte"), "cote")
	assert_eq(PlaceSearch.fold("Łódź"), "lodz")
	assert_eq(PlaceSearch.fold("Straße"), "strasse")
	assert_eq(PlaceSearch.fold("   "), "")


func test_empty_and_null_inputs() -> void:
	assert_eq(PlaceSearch.find(null, "mil"), [] as Array[Dictionary])
	assert_eq(PlaceSearch.find(_game, ""), [] as Array[Dictionary])
	assert_eq(PlaceSearch.find(_game, "   "), [] as Array[Dictionary])
	assert_eq(PlaceSearch.find(_game, "mil", 0), [] as Array[Dictionary])


func test_ver_ranks_prefix_verona_and_vercelli_before_substrings() -> void:
	var hits := PlaceSearch.find(_game, "ver")
	assert_gte(hits.size(), 2)
	var names: Array[String] = []
	for h: Dictionary in hits:
		names.append(str(h["name"]))
	assert_true(names.has("Verona"))
	assert_true(names.has("Vercelli"))

	# All prefix matches must precede any non-prefix matches.
	var saw_non_prefix := false
	for h: Dictionary in hits:
		var folded := PlaceSearch.fold(str(h["name"]))
		if folded.begins_with("ver"):
			assert_false(saw_non_prefix, "prefix match '%s' appeared after a non-prefix match" % h["name"])
		else:
			saw_non_prefix = true


func test_mil_returns_country_milan_first_then_town_milan() -> void:
	var hits := PlaceSearch.find(_game, "mil")
	assert_gte(hits.size(), 2)
	assert_eq(hits[0]["kind"], &"country")
	assert_eq(str(hits[0]["name"]), "Milan")
	assert_eq(hits[0]["tag"], &"MLO")
	assert_eq(str(hits[0]["detail"]), "country, 52 districts")

	assert_eq(hits[1]["kind"], &"place")
	assert_eq(str(hits[1]["name"]), "Milan")
	assert_eq(hits[1]["tag"], &"MLO")
	assert_eq(str(hits[1]["detail"]), "city, Duchy of Milan")


func test_bernin_returns_bernina_pass_then_hospice_bernina_not_bern() -> void:
	var hits := PlaceSearch.find(_game, "bernin")
	assert_eq(hits.size(), 2)
	assert_eq(hits[0]["kind"], &"pass")
	assert_eq(str(hits[0]["name"]), "Bernina")
	assert_eq(hits[0]["tag"], &"MLO")
	assert_true(str(hits[0]["detail"]).begins_with("pass, "))

	assert_eq(hits[1]["kind"], &"place")
	assert_eq(str(hits[1]["name"]), "Hospice Bernina")
	assert_eq(hits[1]["tag"], &"MLO")

	for h: Dictionary in hits:
		assert_ne(str(h["name"]), "Bern")


func test_pass_detail_formats_thousands_and_unnamed_places_are_excluded_and_limit_applies() -> void:
	var st_bernard := PlaceSearch.find(_game, "great st")
	assert_gte(st_bernard.size(), 1)
	assert_eq(st_bernard[0]["kind"], &"pass")
	assert_eq(str(st_bernard[0]["name"]), "Great St Bernard")
	assert_eq(str(st_bernard[0]["detail"]), "pass, 2,469 m")

	for query: String in ["a", "e", "i", "o", "u"]:
		var hits := PlaceSearch.find(_game, query)
		assert_lte(hits.size(), PlaceSearch.LIMIT)
		for h: Dictionary in hits:
			assert_ne(str(h["name"]).strip_edges(), "", "unnamed place must never appear")

	var limited := PlaceSearch.find(_game, "a", 3)
	assert_eq(limited.size(), 3)


func test_map_only_game_searches_places_and_passes_without_countries() -> void:
	var sandbox := Game.new_game(_game.map, 1480)
	var hits := PlaceSearch.find(sandbox, "mil")
	assert_gte(hits.size(), 1)
	assert_eq(hits[0]["kind"], &"place")
	assert_eq(str(hits[0]["name"]), "Milan")
	assert_eq(hits[0]["tag"], &"")
	assert_eq(str(hits[0]["detail"]), "city")
