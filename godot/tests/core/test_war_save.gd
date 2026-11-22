## The war state through the save body (docs/architecture/m7-build-spec.md 4.20, 9; M7 plan B13): a live war made in a test is
## saved and loaded byte-equal and keeps its digest; a forged or damaged war body is refused with the body problem and the
## live game is not changed; a sandbox body keeps its empty war and refuses a name in it.
extends GutTest


func _through_bytes(body: Dictionary) -> Dictionary:
	return bytes_to_var(var_to_bytes(body)) as Dictionary


func _restore(g: Game, body: Dictionary) -> Dictionary:
	return Snapshot.restore(body, g.map, g.defs)


func test_a_live_war_round_trips_and_the_digest_carries_it() -> void:
	var g := WarFixture.game()
	var nb := WarFixture.neighbour_of(g, ArmyFixture.TAG)
	assert_ne(nb, &"", "Genoa has a neighbour")
	var empty_digest := g.digest()
	WarFixture.at_war(g, ArmyFixture.TAG, nb)
	assert_ne(g.digest(), empty_digest, "the war is in the digest")
	var body := Snapshot.of(g)
	var r := _restore(g, _through_bytes(body))
	assert_not_null(r["game"], str(r["problem"]))
	var back := r["game"] as Game
	assert_eq(back.digest(), g.digest(), "the loaded game has the same digest")
	assert_true(Wars.at_war(back, ArmyFixture.TAG, nb), "the war is still on after the load")
	assert_eq(var_to_bytes(Snapshot.of(back)), var_to_bytes(body), "save, load, save: byte-equal")


func test_a_forged_war_is_refused_and_the_live_game_keeps_its_digest() -> void:
	var g := WarFixture.game()
	var nb := WarFixture.neighbour_of(g, ArmyFixture.TAG)
	WarFixture.at_war(g, ArmyFixture.TAG, nb)
	var live := g.digest()
	var body := _through_bytes(Snapshot.of(g))
	var wars := (body["war"] as Dictionary)["wars"] as Array
	(wars[0] as Dictionary)["b"] = "ZZZ"  # a country the game does not have
	var r := _restore(g, body)
	assert_null(r["game"], "a war with an unknown country is refused")
	assert_eq(r["problem"], Snapshot.PROBLEM_UNREADABLE, "as the body problem")
	assert_eq(g.digest(), live, "the live game is not changed")


func test_a_damaged_war_body_is_refused() -> void:
	var g := WarFixture.game()
	WarFixture.at_war(g, ArmyFixture.TAG, WarFixture.neighbour_of(g, ArmyFixture.TAG))
	var wrong_schema := _through_bytes(Snapshot.of(g))
	(wrong_schema["war"] as Dictionary)["schema"] = "hexa-godot/war/0"
	assert_eq(_restore(g, wrong_schema)["problem"], Snapshot.PROBLEM_UNREADABLE, "a wrong schema")
	var id_not_below := _through_bytes(Snapshot.of(g))
	(id_not_below["war"] as Dictionary)["next_war_id"] = 1  # the war's id 1 is not below the next id
	assert_eq(_restore(g, id_not_below)["problem"], Snapshot.PROBLEM_UNREADABLE, "a war id not below next_war_id")
	var no_war := _through_bytes(Snapshot.of(g))
	no_war.erase("war")
	assert_eq(_restore(g, no_war)["problem"], Snapshot.PROBLEM_UNREADABLE, "a format-5 body without its war key")


func test_a_sandbox_body_keeps_its_empty_war_and_refuses_a_name_in_it() -> void:
	var fx := ScenarioFixture.build()
	var sandbox := Game.new_game(fx["map"] as MapData, 7, fx["defs"] as GameDefs)
	var body := _through_bytes(Snapshot.of(sandbox))
	var r := _restore(sandbox, body)
	assert_not_null(r["game"], str(r["problem"]))
	assert_eq((r["game"] as Game).digest(), sandbox.digest(), "the sandbox keeps its digest")
	((body["war"] as Dictionary)["battle_names"] as Dictionary)["Nowhere"] = 1
	assert_eq(_restore(sandbox, body)["problem"], Snapshot.PROBLEM_UNREADABLE, "a sandbox has no place names")


# ----- the occupation and the garrisons (4.3, 4.4): the forged cases of the review, and the legal states that must load -----


## A war game with a neighbour at war with Genoa, and the indices the cases need: a plain land hex of Genoa, a fortress of the
## map (-1 when none), and a country with no war with Genoa (the stranger).
func _war_world() -> Dictionary:
	var g := WarFixture.game()
	var foe := WarFixture.neighbour_of(g, ArmyFixture.TAG)
	WarFixture.at_war(g, ArmyFixture.TAG, foe)
	var fort := g.war_cache.fortresses(g)
	var owned := Territory.districts(g, ArmyFixture.id_of(g, ArmyFixture.TAG))
	var plain := -1
	for i: int in owned:
		if not fort.has(i):
			plain = i
			break
	var top := fort[0] if not fort.is_empty() else -1
	return {"game": g, "foe": foe, "plain": plain, "fort": top, "stranger": WarFixture.stranger_of(g, ArmyFixture.TAG)}


