## Player settings in user://settings.cfg (ui-and-controls-spec.md section 6, ui-style-and-feedback-spec.md section 9).
## Every key is validated against SCHEMA (type, choices or range); unknown keys, wrong types, out-of-range values,
## Objects and corrupt files fall back to defaults. Saves atomically via a .tmp file and rename.
class_name Settings
extends RefCounted

signal changed(key: String, value: Variant)

const PATH := "user://settings.cfg"

## The table of every setting (settings_schema.gd).
const SCHEMA: Dictionary = SettingsSchema.SCHEMA

const DEVICE_PRESETS: Dictionary = {
	"both": {"wheel": "zoom", "gesture": "pan"},
	"mouse": {"wheel": "zoom", "gesture": "zoom"},
	"trackpad": {"wheel": "pan", "gesture": "pan"},
}

const GRAPHICS_PRESETS: Dictionary = {
	"low": {
		"graphics/texture_quality": "half",
		"graphics/relief_shading": false,
		"graphics/preload_next_season": false,
		"display/fps_cap": 60,
	},
	"medium": {
		"graphics/texture_quality": "full",
		"graphics/relief_shading": true,
		"graphics/preload_next_season": true,
		"display/fps_cap": 0,
	},
	"high": {
		"graphics/texture_quality": "full",
		"graphics/relief_shading": true,
		"graphics/preload_next_season": true,
		"display/fps_cap": 0,
	},
}

const GRAPHICS_PRESET_KEYS: Array[String] = [
	"graphics/texture_quality",
	"graphics/relief_shading",
	"graphics/preload_next_season",
	"display/fps_cap",
]

var platform: String = OS.get_name()
var should_reduce_motion: bool = false
var _values: Dictionary = {}
var _key_overrides: Dictionary = {}
var _applying_graphics_preset: bool = false


func _init(
	p_platform: String = OS.get_name(),
	p_should_reduce_motion: bool = system_reduce_motion()
) -> void:
	platform = p_platform
	should_reduce_motion = p_should_reduce_motion
	for key: String in SCHEMA.keys():
		_values[key] = get_default(key)


static func system_reduce_motion() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if DisplayServer.has_method("accessibility_should_reduce_animation"):
		return bool(DisplayServer.call("accessibility_should_reduce_animation"))
	return false


static func load_from(
	path: String = PATH,
	p_platform: String = OS.get_name(),
	p_should_reduce_motion: bool = system_reduce_motion()
) -> Settings:
	var s := Settings.new(p_platform, p_should_reduce_motion)
	if path.is_empty() or not FileAccess.file_exists(path):
		return s
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return s
	var raw_text := file.get_as_text()
	file.close()
	var cfg := SettingsIo.parse_safe_config(raw_text)
	if cfg == null:
		return s
	_apply_loaded_config(s, cfg)
	return s


static func _apply_loaded_config(s: Settings, cfg: ConfigFile) -> void:
	if cfg.has_section_key("controls", "device"):
		var dev_val: Variant = cfg.get_value("controls", "device")
		if is_valid_value("controls/device", dev_val, s.platform):
			s.set_value("controls/device", dev_val)
	for section: String in cfg.get_sections():
		if section == "keys":
			for action: String in cfg.get_section_keys("keys"):
				var binding: Variant = cfg.get_value("keys", action)
				if typeof(binding) == TYPE_STRING:
					s.set_key_override(action, binding as String)
			continue
		for item_key: String in cfg.get_section_keys(section):
			var full_key := section + "/" + item_key
			if full_key == "controls/device":
				continue
			var val: Variant = cfg.get_value(section, item_key)
			if is_valid_value(full_key, val, s.platform):
				s._values[full_key] = val


func get_default(key: String) -> Variant:
	if not SCHEMA.has(key):
		return null
	if key == "accessibility/reduce_motion":
		return should_reduce_motion
	if key == "graphics/texture_quality" and platform == "macOS":
		return "half"
	if key == "graphics/preset" and platform == "macOS":
		return "custom"
	var entry: Dictionary = SCHEMA[key]
	return entry["default"]


func choices_for(key: String) -> Array:
	if not SCHEMA.has(key):
		return []
	var entry: Dictionary = SCHEMA[key]
	if not entry.has("choices"):
		return []
	var base: Array = (entry["choices"] as Array).duplicate()
	if key == "display/window_mode" and platform != "Windows":
		base.erase("exclusive")
	return base


