## The route of an army on the map (docs/architecture/m6-build-spec.md 6.3; L16; z 84): the march's hexes as a polyline in
## Tokens.MAP_PATH over a thin ink line, the legs that end out of supply in MAP_PATH_WARN, a path_stop with the season's
## numeral at each stop and a crossing icon (bridge, ford, wade, pass) at each crossing. It draws what MovePreview.to says
## and only redraws on show_route and clear_route. A thin variant (show_route with thin) draws a stored route.
class_name PathMarks
extends Node2D

const LAYER_Z := 84
const LINE_WIDTH := 4.0
const INK_WIDTH := 7.0
const THIN_WIDTH := 2.0
const STOP_SIZE := 20.0
const CROSSING_ICON := 16.0
const NUMERAL_SIZE := 12
## The crossing kind of MovePreview's crossings -> the Kit icon that marks it (a ferry has the ford's mark).
const CROSSING_ICONS: Dictionary[StringName, StringName] = {
	&"bridge": &"bridge", &"ford": &"ford", &"ferry": &"ford", &"wade": &"wade", &"pass": &"pass_mark",
}

var _view: TileMapView = null
var _points: Array[Vector2] = []
var _warn: PackedByteArray = PackedByteArray()
var _stops: Array[Dictionary] = []  # {pos: Vector2}, the numeral is the index + 1
var _crossings: Array[Dictionary] = []  # {pos: Vector2, icon: Texture2D}
var _thin := false


func _init() -> void:
	z_index = LAYER_Z


## Takes the tile view whose cells the route is drawn over (its centres are the route's points).
func setup(view: TileMapView) -> void:
	_view = view


## Draws MovePreview's preview of a march: {hexes, stops ([{hex}]), crossings ([{hex, to, kind}]), beyond} where `beyond`
## is one byte a hex, 1 when the hex is out of supply. `thin` draws the stored route of a march in progress: the line only.
func show_route(preview: Dictionary, thin: bool = false) -> void:
	_thin = thin
	_points.clear()
	_warn = preview.get("beyond", PackedByteArray()) as PackedByteArray
	_stops.clear()
	_crossings.clear()
	var hexes: Array[Vector2i] = []
	hexes.assign(preview.get("hexes", []) as Array)
	if _view != null:
		for hex: Vector2i in hexes:
			_points.append(_view.centre_of(hex))
		if not thin:
			_read_stops(preview.get("stops", []) as Array)
			_read_crossings(preview.get("crossings", []) as Array)
	queue_redraw()


## Forgets the route and redraws nothing.
func clear_route() -> void:
	_points.clear()
	_stops.clear()
	_crossings.clear()
	_warn = PackedByteArray()
	queue_redraw()


## The hexes of the route as points (for tests and tools).
func points() -> Array[Vector2]:
	return _points.duplicate()


## The season stops and crossings drawn (for tests and tools): counts of each.
func stop_count() -> int:
	return _stops.size()


func crossing_count() -> int:
	return _crossings.size()


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


func _draw() -> void:
	if _points.size() < 2:
		return
	var font := ThemeDB.fallback_font
	if not _thin:
		for i: int in range(_points.size() - 1):
			draw_line(_points[i], _points[i + 1], Tokens.MAP_PATH_INK, INK_WIDTH)
	for i: int in range(_points.size() - 1):
		var beyond := _warn.size() > i + 1 and _warn[i + 1] == 1
		var colour := Tokens.MAP_PATH_WARN if beyond and not _thin else Tokens.MAP_PATH
		draw_line(_points[i], _points[i + 1], colour, THIN_WIDTH if _thin else LINE_WIDTH)
	for c: Dictionary in _crossings:
		var icon := c.icon as Texture2D
		if icon != null:
			draw_texture(icon, (c.pos as Vector2) - icon.get_size() * 0.5)
	for n: int in range(_stops.size()):
		var at := _stops[n].pos as Vector2
		var icon := _stops[n].icon as Texture2D
		if icon != null:
			draw_texture(icon, at - icon.get_size() * 0.5)
		if font != null:
			draw_string(font, at + Vector2(-STOP_SIZE * 0.5, NUMERAL_SIZE * 0.35), str(n + 1),
				HORIZONTAL_ALIGNMENT_CENTER, STOP_SIZE, NUMERAL_SIZE, Tokens.MAP_PATH_INK)
