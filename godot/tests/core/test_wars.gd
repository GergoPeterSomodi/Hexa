## The war door's declarations, score, truce, queries and saved body (docs/architecture/m7-build-spec.md 4.2, 4.20, 5.3; M7 plan
## B5). Every row of declare_war_check is checked with its words; the score is antisymmetric and reads the occupiers; the truce
## is the newest ended war; wars load only when they name living countries and sane seasons. The peace checks, ceded and
## book_battle are in test_wars_peace.gd.
extends GutTest

var g: Game = null
var nb: StringName = &""


func before_each() -> void:
	g = WarFixture.game()
	nb = WarFixture.neighbour_of(g, ArmyFixture.TAG)


func after_each() -> void:
	Wars.fight_seam.clear()


## The long name (CountryDef.long_name: "the Duchy of Savoy"), the words of "the %s" in the spec (4.2, 4.9).
func _long(tag: StringName) -> String:
	return Countries.def_of(g, tag).long_name


## The short name (CountryDef.name), the words of "%s is no more" (4.2 row 6).
func _short(tag: StringName) -> String:
	return Countries.def_of(g, tag).name


func _declare(target: StringName, tag: StringName = ArmyFixture.TAG) -> Dictionary:
	return Wars.declare_war_check(g, {"target": target, "tag": tag})


func test_the_fixture_has_a_neighbour_and_a_stranger() -> void:
	assert_ne(nb, &"", "Genoa has a neighbour in the 1480 scenario")
	assert_ne(WarFixture.stranger_of(g, ArmyFixture.TAG), &"", "and a country that shares no border")


func test_the_declaration_check_rows_each_with_its_words() -> void:
	assert_eq(_declare(&""), {"ok": false, "reason": "no country given"}, "row 1: no target")
	assert_eq(_declare(nb, &"").reason, "choose your country first", "row 3: no tag")
	assert_eq(_declare(&"ZZZ").reason, "no country ZZZ", "row 4: the target is no country")
	assert_eq(_declare(ArmyFixture.TAG, ArmyFixture.TAG).reason, "a country cannot make war on itself", "row 5")
	assert_eq(_declare(nb, &"QQQ").reason, "no country QQQ", "row 4: the tag is no country")


func test_row_2_a_map_without_countries_refuses() -> void:
	var bare := Game.new_game(EconomyFixture.map(), 1480)
	var verdict := Wars.declare_war_check(bare, {"target": &"ABC", "tag": &"DEF"})
	assert_eq(verdict, {"ok": false, "reason": "this map has no countries"})


func test_row_6_a_country_no_more_is_named() -> void:
	g.countries[Countries.by_tag(g, nb).id - 1].alive = false
	assert_eq(_declare(nb).reason, "%s is no more" % _short(nb), "the target is gone")
	g.countries[Countries.by_tag(g, ArmyFixture.TAG).id - 1].alive = false
	assert_eq(_declare(nb).reason, "%s is no more" % _short(ArmyFixture.TAG), "the actor is gone first")


func test_row_7_a_second_declaration_is_refused() -> void:
	WarFixture.at_war(g, ArmyFixture.TAG, nb)
	assert_eq(_declare(nb).reason, "already at war with the %s" % _long(nb))
	assert_eq(_declare(nb).ok, false)


func test_row_8_a_truce_holds_for_eight_seasons() -> void:
	WarFixture.ended(g, ArmyFixture.TAG, nb, g.turn)
	var seasons := g.defs.war.truce_seasons
	var until := g.turn + seasons
	assert_eq(_declare(nb).reason, "a truce with the %s holds until %s (%d more seasons)" % [_long(nb),
		Calendar.date_text(until, g.start_year), seasons])
	g.turn = until
	assert_true(bool(_declare(nb)["ok"]), "the first season after the truce may declare again")


func test_row_9_only_neighbours_go_to_war() -> void:
	var far := WarFixture.stranger_of(g, ArmyFixture.TAG)
	assert_eq(_declare(far).reason, "only neighbours go to war: the %s shares no border with the %s"
		% [_long(far), _long(ArmyFixture.TAG)])


func test_row_10_a_neighbour_may_be_declared_on() -> void:
	assert_eq(_declare(nb), {"ok": true, "reason": ""})


