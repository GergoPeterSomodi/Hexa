## Safe ConfigFile parsing (rejecting Object injection) and atomic .tmp-and-rename persistence for Settings.
class_name SettingsIo
extends RefCounted


static func parse_safe_config(raw_text: String) -> ConfigFile:
	var clean_lines := PackedStringArray()
	var obj_regex := RegEx.create_from_string("\\bObject\\s*\\(")
	for raw_line: String in raw_text.split("\n"):
		var stripped := raw_line.strip_edges()
		if stripped.is_empty() or stripped.begins_with(";") or stripped.begins_with("#"):
			clean_lines.append(raw_line)
			continue
		if stripped.begins_with("["):
			if not stripped.ends_with("]") or stripped.length() < 3:
				return null
			clean_lines.append(raw_line)
			continue
		var eq_idx := stripped.find("=")
		if eq_idx <= 0:
			return null
		var rhs := stripped.substr(eq_idx + 1).strip_edges()
		if rhs.is_empty():
			return null
		if obj_regex.search(rhs) != null:
			continue
		if not _looks_like_variant_literal(rhs):
			return null
		clean_lines.append(raw_line)
	var cfg := ConfigFile.new()
	if cfg.parse("\n".join(clean_lines)) != OK:
		return null
	return cfg


static func _looks_like_variant_literal(rhs: String) -> bool:
	var first := rhs[0]
	if first == "\"" or first == "'" or first == "[" or first == "{":
		return true
	if first == "-" or first == "+" or (first >= "0" and first <= "9"):
		return true
	if rhs.begins_with("true") or rhs.begins_with("false") or rhs.begins_with("null"):
		return true
	if rhs.begins_with("Vector2i(") or rhs.begins_with("Vector2(") or rhs.begins_with("&\""):
		return true
	return false


static func save_atomic(cfg: ConfigFile, path: String) -> bool:
	if path.is_empty():
		return false
	var tmp_path := path + ".tmp"
	var global_tmp := ProjectSettings.globalize_path(tmp_path)
	var global_target := ProjectSettings.globalize_path(path)
	var base_dir := global_target.get_base_dir()
	if not base_dir.is_empty() and not DirAccess.dir_exists_absolute(base_dir):
		if path.begins_with("user://"):
			if DirAccess.make_dir_recursive_absolute(base_dir) != OK:
				return false
		else:
			return false
	if DirAccess.dir_exists_absolute(global_tmp) or DirAccess.dir_exists_absolute(global_target):
		return false
	var probe := FileAccess.open(tmp_path, FileAccess.WRITE)
	if probe == null:
		return false
	probe.close()
	if cfg.save(tmp_path) != OK:
		if FileAccess.file_exists(global_tmp):
			DirAccess.remove_absolute(global_tmp)
		return false
	if DirAccess.rename_absolute(global_tmp, global_target) != OK:
		if FileAccess.file_exists(global_tmp):
			DirAccess.remove_absolute(global_tmp)
		return false
	return true
