## The minimap (docs/architecture/m2-build-spec.md section 7.8; ui-and-controls-spec.md section 7): the far picture
## in the hexagon frame, the map-mode overlay over it (ModeOverlay's material in UV mode, so no copy of the map), and
## the camera's rectangle in gold. A click glides the view there (look_at_requested); a drag jumps while held
## (jump_requested). It holds no facts: it reads FarMap, ModeOverlay and the CameraRig it is bound to, and asks for
## every move through its signals. Pure geometry is static, so tests and C17 can use it without a tree.
class_name Minimap
extends PanelContainer

signal look_at_requested(map_px: Vector2)
signal jump_requested(map_px: Vector2)

const CLICK_SLOP := 6.0
const FRAME_WIDTH := 2.0
const MIN_SIZE := Vector2(220.0, 124.0)
## The opening's two top and two bottom corners sit this far in from the ends, as a fraction of the width.
const CORNER_INSET := 0.12

var _settings: Settings = null
var _enabled_setting := true
var _bound := false
var _map_size := Vector2.ZERO
var _far: FarMap = null
var _mode_overlay: ModeOverlay = null
var _rig: CameraRig = null
var _view_rect := Rect2()
var _overlay_key := ""
var _blank: Texture2D = null
var _pressed := false
var _dragging := false
var _press_at := Vector2.ZERO

@onready var _picture: Control = $Picture
@onready var _overlay_layer: Control = $Overlay
@onready var _frame: Control = $Frame


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = MIN_SIZE
	_blank = ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	for layer: Control in [_picture, _overlay_layer, _frame]:
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.draw.connect(_draw_picture)
	_overlay_layer.draw.connect(_draw_overlay)
	_frame.draw.connect(_draw_frame)
	_refresh_visible()


func _exit_tree() -> void:
	_disconnect_rig()
	_disconnect_settings()


func _process(_delta: float) -> void:
	if not _bound:
		return
	var far_tex: Texture2D = _far.texture() if _far != null else null
	var key := "%d|%s|%d|%d|%d|%d" % [
		int(_mode_overlay.mode()),
		str(_mode_overlay.is_tint_on()),
		_mode_overlay.hot_id(),
		_id_of(far_tex),
		_id_of(_mode_overlay.owner_texture()),
		_id_of(_mode_overlay.palette_texture()),
	]
	if key != _overlay_key:
		_overlay_key = key
		_overlay_layer.material = _mode_overlay.material_for_minimap()
		refresh()


## Binds the picture, the overlay, the camera and the map's size in map px. Shows the minimap (with the setting on).
func bind(far: FarMap, overlay: ModeOverlay, rig: CameraRig, map_size: Vector2) -> void:
	_far = far
	_mode_overlay = overlay
	_map_size = map_size
	bind_camera_rig(rig)
	_bound = _far != null and _mode_overlay != null and _rig != null and map_size.x > 0.0 and map_size.y > 0.0
	_overlay_key = ""
	_refresh_visible()
	refresh()


## Binds the parts of a MapScene (its far picture, overlay and camera rig, with the rig's map size).
func bind_map_scene(scene: MapScene) -> void:
	if scene == null or scene.camera_rig() == null:
		unbind()
		return
	bind(scene.far(), scene.overlay(), scene.camera_rig(), scene.camera_rig().map_size)


## Follows a camera rig's view_changed (its visible rect is read at once).
func bind_camera_rig(rig: CameraRig) -> void:
	_disconnect_rig()
	_rig = rig
	if _rig == null:
		return
	_rig.view_changed.connect(_on_view_changed)
	_view_rect = _rig.visible_map_rect()


## Drops every binding (no game): the minimap hides.
func unbind() -> void:
	_disconnect_rig()
	_far = null
	_mode_overlay = null
	_map_size = Vector2.ZERO
	_bound = false
	_overlay_key = ""
	_overlay_layer.material = null
	_refresh_visible()


## Redraws the picture, the overlay and the frame.
func refresh() -> void:
	_picture.queue_redraw()
	_overlay_layer.queue_redraw()
	_frame.queue_redraw()


func is_bound() -> bool:
	return _bound


## Applies the Layers and Options switch "map/minimap" (live).
func configure(settings: Settings) -> void:
	if settings == _settings:
		if settings != null:
			_apply_settings(settings)
		return
	_disconnect_settings()
	_settings = settings
	if _settings == null:
		return
	_settings.changed.connect(_on_setting_changed)
	_apply_settings(_settings)


## The camera's rectangle in minimap px (clipped to the picture), empty when there is none.
func frame_rect() -> Rect2:
	if not _bound:
		return Rect2()
	var top_left := map_to_px(_view_rect.position)
	var bottom_right := map_to_px(_view_rect.end)
	return Rect2(top_left, bottom_right - top_left).intersection(letterbox(_area(), _map_size))


## A map px as a point in the picture's space (where the minimap draws it).
func map_to_px(map_px: Vector2) -> Vector2:
	var box := letterbox(_area(), _map_size)
	if _map_size.x <= 0.0 or _map_size.y <= 0.0:
		return box.position
	return box.position + (map_px / _map_size) * box.size


## A point in the picture's space as a map px, clamped to the map.
func px_to_map(point: Vector2) -> Vector2:
	var box := letterbox(_area(), _map_size)
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return Vector2.ZERO
	var unit := ((point - box.position) / box.size).clamp(Vector2.ZERO, Vector2.ONE)
	return unit * _map_size


