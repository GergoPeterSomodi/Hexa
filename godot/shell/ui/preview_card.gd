## Works preview card (556 px wide) showing what a build/upgrade/clear brings, four-season
## output strip, where the gain lands, before/after gain chart, cost, requirements, payback,
## refusal explanation, and two-column comparison mode
## (docs/architecture/ui-style-and-feedback-spec.md sections 5 and 7.1; game-feedback-screens.md B).
class_name PreviewCard
extends PanelContainer

signal begin_pressed
signal pin_toggled(on: bool)
signal closed
signal look_at_requested(hex: Vector2i)
signal treasury_only_toggled(on: bool)
## The content got taller or shorter: the screen refits the card to the window.
signal content_changed

@export var treasury_only: bool = false:
	set(value):
		treasury_only = value
		if _refs_bound and _treasury_only != null:
			_treasury_only.set_pressed_no_signal(treasury_only)

var _treasury_only: KitSwitch = null
var _close_btn: KitButton = null
var _title_label: Label = null
var _sub_label: Label = null
var _body: VBoxContainer = null
var _body_scroll: ScrollContainer = null
var _content: VBoxContainer = null
var _brings_head: Label = null
var _brings: VBoxContainer = null
var _season_strip: SeasonStrip = null
var _cols: HBoxContainer = null
var _lands_box: VBoxContainer = null
var _lands: VBoxContainer = null
var _chart_box: VBoxContainer = null
var _chart: InkChart = null
var _cost_label: Label = null
var _requirements: VBoxContainer = null
var _payback_label: Label = null
var _next_label: Label = null
var _compare_box: HBoxContainer = null
var _col_a: VBoxContainer = null
var _col_b: VBoxContainer = null
var _refusal: PanelContainer = null
var _refusal_label: Label = null
var _foot: HBoxContainer = null
var _pin_btn: KitButton = null
var _begin_btn: KitButton = null
var _chart_caption: HBoxContainer = null
var _refs_bound: bool = false

## Refusals that keep the whole card (money, goods, a slot); any other refusal shows only the refusal (spec 4.17).
const FULL_CARD_BLOCKS: Array[String] = ["slot", "ducats", "goods"]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_refs()
	_treasury_only.set_pressed_no_signal(treasury_only)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var key_ev := event as InputEventKey
	if key_ev != null and key_ev.pressed and not key_ev.is_echo() and key_ev.keycode == KEY_ESCAPE:
		closed.emit()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


## Populates the preview card for a single work option (accepted or refused).
func show_preview(p: Dictionary) -> void:
	_ensure_refs()
	var title_text := str(p.get("title", ""))
	var sub_text := str(p.get("subtitle", ""))
	_title_label.text = title_text
	_sub_label.text = sub_text
	_sub_label.visible = not sub_text.is_empty()
	accessibility_name = title_text

	var verdict_raw: Variant = p.get("verdict", {})
	var verdict: Dictionary = verdict_raw if verdict_raw is Dictionary else {}
	var ok := bool(verdict.get("ok", true))
	var reason := str(p.get("reason_words", ""))
	if reason.is_empty():
		reason = str(verdict.get("reason", ""))
	var full_card := str(p.get("blocked_by", "")) in FULL_CARD_BLOCKS
	_compare_box.visible = false
	if not ok and not full_card:
		# A rule refusal shows only the refusal (spec 4.17 blocked_by, 6.5).
		_body.visible = false
		_foot.visible = false
		_refusal.visible = true
		_refusal_label.text = reason
		_begin_btn.set_verdict({"ok": false, "reason": reason})
		visible = true
		return

	# Accepted, or refused for ducats, goods or a slot: the whole card, with the refusal bar when refused.
	_refusal.visible = not ok
	_refusal_label.text = reason
	_body.visible = true
	_foot.visible = true
	_begin_btn.set_verdict({"ok": ok, "reason": reason})

	_populate_brings(p.get("brings", []))
	_populate_seasons_and_chart(p.get("by_season", []))
	_populate_caption(p.get("year", {}))
	_populate_lands(p.get("lands", {}))
	_populate_cost(p.get("cost", {}))
	_populate_requirements(p.get("requirements", []))
	_populate_payback(p.get("payback", {}))
	_populate_next(p.get("next_stages", []))
	_cols.visible = _lands_box.visible or _chart_box.visible
	visible = true


