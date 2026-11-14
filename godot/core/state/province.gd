## One land hex of the Europe map as a province: its terrain, its owner, its people, its good and its settlement and
## castle levels. Plain data, made by the map builder (provinces.gd, country_builder.gd). Step 2 of the builder.
class_name Province
extends RefCounted

var pos: Vector2i = Vector2i.ZERO
var terrain: String = ""  # a land kind of terrain.json
var good: String = ""  # the good the province produces ("" = none)
var coastal: bool = false  # next to an ocean hex (a lake does not count)
var city: bool = false  # a city of the geography (its name is the city's)
var name: String = ""
var region: String = ""  # the historical region (naming.gd)
var owner: String = ""  # the country that owns it at the start ("" = none)
var controller: String = ""  # the country in control at the start (the owner)
var tribe: String = ""  # the native people of an unowned hex
var peasants: float = 0.0
var burghers: float = 0.0
var nobles: float = 0.0
var natives: float = 0.0  # the people of an unowned hex
var works: int = 0  # level of the works on the good (0 none, 1 or 2 at the start)
var settlement: int = 0  # 0 none, 1 village, 2 town, 3 city
var castle: int = 0  # 0 none, 1 tower, 2 small castle, 3 large castle
var port: bool = false  # a port: a colonising country's caravel starts beside it


func _init(p_pos: Vector2i = Vector2i.ZERO, p_terrain: String = "", p_coastal: bool = false,
		p_city: bool = false) -> void:
	pos = p_pos
	terrain = p_terrain
	coastal = p_coastal
	city = p_city


## The people of the province: peasants, burghers and nobles (Python Province.pop).
func pop() -> float:
	return peasants + burghers + nobles
