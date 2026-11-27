## The path of a march under way and what Shift+right click (or V) orders next (docs/architecture/moves-build-spec.md R58 to
## R60; owner 2026-11-27: the click orders the path, nothing is held back). A path is the army's march order: the points still
## ahead (Army.via) and the goal. A hex clicked is added to its end; its final point clicked again comes off; the only point
## clicked again halts the army. Pure reads: MapArmies gives the order through Session.act, and the preview of it is the views'.
class_name MarchPath
extends RefCounted

## The first line of the preview that takes the path's end off, and of the one that takes off the only point.
const SHORTEN_TEXT := "Takes the last point off the path."
const HALT_TEXT := "Takes the last point off the path: the army halts."


## True while `a` has a march order with a goal it has not reached.
static func under_way(a: Army) -> bool:
	return a != null and a.order == Army.ORDER_MARCH and a.goal != Army.NO_HEX and a.goal != a.hex


## The points of `a`'s path still ahead, in order, the goal not among them.
static func ahead(game: Game, a: Army) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for hex: Vector2i in MarchVia.hexes_of(game, a.via):
		if hex != a.hex:
			out.append(hex)
	return out


## The order Shift+right click on `hex` gives `a` while its path is under way: {halt, goal, via}. The final point clicked:
## the one before it is the goal (none before it: `halt`); any other hex is the new goal, the path so far its `via`. {} with
## no path under way: the click is a plain march then.
static func next(game: Game, a: Army, hex: Vector2i) -> Dictionary:
	if not under_way(a):
		return {}
	var via := ahead(game, a)
	if hex != a.goal:
		via.append(a.goal)
		return {"halt": false, "goal": hex, "via": via}
	if via.is_empty():
		return {"halt": true, "goal": a.goal, "via": via}
	var goal: Vector2i = via.pop_back()
	return {"halt": false, "goal": goal, "via": via}


## The picture of that order, in MovePreview.to's form: the extended path's (MovePreview.via), or, on the final point, the
## shortened one's under the clicked place's name with a first line that says what comes off. {} with no path under way, or for
## an army that is not `tag`'s.
static func preview(game: Game, tag: StringName, army_id: int, hex: Vector2i) -> Dictionary:
	var a := Armies.by_id(game, army_id) if game != null and game.map != null else null
	if a == null or a.tag != tag or not game.map.has(hex):
		return {}
	var step := next(game, a, hex)
	if step.is_empty():
		return {}
	var via: Array[Vector2i] = step["via"]
	if hex != a.goal:
		return MovePreview.via(game, tag, army_id, via, hex)
	var out: Dictionary = {"verdict": {"ok": true, "reason": ""}, "hexes": [], "stops": [], "crossings": [], "via": [],
		"lines": [], "way_out": ""}
	var text := HALT_TEXT
	if not bool(step["halt"]):
		var goal: Vector2i = step["goal"]
		var shorter := MovePreview.to(game, tag, army_id, goal) if via.is_empty() else MovePreview.via(game, tag, army_id, via, goal)
		out = shorter.duplicate()
		text = SHORTEN_TEXT
	var lines: Array = [[text, MovePreview.TONE_PLAIN]]
	lines.append_array(out["lines"] as Array)
	out["lines"] = lines
	out["title"] = Words.place(game, hex)
	out["odds"] = {"kind": OddsView.KIND_NONE}  # the move card, not the odds card of the point before
	return out
