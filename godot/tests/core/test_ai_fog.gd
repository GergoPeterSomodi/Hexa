## No omniscience (docs/architecture/fog-build-spec.md 3.7, 7; fog-build-plan FG12): a country's whole turn (its acts in order, its
## trace and its AI luck after) is the same when the facts it may not know are changed. The scene is Milan thin at radius 2 on the
## duel (FogFixture.duel_thin), at war with Venice at Autumn 1481, armies on both sides. Copy B changes only what Milan has not
## discovered: Venice's armies moved to other undiscovered hexes, re-ordered, given other standing orders and men lost; the
## garrisons of undiscovered fortresses lowered by 200; the owners of the two undiscovered Venetian hexes nearest Milan's army
## (now Genoa's); one more undiscovered Venetian hex made a fortress with a garrison; Venice's stores; the world's luck. It does
## not change a discovered garrison, a discovered hex or Venice's treasury: Milan may read those (R19, R33, R34).
## Then each gated read on its own is compared on the two copies, and a planted leak per gated read (the system call a cheat
## would make in its place) is shown to differ, so the comparison can fail. P: a test-only step reading the real garrison, the
## real owner or the real land of an undiscovered hex gives other acts.
extends GutTest

const M := AiFixture.MILAN
const V := AiFixture.VENICE
const G := AiFixture.GENOA
const REACH := 9


## Milan (turn 7: Autumn 1481) at war with Venice on the thin duel; Venice's armies on hexes Milan does not discover, and its
## neighbours' (4 companies each, seen).
func _scene() -> Game:
	var g := FogFixture.duel_thin()
	g.turn = 7
	WarFixture.at_war(g, M, V)
	var own := AiKnow.land_of(g, M)
	for k: int in 2:
		WarFixture.army_at(g, M, g.map.hex_of(own[k * 3]), 4)
	for i: int in _unseen_land(g, V).slice(0, 3):
		WarFixture.army_at(g, V, g.map.hex_of(i), 3)
	WarFixture.army_at(g, V, g.map.hex_of(own[own.size() - 1]), 3)
	Sight.refresh(g)
	g.version += 1
	return g


## Venice's land indices Milan has not discovered, ascending.
func _unseen_land(g: Game, tag: StringName) -> Array[int]:
	var out: Array[int] = []
	for i: int in AiKnow.land_of(g, tag):
		if g.map.is_land(g.map.hex_of(i)) and not Knowledge.discovered(g, M, g.map.hex_of(i)):
			out.append(i)
	return out


## The first fortress (any owner) that Milan has not discovered; -1 when none.
func _unseen_fortress(g: Game) -> int:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if Occupation.fortress_level(g, hex) > 0 and not Knowledge.discovered(g, M, hex):
			return i
	return -1


func _first_army(g: Game) -> Army:
	return AiKnow.own_armies(g, M)[0]


## The `n` indices of `indices` nearest to `from` (ties: lower index).
func _nearest(g: Game, from: Vector2i, indices: Array[int], n: int) -> Array[int]:
	var pool := indices.duplicate()
	var out: Array[int] = []
	while out.size() < n and not pool.is_empty():
		var best := 0
		for k: int in pool.size():
			var d := AiKnow.hex_distance(from, g.map.hex_of(pool[k]))
			var bd := AiKnow.hex_distance(from, g.map.hex_of(pool[best]))
			if d < bd or (d == bd and pool[k] < pool[best]):
				best = k
		out.append(pool[best])
		pool.remove_at(best)
	return out