static func is_valid_value(
	key: String,
	value: Variant,
	p_platform: String = "Windows"
) -> bool:
	if not SCHEMA.has(key):
		return false
	if value == null or typeof(value) == TYPE_OBJECT:
		return false
	var entry: Dictionary = SCHEMA[key]
	var expected_type: int = int(entry["type"])
	if typeof(value) != expected_type:
		return false
	if key == "display/window_mode" and p_platform != "Windows" and str(value) == "exclusive":
		return false
	if entry.has("choices"):
		var choices: Array = entry["choices"]
		var matched := false
		for choice: Variant in choices:
			if typeof(choice) == typeof(value) and choice == value:
				matched = true
				break
		if not matched:
			return false
	if entry.has("range"):
		var bounds: Array = entry["range"]
		if expected_type == TYPE_INT:
			var v_int: int = value
			var lo_int: int = bounds[0]
			var hi_int: int = bounds[1]
			if v_int < lo_int or v_int > hi_int:
				return false
		elif expected_type == TYPE_FLOAT:
			var v_flt: float = value
			var lo_flt: float = bounds[0]
			var hi_flt: float = bounds[1]
			if is_nan(v_flt) or is_inf(v_flt) or v_flt < lo_flt or v_flt > hi_flt:
				return false
		elif expected_type == TYPE_VECTOR2I:
			var v_vec: Vector2i = value
			var lo_vec: Vector2i = bounds[0]
			var hi_vec: Vector2i = bounds[1]
			if v_vec.x < lo_vec.x or v_vec.y < lo_vec.y or v_vec.x > hi_vec.x or v_vec.y > hi_vec.y:
				return false
	return true


func get_value(key: String) -> Variant:
	if not SCHEMA.has(key):
		return null
	if _values.has(key):
		return _values[key]
	return get_default(key)


func set_value(key: String, value: Variant) -> bool:
	if not is_valid_value(key, value, platform):
		return false
	_values[key] = value
	changed.emit(key, value)
	if key == "controls/device":
		var preset_name := value as String
		if DEVICE_PRESETS.has(preset_name):
			var preset: Dictionary = DEVICE_PRESETS[preset_name]
			set_value("controls/wheel_action", preset["wheel"])
			set_value("controls/gesture_action", preset["gesture"])
	elif key == "graphics/preset":
		var gp_name := str(value)
		if GRAPHICS_PRESETS.has(gp_name):
			_applying_graphics_preset = true
			var gp: Dictionary = GRAPHICS_PRESETS[gp_name]
			for k: String in gp.keys():
				set_value(k, gp[k])
			_applying_graphics_preset = false
	elif not _applying_graphics_preset and key in GRAPHICS_PRESET_KEYS:
		_sync_graphics_preset()
	return true


func _sync_graphics_preset() -> void:
	var matched := "custom"
	if _matches_graphics_preset("low"):
		matched = "low"
	elif _matches_graphics_preset("medium"):
		var cur := str(get_value("graphics/preset"))
		matched = "high" if cur == "high" else "medium"
	if str(get_value("graphics/preset")) != matched:
		_values["graphics/preset"] = matched
		changed.emit("graphics/preset", matched)


func _matches_graphics_preset(preset_name: String) -> bool:
	var gp: Dictionary = GRAPHICS_PRESETS[preset_name]
	for k: String in gp.keys():
		if get_value(k) != gp[k]:
			return false
	return true


func reset_page(page: String) -> void:
	if page.is_empty():
		return
	for key: String in SCHEMA.keys():
		var entry: Dictionary = SCHEMA[key]
		if str(entry.get("page", "")) == page:
			if key == "controls/device" or key == "graphics/preset":
				continue
			set_value(key, get_default(key))
	if page == "controls" and SCHEMA.has("controls/device"):
		set_value("controls/device", get_default("controls/device"))
	elif page == "graphics" and SCHEMA.has("graphics/preset"):
		_sync_graphics_preset()


func get_key_overrides() -> Dictionary:
	return _key_overrides.duplicate()


func set_key_override(action: String, value: String) -> void:
	if action.is_empty():
		return
	if value.is_empty():
		_key_overrides.erase(action)
	else:
		_key_overrides[action] = value
	changed.emit("keys/" + action, value)


func clear_key_overrides() -> void:
	_key_overrides.clear()


func save_to(path: String = PATH) -> bool:
	if path.is_empty():
		return false
	var cfg := ConfigFile.new()
	for full_key: String in SCHEMA.keys():
		var parts := full_key.split("/", true, 1)
		if parts.size() != 2:
			continue
		cfg.set_value(parts[0], parts[1], get_value(full_key))
	for action: String in _key_overrides.keys():
		cfg.set_value("keys", action, str(_key_overrides[action]))
	return SettingsIo.save_atomic(cfg, path)
