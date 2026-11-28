## The parchment map's names, dots and goods icons, laid out in screen space (docs/architecture/map-overview-build-spec.md
## R7 to R13, R27, D1, D7). The node stands in the world just over the parchment (z ParchmentMap.LAYER_Z, after it in the
## tree), so reach, paths, army tokens and war marks are drawn over its names; it draws through the view's inverse
## transform, so the screen px of the layout land on the screen. The facts are ParchmentView's, already masked by the fog
## for the viewer, who is Game.player as it stands each time they are read (as ParchmentMap does it; "" in the country
## pick sees all). They are read when the data changes (setup, refresh, a new player or discovery, the Goods mode), never
## when only the view moves, and while the alpha is 0 they are only marked stale. A layout runs on relayout (a new view),
## on a data, mode, good, look or cover change, and at no other time; while the alpha is 0 it waits. Only what is on
## screen is laid out.
##
## A Node2D, never a Control: the renderer culls a Node2D by what it draws, while a Control hands it (0, 0, its size) at
## every redraw, which here dropped the whole layer once the map's point (0, 0) left the screen.
##
## Placing order (R10): capitals (dot, then the name below it, else above it), country names, goods icons (on their
## hex, in the first free spot; a district with none then takes a spot over a country name, as icons draw above names,
## but never over another icon, a dot, a capital's name or a HUD cover rect), towns by level then name (a name that
## meets anything placed or a cover rect is dropped, its dot stays).
##
## A country name is turned along its region and letter-spaced; in Goods mode it is see-through (NAME_ALPHA; never in
## high contrast). A capital's dot and name are a hard obstacle (ParchmentCapitalRoom): a name never lies on them. To
## clear them it first slides along its normal by up to one line; else the names of the capitals in its way go to the
## other side of their dots; else it moves farther, along its normal and its line, on its own known land; else it tries
## the same smaller (NAME_CLEAR_SIZES); else every step down to NAME_MIN_PX, the nearest places beside the capitals too;
## else it is left out and its capital's name stands for it. Where it can it keeps clear of the HUD's cover rects and of
## the goods icons' own spots too, moving past them on its known land: it gives up the icons first, and stays under a
## cover only when no spot on its land is clear of it. A name that would still be left out is searched for once more with
## the icons' spots given up altogether (a capital's name may then move onto one).
##
## A country name is never longer than its room (D7) nor under MIN size: where it cannot be both, it is left out. No
## name or icon box lies on a hex the viewer has not discovered: a country name shrinks or slides to keep off one, any
## other name is dropped.
##
## MapSceneParchment calls: setup(game) with each game; refresh() after owners, works or a season changed the state;
## set_mode, set_good, set_options and set_cover as they change; set_alpha with ParchmentMap.apply_zoom's result (0
## outside Terrain, Owner and Goods, and during the pick); relayout on CameraRig.view_changed with the map-to-screen
## transform.
class_name ParchmentLabels
extends Node2D

const KIND_COUNTRY := &"country"
const KIND_CAPITAL := &"capital"
const KIND_TOWN := &"town"
const KIND_ICON := &"icon"
## Country names (R8): NAME_PX_PER_ROOT_HEX x sqrt(hexes) at a hex NAME_REF_HEX_PX wide on screen, within the two
## sizes, times the text size. A room that is short takes the name down to NAME_MIN_PX, and no further.
const NAME_PX_PER_ROOT_HEX := 8.0
const NAME_REF_HEX_PX := 58.0
const NAME_MIN_PX := 14
const NAME_MAX_PX := 48
## A name with no spot at the sizes of NAME_CLEAR_SIZES is tried at every step of this share of its size down to the
## least.
const NAME_SHRINK := 0.85
## The shares of its size a name is tried at to clear the capitals, largest first (never under NAME_MIN_PX).
const NAME_CLEAR_SIZES: Array[float] = [1.0, 0.75, 0.5]
## A country name's letter spacing as a share of its size (it counts in the fitted width), and its opacity in Goods mode.
const NAME_SPACING_EM := 0.08
const NAME_ALPHA := 0.82
## A country name's box is NAME_BOX_EM of its size high.
const NAME_BOX_EM := 1.0
## The detail steps of R9, by the hex's width on screen (px).
const TOWN_VIEW_PX := 24.0
const TOWN_VIEW_FULL_PX := 28.0
const ICON_VIEW_PX := 16.0
## Town and capital names (R27): the size by level (levels 3, 4, 5 and more), and a capital's; the box and baseline.
const TOWN_FONT_PX: Array[int] = [13, 15, 17]
const CAPITAL_FONT_PX := 17
const TOWN_BOX_EM := 1.2
## Dots (screen px): a town's radius is TOWN_DOT_BASE_PX plus its level; a capital grows from the far view's to the
## town view's. None is wider than DOT_HEX_SHARE of the hex each way (but never under DOT_MIN_PX).
const TOWN_DOT_BASE_PX := 1.5
const CAPITAL_DOT_PX := 7.0
const FAR_CAPITAL_DOT_PX := 5.0
const DOT_HEX_SHARE := 0.45
const DOT_MIN_PX := 2.0
const NAME_GAP_PX := 1.5
## Goods icons (R7; ParchmentIconSpots places them): the pips' radius as a share of the disc's; the pips' row lies just
## under the disc.
const PIP_SHARE := 0.15
const PIP_MIN_PX := 1.2
const PIP_GAP_PX := 1.0
## How far outside the screen a town or an icon is still laid out (screen px).
const SCREEN_MARGIN_PX := 120.0

