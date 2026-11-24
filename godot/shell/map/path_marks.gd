## The route of an army on the map (docs/architecture/m6-build-spec.md 6.3; L16; z 84): the army's own hex and the march's hexes as a
## smooth curve through their centres (PathCurve), drawn in one of three looks (PathLooks: ribbon, dashes, footprints; the setting
## map/path_look). The legs that end out of supply are in MAP_PATH_WARN; a path_stop with the season's numeral at each stop and a
## crossing icon (bridge, ford, wade, pass) at each crossing. It draws what MovePreview.to says and only redraws on show_route,
## clear_route, set_look and set_zoom. A thin variant (show_route with thin) draws a stored route: the line only, in every look.
## The route's start is the army's own hex: the preview's `from` (MapArmies adds it); without one the route starts at its first hex.
class_name PathMarks
extends Node2D

const LAYER_Z := 84
const STOP_SIZE := 20.0
const CROSSING_ICON := 16.0
const NUMERAL_SIZE := 12
const NO_HEX := Vector2i(-9999, -9999)
const LOOK_RIBBON := &"ribbon"
const LOOK_DASHES := &"dashed"
const LOOK_FOOTPRINTS := &"footprints"
const LOOKS: Array[StringName] = [LOOK_RIBBON, LOOK_DASHES, LOOK_FOOTPRINTS]
## The crossing kind of MovePreview's crossings -> the Kit icon that marks it (a ferry has the ford's mark).
const CROSSING_ICONS: Dictionary[StringName, StringName] = {
	&"bridge": &"bridge", &"ford": &"ford", &"ferry": &"ford", &"wade": &"wade", &"pass": &"pass_mark",
}

var _view: TileMapView = null
var _points: Array[Vector2] = []
var _warn: PackedByteArray = PackedByteArray()  # one byte a point: 1 when the leg into it is out of supply
var _stops: Array[Dictionary] = []  # {pos: Vector2, icon: Texture2D}, the numeral is the index + 1
var _crossings: Array[Dictionary] = []  # {pos: Vector2, icon: Texture2D}
var _curve: Dictionary = {}
var _colours := PackedColorArray()
var _thin := false
var _look: StringName = LOOK_RIBBON
var _zoom := 1.0


func _init() -> void:
	z_index = LAYER_Z


## Takes the tile view whose cells the route is drawn over (its centres are the route's points).
func setup(view: TileMapView) -> void:
	_view = view


## Draws MovePreview's preview of a march: {hexes, stops ([{hex}]), crossings ([{hex, to, kind}]), beyond, from} where `beyond` is
## one byte a hex, 1 when the hex is out of supply, and `from` is the army's own hex (the route's first point). `thin` draws the
## stored route of a march in progress: the line only.
func show_route(preview: Dictionary, thin: bool = false) -> void:
	_thin = thin
	_points.clear()
	_warn = PackedByteArray()
	_stops.clear()
	_crossings.clear()
	var hexes: Array[Vector2i] = []
	hexes.assign(preview.get("hexes", []) as Array)
	if _view != null and not hexes.is_empty():
		var beyond := preview.get("beyond", PackedByteArray()) as PackedByteArray
		var from := preview.get("from", NO_HEX) as Vector2i
		if from != NO_HEX and from != hexes[0]:
			_add_point(from, 0)
		for i: int in hexes.size():
			_add_point(hexes[i], beyond[i] if i < beyond.size() else 0)
		if not thin:
			_read_stops(preview.get("stops", []) as Array)
			_read_crossings(preview.get("crossings", []) as Array)
	_rebuild()


## Forgets the route and redraws nothing.
func clear_route() -> void:
	_points.clear()
	_stops.clear()
	_crossings.clear()
	_warn = PackedByteArray()
	_rebuild()


## Chooses the look (one of LOOKS; any other name is ignored) and redraws.
func set_look(look: StringName) -> void:
	if not LOOKS.has(look) or look == _look:
		return
	_look = look
	queue_redraw()


