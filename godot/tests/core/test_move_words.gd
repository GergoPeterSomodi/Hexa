## MoveWords (docs/architecture/moves-build-spec.md R52, R57; MV5): the toast of an order's walk for each shape of the walk
## dictionary of spec section 4 (the walk itself comes with MV4, so each case builds the dictionary by hand), and the fog rule:
## an army out of sight, its country and its place are never named. North Italy, MovesFixture.duel(): Savoy (SAV) the player at war
## with Milan (MLO); Milan's army at (7, 4) is out of Savoy's sight.
extends GutTest

const FAR_GOAL := Vector2i(0, 3)

var _g: Game
var _a: Army


func before_each() -> void:
	_g = MovesFixture.duel()
	_a = MovesFixture.named(_g, MovesFixture.NAME_HOME)


func _words(walk: Dictionary, viewer: StringName = MovesFixture.SAVOY) -> Dictionary:
	return MoveWords.of(_g, viewer, _a.id, walk)


func _walk(stopped: StringName, to: Vector2i, steps: int = 2, extra: Dictionary = {}) -> Dictionary:
	var w := {"steps": steps, "from": _a.hex, "to": to, "stopped": stopped, "text": "", "points": 8, "full": 12,
		"standing": false, "battle": -1}
	w.merge(extra, true)
	return w


## {to, unseen}: a land hex Savoy sees beside a land hex it does not see (both empty of armies), or {} when the map has none.
func _beside_unseen() -> Dictionary:
	for i: int in _g.map.hex_count():
		var h := _g.map.hex_of(i)
		if not _g.map.is_land(h) or not Knowledge.sees(_g, MovesFixture.SAVOY, h) or not Armies.at(_g, h).is_empty():
			continue
		for d: int in 6:
			var n := ImproveRules.neighbour(h, d)
			if _g.map.index_of(n) >= 0 and _g.map.is_land(n) and not Knowledge.sees(_g, MovesFixture.SAVOY, n) and Armies.at(_g, n).is_empty():
				return {"to": h, "unseen": n}
	return {}


func test_walked_names_the_place_and_the_points_left() -> void:
	var w := _words(_walk(&"", Vector2i(5, 7)))
	assert_eq(w.text, "The %s walks to %s: 8 of 12 move points left." % [_a.name, Words.place(_g, Vector2i(5, 7))])
	assert_eq(w.tone, &"plain")


func test_walked_with_a_standing_rest_says_where_it_marches_on_to() -> void:
	assert_true(MovesFixture.standing(_g, _a, FAR_GOAL))
	var w := _words(_walk(&"points", Vector2i(1, 6), 6, {"standing": true, "points": 0}))
	assert_eq(w.text, "The %s walks to %s; it marches on to %s at the end of next season." % [
		_a.name, Words.place(_g, Vector2i(1, 6)), Words.place(_g, FAR_GOAL)])


func test_stored_says_when_it_sets_out() -> void:
	assert_true(MovesFixture.standing(_g, _a, FAR_GOAL))
	for why: StringName in [&"mustering", &"no_points"]:
		var w := _words(_walk(why, _a.hex, 0, {"points": 0}))
		assert_eq(w.text, "The %s sets out for %s at the end of next season." % [_a.name, Words.place(_g, FAR_GOAL)], String(why))


func test_a_goal_the_country_has_not_discovered_is_named_by_its_coordinates() -> void:
	FogFixture.thin(_g, MovesFixture.SAVOY, 0)
	var goal := ArmyFixture.NO_HEX
	for i: int in _g.map.hex_count():
		var h := _g.map.hex_of(i)
		if _g.map.is_land(h) and not Knowledge.discovered(_g, MovesFixture.SAVOY, h):
			goal = h
			break
	assert_ne(goal, ArmyFixture.NO_HEX, "the thin map has undiscovered land")
	_a.goal = goal
	var w := _words(_walk(&"no_points", _a.hex, 0))
	assert_true(str(w.text).contains("sets out for (%d, %d) at the end" % [goal.x, goal.y]), "P: an undiscovered place is named: %s" % str(w.text))


func test_sighted_keeps_the_engines_words_for_an_army_in_sight() -> void:
	var seen := Vector2i(6, 6)
	assert_true(Knowledge.sees(_g, MovesFixture.SAVOY, seen))
	var text := "an army of the Duchy of Milan came into sight at %s" % Words.place(_g, seen)
	var w := _words(_walk(&"sighted", Vector2i(5, 7), 1, {"text": text}))
	assert_eq(w.text, "The %s stops at %s: %s." % [_a.name, Words.place(_g, Vector2i(5, 7)), text])
	assert_eq(w.tone, &"warn")


