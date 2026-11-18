## Tests for Screen, ScreenStack, ScreenIds and UIHarness
## (docs/architecture/ui-and-controls-spec.md section 3.2 and 9; ui-style-and-feedback-spec.md section 4.11).
extends GutTest

const ALL_SPEC_SCREEN_IDS: Array[StringName] = [
	&"main_menu",
	&"sandbox",
	&"pause_menu",
	&"options",
	&"confirm",
	&"loading",
	&"help",
	&"credits",
	&"about",
	&"new_game",
	&"save_load",
	&"season_report",
	&"works_preview",
	&"study",
	&"tech",
	&"idea_pick",
	&"peace",
]


class SpyScreen:
	extends Screen

	var setup_ctx: ShellContext = null
	var enters: int = 0
	var exits: int = 0
	var back_calls: int = 0
	var consume_back: bool = false
	var primary_button: Button = null
	var frame: Control = null

	func _init(p_id: StringName = &"", p_kind: Screen.Kind = Screen.Kind.MODAL, with_frame: bool = true) -> void:
		screen_id = p_id
		kind = p_kind
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if with_frame:
			frame = Control.new()
			frame.name = &"Frame"
			frame.size = Vector2(320.0, 200.0)
			add_child(frame)
			primary_button = Button.new()
			primary_button.name = &"Primary"
			primary_button.text = String(p_id)
			primary_button.size = Vector2(120.0, 36.0)
			primary_button.position = Vector2(20.0, 20.0)
			frame.add_child(primary_button)
			default_focus = NodePath("Frame/Primary")

	func setup(context: ShellContext) -> void:
		super.setup(context)
		setup_ctx = context

	func on_enter() -> void:
		enters += 1

	func on_exit() -> void:
		exits += 1

	func back() -> bool:
		back_calls += 1
		return consume_back


func _shade_of(stack: ScreenStack) -> ColorRect:
	for child: Node in stack.get_children():
		if child is ColorRect:
			return child as ColorRect
	return null


func _shade_count(stack: ScreenStack) -> int:
	var n := 0
	for child: Node in stack.get_children():
		if child is ColorRect:
			n += 1
	return n


func test_push_pop_remove_replace_clear_and_changed_signal() -> void:
	var h := UIHarness.new()
	h.mount(self)
	var changes: Array[int] = [0]
	h.stack.changed.connect(func() -> void: changes[0] += 1)

	assert_eq(h.stack.count(), 0, "starts empty")
	assert_null(h.stack.top(), "top is null when empty")
	assert_null(h.stack.pop(), "pop on empty returns null")

	var a := SpyScreen.new(&"a", Screen.Kind.MODAL)
	var b := SpyScreen.new(&"b", Screen.Kind.OVERLAY)
	h.stack.push(a)
	assert_eq(changes[0], 1)
	assert_eq(h.stack.count(), 1)
	assert_eq(h.stack.top(), a)
	assert_eq(a.setup_ctx, h.ctx, "setup receives ShellContext")
	assert_eq(a.enters, 1, "on_enter called on push")
	assert_true(h.stack.has_screen(&"a"))
	assert_false(h.stack.has_screen(&"b"))

	h.stack.push(b)
	assert_eq(changes[0], 2)
	assert_eq(h.stack.count(), 2)
	assert_eq(h.stack.top(), b)
	assert_true(h.stack.has_screen(&"b"))

	# remove middle screen
	h.stack.remove(a)
	assert_eq(changes[0], 3)
	assert_eq(a.exits, 1, "remove calls on_exit")
	assert_false(a.is_inside_tree())
	assert_eq(h.stack.count(), 1)
	assert_eq(h.stack.top(), b)
	a.queue_free()

	# replace top screen emits changed once and frees old screen
	var c := SpyScreen.new(&"c", Screen.Kind.OPAQUE)
	h.stack.replace(c)
	assert_eq(changes[0], 4, "replace emits changed once")
	assert_eq(b.exits, 1, "replace calls on_exit on old top")
	assert_eq(c.enters, 1, "replace calls on_enter on new screen")
	assert_eq(h.stack.count(), 1)
	assert_eq(h.stack.top(), c)

	# pop returns screen (caller owns it)
	var d := SpyScreen.new(&"d", Screen.Kind.MODAL)
	h.stack.push(d)
	assert_eq(changes[0], 5)
	var popped := h.stack.pop()
	assert_eq(popped, d)
	assert_eq(d.exits, 1)
	assert_false(d.is_inside_tree())
	assert_eq(changes[0], 6)
	d.queue_free()

	# clear removes and frees remaining screens
	var e := SpyScreen.new(&"e", Screen.Kind.OVERLAY)
	h.stack.push(e)
	assert_eq(changes[0], 7)
	h.stack.clear()
	assert_eq(changes[0], 8)
	assert_eq(c.exits, 1)
	assert_eq(e.exits, 1)
	assert_eq(h.stack.count(), 0)
	assert_null(h.stack.top())


