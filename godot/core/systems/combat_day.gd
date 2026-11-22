## One battle day outside the phases that strike (docs/architecture/m7-build-spec.md 4.6): the dawn, the deploy of both sides
## into their lanes, the lanes that broke, the morale, the break test, the flight and the withdrawals, and the day's frame.
## Pure: the only draws are the dice and the hits, made by Combat and CombatHit.
@warning_ignore_start("integer_division")
class_name CombatDay
extends RefCounted


## The dawn: each live fighter's men, the day's losses and counters cleared, the shaken set emptied.
static func begin(st: CombatState) -> void:
	st.dawn = {}
	st.lost_today = {}
	st.shaken = {}
	st.killed_day = PackedInt32Array([0, 0])
	st.wounded_day = PackedInt32Array([0, 0])
	for f: Dictionary in st.fighters:
		st.dawn[int(f["key"])] = int(f["men"])


## Deploy both sides (4.6): the defender's centre is the garrison while it fights; each empty open lane takes a company of
## the reserve, centre first, and a company moved up after day 1 is shaken; then the lanes that held and stay empty break.
static func deploy(st: CombatState) -> void:
	for side: int in 2:
		var ln: Array = st.lanes[side]
		if side == CombatState.DEFENDER:
			if st.garrison_fights():
				ln[CombatState.CENTRE] = CombatState.GARRISON
			elif int(ln[CombatState.CENTRE]) == CombatState.GARRISON:
				ln[CombatState.CENTRE] = CombatState.EMPTY
		for lane: int in CombatState.LANE_COUNT:
			var key: int = int(ln[lane])
			if key == CombatState.EMPTY or key == CombatState.GARRISON:
				continue
			if not st.live(key) or st.is_routed(key) or not st.lane_open(lane):
				ln[lane] = CombatState.EMPTY
		var pool: Array = st.reserve(side)
		for lane: int in CombatState.FILL_ORDER:
			if int(ln[lane]) != CombatState.EMPTY or not st.lane_open(lane) or pool.is_empty():
				continue
			var pick: int = _pick(st, side, pool, lane)
			var key: int = int(pool[pick])
			pool.remove_at(pick)
			ln[lane] = key
			if st.day > 1:
				st.shaken[key] = true
		var hd: Array = st.held[side]
		for lane: int in CombatState.LANE_COUNT:
			if int(ln[lane]) != CombatState.EMPTY:
				hd[lane] = 1
		if st.day > 1:
			_breaks(st, side)


## The company that fills a lane (4.6): infantry first in the centre, cavalry on the flanks, crossbowmen and bombards last,
## then the best defence, then the lowest unit id.
static func _pick(st: CombatState, side: int, pool: Array, lane: int) -> int:
	var best: int = 0
	var best_key: Array = _fill_key(st, int(pool[0]), lane)
	for i: int in range(1, pool.size()):
		var k: Array = _fill_key(st, int(pool[i]), lane)
		if _less(k, best_key):
			best = i
			best_key = k
	return best


static func _fill_key(st: CombatState, key: int, lane: int) -> Array:
	var f: Dictionary = st.fighter(key)
	var branch: String = str(f["branch"])
	var tier: int = 1
	if branch == "artillery" or branch == "missile":
		tier = 2
	elif branch == "infantry" and lane == CombatState.CENTRE:
		tier = 0
	elif branch == "cavalry" and lane != CombatState.CENTRE:
		tier = 0
	var table: PackedInt32Array = st.war.fight_defence[StringName(branch)]
	var fight: int = 1 if st.rough() else 0
	var score: int = int(f["defence"]) * table[fight] * st.war.rank_permille[int(f["rank"])]
	return [tier, -score, key]


static func _less(a: Array, b: Array) -> bool:
	for i: int in 3:
		if int(a[i]) != int(b[i]):
			return int(a[i]) < int(b[i])
	return false


## Lanes that held a company and stay open and empty are broken (4.6): a newly broken centre shocks its side once, and each
## broken flank costs the centre the flank morale each day it stays open.
static func _breaks(st: CombatState, side: int) -> void:
	var ln: Array = st.lanes[side]
	var hd: Array = st.held[side]
	var now: Array = []
	for lane: int in CombatState.LANE_COUNT:
		if int(hd[lane]) == 1 and st.lane_open(lane) and int(ln[lane]) == CombatState.EMPTY:
			now.append(lane)
	var before: Array = st.broken[side]
	st.broken[side] = now
	if now.has(CombatState.CENTRE) and not before.has(CombatState.CENTRE):
		_shock(st, side)
	for lane: Variant in now:
		if int(lane) != CombatState.CENTRE:
			_drain_centre(st, side, st.war.flank_morale)


