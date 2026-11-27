## The seeded random player (docs/architecture/m6-build-spec.md section 9, L13; M1 to M6's actions). `next` picks one name of
## Actions.NAMES and its arguments from the state of a country, so that refusals and successes both occur. It goes through
## the same door as a player (Game.check and Game.act in the tests); it never changes the game itself. Deterministic: the
## same game, tag and Rng state give the same pick. Tests only: no engine calls, no autoload.
##   next(game, tag, luck) -> {action, args}
## The argument shapes are those of Actions: build {hex, family, tag}, upgrade and clear and cancel_work {hex, tag},
## choose_country {tag}, set_tax {level, tag}, raise {hex, kind, count, tag}, split_army {army, units, tag},
## merge_armies {army, into, tag}, disband {army, unit, tag}, march {army, goal, tag}, halt and continue_march {army, tag},
## storm {army, goal, tag}, set_standing {army, standing, tag}. MV19: with `stops`, a march now and then carries `via` (one to
## three stops: near land, any land, the army's own hex or the stop before it again), so refusals and successes both occur.
class_name RandomPlayer
extends RefCounted

## Land hexes tried for a random pick before a random one is taken as it is.
const TRIES := 12
## A goal this close to the army is "near"; any other is "far".
const NEAR := 5
## One pick in this many aims at another country's army or hex (refusals then happen too).
const STRAY := 8
## Moves in the month (moves-build-spec.md 8.2, MV4): the orders whose do half now walks at once, picked more often when `next` is
## asked with `moves` (one pick in MOVES_EVERY is one of them); without it the stream is the one of before.
const MOVES: Array[String] = ["continue_march", "storm"]
const MOVES_EVERY := 4


## One random action for `tag`: {action, args}. Changes nothing. `moves` weights Continue and storm up (MOVES); `stops` gives some
## marches stops (MV19). Without them the stream is the one of before.
static func next(game: Game, tag: StringName, luck: Rng, moves: bool = false, stops: bool = false) -> Dictionary:
	var names := Actions.NAMES
	var action := names[luck.randi_range(0, names.size() - 1)]
	if moves and luck.randi_range(0, MOVES_EVERY - 1) == 0:
		action = MOVES[luck.randi_range(0, MOVES.size() - 1)]
	if stops and action == "march":
		return {"action": action, "args": _via_args(game, tag, luck)}
	return {"action": action, "args": _args(game, tag, action, luck)}


static func _args(game: Game, tag: StringName, action: String, luck: Rng) -> Dictionary:
	match action:
		"build":
			return _build_args(game, tag, luck)
		"upgrade", "clear", "cancel_work":
			return {"hex": _hex_of_land(game, tag, luck), "tag": tag}
		"choose_country":
			return {"tag": _any_tag(game, tag, luck)}
		"set_tax":
			return {"level": luck.randi_range(0, 2), "tag": tag}
		"raise":
			return _raise_args(game, tag, luck)
		"split_army":
			return _split_args(game, tag, luck)
		"merge_armies":
			return _merge_args(game, tag, luck)
		"disband":
			return _disband_args(game, tag, luck)
		"march":
			return _march_args(game, tag, luck)
		"halt":
			return {"army": _army_id(game, tag, luck), "tag": tag}
		"continue_march":
			return {"army": _halted_id(game, tag, luck), "tag": tag}
		"declare_war":
			return _war_args(game, tag, luck)
		"make_peace":
			return _peace_args(game, tag, luck)
		"storm":
			return _storm_args(game, tag, luck)
		"set_standing":
			return {"army": _army_id(game, tag, luck), "standing": _standing(luck), "tag": tag}
	return {}


