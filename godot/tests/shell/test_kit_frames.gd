## GUT tests for Studiolo frame, sheet, card, and toast kit components:
## Ribbon, Cartouche, NavList, PanelFrame, ModalFrame, VellumSheet, HoverCard, and ToastHost
## (docs/architecture/ui-and-controls-spec.md sections 3.5, 9;
## docs/architecture/ui-style-and-feedback-spec.md sections 4.3, 4.7, 4.11, 5).
extends GutTest

const PANEL_FRAME_SCENE := preload("res://shell/ui/panel_frame.tscn")
const MODAL_FRAME_SCENE := preload("res://shell/ui/modal_frame.tscn")
const VELLUM_SHEET_SCENE := preload("res://shell/ui/vellum_sheet.tscn")
const HOVER_CARD_SCENE := preload("res://shell/ui/hover_card.tscn")
const TOAST_HOST_SCENE := preload("res://shell/ui/toast_host.tscn")
const MAP_PATH := "res://data/maps/north_italy.tres"

var _harness: UIHarness = null
var _root: Control = null


func before_each() -> void:
	Bindings.reset_defaults()
	_harness = UIHarness.new()
	_harness.mount(self)
	var theme := KitTheme.load_for(1.0)
	_root = Control.new()
	_root.theme = theme
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_harness.viewport.add_child(_root)


func after_each() -> void:
	Bindings.reset_defaults()
	_root = null
	_harness = null


