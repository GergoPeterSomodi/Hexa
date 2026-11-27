## The twin test (moves-build-spec.md R57, 8.1; plan MV13): two games that differ only in armies Savoy does not see give equal
## MovePreview.to results (the verdict, the leg, the risks, the lines, all of it) and equal refusals for every order of Savoy's
## armies, on MovesFixture.duel() and thin(). Copy B changes only what Savoy cannot see: Milan's unseen army moved elsewhere,
## given the standing order Withdraw and fewer men, and more Milanese armies on unseen hexes round Savoy's. Savoy has its
## fixture army (holding) and a second one with a halted march, so Continue is ordered too. Two states of Savoy's own armies are
## their own cases: a shaken army (Battles.engage_check's morale) and a hex other armies of Savoy march to (the stack limit),
## each against a hidden army on the goal. P: a leg end read from the engine's own leg, which stops beside an army out of
## sight, moves with it.
extends GutTest

const S := MovesFixture.SAVOY
const M := MovesFixture.MILAN
const NAME_HALTED := "Savoyard halted fixture"
## The hidden armies added to copy B, and the most hexes a one-army sweep hides an army on.
const ADDED := 3
const SWEEP := 24
## The goals of a sweep's case: the hexes within this distance of the hidden army.
const REACH := 3
const SHAKEN_MORALE := 400


## The duel (thin: Savoy's explored set at radius 2) with a second army of Savoy that has a halted march, far from Milan's.
func _scene(thin: bool) -> Game:
	var g := MovesFixture.thin() if thin else MovesFixture.duel()
	var home := MovesFixture.named(g, MovesFixture.NAME_HOME)
	var unseen := MovesFixture.named(g, MovesFixture.NAME_UNSEEN)
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if Territory.owner_tag(g, hex) != S or not Armies.at(g, hex).is_empty() \
				or ImproveRules.hex_distance(hex, unseen.hex) < 5 or ImproveRules.hex_distance(hex, home.hex) < 2:
			continue
		var second := ArmyFixture.army(g, S, hex, 0, 2)
		second.name = NAME_HALTED
		Sight.refresh(g)
		var plan := Movement.plan(g, second, home.hex)
		if Sight.sees(g, S, unseen.hex) or not bool(plan.ok):
			Armies.remove(g, second)
			Sight.refresh(g)
			continue
		Armies.set_order(g, second, Army.ORDER_NONE, home.hex, plan.hexes)
		break
	Sight.refresh(g)
	g.version += 1
	return g


## The land hexes Savoy does not see that hold no army, nearest to `from` first (ties: the lower index).
func _unseen_near(g: Game, from: Vector2i) -> Array[Vector2i]:
	var found: Array = []
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 1 and not Sight.sees(g, S, hex) and Armies.at(g, hex).is_empty():
			found.append([ImproveRules.hex_distance(hex, from), i])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array[Vector2i] = []
	for f: Array in found:
		out.append(g.map.hex_of(f[1]))
	return out


## Copy B's changes, all out of Savoy's sight.
func _differ(g: Game) -> void:
	var home := MovesFixture.named(g, MovesFixture.NAME_HOME)
	var unseen := MovesFixture.named(g, MovesFixture.NAME_UNSEEN)
	var spots := _unseen_near(g, home.hex)
	Armies.set_hex(g, unseen, spots[0], Army.NO_HEX)
	Armies.set_standing(g, unseen, Army.STANDING_WITHDRAW)
	Armies.lose_men(g, unseen, 300, &"test")
	# every third unseen hex from there on, so the armies lie on and beside different routes
	for k: int in ADDED:
		ArmyFixture.army(g, M, spots[2 + 3 * k], 0, 2)
	Sight.refresh(g)
	g.version += 1


## What Savoy's armies are told for one order: every verdict and the preview of a march to `hex`, as text.
func _answers(g: Game, army: Army, hex: Vector2i) -> Dictionary:
	var args := {"army": army.id, "goal": hex, "tag": S}
	return {"march": str(g.check("march", args)), "storm": str(g.check("storm", args)),
		"preview": MovePreview.to(g, S, army.id, hex)}


## The differences between the two games for every order of Savoy's armies to the hexes of `goals`.
func _diff_orders(a: Game, b: Game, goals: Array[Vector2i]) -> Array[String]:
	var out: Array[String] = []
	for army: Army in Armies.of_country(a, S):
		var other := Armies.by_id(b, army.id)
		for action: String in ["halt", "continue_march"]:
			var args := {"army": army.id, "tag": S}
			if str(a.check(action, args)) != str(b.check(action, args)):
				out.append("%s of %s: %s against %s" % [action, army.name, a.check(action, args), b.check(action, args)])
		for hex: Vector2i in goals:
			var x := _answers(a, army, hex)
			var y := _answers(b, other, hex)
			for key: String in ["march", "storm"]:
				if x[key] != y[key]:
					out.append("%s of %s to %s: %s against %s" % [key, army.name, hex, x[key], y[key]])
			var px := x["preview"] as Dictionary
			var py := y["preview"] as Dictionary
			if str(px) != str(py):
				for field: String in px:
					if str(px[field]) != str(py.get(field)):
						out.append("preview.%s of %s to %s: %s against %s" % [field, army.name, hex, px[field], py.get(field)])
	return out


