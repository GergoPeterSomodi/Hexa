## GUT tests for Studiolo control components: KitButton, Segmented, KitSwitch, KitSlider,
## KeyCap, and OptionRow (docs/architecture/ui-and-controls-spec.md sections 3.5, 9;
## docs/architecture/ui-style-and-feedback-spec.md sections 4.3, 4.7, 4.11, 5).
extends GutTest

const OPTION_ROW_SCENE := preload("res://shell/ui/option_row.tscn")

var _harness: UIHarness = null
var _root: Control = null


func before_each() -> void:
	Bindings.reset_defaults()
	_harness = UIHarness.new()
	_harness.mount(self)
	var theme := KitTheme.load_for(1.0)
	_root = VBoxContainer.new()
	_root.theme = theme
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_harness.viewport.add_child(_root)


func after_each() -> void:
	Bindings.reset_defaults()
	_root = null
	_harness = null


func test_kit_button_kinds_uppercase_and_minimum_heights() -> void:
	var sec := KitButton.new()
	sec.text = "Cancel"
	_root.add_child(sec)
	assert_eq(sec.theme_type_variation, &"")
	assert_eq(sec.text, "Cancel")
	assert_gte(sec.custom_minimum_size.y, float(Tokens.TARGET_MIN))

	var small := KitButton.new()
	small.kind = KitButton.Kind.SMALL
	small.text = "Tiny"
	_root.add_child(small)
	assert_eq(small.theme_type_variation, &"ButtonSmall")
	assert_gte(small.custom_minimum_size.y, float(Tokens.TARGET_MIN))

	var menu := KitButton.new()
	menu.kind = KitButton.Kind.MENU
	menu.text = "Options"
	_root.add_child(menu)
	assert_eq(menu.theme_type_variation, &"ButtonMenu")
	assert_eq(menu.text, "OPTIONS", "MENU upper-cases text")
	assert_gte(menu.custom_minimum_size.y, float(Tokens.BUTTON_MENU_H))

	var menu_prim := KitButton.new()
	menu_prim.text = "Resume"
	menu_prim.kind = KitButton.Kind.MENU_PRIMARY
	_root.add_child(menu_prim)
	assert_eq(menu_prim.theme_type_variation, &"ButtonMenuPrimary")
	assert_eq(menu_prim.text, "RESUME", "setting kind after text also upper-cases")

	var menu_danger := KitButton.new()
	menu_danger.kind = KitButton.Kind.MENU_DANGER
	menu_danger.text = "Quit"
	_root.add_child(menu_danger)
	assert_eq(menu_danger.theme_type_variation, &"ButtonMenuDanger")
	assert_eq(menu_danger.text, "QUIT")

	var tog := KitButton.new()
	tog.kind = KitButton.Kind.TOGGLE
	_root.add_child(tog)
	assert_eq(tog.theme_type_variation, &"ButtonToggle")
	assert_true(tog.toggle_mode)


