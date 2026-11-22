## No omniscience (docs/architecture/m8-build-spec.md 4.3, 9, done-when 3): a country's whole turn (its acts in order, its trace and its AI
## luck after) is the same when the facts it may not know are changed. The scene is Milan at war with Venice at Autumn 1481 with armies
## on both sides; copy B has, for what Milan does not see: Venice's armies moved to other unseen hexes, re-ordered and given other
## standing orders, every unseen garrison lowered by 200, Venice's treasury, stores and works edited, and the world's luck re-seeded.
## Then each AiKnow read on its own (the door's functions, one by one) is compared on the two copies, and a planted leak per read
## (the system call a cheat would make) is shown to differ, so the comparison can fail. P: a test-only step that reads
## Sieges.forecast instead of AiKnow.forecast gives different acts.
extends GutTest

const M := AiFixture.MILAN
const V := AiFixture.VENICE
const SEEN_ARMY := Vector2i(13, 5)
const HIDDEN_FROM_TO: Array = [[Vector2i(17, 5), Vector2i(19, 6)], [Vector2i(16, 9), Vector2i(17, 9)], [Vector2i(18, 2), Vector2i(20, 4)]]
const UNSEEN_FORT := Vector2i(15, 8)


## Milan (turn 7: Autumn 1481) at war with Venice, armies on both sides; Venice's on hexes Milan does not see, one it sees.
func _scene() -> Game:
	var g := AiFixture.duel()
	g.turn = 7
	WarFixture.at_war(g, M, V)
	WarFixture.army_at(g, M, Vector2i(11, 7), 4)
	WarFixture.army_at(g, M, Vector2i(9, 9), 3)
	WarFixture.army_at(g, V, SEEN_ARMY, 3)
	WarFixture.army_at(g, V, Vector2i(17, 5), 4)
	WarFixture.army_at(g, V, Vector2i(16, 9), 2)
	_refresh(g)
	return g


func _refresh(g: Game) -> void:
	Sight.refresh(g)
	g.version += 1


func _army_on(g: Game, tag: StringName, hex: Vector2i) -> Army:
	for a: Army in Armies.at(g, hex):
		if a.tag == tag:
			return a
	return null


## The facts Milan may not know, changed. Returns what was changed, for the sensitivity checks.
func _perturb(g: Game) -> Dictionary:
	var changed := {"armies": 0, "garrisons": 0}
	for pair: Array in HIDDEN_FROM_TO:
		var army := _army_on(g, V, pair[0] as Vector2i)
		assert_not_null(army, "a Venetian army stands on %s" % str(pair[0]))
		assert_false(Sight.sees(g, M, pair[0] as Vector2i) or Sight.sees(g, M, pair[1] as Vector2i), "both hexes are unseen")
		Armies.set_hex(g, army, pair[1] as Vector2i, Army.NO_HEX)
		Armies.set_order(g, army, Army.ORDER_MARCH, Vector2i(12, 7), PackedInt32Array())
		Armies.set_standing(g, army, Army.STANDING_WITHDRAW)
		Armies.lose_men(g, army, 300, &"test")
		changed["armies"] += 1
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if Occupation.fortress_level(g, hex) > 0 and Occupation.controller_tag(g, hex) != M and not Sight.sees(g, M, hex):
			g.state.garrison[i] = maxi(0, int(g.state.garrison[i]) - 200)
			changed["garrisons"] += 1
	var venice := Countries.by_tag(g, V)
	g.dev_money(V, 4321)
	for good: int in g.defs.goods.size():
		g.dev_goods(V, good, 17 + good)
	g.act("set_tax", {"tag": V, "level": 2 if venice.tax != 2 else 0})
	g.dev_money(V, 90000)
	for i: int in AiKnow.land_of(g, V):
		var hex := g.map.hex_of(i)
		if not g.map.is_land(hex) or Sight.sees(g, M, hex):
			continue
		for option: Dictionary in Improve.build_options(g, hex):
			if bool(option.get("ok", false)) and bool(g.act("build", {"hex": hex, "family": int(option["family_id"]), "tag": V}).get("ok", false)):
				changed["works"] = int(changed.get("works", 0)) + 1
				break
		if int(changed.get("works", 0)) >= 2:
			break
	g.luck.world.seed_with(987654)
	_refresh(g)
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
	assert_false(Sight.sees(g, M, Vector2i(17, 5)), "an unseen Venetian army")
	assert_true(Sight.sees(g, M, SEEN_ARMY), "a seen one")
	assert_false(Sight.sees(g, M, UNSEEN_FORT), "an unseen fortress")
	assert_gt(Occupation.garrison_of(g, UNSEEN_FORT), 200)
	assert_eq(AiKnow.seen_enemies(g, M).size(), 1, "Milan sees one Venetian army of the four")
	var changed := _perturb(_scene())
	assert_gte(int(changed["garrisons"]), 3, "unseen fortresses lowered")
	assert_eq(int(changed["armies"]), 3)
	assert_gte(int(changed.get("works", 0)), 1, "a work under way for Venice")


