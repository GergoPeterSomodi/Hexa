## The parts of the works card that read the neighbourhood (docs/architecture/m4-build-spec.md 4.17): the ticks of the
## requirements, the pair rules that concern an option, the stages above it, and the ring lines of "Where it lands".
## Split from ImprovePreview, which calls it (the 800-line limit); this file never names ImprovePreview. Pure core/views/ code.
class_name ImproveCardParts
extends RefCounted

@warning_ignore_start("integer_division")

const SEASON_NAMES: Array[String] = Calendar.SEASON_NAMES


static func _capital(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)


## The named place on the hex, or "this district".
static func named(game: Game, hex: Vector2i) -> String:
	var name := str(Improve.place_of(game.map, hex).get("name", ""))
	return name if name != "" else "this district"


## The words of pair rule `rule` against the piece on `other` (ImproveRules.PAIR_WORDS: the other place, then this one).
static func pair_text(game: Game, hex: Vector2i, rule: int, other: Vector2i) -> String:
	return ImproveRules.PAIR_WORDS[rule] % [Words.place(game, other), named(game, hex)]


## The entry of hex index `i` in season `s`'s detail of `cells`, or {}.
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


## The ring hexes whose goods change: {hex, name, text, delta, foreign}; "Ring of six: nothing changes" when none.
static func ring_lines(game: Game, tag: StringName, cells: Dictionary, target: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var i := int(cells["i"])
	for j: int in cells["first"]:
		var e: Dictionary = (cells["first"] as Dictionary)[j]
		if j == i or int(e["owner"]) == 0:
			continue
		var from_base: Dictionary = e["from"]
		var to_base: Dictionary = e["to"]
		if int(from_base["staffing"]) == int(to_base["staffing"]) and int(from_base["lift"]) == int(to_base["lift"]):
			continue
		var line := _ring_line(game, tag, cells, target, j)
		if not line.is_empty():
			out.append(line)
	if out.is_empty():
		out.append({"text": "Ring of six: nothing changes"})
	return out


static func _ring_line(game: Game, tag: StringName, cells: Dictionary, target: Dictionary, j: int) -> Dictionary:
	var deltas: Array[int] = [0, 0, 0, 0]
	var years: Dictionary = (cells["years"] as Dictionary)[j]
	var best := int(years["best"])
	var worth := int(years["worth"])
	for s: int in 4:
		var e := _entry(cells, s, j)
		if best >= 0 and not e.is_empty():
			deltas[s] = (e["to_goods"] as PackedInt32Array)[best] - (e["from_goods"] as PackedInt32Array)[best]
	if best < 0:
		return {}
	var e0: Dictionary = (cells["first"] as Dictionary)[j]
	var hex := e0["hex"] as Vector2i
	var owner_id := int(e0["owner"])
	var owner_tag: StringName = Countries.by_id(game, owner_id).tag if Countries.by_id(game, owner_id) != null else &""
	if owner_tag != tag and not Knowledge.discovered(game, tag, hex):
		return {}
	if owner_tag != tag:
		var def := Countries.def_of(game, owner_tag)
		var name := def.name if def != null and def.name != "" else String(owner_tag)
		return {"hex": hex, "name": name, "text": "Also changes %s's district at (%d, %d)" % [name, hex.x, hex.y], "delta": worth,
			"foreign": true}
	var reason := ""
	if int((e0["to"] as Dictionary)["lift"]) != int((e0["from"] as Dictionary)["lift"]):
		reason = " (the %s's market)" % HexCard.level_label(FamilyIds.NAMES[int(target["family"])], int(target["level_to"]))
	else:
		reason = " (more hands)" if int((e0["to"] as Dictionary)["staffing"]) > int((e0["from"] as Dictionary)["staffing"]) else " (fewer hands)"
	var text := "%s %s: %s%s" % [String(game.defs.goods[best].key), Words.place(game, hex), _delta_text(deltas), reason]
	return {"hex": hex, "name": Words.place(game, hex), "text": text, "delta": worth, "foreign": false}


## "+1 a season, +2 in winter"; "+1 spring, +2 summer, ..." when the first three differ.
static func _delta_text(d: Array[int]) -> String:
	if d[0] == d[1] and d[1] == d[2]:
		if d[3] == d[0]:
			return "%s a season" % Words.signed(d[0])
		return "%s a season, %s in winter" % [Words.signed(d[0]), Words.signed(d[3])]
	var parts := PackedStringArray()
	for s: int in 4:
		parts.append("%s %s" % [Words.signed(d[s]), SEASON_NAMES[s].to_lower()])
	return ", ".join(parts)



# --- requirements and next stages -----------------------------------------------------------------------------------


## The ticks of the card: ground, reach, one line for each pair rule that concerns the option, the work slot, the ducats and
## the goods.
static func requirements(game: Game, tag: StringName, hex: Vector2i, action: StringName, target: Dictionary, cost: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var family := int(target["family"])
	var level := int(target["level_to"])
	if action != Works.CLEAR and level >= 1:
		var facts := game.improvement.facts_at(hex)
		var fam := game.defs.family(family) if game.defs != null else null
		if fam != null and fam.ground_text != "":
			out.append({"text": fam.ground_text, "ok": ImproveRules.cell_allowed(family, level, facts)})
		out.append_array(_reach_lines(game, hex, family, level, facts))
		out.append_array(pair_lines(game, hex, family, level))
	if game.has_countries():
		var total := Works.slots(game, tag)
		if total >= 0 and action != Works.CLEAR:
			var used := Works.in_use(game, tag)
			out.append({"text": "a free work slot: %d of %d in use" % [used, total], "ok": used < total})
		var c := Countries.by_tag(game, tag)
		if int(cost["ducats"]) > 0 and c != null:
			out.append({"text": "%s of %s ducats" % [Words.number(int(cost["ducats"])), Words.number(c.treasury)],
				"ok": c.treasury >= int(cost["ducats"])})
		for key: Variant in cost["goods"]:
			var g := game.defs.good_id(StringName(str(key)))
			var have := c.stock[g] if c != null and g >= 0 and g < c.stock.size() else 0
			out.append({"text": "%s of %s %s" % [Words.number(int(cost["goods"][key])), Words.number(have),
				game.defs.goods[g].name.to_lower()], "ok": have >= int(cost["goods"][key])})
	return out


## Stage 2 and 3 reach lines for a goods family: "a place within two hexes or a road", "a town within two hexes".
static func _reach_lines(game: Game, hex: Vector2i, family: int, level: int, facts: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if family == ImproveRules.SETTLEMENT or family == ImproveRules.CASTLE or level < 2 or facts.is_empty():
		return out
	out.append({"text": "a place within two hexes or a road", "ok": int(facts.get("place_distance", 99)) <= 2 or bool(facts.get("road", false))})
	if level == 3:
		out.append({"text": "a town within two hexes", "ok": int(facts.get("town_distance", 99)) <= 2})
		var mining := family == ImproveRules.MINES or family == ImproveRules.QUARRY
		if mining:
			out.append({"text": "a road", "ok": bool(facts.get("road", false))})
		elif not bool(facts.get("coast", false)):
			out.append({"text": "under 1,200 m", "ok": float(facts.get("height_m", 0.0)) <= ImproveRules.HIGH_M - 200.0})
	return out


static func _side(rule_family: int, rule_level: int, family: int, level: int) -> bool:
	if level < rule_level:
		return false
	if rule_family == ImproveRules.ANY_GOODS:
		return family >= ImproveRules.WHEAT
	return family == rule_family


## The pieces within two hexes of `hex`: [{family, level, distance, hex}], what stands and the works under way.
static func _near(game: Game, hex: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var at := Vector2i(hex.x + dx, hex.y + dy)
			var distance := ImproveRules.hex_distance(hex, at)
			var i := game.map.index_of(at)
			if distance < 1 or distance > 2 or i < 0 or game.map.land[i] == 0:
				continue
			if int(game.state.main_use[i]) > 0:
				out.append({"family": int(game.state.main_use[i]), "level": int(game.state.level[i]), "distance": distance, "hex": at})
	for w: Work in game.state.works:
		var distance := ImproveRules.hex_distance(hex, w.hex)
		if w.hex != hex and Works.changes_piece(w) and distance >= 1 and distance <= 2:
			out.append({"family": w.family, "level": w.level_to, "distance": distance, "hex": w.hex})
	return out


static func pair_lines(game: Game, hex: Vector2i, family: int, level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var near := _near(game, hex)
	for r: int in ImproveRules.PAIR_RULES.size():
		var rule: Array = ImproveRules.PAIR_RULES[r]
		var mine_a := _side(int(rule[0]), int(rule[1]), family, level)
		var mine_b := _side(int(rule[2]), int(rule[3]), family, level)
		if not (mine_a or mine_b):
			continue
		var ok := true
		for p: Dictionary in near:
			if int(p["distance"]) > int(rule[4]):
				continue
			if (mine_a and _side(int(rule[2]), int(rule[3]), int(p["family"]), int(p["level"]))) \
					or (mine_b and _side(int(rule[0]), int(rule[1]), int(p["family"]), int(p["level"]))):
				ok = false
				break
		out.append({"text": ImproveRules.PAIR_NEEDS[r], "ok": ok})
	return out


## The first work under way near `hex` that the piece (family, level) would break a pair rule with, as {rule, hex}, as
## Works.pending_conflict walks them; {} for none.
static func pending(game: Game, hex: Vector2i, family: int, level: int) -> Dictionary:
	for w: Work in game.state.works:
		if w.hex == hex or not Works.changes_piece(w):
			continue
		var distance := ImproveRules.hex_distance(hex, w.hex)
		if distance < 1 or distance > 2:
			continue
		var rule := ImproveRules.pair_rule(family, level, w.family, w.level_to, distance)
		if rule >= 0:
			return {"rule": rule, "hex": w.hex}
	return {}


## Each level above the option's: {level, ok, text} (the cell rule and the pair rules against today's neighbours).
static func next_stages(game: Game, hex: Vector2i, target: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var family := int(target["family"])
	var level := int(target["level_to"])
	if family <= 0 or level < 1:
		return out
	var top := FamilyIds.TOP_LEVEL[family]
	if level >= top:
		out.append({"level": level, "ok": false, "text": "None: %s is at its top level." % named(game, hex).replace("this district", "this piece")})
		return out
	var facts := game.improvement.facts_at(hex)
	var near := _near(game, hex)
	var goods := family != ImproveRules.SETTLEMENT and family != ImproveRules.CASTLE
	for lv: int in range(level + 1, top + 1):
		var why := ImproveRules.cell_reason(family, lv, facts) if goods else ""
		if why == "":
			for p: Dictionary in near:
				var rule := ImproveRules.pair_rule(family, lv, int(p["family"]), int(p["level"]), int(p["distance"]))
				if rule >= 0:
					why = pair_text(game, hex, rule, p["hex"] as Vector2i)
					break
		var name := "Stage %d" % lv if goods else _capital(HexCard.level_label(FamilyIds.NAMES[family], lv))
		if why != "":
			out.append({"level": lv, "ok": false, "text": "%s not possible: %s" % [name, why.trim_suffix(".")]})
		else:
			var how := _reach_words(game, hex, family, lv, facts) if goods else ""
			out.append({"level": lv, "ok": true, "text": "%s possible%s." % [name, " (%s)" % how if how != "" else ""]})
	return out


static func _reach_words(game: Game, hex: Vector2i, family: int, level: int, facts: Dictionary) -> String:
	if level == 2:
		var near := _nearest_place(game, hex)
		if near != "":
			return near
		return "a road" if bool(facts.get("road", false)) else "a place within two hexes"
	var mining := family == ImproveRules.MINES or family == ImproveRules.QUARRY
	if mining:
		return "a town within two hexes, on a road"
	if bool(facts.get("coast", false)):
		return "a town within two hexes"
	return "a town within two hexes, under 1,200 m"


## "Savona (6, 13) 1 hex away": the nearest named place within two hexes; "" for none.
static func _nearest_place(game: Game, hex: Vector2i) -> String:
	var best := ""
	var best_distance := 3
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var at := Vector2i(hex.x + dx, hex.y + dy)
			var distance := ImproveRules.hex_distance(hex, at)
			if distance < 1 or distance >= best_distance or not game.map.has(at):
				continue
			var place := Improve.place_of(game.map, at)
			if str(place.get("name", "")) != "" and int(place.get("level", 0)) >= 1:
				best = "%s (%d, %d) %d hex%s away" % [str(place["name"]), at.x, at.y, distance, "" if distance == 1 else "es"]
				best_distance = distance
	return best