func test_wants_pause_and_hides_world_combinations() -> void:
	var h := UIHarness.new()
	h.mount(self)

	assert_false(h.stack.wants_pause())
	assert_false(h.stack.hides_world())

	var overlay := SpyScreen.new(&"help", Screen.Kind.OVERLAY)
	h.stack.push(overlay)
	assert_false(h.stack.wants_pause(), "OVERLAY alone does not pause")
	assert_false(h.stack.hides_world(), "OVERLAY alone does not hide world")

	var modal := SpyScreen.new(&"pause_menu", Screen.Kind.MODAL)
	h.stack.push(modal)
	assert_true(h.stack.wants_pause(), "MODAL pauses")
	assert_false(h.stack.hides_world(), "MODAL does not hide world")

	var opaque := SpyScreen.new(&"study", Screen.Kind.OPAQUE)
	h.stack.push(opaque)
	assert_true(h.stack.wants_pause(), "OPAQUE pauses")
	assert_true(h.stack.hides_world(), "OPAQUE hides world")

	var popped_opaque := h.stack.pop()
	popped_opaque.queue_free()
	assert_true(h.stack.wants_pause(), "MODAL still pauses after OPAQUE popped")
	assert_false(h.stack.hides_world(), "hides_world becomes false when OPAQUE popped")

	h.stack.clear()
	assert_false(h.stack.wants_pause())
	assert_false(h.stack.hides_world())


