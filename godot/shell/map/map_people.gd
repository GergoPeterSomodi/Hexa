## The map's people (docs/architecture/m5-build-spec.md 6.8, 6.9): a town that grew or a district that declined names
## again exactly the tiles of MapCells.touched_by and relays the place plates (MapLabels.set_state and refresh), and after
## each season the player's people ribbons float through Floaters.add_ribbon. A child of the map scene; it reads the game
## from Session and changes nothing in it.
class_name MapPeople
extends Node

var _view: TileMapView = null
var _labels: MapLabels = null
var _floaters: Floaters = null
var _overlay: ModeOverlay = null


## Takes its layers from the map scene it is a child of: the tile view, the place plates, the floaters (null when the
## scene has none) and the overlay.
func _ready() -> void:
	var scene := get_parent()
	_view = scene.get_node_or_null("View") as TileMapView
	_labels = scene.get_node_or_null("Names/Labels") as MapLabels
	_floaters = scene.get_node_or_null("Names/Floaters") as Floaters
	_overlay = scene.get_node_or_null("Overlay") as ModeOverlay
	Events.game_started.connect(_on_game_started)
	Events.town_grew.connect(_on_town_grew)
	Events.district_declined.connect(_on_district_declined)
	Events.season_ended.connect(_on_season_ended)
	_on_game_started()


func _exit_tree() -> void:
	for pair: Array in [[Events.game_started, _on_game_started], [Events.town_grew, _on_town_grew], [Events.district_declined, _on_district_declined],
			[Events.season_ended, _on_season_ended]]:
		if (pair[0] as Signal).is_connected(pair[1] as Callable):
			(pair[0] as Signal).disconnect(pair[1] as Callable)


## A game began (or the scene opened on one): the plates read their levels from the game's state (spec 6.9).
func _on_game_started() -> void:
	if _labels != null and Session.game != null:
		_labels.set_state(Session.game.state)


func _on_town_grew(_tag: StringName, hex: Vector2i, _level: int) -> void:
	_repaint(hex)


func _on_district_declined(_tag: StringName, hex: Vector2i, _level: int, _why: StringName) -> void:
	_repaint(hex)


## The tiles of `hex` and its six neighbours are named again (exactly MapCells.touched_by), the plates take the new level and the Food texture follows (in Food mode).
func _repaint(hex: Vector2i) -> void:
	var game := Session.game
	if game == null or game.map == null or game.state == null or _view == null:
		return
	for touched: Vector2i in MapCells.touched_by(game.map, hex):
		_view.set_hex(touched, MapCells.of_hex(game.map, game.state, touched))
	if _labels != null:
		_labels.set_state(game.state)
		_labels.refresh()
	if _overlay != null:
		_overlay.sync_modes(game)


## The season's ribbons: PeopleView.ribbons for the player, through the floaters' public add_ribbon.
func _on_season_ended(_turn: int) -> void:
	var game := Session.game
	if _overlay != null:
		_overlay.sync_modes(game)
	if _floaters == null or game == null or game.state == null or game.player == &"":
		return
	for ribbon: Dictionary in PeopleView.ribbons(game, game.player):
		_floaters.add_ribbon(ribbon["hex"] as Vector2i, str(ribbon["text"]), StringName(str(ribbon["tone"])))
