## A company row: one kind of company the player may raise (tile-window spec R21, R27; the approved mockups, Appendix B). Two
## forms share one row dictionary, the raise row of TileArmy.of (kind, name, figure, era_text, men, parts, cost_text, upkeep,
## can_raise, state, reason, and attack when a later milestone adds it):
##   COMPACT  (the Army tab, mockup v4's small card): the figure on a wooden icon tile, the name with its age badge, one small
##            line (men, cost, upkeep; or the refusal's reason in red, unless the row says `reason_shared`: the tab then says it
##            once in its head line), and the Raise button (the hammer; greyed with its reason as tooltip when refused).
##   TALL     (the Raise companies window): a portrait, the name and badge, the men and upkeep line, the cost one part a line,
##            "can raise N", and the hammer. A refusal shows its reason under the row.
## The row changes nothing. The hammer emits hammer_pressed(kind) and its owner raises through Session.act. The hammer is
## enabled only when the row's state is ready (the raise check passed). hovered(kind) and unhovered tell the owner the pointer
## or the keyboard is on the row, so it can show the company card.
class_name CompanyRow
extends PanelContainer

const COMPACT := 0
const TALL := 1

signal hammer_pressed(kind: int)
signal hovered(kind: int)
signal unhovered

## Sizes of the two forms in logical pixels, from the mockups: the compact figure, the tall portrait, the hammer button.
const COMPACT_ICON_PX := 28
const TALL_PORTRAIT := Vector2(42, 46)
const HAMMER_SIZE := Vector2(28, 28)
const HAMMER_ICON := &"raise"
const HAMMER_FALLBACK := "+"
const ROW_VARIATION := &"PanelSlot"
const COMPACT_VARIATION := &"PanelTileUnit"
## The compact form's text, number and hammer variations (the tile window's look, mockup v4); the tall form keeps the kit's.
const COMPACT_TEXT := {&"CompanyName": &"TileName", &"CompanyMeta": &"TileHint", &"CompanyCount": &"TileValueMuted",
	&"ButtonIcon": &"ButtonTileAct", &"CompanyEra": &"TileEra", &"Hint": &"TileHint", &"HintBad": &"TileHintBad"}
## The compact form's mark over a figure whose silhouette is close to another's at the card's size (L4): pikemen carry a long
## pike across the tile, crossbowmen a crossbow.
const FIGURE_MARKS := {&"fig_infantry": TileGlyph.PIKE, &"fig_missile": TileGlyph.CROSSBOW}
## The compact form's Raise button.
const RAISE_TEXT := "Raise"
## The tall form's count when none can be raised (the compact form shows nothing then: its small line says why).
const NO_COUNT := "-"

var kind: int = -1
var layout: int = COMPACT
var _figure: TextureRect = null
var _hammer: Button = null
var _count: Label = null
var _name: String = ""
var _figure_name: StringName = &""


## A row of `form` for one raise row of TileArmy.of. Built once; a new row is a new node.
static func make(row: Dictionary, layout_value: int) -> CompanyRow:
	var out := CompanyRow.new()
	out.layout = layout_value
	out.setup(row)
	return out


## The hammer button (for the tests and the keyboard path).
func hammer() -> Button:
	return _hammer


## The "can raise N" text, or the dash.
func count_text() -> String:
	return _count.text if _count != null else ""


func _ready() -> void:
	if _figure != null and has_theme_icon(_figure_name, &"Kit"):
		_figure.texture = get_theme_icon(_figure_name, &"Kit")
	if _hammer != null and layout == COMPACT:
		_hammer.text = RAISE_TEXT
		_hammer.expand_icon = false
		if _hammer.disabled and has_theme_icon(&"lock", &"Kit"):
			_hammer.icon = get_theme_icon(&"lock", &"Kit")  # M4: a refused Raise shows a lock, not only a lower contrast
	elif _hammer != null:
		if has_theme_icon(HAMMER_ICON, &"Kit"):
			_hammer.icon = get_theme_icon(HAMMER_ICON, &"Kit")
		else:
			_hammer.text = HAMMER_FALLBACK


## Builds the row's nodes from the row dictionary.
func setup(row: Dictionary) -> void:
	kind = int(row["kind"])
	_name = str(row["name"])
	_figure_name = StringName(str(row.get("figure", "")))
	var state := StringName(str(row.get("state", "")))
	var reason := str(row.get("reason", ""))
	theme_type_variation = COMPACT_VARIATION if layout == COMPACT else ROW_VARIATION
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override(&"separation", Tokens.S2)
	add_child(body)
	if layout == COMPACT:
		body.add_theme_constant_override(&"separation", Tokens.S2 + 2)
	if layout == COMPACT:
		var tile := PanelContainer.new()
		tile.theme_type_variation = &"PanelTileIcon"
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tile.add_child(_figure_node())
		if FIGURE_MARKS.has(_figure_name):
			var mark := TileGlyph.make(FIGURE_MARKS[_figure_name], float(COMPACT_ICON_PX))
			mark.name = &"FigureMark"
			tile.add_child(mark)
		body.add_child(tile)
	else:
		body.add_child(_figure_node())
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override(&"separation", 0)
	text.add_child(_name_line(row))
	_fill_text(text, row, state, reason)
	body.add_child(text)
	if layout == TALL:
		body.add_child(_cost_column(row))
	body.add_child(_count_column(row, state))
	body.add_child(_hammer_button(row, state, reason))
	mouse_entered.connect(_on_entered)
	mouse_exited.connect(_on_exited)
	_hammer.mouse_entered.connect(_on_entered)
	_hammer.mouse_exited.connect(_on_exited)
	_hammer.focus_entered.connect(_on_entered)
	_hammer.focus_exited.connect(_on_exited)


