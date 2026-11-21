## PeopleView (docs/architecture/m5-build-spec.md 5.6, 6.3, 4.19): `at` for yours, a known country's (banded), an unknown
## one's (not shown), unowned land and the sea; every row of `outlook` with its words; `seasons_to_full`; `ribbons`.
extends GutTest

@warning_ignore_start("integer_division")

const GENOA := Vector2i(8, 13)
const SAVONA := Vector2i(6, 13)
const TURIN_VILLAGE := Vector2i(6, 11)
const LUCCA := Vector2i(12, 15)


func _i(g: Game, hex: Vector2i) -> int:
	return g.map.index_of(hex)


func _view(g: Game) -> StateView:
	return StateView.of(g.state)


func _land_of(g: Game, tag: StringName) -> Vector2i:
	var c := Countries.by_tag(g, tag)
	for i: int in Territory.districts(g, c.id):
		if g.state.main_use[i] != People.SETTLEMENTS and g.state.people[i] > 0:
			return g.map.hex_of(i)
	return Vector2i(-1, -1)


func test_at_yours_before_and_after_a_season() -> void:
	var g := PeopleFixture.genoa()
	var at := PeopleView.at(g, &"GEN", GENOA)
	assert_true(bool(at["shown"]))
	assert_true(bool(at["exact"]))
	assert_eq(at["text"], "30,000 · room 45,000")
	assert_eq(int(at["change"]), 0)
	Season.run(g)
	at = PeopleView.at(g, &"GEN", GENOA)
	assert_eq(at["text"], "30,300 · room 45,000 · ▲ +300")
	assert_eq(int(at["people"]), 30300)
	assert_eq(int(at["room"]), 45000)
	assert_eq(int(at["change"]), 300)


func test_at_known_is_banded_unknown_is_not_shown() -> void:
	var g := PeopleFixture.genoa()
	var milan := _land_of(g, &"MLO")
	var known := PeopleView.at(g, &"GEN", milan)
	assert_true(bool(known["shown"]))
	assert_false(bool(known["exact"]))
	var n := int(g.state.people[_i(g, milan)])
	assert_eq(known["text"], Knowledge.band_text(n, ""))
	assert_eq(int(known["people"]), Knowledge.band(n))
	assert_eq(int(known["room"]), 0, "a foreign room is not told")
	var france := _land_of(g, &"FRA")
	var unknown := PeopleView.at(g, &"GEN", france)
	assert_false(bool(unknown["shown"]), "France is unknown to Genoa")
	assert_eq(unknown["text"], "")
	assert_eq(int(unknown["people"]), 0, "no figure leaks")
	var all := PeopleView.at(g, &"", france)
	assert_true(bool(all["shown"]))
	assert_true(bool(all["exact"]))
	assert_eq(all["text"], Words.number(int(g.state.people[_i(g, france)])))


func test_at_sea_off_map_and_unowned() -> void:
	var g := PeopleFixture.genoa()
	var sea := Vector2i(-1, -1)
	for i: int in g.map.hex_count():
		if g.map.land[i] == 0:
			sea = g.map.hex_of(i)
			break
	assert_eq(PeopleView.at(g, &"GEN", sea), {})
	assert_eq(PeopleView.at(g, &"GEN", Vector2i(-1, 0)), {})
	assert_eq(PeopleView.at(null, &"GEN", GENOA), {})
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1 and int(g.state.owner[i]) == 0 and g.state.people[i] > 0:
			var at := PeopleView.at(g, &"GEN", g.map.hex_of(i))
			assert_true(bool(at["exact"]))
			assert_eq(at["text"], Words.number(int(g.state.people[i])))
			break
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1 and g.state.people[i] == 0 and int(g.state.owner[i]) == 0 \
				and People.room_i(g, _view(g), i) == 0:
			assert_eq(PeopleView.at(g, &"GEN", g.map.hex_of(i))["text"], "none")
			break


func test_a_map_only_game_has_no_people_line() -> void:
	var g := Game.new_game(EconomyFixture.map(), 1480)
	assert_eq(PeopleView.at(g, &"", GENOA), {})
	assert_eq(PeopleView.outlook(g, GENOA), {})


func test_outlook_hungry() -> void:
	var g := PeopleFixture.genoa()
	Countries.by_tag(g, &"GEN").food_fed = 500
	var o := PeopleView.outlook(g, SAVONA)
	assert_eq(o["text"], "Hungry: it loses people each season until your towns are fed.")
	assert_eq(o["tone"], &"bad")
	assert_eq(PeopleView.outlook(g, GENOA)["tone"], &"bad", "every settlement of a hungry country")


func test_outlook_village_grows_into_a_town() -> void:
	var g := PeopleFixture.genoa()
	g.player = &""  # Alba is Savoy's: the viewer "" sees every hex
	var o := PeopleView.outlook(g, TURIN_VILLAGE)
	assert_eq(o["text"], "Grows into a town at 4,000 people (in about 34 seasons).")
	assert_eq(o["tone"], &"good")


