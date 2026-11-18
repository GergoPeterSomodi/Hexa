## Studiolo options modal screen (860 x 580) with NavList pages, schema-driven OptionRows,
## staged display/window Apply + 10 s keep/revert Confirm, per-page Defaults, keybindings, and About
## (docs/architecture/ui-and-controls-spec.md sections 5.6, 6.2-6.7;
## docs/architecture/ui-style-and-feedback-spec.md sections 2, 4.11).
class_name Options
extends Screen

const OPTION_ROW_PATH := "res://shell/ui/option_row.tscn"
const DISPLAY_REVERT_TIMEOUT_S := 10.0
const NAV_WIDTH_PX := 184.0
const TARGET_MILESTONE := 1.5

const PAGES: Array[Dictionary] = [
	{"id": &"display", "text": "Display"},
	{"id": &"graphics", "text": "Graphics"},
	{"id": &"controls", "text": "Controls"},
	{"id": &"map", "text": "Map"},
	{"id": &"accessibility", "text": "Accessibility"},
	{"id": &"advanced", "text": "Advanced"},
	{"id": &"about", "text": "About"},
]

const DISPLAY_CONFIRM_KEYS: Array[String] = [
	"display/window_mode",
	"display/window_preset",
	"display/screen",
	"display/ui_scale",
]

@onready var _frame: ModalFrame = $Center/Frame

var _nav: NavList = null
var _page_host: Control = null
var _back_btn: KitButton = null
var _defaults_btn: KitButton = null
var _apply_btn: KitButton = null
var _footer_hint: Label = null

var _live_settings: Settings = null
var _owned_fallback_settings: Settings = null
var _staged_settings: Settings = null

var _pages: Dictionary[StringName, ScrollContainer] = {}
var _page_vboxes: Dictionary[StringName, VBoxContainer] = {}
var _page_rows: Dictionary[StringName, Array] = {}
var _rows: Dictionary[String, OptionRow] = {}
var _current_page: StringName = &"display"

var _keys_panel: OptionsKeys = OptionsKeys.new()
var _about_handles: Dictionary = {}
var _ui_built: bool = false


func _ready() -> void:
	_ensure_ui()
	_sync_from_live_settings()


func _exit_tree() -> void:
	_keys_panel.cancel_rebind()
	_disconnect_settings()


func on_enter() -> void:
	_ensure_ui()
	_sync_from_live_settings()
	_sync_motion_flags()
	_about_handles["context"] = ctx
	About.refresh_about_handles(_about_handles, _live_settings, get_window())
	_keys_panel.refresh_all()
	_sync_display_row_states()
	_sync_footer()


func on_exit() -> void:
	_keys_panel.cancel_rebind()
	_disconnect_settings()


func back() -> bool:
	if _keys_panel.capturing_action() != &"":
		_keys_panel.cancel_rebind()
		return true
	_reset_staging_to_live()
	return false


func _input(event: InputEvent) -> void:
	if _keys_panel.capturing_action() == &"" or not visible or not is_inside_tree():
		return
	if ctx != null and ctx.stack != null and ctx.stack.has_method(&"top"):
		if ctx.stack.call(&"top") != self:
			return
	var key_ev := event as InputEventKey
	if key_ev == null:
		return
	if _keys_panel.handle_key_event(key_ev):
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


func frame() -> ModalFrame:
	_ensure_ui()
	return _frame


func nav_list() -> NavList:
	_ensure_ui()
	return _nav


func back_button() -> KitButton:
	_ensure_ui()
	return _back_btn


func defaults_button() -> KitButton:
	_ensure_ui()
	return _defaults_btn


func apply_button() -> KitButton:
	_ensure_ui()
	return _apply_btn


func current_page() -> StringName:
	_ensure_ui()
	return _current_page


## Switches the active page via NavList and cross-fades the page host.
func select_page(page_id: StringName) -> void:
	_ensure_ui()
	if not _pages.has(page_id):
		return
	if _keys_panel.capturing_action() != &"" and page_id != &"controls":
		_keys_panel.cancel_rebind()
	var prev_id := _current_page
	_current_page = page_id
	_nav.select(page_id, false)
	if prev_id != page_id:
		var out_page := _pages.get(prev_id, null) as ScrollContainer
		var in_page := _pages.get(page_id, null) as ScrollContainer
		Motion.cross_fade(out_page, in_page, _reduce_motion())
	else:
		for pid: StringName in _pages:
			var page := _pages[pid]
			page.visible = (pid == page_id)
			if page.visible:
				page.modulate.a = 1.0
	if page_id == &"about":
		About.refresh_about_handles(_about_handles, _live_settings, get_window())
	_sync_footer()


