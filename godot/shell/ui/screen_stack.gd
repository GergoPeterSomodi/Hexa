## Manages the active stack of Screen nodes, focus history, Esc back-navigation,
## and the single modal shade ColorRect placed directly beneath the topmost MODAL screen
## (docs/architecture/ui-and-controls-spec.md section 3.2; ui-style-and-feedback-spec.md section 4.11).
class_name ScreenStack
extends Control

signal changed

var ctx: ShellContext = null

var _screens: Array[Screen] = []
var _focus_owners: Array[Control] = []
var _finished_callables: Dictionary[int, Callable] = {}
var _shade: ColorRect = null


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_shade()


## Stores the ShellContext passed to each pushed screen and registers this stack on context.stack.
func setup(context: ShellContext) -> void:
	ctx = context
	if ctx != null:
		ctx.stack = self


## Pushes a Screen onto the top of the stack, sets it up, syncs the modal shade, calls on_enter(),
## runs Motion.enter() for non-OPAQUE screens, grabs default_focus, and emits changed.
func push(screen: Screen) -> void:
	if screen == null or _screens.has(screen):
		return
	var prev_focus := _current_focus_owner()
	_screens.append(screen)
	_focus_owners.append(prev_focus)
	_mount_screen(screen)


## Pops the topmost Screen, calls on_exit(), restores saved focus, and returns it.
## Caller owns the returned Screen and is responsible for freeing or reusing it.
func pop() -> Screen:
	if _screens.is_empty():
		return null
	var top_screen := _screens[_screens.size() - 1]
	_detach_at(_screens.size() - 1, true)
	return top_screen


## Removes a specific Screen from the stack, calling on_exit() and restoring focus if it was top.
## Caller owns the removed Screen and is responsible for freeing or reusing it.
func remove(screen: Screen) -> void:
	if screen == null:
		return
	var idx := _screens.find(screen)
	if idx == -1:
		return
	var was_top := idx == _screens.size() - 1
	_detach_at(idx, was_top)


## Replaces the topmost Screen with `screen` (or pushes if empty), freeing the replaced screen
## and emitting `changed` once. Preserves the focus owner saved beneath the replaced screen.
func replace(screen: Screen) -> void:
	if screen == null:
		return
	if _screens.is_empty():
		push(screen)
		return
	if _screens.has(screen):
		return
	var top_idx := _screens.size() - 1
	var old_screen := _screens[top_idx]
	var inherited_focus := _focus_owners[top_idx]
	_disconnect_finished(old_screen)
	_screens.remove_at(top_idx)
	_focus_owners.remove_at(top_idx)
	if is_instance_valid(old_screen):
		old_screen.on_exit()
		if old_screen.get_parent() == self:
			remove_child(old_screen)
		old_screen.queue_free()

	_screens.append(screen)
	_focus_owners.append(inherited_focus)
	_mount_screen(screen)


## Pops and frees every Screen on the stack, hides the shade, restores bottom focus, and emits changed.
func clear() -> void:
	if _screens.is_empty():
		_sync_shade()
		return
	var base_focus := _focus_owners[0]
	for i: int in range(_screens.size() - 1, -1, -1):
		var s := _screens[i]
		_disconnect_finished(s)
		if is_instance_valid(s):
			s.on_exit()
			if s.get_parent() == self:
				remove_child(s)
			s.queue_free()
	_screens.clear()
	_focus_owners.clear()
	_sync_shade()
	_restore_focus(base_focus)
	changed.emit()


## Returns the topmost Screen, or null when empty.
func top() -> Screen:
	if _screens.is_empty():
		return null
	return _screens[_screens.size() - 1]


## Returns the number of screens currently on the stack.
func count() -> int:
	return _screens.size()


## Returns true if any screen on the stack has `screen_id == id`.
func has_screen(id: StringName) -> bool:
	for s: Screen in _screens:
		if is_instance_valid(s) and s.screen_id == id:
			return true
	return false


## Returns true when any MODAL or OPAQUE screen is on the stack (pauses the world tree).
func wants_pause() -> bool:
	for s: Screen in _screens:
		if is_instance_valid(s) and (s.kind == Screen.Kind.MODAL or s.kind == Screen.Kind.OPAQUE):
			return true
	return false


## Returns true when any OPAQUE screen is on the stack (hides the world and HUD).
func hides_world() -> bool:
	for s: Screen in _screens:
		if is_instance_valid(s) and s.kind == Screen.Kind.OPAQUE:
			return true
	return false


