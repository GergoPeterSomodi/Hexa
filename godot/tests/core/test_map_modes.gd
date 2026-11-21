## Pure unit tests for MapModes plain inputs (docs/architecture/m2-build-spec.md sections 4.6, 5.7, and 10).
extends GutTest

const NEIGHBOUR_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const ODD_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1),
]


func _make_map(cols: int, rows: int) -> MapData:
	var map := MapData.new()
	map.id = "map_modes_fixture"
	map.allocate(cols, rows)
	return map


func test_hex_at_px_centres_and_points_40px_toward_each_neighbour() -> void:
	for row: int in range(-2, 10):
		for col: int in range(-2, 12):
			var hex := Vector2i(col, row)
			var mid := MapTiles.cell_centre(hex)
			assert_eq(MapModes.hex_at_px(mid), hex, "centre of %s resolves to itself" % hex)
			var dirs := ODD_DIRS if (row & 1) == 1 else NEIGHBOUR_DIRS
			for d: int in 6:
				var nb_mid := MapTiles.cell_centre(hex + dirs[d])
				var toward := mid + (nb_mid - mid).normalized() * 40.0
				assert_eq(MapModes.hex_at_px(toward), hex, "40px from %s toward dir %d stays inside %s" % [hex, d, hex])


func test_height_bytes_sea_steps_and_cap() -> void:
	assert_eq(MapModes.height_bytes(null), PackedByteArray())
	var map := _make_map(8, 1)
	# (0, 0) stays sea (land = 0), rest are land with varying heights.
	var heights: Array[int] = [500, 0, 15, 16, 31, -40, 3200, 5000]
	for c: int in 8:
		map.land[c] = 0 if c == 0 else 1
		map.height_m[c] = heights[c]
	var bytes := MapModes.height_bytes(map)
	assert_eq(bytes.size(), 8)
	assert_eq(int(bytes[0]), 0, "sea is always byte 0 even when height_m != 0")
	assert_eq(int(bytes[1]), 1, "0 m land -> byte 1")
	assert_eq(int(bytes[2]), 1, "15 m land -> byte 1")
	assert_eq(int(bytes[3]), 2, "16 m land -> byte 2")
	assert_eq(int(bytes[4]), 2, "31 m land -> byte 2")
	assert_eq(int(bytes[5]), 1, "negative land height clamps to byte 1")
	assert_eq(int(bytes[6]), 201, "3200 m land -> byte 201")
	assert_eq(int(bytes[7]), 255, "above 4064 m caps at 255")


func test_relief_ramp_stops_and_interpolation() -> void:
	var ramp := MapModes.relief_ramp()
	assert_eq(ramp.size(), 256)
	assert_eq(ramp[0], Color(0.0, 0.0, 0.0, 0.0), "byte 0 (sea) is clear")
	assert_true(ramp[1].is_equal_approx(Color("#4f8a4a")), "0 m stop at byte 1")
	assert_true(ramp[26].is_equal_approx(Color("#b7b56a")), "400 m stop at byte 26")
	assert_true(ramp[51].is_equal_approx(Color("#c49a5c")), "800 m stop at byte 51")
	assert_true(ramp[201].is_equal_approx(Color("#f4f5f8")), "3200 m stop at byte 201")
	assert_true(ramp[255].is_equal_approx(Color("#f4f5f8")), "above 3200 m stays at top stop")
	# Linear interpolation between 0 m (#4f8a4a) and 150 m (#79a557) at 16 m (byte 2).
	var expected_16m := Color("#4f8a4a").lerp(Color("#79a557"), 16.0 / 150.0)
	assert_true(ramp[2].is_equal_approx(expected_16m), "byte 2 interpolates linearly between 0 m and 150 m")


func test_palette_from_layout() -> void:
	var unowned := Color("#d8ccb0")
	var c1 := Color("#be3c6e")
	var c2 := Color("#3460b2")
	var pal := MapModes.palette_from(PackedColorArray([c1, c2]), unowned)
	assert_eq(pal.size(), 256)
	assert_eq(pal[0], unowned)
	assert_eq(pal[1], c1)
	assert_eq(pal[2], c2)
	assert_eq(pal[3], Color(0.0, 0.0, 0.0, 0.0))


