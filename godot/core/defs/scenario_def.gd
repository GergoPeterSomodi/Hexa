## A playable scenario's fixed countries, capitals, territory seeds/pins, growth parameters, and grown owner grid
## (docs/architecture/m2-build-spec.md sections 4.1 to 4.6, 5.1, and 8.2).
@tool
class_name ScenarioDef
extends Resource

const NO_HEX := Vector2i(-1, -1)

@export var id: String = ""
@export var name: String = ""
@export_multiline var blurb: String = ""
@export var map_id: String = ""
@export var map_digest: String = ""
@export var year: int = 1480
@export var countries: Array[StringName] = []
@export var capitals: Array[Vector2i] = []
@export var cb_colours: PackedByteArray = PackedByteArray()
@export var seeds: Array[Dictionary] = []
@export var pins: Array[Dictionary] = []
@export var step_cost: int = 2
@export var crest_cost: int = 3
@export var river_cost: int = 1
@export var anchor_start: int = 1
@export var reach: int = 32
@export var owner: PackedByteArray = PackedByteArray()
## Per country (the countries' order): a GameDefs.tempers key (M8 spec 4.4, 5.1). Kept by hand; build_scenario.gd leaves it.
@export var tempers: Array[StringName] = []
## Companies the scenario starts with: {tag: StringName, hex: Vector2i, kind: int, count: int} (M8 spec 5.1). 1480: none.
@export var start_armies: Array[Dictionary] = []
## The settlements that start with a barracks, whatever their size (recruitment-queue.md 4.1, decisions 17 and 18). Kept by
## hand; build_scenario.gd leaves it. None listed: every capital on the map has one (Recruiting.setup).
@export var barracks: Array[Vector2i] = []
## Regions of the discovery set (fog spec R5): index 0 is the first region; byte value k + 1 in `region` means regions[k].
@export var regions: Array[StringName] = []
## One byte a hex, in the map's order: the region's byte, 0 for none. Empty when the scenario has no regions (R7).
@export var region: PackedByteArray = PackedByteArray()
## Per country (R5): {tag: StringName, regions: Array[StringName]}, the regions every hex of which the country starts knowing (R6).
@export var discovery: Array[Dictionary] = []


## Country id (1..countries.size()) for `tag`, or 0 when not listed.
func id_of(tag: StringName) -> int:
	if tag == &"":
		return 0
	var idx := countries.find(tag)
	return 0 if idx < 0 else idx + 1


## Country tag for `id` (1-based), or &"" for 0 or out of range.
func tag_of(id_val: int) -> StringName:
	if id_val <= 0 or id_val > countries.size():
		return &""
	return countries[id_val - 1]


## True when `tag` is listed in the scenario and its capital lies on the map.
func playable(tag: StringName) -> bool:
	var cid := id_of(tag)
	if cid == 0:
		return false
	var idx := cid - 1
	if idx >= capitals.size():
		return false
	return capitals[idx] != NO_HEX


## Per-country palette colours in id order (index 0 corresponds to country id 1).
func colours(defs: GameDefs, colour_blind: bool = false) -> PackedColorArray:
	var out := PackedColorArray()
	if defs == null:
		return out
	out.resize(countries.size())
	for i: int in countries.size():
		if colour_blind:
			var cb_idx := int(cb_colours[i]) if i < cb_colours.size() else -1
			if cb_idx >= 0 and cb_idx < defs.cb_palette.size():
				out[i] = defs.cb_palette[cb_idx]
			else:
				out[i] = defs.unowned_colour
		else:
			var cdef := defs.country(countries[i])
			out[i] = cdef.colour if cdef != null else defs.unowned_colour
	return out


