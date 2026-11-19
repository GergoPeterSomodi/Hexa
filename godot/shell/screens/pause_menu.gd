## Pause menu modal screen (docs/architecture/ui-and-controls-spec.md section 5.2;
## docs/architecture/ui-style-and-feedback-spec.md section 2).
class_name PauseMenu
extends Screen

@onready var _frame: ModalFrame = $Center/Frame

var _subtitle_label: Label = null
var _resume_btn: KitButton = null
var _save_btn: KitButton = null
var _load_btn: KitButton = null
var _options_btn: KitButton = null
var _help_btn: KitButton = null
var _main_menu_btn: KitButton = null
var _quit_btn: KitButton = null
var _ui_built: bool = false


func _ready() -> void:
	_ensure_ui()


func on_enter() -> void:
	_ensure_ui()
	_refresh_state()


func back() -> bool:
	return false


func frame() -> ModalFrame:
	_ensure_ui()
	return _frame


func subtitle_label() -> Label:
	_ensure_ui()
	return _subtitle_label


func resume_button() -> KitButton:
	_ensure_ui()
	return _resume_btn


func options_button() -> KitButton:
	_ensure_ui()
	return _options_btn


func help_button() -> KitButton:
	_ensure_ui()
	return _help_btn


func main_menu_button() -> KitButton:
	_ensure_ui()
	return _main_menu_btn


func quit_button() -> KitButton:
	_ensure_ui()
	return _quit_btn


func save_button() -> KitButton:
	_ensure_ui()
	return _save_btn


func load_button() -> KitButton:
	_ensure_ui()
	return _load_btn


func _ensure_ui() -> void:
	if _ui_built:
		return
	if _frame == null:
		_frame = get_node_or_null("Center/Frame") as ModalFrame
	if _frame == null:
		return
	_ui_built = true

	var body := _frame.body()

	_subtitle_label = Label.new()
	_subtitle_label.name = &"Subtitle"
	_subtitle_label.theme_type_variation = &"Hint"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_subtitle_label)

	_resume_btn = _make_menu_button(&"ResumeButton", "Resume", KitButton.Kind.MENU_PRIMARY)
	_resume_btn.pressed.connect(_on_resume_pressed)
	body.add_child(_resume_btn)

	_save_btn = _make_menu_button(&"SaveButton", "Save game", KitButton.Kind.MENU)
	_save_btn.visible = false
	_save_btn.pressed.connect(_on_save_pressed)
	body.add_child(_save_btn)

	_load_btn = _make_menu_button(&"LoadButton", "Load game", KitButton.Kind.MENU)
	_load_btn.visible = false
	_load_btn.pressed.connect(_on_load_pressed)
	body.add_child(_load_btn)

	_options_btn = _make_menu_button(&"OptionsButton", "Options", KitButton.Kind.MENU)
	_options_btn.pressed.connect(_on_options_pressed)
	body.add_child(_options_btn)

	_help_btn = _make_menu_button(&"HelpButton", "Help and keys", KitButton.Kind.MENU)
	_help_btn.pressed.connect(_on_help_pressed)
	body.add_child(_help_btn)

	_main_menu_btn = _make_menu_button(&"MainMenuButton", "Main menu", KitButton.Kind.MENU)
	_main_menu_btn.pressed.connect(_on_main_menu_pressed)
	body.add_child(_main_menu_btn)

	_quit_btn = _make_menu_button(&"QuitButton", "Quit to desktop", KitButton.Kind.MENU_DANGER)
	_quit_btn.pressed.connect(_on_quit_pressed)
	body.add_child(_quit_btn)

	body.add_child(_build_hint_row())
	default_focus = get_path_to(_resume_btn)


func _make_menu_button(node_name: StringName, label_text: String, btn_kind: KitButton.Kind) -> KitButton:
	var btn := KitButton.new()
	btn.name = node_name
	btn.kind = btn_kind
	btn.text = label_text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.reduce_motion = _reduce_motion()
	return btn


