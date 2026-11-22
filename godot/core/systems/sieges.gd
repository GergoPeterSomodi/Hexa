## Sieges (docs/architecture/m7-build-spec.md 4.4, 4.5, 4.11, D18 and 5.3): the sieges phase. Lifts and removals of the running
## sieges first (4.5), then the walk-ins, the retakes and the sieges that start (4.4's table), the meters and falls (4.5), the
## garrisons' regrowth and the freed land (D18), and one controllers_changed (Occupation.flush). Battles and peaces never write
## game.sieges: this phase reads their outcome from this season's battle records and from the wars. Integer maths; no luck, no
## engine calls. Occupation writes occupier, garrison and unsupported; Sieges writes sieges and siege_names only.
class_name Sieges
extends RefCounted

@warning_ignore_start("integer_division")

const OWNS: Array[String] = ["sieges", "siege_names"]
const SIEGE_STARTED := "siege_started"
const SIEGE_PROGRESS := "siege_progress"
const SIEGE_LIFTED := "siege_lifted"
## The ordinal words of a repeat siege of a place: "Second Siege of Pavia, 1481" (4.5).
const ORDINALS: Array[String] = ["", "", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Ninth", "Tenth"]
## Forecasts look this many seasons ahead at most (-1 past it).
const FORECAST_MAX := 60
## Loader caps (from_dict): a forged save past these is refused. Progress needs at most a few dozen; seasons a long game's count.
const MAX_PROGRESS := 1000
const MAX_SEASONS := 200
const MAX_SIEGES := 500
const MAX_NAME_ENTRIES := 2000
const MAX_NAME_COUNT := 1000


# --- the numbers (4.5) -----------------------------------------------------------------------------------------------


## The numbers of a siege of `hex` by `tag` (4.5): garrison, full garrison, crowd (0 to 3), guns, rate, need, stores and ok (a
## rate above 0, so the siege moves). `men` and `guns` of -1 read tag's armies on the hex. Nothing is written.
static func terms(game: Game, hex: Vector2i, tag: StringName, men: int = -1, guns: int = -1) -> Dictionary:
	var war := _war(game)
	var lvl := Occupation.fortress_level(game, hex)
	var have := _men_of(game, tag, hex) if men < 0 else men
	var have_guns := _guns_of(game, tag, hex) if guns < 0 else guns
	var garrison := Occupation.garrison_of(game, hex)
	var crowd := 0
	if war != null and lvl > 0:
		crowd = _crowd(war, have, garrison)
	var rate := mini(war.siege_rate_max, crowd + have_guns) if war != null and crowd > 0 else 0
	return {"men": have, "garrison": garrison, "full": Occupation.garrison_full(game, hex), "crowd": crowd,
		"guns": have_guns, "rate": rate, "need": Occupation.siege_need(game, hex), "stores": 1 + lvl, "ok": rate > 0}


## Seasons until the siege of `hex` by tag falls at this rate, the arrival season counted (the meters of 4.5 read from the
## progress and seasons given): -1 when it never falls (too few men) or past FORECAST_MAX seasons. Nothing is written.
static func forecast(game: Game, hex: Vector2i, tag: StringName, men: int, guns: int, progress: int, seasons: int) -> int:
	var war := _war(game)
	var t := terms(game, hex, tag, men, guns)
	var rate := int(t["rate"])
	if war == null or rate <= 0:
		return -1
	var need := int(t["need"])
	var stores := int(t["stores"])
	var s := seasons
	var p := progress
	for k: int in range(1, FORECAST_MAX + 1):
		s += 1
		p += rate + (war.siege_hunger if s > stores else 0)
		if s >= war.siege_min_seasons and p >= need:
			return k
	return -1


## True when a siege stands on `hex` and its stores are out: the season count is past the stores (1 + level, 4.5: hunger
## applies in each season after the stores are out). M5's hunger rule then runs for the settlement with no food (D26).
static func starving(game: Game, hex: Vector2i) -> bool:
	var s := Occupation.siege_at(game, hex)
	return s != null and s.seasons > 1 + Occupation.fortress_level(game, hex)


## The siege on a hex, or null (Occupation.siege_at).
static func at(game: Game, hex: Vector2i) -> Siege:
	return Occupation.siege_at(game, hex)


# --- the phase (4.4, 4.5, D18) ---------------------------------------------------------------------------------------


## The sieges phase: standing fortresses read at its start; lifts and removals; the walk-ins, retakes and new sieges; the
## meters and falls; regrowth (Occupation.regrow_all); the freed land (support_season); one flush.
static func season(game: Game) -> void:
	if not _usable(game):
		return
	var standing := Occupation.standing(game)
	var records := _season_records(game)
	_lifts(game, records)
	_walk_all(game, standing, records)
	_meters(game, records)
	_hunger(game)
	Occupation.regrow_all(game)
	Occupation.support_season(game)
	Occupation.flush(game)


## Every siege, in hex index order: its lift (4.5) or its removal (a storm: the hex is the besieger's, no event).
static func _lifts(game: Game, records: Dictionary) -> void:
	for s: Siege in game.sieges.duplicate():
		var why := _lift_why(game, s, records)
		if why == &"keep":
			continue
		game.sieges.erase(s)
		if why != &"storm":
			_emit_lift(game, s, why)


## The reason a running siege lifts this season, or &"keep". A hex the besieger now controls (a storm) is &"storm".
static func _lift_why(game: Game, s: Siege, records: Dictionary) -> StringName:
	var holder := Occupation.controller_tag(game, s.hex)
	if holder == s.besieger:
		return &"storm"
	if holder == &"" or not Wars.at_war(game, s.besieger, holder):
		return &"peace"
	if (records["lost"] as Dictionary).has("%d|%s" % [_index(game, s.hex), String(s.besieger)]):
		return &"relief"
	if _men_of(game, s.besieger, s.hex) <= 0:
		return &"left"
	if _crowd_of(game, s) == 0:
		return &"outnumbered"
	return &"keep"


static func _emit_lift(game: Game, s: Siege, why: StringName) -> void:
	var holder := Occupation.controller_tag(game, s.hex)
	var others: Array[StringName] = []
	if holder != &"":
		others.append(holder)
	game.emit({"kind": SIEGE_LIFTED, "hex": s.hex, "tag": s.besieger, "others": others, "why": why, "name": s.name,
		"progress": s.progress, "need": Occupation.siege_need(game, s.hex), "seasons": s.seasons})


## The 4.4 table, in hex index order, over the hexes where the armies of exactly one country stand: a retake of own land,
## a siege that starts on a garrisoned fortress, or a walk-in of militia_men or more. Hexes a battle was fought on this
## season, and those a country's army retreated onto, are left alone.
static func _walk_all(game: Game, standing: PackedByteArray, records: Dictionary) -> void:
	var groups := _groups(game)
	var keys: Array = groups.keys()
	keys.sort()
	for i: Variant in keys:
		var group: Dictionary = groups[i]
		if group.size() != 1 or (records["fought"] as Dictionary).has(int(i)):
			continue
		var t: StringName = group.keys()[0]
		if (records["retreated"] as Dictionary).has("%d|%s" % [int(i), String(t)]):
			continue
		_act(game, game.map.hex_of(int(i)), t, int(group[t]), standing)


## One hex's row of the 4.4 table for the country t with `men` men on it.
static func _act(game: Game, hex: Vector2i, t: StringName, men: int, standing: PackedByteArray) -> void:
	var war := _war(game)
	var i := _index(game, hex)
	if war == null or i < 0 or game.map.land[i] == 0:
		return
	var t_id := _id_of(game, t)
	if t_id == 0 or Occupation.controller_id(game, hex) == t_id:
		return
	if _owner_id(game, i) == t_id:
		if men >= war.militia_men:
			Occupation.capture(game, hex, t, &"retaken", {})
		return
	var holder := Occupation.controller_tag(game, hex)
	if holder == &"" or not Wars.at_war(game, t, holder):
		return
	if Occupation.fortress_level(game, hex) > 0 and Occupation.garrison_of(game, hex) > 0:
		# 4.5: too few men (crowd 0, no rate) is no siege; the row ends here either way, so no walk-in.
		if bool(terms(game, hex, t)["ok"]):
			_start_siege(game, hex, t, holder)
		return
	if men < war.militia_men or Occupation.area_state(game, hex, standing) == &"held":
		return
	# Defence in depth (4.4): the walker must be at war with the owner as well as with the holder.
	if not Wars.at_war(game, t, _tag_of_owner(game, hex)):
		return
	Occupation.capture(game, hex, t, &"walk", _fall_info(game, hex, "", 0))


## Starts a siege of a garrisoned fortress by t (4.5): the name, the event; the arrival season counts (the meters run next).
static func _start_siege(game: Game, hex: Vector2i, t: StringName, holder: StringName) -> void:
	if Occupation.siege_at(game, hex) != null:
		return
	var s := Siege.new()
	s.hex = hex
	s.besieger = t
	s.started_turn = game.turn
	s.name = _name(game, hex)
	_insert_sorted(game, s)
	var numbers := terms(game, hex, t)
	var others: Array[StringName] = [holder]
	game.emit({"kind": SIEGE_STARTED, "hex": hex, "tag": t, "others": others, "name": s.name,
		"need": int(numbers["need"]), "level": Occupation.fortress_level(game, hex),
		"garrison": int(numbers["garrison"]), "men": int(numbers["men"])})


## The meters of every running siege (4.5): one season each, the progress (no progress beside a battle), the falls.
static func _meters(game: Game, records: Dictionary) -> void:
	var war := _war(game)
	if war == null:
		return
	for s: Siege in game.sieges.duplicate():
		var holder := Occupation.controller_tag(game, s.hex)
		if holder == &"" or not Wars.at_war(game, s.besieger, holder):
			continue
		s.seasons += 1
		var rate := 0
		var hunger := 0
		if not (records["fought"] as Dictionary).has(_index(game, s.hex)):
			rate = int(terms(game, s.hex, s.besieger)["rate"])
			hunger = war.siege_hunger if s.seasons > 1 + Occupation.fortress_level(game, s.hex) else 0
			s.progress += rate + hunger
		var need := Occupation.siege_need(game, s.hex)
		_emit_progress(game, s, holder, rate, hunger, need)
		if s.seasons >= war.siege_min_seasons and s.progress >= need:
			_fall(game, s)


## The besieged settlements whose stores are out (4.11, D26): M5's hunger rule with no food (People.rule_of at fed 0), its
## loss booked through the People door as starved on the owner, and the floor (town_floor) kept. A besieged fortress that
## is no settlement has no people to starve.
static func _hunger(game: Game) -> void:
	for s: Siege in game.sieges.duplicate():
		var i := _index(game, s.hex)
		if i < 0 or int(game.state.main_use[i]) != People.SETTLEMENTS or not starving(game, s.hex):
			continue
		var owner := Countries.by_id(game, _owner_id(game, i))
		var people: int = game.state.people[i]
		if owner == null or people <= 0:
			continue
		var slot := Economy.slot_for(int(game.map.climate[i]), Calendar.season_of(game.turn))
		var step := People.rule_of(game.defs, people, 0, true, People.rates_of(game.defs, slot, owner.tax), 0)
		if step.x < 0:
			People.move(game, s.hex, step.x, &"starved")


## A peace between a and b (4.9): every siege one of them runs on a hex the other owns lifts with why peace, and is removed.
## Sieges of other countries are left alone. Wars.make_peace releases the occupation itself; this only ends the sieges and
## flushes the change of control.
static func end_between(game: Game, a: StringName, b: StringName) -> void:
	for s: Siege in game.sieges.duplicate():
		var owner := _tag_of_owner(game, s.hex)
		var pair := (s.besieger == a and owner == b) or (s.besieger == b and owner == a)
		if not pair:
			continue
		game.sieges.erase(s)
		var others: Array[StringName] = [owner]
		game.emit({"kind": SIEGE_LIFTED, "hex": s.hex, "tag": s.besieger, "others": others, "why": &"peace",
			"name": s.name, "progress": s.progress, "need": Occupation.siege_need(game, s.hex), "seasons": s.seasons})
	Occupation.flush(game)


static func _emit_progress(game: Game, s: Siege, holder: StringName, rate: int, hunger: int, need: int) -> void:
	var others: Array[StringName] = [holder]
	game.emit({"kind": SIEGE_PROGRESS, "hex": s.hex, "tag": s.besieger, "others": others, "progress": s.progress,
		"need": need, "rate": rate, "hunger": hunger, "seasons": s.seasons, "name": s.name})


## A fall (4.5): the district goes to the besieger (its garrison's men are lost in Occupation.capture); the districts of its
## area its owner still holds are named as opened; the siege is removed.
static func _fall(game: Game, s: Siege) -> void:
	var owner_tag := _tag_of_owner(game, s.hex)
	Occupation.capture(game, s.hex, s.besieger, &"siege", _fall_info(game, s.hex, s.name, s.seasons, owner_tag))
	game.sieges.erase(s)


## The extra fields of a district_captured: name, seasons and opened (the districts of the fortress's area the owner holds).
static func _fall_info(game: Game, hex: Vector2i, name: String, seasons: int, owner_tag: StringName = &"") -> Dictionary:
	var opened: Array[Vector2i] = []
	var fortress := Occupation.area_of(game, hex)
	var owner := owner_tag if owner_tag != &"" else _tag_of_owner(game, hex)
	if fortress != Army.NO_HEX:
		for m: int in Occupation.members(game, fortress):
			var mh := game.map.hex_of(m)
			if mh != hex and Occupation.controller_tag(game, mh) == owner:
				opened.append(mh)
	return {"name": name, "seasons": seasons, "opened": opened}


# --- the records of this season and the armies -----------------------------------------------------------------------


## This season's battle records as sets: fought (hex index), lost ("index|tag" of the side that lost) and retreated
## ("index|tag" of a country whose army retreated onto the hex).
static func _season_records(game: Game) -> Dictionary:
	var out := {"fought": {}, "lost": {}, "retreated": {}}
	for r: BattleRecord in game.battle_records:
		if r.turn != game.turn:
			continue
		var i := game.map.index_of(r.hex)
		out["fought"][i] = true
		# The side that lost is read from the int winner (Combat: 0 the attacker, 1 the defender, -1 a draw: no loser).
		var winner := int(r.end.get("winner", -1))
		var loser := String(r.defender) if winner == 0 else (String(r.attacker) if winner == 1 else "")
		if loser != "":
			out["lost"]["%d|%s" % [i, loser]] = true
		_retreats_into(game, r, out["retreated"])
	return out


static func _retreats_into(game: Game, r: BattleRecord, retreated: Dictionary) -> void:
	var spots: Variant = r.end.get("retreat", {})
	if not (spots is Dictionary):
		return
	var table := spots as Dictionary
	for key: Variant in table:
		var army := Armies.by_id(game, int(str(key)))
		var spot := _spot_of(table[key])
		if army == null or spot == Army.NO_HEX:
			continue
		retreated["%d|%s" % [game.map.index_of(spot), String(army.tag)]] = true


static func _spot_of(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and (value as Array).size() == 2:
		return Vector2i(int((value as Array)[0]), int((value as Array)[1]))
	return Army.NO_HEX


## Per hex index: tag -> men of that country's armies on it (every army, land and sea alike is one map).
static func _groups(game: Game) -> Dictionary:
	var out: Dictionary = {}
	for a: Army in game.armies:
		var i := game.map.index_of(a.hex)
		if i < 0:
			continue
		var group: Dictionary = out.get(i, {})
		group[a.tag] = int(group.get(a.tag, 0)) + a.men()
		out[i] = group
	return out


static func _men_of(game: Game, tag: StringName, hex: Vector2i) -> int:
	var men := 0
	for a: Army in Armies.at(game, hex):
		if a.tag == tag:
			men += a.men()
	return men


static func _guns_of(game: Game, tag: StringName, hex: Vector2i) -> int:
	var guns := 0
	for a: Army in Armies.at(game, hex):
		if a.tag != tag:
			continue
		for u: Unit in a.units:
			var def := Military.unit_def(game, u.kind)
			guns += def.siege_points if def != null else 0
	return guns


static func _crowd_of(game: Game, s: Siege) -> int:
	var war := _war(game)
	return _crowd(war, _men_of(game, s.besieger, s.hex), Occupation.garrison_of(game, s.hex)) if war != null else 0


## 0 under the garrison; then 1, 2 or 3 by the crowd_bands (permille of the garrison).
static func _crowd(war: WarDef, men: int, garrison: int) -> int:
	if garrison <= 0 or men < garrison:
		return 0
	var permille := men * 1000 / garrison
	if permille < war.crowd_bands[0]:
		return 1
	return 2 if permille < war.crowd_bands[1] else 3


# --- names, order, saves -----------------------------------------------------------------------------------------------


## "Siege of Pavia, 1480", a repeat "Second Siege of Pavia, 1481"; counted in siege_names by place.
static func _name(game: Game, hex: Vector2i) -> String:
	var place := str(Improve.place_of(game.map, hex).get("name", ""))
	if place == "":
		place = Military.hex_text(game, hex)
	var n := int(game.siege_names.get(place, 0)) + 1
	game.siege_names[place] = n
	var head := "Siege of %s, %d" % [place, Calendar.year_of(game.turn, game.start_year)]
	if n == 1:
		return head
	var word := ORDINALS[n] if n < ORDINALS.size() else "%dth" % n
	return "%s %s" % [word, head]


static func _insert_sorted(game: Game, s: Siege) -> void:
	var at_index := game.sieges.size()
	for k: int in game.sieges.size():
		if _index(game, game.sieges[k].hex) > _index(game, s.hex):
			at_index = k
			break
	game.sieges.insert(at_index, s)


## The sieges and the place counts, as JSON-safe values (the loader is from_dict).
static func to_dict(game: Game) -> Dictionary:
	var rows: Array = []
	for s: Siege in game.sieges:
		rows.append(s.to_dict())
	return {"sieges": rows, "siege_names": game.siege_names.duplicate()}


## Reads to_dict's form into game. Returns "" when it loads, else the reason: a row that does not parse, a besieger that is no
## country, a hex that holds no fortress or no land, a hex met twice, rows out of hex order, or a bad count of the places.
static func from_dict(d: Dictionary, game: Game) -> String:
	var rows: Variant = d.get("sieges", [])
	var names: Variant = d.get("siege_names", {})
	if not (rows is Array) or not (names is Dictionary):
		return "sieges: not a list and a table"
	var list := rows as Array
	var table := names as Dictionary
	if list.size() > MAX_SIEGES:
		return "sieges: more than %d sieges" % MAX_SIEGES
	if table.size() > MAX_NAME_ENTRIES:
		return "siege_names: more than %d places" % MAX_NAME_ENTRIES
	var out: Array[Siege] = []
	var last := -1
	for row: Variant in list:
		var s: Siege = null
		if row is Dictionary:
			s = Siege.from_dict(row as Dictionary)
		if s == null:
			return "sieges: a row does not read"
		var reason := _row_problem(game, s, last)
		if reason != "":
			return reason
		last = game.map.index_of(s.hex)
		out.append(s)
	for key: Variant in table:
		if not (key is String) or not PlaceNames.key_ok(key as String):
			return "siege_names: a place name is not a plain name of 1 to %d characters" % PlaceNames.NAME_KEY_MAX
		var count: Variant = table[key]
		if not (count is int or count is float) or float(count) != floor(float(count)) or float(count) < 0 				or float(count) > MAX_NAME_COUNT:
			return "siege_names: a count is not a whole number of at most %d" % MAX_NAME_COUNT
	game.sieges = out
	game.siege_names = {}
	for key: Variant in table:
		game.siege_names[str(key)] = int(table[key])
	return ""


## Why a loaded siege row is refused, or "": a hex that holds a fortress, in hex order after `last`; a besieger that is a
## country, not the owner, at war with the owner; counts within their caps.
static func _row_problem(game: Game, s: Siege, last: int) -> String:
	var i := game.map.index_of(s.hex)
	if i <= last or Occupation.fortress_level(game, s.hex) == 0:
		return "sieges: a row names no fortress, or is out of hex order"
	if Countries.by_tag(game, s.besieger) == null:
		return "sieges: a besieger that is no country"
	if s.progress > MAX_PROGRESS or s.seasons > MAX_SEASONS:
		return "sieges: a count is past its cap"
	var owner := _tag_of_owner(game, s.hex)
	if s.besieger == owner:
		return "sieges: a besieger that is the owner"
	if not Wars.at_war(game, s.besieger, owner):
		return "sieges: a besieger with no war with the owner"
	return ""


## The digest: every siege's digest_text in hex order, then the place counts in sorted order.
static func digest(game: Game) -> String:
	var parts: PackedStringArray = []
	for s: Siege in game.sieges:
		parts.append(s.digest_text())
	var keys: Array = game.siege_names.keys()
	keys.sort()
	for key: Variant in keys:
		parts.append("%s=%d" % [str(key), int(game.siege_names[key])])
	return ";".join(parts)


# --- helpers -----------------------------------------------------------------------------------------------------------


static func _usable(game: Game) -> bool:
	return game != null and game.map != null and game.state != null and game.defs != null and game.has_countries() \
		and _war(game) != null


static func _war(game: Game) -> WarDef:
	return game.defs.war if game != null and game.defs != null else null


static func _index(game: Game, hex: Vector2i) -> int:
	return game.map.index_of(hex) if game != null and game.map != null else -1


static func _owner_id(game: Game, i: int) -> int:
	return int(game.state.owner[i]) if i >= 0 and i < game.state.owner.size() else 0


static func _tag_of_owner(game: Game, hex: Vector2i) -> StringName:
	var c := Countries.by_id(game, _owner_id(game, _index(game, hex)))
	return c.tag if c != null else &""


static func _id_of(game: Game, tag: StringName) -> int:
	var c := Countries.by_tag(game, tag) if tag != &"" else null
	return c.id if c != null else 0
