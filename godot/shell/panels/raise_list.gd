## The Raise tab of the hex panel (docs/architecture/m6-build-spec.md 6.8; L19, issue #209). On a settlement of yours the panel's
## Works | Raise segment shows this list: a head line ("Men at hand: 6,300 · 1 of 2 companies raised this season") and a row per
## kind of company (Military.raise_options): the figure, the name, "500 men · 12 move points", a KitButton "Raise" with the cost
## text ("25 · 1 iron") and its verdict. A refused row shows its reason under it (and as the button's tooltip). A click raises
## one company through Session.act("raise"); the army_raised event then refreshes the panel (the hex panel calls show_hex
## on every refresh). The list reads the game; it changes it only through Session.
class_name RaiseList
extends VBoxContainer

const FIGURE_PX := 32
const NO_HEX := Vector2i(-1, -1)
## A toast for the player: the raise's words, or the refusal's reason (the tone says which).
signal toast_requested(text: String, tone: StringName)

var _hex := NO_HEX
var _head: Label = null
var _rows: VBoxContainer = null
var _retired: Array[Node] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head = PanelKit.label("", &"Hint")
	_head.name = &"Head"
	_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_head)
	_rows = VBoxContainer.new()
	_rows.name = &"Rows"
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)


## The Raise tab is offered on a settlement of the player's own land, in a game with countries: the one rule the hex
## panel and the hex menu share.
static func offered(game: Game, tag: StringName, hex: Vector2i) -> bool:
	if game == null or game.map == null or game.state == null or tag == &"" or not game.has_countries():
		return false
	if not game.map.has(hex) or not game.map.is_land(hex):
		return false
	if Territory.owner_tag(game, hex) != tag:
		return false
	return int(game.state.main_use[game.map.index_of(hex)]) == Economy.SETTLEMENTS


## Shows the list for `hex` (the hex panel calls it on each refresh while the tab is open).
func show_hex(hex: Vector2i) -> void:
	_hex = hex
	refresh()


func shown_hex() -> Vector2i:
	return _hex


## Rebuilds the head line and one row a kind. Hidden when the hex is not one the tab is offered on.
func refresh() -> void:
	var game := Session.game
	var tag := Session.player_tag()
	PanelKit.clear_children(_rows, _retired)
	if not offered(game, tag, _hex):
		visible = false
		_head.text = ""
		return
	visible = true
	var raised := Military.raised_here(game, tag, _hex)
	var cap := Military.raise_cap(game, _hex)
	_head.text = "Men at hand: %s · %d of %d companies raised this season" % [
		Words.number(Military.men_at_hand(game, tag, _hex)), raised, cap]
	for row: Dictionary in Military.raise_options(game, tag, _hex):
		_rows.add_child(_row(row))


## One kind: the figure, the name and the men and move points, the Raise button with its cost and verdict, and the reason.
func _row(row: Dictionary) -> Control:
	var game := Session.game
	var kind := int(row["kind"])
	var ud := Military.unit_def(game, kind)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)
	var fig := TextureRect.new()
	fig.custom_minimum_size = Vector2(FIGURE_PX, FIGURE_PX)
	fig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fig.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ud != null and fig.has_theme_icon(ud.figure, &"Kit"):
		fig.texture = fig.get_theme_icon(ud.figure, &"Kit")
	line.add_child(fig)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(PanelKit.label(str(row["name"]), &"TableRow"))
	text.add_child(PanelKit.label("%s men · %d move points" % [Words.number(int(row["men"])), int(row["mp"])], &"Hint"))
	line.add_child(text)
	var verdict: Dictionary = row["verdict"]
	var button := KitButton.new()
	button.kind = KitButton.Kind.SECONDARY
	button.text = "Raise"
	button.cost_text = str(row["cost_text"])
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.accessibility_name = "Raise one %s" % str(row["name"])
	button.set_verdict(verdict)
	button.pressed.connect(_on_raise_pressed.bind(kind))
	box.add_child(button)
	if not bool(verdict["ok"]):
		box.add_child(PanelKit.reason(str(verdict["reason"])))
	return box


## A click raises one company of the kind: Session.act checks again and does it, or refuses with its words.
func _on_raise_pressed(kind: int) -> void:
	var words := raised_text(Session.game, kind, _hex)
	var verdict := Session.act("raise", {"hex": _hex, "kind": kind, "count": 1})
	if bool(verdict.get("ok", false)):
		toast_requested.emit(words, &"plain")
	else:
		toast_requested.emit(str(verdict.get("reason", "")), &"warn")


## The toast of one company raised (before the act): "Raised 1 company of pikemen at Turin (5, 9): −25 ducats, −1 iron."
static func raised_text(game: Game, kind: int, hex: Vector2i) -> String:
	var ud := Military.unit_def(game, kind)
	var cost := Military.cost_of(game, kind, 1)
	var parts: Array[String] = ["−%d ducats" % int(cost["ducats"])]
	for gid: int in game.defs.goods.size():
		var good := game.defs.good(gid)
		var key := String(good.key)
		if (cost["goods"] as Dictionary).has(key):
			parts.append("−%d %s" % [int(cost["goods"][key]), good.name.to_lower()])
	return "Raised 1 company of %s at %s: %s." % [ud.name.to_lower(), Military.hex_text(game, hex), ", ".join(parts)]


## The Raise buttons in display order (for the tests and the keyboard path).
func raise_buttons() -> Array[KitButton]:
	var out: Array[KitButton] = []
	for box: Node in _rows.get_children():
		for child: Node in box.get_children():
			if child is KitButton:
				out.append(child as KitButton)
	return out


## The reason lines under the refused rows, in display order.
func reason_labels() -> Array[Label]:
	var out: Array[Label] = []
	for box: Node in _rows.get_children():
		for child: Node in box.get_children():
			if child is Label and (child as Label).theme_type_variation == &"Reason":
				out.append(child as Label)
	return out


func _exit_tree() -> void:
	PanelKit.free_retired(_retired)
