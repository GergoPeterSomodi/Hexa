## The battle dock (docs/architecture/m7-build-spec.md 6.5; M7 B22, issue #238): one battle, day by day, on the left of the map as
## an OVERLAY. Its model is BattleView.of (the only source: fog and the witness's rules are in the view, never read from
## Battle or BattleRecord here). Parts: the title and the place, the face-off (the two sides, the picture, the die), the stats,
## the front-line tug bar, the board (each side's reserve and three lanes, the front line), what each side fought on, the
## ground chips, the day log, the result, and the day stepper in the sticky footer (Earlier, Next, Skip to end, Play).
## Left and Right step the days, Home and End go to the first and last, Enter plays; Esc is the ScreenStack's (back() is false).
## Play runs the days at PLAY_STEP_S; reduce motion jumps to the last day. A record no longer kept shows its chronicle totals.
## The dock opens with show_record; the openers (the badges, the log, the Military page, the army panel) are B21/B24/B26/B28.
class_name BattleDock
extends Screen

const WIDTH: float = 420.0
const PANEL_FRAME := "res://shell/ui/panel_frame.tscn"
const PLAY_STEP_S: float = 0.6
const SHORT_LOG: int = 4
const NO_RECORD: int = -1
const NO_DAY: int = -1
const DAY_WORDS := "Day %d of %d"
const FLEE_WORDS := "Front-line morale · flees under %d %%"
const SIDE_ATTACKER := "attacker"
const SIDE_DEFENDER := "defender"
const CHIP_ICONS := {"pass": &"pass_cross", "river": &"river_cross", "hill": &"uphill", "walls": &"fortress"}

## The place's look-at button was pressed: the App glides the camera to the hex.
signal look_at_requested(hex: Vector2i)

var _frame: PanelFrame = null
var _body: VBoxContainer = null
var _clock: Timer = null
var _prev: KitButton = null
var _next: KitButton = null
var _skip: KitButton = null
var _play: KitButton = null
var _day_label: Label = null
var _record: int = NO_RECORD
var _view: Dictionary = {}
var _day: int = 0
var _days: int = 0
var _full_log: bool = false
var _arms: Dictionary = {}
var _retired: Array[Node] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = WIDTH
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame = (load(PANEL_FRAME) as PackedScene).instantiate() as PanelFrame
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)
	_frame.closed.connect(_on_close)
	_body = _frame.body()
	_clock = Timer.new()
	_clock.wait_time = PLAY_STEP_S
	_clock.one_shot = false
	add_child(_clock)
	_clock.timeout.connect(_on_tick)
	_build_footer()
	visible = false


func _exit_tree() -> void:
	if _clock != null:
		_clock.stop()
	PanelKit.free_retired(_retired)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.is_echo() or not _owns_keys():
		return
	match key.keycode:
		KEY_LEFT:
			step_day(-1)
		KEY_RIGHT:
			step_day(1)
		KEY_HOME:
			go_to_day(1)
		KEY_END:
			go_to_day(_days)
		KEY_ENTER, KEY_KP_ENTER:
			# A focused button (any of the dock's, or Full log, Show the place) takes Enter as its own press; Play takes it
			# only when it or nothing has the focus.
			var focused := get_viewport().gui_get_focus_owner() as BaseButton
			if focused != null and focused != _play:
				return
			play()
		_:
			return
	get_viewport().set_input_as_handled()


## Esc is the ScreenStack's: the dock does not consume it, so the stack pops it.
func back() -> bool:
	return false


func on_exit() -> void:
	stop()


## Opens the battle `record_id` at `day` (-1: the last day). Returns false, and shows nothing, when the viewer may not see it
## (the opener says so) or there is no game. Stepping a shown battle goes through go_to_day.
func show_record(record_id: int, day: int = NO_DAY) -> bool:
	var game := Session.game
	var view := BattleView.of(game, Session.player_tag(), record_id, day) if game != null else {}
	if view.is_empty():
		_hide()
		return false
	if record_id != _record:
		_full_log = false
	_record = record_id
	_view = view
	_days = int(view.get("days", 0))
	_day = int(view.get("day", 0))
	stop()
	visible = true
	refresh()
	return true


## The battle the dock shows, or NO_RECORD when it is hidden.
func shown_record() -> int:
	return _record if visible else NO_RECORD


