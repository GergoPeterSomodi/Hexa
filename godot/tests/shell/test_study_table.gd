## GUT tests for StudyTable: columns, tabular numeric alignment, stable sorting with tie-breaking
## by id, header sort arrows, column click toggling, and Enter/row activation
## (docs/architecture/ui-style-and-feedback-spec.md sections 5 and 11).
extends GutTest

var _harness: UIHarness = null
var _root: Control = null


func before_each() -> void:
	_harness = UIHarness.new()
	_harness.mount(self)
	_root = Control.new()
	_root.theme = KitTheme.load_for(1.0)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_harness.viewport.add_child(_root)


func after_each() -> void:
	_root = null
	_harness = null


func test_columns_stable_sort_tie_breaking_and_headers() -> void:
	var table := StudyTable.new()
	table.size = Vector2(520.0, 260.0)
	_root.add_child(table)

	var tree := table.tree()
	assert_eq(tree.theme_type_variation, &"StudyTree")
	assert_true(tree.column_titles_visible)
	assert_true(tree.hide_root)
	assert_eq(tree.select_mode, Tree.SELECT_ROW)

	table.set_columns([
		{"id": &"name", "title": "District"},
		{"id": &"gain", "title": "Gain", "kind": &"number"},
	])
	assert_eq(tree.columns, 2)
	assert_eq(tree.get_column_title_alignment(0), HORIZONTAL_ALIGNMENT_LEFT)
	assert_eq(tree.get_column_title_alignment(1), HORIZONTAL_ALIGNMENT_RIGHT)

	table.set_rows([
		{"id": 3, "name": "Savona", "gain": 12, "hex": Vector2i(6, 13)},
		{"id": 1, "name": "Genoa", "gain": 41, "hex": Vector2i(8, 13)},
		{"id": 2, "name": "Polcevera", "gain": 12, "hex": Vector2i(9, 13)},
	])
	assert_eq(table.sorted_ids(), [3, 1, 2])

	var sort_events: Array[Array] = []
	table.sort_changed.connect(func(id: StringName, desc: bool) -> void: sort_events.append([id, desc]))

	table.sort_by(&"gain", false)
	assert_eq(table.sorted_ids(), [2, 3, 1], "ascending sort breaks 12-gain tie by id (2 before 3)")
	assert_eq(table.column_header(1), "Gain ↑")
	assert_eq(table.column_header(0), "District")

	table.sort_by(&"gain", true)
	assert_eq(table.sorted_ids(), [1, 2, 3], "descending sort also breaks 12-gain tie by id (2 before 3)")
	assert_eq(table.column_header(1), "Gain ↓")

	tree.column_title_clicked.emit(0, MOUSE_BUTTON_LEFT)
	assert_eq(table.sorted_ids(), [1, 2, 3], "clicking District sorts ascending (Genoa, Polcevera, Savona)")
	assert_eq(table.column_header(0), "District ↑")
	assert_eq(table.column_header(1), "Gain")

	tree.column_title_clicked.emit(0, MOUSE_BUTTON_LEFT)
	assert_eq(table.sorted_ids(), [3, 2, 1], "clicking District again toggles descending")
	assert_eq(table.column_header(0), "District ↓")
	assert_eq(sort_events.size(), 4)


func test_row_activation_by_enter_and_double_click() -> void:
	var table := StudyTable.new()
	table.size = Vector2(520.0, 240.0)
	_root.add_child(table)

	table.set_columns([
		{"id": &"name", "title": "District"},
		{"id": &"gain", "title": "Gain", "kind": &"number"},
	])
	table.set_rows([
		{"id": &"genoa", "name": "Genoa", "gain": 41, "hex": Vector2i(8, 13)},
		{"id": &"savona", "name": "Savona", "gain": 12, "hex": Vector2i(6, 13)},
	])

	var activated: Array[Dictionary] = []
	table.row_activated.connect(func(row: Dictionary) -> void: activated.append(row))

	await _harness.wait_frames(self, 2)
	var tree := table.tree()
	var root_item := tree.get_root()
	assert_not_null(root_item)
	var second_item := root_item.get_child(1)
	assert_not_null(second_item)
	assert_eq(second_item.get_text_alignment(1), HORIZONTAL_ALIGNMENT_RIGHT)

	tree.set_selected(second_item, 0)
	table.grab_focus()
	await _harness.wait_frames(self, 1)

	_harness.send_key(KEY_ENTER)
	await _harness.wait_frames(self, 2)
	assert_eq(activated.size(), 1, "Enter activates selected row")
	assert_eq(activated[0]["id"], &"savona")
	assert_eq(activated[0]["hex"], Vector2i(6, 13))
