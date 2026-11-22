## Notification cards top right of the map (docs/architecture/m3-build-spec.md 6.6): up to four PanelCards, newest on top,
## each with a tone dot, the line's text (two lines at most), a Go button (the App looks at the hex and selects it; the
## card then goes) and a Close button. A card is dropped when two seasons have ended since it came. Fed by Events.chronicled
## lines with `notify` true (LogLines, for the player's own viewer). While a screen hides the world the host calls
## set_covered(true): the cards wait, hidden, and show again when it closes. It reads Session and Events and sends
## intents only; the App's TopRight column places it (Y18).
class_name Notifications
extends VBoxContainer

## The player asked to look at a card's hex (Go). The card is dismissed right after; the App looks and selects.
signal go_requested(hex: Vector2i)
## A card of one of the player's armies: its Go selects the army (and glides to it), not only the hex.
signal army_requested(army: int, hex: Vector2i)
## M7: a card of one of the player's battles (its Go opens the battle dock at the record), and a card of a declaration on the
## player (its Go opens the attacker's country panel).
signal battle_requested(record: int)
signal country_requested(tag: StringName)
## The card list changed: a card came, went or was cleared.
signal changed

const MAX_CARDS: int = 4
const SEASONS_TO_LIVE: int = 2
const CARD_WIDTH: int = 300
const TEXT_LINES: int = 2
const TONE_ICONS: Dictionary[StringName, StringName] = {
	&"good": &"tick",
	&"bad": &"cross",
	&"warn": &"lock",
	&"info": &"info",
	&"plain": &"dash",
	&"muted": &"dash",
}
const TONE_COLORS: Dictionary[StringName, StringName] = {
	&"good": &"NumberGood",
	&"bad": &"NumberBad",
	&"warn": &"NumberWarn",
	&"info": &"SectionHead",
	&"plain": &"SectionHead",
	&"muted": &"Hint",
}

var _cards: Array[Dictionary] = []  # newest first: {id, text, tone, hex, turn, seasons, node}
var _next_id: int = 1
var _covered: bool = false


func _ready() -> void:
	_sync_visible()


func _enter_tree() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = float(CARD_WIDTH)
	for pair: Array in _bus_links():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if not sig.is_connected(handler):
			sig.connect(handler)


func _exit_tree() -> void:
	for pair: Array in _bus_links():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)


func _bus_links() -> Array:
	return [
		[Events.chronicled, _on_chronicled],
		[Events.season_ended, _on_season_ended],
		[Events.game_started, _on_game_reset],
		[Events.game_ended, _on_game_reset],
	]


## Adds the card for a LogLines line when the line says `notify`. Returns its id, or -1 when no card was made. The
## fifth card drops the oldest.
func add_line(line: Dictionary) -> int:
	if line.is_empty() or not bool(line.get("notify", false)):
		return -1
	var hex: Vector2i = line.get("hex", WorksView.NO_HEX)
	var card := {
		"id": _next_id,
		"text": str(line.get("text", "")),
		"tone": StringName(str(line.get("tone", "plain"))),
		"hex": hex,
		"army": int(line.get("army", -1)),
		"record": int(line.get("record", -1)),
		"country": StringName(str(line.get("country", ""))),
		"turn": int(line.get("turn", 0)),
		"seasons": 0,
		"skip": 1,  # the season_ended of the season it came in is not counted: the count starts at the next one
		"node": null,
	}
	_next_id += 1
	card["node"] = _build_card(card)
	_cards.push_front(card)
	add_child(card["node"] as Control)
	move_child(card["node"] as Control, 0)
	while _cards.size() > MAX_CARDS:
		_drop_at(_cards.size() - 1)
	_sync_visible()
	changed.emit()
	return int(card["id"])


## The cards, newest first, as copies: {id, text, tone, hex, turn, seasons}.
func cards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for card: Dictionary in _cards:
		out.append({
			"id": card["id"], "text": card["text"], "tone": card["tone"], "hex": card["hex"],
			"army": card["army"], "record": card["record"], "country": card["country"],
			"turn": card["turn"], "seasons": card["seasons"],
		})
	return out


func card_count() -> int:
	return _cards.size()


## Removes a card without asking for its hex. False when there is no such card.
func dismiss(id: int) -> bool:
	for i: int in _cards.size():
		if int(_cards[i]["id"]) == id:
			_drop_at(i)
			_sync_visible()
			changed.emit()
			return true
	return false


