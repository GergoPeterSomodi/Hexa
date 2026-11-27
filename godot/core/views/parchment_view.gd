## The parchment map's facts for one viewer (docs/architecture/map-overview-build-spec.md R7, R8, R12 to R14, R20, R21,
## R23, D3, D7 and section 4): the owner and goods bytes, the goods and their legend, the country names, the towns and
## the hover line. The fog is applied here: no output holds anything of a hex the viewer has not discovered
## (MapModes.discovered_bytes), so the shell and its shaders are never given such a fact. Light fog is exact (owners and
## goods are land facts). Armies and occupiers are not read. The viewer "" sees all.
## Pure core/views/ code: no nodes, no engine calls, no luck. What it returns from the view cache is not to be written.
class_name ParchmentView
extends RefCounted

## The owner byte of a hex the viewer has not discovered (country ids run 1 to 254, 0 is no one).
const UNKNOWN := 255
## Bytes a hex in goods_bytes: the good id plus one, then the stage.
const GOODS_STRIDE := 2
## A district's stages run 1 to MAX_STAGE.
const MAX_STAGE := 3
## A country name's angle stays within this many degrees of level.
const NAME_ANGLE_MAX_DEG := 55.0
## The least level of a town that is listed (a village: a dot), and the least that is named (a town). Capitals are both.
const TOWN_DOT_LEVEL := 2
const TOWN_NAME_LEVEL := 3
## The legend's words for stages 1 to 3, and for the land that makes none of the good.
const STAGE_TEXTS: Array[String] = ["First stage", "Second stage", "Third stage"]
const NOT_HERE_TEXT := "Not here"
## The stage of the legend's last row, which has words only (no swatch): how many districts make the good.
const COUNT_ROW := -1
const NONE_TEXT := "none you know"
const UNEXPLORED_TEXT := "Unexplored"
const UNCLAIMED_TEXT := "Unclaimed land"
const SEA_TEXT := "Sea"
const TIP_SEPARATOR := " · "


## One byte a hex (index = row * cols + col): the owner's country id, 0 for no one (and the sea), UNKNOWN where the
## viewer has not discovered the hex. Empty without a game.
static func owner_bytes(game: Game, viewer: StringName) -> PackedByteArray:
	if not _has_map(game):
		return PackedByteArray()
	var seen := MapModes.discovered_bytes(game, viewer)
	var key: Array = [hash(seen), hash(game.state.owner), game.map.hex_count()]
	return game.view_cache.pinned(&"parchment_owner", key,
		func() -> PackedByteArray: return _make_owner_bytes(game, seen)) as PackedByteArray


## GOODS_STRIDE bytes a hex: the good id plus one and the stage (1 to 3) of a district that makes a good
## (Economy.good_of); 0 and 0 where none is made and where the viewer has not discovered the hex. Empty without a game.
static func goods_bytes(game: Game, viewer: StringName) -> PackedByteArray:
	if not _has_map(game):
		return PackedByteArray()
	return _goods(game, viewer)[0] as PackedByteArray


## The goods some family makes, in GameDefs order: {id: int, key: StringName, name: String, icon: StringName}.
static func goods_list(game: Game) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null or game.defs == null:
		return out
	var made: Dictionary[StringName, bool] = {}
	for fam: FamilyDef in game.defs.families:
		if fam == null:
			continue
		if fam.good != &"":
			made[fam.good] = true
		for key: StringName in fam.by_extra.values():
			made[key] = true
	for good: GoodDef in game.defs.goods:
		if good != null and made.has(good.key):
			out.append({"id": good.id, "key": good.key, "name": good.name, "icon": good.icon})
	return out


## How many districts the viewer has discovered make the good; 0 for an unknown good.
static func count_of(game: Game, viewer: StringName, good_id: int) -> int:
	if not _has_map(game):
		return 0
	var counts := _goods(game, viewer)[1] as PackedInt32Array
	return counts[good_id] if good_id >= 0 and good_id < counts.size() else 0


## "14 districts you know make it", "1 district you know makes it", "none you know".
static func count_words(count: int) -> String:
	if count <= 0:
		return NONE_TEXT
	return "%s you know %s it" % [Words.plural(count, "district", "districts"), "makes" if count == 1 else "make"]