func _body_with_occupier(g: Game, i: int, value: int) -> Dictionary:
	var body := _through_bytes(Snapshot.of(g))
	var ms := body["map_state"] as Dictionary
	var raw := Marshalls.base64_to_raw(str(ms["occupier"]))
	raw[i] = value
	ms["occupier"] = Marshalls.raw_to_base64(raw)
	return body


func _body_with_garrison(g: Game, i: int, value: int) -> Dictionary:
	var body := _through_bytes(Snapshot.of(g))
	var ms := body["map_state"] as Dictionary
	var gar := (ms["garrison"] as PackedInt32Array).duplicate()
	gar[i] = value
	ms["garrison"] = gar
	return body


## The body is refused with the body problem and the live game keeps its digest.
func _refused_and_unchanged(g: Game, body: Dictionary, label: String) -> void:
	var live := g.digest()
	var r := _restore(g, body)
	assert_null(r["game"], label)
	assert_eq(r["problem"], Snapshot.PROBLEM_UNREADABLE, label)
	assert_eq(g.digest(), live, label + ": the live game is not changed")


func test_an_occupier_that_is_no_country_is_refused() -> void:
	var w := _war_world()
	_refused_and_unchanged(w["game"], _body_with_occupier(w["game"], w["plain"], 200), "occupier 200 is no country")


func test_an_occupier_that_is_the_owner_is_refused() -> void:
	var w := _war_world()
	var g := w["game"] as Game
	var owner := int(g.state.owner[w["plain"]])
	_refused_and_unchanged(g, _body_with_occupier(g, w["plain"], owner), "occupier equal to the owner")


func test_an_occupation_with_no_war_between_the_two_is_refused() -> void:
	var w := _war_world()
	var g := w["game"] as Game
	var stranger := Countries.by_tag(g, w["stranger"]).id
	_refused_and_unchanged(g, _body_with_occupier(g, w["plain"], stranger), "an occupier with no war with the owner")


func test_an_occupation_of_unowned_land_is_refused() -> void:
	var w := _war_world()
	var g := w["game"] as Game
	# The north Italy fixture has no unowned land: the test makes one (a test's state) and occupies it.
	var i: int = w["plain"]
	g.state.owner[i] = 0
	_refused_and_unchanged(g, _body_with_occupier(g, i, 1), "an occupation of unowned land")


func test_a_garrison_of_two_billion_on_a_plain_hex_is_refused() -> void:
	var w := _war_world()
	_refused_and_unchanged(w["game"], _body_with_garrison(w["game"], w["plain"], 2000000000), "garrison 2e9 on a plain hex")


func test_a_negative_garrison_on_a_fortress_is_refused() -> void:
	var w := _war_world()
	assert_ne(w["fort"], -1, "the fixture has a fortress")
	_refused_and_unchanged(w["game"], _body_with_garrison(w["game"], w["fort"], -5), "garrison -5 on a fortress")


func test_a_garrison_of_two_billion_on_a_fortress_is_refused() -> void:
	var w := _war_world()
	_refused_and_unchanged(w["game"], _body_with_garrison(w["game"], w["fort"], 2000000000), "garrison 2e9 on a fortress")


func test_a_garrison_past_the_top_level_cap_is_refused() -> void:
	var w := _war_world()
	var g := w["game"] as Game
	var cap := Snapshot.FORTRESS_TOP * g.defs.war.garrison_per_level
	_refused_and_unchanged(g, _body_with_garrison(g, w["fort"], cap + 1), "one man past the cap")


func test_a_garrison_at_sea_is_refused() -> void:
	var w := _war_world()
	var g := w["game"] as Game
	var sea := -1
	for i: int in g.map.hex_count():
		if g.map.land[i] == 0:
			sea = i
			break
	_refused_and_unchanged(g, _body_with_garrison(g, sea, 1), "a garrison at sea")


func test_a_legal_occupation_at_war_loads_with_its_digest() -> void:
	var w := _war_world()
	var g := w["game"] as Game
	WarFixture.set_occupier(g, g.map.hex_of(w["plain"]), w["foe"])
	var r := _restore(g, _through_bytes(Snapshot.of(g)))
	assert_not_null(r["game"], str(r["problem"]))
	assert_eq((r["game"] as Game).digest(), g.digest(), "an occupation at war loads with the same digest")


func test_a_legal_fortress_at_level_zero_with_its_garrison_loads() -> void:
	# A fortress that lost its level keeps its men: the garrison is within the top level's cap, the fortress is level 0.
	var w := _war_world()
	var g := w["game"] as Game
	var i: int = w["fort"]
	assert_ne(i, -1, "the fixture has a fortress")
	g.state.level[i] = 0
	g.state.garrison[i] = g.defs.war.garrison_per_level
	assert_eq(Occupation.fortress_level(g, g.map.hex_of(i)), 0, "the fortress is at level 0 now")
	var r := _restore(g, _through_bytes(Snapshot.of(g)))
	assert_not_null(r["game"], str(r["problem"]))
	assert_eq((r["game"] as Game).digest(), g.digest(), "a level-0 fortress with its garrison loads")