func test_declare_war_writes_the_war_and_the_event() -> void:
	var before_events := g.events.size()
	var verdict := g.act("declare_war", {"target": nb, "tag": ArmyFixture.TAG})
	assert_true(bool(verdict["ok"]))
	assert_eq(g.wars.size(), 1)
	var w: War = g.wars[0]
	assert_eq(w.id, 1)
	assert_eq(w.a, ArmyFixture.TAG)
	assert_eq(w.b, nb)
	assert_eq(w.start_turn, g.turn)
	assert_eq(g.next_war_id, 2)
	var event := g.events[g.events.size() - 1]
	assert_eq(g.events.size(), before_events + 1)
	assert_eq(event["kind"], "war_declared")
	assert_eq(event["tag"], ArmyFixture.TAG)
	assert_eq(event["target"], nb)
	assert_eq(event["war"], 1)
	assert_eq((event["witnesses"] as PackedStringArray).size(), g.countries.size(), "every living country witnesses")
	assert_eq(g.action_log[g.action_log.size() - 1]["action"], "declare_war")


func test_a_refused_declaration_changes_nothing() -> void:
	var stranger := WarFixture.stranger_of(g, ArmyFixture.TAG)
	var before := Wars.digest(g)
	var events := g.events.size()
	var verdict := g.act("declare_war", {"target": stranger, "tag": ArmyFixture.TAG})
	assert_false(bool(verdict["ok"]))
	assert_eq(Wars.digest(g), before, "the wars are unchanged")
	assert_eq(g.events.size(), events, "no event")
	assert_eq(g.wars.size(), 0)


func test_the_action_is_in_the_table_and_the_pair_is_the_door() -> void:
	assert_true(Actions.NAMES.has("declare_war"))
	var pair := Actions.pair_of("declare_war")
	assert_eq(pair.size(), 2, "a check and a do")
	assert_eq(pair[0], Callable(Wars, "declare_war_check"))
	assert_eq(pair[1], Callable(Wars, "declare_war"))


func test_at_war_is_symmetric_and_ends_with_the_war() -> void:
	assert_false(Wars.at_war(g, ArmyFixture.TAG, nb))
	WarFixture.at_war(g, ArmyFixture.TAG, nb)
	assert_true(Wars.at_war(g, ArmyFixture.TAG, nb))
	assert_true(Wars.at_war(g, nb, ArmyFixture.TAG), "either order")
	g.wars[0].end_turn = g.turn
	assert_false(Wars.at_war(g, ArmyFixture.TAG, nb), "an ended war is not at war")


func test_enemies_are_in_country_id_order() -> void:
	var others: Array[StringName] = []
	for c: Country in g.countries:
		if c.tag != ArmyFixture.TAG:
			others.append(c.tag)
	var late := others[others.size() - 1]
	var early := others[0]
	WarFixture.at_war(g, ArmyFixture.TAG, late)
	WarFixture.at_war(g, ArmyFixture.TAG, early)
	assert_eq(Wars.enemies(g, ArmyFixture.TAG), [early, late] as Array[StringName], "country id order, not war order")
	assert_eq(Wars.enemies(g, early), [ArmyFixture.TAG] as Array[StringName])


func test_war_between_and_of_country_keep_ended_wars() -> void:
	var w := WarFixture.at_war(g, ArmyFixture.TAG, nb)
	assert_eq(Wars.war_between(g, nb, ArmyFixture.TAG), w)
	w.end_turn = g.turn
	w.terms = &"white"
	assert_eq(Wars.war_between(g, nb, ArmyFixture.TAG), null)
	assert_eq(Wars.of_country(g, ArmyFixture.TAG).size(), 1, "the ended war is still of the country")
	assert_eq(Wars.of_country(g, nb)[0], w)


func test_truce_is_the_newest_ended_war_between_the_pair() -> void:
	var seasons := g.defs.war.truce_seasons
	assert_eq(Wars.truce_until(g, ArmyFixture.TAG, nb), 0, "no war ended: no truce")
	WarFixture.ended(g, ArmyFixture.TAG, nb, 10)
	WarFixture.ended(g, nb, ArmyFixture.TAG, 20)
	assert_eq(Wars.truce_until(g, ArmyFixture.TAG, nb), 20 + seasons, "the newest one, in either order")
	var other := WarFixture.stranger_of(g, ArmyFixture.TAG)
	assert_eq(Wars.truce_until(g, ArmyFixture.TAG, other), 0, "a war with another pair gives no truce")


