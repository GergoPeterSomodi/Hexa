## Studiolo vellum confirmation modal screen with optional 10 s wax-seal countdown variant
## (docs/architecture/ui-and-controls-spec.md section 5.3 and 6.2;
## docs/architecture/ui-style-and-feedback-spec.md section 2 and 5).
class_name Confirm
extends Screen

signal confirmed(accepted: bool)
signal chose(choice_id: StringName)

@onready var _sheet: VellumSheet = $Center/Sheet

var _title: String = "Confirm"
var _body: String = ""
var _lede: String = ""
var _confirm_label: String = "Confirm"
var _cancel_label: String = "Cancel"
var _danger: bool = false
var _seal_letter: String = ""
var _seal_tone: StringName = &"vermilion"
var _choices: Array[Dictionary] = []
var _timeout_s: float = 0.0
var _timeout_choice: StringName = &"cancel"
var _safe_choice: StringName = &"cancel"
var _on_result: Callable = Callable()

var _remaining_s: float = 0.0
var _timer_active: bool = false
var _resolved: bool = false
var _last_displayed_sec: int = -1

var _body_label: Label = null
var _countdown_label: Label = null
var _choice_buttons: Dictionary[StringName, KitButton] = {}
var _ui_built: bool = false


## Builds and configures a Confirm screen from `params` via ScreenIds.
static func make(params: Dictionary) -> Confirm:
	var screen := ScreenIds.make(&"confirm") as Confirm
	if screen != null:
		screen.configure(params)
	return screen


## Spec-style constructor: Confirm.ask(title, lines, choices, extra_params).
static func ask(
	title_text: String,
	lines_or_body: Variant = "",
	choices: Array = [],
	extra: Dictionary = {}
) -> Confirm:
	var params := extra.duplicate()
	params["title"] = title_text
	if lines_or_body is Array:
		params["lines"] = lines_or_body
	else:
		params["body"] = str(lines_or_body)
	if not choices.is_empty():
		params["choices"] = choices
	return make(params)


func _ready() -> void:
	set_process(false)
	_ensure_ui()
	_rebuild_contents()


func _exit_tree() -> void:
	_timer_active = false
	set_process(false)


func _process(delta: float) -> void:
	if not _timer_active or _resolved:
		return
	_remaining_s -= delta
	if _remaining_s <= 0.0:
		_remaining_s = 0.0
		_update_countdown_display()
		_resolve(_timeout_choice)
		return
	_update_countdown_display()


## Configures title, body, choices, danger tone, countdown timeout, and result callback.
func configure(params: Dictionary) -> void:
	_title = str(params.get("title", "Confirm"))
	if params.has("lines") and params["lines"] is Array:
		var joined := PackedStringArray()
		for line: Variant in (params["lines"] as Array):
			joined.append(str(line))
		_body = "\n".join(joined)
	else:
		_body = str(params.get("body", ""))
	_lede = str(params.get("lede", ""))
	_confirm_label = str(params.get("confirm_label", "Confirm"))
	_cancel_label = str(params.get("cancel_label", "Cancel"))
	_danger = bool(params.get("danger", false))
	_seal_letter = str(params.get("seal_letter", "!" if _danger else "?"))
	_seal_tone = StringName(str(params.get("seal_tone", "vermilion")))
	_timeout_s = maxf(0.0, float(params.get("timeout_s", 0.0)))
	_timeout_choice = StringName(str(params.get("timeout_choice", params.get("timeout_id", "cancel"))))
	var cb: Variant = params.get("on_result", Callable())
	_on_result = cb if cb is Callable else Callable()

	_choices.clear()
	var raw_choices: Variant = params.get("choices", [])
	if raw_choices is Array and not (raw_choices as Array).is_empty():
		for item: Variant in (raw_choices as Array):
			if item is Dictionary:
				_choices.append(item as Dictionary)

	if params.has("safe_choice"):
		_safe_choice = StringName(str(params["safe_choice"]))
	else:
		_safe_choice = _derive_safe_choice(_choices)

	_resolved = false
	_last_displayed_sec = -1
	if _ui_built:
		_rebuild_contents()


func on_enter() -> void:
	_ensure_ui()
	_rebuild_contents()
	_resolved = false
	_sheet.press_seal(_reduce_motion())
	if _timeout_s > 0.0:
		_remaining_s = _timeout_s
		_timer_active = true
		_last_displayed_sec = -1
		_update_countdown_display()
		set_process(true)
	else:
		_timer_active = false
		set_process(false)


func on_exit() -> void:
	_timer_active = false
	set_process(false)


func back() -> bool:
	_resolve(_safe_choice)
	return true


func sheet() -> VellumSheet:
	_ensure_ui()
	return _sheet


func button_for(choice_id: StringName) -> KitButton:
	_ensure_ui()
	return _choice_buttons.get(choice_id, null)


func remaining_seconds() -> float:
	return _remaining_s