func _figure_node() -> TextureRect:
	_figure = TextureRect.new()
	var side := TALL_PORTRAIT if layout == TALL else Vector2(COMPACT_ICON_PX, COMPACT_ICON_PX)
	_figure.custom_minimum_size = side
	_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_figure.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return _figure


## The name, then the age badge (I, II, III) in its own variation.
func _name_line(row: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 6)
	var title := PanelKit.label(_name, _v(&"CompanyName"))
	line.add_child(title)
	var era := str(row.get("era_text", ""))
	if era != "":
		line.add_child(PanelKit.label(era, _v(&"CompanyEra")))
	return line


## The small line under the name: the compact form shows the refusal's reason instead when the row is not ready; the tall
## form shows men and upkeep, and the reason goes under it.
func _fill_text(text: VBoxContainer, row: Dictionary, state: StringName, reason: String) -> void:
	var shared := bool(row.get("reason_shared", false))
	if layout == COMPACT and state != TileArmy.STATE_READY and reason != "" and not shared:
		text.add_child(_reason_label(state, reason, layout))
		return
	var meta := PanelKit.label(_meta_text(row), _v(&"CompanyMeta"))
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(meta)
	if layout == TALL and state != TileArmy.STATE_READY and reason != "":
		text.add_child(_reason_label(state, reason, layout))


## "500 men · 30 ducats + 1 iron" in the compact form (issue 436 round 3, H3: one line at 15 px; the upkeep is in the hover card);
## "500 men · upkeep 6" in the tall one (its costs are lines of their own). An attack figure is added when the row carries one.
func _meta_text(row: Dictionary) -> String:
	var men := Words.men(int(row.get("men", 0)))
	var upkeep := "upkeep %d" % int(row.get("upkeep", 0))
	var parts: Array[String] = [men]
	if layout == COMPACT:
		parts.append(str(row.get("cost_text", "")))
	if row.has("attack"):
		parts.append("attack %d" % int(row["attack"]))
	if layout == TALL:
		parts.append(upkeep)
	return " · ".join(parts)


## A locked row's reason is a quiet line (the era is not open yet); a refused or short row's reason is in the bad tone. The compact
## form uses the tile window's 15 px secondary text.
static func _reason_label(state: StringName, reason: String, form: int) -> Label:
	var variation := &"Hint" if state == TileArmy.STATE_LOCKED else &"HintBad"
	if form == COMPACT:
		variation = COMPACT_TEXT[variation]
	var label := PanelKit.label(reason, variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## The tall form's costs, one part a line: "30 ducats", "1 iron".
func _cost_column(row: Dictionary) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	for part: Dictionary in row.get("parts", []):
		column.add_child(PanelKit.label("%d %s" % [int(part["amount"]), str(part["name"])], &"CompanyMeta"))
	return column


## The tall form: "can raise N" (the tabular count), or the dash when none can be raised. The compact form: "×N", or nothing
## (the column hides) when none can be raised: its small line or the tab's head says why.
func _count_column(row: Dictionary, state: StringName) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var n := int(row.get("can_raise", 0))
	var ready := n > 0 and state == TileArmy.STATE_READY
	var text := "can raise %d" % n if ready else NO_COUNT
	if layout == COMPACT:
		text = "×%d" % n if ready else ""
		column.visible = false  # mockup v4's card has no count: the company card on hover says how many
	_count = PanelKit.label(text, _v(&"CompanyCount"))
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_count)
	return column


## The hammer: enabled when the row is ready; its tooltip and name carry the raise, or the refusal's reason.
func _hammer_button(row: Dictionary, state: StringName, reason: String) -> Button:
	_hammer = Button.new()
	_hammer.theme_type_variation = _v(&"ButtonIcon")
	_hammer.focus_mode = Control.FOCUS_ALL
	_hammer.mouse_filter = Control.MOUSE_FILTER_STOP
	_hammer.custom_minimum_size = HAMMER_SIZE
	_hammer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hammer.expand_icon = true
	_hammer.accessibility_name = "Raise one %s" % _name
	_hammer.disabled = state != TileArmy.STATE_READY
	_hammer.tooltip_text = "Raise one %s" % _name if state == TileArmy.STATE_READY else reason
	_hammer.pressed.connect(_on_hammer_pressed)
	return _hammer


## A variation in this row's form: the compact form's tile-window variation, or the kit's own in the tall form.
func _v(kit: StringName) -> StringName:
	return COMPACT_TEXT.get(kit, kit) if layout == COMPACT else kit


func _on_hammer_pressed() -> void:
	hammer_pressed.emit(kind)


func _on_entered() -> void:
	hovered.emit(kind)


## The pointer may move from the row onto its hammer (which takes the pointer too): the exit is checked a frame later.
func _on_exited() -> void:
	_leave.call_deferred()


func _leave() -> void:
	if not is_inside_tree():
		return
	if get_global_rect().has_point(get_global_mouse_position()) or _hammer.has_focus():
		return
	unhovered.emit()