## Count of layouts (tests: it does not move while nothing changes).
var layout_count := 0
## Count of readings of the facts (tests: none while the names are hidden).
var fact_reads := 0

var _game: Game = null
var _viewer: StringName = &""
var _mode: int = MapModes.Mode.TERRAIN
var _good := -1
var _alpha := 1.0
var _text_scale := 1.0
var _high_contrast := false
var _cover: Array[Rect2] = []
var _xform := Transform2D.IDENTITY
var _zoom := 1.0
var _viewport := Vector2.ZERO
var _has_view := false
var _dirty := true
# The facts, as read when the data last changed.
var _owners := PackedByteArray()  # ParchmentView.owner_bytes
var _fogged := false  # some hex is undiscovered
var _names: Array[Dictionary] = []  # ParchmentView.country_names, each with its country's id
var _towns: Array[Dictionary] = []  # ParchmentView.towns, in placing order
var _town_rows: Dictionary[int, Array] = {}  # row -> indices into _towns
var _goods := PackedByteArray()  # ParchmentView.goods_bytes, read in Goods mode only
var _icon_names: Dictionary[int, StringName] = {}  # good id -> Kit icon
var _fog_key: Array = []  # MapModes.discovered_key the facts were read at (as ParchmentMap watches it)
var _seen := PackedByteArray()  # the discovered bytes under that key
var _stale := false  # the facts are to be read before the next layout that shows
# The layout.
var _placed: Array[Dictionary] = []
var _space := ParchmentLabelSpace.new()  # what is placed, as boxes
var _dots: Dictionary[Vector2i, float] = {}  # hex -> the radius of the dot placed on it
var _name_blocks: Dictionary[Vector2i, int] = {}  # hex -> the block of the name placed at its town
var _icon_boxes: Array[Rect2] = []  # where each icon would lie with no country name in its way
var _avoid: Array[Rect2] = []  # the boxes the country name being placed is to keep off
var _room := ParchmentCapitalRoom.new(_space, _name_blocks, _name_box, _may_name, _give_name)
var _widths: Dictionary[String, float] = {}  # "size name" -> text width with its halo
var _colours := ParchmentTokens.colours(false)
var _name_fonts: Dictionary[int, Font] = {}  # letter spacing (px) -> the country names' font
var _town_font: Font = _font("alegreya_italic")
var _icon_theme: Theme = null


func _init() -> void:
	z_index = ParchmentMap.LAYER_Z


## The facts of `game` as its player knows it; null clears. Lays out if a view is known. With `read_now` false the facts
## wait until the names are first shown.
func setup(game: Game, read_now: bool = true) -> void:
	_game = game
	_widths.clear()
	_forget_facts()
	_stale = true
	if read_now:
		_read_facts()
	_relayout()


## Reads the facts again (the player, owners, discovery, works or levels changed) and lays out again; while the names are
## hidden it only marks them stale. Not for a view change: after an ownership change the country names alone take
## milliseconds.
func refresh() -> void:
	_stale = true
	_relayout()


