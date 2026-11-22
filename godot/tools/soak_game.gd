## One soak game (docs/architecture/m8-build-spec.md 4.17): builds the suite's game, plays its seasons with the AI and the invariants
## (tests/core/invariants.gd) every season, and returns the record tools/soak.gd tables. The first broken invariant ends the game
## with its lines. Tools only. `Judge` is the soak's counting judge (the AiTurn.judge Callable: AiJudge's contract rules without
## digests); `SoakLogger` counts the engine's and the scripts' errors (OS.add_logger; tools/probes/probe_logger.gd proves it).
@warning_ignore_start("integer_division")
class_name SoakGame
extends RefCounted

const FAKE_COLS := 494
const FAKE_ROWS := 247
const FAKE_COUNTRIES := 60
const FAKE_SEED := 1480
const WORK_ACTIONS: Array[String] = ["build", "upgrade", "clear"]
const ORDER_ACTIONS: Array[String] = ["march", "halt", "continue_march", "storm", "set_standing"]
## The seasons whose land is kept per country (the tuning reads them).
const LAND_AT: Array[int] = [20, 40, 80]
## The playable countries in id order (spec 4.17, `passive`): the seat is [(seed - 1) mod 10].
const PASSIVE_SEATS := 10


## Counts the engine's errors; reset per game.
class SoakLogger extends Logger:
	var count := 0
	var first := ""

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		count += 1
		if first.is_empty():
			first = "%s (%s:%d) %s %s" % [function, file, line, code, rationale]


## The AI's acts as the contract sees them (AiTurn.judge): the verdict must have been ok, the result ok, the tag the seat's.
class Judge extends RefCounted:
	var problems := PackedStringArray()
	var works: Dictionary = {}
	var orders := 0

	func on_act(tag: StringName, action: String, args: Dictionary, verdict: Dictionary, result: Dictionary) -> void:
		if not bool(verdict.get("ok", false)):
			problems.append("%s %s acted on a refused check" % [tag, action])
		if not bool(result.get("ok", false)):
			problems.append("%s %s was allowed by its check and failed: %s" % [tag, action, str(result.get("reason", ""))])
		if StringName(str(args.get("tag", ""))) != tag:
			problems.append("%s %s carries the tag %s" % [tag, action, str(args.get("tag", ""))])
		if WORK_ACTIONS.has(action) and bool(result.get("ok", false)):
			works[String(tag)] = int(works.get(String(tag), 0)) + 1
		if ORDER_ACTIONS.has(action):
			orders += 1

	func take_problems() -> PackedStringArray:
		var out := problems
		problems = PackedStringArray()
		return out


## Plays one game; {} fields as in tools/soak.gd. `plant` is "" or "money" (tests only: a treasury edited mid-game).
static func play(suite: String, seed_value: int, seasons: int, logger: SoakLogger, plant: String = "") -> Dictionary:
	var rec := {"suite": suite, "seed": seed_value, "seasons": seasons, "played": 0, "failure": [], "seat": ""}
	logger.count = 0
	logger.first = ""
	var judge := Judge.new()
	var g := _new_game(suite, seed_value, rec, judge)
	if g == null:
		rec["failure"] = ["setup: the game could not be built"]
		return rec
	var hook := g.orders as AiTurn
	var acc := {"ai": [] as Array[float], "stats": [] as Array[float], "season": [] as Array[float], "refused": 0, "seat_seasons": 0,
		"army_seasons": 0, "wars": 0, "ended_by_peace": 0, "ended": 0, "declared": {}, "won": {}, "lost": {}, "tax": {}, "land": {},
		"passive_declared": false, "passive_lost": false, "people_start": _people(g)}
	for n: int in seasons:
		g.events.clear()
		var before := Invariants.before(g)
		if plant == "money" and n == maxi(seasons / 2, 1):
			g.countries[0].treasury += 5  # a treasury edited outside its ledger: the `money` invariant must say so
		_season(g, acc)
		_tally(g, acc, rec)
		acc["refused"] = int(acc["refused"]) + hook.refusals()
		acc["seat_seasons"] = int(acc["seat_seasons"]) + hook.seats()
		acc["army_seasons"] = int(acc["army_seasons"]) + g.armies.size()
		rec["played"] = n + 1
		_remember(g, acc, n + 1)
		var lines := Invariants.check(g, before, {"contract": judge.take_problems(), "errors": logger.count})
		if not lines.is_empty():
			rec["failure"] = Array(lines)
			if not logger.first.is_empty():
				(rec["failure"] as Array).append("first error: " + logger.first)
			break
	_finish(g, acc, rec, judge)
	return rec


