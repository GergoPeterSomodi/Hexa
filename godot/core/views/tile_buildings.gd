## The Buildings tab's rows of one tile (tile window spec R9, R19, R20; build plan TW5): the built pieces, the work under way
## and the build, upgrade and clear options of ImprovePreview.options_of, grouped Settlement, Land, Harbour, Defence. Own land
## and the sandbox only: any other tile gets {} (R9). Light by default (the rows, states and hammers, no gains); `full` adds
## each row's year gain and payback from the works card (ImprovePreview.of, cached) and the summary's sums of the built
## rows. Every hammer is the verdict of the works check (Works.build_check and its kin), never a second rule.
## Pure core/views/ code: reads through ImprovePreview, WorksView, Improve, Works, Territory and Countries; writes only
## the game's view cache.
## While a work is under way on the hex, the other build, upgrade and clear rows are still listed (from the same option
## source, Improve.build_options and the piece on the hex) with a refused verdict "one job at a time: <the work> is under
## way": no rule or check is changed, only the listing. A built row's gain and upkeep are the negated clearing card's
## year.gain and lands.upkeep: an approximation of what the piece is worth a year (the tests pin that equality).
class_name TileBuildings
extends RefCounted

const GROUPS: Array[StringName] = [&"settlement", &"land", &"harbour", &"defence"]
const GROUP_NAMES := {&"settlement": "Settlement", &"land": "Land", &"harbour": "Harbour", &"defence": "Defence"}
## The states a row can take; the tab draws each one (R19).
const STATES: Array[StringName] = [&"built", &"building", &"ready", &"short", &"locked", &"refused"]


## {summary: {make, upkeep} (null until `full`), groups: Array[{id, name, slots ({}: no slots yet), rows}]}; {} off own land.
## Rows: {id, group, name, icon (a family name), option ({} for built or a work), state, state_text, tone (good, bad, plain,
## muted), progress (0..1, building only), gain (int or null), upkeep (int or null, a cost a year), cost {ducats, goods},
## build_seasons, payback ({} or {seasons (-1: never), text}), hammer (the verdict is ok), reason, gate ({} until M9.5/M11)}.
static func of(game: Game, tag: StringName, hex: Vector2i, full: bool = false) -> Dictionary:
	if game == null or game.defs == null or not _is_own(game, tag, hex):
		return {}
	var key: Array = [&"buildings", game.version, tag, hex, full]
	return game.view_cache.get_or_make(key, func() -> Dictionary: return _make(game, tag, hex, full)) as Dictionary


## The year gain of one option on `hex`: the works card's year.gain (the realm's measure); 0 when the card has no year.
static func gain(game: Game, tag: StringName, hex: Vector2i, option: Dictionary) -> int:
	var year: Dictionary = ImprovePreview.of(game, tag, hex, option).get("year", {})
	return int(year.get("gain", 0))


## The state of a row from its verdict and its refusal kind (pure): ok is ready; ducats or goods short; gate locked;
## slot or rule refused.
static func state_of(verdict: Dictionary, blocked: StringName) -> StringName:
	if bool(verdict.get("ok", false)):
		return &"ready"
	match blocked:
		&"ducats", &"goods":
			return &"short"
		&"gate":
			return &"locked"
	return &"refused"


## The refusal kind of a verdict, as the card's blocked_by: &"" ok, &"slot", &"ducats", &"goods" or &"rule".
static func blocked_by(verdict: Dictionary) -> StringName:
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


## The gate of an option: {} when none holds. A placeholder until M9.5 (slots) and M11 (techs and years) fill it:
## {year: 1495} opens in a year, {tech: "Guilds"} needs a tech.
static func gate_of(_game: Game, _tag: StringName, _option: Dictionary) -> Dictionary:
	return {}


## The locked row's words: "opens in 1495", "needs Guilds"; "" for no gate.
static func gate_text(gate: Dictionary) -> String:
	if gate.has("year"):
		return "opens in %d" % int(gate["year"])
	if gate.has("tech"):
		return "needs %s" % str(gate["tech"])
	return ""


# --- the rows ------------------------------------------------------------------------------------------------------


static func _is_own(game: Game, tag: StringName, hex: Vector2i) -> bool:
	if game.map == null or not game.map.has(hex):
		return false
	if not game.has_countries():
		return true
	return tag != &"" and Territory.owner_tag(game, hex) == tag


static func _make(game: Game, tag: StringName, hex: Vector2i, full: bool) -> Dictionary:
	var rows: Array[Dictionary] = []
	var piece := Improve.piece_at(game, hex)
	if not piece.is_empty():
		rows.append(_built_row(game, tag, hex, piece, full))
	var work := WorksView.at(game, hex, tag)
	if not work.is_empty():
		rows.append(_work_row(work))
	var offers: Array[Dictionary] = _busy_offers(game, hex, work) if not work.is_empty() else ImprovePreview.options_of(game, tag, hex)
	for offer: Dictionary in offers:
		rows.append(_option_row(game, tag, hex, offer, full))
	return {"summary": _summary(rows, full), "groups": _groups(rows)}


