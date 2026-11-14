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
const SHELF := Color("#8fb8cc")
const DEEP := Color("#4f7189")
const LAKE := Color("#7fa9c2")
const RIVER := Color("#3d6f94")
const STREAM := Color("#5d8fb0")
const BEACH := Color("#e8d9a8")
const CLIFF := Color("#5a4a3a")
const ROAD_TRACK := Color("#8c6d4f")
const ROAD_ROAD := Color("#d2b178")
const ROAD_HIGHWAY := Color("#f2ead6")
const ROAD_CASING := Color("#3b3026")
const BRIDGE := Color("#5a4632")
const FORD := Color("#eef6fb")
const QUAY := Color("#1f3f5c")
const CASTLE_INK := Color("#2b2622")
## Soft ground colours of the covers (WorldCover order: farmland, grassland, woods, marsh, rock, snow, tundra, sand).
## The soft band at each hex edge, as a share of the hex radius (the owner's v2: 20 to 25 per cent).
const BLEND_BAND := 0.22
const COVER_COLOURS: Array[Color] = [
	Color("#c9c27e"),
	Color("#a9c27a"),
	Color("#5f8c55"),
	Color("#8ea58a"),
	Color("#a39c93"),
	Color("#f1f4f6"),
	Color("#bdbfa8"),
	Color("#e6d5a3"),
]

var grid: WorldGrid
var region: WorldRegion
var relief: WorldRelief
var water: WorldWater = null
var cover: WorldCover = null
var places: WorldPlaces = null
var roads: WorldRoads = null
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


## Adds the water (rivers, lakes, shores, sea depth, streams) to the picture.
func show_water(p_water: WorldWater) -> void:
	water = p_water
	queue_redraw()


## Shows the ground cover: soft colours that blend across the hex edges, shaded by the relief. The water and the crests
## are drawn on top, as before.
func show_cover(p_cover: WorldCover) -> void:
	cover = p_cover
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
	if cover != null:
		_draw_cover_hexes()
	else:
		_draw_hexes()
	if water != null:
		_draw_water_bodies()
	_draw_crests()
	_draw_passes()
	if water != null:
		_draw_shores()
		_draw_streams()
		_draw_rivers()
	if roads != null:
		_draw_roads()
		_draw_crossings()
	if places != null:
		_draw_settlements()
	else:
		_draw_places()
	_draw_legend()
	if roads != null:
		_draw_network_legend()


func _draw_hexes() -> void:
	for hex: Vector2i in relief.levels.keys():
		var corners := grid.corners_km(hex)
		var pts := PackedVector2Array()
		for corner: Vector2 in corners:
			pts.append(km_to_px(corner))
		draw_colored_polygon(pts, _hex_colour(hex))
		pts.append(pts[0])
		draw_polyline(pts, HEX_LINE, 1.0)


## Each hex is a polygon whose six corners carry the mean colour of the three hexes that meet there, so the colour runs
## across every edge from one hex to the next without a seam. Land keeps its cover colour times its relief shade.
func _draw_cover_hexes() -> void:
	for hex: Vector2i in relief.levels.keys():
		var corners := grid.corners_km(hex)
		var centre := grid.centre_km(hex)
		var own := _cover_hex_colour(hex)
		# The flat middle of the hex is its own colour; a band of BLEND_BAND of the radius at each edge fades into the
		# mean colour of the three hexes meeting at each corner, so the hex still reads as a hex.
		var inner := PackedVector2Array()
		for k: int in 6:
			inner.append(km_to_px(centre + (corners[k] - centre) * (1.0 - BLEND_BAND)))
		draw_colored_polygon(inner, own)
		for k: int in 6:
			var k2 := (k + 1) % 6
			var pts := PackedVector2Array([km_to_px(corners[k]), km_to_px(corners[k2]), inner[k2], inner[k]])
			var cols := PackedColorArray([_corner_colour(hex, k), _corner_colour(hex, k2), own, own])
			draw_polygon(pts, cols)


## The mean colour of the hexes at corner k of a hex: the hex itself and the two neighbours whose edges meet there.
func _corner_colour(hex: Vector2i, k: int) -> Color:
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var count := 0
	var hexes: Array[Vector2i] = [hex]
	for d: int in 6:
		var pair := WorldGrid.EDGE_CORNERS[d]
		if pair.x == k or pair.y == k:
			hexes.append(grid.neighbour(hex, d))
	for h: Vector2i in hexes:
		if h != hex and not relief.levels.has(h):
			continue
		var c := _cover_hex_colour(h)
		r += c.r
		g += c.g
		b += c.b
		count += 1
	return Color(r / float(count), g / float(count), b / float(count))


