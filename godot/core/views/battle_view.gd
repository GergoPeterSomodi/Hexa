## The read-only battle view (docs/architecture/m7-build-spec.md 4.6, 4.15, 5.6, M7 B14): one battle as a viewer may see it, from
## its kept BattleRecord, day by day. `of` is the dock's model; `sites` the battle badges of the last season; `latest_of` the
## newest battle a country fought in; `log_line` the day's sentence. Fog (Knowledge.battle_access): exact for the viewer ""
## and for a side (both sides' numbers, the stances); seen when the viewer witnessed the battle (exact men, killed, wounded
## and morale, R22; no stances, no unit or army ids; the reserve and the routed as one entry each); hidden otherwise, and then
## nothing at all. A battle no longer kept gives the
## totals of its chronicle entry. Pure core/views/ code: a function of the game and the viewer; no nodes, no engine calls.
@warning_ignore_start("integer_division")
class_name BattleView
extends RefCounted

const SIDE_ATTACKER := 0
const SIDE_DEFENDER := 1
const SIDE_WORDS: Array[String] = ["attacker", "defender"]
const LANES := 3
const CENTRE := 1
const NARROW_CLOSED_LANE := 2
const GARRISON := -1
const EMPTY := -2
const TONE_GOOD := &"good"
const TONE_BAD := &"bad"
const TONE_PLAIN := &"plain"
const NO_NOTE := ""
const UNKNOWN_NAME := "a country"
const GONE_NOTE := "The day-by-day account of this battle is no longer kept."
const STANCE_WORDS := {"attack": "Attack", "hold": "Hold", "withdraw": "Withdraw"}


## The battle a viewer may see, as the dock reads it; {} when the record is hidden or unknown. `day` is the battle's day
## number (1 to its days); -1 (or a day that is not in the record) shows the last day. Cached in the view cache by
## [&"battle_view", version, viewer, record_id, day].
static func of(game: Game, viewer: StringName, record_id: int, day: int = -1) -> Dictionary:
	if game == null or game.map == null or record_id < 0:
		return {}
	var key: Array = [&"battle_view", game.version, viewer, record_id, day]
	return game.view_cache.get_or_make(key, func() -> Dictionary: return _make_of(game, viewer, record_id, day)) as Dictionary


## What a viewer may see of a record (Knowledge.battle_access).
static func access(game: Game, viewer: StringName, record: BattleRecord) -> StringName:
	return Knowledge.battle_access(game, viewer, record)


## The battle badges: the records of the turn before this one that the viewer may see, in record id order. Each is
## {record (id), hex, name, tone (good, bad or plain for the viewer's side), front (PackedInt32Array [attacker, defender]
## morale, the last day's), attacker_colour_id, defender_colour_id}. Cached by [&"sites", version, viewer].
static func sites(game: Game, viewer: StringName) -> Array[Dictionary]:
	var key: Array = [&"sites", game.version, viewer]
	return game.view_cache.get_or_make(key, func() -> Array[Dictionary]: return _make_sites(game, viewer)) as Array[Dictionary]


## The id of the newest kept record `tag` fought in (as attacker or defender); -1 when there is none.
static func latest_of(game: Game, tag: StringName) -> int:
	var found := Battles.records_of(game, tag)
	return found[0].id if not found.is_empty() else -1


## The sentence of one day (v0.2.2's battlelog.describe): "Day 2: Savoy 48 killed, 46 wounded; Milan 61 killed, 59 wounded.
## Milan broke (centre)." `names` maps each tag to the country's name. The numbers are exact.
static func log_line(record: BattleRecord, frame: Dictionary, names: Dictionary) -> String:
	return _line(record, frame, names)


# --- the view of a kept record -----------------------------------------------------------------------------------------


