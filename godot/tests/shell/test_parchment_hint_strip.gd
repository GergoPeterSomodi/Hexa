## The HUD over the drawn map (docs/architecture/map-overview-build-spec.md, amendment of 2026-11-28): the key hints
## stand on a walnut strip that shows and fades with the parchment and covers no control, and the parchment's names keep
## off the legend, the key hints, the log's button and the task flag, while the tile view's names keep what they had.
## (P): a strip left out of its place, and names given the old cover only: the checks report them.
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")
const GEN := &"GEN"
## [window, display/ui_scale, accessibility/text_size]: 1280 x 720, with 150 % text, and at UI scale 150 %.
const SIZES: Array[Array] = [[Vector2i(1280, 720), "100", 100], [Vector2i(1280, 720), "100", 150],
	[Vector2i(853, 480), "150", 150]]
## Two default wheel notches out: from the whole-map view to the parchment.
const NOTCHES_OUT := -2.0

var _harness: UIHarness = null
var _app: App = null
var _old: Array = []


func before_each() -> void:
	_old = [Session.save_dir, RunLock.path, Session.ai_enabled]
	Session.save_dir = "user://test_hint_strip_saves"
	RunLock.path = "user://test_hint_strip_running.lock"


func after_each() -> void:
	_close()
	RunLock.clear()
	Session.save_dir = _old[0]
	RunLock.path = _old[1]
	Session.ai_enabled = _old[2]
	Bindings.reset_defaults()
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)


## A Genoa game in a window of `size`, its map loaded.
func _open(size: Array = SIZES[0], extra: Dictionary = {}) -> void:
	_harness = UIHarness.new(size[0])
	_harness.mount(self)
	Session.ai_enabled = false
	_app = APP_SCENE.instantiate() as App
	_app.settings_path = ""
	_app.allow_tree_quit = false
	_app.pause_tree_when_modal = false
	_app.cli_args_override = PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"])
	var s := Settings.new("macOS", true)
	var wanted := {"state/help_seen": true, "graphics/preload_next_season": false, "game/autosave": "off",
		"accessibility/reduce_motion": true, "display/ui_scale": size[1], "accessibility/text_size": size[2]}
	wanted.merge(extra, true)
	for key: String in wanted:
		s.set_value(key, wanted[key])
	_app.set_settings_override(s)
	_harness.viewport.add_child(_app)
	for _i: int in 600:
		if _app.map_scene() != null and _app.stack().count() == 0 and not _app.is_starting():
			break
		await get_tree().process_frame
	_app.map_scene().finish_loading()
	_app.hud().toast_host().clear()
	await _harness.wait_frames(self, 4)


func _close() -> void:
	if _app != null:
		_app.free()
		_app = null
		Session.end_game()
		_harness.viewport.queue_free()
	_harness = null


func _strip() -> Control:
	return _app.hud().map_area().get_node_or_null("HintStrip") as Control


## The tiles: the whole-map view.
func _tiles() -> void:
	_app.map_scene().fit()
	await _harness.wait_frames(self, 6)


## The parchment: two notches past the whole-map view.
func _parchment() -> void:
	await _tiles()
	_app.map_scene().camera_rig().zoom_by(NOTCHES_OUT)
	await _harness.wait_frames(self, 8)


## An army of Genoa selected: the army panel, the line that moves are final and its key.
func _select_army() -> void:
	var g := Session.game
	var army := ArmyFixture.army(g, GEN, Countries.by_tag(g, GEN).capital, 0, 2)
	g.version += 1
	var armies := _app.map_scene().get_node("MapArmies") as MapArmies
	armies.sync()
	assert_true(armies.select_army(army.id))
	await _harness.wait_frames(self, 8)


# ----- the strip ------------------------------------------------------------------------------------------------------


