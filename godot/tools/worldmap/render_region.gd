## Writes the pictures of the map prototype region as PNG files: flat colours by relief level, crests, passes and names
## (the relief pictures), with --water the rivers, lakes, shores, sea depth and streams (the water pictures), and with
## --cover the ground cover (step 4: soft colours blended across the edges, shaded by the relief, water on top).
## Windowed: nothing is drawn headless.
## Run (from the repository root, with GODOT set):
##   "$GODOT" --path godot -s res://tools/worldmap/render_region.gd -- --out=<absolute folder> [--water | --cover]
## Options: --heights=<absolute path> draws another heights file (a comparison, e.g. --stat=centre from the extractor),
## --prefix=<text> is put in front of the picture names.
extends SceneTree

const HEIGHTS := "res://data/worldmap/heights_alps_po.json"
const REGION := "res://data/worldmap/region_alps_po.json"
const VIEW_SCENE := "res://shell/worldmap/world_map_view.tscn"


func _initialize() -> void:
	_render()


func _render() -> void:
	var out_dir := ""
	var heights_path := HEIGHTS
	var prefix := ""
	var with_water := false
	var with_cover := false
	var with_network := false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--cover":
			with_cover = true
		if arg.begins_with("--out="):
			out_dir = arg.substr("--out=".length())
		elif arg.begins_with("--heights="):
			heights_path = arg.substr("--heights=".length())
		elif arg.begins_with("--prefix="):
			prefix = arg.substr("--prefix=".length())
		elif arg == "--water":
			with_water = true
		elif arg == "--network":
			with_network = true
	if out_dir == "":
		printerr("render_region: give --out=<absolute folder>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var heights := WorldHeights.from_text(FileAccess.get_file_as_string(heights_path))
	var region := WorldRegion.from_text(FileAccess.get_file_as_string(REGION))
	if heights == null or region == null:
		printerr("render_region: the region or the heights file does not read")
		quit(1)
		return
	var grid := HexGrid.new(region.hex_w_km, region.deg_km, region.ref_lat, region.lon_west, region.lat_north)
	var relief := WorldRelief.build(grid, heights, region)
	var view: WorldMapView = (load(VIEW_SCENE) as PackedScene).instantiate()
	root.add_child(view)
	view.show_region(grid, region, relief)
	if with_network:
		var net_water := WorldWater.build(grid, relief, heights, region)
		var net_cover := WorldCover.build(grid, relief, heights, net_water, region.cover_seed)
		var places := WorldPlaces.build(grid, relief, net_water, net_cover, region)
		var roads := WorldRoads.build(grid, relief, net_water, places, region)
		view.show_water(net_water)
		view.show_cover(net_cover)
		view.show_network(places, roads)
		view.title = "Alps and Po: settlements and roads on 28 km hexes, over the ground cover"
		await _shot(out_dir.path_join(prefix + "places_region_whole.png"))
		_report_labels(view)
		view.set_view(9.19, 45.46, 9.0)
		await _shot(out_dir.path_join(prefix + "places_milan_close.png"))
		view.set_view(7.9, 46.2, 4.6)
		await _shot(out_dir.path_join(prefix + "places_alpine_passes.png"))
		view.set_view(8.93, 44.41, 8.0)
		await _shot(out_dir.path_join(prefix + "places_genoa.png"))
		view.set_view(9.9, 44.5, 5.5)
		await _shot(out_dir.path_join(prefix + "places_apennine_crossings.png"))
		view.set_view(9.16, 45.12, 9.0)
		await _shot(out_dir.path_join(prefix + "places_pavia_po.png"))
		view.set_view(12.1, 45.3, 8.0)
		await _shot(out_dir.path_join(prefix + "places_venice.png"))
	elif with_cover:
		var cover_water := WorldWater.build(grid, relief, heights, region)
		var cover := WorldCover.build(grid, relief, heights, cover_water, region.cover_seed)
		view.show_water(cover_water)
		view.show_cover(cover)
		view.title = "Alps and Po: ground cover on 28 km hexes, rivers and lakes on top"
		await _shot(out_dir.path_join(prefix + "cover_region_whole.png"))
		view.set_view(7.5, 45.85, 5.0)
		await _shot(out_dir.path_join(prefix + "cover_alps_close.png"))
		view.set_view(8.9, 45.2, 4.2)
		await _shot(out_dir.path_join(prefix + "cover_po_plain.png"))
		view.set_view(10.9, 43.6, 4.0)
		await _shot(out_dir.path_join(prefix + "cover_tuscany.png"))
	elif with_water:
		var water := WorldWater.build(grid, relief, heights, region)
		view.show_water(water)
		view.title = "Alps and Po: rivers, lakes and sea depth on 28 km hexes"
		await _shot(out_dir.path_join(prefix + "water_region_whole.png"))
		view.set_view(8.95, 45.85, 9.0)
		await _shot(out_dir.path_join(prefix + "water_lakes_close.png"))
		view.set_view(10.99, 45.44, 14.0)
		await _shot(out_dir.path_join(prefix + "water_verona.png"))
		view.set_view(11.25, 43.77, 14.0)
		await _shot(out_dir.path_join(prefix + "water_florence.png"))
		view.set_view(8.9, 45.2, 4.2)
		await _shot(out_dir.path_join(prefix + "water_po_plain.png"))
		view.set_view(12.35, 45.35, 9.0)
		await _shot(out_dir.path_join(prefix + "water_venice.png"))
	else:
		await _shot(out_dir.path_join(prefix + "region_whole.png"))
		view.set_view(8.0, 45.7, 2.6)
		await _shot(out_dir.path_join(prefix + "region_middle.png"))
		view.set_view(7.5, 45.85, 5.0)
		await _shot(out_dir.path_join(prefix + "region_alps_close.png"))
		view.set_view(8.9, 45.2, 4.2)
		await _shot(out_dir.path_join(prefix + "region_po_plain.png"))
	print("render_region: pictures written to " + out_dir)
	quit(0)


## Counts the settlement names drawn in the last frame and the pairs whose boxes overlap (the names must not collide).
func _report_labels(view: WorldMapView) -> void:
	var overlaps := 0
	var n := view.label_boxes.size()
	for i: int in n:
		for j: int in range(i + 1, n):
			if view.label_boxes[i].intersects(view.label_boxes[j]):
				overlaps += 1
				printerr("render_region: names overlap: %s and %s" % [view.label_names[i], view.label_names[j]])
	print("render_region: %d names drawn, %d overlapping pairs" % [n, overlaps])


func _shot(path: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var err := image.save_png(path)
	if err != OK:
		printerr("render_region: cannot write " + path)
