## OddsView (docs/architecture/m7-build-spec.md 4.6, 4.7, 4.15, 5.6, 6.4; M7 B23): the odds card of a march. Genoa (GEN, the
## player) at war with a neighbour. Planted faults (P): a hex the player does not see gives the same card as an empty unseen
## hex (kind none, no numbers, no words, no army, no garrison, no siege); an unseen enemy army gives no number and no word; a
## seen garrison is rounded, never exact; a shaken army's refusal gives the two sentences of 6.4. The viewer "" gets {}.
@warning_ignore_start("integer_division")
extends GutTest

var _g: Game
var _war: WarDef


func before_each() -> void:
	_g = ArmyFixture.game()
	_war = _g.defs.war


## A land hex of Genoa beside an enemy's land (the enemy at war with Genoa): {ours, theirs, enemy}; {} when none.
func _contact() -> Dictionary:
	var enemy := WarFixture.neighbour_of(_g, ArmyFixture.TAG)
	WarFixture.at_war(_g, enemy, ArmyFixture.TAG)
	var eid := ArmyFixture.id_of(_g, enemy)
	var mine := ArmyFixture.id_of(_g, ArmyFixture.TAG)
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if not _g.map.is_land(hex) or Territory.owner_id(_g, hex) != mine:
			continue
		for d: int in 6:
			var beside := ImproveRules.neighbour(hex, d)
			if _g.map.is_land(beside) and Territory.owner_id(_g, beside) == eid:
				return {"ours": hex, "theirs": beside, "enemy": enemy}
	return {}


## Makes a hex the player sees: an army of Genoa on a land hex of its own beside it (its sight), or on the hex itself.
func _watch(hex: Vector2i) -> Army:
	var mine := ArmyFixture.id_of(_g, ArmyFixture.TAG)
	var at := hex
	for d: int in 6:
		var beside := ImproveRules.neighbour(hex, d)
		if _g.map.is_land(beside) and Territory.owner_id(_g, beside) == mine:
			at = beside
			break
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, at, 0, 2)
	Sight.refresh(_g)
	return a


## The first hex of an enemy at war with Genoa that Genoa does not see and holds no army on; NO_HEX when none.
func _unseen_enemy_hex(enemy: StringName) -> Vector2i:
	var eid := ArmyFixture.id_of(_g, enemy)
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if _g.map.is_land(hex) and int(_g.state.owner[i]) == eid and not Knowledge.sees(_g, ArmyFixture.TAG, hex) \
				and Armies.at(_g, hex).is_empty():
			return hex
	return ArmyFixture.NO_HEX


## A hostile garrisoned fortress (held by a country at war with Genoa): {hex, holder, army (Genoa's watch, when watched)}.
## Watched: the fortress is seen. Unseen: not seen, no army of Genoa made. {} when none.
func _hostile_fortress(watched: bool) -> Dictionary:
	var enemy := WarFixture.neighbour_of(_g, ArmyFixture.TAG)
	WarFixture.at_war(_g, enemy, ArmyFixture.TAG)
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if Occupation.fortress_level(_g, hex) > 0 and Occupation.garrison_of(_g, hex) > 0 \
				and Occupation.controller_tag(_g, hex) == enemy:
			if watched:
				var a := _watch(hex)
				if Knowledge.sees(_g, ArmyFixture.TAG, hex):
					return {"hex": hex, "holder": enemy, "army": a}
			elif not Knowledge.sees(_g, ArmyFixture.TAG, hex):
				return {"hex": hex, "holder": enemy}
	return {}


## True when a value (a dictionary or list, recursively) holds the integer n.
func _holds(value: Variant, n: int) -> bool:
	if value is int:
		return value == n
	if value is Dictionary:
		for k: Variant in value:
			if _holds((value as Dictionary)[k], n):
				return true
	elif value is Array:
		for item: Variant in value:
			if _holds(item, n):
				return true
	return false


func test_attack_ratio_and_word_are_combats_odds() -> void:
	var c := _contact()
	assert_false(c.is_empty(), "Genoa borders an enemy on the 1480 map")
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, c.ours, 0, 2)
	ArmyFixture.army(_g, c.enemy, c.theirs, 0, 1)
	var v := OddsView.of(_g, ArmyFixture.TAG, a.id, c.theirs)
	assert_eq(v.kind, &"attack")
	assert_eq(v.defence.access, &"seen", "a neighbour's army the player sees is seen, not exact")
	assert_eq(int(v.ratio_permille), Combat.odds_ratio(int(v.attack.strength), int(v.defence.strength)))
	var value := int(v.ratio_permille) * 1000 / maxi(int(v.factor_permille), 1)
	assert_eq(str(v.word), Combat.odds_word(_war, value), "the word is Combat's word over the ground factor")
	assert_eq(str(v.word), OddsView.word(_g, value))
	assert_true(str(v.kind_text).begins_with("Attack · "), "the title reads Attack · the word")


