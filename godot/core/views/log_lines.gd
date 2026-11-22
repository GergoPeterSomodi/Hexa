## The action log's lines, built from the chronicle (docs/architecture/m3-build-spec.md 4.4, 5.6, 6.5, D43): the sentence,
## keyword chip, tone and floating word of each notable event for one viewer. A line is the same live and after a load,
## because it is built from the saved chronicle entry alone. Pure core/views/ code: reads the game, writes nothing.
class_name LogLines
extends RefCounted

const FILTERS: Array[Dictionary] = [{id = &"all", since = "3"}, {id = &"works", since = "3"}, {id = &"mine", since = "3"},
	{id = &"money", since = "4"}, {id = &"war", since = "7"}]
## The memo slot of the set of tags the viewer knows.
const _KNOWN := &"*known"
## The kinds the War filter shows: the six war kinds (4.14) and M6's army kinds (they join War too).
const WAR_LINE_KINDS: Array[String] = ["war_declared", "peace_made", "battle_ended", "siege_started", "siege_lifted",
	"district_captured", "army_raised", "army_disbanded", "march_halted", "army_starved", "unit_lost"]
const SEASONS_SHOWN := 8
const PER_SEASON := 60


## {} when `viewer` is not told of the entry (Knowledge.witnessed) or it cannot be described; else {text, keyword, tone
## (good, plain, bad, muted), hex, mine, filters: Array[StringName], notify, floating, turn}. `memo` lets a caller that
## reads many entries share the answers of "does the viewer know this actor" (the key is the entry's parties).
static func line_of(game: Game, entry: Dictionary, viewer: StringName, memo: Dictionary = {}) -> Dictionary:
	if game == null or not _seen(game, entry, viewer, memo):
		return {}
	var tag := StringName(str(entry.get("tag", "")))
	var others := _tags(entry.get("others", []))
	var mine := tag == viewer
	var line: Dictionary
	match str(entry.get("kind", "")):
		"work_started", "work_finished", "work_cancelled":
			line = _work_line(game, entry, mine)
		"owners_changed":
			mine = mine or others.has(viewer)
			line = _land_line(game, entry, viewer, tag, others)
		"country_chosen":
			line = _rule_line(game, entry, mine)
		"goods_short":
			line = _short_line(game, entry, mine)
		"tax_set":
			line = _tax_line(game, entry, mine)
		"town_grew", "district_declined":
			line = _settle_line(game, entry, mine)
		"army_raised":
			line = _raised_line(game, entry, viewer, mine)
		"army_disbanded":
			line = _disbanded_line(game, entry, viewer, mine)
		"march_halted":
			line = _halted_line(game, entry, mine)
		"army_starved":
			line = _starved_line(game, entry, viewer, mine)
		"unit_lost":
			line = _lost_line(game, entry, viewer, mine)
		"war_declared", "peace_made", "battle_ended", "siege_started", "siege_lifted", "district_captured":
			mine = LogLinesWar.mine(entry, viewer)
			line = LogLinesWar.line(game, entry, viewer, mine)
		_:
			return {}
	if line.is_empty():
		return {}
	if not line.has("record"):
		line["record"] = -1  # the battle record of a battle_ended line (LogLinesWar); -1 elsewhere
	line["mine"] = mine
	line["turn"] = int(entry.get("turn", 0))
	line["filters"] = filters_of(game, entry, viewer, memo)
	return line


