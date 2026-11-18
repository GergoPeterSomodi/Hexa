## InputMap action table, platform gestures, event parsing/serialization and overrides
## (docs/architecture/ui-and-controls-spec.md section 4.1, docs/architecture/ui-style-and-feedback-spec.md section 9).
class_name Bindings
extends RefCounted

const GROUPS: Array[String] = ["Camera", "Map", "View", "Game", "Developer", "App"]

const DEFAULTS: Array[Dictionary] = [
	# Camera
	{"action": &"cam_pan_left", "label": "Pan left", "group": "Camera", "since": "1",
		"events": ["A", "Left"] as Array[String], "physical": true},
	{"action": &"cam_pan_right", "label": "Pan right", "group": "Camera", "since": "1",
		"events": ["D", "Right"] as Array[String], "physical": true},
	{"action": &"cam_pan_up", "label": "Pan up", "group": "Camera", "since": "1",
		"events": ["W", "Up"] as Array[String], "physical": true},
	{"action": &"cam_pan_down", "label": "Pan down", "group": "Camera", "since": "1",
		"events": ["S", "Down"] as Array[String], "physical": true},
	{"action": &"cam_pan_fast", "label": "Fast pan", "group": "Camera", "since": "1.5",
		"events": ["Shift"] as Array[String]},
	{"action": &"cam_zoom_in", "label": "Zoom in", "group": "Camera", "since": "1.5",
		"events": ["=", "+", "Kp+"] as Array[String]},
	{"action": &"cam_zoom_out", "label": "Zoom out", "group": "Camera", "since": "1.5",
		"events": ["-", "Kp-"] as Array[String]},
	{"action": &"cam_fit", "label": "Fit whole map", "group": "Camera", "since": "1",
		"events": ["F", "Home"] as Array[String]},
	# Map
	{"action": &"map_select", "label": "Select hex", "group": "Map", "since": "1",
		"events": ["MouseLeft"] as Array[String]},
	{"action": &"map_command", "label": "Clear or command", "group": "Map", "since": "1",
		"events": ["MouseRight"] as Array[String]},
	# View
	{"action": &"view_grid", "label": "Hex grid", "group": "View", "since": "1",
		"events": ["G"] as Array[String]},
	{"action": &"view_names", "label": "Place names", "group": "View", "since": "1.5",
		"events": ["N"] as Array[String]},
	{"action": &"view_hud", "label": "Hide HUD (photo mode)", "group": "View", "since": "1",
		"events": ["H"] as Array[String]},
	# Game (M1)
	{"action": &"game_upgrade", "label": "Upgrade hex", "group": "Game", "since": "1",
		"events": ["U"] as Array[String]},
	# Developer
	{"action": &"dev_new_seed", "label": "New seed", "group": "Developer", "since": "1.5",
		"events": ["Ctrl+R"] as Array[String]},
	{"action": &"dev_debug", "label": "Debug panel", "group": "Developer", "since": "1.5",
		"events": ["F3", "QuoteLeft"] as Array[String]},
	# App
	{"action": &"app_back", "label": "Back / Pause", "group": "App", "since": "1.5",
		"events": ["Escape"] as Array[String]},
	{"action": &"app_menu", "label": "Pause menu", "group": "App", "since": "1.5",
		"events": ["M"] as Array[String]},
	{"action": &"app_help", "label": "Help and keys", "group": "App", "since": "1.5",
		"events": ["F1", "Shift+Slash"] as Array[String]},
	{"action": &"app_fullscreen", "label": "Fullscreen", "group": "App", "since": "1.5",
		"events": ["F11", "Alt+Enter", "Ctrl+Meta+F"] as Array[String]},
	{"action": &"app_screenshot", "label": "Screenshot", "group": "App", "since": "1.5",
		"events": ["F12"] as Array[String]},
	# Milestone 2+
	{"action": &"view_mode_1", "label": "Map mode 1", "group": "View", "since": "2",
		"events": ["1"] as Array[String]},
	{"action": &"view_mode_2", "label": "Map mode 2", "group": "View", "since": "2",
		"events": ["2"] as Array[String]},
	{"action": &"view_mode_3", "label": "Map mode 3", "group": "View", "since": "2",
		"events": ["3"] as Array[String]},
	{"action": &"view_mode_4", "label": "Map mode 4", "group": "View", "since": "2",
		"events": ["4"] as Array[String]},
	{"action": &"ui_find_place", "label": "Find place", "group": "View", "since": "2",
		"events": ["Ctrl+F"] as Array[String]},
	{"action": &"game_country", "label": "Country panel", "group": "Game", "since": "2",
		"events": ["C"] as Array[String]},
	{"action": &"game_end_season", "label": "End season", "group": "Game", "since": "3",
		"events": ["Space", "Enter"] as Array[String]},
	{"action": &"game_report", "label": "Season report", "group": "Game", "since": "3",
		"events": ["J"] as Array[String]},
	{"action": &"game_quicksave", "label": "Quicksave", "group": "Game", "since": "3",
		"events": ["F5", "Ctrl+S"] as Array[String]},
	{"action": &"game_quickload", "label": "Quickload", "group": "Game", "since": "3",
		"events": ["F9", "Ctrl+L"] as Array[String]},
	{"action": &"game_undo_work", "label": "Cancel work", "group": "Game", "since": "3",
		"events": ["Ctrl+Z"] as Array[String]},
	{"action": &"dev_console", "label": "Developer console", "group": "Developer", "since": "3",
		"events": ["F2"] as Array[String]},
	{"action": &"cam_bookmark_go_1", "label": "Go to bookmark 1", "group": "Camera", "since": "3",
		"events": ["Ctrl+1"] as Array[String]},
	{"action": &"cam_bookmark_go_2", "label": "Go to bookmark 2", "group": "Camera", "since": "3",
		"events": ["Ctrl+2"] as Array[String]},
	{"action": &"cam_bookmark_go_3", "label": "Go to bookmark 3", "group": "Camera", "since": "3",
		"events": ["Ctrl+3"] as Array[String]},
	{"action": &"cam_bookmark_go_4", "label": "Go to bookmark 4", "group": "Camera", "since": "3",
		"events": ["Ctrl+4"] as Array[String]},
	{"action": &"cam_bookmark_go_5", "label": "Go to bookmark 5", "group": "Camera", "since": "3",
		"events": ["Ctrl+5"] as Array[String]},
	{"action": &"cam_bookmark_go_6", "label": "Go to bookmark 6", "group": "Camera", "since": "3",
		"events": ["Ctrl+6"] as Array[String]},
	{"action": &"cam_bookmark_go_7", "label": "Go to bookmark 7", "group": "Camera", "since": "3",
		"events": ["Ctrl+7"] as Array[String]},
	{"action": &"cam_bookmark_go_8", "label": "Go to bookmark 8", "group": "Camera", "since": "3",
		"events": ["Ctrl+8"] as Array[String]},
	{"action": &"cam_bookmark_go_9", "label": "Go to bookmark 9", "group": "Camera", "since": "3",
		"events": ["Ctrl+9"] as Array[String]},
	{"action": &"cam_bookmark_set_1", "label": "Set bookmark 1", "group": "Camera", "since": "3",
		"events": ["Ctrl+Shift+1"] as Array[String]},
	{"action": &"cam_bookmark_set_2", "label": "Set bookmark 2", "group": "Camera", "since": "3",
		"events": ["Ctrl+Shift+2"] as Array[String]},
	{"action": &"cam_bookmark_set_3", "label": "Set bookmark 3", "group": "Camera", "since": "3",
		"events": ["Ctrl+Shift+3"] as Array[String]},
	{"action": &"cam_bookmark_set_4", "label": "Set bookmark 4", "group": "Camera", "since": "3",
		"events": ["Ctrl+Shift+4"] as Array[String]},
	{"action": &"cam_bookmark_set_5", "label": "Set bookmark 5", "group": "Camera", "since": "3",
		"events": ["Ctrl+Shift+5"] as Array[String]},
	{"action": &"cam_bookmark_set_6", "label": "Set bookmark 6", "group": "Camera", "since": "3",
		"events": ["Ctrl+Shift+6"] as Array[String]},
	{"action": &"cam_bookmark_set_7", "label": "Set bookmark 7", "group": "Camera", "since": "3",
		"events": ["Ctrl+Shift+7"] as Array[String]},
	{"action": &"cam_bookmark_set_8", "label": "Set bookmark 8", "group": "Camera", "since": "3",
		"events": ["Ctrl+Shift+8"] as Array[String]},
	{"action": &"cam_bookmark_set_9", "label": "Set bookmark 9", "group": "Camera", "since": "3",
		"events": ["Ctrl+Shift+9"] as Array[String]},
	{"action": &"game_study", "label": "Statesman's Study", "group": "Game", "since": "4",
		"events": ["I"] as Array[String]},
	{"action": &"game_ledger", "label": "Economy ledger", "group": "Game", "since": "4",
		"events": ["L"] as Array[String]},
	{"action": &"study_page_prev", "label": "Previous study page", "group": "Game", "since": "4",
		"events": ["BracketLeft"] as Array[String]},
	{"action": &"study_page_next", "label": "Next study page", "group": "Game", "since": "4",
		"events": ["BracketRight"] as Array[String]},
	{"action": &"study_tab_prev", "label": "Previous study tab", "group": "Game", "since": "4.5",
		"events": ["Ctrl+BracketLeft"] as Array[String]},
	{"action": &"study_tab_next", "label": "Next study tab", "group": "Game", "since": "4.5",
		"events": ["Ctrl+BracketRight"] as Array[String]},
	{"action": &"game_next_unit", "label": "Next unit", "group": "Game", "since": "6",
		"events": ["Tab"] as Array[String]},
	{"action": &"game_continue_march", "label": "Continue march", "group": "Game", "since": "6",
		"events": ["R"] as Array[String]},
	{"action": &"map_cursor_left", "label": "Move hex cursor left", "group": "Map", "since": "6",
		"events": ["Alt+Left"] as Array[String]},
	{"action": &"map_cursor_right", "label": "Move hex cursor right", "group": "Map", "since": "6",
		"events": ["Alt+Right"] as Array[String]},
	{"action": &"map_cursor_up", "label": "Move hex cursor up", "group": "Map", "since": "6",
		"events": ["Alt+Up"] as Array[String]},
	{"action": &"map_cursor_down", "label": "Move hex cursor down", "group": "Map", "since": "6",
		"events": ["Alt+Down"] as Array[String]},
	{"action": &"game_tech", "label": "Technology screen", "group": "Game", "since": "11",
		"events": ["T"] as Array[String]},
]

