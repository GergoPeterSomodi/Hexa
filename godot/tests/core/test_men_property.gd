## The men properties (docs/architecture/m6-build-spec.md 9, done-when 4 and 6; 5.0 R1): 40 seasons of the 1480 scenario with the
## RandomPlayer for every country (raises, marches, halts, splits, merges, disbands) and weather drawn. Every season, every
## country: the change of its people plus the change of its men under arms equals its closed flows other than raised and
## returned, less the men lost by armies (army_starved); the men under arms move by the raised people less the returned
## ones, less the losses. The world's change is the sum of the countries'. Each walk spends no more move points than its
## slowest unit has (or is a single step), crosses no closed pass or blocked edge, and enters only land open to its
## country; at a season's end no army is over the stack limit, no hex holds another country's army, no store is below zero,
## no company or army is empty, and fed is never over its full 1,000.
extends GutTest

const SEASONS := 40
const SEED := 1480
const PLAYER_TURNS := 10

var _luck: Rng = null
var _seen := {}
## The countries that raised companies this season (a window's raised people then are not a refill's alone).
var _raised_tags := {}


func before_each() -> void:
	_luck = Rng.new()
	_luck.seed_with(SEED)
	_seen = {"raised": 0, "disbanded": 0, "marched": 0, "walks": 0, "starved": 0, "split": 0, "merged": 0,
		"continued": 0, "refused": 0, "single_steps": 0, "refill_windows": 0}
	_raised_tags = {}


## Each country's people on its land and its men under arms: {tag: [people, men]}.
func _census(g: Game) -> Dictionary:
	var out := {}
	for c: Country in g.countries:
		var people := 0
		for i: int in Territory.districts(g, c.id):
			people += int(g.state.people[i])
		out[c.tag] = [people, Armies.men_of_country(g, c.tag)]
	return out


## A few random actions for every country (the player's first), as the door takes them.
func _act_all(g: Game) -> void:
	for c: Country in g.countries:
		for _t: int in PLAYER_TURNS:
			var pick: Dictionary = RandomPlayer.next(g, c.tag, _luck)
			var action: String = str(pick["action"])
			# Wars are not in the snapshot yet (B13 wires them); the pick still drew from the stream, so the others do not move.
			if action in ["declare_war", "make_peace"]:
				continue
			var logged := g.action_log.size()
			var verdict: Dictionary = g.act(action, pick["args"])
			if not bool(verdict["ok"]):
				_seen["refused"] += 1
				continue
			assert_gt(g.action_log.size(), logged, "an accepted action is logged")
			if action == "raise":
				_raised_tags[StringName(str(pick["args"]["tag"]))] = true
			_count(action)


func _count(action: String) -> void:
	match action:
		"raise":
			_seen["raised"] += 1
		"disband":
			_seen["disbanded"] += 1
		"march":
			_seen["marched"] += 1
		"split_army":
			_seen["split"] += 1
		"merge_armies":
			_seen["merged"] += 1
		"continue_march":
			_seen["continued"] += 1


## The walks of this season (its unit_moved events) against the move budget, the closed passes and the land entered.
func _check_walks(g: Game, budgets: Dictionary, season: int, winter: bool) -> void:
	var steps := StepCosts.of(g.map, g.defs)
	for e: Dictionary in g.events:
		if str(e.get("kind", "")) != "unit_moved":
			continue
		_seen["walks"] += 1
		var path: Array = e["path"]
		var army_id := int(e["army"])
		var tag := StringName(str(e["tag"]))
		var label := "army %d, season %d" % [army_id, season]
		var spent := 0
		for k: int in path.size() - 1:
			var here := path[k] as Vector2i
			var there := path[k + 1] as Vector2i
			var d := Movement.direction(g.map, g.map.index_of(here), g.map.index_of(there))
			assert_ne(d, -1, "the path steps to a neighbour, " + label)
			var cost := steps.cost(g.map.index_of(here), d, winter)
			assert_ne(cost, StepCosts.CLOSED, "no closed pass is crossed, " + label)
			assert_ne(cost, StepCosts.BLOCKED, "no blocked edge is crossed, " + label)
			assert_true(Movement.open_to(g, tag, there), "the land is open to the country, " + label)
			if cost == StepCosts.WADE:
				assert_eq(k, 0, "a wade is a leg's first step only, " + label)
			else:
				spent += cost
		if path.size() == 2:
			_seen["single_steps"] += 1  # the first step may cost more than the points (walk_season): one step only
		else:
			assert_lte(spent, int(budgets.get(army_id, 0)), "no more move points than the slowest unit has, " + label)


