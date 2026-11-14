## Writes the step 2 pictures of the map prototype region (flat colours by relief level, crests, passes and names) as PNG
## files: the whole region, the middle zoom, the Alps close and the Po plain. Windowed: nothing is drawn headless.
## Run (from the repository root, with GODOT set):
##   "$GODOT" --path godot -s res://tools/worldmap/render_region.gd -- --out=<absolute folder>
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
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr("--out=".length())
		elif arg.begins_with("--heights="):
			heights_path = arg.substr("--heights=".length())
		elif arg.begins_with("--prefix="):
			prefix = arg.substr("--prefix=".length())
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
	var grid := WorldGrid.new(region.hex_w_km, region.deg_km, region.ref_lat, region.lon_west, region.lat_north)
	var relief := WorldRelief.build(grid, heights, region)
	var view: WorldMapView = (load(VIEW_SCENE) as PackedScene).instantiate()
	root.add_child(view)
	view.show_region(grid, region, relief)
	await _shot(out_dir.path_join(prefix + "region_whole.png"))
	view.set_view(8.0, 45.7, 2.6)
	await _shot(out_dir.path_join(prefix + "region_middle.png"))
	view.set_view(7.5, 45.85, 5.0)
	await _shot(out_dir.path_join(prefix + "region_alps_close.png"))
	view.set_view(8.9, 45.2, 4.2)
	await _shot(out_dir.path_join(prefix + "region_po_plain.png"))
	print("render_region: 4 pictures written to " + out_dir)
	quit(0)


func _shot(path: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var err := image.save_png(path)
	if err != OK:
		printerr("render_region: cannot write " + path)