static func _make_of(game: Game, viewer: StringName, record_id: int, day: int) -> Dictionary:
	var r := Battles.record(game, record_id)
	if r == null:
		return _gone(game, viewer, record_id)
	if not _well_formed(r):
		return {}
	var acc := access(game, viewer, r)
	if acc == &"hidden" or r.frames.is_empty():
		return {}
	var seen := acc == &"seen"
	var idx := _index_of_day(r, day)
	var frame: Dictionary = r.frames[idx]
	var names := _names_of(game, viewer, r.attacker, r.defender)
	var refs := _refs(game, viewer, r.attacker, r.defender)
	var viewer_side := _viewer_side(r, viewer)
	var sides := {}
	sides[refs.attacker] = _side(game, r, SIDE_ATTACKER, idx, seen, viewer_side, _name_of(names, r.attacker), refs.named_attacker)
	sides[refs.defender] = _side(game, r, SIDE_DEFENDER, idx, seen, viewer_side, _name_of(names, r.defender), refs.named_defender)
	return {
		"access": acc, "kept": true, "id": r.id, "name": r.name, "year": r.year, "hex": r.hex,
		"place": Words.place(game, r.hex), "days": _int(r.end.get("days", 0)), "day": _int(frame["day"]), "index": idx,
		"sides": {"attacker": [refs.attacker], "defender": [refs.defender]},
		"viewer_side": viewer_side, "ground": _ground(game, r, refs.defender),
		"side": sides, "log": _log(r, idx, names, viewer_side),
		"result": _winner_ref(_result(names, r.attacker, r.defender, r.end, viewer_side), r.attacker, r.defender, refs),
		"note": NO_NOTE,
	}


## A battle no longer kept: the totals and the result of its chronicle entry, for a viewer the entry is told to.
static func _gone(game: Game, viewer: StringName, record_id: int) -> Dictionary:
	var entry := _chronicle_entry(game, record_id)
	if entry.is_empty() or not Knowledge.witnessed(game, entry, viewer):
		return {}
	var attacker := StringName(str(entry.get("attacker", entry.get("tag", ""))))
	var defender := StringName(str(entry.get("defender", "")))
	var own := _viewer_side_of(attacker, defender, viewer)
	var acc := &"exact" if viewer == &"" or own != &"" else &"seen"
	var names := _names_of(game, viewer, attacker, defender)
	var refs := _refs(game, viewer, attacker, defender)
	var hex := _hex_of(entry)
	var winner_tag := StringName(str(entry.get("winner", "")))
	var winner := SIDE_ATTACKER if winner_tag == attacker and winner_tag != &"" else (SIDE_DEFENDER if winner_tag == defender and winner_tag != &"" else -1)
	var killed := _pair_text(entry.get("killed", {}), attacker, defender, refs)
	var wounded := _pair_text(entry.get("wounded", {}), attacker, defender, refs)
	var result := _winner_ref(_result_text(names, attacker, defender, winner, str(entry.get("how", "")),
		str(entry.get("cause", "")), _int(entry.get("days", 0)), Army.NO_HEX, own), attacker, defender, refs)
	return {
		"access": acc, "kept": false, "id": record_id, "name": str(entry.get("name", "")),
		"year": _int(entry.get("year", 0)), "hex": hex, "place": Words.place(game, hex),
		"days": _int(entry.get("days", 0)), "day": 0, "index": -1,
		"sides": {"attacker": [refs.attacker], "defender": [refs.defender]},
		"viewer_side": own, "ground": {}, "side": {},
		"totals": {"killed": killed, "wounded": wounded}, "log": [], "result": result, "note": GONE_NOTE,
	}


static func _chronicle_entry(game: Game, record_id: int) -> Dictionary:
	if record_id < 0:
		return {}
	for e: Dictionary in game.chronicle.entries:
		if str(e.get("kind", "")) == "battle_ended" and _int(e.get("record", -1)) == record_id:
			return e
	return {}


