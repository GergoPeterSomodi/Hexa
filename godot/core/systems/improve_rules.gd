## The rules of the improvement step, as plain tables and pure functions (docs/design/map/06-growing-map.md section 2 and
## the pieces guide, docs/design/map/pieces/GUIDE.md sections 6, 8 and 10): the families and their levels, the cell rules (what
## a family needs of the ground), the pair rules (what may not stand near what), the weights the solver draws by, and the
## small helpers (which picture a hex shows, hex distance, the sea side). No state, no files, no engine calls. Split out of
## world_improve.gd (the old WorldImprove constants and static functions, moved as they were; the weights `fit`,
## `level_weight` and `wild_share` were private statics there).
class_name ImproveRules
extends RefCounted


const NONE := 0
const SETTLEMENT := 1
const CASTLE := 2
const WHEAT := 3
const HEMP := 4
const SILK := 5
const DYES := 6
const VINEYARD := 7
const OLIVES := 8
const GRAZING := 9
const TIMBER := 10
const MINES := 11
const QUARRY := 12
const SALT := 13
const HARBOUR := 14
## The family tables live in the defs layer (FamilyIds); these are the same values under the names the systems use.
const FAMILIES := FamilyIds.COUNT
const NAMES: Array[String] = FamilyIds.NAMES
const TOP_LEVEL: Array[int] = FamilyIds.TOP_LEVEL
## Layouts each family has (the modules' VARIANTS).
const VARIANTS: Array[int] = [1, 2, 3, 2, 2, 2, 2, 3, 2, 3, 2, 2, 2, 2, 2]
## In a pair rule: any goods family (wheat and after).
const ANY_GOODS := -1

## Pairs that may not stand within `radius` hexes of each other: [family a, from level, family b, from level, radius,
## the reason]. Symmetric. Fixed places of the data are not moved by a rule: a pair of them that breaks one is counted
## (fixed_conflicts) and left.
const PAIR_RULES: Array[Array] = [
	[SETTLEMENT, 3, SETTLEMENT, 3, 1, "a town needs its own countryside: no two towns side by side"],
	[CASTLE, 1, CASTLE, 1, 2, "one castle holds its area: at most one within two hexes"],
	[ANY_GOODS, 3, ANY_GOODS, 3, 1, "the top stage stays rare: two level 3 districts never touch"],
	[MINES, 1, MINES, 1, 1, "one mining district per valley: spoil heaps side by side read as one grey mass"],
	[QUARRY, 1, QUARRY, 1, 1, "one quarry per hill"],
	[MINES, 1, QUARRY, 1, 1, "guide, crowding pair quarry / mines: kept apart so each is told at a glance"],
	[SALT, 1, SALT, 1, 1, "salt pans are a special shore, not a coast-long strip"],
	[HARBOUR, 1, HARBOUR, 1, 1, "fishing harbours are spaced along the shore"],
	[DYES, 1, DYES, 1, 2, "a dye works is one per town: nothing else on the map is many-coloured"],
	[DYES, 1, SALT, 1, 1, "guide, crowding pair dye works / salt (vats and pans)"],
	[SILK, 1, OLIVES, 1, 1, "guide, crowding pair silk / olives (two groves of low trees)"],
	[SILK, 2, SILK, 2, 1, "silk is a town's luxury, not a countryside: no two grown silk districts touch"],
	[CASTLE, 1, SETTLEMENT, 4, 1, "a walled town is its own fortress: no castle against its wall"],
]