func set_mode(mode: int) -> void:
	if mode == _mode:
		return
	_mode = mode
	if mode == MapModes.Mode.GOODS and not _stale:
		_read_goods()
	_relayout()


## The good whose districts carry icons in Goods mode.
func set_good(good_id: int) -> void:
	if good_id == _good:
		return
	_good = good_id
	if _mode == MapModes.Mode.GOODS:
		_relayout()


## The parchment's alpha (ParchmentMap.apply_zoom): the labels fade with it; at 0 they are hidden and not laid out.
func set_alpha(a: float) -> void:
	_alpha = clampf(a, 0.0, 1.0)
	modulate.a = _alpha
	visible = _alpha > 0.0
	if visible and (_dirty or _stale):
		_relayout()


## `text_size_percent` is accessibility/text_size (100 to 150); `high_contrast` takes the darker ink.
func set_options(text_size_percent: int, high_contrast: bool) -> void:
	var scale_to := float(text_size_percent) / 100.0
	if is_equal_approx(scale_to, _text_scale) and high_contrast == _high_contrast:
		return
	_text_scale = scale_to
	_high_contrast = high_contrast
	_colours = ParchmentTokens.colours(high_contrast)
	_relayout()


## The HUD's covering rects in screen px (Hud.cover_rects): no town name or icon goes under them, and a country name
## keeps off them where its land has room.
func set_cover(rects: Array[Rect2]) -> void:
	if rects == _cover:
		return
	_cover = rects.duplicate()
	_relayout()


## Lays out for a view: `xform` carries map px to screen px, `zoom` is the camera's, `viewport` the screen's size.
## The same view again does nothing.
func relayout(xform: Transform2D, zoom: float, viewport: Vector2) -> void:
	if _has_view and not _dirty and xform == _xform and zoom == _zoom and viewport == _viewport:
		return
	_xform = xform
	_zoom = zoom
	_viewport = viewport
	_has_view = true
	_relayout()


## What is placed, in placing order: {kind: country|capital|town|icon, hex, text, rect (its bounds, screen px), angle
## (degrees, clockwise on screen), size (font px; an icon: the disc's width)}. A capital or town with no name shown has
## text "", size 0 and its dot's box as rect. More keys: dot and dot_radius (capital, town); name_alpha (the town
## view's fade, capital and town); tag, centre, extent (a country name's unturned box); centre, radius, stage, icon
## (icon).
func placed() -> Array[Dictionary]:
	return _placed


## The town view's fade (R9): 0 for a hex under TOWN_VIEW_PX wide, 1 from TOWN_VIEW_FULL_PX.
static func town_fade(hex_px: float) -> float:
	return clampf((hex_px - TOWN_VIEW_PX) / (TOWN_VIEW_FULL_PX - TOWN_VIEW_PX), 0.0, 1.0)


## The size a country name wants (R8) for a region of `hexes` on hexes `hex_px` wide, before its room is looked at.
static func wanted_name_px(hexes: int, hex_px: float, text_scale: float) -> int:
	var by_area := NAME_PX_PER_ROOT_HEX * sqrt(float(hexes)) * hex_px / NAME_REF_HEX_PX
	return roundi(clampf(by_area, NAME_MIN_PX, NAME_MAX_PX) * text_scale)


## The size of a town's name (R27): by level, a capital's the largest, times the text size.
static func town_name_px(level: int, capital: bool, text_scale: float) -> int:
	var px := CAPITAL_FONT_PX
	if not capital:
		px = TOWN_FONT_PX[clampi(level - ParchmentView.TOWN_NAME_LEVEL, 0, TOWN_FONT_PX.size() - 1)]
	return roundi(float(px) * text_scale)


static func _font(key: String) -> FontVariation:
	var out := FontVariation.new()
	out.base_font = load(Tokens.FONTS[key]) as Font
	var fallbacks: Array[Font] = [load(Tokens.FONTS["fallback"]) as Font]
	out.fallbacks = fallbacks
	return out


## A new player or another discovered set reads the facts again: the key ParchmentMap watches, then its bytes (the
## sight moves far more often than what is discovered).
func _process(_delta: float) -> void:
	if _game == null or _stale or _game.map == null or _game.state == null:
		return
	var viewer := _viewer_now()
	var key := MapModes.discovered_key(_game, viewer)
	if viewer == _viewer and key == _fog_key:
		return
	if viewer == _viewer and MapModes.discovered_bytes(_game, viewer) == _seen:
		_fog_key = key
		return
	refresh()