## Populates a two-column comparison of preview `a` and `b` on shared chart bounds.
func show_compare(a: Dictionary, b: Dictionary) -> void:
	_ensure_refs()
	_body.visible = false
	_refusal.visible = false
	_compare_box.visible = true
	_foot.visible = true

	var title_a := str(a.get("title", "Option A"))
	var title_b := str(b.get("title", "Option B"))
	_title_label.text = "%s vs %s" % [title_a, title_b]
	_sub_label.text = ""
	_sub_label.visible = false
	accessibility_name = _title_label.text

	var gain_a := _year_gain(a)
	var gain_b := _year_gain(b)
	var shared_ticks := _shared_chart_ticks(a, b)

	PanelKit.clear_children(_col_a)
	PanelKit.clear_children(_col_b)
	var comparable := _has_return(a) and _has_return(b)  # a card without a gain (a barracks) is neither better nor worse
	_populate_compare_col(_col_a, a, comparable and gain_a > gain_b, shared_ticks)
	_populate_compare_col(_col_b, b, comparable and gain_b > gain_a, shared_ticks)

	var b_verdict: Dictionary = b.get("verdict", {}) if b.get("verdict", {}) is Dictionary else {}
	if not bool(b_verdict.get("ok", true)):
		_begin_btn.set_verdict(b_verdict)
	else:
		_begin_btn.set_verdict({"ok": true})
	visible = true


## Focuses the primary Begin button when visible and enabled.
func focus_begin() -> void:
	_ensure_refs()
	if _begin_btn.visible and not _begin_btn.disabled:
		_begin_btn.grab_focus()


## Sets the pinned state of the Foot's "Pin to compare" without emitting `pin_toggled`.
func set_pinned(on: bool) -> void:
	_ensure_refs()
	_pin_btn.set_pressed_no_signal(on)


func title_label() -> Label:
	_ensure_refs()
	return _title_label


func sub_label() -> Label:
	_ensure_refs()
	return _sub_label


func brings_container() -> VBoxContainer:
	_ensure_refs()
	return _brings


func season_strip() -> SeasonStrip:
	_ensure_refs()
	return _season_strip


func lands_container() -> VBoxContainer:
	_ensure_refs()
	return _lands


func chart() -> InkChart:
	_ensure_refs()
	return _chart


func cost_label() -> Label:
	_ensure_refs()
	return _cost_label


func requirements_container() -> VBoxContainer:
	_ensure_refs()
	return _requirements


func payback_label() -> Label:
	_ensure_refs()
	return _payback_label


func next_label() -> Label:
	_ensure_refs()
	return _next_label


func refusal_panel() -> PanelContainer:
	_ensure_refs()
	return _refusal


func refusal_label() -> Label:
	_ensure_refs()
	return _refusal_label


func begin_button() -> KitButton:
	_ensure_refs()
	return _begin_btn


func close_button() -> KitButton:
	_ensure_refs()
	return _close_btn


func pin_button() -> KitButton:
	_ensure_refs()
	return _pin_btn


func treasury_only_switch() -> KitSwitch:
	_ensure_refs()
	return _treasury_only


## The scrolling part of the card (the foot stays below it).
func body_scroll() -> ScrollContainer:
	_ensure_refs()
	return _body_scroll


func foot() -> HBoxContainer:
	_ensure_refs()
	return _foot


## The card's height with nothing scrolled: its own chrome, title, the whole content and the foot.
func natural_height() -> float:
	_ensure_refs()
	return get_combined_minimum_size().y - _body_scroll.get_combined_minimum_size().y + _content.get_combined_minimum_size().y


func body_visible() -> bool:
	_ensure_refs()
	return _body.visible


func foot_visible() -> bool:
	_ensure_refs()
	return _foot.visible


func compare_container() -> HBoxContainer:
	_ensure_refs()
	return _compare_box