func test_score_counts_occupied_districts_and_is_antisymmetric() -> void:
	var held := _non_capital(nb, 2)
	for hex: Vector2i in held:
		WarFixture.set_occupier(g, hex, ArmyFixture.TAG)
	assert_eq(Wars.occupied_count(g, ArmyFixture.TAG, nb), 2)
	assert_eq(Wars.score(g, ArmyFixture.TAG, nb), 2)
	assert_eq(Wars.score(g, nb, ArmyFixture.TAG), -2, "b's score is the negative")
	assert_eq(Wars.score(g, ArmyFixture.TAG, ArmyFixture.TAG), 0, "a country against itself scores nothing")


func test_score_takes_the_capital_term() -> void:
	var capital := Countries.by_tag(g, nb).capital
	WarFixture.set_occupier(g, capital, ArmyFixture.TAG)
	var cs := g.defs.war.capital_score
	assert_eq(Wars.score(g, ArmyFixture.TAG, nb), 1 + cs, "the capital is a district too, and the term adds")
	assert_eq(Wars.score(g, nb, ArmyFixture.TAG), -(1 + cs))


func test_a_capital_off_the_map_counts_for_nobody() -> void:
	Countries.by_tag(g, nb).capital = Country.NO_HEX
	var hex := _non_capital(nb, 1)[0]
	WarFixture.set_occupier(g, hex, ArmyFixture.TAG)
	assert_eq(Wars.score(g, ArmyFixture.TAG, nb), 1, "only the district counts")


func test_men_under_arms_is_the_armies_count() -> void:
	WarFixture.army_at(g, ArmyFixture.TAG, g.map.hex_of(Territory.districts(g, Countries.by_tag(g, ArmyFixture.TAG).id)[0]), 2)
	assert_eq(Wars.men_under_arms(g, ArmyFixture.TAG), Armies.men_of_country(g, ArmyFixture.TAG))
	assert_gt(Wars.men_under_arms(g, ArmyFixture.TAG), 0)


func test_the_body_round_trips_and_the_digest_holds() -> void:
	WarFixture.at_war(g, ArmyFixture.TAG, nb)
	WarFixture.ended(g, nb, WarFixture.stranger_of(g, ArmyFixture.TAG), g.turn, &"take")
	var body := Wars.to_dict(g)
	var other := WarFixture.game()
	assert_eq(Wars.from_dict(body, other), "", "a saved body loads")
	assert_eq(Wars.digest(other), Wars.digest(g), "and reads back to the same digest")
	assert_eq(other.next_war_id, g.next_war_id)


func test_a_body_is_refused_when_it_names_no_living_country() -> void:
	WarFixture.at_war(g, ArmyFixture.TAG, nb)
	var body := Wars.to_dict(g)
	var other := WarFixture.game()
	other.countries[Countries.by_tag(other, nb).id - 1].alive = false
	assert_ne(Wars.from_dict(body, other), "", "a dead country is refused")
	assert_eq(other.wars.size(), 0, "and nothing changed")
	var unknown := body.duplicate(true)
	unknown["wars"][0]["b"] = "ZZZ"
	assert_ne(Wars.from_dict(unknown, WarFixture.game()), "", "an unknown country is refused")


func test_an_ended_war_may_name_a_country_that_died_since() -> void:
	var w := WarFixture.ended(g, ArmyFixture.TAG, nb, g.turn, &"white")
	assert_eq(w.end_turn, g.turn)
	var body := Wars.to_dict(g)
	var other := WarFixture.game()
	other.countries[Countries.by_tag(other, nb).id - 1].alive = false
	assert_eq(Wars.from_dict(body, other), "", "an ended war loads when its country is no more")
	assert_eq(other.wars.size(), 1, "and it is kept")
	assert_eq(Wars.digest(other), Wars.digest(g), "with the same digest")
	var lg := WarFixture.game()
	WarFixture.at_war(lg, ArmyFixture.TAG, nb)
	var live := Wars.to_dict(lg)
	var dead := WarFixture.game()
	dead.countries[Countries.by_tag(dead, nb).id - 1].alive = false
	assert_ne(Wars.from_dict(live, dead), "", "a live war still needs two living countries")


