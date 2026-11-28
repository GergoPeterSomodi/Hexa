## Multi-leg marches (docs/architecture/moves-build-spec.md R63 to R66, R70, R71; plan MV19): the round trip of a march with `via`
## through the action log's saved form and Replay.run (proved first); the check and the act agree for `via` (a bad leg refused
## with its prefix, too many stops, a stop equal to the point before it); the route joined from the legs; the walk passes a stop
## without halting; a re-plan goes through the next stop; a stop that cannot be reached halts with the words and Continue resumes;
## halt once keeps and twice clears `via`; save, load, save equal; the digest covers `via`; GameDefs.max_stops is validated.
## North Italy's 1480 game (ArmyFixture: Savoy's own land by Turin). Every case names its planted fault (P).
extends GutTest

const SAV := &"SAV"
const TURIN := Vector2i(5, 9)
const SUSA := Vector2i(4, 9)
const VERCELLI := Vector2i(6, 9)
## Two steps south-west of Turin: the plain route goes by (5, 10), never by Susa or Vercelli.
const PINEROLO := Vector2i(4, 10)
const SOUTH := Vector2i(5, 10)
const NORTH := Vector2i(3, 7)
const FAR_SOUTH := Vector2i(5, 12)
## Twenty move points east of Turin: a stop that a fresh army cannot reach in one season.
const FAR_EAST := Vector2i(9, 10)
const SUMMER_1480 := 2

var _g: Game


func before_each() -> void:
	_g = ArmyFixture.game()
	_g.turn = SUMMER_1480
	Movement.clear_test_hostility()


func after_each() -> void:
	Movement.clear_test_hostility()


func _sav(hex: Vector2i = TURIN) -> Army:
	return ArmyFixture.army(_g, SAV, hex, 0, 2)


func _args(a: Army, goal: Vector2i, via: Array) -> Dictionary:
	return {"army": a.id, "goal": goal, "tag": SAV, "via": via}


func _idx(hexes: Array[Vector2i]) -> PackedInt32Array:
	var out := PackedInt32Array()
	for h: Vector2i in hexes:
		out.append(_g.map.index_of(h))
	return out


func _sea() -> Vector2i:
	for i: int in _g.map.hex_count():
		if _g.map.land[i] != 1:
			return _g.map.hex_of(i)
	return Army.NO_HEX


## The path of the last unit_moved of the army.
func _last_path(id: int) -> Array:
	var out: Array = []
	for e: Dictionary in _g.events:
		if str(e.get("kind", "")) == "unit_moved" and int(e.get("army", -1)) == id:
			out = e["path"]
	return out


## True when `via` is found on `route` in order (invariant I9's rule).
func _in_order(via: PackedInt32Array, route: PackedInt32Array) -> bool:
	var k := 0
	for h: int in route:
		if k < via.size() and h == via[k]:
			k += 1
	return k == via.size()


# --- R70, R71: the log round trip (first) ---------------------------------------------------------------------------------


func test_a_march_with_via_round_trips_through_the_saved_log_and_replays_to_the_live_digest() -> void:
	_g = ArmyFixture.game()  # nothing set outside the log: the replay starts from the same game
	assert_true(_g.dev_money(SAV, 20000))
	var raised := ArmyFixture.raise_now(_g, {"hex": TURIN, "kind": 0, "count": 2, "tag": SAV})
	assert_true(bool(raised.ok), str(raised.get("reason", "")))
	assert_true(bool(Season.run(_g).ok), "the raise musters a season")
	var a := Armies.of_country(_g, SAV)[0]
	var via: Array[Vector2i] = [NORTH]
	var res := _g.act("march", _args(a, FAR_SOUTH, via))
	assert_true(bool(res.ok), str(res.get("reason", "")))
	assert_true(bool(Season.run(_g).ok))
	var record: Dictionary = {}
	for r: Dictionary in _g.action_log:
		if r.action == "march":
			record = r
	assert_eq((record.args as Dictionary).get("via"), [NORTH], "the log record keeps the stops as hexes")
	# the saved form of the log (a save's body keeps it with var_to_bytes) read back, then replayed
	var saved: Array = bytes_to_var(var_to_bytes(_g.action_log))
	var log: Array[Dictionary] = []
	for r: Variant in saved:
		log.append(r as Dictionary)
	var again := Replay.run(_g.map, _g.defs, _g.scenario.id, _g.seed_value, log)
	assert_eq(again.digest(), _g.digest(), "P: the replay of a log with a multi-leg march gives another digest")
	var b := Armies.by_id(again, a.id)
	assert_eq([b.hex, b.goal, b.via], [a.hex, a.goal, a.via], "the replayed army stands, aims and passes alike")
	# P: the same log with the stop left out replays to another game
	var cut: Array[Dictionary] = []
	for r: Dictionary in log:
		var copy := r.duplicate(true)
		if copy.action == "march":
			(copy.args as Dictionary).erase("via")
		cut.append(copy)
	assert_ne(Replay.run(_g.map, _g.defs, _g.scenario.id, _g.seed_value, cut).digest(), _g.digest(), "P: a record that loses via")


