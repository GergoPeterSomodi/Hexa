## Occupation (docs/architecture/m7-build-spec.md 4.3, 4.4, 4.5 (need, storm cut), D18, 5.3): the eighteen fortresses of north
## Italy on seed 1480 (the worked example of 4.3), the castle areas and their four states, the crest wall, capture, release,
## the one controllers_changed per batch, regrowth, the freed land (D18), the cache's drops, and planted faults (a copied war
## whose reach is cut, a warm cache that an event must drop). Mutating tests take a fresh game; the shared base is read only.
extends GutTest

## hex, owner, fortress level, garrison at full, area size (4.3's table, seed 1480).
const WORKED: Array = [
	[Vector2i(10, 3), &"SWI", 1, 400, 4],
	[Vector2i(1, 4), &"SAV", 2, 800, 9],
	[Vector2i(6, 4), &"SWI", 1, 400, 5],
	[Vector2i(13, 6), &"VEN", 2, 800, 7],
	[Vector2i(3, 7), &"SAV", 2, 800, 13],
	[Vector2i(18, 7), &"VEN", 3, 1200, 16],
	[Vector2i(15, 8), &"VEN", 2, 800, 6],
	[Vector2i(17, 8), &"VEN", 2, 800, 5],
	[Vector2i(9, 9), &"MLO", 3, 1200, 17],
	[Vector2i(10, 9), &"MLO", 2, 800, 7],
	[Vector2i(16, 10), &"FER", 2, 800, 6],
	[Vector2i(3, 12), &"FRA", 1, 400, 4],
	[Vector2i(16, 12), &"PAP", 2, 800, 7],
	[Vector2i(8, 13), &"GEN", 2, 800, 12],
	[Vector2i(11, 13), &"MLO", 2, 800, 5],
	[Vector2i(5, 14), &"SAV", 1, 400, 5],
	[Vector2i(15, 15), &"TUS", 2, 800, 7],
	[Vector2i(13, 16), &"TUS", 2, 800, 4],
]
## Held land by country (of its land) in the worked example: 139 of 340 in all.
const HELD: Dictionary = {&"SWI": 9, &"SAV": 27, &"VEN": 34, &"MLO": 29, &"FER": 6, &"FRA": 4, &"PAP": 7, &"GEN": 12, &"TUS": 11}
const GENEVA := Vector2i(1, 4)
const MILAN := Vector2i(9, 9)

static var _base: Game = null


## The shared 1480 game with its garrisons full. Read only.
func _base_game() -> Game:
	if _base == null:
		_base = EconomyFixture.game()
		Occupation.setup(_base)
	return _base


## A 1480 game that is yours to change, its garrisons full.
func _fresh() -> Game:
	var g := EconomyFixture.game()
	Occupation.setup(g)
	return g


func _id(g: Game, tag: StringName) -> int:
	return Countries.by_tag(g, tag).id


func _events(g: Game, kind: String) -> Array:
	var out: Array = []
	for e: Dictionary in g.events:
		if str(e.get("kind", "")) == kind:
			out.append(e)
	return out


## A land hex of `tag` that stands in no castle area and is not occupied.
func _open_hex(g: Game, tag: StringName) -> Vector2i:
	for i: int in Territory.districts(g, _id(g, tag)):
		var hex := g.map.hex_of(i)
		if Occupation.area_of(g, hex) == Army.NO_HEX and not Occupation.is_occupied(g, hex):
			return hex
	return Army.NO_HEX


func _index(g: Game, hex: Vector2i) -> int:
	return g.map.index_of(hex)


# --- the worked example (4.3) ----------------------------------------------------------------------------------------


func test_the_eighteen_fortresses_their_garrisons_and_areas_match_the_worked_example() -> void:
	var g := _base_game()
	assert_eq(g.war_cache.fortresses(g).size(), WORKED.size())
	for row: Array in WORKED:
		var hex: Vector2i = row[0]
		assert_eq(Territory.owner_tag(g, hex), row[1], "owner of %s" % str(hex))
		assert_eq(Occupation.fortress_level(g, hex), row[2], "level of %s" % str(hex))
		assert_eq(Occupation.garrison_of(g, hex), row[3], "garrison of %s" % str(hex))
		assert_eq(Occupation.garrison_full(g, hex), row[3], "full garrison of %s" % str(hex))
		assert_eq(Occupation.members(g, hex).size(), row[4], "area of %s" % str(hex))


