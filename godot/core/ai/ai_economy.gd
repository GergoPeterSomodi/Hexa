## The AI's economy steps (docs/architecture/m8-build-spec.md 4.6, 4.7, 5.5): the works (scan, cards, act), the prior of an option
## and the taxes. A step reads only AiKnow, the definitions and the brief (never another step module) and acts only through
## AiKnow.act; every choice is told to the turn's trace with the numbers it was made by.
@warning_ignore_start("integer_division")
class_name AiEconomy
extends RefCounted

const SETTLEMENT := 1
const CASTLE := 2
const WHEAT := 3
const HARBOUR := 14
## The first settlement level with walls (a walled town); the walls priority is for upgrades to it and to a city.
const WALLED := 4
const LOW := 0
const NORMAL := 1
const HIGH := 2
const BUILD := &"build"
const UPGRADE := &"upgrade"
## A year's seasons the prior counts (spring, summer, autumn and the hex's winter slot).
const YEAR := 4


# ----- works -------------------------------------------------------------------------------------------------------------


## 4.7's scan: this step looks at `scan_per_step` of the season's `scan_hexes` candidates (from the offset (turn x scan_hexes)
## mod count, argument 0 the first slice, 1 the next) and keeps each option worth a card: its prior (and its priority) in
## brief.cards. With no free work slot the step ends at once.
static func works_scan(turn: AiTurn, game: Game, brief: AiBrief, arg: int) -> void:
	var tag := brief.tag
	if arg == 0:
		brief.cards.clear()
	if AiKnow.slots_free(game, tag) <= 0:
		turn.note(tag, "works_scan %d: no free work slot" % arg)
		return
	var list := AiKnow.work_candidates(game, tag)
	var count := list.size()
	if count == 0:
		turn.note(tag, "works_scan %d: no candidates" % arg)
		return
	var span := mini(count, brief.ai.scan_hexes)
	var offset := (AiKnow.turn(game) * brief.ai.scan_hexes) % count
	var from := arg * brief.ai.scan_per_step
	var to := mini(from + brief.ai.scan_per_step, span)
	var kept := 0
	for j: int in range(from, to):
		kept += _scan_hex(game, brief, list[(offset + j) % count])
	turn.note(tag, "works_scan %d: %d candidates, offset %d, looked at %d to %d, kept %d options" % [arg, count, offset, from, maxi(from, to), kept])


## The cards' step `arg`: the (arg + 1)th best option by prior x priority (best option of a hex, ties: lower hex index; a prior
## of 0 or less is never carded) gets its works card (`AiKnow.card`) and one jitter draw; its payback is adjusted by the jitter
## and the priority (4.7).
static func works_card(turn: AiTurn, game: Game, brief: AiBrief, arg: int) -> void:
	var tag := brief.tag
	if AiKnow.slots_free(game, tag) <= 0:
		turn.note(tag, "works_card %d: no free work slot" % arg)
		return
	var ranked := _ranked(game, brief)
	if arg >= ranked.size():
		turn.note(tag, "works_card %d: no candidate left (%d ranked)" % [arg, ranked.size()])
		return
	var entry: Dictionary = ranked[arg]
	var hex: Vector2i = entry["hex"]
	var option: Dictionary = entry["option"]
	var card := AiKnow.card(game, tag, hex, option)
	var jitter := AiKnow.jitter(game, brief.ai.jitter_permille)
	var payback := int(card["payback"])
	var adjusted := payback * jitter * 1000 / int(entry["priority"]) if payback >= 0 else -1
	entry["card"] = card
	entry["jitter"] = jitter
	entry["adjusted"] = adjusted
	entry["rank"] = arg
	turn.note(tag, "works_card %d: %s prior %d x priority %d = score %d; payback %s seasons x jitter %d / priority = %s; %s" % [
		arg, _name(hex, option), int(entry["prior"]), int(entry["priority"]), int(entry["score"]), _seasons(payback), jitter,
		_milli(adjusted), _verdict_words(card)])


