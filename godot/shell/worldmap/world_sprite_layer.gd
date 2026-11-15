## A layer of sprites drawn in the order given, as one canvas item: each sprite is a region of an atlas texture put at a
## map pixel. The draw list is kept by the engine between frames, so moving the camera redraws nothing; set_items is the
## only cost. Used by the north Italy map for the piece grounds, the shadows and the standing things.
class_name WorldSpriteLayer
extends Node2D

var _textures: Array[Texture2D] = []
var _regions: Array[Rect2] = []
var _positions: PackedVector2Array = PackedVector2Array()


func clear_items() -> void:
	_textures.clear()
	_regions.clear()
	_positions.clear()
	queue_redraw()


## One sprite: the atlas, the region of it, and where its top-left corner goes on the map.
func add_item(texture: Texture2D, region: Rect2, at: Vector2) -> void:
	_textures.append(texture)
	_regions.append(region)
	_positions.append(at)
	queue_redraw()


func item_count() -> int:
	return _textures.size()


func _draw() -> void:
	for i: int in _textures.size():
		draw_texture_rect_region(_textures[i], Rect2(_positions[i], _regions[i].size), _regions[i])
