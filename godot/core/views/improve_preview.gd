## The works card's numbers and the hex panel's rows (docs/architecture/m4-build-spec.md 4.17 and 5.6; ui-style-and-feedback-spec.md
## 7.1): what a build, an upgrade or a clearing would bring, season by season, before the player pays for it. Everything
## comes from EconomyPreview (the one what-if) and the rules' own checks, so the card equals what the seasons then do. Both
## measures of 5.0 R2 are in every gain, chip and payback field: the realm's (goods at price + taxes on people + dues -
## upkeep - walls, the default) and the treasury's (the money lines' sum); the shell picks one. Pure core/views/ code: it
## writes nothing but the game's view cache, reads no Settings and draws no luck.
class_name ImprovePreview
extends RefCounted

@warning_ignore_start("integer_division")

const SEASON_NAMES: Array[String] = Calendar.SEASON_NAMES
## Payback is "never" past this many seasons from now (D31).
const PAYBACK_HORIZON := PeopleView.HORIZON
const NO_HEX := Vector2i(-1, -1)


## The card of option {action: &"build"|&"upgrade"|&"clear"|&"barracks", family: int (0 for a barracks)} on `hex` for
## `tag`, cached by version (a barracks changes no output: BarracksView.fill_card). Keys:
## verdict {ok, reason}, blocked_by (&"" ok, &"slot", &"ducats", &"goods" or &"rule"), reason_words, title, subtitle, cost
## {ducats, goods [{good, name, n}], seasons, ready_turn, first_yield_turn, text}, requirements [{text, ok}], brings [{field,
## label, before, after, per}], by_season (four cells in calendar order, Spring first: {season (name), turn, now, note, goods
## [{name, before, after}], before, after, gain (the realm's), before_realm, after_realm, gain_realm, before_treasury,
## after_treasury, gain_treasury}), year {before, after, gain, ... both measures}, lands {district {before, after}, upkeep,
## ring [{hex, name, text, delta, foreign}], country {before, after, before_treasury, after_treasury}}, payback {seasons,
## turn, text, prestige, seasons_treasury, turn_treasury, text_treasury, prestige_treasury}, next_stages [{level, ok, text}],
## chips [{kind, text, amount, tone, text_realm, amount_realm, text_treasury, amount_treasury}], expensive, map_marks
## {hex: {delta, delta_treasury, label}}, ghost {hex, tiles}. A refusal by a rule leaves the money and season fields empty.
static func of(game: Game, tag: StringName, hex: Vector2i, option: Dictionary) -> Dictionary:
	var action := StringName(str(option.get("action", "build")))
	var family := int(option.get("family", 0))
	var key: Array = [&"preview", game.version, tag, hex, action, family]
	return game.view_cache.get_or_make(key, func() -> Dictionary: return _make(game, tag, hex, action, family)) as Dictionary


## The hex panel's rows: each {action, family, label ("Build vineyard"), verdict, cost_text ("40 · 4 seasons"), chips,
## expensive}: the build options of a wild hex, else the upgrade, then the clearing. Nothing for sea, unowned land or a
## hex with a work under way (the panel shows the work). A row is light (a row must come in under 0.2 ms): its chips are
## the district's good a year and a town's people, worked out on the hex alone; the card's `chips` add the gain a year,
## which needs the country's whole step. `full` gives each row the card's own chips (and the card is cached for it).
static func options_of(game: Game, tag: StringName, hex: Vector2i, full: bool = false) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var i := game.map.index_of(hex)
	if i < 0 or game.map.land[i] == 0 or game.state.work_at(hex) != null:
		return rows
	var use := int(game.state.main_use[i])
	var level := int(game.state.level[i])
	if use == ImproveRules.NONE:
		for option: Dictionary in Improve.build_options(game, hex):
			var f := int(option["family_id"])
			rows.append(_row(game, tag, hex, Works.BUILD, f, "Build %s" % WorksView.piece_name(f), full))
		return rows
	if level < FamilyIds.TOP_LEVEL[use]:
		var words := HexCard.level_label(FamilyIds.NAMES[use], level + 1)
		rows.append(_row(game, tag, hex, Works.UPGRADE, use, "Upgrade to %s" % words, full))
	rows.append(_row(game, tag, hex, Works.CLEAR, use, "Clear %s" % WorksView.piece_name(use), full))
	return rows


## The words of a refusal: a pair rule (row 5, through WorldImprove.conflict; row 6, a work under way near) takes
## ImproveRules.PAIR_WORDS with the other place and this one (4.15 e); every other refusal is the verdict's words with a
## capital and a full stop; "" for an accepted verdict.
static func reason_words(game: Game, hex: Vector2i, option: Dictionary, verdict: Dictionary) -> String:
	if bool(verdict.get("ok", false)):
		return ""
	var reason := str(verdict.get("reason", ""))
	var target := _target(game, hex, StringName(str(option.get("action", "build"))), int(option.get("family", 0)))
	if bool(target["valid"]):
		var f := int(target["family"])
		var lv := int(target["level_to"])
		if reason.begins_with("a work under way at"):
			var found := ImproveCardParts.pending(game, hex, f, lv)
			if not found.is_empty():
				return ImproveCardParts.pair_text(game, hex, int(found["rule"]), found["hex"] as Vector2i)
		else:
			var clash := game.improvement.conflict(hex, f, lv)
			if not clash.is_empty() and reason.begins_with(str(ImproveRules.PAIR_RULES[int(clash["rule"])][5])):
				return ImproveCardParts.pair_text(game, hex, int(clash["rule"]), clash["hex"] as Vector2i)
	return _sentence(reason)


