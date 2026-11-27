## The tile window's pinned header (issue 436; split out of tile_window.gd in round 3; the owner's 540 banner design of
## 2026-11-26): the title bar (the settlement-type emblem at the left, the name centred, a drawn round close button), the sub line
## in three cells (the ground word and the hex at the left; the place and owner link in the middle, which takes the room left and
## ends in an ellipsis but is never hidden (H1); the tile's food a year at the right where the view has it), the chips (StripCells,
## TileView.strip_cells), and the short banner (SettlementPicture, Tokens.TILE_BANNER_H tall: the whole town scaled to the
## height, its sky and ground carried on to the width; the bare land, the sea, or terra incognita on a never discovered hex)
## with the badge row at its foot: the round badges (port, occupied, besieged, battle, armies) and the small icon buttons Show
## supply and Show the castle area (L3).
## It reads the view it is given and the game's colours; it changes nothing: the owner link, the close button and the two icon
## buttons are signals the window forwards.
class_name TileHeader
extends VBoxContainer

## The owner link was pressed (the owner's tag).
signal owner_pressed(tag: StringName)
## The close button was pressed.
signal close_pressed
## An App request of an icon button on the picture: &"map_mode" {mode} or &"castle_area" {hex}.
signal app_requested(what: StringName, args: Dictionary)

## The badge icons at the foot of the picture: their side and the inset from the picture's corner, in logical pixels.
const BADGE_ICON := Vector2(18, 18)
const BADGE_INSET := 6
## The Kit icon of a badge, by the start of its words; and of the harbour badge.
const BADGE_ICONS := {"Occupied": &"castle", "Besieged": &"walls", "Battle": &"army", "Enemy army": &"army",
	"Foreign army": &"army"}
const HARBOUR_ICON := &"port_dues"
## The picture's icon buttons (L3): their Kit icon and their tooltip.
const SUPPLY_ICON := &"supply_ok"
const CASTLE_ICON := &"area_held"
const SUPPLY_TIP := "Show supply\nThe map shows where your armies are fed."
const CASTLE_TIP := "Show the castle area\nThe map shows the land this castle holds."
## The close button's cross: half its arm in logical pixels and its stroke; drawn as two lines about the button's centre, so it
## sits exactly in the middle of the circle whatever the font (no glyph, no icon).
const CLOSE_ARM := 4.5
const CLOSE_STROKE := 2.0
## The one chip of a never discovered hex (M6).
const UNEXPLORED_CHIP := {"key": "unexplored", "value": "Unexplored", "label": "Unexplored", "tone": "plain", "muted": true}

var retired: Array[Node] = []

var _owner_tag: StringName = &""
var _hex: Vector2i = HexPanelContract.NO_HEX
var _title: Label
var _close: Button
var _ground: Label
var _place: Button
var _food: Label
var _strip: StripCells
var _strip_band: PanelContainer
var _picture: SettlementPicture
var _emblem: SettlementEmblem
var _badges: HBoxContainer
var _badge_band: PanelContainer


func _ready() -> void:
	_title = %Title
	_close = %Close
	_ground = %Subtitle
	_place = %Place
	_food = %Food
	_strip = %Strip
	_strip_band = %StripBand
	_picture = %Picture
	_badges = %Badges
	_badge_band = %BadgeBand
	_emblem = SettlementEmblem.new()
	_emblem.name = &"Emblem"
	_emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	(%Left as Control).add_child(_emblem)
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		(_badge_band.get_parent() as MarginContainer).add_theme_constant_override(side, BADGE_INSET)
	add_theme_constant_override(&"separation", 0)
	_badges.add_theme_constant_override(&"separation", Tokens.S1 + 1)
	_place.pressed.connect(func() -> void:
		if _owner_tag != &"":
			owner_pressed.emit(_owner_tag))
	_close.pressed.connect(func() -> void: close_pressed.emit())
	_close.draw.connect(_draw_close)
	_close.accessibility_name = "Close the tile window"
	for cell: Control in [_ground, _food]:
		cell.mouse_filter = Control.MOUSE_FILTER_PASS