## Whose knowledge the labels show: the game's player, "" (all) before one is chosen.
func _viewer_now() -> StringName:
	return _game.player if _game != null else &""


func _forget_facts() -> void:
	_viewer = _viewer_now()
	_fog_key = []
	_seen = PackedByteArray()
	_owners = PackedByteArray()
	_fogged = false
	_names.clear()
	_towns.clear()
	_town_rows.clear()
	_goods = PackedByteArray()
	_icon_names.clear()


func _read_facts() -> void:
	_forget_facts()
	_stale = false
	if _game == null or _game.map == null or _game.state == null:
		return
	fact_reads += 1
	_fog_key = MapModes.discovered_key(_game, _viewer)
	_seen = MapModes.discovered_bytes(_game, _viewer)
	_owners = ParchmentView.owner_bytes(_game, _viewer)
	_fogged = _owners.has(ParchmentView.UNKNOWN)
	_names = ParchmentView.country_names(_game, _viewer)
	for entry: Dictionary in _names:
		entry["id"] = Countries.by_tag(_game, entry["tag"]).id
	_towns = ParchmentView.towns(_game, _viewer)
	for i: int in _towns.size():
		var row: int = (_towns[i]["hex"] as Vector2i).y
		if not _town_rows.has(row):
			_town_rows[row] = []
		_town_rows[row].append(i)
	for good: Dictionary in ParchmentView.goods_list(_game):
		_icon_names[int(good["id"])] = good["icon"]
	if _mode == MapModes.Mode.GOODS:
		_read_goods()


func _read_goods() -> void:
	if _game != null and _game.map != null and _game.state != null:
		_goods = ParchmentView.goods_bytes(_game, _viewer)


func _relayout() -> void:
	if _stale and _alpha > 0.0:
		_read_facts()
	_placed.clear()
	_space.clear(_viewport)
	_dots.clear()
	_name_blocks.clear()
	_icon_boxes.clear()
	queue_redraw()
	_dirty = not _has_view or _alpha <= 0.0 or _stale
	if _dirty:
		return
	layout_count += 1
	if _game == null or _game.map == null or _zoom <= 0.0:
		return
	var hex_px := _zoom * float(MapTiles.CELL.x)
	var fade := town_fade(hex_px)
	var town_view := hex_px >= TOWN_VIEW_PX
	var seen := _visible_towns()
	var capitals: Array[Dictionary] = []
	var others: Array[Dictionary] = []
	# Every dot first: they always show, and the names and icons keep off them.
	for town: Dictionary in seen:
		if bool(town["capital"]):
			capitals.append(_dot_entry(town, hex_px, fade))
		elif town_view:
			others.append(_dot_entry(town, hex_px, fade))
	for entry: Dictionary in capitals:
		_add_block(entry["rect"])
	if town_view:
		for entry: Dictionary in capitals:
			_name_capital(entry)
	_placed.append_array(capitals)
	var districts: Array[Vector3i] = []
	if _mode == MapModes.Mode.GOODS and hex_px >= ICON_VIEW_PX:
		districts = _seen_districts()
	for district: Vector3i in districts:
		var box := _icon_spot(Vector2i(district.x, district.y), hex_px, false)
		if box.has_area():
			_icon_boxes.append(box)
	_place_country_names(hex_px, capitals)
	_icon_boxes.clear()  # the icons take their spots now
	for entry: Dictionary in others:
		_add_block(entry["rect"])
	_place_icons(districts, hex_px)
	for entry: Dictionary in others:
		_name_town(entry)
		_placed.append(entry)


## The screen and its margin, in map px.
func _seen_area() -> Rect2:
	var screen := Rect2(Vector2.ZERO, _viewport).grow(SCREEN_MARGIN_PX)
	return _xform.affine_inverse() * screen


## The towns near the screen, in placing order.
func _visible_towns() -> Array[Dictionary]:
	var area := _seen_area()
	var first := floori((area.position.y - 51.0) / MapTiles.ROW)
	var last := ceili((area.end.y - 51.0) / MapTiles.ROW)
	var found := PackedInt32Array()
	for row: int in range(maxi(first, 0), mini(last + 1, _game.map.rows)):
		for i: int in _town_rows.get(row, []):
			if area.has_point(_towns[i]["at"]):
				found.append(i)
	found.sort()
	var out: Array[Dictionary] = []
	for i: int in found:
		out.append(_towns[i])
	return out


