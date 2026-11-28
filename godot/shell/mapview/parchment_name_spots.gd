## Where a country name of the parchment may be put (docs/architecture/map-overview-build-spec.md R10, D7; used by
## ParchmentLabels): the slides along its normal, the farther places along its line, the places just past the boxes it
## keeps off, the sizes it is tried at, and whether a slid name is still on its own country. A name is a turned box: its
## middle, its long axis (a unit vector) and its half size; `shape` is [axis, half].
class_name ParchmentNameSpots
extends RefCounted

## The slides of R10, in lines (the name box's height) along the normal, nearest first.
const SLIDES: Array[float] = [0.0, -0.25, 0.25, -0.5, 0.5, -0.75, 0.75, -1.0, 1.0]
## The farther places a name takes when R10's slides do not serve: shifts along its line, in shares of its length, each
## with these lines along the normal.
const FAR_ALONG: Array[float] = [0.0, -0.2, 0.2, -0.4, 0.4]
const FAR_LINES: Array[float] = [0.0, -0.5, 0.5, -1.0, 1.0, -1.25, 1.25, -1.75, 1.75, -2.25, 2.25]
## The room left between a name put past a box and the box (screen px).
const PAST_PX := 1.0
## The stages of a search for a clear spot (see stage).
const STAGES := 3

static var _far: Array[Vector2] = []  # the farther places (share along, lines across), nearest first


## The sizes a name of size `px` is tried at, largest first: `shares` of it and `plain`, none under `least`.
static func sizes(px: int, plain: int, shares: Array[float], least: int) -> Array[int]:
	var out: Array[int] = []
	for share: float in shares:
		out.append(maxi(least, roundi(px * share)))
	out.append(maxi(least, plain))
	out.sort()
	out.reverse()
	return out


## The middle of a name of shape `shape` moved from `centre` by `place`: x lengths along the axis, y lines across it.
static func spot(centre: Vector2, shape: Array[Vector2], place: Vector2) -> Vector2:
	var axis := shape[0]
	return centre + axis * (place.x * shape[1].x * 2.0) + Vector2(-axis.y, axis.x) * (place.y * shape[1].y * 2.0)


## The middles of one stage (0 to STAGES - 1) of the search for a clear spot: R10's slides, the farther places, the
## places past one of `boxes`. A stage is made only when the search gets to it: most names stop at the first.
static func stage(n: int, centre: Vector2, shape: Array[Vector2], boxes: Array[Rect2], screen: Rect2) -> Array[Vector2]:
	if n == 0:
		return near(centre, shape)
	return far(centre, shape) if n == 1 else past(centre, shape, boxes, screen)


## The middles a name of shape `shape` at `centre` takes by R10's slides, nearest first.
static func near(centre: Vector2, shape: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for line: float in SLIDES:
		out.append(spot(centre, shape, Vector2(0.0, line)))
	return out


## The farther middles, the least moved first (a length along counts as four lines).
static func far(centre: Vector2, shape: Array[Vector2]) -> Array[Vector2]:
	if _far.is_empty():
		for along: float in FAR_ALONG:
			for line: float in FAR_LINES:
				if along != 0.0 or absf(line) > 1.0:
					_far.append(Vector2(along, line))
		_far.sort_custom(func(a: Vector2, b: Vector2) -> bool:
			var da := absf(a.x) * 4.0 + absf(a.y)
			var db := absf(b.x) * 4.0 + absf(b.y)
			return da < db or (da == db and (a.x < b.x or (a.x == b.x and a.y < b.y))))
	var out: Array[Vector2] = []
	for place: Vector2 in _far:
		out.append(spot(centre, shape, place))
	return out


## The middles that put a name of shape `shape` just past a side of one of `boxes`, moved level or upright from
## `centre`, nearest first; only those on `screen`.
static func past(centre: Vector2, shape: Array[Vector2], boxes: Array[Rect2], screen: Rect2) -> Array[Vector2]:
	var reach := bounds_half(shape) + Vector2(PAST_PX, PAST_PX)
	var found: Array[Vector2] = []
	for box: Rect2 in boxes:
		for at: Vector2 in [Vector2(box.position.x - reach.x, centre.y), Vector2(box.end.x + reach.x, centre.y),
				Vector2(centre.x, box.position.y - reach.y), Vector2(centre.x, box.end.y + reach.y)]:
			if screen.has_point(at):
				found.append(at)
	found.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var da := a.distance_squared_to(centre)
		var db := b.distance_squared_to(centre)
		return da < db or (da == db and (a.x < b.x or (a.x == b.x and a.y < b.y))))
	return found


## Half the size of the level box round a name of shape `shape`.
static func bounds_half(shape: Array[Vector2]) -> Vector2:
	var axis := shape[0]
	var half := shape[1]
	return Vector2(absf(axis.x) * half.x + absf(axis.y) * half.y, absf(axis.y) * half.x + absf(axis.x) * half.y)


## The boxes of `boxes` a name of half size `half` around `centre` could meet, wherever it is moved to.
static func boxes_near(boxes: Array[Rect2], centre: Vector2, half: Vector2) -> Array[Rect2]:
	var reach := half.x * 2.0 + half.y * 6.0
	var out: Array[Rect2] = []
	for box: Rect2 in boxes:
		if box.grow(reach).has_point(centre):
			out.append(box)
	return out


## Whether the name's turned box at `at` meets one of `boxes`.
static func hits(boxes: Array[Rect2], at: Vector2, axis: Vector2, half: Vector2) -> bool:
	for box: Rect2 in boxes:
		if ParchmentLabelSpace.turned_hits(box, at, axis, half):
			return true
	return false


## Whether a slid name is still on the region of country `id`: the way from `home` to `at` and the centre line of half
## length `reach` through `at` cross only its hexes (so the slid line is on the region the name started on). `owners` is
## ParchmentView.owner_bytes, `xform` carries map px to screen px.
static func on_region(owners: PackedByteArray, map: MapData, xform: Transform2D, id: int, home: Vector2, at: Vector2,
		axis: Vector2, reach: float) -> bool:
	var inverse := xform.affine_inverse()
	return _line_owned(owners, map, inverse * (at - axis * reach), inverse * (at + axis * reach), id) \
		and _line_owned(owners, map, inverse * home, inverse * at, id)


## Whether the line from `a` to `b` (map px) lies on hexes of country `id` all the way.
static func _line_owned(owners: PackedByteArray, map: MapData, a: Vector2, b: Vector2, id: int) -> bool:
	# The ends first: a line that leaves its country mostly does so there.
	for end: Vector2 in [b, a]:
		var hex := MapModes.hex_at_px(end)
		if not map.has(hex) or int(owners[map.index_of(hex)]) != id:
			return false
	var along := b - a
	if along.is_zero_approx():
		return true
	return not ParchmentLabelSpace.over_hexes(owners, map, (a + b) * 0.5, along.normalized(),
		Vector2(along.length() * 0.5, 0.0), id, false)
