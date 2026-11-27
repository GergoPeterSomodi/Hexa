## The end of a fought battle (docs/architecture/m7-build-spec.md 4.6 the end, 4.14, 5.3; M7 plan B8): the men of every company
## (Armies), the morale and experience, the beaten side's retreat or surrender, the wounded who return in supply, a fortress's storm
## and its sack, the garrison's men (Occupation), the record (BattleRecord, D43), the war's books (Wars.book_battle) and the battle
## events. Battles.apply is called by Battles; the retreat walk is Battles.retreat_path, called by reference so the two files do not
## need each other to parse. No luck: the fight drew it all. Integer maths; no engine calls.
class_name BattleEnd
extends RefCounted

const OWNS: Array[String] = []
const SURRENDERED := "surrendered"
const SIDE_ATTACKER := 0
const SIDE_DEFENDER := 1
const CAUSE_WORDS: Dictionary = {"stance": "order", "timer": "cap", "centre": "centre", "lanes": "lanes", "morale": "morale"}


@warning_ignore_start("integer_division")
## Settles a fought battle and returns its record (id `id`). input is the Combat input (the record keeps its plain form), result
## Combat.fight's output, luck_before the luck state before its first day. Writes the armies through Armies, the fortress through
## Occupation, the war through Wars, and queues battle_fought and battle_ended.
static func apply(game: Game, battle: Battle, input: Dictionary, result: Dictionary, luck_before: int, id: int,
		retreat_fn: Callable, now: bool = false) -> BattleRecord:
	var rec := _record(game, battle, input, result, luck_before, id)
	var raw: Dictionary = result["end"]
	var loser := _loser_side(raw)
	var defender_field := _field_count(input)
	_book_fight_losses(game, battle, rec.end)
	var retreat := Army.NO_HEX
	var surrendered := false
	if loser >= 0 and not _side_armies(game, battle, loser).is_empty():
		var path: Array = _beaten(game, battle, loser, raw, rec.end, retreat_fn, now)
		if path.is_empty():
			_surrender(game, battle, loser, rec.end)
			surrendered = true
		else:
			retreat = path.back()
	_returns(game, battle, rec.end)
	_morale_and_xp(game, battle, rec.end, loser)
	var stormed := _settle_fortress(game, battle, rec.end, raw, surrendered, defender_field)
	rec.end["stormed"] = stormed
	rec.end["sacked"] = sack(game, battle.hex) if stormed else 0
	rec.end["how"] = _how_word(str(raw["how"]), int(raw["winner"]), surrendered)
	rec.end["cause"] = _cause_word(str(raw["how"]), str(raw["cause"]))
	rec.witnesses = witnesses(game, battle.hex, battle.attacker, battle.defender)
	Wars.book_battle(game, rec)
	_events(game, battle, rec, retreat)
	return rec


## The people a sack costs a walled town or city stormed (D27): sack_permille of its people, as a People flow `sacked`. Returns the
## people lost (0 for any other hex).
static func sack(game: Game, hex: Vector2i) -> int:
	var war: WarDef = game.defs.war if game.defs != null else null
	var i := game.map.index_of(hex)
	if war == null or i < 0 or game.state == null or i >= game.state.main_use.size():
		return 0
	if int(game.state.main_use[i]) != Economy.SETTLEMENTS or Occupation.fortress_level(game, hex) <= 0:
		return 0
	var lost := int(game.state.people[i]) * war.sack_permille / 1000
	if lost <= 0:
		return 0
	return lost if People.move(game, hex, -lost, &"sacked") else 0


## The witnesses of a battle's events: its two sides and the countries that see the hex (Sight), in country id order.
static func witnesses(game: Game, hex: Vector2i, a: StringName, d: StringName) -> PackedStringArray:
	var tags: Array[String] = []
	var found: Array[String] = [String(a), String(d)]
	for tag: String in Sight.witnesses_of(game, hex, a):
		found.append(tag)
	for tag: String in Sight.witnesses_of(game, hex, d):
		found.append(tag)
	for tag: String in found:
		if tag != "" and not tags.has(tag):
			tags.append(tag)
	tags.sort_custom(func(x: String, y: String) -> bool: return _id_of(game, x) < _id_of(game, y))
	return PackedStringArray(tags)


static func _id_of(game: Game, tag: String) -> int:
	var c := Countries.by_tag(game, StringName(tag))
	return c.id if c != null else 0


# --- the record and the fight's losses -------------------------------------------------------------------------------


