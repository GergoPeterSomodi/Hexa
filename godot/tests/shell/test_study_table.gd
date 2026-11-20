## GUT tests for StudyTable (m4-5-build-spec.md 6.2 and its test row): the six column kinds, stable sorting with ties by
## id both ways, the header arrows, 100 rows and "Show more", Enter, double click and Go, the Ctrl+arrows and Home and End,
## the selection kept by id, the mine row, refused rows and the accessible text.
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


func _table(cols: Array, rows: Array, size: Vector2 = Vector2(640.0, 320.0)) -> StudyTable:
	var table := StudyTable.new()
	table.size = size
	_root.add_child(table)
	table.set_columns(cols)
	table.set_rows(rows)
	return table


func _districts_columns() -> Array:
	return [
		{"id": &"place", "title": "Place"},
		{"id": &"gain", "title": "A year", "kind": &"number"},
		{"id": &"change", "title": "This season", "kind": &"delta"},
		{"id": &"share", "title": "Share", "kind": &"bar", "ink": 1},
		{"id": &"seasons", "title": "Seasons", "kind": &"spark", "ink": 0},
		{"id": &"go", "title": "", "kind": &"button"},
	]


func _districts(n: int) -> Array:
	var rows: Array = []
	for i: int in n:
		rows.append({
			"id": i + 1,
			"cells": {
				"place": "Place %03d" % (i + 1),
				"gain": {"value": (i * 37) % 90, "text": ""},
				"change": (i % 7) - 3,
				"share": (i * 13) % 1001,
				"seasons": PackedInt32Array([i % 5, 2, 4, i % 3]),
				"go": {"text": "Go"},
			},
			"hex": Vector2i(i, 13),
		})
	return rows


func test_structure_and_theme() -> void:
	var table := _table(_districts_columns(), _districts(3))
	var tree := table.tree()
	assert_eq(tree.theme_type_variation, &"StudyTree")
	assert_true(tree.column_titles_visible)
	assert_true(tree.hide_root)
	assert_eq(tree.select_mode, Tree.SELECT_ROW)
	assert_eq(tree.columns, 6)
	assert_eq(tree.get_column_title_alignment(1), HORIZONTAL_ALIGNMENT_RIGHT, "numbers are right aligned")
	assert_eq(tree.get_column_title_alignment(0), HORIZONTAL_ALIGNMENT_LEFT)
	assert_eq(table.column_header(1), "A year")


func test_six_column_kinds_are_drawn() -> void:
	var table := _table(_districts_columns(), _districts(3))
	await _harness.wait_frames(self, 1)
	var item := table.tree().get_root().get_child(1)
	assert_not_null(item)
	# number: grouped text, right aligned
	assert_eq(item.get_text(1), "37")
	assert_eq(item.get_text_alignment(1), HORIZONTAL_ALIGNMENT_RIGHT)
	# delta: signed text with the U+2212 minus and an arrow icon
	assert_eq(item.get_text(2), "−2", "row 2 has change (1 mod 7) - 3 = -2, shown with U+2212")
	assert_not_null(item.get_icon(2), "a delta cell has its Kit arrow")
	# bar and spark are custom drawn; the button has one button with the Go tip
	assert_eq(item.get_cell_mode(3), TreeItem.CELL_MODE_CUSTOM)
	assert_eq(item.get_cell_mode(4), TreeItem.CELL_MODE_CUSTOM)
	assert_eq(item.get_button_count(5), 1)
	assert_eq(item.get_button_tooltip_text(5, 0), "Go")


func test_delta_signs_and_tones() -> void:
	var rows := [
		{"id": 1, "cells": {"place": "A", "change": 6}},
		{"id": 2, "cells": {"place": "B", "change": -6}},
		{"id": 3, "cells": {"place": "C", "change": 0}},
		{"id": 4, "cells": {"place": "D", "change": {"value": -4, "tone": "good"}}},
	]
	var table := _table([{"id": &"place", "title": "P"}, {"id": &"change", "title": "Change", "kind": &"delta"}], rows)
	var tree := table.tree()
	await _harness.wait_frames(self, 1)
	var root_item := tree.get_root()
	assert_eq(root_item.get_child(0).get_text(1), "+6")
	assert_eq(root_item.get_child(1).get_text(1), "−6", "the minus sign is U+2212")
	assert_eq(root_item.get_child(2).get_text(1), "0")
	assert_eq(root_item.get_child(3).get_text(1), "−4", "a tone given by the caller colours the cell, the sign stays")
	assert_eq(root_item.get_child(0).get_custom_color(1), Tokens.GOOD)
	assert_eq(root_item.get_child(1).get_custom_color(1), Tokens.BAD)
	assert_eq(root_item.get_child(3).get_custom_color(1), Tokens.GOOD)