func test_the_same_turn_when_what_it_may_not_know_changes() -> void:
	var a := _scene()
	var b := _scene()
	_perturb(b)
	assert_ne(a.digest(), b.digest(), "the two games differ")
	var ta := _turn(a)
	var tb := _turn(b)
	assert_gt((ta["acts"] as PackedStringArray).size(), 5, "Milan acted: %s" % str(ta["acts"]))
	assert_true(" ".join(ta["acts"]).contains("march"), "and marched")
	assert_eq(tb["acts"], ta["acts"], "the same acts in the same order")
	assert_eq(tb["trace"], ta["trace"], "the same reasons")
	assert_eq(tb["luck"], ta["luck"], "the same AI luck")


func test_the_same_turn_over_the_other_seasons_and_the_other_country() -> void:
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


# ----- each read of the door, on the two copies ------------------------------------------------------------------------------


## What the door reads for Milan, as a list of {name, value}: every function that touches another country, over every other country,
## every fortress and every land hex near a Milan army.
func _reads(g: Game) -> Dictionary:
	var out := {}
	for c: Country in g.countries:
		if c.tag != M:
			out["men_of %s" % c.tag] = AiKnow.men_of(g, M, c.tag)
	out["seen_enemies"] = AiKnow.seen_enemies(g, M)
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
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
	for e: StringName in [V, &"AUS", &"MAN", &"FER"]:
		out["score %s" % e] = AiKnow.score(g, M, e)
		out["at_war_with_other %s" % e] = AiKnow.at_war_with_other(g, M, e)
	out["enemies"] = AiKnow.enemies(g, M)
	out["wars"] = AiKnow.wars_of(g, M)
	out["fortresses of VEN"] = AiKnow.fortresses_of(g, V)
	out["area states"] = AiKnow.area_state(g, Vector2i(13, 6))
	return out


func test_every_read_of_the_door_is_the_same_on_both_copies() -> void:
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
	# The system call a cheat would make in place of each door function; the perturbation must be visible through it.
	var a := _scene()
	var b := _scene()
	_perturb(b)
	var leaks: Dictionary = {
		"the real garrison of an unseen fortress": func(g: Game) -> Variant: return Occupation.garrison_of(g, UNSEEN_FORT),
		"the real forecast": func(g: Game) -> Variant: return Sieges.forecast(g, UNSEEN_FORT, M, 1500, 0, 0, 0),
		"Venice's armies, all of them": func(g: Game) -> Variant: return Armies.men_of_country(g, V),
		"an unseen Venetian army's hex": func(g: Game) -> Variant: return Armies.of_country(g, V)[0].hex,
		"an unseen Venetian army's order": func(g: Game) -> Variant: return Armies.of_country(g, V)[0].order,
		"Venice's treasury": func(g: Game) -> Variant: return Countries.by_tag(g, V).treasury,
		"Venice's stores": func(g: Game) -> Variant: return Countries.by_tag(g, V).stock,
		"Venice's works": func(g: Game) -> Variant: return g.state.works.size(),
		"the world's luck": func(g: Game) -> Variant: return g.luck.world.get_state(),
		"Venice's men under arms now": func(g: Game) -> Variant: return Wars.men_under_arms(g, V),
	}
	for name: String in leaks:
		var read := leaks[name] as Callable
		assert_ne(read.call(a), read.call(b), "a leak of %s shows" % name)