func test_held_land_by_country_matches_the_worked_example() -> void:
	var g := _base_game()
	var held: Dictionary = {}
	var total := 0
	for c: Country in g.countries:
		var n := 0
		for i: int in Territory.districts(g, c.id):
			if Occupation.area_of(g, g.map.hex_of(i)) != Army.NO_HEX:
				n += 1
		if n > 0:
			held[c.tag] = n
			total += n
	assert_eq(held, HELD)
	assert_eq(total, 139)


func test_the_fortress_is_the_first_member_of_its_area() -> void:
	var g := _base_game()
	var members := Occupation.members(g, GENEVA)
	assert_eq(g.map.hex_of(members[0]), GENEVA)
	assert_eq(Occupation.area_of(g, GENEVA), GENEVA)


# --- the states of an area (4.3) -------------------------------------------------------------------------------------


func test_area_states_castle_held_and_open() -> void:
	var g := _base_game()
	var members := Occupation.members(g, GENEVA)
	assert_eq(Occupation.area_state(g, GENEVA), &"castle")
	assert_eq(Occupation.area_state(g, g.map.hex_of(members[1])), &"held")
	var owned := _open_hex(g, &"SAV")
	assert_eq(Occupation.area_state(g, owned), &"open", "land no fortress holds")


func test_an_area_becomes_fallen_when_its_fortress_is_taken_and_open_where_occupied() -> void:
	var g := _fresh()
	var members := Occupation.members(g, GENEVA)
	var inner := g.map.hex_of(members[1])
	Occupation.capture(g, GENEVA, &"FRA", &"siege", {"name": "Siege of Geneva", "seasons": 2, "opened": 0})
	assert_eq(Occupation.area_state(g, GENEVA), &"castle", "a fortress is a castle taken or not")
	assert_eq(Occupation.area_state(g, inner), &"fallen", "the owner's land of a taken fortress")
	assert_eq(Occupation.garrison_of(g, GENEVA), 0, "a taken fortress keeps no garrison")
	Occupation.capture(g, inner, &"FRA", &"walk", {})
	assert_eq(Occupation.area_state(g, inner), &"open", "an occupied member is open")


func test_the_standing_bytes_decide_held_without_a_live_read() -> void:
	var g := _base_game()
	var inner := g.map.hex_of(Occupation.members(g, GENEVA)[1])
	var stands := PackedByteArray()
	stands.resize(g.map.hex_count())
	stands.fill(0)
	assert_eq(Occupation.area_state(g, inner, stands), &"fallen", "the byte says the fortress does not stand")
	stands[_index(g, GENEVA)] = 1
	assert_eq(Occupation.area_state(g, inner, stands), &"held")
	assert_eq(Occupation.standing(g)[_index(g, GENEVA)], 1)


## A crest edge between a fortress and its member, with no pass, takes the member out of the walk's first step. The map
## is shared, so the edge is put back.
func test_a_crest_without_a_pass_stops_the_area_walk() -> void:
	var g := _fresh()
	var f := _index(g, GENEVA)
	var j := Occupation.members(g, GENEVA)[1]
	var d := -1
	for k: int in 6:
		if StepCosts.neighbour_index(g.map.cols, g.map.rows, f, k) == j:
			d = k
	assert_gt(d, -1)
	var e := StepCosts.edge_slot(f, d, j)
	var was_crest: int = g.map.crest[e]
	var was_pass: int = g.map.pass_edge[e]
	g.map.crest[e] = 1
	g.map.pass_edge[e] = 0
	g.war_cache.clear()
	var steps := g.war_cache.area_steps(g)[j]
	g.map.crest[e] = was_crest
	g.map.pass_edge[e] = was_pass
	g.war_cache.clear()
	assert_ne(steps, 1, "the member is not one step away across the crest")


func test_a_pass_on_the_crest_lets_the_walk_through() -> void:
	var g := _fresh()
	var f := _index(g, GENEVA)
	var j := Occupation.members(g, GENEVA)[1]
	var d := -1
	for k: int in 6:
		if StepCosts.neighbour_index(g.map.cols, g.map.rows, f, k) == j:
			d = k
	var e := StepCosts.edge_slot(f, d, j)
	var was_crest: int = g.map.crest[e]
	var was_pass: int = g.map.pass_edge[e]
	g.map.crest[e] = 1
	g.map.pass_edge[e] = 1
	g.war_cache.clear()
	var steps := g.war_cache.area_steps(g)[j]
	g.map.crest[e] = was_crest
	g.map.pass_edge[e] = was_pass
	g.war_cache.clear()
	assert_eq(steps, 1, "a pass is open to the walk")