func test_colour_of_modes_tint_off_and_hot() -> void:
	var unowned := Color("#d8ccb0")
	var c1 := Color("#be3c6e")
	var c2 := Color("#3460b2")
	var pal := MapModes.palette_from(PackedColorArray([c1, c2]), unowned)
	var ramp := MapModes.relief_ramp()

	# Sea is clear in every mode, even when hot.
	for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.OWNER, MapModes.Mode.RELIEF]:
		assert_eq(MapModes.colour_of(mode, 1, 0, pal, true, 1), Color(0.0, 0.0, 0.0, 0.0))

	# Terrain mode: owned tinted at 0.14, unowned clear, tint_on=false clear.
	var t_owned := MapModes.colour_of(MapModes.Mode.TERRAIN, 1, 5, pal, true, 0)
	assert_true(t_owned.is_equal_approx(Color(c1.r, c1.g, c1.b, MapModes.TINT_ALPHA)))
	assert_eq(MapModes.colour_of(MapModes.Mode.TERRAIN, 0, 5, pal, true, 0), Color(0.0, 0.0, 0.0, 0.0))
	assert_eq(MapModes.colour_of(MapModes.Mode.TERRAIN, 1, 5, pal, false, 1), Color(0.0, 0.0, 0.0, 0.0))

	# Owner mode: owned at 0.55, unowned parchment at 0.55.
	var o_owned := MapModes.colour_of(MapModes.Mode.OWNER, 2, 5, pal, true, 0)
	assert_true(o_owned.is_equal_approx(Color(c2.r, c2.g, c2.b, MapModes.OWNER_ALPHA)))
	var o_unowned := MapModes.colour_of(MapModes.Mode.OWNER, 0, 5, pal, true, 0)
	assert_true(o_unowned.is_equal_approx(Color(unowned.r, unowned.g, unowned.b, MapModes.OWNER_ALPHA)))
	# hot_id == 0 must not highlight unowned land.
	var o_unowned_hot0 := MapModes.colour_of(MapModes.Mode.OWNER, 0, 5, pal, true, 0)
	assert_true(o_unowned_hot0.is_equal_approx(o_unowned))

	# Relief mode: uses ramp[height_byte] at 0.65.
	var r_col := MapModes.colour_of(MapModes.Mode.RELIEF, 1, 26, pal, true, 0)
	assert_true(r_col.is_equal_approx(Color(ramp[26].r, ramp[26].g, ramp[26].b, MapModes.RELIEF_ALPHA)))

	# Hot highlight: mixes 15% with white and adds 0.20 alpha in all three active modes.
	var hot_terrain := MapModes.colour_of(MapModes.Mode.TERRAIN, 1, 5, pal, true, 1)
	var exp_c1 := c1.lerp(Color.WHITE, MapModes.HOT_LIGHTEN)
	assert_true(hot_terrain.is_equal_approx(Color(exp_c1.r, exp_c1.g, exp_c1.b, MapModes.TINT_ALPHA + MapModes.HOT_ALPHA)))
	var hot_owner := MapModes.colour_of(MapModes.Mode.OWNER, 2, 5, pal, true, 2)
	var exp_c2 := c2.lerp(Color.WHITE, MapModes.HOT_LIGHTEN)
	assert_true(hot_owner.is_equal_approx(Color(exp_c2.r, exp_c2.g, exp_c2.b, MapModes.OWNER_ALPHA + MapModes.HOT_ALPHA)))
	var hot_relief := MapModes.colour_of(MapModes.Mode.RELIEF, 1, 26, pal, true, 1)
	var exp_r := ramp[26].lerp(Color.WHITE, MapModes.HOT_LIGHTEN)
	assert_true(hot_relief.is_equal_approx(Color(exp_r.r, exp_r.g, exp_r.b, MapModes.RELIEF_ALPHA + MapModes.HOT_ALPHA)))