# --- R63: the check and the act agree ----------------------------------------------------------------------------------


func test_the_check_and_the_act_agree_for_via() -> void:
	var a := _sav()
	var sea := _sea()
	var cases: Array = [
		[[SUSA, sea], "Point 2: armies cannot walk on water"],
		[[SUSA, SUSA], "Point 2: " + MarchVia.SAME_AS_BEFORE_TEXT],
		[[TURIN], "Point 1: " + MarchVia.SAME_AS_ARMY_TEXT],
		[[SUSA, Vector2i(-5, 3)], "Point 2: that is off the map"],
		[[NORTH, PINEROLO], "The goal: " + MarchVia.SAME_AS_BEFORE_TEXT],
		["Susa", MarchVia.BAD_STOPS_TEXT],
	]
	for c: Array in cases:
		var args := {"army": a.id, "goal": PINEROLO, "tag": SAV, "via": c[0]}
		var before := _g.digest()
		var check := _g.check("march", args)
		assert_false(bool(check.ok), "P: a bad leg accepted: %s" % str(c[0]))
		assert_eq(str(check.reason), c[1])
		var res := _g.act("march", args)
		assert_false(bool(res.ok), "the act refuses as the check")
		assert_eq(str(res.reason), c[1])
		assert_eq(_g.digest(), before, "a refused march changes nothing")
	var many: Array[Vector2i] = []
	for k: int in _g.defs.max_stops + 1:
		many.append(SUSA if k % 2 == 0 else SOUTH)
	assert_eq(str(_g.check("march", _args(a, PINEROLO, many)).reason), MarchVia.TOO_MANY_TEXT % _g.defs.max_stops,
		"P: more than max_stops accepted")
	var ok: Array[Vector2i] = [SUSA]
	assert_true(bool(_g.check("march", _args(a, PINEROLO, ok)).ok), "a good stop")
	assert_true(bool(_g.act("march", _args(a, PINEROLO, ok)).ok), "and the act agrees")


func test_no_via_is_todays_march_word_for_word() -> void:
	var a := _sav()
	var sea := _sea()
	for goal: Vector2i in [PINEROLO, sea, TURIN, FAR_SOUTH]:
		var plain := _g.check("march", {"army": a.id, "goal": goal, "tag": SAV})
		var empty := _g.check("march", _args(a, goal, []))
		assert_eq(empty, plain, "an empty via gives today's verdict to %s" % goal)


# --- R63, R64: the joined route and the stored stops ----------------------------------------------------------------------


func test_the_route_is_the_legs_joined_and_the_stops_are_stored() -> void:
	var a := _sav()
	var via: Array[Vector2i] = [NORTH]
	var v := MarchVia.legs_verdict(_g, a, SAV, via, FAR_SOUTH)
	assert_true(bool(v.ok), str(v.reason))
	var legs: Array = v.legs
	assert_eq(legs.size(), 2)
	var joined := PackedInt32Array()
	var cost := 0
	for leg: Dictionary in legs:
		joined.append_array(leg.hexes as PackedInt32Array)
		cost += int(leg.cost)
	assert_eq((v.plan as Dictionary).hexes, joined, "the route is the legs' hexes in order")
	assert_eq(int((v.plan as Dictionary).cost), cost, "the cost is the sum of the legs")
	assert_eq([legs[0].from, legs[0].to, legs[1].from, legs[1].to], [TURIN, NORTH, NORTH, FAR_SOUTH])
	var res := _g.act("march", _args(a, FAR_SOUTH, via))
	assert_true(bool(res.ok))
	assert_true(a.hex != NORTH or a.via.is_empty(), "a stop stood on is passed")
	assert_true(_in_order(a.via, a.route), "the stops left lie ahead on the route in order (I9)")
	assert_eq(a.goal, FAR_SOUTH)


# --- R65: the walk --------------------------------------------------------------------------------------------------------


