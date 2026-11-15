## What changes on the map in play (docs/architecture/m1-build-spec.md section 4): the main use and the level of each
## hex, one byte each, indexed like MapData's per-hex arrays. A plain value: save it with to_dict, restore it with
## from_dict against the map it was made for.
class_name MapState
extends RefCounted

const SCHEMA := "hexa-godot/map-state/1"

## ImproveRules family id; 0 = wild.
var main_use: PackedByteArray = PackedByteArray()
var level: PackedByteArray = PackedByteArray()


## A wild state for a map: every hex unused, level 0.
static func create(map: MapData) -> MapState:
	var s := MapState.new()
	s.main_use.resize(map.hex_count())
	s.level.resize(map.hex_count())
	return s


func duplicate_state() -> MapState:
	var s := MapState.new()
	s.main_use = main_use.duplicate()
	s.level = level.duplicate()
	return s


## JSON-safe: the two arrays as base64 text.
func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA,
		"size": main_use.size(),
		"main_use": Marshalls.raw_to_base64(main_use),
		"level": Marshalls.raw_to_base64(level),
	}


## The state saved by to_dict, or null when the schema is wrong or the sizes do not match the map.
static func from_dict(d: Dictionary, map: MapData) -> MapState:
	if str(d.get("schema", "")) != SCHEMA:
		return null
	var s := MapState.new()
	s.main_use = Marshalls.base64_to_raw(str(d.get("main_use", "")))
	s.level = Marshalls.base64_to_raw(str(d.get("level", "")))
	var n := map.hex_count()
	if s.main_use.size() != n or s.level.size() != n:
		return null
	return s


## SHA-256 (hex text) of both arrays.
func digest() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	if not main_use.is_empty():
		ctx.update(main_use)
	if not level.is_empty():
		ctx.update(level)
	return ctx.finish().hex_encode()
