## The tile window's flat parts and buttons (issue 436, the owner's mockup v4), as data: KitTheme turns each entry into a
## StyleBoxFlat of the generated themes (the high-contrast theme reads Tokens.HIGH_CONTRAST for every token named here). Colours
## are Tokens names, never literals; "" is no colour. The gold ornate frame itself is the kit's panel_frame (PanelTileFrame,
## KitTheme.PANEL_PADDED).
class_name TileStyle
extends RefCounted

## name -> [ground, border, border widths [l, t, r, b] (or one width), corner radius, content margins [l, t, r, b]].
const BOXES: Dictionary[String, Array] = {
	"PanelTileTitle": ["TILE_TITLE", "TILE_WOOD_LINE", [0, 0, 0, 1], 0, [8, 3, 8, 3]],
	"PanelTileSub": ["TILE_SUB", "TILE_WOOD_LINE", [0, 0, 0, 1], 0, [12, 4, 12, 4]],
	"PanelTileChips": ["TILE_CHIPS", "", 0, 0, [8, 4, 8, 4]],
	"PanelTileChip": ["TILE_CHIP", "TILE_CHIP_LINE", 1, 14, [3, 2, 8, 2]],
	"PanelTileChipIcon": ["TILE_CHIP_DOT", "BRASS", 1, 12, [4, 4, 4, 4]],
	"PanelTileChipMuted": ["TILE_CHIPS", "TILE_SEP", 1, 14, [3, 2, 8, 2]],
	"PanelTileBadgeBox": ["TILE_INSET", "TILE_GOLD_D", 1, 4, [4, 4, 4, 4]],
	"PanelTileRound": ["TILE_SEP", "TILE_GOLD_D", 1, 14, [5, 5, 5, 5]],
	"PanelTileRoundBad": ["TILE_SEP", "BAD", 1, 14, [5, 5, 5, 5]],
	"PanelTileFog": ["TILE_FOG", "", 0, 0, [0, 0, 0, 0]],
	"PanelTileStrip": ["TILE_WOOD", "TILE_WOOD_LINE", 1, 3, [0, 0, 0, 0]],
	"PanelTilePlaque": ["TILE_WOOD_DARK", "TILE_WOOD_LINE", [0, 0, 1, 0], 0, [8, 6, 8, 6]],
	"PanelTileTile": ["TILE_TILE", "BRASS", 1, 4, [0, 0, 0, 0]],
	"PanelTileTileWork": ["TILE_TILE", "TILE_FREE", 1, 4, [0, 0, 0, 0]],
	"PanelTileTileFree": ["TILE_INSET", "TILE_FREE", 1, 4, [0, 0, 0, 0]],
	"PanelTileTileShort": ["TILE_INSET", "BAD", 1, 4, [0, 0, 0, 0]],
	"PanelTileTileLock": ["TILE_LOCK", "TILE_SEP", 1, 4, [0, 0, 0, 0]],
	"PanelTileTileSlot": ["TILE_LOCK", "", 0, 4, [0, 0, 0, 0]],
	"PanelTileLevel": ["TILE_INSET", "TILE_GOLD_D", 1, 3, [3, 0, 3, 0]],
	"PanelTileCard": ["TILE_BODY", "BRASS", 1, 4, [0, 0, 0, 10]],
	"PanelTileCardHead": ["TILE_TITLE", "TILE_WOOD_LINE", [0, 0, 0, 1], 0, [12, 7, 12, 7]],
	"PanelTileCardBody": ["", "", 0, 0, [12, 6, 12, 0]],
	"PanelTileIcon": ["TILE_TILE", "TILE_WOOD_LINE", 1, 4, [5, 5, 5, 5]],
	"PanelTileQueue": ["", "", 0, 0, [8, 2, 8, 4]],
	"PanelTileQueueRow": ["TILE_WOOD_DARK", "TILE_WOOD_LINE", 1, 3, [8, 4, 6, 4]],
	"PanelTileLine": ["", "TILE_LINE", [0, 0, 0, 1], 0, [6, 3, 6, 3]],
	"PanelTileUnit": ["TILE_WOOD", "TILE_WOOD_LINE", 1, 3, [8, 4, 8, 4]],
	"PanelTileNote": ["TILE_INSET", "TILE_SEP", 1, 4, [12, 10, 12, 10]],
	"PanelTileSiege": ["TILE_SIEGE", "TILE_SIEGE_LINE", 1, 3, [10, 8, 10, 8]],
	# The 540 banner design (2026-11-26): the dark inset box of a tab (TileBoxes.box) and its key and value lines.
	"PanelTileBox": ["TILE_INSET", "TILE_WOOD_LINE", 1, 3, [9, 4, 9, 5]],
	"PanelTileBoxLine": ["", "TILE_LINE", [0, 0, 0, 1], 0, [0, 1, 0, 1]],
}