## Returns every OptionRow across all Options pages.
func option_rows() -> Array[OptionRow]:
	_ensure_ui()
	var out: Array[OptionRow] = []
	for key: String in _rows:
		var row := _rows[key]
		if row != null:
			out.append(row)
	return out


## Returns the OptionRow bound to `key`, or null if absent.
func option_row(key: String) -> OptionRow:
	_ensure_ui()
	return _rows.get(key, null) as OptionRow


## Returns the OptionRows belonging to `page_id`.
func page_rows(page_id: StringName) -> Array[OptionRow]:
	_ensure_ui()
	var out: Array[OptionRow] = []
	var list: Array = _page_rows.get(page_id, [])
	for item: Variant in list:
		if item is OptionRow:
			out.append(item as OptionRow)
	return out


## Returns true when any staged display/window setting differs from the live Settings.
func has_pending_display_changes() -> bool:
	if _live_settings == null or _staged_settings == null:
		return false
	for key: String in DISPLAY_CONFIRM_KEYS:
		if _staged_settings.get_value(key) != _live_settings.get_value(key):
			return true
	return false


## Returns the currently staged value for a display/window confirm key (or live value otherwise).
func staged_value(key: String) -> Variant:
	_ensure_ui()
	if _staged_settings != null and key in DISPLAY_CONFIRM_KEYS:
		return _staged_settings.get_value(key)
	if _live_settings != null:
		return _live_settings.get_value(key)
	return null


## Commits staged display/window settings, applies via Display, and pushes the 10 s Confirm modal.
func apply_staged_display() -> Confirm:
	_ensure_ui()
	if not has_pending_display_changes():
		return null
	var snapshot: Dictionary = {}
	for key: String in DISPLAY_CONFIRM_KEYS:
		snapshot[key] = _live_settings.get_value(key)
	for key: String in DISPLAY_CONFIRM_KEYS:
		_live_settings.set_value(key, _staged_settings.get_value(key))

	Display.apply(get_window(), _live_settings)
	if ctx != null:
		ctx.request(&"apply_display", {"ui_scale": _live_settings.get_value("display/ui_scale")})
	_sync_display_row_states()
	_sync_footer()

	var confirm := Confirm.ask(
		"Keep these display settings?",
		["Display settings were applied. Keep them or revert to the previous settings?"],
		[
			{"id": &"keep", "label": "Keep", "kind": "primary", "safe": false},
			{"id": &"revert", "label": "Revert", "kind": "secondary", "safe": true},
		],
		{
			"timeout_s": DISPLAY_REVERT_TIMEOUT_S,
			"timeout_id": &"revert",
			"safe_choice": &"revert",
			"seal_letter": "!",
		}
	)
	if confirm == null:
		return null
	confirm.chose.connect(_on_display_confirm_chose.bind(snapshot))
	if ctx != null and ctx.stack != null and ctx.stack.has_method(&"push"):
		ctx.stack.call(&"push", confirm)
	else:
		confirm.queue_free()
		return null
	return confirm


## Restores schema defaults only for the active page (staged keys update staging on Display).
func reset_current_page_defaults() -> void:
	_ensure_ui()
	if _current_page == &"about" or _live_settings == null:
		return
	var page_name := String(_current_page)
	for key: String in Settings.SCHEMA.keys():
		var entry: Dictionary = Settings.SCHEMA[key]
		if str(entry.get("page", "")) != page_name:
			continue
		if float(str(entry.get("since", "1.5"))) > TARGET_MILESTONE:
			continue
		if str(entry.get("applies", "immediate")) == "confirm":
			_staged_settings.set_value(key, _staged_settings.get_default(key))
		elif key != "controls/device":
			_live_settings.set_value(key, _live_settings.get_default(key))
	if page_name == "controls" and Settings.SCHEMA.has("controls/device"):
		_live_settings.set_value("controls/device", _live_settings.get_default("controls/device"))
	_apply_immediate_page(page_name)
	_sync_display_row_states()
	_sync_footer()


func key_caps_for_action(action: StringName) -> Array[KeyCap]:
	_ensure_ui()
	return _keys_panel.key_caps_for(action)


func rebind_button_for(action: StringName) -> KitButton:
	_ensure_ui()
	return _keys_panel.rebind_button_for(action)


func reset_keys_button() -> KitButton:
	_ensure_ui()
	return _keys_panel.reset_button()


func keys_hint_label() -> Label:
	_ensure_ui()
	return _keys_panel.hint_label()


