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
