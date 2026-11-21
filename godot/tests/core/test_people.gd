## People (core/systems/people.gd; docs/architecture/m5-build-spec.md 4.2, 4.4, 4.20, 5.3 and 9): the start people and the room
## of every level, cover and stage; the setup; the rule of one hex (growth by slot and tax, the cap at room, hunger by fed and
## slot, the floor, crowding, the countryside never starving, room 0); the door `move` with every refusal; `fed_of`; the
## walk `active`; the phase `season` and `close` on a game this test builds; and the levy seam.
extends GutTest

@warning_ignore_start("integer_division")

var _defs: GameDefs


func before_all() -> void:
	_defs = EconomyFixture.committed()


## A 9 x 9 all-land map of one cover and climate, every hex held by owner 1, the game over a wild state with the start people.
func _flat_game(cover: int = 0, climate: int = 1) -> Game:
	var m := MapData.new()
	m.id = "people_flat"
	m.hex_w_km = 28.0
	m.ref_lat = 45.0
	m.allocate(9, 9)
	for i: int in m.hex_count():
		m.land[i] = 1
		m.cover[i] = cover
		m.climate[i] = climate
		m.depth[i] = 0
	var state := MapState.create(m)
	state.owner.fill(1)
	return Game.with_state(m, state, 1, _defs)


func _put(g: Game, hex: Vector2i, family: int, level: int) -> int:
	var i := g.map.index_of(hex)
	g.state.main_use[i] = family
	g.state.level[i] = level
	return i


func _view(g: Game) -> StateView:
	return StateView.of(g.state)


# ----- start and room -------------------------------------------------------------------------------------------------


func test_start_people_for_every_level_and_cover() -> void:
	var g := _flat_game(0)
	var hex := Vector2i(4, 4)
	var covers := [8000, 5000, 2500, 1500, 600, 0, 0, 1500]
	for cover: int in 8:
		var flat := _flat_game(cover)
		assert_eq(People.start_people(flat, hex), covers[cover], "cover %d" % cover)
	var levels := [1000, 3000, 10000, 30000, 60000]
	for level: int in range(1, 6):
		_put(g, hex, 1, level)
		assert_eq(People.start_people(g, hex), levels[level - 1], "settlement level %d" % level)
	assert_eq(People.start_people(g, Vector2i(-1, 0)), 0, "off the map")
	g.map.land[g.map.index_of(Vector2i(0, 0))] = 0
	assert_eq(People.start_people(g, Vector2i(0, 0)), 0, "the sea")
	var bare := Game.with_state(g.map, g.state, 1, null)
	assert_eq(People.start_people(bare, hex), 0, "no definitions")


func test_room_for_every_level_cover_and_stage() -> void:
	var g := _flat_game(0)
	var hex := Vector2i(4, 4)
	var rooms := [2000, 4000, 20000, 45000, 100000]
	for level: int in range(1, 6):
		_put(g, hex, 1, level)
		assert_eq(People.room_at(g, _view(g), hex), rooms[level - 1], "settlement level %d" % level)
	var covers := [8000, 5000, 2500, 1500, 600, 0, 0, 1500]
	for cover: int in 8:
		var flat := _flat_game(cover)
		assert_eq(People.room_at(flat, _view(flat), hex), covers[cover], "wild land of cover %d" % cover)
	# A district adds its jobs by stage (goods 1,000, 2,000, 4,000; harbours 500, 1,000, 2,000), a castle none.
	var stages := {3: [1000, 2000, 4000], 14: [500, 1000, 2000], 7: [1000, 2000, 4000]}
	for family: int in stages:
		for level: int in range(1, 4):
			_put(g, hex, family, level)
			assert_eq(People.room_at(g, _view(g), hex), 8000 + stages[family][level - 1], "family %d level %d" % [family, level])
	_put(g, hex, 2, 2)
	assert_eq(People.room_at(g, _view(g), hex), 8000, "a castle has no jobs")
	assert_eq(People.room_at(g, _view(g), Vector2i(-1, -1)), 0, "off the map")


