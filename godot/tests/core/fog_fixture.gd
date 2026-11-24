## The thin fixture of the fog build (docs/architecture/fog-build-spec.md 7; FG3). A country whose explored set is thin: only its
## land sight and a ring of `r` hexes around it, so the rest of the map is undiscovered and each fog state can be tested.
## A test's state edit, as WarFixture does; never used by the game.
##   thin(g, tag, r):   explored = the country's land sight grown by r (a copy: the land cache is never aliased); the sight's
##                      caches are dropped (the known sets too), the army part refreshed, the version bumped.
##   grown(g, tag, r):  the bitset thin sets, made on its own and written nowhere (a test's expectation reads the same rule).
##   duel_thin():       AiFixture.duel() with Milan (MLO) thin at radius 2 (spec 7).
class_name FogFixture
extends RefCounted


## Sets the explored set of `tag` to its land sight grown by `r` hexes (0: the land sight itself).
static func thin(g: Game, tag: StringName, r: int) -> void:
	var c := Countries.by_tag(g, tag)
	if c == null:
		return
	c.explored = grown(g, tag, r)
	g.sight.clear()
	Sight.refresh(g)
	g.version += 1


## The explored bitset `thin(g, tag, r)` gives: every hex within `r` of the land sight of `tag`, a new array.
static func grown(g: Game, tag: StringName, r: int) -> PackedByteArray:
	var n := g.map.hex_count()
	var bits := PackedByteArray()
	bits.resize((n + 7) >> 3)
	bits.fill(0)
	var c := Countries.by_tag(g, tag)
	if c == null:
		return bits
	var land: PackedByteArray = g.sight.land_of(g, c.id)
	for i: int in n:
		if SightCache.bit_is(land, i):
			for j: int in SightCache.disc(g.map, i, r):
				bits[j >> 3] = bits[j >> 3] | (1 << (j & 7))
	return bits


## Milan thin at radius 2 on the duel (AiFixture.duel): Genoa chosen, the neighbours of Milan with armies, the AI attached.
static func duel_thin() -> Game:
	var g := AiFixture.duel()
	thin(g, AiFixture.MILAN, 2)
	return g
