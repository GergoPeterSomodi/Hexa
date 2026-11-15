## M1 trial helper: writes every tile name the trial view asks for (core/views/map_tiles.gd on the north Italy facts,
## with the pieces of one seed), so the trial bake draws just the coast and piece tiles the view needs.
## Headless:  godot --headless --path godot -s res://tools/mapview/dump_trial_tiles.gd -- --out=<absolute file> [--seed=N]
extends SceneTree

var _trial: TileTrial = null
var _out := ""
var _frames := 0


func _initialize() -> void:
	var seed_value := 1480
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--seed="):
			seed_value = int(arg.substr(7))
	_trial = TileTrial.new()
	_trial.seed_value = seed_value
	root.add_child(_trial)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	if _out == "":
		printerr("dump_trial_tiles: needs --out=<file>")
		quit(1)
		return true
	var names: Array[String] = []
	names.assign(_trial.asked.keys())
	names.sort()
	var file := FileAccess.open(_out, FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": _trial.seed_value, "names": names}))
	file.close()
	print("dump_trial_tiles: %d names, %d not in the tileset yet -> %s" % [names.size(), _trial.view.missing_names().size(), _out])
	quit(0)
	return true
