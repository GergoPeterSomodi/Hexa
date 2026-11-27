## The replay and the save of the moves in the month (moves-build-spec.md done-when 4, R55, R56; plan MV14). SEASONS seasons of
## the 1480 scenario with real weather and people: Savoy is the player and orders through the door every season (raises, marches,
## second moves, storms, halts, continues, a war whenever it has none), battles are fought in the orders, and the computer plays
## every other seat. Then: Replay.run of the whole action log gives the same digest (the AI's own luck stream put back, which a
## log cannot carry: the computer draws it while it thinks, and a replay does not think, as test_replay.gd's _no_ai); a save
## made at idle in the middle of a
## season (an army walked, a march standing) loads to the same digest, saves byte for byte the same, and plays on alike to the
## last season. R73 (MV20): no computer army meets fair warning. MV19 (R70, R71): some of Savoy's marches pass a stop (`via`),
## the replay and the save keep them, and I9 holds every season. P: the log with one march's goal changed replays to another
## digest.
extends GutTest

const S := &"SAV"
const M := &"MLO"
const SEED := 1480
const SEASONS := 20
## The first season the mid-season save may be made in.
const SAVE_FROM := 6
const MONEY := 20000
const GOODS := 200
## Orders tried for one army in a season: a first march, then a second with the points left.
const ORDERS_A_SEASON := 2
const SLOT := "1"

var _dir := ""


func before_each() -> void:
	_dir = "user://test_moves_replay_%d/" % Time.get_ticks_usec()


func after_each() -> void:
	if DirAccess.dir_exists_absolute(_dir):
		for f: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir + f)
		DirAccess.remove_absolute(_dir)


## The game at its start, everything after it logged: Savoy chosen and given money and goods (logged developer moves).
func _start(defs: GameDefs) -> Game:
	var g := Game.new_scenario(EconomyFixture.map(), defs, defs.scenarios[defs.scenarios.size() - 1], SEED)
	assert_true(bool(g.act("choose_country", {"tag": S})["ok"]))
	return g


## The computer's seats on `g`, counting in `counts` what its orders did, fair warning's meetings included.
func _attach(g: Game, counts: Dictionary) -> AiTurn:
	var hook := AiPlayers.attach(g)
	hook.judge = func(_tag: StringName, _action: String, _args: Dictionary, _verdict: Dictionary, result: Dictionary) -> void:
		var walk := result.get("walk", {}) as Dictionary
		if walk.is_empty():
			return
		_count(counts, "ai walks", 1 if int(walk["steps"]) > 0 else 0)
		_count(counts, "ai battles at once", 1 if int(walk["battle"]) >= 0 else 0)
		_count(counts, "ai warned", 1 if walk["stopped"] == FairWarning.WHY else 0)
	return hook


func _count(counts: Dictionary, key: String, n: int = 1) -> void:
	counts[key] = int(counts.get(key, 0)) + n


## An order of the player: counted when it is accepted.
func _order(g: Game, action: String, args: Dictionary, counts: Dictionary) -> void:
	var full := args.duplicate()
	full["tag"] = S
	if not bool(g.check(action, full)["ok"]):
		return
	var res := g.act(action, full)
	assert_true(bool(res["ok"]), "%s: the check said yes: %s" % [action, str(res.get("reason", ""))])
	_count(counts, action)
	if args.has("via"):
		_count(counts, "march with stops")
	var walk := res.get("walk", {}) as Dictionary
	if not walk.is_empty():
		_count(counts, "player walks", 1 if int(walk["steps"]) > 0 else 0)
		_count(counts, "player battles at once", 1 if int(walk["battle"]) >= 0 else 0)


