## GUT tests for the minimap (docs/architecture/m2-build-spec.md sections 7.8 and 10): a click glides to the
## point, a drag jumps while held, the frame follows the camera's view, the overlay follows the mode, and the
## minimap hides without a game or with the setting off. Each check has a planted-fault case (P) where it matters.
extends GutTest

const VIEW_SIZE := Vector2i(1280, 720)
const MAP_PX := Vector2(2236.0, 1708.5)
const AREA := Vector2(220.0, 124.0)

var _vp: SubViewport = null
var _camera: Camera2D = null
var _rig: CameraRig = null
var _minimap: Minimap = null
var _far: FarMap = null
var _overlay: ModeOverlay = null


func before_each() -> void:
	_vp = SubViewport.new()
	_vp.size = VIEW_SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(_vp)
	_camera = Camera2D.new()
	_rig = CameraRig.new()
	_vp.add_child(_camera)
	_vp.add_child(_rig)
	_rig.setup(_camera, MAP_PX, Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)))
	_rig.fit()
	_far = FarMap.new()
	_overlay = ModeOverlay.new()
	_vp.add_child(_far)
	_vp.add_child(_overlay)
	_overlay.setup_from(_make_map(8, 6), _make_owner(8, 6), _make_palette())
	_minimap = (load("res://shell/hud/minimap.tscn") as PackedScene).instantiate() as Minimap
	_vp.add_child(_minimap)
	_minimap.position = Vector2(0.0, 0.0)
	_minimap.size = AREA


func _make_map(cols: int, rows: int) -> MapData:
	var map := MapData.new()
	map.id = "minimap_fixture"
	map.allocate(cols, rows)
	for r: int in rows:
		for c: int in cols:
			var idx := r * cols + c
			map.land[idx] = 1
			map.cover[idx] = 0
			map.height_m[idx] = c * 120 + r * 80
	return map


func _make_owner(cols: int, rows: int) -> PackedByteArray:
	var owner := PackedByteArray()
	owner.resize(cols * rows)
	for i: int in owner.size():
		owner[i] = 1 if i % cols < int(cols * 0.5) else 2
	return owner


func _make_palette() -> PackedColorArray:
	return MapModes.palette_from(PackedColorArray([Color("#be3c6e"), Color("#3460b2")]), Color("#d8ccb0"))


func _bind() -> void:
	_minimap.bind(_far, _overlay, _rig, MAP_PX)
	await wait_process_frames(2)


