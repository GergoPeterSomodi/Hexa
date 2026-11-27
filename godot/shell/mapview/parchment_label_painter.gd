## Draws what ParchmentLabels laid out (its placed() entries): town dots, the country names over them, then the
## capitals, the goods icons and the town names. Called from the labels' _draw only; the colours are ParchmentTokens'.
class_name ParchmentLabelPainter
extends RefCounted

## A country name's baseline below its box's middle, and a town name's below its box's top, in font sizes.
const NAME_BASE_EM := 0.34
const TOWN_BASE_EM := 0.88
## Line widths (screen px).
const DOT_EDGE_PX := 1.0
const CAPITAL_EDGE_PX := 2.5
const DISC_EDGE_PX := 1.5
## The step between two pips in pip radii.
const PIP_STEP := 2.6


## Draws `items` on `on`, their screen px carried into its space by `base`. `colours` are ParchmentTokens.colours,
## `name_colours` the country names' [ink, halo], `name_face` gives a country name's font for its size, `icon_of` a good
## icon's texture (or null).
static func paint(on: CanvasItem, base: Transform2D, items: Array[Dictionary], colours: Dictionary[StringName, Color],
		town_font: Font, name_colours: Array[Color], name_face: Callable, icon_of: Callable) -> void:
	on.draw_set_transform_matrix(base)
	for item: Dictionary in items:
		if item["kind"] == ParchmentLabels.KIND_TOWN:
			_dot(on, item, false, colours)
	for item: Dictionary in items:
		if item["kind"] == ParchmentLabels.KIND_COUNTRY:
			_country(on, base, item, name_face.call(int(item["size"])) as Font, name_colours)
	on.draw_set_transform_matrix(base)
	for item: Dictionary in items:
		if item["kind"] == ParchmentLabels.KIND_CAPITAL:
			_dot(on, item, true, colours)
			_town_name(on, item, town_font, colours)
	for item: Dictionary in items:
		if item["kind"] == ParchmentLabels.KIND_ICON:
			_icon(on, item, icon_of.call(item["icon"]) as Texture2D, colours)
	for item: Dictionary in items:
		if item["kind"] == ParchmentLabels.KIND_TOWN:
			_town_name(on, item, town_font, colours)


## A town's dot fades in with the town view; a capital's is always shown, dark in the far view.
static func _dot(on: CanvasItem, item: Dictionary, capital: bool, colours: Dictionary[StringName, Color]) -> void:
	var fade := float(item["name_alpha"])
	var fill: Color = colours[&"dot_fill"]
	var edge: Color = colours[&"dot_edge"]
	if capital:
		fill = edge.lerp(fill, fade)
	else:
		fill.a *= fade
		edge.a *= fade
	var at: Vector2 = item["dot"]
	var radius := float(item["dot_radius"])
	on.draw_circle(at, radius, fill, true, -1.0, true)
	on.draw_circle(at, radius, edge, false, CAPITAL_EDGE_PX if capital else DOT_EDGE_PX, true)


static func _town_name(on: CanvasItem, item: Dictionary, font: Font, colours: Dictionary[StringName, Color]) -> void:
	var text := str(item["text"])
	var fade := float(item["name_alpha"])
	if text == "" or fade <= 0.0:
		return
	var px := int(item["size"])
	var box: Rect2 = item["rect"]
	var half_halo := ParchmentTokens.HALO_PX * 0.5
	var base := box.position + Vector2(half_halo, half_halo + TOWN_BASE_EM * px)
	var ink: Color = colours[&"town_ink"]
	var halo: Color = colours[&"halo"]
	ink.a *= fade
	halo.a *= fade
	on.draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ParchmentTokens.HALO_PX, halo)
	on.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)


## Leaves the draw transform turned: paint sets it back.
static func _country(on: CanvasItem, base: Transform2D, item: Dictionary, font: Font, colours: Array[Color]) -> void:
	var text := str(item["text"])
	var px := int(item["size"])
	var extent: Vector2 = item["extent"]
	var start := Vector2((ParchmentTokens.HALO_PX - extent.x) * 0.5, NAME_BASE_EM * px)
	on.draw_set_transform_matrix(base * Transform2D(deg_to_rad(float(item["angle"])), item["centre"] as Vector2))
	on.draw_string_outline(font, start, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ParchmentTokens.HALO_PX, colours[1])
	on.draw_string(font, start, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, colours[0])


static func _icon(on: CanvasItem, item: Dictionary, texture: Texture2D, colours: Dictionary[StringName, Color]) -> void:
	var centre: Vector2 = item["centre"]
	var radius := float(item["radius"])
	on.draw_circle(centre, radius, colours[&"disc"], true, -1.0, true)
	on.draw_circle(centre, radius, colours[&"disc_edge"], false, DISC_EDGE_PX, true)
	if texture != null:
		var side := ParchmentIconSpots.glyph_side(radius)
		on.draw_texture_rect(texture, Rect2(centre - Vector2(side, side) * 0.5, Vector2(side, side)), false)
	# The pips, one a stage, in a row just under the disc.
	var pip := ParchmentLabels.pip_radius(radius)
	var stage := int(item["stage"])
	for i: int in stage:
		var at := centre + Vector2((i - (stage - 1) * 0.5) * PIP_STEP * pip, radius + ParchmentLabels.PIP_GAP_PX + pip)
		on.draw_circle(at, pip + 1.0, colours[&"disc"], true, -1.0, true)
		on.draw_circle(at, pip, colours[&"pip"], true, -1.0, true)
