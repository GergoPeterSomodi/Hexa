## Which tile a hex shows on each layer of the map view, by name (docs/architecture/m1-build-spec.md, sections 3 and 5).
## Plain rules on plain facts: no nodes, no files. The names are those of the tileset bake
## (tools/worldmap/tileset_bake); "" means no tile. A hex is Vector2i(column, row); directions are HexGrid's
## (0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE).
class_name MapTiles
extends RefCounted

const CELL := Vector2i(104, 102)
const ROW := 76.5
const GROUND_VARIANTS := 3
const SEA_VARIANTS := 3
const TREE_VARIANTS := 2
const RELIEF_VARIANTS := 3
const SHADE_LEVELS := 10
const LIGHT_LEVELS := 6
const GREEN_COVERS: Array[String] = ["farmland", "grassland", "woods", "marsh"]
## The light of the slope tones: from the upper left (the style frame's SLOPE_LIGHT, as a unit vector).
const LIGHT_DIR := Vector2(-0.898, -0.439)
const SLOPE_M_PER_KM := 26.0
const HEX_KM := 28.0
## The outward unit normals of the six edges on screen (the cell is squashed, so they are not 60 degrees apart).
const EDGE_NORMALS: Array[Vector2] = [
	Vector2(1.0, 0.0), Vector2(0.562, -0.827), Vector2(-0.562, -0.827),
	Vector2(-1.0, 0.0), Vector2(-0.562, 0.827), Vector2(0.562, 0.827),
]
const SIDES: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
## The covers by number, as MapData.cover stores them (the order of the tile names; WorldCover's ids). 255 is sea.
const COVERS: Array[String] = ["farmland", "grassland", "woods", "marsh", "rock", "snow", "tundra", "sand"]
## The sea depths by number, as MapData.depth stores them.
const DEPTHS: Array[String] = ["shelf", "sea", "deep"]


## The middle of a cell in map px (what TileMapLayer.map_to_local gives; a test pins the two together).
static func cell_centre(hex: Vector2i) -> Vector2:
	return Vector2(float(CELL.x) * (float(hex.x) + 0.5 + 0.5 * float(hex.y & 1)), float(CELL.y) / 2.0 + ROW * float(hex.y))


