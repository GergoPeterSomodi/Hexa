## GUT tests for ModeLegend (docs/architecture/m4-5-build-spec.md 6.7, 9): one row a band from MapModes.legend, a stripe
## swatch for a loss, hidden for the other modes, under a screen and in photo mode, mouse and focus ignored, the
## description lists the rows, and it fits under the top bar at 1280 x 720 and 2560 x 1440 (its size is in px).
extends GutTest

const TOP_BAR_H := 40.0
const TOP_GAP := 12.0

var _legend: ModeLegend


func before_each() -> void:
	_legend = (load("res://shell/hud/mode_legend.tscn") as PackedScene).instantiate() as ModeLegend
	_legend.theme = KitTheme.load_for(1.0)
	add_child_autofree(_legend)


func _column() -> VBoxContainer:
	return _legend.get_node("Column") as VBoxContainer


func test_yields_shows_one_row_a_band_top_first() -> void:
	_legend.show_mode(MapModes.Mode.YIELDS)
	var rows := _legend.rows()
	assert_eq(rows.size(), 10, "eight bands, a loss and not your land")
	assert_eq(str(rows[0]["text"]), "400 and more", "the top band first")
	assert_eq(str(rows[7]["text"]), "Nothing", "byte 2 is Nothing")
	assert_eq(str(rows[8]["text"]), "A loss")
	assert_eq(str(rows[9]["text"]), "Not your land")
	assert_true(_legend.visible, "shown for Yields")
	assert_eq(_column().get_child_count(), 11, "the title and one line a row")
	assert_eq(str((_column().get_child(0) as Label).text), ModeLegend.TITLE)


func test_only_a_loss_is_striped() -> void:
	_legend.show_mode(MapModes.Mode.YIELDS)
	var rows := _legend.rows()
	for i: int in rows.size():
		assert_eq(bool(rows[i]["stripes"]), i == 8, "row %d stripes only for a loss" % i)
	var loss := (_column().get_child(9) as HBoxContainer).get_child(0) as ModeLegend.Swatch
	assert_true(loss.stripes, "the loss swatch is striped")
	assert_eq(loss.colour, MapModes.YIELD_COLOURS[0], "the loss swatch takes the madder colour")
	var top := (_column().get_child(1) as HBoxContainer).get_child(0) as ModeLegend.Swatch
	assert_false(top.stripes, "a band swatch is solid")
	assert_eq(top.colour, MapModes.YIELD_COLOURS[8], "the top band takes its colour")


func test_other_modes_hide_the_legend() -> void:
	for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.OWNER, MapModes.Mode.RELIEF]:
		_legend.show_mode(mode)
		assert_false(_legend.visible, "hidden for mode %d" % mode)
		assert_eq(_legend.rows().size(), 0)
		assert_eq(_column().get_child_count(), 0, "no rows left over")


func test_hide_legend_hides_and_show_again_rebuilds_not_stacks() -> void:
	_legend.show_mode(MapModes.Mode.YIELDS)
	_legend.show_mode(MapModes.Mode.YIELDS)
	assert_eq(_column().get_child_count(), 11, "showing again replaces the rows")
	_legend.hide_legend()
	assert_false(_legend.visible)
	assert_eq(_legend.mode(), -1)


func test_a_screen_hides_it_until_it_closes() -> void:
	_legend.show_mode(MapModes.Mode.YIELDS)
	_legend.set_covered(true)
	assert_true(_legend.is_covered())
	assert_false(_legend.visible, "hidden under a screen")
	_legend.set_covered(false)
	assert_true(_legend.visible, "back when the screen closes")


func test_photo_mode_hides_it() -> void:
	_legend.show_mode(MapModes.Mode.YIELDS)
	_legend.set_hidden_by_hud(true)
	assert_true(_legend.is_hidden_by_hud())
	assert_false(_legend.visible, "hidden in photo mode")
	_legend.set_hidden_by_hud(false)
	assert_true(_legend.visible)


func test_covered_and_photo_mode_are_independent() -> void:
	_legend.show_mode(MapModes.Mode.YIELDS)
	_legend.set_covered(true)
	_legend.set_hidden_by_hud(true)
	_legend.set_covered(false)
	assert_false(_legend.visible, "still hidden by photo mode")
	_legend.set_hidden_by_hud(false)
	assert_true(_legend.visible)


func test_mouse_and_focus_are_ignored() -> void:
	_legend.show_mode(MapModes.Mode.YIELDS)
	assert_eq(_legend.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(_legend.focus_mode, Control.FOCUS_NONE)
	for node: Node in _legend.find_children("*", "Control", true, false):
		var c := node as Control
		assert_eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % c.name)


func test_description_lists_the_rows() -> void:
	_legend.show_mode(MapModes.Mode.YIELDS)
	var text := _legend.accessibility_description
	assert_true(text.begins_with(ModeLegend.TITLE), "starts with the title")
	assert_true(text.contains("400 and more"))
	assert_true(text.contains("A loss"))
	assert_true(text.contains("Not your land"))
	_legend.show_mode(MapModes.Mode.TERRAIN)
	assert_eq(_legend.accessibility_description, "", "no description when hidden")


func test_fits_under_the_top_bar_at_1280_by_720_and_2560_by_1440() -> void:
	_legend.show_mode(MapModes.Mode.YIELDS)
	var min_size := _legend.get_combined_minimum_size()
	assert_lte(min_size.x, ModeLegend.WIDTH, "the card is no wider than 220 px")
	assert_eq(_legend.custom_minimum_size.x, ModeLegend.WIDTH)
	var room_720 := 720.0 - TOP_BAR_H - TOP_GAP
	assert_lt(min_size.y, room_720, "fits below the bar at 1280 x 720")
	var room_1440 := 1440.0 - TOP_BAR_H - TOP_GAP
	assert_lt(min_size.y, room_1440, "fits below the bar at 2560 x 1440")


func test_reparent_keeps_the_rows() -> void:
	_legend.show_mode(MapModes.Mode.YIELDS)
	var host := Control.new()
	add_child_autofree(host)
	_legend.reparent(host)
	assert_eq(_column().get_child_count(), 11, "the title and ten rows survive a reparent")
	assert_true(_legend.visible, "still shown for Yields")
	assert_eq(_legend.rows().size(), 10)


func test_several_reparents_do_not_stack_rows() -> void:
	_legend.show_mode(MapModes.Mode.YIELDS)
	var host_a := Control.new()
	var host_b := Control.new()
	add_child_autofree(host_a)
	add_child_autofree(host_b)
	for i: int in 3:
		_legend.reparent(host_a)
		_legend.reparent(host_b)
	_legend.reparent(host_a)
	assert_eq(_column().get_child_count(), 11, "no double rows after several reparents")
	assert_eq(_legend.get_parent(), host_a, "ends in the last host")


func test_the_rows_are_compact_20_px() -> void:
	_legend.show_mode(MapModes.Mode.YIELDS)
	for child: Node in _column().get_children():
		if child is HBoxContainer:
			assert_lte((child as HBoxContainer).get_combined_minimum_size().y, ModeLegend.ROW_H + 0.5, "a row is 20 px")
	assert_lt(_legend.get_combined_minimum_size().y, 260.0, "the whole card is compact")