## The legend of the good's map, top row first: {stage: int, text: String, pips: int} for stages 1 to 3 (pips = stage),
## then stage 0 "Not here" (no pips), then stage COUNT_ROW with count_words. The title is the good's name (goods_list).
## [] for an unknown good.
static func legend(game: Game, viewer: StringName, good_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _has_map(game) or game.defs == null or game.defs.good(good_id) == null:
		return out
	for stage: int in range(1, MAX_STAGE + 1):
		out.append({"stage": stage, "text": STAGE_TEXTS[stage - 1], "pips": stage})
	out.append({"stage": 0, "text": NOT_HERE_TEXT, "pips": 0})
	out.append({"stage": COUNT_ROW, "text": count_words(count_of(game, viewer, good_id)), "pips": 0})
	return out


## One name a region (CountryNames.MIN_REGION_HEXES or more hexes, joined through discovered hexes only) of the hexes the
## viewer has discovered of one owner, in country id order then region order: {tag: StringName, text: String (the short
## name), at: Vector2 (map px), angle_deg: float (the long axis of the hex centres, clockwise on screen, within
## NAME_ANGLE_MAX_DEG), span_px: float (the region's length along that angle, map px), hexes: int}. `at` is the middle
## of the hex centres, or the centre of the region's innermost hex when that middle lies outside the region (so a name
## never stands on a hex that is not the region's). [] in a game without countries.
static func country_names(game: Game, viewer: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _has_map(game) or not game.has_countries():
		return out
	var owners := owner_bytes(game, viewer)
	# A memo of the names by country id and the bytes they were made from: an owner change or a discovery names again
	# only the countries whose hexes changed in those bytes.
	var memo: Dictionary = game.view_cache.pinned(&"parchment_names", game.map.hex_count(),
		func() -> Dictionary: return {"owners": PackedByteArray(), "names": {}})
	var names: Dictionary = memo["names"]
	_forget_changed(names, memo["owners"] as PackedByteArray, owners, game.map.cols)
	memo["owners"] = owners
	for country: Country in game.countries:
		if country == null:
			continue
		if not names.has(country.id):
			names[country.id] = _names_of(game, owners, country.id)
		for entry: Dictionary in names[country.id]:
			out.append(entry.duplicate())
	return out


## The towns the viewer has discovered, in placing order (capitals first, then by level, highest first, then by name):
## {hex: Vector2i, name: String ("" for a town with no place name), level: int, capital: bool, at: Vector2 (map px)}.
## A town is a settlement of TOWN_DOT_LEVEL or more, by the state's level; the capital of every living country is listed
## whatever its level.
static func towns(game: Game, viewer: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _has_map(game):
		return out
	var seen := MapModes.discovered_bytes(game, viewer)
	var capitals: Dictionary[int, StringName] = {}  # hex index -> tag
	for country: Country in game.countries:
		if country == null or not country.alive or country.capital == Country.NO_HEX:
			continue
		var i := game.map.index_of(country.capital)
		if i >= 0 and seen[i] == 1:
			capitals[i] = country.tag
	var key: Array = [hash(seen), hash(game.state.main_use), hash(game.state.level), capitals.hash(),
		game.map.hex_count()]
	var held: Array = game.view_cache.pinned(&"parchment_towns", key,
		func() -> Array: return _make_towns(game, seen, capitals))
	for town: Dictionary in held:
		out.append(town.duplicate())
	return out


## The one-line hover text: "place · owner · good". The place only when the hex has one; the owner's short name, or
## "Unclaimed land". In Goods mode the chosen good and the stage ("Grain, second stage") when the district makes it,
## else no good; in every other mode the good the district makes. "Unexplored" for an undiscovered hex, whatever it
## holds; "Sea" for a discovered sea hex; "" off the map.
static func tip(game: Game, viewer: StringName, hex: Vector2i, mode: int, good_id: int) -> String:
	if not _has_map(game) or not game.map.has(hex):
		return ""
	var i := game.map.index_of(hex)
	if MapModes.discovered_bytes(game, viewer)[i] == 0:
		return UNEXPLORED_TEXT
	if game.map.land[i] == 0:
		return SEA_TEXT
	var parts := PackedStringArray()
	var place := str(Improve.place_of(game.map, hex).get("name", ""))
	if place != "":
		parts.append(place)
	var tag := Territory.owner_tag(game, hex)
	parts.append(_short_name(game, tag) if tag != &"" else UNCLAIMED_TEXT)
	var made := _good_at(game, i, _family_goods(game))
	if made >= 0:
		if mode != MapModes.Mode.GOODS:
			parts.append(game.defs.good(made).name)
		elif made == good_id:
			var stage := clampi(game.state.level[i], 1, MAX_STAGE)
			parts.append("%s, %s" % [game.defs.good(made).name, STAGE_TEXTS[stage - 1].to_lower()])
	return TIP_SEPARATOR.join(parts)


static func _has_map(game: Game) -> bool:
	return game != null and game.map != null and game.state != null


static func _make_owner_bytes(game: Game, seen: PackedByteArray) -> PackedByteArray:
	var n := game.map.hex_count()
	var owners := game.state.owner
	var land := game.map.land
	var out := owners.duplicate()
	out.resize(n)
	for i: int in n:
		if seen[i] == 0:
			out[i] = UNKNOWN
		elif land[i] == 0:
			out[i] = 0
	return out


## [goods bytes, districts a good id (PackedInt32Array)], made together and pinned while the discovered set, the uses and
## the levels stay.
static func _goods(game: Game, viewer: StringName) -> Array:
	var seen := MapModes.discovered_bytes(game, viewer)
	var key: Array = [hash(seen), hash(game.state.main_use), hash(game.state.level), game.map.hex_count()]
	return game.view_cache.pinned(&"parchment_goods", key, func() -> Array: return _make_goods(game, seen)) as Array


static func _make_goods(game: Game, seen: PackedByteArray) -> Array:
	var n := game.map.hex_count()
	var out := PackedByteArray()
	out.resize(n * GOODS_STRIDE)  # zero: none
	var counts := PackedInt32Array()
	if game.defs == null:
		return [out, counts]
	counts.resize(game.defs.goods.size())
	var table := _family_goods(game)
	var uses := game.state.main_use
	var levels := game.state.level
	for i: int in mini(n, uses.size()):
		if uses[i] == 0 or seen[i] == 0:
			continue
		var good := _good_at(game, i, table)
		if good < 0:
			continue
		out[i * GOODS_STRIDE] = good + 1
		out[i * GOODS_STRIDE + 1] = clampi(levels[i], 1, MAX_STAGE)
		counts[good] += 1
	return [out, counts]


## By family id: the good the family makes, -1 for none, -2 when the hex's animal or ore says which (by_extra).
static func _family_goods(game: Game) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(FamilyIds.COUNT)
	out.fill(-1)
	if game.defs == null:
		return out
	for fam: FamilyDef in game.defs.families:
		if fam == null or fam.id <= 0 or fam.id >= FamilyIds.COUNT:
			continue
		if fam.good != &"":
			out[fam.id] = game.defs.good_id(fam.good)
		elif not fam.by_extra.is_empty():
			out[fam.id] = -2
	return out


## Economy.good_of of hex index `i` (-1 for none) without the rest of the district's numbers, which are too slow for a
## whole map; test_parchment_view holds the two equal.
static func _good_at(game: Game, i: int, table: PackedInt32Array) -> int:
	if game.map.land[i] == 0 or i >= game.state.main_use.size():
		return -1
	var family := int(game.state.main_use[i])
	var level := int(game.state.level[i])
	if family <= 0 or family >= table.size() or level < 1:
		return -1
	var good := table[family]
	if good != -2:
		return good
	var fam := game.defs.family(family)
	var extra := str(Improve.piece_for(game.map, game.map.hex_of(i), family, level).get("extra", "-"))
	return game.defs.good_id(fam.by_extra[extra]) if fam.by_extra.has(extra) else -1


## Drops from `names` (country id -> entries) every id that gained or lost a hex between the owner bytes `was` and
## `now`; all of them when the sizes differ. Rows that are equal are passed over whole.
static func _forget_changed(names: Dictionary, was: PackedByteArray, now: PackedByteArray, cols: int) -> void:
	if was == now:
		return
	if was.size() != now.size():
		names.clear()
		return
	for from: int in range(0, now.size(), cols):
		if was.slice(from, from + cols) == now.slice(from, from + cols):
			continue
		for i: int in range(from, mini(from + cols, now.size())):
			if was[i] != now[i]:
				names.erase(int(was[i]))
				names.erase(int(now[i]))


## The names of one country's regions, from the masked owner bytes: an undiscovered hex is no part of any region.
static func _names_of(game: Game, owners: PackedByteArray, id: int) -> Array:
	var out: Array = []
	var tag := Countries.by_id(game, id).tag
	var text := _short_name(game, tag)
	for region: PackedInt32Array in ScenarioGrowth.regions(game.map, owners, id):
		if region.size() >= CountryNames.MIN_REGION_HEXES:
			out.append(_name_entry(game.map, tag, text, region))
	return out


static func _name_entry(map: MapData, tag: StringName, text: String, region: PackedInt32Array) -> Dictionary:
	var centres := PackedVector2Array()
	var sum := Vector2.ZERO
	for i: int in region:
		var at := MapTiles.cell_centre(map.hex_of(i))
		centres.append(at)
		sum += at
	var mid := sum / float(region.size())
	var xx := 0.0
	var yy := 0.0
	var xy := 0.0
	for at: Vector2 in centres:
		var d := at - mid
		xx += d.x * d.x
		yy += d.y * d.y
		xy += d.x * d.y
	var angle := clampf(rad_to_deg(0.5 * atan2(2.0 * xy, xx - yy)), -NAME_ANGLE_MAX_DEG, NAME_ANGLE_MAX_DEG)
	var axis := Vector2.from_angle(deg_to_rad(angle))
	var low := INF
	var high := -INF
	for at: Vector2 in centres:
		var u := (at - mid).dot(axis)
		low = minf(low, u)
		high = maxf(high, u)
	if not region.has(map.index_of(MapModes.hex_at_px(mid))):
		mid = MapTiles.cell_centre(CountryNames.region_label_hex(map, region))
	return {"tag": tag, "text": text, "at": mid, "angle_deg": angle, "span_px": high - low + float(MapTiles.CELL.x),
		"hexes": region.size()}


static func _make_towns(game: Game, seen: PackedByteArray, capitals: Dictionary[int, StringName]) -> Array:
	var out: Array = []
	var uses := game.state.main_use
	var i := uses.find(ImproveRules.SETTLEMENT)
	while i >= 0:
		if not capitals.has(i) and i < seen.size() and seen[i] == 1 and game.map.land[i] == 1 \
				and game.state.level[i] >= TOWN_DOT_LEVEL:
			out.append(_town(game, i, &""))
		i = uses.find(ImproveRules.SETTLEMENT, i + 1)
	for at: int in capitals:
		out.append(_town(game, at, capitals[at]))
	out.sort_custom(_town_before)
	return out


## The town on hex index `i`; `capital_of` is the tag whose capital it is, &"" for none.
static func _town(game: Game, i: int, capital_of: StringName) -> Dictionary:
	var hex := game.map.hex_of(i)
	var place := Improve.place_of(game.map, hex)
	var name := str(place.get("name", ""))
	if name == "" and capital_of != &"":
		var cdef := Countries.def_of(game, capital_of)
		name = cdef.capital_name if cdef != null else ""
	var settled := i < game.state.main_use.size() and game.state.main_use[i] == ImproveRules.SETTLEMENT
	var level := int(game.state.level[i]) if settled else int(place.get("level", 0))
	return {"hex": hex, "name": name, "level": level, "capital": capital_of != &"", "at": MapTiles.cell_centre(hex)}


static func _town_before(a: Dictionary, b: Dictionary) -> bool:
	if a["capital"] != b["capital"]:
		return bool(a["capital"])
	if a["level"] != b["level"]:
		return int(a["level"]) > int(b["level"])
	if a["name"] != b["name"]:
		return str(a["name"]) < str(b["name"])
	var ha: Vector2i = a["hex"]
	var hb: Vector2i = b["hex"]
	return ha.y < hb.y or (ha.y == hb.y and ha.x < hb.x)


static func _short_name(game: Game, tag: StringName) -> String:
	var cdef := Countries.def_of(game, tag)
	return cdef.name if cdef != null and not cdef.name.is_empty() else String(tag)
