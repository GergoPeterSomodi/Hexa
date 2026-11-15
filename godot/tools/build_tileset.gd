## Builds the four season TileSets (docs/architecture/m1-build-spec.md section 3.4) from the six tile indexes and their
## imported pictures: assets/tiles/tiles_spring.tres ... tiles_winter.tres, each with three climate slots a source.
## Import the project first (the pictures are loaded as imported textures).
## Run (from the repository root, GODOT set):
##   "$GODOT" --headless --path godot -s res://tools/build_tileset.gd              writes the four files
##   "$GODOT" --headless --path godot -s res://tools/build_tileset.gd -- --check   builds and compares with the committed files (CI)
## The engine gives every resource in a file a random suffix (id="3_x7k2p"); it is cut off so a rebuild gives the same
## bytes.
extends SceneTree


func _initialize() -> void:
	var check := OS.get_cmdline_user_args().has("--check")
	var failed := 0
	for season: String in TilesetBuilder.SEASONS:
		var built := TilesetBuilder.assemble(season)
		if built.tile_set == null or built.error != "":
			printerr("build_tileset: %s: %s" % [season, built.error])
			failed += 1
			continue
		var path := TilesetBuilder.tres_path(season)
		var temp := "user://build_%s.tres" % season
		var result := ResourceSaver.save(built.tile_set, temp)
		if result != OK:
			printerr("build_tileset: cannot write %s (%d)" % [temp, result])
			failed += 1
			continue
		var text := _plain(FileAccess.get_file_as_string(temp))
		DirAccess.remove_absolute(temp)
		if check:
			if text != FileAccess.get_file_as_string(path):
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
	quit(1 if failed > 0 else 0)


## The file with its random id suffixes cut off ("3_x7k2p" -> "3") and no uid in the header.
func _plain(text: String) -> String:
	var ids := RegEx.create_from_string('(id="|ExtResource\\(")(\\d+)_[a-z0-9]+')
	var uids := RegEx.create_from_string(' uid="[^"]*"')
	return uids.sub(ids.sub(text, "$1$2", true), "", true)
