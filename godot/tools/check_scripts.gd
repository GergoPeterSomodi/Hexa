## Parses every .gd file of the project (not addons/) so that parse errors and warnings show in the log.
## Warnings are errors in project.godot (B3), so a bad script fails its parse.
## Run: godot --headless --path godot --script res://tools/check_scripts.gd   (exit 1 on any failure)
extends SceneTree


func _init() -> void:
	var paths := _find_scripts("res://")
	var failed := 0
	for path in paths:
		if not _parses(path):
			printerr("check_scripts: cannot parse " + path)
			failed += 1
	print("check_scripts: " + str(paths.size()) + " scripts, " + str(failed) + " failed")
	quit(1 if failed > 0 else 0)


func _parses(path: String) -> bool:
	# class_name would clash with the global class this parse already sees: comment it out for the check.
	var source := FileAccess.get_file_as_string(path)
	var names := RegEx.create_from_string("(?m)^class_name ")
	var script := GDScript.new()
	script.source_code = names.sub(source, "# class_name ", true)
	return script.reload() == OK


func _find_scripts(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			# Hidden folders (.godot) and third-party addons are not ours to check.
			if not entry.begins_with(".") and entry != "addons":
				found.append_array(_find_scripts(full))
		elif entry.ends_with(".gd"):
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found