## A built piece: working, its upkeep and its gain from the clearing card (what the realm loses without it).
static func _built_row(game: Game, tag: StringName, hex: Vector2i, piece: Dictionary, full: bool) -> Dictionary:
	var family := int(piece["family_id"])
	var level := int(piece["level"])
	var gain: Variant = null
	var upkeep: Variant = null
	var state_text := "working"
	if full:
		var card := ImprovePreview.of(game, tag, hex, {"action": Works.CLEAR, "family": family})
		gain = _card_gain(card, -1)
		upkeep = _card_upkeep(card, -1)
		if upkeep != null:
			state_text = "working · upkeep %d" % int(upkeep)
	return {
		"id": "built:%d" % family, "group": _group_of(family), "name": _built_name(family, level),
		"icon": FamilyIds.NAMES[family], "option": {}, "state": &"built", "state_text": state_text, "tone": &"good",
		"progress": 0.0, "gain": gain, "upkeep": upkeep, "cost": {"ducats": 0, "goods": {}}, "build_seasons": 0,
		"payback": {}, "hammer": false, "reason": "", "gate": {},
	}


## The work under way: building, with its progress ("1 of 4 seasons" read from WorksView) and its family (WorksView.at
## gives it; a fresh build has its own family, not the piece's). family 0 falls to Land.
static func _work_row(work: Dictionary) -> Dictionary:
	var family := int(work.get("family", 0))
	var parts := str(work["progress"]).split(" ")
	var done := int(parts[0]) if parts.size() >= 3 else 0
	var total := maxi(int(parts[2]) if parts.size() >= 3 else 1, 1)
	return {
		"id": "work", "group": _group_of(family), "name": _capital(str(work["label"])),
		"icon": FamilyIds.NAMES[family] if family > 0 else "", "option": {}, "state": &"building",
		"state_text": "building · %s" % str(work["progress"]), "tone": &"plain",
		"progress": clampf(float(done) / float(total), 0.0, 1.0), "gain": null, "upkeep": null,
		"cost": {"ducats": 0, "goods": {}}, "build_seasons": total, "payback": {}, "hammer": false,
		"reason": "", "gate": {},
	}


## A build, upgrade or clear option: its verdict (the hammer is its ok), its state and its words, and with `full` its card.
static func _option_row(game: Game, tag: StringName, hex: Vector2i, offer: Dictionary, full: bool) -> Dictionary:
	var action := StringName(str(offer["action"]))
	var family := int(offer["family"])
	var option := {"action": action, "family": family}
	var verdict: Dictionary = offer["verdict"]
	var level_to := _level_to(game, hex, action)
	var cost := Works.cost_of(game, action, family, level_to)
	var gate := gate_of(game, tag, option)
	var blocked := &"gate" if not gate.is_empty() else blocked_by(verdict)
	var state := state_of(verdict, blocked)
	var card: Dictionary = ImprovePreview.of(game, tag, hex, option) if full else {}
	var upkeep: Variant = _card_upkeep(card, 1)
	var words := ""
	var tone: StringName = &"plain"
	match state:
		&"ready":
			words = "cost %s" % _cost_words(cost, upkeep)
		&"short":
			words = _short_words(game, tag, cost, blocked, ImprovePreview.reason_words(game, hex, option, verdict))
			tone = &"bad"
		&"locked":
			words = gate_text(gate)
			tone = &"muted"
		_:
			words = str(verdict.get("reason", "")) if bool(offer.get("busy", false)) else ImprovePreview.reason_words(game, hex, option, verdict)
			tone = &"bad"
	var payback: Dictionary = {}
	var card_payback: Dictionary = card.get("payback", {})
	if not card_payback.is_empty():
		payback = {"seasons": int(card_payback["seasons"]), "text": str(card_payback["text"])}
	return {
		"id": "%s:%d" % [action, family], "group": _group_of(family), "name": str(offer["label"]),
		"icon": FamilyIds.NAMES[family], "option": option, "state": state, "state_text": words, "tone": tone,
		"progress": 0.0, "gain": _card_gain(card, 1), "upkeep": upkeep,
		"cost": {"ducats": int(cost["ducats"]), "goods": cost["goods"]},
		"build_seasons": Works.seasons_for(game, action, family, level_to), "payback": payback,
		"hammer": bool(verdict.get("ok", false)), "reason": words if state != &"ready" and state != &"locked" else "",
		"gate": gate,
	}


# --- the busy listing --------------------------------------------------------------------------------------------

