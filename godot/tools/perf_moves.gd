## The moves rows of the moves-in-the-month build (docs/architecture/moves-build-spec.md section 9, MV16), measured by
## tools/perf_core.gd (--only=moves: these rows alone) on north Italy (PerfFixture.north_italy_game, seed 1480), each on a game of
## its own with ARMIES_PER_COUNTRY standing armies a country (the sight loops over them). Every order goes through Game.act.
##   walk_now_ms, walk_now_worst_ms  MARCHES at-once marches of a fresh army to a goal 1 to MARCH_SEASONS seasons away on its own
##                    land, the plan cached by a march_check before the clock: the mean and the worst act (the walk, Sight.refresh
##                    included).
##   walk_battle_ms   BATTLES marches of BATTLE_COMPANIES pikemen companies into as many of a country at war on the hex beside,
##                    each fought in the act: the worst act (the fight, BattleEnd.apply, the flush and the sight).
##   preview_leg_ms   MovePreview.to with leg and risks, cold (the view cache cleared, a new version), worst of PREVIEWS goals on
##                    own and enemy land of a country at war; preview_leg_warm_ms is the same call with only the version moved.
##   preview_via_ms   MovePreview.via with STOPS_PREVIEW staged stops and a new pointer hex, the staged legs cached, worst of VIAS;
##                    preview_via_cold_ms the first call of each set (all six legs, the view cache cleared).
##   march_via_ms     march_check then march with STOPS_MARCH stops (seven route searches, no plan cached) and its walk, worst of VIAS.
## A refused sample is drawn again, never timed. A row that cannot get all its samples reads INF. Nothing is asserted here: the
## budget (tests/perf_core_budget.json) decides, in perf_core.gd.
class_name PerfMoves
extends RefCounted

const SEED := 1480
const ARMIES_PER_COUNTRY := 5
const MARCHES := 200
const MARCH_SEASONS := 4
const BATTLES := 20
const BATTLE_COMPANIES := 8
const PREVIEWS := 50
const WAR_NEAR := 12
const VIAS := 50
const STOPS_PREVIEW := 5
const STOPS_MARCH := 6
const STOP_MIN := 2
const STOP_MAX := 4
const TRIES := 40
const ATTACKER := &"SAV"
const DEFENDER := &"MLO"
const NO_HEX := Vector2i(-1, -1)


## Fills `out` with the moves rows. Returns 0, or 1 when north Italy cannot be built.
static func measure(out: Dictionary) -> int:
	for fill: Callable in [_walks, _battles, _previews, _vias, _march_vias]:
		var game := PerfFixture.north_italy_game(0)
		if game == null:
			return 1
		var luck := Rng.new()
		luck.seed_with(SEED + 16)
		_background(game, luck)
		fill.call(game, luck, out)
	return 0


static func _ms(from_usec: int) -> float:
	return float(Time.get_ticks_usec() - from_usec) / 1000.0


## The worst of the samples, INF when fewer than `want` were taken.
static func _worst(samples: Array[float], want: int) -> float:
	if samples.size() < want:
		printerr("PerfMoves: %d of %d samples" % [samples.size(), want])
		return INF
	return samples.max()


static func _mean(samples: Array[float], want: int) -> float:
	if samples.size() < want:
		return INF
	var total := 0.0
	for s: float in samples:
		total += s
	return total / float(samples.size())


## ARMIES_PER_COUNTRY armies a country, 1 to 8 companies each, holding on free hexes of its own land.
static func _background(game: Game, luck: Rng) -> void:
	for c: Country in game.countries:
		for _k: int in ARMIES_PER_COUNTRY:
			var hex := _own_free(game, c.tag, luck)
			if hex != NO_HEX:
				_army(game, c.tag, hex, luck.randi_range(1, game.defs.stack_limit))
	Sight.refresh(game)


## A fresh army (full points, not mustering) of `companies` pikemen through the armies' door.
static func _army(game: Game, tag: StringName, hex: Vector2i, companies: int) -> Army:
	var a := Armies.create(game, tag, hex, "Army of perf")
	Armies.add_units(game, a, 0, companies, game.turn - 1, hex, 0, {})
	Armies.set_points(game, a, Allowance.full(game, a))
	return a