func test_kit_button_verdict_icon_cost_and_hotkey_tooltip() -> void:
	var btn := KitButton.new()
	btn.kind = KitButton.Kind.PRIMARY
	btn.text = "Build Sawmill"
	btn.icon_name = &"tick"
	btn.cost_text = "40 ducats"
	btn.hotkey_action = &"view_grid"
	btn.tooltip_text = "Toggle grid"
	_root.add_child(btn)

	assert_eq(btn.text, "Build Sawmill", "cost_text does not mutate Button.text")
	var cost_lbl := btn.get_node_or_null("CostLabel") as Label
	assert_not_null(cost_lbl)
	assert_eq(cost_lbl.text, "40 ducats")
	assert_true(cost_lbl.visible)

	var tick_icon := btn.get_theme_icon(&"tick", &"Kit")
	var lock_icon := btn.get_theme_icon(&"lock", &"Kit")
	assert_eq(btn.icon, tick_icon, "icon_name sets Kit theme icon")
	assert_eq(btn.tooltip_text, "Toggle grid [G]")

	var res := Bindings.apply_overrides({"view_grid": "K"})
	assert_true(bool(res["ok"]))
	btn.refresh_hotkey()
	assert_eq(btn.tooltip_text, "Toggle grid [K]", "tooltip updates after rebind")

	btn.set_verdict({"ok": false, "reason": "No wood"})
	assert_true(btn.disabled)
	assert_eq(btn.icon, lock_icon, "refused verdict sets lock icon")
	assert_eq(btn.tooltip_text, "No wood")
	assert_eq(btn.reason_text(), "No wood")
	assert_eq(btn.accessibility_description, "No wood")

	btn.set_verdict({"ok": true})
	assert_false(btn.disabled)
	assert_eq(btn.icon, tick_icon, "ok verdict restores original icon_name icon")
	assert_eq(btn.reason_text(), "")
	assert_eq(btn.tooltip_text, "Toggle grid [K]")

	btn.set_verdict({"ok": false, "reason": "Blocked"})
	assert_true(btn.disabled)
	btn.set_verdict({})
	assert_false(btn.disabled, "missing ok defaults to true")

	# Custom icon (without icon_name) is saved and restored across verdict toggle
	var custom_tex := btn.get_theme_icon(&"tick", &"Kit")
	var custom_btn := KitButton.new()
	custom_btn.icon = custom_tex
	_root.add_child(custom_btn)
	custom_btn.set_verdict({"ok": false, "reason": "Locked"})
	assert_eq(custom_btn.icon, lock_icon)
	custom_btn.set_verdict({"ok": true})
	assert_eq(custom_btn.icon, custom_tex, "custom icon restored on ok verdict")


