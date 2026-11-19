## Helper builders and formatters for ScenarioEditor (Pins TileSet, growth costs, hex facts, redundant pin pruning).
@tool
class_name ScenarioEditorHelpers
extends RefCounted

const MARKS_INDEX_PATH := "res://assets/tiles/summer/index.json"
const MARKS_TEXTURE_PATH := "res://assets/tiles/summer/marks.png"
const PIN_SOURCE_ID := 0
const UNOWNED_ALT_ID := 0
const PIN_TILE_NAME := "mark/white"
const PIN_ALPHA := 0.42
const UNOWNED_PIN_COLOUR := Color(0.55, 0.55, 0.55, 0.45)


## Builds a hexagonal TileSet from `mark/white` with alt 0 ("no one") and alt 1..N (per-country colour + `tag` data).
static func build_pins_tileset(scenario: ScenarioDef, palette: PackedColorArray) -> Dictionary:
	var spec := _read_mark_white_spec()
	var coords := spec["at"] as Vector2i
	var region_size := spec["region"] as Vector2i
	var sep := int(spec["separation"])
	var anchor := spec["anchor"] as Vector2i
	var tex := _load_marks_texture()

	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	ts.tile_layout = TileSet.TILE_LAYOUT_STACKED
	ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	ts.tile_size = MapTiles.CELL
	ts.add_custom_data_layer(0)
	ts.set_custom_data_layer_name(0, "tag")
	ts.set_custom_data_layer_type(0, TYPE_STRING)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.separation = Vector2i(sep, sep)
	atlas.texture_region_size = region_size
	atlas.use_texture_padding = false
	ts.add_source(atlas, PIN_SOURCE_ID)
	atlas.create_tile(coords)

	var origin := Vector2i(
		anchor.x - floori(float(region_size.x) * 0.5),
		anchor.y - floori(float(region_size.y) * 0.5)
	)
	var unowned := atlas.get_tile_data(coords, UNOWNED_ALT_ID)
	unowned.texture_origin = origin
	unowned.modulate = UNOWNED_PIN_COLOUR
	unowned.set_custom_data("tag", "")

	for i: int in scenario.countries.size():
		var cid := i + 1
		var alt_id := atlas.create_alternative_tile(coords, cid)
		var data := atlas.get_tile_data(coords, alt_id)
		data.texture_origin = origin
		var col := palette[cid] if cid < palette.size() else Color.WHITE
		data.modulate = Color(col.r, col.g, col.b, PIN_ALPHA)
		data.set_custom_data("tag", String(scenario.countries[i]))
	return {"tile_set": ts, "coords": coords}


## Returns `scenario.pins` filtered to keep only pins whose owner differs from pure unpinned growth.
static func filter_non_redundant_pins(map: MapData, scenario: ScenarioDef) -> Array[Dictionary]:
	if scenario == null or map == null or scenario.pins.is_empty():
		return scenario.pins.duplicate() if scenario != null else []
	var bare := scenario.duplicate(false) as ScenarioDef
	bare.pins = [] as Array[Dictionary]
	var bare_owner := ScenarioGrowth.grow(map, bare)
	var kept: Array[Dictionary] = []
	for pin: Dictionary in scenario.pins:
		var hv: Variant = pin.get("hex", ScenarioDef.NO_HEX)
		if not (hv is Vector2i):
			kept.append(pin)
			continue
		var hex := hv as Vector2i
		var idx := map.index_of(hex)
		if idx < 0 or map.land[idx] == 0:
			kept.append(pin)
			continue
		var pin_id := scenario.id_of(StringName(pin.get("tag", &"")))
		if pin_id != int(bare_owner[idx]):
			kept.append(pin)
	return kept


