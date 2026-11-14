## The provinces of the Europe 1480 map: one per land hex, in (column, row) order, with the coast and city flags and the
## good of each province. A port of the province part of build_map in hexa/campaign/systems/worldgen.py (the frozen
## reference). Runs after the passes, reading the land and the cities step 1 left in the MapData.
class_name Provinces
extends RefCounted


static func build(map: MapData, geo: Geo, rng: Rng) -> void:
	var land := map.land_hexes()
	land.sort_custom(HexGrid.lex_less)
	for pos: Vector2i in land:
		var coastal := false
		for n: Vector2i in HexGrid.neighbours(pos):
			if map.terrain.has(n) and map.terrain[n] == MapData.OCEAN:
				coastal = true
				break
		map.provinces[pos] = Province.new(pos, map.terrain[pos], coastal, map.city_names.has(pos))
	# The goods are drawn in province order, as Python draws them.
	for pos: Vector2i in land:
		var prov: Province = map.provinces[pos]
		var ll := geo.lonlat(pos)
		prov.good = GoodsRules.good_for(prov, ll[0], ll[1], rng)