static func _drop(game: Game, ids: Array[int]) -> void:
	for id: int in ids:
		var a := Armies.by_id(game, id)
		if a != null:
			Armies.remove(game, a)
	game.events.clear()  # the shell's drain, outside the clock
	Sight.refresh(game)


static func _land(game: Game, tag: StringName) -> PackedInt32Array:
	var c := Countries.by_tag(game, tag)
	return Territory.districts(game, c.id) if c != null else PackedInt32Array()


## A random hex of the country's land with no army on it, NO_HEX when TRIES draws find none.
static func _own_free(game: Game, tag: StringName, luck: Rng) -> Vector2i:
	var land := _land(game, tag)
	for _k: int in TRIES:
		if land.is_empty():
			break
		var hex := game.map.hex_of(land[luck.randi_range(0, land.size() - 1)])
		if game.map.is_land(hex) and Armies.at(game, hex).is_empty():
			return hex
	return NO_HEX


## A country picked by a random land hex (so a large country is drawn as often as its land).
static func _any_tag(game: Game, luck: Rng) -> StringName:
	for _k: int in TRIES * 10:
		var hex := game.map.hex_of(luck.randi_range(0, game.map.hex_count() - 1))
		var tag := Territory.owner_tag(game, hex)
		if tag != &"" and game.map.is_land(hex):
			return tag
	return game.countries[0].tag


static func _walks(game: Game, luck: Rng, out: Dictionary) -> void:
	var samples: Array[float] = []
	var steps := 0
	var seasons: Array[int] = [0, 0, 0, 0]
	for _n: int in MARCHES * 4:
		if samples.size() >= MARCHES:
			break
		var tag := _any_tag(game, luck)
		var start := _own_free(game, tag, luck)
		if start == NO_HEX:
			continue
		var a := _army(game, tag, start, luck.randi_range(1, game.defs.stack_limit))
		Sight.refresh(game)
		game.version += 1
		var found := _march_goal(game, a, luck, 1 + samples.size() % MARCH_SEASONS)
		if not found.is_empty():
			var args := {"army": a.id, "goal": found["goal"], "tag": tag}
			game.version += 1
			Movement.march_check(game, args)  # the plan cached, as a hover leaves it
			var t := Time.get_ticks_usec()
			var verdict := game.act("march", args)
			var spent := _ms(t)
			if bool(verdict.get("ok", false)):
				samples.append(spent)
				steps += int((verdict["walk"] as Dictionary)["steps"])
				seasons[int(found["seasons"]) - 1] += 1
		_drop(game, [a.id])
	out["walk_now_ms"] = _mean(samples, MARCHES)
	out["walk_now_worst_ms"] = _worst(samples, MARCHES)
	out["walk_now_samples"] = samples.size()
	out["walk_now_mean_steps"] = float(steps) / float(maxi(samples.size(), 1))
	out["walk_now_by_seasons"] = seasons


## An allowed goal on the army's own land: one whose walk takes `want` seasons when one is drawn, else the longest of 1 to
## MARCH_SEASONS seasons drawn (a small country has no long routes). {} for none.
static func _march_goal(game: Game, a: Army, luck: Rng, want: int) -> Dictionary:
	var land := _land(game, a.tag)
	var best := {}
	for _k: int in TRIES:
		if land.is_empty():
			break
		var goal := game.map.hex_of(land[luck.randi_range(0, land.size() - 1)])
		if goal == a.hex or not bool(Movement.march_check(game, {"army": a.id, "goal": goal, "tag": a.tag})["ok"]):
			continue
		var walk := Movement.walk_plan(game, a, Movement.plan(game, a, goal)["hexes"], game.turn)
		var seasons := int(walk["seasons"])
		if seasons < 1 or seasons > MARCH_SEASONS:
			continue
		if best.is_empty() or seasons == want or (int(best["seasons"]) != want and seasons > int(best["seasons"])):
			best = {"goal": goal, "seasons": seasons}
		if seasons == want:
			break
	return best


## The war of the battle and preview rows, declared the season before (fair warning shuts no land).
static func _war(game: Game) -> void:
	if not Wars.at_war(game, ATTACKER, DEFENDER):
		WarFixture.at_war(game, ATTACKER, DEFENDER)
		game.war_cache.clear()
		game.version += 1


