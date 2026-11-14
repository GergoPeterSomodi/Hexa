## The text the map view shows under the mouse: the name of a hex (its city, else its terrain), the terrain, the
## pass and the owner when the builder has them. Pure.
class_name HexInfo
extends RefCounted


static func describe(map: MapData, pos: Vector2i, style: TerrainStyle) -> String:
	if not map.has_hex(pos):
		return ""
	var kind: String = map.terrain[pos]
	var lines: PackedStringArray = PackedStringArray()
	if map.city_names.has(pos):
		lines.append(map.city_names[pos])
	elif kind == MapData.OCEAN:
		lines.append("Sea")
	elif kind == MapData.LAKE:
		lines.append("Lake")
	else:
		lines.append(style.terrain_name(kind))
	# TODO-WIRE: the province name (step 2) replaces the line above on land; the country name below comes with owners.
	if map.city_names.has(pos) and kind != MapData.OCEAN and kind != MapData.LAKE:
		lines.append("Terrain: " + style.terrain_name(kind))
	if map.pass_hexes.has(pos):
		lines.append("Pass: " + map.pass_hexes[pos])
	var owned := TerrainStyle.owners(map)
	if owned.has(pos):
		lines.append("Country: " + String(owned[pos]))
	return "\n".join(lines)
