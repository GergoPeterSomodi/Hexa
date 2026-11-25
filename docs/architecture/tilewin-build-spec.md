# Tile window build spec: one uniform window per tile (issue 436)

Technical director, 2026-11-25. **Status: a proposal; no task starts before the owner's go.** Builds section 3 of
`docs/design/ui-family-audit.md` ("the audit") **as the owner answered it** in its last section (2026-11-24), on top of the
fog build (`fog-build-spec.md`, on master). Where the audit's section 3 says something else, the owner's answers win, and
this page wins over both for the build. The tasks are in `tilewin-build-plan.md`.

**What it is, in one paragraph.** Every tile has one window, in the dock on the right where the hex panel is today. It has a
fixed **header** (the tile's name, its place and ground, its owner, badges for occupation, siege, battle and armies), a
**job line** (the work under way on the tile, with Cancel on your own) and a **tab strip**: **Details** (people, goods,
ground, fortress and garrison, siege), **Build** (today's works rows, moved unchanged), **Army** (today's Raise tab, plus the
armies on the tile), **Ships** (an empty tab on your own ports until M19), and later **Industries** (M9.5 adds it by adding
a file). The small right-click menu **stays** for quick actions. Every fact the window shows comes from one pure read model,
`TileView` (`core/views/`), which applies the fog of the fog build and nothing else, so the tests run headless and the fog is
proved in one place.

**The tile window build is done when:**

1. Every rule R1 to R27 below holds, each with its GUT case and its planted fault (P) of section 7.
2. The hex panel (`HexPanel`), its Works and Raise segment and its separate sea and unexplored paths are gone; the window
   replaces them behind the same seam (`HexPanelContract`), and every case of the old tests has a twin in the new ones (the
   checklist of section 7.3).
3. The right-click menu offers the items of R21 and nothing it offers today is lost.
4. A fake tab placed in a test folder shows in the strip with no edit to the window or the registry (R11).
5. `SaveFile.FORMAT`, `Game.digest()` and every core rule are unchanged; the soak and the AI tests do not move.
6. The perf rows of section 8 are within their limits.
7. Lint, import, check_scripts, GUT, both UI `--check`s green; the pictures of section 7.4 signed by the art director; the
   owner has played the plan's checklist.

---

## 1. What is there (read in the code, master after the fog build)

| Finding | Where | Meaning for the build |
|---|---|---|
| The hex panel is one 678-line script: cartouche, piece, ground, owner, war block, people, gives, worth, home reason, work section, works rows, a Works or Raise segment | `shell/panels/hex_panel.gd`, `.tscn` | Split into the frame and the tabs; the works rows are moved first, unchanged (plan group A) |
| The map scene knows only `HexPanelContract` (`show_hex`, `clear`, `refresh`, `shown_hex`, `action_buttons`) | `shell/map/hex_panel_contract.gd` | The window extends it; the map scene does not change |
| The hex menu is a `PopupMenu` on own hexes: works rows, "Raise companies here...", "Select <army>", the war items, "Show supply (6)" | `shell/hud/hex_menu.gd`, built by `MapArmies` | Stays (owner answer 1); two items change (R21) |
| `RaiseList.offered` (own settlement) is the Raise rule, in the shell | `shell/panels/raise_list.gd` 36 | Moved to core so `TileView` can read it (`Military.raise_offered`) |
| `is_port` lives in the AI door | `core/ai/ai_know.gd` 254 | A view may not read `core/ai/` (layers); moved to `Improve.is_port` |
| `HexCard.of`, `war_rows` and `_undiscovered` read `game.player`, not a viewer argument | `core/views/hex_card.gd` | `TileView` takes a viewer; `HexCard` gains `war_rows_for(game, hex, viewer)` and `war_rows(game, hex)` calls it with `game.player` (callers unchanged) |
| The fog functions take a viewer: `Knowledge.discovered`, `sees`, `garrison_known`, `siege_access`; `PeopleView.at`, `SiegeView.at`, `ArmyView.visible`, `BattleView.sites`, `WorksView.at` | `core/views/` | `TileView` reads only these for anything a fog rule covers |
| The panel already shows "Unexplored" (D18 of the fog spec) and a bare "Sea" | `hex_panel.gd` 258, 266 | Become cases of `TileView` (R2, R3) |
| Tab is "Next unit"; Left and Right pan the camera; Ctrl+[ and Ctrl+] are the Study's tab keys (the Study is a screen) | `shell/input/bindings.gd` | The window's keys (R22) avoid the map's keys |
| HUD buttons stay out of the focus chain (ui-and-controls spec 3.x), but the panel's rows take focus today (`FOCUS_ALL`) | `hex_panel.gd` | Kept as today: rows and the strip take focus once the player is in the window |
| No golden shows the hex panel except the scenes of `shot_ui.gd` (`m4_hex_panel_rows`), `shot_ui_m6.gd` (the Raise tab, the hex menu) and `shot_ui_fog.gd` | `tools/ui/` | Their scenes move to the window (section 7.4) |

---

## 2. Decisions taken

| # | Question | Decision | Why |
|---|---|---|---|
| D1 | Window or screen? | The window is the **dock panel** (right column, as the hex panel), not a modal screen | The map stays live beside it; the Esc ladder, the seam and the dock's swap with the country and army panels already work |
| D2 | Width | `Tokens.PANEL_W` (296), the family's width. The fifth tab's label is "Industry" | One width for the hex, country and army panels; five short labels fit (R23 proves it). If a later label does not fit, the strip switches to icons with the word as tooltip, a change in one file |
| D3 | Where the rules of "which tab applies" live | `TileView` (core) gives the **facts** (case, sight, own, settlement, port, build offered, raise offered, armies seen); each tab's `applies(view)` in the shell reads only that dictionary | Core cannot know the shell's tab list; the facts are tested in core, the tab choice is a pure static function, testable headless |
| D4 | How a later milestone adds a tab | A tab is one file in `shell/panels/tile_tabs/` named `*_tab.gd`; `TileTabs` lists the folder (`ResourceLoader.list_directory`, which works in exported builds) and orders by each tab's `ORDER` | "Add a file" with no edit to the window or the registry. Task TW3 probes the listing in an exported Windows build first; if the probe fails, a generator (`tools/build_tile_tabs.gd`, with `--check` in CI, as `build_theme.gd`) writes the index from the folder, which keeps "add a file" |
| D5 | Ships tab: where | On **your own port settlements only** (`Improve.is_port`: a place of level 1 or more with a port and a shore), as an empty tab with one line | The owner asked for an empty tab until ships exist; on a port it keeps the place where ships will be raised. On every tile it would be a dead tab on most of the map |
| D6 | Industries | **No file in this build**; `ORDER` 30 is reserved for it; M9.5 adds `industries_tab.gd` and its model `core/views/tile_industries.gd` | The owner: hidden until M9.5; the registry proves the slot with a fake tab (R11) |
| D7 | Which tab opens | The tab the player last picked, if it applies to the new tile; else Build if it applies; else Details. Kept for the life of the window, not saved | Building is the most common act on own land (one click, as today); a player checking armies stays on Army from tile to tile |
| D8 | The right-click menu | Stays, on own hexes only, as today; "Raise companies here..." opens the window on the Army tab; a new first item "Tile details..." opens it on Details (R21) | Owner answer 1: the window for details, the menu for quick actions |
| D9 | Tab keys | Ctrl+] and Ctrl+[ (the actions `study_tab_next`/`study_tab_prev`, relabelled "Next tab", "Previous tab") cycle the window's tabs when no screen is up; Left and Right switch tabs only while the strip has focus | Tab is "Next unit" and the arrows pan the camera; the Study and the window never are open together as targets (the Study is a screen) |
| D10 | Armies in Details? | No. Armies are in the Army tab; the header carries a badge ("Enemy army here") | One place for army rows; the header still warns on every tab |
| D11 | The job line | The **work** under way (any discovered tile); siege, battle and occupation are header badges | "One job per settlement" (M3, M9.5) shows on every tab; a siege is not the tile's job |
| D12 | Raise hover card (audit U3) | In this build: a pure `RaiseCard.of(game, tag, kind)` and a hover card on each raise row | The audit placed it with the window; the row shows only the price today |
| D13 | Names | `TileWindow` (`shell/panels/tile_window.gd/.tscn`) replaces `HexPanel`; `Hud.tile_window()` replaces `Hud.hex_panel()` (every caller moved in the swap task, no alias); `HexPanelContract` keeps its name (the seam) | No deprecated alias left behind |
| D14 | The sandbox (no countries) | Case `sandbox`: Details and Build as today (every land tile may be built on); no Army, no Ships | The map sandbox keeps working; many old tests run there |
| D15 | Mockups | ASCII sketches here (section 6); the **art director's mockup** is a later task (plan TW0) and, with the owner's approval, gates the shell tasks, not the core ones | Issue 436: "design approved with mockups, then built" |
| D16 | Moves in the month (issue 432), arms (M9.5) | Not built here. The Army tab's row models carry optional fields `points_text` (432) and `arms_text` (M9.5), shown when present | Those builds fill a field; the window does not change |
| D17 | Task IDs | `TW0` to `TW15` | T, F, FG, K are taken |

---

## 3. The rules

Numbered statements. "P" names the planted fault the test must catch. The viewer `""` (sandbox, tests) sees everything.

### 3.1 TileView: the read model

- **R1** `TileView.of(game, viewer, hex) -> Dictionary` is a pure function of the game, the viewer and the hex: no nodes, no
  engine calls, no luck, no `Session`, no `Events` (lint and `check_scripts`). Cached in `game.view_cache` by
  `[&"tile", game.version, viewer, hex]`; `{}` off the map or with no game. P: a `TileView` that reads `Session.player_tag()`
  (the scan of R8).
- **R2** `case` is exactly one of `&"unexplored"`, `&"sea"`, `&"own"`, `&"foreign"`, `&"unowned"`, `&"sandbox"`, decided in
  this order: a game with countries and `not Knowledge.discovered(viewer, hex)` gives `unexplored` (sea too); a sea hex gives
  `sea`; a game with no countries gives `sandbox`; owner = viewer gives `own`; no owner gives `unowned`; else `foreign`.
  Owner means `Territory.owner_tag`; an occupied own tile is still `own`, with the "Occupied" badge (R9). P: an undiscovered
  sea hex that reads "Sea"; an occupied own tile read as foreign.
- **R3** `unexplored` carries only `{case, hex, sight, header: {title: "Unexplored", subtitle: "Hex x, y"}}`: no owner, no
  place, no ground, no badge, no job, no tab facts. P: a place name or a ground word in it.
- **R4** `sight` is `&"undiscovered"`, `&"light"` (discovered, not in sight) or `&"sight"` (`Knowledge.sees`); always
  `&"sight"` for the viewer `""` and on own land in sight. Every fact a fog rule covers reaches `TileView` through a function
  that takes the viewer (`Knowledge`, `PeopleView.at`, `SiegeView.at`, `ArmyView.visible`, `BattleView.sites`,
  `WorksView.at`, `HexCard.war_rows_for(game, hex, viewer)`), never through `game.player`. Case: viewer Venice on a game whose
  `game.player` is Genoa gives Venice's view. P: `war_rows` (the `game.player` form) called from `TileView`.
- **R5** **Fog by construction, the twin test.** For a viewer, two games that differ only in what the fog hides from it give
  equal `TileView`s on every hex. Hidden (fog spec 3.4): every fact of an undiscovered hex; foreign armies out of sight (moved,
  merged, men changed); battles the viewer did not witness; the orders, routes, standing orders and stances of foreign
  armies in sight; a siege's besieger and its men in light fog. P: an armies list not gated by `sees`; a work line on an
  undiscovered hex; a besieger named in light fog.
- **R6** **Light fog shows the land, exact**: owner, holder, piece and its stage, people (exact), gives, the work under way,
  fortress level and garrison (`garrison_known`), a siege's holder, meter and garrison with the word "Besieged". No army, no
  battle unless witnessed. No "about" anywhere (`test_fog_exact.gd` already scans; the new files join it). P: a banded number.
- **R7** **In sight** adds the armies on the hex (`ArmyView.visible`): tag, country name, army name, men exact; and names a
  besieger and its men. A foreign army has no id, no order, no stance, no standing order in the view. P: a foreign army id.
- **R8** **The door scan.** `core/views/tile_*.gd` and `raise_card.gd` never name `game.state.`, `Armies.`,
  `Occupation.garrison_of`, `Sight.`, `Session`, `Events` or `game.player`. They read the game only through the views and
  checks listed in R4 and the own-only calls of R12. `test_tile_door.gd` scans them (as `test_ai_door.gd` does). P: one
  planted line of each kind.

### 3.2 The header and the job line

- **R9** The header: `title` = the place name, else the ground word capitalised ("Farmland"); sea: "Coastal sea" when a coast
  is beside it, else "Open sea"; `subtitle` = "<piece word>, <ground word> · hex x, y" (land) or "<depth word> · hex x, y"
  (sea); `owner` = `{tag, name, relation}` with relation `yours`, `at_war`, `foreign`, `no_one`; `people` = `PeopleView.at`'s
  text. `badges` in this order, each `{text, tone}`: "Occupied by <holder>" (warn), "Besieged" or "Besieged by <besieger>"
  (bad; R6, R7), "Battle here, <season>" (bad; `BattleView.sites` of the viewer), "Enemy army here" (bad; an army in sight of
  a country at war with the viewer) or "Foreign army here" (plain). P: a battle badge for a battle the viewer did not witness.
- **R10** The job line: `WorksView.at(game, hex, viewer)` on a discovered land tile. Own: label, progress, ready season
  ("stopped for the winter" when halted) and `cancel: true` when `Session.check("cancel_work")` would be asked (the shell
  asks it); foreign or unowned: label and ready, no Cancel; own land with no work: "No work under way" (muted), so own land
  keeps a stable layout; otherwise no job line. P: a Cancel on another country's work.

### 3.3 Tabs and the registry

- **R11** **The registry.** A tab is a script in `shell/panels/tile_tabs/` whose name ends in `_tab.gd`, extending `TileTab`
  (`extends VBoxContainer`) with constants `ID` (StringName), `LABEL`, `ORDER` (int, unique), a `static func applies(view:
  Dictionary) -> bool` and `func fill(game: Game, viewer: StringName, hex: Vector2i, view: Dictionary) -> void`.
  `TileTabs.all()` lists the folder once, loads each script, checks the constants (a missing one or a duplicate `ORDER` is an
  error the test names) and sorts by `ORDER`. `TileTabs.for_view(view) -> Array[StringName]` gives the ids that apply.
  `TileTabs.with_folder(path)` lets a test add a folder. Adding a tab needs no edit to `tile_window.gd` or `tile_tabs.gd`.
  P: a hard-coded list (the fake tab of the fixture folder is missing); two tabs with one `ORDER`.
- **R12** **Which tabs apply** (in `ORDER`):

| Tab | `ID` | `ORDER` | Applies when (fields of `TileView`) |
|---|---|---|---|
| Details | `details` | 10 | every case except `unexplored` |
| Build | `build` | 20 | `build.offered`: own land where `Territory.at_home_check` is ok, or `sandbox` land |
| Industries | `industries` | 30 | reserved for M9.5 (own settlement); no file in this build |
| Army | `army` | 40 | `army.raise_offered` (`Military.raise_offered`: own settlement, countries) or `army.armies` not empty |
| Ships | `ships` | 50 | `own_port` (`case == own` and `Improve.is_port`) |

  The own-only reads (`ImprovePreview.options_of`, `Military.raise_options`, `men_at_hand`, `raise_cap`, `raised_here`) are
  called by the Build and Army tabs only when their tab applies, so they never run for a foreign tile. P: the Army tab on a
  foreign tile with no army in sight; the Ships tab on an inland own town.
- **R13** The strip is **hidden when only Details applies** (foreign without armies in sight, unowned, sea); a tab that does
  not apply is **absent**, never greyed; the order never changes. Details ends with "Why not" lines for the absent tabs that
  a player could expect on land: Build's reason from `at_home_check` ("not your land: the Duchy of Milan holds it") and, on
  own land that is not a settlement, "Raising needs a village or larger". None at sea, none on unexplored. P: a greyed tab.
- **R14** **Which tab opens** (D7): on `show_hex`, the last tab the player picked if it applies, else Build if it applies,
  else Details. On a refresh where the open tab stops applying (the last army left, the town was taken), the same fall-back
  runs, with no toast. P: a tab left open that no longer applies.
- **R15** **Lazy tabs.** Only the open tab builds its controls; a switch builds the new one and frees the old one's (through
  `PanelKit`'s retire list); a refresh rebuilds the header, the job line and the open tab only. Signals arrive in bursts: one
  refresh at the end of the frame, as the hex panel does today.

### 3.4 The tabs

- **R16** **Details**, top to bottom: Piece rows, Ground rows (`HexCard`), People (yours: people, change, room and outlook;
  others: the exact number), Gives, Worth (yours, as a `DeltaChip`), the War block (`HexWar.fill`: held by, fortress and its
  garrison, castle area, the siege block), the battle row "Battle of X, Spring 1481 [Open the battle]" when a site of the
  viewer stands here, the buttons "Show supply" (a game with countries, own or foreign land) and "Show the castle area" (as
  the menu offers it today), then the Why not lines. Sea: depth, relief, winter, coasts, crossings. Unexplored: nothing (no
  tab). The owner's name in the header is a link to its country (today's `country_requested`).
