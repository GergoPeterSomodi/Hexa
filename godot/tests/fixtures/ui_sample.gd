## The war sample of the M7 pictures (docs/architecture/m7-build-spec.md 9; tools/ui/shot_ui_m7.gd): a Savoy game (seed 1480) put
## into a war with Milan, made the way a player and the rules would leave it: Milan's army at Alessandria and Savoy's at Vercelli
## (raised through the door), the war declared through the door, two battle records of last season (one Savoy won at Alessandria,
## one Savoy lost at Vercelli: found by a luck seed, both read in full by Savoy), a siege of Pavia with Savoy's army before it,
## and a Milanese district held by Savoy. The records, the siege and the district are written straight into the game (a rig
## for the pictures, as the monkey plants a record): after it the caller refreshes the map's war layer. The session is passed in
## (a tool script compiles before the autoloads, so no autoload is named here).
class_name UiSample
extends RefCounted

const SAV := &"SAV"
const MLO := &"MLO"
const VERCELLI := Vector2i(6, 9)
const ALESS := Vector2i(7, 9)
const PAVIA := Vector2i(10, 9)
const SEARCH := 400
const DEV_MONEY := 100000
const DEV_IRON := 40


## Makes the sample in the running Savoy game `g` through `session` (the Session autoload). Returns {ok, savoy_army, milan_army,
## siege_army, won (record id), lost (record id), siege (the hex), occupied (the hex), area (a Milanese hex in a castle
## area that stands: the hex of the "held" odds card)}; ok is false (and says why in `problem`)
## when a part did not come up.
static func war(session: Object, g: Game) -> Dictionary:
	var out := {"ok": false, "problem": "", "savoy_army": -1, "milan_army": -1, "siege_army": -1, "won": -1, "lost": -1,
		"siege": PAVIA, "occupied": Vector2i(-1, -1), "area": Vector2i(-1, -1)}
	session.call("dev_money", SAV, DEV_MONEY - Countries.by_tag(g, SAV).treasury)
	var iron := g.defs.good_id(&"iron")
	session.call("dev_goods", SAV, iron, DEV_IRON - Countries.by_tag(g, SAV).stock[iron])
	var kind := _pikemen(g)
	var milan := session.call("act", "raise", {"hex": ALESS, "kind": kind, "count": 2, "tag": MLO}) as Dictionary
	if not bool(milan.get("ok", false)):
		out["problem"] = "Milan's raise was refused: %s" % str(milan.get("reason", ""))
		return out
	var declared := session.call("act", "declare_war", {"target": MLO}) as Dictionary
	if not bool(declared.get("ok", false)):
		out["problem"] = "the declaration was refused: %s" % str(declared.get("reason", ""))
		return out
	var savoy := session.call("act", "raise", {"hex": VERCELLI, "kind": kind, "count": 2}) as Dictionary
	if not bool(savoy.get("ok", false)):
		out["problem"] = "Savoy's raise was refused: %s" % str(savoy.get("reason", ""))
		return out
	for a: Army in Armies.at(g, VERCELLI):
		out["savoy_army"] = a.id
	for a: Army in Armies.at(g, ALESS):
		out["milan_army"] = a.id
	var besieger := ArmyFixture.army(g, SAV, PAVIA, 0, 4)
	besieger.name = "Army of Pavia"
	out["siege_army"] = besieger.id
	out["won"] = _record(g, SAV, MLO, ALESS, "Battle of Alessandria, 1480", true)
	out["lost"] = _record(g, MLO, SAV, VERCELLI, "Battle of Vercelli, 1480", false)
	_siege(g)
	var held := _held_hex(g)
	if held.x >= 0:
		Occupation.capture(g, held, SAV, &"walk", {})
		out["occupied"] = held
	out["area"] = _area_hex(g)
	Sight.refresh(g)  # the armies placed in the rig see their surroundings (the vision phase has not run)
	g.version += 1
	out["ok"] = int(out["savoy_army"]) >= 0 and int(out["milan_army"]) >= 0 and int(out["won"]) >= 0 and int(out["lost"]) >= 0 \
		and held.x >= 0 and (out["area"] as Vector2i).x >= 0
	if not bool(out["ok"]):
		out["problem"] = "a part of the sample is missing: %s" % str(out)
	return out


