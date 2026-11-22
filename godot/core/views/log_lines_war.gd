## The war lines of the action log (docs/architecture/m7-build-spec.md 4.14, 4.15): the sentences of war_declared, peace_made,
## battle_ended, siege_started, siege_lifted and district_captured for one viewer. LogLines.line_of calls this for those
## kinds (a split of LogLines, which would pass 800 lines). Pure core/views/ code that reads the chronicle entry alone, so
## a line is the same live and after a load. Wars and peaces are public (4.15: every living country witnesses them), so
## their names are always told; a battle, a siege or a district names a country the viewer does not know as "a country"
## (Knowledge.knows, as M6's LogLines._told_name does for armies).
class_name LogLinesWar
extends RefCounted

const WAR_KINDS: Array[String] = ["war_declared", "peace_made", "battle_ended", "siege_started", "siege_lifted",
	"district_captured"]
const LIFT_WHYS: Array[String] = ["left", "relief", "outnumbered", "peace"]
const TERMS: Array[String] = ["take", "white", "yield", "timer"]
const BY_WORDS: Array[String] = ["walk", "siege", "storm", "retaken", "freed"]
const UNKNOWN := "a country"


static func is_war_kind(kind: String) -> bool:
	return WAR_KINDS.has(kind)


## True when `viewer` is a party to the entry: its actor (tag), a named other (others) or, for a war or a peace, its target.
## LogLines' filter Mine and its line's `mine` both use this.
static func mine(entry: Dictionary, viewer: StringName) -> bool:
	if StringName(str(entry.get("tag", ""))) == viewer:
		return true
	var target := StringName(str(entry.get("target", "")))
	if viewer != &"" and target == viewer:
		return true
	return viewer != &"" and _has(entry.get("others", []), viewer)


## False for an entry the line cannot be built from (a missing hex, party, term or reason). filters_of asks this, and it
## agrees with line(): an entry gives a line exactly when this is true (and the viewer is told of it).
static func describable(entry: Dictionary, viewer: StringName, mine_now: bool) -> bool:
	var tag := StringName(str(entry.get("tag", "")))
	var hex_ok: bool = entry.get("hex", null) is Vector2i
	match str(entry.get("kind", "")):
		"war_declared":
			return tag != &"" and StringName(str(entry.get("target", ""))) != &""
		"peace_made":
			return tag != &"" and StringName(str(entry.get("target", ""))) != &"" and TERMS.has(str(entry.get("terms", "")))
		"battle_ended":
			return hex_ok and tag != &"" and str(entry.get("defender", "")) != ""
		"siege_started":
			return hex_ok and tag != &""
		"siege_lifted":
			return hex_ok and tag != &"" and (not mine_now or LIFT_WHYS.has(str(entry.get("why", ""))))
		"district_captured":
			return hex_ok and BY_WORDS.has(str(entry.get("by", ""))) and (tag != &"" or not _tags_of(entry.get("others", [])).is_empty())
	return false


## The line of a war entry for `viewer`: {keyword, tone, text, hex, notify, floating, record}, or {} when describable() is
## false. `mine_now` is mine(entry, viewer). The hex is the viewer's capital for a war or a peace (their ribbon and Go).
static func line(game: Game, entry: Dictionary, viewer: StringName, mine_now: bool) -> Dictionary:
	if not describable(entry, viewer, mine_now):
		return {}
	match str(entry.get("kind", "")):
		"war_declared":
			return _war_declared(game, entry, viewer, mine_now)
		"peace_made":
			return _peace(game, entry, viewer, mine_now)
		"battle_ended":
			return _battle(game, entry, viewer, mine_now)
		"siege_started":
			return _siege_started(game, entry, viewer, mine_now)
		"siege_lifted":
			return _siege_lifted(game, entry, viewer, mine_now)
	return _district(game, entry, viewer, mine_now)


# ----- wars and peaces: public (4.15) --------------------------------------------------------------------------------


