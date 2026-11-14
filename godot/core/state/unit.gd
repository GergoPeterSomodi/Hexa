## One unit on the map at the start: a troop, a general or a caravel. Plain data, placed by the map builder
## (starting_units.gd). Units are not drawn in 0.3.0; the fields are kept for 0.3.2.
class_name Unit
extends RefCounted

var id: int = 0
var kind: String = ""  # the kind key of units.json ("pikemen", "knights", "bombards", "general", "caravel")
var owner: String = ""  # the country tag
var pos: Vector2i = Vector2i.ZERO
var hp: int = 0
var moves: float = 0.0


func _init(p_id: int = 0, p_kind: String = "", p_owner: String = "", p_pos: Vector2i = Vector2i.ZERO,
		p_hp: int = 0, p_moves: float = 0.0) -> void:
	id = p_id
	kind = p_kind
	owner = p_owner
	pos = p_pos
	hp = p_hp
	moves = p_moves