- **R17** **Build** is today's works rows **moved unchanged** (`BuildRows`, extracted in TW2): the same labels, cost lines,
  chips, (i) buttons, reasons, `game/confirm_works` rule, `U` hotkey on the first Upgrade row and `works_requested` names
  (`works_card`, `begin_work`, `cancel_work`). A work under way hides the rows, as today; Cancel sits on the job line (R10).
- **R18** **Army**: when `raise_offered`, the head line and the raise rows of today's `RaiseList` (moved, unchanged words),
  each row with a hover card from `RaiseCard.of(game, tag, kind)`: men, move points, upkeep a season, the cost lines, and
  the kind's one-line role from its `UnitDef`. Then "Armies here": own armies (name, men, a "Select" button that selects the
  army, as the menu's item does), then foreign armies in sight (country, army name, men exact, no button). Optional row
  fields `points_text` and `arms_text` (D16) are shown when present. P: a Select button on a foreign army.
- **R19** **Ships** shows one line, "No ships yet. Ships will be built and refitted at this port." (Hint), and nothing else:
  no button, no list.
- **R20** Tabs change the game only through `Session.act` (raise, select is a shell act) or the window's existing requests;
  they never assign to game objects (lint's `core/` rules do not reach the shell, so `test_tile_tabs.gd` scans the folder for
  `game.state.` and `.tag =` style writes). P: a planted write.