## Computes the lowest Dijkstra seed-to-hex travel cost per hex up to `scenario.reach`.
static func compute_growth_costs(map: MapData, scen: ScenarioDef) -> PackedInt32Array:
	var n := map.hex_count()
	var best := PackedInt32Array()
	best.resize(n)
	best.fill(scen.reach + 1)
	if scen.reach < 0:
		return best
	var buckets: Array[Array] = []
	buckets.resize(scen.reach + 1)
	for c: int in scen.reach + 1:
		buckets[c] = []
	for s: Dictionary in scen.seeds:
		var hv: Variant = s.get("hex", ScenarioDef.NO_HEX)
		if not (hv is Vector2i):
			continue
		var idx := map.index_of(hv as Vector2i)
		if idx < 0 or map.land[idx] == 0 or scen.id_of(StringName(s.get("tag", &""))) <= 0:
			continue
		var kind := StringName(s.get("kind", &""))
		if kind != &"town" and kind != &"anchor":
			continue
		var c0 := 0 if kind == &"town" else scen.anchor_start
		if c0 >= 0 and c0 <= scen.reach and c0 < best[idx]:
			best[idx] = c0
			(buckets[c0] as Array).append(idx)
	for c: int in scen.reach + 1:
		var bucket: Array = buckets[c]
		var k := 0
		while k < bucket.size():
			var idx := int(bucket[k])
			k += 1
			if c > best[idx]:
				continue
			var hex := map.hex_of(idx)
			for d: int in 6:
				var nb := map.neighbour(hex, d)
				var nb_idx := map.index_of(nb)
				if nb_idx < 0 or map.land[nb_idx] == 0:
					continue
				var step_c := ScenarioGrowth.step(map, scen, hex, d)
				if step_c >= 0 and c + step_c < best[nb_idx]:
					best[nb_idx] = c + step_c
					(buckets[c + step_c] as Array).append(nb_idx)
	return best


## Formats all inspect_hex facts (cover, height, relief, climate, place, rivers, roads, pass, owner, seed, pin, growth cost).
static func format_facts(map: MapData, defs: GameDefs, scen: ScenarioDef, owner: PackedByteArray,
		grown_costs: PackedInt32Array, hex: Vector2i) -> String:
	if map == null or not map.has(hex):
		return ""
	var idx := map.index_of(hex)
	if map.land[idx] == 0:
		return "Hex (%d, %d) — Sea\nDepth: %s\nRelief: %s\nClimate: %s" % [
			hex.x, hex.y,
			HexCard.word(HexCard.DEPTH_WORDS, int(map.depth[idx])),
			HexCard.word(HexCard.RELIEF_WORDS, int(map.relief[idx])),
			HexCard.word(HexCard.CLIMATE_WORDS, int(map.climate[idx])),
		]
	var pass_text := HexCard.pass_of(map, hex)
	var lines: PackedStringArray = [
		"Hex (%d, %d) — Land" % [hex.x, hex.y],
		"Cover: %s" % HexCard.cover_words(int(map.cover[idx])),
		"Height: %d m" % int(map.height_m[idx]),
		"Relief: %s" % HexCard.word(HexCard.RELIEF_WORDS, int(map.relief[idx])),
		"Climate: %s" % HexCard.word(HexCard.CLIMATE_WORDS, int(map.climate[idx])),
		"Place: %s" % _place_fact(map, hex),
		"Rivers: %s" % HexCard.edge_summary(map, hex, "river"),
		"Roads: %s" % HexCard.edge_summary(map, hex, "road"),
		"Pass: %s" % (pass_text if not pass_text.is_empty() else "none"),
		"Owner: %s" % _owner_fact(defs, scen, owner, idx),
		"Seed: %s" % _seed_fact(scen, hex),
		"Pin: %s" % _pin_fact(scen, hex),
		"Growth cost: %s" % _growth_cost_fact(map, scen, grown_costs, hex, idx),
	]
	return "\n".join(lines)


static func _place_fact(map: MapData, hex: Vector2i) -> String:
	var pl := Improve.place_of(map, hex)
	if pl.is_empty():
		return "none"
	return "%s (level %d)" % [str(pl.get("name", "?")), int(pl.get("level", 0))]