func test_single_modal_shade_ordering_and_visibility() -> void:
	var h := UIHarness.new()
	h.mount(self)

	assert_eq(_shade_count(h.stack), 1, "stack maintains exactly one shade ColorRect")
	var shade := _shade_of(h.stack)
	assert_not_null(shade)
	assert_eq(shade.color, Tokens.SHADE)
	assert_eq(shade.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_false(shade.visible, "shade hidden when empty")

	var overlay1 := SpyScreen.new(&"overlay1", Screen.Kind.OVERLAY)
	h.stack.push(overlay1)
	assert_false(shade.visible, "shade hidden when only OVERLAY is up")

	var opaque := SpyScreen.new(&"main_menu", Screen.Kind.OPAQUE)
	h.stack.push(opaque)
	assert_false(shade.visible, "shade hidden when only OPAQUE + OVERLAY are up")

	var modal1 := SpyScreen.new(&"pause_menu", Screen.Kind.MODAL)
	h.stack.push(modal1)
	assert_true(shade.visible, "shade visible when MODAL pushed")
	assert_eq(shade.get_index(), modal1.get_index() - 1, "shade directly under modal1")

	var modal2 := SpyScreen.new(&"options", Screen.Kind.MODAL)
	h.stack.push(modal2)
	assert_eq(_shade_count(h.stack), 1, "still only one shade ColorRect")
	assert_true(shade.visible)
	assert_eq(shade.get_index(), modal2.get_index() - 1, "shade moves directly under modal2")
	assert_gt(shade.get_index(), modal1.get_index(), "shade sits above modal1")

	var overlay2 := SpyScreen.new(&"help", Screen.Kind.OVERLAY)
	h.stack.push(overlay2)
	assert_eq(shade.get_index(), modal2.get_index() - 1, "shade stays under top MODAL when OVERLAY pushed above")

	var popped_overlay := h.stack.pop()
	popped_overlay.queue_free()
	var popped_m2 := h.stack.pop()
	popped_m2.queue_free()
	assert_true(shade.visible, "shade remains visible while modal1 is active")
	assert_eq(shade.get_index(), modal1.get_index() - 1, "shade moves back directly under modal1")

	var popped_m1 := h.stack.pop()
	popped_m1.queue_free()
	assert_false(shade.visible, "shade hides when last MODAL is popped")
	h.stack.clear()


func test_default_focus_and_focus_restoration() -> void:
	var h := UIHarness.new()
	var vp := h.mount(self)

	var outside_btn := Button.new()
	outside_btn.text = "Outside"
	vp.add_child(outside_btn)
	vp.move_child(outside_btn, 0)
	outside_btn.grab_focus()
	assert_eq(vp.gui_get_focus_owner(), outside_btn, "outside button initially focused")

	var screen_a := SpyScreen.new(&"a", Screen.Kind.MODAL)
	h.stack.push(screen_a)
	assert_eq(vp.gui_get_focus_owner(), screen_a.primary_button, "default_focus grabbed on push A")

	var screen_b := SpyScreen.new(&"b", Screen.Kind.MODAL)
	h.stack.push(screen_b)
	assert_eq(vp.gui_get_focus_owner(), screen_b.primary_button, "default_focus grabbed on push B")

	var popped_b := h.stack.pop()
	popped_b.queue_free()
	assert_eq(vp.gui_get_focus_owner(), screen_a.primary_button, "focus restored to A's button on pop B")

	var screen_c := SpyScreen.new(&"c", Screen.Kind.MODAL)
	h.stack.replace(screen_c)
	assert_eq(vp.gui_get_focus_owner(), screen_c.primary_button, "default_focus grabbed on replace C")

	var popped_c := h.stack.pop()
	popped_c.queue_free()
	assert_eq(vp.gui_get_focus_owner(), outside_btn, "focus restored to outside button after popping replaced screen")


func test_back_calls_screen_back_then_pops_and_frees() -> void:
	var h := UIHarness.new()
	h.mount(self)

	assert_false(h.stack.back(), "back returns false when empty")

	var s := SpyScreen.new(&"options", Screen.Kind.MODAL)
	s.consume_back = true
	h.stack.push(s)

	assert_true(h.stack.back(), "back returns true when screen consumes it")
	assert_eq(s.back_calls, 1)
	assert_eq(h.stack.count(), 1, "screen stays open when screen.back() returns true")
	assert_eq(s.exits, 0)

	s.consume_back = false
	assert_true(h.stack.back(), "back returns true when popping screen")
	assert_eq(s.back_calls, 2)
	assert_eq(s.exits, 1)
	assert_eq(h.stack.count(), 0, "screen popped when screen.back() returns false")


func test_finished_signal_auto_pops_and_frees_safely() -> void:
	var h := UIHarness.new()
	h.mount(self)

	var s := SpyScreen.new(&"confirm", Screen.Kind.MODAL)
	h.stack.push(s)
	assert_eq(h.stack.count(), 1)

	s.finished.emit(&"ok")
	assert_eq(h.stack.count(), 0, "finished signal pops the screen")
	assert_eq(s.exits, 1, "on_exit called once")
	assert_false(s.is_inside_tree())

	# Second emit is harmless (already disconnected and detached)
	s.finished.emit(&"ok")
	assert_eq(s.exits, 1, "second finished emit does not double-exit")


func test_motion_enter_respects_reduce_motion_and_opaque() -> void:
	var h := UIHarness.new()
	h.mount(self)

	h.settings.set_value("accessibility/reduce_motion", false)
	var modal := SpyScreen.new(&"pause_menu", Screen.Kind.MODAL)
	h.stack.push(modal)
	assert_almost_eq(modal.frame.position.y, Motion.ENTER_OFFSET_Y, 0.01, "modal target starts offset when reduce_motion is false")
	assert_almost_eq(modal.frame.modulate.a, 0.0, 0.01, "modal target starts transparent when reduce_motion is false")

	h.settings.set_value("accessibility/reduce_motion", true)
	var modal_reduced := SpyScreen.new(&"options", Screen.Kind.MODAL)
	h.stack.push(modal_reduced)
	assert_almost_eq(modal_reduced.frame.position.y, 0.0, 0.001, "reduce_motion snaps y to 0")
	assert_almost_eq(modal_reduced.frame.modulate.a, 1.0, 0.001, "reduce_motion snaps alpha to 1")

	var opaque := SpyScreen.new(&"main_menu", Screen.Kind.OPAQUE)
	opaque.frame.modulate.a = 0.75
	h.stack.push(opaque)
	assert_almost_eq(opaque.frame.modulate.a, 0.75, 0.001, "OPAQUE screen skips Motion.enter")
	h.stack.clear()


func test_screen_ids_registry_and_missing_scene_fails_loudly() -> void:
	for id: StringName in ALL_SPEC_SCREEN_IDS:
		assert_true(ScreenIds.has(id), "ScreenIds has %s" % String(id))
		assert_true(ScreenIds.path_of(id).begins_with("res://shell/screens/"), "path_of(%s) under shell/screens/" % String(id))
		assert_true(ScreenIds.path_of(id).ends_with(".tscn"), "path_of(%s) ends with .tscn" % String(id))

	assert_false(ScreenIds.has(&"nonexistent"))
	assert_eq(ScreenIds.path_of(&"nonexistent"), "")

	var missing_id := ScreenIds.make(&"nonexistent")
	assert_null(missing_id, "unknown screen id returns null")
	assert_push_error("unknown screen id")

	var missing_scene_id := &""
	for id: StringName in ALL_SPEC_SCREEN_IDS:
		if not ResourceLoader.exists(ScreenIds.path_of(id)):
			missing_scene_id = id
			break
	assert_ne(missing_scene_id, &"", "at least one future-milestone screen .tscn is absent")
	var missing_scene := ScreenIds.make(missing_scene_id)
	assert_null(missing_scene, "missing .tscn file returns null")
	assert_push_error("missing scene")


func test_ui_harness_input_and_headless_shot() -> void:
	var h := UIHarness.new()
	var vp := h.mount(self)
	assert_eq(vp.size, Vector2i(1280, 720))

	var s := SpyScreen.new(&"clickable", Screen.Kind.MODAL)
	var pressed_count: Array[int] = [0]
	s.primary_button.pressed.connect(func() -> void: pressed_count[0] += 1)
	h.stack.push(s)

	await h.wait_frames(self, 1)
	h.send_click(Vector2(40.0, 35.0))
	assert_eq(pressed_count[0], 1, "send_click triggers button inside mounted SubViewport")

	h.send_key(KEY_SPACE, true)
	h.send_key(KEY_SPACE, false)
	assert_eq(pressed_count[0], 2, "send_key delivers Space to focused button")

	assert_eq(h.shot("user://test_ui_harness_shot.png"), ERR_UNAVAILABLE, "headless shot returns ERR_UNAVAILABLE safely")
	h.stack.clear()


func test_intermediate_remove_transfers_saved_focus_to_next_screen() -> void:
	var h := UIHarness.new()
	var vp := h.mount(self)

	var outside_btn := Button.new()
	outside_btn.text = "Outside"
	vp.add_child(outside_btn)
	vp.move_child(outside_btn, 0)
	outside_btn.grab_focus()

	var screen_a := SpyScreen.new(&"a", Screen.Kind.MODAL)
	var screen_b := SpyScreen.new(&"b", Screen.Kind.MODAL)
	h.stack.push(screen_a)
	h.stack.push(screen_b)

	h.stack.remove(screen_a)
	screen_a.queue_free()
	assert_eq(vp.gui_get_focus_owner(), screen_b.primary_button, "top screen keeps focus after intermediate remove")

	var popped_b := h.stack.pop()
	popped_b.queue_free()
	assert_eq(vp.gui_get_focus_owner(), outside_btn, "popping B restores pre-A focus after A was removed")

	# Also verify when the intermediate screen root itself held focus
	var root_focus_screen := SpyScreen.new(&"root_focus", Screen.Kind.MODAL, false)
	root_focus_screen.focus_mode = Control.FOCUS_ALL
	root_focus_screen.default_focus = NodePath(".")
	var top_screen := SpyScreen.new(&"top", Screen.Kind.MODAL)
	h.stack.push(root_focus_screen)
	assert_eq(vp.gui_get_focus_owner(), root_focus_screen)
	h.stack.push(top_screen)

	h.stack.remove(root_focus_screen)
	root_focus_screen.queue_free()
	var popped_top := h.stack.pop()
	popped_top.queue_free()
	assert_eq(vp.gui_get_focus_owner(), outside_btn, "intermediate root-focused screen transfers pre-A focus")


func test_modal_shade_blocks_mouse_while_overlay_allows_pass_through() -> void:
	var h := UIHarness.new()
	var vp := h.mount(self)

	var behind_btn := Button.new()
	behind_btn.text = "Behind"
	behind_btn.position = Vector2(500.0, 300.0)
	behind_btn.size = Vector2(140.0, 40.0)
	vp.add_child(behind_btn)
	vp.move_child(behind_btn, 0)
	var hits: Array[int] = [0]
	behind_btn.pressed.connect(func() -> void: hits[0] += 1)

	await h.wait_frames(self, 1)
	h.send_click(Vector2(540.0, 320.0))
	assert_eq(hits[0], 1, "empty stack passes clicks through to underlying controls")

	var overlay := SpyScreen.new(&"overlay", Screen.Kind.OVERLAY)
	h.stack.push(overlay)
	await h.wait_frames(self, 1)
	h.send_click(Vector2(540.0, 320.0))
	assert_eq(hits[0], 2, "OVERLAY passes clicks outside its panels to underlying controls")

	var modal := SpyScreen.new(&"modal", Screen.Kind.MODAL)
	h.stack.push(modal)
	await h.wait_frames(self, 1)
	h.send_click(Vector2(540.0, 320.0))
	assert_eq(hits[0], 2, "MODAL shade blocks clicks outside modal panel from reaching underlying controls")
	h.stack.clear()


func test_centered_modal_child_does_not_lose_vertical_centering_on_enter() -> void:
	var h := UIHarness.new()
	h.mount(self)
	h.settings.set_value("accessibility/reduce_motion", true)

	var s := SpyScreen.new(&"centered", Screen.Kind.MODAL, false)
	var centered := Control.new()
	centered.set_anchors_preset(Control.PRESET_CENTER)
	centered.offset_left = -100.0
	centered.offset_top = -50.0
	centered.offset_right = 100.0
	centered.offset_bottom = 50.0
	s.add_child(centered)
	h.stack.push(s)
	await h.wait_frames(self, 1)

	assert_eq(s.motion_target(), s, "centered child falls back to screen root so Motion.enter preserves centering")
	assert_gt(centered.position.y, 100.0, "centered modal child stays vertically centered")
	h.stack.clear()