func _ensure_refs() -> void:
	if _refs_bound:
		return
	_treasury_only = get_node("VBox/Foot/TreasuryOnly") as KitSwitch
	_close_btn = get_node("VBox/Top/CloseBtn") as KitButton
	_title_label = get_node("VBox/Title") as Label
	_sub_label = get_node("VBox/Sub") as Label
	_body_scroll = get_node("VBox/BodyScroll") as ScrollContainer
	_content = get_node("VBox/BodyScroll/Content") as VBoxContainer
	_body = get_node("VBox/BodyScroll/Content/Body") as VBoxContainer
	_brings_head = get_node("VBox/BodyScroll/Content/Body/BringsHead") as Label
	_brings = get_node("VBox/BodyScroll/Content/Body/Brings") as VBoxContainer
	_season_strip = get_node("VBox/BodyScroll/Content/Body/SeasonStrip") as SeasonStrip
	_cols = get_node("VBox/BodyScroll/Content/Body/Cols") as HBoxContainer
	_lands_box = get_node("VBox/BodyScroll/Content/Body/Cols/LandsBox") as VBoxContainer
	_lands = get_node("VBox/BodyScroll/Content/Body/Cols/LandsBox/Lands") as VBoxContainer
	_chart_box = get_node("VBox/BodyScroll/Content/Body/Cols/ChartBox") as VBoxContainer
	_chart = get_node("VBox/BodyScroll/Content/Body/Cols/ChartBox/InkChart") as InkChart
	_cost_label = get_node("VBox/BodyScroll/Content/Body/Cost") as Label
	_requirements = get_node("VBox/BodyScroll/Content/Body/Requirements") as VBoxContainer
	_payback_label = get_node("VBox/BodyScroll/Content/Body/Payback") as Label
	_next_label = get_node("VBox/BodyScroll/Content/Body/Next") as Label
	_compare_box = get_node("VBox/BodyScroll/Content/CompareBox") as HBoxContainer
	_col_a = get_node("VBox/BodyScroll/Content/CompareBox/ColA") as VBoxContainer
	_col_b = get_node("VBox/BodyScroll/Content/CompareBox/ColB") as VBoxContainer
	_refusal = get_node("VBox/BodyScroll/Content/Refusal") as PanelContainer
	_refusal_label = get_node("VBox/BodyScroll/Content/Refusal/RefusalLabel") as Label
	_foot = get_node("VBox/Foot") as HBoxContainer
	_pin_btn = get_node("VBox/Foot/PinBtn") as KitButton
	_begin_btn = get_node("VBox/Foot/BeginBtn") as KitButton
	_chart_caption = HBoxContainer.new()
	_chart_caption.name = &"Caption"
	_chart_caption.visible = false
	_chart_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chart_box.add_child(_chart_caption)

	_close_btn.pressed.connect(_on_close_pressed)
	_begin_btn.pressed.connect(_on_begin_pressed)
	_pin_btn.toggled.connect(_on_pin_btn_toggled)
	_treasury_only.toggled.connect(_on_treasury_only_toggled)
	_content.minimum_size_changed.connect(content_changed.emit)
	_refs_bound = true


func _populate_brings(raw_brings: Variant) -> void:
	PanelKit.clear_children(_brings)
	var items: Array = raw_brings if raw_brings is Array else []
	for item_var: Variant in items:
		if typeof(item_var) != TYPE_DICTIONARY:
			continue
		var b := item_var as Dictionary
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var before := int(b.get("before", 0))
		var after := int(b.get("after", 0))
		var name_lbl := Label.new()
		name_lbl.theme_type_variation = &"TableRow"
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.text = _brings_name(b)
		row.add_child(name_lbl)
		var value_lbl := Label.new()
		value_lbl.theme_type_variation = &"TableRow"
		value_lbl.text = "%d → %d" % [before, after]
		row.add_child(value_lbl)
		var chip := DeltaChip.new()
		var field := StringName(str(b.get("field", "")))
		var tone := StringName(str(b.get("tone", "")))
		chip.invert = (field == &"upkeep" or tone == &"invert")
		chip.set_delta(after - before)
		row.add_child(chip)
		_brings.add_child(row)

	var has_brings := _brings.get_child_count() > 0
	_brings_head.visible = has_brings
	_brings.visible = has_brings


## "Wine, a year", "Port dues, in spring": the label with its period.
static func _brings_name(b: Dictionary) -> String:
	var label_str := str(b.get("label", str(b.get("field", ""))))
	var per := str(b.get("per", ""))
	if per.is_empty():
		return label_str
	if per == "spring":
		return "%s, in spring" % label_str
	return "%s, a %s" % [label_str, per]


