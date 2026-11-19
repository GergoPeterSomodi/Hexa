## New game modal (docs/architecture/m2-build-spec.md section 7.7): the scenario list with its blurb, the country note,
## a seed under "More" (filled with a random one when the page opens) and Random, Back (Esc) and Begin. Begin ends the
## screen and sends app_requested(&"new_game", {scenario, seed}); the App ends the menus and starts the game.
class_name NewGame
extends Screen

const SEED_MAX_DIGITS := 9
const RANDOM_SEED_MIN := 1
const RANDOM_SEED_MAX := 999999
const COUNTRY_NOTE := "You choose it on the map once it is drawn."

@onready var _frame: ModalFrame = $Center/Frame

var _scenario_list: NavList = null
var _blurb_label: Label = null
var _more_btn: KitButton = null
var _more_box: VBoxContainer = null
var _seed_input: LineEdit = null
var _random_btn: KitButton = null
var _reason_label: Label = null
var _back_btn: KitButton = null
var _begin_btn: KitButton = null
var _rng := RandomNumberGenerator.new()
var _scenario_ids: Array[String] = []
var _ui_built: bool = false


func _ready() -> void:
	_rng.randomize()
	_ensure_ui()


func on_enter() -> void:
	_ensure_ui()
	_apply_reduce_motion()
	_refresh_scenarios()
	roll_random_seed()


## Esc closes the screen (ScreenStack pops it).
func back() -> bool:
	return false


func frame() -> ModalFrame:
	_ensure_ui()
	return _frame


func scenario_list() -> NavList:
	_ensure_ui()
	return _scenario_list


func scenario_ids() -> Array[String]:
	return _scenario_ids.duplicate()


func blurb_label() -> Label:
	_ensure_ui()
	return _blurb_label


func more_button() -> KitButton:
	_ensure_ui()
	return _more_btn


func more_box() -> VBoxContainer:
	_ensure_ui()
	return _more_box


func seed_input() -> LineEdit:
	_ensure_ui()
	return _seed_input


func random_button() -> KitButton:
	_ensure_ui()
	return _random_btn


func reason_label() -> Label:
	_ensure_ui()
	return _reason_label


func back_button() -> KitButton:
	_ensure_ui()
	return _back_btn


func begin_button() -> KitButton:
	_ensure_ui()
	return _begin_btn


## The id of the selected scenario, or "" when none is listed.
func selected_scenario() -> String:
	_ensure_ui()
	return str(_scenario_list.selected_id())


## The seed in the field, or -1 when it is not 1 to 9 digits.
func current_seed() -> int:
	_ensure_ui()
	return parse_seed(_seed_input.text)


## The seed of a typed text: digits only, at most SEED_MAX_DIGITS, or -1.
static func parse_seed(raw: String) -> int:
	var text := raw.strip_edges()
	if text.is_empty() or text.length() > SEED_MAX_DIGITS or not text.is_valid_int():
		return -1
	if text.begins_with("-") or text.begins_with("+"):
		return -1
	return text.to_int()


## Puts a new random seed in the field and returns it.
func roll_random_seed() -> int:
	_ensure_ui()
	var next_seed := _rng.randi_range(RANDOM_SEED_MIN, RANDOM_SEED_MAX)
	_seed_input.text = str(next_seed)
	return next_seed


## Sends new_game for the selected scenario and the typed seed. A bad seed is refused in place and nothing is sent.
func begin() -> bool:
	_ensure_ui()
	var scenario := selected_scenario()
	if scenario.is_empty():
		_say("Choose a scenario first.")
		return false
	var seed_value := current_seed()
	if seed_value < 0:
		_say("The seed is digits only, up to nine.")
		return false
	_say("")
	finished.emit(&"begin")
	if ctx != null:
		ctx.request(&"new_game", {"scenario": scenario, "seed": seed_value})
	return true


