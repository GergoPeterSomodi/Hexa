## The AI's war steps (docs/architecture/m8-build-spec.md 4.9, 4.10, 5.5): `war` decides whether the seat declares a war (a think
## turn only), `war_army` gives one army its standing order and its order while the seat has a live war, `aims` lists an army's aims
## best first. A step reads only AiKnow and AiBrief (never another step module) and acts only through AiKnow.act; the seat's own
## armies are read as plain objects, an enemy's only as AiKnow gives them (seen, banded). Every number is the temperament's, the
## shared AiDef's or the war definitions'.
@warning_ignore_start("integer_division")
class_name AiWar
extends RefCounted

const RETAKE := &"retake"
const RELIEVE := &"relieve"
const RALLY := &"rally"
const ATTACK := &"attack"
const BESIEGE := &"besiege"
const WALK_IN := &"walk_in"
const APPROACH := &"approach"
const RATIO_CAP := 4000
const STATE_OPEN := &"open"
const STATE_FALLEN := &"fallen"
const STATE_CASTLE := &"castle"


# ----- 4.9: when to declare -------------------------------------------------------------------------------------------------


## The `war` step: on a think turn, when its conditions hold and a target exists, one roll of the AI's luck, and the declaration.
static func war(turn: AiTurn, game: Game, brief: AiBrief, _arg: int) -> void:
	var t := brief.temper
	if t == null or not brief.think:
		return
	var why := blocker(game, brief)
	if why != "":
		turn.note(brief.tag, "war: no declaration, " + why)
		return
	var found := targets(game, brief)
	if found.is_empty():
		turn.note(brief.tag, "war: no target")
		return
	var roll := AiKnow.roll(game)
	var best: Dictionary = found[0]
	turn.note(brief.tag, "war: target %s score %d (ratio %d, prize %d), roll %d of %d" % [best["target"], best["score"],
		best["ratio"], best["prize"], roll, t.declare_chance])
	if roll > t.declare_chance:
		return
	var verdict := AiKnow.act(turn, game, brief.tag, "declare_war", {"target": best["target"]})
	if bool(verdict.get("ok", false)):
		brief.declared_now.append(best["target"] as StringName)


## The first of 4.9's conditions 1 to 5 that fails, as words; "" when all hold.
static func blocker(game: Game, brief: AiBrief) -> String:
	var t := brief.temper
	if AiKnow.wars_of(game, brief.tag).size() >= t.max_wars:
		return "it has its %d wars" % t.max_wars
	var ended := AiKnow.last_peace(game, brief.tag)
	if ended > 0 and AiKnow.turn(game) - ended < t.rest_seasons:
		return "it rests until %d" % (ended + t.rest_seasons)
	var chest := t.war_chest_seasons * maxi(brief.upkeep, brief.ai.min_upkeep)
	if brief.treasury < chest:
		return "its war chest %d is not reached (%d)" % [chest, brief.treasury]
	if brief.men < brief.ai.min_war_men:
		return "its %d men are under %d" % [brief.men, brief.ai.min_war_men]
	if brief.hungry:
		return "it is hungry"
	return ""


## The candidate targets, best score first (ties: lower id): {target, men, ratio, need, prize, score}. A neighbour whose
## `declare_war` check is ok, whose banded men are known, whose ratio reaches the need and whose prize is 1 or more.
static func targets(game: Game, brief: AiBrief) -> Array[Dictionary]:
	var t := brief.temper
	var out: Array[Dictionary] = []
	for n: StringName in AiKnow.neighbours(game, brief.tag):
		if not bool(AiKnow.check(game, brief.tag, "declare_war", {"target": n}).get("ok", false)):
			continue
		var men_n := AiKnow.men_of(game, brief.tag, n)
		if men_n < 0:
			continue
		var ratio := ratio_of(brief.men, men_n)
		var need := t.declare_ratio - (t.busy_bonus if AiKnow.at_war_with_other(game, brief.tag, n) else 0)
		var prize := prize_of(game, brief, n)
		if ratio >= need and prize >= 1:
			out.append({"target": n, "men": men_n, "ratio": ratio, "need": need, "prize": prize, "score": prize * ratio / 1000,
				"id": AiKnow.id_of(game, n)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["id"]) < int(b["id"]) if a["score"] == b["score"] else int(a["score"]) > int(b["score"]))
	return out


