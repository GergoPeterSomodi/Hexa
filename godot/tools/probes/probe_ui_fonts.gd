## Headless probe P3 for Studiolo UI fonts (docs/architecture/ui-style-and-feedback-spec.md sections 4.3, 12;
## docs/architecture/ui-style-and-feedback-plan.md P3).
## Run: godot --headless --path godot -s res://tools/probes/probe_ui_fonts.gd
extends SceneTree

const SYMBOLS_ALL := "−·×%"
const SYMBOLS_BODY := "→↑↓−·×%"


func _initialize() -> void:
	var fonts := _load_fonts()
	if fonts.is_empty():
		quit(1)
		return
	var geo_chars := _collect_geography_chars()
	var failed := 0
	for key: String in Tokens.FONTS:
		var font: FontFile = fonts[key]
		failed += _check_font_coverage(key, font, geo_chars)
	failed += _check_tabular_digits(fonts)
	failed += _check_cinzel_spacing(fonts["cinzel_bold"])
	failed += _check_fallback_behaviour(fonts["cinzel_bold"], fonts["fallback"])
	print("probe_ui_fonts: %s (%d failures)" % ["PASS" if failed == 0 else "FAIL", failed])
	quit(1 if failed > 0 else 0)


func _load_fonts() -> Dictionary[String, FontFile]:
	var out: Dictionary[String, FontFile] = {}
	for key: String in Tokens.FONTS:
		var path: String = Tokens.FONTS[key]
		var res := load(path)
		if res == null or not (res is FontFile):
			printerr("probe_ui_fonts: failed to load FontFile at %s" % path)
			return {}
		var font := res as FontFile
		if font.allow_system_fallback:
			printerr("probe_ui_fonts: %s has allow_system_fallback=true (must be false)" % key)
			return {}
		out[key] = font
	return out


func _check_font_coverage(key: String, font: FontFile, geo_chars: PackedStringArray) -> int:
	var missing_required: PackedStringArray = []
	for cp: int in range(0x20, 0x7F):
		if not font.has_char(cp):
			missing_required.append(char(cp))
	for cp: int in range(0xA0, 0x100):
		if not font.has_char(cp):
			missing_required.append(char(cp))
	var sym_set := SYMBOLS_ALL if (key == "cinzel_bold" or key == "fallback") else SYMBOLS_BODY
	for i: int in sym_set.length():
		var ch := sym_set[i]
		if not font.has_char(ch.unicode_at(0)):
			missing_required.append(ch)
	for ch: String in geo_chars:
		if not font.has_char(ch.unicode_at(0)):
			missing_required.append(ch)
	var missing_ext_a: PackedStringArray = []
	for cp: int in range(0x100, 0x180):
		if not font.has_char(cp):
			missing_ext_a.append(char(cp))
	print("probe_ui_fonts: [%s] required_missing=%d ext_a_missing=%d %s" % [
		key, missing_required.size(), missing_ext_a.size(), str(missing_ext_a)
	])
	if not missing_required.is_empty():
		printerr("probe_ui_fonts: [%s] missing required chars: %s" % [key, str(missing_required)])
		return 1
	return 0


