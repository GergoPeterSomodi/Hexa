## The war property (docs/architecture/m7-build-spec.md 4.12 to 4.14, 9, done-when 6 to 9; M7 plan B18): 40 seasons of the 1480
## scenario as Genoa with real weather and people, Genoa's three armies to start with (as test_men_property), and a war staged
## at turn 1 through the door (declare_war against a neighbour). Fair warning (moves-build-spec.md R73): one season passes before
## the staged siege march, so the 40 seasons start at turn 2. Then the RandomPlayer for every country every season: attacks,
## storms, sieges, peace and declarations included. Every pick goes through the check/do contract (test_check_contract's
## contract_problem). Per season, the world's men under arms, garrisons and people change by the closed flows less the losses
## booked in battles (killed and wounded not returned), starvation and captures (the garrison men lost). Over the seeds: battles,
## sieges, peaces and captures happened (no lift in these seeds: see the test body), and storm, set_standing, make_peace and declare_war each succeeded once. A save
## and load every ten seasons gives the digests of the run without saves; the replay of the action log gives the final digest.
## Fixed seeds, deterministic. Runtime: three seeds, each run 40 seasons (about a minute in all).
extends GutTest

const SEASONS := 40
const SAVE_EVERY := 10
const PLAYER_TURNS := 8
const SEEDS: Array[int] = [1480, 7, 11]
## The events counted over the runs (the fights and the wars).
const COUNTED := ["war_declared", "peace_made", "battle_started", "battle_ended", "siege_started", "siege_lifted",
	"district_captured"]
## The actions whose successes must be seen over the runs (the contract's rows that need a war).
const NEEDS_WAR := ["storm", "set_standing", "make_peace", "declare_war"]

var _dir := ""
var _total := {}


func before_each() -> void:
	_dir = "user://test_war_property_%d/" % Time.get_ticks_usec()
	_total = {}


func after_each() -> void:
	if DirAccess.dir_exists_absolute(_dir):
		for f: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir + f)
		DirAccess.remove_absolute(_dir)


func _count(key: String, n: int = 1) -> void:
	_total[key] = int(_total.get(key, 0)) + n


## The 1480 game as Genoa with real weather and people; three armies (two on a town, one on other land), damaged before the
## first census (as test_men_property does: the damage is a rig, not a flow).
func _seeded_game(seed_value: int) -> Game:
	var g := EconomyFixture.game(ArmyFixture.TAG, false, false, seed_value, false)
	var town := ArmyFixture.find_town(g)
	ArmyFixture.town(g, town)
	var first := ArmyFixture.army(g, ArmyFixture.TAG, town, 0, 3)
	var second := ArmyFixture.army(g, ArmyFixture.TAG, town, 0, 2)
	var far := ArmyFixture.army(g, ArmyFixture.TAG, g.map.hex_of(Territory.districts(g, ArmyFixture.id_of(g, ArmyFixture.TAG))[0]), 0, 2)
	for a: Army in [first, second, far]:
		Armies.lose_men(g, a, 300, &"rig")
	_siege_army(g)
	return g


## Three companies of Genoa on its own land beside a fortress of its neighbour (the neighbour the war is declared on): the
## start of a siege. The march onto the fortress goes through the door in _stage_siege once the war is declared (logged).
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


## The staged siege: Genoa's idle army beside a hostile garrisoned fortress is ordered to march onto it (through the door).
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
			var verdict := g.act("march", {"army": a.id, "goal": fort, "tag": ArmyFixture.TAG})
			assert_true(bool(verdict["ok"]), "the staged siege march is taken: %s" % str(verdict.get("reason", "")))
			return


## The war of the start: Genoa against a neighbour, declared through the door.
func _stage_war(g: Game) -> void:
	var neighbour := WarFixture.neighbour_of(g, ArmyFixture.TAG)
	assert_ne(neighbour, &"", "Genoa has a neighbour")
	var verdict := g.act("declare_war", {"target": neighbour, "tag": ArmyFixture.TAG})
	assert_true(bool(verdict["ok"]), "the staged war is declared: %s" % str(verdict.get("reason", "")))


