## People.grow_check and People.decline_check (core/systems/people.gd; docs/architecture/m5-build-spec.md 4.5 and 9): every row
## of each table with its words, on views of "Italy, 1480" (the first refusal is the verdict), and the view's own changes are
## read: a what-if town beside a village blocks it. Planted faults: a work under way, Savona beside Cuneo (pair rule 0), a
## pending work nearby, not fed, not full, a walled town, a hamlet, a dye works that needs the town.
extends GutTest

const ALBA := Vector2i(6, 11)  # "the village near Turin": Savoy's, 3,000 people, no town beside it
const LUCCA := Vector2i(12, 15)  # a village beside Pisa (13, 16), a walled town
const SAVONA := Vector2i(6, 13)  # a town beside Cuneo (5, 13)
const GENOA := Vector2i(8, 13)  # a walled town
const DYES_HEX := Vector2i(7, 12)

var _g: Game


func before_each() -> void:
	_g = EconomyFixture.game()


func _view() -> StateView:
	return StateView.of(_g.state)


func _i(hex: Vector2i) -> int:
	return _g.map.index_of(hex)


## A work on `hex` as Works would have recorded it (the checks read only its hex, family and level).
func _work(hex: Vector2i, level_to: int, family: int = ImproveRules.SETTLEMENT) -> void:
	var w := Work.new()
	w.id = _g.state.next_work_id
	_g.state.next_work_id += 1
	w.tag = &"SAV"
	w.hex = hex
	w.action = Works.UPGRADE
	w.family = family
	w.level_to = level_to
	_g.state.works.append(w)


# ----- grow_check: the rows of 4.5 in order -----------------------------------------------------------------------------


func test_row_1_not_a_settlement() -> void:
	var v := People.grow_check(_g, _view(), Vector2i(7, 13), 1000)  # wild farmland
	assert_false(v["ok"])
	assert_eq(v["reason"], "not a settlement")
	assert_eq([v["rule"], v["other"]], [-1, People.NO_HEX])
	assert_eq(People.grow_check(_g, _view(), Vector2i(-1, -1), 1000)["reason"], "not a settlement", "off the map")


func test_row_2_walls_are_the_crowns_work() -> void:
	for hex: Vector2i in [SAVONA, GENOA]:
		var v := People.grow_check(_g, _view(), hex, 1000)
		assert_eq(v["reason"], "the people raise villages and towns; walls are the crown's work", str(hex))
		assert_false(v["ok"])
	assert_eq(_g.defs.people_top_level, 3, "the committed top level the table reads")


func test_row_3_a_work_under_way_stops_it() -> void:
	var full := _view().with_people({_i(ALBA): 4000})
	assert_true(People.grow_check(_g, full, ALBA, 1000)["ok"], "the same village without the work is ok")
	_work(ALBA, 3)
	var v := People.grow_check(_g, full, ALBA, 1000)
	assert_false(v["ok"])
	assert_eq(v["reason"], "a work is under way here")


func test_row_4_not_full() -> void:
	var v := People.grow_check(_g, _view(), ALBA, 1000)
	assert_eq(v["reason"], "not full: 3,000 of 4,000 people")
	var almost := People.grow_check(_g, _view().with_people({_i(ALBA): 3999}), ALBA, 1000)
	assert_eq(almost["reason"], "not full: 3,999 of 4,000 people")
	assert_true(People.grow_check(_g, _view().with_people({_i(ALBA): 4000}), ALBA, 1000)["ok"])
	assert_true(People.grow_check(_g, _view().with_people({_i(ALBA): 4100}), ALBA, 1000)["ok"], "over the room counts as full")


func test_row_5_not_fed() -> void:
	var full := _view().with_people({_i(ALBA): 4000})
	assert_eq(People.grow_check(_g, full, ALBA, 999)["reason"], "your towns are not fed")
	assert_eq(People.grow_check(_g, full, ALBA, 0)["reason"], "your towns are not fed")
	assert_true(People.grow_check(_g, full, ALBA, 1000)["ok"])