func test_the_walk_passes_a_stop_without_halting() -> void:
	var a := _sav()
	var via: Array[Vector2i] = [SUSA]
	var res := _g.act("march", _args(a, PINEROLO, via))
	assert_true(bool(res.ok), str(res.get("reason", "")))
	var path := _last_path(a.id)
	assert_true(path.has(SUSA), "P: a walk that skips a stop: %s" % str(path))
	assert_eq(a.hex, PINEROLO, "P: an army that halts at a stop with points left")
	assert_eq([a.order, a.goal, a.via], [Army.ORDER_HOLD, Army.NO_HEX, PackedInt32Array()], "arrived: hold, no stops")
	assert_eq(StringName((res.walk as Dictionary).stopped), WalkNow.ARRIVED)
	assert_gt(int((res.walk as Dictionary).points), 0, "points left after passing the stop")


func test_a_long_march_keeps_its_stops_left_and_walks_on_next_season() -> void:
	var a := _sav()
	var via: Array[Vector2i] = [FAR_EAST]
	assert_true(bool(_g.act("march", _args(a, PINEROLO, via)).ok))
	assert_eq(a.order, Army.ORDER_MARCH, "the rest of the route stands")
	assert_true(_in_order(a.via, a.route))
	for _s: int in 6:
		if a.order != Army.ORDER_MARCH:
			break
		assert_true(bool(Season.run(_g).ok))
		assert_true(_in_order(a.via, a.route), "the stops left stay ahead (I9)")
	assert_eq(a.hex, PINEROLO, "it arrives in later seasons")
	assert_true(a.via.is_empty())
	var visited := false
	for e: Dictionary in _g.events:
		if str(e.get("kind", "")) == "unit_moved" and int(e.get("army", -1)) == a.id and (e.path as Array).has(FAR_EAST):
			visited = true
	assert_true(visited, "P: a march that never passed its stop")


func test_a_replan_goes_through_the_next_stop() -> void:
	var a := _sav()
	# a stored route whose first step is not next to the army: the walk re-plans from where it stands (MAX_REPLANS)
	Armies.set_order(_g, a, Army.ORDER_MARCH, PINEROLO, PackedInt32Array([_g.map.index_of(PINEROLO)]),
		PackedInt32Array([_g.map.index_of(VERCELLI)]))
	_g.version += 1
	var walk := WalkNow.walk(_g, a)
	var path := _last_path(a.id)
	assert_true(path.has(VERCELLI), "P: a re-plan that skips a stop: %s" % str(path))
	assert_eq(a.hex, PINEROLO, str(walk))
	var r := MarchVia.route_through(_g, SAV, TURIN, PackedInt32Array([_g.map.index_of(VERCELLI)]), PINEROLO, 12)
	assert_true(bool(r.ok))
	assert_true(MarchVia.hexes_of(_g, r.hexes).has(VERCELLI), "route_through passes the stop")


func test_an_unreachable_stop_halts_with_the_words_and_continue_resumes() -> void:
	var a := _sav()
	var other: StringName = &""
	for c: Country in _g.countries:
		if c.tag != SAV and not Wars.at_war(_g, SAV, c.tag):
			other = c.tag
			break
	var blocker := ArmyFixture.army(_g, other, VERCELLI, 0, 1)
	var via: Array[Vector2i] = [VERCELLI]
	var res := _g.act("march", _args(a, PINEROLO, via))
	assert_true(bool(res.ok), str(res.get("reason", "")))
	assert_eq(a.hex, TURIN, "the step onto the held stop is not taken")
	assert_eq(a.halt_why, Movement.WHY_BLOCKED)
	assert_ne(a.halt_text, "", "the halt's words")
	assert_eq([a.order, a.goal, a.via], [Army.ORDER_NONE, PINEROLO, PackedInt32Array([_g.map.index_of(VERCELLI)])],
		"halted: the goal and the stops kept")
	Armies.remove(_g, blocker)
	_g.version += 1
	var go := _g.act("continue_march", {"army": a.id, "tag": SAV})
	assert_true(bool(go.ok), str(go.get("reason", "")))
	assert_true(_last_path(a.id).has(VERCELLI), "Continue re-plans through the kept stop")
	assert_eq(a.hex, PINEROLO)


# --- R64: halt ------------------------------------------------------------------------------------------------------------


func test_halt_once_keeps_and_twice_clears_via() -> void:
	var a := _sav()
	var via: Array[Vector2i] = [FAR_EAST]
	assert_true(bool(_g.act("march", _args(a, PINEROLO, via)).ok))
	assert_eq(a.order, Army.ORDER_MARCH)
	var kept := a.via.duplicate()
	assert_false(kept.is_empty(), "the stop is not reached in the first season")
	assert_true(bool(_g.act("halt", {"army": a.id, "tag": SAV}).ok))
	assert_eq([a.order, a.goal, a.via], [Army.ORDER_NONE, PINEROLO, kept], "P: a halt that drops the stops")
	assert_true(bool(_g.act("halt", {"army": a.id, "tag": SAV}).ok))
	assert_eq([a.order, a.goal, a.via], [Army.ORDER_HOLD, Army.NO_HEX, PackedInt32Array()], "P: a via left after a hold")