func test_the_view_decides_the_room() -> void:
	var g := _flat_game(0)
	var hex := Vector2i(4, 4)
	var i := g.map.index_of(hex)
	assert_eq(People.room_at(g, _view(g).with({i: Vector2i(1, 4)}), hex), 45000)
	assert_eq(People.room_at(g, _view(g), hex), 8000, "the base is untouched")


func test_setup_gives_every_land_hex_its_start_people_and_every_country_zero_flows() -> void:
	var g := EconomyFixture.game(&"GEN")
	var land := 0
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 1:
			land += 1
			assert_eq(g.state.people[i], People.start_people(g, hex), str(hex))
		else:
			assert_eq(g.state.people[i], 0, "the sea")
	assert_gt(land, 300)
	assert_eq(g.state.people_start, g.state.people)
	assert_eq(g.state.people_end, g.state.people)
	var genoa := Countries.by_tag(g, &"GEN")
	assert_eq(g.state.people[g.map.index_of(Vector2i(8, 13))], 30000)
	assert_eq(EconomySeason.town_people(g, _view(g), &"GEN"), 40000, "M4 4.12: Genoa's towns")
	assert_eq(EconomySeason.country_people(g, _view(g), &"GEN"), 42700, "and its countryside")
	for c: Country in g.countries:
		assert_eq(c.people_flows, PackedInt32Array([0, 0, 0, 0, 0, 0]), c.tag)
		assert_eq(c.food_fed, 1000)
		assert_eq(c.food_need, 0)
	assert_eq(People.FLOWS.size(), Country.PEOPLE_FLOW_COUNT, "the flows and the country's width agree")
	assert_not_null(genoa)


func test_a_state_with_no_people_starts_with_the_table_and_one_with_people_keeps_them() -> void:
	var g := _flat_game(2)
	assert_eq(g.state.people[g.map.index_of(Vector2i(4, 4))], 2500, "with_state gives the start people")
	var kept := Game.with_state(g.map, g.state, 1, _defs)
	g.state.people[0] = 7
	var again := Game.with_state(g.map, g.state, 1, _defs)
	assert_eq(again.state.people[0], 7, "people that are there are not set up again")
	assert_not_null(kept)


# ----- the rule of one hex ---------------------------------------------------------------------------------------------


func _village(people: int, climate: int = 1) -> Array:
	var g := _flat_game(0, climate)
	var i := _put(g, Vector2i(4, 4), 1, 2)
	g.state.people[i] = people
	return [g, i]


func test_growth_by_slot_and_tax() -> void:
	var made := _village(3000)
	var g: Game = made[0]
	var hex := Vector2i(4, 4)
	# 3,000 x tax bp x slot percent / 1,000,000: Low 1.25 %, Normal 1 %, High 0.5 % a season.
	assert_eq(People.change_at(g, _view(g), hex, 1, 1, 1000), Vector2i(30, People.GREW))
	assert_eq(People.change_at(g, _view(g), hex, 1, 0, 1000), Vector2i(37, People.GREW), "Low: 37.5 floored")
	assert_eq(People.change_at(g, _view(g), hex, 1, 2, 1000), Vector2i(15, People.GREW))
	for season: int in 3:
		assert_eq(People.change_at(g, _view(g), hex, season, 1, 1000), Vector2i(30, People.GREW), "season %d" % season)
	# Winter: none in the snow, half in the frost, full in the mild.
	var snow := _village(3000, 0)
	var frost := _village(3000, 1)
	var mild := _village(3000, 2)
	assert_eq(People.change_at(snow[0], _view(snow[0]), hex, 3, 1, 1000), Vector2i.ZERO)
	assert_eq(People.change_at(frost[0], _view(frost[0]), hex, 3, 1, 1000), Vector2i(15, People.GREW))
	assert_eq(People.change_at(mild[0], _view(mild[0]), hex, 3, 1, 1000), Vector2i(30, People.GREW))
	assert_eq(People.change_at(g, _view(g), hex, 1, 7, 1000), Vector2i(15, People.GREW), "a tax out of range counts as High")