func _populate_seasons_and_chart(raw_seasons: Variant) -> void:
	var seasons: Array = raw_seasons if raw_seasons is Array else []
	var now_idx := 0
	var x_labs := PackedStringArray()
	var before_vals := PackedInt32Array()
	var after_vals := PackedInt32Array()

	for i: int in seasons.size():
		if typeof(seasons[i]) != TYPE_DICTIONARY:
			continue
		var s := seasons[i] as Dictionary
		if bool(s.get("now", false)):
			now_idx = i
		x_labs.append(str(s.get("season", "")))
		before_vals.append(_measure(s, "before"))
		after_vals.append(_measure(s, "after"))

	_season_strip.set_seasons(_view_seasons(seasons), now_idx)
	if seasons.is_empty():
		_chart_box.visible = false
		_chart.set_series([])
	else:
		_chart_box.visible = true
		_chart.x_labels = x_labs
		_chart.set_series([
			{"name": "Before", "values": before_vals, "ink": 0},
			{"name": "After", "values": after_vals, "ink": 3},
		])


func _populate_lands(raw_lands: Variant) -> void:
	PanelKit.clear_children(_lands)
	var lands: Dictionary = raw_lands if raw_lands is Dictionary else {}
	if lands.is_empty():
		_lands_box.visible = false
		return

	if lands.has("district") and lands["district"] is Dictionary:
		var d := lands["district"] as Dictionary
		_lands.add_child(_land_row("This district", int(d.get("before", 0)), int(d.get("after", 0))))

	var upkeep := int(lands.get("upkeep", 0))
	if upkeep != 0:
		var u_row := HBoxContainer.new()
		var u_lbl := Label.new()
		u_lbl.theme_type_variation = &"TableRow"
		u_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		u_lbl.text = "Upkeep"
		u_row.add_child(u_lbl)
		var u_chip := DeltaChip.new()
		u_chip.invert = true
		u_chip.set_delta(upkeep)
		u_row.add_child(u_chip)
		_lands.add_child(u_row)

	var ring_raw: Variant = lands.get("ring", [])
	var ring: Array = ring_raw if ring_raw is Array else []
	for r_var: Variant in ring:
		if typeof(r_var) != TYPE_DICTIONARY:
			continue
		var r := r_var as Dictionary
		var r_row := HBoxContainer.new()
		var hex_val: Variant = r.get("hex", null)
		if hex_val is Vector2i:
			var link := KitButton.new()
			link.kind = KitButton.Kind.SMALL
			link.text = str(r.get("name", str(hex_val)))
			link.pressed.connect(_on_ring_hex_pressed.bind(hex_val as Vector2i))
			r_row.add_child(link)
		var txt_lbl := Label.new()
		txt_lbl.theme_type_variation = &"Hint"
		txt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt_lbl.custom_minimum_size.x = 60.0
		txt_lbl.text = str(r.get("text", ""))
		r_row.add_child(txt_lbl)
		_lands.add_child(r_row)

	if lands.has("country") and lands["country"] is Dictionary:
		var c := lands["country"] as Dictionary
		_lands.add_child(_land_row("Country", _measure(c, "before"), _measure(c, "after")))

	_lands_box.visible = _lands.get_child_count() > 0