func test_planted_unseen_enemy_army_gives_no_number_and_no_word() -> void:
	var c := _contact()
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, c.ours, 0, 2)
	var hex := _unseen_enemy_hex(c.enemy)
	assert_ne(hex, ArmyFixture.NO_HEX, "an enemy hex Genoa does not see exists")
	var e := ArmyFixture.army(_g, c.enemy, hex, 0, 3)
	var v := OddsView.of(_g, ArmyFixture.TAG, a.id, hex)
	assert_eq(v.kind, &"none", "P: an unseen hex has no card at all")
	assert_eq(v.defence.access, &"hidden")
	assert_eq(int(v.defence.men), 0, "P: no enemy men leak")
	assert_eq(int(v.defence.morale), 0)
	assert_eq(int(v.defence.strength), 0)
	assert_eq(int(v.ratio_permille), -1)
	assert_eq(str(v.word), "", "P: a hidden defender gives no word")
	assert_false(_holds(v, e.men()), "P: the enemy's exact men appear nowhere in the card")


func test_planted_unseen_enemy_hex_card_equals_an_empty_unseen_hex() -> void:
	var c := _contact()
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, c.ours, 0, 2)
	var hex := _unseen_enemy_hex(c.enemy)
	assert_ne(hex, ArmyFixture.NO_HEX)
	ArmyFixture.army(_g, c.enemy, hex, 0, 3)
	var empty := ArmyFixture.NO_HEX
	for i: int in _g.map.hex_count():
		var h := _g.map.hex_of(i)
		if _g.map.is_land(h) and not Knowledge.sees(_g, ArmyFixture.TAG, h) and Armies.at(_g, h).is_empty() and h != hex:
			empty = h
			break
	assert_ne(empty, ArmyFixture.NO_HEX, "an empty unseen hex exists")
	var seen_army := OddsView.of(_g, ArmyFixture.TAG, a.id, hex)
	var seen_empty := OddsView.of(_g, ArmyFixture.TAG, a.id, empty)
	seen_army.erase("title")
	seen_empty.erase("title")
	assert_eq(seen_army, seen_empty, "P: the card of a fogged army hex is the card of an empty fogged hex")


func test_planted_unseen_fortress_leaks_neither_garrison_nor_need() -> void:
	var f := _hostile_fortress(false)
	assert_false(f.is_empty(), "a hostile garrisoned fortress the player does not see exists")
	var garrison := Occupation.garrison_of(_g, f.hex)
	var need := Occupation.siege_need(_g, f.hex)
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, ArmyFixture.find_town(_g), 0, 2)
	for storm: bool in [false, true]:
		var v := OddsView.of(_g, ArmyFixture.TAG, a.id, f.hex, storm)
		assert_eq(v.kind, &"none", "P: no siege or storm card for a fogged fortress")
		assert_eq(int((v.besiege as Dictionary).seasons), -1)
		assert_eq(int((v.besiege as Dictionary).need), 0, "P: the need is not the viewer's to know")
		if garrison > 9:
			assert_false(_holds(v, garrison), "P: the real garrison appears nowhere")
		if need > 9:
			assert_false(_holds(v, need), "P: the real need appears nowhere")
		assert_eq((v.notes as Array).size(), 0, "P: no fortress note for a fogged fortress")


func test_planted_garrison_seen_only_rounded_never_exact() -> void:
	var f := _hostile_fortress(true)
	assert_false(f.is_empty(), "a hostile garrisoned fortress the player sees exists")
	var target := Occupation.garrison_full(_g, f.hex) - 13
	Occupation.set_garrison(_g, f.hex, target)
	var whole := Occupation.garrison_of(_g, f.hex)
	assert_ne(whole % 100, 0, "the planted garrison is not a round hundred")
	var v := OddsView.of(_g, ArmyFixture.TAG, f.army.id, f.hex, true)
	assert_eq(v.kind, &"storm")
	assert_eq(v.defence.access, &"seen", "the seen garrison makes the defence seen")
	assert_ne(int(v.defence.garrison.men), whole, "P: a seen garrison is rounded, never exact")
	assert_false(_holds(v, whole), "P: the exact garrison appears nowhere in the card")


func test_storm_card_of_a_seen_garrisoned_fortress() -> void:
	var f := _hostile_fortress(true)
	var v := OddsView.of(_g, ArmyFixture.TAG, f.army.id, f.hex, true)
	assert_eq(v.kind, &"storm")
	assert_true(str(v.kind_text).begins_with("Storm · "), str(v.kind_text))
	assert_ne(str(v.word), "", "a seen garrison gives the storm's word")
	var notes := v.notes as Array
	assert_true(notes.has("Garrison starves after %d seasons" % (1 + Occupation.fortress_level(_g, f.hex))), "the stores")
	assert_true(notes.has("Taking it opens %d districts" % int(v.opens)), "the districts a taking opens")
	assert_eq(int(v.defence.garrison.cut), 0, "no siege of Genoa, so no storm cut")