func _ensure_ui() -> void:
	if _ui_built:
		return
	if _sheet == null:
		_sheet = get_node_or_null("Center/Sheet") as VellumSheet
	if _sheet == null:
		return
	_ui_built = true
	_sheet.show_nav = false

	_body_label = Label.new()
	_body_label.name = &"BodyLabel"
	_body_label.theme_type_variation = &"LabelInk"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet.body().add_child(_body_label)

	_countdown_label = Label.new()
	_countdown_label.name = &"CountdownLabel"
	_countdown_label.theme_type_variation = &"LabelInkMuted"
	_countdown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_countdown_label.visible = false
	_sheet.body().add_child(_countdown_label)


func _rebuild_contents() -> void:
	if not _ui_built:
		return
	_sheet.title = _title
	_sheet.lede = _lede
	_sheet.show_nav = false
	_sheet.show_seal = true
	_sheet.seal_tone = _seal_tone
	_sheet.seal_letter = _seal_letter
	if _timeout_s > 0.0:
		_sheet.set_seal_text(str(maxi(1, ceili(_timeout_s))))
	else:
		_sheet.set_seal_text("")

	_body_label.text = _body
	_body_label.visible = not _body.is_empty()

	_clear_footer()
	_choice_buttons.clear()
	var specs := _effective_choices()
	var focus_target: KitButton = null
	var reduce := _reduce_motion()

	for spec: Dictionary in specs:
		var cid := StringName(str(spec.get("id", "cancel")))
		var btn := KitButton.new()
		btn.name = String(cid).capitalize().replace(" ", "") + "Button"
		btn.text = str(spec.get("label", String(cid)))
		btn.kind = _button_kind_for(str(spec.get("kind", "secondary")))
		btn.reduce_motion = reduce
		btn.pressed.connect(_on_choice_pressed.bind(cid))
		_sheet.footer().add_child(btn)
		_choice_buttons[cid] = btn
		if bool(spec.get("safe", false)) or (focus_target == null and cid == _safe_choice):
			focus_target = btn

	if focus_target == null and not specs.is_empty():
		var fallback_id := StringName(str(specs[specs.size() - 1].get("id", "cancel")))
		focus_target = _choice_buttons.get(fallback_id, null)
	if focus_target != null and is_inside_tree():
		default_focus = get_path_to(focus_target)

	_update_countdown_display()


func _effective_choices() -> Array[Dictionary]:
	if not _choices.is_empty():
		return _choices
	return [
		{
			"id": &"confirm",
			"label": _confirm_label,
			"kind": "danger" if _danger else "primary",
			"safe": false,
		},
		{
			"id": &"cancel",
			"label": _cancel_label,
			"kind": "secondary",
			"safe": true,
		},
	]


func _button_kind_for(kind_name: String) -> KitButton.Kind:
	match kind_name:
		"primary":
			return KitButton.Kind.PRIMARY
		"danger":
			return KitButton.Kind.DANGER
		_:
			return KitButton.Kind.SECONDARY


func _clear_footer() -> void:
	var foot := _sheet.footer()
	for child: Node in foot.get_children():
		foot.remove_child(child)
		child.queue_free()


func _update_countdown_display() -> void:
	if not _ui_built:
		return
	if _timeout_s <= 0.0:
		_countdown_label.visible = false
		return
	var shown_s := maxi(1, ceili(_remaining_s)) if _remaining_s > 0.0 else 0
	if shown_s == _last_displayed_sec:
		return
	_last_displayed_sec = shown_s
	_sheet.set_seal_text(str(shown_s))
	var timeout_btn: KitButton = _choice_buttons.get(_timeout_choice, null) as KitButton
	var choice_name: String = timeout_btn.text if timeout_btn != null else String(_timeout_choice)
	_countdown_label.text = "Reverting (%s) in %d s." % [choice_name, shown_s] if _timeout_choice == &"cancel" else "Selecting %s in %d s." % [choice_name, shown_s]
	_countdown_label.visible = true


func _resolve(choice_id: StringName) -> void:
	if _resolved:
		return
	_resolved = true
	_timer_active = false
	set_process(false)
	var accepted := choice_id == &"confirm"
	confirmed.emit(accepted)
	chose.emit(choice_id)
	if _on_result.is_valid():
		_on_result.call(accepted)
	finished.emit(choice_id)


func _on_choice_pressed(choice_id: StringName) -> void:
	_resolve(choice_id)


func _reduce_motion() -> bool:
	if ctx != null and ctx.settings != null:
		return bool(ctx.settings.get_value("accessibility/reduce_motion"))
	return false


func _derive_safe_choice(choices: Array[Dictionary]) -> StringName:
	for spec: Dictionary in choices:
		if bool(spec.get("safe", false)):
			return StringName(str(spec.get("id", "cancel")))
	for spec: Dictionary in choices:
		if StringName(str(spec.get("id", ""))) == &"cancel":
			return &"cancel"
	if not choices.is_empty():
		return StringName(str(choices[choices.size() - 1].get("id", "cancel")))
	return &"cancel"
