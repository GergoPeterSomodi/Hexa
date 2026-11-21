## The worked walks of docs/architecture/m6-build-spec.md 4.13 (b) to (d) on "Italy, 1480", seed 1480, as Savoy, with the
## movement phase (task L6). (a), the raising, and (d)'s starvation belong to later tasks. The Vercelli to Aosta route is the
## 15-point one by Turin (4.13 (c) as first written): the 14-point east chain through (7, 9) and (7, 8) is Milan's land, closed
## to Savoy in peace (D13).
extends GutTest

const SAV := &"SAV"
const TURIN := Vector2i(5, 9)
const VERCELLI := Vector2i(6, 9)
const SUSA := Vector2i(4, 9)
const MONT_CENIS := Vector2i(3, 9)
const SADDLE := Vector2i(3, 7)
const AOSTA := Vector2i(3, 8)
const SPRING_1480 := 1
const SUMMER_1480 := 2
const AUTUMN_1480 := 3
const WINTER_1480 := 4
const SPRING_1481 := 5

var _g: Game


func before_each() -> void:
	_g = ArmyFixture.game()
	Movement.clear_test_hostility()


func after_each() -> void:
	Movement.clear_test_hostility()


func _moved(army_id: int) -> Array:
	var out: Array = []
	for e: Dictionary in _g.events:
		if str(e.get("kind", "")) == "unit_moved" and int(e.get("army", -1)) == army_id:
			out.append(e)
	return out


func test_the_savoy_hexes_of_the_worked_walks_are_its_own() -> void:
	for hex: Vector2i in [TURIN, VERCELLI, SUSA, MONT_CENIS, SADDLE, AOSTA]:
		assert_eq(Territory.owner_tag(_g, hex), SAV, "%s is Savoy's" % str(hex))


func test_b_across_the_po_on_the_wooden_bridge() -> void:
	var a := ArmyFixture.army(_g, SAV, TURIN, 0, 2, SPRING_1480)
	assert_true(bool(Movement.march(_g, {"army": a.id, "goal": VERCELLI, "tag": SAV}).ok))
	MovementPhase.season(_g)
	assert_eq(a.hex, TURIN, "it musters in spring")
	_g.turn = SUMMER_1480
	MovementPhase.season(_g)
	assert_eq(a.hex, VERCELLI, "in summer it walks the bridge")
	var e: Dictionary = _moved(a.id)[0]
	assert_eq(e.path, _path([TURIN, VERCELLI]))
	assert_eq(Array(e.ticks), [1])
	assert_true(bool(e.arrived))
	assert_eq(a.order, Army.ORDER_HOLD, "from summer it holds at Vercelli")


func test_c_across_the_little_st_bernard_waits_for_spring() -> void:
	_g.turn = AUTUMN_1480
	var a := ArmyFixture.army(_g, SAV, VERCELLI, 0, 2, SPRING_1480)
	assert_true(bool(Movement.march(_g, {"army": a.id, "goal": AOSTA, "tag": SAV}).ok))
	var route: Array[Vector2i] = []
	for i: int in a.route:
		route.append(_g.map.hex_of(i))
	var expected := _path([TURIN, Vector2i(5, 8), Vector2i(4, 7), SADDLE, AOSTA])
	assert_eq(route, expected, "the 15-point route by Turin and the Little St Bernard")
	MovementPhase.season(_g)
	assert_eq(a.hex, SADDLE, "autumn walks ten points to the saddle; the 5-point step waits")
	_g.turn = WINTER_1480
	MovementPhase.season(_g)
	assert_eq(a.hex, SADDLE, "winter: the pass edge is closed by snow")
	assert_eq(a.waiting, Movement.WHY_WINTER)
	_g.turn = SPRING_1481
	MovementPhase.season(_g)
	assert_eq(a.hex, AOSTA, "spring 1481 crosses the pass edge")
	assert_eq(a.order, Army.ORDER_HOLD)
	var walk := _moved(a.id)
	assert_eq(walk.size(), 2, "one walk in autumn and one in spring")


func test_d_the_mont_cenis_saddle_is_reached_in_summer() -> void:
	var a := ArmyFixture.army(_g, SAV, TURIN, 0, 2, SPRING_1480)
	assert_true(bool(Movement.march(_g, {"army": a.id, "goal": MONT_CENIS, "tag": SAV}).ok))
	MovementPhase.season(_g)
	assert_eq(a.hex, TURIN, "musters in spring")
	_g.turn = SUMMER_1480
	MovementPhase.season(_g)
	assert_eq(a.hex, MONT_CENIS, "eleven points: Susa 2, the saddle 9")
	var e: Dictionary = _moved(a.id)[0]
	assert_eq(e.path, _path([TURIN, SUSA, MONT_CENIS]))
	assert_eq(Array(e.ticks), [1, 2])
	assert_true(bool(e.arrived))


func _path(hexes: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for h: Variant in hexes:
		out.append(h as Vector2i)
	return out
