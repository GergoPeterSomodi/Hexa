## The fast fog paths of FG18 fix (fog-build-spec 8): SightCache.discovered_of (one bitset per viewer), Knowledge.land_seen (sums over the
## discovered bits) and MapModes.discovered_bytes (expanded from those bits). Each must equal its slow reference on many states: the
## thin fixture at several radii, the normal duel, and after a thin change; and a cached answer must follow a change of explored or land.
extends GutTest

const VIEWER := AiFixture.MILAN


func _thin_game(radius: int) -> Game:
	var g := AiFixture.duel()
	g.player = VIEWER
	FogFixture.thin(g, VIEWER, radius)
	return g


## Every hex: the bit set of discovered_of is Knowledge.discovered (fog R1); the bytes of discovered_bytes match too.
func _assert_bits_match(g: Game, label: String) -> void:
	var bits := g.sight.discovered_of(g, Countries.by_tag(g, VIEWER).id)
	var bytes := MapModes.discovered_bytes(g, VIEWER)
	var bad := 0
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		var on := SightCache.bit_is(bits, i)
		if on != Knowledge.discovered(g, VIEWER, hex) or (bytes[i] == 1) != on:
			bad += 1
	assert_eq(bad, 0, "%s: discovered bits equal Knowledge.discovered on every hex" % label)


## land_seen (fast) equals the slow reference for every country as the viewer, the viewer "" included.
func _assert_land_seen_match(g: Game, label: String) -> void:
	var bad := 0
	for c: Country in g.countries:
		var fast := Knowledge.land_seen(g, VIEWER, c.tag)
		var slow := Knowledge.make_land_seen_slow(g, VIEWER, c.id)
		if int(fast["districts"]) != int(slow["districts"]) or int(fast["people"]) != int(slow["people"]):
			bad += 1
	assert_eq(bad, 0, "%s: land_seen equals the slow reference for every country" % label)


func test_discovered_bits_match_on_the_thin_duel_at_several_radii() -> void:
	for radius: int in [0, 1, 2, 4]:
		var g := _thin_game(radius)
		_assert_bits_match(g, "thin r%d" % radius)
		_assert_land_seen_match(g, "thin r%d" % radius)


func test_discovered_bits_match_on_the_normal_duel() -> void:
	var g := AiFixture.duel()
	g.player = VIEWER
	_assert_bits_match(g, "normal duel")
	_assert_land_seen_match(g, "normal duel")


func test_a_cached_discovered_bitset_follows_a_thin_change() -> void:
	var g := AiFixture.duel()
	g.player = VIEWER
	var before := g.sight.discovered_of(g, Countries.by_tag(g, VIEWER).id).duplicate()
	FogFixture.thin(g, VIEWER, 0)
	var after := g.sight.discovered_of(g, Countries.by_tag(g, VIEWER).id)
	assert_ne(before, after, "a thin change is seen by the next ask (no stale bitset)")
	_assert_bits_match(g, "after thin 0")


func test_a_cached_land_seen_follows_a_change_of_explored() -> void:
	var g := AiFixture.duel()
	g.player = VIEWER
	var ven := Countries.by_tag(g, AiFixture.VENICE)
	var first := Knowledge.land_seen(g, VIEWER, AiFixture.VENICE)
	FogFixture.thin(g, VIEWER, 0)
	g.version += 1
	var second := Knowledge.land_seen(g, VIEWER, AiFixture.VENICE)
	assert_eq(second, Knowledge.make_land_seen_slow(g, VIEWER, ven.id), "land_seen after a change equals the slow reference")
	assert_lte(int(second["districts"]), int(first["districts"]), "thinning never shows more districts")
