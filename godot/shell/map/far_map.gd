## One hex-coloured picture of the whole map: the far maps (terrain or countries) and the countries overlay at the
## tile zoom. Drawn by hex_colours.gdshader from a texture with one texel per hex.
class_name FarMap
extends Node2D

const SHADER := preload("res://shell/map/hex_colours.gdshader")

var _size: Vector2 = Vector2.ZERO


func setup(colours: PackedColorArray, cols: int, rows: int, size: Vector2, opacity: float) -> void:
	var image := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	for r in rows:
		for c in cols:
			image.set_pixel(c, r, colours[r * cols + c])
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("hex_colours", ImageTexture.create_from_image(image))
	mat.set_shader_parameter("grid", Vector2(float(cols), float(rows)))
	mat.set_shader_parameter("opacity", opacity)
	material = mat
	_size = size
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _size), Color.WHITE)
