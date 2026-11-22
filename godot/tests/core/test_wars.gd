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