### 3.5 Opening, the menu, the keys

- **R21** **Opening.** A left click on a hex selects it and opens the window (as today). A right click with an army of yours
  selected is an order (unchanged, M6 D43). A right click with no army selected on your own hex opens the **small menu**;
  elsewhere it clears the selection (unchanged). The menu's items, in groups:
  1. "Tile details..." (new): selects the hex, window on Details.
  2. The works rows (unchanged; a click goes through `BuildRows.begin`, the confirm rule included).
  3. "Raise companies here..." (own settlement): selects the hex, window on Army.
  4. "Select <army>" per army of yours (unchanged).
  5. The war items: "Open the Battle of X", "Show the siege of X", "Show the castle area" (unchanged).
  6. "Show supply (6)" (unchanged).
  P: a menu item whose action no longer reaches its target (each item clicked in `test_hex_menu.gd`).
- **R22** **Keys.** Ctrl+] and Ctrl+[ cycle the open window's tabs (wrapping) while no screen is up; while the Study is up
  they are the Study's. When the strip has focus, Left and Right switch tabs (the `Segmented`'s own handling). Inside the
  window, Tab and Shift+Tab move focus as Godot does; when focus is not in the window, Tab stays "Next unit". Esc closes the
  window through the ladder's step 4 (unchanged). O and Shift+F10 open the menu at the cursor (unchanged). U begins the
  first Upgrade row of the tile whatever tab is open (it asks `BuildRows`' model, not a visible button). Help lists the keys
  from the bindings table. P: Ctrl+] with the Study up changes the window's tab; Tab with focus on the map changes a tab.

