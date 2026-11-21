## Reminders.winter_passes (docs/architecture/m6-build-spec.md 4.15 and 4.13 (c); L12): in Autumn a march whose walk stops short of
## its goal and waits in Winter at a pass that winter closes is named. Positive: Savoy's army at Turin marching over the Little St
## Bernard (route (5, 8), (4, 7), (3, 7), (3, 8); the Autumn walk reaches (3, 7) and winter holds it there). Planted negatives: a
## march that crosses the pass this season, a march in Summer, a holding army, another country's list.
extends GutTest

const TURIN := Vector2i(5, 9)
const PASS_NEAR := Vector2i(3, 7)
const BEYOND := Vector2i(3, 8)
const SAVOY := &"SAV"


## Ends seasons until the season in play is `season` (at most a year of them).
func _to_season(g: Game, season: int) -> void:
	for _k: int in 4:
		if Calendar.season_of(g.turn) == season:
			return
		Season.run(g)


## Savoy's army at Turin, marching to the far side of the pass along the route the planner finds for it.
func _marching_from_turin(g: Game) -> Army:
	var a := ArmyFixture.army(g, SAVOY, TURIN, 0, 2)
	var route := Movement.replan(g, SAVOY, TURIN, BEYOND, Movement.mp_of(g, a))
	assert_true(bool(route["ok"]), "the planner finds the way over the pass")
	Armies.set_order(g, a, Army.ORDER_MARCH, BEYOND, route["hexes"] as PackedInt32Array)
	g.version += 1
	return a


## Savoy's army at the pass, one step from the far side: the Autumn walk crosses it this season.
func _one_step_from_the_far_side(g: Game) -> Army:
	var a := ArmyFixture.army(g, SAVOY, PASS_NEAR, 0, 2)
	var route := Movement.replan(g, SAVOY, PASS_NEAR, BEYOND, Movement.mp_of(g, a))
	Armies.set_order(g, a, Army.ORDER_MARCH, BEYOND, route["hexes"] as PackedInt32Array)
	g.version += 1
	return a


func _has_pass(g: Game) -> bool:
	return g.map.is_land(PASS_NEAR) and g.map.is_land(BEYOND) and Countries.by_tag(g, SAVOY) != null


func test_a_march_waiting_at_a_closed_pass_is_named_in_autumn() -> void:
	var g := ArmyFixture.game()
	if not _has_pass(g):
		pending("the fixture map has no Little St Bernard at (3, 7)")
		return
	_to_season(g, Calendar.AUTUMN)
	var a := _marching_from_turin(g)
	var line := Reminders.winter_passes(g, SAVOY)
	if line.is_empty():
		fail_test("the wait at the closed pass is not named")
		return
	assert_eq(int(line["severity"]), 1)
	assert_true(str(line["text"]).begins_with("Winter closes the Little St Bernard: the %s waits for spring at " % a.name),
		str(line["text"]))
	assert_eq(line["hex"], PASS_NEAR, "the army waits at (3, 7)")
	assert_eq(line["action"], [&"select_army", a.id], "the action selects the army")


func test_a_march_that_crosses_this_season_is_not_named() -> void:
	var g := ArmyFixture.game()
	if not _has_pass(g):
		pending("the fixture map has no Little St Bernard at (3, 7)")
		return
	_to_season(g, Calendar.AUTUMN)
	_one_step_from_the_far_side(g)
	assert_true(Reminders.winter_passes(g, SAVOY).is_empty(), "the walk gets over the pass in Autumn: nothing waits")


func test_no_wait_is_named_in_summer() -> void:
	var g := ArmyFixture.game()
	if not _has_pass(g):
		pending("the fixture map has no Little St Bernard at (3, 7)")
		return
	_to_season(g, Calendar.SUMMER)
	_marching_from_turin(g)
	assert_true(Reminders.winter_passes(g, SAVOY).is_empty(), "the reminder is for Autumn only")


func test_a_holding_army_is_not_named() -> void:
	var g := ArmyFixture.game()
	if not _has_pass(g):
		pending("the fixture map has no Little St Bernard at (3, 7)")
		return
	_to_season(g, Calendar.AUTUMN)
	var a := _marching_from_turin(g)
	Armies.set_order(g, a, Army.ORDER_HOLD, Army.NO_HEX, PackedInt32Array())
	g.version += 1
	assert_true(Reminders.winter_passes(g, SAVOY).is_empty(), "an army that holds is not on the march")


func test_another_country_is_not_named() -> void:
	var g := ArmyFixture.game()
	if not _has_pass(g):
		pending("the fixture map has no Little St Bernard at (3, 7)")
		return
	_to_season(g, Calendar.AUTUMN)
	_marching_from_turin(g)
	assert_true(Reminders.winter_passes(g, ArmyFixture.TAG).is_empty(), "the player's own list holds no army of Savoy")
