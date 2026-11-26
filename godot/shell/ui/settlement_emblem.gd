## The settlement-type emblem on the tile window's picture (issue 436 round 3, the owner's decision: the size stars left the
## title bar; the type is a small heraldic seal drawn in code, one per kind, with a tooltip naming it). A heater shield in brass
## with an ink rim and one charge per kind, so each reads by its shape, not its colour:
##   hamlet       one cottage                 village   a cottage and a chapel spire
##   town         two towers                  walled_town  a crenellated wall with a gate
##   city         a wall under a crown        castle 1 (watchtower)  one tall tower
##   castle 2 (castle)  a keep between two towers   castle 3 (fortress)  a star fort
## `charge_of` names the charge (tests). Colours come from Tokens only.
class_name SettlementEmblem
extends Control

const SIZE := Vector2(30, 36)
## The emblem's words by kind and level (the tooltip's first line).
const NAMES := {&"hamlet": "Hamlet", &"village": "Village", &"town": "Town", &"walled_town": "Walled town", &"city": "City"}
const CASTLE_NAMES: Array[String] = ["", "Watchtower", "Castle", "Fortress"]

var _kind: StringName = &""
var _level := 0


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


## Shows the emblem of `kind` (hamlet .. city, or castle with `level` 1 to 3); an unknown kind hides it.
func show_kind(kind: StringName, level: int) -> void:
	_kind = kind
	_level = level
	visible = charge_of(kind, level) != &""
	tooltip_text = "%s\n%s" % [name_of(kind, level), _meaning(kind, level)] if visible else ""
	queue_redraw()


## The type's name: "Walled town", "Fortress"...; "" for no settlement.
static func name_of(kind: StringName, level: int) -> String:
	if kind == &"castle":
		return CASTLE_NAMES[clampi(level, 1, 3)]
	return str(NAMES.get(kind, ""))


## The charge drawn for the kind (tests: each kind its own).
static func charge_of(kind: StringName, level: int) -> StringName:
	match kind:
		&"hamlet", &"village", &"town", &"walled_town", &"city":
			return kind
		&"castle":
			var castles: Array[StringName] = [&"watchtower", &"castle", &"fortress"]
			return castles[clampi(level, 1, 3) - 1]
	return &""


static func _meaning(kind: StringName, level: int) -> String:
	if kind == &"castle":
		return "A castle of level %d of 3: it holds the land around it." % clampi(level, 1, 3)
	var rank: int = [&"hamlet", &"village", &"town", &"walled_town", &"city"].find(kind) + 1
	return "A settlement of size %d of 5." % rank


func _draw() -> void:
	var w := size.x
	var h := size.y
	var shield := PackedVector2Array([Vector2(1, 1), Vector2(w - 1, 1), Vector2(w - 1, h * 0.52), Vector2(w * 0.5, h - 1),
		Vector2(1, h * 0.52)])
	var shade := PackedVector2Array([Vector2(w * 0.5, 1), Vector2(w - 1, 1), Vector2(w - 1, h * 0.52), Vector2(w * 0.5, h - 1)])
	draw_colored_polygon(shield, Tokens.BRASS)
	draw_colored_polygon(shade, Tokens.TILE_GOLD_D)
	var rim := shield.duplicate()
	rim.append(shield[0])
	draw_polyline(rim, Tokens.INK, 1.5, true)
	var u := w / 30.0
	match charge_of(_kind, _level):
		&"hamlet":
			_cottage(Vector2(15, 22) * u, u)
		&"village":
			_cottage(Vector2(11, 23) * u, u)
			_spire(Vector2(21, 24) * u, u)
		&"town":
			_tower(Vector2(9, 9) * u, Vector2(5, 15) * u)
			_tower(Vector2(17, 7) * u, Vector2(5, 17) * u)
		&"walled_town":
			_wall(Vector2(5, 13) * u, Vector2(20, 11) * u)
		&"city":
			_crown(Vector2(15, 7) * u, u)
			_wall(Vector2(5, 16) * u, Vector2(20, 9) * u)
		&"watchtower":
			_tower(Vector2(12, 6) * u, Vector2(6, 20) * u)
		&"castle":
			_tower(Vector2(5, 12) * u, Vector2(5, 12) * u)
			_tower(Vector2(20, 12) * u, Vector2(5, 12) * u)
			_tower(Vector2(11, 7) * u, Vector2(8, 17) * u)
		&"fortress":
			_star(Vector2(15, 15) * u, 9.0 * u)


func _cottage(foot: Vector2, u: float) -> void:
	draw_rect(Rect2(foot + Vector2(-5, -6) * u, Vector2(10, 6) * u), Tokens.INK)
	draw_colored_polygon(PackedVector2Array([foot + Vector2(-7, -6) * u, foot + Vector2(0, -12) * u, foot + Vector2(7, -6) * u]),
		Tokens.INK)


func _spire(foot: Vector2, u: float) -> void:
	draw_rect(Rect2(foot + Vector2(-2.5, -9) * u, Vector2(5, 9) * u), Tokens.INK)
	draw_colored_polygon(PackedVector2Array([foot + Vector2(-3.5, -9) * u, foot + Vector2(0, -17) * u, foot + Vector2(3.5, -9) * u]),
		Tokens.INK)


func _tower(at: Vector2, extent: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(0, 2), extent - Vector2(0, 2)), Tokens.INK)
	var merlon := extent.x / 5.0
	for k: int in 3:
		draw_rect(Rect2(at + Vector2(merlon * 2.0 * k, 0), Vector2(merlon, 3)), Tokens.INK)


func _wall(at: Vector2, extent: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(0, 3), extent - Vector2(0, 3)), Tokens.INK)
	var merlon := extent.x / 9.0
	for k: int in 5:
		draw_rect(Rect2(at + Vector2(merlon * 2.0 * k, 0), Vector2(merlon, 3)), Tokens.INK)
	draw_rect(Rect2(at + Vector2(extent.x * 0.5 - 2.5, extent.y - 6), Vector2(5, 6)), Tokens.BRASS_HI)


func _crown(c: Vector2, u: float) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-7, 4) * u, c + Vector2(-7, -3) * u, c + Vector2(-3.5, 1) * u,
		c + Vector2(0, -4) * u, c + Vector2(3.5, 1) * u, c + Vector2(7, -3) * u, c + Vector2(7, 4) * u]), Tokens.INK)


func _star(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for k: int in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.55))
	draw_colored_polygon(pts, Tokens.INK)
	draw_circle(c, r * 0.25, Tokens.BRASS_HI)