## The places an army of Savoy may go: enemy armies in sight first, then the enemies' land nearest to it, then its own land.
func _goals(g: Game, a: Army, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var near: Array = []
	var foes := Wars.enemies(g, S)
	for other: Army in g.armies:
		if foes.has(other.tag) and Sight.sees(g, S, other.hex):
			near.append([ImproveRules.hex_distance(a.hex, other.hex), g.map.index_of(other.hex)])
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 1 and foes.has(Territory.owner_tag(g, hex)) and hex != a.hex:
			# every enemy hex ranks behind the armies in sight, in a drawn order among those about as near
			near.append([100 + 10 * ImproveRules.hex_distance(a.hex, hex) + rng.randi_range(0, 39), i])
	near.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	var out: Array[Vector2i] = []
	for n: Array in near.slice(0, 12):
		out.append(g.map.hex_of(n[1]))
	var own := Territory.districts(g, Countries.by_tag(g, S).id)
	for _k: int in 4:
		if not own.is_empty():
			out.append(g.map.hex_of(own[rng.randi_range(0, own.size() - 1)]))
	return out


## Savoy's orders of one season, drawn from the season's own seed: the same game gets the same orders.
func _play_orders(g: Game, counts: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED * 1000 + g.turn
	if g.turn % 3 == 1:
		g.dev_money(S, MONEY)
		for good: int in g.defs.goods.size():
			g.dev_goods(S, good, GOODS)
	if Wars.enemies(g, S).is_empty():
		_order(g, "declare_war", {"target": M}, counts)
	var own := Territory.districts(g, Countries.by_tag(g, S).id)
	var raised := 0
	for i: int in own:
		var args := {"hex": g.map.hex_of(i), "kind": rng.randi_range(0, g.defs.units.size() - 1), "count": 2, "tag": S}
		if raised < 2 and Armies.of_country(g, S).size() < 6 and bool(g.check("raise", args)["ok"]):
			_order(g, "raise", args, counts)
			raised += 1
	var ids: Array[int] = []
	for a: Army in Armies.of_country(g, S):
		ids.append(a.id)
	for id: int in ids:
		for k: int in ORDERS_A_SEASON:
			var a := Armies.by_id(g, id)
			if a == null:
				break
			if a.order == Army.ORDER_NONE and a.goal != Army.NO_HEX and rng.randi_range(0, 1) == 0:
				_order(g, "continue_march", {"army": id}, counts)
				continue
			if k == 1 and a.order == Army.ORDER_MARCH and rng.randi_range(0, 3) == 0:
				_order(g, "halt", {"army": id}, counts)
				continue
			for goal: Vector2i in _goals(g, a, rng):
				var action := "storm" if bool(g.check("storm", {"army": id, "goal": goal, "tag": S})["ok"]) else "march"
				var args := {"army": id, "goal": goal}
				if action == "march" and rng.randi_range(0, 2) == 0:
					_add_stop(g, a, args, own, rng)
				if bool(g.check(action, {"army": id, "goal": goal, "tag": S, "via": args.get("via", [])})["ok"]):
					_order(g, action, args, counts)
					break


## A stop for a march (MV19): one of Savoy's own hexes off the army's hex and the goal, kept when the march through it is allowed.
func _add_stop(g: Game, a: Army, args: Dictionary, own: PackedInt32Array, rng: RandomNumberGenerator) -> void:
	if own.is_empty():
		return
	var stop := g.map.hex_of(own[rng.randi_range(0, own.size() - 1)])
	var via: Array[Vector2i] = [stop]
	if stop != a.hex and stop != args["goal"] and bool(g.check("march", {"army": a.id, "goal": args["goal"], "tag": S,
			"via": via})["ok"]):
		args["via"] = via


## The end of a season; counts the computer's refusals of fair warning.
func _end_season(g: Game, hook: AiTurn, counts: Dictionary) -> void:
	assert_true(bool(Season.run(g)["ok"]), "the season ends")
	assert_eq(Invariants.stop_lines(g), PackedStringArray(), "I9 after the season")
	for c: Country in g.countries:
		for line: String in hook.trace_of(c.tag):
			if line.contains("refused") and line.contains(FairWarning.HINT_TEXT):
				_count(counts, "ai warned")


## True when the game is in the middle of a season worth saving: an army of Savoy has walked, and one of its marches stands.
func _mid_season(g: Game) -> bool:
	var walked := false
	var standing := false
	for a: Army in Armies.of_country(g, S):
		walked = walked or a.season_from != Army.NO_HEX
		standing = standing or a.order == Army.ORDER_MARCH
	return walked and standing


func _through_a_file(g: Game) -> Game:
	assert_eq(SaveFile.write(g, SLOT, {"saved_unix": 1}, {}, _dir), "")
	var read := SaveFile.read(SLOT, _dir)
	assert_eq(read["problem"], "")
	var restored := Snapshot.restore(read["body"] as Dictionary, g.map, g.defs)
	assert_eq(restored["problem"], "")
	return restored["game"] as Game


## The log replayed with no AI, the AI's luck stream put back from the live game (see the header).
func _replayed(g: Game, log: Array[Dictionary]) -> Game:
	var again := Replay.run(g.map, g.defs, g.scenario.id, g.seed_value, log)
	again.luck.ai.set_state(g.luck.ai.get_state())
	return again


## The whole game: {game, counts, loaded (the game saved mid-season and played on), digests, loaded_digests, saved_turn}.
func _play() -> Dictionary:
	var defs := EconomyFixture.defs(false, false)
	var g := _start(defs)
	var counts := {}
	var hook := _attach(g, counts)
	var loaded: Game = null
	var loaded_hook: AiTurn = null
	var out := {"game": g, "counts": counts, "digests": [] as Array[String], "loaded_digests": [] as Array[String],
		"saved_turn": -1}
	for n: int in SEASONS:
		_play_orders(g, counts)
		if loaded != null:
			_play_orders(loaded, {})
		elif n + 1 >= SAVE_FROM and _mid_season(g):
			loaded = _through_a_file(g)
			assert_eq(loaded.digest(), g.digest(), "the mid-season save loads to the same digest")
			assert_eq(var_to_bytes(Snapshot.of(loaded)), var_to_bytes(Snapshot.of(g)), "save, load, save: byte-equal")
			for a: Army in g.armies:
				var b := Armies.by_id(loaded, a.id)
				assert_eq([b.points, b.season_from, b.order, b.goal, b.route, b.halt_why, b.via],
					[a.points, a.season_from, a.order, a.goal, a.route, a.halt_why, a.via], "army %d as it was" % a.id)
			loaded_hook = _attach(loaded, {})
			out["saved_turn"] = g.turn
		_end_season(g, hook, counts)
		(out["digests"] as Array[String]).append(g.digest())
		if loaded != null:
			_end_season(loaded, loaded_hook, {})
			(out["loaded_digests"] as Array[String]).append(loaded.digest())
	out["loaded"] = loaded
	return out


func test_twenty_seasons_replay_and_a_mid_season_save_plays_on_alike() -> void:
	var got := _play()
	var g := got["game"] as Game
	var counts := got["counts"] as Dictionary
	gut.p("saved in turn %d, counts %s" % [got["saved_turn"], str(counts)])
	assert_eq(g.turn, SEASONS + 1)
	for key: String in ["march", "march with stops", "raise", "declare_war", "player walks", "player battles at once", "ai walks",
			"ai battles at once"]:
		assert_gt(int(counts.get(key, 0)), 0, "the run has %s" % key)
	assert_eq(int(counts.get("ai warned", 0)), 0, "no computer army meets fair warning (R73)")
	assert_ne(got["saved_turn"], -1, "a mid-season save was made")
	var after := got["loaded_digests"] as Array[String]
	assert_gt(after.size(), 1, "seasons are played after the load")
	var digests := got["digests"] as Array[String]
	assert_eq(after, digests.slice(digests.size() - after.size()), "the loaded game plays on alike")
	assert_eq(_replayed(g, g.action_log).digest(), g.digest(), "the replay of the log gives the live digest")
	assert_eq(var_to_bytes(Snapshot.of(_through_a_file(g))), var_to_bytes(Snapshot.of(g)), "the last save is byte-equal")


## P: one march's goal changed in the log, and the replay's digest is another one.
func test_p_one_changed_march_argument_gives_another_digest() -> void:
	var g := _play()["game"] as Game
	var log: Array[Dictionary] = []
	for record: Dictionary in g.action_log:
		log.append(record.duplicate(true))
	var changed := -1
	for i: int in range(log.size() - 1, -1, -1):
		var record := log[i]
		if record["action"] != "march" or StringName(str((record["args"] as Dictionary)["tag"])) != S:
			continue
		changed = i
		break
	assert_ne(changed, -1, "the log holds a march of Savoy")
	assert_eq(_replayed(g, log).digest(), g.digest(), "the copy replays alike")
	var args := log[changed]["args"] as Dictionary
	var goal := args["goal"] as Vector2i
	var other := Army.NO_HEX
	# the replay up to the record, to find another goal the same army is allowed there
	var head: Array[Dictionary] = []
	head.assign(log.slice(0, changed))
	var then := _replayed(g, head)
	for i: int in then.map.hex_count():
		var hex := then.map.hex_of(i)
		var full := args.duplicate()
		full["goal"] = hex
		if hex != goal and ImproveRules.hex_distance(hex, goal) > 2 and bool(then.check("march", full)["ok"]):
			other = hex
			break
	assert_ne(other, Army.NO_HEX, "another goal is allowed")
	args["goal"] = other
	assert_ne(_replayed(g, log).digest(), g.digest(), "a march to %s in place of %s" % [other, goal])