func test_ribbon_uppercases_and_wraps() -> void:
	var ribbon := Ribbon.new()
	ribbon.text = "Spring Season Report of the Duchy of Milan"
	_root.add_child(ribbon)

	assert_eq(ribbon.theme_type_variation, &"PanelRibbon")
	assert_eq(ribbon.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_gte(ribbon.custom_minimum_size.x, Ribbon.MIN_WIDTH)
	assert_eq(ribbon.label().theme_type_variation, &"TitleRibbon")
	assert_eq(ribbon.label().text, "SPRING SEASON REPORT OF THE DUCHY OF MILAN")
	assert_eq(ribbon.label().autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(ribbon.label().max_lines_visible, 2)

	ribbon.size = Vector2(240.0, 40.0)
	await _harness.wait_frames(self, 2)
	assert_gt(ribbon.label().get_line_count(), 1, "long ribbon title wraps onto a second line")


func test_cartouche_uppercases_and_preserves_full_tooltip() -> void:
	var cart := Cartouche.new()
	cart.text = "San Giovanni in Persiceto"
	_root.add_child(cart)

	assert_eq(cart.theme_type_variation, &"PanelCartouche")
	assert_eq(cart.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(cart.label().theme_type_variation, &"TitlePanel")
	assert_eq(cart.label().text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)
	assert_eq(cart.label().max_lines_visible, 1)
	assert_eq(cart.label().text, "SAN GIOVANNI IN PERSICETO")
	assert_eq(cart.tooltip_text, "San Giovanni in Persiceto")


func test_nav_list_items_selection_counts_ink_and_keyboard_navigation() -> void:
	var nav := NavList.new()
	_root.add_child(nav)

	var events: Array[StringName] = []
	nav.selected.connect(func(id: StringName) -> void: events.append(id))

	nav.set_items([
		{"id": &"display", "text": "Display", "count": 4},
		{"id": &"controls", "text": "Controls"},
		{"id": &"about", "text": "About", "count": 0},
	])
	assert_eq(nav.selected_id(), &"")

	var btn_disp := nav.button_for(&"display")
	var btn_ctrl := nav.button_for(&"controls")
	var btn_about := nav.button_for(&"about")
	assert_not_null(btn_disp)
	assert_eq(btn_disp.theme_type_variation, &"ButtonNav")
	assert_true(btn_disp.toggle_mode)

	var disp_count := btn_disp.get_node("Count") as Label
	var ctrl_count := btn_ctrl.get_node("Count") as Label
	assert_true(disp_count.visible)
	assert_eq(disp_count.text, "4")
	assert_eq(disp_count.theme_type_variation, &"Hint")
	assert_false(ctrl_count.visible)

	nav.select(&"display", false)
	assert_eq(nav.selected_id(), &"display")
	assert_eq(events.size(), 0, "select(emit=false) does not emit")

	nav.set_count(&"controls", 7)
	assert_true(ctrl_count.visible)
	assert_eq(ctrl_count.text, "7")

	nav.ink = true
	assert_eq(btn_disp.theme_type_variation, &"ButtonNavInk")
	assert_eq(disp_count.theme_type_variation, &"LabelInkMuted")

	await _harness.wait_frames(self, 2)
	btn_disp.grab_focus()
	assert_true(btn_disp.has_focus())

	_harness.send_key(KEY_DOWN)
	await _harness.wait_frames(self, 2)
	assert_eq(nav.selected_id(), &"controls")
	assert_true(btn_ctrl.has_focus())
	assert_eq(events, [&"controls"])

	_harness.send_key(KEY_END)
	await _harness.wait_frames(self, 2)
	assert_eq(nav.selected_id(), &"about")
	assert_true(btn_about.has_focus())
	assert_eq(events, [&"controls", &"about"])

	_harness.send_key(KEY_UP)
	await _harness.wait_frames(self, 2)
	assert_eq(nav.selected_id(), &"controls")
	assert_true(btn_ctrl.has_focus())

	_harness.send_key(KEY_HOME)
	await _harness.wait_frames(self, 2)
	assert_eq(nav.selected_id(), &"display")
	assert_true(btn_disp.has_focus())


func test_panel_frame_header_body_footer_and_close_signal() -> void:
	var frame := PANEL_FRAME_SCENE.instantiate() as PanelFrame
	frame.cartouche_title = "Genoa"
	frame.subtitle = "(3, 12) · Land · port"
	frame.custom_minimum_size = Vector2(float(Tokens.PANEL_W), 320.0)
	_root.add_child(frame)

	assert_eq(frame.cartouche().text, "Genoa")
	assert_true(frame.cartouche().visible)
	assert_false(frame.footer().visible, "empty footer stays hidden")

	var body_lbl := Label.new()
	body_lbl.text = "Harbour level 2"
	frame.body().add_child(body_lbl)
	assert_eq(frame.body().get_child_count(), 1)

	var foot_btn := KitButton.new()
	foot_btn.text = "Build"
	frame.footer().add_child(foot_btn)
	assert_true(frame.footer().visible, "footer appears once populated")

	var closed_count := [0]
	frame.closed.connect(func() -> void: closed_count[0] += 1)

	await _harness.wait_frames(self, 2)
	_harness.send_click(frame.close_button().get_global_rect().get_center())
	await _harness.wait_frames(self, 2)
	assert_eq(closed_count[0], 1, "close button emits closed")

	frame.show_close = false
	assert_false(frame.close_button().visible)


func test_modal_frame_ribbon_body_footer_and_close_signal() -> void:
	var modal := MODAL_FRAME_SCENE.instantiate() as ModalFrame
	modal.ribbon_title = "Paused"
	modal.custom_minimum_size = Vector2(400.0, 280.0)
	_root.add_child(modal)

	assert_eq(modal.panel().theme_type_variation, &"PanelModal")
	assert_eq(modal.ribbon().label().text, "PAUSED")
	assert_true(modal.ribbon().visible)
	assert_lt(modal.ribbon().position.y, 0.0, "ribbon overhangs top edge of modal")

	var msg := Label.new()
	msg.text = "Sandbox game paused"
	modal.body().add_child(msg)

	var resume_btn := KitButton.new()
	resume_btn.kind = KitButton.Kind.PRIMARY
	resume_btn.text = "Resume"
	modal.footer().add_child(resume_btn)
	assert_true(modal.footer().visible)

	var closed_count := [0]
	modal.closed.connect(func() -> void: closed_count[0] += 1)

	await _harness.wait_frames(self, 2)
	assert_gt(modal.close_button().position.x, modal.size.x * 0.5, "close button stays right-aligned when ribbon replaces title")
	_harness.send_click(modal.close_button().get_global_rect().get_center())
	await _harness.wait_frames(self, 2)
	assert_eq(closed_count[0], 1, "modal close button emits closed")


func test_vellum_sheet_sections_scroll_and_keyboard_scrolling() -> void:
	var sheet := VELLUM_SHEET_SCENE.instantiate() as VellumSheet
	sheet.title = "Spring 1480"
	sheet.lede = "My Prince, the treasuries and estates report as follows."
	sheet.seal_letter = "m"
	sheet.size = Vector2(860.0, 420.0)
	_root.add_child(sheet)

	assert_eq(sheet.theme_type_variation, &"PanelVellum")
	assert_eq(sheet.ribbon().label().text, "SPRING 1480")
	assert_eq(sheet.seal_text(), "M")
	assert_eq(sheet.nav().ink, true)
	assert_eq(sheet.body_scroll().focus_mode, Control.FOCUS_ALL)

	var shown: Array[StringName] = []
	sheet.section_shown.connect(func(id: StringName) -> void: shown.append(id))

	var sec_a := sheet.add_section(&"glance", "At a glance")
	var sec_b := sheet.add_section(&"treasury", "Treasury")
	var sec_c := sheet.add_section(&"works", "Works")
	sheet.set_count(&"treasury", 6)

	for i: int in 18:
		for pair: Array in [[sec_a, "Glance"], [sec_b, "Treasury"], [sec_c, "Works"]]:
			var lbl := Label.new()
			lbl.theme_type_variation = &"LabelInk"
			lbl.text = "%s line %d" % [str(pair[1]), i]
			(pair[0] as VBoxContainer).add_child(lbl)

	var ok_btn := KitButton.new()
	ok_btn.kind = KitButton.Kind.MENU_PRIMARY
	ok_btn.text = "Begin Summer"
	sheet.footer().add_child(ok_btn)
	assert_true(sheet.footer().visible)

	await _harness.wait_frames(self, 2)
	sheet.scroll_to(&"works")
	assert_gt(sheet.body_scroll().scroll_vertical, 0, "scroll_to moves scroll_vertical to works section")
	assert_eq(sheet.nav().selected_id(), &"works")
	assert_eq(shown, [&"works"])

	sheet.body_scroll().grab_focus()
	assert_true(sheet.body_scroll().has_focus())

	_harness.send_key(KEY_HOME)
	await _harness.wait_frames(self, 2)
	assert_eq(sheet.body_scroll().scroll_vertical, 0, "Home scrolls to top")

	_harness.send_key(KEY_DOWN)
	await _harness.wait_frames(self, 2)
	assert_gt(sheet.body_scroll().scroll_vertical, 0, "Down scrolls down")
	var after_down := sheet.body_scroll().scroll_vertical

	_harness.send_key(KEY_PAGEDOWN)
	await _harness.wait_frames(self, 2)
	assert_gt(sheet.body_scroll().scroll_vertical, after_down, "PageDown scrolls further down")

	_harness.send_key(KEY_END)
	await _harness.wait_frames(self, 2)
	var at_end := sheet.body_scroll().scroll_vertical
	assert_gt(at_end, 0, "End scrolls to bottom")

	_harness.send_key(KEY_PAGEUP)
	await _harness.wait_frames(self, 2)
	assert_lt(sheet.body_scroll().scroll_vertical, at_end, "PageUp scrolls up")

	_harness.send_key(KEY_UP)
	await _harness.wait_frames(self, 2)
	assert_lt(sheet.body_scroll().scroll_vertical, at_end, "Up scrolls up")

	sheet.show_nav = false
	assert_false(sheet.nav().visible)
	sheet.show_nav = true
	assert_true(sheet.nav().visible)


func test_vellum_sheet_seal_tones_press_and_countdown() -> void:
	var sheet := VELLUM_SHEET_SCENE.instantiate() as VellumSheet
	sheet.title = "Confirm"
	sheet.seal_letter = "m"
	_root.add_child(sheet)

	var seal_icon := sheet.seal_node().get_node("SealIcon") as TextureRect
	assert_not_null(seal_icon.texture)
	assert_eq(seal_icon.self_modulate, Color.WHITE, "vermilion uses unmodulated seal")

	# Slice 3 bakes a seal for each tone: it is shown as it is, unmodulated.
	for tone: StringName in [&"good", &"plain", &"cracked"]:
		sheet.seal_tone = tone
		var baked := StringName("seal_" + String(tone))
		assert_true(sheet.has_theme_icon(baked, &"Kit"), "the Kit has %s" % baked)
		assert_eq(seal_icon.texture, sheet.get_theme_icon(baked, &"Kit"), "%s uses its baked seal" % tone)
		assert_eq(seal_icon.self_modulate, Color.WHITE, "%s is not tinted" % tone)

	assert_null(sheet.press_seal(true), "press_seal reduce_motion=true returns null")
	assert_eq(sheet.seal_node().scale, Vector2.ONE)
	assert_almost_eq(sheet.seal_node().modulate.a, 1.0, 0.001)

	var tween := sheet.press_seal(false)
	assert_not_null(tween, "press_seal reduce_motion=false returns Tween")
	tween.pause()
	tween.custom_step(0.25)
	assert_almost_eq(sheet.seal_node().scale.x, 1.0, 0.001)
	assert_almost_eq(sheet.seal_node().modulate.a, 1.0, 0.001)
	tween.kill()

	sheet.set_seal_text("10")
	assert_eq(sheet.seal_text(), "10")
	sheet.set_seal_text("")
	assert_eq(sheet.seal_text(), "M")


func test_hover_card_renders_hex_card_and_custom_tones_and_hides_when_empty() -> void:
	var card := HOVER_CARD_SCENE.instantiate() as HoverCard
	_root.add_child(card)
	assert_eq(card.theme_type_variation, &"PanelCard")
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_IGNORE)

	var map := load(MAP_PATH) as MapData
	var game := Game.new_game(map, 1480)
	var hex_model := HexCard.of(game, Vector2i(3, 4))
	card.show_card(hex_model)
	assert_true(card.visible)
	assert_eq(card.rows_container().get_child_count(), (hex_model["lines"] as Array).size())

	card.show_card({
		"title": "Vineyard",
		"subtitle": "",
		"lines": [
			["Output", &"good", "+12"],
			["Upkeep", &"bad", "−3"],
			["Winter", &"warn", "Frost"],
			["", &"rule", ""],
			["Note", &"muted", "Calm"],
			["Owner", &"plain", "Milan"],
		],
	})
	assert_true(card.visible)
	var rows := card.rows_container()
	assert_eq(rows.get_child_count(), 6)
	assert_eq((rows.get_child(0).get_node("Amount") as Label).theme_type_variation, &"NumberGood")
	assert_eq((rows.get_child(1).get_node("Amount") as Label).theme_type_variation, &"NumberBad")
	assert_eq((rows.get_child(2).get_node("Amount") as Label).theme_type_variation, &"NumberWarn")
	assert_true(rows.get_child(3) is HSeparator)
	assert_eq((rows.get_child(4).get_node("Amount") as Label).theme_type_variation, &"Hint")
	assert_eq((rows.get_child(5).get_node("Amount") as Label).theme_type_variation, &"Label")

	card.show_card({})
	assert_false(card.visible)
	assert_eq(rows.get_child_count(), 0)


func test_toast_host_caps_expires_key_cap_drop_and_mouse_filter() -> void:
	var host := TOAST_HOST_SCENE.instantiate() as ToastHost
	host.ttl_sec = 0.08
	_root.add_child(host)
	assert_eq(host.mouse_filter, Control.MOUSE_FILTER_IGNORE)

	host.toast("First", &"plain", &"", &"info")
	host.toast("Second", &"good", &"view_grid", &"work")
	host.toast("Third", &"warn", &"", &"alert")
	host.toast("Fourth", &"bad", &"", &"work")

	assert_eq(host.active_count(), 3, "caps visible toasts at 3")
	assert_eq(host.messages(), ["Second", "Third", "Fourth"], "oldest toast evicted")

	var second_toast := host.get_child(0) as PanelContainer
	assert_eq(second_toast.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var cap := second_toast.get_node("HBox/KeyCap") as KeyCap
	assert_true(cap.visible, "key_action shows KeyCap")
	assert_eq(cap.label().text, "G")

	var third_toast := host.get_child(1) as PanelContainer
	var third_cap := third_toast.get_node("HBox/KeyCap") as KeyCap
	assert_false(third_cap.visible, "empty key_action hides KeyCap")

	host.drop([&"work"])
	assert_eq(host.active_count(), 1)
	assert_eq(host.messages(), ["Third"])

	await _harness.wait_frames(self, 1)
	host._process(0.10)
	await _harness.wait_frames(self, 1)
	assert_eq(host.active_count(), 0, "toast expires after ttl_sec")
	assert_eq(host.messages(), [])