static func _new_game(suite: String, seed_value: int, rec: Dictionary, judge: Judge) -> Game:
	var g: Game = null
	var passive: Array[StringName] = []
	if suite == "europe":
		g = _europe(seed_value)
	else:
		var defs := EconomyFixture.defs(false, false)  # the real weather and the people really change
		g = Game.new_scenario(EconomyFixture.map(), defs, defs.scenarios[defs.scenarios.size() - 1], seed_value)
		if suite == "passive":
			var seats: Array[StringName] = []
			for c: Country in g.countries:
				if g.scenario.playable(c.tag):
					seats.append(c.tag)
			var seat := seats[(seed_value - 1) % mini(PASSIVE_SEATS, seats.size())]
			g.act("choose_country", {"tag": seat})
			passive.append(seat)
			rec["seat"] = String(seat)
	if g == null:
		return null
	if suite != "passive" and not g.watch():
		return null
	AiPlayers.attach(g, passive).judge = judge.on_act
	return g


static func _europe(seed_value: int) -> Game:
	var map := FakeMap.build(FAKE_COLS, FAKE_ROWS, FAKE_SEED)
	var built := FakeScenario.build(map, FAKE_COUNTRIES, FAKE_SEED)
	var defs := built["defs"] as GameDefs
	var real := EconomyFixture.committed()
	defs.families = real.families
	defs.goods = real.goods
	defs.work_slots_base = PerfFixture.WORK_SLOTS
	return Game.new_scenario(map, defs, built["scenario"] as ScenarioDef, seed_value)


## Season.run, phase by phase, timed: the AI's phase, the stats phase, the whole.
static func _season(g: Game, acc: Dictionary) -> void:
	var whole := Time.get_ticks_usec()
	Season.begin(g)
	for phase: StringName in Season.PHASES:
		var t := Time.get_ticks_usec()
		Season.run_phase(g, phase)
		if phase == &"ai_orders":
			(acc["ai"] as Array[float]).append(float(Time.get_ticks_usec() - t) / 1000.0)
		elif phase == &"stats":
			(acc["stats"] as Array[float]).append(float(Time.get_ticks_usec() - t) / 1000.0)
	Season.finish(g)
	(acc["season"] as Array[float]).append(float(Time.get_ticks_usec() - whole) / 1000.0)


## The season's events: wars declared, peaces (who won) and who was attacked while passive.
static func _tally(g: Game, acc: Dictionary, rec: Dictionary) -> void:
	for e: Dictionary in g.events:
		var kind := str(e.get("kind", ""))
		var tag := str(e.get("tag", ""))
		var target := str(e.get("target", ""))
		if kind == "war_declared":
			acc["wars"] = int(acc["wars"]) + 1
			_bump(acc["declared"], tag)
			if target == str(rec["seat"]):
				acc["passive_declared"] = true
		elif kind == "peace_made":
			var terms := str(e.get("terms", ""))
			var moved := (e.get("moved", []) as Array).size()
			if terms == "take":
				_bump(acc["won"], tag)
				_bump(acc["lost"], target)
				if target == str(rec["seat"]) and moved >= 1:
					acc["passive_lost"] = true
			elif terms == "yield":
				_bump(acc["won"], target)
				_bump(acc["lost"], tag)
				if tag == str(rec["seat"]) and moved >= 1:
					acc["passive_lost"] = true
	for c: Country in g.countries:
		var levels: Array = (acc["tax"] as Dictionary).get(String(c.tag), [0, 0, 0])
		levels[clampi(c.tax, 0, 2)] += 1
		acc["tax"][String(c.tag)] = levels


