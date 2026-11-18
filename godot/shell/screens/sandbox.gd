## Map sandbox launch modal screen with map display, seed input, random seed button,
## and app_requested("start_sandbox", {map_id, seed}) dispatch
## (docs/architecture/ui-and-controls-spec.md section 5.1).
class_name Sandbox
extends Screen

const DEFAULT_MAP_ID := "north_italy"
const DEFAULT_SEED := 1480
const RANDOM_SEED_MIN := 1
const RANDOM_SEED_MAX := 999999

@onready var _frame: ModalFrame = $Center/Frame

var _seed_input: LineEdit = null
var _random_btn: KitButton = null
var _hint_label: Label = null
var _back_btn: KitButton = null
var _start_btn: KitButton = null
var _rng := RandomNumberGenerator.new()
var _ui_built: bool = false


func _ready() -> void:
	_rng.randomize()
	_ensure_ui()


func on_enter() -> void:
	_ensure_ui()
	var reduce := _reduce_motion()
	_random_btn.reduce_motion = reduce
	_back_btn.reduce_motion = reduce
	_start_btn.reduce_motion = reduce


func back() -> bool:
	return false


func seed_input() -> LineEdit:
	_ensure_ui()
	return _seed_input


func random_button() -> KitButton:
	_ensure_ui()
	return _random_btn


func start_button() -> KitButton:
	_ensure_ui()
	return _start_btn


func back_button() -> KitButton:
	_ensure_ui()
	return _back_btn


func hint_label() -> Label:
	_ensure_ui()
	return _hint_label


## Returns the currently entered seed (or DEFAULT_SEED if empty), or -1 if invalid.
func current_seed() -> int:
	_ensure_ui()
	var raw := _seed_input.text.strip_edges()
	if raw.is_empty():
		return DEFAULT_SEED
	if not raw.is_valid_int():
		return -1
	return raw.to_int()


## Generates and sets a new random seed in the input field.
func roll_random_seed() -> int:
	_ensure_ui()
	var next_seed := _rng.randi_range(RANDOM_SEED_MIN, RANDOM_SEED_MAX)
	_seed_input.text = str(next_seed)
	_set_error("")
	return next_seed


func _ensure_ui() -> void:
	if _ui_built:
		return
	if _frame == null:
		_frame = get_node_or_null("Center/Frame") as ModalFrame
	if _frame == null:
		return
	_ui_built = true
	_frame.closed.connect(_on_back_pressed)

	var body := _frame.body()

	var map_row := HBoxContainer.new()
	map_row.name = &"MapRow"
	var map_key := Label.new()
	map_key.theme_type_variation = &"SectionHead"
	map_key.text = "Map"
	map_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_row.add_child(map_key)
	var map_val := Label.new()
	map_val.theme_type_variation = &"Body"
	map_val.text = "North Italy"
	map_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	map_row.add_child(map_val)
	body.add_child(map_row)

	var seed_row := HBoxContainer.new()
	seed_row.name = &"SeedRow"
	var seed_lbl := Label.new()
	seed_lbl.theme_type_variation = &"Body"
	seed_lbl.text = "Seed"
	seed_row.add_child(seed_lbl)

	_seed_input = LineEdit.new()
	_seed_input.name = &"SeedInput"
	_seed_input.text = str(DEFAULT_SEED)
	_seed_input.placeholder_text = str(DEFAULT_SEED)
	_seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_input.accessibility_name = "Seed"
	_seed_input.text_submitted.connect(_on_seed_submitted)
	_seed_input.text_changed.connect(_on_seed_changed)
	seed_row.add_child(_seed_input)

	_random_btn = KitButton.new()
	_random_btn.name = &"RandomButton"
	_random_btn.kind = KitButton.Kind.SMALL
	_random_btn.text = "Random"
	_random_btn.pressed.connect(_on_random_pressed)
	seed_row.add_child(_random_btn)
	body.add_child(seed_row)

	_hint_label = Label.new()
	_hint_label.name = &"HintLabel"
	_hint_label.theme_type_variation = &"Hint"
	_hint_label.text = "Enter a numeric seed or roll a random one."
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_hint_label)

	var foot := _frame.footer()
	_back_btn = KitButton.new()
	_back_btn.name = &"BackButton"
	_back_btn.kind = KitButton.Kind.SECONDARY
	_back_btn.text = "Back"
	_back_btn.pressed.connect(_on_back_pressed)
	foot.add_child(_back_btn)

	_start_btn = KitButton.new()
	_start_btn.name = &"StartButton"
	_start_btn.kind = KitButton.Kind.PRIMARY
	_start_btn.text = "Start"
	_start_btn.pressed.connect(_on_start_pressed)
	foot.add_child(_start_btn)

	default_focus = get_path_to(_start_btn)


func _set_error(msg: String) -> void:
	if msg.is_empty():
		_hint_label.theme_type_variation = &"Hint"
		_hint_label.text = "Enter a numeric seed or roll a random one."
	else:
		_hint_label.theme_type_variation = &"NumberBad"
		_hint_label.text = msg


func _on_seed_changed(_new_text: String) -> void:
	if current_seed() >= 0:
		_set_error("")


func _on_seed_submitted(_submitted_text: String) -> void:
	_on_start_pressed()


func _on_random_pressed() -> void:
	roll_random_seed()


func _on_back_pressed() -> void:
	finished.emit(&"cancel")


func _on_start_pressed() -> void:
	var seed_val := current_seed()
	if seed_val < 0:
		_set_error("Seed must be a whole non-negative number.")
		return
	if ctx != null:
		ctx.request(&"start_sandbox", {"map_id": DEFAULT_MAP_ID, "seed": seed_val})


func _reduce_motion() -> bool:
	if ctx != null and ctx.settings != null:
		return bool(ctx.settings.get_value("accessibility/reduce_motion"))
	return false