### 3.6 Layout and style

- **R23** The window sits in the dock (right column, under the top bar), width `Tokens.PANEL_W`. Header, job line and strip
  are fixed; the body scrolls; the window is never taller than the viewport below its top minus `Tokens.S2` (today's `_fit`).
  At 1280 x 720 scale 1 and at 2560 x 1440 scale 2 (the same logical layout): the window lies inside the viewport, and the
  strip's minimum width with **five** labels (the four real tabs and the fake fifth "Industry" of the fixture) is at most
  the panel's content width, in both `theme.tres` and `theme_high_contrast.tres`. P: a label long enough to overflow.
- **R24** Studiolo style, tokens only: `Cartouche` for the title, `SectionHead`, `Hint`, `TableRow`, `Reason`,
  `NumberGood`/`Bad`/`Warn` variations, `KitButton` kinds, `DeltaChip`, `Segmented` for the strip, `PanelKit` helpers. No
  `Color(` literal, no `theme_override_` in `.tscn` (lint). Badges are `TableRow` labels in their tone's variation inside a
  `PanelSlot`; no new widget unless the art director's mockup asks, then it goes into `shell/ui/` with its own test.

### 3.7 Saves, determinism, performance

- **R25** No save change: `SaveFile.FORMAT` unchanged; nothing of the window is saved (the tab memory lives in the node).
  `Game.digest()` unchanged; `test_replay.gd`, `test_save_file.gd`, the soak and the AI tests do not move.
- **R26** Refactors ride alone: TW1 and TW2 change no behaviour (tests unchanged and green; the scenes of `shot_ui.gd` that
  show the hex panel are pixel-identical before and after TW2).
- **R27** The window's refresh reads `TileView` (cached per version); opening, switching and refreshing stay inside the rows
  of section 8.

### 3.8 The cases (what each shows)

| Case | Header | Job line | Tabs |
|---|---|---|---|
| Own settlement (port) | name, piece, ground; "yours"; people | work or "No work under way" | Details, Build, Army, Ships |
| Own settlement (inland) | as above | as above | Details, Build, Army |
| Own district or wild land | ground or place; "yours" | work or "No work under way" | Details, Build; Army only with armies seen |
| Own land occupied by an enemy | + "Occupied by X" | the work, if any | Details (+ Build if `at_home_check` allows) + Army if armies seen |
| Foreign, light fog | owner (link), people exact | the work, no Cancel | Details only (strip hidden) |
| Foreign, in sight, no army | as light fog | as light fog | Details only |
| Foreign, in sight, enemy army | + "Enemy army here" | as light fog | Details, Army (read-only rows) |
| A siege | + "Besieged" (light fog) or "Besieged by X" (sight, exact) | as the case | as the case; the War block shows the meter |
| A battle site the viewer saw | + "Battle here, Spring 1481" | as the case | as the case; Details has "Open the battle" |
| Unowned land | "no one" | the work, if any | Details only |
| Sea | "Open sea" / "Coastal sea" | none | Details only |
| Deep fog | "Unexplored", "Hex x, y" | none | none |
| Sandbox | as own, no owner line | work or none | Details, Build |

---

## 4. Interfaces

```gdscript
# core/views/tile_view.gd (new)
class_name TileView extends RefCounted
static func of(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary
# {case, hex, sight, header: {title, subtitle, owner: {tag, name, relation}, people, badges: Array[{text, tone}]},
#  job: {} | {label, progress, ready, halted, tag, cancel: bool},
#  details: {piece_rows, ground_rows, people: Dictionary, gives, worth: int | null, war: bool, battle: {} | {record, name},
#            supply: bool, castle_area: bool, sea_rows},
#  build: {offered: bool, reason}, army: {raise_offered: bool, reason, armies: Array[{own, id (own only), tag, country,
#  name, men, points_text, arms_text}]}, own_port: bool, why_not: Array[String]}

# core/views/raise_card.gd (new)
static func of(game: Game, tag: StringName, kind: int) -> Dictionary   # {title, lines: Array[[label, tone, text]]}

# core/systems/improve.gd (edit), core/systems/military.gd (edit), core/views/hex_card.gd (edit)
static func is_port(game: Game, hex: Vector2i) -> bool                 # moved from AiKnow; AiKnow.is_port calls it
static func raise_offered(game: Game, tag: StringName, hex: Vector2i) -> bool   # moved from RaiseList.offered
static func war_rows_for(game: Game, hex: Vector2i, viewer: StringName) -> Array   # war_rows(game, hex) calls it with game.player

# shell/panels/tile_tabs/tile_tab.gd (new): the base of every tab
class_name TileTab extends VBoxContainer
signal request(what: StringName, args: Dictionary)   # works_card, begin_work, cancel_work, select_army, show_country,
                                                     # open_battle, castle_area, map_mode, toast
func fill(game: Game, viewer: StringName, hex: Vector2i, view: Dictionary) -> void

# shell/panels/tile_tabs/tile_tabs.gd (new)
class_name TileTabs extends RefCounted
static func all() -> Array[Script]
static func for_view(view: Dictionary) -> Array[StringName]
static func with_folder(path: String) -> void        # tests only; reset() restores the default

# shell/panels/tile_window.gd (new) extends HexPanelContract
signal country_requested(tag: StringName)
signal works_requested(what: StringName, args: Dictionary)
signal row_hovered(hex: Vector2i, option: Dictionary)
signal row_unhovered
signal toast_requested(text: String, tone: StringName)
func show_hex(hex: Vector2i) -> void
func show_tab(id: StringName) -> void                 # the menu's "Tile details..." and "Raise companies here..."
func tab_open() -> StringName
func tab_ids() -> Array[StringName]
func next_tab(step: int) -> void                      # Ctrl+] (1), Ctrl+[ (-1)
func begin_option(option: Dictionary, expensive: bool) -> void   # the menu's works rows
```

The panel signals keep their names, so `Hud` and `WarRequests` re-connect to the window as they did to the panel.

---

## 5. Fog: what each fact reads

| Fact in the window | Read through | Undiscovered | Light fog | In sight |
|---|---|---|---|---|
| Title, ground, place, piece | gate R2, then `HexCard` map rows | "Unexplored" only | shown | shown |
| Owner, holder, "Occupied" | `Territory.owner_tag` after the gate; `HexCard.war_rows_for` | hidden | shown | shown |
| People | `PeopleView.at(viewer)` | hidden | exact | exact |
| Gives, work under way | `HexCard.gives_text`, `WorksView.at(viewer)` after the gate | hidden | shown | shown |
| Fortress, garrison | `Knowledge.garrison_known` (via `war_rows_for`) | hidden | exact | exact |
| Siege | `SiegeView.at(viewer)` | hidden | "Besieged", meter, garrison | besieger named, men exact |
| Battle badge and row | `BattleView.sites(viewer)` | hidden | only if witnessed | as witnessed |
| Armies, men | `ArmyView.visible(viewer)` | hidden | hidden | exact, no orders |
| Worth, raise rows, works rows | own-only calls (R12) | n/a | n/a | own tile only |

---

## 6. Sketches (ASCII; the art director's mockup comes later, plan TW0)

```
OWN TOWN (port)                          OWN TOWN, Army tab
+--------------------------------+       +--------------------------------+
| (seal) Genoa                [x]|       | (seal) Genoa                [x]|
|  walled town, farmland . 4, 10 |       |  walled town, farmland . 4, 10 |
|  [Genoa] yours . People 30,300 |       |  [Genoa] yours . People 30,300 |
+--------------------------------+       +--------------------------------+
| Job: walled town to city,      |       | Job: No work under way         |
|      2 of 8, ready Spring 1483 |       +--------------------------------+
|      [Cancel the work]         |       | Details |Build| Army |Ships    |
+--------------------------------+       +--------------------------------+
|[Details]|Build| Army |Ships    |       | Men at hand 6,300 . 1 of 2     |
+--------------------------------+       | [fig] Pikemen  500 men . 12 mp |
| Piece    walled town           |       |       [Raise  25 . 1 iron]     |
| Ground   farmland, lowland     |       | [fig] Knights  250 men . 16 mp |
| People   30,300 (up 300)       |       |       [Raise  45 ...] refused  |
| Room     45,000   Outlook ...  |       |       Not enough horses: 1 of 3|
| Gives    grain 8, cloth 2      |       | Armies here                    |
| Worth    [+14]                 |       |  Army of Genoa  1,000 [Select] |
| War      fortress 2, garrison  |       +--------------------------------+
|          800 of 800            |
| [Show supply]                  |
+--------------------------------+

FOREIGN, LIGHT FOG                        FOREIGN, IN SIGHT, ENEMY ARMY, BESIEGED
+--------------------------------+       +--------------------------------+
| (seal) Milan                [x]|       | (seal) Pavia                [x]|
|  city, farmland . 7, 9         |       |  walled town, farmland . 7, 10 |
|  [Milan] foreign . People 41,2 |       |  [Milan] at war . People 12,100|
+--------------------------------+       |  ! Besieged by Savoy           |
| Job: vineyard, ready Autumn 81 |       |  ! Enemy army here             |
+--------------------------------+       +--------------------------------+
| (no strip: Details only)       |       | Details | Army                 |
| Piece   city                   |       +--------------------------------+
| People  41,200                 |       | War   fortress 3, garrison 600 |
| Gives   grain 9, wine 3        |       | Siege [#####-----] 5 of 9      |
| War     fortress 3, garrison   |       |  Pavia is besieged by Savoy.   |
|         1,200 of 1,200         |       | ---- Army tab ----             |
| [Show supply]                  |       |  Milan: Army of Pavia  1,500   |
| Why not: not your land: the    |       |  Savoy: Army of Turin  2,000   |
| Duchy of Milan holds it        |       |    (yours)            [Select] |
+--------------------------------+       +--------------------------------+

BATTLE SITE (own land)                    SEA                    DEEP FOG
+--------------------------------+       +------------------+   +------------------+
| (seal) Alessandria          [x]|       | Coastal sea   [x]|   | Unexplored    [x]|
|  town, farmland . 6, 10        |       |  shelf . 3, 12   |   |  Hex 31, 4       |
|  [Savoy] yours . People 9,400  |       +------------------+   +------------------+
|  ! Battle here, Spring 1481    |       | Depth  shelf     |   (nothing else)
+--------------------------------+       | Coasts NE, E     |
| Job: No work under way         |       | Winter mild      |
| [Details]|Build| Army          |       +------------------+
| Battle of Alessandria, 1481    |
|   [Open the battle]            |
+--------------------------------+
```

---

## 7. Tests

All under `godot/tests/`. Every edited test keeps its planted faults; a task may not delete a P without replacing it.

### 7.1 New tests

| Test | Cases | Planted faults |
|---|---|---|
| `core/test_tile_view.gd` | each row of 3.8 on north Italy (Genoa, Savoy, Milan) and the sandbox; header words and badge order; job line own and foreign; `why_not` lines; `own_port` on Genoa and not on Asti | R2, R3, R9, R10, R12's facts, R13's lines |
| `core/test_tile_fog.gd` | on `FogFixture.thin` and `duel_thin`: every case at each sight level; the twin test of R5 (copy B moves unseen Venetian armies, changes owners, pieces, works and garrisons of undiscovered hexes, re-orders seen armies) compares `TileView` on every hex; viewer is not `game.player` (R4) | R4, R5, R6, R7 (one P each) |
| `core/test_tile_door.gd` | the scan of R8 over `tile_*.gd` and `raise_card.gd` | one P per forbidden name |
| `core/test_raise_card.gd` | each kind's lines; a refused kind keeps its card | a card without the cost lines |
| `shell/test_tile_tabs.gd` | `all()` order; `for_view` per case of 3.8; the fake fifth tab from `tests/shell/fixtures/tile_tabs/` found by `with_folder`; the write scan of R20 | a hard-coded list; a duplicate `ORDER`; a planted write |
| `shell/test_tile_window.gd` | frame per case; strip hidden with one tab; R14's choice and fall-back; lazy build (R15: only the open tab has children); one refresh per burst; Ctrl+] / Ctrl+[ and the Study (R22); Esc; R23 at both sizes and both themes | R13 greyed tab; R14 stale tab; R22 key leak; R23 overflow |
| `shell/test_build_tab.gd` | the works cases of today's `test_hex_panel.gd` moved (rows, chips, (i), confirm modes, reasons, Cancel on the job line, U) | today's, kept |
| `shell/test_army_tab.gd` | today's `test_raise_list.gd` cases moved; "Armies here" own and foreign; the raise hover card | R18's Select on a foreign army |
| `shell/test_details_tab.gd` | today's `test_hex_panel_people.gd`, the details half of `test_hex_panel.gd`, `test_hex_panel_fog.gd` moved; the battle row and its button; the Why not lines | today's |
| `shell/test_ships_tab.gd` | the one line on Genoa; absent on Asti | Ships on an inland town |

### 7.2 Tests that move or change

| Test | Change | Task |
|---|---|---|
| `shell/test_hex_panel.gd`, `test_hex_panel_people.gd`, `test_hex_panel_fog.gd` | deleted after their cases live in the new files (checklist 7.3) | TW12 |
| `shell/test_raise_list.gd` | becomes `test_army_tab.gd` | TW9 (copy), TW12 (delete) |
| `shell/test_hex_menu.gd` | the new item, the Raise item opens the Army tab, each item clicked reaches its target | TW12 |
| `shell/test_hex_war.gd` | unchanged (`HexWar` is reused by Details) | none |
| `shell/test_works_preview.gd` | "left of the hex panel" becomes "left of the tile window"; the focused-row case loads the Build tab | TW12 |
| `shell/test_hud.gd`, `test_app.gd`, `test_app_flow.gd`, `test_app_flow_m6.gd`, `test_app_flow_m7.gd`, `test_army_toasts.gd` | `hex_panel()` becomes `tile_window()`; `show_raise()` becomes `show_tab(&"army")`; `raise_list()` from the Army tab | TW12 |
| `core/test_ai_know.gd`, `core/test_military.gd` | `is_port` and `raise_offered` through their new homes (same answers) | TW1 |
| `shell/monkey_m6.gd`, `monkey_m7.gd` | the Raise step through the window's Army tab; the hex menu step keeps its counters | TW12 |
| `tools/ui/shot_ui.gd`, `shot_ui_m6.gd`, `shot_ui_fog.gd`, `perf_ui.gd`, `perf_ui_m7.gd` | call `tile_window()`; the scenes keep their names | TW12 |

**Unchanged, must stay green:** every `core/` rule and AI test, `test_replay*.gd`, `test_save_file.gd`, `test_snapshot.gd`,
`test_fog_views.gd`, `test_fog_exact.gd` (it scans the new files too), the soak.

### 7.3 The fold-in checklist (TW12's pull request carries it)

Every test function of `test_hex_panel.gd` (26), `test_hex_panel_people.gd` (12), `test_hex_panel_fog.gd` (2),
`test_raise_list.gd` (12) and `test_hex_menu.gd` (13) is listed with the new test that covers it, or the reason it is gone
(for example "the Works and Raise segment: replaced by the strip, covered by `test_tile_window.gd`"). Every item of today's
hex menu and every row of today's panel is listed with its new place. The code reviewer checks the list against the files.

### 7.4 Monkey and pictures

**Monkey** (`tests/shell/monkey_tile.gd`, extends `MonkeyFog`; `test_ui_monkey.gd` extends it): a step that clicks random
hexes on screen (own, foreign, sea, and on a thin seed undiscovered), switches tabs by click and by Ctrl+] / Ctrl+[, opens the
menu and picks "Tile details..." or "Raise companies here...", and raises when a row allows it. Invariants every frame the
step runs: the open tab is in `TileTabs.for_view(TileView.of(...))`; the strip shows exactly those tabs; an undiscovered hex
shows only "Unexplored"; no army row for an army `ArmyView.visible` refuses; the window's rect lies in the viewport. Counters
`tile_opens`, `tile_tab_switches`, `tile_cases` (at least three cases a seed) must rise above 0.

**Pictures** (`tools/ui/shot_ui_tile.gd`, new; 1280 x 720 scale 1 and 2560 x 1440 scale 2): each sketch of section 6 on
north Italy (own port, own inland town on Army, foreign light fog, foreign in sight with an enemy army and a siege, a battle
site, sea, deep fog on the thin fixture), the menu with its new item, and the fake five-tab strip. The scenes of
`shot_ui.gd` (`m4_hex_panel_rows`), `shot_ui_m6.gd` (the Raise tab) and `shot_ui_fog.gd` that showed the panel are made
again. **Pictures need a window: the owner is asked before any windowed run.** The art director signs them.

---

## 8. Performance

TW1 measures the existing rows before anything moves; TW14 adds the new rows and measures all of them after; both tables in its pull request.

| Row | Class | Limit | Expected | Note |
|---|---|---|---|---|
| **new** `tile_view_ms` (`perf_core`) | cpu | 1.0 mean, 4.0 worst | about 0.3 mean | `TileView.of` on every land hex of north Italy for Genoa, view cache cleared |
| **new** `tile_window_open_ms` (`perf_ui`) | gpu | 16 | under 10 | own city with two armies selected cold (view cache cleared), the call and one forced draw, worst of 3 |
| **new** `tile_tab_switch_ms` (`perf_ui`) | gpu | 16 | under 8 | Details, Build, Army, Ships on Genoa, the call and one forced draw, worst |
| `hud_frame_worst_ms` | gpu | 16 | unchanged | "HUD + tile window open at 1920 x 1080" |
| `hex_menu_war_ms` | cpu | 6 | unchanged | the menu gains one item |
| `works_card_push_ms`, `army_panel_open_ms` | gpu | 16 | unchanged | |

If `tile_window_open_ms` passes its limit: the open tab is filled on the next frame after the header (a two-step build),
then `Worth` (the one heavy read, `EconomyPreview.worth_of`) moves to the Build tab.

---

## 9. Risks

- **The swap is wide.** TW12 touches the HUD, the menu, the app wiring and eleven test files at once. Mitigation: the tabs
  are built and tested beside the old panel first (group C), so the swap moves wiring only; the checklist of 7.3.
- **Folder listing in an export.** If `ResourceLoader.list_directory` misses scripts in the Windows build, tabs vanish in the
  release only. Mitigation: TW3's probe on an exported build before anything uses it; the generator fallback (D4).
- **Five tabs at 296 px.** Proved by R23 now, not at M9.5; the icon fallback is one file.
- **Key clashes.** Ctrl+[ and Ctrl+] are shared with the Study; R22's test pins that they never act on both.
- **Fog drift.** A later tab that reads the game straight would leak; the door scan (R8) covers core files only, so a tab's
  model must live in `core/views/tile_*.gd` (M9.5's `tile_industries.gd` joins the scan by its name).
- **Mockup delay.** The art director's mockup and the owner's approval gate group C; core groups A and B run meanwhile.
- **Later builds.** Issue 432 (points left) and M9.5 (arms, industries) fill fields and add a file; neither edits the frame.

---

## Appendix A. Amendments to earlier specs

| Spec | Section | Amendment |
|---|---|---|
| ui-family-audit.md | 3.1 to 3.5 | The menu stays (R21); Ships on own ports (D5); the keys of R22 replace 3.5's ("R opens the Army tab" is wrong: R is Continue march) |
| m6-build-spec.md | 6.1, 6.8 (hex menu, Raise tab) | The Raise tab is the window's Army tab; the menu's Raise item opens it |
| m7-build-spec.md | 6.8 (war items in the panel and the menu) | The war block and the battle row live in Details; the menu keeps its war items |
| ui-and-controls-spec.md | the bindings table | `study_tab_prev`/`next` are "Previous tab"/"Next tab" for the Study and the tile window |
| economy-rethink.md | 3.1, 7 | The Industries tab is `industries_tab.gd`, `ORDER` 30, its model `core/views/tile_industries.gd` |
