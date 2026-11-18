## Credits modal screen rendered on a Studiolo VellumSheet from res://CREDITS.md
## (docs/architecture/ui-and-controls-spec.md section 5.7;
## docs/architecture/ui-style-and-feedback-spec.md section 2).
class_name Credits
extends Screen

const CREDITS_PATH := "res://CREDITS.md"

@onready var _sheet: VellumSheet = $Center/Sheet

var _close_btn: KitButton = null
var _raw_text: String = ""
var _ui_built: bool = false


func _ready() -> void:
	_ensure_ui()


func on_enter() -> void:
	_ensure_ui()
	_close_btn.reduce_motion = _reduce_motion()
	_sheet.press_seal(_reduce_motion())


func back() -> bool:
	return false


func sheet() -> VellumSheet:
	_ensure_ui()
	return _sheet


func close_button() -> KitButton:
	_ensure_ui()
	return _close_btn


func credits_text() -> String:
	_ensure_ui()
	return _raw_text


func _ensure_ui() -> void:
	if _ui_built:
		return
	if _sheet == null:
		_sheet = get_node_or_null("Center/Sheet") as VellumSheet
	if _sheet == null:
		return
	_ui_built = true

	_raw_text = _load_credits_markdown()
	_populate_sections(_raw_text)

	_close_btn = KitButton.new()
	_close_btn.name = &"CloseButton"
	_close_btn.kind = KitButton.Kind.PRIMARY
	_close_btn.text = "Close"
	_close_btn.pressed.connect(_on_close_pressed)
	_sheet.footer().add_child(_close_btn)
	default_focus = get_path_to(_close_btn)


func _load_credits_markdown() -> String:
	if FileAccess.file_exists(CREDITS_PATH):
		var text := FileAccess.get_file_as_string(CREDITS_PATH)
		if not text.strip_edges().is_empty():
			return text
	return "## Hexa\n\nCredits could not be read from CREDITS.md."


func _populate_sections(markdown: String) -> void:
	var sections := _parse_markdown_sections(markdown)
	if sections.is_empty():
		var sec := _sheet.add_section(&"credits", "Credits")
		_add_paragraph(sec, markdown.strip_edges(), false)
		return
	for idx: int in sections.size():
		var sec_data: Dictionary = sections[idx]
		var title_str := str(sec_data["title"])
		var sec_id := StringName(title_str.to_lower().replace(" ", "_"))
		var container := _sheet.add_section(sec_id, title_str)
		var paragraphs: Array = sec_data["paragraphs"]
		for p_idx: int in paragraphs.size():
			var p: Dictionary = paragraphs[p_idx]
			_add_paragraph(container, str(p["text"]), bool(p["muted"]))


func _parse_markdown_sections(markdown: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var current_title := ""
	var current_lines: Array[String] = []
	var current_paras: Array[Dictionary] = []

	for raw_line: String in markdown.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("# ") and current_title.is_empty():
			continue
		if line.begins_with("## "):
			_flush_paragraph(current_lines, current_paras)
			if not current_title.is_empty():
				out.append({"title": current_title, "paragraphs": current_paras})
			current_title = line.substr(3).strip_edges()
			current_lines = []
			current_paras = []
			continue
		if line.is_empty():
			_flush_paragraph(current_lines, current_paras)
			current_lines = []
			continue
		if line.begins_with("- "):
			_flush_paragraph(current_lines, current_paras)
			current_lines = []
			current_paras.append({"text": "• " + _clean_inline_md(line.substr(2)), "muted": false})
			continue
		if line.begins_with("> "):
			current_lines.append(_clean_inline_md(line.substr(2)))
			continue
		current_lines.append(_clean_inline_md(line))

	_flush_paragraph(current_lines, current_paras)
	if not current_title.is_empty():
		out.append({"title": current_title, "paragraphs": current_paras})
	return out


func _flush_paragraph(lines: Array[String], out_paras: Array[Dictionary]) -> void:
	if lines.is_empty():
		return
	var text := " ".join(lines).strip_edges()
	if text.is_empty():
		return
	var is_license_block := text.begins_with("Copyright ") or text.begins_with("Permission is hereby") or text.begins_with("THE SOFTWARE")
	out_paras.append({"text": text, "muted": is_license_block})


func _clean_inline_md(text: String) -> String:
	return text.replace("**", "").replace("`", "")


func _add_paragraph(container: VBoxContainer, text: String, muted: bool) -> void:
	var lbl := Label.new()
	lbl.theme_type_variation = &"LabelInkMuted" if muted else &"LabelInk"
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(lbl)


func _on_close_pressed() -> void:
	finished.emit(&"close")


func _reduce_motion() -> bool:
	if ctx != null and ctx.settings != null:
		return bool(ctx.settings.get_value("accessibility/reduce_motion"))
	return false
