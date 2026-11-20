## The improvement of each land hex of the normal map (docs/design/map/06-growing-map.md section 2 and the pieces guide,
## docs/design/map/pieces/GUIDE.md sections 6, 8 and 10): which piece family stands on a hex and at which level, chosen
## by wave function collapse, so that a hex's piece fits its own ground and its neighbours' pieces.
##
## The input is the fixed map (MapData); the facts of each land hex come from Improve.facts_of. The ground (cover,
## relief, water, roads, places) is fixed before this step: the solver only chooses the improvement. The result lives
## in a MapState (main_use and level), the one place that says what stands on a hex; this class keeps only what the
## rules derive from it (facts, neighbour tables, counts) and writes the state through _put.
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


## The fixed map and the state this class reads and writes (what stands on each hex).
var map: MapData = null
var state: MapState = null
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

var _only: Dictionary = {}  # empty: the whole map
var _cells: Array[Vector2i] = []
var _index: Dictionary[Vector2i, int] = {}
var _facts: Array[Dictionary] = []
var _fixed: PackedByteArray = PackedByteArray()  # 1: the data decides this hex (a place)
var _nbr: PackedInt32Array = PackedInt32Array()  # six per cell: the neighbouring land cell or -1
var _ring2: Array[PackedInt32Array] = []  # per cell: the land cells exactly two hexes away
## Set by `over`: the facts, the neighbour tables and the distances are not built for every cell (that was a search of
## every cell against every settlement) but for the hex that is asked about, and kept until a settlement changes.
var _lazy := false
var _settled: Dictionary[Vector2i, int] = {}  # lazy: the hexes with a settlement, their level
var _facts_lazy: Dictionary[int, Dictionary] = {}  # lazy: cell -> facts, for the cells asked about
var _prior: PackedFloat32Array = PackedFloat32Array()  # one per cell and option; zero when not allowed
var _initial: PackedInt64Array = PackedInt64Array()
var _dom: PackedInt64Array = PackedInt64Array()  # the solver's result: per cell, the option left
var _compat1: PackedInt64Array = PackedInt64Array()  # per option: the options it may touch
var _compat2: PackedInt64Array = PackedInt64Array()  # per option: the options it may have two hexes away
var _opt_family: PackedInt32Array = PackedInt32Array()
var _opt_level: PackedInt32Array = PackedInt32Array()
var _all: int = 0  # every option's bit


## The improvement of every land hex of a map, from one seed. It fills `state` (a new MapState when none is given).
## `only` (a Dictionary whose keys are hexes; empty for the whole map) limits it to those hexes: the prototype scene
## shows only the district it has art for. Hexes outside are left wild and the rules do not see them.
static func build(p_map: MapData, seed_value: int, p_state: MapState = null, only: Dictionary = {}) -> WorldImprove:
	var out := WorldImprove.new()
	out.map = p_map
	out._only = only
	out.state = p_state if p_state != null else MapState.create(p_map)
	out._make_options()
	out._collect()
	out._build_priors()
	out._search(seed_value)
	out._finish()
	return out


## The rules' working context over a state that already exists (a loaded game, a test): no search.
static func over(p_map: MapData, p_state: MapState) -> WorldImprove:
	var out := WorldImprove.new()
	out.map = p_map
	out.state = p_state
	out._lazy = true
	out._make_options()
	out._collect_cells()
	out._count_state()
	out._refresh_distances()
	return out


## The hexes of a window of columns and rows as a set (for build's `only`).
static func window(rect: Rect2i) -> Dictionary:
	var out: Dictionary = {}
	for r: int in range(rect.position.y, rect.end.y):
		for c: int in range(rect.position.x, rect.end.x):
			out[Vector2i(c, r)] = true
	return out


func family_at(hex: Vector2i) -> int:
	var i := map.index_of(hex)
	return int(state.main_use[i]) if i >= 0 else ImproveRules.NONE


