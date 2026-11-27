## The fog-safe verdict and the preview's walk rules (moves-build-spec.md R23, R28, R45, R57; issues #468 to #471): FogVerdict
## reads other countries' armies only on hexes the country sees, the AI's checks (Game.check through AiKnow) with it, the walk
## meets a hidden army by its own rules with fog-safe words, and MovePreview's leg cuts for room (MarchLeg.room_kept) as the walk
## does. On MovesFixture.duel() (Savoy the viewer, at war with Milan).
extends GutTest

const S := MovesFixture.SAVOY
const M := MovesFixture.MILAN
const SHAKEN_MORALE := 300
const FAR_GOAL := Vector2i(0, 3)


## The duel with Savoy's home army shaken; `hidden` false removes Milan's unseen army.
func _shaken(hidden: bool) -> Game:
	var g := MovesFixture.duel()
	if not hidden:
		Armies.remove(g, MovesFixture.named(g, MovesFixture.NAME_UNSEEN))
	var home := MovesFixture.named(g, MovesFixture.NAME_HOME)
	for u: Unit in home.units:
		Armies.set_morale(g, home, u.id, SHAKEN_MORALE)
	Sight.refresh(g)
	g.version += 1
	return g


func test_the_ais_check_of_a_shaken_army_learns_nothing_of_a_hidden_army() -> void:
	var a := _shaken(false)
	var b := _shaken(true)
	var spot := MovesFixture.named(b, MovesFixture.NAME_UNSEEN).hex
	assert_false(Sight.sees(b, S, spot), "the army is out of sight")
	var args := {"army": MovesFixture.named(a, MovesFixture.NAME_HOME).id, "goal": spot}
	var without := AiKnow.check(a, S, "march", args)
	var with := AiKnow.check(b, S, "march", args)
	assert_eq(str(with), str(without), "P: the AI's check tells of the hidden army")
	assert_true(bool(with.ok), "the march is accepted: %s" % str(with))


## The walk then meets the hidden army by its own rules: it never steps onto it, and its words name only what Savoy sees after it.
func test_the_walk_meets_the_hidden_army_by_its_own_rules() -> void:
	var g := _shaken(true)
	var spot := MovesFixture.named(g, MovesFixture.NAME_UNSEEN).hex
	var home := MovesFixture.named(g, MovesFixture.NAME_HOME)
	var res := g.act("march", {"army": home.id, "goal": spot, "tag": S})
	assert_true(bool(res.ok), str(res))
	var walk := res.walk as Dictionary
	assert_ne(walk.to, spot, "a shaken army does not step onto the enemy")
	assert_true(StringName(walk.stopped) in [Movement.WHY_SHAKEN, Movement.WHY_SIGHTED, WalkNow.POINTS, WalkNow.ZOC],
		"a fog-safe stop: %s (%s)" % [walk.stopped, walk.text])
	for h: Vector2i in MovePreview.named_hexes(str(walk.text)):
		assert_true(Sight.sees(g, S, h), "the words name a hex in sight: %s" % walk.text)


func test_the_goal_check_reads_no_army_on_an_unseen_hex() -> void:
	var g := MovesFixture.duel()
	var unseen := MovesFixture.named(g, MovesFixture.NAME_UNSEEN)
	var home := MovesFixture.named(g, MovesFixture.NAME_HOME)
	assert_eq(FogVerdict.stand(g, home, S, unseen.hex, home.units.size(), PackedInt32Array()), "", "unseen: the room alone")
	var beside := Army.NO_HEX
	for d: int in 6:
		var n := g.map.neighbour(home.hex, d)
		if g.map.index_of(n) >= 0 and g.map.is_land(n) and Armies.at(g, n).is_empty() and Sight.sees(g, S, n):
			beside = n
			break
	assert_ne(beside, Army.NO_HEX, "a free land hex in sight beside the home army")
	ArmyFixture.army(g, M, beside, 0, 1)
	for u: Unit in home.units:
		Armies.set_morale(g, home, u.id, SHAKEN_MORALE)
	assert_string_starts_with(FogVerdict.stand(g, home, S, beside, home.units.size(), PackedInt32Array()),
		"too shaken to attack", "seen: the attack's check")


