## The improvement of each land hex of the normal map (docs/design/map/06-growing-map.md section 2 and the pieces guide,
## docs/design/map/pieces/GUIDE.md sections 6, 8 and 10): which piece family stands on a hex and at which level, chosen
## by wave function collapse, so that a hex's piece fits its own ground and its neighbours' pieces.
##
## The input is the baked hex table of a region (meta.json "hexes": c, r, land, cover, height_m, coast, sea_angle,
## climate, river_edges, road, pass, place). The ground (cover, relief, water, roads, places) is fixed before this
## step: the solver only chooses the improvement.
##
## An option is a (family, level) pair: "none" (level 0: no piece, the hex stays wild), settlements 1 to 5, castles 1
## to 3 and twelve goods families 1 to 3. Furs and cotton have no place in north Italy and are not in the list.
##
## Cell rules (hard, see cell_allowed): the family's ground (wheat on low farmland, timber in woods, mines and quarries
## on rock or high ground, olives only in the mild winter, salt and fishing harbours only on the coast, hemp only at a
## river or stream, dye works beside a town, silk within two hexes of one); the level's reach (level 2 near a place or a road,
## level 3 within two hexes of a town and not in the hills). Fixed cells: a place of the data is a settlement of its
## level and nothing else; a pass takes a watchtower, a castle or nothing; snow, marsh and tundra stay wild.
##
## Neighbour rules (hard, PAIR_RULES: pairs of options that may not stand within one or two hexes of each other).
##
## Weights (soft): the family's fit to the ground; the level's weight grows near towns and roads and falls with the
## height; a share of each hex's weight goes to "none" (WILD_SHARE and the factors beside it), so most of the map stays
## wild; a neighbour of the same family raises a family's weight (AFFINITY: fields and vines come in districts) and a
## neighbour with the very same family and level lowers it (SAME_PENALTY: the map must not tile).
##
## Search: as in WorldCover. Propagation narrows the hexes within two hexes of each choice; a dead end undoes the last
## choice and strikes it out (backtracking); a search that uses up its budget restarts with the next draw of luck; after
## RETRIES restarts the undecided hexes stay wild and are listed (none expected). Since "none" may stand anywhere and
## next to anything, the region itself needs no backtrack; the tests force dead ends on small instances.
##
## Variant and mirror of each piece come from the hex alone (pick: the kit's kit.pick), so that two equal neighbours
## never show the same picture. Determinism: one Rng seeded by the caller; ties broken by a drawn order, never by the
## order of a dictionary. Pure: no files, no engine calls.
class_name WorldImprove
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
const FAMILIES := 15
## The names are the piece modules' names: the first part of a key of the baked piece index.
const NAMES: Array[String] = [
	"none", "settlements", "castles", "wheat", "hemp", "silk", "dyes", "vineyard", "olives", "grazing", "timber",
	"mines", "quarry", "salt", "harbour",
]
const TOP_LEVEL: Array[int] = [0, 5, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3]
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

## The family and the level of each land hex (family NONE and level 0 for a wild hex).
var family: Dictionary[Vector2i, int] = {}
var level: Dictionary[Vector2i, int] = {}
## The land hexes in (row, column) order.
var hexes: Array[Vector2i] = []
var by_family: PackedInt32Array = PackedInt32Array()  # index: family; the count of hexes
var by_level: PackedInt32Array = PackedInt32Array()  # index: family * 6 + level
var backtracks: int = 0  # dead ends undone (all attempts)
var restarts: int = 0  # searches given up after the backtrack budget
var contradictions: int = 0  # propagation wipe-outs
var input_dead_ends: int = 0  # hexes with no option before any choice (a data error; none expected)
var fixed_conflicts: Array[String] = []  # pairs of fixed places that break a pair rule (data, not a choice)
var last_resort: Array[Vector2i] = []  # hexes left wild by the fallback (none expected)

