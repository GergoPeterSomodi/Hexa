## One war mark on the map (docs/architecture/m7-build-spec.md 6.3; M7 B25): a battle site (the kit's crossed swords on a dark
## roundel, its ring in the result's tone, the front-morale bar under it), a siege (a gate tower with its amber dial filling
## clockwise with progress / need), or a replay's battle badge (a battle badge drawn faint while the movement replay runs).
## It holds no game state: WarMarks sets its fields from the views and draws them here.
class_name WarMark
extends Node2D

const KIND_BATTLE := &"battle"
const KIND_SIEGE := &"siege"
const KIND_REPLAY := &"replay"
## The badge's side in map px (the kit piece is 40 x 40); the ring is drawn at RING_R inside it.
const SIZE := 40.0
const RING_R := 19.0
const RING_WIDTH := 3.0
const DIAL_WIDTH := 4.0
const ARC_POINTS := 48
## The front-morale bar: its top under the badge, its height, its width (the badge's).
const BAR_Y := 22.0
const BAR_H := 4.0
const REPLAY_ALPHA := 0.7

var kind: StringName = KIND_BATTLE
var tone: StringName = &"plain"
var record := -1
var hex := Vector2i.ZERO
var dial_done := 0
var need := 1
var front := PackedInt32Array([0, 0])
var attacker_colour := Color.WHITE
var defender_colour := Color.WHITE
var badge: Texture2D = null


func _draw() -> void:
	var alpha := REPLAY_ALPHA if kind == KIND_REPLAY else 1.0
	var half := SIZE / 2.0
	if badge != null:
		draw_texture_rect(badge, Rect2(-half, -half, SIZE, SIZE), false, Color(1.0, 1.0, 1.0, alpha))
	else:
		draw_circle(Vector2.ZERO, RING_R, Color(Tokens.INK, alpha))
	if kind == KIND_SIEGE:
		_dial()
		return
	draw_arc(Vector2.ZERO, RING_R, 0.0, TAU, ARC_POINTS, Color(_ring_colour(), alpha), RING_WIDTH, true)
	_front_bar(alpha)


## The siege dial: the track all round, then the amber arc from the top, clockwise, to dial_done / need.
func _dial() -> void:
	draw_arc(Vector2.ZERO, RING_R, 0.0, TAU, ARC_POINTS, Tokens.WAR_DIAL_TRACK, DIAL_WIDTH, true)
	var share := clampf(float(dial_done) / float(maxi(need, 1)), 0.0, 1.0)
	if share > 0.0:
		draw_arc(Vector2.ZERO, RING_R, -PI / 2.0, -PI / 2.0 + TAU * share, ARC_POINTS, Tokens.WAR_DIAL, DIAL_WIDTH, true)


## The attacker's colour from the left and the defender's from the right, split at their front morale (the last day's).
func _front_bar(alpha: float) -> void:
	var total := front[0] + front[1]
	var split := 0.5 if total <= 0 else float(front[0]) / float(total)
	var left := -SIZE / 2.0
	var width := SIZE * split
	draw_rect(Rect2(left, BAR_Y, width, BAR_H), Color(attacker_colour, alpha))
	draw_rect(Rect2(left + width, BAR_Y, SIZE - width, BAR_H), Color(defender_colour, alpha))


func _ring_colour() -> Color:
	match tone:
		&"good":
			return Tokens.GOOD
		&"bad":
			return Tokens.BAD
	return Tokens.MUTED