## Restarts of the search before the fallback, and backtracks allowed in one run.
const RETRIES := 8
const BACKTRACK_LIMIT := 20000
## The share of a hex's weight that goes to "no piece" before the neighbours speak: far from everything, and the
## lower shares near places and roads (the nearest applies). The owner disliked crowded maps: keep these high.
const WILD_SHARE := 0.80
const WILD_BY_ROAD := 0.70
const WILD_NEAR_TOWN := 0.62  # two hexes from a town
const WILD_AT_TOWN := 0.45  # next to a town
const WILD_AT_CITY := 0.28  # next to a walled town or city: its farmland shows in the six hexes round it
## The share of "no castle" on a pass: a pass with a road is the one worth holding.
const PASS_OPEN := 0.6
const PASS_OPEN_BY_ROAD := 0.3
## Height in metres above which a hex is "in the hills" (levels fall, the wild share grows) and "high" (more again).
## (The heights of the hex table are the highest ground of the hex, so a plain hex beside a hill reads some hundred
## metres and an Alpine valley over 2000.)
const HILLS_M := 700.0
const HIGH_M := 1400.0
## Goods are not placed above this height (the high pastures end; rock and snow above).
const TOP_M := 2600.0
## The upland starts here: grazing in the woods and quarries off the rock need this height.
const UPLAND_M := 700.0
## A weight grows by this much per decided neighbour of the same family (districts), by family.
const AFFINITY: Array[float] = [0.0, 0.0, 0.0, 0.9, 0.5, 0.2, 0.0, 0.8, 0.8, 0.6, 0.6, 0.0, 0.0, 0.0, 0.0]
## A weight is multiplied by this per decided neighbour with the very same family and level.
const SAME_PENALTY := 0.3
## "None" grows by this per wild neighbour: wild land comes in stretches, worked land in districts.
const WILD_AFFINITY := 0.12

## The cover names of the hex table, in WorldCover order (the first word, lower case, is compared).
const COVER_WORDS: Array[String] = ["farmland", "grassland", "woods", "marsh", "rock", "snow", "tundra", "sand"]
const ANIMALS: Array[String] = ["sheep", "cattle", "horses"]
const ORES: Array[String] = ["iron", "copper", "silver"]
## The harbour add-on's level for a port of each settlement level (index: the level).
const ADDON_LEVEL: Array[int] = [0, 1, 1, 2, 3, 3]


## The number of options, and the option of a family and level (-1 when the family has no such level).
static func option_count() -> int:
	var n := 1
	for f: int in range(1, FAMILIES):
		n += TOP_LEVEL[f]
	return n


static func option_of(family_id: int, level_value: int) -> int:
	if family_id == NONE:
		return 0 if level_value == 0 else -1
	if family_id < 0 or family_id >= FAMILIES or level_value < 1 or level_value > TOP_LEVEL[family_id]:
		return -1
	var at := 1
	for f: int in range(1, family_id):
		at += TOP_LEVEL[f]
	return at + level_value - 1


