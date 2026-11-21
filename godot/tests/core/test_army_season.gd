## The armies in the season, the stats and the save (docs/architecture/m6-build-spec.md 4.9, 4.16, 4.17, 5.0 R1, R4, R11;
## L8): a raise and its upkeep reach the stats in their season, the armies are in the digest and the save, a loaded game
## sees what its armies see, and a body with a damaged army is refused.
extends GutTest


## A game with two pikemen raised in the one town of Genoa (1,000 men), before the first season ends.
func _raised_game() -> Game:
	var g := ArmyFixture.game()
	var hex := ArmyFixture.find_town(g)
	ArmyFixture.town(g, hex)
	ArmyFixture.rich(g)
	assert_true(bool(g.act("raise", {"hex": hex, "kind": 0, "count": 2, "tag": ArmyFixture.TAG})["ok"]))
	return g


## The body of a game as a save file keeps it: var_to_bytes and back.
func _saved(g: Game) -> Dictionary:
	return bytes_to_var(var_to_bytes(Snapshot.of(g, {}))) as Dictionary


func test_a_raise_and_its_upkeep_reach_the_stats_in_their_season() -> void:
	var g := _raised_game()
	assert_eq(Armies.men_of_country(g, ArmyFixture.TAG), 1000, "two pikemen of 500")
	Season.run(g)
	var stats := g.stats
	assert_eq(stats.value(ArmyFixture.TAG, 1, "army_raised"), 1000, "the men raised in season 1")
	assert_eq(stats.value(ArmyFixture.TAG, 1, "army_men"), 1000)
	assert_eq(stats.value(ArmyFixture.TAG, 1, "spending"), 50, "two companies at 25 ducats")
	assert_eq(stats.value(ArmyFixture.TAG, 1, "upkeep_army"), 12, "two companies at 6 ducats a season")
	Season.run(g)
	assert_eq(stats.value(ArmyFixture.TAG, 2, "army_raised"), 0, "a raise counts in its season only")
	assert_eq(stats.value(ArmyFixture.TAG, 2, "army_starved"), 0)
	assert_eq(stats.value(ArmyFixture.TAG, 2, "upkeep_army"), 12, "upkeep is paid every season")
	assert_eq(stats.value(ArmyFixture.TAG, 2, "army_men"), 1000)


func test_the_armies_are_in_the_digest_and_the_save() -> void:
	var g := ArmyFixture.game()
	var before := g.digest()
	var hex := ArmyFixture.find_town(g)
	ArmyFixture.town(g, hex)
	ArmyFixture.rich(g)
	assert_true(bool(g.act("raise", {"hex": hex, "kind": 0, "count": 1, "tag": ArmyFixture.TAG})["ok"]))
	assert_ne(g.digest(), before, "an army is in the digest")
	Season.run(g)
	var body := _saved(g)
	assert_eq(((body["armies"] as Dictionary)["list"] as Array).size(), 1)
	var back := Snapshot.restore(body, g.map, g.defs)
	assert_eq(str(back["problem"]), "")
	var loaded := back["game"] as Game
	assert_eq(loaded.digest(), g.digest(), "the save and the load give the same digest")
	assert_eq(loaded.armies.size(), 1)
	assert_eq(loaded.next_army_id, g.next_army_id)
	assert_eq(loaded.next_unit_id, g.next_unit_id)


func test_a_loaded_game_sees_what_its_armies_see_and_explored_is_as_saved() -> void:
	var g := _raised_game()
	Season.run(g)
	var loaded := Snapshot.restore(_saved(g), g.map, g.defs)["game"] as Game
	var army := g.armies[0]
	assert_true(Sight.sees(loaded, ArmyFixture.TAG, army.hex), "the army part of the sight is rebuilt on load")
	assert_eq(loaded.sight.watchers.size(), g.sight.watchers.size())
	var id := ArmyFixture.id_of(g, ArmyFixture.TAG)
	assert_eq(loaded.countries[id - 1].explored, g.countries[id - 1].explored, "explored is never written on a load")


func test_a_body_with_a_damaged_army_is_refused() -> void:
	var g := _raised_game()
	var body := Snapshot.of(g, {})
	var list := (body["armies"] as Dictionary)["list"] as Array
	list.append((list[0] as Dictionary).duplicate(true))  # the planted fault: the same army id twice
	var back := Snapshot.restore(bytes_to_var(var_to_bytes(body)) as Dictionary, g.map, g.defs)
	assert_null(back["game"], "a duplicate army id is refused")
	assert_eq(str(back["problem"]), Snapshot.PROBLEM_UNREADABLE)


## A Genoese land hex with a hex within two of it that Genoa does not see before the raise: the army's sight adds to it.
func _border_town(g: Game) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if not g.map.is_land(hex) or Territory.owner_tag(g, hex) != ArmyFixture.TAG:
			continue
		for j: int in SightCache.disc(g.map, i, 2):
			if not Sight.sees(g, ArmyFixture.TAG, g.map.hex_of(j)):
				return hex
	return Vector2i(-1, -1)


func test_a_live_and_a_loaded_game_agree_on_witnesses_after_a_raise() -> void:
	# Knights see 2 hexes (UnitDef.sight), so the raised army's sight reaches past its country's land: the live game must
	# rebuild the army part at the raise (Military.raise refreshes Sight), or it would disagree with a loaded game.
	var g := ArmyFixture.game()
	var hex := _border_town(g)
	ArmyFixture.town(g, hex)
	ArmyFixture.rich(g)
	assert_true(bool(g.act("raise", {"hex": hex, "kind": 2, "count": 1, "tag": ArmyFixture.TAG})["ok"]))
	var loaded := Snapshot.restore(_saved(g), g.map, g.defs)["game"] as Game
	for j: int in SightCache.disc(g.map, g.map.index_of(hex), 2):
		var near := g.map.hex_of(j)
		assert_eq(Sight.sees(loaded, ArmyFixture.TAG, near), Sight.sees(g, ArmyFixture.TAG, near), "sight at %s" % str(near))
		assert_eq(Sight.witnesses_of(loaded, near, ArmyFixture.TAG), Sight.witnesses_of(g, near, ArmyFixture.TAG),
			"witnesses at %s" % str(near))