const GESTURES: Dictionary = {
	"macOS": [
		"Two-finger scroll: pan the map",
		"Trackpad pinch or mouse wheel: zoom about the pointer",
		"Left, middle or right drag: pan the map",
		"Two-finger click or right click: clear the selection",
		"Shift: hold the works card",
	] as Array[String],
	"Windows": [
		"Mouse wheel or Ctrl+wheel (touchpad pinch): zoom about the pointer",
		"Shift+wheel or tilt wheel: pan sideways",
		"Left, middle or right drag: pan the map",
		"Right click: clear the selection",
		"Shift: hold the works card",
	] as Array[String],
	"Linux": [
		"Mouse wheel or Ctrl+wheel (touchpad pinch): zoom about the pointer",
		"Shift+wheel or tilt wheel: pan sideways",
		"Left, middle or right drag: pan the map",
		"Right click: clear the selection",
		"Shift: hold the works card",
	] as Array[String],
	"default": [
		"Mouse wheel or Ctrl+wheel (touchpad pinch): zoom about the pointer",
		"Shift+wheel or tilt wheel: pan sideways",
		"Left, middle or right drag: pan the map",
		"Right click: clear the selection",
		"Shift: hold the works card",
	] as Array[String],
}

const _SPECIAL_TO_KEY: Dictionary = {
	"=": KEY_EQUAL,
	"Equal": KEY_EQUAL,
	"+": KEY_PLUS,
	"Plus": KEY_PLUS,
	"Kp+": KEY_KP_ADD,
	"Kp Add": KEY_KP_ADD,
	"-": KEY_MINUS,
	"Minus": KEY_MINUS,
	"Kp-": KEY_KP_SUBTRACT,
	"Kp Subtract": KEY_KP_SUBTRACT,
	"`": KEY_QUOTELEFT,
	"QuoteLeft": KEY_QUOTELEFT,
	"[": KEY_BRACKETLEFT,
	"BracketLeft": KEY_BRACKETLEFT,
	"]": KEY_BRACKETRIGHT,
	"BracketRight": KEY_BRACKETRIGHT,
	"/": KEY_SLASH,
	"Slash": KEY_SLASH,
	"Esc": KEY_ESCAPE,
	"Escape": KEY_ESCAPE,
	"Return": KEY_ENTER,
	"Enter": KEY_ENTER,
}

