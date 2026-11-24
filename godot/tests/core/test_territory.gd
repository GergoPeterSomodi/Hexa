## Territory system tests (docs/architecture/m2-build-spec.md sections 5.3 and 10):
## fixture validity, owner_id/owner_tag, every row of at_home_check, transfer event/filtering/freeing,
## districts, count, neighbours, and OWNS.
extends GutTest


func test_fixture_is_deep_valid_and_initial_owners_copied() -> void:
	var f := ScenarioFixture.build()
	var m := f["map"] as MapData
	var defs := f["defs"] as GameDefs
	var scen := f["scenario"] as ScenarioDef
	assert_eq(defs.validate(), [] as Array[String])
	assert_eq(scen.validate(m, defs, true), [] as Array[String])

	var g := Game.new_scenario(m, defs, scen, 1480)
	assert_eq(Territory.OWNS, ["owner"])
	assert_eq(g.state.owner, scen.owner)
	assert_eq(Territory.owner_id(g, ScenarioFixture.ALPHA_CAPITAL), 1)
	assert_eq(Territory.owner_tag(g, ScenarioFixture.ALPHA_CAPITAL), &"AAA")
	assert_eq(Territory.owner_id(g, ScenarioFixture.BETA_CAPITAL), 2)
	assert_eq(Territory.owner_tag(g, ScenarioFixture.BETA_CAPITAL), &"BBB")
	assert_eq(Territory.owner_id(g, ScenarioFixture.OUTLAND_ANCHOR), 3)
	assert_eq(Territory.owner_tag(g, ScenarioFixture.OUTLAND_ANCHOR), &"OUT")
	assert_eq(Territory.owner_id(g, ScenarioFixture.UNOWNED_HEXES[0]), 0)
	assert_eq(Territory.owner_tag(g, ScenarioFixture.UNOWNED_HEXES[0]), &"")
	assert_eq(Territory.owner_id(g, ScenarioFixture.SEA_HEX), 0)
	assert_eq(Territory.owner_tag(g, ScenarioFixture.SEA_HEX), &"")
	assert_eq(Territory.owner_id(g, Vector2i(-1, 0)), 0)
	assert_eq(Territory.owner_tag(g, Vector2i(-1, 0)), &"")