## Planted fault: a copy of the war with its reach cut to zero gives every fortress an area of itself alone.
func test_a_planted_zero_reach_leaves_every_fortress_alone() -> void:
	var g := _fresh()
	g.defs.war.area_reach = PackedInt32Array([0, 0, 0, 0])
	g.war_cache.clear()
	assert_eq(Occupation.members(g, GENEVA).size(), 1)
	assert_eq(Occupation.area_state(g, g.map.hex_of(Occupation.members(g, GENEVA)[0])), &"castle")


## The fortress level of a piece: castles 1 to 3 by level, settlements 4 and 5 are walled town and city, others none.
func test_fortress_level_follows_the_piece() -> void:
	var g := _fresh()
	var hex := _open_hex(g, &"MLO")
	var i := _index(g, hex)
	var cases := [[2, 1, 1], [2, 2, 2], [2, 3, 3], [1, 4, 2], [1, 5, 3], [1, 3, 0], [2, 0, 0], [0, 0, 0]]
	for case: Array in cases:
		g.state.main_use[i] = case[0]
		g.state.level[i] = case[1]
		assert_eq(Occupation.fortress_level(g, hex), case[2], str(case))
	assert_eq(Occupation.garrison_full(g, hex), 0, "no fortress, no garrison")


func test_setup_fills_every_fortress_and_clears_the_occupation() -> void:
	var g := _fresh()
	Occupation.capture(g, GENEVA, &"FRA", &"siege", {})
	Occupation.setup(g)
	assert_eq(Occupation.garrison_of(g, GENEVA), 800)
	assert_eq(Occupation.controller_tag(g, GENEVA), &"SAV")
	assert_false(Occupation.is_occupied(g, GENEVA))


# --- storm and need (4.5, D19) ---------------------------------------------------------------------------------------


func test_siege_need_and_the_storm_cut() -> void:
	var g := _fresh()
	var i := _index(g, MILAN)
	var war := g.defs.war
	var need := 4 + 9 + war.relief_elevation[g.map.relief[i]]
	assert_eq(Occupation.siege_need(g, MILAN), need, "base 4, three per level at full garrison, relief")
	assert_eq(Occupation.storm_garrison(g, MILAN, &"SAV"), 1200, "no siege: the whole garrison")
	var s := Siege.new()
	s.hex = MILAN
	s.besieger = &"SAV"
	s.progress = need
	g.sieges.append(s)
	assert_eq(Occupation.storm_garrison(g, MILAN, &"SAV"), 600, "half the share done: half the garrison")
	assert_eq(Occupation.storm_garrison(g, MILAN, &"VEN"), 1200, "a storm by one who besieges nothing faces all")
	s.progress = 0
	assert_eq(Occupation.storm_garrison(g, MILAN, &"SAV"), 1200)


func test_besieged_needs_a_siege_by_a_country_at_war_with_the_controller() -> void:
	var g := _fresh()
	var s := Siege.new()
	s.hex = MILAN
	s.besieger = &"SAV"
	g.sieges.append(s)
	assert_false(Occupation.besieged(g, MILAN), "no war between Savoy and Milan is declared yet")
	var w := War.new()
	w.id = 1
	w.a = &"SAV"
	w.b = &"MLO"
	w.start_turn = 1
	g.wars.append(w)
	assert_true(Occupation.besieged(g, MILAN))
	w.end_turn = 2
	assert_false(Occupation.besieged(g, MILAN), "an ended war is not one")


# --- capture, release, flush (4.4) ----------------------------------------------------------------------------------


func test_a_walk_in_takes_open_land_and_one_flush_says_it() -> void:
	var g := _fresh()
	var hex := _open_hex(g, &"MLO")
	var i := _index(g, hex)
	Occupation.capture(g, hex, &"SAV", &"walk", {})
	assert_eq(Occupation.controller_tag(g, hex), &"SAV")
	assert_true(Occupation.is_occupied(g, hex))
	assert_true(Occupation.controlled(g, _id(g, &"SAV")).has(i))
	assert_false(Occupation.controlled(g, _id(g, &"MLO")).has(i))
	var taken := _events(g, "district_captured")
	assert_eq(taken.size(), 1)
	assert_eq(taken[0]["by"], &"walk")
	assert_eq(taken[0]["tag"], &"SAV")
	assert_eq(str((taken[0]["others"] as Array)[0]), "MLO")
	assert_eq(_events(g, "controllers_changed").size(), 0, "the flush comes at the end of the batch")
	Occupation.flush(g)
	var changed := _events(g, "controllers_changed")
	assert_eq(changed.size(), 1)
	assert_eq((changed[0]["hexes"] as Array).size(), 1)
	assert_eq(changed[0]["tag"], &"SAV")
	assert_eq(str((changed[0]["others"] as Array)[0]), "MLO")