func test_p_a_step_that_reads_the_real_garrison_gives_other_acts() -> void:
	var a := _scene()
	var b := _scene()
	_perturb(b)
	# The honest step (AiKnow.forecast) and the planted one (Sieges.forecast): the seasons a siege of each Venetian fortress
	# would take, in order; the choice is the quickest one.
	var honest_a := _pick(a, false)
	var honest_b := _pick(b, false)
	assert_eq(honest_b, honest_a, "AiKnow.forecast: the same pick")
	var leaky_a := _pick(a, true)
	var leaky_b := _pick(b, true)
	assert_ne(leaky_b, leaky_a, "Sieges.forecast: another pick (%s against %s)" % [str(leaky_b), str(leaky_a)])


## A test-only step: for each Venetian fortress Milan's first army could besiege, the seasons of the forecast; acts through the door
## a march to the quickest one.
func _pick(g: Game, leak: bool) -> Array:
	var army := AiKnow.own_armies(g, M)[0]
	var guns := AiKnow.guns_of(g, army)
	var seasons: Array = []
	for hex: Vector2i in AiKnow.fortresses_of(g, V):
		var n := Sieges.forecast(g, hex, M, army.men(), guns, 0, 0) if leak else AiKnow.forecast(g, M, hex, army.men(), guns)
		seasons.append([hex, n])
	return seasons


# ----- the leads: the odds card and the check ---------------------------------------------------------------------------------


func test_a_seen_garrison_moved_inside_its_hundred_changes_no_card() -> void:
	# A garrison Milan sees is read rounded to 100 (D49): 800 and 840 are the same to it, in every card it can ask.
	var a := _scene()
	var b := _scene()
	var fort := Vector2i(13, 6)
	assert_true(Sight.sees(b, M, fort))
	assert_eq(Occupation.garrison_of(b, fort), 800)
	b.state.garrison[b.map.index_of(fort)] = 840
	_refresh(b)
	for army: Army in AiKnow.own_armies(a, M):
		for storm: bool in [false, true]:
			var ca := AiKnow.odds(a, M, army, fort, storm)
			var cb := AiKnow.odds(b, M, army, fort, storm)
			assert_eq(var_to_bytes(cb), var_to_bytes(ca), "army %d storm %s: the same card" % [army.id, storm])
	assert_eq(AiKnow.garrison_estimate(b, M, fort), AiKnow.garrison_estimate(a, M, fort))


func test_a_seen_garrison_under_fifty_reads_as_none_in_every_card() -> void:
	# 20 men and 0 men are both "none" to a viewer who sees the hex (rounded to 100): the card's kind must not tell them apart.
	var a := _scene()
	var b := _scene()
	var fort := Vector2i(13, 6)
	a.state.garrison[a.map.index_of(fort)] = 0
	b.state.garrison[b.map.index_of(fort)] = 20
	_refresh(a)
	_refresh(b)
	assert_eq(AiKnow.garrison_estimate(a, M, fort), AiKnow.garrison_estimate(b, M, fort))
	for army: Army in AiKnow.own_armies(a, M):
		for storm: bool in [false, true]:
			var ca := AiKnow.odds(a, M, army, fort, storm)
			var cb := AiKnow.odds(b, M, army, fort, storm)
			assert_eq(cb["kind"], ca["kind"], "army %d storm %s: the kind of march" % [army.id, storm])
			# The check's own verdict (ok, reason, tone) is public to whoever asks, so it may differ; the card's numbers may not.
			for key: String in ["ok", "reason", "tone"]:
				ca.erase(key)
				cb.erase(key)
			assert_eq(var_to_bytes(cb), var_to_bytes(ca), "army %d storm %s: the card" % [army.id, storm])


func test_the_aims_of_every_army_are_the_same_and_include_an_unseen_fortress() -> void:
	var a := _scene()
	var b := _scene()
	_perturb(b)
	var ba := AiBrief.make(a, M)
	var bb := AiBrief.make(b, M)
	var unseen_besieged := 0
	for army: Army in AiKnow.own_armies(a, M):
		var la := AiWar.aims(a, ba, army)
		var lb := AiWar.aims(b, bb, army)
		assert_eq(var_to_bytes(lb), var_to_bytes(la), "aims of army %d" % army.id)
		for aim: Dictionary in la:
			if aim["kind"] == AiWar.BESIEGE and not Sight.sees(a, M, aim["goal"] as Vector2i):
				unseen_besieged += 1
	assert_gt(unseen_besieged, 0, "an unseen fortress is among the aims, counted at its full garrison")
