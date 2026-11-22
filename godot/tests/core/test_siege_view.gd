## SiegeView (docs/architecture/m7-build-spec.md 4.5, 4.15, 5.6, M7 B14): the siege of a fortress as a viewer may see it. Genoa
## (GEN, the player) holds its fortresses; a neighbour at war with it besieges one. Planted faults (P): a siege between countries
## at peace is none; an unseen foreign siege never appears; the defender's relief is shown only to the defender (or the viewer
## ""), never to the besieger; a witness that sees the hex gets no forecast, no rate and no army ids.
extends GutTest

var _g: Game


func before_each() -> void:
	_g = ArmyFixture.game()


## A fortress of any level that Genoa holds; NO_HEX when none.
func _own_fortress() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if Occupation.fortress_level(_g, hex) > 0 and Occupation.controller_tag(_g, hex) == ArmyFixture.TAG:
			return hex
	return ArmyFixture.NO_HEX


## A land neighbour of hex that `tag` controls; NO_HEX when none.
func _land_beside(hex: Vector2i, tag: StringName) -> Vector2i:
	var owner := ArmyFixture.id_of(_g, tag)
	for d: int in 6:
		var beside := ImproveRules.neighbour(hex, d)
		if _g.map.is_land(beside) and Territory.owner_id(_g, beside) == owner:
			return beside
	return ArmyFixture.NO_HEX


## A siege of hex by tag, made as the sieges phase would leave it (progress and seasons given).
func _siege(hex: Vector2i, by: StringName, progress: int, seasons: int) -> Siege:
	var s := Siege.new()
	s.hex = hex
	s.besieger = by
	s.progress = progress
	s.seasons = seasons
	s.name = "Siege of Test, 1480"
	s.started_turn = _g.turn
	_g.sieges.append(s)
	return s


func _has_key(value: Variant, name: String) -> bool:
	if value is Dictionary:
		for k: Variant in value:
			if str(k) == name or _has_key((value as Dictionary)[k], name):
				return true
	elif value is Array:
		for item: Variant in value:
			if _has_key(item, name):
				return true
	return false


func test_defender_sees_the_meter_forecast_and_relief() -> void:
	var f := _own_fortress()
	assert_ne(f, ArmyFixture.NO_HEX, "Genoa holds a fortress on the 1480 map")
	var enemy := WarFixture.neighbour_of(_g, ArmyFixture.TAG)
	assert_ne(enemy, &"", "Genoa has a neighbour to fight")
	WarFixture.at_war(_g, enemy, ArmyFixture.TAG)
	_siege(f, enemy, 2, 1)
	ArmyFixture.army(_g, enemy, f, 0, 3)
	var own := ArmyFixture.army(_g, ArmyFixture.TAG, _land_beside(f, ArmyFixture.TAG), 0, 2)
	var v := SiegeView.at(_g, ArmyFixture.TAG, f)
	assert_eq(v.access, &"exact")
	assert_eq(int(v.progress), 2)
	assert_eq(int(v.need), Occupation.siege_need(_g, f))
	assert_eq(int(v.seasons), 1)
	var lvl := Occupation.fortress_level(_g, f)
	assert_eq(int(v.stores_left), maxi(0, 1 + lvl - 1), "the stores left after one season")
	assert_eq(bool(v.starving), false)
	assert_eq(int(v.hunger), 0)
	assert_true(int(v.falls_in) >= -1, "the forecast season is read for the defender")
	assert_eq((v.relief as Array).size(), 1, "the army beside the fortress can relieve it")
	assert_ne(str(v.besieger_name), "a country", "the defender reads the besieger's name")
	assert_eq(int(v.relief[0].army), own.id)
	assert_eq(int(v.relief[0].seasons), 1)


func test_besieger_gets_no_relief_and_no_army_ids() -> void:
	var f := _own_fortress()
	var enemy := WarFixture.neighbour_of(_g, ArmyFixture.TAG)
	WarFixture.at_war(_g, enemy, ArmyFixture.TAG)
	_siege(f, enemy, 2, 1)
	ArmyFixture.army(_g, enemy, f, 0, 3)
	ArmyFixture.army(_g, ArmyFixture.TAG, _land_beside(f, ArmyFixture.TAG), 0, 2)
	var v := SiegeView.at(_g, enemy, f)
	assert_eq(v.access, &"exact", "the besieger sees its own siege exact")
	assert_eq((v.relief as Array).size(), 0, "P: the defender's relief is not the besieger's to know")
	assert_false(_has_key(v, "army"), "P: no army ids leak to the besieger")


func test_siege_between_countries_at_peace_is_none() -> void:
	var f := _own_fortress()
	var enemy := WarFixture.neighbour_of(_g, ArmyFixture.TAG)
	_siege(f, enemy, 2, 1)
	assert_true(SiegeView.at(_g, ArmyFixture.TAG, f).is_empty(), "P: no war, no siege shown")
	assert_true(SiegeView.at(_g, &"", f).is_empty(), "P: for every viewer")
	assert_true(SiegeView.all(_g, ArmyFixture.TAG).is_empty())


