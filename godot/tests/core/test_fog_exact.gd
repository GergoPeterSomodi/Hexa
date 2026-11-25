## Exact numbers everywhere (docs/architecture/fog-build-spec.md R24 to R27, done-when 3): no file under core/ or shell/ names
## `Knowledge.band`, `band_text` or a `band(` call, and none builds an "about " text (the odds card's, the summaries'). The scan
## reads every .gd file under the two roots, so a view that keeps one call is found. P: fixture texts with each form are reported.
extends GutTest

const ROOTS: Array[String] = ["res://core", "res://shell"]
## The forms of a band or of a rounded word. "band(" is matched as a call or a definition only: yield_band( and food_band(
## are other rules (MapModes), and the word `band` as a variable is not a call.
const PATTERNS: Array[String] = ["\\bband_text\\b", "Knowledge\\.band\\b", "(?<![A-Za-z0-9_.])band\\(", "\"about ", " about\""]


## The problems of one file's text: [] when it names no band and builds no "about " text.
func _problems(text: String, file: String) -> Array[String]:
	var out: Array[String] = []
	for pattern: String in PATTERNS:
		if RegEx.create_from_string(pattern).search(text) != null:
			out.append("%s: %s" % [file, pattern])
	return out


## Every .gd path under `root`, recursive, sorted.
func _scripts(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for name: String in dir.get_files():
		if name.ends_with(".gd"):
			out.append("%s/%s" % [root, name])
	for sub: String in dir.get_directories():
		out.append_array(_scripts("%s/%s" % [root, sub]))
	return out


func test_no_band_or_about_text_under_core_or_shell() -> void:
	var seen := 0
	for root: String in ROOTS:
		for path: String in _scripts(root):
			seen += 1
			assert_eq(_problems(FileAccess.get_file_as_string(path), path), [] as Array[String], path)
	assert_gt(seen, 250, "the scan reads the whole of core/ and shell/")


func test_p_a_band_definition_or_call_is_reported() -> void:
	assert_eq(_problems("static func band(n: int) -> int:\n\treturn n", "knowledge.gd").size(), 1, "a definition")
	assert_eq(_problems("var t := Knowledge.band_text(n, \"ducats\")", "supply_view.gd").size(), 1, "band_text")
	assert_eq(_problems("var b := Knowledge.band(n)", "x.gd").size(), 1, "Knowledge.band")
	assert_eq(_problems("var b := band(n)", "x.gd").size(), 1, "a bare call")


func test_p_a_built_about_text_is_reported() -> void:
	assert_eq(_problems("var about := \"about \" if seen else \"\"", "odds_card.gd").size(), 1)
	assert_eq(_problems("return \"about %s\" % n", "study.gd").size(), 1, "a leading about in a literal")


func test_the_forms_that_stay_are_not_reported() -> void:
	assert_eq(_problems("var b := yield_band(year)\nvar f := food_band(net)", "map_modes.gd").size(), 0, "other bands")
	assert_eq(_problems("var band := 2\nband += 1", "map_modes.gd").size(), 0, "a band variable")
	assert_eq(_problems("\"falls in about %s\" % text", "odds_view.gd").size(), 0, "a forecast is a projection, not a band")


## The tile window's files (tilewin-build-spec 7.1: the fog proofs of TW15) are named here as well, so the scan above is not the
## only thing that covers them: each must exist, have text, and name no band and no built "about " text.
const TILE_FILES: Array[String] = [
	"res://core/views/tile_view.gd", "res://core/views/tile_army.gd", "res://core/views/tile_buildings.gd",
	"res://core/views/building_card.gd", "res://core/views/company_card.gd",
	"res://tests/core/test_tile_fog.gd", "res://tests/core/test_tile_door.gd",
]


func test_the_tile_window_files_name_no_band_and_no_about() -> void:
	for path: String in TILE_FILES:
		var text := FileAccess.get_file_as_string(path)
		assert_gt(text.length(), 0, "%s has text" % path)
		assert_eq(_problems(text, path), [] as Array[String], path)