## The hex the shown battle was fought on (Army.NO_HEX when nothing is shown).
func shown_hex() -> Vector2i:
	return _view.get("hex", Army.NO_HEX) as Vector2i if visible else Army.NO_HEX


## The day shown (1 to the battle's days; 0 for a battle no longer kept).
func shown_day() -> int:
	return _day if visible else 0


## The battle's days (0 when nothing is shown or the record is no longer kept).
func day_count() -> int:
	return _days if _kept() else 0


## Shows the day `delta` days away (clamped to the battle's days).
func step_day(delta: int) -> void:
	go_to_day(_day + delta)


## Shows day `day` of the shown battle (clamped to 1 .. its days). A stepped day stops a running play.
func go_to_day(day: int) -> void:
	stop()
	_show_day(day)


## Plays the days from day 1, one every PLAY_STEP_S; under reduce motion it jumps to the last day.
func play() -> void:
	if not _kept() or _days <= 1:
		return
	stop()
	if _reduce_motion():
		_show_day(_days)
		return
	if _day >= _days:
		_show_day(1)
	_clock.start()
	_sync_stepper()


## Whether a play is running.
func is_playing() -> bool:
	return _clock != null and not _clock.is_stopped()


## The title shown in the frame's cartouche, without the year, which is on the sub line ("" when hidden).
func cartouche_text() -> String:
	return _frame.cartouche_title if _frame != null else ""


## The battle's whole name as the spec words it ("" when hidden): the cartouche's tooltip.
func full_title() -> String:
	return _frame.cartouche().tooltip_text if _frame != null and visible else ""


## The result sentence of the shown battle ("" when nothing is shown).
func result_text() -> String:
	return str((_view.get("result", {}) as Dictionary).get("text", ""))


## Stops a running play (the stepper's controls come back).
func stop() -> void:
	if _clock != null and not _clock.is_stopped():
		_clock.stop()
	if is_node_ready():
		_sync_stepper()


## Shows the whole log (true) or the last SHORT_LOG days (false).
func set_full_log(on: bool) -> void:
	_full_log = on
	refresh()


## Whether the full log is shown.
func full_log() -> bool:
	return _full_log


## Rebuilds the dock's body and footer from the shown view.
func refresh() -> void:
	if not is_node_ready():
		return
	if _view.is_empty():
		_hide()
		return
	PanelKit.clear_children(_body, _retired)
	_arms = {}
	var full := str(_view.get("name", ""))
	var cut := full.rfind(", ")
	var year := full.substr(cut + 2) if cut > 0 else ""
	# The year goes on the sub line so the plate is short; the plate's tooltip keeps the whole name.
	_frame.cartouche_title = full.substr(0, cut) if year.is_valid_int() else full
	_frame.subtitle = year if year.is_valid_int() else ""
	_frame.cartouche().tooltip_text = full
	_frame.cartouche().accessibility_name = full
	_body.add_child(_place_row())
	if _kept():
		_body.add_child(_face_off())
		_body.add_child(_stats())
		_body.add_child(_morale_block())
		_body.add_child(_board())
		_body.add_child(_below_block())
	else:
		_body.add_child(_totals_block())
	_body.add_child(_result_label())
	_sync_stepper()


# --- footer: the day stepper ----------------------------------------------------------------------------------------------


func _build_footer() -> void:
	var foot := _frame.footer()
	_prev = _button("<", "Previous day", KitButton.Kind.SECONDARY)
	_prev.pressed.connect(step_day.bind(-1))
	_day_label = PanelKit.label("", &"TableRow")
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next = _button(">", "Next day", KitButton.Kind.SECONDARY)
	_next.pressed.connect(step_day.bind(1))
	_play = _button("Play", "Play the days", KitButton.Kind.SECONDARY)
	_play.pressed.connect(play)
	_skip = _button("End", "Skip to the last day", KitButton.Kind.SECONDARY)
	_skip.pressed.connect(func() -> void: go_to_day(_days))
	foot.add_child(_prev)
	foot.add_child(_day_label)
	foot.add_child(_next)
	foot.add_child(_play)
	foot.add_child(_skip)