func test_modes_and_palette_from_game() -> void:
	assert_eq(MapModes.modes(null), [MapModes.Mode.TERRAIN, MapModes.Mode.RELIEF] as Array[int])
	var map := _make_map(4, 3)
	var sandbox := Game.new_game(map, 1480)
	assert_eq(MapModes.modes(sandbox), [MapModes.Mode.TERRAIN, MapModes.Mode.RELIEF] as Array[int],
		"map-only game omits OWNER mode")
	var sandbox_pal := MapModes.palette(sandbox, false)
	assert_eq(sandbox_pal.size(), MapModes.PALETTE_SIZE)
	assert_eq(sandbox_pal[0], MapModes.DEFAULT_UNOWNED)

	var scen_game := ScenarioFixture.game()
	assert_eq(MapModes.modes(scen_game), [MapModes.Mode.TERRAIN, MapModes.Mode.OWNER, MapModes.Mode.RELIEF] as Array[int])

	var std_pal := MapModes.palette(scen_game, false)
	assert_eq(std_pal.size(), MapModes.PALETTE_SIZE)
	assert_eq(std_pal[0], scen_game.defs.unowned_colour)
	assert_eq(std_pal[1], scen_game.defs.country(&"AAA").colour)
	assert_eq(std_pal[2], scen_game.defs.country(&"BBB").colour)
	assert_eq(std_pal[3], scen_game.defs.country(&"OUT").colour)

	var cb_pal := MapModes.palette(scen_game, true)
	assert_eq(cb_pal.size(), MapModes.PALETTE_SIZE)
	assert_eq(cb_pal[0], scen_game.defs.unowned_colour)
	assert_eq(cb_pal[1], scen_game.defs.cb_palette[int(scen_game.scenario.cb_colours[0])])
	assert_eq(cb_pal[2], scen_game.defs.cb_palette[int(scen_game.scenario.cb_colours[1])])
	assert_eq(cb_pal[3], scen_game.defs.cb_palette[int(scen_game.scenario.cb_colours[2])])


func test_colour_at_matches_colour_of_for_owned_unowned_and_sea() -> void:
	var game := ScenarioFixture.game()
	var pal := MapModes.palette(game, false)
	var alpha_hex := ScenarioFixture.ALPHA_CAPITAL
	var unowned_hex := ScenarioFixture.UNOWNED_HEXES[0]
	var sea_hex := ScenarioFixture.SEA_HEX
	var hb := MapModes.height_bytes(game.map)

	assert_eq(MapModes.colour_at(game, MapModes.Mode.OWNER, sea_hex, pal, true, 1), Color(0.0, 0.0, 0.0, 0.0))
	assert_eq(MapModes.colour_at(game, MapModes.Mode.OWNER, Vector2i(-1, 0), pal, true, 1), Color(0.0, 0.0, 0.0, 0.0))

	var alpha_oid := Territory.owner_id(game, alpha_hex)
	assert_eq(alpha_oid, 1)
	var alpha_hb := int(hb[game.map.index_of(alpha_hex)])
	for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.OWNER, MapModes.Mode.RELIEF]:
		assert_true(MapModes.colour_at(game, mode, alpha_hex, pal, true, 0).is_equal_approx(
			MapModes.colour_of(mode, alpha_oid, alpha_hb, pal, true, 0)))
		assert_true(MapModes.colour_at(game, mode, alpha_hex, pal, true, 1).is_equal_approx(
			MapModes.colour_of(mode, alpha_oid, alpha_hb, pal, true, 1)))

	assert_eq(Territory.owner_id(game, unowned_hex), 0)
	var unowned_col := MapModes.colour_at(game, MapModes.Mode.OWNER, unowned_hex, pal, true, 0)
	assert_true(unowned_col.is_equal_approx(Color(pal[0].r, pal[0].g, pal[0].b, MapModes.OWNER_ALPHA)))
	assert_eq(MapModes.colour_at(game, MapModes.Mode.TERRAIN, unowned_hex, pal, true, 0), Color(0.0, 0.0, 0.0, 0.0))


func test_delta_colour_is_good_for_a_gain_and_bad_for_a_loss() -> void:
	var gain := MapModes.delta_colour(12)
	var loss := MapModes.delta_colour(-3)
	assert_eq(Color(gain.r, gain.g, gain.b), Color("#7fc98a"))
	assert_eq(Color(loss.r, loss.g, loss.b), Color("#f0806a"))
	assert_almost_eq(gain.a, 0.35, 0.0001)
	assert_almost_eq(loss.a, 0.35, 0.0001)
	assert_eq(MapModes.delta_colour(0).a, 0.0, "no change, no tint")



# --- Yields (docs/architecture/m4-5-build-spec.md 4.8) ---------------------------------------------------------------


func test_yield_band_edges() -> void:
	var edges: Dictionary = {-1: 1, 0: 2, 1: 3, 9: 3, 10: 4, 24: 4, 25: 5, 49: 5, 50: 6, 99: 6, 100: 7, 199: 7, 200: 8,
		399: 8, 400: 9, 5000: 9}
	for year: int in edges:
		assert_eq(MapModes.yield_band(year), int(edges[year]), "band of %d" % year)


