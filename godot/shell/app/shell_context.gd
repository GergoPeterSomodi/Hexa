## Context object owned by the App and passed to screens and the HUD
## (docs/architecture/ui-and-controls-spec.md section 3.2). Screens read game state via Session
## and ask the App for app-level operations (toasts, quit, main menu, sandbox, fullscreen, screenshot,
## look_at) through this context rather than reaching the App or World by node path.
class_name ShellContext
extends RefCounted

signal toast_requested(text: String, tone: StringName)
signal app_requested(what: StringName, args: Dictionary)

var settings: Settings = null
var stack: Control = null


func _init(p_settings: Settings = null, p_stack: Control = null) -> void:
	settings = p_settings
	stack = p_stack


func toast(text: String, tone: StringName = &"plain") -> void:
	toast_requested.emit(text, tone)


func request(what: StringName, args: Dictionary = {}) -> void:
	app_requested.emit(what, args)
