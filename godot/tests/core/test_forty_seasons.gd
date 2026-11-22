## The forty-season rig (docs/architecture/m3-build-spec.md 9): the 1480 scenario as Genoa, each season works begin at
## random valid options up to the free slots (seeded), 40 seasons. Every season: slots never exceeded, every work on its
## owner's land, one work a hex, `stats.count` equals the seasons, the chronicle at most 3,000; every work finishes in the
## turn `WorksView.ready_turn` said when it began; a save and load every 10 seasons gives the same final digest as the run
## without saves; the season summary is equal before and after each load. Determinism and save round trip (spec 9).
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"
const TAG := &"GEN"
const SEASONS := 40
const SAVE_EVERY := 10
const SEED := 1480

var _dir := ""


func before_each() -> void:
	_dir = "user://test_forty_seasons_%d/" % Time.get_ticks_usec()


func after_each() -> void:
	if DirAccess.dir_exists_absolute(_dir):
		for f: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir + f)
		DirAccess.remove_absolute(_dir)


## `calm` forces calm weather (the save round trip: Snapshot carries the weather from N5 on); false plays the real odds.
func _new_game(calm: bool = true) -> Game:
	var defs := EconomyFixture.defs(calm, false)  # the people really change (M5)
	var g := Game.new_scenario(load(MAP_PATH) as MapData, defs, defs.scenarios[defs.scenarios.size() - 1], SEED)
	assert_true(bool(g.act("choose_country", {"tag": TAG})["ok"]))
	return g


## Begins works at random valid options until the slots are full (or 40 tries fail). `ready` maps work id to the turn
## `WorksView.ready_turn` gave when it began.
func _begin_works(g: Game, luck: Rng, ready: Dictionary) -> void:
	var country := Countries.by_tag(g, TAG)
	var districts := Territory.districts(g, country.id)
	var tries := 0
	while Works.in_use(g, TAG) < Works.slots(g, TAG) and tries < 40:
		tries += 1
		var hex := g.map.hex_of(districts[luck.randi_range(0, districts.size() - 1)])
		var verdict: Dictionary
		var kind := luck.randi_range(0, 5)
		if kind == 0:
			verdict = g.act("upgrade", {"hex": hex, "tag": TAG})
		elif kind == 1:
			verdict = g.act("clear", {"hex": hex, "tag": TAG})
		else:
			var options: Array[Dictionary] = []
			for o: Dictionary in g.improvement.build_options(hex):
				if bool(o["ok"]):
					options.append(o)
			if options.is_empty():
				continue
			var pick := options[luck.randi_range(0, options.size() - 1)]
			verdict = g.act("build", {"hex": hex, "family": int(pick["family_id"]), "tag": TAG})
		if bool(verdict["ok"]):
			var work := g.state.work_at(hex)
			assert_not_null(work, "an accepted works action adds a work")
			ready[work.id] = WorksView.ready_turn(g, work)


## Six random actions of the random player for the country (raises, marches, splits, merges, disbands, halts; L13): the
## armies go through the door, so a save and load carries them (the digests of every season are compared).
func _random_armies(g: Game, luck: Rng) -> void:
	for _k: int in 6:
		var pick: Dictionary = RandomPlayer.next(g, TAG, luck)
		# declare_war is not played here until the snapshot carries game.wars (M7 B13): a load would forget the war.
		if str(pick["action"]) == "declare_war":
			continue
		g.act(str(pick["action"]), pick["args"])


func _check_state(g: Game, seasons_done: int) -> void:
	var label := "after season %d" % seasons_done
	assert_lte(Works.in_use(g, TAG), Works.slots(g, TAG), "slots, " + label)
	var seen := {}
	for w: Work in g.state.works:
		assert_eq(Territory.owner_tag(g, w.hex), TAG, "a work on its owner's land, " + label)
		assert_false(seen.has(w.hex), "one work a hex, " + label)
		seen[w.hex] = true
	assert_eq(g.stats.count, seasons_done, "stats.count, " + label)
	assert_lte(g.chronicle.entries.size(), Chronicle.KEEP, "the chronicle is bounded, " + label)
	_check_people(g, label)