func test_a_body_is_refused_for_forged_seasons_ids_and_pairs() -> void:
	WarFixture.at_war(g, ArmyFixture.TAG, nb)
	var body := Wars.to_dict(g)
	var future := body.duplicate(true)
	future["wars"][0]["start_turn"] = g.turn + 5
	assert_ne(Wars.from_dict(future, WarFixture.game()), "", "a war from a season not yet played")
	var bad_next := body.duplicate(true)
	bad_next["next_war_id"] = 0
	assert_ne(Wars.from_dict(bad_next, WarFixture.game()), "", "a next id below 1")
	var bad_schema := body.duplicate(true)
	bad_schema["schema"] = "hexa-godot/war/0"
	assert_ne(Wars.from_dict(bad_schema, WarFixture.game()), "", "a wrong schema")
	var twice := body.duplicate(true)
	var listed: Array = twice["wars"]
	var copy: Dictionary = (listed[0] as Dictionary).duplicate(true)
	listed.append(copy)
	copy["id"] = 2
	twice["next_war_id"] = 3
	assert_ne(Wars.from_dict(twice, WarFixture.game()), "", "two live wars between one pair")
	var ids := body.duplicate(true)
	ids["next_war_id"] = 1
	assert_ne(Wars.from_dict(ids, WarFixture.game()), "", "a war id at or above the next id")


func test_a_planted_war_copy_never_reaches_the_committed_numbers() -> void:
	var committed := EconomyFixture.committed().war.capital_score
	g.defs.war.capital_score = 99
	assert_eq(EconomyFixture.committed().war.capital_score, committed, "the committed war is not touched")


