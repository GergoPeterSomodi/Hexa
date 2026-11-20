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


func _new_game() -> Game:
	var defs := load(DEFS_PATH) as GameDefs
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
func _play(save: bool) -> Dictionary:
	var g := _new_game()
	var luck := Rng.new()
	luck.seed_with(SEED)
	var ready := {}
	var digests: Array[String] = []
	var finished_total := 0
	var begun_total := 0
	for n: int in SEASONS:
		var before := g.state.works.size()
		_begin_works(g, luck, ready)
		begun_total += g.state.works.size() - before
		var ended := g.turn
		assert_true(bool(Season.run(g)["ok"]))
		assert_eq(g.turn, ended + 1)
		_check_state(g, n + 1)
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


func test_forty_seasons_hold_the_invariants() -> void:
	var run := _play(false)
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