static func _pair_text(value: Variant, attacker: StringName, defender: StringName, refs: Dictionary) -> Dictionary:
	var out := {}
	if value is Dictionary:
		var n_a := _int((value as Dictionary).get(String(attacker), 0))
		var n_d := _int((value as Dictionary).get(String(defender), 0))
		out[refs.attacker] = n_a
		out[refs.defender] = n_d
	return out


static func _make_sites(game: Game, viewer: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: BattleRecord in game.battle_records:
		if r.turn != game.turn - 1 or not _well_formed(r):
			continue
		var acc := access(game, viewer, r)
		if acc == &"hidden" or r.frames.is_empty():
			continue
		var front: PackedInt32Array = (r.frames[r.frames.size() - 1]["front"] as PackedInt32Array)
		var shown := PackedInt32Array([front[0], front[1]])
		out.append({
			"record": r.id, "hex": r.hex, "name": r.name, "tone": _tone(_viewer_side(r, viewer), _int(r.end.get("winner", -1))),
			"front": shown, "attacker_colour_id": _colour(game, viewer, r, r.attacker), "defender_colour_id": _colour(game, viewer, r, r.defender),
		})
	return out


# --- sides ----------------------------------------------------------------------------------------------------------


static func _side(game: Game, r: BattleRecord, side: int, idx: int, seen: bool, viewer_side: StringName, shown: String, named: bool) -> Dictionary:
	var tag := r.attacker if side == SIDE_ATTACKER else r.defender
	var tag_text := String(tag) if named else ""
	var frame: Dictionary = r.frames[idx]
	var keys := _side_keys(r, side)
	var men_now := 0
	for key: int in keys:
		men_now += _int((frame["men"] as Dictionary).get(key, 0))
	var start := _start_men(r, side)
	var roll := _int((frame["rolls"] as PackedInt32Array)[side])
	var mult := _mult_of(game, roll)
	var front := _int((frame["front"] as PackedInt32Array)[side])
	var killed := _int((r.end["killed"] as PackedInt32Array)[side])
	var wounded := _int((r.end["wounded_total"] as PackedInt32Array)[side])
	var stance := ""
	if not seen:
		stance = _stance_text(r, side)
	var role := "Attacker" if side == SIDE_ATTACKER else "Defender"
	if viewer_side == SIDE_WORDS[side]:
		role += " · you"
	return {
		"name": shown, "tag": tag_text, "arms": tag_text,
		"role_text": role, "general_text": "No general",
		"men": men_now, "start": start, "killed": killed,
		"wounded": wounded, "roll": roll, "mult_text": "×%.1f" % (mult / 1000.0),
		"mult_tone": _mult_tone(mult), "front": front,
		"stance_text": stance, "lanes": _lanes(game, r, side, idx, seen), "reserve": _reserve(game, r, side, idx, seen),
		"routed": _routed(game, r, side, idx, seen),
	}


## The keys of a side's companies in the record's input (the garrison with the defender's centre).
static func _side_keys(r: BattleRecord, side: int) -> Array[int]:
	var out: Array[int] = []
	for f: Dictionary in _fighters(r):
		if _int(f.get("side", -1)) == side:
			out.append(_int(f.get("key", 0)))
	if side == SIDE_DEFENDER and not _garrison(r).is_empty():
		out.append(GARRISON)
	return out


static func _start_men(r: BattleRecord, side: int) -> int:
	var total := 0
	for f: Dictionary in _fighters(r):
		if _int(f.get("side", -1)) == side:
			total += _int(f.get("men", 0))
	if side == SIDE_DEFENDER:
		total += _int(_garrison(r).get("men", 0))
	return total


static func _stance_text(r: BattleRecord, side: int) -> String:
	var raw: Variant = r.input.get("stance", {})
	var stance: Dictionary = {}
	if raw is Dictionary:
		stance = raw
	var word := str(stance.get("att" if side == SIDE_ATTACKER else "def", "hold"))
	return "Fought on: %s" % STANCE_WORDS.get(word, word)


## The three lanes of a side at a day: a company (kind, name, figure, men, full, morale, routed, shaken, fires), or an empty,
## closed (the right lane on narrow ground) or broken lane (it held a company before and stands empty today). A fogged view
## carries no key; its men and morale are exact (R22).
static func _lanes(game: Game, r: BattleRecord, side: int, idx: int, seen: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lanes: Array = (r.frames[idx]["lanes"] as Array)
	var narrow := _flag(_ground_of(r).get("narrow", false))
	var line: PackedInt32Array = lanes[side]
	for i: int in LANES:
		var key := _int(line[i])
		var closed := narrow and i == NARROW_CLOSED_LANE
		if key == EMPTY or key < -1:
			out.append(_empty_lane(closed, not closed and _held_before(r, side, i, idx)))
		else:
			out.append(_company(game, r, key, idx, seen, closed))
	return out


static func _empty_lane(closed: bool, broken: bool) -> Dictionary:
	return {"empty": true, "closed": closed, "broken": broken, "kind": -1, "name": "", "figure": &"", "men": 0,
		"full": 0, "morale": 0, "routed": false, "shaken": false, "fires": false}


static func _held_before(r: BattleRecord, side: int, lane: int, idx: int) -> bool:
	for j: int in idx:
		var line: PackedInt32Array = (r.frames[j]["lanes"] as Array)[side]
		if _int(line[lane]) != EMPTY and _int(line[lane]) >= -1:
			return true
	return false


## One company's entry at a day. The key (its unit id) is given to the exact view only.
static func _company(game: Game, r: BattleRecord, key: int, idx: int, seen: bool, closed: bool) -> Dictionary:
	var frame: Dictionary = r.frames[idx]
	var ud := _unit_of(game, r, key)
	var routed := (frame["routed"] as PackedInt32Array).has(key)
	var entry := {
		"empty": false, "closed": closed, "broken": false,
		"kind": ud.id if ud != null else -1,
		"name": ud.name if ud != null else "the garrison",
		"figure": ud.figure if ud != null else &"",
		"men": _int((frame["men"] as Dictionary).get(key, 0)),
		"full": _fighter_full(r, key),
		"morale": _int((frame["morale"] as Dictionary).get(key, 0)),
		"routed": routed, "shaken": (frame["shaken"] as PackedInt32Array).has(key),
		"fires": not routed,
	}
	if not seen:
		entry["key"] = key
	return entry


static func _reserve(game: Game, r: BattleRecord, side: int, idx: int, seen: bool) -> Array[Dictionary]:
	var frame: Dictionary = r.frames[idx]
	var in_lane := {}
	for line: Variant in frame["lanes"] as Array:
		for k: int in line as PackedInt32Array:
			in_lane[k] = true
	var out: Array[Dictionary] = []
	for key: int in _side_keys(r, side):
		if key == GARRISON or in_lane.has(key) or (frame["routed"] as PackedInt32Array).has(key):
			continue
		if _int((frame["men"] as Dictionary).get(key, 0)) <= 0:
			continue
		out.append(_company(game, r, key, idx, false, false))
	return _aggregate(out, true) if seen else out


## A witness's view of a group of companies (the reserve, the routed): one entry for the whole group, the figure of its most
## numerous kind, the exact men total and the morale weighted by men; no per-company entries and no ids (4.15, the foreign-army
## rule). An
## exact view keeps its entries (the caller does not aggregate). `fires` is the entry's fires flag.
static func _aggregate(entries: Array[Dictionary], fires: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if entries.is_empty():
		return out
	var total := 0
	var weighted := 0
	var kind_men := {}
	var sample := {}
	for e: Dictionary in entries:
		var m := _int(e["men"])
		total += m
		weighted += m * _int(e["morale"])
		var k := _int(e["kind"])
		kind_men[k] = _int(kind_men.get(k, 0)) + m
		if not sample.has(k):
			sample[k] = e
	var best := -1
	var best_men := -1
	var kinds: Array = kind_men.keys()
	kinds.sort()
	for k: Variant in kinds:
		if _int(kind_men[k]) > best_men:
			best_men = _int(kind_men[k])
			best = _int(k)
	var morale := weighted / total if total > 0 else 0
	var lead: Dictionary = sample[best]
	out.append({"empty": false, "closed": false, "broken": false, "kind": best, "name": lead["name"],
		"figure": lead["figure"], "men": total, "full": 0, "morale": morale, "routed": false,
		"shaken": false, "fires": fires})
	return out


static func _routed(game: Game, r: BattleRecord, side: int, idx: int, seen: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key: int in (r.frames[idx]["routed"] as PackedInt32Array):
		if _side_keys(r, side).has(key):
			out.append(_company(game, r, key, idx, false, false))
	return _aggregate(out, false) if seen else out


# --- the battle's ground, log and result ---------------------------------------------------------------------------


static func _ground(game: Game, r: BattleRecord, helps: String) -> Dictionary:
	var g := _ground_of(r)
	var i := game.map.index_of(r.hex)
	var terrain_name := "Open ground"
	if i >= 0:
		var td := game.defs.terrain(_int(game.map.cover[i]))
		if td != null and not td.name.is_empty():
			terrain_name = td.name
	var narrow := _flag(g.get("narrow", false))
	var lanes_open := LANES - 1 if narrow else LANES
	var chips: Array[Dictionary] = []
	var defender := helps
	if _flag(r.input.get("crossing", false)):
		chips.append({"text": "Pass crossing", "icon": &"pass", "helps": defender})
	if _flag(r.input.get("river", false)):
		chips.append({"text": "River crossing", "icon": &"river", "helps": defender})
	if _flag(r.input.get("uphill", false)):
		chips.append({"text": "Uphill", "icon": &"hill", "helps": defender})
	var defence := _int(g.get("defence", 0))
	if defence > 0:
		chips.append({"text": "Cover: defence +%d %%" % (defence / 10), "icon": &"shield", "helps": defender})
	if _flag(r.input.get("assault", false)):
		chips.append({"text": "Assault on a fortress", "icon": &"walls", "helps": defender})
	var text := "%s · %d lanes" % [terrain_name, lanes_open]
	return {"text": text, "lanes_open": lanes_open, "chips": chips}


static func _log(r: BattleRecord, idx: int, names: Dictionary, viewer_side: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for j: int in range(0, idx + 1):
		var frame: Dictionary = r.frames[j]
		out.append({"day": _int(frame["day"]), "text": _line(r, frame, names),
			"tone": _tone_of_day(frame, viewer_side)})
	return out


static func _tone_of_day(frame: Dictionary, viewer_side: StringName) -> StringName:
	var broke := _int(frame["broke"])
	if broke < 0 or viewer_side == &"":
		return TONE_PLAIN
	return TONE_BAD if SIDE_WORDS[broke] == viewer_side else TONE_GOOD


static func _line(r: BattleRecord, frame: Dictionary, names: Dictionary) -> String:
	var killed: PackedInt32Array = frame["killed"]
	var wounded: PackedInt32Array = frame["wounded"]
	var a := Words.number(killed[0])
	var b := Words.number(wounded[0])
	var c := Words.number(killed[1])
	var d := Words.number(wounded[1])
	var text := "Day %d: %s %s killed, %s wounded; %s %s killed, %s wounded." % [_int(frame["day"]),
		_name_of(names, r.attacker), a, b, _name_of(names, r.defender), c, d]
	var broke := _int(frame["broke"])
	if broke >= 0:
		var loser := r.attacker if broke == SIDE_ATTACKER else r.defender
		var cause := str(frame["cause"])
		var who := _sentence(_name_of(names, loser))
		text += " %s broke (%s)." % [who, cause] if cause != "" else " %s broke." % who
	var withdrew := _int(frame["withdrew"])
	if withdrew > 0:
		var who := r.attacker if withdrew - 1 == SIDE_ATTACKER else r.defender
		text += " %s withdrew." % _sentence(_name_of(names, who))
	return text


static func _result(names: Dictionary, attacker: StringName, defender: StringName, end: Dictionary, viewer_side: StringName) -> Dictionary:
	var retreat: Vector2i = Army.NO_HEX
	var raw_spots: Variant = end.get("retreat", {})
	var spots: Dictionary = {}
	if raw_spots is Dictionary:
		spots = raw_spots
	var keys: Array = spots.keys()
	keys.sort()
	if not keys.is_empty() and typeof(spots[keys[0]]) == TYPE_VECTOR2I:
		retreat = spots[keys[0]]
	return _result_text(names, attacker, defender, _int(end.get("winner", -1)), str(end.get("how", "")),
		str(end.get("cause", "")), _int(end.get("days", 0)), retreat, viewer_side)


static func _result_text(names: Dictionary, attacker: StringName, defender: StringName, winner: int, how: String,
		cause: String, days: int, retreat: Vector2i, viewer_side: StringName) -> Dictionary:
	if winner < 0:
		return {"text": "The battle ended in a draw after %s." % Words.plural(days, "day", "days"), "tone": TONE_PLAIN,
			"winner": "", "how": how}
	var win_tag := attacker if winner == SIDE_ATTACKER else defender
	var lose_tag := defender if winner == SIDE_ATTACKER else attacker
	var loser := _name_of(names, lose_tag)
	var tail := ""
	match how:
		"broke":
			tail = "%s broke%s" % [loser, (" (%s)" % cause) if cause != "" else ""]
			if retreat != Army.NO_HEX:
				tail += " and fled to %s" % _coords(retreat)
		"withdrew":
			tail = "%s withdrew" % loser
			if retreat != Army.NO_HEX:
				tail += " to %s" % _coords(retreat)
		"surrendered":
			tail = "%s surrendered" % loser
		"destroyed":
			tail = "%s was destroyed" % loser
		_:
			tail = "%s left the field" % loser
	var text := "%s won in %s: %s." % [_sentence(_name_of(names, win_tag)), Words.plural(days, "day", "days"), tail]
	return {"text": text, "tone": _tone(viewer_side, winner), "winner": String(win_tag), "how": how}


# --- helpers ------------------------------------------------------------------------------------------------------


static func _index_of_day(r: BattleRecord, day: int) -> int:
	if day >= 0:
		for j: int in r.frames.size():
			if _int(r.frames[j]["day"]) == day:
				return j
	return r.frames.size() - 1


static func _viewer_side(r: BattleRecord, viewer: StringName) -> StringName:
	return _viewer_side_of(r.attacker, r.defender, viewer)


static func _viewer_side_of(attacker: StringName, defender: StringName, viewer: StringName) -> StringName:
	if viewer != &"" and viewer == attacker:
		return &"attacker"
	if viewer != &"" and viewer == defender:
		return &"defender"
	return &""


## A tone for the viewer's side from the winner side (0 attacker, 1 defender, -1 a draw).
static func _tone(viewer_side: StringName, winner: int) -> StringName:
	if viewer_side == &"" or winner < 0:
		return TONE_PLAIN
	return TONE_GOOD if SIDE_WORDS[winner] == viewer_side else TONE_BAD


static func _mult_tone(mult: int) -> StringName:
	if mult > 1000:
		return TONE_GOOD
	if mult < 1000:
		return TONE_BAD
	return TONE_PLAIN


static func _mult_of(game: Game, roll: int) -> int:
	var dice: PackedInt32Array = game.defs.war.dice_permille
	if roll < 1 or roll > dice.size():
		return 1000
	return dice[roll - 1]


static func _fighters(r: BattleRecord) -> Array:
	var out: Array = []
	var raw: Variant = r.input.get("fighters", [])
	if not (raw is Array):
		return out
	for item: Variant in raw as Array:
		if item is Dictionary:
			out.append(item)
	return out


static func _garrison(r: BattleRecord) -> Dictionary:
	var g: Variant = r.input.get("garrison", {})
	return g as Dictionary if g is Dictionary else {}


static func _ground_of(r: BattleRecord) -> Dictionary:
	var g: Variant = r.input.get("ground", {})
	return g as Dictionary if g is Dictionary else {}


static func _fighter_full(r: BattleRecord, key: int) -> int:
	for f: Dictionary in _fighters(r):
		if _int(f.get("key", -9)) == key:
			return _int(f.get("full", 0))
	return _int(_garrison(r).get("full", 0)) if key == GARRISON else 0


## The unit def of a company: the fighter's `kind` (a UnitDef id, the record's input since B8) when it has one; else matched by
## its branch and its stats as the input gives them (records kept before B8); null for the garrison.
static func _unit_of(game: Game, r: BattleRecord, key: int) -> UnitDef:
	if key == GARRISON:
		return null
	for f: Dictionary in _fighters(r):
		if _int(f.get("key", -9)) != key:
			continue
		var kind: Variant = f.get("kind", -1)
		if typeof(kind) == TYPE_INT and _int(kind) >= 0 and game.defs.unit_def(_int(kind)) != null:
			return game.defs.unit_def(_int(kind))
		var branch := str(f.get("branch", ""))
		var fallback: UnitDef = null
		for ud: UnitDef in game.defs.units:
			if String(ud.branch) != branch:
				continue
			if fallback == null:
				fallback = ud
			if ud.men == _int(f.get("full", -1)) and ud.attack == _int(f.get("attack", -1)) \
					and ud.defence == _int(f.get("defence", -1)) and ud.fire_permille == _int(f.get("fire", -1)):
				return ud
		return fallback
	return null


## The names of the two sides as the viewer may read them: the real name for the viewer "", for a side (both sides), and for a
## country the viewer knows (Knowledge.knows); UNKNOWN_NAME for any other (the log's rule, 4.15).
static func _names_of(game: Game, viewer: StringName, attacker: StringName, defender: StringName) -> Dictionary:
	var out := {}
	for tag: StringName in [attacker, defender]:
		var real := _named(game, viewer, attacker, defender, tag)
		out[String(tag)] = _country_name(game, tag) if real else UNKNOWN_NAME
	return out


## Whether the viewer may read a side's country (its name, its tag and its arms): the viewer "", a side, the country itself,
## or a country the viewer knows (Knowledge.knows). Any other country is shown as a role only (4.15).
static func _named(game: Game, viewer: StringName, attacker: StringName, defender: StringName, tag: StringName) -> bool:
	return viewer == &"" or viewer == attacker or viewer == defender or tag == viewer or Knowledge.knows(game, viewer, tag)


## The key a side goes by in the view: its tag when the viewer may read it, else its role word.
static func _ref(named: bool, tag: StringName, role: String) -> String:
	return String(tag) if named else role


## The keys of both sides for a viewer: attacker and defender (the keys), named_attacker and named_defender (flags).
static func _refs(game: Game, viewer: StringName, attacker: StringName, defender: StringName) -> Dictionary:
	var na := _named(game, viewer, attacker, defender, attacker)
	var nd := _named(game, viewer, attacker, defender, defender)
	return {"attacker": _ref(na, attacker, "attacker"), "defender": _ref(nd, defender, "defender"),
		"named_attacker": na, "named_defender": nd}


## The winner as the view gives it: the winner's key (its tag when named, its role otherwise), "" for none.
static func _winner_ref(result: Dictionary, attacker: StringName, defender: StringName, refs: Dictionary) -> Dictionary:
	var w := str(result.get("winner", ""))
	if w == String(attacker):
		result["winner"] = refs.attacker
	elif w == String(defender):
		result["winner"] = refs.defender
	return result


static func _colour(game: Game, viewer: StringName, r: BattleRecord, tag: StringName) -> int:
	return _id_of(game, tag) if _named(game, viewer, r.attacker, r.defender, tag) else -1


## A name at the start of a sentence: its first letter capitalised ("a country" reads "A country").
static func _sentence(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)


static func _hex_of(entry: Dictionary) -> Vector2i:
	var raw: Variant = entry.get("hex", Army.NO_HEX)
	return raw if typeof(raw) == TYPE_VECTOR2I else Army.NO_HEX


static func _name_of(names: Dictionary, tag: StringName) -> String:
	return str(names.get(String(tag), String(tag)))


## A country's long name (CountryDef.long_name), else its name, else its tag.
static func _country_name(game: Game, tag: StringName) -> String:
	var cdef := Countries.def_of(game, tag)
	if cdef != null:
		if not cdef.long_name.is_empty():
			return cdef.long_name
		if not cdef.name.is_empty():
			return cdef.name
	return String(tag)


static func _id_of(game: Game, tag: StringName) -> int:
	var c := Countries.by_tag(game, tag)
	return c.id if c != null else 0


static func _coords(hex: Vector2i) -> String:
	return "(%d, %d)" % [hex.x, hex.y]


## A whole number from a value of any type: ints as they are, floats rounded down, numeric text read; anything else 0.
static func _int(value: Variant) -> int:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return floori(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return str(value).to_int()
	return 0


## A flag from a value of any type: true only for a bool true.
static func _flag(value: Variant) -> bool:
	return typeof(value) == TYPE_BOOL and value


static func _is_text(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME


static func _ints_of(value: Variant, size: int) -> bool:
	return typeof(value) == TYPE_PACKED_INT32_ARRAY and (value as PackedInt32Array).size() == size


## True when the record has the shape the view reads: a day list of full frames (every key, the sizes of the sides' pairs
## and of the lanes), an end with its counts and words, and an input dictionary. A record from outside the game that does
## not have this shape gives nothing, so no view reads a missing field or one of the wrong kind.
static func _well_formed(r: BattleRecord) -> bool:
	if r.frames.is_empty() or typeof(r.input) != TYPE_DICTIONARY or typeof(r.end) != TYPE_DICTIONARY:
		return false
	var e: Dictionary = r.end
	if typeof(e.get("days")) != TYPE_INT or typeof(e.get("winner")) != TYPE_INT:
		return false
	if not (_ints_of(e.get("killed"), 2) and _ints_of(e.get("wounded_total"), 2)):
		return false
	if not (_is_text(e.get("how")) and _is_text(e.get("cause")) and _is_text(e.get("loser"))):
		return false
	if typeof(e.get("retreat")) != TYPE_DICTIONARY:
		return false
	for f: Variant in r.frames:
		if typeof(f) != TYPE_DICTIONARY or not _frame_ok(f as Dictionary):
			return false
	return true


static func _frame_ok(f: Dictionary) -> bool:
	for key: String in BattleRecord.FRAME_KEYS:
		if not f.has(key):
			return false
	if typeof(f["day"]) != TYPE_INT or typeof(f["broke"]) != TYPE_INT or typeof(f["withdrew"]) != TYPE_INT:
		return false
	if not _is_text(f["cause"]) or typeof(f["men"]) != TYPE_DICTIONARY or typeof(f["morale"]) != TYPE_DICTIONARY:
		return false
	if not (_ints_of(f["rolls"], 2) and _ints_of(f["killed"], 2) and _ints_of(f["wounded"], 2) and _ints_of(f["front"], 2)):
		return false
	if typeof(f["routed"]) != TYPE_PACKED_INT32_ARRAY or typeof(f["shaken"]) != TYPE_PACKED_INT32_ARRAY:
		return false
	var lanes: Variant = f["lanes"]
	if not (lanes is Array) or (lanes as Array).size() != 2:
		return false
	for line: Variant in lanes as Array:
		if not _ints_of(line, LANES):
			return false
	return true