## The first `n` districts of tag that are not its capital (in index order).
func _non_capital(tag: StringName, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var capital := Countries.by_tag(g, tag).capital
	for i: int in Territory.districts(g, Countries.by_tag(g, tag).id):
		var hex := g.map.hex_of(i)
		if hex != capital and out.size() < n:
			out.append(hex)
	return out


# ---- the peace and the timer (4.9, B11) ----------------------------------------------------------------------------------

func _peace_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in g.events:
		if str(e.get("kind", "")) == "peace_made":
			out.append(e)
	return out


func _events_of(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in g.events:
		if str(e.get("kind", "")) == kind:
			out.append(e)
	return out


## A live war between Genoa and its neighbour that has lasted the minimum for a white peace.
func _old_war() -> War:
	var w := WarFixture.at_war(g, ArmyFixture.TAG, nb)
	w.start_turn = g.turn - g.defs.war.peace_min_seasons
	return w


func _make(terms: String) -> Dictionary:
	return Wars.make_peace(g, {"target": nb, "terms": terms, "tag": ArmyFixture.TAG})


func _take_held(n: int) -> Array[Vector2i]:
	var held := _non_capital(nb, n)
	for hex: Vector2i in held:
		WarFixture.set_occupier(g, hex, ArmyFixture.TAG)
	return held


func test_a_white_peace_ends_the_war_and_clears_the_occupations() -> void:
	var w := _old_war()
	var mine := _non_capital(nb, 2)
	for hex: Vector2i in mine:
		WarFixture.set_occupier(g, hex, ArmyFixture.TAG)
	var theirs := _non_capital(ArmyFixture.TAG, 1)
	WarFixture.set_occupier(g, theirs[0], nb)
	var nb_districts := Territory.districts(g, Countries.by_tag(g, nb).id).size()
	assert_eq(_make("white"), {"ok": true, "reason": ""})
	assert_false(w.live(), "the war ended")
	assert_eq(w.terms, &"white")
	assert_eq(w.end_turn, g.turn)
	assert_eq(w.moved, 0, "a white peace moves no land")
	for hex: Vector2i in mine + theirs:
		assert_false(Occupation.is_occupied(g, hex), "every occupation between the two clears")
	assert_eq(Territory.districts(g, Countries.by_tag(g, nb).id).size(), nb_districts, "no district changes owner")
	var ev := _peace_events()[0]
	assert_eq(ev["tag"], ArmyFixture.TAG)
	assert_eq(ev["target"], nb)
	assert_eq(ev["war"], w.id)
	assert_eq(ev["terms"], &"white")
	assert_eq((ev["released"] as Array).size(), 3, "the three occupations released")


func test_a_take_moves_the_districts_the_actor_holds_and_keeps_the_capital() -> void:
	var w := _old_war()
	var held := _take_held(3)
	var capital := Countries.by_tag(g, nb).capital
	WarFixture.set_occupier(g, capital, ArmyFixture.TAG)
	assert_true(bool(_make("take")["ok"]))
	assert_false(w.live())
	assert_eq(w.terms, &"take")
	assert_eq(w.moved, 3)
	for hex: Vector2i in held:
		assert_eq(Territory.owner_tag(g, hex), ArmyFixture.TAG, "the district is the winner's")
	assert_eq(Territory.owner_tag(g, capital), nb, "the capital stays with its owner")
	assert_false(Occupation.is_occupied(g, capital), "its occupation clears")
	assert_eq((_peace_events()[0]["moved"] as Array).size(), 3)


func test_a_yield_gives_the_enemy_the_districts_it_holds() -> void:
	var w := _old_war()
	var mine := _non_capital(ArmyFixture.TAG, 2)
	for hex: Vector2i in mine:
		WarFixture.set_occupier(g, hex, nb)
	assert_true(bool(_make("yield")["ok"]))
	assert_eq(w.terms, &"yield")
	assert_eq(w.moved, 2)
	for hex: Vector2i in mine:
		assert_eq(Territory.owner_tag(g, hex), nb, "the enemy takes them")
		assert_false(Occupation.is_occupied(g, hex))


func test_an_army_of_the_loser_on_land_taken_goes_to_its_nearest_own_hex() -> void:
	_old_war()
	var held := _take_held(3)
	var army := WarFixture.army_at(g, nb, held[0], 2)
	var men := Armies.men_of_country(g, nb)
	assert_true(bool(_make("take")["ok"]))
	assert_eq(Territory.owner_tag(g, army.hex), nb, "the army stands on its own land")
	assert_eq(Armies.men_of_country(g, nb), men, "no man lost")
	var best := -1
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.is_land(hex) and Territory.owner_tag(g, hex) == nb:
			var d := ImproveRules.hex_distance(held[0], hex)
			if best < 0 or d < best:
				best = d
	assert_eq(ImproveRules.hex_distance(held[0], army.hex), best, "the nearest own hex (hex distance)")


func test_an_army_of_the_winner_on_the_loser_capital_goes_home() -> void:
	_old_war()
	_take_held(3)
	var capital := Countries.by_tag(g, nb).capital
	var mine := _non_capital(ArmyFixture.TAG, 1)
	var stays := WarFixture.army_at(g, ArmyFixture.TAG, mine[0], 1)
	var army := WarFixture.army_at(g, ArmyFixture.TAG, capital, 2)
	assert_true(bool(_make("take")["ok"]))
	assert_eq(Territory.owner_tag(g, army.hex), ArmyFixture.TAG, "home is Genoa's land")
	assert_ne(army.hex, capital)
	assert_eq(stays.hex, mine[0], "an army on its own land stays where it is")


func test_a_marching_army_sent_home_halts_with_why_peace() -> void:
	_old_war()
	var held := _take_held(3)
	var capital := Countries.by_tag(g, nb).capital
	var army := WarFixture.army_at(g, ArmyFixture.TAG, capital, 1)
	Armies.set_order(g, army, Army.ORDER_MARCH, held[1], PackedInt32Array())
	assert_true(bool(_make("take")["ok"]))
	assert_eq(army.order, Army.ORDER_NONE, "the order is cleared")
	assert_eq(army.halt_why, &"peace")
	var halts := _events_of("march_halted")
	assert_eq(halts.size(), 1, "one halt")
	assert_eq(halts[0]["why"], "peace")
	assert_eq(halts[0]["hex"], army.hex)


func test_an_army_with_no_room_is_disbanded_home_and_no_man_is_lost() -> void:
	_old_war()
	var held := _take_held(3)
	var army := WarFixture.army_at(g, nb, held[0], g.defs.stack_limit + 1)
	var men := Armies.men_of_country(g, nb)
	var people_before := 0
	for n: int in g.state.people:
		people_before += n
	assert_true(bool(_make("take")["ok"]))
	assert_null(Armies.by_id(g, army.id), "the army is gone")
	var people_after := 0
	for n: int in g.state.people:
		people_after += n
	assert_eq(people_after - people_before, men, "every man went back to the people")
	var gone := _events_of("army_disbanded")
	assert_eq(gone.size(), 1)
	assert_eq(gone[0]["men"], men)


func test_the_timer_ends_a_war_at_forty_seasons_as_a_white_peace() -> void:
	var w := WarFixture.at_war(g, ArmyFixture.TAG, nb)
	var held := _non_capital(nb, 1)
	WarFixture.set_occupier(g, held[0], ArmyFixture.TAG)
	g.turn = w.start_turn + 39
	Wars.season(g)
	assert_true(w.live(), "39 seasons: the war goes on")
	g.turn = w.start_turn + 40
	Wars.season(g)
	assert_false(w.live(), "40 seasons: the war ends")
	assert_eq(w.terms, &"timer")
	assert_eq(w.moved, 0, "a timer peace moves no land")
	assert_false(Occupation.is_occupied(g, held[0]), "its occupation returns")
	assert_eq(Territory.owner_tag(g, held[0]), nb)
	var ev := _peace_events()[0]
	assert_eq(ev["terms"], &"timer")
	assert_eq(ev["tag"], w.a)


func test_a_truce_holds_for_eight_seasons_after_the_peace() -> void:
	_old_war()
	assert_true(bool(_make("white")["ok"]))
	var until := g.turn + g.defs.war.truce_seasons
	assert_eq(Wars.truce_until(g, ArmyFixture.TAG, nb), until)
	var verdict := Wars.declare_war_check(g, {"target": nb, "tag": ArmyFixture.TAG})
	assert_eq(verdict["reason"], "a truce with the %s holds until %s (%d more seasons)" % [_long(nb),
		Calendar.date_text(until, g.start_year), until - g.turn])
	g.turn = until
	assert_true(bool(Wars.declare_war_check(g, {"target": nb, "tag": ArmyFixture.TAG})["ok"]), "the truce is over")


func test_peace_made_witnesses_every_living_country() -> void:
	_old_war()
	assert_true(bool(_make("white")["ok"]))
	assert_eq(_peace_events()[0]["witnesses"], Wars.living_tags(g))


func test_the_fights_between_the_two_end_first_through_their_doors() -> void:
	var w := _old_war()
	var calls: Array = []
	Wars.fight_seam[&"battles"] = func(_gm: Game, a: StringName, b: StringName) -> void:
		calls.append(["battles", a, b, w.live()])
	Wars.fight_seam[&"sieges"] = func(_gm: Game, a: StringName, b: StringName) -> void:
		calls.append(["sieges", a, b, w.live()])
	var sieges_before := g.sieges.size()
	assert_true(bool(_make("white")["ok"]))
	assert_eq(calls, [["battles", ArmyFixture.TAG, nb, true], ["sieges", ArmyFixture.TAG, nb, true]],
		"battles, then sieges, while the war still lasts")
	assert_eq(g.sieges.size(), sieges_before, "the peace writes no siege: the sieges phase lifts them")


func test_a_refused_peace_changes_nothing() -> void:
	var w := WarFixture.at_war(g, ArmyFixture.TAG, nb)
	var before := g.digest()
	var events := g.events.size()
	assert_false(bool(_make("white")["ok"]), "a war of no seasons is too young for a white peace")
	assert_true(w.live())
	assert_eq(g.digest(), before)
	assert_eq(g.events.size(), events)


func test_make_peace_is_an_action_and_the_door_checks_it() -> void:
	assert_true(Actions.NAMES.has("make_peace"))
	var pair := Actions.pair_of("make_peace")
	assert_eq(pair[0], Callable(Wars, "make_peace_check"))
	assert_eq(pair[1], Callable(Wars, "make_peace"))
	var w := _old_war()
	var verdict := g.act("make_peace", {"target": nb, "terms": "white", "tag": ArmyFixture.TAG})
	assert_true(bool(verdict["ok"]))
	assert_false(w.live())
	assert_eq(g.action_log[g.action_log.size() - 1]["action"], "make_peace")


func test_a_fight_door_is_a_static_function_of_its_file_or_nothing() -> void:
	assert_false(Wars.door(&"x", "res://core/systems/not_a_system_b11.gd", &"end_all").is_valid(), "no file, no door")
	assert_true(Wars.door(&"x", "res://core/systems/wars.gd", &"season").is_valid(), "a static function is a door")
	assert_false(Wars.door(&"x", "res://core/systems/wars.gd", &"no_such_function").is_valid(), "no function, no door")
	Wars.fight_seam[&"x"] = Callable(self, "after_each")
	assert_eq(Wars.door(&"x", "res://core/systems/not_a_system_b11.gd", &"end_all"), Callable(self, "after_each"),
		"the test seam wins")


func test_men_with_no_free_hex_are_booked_as_lost() -> void:
	_old_war()
	var held := _take_held(3)
	var army := WarFixture.army_at(g, nb, held[0], g.defs.stack_limit + 1)
	var men := Armies.men_of_country(g, nb)
	for i: int in Territory.districts(g, Countries.by_tag(g, nb).id):
		g.state.people[i] = People.PEOPLE_MAX
	var people_before := 0
	for n: int in g.state.people:
		people_before += n
	assert_true(bool(_make("take")["ok"]))
	assert_null(Armies.by_id(g, army.id), "the army is gone")
	var people_after := 0
	for n: int in g.state.people:
		people_after += n
	assert_eq(people_after - people_before, 0, "no room anywhere: no man goes to the people")
	var gone := _events_of("army_disbanded")
	assert_eq(gone.size(), 1)
	assert_eq(gone[0]["lost"], men, "every man is booked as lost")


## Two adjacent land hexes: the first held by a, the second by b (empty when none).
func _border_pair(a: StringName, b: StringName) -> Array[Vector2i]:
	for i: int in g.map.hex_count():
		var h := g.map.hex_of(i)
		if not g.map.is_land(h) or Territory.owner_tag(g, h) != a:
			continue
		for d: int in 6:
			var n := g.map.neighbour(h, d)
			if g.map.has(n) and g.map.is_land(n) and Territory.owner_tag(g, n) == b:
				return [h, n]
	return []


func test_a_peace_with_a_real_battle_in_the_field_runs_through_the_door() -> void:
	var w := _old_war()
	var pair := _border_pair(ArmyFixture.TAG, nb)
	assert_eq(pair.size(), 2, "Genoa shares a border with its neighbour")
	if pair.size() != 2:
		return
	var att := WarFixture.army_at(g, ArmyFixture.TAG, pair[0], 2)
	WarFixture.army_at(g, nb, pair[1], 2)
	assert_true(Battles.engage(g, att, pair[1], 1, -1), "a real battle starts")
	assert_eq(g.battles.size(), 1, "one battle in the field")
	assert_true(bool(_make("white")["ok"]), "the peace is made with the battle in the field")
	assert_false(w.live(), "the war ended")
	assert_eq(_peace_events().size(), 1, "one peace_made")


func test_a_forged_huge_war_list_is_refused_before_any_war_is_read() -> void:
	var list: Array = []
	list.resize(Wars.MAX_WARS + 1)
	list.fill({})
	var body := {"schema": War.SCHEMA, "next_war_id": 1, "wars": list}
	assert_eq(Wars.from_dict(body, WarFixture.game()), Wars.PROBLEM_BODY, "one war over the cap is refused")
	assert_eq(WarFixture.game().wars.size(), 0)


func test_a_draw_books_the_same_whichever_side_the_record_names_as_loser() -> void:
	var first := WarFixture.game()
	var wf := WarFixture.at_war(first, ArmyFixture.TAG, WarFixture.neighbour_of(first, ArmyFixture.TAG))
	var second := WarFixture.game()
	var ws := WarFixture.at_war(second, ArmyFixture.TAG, WarFixture.neighbour_of(second, ArmyFixture.TAG))
	var rec := _real_record()
	rec.end["winner"] = -1
	rec.end["loser"] = rec.attacker
	Wars.book_battle(first, rec)
	rec.end["loser"] = rec.defender
	Wars.book_battle(second, rec)
	assert_eq([wf.won_a, wf.won_b, wf.lost_a, wf.lost_b], [ws.won_a, ws.won_b, ws.lost_a, ws.lost_b],
		"a draw books the same whatever loser says")
	assert_eq(wf.won_a + wf.won_b, 0, "no win in a draw")


## A battle as Combat.fight ends it, made with this war's two sides (as in test_wars_peace.gd).
func _real_record() -> BattleRecord:
	var war := CombatFixture.war()
	var input := CombatFixture.input_of(war, [CombatFixture.pikemen(1, 0, 500), CombatFixture.pikemen(2, 1, 100)])
	var rec := CombatFixture.record_of(war, input, 11)
	rec.attacker = ArmyFixture.TAG
	rec.defender = nb
	return rec
