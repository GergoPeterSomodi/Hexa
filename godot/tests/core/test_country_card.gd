## Unit tests for CountryCard (docs/architecture/m2-build-spec.md sections 5.7, 7.4, and 10).
extends GutTest

const DEFS_PATH := "res://data/defs/game_defs.tres"
const MAP_PATH := "res://data/maps/north_italy.tres"
const SCEN_PATH := "res://data/scenarios/north_italy_1480.tres"

var _game: Game = null


func before_each() -> void:
	var defs := ResourceLoader.load(DEFS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	var map := ResourceLoader.load(MAP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as MapData
	var scen := ResourceLoader.load(SCEN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ScenarioDef
	_game = Game.new_scenario(map, defs, scen, 1480)


func test_invalid_inputs_return_empty() -> void:
	assert_eq(CountryCard.of(null, &"GEN"), {})
	assert_eq(CountryCard.of(_game, &""), {})
	assert_eq(CountryCard.of(_game, &"ZZZ"), {})
	var sandbox := Game.new_game(_game.map, 1480)
	assert_eq(CountryCard.of(sandbox, &"GEN"), {})


func test_genoa_card_before_and_after_choosing_genoa() -> void:
	var before := CountryCard.of(_game, &"GEN")
	assert_eq(before["relation"], &"other")
	assert_true(bool(before["playable"]))
	assert_eq(str(before["play_reason"]), "")

	assert_true(bool(_game.act("choose_country", {"tag": &"GEN"})["ok"]))
	var gen := CountryCard.of(_game, &"GEN")
	assert_eq(gen["tag"], &"GEN")
	assert_eq(str(gen["name"]), "Genoa")
	assert_eq(str(gen["long_name"]), "Republic of Genoa")
	assert_eq(str(gen["adjective"]), "Genoese")
	assert_eq(gen["colour"], _game.defs.country(&"GEN").colour)
	assert_eq(gen["relation"], &"you")
	assert_eq(int(gen["districts"]), 14)
	assert_eq(int(gen["towns"]), 2)
	assert_eq(int(gen["cities"]), 1)

	var cap: Dictionary = gen["capital"]
	assert_eq(str(cap["name"]), "Genoa")
	assert_eq(cap["hex"], Vector2i(8, 13))
	assert_false(bool(cap["off_map"]))
	assert_eq(gen["focus"], Vector2i(8, 13))

	var arms: Dictionary = gen["arms"]
	assert_eq(arms["division"], &"cross")
	assert_eq(arms["field"], _game.defs.tinctures[&"argent"])
	assert_eq(arms["charge"], _game.defs.tinctures[&"gules"])

	# Neighbours in ascending id order: Savoy (4), Milan (5).
	var nbs: Array = gen["neighbours"]
	assert_eq(nbs.size(), 2)
	assert_eq(nbs[0], {"tag": &"SAV", "name": "Savoy"})
	assert_eq(nbs[1], {"tag": &"MLO", "name": "Milan"})

	var passes: Array = gen["passes"]
	assert_true(passes.has("Cadibona"))
	assert_true(passes.has("Giovi"))
	assert_eq(passes.size(), 2)

	# Land covers are sorted descending and sum to districts.
	var land: Array = gen["land"]
	assert_gt(land.size(), 0)
	var sum := 0
	var prev := 999999
	for row: Variant in land:
		var d: Dictionary = row
		var cnt := int(d["count"])
		assert_gt(cnt, 0)
		assert_lte(cnt, prev)
		prev = cnt
		sum += cnt
	assert_eq(sum, int(gen["districts"]))
	assert_ne(str(gen["tip"]), "")

	# Neighbour vs other relation when player is GEN.
	var mlo := CountryCard.of(_game, &"MLO")
	assert_eq(mlo["relation"], &"neighbour")
	assert_eq(int(mlo["districts"]), 52)
	assert_eq(int(mlo["towns"]), 20)
	assert_eq(int(mlo["cities"]), 2)
	var ven := CountryCard.of(_game, &"VEN")
	assert_eq(ven["relation"], &"other")


func test_france_outside_power_with_reason_and_region_focus() -> void:
	assert_true(bool(_game.act("choose_country", {"tag": &"SAV"})["ok"]))
	var fra := CountryCard.of(_game, &"FRA")
	assert_eq(fra["relation"], &"outside")
	assert_false(bool(fra["playable"]))
	assert_eq(str(fra["play_reason"]), "France cannot be played here: its capital, Paris, is off this map")

	var cap: Dictionary = fra["capital"]
	assert_eq(str(cap["name"]), "Paris")
	assert_eq(cap["hex"], Country.NO_HEX)
	assert_true(bool(cap["off_map"]))

	var focus: Vector2i = fra["focus"]
	assert_true(_game.map.is_land(focus))
	assert_eq(Territory.owner_tag(_game, focus), &"FRA")
	# Focus must sit in France's larger region (27 hexes, Dauphiné-Provence).
	var fra_regions := ScenarioGrowth.regions(_game.map, _game.state.owner, _game.scenario.id_of(&"FRA"))
	var largest := fra_regions[0] if fra_regions[0].size() > fra_regions[1].size() else fra_regions[1]
	assert_true(largest.has(_game.map.index_of(focus)))

	var sum := 0
	for row: Variant in fra["land"] as Array:
		sum += int((row as Dictionary)["count"])
	assert_eq(sum, 34)
	assert_eq(int(fra["districts"]), 34)


func test_treasury_yours_known_and_unknown() -> void:
	var game := EconomyFixture.game(&"GEN")
	var gen := CountryCard.of(game, &"GEN")["treasury"] as Dictionary
	assert_eq(gen, {"shown": true, "value": 610, "banded": false, "change": 0, "expected": 86, "expected_realm": 93, "tax": "Normal"})
	var mlo := CountryCard.of(game, &"MLO")["treasury"] as Dictionary
	assert_true(bool(mlo["shown"]))
	assert_true(bool(mlo["banded"]))
	assert_null(mlo["expected"], "another country's expected season is never shown")
	assert_null(mlo["expected_realm"])
	assert_eq(int(mlo["value"]), Knowledge.band(Countries.by_tag(game, &"MLO").treasury))
	assert_eq(Knowledge.band_text(int(mlo["value"]), ""), "about 1,900")
	assert_eq(mlo["tax"], "", "a foreign country shows no tax")
	var fra := CountryCard.of(game, &"FRA")["treasury"] as Dictionary
	assert_false(bool(fra["shown"]), "France is unknown to Genoa: no treasury")
	assert_eq(int(fra["value"]), 0)


func test_own_treasury_change_after_a_season() -> void:
	var game := EconomyFixture.game(&"GEN")
	assert_true(bool(Season.run(game)["ok"]))
	var gen := CountryCard.of(game, &"GEN")["treasury"] as Dictionary
	assert_eq(int(gen["value"]), 696)
	assert_eq(int(gen["change"]), 86)
	assert_eq(gen["tax"], "Normal")


func test_people_yours_known_and_unknown() -> void:
	var game := PeopleFixture.genoa()
	var gen := CountryCard.of(game, &"GEN")["people"] as Dictionary
	assert_eq(gen, {"shown": true, "value": 82700, "banded": false, "change": 0})
	var mlo := CountryCard.of(game, &"MLO")["people"] as Dictionary
	assert_true(bool(mlo["shown"]))
	assert_true(bool(mlo["banded"]))
	assert_eq(int(mlo["value"]), Knowledge.band(int(PeopleView.totals(game, &"MLO")["people"])))
	assert_eq(int(mlo["change"]), 0, "a foreign change is not told")
	var fra := CountryCard.of(game, &"FRA")["people"] as Dictionary
	assert_false(bool(fra["shown"]), "France is unknown to Genoa: no people")
	assert_eq(int(fra["value"]), 0)
	Season.run(game)
	var after := CountryCard.of(game, &"GEN")["people"] as Dictionary
	assert_eq(int(after["value"]), 83285)
	assert_eq(int(after["change"]), 585)
	game.player = &""
	var all := CountryCard.of(game, &"FRA")["people"] as Dictionary
	assert_true(bool(all["shown"]))
	assert_false(bool(all["banded"]), "the viewer empty sees everything exact")