func _click(at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	_minimap.pointer_event(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at
	_minimap.pointer_event(up)


func _motion(at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.relative = Vector2.ZERO
	_minimap.pointer_event(mm)


func _picture() -> Control:
	return _minimap.get_node("Picture") as Control


func _area_centre() -> Vector2:
	return _picture().position + _picture().size * 0.5


func test_geometry_letterbox_opening_and_clip() -> void:
	var area := Rect2(Vector2.ZERO, AREA)
	var box := Minimap.letterbox(area, MAP_PX)
	assert_almost_eq(box.size.x / box.size.y, MAP_PX.x / MAP_PX.y, 0.001, "letterbox keeps the map's aspect")
	assert_true(area.grow(0.01).encloses(box), "letterbox lies inside the area")
	assert_almost_eq(box.get_center().x, area.get_center().x, 0.01, "letterbox is centred")
	var opening := Minimap.opening_points(area)
	assert_eq(opening.size(), 6, "the opening is a hexagon")
	for p: Vector2 in opening:
		assert_true(area.grow(0.01).has_point(p), "opening inside the area")
	var clipped := Minimap.clip_to_rect(opening, box)
	for p: Vector2 in clipped:
		assert_true(box.grow(0.01).has_point(p), "clipped point inside the letterbox")
	# P: a polygon wholly outside the rect clips to nothing.
	var far_away := PackedVector2Array([Vector2(900, 900), Vector2(950, 900), Vector2(950, 950)])
	assert_eq(Minimap.clip_to_rect(far_away, box).size(), 0, "P: a polygon outside the rect clips away")


func test_click_glides_to_the_middle() -> void:
	await _bind()
	var asked: Array[Vector2] = []
	_minimap.look_at_requested.connect(func(p: Vector2) -> void: asked.append(p))
	_click(_area_centre())
	assert_eq(asked.size(), 1, "one click asks once")
	assert_almost_eq(asked[0].x, MAP_PX.x * 0.5, 2.0, "click at the middle asks for the map's middle (x)")
	assert_almost_eq(asked[0].y, MAP_PX.y * 0.5, 2.0, "click at the middle asks for the map's middle (y)")


func test_click_outside_the_map_clamps_to_the_map() -> void:
	await _bind()
	var asked: Array[Vector2] = []
	_minimap.look_at_requested.connect(func(p: Vector2) -> void: asked.append(p))
	_click(Vector2(-50.0, -50.0))
	assert_eq(asked.size(), 1)
	assert_true(Rect2(Vector2.ZERO, MAP_PX).has_point(asked[0]), "P: a click off the map never asks for a point off it")


func test_drag_jumps_and_does_not_glide() -> void:
	await _bind()
	var glides: Array[Vector2] = []
	var jumps: Array[Vector2] = []
	_minimap.look_at_requested.connect(func(p: Vector2) -> void: glides.append(p))
	_minimap.jump_requested.connect(func(p: Vector2) -> void: jumps.append(p))
	var start := _area_centre()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = start
	_minimap.pointer_event(down)
	_motion(start + Vector2(2.0, 0.0))
	assert_eq(jumps.size(), 0, "a move under the click slop is still a click")
	var target := start + Vector2(-40.0, 0.0)
	_motion(target)
	assert_eq(jumps.size(), 1, "a drag past the slop jumps")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = target
	_minimap.pointer_event(up)
	assert_eq(glides.size(), 0, "P: a drag never glides on release")
	assert_true(jumps[-1].x < MAP_PX.x * 0.5, "the jump follows the pointer to the left")


func test_frame_follows_the_view() -> void:
	await _bind()
	var view_before := _minimap.frame_rect()
	_rig.frame_at(MAP_PX * 0.5, 1.0)
	await wait_process_frames(2)
	var frame := _minimap.frame_rect()
	assert_ne(frame, view_before, "the frame moves with the view")
	var box := Minimap.letterbox(Rect2(Vector2.ZERO, _picture().size), MAP_PX)
	var expected_w := box.size.x * float(VIEW_SIZE.x) / MAP_PX.x
	assert_almost_eq(frame.size.x, expected_w, 0.5, "the frame is the view's width at this scale")
	assert_almost_eq(frame.get_center().x, box.get_center().x, 0.5, "the frame is centred on the view")
	_rig.frame_at(Vector2(60.0, 60.0), 1.0)
	await wait_process_frames(2)
	var edge := _minimap.frame_rect()
	assert_gte(edge.position.x, box.position.x - 0.01, "P: the frame is clipped to the picture (left)")
	assert_gte(edge.position.y, box.position.y - 0.01, "P: the frame is clipped to the picture (top)")


func test_hidden_without_a_game_and_with_the_setting_off() -> void:
	assert_false(_minimap.visible, "hidden before a game is bound")
	await _bind()
	assert_true(_minimap.visible, "shown once bound")
	var settings := Settings.new()
	settings.set_value("map/minimap", false)
	_minimap.configure(settings)
	assert_false(_minimap.visible, "hidden with map/minimap off")
	settings.set_value("map/minimap", true)
	assert_true(_minimap.visible, "shown again when the setting is on")
	_minimap.unbind()
	assert_false(_minimap.visible, "hidden after unbind")


func test_overlay_material_follows_the_mode() -> void:
	await _bind()
	var layer := _minimap.get_node("Overlay") as Control
	assert_not_null(layer.material, "the overlay layer has the minimap material")
	var mat := layer.material as ShaderMaterial
	assert_true(bool(mat.get_shader_parameter(&"from_uv")), "minimap material reads UVs")
	_overlay.set_mode(MapModes.Mode.OWNER)
	await wait_process_frames(2)
	var mat_after := layer.material as ShaderMaterial
	assert_eq(int(mat_after.get_shader_parameter(&"mode")), int(MapModes.Mode.OWNER), "mode switch reaches the minimap")
	assert_false(bool((_overlay.material as ShaderMaterial).get_shader_parameter(&"from_uv")), "the map's own material is unchanged")
