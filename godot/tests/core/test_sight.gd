## Sight, explored, witnesses (docs/architecture/m6-build-spec.md 4.11, 5.0 R4, R11, 5.3, 9): the explored start equals M3's
## border rule on the 1480 scenario; sees (land, armies); explored only by setup, see_path and season; owners changed
## forget and gain; witnesses by sight at the time; the army part rebuilt by refresh; the disc table; the save size check.
## Planted faults use their own copies (a fresh game per case), never a shared def.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const GEN := &"GEN"
const SAV := &"SAV"

var _g: Game = null


func before_each() -> void:
	var defs := EconomyFixture.defs()  # calm weather, as the other 1480 tests
	_g = Game.new_scenario(load(MAP_PATH) as MapData, defs, defs.scenarios[defs.scenarios.size() - 1], 1480)
	assert_true(bool(_g.act("choose_country", {"tag": GEN})["ok"]))


## The first land hex Genoa does not see (a hex nobody of its own holds or borders), or (-1, -1).
func _unseen_land() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if _g.map.is_land(hex) and not Sight.sees(_g, GEN, hex):
			return hex
	return Vector2i(-1, -1)


func _army(tag: StringName, hex: Vector2i, men: int = 400) -> Army:
	var a := Army.new()
	a.id = _g.next_army_id
	_g.next_army_id += 1
	a.tag = tag
	a.hex = hex
	var u := Unit.new()
	u.id = _g.next_unit_id
	_g.next_unit_id += 1
	u.kind = 0
	u.men = men
	u.home = hex
	a.units.append(u)
	return a


func test_disc_counts_the_hexes_within_a_radius() -> void:
	var i := _g.map.index_of(Vector2i(4, 3))
	assert_eq(SightCache.disc(_g.map, i, 0).size(), 1, "the hex alone")
	assert_eq(SightCache.disc(_g.map, i, 1).size(), 7, "the hex and its six neighbours")
	assert_eq(SightCache.disc(_g.map, i, 2).size(), 19)
	var corner: PackedInt32Array = SightCache.disc(_g.map, _g.map.index_of(Vector2i(0, 0)), 1)
	assert_eq(corner.size(), 3, "the map's edge cuts the disc")


func test_the_explored_start_equals_the_border_rule_for_every_pair() -> void:
	for a: Country in _g.countries:
		if a == null or a.tag == &"":
			continue
		for b: Country in _g.countries:
			if b == null or b.tag == &"" or b.tag == a.tag:
				continue
			var border := Territory.neighbours(_g, a.id).has(b.id)
			assert_eq(Knowledge.knows(_g, a.tag, b.tag), border,
				"%s knows %s at the start is the shared border (4.11)" % [a.tag, b.tag])


func test_explored_holds_the_land_sight_at_the_start_and_has_the_saved_size() -> void:
	var gen := Countries.by_tag(_g, GEN)
	var capital := gen.capital
	assert_true(Sight.explored(_g, GEN, capital), "the capital is explored")
	assert_eq(gen.explored.size(), (_g.map.hex_count() + 7) >> 3, "one bit a hex")
	for j: int in SightCache.disc(_g.map, _g.map.index_of(capital), _g.defs.land_sight):
		assert_true(SightCache.bit_is(gen.explored, j), "the land sight of the capital is explored")


func test_sees_the_held_hexes_and_their_rings_only() -> void:
	assert_true(Sight.sees(_g, GEN, Countries.by_tag(_g, GEN).capital))
	var unseen := _unseen_land()
	assert_ne(unseen, Vector2i(-1, -1))
	assert_false(Sight.sees(_g, GEN, unseen), "a hex far from Genoa's land is not seen")
	assert_false(Sight.sees(_g, &"", unseen), "the empty tag sees nothing here")


func test_an_army_sees_its_hex_after_refresh_and_not_before() -> void:
	var unseen := _unseen_land()
	assert_false(Sight.sees(_g, GEN, unseen))
	_g.armies.append(_army(GEN, unseen))
	Sight.refresh(_g)
	assert_true(Sight.sees(_g, GEN, unseen), "the army sees its own hex")
	assert_true(Sight.witnesses_of(_g, unseen, &"").has("GEN"), "and is a witness there")