## The seat's men over the target's banded men, permille, capped at 4,000.
static func ratio_of(men: int, men_n: int) -> int:
	return mini(RATIO_CAP, men * 1000 / maxi(1, men_n))


## The target's districts within `prize_range` of the seat's land whose area state is open or fallen and that the seat does not
## hold, plus 2 for each of its fortresses of level 2 or more within that range.
static func prize_of(game: Game, brief: AiBrief, target: StringName) -> int:
	# The seat's near-land field (AiBrief.near_land): a hex is within the range of its land exactly when it is a key.
	var near := brief.near_land()
	var total := 0
	for i: int in AiKnow.land_of(game, target):
		var hex := AiKnow.hex_of(game, i)
		if not AiKnow.is_land(game, hex) or AiKnow.controller_of(game, hex) == brief.tag:
			continue
		var state := AiKnow.area_state(game, hex)
		if (state == STATE_OPEN or state == STATE_FALLEN) and near.has(hex):
			total += 1
	for hex: Vector2i in AiKnow.fortresses_of(game, target):
		if AiKnow.fortress_level(game, hex) >= 2 and near.has(hex):
			total += 2
	return total


# ----- 4.10: what an army does ----------------------------------------------------------------------------------------------


## An army of the seat while it has a live war (`arg` is its id): the standing order, then shaken or hungry to a depot, then a
## besieger's storm, then the best aim (or the post), keeping a march the new aims do not beat by the switch.
static func war_army(turn: AiTurn, game: Game, brief: AiBrief, arg: int) -> void:
	var army := _army(game, brief.tag, arg)
	if army == null or army.units.is_empty() or brief.temper == null:
		return
	_standing(turn, game, brief, army)
	if _recover(turn, game, brief, army):
		return
	if _besieging(turn, game, brief, army):
		return
	_order(turn, game, brief, army)


## The standing order (D25): Withdraw when a seen enemy army within `threat_range` outnumbers it by the temperament's ratio and
## it neither stands on a fortress of its own nor besieges; else Hold. Told only when it differs from the army's.
static func _standing(turn: AiTurn, game: Game, brief: AiBrief, army: Army) -> void:
	var enemies := AiKnow.enemies(game, brief.tag)
	var largest := 0
	for e: Dictionary in brief.seen:
		if enemies.has(e["tag"]) and AiKnow.hex_distance(army.hex, e["hex"]) <= brief.ai.threat_range:
			largest = maxi(largest, int(e["men"]))
	var want := Army.STANDING_HOLD
	if largest * 1000 > army.men() * brief.temper.withdraw_ratio and not _on_own_fortress(game, brief, army) \
			and not _lays(AiKnow.own_siege(game, brief.tag, army.hex), brief.tag):
		want = Army.STANDING_WITHDRAW
	if army.standing != want:
		turn.note(brief.tag, "army %d standing %s (the largest enemy near: %d men)" % [army.id, want, largest])
		AiKnow.act(turn, game, brief.tag, "set_standing", {"army": army.id, "standing": String(want)})