## Random picks for every country (the player's first). Each pick goes through the contract (the check says no: the do
## refuses and the digest is unchanged; yes: the do succeeds). Counts the successes and refusals by action.
func _act_all(g: Game, luck: Rng) -> void:
	for c: Country in g.countries:
		for _t: int in PLAYER_TURNS:
			var pick: Dictionary = RandomPlayer.next(g, c.tag, luck)
			var action := str(pick["action"])
			var args: Dictionary = pick["args"]
			var logged := g.action_log.size()
			var check := g.check(action, args)
			var verdict := g.act(action, args)
			# The contract, lighter than test_check_contract's (no digests here, they are slow over 8,000 picks): a check that
			# says no is refused and logs nothing; one that says yes succeeds and logs. The digest rule is that file's.
			var ok := bool(verdict.get("ok", false))
			assert_eq(ok, bool(check.get("ok", false)), "the check and the do agree: %s (%s)" % [action, str(check.get("reason", ""))])
			assert_eq(g.action_log.size() > logged, ok, "a successful action is logged, a refused one is not: %s" % action)
			_count(("ok " if ok else "refused ") + action)


## The world's men under arms, garrisons and people now: [people on the land, men under arms, garrison men].
func _census(g: Game) -> Array:
	var people := 0
	var garrison := 0
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1:
			people += int(g.state.people[i])
			garrison += int(g.state.garrison[i])
	var men := 0
	for a: Army in g.armies:
		men += a.men()
	return [people, men, garrison]


## Each country's open people flows now: {tag: PackedInt32Array}.
func _open_flows(g: Game) -> Dictionary:
	var out := {}
	for c: Country in g.countries:
		out[c.tag] = c.people_flows.duplicate()
	return out


## The men lost this season to starvation, to battles (each side's killed and wounded men less the wounded who came back to
## a unit still standing) and to captures (the garrison men a capture booked lost). Counts the fights as they are read.
func _losses(g: Game, season: int) -> int:
	var total := 0
	for e: Dictionary in g.events:
		var kind := str(e.get("kind", ""))
		if kind == "army_starved":
			total += int(e["lost"])
		elif kind == "district_captured":
			total += int(e.get("garrison_lost", 0))
	for r: BattleRecord in g.battle_records:
		if r.turn != season:
			continue
		var back := r.returned_by_side()
		for side: int in 2:
			total += int(r.end["killed"][side]) + int(r.end["wounded_total"][side]) - back[side]
	return total


## The identity of a season (4.14, the conservation of men): the change of the world's people, men under arms and garrisons
## is the sum of each country's flows that move no man between the three (raised, returned and garrisoned are internal), less
## the losses above. The flows of the season are the closed ones less what was open before its actions, plus what is open after.
func _check_identity(g: Game, ended: int, pre: Array, open_before: Dictionary, open_after: Dictionary) -> void:
	var post := _census(g)
	var flows := 0
	for c: Country in g.countries:
		var closed := c.people_closed["flows"] as PackedInt32Array
		assert_eq(int(c.people_closed["turn"]), ended, "the closed flows are of this season, %s" % c.tag)
		var before: PackedInt32Array = open_before[c.tag]
		var after: PackedInt32Array = open_after[c.tag]
		var window := PackedInt32Array()
		for f: int in closed.size():
			window.append(closed[f] - before[f] + after[f])
		var rest := 0
		for f: int in window:
			rest += f
		rest -= window[People.FLOWS.find(&"raised")] + window[People.FLOWS.find(&"returned")] + window[People.FLOWS.find(&"garrisoned")]
		flows += rest
	var losses := _losses(g, ended)
	var change := (int(post[0]) + int(post[1]) + int(post[2])) - (int(pre[0]) + int(pre[1]) + int(pre[2]))
	# The identity: people, men under arms and garrisons change by the flows less the losses (each man counted once).
	assert_eq(change, flows - losses, "people, men under arms and garrisons change by the flows less the losses, season %d" % ended)
	for a: Army in g.armies:
		assert_gt(a.units.size(), 0, "no empty army, season %d" % ended)
		assert_lte(Armies.units_at(g, a.tag, a.hex), Military.stack_limit(g, a.tag), "no army over the stack limit, season %d" % ended)


