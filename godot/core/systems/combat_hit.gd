## The hit and the four phases that strike (docs/architecture/m7-build-spec.md 4.6): fire, back line, shock and flanks. Each
## phase works out its hits from the state at its start (hit and its values read only the state), then applies them together
## through apply(). Permille arithmetic in whole numbers, every division floored (GDScript int division). Pure.
@warning_ignore_start("integer_division")
class_name CombatHit
extends RefCounted

## The fight column a side strikes in: the attacker is in an assault while the garrison fights, else open or rough.
static func strike_fight(st: CombatState, side: int) -> int:
	if side == CombatState.ATTACKER and st.garrison_fights():
		return 2
	return 1 if st.rough() else 0


## The fight column a side is struck in: the defender's companies in an assault meet the garrison column.
static func struck_fight(st: CombatState, side: int) -> int:
	if side == CombatState.DEFENDER and st.garrison_fights():
		return 2
	return 1 if st.rough() else 0


static func attack_value(war: WarDef, branch: String, fight: int, attack: int, rank: int) -> int:
	var table: PackedInt32Array = war.fight_attack[StringName(branch)]
	return attack * table[fight] * war.rank_permille[rank] / 1000


## The defence of a target company against a striker of branch striker_branch (4.6): the fight column, its rank, the ground
## (the defender's companies outside an assault), the castle (every defender's fighter in an assault) and the pikes.
static func defence_value(st: CombatState, target: Dictionary, striker_branch: String) -> int:
	var war := st.war
	var branch: String = str(target["branch"])
	var side: int = int(target["side"])
	var table: PackedInt32Array = war.fight_defence[StringName(branch)]
	var dfn: int = int(target["defence"]) * table[struck_fight(st, side)] * war.rank_permille[int(target["rank"])] / 1000
	if side == CombatState.DEFENDER:
		if st.garrison_fights():
			if st.castle_level > 0:
				dfn = dfn * (1000 + war.castle_defence_permille * st.castle_level) / 1000
		else:
			dfn = dfn * (1000 + int(st.ground["defence"])) / 1000
	if branch == "infantry" and striker_branch == "cavalry":
		dfn = dfn * war.pikes_vs_horse_permille / 1000
	return maxi(dfn, 1)


## The extra of a hit: a flank's, an infantry company's against cavalry (pikes), else 1,000.
static func extra_of(war: WarDef, striker_branch: String, target_branch: String, flank: bool) -> int:
	if flank:
		return war.flank_permille
	if striker_branch == "infantry" and target_branch == "cavalry":
		return war.pikes_vs_horse_permille
	return 1000


## The attacker's ground penalties: uphill all battle, a pass and a river on day 1 (multiplied). The defender has none.
static func ground_mult(st: CombatState, side: int) -> int:
	if side != CombatState.ATTACKER:
		return 1000
	var war := st.war
	var g: int = 1000
	if st.uphill:
		g = g * (1000 - war.uphill_penalty_permille) / 1000
	if st.day == 1 and st.crossing:
		g = g * (1000 - war.crossing_penalty_permille) / 1000
	if st.day == 1 and st.river:
		g = g * (1000 - war.river_penalty_permille) / 1000
	return g


## One hit in men (4.6): the target's full men times the base, the values, the men and the stances, the extra, the shaken
## and ground multipliers, the dice of the striker's side and one spread draw. Consumes one draw from the world stream.
static func hit(st: CombatState, striker_key: int, target_key: int, base: int, extra: int) -> int:
	var war := st.war
	var s: Dictionary = st.fighter(striker_key)
	var t: Dictionary = st.fighter(target_key)
	var ss: int = int(s["side"])
	var ts: int = int(t["side"])
	var branch_s: String = str(s["branch"])
	var att: int = attack_value(war, branch_s, strike_fight(st, ss), int(s["attack"]), int(s["rank"]))
	var dfn: int = defence_value(st, t, branch_s)
	var x: int = int(t["full"]) * base
	x = x * att / dfn
	x = x * int(s["men"]) / maxi(int(s["full"]), 1)
	x = x * int(war.stance_dealt[StringName(st.stance[ss])]) / 1000
	x = x * int(war.stance_taken[StringName(st.stance[ts])]) / 1000
	x = x * extra / 1000
	if st.shaken.has(striker_key):
		x = x * war.reserve_shaken_permille / 1000
	x = x * ground_mult(st, ss) / 1000
	x = x * int(war.dice_permille[st.rolls[ss] - 1]) / 1000
	var spread: int = st.rng.randi_range(1000 - war.hit_spread_permille, 1000 + war.hit_spread_permille)
	x = x * spread / 1000
	return x / 1000


## Applies hits, each [target key, men, wounded permille], in order: a hit never takes more than the target has left, the
## wounded share returns as wounded, the rest is killed, and a fighter at 0 men leaves its lane.
static func apply(st: CombatState, hits: Array) -> void:
	for h: Variant in hits:
		var hit_row: Array = h
		var key: int = int(hit_row[0])
		if not st.live(key):
			continue
		var f: Dictionary = st.fighter(key)
		var m: int = mini(int(hit_row[1]), int(f["men"]))
		if m <= 0:
			continue
		var w: int = m * int(hit_row[2]) / 1000
		var side: int = int(f["side"])
		f["men"] = int(f["men"]) - m
		st.lost_today[key] = int(st.lost_today.get(key, 0)) + m
		st.killed_day[side] += m - w
		st.killed_total[side] += m - w
		st.wounded_day[side] += w
		st.wounded_total[side] += w
		st.wounded_by_key[key] = int(st.wounded_by_key.get(key, 0)) + w
		if int(f["men"]) == 0:
			cull(st, key)