## The stepper's state: the controls at the ends are disabled, Play is off while a play runs or with one day.
func _sync_stepper() -> void:
	if _frame == null:
		return
	var live := _kept()
	_frame.footer().visible = live
	_day_label.text = DAY_WORDS % [_day, _days]
	_prev.disabled = _day <= 1
	_next.disabled = _day >= _days
	_skip.disabled = _day >= _days
	_play.disabled = is_playing() or _days <= 1


# --- the parts ------------------------------------------------------------------------------------------------------------


func _place_row() -> Control:
	var row := HBoxContainer.new()
	var place := _wrapped(str(_view.get("place", "")), &"Hint")
	place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(place)
	var look := _button("Show the place", "Show the place on the map", KitButton.Kind.SMALL)
	look.pressed.connect(func() -> void: look_at_requested.emit(_view.get("hex", Army.NO_HEX) as Vector2i))
	row.add_child(look)
	return row


func _face_off() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var picture := BattlePicture.new()
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var attacker := _side(SIDE_ATTACKER)
	var defender := _side(SIDE_DEFENDER)
	row.add_child(_arms_block(SIDE_ATTACKER))
	row.add_child(picture)
	row.add_child(_arms_block(SIDE_DEFENDER))
	var caption := "%s · day %d" % [_ground_text(), _day]
	picture.set_picture(_first_figure(attacker), _first_figure(defender), caption)
	return row


func _arms_block(which: String) -> Control:
	var side := _side(which)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var arms := _arms_for(side)
	if arms != null:
		col.add_child(arms)
		_arms[which] = arms
	col.add_child(_wrapped(str(side.get("name", "")), &"TableRow"))
	col.add_child(_wrapped(str(side.get("role_text", "")), &"Hint"))
	col.add_child(_wrapped(str(side.get("general_text", "")), &"Hint"))
	return col


func _stats() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	var a := _side(SIDE_ATTACKER)
	var d := _side(SIDE_DEFENDER)
	_stat_row(grid, "%s of %s" % [Words.number(int(a.get("men", 0))), Words.number(int(a.get("start", 0)))],
		"Men now / start", "%s of %s" % [Words.number(int(d.get("men", 0))), Words.number(int(d.get("start", 0)))])
	_stat_row(grid, Words.number(int(a.get("killed", 0))), "Killed", Words.number(int(d.get("killed", 0))))
	_stat_row(grid, Words.number(int(a.get("wounded", 0))), "Wounded", Words.number(int(d.get("wounded", 0))))
	grid.add_child(_die_of(a))
	grid.add_child(PanelKit.label("Dice", &"Hint"))
	grid.add_child(_die_of(d))
	return grid


func _stat_row(grid: GridContainer, left: String, key: String, right: String) -> void:
	var l := PanelKit.label(left, &"TableRow")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(l)
	var k := PanelKit.label(key, &"Hint")
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid.add_child(k)
	var r := PanelKit.label(right, &"TableRow")
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(r)


func _die_of(side: Dictionary) -> DieFace:
	var die := DieFace.new()
	var mult := str(side.get("mult_text", ""))
	die.set_face(int(side.get("roll", 1)), mult, _tone_colour(StringName(str(side.get("mult_tone", "plain")))))
	die.accessibility_name = "Dice roll %d, %s" % [int(side.get("roll", 1)), mult]
	die.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return die


func _morale_block() -> Control:
	var col := VBoxContainer.new()
	var fa := int((_side(SIDE_ATTACKER)).get("front", 0))
	var fd := int((_side(SIDE_DEFENDER)).get("front", 0))
	col.add_child(_wrapped(FLEE_WORDS % roundi(TugBar.FLEE_PERMILLE / 10.0), &"Hint"))
	var row := HBoxContainer.new()
	var bar := TugBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.set_values(fa, fd, _colour_of(SIDE_ATTACKER), _colour_of(SIDE_DEFENDER))
	bar.accessibility_name = "Front-line morale: attacker %d %%, defender %d %%" % [roundi(fa / 10.0), roundi(fd / 10.0)]
	row.add_child(_percent(fa))
	row.add_child(bar)
	row.add_child(_percent(fd))
	col.add_child(row)
	return col


func _board() -> Control:
	var col := VBoxContainer.new()
	col.add_child(PanelKit.label("The field", &"SectionHead"))
	var bottom := SIDE_DEFENDER if str(_view.get("viewer_side", "")) == SIDE_DEFENDER else SIDE_ATTACKER
	var top := SIDE_ATTACKER if bottom == SIDE_DEFENDER else SIDE_DEFENDER
	col.add_child(_side_rows(top))
	col.add_child(FrontLine.new())
	col.add_child(_side_rows(bottom))
	return col