## The pairs [attacker's hex, defender's hex beside it], free of armies and of fortresses, along the war's border.
static func _border(game: Game) -> Array[Array]:
	var out: Array[Array] = []
	for i: int in _land(game, ATTACKER):
		var hex := game.map.hex_of(i)
		if not Armies.at(game, hex).is_empty() or Occupation.fortress_level(game, hex) > 0:
			continue
		for d: int in 6:
			var n := game.map.neighbour(hex, d)
			if game.map.has(n) and game.map.is_land(n) and Territory.owner_tag(game, n) == DEFENDER \
					and Armies.at(game, n).is_empty() and Occupation.fortress_level(game, n) == 0:
				out.append([hex, n])
	return out


static func _battles(game: Game, _luck: Rng, out: Dictionary) -> void:
	_war(game)
	var samples: Array[float] = []
	var refused := ""
	var pairs := 0
	for k: int in BATTLES * 4:
		if samples.size() >= BATTLES:
			break
		var border := _border(game)
		pairs = border.size()
		if border.is_empty():
			break
		var pair := border[(k * 7) % border.size()]
		var from: Vector2i = pair[0]
		var to: Vector2i = pair[1]
		var attacker := _army(game, ATTACKER, from, BATTLE_COMPANIES)
		var defender := _army(game, DEFENDER, to, BATTLE_COMPANIES)
		Sight.refresh(game)
		game.version += 1
		var args := {"army": attacker.id, "goal": to, "tag": ATTACKER}
		Movement.march_check(game, args)
		var t := Time.get_ticks_usec()
		var verdict := game.act("march", args)
		var spent := _ms(t)
		if bool(verdict.get("ok", false)) and int((verdict["walk"] as Dictionary)["battle"]) >= 0:
			samples.append(spent)
		else:
			refused = str(verdict.get("reason", verdict.get("walk", "")))
		_drop(game, [attacker.id, defender.id])
	if refused != "":
		print("PerfMoves: a march fought no battle: %s" % refused)
	out["walk_battle_ms"] = _worst(samples, BATTLES)
	out["walk_battle_mean_ms"] = _mean(samples, BATTLES)
	out["walk_battle_fought"] = samples.size()
	out["walk_battle_border_pairs"] = pairs


static func _previews(game: Game, luck: Rng, out: Dictionary) -> void:
	_war(game)
	var armies: Array[Army] = []
	var border := _border(game)
	for k: int in mini(8, border.size()):
		var from: Vector2i = border[int(float(k * border.size()) / 8.0)][0]  # eight places spread along the border
		if Armies.at(game, from).is_empty():
			armies.append(_army(game, ATTACKER, from, 4))
	Sight.refresh(game)
	var cold: Array[float] = []
	var warm: Array[float] = []
	var risky := 0
	var legs := {}
	for _n: int in PREVIEWS * 40:
		if cold.size() >= PREVIEWS or armies.is_empty():
			break
		var a := armies[luck.randi_range(0, armies.size() - 1)]
		var land := _land(game, DEFENDER if cold.size() % 2 == 0 else ATTACKER)
		var goal := game.map.hex_of(land[luck.randi_range(0, land.size() - 1)])
		if ImproveRules.hex_distance(goal, a.hex) > WAR_NEAR \
				or not bool(Movement.march_check(game, {"army": a.id, "goal": goal, "tag": a.tag})["ok"]):
			continue
		game.view_cache.clear()
		game.version += 1
		var t := Time.get_ticks_usec()
		var preview := MovePreview.to(game, a.tag, a.id, goal)
		cold.append(_ms(t))
		game.version += 1
		t = Time.get_ticks_usec()
		MovePreview.to(game, a.tag, a.id, goal)
		warm.append(_ms(t))
		if not (preview["risks"] as Array).is_empty():
			risky += 1
		var why := String((preview["leg"] as Dictionary)["why"])
		legs[why] = int(legs.get(why, 0)) + 1
	out["preview_leg_ms"] = _worst(cold, PREVIEWS)
	out["preview_leg_mean_ms"] = _mean(cold, PREVIEWS)
	out["preview_leg_warm_ms"] = _worst(warm, PREVIEWS)
	out["preview_leg_with_risks"] = risky
	out["preview_leg_whys"] = legs