func test_a_batch_of_changes_is_one_controllers_changed() -> void:
	var g := _fresh()
	var a := _open_hex(g, &"MLO")
	Occupation.capture(g, a, &"SAV", &"walk", {})
	var b := _open_hex(g, &"MLO")
	Occupation.capture(g, b, &"SAV", &"walk", {})
	Occupation.flush(g)
	var changed := _events(g, "controllers_changed")
	assert_eq(changed.size(), 1)
	assert_eq((changed[0]["hexes"] as Array).size(), 2)
	Occupation.flush(g)
	assert_eq(_events(g, "controllers_changed").size(), 1, "a second flush with nothing pending says nothing")


func test_a_capture_takes_the_garrison_and_names_the_siege() -> void:
	var g := _fresh()
	Occupation.capture(g, MILAN, &"SAV", &"siege", {"name": "Siege of Milan", "seasons": 2, "opened": 4})
	var taken := _events(g, "district_captured")
	assert_eq(taken.size(), 1)
	assert_eq(taken[0]["garrison_lost"], 1200, "the men of the garrison are booked lost")
	assert_eq(taken[0]["name"], "Siege of Milan")
	assert_eq(taken[0]["opened"], 4)
	assert_eq(Occupation.garrison_of(g, MILAN), 0)
	assert_eq(g.state.unsupported[_index(g, MILAN)], 0)


func test_a_capture_by_the_owner_gives_the_hex_back() -> void:
	var g := _fresh()
	var hex := _open_hex(g, &"MLO")
	Occupation.capture(g, hex, &"SAV", &"walk", {})
	Occupation.capture(g, hex, &"MLO", &"retaken", {})
	assert_false(Occupation.is_occupied(g, hex), "the owner's own retaking clears the occupier")
	assert_eq(_events(g, "district_captured")[1]["tag"], &"MLO")


func test_a_capture_that_changes_nothing_is_refused_quietly() -> void:
	var g := _fresh()
	Occupation.capture(g, _open_hex(g, &"MLO"), &"MLO", &"walk", {})
	assert_eq(_events(g, "district_captured").size(), 0)


func test_release_in_the_same_batch_cancels_the_flush() -> void:
	var g := _fresh()
	var hex := _open_hex(g, &"MLO")
	Occupation.capture(g, hex, &"SAV", &"walk", {})
	Occupation.release(g, [hex])
	Occupation.flush(g)
	assert_eq(_events(g, "controllers_changed").size(), 0, "taken and given back in one batch: nothing changed")
	assert_eq(Occupation.controller_tag(g, hex), &"MLO")


func test_release_gives_back_a_taken_hex_and_says_so() -> void:
	var g := _fresh()
	var hex := _open_hex(g, &"MLO")
	Occupation.capture(g, hex, &"SAV", &"walk", {})
	Occupation.flush(g)
	Occupation.release(g, [hex])
	Occupation.flush(g)
	assert_eq(Occupation.controller_tag(g, hex), &"MLO")
	var changed := _events(g, "controllers_changed")
	assert_eq(changed.size(), 2)
	assert_eq(changed[1]["tag"], &"MLO", "the country that gained the hex leads")


# --- regrowth (4.3) --------------------------------------------------------------------------------------------------


func test_a_held_fortress_regrows_from_its_hex_and_the_ring() -> void:
	var g := _fresh()
	var i := _index(g, GENEVA)
	Occupation.set_garrison(g, GENEVA, 100)
	ArmyFixture.people_at(g, GENEVA, 20000)
	var levied := Occupation.regrow(g, GENEVA)
	assert_eq(levied, 200, "two levels a hundred men each, from the hex's people (a fifth of 20,000 is 2,000)")
	assert_eq(g.state.garrison[i], 300)
	assert_eq(g.state.people[i], 20000 - 200)