## The id of the pikemen unit kind.
static func _pikemen(g: Game) -> int:
	for unit: UnitDef in g.defs.units:
		if unit.key == &"pikemen":
			return unit.id
	return 0


## A battle record of last season on `hex`, kept in the game and read in full by Savoy: the attacker's three companies of
## pikemen against the defender's pikemen and, when `horse`, knights; the luck seed is searched from 1 until the attacker wins.
## Returns the record's id, -1 when no seed gave it.
static func _record(g: Game, attacker: StringName, defender: StringName, hex: Vector2i, name: String, horse: bool) -> int:
	var war := CombatFixture.war()
	for seed_value: int in range(1, SEARCH):
		var fighters := [CombatFixture.pikemen(101, 0), CombatFixture.pikemen(102, 0), CombatFixture.pikemen(103, 0),
			CombatFixture.pikemen(201, 1)]
		if horse:
			fighters.append(CombatFixture.knights(202, 1))
		for f: Dictionary in fighters:
			for ud: UnitDef in g.defs.units:
				if String(ud.branch) == str(f["branch"]):
					f["kind"] = ud.id
					break
			f["army"] = 1 if int(f["side"]) == 0 else 2
		var input := CombatFixture.input_of(war, fighters, 0, false, false)
		input["attacker"] = String(attacker)
		input["defender"] = String(defender)
		var rec := CombatFixture.record_of(war, input, seed_value)
		if int(rec.end.get("winner", -1)) == 0:
			return _kept(g, rec, attacker, defender, hex, name).id
	return -1


## The record given its place in the game: the next id, last season, Savoy among its witnesses; appended.
static func _kept(g: Game, rec: BattleRecord, attacker: StringName, defender: StringName, hex: Vector2i, name: String) -> BattleRecord:
	rec.id = g.next_record_id
	g.next_record_id += 1
	rec.turn = g.turn - 1
	rec.hex = hex
	rec.name = name
	rec.year = g.start_year
	rec.attacker = attacker
	rec.defender = defender
	rec.witnesses = PackedStringArray([String(SAV)])
	g.battle_records.append(rec)
	return rec


## The siege of Pavia: two seasons in, three points of the fortress's need.
static func _siege(g: Game) -> void:
	var s := Siege.new()
	s.hex = PAVIA
	s.besieger = SAV
	s.progress = 3
	s.seasons = 2
	s.name = "Siege of Pavia, 1480"
	s.started_turn = g.turn
	g.sieges.append(s)


## A land district of Milan beside Alessandria that is not a fortress (the one Savoy holds); (-1, -1) when none.
static func _held_hex(g: Game) -> Vector2i:
	for d: int in 6:
		var beside := g.map.neighbour(ALESS, d)
		if g.map.has(beside) and g.map.is_land(beside) and Territory.owner_tag(g, beside) == MLO \
				and Occupation.fortress_level(g, beside) == 0 and Armies.at(g, beside).is_empty():
			return beside
	return Vector2i(-1, -1)


## A land hex of Milan's that Savoy sees, free of armies and not occupied, in the area of a castle that stands (the area state
## "held"): the first by hex index; (-1, -1) when none.
static func _area_hex(g: Game) -> Vector2i:
	var standing := Occupation.standing(g)
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 1 and Territory.owner_tag(g, hex) == MLO and Armies.at(g, hex).is_empty() 				and Occupation.area_state(g, hex, standing) == &"held" and Knowledge.sees(g, SAV, hex):
			return hex
	return Vector2i(-1, -1)