func _cover_hex_colour(hex: Vector2i) -> Color:
	var c := cover.cover_at(hex)
	if relief.level_at(hex) == ReliefLevels.SEA or c < 0:
		return _hex_colour(hex)
	var base := COVER_COLOURS[c]
	var f := 1.0 + float(cover.shade.get(hex, 0.0))
	return Color(clampf(base.r * f, 0.0, 1.0), clampf(base.g * f, 0.0, 1.0), clampf(base.b * f, 0.0, 1.0))


func _hex_colour(hex: Vector2i) -> Color:
	var level := relief.level_at(hex)
	if level != ReliefLevels.SEA or water == null:
		return LEVEL_COLOURS[level]
	if water.lake_hex.has(hex):
		return LAKE
	match str(water.sea_band.get(hex, "")):
		"shelf":
			return SHELF
		"deep":
			return DEEP
		_:
			return LEVEL_COLOURS[ReliefLevels.SEA]


## The lakes are drawn from the routed chains of the core (the same edges the core uses), as ribbons of their width.
func _draw_water_bodies() -> void:
	for i: int in water.lakes.size():
		var lk: Dictionary = region.lakes[i]
		var pts := water.lake_points_km(i)
		if pts.size() < 2:
			continue
		var px := PackedVector2Array()
		for km: Vector2 in pts:
			px.append(km_to_px(km))
		var pins: Array[bool] = []
		for k: int in px.size():
			pins.append(k == 0 or k == px.size() - 1)
		draw_polyline(_chaikin(px, pins, 3), LAKE, maxf(3.0, float(lk["width_km"]) * px_per_km * 0.8), true)


func _draw_shores() -> void:
	for e: Vector4i in water.shore_edge.keys():
		var pair := WorldGrid.edge_hexes(e)
		var seg := grid.edge_segment_km(pair[0], pair[1])
		var kind: String = water.shore_edge[e]
		if kind == "lake":
			continue
		draw_line(km_to_px(seg[0]), km_to_px(seg[1]), BEACH if kind == "beach" else CLIFF, 3.0)


func _draw_streams() -> void:
	for e: Vector4i in water.stream_edge.keys():
		var pair := WorldGrid.edge_hexes(e)
		var seg := grid.edge_segment_km(pair[0], pair[1])
		draw_line(km_to_px(seg[0]), km_to_px(seg[1]), STREAM, 1.5)


## Each river: its edge midpoints, cut into a smooth curve (Chaikin) that keeps the pinned points (the source, the mouth
## and each river city's crossing), and wider downstream: from the class width at the source to a wider mouth.
func _draw_rivers() -> void:
	for i: int in water.rivers.size():
		var rv: Dictionary = water.rivers[i]
		var px := PackedVector2Array()
		for km: Vector2 in water.river_points_km(i):
			px.append(km_to_px(km))
		var curve := _chaikin(px, water.river_pins(i), 3)
		var klass := float(int(rv["class"]))
		var w_source := 1.0 + 0.6 * klass
		var w_mouth := 2.0 + 1.6 * klass
		var chunks := 6
		var n := curve.size()
		for c: int in chunks:
			var from := floori(float((n - 1) * c) / float(chunks))
			var to := mini(floori(float((n - 1) * (c + 1)) / float(chunks)) + 1, n)
			var part := curve.slice(from, to)
			if part.size() < 2:
				continue
			var t := (float(c) + 0.5) / float(chunks)
			draw_polyline(part, RIVER, lerpf(w_source, w_mouth, t), true)


