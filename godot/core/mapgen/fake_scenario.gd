## A made-up scenario on a made-up map (docs/architecture/m2-build-spec.md section 9): `count` countries whose capitals
## are places of the map, every place a town seed of its nearest capital, grown by ScenarioGrowth. For the speed tool
## and tests only (never shipped); no luck, so the same map gives the same scenario.
##
## Two refinements of the spec text, both so the result is a scenario that validates: the tags are three capital
## letters (`FAA`, `FAB`, ... in id order; the spec's `F01` fails CountryDef's tag rule), and land the growth cannot
## reach (islands with no place, land past the reach) is pinned to the nearest owner, so every land hex is owned and
## `owner` still equals `ScenarioGrowth.grow` of the scenario (pins are applied after the growth).
class_name FakeScenario
extends RefCounted

## Capitals are taken at least this many hexes apart; when the map has too few places for that, the distance is
## relaxed step by step (the places left are taken in place order at the next, smaller distance).
const MIN_CAPITAL_DISTANCE := 20
const RELAXED_DISTANCES: Array[int] = [14, 10, 6, 3, 1, 0]
const GOLDEN := 0.6180339887
const SATURATION := 0.55
const VALUE := 0.8
const MAX_COUNTRIES := 254


## The 14 committed families (data/defs/families, M3 spec 4.3, M4 spec 4.4), so a fake world validates without
## inventing numbers.
static func _families() -> Array[FamilyDef]:
	var out: Array[FamilyDef] = []
	for id: int in range(1, FamilyIds.COUNT):
		out.append(ResourceLoader.load(
			"res://data/defs/families/%s.tres" % FamilyIds.NAMES[id], "", ResourceLoader.CACHE_MODE_IGNORE
		) as FamilyDef)
	return out


