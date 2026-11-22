## The busy pill (docs/architecture/m8-build-spec.md 6.1): its three texts, the card frame, the still hourglass, no mouse, no focus.
extends GutTest

var _pill: BusyPill


func before_each() -> void:
	_pill = (load("res://shell/hud/busy_pill.tscn") as PackedScene).instantiate() as BusyPill
	add_child_autofree(_pill)


func test_hidden_until_told() -> void:
	assert_false(_pill.visible)


func test_the_three_texts() -> void:
	_pill.show_orders(2, 12)
	assert_true(_pill.visible)
	assert_eq(_pill.text(), "Countries are moving 3 / 12")
	_pill.show_orders(12, 12)
	assert_eq(_pill.text(), "Countries are moving 12 / 12", "never past the total")
	_pill.show_text("The season ends")
	assert_eq(_pill.text(), "The season ends")
	_pill.show_text("The moves of Summer 1480 · Space skips them")
	assert_eq(_pill.text(), "The moves of Summer 1480 · Space skips them")


func test_no_seat_shows_only_the_season_ends() -> void:
	_pill.show_orders(0, 0)
	assert_eq(_pill.text(), "The season ends")


func test_hide_pill() -> void:
	_pill.show_text("x")
	_pill.hide_pill()
	assert_false(_pill.visible)


func test_frame_mouse_focus_and_text_variation() -> void:
	assert_eq(_pill.theme_type_variation, &"PanelCard")
	assert_eq(_pill.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(_pill.focus_mode, Control.FOCUS_NONE)
	var text := _pill.get_node("Row/Text") as Label
	assert_eq(text.theme_type_variation, &"Body")
	assert_eq(text.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq((_pill.get_node("Row/Icon") as TextureRect).mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_the_hourglass_is_the_kits_still_icon() -> void:
	var theme := load(KitTheme.THEME_PATH) as Theme
	assert_not_null(theme, "the Studiolo theme loads")
	_pill.theme = theme
	var icon := _pill.get_node("Row/Icon") as TextureRect
	assert_not_null(icon.texture, "the hourglass comes from the Kit")
	assert_eq(icon.texture, theme.get_icon(&"hourglass", &"Kit"))
	assert_eq(_pill.get_children().size(), 1, "no animation node")