## The lines of the newest SEASONS_SHOWN seasons that have any, as [{turn, title ("Spring 1480"), lines}], newest season
## first, each season's lines newest first, at most PER_SEASON a season. Unknown filters (war: a later milestone)
## give no seasons. Cached in game.view_cache by [&"log", version, turn, viewer, filter].
static func entries(game: Game, viewer: StringName, filter: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null:
		return out
	var key: Array = [&"log", game.version, game.turn, viewer, filter, game.chronicle.entries.size()]
	var cached: Variant = game.view_cache.get_or_make(key, func() -> Array[Dictionary]: return _build(game, viewer, filter))
	out.assign((cached as Array).duplicate(true))  # the cache is shared: a caller gets its own copy
	return out


static func _build(game: Game, viewer: StringName, filter: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _filter_ids().has(filter):
		return out
	var memo := {}
	var all := game.chronicle.entries
	var current: Dictionary = {}
	var i := all.size() - 1
	while i >= 0:
		var entry: Dictionary = all[i]
		i -= 1
		if not _may_pass(entry, viewer, filter):
			continue
		var turn := int(entry.get("turn", 0))
		if current.is_empty() or int(current["turn"]) != turn:
			if out.size() >= SEASONS_SHOWN:
				break
			current = {}
		if not current.is_empty() and int(current["turn"]) == turn and (current["lines"] as Array).size() >= PER_SEASON:
			continue  # the season is full: its older entries are never read
		var line := line_of(game, entry, viewer, memo)
		if line.is_empty() or not (line["filters"] as Array).has(filter):
			continue
		if current.is_empty():
			current = {"turn": turn, "title": Calendar.date_text(turn, game.start_year), "lines": [] as Array[Dictionary]}
			out.append(current)
		var lines: Array[Dictionary] = current["lines"]
		if lines.size() < PER_SEASON:
			lines.append(line)
	return out


static func _filter_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for f: Dictionary in FILTERS:
		ids.append(f["id"] as StringName)
	return ids


## A cheap test before the line is built: a filter that is sure to drop the entry skips the work.
static func _may_pass(entry: Dictionary, viewer: StringName, filter: StringName) -> bool:
	match filter:
		&"works":
			return str(entry.get("kind", "")).begins_with("work_")
		&"money":
			return _money_kind(str(entry.get("kind", "")))
		&"mine":
			return LogLinesWar.mine(entry, viewer)
		&"war":
			return WAR_LINE_KINDS.has(str(entry.get("kind", "")))
	return true


## The filters `line_of` gives the entry, without building its sentence: [] when `viewer` is not told of it (Knowledge.
## witnessed) or it cannot be described (the cases in which `line_of` gives {}). `line_of` calls this. `memo` is
## `line_of`'s: a caller that reads many entries shares the answers of "does the viewer know this actor".
static func filters_of(game: Game, entry: Dictionary, viewer: StringName, memo: Dictionary = {}) -> Array[StringName]:
	var none: Array[StringName] = []
	if game == null or not _seen(game, entry, viewer, memo):
		return none
	if not LogLinesWar.is_war_kind(str(entry.get("kind", ""))) and not _describable(entry, viewer):
		return none
	var kind := str(entry.get("kind", ""))
	var mine := StringName(str(entry.get("tag", ""))) == viewer
	if kind == "owners_changed":
		mine = mine or _tags(entry.get("others", [])).has(viewer)
	elif LogLinesWar.is_war_kind(kind):
		mine = LogLinesWar.mine(entry, viewer)
		if not LogLinesWar.describable(entry, viewer, mine):
			return none
		return _filters_of(entry, mine)
	return _filters_of(entry, mine)


## False for an entry `line_of` gives no line: an unknown kind, a work that does not read back, land with no hexes or that
## nobody gave and nobody got, a rule choice with no country, a shortage of another country, a tax level out of range.
static func _describable(entry: Dictionary, viewer: StringName) -> bool:
	var tag := StringName(str(entry.get("tag", "")))
	match str(entry.get("kind", "")):
		"work_started", "work_finished", "work_cancelled":
			var work_value: Variant = entry.get("work", null)
			return work_value is Dictionary and _reads_as_work(work_value as Dictionary)
		"owners_changed":
			return not _hexes(entry.get("hexes", [])).is_empty() and not (tag == &"" and _tags(entry.get("others", [])).is_empty())
		"country_chosen":
			return tag != &""
		"goods_short":
			return tag == viewer  # only the owner is told
		"tax_set":
			return not Words.tax_name(int(entry.get("level", -1))).is_empty()
		"town_grew", "district_declined":
			if tag == &"" or not (entry.get("hex", null) is Vector2i) or _settle_words(entry) == "":
				return false
			# _settle_line: the player's own fall needs a reason the log knows
			return tag != viewer or str(entry.get("kind", "")) == "town_grew" or 				["hunger", "people"].has(str(entry.get("why", "")))
		"army_raised", "army_disbanded":
			return entry.get("hex", null) is Vector2i
		"march_halted":
			return tag == viewer and entry.get("hex", null) is Vector2i and HALT_WHYS.has(str(entry.get("why", "")))
		"army_starved":
			return entry.get("hex", null) is Vector2i and STARVE_WHYS.has(str(entry.get("why", "")))
		"unit_lost":
			return entry.get("hex", null) is Vector2i and str(entry.get("why", "")) == "starved"
	return false


const _WORK_INTS: Array[String] = ["id", "family", "level_to", "started_turn", "seasons", "seasons_left", "paid"]


## Whether Work.from_dict reads `d` (a test pins the two equal): the same checks without building the Work, which an index of
## three thousand entries cannot afford.
static func _reads_as_work(d: Dictionary) -> bool:
	var schema := str(d.get("schema", ""))
	if schema != Work.SCHEMA and schema != Work.SCHEMA_V1:
		return false
	for key: String in _WORK_INTS:
		if Work.whole(d.get(key, null)) == null:
			return false
	var tag_value: Variant = d.get("tag", null)
	var action_value: Variant = d.get("action", null)
	if not (tag_value is String or tag_value is StringName) or not (action_value is String or action_value is StringName):
		return false
	if schema == Work.SCHEMA:
		var goods: Variant = d.get("paid_goods", null)
		if not (goods is Dictionary):
			return false
		for key: Variant in goods as Dictionary:
			var loads: Variant = Work.whole((goods as Dictionary)[key])
			if not (key is String or key is StringName) or loads == null or int(loads) < 0:
				return false
	if not Work.ACTIONS.has(String(action_value)):
		return false
	var hex_value: Variant = d.get("hex", null)
	if hex_value is Vector2i:
		return true
	if hex_value is Array and (hex_value as Array).size() == 2:
		return Work.whole((hex_value as Array)[0]) != null and Work.whole((hex_value as Array)[1]) != null
	return false


static func _filters_of(entry: Dictionary, mine: bool) -> Array[StringName]:
	var kind := str(entry.get("kind", ""))
	var out: Array[StringName] = [&"all"]
	if kind.begins_with("work_"):
		out.append(&"works")
	if mine:
		out.append(&"mine")
	if kind == "goods_short" or kind == "tax_set" or (mine and not _paid_text(entry).is_empty()):
		out.append(&"money")
	if WAR_LINE_KINDS.has(kind):
		out.append(&"war")
	return out


## The kinds that can carry the Money filter (a work does when its ducats moved: checked on the built line).
static func _money_kind(kind: String) -> bool:
	return kind == "goods_short" or kind == "tax_set" or kind.begins_with("work_") or kind == "army_raised" or kind == "army_disbanded"


# ----- who is told -----------------------------------------------------------------------------------------------


## Knowledge.witnessed (a test pins the two equal): the actor and each of `others` are told; a witness list tells exactly
## the tags it holds; else whoever knows the actor. "Knows" costs a pass over the map: `memo` keeps the tags the viewer
## knows (Knowledge.known, which `knows` agrees with) and asks it once.
static func _seen(game: Game, entry: Dictionary, viewer: StringName, memo: Dictionary) -> bool:
	if viewer == &"":
		return true
	var tag := StringName(str(entry.get("tag", "")))
	if tag == viewer or _lists(entry.get("others", []), viewer):
		return true
	var witnesses: Variant = entry.get("witnesses", [])
	if not _no_tags(witnesses):
		return _lists(witnesses, viewer)
	if tag == &"":
		return true  # Knowledge.knows: a public party
	if not memo.has(_KNOWN):
		var told := {}
		for other: StringName in Knowledge.known(game, viewer):  # one pass over the map, not one a tag
			told[other] = true
		memo[_KNOWN] = told
	return (memo[_KNOWN] as Dictionary).has(tag)


## True when `value` (an Array or the PackedStringArray the chronicle stores) holds `tag`; false for anything else.
static func _lists(value: Variant, tag: StringName) -> bool:
	if typeof(value) != TYPE_ARRAY and typeof(value) != TYPE_PACKED_STRING_ARRAY:
		return false
	for item: Variant in value:
		if str(item) == String(tag):
			return true
	return false


## True when `value` holds no tags: an empty Array or PackedStringArray, or anything that is no list (Knowledge reads it so).
static func _no_tags(value: Variant) -> bool:
	if value is Array:
		return (value as Array).is_empty()
	if value is PackedStringArray:
		return (value as PackedStringArray).is_empty()
	return true


static func _tags(value: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if typeof(value) != TYPE_ARRAY and typeof(value) != TYPE_PACKED_STRING_ARRAY:
		return out
	for item: Variant in value:
		out.append(StringName(str(item)))
	return out


# ----- works -----------------------------------------------------------------------------------------------------


static func _work_line(game: Game, entry: Dictionary, mine: bool) -> Dictionary:
	var work_value: Variant = entry.get("work", null)
	if not (work_value is Dictionary):
		return {}
	var work := Work.from_dict(work_value as Dictionary)
	if work == null:
		return {}
	var kind := str(entry.get("kind", ""))
	var turn := int(entry.get("turn", 0))
	var why := str(entry.get("why", ""))
	var line := {"hex": work.hex, "notify": false, "floating": ""}
	if mine:
		var place := WorksView.line(game, work)
		match kind:
			"work_started":
				line.merge({"keyword": "Begun", "tone": "plain",
					"floating": ("Begun %s" % Words.signed(-work.paid)) if work.paid > 0 else "Begun",
					"text": "Begun: %s. Ready %s.%s" % [place, ready_text(game, work, turn), _paid_text(entry)]}, true)
			"work_finished":
				line.merge({"keyword": "Finished", "tone": "good", "floating": "Finished", "notify": true,
					"text": "Finished: %s." % place}, true)
			_:
				line.merge({"keyword": "Cancelled", "tone": "bad", "floating": "Cancelled",
					"notify": why == "lost" or why == "blocked",
					"text": cancelled_text(place, why, str(entry.get("reason", ""))) + _paid_text(entry)}, true)
		return line
	var who := short_name(game, StringName(str(entry.get("tag", ""))))
	var at := "(%d, %d)" % [work.hex.x, work.hex.y]
	match kind:
		"work_started":
			line.merge({"keyword": "Begun", "tone": "muted",
				"text": "%s began work on %s at %s." % [who, noun_of(work), at]}, true)
		"work_finished":
			var cleared := work.action == Works.CLEAR
			var word := "Cleared" if cleared else "Built"
			line.merge({"keyword": word, "tone": "muted", "floating": word,
				"text": "%s %s %s at %s." % [who, "cleared" if cleared else "finished", noun_of(work), at]}, true)
		_:
			line.merge({"keyword": "Cancelled", "tone": "muted",
				"text": "%s cancelled work on %s at %s." % [who, noun_of(work), at]}, true)
	return line


## The money a work line adds when the viewer's own ducats moved: " (−40 ducats)" for a begun work that was paid,
## " (+40 ducats back)" for a cancelled one with a refund; "" otherwise.
static func _paid_text(entry: Dictionary) -> String:
	match str(entry.get("kind", "")):
		"work_started":
			var work_value: Variant = entry.get("work", null)
			var paid := int((work_value as Dictionary).get("paid", 0)) if work_value is Dictionary else 0
			if paid > 0:
				return " (%s)" % Words.signed_ducats(-paid)
		"work_cancelled":
			var refund := int(entry.get("refund", 0))
			if refund > 0:
				return " (+%s back)" % Words.ducats(refund)
		"army_raised":
			var ducats := int(entry.get("ducats", 0))
			if ducats > 0:
				return " (%s)" % Words.signed_ducats(-ducats)
		"army_disbanded":
			var back := int(entry.get("refund", 0))
			if back > 0:
				return " (+%s back)" % Words.ducats(back)
	return ""


## "Cancelled: <place>." (by order), "Cancelled: <place>, the land was lost." or "Cancelled: <place>: <reason>."
static func cancelled_text(place: String, why: String, reason: String) -> String:
	if why == "lost":
		return "Cancelled: %s, the land was lost." % place
	if why == "blocked":
		return "Cancelled: %s: %s." % [place, reason]
	return "Cancelled: %s." % place


## "Spring 1481": the season a work begun in season `turn` stands from, skipping halted seasons (as Works.ready_turn,
## which walks from the current turn; an old entry needs the walk from its own).
static func ready_text(game: Game, work: Work, turn: int) -> String:
	if Occupation.is_occupied(game, work.hex) or Occupation.besieged(game, work.hex):
		return "halted by war"
	var left := work.seasons
	var t := turn
	for n: int in Works.HORIZON:
		if not Works.halted(game, work, t):
			left -= 1
			if left <= 0:
				t += 1
				break
		t += 1
	return Calendar.date_text(t, game.start_year)


## "a vineyard", "a walled town", "an olive grove": the piece a work makes (or, for a clearing, takes off).
static func noun_of(work: Work) -> String:
	var piece := FamilyIds.NAMES[clampi(work.family, 0, FamilyIds.COUNT - 1)]
	var base := WorksView.piece_name(work.family)
	if HexCard.LEVEL_WORDS.has(piece) and work.action != Works.CLEAR:
		base = HexCard.level_label(piece, work.level_to)
	return Words.with_article(base)


## The short name of a country ("Milan"); its tag when it has none.
static func short_name(game: Game, tag: StringName) -> String:
	var def := Countries.def_of(game, tag)
	return def.name if def != null and not def.name.is_empty() else String(tag)


## The text with its first letter in capitals.
static func capital(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


# ----- money: shortages and taxes ---------------------------------------------------------------------------------


## "Your towns ran short of salt: 0 of 1." Only the owner is told: the event's witnesses are its actor alone, and any
## other viewer gets no line even from a hand-made entry.
static func _short_line(game: Game, entry: Dictionary, mine: bool) -> Dictionary:
	if not mine:
		return {}
	var tag := StringName(str(entry.get("tag", "")))
	var c := Countries.by_tag(game, tag)
	var hex: Vector2i = c.capital if c != null else WorksView.NO_HEX
	var text := "Your towns ran short of %s: %s of %s." % [str(entry.get("good", "")).to_lower(),
		Words.number(int(entry.get("taken", 0))), Words.number(int(entry.get("need", 0)))]
	return {"keyword": "Short", "tone": "bad", "hex": hex, "notify": true, "floating": "", "text": text}


## "You set taxes to High." or, for a known other, "Milan set taxes to High." (muted).
static func _tax_line(game: Game, entry: Dictionary, mine: bool) -> Dictionary:
	var tag := StringName(str(entry.get("tag", "")))
	var level := Words.tax_name(int(entry.get("level", -1)))
	if level.is_empty():
		return {}
	var c := Countries.by_tag(game, tag)
	var hex: Vector2i = c.capital if c != null else WorksView.NO_HEX
	if mine:
		return {"keyword": "Taxes", "tone": "plain", "hex": hex, "notify": false, "floating": "",
			"text": "You set taxes to %s." % level}
	return {"keyword": "Taxes", "tone": "muted", "hex": hex, "notify": false, "floating": "",
		"text": "%s set taxes to %s." % [short_name(game, tag), level]}


# ----- people: a settlement grows or falls --------------------------------------------------------------------------


## The words after the name: "grew into a town", "fell to a village: hunger" ("" for a level out of range or a fall for
## a reason the log does not know). A fall's reason is `why` (hunger, people).
static func _settle_words(entry: Dictionary) -> String:
	var words: Array = FamilyIds.LEVEL_WORDS["settlements"]
	var level := int(entry.get("level", 0))
	if level < 1 or level >= words.size():
		return ""
	var noun := Words.with_article(str(words[level]))
	if str(entry.get("kind", "")) == "town_grew":
		return "grew into %s" % noun
	return "fell to %s" % noun


## "Savona (6, 13) grew into a town." (mine) or "Savoy: the village near Turin (6, 11) grew into a town." (muted); a fall
## adds ": hunger." or ": too few people." for the player ("Milan: Cremona (12, 9) fell to a village." for another).
static func _settle_line(game: Game, entry: Dictionary, mine: bool) -> Dictionary:
	var words := _settle_words(entry)
	var at: Variant = entry.get("hex", null)
	if words == "" or not (at is Vector2i):
		return {}
	var grew := str(entry.get("kind", "")) == "town_grew"
	var level := int(entry.get("from", 0))  # the settlement as it stood: the level word of an unnamed one
	var name := Words.settlement(game, at as Vector2i, level if level > 0 else int(entry.get("level", 0)))
	var keyword := "Grew" if grew else "Declined"
	if mine:
		var why := ""
		if not grew:
			match str(entry.get("why", "")):
				"hunger":
					why = ": hunger"
				"people":
					why = ": too few people"
				_:
					return {}
		return {"keyword": keyword, "tone": "good" if grew else "bad", "hex": at, "notify": true, "floating": keyword,
			"text": "%s %s%s." % [name, words, why]}
	var who := short_name(game, StringName(str(entry.get("tag", ""))))
	return {"keyword": keyword, "tone": "muted", "hex": at, "notify": false, "floating": keyword,
		"text": "%s: %s %s." % [who, name, words]}


# ----- armies: raised, disbanded, halted, hungry, lost (m6-build-spec.md 4.11) ------------------------------------------

## The tag of a country the viewer knows, else &"" (Knowledge.knows; the viewer "" knows all). A foreign army line names
## only a known country: an unknown one reads "An army" or "A company", as ArmyView's tokens hide its army (4.12).
static func _told_tag(game: Game, viewer: StringName, tag: StringName) -> StringName:
	return tag if Knowledge.knows(game, viewer, tag) else &""


## The subject of a foreign army line: the short name of the entry's country when told, else "An army".
static func _told_name(game: Game, viewer: StringName, entry: Dictionary) -> String:
	var told := _told_tag(game, viewer, StringName(str(entry.get("tag", ""))))
	return short_name(game, told) if told != &"" else Words.army_of(game, &"")


## The reasons of march_halted and army_starved that a line says (Movement.WHY_*, Supply's why).
const HALT_WHYS: Array[String] = ["winter", "no_way", "blocked"]
const STARVE_WHYS: Array[String] = ["out_of_supply", "stores_empty"]


## "The Army of Turin" from the entry's `name` (producers that name their armies), else "Your army".
static func _the_army(entry: Dictionary) -> String:
	var army_name := str(entry.get("name", ""))
	return "The " + army_name if army_name != "" else "Your army"


## " of the Army of Turin" from the entry's `name`; "" when the entry names no army.
static func _of_the_army(entry: Dictionary) -> String:
	var army_name := str(entry.get("name", ""))
	return " of the " + army_name if army_name != "" else ""


## The kind of company the entry names (`kind_id`), or null.
static func _unit_def(game: Game, entry: Dictionary) -> UnitDef:
	if game == null or game.defs == null or not entry.has("kind_id"):
		return null
	return game.defs.unit_def(int(entry["kind_id"]))


## The number of items of a list the entry holds (its companies), 0 for anything that is no list.
static func _size_of(value: Variant) -> int:
	if value is Array:
		return (value as Array).size()
	if value is PackedInt32Array:
		return (value as PackedInt32Array).size()
	return 0


## A raise: the player's own line with its ducats; another's witnessed raise with the band of its men.
static func _raised_line(game: Game, entry: Dictionary, viewer: StringName, mine: bool) -> Dictionary:
	if not (entry.get("hex", null) is Vector2i):
		return {}
	var hex := entry["hex"] as Vector2i
	var count := int(entry.get("count", 0))
	if mine:
		return {"keyword": "Raised", "tone": "plain", "hex": hex, "notify": false, "floating": "Raised",
			"text": "You raised %s %s%s." % [Words.units(count, _unit_def(game, entry)), Words.at(game, hex),
				_paid_text(entry)]}
	var who := _told_name(game, viewer, entry)
	return {"keyword": "Raised", "tone": "warn", "hex": hex, "notify": true, "floating": "",
		"text": "%s raised %s %s: %s." % [who, Words.plural(count, "company", "companies"), Words.at(game, hex),
			Knowledge.band_text(int(entry.get("men", 0)), "men")]}


## A disband: the player's own line with its refund; another's witnessed one with the band of its men.
static func _disbanded_line(game: Game, entry: Dictionary, viewer: StringName, mine: bool) -> Dictionary:
	if not (entry.get("hex", null) is Vector2i):
		return {}
	var hex := entry["hex"] as Vector2i
	if mine:
		var companies := Words.units(_size_of(entry.get("units", [])), _unit_def(game, entry))
		return {"keyword": "Disbanded", "tone": "plain", "hex": hex, "notify": false, "floating": "",
			"text": "You disbanded %s%s%s." % [companies, _of_the_army(entry), _paid_text(entry)]}
	var who := _told_name(game, viewer, entry)
	return {"keyword": "Disbanded", "tone": "muted", "hex": hex, "notify": false, "floating": "",
		"text": "%s disbanded %s %s." % [who, Knowledge.band_text(int(entry.get("men", 0)), "men"),
			Words.at(game, hex)]}


## A halt: the player's own line only (the walk's witnesses are its country alone). A winter wait names the pass.
static func _halted_line(game: Game, entry: Dictionary, mine: bool) -> Dictionary:
	var why := str(entry.get("why", ""))
	if not mine or not (entry.get("hex", null) is Vector2i) or not HALT_WHYS.has(why):
		return {}
	var hex := entry["hex"] as Vector2i
	var reason := str(entry.get("reason", ""))
	var text := ""
	if why == "winter":
		var pass_text := "the %s is closed by snow" % reason if reason != "" else "winter closes the way"
		text = "%s waits for spring %s: %s." % [_the_army(entry), Words.at(game, hex), pass_text]
	elif why == "no_way":
		text = "%s halted %s: %s by land." % [_the_army(entry), Words.at(game, hex), reason]
	else:
		text = "%s halted %s: %s." % [_the_army(entry), Words.at(game, hex), reason]
	return {"keyword": "Halted", "tone": "warn", "hex": hex, "notify": true, "floating": "Halted", "text": text}


## Hunger: the player's own loss with its cause; another's witnessed loss without a number.
static func _starved_line(game: Game, entry: Dictionary, viewer: StringName, mine: bool) -> Dictionary:
	var why := str(entry.get("why", ""))
	if not (entry.get("hex", null) is Vector2i) or not STARVE_WHYS.has(why):
		return {}
	var hex := entry["hex"] as Vector2i
	if not mine:
		var army_tag := StringName(str(entry.get("tag", "")))
		return {"keyword": "Hunger", "tone": "muted", "hex": hex, "notify": false, "floating": "",
			"text": "%s lost men to hunger %s." % [Words.army_of(game, _told_tag(game, viewer, army_tag)), Words.at(game, hex)]}
	var lost := int(entry.get("lost", 0))
	var cause := "out of supply" if why == "out_of_supply" else "the stores are empty"
	return {"keyword": "Hunger", "tone": "bad", "hex": hex, "notify": true, "floating": "Hunger " + Words.signed(-lost),
		"text": "%s lost %s to hunger %s: %s." % [_the_army(entry), Words.men(lost), Words.at(game, hex), cause]}


## A company lost to hunger: the player's own, or another's witnessed one (muted, no number).
static func _lost_line(game: Game, entry: Dictionary, viewer: StringName, mine: bool) -> Dictionary:
	if not (entry.get("hex", null) is Vector2i) or str(entry.get("why", "")) != "starved":
		return {}
	var hex := entry["hex"] as Vector2i
	if not mine:
		var company_tag := StringName(str(entry.get("tag", "")))
		return {"keyword": "Lost", "tone": "muted", "hex": hex, "notify": false, "floating": "",
			"text": "%s starved %s." % [Words.company_of(game, _told_tag(game, viewer, company_tag)), Words.at(game, hex)]}
	var def := _unit_def(game, entry)
	var company := capital(Words.with_article(def.one)) if def != null else "A company"
	return {"keyword": "Lost", "tone": "bad", "hex": hex, "notify": true, "floating": "",
		"text": "%s%s is gone: starved %s." % [company, _of_the_army(entry), Words.at(game, hex)]}


# ----- land and rule ---------------------------------------------------------------------------------------------


static func _land_line(game: Game, entry: Dictionary, viewer: StringName, tag: StringName, others: Array[StringName]) -> Dictionary:
	var hexes := _hexes(entry.get("hexes", []))
	if hexes.is_empty():
		return {}
	var gained := tag == viewer and viewer != &""
	var lost := others.has(viewer) and viewer != &""
	var districts := Words.plural(hexes.size(), "district", "districts")
	var places := _places(game, hexes)
	if tag == &"" and others.is_empty():
		return {}  # land that nobody gave and nobody got: nothing to say
	var names: Array[String] = []
	for other: StringName in others:
		if Knowledge.knows(game, viewer, other):  # a victim the viewer does not know stays unnamed
			names.append(Words.country_the(game, other))
	if names.is_empty() and not others.is_empty():
		names.append("another country")
	var from := Words.list(names)
	var line := {"hex": hexes[0], "notify": gained or lost, "floating": ""}
	if gained:
		var text := "Took %s" % districts + ((" from %s" % from) if not names.is_empty() else "")
		line.merge({"keyword": "Gained", "tone": "good", "floating": "Gained", "text": "%s: %s." % [text, places]}, true)
	elif lost:
		var to := (" to %s" % Words.country_the(game, tag)) if tag != &"" else ""
		line.merge({"keyword": "Lost", "tone": "bad", "floating": "Lost", "text": "Lost %s%s: %s." % [districts, to, places]}, true)
	else:
		var text := ""
		if tag == &"":
			text = "%s lost %s" % [capital(from), districts]
		else:
			text = "%s took %s" % [capital(Words.country_the(game, tag)), districts]
			if not names.is_empty():
				text += " from %s" % from
		line.merge({"keyword": "Taken", "tone": "muted", "floating": "Taken", "text": "%s: %s." % [text, places]}, true)
	return line


static func _hexes(value: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for item: Variant in value as Array:
		if item is Vector2i:
			out.append(item as Vector2i)
	return out


## "Bergamo (11, 8) and 2 more": only the first is looked up.
static func _places(game: Game, hexes: Array[Vector2i]) -> String:
	var items: Array[String] = []
	for i: int in hexes.size():
		items.append(Words.place(game, hexes[i]) if i < 1 else "")
	return Words.list(items, 1)


static func _rule_line(game: Game, entry: Dictionary, mine: bool) -> Dictionary:
	var tag := StringName(str(entry.get("tag", "")))
	var c := Countries.by_tag(game, tag)
	var hex: Vector2i = c.capital if c != null else WorksView.NO_HEX
	var the := Words.country_the(game, tag)
	var text := "Took the rule of %s." % the if mine else "%s passed to a new ruler." % capital(the)
	if the == "":
		return {}
	return {"keyword": "Rule", "tone": "plain", "hex": hex, "notify": false, "floating": "", "text": text}
