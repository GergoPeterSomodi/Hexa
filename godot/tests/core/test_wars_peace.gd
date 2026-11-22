## The peace checks (docs/architecture/m7-build-spec.md 4.9), what a peace would cede (ceded) and the books of a fought battle
## (book_battle), M7 plan B5. The peace itself (make_peace, the timer) is B11 and is not called here.
extends GutTest

var g: Game = null
var nb: StringName = &""
const GEN := ArmyFixture.TAG


func before_each() -> void:
	g = WarFixture.game()
	nb = WarFixture.neighbour_of(g, GEN)


## The long name (CountryDef.long_name), the words of "the %s" in the spec (4.9).
func _long(tag: StringName) -> String:
	return Countries.def_of(g, tag).long_name


func _peace(terms: String, target: StringName = &"") -> Dictionary:
	var who := target if target != &"" else nb
	return Wars.make_peace_check(g, {"target": who, "terms": terms, "tag": GEN})


func _non_capital(tag: StringName, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var capital := Countries.by_tag(g, tag).capital
	for i: int in Territory.districts(g, Countries.by_tag(g, tag).id):
		var hex := g.map.hex_of(i)
		if hex != capital and out.size() < n:
			out.append(hex)
	return out


func test_the_roster_and_the_terms_refusals() -> void:
	assert_eq(Wars.make_peace_check(g, {"terms": "white", "tag": GEN}).reason, "no country given", "row 1: no target")
	assert_eq(Wars.make_peace_check(g, {"target": nb, "tag": GEN}).reason, "no terms given", "row 1: no terms")
	assert_eq(Wars.make_peace_check(g, {"target": nb, "terms": "white"}).reason, "choose your country first", "row 2 (tag)")
	assert_eq(_peace("white", &"ZZZ").reason, "no country ZZZ", "row 2 (target)")
	WarFixture.at_war(g, GEN, nb)
	assert_eq(_peace("boom").reason, "no such terms: take, white or yield", "row 4")


func test_row_3_not_at_war() -> void:
	assert_eq(_peace("white").reason, "not at war with the %s" % _long(nb))


func test_row_5_a_white_peace_needs_the_war_to_be_old() -> void:
	WarFixture.at_war(g, GEN, nb)
	var need := g.defs.war.peace_min_seasons
	assert_eq(_peace("white").reason, "a white peace needs %d seasons of war: %d more" % [need, need],
		"a war of no seasons")
	g.turn += need
	assert_true(bool(_peace("white")["ok"]), "once the war is old enough, the score decides")


func test_row_6_a_white_peace_is_refused_to_a_winning_side() -> void:
	var w := WarFixture.at_war(g, GEN, nb)
	w.start_turn = g.turn - g.defs.war.peace_min_seasons
	for hex: Vector2i in _non_capital(GEN, 2):
		WarFixture.set_occupier(g, hex, nb)
	var total := Wars.score(g, GEN, nb)
	assert_true(total < g.defs.war.white_score_min, "the other side is winning")
	assert_eq(_peace("white").reason, "they are winning (score %+d): they refuse a white peace" % total)


func test_a_white_peace_is_allowed_at_an_even_score() -> void:
	var w := WarFixture.at_war(g, GEN, nb)
	w.start_turn = g.turn - g.defs.war.peace_min_seasons
	assert_eq(_peace("white"), {"ok": true, "reason": ""})


func test_row_7_a_take_needs_one_of_their_districts() -> void:
	WarFixture.at_war(g, GEN, nb)
	assert_eq(_peace("take").reason, "you hold none of their districts")


func test_row_8_a_take_refused_on_a_small_score_and_a_bigger_army() -> void:
	WarFixture.at_war(g, GEN, nb)
	WarFixture.set_occupier(g, _non_capital(nb, 1)[0], GEN)
	WarFixture.army_at(g, nb, g.map.hex_of(Territory.districts(g, Countries.by_tag(g, nb).id)[0]), 2)
	var total := Wars.score(g, GEN, nb)
	assert_eq(total, 1)
	assert_eq(_peace("take").reason, "they refuse: score %+d; hold %d or more of their districts, or beat their armies"
		% [total, g.defs.war.take_score])


func test_row_8_a_take_allowed_on_enough_districts() -> void:
	WarFixture.at_war(g, GEN, nb)
	for hex: Vector2i in _non_capital(nb, g.defs.war.take_score):
		WarFixture.set_occupier(g, hex, GEN)
	assert_true(Wars.score(g, GEN, nb) >= g.defs.war.take_score)
	assert_eq(_peace("take"), {"ok": true, "reason": ""})


func test_a_yield_has_no_score_rule() -> void:
	WarFixture.at_war(g, GEN, nb)
	assert_eq(_peace("yield"), {"ok": true, "reason": ""})


func test_ceded_white_and_no_war_move_nothing() -> void:
	var w := WarFixture.at_war(g, GEN, nb)
	WarFixture.set_occupier(g, _non_capital(nb, 1)[0], GEN)
	assert_eq(Wars.ceded(g, w, &"white", GEN), [] as Array[Vector2i])
	assert_eq(Wars.ceded(g, null, &"take", GEN), [] as Array[Vector2i], "no war")


func test_ceded_take_is_the_districts_the_actor_holds_without_the_capital() -> void:
	var w := WarFixture.at_war(g, GEN, nb)
	var held := _non_capital(nb, 3)
	for hex: Vector2i in held:
		WarFixture.set_occupier(g, hex, GEN)
	var capital := Countries.by_tag(g, nb).capital
	WarFixture.set_occupier(g, capital, GEN)
	var ceded := Wars.ceded(g, w, &"take", GEN)
	assert_eq(ceded.size(), 3, "the capital stays with its owner")
	assert_false(ceded.has(capital))
	for hex: Vector2i in held:
		assert_true(ceded.has(hex))
	var sorted := ceded.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return g.map.index_of(a) < g.map.index_of(b))
	assert_eq(ceded, sorted, "hex index order")