# ----- capitals and towns --------------------------------------------------------------------------------------------


## The entry of a town with its dot and no name yet.
func _dot_entry(town: Dictionary, hex_px: float, fade: float) -> Dictionary:
	var capital := bool(town["capital"])
	var radius := lerpf(FAR_CAPITAL_DOT_PX, CAPITAL_DOT_PX, fade) if capital \
		else TOWN_DOT_BASE_PX + float(town["level"])
	radius = minf(radius, maxf(DOT_MIN_PX, DOT_HEX_SHARE * hex_px))
	var dot: Vector2 = _xform * (town["at"] as Vector2)
	_dots[town["hex"]] = radius
	return {"kind": KIND_CAPITAL if capital else KIND_TOWN, "hex": town["hex"], "text": "",
		"rect": ParchmentCapitalRoom.dot_box(dot, radius), "angle": 0.0, "size": 0, "dot": dot, "dot_radius": radius,
		"name_alpha": fade, "name": town["name"], "level": town["level"]}


## The box of a name of `entry` at the size `px`, below its dot or above it.
func _name_box(entry: Dictionary, px: int, above: bool) -> Rect2:
	var size := Vector2(_text_width(_town_font, str(entry["name"]), px), TOWN_BOX_EM * px + ParchmentTokens.HALO_PX)
	var dot: Vector2 = entry["dot"]
	var gap := float(entry["dot_radius"]) + NAME_GAP_PX
	var top := dot.y - gap - size.y if above else dot.y + gap
	return Rect2(Vector2(dot.x - size.x * 0.5, top), size)


## A capital's name: below its dot, else above it, else none.
func _name_capital(entry: Dictionary) -> void:
	if str(entry["name"]) == "":
		return
	var px := town_name_px(entry["level"], true, _text_scale)
	for above: bool in [false, true]:
		var box := _name_box(entry, px, above)
		if _may_name(box):
			_give_name(entry, box, px)
			return


## A town's name (level TOWN_NAME_LEVEL or more): below its dot, or dropped.
func _name_town(entry: Dictionary) -> void:
	if int(entry["level"]) < ParchmentView.TOWN_NAME_LEVEL or str(entry["name"]) == "":
		return
	var px := town_name_px(entry["level"], false, _text_scale)
	var box := _name_box(entry, px, false)
	if _may_name(box):
		_give_name(entry, box, px)


## Whether a capital's or a town's name may lie in `box`; while the country names are placed, never on an icon's spot
## that is still held (_put_over_icons).
func _may_name(box: Rect2) -> bool:
	return not _is_blocked(box) and not ParchmentNameSpots.hits(_icon_boxes, box.get_center(), Vector2.RIGHT,
		box.size * 0.5) and not _on_unknown(box.get_center(), Vector2.RIGHT, box.size * 0.5)


func _give_name(entry: Dictionary, box: Rect2, px: int) -> void:
	entry["text"] = entry["name"]
	entry["rect"] = box
	entry["size"] = px
	_name_blocks[entry["hex"]] = _space.size()
	_add_block(box)


# ----- the country names ---------------------------------------------------------------------------------------------


func _place_country_names(hex_px: float, capitals: Array[Dictionary]) -> void:
	var screen := Rect2(Vector2.ZERO, _viewport)
	_room.begin(capitals)
	for name: Dictionary in _names:
		var centre: Vector2 = _xform * (name["at"] as Vector2)
		var room := float(name["span_px"]) * _zoom
		if not screen.grow(room + NAME_MAX_PX * 4.0 * _text_scale).has_point(centre):
			continue
		var text := str(name["text"])
		var px := _fit_name_px(text, wanted_name_px(name["hexes"], hex_px, _text_scale), room)
		if px < NAME_MIN_PX:
			continue
		# With larger text the size the name fits at 100 % is tried too, before any smaller one.
		var plain := px if _text_scale <= 1.0 else _fit_name_px(text, wanted_name_px(name["hexes"], hex_px, 1.0), room)
		var sizes := ParchmentNameSpots.sizes(px, plain, NAME_CLEAR_SIZES, NAME_MIN_PX)
		if not _put_name(name, centre, sizes, capitals) and not _put_last(name, centre, sizes, capitals):
			_put_over_icons(name, centre, sizes, capitals)  # with no spot even so the country is left unnamed


