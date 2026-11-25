## The tile window's tab registry (tile-window spec R11, D4): the fake tab of the fixture folder is found through
## with_folder (a hard-coded list would miss it), it applies on an own settlement, and a duplicate ORDER or a missing
## constant is named by the check.
extends GutTest

const FIXTURE := "res://tests/shell/fixtures/tile_tabs"
const FAKE := "res://tests/shell/fixtures/tile_tabs/fake_tab.gd"


func after_each() -> void:
	TileTabs.reset()


func _in_memory(source: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = source
	assert_eq(script.reload(), OK, "in-memory tab script parses")
	return script


func test_fake_tab_found_through_with_folder() -> void:
	TileTabs.reset()
	var tabs := TileTabs.with_folder(FIXTURE)
	var ids: Array[StringName] = []
	for script: GDScript in tabs:
		ids.append(TileTabs.id_of(script))
	assert_true(ids.has(&"industry"), "with_folder lists the fixture's fake tab")
	for script: GDScript in tabs:
		if TileTabs.id_of(script) == &"industry":
			assert_eq(TileTabs.order_of(script), 30, "the fake tab has ORDER 30")
			assert_eq(script.get_script_constant_map()["LABEL"], "Industry", "the fake tab is labelled Industry")


func test_for_view_lists_industry_on_own_settlement_only() -> void:
	TileTabs.reset()
	TileTabs.with_folder(FIXTURE)
	assert_true(TileTabs.for_view({"case": "own", "settlement": true}).has(&"industry"),
			"the fake tab applies on an own settlement")
	assert_false(TileTabs.for_view({"case": "own", "settlement": false}).has(&"industry"),
			"the fake tab does not apply on own land that is no settlement")
	assert_false(TileTabs.for_view({"case": "foreign", "settlement": true}).has(&"industry"),
			"the fake tab does not apply on a foreign settlement")


func test_reset_drops_the_fixture_folder() -> void:
	TileTabs.reset()
	TileTabs.with_folder(FIXTURE)
	TileTabs.reset()
	var ids: Array[StringName] = []
	for script: GDScript in TileTabs.all():
		ids.append(TileTabs.id_of(script))
	assert_false(ids.has(&"industry"), "reset forgets the extra folder")


func test_base_script_is_not_a_tab() -> void:
	var listed := TileTabs.list_folder(FIXTURE)
	assert_true(listed.has(FAKE), "the folder listing finds the fake tab")
	for path: String in TileTabs.list_folder(TileTabs.FOLDER):
		assert_false(path.ends_with(TileTabs.BASE_SCRIPT), "the base script is not listed as a tab")


func test_index_matches_the_real_folder() -> void:
	assert_eq(PackedStringArray(TileTabs.Index.PATHS), TileTabs.list_folder(TileTabs.FOLDER),
			"tile_tabs_index.gd lists the real folder (run tools/build_tile_tabs.gd after a change)")


func test_duplicate_order_is_named() -> void:
	var fake := load(FAKE) as GDScript
	var dup := _in_memory("extends TileTab\nconst ID := &\"dup\"\nconst LABEL := \"Dup\"\nconst ORDER := 30\n")
	var problems := TileTabs.check([fake, dup])
	assert_eq(problems.size(), 1, "one problem for the duplicate")
	assert_true(problems.size() > 0 and problems[0].contains("duplicate ORDER 30"),
			"the duplicate ORDER is named with its value")


func test_missing_constant_is_named() -> void:
	var no_label := _in_memory("extends TileTab\nconst ID := &\"nolabel\"\nconst ORDER := 40\n")
	var problems := TileTabs.check([no_label])
	assert_eq(problems.size(), 1, "one problem for the missing constant")
	assert_true(problems.size() > 0 and problems[0].contains("missing constant LABEL"),
			"the missing constant is named")


func test_unique_orders_pass_the_check() -> void:
	var fake := load(FAKE) as GDScript
	var other := _in_memory("extends TileTab\nconst ID := &\"other\"\nconst LABEL := \"Other\"\nconst ORDER := 40\n")
	assert_eq(TileTabs.check([fake, other]).size(), 0, "two tabs with different ORDER pass")
