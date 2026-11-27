## The stops of a march being staged on the map (docs/architecture/moves-build-spec.md R58 to R62, D32, D33): the hexes the shell
## holds for one army of yours until the march is ordered. Staging is the shell's alone: nothing here acts, logs or saves, and the
## game is only read (a leg's verdict, the preview). MapArmies owns one: it stages, draws, orders and clears. A new stop is
## checked as its leg alone (Movement.goal_verdict from the stop before it, no room check: a stop is passed) in words the viewer
## may read; the order checks the whole route again.
class_name MarchStops
extends RefCounted

## The refusal of a storm while stops are staged (R60).
const STORM_TEXT := "A storm takes no stops: clear them first (Esc)"
const OFF_MAP_TEXT := "that is off the map"
const NO_HEX := Vector2i(-9999, -9999)

var _army := -1
var _hexes: Array[Vector2i] = []


## The army the stops are staged for, -1 with none staged.
func army() -> int:
	return _army


func is_empty() -> bool:
	return _hexes.is_empty()


## The staged stops in order (a copy).
func hexes() -> Array[Vector2i]:
	return _hexes.duplicate()


## The last staged stop, NO_HEX with none.
func last() -> Vector2i:
	return NO_HEX if _hexes.is_empty() else _hexes[_hexes.size() - 1]


## Forgets the stops; false when there were none.
func clear() -> bool:
	var had := not _hexes.is_empty()
	_hexes.clear()
	_army = -1
	return had


## Shift+left click or V at `hex` for army `army_id` of `tag`: on the last staged stop it is taken off, else `hex` is added as
## a stop. "" when the stops changed; else the refusal's words, with nothing changed (R58).
func toggle(game: Game, tag: StringName, army_id: int, hex: Vector2i) -> String:
	var a := Armies.by_id(game, army_id)
	if a == null or game.map == null or not game.map.has(hex):
		return OFF_MAP_TEXT
	if _army != army_id:
		clear()
	if not _hexes.is_empty() and hex == last():
		_hexes.remove_at(_hexes.size() - 1)
		if _hexes.is_empty():
			_army = -1
		return ""
	var why := _refusal(game, tag, a, hex)
	if why != "":
		return why
	_army = army_id
	_hexes.append(hex)
	return ""


## The stops of an order whose goal is `hex`: every staged stop, less the last one when the goal is that stop (D33).
func via_for(hex: Vector2i) -> Array[Vector2i]:
	var out := hexes()
	if not out.is_empty() and hex == last():
		out.remove_at(out.size() - 1)
	return out


## The picture of the order a commit at `hex` gives (R59): MovePreview.via through the stops, or the plain MovePreview.to when
## the goal is the only stop (a march with no stops is ordered then). Both are cached by the views.
func preview(game: Game, tag: StringName, hex: Vector2i) -> Dictionary:
	var via := via_for(hex)
	if via.is_empty():
		return MovePreview.to(game, tag, _army, hex)
	return MovePreview.via(game, tag, _army, via, hex)


## Why `hex` may not be the next stop of `a`, "" when it may.
func _refusal(game: Game, tag: StringName, a: Army, hex: Vector2i) -> String:
	if _hexes.size() >= game.defs.max_stops:
		return MarchVia.TOO_MANY_TEXT % game.defs.max_stops
	if hex == a.hex:
		return MarchVia.SAME_AS_ARMY_TEXT
	var from := Movement.NO_HEX if _hexes.is_empty() else last()
	var verdict := Movement.goal_verdict(game, a, tag, hex, from, false)
	if bool(verdict.ok):
		return ""
	return str((MovePreview.refused(game, tag, hex, str(verdict.reason))["verdict"] as Dictionary)["reason"])