func test_growth_never_passes_the_room() -> void:
	var made := _village(3990)
	var g: Game = made[0]
	assert_eq(People.change_at(g, _view(g), Vector2i(4, 4), 1, 1, 1000), Vector2i(10, People.GREW), "39 would pass 4,000")
	g.state.people[made[1]] = 4000
	assert_eq(People.change_at(g, _view(g), Vector2i(4, 4), 1, 1, 1000), Vector2i.ZERO, "full")
	g.state.people[made[1]] = 3
	assert_eq(People.change_at(g, _view(g), Vector2i(4, 4), 1, 1, 1000), Vector2i.ZERO, "a fraction of a person is none")


func test_hunger_at_fed_0_400_and_999_and_in_winter() -> void:
	var made := _village(3000)
	var g: Game = made[0]
	var hex := Vector2i(4, 4)
	assert_eq(People.change_at(g, _view(g), hex, 1, 1, 0), Vector2i(-120, People.STARVED), "4 % of 3,000 at no food")
	assert_eq(People.change_at(g, _view(g), hex, 1, 1, 400), Vector2i(-72, People.STARVED), "a shortfall of 600")
	assert_eq(People.change_at(g, _view(g), hex, 1, 1, 999), Vector2i(-1, People.STARVED), "rounded up: one person")
	assert_eq(People.change_at(g, _view(g), hex, 1, 1, 1000), Vector2i(30, People.GREW), "fed: it grows")
	var snow := _village(3000, 0)
	var frost := _village(3000, 1)
	var mild := _village(3000, 2)
	assert_eq(People.change_at(snow[0], _view(snow[0]), hex, 3, 1, 0), Vector2i(-180, People.STARVED), "150 % in the snow")
	assert_eq(People.change_at(frost[0], _view(frost[0]), hex, 3, 1, 0), Vector2i(-150, People.STARVED), "125 % in the frost")
	assert_eq(People.change_at(mild[0], _view(mild[0]), hex, 3, 1, 0), Vector2i(-120, People.STARVED))


func test_hunger_never_takes_a_town_under_its_floor() -> void:
	for pair: Array in [[250, 10], [205, 5], [200, 0], [150, 0]]:
		var made := _village(pair[0])
		var g: Game = made[0]
		var step := People.change_at(g, _view(g), Vector2i(4, 4), 1, 1, 0)
		assert_eq(-step.x, pair[1], "%d people" % pair[0])
	var made := _village(205)
	var g: Game = made[0]
	var after := 205 + People.change_at(g, _view(g), Vector2i(4, 4), 1, 1, 0).x
	assert_eq(after, 200, "205 people: 9 would be taken, 5 are")


func test_crowding_leaves_two_percent_down_to_the_room() -> void:
	var made := _village(5000)
	var g: Game = made[0]
	assert_eq(People.change_at(g, _view(g), Vector2i(4, 4), 1, 1, 1000), Vector2i(-100, People.LEFT), "2 % of 5,000")
	g.state.people[made[1]] = 4010
	assert_eq(People.change_at(g, _view(g), Vector2i(4, 4), 1, 1, 1000), Vector2i(-10, People.LEFT), "only what is over")
	g.state.people[made[1]] = 4001
	assert_eq(People.change_at(g, _view(g), Vector2i(4, 4), 1, 1, 1000), Vector2i(-1, People.LEFT))
	# Crowding in winter in the snow too: leaving has no season.
	var snow := _village(5000, 0)
	assert_eq(People.change_at(snow[0], _view(snow[0]), Vector2i(4, 4), 3, 1, 1000), Vector2i(-100, People.LEFT))
	# A hungry settlement over its room starves first (4.4's order).
	g.state.people[made[1]] = 5000
	assert_eq(People.change_at(g, _view(g), Vector2i(4, 4), 1, 1, 0).y, People.STARVED)