func _build_hint_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = &"HintRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pairs: Array[Array] = [
		[&"app_back", "back to the map"],
		[&"app_help", "keys"],
		[&"app_fullscreen", "window mode"],
	]
	for pair: Array in pairs:
		var cap := KeyCap.new()
		cap.action = pair[0] as StringName
		row.add_child(cap)
		var lbl := Label.new()
		lbl.theme_type_variation = &"Hint"
		lbl.text = str(pair[1])
		row.add_child(lbl)
	return row


## The long name of your country in a scenario game ("Republic of Genoa"), the scenario while none is chosen,
## else the sandbox line. M3 adds the date.
func _subtitle_text() -> String:
	var game := Session.game
	if game == null:
		return "Map sandbox"
	if game.has_countries():
		if game.player != &"":
			var card := CountryCard.of(game, game.player)
			if not card.is_empty():
				return str(card["long_name"])
		return game.scenario.name if game.scenario != null and not game.scenario.name.is_empty() else "Choosing a country"
	return "Map sandbox · seed %d" % game.seed_value


func _refresh_state() -> void:
	var reduce := _reduce_motion()
	for btn: KitButton in [_resume_btn, _save_btn, _load_btn, _options_btn, _help_btn, _main_menu_btn, _quit_btn]:
		if btn != null:
			btn.reduce_motion = reduce

	_subtitle_label.text = _subtitle_text()

	var has_saves := Session.has_method(&"save_game")
	_save_btn.visible = has_saves
	_load_btn.visible = has_saves
	if has_saves and Session.has_method(&"is_season_running") and bool(Session.call(&"is_season_running")):
		_save_btn.set_verdict({"ok": false, "reason": "Wait for the season to end"})
	else:
		_save_btn.set_verdict({"ok": true})


func _has_unsaved_actions() -> bool:
	if ctx != null and ctx.has_method(&"has_unsaved_actions"):
		return bool(ctx.call(&"has_unsaved_actions"))
	var unsaved: Variant = Session.get(&"unsaved_actions")
	if unsaved != null:
		return int(unsaved) > 0
	return false


func _push_screen(id: StringName) -> Screen:
	if ctx == null or ctx.stack == null or not ctx.stack.has_method(&"push"):
		return null
	var next := ScreenIds.make(id)
	if next != null:
		ctx.stack.call(&"push", next)
	return next


func _ask_confirm(title_text: String, body_text: String, confirm_label: String, what: StringName) -> void:
	var confirm := ScreenIds.make(&"confirm") as Confirm
	if confirm == null:
		_emit_app_request(what)
		return
	confirm.configure({
		"title": title_text,
		"body": body_text,
		"confirm_label": confirm_label,
		"cancel_label": "Stay",
		"danger": true,
		"on_result": func(accepted: bool) -> void:
			if accepted:
				_emit_app_request(what),
	})
	if ctx != null and ctx.stack != null and ctx.stack.has_method(&"push"):
		ctx.stack.call(&"push", confirm)
	else:
		confirm.queue_free()


func _emit_app_request(what: StringName, args: Dictionary = {}) -> void:
	if ctx != null:
		ctx.request(what, args)


func _reduce_motion() -> bool:
	if ctx != null and ctx.settings != null:
		return bool(ctx.settings.get_value("accessibility/reduce_motion"))
	return false


func _on_resume_pressed() -> void:
	finished.emit(&"resume")


func _on_save_pressed() -> void:
	_push_screen(&"save_load")


func _on_load_pressed() -> void:
	_push_screen(&"save_load")


func _on_options_pressed() -> void:
	_push_screen(&"options")


func _on_help_pressed() -> void:
	_push_screen(&"help")


func _on_main_menu_pressed() -> void:
	if _has_unsaved_actions():
		_ask_confirm(
			"Leave to main menu?",
			"Leave to the main menu? Unsaved changes are lost.",
			"Leave",
			&"main_menu"
		)
		return
	_emit_app_request(&"main_menu")


func _on_quit_pressed() -> void:
	if _has_unsaved_actions():
		_ask_confirm(
			"Quit to desktop?",
			"Quit to desktop? Unsaved changes are lost.",
			"Quit",
			&"quit"
		)
		return
	_emit_app_request(&"quit")
