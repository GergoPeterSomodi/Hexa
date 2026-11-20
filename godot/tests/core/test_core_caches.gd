## The caches and fast paths of the speed work (Y17): each gives what the plain computation gives, after actions, season
## ends, owner changes and direct edits of the state. Territory's owner index, Works' city count, Words.place's place
## index, ViewCache.pinned, WorldImprove.build_check (one family), the two-hex ring and ImproveRules.pair_reason's memo.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"

var _g: Game


func before_each() -> void:
	var defs := load(DEFS_PATH) as GameDefs
	_g = Game.new_scenario(load(MAP_PATH) as MapData, defs, defs.scenarios[defs.scenarios.size() - 1], 1480)
	assert_true(bool(_g.act("choose_country", {"tag": &"GEN"})["ok"]))


# ----- the plain computations -----------------------------------------------------------------------------------


func _districts_plain(id: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i: int in _g.map.hex_count():
		if _g.map.land[i] != 0 and int(_g.state.owner[i]) == id:
			out.append(i)
	return out


func _slots_plain(tag: StringName) -> int:
	var c := Countries.by_tag(_g, tag)
	var total := _g.defs.work_slots_base
	for i: int in _districts_plain(c.id):
		if int(_g.state.main_use[i]) == ImproveRules.SETTLEMENT and int(_g.state.level[i]) >= _g.defs.work_slots_city_level:
			total += 1
	return total


func _place_plain(hex: Vector2i) -> String:
	var coords := "(%d, %d)" % [hex.x, hex.y]
	var best_name := ""
	var best_distance := Words.NEAR + 1
	for entry: Dictionary in _g.map.places:
		var place_name := str(entry.get("name", ""))
		var at: Variant = entry.get("hex", null)
		if place_name == "" or typeof(at) != TYPE_VECTOR2I:
			continue
		var distance := ImproveRules.hex_distance(hex, at as Vector2i)
		if distance == 0:
			return "%s %s" % [place_name, coords]
		if distance < best_distance:
			best_distance = distance
			best_name = place_name
	return coords if best_name == "" else "near %s %s" % [best_name, coords]


func _all_ids() -> Array[int]:
	var out: Array[int] = []
	for c: Country in _g.countries:
		out.append(c.id)
	return out


func _same_districts(label: String) -> void:
	for id: int in _all_ids():
		assert_eq(Territory.districts(_g, id), _districts_plain(id), "%s: districts of %d" % [label, id])
		assert_eq(Territory.count(_g, id), _districts_plain(id).size(), "%s: count of %d" % [label, id])


# ----- Territory --------------------------------------------------------------------------------------------------


func test_districts_equal_the_plain_scan_through_every_kind_of_change() -> void:
	_same_districts("start")
	var moved: Array[Vector2i] = []
	for i: int in Territory.districts(_g, Countries.by_tag(_g, &"GEN").id):
		if moved.size() < 4:
			moved.append(_g.map.hex_of(i))
	var to := Countries.by_tag(_g, &"SAV").id
	assert_gt(Territory.transfer(_g, moved, to), 0)
	_same_districts("after a transfer")
	_g.state.owner[_g.map.index_of(moved[0])] = 0  # a direct edit, no version bump
	_same_districts("after a direct edit")
	assert_gt(_g.dev_transfer(moved, Countries.by_tag(_g, &"GEN").id), -1)
	_same_districts("after a dev transfer")
	Season.run(_g)
	_same_districts("after a season")


func test_districts_are_made_once_for_the_same_owners() -> void:
	var id := Countries.by_tag(_g, &"GEN").id
	var first := Territory.districts(_g, id)
	var second := Territory.districts(_g, id)
	assert_eq(first, second)
	assert_eq(_g.view_cache.size(), 0, "the index is pinned, not one of the 64")
	# Made once: the pinned index is the same object across calls while the owners do not change.
	assert_same(Territory._by_owner(_g), Territory._by_owner(_g), "the index is not rebuilt on every call")


# ----- Works.slots ------------------------------------------------------------------------------------------------


func test_slots_equal_the_plain_count_after_actions_seasons_and_direct_edits() -> void:
	assert_eq(Works.slots(_g, &"GEN"), _slots_plain(&"GEN"))
	var capital := Countries.by_tag(_g, &"GEN").capital
	var at := _g.map.index_of(capital)
	_g.state.level[at] = 5  # a direct edit: the city counts
	assert_eq(Works.slots(_g, &"GEN"), _slots_plain(&"GEN"), "after a level edit")
	_g.state.level[at] = 1
	assert_eq(Works.slots(_g, &"GEN"), _slots_plain(&"GEN"), "after the edit back")
	for n: int in 6:
		Season.run(_g)
		assert_eq(Works.slots(_g, &"GEN"), _slots_plain(&"GEN"), "season %d" % n)
	for tag: StringName in [&"SAV", &"MLO", &"VEN", &"GEN"]:
		assert_eq(Works.slots(_g, tag), _slots_plain(tag), String(tag))
	_g.defs.work_slots_city_level = 1  # the threshold is part of the key
	for tag: StringName in [&"GEN", &"MLO"]:
		assert_eq(Works.slots(_g, tag), _slots_plain(tag), "threshold 1, " + String(tag))
	_g.defs.work_slots_city_level = 4


# ----- Words.place ------------------------------------------------------------------------------------------------


func test_place_equals_the_plain_scan_on_every_hex() -> void:
	var checked := 0
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		assert_eq(Words.place(_g, hex), _place_plain(hex), str(hex))
		checked += 1
	assert_eq(checked, _g.map.hex_count())
	assert_eq(Words.place(_g, Vector2i(-3, -3)), _place_plain(Vector2i(-3, -3)), "off the map")


# ----- ViewCache --------------------------------------------------------------------------------------------------


func test_pinned_is_made_again_only_for_a_new_key() -> void:
	var c := ViewCache.new()
	var made := [0]
	var make := func() -> Array:
		made[0] += 1
		return [made[0]]
	assert_eq(c.pinned(&"a", [1, 2], make), [1])
	assert_eq(c.pinned(&"a", [1, 2], make), [1], "the same key: the same value")
	assert_eq(c.pinned(&"a", [1, 3], make), [2], "a new key: made again")
	assert_eq(c.pinned(&"b", [1, 3], make), [3], "another slot")
	assert_eq(c.size(), 0, "pins are not counted")
	c.clear()
	assert_eq(c.pinned(&"a", [1, 3], make), [4], "clear forgets the pins")


# ----- WorldImprove: one family, the ring, the memo ---------------------------------------------------------------


## What build_check answered when it went through build_options (the reference for the one-family path).
func _check_by_options(w: WorldImprove, hex: Vector2i, family: int) -> Dictionary:
	if family_at_plain(w, hex) != ImproveRules.NONE:
		return {"ok": false, "reason": "something already stands here"}
	for option: Dictionary in w.build_options(hex):
		if int(option["family_id"]) == family:
			return {"ok": bool(option["ok"]), "reason": str(option["reason"])}
	return {}


func family_at_plain(w: WorldImprove, hex: Vector2i) -> int:
	return w.family_at(hex)


func test_build_check_of_one_family_equals_the_options_list_everywhere() -> void:
	var w := _g.improvement
	var compared := 0
	var step := 3
	for i: int in range(0, _g.map.hex_count(), step):
		var hex := _g.map.hex_of(i)
		if _g.map.land[i] == 0:
			continue
		for family: int in range(ImproveRules.WHEAT, ImproveRules.FAMILIES):
			var reference := _check_by_options(w, hex, family)
			if reference.is_empty():
				continue  # not offered: the long answer, unchanged code
			var got := w.build_check(hex, family)
			assert_eq(bool(got["ok"]), bool(reference["ok"]), "%s %d" % [hex, family])
			assert_eq(str(got["reason"]), str(reference["reason"]), "%s %d reason" % [hex, family])
			compared += 1
	assert_gt(compared, 200, "many offers compared")


func test_the_works_of_a_lazy_game_equal_those_of_a_searched_one() -> void:
	# The same state through WorldImprove.over (lazy) and the searched context agree on every check.
	var lazy := WorldImprove.over(_g.map, _g.state)
	var searched := _g.improvement
	var compared := 0
	for i: int in range(0, _g.map.hex_count(), 5):
		if _g.map.land[i] == 0:
			continue
		var hex := _g.map.hex_of(i)
		for family: int in range(ImproveRules.WHEAT, ImproveRules.FAMILIES, 3):
			assert_eq(lazy.build_check(hex, family), searched.build_check(hex, family), "%s %d" % [hex, family])
			compared += 1
		assert_eq(lazy.upgrade_check(hex), searched.upgrade_check(hex), "upgrade %s" % hex)
	assert_gt(compared, 100)


func test_the_two_hex_ring_is_the_cells_two_away_in_cell_order() -> void:
	var w := WorldImprove.over(_g.map, _g.state)
	for hex: Vector2i in [Vector2i(8, 13), Vector2i(7, 12), Vector2i(0, 0), Vector2i(20, 21), Vector2i(21, 20)]:
		if not w._index.has(hex):
			continue
		var expected: Array[int] = []
		for k: int in w._cells.size():
			if ImproveRules.hex_distance(hex, w._cells[k]) == 2:
				expected.append(k)
		var got := w._ring_of(hex)
		assert_eq(Array(got), expected, str(hex))


func test_the_pair_memo_gives_the_unmemoised_answer() -> void:
	for fa: int in range(1, ImproveRules.FAMILIES):
		for la: int in range(1, ImproveRules.TOP_LEVEL[fa] + 1):
			for fb: int in range(1, ImproveRules.FAMILIES):
				for lb: int in range(1, ImproveRules.TOP_LEVEL[fb] + 1):
					for radius: int in [1, 2]:
						var first := ImproveRules.pair_reason(fa, la, fb, lb, radius)
						var again := ImproveRules.pair_reason(fa, la, fb, lb, radius)
						assert_eq(first, ImproveRules._pair_reason_of(fa, la, fb, lb, radius))
						assert_eq(again, first)


# ----- Works.season with the list rebuilt once --------------------------------------------------------------------


func test_a_season_removes_exactly_the_finished_works_in_order() -> void:
	var ids: Array[int] = []
	var tried := 0
	var districts := Territory.districts(_g, Countries.by_tag(_g, &"GEN").id)
	for i: int in districts:
		var hex := _g.map.hex_of(i)
		tried += 1
		for o: Dictionary in _g.improvement.build_options(hex):
			if bool(o["ok"]) and Works.in_use(_g, &"GEN") < Works.slots(_g, &"GEN"):
				if bool(_g.act("build", {"hex": hex, "family": int(o["family_id"]), "tag": &"GEN"})["ok"]):
					ids.append(_g.state.work_at(hex).id)
				break
	assert_gt(ids.size(), 1)
	var seen_order := true
	for n: int in 12:
		var before: Array[int] = []
		for w: Work in _g.state.works:
			before.append(w.id)
		Season.run(_g)
		var after: Array[int] = []
		for w: Work in _g.state.works:
			after.append(w.id)
		var expected: Array[int] = []
		for id: int in before:
			if after.has(id):
				expected.append(id)
		seen_order = seen_order and after == expected
	assert_true(seen_order, "the works that stay keep their order")
	assert_eq(_g.state.works.size(), 0, "all finished or cancelled after 12 seasons")
