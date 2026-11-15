## M1 trial helper: writes the pieces the improvement step puts on the north Italy hex table for one seed, as JSON, so
## the trial tileset bake (tools/worldmap/tileset_bake/bake_trial.py) knows which piece tiles the trial view needs.
## Headless:  godot --headless --path godot -s res://tools/mapview/dump_trial_pieces.gd -- --out=<absolute file> [--seed=N]
extends SceneTree

const META := "res://assets/worldmap/north_italy/meta.json"


func _initialize() -> void:
	var out := ""
	var seed_value := 1480
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--seed="):
			seed_value = int(arg.substr(7))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(META))
	if out == "" or typeof(parsed) != TYPE_DICTIONARY:
		printerr("dump_trial_pieces: needs --out=<file> and the baked meta.json")
		quit(1)
		return
	var meta: Dictionary = parsed
	var table: Array = meta["hexes"]
	var improve := WorldImprove.build(table, seed_value)
	var rows: Array[Dictionary] = []
	for hex: Vector2i in improve.hexes:
		var piece := improve.piece_at(hex)
		if piece.is_empty():
			continue
		piece["c"] = hex.x
		piece["r"] = hex.y
		rows.append(piece)
	var file := FileAccess.open(out, FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": seed_value, "pieces": rows}, "\t"))
	file.close()
	print("dump_trial_pieces: %d pieces for seed %d -> %s" % [rows.size(), seed_value, out])
	quit(0)