## A stable pick of 0 to count - 1 for a hex (which variant of a tile it shows).
static func pick(hex: Vector2i, count: int, salt: int = 0) -> int:
	var h := (hex.x * 73856093) ^ (hex.y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return posmod(h ^ (h >> 16), count)


## Which of the six lattice positions a cell is (the coast's wobble repeats every 3 cells and 2 rows).
static func lattice_variant(hex: Vector2i) -> int:
	return posmod(hex.x, 3) + 3 * (hex.y & 1)


static func _smoothstep(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## ground/<cover>/<band>/<variant>. Green ground goes paler with height (bands 0 to 3) and open ground is half stone above 1700 m.
static func ground(cover: String, height_m: float, hex: Vector2i) -> String:
	if cover == "":
		return ""
	var band := 0
	if GREEN_COVERS.has(cover):
		band = clampi(roundi(_smoothstep(100.0, 850.0, height_m) * 3.0), 0, 3)
		if height_m > 1700.0 and cover != "woods":
			band = 4
	return "ground/%s/%d/%d" % [cover, band, pick(hex, GROUND_VARIANTS, 1)]


## The cover's name for a MapData cover number, "" for the sea (255) or a number that is no cover.
static func cover_name(cover_id: int) -> String:
	return COVERS[cover_id] if cover_id >= 0 and cover_id < COVERS.size() else ""


## The depth's name for a MapData depth number (0 shelf, 1 sea, 2 deep); anything else is shelf.
static func depth_name(depth_id: int) -> String:
	return DEPTHS[depth_id] if depth_id >= 0 and depth_id < DEPTHS.size() else "shelf"


## ground() with the cover given by its MapData number.
static func ground_of(cover_id: int, height_m: float, hex: Vector2i) -> String:
	return ground(cover_name(cover_id), height_m, hex)


## sea() with the depth given by its MapData number.
static func sea_of(depth_id: int, beside_land: bool, hex: Vector2i) -> String:
	return sea(depth_name(depth_id), beside_land, hex)


## sea/<depth>/<variant>. A sea hex beside land is always shelf: only the shelf tile has a hard edge, so no deeper
## water spills onto the shore.
static func sea(depth: String, beside_land: bool, hex: Vector2i) -> String:
	var name := depth if (depth == "sea" or depth == "deep") and not beside_land else "shelf"
	return "sea/%s/%d" % [name, pick(hex, SEA_VARIANTS, 2)]


## The coast mask of a land hex: bit d is set when the neighbour in direction d is sea. 0 = no coast.
static func coast_mask(neighbour_is_sea: Array[bool]) -> int:
	var mask := 0
	for d: int in 6:
		if neighbour_is_sea[d]:
			mask |= 1 << d
	return mask


## Whether a carved port's bay fits a coast: the sea must lie south (both lower edges).
static func bay_fits(mask: int) -> bool:
	return (mask & 0b110000) == 0b110000


## coast/<style>/<mask>/<lattice variant>[/bay]. Steep ground (relief level 3 and up) breaks off as a cliff; a port
## stands on a low shore.
static func coast(mask: int, hex: Vector2i, relief_level: int, port: bool, bay: bool) -> String:
	if mask == 0:
		return ""
	var style := "cliff" if relief_level >= 3 and not port else "beach"
	return "coast/%s/%d/%d%s" % [style, mask, lattice_variant(hex), "/bay" if bay and bay_fits(mask) else ""]


## The side of the sea for a coast piece (E, SE, S, SW, W, NW, N, NE), from the mask; "" without a coast.
static func sea_side(mask: int) -> String:
	var sum := Vector2.ZERO
	for d: int in 6:
		if (mask >> d) & 1 == 1:
			sum += EDGE_NORMALS[d]
	if mask == 0 or sum.length() < 0.01:
		return ""
	return SIDES[posmod(roundi(rad_to_deg(sum.angle()) / 45.0), 8)]


## Vector2i(shade level 0..SHADE_LEVELS, light level 0..LIGHT_LEVELS) of a land hex from its height and its six
## neighbours' (a sea or missing neighbour counts as this hex's own height: the shore is no slope).
## A slope that faces the light is lit, one that faces away is shaded, and a floor below its neighbours is darker.
static func slope_tone(height_m: float, neighbour_m: PackedFloat32Array) -> Vector2i:
	var grad := Vector2.ZERO
	var mean := 0.0
	for d: int in 6:
		var dir := EDGE_NORMALS[d]
		grad += dir * ((neighbour_m[d] - height_m) / HEX_KM)
		mean += neighbour_m[d]
	grad /= 3.0
	mean /= 6.0
	var steep := grad.length()
	var facing := -grad.dot(LIGHT_DIR) / SLOPE_M_PER_KM
	var lit := clampf(facing, 0.0, 1.0) * _smoothstep(4.0, 20.0, steep)
	var shaded := clampf(-facing, 0.0, 1.0) * _smoothstep(6.0, 26.0, steep)
	var hollow := _smoothstep(12.0, 150.0, mean - height_m) * _smoothstep(6.0, 26.0, steep)
	var dark := 0.16 * shaded + 0.10 * hollow
	return Vector2i(clampi(roundi(dark / 0.03), 0, SHADE_LEVELS), clampi(roundi(lit * float(LIGHT_LEVELS)), 0, LIGHT_LEVELS))


## relief/<kind>/<form>/<variant>: hills on hill country, a ridge on high ground (the big ones where a crest runs).
## A built hex keeps a ridge only in its back half and loses its hills; a road gets a saddle.
static func relief(relief_level: int, crest: bool, built: bool, road: bool, hex: Vector2i) -> String:
	var kind := ""
	match relief_level:
		3:
			kind = "hills_low" if pick(hex, 3, 3) != 0 else ""
		4:
			kind = "ridge_green" if crest else "hills_high"
		5:
			kind = "ridge_rock" if crest else "ridge_green"
		6:
			kind = "ridge_snow" if crest else "ridge_rock"
	if kind == "" or (built and kind.begins_with("hills")):
		return ""
	var form := "back" if built else ("pass" if road else "full")
	return "relief/%s/%s/%d" % [kind, form, pick(hex, RELIEF_VARIANTS, 4)]


## trees/<kind>/<option>/<direction>/<variant> for one wedge of a hex, or "". cover and neighbour_cover are cover
## names (neighbour_cover is "" for sea); river and road say whether a river runs along this wedge's edge and a road
## crosses it; hilly says the hex shows hills or a ridge (the wood thins so they show).
static func trees(direction: int, cover: String, height_m: float, neighbour_cover: String, river: bool, road: bool,
		built: bool, hilly: bool, hex: Vector2i) -> String:
	if height_m > 1800.0:
		return ""
	var kind := "broad"
	if height_m > 1300.0 or cover == "rock" or cover == "snow":
		kind = "conifer"
	elif height_m > 700.0:
		kind = "mixed"
	var shore := neighbour_cover == ""
	var option := ""
	if cover == "woods":
		if built:
			option = "" if river or shore else ("outerroad" if road else "outer")
		elif (river or shore) and road:
			option = "bankroad"
		elif river or shore:
			option = "bank"
		elif road:
			option = "road"
		else:
			option = "thin" if hilly else "full"
	elif built or river or road or shore:
		option = ""
	elif neighbour_cover == "woods":
		option = "fringe"
	elif cover == "rock" and height_m < 1700.0:
		option = "sparse"
	elif (cover == "farmland" or cover == "grassland") and pick(hex, 2, 10 + direction) == 0:
		option = "sparse"
	if option == "":
		return ""
	return "trees/%s/%s/%d/%d" % [kind, option, direction, pick(hex, TREE_VARIANTS, 20 + direction)]


## piece/<family>/<level>/<variant>/<mirror>/<extra>/<part>; part is ground, shadow, back or front.
static func piece(family: String, level: int, variant: int, mirror: bool, extra: String, part: String) -> String:
	return "piece/%s/%d/%d/%d/%s/%s" % [family, level, variant, int(mirror), extra if extra != "" else "-", part]
