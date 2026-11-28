## A thin walnut strip behind the key hints while the drawn map shows (docs/architecture/map-overview-build-spec.md,
## amendment of 2026-11-28): their pale text cannot be read on the paper. It wears the kit's card (PanelCard: the legend's
## frame, and in high contrast its black field with the gold line), is as wide as the hints shown and a little more all
## round, and is as solid as the drawn map. With the drawn map hidden there is none: the tile view is as before. It
## follows the KeyHints it is pointed at, reads how solid the map's parchment is (follow; once a frame, and it changes
## nothing there) and takes no mouse.
class_name HintStrip
extends PanelContainer

## How far the strip reaches past the hints: sideways (under the gap the Hud leaves between them and the scale bar) and up
## and down (under the room between them and the Return button).
const PAD := Vector2(6.0, 4.0)

## The key hints the strip stands behind, a sibling.
@export var hints_path: NodePath

var _hints: KeyHints = null
var _map: ParchmentMap = null
var _alpha := 0.0


## The strip round `hints`, in their parent's space; empty while they show nothing.
static func rect_round(hints: KeyHints) -> Rect2:
	var width := hints.get_combined_minimum_size().x
	if not hints.visible or width <= 0.0:
		return Rect2()
	return Rect2(hints.position, Vector2(width, hints.size.y)).grow_individual(PAD.x, PAD.y, PAD.x, PAD.y)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_hints = get_node(hints_path) as KeyHints
	for moved: Signal in [_hints.item_rect_changed, _hints.visibility_changed, _hints.minimum_size_changed]:
		moved.connect(_queue_place)


## The drawn map the strip comes and goes with (null: no map).
func follow(map: ParchmentMap) -> void:
	_map = map
	_read_map()


func _process(_delta: float) -> void:
	_read_map()


## How solid the drawn map shows now: its picture's alpha while it cross-fades, else whole or not at all.
func _read_map() -> void:
	var alpha := 0.0
	if _map != null and is_instance_valid(_map) and _map.visible:
		alpha = _map.picture().self_modulate.a
	if alpha != _alpha:
		_alpha = alpha
		_place()


## The hints settle a frame late.
func _queue_place() -> void:
	_place.call_deferred()


func _place() -> void:
	var rect := rect_round(_hints)
	visible = _alpha > 0.0 and rect.has_area()
	modulate.a = _alpha
	if visible:
		position = rect.position
		size = rect.size
