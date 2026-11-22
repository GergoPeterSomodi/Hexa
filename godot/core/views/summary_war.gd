## The War part of the season report (docs/architecture/m7-build-spec.md 4.17, 4.14, 4.15; M7 B19): the wars the viewer is in
## this season (its battles, sieges, captures and losses, peaces and declarations, and a sub line of the war score), the war
## lines of "Your orders" (declared, made peace, storm, standing) and the war events of others that the viewer witnessed
## ("What befell"), plus the glance's War chips. SeasonSummary asks for them and puts them in the report; this file lives apart
## to keep that one small. The lines about the viewer's own state (sieges, the score, the chips) are read from the state, so
## they are only written for the season that just closed; an older report has its chronicle lines only. Pure core/views/
## code: it reads the game and writes nothing.
class_name SummaryWar
extends RefCounted

@warning_ignore_start("integer_division")

## The chronicle kinds of the war section and of What befell (4.14); the army and the log lines come from LogLinesWar.
const EVENT_KINDS: Array[String] = ["war_declared", "peace_made", "battle_ended", "siege_started", "siege_lifted",
	"district_captured"]
## The action-log kinds of "Your orders" that the war section words itself.
const ORDER_KINDS: Array[String] = ["declare_war", "make_peace", "storm", "set_standing"]
const SIDE_ATTACKER := 0
const SIDE_DEFENDER := 1
const UNKNOWN := "a country"


## {section (the War section; {} when there is no line and no war), quiet (no war event of the viewer's and no live siege of
## its own), chips (the glance's War chips: one per live war of the viewer, when the season just closed)}.
static func of(game: Game, tag: StringName, turn: int) -> Dictionary:
	var out := {"section": {}, "quiet": true, "chips": [] as Array[Dictionary]}
	if game == null or game.state == null or not game.has_countries() or Countries.by_tag(game, tag) == null:
		return out
	var last := turn == game.turn - 1
	var lines: Array[Dictionary] = []
	for entry: Dictionary in game.chronicle.of_turn(turn):
		if EVENT_KINDS.has(str(entry.get("kind", ""))) and LogLinesWar.mine(entry, tag):
			var line := _event_line(game, entry, tag)
			if not line.is_empty():
				lines.append(line)
	var sieges: Array[Dictionary] = []
	if last:
		sieges = _sieges(game, tag)
	for line: Dictionary in sieges:
		lines.append(line)
	var enemies := active_enemies(game, tag, turn)
	var chips: Array[Dictionary] = []
	if last:
		for enemy: StringName in enemies:
			var score := Wars.score(game, tag, enemy)
			lines.append(_sub(_score_text(game, tag, enemy, score)))
			chips.append(_chip(game, tag, enemy, score))
	out["quiet"] = _only_subs(lines)
	out["chips"] = chips
	var total := {}
	if not enemies.is_empty():
		total = _line("At war with %s" % Words.plural(enemies.size(), "country", "countries"), "plain", 0)
	elif not lines.is_empty():
		total = _line("At peace", "plain", 0)
	if lines.is_empty() and total.is_empty():
		return out
	var ranked := _ranked(lines)
	out["section"] = {"id": &"war", "title": "War", "count": ranked.size(), "total": total,
		"lines": ranked.slice(0, SeasonSummary.SHOWN), "more": maxi(ranked.size() - SeasonSummary.SHOWN, 0), "unchanged": ""}
	return out


