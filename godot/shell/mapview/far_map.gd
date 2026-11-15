## The far zoom's one picture (docs/architecture/m1-build-spec.md section 7): FarPicture's pixels in one texture on one
## sprite, scaled so a picture hex covers its cell, filtered linearly. Below ZOOM_OFF the tile layers are hidden and this
## is all that shows; between ZOOM_OFF and ZOOM_ON the picture fades out over the tiles. It holds no facts: it is given
## the map and the state, and told which hex changed.
class_name FarMap
extends Node2D

const ZOOM_OFF := 0.20  # at and below this zoom the tiles are hidden and the picture is solid
const ZOOM_ON := 0.25  # at and above this zoom the picture is gone
## Map px a picture px covers (a cell is 104 x 76.5 px, a hex is 4 x 3 picture px).
const SCALE := Vector2(26.0, 25.5)
## The cell's middle is 51 px under its top, the picture hex's is 76.5 / 6 = 12.75 px under where the scale puts it.
const OFFSET := Vector2(0.0, 12.75)

var _map: MapData = null
var _state: MapState = null
var _bytes := PackedByteArray()
var _size := Vector2i.ZERO
var _image: Image = null
var _texture: ImageTexture = null
var _sprite: Sprite2D = null
var _building := false
var _next_row := 0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Picture"
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.scale = SCALE
	_sprite.position = OFFSET
	add_child(_sprite)
	visible = false


## Builds the picture of a map and its state at once (about 0.7 s for Europe: a large map uses begin and step).
func setup(map: MapData, state: MapState) -> void:
	begin(map, state)
	step(1.0e9)


## Starts building the picture a few rows at a time (see step); the old picture stays up until the new one is ready.
func begin(map: MapData, state: MapState) -> void:
	_map = map
	_state = state
	_size = FarPicture.size_of(map)
	_bytes = PackedByteArray()
	_bytes.resize(_size.x * _size.y * 4)
	_next_row = 0
	_building = true
	if _sprite == null:
		_ready()


func is_building() -> bool:
	return _building


## Writes rows of hexes for up to `budget_ms` milliseconds (at least one row); the picture appears when the last is done.
func step(budget_ms: float) -> void:
	if not _building:
		return
	var until := Time.get_ticks_usec() + int(budget_ms * 1000.0)
	while _next_row < _map.rows:
		for c: int in _map.cols:
			FarPicture.write_hex(_bytes, _map, _state, Vector2i(c, _next_row))
		_next_row += 1
		if Time.get_ticks_usec() >= until:
			break
	if _next_row < _map.rows:
		return
	_building = false
	_image = Image.create_from_data(_size.x, _size.y, false, Image.FORMAT_RGBA8, _bytes)
	_texture = ImageTexture.create_from_image(_image)
	_sprite.texture = _texture


## A hex changed: its 12 pixels are written again and the texture updated.
func update_hex(hex: Vector2i) -> void:
	if _map == null or not _map.has(hex):
		return
	FarPicture.write_hex(_bytes, _map, _state, hex)
	if _texture == null or _building:
		return  # the picture being built takes the bytes when it is done
	_image = Image.create_from_data(_size.x, _size.y, false, Image.FORMAT_RGBA8, _bytes)
	_texture.update(_image)


## The picture's pixel colour at a hex (what a test looks at).
func pixel_of(hex: Vector2i) -> Color:
	var rect := FarPicture.rect_of(hex)
	return _image.get_pixel(rect.position.x + 1, rect.position.y + 2) if _image != null else Color.BLACK


## How solid the picture is at a zoom: 1 at and below ZOOM_OFF, 0 at and above ZOOM_ON, linear between.
static func alpha_at(zoom: float) -> float:
	return clampf((ZOOM_ON - zoom) / (ZOOM_ON - ZOOM_OFF), 0.0, 1.0)


## Whether the tile layers show at a zoom.
static func tiles_show_at(zoom: float) -> bool:
	return zoom > ZOOM_OFF


## Shows the picture as the zoom says; returns whether the tiles should show.
func apply_zoom(zoom: float) -> bool:
	var alpha := alpha_at(zoom)
	visible = alpha > 0.0 and _texture != null
	modulate.a = alpha
	return tiles_show_at(zoom)
