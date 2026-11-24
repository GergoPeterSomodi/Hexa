## The Armies part of the season report (docs/architecture/m6-build-spec.md 4.14 and 4.11; L12): the men under arms and the
## armies of the viewer that moved, changed men, musters or lost companies; the army lines of "Your orders" (raised, disbanded,
## marched, held, split, joined); the foreign armies in sight ("What befell"; the others' army doings are SummaryDoings'). SeasonSummary
## asks for them and puts them in the report; this file lives apart to keep that one small. Pure core/views/ code: it reads
## the game and writes nothing.
class_name SummaryArmies
extends RefCounted

@warning_ignore_start("integer_division")

## The men under arms changed under this many percent of the season before leave the season quiet (with no army event).
const QUIET_PERCENT := 2
## The chronicle kinds an army event of a season is (its lines are the report's; any of them makes the season not quiet).
const EVENT_KINDS: Array[String] = ["army_raised", "army_disbanded", "army_starved", "unit_lost", "march_halted"]
## The action-log kinds of "Your orders" that the army section words itself (the others come from the chronicle).
const ORDER_KINDS: Array[String] = ["march", "halt", "continue_march", "split_army", "merge_armies"]


## {had (the viewer had armies this season or the last), men, change (the men under arms of this season less the last),
## section (the Armies section; {} when the viewer had none and no line), quiet (no army event, no march and the men changed
## under QUIET_PERCENT), sight (the foreign armies in sight: What befell lines, the season that just ended only)}.
static func of(game: Game, tag: StringName, turn: int) -> Dictionary:
	var out := {"had": false, "men": 0, "change": 0, "section": {}, "quiet": true, "sight": [] as Array[Dictionary]}
	if game == null or game.stats == null or not game.has_countries() or Countries.by_tag(game, tag) == null:
		return out
	var stats := game.stats
	if not stats.has_row(turn):
		return out
	var now := stats.value(tag, turn, "army_men")
	var before := stats.value(tag, turn - 1, "army_men") if turn > 1 and stats.has_row(turn - 1) else 0
	var change := now - before
	var last := turn == game.turn - 1
	var had := now > 0 or before > 0
	var lines: Array[Dictionary] = []
	var moved := 0
	var eventful := false
	for entry: Dictionary in game.chronicle.of_turn(turn):
		var kind := str(entry.get("kind", ""))
		if EVENT_KINDS.has(kind) and not LogLines.line_of(game, entry, tag).is_empty():
			eventful = true
		if kind == "unit_lost" and StringName(str(entry.get("tag", ""))) == tag:
			var line := LogLines.line_of(game, entry, tag)
			if not line.is_empty():
				lines.append(_line(str(line["text"]), str(line["tone"]), 1))
	if last:
		for a: Army in Armies.of_country(game, tag):
			if a.moved_from != Army.NO_HEX:
				moved += 1
				var walked := _line("%s: %s → %s, %s." % [a.name, Words.place(game, a.moved_from), Words.place(game, a.hex),
					Words.men(a.men())], "plain", 1)
				walked["hex"] = a.hex
				walked["action"] = [&"select_army", a.id]
				lines.append(walked)
			if a.lost_last > 0:
				var lost := _line("%s %s: %s men %s %s%s, %s." % [a.name, Words.at(game, a.hex), Words.number(a.men()),
					"▼", Words.MINUS, Words.number(a.lost_last), "out of supply" if a.supply != Supply.FED else "hungry"],
					"bad", a.lost_last)
				lost["hex"] = a.hex
				lost["action"] = [&"select_army", a.id]
				lines.append(lost)
			elif _raised_in(a, turn):
				var musters := _line("%s %s: %s, mustering." % [a.name, Words.at(game, a.hex), Words.men(a.men())],
					"plain", 1)
				musters["hex"] = a.hex
				musters["action"] = [&"select_army", a.id]
				lines.append(musters)
		var upkeep := Military.upkeep_country(game, tag)
		var sub: Array[Dictionary] = []
		if upkeep > 0:
			sub.append(_sub("Upkeep: %s a season." % Words.ducats(upkeep)))
		var ate := _food_eaten(game, tag, turn)
		if not ate.is_empty():
			sub.append(_sub("Your armies ate %s from the stores." % ate))
		lines.append_array(sub)
	var quiet := not eventful and moved == 0 and absi(change) * 100 < QUIET_PERCENT * maxi(1, before)
	var shown := had or not lines.is_empty()
	out["had"] = had
	out["men"] = now
	out["change"] = change
	out["quiet"] = quiet
	if shown:
		var total := _line("Men under arms %s → %s" % [Words.number(before), Words.number(now)], _tone_of(change), 0)
		total["from"] = before
		total["to"] = now
		total["amount"] = change
		out["section"] = {"id": &"armies", "title": "Armies", "count": lines.size(), "total": total,
			"lines": lines.slice(0, SeasonSummary.SHOWN), "more": maxi(lines.size() - SeasonSummary.SHOWN, 0), "unchanged": ""}
	if last:
		out["sight"] = _sight(game, tag)
	return out


