## Pure Esc ladder decision rule (docs/architecture/ui-and-controls-spec.md section 3.3).
class_name EscLadder
extends RefCounted

const NONE := &"none"
const STACK_BACK := &"stack_back"
const CLOSE_HUD_LIST := &"close_hud_list"
const CLEAR_SELECTION := &"clear_selection"
const OPEN_PAUSE_MENU := &"open_pause_menu"


## Returns the action step for Esc given `{top_screen_id, has_screen, hud_list_open, has_selection, dock_open}`.
static func decide(state: Dictionary) -> StringName:
	var top_screen_id := StringName(str(state.get("top_screen_id", &"")))
	if top_screen_id == &"loading" or top_screen_id == &"main_menu":
		return NONE
	var has_screen := bool(state.get("has_screen", top_screen_id != &""))
	if has_screen:
		return STACK_BACK
	if bool(state.get("hud_list_open", false)):
		return CLOSE_HUD_LIST
	if bool(state.get("has_selection", false)) or bool(state.get("dock_open", false)):
		return CLEAR_SELECTION
	return OPEN_PAUSE_MENU