## The facts Milan may not know, changed on copy B. Returns what was changed, for the sensitivity checks.
func _perturb(g: Game) -> Dictionary:
	var changed := {"armies": 0, "garrisons": 0, "owners": 0, "fortresses": 0, "stores": 0}
	var unseen := _unseen_land(g, V)
	var flips := _nearest(g, _first_army(g).hex, unseen, 2)
	var genoa := Countries.by_tag(g, G).id
	for i: int in flips:
		g.state.owner[i] = genoa
		changed["owners"] = int(changed["owners"]) + 1
	var fort := -1
	for i: int in unseen:
		if not flips.has(i):
			fort = i
			break
	if fort >= 0:
		g.state.main_use[fort] = ImproveRules.CASTLE
		g.state.level[fort] = FamilyIds.TOP_LEVEL[ImproveRules.CASTLE]
		g.state.garrison[fort] = 300
		changed["fortresses"] = int(changed["fortresses"]) + 1
	var spare: Array[int] = []
	for i: int in unseen:
		if not flips.has(i) and i != fort:
			spare.append(i)
	var k := 0
	for army: Army in AiKnow.own_armies(g, V):
		if Sight.sees(g, M, army.hex) or spare.is_empty():
			continue
		var to := g.map.hex_of(spare[spare.size() - 1 - (k % spare.size())])
		k += 1
		Armies.set_hex(g, army, to, Army.NO_HEX)
		Armies.set_order(g, army, Army.ORDER_MARCH, _first_army(g).hex, PackedInt32Array())
		Armies.set_standing(g, army, Army.STANDING_WITHDRAW)
		Armies.lose_men(g, army, 300, &"test")
		changed["armies"] = int(changed["armies"]) + 1
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if Occupation.fortress_level(g, hex) > 0 and not Knowledge.discovered(g, M, hex):
			g.state.garrison[i] = maxi(0, int(g.state.garrison[i]) - 200)
			changed["garrisons"] = int(changed["garrisons"]) + 1
	for good: int in g.defs.goods.size():
		g.dev_goods(V, good, 17 + good)
	changed["stores"] = g.defs.goods.size()
	g.luck.world.seed_with(987654)
	Sight.refresh(g)
	g.version += 1
	return changed


func _turn(g: Game) -> Dictionary:
	var hook := AiFixture.solo(g, M)
	var acts := AiFixture.run(g, hook)
	var text := PackedStringArray()
	for a: Dictionary in acts:
		text.append("%s %s" % [a["action"], str(a["args"])])
	return {"acts": text, "trace": hook.trace_of(M), "luck": g.luck.ai.get_state()}


func test_the_scene_has_what_the_spec_asks_for() -> void:
	var g := _scene()
	assert_gt(_unseen_land(g, V).size(), 0, "Venice has undiscovered land")
	assert_ne(_unseen_fortress(g), -1, "an undiscovered fortress exists")
	assert_gt(AiKnow.seen_enemies(g, M).size(), 0, "Milan sees some Venetian army")
	assert_lt(AiKnow.seen_enemies(g, M).size(), g.armies.size(), "and not every army is seen")
	var b := _scene()
	var changed := _perturb(b)
	assert_gte(int(changed["garrisons"]), 1, "undiscovered fortresses lowered")
	assert_gte(int(changed["owners"]), 1, "undiscovered owners changed")
	assert_gte(int(changed["armies"]), 1, "unseen Venetian armies moved")


func test_the_same_turn_when_what_it_may_not_know_changes() -> void:
	var a := _scene()
	var b := _scene()
	_perturb(b)
	assert_ne(a.digest(), b.digest(), "the two games differ")
	var ta := _turn(a)
	var tb := _turn(b)
	assert_gt((ta["acts"] as PackedStringArray).size(), 0, "Milan acted: %s" % str(ta["acts"]))
	assert_eq(tb["acts"], ta["acts"], "the same acts in the same order")
	assert_eq(tb["trace"], ta["trace"], "the same reasons")
	assert_eq(tb["luck"], ta["luck"], "the same AI luck")


func test_the_same_turn_over_the_other_seasons() -> void:
	for turn: int in [3, 5, 9, 12]:
		var a := _scene()
		var b := _scene()
		a.turn = turn
		b.turn = turn
		_perturb(b)
		var ta := _turn(a)
		var tb := _turn(b)
		assert_eq(tb["acts"], ta["acts"], "turn %d" % turn)
		assert_eq(tb["luck"], ta["luck"], "turn %d luck" % turn)


# ----- each gated read of the door, on the two copies -------------------------------------------------------------------------


## What the door reads for Milan: every function that touches another country, over every other country, every fortress and every
## land hex near a Milan army. AiKnow.area_state, owner_of, controller_of, fortresses_of and capital_of of another country are
## not listed: AiWar reads them only after its discovered gate (R33; the door's own gate is FG12's open question).
func _reads(g: Game) -> Dictionary:
	var out := {}
	for c: Country in g.countries:
		if c.tag != M:
			out["men_of %s" % c.tag] = AiKnow.men_of(g, M, c.tag)
	out["seen_enemies"] = AiKnow.seen_enemies(g, M)
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		out["discovered %s" % hex] = AiKnow.discovered(g, M, hex)
		if Occupation.fortress_level(g, hex) > 0:
			out["garrison %s" % hex] = AiKnow.garrison_estimate(g, M, hex)
			out["forecast %s" % hex] = AiKnow.forecast(g, M, hex, 1500, 0)
			out["forecast guns %s" % hex] = AiKnow.forecast(g, M, hex, 1500, 4)
	for army: Army in AiKnow.own_armies(g, M):
		for i: int in g.map.hex_count():
			var hex := g.map.hex_of(i)
			if g.map.is_land(hex) and AiKnow.hex_distance(army.hex, hex) <= 9:
				out["odds %d %s" % [army.id, hex]] = AiKnow.odds(g, M, army, hex, false)
				out["storm odds %d %s" % [army.id, hex]] = AiKnow.odds(g, M, army, hex, true)
	for e: StringName in [V, G]:
		out["score %s" % e] = AiKnow.score(g, M, e)
		out["at_war_with_other %s" % e] = AiKnow.at_war_with_other(g, M, e)
	out["enemies"] = AiKnow.enemies(g, M)
	out["wars"] = AiKnow.wars_of(g, M)
	return out


