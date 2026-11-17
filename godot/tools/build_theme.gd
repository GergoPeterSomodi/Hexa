## Builds the two generated Theme resources (docs/architecture/ui-style-and-feedback-spec.md section 4.7 and 4.9):
##   - res://shell/ui/theme.tres (1x Studiolo theme)
##   - res://shell/ui/theme_high_contrast.tres (flat StyleBoxFlat high-contrast / low-memory theme)
##
## Run (from the repository root):
##   /opt/homebrew/bin/godot --headless --path godot -s res://tools/build_theme.gd              writes both files
##   /opt/homebrew/bin/godot --headless --path godot -s res://tools/build_theme.gd -- --check   verifies committed files (CI)
extends SceneTree

const SYMBOLS_ALL := "−·×%"
const SYMBOLS_ARROWS := "→↑↓"


func _initialize() -> void:
	var check := OS.get_cmdline_user_args().has("--check")
	var failed := 0

	var studiolo := KitTheme.build_studiolo()
	var hc := KitTheme.build_high_contrast()

	failed += _process_theme("studiolo", studiolo, KitTheme.THEME_PATH, check)
	failed += _process_theme("high_contrast", hc, KitTheme.HIGH_CONTRAST_PATH, check)

	if check:
		failed += _verify_theme("studiolo", studiolo)
		failed += _verify_theme("high_contrast", hc)

	quit(1 if failed > 0 else 0)


func _process_theme(label: String, theme: Theme, out_path: String, check: bool) -> int:
	var temp := "user://build_theme_%s.tres" % label
	var err := ResourceSaver.save(theme, temp)
	if err != OK:
		printerr("build_theme: cannot write %s (%d)" % [temp, err])
		return 1
	var text := _plain(FileAccess.get_file_as_string(temp))
	DirAccess.remove_absolute(temp)

	if check:
		if not FileAccess.file_exists(out_path):
			printerr("build_theme: missing %s (run tools/build_theme.gd)" % out_path)
			return 1
		var committed := FileAccess.get_file_as_string(out_path)
		if text != committed:
			printerr("build_theme: %s differs from KitTheme output (run tools/build_theme.gd)" % out_path)
			return 1
		print("build_theme: %s is current" % out_path)
		return 0

	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		printerr("build_theme: cannot write %s" % out_path)
		return 1
	file.store_string(text)
	file.close()
	print("build_theme: wrote %s" % out_path)
	return 0


func _verify_theme(label: String, theme: Theme) -> int:
	var failed := 0
	for var_name: String in Tokens.TYPE_VARIATIONS:
		var tname := StringName(var_name)
		if not theme.has_font(&"font", tname) or not theme.has_font_size(&"font_size", tname) or not theme.has_color(&"font_color", tname):
			printerr("build_theme: [%s] missing type variation %s" % [label, var_name])
			failed += 1

	for alias_name: String in Tokens.HEX_ALIASES:
		var aname := StringName(alias_name)
		if not theme.has_font(&"font", aname) or not theme.has_font_size(&"font_size", aname) or not theme.has_color(&"font_color", aname):
			printerr("build_theme: [%s] missing Hex alias %s" % [label, alias_name])
			failed += 1

	for style_name: String in Tokens.STYLE_VARIATIONS:
		if not _has_style_variation(theme, style_name):
			printerr("build_theme: [%s] missing style variation %s" % [label, style_name])
			failed += 1

	failed += _verify_fonts(label, theme)
	failed += _verify_tabular_digits(label, theme)
	return failed


func _has_style_variation(theme: Theme, style_name: String) -> bool:
	var spec: Dictionary = Tokens.STYLE_VARIATIONS[style_name]
	var base_type := str(spec["base_type"])
	var tname := StringName(style_name)
	if style_name != base_type and theme.get_type_variation_base(tname) != StringName(base_type):
		return false
	if base_type == "PanelContainer":
		return theme.has_stylebox(&"panel", tname)
	if base_type == "Button":
		return theme.has_stylebox(&"normal", tname) and theme.has_stylebox(&"pressed", tname)
	if base_type == "Tree":
		return theme.has_stylebox(&"selected", tname) and theme.has_color(&"guide_color", tname)
	if style_name == "InkChart":
		var colors: Dictionary = spec["colors"]
		for k: String in colors:
			if not theme.has_color(StringName(k), &"InkChart"):
				return false
		return theme.has_font(&"font", &"InkChart")
	return true


func _verify_fonts(label: String, theme: Theme) -> int:
	var failed := 0
	for var_name: String in Tokens.TYPE_VARIATIONS:
		var spec: Dictionary = Tokens.TYPE_VARIATIONS[var_name]
		var font := theme.get_font(&"font", StringName(var_name))
		if font == null:
			printerr("build_theme: [%s] null font for %s" % [label, var_name])
			failed += 1
			continue
		var missing := _missing_chars(font, str(spec["font"]) != "cinzel_bold")
		if not missing.is_empty():
			printerr("build_theme: [%s] %s font missing chars: %s" % [label, var_name, str(missing)])
			failed += 1
	return failed


func _missing_chars(font: Font, check_arrows: bool) -> PackedStringArray:
	var missing: PackedStringArray = []
	for cp: int in range(0x20, 0x7F):
		if not font.has_char(cp):
			missing.append(char(cp))
	for cp: int in range(0xA0, 0x180):
		if not font.has_char(cp):
			missing.append(char(cp))
	for i: int in SYMBOLS_ALL.length():
		var ch := SYMBOLS_ALL[i]
		if not font.has_char(ch.unicode_at(0)):
			missing.append(ch)
	if check_arrows:
		for i: int in SYMBOLS_ARROWS.length():
			var ch := SYMBOLS_ARROWS[i]
			if not font.has_char(ch.unicode_at(0)):
				missing.append(ch)
	return missing


func _verify_tabular_digits(label: String, theme: Theme) -> int:
	var num_font := theme.get_font(&"font", &"Number")
	var num_size := theme.get_font_size(&"font_size", &"Number")
	if num_font == null:
		return 1
	var w1 := num_font.get_string_size("1111", HORIZONTAL_ALIGNMENT_LEFT, -1, num_size).x
	var w0 := num_font.get_string_size("0000", HORIZONTAL_ALIGNMENT_LEFT, -1, num_size).x
	if not is_equal_approx(w1, w0):
		printerr("build_theme: [%s] Number tabular digits mismatch: 1111=%f 0000=%f" % [label, w1, w0])
		return 1
	return 0


## Strips random resource UIDs and normalises ExtResource/SubResource id suffixes so rebuilds are byte-identical.
func _plain(text: String) -> String:
	var uids := RegEx.create_from_string(' uid="[^"]*"')
	var cleaned := uids.sub(text, "", true)
	var ext_ids := RegEx.create_from_string('(id="|ExtResource\\(")(\\d+)_[a-z0-9]+')
	cleaned = ext_ids.sub(cleaned, "$1$2", true)

	var sub_decl := RegEx.create_from_string('\\[sub_resource type="([^"]+)" id="([^"]+)"\\]')
	var type_counts: Dictionary[String, int] = {}
	var id_map: Dictionary[String, String] = {}
	for m: RegExMatch in sub_decl.search_all(cleaned):
		var stype := m.get_string(1)
		var old_id := m.get_string(2)
		if id_map.has(old_id):
			continue
		var count := int(type_counts.get(stype, 0)) + 1
		type_counts[stype] = count
		id_map[old_id] = "%s_%d" % [stype, count]

	for old_id: String in id_map:
		cleaned = cleaned.replace('"%s"' % old_id, '"%s"' % id_map[old_id])
	return cleaned
