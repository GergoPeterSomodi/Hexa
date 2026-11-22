## Compatibility GL / shader probe for ModeOverlay (docs/architecture/m2-build-spec.md sections 10 and 11).
## Renders North Italy with a hand-made owner array in Terrain, Owner, and Relief modes, and with hand-made Yields
## bytes (0 to 9 over the land) in Yields mode, reads back the framebuffer, and compares every hex middle against
## MapModes.colour_of (tolerance <= 3 per channel). A loss (byte 1) is striped: its middle may read madder or the veil.
## The Food mode (M5, spec 6.5) is checked the same way with hand-made Food bytes (0 to 8); bytes 1 and 2 are striped.
## The Supply mode and the sight veil (M6 L17, spec 6.6): hand-made Supply bytes (0 to 6, 1 striped) and sight bytes (every
## third land hex unseen) are checked in Supply, in Terrain under the veil and in Supply under the veil.
## The occupied stripes and the castle-area tint (M7, spec 6.3): hand-made occupiers (every fifth land hex held by another
## country) and hand-made areas are checked in Owner, Terrain and Relief, the areas on in Owner, Terrain and Relief as a
## second pass. A stripe's band is the fragment's map position (MapModes.stripe_is_occupier), so the expected colour takes the
## occupier only in its band.
## Headless (dummy renderer) it prints SKIP and exits 0.
##
## Run windowed (live GPU / Compatibility GL):
##   /opt/homebrew/bin/godot --path godot -s res://tools/map/probe_mode_overlay.gd
## Planted fault (swaps two palette entries and shifts every Yields byte; must print FAIL and exit 1):
##   /opt/homebrew/bin/godot --path godot -s res://tools/map/probe_mode_overlay.gd -- --plant
## Save PNGs per mode:
##   /opt/homebrew/bin/godot --path godot -s res://tools/map/probe_mode_overlay.gd -- --out-dir=/tmp/m2_c4_shots
extends SceneTree

const TOLERANCE := 3.0
const VIEW_MARGIN := 24.0
const WIN_SIZE := Vector2i(1280, 720)
const SEA_CLEAR := Color("#3f7fae")
const MAP_PATH := "res://data/maps/north_italy.tres"

var _plant := false
var _out_dir := ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--plant":
			_plant = true
		elif arg.begins_with("--out-dir="):
			_out_dir = arg.substr(10)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(WIN_SIZE)
		root.size = WIN_SIZE
	RenderingServer.set_default_clear_color(SEA_CLEAR)
	_run()


func _run() -> void:
	await process_frame
	await process_frame
	var headless := DisplayServer.get_name() == "headless"
	print("probe_mode_overlay: driver=%s method=%s headless=%s plant=%s" % [
		RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_current_rendering_method(),
		str(headless),
		str(_plant),
	])

	var map := ResourceLoader.load(MAP_PATH) as MapData
	if map == null:
		printerr("probe_mode_overlay: failed to load %s" % MAP_PATH)
		quit(1)
		return

	var owner := _hand_made_owners(map)
	var palette := _hand_made_palette()
	var h_bytes := MapModes.height_bytes(map)
	var yield_bytes := _hand_made_yields(map)
	var food_bytes := _hand_made_food(map)
	var supply_bytes := _hand_made_supply(map)
	var sight_bytes := _hand_made_sight(map)
	var occupier_bytes := _hand_made_occupiers(map, owner)
	var area_bytes := _hand_made_areas(map)

	var world := Node2D.new()
	world.name = "ProbeWorld"
	var map_px := Vector2(
		(float(map.cols) + 0.5) * float(MapTiles.CELL.x),
		float(map.rows) * MapTiles.ROW + float(MapTiles.CELL.y) - MapTiles.ROW
	)
	var vp_size := root.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(WIN_SIZE)
	var fit_scale := minf((vp_size.x - 2.0 * VIEW_MARGIN) / map_px.x, (vp_size.y - 2.0 * VIEW_MARGIN) / map_px.y)
	world.scale = Vector2(fit_scale, fit_scale)
	world.position = (vp_size - map_px * fit_scale) * 0.5
	root.add_child(world)

	var view := _build_tile_view(map)
	world.add_child(view)
	var borders_palette := palette.duplicate()
	var overlay := ModeOverlay.new()
	world.add_child(overlay)
	overlay.setup_from(map, owner, palette)
	overlay.update_yields(yield_bytes)
	overlay.update_food(food_bytes)
	overlay.update_supply(supply_bytes)
	overlay.update_sight(sight_bytes)
	overlay.update_occupier_bytes(occupier_bytes)
	overlay.update_areas(area_bytes)
	view.set_borders(map, owner, borders_palette)

	if headless:
		print("probe_mode_overlay: SKIP framebuffer readback (dummy headless renderer); setup bytes=%d" % overlay.texture_bytes())
		quit(0)
		return

	overlay.visible = false
	await _wait_frames(3)
	var base_img := root.get_texture().get_image()
	if base_img == null or base_img.is_empty():
		printerr("probe_mode_overlay: empty base viewport image")
		quit(1)
		return

	if _plant:
		_plant_faults(overlay, palette, yield_bytes, food_bytes, supply_bytes)

	overlay.visible = true
	var failed_modes: int = await _check_modes(map, owner, h_bytes, palette, world, vp_size, base_img, overlay,
		yield_bytes, food_bytes, supply_bytes, sight_bytes, occupier_bytes, area_bytes)
	quit(0 if failed_modes == 0 else 1)


