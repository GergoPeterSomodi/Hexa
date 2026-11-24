## Sight, explored, witnesses (docs/architecture/m6-build-spec.md 4.11, 5.0 R4, R11, 5.3, 9; fog spec R6 to R17, R30): the start
## (the land sight or the regions), sight by control, discovery at once for a captured district, an owner change and a
## release, the land kinds' witnesses, the army part, the disc table, the save size check. Planted faults use their own
## copies (a fresh game per case), never a shared def; a case marked (P) is the planted fault it would catch.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const GEN := &"GEN"
const SAV := &"SAV"
const MLO := &"MLO"
const VEN := &"VEN"

var _g: Game = null


func before_each() -> void:
	_g = _new_game(false, &"")


## A north Italy game with Genoa chosen. `no_regions` clears the regions (R7); `drop` removes that country's discovery
## entry (R6). The scenario is a copy, so the shared def is never changed.
func _new_game(no_regions: bool, drop: StringName) -> Game:
	var defs := EconomyFixture.defs()  # calm weather, as the other 1480 tests
	var base := defs.scenarios[defs.scenarios.size() - 1] as ScenarioDef
	var sc := base.duplicate(true) as ScenarioDef
	if no_regions:
		var none: Array[StringName] = []
		sc.regions = none
		sc.region = PackedByteArray()
	var kept: Array[Dictionary] = []
	for e: Dictionary in sc.discovery:
		if StringName(e.get("tag", &"")) != drop and not no_regions:
			kept.append(e)
	sc.discovery = kept
	var g := Game.new_scenario(load(MAP_PATH) as MapData, defs, sc, 1480)
	assert_true(bool(g.act("choose_country", {"tag": GEN})["ok"]))
	return g


## The bitset of every hex of the map set (the whole map, north Italy's start).
func _full_bits() -> PackedByteArray:
	var n := _g.map.hex_count()
	var bits := PackedByteArray()
	bits.resize((n + 7) >> 3)
	bits.fill(0)
	for i: int in n:
		bits[i >> 3] = bits[i >> 3] | (1 << (i & 7))
	return bits


## The bitset of the controlled hexes of `tag` and their rings, read straight from the controller of each hex (no cache).
func _brute_land(game: Game, tag: StringName) -> PackedByteArray:
	var c := Countries.by_tag(game, tag)
	var n := game.map.hex_count()
	var bits := PackedByteArray()
	bits.resize((n + 7) >> 3)
	bits.fill(0)
	for i: int in n:
		if c != null and Occupation.controller_id(game, game.map.hex_of(i)) == c.id:
			for j: int in SightCache.disc(game.map, i, game.defs.land_sight):
				bits[j >> 3] = bits[j >> 3] | (1 << (j & 7))
	return bits


## The first land hex Genoa does not see (a hex nobody of its own holds or borders), or (-1, -1).
func _unseen_land() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if _g.map.is_land(hex) and not Sight.sees(_g, GEN, hex):
			return hex
	return Vector2i(-1, -1)