## The identity and the state at the end of a season. `pre` is the census before the actions, `post` after the season,
## `lost` the men each country lost to hunger this season, `planted` a person added behind the door (P only).
func _check_season(g: Game, season: int, pre: Dictionary, post: Dictionary, lost: Dictionary,
		open_before: Dictionary, open_after: Dictionary) -> void:
	var world_change := 0
	var world_flows := 0
	for c: Country in g.countries:
		var label := "%s, season %d" % [c.tag, season]
		var closed := c.people_closed["flows"] as PackedInt32Array
		assert_eq(int(c.people_closed["turn"]), season, "the closed flows are of this season, " + label)
		# The season's window: what closed at its stats phase, less what was open before its actions (booked after the
		# last close: the refill of the season before, in its ready_units), plus what is open after the season (this
		# season's refill and vision). The refill runs after the calendar, so its flows close with the next season.
		var window := PackedInt32Array()
		var before: PackedInt32Array = open_before[c.tag]
		var after: PackedInt32Array = open_after[c.tag]
		for f: int in closed.size():
			window.append(closed[f] - before[f] + after[f])
		var raised := int(window[People.FLOWS.find(&"raised")])
		var returned := int(window[People.FLOWS.find(&"returned")])
		var rest := 0
		for f: int in window:
			rest += f
		rest -= raised + returned
		var men_lost := int(lost.get(c.tag, 0))
		var dp := int(post[c.tag][0]) - int(pre[c.tag][0])
		var dm := int(post[c.tag][1]) - int(pre[c.tag][1])
		assert_eq(dp + dm, rest - men_lost, "people plus men change by the flows less the men lost, " + label)
		assert_eq(dm, -(raised + returned) - men_lost, "the men under arms move by the raised and returned people, less losses, " + label)
		world_change += dp + dm
		world_flows += rest - men_lost
		for stock: int in c.stock:
			assert_gte(stock, 0, "no store below zero, " + label)
		assert_lte(c.food_fed, 1000, "fed is never over the full, " + label)
	assert_eq(world_change, world_flows, "the world's change is the sum over the countries, season %d" % season)
	for a: Army in g.armies:
		var label := "army %d, season %d" % [a.id, season]
		assert_gt(a.units.size(), 0, "no empty army, " + label)
		for u: Unit in a.units:
			assert_gt(u.men, 0, "no company without men, " + label)
		assert_lte(Armies.units_at(g, a.tag, a.hex), Military.stack_limit(g, a.tag), "no army over the stack limit, " + label)
		for other: Army in Armies.at(g, a.hex):
			assert_eq(other.tag, a.tag, "no hex shared with another country's army, " + label)


## Each country's open people flows now (what the season has booked since its last close): {tag: PackedInt32Array}.
func _open_flows(g: Game) -> Dictionary:
	var out := {}
	for c: Country in g.countries:
		out[c.tag] = c.people_flows.duplicate()
	return out


