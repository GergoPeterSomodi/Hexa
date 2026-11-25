## The Army tab's model of one tile (docs/architecture/tilewin-build-spec.md R7, R9, R21, R22; TW6). `of(game, tag, hex)` reads
## the tile for the viewer `tag`. "Armies here" is for any viewer: the viewer's own armies on the hex (each with its id and an
## open flag) and the foreign armies the viewer sees there (country and men exact, read-only: no id, no order, no name, since
## the token of ArmyView carries none). The company rows are for the viewer's own settlement only. `can_raise` is the largest
## count the raise check passes. Pure core/views/ code: a function of the game and the viewer, no nodes, no engine calls.
@warning_ignore_start("integer_division")
class_name TileArmy
extends RefCounted

const ERA_BADGES: Array[String] = ["I", "II", "III"]
const STATE_READY := &"ready"
const STATE_SHORT := &"short"
const STATE_LOCKED := &"locked"
const STATE_REFUSED := &"refused"
## The words a kind's settlement level gate gives (Military.raise_check: "<kind> are raised in a village or larger").
const LEVEL_GATE_WORDS := " are raised in a "


## {armies: Array[row], raise: {} | {head, arms, rows: Array[row]}} for the viewer `tag` on `hex`. An army row: own, open,
## tag, country, name, men, men_text, state_text, points_text, arms_text, and id (own rows only). `points_text` and
## `arms_text` are "" until their milestones. `arms` is {} until M9.5 (the arms banner is absent before). A raise row: kind,
## name, figure, era, era_text, men, parts (Array of {key, name, amount}: ducats, then goods), cost_text, upkeep, can_raise,
## state (ready, short, locked or refused), reason ("" when ready; the rule's own words otherwise).
static func of(game: Game, tag: StringName, hex: Vector2i) -> Dictionary:
	if game == null or game.map == null or not game.has_countries() or tag == &"":
		return {"armies": [], "raise": {}}
	return {"armies": _armies_here(game, tag, hex), "raise": _raise(game, tag, hex)}


## The largest count n (0 when none) with Military.raise_check ok for n companies of `kind` on `hex`. Every refusal of the check
## is monotone in the count, so the bound (the cap left, and the men at hand for whole companies) is stepped down until a count
## passes; the check itself has the last word, so n passes and n + 1 is refused.
static func can_raise(game: Game, tag: StringName, hex: Vector2i, kind: int) -> int:
	var ud := Military.unit_def(game, kind)
	if ud == null or ud.men <= 0 or not Military.raise_offered(game, tag, hex):
		return 0
	var left := Military.raise_cap(game, hex) - Military.raised_here(game, tag, hex)
	var bound := mini(left, Military.men_at_hand(game, tag, hex) / ud.men)
	for n: int in range(bound, 0, -1):
		if bool(Military.raise_check(game, {"hex": hex, "kind": kind, "count": n, "tag": tag}).get("ok", false)):
			return n
	return 0


## The row state of a raise check verdict: ready when ok; locked when the kind's settlement level gate refuses (its era gate
## does not exist in the rules yet); short for ducats, goods and men; refused for every other rule.
static func state_of(verdict: Dictionary) -> StringName:
	if bool(verdict.get("ok", false)):
		return STATE_READY
	var reason := str(verdict.get("reason", ""))
	if reason.contains(LEVEL_GATE_WORDS):
		return STATE_LOCKED
	if reason.begins_with("not enough ") or reason.begins_with("only "):
		return STATE_SHORT
	return STATE_REFUSED


static func _armies_here(game: Game, tag: StringName, hex: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in ArmyView.tokens(game, tag):
		if t.hex != hex:
			continue
		if t.tag == tag:
			for id: int in (t.armies as PackedInt32Array):
				var row := _own_row(game, tag, id)
				if not row.is_empty():
					out.append(row)
		else:
			out.append(_foreign_row(game, t))
	return out


static func _own_row(game: Game, tag: StringName, id: int) -> Dictionary:
	var p := ArmyView.panel(game, tag, id)
	if p.is_empty() or not bool(p.get("mine", false)):
		return {}
	var order := p.order as Dictionary
	var supply := p.supply as Dictionary
	var state := "%s · %s" % [str(order.text).to_lower(), str(supply.text).to_lower()]
	var men := int(p.men)
	return {
		"own": true, "open": true, "id": id, "tag": tag, "country": str(p.country), "name": str(p.name),
		"men": men, "men_text": Words.men(men), "state_text": state, "points_text": "", "arms_text": "",
	}


## A foreign army in sight: the country and the men exact. The token carries no name and no id, so none is shown.
static func _foreign_row(game: Game, t: Dictionary) -> Dictionary:
	var men := int(t.men)
	var tag := StringName(t.tag)
	return {
		"own": false, "open": false, "tag": tag, "country": _country(game, tag), "name": "",
		"men": men, "men_text": Words.men(men), "state_text": "", "points_text": "", "arms_text": "",
	}


static func _country(game: Game, tag: StringName) -> String:
	var cdef := Countries.def_of(game, tag)
	if cdef != null and not cdef.name.is_empty():
		return cdef.name
	return String(tag)


## The raise block: only on the viewer's own settlement (Military.raise_offered); {} elsewhere.
static func _raise(game: Game, tag: StringName, hex: Vector2i) -> Dictionary:
	if not Military.raise_offered(game, tag, hex):
		return {}
	var rows: Array[Dictionary] = []
	for ud: UnitDef in game.defs.units:
		if ud != null:
			rows.append(_row(game, tag, hex, ud))
	var head := "Men to levy %s · %d of %d raised this season" % [
		Words.number(Military.men_at_hand(game, tag, hex)), Military.raised_here(game, tag, hex),
		Military.raise_cap(game, hex)]
	return {"head": head, "arms": {}, "rows": rows}


static func _row(game: Game, tag: StringName, hex: Vector2i, ud: UnitDef) -> Dictionary:
	var verdict := Military.raise_check(game, {"hex": hex, "kind": ud.id, "count": 1, "tag": tag})
	var parts := _parts(game, ud)
	var texts := PackedStringArray()
	for part: Dictionary in parts:
		texts.append("%d %s" % [int(part.amount), str(part.name)])
	var era := clampi(ud.era, 1, ERA_BADGES.size())
	return {
		"kind": ud.id, "name": ud.name, "figure": ud.figure, "era": ud.era, "era_text": ERA_BADGES[era - 1],
		"men": ud.men, "parts": parts, "cost_text": " + ".join(texts), "upkeep": ud.upkeep,
		"can_raise": can_raise(game, tag, hex, ud.id), "state": state_of(verdict),
		"reason": "" if bool(verdict.get("ok", false)) else str(verdict.get("reason", "")),
	}


## The cost of one company as parts: the ducats, then each good in the order of the goods list.
static func _parts(game: Game, ud: UnitDef) -> Array[Dictionary]:
	var cost := Military.cost_of(game, ud.id, 1)
	var out: Array[Dictionary] = [{"key": "ducats", "name": "ducats", "amount": int(cost.ducats)}]
	var goods := cost.goods as Dictionary
	for gid: int in game.defs.goods.size():
		var g := game.defs.good(gid)
		var key := String(g.key)
		if goods.has(key):
			out.append({"key": key, "name": g.name.to_lower(), "amount": int(goods[key])})
	return out
