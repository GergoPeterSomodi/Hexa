## The App's M4 handlers (docs/architecture/m4-build-spec.md 6.9 and 6.12), kept out of app.gd and game_requests.gd so those stay
## under their size limits: the works card (a row's hover, the (i) button, U), Begin and Cancel the work, the marks the card
## shows on the map, the Statesman's Study (one instance for the game's life) and the tax toast. GameRequests makes one with the
## App; it connects the signals below, asks it to answer the requests it knows (`handle`) and tells it when the map scene
## comes or goes. It reads the App only through its public accessors and changes the game only through Session.
class_name WorksFlow
extends RefCounted

const NOTHING_TO_BUILD := "Nothing to build or upgrade here."
const NO_TREASURY := "The sandbox has no treasury."
const CONFIRM_KEY := "game/confirm_works"
const TREASURY_KEY := "game/gain_treasury_only"

var _app: App = null
var _scene: MapScene = null
var _card: WorksPreview = null
var _study: Study = null
## The player's tax level before the last change (tax_set carries only the new one): the toast names the gain.
var _tax_level: int = -1
var _links: Array[Array] = []


func _init(app: Node) -> void:
	_app = app as App


## Connects the signals this class answers. `link` is the App's `_link(emitter, signal, handler)`.
func connect_signals(link: Callable) -> void:
	var hud := _app.hud()
	link.call(hud.hex_panel(), &"works_requested", on_works_requested)
	link.call(hud.hex_panel(), &"row_hovered", on_row_hovered)
	link.call(hud.hex_panel(), &"row_unhovered", on_row_unhovered)
	link.call(hud, &"study_requested", open_study)
	link.call(Events, &"tax_set", _on_tax_set)
	link.call(Events, &"game_started", _sync_tax)
	link.call(Events, &"country_chosen", _on_country_chosen)


## The map scene came: U, I and L, and a new selection (which closes the card).
func bind_scene(scene: MapScene) -> void:
	unbind_scene(_scene)
	_scene = scene
	_links = [
		[scene.upgrade_requested, on_upgrade_requested],
		[scene.selection_changed, _on_selection_changed],
	]
	if scene.map_input() != null:
		_links.append([scene.map_input().study_requested, open_study])
	for pair: Array in _links:
		(pair[0] as Signal).connect(pair[1] as Callable)


func unbind_scene(scene: MapScene) -> void:
	if scene != null and is_instance_valid(scene):
		for pair: Array in _links:
			if (pair[0] as Signal).is_connected(pair[1] as Callable):
				(pair[0] as Signal).disconnect(pair[1] as Callable)
	if scene == _scene:
		_links = []
		_scene = null
		_card = null


## A request from a screen or the console (ShellContext.request) that this class answers. False for any other.
func handle(what: StringName, args: Dictionary) -> bool:
	match what:
		&"works_card":
			show_card(args["hex"] as Vector2i, args["option"] as Dictionary, true)
		&"close_card":
			close_card()
		&"begin_work":
			begin(args["hex"] as Vector2i, args["option"] as Dictionary)
		&"cancel_work":
			cancel(args)
		&"study":
			open_study(StringName(str(args.get("page", &""))))
		&"refresh_hud":
			_app.hud().refresh_economy()
		_:
			return false
	return true


# ----- the hex panel's requests ---------------------------------------------------------------------------------------


## The hex panel's works_requested(what, args): the same requests as app_requested.
func on_works_requested(what: StringName, args: Dictionary) -> void:
	handle(what, args)


## The pointer or the keyboard is on a row: its card opens beside the panel (no focus taken) with its marks on the map.
func on_row_hovered(hex: Vector2i, option: Dictionary) -> void:
	show_card(hex, option, false)


## The pointer left the row: the card closes unless Shift holds it or it is pinned. The panel may have been freed with
## the row (a refresh), and the card with it: both are checked.
func on_row_unhovered() -> void:
	var card := _live_card()
	if card != null:
		card.leave()