## 4.7's acting: the fortify candidate of a steadfast seat first (one a season, `T - cost >= R`, no payback test), then the
## cards by ascending adjusted payback: one is taken when its verdict is ok, its payback is at most `payback_max` and
## `T - ducats >= R`; up to `works_per_season` works a season, the slots and money read again after each. A card refused only
## for money (ducats or goods) sets W (brief.wanted_cost) to its ducats when W is 0.
static func works_act(turn: AiTurn, game: Game, brief: AiBrief, _arg: int) -> void:
	var tag := brief.tag
	if AiKnow.slots_free(game, tag) <= 0:
		turn.note(tag, "works_act: no free work slot")
		return
	var done := 0
	var limit := brief.ai.works_per_season
	if brief.temper != null and brief.temper.fortify and not brief.threats.is_empty():
		done += _fortify(turn, game, brief)
	var taken := {}
	for entry: Dictionary in _carded(brief):
		if done >= limit:
			break
		if AiKnow.slots_free(game, tag) <= 0:
			turn.note(tag, "works_act: no free work slot left")
			break
		if _take(turn, game, brief, entry):
			done += 1
			taken[entry["hex"]] = true
	turn.note(tag, "works_act: %d of %d works begun, W %d" % [done, limit, brief.wanted_cost])


## One card's turn: true when its work was begun.
static func _take(turn: AiTurn, game: Game, brief: AiBrief, entry: Dictionary) -> bool:
	var tag := brief.tag
	var hex: Vector2i = entry["hex"]
	var option: Dictionary = entry["option"]
	var card := AiKnow.card(game, tag, hex, option)
	var payback := int(card["payback"])
	var most := brief.temper.payback_max if brief.temper != null else 0
	var ducats := int(card["ducats"])
	var name := _name(hex, option)
	if not _ok(card):
		var money: bool = card["blocked_by"] == &"ducats" or card["blocked_by"] == &"goods"
		if money and payback >= 0 and payback <= most and brief.wanted_cost == 0:
			brief.wanted_cost = ducats
			turn.note(tag, "works_act: %s refused for money only (%s): W = %d" % [name, card["blocked_by"], ducats])
		else:
			turn.note(tag, "works_act: %s skipped, %s" % [name, _verdict_words(card)])
		return false
	if payback < 0 or payback > most:
		turn.note(tag, "works_act: %s skipped, payback %s over the limit %d" % [name, _seasons(payback), most])
		return false
	var treasury := AiKnow.treasury(game, tag)
	if treasury - ducats < brief.reserve:
		turn.note(tag, "works_act: %s skipped, T %d - cost %d under the reserve R %d" % [name, treasury, ducats, brief.reserve])
		return false
	turn.note(tag, "works_act: takes %s, payback %s (limit %d), cost %d, T %d - cost >= R %d" % [
		name, _seasons(payback), most, ducats, treasury, brief.reserve])
	return bool(_begin(turn, game, tag, hex, option).get("ok", false))


## The steadfast seat's fortify (4.7): the first candidate its check allows that it can pay with its reserve kept; 1 when begun.
static func _fortify(turn: AiTurn, game: Game, brief: AiBrief) -> int:
	var tag := brief.tag
	for hex: Vector2i in AiKnow.fortify_candidates(game, tag, brief.threats):
		var option := {"action": BUILD if AiKnow.use_at(game, hex).x == 0 else UPGRADE, "family": CASTLE}
		var card := AiKnow.card(game, tag, hex, option)
		var ducats := int(card["ducats"])
		var treasury := AiKnow.treasury(game, tag)
		if not _ok(card):
			turn.note(tag, "works_act: fortify %s skipped, %s" % [_name(hex, option), _verdict_words(card)])
			continue
		if treasury - ducats < brief.reserve:
			turn.note(tag, "works_act: fortify %s skipped, T %d - cost %d under the reserve R %d" % [_name(hex, option), treasury, ducats, brief.reserve])
			continue
		turn.note(tag, "works_act: fortifies %s, cost %d, T %d - cost >= R %d (threats %s)" % [
			_name(hex, option), ducats, treasury, brief.reserve, ",".join(brief.threats)])
		if bool(_begin(turn, game, tag, hex, option).get("ok", false)):
			return 1
	return 0