## The cell rules: whether a family may stand at a level on a hex with these facts (see facts_at). Places and passes
## are decided before the rules (see _domain_of): this is the rule for a free hex.
static func cell_allowed(family_id: int, level_value: int, facts: Dictionary) -> bool:
	if family_id == NONE:
		return level_value == 0
	if family_id == SETTLEMENT or family_id == CASTLE:
		return false  # never chosen freely: places and passes come from the data
	if level_value < 1 or level_value > TOP_LEVEL[family_id]:
		return false
	var cover_id := int(facts.get("cover", -1))
	var metres := float(facts.get("height_m", 0.0))
	var coast := bool(facts.get("coast", false))
	var river := bool(facts.get("river", false))
	var climate := str(facts.get("climate", "frost"))
	var town := int(facts.get("town_distance", 99))  # hexes to the nearest settlement of level 3 or more
	var place := int(facts.get("place_distance", 99))  # hexes to the nearest settlement of any level
	var road := bool(facts.get("road", false))
	if metres > TOP_M:
		return false
	if cover_id == WorldCover.SNOW or cover_id == WorldCover.TUNDRA:
		return false
	if cover_id == WorldCover.MARSH and family_id != SALT:
		return false
	var mining := family_id == MINES or family_id == QUARRY
	var upland_cover := cover_id == WorldCover.WOODS or cover_id == WorldCover.GRASSLAND
	# The level's reach: level 2 near a place or on a road; level 3 within two hexes of a town and not in the hills
	# (a mine or a quarry is in the hills by its nature: it needs the town and a road instead).
	if level_value >= 2 and not (place <= 2 or road):
		return false
	if level_value == 3:
		if town > 2:
			return false
		if mining and not road:
			return false
		if not mining and not coast and metres > HIGH_M - 200.0:
			return false
	match family_id:
		WHEAT:
			return cover_id == WorldCover.FARMLAND and metres <= 600.0
		HEMP:
			return cover_id == WorldCover.FARMLAND and river and metres <= 400.0
		SILK:
			return (cover_id == WorldCover.FARMLAND or cover_id == WorldCover.GRASSLAND) and metres <= 600.0 \
				and town <= 2 and climate != "snow"
		DYES:
			return (cover_id == WorldCover.FARMLAND or cover_id == WorldCover.GRASSLAND) and metres <= 500.0 \
				and town <= 1
		VINEYARD:
			return (cover_id == WorldCover.GRASSLAND or cover_id == WorldCover.FARMLAND) and metres >= 100.0 \
				and metres <= 900.0 and climate != "snow"
		OLIVES:
			# Warm coast hills: the mild winter only. A coast hex is settled at its shore, whatever its heights.
			return climate == "mild" and (coast or metres <= 900.0) and (cover_id == WorldCover.GRASSLAND \
				or cover_id == WorldCover.FARMLAND or cover_id == WorldCover.WOODS)
		GRAZING:
			# Meadows, and the upland: the wooded foothills carry flocks too.
			return cover_id == WorldCover.GRASSLAND or (cover_id == WorldCover.WOODS and metres >= UPLAND_M)
		TIMBER:
			return cover_id == WorldCover.WOODS and metres <= 1800.0
		MINES:
			return cover_id == WorldCover.ROCK or (metres >= 1000.0 and upland_cover)
		QUARRY:
			return cover_id == WorldCover.ROCK or (metres >= UPLAND_M and upland_cover)
		SALT:
			# A low shore: sand or marsh anywhere, and a farmed or grass shore without high ground in the mild winter
			# (pans need a flat shore: a hex whose highest ground is in the hills has a cliff coast).
			var flat := cover_id == WorldCover.SAND or cover_id == WorldCover.MARSH
			var warm := climate == "mild" and metres <= HILLS_M 				and (cover_id == WorldCover.FARMLAND or cover_id == WorldCover.GRASSLAND)
			return coast and (flat or warm)
		HARBOUR:
			# A fishing harbour: a coast that is not a port's own hex nor beside one (the port is the harbour there).
			return coast and cover_id != WorldCover.ROCK and not bool(facts.get("port_near", false))
	return false


## Whether two options may stand `radius` (1 or 2) hexes apart (the pair rules).
static func pair_allowed(family_a: int, level_a: int, family_b: int, level_b: int, radius: int) -> bool:
	return pair_reason(family_a, level_a, family_b, level_b, radius) == ""


## The reason of the first pair rule two options break at a distance, or "" when they may stand there.
static func pair_reason(family_a: int, level_a: int, family_b: int, level_b: int, radius: int) -> String:
	# The memo key packs families below 16, levels below 8 and radius below 4: a bigger value would collide.
	assert(family_a < 16 and family_b < 16 and level_a < 8 and level_b < 8 and radius < 4, "pair_reason memo key range")
	var key := (((family_a * 8 + level_a) * 16 + family_b) * 8 + level_b) * 4 + radius
	var held: Variant = _pair_memo.get(key)
	if held != null:
		return held as String
	var why := _pair_reason_of(family_a, level_a, family_b, level_b, radius)
	_pair_memo[key] = why
	return why


## pair_reason is a pure function of constants: each answer is worked out once.
static var _pair_memo: Dictionary = {}


static func _pair_reason_of(family_a: int, level_a: int, family_b: int, level_b: int, radius: int) -> String:
	for rule: Array in PAIR_RULES:
		if radius > int(rule[4]):
			continue
		var a := _rule_side(int(rule[0]), int(rule[1]), family_a, level_a)
		var b := _rule_side(int(rule[2]), int(rule[3]), family_b, level_b)
		if a and b:
			return str(rule[5])
		a = _rule_side(int(rule[0]), int(rule[1]), family_b, level_b)
		b = _rule_side(int(rule[2]), int(rule[3]), family_a, level_a)
		if a and b:
			return str(rule[5])
	return ""


