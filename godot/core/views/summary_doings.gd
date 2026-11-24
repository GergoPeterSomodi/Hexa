## What others did in the report: "What befell" gives one line a country for the doings the viewer witnessed in a season
## (docs/architecture/m8-build-spec.md 4.14, D38): works begun, finished and cancelled, men raised and disbanded, taxes set, towns
## grown, districts declined, men lost to hunger. Counted per country, rank = its count of events. Pure core/views/ code:
## reads the game, writes nothing; SeasonSummary puts the lines in its section.
class_name SummaryDoings
extends RefCounted

## The chronicle kinds that are doings (a war, a battle, a siege or a capture is its own line: SummaryWar, SeasonSummary).
const DOING_KINDS: Array[String] = ["work_started", "work_finished", "work_cancelled", "army_raised", "army_disbanded", "tax_set",
	"town_grew", "district_declined", "army_starved", "unit_lost"]


# ----- what befell: the doings of others, one line a country (4.14, D38) -------------------------------------------


## One line a country the viewer witnessed doing something in `turn`: "Milan began 2 works, raised 1,000 men at Novara
## (7, 8) and set taxes to Low." The parts are counted; the rank is the count of events; the link is the first event's hex.
## The viewer's own doings are not here (their sections are), and an event the viewer is not told of is not counted.
static func of(game: Game, tag: StringName, turn: int) -> Array[Dictionary]:
	var groups: Dictionary = {}
	var order: Array[StringName] = []
	for entry: Dictionary in game.chronicle.of_turn(turn):
		var kind := str(entry.get("kind", ""))
		if not DOING_KINDS.has(kind):
			continue
		var actor := StringName(str(entry.get("tag", "")))
		var line := LogLines.line_of(game, entry, tag)
		if actor == tag or actor == &"" or line.is_empty() or bool(line["mine"]):
			continue
		if not groups.has(actor):
			groups[actor] = {"events": 0, "hex": line.get("hex", WorksView.NO_HEX), "started": 0, "finished": 0, "cancelled": 0,
				"raised": 0, "raised_men": 0, "raised_hex": WorksView.NO_HEX, "disbanded": 0, "disbanded_men": 0,
				"tax": "", "grew": 0, "declined": 0, "units": 0, "starved_men": 0}
			order.append(actor)
		_count(groups[actor] as Dictionary, entry, kind)
	var out: Array[Dictionary] = []
	for actor: StringName in order:
		var t := groups[actor] as Dictionary
		var line := _line(_sentence(game, actor, t), "plain", int(t["events"]))
		line["hex"] = t["hex"]
		out.append(line)
	return out


static func _count(t: Dictionary, entry: Dictionary, kind: String) -> void:
	t["events"] = int(t["events"]) + 1
	match kind:
		"work_started":
			t["started"] = int(t["started"]) + 1
		"work_finished":
			t["finished"] = int(t["finished"]) + 1
		"work_cancelled":
			t["cancelled"] = int(t["cancelled"]) + 1
		"army_raised":
			if int(t["raised"]) == 0:
				t["raised_hex"] = entry.get("hex", WorksView.NO_HEX)
			t["raised"] = int(t["raised"]) + 1
			t["raised_men"] = int(t["raised_men"]) + int(entry.get("men", 0))
		"army_disbanded":
			t["disbanded"] = int(t["disbanded"]) + 1
			t["disbanded_men"] = int(t["disbanded_men"]) + int(entry.get("men", 0))
		"tax_set":
			t["tax"] = Words.tax_name(int(entry.get("level", -1)))
		"town_grew":
			t["grew"] = int(t["grew"]) + 1
		"district_declined":
			t["declined"] = int(t["declined"]) + 1
		"army_starved":
			t["starved_men"] = int(t["starved_men"]) + int(entry.get("lost", 0))
		"unit_lost":
			t["units"] = int(t["units"]) + 1


## "Milan began 2 works, raised 1,000 men at Novara (7, 8) and set taxes to Low." Every part is named (Words.list
## with all of them shown).
static func _sentence(game: Game, actor: StringName, t: Dictionary) -> String:
	var parts: Array[String] = []
	if int(t["started"]) > 0:
		parts.append("began %s" % Words.plural(int(t["started"]), "work", "works"))
	if int(t["finished"]) > 0:
		parts.append("finished %s" % Words.plural(int(t["finished"]), "work", "works"))
	if int(t["cancelled"]) > 0:
		parts.append("cancelled %s" % Words.plural(int(t["cancelled"]), "work", "works"))
	if int(t["raised"]) > 0:
		parts.append("raised %s %s" % [Words.men(int(t["raised_men"])), Words.at(game, t["raised_hex"] as Vector2i)])
	if int(t["disbanded"]) > 0:
		parts.append("disbanded %s" % Words.men(int(t["disbanded_men"])))
	if str(t["tax"]) != "":
		parts.append("set taxes to %s" % str(t["tax"]))
	if int(t["grew"]) > 0:
		parts.append("%s grew" % Words.plural(int(t["grew"]), "town", "towns"))
	if int(t["declined"]) > 0:
		parts.append("%s declined" % Words.plural(int(t["declined"]), "district", "districts"))
	if int(t["starved_men"]) > 0:
		parts.append("lost %s to hunger" % Words.men(int(t["starved_men"])))
	elif int(t["units"]) > 0:
		parts.append("lost %s to hunger" % Words.plural(int(t["units"]), "company", "companies"))
	return "%s %s." % [LogLines.short_name(game, actor), Words.list(parts, maxi(parts.size(), 1))]


static func _line(text: String, tone: String, rank: int) -> Dictionary:
	return {
		"text": text, "detail": "", "amount": 0, "unit": &"", "tone": tone, "value": 0, "from": 0, "to": 0,
		"hex": WorksView.NO_HEX, "rank": rank, "top": false, "sub": false, "action": [], "action_label": "",
	}
