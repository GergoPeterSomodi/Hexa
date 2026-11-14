## The starting units of the Europe 1480 map: the troops of each country by its people, a general in the big ones, and a
## caravel in each colonising country's port. A port of starting_units in hexa/campaign/systems/worldgen.py (the frozen
## reference). The units are data only (they are drawn from 0.3.2). The general's trait is not drawn (a 0.3.2 rule).
class_name StartingUnits
extends RefCounted

const CARAVEL_BY_TURN := 40  # a country whose colonising starts by this turn gets a caravel
const NO_SPOT := Vector2i(-1, -1)  # the place of a unit that finds no room (not placed)


## A port of a colonising country, with its sort keys (longitude, then the negative people, then province order).
class PortKey:
	extends RefCounted
	var pos: Vector2i
	var lon: float
	var neg_pop: float
	var index: int

	func _init(p_pos: Vector2i, p_lon: float, p_neg_pop: float, p_index: int) -> void:
		pos = p_pos
		lon = p_lon
		neg_pop = p_neg_pop
		index = p_index


static func build(map: MapData, data: EuropeData, geo: Geo) -> void:
	var infantry: String = data.troop_keys["infantry/1"]
	var cavalry: String = data.troop_keys["cavalry/1"]
	var artillery: String = data.troop_keys["artillery/1"]
	for tag: String in map.country_order:
		var country: Country = map.countries[tag]
		var pop := map.total_pop(tag)
		var kinds: Array[String] = []
		for _i in maxi(1, HexGrid.round_half_even(pop / 450.0)):
			kinds.append(infantry)
		for _i in HexGrid.round_half_even(pop / 1000.0):
			kinds.append(cavalry)
		if pop > 900.0:
			kinds.append(artillery)
		if pop > 1500.0:
			kinds.append("general")
		var capital: Province = map.provinces[country.capital]
		for kind: String in kinds:
			var spot := _land_spot(map, data, tag, capital, kind)
			if spot != NO_SPOT:
				_add(map, data, kind, tag, spot)
	for tag: String in map.country_order:
		var country: Country = map.countries[tag]
		if country.colonial_start > CARAVEL_BY_TURN:
			continue
		var ports: Array[PortKey] = []
		for prov: Province in map.provinces_of(tag):
			if prov.port:
				ports.append(PortKey.new(prov.pos, geo.lonlat(prov.pos)[0], -prov.pop(), ports.size()))
		ports.sort_custom(_port_less)
		for key: PortKey in ports:
			var sea := _free_sea_beside(map, key.pos)
			if sea != NO_SPOT:
				_add(map, data, "caravel", tag, sea)
				break


static func _port_less(a: PortKey, b: PortKey) -> bool:
	if a.lon != b.lon:
		return a.lon < b.lon
	if a.neg_pop != b.neg_pop:
		return a.neg_pop < b.neg_pop
	return a.index < b.index


## The first ocean hex beside a port with no unit on it, in neighbour order; NO_SPOT when none.
static func _free_sea_beside(map: MapData, pos: Vector2i) -> Vector2i:
	for n: Vector2i in HexGrid.neighbours(pos):
		if map.terrain.get(n, "") == MapData.OCEAN and map.units_at(n).is_empty():
			return n
	return NO_SPOT


## Where a new troop appears: the province itself, or a province of the country beside it with room for it.
static func _land_spot(map: MapData, data: EuropeData, tag: String, prov: Province, kind: String) -> Vector2i:
	var candidates: Array[Vector2i] = [prov.pos]
	var around: Array[Vector2i] = HexGrid.neighbours(prov.pos)
	around.sort_custom(HexGrid.lex_less)
	candidates.append_array(around)
	for pos: Vector2i in candidates:
		if not map.provinces.has(pos):
			continue
		var other: Province = map.provinces[pos]
		if other.owner != tag or map.is_ridge_step(prov.pos, pos):
			continue
		if _can_stand(map, data, tag, kind, pos):
			return pos
	return NO_SPOT


## Python military.can_stand for one unit of this kind joining the units on a hex: only its own country's units may
## share it; at most the stack limit of war units (the base, plus the general's share when a general stands there),
## at most the civilian limit of other units, and at most one general. Country bonuses from techs are not counted yet.
static func _can_stand(map: MapData, data: EuropeData, tag: String, kind: String, pos: Vector2i) -> bool:
	var others := map.units_at(pos)
	var war := 0
	var generals := 0
	for unit: Unit in others:
		if unit.owner != tag:
			return false
		if data.war_kinds.has(unit.kind):
			war += 1
		if unit.kind == "general":
			generals += 1
	if data.war_kinds.has(kind):
		war += 1
	if kind == "general":
		generals += 1
	var everyone := others.size() + 1
	var civilians := everyone - war - generals
	var limit := data.stack_base + (data.stack_general if generals > 0 else 0)
	return war <= limit and civilians <= data.stack_civilian and generals <= 1


static func _add(map: MapData, data: EuropeData, kind: String, owner: String, pos: Vector2i) -> void:
	var unit := Unit.new(map.units.size() + 1, kind, owner, pos, int(data.unit_hp[kind]),
			float(data.unit_moves[kind]))
	map.units.append(unit)
