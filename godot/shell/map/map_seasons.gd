## The season of the map scene (docs/architecture/m3-build-spec.md 6.9), moved out of map_scene.gd to keep it under its size
## limit: the TileSet swap (set_season), the calendar season with the fade (show_season), the F3 Look preview and the
## next season's preload. The state a caller reads (`season`, `slice_ms`, `preload_next_season`) stays on the scene.
class_name MapSeasons
extends RefCounted

## The season shown when there is no game (MapScene.START_SEASON).
const START_SEASON := "summer"

## The season set that is on the view now.
var tiles: TilesetBuilder = null

var _scene: MapScene = null
var _pending := ""  # a season asked for before its pictures were loaded: swapped when they are
var _previewing := false  # a Look preview is on until the next season_ended
var _wanted := ""  # the season asked for last (set before a fade's capture)


## `scene` is a Node because MapScene creates this helper in a member initialiser (`MapSeasons.new(self)`), where its
## own class is not resolved yet: a MapScene parameter would be a parse cycle.
func _init(scene: Node) -> void:
	_scene = scene as MapScene


## The calendar's season index of the running game (the start season when there is none).
static func calendar_index() -> int:
	return Calendar.season_of(Session.game.turn) if Session.game != null else TilesetBuilder.SEASONS.find(START_SEASON)


## Loads the calendar's season for the view (the scene is opening); the name is put on the scene.
func open() -> TilesetBuilder:
	_scene.season = TilesetBuilder.SEASONS[calendar_index()]
	_wanted = _scene.season
	tiles = TilesetBuilder.load_season(_scene.season, _scene.is_half_textures())
	if tiles.tile_set == null:
		push_warning("map scene: %s (bake the tiles and run tools/build_tileset.gd)" % tiles.error)
		tiles.tile_set = TileSet.new()
	return tiles


func reload_quality() -> void:
	var half := _scene.is_half_textures()
	if tiles != null and tiles.half == half:
		return
	var loaded := TilesetBuilder.load_season(_scene.season, half)
	if loaded.tile_set == null:
		push_warning("map scene: %s" % loaded.error)
		return
	_swap_to(loaded)


## Swaps the season: the TileSet of every layer is replaced and no cell is written. Godot rebuilds a layer when its TileSet
## changes (about 1 ms a thousand cells), so the view swaps a chunk of a layer at a time (slice_ms a frame), the chunks on the
## screen first; a small map is done in the first step.
func set_season(value: String) -> void:
	_pending = ""
	var half := _scene.is_half_textures()
	if (value == _scene.season and (tiles == null or tiles.half == half)) or not TilesetBuilder.SEASONS.has(value):
		return
	if _scene.preload_next_season and DisplayServer.get_name() != "headless" and not TilesetBuilder.is_loaded(value, half):
		TilesetBuilder.request_season(value, half)  # not loaded yet (a key jumped over the next season): the frames go on meanwhile
		_pending = value
		return
	var loaded := TilesetBuilder.load_season(value, half)
	if loaded.tile_set == null:
		push_warning("map scene: %s" % loaded.error)
		return
	_scene.season = value
	_swap_to(loaded)
	_scene.season_changed.emit(value)


## Shows the calendar's season `index` (0 Spring to 3 Winter), with the fade when `fade`: the SeasonFade captures first, the swap
## starts below it. Ignored while a look preview is on.
func show_season(index: int, fade: bool) -> void:
	if _previewing:
		return
	var value: String = TilesetBuilder.SEASONS[posmod(index, TilesetBuilder.SEASONS.size())]
	_wanted = value
	if not fade or value == _scene.season:
		set_season(value)
		return
	var curtain := _scene.season_fade()
	var scene := _scene
	await curtain.capture()
	if not is_instance_valid(scene) or not is_instance_valid(curtain):
		return  # the scene was freed during the fade
	if _wanted == value:
		set_season(value)
	curtain.fade_out()


## F3's Look: 0 to 3 shows that season at once, -1 goes back to the calendar's. The preview ends at the next season_ended.
func preview(index: int) -> void:
	_previewing = false
	show_season(calendar_index() if index < 0 else index, false)
	_previewing = index >= 0


func game_started() -> void:
	_previewing = false
	show_season(calendar_index(), false)


func season_ended() -> void:
	if _previewing:
		_previewing = false
		_settle.call_deferred()  # after whoever shows the new season (with a fade) has had its turn


## A preview that ended with the season, and nobody showed the new season meanwhile: the calendar's is shown.
func _settle() -> void:
	if not is_instance_valid(_scene):
		return
	if not _previewing and _wanted != TilesetBuilder.SEASONS[calendar_index()]:
		show_season(calendar_index(), false)


## Each frame: a season asked for before its pictures were loaded is swapped when they are; true while a swap goes on.
func tick() -> bool:
	if _pending != "" and TilesetBuilder.is_loaded(_pending, _scene.is_half_textures()):
		set_season(_pending)
	if _scene.view().is_swapping():
		_scene.view().swap_step(_scene.slice_ms)
		return true
	return false


func request_next() -> void:
	if not _scene.preload_next_season or DisplayServer.get_name() == "headless":
		return
	var seasons := TilesetBuilder.SEASONS
	TilesetBuilder.request_season(seasons[(seasons.find(_scene.season) + 1) % seasons.size()], _scene.is_half_textures())


func _swap_to(loaded: TilesetBuilder) -> void:
	tiles = loaded
	var view := _scene.view()
	view.begin_season_swap(loaded, _hexes_on_screen())
	view.swap_step(_scene.slice_ms)
	request_next()


## The hexes the camera sees (a Rect2i), for what is done nearest the screen first.
func _hexes_on_screen() -> Rect2i:
	var camera := _scene.camera()
	var half := _scene.get_viewport_rect().size / (2.0 * camera.zoom.x)
	var low := _scene.view().hex_at(camera.position - half)
	var high := _scene.view().hex_at(camera.position + half)
	return Rect2i(low, high - low + Vector2i.ONE).abs()
