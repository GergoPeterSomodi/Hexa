## The action log (docs/architecture/m3-build-spec.md section 6.5), bottom left of the map, above the key hints. Closed: one
## icon button (the kit's `log` icon, tooltip "Log") with a small badge of the unread lines; it takes no room on the map.
## Open: a card slides up from the icon (Motion.log_sheet; reduce motion sets it at once) with the filters (LogLines.FILTERS up
## to the milestone), the seasons newest first and their lines. A line with a hex asks to glide there (line_activated); the
## newest season's header asks for the last report (report_requested), an older one (in a game with countries) opens the
## study's History page at its turn (history_requested). The icon and Esc close it: the App's Esc ladder calls escape(). It
## reads Session and Events and sends intents only; the HUD places and wires it (Y18). Once bind_settings is called, its open
## state and filter are kept in Settings (state/log_open, state/log_filter).
class_name ActionLog
extends Control

## The player asked to glide to a line's hex.
signal line_activated(hex: Vector2i)
## M7: a battle line (its `record` is 0 or more) asks to open the battle dock at that record instead of gliding to its hex.
signal battle_requested(record: int)
## The player asked for the last season report (the newest season's header).
signal report_requested
## An older season's header asked for the History page at that season's turn.
signal history_requested(turn: int)

## The filters up to this milestone (LogLines.FILTERS carries the milestone each one arrives in).
const MILESTONE := 7
## The open card's size: at most 340 px wide (x 12 to 352 at 1280 wide, clear of the centred toast stack) and 268 px
## tall; the lines wrap inside it and the card scrolls.
const CARD_W := 340
## The side padding of a filter tab, so five tabs fit the card.
const TAB_PAD := 6.0
const TAB_STATES: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]
const CARD_H := 268
## The icon button is a square of this size; the card's bottom sits CARD_GAP above its top edge.
const ICON_SIZE := 40.0
const CARD_GAP := 8.0
## The key hints row keeps this much of the window's bottom clear of the card (fit_height).
const HINTS_CLEARANCE := 44
const KEYWORD_W := 96
## The badge shows the unread count up to BADGE_MAX; more reads BADGE_OVER.
const BADGE_MAX := 9
const BADGE_OVER := "9+"
const ICON_COLOUR_STATES: Array[StringName] = [
	&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_hover_pressed_color", &"icon_focus_color", &"icon_disabled_color",
]
const EMPTY_TEXT := "No actions yet."
const EMPTY_FILTER_TEXT := "Nothing under this filter yet."
const ACTIVATE_TIP := "Show on the map"
const REPORT_TIP := "Open the last report"
const HISTORY_TIP := "Open History at %s"
const TONE_VARIATION := {"good": &"NumberGood", "bad": &"NumberBad", "plain": &"SectionHead", "muted": &"Hint"}

@onready var _toggle: Button = $Toggle
@onready var _badge: PanelContainer = $Badge
@onready var _badge_text: Label = $Badge/BadgeText
@onready var _card: PanelContainer = $Card
@onready var _head: HBoxContainer = $Card/VBox/Head
@onready var _close: Button = $Card/VBox/Head/Close
@onready var _seasons: VBoxContainer = $Card/VBox/Scroll/Seasons

var feed := LogFeed.new()

var _settings: Settings = null
var _open := false
var _filter: StringName = &"all"
var _segments: Segmented = null
var _tightening := false
var _retired: Array[Node] = []
var _dirty := false
var _flush_queued := false
var _refresh_count := 0
var _slide_tween: Tween = null
## The card's resting y (its position when closed-and-shown); the slide starts and ends from it.
var _rest_y := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_segments = Segmented.new()
	_segments.hud_mode = true
	_segments.set_options(_filter_options())
	(_segments.get_node("Buttons") as HBoxContainer).add_theme_constant_override("separation", 0)  # the tabs fit the 340 px card
	_tighten_tabs()
	_head.add_child(_segments)
	_head.move_child(_segments, 0)
	_segments.changed.connect(_on_filter_picked)
	_toggle.pressed.connect(toggle)
	_close.pressed.connect(close)
	(_toggle as KitButton).tooltip_text = "Log"  # through KitButton, which keeps the base tip (the scene's value is lost to the script)
	# The 24 px icon is full-colour art: the button would tint it with its font colour, so its icon colours stay white (as vellum_sheet's seal does).
	for key: StringName in ICON_COLOUR_STATES:
		_toggle.add_theme_color_override(key, Color.WHITE)
	if Session.game != null:
		feed.rebuild(Session.game, Session.player_tag())
	_apply_visibility()
	refresh()


