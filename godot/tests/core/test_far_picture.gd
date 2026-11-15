## The far zoom's picture (core/views/far_picture.gd): size, colours, and what one hex change rewrites.
extends GutTest

const COLS := 8
const ROWS := 6


## An 8 x 6 map: sea on the left three columns, land on the right, a wood at (5, 2), farmland elsewhere.
func _map() -> Dictionary:
	var n := COLS * ROWS
	var land := PackedByteArray()
	var cover := PackedByteArray()
	var depth := PackedByteArray()
	var climate := PackedByteArray()
	var height := PackedInt32Array()
	land.resize(n)
	cover.resize(n)
	depth.resize(n)
	climate.resize(n)
	height.resize(n)
	for r: int in ROWS:
		for c: int in COLS:
			var i := r * COLS + c
			land[i] = 1 if c >= 3 else 0
			cover[i] = 0 if c >= 3 else 255
			depth[i] = 2 if c == 0 else 1
			climate[i] = 2
			height[i] = 200 if c >= 3 else 0
	cover[2 * COLS + 5] = 2
	return {"cols": COLS, "rows": ROWS, "land": land, "cover": cover, "depth": depth, "climate": climate,
		"height_m": height}


func _state() -> Dictionary:
	var main_use := PackedByteArray()
	main_use.resize(COLS * ROWS)
	return {"main_use": main_use, "level": main_use.duplicate()}


func _px(buffer: PackedByteArray, map: Dictionary, x: int, y: int) -> Color:
	var at := (y * FarPicture.size_of(map).x + x) * 4
	return Color8(buffer[at], buffer[at + 1], buffer[at + 2], buffer[at + 3])


func test_size() -> void:
	var map := _map()
	assert_eq(FarPicture.size_of(map), Vector2i(4 * COLS + 2, 3 * ROWS + 1))
	assert_eq(FarPicture.pixels(map, _state()).size(), (4 * COLS + 2) * (3 * ROWS + 1) * 4)
	# Europe: 494 x 247 hexes make 1,978 x 742 px.
	assert_eq(FarPicture.size_of({"cols": 494, "rows": 247}), Vector2i(1978, 742))


func test_sea_is_blue_and_wood_is_green() -> void:
	var map := _map()
	var state := _state()
	var sea := FarPicture.colour_of(map, state, Vector2i(0, 1))
	assert_true(sea.b > sea.r and sea.b > sea.g, "open sea is blue")
	var wood := FarPicture.colour_of(map, state, Vector2i(5, 2))
	assert_true(wood.g > wood.r and wood.g > wood.b, "a wood is green")
	assert_ne(FarPicture.colour_of(map, state, Vector2i(0, 1)), FarPicture.colour_of(map, state, Vector2i(2, 1)),
		"the deep differs from the shelf beside land")
	var buffer := FarPicture.pixels(map, state)
	var rect := FarPicture.rect_of(Vector2i(5, 2))
	assert_eq(_px(buffer, map, rect.position.x + 1, rect.position.y + 1).to_html(false), wood.to_html(false))
	assert_eq(_px(buffer, map, 0, 0).a, 1.0, "a covered pixel is opaque")


func test_odd_rows_are_shifted() -> void:
	assert_eq(FarPicture.rect_of(Vector2i(2, 2)).position, Vector2i(8, 6))
	assert_eq(FarPicture.rect_of(Vector2i(2, 3)).position, Vector2i(10, 9))


func test_one_hex_changes_12_pixels() -> void:
	var map := _map()
	var state := _state()
	var before := FarPicture.pixels(map, state)
	var hex := Vector2i(5, 3)
	state.main_use[3 * COLS + 5] = 3  # wheat
	var after := FarPicture.pixels(map, state)
	var changed := 0
	var inside := 0
	var rect := FarPicture.rect_of(hex)
	var size := FarPicture.size_of(map)
	for y: int in size.y:
		for x: int in size.x:
			if _px(before, map, x, y) != _px(after, map, x, y):
				changed += 1
				if rect.has_point(Vector2i(x, y)):
					inside += 1
	assert_eq(changed, 12)
	assert_eq(inside, 12)
	var patched := before.duplicate()
	FarPicture.write_hex(patched, map, state, hex)
	assert_eq(patched, after, "write_hex gives what a full rebuild gives")


func test_a_town_has_a_roof_dot() -> void:
	var map := _map()
	var state := _state()
	state.main_use[3 * COLS + 5] = 1
	var buffer := FarPicture.pixels(map, state)
	var rect := FarPicture.rect_of(Vector2i(5, 3))
	var dot := _px(buffer, map, rect.position.x + 1, rect.position.y + 1)
	assert_true(dot.r > dot.g and dot.r > dot.b, "a roof-red dot")