func test_outlook_stays_a_village_beside_a_town() -> void:
	var g := PeopleFixture.genoa()
	g.player = &""  # Lucca is Tuscany's
	var o := PeopleView.outlook(g, LUCCA)
	assert_true(str(o["text"]).begins_with("Stays a village: "), o["text"])
	assert_true(str(o["text"]).contains("a town beside"), o["text"])
	assert_true(str(o["text"]).contains("two towns may not stand side by side"), o["text"])
	assert_eq(o["tone"], &"plain")


func test_outlook_a_work_under_way() -> void:
	var g := PeopleFixture.genoa()
	var work := Work.new()
	work.hex = SAVONA
	g.state.works.append(work)
	var o := PeopleView.outlook(g, SAVONA)
	assert_eq(o["text"], "A work is under way here.")
	assert_eq(o["tone"], &"plain")


func test_outlook_town_walled_and_city_rows() -> void:
	var g := PeopleFixture.genoa()
	g.state.people[_i(g, SAVONA)] = 10300
	var o := PeopleView.outlook(g, SAVONA)
	assert_eq(o["text"], "Room for 9,700 more; walls would give room for 45,000.")
	assert_eq(o["tone"], &"plain")
	g.state.people[_i(g, SAVONA)] = 20000
	o = PeopleView.outlook(g, SAVONA)
	assert_eq(o["text"], "Full at 20,000: walls would give it room (a work).")
	assert_eq(o["tone"], &"warn")
	g.state.people[_i(g, GENOA)] = 30300
	o = PeopleView.outlook(g, GENOA)
	assert_eq(o["text"], "Room for 14,700 more; a city would give room for 100,000.")
	g.state.people[_i(g, GENOA)] = 45000
	o = PeopleView.outlook(g, GENOA)
	assert_eq(o["text"], "Full at 45,000: a city would give it room (a work).")
	assert_eq(o["tone"], &"warn")
	g.state.level[_i(g, GENOA)] = 5
	g.state.people[_i(g, GENOA)] = 60300
	o = PeopleView.outlook(g, GENOA)
	assert_eq(o["text"], "Room for 39,700 more.")
	g.state.people[_i(g, GENOA)] = 100000
	o = PeopleView.outlook(g, GENOA)
	assert_eq(o["text"], "Full: a city holds no more.")
	assert_eq(o["tone"], &"plain")



func test_outlook_other_land() -> void:
	var g := PeopleFixture.genoa()
	var hex := Vector2i(7, 12)
	var i := _i(g, hex)
	var room := People.room_i(g, _view(g), i)
	g.state.people[i] = room - 2000
	var o := PeopleView.outlook(g, hex)
	assert_true(str(o["text"]).begins_with("Room for 2,000 more: about "), o["text"])
	assert_true(str(o["text"]).ends_with(" come each season."), o["text"])
	assert_eq(o["tone"], &"plain")
	g.state.people[i] = room
	assert_eq(PeopleView.outlook(g, hex)["text"], "Full: the land holds %s." % Words.number(room))
	var crowd := room + 1000
	g.state.people[i] = crowd
	o = PeopleView.outlook(g, hex)
	var leave := mini(1000, (crowd * 200 + 9999) / 10000)
	assert_eq(o["text"], "Crowded: about %s leave each season." % Words.number(leave))
	assert_eq(o["tone"], &"warn")


func test_outlook_nobody_lives_here_and_unowned() -> void:
	var g := PeopleFixture.genoa()
	g.player = &""
	var found := false
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1 and int(g.state.owner[i]) > 0 and g.state.main_use[i] != People.SETTLEMENTS 				and g.state.people[i] == 0 and People.room_i(g, _view(g), i) == 0:
			assert_eq(PeopleView.outlook(g, g.map.hex_of(i))["text"], "No one lives here.")
			found = true
			break
	assert_true(found, "some owned hex holds no one and has no room")
	assert_eq(PeopleView.outlook(g, Vector2i(-1, -1)), {})
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1 and int(g.state.owner[i]) == 0:
			assert_eq(PeopleView.outlook(g, g.map.hex_of(i)), {}, "unowned land has no outlook")
			break


func test_seasons_to_full() -> void:
	var g := PeopleFixture.genoa()
	assert_eq(PeopleView.seasons_to_full(g, _view(g), TURIN_VILLAGE), 34)
	var full := _i(g, Vector2i(7, 12))
	g.state.people[full] = People.room_i(g, _view(g), full)
	assert_eq(PeopleView.seasons_to_full(g, _view(g), Vector2i(7, 12)), 0, "a full hex")
	assert_eq(PeopleView.seasons_to_full(g, _view(g), Vector2i(-1, -1)), -1)
	var still := PeopleFixture.genoa(PeopleFixture.still())
	assert_eq(PeopleView.seasons_to_full(still, _view(still), TURIN_VILLAGE), -1, "no growth: never")
	var v := _view(g).with_people({_i(g, TURIN_VILLAGE): 4000})
	assert_eq(PeopleView.seasons_to_full(g, v, TURIN_VILLAGE), 0, "the view's people are read")