## Renders each mode (and the veil over two of them), compares every hex middle with MapModes; returns the modes that failed.
func _check_modes(map: MapData, owner: PackedByteArray, h_bytes: PackedByteArray, palette: PackedColorArray,
		world: Node2D, vp_size: Vector2, base_img: Image, overlay: ModeOverlay, yield_bytes: PackedByteArray,
		food_bytes: PackedByteArray, supply_bytes: PackedByteArray, sight_bytes: PackedByteArray,
		occupier_bytes: PackedByteArray, area_bytes: PackedByteArray) -> int:
	var modes_to_check: Array[Array] = [
		[MapModes.Mode.TERRAIN, "Terrain", false, false],
		[MapModes.Mode.OWNER, "Owner", false, false],
		[MapModes.Mode.RELIEF, "Relief", false, false],
		[MapModes.Mode.YIELDS, "Yields", false, false],
		[MapModes.Mode.FOOD, "Food", false, false],
		[MapModes.Mode.SUPPLY, "Supply", false, false],
		[MapModes.Mode.TERRAIN, "Terrain+veil", true, false],
		[MapModes.Mode.SUPPLY, "Supply+veil", true, false],
		[MapModes.Mode.OWNER, "Owner+areas", false, true],
		[MapModes.Mode.TERRAIN, "Terrain+areas", false, true],
		[MapModes.Mode.RELIEF, "Relief+areas", false, true],
	]
	var total_failed_modes := 0
	for entry: Array in modes_to_check:
		var mode: MapModes.Mode = entry[0] as MapModes.Mode
		var label: String = str(entry[1])
		overlay.set_mode(mode)
		overlay.set_tint(true)
		overlay.set_sight_veil(bool(entry[2]))
		overlay.set_areas_on(bool(entry[3]))
		await _wait_frames(3)
		var img := root.get_texture().get_image()
		if img == null or img.is_empty():
			printerr("probe_mode_overlay: FAIL %-8s (empty image)" % label)
			total_failed_modes += 1
			continue
		if _out_dir != "":
			_save_shot(img, label.to_lower())
		var stats := _verify_frame(map, owner, h_bytes, palette, mode, world, vp_size, base_img, img, yield_bytes, food_bytes,
				supply_bytes, sight_bytes, occupier_bytes, area_bytes, bool(entry[2]), bool(entry[3]))
		var bad := int(stats["bad"])
		var worst := float(stats["worst"])
		var status := "PASS" if bad == 0 else "FAIL"
		print("probe_mode_overlay: %s  %-8s  (hexes=%d, failed=%d, worst_diff=%.2f/255%s)" % [
			status, label, map.hex_count(), bad, worst,
			"" if bad == 0 else ", first=%s" % str(stats["first"]),
		])
		if bad > 0:
			total_failed_modes += 1

	return total_failed_modes


## The planted fault: two palette entries swapped, every Yields byte shifted by one and every Food byte by one.
func _plant_faults(overlay: ModeOverlay, palette: PackedColorArray, yield_bytes: PackedByteArray,
		food_bytes: PackedByteArray, supply_bytes: PackedByteArray) -> void:
	var planted := palette.duplicate()
	var tmp := planted[1]
	planted[1] = planted[2]
	planted[2] = tmp
	overlay.set_palette_colours(planted)
	var shifted := yield_bytes.duplicate()
	for i: int in shifted.size():
		shifted[i] = (int(shifted[i]) + 1) % 10
	overlay.update_yields(shifted)
	var food_shifted := food_bytes.duplicate()
	for i: int in food_shifted.size():
		food_shifted[i] = (int(food_shifted[i]) + 1) % 9
	overlay.update_food(food_shifted)
	var supply_shifted := supply_bytes.duplicate()
	for i: int in supply_shifted.size():
		supply_shifted[i] = (int(supply_shifted[i]) + 1) % 7
	overlay.update_supply(supply_shifted)