func test_siege_forecast_is_sieges_forecast() -> void:
	var f := _hostile_fortress(true)
	var a: Army = f.army
	var v := OddsView.of(_g, ArmyFixture.TAG, a.id, f.hex)
	assert_eq(v.kind, &"siege", "a fortress with men and no army on it is a siege")
	var guns := 0
	for u: Unit in a.units:
		var def := Military.unit_def(_g, u.kind)
		guns += def.siege_points if def != null else 0
	var seasons := Sieges.forecast(_g, f.hex, ArmyFixture.TAG, a.men(), guns, 0, 0)
	assert_eq(int((v.besiege as Dictionary).seasons), seasons)
	if seasons >= 0:
		assert_eq(str(v.word), "falls in about %s" % ("%d season%s" % [seasons, "" if seasons == 1 else "s"]))
	else:
		assert_eq(str(v.word), "too few men to take it")


func test_shaken_army_is_refused_in_the_two_sentences() -> void:
	var c := _contact()
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, c.ours, 0, 2)
	ArmyFixture.army(_g, c.enemy, c.theirs, 0, 1)
	for u: Unit in a.units:
		Armies.set_morale(_g, a, u.id, 300)
	var v := OddsView.of(_g, ArmyFixture.TAG, a.id, c.theirs)
	assert_false(bool(v.ok))
	assert_eq(str(v.reason), "Too shaken to attack: morale 30 %, 50 % needed. It recovers 25 a season when fed.")
	assert_eq(str(v.tone), "bad")


func test_held_land_moves_in_but_cannot_take_it() -> void:
	var hex := ArmyFixture.NO_HEX
	var holder := &""
	for i: int in _g.map.hex_count():
		var h := _g.map.hex_of(i)
		if _g.map.is_land(h) and AreaLines.held_by(_g, h)["state"] == &"held" and not Occupation.is_occupied(_g, h):
			var owner := Territory.owner_tag(_g, h)
			if owner != ArmyFixture.TAG and owner != &"":
				hex = h
				holder = owner
				break
	assert_ne(hex, ArmyFixture.NO_HEX, "a held area of another country exists on the 1480 map")
	WarFixture.at_war(_g, holder, ArmyFixture.TAG)
	var a := _watch(hex)
	var v := OddsView.of(_g, ArmyFixture.TAG, a.id, hex)
	assert_eq(v.kind, &"held")
	assert_true(str((v.notes as Array)[0]).begins_with("Moves in, but cannot take it: held by the castle of "))
	assert_true(str(v.hint).begins_with("Besiege it: "))


func test_open_enemy_land_is_a_walk_in_and_own_land_is_none() -> void:
	var enemy := WarFixture.neighbour_of(_g, ArmyFixture.TAG)
	WarFixture.at_war(_g, enemy, ArmyFixture.TAG)
	var hex := ArmyFixture.NO_HEX
	var eid := ArmyFixture.id_of(_g, enemy)
	for i: int in _g.map.hex_count():
		var h := _g.map.hex_of(i)
		if _g.map.is_land(h) and int(_g.state.owner[i]) == eid and Occupation.fortress_level(_g, h) == 0 \
				and AreaLines.held_by(_g, h)["state"] != &"held":
			hex = h
			break
	assert_ne(hex, ArmyFixture.NO_HEX, "open enemy land exists")
	var a := _watch(hex)
	var v := OddsView.of(_g, ArmyFixture.TAG, a.id, hex)
	assert_eq(v.kind, &"walk_in")
	assert_eq((v.notes as Array)[0], "Takes it at the end of the season.")
	var own := _watch(ArmyFixture.find_town(_g))
	assert_eq(OddsView.of(_g, ArmyFixture.TAG, own.id, ArmyFixture.find_town(_g)).kind, &"none", "own land is no war target")


func test_storm_of_a_plain_hex_is_refused_for_no_walls() -> void:
	var c := _contact()
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, c.ours, 0, 2)
	var v := OddsView.of(_g, ArmyFixture.TAG, a.id, c.theirs, true)
	assert_eq(v.kind, &"none")
	assert_false(bool(v.ok))
	assert_true(str(v.reason).begins_with("No walls to storm at"), str(v.reason))


func test_viewer_empty_and_other_countries_army_give_nothing() -> void:
	var c := _contact()
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, c.ours, 0, 2)
	assert_true(OddsView.of(_g, &"", a.id, c.theirs).is_empty(), "the viewer \"\" gets no odds card, as reach")
	var foreign := ArmyFixture.army(_g, c.enemy, c.theirs, 0, 1)
	var v := OddsView.of(_g, ArmyFixture.TAG, foreign.id, c.ours)
	assert_eq(v.kind, &"none", "another country's army has no card for the player")
	assert_false(bool(v.ok))