func capturing_action() -> StringName:
	return _keys_panel.capturing_action()


func begin_rebind(action: StringName) -> void:
	_ensure_ui()
	_keys_panel.begin_rebind(action)


func cancel_rebind() -> void:
	_keys_panel.cancel_rebind()


func reset_all_keys() -> void:
	_ensure_ui()
	_keys_panel.reset_all()


func about_copy_button() -> KitButton:
	_ensure_ui()
	return _about_handles.get("copy_btn", null) as KitButton


func _ensure_ui() -> void:
	if _ui_built:
		return
	if _frame == null:
		_frame = get_node_or_null("Center/Frame") as ModalFrame
	if _frame == null:
		return
	_ui_built = true
	_init_settings_refs()
	_build_header_back()
	_build_body_split()
	_build_pages()
	_build_footer()
	_setup_initial_focus()


func _init_settings_refs() -> void:
	if ctx != null and ctx.settings != null:
		_live_settings = ctx.settings
	else:
		_owned_fallback_settings = Settings.new()
		_live_settings = _owned_fallback_settings
	_staged_settings = Settings.new(_live_settings.platform, _live_settings.should_reduce_motion)
	_copy_confirm_to_staging()
	_connect_settings()


func _build_header_back() -> void:
	var head := _frame.panel().get_node_or_null("VBox/Head") as HBoxContainer
	if head == null:
		return
	var back_box := HBoxContainer.new()
	back_box.name = &"BackBox"
	back_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(back_box)

	_back_btn = KitButton.new()
	_back_btn.name = &"BackButton"
	_back_btn.kind = KitButton.Kind.SMALL
	_back_btn.text = "Back"
	_back_btn.hotkey_action = &"app_back"
	_back_btn.pressed.connect(_on_back_pressed)
	back_box.add_child(_back_btn)

	var esc_cap := KeyCap.new()
	esc_cap.name = &"BackKeyCap"
	esc_cap.action = &"app_back"
	esc_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_box.add_child(esc_cap)


func _build_body_split() -> void:
	var body := _frame.body()
	var split := HBoxContainer.new()
	split.name = &"Split"
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(split)

	_nav = NavList.new()
	_nav.name = &"PagesNav"
	_nav.ink = false
	_nav.custom_minimum_size = Vector2(NAV_WIDTH_PX, 0.0)
	_nav.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_nav.set_items(PAGES)
	_nav.selected.connect(_on_nav_selected)
	split.add_child(_nav)

	var vsep := VSeparator.new()
	vsep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	split.add_child(vsep)

	_page_host = Control.new()
	_page_host.name = &"PageHost"
	_page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_host.clip_contents = true
	_page_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	split.add_child(_page_host)


func _build_pages() -> void:
	for page_spec: Dictionary in PAGES:
		var page_id: StringName = page_spec["id"]
		var scroll := ScrollContainer.new()
		scroll.name = String(page_id).capitalize() + "Page"
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.visible = (page_id == _current_page)
		_page_host.add_child(scroll)

		var vbox := VBoxContainer.new()
		vbox.name = &"Rows"
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scroll.add_child(vbox)

		_pages[page_id] = scroll
		_page_vboxes[page_id] = vbox
		_page_rows[page_id] = []

	_populate_schema_rows()
	_populate_accessibility_note()
	var controls_vbox := _page_vboxes.get(&"controls", null) as VBoxContainer
	if controls_vbox != null:
		_keys_panel.build(controls_vbox, _live_settings)
	var about_vbox := _page_vboxes.get(&"about", null) as VBoxContainer
	if about_vbox != null:
		_about_handles = About.build_about_content(about_vbox, _live_settings, ctx, get_window())
	_nav.select(_current_page, false)


func _populate_schema_rows() -> void:
	var row_scene := ResourceLoader.load(OPTION_ROW_PATH) as PackedScene
	if row_scene == null:
		return
	for key: String in Settings.SCHEMA.keys():
		var entry: Dictionary = Settings.SCHEMA[key]
		var page_str := str(entry.get("page", ""))
		var since_val := float(str(entry.get("since", "1.5")))
		if page_str.is_empty() or since_val > TARGET_MILESTONE:
			continue
		var page_id := StringName(page_str)
		if not _page_vboxes.has(page_id):
			continue
		var row := row_scene.instantiate() as OptionRow
		row.name = key.replace("/", "_")
		var is_staged := str(entry.get("applies", "immediate")) == "confirm"
		var target_settings := _staged_settings if is_staged else _live_settings
		var choices_override := _choices_override_for(key, target_settings)
		_page_vboxes[page_id].add_child(row)
		row.bind(target_settings, key, _live_settings.platform, choices_override)
		_post_configure_row(key, row)
		row.value_applied.connect(_on_row_value_applied)
		_rows[key] = row
		(_page_rows[page_id] as Array).append(row)