## Every army that holds (it arrived, or never marched) is sent to a land hex of its country two to three hexes off, now
## and then (the order goes through the door; a refusal is taken as it is).
func _remarch(g: Game) -> void:
	for a: Army in g.armies.duplicate():
		if a.order != Army.ORDER_HOLD and a.order != Army.ORDER_NONE:
			continue
		if _luck.randi_range(0, 1) != 0:
			continue
		var land := Territory.districts(g, Countries.by_tag(g, a.tag).id)
		for _t: int in 6:
			if land.is_empty():
				break
			var goal := g.map.hex_of(land[_luck.randi_range(0, land.size() - 1)])
			var d := ImproveRules.hex_distance(goal, a.hex)
			if d < 2 or d > 3:
				continue
			if bool(g.act("march", {"army": a.id, "goal": goal, "tag": a.tag})["ok"]):
				_seen["marched"] += 1
				break


func _run(g: Game) -> void:
	for season: int in SEASONS:
		var pre := _census(g)
		var open_before := _open_flows(g)
		_raised_tags.clear()
		_act_all(g)
		_remarch(g)
		# Every third season the country's food is gone before the supply phase (which runs before production): its armies
		# on its land go hungry (a rig through the door, logged; a dev transfer, like the rest of the tests' rigs).
		if season % 3 == 2:
			for good: String in ["grain", "fish"]:
				var id := g.defs.good_id(StringName(good))
				g.dev_goods(ArmyFixture.TAG, id, -Countries.by_tag(g, ArmyFixture.TAG).stock[id])
		# The walk budget is the slowest unit's move points as the phase will read them: after the actions.
		var budgets := {}
		for a: Army in g.armies:
			budgets[a.id] = Movement.mp_of(g, a)
		var ended := g.turn
		var winter := Movement.winter_now(g)  # read before the season: the calendar moves the turn on
		g.events.clear()
		assert_true(bool(Season.run(g)["ok"]), "the season ends")
		var lost := {}
		for e: Dictionary in g.events:
			if str(e.get("kind", "")) == "army_starved":
				_seen["starved"] += 1
				var t := StringName(str(e["tag"]))
				lost[t] = int(lost.get(t, 0)) + int(e["lost"])
		_check_walks(g, budgets, ended, winter)
		_check_season(g, ended, pre, _census(g), lost, open_before, _open_flows(g))
		for c: Country in g.countries:
			var closed := c.people_closed["flows"] as PackedInt32Array
			var window_raised := int(closed[People.FLOWS.find(&"raised")]) - int(open_before[c.tag][People.FLOWS.find(&"raised")]) + int(_open_flows(g)[c.tag][People.FLOWS.find(&"raised")])
			if window_raised < 0 and not _raised_tags.has(c.tag):
				_seen["refill_windows"] += 1


## The 1480 game as Genoa with real weather and people, and three armies of its own to start with (the raises of the
## random player are rare on random hexes): two on one town (a split and a merge can be made there), one on other land.
## Their companies are damaged (a rig before the first census: 300 men lost to nothing, not a flow), so the ready_units
## refill has men to bring back from the people of the town.
func _seeded_game() -> Game:
	var g := EconomyFixture.game(&"GEN", false, false, SEED, false)
	var town := ArmyFixture.find_town(g)
	ArmyFixture.town(g, town)
	var first := ArmyFixture.army(g, ArmyFixture.TAG, town, 0, 3)
	var second := ArmyFixture.army(g, ArmyFixture.TAG, town, 0, 2)
	var far := ArmyFixture.army(g, ArmyFixture.TAG, g.map.hex_of(Territory.districts(g, ArmyFixture.id_of(g, ArmyFixture.TAG))[0]), 0, 2)
	for a: Army in [first, second, far]:
		Armies.lose_men(g, a, 300, &"rig")
	return g