## U: the card of the selected hex's upgrade (on wild land its first allowed build), or the work at once by
## game/confirm_works (off: begins; expensive: begins unless the row is expensive; always: the card). Nothing to build or
## upgrade: a toast.
func on_upgrade_requested() -> void:
	var game := Session.game
	if game == null or _scene == null or _scene.selected == MapScene.NO_HEX:
		_toast(NOTHING_TO_BUILD)
		return
	var hex := _scene.selected
	var row := upgrade_row(game, Session.player_tag(), hex)
	if row.is_empty():
		var under_way := Works.upgrade_check(game, {"hex": hex, "tag": Session.player_tag()})
		if game.state.work_at(hex) != null and not bool(under_way["ok"]):  # the panel shows no rows for it: say why
			var option := {"action": Works.UPGRADE, "family": 0}
			var words := ImprovePreview.reason_words(game, hex, option, under_way)
			_toast(words if words != "" else str(under_way["reason"]), &"warn")
		else:
			_toast(NOTHING_TO_BUILD)
		return
	var option := {"action": row["action"], "family": row["family"]}
	if wants_card(row):
		show_card(hex, option, true)
	else:
		begin(hex, option)


## The row U acts on: the upgrade of a piece (even refused: the card says why), else the first build of wild land that the
## rules allow; {} when there is none.
static func upgrade_row(game: Game, tag: StringName, hex: Vector2i) -> Dictionary:
	var rows := ImprovePreview.options_of(game, tag, hex)
	for row: Dictionary in rows:
		if StringName(str(row["action"])) == Works.UPGRADE:
			return row
	for row: Dictionary in rows:
		if StringName(str(row["action"])) == Works.BUILD and bool((row["verdict"] as Dictionary)["ok"]):
			return row
	return {}


## Whether a row opens the card before the work begins: game/confirm_works always, or expensive for an expensive row.
func wants_card(row: Dictionary) -> bool:
	var mode := "expensive"
	if _app.settings() != null:
		mode = str(_app.settings().get_value(CONFIRM_KEY))
	return mode == "always" or (mode == "expensive" and bool(row["expensive"]))


# ----- the card -------------------------------------------------------------------------------------------------------


## Pushes the card (or updates the one up) for `option` on `hex`, beside the hex panel, and shows its ghost and marks on the
## map. `focus` puts the focus on Begin (the (i) button, U); a hover leaves it where it is.
func show_card(hex: Vector2i, option: Dictionary, focus: bool) -> void:
	var game := Session.game
	if game == null or _scene == null or _app.is_starting() or _scene.picking() or _app.hides_world():
		return
	var card := _live_card()
	if card == null:
		if _app.stack().count() > 0:
			return  # another screen is up: no card over it
		card = ScreenIds.make(&"works_preview") as WorksPreview
		if card == null:
			return
		card.finished.connect(_on_card_finished.bind(card))
		_card = card
		_app.stack().push(card)
	var panel := _app.hud().hex_panel()
	if panel.is_visible_in_tree():
		card.set_beside(Hud.screen_rect(panel))
	card.show_option(hex, option, focus)
	_scene.show_preview(card.preview())


## The screen stack changed: a screen other than the card above an open card (the pause menu) closes it with its marks.
func on_stack_changed() -> void:
	var card := _live_card()
	if card != null and _app.stack().top() != card:
		close_card()


## Closes the card (a request, a new selection, Begin) and takes its marks off the map.
func close_card() -> void:
	var card := _live_card()
	if card != null:
		card.back()
	elif _scene != null and is_instance_valid(_scene):
		_scene.clear_marks()


## The card on the stack, else null (it may have finished and be waiting to be freed).
func _live_card() -> WorksPreview:
	if _card == null or not is_instance_valid(_card):
		_card = null
		return null
	if not _app.stack().has_screen(&"works_preview"):
		return null
	return _card


func _on_card_finished(_result: StringName, card: WorksPreview) -> void:
	if card == _card:
		_card = null
	if _scene != null and is_instance_valid(_scene):
		_scene.clear_marks()


func _on_selection_changed(_hex: Vector2i) -> void:
	close_card()


# ----- begin and cancel -----------------------------------------------------------------------------------------------


