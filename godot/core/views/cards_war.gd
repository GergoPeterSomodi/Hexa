## The hover cards of the war's map marks (docs/architecture/m7-build-spec.md 5.6, 6.3; M7 B23): a battle site (WarCards.site)
## and a siege dial (WarCards.siege). Each reads the BattleView or SiegeView of the viewer, so the fog is theirs: a witness
## of a battle reads its totals rounded; a siege's rate and forecast show only to its besieger and defender, and a viewer who
## sees the hex reads the meter and no more. Pure core/views/ code: no nodes, no engine calls, no writes.
class_name WarCards
extends RefCounted

const TONE_PLAIN := &"plain"
const HINT_SITE := "Click: the battle"
const HINT_SIEGE := "Click: the hex"


## A battle site's card for the viewer: {title (the battle's name), lines ([[text, tone]]: the result, then each side's killed
## and wounded), hint}. {} when the viewer may not see the battle (BattleView.of gives nothing).
static func site(game: Game, viewer: StringName, record_id: int) -> Dictionary:
	var v := BattleView.of(game, viewer, record_id)
	if v.is_empty():
		return {}
	var lines: Array = [[str(v.result.text), v.result.tone]]
	if bool(v.kept):
		for side: Variant in (v.side as Dictionary).values():
			var s: Dictionary = side
			lines.append(["%s: %s killed, %s wounded." % [str(s.name), Words.number(int(s.killed)),
				Words.number(int(s.wounded))], TONE_PLAIN])
	else:
		lines.append([str(v.note), TONE_PLAIN])
	return {"title": str(v.name), "lines": lines, "hint": HINT_SITE}


## A siege dial's card: {title ("Siege of Pavia: 6 of 10"), lines ([[text, tone]]), hint}. The besieger and the defender read
## the rate, the forecast season and the stores; a viewer who only sees the hex reads who besieges and no numbers beyond the
## meter. {} when the viewer may not see the siege (SiegeView.at gives nothing).
static func siege(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary:
	var v := SiegeView.at(game, viewer, hex)
	if v.is_empty():
		return {}
	var title := "%s: %d of %d" % [_plain_name(str(v.name)), int(v.progress), int(v.need)]
	var lines: Array = []
	if str(v.access) == "exact":
		lines.append(["Each season +%d" % int(v.rate), TONE_PLAIN])
		var falls := int(v.falls_in)
		lines.append(["Falls in about %s" % _seasons_text(falls) if falls >= 0 else "Will not fall at this rate", TONE_PLAIN])
		if bool(v.starving):
			lines.append(["The garrison is starving", SiegeView.TONE_BAD])
		else:
			lines.append(["The garrison starves after %d" % int(v.stores_left), TONE_PLAIN])
	else:
		lines.append(["Besieged by %s" % str(v.besieger_name), TONE_PLAIN])
	return {"title": title, "lines": lines, "hint": HINT_SIEGE}


## A siege's name without its year: "Siege of Pavia, 1480" -> "Siege of Pavia".
static func _plain_name(name: String) -> String:
	var at := name.rfind(", ")
	if at > 0 and name.substr(at + 2).is_valid_int():
		return name.substr(0, at)
	return name


## "1 season", "4 seasons".
static func _seasons_text(n: int) -> String:
	return "%d season%s" % [n, "" if n == 1 else "s"]
