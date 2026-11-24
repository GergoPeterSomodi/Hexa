## The thin fixture (docs/architecture/fog-build-spec.md 7; FG3): thin(g, tag, r) leaves exactly the land sight grown by r in the
## country's explored set; duel_thin is the duel with Milan thin at radius 2. The expected set is made here by a breadth-first
## walk over the hex neighbours (not by the disc table the fixture uses), so the two can disagree.
## Planted faults: a thin set missing the own land, one grown by r - 1, and a set aliasing the land cache, are each shown to differ.
extends GutTest

const GEN := &"GEN"


func _game() -> Game:
	return ArmyFixture.game()


## The explored set of the rule, by a walk: every own district is at distance 0, a hex is in when it is within
## land_sight + r of one of them (the walk goes through map cells only, never past the edge).
func _expected(g: Game, tag: StringName, r: int) -> PackedByteArray:
	var c := Countries.by_tag(g, tag)
	var n := g.map.hex_count()
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var queue: Array[int] = []
	for d: int in Territory.districts(g, c.id):
		dist[d] = 0
		queue.append(d)
	var depth: int = g.defs.land_sight + r
	var head := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		if dist[i] >= depth:
			continue
		var hex := g.map.hex_of(i)
		for k: int in 6:
			var j := g.map.index_of(ImproveRules.neighbour(hex, k))
			if j >= 0 and dist[j] == -1:
				dist[j] = dist[i] + 1
				queue.append(j)
	var bits := PackedByteArray()
	bits.resize((n + 7) >> 3)
	bits.fill(0)
	for i: int in n:
		if dist[i] >= 0:
			bits[i >> 3] = bits[i >> 3] | (1 << (i & 7))
	return bits


## Hexes whose bit differs between the two sets (the bitsets have the map's size).
func _mismatches(a: PackedByteArray, b: PackedByteArray, n: int) -> int:
	var count := 0
	for i: int in n:
		if SightCache.bit_is(a, i) != SightCache.bit_is(b, i):
			count += 1
	return count


func test_thin_leaves_exactly_the_land_sight_grown_by_r() -> void:
	for r: int in [0, 1, 2]:
		var g := _game()
		var n := g.map.hex_count()
		FogFixture.thin(g, GEN, r)
		var c := Countries.by_tag(g, GEN)
		var expected := _expected(g, GEN, r)
		assert_eq(_mismatches(c.explored, expected, n), 0, "r %d: the thin set is the land sight grown by r" % r)
		assert_eq(c.explored.size(), (n + 7) >> 3, "r %d: one bit a hex" % r)


func test_thin_holds_every_own_hex_and_is_not_the_whole_map() -> void:
	var g := _game()
	FogFixture.thin(g, GEN, 0)
	var c := Countries.by_tag(g, GEN)
	var own := Territory.districts(g, c.id)
	assert_gt(own.size(), 0, "Genoa holds land")
	for d: int in own:
		assert_true(SightCache.bit_is(c.explored, d), "own hex %d is explored" % d)
	var unseen := Vector2i(-1, -1)
	for i: int in g.map.hex_count():
		if g.map.is_land(g.map.hex_of(i)) and not SightCache.bit_is(c.explored, i):
			unseen = g.map.hex_of(i)
			break
	assert_ne(unseen, Vector2i(-1, -1), "a land hex far from Genoa is undiscovered")


func test_thin_bumps_the_version() -> void:
	var g := _game()
	var version := g.version
	FogFixture.thin(g, GEN, 1)
	assert_gt(g.version, version, "a hand edit bumps the version")


func test_thin_does_not_alias_the_land_cache() -> void:
	var g := _game()
	FogFixture.thin(g, GEN, 0)
	var c := Countries.by_tag(g, GEN)
	var land_before: PackedByteArray = g.sight.land_of(g, c.id).duplicate()
	# a far hex, marked by a walk: explored grows, the land cache must not
	var far := Vector2i(-1, -1)
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.is_land(hex) and not SightCache.bit_is(land_before, i):
			far = hex
			break
	assert_ne(far, Vector2i(-1, -1), "a land hex outside Genoa's land exists")
	Sight.see_path(g, GEN, [far] as Array[Vector2i], 2)
	assert_true(Sight.explored(g, GEN, far), "the walk explored the far hex")
	assert_eq(_mismatches(g.sight.land_of(g, c.id), land_before, g.map.hex_count()), 0,
		"the land sight is unchanged by the walk (no shared storage)")


func test_planted_thin_set_missing_own_land_is_caught() -> void:
	var g := _game()
	var n := g.map.hex_count()
	var expected := _expected(g, GEN, 1)
	var broken := FogFixture.grown(g, GEN, 1)
	for d: int in Territory.districts(g, Countries.by_tag(g, GEN).id):
		broken[d >> 3] = broken[d >> 3] & ~(1 << (d & 7))
	assert_gt(_mismatches(broken, expected, n), 0, "a set without the own land differs from the rule")


func test_planted_thin_set_one_ring_short_is_caught() -> void:
	var g := _game()
	var n := g.map.hex_count()
	var expected := _expected(g, GEN, 2)
	var short := FogFixture.grown(g, GEN, 1)
	assert_gt(_mismatches(short, expected, n), 0, "grown by 1 differs from grown by 2")


func test_duel_thin_thins_milan_at_radius_two() -> void:
	var g := FogFixture.duel_thin()
	var n := g.map.hex_count()
	var milan := Countries.by_tag(g, AiFixture.MILAN)
	assert_not_null(milan)
	assert_eq(_mismatches(milan.explored, _expected(g, AiFixture.MILAN, 2), n), 0, "Milan's set is the land sight grown by 2")