func test_the_countryside_never_starves_and_grows_into_its_room() -> void:
	var g := _flat_game(0)
	var hex := Vector2i(4, 4)
	var i := g.map.index_of(hex)
	assert_eq(People.change_at(g, _view(g), hex, 1, 1, 0), Vector2i.ZERO, "full farmland, nothing eaten from the stores")
	g.state.people[i] = 7000
	assert_eq(People.change_at(g, _view(g), hex, 1, 1, 0), Vector2i(70, People.GREW), "fed or not: it grows")
	_put(g, hex, 7, 2)
	g.state.people[i] = 8000
	assert_eq(People.change_at(g, _view(g), hex, 1, 1, 0), Vector2i(80, People.GREW), "a vineyard has room for 2,000 more")
	g.state.people[i] = 12000
	assert_eq(People.change_at(g, _view(g), hex, 1, 1, 1000), Vector2i(-240, People.LEFT), "the district cleared: 2 % of 12,000 leave, the rest stays")


func test_room_zero_snow_and_off_the_map() -> void:
	var g := _flat_game(5)  # snow: no countryside, no room
	var hex := Vector2i(4, 4)
	var i := g.map.index_of(hex)
	assert_eq(People.change_at(g, _view(g), hex, 1, 1, 1000), Vector2i.ZERO, "room 0 and no one")
	g.state.people[i] = 100
	assert_eq(People.change_at(g, _view(g), hex, 1, 1, 1000), Vector2i(-2, People.LEFT), "no room: 2 % leave")
	assert_eq(People.change_at(g, _view(g), Vector2i(-1, -1), 1, 1, 1000), Vector2i.ZERO)


func test_a_what_if_view_is_read() -> void:
	var made := _village(3000)
	var g: Game = made[0]
	var view := _view(g).with_people({made[1]: 4000})
	assert_eq(People.change_at(g, view, Vector2i(4, 4), 1, 1, 1000), Vector2i.ZERO, "full on the view")
	assert_eq(People.change_at(g, _view(g), Vector2i(4, 4), 1, 1, 1000).x, 30, "the base is untouched")


# ----- the door --------------------------------------------------------------------------------------------------------


func _flows(c: Country) -> Array:
	return Array(c.people_flows)


func test_move_changes_the_people_and_the_owners_flow() -> void:
	var g := EconomyFixture.game(&"GEN")
	var genoa := Countries.by_tag(g, &"GEN")
	var hex := Vector2i(8, 13)
	var i := g.map.index_of(hex)
	assert_true(People.move(g, hex, 300, &"grew"))
	assert_eq(g.state.people[i], 30300)
	assert_eq(_flows(genoa), [300, 0, 0, 0, 0, 0])
	assert_true(People.move(g, hex, -120, &"starved"))
	assert_true(People.move(g, hex, -80, &"left"))
	assert_true(People.move(g, hex, -50, &"raised"))
	assert_true(People.move(g, hex, 20, &"returned"))
	assert_true(People.move(g, hex, 5, &"dev"))
	assert_eq(_flows(genoa), [300, -120, -80, -50, 20, 5])
	assert_eq(g.state.people[i], 30300 - 120 - 80 - 50 + 20 + 5)
	var other := Countries.by_tag(g, &"SAV")
	assert_eq(_flows(other), [0, 0, 0, 0, 0, 0], "another country's flows are its own")
	var before := g.state.people.duplicate()
	assert_true(People.move(g, hex, 0, &"grew"), "an amount of 0 changes nothing and is true")
	assert_eq(g.state.people, before)
	assert_eq(_flows(genoa), [300, -120, -80, -50, 20, 5])


