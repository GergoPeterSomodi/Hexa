## Pure Esc ladder decision rule (docs/architecture/ui-and-controls-spec.md section 3.3). M6: an army selected (its panel in the
## dock) is cleared at the dock step, before the hex selection (the App's CLEAR_SELECTION step clears the army first). The
## staged stops of a march go before the selection, all in one press (CLEAR_STOPS; moves-build-spec.md R61, D34).
class_name EscLadder
extends RefCounted

const NONE := &"none"
const STACK_BACK := &"stack_back"
const CLOSE_HUD_LIST := &"close_hud_list"
const CLEAR_STOPS := &"clear_stops"
const CLEAR_SELECTION := &"clear_selection"
const OPEN_PAUSE_MENU := &"open_pause_menu"


## Returns the action step for Esc given `{top_screen_id, has_screen, hud_list_open, has_stops, has_army, has_selection,
## dock_open}`.
static func decide(state: Dictionary) -> StringName:
	var top_screen_id := StringName(str(state.get("top_screen_id", &"")))
	if top_screen_id == &"loading" or top_screen_id == &"main_menu":
		return NONE
	var has_screen := bool(state.get("has_screen", top_screen_id != &""))
	if has_screen:
		return STACK_BACK
	if bool(state.get("hud_list_open", false)):
		return CLOSE_HUD_LIST
	if bool(state.get("has_stops", false)):
		return CLEAR_STOPS
	if bool(state.get("has_selection", false)) or bool(state.get("has_army", false)) or bool(state.get("dock_open", false)):
		return CLEAR_SELECTION
	return OPEN_PAUSE_MENU
