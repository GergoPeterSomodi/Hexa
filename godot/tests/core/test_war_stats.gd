## The seven war series of the stats (M7 B13 / spec 4.19: battle_losses, battles_won, battles_lost, districts_held, districts_lost,
## garrison_men, garrison_lost). A seeded war game with a siege and fights on the 1480 map: every season, each country's value of each
## series is recomputed from what the game kept (the battle records, the captures in the events, the map's owners, occupiers and
## garrisons) and compared with the stats the season wrote. Worked cases: the storm of a fortress (its garrison lost and the
## defender's men killed and wounded), a battle won and lost, a district held by an occupier and lost to it.
extends GutTest

const SEASONS := 10
const SEED := 1480


func _game() -> Game:
	var g := EconomyFixture.game(ArmyFixture.TAG, false, false, SEED, false)
	var town := ArmyFixture.find_town(g)
	ArmyFixture.town(g, town)
	var first := ArmyFixture.army(g, ArmyFixture.TAG, town, 0, 3)
	var second := ArmyFixture.army(g, ArmyFixture.TAG, town, 0, 2)
	var far := ArmyFixture.army(g, ArmyFixture.TAG, g.map.hex_of(Territory.districts(g, ArmyFixture.id_of(g, ArmyFixture.TAG))[0]), 0, 2)
	# The damage rig of test_war_property (before the first census: not a flow): the companies have men to lose in a fight.
	for a: Army in [first, second, far]:
		Armies.lose_men(g, a, 300, &"rig")
	_siege_army(g)
	var neighbour := WarFixture.neighbour_of(g, ArmyFixture.TAG)
	assert_true(bool(g.act("declare_war", {"target": neighbour, "tag": ArmyFixture.TAG})["ok"]), "the war is declared")
	_stage_siege(g)
	return g


## Three companies of Genoa beside a fortress of its neighbour (the start of the storm and the siege).
func _siege_army(g: Game) -> void:
	var neighbour := WarFixture.neighbour_of(g, ArmyFixture.TAG)
	var mine := ArmyFixture.id_of(g, ArmyFixture.TAG)
	for i: int in g.war_cache.fortresses(g):
		var fort := g.map.hex_of(i)
		if Occupation.garrison_of(g, fort) <= 0 or Occupation.controller_tag(g, fort) != neighbour:
			continue
		for d: int in 6:
			var n := g.map.neighbour(fort, d)
			var j := g.map.index_of(n)
			if j < 0 or g.map.land[j] != 1:
				continue
			var owner := int(g.state.owner[j])
			if owner == mine or owner == 0:
				ArmyFixture.army(g, ArmyFixture.TAG, n, 0, 3, 0)
				return


## The idle Genoa army beside a hostile garrisoned fortress marches onto it (a siege that becomes a storm or a siege).
func _stage_siege(g: Game) -> void:
	for a: Army in g.armies.duplicate():
		if a.tag != ArmyFixture.TAG or a.order != Army.ORDER_NONE:
			continue
		for i: int in g.war_cache.fortresses(g):
			var fort := g.map.hex_of(i)
			if ImproveRules.hex_distance(fort, a.hex) != 1:
				continue
			if Occupation.garrison_of(g, fort) <= 0 or not Wars.at_war(g, ArmyFixture.TAG, Occupation.controller_tag(g, fort)):
				continue
			g.act("march", {"army": a.id, "goal": fort, "tag": ArmyFixture.TAG})
			return


## The season's expected values: {series: {tag: value}} from the records, the events and the map.
func _expected(g: Game, season: int) -> Dictionary:
	var expect := {"battle_losses": {}, "battles_won": {}, "battles_lost": {}, "garrison_lost": {}, "districts_held": {},
		"districts_lost": {}, "garrison_men": {}}
	var owner_of := {}
	for a: Army in g.armies:
		for u: Unit in a.units:
			owner_of[u.id] = a.tag
	for r: BattleRecord in g.battle_records:
		if r.turn != season:
			continue
		var sides: Array[StringName] = [r.attacker, r.defender]
		var returned: Dictionary = r.end["returned"]
		for side: int in 2:
			var back := 0
			for uid: Variant in returned:
				if owner_of.get(int(uid), &"") == sides[side]:
					back += int(returned[uid])
			_add(expect["battle_losses"], sides[side], int(r.end["killed"][side]) + int(r.end["wounded_total"][side]) - back)
		var winner := int(r.end["winner"])
		# The record's loser is a tag (battle_end writes it); its side is the other side of the int winner.
		var loser := 1 - winner if winner >= 0 else -1
		if winner >= 0:
			_add(expect["battles_won"], sides[winner], 1)
		if loser >= 0:
			_add(expect["battles_lost"], sides[loser], 1)
	for e: Dictionary in g.events:
		if str(e.get("kind", "")) == "district_captured":
			_add(expect["garrison_lost"], StringName(str(e["owner"])), int(e.get("garrison_lost", 0)))
	for i: int in g.map.hex_count():
		var oc := int(g.state.owner[i])
		var oq := int(g.state.occupier[i])
		if oc > 0:
			var ot := g.countries[oc - 1].tag
			_add(expect["garrison_men"], ot, int(g.state.garrison[i]))
			if oq > 0 and oq != oc:
				_add(expect["districts_held"], g.countries[oq - 1].tag, 1)
				_add(expect["districts_lost"], ot, 1)
	return expect


func _add(table: Dictionary, tag: StringName, n: int) -> void:
	table[tag] = int(table.get(tag, 0)) + n


func test_the_seven_war_series_match_their_recomputation_every_season() -> void:
	var g := _game()
	var luck := Rng.new()
	luck.seed_with(SEED)
	var worked := {}
	for _n: int in SEASONS:
		g.events.clear()
		for c: Country in g.countries:
			for _t: int in 8:
				var pick: Dictionary = RandomPlayer.next(g, c.tag, luck)
				g.act(str(pick["action"]), pick["args"])
		var ended := g.turn
		Season.run(g)
		var expect := _expected(g, ended)
		for series: String in expect:
			var table: Dictionary = expect[series]
			for c: Country in g.countries:
				var want := int(table.get(c.tag, 0))
				assert_eq(g.stats.value(c.tag, ended, series), want, "%s of %s in season %d" % [series, c.tag, ended])
				if want != 0:
					worked[series] = int(worked.get(series, 0)) + 1
	gut.p("worked cells: %s" % str(worked))
	for series: String in ["battle_losses", "battles_won", "battles_lost", "garrison_lost", "garrison_men", "districts_held", "districts_lost"]:
		assert_gt(int(worked.get(series, 0)), 0, "the run worked %s (a non-zero value was checked)" % series)
