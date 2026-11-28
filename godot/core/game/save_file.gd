## The save file (docs/architecture/m3-build-spec.md 4.10, 5.4): line 1 a JSON header, then the zstd-compressed body of
## Snapshot. Writing never leaves a half file: a temp file in the same folder, the old file moved aside, the temp file
## renamed, the backup deleted; the old save stays in `.sav` or `.bak` on any failure. The only place in core/ that touches
## files (the one door for saves).
class_name SaveFile
extends RefCounted

## 9: recruitment (recruitment-queue.md 6): map-state/6 adds `barracks`, in the digest, and an old `raise` record will mean
## something else; a format-8 file is refused as older, quietly ("Made by an older test build"). No upgrade step.
## 8: moves in the month (moves-build-spec.md R55, D22): army/3 adds `points` and `season_from`, both in the digest; a format-7
## file is refused as older, quietly ("Made by an older test build").
## 7: the fog build (fog-build-spec R38, D16): a format-6 (M8) file is refused as older, quietly ("Made by an older
## test build"); the body keeps its shape (country/4's `explored`; chronicle entries may carry `land`).
## 6: M8 (4.15, D34): the digest gains ai_only, the body `game.ai_only` and `log_from`, the log keeps the last 40 seasons. A
## format-5 (M7) file is refused as older, quietly ("Made by an older test build"). 5 had the war body (M7, 4.20).
const FORMAT := 9
const OLDEST_FORMAT := 9
const DIR := "user://saves"
const SLOTS: Array[String] = ["quick", "1", "2", "3", "4", "5", "6", "7", "8"]
const AUTO_SLOTS: Array[String] = ["auto1", "auto2", "auto3"]
const THUMB := Vector2i(192, 108)
const HEADER_MAX := 4096
const BODY_MAX := 536870912
const NAME_MAX := 120
## The largest whole number a JSON float holds exactly (2^53).
const MAX_EXACT := 9007199254740992.0


## True for a slot name of SLOTS or AUTO_SLOTS: nothing else may become a file name.
static func is_slot(slot: String) -> bool:
	return SLOTS.has(slot) or AUTO_SLOTS.has(slot)


## The `.sav` path of a slot, or "" for a name that is not a slot (no path out of the folder).
static func path_of(slot: String, dir: String = DIR) -> String:
	if not is_slot(slot):
		return ""
	return dir.path_join(slot + ".sav")


## The header of 4.10 without the three body fields (write adds them). `info`: build, name, saved_unix, play_seconds, and
## optionally map_digest and scenario_digest (a caller that knows them saves the hashing).
static func header_of(game: Game, slot: String, info: Dictionary) -> Dictionary:
	var scenario_id := ""
	var scenario_digest := ""
	if game.scenario != null:
		scenario_id = game.scenario.id
		scenario_digest = str(info["scenario_digest"]) if info.has("scenario_digest") else game.scenario.digest()
	var map_digest := str(info["map_digest"]) if info.has("map_digest") else game.map.digest()
	var country := ""
	if game.scenario == null:
		country = "Sandbox"
	elif game.player != &"":
		var def := Countries.def_of(game, game.player)
		country = def.long_name if def != null else String(game.player)
	return {
		"hexa": "save", "format": FORMAT, "build": str(info.get("build", "")), "slot": slot,
		"name": str(info.get("name", "")).left(NAME_MAX),
		"map_id": game.map.id, "map_digest": map_digest,
		"scenario_id": scenario_id, "scenario_digest": scenario_digest,
		"tag": String(game.player), "country": country,
		"turn": game.turn, "date": game.date_text(),
		"saved_unix": int(info.get("saved_unix", 0)), "play_seconds": int(info.get("play_seconds", 0)),
		"digest": game.digest(),
	}


## "" or the problem. The sequence of 4.10 (D33); `json_too` also writes `<slot>.body.json` for a developer.
static func write(game: Game, slot: String, info: Dictionary, ui: Dictionary, dir: String = DIR,
		json_too: bool = false) -> String:
	if not is_slot(slot):
		return "no slot '%s'" % slot
	if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
		return "the save could not be written"
	var body: Dictionary = Snapshot.of(game, ui)
	var plain := var_to_bytes(body)
	var packed := plain.compress(FileAccess.COMPRESSION_ZSTD)
	var header := header_of(game, slot, info)
	header["body_bytes"] = packed.size()
	header["body_size"] = plain.size()
	header["body_sha256"] = _sha(packed)
	var sav := path_of(slot, dir)
	var tmp := sav + ".tmp"
	var bak := sav + ".bak"
	var problem := _write_tmp(tmp, header, packed)
	if problem.is_empty():
		problem = _swap(tmp, sav, bak)
	if not problem.is_empty():
		DirAccess.remove_absolute(tmp)
		return problem
	if json_too:
		var f := FileAccess.open(dir.path_join(slot + ".body.json"), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(body, "  "))
			f.close()
	return ""