static func _war_declared(game: Game, entry: Dictionary, viewer: StringName, mine_now: bool) -> Dictionary:
	var tag := StringName(str(entry.get("tag", "")))
	var target := StringName(str(entry.get("target", "")))
	if not mine_now:
		var among := "%s declared war on %s." % [_capital_the(game, tag), Words.country_the(game, target)]
		return _line("War", "muted", among, _capital(game, tag), false, "")
	if tag == viewer:
		return _line("War", "bad", "You declared war on %s." % Words.country_the(game, target), _capital(game, tag),
			false, "War!")
	return _line("War", "bad", "%s declared war on you!" % _capital_the(game, tag), _capital(game, target),
		true, "War!")


static func _peace(game: Game, entry: Dictionary, viewer: StringName, mine_now: bool) -> Dictionary:
	var tag := StringName(str(entry.get("tag", "")))
	var target := StringName(str(entry.get("target", "")))
	var terms := str(entry.get("terms", ""))
	if not mine_now:
		var among := "Peace between %s and %s." % [Words.country_the(game, tag), Words.country_the(game, target)]
		return _line("Peace", "muted", among, _capital(game, tag), false, "")
	var other := target if tag == viewer else tag
	var what := ""
	match terms:
		"white":
			what = "a white peace"
		"timer":
			what = _timer_text(game, entry)
		_:
			# take: the actor takes the land; yield: the actor gives it to the other side
			var takes := (tag if terms == "take" else target) == viewer
			var districts := Words.plural(_count(entry.get("moved", [])), "district", "districts")
			what = ("you took %s" % districts) if takes else ("you gave up %s" % districts)
	var text := "Peace with %s: %s." % [Words.country_the(game, other), what]
	return _line("Peace", "plain", text, _capital(game, viewer), true, "Peace")


## "the war ended after 40 seasons": the seasons between the war's declaration and this peace, read from the chronicle's
## war_declared entry of the same war (the number is the entry's own history, so a load gives the same words). A war whose
## declaration the chronicle no longer holds ends "by the timer".
static func _timer_text(game: Game, entry: Dictionary) -> String:
	var seasons := _seasons_of_war(game, int(entry.get("war", -1)), int(entry.get("turn", 0)))
	if seasons < 1:
		return "the war ended by the timer"
	return "the war ended after %s" % Words.seasons(seasons)


static func _seasons_of_war(game: Game, war: int, turn: int) -> int:
	var all := game.chronicle.entries
	var i := all.size() - 1
	while i >= 0:
		var found: Dictionary = all[i]
		if str(found.get("kind", "")) == "war_declared" and int(found.get("war", -2)) == war:
			return turn - int(found.get("turn", turn))
		i -= 1
	return -1


# ----- battles: exact to a side, a witnessed other's by what the viewer knows (4.15) --------------------------------


static func _battle(game: Game, entry: Dictionary, viewer: StringName, mine_now: bool) -> Dictionary:
	var attacker := StringName(str(entry.get("tag", "")))
	var defender := StringName(str(entry.get("defender", "")))
	var winner := StringName(str(entry.get("winner", "")))
	var loser := StringName(str(entry.get("loser", "")))
	var hex := entry["hex"] as Vector2i
	var record := int(entry.get("record", -1))
	# The producer names the battle in full ("Battle of Alessandria, 1480", Battles.name_for): the name is used as it is.
	var head := str(entry.get("name", ""))
	if head == "":
		head = "Battle at (%d, %d), %d" % [hex.x, hex.y, int(entry.get("year", 0))]
	var peace_end := str(entry.get("how", "")) == "peace"
	if not mine_now:
		var body := ""
		if peace_end:
			body = "the fight ended with the peace"
		elif winner != &"" and loser != &"":
			body = "%s beat %s" % [_short(game, viewer, winner), _short(game, viewer, loser)]
		else:
			body = "%s and %s fought to a draw" % [_short(game, viewer, attacker), _short(game, viewer, defender)]
		return _battle_line(head + ": " + body + ".", "muted", hex, false, "Battle", record)
	if peace_end:
		return _battle_line(head + ": the fight ended with the peace.", "plain", hex, false, "", record)
	var opponent := defender if attacker == viewer else attacker
	var days := Words.plural(int(entry.get("days", 0)), "day", "days")
	var outcome := "no side won in %s" % days
	var tone := "plain"
	var floating := ""
	if winner == viewer:
		outcome = "you won in %s" % days
		tone = "good"
		floating = "Victory!"
	elif loser == viewer:
		outcome = "you lost in %s" % days
		tone = "bad"
		floating = "Defeat!"
	var lost := "You lost %s" % Words.men(_pair(entry, "killed", viewer))
	var wounded := _pair(entry, "wounded", viewer)
	if wounded > 0:
		lost += " (%s wounded)" % Words.number(wounded)
	var theirs := "%s %s" % [_real(game, opponent), Words.number(_pair(entry, "killed", opponent))]
	var text := "%s: %s. %s, %s%s." % [head, outcome, lost, theirs, _flight(entry, viewer, loser)]
	return _battle_line(text, tone, hex, true, floating, record)