## Validates against `map` and `defs` per m2-build-spec section 8.2. When `deep` is true, also regrows owner
## and checks normal and colour-blind contrast between all neighbouring country pairs.
func validate(map: MapData, defs: GameDefs, deep: bool) -> Array[String]:
	var errors: Array[String] = []
	if map == null:
		errors.append("map is null")
		return errors
	if defs == null:
		errors.append("defs is null")
		return errors
	if map_id != map.id:
		errors.append("map_id '%s' does not match map.id '%s'" % [map_id, map.id])
	if map_digest != map.digest():
		errors.append("map_digest differs from map (built on another map: run tools/build_scenario.gd)")
	var country_set := _validate_countries(map, defs, errors)
	_validate_seeds(map, country_set, errors)
	_validate_pins(map, country_set, errors)
	_validate_owner(map, errors)
	_validate_tempers(defs, errors)
	_validate_start_armies(map, defs, country_set, errors)
	_validate_barracks(map, errors)
	_validate_regions(map, errors)
	if deep:
		_validate_deep(map, defs, errors)
	return errors


## SHA-256 (hex text) of every field in a fixed order.
func digest() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	_feed_str(ctx, id)
	_feed_str(ctx, name)
	_feed_str(ctx, blurb)
	_feed_str(ctx, map_id)
	_feed_str(ctx, map_digest)
	_feed_int(ctx, year)
	_feed_int(ctx, countries.size())
	for tag: StringName in countries:
		_feed_str(ctx, String(tag))
	_feed_int(ctx, capitals.size())
	for cap: Vector2i in capitals:
		ctx.update(PackedInt32Array([cap.x, cap.y]).to_byte_array())
	_feed_int(ctx, cb_colours.size())
	_feed_bytes(ctx, cb_colours)
	_feed_dict_list(ctx, seeds)
	_feed_dict_list(ctx, pins)
	ctx.update(PackedInt32Array([step_cost, crest_cost, river_cost, anchor_start, reach]).to_byte_array())
	_feed_int(ctx, owner.size())
	_feed_bytes(ctx, owner)
	_feed_int(ctx, tempers.size())
	for key: StringName in tempers:
		_feed_str(ctx, String(key))
	_feed_dict_list(ctx, start_armies)
	_feed_int(ctx, barracks.size())
	for hex: Vector2i in barracks:
		ctx.update(PackedInt32Array([hex.x, hex.y]).to_byte_array())
	_feed_int(ctx, regions.size())
	for reg: StringName in regions:
		_feed_str(ctx, String(reg))
	_feed_int(ctx, region.size())
	_feed_bytes(ctx, region)
	_feed_dict_list(ctx, discovery)
	return ctx.finish().hex_encode()


func _validate_countries(map: MapData, defs: GameDefs, errors: Array[String]) -> Dictionary:
	var country_set: Dictionary = {}
	if countries.is_empty() or countries.size() > 254:
		errors.append("countries has %d entries, expected 1 to 254" % countries.size())
	for i: int in countries.size():
		var tag := countries[i]
		if tag == &"":
			errors.append("countries[%d]: empty tag" % i)
			continue
		if country_set.has(tag):
			errors.append("countries[%d]: duplicate tag '%s'" % [i, String(tag)])
		else:
			country_set[tag] = true
		var cdef := defs.country(tag)
		if cdef == null:
			errors.append("countries[%d]: unknown country tag '%s'" % [i, String(tag)])
	if capitals.size() != countries.size():
		errors.append("capitals has %d entries, expected %d" % [capitals.size(), countries.size()])
	if cb_colours.size() != countries.size():
		errors.append("cb_colours has %d entries, expected %d" % [cb_colours.size(), countries.size()])
	for i: int in cb_colours.size():
		if cb_colours[i] >= 8:
			errors.append("cb_colours[%d]: index %d must be under 8" % [i, cb_colours[i]])
	for i: int in mini(countries.size(), capitals.size()):
		var tag := countries[i]
		var cap := capitals[i]
		if cap == NO_HEX:
			var cdef := defs.country(tag)
			if cdef != null and cdef.capital_name.strip_edges().is_empty():
				errors.append("capitals[%d] (%s): capital_name must be set when capital is NO_HEX" % [i, String(tag)])
		elif not map.is_land(cap):
			errors.append("capitals[%d] (%s): capital %s is not on land" % [i, String(tag), cap])
		elif map.place_id[map.index_of(cap)] < 0:
			errors.append("capitals[%d] (%s): capital %s does not hold a place" % [i, String(tag), cap])
	return country_set