func test_regrowth_takes_the_ring_when_the_hex_has_no_people() -> void:
	var g := _fresh()
	var hex := GENEVA
	Occupation.set_garrison(g, hex, 100)
	ArmyFixture.people_at(g, hex, 0)
	var sav := _id(g, &"SAV")
	var grid := g.map.grid()
	for d: int in 6:
		var j := g.map.index_of(grid.neighbour(hex, d))
		if j >= 0 and g.map.land[j] != 0 and g.state.owner[j] == sav:
			ArmyFixture.people_at(g, grid.neighbour(hex, d), 20000)
	assert_eq(Occupation.regrow(g, hex), 200)
	assert_eq(Occupation.garrison_of(g, hex), 300)


func test_regrowth_stops_at_the_full_garrison() -> void:
	var g := _fresh()
	Occupation.set_garrison(g, GENEVA, 790)
	ArmyFixture.people_at(g, GENEVA, 20000)
	assert_eq(Occupation.regrow(g, GENEVA), 10)
	assert_eq(Occupation.garrison_of(g, GENEVA), 800)


func test_regrowth_is_refused_under_siege_on_occupied_land_and_with_a_hostile_army() -> void:
	var g := _fresh()
	Occupation.set_garrison(g, GENEVA, 100)
	ArmyFixture.people_at(g, GENEVA, 20000)
	var s := Siege.new()
	s.hex = GENEVA
	s.besieger = &"FRA"
	g.sieges.append(s)
	assert_eq(Occupation.regrow(g, GENEVA), 0, "a siege stops it")
	g.sieges.clear()
	var w := War.new()
	w.id = 1
	w.a = &"FRA"
	w.b = &"SAV"
	w.start_turn = 1
	g.wars.append(w)
	var army := Armies.create(g, &"FRA", GENEVA, "Army of test")
	assert_ne(army, null)
	assert_eq(Occupation.regrow(g, GENEVA), 0, "a hostile army on the hex stops it")
	Armies.remove(g, army)
	Occupation.capture(g, GENEVA, &"FRA", &"siege", {})
	assert_eq(Occupation.regrow(g, GENEVA), 0, "an occupied fortress keeps no garrison and regrows none")


func test_a_garrison_above_full_gives_its_excess_back() -> void:
	var g := _fresh()
	var i := _index(g, GENEVA)
	g.state.garrison[i] = 850
	ArmyFixture.people_at(g, GENEVA, 0)
	assert_eq(Occupation.regrow(g, GENEVA), 0)
	assert_eq(g.state.garrison[i], 800)
	assert_eq(g.state.people[i], 50, "the fifty men go home to the hex")


# --- freed land (D18) ------------------------------------------------------------------------------------------------


func test_an_occupied_district_with_no_support_goes_back_after_six_seasons() -> void:
	var g := _fresh()
	var hex := _open_hex(g, &"MLO")
	var i := _index(g, hex)
	Occupation.capture(g, hex, &"SAV", &"walk", {})
	for _season: int in 5:
		Occupation.support_season(g)
	assert_eq(g.state.unsupported[i], 5)
	assert_eq(Occupation.controller_tag(g, hex), &"SAV")
	Occupation.support_season(g)
	assert_eq(Occupation.controller_tag(g, hex), &"MLO")
	assert_eq(g.state.unsupported[i], 0)
	var freed := _events(g, "district_captured")
	assert_eq(freed[freed.size() - 1]["by"], &"freed")
	assert_eq(freed[freed.size() - 1]["tag"], &"MLO")


func test_an_army_of_the_occupier_in_range_resets_the_count() -> void:
	var g := _fresh()
	var hex := _open_hex(g, &"MLO")
	var i := _index(g, hex)
	Occupation.capture(g, hex, &"SAV", &"walk", {})
	for _season: int in 4:
		Occupation.support_season(g)
	Armies.create(g, &"SAV", hex, "Army of test")
	Occupation.support_season(g)
	assert_eq(g.state.unsupported[i], 0, "an army within 3 hexes supports the hex")
	assert_eq(Occupation.controller_tag(g, hex), &"SAV")


# --- the derived cache (WarCache, 5.3) -------------------------------------------------------------------------------


func test_an_event_that_says_controllers_changed_drops_the_control_lists() -> void:
	var g := _fresh()
	var hex := _open_hex(g, &"MLO")
	var i := _index(g, hex)
	var sav := _id(g, &"SAV")
	assert_false(Occupation.controlled(g, sav).has(i), "the list is warm now")
	g.state.occupier[i] = sav
	assert_false(Occupation.controlled(g, sav).has(i), "a direct write is not seen until an event says so")
	g.emit({"kind": "controllers_changed", "hexes": [hex], "tag": &"SAV", "others": [&"MLO"]})
	assert_true(Occupation.controlled(g, sav).has(i), "controllers_changed drops the lists")