## What a family needs of the ground, for a refusal (index: family).
const GROUND_NEEDS: Array[String] = [
	"", "", "castles stand on passes", "wheat needs low farmland", "hemp needs farmland at a river or stream",
	"silk needs farmland or meadow within two hexes of a town", "a dye works needs farmland or meadow beside a town",
	"vines need sunny farmland or hills", "olives need the mild winter on the warm coast or its hills",
	"grazing needs meadow or upland woods", "timber needs woods", "a mine needs rock or high ground",
	"a quarry needs rock or upland", "salt pans need a low shore", "a fishing harbour needs a coast with no port beside it",
]


## Why a family at a level does not fit a free hex with these facts, in plain words; "" when it does (cell_allowed).
static func cell_reason(family_id: int, level_value: int, facts: Dictionary) -> String:
	if cell_allowed(family_id, level_value, facts):
		return ""
	if family_id <= NONE or family_id >= FAMILIES or family_id == SETTLEMENT or family_id == CASTLE:
		return "nothing of that kind can be built here"
	var cover_id := int(facts.get("cover", -1))
	var metres := float(facts.get("height_m", 0.0))
	if metres > TOP_M:
		return "too high: the rock and snow above stay wild"
	if cover_id == WorldCover.SNOW or cover_id == WorldCover.TUNDRA:
		return "snow and tundra stay wild"
	if cover_id == WorldCover.MARSH and family_id != SALT:
		return "marsh stays wild"
	var mining := family_id == MINES or family_id == QUARRY
	if level_value >= 2 and not (int(facts.get("place_distance", 99)) <= 2 or bool(facts.get("road", false))):
		return "level %d needs a place within two hexes or a road" % level_value
	if level_value == 3:
		if int(facts.get("town_distance", 99)) > 2:
			return "level 3 needs a town within two hexes"
		if mining and not bool(facts.get("road", false)):
			return "level 3 needs a road"
		if not mining and not bool(facts.get("coast", false)) and metres > HIGH_M - 200.0:
			return "too high for the third stage"
	return GROUND_NEEDS[family_id] if GROUND_NEEDS[family_id] != "" else "the ground does not fit"


static func _rule_side(rule_family: int, rule_level: int, family_id: int, level_value: int) -> bool:
	if level_value < rule_level:
		return false
	if rule_family == ANY_GOODS:
		return family_id >= WHEAT
	return family_id == rule_family


## Which picture a hex shows: Vector2i(variant, mirror 0 or 1), from the hex alone (the kit's kit.pick, the same
## numbers). With two layouts or more no two neighbours get the same picture.
static func pick(hex: Vector2i, variants: int) -> Vector2i:
	var col := hex.x
	var row := hex.y
	var q := col - ((row - (row & 1)) >> 1)
	var cls := posmod(q - row, 3)
	var h := ((col * 73856093) ^ (row * 19349663)) & 0xffffffff
	h = ((h ^ (h >> 13)) * 0x5bd1e995) & 0xffffffff
	var bit := (h >> 15) & 1
	if variants >= 3:
		var v := cls
		if cls == 0 and variants > 3:
			var turn := (h >> 17) % (variants - 2)
			v = 0 if turn == 0 else turn + 2
		return Vector2i(v, bit)
	var last := maxi(1, variants) - 1
	if cls == 1:
		return Vector2i(last, 0)
	if cls == 2:
		return Vector2i(0, 1)
	return Vector2i(last, 1) if bit == 1 else Vector2i(0, 0)


## The eight sea sides of the coast pieces and their directions on screen (x right, y down; the kit's kit.SIDES: the
## slanted ones point at the hex's lower and upper neighbours, 55.8 degrees from the row).
const SEA_SIDES: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const SEA_SIDE_DEGREES: Array[float] = [0.0, 55.8, 90.0, 124.2, 180.0, -124.2, -90.0, -55.8]


## The sea side nearest to a direction on screen in degrees (0 east, 90 south): the "extra" of a coast piece's key.
static func sea_side(angle_degrees: float) -> String:
	var best := 0
	var best_gap := 999.0
	for k: int in SEA_SIDES.size():
		var gap := absf(wrapf(angle_degrees - SEA_SIDE_DEGREES[k], -180.0, 180.0))
		if gap < best_gap:
			best_gap = gap
			best = k
	return SEA_SIDES[best]


