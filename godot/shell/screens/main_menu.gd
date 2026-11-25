## Opaque Studiolo main menu screen with lazy-loaded map backdrop, drift & wind-rose motion,
## wordmark, developer-gated Map sandbox entry, Options, Credits, and direct Quit
## (docs/architecture/ui-and-controls-spec.md section 5.1;
## docs/architecture/ui-style-and-feedback-spec.md section 2, 4.10, 4.11).
class_name MainMenu
extends Screen

const MENU_BG_PATH := "res://assets/ui/menu/menu_bg.png"
const MENU_SHADE_PATH := "res://assets/ui/menu/menu_shade.png"
const COLUMN_HALF_W := 168.0

@onready var _bg_rect: TextureRect = $MenuBg
@onready var _shade_rect: TextureRect = $MenuShade
@onready var _rose_rect: TextureRect = $Rose
@onready var _menu_column: VBoxContainer = $MenuColumn
@onready var _wordmark_rect: TextureRect = $MenuColumn/Wordmark
@onready var _rule_rect: TextureRect = $MenuColumn/Rule
@onready var _continue_btn: KitButton = $MenuColumn/Sheet/Buttons/ContinueButton
@onready var _continue_hint: Label = $MenuColumn/Sheet/Buttons/ContinueHint
@onready var _new_game_btn: KitButton = $MenuColumn/Sheet/Buttons/NewGameButton
@onready var _load_btn: KitButton = $MenuColumn/Sheet/Buttons/LoadButton
@onready var _sandbox_btn: KitButton = $MenuColumn/Sheet/Buttons/SandboxButton
@onready var _options_btn: KitButton = $MenuColumn/Sheet/Buttons/OptionsButton
@onready var _credits_btn: KitButton = $MenuColumn/Sheet/Buttons/CreditsButton
@onready var _quit_btn: KitButton = $MenuColumn/Sheet/Buttons/QuitButton
@onready var _dev_note: Label = $DevNote
@onready var _version_label: Label = $VersionLabel

var _drift_tween: Tween = null
var _rose_tween: Tween = null
var _connected_settings: Settings = null
var _ui_ready: bool = false
var _art_pending: Array[String] = []


func _ready() -> void:
	_ui_ready = true
	_menu_column.offset_left = float(Tokens.MENU_COLUMN_X) - COLUMN_HALF_W
	_menu_column.offset_right = float(Tokens.MENU_COLUMN_X) + COLUMN_HALF_W
	_continue_btn.pressed.connect(_on_continue_pressed)
	_new_game_btn.pressed.connect(_on_new_game_pressed)
	_load_btn.pressed.connect(_on_load_pressed)
	_sandbox_btn.pressed.connect(_on_sandbox_pressed)
	_options_btn.pressed.connect(_on_options_pressed)
	_credits_btn.pressed.connect(_on_credits_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)
	_bg_rect.resized.connect(_sync_pivots)
	_rose_rect.resized.connect(_sync_pivots)
	_version_label.text = _format_version()
	_refresh_kit_art()
	_sync_dev_visibility()
	_refresh_saves()


func _exit_tree() -> void:
	_release_menu_art()
	_disconnect_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and _ui_ready:
		_refresh_kit_art()


func on_enter() -> void:
	_load_menu_art()
	_refresh_kit_art()
	_connect_settings()
	_sync_dev_visibility()
	_refresh_saves()
	_start_motion()


func on_exit() -> void:
	_release_menu_art()
	_disconnect_settings()


## Esc does nothing on the main menu (no accidental quit).
func back() -> bool:
	return true


func new_game_button() -> KitButton:
	return _new_game_btn


func sandbox_button() -> KitButton:
	return _sandbox_btn


func options_button() -> KitButton:
	return _options_btn


func credits_button() -> KitButton:
	return _credits_btn


func quit_button() -> KitButton:
	return _quit_btn


func continue_button() -> KitButton:
	return _continue_btn


func continue_hint() -> Label:
	return _continue_hint


func load_button() -> KitButton:
	return _load_btn


func background_rect() -> TextureRect:
	if _bg_rect == null:
		_bg_rect = get_node_or_null("MenuBg") as TextureRect
	return _bg_rect


func shade_rect() -> TextureRect:
	if _shade_rect == null:
		_shade_rect = get_node_or_null("MenuShade") as TextureRect
	return _shade_rect


## The backdrop pictures load on a thread (the bigger one costs about 25 ms to decode) and are laid on the menu when they are
## ready, a frame or a few after it opens; the other screens are warmed meanwhile.
func _load_menu_art() -> void:
	ScreenIds.warm()
	if _bg_rect.texture != null and _shade_rect.texture != null:
		return
	_art_pending.clear()
	for path: String in [MENU_BG_PATH, MENU_SHADE_PATH]:
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path) == OK:
			_art_pending.append(path)
	set_process(not _art_pending.is_empty())


func _process(_delta: float) -> void:
	for path: String in _art_pending.duplicate():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_art_pending.erase(path)
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			continue
		var tex := ResourceLoader.load_threaded_get(path) as Texture2D
		if path == MENU_BG_PATH:
			_bg_rect.texture = tex
			var instant := _reduce_motion() or SimClock.fixed()
			_bg_rect.modulate.a = 1.0 if instant else 0.0
			if not instant:
				create_tween().tween_property(_bg_rect, "modulate:a", 1.0, 0.2)
		else:
			_shade_rect.texture = tex
	if _art_pending.is_empty():
		set_process(false)


func _release_menu_art() -> void:
	for path: String in _art_pending:
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(path)
	_art_pending.clear()
	set_process(false)
	_stop_motion()
	if _bg_rect != null:
		_bg_rect.texture = null
		_bg_rect.scale = Vector2.ONE
	if _shade_rect != null:
		_shade_rect.texture = null