## The record of the battle as the fight left it (the end's words mapped in apply).
static func _record(game: Game, battle: Battle, input: Dictionary, result: Dictionary, luck_before: int, id: int) -> BattleRecord:
	var rec := BattleRecord.new()
	rec.id = id
	rec.turn = game.turn
	rec.hex = battle.hex
	rec.name = battle.name
	rec.year = Calendar.year_of(game.turn, game.start_year)
	rec.attacker = battle.attacker
	rec.defender = battle.defender
	rec.input = BattleRecord.plain(input) as Dictionary
	rec.luck_before = luck_before
	rec.frames.assign(result["frames"])
	rec.end = (result["end"] as Dictionary).duplicate(true)
	return rec


## The side that lost (0 attacker, 1 defender), or -1 for a draw.
static func _loser_side(raw: Dictionary) -> int:
	var winner := int(raw["winner"])
	return 1 - winner if winner >= 0 else -1


## The defender's companies in the input (the garrison not counted): 0 means the garrison stood alone.
static func _field_count(input: Dictionary) -> int:
	var n := 0
	for f: Variant in input["fighters"] as Array:
		var fd := f as Dictionary
		if int(fd["side"]) == SIDE_DEFENDER and int(fd["key"]) != -1:
			n += 1
	return n


static func _tag_of(battle: Battle, side: int) -> StringName:
	return battle.attacker if side == SIDE_ATTACKER else battle.defender


## The armies of a side that still exist, in the order they came.
static func _side_armies(game: Game, battle: Battle, side: int) -> Array[Army]:
	var out: Array[Army] = []
	var found: Variant = battle.armies.get(String(_tag_of(battle, side)), PackedInt32Array())
	for n: Variant in found:
		var a := Armies.by_id(game, int(n))
		if a != null:
			out.append(a)
	return out


static func _unit_ids(army: Army) -> PackedInt32Array:
	var out := PackedInt32Array()
	for u: Unit in army.units:
		out.append(u.id)
	return out


## Each company loses the men the fight took from it (killed and wounded). A company at 0 leaves with unit_lost.
static func _book_fight_losses(game: Game, battle: Battle, end: Dictionary) -> void:
	var men: Dictionary = end["men"]
	for side: int in 2:
		for army: Army in _side_armies(game, battle, side):
			for uid: int in _unit_ids(army):
				var u := army.unit(uid)
				var after := int(men.get(uid, u.men))
				Armies.lose_unit_men(game, army, uid, u.men - after, &"battle")


# --- the beaten side -------------------------------------------------------------------------------------------------


## The retreat of the beaten side: its walk (Battles.retreat_path) when it has a spot; the walk is applied and [] is returned
## when it has none (the caller surrenders the side). A Withdraw (stance) goes only to its own land.
static func _beaten(game: Game, battle: Battle, loser: int, raw: Dictionary, end: Dictionary, retreat_fn: Callable,
		now: bool = false) -> Array:
	var armies := _side_armies(game, battle, loser)
	var own := str(raw["how"]) == "withdraw" and str(raw["cause"]) == "stance"
	var path: Array = retreat_fn.call(game, _tag_of(battle, loser), armies, battle.hex, own)
	if not path.is_empty():
		_retreat(game, battle, loser, armies, path, end, now)
	return path


## Every army of the beaten side walks to the spot (one unit_moved each, ticks after the battle's tick), halts (order none,
## halt_why defeated, march_halted) and is recorded in end.retreat. `now` is unit_moved's flag: true for the retreat of a battle
## fought at once (Battles.fight_now), so the replay lays it right after that battle's walk (R50).
static func _retreat(game: Game, battle: Battle, loser: int, armies: Array[Army], path: Array, end: Dictionary,
		now: bool = false) -> void:
	var tag := _tag_of(battle, loser)
	var spot: Vector2i = path.back()
	var text := "defeated at %s" % _text(game, battle.hex)
	var full: Array[Vector2i] = [battle.hex]
	for h: Variant in path:
		full.append(h as Vector2i)
	var ticks := PackedInt32Array()
	for k: int in path.size():
		ticks.append(battle.tick + k + 1)
	var witnessed := witnesses(game, spot, tag, tag)
	for army: Army in armies:
		Armies.set_hex(game, army, spot, army.hex)
		Armies.set_order(game, army, Army.ORDER_NONE, army.goal, army.route, army.via)
		Armies.set_halt(game, army, &"defeated", text)
		(end["retreat"] as Dictionary)[army.id] = spot
		game.emit({"kind": "unit_moved", "tag": tag, "army": army.id, "path": full, "ticks": ticks,
			"seen": _seen(game, tag, full), "witnesses": witnessed, "arrived": true, "why": &"retreat", "now": now})
		game.emit({"kind": "march_halted", "tag": tag, "army": army.id, "hex": spot, "why": "defeated", "reason": text,
			"waits": false, "witnesses": PackedStringArray([String(tag)]), "name": army.name})