func test_row_6_a_pair_rule_with_the_other_piece() -> void:
	var full := _view().with_people({_i(LUCCA): 4000})
	var v := People.grow_check(_g, full, LUCCA, 1000)
	assert_false(v["ok"])
	assert_eq(v["reason"], "a town needs its own countryside: no two towns side by side (settlements 4 at 13, 16)")
	assert_eq(v["rule"], 0)
	assert_eq(v["other"], Vector2i(13, 16), "Pisa, a walled town")
	assert_eq(ImproveRules.PAIR_WORDS[v["rule"]] % ["Pisa (13, 16)", "Lucca (12, 15)"],
		"Pisa (13, 16) is a town beside Lucca (12, 15): two towns may not stand side by side.")


func test_savona_fallen_to_a_village_cannot_grow_back_beside_cuneo() -> void:
	var fallen := _view().with({_i(SAVONA): Vector2i(1, 2)}).with_people({_i(SAVONA): 4000})
	var v := People.grow_check(_g, fallen, SAVONA, 1000)
	assert_false(v["ok"])
	assert_eq(v["rule"], 0)
	assert_eq(v["other"], Vector2i(5, 13), "Cuneo")
	assert_eq(v["reason"], "a town needs its own countryside: no two towns side by side (settlements 3 at 5, 13)")


func test_row_7_a_pending_work_nearby() -> void:
	var full := _view().with_people({_i(ALBA): 4000})
	# A town begun on the hex beside Alba would break pair rule 0 once built.
	var beside := _g.map.neighbour(ALBA, 0)
	_work(beside, 3)
	var v := People.grow_check(_g, full, ALBA, 1000)
	assert_false(v["ok"])
	assert_eq(v["reason"], Works.pending_conflict(_g, ALBA, ImproveRules.SETTLEMENT, 3))
	assert_true(String(v["reason"]).begins_with("a work under way at (%d, %d) would break it: " % [beside.x, beside.y]))
	assert_eq(v["rule"], -1, "a work is not a pair rule against a piece")


func test_row_8_ok_carries_no_rule() -> void:
	var v := People.grow_check(_g, _view().with_people({_i(ALBA): 4000}), ALBA, 1000)
	assert_eq(v, {"ok": true, "reason": "", "rule": -1, "other": People.NO_HEX})


func test_a_hamlet_grows_to_a_village_and_a_village_to_a_town_only() -> void:
	var hamlet := _view().with({_i(ALBA): Vector2i(1, 1)}).with_people({_i(ALBA): 2000})
	assert_true(People.grow_check(_g, hamlet, ALBA, 1000)["ok"], "a hamlet full at 2,000 becomes a village")
	assert_eq(People.grow_check(_g, _view().with({_i(ALBA): Vector2i(1, 1)}).with_people({_i(ALBA): 1999}), ALBA, 1000)["reason"],
		"not full: 1,999 of 2,000 people")


func test_the_views_changes_are_read() -> void:
	var full := _view().with_people({_i(ALBA): 4000})
	assert_true(People.grow_check(_g, full, ALBA, 1000)["ok"])
	# A what-if town on a land hex beside it blocks the growth; the base is untouched.
	var beside := Vector2i(-1, -1)
	for d: int in 6:
		var near := _g.map.neighbour(ALBA, d)
		if _g.map.is_land(near) and _g.state.main_use[_i(near)] == 0:
			beside = near
			break
	assert_ne(beside, Vector2i(-1, -1), "a free land hex beside Alba")
	var crowded := full.with({_i(beside): Vector2i(1, 3)})
	var v := People.grow_check(_g, crowded, ALBA, 1000)
	assert_false(v["ok"])
	assert_eq([v["rule"], v["other"]], [0, beside])
	assert_eq(_g.state.main_use[_i(beside)], 0, "the state is as it was")
	# The room is the view's: with its own level the same people are not full.
	var city := _view().with({_i(ALBA): Vector2i(1, 5)}).with_people({_i(ALBA): 4000})
	assert_eq(People.grow_check(_g, city, ALBA, 1000)["reason"], "the people raise villages and towns; walls are the crown's work")


