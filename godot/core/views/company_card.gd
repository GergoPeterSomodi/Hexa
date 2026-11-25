## The hover card of a Raise companies row (docs/architecture/tilewin-build-spec.md R26, TW7): the men and the fighting of a
## kind of company, what raising one takes, what it costs afterwards, and the verdict line ("You can raise 6 companies here
## this season." or the refusal in bad tone). A refused kind keeps its whole card. Raising is the player's own settlements
## only: {} wherever Military.raise_offered says no. Pure core/views/ code: no nodes, no engine calls, no writes; the numbers
## come from Military (the rules), Supply (food) and Countries (the stores). Optional M9.5 sections (arms) are left out until
## their data exists.
class_name CompanyCard
extends RefCounted

const TONE_PLAIN := &"plain"
const TONE_GOOD := &"good"
const TONE_BAD := &"bad"
const HEAD_MEN := "Men"
const HEAD_RAISE := "To raise"
const HEAD_AFTER := "Afterwards"
const AGES: Array[String] = ["I", "II", "III"]


## {title, kind, sections, verdict {ok, text, tone}}; {} unless `tag` may raise companies on `hex` at all.
static func of(game: Game, tag: StringName, hex: Vector2i, kind: int) -> Dictionary:
	if game == null or not Military.raise_offered(game, tag, hex):
		return {}
	var ud := Military.unit_def(game, kind)
	if ud == null:
		return {}
	var c := Countries.by_tag(game, tag)
	if c == null:
		return {}
	var sections: Array = [
		{"head": HEAD_MEN, "lines": _men_lines(ud)},
		{"head": HEAD_RAISE, "lines": _raise_lines(game, c, tag, hex, ud)},
		{"head": HEAD_AFTER, "lines": _after_lines(game, ud)},
	]
	return {
		"title": ud.name, "kind": _capital(String(ud.branch)), "sections": sections,
		"verdict": _verdict(game, tag, hex, kind, ud),
	}


static func _men_lines(ud: UnitDef) -> Array:
	return [
		["Men", TONE_PLAIN, Words.men(ud.men)],
		["Attack and defence", TONE_PLAIN, "%d and %d" % [ud.attack, ud.defence]],
		["Age", TONE_PLAIN, AGES[clampi(ud.era - 1, 0, AGES.size() - 1)]],
	]


## Ducats, each good the kind takes (with what the stores hold), and the men levied from the people.
static func _raise_lines(game: Game, c: Country, tag: StringName, hex: Vector2i, ud: UnitDef) -> Array:
	var out: Array = []
	var cost := Military.cost_of(game, ud.id, 1)
	out.append(["Ducats", TONE_PLAIN, Words.ducats(int(cost["ducats"]))])
	var goods: Dictionary = cost["goods"]
	for key: Variant in goods:
		var g := game.defs.good_id(StringName(str(key)))
		var name := game.defs.goods[g].name if g >= 0 else str(key)
		var need := int(goods[key])
		var have := c.stock[g] if g >= 0 and g < c.stock.size() else 0
		var tone := TONE_PLAIN if have >= need else TONE_BAD
		out.append([_capital(name), tone, "%s, you have %s" % [Words.loads(need, name), Words.number(have)]])
	var at_hand := Military.men_at_hand(game, tag, hex)
	var tone_men := TONE_PLAIN if at_hand >= ud.men else TONE_BAD
	out.append(["Men from the people", tone_men, "%s of %s available" % [Words.number(ud.men), Words.number(at_hand)]])
	return out


## Upkeep a season (ducats) and the food the company eats a season (the army's ration, as the supply counts it).
static func _after_lines(game: Game, ud: UnitDef) -> Array:
	return [
		["Upkeep a season", TONE_PLAIN, Words.ducats(ud.upkeep)],
		["Food a season", TONE_PLAIN, Words.plural(Supply.food_need(game, ud.men), "load of food", "loads of food")],
	]


## The largest number of companies of the kind the hex takes this season (0 for none); the stepping down of Military's
## raise rules, bounded by the settlement's cap left.
static func can_raise(game: Game, tag: StringName, hex: Vector2i, kind: int) -> int:
	var left := Military.raise_cap(game, hex) - Military.raised_here(game, tag, hex)
	for n: int in range(left, 0, -1):
		if bool(Military.raise_check(game, {"hex": hex, "kind": kind, "count": n, "tag": tag})["ok"]):
			return n
	return 0


static func _verdict(game: Game, tag: StringName, hex: Vector2i, kind: int, ud: UnitDef) -> Dictionary:
	var n := can_raise(game, tag, hex, kind)
	if n > 0:
		return {"ok": true, "text": "You can raise %s here this season." % Words.plural(n, "company", "companies"),
			"tone": TONE_GOOD}
	var reason := str(Military.raise_check(game, {"hex": hex, "kind": kind, "count": 1, "tag": tag})["reason"])
	if reason == "":
		reason = "You cannot raise %s here." % ud.many
	return {"ok": false, "text": _sentence(reason), "tone": TONE_BAD}


static func _sentence(reason: String) -> String:
	var text := _capital(reason)
	return text if text.ends_with(".") else text + "."


static func _capital(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)