## D31: from `ready_turn` the four seasons' `gains` (Spring first, repeated) are added until the sum reaches `cost`.
## {turn (0: never), seasons (from `now`; -1: never), date ("Autumn 1482"), prestige (true when never)}; never past 400
## seasons from `now`.
static func payback(gains: Array[int], cost: int, ready_turn: int, start_year: int, now: int = 1) -> Dictionary:
	var sum := 0
	for t: int in range(ready_turn, now + PAYBACK_HORIZON + 1):
		sum += gains[Calendar.season_of(t)] if gains.size() == 4 else 0
		if sum >= cost:
			return {"turn": t, "seasons": t - now, "date": Calendar.date_text(t, start_year), "prestige": false}
	return {"turn": 0, "seasons": -1, "date": "", "prestige": true}


# --- the rows ------------------------------------------------------------------------------------------------------


static func _row(game: Game, tag: StringName, hex: Vector2i, action: StringName, family: int, label: String, full: bool) -> Dictionary:
	var target := _target(game, hex, action, family)
	var args := {"hex": hex, "tag": tag}
	if action == Works.BUILD:
		args["family"] = family
	var level := int(target["level_to"])
	var seasons := Works.seasons_for(game, action, int(target["family"]), level)
	var cost := Works.cost_of(game, action, int(target["family"]), level)
	var c := Countries.by_tag(game, tag) if game.has_countries() else null
	var verdict := game.check(String(action), args) if bool(target["valid"]) else {"ok": false, "reason": "nothing can be done here"}
	var chips: Array[Dictionary] = []
	if _blocked_by(verdict) != &"rule":
		chips = of(game, tag, hex, {"action": action, "family": family})["chips"] if full else _light_chips(game, hex, target, c)
	return {
		"action": action, "family": family, "label": label, "verdict": verdict,
		"cost_text": _short_cost(_cost(game, cost, seasons, 0, {"turn": 0, "word": ""}, false, false, true)), "chips": chips,
		"expensive": c != null and _expensive(game, c, int(cost["ducats"]), seasons),
	}


## The chips of a row, from the hex alone: the district's good a year and a town's room (the card has the gain too).
static func _light_chips(game: Game, hex: Vector2i, target: Dictionary, c: Country) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game.defs == null or game.defs.goods.is_empty():
		return out
	var i := int(target["i"])
	var pair: Vector2i = target["pair"]
	var own := StateView.of(game.state)
	var from_base := game.districts.base_of(game, i)
	var to_base := Economy.district_base(game, own.with({i: pair}), hex)
	var count := game.defs.goods.size()
	var from_goods := PackedInt32Array()
	from_goods.resize(count)
	var to_goods := PackedInt32Array()
	to_goods.resize(count)
	var tax := c.tax if c != null else 1
	for s: int in 4:
		var slot := Economy.slot_for(int(game.map.climate[i]), s)
		Economy.add_output(from_base, slot, Economy.CALM, tax, game.defs, from_goods)
		Economy.add_output(to_base, slot, Economy.CALM, tax, game.defs, to_goods)
	var main := int(to_base["good"]) if int(to_base["good"]) >= 0 else int(from_base["good"])
	if main >= 0 and int(target["family"]) != ImproveRules.SETTLEMENT and to_goods[main] != from_goods[main]:
		out.append(_chip(&"good", "%s %s a year" % [String(game.defs.goods[main].key), Words.signed(to_goods[main] - from_goods[main])],
			to_goods[main] - from_goods[main]))
	var room := int(to_base["room"]) - int(from_base["room"])
	if int(target["family"]) == ImproveRules.SETTLEMENT and room != 0:
		out.append(_chip(&"room", "room %s" % Words.signed(room), room))
	return out


static func _chip(kind: StringName, text: String, amount: int) -> Dictionary:
	return {"kind": kind, "text": text, "amount": amount, "tone": _tone(amount), "text_realm": text, "amount_realm": amount,
		"text_treasury": text, "amount_treasury": amount}