static func _begin(turn: AiTurn, game: Game, tag: StringName, hex: Vector2i, option: Dictionary) -> Dictionary:
	if option["action"] == BUILD:
		return AiKnow.act(turn, game, tag, "build", {"hex": hex, "family": int(option["family"])})
	return AiKnow.act(turn, game, tag, "upgrade", {"hex": hex})


## The entries that have a card, by ascending adjusted payback (never last; ties: lower hex index).
static func _carded(brief: AiBrief) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in brief.cards:
		if entry.has("card") and int(entry["adjusted"]) >= 0:
			out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["adjusted"]) != int(b["adjusted"]):
			return int(a["adjusted"]) < int(b["adjusted"])
		return int(a["i"]) < int(b["i"]))
	return out


## The scanned options by score (best first; ties: hex index, then family), one a hex.
static func _ranked(_game: Game, brief: AiBrief) -> Array[Dictionary]:
	var sorted := brief.cards.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) > int(b["score"])
		if int(a["i"]) != int(b["i"]):
			return int(a["i"]) < int(b["i"])
		return int(a["option"]["family"]) < int(b["option"]["family"]))
	var out: Array[Dictionary] = []
	var seen := {}
	for entry: Dictionary in sorted:
		if not seen.has(entry["i"]):
			seen[entry["i"]] = true
			out.append(entry)
	return out


## Scans the options of one candidate hex into brief.cards; the count kept.
static func _scan_hex(game: Game, brief: AiBrief, hex: Vector2i) -> int:
	var options: Array[Dictionary] = []
	var use := AiKnow.use_at(game, hex)
	if use.x == 0:
		for built: Dictionary in AiKnow.build_options(game, hex):
			if bool(built.get("ok", false)):
				options.append({"action": BUILD, "family": int(built["family_id"])})
	else:
		options.append({"action": UPGRADE, "family": use.x})
	var at_war := not brief.enemies.is_empty()
	var kept := 0
	for option: Dictionary in options:
		var family := int(option["family"])
		if at_war and brief.temper != null and not brief.temper.works_at_war and family != WHEAT and family != HARBOUR:
			continue
		var value := prior(game, brief, hex, option)
		if value <= 0:
			continue
		var weight := _priority(game, brief, hex, option)
		brief.cards.append({"hex": hex, "i": AiKnow.index_of(game, hex), "option": option, "prior": value, "priority": weight,
			"score": value * weight / 1000})
		kept += 1
	return kept


## 4.7's priority, in permille (1,000: none): food families when hungry or food soon, a settlement's upgrade to a walled town
## or city when its hex is in `town_full`; the larger of the two.
static func _priority(game: Game, brief: AiBrief, hex: Vector2i, option: Dictionary) -> int:
	var family := int(option["family"])
	var weight := 1000
	if (family == WHEAT or family == HARBOUR) and (brief.hungry or brief.food_soon):
		weight = maxi(weight, brief.ai.food_priority)
	if family == SETTLEMENT and option["action"] == UPGRADE and AiKnow.use_at(game, hex).y + 1 >= WALLED and brief.town_full.has(hex):
		weight = maxi(weight, brief.ai.walls_priority)
	return weight


# ----- the prior ---------------------------------------------------------------------------------------------------------