func test_refresh_never_writes_explored() -> void:
	var gen := Countries.by_tag(_g, GEN)
	var before := gen.explored.duplicate()
	var unseen := _unseen_land()
	_g.armies.append(_army(GEN, unseen))
	Sight.refresh(_g)
	assert_eq(gen.explored, before, "refresh leaves explored alone (R4)")
	assert_false(Sight.explored(_g, GEN, unseen), "the army's hex is not explored until the vision phase")


func test_the_vision_phase_adds_the_army_part_to_explored() -> void:
	var unseen := _unseen_land()
	_g.armies.append(_army(GEN, unseen))
	Sight.season(_g)
	assert_true(Sight.explored(_g, GEN, unseen), "the vision phase explores what the army sees")


func test_see_path_marks_the_steps_and_their_rings() -> void:
	var unseen := _unseen_land()
	assert_false(Sight.explored(_g, GEN, unseen))
	var path: Array[Vector2i] = [unseen]
	Sight.see_path(_g, GEN, path, 0)
	assert_true(Sight.explored(_g, GEN, unseen), "the step itself")
	var far := _unseen_land()
	var ring: Array[Vector2i] = [far]
	var neighbour := _g.map.hex_of(SightCache.disc(_g.map, _g.map.index_of(far), 1)[1])
	Sight.see_path(_g, GEN, ring, 1)
	assert_true(Sight.explored(_g, GEN, neighbour), "a step's ring at radius 1")


func test_an_owner_change_explores_the_gain_at_the_vision_phase() -> void:
	var gen := Countries.by_tag(_g, GEN)
	var unseen := _unseen_land()
	assert_false(Sight.explored(_g, GEN, unseen))
	var moved: Array[Vector2i] = [unseen]
	assert_eq(Territory.transfer(_g, moved, gen.id), 1, "the hex changes hands")
	assert_false(Sight.explored(_g, GEN, unseen), "not explored until the vision phase")
	assert_true(Sight.sees(_g, GEN, unseen), "but held: seen now (the owner bytes)")
	Sight.season(_g)
	assert_true(Sight.explored(_g, GEN, unseen), "the vision phase takes the gain and its ring")


func test_witnesses_are_the_countries_whose_sight_held_the_hex() -> void:
	var capital := Countries.by_tag(_g, GEN).capital
	var event := {"kind": "work_finished", "tag": SAV, "hex": capital}
	_g.emit(event)
	var witnesses: PackedStringArray = event["witnesses"]
	assert_true(witnesses.has("GEN"), "Genoa holds the hex")
	assert_true(witnesses.has("SAV"), "the actor is always among them")
	var unseen := _unseen_land()
	var far := {"kind": "work_finished", "tag": SAV, "hex": unseen}
	_g.emit(far)
	assert_false((far["witnesses"] as PackedStringArray).has("GEN"), "P: a far country is not a witness")
	assert_true((far["witnesses"] as PackedStringArray).has("SAV"))


func test_a_given_witness_list_is_kept() -> void:
	var event := {"kind": "work_finished", "tag": SAV, "hex": _unseen_land(), "witnesses": PackedStringArray(["FRA"])}
	_g.emit(event)
	assert_eq(event["witnesses"], PackedStringArray(["FRA"]))


func test_the_battle_and_siege_kinds_get_their_witnesses_when_they_have_none() -> void:
	# M7 (4.14): the battle, siege and district kinds are sighted kinds: an unlisted witness list is stamped.
	var capital := Countries.by_tag(_g, GEN).capital
	for kind: String in ["battle_started", "battle_fought", "battle_ended", "siege_started", "siege_progress",
			"siege_lifted", "district_captured"]:
		var event := {"kind": kind, "tag": SAV, "hex": capital}
		_g.emit(event)
		assert_true(event.has("witnesses"), "%s is stamped" % kind)
		assert_true((event["witnesses"] as PackedStringArray).has("GEN"), "%s: Genoa holds the hex" % kind)
	var unseen := _unseen_land()
	var far := {"kind": "battle_ended", "tag": SAV, "hex": unseen}
	_g.emit(far)
	assert_false((far["witnesses"] as PackedStringArray).has("GEN"), "P: an unseen battle is not witnessed by Genoa")
	var plain := {"kind": "peace_made", "tag": SAV, "hex": capital}
	_g.emit(plain)
	assert_false(plain.has("witnesses"), "peace_made is not a sighted kind (its witnesses are every living country)")