const _KEY_TO_CANONICAL: Dictionary = {
	KEY_EQUAL: "=",
	KEY_PLUS: "+",
	KEY_KP_ADD: "Kp+",
	KEY_MINUS: "-",
	KEY_KP_SUBTRACT: "Kp-",
	KEY_QUOTELEFT: "QuoteLeft",
	KEY_BRACKETLEFT: "BracketLeft",
	KEY_BRACKETRIGHT: "BracketRight",
	KEY_SLASH: "Slash",
	KEY_ESCAPE: "Escape",
	KEY_ENTER: "Enter",
}

const _KEY_TO_DISPLAY: Dictionary = {
	KEY_EQUAL: "=",
	KEY_PLUS: "+",
	KEY_KP_ADD: "Kp+",
	KEY_MINUS: "-",
	KEY_KP_SUBTRACT: "Kp-",
	KEY_QUOTELEFT: "`",
	KEY_BRACKETLEFT: "[",
	KEY_BRACKETRIGHT: "]",
	KEY_SLASH: "/",
	KEY_ESCAPE: "Esc",
	KEY_ENTER: "Enter",
}


## Platform gesture lines for the help overlay.
static func gestures_for(platform: String = OS.get_name()) -> Array[String]:
	var list: Array = GESTURES.get(platform, GESTURES["default"])
	var out: Array[String] = []
	for line: Variant in list:
		out.append(str(line))
	return out


