## The moves fixtures (docs/architecture/moves-build-spec.md 8, MV0): standing, duel and thin (tests/core/moves_fixture.gd).
## Planted faults these cases catch: a standing march that walks the army (the hex and moved_from must stay), a duel with no
## war or one declared this season, a duel whose near army is not three hexes away, an unseen army that Savoy sees, that is not
## two steps from its sight or that stands on the near army's hex, a duel that is not the same each time, and a thin that leaves
## Savoy whole or changes Milan's explored set.
extends GutTest

const SAV := MovesFixture.SAVOY
const MLO := MovesFixture.MILAN


func _home(g: Game) -> Army:
	return MovesFixture.named(g, MovesFixture.NAME_HOME)


func _near(g: Game) -> Army:
	return MovesFixture.named(g, MovesFixture.NAME_NEAR)


func _unseen(g: Game) -> Army:
	return MovesFixture.named(g, MovesFixture.NAME_UNSEEN)


## Savoy's own land two steps from `from` (the first found in neighbour order), or NO_HEX.
func _two_steps_own(g: Game, from: Vector2i) -> Vector2i:
	for d: int in 6:
		var mid := ImproveRules.neighbour(from, d)
		for e: int in 6:
			var goal := ImproveRules.neighbour(mid, e)
			if goal != from and g.map.index_of(goal) >= 0 and g.map.is_land(goal) \
					and Territory.owner_id(g, goal) == ArmyFixture.id_of(g, SAV):
				return goal
	return Army.NO_HEX


func test_duel_has_savoy_and_milan_at_war() -> void:
	var g := MovesFixture.duel()
	assert_true(Wars.at_war(g, SAV, MLO), "Savoy and Milan are at war in the duel")


func test_duel_war_is_a_season_old_and_declared_now_is_of_this_season() -> void:
	var g := MovesFixture.duel()
	assert_eq(Wars.war_between(g, SAV, MLO).start_turn, g.turn - 1, "P: a duel that shuts Milan's land (fair warning)")
	var now := MovesFixture.declared_now()
	var war := Wars.war_between(now, SAV, MLO)
	assert_eq([war.a, war.start_turn], [SAV, now.turn], "declared by Savoy this season")


func test_duel_has_the_three_named_armies_of_their_countries() -> void:
	var g := MovesFixture.duel()
	var home := _home(g)
	var near := _near(g)
	var unseen := _unseen(g)
	assert_not_null(home, "the Savoyard army is named")
	assert_not_null(near, "the near Milanese army is named")
	assert_not_null(unseen, "the unseen Milanese army is named")
	if home == null or near == null or unseen == null:
		return
	assert_eq(home.tag, SAV, "the home army belongs to Savoy")
	assert_eq(near.tag, MLO, "the near army belongs to Milan")
	assert_eq(unseen.tag, MLO, "the unseen army belongs to Milan")


func test_duel_puts_the_near_milanese_army_three_hexes_from_savoy() -> void:
	var g := MovesFixture.duel()
	var home := _home(g)
	var near := _near(g)
	if home == null or near == null:
		fail_test("the duel's armies are named")
		return
	assert_eq(ImproveRules.hex_distance(home.hex, near.hex), MovesFixture.NEAR_DISTANCE,
		"the near army is three hexes from the Savoyard army")
	assert_true(g.map.is_land(near.hex), "the near army stands on land")


func test_duel_puts_the_unseen_army_two_hexes_out_of_savoys_sight() -> void:
	var g := MovesFixture.duel()
	var unseen := _unseen(g)
	if unseen == null:
		fail_test("the unseen army is named")
		return
	assert_false(Sight.sees(g, SAV, unseen.hex), "Savoy does not see the unseen army's hex")
	var reached := false
	for d: int in 6:
		var beside := ImproveRules.neighbour(unseen.hex, d)
		if g.map.index_of(beside) < 0:
			continue
		assert_false(Sight.sees(g, SAV, beside), "no hex beside the unseen army is seen by Savoy")
		for e: int in 6:
			var far := ImproveRules.neighbour(beside, e)
			if g.map.index_of(far) >= 0 and Sight.sees(g, SAV, far):
				reached = true
	assert_true(reached, "a hex two steps from the unseen army is seen by Savoy")
	assert_ne(unseen.hex, _near(g).hex, "P: both Milanese armies on one hex")
	assert_eq(Armies.at(g, unseen.hex).size(), 1, "the unseen army stands alone")


