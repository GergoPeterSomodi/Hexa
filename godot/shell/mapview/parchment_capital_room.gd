## The room a country name of the parchment needs from the capitals (docs/architecture/map-overview-build-spec.md R10 and
## its amendment of 2026-11-28; used by ParchmentLabels). A capital's dot and its shown name are a hard obstacle: a name's
## turned box needs nothing of them, or the names of some capitals on the other side of their dots, or it cannot stand
## there. A capital here is its ParchmentLabels entry (dot, dot_radius, text, rect, size, hex).
class_name ParchmentCapitalRoom
extends RefCounted

## What a name's spot needs of the capitals round it.
enum Need { NOTHING, MOVES, TOO_MUCH }
## A box not worked out yet.
const UNASKED := Rect2(0.0, 0.0, -1.0, -1.0)

var _space: ParchmentLabelSpace  # the labels' own: what is placed, as boxes
var _blocks: Dictionary[Vector2i, int]  # the labels' own: hex -> the block of the name placed at its town
var _name_box: Callable  # (entry, px, above) -> Rect2: the box of the entry's name below or above its dot
var _may_name: Callable  # (box) -> bool: whether a capital's name may lie there
var _give_name: Callable  # (entry, box, px): shows the entry's name there and takes the box
var _capitals: Array[Dictionary] = []  # the layout's (begin)
var _covers: Array[Rect2] = []  # beside them: what each takes, dot and name
var _near: Array[Dictionary] = []  # near()'s last answer, for a name's next search, and what it was asked
var _near_at := Vector2.INF
var _near_half := Vector2.ZERO


func _init(space: ParchmentLabelSpace, blocks: Dictionary[Vector2i, int], name_box: Callable, may_name: Callable,
		give_name: Callable) -> void:
	_space = space
	_blocks = blocks
	_name_box = name_box
	_may_name = may_name
	_give_name = give_name


static func dot_box(dot: Vector2, radius: float) -> Rect2:
	return Rect2(dot, Vector2.ZERO).grow(radius + 1.0)


## How far from its place a name of half size `half` is searched near: a capital farther off cannot meet it there.
static func reach_of(half: Vector2) -> float:
	return half.x * 2.0 + half.y * 6.0


## What a capital takes: its dot and its name.
static func cover_of(entry: Dictionary) -> Rect2:
	return dot_box(entry["dot"], entry["dot_radius"]).merge(entry["rect"])


## The capitals of a new layout, their dots and names placed.
func begin(capitals: Array[Dictionary]) -> void:
	_capitals = capitals
	_measure()


## The capitals a name of half size `half` around `centre` could meet, wherever it is moved to near there. A name is
## searched for several times over: the same question again is answered at once.
func near(centre: Vector2, half: Vector2) -> Array[Dictionary]:
	if centre != _near_at or half != _near_half:
		_near_at = centre
		_near_half = half
		_near = []
		var reach := reach_of(half)
		for i: int in _covers.size():
			if _covers[i].grow(reach).has_point(centre):
				_near.append(_capitals[i])
	return _near


func _measure() -> void:
	_near_at = Vector2.INF
	_covers.clear()
	for entry: Dictionary in _capitals:
		_covers.append(cover_of(entry))


## The places the last search of a name adds: just clear of each capital's dot or name that lies in its way at `centre`,
## moved along its own line or normal; and, where capitals show names (the town view, where more than one box may be in
## the way), the finer places. `shape` is [axis, half]; of the first only places on `screen`, and none farther than the
## last search moves a name with `room` px along its line (ParchmentNameSpots.in_reach).
static func last_places(near_ones: Array[Dictionary], centre: Vector2, shape: Array[Vector2], screen: Rect2,
		room: float) -> Array[Vector2]:
	var in_the_way: Array[Rect2] = []
	var named := false
	for entry: Dictionary in near_ones:
		var boxes: Array[Rect2] = [dot_box(entry["dot"], entry["dot_radius"])]
		if str(entry["text"]) != "":
			boxes.append(entry["rect"])
			named = true
		for box: Rect2 in boxes:
			if ParchmentLabelSpace.turned_hits(box, centre, shape[0], shape[1]):
				in_the_way.append(box)
	var out := ParchmentNameSpots.beside(centre, shape, in_the_way, screen)
	if named:
		out.append_array(ParchmentNameSpots.fine(centre, shape))
	return ParchmentNameSpots.in_reach(out, centre, shape, room)


