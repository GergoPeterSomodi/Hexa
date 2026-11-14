## The map prototype's viewer, step 2 (docs/design/map/README.md section 8): the region's hexes in flat colours by relief
## level, crest chains as dark lines on the edges, pass edges and saddles in gold, and the names of places and passes.
## Mouse wheel zooms about the pointer, dragging pans. Shell only: it draws what core/worldmap computed.
class_name WorldMapView
extends Control

const LEVEL_COLOURS: Array[Color] = [
	Color("#6f93ab"),  # 0 sea
	Color("#b3c98b"),  # 1 lowland
	Color("#d3d89b"),  # 2 plain
	Color("#c3b47f"),  # 3 hills
	Color("#a68d62"),  # 4 highland
	Color("#8c8479"),  # 5 mountains
	Color("#eef1f3"),  # 6 high peaks
]
const INK := Color("#2b2622")
const HEX_LINE := Color(0.0, 0.0, 0.0, 0.16)
const GOLD := Color("#d9a441")
const TEXT := Color("#1f1b17")
const PANEL := Color(0.97, 0.96, 0.93, 0.9)
const MARGIN_TOP := 36.0  # the title bar: the map is fitted below it
const CREST_PX := 3.0
const PASS_PX := 4.5
const ZOOM_MIN := 0.6
const ZOOM_MAX := 40.0

var grid: WorldGrid
var region: WorldRegion
var relief: WorldRelief
var centre_km: Vector2 = Vector2.ZERO
var px_per_km: float = 2.0
var title: String = "Alps and Po: relief on 28 km hexes"
var _dragging := false
var _fit_pending := false


## Shows a region's relief and sets the view to the whole region.
func show_region(p_grid: WorldGrid, p_region: WorldRegion, p_relief: WorldRelief) -> void:
	grid = p_grid
	region = p_region
	relief = p_relief
	_fit_pending = true
	queue_redraw()


## The whole region in the viewer (on the next draw, once the control has its size).
func fit_view() -> void:
	_fit_pending = true
	queue_redraw()


func _apply_fit() -> void:
	var width := (region.lon_east - region.lon_west) * grid.deg_km * cos(deg_to_rad(grid.ref_lat))
	var height := (region.lat_north - region.lat_south) * grid.deg_km
	px_per_km = minf(size.x / width, (size.y - MARGIN_TOP) / height) * 0.96
	# The map sits in the space below the title bar: its centre is half the bar lower than the control's centre.
	centre_km = Vector2(width / 2.0, height / 2.0 - MARGIN_TOP / 2.0 / px_per_km)


## A view centred on a longitude and latitude at a scale in pixels per kilometre.
func set_view(lon: float, lat: float, p_px_per_km: float) -> void:
	centre_km = grid.km_of(lon, lat)
	px_per_km = clampf(p_px_per_km, ZOOM_MIN, ZOOM_MAX)
	queue_redraw()


func km_to_px(km: Vector2) -> Vector2:
	return (km - centre_km) * px_per_km + size / 2.0


func px_to_km(px: Vector2) -> Vector2:
	return (px - size / 2.0) / px_per_km + centre_km


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), LEVEL_COLOURS[0])
	if grid == null:
		return
	if _fit_pending and size.x > 0.0 and size.y > 0.0:
		_apply_fit()
		_fit_pending = false
	_draw_hexes()
	_draw_crests()
	_draw_passes()
	_draw_places()
	_draw_legend()


func _draw_hexes() -> void:
	for hex: Vector2i in relief.levels.keys():
		var corners := grid.corners_km(hex)
		var pts := PackedVector2Array()
		for corner: Vector2 in corners:
			pts.append(km_to_px(corner))
		draw_colored_polygon(pts, LEVEL_COLOURS[relief.level_at(hex)])
		pts.append(pts[0])
		draw_polyline(pts, HEX_LINE, 1.0)


func _draw_crests() -> void:
	for key: Vector4i in relief.crest_edges.keys():
		if relief.pass_edges.has(key):
			continue
		var pair := WorldGrid.edge_hexes(key)
		var seg := grid.edge_segment_km(pair[0], pair[1])
		draw_line(km_to_px(seg[0]), km_to_px(seg[1]), INK, CREST_PX)


func _draw_passes() -> void:
	for key: Vector4i in relief.pass_edges.keys():
		var pair := WorldGrid.edge_hexes(key)
		var seg := grid.edge_segment_km(pair[0], pair[1])
		draw_line(km_to_px(seg[0]), km_to_px(seg[1]), GOLD, PASS_PX)
	for p: int in relief.pass_hex.keys():
		if not relief.pass_has_crest[p]:
			continue
		var at := km_to_px(grid.centre_km(relief.pass_hex[p]))
		draw_circle(at, 5.0, GOLD)
		draw_circle(at, 5.0, INK, false, 1.5)


func _draw_places() -> void:
	var font := ThemeDB.fallback_font
	for pl: Dictionary in region.places:
		var kind: String = pl["kind"]
		var is_city := kind == "city"
		if not is_city and px_per_km < 3.0:
			continue
		var pl_pos: Vector2 = pl["pos"]
		var at := km_to_px(grid.km_of(pl_pos.x, pl_pos.y))
		if not Rect2(Vector2.ZERO, size).grow(40.0).has_point(at):
			continue
		draw_circle(at, 3.5 if is_city else 2.5, TEXT)
		draw_string(font, at + Vector2(6.0, -4.0), str(pl["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14 if is_city else 12, TEXT)
	if px_per_km < 2.0:
		return
	for ps: Dictionary in region.passes:
		var ps_pos: Vector2 = ps["pos"]
		var at := km_to_px(grid.km_of(ps_pos.x, ps_pos.y))
		if not Rect2(Vector2.ZERO, size).grow(40.0).has_point(at):
			continue
		draw_string(font, at + Vector2(6.0, 12.0), str(ps["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD.darkened(0.35))


func _draw_legend() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0.0, 0.0, size.x, MARGIN_TOP), PANEL)
	draw_string(font, Vector2(12.0, 24.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT)
	var top := size.y - 212.0
	draw_rect(Rect2(8.0, top, 262.0, 204.0), PANEL)
	for level: int in ReliefLevels.NAMES.size():
		var y := top + 12.0 + float(level) * 18.0
		draw_rect(Rect2(16.0, y, 14.0, 14.0), LEVEL_COLOURS[level])
		draw_string(font, Vector2(36.0, y + 12.0), ReliefLevels.name_of(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
	var crest_y := top + 12.0 + 7.0 * 18.0 + 10.0
	draw_line(Vector2(16.0, crest_y), Vector2(30.0, crest_y), INK, CREST_PX)
	draw_string(font, Vector2(36.0, crest_y + 4.0), "crest (spine at crest height)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
	draw_line(Vector2(16.0, crest_y + 20.0), Vector2(30.0, crest_y + 20.0), GOLD, PASS_PX)
	draw_string(font, Vector2(36.0, crest_y + 24.0), "pass edge; gold dot = saddle hex", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)


func _gui_input(event: InputEvent) -> void:
	if grid == null:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom_at(button.position, 1.25)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom_at(button.position, 0.8)
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		centre_km -= motion.relative / px_per_km
		queue_redraw()


func _zoom_at(at: Vector2, factor: float) -> void:
	var before := px_to_km(at)
	px_per_km = clampf(px_per_km * factor, ZOOM_MIN, ZOOM_MAX)
	centre_km += before - px_to_km(at)
	queue_redraw()