## What is wrong with the strip while the drawn map lies solid: it must show whole, behind every hint shown, and cover
## no control.
func _strip_problems() -> Array[String]:
	var out: Array[String] = []
	var hud := _app.hud()
	var strip := _strip()
	var any := hud.key_hints().get_combined_minimum_size().x > 0.0
	if not any:  # a window too narrow for the first hint shows none, and then there is no strip either
		return ["a strip with no hint"] if strip != null and strip.visible else [] as Array[String]
	if strip == null or not strip.is_visible_in_tree():
		return ["no strip shows"]
	var rect := Hud.screen_rect(strip)
	if strip.modulate.a < 1.0:
		out.append("the strip is see-through: %.2f" % strip.modulate.a)
	if strip.get_index() >= hud.key_hints().get_index() or strip.get_parent() != hud.key_hints().get_parent():
		out.append("the strip is not behind the hints")
	var shown := 0
	for child: Node in hud.key_hints().get_children():
		var item := child as Control
		if item == null or not item.visible or item.is_queued_for_deletion():
			continue
		shown += 1
		if not rect.grow(0.5).encloses(Hud.screen_rect(item)):
			out.append("a hint %s off the strip %s" % [Hud.screen_rect(item), rect])
	if shown == 0:
		out.append("no hint is shown")
	var window := Rect2(Vector2.ZERO, hud.map_area().get_viewport_rect().size)
	if not window.encloses(rect):
		out.append("the strip leaves the window: %s" % rect)
	var controls: Dictionary[String, Control] = {"zoom control": hud.zoom_control(), "minimap": hud.minimap(),
		"Return button": hud.return_button(), "scale bar": hud.scale_bar()}
	for part: Control in hud.action_log().icon_parts():
		controls["log's %s" % part.name] = part
	for what: String in controls:
		if controls[what].is_visible_in_tree() and rect.intersects(Hud.screen_rect(controls[what])):
			out.append("the strip %s covers the %s %s" % [rect, what, Hud.screen_rect(controls[what])])
	return out


func test_the_key_hints_stand_on_a_strip_over_the_drawn_map_only() -> void:
	await _open()
	await _tiles()
	var strip := _strip()
	assert_not_null(strip, "the HUD has a strip")
	if strip == null:
		return
	assert_false(strip.visible, "the tile view is as before")
	await _parchment()
	assert_eq(_strip_problems(), [] as Array[String], "Terrain")
	assert_eq(strip.theme_type_variation, &"PanelCard", "the kit's card")
	_app.map_scene().set_mode(MapModes.Mode.RELIEF)
	await _harness.wait_frames(self, 6)
	assert_false(strip.visible, "no drawn map in Relief")
	_app.map_scene().set_mode(MapModes.Mode.GOODS)
	await _tiles()
	assert_eq(_strip_problems(), [] as Array[String], "Goods, at the whole-map view")
	_app.map_scene().set_mode(MapModes.Mode.TERRAIN)
	await _parchment()
	_app.hud().key_hints().set_hints_enabled(false)
	await _harness.wait_frames(self, 3)
	assert_false(strip.visible, "no hints, no strip")
	_app.hud().key_hints().set_hints_enabled(true)
	await _harness.wait_frames(self, 3)
	assert_true(strip.visible)
	await _tiles()
	assert_false(strip.visible, "back on the tiles")


func test_the_strip_covers_no_control_in_small_windows() -> void:
	for size: Array in SIZES:
		await _open(size)
		var found: Array[String] = []
		_app.map_scene().set_mode(MapModes.Mode.GOODS)
		await _harness.wait_frames(self, 8)
		for line: String in _strip_problems():
			found.append("Goods: " + line)
		_app.map_scene().set_mode(MapModes.Mode.OWNER)
		await _parchment()
		for line: String in _strip_problems():
			found.append("Owner: " + line)
		await _select_army()
		assert_eq(_app.hud().key_hints().note_text(), KeyHints.MOVES_NOTE)
		for line: String in _strip_problems():
			found.append("an army selected: " + line)
		assert_eq(found, [] as Array[String], str(size))
		if size == SIZES[0]:
			var strip := _strip()
			if strip != null:
				strip.position.x += 2000.0
				assert_gt(_strip_problems().size(), 0, "(P) a strip out of its place is reported")
		_close()