func level_at(hex: Vector2i) -> int:
	var i := map.index_of(hex)
	return int(state.level[i]) if i >= 0 else 0


## The facts the rules read for a land hex: cover (a WorldCover number), height_m, coast, river, road, pass, climate,
## place_level, port, port_mode, landmark, place_distance, town_distance, city_distance, port_near, sea_angle.
func facts_at(hex: Vector2i) -> Dictionary:
	if not _index.has(hex):
		return {}
	return _facts_of(int(_index[hex]))


## What the map draws on a hex: {} for a wild hex, else the facts of Improve.piece_of.
func piece_at(hex: Vector2i) -> Dictionary:
	return Improve.piece_of(map, state, hex)


func count_of(family_id: int) -> int:
	return int(by_family[family_id]) if family_id >= 0 and family_id < ImproveRules.FAMILIES else 0


func count_at(family_id: int, level_value: int) -> int:
	return int(by_level[family_id * 6 + level_value])


# ----- the player's changes (build, upgrade, clear) -----------------------------------------------------------------
#
# Each is a check/action pair: x_check(...) -> {ok, reason}, and x(...), which checks again and then acts. A change
# keeps by_family and by_level right. The picture of a hex (variant and mirror) comes from the hex and the family
# alone (pick), so an upgrade never makes it jump. Places of the data are "fixed": they may grow but not go.
# (The static `build` makes the whole map; the player's build on one hex is build_on.)


func is_fixed(hex: Vector2i) -> bool:
	return _index.has(hex) and _fixed[int(_index[hex])] == 1


static func _verdict(ok: bool, reason: String = "") -> Dictionary:
	return {"ok": ok, "reason": "" if ok else reason}


## The first pair rule that the option (family, level) on a hex breaks against the pieces within two hexes, as a
## reason with the neighbour's place; "" when none.
func _pair_conflict(hex: Vector2i, family_id: int, level_value: int) -> String:
	if _lazy:
		return _pair_conflict_lazy(hex, family_id, level_value)
	var i := int(_index[hex])
	for d: int in 6:
		var k := _neighbour_cell(i, d)
		if k >= 0:
			var why := _pair_against(k, family_id, level_value, 1)
			if why != "":
				return why
	for k: int in _ring2_of(i):
		var why := _pair_against(k, family_id, level_value, 2)
		if why != "":
			return why
	return ""


## The same answer as the tables above for a game over a state (loaded, or just checked): the neighbours in edge order,
## then the twelve hexes two away in row order, skipping the wild ones by a look at the state before any cell lookup
## (nearly every hex around is wild, and a sea hex holds no piece).
func _pair_conflict_lazy(hex: Vector2i, family_id: int, level_value: int) -> String:
	var use := state.main_use
	for d: int in 6:
		var beside := ImproveRules.neighbour(hex, d)
		var at := map.index_of(beside)
		if at < 0 or use[at] == 0 or map.land[at] == 0:
			continue
		var why := _pair_against(int(_index[beside]), family_id, level_value, 1)
		if why != "":
			return why
	for delta: Vector2i in _ring_deltas((hex.y & 1) == 1):
		var far := hex + delta
		var at := map.index_of(far)
		if at < 0 or use[at] == 0 or map.land[at] == 0:
			continue
		var why := _pair_against(int(_index[far]), family_id, level_value, 2)
		if why != "":
			return why
	return ""


## The land cell next to cell `i` in direction `d`, or -1.
func _neighbour_cell(i: int, d: int) -> int:
	if not _lazy:
		return int(_nbr[i * 6 + d])
	return int(_index.get(ImproveRules.neighbour(_cells[i], d), -1))


## The land cells exactly two hexes from cell `i`, in cell order.
func _ring2_of(i: int) -> PackedInt32Array:
	if not _lazy:
		return _ring2[i] if i < _ring2.size() else PackedInt32Array()
	return _ring_of(_cells[i])