var _cells: Array[Vector2i] = []
var _index: Dictionary[Vector2i, int] = {}
var _facts: Array[Dictionary] = []
var _fixed: PackedByteArray = PackedByteArray()  # 1: the data decides this hex (a place)
var _nbr: PackedInt32Array = PackedInt32Array()  # six per cell: the neighbouring land cell or -1
var _ring2: Array[PackedInt32Array] = []  # per cell: the land cells exactly two hexes away
var _prior: PackedFloat32Array = PackedFloat32Array()  # one per cell and option; zero when not allowed
var _initial: PackedInt64Array = PackedInt64Array()
var _dom: PackedInt64Array = PackedInt64Array()
var _count: PackedInt32Array = PackedInt32Array()  # options left in each domain
var _single: PackedInt32Array = PackedInt32Array()  # the option of a decided cell, else -1
var _order: PackedInt32Array = PackedInt32Array()  # the drawn order that breaks ties between cells
var _compat1: PackedInt64Array = PackedInt64Array()  # per option: the options it may touch
var _compat2: PackedInt64Array = PackedInt64Array()  # per option: the options it may have two hexes away
var _opt_family: PackedInt32Array = PackedInt32Array()
var _opt_level: PackedInt32Array = PackedInt32Array()
var _all: int = 0  # every option's bit
var _trail_cell: PackedInt32Array = PackedInt32Array()
var _trail_old: PackedInt64Array = PackedInt64Array()
var _frame_cell: PackedInt32Array = PackedInt32Array()
var _frame_opt: PackedInt32Array = PackedInt32Array()
var _frame_tried: PackedInt64Array = PackedInt64Array()
var _frame_before: PackedInt64Array = PackedInt64Array()
var _frame_start: PackedInt32Array = PackedInt32Array()
var _rng: Rng = null
var _attempt_backtracks: int = 0


## The improvement of every land hex of a baked hex table (meta.json "hexes"), from one seed.
static func build(hex_table: Array, seed_value: int) -> WorldImprove:
	var out := WorldImprove.new()
	out._make_options()
	out._collect(hex_table)
	out._build_priors()
	out._search(seed_value)
	out._finish()
	return out


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
	for rule: Array in PAIR_RULES:
		if radius > int(rule[4]):
			continue
		var a := _rule_side(int(rule[0]), int(rule[1]), family_a, level_a)
		var b := _rule_side(int(rule[2]), int(rule[3]), family_b, level_b)
		if a and b:
			return false
		a = _rule_side(int(rule[0]), int(rule[1]), family_b, level_b)
		b = _rule_side(int(rule[2]), int(rule[3]), family_a, level_a)
		if a and b:
			return false
	return true


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


## The neighbour of a hex in edge order (0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE), as WorldGrid.neighbour.
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


func family_at(hex: Vector2i) -> int:
	return int(family.get(hex, NONE))


func level_at(hex: Vector2i) -> int:
	return int(level.get(hex, 0))


## The facts the rules read for a land hex: cover (a WorldCover number), height_m, coast, river, road, pass, climate,
## place_level, port, port_mode, landmark, place_distance, town_distance, city_distance, port_near, sea_angle.
func facts_at(hex: Vector2i) -> Dictionary:
	if not _index.has(hex):
		return {}
	return _facts[int(_index[hex])]


## What the map draws on a hex: {} for a wild hex, else family (the piece module's name), family_id, level, variant,
## mirror, extra ("-", an animal, an ore or a landmark's name), sea (the sea side of a coast hex, "" inland), and for a
## port addon (the harbour add-on's level, 0 for none) and addon_mode ("carved" or "seaside").
func piece_at(hex: Vector2i) -> Dictionary:
	var f := family_at(hex)
	if f == NONE:
		return {}
	var facts := facts_at(hex)
	var lv := level_at(hex)
	var chosen := pick(hex, VARIANTS[f])
	var extra := "-"
	var h := _hash(hex)
	if f == GRAZING:
		# Cattle on the low meadows, horses on some of them, sheep on the hills and the high pastures.
		var metres := float(facts.get("height_m", 0.0))
		if metres < 300.0:
			extra = ANIMALS[2] if h % 3 == 0 else ANIMALS[1]
		else:
			extra = ANIMALS[1] if (metres < 700.0 and h % 4 == 0) else ANIMALS[0]
	elif f == MINES:
		extra = ORES[0] if h % 10 < 5 else (ORES[1] if h % 10 < 8 else ORES[2])
	elif f == SETTLEMENT and str(facts.get("landmark", "")) != "":
		extra = str(facts.get("landmark", ""))
	var addon := 0
	if f == SETTLEMENT and bool(facts.get("port", false)) and bool(facts.get("coast", false)):
		addon = ADDON_LEVEL[clampi(lv, 0, 5)]  # a port whose hex has no shore on this map shows no harbour
	return {
		"family": NAMES[f],
		"family_id": f,
		"level": lv,
		"variant": chosen.x,
		"mirror": chosen.y == 1,
		"extra": extra,
		"addon": addon,
		"sea": sea_side(float(facts.get("sea_angle", 90.0))) if bool(facts.get("coast", false)) else "",
		"addon_mode": str(facts.get("port_mode", "seaside")) if addon > 0 else "",
	}


