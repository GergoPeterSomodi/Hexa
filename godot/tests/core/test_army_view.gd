## ArmyView (docs/architecture/m6-build-spec.md sections 4.12, 5.6 and 9, L11): tokens per (hex, country) the viewer sees,
## exact texts, the panel's order texts, needing_orders and the hex card's Armies text. North Italy: Genoa (GEN)
## is the player; Savoy (SAV) is the foreign country. Planted faults: an unseen foreign army is absent from the tokens.
extends GutTest

const SAV := &"SAV"

var _g: Game


func before_each() -> void:
	_g = ArmyFixture.game()


func _gen_hex() -> Vector2i:
	return ArmyFixture.find_town(_g)


## A land hex the player does not see (Sight), or NO_HEX.
func _unseen_land() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if _g.map.land[i] == 1 and not Knowledge.sees(_g, ArmyFixture.TAG, hex):
			return hex
	return ArmyFixture.NO_HEX


## M7 (6.8): the own panel's standing, morale words, rank and the token's shaken flag; a foreign panel has none of them.
func test_war_parts_of_the_own_panel_and_the_shaken_token() -> void:
	var hex := _gen_hex()
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 2)
	var p := ArmyView.panel(_g, ArmyFixture.TAG, a.id)
	assert_eq(p.standing, "hold")
	assert_eq(p.standing_text, "Hold")
	assert_eq(p.morale_word, "Steady")
	assert_eq(p.morale_text, "Morale 100 %")
	assert_false(bool(p.too_shaken))
	assert_eq((p.siege as Dictionary).size(), 0)
	assert_eq(str((p.units as Array)[0].rank_name), "Recruit")
	assert_eq(int((p.units as Array)[0].morale), 1000)
	for u: Unit in a.units:
		Armies.set_morale(_g, a, u.id, 300)
	var shaken := ArmyView.panel(_g, ArmyFixture.TAG, a.id)
	assert_eq(shaken.morale_word, "Shaken")
	assert_true(bool(shaken.too_shaken))
	var token := _token_at(ArmyView.tokens(_g, ArmyFixture.TAG), hex, ArmyFixture.TAG)
	assert_true(bool(token.shaken), "the own token shows the shaken flag")
	var foreign := ArmyFixture.army(_g, SAV, _unseen_land(), 0, 1)
	var seen := ArmyView.panel(_g, ArmyFixture.TAG, foreign.id)
	assert_true(seen.is_empty() or not seen.has("standing"), "P: another country's standing is not the viewer's to know")
	assert_true(seen.is_empty() or not seen.has("morale"), "P: another country's morale is not the viewer's to know")


func _token_at(tokens: Array[Dictionary], hex: Vector2i, tag: StringName) -> Dictionary:
	for t: Dictionary in tokens:
		if t.hex == hex and t.tag == tag:
			return t
	return {}


## D7: the badge text is exact for every token; no banded "~" form is left.
func test_token_text_is_exact() -> void:
	assert_eq(ArmyView.token_text(450), "450")
	assert_eq(ArmyView.token_text(999), "999")
	assert_eq(ArmyView.token_text(1000), "1.0k")
	assert_eq(ArmyView.token_text(1234), "1.2k")
	assert_eq(ArmyView.token_text(1249), "1.2k")
	assert_eq(ArmyView.token_text(1450), "1.5k")


func test_own_army_is_an_exact_token_with_its_figure() -> void:
	var hex := _gen_hex()
	assert_ne(hex, ArmyFixture.NO_HEX)
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 2)
	var tokens := ArmyView.tokens(_g, ArmyFixture.TAG)
	var t := _token_at(tokens, hex, ArmyFixture.TAG)
	assert_false(t.is_empty(), "the player's army has a token")
	assert_true(bool(t.mine))
	assert_eq(int(t.men), a.men())
	assert_eq(t.text, ArmyView.token_text(a.men()))
	assert_true((t.armies as PackedInt32Array).has(a.id))
	assert_eq(t.figure, Military.unit_def(_g, 0).figure)
	assert_false(bool(t.mustering), "raised a turn ago: not mustering")


func test_unseen_foreign_army_is_absent() -> void:
	var hex := _unseen_land()
	assert_ne(hex, ArmyFixture.NO_HEX, "the 1480 map has a land hex Genoa does not see")
	ArmyFixture.army(_g, SAV, hex, 0, 2)
	assert_true(_token_at(ArmyView.tokens(_g, ArmyFixture.TAG), hex, SAV).is_empty(),
		"P: an unseen foreign army is absent from the tokens")


func test_seen_foreign_army_has_exact_men_and_no_ids() -> void:
	var hex := _gen_hex()
	var a := ArmyFixture.army(_g, SAV, hex, 0, 2)
	var t := _token_at(ArmyView.tokens(_g, ArmyFixture.TAG), hex, SAV)
	assert_false(t.is_empty(), "a foreign army in sight has a token")
	assert_eq(int(t.men), a.men(), "D7: men exact, never banded")
	assert_eq(t.text, ArmyView.token_text(a.men()))
	assert_true((t.armies as PackedInt32Array).is_empty(), "no army ids for another country")
	assert_false(bool(t.marching or t.mustering or t.waiting or t.hungry), "no order is shown")


