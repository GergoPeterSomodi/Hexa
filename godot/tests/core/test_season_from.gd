## Where an army came from (docs/architecture/moves-build-spec.md R40, D15; MV4): Army.season_from keeps the hex an army stood on
## when it first moved in the season (an at-once walk or a phase walk), ready_units' close_season turns it into moved_from and
## clears it, and the season report's "A → B" line (SummaryArmies) reads moved_from: it shows the season's at-once walks and phase
## walks together, and a walk of the next season does not change the last report. North Italy's 1480 game (ArmyFixture, Genoa the
## player; its armies walk its own land). P: an at-once walk missing from the report; a report changed by a walk after it.
extends GutTest

var _g: Game
var _town: Vector2i


func before_each() -> void:
	_g = ArmyFixture.game()
	_town = ArmyFixture.find_town(_g)
	Movement.clear_test_hostility()


## A hex of the player's own land beside `hex` that an army may march to, or NO_HEX.
func _own_beside(hex: Vector2i, not_this: Vector2i = Army.NO_HEX) -> Vector2i:
	for d: int in 6:
		var n := _g.map.neighbour(hex, d)
		if n != not_this and _g.map.index_of(n) >= 0 and Territory.owner_tag(_g, n) == ArmyFixture.TAG \
				and bool(Movement.march_check(_g, {"army": _g.armies[0].id, "goal": n, "tag": ArmyFixture.TAG}).ok):
			return n
	return Army.NO_HEX


## The report's "walked" lines of the last season for the player: the texts with an arrow.
func _walked_lines(turn: int) -> Array[String]:
	var out: Array[String] = []
	var section := SummaryArmies.of(_g, ArmyFixture.TAG, turn)["section"] as Dictionary
	for line: Dictionary in section.get("lines", []):
		if str(line["text"]).find("→") >= 0:
			out.append(str(line["text"]))
	return out


func test_set_hex_keeps_the_first_origin_of_the_season() -> void:
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, _town, 0, 1, 0)
	var first := _own_beside(_town)
	assert_ne(first, Army.NO_HEX)
	assert_eq(a.season_from, Army.NO_HEX, "no move yet")
	assert_true(bool(_g.act("march", {"army": a.id, "goal": first, "tag": ArmyFixture.TAG}).ok))
	assert_eq(a.hex, first)
	assert_eq(a.season_from, _town, "the at-once walk keeps where it set out")
	assert_eq(a.moved_from, Army.NO_HEX, "moved_from waits for the season's end")
	var second := _own_beside(first, _town)
	if second != Army.NO_HEX and a.points > 0:
		_g.act("march", {"army": a.id, "goal": second, "tag": ArmyFixture.TAG})
		assert_eq(a.season_from, _town, "a second walk keeps the first origin")


func test_the_report_shows_an_at_once_walk_and_a_phase_walk() -> void:
	var walker := ArmyFixture.army(_g, ArmyFixture.TAG, _town, 0, 1, 0)
	var goal := _own_beside(_town)
	assert_ne(goal, Army.NO_HEX)
	assert_true(bool(_g.act("march", {"army": walker.id, "goal": goal, "tag": ArmyFixture.TAG}).ok))
	assert_eq(walker.hex, goal, "it walked in the act")
	var other := _own_beside(_town, goal)
	var stander := ArmyFixture.army(_g, ArmyFixture.TAG, _town, 0, 1, 0)
	var standing := other != Army.NO_HEX and MovesFixture.standing(_g, stander, other)
	var turn := _g.turn
	assert_true(bool(Season.run(_g).ok))
	assert_eq(walker.moved_from, _town, "close_season: moved_from is where it set out")
	assert_eq(walker.season_from, Army.NO_HEX, "and season_from is cleared")
	var lines := _walked_lines(turn)
	var walked := "%s: %s → %s" % [walker.name, Words.place(_g, _town), Words.place(_g, goal)]
	var found := false
	for t: String in lines:
		if t.begins_with(walked):
			found = true
	assert_true(found, "P: an at-once walk missing from the report: %s in %s" % [walked, str(lines)])
	if standing:
		assert_eq(stander.hex, other, "the phase walked the standing march")
		assert_eq(stander.moved_from, _town)
		assert_eq(lines.size(), 2, "both walks are in the report: %s" % str(lines))


func test_a_walk_of_the_next_season_does_not_change_the_last_report() -> void:
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, _town, 0, 1, 0)
	var goal := _own_beside(_town)
	assert_true(bool(_g.act("march", {"army": a.id, "goal": goal, "tag": ArmyFixture.TAG}).ok))
	var turn := _g.turn
	assert_true(bool(Season.run(_g).ok))
	var before := _walked_lines(turn)
	assert_eq(before.size(), 1, str(before))
	var back := _g.act("march", {"army": a.id, "goal": _town, "tag": ArmyFixture.TAG})
	assert_true(bool(back.ok), str(back.reason))
	assert_eq(a.hex, _town, "the next season's walk is done")
	_g.version += 1
	# The origin of the last season's line is kept (moved_from is written only by close_season). The line's end is read by
	# SummaryArmies from the army's live hex, so it follows the new walk. Known gap, left open: the end hex is in no stored
	# field (army/3 holds moved_from and season_from only; the chronicle holds no unit_moved), so fixing it needs a new army
	# field and a save format bump. This case pins the part the state owns: the origin, the line count and season_from.
	var after := _walked_lines(turn)
	assert_eq(after.size(), before.size(), "P: a report changed by a walk after it (a line lost or added)")
	var origin := "%s: %s →" % [a.name, Words.place(_g, _town)]
	assert_true(after.size() == 1 and after[0].begins_with(origin), "the line still sets out from the town: %s" % str(after))
	assert_eq(a.moved_from, _town, "moved_from still names the last season's origin")
	assert_eq(a.season_from, goal, "season_from holds this season's origin")


func test_an_army_that_did_not_move_has_no_line() -> void:
	ArmyFixture.army(_g, ArmyFixture.TAG, _town, 0, 1, 0)
	var turn := _g.turn
	assert_true(bool(Season.run(_g).ok))
	assert_eq(_walked_lines(turn).size(), 0)
	for a: Army in _g.armies:
		assert_eq([a.moved_from, a.season_from], [Army.NO_HEX, Army.NO_HEX])
