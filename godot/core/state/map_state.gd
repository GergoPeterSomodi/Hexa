## What changes on the map in play (docs/architecture/m1-build-spec.md section 4, m2-build-spec.md section 5.2):
## the main use, the level and the owner of each hex, one byte each, indexed like MapData's per-hex arrays.
## A plain value: save it with to_dict, restore it with from_dict against the map it was made for.
class_name MapState
extends RefCounted

const SCHEMA_V1 := "hexa-godot/map-state/1"
const SCHEMA := "hexa-godot/map-state/2"

## ImproveRules family id; 0 = wild.
var main_use: PackedByteArray = PackedByteArray()
var level: PackedByteArray = PackedByteArray()
## Country id per hex (1 to 254); 0 = no one.
var owner: PackedByteArray = PackedByteArray()


## A wild state for a map: every hex unused, level 0, owner 0.
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
	return s


## JSON-safe: the three arrays as base64 text.
func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA,
		"size": main_use.size(),
		"main_use": Marshalls.raw_to_base64(main_use),
		"level": Marshalls.raw_to_base64(level),
		"owner": Marshalls.raw_to_base64(owner),
	}


## The state saved by to_dict, or null when the schema is wrong or the sizes do not match the map.
## Schema 1 dicts load with all-zero owners for backward compatibility.
static func from_dict(d: Dictionary, map: MapData) -> MapState:
	var schema := str(d.get("schema", ""))
	if schema != SCHEMA and schema != SCHEMA_V1:
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
	return s


## SHA-256 (hex text) of main_use, level and owner.
func digest() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	if not main_use.is_empty():
		ctx.update(main_use)
	if not level.is_empty():
		ctx.update(level)
	if not owner.is_empty():
		ctx.update(owner)
	return ctx.finish().hex_encode()