## Begins the work of `option` ({action, family}) on `hex` through Session. The toast of a begun work comes from the
## work_started event (GameRequests); a refusal is toasted here. The card closes either way.
func begin(hex: Vector2i, option: Dictionary) -> void:
	var game := Session.game
	if game == null:
		return
	var action := str(option["action"])
	var args := {"hex": hex}
	if action == String(Works.BUILD):
		args["family"] = int(option["family"])
	var verdict := Session.act(action, args)
	close_card()
	if not bool(verdict.get("ok", false)):
		var words := ImprovePreview.reason_words(game, hex, option, verdict)
		_toast(words if words != "" else str(verdict.get("reason", "")), &"warn")


## Cancels the work under way ({hex, tag, refund, refund_goods} from the hex panel). The toast of a cancelled work (with the
## refund) comes from the work_cancelled event; a refusal is toasted here.
func cancel(args: Dictionary) -> void:
	var verdict := Session.act("cancel_work", {"hex": args["hex"], "tag": args["tag"]})
	if not bool(verdict.get("ok", false)):
		_toast(str(verdict.get("reason", "")), &"warn")


# ----- the study ------------------------------------------------------------------------------------------------------


## Pushes the study at `page` (&"" the last page shown); a game without countries toasts instead; a study already up shows
## the page. Nothing while the pick or another screen is up (the card closes first).
func open_study(page: StringName = &"") -> void:
	var game := Session.game
	if game == null or _scene == null:
		return
	if not game.has_countries():
		_toast(NO_TREASURY)
		return
	if Session.player_tag() == &"" or _app.is_starting():
		return
	var study := _study_screen()
	if study == null:
		return
	if _app.stack().has_screen(&"study"):
		study.open_page(page)
		return
	close_card()
	if _app.stack().count() > 0:
		return
	_app.stack().push(study)
	if page != &"":
		study.open_page(page)


## Takes the study off the stack when it is up (a look_at from one of its rows: the map is shown first).
func close_study() -> void:
	if _study != null and is_instance_valid(_study) and _app.stack().has_screen(&"study"):
		_study.back()


## The game is going: the study (which survives its own pops) is freed, the next game makes another.
func drop() -> void:
	if _study != null and is_instance_valid(_study) and not _study.is_inside_tree():
		_study.queue_free()
	_study = null
	_card = null


## The one Study of this game, made on the first ask.
func _study_screen() -> Study:
	if _study == null or not is_instance_valid(_study):
		_study = ScreenIds.make(&"study") as Study
		if _study != null:
			_study.configure(StudyPages.shown(Bindings.SHELL_MILESTONE))
	return _study


# ----- tax ------------------------------------------------------------------------------------------------------------


func _on_country_chosen(_tag: StringName) -> void:
	_sync_tax()


func _sync_tax() -> void:
	var game := Session.game
	var country := Countries.by_tag(game, game.player) if game != null and game.has_countries() else null
	_tax_level = country.tax if country != null else -1


## The player set taxes (the study's Segmented, the console): "Taxes set to High: about ▲ +38 a season." The gain is what
## the season in play earns over the old level (the study's tax options, one measure by game/gain_treasury_only).
func _on_tax_set(tag: StringName, level: int) -> void:
	var game := Session.game
	if game == null or tag != game.player:
		return
	var from := _tax_level
	_tax_level = level
	var text := "Taxes set to %s" % Words.tax_name(level)
	var gain := _tax_gain(game, tag, from)
	if gain != 0:
		text += ": about %s %s a season" % ["▲" if gain > 0 else "▼", Words.signed(gain)]
	_toast(text + ".")


func _tax_gain(game: Game, tag: StringName, from: int) -> int:
	if from < 0:
		return 0
	var options: Array = (StudyEconomy.this_season(game, tag)["tax"] as Dictionary)["options"]
	var only_treasury := _app.settings() != null and bool(_app.settings().get_value(TREASURY_KEY))
	for opt: Dictionary in options:
		if int(opt["level"]) == from:
			return -int(opt["change"] if only_treasury else opt["realm_change"])
	return 0


func _toast(text: String, tone: StringName = &"plain") -> void:
	_app.hud().toast(text, tone)