## Shaken (morale under `rest_morale`) or hungry (the last supply phase left it hungry) goes to the nearest own depot and holds
## there; a hungry besieger of a place that falls within two seasons keeps its siege. True when the army's step is done.
static func _recover(turn: AiTurn, game: Game, brief: AiBrief, army: Army) -> bool:
	var shaken := AiKnow.morale_of(army) < brief.ai.rest_morale
	var hungry := army.supply == 2
	if hungry and not shaken:
		var falls := int(AiKnow.own_siege(game, brief.tag, army.hex).get("falls_in", -1))
		if _lays(AiKnow.own_siege(game, brief.tag, army.hex), brief.tag) and falls >= 1 and falls <= 2:
			hungry = false
	if not shaken and not hungry:
		return false
	var depot := Army.NO_HEX
	var least := 1 << 30
	for hex: Vector2i in AiKnow.depots(game, brief.tag):
		var d := AiKnow.hex_distance(army.hex, hex)
		if d < least:
			least = d
			depot = hex
	turn.note(brief.tag, "army %d %s: to the depot %s" % [army.id, "shaken" if shaken else "hungry", depot])
	if depot == Army.NO_HEX or army.hex == depot:
		_hold(turn, game, brief, army)
	elif army.order != Army.ORDER_MARCH or army.goal != depot:
		if not bool(AiKnow.act(turn, game, brief.tag, "march", {"army": army.id, "goal": depot}).get("ok", false)):
			_hold(turn, game, brief, army)
	return true


## A besieger (a siege of the seat on its hex) storms when the meter has reached the temperament's share of the need, the siege
## has lasted `siege_min_seasons` and the storm's odds reach `storm_ratio`; else the siege goes on. True when it besieges.
static func _besieging(turn: AiTurn, game: Game, brief: AiBrief, army: Army) -> bool:
	var siege := AiKnow.own_siege(game, brief.tag, army.hex)
	if not _lays(siege, brief.tag):
		return false
	if army.order == Army.ORDER_STORM:
		return true
	var t := brief.temper
	var progress := int(siege.get("progress", 0))
	var need := int(siege.get("need", 0))
	var lasted := int(siege.get("seasons", 0))
	if progress * 1000 < t.storm_share * need or lasted < game.defs.war.siege_min_seasons:
		turn.note(brief.tag, "army %d besieges %s: meter %d of %d, season %d: the siege goes on" % [army.id, army.hex, progress,
			need, lasted])
		return true
	var odds := AiKnow.odds(game, brief.tag, army, army.hex, true)
	var value := _value(odds)
	turn.note(brief.tag, "army %d besieges %s: meter %d of %d, storm odds %d against %d" % [army.id, army.hex, progress, need,
		value, t.storm_ratio])
	if value >= t.storm_ratio:
		AiKnow.act(turn, game, brief.tag, "storm", {"army": army.id, "goal": army.hex})
	return true


## Its order: the best aim not yet refused this turn, else its post. A march kept unless a better aim beats it by the switch.
static func _order(turn: AiTurn, game: Game, brief: AiBrief, army: Army) -> void:
	var tried: Array = brief.refused.get(army.id, [])
	var list: Array[Dictionary] = []
	for aim: Dictionary in aims(game, brief, army):
		if not tried.has(aim["goal"]):
			list.append(aim)
	if list.is_empty():
		_post(turn, game, brief, army, tried)
		return
	var best := list[0]
	if army.order == Army.ORDER_MARCH:
		for aim: Dictionary in list:
			if aim["goal"] == army.goal and int(best["score"]) * 1000 <= int(aim["score"]) * brief.ai.switch_permille:
				turn.note(brief.tag, "army %d keeps its march to %s (%s %d, best %d)" % [army.id, army.goal, aim["kind"],
					aim["score"], best["score"]])
				return
	var goal: Vector2i = best["goal"]
	turn.note(brief.tag, "army %d aim %s %s score %d" % [army.id, best["kind"], goal, best["score"]])
	if goal == army.hex:
		_hold(turn, game, brief, army)
	elif army.order == Army.ORDER_MARCH and army.goal == goal:
		return
	else:
		_march(turn, game, brief, army, goal, best["kind"] as StringName)


## The march to `goal`; a walk-in claims its hex; a refused march is told to the brief and asks for one more step, else it holds.
static func _march(turn: AiTurn, game: Game, brief: AiBrief, army: Army, goal: Vector2i, kind: StringName) -> void:
	if bool(AiKnow.act(turn, game, brief.tag, "march", {"army": army.id, "goal": goal}).get("ok", false)):
		if kind == WALK_IN:
			brief.claims[AiKnow.index_of(game, goal)] = army.id
		return
	var tried: Array = brief.refused.get(army.id, [])
	tried.append(goal)
	brief.refused[army.id] = tried
	if not turn.army_retry(game, brief.tag, army.id):
		_hold(turn, game, brief, army)