func test_conflict_equals_the_improvement_rules_everywhere() -> void:
	# The view-based walk gives the same first conflict as WorldImprove's own, hex by hex and option by option.
	var options: Array[Vector2i] = [Vector2i(1, 3), Vector2i(2, 1), Vector2i(6, 1), Vector2i(7, 3), Vector2i(5, 2), Vector2i(1, 4)]
	var checked := 0
	for i: int in _g.map.hex_count():
		if _g.map.land[i] == 0:
			continue
		var hex := _g.map.hex_of(i)
		for option: Vector2i in options:
			var ours := People.conflict(_g, _view(), hex, option.x, option.y)
			var theirs := _g.improvement.conflict(hex, option.x, option.y)
			assert_eq(ours, theirs, "%s as %s" % [str(hex), str(option)])
			checked += 1
	assert_gt(checked, 1500)


func test_a_grow_check_that_says_ok_is_one_improve_accepts() -> void:
	# R4: every village and hamlet of every country, full and fed on the view, that grow_check allows is allowed by
	# Improve.upgrade_check on the same hex too.
	var allowed := 0
	var refused := 0
	for c: Country in _g.countries:
		for i: int in Territory.districts(_g, c.id):
			if _g.state.main_use[i] != 1 or _g.state.level[i] >= 3:
				continue
			var hex := _g.map.hex_of(i)
			var room := People.room_at(_g, _view(), hex)
			var full := _view().with_people({i: room})
			if bool(People.grow_check(_g, full, hex, 1000)["ok"]):
				allowed += 1
				assert_true(bool(Improve.upgrade_check(_g, {"hex": hex, "tag": c.tag})["ok"]), "%s %s" % [c.tag, str(hex)])
			else:
				refused += 1
	assert_gt(allowed, 5, "villages that grow")
	assert_gt(refused, 0, "and villages that cannot (Lucca beside Pisa)")


# ----- decline_check ------------------------------------------------------------------------------------------------------


func test_decline_row_1_not_a_settlement() -> void:
	var v := People.decline_check(_g, _view(), Vector2i(7, 13))
	assert_false(v["ok"])
	assert_eq(v["reason"], "not a settlement")
	assert_eq(v["other"], People.NO_HEX)
	assert_false(v.has("rule"), "a decline names no pair rule")


func test_decline_row_2_a_hamlet_falls_no_further() -> void:
	var hamlet := _view().with({_i(ALBA): Vector2i(1, 1)}).with_people({_i(ALBA): 10})
	assert_eq(People.decline_check(_g, hamlet, ALBA)["reason"], "a hamlet falls no further")


func test_decline_row_3_walls_do_not_fall_to_hunger() -> void:
	var thin := _view().with_people({_i(GENOA): 300})
	var v := People.decline_check(_g, thin, GENOA)
	assert_false(v["ok"])
	assert_eq(v["reason"], "walls do not fall to hunger")


func test_decline_row_4_a_work_under_way() -> void:
	var thin := _view().with_people({_i(SAVONA): 1900})
	assert_true(People.decline_check(_g, thin, SAVONA)["ok"], "without the work")
	_work(SAVONA, 4)
	assert_eq(People.decline_check(_g, thin, SAVONA)["reason"], "a work is under way here")


func test_decline_row_5_not_under_the_floor() -> void:
	assert_eq(People.decline_check(_g, _view(), SAVONA)["reason"], "not under 2,000 people")
	var edge := _view().with_people({_i(SAVONA): 2000})
	assert_eq(People.decline_check(_g, edge, SAVONA)["reason"], "not under 2,000 people", "at the floor is not under it")
	assert_true(People.decline_check(_g, _view().with_people({_i(SAVONA): 1999}), SAVONA)["ok"])
	var village := _view().with_people({_i(ALBA): 1000})
	assert_eq(People.decline_check(_g, village, ALBA)["reason"], "not under 1,000 people")
	assert_true(People.decline_check(_g, _view().with_people({_i(ALBA): 999}), ALBA)["ok"], "a village under 1,000 falls to a hamlet")


