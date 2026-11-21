## The body of a save (docs/architecture/m3-build-spec.md 4.10, 5.4): `of` turns a game into plain values that
## var_to_bytes keeps exactly (strings, ints, packed arrays, Vector2i), `restore` turns them back into a game and checks
## the type of every value first. Pure: no file is touched here (SaveFile writes and reads).
class_name Snapshot
extends RefCounted

const PROBLEM_UNREADABLE := "Cannot be read"
const PROBLEM_OTHER_MAP := "Made for another map"
const PROBLEM_OTHER_BUILD := "Made by another build"
const PROBLEM_NEWER := "Made by a newer Hexa"
const PROBLEM_OLDER := "Made by an older test build"
const MAX_TURN := 100000


## The body of 4.10: `ui` is the shell's block (bookmarks, camera, map mode, look), kept as given.
static func of(game: Game, ui: Dictionary = {}) -> Dictionary:
	var countries: Array = []
	for c: Country in game.countries:
		countries.append(c.to_dict())
	var log: Array = []
	for record: Dictionary in game.action_log:
		log.append(record.duplicate(true))
	var scenario_id := ""
	var scenario_digest := ""
	if game.scenario != null:
		scenario_id = game.scenario.id
		scenario_digest = game.scenario.digest()
	return {
		"format": SaveFile.FORMAT,
		"game": {
			"map_id": game.map.id, "scenario_id": scenario_id, "scenario_digest": scenario_digest,
			"seed": game.seed_value, "start_year": game.start_year, "turn": game.turn, "player": String(game.player),
			"weather": game.weather.duplicate(),
		},
		"map_state": game.state.to_dict(),
		"countries": countries,
		"stats": game.stats.to_dict() if game.stats != null else {},
		"chronicle": game.chronicle.to_dict(),
		"luck": game.luck.to_dict() if game.luck != null else {},
		"action_log": log,
		"ui": ui.duplicate(true),
	}


## {game: Game or null, ui: Dictionary, problem: String}: a game with the digest the body was made with, or null and the
## words of the problem. Every value is type-checked before use; nothing here can crash on a damaged body.
static func restore(body: Dictionary, map: MapData, defs: GameDefs) -> Dictionary:
	var out := {"game": null, "ui": {}, "problem": ""}
	if map == null or defs == null:
		out["problem"] = PROBLEM_UNREADABLE
		return out
	var problem := _format_problem(body)
	var meta: Variant = body.get("game")
	if problem.is_empty() and not _meta_ok(meta):
		problem = PROBLEM_UNREADABLE
	if problem.is_empty() and str((meta as Dictionary)["map_id"]) != map.id:
		problem = PROBLEM_OTHER_MAP
	var scenario: ScenarioDef = null
	if problem.is_empty():
		var found := _scenario_of(meta as Dictionary, defs)
		problem = str(found["problem"])
		scenario = found["scenario"] as ScenarioDef
	if not problem.is_empty():
		out["problem"] = problem
		return out
	var built := _build(body, meta as Dictionary, map, defs, scenario)
	if not built.has("game"):
		out["problem"] = PROBLEM_OTHER_MAP if str(built.get("problem", "")) == "map" else PROBLEM_UNREADABLE
		return out
	out["game"] = built["game"]
	out["ui"] = (body["ui"] as Dictionary).duplicate(true)
	return out


static func _format_problem(body: Dictionary) -> String:
	var format: Variant = body.get("format")
	if not (format is int):
		return PROBLEM_UNREADABLE
	if int(format) > SaveFile.FORMAT:
		return PROBLEM_NEWER
	if int(format) < SaveFile.OLDEST_FORMAT:
		return PROBLEM_OLDER
	for key: String in ["map_state", "chronicle", "luck", "stats", "ui"]:
		if not (body.get(key) is Dictionary):
			return PROBLEM_UNREADABLE
	if not (body.get("countries") is Array) or not (body.get("action_log") is Array):
		return PROBLEM_UNREADABLE
	return ""


static func _meta_ok(meta: Variant) -> bool:
	if not (meta is Dictionary):
		return false
	var d := meta as Dictionary
	for key: String in ["map_id", "scenario_id", "scenario_digest", "player"]:
		if not (d.get(key) is String):
			return false
	for key: String in ["seed", "start_year", "turn"]:
		if not (d.get(key) is int):
			return false
	if d.has("weather") and _weather_of(d["weather"]) == null:
		return false
	return int(d["turn"]) >= Calendar.FIRST_TURN and int(d["turn"]) <= MAX_TURN


