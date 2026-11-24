## MovePreview (docs/architecture/m6-build-spec.md sections 4.4, 4.7, 4.13, 5.6 and 6.7, L11): the reach of an army (mustering:
## next only) and the words of a march to a hex for each kind of line: a refusal of a foreign land with its way out, a go or
## a note for a land hex next door, and the mustering line. North Italy, Genoa (GEN) the player.
extends GutTest

var _g: Game


func before_each() -> void:
	_g = ArmyFixture.game()


func _gen_hex() -> Vector2i:
	return ArmyFixture.find_town(_g)


func _neighbour_of_gen(hex: Vector2i) -> Vector2i:
	var mine := ArmyFixture.id_of(_g, ArmyFixture.TAG)
	for d: int in 6:
		var beside := ImproveRules.neighbour(hex, d)
		if _g.map.is_land(beside) and Territory.owner_id(_g, beside) == mine:
			return beside
	return ArmyFixture.NO_HEX


## A land hex of another country (not Genoa's, not unowned), or NO_HEX.
func _foreign_land() -> Vector2i:
	var mine := ArmyFixture.id_of(_g, ArmyFixture.TAG)
	for i: int in _g.map.hex_count():
		var owner := int(_g.state.owner[i])
		if _g.map.land[i] == 1 and owner > 0 and owner != mine:
			return _g.map.hex_of(i)
	return ArmyFixture.NO_HEX


func test_reach_of_a_walking_army_holds_its_own_hex_and_grows_next_season() -> void:
	var hex := _gen_hex()
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 1)
	var r := MovePreview.reach(_g, ArmyFixture.TAG, a.id)
	var own := _g.map.index_of(hex)
	assert_true((r.season as PackedInt32Array).has(own), "the army stands on its own hex at the season's end")
	assert_true((r.next as PackedInt32Array).size() >= (r.season as PackedInt32Array).size(),
		"the next season's reach holds the season's")


func test_reach_of_a_mustering_army_is_next_only() -> void:
	var hex := _gen_hex()
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 1, _g.turn)
	var r := MovePreview.reach(_g, ArmyFixture.TAG, a.id)
	assert_true((r.season as PackedInt32Array).is_empty(), "a mustering army has no reach this season")
	assert_false((r.next as PackedInt32Array).is_empty(), "but it has one for next season")


func test_reach_of_a_foreign_army_is_empty_for_the_player() -> void:
	var foreign := ArmyFixture.army(_g, ArmyFixture.other_tag(_g), _foreign_land(), 0, 1)
	var r := MovePreview.reach(_g, ArmyFixture.TAG, foreign.id)
	assert_true((r.season as PackedInt32Array).is_empty(), "P: another country's army has no reach for the player")
	assert_true((r.next as PackedInt32Array).is_empty())
	assert_true((MovePreview.reach(_g, &"", foreign.id).next as PackedInt32Array).is_empty(), "no viewer, no reach")


func test_refusal_of_an_undiscovered_owner_does_not_name_it() -> void:
	FogFixture.thin(_g, ArmyFixture.TAG, 1)
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, _gen_hex(), 0, 1)
	var goal := _undiscovered_land()
	assert_ne(goal, ArmyFixture.NO_HEX, "the thin map has a foreign land hex Genoa has not discovered")
	var p := MovePreview.to(_g, ArmyFixture.TAG, a.id, goal)
	var owner := Territory.owner_tag(_g, goal)
	assert_eq(p.lines[0][0], "not your land: another country holds it, and your armies cross no border in peace",
		"P: the owner is not named")
	assert_false(str(p.lines[0][0]).contains(str(owner)), "the owner's tag and name stay out of it")
	assert_false(str(p.verdict.reason).contains("the the"), "no doubled article")


func test_refusal_of_a_known_explored_owner_names_it_once() -> void:
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, _gen_hex(), 0, 1)
	var goal := _known_explored_land()
	assert_ne(goal, ArmyFixture.NO_HEX, "a foreign hex of a known country Genoa has explored")
	var owner := Territory.owner_tag(_g, goal)
	var p := MovePreview.to(_g, ArmyFixture.TAG, a.id, goal)
	var named := "%s holds it" % Words.country_the(_g, owner)
	assert_true(str(p.lines[0][0]).begins_with("not your land: " + named), "the owner is named by the word helper: %s" % str(p.lines[0][0]))
	assert_false(str(p.lines[0][0]).contains("the the"), "the article is not doubled")


## A land hex of another country that the player has not discovered (on the thin map), or NO_HEX.
func _undiscovered_land() -> Vector2i:
	for i: int in _g.map.hex_count():
		var owner := int(_g.state.owner[i])
		var hex := _g.map.hex_of(i)
		if _g.map.land[i] == 1 and owner > 0 and owner != ArmyFixture.id_of(_g, ArmyFixture.TAG) and not Knowledge.discovered(_g, ArmyFixture.TAG, hex):
			return hex
	return ArmyFixture.NO_HEX