## The war lines of "Your orders" in `turn` by `tag`: "Declared war on the Duchy of Milan.", "Made peace with the Duchy of
## Milan: took 2 districts.", "Ordered to storm: the Army of Vercelli at Pavia (10, 9).", "The Army of Turin now withdraws when
## attacked.". Read from the action log, so a load gives the same lines.
static func orders(game: Game, tag: StringName, turn: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null or not game.has_countries():
		return out
	for record: Dictionary in game.action_log:
		if int(record.get("turn", -1)) != turn or not ORDER_KINDS.has(str(record.get("action", ""))):
			continue
		var args: Variant = record.get("args", {})
		if not (args is Dictionary) or StringName(str((args as Dictionary).get("tag", ""))) != tag:
			continue
		var text := _order_text(game, tag, turn, str(record["action"]), args as Dictionary)
		if not text.is_empty():
			out.append(_order(text, _hex_arg((args as Dictionary).get("goal", (args as Dictionary).get("hex", null)))))
	return out


## The witnessed war events of others in `turn` (What befell): wars and peaces between others (public), and the battles,
## sieges and districts of others the viewer witnessed. The viewer's own are in the section, never here.
static func witnessed(game: Game, tag: StringName, turn: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null or not game.has_countries():
		return out
	for entry: Dictionary in game.chronicle.of_turn(turn):
		if not EVENT_KINDS.has(str(entry.get("kind", ""))) or LogLinesWar.mine(entry, tag):
			continue
		var line: Dictionary = {}
		if str(entry.get("kind", "")) == "battle_ended":
			line = _other_battle_line(game, entry, tag)
		else:
			var found := LogLines.line_of(game, entry, tag)
			if not found.is_empty() and not bool(found["mine"]):
				line = _line(str(found["text"]), "plain" if str(found["tone"]) == "muted" else str(found["tone"]), 0)
				line["hex"] = found["hex"]
		if not line.is_empty():
			out.append(line)
	return out


## The countries the viewer is at war with in `turn`: a war is active from its declaration to its end (the end season
## included), in country id order. Each country once.
static func active_enemies(game: Game, tag: StringName, turn: int) -> Array[StringName]:
	var ids := PackedInt32Array()
	for w: War in Wars.of_country(game, tag):
		if w.start_turn > turn or (w.end_turn != 0 and w.end_turn < turn):
			continue
		var c := Countries.by_tag(game, w.other(tag))
		if c != null and not ids.has(c.id):
			ids.append(c.id)
	ids.sort()
	var out: Array[StringName] = []
	for id: int in ids:
		out.append(Countries.by_id(game, id).tag)
	return out


## The men of a battle record that side booked as lost (Stats' rule: killed, plus the wounded, less the wounded who went back
## to their units). Side 0 is the attacker, 1 the defender.
static func men_booked(game: Game, r: BattleRecord, side: int) -> int:
	var killed: PackedInt32Array = r.end.get("killed", PackedInt32Array([0, 0]))
	var wounded: PackedInt32Array = r.end.get("wounded_total", PackedInt32Array([0, 0]))
	if killed.size() < 2 or wounded.size() < 2 or (side != SIDE_ATTACKER and side != SIDE_DEFENDER):
		return 0
	var side_tag := r.attacker if side == SIDE_ATTACKER else r.defender
	var owner := _owners(game)
	var back := 0
	var returned: Dictionary = r.end.get("returned", {})
	for uid: Variant in returned:
		if owner.get(int(uid), &"") == side_tag:
			back += int(returned[uid])
	return int(killed[side]) + int(wounded[side]) - back


# ----- the section -----------------------------------------------------------------------------------------------------


## One line of the viewer's own war events: a battle of its side, a peace, a declaration, a capture, a lift.
static func _event_line(game: Game, entry: Dictionary, tag: StringName) -> Dictionary:
	if str(entry.get("kind", "")) == "battle_ended":
		return _battle_line(game, entry, tag)
	var found := LogLines.line_of(game, entry, tag)
	if found.is_empty():
		return {}
	var rank := 0 if str(entry.get("kind", "")) == "siege_lifted" else 1
	var line := _line(str(found["text"]), _plain_tone(str(found["tone"])), rank)
	line["hex"] = found["hex"]
	return line


## "Battle of Alessandria, 1480: you won in 4 days. You lost 120 men, they 410." The men are booked (men_booked), so the
## section's sums are the stats' battle losses; the line opens the battle's record in the dock.
static func _battle_line(game: Game, entry: Dictionary, tag: StringName) -> Dictionary:
	var attacker := StringName(str(entry.get("tag", "")))
	var mine_side := SIDE_ATTACKER if attacker == tag else SIDE_DEFENDER
	var their_side := 1 - mine_side
	var record := Battles.record(game, int(entry.get("record", -1)))
	var mine := 0
	var theirs := 0
	if record != null:
		mine = men_booked(game, record, mine_side)
		theirs = men_booked(game, record, their_side)
	else:
		mine = _pair(entry, "killed", tag) + _pair(entry, "wounded", tag)
	var how := str(entry.get("how", ""))
	var winner := StringName(str(entry.get("winner", "")))
	var head := str(entry.get("name", ""))
	var outcome := ""
	var tone := "plain"
	var days := Words.plural(int(entry.get("days", 0)), "day", "days")
	if how == "peace":
		outcome = "the fight ended with the peace"
	elif winner == tag:
		outcome = "you won in %s" % days
		tone = "good"
	elif winner != &"":
		outcome = "you lost in %s" % days
		tone = "bad"
	else:
		outcome = "no side won in %s" % days
	var text := "%s: %s." % [head, outcome] if how == "peace" else \
		"%s: %s. You lost %s men, they %s." % [head, outcome, Words.number(mine), Words.number(theirs)]
	var line := _line(text, tone, mine)
	line["hex"] = entry.get("hex", WorksView.NO_HEX)
	line["action"] = [&"battle", int(entry.get("record", -1))]
	line["action_label"] = "Open the battle"
	return line


## A battle between others the viewer witnessed: "Battle of Gavi, 1481: Milan beat Genoa." (muted, as the log has it).
static func _other_battle_line(game: Game, entry: Dictionary, viewer: StringName) -> Dictionary:
	if not Knowledge.witnessed(game, entry, viewer):
		return {}
	var attacker := StringName(str(entry.get("tag", "")))
	var defender := StringName(str(entry.get("defender", "")))
	var winner := StringName(str(entry.get("winner", "")))
	var loser := StringName(str(entry.get("loser", "")))
	var head := str(entry.get("name", ""))
	var body := ""
	if str(entry.get("how", "")) == "peace":
		body = "the fight ended with the peace"
	elif winner != &"" and loser != &"":
		body = "%s beat %s" % [_short(game, viewer, winner), _short(game, viewer, loser)]
	else:
		body = "%s and %s fought to a draw" % [_short(game, viewer, attacker), _short(game, viewer, defender)]
	var line := _line("%s: %s." % [head, body], "plain", 0)
	line["hex"] = entry.get("hex", WorksView.NO_HEX)
	return line


## The sieges the viewer is part of: its own (the besieger's line: the siege's own name as Sieges names it, "Siege of Pavia, 1480",
## then the meter, the rate and the forecast, as SiegeView reads them) and the fortresses it holds that another besieges (the
## plain place name, "your Pavia (10, 9)"). Rank: the men still to bring the meter to its need.
static func _sieges(game: Game, tag: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Siege in game.sieges:
		var holder := Occupation.controller_tag(game, s.hex)
		if s.besieger != tag and holder != tag:
			continue
		var view := SiegeView.at(game, tag, s.hex)
		if view.is_empty():
			continue
		var progress := int(view["progress"])
		var need := int(view["need"])
		var plain := plain_place(game, s.hex)
		var line: Dictionary
		if s.besieger == tag:
			var head := s.name if s.name != "" else "Siege of %s" % plain
			var clause := ""
			if int(view["rate"]) > 0:
				clause += ", +%s a season" % Words.number(int(view["rate"]))
			if int(view["falls_in"]) > 0:
				clause += "; falls in about %s" % Words.seasons(int(view["falls_in"]))
			line = _line("%s: %s of %s%s." % [head, Words.number(progress), Words.number(need), clause], "good", maxi(need - progress, 0))
		else:
			line = _line("%s besieges your %s (%d, %d): %s of %s." % [LogLines.capital(LogLines.short_name(game, s.besieger)),
				plain, s.hex.x, s.hex.y, Words.number(progress), Words.number(need)], "bad", maxi(need - progress, 0))
		line["hex"] = s.hex
		line["action"] = [&"look_at", s.hex]
		line["action_label"] = "Go to %s" % plain
		out.append(line)
	return out


## The plain name of the place of a hex ("Pavia"), without its coordinates; "(10, 9)" for a hex with no place name.
static func plain_place(game: Game, hex: Vector2i) -> String:
	var name := str(Improve.place_of(game.map, hex).get("name", ""))
	return name if name != "" else "(%d, %d)" % [hex.x, hex.y]


## The lines by rank, largest first (ties keep the order of the season's log), sub lines last: SeasonSummary's _section order
## (spec 4.17), so the lines it shows are the largest, not the first in the chronicle.
static func _ranked(lines: Array[Dictionary]) -> Array[Dictionary]:
	var keys: Array[Array] = []
	for i: int in lines.size():
		var sub := 1 if bool(lines[i].get("sub", false)) else 0
		keys.append([sub, -int(lines[i]["rank"]), i])
	keys.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[0]) != int(b[0]):
			return int(a[0]) < int(b[0])
		if int(a[1]) != int(b[1]):
			return int(a[1]) < int(b[1])
		return int(a[2]) < int(b[2]))
	var out: Array[Dictionary] = []
	for key: Array in keys:
		out.append(lines[int(key[2])])
	return out


# ----- helpers ---------------------------------------------------------------------------------------------------------


## A sub line of the war score: "War score with Milan +2: you hold 2 of their districts, they hold none of yours."
static func _score_text(game: Game, tag: StringName, enemy: StringName, score: int) -> String:
	var held := Wars.occupied_count(game, tag, enemy)
	var lost := Wars.occupied_count(game, enemy, tag)
	return "War score with %s %s: you hold %s of their districts, they hold %s of yours." % [LogLines.short_name(game, enemy),
		Words.signed(score), "none" if held == 0 else Words.number(held), "none" if lost == 0 else Words.number(lost)]


## The glance's chip of one live war: "At war with Milan: +2".
static func _chip(game: Game, tag: StringName, enemy: StringName, score: int) -> Dictionary:
	var tone := "good" if score > 0 else ("bad" if score < 0 else "plain")
	var line := _line("At war with %s: %s" % [LogLines.short_name(game, enemy), Words.signed(score)], tone, 0)
	line["hex"] = _capital_of(game, tag)
	return line


static func _capital_of(game: Game, tag: StringName) -> Vector2i:
	var c := Countries.by_tag(game, tag)
	return c.capital if c != null else WorksView.NO_HEX


static func _order_text(game: Game, tag: StringName, turn: int, action: String, args: Dictionary) -> String:
	var target := StringName(str(args.get("target", "")))
	match action:
		"declare_war":
			return "Declared war on %s." % Words.country_the(game, target)
		"make_peace":
			var terms := str(args.get("terms", ""))
			var moved := _moved_of(game, tag, target, turn)
			var what := "a white peace" if terms == "white" else ("%s %s" % [
				"took" if terms == "take" else "gave up", Words.plural(moved, "district", "districts")])
			return "Made peace with %s: %s." % [Words.country_the(game, target), what]
		"storm":
			var army := Armies.by_id(game, int(args.get("army", -1)))
			var name := "the %s" % army.name if army != null and army.name != "" else "your army"
			return "Ordered to storm: %s %s." % [name, Words.at(game, _hex_arg(args.get("goal", null)))]
		"set_standing":
			var army_s := Armies.by_id(game, int(args.get("army", -1)))
			var name_s := "the %s" % army_s.name if army_s != null and army_s.name != "" else "your army"
			var word := "holds" if str(args.get("standing", "")) == String(Army.STANDING_HOLD) else "withdraws"
			return "%s now %s when attacked." % [LogLines.capital(name_s), word]
	return ""


## The districts a peace of `tag` with `target` moved in `turn` (the chronicle's peace entry); 0 when none is kept.
static func _moved_of(game: Game, tag: StringName, target: StringName, turn: int) -> int:
	for entry: Dictionary in game.chronicle.of_turn(turn):
		if str(entry.get("kind", "")) == "peace_made" and StringName(str(entry.get("tag", ""))) == tag \
				and StringName(str(entry.get("target", ""))) == target:
			return (entry.get("moved", []) as Array).size() if entry.get("moved", null) is Array else 0
	return 0


static func _owners(game: Game) -> Dictionary:
	var out := {}
	for a: Army in game.armies:
		for u: Unit in a.units:
			out[u.id] = a.tag
	return out


## True when every line is a sub line (no event, no siege): the season is quiet in war.
static func _only_subs(lines: Array[Dictionary]) -> bool:
	for line: Dictionary in lines:
		if not bool(line.get("sub", false)):
			return false
	return true


static func _short(game: Game, viewer: StringName, tag: StringName) -> String:
	if tag == &"" or not Knowledge.knows(game, viewer, tag):
		return UNKNOWN
	return LogLines.short_name(game, tag)


static func _pair(entry: Dictionary, key: String, tag: StringName) -> int:
	var value: Variant = entry.get(key, null)
	return int((value as Dictionary).get(String(tag), 0)) if value is Dictionary else 0


static func _hex_arg(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value as Vector2i
	if value is Array and (value as Array).size() == 2:
		return Vector2i(int((value as Array)[0]), int((value as Array)[1]))
	return WorksView.NO_HEX


static func _plain_tone(tone: String) -> String:
	return "plain" if tone == "muted" else tone


static func _order(text: String, hex: Vector2i) -> Dictionary:
	var line := _line(text, "plain", 0)
	line["hex"] = hex
	return line


static func _sub(text: String) -> Dictionary:
	var line := _line(text, "plain", 0)
	line["sub"] = true
	return line


static func _line(text: String, tone: String, rank: int) -> Dictionary:
	return {
		"text": text, "detail": "", "amount": 0, "unit": &"", "tone": tone, "value": 0, "from": 0, "to": 0,
		"hex": WorksView.NO_HEX, "rank": rank, "top": false, "sub": false, "action": [], "action_label": "",
	}
