## The move allowance (docs/architecture/moves-build-spec.md 3.1, R12 to R15, D3, D14): the move points an army has left in the
## season, 0 to its full (the slowest company's UnitDef.mp). The reads and the rules live here; the one writer of the field is
## Armies.set_points, which every rule below calls. Refilled in the ready_units phase (R13); a split, a merge and a disband move
## the points by the D14 rules so no change of the army gives more points than it had (the loopholes of design 2.5).
## Whole numbers only; no luck; no engine calls.
class_name Allowance
extends RefCounted

const OWNS: Array[String] = []


## The army's full points: the slowest company's mp (Movement.mp_of); 0 for an army with no company.
static func full(game: Game, army: Army) -> int:
	return Movement.mp_of(game, army)


## The points the army has left this season.
static func left(army: Army) -> int:
	return army.points


## True when the army has not spent any of its points: they equal its full and are above 0 (R15).
static func fresh(game: Game, army: Army) -> bool:
	var top := full(game, army)
	return top > 0 and army.points == top


## The ready_units phase (R13): every army's points become its full.
static func refill(game: Game) -> void:
	if game == null:
		return
	for a: Army in game.armies:
		Armies.set_points(game, a, full(game, a))


## A split (R15, D14): the new army's points are the parent's points before the split, and the parent keeps them; each is cut
## to its own full (a slower company may have gone with either).
static func after_split(game: Game, parent: Army, fresh_army: Army, parent_before: int) -> void:
	Armies.set_points(game, fresh_army, parent_before)
	Armies.set_points(game, parent, parent_before)


## A merge (R15, D14): the army that took the companies gets the lower of the two armies' points, cut to its new full.
static func after_merge(game: Game, into: Army, a_points: int, into_points: int) -> void:
	Armies.set_points(game, into, mini(a_points, into_points))


## A disband that leaves the army standing (R15, D14): its points are cut to its new full.
static func after_disband(game: Game, army: Army) -> void:
	Armies.set_points(game, army, army.points)


## The invariant I1 for the points (R14): one line for each army whose points are below 0 or above its full. Empty when sound.
static func check(game: Game) -> PackedStringArray:
	var out := PackedStringArray()
	for a: Army in game.armies:
		var top := full(game, a)
		if a.points < 0 or a.points > top:
			out.append("army %d has %d move points, outside 0 to %d" % [a.id, a.points, top])
	return out