func test_every_gated_read_is_the_same_on_both_copies() -> void:
	var a := _scene()
	var b := _scene()
	_perturb(b)
	var ra := _reads(a)
	var rb := _reads(b)
	assert_gt(ra.size(), 100)
	var differing: Array[String] = []
	for key: String in ra:
		if var_to_bytes(ra[key]) != var_to_bytes(rb.get(key)):
			differing.append(key)
	assert_eq(differing, [] as Array[String], "reads that follow what Milan may not know")


func test_p_each_planted_leak_differs_on_the_two_copies() -> void:
	# The system call a cheat would make in place of each gated read; the perturbation must be visible through it.
	var a := _scene()
	var b := _scene()
	_perturb(b)
	var fort := _unseen_fortress(a)
	var flip := _nearest(a, _first_army(a).hex, _unseen_land(a, V), 1)[0]
	var leaks: Dictionary = {
		"the real garrison of an undiscovered fortress": func(g: Game) -> Variant: return Occupation.garrison_of(g, g.map.hex_of(fort)),
		"the real owner of an undiscovered hex": func(g: Game) -> Variant: return Territory.owner_tag(g, g.map.hex_of(flip)),
		"Venice's land": func(g: Game) -> Variant: return Territory.districts(g, Countries.by_tag(g, V).id).size(),
		"Venice's men under arms": func(g: Game) -> Variant: return Wars.men_under_arms(g, V),
		"the world's luck": func(g: Game) -> Variant: return g.luck.world.get_state(),
	}
	for name: String in leaks:
		var read := leaks[name] as Callable
		assert_ne(read.call(a), read.call(b), "a leak of %s shows" % name)


# ----- the three plants: a step that reads a gated fact straight gives other acts ---------------------------------------------


## A test-only step: for each Venetian fortress, the seasons of a siege by Milan's first army. Honest: AiKnow.forecast over the
## fortresses Milan has discovered; the plant: Sieges.forecast, which reads the real garrison of every one.
func _pick_fortress(g: Game, leak: bool) -> Array:
	var army := _first_army(g)
	var guns := AiKnow.guns_of(g, army)
	var seasons: Array = []
	for hex: Vector2i in AiKnow.fortresses_of(g, V):
		if leak:
			seasons.append([hex, Sieges.forecast(g, hex, M, army.men(), guns, 0, 0)])
		elif Knowledge.discovered(g, M, hex):
			seasons.append([hex, AiKnow.forecast(g, M, hex, army.men(), guns)])
	return seasons


## Venetian land within reach of Milan's first army, ascending. Honest: the discovered hexes of AiKnow.owner_of; the plant: the
## real owners (Territory.owner_tag) of every hex.
func _reach_by_owner(g: Game, honest: bool) -> Array[int]:
	var army := _first_army(g)
	var out: Array[int] = []
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if not g.map.is_land(hex) or AiKnow.hex_distance(army.hex, hex) > REACH:
			continue
		if honest and not Knowledge.discovered(g, M, hex):
			continue
		var owner := AiKnow.owner_of(g, hex) if honest else Territory.owner_tag(g, hex)
		if owner == V:
			out.append(i)
	return out


## The same reach taken from Venice's land list: honest, AiKnow.land_of over the discovered hexes; the plant, the real
## Territory.districts of Venice.
func _reach_by_land(g: Game, honest: bool) -> Array[int]:
	var army := _first_army(g)
	var out: Array[int] = []
	var list: PackedInt32Array = AiKnow.land_of(g, V) if honest else Territory.districts(g, Countries.by_tag(g, V).id)
	for i: int in list:
		var hex := g.map.hex_of(i)
		if AiKnow.hex_distance(army.hex, hex) > REACH:
			continue
		if honest and not Knowledge.discovered(g, M, hex):
			continue
		out.append(i)
	return out


