## A settlement that falls a level (WorldImprove.lower_check and lower, Improve.lower_check and lower): each refusal with
## its words, the counts and the distances following, the pair rules freed, the lazy search agreeing with the eager one,
## and exactly one hex_changed.
extends GutTest


func _place(level: int) -> Dictionary:
	return ImproveFixture.place(level)


## A 5 x 5 block of one ground with the given places, every hex wild but the places.
func _bare(cover: int, height: float, places: Dictionary = {}) -> WorldImprove:
	var over: Dictionary = {}
	for hex: Variant in places.keys():
		over[hex] = {"place": _place(int(places[hex]))}
	var imp := WorldImprove.build(ImproveFixture.block(5, 5, {"cover": cover, "height": height}, over), 3)
	for hex: Vector2i in imp.hexes:
		if not imp.is_fixed(hex):
			imp._put(hex, ImproveRules.NONE, 0)
	return imp


func _sum_is_right(imp: WorldImprove) -> void:
	var total := 0
	for f: int in ImproveRules.FAMILIES:
		total += imp.count_of(f)
	assert_eq(total, imp.hexes.size(), "every hex is counted once")


func test_lower_refuses_with_its_words_and_a_town_falls_to_a_village_and_on_to_a_hamlet() -> void:
	var imp := _bare(WorldCover.FARMLAND, 100.0, {Vector2i(2, 2): 3})
	var town := Vector2i(2, 2)
	assert_eq(str(imp.lower_check(Vector2i(-9, 9))["reason"]), "not a land hex")
	assert_eq(str(imp.lower_check(Vector2i(0, 0))["reason"]), "only a settlement falls a level", "wild")
	imp.build_on(Vector2i(1, 2), ImproveRules.WHEAT)
	assert_eq(str(imp.lower_check(Vector2i(1, 2))["reason"]), "only a settlement falls a level", "goods")
	assert_false(bool(imp.lower(Vector2i(1, 2))["ok"]))
	assert_eq(imp.level_at(Vector2i(1, 2)), 1, "a refusal changes nothing")
	assert_true(bool(imp.lower_check(town)["ok"]))
	assert_true(bool(imp.lower(town)["ok"]), "a town falls to a village")
	assert_eq(imp.level_at(town), 2)
	assert_eq(imp.count_at(ImproveRules.SETTLEMENT, 3), 0, "the counts follow")
	assert_eq(imp.count_at(ImproveRules.SETTLEMENT, 2), 1)
	assert_true(bool(imp.lower(town)["ok"]), "a village falls to a hamlet")
	assert_eq(imp.level_at(town), 1)
	var no := imp.lower_check(town)
	assert_false(bool(no["ok"]))
	assert_eq(str(no["reason"]), "a hamlet falls no further")
	assert_eq(str(imp.lower(town)["reason"]), str(no["reason"]), "the doer says what the check says")
	assert_eq(imp.level_at(town), 1)
	assert_eq(imp.family_at(town), ImproveRules.SETTLEMENT, "it stays a settlement")
	_sum_is_right(imp)


func test_the_distances_and_pair_rules_follow_a_lower_in_the_eager_and_the_lazy_search() -> void:
	var imp := _bare(WorldCover.FARMLAND, 100.0, {Vector2i(2, 2): 4})
	var twin := _bare(WorldCover.FARMLAND, 100.0, {Vector2i(2, 2): 4})  # the lazy search reads a state of its own
	var lazy := WorldImprove.over(twin.map, twin.state)
	var near := Vector2i(3, 2)
	var far := Vector2i(4, 4)
	for w: WorldImprove in [imp, lazy]:
		assert_eq(int(w.facts_at(near)["city_distance"]), 1, "a city beside it")
		assert_false(w.conflict(near, ImproveRules.SETTLEMENT, 3).is_empty(), "no town beside a town")
		assert_true(bool(w.lower(Vector2i(2, 2))["ok"]), "city to a walled town")
		assert_eq(int(w.facts_at(near)["city_distance"]), 99, "no city left")
		assert_eq(int(w.facts_at(near)["town_distance"]), 1, "a town still")
	imp.lower(Vector2i(2, 2))
	lazy.lower(Vector2i(2, 2))
	for w: WorldImprove in [imp, lazy]:
		assert_eq(int(w.facts_at(near)["town_distance"]), 99, "a village opens the town-near levels no more")
		assert_eq(int(w.facts_at(near)["place_distance"]), 1, "it is still a place")
		assert_true(w.conflict(near, ImproveRules.SETTLEMENT, 3).is_empty(), "a town that fell frees the pair rule")
		assert_eq(int(w.facts_at(far)["town_distance"]), 99)
	for hex: Vector2i in imp.hexes:
		assert_eq(lazy.facts_at(hex), imp.facts_at(hex), "the lazy facts agree at %s" % hex)
		for f: int in range(1, ImproveRules.FAMILIES):
			for lv: int in range(1, ImproveRules.TOP_LEVEL[f] + 1):
				assert_eq(lazy.conflict(hex, f, lv), imp.conflict(hex, f, lv))


func test_improve_lower_is_one_hex_changed_and_a_check_with_no_hex_says_so() -> void:
	var g := Game.new_game(ImproveFixture.block(5, 5, {}, {Vector2i(2, 2): {"place": _place(3)}}), 3)
	assert_eq(str(Improve.lower_check(g, {})["reason"]), "no hex given")
	assert_eq(str(Improve.lower_check(g, {"hex": 5})["reason"]), "no hex given")
	assert_eq(str(Improve.lower(g, {})["reason"]), "no hex given")
	g.events.clear()
	assert_eq(str(Improve.lower(g, {"hex": Vector2i(-9, 9)})["reason"]), "not a land hex")
	assert_true(g.events.is_empty(), "a refusal emits nothing")
	var done := Improve.lower(g, {"hex": Vector2i(2, 2), "tag": &"AAA"})
	assert_true(bool(done["ok"]))
	assert_eq(g.improvement.level_at(Vector2i(2, 2)), 2)
	assert_eq(g.events.size(), 1, "exactly one event")
	assert_eq(str(g.events[0]["kind"]), "hex_changed")
	assert_eq(g.events[0]["hex"], Vector2i(2, 2))
	assert_true(bool(Improve.lower(g, {"hex": Vector2i(2, 2)})["ok"]))
	g.events.clear()
	assert_false(bool(Improve.lower(g, {"hex": Vector2i(2, 2)})["ok"]), "a hamlet")
	assert_true(g.events.is_empty())