## The offers of a hex with a work under way: the same sources as options_of (the wild hex's build options, or the piece's
## upgrade and clear), each with a refused verdict "one job at a time: <the work> is under way". Listing only: the rules and
## the checks are not asked.
static func _busy_offers(game: Game, hex: Vector2i, work: Dictionary) -> Array[Dictionary]:
	var why := "one job at a time: %s is under way" % str(work["label"])
	var out: Array[Dictionary] = []
	var piece := Improve.piece_at(game, hex)
	if piece.is_empty():
		for option: Dictionary in Improve.build_options(game, hex):
			var f := int(option["family_id"])
			out.append(_offer(Works.BUILD, f, "Build %s" % WorksView.piece_name(f), why))
		return out
	var use := int(piece["family_id"])
	var level := int(piece["level"])
	if level < FamilyIds.TOP_LEVEL[use]:
		out.append(_offer(Works.UPGRADE, use, "Upgrade to %s" % HexCard.level_label(FamilyIds.NAMES[use], level + 1), why))
	out.append(_offer(Works.CLEAR, use, "Clear %s" % WorksView.piece_name(use), why))
	return out


static func _offer(action: StringName, family: int, label: String, why: String) -> Dictionary:
	return {"action": action, "family": family, "label": label, "verdict": {"ok": false, "reason": why}, "busy": true}


# --- words, sums, groups ----------------------------------------------------------------------------------------------


## "120", "120 · 10 loads of timber", "free"; with the upkeep "· upkeep 8" is added by the caller.
static func _cost_words(cost: Dictionary, upkeep: Variant) -> String:
	var parts := PackedStringArray()
	if int(cost["ducats"]) > 0:
		parts.append(Words.number(int(cost["ducats"])))
	var goods: Dictionary = cost["goods"]
	for key: Variant in goods:
		parts.append(Words.loads(int(goods[key]), str(key)))
	var text := " · ".join(parts) if not parts.is_empty() else "free"
	if upkeep != null:
		text += " · upkeep %d" % int(upkeep)
	return text


## "cost 300 · you have 204" for a ducat shortfall; the reason's own words for goods.
static func _short_words(game: Game, tag: StringName, cost: Dictionary, blocked: StringName, reason: String) -> String:
	if blocked != &"ducats":
		return reason
	var c := Countries.by_tag(game, tag)
	var have := c.treasury if c != null else 0
	return "cost %s · you have %s" % [Words.number(int(cost["ducats"])), Words.number(have)]


static func _level_to(game: Game, hex: Vector2i, action: StringName) -> int:
	if action == Works.BUILD:
		return 1
	if action == Works.UPGRADE:
		return int(Improve.piece_at(game, hex).get("level", 0)) + 1
	return 0


## The built piece's own summary: the sum of the built rows' gains and upkeep (null until `full`).
static func _summary(rows: Array[Dictionary], full: bool) -> Dictionary:
	var make: Variant = null
	var upkeep: Variant = null
	if full:
		var m := 0
		var u := 0
		for row: Dictionary in rows:
			if row["state"] != &"built":
				continue
			if row["gain"] != null:
				m += int(row["gain"])
			if row["upkeep"] != null:
				u += int(row["upkeep"])
		make = m
		upkeep = u
	return {"make": make, "upkeep": upkeep}


static func _groups(rows: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in GROUPS:
		var mine: Array[Dictionary] = []
		for row: Dictionary in rows:
			if row["group"] == id:
				mine.append(row)
		if not mine.is_empty():
			out.append({"id": id, "name": GROUP_NAMES[id], "slots": {}, "rows": mine})
	return out


static func _group_of(family: int) -> StringName:
	if family == ImproveRules.SETTLEMENT:
		return &"settlement"
	if family == ImproveRules.CASTLE:
		return &"defence"
	if family == ImproveRules.HARBOUR:
		return &"harbour"
	return &"land"


## The card's gain (sign 1) or its negation (sign -1); null when the card has no year (a rule refusal, or no countries).
static func _card_gain(card: Dictionary, sign: int) -> Variant:
	var year: Dictionary = card.get("year", {})
	if year.is_empty():
		return null
	return sign * int(year["gain"])


## The card's upkeep change on the hex (sign 1), or its negation; null when the card has no lands.
static func _card_upkeep(card: Dictionary, sign: int) -> Variant:
	var lands: Dictionary = card.get("lands", {})
	if lands.is_empty():
		return null
	return sign * int(lands["upkeep"])


## "Settlement" words for a settlement or castle or harbour ("walled town"); "Vineyard, first stage" for the rest.
static func _built_name(family: int, level: int) -> String:
	var name := FamilyIds.NAMES[family]
	var words := HexCard.level_label(name, level)
	if HexCard.LEVEL_WORDS.has(name):
		return _capital(words)
	return "%s, %s" % [_capital(WorksView.piece_name(family)), words]


static func _capital(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)
