## The names of the map prototype's settlements, placed without collisions (step 5 of the prototype): each name tries the offsets
## around its marker in order, a name takes the first offset whose box is free of the markers, the panels and the names
## already placed, and a name that finds no free offset is dropped. The names are placed by rank (the great city first, then
## the cities, the towns and the villages), so on a conflict the lower-ranked name goes. Pure: the caller measures the text.
class_name WorldLabels
extends RefCounted

## Gap between a marker and its name, in pixels.
const GAP := 10.0
## The offsets tried in order, as the name's box relative to its marker: right and above first (the step-5 position), then
## right and below, left and above, left and below, above and below the marker, centred. "r" is the marker's half size.
enum Spot { RIGHT_UP, RIGHT_DOWN, LEFT_UP, LEFT_DOWN, ABOVE, BELOW }
const SPOTS: Array[int] = [Spot.RIGHT_UP, Spot.RIGHT_DOWN, Spot.LEFT_UP, Spot.LEFT_DOWN, Spot.ABOVE, Spot.BELOW]


## Places the names. Each item: name (String), at (Vector2, the marker's centre in pixels), width (float, the text's width),
## size (float, the font size), rank (int, higher first; ties by name), half (float, the marker's half size). obstacles: the
## boxes the names must keep off (the markers of all places, the panels). Returns the placed items, in placing order, each
## with "box" (Rect2: the text's top-left and its size) added.
static func place(items: Array[Dictionary], obstacles: Array[Rect2], bounds: Rect2) -> Array[Dictionary]:
	var order := items.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["rank"]) != int(b["rank"]):
			return int(a["rank"]) > int(b["rank"])
		return str(a["name"]) < str(b["name"]))
	var taken: Array[Rect2] = obstacles.duplicate()
	var placed: Array[Dictionary] = []
	for item: Dictionary in order:
		var box := _free_box(item, taken, bounds)
		if box.size == Vector2.ZERO:
			continue
		taken.append(box)
		var out := item.duplicate()
		out["box"] = box
		placed.append(out)
	return placed


## The box of the name at the first free spot, or an empty box (zero size) when none is free.
static func _free_box(item: Dictionary, taken: Array[Rect2], bounds: Rect2) -> Rect2:
	for spot: int in SPOTS:
		var box := box_at(spot, item)
		if not bounds.encloses(box):
			continue
		var clear := true
		for other: Rect2 in taken:
			if other.intersects(box):
				clear = false
				break
		if clear:
			return box
	return Rect2(Vector2.ZERO, Vector2.ZERO)


## The box of a name at a spot around its marker. The box is the text's width and its font size plus a little leading.
static func box_at(spot: int, item: Dictionary) -> Rect2:
	var at: Vector2 = item["at"]
	var w: float = item["width"]
	var size: float = item["size"]
	var half: float = item["half"]
	var h := size + 4.0
	var x := at.x + half + GAP
	var y := at.y - h / 2.0
	match spot:
		Spot.RIGHT_UP:
			y = at.y - half - h + 2.0
		Spot.RIGHT_DOWN:
			y = at.y + half - 2.0
		Spot.LEFT_UP:
			x = at.x - half - GAP - w
			y = at.y - half - h + 2.0
		Spot.LEFT_DOWN:
			x = at.x - half - GAP - w
			y = at.y + half - 2.0
		Spot.ABOVE:
			x = at.x - w / 2.0
			y = at.y - half - h
		Spot.BELOW:
			x = at.x - w / 2.0
			y = at.y + half
	return Rect2(Vector2(x, y), Vector2(w, h))
