## What changes on the map in play (docs/architecture/m1-build-spec.md section 4, m2-build-spec.md section 5.2,
## m3-build-spec.md 5.2): the main use, the level and the owner of each hex, one byte each, indexed like MapData's
## per-hex arrays, and the works under way. A plain value: save it with to_dict, restore it with from_dict against the
## map it was made for.
class_name MapState
extends RefCounted

## Schema 1 loads with owner zeros and no works; 2 loads with no works; 1 to 3 load with the people arrays at zeros;
## 4 (tests only) loads with the three occupation arrays at zeros (docs/architecture/m7-build-spec.md 5.2); 1 to 5 load
## with no barracks (docs/design/recruitment-queue.md).
const SCHEMA_V1 := "hexa-godot/map-state/1"
const SCHEMA_V2 := "hexa-godot/map-state/2"
const SCHEMA_V3 := "hexa-godot/map-state/3"
const SCHEMA_V4 := "hexa-godot/map-state/4"
const SCHEMA_V5 := "hexa-godot/map-state/5"
const SCHEMA := "hexa-godot/map-state/6"

## ImproveRules family id; 0 = wild.
var main_use: PackedByteArray = PackedByteArray()
var level: PackedByteArray = PackedByteArray()
## Country id per hex (1 to 254); 0 = no one.
var owner: PackedByteArray = PackedByteArray()
## The works under way, in id order. Written only by Works.
var works: Array[Work] = []
var next_work_id: int = 1
## Whole persons per hex (docs/architecture/m5-build-spec.md 5.2); sea 0. Written only by People.
var people: PackedInt32Array = PackedInt32Array()
## The people at the start and at the end of the last season ended; written only by People (close).
var people_start: PackedInt32Array = PackedInt32Array()
var people_end: PackedInt32Array = PackedInt32Array()
## Per hex: 0 the owner holds it, else the occupying country's id. Written only by Occupation (M7).
var occupier: PackedByteArray = PackedByteArray()
## Per hex: men of a fortress's garrison; 0 elsewhere. Written only by Occupation (M7).
var garrison: PackedInt32Array = PackedInt32Array()
## Per hex: seasons an occupied hex had no support (D18). Written only by Occupation (M7).
var unsupported: PackedByteArray = PackedByteArray()
## Per hex: 1 where a barracks stands (only ever on a settlement), else 0. Written only by Recruiting.
var barracks: PackedByteArray = PackedByteArray()


## A wild state for a map: every hex unused, level 0, owner 0, no works.
static func create(map: MapData) -> MapState:
	var s := MapState.new()
	var n := map.hex_count()
	s.main_use.resize(n)
	s.level.resize(n)
	s.owner.resize(n)
	s.people.resize(n)
	s.people_start.resize(n)
	s.people_end.resize(n)
	s.occupier.resize(n)
	s.garrison.resize(n)
	s.unsupported.resize(n)
	s.barracks.resize(n)
	return s


func duplicate_state() -> MapState:
	var s := MapState.new()
	s.main_use = main_use.duplicate()
	s.level = level.duplicate()
	s.owner = owner.duplicate()
	s.people = people.duplicate()
	s.people_start = people_start.duplicate()
	s.people_end = people_end.duplicate()
	s.occupier = occupier.duplicate()
	s.garrison = garrison.duplicate()
	s.unsupported = unsupported.duplicate()
	s.barracks = barracks.duplicate()
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


## The byte arrays as base64 text, the works as plain dictionaries, the people and garrison arrays as they are.
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
		"people": people.duplicate(),
		"people_start": people_start.duplicate(),
		"people_end": people_end.duplicate(),
		"occupier": Marshalls.raw_to_base64(occupier),
		"garrison": garrison.duplicate(),
		"unsupported": Marshalls.raw_to_base64(unsupported),
		"barracks": Marshalls.raw_to_base64(barracks),
	}


## The state saved by to_dict, or null when the schema is wrong, the sizes do not match the map or a work is damaged.
## Schema 1 dicts load with all-zero owners, schemas 1 and 2 with no works, schemas 1 to 3 with zero people, schemas 1
## to 5 with no barracks.
static func from_dict(d: Dictionary, map: MapData) -> MapState:
	var schema := str(d.get("schema", ""))
	if not [SCHEMA, SCHEMA_V5, SCHEMA_V4, SCHEMA_V3, SCHEMA_V2, SCHEMA_V1].has(schema):
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
	var has_works := schema != SCHEMA_V1 and schema != SCHEMA_V2
	if has_works and not s._load_works(d, map):
		return null
	if schema == SCHEMA or schema == SCHEMA_V5 or schema == SCHEMA_V4:
		if not s._load_people(d, n):
			return null
	else:
		s.people.resize(n)
		s.people_start.resize(n)
		s.people_end.resize(n)
	if schema == SCHEMA or schema == SCHEMA_V5:
		if not s._load_occupation(d, map):
			return null
	else:
		s.occupier.resize(n)
		s.garrison.resize(n)
		s.unsupported.resize(n)
	if schema == SCHEMA:
		if not s._load_barracks(d, map):
			return null
	else:
		s.barracks.resize(n)
	return s


