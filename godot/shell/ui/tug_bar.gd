## The tug bar of the battle dock (docs/architecture/m7-build-spec.md 6.5; M7 B22): two halves growing from the middle, each in
## its side's colour, the attacker's to the left and the defender's to the right. Each half is its side's front-line morale
## (permille); a tick marks each side's flee line (FLEE_PERMILLE from its outer edge). Tokens only; the percentages beside
## the bar are the dock's labels.
class_name TugBar
extends Control

const BAR_H: float = 14.0
const TICK_W: float = 2.0
const TICK_EXTRA: float = 4.0
const FULL: int = 1000
## A side flees when its front morale falls under this (10 %).
const FLEE_PERMILLE: int = 100

var attacker_permille: int = FULL
var defender_permille: int = FULL
var attacker_colour: Color = Tokens.MUTED
var defender_colour: Color = Tokens.MUTED


func _init() -> void:
	custom_minimum_size = Vector2(120.0, BAR_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Sets both fronts (permille, clamped to 0 to 1000) and their colours, and redraws.
func set_values(attacker: int, defender: int, attacker_col: Color, defender_col: Color) -> void:
	attacker_permille = clampi(attacker, 0, FULL)
	defender_permille = clampi(defender, 0, FULL)
	attacker_colour = attacker_col
	defender_colour = defender_col
	queue_redraw()


## The x of a side's flee tick: its half's outer edge moved in by the flee share. `left` is the attacker's side.
static func flee_x(width: float, left: bool) -> float:
	var half := width * 0.5
	var inset := half * float(FLEE_PERMILLE) / float(FULL)
	return half - inset if left else half + inset


func _draw() -> void:
	var w := size.x
	var h := minf(size.y, BAR_H)
	var y := (size.y - h) * 0.5
	var mid := w * 0.5
	draw_rect(Rect2(0.0, y, w, h), Tokens.WAR_DIAL_TRACK)
	var half := mid
	var att_w := half * float(attacker_permille) / float(FULL)
	var def_w := half * float(defender_permille) / float(FULL)
	draw_rect(Rect2(mid - att_w, y, att_w, h), attacker_colour)
	draw_rect(Rect2(mid, y, def_w, h), defender_colour)
	var tick_top := y - TICK_EXTRA * 0.5
	var tick_h := h + TICK_EXTRA
	draw_rect(Rect2(flee_x(w, true) - TICK_W * 0.5, tick_top, TICK_W, tick_h), Tokens.BAD)
	draw_rect(Rect2(flee_x(w, false) - TICK_W * 0.5, tick_top, TICK_W, tick_h), Tokens.BAD)