## name -> {size, font: [normal, hover, pressed, disabled] tokens, and a BOXES-style box for each state}. ButtonTileTab is the
## flat tab (the gold rule under the open tab, hairlines between tabs); ButtonTileHit lies over a building tile (no icon of its
## own, a gold rim on hover).
const BUTTONS: Dictionary[String, Dictionary] = {
	"ButtonTileTab": {"size": 15, "font": ["MUTED", "TEXT", "TEXT", "TILE_DIM"],
		"normal": ["TILE_TAB", "TILE_WOOD_LINE", [0, 0, 1, 1], 0, [6, 8, 6, 8]],
		"hover": ["TILE_TAB_ON", "TILE_WOOD_LINE", [0, 0, 1, 1], 0, [6, 8, 6, 8]],
		"pressed": ["TILE_TAB_ON", "PRIMARY", [0, 0, 0, 3], 0, [6, 8, 6, 8]],
		"disabled": ["TILE_TAB", "TILE_WOOD_LINE", [0, 0, 1, 1], 0, [6, 8, 6, 8]]},
	"ButtonTileIcon": {"size": 14, "font": ["GOLD", "TEXT", "TEXT", "TILE_DIM"],
		"normal": ["TILE_TITLE", "TILE_GOLD_D", 1, 13, [5, 5, 5, 5]], "hover": ["TILE_TAB_ON", "BRASS", 1, 13, [5, 5, 5, 5]],
		"pressed": ["TILE_TAB_ON", "BRASS", 1, 13, [5, 5, 5, 5]], "disabled": ["TILE_TITLE", "TILE_SEP", 1, 13, [5, 5, 5, 5]]},
	"ButtonTileSmall": {"size": 15, "font": ["GOLD", "TEXT", "TEXT", "TILE_DIM"],
		"normal": ["TILE_WOOD_DARK", "TILE_GOLD_D", 1, 4, [9, 3, 9, 3]], "hover": ["TILE_WOOD", "BRASS", 1, 4, [9, 3, 9, 3]],
		"pressed": ["TILE_WOOD", "BRASS", 1, 4, [9, 3, 9, 3]], "disabled": ["TILE_WOOD_DARK", "TILE_SEP", 1, 4, [9, 3, 9, 3]]},
	"ButtonTileAct": {"size": 15, "font": ["TEXT", "BRASS_HI", "BRASS_HI", "TILE_DIM"],
		"normal": ["TILE_TILE", "TILE_GOLD_D", 1, 4, [12, 5, 12, 5]], "hover": ["TILE_TILE", "BRASS", 1, 4, [12, 5, 12, 5]],
		"pressed": ["TILE_TILE", "BRASS", 1, 4, [12, 5, 12, 5]], "disabled": ["TILE_WOOD_DARK", "TILE_SEP", 1, 4, [12, 5, 12, 5]]},
	"ButtonTileCancel": {"size": 15, "font": ["BAD", "TEXT", "TEXT", "TILE_DIM"],
		"normal": ["", "BAD", 1, 3, [7, 2, 7, 2]], "hover": ["TILE_WOOD", "BAD", 1, 3, [7, 2, 7, 2]],
		"pressed": ["TILE_WOOD", "BAD", 1, 3, [7, 2, 7, 2]], "disabled": ["", "TILE_SEP", 1, 3, [7, 2, 7, 2]]},
	"ButtonTileLink": {"size": 15, "font": ["TILE_SUB_HI", "GOLD", "GOLD", "TILE_SUB_HI"],
		"normal": ["", "", 0, 0, [4, 0, 4, 0]], "hover": ["", "", 0, 0, [4, 0, 4, 0]],
		"pressed": ["", "", 0, 0, [4, 0, 4, 0]], "disabled": ["", "", 0, 0, [4, 0, 4, 0]]},
	"ButtonTileBadge": {"size": 15, "font": ["GOLD", "TEXT", "TEXT", "TILE_DIM"],
		"normal": ["TILE_SEP", "TILE_GOLD_D", 1, 14, [5, 5, 5, 5]], "hover": ["TILE_TAB_ON", "BRASS_HI", 1, 14, [5, 5, 5, 5]],
		"pressed": ["TILE_TAB_ON", "BRASS_HI", 1, 14, [5, 5, 5, 5]], "disabled": ["TILE_SEP", "TILE_SEP", 1, 14, [5, 5, 5, 5]]},
	"ButtonTileFold": {"size": 15, "font": ["MUTED", "TEXT", "TEXT", "TILE_DIM"],
		"normal": ["", "", 0, 0, [0, 0, 0, 0]], "hover": ["TILE_TAB", "", 0, 2, [0, 0, 0, 0]],
		"pressed": ["TILE_TAB", "", 0, 2, [0, 0, 0, 0]], "disabled": ["", "", 0, 0, [0, 0, 0, 0]]},
	"ButtonTileHit": {"size": 15, "font": ["", "", "", ""],
		"normal": ["", "", 0, 4, [0, 0, 0, 0]], "hover": ["", "GOLD", 2, 4, [0, 0, 0, 0]],
		"pressed": ["", "BRASS_HI", 2, 4, [0, 0, 0, 0]], "disabled": ["", "", 0, 4, [0, 0, 0, 0]]},
}