func test_the_others_of_a_sighted_event_witness_even_when_they_do_not_see_the_hex() -> void:
	# M7 (4.14): the actor and the others always witness; an other that does not see the hex is still in the list.
	var unseen := _unseen_land()
	var seen_by := Sight.witnesses_of(_g, unseen, &"")
	var outsider := &""
	for c: Country in _g.countries:
		if c.tag != &"" and c.tag != GEN and not seen_by.has(String(c.tag)):
			outsider = c.tag
			break
	assert_ne(outsider, &"", "the scenario has a country that does not see the hex")
	assert_false(Sight.sees(_g, outsider, unseen), "the outsider does not see it")
	for kind: String in ["siege_started", "siege_progress", "siege_lifted", "district_captured"]:
		var event := {"kind": kind, "tag": SAV, "hex": unseen, "others": [outsider]}
		_g.emit(event)
		assert_true((event["witnesses"] as PackedStringArray).has(String(outsider)), "%s: the other witnesses" % kind)
		assert_true((event["witnesses"] as PackedStringArray).has("SAV"), "%s: the actor witnesses" % kind)
	var listed := {"kind": "siege_started", "tag": SAV, "hex": unseen, "others": [outsider], "witnesses": PackedStringArray(["FRA"])}
	_g.emit(listed)
	assert_eq(listed["witnesses"], PackedStringArray(["FRA"]), "a given witness list is kept")


func test_a_map_only_game_stamps_nothing() -> void:
	var bare := Game.new_game(load(MAP_PATH) as MapData, 1)
	var event := {"kind": "work_finished", "tag": SAV, "hex": Vector2i(4, 3)}
	bare.emit(event)
	assert_false(event.has("witnesses"), "no countries, no sight")
	assert_false(Sight.sees(bare, GEN, Vector2i(4, 3)))


func test_the_snapshot_refuses_an_explored_of_another_size() -> void:
	var defs := EconomyFixture.defs()
	var map := load(MAP_PATH) as MapData
	var body := Snapshot.of(_g)
	var first := Snapshot.restore(body, map, defs)
	assert_not_null(first["game"], "a saved game restores")
	var countries: Array = body["countries"]
	var planted: Dictionary = (countries[0] as Dictionary).duplicate(true)
	planted["explored"] = PackedByteArray([1, 2, 3])
	countries[0] = planted
	var bad := Snapshot.restore(body, map, defs)
	assert_null(bad["game"], "P: an explored of the wrong size is refused")
	assert_eq(bad["problem"], Snapshot.PROBLEM_UNREADABLE)


func test_a_dev_transfer_then_save_and_load_give_the_same_season() -> void:
	var defs := EconomyFixture.defs()
	var map := load(MAP_PATH) as MapData
	var gen := Countries.by_tag(_g, GEN)
	var unseen := _unseen_land()
	var moved: Array[Vector2i] = [unseen]
	assert_eq(_g.dev_transfer(moved, gen.id), 1, "the land changes hands")
	var loaded := Snapshot.restore(Snapshot.of(_g), map, defs)["game"] as Game
	assert_not_null(loaded, "the game saves and loads")
	assert_eq(loaded.digest(), _g.digest(), "equal before the season")
	Sight.season(_g)
	Sight.season(loaded)
	assert_true(Sight.explored(loaded, GEN, unseen), "the loaded game explores the gain at its vision phase")
	assert_eq(loaded.digest(), _g.digest(), "live and loaded agree after the season")


func test_witnesses_agree_with_sees_for_every_country() -> void:
	_g.armies.append(_army(SAV, _unseen_land()))
	Sight.refresh(_g)
	var hexes: Array[Vector2i] = [Countries.by_tag(_g, GEN).capital, _unseen_land()]
	for hex: Vector2i in hexes:
		var brute: PackedStringArray = []
		for c: Country in _g.countries:
			if c != null and c.tag != &"" and Sight.sees(_g, c.tag, hex):
				brute.append(String(c.tag))
		assert_eq(Sight.witnesses_of(_g, hex, &""), brute, "the disc reads give the same tags as a loop (%s)" % hex)