## Up to `count` land hexes Genoa has not explored (after FogFixture.thin, the deep fog of the thin start).
func _unexplored(count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in _g.map.hex_count():
		if out.size() >= count:
			break
		var hex := _g.map.hex_of(i)
		if _g.map.is_land(hex) and not Sight.explored(_g, GEN, hex):
			out.append(hex)
	return out


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


func _disc_of(hex: Vector2i, radius: int) -> PackedInt32Array:
	return SightCache.disc(_g.map, _g.map.index_of(hex), radius)


## Makes `tag`'s ring of hexes its own land, so the hex is held by it alone: returns the hex (a land hex of `tag`).
func _enclave_of(tag: StringName, to: StringName) -> Vector2i:
	var c := Countries.by_tag(_g, tag)
	var target := Countries.by_tag(_g, to)
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if _g.map.is_land(hex) and Occupation.controller_id(_g, hex) == c.id:
			var ring: Array[Vector2i] = []
			for j: int in SightCache.disc(_g.map, i, 1):
				if j != i:
					ring.append(_g.map.hex_of(j))
			Territory.transfer(_g, ring, target.id)
			return hex
	return Vector2i(-1, -1)


func test_disc_counts_the_hexes_within_a_radius() -> void:
	var i := _g.map.index_of(Vector2i(4, 3))
	assert_eq(SightCache.disc(_g.map, i, 0).size(), 1, "the hex alone")
	assert_eq(SightCache.disc(_g.map, i, 1).size(), 7, "the hex and its six neighbours")
	assert_eq(SightCache.disc(_g.map, i, 2).size(), 19)
	var corner: PackedInt32Array = SightCache.disc(_g.map, _g.map.index_of(Vector2i(0, 0)), 1)
	assert_eq(corner.size(), 3, "the map's edge cuts the disc")


func test_the_start_of_north_italy_is_the_whole_map_for_every_country() -> void:
	# R6: north Italy's one region holds every hex, and every country's discovery entry names it.
	var full := _full_bits()
	for c: Country in _g.countries:
		if c == null or c.tag == &"":
			continue
		assert_eq(c.explored, full, "%s starts knowing the whole map" % c.tag)


func test_a_country_with_no_discovery_entry_starts_with_its_land_sight_only() -> void:
	# R6, the other case: SAV has no entry, so its start is its land sight (P: setup that ignores discovery).
	var g := _new_game(false, SAV)
	var sav := Countries.by_tag(g, SAV)
	assert_eq(sav.explored, g.sight.land_of(g, sav.id), "SAV starts with its land sight")
	assert_false(sav.explored == _full_bits(), "P: not the whole map")
	assert_eq(Countries.by_tag(g, GEN).explored, _full_bits(), "GEN keeps its entry: the whole map")
	assert_true(Sight.explored(g, SAV, sav.capital), "the capital is explored")


func test_a_scenario_with_no_regions_starts_with_the_land_sight_only() -> void:
	# R7: no regions, no discovery: the land sight alone (P: a fake game whose explored is the whole map).
	var g := _new_game(true, &"")
	var gen := Countries.by_tag(g, GEN)
	assert_eq(gen.explored, g.sight.land_of(g, gen.id), "the land sight and nothing more")
	assert_false(gen.explored == _full_bits(), "P: not the whole map")


func test_explored_has_the_saved_size() -> void:
	var gen := Countries.by_tag(_g, GEN)
	assert_eq(gen.explored.size(), (_g.map.hex_count() + 7) >> 3, "one bit a hex")


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
	FogFixture.thin(_g, GEN, 0)
	var gen := Countries.by_tag(_g, GEN)
	var before := gen.explored.duplicate()
	var unseen := _unseen_land()
	_g.armies.append(_army(GEN, unseen))
	Sight.refresh(_g)
	assert_eq(gen.explored, before, "refresh leaves explored alone (R4)")
	assert_false(Sight.explored(_g, GEN, unseen), "the army's hex is not explored until the vision phase")


func test_the_vision_phase_adds_the_army_part_to_explored() -> void:
	FogFixture.thin(_g, GEN, 0)
	var unseen := _unseen_land()
	_g.armies.append(_army(GEN, unseen))
	Sight.season(_g)
	assert_true(Sight.explored(_g, GEN, unseen), "the vision phase explores what the army sees")


func test_see_path_marks_the_steps_and_their_rings() -> void:
	FogFixture.thin(_g, GEN, 0)
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


func test_an_owner_change_explores_the_gain_at_once() -> void:
	# R10: the new owner's hex and its ring are explored by the transfer itself, before any season (P: a cession that reads
	# as Unexplored until the next season).
	FogFixture.thin(_g, GEN, 0)
	var gen := Countries.by_tag(_g, GEN)
	var unseen := _unseen_land()
	assert_false(Sight.explored(_g, GEN, unseen))
	var moved: Array[Vector2i] = [unseen]
	assert_eq(Territory.transfer(_g, moved, gen.id), 1, "the hex changes hands")
	assert_true(Sight.explored(_g, GEN, unseen), "explored at once")
	assert_true(Sight.sees(_g, GEN, unseen), "and held: seen now")
	var neighbour := _g.map.hex_of(SightCache.disc(_g.map, _g.map.index_of(unseen), 1)[1])
	assert_true(Sight.explored(_g, GEN, neighbour), "and its ring")
	Sight.season(_g)
	assert_true(Sight.explored(_g, GEN, unseen), "the vision phase keeps it")


func test_a_district_captured_is_explored_by_its_taker_at_once_for_every_kind() -> void:
	# R9: walk-in, siege, storm and retaken, each through the real producer (Occupation.capture). P: the mark left to the
	# next vision phase.
	FogFixture.thin(_g, GEN, 0)
	var hexes := _unexplored(4)
	assert_eq(hexes.size(), 4, "four undiscovered land hexes")
	var kinds: Array[StringName] = [&"walk", &"siege", &"storm", &"retaken"]
	for k: int in kinds.size():
		var hex := hexes[k]
		Occupation.capture(_g, hex, GEN, kinds[k], {})
		assert_true(Sight.sees(_g, GEN, hex), "%s: the taker sees it" % kinds[k])
		assert_true(Sight.explored(_g, GEN, hex), "%s: the taker has explored it" % kinds[k])
		for j: int in SightCache.disc(_g.map, _g.map.index_of(hex), 1):
			assert_true(SightCache.bit_is(Countries.by_tag(_g, GEN).explored, j), "%s: and its ring" % kinds[k])
		var last: Dictionary = _g.events[_g.events.size() - 1]
		assert_eq(str(last.get("kind", "")), "district_captured", "%s: the event is queued" % kinds[k])
		assert_true(bool(last.get("land", false)), "%s: a land fact" % kinds[k])


func test_a_conquered_hex_is_in_sight_of_its_conqueror_and_not_of_the_old_owner() -> void:
	# R14, R15: an enclave of Venice taken by Milan: Milan sees it and its ring in the same phase; Venice has explored it
	# and does not see it (no Venetian hex around it). P: the old owner still sees the hex.
	var hex := _enclave_of(VEN, GEN)
	assert_ne(hex, Vector2i(-1, -1), "Venice holds a hex")
	Occupation.capture(_g, hex, MLO, &"walk", {})
	assert_true(Sight.sees(_g, MLO, hex), "R14: the conqueror sees the hex")
	for j: int in SightCache.disc(_g.map, _g.map.index_of(hex), 1):
		assert_true(Sight.sees(_g, MLO, _g.map.hex_of(j)), "R14: and its ring")
	assert_true(Sight.explored(_g, VEN, hex), "R15: Venice has discovered the hex")
	assert_false(Sight.sees(_g, VEN, hex), "R15: the old owner keeps it in light fog")


func test_a_release_explores_for_the_owner_at_once() -> void:
	# R10, R17: a hex of Venice that Genoa occupies is out of Venice's sight once Venice's survey is made again (thin at
	# radius 0: the enclave has no Venetian neighbour). The release and its controllers_changed flush explore it for
	# Venice at once, before the vision phase.
	var hex := _enclave_of(VEN, GEN)
	assert_ne(hex, Vector2i(-1, -1), "Venice holds a hex")
	Occupation.capture(_g, hex, GEN, &"walk", {})
	Occupation.flush(_g)  # the capture's own controllers_changed (a phase's end); then the survey
	FogFixture.thin(_g, VEN, 0)
	assert_false(Sight.explored(_g, VEN, hex), "Venice's survey does not reach the occupied hex")
	var release: Array[Vector2i] = [hex]
	Occupation.release(_g, release)
	Occupation.flush(_g)
	var last: Dictionary = _g.events[_g.events.size() - 1]
	assert_eq(str(last.get("kind", "")), "controllers_changed", "the flush names the control change")
	assert_true(Sight.explored(_g, VEN, hex), "R17: explored for Venice at once")
	assert_true(Sight.sees(_g, VEN, hex), "and in sight")


func test_the_land_cache_follows_control_after_a_capture() -> void:
	# R16: the cached land sight of the two countries a capture names is forgotten, so it equals the brute reading.
	var hex := _enclave_of(VEN, GEN)
	assert_ne(hex, Vector2i(-1, -1))
	var before := _g.sight.land_of(_g, Countries.by_tag(_g, VEN).id)
	assert_eq(before, _brute_land(_g, VEN), "the land sight before the capture is the brute one")
	Occupation.capture(_g, hex, MLO, &"walk", {})
	Occupation.flush(_g)
	assert_eq(_g.sight.land_of(_g, Countries.by_tag(_g, VEN).id), _brute_land(_g, VEN), "Venice's land sight follows control")
	assert_eq(_g.sight.land_of(_g, Countries.by_tag(_g, MLO).id), _brute_land(_g, MLO), "Milan's land sight follows control")


func test_explored_only_grows_and_its_revision_follows_it() -> void:
	FogFixture.thin(_g, GEN, 0)
	var rev := _g.sight.explored_revision(Countries.by_tag(_g, GEN).id)
	var hex := _unexplored(1)[0]
	var moved: Array[Vector2i] = [hex]
	Territory.transfer(_g, moved, Countries.by_tag(_g, GEN).id)
	assert_gt(_g.sight.explored_revision(Countries.by_tag(_g, GEN).id), rev, "the revision grows with the explored set")


func test_witnesses_are_the_countries_whose_sight_held_the_hex() -> void:
	var capital := Countries.by_tag(_g, GEN).capital
	var event := {"kind": "army_raised", "tag": SAV, "hex": capital}
	_g.emit(event)
	var witnesses: PackedStringArray = event["witnesses"]
	assert_true(witnesses.has("GEN"), "Genoa holds the hex")
	assert_true(witnesses.has("SAV"), "the actor is always among them")
	var unseen := _unseen_land()
	var far := {"kind": "army_raised", "tag": SAV, "hex": unseen}
	_g.emit(far)
	assert_false((far["witnesses"] as PackedStringArray).has("GEN"), "P: a far country is not a witness")
	assert_true((far["witnesses"] as PackedStringArray).has("SAV"))


func test_a_land_kind_is_marked_land_and_gets_no_witness_list() -> void:
	# R30 (P: a land kind with a sight list). The six land kinds, emitted as the rules emit them.
	var capital := Countries.by_tag(_g, GEN).capital
	for kind: String in Sight.LAND_KINDS:
		var event := {"kind": kind, "tag": SAV, "hex": capital}
		_g.emit(event)
		assert_true(bool(event.get("land", false)), "%s is a land fact" % kind)
		assert_false(event.has("witnesses"), "%s has no sight list" % kind)
	var sighted := {"kind": "battle_ended", "tag": SAV, "hex": capital}
	_g.emit(sighted)
	assert_false(sighted.has("land"), "a battle is not a land fact")
	assert_true((sighted["witnesses"] as PackedStringArray).has("GEN"), "a battle keeps its witnesses")


func test_a_given_witness_list_is_kept() -> void:
	var event := {"kind": "siege_started", "tag": SAV, "hex": _unseen_land(), "witnesses": PackedStringArray(["FRA"])}
	_g.emit(event)
	assert_eq(event["witnesses"], PackedStringArray(["FRA"]))


func test_the_battle_and_siege_kinds_get_their_witnesses_when_they_have_none() -> void:
	# M7 (4.14): the battle and siege kinds are sighted kinds: an unlisted witness list is stamped.
	var capital := Countries.by_tag(_g, GEN).capital
	for kind: String in ["battle_started", "battle_fought", "battle_ended", "siege_started", "siege_progress",
			"siege_lifted"]:
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


func test_the_witnesses_follow_control_not_ownership() -> void:
	# R13 (P: a witness read from the owner byte): the enclave, after Milan took it, is witnessed by Milan and not by Venice,
	# the owner, which controls none of its disc.
	var hex := _enclave_of(VEN, GEN)
	Occupation.capture(_g, hex, MLO, &"walk", {})
	var witnesses := Sight.witnesses_of(_g, hex, &"")
	assert_true(witnesses.has("MLO"), "the controller witnesses")
	assert_false(witnesses.has("VEN"), "P: the owner, which no longer controls the disc, does not")
	var event := {"kind": "siege_started", "tag": SAV, "hex": hex}
	_g.emit(event)
	assert_false((event["witnesses"] as PackedStringArray).has("VEN"), "a sighted event at the hex: no Venice")


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
	for kind: String in ["siege_started", "siege_progress", "siege_lifted"]:
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
	FogFixture.thin(_g, GEN, 0)
	var unseen := _unseen_land()
	var moved: Array[Vector2i] = [unseen]
	assert_eq(_g.dev_transfer(moved, gen.id), 1, "the land changes hands")
	var loaded := Snapshot.restore(Snapshot.of(_g), map, defs)["game"] as Game
	assert_not_null(loaded, "the game saves and loads")
	assert_eq(loaded.digest(), _g.digest(), "equal before the season")
	Sight.season(_g)
	Sight.season(loaded)
	assert_true(Sight.explored(loaded, GEN, unseen), "the loaded game explores the gain")
	assert_eq(loaded.digest(), _g.digest(), "live and loaded agree after the season")


func test_witnesses_agree_with_sees_for_every_country() -> void:
	# By control: an occupied hex (Genoa took it) and an army of Savoy's are in the set with an unseen hex and the capital.
	var occupied := _unseen_land()
	Occupation.capture(_g, occupied, GEN, &"walk", {})
	_g.armies.append(_army(SAV, _unseen_land()))
	Sight.refresh(_g)
	var hexes: Array[Vector2i] = [Countries.by_tag(_g, GEN).capital, _unseen_land(), occupied]
	for hex: Vector2i in hexes:
		var brute: PackedStringArray = []
		for c: Country in _g.countries:
			if c != null and c.tag != &"" and Sight.sees(_g, c.tag, hex):
				brute.append(String(c.tag))
		assert_eq(Sight.witnesses_of(_g, hex, &""), brute, "the disc reads give the same tags as a loop (%s)" % hex)
