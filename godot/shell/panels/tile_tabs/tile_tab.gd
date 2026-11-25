## The base of a tile window tab (tile-window spec R11). A tab is one script in shell/panels/tile_tabs/ whose name ends in
## `_tab.gd` and extends this class. Each tab script declares, as constants, `ID` (StringName), `LABEL` (String) and
## `ORDER` (int, unique across the tabs), and overrides `applies` and `fill`. TileTabs finds the scripts and checks them;
## the window never names a tab.
class_name TileTab
extends VBoxContainer

## A row of the tab is under the pointer or the keyboard: the card (a Dictionary) and the rect to anchor it to.
signal row_hovered(card: Dictionary, anchor: Rect2)
## The pointer or the keyboard left the row.
signal row_unhovered()
## A works request for the App: {what: StringName, args: Dictionary} (the payload of TileWindow.works_requested).
signal works_requested(request: Dictionary)
## A toast (text, tone).
signal toast_requested(text: String, tone: StringName)
## An App request, e.g. &"raise_screen", &"open_battle", &"goto_hex", with its args.
signal app_requested(what: StringName, args: Dictionary)
## The tab asks the window to open another tab (a live one; the window ignores a dimmed or absent id).
signal open_tab_requested(id: StringName)

## The icon inside a card's square icon tile and inside a round plaque icon (issue 436, mockup v4), in logical pixels.
const ICON_TILE_PX := Vector2(24, 24)
const ICON_ROUND_PX := Vector2(14, 14)


## Whether the tab shows for this view (a TileView dictionary). Static, so the registry can ask without an instance.
static func applies(_view: Dictionary) -> bool:
	return false


## Why the tab is dimmed for this view, or "" when it is live (tile-window spec R14). A shown tab that is dimmed is drawn
## dimmed, its reason is the tooltip, and it is neither clickable nor reached by the tab keys. Static, like applies.
static func dimmed(_view: Dictionary) -> String:
	return ""


## Fills the tab for the hex. Overridden by each tab.
func fill(_game: Game, _viewer: StringName, _hex: Vector2i, _view: Dictionary) -> void:
	pass


## The square wooden icon tile of a card (mockup v4), or with `round_icon` the small round icon of a plaque: the Kit icon `icon`
## of `host`'s theme, or an empty tile when the kit has none. Shared by the tabs.
static func icon_tile(host: Control, icon: StringName, round_icon: bool = false) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"PanelTileRound" if round_icon else &"PanelTileIcon"
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var picture := TextureRect.new()
	picture.custom_minimum_size = ICON_ROUND_PX if round_icon else ICON_TILE_PX
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != &"" and host.has_theme_icon(icon, &"Kit"):
		picture.texture = host.get_theme_icon(icon, &"Kit")
	tile.add_child(picture)
	return tile