func test_p_a_step_reading_the_real_garrison_gives_other_acts() -> void:
	var a := _scene()
	var b := _scene()
	_perturb(b)
	var honest_a := _pick_fortress(a, false)
	var honest_b := _pick_fortress(b, false)
	assert_eq(honest_b, honest_a, "AiKnow.forecast: the same pick")
	var leaky_a := _pick_fortress(a, true)
	var leaky_b := _pick_fortress(b, true)
	assert_gt(leaky_a.size(), honest_a.size(), "the plant sees the undiscovered fortress too")
	assert_ne(leaky_b, leaky_a, "Sieges.forecast: another pick (%s against %s)" % [str(leaky_b), str(leaky_a)])


func test_p_a_step_reading_the_real_owner_gives_other_acts() -> void:
	var a := _scene()
	var b := _scene()
	_perturb(b)
	assert_eq(_reach_by_owner(b, true), _reach_by_owner(a, true), "AiKnow.owner_of on discovered hexes: the same reach")
	var leak_a := _reach_by_owner(a, false)
	var leak_b := _reach_by_owner(b, false)
	assert_ne(leak_b, leak_a, "Territory.owner_tag: another reach (%s against %s)" % [str(leak_b), str(leak_a)])


func test_p_a_step_reading_the_real_land_gives_other_acts() -> void:
	var a := _scene()
	var b := _scene()
	_perturb(b)
	assert_eq(_reach_by_land(b, true), _reach_by_land(a, true), "AiKnow.land_of over the discovered hexes: the same reach")
	var leak_a := _reach_by_land(a, false)
	var leak_b := _reach_by_land(b, false)
	assert_ne(leak_b, leak_a, "Territory.districts: another reach (%s against %s)" % [str(leak_b), str(leak_a)])


# ----- the fortress reads: a discovered garrison is exact, an undiscovered fortress gives no card -------------------------------


func test_a_discovered_garrison_is_read_exactly_on_every_card() -> void:
	# R19: a discovered fortress is exact for the viewer; no rounding (the 100s of D49 are gone for the AI).
	var g := _scene()
	var fort := Army.NO_HEX
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if Occupation.fortress_level(g, hex) > 0 and Knowledge.discovered(g, M, hex):
			fort = hex
			break
	assert_ne(fort, Army.NO_HEX, "Milan has discovered a fortress")
	var i := g.map.index_of(fort)
	for men: int in [800, 840, 20]:
		g.state.garrison[i] = men
		g.version += 1
		assert_eq(AiKnow.garrison_estimate(g, M, fort), men, "exact %d" % men)
		assert_eq(AiKnow.forecast(g, M, fort, 2000, 0), Sieges.forecast_for(g, fort, men, 2000, 0, 0, 0), "forecast of %d" % men)


func test_an_undiscovered_fortress_gives_no_card_whatever_it_holds() -> void:
	var a := _scene()
	var b := _scene()
	var i := _unseen_fortress(a)
	assert_ne(i, -1, "an undiscovered fortress exists")
	var fort := a.map.hex_of(i)
	a.state.garrison[i] = 20
	b.state.garrison[i] = 800
	a.version += 1
	b.version += 1
	assert_eq(AiKnow.garrison_estimate(a, M, fort), -1, "unknown, never none")
	assert_eq(AiKnow.garrison_estimate(b, M, fort), -1, "unknown, never the full garrison")
	assert_eq(AiKnow.forecast(a, M, fort, 2000, 2), -1, "no forecast against a guess")
	assert_eq(AiKnow.forecast(b, M, fort, 2000, 2), -1, "no forecast against a guess")


func test_the_aims_are_the_same_and_every_goal_is_discovered() -> void:
	var a := _scene()
	var b := _scene()
	_perturb(b)
	var ba := AiBrief.make(a, M)
	var bb := AiBrief.make(b, M)
	var goals := 0
	for army: Army in AiKnow.own_armies(a, M):
		var la := AiWar.aims(a, ba, army)
		var lb := AiWar.aims(b, bb, army)
		assert_eq(var_to_bytes(lb), var_to_bytes(la), "aims of army %d" % army.id)
		for aim: Dictionary in la:
			goals += 1
			assert_true(Knowledge.discovered(a, M, aim["goal"] as Vector2i), "an aim's goal %s is discovered" % str(aim["goal"]))
	assert_gt(goals, 0, "Milan has aims")