## A land hex of a known foreign country that the player has explored, or NO_HEX.
func _known_explored_land() -> Vector2i:
	var mine := ArmyFixture.id_of(_g, ArmyFixture.TAG)
	for i: int in _g.map.hex_count():
		var owner := int(_g.state.owner[i])
		if _g.map.land[i] != 1 or owner <= 0 or owner == mine:
			continue
		var hex := _g.map.hex_of(i)
		if Knowledge.knows(_g, ArmyFixture.TAG, Countries.by_id(_g, owner).tag) and Sight.explored(_g, ArmyFixture.TAG, hex):
			return hex
	return ArmyFixture.NO_HEX


func test_refusal_of_a_foreign_land_gives_the_way_out() -> void:
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, _gen_hex(), 0, 1)
	var goal := _foreign_land()
	assert_ne(goal, ArmyFixture.NO_HEX)
	var p := MovePreview.to(_g, ArmyFixture.TAG, a.id, goal)
	assert_false(bool(p.verdict.ok))
	assert_eq(p.kind, &"refusal")
	assert_true(str(p.lines[0][0]).begins_with("not your land"), "the reason is the first line")
	assert_eq(p.lines[0][1], &"bad")
	assert_eq(p.way_out, "Go round their land.")
	assert_true((p.hexes as Array).is_empty(), "no route for a refusal")


func test_a_march_to_a_neighbour_arrives_with_stops_and_a_kind() -> void:
	var hex := _gen_hex()
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 1)
	var goal := _neighbour_of_gen(hex)
	var p := MovePreview.to(_g, ArmyFixture.TAG, a.id, goal)
	assert_true(bool(p.verdict.ok), "the march is allowed: %s" % str(p.verdict.reason))
	assert_true(p.kind == &"go" or p.kind == &"note", "a march is go or note")
	assert_eq((p.hexes as Array).back(), goal, "the goal is the last hex of the route")
	assert_true(int(p.arrives_turn) >= _g.turn)
	assert_true(int(p.seasons) >= 1)
	assert_eq((p.stops as Array).size(), int(p.seasons), "one stop per season walked")
	assert_true(str(p.arrives_text).begins_with("There in "))
	assert_eq(p.way_out, "")


func test_a_mustering_army_gets_the_musters_first_line_and_a_note() -> void:
	var hex := _gen_hex()
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 1, _g.turn)
	var goal := _neighbour_of_gen(hex)
	var p := MovePreview.to(_g, ArmyFixture.TAG, a.id, goal)
	assert_true(bool(p.verdict.ok))
	assert_eq(p.kind, &"note")
	var texts: Array = []
	for line: Array in p.lines:
		texts.append(str(line[0]))
	assert_true(texts.any(func(t: String) -> bool: return t.begins_with("Musters first")), "the musters line is there")


func test_supply_end_of_a_goal_in_supply_is_good() -> void:
	var hex := _gen_hex()
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 1)
	var goal := _neighbour_of_gen(hex)
	var p := MovePreview.to(_g, ArmyFixture.TAG, a.id, goal)
	var end := p.supply_end as Dictionary
	assert_eq(bool(end.in_supply), Supply.in_supply(_g, ArmyFixture.TAG, goal, Calendar.is_winter(int(p.arrives_turn))))
	if bool(end.in_supply):
		assert_eq(int(end.loss), 0)
	else:
		assert_true(str((p.lines as Array).back()[0]).begins_with("Out of supply"))


func test_preview_is_cached_and_equal_on_a_second_ask() -> void:
	var hex := _gen_hex()
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 1)
	var goal := _neighbour_of_gen(hex)
	var first := MovePreview.to(_g, ArmyFixture.TAG, a.id, goal)
	var second := MovePreview.to(_g, ArmyFixture.TAG, a.id, goal)
	assert_eq(first.hexes, second.hexes)
	assert_eq(first.kind, second.kind)