## The bus links live while the widget is in the tree, so a reparent (a HUD relayout) keeps them.
func _enter_tree() -> void:
	if not Events.chronicled.is_connected(_on_chronicled):
		Events.chronicled.connect(_on_chronicled)
	if not Events.game_started.is_connected(_on_game_started):
		Events.game_started.connect(_on_game_started)
	if not Events.game_ended.is_connected(_on_game_ended):
		Events.game_ended.connect(_on_game_ended)
	if not Events.country_chosen.is_connected(_on_country_chosen):
		Events.country_chosen.connect(_on_country_chosen)


func _exit_tree() -> void:
	if Events.chronicled.is_connected(_on_chronicled):
		Events.chronicled.disconnect(_on_chronicled)
	if Events.game_started.is_connected(_on_game_started):
		Events.game_started.disconnect(_on_game_started)
	if Events.game_ended.is_connected(_on_game_ended):
		Events.game_ended.disconnect(_on_game_ended)
	if Events.country_chosen.is_connected(_on_country_chosen):
		Events.country_chosen.disconnect(_on_country_chosen)
	PanelKit.free_retired(_retired)


## Keeps the open state and the filter in `settings` from now on, and takes them from it at once.
func bind_settings(settings: Settings) -> void:
	_settings = settings
	if is_node_ready():
		_read_settings()
		_apply_visibility()
		refresh()


## Caps the open card's height at `available` px; the card is never taller than CARD_H, and its lines scroll when they do not fit.
func fit_height(available: float) -> void:
	if not is_node_ready():
		return
	var height := minf(float(CARD_H), maxf(0.0, available))
	_card.custom_minimum_size.y = height
	_card.offset_top = _card.offset_bottom - height  # the card keeps its bottom edge and grows up from it
	if not (_slide_tween != null and _slide_tween.is_running()):
		_rest_y = _card.position.y


## Opens the card (it slides up) and marks every line read.
func open() -> void:
	_set_open(true)


## Closes the card (it slides down); the icon stays.
func close() -> void:
	_set_open(false)


func toggle() -> void:
	_set_open(not _open)


func is_open() -> bool:
	return _open


## Esc: closes an open log and returns true; false when it was closed (the Esc ladder goes on to its next step).
func escape() -> bool:
	if not _open:
		return false
	close()
	return true


## The filter the card shows: all, works or mine. An unknown id is ignored.
func set_filter(id: StringName) -> void:
	if not _filter_ids().has(id):
		return
	_filter = id
	if _segments != null:
		_segments.select(id)
	if _settings != null:
		_settings.set_value("state/log_filter", String(id))
	refresh()


func filter() -> StringName:
	return _filter


## Lines that arrived since the log was last open.
func unread() -> int:
	return feed.unread


## The season titles of the card, newest first ("Spring 1480"); empty when the card is closed.
func season_titles() -> Array[String]:
	var out: Array[String] = []
	if not _open:
		return out
	for season: Dictionary in feed.entries(_filter):
		out.append(str(season["title"]))
	return out


## The number of line rows on the card (zero when closed).
func line_count() -> int:
	var count := 0
	if not _open:
		return count
	for season: Dictionary in feed.entries(_filter):
		count += (season["lines"] as Array).size()
	return count


