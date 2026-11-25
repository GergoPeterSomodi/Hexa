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
			assert_eq(TileTabs.order_of(script), 50, "the fake tab has ORDER 50")
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
	var dup := _in_memory("extends TileTab\nconst ID := &\"dup\"\nconst LABEL := \"Dup\"\nconst ORDER := 50\n")
	var problems := TileTabs.check([fake, dup])
	assert_eq(problems.size(), 1, "one problem for the duplicate")
	assert_true(problems.size() > 0 and problems[0].contains("duplicate ORDER 50"),
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


func test_a_tab_is_live_by_default() -> void:
	assert_eq(TileTab.dimmed({"case": "own"}), "", "the base tab is live for any view")
	var fake := load(FAKE) as GDScript
	assert_eq(str(fake.call("dimmed", {"case": "own", "settlement": true})), "", "the fake tab is live on its own settlement")


func test_dimmed_in_gives_the_reason_of_a_shown_dimmed_tab() -> void:
	var shut := _in_memory("extends TileTab\nconst ID := &\"shut\"\nconst LABEL := \"Shut\"\nconst ORDER := 60\n"
			+ "static func applies(view: Dictionary) -> bool:\n\treturn view.get(\"case\", \"\") == \"foreign\"\n"
			+ "static func dimmed(_view: Dictionary) -> String:\n\treturn \"Not yours\"\n")
	var view := {"case": "foreign"}
	var dimmed := TileTabs.dimmed_in([shut], view)
	assert_eq(dimmed, {&"shut": "Not yours"}, "a dimmed tab that applies gives its reason, keyed by id")


func test_dimmed_in_skips_tabs_that_do_not_apply() -> void:
	var shut := _in_memory("extends TileTab\nconst ID := &\"shut\"\nconst LABEL := \"Shut\"\nconst ORDER := 60\n"
			+ "static func applies(view: Dictionary) -> bool:\n\treturn view.get(\"case\", \"\") == \"foreign\"\n"
			+ "static func dimmed(_view: Dictionary) -> String:\n\treturn \"Not yours\"\n")
	assert_true(TileTabs.dimmed_in([shut], {"case": "own"}).is_empty(),
			"a tab that does not apply is not listed as dimmed (it is absent, not dimmed)")


func test_dimmed_in_is_empty_for_live_tabs() -> void:
	var fake := load(FAKE) as GDScript
	assert_true(TileTabs.dimmed_in([fake], {"case": "own", "settlement": true}).is_empty(),
			"a live shown tab gives no reason")


func test_shown_in_orders_by_order() -> void:
	var late := _in_memory("extends TileTab\nconst ID := &\"late\"\nconst LABEL := \"Late\"\nconst ORDER := 90\n"
			+ "static func applies(_view: Dictionary) -> bool:\n\treturn true\n")
	var early := _in_memory("extends TileTab\nconst ID := &\"early\"\nconst LABEL := \"Early\"\nconst ORDER := 5\n"
			+ "static func applies(_view: Dictionary) -> bool:\n\treturn true\n")
	assert_eq(TileTabs.shown_in([late, early], {}), [&"early", &"late"] as Array[StringName], "shown tabs sort by ORDER")