func test_the_strip_fades_with_the_drawn_map() -> void:
	await _open(SIZES[0], {"accessibility/reduce_motion": false})
	await _tiles()
	var scene := _app.map_scene()
	var parchment := scene.parchment()
	scene.set_process(false)
	scene.frame_at(scene.map_size() / 2.0, scene.camera_rig().min_zoom())
	scene._process(ParchmentSwitch.FADE_SEC * 0.5)
	await _harness.wait_frames(self, 2)
	assert_true(parchment.is_fading(), "the case is mid-fade")
	var strip := _strip()
	assert_true(strip != null and strip.visible)
	var alpha := parchment.picture().self_modulate.a
	assert_almost_eq(strip.modulate.a if strip != null else -1.0, alpha, 0.001, "as solid as the drawn map")
	scene._process(1.0)
	await _harness.wait_frames(self, 2)
	assert_eq(strip.modulate.a if strip != null else -1.0, 1.0)


## The ground of a card's stylebox: its colour, or the pixel in the middle of its picture.
func _ground(box: StyleBox) -> Color:
	if box is StyleBoxFlat:
		return (box as StyleBoxFlat).bg_color
	var image := (box as StyleBoxTexture).texture.get_image()
	return image.get_pixel(image.get_width() >> 1, image.get_height() >> 1)


func test_the_hints_read_on_the_strip_in_both_themes() -> void:
	for high: bool in [false, true]:
		await _open(SIZES[0], {"accessibility/high_contrast": high})
		await _parchment()
		var strip := _strip()
		assert_true(strip != null and strip.visible, "high contrast %s" % high)
		if strip == null:
			_close()
			continue
		var ground := _ground(strip.get_theme_stylebox(&"panel"))
		assert_gt(ground.a, 0.9, "an opaque ground")
		var weak: Array[String] = []
		var looked := 0
		for label: Node in _app.hud().key_hints().find_children("*", "Label", true, false):
			var words := label as Label
			if not words.is_visible_in_tree() or words.get_parent() is KeyCap or words.text == "":
				continue
			looked += 1
			var ratio := Tokens.contrast_ratio(words.get_theme_color(&"font_color"), ground)
			if ratio < 4.5:
				weak.append("%s %.2f" % [words.text, ratio])
		assert_gt(looked, 3)
		assert_eq(weak, [] as Array[String], "high contrast %s" % high)
		var last := _app.hud().key_hints().find_children("*", "Label", true, false)[-1] as Label
		assert_lt(Tokens.contrast_ratio(last.get_theme_color(&"font_color"), ParchmentTokens.LAND), 2.0,
			"(P) the same words on the paper do not read")
		_close()


# ----- the names keep off ---------------------------------------------------------------------------------------------


## The parts of the HUD the drawn map's names are to keep off, beyond the tile view's: name -> screen rect.
func _name_covers() -> Dictionary[String, Rect2]:
	var hud := _app.hud()
	var out: Dictionary[String, Rect2] = {}
	var hints := Hud.screen_rect(hud.key_hints())
	hints.size.x = hud.key_hints().get_combined_minimum_size().x
	var parts: Array[Control] = [hud.mode_legend(), hud.task_flag()]
	parts.append_array(hud.action_log().icon_parts())
	for part: Control in parts:
		if part.is_visible_in_tree():
			out[str(part.name)] = Hud.screen_rect(part)
	out["KeyHints"] = hints
	return out


## The parchment's names and icons that lie under one of `covers` (a country name by its turned box).
func _under(covers: Dictionary[String, Rect2]) -> Array[String]:
	var out: Array[String] = []
	for item: Dictionary in _app.map_scene().parchment_names().placed():
		var country: bool = item["kind"] == ParchmentLabels.KIND_COUNTRY
		if not country and item["kind"] != ParchmentLabels.KIND_ICON and str(item["text"]) == "":
			continue
		for what: String in covers:
			var hit := false
			if country:
				hit = ParchmentLabelSpace.turned_hits(covers[what], item["centre"],
					Vector2.from_angle(deg_to_rad(float(item["angle"]))), (item["extent"] as Vector2) * 0.5)
			else:
				hit = covers[what].intersects(item["rect"])
			if hit:
				out.append("%s %s under %s" % [item["kind"], item["text"], what])
	return out


