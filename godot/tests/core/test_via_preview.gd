## The picture of a multi-leg march (docs/architecture/moves-build-spec.md R59, R67, R68; plan MV19): MovePreview.via gives the
## legs (from, to, hexes, cost, seasons, arrival), the total (the sum of the legs), the route through every path point in order, this
## season's leg and risks read on the whole route, a line a leg and one for the whole route; its refusals name the point and only
## what the viewer may read (thin fog); the stored route keeps the points left; the army panel's order line names them; the
## legs are kept per leg, so a new pointer hex plans only the last one. North Italy (ArmyFixture) and the thin duel. P each.
extends GutTest

const SAV := &"SAV"
const TURIN := Vector2i(5, 9)
const SUSA := Vector2i(4, 9)
const VERCELLI := Vector2i(6, 9)
const PINEROLO := Vector2i(4, 10)
const NORTH := Vector2i(3, 7)
const FAR_SOUTH := Vector2i(5, 12)
const FAR_EAST := Vector2i(9, 10)
const SUMMER_1480 := 2

var _g: Game


func before_each() -> void:
	_g = ArmyFixture.game()
	_g.turn = SUMMER_1480
	Movement.clear_test_hostility()


func _sav(hex: Vector2i = TURIN) -> Army:
	return ArmyFixture.army(_g, SAV, hex, 0, 2)


func _stops(hexes: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(hexes)
	return out


func _line_with(p: Dictionary, head: String) -> String:
	for line: Array in p.lines:
		if str(line[0]).begins_with(head):
			return str(line[0])
	return ""


func test_the_legs_and_the_total_are_the_sum_of_the_legs() -> void:
	var a := _sav()
	var p := MovePreview.via(_g, SAV, a.id, _stops([NORTH, VERCELLI]), FAR_SOUTH)
	assert_true(bool(p.verdict.ok), str(p.verdict))
	var legs: Array = p.legs
	assert_eq(legs.size(), 3)
	assert_eq([legs[0].from, legs[0].to, legs[1].from, legs[1].to, legs[2].from, legs[2].to],
		[TURIN, NORTH, NORTH, VERCELLI, VERCELLI, FAR_SOUTH], "P: a preview that skips a stop")
	var cost := 0
	var seasons := 0
	var hexes: Array[Vector2i] = []
	for leg: Dictionary in legs:
		cost += int(leg.cost)
		seasons += int(leg.seasons)
		hexes.append_array(leg.hexes)
		assert_eq((leg.hexes as Array).back(), leg.to, "a leg ends on its point")
	assert_eq(int(p.total.cost), cost, "P: a total that is not the sum of its legs")
	assert_eq(int(p.total.seasons), seasons, "the seasons of the legs add up to the whole route's")
	assert_eq(int(p.total.legs), 3)
	assert_eq(p.hexes, hexes, "the route is the legs joined")
	assert_eq(int(legs[2].arrives_turn), int(p.total.arrives_turn), "the last leg arrives with the route")
	assert_eq(int(p.arrives_turn), int(p.total.arrives_turn))
	assert_true((p.hexes as Array).has(NORTH) and (p.hexes as Array).has(VERCELLI))
	assert_eq(p.via, _stops([NORTH, VERCELLI]))
	assert_true(_line_with(p, "Leg 2: ").contains("move points"), str(p.lines))
	assert_true(_line_with(p, "Whole route: 3 legs, %d move points" % cost) != "", str(p.lines))


func test_this_seasons_leg_is_read_on_the_whole_route() -> void:
	var a := _sav()
	var p := MovePreview.via(_g, SAV, a.id, _stops([SUSA]), PINEROLO)
	var leg: Dictionary = p.leg
	assert_true((leg.hexes as Array).has(SUSA), "the leg passes the stop: %s" % str(leg.hexes))
	assert_eq(leg.end, PINEROLO, "and walks on to the goal (D29)")
	assert_eq(StringName(leg.why), MovePreview.WHY_ARRIVES)
	var res := _g.act("march", {"army": a.id, "goal": PINEROLO, "tag": SAV, "via": _stops([SUSA])})
	assert_eq(a.hex, leg.end, "the walk ends where the preview said")
	assert_eq(int((res.walk as Dictionary).points), int(leg.points_after))


func test_no_stops_is_the_plain_preview() -> void:
	var a := _sav()
	var plain := MovePreview.to(_g, SAV, a.id, PINEROLO)
	var p := MovePreview.via(_g, SAV, a.id, _stops([]), PINEROLO)
	for key: String in ["verdict", "hexes", "stops", "leg", "risks", "arrives_turn", "seasons"]:
		assert_eq(str(p[key]), str(plain[key]), key)
	assert_eq((p.legs as Array).size(), 1)


func test_a_refusal_names_the_stop_in_safe_words() -> void:
	var a := _sav()
	var sea := Army.NO_HEX
	for i: int in _g.map.hex_count():
		if _g.map.land[i] != 1:
			sea = _g.map.hex_of(i)
			break
	var p := MovePreview.via(_g, SAV, a.id, _stops([SUSA, sea]), PINEROLO)
	assert_false(bool(p.verdict.ok))
	assert_true(str(p.verdict.reason).begins_with("Point 2: "), str(p.verdict))
	assert_eq(p.kind, &"refusal")
	assert_true(str(p.lines[0][0]).begins_with("Point 2: "))
	assert_eq((p.legs as Array).size(), 0)


func test_fog_safe_words_on_the_thin_duel() -> void:
	var g := MovesFixture.thin()
	var home := MovesFixture.named(g, MovesFixture.NAME_HOME)
	var unseen := MovesFixture.named(g, MovesFixture.NAME_UNSEEN)
	var fogged := Army.NO_HEX
	var foreign := Army.NO_HEX
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] != 1 or Knowledge.discovered(g, MovesFixture.SAVOY, hex):
			continue
		var owner := Territory.owner_tag(g, hex)
		if fogged == Army.NO_HEX and bool(g.check("march", {"army": home.id, "goal": hex, "tag": MovesFixture.SAVOY}).ok):
			fogged = hex
		if owner != &"" and owner != MovesFixture.SAVOY and owner != MovesFixture.MILAN and foreign == Army.NO_HEX:
			foreign = hex
	assert_ne(fogged, Army.NO_HEX, "an undiscovered goal the army may be sent to")
	var p := MovePreview.via(g, MovesFixture.SAVOY, home.id, _stops([unseen.hex]), fogged)
	var words := str(p.lines)
	assert_false(words.contains(Words.country_the(g, MovesFixture.MILAN)) and not bool(p.verdict.ok),
		"P: a leg's refusal that names an unseen army's country")
	if foreign != Army.NO_HEX:
		var q := MovePreview.via(g, MovesFixture.SAVOY, home.id, _stops([foreign]), fogged)
		assert_false(bool(q.verdict.ok))
		assert_true(str(q.verdict.reason).begins_with("Point 1: "))
		assert_false(str(q.verdict.reason).contains(Words.country_the(g, Territory.owner_tag(g, foreign))),
			"P: a refusal that names the owner of an undiscovered stop: %s" % q.verdict.reason)
	# the leg with unmapped land is marked
	if bool(p.verdict.ok):
		var marked := false
		for leg: Dictionary in p.legs:
			marked = marked or bool(leg.fog)
		assert_true(marked, "P: a leg through unmapped land that is not marked")
		assert_true(words.contains("Unmapped land on the way."), words)