func _pair_against(cell: int, family_id: int, level_value: int, radius: int) -> String:
	var other := _cells[cell]
	var f := family_at(other)
	if f == ImproveRules.NONE:
		return ""
	var why := ImproveRules.pair_reason(family_id, level_value, f, level_at(other), radius)
	if why == "":
		return ""
	return "%s (%s %d at %d, %d)" % [why, ImproveRules.NAMES[f], level_at(other), other.x, other.y]


## The pieces a wild hex may take, each {family_id, family, level (1), ok, reason}: every family its ground allows at
## level 1; ok is false (the reason is the pair rule) when a neighbour forbids it. A pass offers a watchtower. Empty
## for a hex that is not wild land, and for wild land no family fits.
func build_options(hex: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _index.has(hex) or family_at(hex) != ImproveRules.NONE:
		return out
	var facts := facts_at(hex)
	var candidates: Array[int] = []
	if bool(facts.get("pass", false)):
		candidates.append(ImproveRules.CASTLE)
	else:
		for f: int in range(ImproveRules.WHEAT, ImproveRules.FAMILIES):
			if ImproveRules.cell_allowed(f, 1, facts):
				candidates.append(f)
	for f: int in candidates:
		var why := _pair_conflict(hex, f, 1)
		out.append({"family_id": f, "family": ImproveRules.NAMES[f], "level": 1, "ok": why == "", "reason": why})
	return out


func build_check(hex: Vector2i, family_id: int) -> Dictionary:
	if not _index.has(hex):
		return _verdict(false, "not a land hex")
	if family_at(hex) != ImproveRules.NONE:
		return _verdict(false, "something already stands here")
	# Only the asked family is tried (build_options would try every candidate's pair rules for the same answer).
	var facts := facts_at(hex)
	var offered := family_id == ImproveRules.CASTLE if bool(facts.get("pass", false)) 			else (family_id >= ImproveRules.WHEAT and family_id < ImproveRules.FAMILIES and ImproveRules.cell_allowed(family_id, 1, facts))
	if offered:
		var why := _pair_conflict(hex, family_id, 1)
		return _verdict(why == "", why)
	if family_id <= ImproveRules.NONE or family_id >= ImproveRules.FAMILIES:
		return _verdict(false, "no such piece")
	if bool(facts_at(hex).get("pass", false)):
		return _verdict(false, "only a watchtower can stand on a pass")
	return _verdict(false, ImproveRules.cell_reason(family_id, 1, facts_at(hex)))


## Sets the piece of a hex with no check: for a caller that has just checked (Improve), so the rules run once.
func put_piece(hex: Vector2i, family_id: int, level_value: int) -> void:
	_put(hex, family_id, level_value)


## Builds level 1 of a family on a wild hex (after checking again). Returns the verdict.
func build_on(hex: Vector2i, family_id: int) -> Dictionary:
	var verdict := build_check(hex, family_id)
	if bool(verdict["ok"]):
		_put(hex, family_id, 1)
	return verdict


func upgrade_check(hex: Vector2i) -> Dictionary:
	if not _index.has(hex):
		return _verdict(false, "not a land hex")
	var f := family_at(hex)
	if f == ImproveRules.NONE:
		return _verdict(false, "nothing is built here: build something first")
	var lv := level_at(hex)
	if lv >= ImproveRules.TOP_LEVEL[f]:
		return _verdict(false, "already at its highest level")
	if f != ImproveRules.SETTLEMENT and f != ImproveRules.CASTLE:
		var why := ImproveRules.cell_reason(f, lv + 1, facts_at(hex))
		if why != "":
			return _verdict(false, why)
	var conflict := _pair_conflict(hex, f, lv + 1)
	if conflict != "":
		return _verdict(false, conflict)
	return _verdict(true)


## One level up for the piece on a hex (after checking again). A village of the data may grow into a town.
func upgrade(hex: Vector2i) -> Dictionary:
	var verdict := upgrade_check(hex)
	if bool(verdict["ok"]):
		_put(hex, family_at(hex), level_at(hex) + 1)
	return verdict


func clear_check(hex: Vector2i) -> Dictionary:
	if not _index.has(hex):
		return _verdict(false, "not a land hex")
	if family_at(hex) == ImproveRules.NONE:
		return _verdict(false, "nothing is built here")
	if is_fixed(hex):
		return _verdict(false, "a place of the map is never pulled down")
	return _verdict(true)


## Takes the piece off a hex: it is wild again (after checking again).
func clear(hex: Vector2i) -> Dictionary:
	var verdict := clear_check(hex)
	if bool(verdict["ok"]):
		_put(hex, ImproveRules.NONE, 0)
	return verdict


## Sets the piece of a hex and keeps the counts; a changed settlement level moves the distances the rules read.
func _put(hex: Vector2i, family_id: int, level_value: int) -> void:
	var old_f := family_at(hex)
	var old_l := level_at(hex)
	by_family[old_f] -= 1
	by_level[old_f * 6 + old_l] -= 1
	var at := map.index_of(hex)
	state.main_use[at] = family_id
	state.level[at] = level_value
	by_family[family_id] += 1
	by_level[family_id * 6 + level_value] += 1
	if family_id == ImproveRules.SETTLEMENT or old_f == ImproveRules.SETTLEMENT:
		if _lazy:
			if family_id == ImproveRules.SETTLEMENT:
				_settled[hex] = level_value
			else:
				_settled.erase(hex)
			_facts_lazy.clear()
		else:
			_refresh_distances()


## The distances to the nearest place, town and city from the settlements as they stand now (a village that grew into a
## town opens the town-near levels round it).
func _refresh_distances() -> void:
	if _lazy:
		_settled.clear()
		_facts_lazy.clear()
		for hex: Vector2i in hexes:
			if family_at(hex) == ImproveRules.SETTLEMENT:
				_settled[hex] = level_at(hex)
		return
	var settled: Array[Vector3i] = []
	for hex: Vector2i in hexes:
		if family_at(hex) == ImproveRules.SETTLEMENT:
			settled.append(Vector3i(hex.x, hex.y, level_at(hex)))
	for i: int in _cells.size():
		var near_place := 99
		var near_town := 99
		var near_city := 99
		for s: Vector3i in settled:
			var distance := ImproveRules.hex_distance(_cells[i], Vector2i(s.x, s.y))
			if distance == 0:
				continue
			near_place = mini(near_place, distance)
			if s.z >= 3:
				near_town = mini(near_town, distance)
			if s.z >= 4:
				near_city = mini(near_city, distance)
		var facts := _facts[i]
		facts["place_distance"] = near_place
		facts["town_distance"] = near_town
		facts["city_distance"] = near_city


## Every pair rule and cell rule the result breaks, as text (none expected; the tests and the tools print it).
## Pairs of fixed places are not listed here: they are in fixed_conflicts.
func violations() -> Array[String]:
	var out: Array[String] = []
	for hex: Vector2i in hexes:
		var f := family_at(hex)
		var lv := level_at(hex)
		var i := int(_index[hex])
		if _fixed[i] == 0 and f != ImproveRules.NONE and f != ImproveRules.CASTLE and not ImproveRules.cell_allowed(f, lv, _facts_of(i)):
			out.append("%s: %s %d breaks a cell rule" % [hex, ImproveRules.NAMES[f], lv])
		if f == ImproveRules.NONE:
			continue
		for other: Vector2i in hexes:
			if other == hex or (other.y < hex.y or (other.y == hex.y and other.x < hex.x)):
				continue
			var distance := ImproveRules.hex_distance(hex, other)
			if distance > 2:
				continue
			var j := int(_index[other])
			if _fixed[i] == 1 and _fixed[j] == 1:
				continue
			if not ImproveRules.pair_allowed(f, lv, family_at(other), level_at(other), distance):
				out.append("%s %s %d and %s %s %d, %d apart" % [hex, ImproveRules.NAMES[f], lv, other, ImproveRules.NAMES[family_at(other)],
					level_at(other), distance])
	return out


## Counts for the report and the tests.
func summary() -> Dictionary:
	var names: Dictionary[String, int] = {}
	var levels: Dictionary[String, Array] = {}
	var pieces := 0
	for f: int in range(1, ImproveRules.FAMILIES):
		names[ImproveRules.NAMES[f]] = count_of(f)
		pieces += count_of(f)
		var row: Array[int] = []
		for lv: int in range(1, ImproveRules.TOP_LEVEL[f] + 1):
			row.append(count_at(f, lv))
		levels[ImproveRules.NAMES[f]] = row
	return {
		"hexes": hexes.size(),
		"pieces": pieces,
		"wild": count_of(ImproveRules.NONE),
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
	var n := ImproveRules.option_count()
	_opt_family.resize(n)
	_opt_level.resize(n)
	_opt_family[0] = ImproveRules.NONE
	_opt_level[0] = 0
	var at := 1
	for f: int in range(1, ImproveRules.FAMILIES):
		for lv: int in range(1, ImproveRules.TOP_LEVEL[f] + 1):
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
			if ImproveRules.pair_allowed(_opt_family[a], _opt_level[a], _opt_family[b], _opt_level[b], 1):
				near = near | (1 << b)
			if ImproveRules.pair_allowed(_opt_family[a], _opt_level[a], _opt_family[b], _opt_level[b], 2):
				far = far | (1 << b)
		_compat1[a] = near
		_compat2[a] = far


func _collect() -> void:
	for i: int in map.hex_count():
		if map.land[i] == 1 and (_only.is_empty() or _only.has(map.hex_of(i))):
			_cells.append(map.hex_of(i))
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
		var facts := Improve.facts_of(map, hex)
		var lv := int(facts["place_level"])
		if lv > 0:
			settled.append(Vector3i(hex.x, hex.y, lv))
			if bool(facts["port"]):
				ports.append(hex)
			_fixed[i] = 1
		_facts.append(facts)
		for d: int in 6:
			var nb := ImproveRules.neighbour(hex, d)
			if _index.has(nb):
				_nbr[i * 6 + d] = int(_index[nb])
	for i: int in n:
		var hex := _cells[i]
		_ring2.append(_ring_of(hex))
		var facts := _facts[i]
		var near_place := 99
		var near_town := 99
		var near_city := 99
		for s: Vector3i in settled:
			var distance := ImproveRules.hex_distance(hex, Vector2i(s.x, s.y))
			if distance == 0:
				continue
			near_place = mini(near_place, distance)
			if s.z >= 3:
				near_town = mini(near_town, distance)
			if s.z >= 4:
				near_city = mini(near_city, distance)
		var port_near := bool(facts["port"])
		for p: Vector2i in ports:
			if ImproveRules.hex_distance(hex, p) <= 1:
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
			var distance := ImproveRules.hex_distance(ha, hb)
			if distance <= 2 and not ImproveRules.pair_allowed(ImproveRules.SETTLEMENT, settled[a].z, ImproveRules.SETTLEMENT, settled[b].z, distance):
				fixed_conflicts.append("%s (level %d) and %s (level %d)" % [ha, settled[a].z, hb, settled[b].z])


## The land cells exactly two hexes from a hex, in cell order (ascending: the cells are in row-major order, and the
## twelve offsets of a parity are listed row-major too).
func _ring_of(hex: Vector2i) -> PackedInt32Array:
	var ring := PackedInt32Array()
	for delta: Vector2i in _ring_deltas((hex.y & 1) == 1):
		var k := int(_index.get(hex + delta, -1))
		if k >= 0:
			ring.append(k)
	return ring


static var _deltas: Array = []


## The twelve offsets of the hexes exactly two away from a hex on an even row (false) or an odd row (true), sorted by
## row then column. Found once from the distance function itself.
static func _ring_deltas(odd_row: bool) -> Array[Vector2i]:
	if _deltas.is_empty():
		for parity: int in 2:
			var origin := Vector2i(10, 10 + parity)
			var found: Array[Vector2i] = []
			for dy: int in range(-2, 3):
				for dx: int in range(-3, 4):
					var delta := Vector2i(dx, dy)
					if ImproveRules.hex_distance(origin, origin + delta) == 2:
						found.append(delta)  # row-major already: dy ascending, then dx
			_deltas.append(found)
	var out: Array[Vector2i] = []
	out.assign(_deltas[1 if odd_row else 0])
	return out


## What `over` needs and no search: the land cells, which of them are places of the data, and the pairs of those
## places that break a pair rule (found by looking at the hexes within two of each place, not at every pair).
func _collect_cells() -> void:
	for i: int in map.hex_count():
		if map.land[i] == 1:
			_cells.append(map.hex_of(i))
	var n := _cells.size()
	for i: int in n:
		_index[_cells[i]] = i
	_fixed.resize(n)
	_fixed.fill(0)
	var places: Array[int] = []  # the cells of the data's places, in cell order
	var place_level: Dictionary[int, int] = {}
	var top := ImproveRules.TOP_LEVEL[ImproveRules.SETTLEMENT]
	for i: int in n:
		var place := Improve.place_of(map, _cells[i])
		var lv := clampi(int(place.get("level", 0)), 0, top) if not place.is_empty() else 0
		if lv > 0:
			_fixed[i] = 1
			places.append(i)
			place_level[i] = lv
	var rank: Dictionary[int, int] = {}
	for a: int in places.size():
		rank[places[a]] = a
	for a: int in places.size():
		var ha := _cells[places[a]]
		var near: Array[int] = []
		for d: int in 6:
			var first := ImproveRules.neighbour(ha, d)
			near.append(int(_index.get(first, -1)))
			for e: int in 6:
				near.append(int(_index.get(ImproveRules.neighbour(first, e), -1)))
		var later: Dictionary[int, bool] = {}
		for k: int in near:
			if k >= 0 and rank.has(k) and int(rank[k]) > a and ImproveRules.hex_distance(ha, _cells[k]) <= 2:
				later[int(rank[k])] = true
		var order: Array[int] = []
		order.assign(later.keys())
		order.sort()
		for b: int in order:
			var hb := _cells[places[b]]
			var distance := ImproveRules.hex_distance(ha, hb)
			var la := int(place_level[places[a]])
			var lb := int(place_level[places[b]])
			if not ImproveRules.pair_allowed(ImproveRules.SETTLEMENT, la, ImproveRules.SETTLEMENT, lb, distance):
				fixed_conflicts.append("%s (level %d) and %s (level %d)" % [ha, la, hb, lb])


## The facts of cell `i`: `build` keeps them for every cell; `over` builds them when asked and keeps them until a
## settlement changes (the distances read the settlements as they stand now, port_near the ports of the data).
func _facts_of(i: int) -> Dictionary:
	if not _lazy:
		return _facts[i]
	if _facts_lazy.has(i):
		return _facts_lazy[i]
	var hex := _cells[i]
	var facts := Improve.facts_of(map, hex)
	var near_place := 99
	var near_town := 99
	var near_city := 99
	for s: Vector2i in _settled:
		var distance := ImproveRules.hex_distance(hex, s)
		if distance == 0:
			continue
		var lv := int(_settled[s])
		near_place = mini(near_place, distance)
		if lv >= 3:
			near_town = mini(near_town, distance)
		if lv >= 4:
			near_city = mini(near_city, distance)
	var port_near := bool(facts["port"])
	for d: int in 6:
		var beside := ImproveRules.neighbour(hex, d)
		if _index.has(beside):
			var place := Improve.place_of(map, beside)
			port_near = port_near or (not place.is_empty() and int(place.get("level", 0)) >= 1 and bool(place.get("port", false)))
	facts["place_distance"] = near_place
	facts["town_distance"] = near_town
	facts["city_distance"] = near_city
	facts["port_near"] = port_near
	_facts_lazy[i] = facts
	return facts


# ----- the cell rules and the weights -------------------------------------------------------------------------------


## The options of one hex as bits: a place is its settlement; a pass is nothing, a watchtower or a castle; every other
## hex is "none" and what the cell rules allow.
func _domain_of(i: int) -> int:
	var facts := _facts[i]
	var place_level := int(facts["place_level"])
	if place_level > 0:
		return 1 << ImproveRules.option_of(ImproveRules.SETTLEMENT, place_level)
	var mask := 1
	if bool(facts["pass"]):
		return mask | (1 << ImproveRules.option_of(ImproveRules.CASTLE, 1)) | (1 << ImproveRules.option_of(ImproveRules.CASTLE, 2))
	for opt: int in range(1, _opt_family.size()):
		if ImproveRules.cell_allowed(_opt_family[opt], _opt_level[opt], facts):
			mask = mask | (1 << opt)
	return mask


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
			if f == ImproveRules.CASTLE:
				# A pass on a road is worth holding; the castle proper is the rarer one.
				w = (1.0 if _opt_level[opt] == 1 else 0.6) * (1.0 if bool(facts["road"]) else 0.7)
			elif f != ImproveRules.SETTLEMENT:
				w = ImproveRules.fit(f, facts) * ImproveRules.level_weight(_opt_level[opt], facts)
			w = maxf(w, 0.001)
			_prior[i * options + opt] = w
			worked += w
		if (mask & 1) == 1:
			var share := (ImproveRules.PASS_OPEN_BY_ROAD if bool(facts["road"]) else ImproveRules.PASS_OPEN) if bool(facts["pass"]) else ImproveRules.wild_share(facts)
			_prior[i * options] = maxf(worked, 0.001) * share / (1.0 - share)


# ----- the search ---------------------------------------------------------------------------------------------------


# ----- the search ---------------------------------------------------------------------------------------------------


## Runs the solver (ImproveSolver) over the inputs and takes its counts and its result.
func _search(seed_value: int) -> void:
	var solver := ImproveSolver.new()
	solver.initial = _initial
	solver.prior = _prior
	solver.nbr = _nbr
	solver.ring2 = _ring2
	solver.fixed = _fixed
	solver.compat1 = _compat1
	solver.compat2 = _compat2
	solver.opt_family = _opt_family
	solver.all = _all
	solver.solve(seed_value)
	backtracks += solver.backtracks
	restarts += solver.restarts
	contradictions += solver.contradictions
	input_dead_ends += solver.input_dead_ends
	for cell: int in solver.last_resort:
		last_resort.append(_cells[cell])
	_dom = solver.dom


func _finish() -> void:
	for i: int in _cells.size():
		var opt := maxi(ImproveSolver.lowest_bit(int(_dom[i])), 0)
		var at := map.index_of(_cells[i])
		state.main_use[at] = _opt_family[opt]
		state.level[at] = _opt_level[opt]
	_count_state()
	_prior.clear()
	_dom.clear()


## Fills hexes and the counts from the state.
func _count_state() -> void:
	by_family.resize(ImproveRules.FAMILIES)
	by_family.fill(0)
	by_level.resize(ImproveRules.FAMILIES * 6)
	by_level.fill(0)
	hexes = _cells.duplicate()
	for hex: Vector2i in _cells:
		var f := family_at(hex)
		by_family[f] += 1
		by_level[f * 6 + level_at(hex)] += 1