func test_stable_sort_breaks_ties_by_id_both_ways() -> void:
	var table := _table(
		[{"id": &"name", "title": "District"}, {"id": &"gain", "title": "Gain", "kind": &"number"}],
		[
			{"id": 3, "cells": {"name": "Savona", "gain": 12}},
			{"id": 1, "cells": {"name": "Genoa", "gain": 41}},
			{"id": 2, "cells": {"name": "Polcevera", "gain": 12}},
		])
	assert_eq(table.sorted_ids(), [3, 1, 2], "unsorted rows keep the order given")
	table.sort_by(&"gain", false)
	assert_eq(table.sorted_ids(), [2, 3, 1], "ascending: the 12 tie is broken by id, 2 before 3")
	assert_eq(table.column_header(1), "Gain ↑")
	table.sort_by(&"gain", true)
	assert_eq(table.sorted_ids(), [1, 2, 3], "descending: the 12 tie is still 2 before 3")
	assert_eq(table.column_header(1), "Gain ↓")
	assert_eq(table.column_header(0), "District")


func test_header_click_and_descending_first() -> void:
	var table := _table(
		[{"id": &"name", "title": "District"}, {"id": &"gain", "title": "Gain", "kind": &"number"}],
		[
			{"id": 1, "cells": {"name": "Savona", "gain": 12}},
			{"id": 2, "cells": {"name": "Genoa", "gain": 41}},
			{"id": 3, "cells": {"name": "polcevera", "gain": 5}},
		])
	var tree := table.tree()
	tree.column_title_clicked.emit(1, MOUSE_BUTTON_LEFT)
	assert_eq(table.sort_state(), {"id": &"gain", "descending": true}, "a number column sorts highest first at once")
	assert_eq(table.sorted_ids(), [2, 1, 3])
	tree.column_title_clicked.emit(1, MOUSE_BUTTON_LEFT)
	assert_eq(table.sorted_ids(), [3, 1, 2], "a second click toggles the direction")
	tree.column_title_clicked.emit(0, MOUSE_BUTTON_LEFT)
	assert_eq(table.sort_state(), {"id": &"name", "descending": false}, "a text column sorts A to Z first")
	assert_eq(table.sorted_ids(), [2, 3, 1], "text sort ignores case: Genoa, polcevera, Savona")
	tree.column_title_clicked.emit(1, MOUSE_BUTTON_RIGHT)
	assert_eq(table.sort_state()["id"], &"name", "only a left click sorts")


func test_hundred_rows_then_show_more() -> void:
	var table := _table(_districts_columns(), _districts(250), Vector2(900.0, 500.0))
	assert_eq(table.total_count(), 250)
	assert_eq(table.shown_count(), 100)
	var tree := table.tree()
	var last := tree.get_root().get_child(tree.get_root().get_child_count() - 1)
	assert_eq(last.get_text(0), "Showing 100 of 250 · Enter: show 100 more")
	table.show_more()
	assert_eq(table.shown_count(), 200)
	table.show_more()
	assert_eq(table.shown_count(), 250)
	table.show_more()
	assert_eq(table.shown_count(), 250, "show_more stops at the total")
	assert_eq(tree.get_root().get_child_count(), 250, "no more row once every row is shown")


func test_enter_double_click_and_go_activate_the_row() -> void:
	var table := _table(_districts_columns(), _districts(3), Vector2(900.0, 360.0))
	var activated: Array[Dictionary] = []
	table.row_activated.connect(func(row: Dictionary) -> void: activated.append(row))
	await _harness.wait_frames(self, 2)
	var tree := table.tree()
	var item := tree.get_root().get_child(1)
	tree.set_selected(item, 0)
	tree.grab_focus()
	await _harness.wait_frames(self, 1)
	_harness.send_key(KEY_ENTER)
	await _harness.wait_frames(self, 2)
	assert_eq(activated.size(), 1, "Enter activates the selected row")
	assert_eq(activated[0]["id"], 2)
	assert_eq(activated[0]["hex"], Vector2i(1, 13))

	var rect := tree.get_item_area_rect(item, 0)
	var at := tree.get_global_rect().position + rect.position + rect.size * 0.5
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.double_click = true
	press.position = at
	press.global_position = at
	_harness.push_input(press)
	await _harness.wait_frames(self, 2)
	assert_eq(activated.size(), 2, "a double click activates the row")

	tree.button_clicked.emit(item, 5, 0, MOUSE_BUTTON_LEFT)
	assert_eq(activated.size(), 3, "the Go button activates the row")
	assert_eq(activated[2]["id"], 2)