func _all_hexes(g: Game) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in g.map.hex_count():
		out.append(g.map.hex_of(i))
	return out


func _within(g: Game, hex: Vector2i, distance: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for h: Vector2i in _all_hexes(g):
		if ImproveRules.hex_distance(h, hex) <= distance:
			out.append(h)
	return out


## The armies of `g` Savoy sees, as "id@hex".
func _seen(g: Game) -> PackedStringArray:
	var out := PackedStringArray()
	for a: Army in g.armies:
		if a.tag == S or Sight.sees(g, S, a.hex):
			out.append("%d@%s" % [a.id, a.hex])
	return out


func _first(lines: Array[String]) -> String:
	return "%d difference(s), the first: %s" % [lines.size(), "\n".join(lines.slice(0, 6))]


func test_the_two_games_differ_only_in_armies_savoy_does_not_see() -> void:
	for thin: bool in [false, true]:
		var a := _scene(thin)
		var b := _scene(thin)
		_differ(b)
		assert_ne(a.digest(), b.digest(), "the games differ")
		assert_eq(_seen(b), _seen(a), "thin %s: the same armies in sight" % thin)
		assert_eq(Armies.of_country(a, S).size(), 2, "Savoy has two armies")
		assert_true(bool(a.check("continue_march", {"army": Armies.of_country(a, S)[1].id, "tag": S})["ok"]), "one to continue")
		assert_gt(b.armies.size(), a.armies.size())


func test_every_order_gets_the_same_answer_on_the_duel() -> void:
	var a := _scene(false)
	var b := _scene(false)
	_differ(b)
	var found := _diff_orders(a, b, _all_hexes(a))
	assert_eq(found.size(), 0, _first(found))


func test_every_order_gets_the_same_answer_on_the_thin_duel() -> void:
	var a := _scene(true)
	var b := _scene(true)
	_differ(b)
	var found := _diff_orders(a, b, _all_hexes(a))
	assert_eq(found.size(), 0, _first(found))


## One hidden army at a time, on each of the unseen hexes nearest the fixture army: the orders round it.
func test_a_hidden_army_anywhere_near_changes_no_answer() -> void:
	for thin: bool in [false, true]:
		var a := _scene(thin)
		Armies.remove(a, MovesFixture.named(a, MovesFixture.NAME_UNSEEN))
		Sight.refresh(a)
		a.version += 1
		var home := MovesFixture.named(a, MovesFixture.NAME_HOME)
		var found: Array[String] = []
		var spots := _unseen_near(a, home.hex).slice(0, SWEEP)
		assert_eq(spots.size(), SWEEP)
		for spot: Vector2i in spots:
			var b := _scene(thin)
			Armies.set_hex(b, MovesFixture.named(b, MovesFixture.NAME_UNSEEN), spot, Army.NO_HEX)
			Sight.refresh(b)
			b.version += 1
			found.append_array(_diff_orders(a, b, _within(a, spot, REACH)))
		assert_eq(found.size(), 0, "thin %s: %s" % [thin, _first(found)])


## R57 for a shaken army: an order onto a hex where an army out of sight stands is answered as onto an empty one.
func test_a_shaken_army_learns_nothing_of_a_hidden_army() -> void:
	var a := _scene(false)
	var b := _scene(false)
	var spot := MovesFixture.named(b, MovesFixture.NAME_UNSEEN).hex
	Armies.remove(a, MovesFixture.named(a, MovesFixture.NAME_UNSEEN))
	for g: Game in [a, b]:
		var home := MovesFixture.named(g, MovesFixture.NAME_HOME)
		for u: Unit in home.units:
			Armies.set_morale(g, home, u.id, SHAKEN_MORALE)
		Sight.refresh(g)
		g.version += 1
	assert_false(Sight.sees(b, S, spot), "the army is out of sight")
	var found := _diff_orders(a, b, [spot] as Array[Vector2i])
	assert_eq(found.size(), 0, _first(found))


## R57 for the stack limit: with another army of Savoy marching to the hex, the order's answer does not tell whether an army
## out of sight stands there.
func test_the_room_at_a_hex_tells_nothing_of_a_hidden_army() -> void:
	var a := _scene(false)
	var b := _scene(false)
	var spot := MovesFixture.named(b, MovesFixture.NAME_UNSEEN).hex
	Armies.remove(a, MovesFixture.named(a, MovesFixture.NAME_UNSEEN))
	for g: Game in [a, b]:
		var home := MovesFixture.named(g, MovesFixture.NAME_HOME)
		var other := ArmyFixture.army(g, S, home.hex, 0, g.defs.stack_limit - 1)
		var plan := Movement.plan(g, other, spot)
		assert_true(bool(plan.ok), "the other army has a way")
		Armies.set_order(g, other, Army.ORDER_MARCH, spot, plan.hexes)
		Sight.refresh(g)
		g.version += 1
	assert_false(Sight.sees(b, S, spot), "the army is out of sight")
	var found := _diff_orders(a, b, [spot] as Array[Vector2i])
	assert_eq(found.size(), 0, _first(found))


## P: a leg read from the engine's own walk (MarchLeg.leg, which a zone of control ends whether the army is seen or not) moves
## with an army out of sight; the preview's leg for the same order does not.
func test_p_a_leg_end_read_from_the_engines_leg_moves_with_an_unseen_army() -> void:
	var a := _scene(false)
	Armies.remove(a, MovesFixture.named(a, MovesFixture.NAME_UNSEEN))
	Sight.refresh(a)
	a.version += 1
	var home := MovesFixture.named(a, MovesFixture.NAME_HOME)
	var steps := StepCosts.of(a.map, a.defs)
	var leaked := 0
	for spot: Vector2i in _unseen_near(a, home.hex).slice(0, SWEEP):
		var b := _scene(false)
		Armies.set_hex(b, MovesFixture.named(b, MovesFixture.NAME_UNSEEN), spot, Army.NO_HEX)
		Sight.refresh(b)
		b.version += 1
		var other := MovesFixture.named(b, MovesFixture.NAME_HOME)
		for goal: Vector2i in _within(a, spot, REACH):
			var plan := Movement.plan(a, home, goal)
			if goal == spot or not bool(plan.ok) or not bool(a.check("march", {"army": home.id, "goal": goal, "tag": S})["ok"]):
				continue
			var ends: Array[int] = []
			for pair: Array in [[a, home], [b, other]]:
				var probe := (pair[1] as Army)
				var was := [probe.order, probe.goal, probe.route]
				Armies.set_order(pair[0], probe, Army.ORDER_MARCH, goal, plan.hexes)
				ends.append(MarchLeg.leg(pair[0], steps, probe, false, probe.points, false).end)
				Armies.set_order(pair[0], probe, was[0], was[1], was[2])
			if ends[0] != ends[1]:
				leaked += 1
				assert_eq(MovePreview.leg_of(b, S, other.id, goal)["end"], MovePreview.leg_of(a, S, home.id, goal)["end"],
					"the preview's leg to %s keeps its end" % goal)
		if leaked > 0:
			break
	assert_gt(leaked, 0, "an unseen army moves the engine's leg end somewhere: the comparison can fail")


## Multi-leg marches (MV19, R67): orders with stops on and round the hexes where copy B hides armies (one stop, then two) get
## the same check and the same MovePreview.via (verdict, legs, total, leg, risks, lines) in both games, on duel() and thin().
func test_orders_with_stops_get_the_same_answer() -> void:
	for thin: bool in [false, true]:
		var a := _scene(thin)
		var b := _scene(thin)
		_differ(b)
		var home := MovesFixture.named(a, MovesFixture.NAME_HOME)
		var stops := _unseen_near(a, home.hex).slice(0, 8)
		var found: Array[String] = []
		for army: Army in Armies.of_country(a, S):
			var other := Armies.by_id(b, army.id)
			for k: int in stops.size():
				var plans: Array = [[stops[k]], [stops[k], stops[(k + 3) % stops.size()]]]
				for raw: Array in plans:
					var via: Array[Vector2i] = []
					via.assign(raw)
					for goal: Vector2i in _within(a, stops[k], 2):
						var args := {"army": army.id, "goal": goal, "tag": S, "via": via}
						var x := str(a.check("march", args))
						var y := str(b.check("march", args))
						if x != y:
							found.append("march of %s by %s to %s: %s against %s" % [army.name, via, goal, x, y])
						var px := MovePreview.via(a, S, army.id, via, goal)
						var py := MovePreview.via(b, S, other.id, via, goal)
						if str(px) != str(py):
							for field: String in px:
								if str(px[field]) != str(py.get(field)):
									found.append("via.%s of %s by %s to %s: %s against %s" % [field, army.name, via, goal, px[field],
										py.get(field)])
		assert_eq(found.size(), 0, "thin %s: %s" % [thin, _first(found)])
