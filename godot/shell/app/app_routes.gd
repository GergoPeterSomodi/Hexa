## The App's router (docs/architecture/m2-build-spec.md section 7.11): what the map scene and the HUD ask for: the pick,
## the country panel in the dock, glides to a country or a place, the "You rule ..." toast, place search, the mode
## switch, the minimap's look and jump, and the zoom, fit and debug requests. The App owns one and connects its
## signals here; this class reads the App only through its public accessors and changes the game only through Session.
class_name AppRoutes
extends RefCounted

## The zoom a glide to a country or a place reaches when the view is further out than this (1 = the art size).
const GLIDE_ZOOM := 0.6
## The toasts of a map mode the game does not offer (MapModes.modes): a map-only game, and the pick before a country is ruled.
const NO_COUNTRIES := "No countries on this map"
const CHOOSE_FIRST := "Choose your country first"

var _app: App = null
var _pick: CountryPick = null


func _init(app: Node) -> void:
	_app = app as App


## The pick: the map is in Owner mode (the scene starts so while picking); the country list is pushed.
func begin_pick() -> void:
	_pick = ScreenIds.make(&"country_pick") as CountryPick
	if _pick != null:
		_app.stack().push(_pick)
	_app.refresh_stack_state()


## The pick screen while it is on the stack, else null.
func pick_screen() -> CountryPick:
	if _pick != null and is_instance_valid(_pick) and _app.stack().has_screen(&"country_pick"):
		return _pick
	return null


## Shows a country's panel in the dock and glides to its focus hex.
func show_country(tag: StringName) -> void:
	if _app.hud() == null or Session.game == null or not Session.game.has_countries():
		return
	var card := CountryCard.of(Session.game, tag)
	if card.is_empty():
		return
	var picking := _app.map_scene() != null and _app.map_scene().picking()
	_app.hud().show_country(tag, picking)
	var focus := card["focus"] as Vector2i
	if _app.map_scene() != null and focus != Country.NO_HEX:
		_app.map_scene().glide_to_hex(focus, glide_zoom())


## The zoom a glide aims for: the current one, or GLIDE_ZOOM when the view is further out.
func glide_zoom() -> float:
	if _app.map_scene() == null or _app.map_scene().camera_rig() == null:
		return -1.0
	return maxf(_app.map_scene().camera_rig().target_zoom(), GLIDE_ZOOM)


func scenario_title(scenario_id: String) -> String:
	var defs := Session.defs()
	var scenario := defs.scenario(scenario_id) if defs != null else null
	return scenario.name if scenario != null and not scenario.name.is_empty() else scenario_id


## "You rule the Republic of Genoa from Genoa." and a glide to the capital.
func announce_rule(instant: bool = false) -> void:
	var game := Session.game
	if game == null or _app.map_scene() == null:
		return
	var card := CountryCard.of(game, game.player)
	if card.is_empty():
		return
	var capital: Dictionary = card["capital"]
	if not bool(capital["off_map"]):
		_app.map_scene().glide_to_hex(capital["hex"] as Vector2i, glide_zoom(), instant)
		_app.context().toast("You rule the %s from %s." % [str(card["long_name"]), str(capital["name"])], &"good")
	else:
		_app.context().toast("You rule the %s." % str(card["long_name"]), &"good")


func on_country_chosen(_tag: StringName) -> void:
	Session.unsaved_actions = 0
	if _app.map_scene() == null or _app.is_starting():
		return
	announce_rule()
	if _app.hud() != null:
		_app.hud().close_dock()
	HelpOverlay.open_if_unseen.call_deferred(_app.context())


func on_map_country_clicked(tag: StringName) -> void:
	var pick := pick_screen()
	if pick != null:
		pick.on_country_clicked(tag)


func on_map_country_hovered(tag: StringName) -> void:
	var pick := pick_screen()
	if pick != null:
		pick.on_country_hovered(tag)


## C: while picking, focus goes to the list; otherwise your country's panel.
func on_map_country_requested() -> void:
	var pick := pick_screen()
	if pick != null:
		var tags := pick.row_tags()
		if not tags.is_empty() and pick.row_button(tags[0]) != null:
			pick.row_button(tags[0]).grab_focus()
		return
	if Session.player_tag() != &"":
		show_country(Session.player_tag())


func toggle_find_place() -> void:
	var top := _app.stack().top()
	if top != null and top.screen_id == &"find_place":
		_app.stack().back()
		return
	if _app.map_scene() == null or _app.hides_world() or (top != null and top.screen_id != &"country_pick"):
		return
	var find := ScreenIds.make(&"find_place")
	if find != null:
		_app.stack().push(find)


func on_country_panel_closed() -> void:
	var pick := pick_screen()
	if pick != null:
		pick.dock_closed()


## The top bar's switch: a mode the game does not offer is toasted (spec 6.9), otherwise it is set.
func on_hud_mode_requested(mode: int) -> void:
	if _app.map_scene() == null:
		return
	if not MapModes.modes(Session.game).has(mode):
		var has_countries := Session.game != null and Session.game.has_countries()
		_app.context().toast(CHOOSE_FIRST if has_countries else NO_COUNTRIES, &"warn")
		return
	_app.map_scene().set_mode(mode)