func count_of(family_id: int) -> int:
	return int(by_family[family_id]) if family_id >= 0 and family_id < FAMILIES else 0


func count_at(family_id: int, level_value: int) -> int:
	return int(by_level[family_id * 6 + level_value])


## Every pair rule and cell rule the result breaks, as text (none expected; the tests and the tools print it).
## Pairs of fixed places are not listed here: they are in fixed_conflicts.
func violations() -> Array[String]:
	var out: Array[String] = []
	for hex: Vector2i in hexes:
		var f := family_at(hex)
		var lv := level_at(hex)
		var i := int(_index[hex])
		if _fixed[i] == 0 and f != NONE and f != CASTLE and not cell_allowed(f, lv, _facts[i]):
			out.append("%s: %s %d breaks a cell rule" % [hex, NAMES[f], lv])
		if f == NONE:
			continue
		for other: Vector2i in hexes:
			if other == hex or (other.y < hex.y or (other.y == hex.y and other.x < hex.x)):
				continue
			var distance := hex_distance(hex, other)
			if distance > 2:
				continue
			var j := int(_index[other])
			if _fixed[i] == 1 and _fixed[j] == 1:
				continue
			if not pair_allowed(f, lv, family_at(other), level_at(other), distance):
				out.append("%s %s %d and %s %s %d, %d apart" % [hex, NAMES[f], lv, other, NAMES[family_at(other)],
					level_at(other), distance])
	return out


## Counts for the report and the tests.
func summary() -> Dictionary:
	var names: Dictionary[String, int] = {}
	var levels: Dictionary[String, Array] = {}
	var pieces := 0
	for f: int in range(1, FAMILIES):
		names[NAMES[f]] = count_of(f)
		pieces += count_of(f)
		var row: Array[int] = []
		for lv: int in range(1, TOP_LEVEL[f] + 1):
			row.append(count_at(f, lv))
		levels[NAMES[f]] = row
	return {
		"hexes": hexes.size(),
		"pieces": pieces,
		"wild": count_of(NONE),
		"by_family": names,
		"by_level": levels,
		"backtracks": backtracks,
		"restarts": restarts,
		"contradictions": contradictions,
		"input_dead_ends": input_dead_ends,
		"fixed_conflicts": fixed_conflicts.size(),
		"last_resort": last_resort.size(),
	}


# ----- inputs -------------------------------------------------------------------------------------------------------


func _make_options() -> void:
	var n := option_count()
	_opt_family.resize(n)
	_opt_level.resize(n)
	_opt_family[0] = NONE
	_opt_level[0] = 0
	var at := 1
	for f: int in range(1, FAMILIES):
		for lv: int in range(1, TOP_LEVEL[f] + 1):
			_opt_family[at] = f
			_opt_level[at] = lv
			at += 1
	_all = (1 << n) - 1
	_compat1.resize(n)
	_compat2.resize(n)
	for a: int in n:
		var near := 0
		var far := 0
		for b: int in n:
			if pair_allowed(_opt_family[a], _opt_level[a], _opt_family[b], _opt_level[b], 1):
				near = near | (1 << b)
			if pair_allowed(_opt_family[a], _opt_level[a], _opt_family[b], _opt_level[b], 2):
				far = far | (1 << b)
		_compat1[a] = near
		_compat2[a] = far


