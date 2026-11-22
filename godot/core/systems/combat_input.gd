## The input of one battle (docs/architecture/m7-build-spec.md 5.3, Combat): the plain snapshot that Battles builds from the live
## state, checked by validate(), and the working state CombatState that Combat fights it with. The input is read, never
## written: fight never changes it, so the record keeps it as it was given. Every type is checked before its value is used:
## a hostile snapshot gives messages from validate() and never an error. Pure.
class_name CombatInput
extends RefCounted

const KEYS: Array[String] = ["attacker", "defender", "assault", "ground", "crossing", "uphill", "river", "stance",
		"can_retreat", "fighters", "garrison"]
const FIGHTER_KEYS: Array[String] = ["key", "side", "branch", "men", "full", "attack", "defence", "fire", "rank", "morale",
		"hungry"]
const GROUND_KEYS: Array[String] = ["defence", "relief", "rough", "narrow", "key", "elevation"]
## The most men a company or a garrison holds (WarDef.MAX_COUNT): keeps every product of a hit inside 64 bits.
const MAX_MEN := WarDef.MAX_COUNT
## The most defence of a ground: a cover's 1,000 plus the highest relief addition (WarDef.relief_defence_add, 500).
const MAX_GROUND_DEFENCE := 1500


## Problems found in an input, empty when it is valid. Each value's type is checked before any use of it, so a bad input
## gives a message and never an error.
static func validate(war: WarDef, input: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in KEYS:
		if not input.has(key):
			errors.append("input: no '%s'" % key)
	if not errors.is_empty():
		return errors
	_check_tags(errors, input["attacker"], input["defender"])
	_check_flag(errors, input["assault"], "assault")
	for flag: String in ["crossing", "uphill", "river"]:
		_check_flag(errors, input[flag], flag)
	var assault: bool = typeof(input["assault"]) == TYPE_BOOL and bool(input["assault"])
	_check_ground(errors, input["ground"])
	_check_stance(errors, input["stance"], input["can_retreat"])
	_check_fighters(errors, war, input["fighters"], assault)
	_check_garrison(errors, war, input["garrison"], assault)
	return errors


static func _check_tags(errors: Array[String], attacker: Variant, defender: Variant) -> void:
	if typeof(attacker) != TYPE_STRING or typeof(defender) != TYPE_STRING:
		errors.append("input: attacker and defender must be tags (text)")
	elif str(attacker) == str(defender):
		errors.append("input: attacker and defender are the same tag")


static func _check_flag(errors: Array[String], value: Variant, name: String) -> void:
	if typeof(value) != TYPE_BOOL:
		errors.append("input: %s must be a bool" % name)


static func _check_ground(errors: Array[String], value: Variant) -> void:
	if not (value is Dictionary):
		errors.append("input: ground must be a dictionary")
		return
	var g: Dictionary = value
	for key: String in GROUND_KEYS:
		if not g.has(key):
			errors.append("input: ground has no '%s'" % key)
			return
	if typeof(g["defence"]) != TYPE_INT or int(g["defence"]) < 0 or int(g["defence"]) > MAX_GROUND_DEFENCE:
		errors.append("input: ground defence must be 0 to %d" % MAX_GROUND_DEFENCE)
	if typeof(g["relief"]) != TYPE_INT or int(g["relief"]) < 0 or int(g["relief"]) > WarDef.RELIEF_LEVELS - 1:
		errors.append("input: ground relief must be 0 to %d" % (WarDef.RELIEF_LEVELS - 1))
	_check_flag(errors, g["rough"], "ground rough")
	_check_flag(errors, g["narrow"], "ground narrow")
	if typeof(g["key"]) != TYPE_STRING:
		errors.append("input: ground key must be text")


static func _check_stance(errors: Array[String], stance: Variant, retreat: Variant) -> void:
	if not (stance is Dictionary) or not (retreat is Dictionary):
		errors.append("input: stance and can_retreat must be dictionaries")
		return
	var st: Dictionary = stance
	var rt: Dictionary = retreat
	for side: String in ["att", "def"]:
		if not st.has(side) or not rt.has(side):
			errors.append("input: stance and can_retreat need '%s'" % side)
			continue
		if typeof(st[side]) != TYPE_STRING or not ["attack", "hold", "withdraw"].has(str(st[side])):
			errors.append("input: stance %s must be attack, hold or withdraw" % side)
		_check_flag(errors, rt[side], "can_retreat %s" % side)


static func _check_fighters(errors: Array[String], war: WarDef, value: Variant, assault: bool) -> void:
	if not (value is Array):
		errors.append("input: fighters must be a list")
		return
	var seen: Dictionary = {}
	var sides: Array = [0, 0]
	for raw: Variant in value as Array:
		if not (raw is Dictionary):
			errors.append("input: a fighter is not a dictionary")
			continue
		var f: Dictionary = raw
		var missing: bool = false
		for key: String in FIGHTER_KEYS:
			if not f.has(key):
				errors.append("input: a fighter has no '%s'" % key)
				missing = true
		if missing:
			continue
		_check_fighter(errors, war, f, seen, sides)
	if assault and int(sides[0]) == 0 and int(sides[1]) == 0:
		errors.append("input: a battle with no fighter")


static func _check_fighter(errors: Array[String], war: WarDef, f: Dictionary, seen: Dictionary, sides: Array) -> void:
	var key: Variant = f["key"]
	if typeof(key) != TYPE_INT or int(key) < 0 or seen.has(int(key)):
		errors.append("input: a fighter key must be a unique whole number from 0")
		return
	seen[int(key)] = true
	var label: String = str(key)
	var side: Variant = f["side"]
	if typeof(side) != TYPE_INT or (int(side) != 0 and int(side) != 1):
		errors.append("input: fighter %s side must be 0 or 1" % label)
		return
	sides[int(side)] = int(sides[int(side)]) + 1
	if typeof(f["branch"]) != TYPE_STRING or not WarDef.BRANCHES.has(StringName(str(f["branch"]))):
		errors.append("input: fighter %s branch is unknown" % label)
	for n: String in ["men", "full"]:
		if typeof(f[n]) != TYPE_INT or int(f[n]) < 0 or int(f[n]) > MAX_MEN:
			errors.append("input: fighter %s %s must be from 0 to %d" % [label, n, MAX_MEN])
	if typeof(f["men"]) == TYPE_INT and typeof(f["full"]) == TYPE_INT and int(f["men"]) > int(f["full"]):
		errors.append("input: fighter %s has more men than full" % label)
	if typeof(f["fire"]) != TYPE_INT or int(f["fire"]) < 0 or int(f["fire"]) > WarDef.MAX_PERMILLE:
		errors.append("input: fighter %s fire must be from 0 to %d" % [label, WarDef.MAX_PERMILLE])
	for n: String in ["attack", "defence"]:
		if typeof(f[n]) != TYPE_INT or int(f[n]) < 1 or int(f[n]) > 20:
			errors.append("input: fighter %s %s must be 1 to 20" % [label, n])
	if typeof(f["rank"]) != TYPE_INT or int(f["rank"]) < 0 or int(f["rank"]) > WarDef.RANK_COUNT - 1:
		errors.append("input: fighter %s rank must be 0 to %d" % [label, WarDef.RANK_COUNT - 1])
	if typeof(f["morale"]) != TYPE_INT or int(f["morale"]) < 0 or int(f["morale"]) > 1000:
		errors.append("input: fighter %s morale must be 0 to 1000" % label)
	_check_flag(errors, f["hungry"], "fighter %s hungry" % label)


static func _check_garrison(errors: Array[String], war: WarDef, value: Variant, assault: bool) -> void:
	if not (value is Dictionary):
		errors.append("input: garrison must be a dictionary")
		return
	var g: Dictionary = value
	if g.is_empty():
		return
	for n: String in ["men", "full", "level"]:
		if not g.has(n) or typeof(g[n]) != TYPE_INT:
			errors.append("input: garrison needs a whole '%s'" % n)
			return
	if int(g["level"]) < 1 or int(g["level"]) > WarDef.FORTRESS_LEVELS - 1:
		errors.append("input: garrison level must be 1 to %d" % (WarDef.FORTRESS_LEVELS - 1))
	for n: String in ["men", "full"]:
		if int(g[n]) < 0 or int(g[n]) > MAX_MEN:
			errors.append("input: garrison %s must be from 0 to %d" % [n, MAX_MEN])
	if int(g["men"]) > int(g["full"]):
		errors.append("input: garrison men must be from 0 to its full")
	if g.has("morale") and (typeof(g["morale"]) != TYPE_INT or int(g["morale"]) < 0 or int(g["morale"]) > 1000):
		errors.append("input: garrison morale must be a whole number from 0 to 1000")
	if not assault:
		errors.append("input: a garrison is only in an assault")


## The working state of a battle from its input (the input is only read). Call validate first.
static func state(war: WarDef, input: Dictionary, rng: Rng) -> CombatState:
	var st := CombatState.new()
	st.war = war
	st.rng = rng
	st.tags = PackedStringArray([str(input["attacker"]), str(input["defender"])])
	st.assault = bool(input["assault"])
	st.ground = input["ground"]
	st.crossing = bool(input["crossing"])
	st.uphill = bool(input["uphill"])
	st.river = bool(input["river"])
	var sd: Dictionary = input["stance"]
	var rt: Dictionary = input["can_retreat"]
	for side: int in 2:
		var side_name: String = "att" if side == 0 else "def"
		st.can_retreat[side] = bool(rt[side_name])
		var s: String = str(sd[side_name])
		if s == "withdraw" and not bool(rt[side_name]):
			s = "hold"
		st.stance[side] = s
	for raw: Variant in input["fighters"] as Array:
		_add(st, raw as Dictionary)
	var g: Dictionary = input["garrison"]
	if st.assault and not g.is_empty():
		var level: int = int(g["level"])
		st.castle_level = level
		_add(st, {
			"key": CombatState.GARRISON, "side": 1, "branch": "infantry", "men": int(g["men"]), "full": int(g["full"]),
			"attack": war.garrison_attack, "defence": war.garrison_defence + war.garrison_defence_per_level * level,
			"fire": 0, "rank": 0, "morale": int(g.get("morale", 1000)), "hungry": false,
		})
	st.lanes = [[CombatState.EMPTY, CombatState.EMPTY, CombatState.EMPTY],
			[CombatState.EMPTY, CombatState.EMPTY, CombatState.EMPTY]]
	st.held = [[0, 0, 0], [0, 0, 0]]
	st.broken = [[], []]
	return st


static func _add(st: CombatState, raw: Dictionary) -> void:
	var f: Dictionary = {
		"key": int(raw["key"]), "side": int(raw["side"]), "branch": str(raw["branch"]), "men": int(raw["men"]),
		"full": int(raw["full"]), "attack": int(raw["attack"]), "defence": int(raw["defence"]),
		"fire": int(raw["fire"]), "rank": int(raw["rank"]), "morale": int(raw["morale"]),
		"hungry": bool(raw["hungry"]),
	}
	st.index[int(f["key"])] = st.fighters.size()
	st.fighters.append(f)