static func _write_tmp(tmp: String, header: Dictionary, packed: PackedByteArray) -> String:
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return _words(FileAccess.get_open_error())
	var ok := f.store_buffer((JSON.stringify(header) + "\n").to_utf8_buffer())
	ok = f.store_buffer(packed) and ok
	f.flush()
	var err := f.get_error()
	f.close()
	if not ok or err != OK:
		return _words(err)
	return ""


## The old `.bak` goes, `.sav` becomes `.bak`, `.tmp` becomes `.sav`, `.bak` goes. A failure puts the old save back.
static func _swap(tmp: String, sav: String, bak: String) -> String:
	var had_old := FileAccess.file_exists(sav)
	if had_old:
		if FileAccess.file_exists(bak) and DirAccess.remove_absolute(bak) != OK:
			return "the save could not be written"
		if DirAccess.rename_absolute(sav, bak) != OK:
			return "the save could not be written"
	if DirAccess.rename_absolute(tmp, sav) != OK:
		if had_old:
			DirAccess.rename_absolute(bak, sav)
		return "the save could not be written"
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(bak)
	return ""


static func _words(err: Error) -> String:
	if err == ERR_FILE_NO_PERMISSION or err == ERR_UNAUTHORIZED:
		return "permission denied"
	if err == ERR_OUT_OF_MEMORY or err == ERR_FILE_CANT_WRITE:
		return "no space left on the disk"
	return "the save could not be written"


