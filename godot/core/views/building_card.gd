## The hover card of a Buildings row (docs/architecture/tilewin-build-spec.md R25, TW7): what a building would do each year,
## what it costs to build, and the verdict line. A built piece (option {}) gets what it makes and its upkeep, and no cost. Only
## the viewer's own land: {} for a hex that is not the tag's (R9); the sandbox (no countries) sees every hex. Pure core/views/
## code: no nodes, no engine calls, no writes. Its numbers come from ImprovePreview (the works card), Works and Improve.
## Sections are {head, lines: [[label, tone, text]]}; a section with no line is left out, and the cost lines are always
## worked out from Works.cost_of, so a refused card keeps them. Issue 436 round 3 (H5): `heading` is the card's action ("Upgrade
## to city", "Build a vineyard"; the building's stage for a standing piece), `subheading` what stands now; all money is a year.
class_name BuildingCard
extends RefCounted

const TONE_PLAIN := &"plain"
const TONE_GOOD := &"good"
const TONE_BAD := &"bad"
const HEAD_YEAR := "Each year it would"
const HEAD_BUILT_YEAR := "Each year it makes"
const HEAD_COST := "To build"
const BUILT_TEXT := "It stands here."
const SEASONS_A_YEAR := 4


## {title, kind, sections, verdict {ok, text, tone}}; {} for a hex the viewer may not see here, or a hex with nothing to show.
static func of(game: Game, tag: StringName, hex: Vector2i, option: Dictionary) -> Dictionary:
	if game == null or game.map == null or not game.map.has(hex):
		return {}
	if game.has_countries() and Territory.owner_tag(game, hex) != tag:
		return {}
	if option.is_empty():
		return _built(game, tag, hex)
	var action := StringName(str(option.get("action", "")))
	if action == Works.BUILD:
		return _offer(game, tag, hex, Works.BUILD, int(option.get("family", 0)), 1)
	if action == Works.UPGRADE:
		var piece := Improve.piece_at(game, hex)
		if piece.is_empty():
			return {}
		return _offer(game, tag, hex, Works.UPGRADE, int(piece["family_id"]), int(piece["level"]) + 1)
	return {}


## The card of a building that can be built or upgraded: the year, the cost and the verdict.
static func _offer(game: Game, tag: StringName, hex: Vector2i, action: StringName, family: int, level_to: int) -> Dictionary:
	var preview := ImprovePreview.of(game, tag, hex, {"action": action, "family": family})
	var sections: Array = []
	var workers := _workers(preview, false)
	if not workers.is_empty():
		sections.append({"head": "", "lines": workers})
	var year := _year_lines(game, preview, false)
	if not year.is_empty():
		sections.append({"head": HEAD_YEAR, "lines": year})
	sections.append({"head": HEAD_COST, "lines": _cost_lines(game, action, family, level_to, preview)})
	var kind := _kind(family, level_to)
	var heading := "Upgrade to %s" % kind.to_lower() if action == Works.UPGRADE else "Build: %s" % _capital(Words.piece_noun(
		FamilyIds.NAMES[family]))
	var now := Improve.piece_at(game, hex)
	var subheading := _title(game, hex, family)
	if action == Works.UPGRADE and not now.is_empty():
		subheading = "Now: %s in %s" % [_kind(family, int(now["level"])).to_lower(), ImproveCardParts.named(game, hex)]
	return {
		"title": _title(game, hex, family), "kind": kind, "sections": sections, "heading": heading, "subheading": subheading,
		"verdict": _verdict(game, tag, preview, action, family, level_to),
	}


## The card of a standing piece: what it makes and its upkeep (the clearing card, turned round), no cost.
static func _built(game: Game, tag: StringName, hex: Vector2i) -> Dictionary:
	var piece := Improve.piece_at(game, hex)
	if piece.is_empty():
		return {}
	var family := int(piece["family_id"])
	var preview := ImprovePreview.of(game, tag, hex, {"action": Works.CLEAR, "family": family})
	var sections: Array = []
	var workers := _workers(preview, true)
	if not workers.is_empty():
		sections.append({"head": "", "lines": workers})
	var year := _year_lines(game, preview, true)
	if not year.is_empty():
		sections.append({"head": HEAD_BUILT_YEAR, "lines": year})
	var kind := _kind(family, int(piece["level"]))
	return {
		"title": _title(game, hex, family), "kind": kind, "sections": sections, "heading": kind,
		"subheading": _title(game, hex, family), "verdict": {"ok": true, "text": BUILT_TEXT, "tone": TONE_GOOD},
	}


