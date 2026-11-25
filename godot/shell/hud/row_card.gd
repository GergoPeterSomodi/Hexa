## The hover card of a tile window row (tile-window spec D12, R25, R26): turns a BuildingCard or CompanyCard dictionary
## ({title, kind, sections: [{head, lines: [[label, tone, text]]}], verdict: {ok, text, tone}}) into the lines HoverCard
## shows ({title, subtitle, lines: [[text, tone, amount]]}). Pure: no nodes, no game. The Hud places the card beside the
## window at the row's rect.
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
			lines.append([head, &"muted"])
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
	return {"title": str(card.get("title", "")), "subtitle": str(card.get("kind", "")), "lines": lines}


## The top-left of a card of `size` beside the window rect `window`: left of it, level with the anchor row, kept inside `view`.
static func place(anchor: Rect2, window: Rect2, size: Vector2, view: Vector2) -> Vector2:
	var x := window.position.x - size.x - float(Tokens.S2)
	if x < 0.0:
		x = minf(window.end.x + float(Tokens.S2), maxf(view.x - size.x, 0.0))
	var y := clampf(anchor.position.y, 0.0, maxf(view.y - size.y, 0.0))
	return Vector2(x, y)
