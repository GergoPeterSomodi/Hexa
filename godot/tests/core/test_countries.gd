## Countries system & Game scenario tests (docs/architecture/m2-build-spec.md sections 5.3, 5.4, 5.9, and 10):
## setup, lookup helpers, playability, every row of choose_check, choose event & immutability, Game.digest(),
## piece round-trip, and M1 map-only backward compatibility.
extends GutTest


func test_setup_lookups_and_playability() -> void:
	var g := ScenarioFixture.game()
	assert_eq(Countries.OWNS, ["countries", "player"])
	assert_true(g.has_countries())
	assert_eq(g.player, &"")
	assert_eq(g.countries.size(), 3)

	assert_eq(g.countries[0].id, 1)
	assert_eq(g.countries[0].tag, &"AAA")
	assert_eq(g.countries[0].capital, ScenarioFixture.ALPHA_CAPITAL)
	assert_eq(g.countries[1].id, 2)
	assert_eq(g.countries[1].tag, &"BBB")
	assert_eq(g.countries[1].capital, ScenarioFixture.BETA_CAPITAL)
	assert_eq(g.countries[2].id, 3)
	assert_eq(g.countries[2].tag, &"OUT")
	assert_eq(g.countries[2].capital, Country.NO_HEX)

	assert_null(Countries.by_id(g, 0))
	assert_null(Countries.by_id(g, -1))
	assert_null(Countries.by_id(g, 4))
	assert_eq(Countries.by_id(g, 2).tag, &"BBB")

	assert_null(Countries.by_tag(g, &""))
	assert_null(Countries.by_tag(g, &"ZZZ"))
	assert_eq(Countries.by_tag(g, &"AAA").id, 1)

	assert_eq(Countries.def_of(g, &"AAA").long_name, "Republic of Alpha")
	assert_null(Countries.def_of(g, &"ZZZ"))

	assert_true(Countries.playable(g, &"AAA"))
	assert_true(Countries.playable(g, &"BBB"))
	assert_false(Countries.playable(g, &"OUT"))
	assert_false(Countries.playable(g, &"ZZZ"))

	g.countries[0].alive = false
	assert_false(Countries.playable(g, &"AAA"))


func test_choose_check_every_table_row_and_choose_action() -> void:
	var f := ScenarioFixture.build()
	var m := f["map"] as MapData

	# 1. Map-only game -> "this map has no countries".
	var sandbox := Game.new_game(m, 1)
	var no_countries := sandbox.check("choose_country", {"tag": &"AAA"})
	assert_false(bool(no_countries["ok"]))
	assert_eq(str(no_countries["reason"]), "this map has no countries")

	var g := ScenarioFixture.game()
	var before := g.digest()

	# 3. Unknown tag -> "no country %s".
	var missing := g.check("choose_country", {"tag": &"ZZZ"})
	assert_false(bool(missing["ok"]))
	assert_eq(str(missing["reason"]), "no country ZZZ")
	var empty_tag := g.check("choose_country", {})
	assert_false(bool(empty_tag["ok"]))
	assert_eq(str(empty_tag["reason"]), "no country ")

	# 4. Capital off the map -> "%s cannot be played here: its capital, %s, is off this map".
	var off_map := g.check("choose_country", {"tag": &"OUT"})
	assert_false(bool(off_map["ok"]))
	assert_eq(str(off_map["reason"]), "Outland cannot be played here: its capital, Farburg, is off this map")

	# 5. Not alive -> "%s is no more".
	g.countries[1].alive = false
	var dead := g.check("choose_country", {"tag": &"BBB"})
	assert_false(bool(dead["ok"]))
	assert_eq(str(dead["reason"]), "Beta is no more")
	g.countries[1].alive = true

	# Check never mutates state or queues events.
	var valid_check := g.check("choose_country", {"tag": &"AAA"})
	assert_true(bool(valid_check["ok"]))
	assert_eq(str(valid_check["reason"]), "")
	assert_eq(g.player, &"")
	assert_eq(g.events.size(), 0)
	assert_eq(g.digest(), before)

	# 6. Act choose_country sets player, queues country_chosen once, updates digest.
	assert_true(Actions.NAMES.has("choose_country"))
	assert_eq(Actions.pair_of("choose_country").size(), 2)
	var chosen := g.act("choose_country", {"tag": &"AAA"})
	assert_true(bool(chosen["ok"]))
	assert_eq(str(chosen["reason"]), "")
	assert_eq(g.player, &"AAA")
	assert_eq(g.events.size(), 1)
	assert_eq(str(g.events[0]["kind"]), "country_chosen")
	assert_eq(g.events[0]["tag"], &"AAA")
	assert_eq(int(g.events[0]["turn"]), 1)
	assert_eq(g.chronicle.entries.size(), 1, "country_chosen is notable")
	assert_eq(g.chronicle.entries[0]["tag"], "AAA")
	assert_ne(g.digest(), before)

	# 2. Second choose is refused and changes nothing.
	var after_choose := g.digest()
	g.events.clear()
	var second := g.act("choose_country", {"tag": &"BBB"})
	assert_false(bool(second["ok"]))
	assert_eq(str(second["reason"]), "a country is chosen already: Alpha")
	assert_eq(g.player, &"AAA")
	assert_eq(g.events.size(), 0)
	assert_eq(g.digest(), after_choose)