func test_viewer_empty_sees_every_army_exact() -> void:
	var hex := _unseen_land()
	var a := ArmyFixture.army(_g, SAV, hex, 0, 2)
	var t := _token_at(ArmyView.tokens(_g, &""), hex, SAV)
	assert_false(t.is_empty())
	assert_eq(int(t.men), a.men())


func test_panel_of_an_unseen_army_is_empty_and_own_panel_is_full() -> void:
	var far := ArmyFixture.army(_g, SAV, _unseen_land(), 0, 1)
	assert_true(ArmyView.panel(_g, ArmyFixture.TAG, far.id).is_empty())
	var mine := ArmyFixture.army(_g, ArmyFixture.TAG, _gen_hex(), 0, 2)
	var p := ArmyView.panel(_g, ArmyFixture.TAG, mine.id)
	assert_true(bool(p.mine))
	assert_eq(int(p.men), mine.men())
	assert_eq((p.units as Array).size(), mine.units.size(), "one row a company")
	assert_eq(int(p.supply.state), Supply.FED, "a new army is fed from the stores")


func test_order_text_for_a_holding_mustering_and_marching_army() -> void:
	var hex := _gen_hex()
	var holding := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 1)
	assert_eq(ArmyView.panel(_g, ArmyFixture.TAG, holding.id).order.text, "Holding")
	var fresh := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 1, _g.turn)
	assert_eq(ArmyView.panel(_g, ArmyFixture.TAG, fresh.id).order.text, "Musters this season")
	var neighbour := _neighbour_of_gen(hex)
	assert_ne(neighbour, ArmyFixture.NO_HEX)
	var walker := ArmyFixture.army(_g, ArmyFixture.TAG, neighbour, 0, 1)
	# moves in the month: Movement.march walks at once and this march arrives in the act (the panel reads "Holding"), so the
	# marching state is a standing march made through the fixture
	assert_true(MovesFixture.standing(_g, walker, hex))
	var text := str(ArmyView.panel(_g, ArmyFixture.TAG, walker.id).order.text)
	assert_true(text.begins_with("Marching"), "marching text, got %s" % text)


func test_needing_orders_lists_none_first_then_id_order() -> void:
	var hex := _gen_hex()
	var neighbour := _neighbour_of_gen(hex)
	var walker := ArmyFixture.army(_g, ArmyFixture.TAG, neighbour, 0, 1)
	var idle := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 1)
	Movement.march(_g, {"army": walker.id, "goal": hex, "tag": ArmyFixture.TAG})
	assert_eq(ArmyView.needing_orders(_g, ArmyFixture.TAG), PackedInt32Array([idle.id, walker.id]))


func test_hex_text_names_own_and_seen_foreign_armies() -> void:
	var hex := _gen_hex()
	var mine := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 2)
	var text := ArmyView.hex_text(_g, ArmyFixture.TAG, hex)
	assert_true(text.begins_with(mine.name + ": "), "own army named: %s" % text)
	assert_true(text.ends_with("holding"))
	assert_eq(ArmyView.hex_text(_g, ArmyFixture.TAG, _unseen_land()), "", "nothing on an empty unseen hex")


func test_foreign_armies_of_one_country_are_one_summed_figure() -> void:
	var hex := _gen_hex()
	var known := ""
	for c: Country in _g.countries:
		if c.tag != ArmyFixture.TAG and Knowledge.knows(_g, ArmyFixture.TAG, c.tag):
			known = String(c.tag)
			break
	assert_ne(known, "", "a country Genoa knows")
	var a1 := ArmyFixture.army(_g, StringName(known), hex, 0, 1)
	var a2 := ArmyFixture.army(_g, StringName(known), hex, 0, 2)
	var text := ArmyView.hex_text(_g, ArmyFixture.TAG, hex)
	assert_eq(text.count(":"), 1, "P: one figure for the country, not one per army: %s" % text)
	assert_true(text.ends_with(Words.men(a1.men() + a2.men())),
		"the summed men, exact once: %s" % text)


## R23 (P): an army on a hex the country has discovered but does not see is not shown: discovery is not sight.
func test_discovered_but_unseen_foreign_army_is_absent() -> void:
	FogFixture.thin(_g, ArmyFixture.TAG, 3)
	var hex := ArmyFixture.NO_HEX
	for i: int in _g.map.hex_count():
		var h := _g.map.hex_of(i)
		if _g.map.land[i] == 1 and Knowledge.discovered(_g, ArmyFixture.TAG, h) and not Knowledge.sees(_g, ArmyFixture.TAG, h):
			hex = h
			break
	assert_ne(hex, ArmyFixture.NO_HEX, "a land hex Genoa has discovered but does not see")
	var a := ArmyFixture.army(_g, SAV, hex, 0, 2)
	assert_false(ArmyView.visible(_g, ArmyFixture.TAG, a), "P: an army out of sight is not visible")
	assert_true(_token_at(ArmyView.tokens(_g, ArmyFixture.TAG), hex, SAV).is_empty(), "P: no token out of sight")
	assert_true(ArmyView.panel(_g, ArmyFixture.TAG, a.id).is_empty(), "P: no panel out of sight")
	assert_eq(ArmyView.hex_text(_g, ArmyFixture.TAG, hex), "", "P: no Armies line out of sight")