## Goods views: the whole map with wine (as pm_goods_wine), and zoom 1 on the north east and on the middle south. In
## each, every name has room clear of the HUD on its own land.
func _goods_views() -> Array[Callable]:
	var scene := _app.map_scene()
	return [
		func() -> void: scene.fit(),
		func() -> void: scene.frame_at(MapTiles.cell_centre(Vector2i(13, 6)), 1.0),
		func() -> void: scene.frame_at(MapTiles.cell_centre(Vector2i(7, 12)), 1.0),
	]


func test_the_drawn_maps_names_keep_off_the_legend_hints_log_and_task_flag() -> void:
	await _open(SIZES[0], {"state/map_mode": "goods", "state/map_good": "wine"})
	var found: Array[String] = []
	var old_cover: Array[String] = []
	var views := _goods_views()
	for n: int in views.size():
		views[n].call()
		await _harness.wait_frames(self, 8)
		var covers := _name_covers()
		for part: String in ["ModeLegend", "TaskFlag", "Toggle", "KeyHints"]:
			if not covers.has(part):
				found.append("view %d: %s is not on screen" % [n, part])
		for line: String in _under(covers):
			found.append("view %d: %s" % [n, line])
		# (P) The same view with the tile view's cover alone, as the names had it.
		var scene := _app.map_scene()
		scene.set_screen_cover(_app.hud().cover_rects())
		old_cover.append_array(_under(covers))
		scene.set_screen_cover(_app.hud().cover_rects(), _app.hud().name_cover_rects())
		_app.call("_sync_screen_cover")
	assert_eq(found, [] as Array[String])
	assert_gt(old_cover.size(), 0, "(P) names under the legend, the hints, the log and the task flag are reported")


## The F3 panel moves the legend under it and sizes it no differently: the drawn map's names are told all the same, and
## once all stands still the HUD says no more.
func test_the_names_follow_the_legend_the_f3_panel_moves() -> void:
	await _open(SIZES[0], {"state/map_mode": "goods"})
	await _parchment()
	var hud := _app.hud()
	var names := _app.map_scene().parchment_names()
	var told: Array[int] = [0]
	hud.cover_changed.connect(func() -> void: told[0] += 1)
	for open: bool in [true, false]:
		var before := Hud.screen_rect(hud.mode_legend())
		hud.set_debug_open(open)
		await _harness.wait_frames(self, 20)
		var after := Hud.screen_rect(hud.mode_legend())
		assert_true(hud.mode_legend().is_visible_in_tree(), "F3 open %s: the legend shows" % open)
		assert_ne(after.position, before.position, "F3 open %s: the case moves the legend" % open)
		assert_eq(after.size, before.size, "F3 open %s: and does not resize it" % open)
		assert_eq(names._cover, hud.cover_rects() + hud.name_cover_rects(), "F3 open %s: the names' cover" % open)
		told[0] = 0
		await _harness.wait_frames(self, 20)
		assert_eq(told[0], 0, "F3 open %s: no cover_changed while nothing moves" % open)


func test_the_tile_views_names_keep_the_cover_they_had() -> void:
	await _open()
	_app.map_scene().set_mode(MapModes.Mode.OWNER)
	await _tiles()
	var scene := _app.map_scene()
	var hud := _app.hud()
	assert_gt(hud.name_cover_rects().size(), 2, "the drawn map's own covers are there")
	assert_eq(scene.country_labels().cover(), hud.cover_rects(), "the tile view's names: as before")
	assert_eq(scene.parchment_names()._cover, hud.cover_rects() + hud.name_cover_rects(), "the drawn map's: both")
	hud.set_hud_visible(false)
	await _harness.wait_frames(self, 4)
	assert_eq(hud.name_cover_rects(), [] as Array[Rect2], "a hidden HUD covers nothing")
	assert_eq(scene.parchment_names()._cover, [] as Array[Rect2])