func test_at_home_check_every_table_row() -> void:
	var f := ScenarioFixture.build()
	var m := f["map"] as MapData

	# 1. Map-only game -> ok regardless of tag or owner.
	var sandbox := Game.new_game(m, 1)
	assert_true(bool(Territory.at_home_check(sandbox, &"", ScenarioFixture.ALPHA_CAPITAL)["ok"]))
	assert_true(bool(Territory.at_home_check(sandbox, &"ZZZ", ScenarioFixture.ALPHA_CAPITAL)["ok"]))

	# 2. Sea or off-map -> ok (acting system refuses with "not a land hex").
	var g := ScenarioFixture.game()
	assert_true(bool(Territory.at_home_check(g, &"", ScenarioFixture.SEA_HEX)["ok"]))
	assert_true(bool(Territory.at_home_check(g, &"ZZZ", Vector2i(-2, 0))["ok"]))
	assert_true(bool(Territory.at_home_check(g, &"AAA", Vector2i(9, 2))["ok"]))

	# 3. Empty tag -> "choose your country first".
	var no_tag := Territory.at_home_check(g, &"", ScenarioFixture.ALPHA_CAPITAL)
	assert_false(bool(no_tag["ok"]))
	assert_eq(str(no_tag["reason"]), "choose your country first")

	# 4. Unknown tag -> "no country %s".
	var unknown := Territory.at_home_check(g, &"ZZZ", ScenarioFixture.ALPHA_CAPITAL)
	assert_false(bool(unknown["ok"]))
	assert_eq(str(unknown["reason"]), "no country ZZZ")

	# 5. Country not alive -> "%s is no more".
	g.countries[0].alive = false
	var dead := Territory.at_home_check(g, &"AAA", ScenarioFixture.ALPHA_CAPITAL)
	assert_false(bool(dead["ok"]))
	assert_eq(str(dead["reason"]), "Alpha is no more")
	g.countries[0].alive = true

	# 6. Unowned land -> "no one holds this land".
	var unowned := Territory.at_home_check(g, &"AAA", ScenarioFixture.UNOWNED_HEXES[0])
	assert_false(bool(unowned["ok"]))
	assert_eq(str(unowned["reason"]), "no one holds this land")

	# 7. Held by another country -> "not your land: the %s holds it" (long name), but only on a hex the actor has discovered
	# (R32, D15). AAA has not discovered BETA's capital or OUTLAND's anchor in this fixture, so no name is given.
	var other_b := Territory.at_home_check(g, &"AAA", ScenarioFixture.BETA_CAPITAL)
	assert_false(bool(other_b["ok"]))
	assert_eq(str(other_b["reason"]), "not your land: another country holds it")

	var other_out := Territory.at_home_check(g, &"AAA", ScenarioFixture.OUTLAND_ANCHOR)
	assert_false(bool(other_out["ok"]))
	assert_eq(str(other_out["reason"]), "not your land: another country holds it")

	# The same refusal names the holder once AAA has discovered the hex (a thin radius that covers the whole 9x7 map).
	FogFixture.thin(g, &"AAA", 30)
	assert_eq(str(Territory.at_home_check(g, &"AAA", ScenarioFixture.BETA_CAPITAL)["reason"]),
		"not your land: the Duchy of Beta holds it", "discovered: the holder is named")

	# 8. Own land -> ok (including outside power acting on its own hex).
	var own := Territory.at_home_check(g, &"AAA", ScenarioFixture.ALPHA_CAPITAL)
	assert_true(bool(own["ok"]))
	assert_eq(str(own["reason"]), "")
	assert_true(bool(Territory.at_home_check(g, &"OUT", ScenarioFixture.OUTLAND_ANCHOR)["ok"]))


func test_transfer_skips_queues_one_event_and_frees() -> void:
	var g := ScenarioFixture.game()
	var scenario_owner_before := g.scenario.owner.duplicate()
	var beta_hex := ScenarioFixture.BETA_CAPITAL
	var unowned_hex := ScenarioFixture.UNOWNED_HEXES[0]
	var alpha_hex := ScenarioFixture.ALPHA_CAPITAL

	# Mix: BBB hex, unowned hex, duplicate unowned hex, already-AAA hex, sea hex, off-map hex.
	var batch: Array[Vector2i] = [
		beta_hex, unowned_hex, unowned_hex, alpha_hex, ScenarioFixture.SEA_HEX, Vector2i(-1, -1),
	]
	var changed := Territory.transfer(g, batch, 1)
	assert_eq(changed, 2, "only beta_hex and unowned_hex change")
	assert_eq(Territory.owner_id(g, beta_hex), 1)
	assert_eq(Territory.owner_id(g, unowned_hex), 1)
	assert_eq(Territory.owner_id(g, ScenarioFixture.SEA_HEX), 0, "sea stays 0")
	assert_eq(g.scenario.owner, scenario_owner_before, "scenario.owner resource is never mutated")

	assert_eq(g.events.size(), 1, "exactly one owners_changed event queued")
	assert_eq(str(g.events[0]["kind"]), "owners_changed")
	var ev_hexes: Array[Vector2i] = g.events[0]["hexes"]
	assert_eq(ev_hexes, [beta_hex, unowned_hex] as Array[Vector2i])
	assert_eq(g.events[0]["tag"], &"AAA", "the new owner")
	assert_eq(g.events[0]["others"], [&"BBB"] as Array[StringName], "the old owners, unowned land left out")
	assert_eq(int(g.events[0]["turn"]), 1, "emit stamps the turn")
	assert_eq(g.chronicle.entries.size(), 1, "owners_changed is notable")
	assert_eq(str(g.chronicle.entries[0]["kind"]), "owners_changed")
	assert_eq(g.chronicle.entries[0]["others"], PackedStringArray(["BBB"]))

	# No-op transfer queues nothing.
	g.events.clear()
	assert_eq(Territory.transfer(g, [alpha_hex, ScenarioFixture.SEA_HEX, Vector2i(99, 0)], 1), 0)
	assert_eq(g.events.size(), 0, "no-op transfer queues nothing")

	# Invalid country ids are refused cleanly.
	assert_eq(Territory.transfer(g, [alpha_hex], -1), 0)
	assert_eq(Territory.transfer(g, [alpha_hex], 99), 0)
	assert_eq(g.events.size(), 0)

	# to_id = 0 frees land and queues one event.
	assert_eq(Territory.transfer(g, [beta_hex], 0), 1)
	assert_eq(Territory.owner_id(g, beta_hex), 0)
	assert_eq(g.events.size(), 1)
	var freed_verdict := Territory.at_home_check(g, &"AAA", beta_hex)
	assert_false(bool(freed_verdict["ok"]))
	assert_eq(str(freed_verdict["reason"]), "no one holds this land")