func test_game_digest_covers_new_fields_and_round_trip_pieces() -> void:
	var a := ScenarioFixture.game(1480)
	var b := ScenarioFixture.game(1480)
	assert_eq(a.digest(), b.digest())

	# Changing scenario id moves digest.
	var f2 := ScenarioFixture.build()
	var scen2 := f2["scenario"] as ScenarioDef
	scen2.id = "other_scenario"
	var c_scen := Game.new_scenario(f2["map"] as MapData, f2["defs"] as GameDefs, scen2, 1480)
	assert_ne(c_scen.digest(), a.digest(), "scenario id in digest")

	# Changing player moves digest.
	var base := a.digest()
	a.act("choose_country", {"tag": &"AAA"})
	assert_ne(a.digest(), base, "player in digest")

	# Changing MapState.owner moves digest.
	var with_player := a.digest()
	Territory.transfer(a, [ScenarioFixture.UNOWNED_HEXES[0]], 1)
	assert_ne(a.digest(), with_player, "owner in digest")

	# Changing a Country field moves digest.
	var with_owner := a.digest()
	a.countries[2].alive = false
	assert_ne(a.digest(), with_owner, "country alive in digest")

	# Spec 5.9 piece-by-piece round-trip reconstructs an identical Game.digest().
	var saved_state := a.state.to_dict()
	var saved_countries: Array[Dictionary] = []
	for c: Country in a.countries:
		saved_countries.append(c.to_dict())
	var saved_player := String(a.player)

	var restored := Game.with_state(a.map, MapState.from_dict(saved_state, a.map), a.seed_value)
	restored.defs = a.defs
	restored.scenario = a.scenario
	restored.player = StringName(saved_player)
	restored.start_year = a.start_year
	restored.turn = a.turn
	restored.chronicle = Chronicle.from_dict(a.chronicle.to_dict())
	restored.luck = Luck.from_dict(a.luck.to_dict(), a.seed_value)
	restored.stats = Stats.from_dict(a.stats.to_dict())
	for cd: Dictionary in saved_countries:
		restored.countries.append(Country.from_dict(cd))
	assert_eq(restored.digest(), a.digest(), "5.9 piece round-trip preserves Game.digest()")


func test_map_only_backward_compatibility() -> void:
	var f := ScenarioFixture.build()
	var m := f["map"] as MapData
	# A map-only game has no countries; building needs the work data (the defs), as every work takes seasons.
	var g := Game.new_game(m, 99, load("res://data/defs/game_defs.tres") as GameDefs)
	assert_false(g.has_countries())
	assert_null(g.scenario)
	assert_true(g.countries.is_empty())
	assert_eq(g.player, &"")

	# Map-only game builds anywhere without a tag.
	for i: int in m.hex_count():
		var hex := m.hex_of(i)
		if not m.is_land(hex) or not Improve.piece_at(g, hex).is_empty():
			continue
		var opts := Improve.build_options(g, hex)
		if not opts.is_empty():
			var res := g.act("build", {"hex": hex, "family": int(opts[0]["family_id"])})
			assert_true(bool(res["ok"]), str(res["reason"]))
			break