func test_move_refuses_what_it_must_and_changes_nothing() -> void:
	var g := EconomyFixture.game(&"GEN")
	var genoa := Countries.by_tag(g, &"GEN")
	var hex := Vector2i(8, 13)
	var i := g.map.index_of(hex)
	var sea_i := 0
	while g.map.land[sea_i] == 1:
		sea_i += 1
	var free_i := g.map.index_of(Vector2i(7, 13))  # Genoa's wild farmland, set free: land no country holds
	assert_eq(g.dev_transfer([g.map.hex_of(free_i)] as Array[Vector2i], 0), 1)
	var people := g.state.people.duplicate()
	var cases: Array = [
		["off the map", Vector2i(-1, -1), 5, &"grew"],
		["the sea", g.map.hex_of(sea_i), 5, &"grew"],
		["an unknown reason", hex, 5, &"plague"],
		["a result below zero", hex, -30001, &"starved"],
		["a result over the largest", hex, People.PEOPLE_MAX, &"grew"],
		["land no country holds", g.map.hex_of(free_i), 5, &"grew"],
	]
	for case: Array in cases:
		assert_false(People.move(g, case[1], case[2], case[3]), case[0])
		assert_eq(g.state.people, people, "%s: nothing changed" % case[0])
		assert_eq(_flows(genoa), [0, 0, 0, 0, 0, 0], "%s: no flow" % case[0])
	assert_true(People.move(g, hex, -30000, &"starved"), "all the way to 0 is allowed")
	assert_eq(g.state.people[i], 0)
	assert_true(People.move(g, hex, People.PEOPLE_MAX, &"dev"), "the largest is allowed")
	assert_false(People.move(g, hex, 1, &"dev"), "one more is not")
	# A map-only game has no countries: the door is shut.
	var lone := _flat_game(0)
	var lone_people := lone.state.people.duplicate()
	assert_false(People.move(lone, Vector2i(4, 4), 5, &"grew"))
	assert_eq(lone.state.people, lone_people)


# ----- food ------------------------------------------------------------------------------------------------------------


func test_fed_of_reads_the_open_flows_of_grain_and_fish() -> void:
	var g := EconomyFixture.game(&"GEN")
	var genoa := Countries.by_tag(g, &"GEN")
	assert_eq(People.fed_of(g, &"GEN", 0), 1000, "no need: fed")
	assert_eq(People.fed_of(g, &"GEN", 4), 0, "nothing eaten yet this season")
	Stores.move(g, &"GEN", Economy.FISH, 10, &"made")
	Stores.move(g, &"GEN", Economy.FISH, -3, &"used")
	assert_eq(People.fed_of(g, &"GEN", 4), 750, "3 of 4")
	Stores.move(g, &"GEN", Economy.GRAIN, -1, &"used")
	assert_eq(People.fed_of(g, &"GEN", 4), 1000, "4 of 4")
	Stores.move(g, &"GEN", Economy.GRAIN, -3, &"used")
	assert_eq(People.fed_of(g, &"GEN", 4), 1000, "never over 1,000")
	assert_eq(People.fed_of(g, &"GEN", 9), 777, "7 of 9, floored")
	assert_eq(People.fed_of(g, &"ZZZ", 9), 1000, "an unknown country has no need to meet")
	assert_not_null(genoa)
	# The other flows are not food eaten: sold and made leave it as it was.
	Stores.move(g, &"GEN", Economy.GRAIN, -1, &"sold")
	assert_eq(People.fed_of(g, &"GEN", 8), 1000 * 7 / 8)
	assert_eq(People.food_need_of(g, _view(g), &"GEN"), 4, "40,000 town people: four loads")


# ----- the walk ------------------------------------------------------------------------------------------------------


func test_active_holds_the_settlements_and_the_hexes_that_can_change() -> void:
	var g := EconomyFixture.game(&"GEN")
	var genoa := Countries.by_tag(g, &"GEN")
	var view := _view(g)
	var active := People.active(g, view, genoa.id)
	var want: Array[int] = []
	for i: int in Territory.districts(g, genoa.id):
		if g.state.main_use[i] == 1 or g.state.people[i] != People._room_i(g, view, i):
			want.append(i)
	assert_eq(Array(active), want)
	for hex: Vector2i in [Vector2i(8, 13), Vector2i(6, 13), Vector2i(7, 12), Vector2i(7, 14), Vector2i(9, 13)]:
		assert_true(active.has(g.map.index_of(hex)), str(hex))
	assert_false(active.has(g.map.index_of(Vector2i(7, 13))), "the full wild farmland cannot change")
	for n: int in range(1, active.size()):
		assert_lt(active[n - 1], active[n], "ascending")
	# A view that fills a hex takes it out, one that empties a full hex puts it in.
	var full_i := g.map.index_of(Vector2i(7, 13))
	var emptied := People.active(g, view.with_people({full_i: 100}), genoa.id)
	assert_true(emptied.has(full_i))
	var olives := g.map.index_of(Vector2i(7, 14))
	var filled := People.active(g, view.with_people({olives: People._room_i(g, view, olives)}), genoa.id)
	assert_false(filled.has(olives))
	# A level the view changes changes the room: a vineyard cleared on the view leaves 8,000 of 8,000.
	var vineyard := g.map.index_of(Vector2i(7, 12))
	var cleared := People.active(g, view.with({vineyard: Vector2i(0, 0)}), genoa.id)
	assert_false(cleared.has(vineyard), "cleared: 8,000 of 8,000 is full")
	assert_eq(People.active(g, view, 0).size(), 0, "no country")


