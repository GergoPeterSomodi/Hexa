## Builds the four season TileSets (docs/architecture/m1-build-spec.md section 3.4; ui-and-controls-spec.md section 6.3)
## from the six tile indexes and their imported pictures:
##   assets/tiles/tiles_spring.tres ... tiles_winter.tres         (full resolution)
##   assets/tiles/tiles_spring_half.tres ... tiles_winter_half.tres (half resolution, 0.5x atlases in assets/tiles/half/)
## Import the project first (the pictures are loaded as imported textures).
## Run (from the repository root, GODOT set):
##   "$GODOT" --headless --path godot -s res://tools/build_tileset.gd               writes full & half TileSets (and missing half atlases)
##   "$GODOT" --headless --path godot -s res://tools/build_tileset.gd -- --half     regenerates half atlases and writes half TileSets
##   "$GODOT" --headless --path godot -s res://tools/build_tileset.gd -- --check    checks full & half TileSets and half atlases (CI)
## The engine gives every resource in a file a random suffix (id="3_x7k2p"); it is cut off so a rebuild gives the same
## bytes.
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var check := args.has("--check")
	var half_only := args.has("--half")
	var failed := 0

	if not check:
		failed += _ensure_half_atlases(half_only)
	else:
		failed += _check_half_atlases()

	if not half_only:
		failed += _process_variants(false, check)
	failed += _process_variants(true, check)
	quit(1 if failed > 0 else 0)


func _process_variants(is_half: bool, check: bool) -> int:
	var failed := 0
	for season: String in TilesetBuilder.SEASONS:
		var built := TilesetBuilder.assemble(season, is_half)
		if built.tile_set == null or built.error != "":
			printerr("build_tileset: %s (half=%s): %s" % [season, str(is_half), built.error])
			failed += 1
			continue
		var path := TilesetBuilder.tres_path(season, is_half)
		var suffix := "_half" if is_half else ""
		var temp := "user://build_%s%s.tres" % [season, suffix]
		var result := ResourceSaver.save(built.tile_set, temp)
		if result != OK:
			printerr("build_tileset: cannot write %s (%d)" % [temp, result])
			failed += 1
			continue
		var text := _plain(FileAccess.get_file_as_string(temp))
		DirAccess.remove_absolute(temp)
		if check:
			if not FileAccess.file_exists(path) or text != FileAccess.get_file_as_string(path):
				printerr("build_tileset: %s differs from the tileset builder's output (run tools/build_tileset.gd)" % path)
				failed += 1
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				printerr("build_tileset: cannot write %s" % path)
				failed += 1
				continue
			file.store_string(text)
			file.close()
			print("build_tileset: wrote %s (%d tiles)" % [path, built.names.size()])
	return failed


func _ensure_half_atlases(force_regen: bool) -> int:
	var failed := 0
	var created := 0
	for set_name: String in TilesetBuilder.ALL_SETS:
		var index_path := TilesetBuilder.ROOT + set_name + "/index.json"
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
		if typeof(parsed) != TYPE_DICTIONARY:
			printerr("build_tileset: cannot read %s" % index_path)
			failed += 1
			continue
		var index := parsed as Dictionary
		var out_dir := ProjectSettings.globalize_path(TilesetBuilder.HALF_ROOT + set_name)
		if not DirAccess.dir_exists_absolute(out_dir):
			if DirAccess.make_dir_recursive_absolute(out_dir) != OK:
				printerr("build_tileset: cannot create %s" % out_dir)
				failed += 1
				continue
		for src_var: Variant in (index["sources"] as Array):
			var source: Dictionary = src_var
			var file_name := str(source["file"])
			var src_path := ProjectSettings.globalize_path(TilesetBuilder.ROOT + set_name + "/" + file_name)
			var dst_path := ProjectSettings.globalize_path(TilesetBuilder.HALF_ROOT + set_name + "/" + file_name)
			if not force_regen and FileAccess.file_exists(dst_path):
				continue
			var img := Image.load_from_file(src_path)
			if img == null:
				printerr("build_tileset: cannot load %s" % src_path)
				failed += 1
				continue
			var hw := roundi(float(img.get_width()) * 0.5)
			var hh := roundi(float(img.get_height()) * 0.5)
			img.resize(hw, hh, Image.INTERPOLATE_BILINEAR)
			if img.save_png(dst_path) != OK:
				printerr("build_tileset: cannot save %s" % dst_path)
				failed += 1
				continue
			created += 1
	if created > 0:
		print("build_tileset: generated %d half atlases under %s" % [created, TilesetBuilder.HALF_ROOT])
	return failed


func _check_half_atlases() -> int:
	var failed := 0
	for set_name: String in TilesetBuilder.ALL_SETS:
		var index_path := TilesetBuilder.ROOT + set_name + "/index.json"
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
		if typeof(parsed) != TYPE_DICTIONARY:
			printerr("build_tileset: cannot read %s" % index_path)
			failed += 1
			continue
		var index := parsed as Dictionary
		for src_var: Variant in (index["sources"] as Array):
			var source: Dictionary = src_var
			var file_name := str(source["file"])
			var size_arr: Array = source["size"]
			var want_w := roundi(float(size_arr[0]) * 0.5)
			var want_h := roundi(float(size_arr[1]) * 0.5)
			var dst_res := TilesetBuilder.HALF_ROOT + set_name + "/" + file_name
			if not ResourceLoader.exists(dst_res):
				printerr("build_tileset: missing imported half atlas %s" % dst_res)
				failed += 1
				continue
			var tex := load(dst_res) as Texture2D
			if tex == null or roundi(tex.get_size().x) != want_w or roundi(tex.get_size().y) != want_h:
				printerr("build_tileset: half atlas %s size mismatch (expected %dx%d)" % [dst_res, want_w, want_h])
				failed += 1
	return failed


## The file with its random id suffixes cut off ("3_x7k2p" -> "3") and no uid in the header.
func _plain(text: String) -> String:
	var ids := RegEx.create_from_string('(id="|ExtResource\\(")(\\d+)_[a-z0-9]+')
	var uids := RegEx.create_from_string(' uid="[^"]*"')
	return uids.sub(ids.sub(text, "$1$2", true), "", true)