## The people invariants (m5-build-spec.md 4.12, done-when 2 and 3): no hex under 0 or past the cap, none at sea; for every
## country the change of its people over the season ended equals its closed flows; the stats people are the sum.
func _check_people(g: Game, label: String) -> void:
	var state := g.state
	var by_owner := {}
	var world_change := 0
	var world_flows := 0
	for i: int in g.map.hex_count():
		var p := int(state.people[i])
		assert_gte(p, 0, "no hex below 0, " + label)
		assert_lte(p, People.PEOPLE_MAX, "the cap, " + label)
		if g.map.land[i] == 0:
			assert_eq(p, 0, "no people at sea, " + label)
		var id := int(state.owner[i])
		by_owner[id] = int(by_owner.get(id, 0)) + int(state.people_end[i]) - int(state.people_start[i])
		world_change += int(state.people_end[i]) - int(state.people_start[i])
		assert_eq(p, int(state.people_end[i]), "the season just closed: people equal people_end, " + label)
	for c: Country in g.countries:
		var flows: PackedInt32Array = c.people_closed["flows"]
		var sum := 0
		for f: int in flows:
			sum += f
		world_flows += sum
		assert_eq(int(by_owner.get(c.id, 0)), sum, "%s: the change equals the closed flows, %s" % [c.tag, label])
		assert_eq(c.people_flows.count(0), c.people_flows.size(), "the open flows start again from zero, " + label)
	assert_eq(world_change, world_flows, "the world's change is the sum of the flows, " + label)
	var live := 0
	for i: int in g.map.hex_count():
		if int(state.owner[i]) == Countries.by_tag(g, TAG).id:
			live += int(state.people[i])
	assert_eq(g.stats.value(TAG, g.turn - 1, "people"), live, "the stats people, " + label)


## Every tracked work that is gone must have finished in the turn promised (a cancelled one is dropped from the list);
## one still there must not be due.
func _check_ready(g: Game, ended_turn: int, ready: Dictionary) -> void:
	var finished := {}
	for entry: Dictionary in g.chronicle.of_turn(ended_turn):
		if str(entry.get("kind", "")) == "work_finished":
			finished[int((entry["work"] as Dictionary)["id"])] = true
	var under_way := {}
	for w: Work in g.state.works:
		under_way[w.id] = true
	for id: int in ready.keys():
		if under_way.has(id):
			assert_gt(int(ready[id]), g.turn, "work %d is not yet due at turn %d" % [id, g.turn])
		elif finished.has(id):
			assert_eq(g.turn, int(ready[id]), "work %d finished in the turn promised" % id)
			ready.erase(id)
		elif g.chronicle.entries.size() > 0:
			ready.erase(id)  # cancelled (lost or blocked) in an earlier or this season: nothing is promised


## Plays 40 seasons; with `save` a save and a load every SAVE_EVERY seasons. Returns {game, digests, finished}.
func _play(save: bool, calm: bool = true) -> Dictionary:
	var g := _new_game(calm)
	var luck := Rng.new()
	luck.seed_with(SEED)
	var ready := {}
	var digests: Array[String] = []
	var ledgers := {}
	var finished_total := 0
	var begun_total := 0
	for n: int in SEASONS:
		_fund(g, n)
		_cancel_one(g, luck)
		_random_armies(g, luck)
		var before := g.state.works.size()
		_begin_works(g, luck, ready)
		begun_total += g.state.works.size() - before
		var ended := g.turn
		assert_true(bool(Season.run(g)["ok"]))
		assert_eq(g.turn, ended + 1)
		_check_state(g, n + 1)
		_check_money_and_goods(g, ended, ledgers)
		_check_ready(g, ended, ready)
		for entry: Dictionary in g.chronicle.of_turn(ended):
			if str(entry.get("kind", "")) == "work_finished":
				finished_total += 1
		if save and (n + 1) % SAVE_EVERY == 0:
			g = _through_a_file(g)
		digests.append(g.digest())
	return {"game": g, "digests": digests, "finished": finished_total, "begun": begun_total}


## Saves, loads and returns the loaded game; the season summary of the last season is equal on both sides.
func _through_a_file(g: Game) -> Game:
	var summary := SeasonSummary.of(g, TAG, g.turn - 1)
	assert_eq(SaveFile.write(g, "1", {"saved_unix": 1}, {}, _dir), "")
	var read := SaveFile.read("1", _dir)
	assert_eq(read["problem"], "")
	var restored := Snapshot.restore(read["body"] as Dictionary, g.map, g.defs)
	assert_eq(restored["problem"], "")
	var back := restored["game"] as Game
	assert_not_null(back)
	assert_eq(back.digest(), g.digest(), "the digest survives the file")
	assert_eq(SeasonSummary.of(back, TAG, back.turn - 1), summary, "the summary is equal after the load")
	return back


