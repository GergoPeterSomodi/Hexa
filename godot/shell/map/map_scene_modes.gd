## The map modes of the map scene (docs/architecture/map-overview-build-spec.md D12), moved out of map_scene.gd to keep it
## under its size limit: the mode on show, the remembered mode (the setting state/map_mode, or the one kept here when the
## scene has no settings) and putting a mode on the overlay, the pennants and the country names. Which modes a game offers
## stays MapModes' answer; the public calls (mode, set_mode) and the signals stay on the scene.
class_name MapSceneModes
extends RefCounted

const SETTING := "state/map_mode"

## The mode on show.
var current: MapModes.Mode = MapModes.Mode.TERRAIN

var _persisted: MapModes.Mode = MapModes.Mode.TERRAIN
var _scene: MapScene = null
var _sync_names := Callable()


## `scene` is a Node for the reason MapSeasons gives: MapScene creates this helper in a member initialiser. `sync_names`
## is the scene's laying out of the country names (its camera moves use it too).
func _init(scene: Node, sync_names: Callable) -> void:
	_scene = scene as MapScene
	_sync_names = sync_names


## The setting's value as it is now: remembered, and shown unless the pick is on or there is no game.
func hear(value: String) -> void:
	_persisted = _mode_from_string(value)
	if not _scene.picking() and Session.game != null:
		apply(_clamp_for_game(_persisted), false)


## A game's first mode: Owner during the pick, else the remembered one.
func start(settings: Settings) -> void:
	var first := MapModes.Mode.OWNER if _scene.picking() else _saved(settings)
	apply(_clamp_for_game(first), false)


## Shows the remembered mode again (Terrain when the running game does not offer it).
func restore(settings: Settings) -> void:
	apply(_clamp_for_game(_saved(settings)), false)


## Puts `target` on the map. With `persist` it is remembered too, and written to `settings` when there are any. The
## scene's mode_changed is sent when the mode on show changed.
func apply(target: MapModes.Mode, persist: bool, settings: Settings = null) -> void:
	var changed := current != target
	current = target
	var overlay := _scene.overlay()
	if overlay != null:
		overlay.set_mode(current)
		overlay.sync_modes(Session.game, true)
	var is_picking := _scene.picking()
	var capitals := _scene.capital_marks()
	if capitals != null:
		capitals.set_picking(is_picking)
		capitals.set_mode(current)
	var country_labels := _scene.country_labels()
	if country_labels != null:
		country_labels.set_picking(is_picking)
		country_labels.set_mode(current)
	_sync_names.call()
	if persist:
		_persisted = current
		if settings != null:
			var mode_str := _mode_to_string(current)
			if str(settings.get_value(SETTING)) != mode_str:
				settings.set_value(SETTING, mode_str)
	if changed:
		_scene.mode_changed.emit(int(current))


func _saved(settings: Settings) -> MapModes.Mode:
	if settings != null:
		return _mode_from_string(str(settings.get_value(SETTING)))
	return _persisted


static func _clamp_for_game(candidate: MapModes.Mode) -> MapModes.Mode:
	return candidate if MapModes.modes(Session.game).has(int(candidate)) else MapModes.Mode.TERRAIN


static func _mode_from_string(name: String) -> MapModes.Mode:
	return maxi(MapModes.mode_of(StringName(name)), 0) as MapModes.Mode


static func _mode_to_string(m: MapModes.Mode) -> String:
	return String(MapModes.MODE_KEYS[int(m)])