func test_arrows_move_the_row_and_ctrl_arrows_move_the_sort() -> void:
	var table := _table(
		[{"id": &"name", "title": "District"}, {"id": &"gain", "title": "Gain", "kind": &"number"}],
		[
			{"id": 1, "cells": {"name": "Savona", "gain": 12}},
			{"id": 2, "cells": {"name": "Genoa", "gain": 41}},
			{"id": 3, "cells": {"name": "Polcevera", "gain": 5}},
		])
	var selected: Array[int] = []
	table.row_selected.connect(func(row: Dictionary) -> void: selected.append(int(row["id"])))
	var tree := table.tree()
	await _harness.wait_frames(self, 2)
	tree.set_selected(tree.get_root().get_child(0), 0)
	tree.grab_focus()
	await _harness.wait_frames(self, 1)
	_harness.send_key(KEY_DOWN)
	await _harness.wait_frames(self, 1)
	assert_eq(selected.back(), 2, "Down moves to the next row in display order")
	_harness.send_key(KEY_END)
	await _harness.wait_frames(self, 1)
	assert_eq(selected.back(), 3, "End selects the last shown row")
	_harness.send_key(KEY_HOME)
	await _harness.wait_frames(self, 1)
	assert_eq(selected.back(), 1, "Home selects the first row")

	_harness.send_key(KEY_RIGHT, true, true)
	await _harness.wait_frames(self, 1)
	assert_eq(table.sort_state(), {"id": &"name", "descending": false}, "Ctrl+Right with no sort takes the first sortable column")
	assert_eq(table.sorted_ids(), [2, 3, 1])
	_harness.send_key(KEY_RIGHT, true, true)
	await _harness.wait_frames(self, 1)
	assert_eq(table.sort_state(), {"id": &"gain", "descending": true}, "Ctrl+Right sorts the next column, highest first")
	assert_eq(table.sorted_ids(), [2, 1, 3])
	_harness.send_key(KEY_DOWN, true, true)
	await _harness.wait_frames(self, 1)
	assert_eq(table.sort_state(), {"id": &"gain", "descending": false}, "Ctrl+Down sorts ascending")
	_harness.send_key(KEY_UP, true, true)
	await _harness.wait_frames(self, 1)
	assert_eq(table.sort_state(), {"id": &"gain", "descending": true}, "Ctrl+Up sorts descending")
	_harness.send_key(KEY_LEFT, true, true)
	await _harness.wait_frames(self, 1)
	assert_eq(table.sort_state()["id"], &"name", "Ctrl+Left moves back to the district column")


func test_selection_kept_by_id_over_sort_and_refresh() -> void:
	var table := _table(
		[{"id": &"name", "title": "District"}, {"id": &"gain", "title": "Gain", "kind": &"number"}],
		[
			{"id": 1, "cells": {"name": "Savona", "gain": 12}},
			{"id": 2, "cells": {"name": "Genoa", "gain": 41}},
			{"id": 3, "cells": {"name": "Polcevera", "gain": 5}},
		])
	table.select_id(3)
	assert_eq(table.selected_row()["id"], 3)
	table.sort_by(&"gain", true)
	assert_eq(table.selected_row()["id"], 3, "a re-sort keeps the row selected by id")
	var item_text := table.tree().get_selected().get_text(0)
	assert_eq(item_text, "Polcevera", "the selected item is the same row after the sort")

	table.set_rows([
		{"id": 3, "cells": {"name": "Polcevera", "gain": 50}},
		{"id": 1, "cells": {"name": "Savona", "gain": 12}},
	])
	assert_eq(table.selected_row()["id"], 3, "a refresh keeps the row selected by id")
	assert_eq(table.tree().get_selected().get_text(1), "50")

	table.set_rows([{"id": 1, "cells": {"name": "Savona", "gain": 12}}])
	assert_eq(table.selected_row(), {}, "a row that left the table is not selected")


func test_mine_row_is_marked() -> void:
	var table := _table(
		[{"id": &"name", "title": "District"}, {"id": &"gain", "title": "Gain", "kind": &"number"}],
		[
			{"id": 1, "cells": {"name": "Genoa", "gain": 41}, "mine": true},
			{"id": 2, "cells": {"name": "Savona", "gain": 12}},
		])
	await _harness.wait_frames(self, 1)
	var mine := table.tree().get_root().get_child(0)
	var other := table.tree().get_root().get_child(1)
	assert_eq(mine.get_text(0), "Genoa (you)")
	assert_eq(other.get_text(0), "Savona")
	assert_eq(mine.get_custom_color(0), table.tree().get_theme_color(&"font_color", &"TableHeader"))
	assert_true(table.row_name(1).begins_with("Genoa (you)"), "the accessible name carries the mark")


func test_refused_rows_are_skipped_with_an_error() -> void:
	var table := StudyTable.new()
	_root.add_child(table)
	table.set_columns([{"id": &"name", "title": "District"}])
	table.set_rows([
		{"id": 1, "cells": {"name": "Genoa"}},
		{"cells": {"name": "No id"}},
		{"id": 1, "cells": {"name": "Twice"}},
		{"id": &"savona", "cells": {"name": "String id"}},
	])
	assert_push_error_count(3)
	assert_eq(table.total_count(), 1)
	assert_eq(table.sorted_ids(), [1])