func _validate_seeds(map: MapData, country_set: Dictionary, errors: Array[String]) -> void:
	var town_places: Dictionary = {}
	for pl: Dictionary in map.places:
		if int(pl.get("level", 0)) >= 1 or int(pl.get("castle", 0)) >= 1:
			var pv: Variant = pl.get("hex", NO_HEX)
			if pv is Vector2i:
				town_places[pv as Vector2i] = str(pl.get("name", "?"))
	var seen_hexes: Dictionary = {}
	var town_counts: Dictionary = {}
	for i: int in seeds.size():
		var s: Dictionary = seeds[i]
		var hv: Variant = s.get("hex", NO_HEX)
		var hex_ok := hv is Vector2i and map.is_land(hv as Vector2i)
		if not hex_ok:
			errors.append("seeds[%d]: hex %s is not on land" % [i, hv])
		var tag := StringName(s.get("tag", &""))
		if tag == &"" or not country_set.has(tag):
			errors.append("seeds[%d]: tag '%s' is not listed in countries" % [i, String(tag)])
		var kind := StringName(s.get("kind", &""))
		if kind != &"town" and kind != &"anchor":
			errors.append("seeds[%d]: invalid kind '%s'" % [i, String(kind)])
		if hv is Vector2i:
			var hex: Vector2i = hv
			if seen_hexes.has(hex):
				errors.append("seeds[%d]: duplicate seed on hex %s" % [i, hex])
			else:
				seen_hexes[hex] = kind
			if kind == &"town":
				town_counts[hex] = int(town_counts.get(hex, 0)) + 1
			elif kind == &"anchor" and town_places.has(hex):
				errors.append("seeds[%d]: anchor seed on place '%s' at %s" % [i, str(town_places[hex]), hex])
	for phex: Vector2i in town_places:
		var count := int(town_counts.get(phex, 0))
		if count != 1:
			errors.append("seeds: place '%s' at %s must have 1 town seed, found %d" % [str(town_places[phex]), phex, count])


func _validate_pins(map: MapData, country_set: Dictionary, errors: Array[String]) -> void:
	for i: int in pins.size():
		var p: Dictionary = pins[i]
		var hv: Variant = p.get("hex", NO_HEX)
		if not (hv is Vector2i) or not map.is_land(hv as Vector2i):
			errors.append("pins[%d]: hex %s is not on land" % [i, hv])
		var tag := StringName(p.get("tag", &""))
		if tag != &"" and not country_set.has(tag):
			errors.append("pins[%d]: tag '%s' is not listed in countries" % [i, String(tag)])


func _validate_owner(map: MapData, errors: Array[String]) -> void:
	var n := map.hex_count()
	if owner.size() != n:
		errors.append("owner has %d bytes, expected %d" % [owner.size(), n])
		return
	var counts := PackedInt32Array()
	counts.resize(countries.size() + 1)
	var reported := 0
	for i: int in n:
		var oid := int(owner[i])
		if map.land[i] == 0 and oid != 0:
			if reported < 20:
				errors.append("owner: sea hex %s has owner %d" % [map.hex_of(i), oid])
			reported += 1
		if oid > countries.size():
			if reported < 20:
				errors.append("owner: hex %s has invalid owner id %d (max %d)" % [map.hex_of(i), oid, countries.size()])
			reported += 1
		else:
			counts[oid] += 1
	for i: int in countries.size():
		var cid := i + 1
		if counts[cid] == 0:
			errors.append("owner: country '%s' (id %d) owns no hex" % [String(countries[i]), cid])
		if i < capitals.size() and capitals[i] != NO_HEX:
			var cap_idx := map.index_of(capitals[i])
			if cap_idx >= 0 and int(owner[cap_idx]) != cid:
				errors.append("owner: capital %s of '%s' is owned by id %d, expected %d" % [
					capitals[i], String(countries[i]), int(owner[cap_idx]), cid])


## M8 spec 5.1: one temperament a country, each known to the defs.
func _validate_tempers(defs: GameDefs, errors: Array[String]) -> void:
	if tempers.size() != countries.size():
		errors.append("tempers has %d entries, expected %d" % [tempers.size(), countries.size()])
	for i: int in tempers.size():
		if defs.temper(tempers[i]) == null:
			errors.append("tempers[%d]: unknown temper '%s'" % [i, String(tempers[i])])


