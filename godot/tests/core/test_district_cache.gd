## The district cache (core/systems/district_cache.gd; docs/architecture/m4-build-spec.md 5.4, 5.0 A5): a cold cache equals
## Economy.district_base on every land hex of north Italy, `touch` forgets the hex and its ring, and a cache that is not
## touched after a change is caught. Game.emit's own touches belong to a later task: here `touch` is called directly.
extends GutTest

const DEFS_PATH := "res://data/defs/game_defs.tres"
const MAP_PATH := "res://data/maps/north_italy.tres"
const SCEN_PATH := "res://data/scenarios/north_italy_1480.tres"

var _defs: GameDefs
var _map: MapData
var _scen: ScenarioDef


func before_all() -> void:
	_defs = ResourceLoader.load(DEFS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	_map = ResourceLoader.load(MAP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as MapData
	_scen = ResourceLoader.load(SCEN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ScenarioDef


func _new_game() -> Game:
	return Game.new_scenario(_map, _defs, _scen, 1480)


## The land hexes whose cached base differs from district_base (the indices).
func _stale(game: Game, cache: DistrictCache) -> Array[int]:
	var out: Array[int] = []
	var view := StateView.of(game.state)
	for i: int in game.map.hex_count():
		if game.map.land[i] == 0:
			continue
		if cache.base_of(game, i) != Economy.district_base(game, view, game.map.hex_of(i)):
			out.append(i)
	return out


func _land_count(game: Game) -> int:
	var n := 0
	for i: int in game.map.hex_count():
		n += game.map.land[i]
	return n


func test_fields_match_the_base_keys() -> void:
	# The cache keeps the people-free fourteen; district_base adds the live people, staffing and a0 (M5 spec 5.3).
	assert_eq(DistrictCache.FIELDS, Economy.BASE_FIELDS.size())
	assert_eq(DistrictCache.FIELDS, 14)
	assert_eq(Economy.empty_base().size(), DistrictCache.FIELDS + 3)
	var game := _new_game()
	var base := Economy.district_base(game, StateView.of(game.state), Vector2i(8, 13))
	assert_eq(base.size(), DistrictCache.FIELDS + 3)
	for key: String in Economy.BASE_FIELDS:
		assert_true(base.has(key), key)
	for key: String in ["people", "staffing", "a0"]:
		assert_true(base.has(key), key)


func test_a_cold_cache_equals_district_base_on_every_land_hex() -> void:
	var game := _new_game()
	var cache := DistrictCache.new()
	assert_eq(cache.size(), 0)
	assert_eq(_stale(game, cache), [] as Array[int], "first reads compute")
	assert_eq(cache.size(), _land_count(game))
	assert_eq(_stale(game, cache), [] as Array[int], "later reads come from the ints")
	assert_eq(cache.size(), _land_count(game))
	assert_eq(cache.base_of(game, -1), Economy.empty_base())


func test_touch_forgets_the_hex_and_its_ring_only() -> void:
	var game := _new_game()
	var cache := DistrictCache.new()
	_stale(game, cache)
	var full := cache.size()
	var hex := Vector2i(8, 13)  # Genoa: a coast hex with sea neighbours
	var gone := 1
	for d: int in 6:
		if game.map.is_land(game.map.neighbour(hex, d)):
			gone += 1
	cache.touch(game, hex)
	assert_eq(cache.size(), full - gone)
	cache.touch(game, hex)
	assert_eq(cache.size(), full - gone, "touching twice forgets nothing more")
	cache.touch(game, Vector2i(-5, -5))
	assert_eq(cache.size(), full - gone, "off the map: nothing")


func test_a_change_without_touch_is_stale_and_touch_repairs_it() -> void:
	var game := _new_game()
	var cache := DistrictCache.new()
	_stale(game, cache)
	var hex := Vector2i(7, 12)  # Genoa's vineyard: replace it
	var i := game.map.index_of(hex)
	game.state.main_use[i] = 9
	game.state.level[i] = 3
	# A cache whose touch does nothing is caught: the district still shows the vineyard.
	assert_true(_stale(game, cache).has(i), "the changed hex is stale")
	cache.touch(game, hex)
	assert_eq(_stale(game, cache), [] as Array[int], "touch repairs the hex and its ring")


func test_touch_covers_jobs_and_lift_in_the_ring() -> void:
	var game := _new_game()
	var cache := DistrictCache.new()
	_stale(game, cache)
	var hex := Vector2i(9, 13)  # the timber district beside Genoa
	var genoa := game.map.index_of(Vector2i(8, 13))
	assert_eq(int(cache.base_of(game, game.map.index_of(hex))["lift"]), 100)
	game.state.level[genoa] = 5
	cache.touch(game, Vector2i(8, 13))
	assert_eq(int(cache.base_of(game, game.map.index_of(hex))["lift"]), 200)
	assert_eq(_stale(game, cache), [] as Array[int])


func test_random_changes_with_touches_keep_the_cache_equal() -> void:
	var game := _new_game()
	var cache := DistrictCache.new()
	_stale(game, cache)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1480
	var land: Array[int] = []
	for i: int in game.map.hex_count():
		if game.map.land[i] == 1:
			land.append(i)
	for step: int in 300:
		var i := land[rng.randi_range(0, land.size() - 1)]
		var family := rng.randi_range(0, 14)
		game.state.main_use[i] = family
		game.state.level[i] = 0 if family == 0 else rng.randi_range(1, FamilyIds.TOP_LEVEL[family])
		cache.touch(game, game.map.hex_of(i))
		if step % 30 == 29:
			assert_eq(_stale(game, cache), [] as Array[int], "after %d changes" % (step + 1))


func test_clear_empties_the_cache() -> void:
	var game := _new_game()
	var cache := DistrictCache.new()
	_stale(game, cache)
	cache.clear()
	assert_eq(cache.size(), 0)
	var i := game.map.index_of(Vector2i(8, 13))
	cache.base_of(game, i)
	assert_eq(cache.size(), 1)
	assert_eq(cache.base_of(game, i), Economy.district_base(game, StateView.of(game.state), Vector2i(8, 13)))


func test_made_of_works_while_game_has_no_districts_field() -> void:
	# Game gets its `districts` field in a later task; made_of reads it when it is there and computes otherwise.
	var game := _new_game()
	var info := EconomySeason.made_of(game, StateView.of(game.state), &"GEN", 2, PackedByteArray([0, 0, 0]), 1)
	assert_eq(info["made"][3], 24)


func test_made_of_through_the_cache_equals_made_of_without_it_for_every_country() -> void:
	var game := _new_game()
	var view := StateView.of(game.state)
	var cache := DistrictCache.new()
	var weather := PackedByteArray([1, 2, 0])
	for c: Country in game.countries:
		for season: int in 4:
			for tax: int in 3:
				var cold := EconomySeason.made_of(game, view, c.tag, season, weather, tax)
				var warm := EconomySeason.made_of(game, view, c.tag, season, weather, tax, cache)
				assert_eq(warm, cold, "%s season %d tax %d" % [c.tag, season, tax])
	assert_gt(cache.size(), 0)


# ----- through Game.emit (task N4; 5.0 A5) ---------------------------------------------------------------------------


func test_two_thousand_random_actions_keep_the_games_own_cache_equal() -> void:
	var game := EconomyFixture.game(&"GEN")
	var cache := game.districts
	var rng := RandomNumberGenerator.new()
	rng.seed = 2000
	var hexes: Array[Vector2i] = []
	for i: int in game.map.hex_count():
		if game.map.land[i] == 1 and int(game.state.owner[i]) == Countries.by_tag(game, &"GEN").id:
			hexes.append(game.map.hex_of(i))
	var changed := 0
	for n: int in 2000:
		var hex := hexes[rng.randi_range(0, hexes.size() - 1)]
		var pick := rng.randi_range(0, 9)
		if n % 5 == 0:
			game.dev_money(&"GEN", 1000)
			game.dev_goods(&"GEN", 11, 30)
			game.dev_goods(&"GEN", 12, 60)
		if pick < 3:
			var options: Array[Dictionary] = []
			for o: Dictionary in game.improvement.build_options(hex):
				if bool(o["ok"]):
					options.append(o)
			if not options.is_empty():
				game.act("build", {"hex": hex, "family": int(options[rng.randi_range(0, options.size() - 1)]["family_id"]), "tag": &"GEN"})
		elif pick < 5:
			game.act("upgrade", {"hex": hex, "tag": &"GEN"})
		elif pick < 6:
			game.act("clear", {"hex": hex, "tag": &"GEN"})
		elif pick < 7:
			game.act("cancel_work", {"hex": hex, "tag": &"GEN"})
		else:
			var before := Array(game.state.main_use)
			Season.run(game)
			changed += 0 if Array(game.state.main_use) == before else 1
		if n % 40 == 39:
			assert_eq(_stale(game, cache), [] as Array[int], "after %d actions" % (n + 1))
	assert_eq(_stale(game, cache), [] as Array[int], "after 2,000 actions")
	assert_gt(changed, 5, "works finished and changed the map through the door")
	assert_gt(cache.size(), 0)


# ----- M5: the cache keeps the people-free fourteen; staffing and a0 are live (spec 5.3) -------------------------------


func test_staffing_follows_the_people_without_a_touch() -> void:
	# P: a cache that kept staffing across a season would show the old number after the people move and nothing is touched.
	var game := _new_game()
	var cache := DistrictCache.new()
	_stale(game, cache)
	var hex := Vector2i(9, 13)  # the timber district beside Genoa: its hands are Genoa's people and its own ring's
	var i := game.map.index_of(hex)
	var before := cache.base_of(game, i)
	game.state.people[game.map.index_of(Vector2i(9, 12))] = 0
	game.state.people[game.map.index_of(Vector2i(8, 13))] = 0
	game.state.people[game.map.index_of(Vector2i(10, 13))] = 0
	var after := cache.base_of(game, i)
	assert_eq(after["people"], game.state.people[i])
	assert_lt(int(after["staffing"]), int(before["staffing"]), "fewer hands: less of the jobs staffed, with no touch")
	assert_lt(int(after["a0"]), int(before["a0"]))
	assert_eq(after["raw"], before["raw"])
	assert_eq(_stale(game, cache), [] as Array[int], "and the cache still equals district_base everywhere")


func test_base_of_reads_the_view_given() -> void:
	var game := _new_game()
	var cache := DistrictCache.new()
	var hex := Vector2i(9, 13)
	var i := game.map.index_of(hex)
	var own := cache.base_of(game, i)
	var empty := {i: 0, game.map.index_of(Vector2i(8, 13)): 0}
	for d: int in 6:
		empty[game.map.index_of(game.map.neighbour(hex, d))] = 0
	var view := StateView.of(game.state).with_people(empty)
	var what_if := cache.base_of(game, i, view)
	assert_eq(what_if, Economy.district_base(game, view, hex), "equals district_base on the view")
	assert_eq(cache.base_of(game, i), own, "and the cache itself is as it was")
	assert_lt(int(what_if["staffing"]), int(own["staffing"]))


func test_the_cache_equals_district_base_after_ten_seasons_of_people() -> void:
	var game := PeopleFixture.genoa()
	PeopleFixture.play(game, 10)
	var cache := game.districts
	assert_eq(_stale(game, cache), [] as Array[int])
	assert_eq(_stale(game, DistrictCache.new()), [] as Array[int], "a cold cache too")


func test_the_caches_staffing_equals_the_one_live_step_on_every_goods_hex() -> void:
	# DistrictCache.staffed_of (the hot path of SeasonProfile.live) and Economy.staffed (the view's step) agree, at turn 1,
	# with the people moved by ten seasons, and with a foreign owner on a hex beside a district.
	var game := PeopleFixture.genoa()
	for stage: int in 2:
		if stage == 1:
			PeopleFixture.play(game, 10)
			game.state.owner[game.map.index_of(Vector2i(9, 12))] = 0
		var view := StateView.of(game.state)
		var cache := game.districts
		var checked := 0
		for i: int in game.map.hex_count():
			if game.map.land[i] == 0:
				continue
			var ints := cache.ints_of(game, i)
			var raw := ints[i * DistrictCache.FIELDS + Economy.F_RAW]
			if raw == 0:
				continue
			var lift := ints[i * DistrictCache.FIELDS + Economy.F_LIFT]
			assert_eq(cache.staffed_of(game, i, raw, lift), Economy.staffed(game, view, i, raw, lift), str(game.map.hex_of(i)))
			checked += 1
		assert_gt(checked, 3, "districts with output")
