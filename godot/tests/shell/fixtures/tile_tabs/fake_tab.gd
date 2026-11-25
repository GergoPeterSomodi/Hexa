## A fake tab for the registry test (tile-window spec R11): ORDER 30 is the slot the Industries tab reserves (D6). It applies
## on an own settlement: a view of the player's own case with a settlement. Lives in a test folder, never in the game.
extends TileTab

const ID := &"industry"
const LABEL := "Industry"
const ORDER := 30


static func applies(view: Dictionary) -> bool:
	return String(view.get("case", "")) == "own" and bool(view.get("settlement", false))