## "; they fled to (8, 8)" for the beaten side's retreat (you, when the viewer is the one beaten); "" with none.
static func _flight(entry: Dictionary, viewer: StringName, loser: StringName) -> String:
	var retreat: Variant = entry.get("retreat", Army.NO_HEX)
	if not (retreat is Vector2i) or (retreat as Vector2i) == Army.NO_HEX or loser == &"":
		return ""
	var spot := retreat as Vector2i
	var who := "you" if loser == viewer else "they"
	return "; %s fled to (%d, %d)" % [who, spot.x, spot.y]


static func _battle_line(text: String, tone: String, hex: Vector2i, notify: bool, floating: String, record: int) -> Dictionary:
	var line := _line("Battle", tone, text, hex, notify, floating)
	line["record"] = record
	return line


# ----- sieges -------------------------------------------------------------------------------------------------------


static func _siege_started(game: Game, entry: Dictionary, viewer: StringName, mine_now: bool) -> Dictionary:
	var tag := StringName(str(entry.get("tag", "")))
	var hex := entry["hex"] as Vector2i
	var named := _named(entry, hex)
	if not mine_now:
		return _line("Siege", "muted", "%s besieges %s." % [LogLines.capital(_short(game, viewer, tag)), named], hex, false, "")
	if tag == viewer:
		var needs := Words.number(int(entry.get("need", 0)))
		return _line("Siege", "warn", "You besiege %s: it needs %s." % [named, needs], hex, true, "Siege")
	return _line("Siege", "warn", "%s besieges your %s." % [LogLines.capital(LogLines.short_name(game, tag)), named],
		hex, true, "Siege")


static func _siege_lifted(game: Game, entry: Dictionary, viewer: StringName, mine_now: bool) -> Dictionary:
	var tag := StringName(str(entry.get("tag", "")))
	var hex := entry["hex"] as Vector2i
	var named := _named(entry, hex)
	if not mine_now:
		return _line("Lifted", "muted", "The siege of %s is lifted." % named, hex, false, "")
	if tag == viewer:
		var reason := _lift_reason(str(entry.get("why", "")))
		return _line("Lifted", "warn", "The siege of %s is lifted: %s." % [named, reason], hex, true, "Lifted")
	return _line("Lifted", "good", "The siege of your %s is lifted." % named, hex, true, "Lifted")


static func _lift_reason(why: String) -> String:
	match why:
		"left":
			return "your army left"
		"relief":
			return "a relief army beat yours"
		"outnumbered":
			return "your army is too small for its garrison"
	return "peace was made"


# ----- districts ----------------------------------------------------------------------------------------------------


static func _district(game: Game, entry: Dictionary, viewer: StringName, mine_now: bool) -> Dictionary:
	var tag := StringName(str(entry.get("tag", "")))
	var hex := entry["hex"] as Vector2i
	var by := str(entry.get("by", ""))
	var others := _tags_of(entry.get("others", []))
	var old := others[0] if not others.is_empty() else &""
	var gained := tag == viewer
	var lost := not gained and others.has(viewer)
	var place := Words.place(game, hex)
	if by == "siege" and str(entry.get("name", "")) != "":
		place = _named(entry, hex)
	if by == "siege":
		return _fall(game, entry, viewer, mine_now, place, gained)
	if not mine_now:
		var verb := "took back" if by == "retaken" or by == "freed" else "took"
		return _line("Taken", "muted", "%s %s %s." % [LogLines.capital(_short(game, viewer, tag)), verb, place], hex, false, "")
	if gained:
		return _gained(game, entry, viewer, by, place, old)
	if lost:
		var to := "Lost: %s to %s." % [place, _real(game, tag)]
		return _line("Lost", "bad", to, hex, true, "Lost")
	return {}