## The weather (snow, frost, mild: 0 calm, 1 good, 2 poor) as three bytes, or null when it is not three whole numbers
## 0 to 2; a save without the key is calm (the caller's default).
static func _weather_of(raw: Variant) -> Variant:
	var out := PackedByteArray([0, 0, 0])
	if raw is PackedByteArray and (raw as PackedByteArray).size() == 3:
		out = (raw as PackedByteArray).duplicate()
	elif raw is Array and (raw as Array).size() == 3:
		for i: int in 3:
			var v: Variant = (raw as Array)[i]
			if not (v is int) and not (v is float and is_equal_approx(float(v), roundf(float(v)))):
				return null
			if int(v) < 0 or int(v) > 2:
				return null
			out[i] = int(v)
		return out
	else:
		return null
	for b: int in out:
		if b > 2:
			return null
	return out


## {scenario, problem}: the scenario named by the body, from the definitions; its digest must be the one saved.
static func _scenario_of(meta: Dictionary, defs: GameDefs) -> Dictionary:
	var id := str(meta["scenario_id"])
	if id.is_empty():
		return {"scenario": null, "problem": "" if str(meta["scenario_digest"]).is_empty() else PROBLEM_UNREADABLE}
	var scenario := defs.scenario(id)
	if scenario == null or scenario.digest() != str(meta["scenario_digest"]):
		return {"scenario": null, "problem": PROBLEM_OTHER_BUILD}
	return {"scenario": scenario, "problem": ""}


## {game} or {problem: "map" | "body"}: the pieces put back one by one (Game.with_state leaves stats, the log and the
## countries to us).
static func _build(body: Dictionary, meta: Dictionary, map: MapData, defs: GameDefs, scenario: ScenarioDef) -> Dictionary:
	var state_dict := body["map_state"] as Dictionary
	var state_problem := _state_problem(state_dict, map)
	if not state_problem.is_empty():
		return {"problem": state_problem}
	var state := MapState.from_dict(state_dict, map)
	if state == null:
		return {"problem": "body"}
	var chronicle := Chronicle.from_dict(body["chronicle"] as Dictionary)
	var countries: Variant = _countries_of(body["countries"] as Array, scenario)
	var log: Variant = _log_of(body["action_log"] as Array)
	var luck: Variant = _luck_of(body["luck"] as Dictionary, int(meta["seed"]))
	var stats_dict := body["stats"] as Dictionary
	var stats: Stats = null
	if not stats_dict.is_empty():
		stats = Stats.from_dict(stats_dict)
		if stats == null:
			return {"problem": "body"}
	var player := StringName(str(meta["player"]))
	if chronicle == null or countries == null or log == null or luck == null:
		return {"problem": "body"}
	if scenario == null and player != &"":
		return {"problem": "body"}
	if player != &"" and not _has_tag(countries as Array, player):
		return {"problem": "body"}
	if not _ranges_ok(state, map, (countries as Array).size()):
		return {"problem": "body"}
	var game := Game.with_state(map, state, int(meta["seed"]), defs)
	game.scenario = scenario
	game.player = player
	game.start_year = int(meta["start_year"])
	game.turn = int(meta["turn"])
	if (meta as Dictionary).has("weather"):
		game.weather = _weather_of(meta["weather"]) as PackedByteArray
	game.chronicle = chronicle
	game.luck = luck as Luck
	game.stats = stats
	game.countries.assign(countries as Array)
	game.action_log.assign(log as Array)
	return {"game": game}


## "" when the three byte arrays are base64 text of the map's size, "map" when they decode to another size, "body" when
## a value is not text or not base64, or a people array (map-state/4) is not a packed int array of the map's size. Checked before MapState.from_dict decodes, which would print an engine error.
static func _state_problem(d: Dictionary, map: MapData) -> String:
	var n := map.hex_count()
	var other_size := false
	for key: String in ["main_use", "level", "owner"]:
		var text: Variant = d.get(key)
		if not (text is String) or not _base64_ok(text as String):
			return "body"
		if Marshalls.base64_to_raw(text as String).size() != n:
			other_size = true
	if d.has("size") and not (d["size"] is int):
		return "body"
	if other_size:
		return "map"
	if str(d.get("schema", "")) == MapState.SCHEMA:
		for key: String in ["people", "people_start", "people_end"]:
			var ints: Variant = d.get(key)
			if not (ints is PackedInt32Array) or (ints as PackedInt32Array).size() != n:
				return "body"
	return ""