## The country names' font at the size `px`: its letters spaced by NAME_SPACING_EM.
func _name_face(px: int) -> Font:
	var spacing := roundi(NAME_SPACING_EM * px)
	if not _name_fonts.has(spacing):
		var face := _font("alegreya_sc_bold")
		face.spacing_glyph = spacing
		_name_fonts[spacing] = face
	return _name_fonts[spacing]


## The largest size up to `wanted` at which the name is no longer than `room`; under NAME_MIN_PX when none is.
func _fit_name_px(text: String, wanted: int, room: float) -> int:
	var width := _text_width(_name_face(wanted), text, wanted)
	if width <= room:
		return wanted
	var halo := float(ParchmentTokens.HALO_PX)
	var px := mini(wanted - 1, floori(float(wanted) * (room - halo) / (width - halo)) + 2)
	while px >= NAME_MIN_PX and _text_width(_name_face(px), text, px) > room:
		px -= 1
	return px


## Places the name clear of the capitals, and where its land has room clear of the HUD's cover rects and the goods
## icons' spots too. At its full size (`sizes`[0]) it first tries clear of all three. To get out from under a cover it
## may shrink as it does for a capital, giving up the icons. It never shrinks for an icon: only its full size is moved
## off one. False, with nothing changed, when no spot clears the capitals.
func _put_name(name: Dictionary, centre: Vector2, sizes: Array[int], capitals: Array[Dictionary]) -> bool:
	var half := _name_shape(name, sizes[0])[1]
	var cover := ParchmentNameSpots.boxes_near(_cover, centre, half)
	var icons := ParchmentNameSpots.boxes_near(_icon_boxes, centre, half)
	var done := false
	if not icons.is_empty() and not cover.is_empty():
		_avoid = cover + icons
		done = _put_clear(name, centre, [sizes[0]], capitals)
	if not done and not cover.is_empty():
		_avoid = cover
		done = _put_clear(name, centre, sizes, capitals)
	if not done and not icons.is_empty():
		_avoid = icons
		done = _put_clear(name, centre, [sizes[0]], capitals)
	_avoid = []
	return done or _put_clear(name, centre, sizes, capitals)


## The last search, for a name that _put_name found no spot for: every step from its size down to NAME_MIN_PX, with the
## nearest places beside the capitals too (the sizes of `tried` have had every other place); clear of the HUD's cover
## rects first, then under them.
func _put_last(name: Dictionary, centre: Vector2, tried: Array[int], capitals: Array[Dictionary]) -> bool:
	var steps := ParchmentNameSpots.steps(tried[0], NAME_SHRINK, NAME_MIN_PX)
	var cover := ParchmentNameSpots.boxes_near(_cover, centre, _name_shape(name, tried[0])[1])
	var done := false
	if not cover.is_empty():
		_avoid = cover
		done = _put_clear(name, centre, steps, capitals, tried)
		_avoid = []
	return done or _put_clear(name, centre, steps, capitals, tried)


## Both searches again with the icons' spots given up altogether, so that a capital's name too may move onto one to make
## room (_may_name refuses it while they are held). The spots are held again for the names that follow.
func _put_over_icons(name: Dictionary, centre: Vector2, sizes: Array[int], capitals: Array[Dictionary]) -> void:
	if _icon_boxes.is_empty():
		return  # the searches so far had nothing to give up
	var held := _icon_boxes
	_icon_boxes = []
	if not _put_name(name, centre, sizes, capitals):
		_put_last(name, centre, sizes, capitals)
	_icon_boxes = held