func _land_row(label_text: String, before: int, after: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.theme_type_variation = &"TableRow"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text = "%s %d → %d" % [label_text, before, after]
	row.add_child(lbl)
	var chip := DeltaChip.new()
	chip.set_delta(after - before)
	row.add_child(chip)
	return row


func _populate_cost(raw_cost: Variant) -> void:
	var text := ""
	if raw_cost is String:
		text = str(raw_cost)
	elif raw_cost is Dictionary:
		var c := raw_cost as Dictionary
		text = str(c.get("text", ""))
		if text.is_empty() and (c.has("ducats") or c.has("seasons")):
			text = "%d ducats · %d seasons" % [int(c.get("ducats", 0)), int(c.get("seasons", 0))]
	_cost_label.text = text
	_cost_label.visible = not text.is_empty()


func _populate_requirements(raw_reqs: Variant) -> void:
	PanelKit.clear_children(_requirements)
	var reqs: Array = raw_reqs if raw_reqs is Array else []
	for req_var: Variant in reqs:
		if typeof(req_var) != TYPE_DICTIONARY:
			continue
		var req := req_var as Dictionary
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ok := bool(req.get("ok", true))
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(float(Tokens.S4), float(Tokens.S4))
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_key := &"tick" if ok else &"cross"
		if has_theme_icon(icon_key, &"Kit"):
			icon_rect.texture = get_theme_icon(icon_key, &"Kit")
		var tone_var := &"NumberGood" if ok else &"NumberBad"
		if has_theme_color(&"font_color", tone_var):
			icon_rect.self_modulate = get_theme_color(&"font_color", tone_var)
		row.add_child(icon_rect)

		var lbl := Label.new()
		lbl.text = str(req.get("text", ""))
		lbl.theme_type_variation = &"TableRow" if ok else &"NumberBad"
		row.add_child(lbl)
		_requirements.add_child(row)
	_requirements.visible = _requirements.get_child_count() > 0


func _populate_payback(raw_payback: Variant) -> void:
	var text := ""
	if raw_payback is String:
		text = str(raw_payback)
	elif raw_payback is Dictionary:
		var pb := raw_payback as Dictionary
		var key := "text_treasury" if (treasury_only and pb.has("text_treasury")) else "text"
		text = str(pb.get(key, ""))
	_payback_label.text = text
	_payback_label.visible = not text.is_empty()


func _populate_next(raw_next: Variant) -> void:
	var text := ""
	if raw_next is String:
		text = str(raw_next)
	elif raw_next is Array:
		var parts: PackedStringArray = []
		for n_var: Variant in (raw_next as Array):
			if n_var is Dictionary:
				var n_txt := str((n_var as Dictionary).get("text", ""))
				if not n_txt.is_empty():
					parts.append(n_txt)
			elif n_var is String:
				parts.append(str(n_var))
		text = " ".join(parts)
	_next_label.text = text
	_next_label.visible = not text.is_empty()


func _populate_compare_col(col: VBoxContainer, p: Dictionary, is_better: bool, shared_ticks: PackedInt32Array) -> void:
	var head := Label.new()
	head.theme_type_variation = &"SectionHead" if is_better else &"TitlePanel"
	head.text = str(p.get("title", ""))
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size.x = 60.0
	col.add_child(head)

	var sub_txt := str(p.get("subtitle", ""))
	if not sub_txt.is_empty():
		var sub := Label.new()
		sub.theme_type_variation = &"Hint"
		sub.text = sub_txt
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size.x = 60.0
		col.add_child(sub)

	var verdict: Dictionary = p.get("verdict", {}) if p.get("verdict", {}) is Dictionary else {}
	if not bool(verdict.get("ok", true)):
		var ref := Label.new()
		ref.theme_type_variation = &"NumberBad"
		ref.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var r_words := str(p.get("reason_words", ""))
		ref.text = r_words if not r_words.is_empty() else str(verdict.get("reason", ""))
		col.add_child(ref)
		return

	var seasons_raw: Variant = p.get("by_season", [])
	var seasons: Array = seasons_raw if seasons_raw is Array else []
	if _has_return(p):  # a barracks has no gain to show
		var gain_chip := DeltaChip.new()
		gain_chip.boxed = is_better
		gain_chip.set_delta(_year_gain(p), "a year")
		col.add_child(gain_chip)

	if not seasons.is_empty():
		var c := InkChart.new()
		c.kind = InkChart.Kind.PAIRED_BARS
		c.ground = InkChart.Ground.SLOT
		c.custom_minimum_size = Vector2(120.0, 72.0)
		c.y_ticks = shared_ticks
		var xl := PackedStringArray()
		var bv := PackedInt32Array()
		var av := PackedInt32Array()
		for s_var: Variant in seasons:
			if s_var is Dictionary:
				var s := s_var as Dictionary
				xl.append(str(s.get("season", "")))
				bv.append(_measure(s, "before"))
				av.append(_measure(s, "after"))
		c.x_labels = xl
		c.set_series([
			{"name": "Before", "values": bv, "ink": 0},
			{"name": "After", "values": av, "ink": 3},
		])
		col.add_child(c)

	var cost_txt := ""
	var cost_raw: Variant = p.get("cost", {})
	if cost_raw is String:
		cost_txt = str(cost_raw)
	elif cost_raw is Dictionary:
		cost_txt = str((cost_raw as Dictionary).get("text", ""))
	if not cost_txt.is_empty():
		var cl := Label.new()
		cl.theme_type_variation = &"Hint"
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.text = cost_txt
		col.add_child(cl)


## The card says what it gives: a year or seasons of figures.
func _has_return(p: Dictionary) -> bool:
	var seasons: Variant = p.get("by_season", [])
	var year: Variant = p.get("year", {})
	return (seasons is Array and not (seasons as Array).is_empty()) or (year is Dictionary and not (year as Dictionary).is_empty())


func _year_gain(p: Dictionary) -> int:
	var yr: Variant = p.get("year", {})
	if yr is Dictionary and _has_gain(yr as Dictionary):
		return _pick_gain(yr as Dictionary)
	var total := 0
	var seasons: Variant = p.get("by_season", [])
	if seasons is Array:
		for s_var: Variant in (seasons as Array):
			if s_var is Dictionary:
				total += _pick_gain(s_var as Dictionary)
	return total


## The gain the card shows: the treasury measure when `treasury_only` and the preview has it, else the realm
## measure (spec 5.0 R2: the preview returns both; the shell picks one).
func _pick_gain(d: Dictionary) -> int:
	if treasury_only and d.has("gain_treasury"):
		return int(d["gain_treasury"])
	if d.has("gain_realm"):
		return int(d["gain_realm"])
	return int(d.get("gain", 0))


func _has_gain(d: Dictionary) -> bool:
	return d.has("gain_realm") or d.has("gain_treasury") or d.has("gain")


## The field in the measure the card shows: `<field>_treasury` when `treasury_only` and the preview has it, else
## `<field>_realm`, else the plain field (spec 5.0 R2: the preview returns both measures).
func _measure(d: Dictionary, field: String) -> int:
	if treasury_only and d.has(field + "_treasury"):
		return int(d[field + "_treasury"])
	if d.has(field + "_realm"):
		return int(d[field + "_realm"])
	return int(d.get(field, 0))


## The four season cells with `gain` replaced by the measure the card shows.
func _view_seasons(raw_seasons: Array) -> Array:
	var out: Array = []
	for s_var: Variant in raw_seasons:
		if typeof(s_var) != TYPE_DICTIONARY:
			continue
		var s := (s_var as Dictionary).duplicate()
		s["gain"] = _pick_gain(s_var as Dictionary)
		out.append(s)
	return out


## The chart's caption: "A year 511 → 533" and the year's gain chip (spec 6.5).
func _populate_caption(raw_year: Variant) -> void:
	PanelKit.clear_children(_chart_caption)
	var yr: Dictionary = raw_year if raw_year is Dictionary else {}
	_chart_caption.visible = not yr.is_empty()
	if yr.is_empty():
		return
	var before := _measure(yr, "before")
	var after := _measure(yr, "after")
	_chart_caption.add_child(PanelKit.label("A year %d → %d" % [before, after], &"Hint"))
	var chip := DeltaChip.new()
	chip.set_delta(_pick_gain(yr))
	_chart_caption.add_child(chip)


func _shared_chart_ticks(a: Dictionary, b: Dictionary) -> PackedInt32Array:
	var lo := 0
	var hi := 0
	for p: Dictionary in [a, b]:
		var seasons: Variant = p.get("by_season", [])
		if seasons is Array:
			for s_var: Variant in (seasons as Array):
				if s_var is Dictionary:
					var s := s_var as Dictionary
					var bv := _measure(s, "before")
					var av := _measure(s, "after")
					lo = mini(lo, mini(bv, av))
					hi = maxi(hi, maxi(bv, av))
	if lo == hi:
		hi = lo + 1
	return PackedInt32Array([lo, hi])


func _on_close_pressed() -> void:
	closed.emit()


func _on_begin_pressed() -> void:
	begin_pressed.emit()


func _on_pin_btn_toggled(on: bool) -> void:
	pin_toggled.emit(on)


func _on_treasury_only_toggled(on: bool) -> void:
	treasury_only = on
	treasury_only_toggled.emit(on)


func _on_ring_hex_pressed(hex: Vector2i) -> void:
	look_at_requested.emit(hex)