## True for padded base64: a multiple of 4 characters, the alphabet, "=" only as the last one or two.
static func _base64_ok(text: String) -> bool:
	var bytes := text.to_ascii_buffer()
	if bytes.size() != text.length() or bytes.size() % 4 != 0:
		return false
	var pad := 0
	for i: int in bytes.size():
		var b := bytes[i]
		if b == 61:
			if i < bytes.size() - 2:
				return false
			pad += 1
		elif pad > 0:
			return false
		elif not ((b >= 65 and b <= 90) or (b >= 97 and b <= 122) or (b >= 48 and b <= 57) or b == 43 or b == 47):
			return false
	return true


## Every use is a family, every level within the family's top, every owner a country, and the sea holds none.
static func _ranges_ok(state: MapState, map: MapData, country_count: int) -> bool:
	for i: int in map.hex_count():
		var use := int(state.main_use[i])
		var lv := int(state.level[i])
		var owner_id := int(state.owner[i])
		if use >= FamilyIds.COUNT or lv > FamilyIds.TOP_LEVEL[use] or owner_id > country_count:
			return false
		if map.land[i] == 0 and (use != 0 or lv != 0 or owner_id != 0):
			return false
		if not _people_ok(state, map, i):
			return false
	return true


## A4: every people value of hex `i` in 0..PEOPLE_MAX, and none at sea.
static func _people_ok(state: MapState, map: MapData, i: int) -> bool:
	for ints: PackedInt32Array in [state.people, state.people_start, state.people_end]:
		var v := ints[i]
		if v < 0 or v > People.PEOPLE_MAX or (v != 0 and map.land[i] == 0):
			return false
	return true


static func _has_tag(countries: Array, tag: StringName) -> bool:
	for c: Country in countries:
		if c.tag == tag:
			return true
	return false


## The countries in id order, or null: a scenario game needs exactly the scenario's tags with ids 1, 2, 3 ...; a
## map-only game has none.
static func _countries_of(raw: Array, scenario: ScenarioDef) -> Variant:
	var out: Array = []
	var want := scenario.countries.size() if scenario != null else 0
	if raw.size() != want:
		return null
	for i: int in raw.size():
		if not (raw[i] is Dictionary):
			return null
		if not _country_typed(raw[i] as Dictionary):
			return null
		var c := Country.from_dict(raw[i] as Dictionary)
		if c == null or c.id != i + 1 or c.tag != scenario.countries[i]:
			return null
		out.append(c)
	return out


## The types Country.from_dict reads without checking: id int, tag text, capital two ints, alive bool. The M4 fields
## (treasury, tax, ledgers, stock, flows ...) are checked by Country.from_dict itself, which refuses a bad one and
## country/1 (its schema) with null; of the M5 fields (country/3) the whole numbers and the packed flows are checked here.
static func _country_typed(d: Dictionary) -> bool:
	if not (d.get("id") is int) or not (d.get("tag") is String) or not (d.get("alive") is bool):
		return false
	if str(d.get("schema", "")) == Country.SCHEMA and not _people_fields_typed(d):
		return false
	var cap: Variant = d.get("capital")
	return cap is Array and (cap as Array).size() == 2 and (cap as Array)[0] is int and (cap as Array)[1] is int


static func _people_fields_typed(d: Dictionary) -> bool:
	if not (d.get("food_need") is int) or not (d.get("food_fed") is int) or not (d.get("people_flows") is PackedInt32Array):
		return false
	var closed: Variant = d.get("people_closed")
	return closed is Dictionary and ((closed as Dictionary).is_empty() or (closed as Dictionary).get("flows") is PackedInt32Array)


## The action log records, or null when one is not {turn: int, action: String, args: Dictionary}.
static func _log_of(raw: Array) -> Variant:
	var out: Array = []
	for item: Variant in raw:
		if not (item is Dictionary):
			return null
		var record := item as Dictionary
		if not (record.get("turn") is int) or not (record.get("action") is String) or not (record.get("args") is Dictionary):
			return null
		out.append(record)
	return out


static func _luck_of(d: Dictionary, seed_value: int) -> Variant:
	if str(d.get("schema", "")) != Luck.SCHEMA:
		return null
	for key: String in ["world", "ai", "decor"]:
		if not (d.get(key) is int):
			return null
	return Luck.from_dict(d, seed_value)
