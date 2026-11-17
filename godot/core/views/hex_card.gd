## Pure view helpers and word tables for a hex's hover card and side panel (docs/architecture/ui-and-controls-spec.md
## sections 3.6 and 7). Reads MapData, MapState and Improve; makes no engine or scene-tree calls.
class_name HexCard
extends RefCounted

## The words for a level, per family (docs/design/map/pieces/GUIDE.md section 8); other families use STAGE_WORDS.
const LEVEL_WORDS := {
	"settlements": ["", "hamlet", "village", "town", "walled town", "city"],
	"castles": ["", "watchtower", "castle", "fortress"],
	"harbour": ["", "fishing jetty", "quay", "port"],
}
const STAGE_WORDS: Array[String] = ["wild", "first stage", "second stage", "third stage"]
const COVER_WORDS: Array[String] = ["farmland", "grassland", "woods", "marsh", "rock", "snow", "tundra", "sand"]
const RELIEF_WORDS: Array[String] = ["sea", "lowland", "plain", "hills", "highland", "mountains", "high peaks"]
const CLIMATE_WORDS: Array[String] = ["snow", "frost", "mild"]
const DEPTH_WORDS: Array[String] = ["shelf", "open sea", "deep sea"]
const RIVER_WORDS: Array[String] = ["none", "river", "river", "river", "stream"]
const ROAD_WORDS: Array[String] = ["none", "track", "road", "highway"]
const CROSSING_WORDS: Array[String] = ["none", "ford", "wood bridge", "stone bridge", "ferry", "pass"]
const DIRECTIONS: Array[String] = ["E", "NE", "NW", "W", "SW", "SE"]
const EDGES: Array[String] = ["coast", "river", "road", "pass"]


## Clamped lookup in a word table; "" when the table is empty.
static func word(list: Array[String], index: int) -> String:
	if list.is_empty():
		return ""
	return list[clampi(index, 0, list.size() - 1)]


## The ground cover word for a MapData cover byte ("sea" for COVER_SEA).
static func cover_words(cover: int) -> String:
	if cover == MapData.COVER_SEA:
		return "sea"
	return word(COVER_WORDS, cover)


## The pass on a hex with its height in metres (e.g. "Giovi (472 m)"), or "" when none.
static func pass_of(map: MapData, hex: Vector2i) -> String:
	if map == null or not map.has(hex):
		return ""
	var i := map.index_of(hex)
	var p := int(map.pass_id[i]) if i < map.pass_id.size() else -1
	if p < 0 or p >= map.passes.size():
		return ""
	var entry: Dictionary = map.passes[p]
	var name := str(entry.get("name", ""))
	if name == "":
		return ""
	var metres := int(entry.get("metres", 0))
	return "%s (%d m)" % [name, metres] if metres > 0 else name


## Summary of the six edges of `hex` for `kind` ("river", "road", "crossing", "crest", "pass_edge"):
## e.g. "river (E, NW)", "highway (E), road (SW)", or "none".
static func edge_summary(map: MapData, hex: Vector2i, kind: String) -> String:
	if map == null or not map.has(hex):
		return "none"
	var order: Array[String] = []
	var dirs_by_word: Dictionary = {}
	for d: int in DIRECTIONS.size():
		var e := map.edge_index(hex, d)
		if e < 0:
			continue
		var label := _edge_word(map, e, kind)
		if label == "" or label == "none":
			continue
		if not dirs_by_word.has(label):
			order.append(label)
			dirs_by_word[label] = PackedStringArray()
		var list: PackedStringArray = dirs_by_word[label]
		list.append(DIRECTIONS[d])
		dirs_by_word[label] = list
	if order.is_empty():
		return "none"
	var parts := PackedStringArray()
	for label: String in order:
		var list: PackedStringArray = dirs_by_word[label]
		parts.append("%s (%s)" % [label, ", ".join(list)])
	return ", ".join(parts)