## Copies the committed goods (data/defs/goods) and the economy numbers of data/defs/game_defs.tres (M4 spec 4.2 to
## 4.12, 5.1), and a fresh WarDef from data/defs/war.tres (M7 5.1), into `defs`, so a fake or fixture defs validates under
## the M4 and M7 rules. Numbers are never invented here.
static func economy_into(defs: GameDefs) -> void:
	var committed := ResourceLoader.load(
		"res://data/defs/game_defs.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	) as GameDefs
	var goods: Array[GoodDef] = []
	for g: GoodDef in committed.goods:
		goods.append(ResourceLoader.load(
			"res://data/defs/goods/%s.tres" % String(g.key), "", ResourceLoader.CACHE_MODE_IGNORE
		) as GoodDef)
	defs.goods = goods
	# The war (M7 5.1): a fresh copy of data/defs/war.tres, so GameDefs.validate() holds and no test shares the committed one.
	defs.war = ResourceLoader.load("res://data/defs/war.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as WarDef
	# The computer's numbers (M8 4.4, 5.1): fresh copies of data/defs/ai.tres and the five temperaments, for the same reason.
	defs.ai = ResourceLoader.load("res://data/defs/ai.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as AiDef
	var tempers: Array[AiTemperDef] = []
	for t: AiTemperDef in committed.tempers:
		tempers.append(ResourceLoader.load(
			"res://data/defs/tempers/%s.tres" % String(t.key), "", ResourceLoader.CACHE_MODE_IGNORE
		) as AiTemperDef)
	defs.tempers = tempers
	defs.wild_good = committed.wild_good.duplicate()
	defs.wild_yield = committed.wild_yield
	defs.country_people = committed.country_people
	defs.hands_permille = committed.hands_permille
	defs.food_need_milli = committed.food_need_milli
	defs.food_weight = committed.food_weight
	defs.content_floor = committed.content_floor
	defs.reserve_seasons = committed.reserve_seasons
	defs.town_tax_milli = committed.town_tax_milli
	defs.country_tax_milli = committed.country_tax_milli
	defs.tax_permille = committed.tax_permille
	defs.goods_share_permille = committed.goods_share_permille
	defs.output_permille = committed.output_permille
	defs.port_dues_percent = committed.port_dues_percent
	defs.fishing_percent = committed.fishing_percent
	defs.start_treasury_base = committed.start_treasury_base
	defs.start_treasury_per_1000 = committed.start_treasury_per_1000
	defs.weather_odds = committed.weather_odds
	defs.weather_permille = committed.weather_permille
	defs.expensive_permille = committed.expensive_permille
	defs.expensive_seasons = committed.expensive_seasons
	# M6 (spec 4.2, 4.3, 5.1): the four kinds and the eight grounds; the step, supply and sight numbers keep GameDefs' own
	# defaults, which are the committed ones.
	var units: Array[UnitDef] = []
	for u: UnitDef in committed.units:
		units.append(ResourceLoader.load(
			"res://data/defs/units/%s.tres" % String(u.key), "", ResourceLoader.CACHE_MODE_IGNORE
		) as UnitDef)
	defs.units = units
	var terrains: Array[TerrainDef] = []
	for t: TerrainDef in committed.terrains:
		terrains.append(ResourceLoader.load(
			"res://data/defs/terrain/%s.tres" % String(t.key), "", ResourceLoader.CACHE_MODE_IGNORE
		) as TerrainDef)
	defs.terrains = terrains


## `{defs: GameDefs, scenario: ScenarioDef}` with `count` countries (fewer when the map has fewer places).
static func build(map: MapData, count: int, _seed_value: int) -> Dictionary:
	var defs := GameDefs.new()
	defs.tinctures = GameDefs.default_tinctures()
	defs.cb_palette = GameDefs.default_cb_palette()
	defs.families = _families()
	economy_into(defs)
	var scenario := ScenarioDef.new()
	scenario.id = "fake"
	scenario.name = "Fake %d" % count
	# No regions and no discovery (fog spec R7): the made-up world starts with the land sight only.
	if map == null:
		return {"defs": defs, "scenario": scenario}
	var capitals := _pick_capitals(map, clampi(count, 0, MAX_COUNTRIES))
	scenario.map_id = map.id
	scenario.map_digest = map.digest()
	scenario.reach = 6 * (map.cols + map.rows) + 64
	var tags := _make_defs(defs, capitals, map)
	scenario.countries.assign(tags)
	for place_idx: int in capitals:
		scenario.capitals.append(_place_hex(map, place_idx))
	scenario.seeds = _town_seeds(map, capitals, tags)
	var grown := ScenarioGrowth.grow(map, scenario)
	scenario.pins = _pins_for_unowned(map, grown, scenario)
	scenario.owner = ScenarioGrowth.grow(map, scenario)
	scenario.cb_colours = _cb_colours(map, scenario.owner, tags.size(), defs.cb_palette)
	# Country id gives the temperament, [builder, cautious, steadfast, aggressive, opportunist][id mod 5] (M8 spec 4.4).
	for id: int in range(1, tags.size() + 1):
		scenario.tempers.append(defs.tempers[id % defs.tempers.size()].key)
	defs.scenarios.append(scenario)
	return {"defs": defs, "scenario": scenario}


## Place indices of the capitals, in place order within each distance step.
static func _pick_capitals(map: MapData, count: int) -> PackedInt32Array:
	var taken := PackedInt32Array()
	var steps: Array[int] = [MIN_CAPITAL_DISTANCE]
	steps.append_array(RELAXED_DISTANCES)
	for min_dist: int in steps:
		for place_idx: int in map.places.size():
			if taken.size() >= count:
				return taken
			if taken.has(place_idx):
				continue
			var hex := _place_hex(map, place_idx)
			if not map.is_land(hex):
				continue
			var far := true
			for other: int in taken:
				if _distance(hex, _place_hex(map, other)) < min_dist:
					far = false
					break
			if far:
				taken.append(place_idx)
	return taken


static func _make_defs(defs: GameDefs, capitals: PackedInt32Array, map: MapData) -> Array[StringName]:
	var tags: Array[StringName] = []
	var tinctures: Array = defs.tinctures.keys()
	tinctures.sort()
	for i: int in capitals.size():
		var tag := StringName("F%s%s" % [char(65 + floori(float(i) / 26.0)), char(65 + i % 26)])
		tags.append(tag)
		var c := CountryDef.new()
		c.tag = tag
		c.name = "Land %02d" % (i + 1)
		c.long_name = "Realm of Land %02d" % (i + 1)
		c.adjective = "Landish"
		c.ruler = "the Ruler of Land %02d" % (i + 1)
		c.colour = Color.from_hsv(fposmod(float(i) * GOLDEN, 1.0), SATURATION, VALUE)
		c.capital_name = str(map.places[capitals[i]].get("name", ""))
		c.arms_division = CountryDef.DIVISIONS[i % CountryDef.DIVISIONS.size()]
		c.arms_field = StringName(tinctures[i % tinctures.size()])
		c.arms_charge = StringName(tinctures[(i + 3) % tinctures.size()])
		defs.countries.append(c)
	return tags


## One town seed per place, of the capital nearest to it (cube distance, ties to the earlier capital).
static func _town_seeds(map: MapData, capitals: PackedInt32Array, tags: Array[StringName]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if capitals.is_empty():
		return out
	for place_idx: int in map.places.size():
		var hex := _place_hex(map, place_idx)
		if not map.is_land(hex):
			continue
		out.append({"hex": hex, "tag": tags[_nearest(hex, capitals, map)], "kind": &"town"})
	return out


## Index (into `capitals`) of the capital nearest to `hex`; the earlier one on a tie.
static func _nearest(hex: Vector2i, capitals: PackedInt32Array, map: MapData) -> int:
	var best := 0
	var best_d := 1 << 30
	for i: int in capitals.size():
		var d := _distance(hex, _place_hex(map, capitals[i]))
		if d < best_d:
			best_d = d
			best = i
	return best


## Pins for land the growth left at 0: land touching owned land goes to the nearest owner by steps (a flood from the
## owned hexes, lowest index first); an island with no owned hex goes whole to the nearest capital.
static func _pins_for_unowned(map: MapData, grown: PackedByteArray, scenario: ScenarioDef) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if scenario.capitals.is_empty():
		return out
	var n := map.hex_count()
	var owned := grown.duplicate()
	var queue := PackedInt32Array()
	for i: int in n:
		if owned[i] != 0:
			queue.append(i)
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		var hex := map.hex_of(cur)
		for d: int in 6:
			var j := map.index_of(map.neighbour(hex, d))
			if j >= 0 and map.land[j] != 0 and owned[j] == 0:
				owned[j] = owned[cur]
				queue.append(j)
				out.append({"hex": map.hex_of(j), "tag": scenario.tag_of(owned[j])})
	for i: int in n:
		if map.land[i] == 0 or owned[i] != 0:
			continue
		var cid := _nearest_capital_id(map.hex_of(i), scenario)
		var tag := scenario.tag_of(cid)
		var island := PackedInt32Array([i])
		owned[i] = cid
		var at := 0
		while at < island.size():
			var cur := island[at]
			at += 1
			out.append({"hex": map.hex_of(cur), "tag": tag})
			for d: int in 6:
				var j := map.index_of(map.neighbour(map.hex_of(cur), d))
				if j >= 0 and map.land[j] != 0 and owned[j] == 0:
					owned[j] = cid
					island.append(j)
	return out


static func _nearest_capital_id(hex: Vector2i, scenario: ScenarioDef) -> int:
	var best := 1
	var best_d := 1 << 30
	for i: int in scenario.capitals.size():
		var d := _distance(hex, scenario.capitals[i])
		if d < best_d:
			best_d = d
			best = i + 1
	return best


## Colour-blind palette slots, greedy in id order: the slot farthest (worst simulated delta E) from the slots of the
## lower-id neighbours already given one; the lowest slot on a tie.
static func _cb_colours(map: MapData, owned: PackedByteArray, count: int, palette: PackedColorArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(count)
	var lower: Array = []
	lower.resize(count + 1)
	for i: int in count + 1:
		lower[i] = []
	for pair: Vector2i in ScenarioGrowth.neighbour_pairs(map, owned):
		(lower[pair.y] as Array).append(pair.x)
	for id: int in range(1, count + 1):
		var best := (id - 1) % palette.size()
		var best_score := -1.0
		for slot: int in palette.size():
			var score := 1.0e9
			for other: int in lower[id]:
				score = minf(score, ColourContrast.worst_delta_e(palette[slot], palette[out[other - 1]]))
			if score > best_score + 0.0001:
				best_score = score
				best = slot
		out[id - 1] = best
	return out


static func _place_hex(map: MapData, place_idx: int) -> Vector2i:
	return map.places[place_idx].get("hex", ScenarioDef.NO_HEX) as Vector2i


static func _distance(a: Vector2i, b: Vector2i) -> int:
	var ax := a.x - ((a.y - (a.y & 1)) >> 1)
	var bx := b.x - ((b.y - (b.y & 1)) >> 1)
	var dx := ax - bx
	var dz := a.y - b.y
	return maxi(maxi(absi(dx), absi(dz)), absi(dx + dz))
