## Unit tests for AreaLines (castle-area lines, the tint, held_by), the occupier and area parts of MapModes, and the war rows
## of HexCard (docs/architecture/m7-build-spec.md 4.3, 4.15, 5.6, 6.3, 6.8; M7 plan B15). Every game is WarFixture.game()
## (fresh, copied definitions); the planted faults are written into that game's state before the first read.
extends GutTest

const PAVIA := Vector2i(10, 9)  # Milan's walled castle, level 2, area of 7 hexes on seed 1480 (4.3)

var _g: Game = null
var _me: StringName = &""
var _foe: StringName = &""


func before_each() -> void:
	_g = WarFixture.game()
	_me = ArmyFixture.TAG
	_foe = &"MLO"


## Every chunk of the map, as the shell asks for them.
func _all_lines(viewer: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cx_max := ceili(float(_g.map.cols) / float(EdgeLines.CHUNK))
	var cy_max := ceili(float(_g.map.rows) / float(EdgeLines.CHUNK))
	for cy: int in cy_max:
		for cx: int in cx_max:
			out.append_array(AreaLines.for_chunk(_g, viewer, Vector2i(cx, cy)))
	return out


## The edges the lines must draw, counted from the bytes and the war cache alone: each outer edge of a held area once. An
## edge to a hex outside every held area is drawn from its held side; an edge between two held areas is drawn once, from
## the lower hex index; the map's edge has none.
func _expected_edges(viewer: StringName) -> int:
	var bytes := AreaLines.area_bytes(_g, viewer)
	var areas := _g.war_cache.area_index(_g)
	var total := 0
	for i: int in bytes.size():
		if bytes[i] == 0:
			continue
		var hex := _g.map.hex_of(i)
		for d: int in 6:
			var o := _g.map.index_of(_g.map.neighbour(hex, d))
			if o < 0:
				continue
			if bytes[o] != 0:
				if areas[o] == areas[i]:
					continue
				if o < i:
					continue
			total += 1
	return total


## The key of a line's edge: its two corners, rounded, sorted, so the same edge drawn from either side has one key.
func _edge_key(line: Dictionary) -> String:
	var p := line["points"] as PackedVector2Array
	var a := "%.2f,%.2f" % [p[0].x, p[0].y]
	var b := "%.2f,%.2f" % [p[1].x, p[1].y]
	return a + "|" + b if a < b else b + "|" + a


func _row(lines: Array, label: String) -> Array:
	for row: Variant in lines:
		if str((row as Array)[0]) == label:
			return row as Array
	return []


# --- the area bytes and the held state -------------------------------------------------------------------------------


func test_pavia_area_is_seven_hexes_and_held_when_at_war() -> void:
	assert_eq(Occupation.members(_g, PAVIA).size(), 7)
	assert_eq(AreaLines.area_bytes(_g, _me).size(), _g.map.hex_count())
	# No war yet: nothing is tinted or lined.
	assert_eq(AreaLines.area_bytes(_g, _me).count(1), 0)
	WarFixture.at_war(_g, _me, _foe)
	_g.version += 1  # a war change moves the version (Game.emit); the fixture writes state directly, so bump it here
	var bytes := AreaLines.area_bytes(_g, _me)
	for i: int in Occupation.members(_g, PAVIA):
		assert_eq(bytes[i], 1, "member %d is in the held area" % i)
	# A hex of Milan outside every held area is not tinted.
	var areas := _g.war_cache.area_index(_g)
	for i: int in _g.map.hex_count():
		if int(_g.state.owner[i]) == Countries.by_tag(_g, _foe).id and areas[i] < 0 and _g.map.land[i] == 1:
			assert_eq(bytes[i], 0, "open Milan land at %s has no tint" % str(_g.map.hex_of(i)))
			break


func test_viewer_sees_no_area_of_its_own_castle_and_none_without_a_war() -> void:
	WarFixture.at_war(_g, _me, _foe)
	# Milan's own castle is not an enemy's castle for Milan: its area has no tint and no line for Milan. (Genoa's castles
	# share this chunk and are Milan's enemies' areas, so their lines are the only ones here.)
	assert_eq(AreaLines.area_bytes(_g, _foe)[Occupation.members(_g, PAVIA)[1]], 0)
	var me_id := Countries.by_tag(_g, _me).id
	var near := AreaLines.for_chunk(_g, _foe, EdgeLines.chunk_of(PAVIA))
	assert_true(near.size() > 0)
	for line: Dictionary in near:
		assert_eq(int(line["colour_id"]), me_id, "every line in the chunk is Genoa's castle area")
	# The viewer "" has no enemies at all.
	assert_eq(AreaLines.area_bytes(_g, &"").count(1), 0)


func test_fallen_area_keeps_no_tint_and_no_line() -> void:
	WarFixture.at_war(_g, _me, _foe)
	WarFixture.set_occupier(_g, PAVIA, _me)  # the castle is taken: its area falls (4.3)
	var bytes := AreaLines.area_bytes(_g, _me)
	for i: int in Occupation.members(_g, PAVIA):
		assert_eq(bytes[i], 0, "fallen member %d keeps no tint" % i)
	var fallen := AreaLines.held_by(_g, _g.map.hex_of(Occupation.members(_g, PAVIA)[1]))
	assert_eq(fallen["state"], &"fallen")
	assert_true(bool(fallen["fallen"]))
	assert_eq(fallen["fortress"], PAVIA)


# --- the lines -------------------------------------------------------------------------------------------------------


func test_lines_sit_on_every_outer_edge_and_none_inside() -> void:
	WarFixture.at_war(_g, _me, _foe)
	var lines := _all_lines(_me)
	assert_eq(lines.size(), _expected_edges(_me), "one line per outer edge of a held area")
	assert_true(lines.size() > 0)
	var foe_id := Countries.by_tag(_g, _foe).id
	for line: Dictionary in lines:
		assert_eq(str(line["kind"]), "area")
		assert_true(bool(line["dashed"]))
		assert_eq(int(line["colour_id"]), foe_id, "lines take the owner's colour")
		assert_eq((line["points"] as PackedVector2Array).size(), 2)
		assert_eq(float(line["width"]), AreaLines.WIDTH)
	# Pavia's own outer edges: a line at each of its outer edges, drawn by its chunk.
	var pavia_lines := AreaLines.for_chunk(_g, _me, EdgeLines.chunk_of(PAVIA))
	assert_true(pavia_lines.size() > 0)


func test_every_edge_is_drawn_exactly_once_over_the_whole_map() -> void:
	# Where two held areas meet on a shared edge, that edge is drawn once (the lower hex index's side), never twice.
	WarFixture.at_war(_g, _me, _foe)
	_g.version += 1
	var keys: Dictionary = {}
	var lines := _all_lines(_me)
	for line: Dictionary in lines:
		var key := _edge_key(line)
		assert_false(keys.has(key), "edge %s is drawn twice" % key)
		keys[key] = true
	assert_eq(keys.size(), _expected_edges(_me), "the count equals the independent recount")
	assert_eq(lines.size(), keys.size())


func test_planted_fault_an_inside_edge_gets_a_line_is_caught() -> void:
	# A planted fault: draw the lines of a hex with every neighbour counted as outside. The real count is smaller on the
	# area's inside edges, so the count of the real lines must differ from the planted one.
	WarFixture.at_war(_g, _me, _foe)
	var bytes := AreaLines.area_bytes(_g, _me)
	var planted := 0
	var real := 0
	for i: int in bytes.size():
		if bytes[i] == 0:
			continue
		var hex := _g.map.hex_of(i)
		for d: int in 6:
			if _g.map.index_of(_g.map.neighbour(hex, d)) >= 0:
				planted += 1
	real = _all_lines(_me).size()
	assert_true(real < planted, "the inside edges of the area have no line (%d < %d)" % [real, planted])


func test_no_lines_on_open_land_or_fallen_area() -> void:
	WarFixture.at_war(_g, _me, _foe)
	WarFixture.set_occupier(_g, PAVIA, _me)
	assert_eq(_all_lines(_me).size(), _expected_edges(_me))
	var near := AreaLines.for_chunk(_g, _me, EdgeLines.chunk_of(PAVIA))
	for line: Dictionary in near:
		assert_true(int(line["colour_id"]) == Countries.by_tag(_g, _foe).id)
	assert_eq(_expected_edges(_me), _all_lines(_me).size())


func test_chunks_touched_holds_the_castle_chunk() -> void:
	var hexes: Array[Vector2i] = [PAVIA]
	var touched := AreaLines.chunks_touched(_g, hexes)
	assert_true(touched.has(EdgeLines.chunk_of(PAVIA)))


# --- held_by and the castle's name -----------------------------------------------------------------------------------


func test_held_by_names_the_castle_and_its_distance() -> void:
	WarFixture.at_war(_g, _me, _foe)
	var castle := AreaLines.held_by(_g, PAVIA)
	assert_eq(castle["state"], &"castle")
	assert_eq(castle["fortress"], PAVIA)
	assert_eq(str(castle["name"]), "the castle of Pavia")
	assert_eq(int(castle["members"]), 7)
	assert_eq(int(castle["distance"]), 0)
	var member: int = Occupation.members(_g, PAVIA)[1]
	var near := AreaLines.held_by(_g, _g.map.hex_of(member))
	assert_eq(near["state"], &"held")
	assert_eq(near["fortress"], PAVIA)
	assert_true(int(near["distance"]) >= 1 and int(near["distance"]) <= 2)
	# Land with no castle holding it.
	var far := AreaLines.held_by(_g, Vector2i(0, 0))
	assert_eq(int(far["distance"]), -1)


# --- the map modes: occupier, stripes, area tint ---------------------------------------------------------------------


func test_occupier_colour_replaces_the_owners_in_owner_and_terrain() -> void:
	var c1 := Color("#be3c6e")
	var c2 := Color("#3460b2")
	var pal := MapModes.palette_from(PackedColorArray([c1, c2]), Color("#d8ccb0"))
	# Owner 1 occupied by country 2: the occupier's colour, alpha kept.
	var owner_occ := MapModes.colour_of(MapModes.Mode.OWNER, 1, 5, pal, true, 0, 0, 0, 0, 1, false, 2)
	assert_true(owner_occ.is_equal_approx(Color(c2.r, c2.g, c2.b, MapModes.OWNER_ALPHA)))
	var terrain_occ := MapModes.colour_of(MapModes.Mode.TERRAIN, 1, 5, pal, true, 0, 0, 0, 0, 1, false, 2)
	assert_true(terrain_occ.is_equal_approx(Color(c2.r, c2.g, c2.b, MapModes.TINT_ALPHA)))
	# Relief has no stripes: the occupier changes nothing there.
	var relief := MapModes.colour_of(MapModes.Mode.RELIEF, 1, 26, pal, true, 0, 0, 0, 0, 1, false, 2)
	assert_eq(relief, MapModes.colour_of(MapModes.Mode.RELIEF, 1, 26, pal, true, 0))
	# Planted fault: occupier equal to the owner, or 0, changes nothing.
	assert_eq(MapModes.colour_of(MapModes.Mode.OWNER, 1, 5, pal, true, 0, 0, 0, 0, 1, false, 1),
		MapModes.colour_of(MapModes.Mode.OWNER, 1, 5, pal, true, 0))
	assert_eq(MapModes.colour_of(MapModes.Mode.OWNER, 1, 5, pal, true, 0, 0, 0, 0, 1, false, 0),
		MapModes.colour_of(MapModes.Mode.OWNER, 1, 5, pal, true, 0))


func test_occupier_stripes_use_each_palette() -> void:
	# Both palettes of the game: the standard and the colour-blind one give the occupier its own palette colour.
	for blind: bool in [false, true]:
		var pal := MapModes.palette(_g, blind)
		var pick := 2
		var c := MapModes.colour_of(MapModes.Mode.OWNER, 1, 5, pal, true, 0, 0, 0, 0, 1, false, pick)
		assert_true(c.is_equal_approx(Color(pal[pick].r, pal[pick].g, pal[pick].b, MapModes.OWNER_ALPHA)),
			"colour-blind %s" % str(blind))


func test_stripe_bands_alternate_every_eight_pixels() -> void:
	assert_true(MapModes.stripe_is_occupier(0, 0))
	assert_true(MapModes.stripe_is_occupier(7, 0))
	assert_false(MapModes.stripe_is_occupier(8, 0))
	assert_false(MapModes.stripe_is_occupier(0, 8))
	assert_true(MapModes.stripe_is_occupier(8, 8))
	assert_eq(MapModes.OCCUPIED_STRIPE_PX, 8.0)


func test_area_tint_mixes_the_owners_colour_at_twelve_percent() -> void:
	var c1 := Color("#be3c6e")
	var pal := MapModes.palette_from(PackedColorArray([c1]), Color("#d8ccb0"))
	var tinted := MapModes.colour_of(MapModes.Mode.OWNER, 1, 5, pal, true, 0, 0, 0, 0, 1, false, 0, 1)
	var base_alpha := MapModes.OWNER_ALPHA
	assert_true(absf(tinted.a - (MapModes.AREA_ALPHA + base_alpha * (1.0 - MapModes.AREA_ALPHA))) < 0.0001)
	assert_true(absf(tinted.r - c1.r) < 0.0001 and absf(tinted.g - c1.g) < 0.0001)
	# The yield, food and supply modes keep their own colour: the tint changes nothing there.
	for mode: int in [MapModes.Mode.YIELDS, MapModes.Mode.FOOD, MapModes.Mode.SUPPLY]:
		assert_eq(MapModes.colour_of(mode, 1, 5, pal, true, 0, 3, 3, 1, 1, false, 0, 1),
			MapModes.colour_of(mode, 1, 5, pal, true, 0, 3, 3, 1, 1, false, 0, 0))


func test_occupied_legend_has_the_stripes_and_the_area_row() -> void:
	var rows := MapModes.occupied_legend()
	assert_eq(rows.size(), 2)
	assert_true(bool(rows[0]["stripes"]))
	assert_false(bool(rows[0]["area"]))
	assert_true(bool(rows[1]["area"]))
	assert_false(bool(rows[1]["stripes"]))


func test_occupier_bytes_are_the_occupier_ids() -> void:
	WarFixture.set_occupier(_g, PAVIA, _me)
	var bytes := MapModes.occupier_bytes(_g)
	assert_eq(int(bytes[_g.map.index_of(PAVIA)]), Countries.by_tag(_g, _me).id)
	assert_eq(MapModes.occupier_bytes(null).size(), 0)


func test_colour_at_reads_the_occupier_and_the_area() -> void:
	WarFixture.at_war(_g, _me, _foe)
	var pal := MapModes.palette(_g, false)
	var idx: int = Occupation.members(_g, PAVIA)[1]
	var member := _g.map.hex_of(idx)
	var height := int(MapModes.height_bytes(_g.map)[idx])
	var owner := Territory.owner_id(_g, member)
	# A held hex of an enemy's area: the owner's colour with the 12 % tint.
	var tinted := MapModes.colour_of(MapModes.Mode.OWNER, owner, height, pal, true, 0, 0, 0, 0, 1, false, 0, 1)
	assert_eq(MapModes.colour_at(_g, MapModes.Mode.OWNER, member, pal, true, 0), tinted)
	# Occupied (a write the game would batch into a flush: the version moves with it): the occupier's colour, no tint.
	WarFixture.set_occupier(_g, member, _me)
	_g.version += 1
	var me_id := Countries.by_tag(_g, _me).id
	var occupied := MapModes.colour_of(MapModes.Mode.OWNER, owner, height, pal, true, 0, 0, 0, 0, 1, false, me_id, 0)
	assert_eq(MapModes.colour_at(_g, MapModes.Mode.OWNER, member, pal, true, 0), occupied)


# --- the hex card's war rows -----------------------------------------------------------------------------------------


func test_hex_card_castle_row_is_for_the_viewer_at_war_only() -> void:
	var member: Vector2i = _g.map.hex_of(Occupation.members(_g, PAVIA)[1])
	assert_eq(_row(HexCard.of(_g, member)["lines"], "Castle area"), [])
	WarFixture.at_war(_g, _me, _foe)
	var row := _row(HexCard.of(_g, member)["lines"], "Castle area")
	assert_eq(str(row[2]), "Held by the castle of Pavia (10, 9), 7 hexes")
	var castle := _row(HexCard.of(_g, PAVIA)["lines"], "Castle area")
	assert_eq(str(castle[2]), "This is the castle of Pavia (10, 9), 7 hexes")


func test_hex_card_fallen_castle_and_held_by_rows() -> void:
	WarFixture.at_war(_g, _me, _foe)
	var member: Vector2i = _g.map.hex_of(Occupation.members(_g, PAVIA)[1])
	var stranger := WarFixture.stranger_of(_g, _me)
	WarFixture.set_occupier(_g, PAVIA, _me)
	var fallen := _row(HexCard.of(_g, member)["lines"], "Castle area")
	assert_eq(str(fallen[2]), "Open: the castle of Pavia (10, 9) has fallen")
	# Occupied land carries "Held by" for everyone (public, 4.15).
	WarFixture.set_occupier(_g, member, stranger)
	var held := _row(HexCard.of(_g, member)["lines"], "Held by")
	assert_eq(str(held[2]), "the " + Occupation.occupier_long_name(_g, member))


func test_hex_card_garrison_is_exact_to_the_owner_and_hidden_otherwise() -> void:
	_g.player = _foe
	var owner_row := _row(HexCard.of(_g, PAVIA)["lines"], "Fortress")
	assert_true(str(owner_row[2]).ends_with("garrison 800 of 800"), str(owner_row[2]))
	# Planted fault: the card reads the garrison the state holds.
	_g.state.garrison[_g.map.index_of(PAVIA)] = 123
	assert_true(str(_row(HexCard.of(_g, PAVIA)["lines"], "Fortress")[2]).ends_with("garrison 123 of 800"))
	# A viewer that does not see the hex but has discovered it reads the garrison exact (R19: hidden only when undiscovered).
	_g.player = _me
	var fortress_hex := Vector2i(-1, -1)
	var fortresses := _g.war_cache.fortresses(_g)
	for i: int in fortresses:
		var hex := _g.map.hex_of(i)
		if not Knowledge.sees(_g, _me, hex) and Knowledge.discovered(_g, _me, hex):
			fortress_hex = hex
			break
	assert_true(fortress_hex != Vector2i(-1, -1), "a fortress the viewer has discovered but does not see")
	var seen := _row(HexCard.of(_g, fortress_hex)["lines"], "Fortress")
	var exact := "garrison %d of %d" % [Occupation.garrison_of(_g, fortress_hex), Occupation.garrison_full(_g, fortress_hex)]
	assert_true(str(seen[2]).ends_with(exact), str(seen[2]))
	# An undiscovered fortress gives no card at all: a thin start (FogFixture) leaves the far fortresses dark.
	FogFixture.thin(_g, _me, 0)
	var dark := Vector2i(-1, -1)
	for i: int in fortresses:
		var hex := _g.map.hex_of(i)
		if not Knowledge.discovered(_g, _me, hex):
			dark = hex
			break
	assert_true(dark != Vector2i(-1, -1), "a fortress the viewer has not discovered")
	assert_eq(_row(HexCard.of(_g, dark)["lines"], "Fortress"), [], "no fortress row on an undiscovered hex")


func test_hex_card_siege_row_is_exact_to_the_besieger_and_the_defender() -> void:
	var s := Siege.new()
	s.hex = PAVIA
	s.besieger = _me
	s.progress = 6
	s.name = "Pavia"
	_g.sieges.append(s)
	# A siege shows only between countries at war (Knowledge.siege_access): the holder of the castle and the besieger fight.
	WarFixture.at_war(_g, _me, Occupation.controller_tag(_g, PAVIA))
	_g.player = _me
	var row := _row(HexCard.of(_g, PAVIA)["lines"], "Siege")
	assert_eq(str(row[2]), "Pavia is besieged by Genoa: 6 of %d" % Occupation.siege_need(_g, PAVIA))
	# A stranger that has discovered the hex but does not see it reads the land level: "Besieged", no besieger (R21).
	# A stranger that has not discovered it sees no siege row at all.
	var stranger := WarFixture.stranger_of(_g, _me)
	_g.player = stranger
	var srow := _row(HexCard.of(_g, PAVIA)["lines"], "Siege")
	if Knowledge.sees(_g, stranger, PAVIA):
		assert_true(str(srow[2]).contains("besieged by"), str(srow))
	elif Knowledge.discovered(_g, stranger, PAVIA):
		assert_true(str(srow[2]).contains("Besieged"), str(srow))
		assert_false(str(srow[2]).contains("besieged by"), "no besieger's name on land: %s" % str(srow))
	else:
		assert_eq(srow, [])