## 4.7's prior of an option {action: &"build" | &"upgrade", family} on a hex, in permille a year of its cost: the year's value
## of the stage (goods at the fixed prices, taxes on the room, port dues, less upkeep and walls, a year being four seasons at
## full staffing) over what it costs (ducats and goods at their prices). 0 for a castle and for anything that gains nothing.
@warning_ignore("unused_parameter")
static func prior(game: Game, brief: AiBrief, hex: Vector2i, option: Dictionary) -> int:
	var use := AiKnow.use_at(game, hex)
	var family := int(option.get("family", 0))
	var level_from := 0
	if option.get("action", BUILD) == UPGRADE:
		family = use.x
		level_from = use.y
	var level_to := level_from + 1
	var fam := game.defs.family(family)
	if fam == null or family <= 0 or family == CASTLE or level_to >= fam.cost.size():
		return 0
	var value := 0
	if family == SETTLEMENT:
		value = _settlement_value(game, fam, hex, level_from, level_to)
	elif fam.base.size() > level_to:
		value = _goods_value(game, fam, hex, level_from, level_to)
	return value * 1000 / maxi(1, _cost(game, fam, level_to))


## A goods family's year: its loads at full staffing at the fixed price, less the wild yield it displaces and its upkeep.
static func _goods_value(game: Game, fam: FamilyDef, hex: Vector2i, level_from: int, level_to: int) -> int:
	var ground := AiKnow.ground(game, hex)
	var winter := 3 + int(ground["climate"])
	var good := fam.good
	var extra := 1000
	if good == &"":
		var animal := AiKnow.piece_extra(game, hex, fam.id, level_to)
		if fam.by_extra.has(animal):
			good = fam.by_extra[animal]
			extra = int(fam.extra_permille.get(animal, 1000))
	var price := _price(game, good)
	var year := 0
	for slot: int in [0, 1, 2, winter]:
		year += fam.season_percent[slot] if slot < fam.season_percent.size() else 0
	var gain := (fam.base[level_to] * extra / 1000 * year / 100 - (fam.base[level_from] * extra / 1000 * year / 100 if level_from > 0 else 0)) * price / 1000
	var keep_from := 100 if level_from == 0 else _at(fam.keep_wild, level_from, 100)
	var lost := _wild_year(game, int(ground["cover"]), winter) * _wild_price(game, int(ground["cover"])) \
		* (keep_from - _at(fam.keep_wild, level_to, 0)) / 100 / 1000
	return gain - lost - YEAR * (_at(fam.upkeep, level_to, 0) - _at(fam.upkeep, level_from, 0))


## A settlement's year: the room's taxes and the port's dues, less upkeep and walls.
static func _settlement_value(game: Game, fam: FamilyDef, hex: Vector2i, level_from: int, level_to: int) -> int:
	var taxes := (_at(fam.room, level_to, 0) - _at(fam.room, level_from, 0)) * game.defs.town_tax_milli / 1000000
	if AiKnow.is_port(game, hex):
		taxes += _at(fam.port_dues, level_to, 0) - _at(fam.port_dues, level_from, 0)
	var keep := _at(fam.upkeep, level_to, 0) + _at(fam.walls, level_to, 0) - _at(fam.upkeep, level_from, 0) - _at(fam.walls, level_from, 0)
	return YEAR * taxes - YEAR * keep


## The ducats and the goods at their prices of the work that reaches `level_to`.
static func _cost(game: Game, fam: FamilyDef, level_to: int) -> int:
	var milli := 0
	if level_to < fam.cost_goods.size():
		for key: Variant in fam.cost_goods[level_to]:
			milli += int(fam.cost_goods[level_to][key]) * _price(game, StringName(str(key)))
	return _at(fam.cost, level_to, 0) + milli / 1000


## The loads a year of the hex's wild land gives (the four slots of a year) in calm weather.
static func _wild_year(game: Game, cover: int, winter: int) -> int:
	var defs := game.defs
	if cover >= defs.wild_good.size() or defs.wild_good[cover] == &"":
		return 0
	var total := 0
	for slot: int in [0, 1, 2, winter]:
		var at := cover * FamilyDef.SLOTS + slot
		var loads: int = defs.wild_yield[at] if at < defs.wild_yield.size() else 0
		if defs.good_id(defs.wild_good[cover]) == 0:
			loads = loads * defs.weather_permille[0] / 1000
		total += loads
	return total