func _choices_override_for(key: String, settings: Settings) -> Array:
	if key == "display/screen":
		var out: Array = [0]
		if DisplayServer.get_name() != "headless":
			var count := DisplayServer.get_screen_count()
			for i: int in range(1, count + 1):
				out.append(i)
		var cur := int(settings.get_value(key))
		if not out.has(cur):
			out.append(cur)
		return out
	if key == "display/window_preset":
		if DisplayServer.get_name() == "headless" or DisplayServer.get_screen_count() <= 0:
			return []
		var scr := clampi(DisplayServer.get_primary_screen(), 0, DisplayServer.get_screen_count() - 1)
		var usable := DisplayServer.screen_get_usable_rect(scr).size
		if usable.x <= 0 or usable.y <= 0:
			return []
		var presets := Display.presets_for(usable)
		var cur_str := str(settings.get_value(key))
		if not presets.has(cur_str):
			presets.append(cur_str)
		return presets
	return []


func _post_configure_row(key: String, row: OptionRow) -> void:
	if key != "display/screen":
		return
	var opt := row.control() as OptionButton
	if opt == null:
		return
	var is_headless := DisplayServer.get_name() == "headless"
	var screen_count := DisplayServer.get_screen_count() if not is_headless else 0
	for i: int in opt.item_count:
		if i == 0:
			opt.set_item_text(0, "System")
		elif not is_headless and i <= screen_count:
			var sz := DisplayServer.screen_get_size(i - 1)
			opt.set_item_text(i, "Screen %d (%d × %d)" % [i, sz.x, sz.y])
		else:
			opt.set_item_text(i, "Screen %d" % i)


func _populate_accessibility_note() -> void:
	var vbox := _page_vboxes.get(&"accessibility", null) as VBoxContainer
	if vbox == null:
		return
	var note := Label.new()
	note.name = &"UIScaleNote"
	note.theme_type_variation = &"Hint"
	note.text = "UI scale is configured on the Display page."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(note)


func _build_footer() -> void:
	var foot := _frame.footer()
	_footer_hint = Label.new()
	_footer_hint.name = &"FooterHint"
	_footer_hint.theme_type_variation = &"Hint"
	_footer_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(_footer_hint)

	_defaults_btn = KitButton.new()
	_defaults_btn.name = &"DefaultsButton"
	_defaults_btn.kind = KitButton.Kind.SECONDARY
	_defaults_btn.text = "Defaults for this page"
	_defaults_btn.pressed.connect(reset_current_page_defaults)
	foot.add_child(_defaults_btn)

	_apply_btn = KitButton.new()
	_apply_btn.name = &"ApplyButton"
	_apply_btn.kind = KitButton.Kind.PRIMARY
	_apply_btn.text = "Apply"
	_apply_btn.disabled = true
	_apply_btn.pressed.connect(apply_staged_display)
	foot.add_child(_apply_btn)


func _setup_initial_focus() -> void:
	var first_nav := _nav.button_for(_current_page)
	if first_nav != null and is_inside_tree():
		default_focus = get_path_to(first_nav)
	elif _back_btn != null and is_inside_tree():
		default_focus = get_path_to(_back_btn)


func _sync_from_live_settings() -> void:
	var target := ctx.settings if (ctx != null and ctx.settings != null) else _live_settings
	if target != null and target != _live_settings:
		_disconnect_settings()
		_live_settings = target
		_keys_panel.set_settings(_live_settings)
		for key: String in _rows:
			var entry: Dictionary = Settings.SCHEMA[key]
			if str(entry.get("applies", "immediate")) != "confirm":
				var row := _rows[key]
				row.bind(_live_settings, key, _live_settings.platform, _choices_override_for(key, _live_settings))
				_post_configure_row(key, row)
	_connect_settings()
	_reset_staging_to_live()


func _copy_confirm_to_staging() -> void:
	if _live_settings == null or _staged_settings == null:
		return
	for key: String in DISPLAY_CONFIRM_KEYS:
		_staged_settings.set_value(key, _live_settings.get_value(key))


func _reset_staging_to_live() -> void:
	_copy_confirm_to_staging()
	_sync_display_row_states()
	_sync_footer()