## The distance in hexes between two hexes (odd rows shifted right).
static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var aq := a.x - ((a.y - (a.y & 1)) >> 1)
	var bq := b.x - ((b.y - (b.y & 1)) >> 1)
	var dq := aq - bq
	var dr := a.y - b.y
	return maxi(maxi(absi(dq), absi(dr)), absi(dq + dr))


## The neighbour of a hex in edge order (0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE), as HexGrid.neighbour.
static func neighbour(hex: Vector2i, direction: int) -> Vector2i:
	var odd := (hex.y & 1) == 1
	match direction:
		0:
			return hex + Vector2i(1, 0)
		1:
			return hex + (Vector2i(1, -1) if odd else Vector2i(0, -1))
		2:
			return hex + (Vector2i(0, -1) if odd else Vector2i(-1, -1))
		3:
			return hex + Vector2i(-1, 0)
		4:
			return hex + (Vector2i(0, 1) if odd else Vector2i(-1, 1))
	return hex + (Vector2i(1, 1) if odd else Vector2i(0, 1))


## The fit of a family to a hex's ground (the level and the wild share come after).
static func fit(family_id: int, facts: Dictionary) -> float:
	var cover_id := int(facts["cover"])
	var metres := float(facts["height_m"])
	var river := bool(facts["river"])
	var coast := bool(facts["coast"])
	var mild := str(facts["climate"]) == "mild"
	match family_id:
		WHEAT:
			return 3.0
		HEMP:
			return 1.3
		SILK:
			return 0.9 if cover_id == WorldCover.FARMLAND else 0.6
		DYES:
			return 1.2 if river or coast else 0.5
		VINEYARD:
			if cover_id == WorldCover.FARMLAND:
				return 1.1 if metres >= 200.0 else 0.3
			return 2.2 if metres <= 600.0 else 1.2
		OLIVES:
			if cover_id == WorldCover.WOODS:
				return 0.7
			return 2.6 if cover_id == WorldCover.GRASSLAND else 1.0
		GRAZING:
			if cover_id == WorldCover.WOODS:
				return 0.6
			return 1.6 if metres >= 300.0 else 1.0
		TIMBER:
			return 1.6 * (1.3 if river else 1.0)
		MINES:
			return 1.0 if cover_id == WorldCover.ROCK else 0.35
		QUARRY:
			return 0.7 if cover_id == WorldCover.ROCK else 0.3
		SALT:
			return 2.5 if cover_id == WorldCover.SAND or cover_id == WorldCover.MARSH else (1.2 if mild else 0.0)
		HARBOUR:
			return 0.9
	return 0.0


## The weight of a level on a hex: level 1 is the common one; the higher ones grow near towns and roads and fall in
## the hills.
static func level_weight(level_value: int, facts: Dictionary) -> float:
	if level_value <= 1:
		return 1.0
	var town := int(facts["town_distance"])
	var city := int(facts["city_distance"])
	var metres := float(facts["height_m"])
	var reach := 0.45
	if city <= 1:
		reach = 1.5
	elif town <= 1:
		reach = 1.1
	elif town <= 2:
		reach = 0.8
	if bool(facts["road"]):
		reach *= 1.3
	if metres > HIGH_M:
		reach *= 0.4
	elif metres > HILLS_M:
		reach *= 0.65
	return reach if level_value == 2 else reach * 0.45


## The share of a hex's weight that goes to "none".
static func wild_share(facts: Dictionary) -> float:
	var share := WILD_SHARE
	var town := int(facts["town_distance"])
	if int(facts["city_distance"]) <= 1:
		share = WILD_AT_CITY
	elif town <= 1:
		share = WILD_AT_TOWN
	elif town <= 2:
		share = WILD_NEAR_TOWN
	elif bool(facts["road"]) or int(facts["place_distance"]) <= 1:
		share = WILD_BY_ROAD
	var metres := float(facts["height_m"])
	if metres > HIGH_M:
		share = 1.0 - (1.0 - share) * 0.45
	elif metres > HILLS_M:
		share = 1.0 - (1.0 - share) * 0.75
	return share