## An army with no aim goes to its post (fair warning: the enemies head the posts), or holds on it.
static func _post(turn: AiTurn, game: Game, brief: AiBrief, army: Army, tried: Array) -> void:
	var post := brief.post_of(army.id)
	turn.note(brief.tag, "army %d has no aim: its post %s" % [army.id, post])
	if post == Army.NO_HEX or army.hex == post or tried.has(post):
		_hold(turn, game, brief, army)
	elif army.order != Army.ORDER_MARCH or army.goal != post:
		_march(turn, game, brief, army, post, &"post")


## Hold: a marching army halts; one already holding, or with no order, does nothing.
static func _hold(turn: AiTurn, game: Game, brief: AiBrief, army: Army) -> void:
	if army.order == Army.ORDER_MARCH or army.order == Army.ORDER_STORM:
		AiKnow.act(turn, game, brief.tag, "halt", {"army": army.id})


# ----- the aims -------------------------------------------------------------------------------------------------------------


## 4.10's aims of an army, best score first (ties: lower hex index): {kind, goal, score}. Fair warning (D23): no aim in the land of
## an enemy declared on this turn. The post is not an aim: an army with none goes to it (_order).
static func aims(game: Game, brief: AiBrief, army: Army) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var enemies := AiKnow.enemies(game, brief.tag)
	var seen: Array[Dictionary] = []
	for e: Dictionary in brief.seen:
		if enemies.has(e["tag"]):
			seen.append(e)
	_retake(game, brief, army, enemies, seen, out)
	_relieve(game, brief, army, seen, out)
	_attack(game, brief, army, seen, out)
	_besiege(game, brief, army, enemies, seen, out)
	_walk_in(game, brief, army, enemies, seen, out)
	_approach(game, brief, army, enemies, out)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] != b["score"]:
			return int(a["score"]) > int(b["score"])
		return AiKnow.index_of(game, a["goal"]) < AiKnow.index_of(game, b["goal"]))
	return out


static func _aim(out: Array[Dictionary], kind: StringName, goal: Vector2i, score: int) -> void:
	out.append({"kind": kind, "goal": goal, "score": score})


## retake: an own district an enemy occupies, within `target_range`, with no seen enemy army there of more men than the army.
static func _retake(game: Game, brief: AiBrief, army: Army, enemies: Array[StringName], seen: Array[Dictionary],
		out: Array[Dictionary]) -> void:
	for i: int in AiKnow.land_of(game, brief.tag):
		var hex := AiKnow.hex_of(game, i)
		var d := AiKnow.hex_distance(army.hex, hex)
		if d > brief.ai.target_range or hex == army.hex or not AiKnow.is_land(game, hex):
			continue
		if enemies.has(AiKnow.controller_of(game, hex)) and not _warned(game, brief, hex) \
				and _men_on(seen, hex) <= army.men():
			_aim(out, RETAKE, hex, 1000 - 10 * d)


## relieve: an own fortress besieged by an enemy within `relief_range`. With force enough (the army and the seat's armies on the
## rally hex) against the besiegers' banded men: attack; else the rally hex, unless the place falls next season and the force is
## under `relief_last` of them (then it is given up).
static func _relieve(game: Game, brief: AiBrief, army: Army, seen: Array[Dictionary], out: Array[Dictionary]) -> void:
	for hex: Vector2i in AiKnow.fortresses_of(game, brief.tag):
		var d := AiKnow.hex_distance(army.hex, hex)
		var siege := AiKnow.own_siege(game, brief.tag, hex)
		if d > brief.ai.relief_range or siege.is_empty() or _lays(siege, brief.tag) or hex == army.hex:
			continue
		var besiegers := _men_on(seen, hex)
		if besiegers <= 0:
			besiegers = int(siege.get("men", 0))
		var rally := _rally_hex(game, brief, army, hex, seen)
		var force := army.men() + (_own_men_on(game, brief, army, rally) if rally != Army.NO_HEX else 0)
		var last := int(siege.get("falls_in", -1)) == 1
		var needed := brief.ai.relief_last if last else brief.temper.relief_ratio
		if force * 1000 >= besiegers * needed:
			_aim(out, RELIEVE, hex, 900 - 10 * d)
		elif not last and rally != Army.NO_HEX:
			_aim(out, RALLY, rally, 850 - 10 * AiKnow.hex_distance(army.hex, rally))