static func _shock(st: CombatState, side: int) -> void:
	for key: int in st.live_keys(side, true):
		if not st.is_routed(key):
			_drain(st, key, st.war.centre_shock)


static func _drain_centre(st: CombatState, side: int, amount: int) -> void:
	var key: int = int((st.lanes[side] as Array)[CombatState.CENTRE])
	if key != CombatState.EMPTY:
		_drain(st, key, amount)


## Takes morale off a fighter; at 0 it routs: it leaves its lane and stays on the hex (a garrison just stops holding).
static func _drain(st: CombatState, key: int, amount: int) -> void:
	if not st.has_fighter(key):
		return
	var f: Dictionary = st.fighter(key)
	f["morale"] = maxi(0, int(f["morale"]) - amount)
	if int(f["morale"]) > 0:
		return
	var side: int = int(f["side"])
	var ln: Array = st.lanes[side]
	for lane: int in CombatState.LANE_COUNT:
		if int(ln[lane]) == key:
			ln[lane] = CombatState.EMPTY
	if key != CombatState.GARRISON:
		st.routed[key] = true


## Morale (4.6): each live fighter loses 5 x its losses today x 1000 / its men at dawn, plus 20 in a lane or 30 in the reserve,
## plus 30 when unfed; divided by its rank. The garrison has no hunger.
static func morale(st: CombatState) -> void:
	var war := st.war
	for side: int in 2:
		for key: int in st.live_keys(side):
			if st.is_routed(key) or not st.live(key):
				continue
			var f: Dictionary = st.fighter(key)
			var dawn_men: int = maxi(int(st.dawn.get(key, 0)), 1)
			var lost: int = int(st.lost_today.get(key, 0))
			var loss: int = war.morale_per_loss * lost * 1000 / dawn_men
			loss += war.front_drain if st.in_lanes(side, key) else war.reserve_drain
			if key != CombatState.GARRISON and bool(f["hungry"]):
				loss += war.hunger_drain
			loss = loss * 1000 / war.rank_permille[int(f["rank"])]
			_drain(st, key, loss)


## The lane cause of a side's break (4.6): with no reserve, its centre empty, or two open lanes empty (either one on narrow
## ground); "" otherwise.
static func _lane_cause(st: CombatState, side: int) -> String:
	if not st.reserve(side).is_empty():
		return ""
	var ln: Array = st.lanes[side]
	var hd: Array = st.held[side]
	var open_count: int = 0
	var empty_held: Array = []
	for lane: int in CombatState.LANE_COUNT:
		if st.lane_open(lane):
			open_count += 1
			if int(ln[lane]) == CombatState.EMPTY and int(hd[lane]) == 1:
				empty_held.append(lane)
	if empty_held.is_empty():
		return ""
	if empty_held.has(CombatState.CENTRE):
		return "centre"
	if open_count == 2 or empty_held.size() >= 2:
		return "lanes"
	return ""


## The break test (4.6): a side breaks by its lanes, or when its front morale is under flee_morale (a side with no man in a
## lane is not measured by morale). Both: the lower front morale, the attacker on a tie.
static func breaker(st: CombatState) -> void:
	var war := st.war
	var cause: Array = ["", ""]
	var front: Array = [st.front_morale(0), st.front_morale(1)]
	for side: int in 2:
		cause[side] = _lane_cause(st, side)
		if str(cause[side]) == "" and int(front[side]) >= 0 and int(front[side]) < war.flee_morale:
			cause[side] = "morale"
	var broken: Array = []
	for side: int in 2:
		if str(cause[side]) != "":
			broken.append(side)
	st.broke = -1
	st.cause = ""
	if broken.is_empty():
		return
	var pick: int = int(broken[0])
	if broken.size() == 2:
		var fa: int = maxi(int(front[0]), 0)
		var fb: int = maxi(int(front[1]), 0)
		pick = 0 if fa <= fb else 1
	st.broke = pick
	st.cause = str(cause[pick])


## The flight of a side that broke (4.6): each fighter loses 150 permille of its men, all killed; its bombards are lost whole;
## its companies' morale is set to 150.
static func flight(st: CombatState, side: int) -> void:
	var hits: Array = []
	for key: int in st.live_keys(side):
		var f: Dictionary = st.fighter(key)
		var gun: bool = key != CombatState.GARRISON and str(f["branch"]) == "artillery"
		if gun:
			hits.append([key, int(f["men"]), 0])
			st.lost_whole.append(key)
		else:
			hits.append([key, int(f["men"]) * st.war.flee_pursuit_permille / 1000, 0])
	CombatHit.apply(st, hits)
	for key: int in _field_keys(st, side):
		st.fighter(key)["morale"] = st.war.flee_morale_left