func _wait_frames(count: int) -> void:
	for _i: int in count:
		await process_frame


func _build_tile_view(map: MapData) -> TileMapView:
	var tiles := TilesetBuilder.load_season("summer", false)
	if tiles.tile_set == null:
		tiles.tile_set = TileSet.new()
	var state := MapState.create(map)
	var view := TileMapView.new()
	view.setup(tiles)
	view.set_climates(map.cols, map.climate)
	view.begin_fill(
		map.cols, map.rows,
		func(hex: Vector2i, names: PackedStringArray) -> void: MapCells.fill_hex(map, state, hex, names),
		Vector2i.ZERO, MapCells.LAYERS
	)
	while view.fill_step(100000):
		pass
	for cy: int in ceili(float(map.rows) / EdgeLines.CHUNK):
		for cx: int in ceili(float(map.cols) / EdgeLines.CHUNK):
			var chunk := Vector2i(cx, cy)
			view.set_chunk_lines(chunk, EdgeLines.for_chunk(map, state, chunk))
	return view


func _verify_frame(map: MapData, owner: PackedByteArray, h_bytes: PackedByteArray, palette: PackedColorArray,
		mode: MapModes.Mode, world: Node2D, vp_size: Vector2, base_img: Image, img: Image,
		yield_bytes: PackedByteArray, food_bytes: PackedByteArray, supply_bytes: PackedByteArray,
		sight_bytes: PackedByteArray, occupier_bytes: PackedByteArray, area_bytes: PackedByteArray,
		veil: bool, areas: bool) -> Dictionary:
	var img_size := Vector2(img.get_size())
	var xform := world.get_global_transform_with_canvas()
	var to_map := xform.affine_inverse()
	var to_view := vp_size / img_size
	var bad := 0
	var worst := 0.0
	var first := ""
	for r: int in map.rows:
		for c: int in map.cols:
			var hex := Vector2i(c, r)
			var idx := r * map.cols + c
			var vp_pt := xform * MapTiles.cell_centre(hex)
			var px := Vector2i(
				clampi(roundi(vp_pt.x * img_size.x / vp_size.x), 0, img.get_width() - 1),
				clampi(roundi(vp_pt.y * img_size.y / vp_size.y), 0, img.get_height() - 1)
			)
			var bg := base_img.get_pixelv(px)
			var got := img.get_pixelv(px)
			# the stripe band of the sampled pixel, in map px (the shader's fragment is the pixel's centre)
			var map_pt := to_map * ((Vector2(px) + Vector2(0.5, 0.5)) * to_view)
			var occ := int(occupier_bytes[idx]) if MapModes.stripe_is_occupier(floori(map_pt.x), floori(map_pt.y)) else 0
			var area := int(area_bytes[idx]) if areas else 0
			var want := MapModes.colour_of(mode, int(owner[idx]), int(h_bytes[idx]), palette, true, 0, int(yield_bytes[idx]),
				int(food_bytes[idx]), int(supply_bytes[idx]), int(sight_bytes[idx]), veil, occ, area)
			var exp_r := bg.r * (1.0 - want.a) + want.r * want.a
			var exp_g := bg.g * (1.0 - want.a) + want.g * want.a
			var exp_b := bg.b * (1.0 - want.a) + want.b * want.a
			var diff := maxf(absf(got.r - exp_r), maxf(absf(got.g - exp_g), absf(got.b - exp_b))) * 255.0
			var striped := (mode == MapModes.Mode.YIELDS and int(yield_bytes[idx]) == 1) \
					or (mode == MapModes.Mode.FOOD and int(food_bytes[idx]) >= 1 and int(food_bytes[idx]) <= 2)
			if mode == MapModes.Mode.SUPPLY and int(supply_bytes[idx]) == 1:
				striped = true
			if striped and int(h_bytes[idx]) > 0:
				# the stripe under the middle may be madder or the veil between
				var a := MapModes.VEIL_ALPHA
				var alt_r := bg.r * (1.0 - a) + MapModes.VEIL.r * a
				var alt_g := bg.g * (1.0 - a) + MapModes.VEIL.g * a
				var alt_b := bg.b * (1.0 - a) + MapModes.VEIL.b * a
				diff = minf(diff, maxf(absf(got.r - alt_r), maxf(absf(got.g - alt_g), absf(got.b - alt_b))) * 255.0)
			worst = maxf(worst, diff)
			if diff > TOLERANCE:
				if bad == 0:
					first = "%s got=(%.3f,%.3f,%.3f) exp=(%.3f,%.3f,%.3f)" % [
						str(hex), got.r, got.g, got.b, exp_r, exp_g, exp_b
					]
				bad += 1
	return {"bad": bad, "worst": worst, "first": first}