## The verdict line: the hammer's words when the row is ok, else the rule's own words in bad tone (a ducat refusal names the gap).
static func _verdict(game: Game, tag: StringName, preview: Dictionary, action: StringName, family: int, level_to: int) -> Dictionary:
	if bool((preview["verdict"] as Dictionary).get("ok", false)):
		var words := "You can upgrade this: click the tile." if action == Works.UPGRADE else "You can build this: click the tile."
		return {"ok": true, "text": words, "tone": TONE_GOOD}
	var text := str(preview.get("reason_words", ""))
	if StringName(preview.get("blocked_by", &"")) == &"ducats":
		var c := Countries.by_tag(game, tag)
		var need := int(Works.cost_of(game, action, family, level_to)["ducats"])
		var gap := maxi(need - c.treasury, 0) if c != null else need
		text = "You cannot afford this yet: %s more ducats." % Words.number(gap)
	if text == "":
		text = "You cannot build this here."
	return {"ok": false, "text": text, "tone": TONE_BAD}


## The "Workers" line when the year has jobs (the piece's jobs: after the change, or before it for a standing piece).
static func _workers(preview: Dictionary, built: bool) -> Array:
	for b: Variant in preview.get("brings", []):
		var row: Dictionary = b
		if StringName(row["field"]) == &"jobs":
			var jobs := int(row["before"] if built else row["after"])
			return [["Workers", TONE_PLAIN, Words.plural(jobs, "job", "jobs")]]
	return []


## Uses and makes (the goods that change a year), the profit and the upkeep; {} lines when the card has no year (a rule refusal,
## or a sandbox without a country). A standing piece turns each change round.
static func _year_lines(game: Game, preview: Dictionary, built: bool) -> Array:
	var out: Array = []
	for b: Variant in preview.get("brings", []):
		var row: Dictionary = b
		var field := StringName(row["field"])
		if field == &"" or game.defs == null or game.defs.good_id(field) < 0:
			continue
		var delta := int(row["after"]) - int(row["before"])
		if built:
			delta = -delta
		if delta == 0:
			continue
		var name := game.defs.goods[game.defs.good_id(field)].name
		if delta > 0:
			out.append(["Makes", TONE_GOOD, "%s a year" % Words.loads(delta, name)])
		else:
			out.append(["Uses", TONE_PLAIN, "%s a year" % Words.loads(delta, name)])
	var year: Dictionary = preview.get("year", {})
	var lands: Dictionary = preview.get("lands", {})
	if year.is_empty() or lands.is_empty():
		return out
	var gain := int(year["gain"])
	if built:
		gain = -gain
	out.append(["Profit a year", _tone(gain), Words.signed_ducats(gain)])
	var upkeep := int(lands["upkeep"]) * SEASONS_A_YEAR
	if built:
		upkeep = -upkeep
	out.append(["Upkeep a year", _tone(-upkeep), Words.signed_ducats(-upkeep)])
	return out


## The cost lines: ducats, each good, the building time and the payback. Worked out here, so a refused card keeps them.
static func _cost_lines(game: Game, action: StringName, family: int, level_to: int, preview: Dictionary) -> Array:
	var out: Array = []
	var cost := Works.cost_of(game, action, family, level_to)
	if int(cost["ducats"]) > 0:
		out.append(["Ducats", TONE_PLAIN, Words.ducats(int(cost["ducats"]))])
	var goods: Dictionary = cost["goods"]
	for key: Variant in goods:
		var g := game.defs.good_id(StringName(str(key)))
		var name := game.defs.goods[g].name if g >= 0 else str(key)
		out.append([_capital(name), TONE_PLAIN, Words.loads(int(goods[key]), name)])
	out.append(["Building time", TONE_PLAIN, Words.seasons(Works.seasons_for(game, action, family, level_to))])
	var payback: Dictionary = preview.get("payback", {})
	if not payback.is_empty() and str(payback.get("text", "")) != "":
		out.append(["Payback", TONE_PLAIN, str(payback["text"])])
	return out


## "Vineyard in Asti" (the piece's noun, the place's name or "this district").
static func _title(game: Game, hex: Vector2i, family: int) -> String:
	return "%s in %s" % [_capital(Words.piece_noun(FamilyIds.NAMES[family])), ImproveCardParts.named(game, hex)]


## The stage or level the card is for: "village", "walled town", "first stage".
static func _kind(family: int, level: int) -> String:
	return _capital(HexCard.level_label(FamilyIds.NAMES[family], level))


static func _tone(n: int) -> StringName:
	if n > 0:
		return TONE_GOOD
	if n < 0:
		return TONE_BAD
	return TONE_PLAIN


static func _capital(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)