## The price of a withdrawal (4.6): the side's men lose the permille (all killed), and its companies' morale is set to 250.
static func withdraw(st: CombatState, side: int, permille: int) -> void:
	var hits: Array = []
	for key: int in st.live_keys(side):
		hits.append([key, int(st.fighter(key)["men"]) * permille / 1000, 0])
	CombatHit.apply(st, hits)
	for key: int in _field_keys(st, side):
		st.fighter(key)["morale"] = st.war.withdraw_morale


static func _field_keys(st: CombatState, side: int) -> Array:
	var out: Array = []
	for f: Dictionary in st.fighters:
		if int(f["side"]) == side and int(f["key"]) != CombatState.GARRISON:
			out.append(int(f["key"]))
	return out


## The end of the day (4.6): a break ends the battle with a flight; a side with no fighter left is wiped out; a side on
## Withdraw leaves at withdraw_day (when it has a retreat); at the last day the lower front morale withdraws, unless it has
## no retreat and the other has one.
static func finish(st: CombatState) -> void:
	var war := st.war
	# Wiped out first: a side with no man left (field or garrison) is not a break. Both wiped is a draw (winner -1).
	var out_a: bool = not st.has_men(0)
	var out_d: bool = not st.has_men(1)
	if out_a or out_d:
		var win: int = -1
		if out_a and not out_d:
			win = 1
		elif out_d and not out_a:
			win = 0
		_end(st, "wiped", "wiped", win)
		return
	breaker(st)
	if st.broke >= 0:
		flight(st, st.broke)
		_end(st, "broke", st.cause, 1 - st.broke)
		return
	if st.day == war.withdraw_day:
		var leavers: Array = []
		for side: int in 2:
			if st.stance[side] == "withdraw" and bool(st.can_retreat[side]):
				leavers.append(side)
		if not leavers.is_empty():
			var who: int = int(leavers[0])
			if leavers.size() == 2:
				who = _lower_front(st)
			_withdrawal(st, who, "stance")
			return
	if st.day >= war.battle_days:
		var lower: int = _lower_front(st)
		var other: int = 1 - lower
		if not bool(st.can_retreat[lower]) and bool(st.can_retreat[other]):
			lower = other
		_withdrawal(st, lower, "timer")


## The side with the lower front morale (the attacker on a tie); a side with no man in a lane counts as 0.
static func _lower_front(st: CombatState) -> int:
	var fa: int = maxi(st.front_morale(0), 0)
	var fb: int = maxi(st.front_morale(1), 0)
	return 0 if fa <= fb else 1


static func _withdrawal(st: CombatState, side: int, why: String) -> void:
	var permille: int = st.war.withdraw_pursuit_attacker_permille if side == 0 else st.war.withdraw_pursuit_permille
	withdraw(st, side, permille)
	st.withdrew = side + 1
	_end(st, "withdraw", why, 1 - side)


static func _end(st: CombatState, how: String, why: String, win: int) -> void:
	st.over = true
	st.how = how
	st.cause = why
	st.winner = win


## The day's frame in the record's form (BattleRecord.FRAME_KEYS): men and morale of every fighter, the lanes, the routed and
## shaken companies, the day's killed and wounded, the front morale, the break and the withdrawal.
static func frame(st: CombatState) -> Dictionary:
	var men: Dictionary = {}
	var morale_out: Dictionary = {}
	for f: Dictionary in st.fighters:
		var key: int = int(f["key"])
		men[key] = int(f["men"])
		morale_out[key] = int(f["morale"])
	var lanes_out: Array = [
		PackedInt32Array((st.lanes[0] as Array)),
		PackedInt32Array((st.lanes[1] as Array)),
	]
	var routed_keys: Array = st.routed.keys()
	routed_keys.sort()
	var shaken_keys: Array = st.shaken.keys()
	shaken_keys.sort()
	return {
		"day": st.day,
		"rolls": PackedInt32Array(st.rolls),
		"lanes": lanes_out,
		"men": men,
		"morale": morale_out,
		"routed": PackedInt32Array(routed_keys),
		"shaken": PackedInt32Array(shaken_keys),
		"killed": PackedInt32Array(st.killed_day),
		"wounded": PackedInt32Array(st.wounded_day),
		"front": PackedInt32Array([maxi(st.front_morale(0), 0), maxi(st.front_morale(1), 0)]),
		"broke": st.broke,
		"cause": st.cause if st.broke >= 0 else "",
		"withdrew": st.withdrew,
	}