func test_unseen_foreign_siege_never_appears() -> void:
	var found := ArmyFixture.NO_HEX
	var besieger := &""
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		var holder := Occupation.controller_tag(_g, hex)
		if Occupation.fortress_level(_g, hex) == 0 or holder == &"" or holder == ArmyFixture.TAG:
			continue
		if Knowledge.sees(_g, ArmyFixture.TAG, hex):
			continue
		var e := WarFixture.neighbour_of(_g, holder)
		if e == &"" or e == ArmyFixture.TAG:
			continue
		found = hex
		besieger = e
		break
	assert_ne(found, ArmyFixture.NO_HEX, "the 1480 map has a foreign fortress Genoa does not see")
	WarFixture.at_war(_g, besieger, Occupation.controller_tag(_g, found))
	_siege(found, besieger, 3, 1)
	assert_true(SiegeView.at(_g, ArmyFixture.TAG, found).is_empty(), "P: an unseen siege is absent")
	for dial: Dictionary in SiegeView.all(_g, ArmyFixture.TAG):
		assert_ne(dial.hex, found, "P: and it is no dial")
	assert_false(SiegeView.at(_g, besieger, found).is_empty(), "the besieger sees it")


func test_witness_of_the_hex_sees_banded_men_and_no_forecast() -> void:
	var found := ArmyFixture.NO_HEX
	var besieger := &""
	var holder_tag := &""
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		var holder := Occupation.controller_tag(_g, hex)
		if Occupation.fortress_level(_g, hex) == 0 or holder == &"" or holder == ArmyFixture.TAG:
			continue
		var e := WarFixture.neighbour_of(_g, holder)
		if e == &"" or e == ArmyFixture.TAG:
			continue
		var beside := _land_beside(hex, ArmyFixture.TAG)
		if beside == ArmyFixture.NO_HEX:
			continue
		found = hex
		besieger = e
		holder_tag = holder
		break
	assert_ne(found, ArmyFixture.NO_HEX, "a foreign fortress beside Genoa's land")
	WarFixture.at_war(_g, besieger, holder_tag)
	_siege(found, besieger, 3, 1)
	ArmyFixture.army(_g, ArmyFixture.TAG, _land_beside(found, ArmyFixture.TAG), 0, 1)
	ArmyFixture.army(_g, besieger, found, 0, 3)
	assert_true(Knowledge.sees(_g, ArmyFixture.TAG, found), "Genoa sees the hex with its army beside it")
	var v := SiegeView.at(_g, ArmyFixture.TAG, found)
	assert_eq(v.access, &"seen")
	assert_eq(int(v.rate), -1, "P: no rate for a witness")
	assert_eq(int(v.falls_in), -1, "P: no forecast for a witness")
	assert_eq((v.relief as Array).size(), 0)
	assert_false(_has_key(v, "army"), "P: no army ids for a witness")
	assert_true(str(v.garrison_text).begins_with("garrison about"), "the garrison banded: %s" % v.garrison_text)
	assert_true(str(v.men_text).begins_with("about"), "the besieger's men banded")
	if not Knowledge.knows(_g, ArmyFixture.TAG, besieger):
		assert_eq(str(v.besieger_name), "a country", "P: a besieger the witness does not know is a country")
	assert_ne(str(SiegeView.at(_g, besieger, found).besieger_name), "a country", "the besieger reads its own name")
	assert_eq(int(v.progress), 3, "the meter is exact")


func test_dials_and_tones_for_each_side() -> void:
	var f := _own_fortress()
	var enemy := WarFixture.neighbour_of(_g, ArmyFixture.TAG)
	WarFixture.at_war(_g, enemy, ArmyFixture.TAG)
	_siege(f, enemy, 4, 2)
	var defender_dial := _dial(SiegeView.all(_g, ArmyFixture.TAG), f)
	var besieger_dial := _dial(SiegeView.all(_g, enemy), f)
	assert_eq(defender_dial.tone, &"bad")
	assert_eq(besieger_dial.tone, &"good")
	assert_eq(int(besieger_dial.progress), 4)


func test_stores_out_means_starving_and_hunger() -> void:
	var f := _own_fortress()
	var enemy := WarFixture.neighbour_of(_g, ArmyFixture.TAG)
	WarFixture.at_war(_g, enemy, ArmyFixture.TAG)
	var lvl := Occupation.fortress_level(_g, f)
	_siege(f, enemy, 1, 2 + lvl)
	var v := SiegeView.at(_g, ArmyFixture.TAG, f)
	assert_true(bool(v.starving))
	assert_eq(int(v.stores_left), 0)
	assert_eq(int(v.hunger), _g.defs.war.siege_hunger)


func _dial(dials: Array[Dictionary], hex: Vector2i) -> Dictionary:
	for d: Dictionary in dials:
		if d.hex == hex:
			return d
	return {}
