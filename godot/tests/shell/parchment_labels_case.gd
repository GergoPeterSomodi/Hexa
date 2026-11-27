## What the tests of ParchmentLabels share: the games, the views, the readers of placed() and the faulty labels of the
## planted cases.
class_name ParchmentLabelsCase
extends GutTest

const GEN := &"GEN"
const VIEWER := AiFixture.MILAN
const SCREEN := Vector2(1920.0, 1080.0)
const SIZE_EPS := 0.5


## Labels that keep the viewer of the first read, as a setup that stored its viewer did (a planted fault).
class StaleViewer:
	extends ParchmentLabels

	var held: StringName = &""

	func _viewer_now() -> StringName:
		return held


## Country names left where R10 alone leaves them: no search for room by the capitals (a planted fault).
class NoRoom:
	extends ParchmentLabels

	func _put_clear(_name: Dictionary, _centre: Vector2, _sizes: Array[int], _capitals: Array[Dictionary]) -> bool:
		return false


## A layout that places every name and icon wherever it first tries: the collision check left out (a planted fault).
class NoCollision:
	extends ParchmentLabels

	func _is_blocked(_box: Rect2, _over_names: bool = false) -> bool:
		return false


## The labels with no country names: what the icons could do if no name were in the way.
class NoNames:
	extends ParchmentLabels

	func _place_country_names(_hex_px: float, _capitals: Array[Dictionary]) -> void:
		pass


func _full() -> Game:
	return EconomyFixture.game(GEN)


func _thin() -> Game:
	var g := FogFixture.duel_thin()
	g.player = VIEWER
	return g


## The map-to-screen transform of a view of hexes `hex_px` wide, its middle on the map point `at` (the map's middle).
func _view(g: Game, hex_px: float, at: Vector2 = Vector2.INF) -> Transform2D:
	var zoom := hex_px / MapTiles.CELL.x
	var mid := at
	if mid == Vector2.INF:
		mid = Vector2(g.map.cols * MapTiles.CELL.x, g.map.rows * MapTiles.ROW) * 0.5
	return Transform2D(Vector2(zoom, 0.0), Vector2(0.0, zoom), SCREEN * 0.5 - mid * zoom)


func _labels(g: Game, node: ParchmentLabels = null) -> ParchmentLabels:
	var out := node if node != null else ParchmentLabels.new()
	add_child_autofree(out)
	out.setup(g)
	return out


func _show(labels: ParchmentLabels, g: Game, hex_px: float, at: Vector2 = Vector2.INF) -> Array[Dictionary]:
	labels.relayout(_view(g, hex_px, at), hex_px / MapTiles.CELL.x, SCREEN)
	return labels.placed()


func _of(items: Array[Dictionary], kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in items:
		if item["kind"] == kind:
			out.append(item)
	return out


func _named(items: Array[Dictionary], kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in _of(items, kind):
		if str(item["text"]) != "":
			out.append(item)
	return out


func _font(key: String) -> Font:
	return load(Tokens.FONTS[key]) as Font


## The width of a country name at `px` on its own: the font, the letters 0.08 em apart, and the halo.
func _name_width(text: String, px: int) -> float:
	var face := FontVariation.new()
	face.base_font = _font("alegreya_sc_bold")
	face.spacing_glyph = roundi(0.08 * px)
	return face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + ParchmentTokens.HALO_PX


## The placed entries whose middle lies outside the rect the renderer culls the labels by: those it can drop. The rect
## is read from the renderer itself (a debug call: it answers headless, and gives nothing in an exported game). That the
## pixels then reach the screen only a window shows (tools/ui/shot_ui_parchment.gd, group cull).
static func culled(labels: ParchmentLabels) -> Array[String]:
	var cull := RenderingServer.debug_canvas_item_get_rect(labels.get_canvas_item())
	var into := labels.draw_base()
	var out: Array[String] = []
	for item: Dictionary in labels.placed():
		if not cull.has_point(into * (item["rect"] as Rect2).get_center()):
			out.append("%s %s outside %s" % [item["kind"], item["hex"], cull])
	return out


func _good_with_districts(g: Game, viewer: StringName) -> int:
	var best := -1
	var most := 0
	for good: Dictionary in ParchmentView.goods_list(g):
		var n := ParchmentView.count_of(g, viewer, good["id"])
		if n > most:
			best = good["id"]
			most = n
	return best


## Whether the box meets what the entry `other` covers: its name or icon box (turned, for a country) and its dot.
func _meets(box: Rect2, other: Dictionary) -> bool:
	if other["kind"] == ParchmentLabels.KIND_COUNTRY:
		var axis := Vector2.from_angle(deg_to_rad(float(other["angle"])))
		return ParchmentLabelSpace.turned_hits(box, other["centre"], axis, (other["extent"] as Vector2) * 0.5)
	if other.has("dot"):
		var radius := float(other["dot_radius"])
		if box.intersects(Rect2(other["dot"], Vector2.ZERO).grow(radius)):
			return true
		return str(other["text"]) != "" and box.intersects(other["rect"])
	return box.intersects(other["rect"])


func _cover_rects() -> Array[Rect2]:
	return [Rect2(0.0, 0.0, 1920.0, 300.0), Rect2(960.0, 300.0, 120.0, 780.0)]
