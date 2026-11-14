## One of the 49 countries of the Europe 1480 map at the start: its tag, name, colour and capital. Plain data, made by
## the map builder (country_builder.gd). Step 2 of the builder.
class_name Country
extends RefCounted

var tag: String = ""
var name: String = ""
var colour: Color = Color.BLACK
var capital: Vector2i = Vector2i.ZERO
var colonial_start: int = 999  # the turn the country starts colonising (999: no start; 40 or less: a caravel at the start)


func _init(p_tag: String = "", p_name: String = "", p_colour: Color = Color.BLACK,
		p_capital: Vector2i = Vector2i.ZERO) -> void:
	tag = p_tag
	name = p_name
	colour = p_colour
	capital = p_capital