func test_decline_row_6_a_dye_works_that_needs_the_town() -> void:
	# Savona (6, 13) is the only town within one hex of (7, 12): a dye works there needs it.
	var base := _view().with_people({_i(SAVONA): 1935})
	assert_true(People.decline_check(_g, base, SAVONA)["ok"], "Savona falls at 1,935 with no dye works (4.11 e)")
	var dyed := base.with({_i(DYES_HEX): Vector2i(ImproveRules.DYES, 1)})
	var v := People.decline_check(_g, dyed, SAVONA)
	assert_false(v["ok"])
	assert_eq(v["other"], DYES_HEX)
	assert_eq(v["reason"], "the %s at (7, 12) needs this town" % ImproveRules.NAMES[ImproveRules.DYES])
	# A dye works needs a town within one hex only: one two hexes away does not need Savona.
	var far := base.with({_i(Vector2i(7, 11)): Vector2i(ImproveRules.DYES, 1)})
	assert_true(People.decline_check(_g, far, SAVONA)["ok"], "(7, 11) is two hexes from Savona: it never relied on it")


func test_decline_row_6_other_pieces_that_need_a_town() -> void:
	var base := _view().with_people({_i(SAVONA): 1935})
	# A silk district and a third-stage district rely on a town within two hexes. Genoa (8, 13) is a town too: a piece
	# within two hexes of both still has a town without Savona.
	var silk_at := Vector2i(5, 12)  # near Savona, two hexes or more from Genoa
	var silk := base.with({_i(silk_at): Vector2i(ImproveRules.SILK, 1)})
	var reliant := People.decline_check(_g, silk, SAVONA)
	var near_other := false
	for dy: int in range(-2, 3):
		for dx: int in range(-3, 4):
			var at := silk_at + Vector2i(dx, dy)
			if at != SAVONA and ImproveRules.hex_distance(at, silk_at) <= 2 and _g.map.is_land(at):
				var level := _g.state.level[_i(at)]
				if _g.state.main_use[_i(at)] == 1 and level >= 3:
					near_other = true
	assert_eq(bool(reliant["ok"]), near_other, "falls unless the silk has no other town within two hexes")
	if not near_other:
		assert_eq(reliant["other"], silk_at)
	# A third-stage district (a wheat stage 3) within two hexes of Savona and no other town in two hexes of it.
	var wheat3 := base.with({_i(Vector2i(4, 13)): Vector2i(ImproveRules.WHEAT, 3)})
	var v3 := People.decline_check(_g, wheat3, SAVONA)
	var wheat_other := false
	for dy: int in range(-2, 3):
		for dx: int in range(-3, 4):
			var at := Vector2i(4, 13) + Vector2i(dx, dy)
			if at != SAVONA and ImproveRules.hex_distance(at, Vector2i(4, 13)) <= 2 and _g.map.is_land(at):
				if _g.state.main_use[_i(at)] == 1 and _g.state.level[_i(at)] >= 3:
					wheat_other = true
	assert_eq(bool(v3["ok"]), wheat_other, "the stage-3 rule: a town within two hexes")


func test_decline_check_reads_the_views_pieces_not_the_states() -> void:
	var thin := _view().with_people({_i(SAVONA): 1935})
	var dyed := thin.with({_i(DYES_HEX): Vector2i(ImproveRules.DYES, 1)})
	assert_false(People.decline_check(_g, dyed, SAVONA)["ok"])
	assert_true(People.decline_check(_g, thin, SAVONA)["ok"], "the view without it is free: nothing was written to the state")
	assert_eq(_g.state.main_use[_i(DYES_HEX)], ImproveRules.VINEYARD, "the vineyard still stands in the state")