func _check_tabular_digits(fonts: Dictionary[String, FontFile]) -> int:
	var failed := 0
	var ts := TextServerManager.get_primary_interface()
	var lnum_tag := ts.name_to_tag("lnum")
	var tnum_tag := ts.name_to_tag("tnum")
	var tabular_keys: Array[String] = [
		"alegreya_sans_regular",
		"alegreya_sans_medium",
		"alegreya_sans_bold",
		"alegreya_sc_bold",
	]
	for key: String in tabular_keys:
		var fv := FontVariation.new()
		fv.base_font = fonts[key]
		fv.opentype_features = {lnum_tag: 1, tnum_tag: 1}
		for font_size: int in [13, 14, 15, 16]:
			var w1 := fv.get_string_size("1111", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var w0 := fv.get_string_size("0000", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var w8 := fv.get_string_size("8888", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if not is_equal_approx(w1, w0) or not is_equal_approx(w1, w8):
				printerr("probe_ui_fonts: [%s @%d] tabular width mismatch: 1111=%f 0000=%f 8888=%f" % [
					key, font_size, w1, w0, w8
				])
				failed += 1
		print("probe_ui_fonts: [%s] tabular 1111==0000==8888 at 16px: %.2f px" % [
			key, fv.get_string_size("1111", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		])
	return failed


func _check_cinzel_spacing(cinzel: FontFile) -> int:
	var failed := 0
	var base_w := cinzel.get_string_size("GENOA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	for pair: Array in [[16, 0.10], [20, 0.14], [15, 0.14]]:
		var sz := int(pair[0])
		var em := float(pair[1])
		var px := roundi(float(sz) * em)
		var fv := FontVariation.new()
		fv.base_font = cinzel
		fv.spacing_glyph = px
		var base_sz_w := cinzel.get_string_size("GENOA", HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var spaced_w := fv.get_string_size("GENOA", HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		if spaced_w <= base_sz_w + float(px) * 3.0:
			printerr("probe_ui_fonts: Cinzel spacing %dpx @%dpx did not widen string (base=%.2f spaced=%.2f)" % [
				px, sz, base_sz_w, spaced_w
			])
			failed += 1
		print("probe_ui_fonts: [cinzel_bold @%dpx, %.2fem=%dpx] base=%.2f spaced=%.2f" % [
			sz, em, px, base_sz_w, spaced_w
		])
	if base_w <= 0.0:
		failed += 1
	return failed


func _check_fallback_behaviour(cinzel: FontFile, noto: FontFile) -> int:
	var failed := 0
	var esperanto_c := 0x0108  # Ĉ: absent in Cinzel, present in Noto Sans
	var cjk_char := 0x4E2D     # 中: absent in both, proves system fallback is off
	if cinzel.has_char(esperanto_c):
		printerr("probe_ui_fonts: expected Cinzel to lack U+0108 for fallback test")
		failed += 1
	if cinzel.has_char(cjk_char) or noto.has_char(cjk_char):
		printerr("probe_ui_fonts: unexpected CJK glyph in static fonts")
		failed += 1
	var fv := FontVariation.new()
	fv.base_font = cinzel
	fv.fallbacks = [noto]
	if not fv.has_char(esperanto_c):
		printerr("probe_ui_fonts: FontVariation with Noto fallback failed has_char(U+0108)")
		failed += 1
	if fv.has_char(cjk_char):
		printerr("probe_ui_fonts: system fallback leaked U+4E2D despite allow_system_fallback=false")
		failed += 1
	print("probe_ui_fonts: fallback verified (U+0108 via Noto=%s, U+4E2D blocked=%s)" % [
		str(fv.has_char(esperanto_c)), str(not fv.has_char(cjk_char))
	])
	return failed


func _collect_geography_chars() -> PackedStringArray:
	var seen: Dictionary[String, bool] = {}
	var dir := DirAccess.open("res://data/geography")
	if dir != null:
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if entry.ends_with(".json"):
				var text := FileAccess.get_file_as_string("res://data/geography/" + entry)
				var parsed: Variant = JSON.parse_string(text)
				_walk_json_strings(parsed, seen)
			entry = dir.get_next()
		dir.list_dir_end()
	var out: PackedStringArray = []
	for ch: String in seen:
		out.append(ch)
	out.sort()
	return out


func _walk_json_strings(node: Variant, seen: Dictionary[String, bool]) -> void:
	if typeof(node) == TYPE_STRING:
		var s := str(node)
		for i: int in s.length():
			var cp := s.unicode_at(i)
			if cp >= 0x20 and cp != 0xAD:
				seen[s[i]] = true
	elif typeof(node) == TYPE_ARRAY:
		for item: Variant in (node as Array):
			_walk_json_strings(item, seen)
	elif typeof(node) == TYPE_DICTIONARY:
		var dict := node as Dictionary
		for k: Variant in dict:
			var ks := str(k)
			if ks in ["name", "names", "title", "label", "capital", "city", "town", "region", "country", "river", "pass", "tribe", "market"] or typeof(dict[k]) in [TYPE_ARRAY, TYPE_DICTIONARY]:
				_walk_json_strings(dict[k], seen)