## Places the name clear of every capital and of the boxes to avoid, at the first of `sizes` (largest first) that has a
## spot: at each size the first of a slide of R10; a slide of R10 whose capitals' names can go to the other side of their
## dots; a farther place; a farther place with such names moved; and the same for the places just past a box to avoid.
## With `tried` (the last search) the places beside the capitals follow, and they are all that a size of `tried` gets.
## A moved name is on its region and no spot is on unexplored paper. False, with nothing changed, when no size has such a
## spot.
func _put_clear(name: Dictionary, centre: Vector2, sizes: Array[int], capitals: Array[Dictionary],
		tried: Array[int] = []) -> bool:
	var reach := _name_shape(name, sizes[0])[1]
	var near := _room.near(centre, reach)
	var taken := ParchmentCapitalRoom.taken_by(near)
	var stages := ParchmentNameSpots.STAGES + int(not tried.is_empty())
	var before := 0
	for size_px: int in sizes:
		if size_px == before:
			continue
		before = size_px
		var shape := _name_shape(name, size_px)
		var screen := Rect2(Vector2.ZERO, _viewport)
		for stage: int in range(ParchmentNameSpots.STAGES if tried.has(size_px) else 0, stages):
			var spots := ParchmentNameSpots.stage(stage, centre, shape, _avoid, screen) \
				if stage < ParchmentNameSpots.STAGES \
				else ParchmentCapitalRoom.last_places(near, centre, shape, screen, float(name["span_px"]) * _zoom)
			var with_moves: Array[Vector2] = []  # the middles that need capitals' names moved
			for at: Vector2 in spots:
				if ParchmentNameSpots.hits(_avoid, at, shape[0], shape[1]):
					continue  # the cheapest of the checks, first
				var need := _room.need_at(taken, at, shape[0], shape[1])
				if need == ParchmentCapitalRoom.Need.MOVES:
					with_moves.append(at)
				elif need == ParchmentCapitalRoom.Need.NOTHING and _may_stand(name, centre, at, shape[0], shape[1]) \
						and ParchmentCapitalRoom.far_clear(capitals, centre, reach, at, shape[0], shape[1]):
					_give_country(name, at, shape[0], shape[1], size_px)
					return true
			for at: Vector2 in with_moves:
				if _may_stand(name, centre, at, shape[0], shape[1]) \
						and ParchmentCapitalRoom.far_clear(capitals, centre, reach, at, shape[0], shape[1]) \
						and _room.move_names(near, at, shape[0], shape[1]):
					_give_country(name, at, shape[0], shape[1], size_px)
					return true
	return false


## [the long axis (a unit vector), the half size] of the name's box at the size `px`.
func _name_shape(name: Dictionary, px: int) -> Array[Vector2]:
	var axis := Vector2.from_angle(deg_to_rad(float(name["angle_deg"])))
	var width := _text_width(_name_face(px), str(name["text"]), px)
	return [axis, Vector2(width, NAME_BOX_EM * px + ParchmentTokens.HALO_PX) * 0.5]


## Whether a name may stand at `at`: off the boxes to avoid and unexplored paper, and on its region when moved from
## `home`.
func _may_stand(name: Dictionary, home: Vector2, at: Vector2, axis: Vector2, half: Vector2) -> bool:
	if ParchmentNameSpots.hits(_avoid, at, axis, half):
		return false
	if at != home and not ParchmentNameSpots.on_region(_owners, _game.map, _xform, int(name["id"]), home, at, axis, half.x):
		return false
	return not _on_unknown(at, axis, half)


func _give_country(name: Dictionary, at: Vector2, axis: Vector2, half: Vector2, px: int) -> void:
	var out := Vector2(absf(axis.x) * half.x + absf(axis.y) * half.y, absf(axis.y) * half.x + absf(axis.x) * half.y)
	var bounds := Rect2(at - out, out * 2.0)
	_placed.append({"kind": KIND_COUNTRY, "hex": MapModes.hex_at_px(_xform.affine_inverse() * at), "text": name["text"],
		"rect": bounds, "angle": name["angle_deg"], "size": px, "tag": name["tag"], "centre": at, "extent": half * 2.0})
	_add_block(bounds, PackedVector2Array([at, axis, half]))


# ----- the goods icons -----------------------------------------------------------------------------------------------


## The districts of the chosen good near the screen, each [column, row, stage].
func _seen_districts() -> Array[Vector3i]:
	if _good < 0 or _goods.is_empty() or not _icon_names.has(_good):
		return []
	return ParchmentIconSpots.districts(_game.map, _goods, _good, _seen_area())


## One icon on each of the districts: first every district that has a spot clear of all that is placed, then the others
## on a spot that only country names take.
func _place_icons(districts: Array[Vector3i], hex_px: float) -> void:
	var left_over: Array[Vector3i] = []
	for district: Vector3i in districts:
		if not _place_icon(Vector2i(district.x, district.y), district.z, hex_px, false):
			left_over.append(district)
	for district: Vector3i in left_over:
		_place_icon(Vector2i(district.x, district.y), district.z, hex_px, true)