## A fortress falls to a siege: the land it held lies open (its opened districts, when there are any).
static func _fall(game: Game, entry: Dictionary, viewer: StringName, mine_now: bool, place: String, gained: bool) -> Dictionary:
	var hex := entry["hex"] as Vector2i
	var fell := "%s has fallen after %s" % [place, Words.seasons(int(entry.get("seasons", 0)))]
	if not mine_now:
		return _line("Fallen", "muted", fell + ".", hex, false, "")
	var opened := _count(entry.get("opened", []))
	var clause := ""
	if opened > 0:
		clause = ": its land lies open (%s)" % Words.plural(opened, "district", "districts")
	return _line("Fallen", "good" if gained else "bad", fell + clause + ".", hex, true, "Taken" if gained else "Lost")


static func _gained(game: Game, entry: Dictionary, viewer: StringName, by: String, place: String, old: StringName) -> Dictionary:
	var hex := entry["hex"] as Vector2i
	var text := ""
	match by:
		"retaken":
			text = "Retaken: %s." % place
		"freed":
			var owner := StringName(str(entry.get("owner", "")))
			if owner == &"":
				owner = StringName(str(entry.get("tag", "")))
			text = "Freed: %s went back to %s." % [place, _real(game, owner)]
		_:
			var from := (" from %s" % _real(game, old)) if old != &"" else ""
			text = "Taken: %s%s." % [place, from]
	return _line("Taken", "good", text, hex, true, "Taken")


# ----- shared helpers -----------------------------------------------------------------------------------------------


static func _line(keyword: String, tone: String, text: String, hex: Vector2i, notify: bool, floating: String) -> Dictionary:
	return {"keyword": keyword, "tone": tone, "text": text, "hex": hex, "notify": notify, "floating": floating, "record": -1}


## A country's real name ("the Duchy of Milan") in a line about the player's own affairs: a country at war with the player
## is named even when the viewer does not know it (it declared war by name, 4.15). Others' affairs use _the.
static func _real(game: Game, tag: StringName) -> String:
	return Words.country_the(game, tag) if tag != &"" else UNKNOWN


## The short name ("Milan") of a country the viewer knows, else "a country".
static func _short(game: Game, viewer: StringName, tag: StringName) -> String:
	if tag == &"" or not Knowledge.knows(game, viewer, tag):
		return UNKNOWN
	return LogLines.short_name(game, tag)


## "The Duchy of Milan", as a public name at the start of a sentence.
static func _capital_the(game: Game, tag: StringName) -> String:
	return LogLines.capital(Words.country_the(game, tag))


static func _capital(game: Game, tag: StringName) -> Vector2i:
	var c := Countries.by_tag(game, tag)
	return c.capital if c != null else WorksView.NO_HEX


## "Pavia (10, 9)" for a named fortress; the coordinates alone when the entry names none.
static func _named(entry: Dictionary, hex: Vector2i) -> String:
	var coords := "(%d, %d)" % [hex.x, hex.y]
	var named := str(entry.get("name", ""))
	return "%s %s" % [named, coords] if named != "" else coords


static func _pair(entry: Dictionary, key: String, tag: StringName) -> int:
	var value: Variant = entry.get(key, null)
	if value is Dictionary:
		return int((value as Dictionary).get(String(tag), 0))
	return 0


static func _count(value: Variant) -> int:
	if value is Array:
		return (value as Array).size()
	if value is PackedVector2Array:
		return (value as PackedVector2Array).size()
	return 0


## True when `value` (an Array or the PackedStringArray the chronicle stores) holds `tag`.
static func _has(value: Variant, tag: StringName) -> bool:
	if typeof(value) != TYPE_ARRAY and typeof(value) != TYPE_PACKED_STRING_ARRAY:
		return false
	for item: Variant in value:
		if str(item) == String(tag):
			return true
	return false


static func _tags_of(value: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if typeof(value) != TYPE_ARRAY and typeof(value) != TYPE_PACKED_STRING_ARRAY:
		return out
	for item: Variant in value:
		out.append(StringName(str(item)))
	return out