func _side_rows(which: String) -> Control:
	var side := _side(which)
	var col := VBoxContainer.new()
	col.add_child(_wrapped("%s · reserve" % str(side.get("name", "")), &"Hint"))
	col.add_child(_tiles_flow(side.get("reserve", []) as Array, "No company in reserve"))
	var lanes := HBoxContainer.new()
	for lane: Variant in side.get("lanes", []) as Array:
		var tile := RegimentTile.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.set_entry(lane as Dictionary)
		lanes.add_child(tile)
	col.add_child(lanes)
	var routed: Array = side.get("routed", []) as Array
	if not routed.is_empty():
		col.add_child(_wrapped("Routed", &"Hint"))
		col.add_child(_tiles_flow(routed, ""))
	return col


func _tiles_flow(entries: Array, empty_words: String) -> Control:
	var flow := HFlowContainer.new()
	for entry: Variant in entries:
		var tile := RegimentTile.new()
		tile.set_entry(entry as Dictionary)
		flow.add_child(tile)
	if entries.is_empty() and empty_words != "":
		flow.add_child(PanelKit.label(empty_words, &"Hint"))
	return flow


func _below_block() -> Control:
	var col := VBoxContainer.new()
	var fought: PackedStringArray = []
	for which: String in [SIDE_ATTACKER, SIDE_DEFENDER]:
		var side := _side(which)
		var stance := str(side.get("stance_text", ""))
		if stance != "":
			fought.append("%s: %s" % [str(side.get("name", "")), stance])
	if not fought.is_empty():
		col.add_child(_wrapped(" · ".join(fought), &"TableRow"))
	var chips := HFlowContainer.new()
	for chip: Variant in (_view.get("ground", {}) as Dictionary).get("chips", []) as Array:
		chips.add_child(_chip(chip as Dictionary))
	col.add_child(chips)
	col.add_child(_log_block())
	return col


func _chip(chip: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var icon_name: StringName = CHIP_ICONS.get(str(chip.get("icon", "")), &"")
	if icon_name != &"" and has_theme_icon(icon_name, &"Kit"):
		var tex := TextureRect.new()
		tex.texture = get_theme_icon(icon_name, &"Kit")
		tex.custom_minimum_size = Vector2(16.0, 16.0)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tex)
	row.add_child(PanelKit.label(str(chip.get("text", "")), &"Hint"))
	return row


func _log_block() -> Control:
	var col := VBoxContainer.new()
	col.add_child(PanelKit.label("Day log", &"SectionHead"))
	var lines: Array = _view.get("log", []) as Array
	var first := 0 if _full_log else maxi(0, lines.size() - SHORT_LOG)
	for i: int in range(first, lines.size()):
		var entry := lines[i] as Dictionary
		var lbl := _wrapped(str(entry.get("text", "")), &"Hint")
		lbl.add_theme_color_override(&"font_color", _tone_colour(StringName(str(entry.get("tone", "plain")))))
		col.add_child(lbl)
	if lines.size() > SHORT_LOG:
		var toggle := _button("Short log" if _full_log else "Full log", "Show the whole log", KitButton.Kind.SMALL)
		toggle.pressed.connect(set_full_log.bind(not _full_log))
		col.add_child(toggle)
	return col


func _totals_block() -> Control:
	var col := VBoxContainer.new()
	col.add_child(_wrapped(str(_view.get("note", "")), &"Hint"))
	var totals := _view.get("totals", {}) as Dictionary
	var sides := _view.get("sides", {}) as Dictionary
	var att := _tag_of(sides, SIDE_ATTACKER)
	var dfn := _tag_of(sides, SIDE_DEFENDER)
	for key: String in ["killed", "wounded"]:
		var pair := totals.get(key, {}) as Dictionary
		col.add_child(_wrapped("%s: %s · %s" % [key.capitalize(), Words.number(int(pair.get(att, 0))),
			Words.number(int(pair.get(dfn, 0)))], &"TableRow"))
	return col


func _result_label() -> Label:
	var result := _view.get("result", {}) as Dictionary
	var lbl := _wrapped(str(result.get("text", "")), &"TableRow")
	lbl.add_theme_color_override(&"font_color", _tone_colour(StringName(str(result.get("tone", "plain")))))
	return lbl