static func _sha(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


## {state: &"empty" | &"ok" | &"newer" | &"older" | &"broken", header: Dictionary}. `.bak` stands in when `.sav` is
## missing or broken. Only the first line and the file's length are read.
static func read_header(slot: String, dir: String = DIR) -> Dictionary:
	if not is_slot(slot):
		return {"state": &"empty", "header": {}}
	var sav := path_of(slot, dir)
	var bak := sav + ".bak"
	if not FileAccess.file_exists(sav) and not FileAccess.file_exists(bak):
		return {"state": &"empty", "header": {}}
	var first := _header_of_file(sav)
	if first["state"] == &"broken" and FileAccess.file_exists(bak):
		return _header_of_file(bak)
	return first


## {state, header, offset}: the header line of one file; "offset" is where the body starts.
static func _header_of_file(path: String) -> Dictionary:
	var broken := {"state": &"broken", "header": {}, "offset": 0}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return broken
	var length := f.get_length()
	var head := f.get_buffer(mini(length, HEADER_MAX + 1))
	f.close()
	var end := head.find(10)
	if end < 0:
		return broken
	var line := head.slice(0, end)
	if not _utf8_ok(line) or not _numbers_ok(line):
		return broken
	var json := JSON.new()
	if json.parse(line.get_string_from_utf8()) != OK or not (json.data is Dictionary):
		return broken
	var header := _clean(json.data as Dictionary)
	if header.is_empty():
		return broken
	if length != end + 1 + int(header["body_bytes"]):
		return broken
	var state := &"ok"
	if int(header["format"]) > FORMAT:
		state = &"newer"
	elif int(header["format"]) < OLDEST_FORMAT:
		state = &"older"
	return {"state": state, "header": header, "offset": end + 1}


## True when the bytes are well-formed UTF-8 (decoding a damaged line would print engine errors).
static func _utf8_ok(bytes: PackedByteArray) -> bool:
	var i := 0
	var n := bytes.size()
	while i < n:
		var b := bytes[i]
		var extra := 0
		if b >= 0xF5 or (b >= 0x80 and b < 0xC2):
			return false
		elif b >= 0xF0:
			extra = 3
		elif b >= 0xE0:
			extra = 2
		elif b >= 0xC0:
			extra = 1
		if i + extra >= n and extra > 0:
			return false
		for k: int in extra:
			var c := bytes[i + 1 + k]
			if c & 0xC0 != 0x80:
				return false
			if k == 0 and ((b == 0xE0 and c < 0xA0) or (b == 0xF0 and c < 0x90) or (b == 0xED and c > 0x9F)
					or (b == 0xF4 and c > 0x8F)):
				return false
		i += extra + 1
	return true


## True when no number outside a string has a fraction, an exponent or more than 16 digits: the header holds whole
## numbers only, and the JSON parser warns about a huge exponent.
static func _numbers_ok(line: PackedByteArray) -> bool:
	var in_string := false
	var escaped := false
	var run := 0
	for b: int in line:
		if in_string:
			if escaped:
				escaped = false
			elif b == 92:
				escaped = true
			elif b == 34:
				in_string = false
			continue
		if b == 34:
			in_string = true
		elif b == 46 or b == 101 or b == 69:
			return false
		elif b >= 48 and b <= 57:
			run += 1
			if run > 16:
				return false
			continue
		run = 0
	return true


## The header with its numbers as ints, or {} when a key is missing or has the wrong type.
static func _clean(raw: Dictionary) -> Dictionary:
	if raw.get("hexa") != "save":
		return {}
	var out := {}
	for key: String in ["format", "turn", "saved_unix", "play_seconds", "body_bytes", "body_size"]:
		var v: Variant = raw.get(key)
		if not (v is float or v is int):
			return {}
		var f := float(v)
		if is_nan(f) or is_inf(f) or f < 0.0 or f > MAX_EXACT or f != floorf(f):
			return {}
		out[key] = int(v)
	for key: String in ["build", "slot", "name", "map_id", "map_digest", "scenario_id", "scenario_digest", "tag",
			"country", "date", "digest", "body_sha256"]:
		if not (raw.get(key) is String):
			return {}
		out[key] = raw[key]
	out["hexa"] = "save"
	if int(out["body_size"]) < 1 or int(out["body_size"]) > BODY_MAX or int(out["body_bytes"]) > BODY_MAX:
		return {}
	return out


## {problem: String, header: Dictionary, body: Dictionary}: the first of `.sav` and `.bak` that reads whole. A problem
## is the words of the table in 4.10 ("Empty slot", "Cannot be read", "Made by a newer Hexa" ...).
static func read(slot: String, dir: String = DIR) -> Dictionary:
	if not is_slot(slot):
		return {"problem": "no slot '%s'" % slot, "header": {}, "body": {}}
	var sav := path_of(slot, dir)
	if not FileAccess.file_exists(sav) and not FileAccess.file_exists(sav + ".bak"):
		return {"problem": "Empty slot", "header": {}, "body": {}}
	var out := _read_file(sav)
	if str(out["problem"]).is_empty() or not FileAccess.file_exists(sav + ".bak"):
		return out
	var second := _read_file(sav + ".bak")
	return second if str(second["problem"]).is_empty() else out


static func _read_file(path: String) -> Dictionary:
	var out := {"problem": Snapshot.PROBLEM_UNREADABLE, "header": {}, "body": {}}
	var info := _header_of_file(path)
	if info["state"] == &"broken":
		return out
	out["header"] = info["header"]
	if info["state"] == &"newer":
		out["problem"] = Snapshot.PROBLEM_NEWER
		return out
	if info["state"] == &"older":
		out["problem"] = Snapshot.PROBLEM_OLDER
		return out
	var header := info["header"] as Dictionary
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	f.seek(int(info["offset"]))
	var packed := f.get_buffer(int(header["body_bytes"]))
	f.close()
	if packed.size() != int(header["body_bytes"]) or _sha(packed) != str(header["body_sha256"]):
		return out
	var plain := packed.decompress(int(header["body_size"]), FileAccess.COMPRESSION_ZSTD)
	if plain.size() != int(header["body_size"]):
		return out
	var body: Variant = bytes_to_var(plain)
	if not (body is Dictionary):
		return out
	out["body"] = _upgrade(body as Dictionary)
	out["problem"] = "" if not (out["body"] as Dictionary).is_empty() else Snapshot.PROBLEM_UNREADABLE
	return out


## Runs `_upgrade_<n>` steps in order, format n to n + 1 (D31). None yet: FORMAT is OLDEST_FORMAT.
static func _upgrade(body: Dictionary) -> Dictionary:
	return body


## Deletes every file of a slot; false when one could not be deleted.
static func remove(slot: String, dir: String = DIR) -> bool:
	if not is_slot(slot):
		return false
	var ok := true
	for ext: String in [".sav", ".sav.bak", ".sav.tmp", ".png", ".body.json"]:
		var path := dir.path_join(slot + ext)
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
			ok = false
	return ok


## The autosave slot to write next: the first empty of AUTO_SLOTS, else the one with the oldest `saved_unix`.
static func auto_slot(dir: String = DIR) -> String:
	var oldest := AUTO_SLOTS[0]
	var oldest_unix := -1
	for slot: String in AUTO_SLOTS:
		var info := read_header(slot, dir)
		if info["state"] == &"empty":
			return slot
		var stamp := int((info["header"] as Dictionary).get("saved_unix", 0))
		if oldest_unix < 0 or stamp < oldest_unix:
			oldest = slot
			oldest_unix = stamp
	return oldest
