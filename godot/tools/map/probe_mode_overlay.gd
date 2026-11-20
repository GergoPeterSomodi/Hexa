## Compatibility GL / shader probe for ModeOverlay (docs/architecture/m2-build-spec.md sections 10 and 11).
## Renders North Italy with a hand-made owner array in Terrain, Owner, and Relief modes, and with hand-made Yields
## bytes (0 to 9 over the land) in Yields mode, reads back the framebuffer, and compares every hex middle against
## MapModes.colour_of (tolerance <= 3 per channel). A loss (byte 1) is striped: its middle may read madder or the veil.
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
		_plant_faults(overlay, palette, yield_bytes)

	overlay.visible = true
	var modes_to_check: Array[Array] = [
		[MapModes.Mode.TERRAIN, "Terrain"],
		[MapModes.Mode.OWNER, "Owner"],
		[MapModes.Mode.RELIEF, "Relief"],
		[MapModes.Mode.YIELDS, "Yields"],
	]
	var total_failed_modes := 0
	for entry: Array in modes_to_check:
		var mode: MapModes.Mode = entry[0] as MapModes.Mode
		var label: String = str(entry[1])
		overlay.set_mode(mode)
		overlay.set_tint(true)
		await _wait_frames(3)
		var img := root.get_texture().get_image()
		if img == null or img.is_empty():
			printerr("probe_mode_overlay: FAIL %-8s (empty image)" % label)
			total_failed_modes += 1
			continue
		if _out_dir != "":
			_save_shot(img, label.to_lower())
		var stats := _verify_frame(map, owner, h_bytes, palette, mode, world, vp_size, base_img, img, yield_bytes)
		var bad := int(stats["bad"])
		var worst := float(stats["worst"])
		var status := "PASS" if bad == 0 else "FAIL"
		print("probe_mode_overlay: %s  %-8s  (hexes=%d, failed=%d, worst_diff=%.2f/255%s)" % [
			status, label, map.hex_count(), bad, worst,
			"" if bad == 0 else ", first=%s" % str(stats["first"]),
		])
		if bad > 0:
			total_failed_modes += 1

	quit(0 if total_failed_modes == 0 else 1)


## The planted fault: two palette entries swapped and every Yields byte shifted by one.
func _plant_faults(overlay: ModeOverlay, palette: PackedColorArray, yield_bytes: PackedByteArray) -> void:
	var planted := palette.duplicate()
	var tmp := planted[1]
	planted[1] = planted[2]
	planted[2] = tmp
	overlay.set_palette_colours(planted)
	var shifted := yield_bytes.duplicate()
	for i: int in shifted.size():
		shifted[i] = (int(shifted[i]) + 1) % 10
	overlay.update_yields(shifted)


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
		yield_bytes: PackedByteArray) -> Dictionary:
	var img_size := Vector2(img.get_size())
	var xform := world.get_global_transform_with_canvas()
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
			var want := MapModes.colour_of(mode, int(owner[idx]), int(h_bytes[idx]), palette, true, 0, int(yield_bytes[idx]))
			var exp_r := bg.r * (1.0 - want.a) + want.r * want.a
			var exp_g := bg.g * (1.0 - want.a) + want.g * want.a
			var exp_b := bg.b * (1.0 - want.a) + want.b * want.a
			var diff := maxf(absf(got.r - exp_r), maxf(absf(got.g - exp_g), absf(got.b - exp_b))) * 255.0
			if mode == MapModes.Mode.YIELDS and int(yield_bytes[idx]) == 1 and int(h_bytes[idx]) > 0:
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


static func _hand_made_palette() -> PackedColorArray:
	return MapModes.palette_from(PackedColorArray([
		Color("#829678"),  # 1 Savoy
		Color("#3460b2"),  # 2 Milan
		Color("#be3232"),  # 3 Switzerland
		Color("#1ea08c"),  # 4 Venice
		Color("#8c32a0"),  # 5 Florence
		Color("#be3c6e"),  # 6 Genoa
	]), Color("#d8ccb0"))
