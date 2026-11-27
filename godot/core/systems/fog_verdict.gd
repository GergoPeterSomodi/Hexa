## The fog-safe reads of an order before it is given (docs/architecture/moves-build-spec.md R23, R28, R45, R57): what a country is
## told of a march, a Continue or a storm, and of the preview's leg, reads the armies of other countries only on hexes it sees.
## An army out of sight is not there for the verdict: the walk meets it by its own rules (the other-country cut R24, the contact
## and its refusal R26, R28), with fog-safe words. Movement.goal_verdict (so march_check, continue_check, storm_check and the AI's
## checks, which go through Game.check) and MovePreview's leg read these. Pure reads; no luck; integer maths.
class_name FogVerdict
extends RefCounted

const OWNS: Array[String] = []


## True when `tag` sees `hex` now (Sight; the viewer "" sees all).
static func sees(game: Game, tag: StringName, hex: Vector2i) -> bool:
	return tag == &"" or Sight.sees(game, tag, hex)


## The goal's stand check of an order for `army` of `tag` (4.7 rows 7 and 8): "" or the refusal. On a goal the country sees, an
## army of a country at war there makes the order an attack (Battles.engage_check), else another country's army or the room with
## the country's companies on their way (Military.can_stand: `adding`, `leaving`). On a goal it does not see, the room alone
## (Military.room_text): the country's own companies are all it may read there.
static func stand(game: Game, army: Army, tag: StringName, goal: Vector2i, adding: int, leaving: PackedInt32Array) -> String:
	if not sees(game, tag, goal):
		return Military.room_text(game, tag, goal, adding, leaving)
	if Movement.enemy_army_at(game, tag, goal):
		var attack := Battles.engage_check(game, {"army": army.id, "hex": goal, "tag": tag})
		return "" if bool(attack.ok) else str(attack.reason)
	return Military.can_stand(game, tag, goal, adding, leaving)


## The contact of a step of `army` onto `hex`, where an army at war with its country stands (R26, R28), as the walk decides it
## (Battles.engage_check): {ok (the battle opens), why (the walk's halt word when refused: MarchLeg.refusal_why), text (the
## check's words)}. The preview asks it only on a hex the viewer sees, so the words name only what it sees.
static func contact(game: Game, army: Army, hex: Vector2i) -> Dictionary:
	var check := Battles.engage_check(game, {"army": army.id, "hex": hex, "tag": army.tag})
	if bool(check.ok):
		return {"ok": true, "why": &"", "text": ""}
	var text := str(check.reason)
	return {"ok": false, "why": MarchLeg.refusal_why(game, army, hex), "text": text if text != "" else MarchLeg.SHUT_TEXT}