static func _wild_price(game: Game, cover: int) -> int:
	return _price(game, game.defs.wild_good[cover]) if cover < game.defs.wild_good.size() else 0


## A good's fixed price in thousandths of a ducat (0 for an unknown good).
static func _price(game: Game, good: StringName) -> int:
	var id := game.defs.good_id(good)
	return game.defs.good(id).price_milli if id >= 0 and game.defs.good(id) != null else 0


static func _at(values: PackedInt32Array, level: int, fallback: int) -> int:
	return values[level] if level >= 0 and level < values.size() else fallback


# ----- taxes -------------------------------------------------------------------------------------------------------------


## 4.6's table, the last step: the first row that applies sets the level (T the treasury now, R the reserve, W the works
## wanted, N_low and N_normal the season's previews at Low and Normal). The seat acts `set_tax` only when the level differs.
static func tax(turn: AiTurn, game: Game, brief: AiBrief, _arg: int) -> void:
	var tag := brief.tag
	var money := AiKnow.treasury(game, tag)
	var reserve := brief.reserve
	var level := AiKnow.tax_level(game, tag)
	var war := not AiKnow.enemies(game, tag).is_empty()
	var wanted := brief.wanted_cost
	var previews := {}
	var row := _tax_row(game, brief, money, reserve, level, war, wanted, previews)
	var target := _tax_level(row)
	turn.note(tag, "tax: T %d R %d W %d N_low %s N_normal %s, %s, level %s: row %d gives %s" % [
		money, reserve, wanted, str(previews.get(LOW, "-")), str(previews.get(NORMAL, "-")), "at war" if war else "at peace",
		_level_name(level), row, _level_name(target)])
	if target != level:
		AiKnow.act(turn, game, tag, "set_tax", {"level": target})


## The row (1 to 7) of 4.6 that applies; `previews` takes the nets that were worked out.
static func _tax_row(game: Game, brief: AiBrief, money: int, reserve: int, level: int, war: bool, wanted: int, previews: Dictionary) -> int:
	if money < 0:
		return 1
	if war and money < reserve:
		return 2
	if _net(game, brief.tag, NORMAL, previews) < 0 and money < 2 * reserve:
		return 3
	if level == HIGH and not (2 * money >= 3 * reserve and _net(game, brief.tag, NORMAL, previews) >= 0):
		return 4
	if not war and not brief.hungry and not brief.food_soon and wanted == 0 and money >= 2 * reserve \
			and _net(game, brief.tag, LOW, previews) >= 0:
		return 5
	if level == LOW and not war and wanted == 0 and 2 * money >= 3 * reserve:
		return 6
	return 7


static func _tax_level(row: int) -> int:
	if row <= 4:
		return HIGH
	return LOW if row <= 6 else NORMAL


static func _net(game: Game, tag: StringName, level: int, previews: Dictionary) -> int:
	if not previews.has(level):
		previews[level] = AiKnow.preview_net(game, tag, level)
	return int(previews[level])


static func _level_name(level: int) -> String:
	return ["Low", "Normal", "High"][clampi(level, 0, 2)]


# ----- words -------------------------------------------------------------------------------------------------------------


static func _name(hex: Vector2i, option: Dictionary) -> String:
	return "%s %s at (%d, %d)" % [option["action"], FamilyIds.NAMES[clampi(int(option["family"]), 0, FamilyIds.COUNT - 1)], hex.x, hex.y]


static func _seasons(payback: int) -> String:
	return "never" if payback < 0 else str(payback)


static func _milli(value: int) -> String:
	return "never" if value < 0 else "%d.%03d" % [value / 1000, value % 1000]


static func _verdict_words(card: Dictionary) -> String:
	var verdict: Dictionary = card["verdict"]
	return "ok" if bool(verdict.get("ok", false)) else "refused (%s): %s" % [card["blocked_by"], verdict.get("reason", "")]


static func _ok(card: Dictionary) -> bool:
	return bool((card["verdict"] as Dictionary).get("ok", false))