func test_mode_keys_and_mode_of() -> void:
	assert_eq(MapModes.MODE_KEYS, [&"terrain", &"owner", &"relief", &"yields", &"food", &"supply"] as Array[StringName])
	assert_eq(MapModes.mode_of(&"terrain"), MapModes.Mode.TERRAIN)
	assert_eq(MapModes.mode_of(&"yields"), MapModes.Mode.YIELDS)
	assert_eq(MapModes.mode_of(&"food"), MapModes.Mode.FOOD)
	assert_eq(MapModes.mode_of(&"supply"), MapModes.Mode.SUPPLY)
	assert_eq(MapModes.mode_of(&""), -1)


func test_yield_ramp_entries() -> void:
	var ramp := MapModes.yield_ramp()
	assert_eq(ramp.size(), 256)
	assert_eq(ramp[0], Color(0.0, 0.0, 0.0, 0.0))
	for b: int in range(1, 10):
		assert_eq(ramp[b], MapModes.YIELD_COLOURS[b - 1], "byte %d" % b)
	assert_eq(ramp[10], Color(0.0, 0.0, 0.0, 0.0))
	assert_eq(ramp[255], Color(0.0, 0.0, 0.0, 0.0))


func test_yield_colour_distances() -> void:
	var cols := MapModes.YIELD_COLOURS
	for b: int in range(2, 9):  # bytes 2 to 9 are cols[1] to cols[8]
		assert_gte(ColourContrast.worst_delta_e(cols[b - 1], cols[b]), 6.0, "bytes %d and %d" % [b, b + 1])
	for b: int in range(2, 10):
		assert_gte(ColourContrast.worst_delta_e(MapModes.VEIL, cols[b - 1]), 15.0, "veil against byte %d" % b)
		assert_gte(ColourContrast.worst_delta_e(cols[0], cols[b - 1]), 15.0, "madder against byte %d" % b)


func test_colour_of_yields() -> void:
	var pal := MapModes.palette_from(PackedColorArray(), MapModes.DEFAULT_UNOWNED)
	var clear := Color(0.0, 0.0, 0.0, 0.0)
	for yb: int in range(0, 10):
		assert_eq(MapModes.colour_of(MapModes.Mode.YIELDS, 1, 0, pal, true, 0, yb), clear, "sea is clear at byte %d" % yb)
	var veil := MapModes.colour_of(MapModes.Mode.YIELDS, 1, 5, pal, true, 0, 0)
	assert_eq(Color(veil.r, veil.g, veil.b), MapModes.VEIL)
	assert_almost_eq(veil.a, 0.45, 0.0001)
	assert_eq(MapModes.colour_of(MapModes.Mode.YIELDS, 1, 5, pal, true, 0), veil, "no byte given is the veil")
	var loss := MapModes.colour_of(MapModes.Mode.YIELDS, 1, 5, pal, true, 0, 1)
	assert_eq(Color(loss.r, loss.g, loss.b), Color("#a8321a"))
	for yb: int in range(1, 10):
		var c := MapModes.colour_of(MapModes.Mode.YIELDS, 1, 5, pal, true, 0, yb)
		assert_eq(Color(c.r, c.g, c.b), MapModes.YIELD_COLOURS[yb - 1], "byte %d" % yb)
		assert_almost_eq(c.a, 0.70, 0.0001)
	# The hover highlight does not touch Yields.
	assert_eq(MapModes.colour_of(MapModes.Mode.YIELDS, 1, 5, pal, true, 1, 6),
		MapModes.colour_of(MapModes.Mode.YIELDS, 1, 5, pal, true, 0, 6))


func test_legend() -> void:
	for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.OWNER, MapModes.Mode.RELIEF]:
		assert_eq(MapModes.legend(mode).size(), 0)
	var rows := MapModes.legend(MapModes.Mode.YIELDS)
	var texts: Array[String] = []
	for row: Dictionary in rows:
		texts.append(str(row["text"]))
	assert_eq(texts, ["400 and more", "200 to 399", "100 to 199", "50 to 99", "25 to 49", "10 to 24", "1 to 9", "Nothing",
		"A loss", "Not your land"] as Array[String])
	assert_eq(rows[0]["colour"], Color("#0b3f3c"))
	assert_eq(rows[7]["colour"], Color("#efe3c4"))
	assert_true(bool(rows[8]["stripes"]))
	assert_eq(rows[8]["colour"], Color("#a8321a"))
	assert_eq(rows[9]["colour"], MapModes.VEIL)
	for r: int in range(0, 8):
		assert_false(bool(rows[r]["stripes"]))
	assert_false(bool(rows[9]["stripes"]))


