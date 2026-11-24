## The odds card (docs/architecture/m7-build-spec.md 6.4; M7 B26): the hover card of a march that is a war target of the selected
## army (an attack, a siege, a storm, a walk in, or a walk in held by a castle), shown by MapHover in place of the move card. Its
## words are OddsView's (the odds, fogged by the view) and MovePreview.to's (the arrival and the place): this file only lays them
## out. A refusal is shown only for a shaken army (the two sentences of 6.4); every other refusal stays the move card's, which
## already names no hex the viewer does not see. It is a MoveCard, so it has the same frame and takes neither the mouse nor the
## focus. Pure words: `card_of` and `wants` are static and read no node.
class_name OddsCard
extends MoveCard

const WAR_KINDS: Array[StringName] = [OddsView.KIND_ATTACK, OddsView.KIND_SIEGE, OddsView.KIND_STORM,
	OddsView.KIND_WALK_IN, OddsView.KIND_HELD]
const SHAKEN_START := "Too shaken"
const TONE_PLAIN := "plain"
const TONE_BAD := "bad"
const PERMILLE_PER_PERCENT := 10


## The odds of the march: the preview's own when it has them, else OddsView.of (a refused march has none in its preview).
static func odds_of(game: Game, tag: StringName, army_id: int, hex: Vector2i, preview: Dictionary) -> Dictionary:
	var own := preview.get("odds", {}) as Dictionary
	if not own.is_empty():
		return own
	return OddsView.of(game, tag, army_id, hex)


## True when the hover card of this march is the odds card: a war target of the army (a march that is allowed), or a refused
## march that is a war target and only too shaken to attack (OddsView's sentence, which names no hex). Everything else is the
## move card.
static func wants(preview: Dictionary, odds: Dictionary) -> bool:
	if odds.is_empty() or not WAR_KINDS.has(StringName(str(odds.get("kind", "")))):
		return false
	if bool((preview.get("verdict", {}) as Dictionary).get("ok", false)):
		return true
	return str(odds.get("reason", "")).begins_with(SHAKEN_START)


## The card's words for a war target: {title, lines ([[text, tone]]), way_out} in MoveCard's form. The lines, in order: the kind
## and the word in its tone, the army (men and morale), the defence (men and morale, or the garrison's count and weight, or
## "unknown" when hidden), the ground and walls chips, the notes, and the arrival. The way out is the hint. A refusal is its
## reason in BAD only (the kind is kept above it).
static func card_of(preview: Dictionary, odds: Dictionary) -> Dictionary:
	var title := str(odds.get("title", ""))
	if title == "":
		title = str(preview.get("title", ""))
	var lines: Array = []
	var kind_text := str(odds.get("kind_text", ""))
	var tone := str(odds.get("tone", TONE_PLAIN))
	if not bool(odds.get("ok", false)):
		if kind_text != "":
			lines.append([kind_text, TONE_PLAIN])
		lines.append([str(odds.get("reason", "")), TONE_BAD])
		return {"title": title, "lines": lines, "way_out": ""}
	if kind_text != "":
		lines.append([kind_text, tone])
	var attack := odds.get("attack", {}) as Dictionary
	if not attack.is_empty() and int(attack.get("men", 0)) > 0:
		lines.append(["You %s · morale %s" % [Words.men(int(attack.men)), _percent(int(attack.morale))], TONE_PLAIN])
	var defence_line := _defence_line(odds)
	if defence_line != "":
		lines.append([defence_line, TONE_PLAIN])
	for chip: Variant in odds.get("chips", []) as Array:
		lines.append([str((chip as Dictionary).get("text", "")), TONE_PLAIN])
	for note: Variant in odds.get("notes", []) as Array:
		lines.append([str(note), TONE_PLAIN])
	var arrives := str(preview.get("arrives_text", ""))
	if arrives != "":
		lines.append([arrives, TONE_PLAIN])
	return {"title": title, "lines": lines, "way_out": str(odds.get("hint", ""))}


## The defender's line: the men and morale of the army it faces, "They 1,000 men · morale 100 %" when seen (exact, R25),
## "They: unknown" when hidden, and the garrison's count and weight behind its walls. "" when the card has none.
static func _defence_line(odds: Dictionary) -> String:
	var defence := odds.get("defence", {}) as Dictionary
	var access := str(defence.get("access", OddsView.ACCESS_HIDDEN))
	var garrison := defence.get("garrison", {}) as Dictionary
	var kind := str(odds.get("kind", ""))
	if access == OddsView.ACCESS_HIDDEN:
		return "They: unknown" if kind == str(OddsView.KIND_ATTACK) or kind == str(OddsView.KIND_STORM) else ""
	var parts := PackedStringArray()
	if int(defence.get("men", 0)) > 0:
		parts.append("They %s · morale %s" % [Words.men(int(defence.men)), _percent(int(defence.get("morale", 0)))])
	if int(garrison.get("men", 0)) > 0:
		var weight := int(garrison.get("weight_permille", 0)) / 1000.0
		parts.append("a garrison of %s · counts ×%.1f behind its walls" % [Words.number(int(garrison.men)), weight])
	return " · ".join(parts)


## "100 %" from permille.
static func _percent(permille: int) -> String:
	return "%d %%" % int(float(permille) / PERMILLE_PER_PERCENT)


## Shows the odds card of a war target (`card_of`); the card takes no focus and no mouse, as the move card does.
func show_odds(preview: Dictionary, odds: Dictionary) -> void:
	_fill(card_of(preview, odds))
	_open = true
	visible = true
