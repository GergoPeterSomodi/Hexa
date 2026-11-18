## Studiolo inspected-hex side panel tests (docs/architecture/m1-build-spec.md section 11, T14;
## docs/architecture/ui-style-and-feedback-plan.md H1).
extends GutTest

const PANEL := "res://shell/panels/hex_panel.tscn"
const SEARCH_LIMIT := 400

var _panel: HexPanel = null


func before_each() -> void:
	Bindings.ensure()
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	_panel = (load(PANEL) as PackedScene).instantiate() as HexPanel
	_panel.theme = KitTheme.load_for(1.0)
	add_child_autofree(_panel)
	Events.hex_changed.connect(_on_hex_changed)


func after_each() -> void:
	if Events.hex_changed.is_connected(_on_hex_changed):
		Events.hex_changed.disconnect(_on_hex_changed)
	await get_tree().process_frame


func _on_hex_changed(_hex: Vector2i) -> void:
	_panel.refresh()


func _wild_land_with_options(limit: int) -> Array[Vector2i]:
	var game := Session.game
	var out: Array[Vector2i] = []
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if game.map.land[i] == 1 and Improve.piece_at(game, hex).is_empty() and not Improve.build_options(game, hex).is_empty():
			out.append(hex)
			if out.size() >= limit:
				break
	return out


func _press(prefix: String) -> void:
	for button: Button in _panel.action_buttons():
		if not button.disabled and button.text.begins_with(prefix):
			button.pressed.emit()
			return
	fail_test("no enabled button starts with '%s'" % prefix)


func _button(prefix: String) -> Button:
	for button: Button in _panel.action_buttons():
		if button.text.begins_with(prefix):
			return button
	return null


func _row_value(grid_path: String, key: String) -> String:
	var kids := (_panel.get_node(grid_path) as GridContainer).get_children()
	for at: int in range(0, kids.size() - 1, 2):
		if (kids[at] as Label).text == key:
			return (kids[at + 1] as Label).text
	return ""


func _reason_lines() -> Array[String]:
	var out: Array[String] = []
	for node: Node in (_panel.get_node("Body/ActionsBox/Actions") as VBoxContainer).get_children():
		if node is Label:
			out.append((node as Label).text)
	return out


func test_it_is_hidden_until_a_hex_is_shown_and_stops_the_mouse_with_studiolo_frame() -> void:
	assert_false(_panel.visible, "hidden at the start")
	assert_eq(_panel.shown_hex(), HexPanelContract.NO_HEX)
	assert_eq(_panel.mouse_filter, Control.MOUSE_FILTER_STOP, "a click on the panel never reaches the map")
	assert_eq(_panel.custom_minimum_size.x, float(Tokens.PANEL_W), "width matches Tokens.PANEL_W")
	assert_eq((_panel.get_node("Body/PieceBox/Heading") as Label).theme_type_variation, &"SectionHead")
	assert_eq((_panel.get_node("Body/GroundBox/Heading") as Label).theme_type_variation, &"SectionHead")
	assert_eq((_panel.get_node("Body/ActionsBox/Heading") as Label).theme_type_variation, &"SectionHead")

	var hex := _wild_land_with_options(1)[0]
	_panel.show_hex(hex)
	assert_true(_panel.visible)
	assert_eq(_panel.shown_hex(), hex)
	assert_eq(_panel.cartouche().theme_type_variation, &"PanelCartouche")
	assert_eq(_panel.cartouche().label().theme_type_variation, &"TitlePanel")
	for button: Button in _panel.action_buttons():
		assert_true(button is KitButton, "actions use Studiolo KitButton")
		assert_eq(button.focus_mode, Control.FOCUS_NONE, "buttons take no keyboard focus")
	_panel.clear()
	assert_false(_panel.visible, "clear hides it")
	assert_eq(_panel.shown_hex(), HexPanelContract.NO_HEX)


func test_a_wild_hex_shows_its_ground_and_lists_its_builds() -> void:
	var hex := _wild_land_with_options(1)[0]
	_panel.show_hex(hex)
	assert_eq(_panel.subtitle_label().text, "Hex %d, %d" % [hex.x, hex.y])
	assert_eq(_row_value("Body/PieceBox/Rows", "Stands on it"), "nothing (wild land)")
	assert_ne(_row_value("Body/GroundBox/Rows", "Ground"), "", "the ground is written")
	assert_ne(_row_value("Body/GroundBox/Rows", "Height"), "", "the height is written")
	var piece_rows := (_panel.get_node("Body/PieceBox/Rows") as GridContainer).get_children()
	assert_eq((piece_rows[0] as Label).theme_type_variation, &"Hint", "ledger keys use Hint")
	assert_eq((piece_rows[1] as Label).theme_type_variation, &"TableRow", "ledger values use TableRow")
	assert_true((_panel.get_node("Body/GroundBox") as VBoxContainer).visible)
	assert_eq((_panel.get_node("Body/ActionsBox/Heading") as Label).text, "Build here")
	var enabled := 0
	for button: Button in _panel.action_buttons():
		assert_true(button.text.begins_with("Build "), "every button is a build: " + button.text)
		if not button.disabled:
			enabled += 1
	assert_gt(enabled, 0, "at least one build can be pressed")