## A land hex next to `hex` that Genoa holds, or NO_HEX.
func _neighbour_of_gen(hex: Vector2i) -> Vector2i:
	var mine := ArmyFixture.id_of(_g, ArmyFixture.TAG)
	for d: int in 6:
		var beside := ImproveRules.neighbour(hex, d)
		if _g.map.is_land(beside) and Territory.owner_id(_g, beside) == mine:
			return beside
	return ArmyFixture.NO_HEX


## A token list is not kept past a change of sight that moves no version (a phase of a season, a computer's turn, an army that stops
## watching): a foreign army that has left the viewer's sight leaves the list at once (fog R23; the fog monkey, seed 1504).
func test_a_foreign_army_leaves_the_tokens_when_the_sight_moves_with_the_version_unchanged() -> void:
	var out := _unseen_land()
	assert_ne(out, ArmyFixture.NO_HEX)
	var watcher := ArmyFixture.army(_g, ArmyFixture.TAG, out, 0, 1)
	Sight.refresh(_g)
	var beside := ArmyFixture.NO_HEX
	for d: int in 6:
		var h := ImproveRules.neighbour(out, d)
		if _g.map.is_land(h):
			beside = h
			break
	assert_ne(beside, ArmyFixture.NO_HEX)
	ArmyFixture.army(_g, SAV, beside, 0, 2)
	_g.version += 1
	assert_true(Knowledge.sees(_g, ArmyFixture.TAG, beside), "the watching army sees the hex beside it")
	assert_false(_token_at(ArmyView.tokens(_g, ArmyFixture.TAG), beside, SAV).is_empty(), "in sight: listed")
	Armies.remove(_g, watcher)
	Sight.refresh(_g)  # the army part moves; the version does not
	assert_false(Knowledge.sees(_g, ArmyFixture.TAG, beside), "the watcher is gone: the hex is out of sight")
	assert_true(_token_at(ArmyView.tokens(_g, ArmyFixture.TAG), beside, SAV).is_empty(), "out of sight: no token, though the version stands")


## Moves in the month (R51): an own token carries the lowest points left and the lowest full of its armies; a foreign token
## carries none (planted: points on a foreign token).
func test_an_own_token_carries_the_lowest_points_of_its_armies() -> void:
	var hex := _gen_hex()
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 1)
	var b := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 1)
	ArmyFixture.spent(_g, a, 8)
	ArmyFixture.spent(_g, b, 3)
	var t := _token_at(ArmyView.tokens(_g, ArmyFixture.TAG), hex, ArmyFixture.TAG)
	assert_eq(int(t.points_left), 3, "the lowest left of the two armies")
	assert_eq(int(t.points_full), mini(Allowance.full(_g, a), Allowance.full(_g, b)), "the lowest full")
	ArmyFixture.spent(_g, b, 0)
	_g.version += 1
	var spent := _token_at(ArmyView.tokens(_g, ArmyFixture.TAG), hex, ArmyFixture.TAG)
	assert_eq(int(spent.points_left), 0, "an army with no points left shows 0, not 'none'")
	assert_gt(int(spent.points_full), 0)


func test_a_foreign_token_and_panel_carry_no_points() -> void:
	var hex := _gen_hex()
	var foreign := ArmyFixture.army(_g, SAV, hex, 0, 2)
	ArmyFixture.spent(_g, foreign, 2)
	var t := _token_at(ArmyView.tokens(_g, ArmyFixture.TAG), hex, SAV)
	assert_false(t.is_empty())
	assert_lt(int(t.points_left), 0, "P: points on a foreign token")
	assert_lt(int(t.points_full), 0, "P: points on a foreign token")
	assert_false(ArmyView.panel(_g, ArmyFixture.TAG, foreign.id).has("points"), "P: points on a foreign panel")


func test_the_panel_gives_the_points_and_their_words() -> void:
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, _gen_hex(), 0, 1)
	var full := Allowance.full(_g, a)
	var p := ArmyView.panel(_g, ArmyFixture.TAG, a.id)
	assert_eq(int(p.points.left), full)
	assert_eq(int(p.points.full), full)
	assert_eq(str(p.points.text), "%d of %d left this season" % [full, full])
	ArmyFixture.spent(_g, a, 4)
	var q := ArmyView.panel(_g, ArmyFixture.TAG, a.id)
	assert_eq(str(q.points.text), "4 of %d left this season" % full)
