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
	assert_eq(DistrictCache.FIELDS, Economy.BASE_FIELDS.size())
	assert_eq(Economy.empty_base().size(), DistrictCache.FIELDS)
	var game := _new_game()
	assert_eq(Economy.district_base(game, StateView.of(game.state), Vector2i(8, 13)).size(), DistrictCache.FIELDS)


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
