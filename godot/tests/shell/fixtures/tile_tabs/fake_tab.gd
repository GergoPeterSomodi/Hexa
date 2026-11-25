## A fake tab for the registry test (tile-window spec R11): ORDER 50 is free (town 10, army 30, ships 40), so the fake can
## take it. It applies on an own settlement: a view of the player's own case with a settlement. Lives in a test folder, never
## in the game.
extends TileTab

const ID := &"industry"
const LABEL := "Industry"
const ORDER := 50


static func applies(view: Dictionary) -> bool:
	return String(view.get("case", "")) == "own" and bool(view.get("settlement", false))