## The newest season's header button, or null when the card shows no season.
func report_button() -> Button:
	for child: Node in _seasons.get_children():
		if child is Button:
			return child as Button
	return null


## Every season header button of the card, newest first: the first asks for the last report, the others (in a game with
## countries) for History at their turn. Season headers that are plain text are not in it.
func header_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child: Node in _seasons.get_children():
		if child is Button:
			out.append(child as Button)
	return out


## The text of the "+N new" badge's count ("" when hidden): the unread lines, "9+" above nine.
func badge_text() -> String:
	return _badge_text.text if _badge.visible else ""


## Refreshes the badge and, when open, the card from the feed. Runs at once; bursts of chronicled events go through
## _mark_dirty, which runs one refresh at the next idle frame.
func refresh() -> void:
	if not is_node_ready():
		return
	_refresh_count += 1
	_dirty = false
	_sync_badge()
	if _open:
		_rebuild_seasons()


## How many refreshes have run (the tests count the rebuilds of a burst).
func refresh_count() -> int:
	return _refresh_count


## Asks for one refresh at the next idle frame; a second call in the same frame adds nothing.
func _mark_dirty() -> void:
	_dirty = true
	if _flush_queued or not is_inside_tree():
		return
	_flush_queued = true
	call_deferred("_flush")


func _flush() -> void:
	_flush_queued = false
	if _dirty:
		refresh()


func _set_open(value: bool) -> void:
	_open = value
	if _open:
		feed.mark_read()
	if _settings != null:
		_settings.set_value("state/log_open", _open)
	_slide(_open)
	refresh()


## Slides the card up (opening) or down and out (closing). A slide already running keeps the resting height it started from,
## so a click in mid-slide turns it round without a jump.
func _slide(opening: bool) -> void:
	if not is_node_ready():
		return
	var sliding := _slide_tween != null and _slide_tween.is_running()
	if sliding:
		_slide_tween.kill()
	else:
		_rest_y = _card.position.y
	if opening:
		_card.visible = true
	var tween := Motion.log_sheet(_card, _rest_y, opening, _reduce_motion())
	_slide_tween = tween
	if tween == null:
		_card.visible = opening
	elif not opening:
		tween.finished.connect(_on_slide_closed)


func _on_slide_closed() -> void:
	if _open:
		return
	_card.visible = false
	_card.position.y = _rest_y
	_slide_tween = null


func _apply_visibility() -> void:
	if not is_node_ready():
		return
	if _slide_tween != null and _slide_tween.is_running():
		return
	_card.visible = _open
	_card.modulate.a = 1.0


func _reduce_motion() -> bool:
	return _settings != null and bool(_settings.get_value("accessibility/reduce_motion"))


func _read_settings() -> void:
	_open = bool(_settings.get_value("state/log_open"))
	var stored := StringName(str(_settings.get_value("state/log_filter")))
	_filter = stored if _filter_ids().has(stored) else &"all"
	_segments.select(_filter)
	if _open:
		feed.mark_read()


func _sync_badge() -> void:
	_badge.visible = feed.unread > 0
	_badge_text.text = str(feed.unread) if feed.unread <= BADGE_MAX else BADGE_OVER


func _rebuild_seasons() -> void:
	PanelKit.clear_children(_seasons, _retired)
	var seasons := feed.entries(_filter)
	if seasons.is_empty():
		_seasons.add_child(PanelKit.reason(EMPTY_FILTER_TEXT if feed.has_game() else EMPTY_TEXT))
		return
	for at: int in seasons.size():
		var season := seasons[at]
		_seasons.add_child(_season_header(str(season["title"]), at == 0, int(season["turn"])))
		for line: Dictionary in season["lines"] as Array:
			_seasons.add_child(_line_row(line))