## Summary of the road crossings on the six edges of `hex` (e.g. "stone bridge (E)" or "none").
static func crossing_summary(map: MapData, hex: Vector2i) -> String:
	return edge_summary(map, hex, "crossing")


static func _edge_word(map: MapData, e: int, kind: String) -> String:
	match kind:
		"river", "rivers":
			return word(RIVER_WORDS, int(map.river[e])) if e < map.river.size() else "none"
		"road", "roads":
			return word(ROAD_WORDS, int(map.road[e])) if e < map.road.size() else "none"
		"crossing", "crossings":
			return word(CROSSING_WORDS, int(map.crossing[e])) if e < map.crossing.size() else "none"
		"crest":
			return "crest" if e < map.crest.size() and int(map.crest[e]) > 0 else "none"
		"pass", "pass_edge":
			return "pass" if e < map.pass_edge.size() and int(map.pass_edge[e]) > 0 else "none"
	return "none"


## Title of a hex for its hover card: the place name when one stands there, else "Hex (c, r)" or "Sea (c, r)".
static func title_of(map: MapData, hex: Vector2i) -> String:
	if map == null or not map.has(hex):
		return ""
	if not map.is_land(hex):
		return "Sea (%d, %d)" % [hex.x, hex.y]
	var place := Improve.place_of(map, hex)
	var place_name := str(place.get("name", ""))
	if place_name != "":
		return place_name
	return "Hex (%d, %d)" % [hex.x, hex.y]


## Subtitle of a hex for its hover card: "(c, r) · Land" (with capital, port, pass tags) or "(c, r) · Sea".
static func subtitle_of(map: MapData, hex: Vector2i) -> String:
	if map == null or not map.has(hex):
		return ""
	var parts := PackedStringArray(["(%d, %d)" % [hex.x, hex.y]])
	if not map.is_land(hex):
		parts.append("Sea")
		return " · ".join(parts)
	parts.append("Land")
	var place := Improve.place_of(map, hex)
	if bool(place.get("capital", false)):
		parts.append("capital")
	if bool(place.get("port", false)):
		parts.append("port")
	if pass_of(map, hex) != "":
		parts.append("pass")
	return " · ".join(parts)


## Key-value rows `[key, value]` describing the ground of `hex`.
static func ground_rows(map: MapData, hex: Vector2i) -> Array[Array]:
	var rows: Array[Array] = []
	if map == null or not map.has(hex):
		return rows
	var i := map.index_of(hex)
	if map.land[i] == 0:
		rows.append(["Depth", word(DEPTH_WORDS, int(map.depth[i]))])
		rows.append(["Relief", word(RELIEF_WORDS, int(map.relief[i]))])
		return rows
	rows.append(["Ground", cover_words(int(map.cover[i]))])
	rows.append(["Height", "%d m" % int(map.height_m[i])])
	rows.append(["Relief", word(RELIEF_WORDS, int(map.relief[i]))])
	rows.append(["Winter", word(CLIMATE_WORDS, int(map.climate[i]))])
	var facts := Improve.facts_of(map, hex)
	var edges: Array[String] = []
	for edge: String in EDGES:
		if bool(facts[edge]):
			edges.append(edge)
	if not edges.is_empty():
		rows.append(["Edges", ", ".join(PackedStringArray(edges))])
	return rows


## Key-value rows `[key, value]` describing what stands on a hex (`Improve.piece_at`).
static func piece_rows(piece: Dictionary) -> Array[Array]:
	var rows: Array[Array] = []
	if piece.is_empty():
		rows.append(["Stands on it", "nothing (wild land)"])
		return rows
	var family := str(piece["family"])
	rows.append(["Piece", family_word(family, str(piece["extra"]))])
	rows.append(["Level", level_word(family, int(piece["level"]))])
	if int(piece["addon"]) > 0:
		rows.append(["Harbour", "%s (%s)" % [level_word("harbour", int(piece["addon"])), str(piece["addon_mode"])]])
	rows.append(["Layout", "%d%s" % [int(piece["variant"]) + 1, ", mirrored" if bool(piece["mirror"]) else ""]])
	return rows