## A fortress of the game (most picks: a storm's goal; a hostile one, held by a country at war with the country, first) or
## any land hex.
static func _fortress_or_land(game: Game, tag: StringName, luck: Rng) -> Vector2i:
	var forts := game.war_cache.fortresses(game)
	var hostile: Array[int] = []
	for i: int in forts:
		var ctl := Occupation.controller_tag(game, game.map.hex_of(i))
		if ctl != &"" and ctl != tag and Wars.at_war(game, tag, ctl):
			hostile.append(i)
	if not hostile.is_empty() and luck.randi_range(0, STRAY - 1) != 0:
		return game.map.hex_of(hostile[luck.randi_range(0, hostile.size() - 1)])
	if not forts.is_empty() and luck.randi_range(0, STRAY - 1) != 0:
		return game.map.hex_of(forts[luck.randi_range(0, forts.size() - 1)])
	return _any_land(game, luck)


## A standing order: hold or withdraw, or none now and then (refused).
static func _standing(luck: Rng) -> String:
	var words := ["hold", "withdraw", ""]
	return words[luck.randi_range(0, words.size() - 1)]


## A declaration of war: a neighbour of the country half the time (a declaration that can succeed), else any country.
static func _war_args(game: Game, tag: StringName, luck: Rng) -> Dictionary:
	var target := _any_tag(game, tag, luck)
	var c := Countries.by_tag(game, tag)
	if c != null and luck.randi_range(0, 1) == 0:
		var around := Territory.neighbours(game, c.id)
		if not around.is_empty():
			var near := Countries.by_id(game, around[luck.randi_range(0, around.size() - 1)])
			if near != null:
				target = near.tag
	return {"target": target, "tag": tag}


## A peace with one of the country's enemies half the time (a peace that can be made), else any country; the terms at random.
static func _peace_args(game: Game, tag: StringName, luck: Rng) -> Dictionary:
	var target := _any_tag(game, tag, luck)
	var foes := Wars.enemies(game, tag)
	if not foes.is_empty() and luck.randi_range(0, 1) == 0:
		target = foes[luck.randi_range(0, foes.size() - 1)]
	var terms := ["take", "white", "yield"]
	return {"target": target, "terms": terms[luck.randi_range(0, 2)], "tag": tag}


## A halted march of the country (order none, its goal kept: movement.gd halt), most picks, so that continue_march
## succeeds now and then; else any army's id.
static func _halted_id(game: Game, tag: StringName, luck: Rng) -> int:
	var halted: Array[Army] = []
	for a: Army in Armies.of_country(game, tag):
		if a.order == Army.ORDER_NONE and a.goal != Army.NO_HEX:
			halted.append(a)
	if not halted.is_empty() and luck.randi_range(0, STRAY - 1) != 0:
		return halted[luck.randi_range(0, halted.size() - 1)].id
	return _army_id(game, tag, luck)


## A works action on a hex of the country's land (or any hex, now and then), with a family it could build when one exists.
static func _build_args(game: Game, tag: StringName, luck: Rng) -> Dictionary:
	var hex := _hex_of_land(game, tag, luck)
	var family := ImproveRules.WHEAT
	var options: Array[Dictionary] = []
	for o: Dictionary in game.improvement.build_options(hex):
		if bool(o["ok"]):
			options.append(o)
	if not options.is_empty():
		family = int(options[luck.randi_range(0, options.size() - 1)]["family_id"])
	return {"hex": hex, "family": family, "tag": tag}


## A raise at a settlement of the country's land (most picks) or at any hex; a kind and 1 to 4 companies.
static func _raise_args(game: Game, tag: StringName, luck: Rng) -> Dictionary:
	var hex := _hex_of_land(game, tag, luck)
	if luck.randi_range(0, 3) == 0:
		hex = _any_land(game, luck)
	var kinds := maxi(game.defs.units.size(), 1)
	return {"hex": hex, "kind": luck.randi_range(0, kinds - 1), "count": luck.randi_range(1, 4), "tag": tag}