## Registers actions from DEFAULTS up to `up_to_milestone` into Godot's InputMap.
static func ensure(up_to_milestone: String = "12") -> void:
	var max_m := float(up_to_milestone)
	for entry: Dictionary in DEFAULTS:
		if float(str(entry["since"])) > max_m:
			continue
		_install_entry(entry)


## Restores all DEFAULTS events in InputMap.
static func reset_defaults() -> void:
	for entry: Dictionary in DEFAULTS:
		_install_entry(entry)


static func _install_entry(entry: Dictionary) -> void:
	var action: StringName = entry["action"]
	var physical := bool(entry.get("physical", false))
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	else:
		InputMap.action_erase_events(action)
	var ev_names: Array = entry["events"]
	for raw: Variant in ev_names:
		var ev := parse_event(str(raw))
		if ev == null:
			continue
		if physical and ev is InputEventKey:
			var key_ev := ev as InputEventKey
			if key_ev.keycode != KEY_NONE:
				key_ev.physical_keycode = key_ev.keycode
				key_ev.keycode = KEY_NONE
		InputMap.action_add_event(action, ev)


## Applies `action -> event_text_or_array` overrides onto InputMap.
## Refuses unknown actions, unparseable strings, or clashes within the same group & active milestone.
static func apply_overrides(overrides: Dictionary) -> Dictionary:
	ensure()
	var conflicts: Dictionary = {}
	for raw_action: Variant in overrides.keys():
		var action := StringName(str(raw_action))
		var entry := _find_entry(action)
		if entry.is_empty():
			conflicts[action] = &"unknown_action"
			continue
		var parsed := _parse_override_value(overrides[raw_action], bool(entry.get("physical", false)))
		if parsed.is_empty():
			conflicts[action] = &"invalid_event"
			continue
		var clash := _find_clash(entry, parsed)
		if clash != &"":
			conflicts[action] = clash
			continue
		InputMap.action_erase_events(action)
		for ev: InputEvent in parsed:
			InputMap.action_add_event(action, ev)
	return {"ok": conflicts.is_empty(), "conflicts": conflicts}