func test_districts_count_and_neighbours() -> void:
	var g := ScenarioFixture.game()
	var total_owned := 0
	for cid: int in [1, 2, 3]:
		var d := Territory.districts(g, cid)
		var cnt := Territory.count(g, cid)
		assert_eq(d.size(), cnt, "districts size equals count for id %d" % cid)
		assert_gt(cnt, 0, "country %d owns land" % cid)
		for k: int in range(1, d.size()):
			assert_lt(d[k - 1], d[k], "districts are sorted ascending")
		for idx: int in d:
			assert_eq(int(g.state.owner[idx]), cid)
			assert_eq(int(g.map.land[idx]), 1)
		total_owned += cnt
	assert_eq(total_owned + ScenarioFixture.UNOWNED_HEXES.size(), 54, "all 54 land hexes accounted for")

	assert_eq(Territory.districts(g, 0).size(), 0)
	assert_eq(Territory.count(g, 0), 0)
	assert_eq(Territory.neighbours(g, 0).size(), 0)

	# Neighbours are ascending, exclude 0 (unowned) and self.
	assert_eq(Territory.neighbours(g, 1), PackedInt32Array([2]))
	assert_eq(Territory.neighbours(g, 2), PackedInt32Array([1, 3]))
	assert_eq(Territory.neighbours(g, 3), PackedInt32Array([2]))

	# Transferring a BBB hex bordering OUT to AAA makes AAA and OUT neighbours.
	var border_hex := Vector2i(6, 2)
	assert_eq(Territory.owner_id(g, border_hex), 2)
	assert_eq(Territory.transfer(g, [border_hex], 1), 1)
	assert_eq(Territory.neighbours(g, 1), PackedInt32Array([2, 3]))
	assert_eq(Territory.neighbours(g, 3), PackedInt32Array([1, 2]))


func test_neighbours_are_cached_and_follow_the_owner_bytes() -> void:
	var g := EconomyFixture.game(&"GEN")
	for c: Country in g.countries:
		assert_eq(Territory.neighbours(g, c.id), Territory._neighbours_of(g, c.id), "cached equals worked out: %s" % c.tag)
		assert_eq(Territory.neighbours(g, c.id), Territory._neighbours_of(g, c.id), "and again")
	var genoa := Countries.by_tag(g, &"GEN")
	var before := Territory.neighbours(g, genoa.id)
	# a direct edit of an owner byte (no door): the next call sees it
	for i: int in Territory.districts(g, genoa.id):
		g.state.owner[i] = 0
	assert_eq(Territory.neighbours(g, genoa.id), PackedInt32Array(), "a country with no land has no neighbour")
	assert_gt(before.size(), 0)
