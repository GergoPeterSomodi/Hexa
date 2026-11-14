## The odds of each terrain kind on a land hex, from what is known about the place: a port of terrain_prior in
## hexa/campaign/systems/worldgen.py, with the shape tests of hexa/campaign/geo.py (desert_at, steppe_at, maghreb_at,
## marsh_at, and the near_line distance to the mountain and hill lines).
class_name TerrainPrior
extends RefCounted

var _geo: Geo
var _data: EuropeData
var _deserts: Array[Geo.Shape] = []
var _steppes: Array[Geo.Shape] = []
var _maghreb: Array[Geo.Shape] = []


func _init(geo: Geo, data: EuropeData) -> void:
	_geo = geo
	_data = data
	_deserts = Geo.shapes_of(data.deserts)
	_steppes = Geo.shapes_of(data.steppes)
	_maghreb = Geo.shapes_of(data.maghreb)


## {terrain kind: weight} for a land hex; coastal: next to the ocean or a lake; river: a river runs through it.
func weights(pos: Vector2i, coastal: bool, river: bool) -> Dictionary:
	var ll := _geo.lonlat(pos)
	var lon := ll[0]
	var lat := ll[1]
	var mount := _near_line(lon, lat, _data.mountains, 2.0)
	if mount < 0.8:
		var snow := 0.35 if (lat > 45.5 or (lon < -30.0 and lat > 50.0)) else 0.0
		return {"mountains": 1.0, "snow": snow, "hills": 0.15}
	var hills := mount < 1.6 or _near_line(lon, lat, _data.hills, 1.0) < 1.0
	var desert := Geo.hit(lon, lat, _deserts)
	var marsh := _marsh_at(lon, lat)
	var americas := lon < -30.0
	var north_africa := Geo.hit(lon, lat, _maghreb)
	var hill_part := 0.04 if hills else 0.0
	if river:
		if desert:
			return {"plains": 1.0, "marsh": 0.08 + marsh}
		return {"plains": 1.0, "marsh": 0.15 + marsh, "forest": 0.15, "hills": 0.05}
	if desert:
		if -20.0 < lon and lon < 40.0 and 12.0 < lat and lat < 18.5:  # the Sahel: desert fades into steppe
			return {"desert": 0.55, "steppe": 0.3, "savanna": 0.3, "hills": hill_part}
		if north_africa and lat > 28.5:  # the northern edge of the Sahara
			return {"desert": 1.0, "steppe": 0.22, "hills": hill_part}
		return {"desert": 1.0, "steppe": 0.06, "hills": hill_part}
	if hills:
		if north_africa:
			return {"hills": 0.7, "steppe": 0.25, "forest": 0.03, "mountains": 0.08 if mount < 1.2 else 0.0}
		var w := {"hills": 0.7, "forest": 0.25, "mountains": 0.08 if mount < 1.2 else 0.0}
		if lat > 57.0:
			w["taiga"] = 0.3
		if lat < 17.0:
			w["jungle" if lat < 8.0 else "savanna"] = 0.2
		return w
	if americas:
		if lat >= 59.0:
			return {"tundra": 1.0, "snow": 0.35, "taiga": 0.1}
		if lat >= 55.0:
			return {"tundra": 0.6, "taiga": 0.6, "marsh": 0.05}
		if lat >= 47.0:
			return {"taiga": 0.5, "forest": 0.4, "plains": 0.12, "marsh": 0.06 + marsh}
		if lat < 21.5:
			if lon < -95.0 and lat > 16.5:
				return {"plains": 0.6, "hills": 0.3, "savanna": 0.1}
			var tropics := {
				"jungle": 0.6 if lat < 14.0 else 0.35,
				"plains": 0.15 if lat < 14.0 else 0.3,
				"savanna": 0.3 if (2.0 < lat and lat < 12.0 and lon > -72.0) else 0.1,
				"marsh": 0.04 + marsh,
			}
			if coastal:
				tropics["beach"] = 0.3
			return tropics
		var temperate := {"forest": 0.75 if lat > 40.0 else 0.5, "plains": 0.3 if lat > 40.0 else 0.45,
				"marsh": 0.04 + marsh}
		if coastal and lat < 36.0:
			temperate["beach"] = 0.25
		return temperate
	if lat < 17.0:  # Africa south of the Sahara
		var africa: Dictionary
		if lat < 5.5:  # the Guinea coast and the Congo: rainforest
			africa = {"jungle": 0.7, "plains": 0.1, "savanna": 0.15, "marsh": 0.04 + marsh}
		elif lat < 8.0:  # jungle thins into savanna
			africa = {"jungle": 0.45, "savanna": 0.45, "plains": 0.1, "marsh": 0.03 + marsh}
		elif lat < 12.5:  # savanna, with grassland
			africa = {"savanna": 0.65, "plains": 0.2, "steppe": 0.15}
		else:  # the Sahel: dry savanna and steppe
			africa = {"savanna": 0.55, "steppe": 0.35, "plains": 0.1}
		if coastal:
			africa["beach"] = 0.2
		return africa
	if Geo.hit(lon, lat, _steppes):
		return {"steppe": 1.0, "plains": 0.12, "marsh": marsh}
	if north_africa:  # the Maghreb: dry steppe and scrub, desert, a little woodland
		var maghreb := {"steppe": 0.5, "plains": 0.3, "desert": 0.3 if lat < 34.0 else 0.1, "forest": 0.03}
		if coastal:
			maghreb["beach"] = 0.18
		return maghreb
	var europe: Dictionary
	if lat >= 58.0 or (lon > 24.0 and lat >= 55.0):
		europe = {"taiga": 0.5, "forest": 0.25, "plains": 0.2, "marsh": 0.06 + marsh}
	elif lat >= 53.0:
		europe = {"forest": 0.45, "plains": 0.45, "hills": 0.08, "marsh": 0.05 + marsh}
	else:
		europe = {"plains": 0.64, "forest": 0.22, "hills": 0.1, "marsh": 0.02 + marsh}
	if coastal and lat < 41.0:
		europe["beach"] = 0.18
	return europe


## Distance in degrees to the nearest line (lines of interleaved points), or limit when none is closer.
static func _near_line(lon: float, lat: float, lines: Array[PackedFloat64Array], limit: float) -> float:
	var best := limit
	for line: PackedFloat64Array in lines:
		var n := Geo.point_count(line)
		for i in range(n - 1):
			var ax := line[2 * i]
			var ay := line[2 * i + 1]
			var bx := line[2 * i + 2]
			var by := line[2 * i + 3]
			if minf(ax, bx) - limit > lon or maxf(ax, bx) + limit < lon \
					or minf(ay, by) - limit > lat or maxf(ay, by) + limit < lat:
				continue
			best = minf(best, Geo.seg_distance(lon, lat, ax, ay, bx, by))
	return best


## How marshy the region is (0 to 1): the first marsh box that holds the point, or 0.
func _marsh_at(lon: float, lat: float) -> float:
	for box: PackedFloat64Array in _data.marshes:
		if box[0] <= lon and lon <= box[2] and box[1] <= lat and lat <= box[3]:
			return box[4]
	return 0.0