func test_kit_button_lazy_glow_creation_and_motion() -> void:
	var sec := KitButton.new()
	sec.kind = KitButton.Kind.SECONDARY
	sec.text = "Plain"
	sec.reduce_motion = true
	_root.add_child(sec)
	assert_null(sec.get_node_or_null("Glow"))
	sec.mouse_entered.emit()
	sec.grab_focus()
	assert_null(sec.get_node_or_null("Glow"), "SECONDARY never creates Glow")

	for glow_kind: KitButton.Kind in [
		KitButton.Kind.PRIMARY,
		KitButton.Kind.MENU,
		KitButton.Kind.MEDALLION,
	]:
		var btn := KitButton.new()
		btn.kind = glow_kind
		btn.text = "Action"
		btn.reduce_motion = true
		_root.add_child(btn)
		assert_null(btn.get_node_or_null("Glow"), "Glow is null before hover or focus")

		btn.mouse_entered.emit()
		var glow := btn.get_node_or_null("Glow") as NinePatchRect
		assert_not_null(glow, "Glow created lazily on hover")
		assert_eq(glow.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(glow.patch_margin_left, 24)
		assert_eq(glow.texture, btn.get_theme_icon(&"glow_soft", &"Kit"))
		assert_almost_eq(glow.modulate.a, 1.0, 0.001)

		btn.mouse_exited.emit()
		assert_almost_eq(glow.modulate.a, 0.0, 0.001)

		btn.grab_focus()
		assert_almost_eq(glow.modulate.a, 1.0, 0.001)
		btn.release_focus()
		assert_almost_eq(glow.modulate.a, 0.0, 0.001)


func test_segmented_options_selection_click_and_hud_mode() -> void:
	var seg := Segmented.new()
	_root.add_child(seg)
	assert_eq(seg.theme_type_variation, &"PanelSlot")

	var emitted: Array[Variant] = []
	seg.changed.connect(func(id: Variant) -> void: emitted.append(id))

	seg.set_options([
		{"id": &"full", "label": "Full", "tooltip": "Full report"},
		{"id": &"brief", "label": "Brief"},
		{"id": &"off", "label": "Off"},
	])
	assert_null(seg.selected_id())

	var btn_full := seg.button_for(&"full")
	var btn_brief := seg.button_for(&"brief")
	var btn_off := seg.button_for(&"off")
	assert_not_null(btn_full)
	assert_eq(btn_full.theme_type_variation, &"ButtonTab")
	assert_true(btn_full.toggle_mode)
	assert_gte(btn_full.custom_minimum_size.y, float(Tokens.TARGET_MIN))
	assert_eq(btn_full.focus_mode, Control.FOCUS_ALL)

	seg.select(&"full", false)
	assert_eq(seg.selected_id(), &"full")
	assert_eq(emitted.size(), 0, "select(emit=false) does not emit changed")

	seg.select(&"brief", true)
	assert_eq(seg.selected_id(), &"brief")
	assert_eq(emitted, [&"brief"])

	await _harness.wait_frames(self, 2)
	var click_pos := btn_off.get_global_rect().get_center()
	_harness.send_click(click_pos)
	await _harness.wait_frames(self, 2)
	assert_eq(seg.selected_id(), &"off")
	assert_eq(emitted, [&"brief", &"off"])

	seg.hud_mode = true
	assert_eq(btn_full.focus_mode, Control.FOCUS_NONE)


func test_kit_switch_and_kit_slider() -> void:
	var sw := KitSwitch.new()
	sw.text = "Hex grid"
	_root.add_child(sw)
	assert_eq(sw.theme_type_variation, &"KitSwitch")
	assert_gte(sw.custom_minimum_size.y, float(Tokens.TARGET_MIN))
	assert_eq(sw.accessibility_name, "Hex grid")
	sw.button_pressed = true
	assert_true(sw.button_pressed)

	var sl := KitSlider.new()
	sl.suffix = "%"
	sl.set_bounds(10.0, 100.0, 5.0)
	sl.set_slider_value(50.0, false)
	_root.add_child(sl)

	assert_eq(sl.value_label().theme_type_variation, &"Number")
	assert_eq(sl.value_label().text, "50%")
	assert_gte(sl.slider().custom_minimum_size.y, float(Tokens.TARGET_MIN))

	var changes: Array[float] = []
	var commits: Array[float] = []
	sl.value_changed.connect(func(v: float) -> void: changes.append(v))
	sl.value_committed.connect(func(v: float) -> void: commits.append(v))

	sl.set_slider_value(65.0, false)
	assert_eq(sl.value_label().text, "65%")
	assert_eq(changes.size(), 0, "set_slider_value(emit=false) stays silent")

	sl.value = 80.0
	assert_eq(sl.value_label().text, "80%")
	assert_eq(changes, [80.0])

	sl.slider().drag_ended.emit(true)
	assert_eq(commits, [80.0])

	sl.format_int = false
	sl.suffix = ""
	sl.set_bounds(0.05, 0.80, 0.05)
	sl.set_slider_value(0.25, false)
	assert_eq(sl.value_label().text, "0.25")


func test_key_cap_tracks_bindings_and_waiting_state() -> void:
	var cap := KeyCap.new()
	cap.action = &"view_grid"
	_root.add_child(cap)

	assert_eq(cap.theme_type_variation, &"KeyCapPanel")
	assert_eq(cap.label().theme_type_variation, &"KeyCap")
	assert_eq(cap.label().text, "G")

	var res := Bindings.apply_overrides({"view_grid": "K"})
	assert_true(bool(res["ok"]))
	cap.refresh_from_input_map()
	assert_eq(cap.label().text, "K")

	cap.waiting = true
	assert_eq(cap.theme_type_variation, &"KeyCapPanelWait")
	assert_eq(cap.label().text, "...")

	cap.waiting = false
	assert_eq(cap.theme_type_variation, &"KeyCapPanel")
	assert_eq(cap.label().text, "K")

	Bindings.reset_defaults()
	cap.refresh_from_input_map()
	assert_eq(cap.label().text, "G")

	cap.action = &""
	assert_eq(cap.label().text, "—", "cleared action shows em-dash")

	cap.action = &"missing_unbound_action"
	assert_eq(cap.label().text, "—", "unknown/unbound action shows em-dash")

	cap.action = &""
	cap.key_text = "Shift"
	assert_eq(cap.label().text, "Shift", "manual key_text renders when unbound")


func test_option_row_binds_bool_choices_range_and_disabled_reason() -> void:
	var settings := Settings.new("macOS", false)
	var applied: Array[Array] = []

	var bool_row := OPTION_ROW_SCENE.instantiate() as OptionRow
	bool_row.value_applied.connect(func(k: String, v: Variant) -> void: applied.append([k, v]))
	_root.add_child(bool_row)
	bool_row.bind(settings, "map/grid", "macOS")
	var sw := bool_row.control() as KitSwitch
	assert_not_null(sw)
	assert_false(sw.button_pressed)
	sw.button_pressed = true
	assert_eq(settings.get_value("map/grid"), true)
	assert_eq(applied.back(), ["map/grid", true])

	var choice_row := OPTION_ROW_SCENE.instantiate() as OptionRow
	_root.add_child(choice_row)
	choice_row.bind(settings, "display/window_mode", "macOS")
	var opt := choice_row.control() as OptionButton
	assert_not_null(opt)
	assert_eq(opt.item_count, 2, "macOS excludes exclusive mode")
	opt.select(1)
	opt.item_selected.emit(1)
	assert_eq(settings.get_value("display/window_mode"), "fullscreen")

	# Re-binding to int choices & choices_override disconnects cleanly and maps int values
	choice_row.bind(settings, "display/fps_cap", "macOS", [0, 60])
	opt = choice_row.control() as OptionButton
	assert_not_null(opt)
	assert_eq(opt.item_count, 2)
	opt.select(1)
	opt.item_selected.emit(1)
	assert_eq(settings.get_value("display/fps_cap"), 60)

	var range_row := OPTION_ROW_SCENE.instantiate() as OptionRow
	_root.add_child(range_row)
	range_row.bind(settings, "map/grid_opacity", "macOS")
	var sl := range_row.control() as KitSlider
	assert_not_null(sl)
	assert_almost_eq(sl.value, 100.0, 0.001)
	sl.value = 45.0
	assert_eq(settings.get_value("map/grid_opacity"), 45)

	# Float range binding
	var float_row := OPTION_ROW_SCENE.instantiate() as OptionRow
	_root.add_child(float_row)
	float_row.bind(settings, "dev/far_zoom", "macOS")
	var float_sl := float_row.control() as KitSlider
	assert_not_null(float_sl)
	assert_false(float_sl.format_int)
	float_sl.value = 0.35
	assert_almost_eq(float(settings.get_value("dev/far_zoom")), 0.35, 0.001)

	# Reset page syncs UI controls back without feedback loops
	settings.reset_page("map")
	assert_false(sw.button_pressed)
	assert_almost_eq(sl.value, 100.0, 0.001)

	# Disabled reason disables control and displays Reason label
	var reason_lbl := choice_row.get_node("Reason") as Label
	assert_false(reason_lbl.visible)
	choice_row.set_disabled_reason(true, "Fullscreen active")
	assert_true(opt.disabled)
	assert_true(reason_lbl.visible)
	assert_eq(reason_lbl.text, "Fullscreen active")
	assert_eq(choice_row.tooltip_text, "Fullscreen active")

	choice_row.set_disabled_reason(false)
	assert_false(opt.disabled)
	assert_false(reason_lbl.visible)
	assert_eq(choice_row.tooltip_text, "")

	# choices_override turns a ranged key (e.g. display/screen) into an OptionButton
	var screen_row := OPTION_ROW_SCENE.instantiate() as OptionRow
	_root.add_child(screen_row)
	screen_row.bind(settings, "display/screen", "macOS", [0, 1])
	var screen_opt := screen_row.control() as OptionButton
	assert_not_null(screen_opt)
	assert_eq(screen_opt.item_count, 2)
	screen_opt.select(1)
	screen_opt.item_selected.emit(1)
	assert_eq(settings.get_value("display/screen"), 1)

	# _exit_tree disconnects Settings.changed; re-entering reconnects and resyncs
	assert_true(settings.changed.is_connected(screen_row._on_settings_changed))
	_root.remove_child(screen_row)
	assert_false(settings.changed.is_connected(screen_row._on_settings_changed))
	settings.set_value("display/screen", 0)
	_root.add_child(screen_row)
	assert_true(settings.changed.is_connected(screen_row._on_settings_changed))
	assert_eq(screen_opt.selected, 0)