## Whether the turned box at `at` meets no capital that near(centre, half) leaves out: a name put past a box
## may land far from where it started. (A capital's rect is its name's box, or its dot's while no name is shown.)
static func far_clear(capitals: Array[Dictionary], centre: Vector2, half: Vector2, at: Vector2, axis: Vector2,
		box_half: Vector2) -> bool:
	var bounds := _bounds(at, axis, box_half)
	if Rect2(centre, Vector2.ZERO).grow(reach_of(half)).encloses(bounds):
		return true  # every capital it could meet is near
	for entry: Dictionary in capitals:
		# Most capitals are far from the spot: the engine's level test of their boxes comes first.
		var dot := dot_box(entry["dot"], entry["dot_radius"])
		if not bounds.intersects(dot) and not bounds.intersects(entry["rect"]):
			continue
		if (ParchmentLabelSpace.turned_hits(dot, at, axis, box_half) or ParchmentLabelSpace.turned_hits(entry["rect"], at,
				axis, box_half)) and not cover_of(entry).grow(reach_of(half)).has_point(centre):
			return false
	return true


## What stands in a name's way near it: for each capital [its dot's box, its name's box (empty when none is shown),
## the box that name would have on the other side of its dot (UNASKED until a spot asks; empty when it may not go
## there), the capital's entry].
static func taken_by(near_ones: Array[Dictionary]) -> Array[Array]:
	var out: Array[Array] = []
	for entry: Dictionary in near_ones:
		var shown: Rect2 = entry["rect"] if str(entry["text"]) != "" else Rect2()
		out.append([dot_box(entry["dot"], entry["dot_radius"]), shown, UNASKED, entry])
	return out


## What a name's turned box at `at` needs of the capitals (`taken`, see taken_by): nothing, some names moved to the
## other side of their dots, or more than can be done (it meets a dot, or a name with nowhere to go).
func need_at(taken: Array[Array], at: Vector2, axis: Vector2, half: Vector2) -> Need:
	var need := Need.NOTHING
	var bounds := _bounds(at, axis, half)
	for held: Array in taken:
		# Most capitals are far from the spot: the engine's level test of their boxes spares the turned ones.
		if not bounds.intersects(held[0]) and not bounds.intersects(held[1]):
			continue
		if ParchmentLabelSpace.turned_hits(held[0], at, axis, half):
			return Need.TOO_MUCH
		var shown: Rect2 = held[1]
		if shown.has_area() and ParchmentLabelSpace.turned_hits(shown, at, axis, half):
			if held[2] == UNASKED:
				held[2] = _room_over_there(held[3])
			var other: Rect2 = held[2]
			if not other.has_area() or ParchmentLabelSpace.turned_hits(other, at, axis, half):
				return Need.TOO_MUCH
			need = Need.MOVES
	return need


## Makes room for a turned box by putting each capital's name in its way on the other side of its dot. All of them or
## none: false, with nothing moved, when a name has no free place over there. (The dots are the caller's to check.)
func move_names(capitals: Array[Dictionary], centre: Vector2, axis: Vector2, half: Vector2) -> bool:
	var in_the_way: Array[Dictionary] = []
	for entry: Dictionary in capitals:
		if str(entry["text"]) != "" and ParchmentLabelSpace.turned_hits(entry["rect"], centre, axis, half):
			in_the_way.append(entry)
	var moved: Array[Array] = []  # [entry, its old box, its old block]
	for entry: Dictionary in in_the_way:
		var old: Rect2 = entry["rect"]
		var block: int = _blocks[entry["hex"]]
		var box := _other_side(entry)
		_space.lift(block)
		if ParchmentLabelSpace.turned_hits(box, centre, axis, half) or not bool(_may_name.call(box)):
			_space.put_back(block, old)
			for undo: Array in moved:
				var back: Dictionary = undo[0]
				_space.lift(_blocks[back["hex"]])
				_blocks[back["hex"]] = undo[2]
				_space.put_back(undo[2], undo[1])
				back["rect"] = undo[1]
			return false
		moved.append([entry, old, block])
		_give_name.call(entry, box, entry["size"])
	if not moved.is_empty():
		_measure()
	return true


## The level box round a turned box.
static func _bounds(at: Vector2, axis: Vector2, half: Vector2) -> Rect2:
	var x := absf(axis.x) * half.x + absf(axis.y) * half.y
	var y := absf(axis.y) * half.x + absf(axis.x) * half.y
	return Rect2(at.x - x, at.y - y, x * 2.0, y * 2.0)


## The box a capital's name may move to on the other side of its dot; empty when something is in the way there.
func _room_over_there(entry: Dictionary) -> Rect2:
	var block: int = _blocks[entry["hex"]]
	var box := _other_side(entry)
	_space.lift(block)
	var free := bool(_may_name.call(box))
	_space.put_back(block, entry["rect"])
	return box if free else Rect2()


## The box a capital's shown name would have on the other side of its dot.
func _other_side(entry: Dictionary) -> Rect2:
	var below := (entry["rect"] as Rect2).get_center().y > (entry["dot"] as Vector2).y
	return _name_box.call(entry, entry["size"], below)
