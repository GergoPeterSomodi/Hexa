## The retreat walk of a beaten side (docs/architecture/m7-build-spec.md 4.6, the end; M7 plan B8): where its armies go when a
## battle ends: the walk over the map within retreat_range (blocked and closed edges, winter), the room of the side and the land
## rule. Split from battles.gd for size. Reads only. It references no Battles function, so the two files need not parse each
## other. Integer maths; no engine calls.
class_name BattleRetreat
extends RefCounted



## The walk of a side's armies to its retreat spot: the hexes after hex, the last one the spot; [] when there is none. Within
## retreat_range steps over edges the map does not block or close (winter's closed passes too), never through or into a hex of an
## enemy army or a hostile garrisoned fortress, and with room for the whole side. own_only (a Withdraw) allows only land the side's
## country controls; else its own or unowned land, or land of a country at war with it, its controlled land first. Nearest by steps,
## then farthest from the nearest enemy army, then the lowest index.
static func retreat_path(game: Game, tag: StringName, armies: Array[Army], hex: Vector2i, own_only: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var reach := reach_of(game, tag, armies, hex)
	if reach.is_empty():
		return out
	var leaving := _ids_of(armies)
	var total := _companies(armies)
	var steps: Dictionary = reach["steps"]
	var foes: Dictionary = reach["foes"]
	var best := -1
	var best_rank := PackedInt32Array()
	for key: Variant in steps:
		var i := int(key)
		var step := int(steps[key])
		var spot := game.map.hex_of(i)
		if step < 1 or not _spot_ok(game, tag, spot, own_only, total, leaving, foes):
			continue
		var rank := _rank(game, tag, spot, step, own_only, i, foes, best_rank)
		if rank.is_empty():
			continue
		if best < 0 or _less(rank, best_rank):
			best = i
			best_rank = rank
	if best < 0:
		return out
	var parent: Dictionary = reach["parent"]
	var cur := best
	while cur != int(reach["start"]):
		out.insert(0, game.map.hex_of(cur))
		cur = int(parent[cur])
	return out


## The walk of a side's armies on hex before a spot is chosen (_reach), or {} when there is none to make (no war numbers, no
## army, off the map). It holds while no army, war, fortress or land changes: the questions of one moment share it (has_spot).
static func reach_of(game: Game, tag: StringName, armies: Array[Army], hex: Vector2i) -> Dictionary:
	var war := _war(game)
	if war == null or armies.is_empty() or game.map.index_of(hex) < 0:
		return {}
	return _reach(game, tag, hex, war.retreat_range)


## True when retreat_path would not be empty, from the side's walk `reach` (reach_of): the first spot found answers, none is
## ranked.
static func has_spot(game: Game, tag: StringName, armies: Array[Army], reach: Dictionary, own_only: bool) -> bool:
	if reach.is_empty():
		return false
	var leaving := _ids_of(armies)
	var total := _companies(armies)
	var steps: Dictionary = reach["steps"]
	var foes: Dictionary = reach["foes"]
	for key: Variant in steps:
		if int(steps[key]) >= 1 and _spot_ok(game, tag, game.map.hex_of(int(key)), own_only, total, leaving, foes):
			return true
	return false


## The retreat spot of a side (the last hex of retreat_path), or Army.NO_HEX.
static func retreat_spot(game: Game, tag: StringName, armies: Array[Army], hex: Vector2i, own_only: bool) -> Vector2i:
	var path := retreat_path(game, tag, armies, hex, own_only)
	return path.back() if not path.is_empty() else Army.NO_HEX


## True when tag's armies on hex have a retreat spot (any land, as a broken side may go).
static func can_retreat(game: Game, tag: StringName, hex: Vector2i) -> bool:
	var armies: Array[Army] = []
	for a: Army in Armies.at(game, hex):
		if a.tag == tag:
			armies.append(a)
	return has_spot(game, tag, armies, reach_of(game, tag, armies, hex), false)


## The companies of the armies.
static func _companies(armies: Array[Army]) -> int:
	var total := 0
	for a: Army in armies:
		total += a.units.size()
	return total


## The hexes of the armies at war with tag, as keys (read once for a walk, not once a hex).
static func _foe_hexes(game: Game, tag: StringName) -> Dictionary:
	var at_war := {}
	var out := {}
	for a: Army in game.armies:
		if a.tag == tag:
			continue
		if not at_war.has(a.tag):
			at_war[a.tag] = Wars.at_war(game, tag, a.tag)
		if at_war[a.tag]:
			out[a.hex] = true
	return out


## The hexes a side's armies can walk to within retreat_range: {start, steps: {index: steps}, parent: {index: index},
## foes: the hexes of the armies at war with the side (_foe_hexes)}.
static func _reach(game: Game, tag: StringName, from: Vector2i, reach: int) -> Dictionary:
	var map := game.map
	var costs := StepCosts.of(map, game.defs)
	var foes := _foe_hexes(game, tag)
	var winter := Calendar.is_winter(game.turn)
	var start := map.index_of(from)
	var steps := {start: 0}
	var parent := {}
	var layer: Array[int] = [start]
	for k: int in range(1, reach + 1):
		var next: Array[int] = []
		for i: int in layer:
			for d: int in 6:
				var n := map.neighbour(map.hex_of(i), d)
				var j := map.index_of(n)
				if j < 0 or steps.has(j) or not map.is_land(n):
					continue
				var c := costs.cost(i, d, winter)
				if c == StepCosts.BLOCKED or c == StepCosts.CLOSED or _enemy_held(game, tag, n, foes):
					continue
				steps[j] = k
				parent[j] = i
				next.append(j)
		layer = next
	return {"start": start, "steps": steps, "parent": parent, "foes": foes}


## A hex a side may not enter: an enemy army stands there, or a hostile garrisoned fortress holds it.
static func _enemy_held(game: Game, tag: StringName, hex: Vector2i, foes: Dictionary) -> bool:
	if foes.has(hex):
		return true
	var holder := Occupation.controller_tag(game, hex)
	return holder != tag and holder != &"" and Wars.at_war(game, tag, holder) \
		and Occupation.garrison_of(game, hex) > 0 and Occupation.fortress_level(game, hex) > 0


## Whether a side may stop on spot (see retreat_path): not enemy-held, the land rule, and room for the whole side.
static func _spot_ok(game: Game, tag: StringName, spot: Vector2i, own_only: bool, total: int, leaving: PackedInt32Array,
		foes: Dictionary) -> bool:
	if _enemy_held(game, tag, spot, foes) or Armies.held_by_other(game, tag, spot):
		return false
	if own_only:
		if Occupation.controller_tag(game, spot) != tag:
			return false
	else:
		var owner := Territory.owner_tag(game, spot)
		if not (owner == tag or owner == &"" or Wars.at_war(game, tag, owner)):
			return false
	return Armies.units_at(game, tag, spot, leaving) + total <= game.defs.stack_limit


## The rank of a retreat spot: its controlled land first (for a broken side), the fewer steps, the farther from the nearest enemy
## army, then the lowest index (smaller is better). [] when its first two numbers already lose to `best` (the best rank so far, []
## for none): the distance to the enemy is then not measured.
static func _rank(game: Game, tag: StringName, spot: Vector2i, step: int, own_only: bool, index: int, foes: Dictionary,
		best: PackedInt32Array) -> PackedInt32Array:
	var first := 0 if own_only or Occupation.controller_tag(game, spot) == tag else 1
	if not best.is_empty() and (first > best[0] or (first == best[0] and step > best[1])):
		return PackedInt32Array()
	return PackedInt32Array([first, step, -_enemy_distance(spot, foes), index])


## The distance from spot to the nearest of the hexes of the enemy's armies (0 when there is none).
static func _enemy_distance(spot: Vector2i, foes: Dictionary) -> int:
	var best := -1
	for hex: Vector2i in foes:
		var d := ImproveRules.hex_distance(spot, hex)
		if best < 0 or d < best:
			best = d
	return maxi(best, 0)


## Lexicographic order of two ranks (smaller first).
static func _less(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	for k: int in a.size():
		if a[k] != b[k]:
			return a[k] < b[k]
	return false


static func _ids_of(armies: Array[Army]) -> PackedInt32Array:
	var out := PackedInt32Array()
	for a: Army in armies:
		out.append(a.id)
	return out


static func _war(game: Game) -> WarDef:
	return game.defs.war if game != null and game.defs != null else null