func _refresh_kit_art() -> void:
	_wordmark_rect.texture = get_theme_icon(&"wordmark", &"Kit") if has_theme_icon(&"wordmark", &"Kit") else null
	_rule_rect.texture = get_theme_icon(&"rule_diamond", &"Kit") if has_theme_icon(&"rule_diamond", &"Kit") else null
	_rose_rect.texture = get_theme_icon(&"rose", &"Kit") if has_theme_icon(&"rose", &"Kit") else null


func _start_motion() -> void:
	_stop_motion()
	var reduce := _reduce_motion()
	for btn: KitButton in [_new_game_btn, _sandbox_btn, _options_btn, _credits_btn, _quit_btn]:
		btn.reduce_motion = reduce
	_sync_pivots()
	if _bg_rect != null:
		_bg_rect.scale = Vector2.ONE
	_rose_tween = Motion.wiggle_rose(_rose_rect, reduce)


func _stop_motion() -> void:
	if _drift_tween != null and _drift_tween.is_valid():
		_drift_tween.kill()
	_drift_tween = null
	if _rose_tween != null and _rose_tween.is_valid():
		_rose_tween.kill()
	_rose_tween = null


func _sync_pivots() -> void:
	if _bg_rect != null:
		_bg_rect.pivot_offset = _bg_rect.size * 0.5
	if _rose_rect != null:
		_rose_rect.pivot_offset = _rose_rect.size * 0.5


func _connect_settings() -> void:
	if ctx == null or ctx.settings == null:
		return
	if _connected_settings == ctx.settings:
		return
	_disconnect_settings()
	_connected_settings = ctx.settings
	_connected_settings.changed.connect(_on_setting_changed)


func _disconnect_settings() -> void:
	if _connected_settings != null and _connected_settings.changed.is_connected(_on_setting_changed):
		_connected_settings.changed.disconnect(_on_setting_changed)
	_connected_settings = null


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "dev/developer_tools":
		_sync_dev_visibility()
	elif key == "accessibility/reduce_motion":
		_start_motion()


func _sync_dev_visibility() -> void:
	var dev_on := true
	if ctx != null and ctx.settings != null:
		dev_on = bool(ctx.settings.get_value("dev/developer_tools"))
	_sandbox_btn.visible = dev_on
	_dev_note.visible = dev_on
	_refresh_default_focus()
	if is_inside_tree() and not dev_on and _sandbox_btn.has_focus():
		_new_game_btn.grab_focus()


## Continue holds focus when a save exists, else New game.
func _refresh_default_focus() -> void:
	var primary: Control = _continue_btn if _continue_btn.visible else _new_game_btn
	default_focus = get_path_to(primary)


## Continue (with its line of the save) and Load game show only when a save exists; the newest save is Continue.
func _refresh_saves() -> void:
	var newest: Dictionary = Session.newest_save() if Session.has_method(&"newest_save") else {}
	var has_save := not newest.is_empty()
	_continue_btn.visible = has_save
	_continue_hint.visible = has_save
	_load_btn.visible = has_save
	_continue_btn.kind = KitButton.Kind.MENU_PRIMARY
	_new_game_btn.kind = KitButton.Kind.MENU if has_save else KitButton.Kind.MENU_PRIMARY
	_continue_hint.text = _save_line(newest) if has_save else ""
	_refresh_default_focus()


## "Republic of Genoa · Spring 1482"; a sandbox save reads "Map sandbox · Spring 1482".
func _save_line(newest: Dictionary) -> String:
	var header := newest.get("header", {}) as Dictionary
	var country := str(header.get("country", ""))
	if country == "Sandbox" or (country.is_empty() and str(header.get("scenario_id", "")).is_empty()):
		country = "Map sandbox"
	var date := str(header.get("date", ""))
	return date if country.is_empty() else "%s · %s" % [country, date]


func _push_screen(id: StringName) -> Screen:
	if ctx == null or ctx.stack == null or not ctx.stack.has_method(&"push"):
		return null
	var next := ScreenIds.make(id)
	if next != null:
		ctx.stack.call(&"push", next)
	return next


## Continue loads the newest save (the App starts it, with the Loading screen).
func _on_continue_pressed() -> void:
	var newest: Dictionary = Session.newest_save() if Session.has_method(&"newest_save") else {}
	if newest.is_empty() or ctx == null:
		return
	ctx.request(&"load", {"slot": str(newest["slot"])})


## Load game opens the Save and Load screen on its Load tab.
func _on_load_pressed() -> void:
	if ctx == null or ctx.stack == null or not ctx.stack.has_method(&"push"):
		return
	ctx.stack.call(&"push", SaveLoad.make(&"load"))


func _on_new_game_pressed() -> void:
	_push_screen(&"new_game")


func _on_sandbox_pressed() -> void:
	_push_screen(&"sandbox")


func _on_options_pressed() -> void:
	_push_screen(&"options")


func _on_credits_pressed() -> void:
	_push_screen(&"credits")


func _on_quit_pressed() -> void:
	if ctx != null:
		ctx.request(&"quit")


func _reduce_motion() -> bool:
	if ctx != null and ctx.settings != null:
		return bool(ctx.settings.get_value("accessibility/reduce_motion"))
	return false


func _format_version() -> String:
	var ver := str(ProjectSettings.get_setting("application/config/version", "0.3.0"))
	var info := Engine.get_version_info()
	var eng := "%d.%d.%d" % [int(info.get("major", 4)), int(info.get("minor", 7)), int(info.get("patch", 2))]
	return "%s · Godot %s" % [ver, eng]
