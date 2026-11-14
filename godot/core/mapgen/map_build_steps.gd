## The Europe 1480 build as stages, so that the shell can show progress between them (the bar moves once a frame, and a
## build of about 4 seconds would otherwise freeze the screen). Each stage is the same call as in MapBuilder's single
## build, in the same order, with the same luck: running every stage gives the same map as MapBuilder.build_europe.
## Pure: no engine calls, no signals; the shell calls run_next() once a frame and reads next_label() and progress().
class_name MapBuildSteps
extends RefCounted

const LABELS: PackedStringArray = [
	"Land and sea",
	"Rivers",
	"Terrain",
	"Coasts and cities",
	"Ridges and passes",
	"Provinces",
	"Countries, towns and castles",
	"Roads",
	"Starting units",
]

var map: MapData
var _data: EuropeData
var _geo: Geo
var _land: Dictionary = {}
var _rng: Rng
var _next: int = 0


func _init(data: EuropeData) -> void:
	_data = data
	_geo = Geo.new(float(data.projection["lon0"]), float(data.projection["col_deg"]),
			float(data.projection["row_deg"]), float(data.projection["y_top"]),
			int(data.projection["cols"]), int(data.projection["rows"]))
	map = MapData.new()
	map.cols = _geo.cols
	map.rows = _geo.rows
	map.map_seed = data.map_seed


## Stages done, out of all of them (0.0 to 1.0).
func progress() -> float:
	return float(_next) / float(LABELS.size())


## The name of the stage run_next() will do, or "" when all are done.
func next_label() -> String:
	if _next >= LABELS.size():
		return ""
	return LABELS[_next]


func is_done() -> bool:
	return _next >= LABELS.size()


## Runs the next stage. Returns false (and does nothing) when every stage has run.
func run_next() -> bool:
	if is_done():
		return false
	match _next:
		0:
			_land = LandBuilder.paint(map, _data, _geo)
		1:
			LandBuilder.rivers(map, _data, _geo, _land)
		2:
			MapBuilder.collapse_terrain(map, _data, _geo, _land)
		3:
			LandBuilder.sea_bodies(map)
			LandBuilder.cities(map, _data, _geo)
		4:
			Passes.build(map, _data, _geo, MapBuilder.land_set(map))
			# Step 2. One luck source for all of it, seeded from the map seed.
			_rng = Rng.new()
			_rng.seed_with(_data.map_seed)
		5:
			Provinces.build(map, _geo, _rng)
		6:
			CountryBuilder.build(map, _data, _geo, _rng)
		7:
			RoadBuilder.build(map, _data)
		8:
			StartingUnits.build(map, _data, _geo)
	_next += 1
	return true