## "40 · 4 seasons", "100 · 10 timber · 8 seasons", "4 seasons".
static func _short_cost(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	if int(cost.get("ducats", 0)) > 0:
		parts.append(Words.number(int(cost["ducats"])))
	for entry: Dictionary in cost.get("goods", []):
		parts.append(Words.loads(int(entry["n"]), str(entry["name"])))
	parts.append(Words.seasons(int(cost.get("seasons", 1))))
	return " · ".join(parts)


# --- the card ------------------------------------------------------------------------------------------------------


## What the option does to the hex: {valid, family (of the piece after), level_to, pair (Vector2i(main_use, level) after),
## old_family, old_level, i}.
static func _target(game: Game, hex: Vector2i, action: StringName, family: int) -> Dictionary:
	var out := {"valid": false, "family": 0, "level_to": 0, "pair": Vector2i(0, 0), "old_family": 0, "old_level": 0, "i": -1}
	var i := game.map.index_of(hex)
	if i < 0 or game.map.land[i] == 0:
		return out
	out["i"] = i
	out["old_family"] = int(game.state.main_use[i])
	out["old_level"] = int(game.state.level[i])
	if action == Works.BUILD:
		out["valid"] = family > 0 and family < FamilyIds.COUNT
		out["family"] = family
		out["level_to"] = 1
		out["pair"] = Vector2i(family, 1)
	elif action == Works.UPGRADE:
		var f := int(game.state.main_use[i])
		out["valid"] = f > 0
		out["family"] = f
		out["level_to"] = int(game.state.level[i]) + 1
		out["pair"] = Vector2i(f, int(game.state.level[i]) + 1)
	elif action == Works.CLEAR:
		out["valid"] = int(game.state.main_use[i]) > 0
		out["family"] = int(game.state.main_use[i])
	elif action == Works.BARRACKS:  # beside the piece: the check says where
		out["valid"] = true
		out["pair"] = Vector2i(int(out["old_family"]), int(out["old_level"]))
	return out


## The first refusal's kind: &"" ok, &"slot", &"ducats", &"goods" (rows 7 to 9: the card shows everything) or &"rule".
static func _blocked_by(verdict: Dictionary) -> StringName:
	if bool(verdict.get("ok", false)):
		return &""
	var reason := str(verdict.get("reason", ""))
	if reason.begins_with("no free work slot"):
		return &"slot"
	if reason.begins_with("not enough ducats"):
		return &"ducats"
	if reason.begins_with("not enough "):
		return &"goods"
	return &"rule"


static func _make(game: Game, tag: StringName, hex: Vector2i, action: StringName, family: int) -> Dictionary:
	var option := {"action": action, "family": family}
	var target := _target(game, hex, action, family)
	var args := {"hex": hex, "tag": tag}
	if action == Works.BUILD:
		args["family"] = family
	var verdict := game.check(Works.game_action(action), args) if bool(target["valid"]) else {"ok": false,
		"reason": "nothing can be done here"}
	var blocked := _blocked_by(verdict)
	var out := _blank()
	out["verdict"] = verdict
	out["blocked_by"] = blocked
	out["reason_words"] = reason_words(game, hex, option, verdict)
	out["title"] = _title(game, hex, action, target)
	out["subtitle"] = _subtitle(game, hex)
	if blocked == &"rule":
		return out
	var c := Countries.by_tag(game, tag) if game.has_countries() else null
	var seasons := Works.seasons_for(game, action, int(target["family"]), int(target["level_to"]))
	var ready := WorksView.ready_turn_of(game, hex, seasons)
	var cost := Works.cost_of(game, action, int(target["family"]), int(target["level_to"]))
	if action == Works.BARRACKS:
		out["cost"] = _cost(game, cost, seasons, ready, {"turn": 0, "word": ""}, not bool(verdict["ok"]), c != null)
		out["expensive"] = c != null and _expensive(game, c, int(cost["ducats"]), seasons)
		BarracksView.fill_card(game, tag, hex, cost, out)
		return out
	var cells := _cells(game, c, hex, target)
	var gain := _gains(cells)
	var first := _first_yield(game, target, cells, ready)
	out["cost"] = _cost(game, cost, seasons, ready, first, not bool(verdict["ok"]), c != null)
	out["by_season"] = _by_season(game, cells)
	out["brings"] = _brings(game, cells, target)
	out["people_note"] = _people_note(game, cells, target)
	var year := _year(cells)
	var district := _district(game, cells)
	if c != null:
		out["year"] = year
		out["lands"] = _lands(game, tag, cells, target, district, year)
		var value := int(cost["ducats"]) + _goods_value(game, cost["goods"] as Dictionary)
		out["payback"] = _payback(game, gain, value, ready, c != null and value > 0)
		out["requirements"] = ImproveCardParts.requirements(game, tag, hex, action, target, cost)
		out["expensive"] = _expensive(game, c, int(cost["ducats"]), seasons)
	else:
		out["requirements"] = ImproveCardParts.requirements(game, tag, hex, action, target, cost)
	out["next_stages"] = ImproveCardParts.next_stages(game, hex, target)
	out["chips"] = _chips(game, cells, target, year, c != null)
	out["map_marks"] = _marks(game, hex, cells, tag, c != null)
	out["ghost"] = {"hex": hex, "tiles": MapCells.piece_cells(game.map, Improve.piece_for(game.map, hex, int(target["pair"].x), int(target["pair"].y)), hex)}
	return out


## The card of a refusal by a rule or of nothing: only the verdict, the words and the title.
static func _blank() -> Dictionary:
	return {
		"verdict": {"ok": false, "reason": ""}, "blocked_by": &"", "title": "", "subtitle": "", "reason_words": "", "brings": [],
		"by_season": [], "year": {}, "lands": {}, "cost": {"text": ""}, "people_note": "", "requirements": [], "payback": {}, "next_stages": [],
		"chips": [], "expensive": false, "map_marks": {}, "ghost": {},
	}


# --- words ---------------------------------------------------------------------------------------------------------


static func _sentence(reason: String) -> String:
	if reason == "":
		return ""
	var text := reason.substr(0, 1).to_upper() + reason.substr(1)
	var digits := RegEx.create_from_string("[0-9]{4,}")
	var found := digits.search_all(text)
	for n: int in range(found.size() - 1, -1, -1):
		var m := found[n]
		text = text.substr(0, m.get_start()) + Words.number(int(m.get_string())) + text.substr(m.get_end())
	return text if text.ends_with(".") else text + "."


static func _capital(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)


static func _label_of(game: Game, action: StringName, target: Dictionary) -> String:
	var work := Work.new()
	work.action = action
	work.family = int(target["family"])
	work.level_to = int(target["level_to"])
	return WorksView.label(game, work)


static func _title(game: Game, hex: Vector2i, action: StringName, target: Dictionary) -> String:
	if not bool(target["valid"]):
		return ""
	var label := _label_of(game, action, target)
	var name := str(Improve.place_of(game.map, hex).get("name", ""))
	if name != "" and action != Works.BUILD:
		return "%s, %s" % [name, label]
	return _capital(label)


## "near Savona (7, 12) · farmland, 665 m · frost winter · a river on the W edge".
static func _subtitle(game: Game, hex: Vector2i) -> String:
	var map := game.map
	var i := map.index_of(hex)
	if i < 0 or map.land[i] == 0:
		return Words.place(game, hex)
	var parts := PackedStringArray([Words.place(game, hex)])
	parts.append("%s, %d m" % [HexCard.cover_words(int(map.cover[i])), int(map.height_m[i])])
	parts.append("%s winter" % HexCard.word(HexCard.CLIMATE_WORDS, int(map.climate[i])))
	var sides: Array[String] = []
	var stream := false
	for d: int in 6:
		var kind := map.river_on(hex, d)
		if kind > 0:
			sides.append(HexCard.DIRECTIONS[d])
			stream = stream or kind == 4
	if not sides.is_empty():
		parts.append("%s on the %s %s" % ["a stream" if stream else "a river", Words.list(sides, 6), "edge" if sides.size() == 1 else "edges"])
	if bool(Improve.place_of(map, hex).get("port", false)):
		parts.append("a port")
	return " · ".join(parts)


# --- the two views of the four seasons ----------------------------------------------------------------------------


## The four seasons before and after, in calendar order: {price (milli by good), now (season index), before: [4 x season
## entry of EconomyPreview or {}], after: [...], det: [4 x Array of touched hexes], i (hex index), turn: [4 x turn], has}.
static func _cells(game: Game, c: Country, hex: Vector2i, target: Dictionary) -> Dictionary:
	var i := int(target["i"])
	var pair: Vector2i = target["pair"]
	var now := Calendar.season_of(game.turn)
	var out := {"now": now, "i": i, "has": c != null, "before": [], "after": [], "det": [], "turn": [], "hex": hex}
	var before: Array = []
	var after: Array = []
	var det: Array = []
	var turns: Array = []
	var prices := PackedInt32Array()
	if c != null:
		var before_key: Array = [&"preview_before", game.version, c.tag]
		var base := game.view_cache.get_or_make(before_key, func() -> Array:
			return EconomyPreview.with(game, c.tag, {"lines": false}, 4)["seasons"] as Array) as Array
		var over := EconomyPreview.with(game, c.tag, {"hexes": {i: pair}, "detail": true, "lines": false}, 4)["seasons"] as Array
		prices = Economy.market_prices(game, null, Economy.market_of(game, c.tag), c.stock)
		for s: int in 4:
			var k := posmod(s - now, 4)
			before.append(base[k] if k < base.size() else {})
			after.append(over[k] if k < over.size() else {})
			det.append((over[k] as Dictionary).get("hexes", []) if k < over.size() else [])
			turns.append(game.turn + k)
	else:
		prices = Economy.market_prices(game, null, Economy.NO_MARKET, PackedInt32Array())
		for s: int in 4:
			var k := posmod(s - now, 4)
			before.append({})
			after.append({})
			det.append(_local_detail(game, i, pair, s))
			turns.append(game.turn + k)
	out["before"] = before
	out["after"] = after
	out["det"] = det
	out["turn"] = turns
	out["price"] = prices
	var first: Dictionary = {}
	for s: int in 4:
		for e: Dictionary in (det[s] as Array):
			if not first.has(int(e["i"])):
				first[int(e["i"])] = e
	out["first"] = first
	out["years"] = _years(game, out)
	return out


## `first` holds, for each hex the change touches in some season, its entry of the first season it has one (a hex whose base
## does not change is not touched). For each of them: {goods (the year's change by good id), best (the good with the largest change, -1
## for none), best_year (its change), worth (the year's change of the hex's worth)}.
static func _years(game: Game, cells: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var count := game.defs.goods.size() if game.defs != null else 0
	for j: int in cells["first"]:
		var sums := PackedInt32Array()
		sums.resize(count)
		var worth := 0
		for s: int in 4:
			var f := _entry(cells, s, j)
			if f.is_empty():
				continue
			var to_goods: PackedInt32Array = f["to_goods"]
			var from_goods: PackedInt32Array = f["from_goods"]
			for g: int in count:
				sums[g] += to_goods[g] - from_goods[g]
			var w := _worth(cells, f)
			worth += w[1] - w[0]
		var best := -1
		var best_year := 0
		for g: int in count:
			if absi(sums[g]) > absi(best_year):
				best = g
				best_year = sums[g]
		out[j] = {"goods": sums, "best": best, "best_year": best_year, "worth": worth}
	return out


## What the hex and the six round it give in a season of a game with no country: the same entries EconomyPreview's detail
## makes, on the Normal tax.
static func _local_detail(game: Game, i: int, pair: Vector2i, season: int) -> Array:
	var out: Array = []
	var own := StateView.of(game.state)
	var view := own.with({i: pair})
	var hexes := {i: true}
	for d: int in 6:
		var j := game.map.index_of(game.map.neighbour(game.map.hex_of(i), d))
		if j >= 0:
			hexes[j] = true
	var keys: Array = hexes.keys()
	keys.sort()
	var goods := game.defs.goods.size() if game.defs != null else 0
	for j: Variant in keys:
		var at := int(j)
		var hex := game.map.hex_of(at)
		if game.map.land[at] == 0:
			continue
		var slot := Economy.slot_for(int(game.map.climate[at]), season)
		var from_base := Economy.district_base(game, own, hex)
		var to_base := Economy.district_base(game, view, hex)
		var from_goods := PackedInt32Array()
		from_goods.resize(goods)
		var to_goods := PackedInt32Array()
		to_goods.resize(goods)
		var from_out := Economy.add_output(from_base, slot, Economy.CALM, 1, game.defs, from_goods)
		var to_out := Economy.add_output(to_base, slot, Economy.CALM, 1, game.defs, to_goods)
		out.append({
			"hex": hex, "i": at, "owner": 0, "from": from_base, "to": to_base, "from_goods": from_goods, "to_goods": to_goods,
			"from_dues": int(from_out["ducats"]), "to_dues": int(to_out["ducats"]),
			"from_cost": int(from_out["upkeep"]) + int(from_out["walls"]), "to_cost": int(to_out["upkeep"]) + int(to_out["walls"]),
		})
	return out


## The entry of hex index `i` in season `s`'s detail, or {}.
static func _entry(cells: Dictionary, s: int, i: int) -> Dictionary:
	for e: Dictionary in (cells["det"] as Array)[s]:
		if int(e["i"]) == i:
			return e
	return {}


static func _milli(goods: PackedInt32Array, prices: PackedInt32Array) -> int:
	var total := 0
	for g: int in goods.size():
		total += goods[g] * (prices[g] if g < prices.size() else 0)
	return total


## A hex's worth in a season (goods at price + dues - upkeep - walls), before and after.
static func _worth(cells: Dictionary, e: Dictionary) -> Array[int]:
	var prices: PackedInt32Array = cells["price"]
	var before := _milli(e["from_goods"] as PackedInt32Array, prices) / 1000 + int(e["from_dues"]) - int(e["from_cost"])
	var after := _milli(e["to_goods"] as PackedInt32Array, prices) / 1000 + int(e["to_dues"]) - int(e["to_cost"])
	return [before, after]


## [realm gains by season, treasury gains by season] in calendar order, as {realm: Array[int], treasury: Array[int]}.
static func _gains(cells: Dictionary) -> Dictionary:
	var realm: Array[int] = []
	var treasury: Array[int] = []
	for s: int in 4:
		var b: Dictionary = (cells["before"] as Array)[s]
		var a: Dictionary = (cells["after"] as Array)[s]
		realm.append(int(a.get("realm", 0)) - int(b.get("realm", 0)))
		treasury.append(int(a.get("net", 0)) - int(b.get("net", 0)))
	return {"realm": realm, "treasury": treasury}


## {turn, word}: the first season from `ready` in which the district's good is made, and its harvest word ("vintage");
## turn 0 for none (a good with no harvest word has no first yield).
static func _first_yield(game: Game, target: Dictionary, cells: Dictionary, ready: int) -> Dictionary:
	var none := {"turn": 0, "word": ""}
	if int(target["level_to"]) < 1 or int(target["i"]) < 0:
		return none
	var e := _entry(cells, 0, int(target["i"]))
	if e.is_empty():
		return none
	var good := int((e["to"] as Dictionary)["good"])
	if good < 0 or game.defs.goods[good].harvest_word == "":
		return none
	for t: int in range(ready, ready + 4):
		var made := _entry(cells, Calendar.season_of(t), int(target["i"]))
		if not made.is_empty() and (made["to_goods"] as PackedInt32Array)[good] > 0:
			return {"turn": t, "word": game.defs.goods[good].harvest_word}
	return none


# --- cost, seasons, brings --------------------------------------------------------------------------------------------


static func _goods_value(game: Game, goods: Dictionary) -> int:
	var milli := 0
	for key: Variant in goods:
		var g := game.defs.good_id(StringName(str(key)))
		if g >= 0:
			milli += int(goods[key]) * game.defs.goods[g].price_milli
	return milli / 1000


static func _cost(game: Game, cost: Dictionary, seasons: int, ready: int, first: Dictionary, refused: bool, money: bool,
		short: bool = false) -> Dictionary:
	var goods: Array[Dictionary] = []
	for key: Variant in cost["goods"]:
		var g := game.defs.good_id(StringName(str(key)))
		var name := game.defs.goods[g].name.to_lower() if g >= 0 else str(key)
		goods.append({"good": StringName(str(key)), "name": name, "n": int(cost["goods"][key])})
	if short:
		return {"ducats": int(cost["ducats"]), "goods": goods, "seasons": seasons}
	var parts := PackedStringArray()
	if not money:
		parts.append(Words.seasons(seasons))
	else:
		if int(cost["ducats"]) > 0:
			parts.append(Words.ducats(int(cost["ducats"])))
		for entry: Dictionary in goods:
			parts.append(Words.loads(int(entry["n"]), str(entry["name"])))
		parts.append(Words.seasons(seasons))
		parts.append("ready %s%s" % [Calendar.date_text(ready, game.start_year), " if begun now" if refused else ""])
		if int(first["turn"]) > 0:
			parts.append("first %s %s" % [first["word"], Calendar.date_text(int(first["turn"]), game.start_year)])
	return {"ducats": int(cost["ducats"]), "goods": goods, "seasons": seasons, "ready_turn": ready, "first_yield_turn": int(first["turn"]),
		"text": " · ".join(parts)}


static func _by_season(game: Game, cells: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var i := int(cells["i"])
	for s: int in 4:
		var b: Dictionary = (cells["before"] as Array)[s]
		var a: Dictionary = (cells["after"] as Array)[s]
		var e := _entry(cells, s, i)
		var goods: Array[Dictionary] = []
		var note := ""
		if not e.is_empty():
			goods = _changed_goods(game, e)
			note = _note(game, e, s)
		var gain_r := int(a.get("realm", 0)) - int(b.get("realm", 0))
		var gain_t := int(a.get("net", 0)) - int(b.get("net", 0))
		out.append({
			"season": SEASON_NAMES[s], "turn": (cells["turn"] as Array)[s], "now": s == int(cells["now"]), "note": note,
			"goods": goods, "before": int(b.get("realm", 0)), "after": int(a.get("realm", 0)), "gain": gain_r,
			"before_realm": int(b.get("realm", 0)), "after_realm": int(a.get("realm", 0)), "gain_realm": gain_r,
			"before_treasury": int(b.get("net", 0)), "after_treasury": int(a.get("net", 0)), "gain_treasury": gain_t,
		})
	return out


## The goods of the hex that change, the district's good first, then by id: [{name, before, after}].
static func _changed_goods(game: Game, e: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var from_goods: PackedInt32Array = e["from_goods"]
	var to_goods: PackedInt32Array = e["to_goods"]
	for g: int in _order(game, e):
		if from_goods[g] != to_goods[g]:
			out.append({"name": String(game.defs.goods[g].key), "before": from_goods[g], "after": to_goods[g]})
	return out


## Good ids, the district's good (after, else before) first.
static func _order(game: Game, e: Dictionary) -> Array[int]:
	var main := int((e["to"] as Dictionary)["good"])
	if main < 0:
		main = int((e["from"] as Dictionary)["good"])
	var out: Array[int] = []
	if main >= 0:
		out.append(main)
	for g: int in game.defs.goods.size():
		if g != main:
			out.append(g)
	return out


static func _note(game: Game, e: Dictionary, season: int) -> String:
	if season != Calendar.WINTER:
		return ""
	var to: Dictionary = e["to"]
	var i := int(e["i"])
	var slot := Economy.slot_for(int(game.map.climate[i]), season)
	if int(to["port_level"]) > 0 and slot < game.defs.port_dues_percent.size():
		return "port dues %d %% lower" % (100 - game.defs.port_dues_percent[slot])
	var climate := int(game.map.climate[i])
	var total := 0
	for n: int in e["to_goods"] as PackedInt32Array:
		total += n
	if climate < 2 and total == 0 and int(e["to_dues"]) == 0 and int(to["family"]) > 0:
		return "%s: nothing grows" % HexCard.word(HexCard.CLIMATE_WORDS, climate)
	return ""


## [before, after] of a hex field summed over the four seasons' entries.
static func _year_sum(cells: Dictionary, i: int, field: String) -> Array[int]:
	var from_sum := 0
	var to_sum := 0
	for s: int in 4:
		var e := _entry(cells, s, i)
		if not e.is_empty():
			from_sum += int(e["from_" + field])
			to_sum += int(e["to_" + field])
	return [from_sum, to_sum]


static func _brings(game: Game, cells: Dictionary, target: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var i := int(cells["i"])
	var e := _entry(cells, 0, i)
	if e.is_empty():
		return out
	var family := int(target["family"])
	if family == ImproveRules.SETTLEMENT:
		return _brings_town(game, cells, e)
	if family == ImproveRules.CASTLE:
		out.append(_bring(&"walls", "Walls", int(e["from_cost"]), int(e["to_cost"]), &"season"))
		out.append({"field": &"war", "label": "Its worth shows in war.", "before": 0, "after": 0, "per": &""})
		return out
	for g: int in _order(game, e):
		var sums := _good_sum(cells, i, g)
		if sums[0] != sums[1]:
			var name: String = game.defs.goods[g].name
			out.append(_bring(game.defs.goods[g].key, _capital(name), sums[0], sums[1], &"year"))
	var from_jobs := int((e["from"] as Dictionary)["jobs"])
	var to_jobs := int((e["to"] as Dictionary)["jobs"])
	if from_jobs != to_jobs:
		out.append(_bring(&"jobs", "Jobs", from_jobs, to_jobs, &""))
	if int(e["from_cost"]) != int(e["to_cost"]):
		out.append(_bring(&"upkeep", "Upkeep, a season", int(e["from_cost"]), int(e["to_cost"]), &""))
	var from_room := int((e["from"] as Dictionary)["room"])
	var to_room := int((e["to"] as Dictionary)["room"])
	if from_room != to_room:
		out.append(_bring(&"room", "Room", from_room, to_room, &""))
	return out


static func _bring(field: StringName, label: String, before: int, after: int, per: StringName) -> Dictionary:
	return {"field": field, "label": label, "before": before, "after": after, "per": per}


static func _good_sum(cells: Dictionary, i: int, g: int) -> Array[int]:
	var from_sum := 0
	var to_sum := 0
	for s: int in 4:
		var e := _entry(cells, s, i)
		if not e.is_empty():
			from_sum += (e["from_goods"] as PackedInt32Array)[g]
			to_sum += (e["to_goods"] as PackedInt32Array)[g]
	return [from_sum, to_sum]


## A settlement: its room (an upgrade brings room, not people: M5 D17), taxes on people (the country), port dues and fish
## (spring), the towns' food, upkeep and walls.
static func _brings_town(game: Game, cells: Dictionary, e: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var from_base: Dictionary = e["from"]
	var to_base: Dictionary = e["to"]
	out.append(_bring(&"room", "Room", int(from_base["room"]), int(to_base["room"]), &""))
	var b: Dictionary = (cells["before"] as Array)[Calendar.SPRING]
	var a: Dictionary = (cells["after"] as Array)[Calendar.SPRING]
	if bool(cells["has"]) and not b.is_empty():
		out.append(_bring(&"tax", "Taxes on people (the country)", _line(b, &"tax_people"), _line(a, &"tax_people"), &"season"))
	var spring := _entry(cells, Calendar.SPRING, int(cells["i"]))
	if not spring.is_empty() and (int(spring["from_dues"]) > 0 or int(spring["to_dues"]) > 0):
		out.append(_bring(&"port_dues", "Port dues", int(spring["from_dues"]), int(spring["to_dues"]), &"spring"))
	if not spring.is_empty() and (int(from_base["port_level"]) > 0 or int(to_base["port_level"]) > 0):
		var fish := (spring["from_goods"] as PackedInt32Array)[Economy.FISH]
		out.append(_bring(&"fish", "Fish", fish, (spring["to_goods"] as PackedInt32Array)[Economy.FISH], &"season"))
	if bool(cells["has"]) and not b.is_empty():
		var food_from := EconomySeason.need_loads(int(b["town"]), game.defs.food_need_milli)
		var food_to := EconomySeason.need_loads(int(a["town"]), game.defs.food_need_milli)
		out.append(_bring(&"food", "Towns' food", food_from, food_to, &"season"))
	out.append(_bring(&"upkeep", "Upkeep and walls", int(spring.get("from_cost", 0)), int(spring.get("to_cost", 0)), &"season"))
	return out


## The people note of a settlement's upgrade (spec 4.6 and 4.11 c): below the level the people raise themselves, "Its people
## raise it themselves at 4,000 (in about 34 seasons)." or "Its people are waiting for it."; above it, what the new room waits
## for, "People 30,000: the new room counts once they pass 45,000, in about 41 seasons." Else "".
static func _people_note(game: Game, cells: Dictionary, target: Dictionary) -> String:
	if int(target["family"]) != ImproveRules.SETTLEMENT or int(target["old_family"]) != ImproveRules.SETTLEMENT:
		return ""
	var i := int(cells["i"])
	if game.defs == null or game.state.people.size() <= i or int(game.state.owner[i]) == 0 and game.has_countries():
		return ""
	var people := game.state.people[i]
	var room_n := People.room_i(game, StateView.of(game.state), i)
	var room := Words.number(room_n)
	var full := people >= room_n
	var left := 0 if full else PeopleView.seasons_to_full(game, StateView.of(game.state), game.map.hex_of(i))
	var in_about := "" if left < 0 else (" (in about %s)" % Words.seasons(left) if left > 0 else "")
	if int(target["old_level"]) < game.defs.people_top_level:
		if full:
			return "Its people are waiting for it."
		if left < 0:
			return "Its people do not grow, so only the crown's work raises it."
		return "Its people raise it themselves at %s%s." % [room, in_about]
	if full:
		return "People %s: the new room is theirs at once." % Words.number(people)
	if left < 0:
		return "People %s: they do not grow, so the new room stays empty." % Words.number(people)
	return "People %s: the new room counts once they pass %s, in about %s." % [Words.number(people), room, Words.seasons(left)]


static func _line(entry: Dictionary, why: StringName) -> int:
	var total := 0
	for line: Dictionary in entry.get("lines", []):
		if line["why"] == why:
			total += int(line["amount"])
	return total


static func _year(cells: Dictionary) -> Dictionary:
	var b_realm := 0
	var a_realm := 0
	var b_net := 0
	var a_net := 0
	for s: int in 4:
		b_realm += int(((cells["before"] as Array)[s] as Dictionary).get("realm", 0))
		a_realm += int(((cells["after"] as Array)[s] as Dictionary).get("realm", 0))
		b_net += int(((cells["before"] as Array)[s] as Dictionary).get("net", 0))
		a_net += int(((cells["after"] as Array)[s] as Dictionary).get("net", 0))
	return {"before": b_realm, "after": a_realm, "gain": a_realm - b_realm, "before_realm": b_realm, "after_realm": a_realm,
		"gain_realm": a_realm - b_realm, "before_treasury": b_net, "after_treasury": a_net, "gain_treasury": a_net - b_net}


## The hex's goods' worth a year (dues too), before and after.
static func _district(game: Game, cells: Dictionary) -> Dictionary:
	var prices: PackedInt32Array = cells["price"]
	var from_milli := 0
	var to_milli := 0
	var from_dues := 0
	var to_dues := 0
	for s: int in 4:
		var e := _entry(cells, s, int(cells["i"]))
		if e.is_empty():
			continue
		from_milli += _milli(e["from_goods"] as PackedInt32Array, prices)
		to_milli += _milli(e["to_goods"] as PackedInt32Array, prices)
		from_dues += int(e["from_dues"])
		to_dues += int(e["to_dues"])
	return {"before": from_milli / 1000 + from_dues, "after": to_milli / 1000 + to_dues}


static func _lands(game: Game, tag: StringName, cells: Dictionary, target: Dictionary, district: Dictionary, year: Dictionary) -> Dictionary:
	var cost := _year_sum(cells, int(cells["i"]), "cost")
	return {
		"district": district, "upkeep": cost[1] - cost[0], "ring": ImproveCardParts.ring_lines(game, tag, cells, target),
		"country": {"before": year["before"], "after": year["after"], "before_treasury": year["before_treasury"],
			"after_treasury": year["after_treasury"]},
	}


# --- payback, expensive, chips, marks ----------------------------------------------------------------------------------


static func _payback(game: Game, gain: Dictionary, value: int, ready: int, wanted: bool) -> Dictionary:
	if not wanted:
		return {}
	var r := payback(gain["realm"] as Array[int], value, ready, game.start_year, game.turn)
	var t := payback(gain["treasury"] as Array[int], value, ready, game.start_year, game.turn)
	return {
		"seasons": r["seasons"], "turn": r["turn"], "text": _payback_text(game, r, true), "prestige": r["prestige"],
		"seasons_treasury": t["seasons"], "turn_treasury": t["turn"], "text_treasury": _payback_text(game, t, false),
		"prestige_treasury": t["prestige"],
	}


static func _payback_text(_game: Game, p: Dictionary, full: bool) -> String:
	if bool(p["prestige"]):
		return "Never pays back: a prestige work." if full else "Never pays back."
	if full:
		return "Pays back in %s, %s from now (at today's prices)." % [p["date"], Words.seasons(int(p["seasons"]))]
	return "%s, %s from now." % [p["date"], Words.seasons(int(p["seasons"]))]


static func _expensive(game: Game, c: Country, ducats: int, seasons: int) -> bool:
	return ducats * 1000 > c.treasury * game.defs.expensive_permille or seasons >= game.defs.expensive_seasons


## Up to three: the district's good a year, the gain a year (both measures), and a town's room.
static func _chips(game: Game, cells: Dictionary, target: Dictionary, year: Dictionary, money: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var i := int(cells["i"])
	var e := _entry(cells, 0, i)
	if e.is_empty():
		return out
	var main := int((e["to"] as Dictionary)["good"])
	if main < 0:
		main = int((e["from"] as Dictionary)["good"])
	if main >= 0 and int(target["family"]) != ImproveRules.SETTLEMENT:
		var sums := _good_sum(cells, i, main)
		if sums[1] != sums[0]:
			out.append(_chip(&"good", "%s %s a year" % [String(game.defs.goods[main].key), Words.signed(sums[1] - sums[0])], sums[1] - sums[0]))
	if money and (int(year["gain_realm"]) != 0 or int(year["gain_treasury"]) != 0):
		var realm := int(year["gain_realm"])
		var treasury := int(year["gain_treasury"])
		out.append({"kind": &"gain", "text": "%s a year" % Words.signed(realm), "amount": realm, "tone": _tone(realm),
			"text_realm": "%s a year" % Words.signed(realm), "amount_realm": realm,
			"text_treasury": "%s a year" % Words.signed(treasury), "amount_treasury": treasury})
	if int(target["family"]) == ImproveRules.SETTLEMENT:
		var gone := int((e["to"] as Dictionary)["room"]) - int((e["from"] as Dictionary)["room"])
		if gone != 0:
			out.append(_chip(&"room", "room %s" % Words.signed(gone), gone))
	return out


static func _tone(n: int) -> StringName:
	return &"good" if n > 0 else (&"bad" if n < 0 else &"faint")


## {hex: {delta, delta_treasury (0: the hexes' own worth is one measure), label}} for the hex and each owned ring hex whose
## year changes.
static func _marks(game: Game, hex: Vector2i, cells: Dictionary, tag: StringName, money: bool) -> Dictionary:
	var out: Dictionary = {}
	var i := int(cells["i"])
	for j: int in cells["first"]:
		var e: Dictionary = (cells["first"] as Dictionary)[j]
		if int(e["owner"]) == 0 and money:
			continue
		var years: Dictionary = (cells["years"] as Dictionary)[j]
		var worth := int(years["worth"])
		var best := int(years["best"])
		var best_year := int(years["best_year"])
		if j != i and worth == 0 and best < 0:
			continue
		var label := ""
		if best >= 0:
			label = "%s %s" % [Words.signed(best_year), String(game.defs.goods[best].key)]
		out[e["hex"]] = {"delta": worth, "label": label}
	return out