func _save_shot(img: Image, name: String) -> void:
	var dir := ProjectSettings.globalize_path(_out_dir) if _out_dir.begins_with("res://") else _out_dir
	DirAccess.make_dir_recursive_absolute(dir)
	var out_path := dir.path_join("probe_mode_%s.png" % name)
	img.save_png(out_path)
	print("probe_mode_overlay: wrote %s" % out_path)


## Hand-made owner array on North Italy (6 rough states across land hexes; sea stays 0).
static func _hand_made_owners(map: MapData) -> PackedByteArray:
	var owner := PackedByteArray()
	owner.resize(map.hex_count())
	for r: int in map.rows:
		for c: int in map.cols:
			var idx := r * map.cols + c
			if map.land[idx] == 0:
				owner[idx] = 0
			elif r < 4 and c >= 3 and c <= 12:
				owner[idx] = 3  # Switzerland
			elif c < 7 and r < 14:
				owner[idx] = 1  # Savoy
			elif c >= 14 and r < 11:
				owner[idx] = 4  # Venice
			elif r >= 13 and c >= 12:
				owner[idx] = 5  # Florence
			elif r >= 12 and c < 10:
				owner[idx] = 6  # Genoa
			else:
				owner[idx] = 2  # Milan
	return owner


## Hand-made Yields bytes: 0 to 9 in turn over the land hexes (a 0 is a hex of another country), sea 0.
static func _hand_made_yields(map: MapData) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(map.hex_count())
	for idx: int in map.hex_count():
		if map.land[idx] != 0:
			out[idx] = idx % 10
	return out


## Hand-made Food bytes: 0 to 8 in turn over the land hexes (a 0 is a hex of another country), sea 0.
static func _hand_made_food(map: MapData) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(map.hex_count())
	for idx: int in map.hex_count():
		if map.land[idx] != 0:
			out[idx] = idx % 9
	return out


## Hand-made Supply bytes: 0 to 6 in turn over the land hexes, sea 0.
static func _hand_made_supply(map: MapData) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(map.hex_count())
	for idx: int in map.hex_count():
		if map.land[idx] != 0:
			out[idx] = idx % 7
	return out


## Hand-made sight: every third land hex (by column plus row) unseen, the rest and the sea seen.
static func _hand_made_sight(map: MapData) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(map.hex_count())
	out.fill(1)
	for idx: int in map.hex_count():
		if map.land[idx] != 0:
			var hex := map.hex_of(idx)
			out[idx] = 0 if (hex.x + hex.y) % 3 == 0 else 1
	return out


## Hand-made occupiers: every fifth land hex (by index) held by another country (the owner's successor on the six, never the
## owner itself); sea 0.
static func _hand_made_occupiers(map: MapData, owner: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(map.hex_count())
	for idx: int in map.hex_count():
		if map.land[idx] != 0 and idx % 5 == 2:
			out[idx] = (int(owner[idx]) % 6) + 1
	return out


## Hand-made castle areas: the land hexes on a diagonal band of one in five (by column and row); sea 0.
static func _hand_made_areas(map: MapData) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(map.hex_count())
	for idx: int in map.hex_count():
		if map.land[idx] != 0:
			var hex := map.hex_of(idx)
			out[idx] = 1 if (hex.x * 3 + hex.y) % 5 == 0 else 0
	return out


static func _hand_made_palette() -> PackedColorArray:
	return MapModes.palette_from(PackedColorArray([
		Color("#829678"),  # 1 Savoy
		Color("#3460b2"),  # 2 Milan
		Color("#be3232"),  # 3 Switzerland
		Color("#1ea08c"),  # 4 Venice
		Color("#8c32a0"),  # 5 Florence
		Color("#be3c6e"),  # 6 Genoa
	]), Color("#d8ccb0"))