## Reads the barracks of a schema 6 dict: base64 bytes of the map's size, each 0 or 1, none at sea. False when missing or
## damaged. That each stands on a settlement is the snapshot's check.
func _load_barracks(d: Dictionary, map: MapData) -> bool:
	var n := map.hex_count()
	var raw: Variant = d.get("barracks", null)
	if not (raw is String):
		return false
	barracks = Marshalls.base64_to_raw(raw as String)
	if barracks.size() != n:
		return false
	for i: int in n:
		if barracks[i] > 1 or (barracks[i] != 0 and map.land[i] == 0):
			return false
	return true


## Reads the three occupation arrays of a schema 5 or 6 dict: occupier and unsupported as base64 bytes of n, garrison as n
## whole numbers (a packed array or a JSON list), no negatives. False when one is missing or the wrong size.
func _load_occupation(d: Dictionary, map: MapData) -> bool:
	var n := map.hex_count()
	occupier = Marshalls.base64_to_raw(str(d.get("occupier", "")))
	unsupported = Marshalls.base64_to_raw(str(d.get("unsupported", "")))
	var ints: Variant = _ints_of(d.get("garrison", null), n)
	if occupier.size() != n or unsupported.size() != n or ints == null:
		return false
	# A country id is 1 to 254 (0: the owner holds it); only land is occupied or garrisoned.
	for i: int in n:
		if occupier[i] > 254:
			return false
		if (occupier[i] != 0 or (ints as PackedInt32Array)[i] != 0) and map.land[i] == 0:
			return false
	garrison = ints as PackedInt32Array
	return true


## Reads the three people arrays of a schema 4 dict; false when one is missing, is neither a PackedInt32Array nor a list
## of whole numbers (a JSON copy), has a whole-number entry below 0 or has the wrong size.
func _load_people(d: Dictionary, n: int) -> bool:
	var out: Array[PackedInt32Array] = []
	for key: String in ["people", "people_start", "people_end"]:
		var ints: Variant = _ints_of(d.get(key, null), n)
		if ints == null:
			return false
		out.append(ints as PackedInt32Array)
	people = out[0]
	people_start = out[1]
	people_end = out[2]
	return true


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


## A PackedInt32Array of exactly n non-negative whole numbers from a packed array or a list; null for anything else.
static func _ints_of(raw: Variant, n: int) -> Variant:
	var out := PackedInt32Array()
	if raw is PackedInt32Array:
		out = (raw as PackedInt32Array).duplicate()
	elif raw is Array and (raw as Array).size() == n:
		for item: Variant in raw as Array:
			var whole: Variant = Unit.int32(item)
			if whole == null:
				return null
			out.append(int(whole))
	else:
		return null
	if out.size() != n:
		return null
	for v: int in out:
		if v < 0:
			return null
	return out


## SHA-256 (hex text) of main_use, level, owner, people, people_start, people_end (as bytes of their ints), occupier,
## garrison, unsupported, barracks, each work's digest_text and next_work_id.
func digest() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	if not main_use.is_empty():
		ctx.update(main_use)
	if not level.is_empty():
		ctx.update(level)
	if not owner.is_empty():
		ctx.update(owner)
	for ints: PackedInt32Array in [people, people_start, people_end]:
		if not ints.is_empty():
			ctx.update(ints.to_byte_array())
	# M7 (5.2): occupier, garrison, unsupported, in this order.
	if not occupier.is_empty():
		ctx.update(occupier)
	if not garrison.is_empty():
		ctx.update(garrison.to_byte_array())
	if not unsupported.is_empty():
		ctx.update(unsupported)
	if not barracks.is_empty():
		ctx.update(barracks)
	var parts: PackedStringArray = []
	for w: Work in works:
		parts.append(w.digest_text())
	parts.append(str(next_work_id))
	ctx.update("\n".join(parts).to_utf8_buffer())
	return ctx.finish().hex_encode()
