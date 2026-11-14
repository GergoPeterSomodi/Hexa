## The Europe 1480 map builder. Step 1 (the land layers): grid and projection, land and sea, lakes, the forced points,
## rivers, the terrain by wave function collapse, the cities, the ridge edges and the passes. Step 2 (0.3.0, this file's
## second half): provinces with their goods, countries and their territories, names, people, towns, castles, works and
## ports, roads and the starting units. A port of build_map and build_countries, build_roads and starting_units in
## hexa/campaign/systems/worldgen.py (the Python reference; read, do not change).
class_name MapBuilder
extends RefCounted


## The Europe 1480 map from the godot/data inputs, with the fixed map seed (constants.json map_seed).
static func build_europe(data: EuropeData) -> MapData:
	var geo := Geo.new(float(data.projection["lon0"]), float(data.projection["col_deg"]),
			float(data.projection["row_deg"]), float(data.projection["y_top"]),
			int(data.projection["cols"]), int(data.projection["rows"]))
	var map := MapData.new()
	map.cols = geo.cols
	map.rows = geo.rows
	map.map_seed = data.map_seed
	var land := LandBuilder.paint(map, data, geo)
	LandBuilder.rivers(map, data, geo, land)
	_collapse_terrain(map, data, geo, land)
	LandBuilder.sea_bodies(map)
	LandBuilder.cities(map, data, geo)
	Passes.build(map, data, geo, _land_set(map))
	# Step 2. One luck source for all of it, seeded from the map seed (the numbers are not Python's; see the data README).
	var rng := Rng.new()
	rng.seed_with(data.map_seed)
	Provinces.build(map, geo, rng)
	CountryBuilder.build(map, data, geo, rng)
	RoadBuilder.build(map, data)
	StartingUnits.build(map, data, geo)
	return map


## Gives every land hex its terrain kind. Odds come from the geography (TerrainPrior); neighbours must fit (Wfc).
static func _collapse_terrain(map: MapData, data: EuropeData, geo: Geo, land: Dictionary) -> void:
	var coastal: Dictionary = {}
	for p: Vector2i in land.keys():
		for n: Vector2i in HexGrid.neighbours(p):
			if map.terrain.has(n) and not land.has(n):
				coastal[p] = true
				break
	var odds := TerrainPrior.new(geo, data)
	var cells: Array[Vector2i] = []
	for p: Vector2i in land.keys():
		cells.append(p)
	cells.sort_custom(HexGrid.lex_less)
	var prior: Dictionary = {}
	for p: Vector2i in cells:
		prior[p] = odds.weights(p, coastal.has(p), map.river_at.has(p))
	var rng := Rng.new()
	rng.seed_with(data.map_seed)
	var tiles := Wfc.collapse(cells, prior, data.forbidden, data.affinity, rng)
	for pos: Vector2i in tiles.keys():
		map.terrain[pos] = tiles[pos]


static func _land_set(map: MapData) -> Dictionary:
	var land: Dictionary = {}
	for p: Vector2i in map.land_hexes():
		land[p] = true
	return land