# ----- the phase and the close, on a game this test builds ---------------------------------------------------------------


func test_a_season_moves_the_people_through_the_door_and_close_keeps_the_flows() -> void:
	var g := PeopleFixture.genoa(null, false)
	var genoa := Countries.by_tag(g, &"GEN")
	var before := g.state.people.duplicate()
	var start_total := 0
	for i: int in Territory.districts(g, genoa.id):
		start_total += g.state.people[i]
	assert_eq(start_total, 82700)
	PeopleFixture.season(g)
	var total := 0
	for i: int in Territory.districts(g, genoa.id):
		total += g.state.people[i]
	assert_eq(total, 83285, "4.11 (a): Spring 1480 ends at 83,285")
	assert_eq(g.state.people[g.map.index_of(Vector2i(8, 13))], 30300, "Genoa +300")
	assert_eq(g.state.people[g.map.index_of(Vector2i(6, 13))], 10100, "Savona +100")
	assert_eq(g.state.people[g.map.index_of(Vector2i(7, 12))], before[g.map.index_of(Vector2i(7, 12))] + 80, "the vineyard +80")
	assert_eq(g.state.people_start, before, "close: the start is the people before")
	assert_eq(g.state.people_end, g.state.people, "and the end the people now")
	assert_eq(genoa.people_closed["turn"], 1)
	assert_eq(Array(genoa.people_closed["flows"]), [585, 0, 0, 0, 0, 0])
	assert_eq(_flows(genoa), [0, 0, 0, 0, 0, 0], "the open flows start again")
	assert_eq(genoa.food_need, 4)
	assert_eq(genoa.food_fed, 1000)


func test_the_phase_equals_the_change_at_rule_hex_by_hex() -> void:
	var g := PeopleFixture.genoa()
	var genoa := Countries.by_tag(g, &"GEN")
	# Production and income first, as the table runs them, so the flows of the season are open.
	Season.run_phase(g, &"production")
	Season.run_phase(g, &"income")
	var view := _view(g)
	var fed := People.fed_of(g, &"GEN", People.food_need_of(g, view, &"GEN"))
	var want := g.state.people.duplicate()
	for i: int in Territory.districts(g, genoa.id):
		var step := People.change_at(g, view, g.map.hex_of(i), 0, genoa.tax, fed)
		want[i] += step.x
	People.season(g)
	for i: int in Territory.districts(g, genoa.id):
		assert_eq(g.state.people[i], want[i], str(g.map.hex_of(i)))
	assert_eq(genoa.food_fed, fed)


func test_a_dead_country_and_a_sandbox_are_left_alone() -> void:
	var g := PeopleFixture.genoa()
	var genoa := Countries.by_tag(g, &"GEN")
	genoa.alive = false
	var before := g.state.people.duplicate()
	People.season(g)
	for i: int in Territory.districts(g, genoa.id):
		assert_eq(g.state.people[i], before[i], "a country that is no more does not move")
	var lone := _flat_game(0)
	var lone_before := lone.state.people.duplicate()
	People.season(lone)
	People.close(lone)
	assert_eq(lone.state.people, lone_before, "a sandbox's people never change")
	assert_eq(lone.state.people_end, lone.state.people, "but the close keeps the arrays")


func test_close_twice_makes_the_start_the_last_end() -> void:
	var g := PeopleFixture.genoa()
	PeopleFixture.season(g)
	var end_one := g.state.people.duplicate()
	PeopleFixture.season(g)
	assert_eq(g.state.people_start, end_one)
	assert_eq(g.state.people_end, g.state.people)
	assert_ne(g.state.people_start, g.state.people, "a season of growth between them")