# --- helpers --------------------------------------------------------------------------------------------------------------


## A side's dictionary from the view (keyed by the side's tag); {} when the view has none.
func _side(which: String) -> Dictionary:
	var sides := _view.get("sides", {}) as Dictionary
	var tags := sides.get(which, []) as Array
	if tags.is_empty():
		return {}
	var all := _view.get("side", {}) as Dictionary
	return all.get(str(tags[0]), {}) as Dictionary


func _tag_of(sides: Dictionary, which: String) -> String:
	var tags := sides.get(which, []) as Array
	return str(tags[0]) if not tags.is_empty() else ""


func _kept() -> bool:
	return not _view.is_empty() and bool(_view.get("kept", false))


func _ground_text() -> String:
	return str((_view.get("ground", {}) as Dictionary).get("text", ""))


func _first_figure(side: Dictionary) -> StringName:
	for lane: Variant in side.get("lanes", []) as Array:
		var entry := lane as Dictionary
		if not bool(entry.get("empty", true)):
			return StringName(str(entry.get("figure", "")))
	return &""


func _arms_for(side: Dictionary) -> CountryArms:
	var name := str(side.get("name", ""))
	if name == "" or name == BattleView.UNKNOWN_NAME or Session.game == null:
		return null
	var card := CountryCard.of(Session.game, StringName(str(side.get("tag", ""))))
	if card.is_empty():
		return null
	var arms := CountryArms.new()
	arms.small = true
	arms.set_country(card["arms"] as Dictionary)
	return arms


func _colour_of(which: String) -> Color:
	var arms := _arms.get(which) as CountryArms
	return arms.field_color() if arms != null and arms.has_arms() else Tokens.MUTED


func _percent(permille: int) -> Label:
	return PanelKit.label("%d %%" % roundi(permille / 10.0), &"Hint")


func _tone_colour(tone: StringName) -> Color:
	if tone == BattleView.TONE_GOOD:
		return Tokens.GOOD
	if tone == BattleView.TONE_BAD:
		return Tokens.BAD
	return Tokens.TEXT


func _wrapped(text: String, variation: StringName) -> Label:
	var lbl := PanelKit.label(text, variation)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


func _button(text: String, tip: String, kind: KitButton.Kind) -> KitButton:
	var btn := KitButton.new()
	btn.kind = kind
	btn.text = text
	btn.tooltip_text = tip
	btn.accessibility_name = tip
	btn.focus_mode = Control.FOCUS_ALL
	return btn


func _hide() -> void:
	stop()
	_view = {}
	_record = NO_RECORD
	visible = false
	if _body != null:
		PanelKit.clear_children(_body, _retired)


func _on_tick() -> void:
	if not _kept() or _day >= _days:
		stop()
		return
	_show_day(_day + 1)
	if _day >= _days:
		stop()


## Loads and shows a day without touching a running play (the tick and play itself use it).
func _show_day(day: int) -> void:
	if not _kept() or _record == NO_RECORD:
		return
	var target := clampi(day, 1, _days)
	var game := Session.game
	var view := BattleView.of(game, Session.player_tag(), _record, target) if game != null else {}
	if view.is_empty():
		_hide()
		return
	_view = view
	_day = int(view.get("day", target))
	refresh()


func _on_close() -> void:
	stop()
	finished.emit(&"close")


func _reduce_motion() -> bool:
	return ctx != null and ctx.settings != null and bool(ctx.settings.get_value("accessibility/reduce_motion"))


## Whether a key press is the dock's to take: the dock is shown and is the top screen (a Confirm over it takes its keys).
func _owns_keys() -> bool:
	if not is_visible_in_tree() or _view.is_empty():
		return false
	if ctx != null and ctx.stack != null and ctx.stack.has_method(&"top"):
		return ctx.stack.call(&"top") == self
	return true



## A dashed line across the board between the two sides: the front (inner class, drawing only).
class FrontLine:
	extends Control

	const DASH: float = 6.0
	const HEIGHT: float = 14.0

	func _init() -> void:
		custom_minimum_size = Vector2(0.0, HEIGHT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		draw_dashed_line(Vector2(0.0, y), Vector2(size.x, y), Tokens.BAD, 1.5, DASH)
