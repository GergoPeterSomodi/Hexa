## The deep-fog step (docs/architecture/moves-build-spec.md R7, R36 to R39, D9; the default of moves-build-plan.md section 8,
## which the owner will come back to). A step onto a hex whose EXPLORED bit the walker's country lacks (Sight.explored) is a fog
## step: it is taken only by a fresh army (its points equal its full points) and spends GameDefs.fog_step_cost (-1: all its
## points). The explored bit, not the sight: an army's own sight ring makes every next hex seen (fog D1), so a rule read from the
## sight would never bite. The vision phase explores the army's sight ring, so sight 1 advances about one hex a season through
## unmapped land and sight 2 about two. MarchLeg's leg (both walks), Movement.walk_season (the plans' estimate) and the preview
## read it. On north Italy every country has explored every hex at the start (fog D3), so nothing changes there.
## Pure reads; no luck; integer maths.
class_name FogStep
extends RefCounted

const OWNS: Array[String] = []
## The stop word of a walk that ends on (or before) a fog step: not a halt, the march stays standing.
const WHY := &"fog"


## The explored bitset of `tag`: a hex whose bit is unset is a fog step. Empty (no fog step anywhere) when the game has no
## countries, the country is unknown, or its explored set was never made for this map (an in-memory game with no setup).
static func mapped(game: Game, tag: StringName) -> PackedByteArray:
	if game == null or game.map == null or not game.has_countries():
		return PackedByteArray()
	var c := Countries.by_tag(game, tag)
	if c == null or c.explored.size() != (game.map.hex_count() + 7) >> 3:
		return PackedByteArray()
	return c.explored


## True when the step onto hex index `index` is a fog step for the country whose `mapped` bitset this is.
static func is_fog(bits: PackedByteArray, index: int) -> bool:
	return not bits.is_empty() and index >= 0 and not SightCache.bit_is(bits, index)


## The points left after a fog step taken with `points`: none for a cost of -1, else the points less the cost (never below 0).
static func after(cost: int, points: int) -> int:
	return 0 if cost < 0 else maxi(0, points - cost)