static func _bump(into: Dictionary, key: String) -> void:
	into[key] = int(into.get(key, 0)) + 1


## The land of every country at seasons 20, 40 and 80.
static func _remember(g: Game, acc: Dictionary, season: int) -> void:
	if not LAND_AT.has(season):
		return
	var land := {}
	for c: Country in g.countries:
		land[String(c.tag)] = Territory.districts(g, c.id).size()
	acc["land"][str(season)] = land


static func _people(g: Game) -> int:
	var total := 0
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1:
			total += int(g.state.people[i])
	return total


## The end-of-game measures (the ranges of 4.17 read them).
static func _finish(g: Game, acc: Dictionary, rec: Dictionary, judge: Judge) -> void:
	var played := int(rec["played"])
	var land_total := 0
	var best := 0
	var negative := 0
	var richest := 0
	var men := 0
	var rows := {}
	for c: Country in g.countries:
		var n := Territory.districts(g, c.id).size()
		land_total += n
		best = maxi(best, n)
		negative += 1 if c.treasury < 0 else 0
		richest = maxi(richest, c.treasury)
		var m := Armies.men_of_country(g, c.tag)
		men += m
		var key := String(c.tag)
		rows[key] = {"land": n, "treasury": c.treasury, "men": m, "declared": int((acc["declared"] as Dictionary).get(key, 0)),
			"won": int((acc["won"] as Dictionary).get(key, 0)), "lost": int((acc["lost"] as Dictionary).get(key, 0)),
			"works": int(judge.works.get(key, 0)), "tax": (acc["tax"] as Dictionary).get(key, [0, 0, 0])}
	for w: War in g.wars:
		if not w.live():
			acc["ended"] = int(acc["ended"]) + 1
			if w.terms != &"timer":
				acc["ended_by_peace"] = int(acc["ended_by_peace"]) + 1
	var people := _people(g)
	var seats := maxi(int(acc["seat_seasons"]), 1)
	var years := maxf(float(played) / 4.0, 0.25)
	rec["wars"] = int(acc["wars"])
	rec["ended"] = int(acc["ended"])
	rec["ended_by_peace"] = int(acc["ended_by_peace"])
	rec["battles"] = g.next_record_id - 1
	rec["share_max"] = 1000 * best / maxi(land_total, 1)
	rec["negative"] = negative
	rec["countries"] = g.countries.size()
	rec["treasury_max"] = richest
	rec["people_permille"] = 1000 * people / maxi(int(acc["people_start"]), 1)
	rec["men_permille"] = 1000 * men / maxi(people, 1)
	rec["works_per_country_year"] = float(_sum(judge.works)) / float(maxi(g.countries.size(), 1)) / years
	rec["refused_per_seat"] = float(acc["refused"]) / float(seats)
	rec["orders_per_army"] = float(judge.orders) / float(maxi(int(acc["army_seasons"]), 1))
	rec["ai_ms_worst"] = _max(acc["ai"])
	rec["ai_ms_mean"] = _mean(acc["ai"])
	rec["ai_ms_seat"] = _mean(acc["ai"]) * float(played) / float(seats)
	rec["stats_ms_worst"] = _max(acc["stats"])
	rec["season_ms_worst"] = _max(acc["season"])
	rec["save_bytes"] = var_to_bytes(Snapshot.of(g)).compress(FileAccess.COMPRESSION_ZSTD).size()
	var entries := g.chronicle.entries
	rec["chronicle_seasons"] = (g.turn - int(entries[0].get("turn", g.turn))) if not entries.is_empty() else played
	rec["passive_declared"] = bool(acc["passive_declared"])
	rec["passive_lost"] = bool(acc["passive_lost"])
	rec["land_at"] = acc["land"]
	rec["rows"] = rows
	rec["digest"] = g.digest()


static func _sum(d: Dictionary) -> int:
	var n := 0
	for k: Variant in d:
		n += int(d[k])
	return n


static func _max(values: Array[float]) -> float:
	var out := 0.0
	for v: float in values:
		out = maxf(out, v)
	return out


static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v: float in values:
		total += v
	return total / float(values.size())
