## Base class for every UI screen scene pushed onto ScreenStack
## (docs/architecture/ui-and-controls-spec.md section 3.2).
class_name Screen
extends Control

enum Kind { MODAL, OPAQUE, OVERLAY }

signal finished(result: StringName)

@export var kind: Kind = Kind.MODAL
@export var default_focus: NodePath
@export var screen_id: StringName = &""

var ctx: ShellContext = null


## Called once by ScreenStack before on_enter(). Subclasses should call super.setup(context).
func setup(context: ShellContext) -> void:
	ctx = context


## Virtual hook called when this screen is pushed onto the stack.
func on_enter() -> void:
	pass


## Virtual hook called right before this screen is removed from the stack.
func on_exit() -> void:
	pass


## Virtual Esc handler. Return true if consumed internally; false lets ScreenStack pop this screen.
func back() -> bool:
	return false


## Returns the Control to animate with Motion.enter(). Defaults to the first non-full-rect child
## Control anchored at y = 0 for MODAL screens (since Motion.enter animates position.y to 0),
## or self otherwise.
func motion_target() -> Control:
	if kind == Kind.MODAL:
		for child: Node in get_children():
			var ctrl := child as Control
			if (
				ctrl != null
				and not _is_full_rect(ctrl)
				and is_zero_approx(ctrl.anchor_top)
				and is_zero_approx(ctrl.position.y)
			):
				return ctrl
	return self


func _is_full_rect(ctrl: Control) -> bool:
	return (
		is_zero_approx(ctrl.anchor_left)
		and is_zero_approx(ctrl.anchor_top)
		and is_equal_approx(ctrl.anchor_right, 1.0)
		and is_equal_approx(ctrl.anchor_bottom, 1.0)
	)