# ----- the levy seam (4.20) ----------------------------------------------------------------------------------------------


func test_available_is_a_tenth_of_the_people_floored() -> void:
	var g := EconomyFixture.game(&"GEN")
	assert_eq(People.available(g, Vector2i(8, 13)), 3000)
	g.state.people[g.map.index_of(Vector2i(8, 13))] = 30009
	assert_eq(People.available(g, Vector2i(8, 13)), 3000, "floored")
	var sea_i := 0
	while g.map.land[sea_i] == 1:
		sea_i += 1
	assert_eq(People.available(g, g.map.hex_of(sea_i)), 0, "the sea")
	assert_eq(People.available(g, Vector2i(-1, -1)), 0, "off the map")
	g.dev_transfer([Vector2i(7, 13)] as Array[Vector2i], 0)
	assert_gt(g.state.people[g.map.index_of(Vector2i(7, 13))], 0)
	assert_eq(People.available(g, Vector2i(7, 13)), 0, "unowned land")


func test_levy_check_rows_with_their_words() -> void:
	var g := EconomyFixture.game(&"GEN")
	var hex := Vector2i(8, 13)
	var sea_i := 0
	while g.map.land[sea_i] == 1:
		sea_i += 1
	assert_eq(People.levy_check(g, &"GEN", g.map.hex_of(sea_i), 10)["reason"], "not a land hex")
	assert_eq(People.levy_check(g, &"GEN", Vector2i(-1, -1), 10)["reason"], "not a land hex")
	var foreign := People.levy_check(g, &"SAV", hex, 10)
	assert_false(foreign["ok"])
	assert_eq(foreign["reason"], Territory.at_home_check(g, &"SAV", hex)["reason"], "M2's home rule, with its words")
	assert_ne(foreign["reason"], "")
	assert_eq(People.levy_check(g, &"GEN", hex, 0)["reason"], "no men asked")
	assert_eq(People.levy_check(g, &"GEN", hex, -4)["reason"], "no men asked")
	assert_eq(People.levy_check(g, &"GEN", hex, 3001)["reason"], "only 3000 men can be raised here: (8, 13) holds 30000 people")
	assert_true(People.levy_check(g, &"GEN", hex, 3000)["ok"])
	assert_true(People.levy_check(g, &"GEN", hex, 1)["ok"])
	assert_eq(People.levy_check(g, &"", hex, 1)["reason"], "choose your country first")


func test_levy_takes_the_men_as_raised_and_a_refusal_takes_none() -> void:
	var g := EconomyFixture.game(&"GEN")
	var genoa := Countries.by_tag(g, &"GEN")
	var hex := Vector2i(8, 13)
	var i := g.map.index_of(hex)
	assert_eq(People.levy(g, &"GEN", hex, 1000), 1000)
	assert_eq(g.state.people[i], 29000)
	assert_eq(_flows(genoa), [0, 0, 0, -1000, 0, 0])
	assert_eq(People.levy(g, &"GEN", hex, 5000), 0, "more than a tenth of the 29,000: refused")
	assert_eq(People.levy(g, &"SAV", hex, 10), 0, "not its land")
	assert_eq(People.levy(g, &"GEN", hex, 0), 0)
	assert_eq(g.state.people[i], 29000, "a refusal changes nothing")
	assert_eq(_flows(genoa), [0, 0, 0, -1000, 0, 0])


