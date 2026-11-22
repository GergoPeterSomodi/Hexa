## The AI's forces steps (docs/architecture/m8-build-spec.md 4.8, 5.5, D19 to D21): `forces` raises companies for the seat's goal of
## men, disbands one when the seat is broke or far over its goal, merges armies standing together, then appends one army step
## for each army; `peace_army` is an army's step while the seat is at peace: its standing order is Hold, then it marches to its
## post or halts on it. A step reads only AiKnow and AiBrief (never another step module) and acts only through AiKnow.act.
@warning_ignore_start("integer_division")
class_name AiForces
extends RefCounted

const HIGH_TAX := 2


## The seat's forces for the turn: raise, disband, merge, then the army steps (id order) appended after this step.
static func forces(turn: AiTurn, game: Game, brief: AiBrief, _arg: int) -> void:
	_raise(turn, game, brief)
	_disband(turn, game, brief)
	_merge(turn, game, brief)
	for army: Army in AiKnow.own_armies(game, brief.tag):
		turn.push_step(AiTurn.ARMY, army.id)


## An army of the seat at peace (`arg` is its id): Hold when attacked, then its post's march, or a halt on the post. An army
## takes this step every `peace_order_every` seasons ((turn + id) mod n == 0). No post, no order.
static func peace_army(turn: AiTurn, game: Game, brief: AiBrief, arg: int) -> void:
	if posmod(AiKnow.turn(game) + arg, brief.ai.peace_order_every) != 0:
		return
	var army := _army(game, brief.tag, arg)
	if army == null:
		return
	if army.standing != Army.STANDING_HOLD:
		AiKnow.act(turn, game, brief.tag, "set_standing", {"army": arg, "standing": String(Army.STANDING_HOLD)})
	var post := brief.post_of(arg)
	if post == Army.NO_HEX:
		return
	if army.hex == post:
		if army.order == Army.ORDER_MARCH:
			AiKnow.act(turn, game, brief.tag, "halt", {"army": arg})
	elif army.order != Army.ORDER_MARCH or army.goal != post:
		AiKnow.act(turn, game, brief.tag, "march", {"army": arg, "goal": post})


static func _army(game: Game, tag: StringName, id: int) -> Army:
	for army: Army in AiKnow.own_armies(game, tag):
		if army.id == id:
			return army
	return null


# ----- raising --------------------------------------------------------------------------------------------------------------


## 4.8's raising: while the seat's men are under its goal and it has raised fewer companies than the season's cap.
static func _raise(turn: AiTurn, game: Game, brief: AiBrief) -> void:
	var at_war := not brief.enemies.is_empty()
	var cap := brief.ai.raises_war if at_war else brief.ai.raises_peace
	for _n: int in cap:
		if AiKnow.men(game, brief.tag) >= brief.goal_men or not _raise_one(turn, game, brief, at_war):
			return


## One company: the kinds by want, the places by nearness to the front; the first kind the money allows and a place whose
## check passes. False when none does.
static func _raise_one(turn: AiTurn, game: Game, brief: AiBrief, at_war: bool) -> bool:
	var companies := _companies(game, brief.tag)
	var kinds := kind_order(game, brief, companies, at_war)
	var places := place_order(game, brief)
	var reserve := brief.reserve if not at_war else brief.reserve / 2
	var total := 0
	for n: int in companies.values():
		total += n
	for kind: int in kinds:
		var ud := game.defs.unit_def(kind)
		if total > 0 and AiKnow.army_upkeep(game, brief.tag) + ud.upkeep > brief.army_room:
			continue
		if AiKnow.treasury(game, brief.tag) - ud.cost < reserve:
			continue
		for hex: Vector2i in places:
			var args := {"hex": hex, "kind": kind, "count": 1}
			if bool(AiKnow.check(game, brief.tag, "raise", args).get("ok", false)):
				return bool(AiKnow.act(turn, game, brief.tag, "raise", args).get("ok", false))
	return false


## The seat's companies by kind: {kind id: count}.
static func _companies(game: Game, tag: StringName) -> Dictionary:
	var out := {}
	for army: Army in AiKnow.own_armies(game, tag):
		for u: Unit in army.units:
			out[u.kind] = int(out.get(u.kind, 0)) + 1
	return out