## Whether a value of the hex table says yes: true, a number that is not zero, a name, a list with something in it.
static func _flag(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return bool(value)
		TYPE_INT, TYPE_FLOAT:
			return float(value) != 0.0
		TYPE_STRING, TYPE_STRING_NAME:
			var text := str(value)
			return text != "" and text != "none" and text != "-"
		TYPE_ARRAY:
			var list: Array = value
			return not list.is_empty()
		TYPE_DICTIONARY:
			var table: Dictionary = value
			return not table.is_empty()
	return false


static func _cover_id(value: Variant) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	var word := str(value).to_lower().get_slice(" ", 0)
	for c: int in COVER_WORDS.size():
		if word == COVER_WORDS[c] or word == COVER_WORDS[c].trim_suffix("land") or word + "s" == COVER_WORDS[c]:
			return c
	return -1


static func _hash(hex: Vector2i) -> int:
	var h := ((hex.x * 73856093) ^ (hex.y * 19349663)) & 0xffffffff
	h = ((h ^ (h >> 13)) * 0x5bd1e995) & 0xffffffff
	return (h >> 7) & 0xffff


func _collect(hex_table: Array) -> void:
	var rows: Dictionary[Vector2i, Dictionary] = {}
	for entry: Variant in hex_table:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = entry
		if not _flag(row.get("land", false)):
			continue
		var hex := Vector2i(int(row.get("c", 0)), int(row.get("r", 0)))
		rows[hex] = row
		_cells.append(hex)
	_cells.sort_custom(func(p: Vector2i, q: Vector2i) -> bool:
		return p.y < q.y or (p.y == q.y and p.x < q.x))
	var n := _cells.size()
	for i: int in n:
		_index[_cells[i]] = i
	_nbr.resize(n * 6)
	_nbr.fill(-1)
	_fixed.resize(n)
	_fixed.fill(0)
	var settled: Array[Vector3i] = []  # x, y: the hex; z: the level
	var ports: Array[Vector2i] = []
	for i: int in n:
		var hex := _cells[i]
		var row: Dictionary = rows[hex]
		var facts: Dictionary = {
			"cover": _cover_id(row.get("cover", "")),
			"height_m": float(row.get("height_m", 0.0)),
			"coast": _flag(row.get("coast", false)),
			"sea_angle": float(row.get("sea_angle", 0.0)) if typeof(row.get("sea_angle")) in [TYPE_INT, TYPE_FLOAT] else 0.0,
			# Water at the hex's border: a river edge, or a stream edge (hemp rets in either).
			"river": _flag(row.get("river_edges", null)) or _flag(row.get("stream_edges", null)),
			"road": _flag(row.get("road", false)),
			"pass": _flag(row.get("pass", false)),
			"climate": str(row.get("climate", "frost")),
			"place_level": 0,
			"port": false,
			"port_mode": "",
			"landmark": "",
		}
		var place: Variant = row.get("place", null)
		if typeof(place) == TYPE_DICTIONARY:
			var p: Dictionary = place
			var lv := clampi(int(p.get("level", 1)), 1, TOP_LEVEL[SETTLEMENT])
			facts["place_level"] = lv
			facts["port"] = _flag(p.get("port", false))
			facts["port_mode"] = str(p.get("port_mode", "seaside")) if bool(facts["port"]) else ""
			facts["landmark"] = str(p.get("landmark", "")) if _flag(p.get("landmark", null)) else ""
			settled.append(Vector3i(hex.x, hex.y, lv))
			if bool(facts["port"]):
				ports.append(hex)
			_fixed[i] = 1
		_facts.append(facts)
		for d: int in 6:
			var nb := neighbour(hex, d)
			if _index.has(nb):
				_nbr[i * 6 + d] = int(_index[nb])
	for i: int in n:
		var hex := _cells[i]
		var ring := PackedInt32Array()
		var seen: Dictionary[int, bool] = {}
		for d: int in 6:
			var first := neighbour(hex, d)
			for e: int in 6:
				var second := neighbour(first, e)
				if _index.has(second) and hex_distance(hex, second) == 2 and not seen.has(int(_index[second])):
					seen[int(_index[second])] = true
					ring.append(int(_index[second]))
		ring.sort()
		_ring2.append(ring)
		var facts := _facts[i]
		var near_place := 99
		var near_town := 99
		var near_city := 99
		for s: Vector3i in settled:
			var distance := hex_distance(hex, Vector2i(s.x, s.y))
			if distance == 0:
				continue
			near_place = mini(near_place, distance)
			if s.z >= 3:
				near_town = mini(near_town, distance)
			if s.z >= 4:
				near_city = mini(near_city, distance)
		var port_near := bool(facts["port"])
		for p: Vector2i in ports:
			if hex_distance(hex, p) <= 1:
				port_near = true
		facts["place_distance"] = near_place
		facts["town_distance"] = near_town
		facts["city_distance"] = near_city
		facts["port_near"] = port_near
	# Fixed places that break a pair rule are data: listed, and left as they are.
	for a: int in settled.size():
		for b: int in range(a + 1, settled.size()):
			var ha := Vector2i(settled[a].x, settled[a].y)
			var hb := Vector2i(settled[b].x, settled[b].y)
			var distance := hex_distance(ha, hb)
			if distance <= 2 and not pair_allowed(SETTLEMENT, settled[a].z, SETTLEMENT, settled[b].z, distance):
				fixed_conflicts.append("%s (level %d) and %s (level %d)" % [ha, settled[a].z, hb, settled[b].z])


# ----- the cell rules and the weights -------------------------------------------------------------------------------


## The options of one hex as bits: a place is its settlement; a pass is nothing, a watchtower or a castle; every other
## hex is "none" and what the cell rules allow.
func _domain_of(i: int) -> int:
	var facts := _facts[i]
	var place_level := int(facts["place_level"])
	if place_level > 0:
		return 1 << option_of(SETTLEMENT, place_level)
	var mask := 1
	if bool(facts["pass"]):
		return mask | (1 << option_of(CASTLE, 1)) | (1 << option_of(CASTLE, 2))
	for opt: int in range(1, _opt_family.size()):
		if cell_allowed(_opt_family[opt], _opt_level[opt], facts):
			mask = mask | (1 << opt)
	return mask


## The fit of a family to a hex's ground (the level and the wild share come after).
static func _fit(family_id: int, facts: Dictionary) -> float:
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
static func _level_weight(level_value: int, facts: Dictionary) -> float:
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
static func _wild_share(facts: Dictionary) -> float:
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


func _build_priors() -> void:
	var n := _cells.size()
	var options := _opt_family.size()
	_prior.resize(n * options)
	_prior.fill(0.0)
	_initial.resize(n)
	for i: int in n:
		var facts := _facts[i]
		var mask := _domain_of(i)
		_initial[i] = mask
		if mask == 0:
			input_dead_ends += 1
			continue
		var worked := 0.0
		for opt: int in range(1, options):
			if ((mask >> opt) & 1) == 0:
				continue
			var f := _opt_family[opt]
			var w := 1.0
			if f == CASTLE:
				# A pass on a road is worth holding; the castle proper is the rarer one.
				w = (1.0 if _opt_level[opt] == 1 else 0.6) * (1.0 if bool(facts["road"]) else 0.7)
			elif f != SETTLEMENT:
				w = _fit(f, facts) * _level_weight(_opt_level[opt], facts)
			w = maxf(w, 0.001)
			_prior[i * options + opt] = w
			worked += w
		if (mask & 1) == 1:
			var share := (PASS_OPEN_BY_ROAD if bool(facts["road"]) else PASS_OPEN) if bool(facts["pass"]) else _wild_share(facts)
			_prior[i * options] = maxf(worked, 0.001) * share / (1.0 - share)


# ----- the search ---------------------------------------------------------------------------------------------------


func _search(seed_value: int) -> void:
	_rng = Rng.new()
	_rng.seed_with(seed_value)
	var n := _initial.size()
	_count.resize(n)
	_single.resize(n)
	_order.resize(n)
	for _attempt: int in RETRIES + 1:
		_reset_domains()
		for i: int in n:
			_order[i] = _rng.randi_range(0, 1 << 30)
		_trail_cell.clear()
		_trail_old.clear()
		_clear_frames()
		_attempt_backtracks = 0
		var queue: Array[int] = []
		for i: int in n:
			if _count[i] == 1:
				queue.append(i)
		if not _propagate(queue):
			input_dead_ends += 1
			_reset_domains()
		if _run():
			return
		restarts += 1
	# Last resort: every hex still open stays wild (or takes its first option where "none" is not allowed).
	_reset_domains()
	for i: int in n:
		if _count[i] > 1:
			var keep := 1 if (int(_initial[i]) & 1) == 1 else (1 << _lowest_bit(int(_initial[i])))
			_set_dom(i, keep)
			last_resort.append(_cells[i])


func _reset_domains() -> void:
	_dom = _initial.duplicate()
	for i: int in _dom.size():
		_count[i] = _popcount(int(_dom[i]))
		_single[i] = _lowest_bit(int(_dom[i])) if _count[i] == 1 else -1


func _set_dom(cell: int, mask: int) -> void:
	_dom[cell] = mask
	var count := _popcount(mask)
	_count[cell] = count
	_single[cell] = _lowest_bit(mask) if count == 1 else -1


## The backtracking loop of WorldCover._run: a frame is one decision; a dead end restores the newest frame and strikes
## its option; a frame with no option left is popped and the one below it restored in turn.
func _run() -> bool:
	var contradiction := false
	var result := false
	var running := true
	while running:
		if not contradiction:
			var cell := _pick_cell()
			if cell < 0:
				result = true
				running = false
			else:
				var opt := _pick_option(cell, int(_dom[cell]))
				_frame_cell.append(cell)
				_frame_opt.append(opt)
				_frame_tried.append(0)
				_frame_before.append(_dom[cell])
				_frame_start.append(_trail_cell.size())
				contradiction = not _assign(cell, opt)
		else:
			if _frame_cell.is_empty() or _attempt_backtracks >= BACKTRACK_LIMIT:
				running = false
			else:
				_attempt_backtracks += 1
				backtracks += 1
				var top := _frame_cell.size() - 1
				_restore(int(_frame_start[top]))
				var tried := int(_frame_tried[top]) | (1 << int(_frame_opt[top]))
				_frame_tried[top] = tried
				var rem := int(_frame_before[top]) & ~tried
				if rem == 0:
					_pop_frame()
				else:
					var cell := int(_frame_cell[top])
					var opt := _pick_option(cell, rem)
					_frame_opt[top] = opt
					contradiction = not _assign(cell, opt)
	return result


func _clear_frames() -> void:
	_frame_cell.clear()
	_frame_opt.clear()
	_frame_tried.clear()
	_frame_before.clear()
	_frame_start.clear()


func _pop_frame() -> void:
	var top := _frame_cell.size() - 1
	_frame_cell.resize(top)
	_frame_opt.resize(top)
	_frame_tried.resize(top)
	_frame_before.resize(top)
	_frame_start.resize(top)


## The undecided cell with the fewest options; ties go to the lowest drawn order (not to the map's rows, so the
## districts do not grow in stripes). -1 when all are decided. A linear scan: fine for a region; Europe needs a heap.
func _pick_cell() -> int:
	var best := -1
	var best_count := 1 << 20
	var best_order := 0
	for i: int in _count.size():
		var count := _count[i]
		if count <= 1:
			continue
		if count < best_count or (count == best_count and _order[i] < best_order):
			best_count = count
			best_order = _order[i]
			best = i
	return best


## One option of a domain, drawn by weight: the prior, raised by decided neighbours of the same family and lowered by
## decided neighbours with the very same family and level.
func _pick_option(cell: int, mask: int) -> int:
	var options := _opt_family.size()
	var same_family := PackedInt32Array()
	same_family.resize(FAMILIES)
	same_family.fill(0)
	var same_option: Dictionary[int, int] = {}
	for d: int in 6:
		var nb := int(_nbr[cell * 6 + d])
		if nb < 0 or _single[nb] < 0:
			continue
		var opt := _single[nb]
		same_family[_opt_family[opt]] += 1
		same_option[opt] = int(same_option.get(opt, 0)) + 1
	var picked: Array[int] = []
	var weights: Array[float] = []
	var total := 0.0
	for opt: int in options:
		if ((mask >> opt) & 1) == 0:
			continue
		var f := _opt_family[opt]
		var w := maxf(float(_prior[cell * options + opt]), 0.0001)
		if f == NONE:
			w *= 1.0 + WILD_AFFINITY * float(same_family[NONE])
		else:
			w *= 1.0 + AFFINITY[f] * float(same_family[f])
			w *= pow(SAME_PENALTY, float(int(same_option.get(opt, 0))))
		picked.append(opt)
		weights.append(w)
		total += w
	var x := _rng.randf() * total
	var acc := 0.0
	for k: int in picked.size():
		acc += weights[k]
		if x < acc:
			return picked[k]
	return picked[picked.size() - 1]


func _assign(cell: int, opt: int) -> bool:
	_push_trail(cell, int(_dom[cell]))
	_set_dom(cell, 1 << opt)
	var queue: Array[int] = [cell]
	return _propagate(queue)


## Narrows the cells within two hexes of each queued cell to what its domain allows; false on a wipe-out. A fixed
## place is never narrowed (its conflicts are data: fixed_conflicts).
func _propagate(queue: Array[int]) -> bool:
	while not queue.is_empty():
		var j: int = queue.pop_back()
		var mask := int(_dom[j])
		var near := _support(mask, _compat1)
		if near != _all:
			for d: int in 6:
				var k := int(_nbr[j * 6 + d])
				if k >= 0 and not _narrow(k, near, queue):
					return false
		var far := _support(mask, _compat2)
		if far != _all and j < _ring2.size():
			for k: int in _ring2[j]:
				if not _narrow(k, far, queue):
					return false
	return true


func _narrow(cell: int, allow: int, queue: Array[int]) -> bool:
	if not _fixed.is_empty() and _fixed[cell] == 1:
		return true
	var before := int(_dom[cell])
	var after := before & allow
	if after == before:
		return true
	_push_trail(cell, before)
	_set_dom(cell, after)
	if after == 0:
		contradictions += 1
		return false
	queue.append(cell)
	return true


## The options some option of a domain allows beside it. "None" allows everything, so an open hex narrows nothing.
func _support(mask: int, table: PackedInt64Array) -> int:
	if (mask & 1) == 1 and (int(table[0]) == _all):
		return _all
	var got := 0
	var m := mask
	var opt := 0
	while m != 0:
		if (m & 1) == 1:
			got = got | int(table[opt])
			if got == _all:
				return got
		m = m >> 1
		opt += 1
	return got


func _push_trail(cell: int, old: int) -> void:
	_trail_cell.append(cell)
	_trail_old.append(old)


func _restore(start: int) -> void:
	while _trail_cell.size() > start:
		var last := _trail_cell.size() - 1
		_set_dom(int(_trail_cell[last]), int(_trail_old[last]))
		_trail_cell.resize(last)
		_trail_old.resize(last)


func _finish() -> void:
	by_family.resize(FAMILIES)
	by_family.fill(0)
	by_level.resize(FAMILIES * 6)
	by_level.fill(0)
	hexes = _cells.duplicate()
	for i: int in _cells.size():
		var opt := maxi(_lowest_bit(int(_dom[i])), 0)
		var f := _opt_family[opt]
		var lv := _opt_level[opt]
		family[_cells[i]] = f
		level[_cells[i]] = lv
		by_family[f] += 1
		by_level[f * 6 + lv] += 1
	_trail_cell.clear()
	_trail_old.clear()
	_clear_frames()
	_prior.clear()
	_dom.clear()
	_count.clear()
	_single.clear()
	_order.clear()


static func _popcount(mask: int) -> int:
	var count := 0
	var m := mask
	while m != 0:
		m = m & (m - 1)
		count += 1
	return count


static func _lowest_bit(mask: int) -> int:
	if mask == 0:
		return -1
	var opt := 0
	var m := mask
	while (m & 1) == 0:
		m = m >> 1
		opt += 1
	return opt
