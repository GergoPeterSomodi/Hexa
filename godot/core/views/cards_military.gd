## The hover card of the Army chip in the resource bar (docs/architecture/m6-build-spec.md sections 6.10 and 5.6; L11): the men
## under arms of a country and what they cost and suffer. Pure core/views/ code. The card is the player's own country's: the
## caller passes its tag.
class_name MilitaryCards
extends RefCounted

const TONE_PLAIN := &"plain"
const TONE_BAD := &"bad"
const TONE_MUTED := &"muted"
const HINT := "Click: the Military page"


## {value (men under arms), change (men since the season before last, the last season's change), title, lines, hint}.
## Lines: [text, tone] for the armies and companies; [label, tone, amount] for upkeep, out of supply and losses.
static func army(game: Game, tag: StringName) -> Dictionary:
	var armies := Armies.of_country(game, tag)
	var men := Armies.men_of_country(game, tag)
	var lines: Array = []
	if armies.is_empty():
		lines.append(["No armies", TONE_MUTED])
	else:
		var companies := 0
		for a: Army in armies:
			companies += a.units.size()
		lines.append(["%s, %s" % [Words.plural(armies.size(), "army", "armies"),
			Words.plural(companies, "company", "companies")], TONE_PLAIN])
		var upkeep := Military.upkeep_country(game, tag)
		if upkeep > 0:
			lines.append(["Upkeep a season", TONE_BAD, upkeep])
		var out := _out_of_supply(game, tag, armies)
		if out > 0:
			lines.append(["Out of supply", TONE_BAD, Words.plural(out, "army", "armies")])
		var lost := 0
		for a: Army in armies:
			lost += a.lost_last
		if lost > 0:
			lines.append(["Lost last season", TONE_BAD, lost])
	return {
		"value": men,
		"change": _change(game, tag),
		"title": "Men under arms",
		"lines": lines,
		"hint": HINT,
	}


## The armies of `tag` whose hex is out of its supply this season.
static func _out_of_supply(game: Game, tag: StringName, armies: Array[Army]) -> int:
	var winter := Calendar.is_winter(game.turn)
	var n := 0
	for a: Army in armies:
		if not Supply.in_supply(game, tag, a.hex, winter):
			n += 1
	return n


## The change of the men under arms over the last closed season (0 before two seasons, or without statistics).
static func _change(game: Game, tag: StringName) -> int:
	if game.stats == null:
		return 0
	return game.stats.value(tag, game.turn - 1, "army_men") - game.stats.value(tag, game.turn - 2, "army_men")