## Handles one pointer event, in the minimap's own space (the GUI calls this; tests call it too).
func pointer_event(event: InputEvent) -> void:
	if not _bound:
		return
	if event is InputEventMouseButton:
		_on_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _pressed:
		_on_motion(event as InputEventMouseMotion)


func _gui_input(event: InputEvent) -> void:
	pointer_event(event)


func _on_button(mb: InputEventMouseButton) -> void:
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_pressed = true
		_dragging = false
		_press_at = _to_area(mb.position)
		return
	if not _pressed:
		return
	_pressed = false
	if not _dragging:
		look_at_requested.emit(px_to_map(_press_at))
	_dragging = false


func _on_motion(motion: InputEventMouseMotion) -> void:
	var point := _to_area(motion.position)
	if not _dragging and point.distance_to(_press_at) < CLICK_SLOP:
		return
	_dragging = true
	jump_requested.emit(px_to_map(point))


func _to_area(point: Vector2) -> Vector2:
	return point - _picture.position


func _area() -> Rect2:
	return Rect2(Vector2.ZERO, _picture.size)


func _draw_picture() -> void:
	var area := _area()
	_picture.draw_colored_polygon(opening_points(area), Tokens.SLOT)
	if _bound and _far.texture() != null:
		_draw_map_polygon(_picture, area, _far.texture())


func _draw_overlay() -> void:
	if not _bound or _overlay_layer.material == null:
		return
	var tex: Texture2D = _far.texture() if _far.texture() != null else _blank
	_draw_map_polygon(_overlay_layer, _area(), tex)


func _draw_frame() -> void:
	var rect := frame_rect()
	if rect.size.x > 0.0 and rect.size.y > 0.0:
		_frame.draw_rect(rect, Tokens.GOLD, false, FRAME_WIDTH)


## The opening, clipped to the map's letterbox, drawn with UVs over the map (0..1 across the letterbox).
func _draw_map_polygon(target: Control, area: Rect2, tex: Texture2D) -> void:
	var box := letterbox(area, _map_size)
	var quad := clip_to_rect(opening_points(area), box)
	if quad.size() < 3:
		return
	var uvs := PackedVector2Array()
	for p: Vector2 in quad:
		uvs.append((p - box.position) / box.size)
	target.draw_polygon(quad, PackedColorArray([Color.WHITE]), uvs, tex)


func _on_view_changed(_zoom: float, visible_rect: Rect2) -> void:
	_view_rect = visible_rect
	_frame.queue_redraw()


func _refresh_visible() -> void:
	visible = _bound and _enabled_setting


func _apply_settings(settings: Settings) -> void:
	_enabled_setting = bool(settings.get_value("map/minimap"))
	_refresh_visible()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "map/minimap" and _settings != null:
		_apply_settings(_settings)


func _disconnect_settings() -> void:
	if _settings != null and _settings.changed.is_connected(_on_setting_changed):
		_settings.changed.disconnect(_on_setting_changed)
	_settings = null


func _disconnect_rig() -> void:
	if _rig != null and is_instance_valid(_rig) and _rig.view_changed.is_connected(_on_view_changed):
		_rig.view_changed.disconnect(_on_view_changed)
	_rig = null


static func _id_of(tex: Texture2D) -> int:
	return tex.get_instance_id() if tex != null else 0


## The hexagon of the frame's opening inside `area`: points at the middle of both ends, corners inset at the top and bottom.
static func opening_points(area: Rect2) -> PackedVector2Array:
	var inset := area.size.x * CORNER_INSET
	var mid_y := area.get_center().y
	var left := area.position.x
	var right := area.end.x
	var top := area.position.y
	var bottom := area.end.y
	return PackedVector2Array([
		Vector2(left, mid_y),
		Vector2(left + inset, top),
		Vector2(right - inset, top),
		Vector2(right, mid_y),
		Vector2(right - inset, bottom),
		Vector2(left + inset, bottom),
	])


## The largest rectangle of the map's aspect ratio inside `area`, centred.
static func letterbox(area: Rect2, map_size: Vector2) -> Rect2:
	if map_size.x <= 0.0 or map_size.y <= 0.0 or area.size.x <= 0.0 or area.size.y <= 0.0:
		return area
	var scale_to := minf(area.size.x / map_size.x, area.size.y / map_size.y)
	var size := map_size * scale_to
	return Rect2(area.position + (area.size - size) * 0.5, size)


## A convex polygon clipped to a rectangle (Sutherland-Hodgman on the four sides).
static func clip_to_rect(poly: PackedVector2Array, rect: Rect2) -> PackedVector2Array:
	var step_a := _clip_axis(poly, 0, rect.position.x, true)
	var step_b := _clip_axis(step_a, 0, rect.end.x, false)
	var step_c := _clip_axis(step_b, 1, rect.position.y, true)
	return _clip_axis(step_c, 1, rect.end.y, false)


static func _clip_axis(poly: PackedVector2Array, axis: int, bound: float, keep_above: bool) -> PackedVector2Array:
	var result := PackedVector2Array()
	var count := poly.size()
	for i: int in count:
		var a := poly[i]
		var b := poly[(i + 1) % count]
		var a_in := _inside(_coord(a, axis), bound, keep_above)
		var b_in := _inside(_coord(b, axis), bound, keep_above)
		if a_in:
			result.append(a)
		if a_in != b_in:
			var t := (bound - _coord(a, axis)) / (_coord(b, axis) - _coord(a, axis))
			result.append(a.lerp(b, t))
	return result


static func _inside(value: float, bound: float, keep_above: bool) -> bool:
	return value >= bound if keep_above else value <= bound


static func _coord(point: Vector2, axis: int) -> float:
	return point.x if axis == 0 else point.y