## `count` stops from the army's hex, each STOP_MIN to STOP_MAX hexes from the one before on its own land, every leg allowed,
## or [] when a chain cannot be drawn.
static func _chain(game: Game, a: Army, luck: Rng, count: int) -> Array[Vector2i]:
	var land := _land(game, a.tag)
	var chain: Array[Vector2i] = []
	var from := a.hex
	for _k: int in TRIES * count * 4:
		if chain.size() >= count or land.is_empty():
			break
		var hex := game.map.hex_of(land[luck.randi_range(0, land.size() - 1)])
		var far := ImproveRules.hex_distance(hex, from)
		if far < STOP_MIN or far > STOP_MAX or hex == a.hex:
			continue
		var via: Array[Vector2i] = chain.duplicate()
		if bool(MarchVia.legs_verdict(game, a, a.tag, via, hex)["ok"]):
			chain.append(hex)
			from = hex
	if chain.size() < count:
		var none: Array[Vector2i] = []
		return none
	return chain


## Hexes of the army's own land near `from` that no point of `taken` holds, in a drawn order.
static func _near(game: Game, a: Army, luck: Rng, from: Vector2i, taken: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in _land(game, a.tag):
		var hex := game.map.hex_of(i)
		if hex != a.hex and not taken.has(hex) and ImproveRules.hex_distance(hex, from) <= STOP_MAX:
			out.insert(luck.randi_range(0, out.size()), hex)
	return out


static func _vias(game: Game, luck: Rng, out: Dictionary) -> void:
	var tag := PerfFixture.largest_tag(game)
	var cold: Array[float] = []
	var warm: Array[float] = []
	for _n: int in VIAS * 6:
		if warm.size() >= VIAS:
			break
		var start := _own_free(game, tag, luck)
		if start == NO_HEX:
			continue
		var a := _army(game, tag, start, 2)
		Sight.refresh(game)
		game.version += 1
		var stops := _chain(game, a, luck, STOPS_PREVIEW)
		if not stops.is_empty():
			_via_samples(game, a, stops, _near(game, a, luck, stops.back(), stops), cold, warm)
		_drop(game, [a.id])
	out["preview_via_ms"] = _worst(warm, VIAS)
	out["preview_via_mean_ms"] = _mean(warm, VIAS)
	out["preview_via_cold_ms"] = _worst(cold, VIAS)
	out["preview_via_country"] = String(tag)


## One staged set: the cold call on the first allowed pointer hex, then the call on a second one with the legs cached. The pointer
## hexes are not checked before the clock (a check would cache their last leg); a refused one is not kept.
static func _via_samples(game: Game, a: Army, stops: Array[Vector2i], pointers: Array[Vector2i], cold: Array[float],
		warm: Array[float]) -> void:
	game.view_cache.clear()
	game.version += 1
	var first := true
	for hex: Vector2i in pointers:
		if first:
			game.view_cache.clear()
		var t := Time.get_ticks_usec()
		var preview := MovePreview.via(game, a.tag, a.id, stops, hex)
		var spent := _ms(t)
		if not bool((preview["verdict"] as Dictionary)["ok"]):
			continue
		if first:
			cold.append(spent)
			first = false
		else:
			warm.append(spent)
			return


static func _march_vias(game: Game, luck: Rng, out: Dictionary) -> void:
	var samples: Array[float] = []
	var steps := 0
	for _n: int in VIAS * 8:
		if samples.size() >= VIAS:
			break
		var tag := _any_tag(game, luck)
		var start := _own_free(game, tag, luck)
		if start == NO_HEX:
			continue
		var a := _army(game, tag, start, 2)
		Sight.refresh(game)
		game.version += 1
		var chain := _chain(game, a, luck, STOPS_MARCH + 1)
		if not chain.is_empty():
			var goal: Vector2i = chain.pop_back()
			var args := {"army": a.id, "goal": goal, "tag": tag, "via": chain}
			game.version += 1  # no plan of a leg is cached: seven route searches
			var t := Time.get_ticks_usec()
			var checked := Movement.march_check(game, args)
			var verdict := game.act("march", args)
			var spent := _ms(t)
			if bool(checked["ok"]) and bool(verdict.get("ok", false)):
				samples.append(spent)
				steps += int((verdict["walk"] as Dictionary)["steps"])
		_drop(game, [a.id])
	out["march_via_ms"] = _worst(samples, VIAS)
	out["march_via_mean_ms"] = _mean(samples, VIAS)
	out["march_via_mean_steps"] = float(steps) / float(maxi(samples.size(), 1))
