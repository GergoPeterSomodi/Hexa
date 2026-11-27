## The armies a peace strands (issue #467; m7-build-spec 4.9): when land changes hands, every army that may no longer stand on
## its hex (Movement.open_to) goes to its own land, a third country's too, in army id order. Venice and Savoy at war with
## Milan; Milan yields to Venice the districts Venice holds, where Savoy's armies stand.
extends GutTest

const MLO := MovesFixture.MILAN
const SAV := MovesFixture.SAVOY
const VEN := &"VEN"
const COMPANIES := 5

var _g: Game


func before_each() -> void:
	Movement.clear_test_hostility()
	_g = ArmyFixture.game()
	WarFixture.at_war(_g, VEN, MLO)
	WarFixture.at_war(_g, SAV, MLO)


func after_each() -> void:
	Movement.clear_test_hostility()


## `n` districts of Milan, not its capital, with no army, in index order.
func _milanese(n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var milan := Countries.by_tag(_g, MLO)
	for i: int in Territory.districts(_g, milan.id):
		var hex := _g.map.hex_of(i)
		if hex != milan.capital and Armies.at(_g, hex).is_empty() and out.size() < n:
			out.append(hex)
	assert_eq(out.size(), n, "Milan has districts enough")
	return out


## Two armies of Savoy on two districts Venice holds (the second marching), one on a district Milan keeps; Milan yields.
## Returns {on: the three armies' ids, ceded: the two hexes, kept: the third hex}.
func _yield_under_savoy() -> Dictionary:
	var hexes := _milanese(3)
	var ids: Array[int] = []
	for k: int in 3:
		ids.append(ArmyFixture.army(_g, SAV, hexes[k], 0, COMPANIES).id)
	for k: int in 2:
		WarFixture.set_occupier(_g, hexes[k], VEN)
	var home := _g.map.hex_of(Territory.districts(_g, ArmyFixture.id_of(_g, SAV))[0])
	Armies.set_order(_g, Armies.by_id(_g, ids[1]), Army.ORDER_MARCH, home, PackedInt32Array([_g.map.index_of(home)]))
	Sight.refresh(_g)
	_g.events.clear()
	var res := _g.act("make_peace", {"target": VEN, "terms": "yield", "tag": MLO})
	assert_true(bool(res.ok), str(res.reason))
	for k: int in 2:
		assert_eq(Territory.owner_tag(_g, hexes[k]), VEN, "the district is Venice's now")
	return {"on": ids, "ceded": [hexes[0], hexes[1]], "kept": hexes[2]}


func test_a_third_countrys_armies_leave_the_land_that_changed_hands() -> void:
	var scene := _yield_under_savoy()
	var ids: Array = scene.on
	var limit := Military.stack_limit(_g, SAV)
	for k: int in 2:
		var a := Armies.by_id(_g, ids[k])
		assert_not_null(a, "army %d lives" % ids[k])
		assert_ne(a.hex, (scene.ceded as Array)[k], "army %d left the ceded district" % a.id)
		assert_eq(Territory.owner_tag(_g, a.hex), SAV, "for Savoy's own land")
		assert_lte(Armies.units_at(_g, SAV, a.hex), limit)
	assert_eq(Armies.by_id(_g, ids[2]).hex, scene.kept, "the army on land Milan keeps stays: Savoy is at war with Milan still")
	for a: Army in _g.armies:
		assert_true(Movement.open_to(_g, a.tag, a.hex), "army %d of %s may stand on %s" % [a.id, a.tag, str(a.hex)])


func test_a_third_countrys_march_halts_with_the_peace() -> void:
	var scene := _yield_under_savoy()
	var marching := Armies.by_id(_g, (scene.on as Array)[1])
	assert_eq(marching.order, Army.ORDER_NONE)
	assert_eq(marching.halt_why, &"peace")
	var halts: Array[int] = []
	var peace_at := -1
	for k: int in _g.events.size():
		var e: Dictionary = _g.events[k]
		if str(e.get("kind", "")) == "peace_made":
			peace_at = k
		if str(e.get("kind", "")) == "march_halted":
			assert_gt(k, peace_at, "after the peace")
			halts.append(int(e["army"]))
	assert_eq(halts, [marching.id] as Array[int], "one halt, the marching army's")


func test_the_same_peace_moves_the_armies_the_same_way() -> void:
	_yield_under_savoy()
	var first := _g.digest()
	before_each()
	_yield_under_savoy()
	assert_eq(_g.digest(), first)
