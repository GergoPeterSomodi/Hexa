## What the map scene needs of the panel that shows the selected hex (T13 to T14). A real panel (shell/panels/hex_panel)
## extends this class and overrides the four methods marked "override"; the map scene knows only this type.
##
## The contract:
##  - The scene calls show_hex(hex) when the player selects a hex, clear() when the selection goes, and refresh() after
##    ANY Events.hex_changed while a hex is shown (a build elsewhere can change what this hex may build).
##  - The panel READS the game (Session.game.map and .state, Improve.piece_at, Improve.build_options, Improve.facts_of,
##    Session.check) and CHANGES it only by Session.act("build" {hex, family} / "upgrade" {hex} / "clear" {hex}). It never
##    touches the map view, the camera or the tiles: the scene redraws from Events.hex_changed.
##  - A refused action's button is disabled and shows the verdict's reason (as a tooltip and a short line).
##  - The panel stops the mouse (mouse_filter STOP, buttons focus_mode NONE) so a click on it never reaches the map, and
##    it is hidden while no hex is shown.
##  - action_buttons() lists the buttons in order, for tests and tools to press.
class_name HexPanelContract
extends PanelContainer

const NO_HEX := Vector2i(-9999, -9999)


## Override. Shows the panel for this hex of Session.game.map.
func show_hex(_hex: Vector2i) -> void:
	push_error("HexPanelContract.show_hex is not overridden")


## Override. Hides the panel; nothing is shown afterwards.
func clear() -> void:
	push_error("HexPanelContract.clear is not overridden")


## Override. Reads the game again for the shown hex (its facts, its options and their reasons).
func refresh() -> void:
	push_error("HexPanelContract.refresh is not overridden")


## Override. The hex shown, or NO_HEX.
func shown_hex() -> Vector2i:
	return NO_HEX


## The buttons in the panel's order (Build / Upgrade / Clear); the default searches the children.
func action_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for node: Node in find_children("*", "Button", true, false):
		out.append(node as Button)
	return out