## Go: emits go_requested with the card's hex (when it has one), then dismisses the card. False when there is no card.
func go(id: int) -> bool:
	for card: Dictionary in _cards:
		if int(card["id"]) == id:
			var hex: Vector2i = card["hex"]
			var army := int(card["army"])
			var record := int(card["record"])
			var country := card["country"] as StringName
			if record >= 0:
				battle_requested.emit(record)
			elif country != &"":
				country_requested.emit(country)
			elif army >= 0:
				army_requested.emit(army, hex)
			elif hex != WorksView.NO_HEX:
				go_requested.emit(hex)
			return dismiss(id)
	return false


func clear() -> void:
	while not _cards.is_empty():
		_drop_at(_cards.size() - 1)
	_sync_visible()
	changed.emit()


## A screen that hides the world is up (true) or closed (false). The cards stay and show again when it closes.
func set_covered(covered: bool) -> void:
	_covered = covered
	_sync_visible()


func is_covered() -> bool:
	return _covered


## The tone's icon and colour on a TextureRect (a dot in a card or a row): the Kit icon and the theme's font colour.
static func apply_tone(icon: TextureRect, tone: StringName) -> void:
	var icon_name: StringName = TONE_ICONS.get(tone, &"dash")
	icon.texture = icon.get_theme_icon(icon_name, &"Kit") if icon.has_theme_icon(icon_name, &"Kit") else null
	var color_type: StringName = TONE_COLORS.get(tone, &"SectionHead")
	icon.self_modulate = icon.get_theme_color(&"font_color", color_type) if icon.has_theme_color(&"font_color", color_type) \
			else Tokens.TEXT


func _on_chronicled(entry: Dictionary) -> void:
	var game := Session.game
	var viewer := Session.player_tag()
	if game == null or viewer == &"":
		return
	var line := LogLines.line_of(game, entry, viewer)
	if bool(line.get("mine", false)) and entry.has("army"):
		line["army"] = int(entry["army"])  # the player's army lines: Go selects the army
	if str(entry.get("kind", "")) == "war_declared":
		line["country"] = str(entry.get("tag", ""))  # a declaration on the player: Go opens the attacker's country panel
	add_line(line)


## Two seasons ended since a card came: it is dropped at the second season's end.
func _on_season_ended(_turn: int) -> void:
	var i := _cards.size() - 1
	var dropped := false
	while i >= 0:
		var card := _cards[i]
		if int(card["skip"]) > 0:
			card["skip"] = int(card["skip"]) - 1
			i -= 1
			continue
		card["seasons"] = int(card["seasons"]) + 1
		if int(card["seasons"]) >= SEASONS_TO_LIVE:
			_drop_at(i)
			dropped = true
		i -= 1
	if dropped:
		_sync_visible()
		changed.emit()


func _on_game_reset() -> void:
	clear()


func _drop_at(index: int) -> void:
	var node := _cards[index]["node"] as Control
	_cards.remove_at(index)
	if is_instance_valid(node):
		remove_child(node)
		node.queue_free()


func _sync_visible() -> void:
	visible = not _covered and not _cards.is_empty()


func _build_card(card: Dictionary) -> PanelContainer:
	var id := int(card["id"])
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelCard"
	panel.custom_minimum_size.x = float(CARD_WIDTH)
	panel.accessibility_name = str(card["text"])
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var dot := TextureRect.new()
	dot.custom_minimum_size = Vector2(16, 16)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)
	apply_tone(dot, card["tone"] as StringName)
	var body := Label.new()
	body.theme_type_variation = &"Body"
	body.text = str(card["text"])
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.max_lines_visible = TEXT_LINES
	body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(body)
	var can_go: bool = (card["hex"] as Vector2i) != WorksView.NO_HEX or int(card["army"]) >= 0 \
			or int(card["record"]) >= 0 or (card["country"] as StringName) != &""
	var go_button := Button.new()
	go_button.theme_type_variation = &"ButtonSmall"
	go_button.text = "Go"
	go_button.focus_mode = Control.FOCUS_NONE
	go_button.custom_minimum_size.y = float(Tokens.BUTTON_SM_H)
	go_button.disabled = not can_go
	go_button.tooltip_text = "Look at it on the map" if can_go else ""
	go_button.pressed.connect(func() -> void: go(id))
	row.add_child(go_button)
	var close_button := Button.new()
	close_button.theme_type_variation = &"ButtonSmall"
	close_button.text = "Close"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size.y = float(Tokens.BUTTON_SM_H)
	close_button.tooltip_text = "Dismiss this card"
	close_button.pressed.connect(func() -> void: dismiss(id))
	row.add_child(close_button)
	return panel