func _season_header(title: String, newest: bool, turn: int) -> Control:
	var older_link := not newest and Session.game != null and Session.game.has_countries()
	if not newest and not older_link:
		return PanelKit.label(title, &"SectionHead")
	var head := Button.new()
	head.text = title
	head.flat = true
	head.focus_mode = Control.FOCUS_NONE
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if newest:
		head.tooltip_text = REPORT_TIP
		head.pressed.connect(func() -> void: report_requested.emit())
	else:
		head.tooltip_text = HISTORY_TIP % title
		head.pressed.connect(func() -> void: history_requested.emit(turn))
	return head


func _line_row(line: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var keyword := PanelKit.label(str(line.get("keyword", "")), _tone_variation(str(line.get("tone", ""))))
	keyword.custom_minimum_size.x = KEYWORD_W
	row.add_child(keyword)
	var mine := bool(line.get("mine", false))
	var sentence := PanelKit.label(str(line.get("text", "")), &"Body" if mine else &"Hint")
	sentence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sentence.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sentence.custom_minimum_size.x = 1.0  # an autowrap label never asks for its one-line width, so a long line wraps
	var at: Vector2i = WorksView.NO_HEX
	var hex: Variant = line.get("hex", null)
	if hex is Vector2i:
		at = hex as Vector2i
	var record := int(line.get("record", -1))
	if at != WorksView.NO_HEX or record >= 0:
		# PASS, not STOP: the wheel still scrolls the card; a click is accepted in _on_line_input.
		sentence.mouse_filter = Control.MOUSE_FILTER_PASS
		sentence.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		sentence.tooltip_text = ACTIVATE_TIP
		sentence.gui_input.connect(_on_line_input.bind(at, record))
	row.add_child(sentence)
	return row


func _on_line_input(event: InputEvent, hex: Vector2i, record: int = -1) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if record >= 0:
			battle_requested.emit(record)
		else:
			line_activated.emit(hex)


func _tone_variation(tone: String) -> StringName:
	return TONE_VARIATION.get(tone, &"Hint") as StringName


## The five tabs (War arrives in M7) keep to the 340 px card: each tab's side padding is TAB_PAD px. The overrides are taken off
## and made again from the theme as it is now (a theme change calls this), so a new theme or scale is never held by a stale one.
func _tighten_tabs() -> void:
	if _segments == null or _tightening:
		return
	_tightening = true
	for id: StringName in _filter_ids():
		var btn := _segments.button_for(id)
		if btn == null:
			continue
		for state: String in TAB_STATES:
			btn.remove_theme_stylebox_override(state)
			var box := btn.get_theme_stylebox(state)
			if box == null:
				continue
			var tight := box.duplicate() as StyleBox
			tight.content_margin_left = TAB_PAD
			tight.content_margin_right = TAB_PAD
			btn.add_theme_stylebox_override(state, tight)
	_tightening = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_tighten_tabs.call_deferred()


func _filter_options() -> Array:
	var items: Array = []
	for f: Dictionary in LogLines.FILTERS:
		if int(str(f["since"])) > MILESTONE:
			continue
		var id := f["id"] as StringName
		items.append({"id": id, "label": String(id).capitalize()})
	return items


func _filter_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for item: Dictionary in _filter_options():
		ids.append(item["id"] as StringName)
	return ids


func _on_filter_picked(id: Variant) -> void:
	set_filter(StringName(str(id)))


## Counts the line at once (unread stays exact even mid-burst) and marks the view dirty; the rows are rebuilt once.
func _on_chronicled(entry: Dictionary) -> void:
	feed.add(entry)
	if _open:
		feed.mark_read()
	_mark_dirty()


## The viewer is the human country, which is &"" until the pick: the feed is rebuilt when it is chosen.
func _on_country_chosen(_tag: StringName) -> void:
	if Session.game != null:
		feed.rebuild(Session.game, Session.player_tag())
	refresh()


func _on_game_started() -> void:
	if Session.game != null:
		feed.rebuild(Session.game, Session.player_tag())
	else:
		feed.clear()
	refresh()


func _on_game_ended() -> void:
	feed.clear()
	refresh()