## A key asked for a mode the game does not offer: while picking, the toast says to choose first. (In a map-only game the
## scene itself has said "No countries on this map" through `refused`.)
func on_map_mode_refused(_mode: int) -> void:
	if Session.game != null and Session.game.has_countries():
		_app.context().toast(CHOOSE_FIRST, &"warn")


func on_hud_country_play(tag: StringName) -> void:
	var pick := pick_screen()
	if pick != null:
		pick.play(tag)


## "Show on the map" in a country panel: glide there and switch to Owner mode.
func on_hud_country_look_at(hex: Vector2i) -> void:
	if _app.map_scene() == null:
		return
	if Session.game != null and Session.game.has_countries():
		_app.map_scene().set_mode(int(MapModes.Mode.OWNER))
	_app.map_scene().glide_to_hex(hex, glide_zoom())


func on_hud_look_at(map_px: Vector2) -> void:
	if _app.map_scene() != null and _app.map_scene().camera_rig() != null:
		_app.map_scene().camera_rig().look_at(map_px)


func on_hud_jump(map_px: Vector2) -> void:
	if _app.map_scene() != null and _app.map_scene().camera_rig() != null:
		_app.map_scene().camera_rig().look_at(map_px, -1.0, true)


## Connects the map scene's signals to this router (and, for the pick and the search, to the App's screens).
func bind_scene(scene: MapScene) -> void:
	for pair: Array in _scene_links(scene):
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if not sig.is_connected(handler):
			sig.connect(handler)


func unbind_scene(scene: MapScene) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	for pair: Array in _scene_links(scene):
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)


func _scene_links(scene: MapScene) -> Array[Array]:
	return [
		[scene.refused, on_map_refused],
		[scene.map_mode_refused, on_map_mode_refused],
		[scene.hud_toggle_requested, on_map_hud_toggle],
		[scene.country_clicked, on_map_country_clicked],
		[scene.country_hovered, on_map_country_hovered],
		[scene.country_requested, on_map_country_requested],
		[scene.find_place_requested, toggle_find_place],
	]


func on_map_refused(reason: String) -> void:
	if _app.context() != null and not reason.is_empty():
		_app.context().toast(reason, &"warn")


func on_map_hud_toggle() -> void:
	if _app.hud() != null:
		_app.hud().toggle_hud()


func on_hud_zoom_step(notches: float) -> void:
	if _app.map_scene() != null and _app.map_scene().camera_rig() != null:
		_app.map_scene().camera_rig().zoom_by(notches)


func on_hud_zoom_set(z: float) -> void:
	if _app.map_scene() != null and _app.map_scene().camera_rig() != null:
		_app.map_scene().camera_rig().zoom_to(z)


func on_hud_fit() -> void:
	if _app.map_scene() != null:
		_app.map_scene().fit()


## F3's Look: 0 to 3 a season, -1 the calendar's (MapScene.preview_season; the index is passed on as it is).
func on_hud_season_preview(index: int) -> void:
	if _app.map_scene() != null:
		_app.map_scene().preview_season(index)


func on_hud_new_seed() -> void:
	if _app.map_scene() != null:
		_app.map_scene().new_seed()


func on_hud_debug_layer(layer_name: StringName, on: bool) -> void:
	if _app.map_scene() != null:
		_app.map_scene().apply_debug_layer(layer_name, on)


func on_hud_far_zoom(value: float) -> void:
	if _app.map_scene() != null and _app.map_scene().far() != null:
		_app.map_scene().far().set_zoom_switch(value)


func on_hud_slice_ms(ms: int) -> void:
	if _app.map_scene() != null:
		_app.map_scene().slice_ms = float(ms)


## Saves the viewport as a PNG in `dir` and toasts; returns the file's path, or "" (headless, or it failed).
func take_screenshot(dir: String) -> String:
	var vp := _app.get_viewport()
	if vp == null or DisplayServer.get_name() == "headless":
		return ""
	var tex := vp.get_texture()
	if tex == null:
		return ""
	var img := tex.get_image()
	if img == null or img.is_empty():
		return ""
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir)) != OK:
		_app.context().toast("Could not create screenshot folder", &"bad")
		return ""
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var filename := "hexa_%s.png" % stamp
	var full_path := dir.path_join(filename)
	if img.save_png(full_path) == OK:
		_app.context().toast("Saved screenshot: %s" % filename, &"good")
		return full_path
	_app.context().toast("Could not save screenshot", &"bad")
	return ""


## The `look_at` request: a map pixel, or a hex (glide there; `select` also selects it). `mode` (a MapModes key such as
## &"yields") sets the map mode first (Show on the map).
func look_at(args: Dictionary) -> void:
	var scene := _app.map_scene()
	if scene != null and args.has("mode"):
		scene.set_mode(MapModes.mode_of(StringName(str(args["mode"]))))
	if scene == null or scene.camera_rig() == null:
		return
	if args.has("map_px") and args["map_px"] is Vector2:
		scene.camera_rig().look_at(args["map_px"] as Vector2)
	elif args.has("hex") and args["hex"] is Vector2i and scene.view() != null:
		var hex := args["hex"] as Vector2i
		scene.glide_to_hex(hex, glide_zoom())
		if bool(args.get("select", false)):
			scene.select_hex(hex)