func test_row_names_and_summary() -> void:
	var table := _table(
		[{"id": &"name", "title": "District"}, {"id": &"gain", "title": "A year", "kind": &"number"}],
		[
			{"id": 1, "cells": {"name": "Genoa", "gain": 41}},
			{"id": 2, "cells": {"name": "Savona", "gain": 1068}},
		],
		Vector2(400.0, 200.0))
	table.section_title = "Districts"
	assert_eq(table.row_name(1), "Genoa, A year 41")
	assert_eq(table.row_name(2), "Savona, A year 1,068")
	assert_eq(table.summary(), "Districts: 2 rows, 2 shown.")
	table.sort_by(&"gain", true)
	assert_eq(table.summary(), "Districts: 2 rows, 2 shown, sorted by A year, highest first.")
	assert_eq(table.tree().accessibility_name, "Districts")
	assert_eq(table.tree().accessibility_description, "Districts: 2 rows, 2 shown, sorted by A year, highest first.")


func test_fits_1280_by_720_and_2560_by_1440() -> void:
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(2560, 1440)]:
		var harness := UIHarness.new(size)
		harness.mount(self)
		var root := Control.new()
		root.theme = KitTheme.load_for(1.0)
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		harness.viewport.add_child(root)
		var table := StudyTable.new()
		table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(table)
		table.set_columns(_districts_columns())
		table.set_rows(_districts(250))
		await harness.wait_frames(self, 2)
		assert_eq(table.size, Vector2(size), "the table fills %s and does not grow past it" % str(size))
		assert_eq(table.shown_count(), 100)
		harness.dispose()


func _named_rows(ids: Array) -> Array:
	var rows: Array = []
	for id: int in ids:
		rows.append({"id": id, "cells": {"name": "Row %d" % id, "gain": id * 10}})
	return rows


func _named_columns() -> Array:
	return [{"id": &"name", "title": "District"}, {"id": &"gain", "title": "Gain", "kind": &"number"}]


func test_button_only_on_rows_that_have_the_cell() -> void:
	var table := _table(
		[{"id": &"name", "title": "District"}, {"id": &"go", "title": "", "kind": &"button"}],
		[
			{"id": 1, "cells": {"name": "With", "go": {"text": "Go"}}},
			{"id": 2, "cells": {"name": "Without"}},
			{"id": 3, "cells": {"name": "Empty", "go": ""}},
			{"id": 4, "cells": {"name": "Null", "go": null}},
		])
	await _harness.wait_frames(self, 1)
	var tree := table.tree()
	var root_item := tree.get_root()
	assert_eq(root_item.get_child(0).get_button_count(1), 1, "a row with the cell has its Go button")
	assert_eq(root_item.get_child(1).get_button_count(1), 0, "a missing cell: no button")
	assert_eq(root_item.get_child(2).get_button_count(1), 0, "an empty cell: no button")
	assert_eq(root_item.get_child(3).get_button_count(1), 0, "a null cell: no button")

	var activated: Array[int] = []
	table.row_activated.connect(func(row: Dictionary) -> void: activated.append(int(row["id"])))
	tree.button_clicked.emit(root_item.get_child(0), 1, 0, MOUSE_BUTTON_LEFT)
	assert_eq(activated, [1], "the Go button activates its row")
	table.select_id(2)
	tree.item_activated.emit()
	assert_eq(activated, [1, 2], "Enter or a double click still activates a row without a button")


func test_set_rows_keeps_the_requested_page() -> void:
	var table := _table(_districts_columns(), _districts(250), Vector2(900.0, 500.0))
	table.show_more()
	table.show_more()
	assert_eq(table.shown_count(), 250)
	table.set_rows(_districts(150))
	assert_eq(table.shown_count(), 150, "a shorter refresh draws every row it has")
	table.set_rows(_districts(500))
	assert_eq(table.shown_count(), 250, "the requested page comes back with a longer refresh")


func test_selection_comes_back_when_its_id_returns() -> void:
	var table := _table(_named_columns(), _named_rows([1, 2, 3, 4, 5]))
	await _harness.wait_frames(self, 1)
	table.select_id(3)
	table.set_rows(_named_rows([1, 2]))
	assert_eq(table.selected_row(), {}, "while row 3 is gone nothing is selected")
	assert_null(table.tree().get_selected(), "and the tree shows no selection")
	table.set_rows(_named_rows([1, 2, 3, 4, 5]))
	assert_eq(table.selected_row()["id"], 3, "the selection returns with its id")
	assert_eq(table.tree().get_selected().get_text(0), "Row 3")