## The crossing chips of day 1 (4.6, Battles' flags): a pass edge and a river edge with no crossing tile each cost the attacker.
func test_crossing_chips_read_the_edge_between_stand_and_hex() -> void:
	var found_pass := false
	var found_river := false
	for i: int in _g.map.hex_count():
		var stand := _g.map.hex_of(i)
		if not _g.map.is_land(stand):
			continue
		for d: int in 6:
			var to := ImproveRules.neighbour(stand, d)
			if not _g.map.is_land(to):
				continue
			var e := _g.map.edge_index(stand, d)
			if e < 0 or e >= _g.map.pass_edge.size():
				continue
			if int(_g.map.pass_edge[e]) != 0 and not found_pass:
				found_pass = true
				var chips := OddsView._edge_chips(_g, stand, to, "MLO")
				assert_true(str(chips[0].text).begins_with("Across a pass "), str(chips[0].text))
				assert_true(str(chips[0].text).ends_with("on day 1"))
			var river := int(_g.map.river[e])
			if river >= 1 and river <= 3 and int(_g.map.crossing[e]) == 0 and not found_river:
				found_river = true
				assert_true(str(OddsView._edge_chips(_g, stand, to, "MLO")[-1].text).begins_with("Across the river "))
	assert_true(found_pass, "the 1480 map has a pass edge between land hexes")
	assert_true(found_river, "the 1480 map has a river edge with no crossing tile")


# --- M8 K13: the besiege card reads the garrison the viewer may take it to be (D49) ---------------------------------------------


func _besiege_of(f: Dictionary, a: Army) -> Dictionary:
	return OddsView.of(_g, ArmyFixture.TAG, a.id, f.hex).besiege as Dictionary


func test_unseen_fortress_card_uses_the_full_garrison_and_a_reduced_one_changes_nothing() -> void:
	var f := _hostile_fortress(false)
	assert_false(f.is_empty(), "a hostile garrisoned fortress the player does not see exists")
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, ArmyFixture.find_town(_g), 0, 2)
	var full := Occupation.garrison_full(_g, f.hex)
	var estimate := Knowledge.garrison_estimate(_g, ArmyFixture.TAG, f.hex)
	assert_eq(int(estimate.men), full, "the estimate of an unseen fortress is its full garrison")
	var before := OddsView.of(_g, ArmyFixture.TAG, a.id, f.hex)
	Occupation.set_garrison(_g, f.hex, maxi(1, full / 4))
	var after := OddsView.of(_g, ArmyFixture.TAG, a.id, f.hex)
	assert_eq(after, before, "P: a reduced unseen garrison does not change the card")
	# The card is none for a fogged fortress; the besiege numbers it would use (and the AI's) are the estimate's.
	Occupation.set_garrison(_g, f.hex, full)
	var strong := ArmyFixture.army(_g, ArmyFixture.TAG, ArmyFixture.find_town(_g), 0, 8)
	var numbers_full := OddsView._besiege(_g, ArmyFixture.TAG, strong, f.hex)
	Occupation.set_garrison(_g, f.hex, maxi(1, full / 4))
	var numbers_low := OddsView._besiege(_g, ArmyFixture.TAG, strong, f.hex)
	assert_eq(numbers_low, numbers_full, "P: the besiege numbers of an unseen fortress do not follow its real garrison")
	assert_eq(int(numbers_low.seasons), Sieges.forecast_for(_g, f.hex, full, strong.men(), OddsView._guns(_g, strong), 0, 0),
		"they are forecast_for the full garrison")


func test_the_besiege_numbers_of_a_seen_fortress_follow_its_rounded_garrison() -> void:
	var f := _hostile_fortress(true)
	assert_false(f.is_empty(), "a hostile fortress the player sees exists")
	var a: Army = f.army
	var seen := Knowledge.garrison_estimate(_g, ArmyFixture.TAG, f.hex)
	assert_eq(seen.access, &"seen")
	var guns := 0
	for u: Unit in a.units:
		var def := Military.unit_def(_g, u.kind)
		guns += def.siege_points if def != null else 0
	var want := Sieges.forecast_for(_g, f.hex, int(seen.men), a.men(), guns, 0, 0)
	assert_eq(int(_besiege_of(f, a).seasons), want, "the card's seasons are forecast_for the seen garrison")
	assert_eq(int(_besiege_of(f, a).seasons), Sieges.forecast(_g, f.hex, ArmyFixture.TAG, a.men(), guns, 0, 0),
		"a full garrison reads as before: the rounded one is the real one")