## Chaikin corner cutting, a few rounds, for an open line. A point flagged in pins keeps its place (the ends and the river
## city crossings), so the curve passes through the points that a crossing or a bridge pins.
static func _chaikin(points: PackedVector2Array, pins: Array[bool], rounds: int) -> PackedVector2Array:
	var pts := points
	var flags: Array[bool] = pins.duplicate()
	for r: int in rounds:
		var out := PackedVector2Array()
		var out_flags: Array[bool] = []
		var n := pts.size()
		if n < 3:
			break
		for i: int in n - 1:
			var a := pts[i]
			var b := pts[i + 1]
			if flags[i]:
				out.append(a)
				out_flags.append(true)
			else:
				out.append(a * 0.75 + b * 0.25)
				out_flags.append(false)
			if not flags[i + 1]:
				out.append(a * 0.25 + b * 0.75)
				out_flags.append(false)
		out.append(pts[n - 1])
		out_flags.append(true)
		pts = out
		flags = out_flags
	return pts


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
	var rows := COVER_COLOURS.size() if cover != null else ReliefLevels.NAMES.size()
	var box := 68.0 + float(rows) * 18.0
	var top := size.y - box - 8.0
	draw_rect(Rect2(8.0, top, 262.0, box), PANEL)
	for row: int in rows:
		var y := top + 12.0 + float(row) * 18.0
		if cover != null:
			draw_rect(Rect2(16.0, y, 14.0, 14.0), COVER_COLOURS[row])
			draw_string(font, Vector2(36.0, y + 12.0), WorldCover.NAMES[row], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
		else:
			draw_rect(Rect2(16.0, y, 14.0, 14.0), LEVEL_COLOURS[row])
			draw_string(font, Vector2(36.0, y + 12.0), ReliefLevels.name_of(row), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
	var crest_y := top + 12.0 + float(rows) * 18.0 + 10.0
	draw_line(Vector2(16.0, crest_y), Vector2(30.0, crest_y), INK, CREST_PX)
	draw_string(font, Vector2(36.0, crest_y + 4.0), "crest (spine at crest height)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
	draw_line(Vector2(16.0, crest_y + 20.0), Vector2(30.0, crest_y + 20.0), GOLD, PASS_PX)
	draw_string(font, Vector2(36.0, crest_y + 24.0), "pass edge; gold dot = saddle hex", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)


## Shows the settlements and the roads (step 5 of the prototype) over the picture: the places by level, the roads by quality,
## the crossings of the rivers, streams and lakes, and the quays.
func show_network(p_places: WorldPlaces, p_roads: WorldRoads) -> void:
	places = p_places
	roads = p_roads
	queue_redraw()


## Each link is drawn as smooth lines through the hex centres, split where its road quality changes: highways with a dark
## casing, roads tan, tracks thin brown. Each run is pinned at its two ends, so the runs join without a gap.
func _draw_roads() -> void:
	for ln: Dictionary in roads.links:
		var path: Array = ln["path"]
		var n := path.size()
		if n < 2:
			continue
		var hexes: Array[Vector2i] = []
		for item: Variant in path:
			var h: Vector2i = item
			hexes.append(h)
		var centres := PackedVector2Array()
		for h: Vector2i in hexes:
			centres.append(km_to_px(grid.centre_km(h)))
		var i := 0
		while i < n - 1:
			var q := roads.quality_of(WorldGrid.edge_key(hexes[i], hexes[i + 1]))
			var j := i
			while j + 1 < n - 1 and roads.quality_of(WorldGrid.edge_key(hexes[j + 1], hexes[j + 2])) == q:
				j += 1
			var run := centres.slice(i, j + 2)
			var pins: Array[bool] = []
			for k: int in run.size():
				pins.append(k == 0 or k == run.size() - 1)
			_draw_road_run(_chaikin(run, pins, 3), q)
			i = j + 1


func _draw_road_run(curve: PackedVector2Array, q: int) -> void:
	if q >= 3:
		draw_polyline(curve, ROAD_CASING, 5.0, true)
		draw_polyline(curve, ROAD_HIGHWAY, 3.0, true)
	elif q == 2:
		draw_polyline(curve, ROAD_ROAD, 2.6, true)
	else:
		draw_polyline(curve, ROAD_TRACK, 1.6, true)


## The crossings: a bridge is drawn over its river edge (stone pale, wood brown), a ford is a dashed line on the edge, a ferry
## a round badge at the edge middle. Quays are a blue bar on their shore or lake edge.
func _draw_crossings() -> void:
	for e: Vector4i in roads.quality.keys():
		var kind := roads.crossing_of(e)
		if kind == "none" or kind == "pass":
			continue
		var pair := WorldGrid.edge_hexes(e)
		var seg := grid.edge_segment_km(pair[0], pair[1])
		var a := km_to_px(seg[0])
		var b := km_to_px(seg[1])
		match kind:
			"bridge_stone":
				draw_line(a, b, ROAD_CASING, 6.0)
				draw_line(a, b, ROAD_HIGHWAY, 3.5)
			"bridge_wood":
				draw_line(a, b, ROAD_CASING, 6.0)
				draw_line(a, b, BRIDGE, 3.5)
			"ford":
				draw_dashed_line(a, b, FORD, 2.5, 4.0)
			"ferry":
				var mid := (a + b) / 2.0
				draw_circle(mid, 4.5, QUAY)
				draw_circle(mid, 4.5, FORD, false, 1.5)
	for e: Vector4i in places.quay_edges.keys():
		var pair := WorldGrid.edge_hexes(e)
		var seg := grid.edge_segment_km(pair[0], pair[1])
		draw_line(km_to_px(seg[0]), km_to_px(seg[1]), QUAY, 3.0)


## Settlements as markers by level (hamlet dot, village ring dot, town square, city square, great city square with a ring),
## a gold ring for the capital, a small tower for a castle. Landmarks: a gold diamond for a hospice on its saddle, a cross for a
## monastery. The names (WorldLabels) come from the town level up, more of them as the view zooms in, and a name that would
## collide with a marker, a panel or another name is moved to another spot or dropped.
func _draw_settlements() -> void:
	var font := ThemeDB.fallback_font
	var reach := Rect2(Vector2.ZERO, size).grow(40.0)
	var boxes: Array[Rect2] = []  # the boxes the names keep off: every marker in reach, and the panels
	var names: Array[Dictionary] = []
	for pl: Dictionary in places.places:
		var hex: Vector2i = pl["hex"]
		var at := km_to_px(grid.centre_km(hex))
		if not reach.has_point(at):
			continue
		var level := int(pl["level"])
		var capital := bool(pl["capital"])
		var half := _marker_half(level, capital)
		boxes.append(Rect2(at - Vector2(half, half), Vector2(2.0 * half, 2.0 * half)))
		var label := str(pl["name"])
		if label != "" and _label_tier(level):
			var fs := 14 if level >= 4 else 12
			names.append({"name": label, "at": at, "width": font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x,
				"size": float(fs), "rank": level * 10 + (5 if capital else 0), "half": half})
		match level:
			1:
				draw_circle(at, 2.2, TEXT)
			2:
				draw_circle(at, 3.8, Color("#fbf7ee"))
				draw_circle(at, 3.8, INK, false, 1.2)
			3:
				_draw_square(at, 5.0)
			4:
				_draw_square(at, 7.0)
			_:
				_draw_square(at, 9.0)
		if level >= 5 or capital:
			draw_arc(at, 12.0, 0.0, TAU, 32, GOLD, 2.0, true)
		if int(pl["castle"]) > 0:
			draw_rect(Rect2(at + Vector2(7.0, -13.0), Vector2(6.0, 7.0)), CASTLE_INK)
	for lm: Dictionary in places.landmarks:
		var lh: Vector2i = lm["hex"]
		var at := km_to_px(grid.centre_km(lh))
		if not reach.has_point(at):
			continue
		boxes.append(Rect2(at - Vector2(7.0, 7.0), Vector2(14.0, 14.0)))
		if str(lm["kind"]) == "hospice":
			var diamond := PackedVector2Array([at + Vector2(0.0, -6.0), at + Vector2(6.0, 0.0),
				at + Vector2(0.0, 6.0), at + Vector2(-6.0, 0.0)])
			draw_colored_polygon(diamond, GOLD)
			draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), INK, 1.2)
		else:
			draw_line(at + Vector2(-4.0, 0.0), at + Vector2(4.0, 0.0), INK, 1.5)
			draw_line(at + Vector2(0.0, -4.0), at + Vector2(0.0, 4.0), INK, 1.5)
	boxes.append_array(_panel_boxes())
	var bounds := Rect2(0.0, MARGIN_TOP, size.x, size.y - MARGIN_TOP)
	for item: Dictionary in WorldLabels.place(names, boxes, bounds):
		var box: Rect2 = item["box"]
		draw_string(font, box.position + Vector2(0.0, float(item["size"]) + 1.0), str(item["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(item["size"]), TEXT)


## The half size of a settlement's marker on the map (the ring of the great city and the capital is the largest).
func _marker_half(level: int, capital: bool) -> float:
	if level >= 5 or capital:
		return 12.0
	match level:
		1:
			return 3.0
		2:
			return 5.0
		3:
			return 6.0
	return 8.0


## The names shown at a level and zoom: the great cities, cities and capitals always; towns from a zoom of 1 pixel per km;
## villages from 3 pixels per km.
func _label_tier(level: int) -> bool:
	if level >= 4:
		return true
	if level == 3:
		return px_per_km >= 1.0
	return level == 2 and px_per_km >= 3.0


## The boxes of the panels drawn over the map: the title bar is outside the names' bounds; the cover legend (bottom left) and
## the network legend (top right) are kept clear.
func _panel_boxes() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if cover != null:
		var rows := COVER_COLOURS.size()
		var box := 68.0 + float(rows) * 18.0
		out.append(Rect2(8.0, size.y - box - 16.0, 262.0, box + 8.0))
	if roads != null:
		out.append(Rect2(size.x - 258.0, MARGIN_TOP + 8.0, 250.0, 278.0))
	return out


func _draw_square(at: Vector2, r: float) -> void:
	draw_rect(Rect2(at - Vector2(r, r), Vector2(2.0 * r, 2.0 * r)), Color("#fbf7ee"))
	draw_rect(Rect2(at - Vector2(r, r), Vector2(2.0 * r, 2.0 * r)), INK, false, 1.5)
	draw_rect(Rect2(at - Vector2(r - 2.0, r - 2.0), Vector2(2.0 * r - 4.0, 2.0 * r - 4.0)), TEXT)


func _draw_network_legend() -> void:
	var font := ThemeDB.fallback_font
	var w := 250.0
	var x := size.x - w - 8.0
	var y := MARGIN_TOP + 8.0
	var lines: Array[String] = ["Highway (quality 3)", "Road (quality 2)", "Track (quality 1)", "Stone bridge",
		"Wooden bridge", "Ford", "Ferry", "Pass (gold edge)", "Quay"]
	var marks: Array[String] = ["Great city", "City", "Town", "Village", "Hamlet", "Capital"]
	var height := 30.0 + float(lines.size() + marks.size()) * 16.0 + 8.0
	draw_rect(Rect2(x, y, w, height), PANEL)
	draw_string(font, Vector2(x + 10.0, y + 16.0), "Roads and places", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
	for i: int in lines.size():
		var ly := y + 30.0 + float(i) * 16.0
		var x0 := x + 12.0
		var x1 := x + 44.0
		match i:
			0:
				draw_line(Vector2(x0, ly), Vector2(x1, ly), ROAD_CASING, 5.0)
				draw_line(Vector2(x0, ly), Vector2(x1, ly), ROAD_HIGHWAY, 3.0)
			1:
				draw_line(Vector2(x0, ly), Vector2(x1, ly), ROAD_ROAD, 2.6)
			2:
				draw_line(Vector2(x0, ly), Vector2(x1, ly), ROAD_TRACK, 1.6)
			3:
				draw_line(Vector2(x0, ly), Vector2(x1, ly), ROAD_CASING, 6.0)
				draw_line(Vector2(x0, ly), Vector2(x1, ly), ROAD_HIGHWAY, 3.5)
			4:
				draw_line(Vector2(x0, ly), Vector2(x1, ly), ROAD_CASING, 6.0)
				draw_line(Vector2(x0, ly), Vector2(x1, ly), BRIDGE, 3.5)
			5:
				draw_dashed_line(Vector2(x0, ly), Vector2(x1, ly), TEXT, 2.5, 4.0)
			6:
				draw_circle(Vector2((x0 + x1) / 2.0, ly), 4.5, QUAY)
			7:
				draw_line(Vector2(x0, ly), Vector2(x1, ly), GOLD, PASS_PX)
			8:
				draw_line(Vector2(x0, ly), Vector2(x1, ly), QUAY, 3.0)
		draw_string(font, Vector2(x + 56.0, ly + 4.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)
	var base := y + 30.0 + float(lines.size()) * 16.0
	for i: int in marks.size():
		var my := base + float(i) * 16.0
		var mx := x + 28.0
		match i:
			0:
				_draw_square(Vector2(mx, my), 9.0)
			1:
				_draw_square(Vector2(mx, my), 7.0)
			2:
				_draw_square(Vector2(mx, my), 5.0)
			3:
				draw_circle(Vector2(mx, my), 3.8, Color("#fbf7ee"))
				draw_circle(Vector2(mx, my), 3.8, INK, false, 1.2)
			4:
				draw_circle(Vector2(mx, my), 2.2, TEXT)
			_:
				draw_arc(Vector2(mx, my), 6.0, 0.0, TAU, 16, GOLD, 2.0, true)
		draw_string(font, Vector2(x + 56.0, my + 4.0), marks[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)


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