## The seen flags of a walk: the player's own country sees all, else what the player sees of each hex.
static func _seen(game: Game, tag: StringName, hexes: Array[Vector2i]) -> PackedByteArray:
	var out := PackedByteArray()
	for h: Vector2i in hexes:
		out.append(1 if tag == game.player or Sight.sees(game, game.player, h) else 0)
	return out


## The beaten side surrenders: every company it has left is lost as surrendered and its men are booked as killed.
static func _surrender(game: Game, battle: Battle, loser: int, end: Dictionary) -> void:
	var killed: PackedInt32Array = end["killed"]
	var lost := PackedInt32Array()
	for army: Army in _side_armies(game, battle, loser):
		for uid: int in _unit_ids(army):
			var remaining := army.unit(uid).men
			killed[loser] = killed[loser] + remaining
			Armies.lose_unit_men(game, army, uid, remaining, &"surrendered")
			lost.append(uid)
	end["killed"] = killed
	end["surrendered"] = lost


## The wounded who return: half of each company's wounded, when its army ends in supply (4.6). Returned men are added through Armies.
static func _returns(game: Game, battle: Battle, end: Dictionary) -> void:
	var war := game.defs.war
	var winter := Calendar.is_winter(game.turn)
	var wounded: Dictionary = end["wounded"]
	var returned: Dictionary = end["returned"]
	for side: int in 2:
		for army: Army in _side_armies(game, battle, side):
			if not Supply.in_supply(game, army.tag, army.hex, winter):
				continue
			for uid: int in _unit_ids(army):
				var back := int(wounded.get(uid, 0)) * war.wounded_return_permille / 1000
				if back > 0:
					var added := Armies.add_men(game, army, uid, back)
					if added > 0:
						returned[uid] = added


## The surviving companies take their morale from the fight; the winner's gain xp_win experience, the loser's xp_lose (a draw none).
static func _morale_and_xp(game: Game, battle: Battle, end: Dictionary, loser: int) -> void:
	var war := game.defs.war
	var morale: Dictionary = end["morale"]
	var winner := -1 if loser < 0 else 1 - loser
	for side: int in 2:
		var xp := war.xp_win if side == winner else (war.xp_lose if side == loser else 0)
		for army: Army in _side_armies(game, battle, side):
			for uid: int in _unit_ids(army):
				Armies.set_morale(game, army, uid, int(morale.get(uid, army.unit(uid).morale)))
				if xp > 0:
					Armies.add_xp(game, army, uid, xp)


# --- the fortress (4.6 the storm, 4.4) -------------------------------------------------------------------------------


## The assault's fortress: stormed when the defender fell (it broke, was wiped out or surrendered) and its garrison has no men or
## no morale, or it stood alone; the attacker takes it (Occupation.capture, by storm) and its garrison is 0. Else the garrison keeps
## its uncut men (the storm's cut is not fought) and what its men left. Returns true when stormed.
static func _settle_fortress(game: Game, battle: Battle, end: Dictionary, raw: Dictionary, surrendered: bool,
		defender_field: int) -> bool:
	if not battle.assault:
		return false
	var garrison: Dictionary = end["garrison"]
	var men_after := int(garrison.get("men", 0))
	var morale := int(garrison.get("morale", 0))
	var how := str(raw["how"])
	var fell := int(raw["winner"]) == SIDE_ATTACKER and (how == "broke" or how == "wiped" or surrendered)
	var uncut := battle.storm_from - battle.storm_cut if battle.storm_cut > 0 else 0
	# The garrison's men the fight left are written first: a capture books the garrison it finds as lost, and the men the fight
	# killed or wounded are booked as battle losses already (each man counted once).
	Occupation.set_garrison(game, battle.hex, uncut + men_after)
	if fell and (men_after == 0 or morale == 0 or defender_field == 0):
		var opened := maxi(Occupation.members(game, battle.hex).size() - 1, 0)
		Occupation.capture(game, battle.hex, battle.attacker, &"storm",
			{"name": _text(game, battle.hex), "seasons": 0, "opened": opened})
		return true
	return false


