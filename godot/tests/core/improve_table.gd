## Test helper: the hex table WorldImprove reads (the shape of the baked meta.json "hexes"), built from the map core of
## the prototype region instead of from a bake, so the tests of the improvement step need no baked art.
## The winter of a hex is the pieces guide's rule (GUIDE.md section 7: latitude, height, kilometres to the sea).
class_name ImproveTable
extends RefCounted

const HEIGHTS := "res://data/worldmap/heights_alps_po.json"
const REGION := "res://data/worldmap/region_alps_po.json"
const COVERS: Array[String] = ["farmland", "grassland", "woods", "marsh", "rock", "snow", "tundra", "sand"]


## The table of the whole prototype region, or an empty array when the data do not read.
static func region_table() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var heights := WorldHeights.from_text(FileAccess.get_file_as_string(HEIGHTS))
	var region := WorldRegion.from_text(FileAccess.get_file_as_string(REGION))
	if heights == null or region == null:
		return out
	var grid := HexGrid.new(region.hex_w_km, region.deg_km, region.ref_lat, region.lon_west, region.lat_north)
	var relief := WorldRelief.build(grid, heights, region)
	var water := WorldWater.build(grid, relief, heights, region)
	var cover := WorldCover.build(grid, relief, heights, water, region.cover_seed)
	var places := WorldPlaces.build(grid, relief, water, cover, region)
	var roads := WorldRoads.build(grid, relief, water, places, region)
	var sea: Array[Vector2] = []
	for hex: Vector2i in relief.levels.keys():
		if relief.level_at(hex) == ReliefLevels.SEA and not water.lake_hex.has(hex):
			sea.append(grid.centre_km(hex))
	var saddles: Dictionary[Vector2i, bool] = {}
	for p: int in places.pass_saddles.keys():
		saddles[places.pass_saddles[p]] = true
	for hex: Vector2i in relief.levels.keys():
		var land := relief.level_at(hex) != ReliefLevels.SEA
		var row: Dictionary = {"c": hex.x, "r": hex.y, "land": land}
		if land:
			var centre := grid.centre_km(hex)
			var metres := float(heights.height_m.get(hex, 0.0))
			var sea_km := 999.0
			for s: Vector2 in sea:
				sea_km = minf(sea_km, centre.distance_to(s) - grid.hex_w_km / 2.0)
			var river_edges: Array[int] = []
			for d: int in 6:
				if water.river_edge.has(HexGrid.edge_key(hex, grid.neighbour(hex, d))):
					river_edges.append(d)
			row["cover"] = COVERS[cover.cover_at(hex)]
			row["height_m"] = metres
			row["coast"] = cover.is_coastal(hex)
			row["sea_angle"] = 90.0
			row["climate"] = winter_of(grid.lonlat_of(centre).y, metres, maxf(sea_km, 0.0))
			row["river_edges"] = river_edges
			row["road"] = roads.network.has(hex)
			row["pass"] = saddles.has(hex)
			row["place"] = null
			var pl := places.place_at(hex)
			if not pl.is_empty() and int(pl["level"]) >= 1:
				var sea_port := bool(pl["port"]) and bool(pl["sea"])
				row["place"] = {
					"name": str(pl["name"]),
					"level": int(pl["level"]),
					"port": sea_port,
					"port_mode": "carved" if sea_port and int(pl["level"]) >= 4 else "seaside",
					"landmark": null,
				}
		out.append(row)
	return out


## The guide's winter rule: "mild", "frost" or "snow".
static func winter_of(lat: float, metres: float, sea_km: float) -> String:
	var warm := clampf((50.0 - lat) / 8.0, 0.25, 1.0)
	var settled := metres * minf(1.0, sea_km / 25.0)
	var cold := 0.5 * (lat - 36.0) + settled / 300.0 \
		- warm * (3.5 * maxf(0.0, 1.0 - sea_km / 40.0) + 2.0 * maxf(0.0, 1.0 - sea_km / 15.0)) \
		+ minf(2.0, sea_km / 300.0)
	if cold < 4.5:
		return "mild"
	return "frost" if cold < 8.0 else "snow"