func test_sighted_never_names_a_place_out_of_sight() -> void:
	var far := MovesFixture.named(_g, MovesFixture.NAME_NEAR).hex
	assert_false(Knowledge.sees(_g, MovesFixture.SAVOY, far))
	var w := _words(_walk(&"sighted", Vector2i(5, 7), 1, {"text": "an army of the Duchy of Milan came into sight at (%d, %d)" % [far.x, far.y]}))
	assert_false(str(w.text).contains("(%d, %d)" % [far.x, far.y]), "P: an army out of sight is named: %s" % str(w.text))
	assert_false(str(w.text).contains("Milan"))
	assert_true(str(w.text).ends_with("an army came into sight."))


func test_battle_names_the_place_and_the_battle() -> void:
	var w := _words(_walk(&"battle", Vector2i(6, 6), 1))
	assert_eq(w.text, "The %s attacks at %s: a battle." % [_a.name, Words.place(_g, Vector2i(6, 6))], "no record yet: a battle")
	assert_eq(w.tone, &"warn")


func test_zone_of_control_names_the_enemy_only_where_it_is_seen() -> void:
	var enemy_at := Vector2i(6, 6)
	ArmyFixture.army(_g, MovesFixture.MILAN, enemy_at, 0, 1)
	Sight.refresh(_g)
	var to := Vector2i(5, 7)
	var seen := _words(_walk(&"zoc", to, 1))
	assert_eq(seen.text, "The %s stops beside an army of the Duchy of Milan at %s: its season is over." % [_a.name, Words.place(_g, to)])
	var by := _beside_unseen()
	assert_false(by.is_empty(), "the map has a seen hex beside an unseen one")
	ArmyFixture.army(_g, MovesFixture.MILAN, by.unseen, 0, 1)
	Sight.refresh(_g)
	assert_false(Knowledge.sees(_g, MovesFixture.SAVOY, by.unseen))
	var hidden := _words(_walk(&"zoc", by.to, 1))
	assert_false(str(hidden.text).contains("Milan"), "P: an army out of sight is named: %s" % str(hidden.text))
	assert_true(str(hidden.text).contains("beside an enemy at "), str(hidden.text))


func test_blocked_names_the_other_country_only_where_it_is_seen() -> void:
	var held := Vector2i(5, 7)
	ArmyFixture.army(_g, &"GEN", held, 0, 1)
	Sight.refresh(_g)
	var seen := _words(_walk(&"blocked", _a.hex, 0))
	assert_true(str(seen.text).contains("an army of %s is at %s" % [Words.country_the(_g, &"GEN"), Words.place(_g, held)]), str(seen.text))
	var by := _beside_unseen()
	assert_false(by.is_empty(), "the map has a seen hex beside an unseen one")
	ArmyFixture.army(_g, &"GEN", by.unseen, 0, 1)
	Sight.refresh(_g)
	var hidden := _words(_walk(&"blocked", by.to, 0))
	assert_false(str(hidden.text).contains(Words.country_the(_g, &"GEN")), "P: the country of an army out of sight is named: %s" % str(hidden.text))
	assert_true(str(hidden.text).contains("another country's army stands in the way"), str(hidden.text))


func test_the_other_stops_have_their_words() -> void:
	var to := Vector2i(5, 7)
	var at := Words.place(_g, to)
	assert_eq(_words(_walk(&"shaken", to, 1)).text, "The %s stops at %s: too shaken to attack." % [_a.name, at])
	assert_eq(_words(_walk(&"fog", to, 1)).text, "The %s stops at %s: it spends its season finding the way through unmapped land." % [_a.name, at])
	assert_eq(_words(_walk(&"winter", to, 0)).text, "The %s waits for spring: the pass is closed." % _a.name)
	assert_eq(_words(_walk(&"winter", to, 2)).text, "The %s walks to %s and waits for spring: the pass is closed." % [_a.name, at])
	assert_eq(_words(_walk(&"something_new", to, 1)).text, "The %s stops at %s." % [_a.name, at], "an unknown stop still has words")


func test_another_countrys_army_has_no_toast() -> void:
	assert_eq(_words(_walk(&"", Vector2i(5, 7)), MovesFixture.MILAN).text, "", "P: Milan reads Savoy's order")
	assert_eq(MoveWords.of(_g, MovesFixture.SAVOY, -5, _walk(&"", Vector2i(5, 7))).text, "")
	assert_eq(_words({}).text, "", "no walk, no words")
	assert_true(str(_words(_walk(&"", Vector2i(5, 7)), &"").text).begins_with("The "), "the viewer of no country reads every army")