## The own controlled neighbour of a fortress with no seen enemy army, nearest the army (ties: hex index).
static func _rally_hex(game: Game, brief: AiBrief, army: Army, fortress: Vector2i, seen: Array[Dictionary]) -> Vector2i:
	var best := Army.NO_HEX
	var least := 1 << 30
	for beside: Vector2i in AiKnow.land_neighbours(game, fortress):
		if AiKnow.controller_of(game, beside) != brief.tag or _men_on(seen, beside) > 0:
			continue
		var d := AiKnow.hex_distance(army.hex, beside)
		if d < least or (d == least and AiKnow.index_of(game, beside) < AiKnow.index_of(game, best)):
			least = d
			best = beside
	return best


## The men of the seat's other armies on a hex.
static func _own_men_on(game: Game, brief: AiBrief, army: Army, hex: Vector2i) -> int:
	var total := 0
	for other: Army in AiKnow.own_armies(game, brief.tag):
		if other.id != army.id and other.hex == hex:
			total += other.men()
	return total


## attack: a seen enemy army within `attack_range` whose odds ratio over the ground factor reaches `attack_ratio`.
static func _attack(game: Game, brief: AiBrief, army: Army, seen: Array[Dictionary], out: Array[Dictionary]) -> void:
	for e: Dictionary in seen:
		var hex: Vector2i = e["hex"]
		var d := AiKnow.hex_distance(army.hex, hex)
		if d > brief.ai.attack_range or hex == army.hex or _warned(game, brief, hex):
			continue
		var value := _value(AiKnow.odds(game, brief.tag, army, hex, false))
		if value >= brief.temper.attack_ratio:
			_aim(out, ATTACK, hex, 700 + mini(2000, value - brief.temper.attack_ratio) / 10 - 10 * d)


## besiege: an enemy-held fortress within `target_range` with a garrison to take, laid siege by no other army of the seat, that
## the forecast (against the garrison it may take it to be) says falls in 1 to `siege_max` seasons (2 more with guns) and
## before the war's timer less 2; the enemy's capital 100 better.
static func _besiege(game: Game, brief: AiBrief, army: Army, enemies: Array[StringName], seen: Array[Dictionary],
		out: Array[Dictionary]) -> void:
	var guns := AiKnow.guns_of(game, army)
	var longest := brief.temper.siege_max + (2 if guns > 0 else 0)
	for enemy: StringName in enemies:
		var age := _war_age(game, brief.tag, enemy)
		for hex: Vector2i in AiKnow.fortresses_of(game, enemy):
			var d := AiKnow.hex_distance(army.hex, hex)
			if d > brief.ai.target_range or hex == army.hex or _warned(game, brief, hex) or _men_on(seen, hex) > 0:
				continue
			if AiKnow.garrison_estimate(game, brief.tag, hex) <= 0 or _besieged_by_other(game, brief, army, hex):
				continue
			var seasons := AiKnow.forecast(game, brief.tag, hex, army.men(), guns)
			if seasons < 1 or seasons > longest or age + seasons >= game.defs.war.war_timer_seasons - 2:
				continue
			var score := 650 - 25 * seasons - 10 * d
			if AiKnow.capital_of(game, enemy) == hex:
				score += 100
			_aim(out, BESIEGE, hex, score)


## True when another army of the seat besieges the hex or stands on it.
static func _besieged_by_other(game: Game, brief: AiBrief, army: Army, hex: Vector2i) -> bool:
	if _lays(AiKnow.own_siege(game, brief.tag, hex), brief.tag):
		return true
	for other: Army in AiKnow.own_armies(game, brief.tag):
		if other.id != army.id and other.hex == hex:
			return true
	return false