func test_give_back_returns_men_and_a_crowd_leaves_next_season() -> void:
	var g := EconomyFixture.game(&"GEN")
	var genoa := Countries.by_tag(g, &"GEN")
	var hex := Vector2i(8, 13)
	var i := g.map.index_of(hex)
	assert_eq(People.levy(g, &"GEN", hex, 1000), 1000)
	assert_eq(People.give_back(g, hex, 1000), 1000)
	assert_eq(g.state.people[i], 30000)
	assert_eq(_flows(genoa), [0, 0, 0, -1000, 1000, 0])
	g.state.people[i] = 45000
	assert_eq(People.give_back(g, hex, 100), 100)
	assert_eq(g.state.people[i], 45100, "over the room")
	assert_eq(People.change_at(g, _view(g), hex, 1, 1, 1000), Vector2i(-100, People.LEFT), "they leave as any crowd")
	assert_eq(People.give_back(g, hex, 0), 0)
	assert_eq(People.give_back(g, Vector2i(-1, -1), 5), 0)
	var sea_i := 0
	while g.map.land[sea_i] == 1:
		sea_i += 1
	assert_eq(People.give_back(g, g.map.hex_of(sea_i), 5), 0, "the sea")
	g.dev_transfer([Vector2i(7, 13)] as Array[Vector2i], 0)
	assert_eq(People.give_back(g, Vector2i(7, 13), 5), 0, "unowned land")


# ----- the running set (R2's fallback): the same hexes as a walk over every owned hex ------------------------------------


func _walked(g: Game, id: int) -> Array:
	var view := StateView.of(g.state)
	var out: Array = []
	for i: int in Territory.districts(g, id):
		if g.state.main_use[i] == 1 or g.state.people[i] != People._room_i(g, view, i):
			out.append(i)
	return out


func test_the_running_set_equals_the_walk_through_seasons_works_and_the_door() -> void:
	var g := PeopleFixture.genoa()
	g.dev_money(&"GEN", 5000)
	g.dev_goods(&"GEN", 11, 100)
	g.dev_goods(&"GEN", 12, 100)
	var seen := 0
	for n: int in 14:
		match n % 4:
			0:
				for hex: Vector2i in [Vector2i(7, 13), Vector2i(6, 14), Vector2i(10, 12)]:
					for row: Dictionary in ImprovePreview.options_of(g, &"GEN", hex):
						if bool(row["verdict"]["ok"]):
							g.act(String(row["action"]), {"hex": hex, "family": row["family"], "tag": &"GEN"})
							break
			1:
				People.move(g, Vector2i(7, 13), -300, &"dev")  # a full hex made short: it joins the set
			2:
				People.move(g, Vector2i(8, 13), 50, &"dev")
		PeopleFixture.season(g)
		for c: Country in g.countries:
			var want := _walked(g, c.id)
			assert_eq(Array(People.active(g, StateView.of(g.state), c.id)), want, "%s after season %d" % [c.tag, n + 1])
			seen += want.size()
	assert_gt(seen, 500)
	assert_gt(g.districts.open_hexes(g).size(), 20)
	# Dropping the set and walking again finds the same hexes.
	g.districts.reset_open()
	for c: Country in g.countries:
		assert_eq(Array(People.active(g, StateView.of(g.state), c.id)), _walked(g, c.id), c.tag)


func test_a_hex_made_short_by_the_door_joins_the_set_and_a_full_one_leaves() -> void:
	var g := EconomyFixture.game(&"GEN")
	var genoa := Countries.by_tag(g, &"GEN")
	var i := g.map.index_of(Vector2i(7, 13))  # wild farmland, full
	assert_false(People.active(g, StateView.of(g.state), genoa.id).has(i))
	assert_true(People.move(g, Vector2i(7, 13), -10, &"dev"))
	assert_true(People.active(g, StateView.of(g.state), genoa.id).has(i), "10 short: it can grow")
	assert_true(People.move(g, Vector2i(7, 13), 10, &"dev"))
	assert_false(People.active(g, StateView.of(g.state), genoa.id).has(i), "full again: it leaves")
	# A level change through the door of the map (hex_changed) changes the room: a vineyard cleared leaves 8,000 of 8,000.
	var vineyard := g.map.index_of(Vector2i(7, 12))
	assert_true(People.active(g, StateView.of(g.state), genoa.id).has(vineyard), "8,000 of 10,000")
	g.improvement.clear(Vector2i(7, 12))
	g.emit({"kind": "hex_changed", "hex": Vector2i(7, 12)})
	assert_false(People.active(g, StateView.of(g.state), genoa.id).has(vineyard), "cleared: 8,000 of 8,000")