func test_owners_changed_drops_the_castle_areas() -> void:
	var g := _fresh()
	var member := g.map.hex_of(Occupation.members(g, GENEVA)[1])
	assert_eq(Occupation.area_of(g, member), GENEVA)
	Territory.transfer(g, [member] as Array[Vector2i], _id(g, &"MLO"))
	assert_eq(Occupation.area_of(g, member), Army.NO_HEX, "land that is not Savoy's is in no area")


func test_a_fortress_whose_level_changes_drops_the_fortress_list() -> void:
	var g := _fresh()
	assert_true(g.war_cache.fortresses(g).has(_index(g, MILAN)))
	var i := _index(g, MILAN)
	g.state.main_use[i] = 0
	g.state.level[i] = 0
	g.emit({"kind": "hex_changed", "hex": MILAN})
	assert_false(g.war_cache.fortresses(g).has(i), "a hex_changed of a fortress drops the areas")


func test_a_hex_changed_that_keeps_the_fortress_leaves_the_areas_alone() -> void:
	var g := _fresh()
	var before := g.war_cache.area_index(g).duplicate()
	g.emit({"kind": "hex_changed", "hex": MILAN})
	assert_eq(g.war_cache.area_index(g), before)


func test_a_new_controller_flush_is_recorded_once_per_hex() -> void:
	var g := _fresh()
	var hex := _open_hex(g, &"MLO")
	Occupation.capture(g, hex, &"SAV", &"walk", {})
	Occupation.capture(g, hex, &"FRA", &"walk", {})
	Occupation.flush(g)
	var changed := _events(g, "controllers_changed")
	assert_eq(changed.size(), 1)
	assert_eq(changed[0]["tag"], &"FRA")
	assert_eq(str((changed[0]["others"] as Array)[0]), "MLO", "the controller before the batch is named, not the middle one")


# --- conservation of men on a fall and a refused give-back (review of B6: 5a, 5b) ------------------------------------


## A fortress that falls to level 0 (a clear work) gives its whole garrison back to its hex: regrow_all visits it although it
## is off the fortress list.
func test_a_fortress_that_falls_to_level_zero_gives_its_garrison_back() -> void:
	var g := _fresh()
	var i := _index(g, GENEVA)
	ArmyFixture.people_at(g, GENEVA, 0)
	g.state.main_use[i] = 0
	g.state.level[i] = 0
	g.emit({"kind": "hex_changed", "hex": GENEVA})
	assert_false(g.war_cache.fortresses(g).has(i), "off the fortress list now")
	Occupation.regrow_all(g)
	assert_eq(g.state.garrison[i], 0, "no men left in a garrison that is no fortress")
	assert_eq(g.state.people[i], 800, "the men go home to the hex (conservation)")


## People refuses to place the excess (the hex would pass PEOPLE_MAX): the garrison keeps the men, nothing vanishes.
func test_a_refused_give_back_keeps_the_excess_in_the_garrison() -> void:
	var g := _fresh()
	var i := _index(g, GENEVA)
	g.state.garrison[i] = 900
	g.state.people[i] = People.PEOPLE_MAX - 10
	var before := g.state.garrison[i] + g.state.people[i]
	Occupation.regrow(g, GENEVA)
	assert_eq(g.state.garrison[i], 900, "refused: the garrison is cut by nothing")
	assert_eq(g.state.garrison[i] + g.state.people[i], before, "men are conserved")


## An unowned hex refuses the give-back (People does not take people on unowned land): the men stay in the garrison.
func test_a_give_back_on_unowned_land_keeps_the_garrison() -> void:
	var g := _fresh()
	var i := _index(g, GENEVA)
	g.state.owner[i] = 0
	g.state.garrison[i] = 900
	g.state.people[i] = 0
	Occupation.regrow(g, GENEVA)
	assert_eq(g.state.garrison[i], 900)
	assert_eq(g.state.people[i], 0)


## Any hex that holds men in a garrison is visited by regrow_all, a fortress or not.
func test_regrow_all_visits_a_hex_with_men_that_is_no_fortress() -> void:
	var g := _fresh()
	var hex := _open_hex(g, &"MLO")
	var i := _index(g, hex)
	g.state.garrison[i] = 50
	ArmyFixture.people_at(g, hex, 0)
	Occupation.regrow_all(g)
	assert_eq(g.state.garrison[i], 0)
	assert_eq(g.state.people[i], 50)