## A split of one of the country's armies: a random set of its companies (sometimes none, sometimes a stray id).
static func _split_args(game: Game, tag: StringName, luck: Rng) -> Dictionary:
	var army := _army_of(game, tag, luck)
	var ids := PackedInt32Array()
	if army != null:
		var pool := PackedInt32Array()
		for u: Unit in army.units:
			pool.append(u.id)
		var take := luck.randi_range(0, pool.size())
		for _k: int in take:
			ids.append(pool[luck.randi_range(0, pool.size() - 1)])
	if luck.randi_range(0, 9) == 0:
		ids.append(-7)
	return {"army": _army_id_of(army), "units": ids, "tag": tag}


## A merge of two armies (of the country, or one stray), the second joining the first.
static func _merge_args(game: Game, tag: StringName, luck: Rng) -> Dictionary:
	var first := _army_of(game, tag, luck)
	var second := _army_of(game, tag, luck)
	if first != null and luck.randi_range(0, STRAY - 1) != 0:
		# Most picks join an army of the country on the same hex (a merge that is allowed), when there is one.
		var same: Array[Army] = []
		for a: Army in Armies.at(game, first.hex):
			if a.tag == tag and a.id != first.id:
				same.append(a)
		if not same.is_empty():
			second = same[luck.randi_range(0, same.size() - 1)]
	return {"army": _army_id_of(first), "into": _army_id_of(second), "tag": tag}


## A disband of one company, or of the whole army (unit -1), of one of the country's armies.
static func _disband_args(game: Game, tag: StringName, luck: Rng) -> Dictionary:
	var army := _army_of(game, tag, luck)
	var unit := -1
	if army != null and not army.units.is_empty() and luck.randi_range(0, 2) == 0:
		unit = army.units[luck.randi_range(0, army.units.size() - 1)].id
	return {"army": _army_id_of(army), "unit": unit, "tag": tag}


## A march of one of the country's armies: to a hex of its land, near it or far; sometimes any land hex; now and then an
## attack on a hex of a country at war with it (M7: an enemy army's hex, or the land of the enemy).
static func _march_args(game: Game, tag: StringName, luck: Rng) -> Dictionary:
	var army := _army_of(game, tag, luck)
	var goal := _hex_of_land(game, tag, luck)
	if army != null and luck.randi_range(0, 1) == 0:
		goal = _near_land(game, army.hex, luck)
	elif luck.randi_range(0, 2) == 0:
		goal = _enemy_hex(game, tag, luck)
	return {"army": _army_id_of(army), "goal": goal, "tag": tag}


## A march with stops (MV19, R63): the march of _march_args, half of the time with one to three stops.
static func _via_args(game: Game, tag: StringName, luck: Rng) -> Dictionary:
	var args := _march_args(game, tag, luck)
	var army := Armies.by_id(game, int(args["army"]))
	if army == null or luck.randi_range(0, 1) == 0:
		return args
	var via: Array[Vector2i] = []
	for _k: int in luck.randi_range(1, 3):
		match luck.randi_range(0, 5):
			0:
				via.append(army.hex)
			1:
				via.append(via.back() if not via.is_empty() else _any_land(game, luck))
			2:
				via.append(_any_land(game, luck))
			_:
				via.append(_near_land(game, army.hex, luck))
	args["via"] = via
	return args


## A hex of a country at war with tag (its land, a district picked at random), or any land hex when it is at war with none.
static func _enemy_hex(game: Game, tag: StringName, luck: Rng) -> Vector2i:
	var fort := _hostile_fortress(game, tag, luck)
	if fort != Movement.NO_HEX and luck.randi_range(0, 1) == 0:
		return fort
	var foes := Wars.enemies(game, tag)
	if foes.is_empty():
		return _any_land(game, luck)
	var foe := Countries.by_tag(game, foes[luck.randi_range(0, foes.size() - 1)])
	if foe == null:
		return _any_land(game, luck)
	var land := Territory.districts(game, foe.id)
	if land.is_empty():
		return _any_land(game, luck)
	return game.map.hex_of(land[luck.randi_range(0, land.size() - 1)])


