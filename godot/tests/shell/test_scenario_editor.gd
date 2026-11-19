## Headless GUT tests for ScenarioEditor (docs/architecture/m2-build-spec.md sections 8.4 and 10):
## opening north_italy_1480, live pin painting -> ModeOverlay & border mesh rebuild,
## Write to user:// + Check with 0 lines, erase restoring grown owner, redundant pin drop,
## seed/unowned brushes, inspect_hex facts, colour-blind/mode switches, and planted validation faults.
extends GutTest

const EDITOR_SCENE_PATH := "res://shell/editor/scenario_editor.tscn"
const TEMP_SCEN_PATH := "user://test_scenario_editor_c12.tres"
const TARGET_HEX := Vector2i(14, 17)  # Sienese land hex bordering Florence in north_italy_1480

var _editor: ScenarioEditor = null


func before_each() -> void:
	var packed := load(EDITOR_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	_editor = packed.instantiate() as ScenarioEditor
	assert_not_null(_editor)
	add_child_autofree(_editor)


func after_each() -> void:
	var abs_tmp := ProjectSettings.globalize_path(TEMP_SCEN_PATH)
	if FileAccess.file_exists(abs_tmp):
		DirAccess.remove_absolute(abs_tmp)
	_editor = null
	await get_tree().process_frame


func _border_vertices_of_chunk(chunk: Vector2i) -> PackedVector2Array:
	var borders := _editor.view().get_node("Borders") as Node2D
	var node := borders.get_node_or_null("Borders_%d_%d" % [chunk.x, chunk.y]) as EdgeLineLayer
	return node.vertices().duplicate() if node != null else PackedVector2Array()


func _use_scenario_copy() -> ScenarioDef:
	var copy := _editor.scenario.duplicate(true) as ScenarioDef
	copy.resource_path = ""
	_editor.scenario = copy
	return copy


func test_opens_north_italy_1480_with_layers_and_passes_check() -> void:
	assert_not_null(_editor.scenario)
	assert_eq(_editor.scenario.id, "north_italy_1480")
	assert_not_null(_editor.map_data())
	assert_not_null(_editor.defs())
	assert_true(_editor.live_regrow)
	assert_gt(_editor.view().cell_count(), _editor.map_data().hex_count())
	assert_gt(_editor.view().border_chunks().size(), 0)
	assert_gt(_editor.overlay().texture_bytes(), 0)
	assert_eq(_editor.overlay().mode(), MapModes.Mode.OWNER)
	assert_true(_editor.seeds_layer().visible)
	assert_not_null(_editor.pins_layer().tile_set)
	assert_not_null(_editor.camera())

	# Alt 0 is "no one" (&""), alt 1..13 match countries in order.
	var ts := _editor.pins_layer().tile_set
	var atlas := ts.get_source(ScenarioEditor.PIN_SOURCE_ID) as TileSetAtlasSource
	assert_not_null(atlas)
	var coords := _editor.pin_tile_coords()
	assert_eq(str(atlas.get_tile_data(coords, ScenarioEditor.UNOWNED_ALT_ID).get_custom_data("tag")), "")
	assert_eq(str(atlas.get_tile_data(coords, _editor.pin_alternative_for(&"TUS")).get_custom_data("tag")), "TUS")

	_editor.check()
	assert_eq(_editor.last_check_errors(), [] as Array[String])
	assert_eq(_editor.facts, "", "Check on clean north_italy_1480 writes no problem lines")


func test_pin_set_cell_regrow_write_check_and_erase_restore() -> void:
	var copy := _use_scenario_copy()
	var map := _editor.map_data()
	var sie_id := copy.id_of(&"SIE")
	var tus_id := copy.id_of(&"TUS")
	assert_eq(_editor.owner_at(TARGET_HEX), sie_id)

	var chunk := EdgeLines.chunk_of(TARGET_HEX)
	var verts_before := _border_vertices_of_chunk(chunk)

	# Paint TUS pin on Pins layer and regrow.
	var pins := _editor.pins_layer()
	pins.set_cell(TARGET_HEX, ScenarioEditor.PIN_SOURCE_ID, _editor.pin_tile_coords(), _editor.pin_alternative_for(&"TUS"))
	_editor.regrow()

	assert_eq(_editor.owner_at(TARGET_HEX), tus_id)
	assert_eq(_editor.overlay().owner_image().get_pixelv(TARGET_HEX).r8, tus_id,
		"ModeOverlay owner texel updates live")
	var verts_after := _border_vertices_of_chunk(chunk)
	assert_ne(verts_after, verts_before, "TileMapView border chunk rebuilds live when owner moves")

	# Write to user:// copy then Check gives no line.
	var save_err := _editor.write_to(TEMP_SCEN_PATH)
	assert_eq(save_err, OK)
	assert_eq(_editor.last_check_errors(), [] as Array[String])
	assert_eq(_editor.facts, "")

	var loaded := ResourceLoader.load(TEMP_SCEN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ScenarioDef
	assert_not_null(loaded)
	assert_eq(loaded.pins.size(), 1)
	assert_eq(loaded.pins[0]["hex"], TARGET_HEX)
	assert_eq(loaded.pins[0]["tag"], &"TUS")
	assert_eq(int(loaded.owner[map.index_of(TARGET_HEX)]), tus_id)
	assert_eq(loaded.validate(map, _editor.defs(), true), [] as Array[String])

	# Erase pin and regrow -> restores grown SIE owner and original border mesh.
	pins.erase_cell(TARGET_HEX)
	_editor.regrow()
	assert_eq(_editor.owner_at(TARGET_HEX), sie_id)
	assert_eq(_editor.overlay().owner_image().get_pixelv(TARGET_HEX).r8, sie_id)
	assert_eq(_border_vertices_of_chunk(chunk), verts_before)


func test_redundant_pins_dropped_on_write_and_unowned_pin_frees_hex() -> void:
	var copy := _use_scenario_copy()
	var sie_id := copy.id_of(&"SIE")

	# Painting the same country that pure growth already yields is dropped on write.
	_editor.paint_pin(TARGET_HEX, &"SIE")
	assert_eq(copy.pins.size(), 1)
	assert_eq(_editor.write_to(TEMP_SCEN_PATH), OK)
	assert_true(copy.pins.is_empty(), "redundant pin matching pure growth is dropped on Write")
	assert_true(_editor.pins_layer().get_used_cells().is_empty())

	# Painting "no one" (&"") sets owner to 0, then erasing restores SIE.
	_editor.paint_pin(TARGET_HEX, &"")
	assert_eq(_editor.owner_at(TARGET_HEX), 0)
	_editor.erase_pin(TARGET_HEX)
	assert_eq(_editor.owner_at(TARGET_HEX), sie_id)

	# Emitting Pins.changed (as Godot's TileMap editor does) triggers live regrow automatically.
	var pins := _editor.pins_layer()
	pins.set_cell(TARGET_HEX, ScenarioEditor.PIN_SOURCE_ID, _editor.pin_tile_coords(), _editor.pin_alternative_for(&"TUS"))
	pins.changed.emit()
	assert_eq(_editor.owner_at(TARGET_HEX), copy.id_of(&"TUS"))

	# Brush application via active_brush + active_country.
	_editor.set_active_brush(ScenarioEditor.Brush.ERASE_PIN)
	_editor.apply_brush(TARGET_HEX)
	assert_eq(_editor.owner_at(TARGET_HEX), sie_id)
	assert_true(_editor.facts.contains("Hex (14, 17)"))


func test_seed_brushes_modes_colour_blind_and_inspect_facts() -> void:
	var copy := _use_scenario_copy()
	var seed_hex := Vector2i(14, 17)
	_editor.set_seed(seed_hex, &"TUS", &"anchor", "test anchor")
	assert_eq(_editor.owner_at(seed_hex), copy.id_of(&"TUS"), "anchor seed transfers growth")
	_editor.erase_seed(seed_hex)
	assert_eq(_editor.owner_at(seed_hex), copy.id_of(&"SIE"), "erasing anchor restores SIE")

	_editor.mode = MapModes.Mode.RELIEF
	assert_eq(_editor.overlay().mode(), MapModes.Mode.RELIEF)
	_editor.mode = MapModes.Mode.TERRAIN
	assert_eq(_editor.overlay().mode(), MapModes.Mode.TERRAIN)
	_editor.mode = MapModes.Mode.OWNER

	_editor.colour_blind = true
	var tus_cb := _editor.defs().cb_palette[copy.cb_colours[copy.id_of(&"TUS") - 1]]
	var pal_img := _editor.overlay().palette_image()
	assert_almost_eq(pal_img.get_pixel(copy.id_of(&"TUS"), 0).r, tus_cb.r, 0.02)

	_editor.show_seeds = false
	assert_false(_editor.seeds_layer().visible)
	_editor.show_seeds = true
	assert_true(_editor.seeds_layer().visible)

	# inspect_hex populates facts with terrain, owner, seed, pin, and growth cost.
	_editor.inspect_hex = Vector2i(9, 9)  # Milan
	assert_true(_editor.facts.contains("Cover:"))
	assert_true(_editor.facts.contains("Height:"))
	assert_true(_editor.facts.contains("Relief:"))
	assert_true(_editor.facts.contains("Climate:"))
	assert_true(_editor.facts.contains("Place: Milan"))
	assert_true(_editor.facts.contains("Owner: MLO"))
	assert_true(_editor.facts.contains("Seed: town MLO"))
	assert_true(_editor.facts.contains("Growth cost: grown=0"))

	# Sea hex inspection.
	_editor.inspect_hex = Vector2i(19, 10)
	assert_true(_editor.facts.contains("Sea"))
	assert_true(_editor.facts.contains("Depth:"))


func test_planted_validation_fault_reported_by_check() -> void:
	var copy := _use_scenario_copy()
	# Planted fault: pin placed on a sea hex.
	var sea_hex := Vector2i(19, 10)
	assert_false(_editor.map_data().is_land(sea_hex))
	_editor.pins_layer().set_cell(sea_hex, ScenarioEditor.PIN_SOURCE_ID, _editor.pin_tile_coords(),
		_editor.pin_alternative_for(&"VEN"))
	_editor.regrow()
	_editor.check()

	var errs := _editor.last_check_errors()
	assert_gt(errs.size(), 0, "Check catches planted sea pin fault")
	assert_true(_editor.facts.contains("not on land"))


func test_large_map_disables_live_regrow_by_default() -> void:
	var big := FakeMap.build(120, 90, 1480)
	assert_gt(big.hex_count(), ScenarioEditor.LARGE_MAP_HEXES)
	var defs := _editor.defs()
	var scen := ScenarioDef.new()
	scen.id = "big_test"
	scen.map_id = big.id
	scen.countries = [&"AAA", &"BBB"]
	# Find first two land hexes with places or just land hexes.
	var land_hexes: Array[Vector2i] = []
	for i: int in big.hex_count():
		if big.land[i] == 1:
			land_hexes.append(big.hex_of(i))
			if land_hexes.size() >= 2:
				break
	scen.capitals = [land_hexes[0], land_hexes[1]]
	scen.cb_colours = PackedByteArray([0, 1])
	scen.seeds = [
		{"hex": land_hexes[0], "tag": &"AAA", "kind": &"town", "note": ""},
		{"hex": land_hexes[1], "tag": &"BBB", "kind": &"town", "note": ""},
	]
	_editor.setup_for(scen, big, defs)
	assert_false(_editor.live_regrow, "live_regrow turns off by default for maps > 10,000 hexes")