func test_yield_bytes_of_genoa_at_turn_one() -> void:
	var game := EconomyFixture.game(&"GEN")
	var map := game.map
	var bytes := MapModes.yield_bytes(game, &"GEN")
	assert_eq(bytes.size(), map.hex_count())
	var named: Dictionary = {Vector2i(8, 13): 8, Vector2i(7, 14): 7, Vector2i(7, 12): 6, Vector2i(6, 13): 5,
		Vector2i(9, 13): 5, Vector2i(7, 13): 4}
	for hex: Vector2i in named:
		assert_eq(int(bytes[map.index_of(hex)]), int(named[hex]), "byte of %s" % hex)
	var counts: Dictionary = {}
	var genoa := Countries.by_tag(game, &"GEN")
	for i: int in map.hex_count():
		if map.land[i] == 0 or int(game.state.owner[i]) != genoa.id:
			assert_eq(int(bytes[i]), 0, "not Genoa's land: hex %d is 0" % i)
		else:
			counts[int(bytes[i])] = int(counts.get(int(bytes[i]), 0)) + 1
	assert_eq(int(counts.get(3, 0)), 6, "the six woods")
	assert_eq(int(counts.get(2, 0)), 2, "the two rocks")
	assert_eq(int(counts.get(1, 0)), 0, "no loss")


func test_yield_bytes_planted_milan_hex_is_zero_and_wild_land_is_its_own_band() -> void:
	var game := EconomyFixture.game(&"GEN")
	var milan := Countries.by_tag(game, &"MLO")
	var found := 0
	for i: int in game.map.hex_count():
		if game.map.land[i] != 0 and int(game.state.owner[i]) == milan.id:
			found += 1
			assert_eq(int(MapModes.yield_bytes(game, &"GEN")[i]), 0, "a Milan hex is 0 (veiled)")
			var pal := MapModes.palette(game, false)
			var col := MapModes.colour_at(game, MapModes.Mode.YIELDS, game.map.hex_of(i), pal, true, 0)
			assert_eq(Color(col.r, col.g, col.b), MapModes.VEIL)
			assert_almost_eq(col.a, MapModes.VEIL_ALPHA, 0.0001)
			if found >= 5:
				break
	assert_gt(found, 0, "Milan holds land")
	# Genoa's vineyard made wild: still Genoa's land, so a band of its own, not the veil.
	var wild := EconomyFixture.game(&"GEN", true)
	var b := int(MapModes.yield_bytes(wild, &"GEN")[wild.map.index_of(EconomyFixture.VINEYARD_HEX)])
	assert_between(b, 2, 9, "wild land of yours has a band")
	assert_ne(b, 6, "and not the vineyard's")
	# A map-only game and no viewer give all zeros.
	var sandbox := Game.new_game(_make_map(4, 3), 1480)
	assert_eq(MapModes.yield_bytes(sandbox, &"GEN").size(), 12)
	assert_eq(MapModes.yield_bytes(sandbox, &"GEN").count(0), 12)
	assert_eq(MapModes.yield_bytes(game, &"").count(0), game.map.hex_count())


func test_colour_at_yields_reads_the_players_bytes() -> void:
	var game := EconomyFixture.game(&"GEN")
	var pal := MapModes.palette(game, false)
	var genoa := MapModes.colour_at(game, MapModes.Mode.YIELDS, Vector2i(8, 13), pal, true, 0)
	assert_eq(Color(genoa.r, genoa.g, genoa.b), MapModes.YIELD_COLOURS[7], "Genoa is byte 8")
	assert_almost_eq(genoa.a, 0.70, 0.0001)
	var sea := Vector2i(-1, -1)
	for i: int in game.map.hex_count():
		if game.map.land[i] == 0:
			sea = game.map.hex_of(i)
			break
	assert_eq(MapModes.colour_at(game, MapModes.Mode.YIELDS, sea, pal, true, 0), Color(0.0, 0.0, 0.0, 0.0))