## Shows the header of `view` (a TileView) for the hex; `cells` are the chips (TileView.strip_cells).
func show_view(game: Game, view: Dictionary, cells: Array) -> void:
	var head: Dictionary = view.get("header", {})
	var case_id := StringName(str(view.get("case", "")))
	_hex = view.get("hex", HexPanelContract.NO_HEX)
	_title.text = str(head.get("title", ""))
	_title.tooltip_text = _title.text
	var parts := str(head.get("subtitle", "")).split(" · ")
	# The left cell is the ground word and the hex ("Plain, (8, 10)"); at sea the depth chip says the water, so the hex alone (M2).
	var hex_words := parts[parts.size() - 1]
	var ground := parts[0].capitalize() if parts.size() > 1 and case_id != &"sea" else ""
	_ground.text = "%s, %s" % [ground, hex_words] if ground != "" else hex_words
	_ground.tooltip_text = ("The ground here: %s.
" % parts[0] if ground != "" else "") 		+ "Where this tile lies on the map (column, row)."
	_show_food(view.get("land", {}) as Dictionary)
	var owner: Dictionary = head.get("owner", {})
	_owner_tag = StringName(str(owner.get("tag", "")))
	var place := str(head.get("place", ""))
	_place.text = place
	_place.tooltip_text = place + ("\nOpen this country." if _owner_tag != &"" else "")
	_place.visible = place != ""
	_place.disabled = _owner_tag == &""
	var shown: Array = cells if case_id != &"unexplored" else [UNEXPLORED_CHIP]
	_strip.show_cells(shown)
	_strip_band.visible = _strip.visible
	var picture: Dictionary = head.get("picture", {})
	var land: Dictionary = view.get("land", {})
	_show_badges(head.get("badges", []), int(picture.get("harbour", 0)) > 0, bool(land.get("supply", false)),
		bool(land.get("castle_area", false)))
	var colour := _colour_of(game, StringName(str(picture.get("owner_tag", owner.get("tag", "")))))
	var snow := int(picture.get("climate", -1)) == HexCard.CLIMATE_WORDS.find("snow")
	if not picture.is_empty():
		var kind := StringName(str(picture.get("kind", "hamlet")))
		_picture.show_picture(kind, int(picture.get("level", 1)), int(picture.get("harbour", 0)), snow, colour)
		_emblem.show_kind(kind, int(picture.get("level", 1)))
	else:
		# No settlement: the bare land, the sea, or terra incognita (M6: a drawn hatch, not the word twice).
		var bare := SettlementPicture.LAND
		if case_id == &"sea":
			bare = SettlementPicture.SEA
		elif case_id == &"unexplored":
			bare = SettlementPicture.FOG
		_picture.show_picture(bare, 1, 0, snow, colour)
		_emblem.show_kind(&"", 0)


## The right cell of the sub line: the tile's food a year, made less eaten, in its tone ("Food +11"); empty where the view has
## no food (foreign land, the sea, an undiscovered hex).
func _show_food(land: Dictionary) -> void:
	var food: Dictionary = land.get("food", {})
	if food.is_empty():
		_food.text = ""
		_food.tooltip_text = "No food is made or eaten here."
		return
	var made := int(food.get("made", 0))
	var eaten := int(food.get("eaten", 0))
	var net := made - eaten
	_food.text = "Food %s" % Words.signed(net)
	_food.add_theme_color_override(&"font_color", Tokens.GOOD if net >= 0 else Tokens.BAD)
	_food.tooltip_text = "Food a year here: %s made, %s eaten." % [Words.number(made), Words.number(eaten)]


## The badges as round icons at the foot of the picture, each with its words as tooltip (a bad one rimmed in red); a port shows
## the harbour's icon first; then the icon buttons Show supply and Show the castle area where the view offers them.
func _show_badges(badges: Array, harbour: bool, supply: bool, castle: bool) -> void:
	PanelKit.clear_children(_badges, retired)
	var items: Array[Dictionary] = []
	if harbour:
		items.append({"text": "A port", "tone": "plain", "icon": HARBOUR_ICON})
	for raw: Variant in badges:
		var badge := (raw as Dictionary).duplicate()
		badge["icon"] = _badge_icon(str(badge.get("text", "")))
		items.append(badge)
	for badge: Dictionary in items:
		var disc := PanelContainer.new()
		var tone := StringName(str(badge.get("tone", "plain")))
		disc.theme_type_variation = &"PanelTileRoundBad" if tone == &"bad" else &"PanelTileRound"
		disc.tooltip_text = str(badge.get("text", ""))
		disc.mouse_filter = Control.MOUSE_FILTER_STOP
		disc.set_meta("text", disc.tooltip_text)
		disc.add_child(_icon(StringName(str(badge["icon"]))))
		_badges.add_child(disc)
	if supply:
		_badges.add_child(_icon_button(&"SupplyButton", SUPPLY_ICON, SUPPLY_TIP,
			func() -> void: app_requested.emit(&"map_mode", {"mode": &"supply"})))
	if castle:
		var hex := _hex
		_badges.add_child(_icon_button(&"CastleButton", CASTLE_ICON, CASTLE_TIP,
			func() -> void: app_requested.emit(&"castle_area", {"hex": hex})))
	_badge_band.visible = _badges.get_child_count() > 0


func _icon(icon_name: StringName) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = BADGE_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_theme_icon(icon_name, &"Kit"):
		icon.texture = get_theme_icon(icon_name, &"Kit")
	return icon


func _icon_button(node_name: StringName, icon_name: StringName, tip: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.theme_type_variation = &"ButtonTileBadge"
	button.tooltip_text = tip
	button.accessibility_name = tip.get_slice("\n", 0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	if has_theme_icon(icon_name, &"Kit"):
		button.icon = get_theme_icon(icon_name, &"Kit")
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = BADGE_ICON + Vector2(10, 10)
	button.pressed.connect(on_press)
	return button


## The words of the badges shown (tests read them, in order); the icon buttons are not badges.
func badge_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for child: Node in _badges.get_children():
		if child.has_meta("text"):
			out.append(str(child.get_meta("text", "")))
	return out


## The icon button of the picture by its name (&"SupplyButton", &"CastleButton"), or null (tests).
func icon_button(node_name: StringName) -> Button:
	return _badges.get_node_or_null(NodePath(String(node_name))) as Button


## The emblem (tests).
func emblem() -> SettlementEmblem:
	return _emblem


static func _badge_icon(text: String) -> StringName:
	for start: String in BADGE_ICONS:
		if text.begins_with(start):
			return BADGE_ICONS[start]
	return &"warning"


func _draw_close() -> void:
	var colour := _close.get_theme_color(&"font_hover_color" if _close.is_hovered() else &"font_color")
	var rect := close_glyph_rect()
	_close.draw_line(rect.position, rect.end, colour, CLOSE_STROKE, true)
	_close.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), colour, CLOSE_STROKE, true)


## The close cross's box in the button's own coordinates: centred on the button (tests check it).
func close_glyph_rect() -> Rect2:
	var centre := _close.size * 0.5
	return Rect2(centre - Vector2(CLOSE_ARM, CLOSE_ARM), Vector2(CLOSE_ARM, CLOSE_ARM) * 2.0)


func _colour_of(game: Game, tag: StringName) -> Color:
	var cdef: CountryDef = Countries.def_of(game, tag) if tag != &"" and game != null else null
	if cdef == null:
		return Tokens.MUTED
	return cdef.colour