## Routes Esc to the topmost Screen. Returns false when empty; otherwise asks top().back(),
## popping and freeing top() if back() returns false.
func back() -> bool:
	var current := top()
	if current == null:
		return false
	if current.back():
		return true
	var popped := pop()
	if popped != null:
		popped.queue_free()
	return true


func _ensure_shade() -> ColorRect:
	if _shade == null:
		_shade = ColorRect.new()
		_shade.name = &"ModalShade"
		_shade.color = Tokens.SHADE
		_shade.mouse_filter = Control.MOUSE_FILTER_STOP
		_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_shade.visible = false
		add_child(_shade)
	return _shade


func _mount_screen(screen: Screen) -> void:
	_connect_finished(screen)
	screen.setup(ctx)
	add_child(screen)
	_sync_shade()
	screen.on_enter()
	if not is_instance_valid(screen) or not _screens.has(screen):
		return
	if screen.kind != Screen.Kind.OPAQUE:
		var target := screen.motion_target()
		if target != null:
			Motion.enter(target, _reduce_motion())
	_grab_default_focus(screen)
	changed.emit()


func _sync_shade() -> void:
	var shade := _ensure_shade()
	var top_modal: Screen = null
	for i: int in range(_screens.size() - 1, -1, -1):
		var candidate := _screens[i]
		if is_instance_valid(candidate) and candidate.kind == Screen.Kind.MODAL:
			top_modal = candidate
			break
	if top_modal == null:
		shade.visible = false
		if shade.get_index() != 0:
			move_child(shade, 0)
		return
	shade.visible = true
	var modal_idx := top_modal.get_index()
	var shade_idx := shade.get_index()
	if shade_idx < modal_idx:
		if shade_idx != modal_idx - 1:
			move_child(shade, modal_idx - 1)
	elif shade_idx > modal_idx:
		move_child(shade, modal_idx)


func _detach_at(idx: int, restore_focus: bool) -> void:
	var screen := _screens[idx]
	var saved_focus := _focus_owners[idx]
	_disconnect_finished(screen)
	if not restore_focus and idx + 1 < _focus_owners.size():
		var next_focus := _focus_owners[idx + 1]
		if (
			next_focus == null
			or not is_instance_valid(next_focus)
			or next_focus == screen
			or (is_instance_valid(screen) and screen.is_ancestor_of(next_focus))
		):
			_focus_owners[idx + 1] = saved_focus
	_screens.remove_at(idx)
	_focus_owners.remove_at(idx)
	if is_instance_valid(screen):
		screen.on_exit()
		if screen.get_parent() == self:
			remove_child(screen)
	_sync_shade()
	if restore_focus:
		_restore_focus(saved_focus)
	changed.emit()


func _connect_finished(screen: Screen) -> void:
	var key := screen.get_instance_id()
	if _finished_callables.has(key):
		return
	var cb := _on_screen_finished.bind(screen)
	_finished_callables[key] = cb
	if not screen.finished.is_connected(cb):
		screen.finished.connect(cb)


func _disconnect_finished(screen: Screen) -> void:
	if not is_instance_valid(screen):
		return
	var key := screen.get_instance_id()
	if not _finished_callables.has(key):
		return
	var cb: Callable = _finished_callables[key]
	_finished_callables.erase(key)
	if screen.finished.is_connected(cb):
		screen.finished.disconnect(cb)


func _on_screen_finished(_result: StringName, screen: Screen) -> void:
	if not is_instance_valid(screen):
		return
	remove(screen)
	screen.queue_free()


func _current_focus_owner() -> Control:
	var vp := get_viewport()
	if vp == null:
		return null
	var owner := vp.gui_get_focus_owner()
	if owner == null or not is_instance_valid(owner):
		return null
	return owner


func _grab_default_focus(screen: Screen) -> void:
	if screen.default_focus.is_empty():
		return
	var target := screen.get_node_or_null(screen.default_focus) as Control
	if target != null and target.is_inside_tree() and target.is_visible_in_tree() and target.focus_mode != Control.FOCUS_NONE:
		target.grab_focus()


func _restore_focus(ctrl: Control) -> void:
	if ctrl == null or not is_instance_valid(ctrl):
		return
	if not ctrl.is_inside_tree() or not ctrl.is_visible_in_tree():
		return
	if ctrl.focus_mode == Control.FOCUS_NONE:
		return
	ctrl.grab_focus()


func _reduce_motion() -> bool:
	if ctx != null and ctx.settings != null:
		return bool(ctx.settings.get_value("accessibility/reduce_motion"))
	return false