func test_the_stored_route_keeps_the_stops_left_and_the_order_line_names_them() -> void:
	var a := _sav()
	assert_true(bool(_g.act("march", {"army": a.id, "goal": PINEROLO, "tag": SAV, "via": _stops([FAR_EAST])}).ok))
	var stored := MovePreview.stored(_g, SAV, a.id)
	assert_eq(stored.via, _stops([FAR_EAST]), "R68: the stops left")
	var order := (ArmyView.panel(_g, SAV, a.id).order as Dictionary)
	assert_true(str(order.text).ends_with(" by " + Words.place(_g, FAR_EAST)), str(order.text))
	for _s: int in 6:
		if a.via.is_empty():
			break
		Season.run(_g)
	if a.order == Army.ORDER_MARCH:
		assert_eq(MovePreview.stored(_g, SAV, a.id).via, [] as Array[Vector2i], "P: a marker for a stop already passed")
	assert_false(str((ArmyView.panel(_g, SAV, a.id).order as Dictionary).text).contains(" by "), "no stop left to name")
	var foreign := ArmyView.panel(_g, &"MLO" if Countries.by_tag(_g, &"MLO") != null else &"GEN", a.id)
	assert_false(foreign.has("order"), "P: a stop shown on a foreign army")


func test_the_earlier_legs_are_planned_once_and_moving_the_pointer_plans_the_last_leg() -> void:
	var a := _sav()
	var stops := _stops([NORTH, VERCELLI])
	MovePreview.via(_g, SAV, a.id, stops, FAR_SOUTH)
	var table: Dictionary = _g.view_cache.pinned(&"via_plans", _g.version, func() -> Dictionary: return {}) as Dictionary
	var after_first := table.size()
	assert_gt(after_first, 0, "the legs from a stop are kept")
	MovePreview.via(_g, SAV, a.id, stops, PINEROLO)
	assert_eq(table.size(), after_first + 1, "a new pointer hex plans only the last leg")
	var again := MovePreview.via(_g, SAV, a.id, stops, PINEROLO)
	assert_same(again, MovePreview.via(_g, SAV, a.id, stops, PINEROLO), "the preview is kept per pointer hex")
	var digest := _g.digest()
	var version := _g.version
	for hex: Vector2i in [SUSA, NORTH, FAR_EAST]:
		MovePreview.via(_g, SAV, a.id, stops, hex)
	assert_eq([_g.digest(), _g.version], [digest, version], "the preview never changes the game")