func test_forty_seasons_every_country_conserves_its_men_and_its_people() -> void:
	var g := _seeded_game()
	_run(g)
	assert_eq(g.turn, SEASONS + 1)
	assert_gt(int(_seen["raised"]), 3, "armies were raised: %s" % str(_seen))
	assert_gt(int(_seen["marched"]), 3, "armies were ordered on the march")
	assert_gt(int(_seen["walks"]), 3, "armies walked")
	assert_gt(int(_seen["disbanded"]), 0, "armies were disbanded")
	assert_gt(int(_seen["split"]) + int(_seen["merged"]), 0, "armies were split or merged")
	assert_gt(int(_seen["continued"]), 0, "a halted march continued (a player halt keeps its goal)")
	# The refill is pinned by the deterministic tests below (a fixed seed, no random actions): this counter depends on the
	# random stream, and a country that raised companies that season is not counted.
	assert_gt(int(_seen["starved"]), 0, "an army went hungry with its country's stores empty")


func test_p_one_person_from_nowhere_breaks_the_identity() -> void:
	# The identity is exact: a person added behind the door is seen in the census (the check's own proof).
	var g := EconomyFixture.game(&"GEN", false, true, SEED, false)
	var c := Countries.by_tag(g, &"GEN")
	var pre := _census(g)
	var land := Territory.districts(g, c.id)
	g.state.people[land[0]] += 1
	Season.run(g)
	var closed := c.people_closed["flows"] as PackedInt32Array
	var rest := 0
	for f: int in closed:
		rest += f
	rest -= int(closed[People.FLOWS.find(&"raised")]) + int(closed[People.FLOWS.find(&"returned")])
	var post := _census(g)
	var change: int = int(post[c.tag][0]) + int(post[c.tag][1]) - int(pre[c.tag][0]) - int(pre[c.tag][1])
	assert_ne(change, rest, "one person from nowhere is seen: the change is not the flows")


func _men_and_people(g: Game, tag: StringName) -> Array:
	var people := 0
	for i: int in Territory.districts(g, Countries.by_tag(g, tag).id):
		people += int(g.state.people[i])
	return [Armies.men_of_country(g, tag), people]


func test_a_damaged_company_refills_from_its_people_on_a_fixed_seed() -> void:
	var g := _seeded_game()
	var before := _men_and_people(g, ArmyFixture.TAG)
	for _k: int in 3:
		assert_true(bool(Season.run(g)["ok"]), "the season ends")
	var after := _men_and_people(g, ArmyFixture.TAG)
	assert_gt(int(after[0]), int(before[0]), "the men under arms rose: the refill brought men back")


func test_a_refill_in_a_war_draws_on_an_own_home_and_stops_on_an_occupied_one() -> void:
	var g := _seeded_game()
	var enemy := WarFixture.neighbour_of(g, ArmyFixture.TAG)
	WarFixture.at_war(g, ArmyFixture.TAG, enemy)
	var home := g.armies[0].hex
	assert_eq(Territory.owner_tag(g, home), ArmyFixture.TAG, "the army stands on its own land")
	_damage_all(g, 200)
	var damaged := Armies.men_of_country(g, ArmyFixture.TAG)
	Military.refill(g)
	assert_gt(Armies.men_of_country(g, ArmyFixture.TAG), damaged, "an own unoccupied home refills during the war")
	_damage_all(g, 200)
	WarFixture.set_occupier(g, home, enemy)
	var on_home := _men_on(g, home)
	Military.refill(g)
	assert_eq(_men_on(g, home), on_home, "the armies on an occupied home take no levy")


## The men of the player's armies standing on hex.
func _men_on(g: Game, hex: Vector2i) -> int:
	var n := 0
	for a: Army in g.armies:
		if a.tag == ArmyFixture.TAG and a.hex == hex:
			for u: Unit in a.units:
				n += u.men
	return n


## Takes `men` from every company of every army of the player's country (a test's rig, before any census).
func _damage_all(g: Game, men: int) -> void:
	for a: Army in g.armies:
		if a.tag != ArmyFixture.TAG:
			continue
		for u: Unit in a.units:
			u.men = maxi(1, u.men - men)