static func _parse_override_value(raw_val: Variant, physical: bool) -> Array[InputEvent]:
	var texts: Array[String] = []
	if raw_val is String:
		var s := (raw_val as String).strip_edges()
		if s == "":
			return []
		if parse_event(s) != null:
			texts.append(s)
		elif s.contains(","):
			for part: String in s.split(",", false):
				texts.append(part.strip_edges())
		else:
			return []
	elif raw_val is Array or raw_val is PackedStringArray:
		for item: Variant in raw_val:
			var part := str(item).strip_edges()
			if part == "":
				return []
			texts.append(part)
	else:
		return []
	if texts.is_empty():
		return []
	var events: Array[InputEvent] = []
	var seen: Dictionary = {}
	for t: String in texts:
		var ev := parse_event(t)
		if ev == null:
			return []
		var canonical := serialize_event(ev)
		if seen.has(canonical):
			return []
		seen[canonical] = true
		if physical and ev is InputEventKey:
			var key_ev := ev as InputEventKey
			if key_ev.keycode != KEY_NONE:
				key_ev.physical_keycode = key_ev.keycode
				key_ev.keycode = KEY_NONE
		events.append(ev)
	return events


static func _find_clash(entry: Dictionary, candidate_events: Array[InputEvent]) -> StringName:
	var action: StringName = entry["action"]
	var group := str(entry["group"])
	var candidate_keys: Dictionary = {}
	for ev: InputEvent in candidate_events:
		candidate_keys[serialize_event(ev)] = true
	for other: Dictionary in DEFAULTS:
		var other_action: StringName = other["action"]
		if other_action == action or str(other["group"]) != group:
			continue
		if not _milestones_overlap(entry, other):
			continue
		for other_ev: InputEvent in events_for(other_action):
			if candidate_keys.has(serialize_event(other_ev)):
				return other_action
	return &""


static func _milestones_overlap(a: Dictionary, b: Dictionary) -> bool:
	var a_start := float(str(a["since"]))
	var a_end := float(str(a.get("until", "999")))
	var b_start := float(str(b["since"]))
	var b_end := float(str(b.get("until", "999")))
	return maxf(a_start, b_start) <= minf(a_end, b_end)


static func _find_entry(action: StringName) -> Dictionary:
	for entry: Dictionary in DEFAULTS:
		if entry["action"] == action:
			return entry
	return {}