func test_ceded_yield_is_the_actors_districts_the_target_holds() -> void:
	var w := WarFixture.at_war(g, GEN, nb)
	var mine := _non_capital(GEN, 2)
	for hex: Vector2i in mine:
		WarFixture.set_occupier(g, hex, nb)
	assert_eq(Wars.ceded(g, w, &"yield", GEN).size(), 2)
	assert_eq(Wars.ceded(g, w, &"take", nb).size(), 2, "the same moves from the other side's take")


func test_planted_a_take_that_would_empty_a_country_lists_one_less() -> void:
	var w := WarFixture.at_war(g, GEN, nb)
	Countries.by_tag(g, nb).capital = Country.NO_HEX
	var held := Territory.districts(g, Countries.by_tag(g, nb).id)
	for i: int in held:
		WarFixture.set_occupier(g, g.map.hex_of(i), GEN)
	assert_gt(held.size(), 0)
	assert_eq(Wars.ceded(g, w, &"take", GEN).size(), held.size() - 1, "one district stays with the target")


## A battle as Combat.fight ends it (its winner an int: 0 the attacker, 1 the defender, -1 a draw; killed and wounded_total
## packed per side), made by CombatFixture.record_of with this war's two sides.
func _real_record() -> BattleRecord:
	var war := CombatFixture.war()
	var input := CombatFixture.input_of(war, [CombatFixture.pikemen(1, 0, 500), CombatFixture.pikemen(2, 1, 100)])
	var rec := CombatFixture.record_of(war, input, 11)
	rec.attacker = GEN
	rec.defender = nb
	return rec


func test_book_battle_books_a_real_record() -> void:
	var w := WarFixture.at_war(g, GEN, nb)
	var rec := _real_record()
	var winner := int(rec.end["winner"])
	var killed: Array = Array(rec.end["killed"])
	var wounded: Array = Array(rec.end["wounded_total"])
	Wars.book_battle(g, rec)
	assert_eq(w.won_a, 1 if winner == 0 else 0, "the attacker's win, from the winner's int")
	assert_eq(w.won_b, 1 if winner == 1 else 0, "the defender's win")
	assert_eq(w.lost_a, int(killed[0]) + int(wounded[0]), "the attacker's killed and wounded")
	assert_eq(w.lost_b, int(killed[1]) + int(wounded[1]), "the defender's killed and wounded")
	assert_gt(w.lost_a + w.lost_b, 0, "men were lost")


func test_book_battle_books_a_record_read_back_from_json() -> void:
	var rec := _real_record()
	var back := BattleRecord.from_dict(JSON.parse_string(JSON.stringify(rec.to_dict())) as Dictionary)
	assert_not_null(back, "the record reads back")
	if back == null:
		return
	var a := WarFixture.at_war(g, GEN, nb)
	Wars.book_battle(g, rec)
	var other := WarFixture.game()
	var b := WarFixture.at_war(other, GEN, nb)
	Wars.book_battle(other, back)
	assert_eq([b.won_a, b.won_b, b.lost_a, b.lost_b], [a.won_a, a.won_b, a.lost_a, a.lost_b],
		"the same books from the record and from its saved form")


func test_a_draw_books_the_men_and_no_win() -> void:
	var w := WarFixture.at_war(g, GEN, nb)
	var rec := _real_record()
	rec.end["winner"] = -1
	Wars.book_battle(g, rec)
	assert_eq(w.won_a + w.won_b, 0, "no side wins a draw")
	assert_gt(w.lost_a + w.lost_b, 0, "the men are still booked")


func test_the_defender_wins_books_its_win() -> void:
	var w := WarFixture.at_war(g, GEN, nb)
	var rec := _real_record()
	rec.end["winner"] = 1
	Wars.book_battle(g, rec)
	assert_eq(w.won_b, 1, "the defender's win")
	assert_eq(w.won_a, 0)


func test_the_sides_follow_the_tags_not_the_order_of_the_war() -> void:
	var w := WarFixture.at_war(g, nb, GEN)  # the defender is the war's a this time
	var rec := _real_record()
	var killed: Array = Array(rec.end["killed"])
	var wounded: Array = Array(rec.end["wounded_total"])
	rec.end["winner"] = 0  # the attacker, GEN, wins
	Wars.book_battle(g, rec)
	assert_eq(w.won_b, 1, "GEN is the war's b here")
	assert_eq(w.won_a, 0)
	assert_eq(w.lost_b, int(killed[0]) + int(wounded[0]), "GEN's men booked on b")
	assert_eq(w.lost_a, int(killed[1]) + int(wounded[1]), "the defender's on a")


func test_wounded_who_returned_are_taken_back() -> void:
	var rec := _real_record()
	var killed: Array = Array(rec.end["killed"])
	var wounded: Array = Array(rec.end["wounded_total"])
	rec.end["returned"] = {1: 8, 2: 10}  # unit keys 1 (attacker's company) and 2 (defender's), from the input's fighters
	var w := WarFixture.at_war(g, GEN, nb)
	Wars.book_battle(g, rec)
	assert_eq(w.lost_a, int(killed[0]) + int(wounded[0]) - 8, "the attacker's returned men are not lost")
	assert_eq(w.lost_b, int(killed[1]) + int(wounded[1]) - 10, "the defender's returned men are not lost")


func test_book_battle_with_no_live_war_books_nothing() -> void:
	var rec := _real_record()
	Wars.book_battle(g, rec)
	assert_eq(g.wars.size(), 0)