## M8 spec 5.1: each start army on land its tag owns, a known kind, 1 to 8 companies.
func _validate_start_armies(map: MapData, defs: GameDefs, country_set: Dictionary, errors: Array[String]) -> void:
	for i: int in start_armies.size():
		var a: Dictionary = start_armies[i]
		var tag := StringName(a.get("tag", &""))
		if tag == &"" or not country_set.has(tag):
			errors.append("start_armies[%d]: tag '%s' is not listed in countries" % [i, String(tag)])
		var hv: Variant = a.get("hex", NO_HEX)
		if not (hv is Vector2i) or not map.is_land(hv as Vector2i):
			errors.append("start_armies[%d]: hex %s is not on land" % [i, hv])
		elif owner.size() == map.hex_count() and tag != &"":
			var hex_owner := int(owner[map.index_of(hv as Vector2i)])
			if hex_owner != id_of(tag):
				errors.append("start_armies[%d]: hex %s is not owned by '%s'" % [i, hv, String(tag)])
		var kind := int(a.get("kind", -1))
		if defs.unit_def(kind) == null:
			errors.append("start_armies[%d]: unknown kind %d" % [i, kind])
		var count := int(a.get("count", 0))
		if count < 1 or count > 8:
			errors.append("start_armies[%d]: count is %d, expected 1 to 8" % [i, count])


## recruitment-queue.md 4.1: each start barracks on a place of the map with a settlement (level 1 or more), on land a
## country owns, listed once.
func _validate_barracks(map: MapData, errors: Array[String]) -> void:
	var seen: Dictionary = {}
	for i: int in barracks.size():
		var hex := barracks[i]
		var at := map.index_of(hex)
		var place := int(map.place_id[at]) if map.is_land(hex) else -1
		if place < 0 or int(map.places[place].get("level", 0)) < 1:
			errors.append("barracks[%d]: hex %s holds no settlement" % [i, hex])
		elif owner.size() == map.hex_count() and owner[at] == 0:
			errors.append("barracks[%d]: hex %s is owned by no one" % [i, hex])
		if seen.has(hex):
			errors.append("barracks[%d]: hex %s listed twice" % [i, hex])
		seen[hex] = true


## The start discovery of `tag` (fog spec R6): one byte a hex, 1 where the hex's region is one of the tag's regions.
## Empty when the scenario has no regions or `tag` has no entry.
func discovery_of(tag: StringName) -> PackedByteArray:
	var out := PackedByteArray()
	if regions.is_empty() or region.is_empty():
		return out
	var names: Array = []
	var found := false
	for entry: Dictionary in discovery:
		if StringName(entry.get("tag", &"")) == tag:
			names = entry.get("regions", [])
			found = true
			break
	if not found:
		return out
	var flags := PackedByteArray()
	flags.resize(regions.size() + 1)
	for k: int in regions.size():
		flags[k + 1] = 1 if names.has(regions[k]) else 0
	out.resize(region.size())
	for i: int in region.size():
		var b := int(region[i])
		out[i] = flags[b] if b < flags.size() else 0
	return out