## The kinds to raise, the most wanting first (ties: kind id): for each kind with a mix share (bombards only at war),
## want = mix x (companies + 1) - 1000 x companies of that kind.
static func kind_order(game: Game, brief: AiBrief, companies: Dictionary, at_war: bool) -> Array[int]:
	var total := 0
	for n: int in companies.values():
		total += n
	var wants: Array[Dictionary] = []
	for ud: UnitDef in game.defs.units:
		var share := brief.temper.mix[ud.id] if ud.id < brief.temper.mix.size() else 0
		if share <= 0 or (ud.key == &"bombards" and not at_war):
			continue
		wants.append({"kind": ud.id, "want": share * (total + 1) - 1000 * int(companies.get(ud.id, 0))})
	wants.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["kind"]) < int(b["kind"]) if a["want"] == b["want"] else int(a["want"]) > int(b["want"]))
	var out: Array[int] = []
	for w: Dictionary in wants:
		out.append(int(w["kind"]))
	return out


## The seat's settlements, nearest the front first (the capital when there is no front), then most men at hand, then hex index.
static func place_order(game: Game, brief: AiBrief) -> Array[Vector2i]:
	var rows: Array[Dictionary] = []
	for hex: Vector2i in AiKnow.settlements(game, brief.tag):
		rows.append({"hex": hex, "dist": _from_front(game, brief, hex),
			"men": AiKnow.men_at_hand(game, brief.tag, hex), "index": AiKnow.index_of(game, hex)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["dist"] != b["dist"]:
			return int(a["dist"]) < int(b["dist"])
		if a["men"] != b["men"]:
			return int(a["men"]) > int(b["men"])
		return int(a["index"]) < int(b["index"]))
	var out: Array[Vector2i] = []
	for row: Dictionary in rows:
		out.append(row["hex"])
	return out


## Hex distance from `hex` to the seat's nearest front hex, else to its capital; 0 when it has neither.
static func _from_front(game: Game, brief: AiBrief, hex: Vector2i) -> int:
	var best := -1
	for i: int in brief.front:
		var d := AiKnow.hex_distance(hex, AiKnow.hex_of(game, i))
		if best < 0 or d < best:
			best = d
	if best < 0:
		var home := AiKnow.capital_of(game, brief.tag)
		best = AiKnow.hex_distance(hex, home) if home != Army.NO_HEX else 0
	return best


# ----- disbanding and merging -----------------------------------------------------------------------------------------------


## 4.8's disbanding, one company a season: broke (a treasury under 0 that even High taxes leave in deficit), or at peace with
## no threat and men over the goal by `disband_surplus`. From the army farthest from the front, its smallest company.
static func _disband(turn: AiTurn, game: Game, brief: AiBrief) -> void:
	var tag := brief.tag
	var broke := AiKnow.treasury(game, tag) < 0 and AiKnow.preview_net(game, tag, HIGH_TAX) < 0
	var surplus := brief.enemies.is_empty() and brief.threats.is_empty() \
		and AiKnow.men(game, tag) * 1000 > brief.goal_men * brief.ai.disband_surplus
	if not broke and not surplus:
		return
	var rows: Array[Dictionary] = []
	for army: Army in AiKnow.own_armies(game, tag):
		rows.append({"army": army, "dist": _from_front(game, brief, army.hex)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["army"] as Army).id < (b["army"] as Army).id if a["dist"] == b["dist"] else int(a["dist"]) > int(b["dist"]))
	for row: Dictionary in rows:
		var army: Army = row["army"]
		var unit := _smallest(army)
		if unit != null and bool(AiKnow.act(turn, game, tag, "disband", {"army": army.id, "unit": unit.id}).get("ok", false)):
			return


## The company with the fewest men (ties: the highest id).
static func _smallest(army: Army) -> Unit:
	var best: Unit = null
	for u: Unit in army.units:
		if best == null or u.men < best.men or (u.men == best.men and u.id > best.id):
			best = u
	return best


## Two armies of the seat on one hex, neither marching (or marching to one goal), join: the higher id into the lower; at most
## `merges_per_season`.
static func _merge(turn: AiTurn, game: Game, brief: AiBrief) -> void:
	for _n: int in brief.ai.merges_per_season:
		var pair := _pair(AiKnow.own_armies(game, brief.tag))
		if pair.is_empty():
			return
		AiKnow.act(turn, game, brief.tag, "merge_armies", {"army": pair[1], "into": pair[0]})


## [lower id, higher id] of the first mergeable pair in id order, or [].
static func _pair(armies: Array[Army]) -> Array[int]:
	for i: int in armies.size():
		for j: int in range(i + 1, armies.size()):
			var a := armies[i]
			var b := armies[j]
			if a.hex != b.hex:
				continue
			var still := a.order != Army.ORDER_MARCH and b.order != Army.ORDER_MARCH
			var together := a.order == Army.ORDER_MARCH and b.order == Army.ORDER_MARCH and a.goal == b.goal
			if still or together:
				return [a.id, b.id] as Array[int]
	return [] as Array[int]
