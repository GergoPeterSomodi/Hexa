## What changes on the map in play (docs/architecture/m1-build-spec.md section 4, m2-build-spec.md section 5.2,
## m3-build-spec.md 5.2): the main use, the level and the owner of each hex, one byte each, indexed like MapData's
## per-hex arrays, and the works under way. A plain value: save it with to_dict, restore it with from_dict against the
## map it was made for.
class_name MapState
extends RefCounted

## Schema 1 loads with owner zeros and no works; 2 loads with no works.
const SCHEMA_V1 := "hexa-godot/map-state/1"
const SCHEMA_V2 := "hexa-godot/map-state/2"
const SCHEMA := "hexa-godot/map-state/3"

## ImproveRules family id; 0 = wild.
var main_use: PackedByteArray = PackedByteArray()
var level: PackedByteArray = PackedByteArray()
## Country id per hex (1 to 254); 0 = no one.
var owner: PackedByteArray = PackedByteArray()
## The works under way, in id order. Written only by Works.
var works: Array[Work] = []
var next_work_id: int = 1


## A wild state for a map: every hex unused, level 0, owner 0, no works.
static func create(map: MapData) -> MapState:
	var s := MapState.new()
	var n := map.hex_count()
	s.main_use.resize(n)
	s.level.resize(n)
	s.owner.resize(n)
	return s


func duplicate_state() -> MapState:
	var s := MapState.new()
	s.main_use = main_use.duplicate()
	s.level = level.duplicate()
	s.owner = owner.duplicate()
	for w: Work in works:
		s.works.append(w.duplicate_work())
	s.next_work_id = next_work_id
	return s


## The work under way on a hex, or null when none.
func work_at(hex: Vector2i) -> Work:
	for w: Work in works:
		if w.hex == hex:
			return w
	return null


## JSON-safe: the three arrays as base64 text, the works as plain dictionaries.
func to_dict() -> Dictionary:
	var work_dicts: Array = []
	for w: Work in works:
		work_dicts.append(w.to_dict())
	return {
		"schema": SCHEMA,
		"size": main_use.size(),
		"main_use": Marshalls.raw_to_base64(main_use),
		"level": Marshalls.raw_to_base64(level),
		"owner": Marshalls.raw_to_base64(owner),
		"works": work_dicts,
		"next_work_id": next_work_id,
	}


## The state saved by to_dict, or null when the schema is wrong, the sizes do not match the map or a work is damaged.
## Schema 1 dicts load with all-zero owners and schemas 1 and 2 with no works.
static func from_dict(d: Dictionary, map: MapData) -> MapState:
	var schema := str(d.get("schema", ""))
	if schema != SCHEMA and schema != SCHEMA_V2 and schema != SCHEMA_V1:
		return null
	var n := map.hex_count()
	var s := MapState.new()
	s.main_use = Marshalls.base64_to_raw(str(d.get("main_use", "")))
	s.level = Marshalls.base64_to_raw(str(d.get("level", "")))
	if s.main_use.size() != n or s.level.size() != n:
		return null
	if schema == SCHEMA_V1:
		s.owner.resize(n)
	else:
		if not d.has("owner"):
			return null
		s.owner = Marshalls.base64_to_raw(str(d.get("owner", "")))
		if s.owner.size() != n:
			return null
	if schema == SCHEMA and not s._load_works(d, map):
		return null
	return s


func _load_works(d: Dictionary, map: MapData) -> bool:
	var raw: Variant = d.get("works", null)
	var next_raw: Variant = Work.whole(d.get("next_work_id", null))
	if not (raw is Array) or next_raw == null:
		return false
	var seen: Dictionary = {}
	var last_id := 0
	for item: Variant in raw as Array:
		if not (item is Dictionary):
			return false
		var w := Work.from_dict(item as Dictionary)
		if w == null or map.index_of(w.hex) < 0 or seen.has(w.hex) or w.id <= last_id:
			return false
		seen[w.hex] = true
		last_id = w.id
		works.append(w)
	next_work_id = int(next_raw)
	return next_work_id > last_id


## SHA-256 (hex text) of main_use, level, owner, each work's digest_text and next_work_id.
func digest() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	if not main_use.is_empty():
		ctx.update(main_use)
	if not level.is_empty():
		ctx.update(level)
	if not owner.is_empty():
		ctx.update(owner)
	var parts: PackedStringArray = []
	for w: Work in works:
		parts.append(w.digest_text())
	parts.append(str(next_work_id))
	ctx.update("\n".join(parts).to_utf8_buffer())
	return ctx.finish().hex_encode()