func test_duel_is_the_same_each_time() -> void:
	var first := MovesFixture.duel()
	var second := MovesFixture.duel()
	for name: String in [MovesFixture.NAME_HOME, MovesFixture.NAME_NEAR, MovesFixture.NAME_UNSEEN]:
		var a := MovesFixture.named(first, name)
		var b := MovesFixture.named(second, name)
		assert_not_null(a, "%s is named in the first duel" % name)
		assert_not_null(b, "%s is named in the second duel" % name)
		if a != null and b != null:
			assert_eq(a.hex, b.hex, "%s stands on the same hex in both duels" % name)


func test_standing_gives_a_march_and_keeps_the_army_where_it_is() -> void:
	var g := MovesFixture.duel()
	var home := _home(g)
	if home == null:
		fail_test("the home army is named")
		return
	var goal := _two_steps_own(g, home.hex)
	assert_ne(goal, Army.NO_HEX, "Savoy has a land hex two steps from its army")
	if goal == Army.NO_HEX:
		return
	var before_hex := home.hex
	var before_from := home.moved_from
	assert_true(MovesFixture.standing(g, home, goal), "the standing march is planned")
	assert_eq(home.order, Army.ORDER_MARCH, "the army has a march order")
	assert_eq(home.goal, goal, "the goal is the one given")
	assert_gt(home.route.size(), 0, "a stored route is kept")
	assert_eq(home.route[home.route.size() - 1], g.map.index_of(goal), "the route ends at the goal")
	assert_eq(home.hex, before_hex, "nothing walks: the army stands where it stood")
	assert_eq(home.moved_from, before_from, "no move is recorded")


func test_thin_leaves_savoy_explored_at_radius_two() -> void:
	var g := MovesFixture.thin()
	var expected := FogFixture.grown(g, SAV, 2)
	var explored: PackedByteArray = Countries.by_tag(g, SAV).explored
	var n := g.map.hex_count()
	var known := 0
	var mismatches := 0
	for i: int in n:
		var bit := SightCache.bit_is(explored, i)
		if bit:
			known += 1
		if bit != SightCache.bit_is(expected, i):
			mismatches += 1
	assert_eq(mismatches, 0, "Savoy's explored set is its land sight grown by two hexes")
	assert_lt(known, n, "Savoy has not explored the whole map")
	assert_gt(known, 0, "Savoy has explored something")


func test_thin_leaves_milans_explored_set_as_the_duel_has_it() -> void:
	var thin := MovesFixture.thin()
	var whole := MovesFixture.duel()
	var a: PackedByteArray = Countries.by_tag(thin, MLO).explored
	var b: PackedByteArray = Countries.by_tag(whole, MLO).explored
	var differ := 0
	for i: int in thin.map.hex_count():
		if SightCache.bit_is(a, i) != SightCache.bit_is(b, i):
			differ += 1
	assert_eq(differ, 0, "only Savoy is thinned")


func test_thin_keeps_the_duel_armies() -> void:
	var g := MovesFixture.thin()
	var whole := MovesFixture.duel()
	for name: String in [MovesFixture.NAME_HOME, MovesFixture.NAME_NEAR, MovesFixture.NAME_UNSEEN]:
		var a := MovesFixture.named(g, name)
		var b := MovesFixture.named(whole, name)
		if a != null and b != null:
			assert_eq(a.hex, b.hex, "%s stands where the duel puts it" % name)