## R23 and issue #470: a leg whose end is full of Savoy's companies ends on the last hex with room, as the walk does.
func test_the_preview_cuts_the_leg_for_room_as_the_walk_does() -> void:
	var g := MovesFixture.duel()
	var home := MovesFixture.named(g, MovesFixture.NAME_HOME)
	var first := MovePreview.leg_of(g, S, home.id, FAR_GOAL)
	assert_eq(StringName(first.why), MovePreview.WHY_POINTS, "the long march stops for its points")
	var end: Vector2i = first.end
	ArmyFixture.army(g, S, end, 0, g.defs.stack_limit)
	Sight.refresh(g)
	g.version += 1
	var leg := MovePreview.leg_of(g, S, home.id, FAR_GOAL)
	assert_eq(StringName(leg.why), MovePreview.WHY_ROOM)
	assert_eq((leg.hexes as Array).size(), (first.hexes as Array).size() - 1, "one hex short")
	assert_eq(int(leg.points_after), int(leg.points_before) - int(leg.cost), "the points of the kept steps")
	var lines := str(MovePreview.to(g, S, home.id, FAR_GOAL).lines)
	assert_string_contains(lines, "no room for more of your companies")
	var res := g.act("march", {"army": home.id, "goal": FAR_GOAL, "tag": S})
	var walk := res.walk as Dictionary
	assert_eq(StringName(walk.stopped), WalkNow.ROOM)
	assert_eq(walk.to, leg.end, "the walk ends where the preview said")
	assert_eq(int(walk.points), int(leg.points_after))


## R28 and issue #471: a contact the walk is refused keeps the preview's points and gives the walk's halt and its words (no battle
## risk, no "season is over").
func test_a_refused_contact_keeps_the_points_and_names_the_halt() -> void:
	var g := MovesFixture.duel()
	Armies.remove(g, MovesFixture.named(g, MovesFixture.NAME_NEAR))
	var home := MovesFixture.named(g, MovesFixture.NAME_HOME)
	for u: Unit in home.units:
		Armies.set_morale(g, home, u.id, SHAKEN_MORALE)
	g.version += 1
	var goal := Army.NO_HEX
	var way := Army.NO_HEX
	for i: int in g.map.hex_count():
		var h := g.map.hex_of(i)
		var plan := Movement.plan(g, home, h)
		if ImproveRules.hex_distance(h, home.hex) < 3 or not bool(plan.ok) or (plan.hexes as PackedInt32Array).size() < 3:
			continue
		var first := g.map.hex_of((plan.hexes as PackedInt32Array)[0])
		if Sight.sees(g, S, first) and Armies.at(g, first).is_empty() and Movement.open_to(g, M, first) 				and bool(g.check("march", {"army": home.id, "goal": h, "tag": S}).ok):
			goal = h
			way = first
			break
	assert_ne(goal, Army.NO_HEX, "a march past a hex in sight")
	ArmyFixture.army(g, M, way, 0, 1)
	Sight.refresh(g)
	g.version += 1
	var p := MovePreview.to(g, S, home.id, goal)
	var leg: Dictionary = p.leg
	assert_eq(StringName(leg.why), Movement.WHY_SHAKEN)
	assert_eq((leg.hexes as Array).size(), 0, "it stops before the enemy")
	assert_eq(int(leg.points_after), int(leg.points_before), "a halt keeps the points")
	assert_string_starts_with(str(leg.text), "too shaken to attack")
	var lines := str(p.lines)
	assert_string_contains(lines, "too shaken to attack")
	assert_false(str(p.risks).contains("opens a battle"), "no battle risk: %s" % str(p.risks))