## A dead fighter leaves its lane and the routed list.
static func cull(st: CombatState, key: int) -> void:
	var side: int = st.side_of(key)
	var ln: Array = st.lanes[side]
	for lane: int in CombatState.LANE_COUNT:
		if int(ln[lane]) == key:
			ln[lane] = CombatState.EMPTY
	st.routed.erase(key)


## The enemy target of a shot at lane: the lane, else the first filled lane in fill order; EMPTY when none.
static func target_at(st: CombatState, side: int, lane: int) -> int:
	var ln: Array = st.lanes[side]
	for pick: int in [lane, 1, 0, 2]:
		if int(ln[pick]) != CombatState.EMPTY:
			return int(ln[pick])
	return CombatState.EMPTY


## Fire (4.6): each ranged company in the reserve shoots. Bombards hit the enemy centre; other ranged companies (crossbowmen)
## take the k-th of their side at lane FILL_ORDER[k mod 3]. The base is the company's fire permille.
static func fire(st: CombatState) -> void:
	var hits: Array = []
	for side: int in 2:
		var enemy: int = 1 - side
		var k: int = 0
		for key: int in st.reserve(side):
			var f: Dictionary = st.fighter(key)
			var fire_permille: int = int(f["fire"])
			if fire_permille <= 0:
				continue
			var target: int
			if str(f["branch"]) == "artillery":
				target = target_at(st, enemy, CombatState.CENTRE)
			else:
				target = target_at(st, enemy, CombatState.FILL_ORDER[k % 3])
				k += 1
			if target == CombatState.EMPTY:
				continue
			hits.append([target, hit(st, key, target, fire_permille, 1000), st.war.wounded_share_permille])
	apply(st, hits)


## Back line (4.6): a side whose centre is empty exposes its reserve; the enemy's reserve hits it at the back-line base.
static func backline(st: CombatState) -> void:
	var hits: Array = []
	for side: int in 2:
		var enemy: int = 1 - side
		if int((st.lanes[enemy] as Array)[CombatState.CENTRE]) != CombatState.EMPTY:
			continue
		var exposed: Array = st.reserve(enemy)
		if exposed.is_empty():
			continue
		var strikers: Array = st.reserve(side)
		for i: int in strikers.size():
			var target: int = int(exposed[i % exposed.size()])
			hits.append([target, hit(st, int(strikers[i]), target, st.war.backline_permille, 1000), st.war.wounded_share_permille])
	apply(st, hits)


## Shock (4.6): each lane fights the same lane of the enemy, both ways at once.
static func shock(st: CombatState) -> void:
	var hits: Array = []
	var war := st.war
	var att: Array = st.lanes[CombatState.ATTACKER]
	var dfn: Array = st.lanes[CombatState.DEFENDER]
	for lane: int in CombatState.LANE_COUNT:
		var a: int = int(att[lane])
		var d: int = int(dfn[lane])
		if a == CombatState.EMPTY or d == CombatState.EMPTY:
			continue
		var ba: String = str(st.fighter(a)["branch"])
		var bd: String = str(st.fighter(d)["branch"])
		var dmg_d: int = hit(st, a, d, war.shock_permille, extra_of(war, ba, bd, false))
		var dmg_a: int = hit(st, d, a, war.shock_permille, extra_of(war, bd, ba, false))
		hits.append([d, dmg_d, war.wounded_share_permille])
		hits.append([a, dmg_a, war.wounded_share_permille])
	apply(st, hits)


## Flanks (4.6): an enemy company with nobody opposite in its flank lane strikes this side's centre, or the nearest filled
## lane (centre first, then the nearer flank, then the lower index), at the flank bonus.
static func flanks(st: CombatState) -> void:
	var hits: Array = []
	var war := st.war
	for side: int in 2:
		var enemy: int = 1 - side
		for lane: int in [0, 2]:
			var runner: int = int((st.lanes[enemy] as Array)[lane])
			if runner == CombatState.EMPTY or int((st.lanes[side] as Array)[lane]) != CombatState.EMPTY:
				continue
			var where: int = nearest_filled(st, side, lane)
			if where < 0:
				continue
			var target: int = int((st.lanes[side] as Array)[where])
			var extra: int = extra_of(war, str(st.fighter(runner)["branch"]), str(st.fighter(target)["branch"]), true)
			hits.append([target, hit(st, runner, target, war.shock_permille, extra), war.wounded_share_permille])
	apply(st, hits)


## The lane a flank runner strikes in: the centre when filled, else the nearest filled flank; -1 when none stands.
static func nearest_filled(st: CombatState, side: int, lane: int) -> int:
	var ln: Array = st.lanes[side]
	if int(ln[CombatState.CENTRE]) != CombatState.EMPTY:
		return CombatState.CENTRE
	var best: int = -1
	for i: int in [0, 2]:
		if int(ln[i]) == CombatState.EMPTY:
			continue
		if best < 0 or absi(i - lane) < absi(best - lane):
			best = i
	return best
