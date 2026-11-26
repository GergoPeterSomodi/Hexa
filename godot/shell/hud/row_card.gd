## The hover card of a tile window row (tile-window spec D12, R25, R26): turns a BuildingCard or CompanyCard dictionary
## ({title, kind, heading, subheading, sections: [{head, lines: [[label, tone, text]]}], verdict: {ok, text, tone}}) into the
## lines TileHoverCard shows ({title, subtitle, lines: [[text, tone, amount]]}; a section head has the tone &"head"). Issue 436
## round 3 (H5): the title is the card's action ("Upgrade to city") with what stands now as the subtitle, where the card gives
## them. Pure: no nodes, no game. The Hud places the card beside the hovered row (place).
class_name RowCard
extends RefCounted


## The HoverCard dictionary of a row card; {} for an empty card.
static func hover_of(card: Dictionary) -> Dictionary:
	if card.is_empty():
		return {}
	var lines: Array = []
	for raw: Variant in card.get("sections", []) as Array:
		var section := raw as Dictionary
		var head := str(section.get("head", ""))
		if head != "":
			lines.append([head, &"head"])
		for line: Variant in section.get("lines", []) as Array:
			var cells := line as Array
			if cells.size() >= 3:
				lines.append([str(cells[0]), StringName(str(cells[1])), str(cells[2])])
			elif cells.size() == 2:
				lines.append([str(cells[0]), StringName(str(cells[1]))])
	var verdict: Dictionary = card.get("verdict", {})
	if not verdict.is_empty() and str(verdict.get("text", "")) != "":
		lines.append(["", &"rule"])
		lines.append([str(verdict["text"]), StringName(str(verdict.get("tone", "plain")))])
	var title := str(card.get("heading", card.get("title", "")))
	var subtitle := str(card.get("subheading", card.get("kind", "")))
	return {"title": title, "subtitle": subtitle, "lines": lines}


## The top-left of a card of `size` beside the hovered row `anchor` (H5): its right edge S2 left of the row, top-aligned with it;
## right of the row when there is no room at its left; kept inside `view` and above `floor_y` (the key-hint bar's top).
static func place(anchor: Rect2, size: Vector2, view: Vector2, floor_y: float = -1.0) -> Vector2:
	var gap := float(Tokens.S2)
	var x := anchor.position.x - size.x - gap
	if x < 0.0:
		x = minf(anchor.end.x + gap, maxf(view.x - size.x, 0.0))
	var bottom := view.y if floor_y < 0.0 else minf(floor_y, view.y)
	var y := clampf(anchor.position.y, 0.0, maxf(bottom - size.y - gap, 0.0))
	return Vector2(x, y)