func test_modes_with_yields() -> void:
	var all: Array[int] = [MapModes.Mode.TERRAIN, MapModes.Mode.OWNER, MapModes.Mode.RELIEF, MapModes.Mode.YIELDS,
		MapModes.Mode.FOOD, MapModes.Mode.SUPPLY]
	assert_eq(MapModes.modes(EconomyFixture.game(&"GEN")), all)
	assert_eq(MapModes.modes(EconomyFixture.game()),
		[MapModes.Mode.TERRAIN, MapModes.Mode.OWNER, MapModes.Mode.RELIEF] as Array[int],
		"countries but no chosen player: no Yields")
	assert_eq(MapModes.modes(Game.new_game(_make_map(4, 3), 1480)),
		[MapModes.Mode.TERRAIN, MapModes.Mode.RELIEF] as Array[int])
	assert_eq(MapModes.modes(null), [MapModes.Mode.TERRAIN, MapModes.Mode.RELIEF] as Array[int])


# --- Food (docs/architecture/m5-build-spec.md 5.6, 4.11 (f)) ---------------------------------------------------------


func test_food_band_edges() -> void:
	var edges: Dictionary = {-11: 1, -10: 1, -9: 2, -1: 2, 0: 3, 1: 4, 4: 4, 5: 5, 9: 5, 10: 6, 19: 6, 20: 7, 39: 7,
		40: 8, 500: 8}
	for net: int in edges:
		assert_eq(MapModes.food_band(net), int(edges[net]), "band of %d" % net)


func test_food_ramp_entries() -> void:
	var ramp := MapModes.food_ramp()
	assert_eq(ramp.size(), 256)
	assert_eq(ramp[0], Color(0.0, 0.0, 0.0, 0.0))
	for b: int in range(1, 9):
		assert_eq(ramp[b], MapModes.FOOD_COLOURS[b - 1], "byte %d" % b)
	assert_eq(ramp[9], Color(0.0, 0.0, 0.0, 0.0))
	assert_eq(ramp[255], Color(0.0, 0.0, 0.0, 0.0))


func test_food_colour_distances() -> void:
	var cols := MapModes.FOOD_COLOURS
	for b: int in range(3, 8):  # bytes 3 to 8 are cols[2] to cols[7]
		assert_gte(ColourContrast.worst_delta_e(cols[b - 1], cols[b]), 6.0, "bytes %d and %d" % [b, b + 1])
	for b: int in range(1, 9):
		assert_gte(ColourContrast.worst_delta_e(MapModes.VEIL, cols[b - 1]), 15.0, "veil against byte %d" % b)
	for b: int in range(2, 9):
		assert_gte(ColourContrast.worst_delta_e(cols[0], cols[b - 1]), 15.0, "byte 1 against byte %d" % b)
	for b: int in [1, 2]:
		assert_gte(ColourContrast.worst_delta_e(cols[b - 1], cols[2]), 15.0, "byte %d against byte 3" % b)


func test_colour_of_food() -> void:
	var pal := MapModes.palette_from(PackedColorArray(), MapModes.DEFAULT_UNOWNED)
	var clear := Color(0.0, 0.0, 0.0, 0.0)
	for fb: int in range(0, 9):
		assert_eq(MapModes.colour_of(MapModes.Mode.FOOD, 1, 0, pal, true, 0, 0, fb), clear, "sea at byte %d" % fb)
	var veil := MapModes.colour_of(MapModes.Mode.FOOD, 1, 5, pal, true, 0, 0, 0)
	assert_eq(Color(veil.r, veil.g, veil.b), MapModes.VEIL)
	assert_almost_eq(veil.a, MapModes.VEIL_ALPHA, 0.0001)
	for fb: int in range(1, 9):
		var c := MapModes.colour_of(MapModes.Mode.FOOD, 1, 5, pal, true, 0, 0, fb)
		assert_eq(Color(c.r, c.g, c.b), MapModes.FOOD_COLOURS[fb - 1], "byte %d" % fb)
		assert_almost_eq(c.a, 0.70, 0.0001)
	assert_eq(MapModes.colour_of(MapModes.Mode.FOOD, 1, 5, pal, true, 1, 0, 6),
		MapModes.colour_of(MapModes.Mode.FOOD, 1, 5, pal, true, 0, 0, 6), "no hover highlight")