func test_ribbons_one_percent_and_hunger() -> void:
	var g := PeopleFixture.genoa()
	assert_eq(PeopleView.ribbons(g, &"GEN").size(), 0, "before a season")
	Season.run(g)
	var list := PeopleView.ribbons(g, &"GEN")
	assert_eq(list.size(), 2, "Genoa +300 of 30,000 and Savona +100 of 10,000 are a hundredth each")
	assert_eq(list[0]["hex"], SAVONA, "index order")
	assert_eq(list[0]["text"], "People +100")
	assert_eq(list[0]["tone"], &"good")
	assert_eq(list[1]["text"], "People +300")
	g.state.people_start[_i(g, SAVONA)] = 100000
	g.state.people_end[_i(g, SAVONA)] = 100500
	assert_eq(PeopleView.ribbons(g, &"GEN").size(), 1, "under a hundredth: none")
	Countries.by_tag(g, &"GEN").food_fed = 0
	g.state.people_start[_i(g, SAVONA)] = 100000
	g.state.people_end[_i(g, SAVONA)] = 99999
	list = PeopleView.ribbons(g, &"GEN")
	assert_eq(list[0]["text"], "Hunger −1", "a hunger loss under a hundredth still shows")
	assert_eq(list[0]["tone"], &"bad")
	assert_eq(PeopleView.ribbons(g, &"XXX").size(), 0)


func test_the_views_write_nothing() -> void:
	var g := PeopleFixture.genoa()
	var before := g.digest()
	PeopleView.at(g, &"GEN", GENOA)
	PeopleView.outlook(g, TURIN_VILLAGE)
	PeopleView.outlook(g, LUCCA)
	PeopleView.totals(g, &"GEN")
	PeopleView.ribbons(g, &"GEN")
	assert_eq(g.digest(), before)


func test_the_fog_outlook_and_ribbons_of_others_give_nothing() -> void:
	var g := PeopleFixture.genoa()
	PeopleFixture.play(g, 1)
	var france := _land_of(g, &"FRA")
	assert_eq(PeopleView.outlook(g, france), {}, "an unknown country's hex has no outlook")
	assert_eq(PeopleView.outlook(g, TURIN_VILLAGE), {}, "nor has a known country's")
	assert_eq(PeopleView.outlook(g, LUCCA), {})
	var sie := Countries.by_tag(g, &"SIE")
	sie.food_fed = 0
	for i: int in Territory.districts(g, sie.id):
		if g.state.main_use[i] == People.SETTLEMENTS:
			assert_eq(PeopleView.outlook(g, g.map.hex_of(i)), {}, "no Hungry line for another country's town")
	assert_eq(PeopleView.ribbons(g, &"SIE"), [] as Array[Dictionary])
	assert_eq(PeopleView.ribbons(g, &"MLO"), [] as Array[Dictionary])
	assert_ne(PeopleView.outlook(g, GENOA), {}, "your own hex still has one")
	assert_gt(PeopleView.ribbons(g, &"GEN").size(), 0)
	g.player = &""
	assert_ne(PeopleView.outlook(g, france), {}, "the viewer empty sees everything")


func test_seasons_to_full_at_the_horizon() -> void:
	var g := PeopleFixture.genoa()
	var hex := Vector2i(-1, -1)
	for i: int in Territory.districts(g, Countries.by_tag(g, &"GEN").id):
		if g.state.main_use[i] != People.SETTLEMENTS and People.room_i(g, _view(g), i) == 2500:
			hex = g.map.hex_of(i)
			break
	if hex.x < 0:
		for i: int in Territory.districts(g, Countries.by_tag(g, &"GEN").id):
			if g.state.main_use[i] != People.SETTLEMENTS and People.room_i(g, _view(g), i) > 0:
				hex = g.map.hex_of(i)
				break
	var i := _i(g, hex)
	var room := People.room_i(g, _view(g), i)
	var c := Countries.by_tag(g, &"GEN")
	# a reference walk, one step more than the horizon allowed
	var exact := -1
	for start: int in range(1, room):
		var crowd := start
		var steps := -1
		for n: int in PeopleView.HORIZON + 1:
			if crowd >= room:
				steps = n
				break
			var rates := People.rates_of(g.defs, Economy.slot_for(int(g.map.climate[i]), Calendar.season_of(g.turn + n)), c.tax)
			crowd += People.rule_of(g.defs, crowd, room, false, rates, 1000).x
		var got := PeopleView.seasons_to_full(g, _view(g).with_people({i: start}), hex)
		assert_eq(got, steps, "from %d people" % start)
		if steps == PeopleView.HORIZON:
			exact = start
	assert_gt(exact, 0, "some start needs exactly the horizon")
	if exact > 0:
		assert_eq(PeopleView.seasons_to_full(g, _view(g).with_people({i: exact}), hex), 400, "full on the 400th step")
