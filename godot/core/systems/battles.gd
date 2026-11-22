@warning_ignore_start("integer_division")
## A battle's life (docs/architecture/m7-build-spec.md 4.6, 4.7, 5.3; M7 plan B8): a battle starts when an army attacks, joins or
## storms (engage, from the movement phase), is fought in the battles phase (season) by Combat.fight on the live ground, and is
## settled by BattleEnd. The only writer of game.battles, battle_records, next_record_id and battle_names. Every army, unit and
## fortress change goes through its door (Armies, Occupation, Wars, People). Luck: game.luck.world, through the fight alone.
## Integer maths; no engine calls. The save body (to_dict, from_dict) cross-checks every id it holds.
## Engage is called with the army still on its stand hex: when it takes the step it moves the army onto the battle hex
## (Armies.set_hex) and returns true; a false return changes nothing.
class_name Battles
extends RefCounted

const OWNS: Array[String] = ["battles", "battle_records", "next_record_id", "battle_names"]
const SCHEMA := "hexa-godot/battles/1"
## The text a refused saved body gives (Armies.PROBLEM_BODY's form).
const PROBLEM_BODY := "body"
const SIDE_ATTACKER := 0
const SIDE_DEFENDER := 1
const SIDE_WORDS: Array[String] = ["attacker", "defender"]
## The words of a repeat battle at one place: index 0 is the first (no word), index 1 "Second" and so on.
const ORDINALS: PackedStringArray = ["", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Ninth", "Tenth"]
const GARRISON_MORALE := 1000
const OPEN_KEY := "open"
## The loader's limits for the name table (saved with the battles): the most places, the longest place name, and the most battles
## counted at one place. Chosen with the sieges' table (B9 uses the same numbers for siege_names).
const NAMES_MAX := 2000
const NAME_KEY_MAX := 200
const NAME_COUNT_MAX := 1000000


# --- queries ---------------------------------------------------------------------------------------------------------


## The live battle on a hex, or null.
static func at(game: Game, hex: Vector2i) -> Battle:
	for b: Battle in game.battles:
		if b.hex == hex:
			return b
	return null


## The battle an army is in, or null.
static func of_army(game: Game, army_id: int) -> Battle:
	for b: Battle in game.battles:
		for key: Variant in b.armies:
			if _ids(b, str(key)).has(army_id):
				return b
	return null


## The kept record with this id, or null when it is no longer kept.
static func record(game: Game, id: int) -> BattleRecord:
	for r: BattleRecord in game.battle_records:
		if r.id == id:
			return r
	return null


## The kept records a country fought in (as attacker or defender), newest first; turn 0 for all turns.
static func records_of(game: Game, tag: StringName, turn: int = 0) -> Array[BattleRecord]:
	var out: Array[BattleRecord] = []
	for i: int in range(game.battle_records.size() - 1, -1, -1):
		var r: BattleRecord = game.battle_records[i]
		if (r.attacker == tag or r.defender == tag) and (turn == 0 or r.turn == turn):
			out.append(r)
	return out


## True when `adding` more companies of tag fit on hex under the stack limit (the companies there count already).
static func fits(game: Game, tag: StringName, hex: Vector2i, adding: int) -> bool:
	return Armies.units_at(game, tag, hex) + adding <= game.defs.stack_limit


# --- starting a battle (4.6 start, 4.7 the check) --------------------------------------------------------------------


## The check of an army's step onto a hex where a battle or an enemy army stands (4.7): args {army (id), hex, tag}. Rows 1 to 4
## of the table: the army (M6's words), a hex of another country's army, the morale (attack_morale), the stack limit. Extra
## refusals: two enemy countries on one hex, and a battle of others there. {ok, reason}; "" when ok. Changes nothing.
static func engage_check(game: Game, args: Dictionary) -> Dictionary:
	var id := int(args.get("army", 0))
	if id < 1:
		return _refusal("no army given")
	var army := Armies.by_id(game, id)
	if army == null:
		return _refusal("no army %d" % id)
	var tag := StringName(str(args.get("tag", "")))
	if army.tag != tag:
		return _refusal("not your army: %s commands it" % _the(game, army.tag))
	var hex: Vector2i = args.get("hex", Army.NO_HEX)
	if game.map.index_of(hex) < 0 or not game.map.is_land(hex):
		return _refusal("no way there by land: %s is not land" % _coords(hex))
	var reason := _hostile_reason(game, army, hex)
	if reason != "":
		return _refusal(reason)
	return _room_reason(game, army, hex)


## Rows 2 and 3 of engage_check and the refusals beside them: "" when none applies.
static func _hostile_reason(game: Game, army: Army, hex: Vector2i) -> String:
	var foreign := _foreign_at(game, army.tag, hex)
	if foreign != null:
		return "another country's army stands at %s" % _place_text(game, hex)
	if _enemy_tags_at(game, army.tag, hex).size() > 1:
		return "more than one enemy country stands at %s: one battle at a time" % _place_text(game, hex)
	var b := at(game, hex)
	if b != null and _side(b, army.tag) < 0:
		return "the %s is fought there: you cannot join it" % b.name
	var war := _war(game)
	var morale := Armies.morale_of(army)
	if morale < war.attack_morale:
		return "too shaken to attack: morale %d %%, %d %% needed (it recovers %d a season when fed)" % [
			morale / 10, war.attack_morale / 10, war.morale_recovery / 10]
	return ""


## Row 4 of engage_check: the companies of the army's country already on the hex (not the army's own) plus the army's fit the
## stack limit.
static func _room_reason(game: Game, army: Army, hex: Vector2i) -> Dictionary:
	var limit: int = game.defs.stack_limit
	var there := Armies.units_at(game, army.tag, hex, PackedInt32Array([army.id]))
	if there + army.units.size() > limit:
		return _refusal("no room: %d of %d companies of yours stand there already" % [there, limit])
	return _ok()


## Starts a battle, joins one or storms a fortress for an army whose step ends on hex (4.6). A battle of the army's side there
## takes it in (battle_joined); a hex of enemy armies starts a battle (battle_started); a hostile garrisoned fortress with no
## army and the army's storm order starts an assault. True when a battle is set up or joined; false (no change) for a plain
## step, a refusal or no war. last_edge is the map's edge index of the step (-1 for none).
static func engage(game: Game, army: Army, hex: Vector2i, tick: int, last_edge: int) -> bool:
	if game == null or army == null or game.defs == null or game.defs.war == null:
		return false
	if not bool(engage_check(game, {"army": army.id, "hex": hex, "tag": army.tag}).ok):
		return false
	var b := at(game, hex)
	if b != null:
		_join(game, b, army)
		return true
	var enemies := _enemies_at(game, army.tag, hex)
	if enemies.is_empty():
		if army.order == Army.ORDER_STORM and _storm_target(game, army.tag, hex):
			return _storm(game, army, hex, tick)
		return false
	return _attack(game, army, enemies, hex, tick, last_edge)


## A new battle of army against the enemy armies on hex (one country, checked by engage_check).
static func _attack(game: Game, army: Army, enemies: Array[Army], hex: Vector2i, tick: int, last_edge: int) -> bool:
	var stand := army.hex
	var b := Battle.new()
	b.hex = hex
	b.attacker = army.tag
	b.defender = enemies[0].tag
	b.start_turn = game.turn
	b.tick = tick
	b.assault = assault_at(game, hex, b.defender)
	b.set_group(String(army.tag), PackedInt32Array([army.id]))
	b.set_group(String(b.defender), _ids_of(enemies))
	_set_flags(game, b, stand, last_edge)
	b.name = name_for(game, hex)
	_begin(game, b, army, stand)
	return true


## A storm: the army alone against the garrison of the hostile fortress it stands on. The garrison's cut is the storm's (4.6).
static func _storm(game: Game, army: Army, hex: Vector2i, tick: int) -> bool:
	var stand := army.hex
	var b := Battle.new()
	b.hex = hex
	b.attacker = army.tag
	b.defender = Occupation.controller_tag(game, hex)
	b.start_turn = game.turn
	b.tick = tick
	b.assault = true
	b.set_group(String(army.tag), PackedInt32Array([army.id]))
	var garrison := Occupation.garrison_of(game, hex)
	var faced := Occupation.storm_garrison(game, hex, army.tag)
	if faced < garrison:
		b.storm_from = garrison
		b.storm_cut = faced
	_set_flags(game, b, stand, -1)
	b.name = name_for(game, hex)
	_begin(game, b, army, stand)
	return true


## An army takes its place in the battle on its hex, on its side (engage_check refuses a battle of the other side).
static func _join(game: Game, b: Battle, army: Army) -> void:
	var side := _side(b, army.tag)
	var stand := army.hex
	_step_in(game, army, b.hex, stand)
	var key := String(army.tag)
	var ids := _ids(b, key)
	ids.append(army.id)
	b.set_group(key, ids)
	game.emit({"kind": "battle_joined", "tag": army.tag, "hex": b.hex, "army": army.id, "side": SIDE_WORDS[side],
		"men": army.men(), "witnesses": BattleEnd.witnesses(game, b.hex, b.attacker, b.defender)})


## Registers a new battle: the army takes its step, the battle joins the list and battle_started is emitted.
static func _begin(game: Game, b: Battle, army: Army, stand: Vector2i) -> void:
	_step_in(game, army, b.hex, stand)
	game.battles.append(b)
	game.emit({"kind": "battle_started", "tag": b.attacker, "hex": b.hex, "others": [b.defender], "defender": b.defender,
		"assault": b.assault, "name": b.name, "year": Calendar.year_of(game.turn, game.start_year), "tick": b.tick,
		"witnesses": BattleEnd.witnesses(game, b.hex, b.attacker, b.defender)})


## The army stands on the battle hex and its march ends in the battle (order none; the goal and route are kept).
static func _step_in(game: Game, army: Army, hex: Vector2i, stand: Vector2i) -> void:
	Armies.set_hex(game, army, hex, stand)
	Armies.set_order(game, army, Army.ORDER_NONE, army.goal, army.route)


## The crossing, river and uphill flags of a battle from its last step (4.6): the attacker's stand hex is under the battle hex
## (uphill); a step over a pass edge crosses; a river of class 1 to 3 with no bridge is crossed.
static func _set_flags(game: Game, b: Battle, stand: Vector2i, last_edge: int) -> void:
	var map := game.map
	var hi := map.index_of(b.hex)
	var si := map.index_of(stand)
	b.uphill = hi >= 0 and si >= 0 and si != hi and int(map.relief[si]) < int(map.relief[hi])
	if last_edge >= 0 and last_edge < map.pass_edge.size():
		b.crossing = int(map.pass_edge[last_edge]) != 0
		var river := int(map.river[last_edge])
		b.river = river >= 1 and river <= 3 and int(map.crossing[last_edge]) == 0


## The name of the place of a hex for a battle (4.6): the hex's own place, else the nearest named place within two hexes, else "".
static func place_name(game: Game, hex: Vector2i) -> String:
	var seen := {hex: true}
	var ring: Array[Vector2i] = [hex]
	for _k: int in 3:
		for h: Vector2i in ring:
			var text := str(Improve.place_of(game.map, h).get("name", ""))
			if text != "":
				return text
		var next: Array[Vector2i] = []
		for h: Vector2i in ring:
			for d: int in 6:
				var n := game.map.neighbour(h, d)
				if game.map.has(n) and not seen.has(n):
					seen[n] = true
					next.append(n)
		ring = next
	return ""


## The battle's name ("Battle of Alessandria, 1480", "Second Battle of Alessandria, 1480", "Battle at (3, 8), 1480"); the count of
## battles named there goes up in battle_names.
static func name_for(game: Game, hex: Vector2i) -> String:
	var place := place_name(game, hex)
	var key := place if place != "" else _coords(hex)
	var count := int(game.battle_names.get(key, 0)) + 1
	game.battle_names[key] = count
	var head := "Battle"
	if count >= 2 and count <= ORDINALS.size():
		head = "%s Battle" % ORDINALS[count - 1]
	elif count > ORDINALS.size():
		head = "%dth Battle" % count
	var year := Calendar.year_of(game.turn, game.start_year)
	if place != "":
		return "%s of %s, %d" % [head, place, year]
	return "%s at %s, %d" % [head, _coords(hex), year]


## The enemy armies standing on hex (at war with tag), in id order.
static func _enemies_at(game: Game, tag: StringName, hex: Vector2i) -> Array[Army]:
	var out: Array[Army] = []
	for a: Army in Armies.at(game, hex):
		if a.tag != tag and Wars.at_war(game, tag, a.tag):
			out.append(a)
	return out


## The distinct countries of the enemy armies on hex, in the order they appear.
static func _enemy_tags_at(game: Game, tag: StringName, hex: Vector2i) -> Array[StringName]:
	var out: Array[StringName] = []
	for a: Army in _enemies_at(game, tag, hex):
		if not out.has(a.tag):
			out.append(a.tag)
	return out


## The first army on hex of a country that is neither tag nor at war with it, or null.
static func _foreign_at(game: Game, tag: StringName, hex: Vector2i) -> Army:
	for a: Army in Armies.at(game, hex):
		if a.tag != tag and not Wars.at_war(game, tag, a.tag):
			return a
	return null


## A hostile garrisoned fortress: held by a country at war with tag, with a garrison and a fortress level.
static func _storm_target(game: Game, tag: StringName, hex: Vector2i) -> bool:
	if Occupation.fortress_level(game, hex) <= 0 or Occupation.garrison_of(game, hex) <= 0:
		return false
	var holder := Occupation.controller_tag(game, hex)
	return holder != tag and holder != &"" and Wars.at_war(game, tag, holder)


## An assault: a garrisoned fortress the defender holds.
static func assault_at(game: Game, hex: Vector2i, defender: StringName) -> bool:
	return Occupation.fortress_level(game, hex) > 0 and Occupation.controller_tag(game, hex) == defender \
		and Occupation.garrison_of(game, hex) > 0


## The side of a battle a country holds: 0 attacker, 1 defender, -1 none.
static func _side(b: Battle, tag: StringName) -> int:
	if tag == b.attacker:
		return SIDE_ATTACKER
	if tag == b.defender:
		return SIDE_DEFENDER
	return -1


## The army ids of a battle's country (a copy), in the order they came.
static func _ids(b: Battle, key: String) -> PackedInt32Array:
	var found: Variant = b.armies.get(key, PackedInt32Array())
	var out := PackedInt32Array()
	if found is PackedInt32Array:
		out = (found as PackedInt32Array).duplicate()
	elif found is Array:
		for n: Variant in found as Array:
			out.append(int(n))
	return out


static func _ids_of(armies: Array[Army]) -> PackedInt32Array:
	var out := PackedInt32Array()
	for a: Army in armies:
		out.append(a.id)
	return out


## The armies of a battle's country that still exist, in the order they came.
static func _battle_armies(game: Game, b: Battle, tag: StringName) -> Array[Army]:
	var out: Array[Army] = []
	for id: int in _ids(b, String(tag)):
		var a := Armies.by_id(game, id)
		if a != null:
			out.append(a)
	return out


static func _war(game: Game) -> WarDef:
	return game.defs.war if game != null and game.defs != null else null


static func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


static func _ok() -> Dictionary:
	return {"ok": true, "reason": ""}


static func _the(game: Game, tag: StringName) -> String:
	var cdef := Countries.def_of(game, tag)
	return "the " + (cdef.long_name if cdef != null and cdef.long_name != "" else String(tag))


static func _coords(hex: Vector2i) -> String:
	return "(%d, %d)" % [hex.x, hex.y]


static func _place_text(game: Game, hex: Vector2i) -> String:
	var text := str(Improve.place_of(game.map, hex).get("name", ""))
	return "%s %s" % [text, _coords(hex)] if text != "" else _coords(hex)


# --- the battles phase (4.6) -----------------------------------------------------------------------------------------


## The battles phase: first every storm order standing on its goal starts its assault; then every battle, in hex index order, is
## fought (Combat.fight on input_of, luck from game.luck.world) and settled (BattleEnd.apply). game.battles is empty after it.
static func season(game: Game) -> void:
	if game == null or game.map == null or game.defs == null or game.defs.war == null:
		game.battles.clear()
		return
	var armies: Array[Army] = []
	armies.assign(game.armies)
	for a: Army in armies:
		if a.order == Army.ORDER_STORM and a.hex == a.goal and at(game, a.hex) == null:
			engage(game, a, a.hex, 0, -1)
	var list: Array[Battle] = []
	list.assign(game.battles)
	list.sort_custom(func(x: Battle, y: Battle) -> bool: return game.map.index_of(x.hex) < game.map.index_of(y.hex))
	game.battles.clear()
	for b: Battle in list:
		_fight(game, b)
	if not list.is_empty():
		Occupation.flush(game)
		Sight.refresh(game)


## Fights one battle and keeps its record (the oldest records go past battle_records_kept).
static func _fight(game: Game, b: Battle) -> void:
	var war := _war(game)
	var input := input_of(game, b)
	var problems := CombatInput.validate(war, input, game.defs.units.size())
	if not problems.is_empty():
		# Conservative: a battle the fight cannot take is ended as a draw (as end_all does), never dropped with its armies stacked.
		push_warning("battle at %s ended as a draw, not fought: %s" % [_coords(b.hex), problems[0]])
		BattleEnd.peace(game, b)
		return
	var luck_before := game.luck.world.get_state()
	var result := Combat.fight(war, input, game.luck.world)
	var id := game.next_record_id
	game.next_record_id += 1
	var rec := BattleEnd.apply(game, b, input, result, luck_before, id, Battles.retreat_path)
	game.battle_records.append(rec)
	while game.battle_records.size() > war.battle_records_kept:
		game.battle_records.remove_at(0)


## Combat.fight's input for a battle, from the live state (4.6, 5.3): the ground of its hex, the sides' companies, the stances
## and whether each side can retreat, and the garrison. Reads only.
static func input_of(game: Game, b: Battle) -> Dictionary:
	var garrison := _garrison(game, b)
	var attacker_armies := _battle_armies(game, b, b.attacker)
	var defender_armies := _battle_armies(game, b, b.defender)
	var att_can := not retreat_path(game, b.attacker, attacker_armies, b.hex, false).is_empty()
	var stance_def := "hold"
	var def_can := not retreat_path(game, b.defender, defender_armies, b.hex, false).is_empty()
	if _standing(defender_armies) == Army.STANDING_WITHDRAW \
			and not retreat_path(game, b.defender, defender_armies, b.hex, true).is_empty():
		stance_def = "withdraw"
		def_can = true
	return {
		"attacker": String(b.attacker), "defender": String(b.defender),
		"assault": b.assault and not garrison.is_empty(), "ground": ground_at(game, b.hex),
		"crossing": b.crossing, "uphill": b.uphill, "river": b.river,
		"stance": {"att": "attack", "def": stance_def}, "can_retreat": {"att": att_can, "def": def_can},
		"fighters": _fighters(game, b), "garrison": garrison,
	}


## The standing order of a side: the lowest-id army's (Hold when it has none).
static func _standing(armies: Array[Army]) -> StringName:
	var first: Army = null
	for a: Army in armies:
		if first == null or a.id < first.id:
			first = a
	return first.standing if first != null else Army.STANDING_HOLD


## The ground of a hex for Combat (4.6): the cover's defence and its rough and narrow flags, the relief's additions, and the odds key.
static func ground_at(game: Game, hex: Vector2i) -> Dictionary:
	var map := game.map
	var i := map.index_of(hex)
	var relief := int(map.relief[i])
	var td := game.defs.terrain(int(map.cover[i]))
	var defence := td.defence_permille if td != null else 0
	var rough := td != null and td.rough
	var narrow := td != null and td.narrow
	return Combat.make_ground(_war(game), defence, rough, narrow, relief, _odds_key(game, td, relief))


## The odds key of a hex (D50): its woods, marsh or snow cover; else mountains and hills by relief; else open.
static func _odds_key(game: Game, td: TerrainDef, relief: int) -> String:
	if td != null and ["woods", "marsh", "snow"].has(String(td.key)):
		return String(td.key)
	var war := _war(game)
	if relief >= war.relief_narrow_from:
		return "mountains"
	if relief >= war.relief_rough_from:
		return "hills"
	return OPEN_KEY


## The fighters of both sides in Combat's input form: a company's men, full strength, attack, defence, fire, rank, morale and
## whether its army was hungry at the last supply phase.
static func _fighters(game: Game, b: Battle) -> Array:
	var out: Array = []
	for side: int in 2:
		var tag := b.attacker if side == SIDE_ATTACKER else b.defender
		for a: Army in _battle_armies(game, b, tag):
			for u: Unit in a.units:
				var ud := game.defs.unit_def(u.kind)
				if ud == null:
					continue
				out.append({"key": u.id, "side": side, "branch": String(ud.branch), "men": u.men, "full": ud.men,
					"attack": ud.attack, "defence": ud.defence, "fire": ud.fire_permille, "rank": Armies.rank_of(game, u),
					"morale": u.morale, "hungry": a.supply == 2, "kind": u.kind, "army": a.id})
	return out


## The garrison of an assault in Combat's form: the men that fight (the storm's cut removed) of the fortress level's full; {} when
## the battle is no assault or its garrison has no man.
static func _garrison(game: Game, b: Battle) -> Dictionary:
	if not b.assault:
		return {}
	var men := b.storm_cut if b.storm_cut > 0 else Occupation.garrison_of(game, b.hex)
	if men <= 0:
		return {}
	return {"men": men, "full": Occupation.garrison_full(game, b.hex), "level": Occupation.fortress_level(game, b.hex),
		"morale": GARRISON_MORALE}


# --- the retreat (4.6, the end): the walk is BattleRetreat's (battle_retreat.gd) ---------------------------------------------

## The walk of a side's armies to its retreat spot (see BattleRetreat.retreat_path).
static func retreat_path(game: Game, tag: StringName, armies: Array[Army], hex: Vector2i, own_only: bool) -> Array[Vector2i]:
	return BattleRetreat.retreat_path(game, tag, armies, hex, own_only)


## The retreat spot of a side (see BattleRetreat.retreat_spot).
static func retreat_spot(game: Game, tag: StringName, armies: Array[Army], hex: Vector2i, own_only: bool) -> Vector2i:
	return BattleRetreat.retreat_spot(game, tag, armies, hex, own_only)


## True when tag's armies on hex have a retreat spot (see BattleRetreat.can_retreat).
static func can_retreat(game: Game, tag: StringName, hex: Vector2i) -> bool:
	return BattleRetreat.can_retreat(game, tag, hex)



## A peace between a and b ends every open battle of the two (4.9, D30): no day is fought, no pursuit, no experience. The battle
## leaves the list, its armies keep their hexes with orders none, and battle_ended is queued with how "peace" (a draw: winner and
## loser empty, record -1). A battle has fought no day when it is ended here, and a record keeps 1 to 8 days, so no record is
## made. Battles of other countries are untouched. Returns how many battles ended (0 is a no-op).
static func end_all(game: Game, a: StringName, b: StringName) -> int:
	if game == null or game.map == null:
		return 0
	var keep: Array[Battle] = []
	var ended := 0
	for bt: Battle in game.battles:
		var pair := (bt.attacker == a and bt.defender == b) or (bt.attacker == b and bt.defender == a)
		if not pair:
			keep.append(bt)
			continue
		BattleEnd.peace(game, bt)
		ended += 1
	if ended == 0:
		return 0
	game.battles.assign(keep)
	Occupation.flush(game)
	Sight.refresh(game)
	return ended


# --- the save body and the digest ------------------------------------------------------------------------------------


## Every line of the battles' state, in order: the battles, the records' digests, next_record_id, the name counts.
static func digest(game: Game) -> String:
	var lines := PackedStringArray()
	for b: Battle in game.battles:
		lines.append(b.digest_text())
	lines.append("records")
	for r: BattleRecord in game.battle_records:
		lines.append(r.digest())
	lines.append("next %d" % game.next_record_id)
	var keys: Array = game.battle_names.keys()
	keys.sort()
	for key: Variant in keys:
		lines.append("name %s %d" % [str(key), int(game.battle_names[key])])
	return "\n".join(lines)


## {schema, next_record_id, names: {place: count}, battles: [Battle], records: [BattleRecord]} (5.2, 5.4).
static func to_dict(game: Game) -> Dictionary:
	var names := {}
	for key: Variant in game.battle_names:
		names[str(key)] = int(game.battle_names[key])
	var battles: Array = []
	for b: Battle in game.battles:
		battles.append(b.to_dict())
	var records: Array = []
	for r: BattleRecord in game.battle_records:
		records.append(r.to_dict())
	return {"schema": SCHEMA, "next_record_id": game.next_record_id, "names": names, "battles": battles, "records": records}


## Fills the battles and records from a saved body, or refuses with PROBLEM_BODY and changes nothing. A battle's armies must exist,
## stand on its hex, be of the country the group names, and stand in no other battle; its hex is land; its countries exist. A
## record's id is above 0, below next_record_id and ascending; its turn is not after the game's; there are at most
## battle_records_kept of them.
static func from_dict(d: Dictionary, game: Game) -> String:
	var war := _war(game)
	if game == null or game.map == null or war == null or str(d.get("schema", "")) != SCHEMA:
		return PROBLEM_BODY
	var next: Variant = Unit.whole(d.get("next_record_id", null))
	if next == null or int(next) < 1 or not (d.get("names", null) is Dictionary) \
			or not (d.get("battles", null) is Array) or not (d.get("records", null) is Array):
		return PROBLEM_BODY
	var names: Variant = _names_from(d["names"] as Dictionary)
	var battles: Variant = _battles_from(d["battles"] as Array, game)
	var records: Variant = _records_from(d["records"] as Array, game, int(next), war)
	if records is String:
		return records as String
	if names == null or battles == null or records == null:
		return PROBLEM_BODY
	game.battles.assign(battles)
	game.battle_records.assign(records)
	game.next_record_id = int(next)
	game.battle_names = names
	return ""


## A storm's fields match the fortress on its hex (the garrison when it began, a cut no larger than it, a fortress held by the
## defender for an assault); a battle that is no assault has no storm fields.
static func _storm_ok(game: Game, b: Battle) -> bool:
	if b.storm_from != 0 or b.storm_cut != 0:
		if not b.assault or b.storm_from != Occupation.garrison_of(game, b.hex) or b.storm_cut > b.storm_from:
			return false
	if b.assault:
		if Occupation.fortress_level(game, b.hex) <= 0 or Occupation.garrison_of(game, b.hex) <= 0:
			return false
		if Occupation.controller_tag(game, b.hex) != b.defender:
			return false
	return true


## The name counts of a saved body: at most NAMES_MAX places, each a text of at most NAME_KEY_MAX characters with a whole count
## from 0 to NAME_COUNT_MAX; null otherwise.
static func _names_from(raw: Dictionary) -> Variant:
	if raw.size() > NAMES_MAX:
		return null
	var out := {}
	for key: Variant in raw:
		var value: Variant = raw[key]
		if not (key is String) or not PlaceNames.key_ok(key as String):  # the shared rule (PlaceNames: length, no control or separator)
			return null
		if not (value is int or value is float):
			return null
		var f := float(value)
		if f < 0.0 or f > float(NAME_COUNT_MAX) or f != roundf(f):
			return null
		out[str(key)] = int(f)
	return out


## The battles of a saved body in their saved order, each checked against the game; null when one fails.
static func _battles_from(list: Array, game: Game) -> Variant:
	var out: Array[Battle] = []
	var seen := {}
	var hexes := {}
	for item: Variant in list:
		if not (item is Dictionary):
			return null
		var b := Battle.from_dict(item as Dictionary)
		if b == null or hexes.has(b.hex) or not _battle_ok(game, b, seen):
			return null
		hexes[b.hex] = true
		out.append(b)
	return out


## The cross-checks of one battle (see from_dict); seen collects the army ids already in a battle. A battle is between two
## countries at war, began no later than this turn, stands on land, and its storm (if any) is a storm of the fortress there.
static func _battle_ok(game: Game, b: Battle, seen: Dictionary) -> bool:
	if game.map.index_of(b.hex) < 0 or not game.map.is_land(b.hex):
		return false
	if Countries.by_tag(game, b.attacker) == null or Countries.by_tag(game, b.defender) == null:
		return false
	if not Wars.at_war(game, b.attacker, b.defender):
		return false
	if b.start_turn < 1 or b.start_turn > game.turn or not _storm_ok(game, b):
		return false
	for key: Variant in b.armies:
		var tag := StringName(str(key))
		for id: int in _ids(b, str(key)):
			var a := Armies.by_id(game, id)
			if a == null or a.tag != tag or a.hex != b.hex or seen.has(id):
				return false
			seen[id] = true
	return true


## The records of a saved body, ascending by id and within the limits of from_dict. Each record's input must validate exactly as a
## live battle's input does (CombatInput.validate with the unit count), so a hostile fighter cannot reach a reader. Returns the
## list, or the reason it is refused (PROBLEM_BODY for a shape the records do not read).
static func _records_from(list: Array, game: Game, next: int, war: WarDef) -> Variant:
	if list.size() > war.battle_records_kept:
		return PROBLEM_BODY
	var out: Array[BattleRecord] = []
	var last := 0
	for item: Variant in list:
		if not (item is Dictionary):
			return PROBLEM_BODY
		var r := BattleRecord.from_dict(item as Dictionary)
		if r == null or r.id <= last or r.id >= next or r.turn > game.turn:
			return PROBLEM_BODY
		if game.map.index_of(r.hex) < 0 or Countries.by_tag(game, r.attacker) == null or Countries.by_tag(game, r.defender) == null:
			return PROBLEM_BODY
		var problems := CombatInput.validate(war, r.input, game.defs.units.size())
		if not problems.is_empty():
			return "record %d: %s" % [r.id, problems[0]]
		last = r.id
		out.append(r)
	return out
