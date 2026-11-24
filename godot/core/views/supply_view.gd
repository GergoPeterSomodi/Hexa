## What the Supply of a hex means to its owner (docs/architecture/m6-build-spec.md sections 4.8, 5.6 and 6.6; L11): one hex's
## state for the hex card (`at`), and one byte a hex for the Supply mode (`bytes`, read by MapModes.supply_bytes). The bytes
## are the table of 6.6: 0 not the viewer's land, 1 out of supply and starving (the land feeds no one), 2 out and fed a few
## (under 1,000 men a season), 3 out and fed an army, 4 in supply now but cut off in winter (shown from spring to autumn),
## 5 in supply, 6 a depot. Pure core/views/ code: a function of the game and the viewer; the supply fields come from Supply.
class_name SupplyView
extends RefCounted

const BYTE_NONE := 0
const BYTE_STARVING := 1
const BYTE_FEW := 2
const BYTE_ARMY := 3
const BYTE_WINTER_CUT := 4
const BYTE_IN := 5
const BYTE_DEPOT := 6
const FEW_LIMIT := 1000
const DEPOT_TEXT := "A depot (a village or larger, a port)."


## The supply of `hex` for `viewer` now: {shown, state (&"depot", &"in", &"winter_cut", &"out"), text, feeds}. `shown` is false
## off the viewer's own land (and for the viewer "" and a hex that is not land).
static func at(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary:
	var out := {"shown": false, "state": &"", "text": "", "feeds": 0}
	if game == null or game.map == null or game.state == null or viewer == &"" or not game.has_countries():
		return out
	var c := Countries.by_tag(game, viewer)
	var i := game.map.index_of(hex)
	if c == null or i < 0 or game.map.land[i] != 1 or int(game.state.owner[i]) != c.id:
		return out
	var winter := Calendar.is_winter(game.turn)
	var now_f := Supply.field(game, viewer, winter)
	var win_f := Supply.field(game, viewer, true)
	var view := StateView.of(game.state)
	var b := _byte(game, viewer, i, now_f, win_f, winter, view)
	out.shown = true
	out.feeds = Supply.forage_cap(game, view, hex, game.turn) if b <= BYTE_ARMY else 0
	match b:
		BYTE_DEPOT:
			out.state = &"depot"
			out.text = DEPOT_TEXT
		BYTE_IN:
			out.state = &"in"
			out.text = "In supply"
		BYTE_WINTER_CUT:
			out.state = &"winter_cut"
			out.text = "In supply, cut off in winter"
		_:
			out.state = &"out"
			out.text = "Out of supply: the land feeds no one" if int(out.feeds) == 0 \
				else "Out of supply: the land feeds %s men a season" % Words.number(int(out.feeds))
	return out


## One byte a hex (index = row * cols + col) of the viewer's Supply mode: 0 on every hex that is not the viewer's land.
## The fields are fetched once, so this is one pass over the map (MapModes caches it).
static func bytes(game: Game, viewer: StringName) -> PackedByteArray:
	var n := game.map.hex_count()
	var out := PackedByteArray()
	out.resize(n)
	out.fill(BYTE_NONE)
	if viewer == &"" or not game.has_countries() or game.state == null:
		return out
	var c := Countries.by_tag(game, viewer)
	if c == null:
		return out
	var winter := Calendar.is_winter(game.turn)
	var now_f := Supply.field(game, viewer, winter)
	var win_f := Supply.field(game, viewer, true)
	var view := StateView.of(game.state)
	for i: int in n:
		if game.map.land[i] == 1 and int(game.state.owner[i]) == c.id:
			out[i] = _byte(game, viewer, i, now_f, win_f, winter, view)
	return out


## The byte of one land hex the viewer owns (6.6's table). `now_f` and `win_f` are the viewer's fields this season and in winter.
static func _byte(game: Game, viewer: StringName, i: int, now_f: PackedByteArray, win_f: PackedByteArray,
		winter: bool, view: StateView) -> int:
	var hex := game.map.hex_of(i)
	if Supply.is_depot(game, viewer, hex):  # settlements and fortresses alike (M7 4.12)
		return BYTE_DEPOT
	if _in(now_f, i):
		return BYTE_WINTER_CUT if (not winter and not _in(win_f, i)) else BYTE_IN
	var feeds := Supply.forage_cap(game, view, hex, game.turn)
	if feeds <= 0:
		return BYTE_STARVING
	return BYTE_FEW if feeds < FEW_LIMIT else BYTE_ARMY


static func _in(field: PackedByteArray, i: int) -> bool:
	return i < field.size() and field[i] == 1