# --- words and events ------------------------------------------------------------------------------------------------


## The spec's words for how the battle ended (battle_ended's `how`): broke, withdrew, surrendered, destroyed, gone.
static func _how_word(raw_how: String, winner: int, surrendered: bool) -> String:
	if surrendered:
		return SURRENDERED
	if raw_how == "broke":
		return "broke"
	if raw_how == "withdraw":
		return "withdrew"
	return "gone" if winner < 0 else "destroyed"


## The spec's cause: centre, lanes, morale, order (a Withdraw), cap (the day cap), or "" (none, a wipe-out).
static func _cause_word(raw_how: String, raw_cause: String) -> String:
	if raw_how == "wiped":
		return ""
	return str(CAUSE_WORDS.get(raw_cause, ""))


## battle_fought (the men and front morale of each side) and battle_ended (the war-goals contract, 3.4).
static func _events(game: Game, battle: Battle, rec: BattleRecord, retreat: Vector2i) -> void:
	var end := rec.end
	var killed: PackedInt32Array = end["killed"]
	var wounded: PackedInt32Array = end["wounded_total"]
	var front := PackedInt32Array([0, 0])
	if not rec.frames.is_empty():
		front = rec.frames[rec.frames.size() - 1]["front"] as PackedInt32Array
	var att := String(battle.attacker)
	var dfn := String(battle.defender)
	var seen_by := witnesses(game, battle.hex, battle.attacker, battle.defender)
	var winner := int(end["winner"])
	var winner_tag: StringName = battle.attacker if winner == SIDE_ATTACKER \
		else (battle.defender if winner == SIDE_DEFENDER else &"")
	var loser_tag: StringName = &""
	if winner >= 0:
		loser_tag = battle.defender if winner == SIDE_ATTACKER else battle.attacker
	game.emit({"kind": "battle_fought", "tag": battle.attacker, "hex": battle.hex, "others": [battle.defender],
		"days": int(end["days"]), "killed": {att: killed[0], dfn: killed[1]}, "wounded": {att: wounded[0], dfn: wounded[1]},
		"morale": {att: maxi(front[0], 0), dfn: maxi(front[1], 0)}, "witnesses": seen_by})
	game.emit({"kind": "battle_ended", "tag": battle.attacker, "hex": battle.hex, "others": [battle.defender],
		"attacker": battle.attacker, "defender": battle.defender, "winner": winner_tag, "loser": loser_tag,
		"assault": battle.assault, "how": str(end["how"]), "cause": str(end["cause"]), "seasons": 1,
		"days": int(end["days"]), "name": battle.name, "year": rec.year, "killed": {att: killed[0], dfn: killed[1]},
		"wounded": {att: wounded[0], dfn: wounded[1]}, "retreat": retreat, "record": rec.id,
		"stormed": bool(end["stormed"]), "witnesses": seen_by})


## A battle ended by a peace (Battles.end_all): no day, no pursuit, no xp. Its armies keep their hexes, with orders none, and
## battle_ended is queued as a draw (how peace, winner and loser empty, record -1, nothing killed or wounded).
static func peace(game: Game, battle: Battle) -> void:
	for side: int in 2:
		for army: Army in _side_armies(game, battle, side):
			Armies.set_order(game, army, Army.ORDER_NONE, army.goal, army.route, army.via)
	var seen_by := witnesses(game, battle.hex, battle.attacker, battle.defender)
	var none := {String(battle.attacker): 0, String(battle.defender): 0}
	game.emit({"kind": "battle_ended", "tag": battle.attacker, "hex": battle.hex, "others": [battle.defender],
		"attacker": battle.attacker, "defender": battle.defender, "winner": &"", "loser": &"", "assault": battle.assault,
		"how": "peace", "cause": "", "seasons": 1, "days": 0, "name": battle.name,
		"year": Calendar.year_of(game.turn, game.start_year), "killed": none, "wounded": none,
		"retreat": Army.NO_HEX, "record": -1, "stormed": false, "witnesses": seen_by})


static func _text(game: Game, hex: Vector2i) -> String:
	var name := str(Improve.place_of(game.map, hex).get("name", ""))
	var coords := "(%d, %d)" % [hex.x, hex.y]
	return "%s %s" % [name, coords] if name != "" else coords