## The orders of `turn` by `tag` in the army kinds, in the order of the season's log: "Raised 2 companies of pikemen at Turin
## (5, 9) (▼ −50).", "Ordered to march: the Army of Turin to Vercelli (6, 9).", "Ordered to hold: the Army of Turin.", "Split
## the Army of Turin.", "Joined ... to ...", "Disbanded 1 company of pikemen of the Army of Turin (+25 ducats back)."
static func orders(game: Game, tag: StringName, turn: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null or not game.has_countries():
		return out
	for entry: Dictionary in game.chronicle.of_turn(turn):
		var kind := str(entry.get("kind", ""))
		if StringName(str(entry.get("tag", ""))) != tag:
			continue
		if kind == "army_raised":
			out.append(_order(_raised_text(game, entry), entry.get("hex", WorksView.NO_HEX) as Vector2i))
		elif kind == "army_disbanded":
			out.append(_order(_disbanded_text(game, entry), entry.get("hex", WorksView.NO_HEX) as Vector2i))
	for record: Dictionary in game.action_log:
		if int(record.get("turn", -1)) != turn or not ORDER_KINDS.has(str(record.get("action", ""))):
			continue
		var args: Variant = record.get("args", {})
		if not (args is Dictionary) or StringName(str((args as Dictionary).get("tag", ""))) != tag:
			continue
		var text := _action_text(game, str(record["action"]), args as Dictionary)
		if not text.is_empty():
			out.append(_order(text, _hex_arg((args as Dictionary).get("goal", null))))
	return out


# ----- helpers ----------------------------------------------------------------------------------------------------------


## The foreign armies in sight that the viewer knows: "A Milanese army of 1,000 men stands at Alessandria (7, 9)."
static func _sight(game: Game, tag: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in Knowledge.armies_seen(game, tag):
		var a := item["army"] as Army
		if a == null or not ArmyView.visible(game, tag, a) or a.tag == tag:
			continue
		var line := _line("%s of %s stands %s." % [Words.army_of(game, a.tag), Words.men(a.men()),
			Words.at(game, a.hex)], "plain", 0)
		line["hex"] = a.hex
		line["action"] = [&"look_at", a.hex]
		out.append(line)
	return out


## Whether a unit of `a` was raised in `turn` (the army's companies are raised in the season that made them).
static func _raised_in(a: Army, turn: int) -> bool:
	return a.mustering(turn)


## The loads the armies ate of each good in the closed goods of `turn` ("1 grain", "1 grain, 2 fish"); "" when none.
static func _food_eaten(game: Game, tag: StringName, turn: int) -> String:
	var c := Countries.by_tag(game, tag)
	if c == null or game.defs == null or int(c.goods_closed.get("turn", -1)) != turn:
		return ""
	var flows := c.goods_closed.get("flows", PackedInt32Array()) as PackedInt32Array
	var closing := c.goods_closed.get("closing", PackedInt32Array()) as PackedInt32Array
	var flow := Stores.FLOWS.find(&"army")
	var parts: Array[String] = []
	for g: int in mini(closing.size(), game.defs.goods.size()):
		var at := flow * closing.size() + g
		if at < flows.size() and flows[at] != 0:
			parts.append(Words.loads(absi(flows[at]), game.defs.goods[g].name))
	return Words.list(parts, parts.size()) if not parts.is_empty() else ""


static func _raised_text(game: Game, entry: Dictionary) -> String:
	var hex := entry.get("hex", WorksView.NO_HEX) as Vector2i
	var def := _unit_def(game, entry)
	var count := int(entry.get("count", 0))
	var what := Words.units(count, def) if def != null else Words.plural(count, "company", "companies")
	return "Raised %s %s (▼ %s%s)." % [what, Words.at(game, hex), Words.MINUS, Words.number(int(entry.get("ducats", 0)))]


static func _disbanded_text(game: Game, entry: Dictionary) -> String:
	var def := _unit_def(game, entry)
	var count := (entry.get("units", []) as Array).size() if entry.get("units", null) is Array else 0
	var what := Words.units(count, def) if def != null else Words.plural(count, "company", "companies")
	var of_army := " of the %s" % str(entry.get("name", "army")) if str(entry.get("name", "")) != "" else ""
	var refund := int(entry.get("refund", 0))
	var back := " (+%s back)" % Words.ducats(refund) if refund > 0 else ""
	return "Disbanded %s%s%s." % [what, of_army, back]


## The text of one army order of the action log; "" for an action that says nothing.
static func _action_text(game: Game, action: String, args: Dictionary) -> String:
	var army := Armies.by_id(game, int(args.get("army", -1)))
	var name := "the %s" % army.name if army != null and army.name != "" else "your army"
	match action:
		"march":
			var goal := _hex_arg(args.get("goal", null))
			return "Ordered to march: %s %s." % [name, Words.at(game, goal, "to")]
		"continue_march":
			return "Ordered to march on: %s." % name
		"halt":
			# A halt on a march keeps its goal (the army can march on); a second halt holds it. The army's state at the report.
			if army != null and army.order == Army.ORDER_NONE and army.goal != Army.NO_HEX:
				return "Halted: %s, which can march on." % name
			return "Ordered to hold: %s." % name
		"split_army":
			return "Split %s." % name
		"merge_armies":
			var into := Armies.by_id(game, int(args.get("into", -1)))
			var joined := "an army" if into == null else "the %s" % into.name
			return "Joined %s to %s." % [name if army != null else "an army", joined]
	return ""


static func _order(text: String, hex: Vector2i) -> Dictionary:
	var line := _line(text, "plain", 0)
	line["hex"] = hex
	return line


## A hex argument of the action log: a Vector2i, or the two ints of a plain array (the log keeps plain values).
static func _hex_arg(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value as Vector2i
	if value is Array and (value as Array).size() == 2:
		return Vector2i(int((value as Array)[0]), int((value as Array)[1]))
	return WorksView.NO_HEX


static func _unit_def(game: Game, entry: Dictionary) -> UnitDef:
	if game == null or game.defs == null or not entry.has("kind_id"):
		return null
	return game.defs.unit_def(int(entry["kind_id"]))


static func _tone_of(amount: int) -> String:
	return "good" if amount > 0 else ("bad" if amount < 0 else "plain")


static func _sub(text: String) -> Dictionary:
	var line := _line(text, "plain", 0)
	line["sub"] = true
	return line


static func _line(text: String, tone: String, rank: int) -> Dictionary:
	return {
		"text": text, "detail": "", "amount": 0, "unit": &"", "tone": tone, "value": 0, "from": 0, "to": 0,
		"hex": WorksView.NO_HEX, "rank": rank, "top": false, "sub": false, "action": [], "action_label": "",
	}
