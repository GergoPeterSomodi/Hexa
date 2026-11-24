## The deep-fog texture of the map overlay (fog spec R36, D17; docs/architecture/fog-build-spec.md section 3.8): one R8 byte a hex,
## 1 where the viewer has discovered the hex and 0 under deep fog. ModeOverlay's shader paints every 0 with one flat fill in every
## mode, and the minimap shares the texture. It keeps the key of the bytes it shows, so a sync costs one compare while the explored
## set and the sight do not move. The rule is MapModes' (core/views/); this class only holds the texture (the overlay moved it here
## to stay under the lint's 800 lines).
class_name DeepFog
extends RefCounted

var _bytes := PackedByteArray()  # the bytes the texture shows (the texels are written from it)
var _key: Array = []  # MapModes.discovered_key of those bytes ([]: none yet)
var _image: Image = null
var _tex: ImageTexture = null


## Makes the texture for a map of `cols` x `rows`, every hex discovered until the first sync (no fog before the viewer's
## discovery is known).
func setup(cols: int, rows: int) -> void:
	_key = []
	_bytes = PackedByteArray()
	_bytes.resize(cols * rows)
	_bytes.fill(1)
	_image = Image.create_from_data(cols, rows, false, Image.FORMAT_R8, _bytes)
	_tex = ImageTexture.create_from_image(_image)


## The texture (null before setup).
func texture() -> ImageTexture:
	return _tex


## The image behind the texture: its bytes are the fog (the tests read them here).
func image() -> Image:
	return _image


## True when some hex is under deep fog.
func any_fog() -> bool:
	return _bytes.find(0) >= 0


## Brings the texture to `game`'s discovered hexes when their key moved; returns the texels written (0 while nothing moved).
func sync(game: Game) -> int:
	if game == null or game.map == null or _tex == null:
		return 0
	var key := MapModes.discovered_key(game, game.player)
	if key == _key:
		return 0
	_key = key
	return write(MapModes.discovered_bytes(game, game.player))


## Writes the texels that differ from `bytes` (one byte a hex, row-major) and uploads the texture once. Returns the texels
## written; 0 for bytes of the wrong size.
func write(bytes: PackedByteArray) -> int:
	if _tex == null or bytes.size() != _bytes.size():
		return 0
	var cols := _image.get_width()
	var wrote := 0
	var idx := 0
	for row: int in _image.get_height():
		for col: int in cols:
			var b := bytes[idx]
			if b != _bytes[idx]:
				_bytes[idx] = b
				_image.set_pixel(col, row, Color(float(b) / 255.0, 0.0, 0.0, 1.0))
				wrote += 1
			idx += 1
	if wrote > 0:
		_tex.update(_image)
	return wrote