func _sync_display_row_states() -> void:
	var preset_row := _rows.get("display/window_preset", null) as OptionRow
	if preset_row != null and _staged_settings != null:
		var mode := str(_staged_settings.get_value("display/window_mode"))
		if mode != "windowed":
			preset_row.set_disabled_reason(true, "Available in Windowed mode")
		else:
			preset_row.set_disabled_reason(false, "")


func _sync_footer() -> void:
	if not _ui_built:
		return
	var pending := has_pending_display_changes()
	_apply_btn.disabled = not pending
	_defaults_btn.disabled = (_current_page == &"about")
	if pending:
		_footer_hint.text = "Staged display changes pending — click Apply to preview."
	else:
		_footer_hint.text = "Changes apply at once, except display/window settings."


func _sync_motion_flags() -> void:
	var reduce := _reduce_motion()
	for btn: KitButton in [_back_btn, _defaults_btn, _apply_btn]:
		if btn != null:
			btn.reduce_motion = reduce
	_keys_panel.set_reduce_motion(reduce)


func _apply_immediate_setting(key: String) -> void:
	if _live_settings == null:
		return
	match key:
		"display/fps_cap":
			Engine.max_fps = int(_live_settings.get_value("display/fps_cap"))
		"display/power_saving":
			OS.low_processor_usage_mode = bool(_live_settings.get_value("display/power_saving"))
		"accessibility/tooltip_delay":
			var delay := Display.tooltip_delay_seconds(str(_live_settings.get_value("accessibility/tooltip_delay")))
			ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", delay)
		"display/vsync":
			if DisplayServer.get_name() != "headless":
				match str(_live_settings.get_value("display/vsync")):
					"off":
						DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
					"adaptive":
						DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
					_:
						DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		"accessibility/reduce_motion":
			_sync_motion_flags()
		"dev/ui_kit":
			if ctx != null:
				ctx.request(&"apply_ui_kit", {"ui_kit": _live_settings.get_value("dev/ui_kit")})


func _apply_immediate_page(page_name: String) -> void:
	for key: String in Settings.SCHEMA.keys():
		var entry: Dictionary = Settings.SCHEMA[key]
		if str(entry.get("page", "")) == page_name and str(entry.get("applies", "immediate")) == "immediate":
			_apply_immediate_setting(key)


func _connect_settings() -> void:
	if _live_settings != null and not _live_settings.changed.is_connected(_on_live_settings_changed):
		_live_settings.changed.connect(_on_live_settings_changed)
	if _staged_settings != null and not _staged_settings.changed.is_connected(_on_staged_settings_changed):
		_staged_settings.changed.connect(_on_staged_settings_changed)


func _disconnect_settings() -> void:
	if _live_settings != null and _live_settings.changed.is_connected(_on_live_settings_changed):
		_live_settings.changed.disconnect(_on_live_settings_changed)
	if _staged_settings != null and _staged_settings.changed.is_connected(_on_staged_settings_changed):
		_staged_settings.changed.disconnect(_on_staged_settings_changed)


func _on_nav_selected(id: StringName) -> void:
	select_page(id)


func _on_back_pressed() -> void:
	if _keys_panel.capturing_action() != &"":
		_keys_panel.cancel_rebind()
		return
	_reset_staging_to_live()
	finished.emit(&"back")


func _on_row_value_applied(key: String, _value: Variant) -> void:
	if key in DISPLAY_CONFIRM_KEYS:
		_sync_display_row_states()
		_sync_footer()
	else:
		_apply_immediate_setting(key)


func _on_live_settings_changed(key: String, _value: Variant) -> void:
	if key.begins_with("keys/"):
		_keys_panel.refresh_all()
	elif not (key in DISPLAY_CONFIRM_KEYS):
		_apply_immediate_setting(key)


func _on_staged_settings_changed(_key: String, _value: Variant) -> void:
	_sync_display_row_states()
	_sync_footer()


func _on_display_confirm_chose(choice_id: StringName, snapshot: Dictionary) -> void:
	if choice_id == &"keep":
		_copy_confirm_to_staging()
		_sync_display_row_states()
		_sync_footer()
		return
	if _live_settings != null:
		for key: String in snapshot:
			_live_settings.set_value(str(key), snapshot[key])
		Display.apply(get_window(), _live_settings)
		if ctx != null:
			ctx.request(&"apply_display", {"ui_scale": _live_settings.get_value("display/ui_scale")})
	_reset_staging_to_live()


func _reduce_motion() -> bool:
	if _live_settings != null:
		return bool(_live_settings.get_value("accessibility/reduce_motion"))
	return false
