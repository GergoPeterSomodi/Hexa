## The base of a tile window tab (tile-window spec R11). A tab is one script in shell/panels/tile_tabs/ whose name ends in
## `_tab.gd` and extends this class. Each tab script declares, as constants, `ID` (StringName), `LABEL` (String) and
## `ORDER` (int, unique across the tabs), and overrides `applies` and `fill`. TileTabs finds the scripts and checks them;
## the window never names a tab.
class_name TileTab
extends VBoxContainer


## Whether the tab shows for this view (a TileView dictionary). Static, so the registry can ask without an instance.
static func applies(_view: Dictionary) -> bool:
	return false


## Fills the tab for the hex. Overridden by each tab.
func fill(_game: Game, _viewer: StringName, _hex: Vector2i, _view: Dictionary) -> void:
	pass