## Money for the works and now and then a tax change (the console's door, so the ledgers see a `dev` line too).
func _fund(g: Game, n: int) -> void:
	if n % 3 == 0:
		assert_true(g.dev_money(TAG, 400))
	if n % 8 == 0:
		assert_true(g.dev_goods(TAG, 11, 20))
		assert_true(g.dev_goods(TAG, 12, 40))
	if n % 7 == 3:
		g.act("set_tax", {"level": int(n / 7.0) % 3, "tag": TAG})


## Cancels one work of TAG now and then: the refund is what it paid, in its first season only, and never more.
func _cancel_one(g: Game, luck: Rng) -> void:
	var mine: Array[Work] = []
	for w: Work in g.state.works:
		if w.tag == TAG:
			mine.append(w)
	if mine.is_empty() or luck.randi_range(0, 3) != 0:
		return
	var work := mine[luck.randi_range(0, mine.size() - 1)]
	var country := Countries.by_tag(g, TAG)
	var before := country.treasury
	var paid := work.paid
	var first_season := work.started_turn == g.turn
	g.events.clear()
	assert_true(bool(g.act("cancel_work", {"hex": work.hex, "tag": TAG})["ok"]))
	var refund := int(g.events[0]["refund"])
	assert_eq(country.treasury - before, refund, "the treasury got the refund")
	assert_lte(refund, paid, "a refund never exceeds what the work paid")
	if not first_season:
		assert_eq(refund, 0, "and there is none after its first season")


## Every season, for every country: the treasury changed by the closed ledger's lines (the console's and the works'
## included), the stock of every good by the closed flows; every line's reason is known; refunds never beyond the works'
## payments. `ledgers` carries the last closing of each country (the next opening continues from it).
func _check_money_and_goods(g: Game, ended: int, ledgers: Dictionary) -> void:
	for c: Country in g.countries:
		var closed := c.ledger_closed
		assert_eq(int(closed["turn"]), ended)
		var sum := 0
		var work := 0
		var raised := 0
		var refunds := 0
		for line: Dictionary in closed["lines"] as Array:
			assert_true(Treasury.WHY.has(line["why"]), "a known reason: %s" % line["why"])
			sum += int(line["amount"])
			if line["why"] == &"work":
				work -= int(line["amount"])
			elif line["why"] == &"raise":
				raised -= int(line["amount"])
			elif line["why"] == &"refund":
				refunds += int(line["amount"])
		assert_eq(int(closed["closing"]) - int(closed["opening"]), sum, "%s: treasury change == the lines' sum" % c.tag)
		assert_eq(int(closed["closing"]), c.treasury)
		# The refund reason is shared: a cancelled work gives back what it paid in its first season (M3 D14), and a disband
		# gives back the cost of a company raised this season on its home (M6 D10, Military.disband). Both are paid out of
		# this season's work and raise spending, so the bound is their sum (the refund of a company raised in an earlier season
		# is not allowed by Military.disband, so it never appears in this season's lines).
		assert_lte(refunds, work + raised, "%s: refunds never exceed what the works and the raises paid" % c.tag)
		if ledgers.has(c.tag):
			assert_eq(int(closed["opening"]), int(ledgers[c.tag]), "%s: the ledger continues from the last closing" % c.tag)
		ledgers[c.tag] = int(closed["closing"])
		assert_true(c.ledger_open.is_empty(), "the lines start again")
		var goods := c.goods_closed
		var count := (goods["closing"] as PackedInt32Array).size()
		var flows := goods["flows"] as PackedInt32Array
		for good: int in count:
			var net := 0
			for flow: int in Stores.FLOWS.size():
				net += flows[flow * count + good]
			assert_eq((goods["closing"] as PackedInt32Array)[good] - (goods["opening"] as PackedInt32Array)[good], net,
				"%s: stock change == the flows' sum, good %d" % [c.tag, good])
			assert_gte((goods["closing"] as PackedInt32Array)[good], 0)
		assert_eq(goods["closing"], c.stock)


func test_forty_seasons_hold_the_invariants() -> void:
	var run := _play(false, false)
	var g := run["game"] as Game
	assert_eq(g.turn, SEASONS + 1)
	assert_gt(int(run["begun"]), 10, "works were begun")
	assert_gt(int(run["finished"]), 0, "works finished")


func test_a_save_and_load_every_ten_seasons_gives_the_same_final_digest() -> void:
	var plain := _play(false)
	var saved := _play(true)
	assert_eq((saved["game"] as Game).digest(), (plain["game"] as Game).digest(), "the final digest")
	assert_eq(saved["digests"], plain["digests"], "every season's digest")


func test_the_same_run_twice_gives_the_same_digest() -> void:
	assert_eq((_play(false)["game"] as Game).digest(), (_play(false)["game"] as Game).digest())