## Canonical round-trip serialization of an InputEvent (matches DEFAULTS event strings).
static func serialize_event(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				return "MouseLeft"
			MOUSE_BUTTON_RIGHT:
				return "MouseRight"
			MOUSE_BUTTON_MIDDLE:
				return "MouseMiddle"
			_:
				return ""
	if event is InputEventKey:
		var key_ev := event as InputEventKey
		var code: Key = key_ev.keycode if key_ev.keycode != KEY_NONE else key_ev.physical_keycode
		if code == KEY_NONE:
			return ""
		var base := _canonical_key_name(code)
		if base == "":
			return ""
		if code in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			return base
		var parts: Array[String] = []
		if key_ev.command_or_control_autoremap:
			parts.append("Ctrl")
		else:
			if key_ev.ctrl_pressed:
				parts.append("Ctrl")
		if key_ev.alt_pressed:
			parts.append("Alt")
		if key_ev.shift_pressed:
			parts.append("Shift")
		if key_ev.meta_pressed and not key_ev.command_or_control_autoremap:
			parts.append("Meta")
		parts.append(base)
		return "+".join(parts)
	return ""


## Human-readable key cap / display text for `event` on `platform` ("macOS", "Windows", "Linux").
static func event_text(event: InputEvent, platform: String = OS.get_name()) -> String:
	if event is InputEventMouseButton:
		return serialize_event(event)
	if event is InputEventKey:
		var key_ev := event as InputEventKey
		var code: Key = key_ev.keycode if key_ev.keycode != KEY_NONE else key_ev.physical_keycode
		if code == KEY_NONE:
			return ""
		var is_mac := platform == "macOS"
		if code == KEY_SLASH and key_ev.shift_pressed and not key_ev.alt_pressed and not key_ev.ctrl_pressed and not key_ev.meta_pressed and not key_ev.command_or_control_autoremap:
			return "?"
		var base := _display_key_name(code)
		if base == "":
			return ""
		if code in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			return "Cmd" if (code == KEY_META and is_mac) else base
		var parts: Array[String] = []
		if key_ev.command_or_control_autoremap:
			parts.append("Cmd" if is_mac else "Ctrl")
		elif key_ev.ctrl_pressed:
			parts.append("Ctrl")
		if key_ev.alt_pressed:
			parts.append("Opt" if is_mac else "Alt")
		if key_ev.shift_pressed:
			parts.append("Shift")
		if key_ev.meta_pressed and not key_ev.command_or_control_autoremap:
			parts.append("Cmd" if is_mac else "Meta")
		parts.append(base)
		return "+".join(parts)
	return ""


static func _canonical_key_name(code: Key) -> String:
	if _KEY_TO_CANONICAL.has(code):
		return str(_KEY_TO_CANONICAL[code])
	return OS.get_keycode_string(code)


static func _display_key_name(code: Key) -> String:
	if _KEY_TO_DISPLAY.has(code):
		return str(_KEY_TO_DISPLAY[code])
	return OS.get_keycode_string(code)


## Parses a canonical or display event string back into an InputEventKey or InputEventMouseButton, or null.
static func parse_event(text: String) -> InputEvent:
	var s := text.strip_edges()
	if s == "":
		return null
	if s == "MouseLeft" or s == "LeftClick":
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = true
		return mb
	if s == "MouseRight" or s == "RightClick":
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_RIGHT
		mb.pressed = true
		return mb
	if s == "MouseMiddle" or s == "MiddleClick":
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_MIDDLE
		mb.pressed = true
		return mb
	if s == "?":
		var q_ev := InputEventKey.new()
		q_ev.keycode = KEY_SLASH
		q_ev.shift_pressed = true
		q_ev.pressed = true
		return q_ev
	return _parse_key_event(s)


static func _parse_key_event(s: String) -> InputEventKey:
	var physical_only := false
	var body := s
	if body.begins_with("Physical:"):
		physical_only = true
		body = body.substr(len("Physical:")).strip_edges()
	if body == "":
		return null
	var tokens := _split_chord(body)
	if tokens.is_empty():
		return null
	var key_token := tokens[tokens.size() - 1]
	var code := _find_keycode(key_token)
	if code == KEY_NONE:
		return null
	var want_ctrl := false
	var want_alt := false
	var want_shift := false
	var want_meta := false
	for i: int in range(tokens.size() - 1):
		match tokens[i]:
			"Ctrl", "Control":
				want_ctrl = true
			"Alt", "Opt", "Option":
				want_alt = true
			"Shift":
				want_shift = true
			"Meta", "Cmd", "Command":
				want_meta = true
			_:
				return null
	var ev := InputEventKey.new()
	ev.pressed = true
	if physical_only:
		ev.physical_keycode = code
	else:
		ev.keycode = code
	if (want_ctrl and not want_meta) or (want_meta and not want_ctrl):
		ev.command_or_control_autoremap = true
	else:
		ev.ctrl_pressed = want_ctrl
		ev.meta_pressed = want_meta
	ev.alt_pressed = want_alt
	ev.shift_pressed = want_shift
	return ev


static func _split_chord(body: String) -> Array[String]:
	if body == "+" or body == "Kp+":
		return [body]
	var out: Array[String] = []
	var cur := ""
	var i := 0
	while i < body.length():
		var ch := body[i]
		if ch == "+" and cur != "" and cur != "Kp":
			out.append(cur)
			cur = ""
		else:
			cur += ch
		i += 1
	if cur == "":
		return []
	out.append(cur)
	return out


static func _find_keycode(token: String) -> Key:
	if _SPECIAL_TO_KEY.has(token):
		return _SPECIAL_TO_KEY[token] as Key
	return OS.find_keycode_from_string(token)


## Returns the InputEvents currently bound to `action` in InputMap.
static func events_for(action: StringName) -> Array[InputEvent]:
	if not InputMap.has_action(action):
		return []
	return InputMap.action_get_events(action)


## Returns human-readable key cap strings for `action` from the live InputMap.
static func key_caps_for(action: StringName, platform: String = OS.get_name()) -> Array[String]:
	var caps: Array[String] = []
	for ev: InputEvent in events_for(action):
		var cap := event_text(ev, platform)
		if cap != "":
			caps.append(cap)
	return caps