func test_food_legend_and_titles() -> void:
	var rows := MapModes.legend(MapModes.Mode.FOOD)
	var texts: Array[String] = []
	for row: Dictionary in rows:
		texts.append(str(row["text"]))
	assert_eq(texts, ["40 and more", "20 to 39", "10 to 19", "5 to 9", "1 to 4", "Nothing", "Short by 1 to 9",
		"Short by 10 or more", "Not your land"] as Array[String])
	for r: int in rows.size():
		assert_eq(bool(rows[r]["stripes"]), r == 6 or r == 7, "stripes of row %d" % r)
	assert_eq(rows[0]["colour"], MapModes.FOOD_COLOURS[7])
	assert_eq(rows[6]["colour"], MapModes.FOOD_COLOURS[1])
	assert_eq(rows[7]["colour"], MapModes.FOOD_COLOURS[0])
	assert_eq(rows[8]["colour"], MapModes.VEIL)
	assert_eq(MapModes.legend_title(MapModes.Mode.FOOD), "Food: made less eaten, a year")
	assert_eq(MapModes.legend_title(MapModes.Mode.YIELDS), "Yields: worth a year")
	assert_eq(MapModes.legend_title(MapModes.Mode.TERRAIN), "")


func test_food_year_of_genoa_and_savona() -> void:
	var game := EconomyFixture.game(&"GEN")
	assert_eq(MapModes.food_year(game, &"GEN", Vector2i(8, 13)), Vector2i(22, 12), "Genoa: fish 22, eaten 12")
	assert_eq(MapModes.food_year(game, &"GEN", Vector2i(6, 13)), Vector2i(6, 4), "Savona: grain 6, eaten 4")
	assert_eq(MapModes.food_year(game, &"GEN", Vector2i(-1, -1)), Vector2i.ZERO, "off the map")
	assert_eq(MapModes.food_year(game, &"", Vector2i(8, 13)), Vector2i.ZERO, "no viewer")


func test_food_bytes_of_genoa_at_turn_one() -> void:
	var game := EconomyFixture.game(&"GEN")
	var map := game.map
	var bytes := MapModes.food_bytes(game, &"GEN")
	assert_eq(bytes.size(), map.hex_count())
	assert_eq(int(bytes[map.index_of(Vector2i(8, 13))]), 6, "Genoa +10")
	assert_eq(int(bytes[map.index_of(Vector2i(6, 13))]), 4, "Savona +2")
	assert_eq(int(bytes[map.index_of(Vector2i(7, 13))]), 5, "the wild farmland's 7 grain")
	var genoa := Countries.by_tag(game, &"GEN")
	for i: int in map.hex_count():
		if map.land[i] == 0 or int(game.state.owner[i]) != genoa.id:
			assert_eq(int(bytes[i]), 0, "not Genoa's land: hex %d is 0" % i)
		elif map.index_of(Vector2i(8, 13)) != i and map.index_of(Vector2i(6, 13)) != i \
				and map.index_of(Vector2i(7, 13)) != i:
			assert_eq(int(bytes[i]), 3, "every other hex of Genoa is 3 (hex %d)" % i)


func test_food_bytes_planted_milan_hex_is_zero() -> void:
	var game := EconomyFixture.game(&"GEN")
	var milan := Countries.by_tag(game, &"MLO")
	var found := 0
	var pal := MapModes.palette(game, false)
	for i: int in game.map.hex_count():
		if game.map.land[i] != 0 and int(game.state.owner[i]) == milan.id:
			found += 1
			assert_eq(int(MapModes.food_bytes(game, &"GEN")[i]), 0, "a Milan hex is 0 (veiled)")
			assert_eq(MapModes.food_year(game, &"GEN", game.map.hex_of(i)), Vector2i.ZERO)
			var col := MapModes.colour_at(game, MapModes.Mode.FOOD, game.map.hex_of(i), pal, true, 0)
			assert_eq(Color(col.r, col.g, col.b), MapModes.VEIL)
			if found >= 5:
				break
	assert_gt(found, 0, "Milan holds land")
	var sandbox := Game.new_game(_make_map(4, 3), 1480)
	assert_eq(MapModes.food_bytes(sandbox, &"GEN").count(0), 12)
	assert_eq(MapModes.food_bytes(game, &"").count(0), game.map.hex_count())
	var genoa := MapModes.colour_at(game, MapModes.Mode.FOOD, Vector2i(8, 13), pal, true, 0)
	assert_eq(Color(genoa.r, genoa.g, genoa.b), MapModes.FOOD_COLOURS[5], "Genoa is byte 6")