func test_a_plain_march_gives_no_via() -> void:
	var a := _sav()
	var via: Array[Vector2i] = [FAR_EAST]
	assert_true(bool(_g.act("march", _args(a, PINEROLO, via)).ok))
	assert_false(a.via.is_empty(), "the march through a stop keeps it")
	var plain := _g.act("march", {"army": a.id, "goal": TURIN if a.hex != TURIN else SOUTH, "tag": SAV})
	assert_true(bool(plain.ok), str(plain.get("reason", "")))
	assert_true(a.via.is_empty(), "P: a plain march that keeps the old stops")


# --- R70: saves and the digest --------------------------------------------------------------------------------------------


func test_save_load_save_is_equal_with_stops_left() -> void:
	var a := _sav()
	var via: Array[Vector2i] = [FAR_EAST]
	assert_true(bool(_g.act("march", _args(a, PINEROLO, via)).ok))
	var bytes := var_to_bytes(Snapshot.of(_g))
	var restored := Snapshot.restore(bytes_to_var(bytes) as Dictionary, _g.map, _g.defs)
	assert_eq(restored.problem, "")
	var back := restored.game as Game
	assert_eq(back.digest(), _g.digest(), "the same digest")
	assert_eq(Armies.by_id(back, a.id).via, a.via, "P: stops lost on load")
	assert_eq(var_to_bytes(Snapshot.of(back)), bytes, "save, load, save: byte-equal")


func test_the_digest_covers_via_and_a_bad_via_does_not_load() -> void:
	var a := _sav()
	Armies.set_order(_g, a, Army.ORDER_MARCH, PINEROLO, PackedInt32Array([_g.map.index_of(SOUTH), _g.map.index_of(PINEROLO)]))
	var base := _g.digest()
	Armies.set_order(_g, a, Army.ORDER_MARCH, PINEROLO, PackedInt32Array([_g.map.index_of(SOUTH), _g.map.index_of(PINEROLO)]),
		PackedInt32Array([_g.map.index_of(SOUTH)]))
	assert_ne(_g.digest(), base, "P: via outside the digest")
	var d := Armies.to_dict(_g)
	var bad: Dictionary = d.duplicate(true)
	bad["list"][0]["via"] = [_g.map.hex_count() + 3]
	assert_eq(Armies.from_dict(bad, _g), Armies.PROBLEM_BODY, "P: a stop off the map loads")
	var many: Dictionary = d.duplicate(true)
	var list: Array = []
	for k: int in _g.defs.max_stops + 1:
		list.append(_g.map.index_of(SOUTH))
	many["list"][0]["via"] = list
	assert_eq(Armies.from_dict(many, _g), Armies.PROBLEM_BODY, "P: more than max_stops loads")
	assert_eq(Armies.from_dict(d.duplicate(true), _g), "", "the good body loads")


func test_set_order_with_no_goal_keeps_no_stops() -> void:
	var a := _sav()
	Armies.set_order(_g, a, Army.ORDER_HOLD, Army.NO_HEX, PackedInt32Array(), PackedInt32Array([_g.map.index_of(SOUTH)]))
	assert_true(a.via.is_empty(), "P: stops with no goal (I9)")


func test_max_stops_is_validated() -> void:
	var defs := ArmyFixture.defs()
	assert_eq(defs.max_stops, 6, "D36: six stops")
	for bad: int in [0, -1, 13]:
		defs.max_stops = bad
		assert_true(defs.validate().has("max_stops is %d, expected 1 to 12" % bad), "max_stops %d refused" % bad)
	defs.max_stops = 6
	assert_eq(defs.validate(), [] as Array[String])


func test_checks_and_previews_draw_no_luck() -> void:
	var a := _sav()
	var luck := var_to_bytes(_g.luck.to_dict())
	var via: Array[Vector2i] = [NORTH, VERCELLI]
	for _k: int in 50:
		_g.check("march", _args(a, FAR_SOUTH, via))
		MovePreview.via(_g, SAV, a.id, via, FAR_SOUTH)
	assert_eq(var_to_bytes(_g.luck.to_dict()), luck, "R71: no luck in a check or a preview")