static func _owner_fact(defs: GameDefs, scen: ScenarioDef, owner: PackedByteArray, idx: int) -> String:
	var oid := int(owner[idx]) if idx >= 0 and idx < owner.size() else 0
	if oid <= 0 or scen == null:
		return "no one (0)"
	var tag := scen.tag_of(oid)
	var cdef := defs.country(tag) if defs != null else null
	return "%s — %s (id %d)" % [String(tag), cdef.long_name if cdef != null else String(tag), oid]


static func _seed_fact(scen: ScenarioDef, hex: Vector2i) -> String:
	if scen == null:
		return "none"
	for entry: Dictionary in scen.seeds:
		if entry.get("hex", ScenarioDef.NO_HEX) == hex:
			var note := str(entry.get("note", ""))
			return "%s %s%s" % [
				str(entry.get("kind", "")),
				str(entry.get("tag", "")),
				" (%s)" % note if not note.is_empty() else "",
			]
	return "none"


static func _pin_fact(scen: ScenarioDef, hex: Vector2i) -> String:
	if scen == null:
		return "none"
	for entry: Dictionary in scen.pins:
		if entry.get("hex", ScenarioDef.NO_HEX) == hex:
			var tag := StringName(entry.get("tag", &""))
			return "no one" if tag == &"" else String(tag)
	return "none"


static func _growth_cost_fact(map: MapData, scen: ScenarioDef, grown_costs: PackedInt32Array, hex: Vector2i, idx: int) -> String:
	var grown := grown_costs[idx] if idx >= 0 and idx < grown_costs.size() else -1
	var reach_str := str(grown) if grown >= 0 and scen != null and grown <= scen.reach else "unreached"
	var step_parts := PackedStringArray()
	for d: int in 6:
		var cost := ScenarioGrowth.step(map, scen, hex, d)
		if cost >= 0:
			step_parts.append("%s=%d" % [HexCard.DIRECTIONS[d], cost])
	return "grown=%s; steps: %s" % [reach_str, ", ".join(step_parts) if not step_parts.is_empty() else "none"]


static func _read_mark_white_spec() -> Dictionary:
	var out: Dictionary = {
		"at": Vector2i(3, 0),
		"region": Vector2i(172, 170),
		"separation": 2,
		"anchor": Vector2i(86, 85),
	}
	if not FileAccess.file_exists(MARKS_INDEX_PATH):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MARKS_INDEX_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	for src: Variant in (parsed as Dictionary).get("sources", []):
		var sd: Dictionary = src
		if str(sd.get("name", "")) != "marks":
			continue
		var reg: Array = sd.get("region", [172, 170])
		out["region"] = Vector2i(int(reg[0]), int(reg[1]))
		out["separation"] = int(sd.get("separation", 2))
		for tile: Variant in sd.get("tiles", []):
			var td: Dictionary = tile
			if str(td.get("name", "")) == PIN_TILE_NAME:
				var at: Array = td.get("at", [3, 0])
				var anc: Array = td.get("anchor", [86, 85])
				out["at"] = Vector2i(int(at[0]), int(at[1]))
				out["anchor"] = Vector2i(int(anc[0]), int(anc[1]))
				return out
	return out


static func _load_marks_texture() -> Texture2D:
	if ResourceLoader.exists(MARKS_TEXTURE_PATH):
		var tex := load(MARKS_TEXTURE_PATH) as Texture2D
		if tex != null:
			return tex
	if FileAccess.file_exists(MARKS_TEXTURE_PATH):
		var img := Image.load_from_file(ProjectSettings.globalize_path(MARKS_TEXTURE_PATH))
		if img != null:
			return ImageTexture.create_from_image(img)
	var fallback := Image.create(MapTiles.CELL.x, MapTiles.CELL.y, false, Image.FORMAT_RGBA8)
	fallback.fill(Color.WHITE)
	return ImageTexture.create_from_image(fallback)