func test_a_sea_hex_shows_no_actions() -> void:
	var game := Session.game
	var sea := Vector2i(-1, -1)
	for i: int in game.map.hex_count():
		if game.map.land[i] == 0:
			sea = game.map.hex_of(i)
			break
	assert_ne(sea, Vector2i(-1, -1), "the map has a sea hex")
	_panel.show_hex(sea)
	assert_true(_panel.visible)
	assert_eq(_panel.cartouche().text, "Sea")
	assert_eq(_panel.cartouche().label().text, "SEA")
	assert_false((_panel.get_node("Body/ActionsBox") as VBoxContainer).visible)
	assert_true(_panel.action_buttons().is_empty())


func test_a_refused_button_is_disabled_and_shows_its_reason() -> void:
	var game := Session.game
	var place_hex := Vector2i(-1, -1)
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		var piece := Improve.piece_at(game, hex)
		if not piece.is_empty() and int(piece["family_id"]) == ImproveRules.SETTLEMENT and game.improvement.is_fixed(hex):
			place_hex = hex
			break
	assert_ne(place_hex, Vector2i(-1, -1), "a place of the map stands on a settlement")
	_panel.show_hex(place_hex)
	var clear_button := _button("Clear") as KitButton
	assert_not_null(clear_button, "a built hex has Clear")
	assert_eq(clear_button.kind, KitButton.Kind.DANGER)
	assert_true(clear_button.disabled, "a place is never pulled down, so Clear is refused")
	var reason := str(Session.check("clear", {"hex": place_hex})["reason"])
	assert_ne(reason, "", "the rules give a reason")
	assert_eq(clear_button.tooltip_text, reason, "the reason is the tooltip")
	assert_eq(clear_button.reason_text(), reason, "KitButton tracks verdict reason")
	assert_eq(clear_button.icon, clear_button.get_theme_icon(&"lock", &"Kit"), "refused KitButton shows lock icon")
	assert_true(_reason_lines().has(reason), "the reason is a line under the actions")


func test_build_then_upgrade_then_clear_go_through_session() -> void:
	var done := false
	for hex: Vector2i in _wild_land_with_options(SEARCH_LIMIT):
		_panel.show_hex(hex)
		var is_wild := Improve.piece_at(Session.game, hex).is_empty()
		if not is_wild or not _has_enabled("Build"):
			continue
		_press("Build")
		assert_false(Improve.piece_at(Session.game, hex).is_empty(), "Build put a piece on the hex")
		assert_eq(_row_value("Body/PieceBox/Rows", "Level"), "level 1, " + _level_word_for(hex), "the panel shows level 1")
		if not _has_enabled("Upgrade"):
			_press("Clear")
			assert_true(Improve.piece_at(Session.game, hex).is_empty(), "Clear took it away again")
			continue
		var level_before := Session.game.state.level[Session.game.map.index_of(hex)]
		_press("Upgrade")
		assert_eq(Session.game.state.level[Session.game.map.index_of(hex)], level_before + 1, "Upgrade raised the level by one")
		assert_eq(_panel.shown_hex(), hex, "the panel still shows the hex")
		_press("Clear")
		assert_true(Improve.piece_at(Session.game, hex).is_empty(), "Clear took the piece away")
		assert_false((_panel.get_node("Body/ActionsBox/Actions") as VBoxContainer).get_children().is_empty(), "the build list is back")
		done = true
		break
	assert_true(done, "a wild hex could be built, upgraded and cleared")


func _has_enabled(prefix: String) -> bool:
	for button: Button in _panel.action_buttons():
		if not button.disabled and button.text.begins_with(prefix):
			return true
	return false


func _level_word_for(hex: Vector2i) -> String:
	var piece := Improve.piece_at(Session.game, hex)
	var family := str(piece["family"])
	if family == "settlements":
		return "hamlet"
	if family == "castles":
		return "watchtower"
	return "first stage"
