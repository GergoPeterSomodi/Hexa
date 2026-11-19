## Capital pennants on the map (docs/architecture/m2-build-spec.md sections 6.1 and 6.4):
## draws a brass pennant_pole and palette-tinted pennant_cloth 46 px above each playable
## country's capital in map space (z_index 86), visible in Owner mode and while picking.
@tool
class_name CapitalMarks
extends Node2D

const LAYER_Z := 86
const OFFSET_Y := -46.0
const CLOTH_OFFSET := Vector2(0.0, -16.0)

var _game: Game = null
var _colour_blind := false
var _mode: MapModes.Mode = MapModes.Mode.TERRAIN
var _picking := false
var _items: Array[Dictionary] = []  # {id, tag, capital, pole, cloth}
var _fallback_theme: Theme = null


func _init() -> void:
	z_index = LAYER_Z
	visible = false


## Builds pennant sprites for all playable capitals of `game` using `colour_blind` palette.
func setup(game: Game, colour_blind: bool = false) -> void:
	_game = game
	_colour_blind = colour_blind
	_rebuild()
	_update_visibility()


## Rebuilds pennants from the current game state (e.g. on owners_changed or alive change).
func refresh() -> void:
	_rebuild()
	_update_visibility()


## Updates the current map mode and refreshes pennant visibility.
func set_mode(mode: MapModes.Mode) -> void:
	_mode = mode
	_update_visibility()


## Sets whether country picking is active and refreshes pennant visibility.
func set_picking(on: bool) -> void:
	_picking = on
	_update_visibility()


## Switches pennant cloth tints between standard and colour-blind palettes.
func set_colour_blind(on: bool) -> void:
	if on == _colour_blind and not _items.is_empty():
		return
	_colour_blind = on
	if _game == null or not _game.has_countries():
		return
	var pal := MapModes.palette(_game, _colour_blind)
	for item: Dictionary in _items:
		var cid := int(item["id"])
		var cloth := item["cloth"] as Sprite2D
		if cloth != null and cid > 0 and cid < pal.size():
			cloth.modulate = pal[cid]


## Number of playable capital pennants currently built for the game.
func pennant_count() -> int:
	return _items.size()


## Returns the cloth modulate colour for `tag`, or Color.TRANSPARENT if not present.
func cloth_colour_of(tag: StringName) -> Color:
	for item: Dictionary in _items:
		if (item["tag"] as StringName) == tag:
			var cloth := item["cloth"] as Sprite2D
			if cloth != null:
				return cloth.modulate
	return Color.TRANSPARENT


func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_items.clear()
	if _game == null or not _game.has_countries():
		return
	var pole_tex := _kit_icon(&"pennant_pole")
	var cloth_tex := _kit_icon(&"pennant_cloth")
	var pal := MapModes.palette(_game, _colour_blind)
	for country: Country in _game.countries:
		if country == null or not Countries.playable(_game, country.tag):
			continue
		var pole := Sprite2D.new()
		pole.name = "Pennant_%s" % String(country.tag)
		pole.texture = pole_tex
		pole.centered = true
		pole.position = MapTiles.cell_centre(country.capital) + Vector2(0.0, OFFSET_Y)

		var cloth := Sprite2D.new()
		cloth.name = "Cloth"
		cloth.texture = cloth_tex
		cloth.centered = false
		cloth.position = CLOTH_OFFSET
		cloth.show_behind_parent = true
		if country.id > 0 and country.id < pal.size():
			cloth.modulate = pal[country.id]
		pole.add_child(cloth)
		add_child(pole)
		_items.append({
			"id": country.id,
			"tag": country.tag,
			"capital": country.capital,
			"pole": pole,
			"cloth": cloth,
		})


func _update_visibility() -> void:
	var show_marks := _game != null and _game.has_countries() and (_mode == MapModes.Mode.OWNER or _picking) and not _items.is_empty()
	if show_marks:
		_sync_textures()
	visible = show_marks


func _sync_textures() -> void:
	if _items.is_empty():
		return
	var pole_tex := _kit_icon(&"pennant_pole")
	var cloth_tex := _kit_icon(&"pennant_cloth")
	for item: Dictionary in _items:
		var pole := item["pole"] as Sprite2D
		var cloth := item["cloth"] as Sprite2D
		if pole != null and pole_tex != null and pole.texture != pole_tex:
			pole.texture = pole_tex
		if cloth != null and cloth_tex != null and cloth.texture != cloth_tex:
			cloth.texture = cloth_tex


func _kit_icon(icon_name: StringName) -> Texture2D:
	if is_inside_tree():
		var win := get_window()
		if win != null and win.theme != null and win.theme.has_icon(icon_name, &"Kit"):
			return win.theme.get_icon(icon_name, &"Kit")
	var proj := ThemeDB.get_project_theme()
	if proj != null and proj.has_icon(icon_name, &"Kit"):
		return proj.get_icon(icon_name, &"Kit")
	if _fallback_theme == null and ResourceLoader.exists(KitTheme.THEME_PATH):
		_fallback_theme = load(KitTheme.THEME_PATH) as Theme
	if _fallback_theme != null and _fallback_theme.has_icon(icon_name, &"Kit"):
		return _fallback_theme.get_icon(icon_name, &"Kit")
	return null
