## AiForces (core/ai/ai_forces.gd; docs/architecture/m8-build-spec.md 4.8, 5.5, 9, D19 to D21): the goal of men per temperament and
## threat, the upkeep room and the first company, the mix's want and the kind order, the place order, the companies raised a
## season, disbanding both ways, the posts (peace_army) and the merges. Each step is called alone on a game this test builds
## (Milan's seat, Genoa the player), so the other steps' work never enters; every planted fault (P) is a situation the rule
## must refuse, made on its own copy of the definitions (the temperament, the AI numbers and the unit kinds are duplicated first).
@warning_ignore_start("integer_division")
extends GutTest

const SEAT := AiFixture.MILAN

var _g: Game
var _hook: AiTurn
var _acts: Array[Dictionary] = []


func before_each() -> void:
	_g = ArmyFixture.game()
	_acts = []
	_hook = AiFixture.solo(_g, SEAT)
	_hook.judge = func(t: StringName, action: String, args: Dictionary, _v: Dictionary, _r: Dictionary) -> void:
		_acts.append({"tag": t, "action": action, "args": args})


# ----- helpers ---------------------------------------------------------------------------------------------------------


func _brief() -> AiBrief:
	return AiBrief.make(_g, SEAT)


## A copy of the seat's temperament that the test may change, put in the game's own definitions.
func _temper() -> AiTemperDef:
	var key := AiPlayers.temper_of(_g, SEAT).key
	var copy := _g.defs.temper(key).duplicate() as AiTemperDef
	var list: Array[AiTemperDef] = []
	for t: AiTemperDef in _g.defs.tempers:
		list.append(copy if t.key == key else t)
	_g.defs.tempers = list
	return copy


## A copy of the AI numbers that the test may change.
func _ai() -> AiDef:
	_g.defs.ai = _g.defs.ai.duplicate() as AiDef
	return _g.defs.ai


func _country() -> Country:
	return Countries.by_tag(_g, SEAT)


func _rich() -> void:
	var c := _country()
	c.treasury = 1000000
	for i: int in c.stock.size():
		c.stock[i] = 1000