## walk in: an enemy district within `target_range`, open or fallen (or a fortress with no garrison), the seat not holding it,
## no seen enemy army on it, not claimed this turn by another army, and the army at least `militia_men` strong.
static func _walk_in(game: Game, brief: AiBrief, army: Army, enemies: Array[StringName], seen: Array[Dictionary],
		out: Array[Dictionary]) -> void:
	if army.men() < game.defs.war.militia_men:
		return
	for enemy: StringName in enemies:
		for i: int in AiKnow.land_of(game, enemy):
			var hex := AiKnow.hex_of(game, i)
			var d := AiKnow.hex_distance(army.hex, hex)
			if d > brief.ai.target_range or hex == army.hex or not AiKnow.is_land(game, hex) or _warned(game, brief, hex):
				continue
			if brief.claims.has(i) and int(brief.claims[i]) != army.id:
				continue
			if AiKnow.controller_of(game, hex) == brief.tag or _men_on(seen, hex) > 0:
				continue
			var state := AiKnow.area_state(game, hex)
			if state == STATE_OPEN or state == STATE_FALLEN or (state == STATE_CASTLE and AiKnow.garrison_estimate(game, brief.tag, hex) <= 0):
				_aim(out, WALK_IN, hex, 500 - 10 * d)


## approach: the nearest hex of an enemy's land (ties: lower hex index).
static func _approach(game: Game, brief: AiBrief, army: Army, enemies: Array[StringName], out: Array[Dictionary]) -> void:
	var best := Army.NO_HEX
	var least := 1 << 30
	for enemy: StringName in enemies:
		for i: int in AiKnow.land_of(game, enemy):
			var hex := AiKnow.hex_of(game, i)
			if hex == army.hex or not AiKnow.is_land(game, hex) or _warned(game, brief, hex):
				continue
			var d := AiKnow.hex_distance(army.hex, hex)
			if d < least:
				least = d
				best = hex
	if best != Army.NO_HEX:
		_aim(out, APPROACH, best, 100 - least)


# ----- helpers --------------------------------------------------------------------------------------------------------------


static func _army(game: Game, tag: StringName, id: int) -> Army:
	for army: Army in AiKnow.own_armies(game, tag):
		if army.id == id:
			return army
	return null


## The odds card's ratio over its ground factor, permille; -1 when no battle is worked out.
static func _value(odds: Dictionary) -> int:
	var ratio := int(odds.get("ratio_permille", -1))
	return -1 if ratio < 0 else ratio * 1000 / maxi(1, int(odds.get("factor_permille", 1000)))


## True when a siege view is of a siege the seat lays.
static func _lays(siege: Dictionary, tag: StringName) -> bool:
	return not siege.is_empty() and StringName(str(siege.get("besieger", ""))) == tag


static func _on_own_fortress(game: Game, brief: AiBrief, army: Army) -> bool:
	return AiKnow.fortress_level(game, army.hex) > 0 and AiKnow.controller_of(game, army.hex) == brief.tag


## Fair warning: true when the hex is held or owned by an enemy declared on this turn.
static func _warned(game: Game, brief: AiBrief, hex: Vector2i) -> bool:
	return brief.declared_now.has(AiKnow.owner_of(game, hex)) or brief.declared_now.has(AiKnow.controller_of(game, hex))


## The banded men of the seen enemy armies on a hex.
static func _men_on(seen: Array[Dictionary], hex: Vector2i) -> int:
	var total := 0
	for e: Dictionary in seen:
		if e["hex"] == hex:
			total += int(e["men"])
	return total


## The age of the seat's live war with `enemy`.
static func _war_age(game: Game, tag: StringName, enemy: StringName) -> int:
	for w: Dictionary in AiKnow.wars_of(game, tag):
		if w["enemy"] == enemy:
			return AiKnow.turn(game) - int(w["start_turn"])
	return 0