## M7 (6.4): a march onto an enemy's army is an attack; its hover card's first line names the attack and its odds, and the
## odds card (OddsView) rides along. Planted: a march onto own land has no war words.
func test_an_attack_march_gives_the_war_line_and_the_odds() -> void:
	var enemy := WarFixture.neighbour_of(_g, ArmyFixture.TAG)
	WarFixture.at_war(_g, enemy, ArmyFixture.TAG)
	var eid := ArmyFixture.id_of(_g, enemy)
	var mine := ArmyFixture.id_of(_g, ArmyFixture.TAG)
	var ours := ArmyFixture.NO_HEX
	var theirs := ArmyFixture.NO_HEX
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if not _g.map.is_land(hex) or Territory.owner_id(_g, hex) != mine:
			continue
		for d: int in 6:
			var beside := ImproveRules.neighbour(hex, d)
			if _g.map.is_land(beside) and Territory.owner_id(_g, beside) == eid:
				ours = hex
				theirs = beside
				break
		if theirs != ArmyFixture.NO_HEX:
			break
	assert_ne(theirs, ArmyFixture.NO_HEX, "Genoa borders the enemy")
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, ours, 0, 2)
	ArmyFixture.army(_g, enemy, theirs, 0, 1)
	var v := MovePreview.to(_g, ArmyFixture.TAG, a.id, theirs)
	assert_true(bool(v.verdict.ok), "the march to the enemy's hex is allowed: %s" % str(v.verdict.reason))
	assert_eq(v.war.kind, &"attack")
	assert_eq(v.odds.kind, &"attack")
	assert_true(str((v.lines as Array)[0][0]).begins_with("Attacks the "), str((v.lines as Array)[0][0]))
	var own := MovePreview.to(_g, ArmyFixture.TAG, a.id, ArmyFixture.find_town(_g))
	assert_false(str((own.get("war", {}) as Dictionary).get("kind", "")) == "attack", "P: own land is no attack")
	assert_true((own.get("odds", {}) as Dictionary).is_empty(), "P: a march onto own land has no odds card")


## True when a string anywhere in a value (dictionaries and lists, recursively) contains needle.
func _text_holds(value: Variant, needle: String) -> bool:
	if value is String:
		return (value as String).contains(needle)
	if value is Dictionary:
		for k: Variant in value:
			if _text_holds(k, needle) or _text_holds((value as Dictionary)[k], needle):
				return true
	elif value is Array:
		for item: Variant in value:
			if _text_holds(item, needle):
				return true
	return false


## M7 (4.15) fog: a refusal that names an unseen goal says the generic no-way words and names no enemy. The same words for an
## unseen empty sea goal; a seen refusal keeps its exact reason.
func test_planted_refusal_on_an_unseen_goal_names_nothing() -> void:
	var enemy := WarFixture.neighbour_of(_g, ArmyFixture.TAG)
	WarFixture.at_war(_g, enemy, ArmyFixture.TAG)
	var hex := ArmyFixture.NO_HEX
	for i: int in _g.map.hex_count():
		var h := _g.map.hex_of(i)
		if _g.map.is_land(h) and int(_g.state.owner[i]) == ArmyFixture.id_of(_g, enemy) 				and not Knowledge.sees(_g, ArmyFixture.TAG, h) and Armies.at(_g, h).is_empty():
			hex = h
			break
	assert_ne(hex, ArmyFixture.NO_HEX, "an unseen enemy land hex exists")
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, _gen_hex(), 0, 2)
	for u: Unit in a.units:
		Armies.set_morale(_g, a, u.id, 300)
	ArmyFixture.army(_g, enemy, hex, 0, 3)
	var v := MovePreview.to(_g, ArmyFixture.TAG, a.id, hex)
	assert_eq(v.kind, &"refusal")
	assert_eq(str(v.verdict.reason), "no way there by land", "P: an unseen goal's refusal names nothing")
	assert_false(_text_holds(v, String(enemy)), "P: no enemy tag in the card")
	assert_false(_text_holds(v, "shaken"), "P: the enemy's presence is not named")
	var sea := ArmyFixture.NO_HEX
	for i: int in _g.map.hex_count():
		var h := _g.map.hex_of(i)
		if not _g.map.is_land(h) and not Knowledge.sees(_g, ArmyFixture.TAG, h):
			sea = h
			break
	assert_ne(sea, ArmyFixture.NO_HEX, "an unseen sea hex exists")
	var empty := MovePreview.to(_g, ArmyFixture.TAG, a.id, sea)
	assert_eq(str(empty.verdict.reason), str(v.verdict.reason), "P: the same words as an empty unseen hex")


func test_a_seen_refusal_keeps_its_reason() -> void:
	var enemy := WarFixture.neighbour_of(_g, ArmyFixture.TAG)
	WarFixture.at_war(_g, enemy, ArmyFixture.TAG)
	var eid := ArmyFixture.id_of(_g, enemy)
	var mine := ArmyFixture.id_of(_g, ArmyFixture.TAG)
	var ours := ArmyFixture.NO_HEX
	var theirs := ArmyFixture.NO_HEX
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if not _g.map.is_land(hex) or Territory.owner_id(_g, hex) != mine:
			continue
		for d: int in 6:
			var beside := ImproveRules.neighbour(hex, d)
			if _g.map.is_land(beside) and Territory.owner_id(_g, beside) == eid:
				ours = hex
				theirs = beside
				break
		if theirs != ArmyFixture.NO_HEX:
			break
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, ours, 0, 2)
	ArmyFixture.army(_g, enemy, theirs, 0, 1)
	for u: Unit in a.units:
		Armies.set_morale(_g, a, u.id, 300)
	var v := MovePreview.to(_g, ArmyFixture.TAG, a.id, theirs)
	assert_eq(v.kind, &"refusal")
	assert_true(str(v.verdict.reason).begins_with("too shaken to attack"), str(v.verdict.reason))