## A hostile garrisoned fortress (held by a country at war with tag, with men in it): a siege's goal, picked at random; NO_HEX
## when there is none.
static func _hostile_fortress(game: Game, tag: StringName, luck: Rng) -> Vector2i:
	var list: Array[Vector2i] = []
	for i: int in game.war_cache.fortresses(game):
		var h := game.map.hex_of(i)
		if Occupation.garrison_of(game, h) > 0 and Wars.at_war(game, tag, Occupation.controller_tag(game, h)):
			list.append(h)
	if list.is_empty():
		return Movement.NO_HEX
	return list[luck.randi_range(0, list.size() - 1)]


## A storm: a fortress (a hostile one most picks; M7), and an army of the country near it when there is one (most picks), else
## a random army of the country's.
static func _storm_args(game: Game, tag: StringName, luck: Rng) -> Dictionary:
	var goal := _fortress_or_land(game, tag, luck)
	var army := _army_of(game, tag, luck)
	var near: Array[Army] = []
	for a: Army in Armies.of_country(game, tag):
		if a.hex != goal and ImproveRules.hex_distance(a.hex, goal) <= NEAR:
			near.append(a)
	if not near.is_empty() and luck.randi_range(0, STRAY - 1) != 0:
		army = near[luck.randi_range(0, near.size() - 1)]
	return {"army": _army_id_of(army), "goal": goal, "tag": tag}


## One of the country's armies, or (one pick in STRAY) any army of the game; null when there are none.
static func _army_of(game: Game, tag: StringName, luck: Rng) -> Army:
	var own := Armies.of_country(game, tag)
	if game.armies.is_empty():
		return null
	if not own.is_empty() and luck.randi_range(0, STRAY - 1) != 0:
		return own[luck.randi_range(0, own.size() - 1)]
	return game.armies[luck.randi_range(0, game.armies.size() - 1)]


## An army id of the country, or a stray id (0) when it has none.
static func _army_id(game: Game, tag: StringName, luck: Rng) -> int:
	return _army_id_of(_army_of(game, tag, luck))


static func _army_id_of(army: Army) -> int:
	return army.id if army != null else 0


## A land hex of the country: one of its own districts, or any land hex when it has none (or one pick in STRAY).
static func _hex_of_land(game: Game, tag: StringName, luck: Rng) -> Vector2i:
	var c := Countries.by_tag(game, tag)
	if c != null and luck.randi_range(0, STRAY - 1) != 0:
		var land := Territory.districts(game, c.id)
		if not land.is_empty():
			return game.map.hex_of(land[luck.randi_range(0, land.size() - 1)])
	return _any_land(game, luck)


## A land hex of the map, at random (a few tries; then the last one drawn, which may be sea).
static func _any_land(game: Game, luck: Rng) -> Vector2i:
	var hex := game.map.hex_of(0)
	for _t: int in TRIES:
		hex = game.map.hex_of(luck.randi_range(0, game.map.hex_count() - 1))
		if game.map.is_land(hex):
			return hex
	return hex


## A land hex within NEAR of `from` when one is found in a few tries, else any land hex.
static func _near_land(game: Game, from: Vector2i, luck: Rng) -> Vector2i:
	for _t: int in TRIES:
		var hex := game.map.hex_of(luck.randi_range(0, game.map.hex_count() - 1))
		if game.map.is_land(hex) and ImproveRules.hex_distance(hex, from) <= NEAR and hex != from:
			return hex
	return _any_land(game, luck)


## A country tag: the player's own, or another one (for choose_country, which refuses a country already taken).
static func _any_tag(game: Game, tag: StringName, luck: Rng) -> StringName:
	if game.countries.is_empty() or luck.randi_range(0, 1) == 0:
		return tag
	return game.countries[luck.randi_range(0, game.countries.size() - 1)].tag