## `count` towns (level 3, 20,000 people) on the seat's land, the first land hexes whose six neighbours are its own and that are
## not next to one another; their hexes.
func _towns(count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in AiKnow.land_of(_g, SEAT):
		var hex := AiKnow.hex_of(_g, i)
		var fits := _g.map.is_land(hex)
		for d: int in 6:
			var beside := ImproveRules.neighbour(hex, d)
			fits = fits and _g.map.is_land(beside) and AiKnow.owner_of(_g, beside) == SEAT
		for other: Vector2i in out:
			fits = fits and AiKnow.hex_distance(hex, other) > 2
		if fits:
			ArmyFixture.town(_g, hex, 3, 20000)
			out.append(hex)
			if out.size() == count:
				break
	assert_eq(out.size(), count, "the seat has room for the towns")
	return out


## An army of the seat on `hex` of `count` pikemen (the id of the first one is the kind 0), made through the door.
func _army(hex: Vector2i, count: int = 1, kind: int = 0) -> Army:
	return ArmyFixture.army(_g, SEAT, hex, kind, count)


func _companies() -> int:
	var n := 0
	for a: Army in AiKnow.own_armies(_g, SEAT):
		n += a.units.size()
	return n


func _kinds_raised() -> Array[int]:
	var out: Array[int] = []
	for a: Army in AiKnow.own_armies(_g, SEAT):
		for u: Unit in a.units:
			out.append(u.kind)
	return out


func _acts_of(action: String) -> Array[Dictionary]:
	return _acts.filter(func(a: Dictionary) -> bool: return a["action"] == action)


## Runs the forces step alone on a fresh brief.
func _forces(brief: AiBrief = null) -> AiBrief:
	var b := brief if brief != null else _brief()
	AiForces.forces(_hook, _g, b, 0)
	return b


## The step names the forces step appended to the hook's queue, in order.
func _pushed() -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in _hook._queue:
		out.append("%s %d" % [row["name"], row["arg"]])
	return out


# ----- the goal of men ---------------------------------------------------------------------------------------------------


func test_goal_men_is_the_temperaments_share_of_the_people_and_rises_at_war() -> void:
	var t := _temper()
	var b := _brief()
	assert_eq(b.threats, [] as Array[StringName], "1480 starts with no armies: no threat")
	assert_eq(b.goal_men, maxi(b.ai.min_army_men, b.people * t.army_permille / 1000), "at peace")
	assert_gt(b.people, 0)
	t.army_permille = 50
	t.war_army_permille = 90
	b = _brief()
	assert_eq(b.goal_men, maxi(b.ai.min_army_men, b.people * 50 / 1000), "a plain share of the people")
	WarFixture.at_war(_g, SEAT, AiFixture.VENICE)
	b = _brief()
	assert_eq(b.goal_men, maxi(b.ai.min_army_men, b.people * 90 / 1000), "at war: the war share")
	t.army_permille = 0
	t.war_army_permille = 0
	assert_eq(_brief().goal_men, _g.defs.ai.min_army_men, "never under the floor of men")


func test_goal_men_rises_under_threat_from_a_banded_neighbour() -> void:
	var t := _temper()
	t.army_permille = 50
	t.war_army_permille = 90
	var neighbour := AiKnow.neighbours(_g, SEAT)[0]
	var hex := AiFixture.land_hex(_g, neighbour)
	WarFixture.army_at(_g, neighbour, hex, 8)
	Sight.refresh(_g)
	var b := _brief()
	if AiKnow.men_of(_g, SEAT, neighbour) < 0:
		pending("the neighbour's men are not known to the seat on this map")
		return
	assert_true(b.threats.has(neighbour) or AiKnow.men_of(_g, SEAT, neighbour) * 1000 <= b.ai.min_army_men * b.ai.threat_permille,
		"a neighbour over the threat share is a threat")
	if b.threats.has(neighbour):
		assert_eq(b.goal_men, maxi(b.ai.min_army_men, b.people * 90 / 1000), "a threat: the war share")


# ----- raising: the money --------------------------------------------------------------------------------------------------


func test_the_first_company_is_allowed_whatever_the_room_the_second_is_not() -> void:
	_towns(2)
	_rich()
	var b := _brief()
	b.goal_men = 100000
	b.army_room = 0
	_forces(b)
	assert_eq(_companies(), 1, "the first company comes without room; the second would pass the upkeep room")
	assert_eq(_acts_of("raise").size(), 1)


func test_p_an_upkeep_room_that_fits_two_lets_the_second_company_in() -> void:
	_towns(2)
	_rich()
	var b := _brief()
	b.goal_men = 100000
	b.army_room = 100000
	_forces(b)
	assert_eq(_companies(), _g.defs.ai.raises_peace, "with room the season's cap is raised")


func test_the_room_counts_the_upkeep_after_the_company() -> void:
	_towns(2)
	_rich()
	var b := _brief()
	b.goal_men = 100000
	var first := _g.defs.unit_def(0).upkeep
	b.army_room = first + _g.defs.unit_def(0).upkeep - 1
	_army(AiKnow.settlements(_g, SEAT)[0])
	_forces(b)
	assert_eq(_companies(), 1, "one company stands (upkeep %d) and one more would be over the room %d" % [first, b.army_room])
	b.army_room = AiKnow.army_upkeep(_g, SEAT) + _g.defs.unit_def(0).upkeep
	_forces(b)
	assert_gt(_companies(), 1, "room for exactly one more: raised")


func test_nothing_is_raised_when_the_treasury_would_fall_under_the_reserve() -> void:
	_towns(2)
	_rich()
	var b := _brief()
	b.goal_men = 100000
	b.army_room = 100000
	var cost := _g.defs.unit_def(0).cost
	var cheapest := cost
	for ud: UnitDef in _g.defs.units:
		cheapest = mini(cheapest, ud.cost)
	b.reserve = 5000
	_country().treasury = b.reserve + cheapest - 1
	_forces(b)
	assert_eq(_companies(), 0, "T - cost under the reserve: no raise")
	_country().treasury = b.reserve + cost + 100
	_forces(b)
	assert_gt(_companies(), 0, "T - cost over the reserve: raised")


func test_p_at_war_the_reserve_is_halved() -> void:
	_towns(2)
	_rich()
	WarFixture.at_war(_g, SEAT, AiFixture.VENICE)
	var b := _brief()
	b.goal_men = 100000
	b.army_room = 100000
	b.reserve = 1000
	_country().treasury = 500 + 100
	_forces(b)
	assert_gt(_companies(), 0, "at war R / 2 = 500: 600 - cost keeps it")
	_g = ArmyFixture.game()
	_hook = AiFixture.solo(_g, SEAT)
	_towns(2)
	_rich()
	b = _brief()
	b.goal_men = 100000
	b.army_room = 100000
	b.reserve = 1000
	_country().treasury = 500 + 100
	_forces(b)
	assert_eq(_companies(), 0, "at peace the whole reserve: 600 - cost is under 1000")


func test_no_raise_once_the_men_reach_the_goal() -> void:
	_towns(2)
	_rich()
	var b := _brief()
	b.goal_men = 500
	b.army_room = 100000
	_forces(b)
	assert_eq(_companies(), 1, "one company of 500 men reaches a goal of 500")
	assert_eq(AiKnow.men(_g, SEAT), 500)


# ----- raising: the kinds and the places -------------------------------------------------------------------------------------


func test_the_mix_wants_by_share_and_the_kinds_are_ordered_by_want_then_id() -> void:
	var t := _temper()
	t.mix = PackedInt32Array([550, 350, 100, 0])
	var b := _brief()
	assert_eq(AiForces.kind_order(_g, b, {}, false), [0, 1, 2] as Array[int], "no company yet: the share itself")
	assert_eq(AiForces.kind_order(_g, b, {0: 1}, false), [1, 2, 0] as Array[int], "want = mix x (n + 1) - 1000 x n of the kind")
	assert_eq(AiForces.kind_order(_g, b, {0: 1, 1: 1, 2: 1}, false), [0, 1, 2] as Array[int], "wants 550x4-1000 = 1200, 400, 400 ... ties by kind id")
	t.mix = PackedInt32Array([500, 400, 50, 50])
	b = _brief()
	assert_eq(AiForces.kind_order(_g, b, {}, false), [0, 1, 2] as Array[int], "bombards only at war")
	assert_eq(AiForces.kind_order(_g, b, {}, true), [0, 1, 2, 3] as Array[int], "at war the bombards are wanted too")
	t.mix = PackedInt32Array([250, 250, 250, 250])
	assert_eq(AiForces.kind_order(_g, _brief(), {}, true), [0, 1, 2, 3] as Array[int], "equal wants: kind id order")


func test_the_company_raised_is_the_one_most_wanted() -> void:
	var t := _temper()
	t.mix = PackedInt32Array([0, 1000, 0, 0])
	_towns(2)
	_rich()
	var b := _brief()
	b.goal_men = 100000
	b.army_room = 100000
	_forces(b)
	assert_eq(_kinds_raised(), [1, 1] as Array[int], "a mix of crossbowmen only")


func test_p_knights_refused_for_want_of_a_good_fall_to_the_next_kind() -> void:
	var t := _temper()
	t.mix = PackedInt32Array([0, 300, 700, 0])
	_towns(2)
	_rich()
	var knights := _g.defs.unit_def(2)
	assert_false(knights.cost_goods.is_empty(), "knights are paid in a good")
	_country().stock[_g.defs.good_id(&"horses")] = 0
	var b := _brief()
	b.goal_men = 100000
	b.army_room = 100000
	_forces(b)
	assert_eq(_kinds_raised(), [1, 1] as Array[int], "no knights without the good: the crossbowmen instead")
	assert_eq(_hook.refusals(), 0, "a probe that fails is not a refused act")


func test_the_place_order_is_nearest_the_front_then_most_men_then_hex_index() -> void:
	var towns := _towns(3)
	WarFixture.at_war(_g, SEAT, AiFixture.VENICE)
	var b := _brief()
	assert_gt(b.front.size(), 0, "a war with a neighbour gives a front")
	var order := AiForces.place_order(_g, b)
	var rows: Array[Dictionary] = []
	for hex: Vector2i in order:
		var nearest := 1 << 30
		for i: int in b.front:
			nearest = mini(nearest, AiKnow.hex_distance(hex, AiKnow.hex_of(_g, i)))
		rows.append({"d": nearest, "men": AiKnow.men_at_hand(_g, SEAT, hex), "i": AiKnow.index_of(_g, hex)})
	for k: int in range(1, rows.size()):
		var a := rows[k - 1]
		var c := rows[k]
		var ok: bool = a["d"] < c["d"] or (a["d"] == c["d"] and (a["men"] > c["men"] or (a["men"] == c["men"] and a["i"] < c["i"])))
		assert_true(ok, "place %d keeps the order (distance, men, index)" % k)
	for town: Vector2i in towns:
		assert_true(order.has(town), "every settlement is a place")
	assert_eq(AiForces.place_order(_g, b), order, "the same order twice")


func test_a_raise_is_made_at_the_place_nearest_the_front() -> void:
	_towns(3)
	_rich()
	WarFixture.at_war(_g, SEAT, AiFixture.VENICE)
	var b := _brief()
	b.goal_men = 100000
	b.army_room = 100000
	var first := AiForces.place_order(_g, b)[0]
	_forces(b)
	var raised := _acts_of("raise")
	assert_gt(raised.size(), 0)
	assert_eq(raised[0]["args"]["hex"], first, "the first company on the first place")


func test_p_a_place_whose_check_refuses_moves_to_the_next() -> void:
	_towns(2)
	_rich()
	var b := _brief()
	b.goal_men = 100000
	b.army_room = 100000
	var first := AiForces.place_order(_g, b)[0]
	ArmyFixture.army(_g, SEAT, first, 0, Military.raise_cap(_g, first), _g.turn)
	AiForces.forces(_hook, _g, b, 0)
	var raised := _acts_of("raise")
	assert_gt(raised.size(), 0, "the other town takes it")
	for r: Dictionary in raised:
		assert_ne(r["args"]["hex"], first, "the full place is passed over")


func test_companies_raised_a_season_are_capped_at_peace_and_at_war() -> void:
	_towns(3)
	_rich()
	var b := _brief()
	b.goal_men = 100000
	b.army_room = 100000
	_forces(b)
	assert_eq(_companies(), _g.defs.ai.raises_peace, "raises_peace at peace")
	_g = ArmyFixture.game()
	_hook = AiFixture.solo(_g, SEAT)
	_towns(3)
	_rich()
	WarFixture.at_war(_g, SEAT, AiFixture.VENICE)
	b = _brief()
	b.goal_men = 100000
	b.army_room = 100000
	_forces(b)
	assert_eq(_companies(), _g.defs.ai.raises_war, "raises_war at war")


func test_p_a_changed_cap_in_the_ai_numbers_is_the_cap() -> void:
	var ai := _ai()
	ai.raises_peace = 1
	_towns(3)
	_rich()
	var b := _brief()
	b.goal_men = 100000
	b.army_room = 100000
	_forces(b)
	assert_eq(_companies(), 1)


func test_a_raise_stops_when_no_place_passes() -> void:
	_towns(2)
	_rich()
	_country().stock[_g.defs.good_id(&"iron")] = 0
	var b := _brief()
	b.goal_men = 100000
	b.army_room = 100000
	_forces(b)
	assert_eq(_acts_of("raise").size(), 0, "no iron for any kind: every check refuses, nothing raised, no crash")


# ----- disbanding --------------------------------------------------------------------------------------------------------------


func _poor_with_a_heavy_army() -> Army:
	var heavy := _g.defs.unit_def(0)
	heavy.upkeep = 100000
	var town := _towns(1)[0]
	return _army(town)


func test_a_broke_seat_whose_high_taxes_still_leave_a_deficit_disbands_a_company() -> void:
	var army := _poor_with_a_heavy_army()
	_country().treasury = -5
	assert_lt(AiKnow.preview_net(_g, SEAT, 2), 0, "even High taxes leave a deficit")
	_forces()
	var out := _acts_of("disband")
	assert_eq(out.size(), 1, "one company a season")
	assert_eq(out[0]["args"]["army"], army.id)


func test_p_no_disband_while_high_taxes_would_pay_the_bills() -> void:
	var town := _towns(1)[0]
	_army(town)
	_country().treasury = -5
	assert_gte(AiKnow.preview_net(_g, SEAT, 2), 0, "High taxes leave a surplus")
	_forces()
	assert_eq(_acts_of("disband").size(), 0, "a positive High preview: no disbanding")


func test_p_a_positive_treasury_disbands_nothing_however_big_the_upkeep() -> void:
	_poor_with_a_heavy_army()
	_country().treasury = 10
	_forces()
	assert_eq(_acts_of("disband").size(), 0)


func test_surplus_at_peace_disbands_the_smallest_company_of_the_farthest_army() -> void:
	var towns := _towns(2)
	_rich()
	var near := _army(towns[0], 3)
	var far := _army(towns[1], 3)
	var b := _brief()
	b.goal_men = 500
	assert_true(b.threats.is_empty() and b.enemies.is_empty())
	assert_gt(AiKnow.men(_g, SEAT) * 1000, b.goal_men * b.ai.disband_surplus, "far over the goal")
	var home := AiKnow.capital_of(_g, SEAT)
	var far_one := far if AiKnow.hex_distance(towns[1], home) > AiKnow.hex_distance(towns[0], home) else near
	far_one.units[1].men = 100
	var small := far_one.units[1].id
	_forces(b)
	var out := _acts_of("disband")
	assert_eq(out.size(), 1, "one company a season")
	assert_eq(out[0]["args"]["army"], far_one.id, "from the army farthest from the capital")
	assert_eq(out[0]["args"]["unit"], small, "its company with the fewest men")


func test_a_tie_in_men_disbands_the_highest_company_id() -> void:
	var town := _towns(1)[0]
	_rich()
	var army := _army(town, 3)
	var last := army.units[2].id
	var b := _brief()
	b.goal_men = 500
	_forces(b)
	assert_eq(_acts_of("disband")[0]["args"]["unit"], last)


func test_p_no_surplus_disband_under_threat_or_at_war_or_near_the_goal() -> void:
	var town := _towns(1)[0]
	_rich()
	_army(town, 3)
	var b := _brief()
	b.goal_men = 1500
	_forces(b)
	assert_eq(_acts_of("disband").size(), 0, "men not over twice the goal")
	b.goal_men = 500
	b.threats = [AiFixture.VENICE] as Array[StringName]
	_forces(b)
	assert_eq(_acts_of("disband").size(), 0, "a threat: nothing disbanded")
	b.threats = [] as Array[StringName]
	b.enemies = [AiFixture.VENICE] as Array[StringName]
	_forces(b)
	assert_eq(_acts_of("disband").size(), 0, "at war: nothing disbanded")


# ----- merging -------------------------------------------------------------------------------------------------------------------


func test_two_armies_on_one_hex_merge_the_higher_id_into_the_lower() -> void:
	var town := _towns(1)[0]
	_rich()
	var low := _army(town)
	var high := _army(town)
	var b := _brief()
	b.goal_men = AiKnow.men(_g, SEAT)
	_forces(b)
	var out := _acts_of("merge_armies")
	assert_eq(out.size(), 1)
	assert_eq([out[0]["args"]["army"], out[0]["args"]["into"]], [high.id, low.id])
	assert_null(Armies.by_id(_g, high.id), "the higher army is gone")
	assert_eq(Armies.by_id(_g, low.id).units.size(), 2)


func test_p_armies_on_different_hexes_or_marching_apart_do_not_merge() -> void:
	var towns := _towns(2)
	_rich()
	_army(towns[0])
	_army(towns[1])
	var a := _army(towns[0])
	a.order = Army.ORDER_MARCH
	a.goal = towns[1]
	var b := _brief()
	b.goal_men = AiKnow.men(_g, SEAT)
	_forces(b)
	assert_eq(_acts_of("merge_armies").size(), 0, "one army marches off: the two on the hex are one moving, one still")


func test_two_armies_marching_to_one_goal_merge() -> void:
	var towns := _towns(2)
	var a := _army(towns[0])
	var c := _army(towns[0])
	for army: Army in [a, c]:
		army.order = Army.ORDER_MARCH
		army.goal = towns[1]
	var b := _brief()
	b.goal_men = AiKnow.men(_g, SEAT)
	_forces(b)
	assert_eq(_acts_of("merge_armies").size(), 1)


func test_merges_stop_at_the_seasons_limit() -> void:
	var ai := _ai()
	ai.merges_per_season = 1
	var town := _towns(1)[0]
	_army(town)
	_army(town)
	_army(town)
	var b := _brief()
	b.goal_men = AiKnow.men(_g, SEAT)
	_forces(b)
	assert_eq(_acts_of("merge_armies").size(), 1, "merges_per_season 1")
	assert_eq(AiKnow.own_armies(_g, SEAT).size(), 2)
	ai.merges_per_season = 4
	var again := _brief()
	again.goal_men = AiKnow.men(_g, SEAT)
	_forces(again)
	assert_eq(AiKnow.own_armies(_g, SEAT).size(), 1, "with four allowed the rest join")


# ----- the army steps and the posts --------------------------------------------------------------------------------------------


func test_forces_appends_one_army_step_for_each_army_in_id_order() -> void:
	var towns := _towns(2)
	var a := _army(towns[0])
	var c := _army(towns[1])
	var b := _brief()
	b.goal_men = AiKnow.men(_g, SEAT)
	_forces(b)
	assert_eq(_pushed(), ["army %d" % a.id, "army %d" % c.id] as Array[String])


func test_the_forces_step_acts_only_for_its_seat() -> void:
	_towns(3)
	_rich()
	var b := _brief()
	b.goal_men = 100000
	_forces(b)
	assert_gt(_acts.size(), 0)
	for act: Dictionary in _acts:
		assert_eq(act["tag"], SEAT)
		assert_eq(act["args"]["tag"], SEAT)


# Re-pinned for moves in the month: the march to the post walks inside the step (R9). A post more than a season away leaves the
# march standing after the first leg (no second order); a post within reach is reached in the step.
func test_an_army_off_its_post_marches_to_it_and_one_on_it_stays() -> void:
	var towns := _towns(2)
	var army := _army(towns[0])
	var far := _far_town(army)
	var b := _brief()
	b.posts = [far] as Array[Vector2i]
	AiForces.peace_army(_hook, _g, b, army.id)
	var marches := _acts_of("march")
	assert_eq(marches.size(), 1)
	assert_eq(marches[0]["args"]["goal"], far)
	assert_ne(army.hex, towns[0], "its first leg walked in the step")
	assert_eq([army.order, army.goal], [Army.ORDER_MARCH, far], "the rest stands")
	AiForces.peace_army(_hook, _g, b, army.id)
	assert_eq(_acts_of("march").size(), 1, "already marching to its post: no second order")
	var on := _army(towns[1])
	b.posts = [towns[1]] as Array[Vector2i]
	AiForces.peace_army(_hook, _g, b, on.id)
	assert_eq(_acts_of("march").size(), 1, "an army on its post gives no march")
	var near := _army(towns[1])
	var next := ImproveRules.neighbour(towns[1], 0)
	b.posts = [next] as Array[Vector2i]
	AiForces.peace_army(_hook, _g, b, near.id)
	assert_eq([near.hex, near.order], [next, Army.ORDER_HOLD], "a post one step away: there in the step")
	AiForces.peace_army(_hook, _g, b, near.id)
	assert_eq(_acts_of("march").size(), 2, "and no further order on it")


## moves in the month (R41): a march of the forces' step halted on sight asks for one more step. In a turn an army at peace has
## no enemy to see, so the step is called here in a war scene (AiWarScene): knights of sight 2 walking past an unseen company.
func test_a_march_to_the_post_halted_on_sight_asks_for_one_more_step() -> void:
	_g = AiWarScene.at_war(AiFixture.VENICE)
	_hook = AiFixture.solo(_g, SEAT)
	var knights := _army(Vector2i(20, 5), 4, 2)
	ArmyFixture.army(_g, AiFixture.VENICE, Vector2i(18, 4), 0, 1, 0)
	Sight.refresh(_g)
	var b := _brief()
	b.posts = [Vector2i(19, 3)] as Array[Vector2i]
	assert_eq(b.seen.filter(func(e: Dictionary) -> bool: return e["hex"] == Vector2i(18, 4)).size(), 0)
	AiForces.peace_army(_hook, _g, b, knights.id)
	assert_eq(knights.halt_why, Movement.WHY_SIGHTED, "the walk halted on sight")
	assert_eq(_pushed(), ["army %d" % knights.id] as Array[String], "P: a halt with no further step")
	assert_eq(b.seen, AiKnow.seen_enemies(_g, SEAT), "and the seat looked again")
	_hook = AiFixture.solo(_g, SEAT)
	var foot := _army(Vector2i(9, 9))
	b.posts = [ImproveRules.neighbour(Vector2i(9, 9), 0)] as Array[Vector2i]
	AiForces.peace_army(_hook, _g, b, foot.id)
	assert_ne(foot.hex, Vector2i(9, 9), "a march with nothing new to see")
	assert_eq(_pushed(), [] as Array[String], "P: a march not halted on sight asks for no step")


## The first land hex of the seat's own land (index order) that `army` needs more than one season to reach.
func _far_town(army: Army) -> Vector2i:
	for i: int in AiKnow.land_of(_g, SEAT):
		var hex := AiKnow.hex_of(_g, i)
		var plan := Movement.plan(_g, army, hex)
		if bool(plan.ok) and int(Movement.walk_plan(_g, army, plan.hexes, _g.turn).seasons) > 1:
			return hex
	assert_true(false, "the seat has land more than a season away")
	return Army.NO_HEX


func test_an_army_on_its_post_but_marching_elsewhere_halts() -> void:
	var towns := _towns(2)
	var army := _army(towns[0])
	var b := _brief()
	b.posts = [towns[0]] as Array[Vector2i]
	Armies.set_order(_g, army, Army.ORDER_MARCH, towns[1], PackedInt32Array([_g.map.index_of(towns[1])]))
	AiForces.peace_army(_hook, _g, b, army.id)
	assert_eq(_acts_of("halt").size(), 1, "it stands on its post and halts")
	assert_ne(army.order, Army.ORDER_MARCH)


func test_posts_go_round_the_armies_by_men_then_id() -> void:
	var towns := _towns(3)
	var small := _army(towns[0], 1)
	var big := _army(towns[0], 3)
	var mid := _army(towns[0], 2)
	var b := _brief()
	b.posts = [towns[1], towns[2]] as Array[Vector2i]
	for army: Army in [small, big, mid]:
		AiForces.peace_army(_hook, _g, b, army.id)
	var goals := {}
	for m: Dictionary in _acts_of("march"):
		goals[m["args"]["army"]] = m["args"]["goal"]
	assert_eq(goals.get(big.id), towns[1], "the largest army takes the first post")
	assert_eq(goals.get(mid.id), towns[2], "the next the second")
	assert_eq(goals.get(small.id), towns[1], "the third goes round to the first")


func test_p_an_army_with_no_post_gets_no_march() -> void:
	var towns := _towns(1)
	var army := _army(towns[0])
	var b := _brief()
	b.posts = [] as Array[Vector2i]
	AiForces.peace_army(_hook, _g, b, army.id)
	assert_eq(_acts_of("march").size() + _acts_of("halt").size(), 0)


func test_an_army_at_peace_holds_when_attacked() -> void:
	var towns := _towns(1)
	var army := _army(towns[0])
	Armies.set_standing(_g, army, Army.STANDING_WITHDRAW)
	var b := _brief()
	b.posts = [towns[0]] as Array[Vector2i]
	AiForces.peace_army(_hook, _g, b, army.id)
	assert_eq(army.standing, Army.STANDING_HOLD)
	assert_eq(_acts_of("set_standing").size(), 1)
	AiForces.peace_army(_hook, _g, b, army.id)
	assert_eq(_acts_of("set_standing").size(), 1, "already Hold: no act")
	assert_eq(_hook.refusals(), 0)


func test_the_real_brief_posts_the_capital_when_nothing_threatens() -> void:
	var towns := _towns(1)
	var army := _army(towns[0])
	var b := _brief()
	var home := AiKnow.capital_of(_g, SEAT)
	assert_eq(b.posts, [home] as Array[Vector2i], "no threat: the capital alone")
	AiForces.peace_army(_hook, _g, b, army.id)
	if home == towns[0]:
		assert_eq(_acts_of("march").size(), 0)
	else:
		assert_eq(_acts_of("march").size() + _hook.refusals(), 1, "it tries its post once")


func test_p_the_order_every_setting_spaces_an_armys_steps() -> void:
	var ai := _ai()
	ai.peace_order_every = 2
	var towns := _towns(2)
	var army := _army(towns[0])
	var b := _brief()
	b.posts = [towns[1]] as Array[Vector2i]
	_g.turn = 2 if posmod(2 + army.id, 2) != 0 else 3
	AiForces.peace_army(_hook, _g, b, army.id)
	assert_eq(_acts_of("march").size(), 0, "(turn + id) mod 2 is not 0: the army waits this season")
	_g.turn += 1
	AiForces.peace_army(_hook, _g, b, army.id)
	assert_eq(_acts_of("march").size(), 1, "the next season it takes its step")


# ----- the door -------------------------------------------------------------------------------------------------------------------


func test_the_forces_file_calls_only_the_door_the_brief_and_the_trace() -> void:
	var text := FileAccess.get_file_as_string("res://core/ai/ai_forces.gd")
	for other: String in ["AiEconomy", "AiWar", "AiPeace", "AiPlayers", "Session"]:
		assert_false(text.contains(other), "ai_forces.gd never names " + other)