func _ensure_ui() -> void:
	if _ui_built:
		return
	if _frame == null:
		_frame = get_node_or_null("Center/Frame") as ModalFrame
	if _frame == null:
		return
	_ui_built = true
	var body := _frame.body()

	body.add_child(PanelKit.label("Scenario", &"SectionHead"))
	_scenario_list = NavList.new()
	_scenario_list.name = &"Scenarios"
	_scenario_list.selected.connect(_on_scenario_selected)
	body.add_child(_scenario_list)
	_blurb_label = PanelKit.label("", &"LabelFlavour")
	_blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_blurb_label)

	body.add_child(PanelKit.label("Your country", &"SectionHead"))
	body.add_child(PanelKit.label(COUNTRY_NOTE, &"Body"))

	_more_btn = KitButton.new()
	_more_btn.name = &"MoreButton"
	_more_btn.text = "More"
	_more_btn.kind = KitButton.Kind.SECONDARY
	_more_btn.toggle_mode = true
	_more_btn.toggled.connect(_on_more_toggled)
	body.add_child(_more_btn)

	_more_box = VBoxContainer.new()
	_more_box.name = &"MoreBox"
	_more_box.visible = false
	_more_box.add_child(PanelKit.label("Seed", &"Hint"))
	var seed_row := HBoxContainer.new()
	seed_row.name = &"SeedRow"
	_seed_input = LineEdit.new()
	_seed_input.name = &"SeedInput"
	_seed_input.placeholder_text = "digits"
	_seed_input.max_length = SEED_MAX_DIGITS
	_seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(_seed_input)
	_random_btn = KitButton.new()
	_random_btn.name = &"RandomButton"
	_random_btn.text = "Random"
	_random_btn.kind = KitButton.Kind.SECONDARY
	_random_btn.pressed.connect(_on_random_pressed)
	seed_row.add_child(_random_btn)
	_more_box.add_child(seed_row)
	body.add_child(_more_box)

	_reason_label = PanelKit.reason("")
	_reason_label.visible = false
	body.add_child(_reason_label)

	var foot := _frame.footer()
	_back_btn = KitButton.new()
	_back_btn.name = &"BackButton"
	_back_btn.text = "Back"
	_back_btn.kind = KitButton.Kind.SECONDARY
	_back_btn.hotkey_action = &"app_back"
	_back_btn.pressed.connect(_on_back_pressed)
	foot.add_child(_back_btn)
	_begin_btn = KitButton.new()
	_begin_btn.name = &"BeginButton"
	_begin_btn.text = "Begin"
	_begin_btn.kind = KitButton.Kind.PRIMARY
	_begin_btn.pressed.connect(_on_begin_pressed)
	foot.add_child(_begin_btn)
	default_focus = get_path_to(_begin_btn)


func _refresh_scenarios() -> void:
	var items: Array = []
	_scenario_ids.clear()
	var defs := Session.defs()
	if defs != null:
		for scenario: ScenarioDef in defs.scenarios:
			if scenario == null:
				continue
			_scenario_ids.append(scenario.id)
			items.append({"id": StringName(scenario.id), "text": scenario.name})
	_scenario_list.set_items(items)
	if not _scenario_ids.is_empty():
		_scenario_list.select(StringName(_scenario_ids[0]))
	_show_blurb()
	_refresh_begin()


func _refresh_begin() -> void:
	if Session.defs() == null:
		_begin_btn.set_verdict({"ok": false, "reason": "the game definitions did not load"})
	elif _scenario_ids.is_empty():
		_begin_btn.set_verdict({"ok": false, "reason": "no scenario is listed"})
	else:
		_begin_btn.set_verdict({"ok": true})


func _show_blurb() -> void:
	var defs := Session.defs()
	var scenario: ScenarioDef = null
	if defs != null:
		scenario = defs.scenario(selected_scenario())
	_blurb_label.text = scenario.blurb if scenario != null else ""


func _say(text: String) -> void:
	_reason_label.text = text
	_reason_label.visible = not text.is_empty()


func _apply_reduce_motion() -> void:
	var reduce := _reduce_motion()
	for btn: KitButton in [_more_btn, _random_btn, _back_btn, _begin_btn]:
		btn.reduce_motion = reduce


func _reduce_motion() -> bool:
	if ctx != null and ctx.settings != null:
		return bool(ctx.settings.get_value("accessibility/reduce_motion"))
	return false


func _on_scenario_selected(_id: StringName) -> void:
	_show_blurb()


func _on_more_toggled(on: bool) -> void:
	_more_box.visible = on


func _on_random_pressed() -> void:
	roll_random_seed()


func _on_begin_pressed() -> void:
	begin()


func _on_back_pressed() -> void:
	finished.emit(&"back")