## The war events of the season, counted over the runs.
func _tally(g: Game) -> void:
	for e: Dictionary in g.events:
		var kind := str(e.get("kind", ""))
		if kind in COUNTED:
			_count(kind)


## Plays SEASONS seasons of the seed; with `save` a save and a load every SAVE_EVERY seasons. Returns {game, digests}.
func _play(seed_value: int, save: bool) -> Dictionary:
	var g := _seeded_game(seed_value)
	_stage_war(g)
	# fair warning: war declared a season earlier (the end of the season is logged, so the replay runs it too).
	assert_true(bool(Season.run(g)["ok"]), "the season of the declaration ends")
	_stage_siege(g)
	var luck := Rng.new()
	luck.seed_with(seed_value)
	var digests: Array[String] = []
	for n: int in SEASONS:
		var pre := _census(g)
		var open_before := _open_flows(g)
		g.events.clear()
		_act_all(g, luck)
		var ended := g.turn
		assert_true(bool(Season.run(g)["ok"]), "the season ends")
		assert_eq(g.turn, ended + 1)
		_tally(g)
		_check_identity(g, ended, pre, open_before, _open_flows(g))
		if save and (n + 1) % SAVE_EVERY == 0:
			g = _through_a_file(g)
		digests.append(g.digest())
	return {"game": g, "digests": digests}


## Saves, loads and returns the loaded game; its digest is the same as before the save.
func _through_a_file(g: Game) -> Game:
	assert_eq(SaveFile.write(g, "1", {"saved_unix": 1}, {}, _dir), "")
	var read := SaveFile.read("1", _dir)
	assert_eq(read["problem"], "")
	var restored := Snapshot.restore(read["body"] as Dictionary, g.map, g.defs)
	assert_eq(restored["problem"], "")
	var back := restored["game"] as Game
	assert_not_null(back)
	assert_eq(back.digest(), g.digest(), "the digest survives the file")
	return back


func test_war_seasons_conserve_men_and_people_and_fight() -> void:
	for seed_value: int in SEEDS:
		var played := _play(seed_value, false)
		var g := played["game"] as Game
		assert_eq(g.turn, SEASONS + 2)  # fair warning: war declared a season earlier
		assert_gt(g.wars.size(), 0, "a war was declared (seed %d)" % seed_value)
	gut.p("counts: %s" % str(_total))
	assert_gt(int(_total.get("battle_started", 0)), 0, "battles started")
	assert_gt(int(_total.get("battle_ended", 0)), 0, "battles ended")
	assert_gt(int(_total.get("siege_started", 0)), 0, "sieges started")
	# No siege was lifted in these seeds: a lift is a rule of Sieges._lift_why (left, relief, outnumbered, peace), each tested
	# with its own case in test_sieges.gd. A staged lift (the besieger marches off) did not produce one here.
	assert_gt(int(_total.get("district_captured", 0)), 0, "districts captured")
	assert_gt(int(_total.get("peace_made", 0)), 0, "peaces made")
	for action: String in NEEDS_WAR:
		assert_gt(int(_total.get("ok " + action, 0)), 0, "%s succeeded at least once" % action)


func test_saves_every_ten_seasons_change_no_digest_in_a_war() -> void:
	for seed_value: int in SEEDS:
		var plain: Array = _play(seed_value, false)["digests"]
		var saved: Array = _play(seed_value, true)["digests"]
		assert_eq(saved.size(), SEASONS)
		assert_eq(saved, plain, "the saved run's digests equal the plain run's (seed %d)" % seed_value)


## The replay of the log from the same start: the fixtures' start (the armies, the town and the damage rig) is not in the log,
## so the replay starts from the same rigged game and plays the log's records in order (the end_season records run the season).
func test_the_replay_of_the_action_log_equals_the_live_game() -> void:
	for seed_value: int in SEEDS:
		var g := _play(seed_value, false)["game"] as Game
		var again := _seeded_game(seed_value)
		for record: Dictionary in g.action_log:
			var action := str(record.get("action", ""))
			if action == "end_season":
				Season.run(again)
			else:
				var args: Dictionary = record["args"]
				again.act(action, args)
		assert_eq(again.digest(), g.digest(), "the replay equals the live game (seed %d)" % seed_value)