func look() -> StringName:
	return _look


## The map's zoom: the line keeps its screen width and the markers their screen size (tokens' rule), so it redraws on a change.
func set_zoom(zoom: float) -> void:
	if zoom <= 0.0 or is_equal_approx(zoom, _zoom):
		return
	_zoom = zoom
	queue_redraw()


## The hexes of the route as points, the army's own hex first (for tests and tools).
func points() -> Array[Vector2]:
	return _points.duplicate()


## The season stops and crossings drawn (for tests and tools): counts of each.
func stop_count() -> int:
	return _stops.size()


func crossing_count() -> int:
	return _crossings.size()


func _add_point(hex: Vector2i, warn: int) -> void:
	_points.append(_view.centre_of(hex))
	_warn.append(warn)


func _read_stops(stops: Array) -> void:
	for item: Variant in stops:
		var s := item as Dictionary
		if _view != null and s.has("hex"):
			_stops.append({"pos": _view.centre_of(s.hex as Vector2i), "icon": ArmyToken.kit_icon(&"path_stop", self)})


func _read_crossings(crossings: Array) -> void:
	for item: Variant in crossings:
		var c := item as Dictionary
		if _view == null or not c.has("hex") or not c.has("to"):
			continue
		var mid := (_view.centre_of(c.hex as Vector2i) + _view.centre_of(c.to as Vector2i)) * 0.5
		var icon := ArmyToken.kit_icon(CROSSING_ICONS.get(StringName(c.get("kind", &"")), &"ford") as StringName, self)
		_crossings.append({"pos": mid, "icon": icon})


## The curve and the leg colours from the points and the warnings; then a redraw.
func _rebuild() -> void:
	_curve = {}
	_colours = PackedColorArray()
	if _points.size() >= 2:
		_curve = PathCurve.build(PackedVector2Array(_points))
		for i: int in range(_points.size() - 1):
			var beyond := not _thin and _warn[i + 1] == 1
			_colours.append(Tokens.MAP_PATH_WARN if beyond else Tokens.MAP_PATH)
	queue_redraw()


func _draw() -> void:
	if _curve.is_empty():
		return
	var px := 1.0 / _zoom  # map units of one screen pixel
	var mark := maxf(1.0, 0.6 / _zoom)  # the markers' scale, as the army tokens'
	if _thin:
		PathLooks.legs(self, _curve, _colours, PathLooks.THIN_WIDTH * px)
	elif _look == LOOK_DASHES:
		PathLooks.dashed(self, _curve, _colours, px)
	elif _look == LOOK_FOOTPRINTS:
		PathLooks.footprints(self, _curve, _colours, px)
	else:
		PathLooks.ribbon(self, _curve, _colours, px)
	_draw_markers(px, mark)


func _draw_markers(px: float, mark: float) -> void:
	var font := ThemeDB.fallback_font
	for c: Dictionary in _crossings:
		var icon := c.icon as Texture2D
		if icon != null:
			var size := icon.get_size() * mark
			draw_texture_rect(icon, Rect2((c.pos as Vector2) - size * 0.5, size), false)
	var dots := not _thin and _look == LOOK_RIBBON
	for n: int in range(_stops.size()):
		var at := _stops[n].pos as Vector2
		var icon := _stops[n].icon as Texture2D
		if dots:
			PathLooks.dot(self, at, PathLooks.DOT_RADIUS * mark, Tokens.MAP_PATH)
		elif icon != null:
			var size := icon.get_size() * mark
			draw_texture_rect(icon, Rect2(at - size * 0.5, size), false)
		if font != null:
			var size_text := roundi(NUMERAL_SIZE * mark)
			draw_string(font, at + Vector2(-STOP_SIZE * mark * 0.5, size_text * 0.35), str(n + 1),
				HORIZONTAL_ALIGNMENT_CENTER, STOP_SIZE * mark, size_text, Tokens.MAP_PATH_INK)