## Fog spec R5: `region` has the map's hex count or is empty, and no byte above the region count. With no regions,
## `discovery` is empty; else every country of `countries` has exactly one entry, every name is in `regions`, and no name
## is given twice.
func _validate_regions(map: MapData, errors: Array[String]) -> void:
	var known: Dictionary = {}
	for k: int in regions.size():
		var reg := regions[k]
		if reg == &"" or known.has(reg):
			errors.append("regions[%d]: empty or duplicate name '%s'" % [k, String(reg)])
		known[reg] = true
	if not region.is_empty() and region.size() != map.hex_count():
		errors.append("region has %d bytes, expected %d or none" % [region.size(), map.hex_count()])
	var reported := 0
	for i: int in region.size():
		if int(region[i]) > regions.size():
			if reported < 20:
				errors.append("region: hex %s has region byte %d (max %d)" % [map.hex_of(i), int(region[i]), regions.size()])
			reported += 1
	if regions.is_empty():
		if not discovery.is_empty():
			errors.append("discovery has %d entries but the scenario has no regions" % discovery.size())
		return
	var entries: Dictionary = {}
	for i: int in discovery.size():
		var entry: Dictionary = discovery[i]
		var tag := StringName(entry.get("tag", &""))
		entries[tag] = int(entries.get(tag, 0)) + 1
		var given: Array = entry.get("regions", [])
		var named: Dictionary = {}
		for item: Variant in given:
			var sn := StringName(item)
			if not known.has(sn):
				errors.append("discovery[%d] (%s): region '%s' is not in regions" % [i, String(tag), String(sn)])
			if named.has(sn):
				errors.append("discovery[%d] (%s): region '%s' listed twice" % [i, String(tag), String(sn)])
			named[sn] = true
	for tag: StringName in entries:
		if not countries.has(tag):
			errors.append("discovery: tag '%s' is not listed in countries" % String(tag))
	for tag: StringName in countries:
		var n := int(entries.get(tag, 0))
		if n != 1:
			errors.append("discovery: country '%s' has %d entries, expected 1" % [String(tag), n])


func _validate_deep(map: MapData, defs: GameDefs, errors: Array[String]) -> void:
	var grown := ScenarioGrowth.grow(map, (self as Variant) as ScenarioDef)
	if grown != owner:
		var detail := "owner does not match ScenarioGrowth.grow"
		var n := mini(grown.size(), owner.size())
		for i: int in n:
			if grown[i] != owner[i]:
				detail += " (first diff at %s: owner=%d, grown=%d)" % [map.hex_of(i), int(owner[i]), int(grown[i])]
				break
		errors.append(detail)
	var pairs := ScenarioGrowth.neighbour_pairs(map, owner)
	for pair: Vector2i in pairs:
		var idx_a := pair.x - 1
		var idx_b := pair.y - 1
		if idx_a < 0 or idx_b < 0 or idx_a >= countries.size() or idx_b >= countries.size():
			continue
		var tag_a := countries[idx_a]
		var tag_b := countries[idx_b]
		var def_a := defs.country(tag_a)
		var def_b := defs.country(tag_b)
		if def_a != null and def_b != null:
			var de := ColourContrast.delta_e(def_a.colour, def_b.colour)
			if de < defs.min_contrast:
				errors.append("colour contrast between neighbours %s and %s is %.2f (min %.2f)" % [
					String(tag_a), String(tag_b), de, defs.min_contrast])
		if idx_a < cb_colours.size() and idx_b < cb_colours.size():
			var cba := int(cb_colours[idx_a])
			var cbb := int(cb_colours[idx_b])
			if cba < defs.cb_palette.size() and cbb < defs.cb_palette.size():
				var cb_de := ColourContrast.worst_delta_e(defs.cb_palette[cba], defs.cb_palette[cbb])
				if cb_de < defs.min_contrast_cb:
					errors.append("cb_colours contrast between neighbours %s and %s is %.2f (min %.2f)" % [
						String(tag_a), String(tag_b), cb_de, defs.min_contrast_cb])


static func _feed_bytes(ctx: HashingContext, bytes: PackedByteArray) -> void:
	if not bytes.is_empty():
		ctx.update(bytes)


static func _feed_int(ctx: HashingContext, value: int) -> void:
	ctx.update(PackedInt32Array([value]).to_byte_array())


static func _feed_str(ctx: HashingContext, text: String) -> void:
	var buf := text.to_utf8_buffer()
	_feed_int(ctx, buf.size())
	_feed_bytes(ctx, buf)


static func _feed_dict_list(ctx: HashingContext, list: Array[Dictionary]) -> void:
	_feed_int(ctx, list.size())
	for d: Dictionary in list:
		var keys: Array = d.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		_feed_int(ctx, keys.size())
		for k: Variant in keys:
			_feed_str(ctx, str(k))
			var v: Variant = d[k]
			_feed_str(ctx, type_string(typeof(v)) + ":" + str(v))