## The icon of a district, in its spot (see _icon_spot). False when there is none.
func _place_icon(hex: Vector2i, stage: int, hex_px: float, over_names: bool) -> bool:
	var box := _icon_spot(hex, hex_px, over_names)
	if not box.has_area():
		return false
	var radius := ParchmentIconSpots.radius(hex_px)
	var centre := box.position + Vector2(radius, radius)
	_placed.append({"kind": KIND_ICON, "hex": hex, "text": "", "rect": box, "angle": 0.0,
		"size": roundi(radius * 2.0), "centre": centre, "radius": radius, "stage": stage, "icon": _icon_names[_good]})
	_add_block(box)
	return true


## The box (disc and pips) of a district's icon: the first free of ParchmentIconSpots.boxes. With `over_names` a spot
## that country names take counts as free. Empty when none is.
func _icon_spot(hex: Vector2i, hex_px: float, over_names: bool) -> Rect2:
	var middle: Vector2 = _xform * MapTiles.cell_centre(hex)
	for box: Rect2 in ParchmentIconSpots.boxes(middle, hex_px, _dots.get(hex, -1.0)):
		if not _is_blocked(box, over_names) and not _on_unknown(box.get_center(), Vector2.RIGHT, box.size * 0.5):
			return box
	return Rect2()


static func pip_radius(radius: float) -> float:
	return maxf(PIP_MIN_PX, PIP_SHARE * radius)


# ----- what is taken -------------------------------------------------------------------------------------------------


func _add_block(bounds: Rect2, turn: PackedVector2Array = PackedVector2Array()) -> void:
	_space.add(bounds, turn)


## Whether `box` meets a HUD cover rect or anything placed; with `over_names`, the country names (the turned boxes) do
## not count.
func _is_blocked(box: Rect2, over_names: bool = false) -> bool:
	for rect: Rect2 in _cover:
		if rect.intersects(box):
			return true
	return _space.meets(box, over_names)


## Whether the screen box of middle `centre`, long axis `axis` and half size `half` overlaps the cell of a hex the
## viewer has not discovered.
func _on_unknown(centre: Vector2, axis: Vector2, half: Vector2) -> bool:
	if not _fogged:
		return false
	return ParchmentLabelSpace.over_hexes(_owners, _game.map, _xform.affine_inverse() * centre, axis, half / _zoom,
		ParchmentView.UNKNOWN, true)


## The width of `text` at the size `px`, with its halo.
func _text_width(font: Font, text: String, px: int) -> float:
	var key := "%d %d %s" % [int(font == _town_font), px, text]
	if not _widths.has(key):
		_widths[key] = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + ParchmentTokens.HALO_PX
	return _widths[key]


# ----- drawing -------------------------------------------------------------------------------------------------------


func _draw() -> void:
	ParchmentLabelPainter.paint(self, draw_base(), _placed, _colours, _town_font, _name_colours(), _name_face,
		_icon_texture)


## What carries the layout's screen px into the node's own space (the map's): the view's inverse transform.
func draw_base() -> Transform2D:
	return _xform.affine_inverse() if _has_view else Transform2D.IDENTITY


## [ink, halo] of the country names: both NAME_ALPHA opaque in Goods mode, whole in the other modes and in high
## contrast.
func _name_colours() -> Array[Color]:
	var ink: Color = _colours[&"name_ink"]
	var halo: Color = _colours[&"halo"]
	if _mode == MapModes.Mode.GOODS and not _high_contrast:
		ink.a *= NAME_ALPHA
		halo.a *= NAME_ALPHA
	return [ink, halo]


## The Kit icon of a good, from the project's theme (the 24 px icons).
func _icon_texture(icon: StringName) -> Texture2D:
	if _icon_theme == null:
		_icon_theme = ThemeDB.get_project_theme()
	if _icon_theme == null and ResourceLoader.exists(KitTheme.THEME_PATH):
		_icon_theme = load(KitTheme.THEME_PATH) as Theme
	if _icon_theme != null and _icon_theme.has_icon(icon, &"Kit"):
		return _icon_theme.get_icon(icon, &"Kit")
	return null