## Hover-card model for `hex` in `game` (spec sections 3.5 and 7); `{}` when `game` or `game.map` is null or `hex` is off the map.
static func of(game: Game, hex: Vector2i) -> Dictionary:
	if game == null or game.map == null or not game.map.has(hex):
		return {}
	var map := game.map
	var i := map.index_of(hex)
	var is_land := map.land[i] == 1
	var cover := cover_words(int(map.cover[i])) if is_land else word(DEPTH_WORDS, int(map.depth[i]))
	var height_m := int(map.height_m[i]) if is_land else 0
	var relief := word(RELIEF_WORDS, int(map.relief[i])) if is_land else RELIEF_WORDS[0]
	var climate := word(CLIMATE_WORDS, int(map.climate[i]))
	var place := Improve.place_of(map, hex) if is_land else {}
	var place_name := str(place.get("name", ""))
	var pass_name := pass_of(map, hex) if is_land else ""
	var rivers := edge_summary(map, hex, "river")
	var roads := edge_summary(map, hex, "road")
	var crossings := crossing_summary(map, hex)
	var piece := Improve.piece_at(game, hex) if is_land else {}
	var lines: Array = [
		["Hex", &"muted", "(%d, %d)" % [hex.x, hex.y]],
	]
	if is_land:
		if place_name != "":
			lines.append(["Place", &"plain", place_name])
		lines.append(["Cover", &"plain", cover])
		lines.append(["Height", &"plain", "%d m" % height_m])
		lines.append(["Relief", &"plain", relief])
		lines.append(["Winter", &"plain", climate])
		if pass_name != "":
			lines.append(["Pass", &"plain", pass_name])
		if rivers != "none":
			lines.append(["Rivers", &"plain", rivers])
		if roads != "none":
			lines.append(["Roads", &"plain", roads])
		if crossings != "none":
			lines.append(["Crossings", &"plain", crossings])
		if piece.is_empty():
			lines.append(["Stands on it", &"muted", "nothing (wild land)"])
		else:
			lines.append(["", &"rule", ""])
			for row: Array in piece_rows(piece):
				lines.append([str(row[0]), &"plain", str(row[1])])
	else:
		lines.append(["Depth", &"plain", cover])
		lines.append(["Relief", &"plain", relief])
		lines.append(["Winter", &"plain", climate])
	return {
		"hex": hex,
		"title": title_of(map, hex),
		"subtitle": subtitle_of(map, hex),
		"is_land": is_land,
		"cover": cover,
		"height_m": height_m,
		"relief": relief,
		"climate": climate,
		"place": place_name,
		"pass_name": pass_name,
		"rivers": rivers,
		"roads": roads,
		"crossings": crossings,
		"piece": piece,
		"lines": lines,
	}


static func top_level(family_name: String) -> int:
	var id := ImproveRules.NAMES.find(family_name)
	return ImproveRules.TOP_LEVEL[id] if id >= 0 else 0


static func level_name(family_name: String, level: int) -> String:
	var label := ""
	if LEVEL_WORDS.has(family_name):
		var words: Array = LEVEL_WORDS[family_name]
		if level >= 0 and level < words.size():
			label = str(words[level])
	elif level >= 0 and level < STAGE_WORDS.size():
		label = STAGE_WORDS[level]
	return "%s (level %d)" % [label, level] if label != "" else "level %d" % level


static func family_word(family: String, extra: String) -> String:
	var label := family.replace("_", " ").capitalize()
	if extra != "-" and extra != "":
		label += " (" + extra + ")"
	return label


static func level_word(family: String, level: int) -> String:
	if LEVEL_WORDS.has(family):
		var words: Array = LEVEL_WORDS[family]
		if level >= 0 and level < words.size():
			return "level %d, %s" % [level, str(words[level])]
	if level >= 0 and level < STAGE_WORDS.size():
		return "level %d, %s" % [level, STAGE_WORDS[level]]
	return "level %d" % level
