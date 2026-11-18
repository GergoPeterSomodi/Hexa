## Test harness for screen, kit, HUD and App GUT tests
## (docs/architecture/ui-and-controls-spec.md section 9; ui-and-controls-plan.md U5).
##
## Builds a 1280 x 720 SubViewport with a ScreenStack and a ShellContext backed by fresh
## in-memory Settings and registered Bindings.
class_name UIHarness
extends RefCounted

const DEFAULT_SIZE := Vector2i(1280, 720)

var viewport: SubViewport = null
var stack: ScreenStack = null
var settings: Settings = null
var ctx: ShellContext = null


func _init(p_size: Vector2i = DEFAULT_SIZE) -> void:
	Bindings.ensure()
	settings = Settings.new()
	viewport = SubViewport.new()
	viewport.size = p_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = false
	stack = ScreenStack.new()
	ctx = ShellContext.new(settings, stack)
	stack.setup(ctx)
	viewport.add_child(stack)


## Attaches the SubViewport to `owner_node` (using GutTest's auto-queue-free helper when available).
func mount(owner_node: Node) -> SubViewport:
	if viewport.get_parent() == null and owner_node != null:
		if owner_node.has_method("add_child_autoqfree"):
			owner_node.call("add_child_autoqfree", viewport)
		elif owner_node.has_method("add_child_autofree"):
			owner_node.call("add_child_autofree", viewport)
		else:
			owner_node.add_child(viewport)
	return viewport


## Sends an InputEvent directly into the SubViewport.
func push_input(event: InputEvent) -> void:
	if viewport != null and event != null:
		viewport.push_input(event)


## Sends a synthetic key press/release event into the SubViewport.
func send_key(
	keycode: Key,
	pressed: bool = true,
	ctrl: bool = false,
	shift: bool = false,
	alt: bool = false
) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	ev.ctrl_pressed = ctrl
	ev.shift_pressed = shift
	ev.alt_pressed = alt
	push_input(ev)


## Sends a mouse move, button press, and button release at `pos` in viewport coordinates.
func send_click(pos: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	push_input(motion)

	var press := InputEventMouseButton.new()
	press.button_index = button
	press.position = pos
	press.global_position = pos
	press.pressed = true
	push_input(press)

	var release := InputEventMouseButton.new()
	release.button_index = button
	release.position = pos
	release.global_position = pos
	release.pressed = false
	push_input(release)


## Awaits `frames` process frames on `owner_node`'s SceneTree.
func wait_frames(owner_node: Node, frames: int = 2) -> void:
	if owner_node == null or not owner_node.is_inside_tree():
		return
	var tree := owner_node.get_tree()
	if tree == null:
		return
	for _i: int in range(maxi(frames, 0)):
		await tree.process_frame


## Saves the rendered SubViewport texture to `path` as a PNG, or returns ERR_UNAVAILABLE
## when running under the headless dummy renderer or when no texture is available.
func shot(path: String) -> Error:
	if DisplayServer.get_name() == "headless":
		return ERR_UNAVAILABLE
	if viewport == null:
		return ERR_UNAVAILABLE
	var tex := viewport.get_texture()
	if tex == null:
		return ERR_UNAVAILABLE
	var img := tex.get_image()
	if img == null or img.is_empty():
		return ERR_UNAVAILABLE
	return img.save_png(path)


## Frees the SubViewport if not managed by mount().
func dispose() -> void:
	if viewport != null and is_instance_valid(viewport) and not viewport.is_queued_for_deletion():
		if viewport.get_parent() != null:
			viewport.get_parent().remove_child(viewport)
		viewport.queue_free()
	viewport = null
	stack = null
	ctx = null
	settings = null
