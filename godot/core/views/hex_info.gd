## The text the map view shows under the mouse: the province's name (else its city, else the terrain or sea), the terrain,
## the country and whether it is a capital, and the pass. Pure.
class_name HexInfo
extends RefCounted


static func describe(map: MapData, pos: Vector2i, style: TerrainStyle) -> String:
	if not map.has_hex(pos):
		return ""
	var kind: String = map.terrain[pos]
	var water := kind == MapData.OCEAN or kind == MapData.LAKE
	var prov := map.province(pos)
	var lines: PackedStringArray = PackedStringArray()
	if prov != null and prov.name != "":
		lines.append(prov.name)
	elif map.city_names.has(pos):
		lines.append(map.city_names[pos])
	elif kind == MapData.OCEAN:
		lines.append("Sea")
	elif kind == MapData.LAKE:
		lines.append("Lake")
	else:
		lines.append(style.terrain_name(kind))
	if not water:
		lines.append("Terrain: " + style.terrain_name(kind))
	var owner := Political.owner_of(map, pos)
	if owner != "":
		var country_name: String = map.countries[owner].name if map.countries.has(owner) else owner
		lines.append("Country: " + country_name)
	for tag: String in map.country_order:
		if map.countries.has(tag) and map.countries[tag].capital == pos:
			lines.append("Capital of " + map.countries[tag].name)
			break
	if map.pass_hexes.has(pos):
		lines.append("Pass: " + map.pass_hexes[pos])
	return "\n".join(lines)
