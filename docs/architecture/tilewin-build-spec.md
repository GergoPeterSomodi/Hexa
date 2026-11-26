# Tile window build spec: one uniform window per tile (issue 436)

Technical director, 2026-11-25. **Status: built 2026-11-25 except TW19 (pictures signed, goldens, README and docs). The rules
below describe the window as built; section 10 lists where the build left the first design and marks every rule built, not
built or deferred. Design review round 3 (TW23, in progress) is building the owner's decisions of 2026-11-25, D21 to D26, and the designer's findings H1 to H5, M1 to M9 and L1 to L7: where a rule says "from TW23" it describes the target and 10.4 says what the code does until then.** The design was approved by the owner after the mockups of Appendix B, then changed in three polish rounds
after his playtest (one fixed size, Land and Buildings merged into one Town tab, the mockup v4 look). Builds section 3 of
`docs/design/ui-family-audit.md` ("the audit") as the owner answered it (2026-11-24), on top of the fog build
(`fog-build-spec.md`, on master) and ready for the economy rethink (`docs/design/economy-rethink.md`, M9.5). Where the audit
or the mockups say something else, this page wins for the build. The tasks are in `tilewin-build-plan.md`.

**What it is, in one paragraph.** Every tile has one window, in the dock on the right where the hex panel was, in the kit's gold
frame, **440 x 640** logical pixels on every tile and every tab (`Tokens.TILE_WINDOW_W` and `TILE_WINDOW_H`; it shrinks only on
a viewport too short for it). Its **header** has the name centred and a round close button at the
right (the size stars are gone from TW23: a settlement-type emblem sits on the picture, D22); a teal sub line (the ground and hex, the owner's link, the food); a row of **round-icon chips** (people, food, works
or slots, and this tile's income a year in ducats (D21); foreign land: people, garrison, buildings, armies); and a 150 px **picture**
on every tile (the settlement, the bare land or the sea) scaled to the window's width so the whole town shows (D25), with the
emblem and round badge icons, or the word "Unexplored" on deep fog. Under it flat **tabs** with a
gold underline: **Town**, **Army**, and **Ships** (your own ports only, empty until ships exist, in the game's own words, D23); a tab that does not apply is
dimmed, keeps its reason as a tooltip and has it written under the facts of the Town tab. The **Town tab** holds, top to
bottom, the siege block when the tile is besieged, the **building strips** (one wooden strip per group: a two-line plaque and 40 px icon
tiles, D24) on land you may build on, and the **land facts** ledger in collapsible sections (D26). The **Army tab** holds icon cards (armies here, a company to
raise); a **Raise companies** window with tall rows opens from its "Show all". The **queue** (the work under way, its seasons, a
red Cancel) is one row pinned at the foot of the window on every tab. Every icon and number has a tooltip or a hover card
(R37). Industries are plain buildings in the strips (no Industry tab). The small right-click menu stays. Every fact comes from
pure read models in `core/views/` (`TileView`, `TileBuildings`, `TileArmy`, `BuildingCard`, `CompanyCard`), which apply the fog
and nothing else, so the tests run headless and the fog is proved in one place.

**The tile window build is done when:**

1. Every rule R1 to R40 holds, each with its GUT case and its planted fault (P) of section 7.
2. `HexPanel`, its Works and Raise segment and its separate sea and unexplored paths are gone; the window replaces them
   behind the same seam (`HexPanelContract`); every case of the old tests has a twin in the new ones (checklist 7.3).
3. The right-click menu offers the items of R31; whatever it offered before has a place (the checklist lists each).
4. A fake tab placed in a test folder shows in the strip with no edit to the window or the registry (R11).
5. `SaveFile.FORMAT`, `Game.digest()` and every core rule are unchanged; the soak and the AI tests do not move.
6. The perf rows of section 8 are within their limits.
7. Lint, import, check_scripts, GUT, both UI `--check`s, `build_tile_tabs.gd --check` green; the pictures of 7.4 signed by
   the art director; the owner has played the plan's checklist.

---

## 1. What is there (master after the fog build, plus group A; the state before the build, section 10 says what was built)

| Finding | Where | Meaning for the build |
|---|---|---|
| The hex panel is one 520-line script after TW2 (cartouche, piece, ground, owner, war block, people, gives, worth, Works or Raise segment) | `shell/panels/hex_panel.gd` | Replaced in the swap (TW16) |
| **Built (TW1):** `Improve.is_port`, `Military.raise_offered`, `HexCard.war_rows_for(game, viewer, hex)` | `core/systems/`, `core/views/hex_card.gd` | Views may read them |
| **Built (TW2):** `BuildRows` (works rows, confirm rule, `begin_option`, request names) and `JobLine` | `shell/panels/tile_tabs/` | `JobLine` is reused as is; `BuildRows` keeps its click logic, its drawing is replaced by the compact rows (R19) |
| **Built (TW3):** `TileTab`, `TileTabs` (`all`, `for_view`, `with_folder`, `reset`, `check`), the generated index `tile_tabs_index.gd` and `tools/build_tile_tabs.gd --check`; the fake tab fixture | `shell/panels/tile_tabs/`, `tests/shell/fixtures/tile_tabs/` | The export probe could not run (no export templates), so the index fallback of D4 is in use; it works in an export by construction |
| `ImprovePreview.options_of` (light rows) and `ImprovePreview.of` (the works card: verdict, `blocked_by`, cost, seasons, payback, year gain, brings) | `core/views/improve_preview.gd` | The Buildings rows and the building card read these; nothing new in the rules |
| `Military.raise_options`, `raise_check`, `cost_of`, `men_at_hand`, `raise_cap`, `raised_here`; `UnitDef.era` (1 to 3), `attack`, `defence`, `upkeep` | `core/systems/military.gd`, `core/defs/unit_def.gd` | The Army rows, `can_raise` and the company card read these |
| `HexCard.food_text_of` and `gives_text` read `game.player` | `core/views/hex_card.gd` | `TileView` calls `MapModes.food_year(game, viewer, hex)` and the district output itself with the viewer (R4) |
| Settlement levels: hamlet, village, town, walled town, city; castles: watchtower, castle, fortress; harbour: jetty, quay, port | `core/defs/family_ids.gd` | The seven picture kinds (R28) |
| No settlement slots, no arms, no year or tech gates exist yet (M9.5, M11) | `core/` | The models carry the fields now and leave them empty (D16) |
| Tab is "Next unit"; arrows pan; Ctrl+[ / Ctrl+] are the Study's tab keys | `shell/input/bindings.gd` | The window's keys (R32) |

---

## 2. Decisions taken

| # | Question | Decision | Why |
|---|---|---|---|
| D1 | Window or screen? | The **dock panel** (right column), not a modal | The map stays live; the Esc ladder and the dock swap already work |
| D2 | Size | `Tokens.TILE_WINDOW_W` x `Tokens.TILE_WINDOW_H` (440 x 640 logical), the same for every tile and tab | Room for the icon strips and the chips; one size so the window never jumps when another tile or tab is picked (R33). The first draft was `Tokens.PANEL_W` (296) and a height that followed the content |
| D3 | Where "which tab, live or dimmed" is decided | `TileView` gives facts and reasons; each tab's static `applies(view)` and `dimmed(view)` read only that dictionary | Core cannot know the shell's tabs; the choice stays testable headless |
| D4 | How a later milestone adds a tab | One `*_tab.gd` file in `shell/panels/tile_tabs/` plus `build_tile_tabs.gd` (the index; CI `--check`). Built in TW3 | "Add a file" kept; the index is safe in exports |
| D5 | Ships tab | Own port settlements only (`Improve.is_port`), one empty line, with in-game wording from TW23 (D23); never dimmed elsewhere; the owner kept the tab on 2026-11-25 | Owner's answer; a dead tab on most of the map otherwise |
| D6 | Industries | **No Industry tab.** Industries are buildings in the Town tab's strips (M9.5 adds a Workshops strip, not a tab) | Owner, 2026-11-25; economy-rethink: industries are buildings in slots |
| D7 | Which tab opens | The last tab picked if it is live on the new tile; else the Town tab (the retired ids Buildings and Land stay as fall-backs for a window given stub tabs). Not saved | A player on Army stays on Army; the Town tab is the common act |
| D8 | Tabs that do not apply on land | On any discovered land tile the strip shows **Town and Army**; a tab that does not apply is **dimmed** (not clickable, its reason as tooltip, and written under the facts on the Town tab). Ships is shown only on own ports. Sea: Town only, the tab strip hidden. Unexplored: no tabs, a fog note. The sandbox: Town only | A stable strip reads better than tabs that come and go; the first draft's tabs Land and Buildings are the Town tab since the owner's decision of 2026-11-25 (the audit's Infrastructure idea) |
| D9 | Tab keys | Ctrl+] / Ctrl+[ ("Next tab", "Previous tab") cycle the **live** tabs when no screen is up; Left/Right only while the strip has focus | Tab is Next unit; arrows pan; the Study is a screen |
| D10 | The number chips | Four chips chosen by the case (R10), **the same on every tab**, each a round icon and a centred number | Stable layout; the Army tab's men and arms sit in its own head line and banner |
| D11 | The job line | The work under way, as one **queue row pinned at the foot of the window** on every tab; siege, battle and occupation are badges on the picture, and a siege has its own block at the top of the Town tab | One job per settlement shows on every tab; the siege is a state of the tile, not of its army |
| D12 | Hover cards | `BuildingCard.of` and `CompanyCard.of` in `core/views/`, fed by `ImprovePreview.of` and `Military`; the shell shows them in `HoverCard`. `RaiseCard` of the earlier draft is renamed `CompanyCard` and takes the hex | One card model per row kind, testable headless |
| D13 | Raise companies window | The **Army tab holds the compact rows**; "Show all" opens `RaiseScreen`, a non-opaque screen on the `ScreenStack` (`ModalFrame`) with tall rows, search and filter, for long lists | Owner, 2026-11-25 |
| D14 | Buildings in v1 | **One wooden strip per group** (Settlement, Land, Harbour, Defence; M9.5 adds Workshops): a plaque (icon, name, "N built of M"; two lines from TW23) and 40 px icon tiles (48 px until TW23, D24) that wrap onto more rows; the words are in each tile's hover card. **No building levels with + / -, no workforce bars, no workers or capacity numbers on the plaque** (Appendix C) | Mockup v4 (after EU4 and EU5); the economy design has no levels or staffing yet |
| D15 | Settlement picture | Code-drawn in a `Control` (`SettlementPicture._draw`) from a pure recipe; no baked files (R28) | Cheapest honest way: no import, no atlas, sharp at scale 2, in the Kenney flat look; a bake can come later from the same recipe |
| D16 | Slots, arms, gates (M9.5, M11) | The row and card models carry `slots`, `arms`, `gate` fields now, empty until those builds fill them; before M9.5 the strip's third cell is the country's **Works** (crews in use of the limit) | The window does not change when M9.5 lands; M9.5 fills fields and adds rows |
| D17 | The right-click menu | Stays, own hexes only, with the approved items (R31); the inline works rows leave the menu for "Build here..." | The approved mockup; one click more for a build, the same confirm rule |
| D18 | Names | `TileWindow` replaces `HexPanel`; `Hud.tile_window()` replaces `Hud.hex_panel()` (no alias); `HexPanelContract` keeps its name | No deprecated alias |
| D19 | Sandbox (no countries) | The Town tab (strips and facts) as today; no Army, no Ships; chips: people and food | The map sandbox keeps working |
| D20 | Task IDs | `TW0` to `TW19`, then `TW20` to `TW22` for the polish rounds and `TW23` for design review round 3 | T, F, FG, K are taken |
| D21 | The ducats chip of the header (owner, 2026-11-25) | The own-tile chip "Ducats" shows **this tile's income a year**, not the viewer's treasury (the treasury is on the top bar). Default formula: what the buildings here make a year less their upkeep, plus the district's yearly worth at the viewer's tax; TW23 pins the one formula so that the chip, the Town tab's summary line and the hover card give the same numbers, and writes it in 10.4. Own land only: a foreign tile has no ducats chip. Tooltip: "Income of this tile a year" | A tile's chip should say what the tile brings; the treasury is not a fact of the tile |
| D22 | Settlement size on the picture (owner, 2026-11-25) | A **settlement-type emblem** sits on the picture (one small round emblem for each picture kind: hamlet, village, town, walled town, city, castle; its tooltip names the type). The **size stars are removed** from the title bar and `TileView.header.stars` goes; the emblem reads the picture's `kind` | The picture and the emblem say the size once; the stars said it a second time |
| D23 | The Ships tab (owner, 2026-11-25) | **Kept** (own ports only, empty until ships exist) with **in-game wording**: no development words such as "milestone" or "this tab is here". Default text "No ships here yet. Ships and shipyards will be built in your ports."; the creative director confirms the words in TW23 | The tab gives ports their place; the text must speak the game's language |
| D24 | Building tiles and the plaque (owner, 2026-11-25) | The tiles are **40 px** (were 48) and the plaque is **two lines** (the name over "N built of M") so a group with many buildings keeps its room; tiles still wrap onto more strip rows | Smaller tiles let more buildings show before the body scrolls |
| D25 | The picture's scale (owner, 2026-11-25) | The picture is **scaled to the window's width** so the whole town is visible: the scale is the Control's width over the recipe box's width, the sky and ground bands fill the Control's height, the town sits on the ground band, nothing is cropped at the sides. A layout fix, not art work (the owner's note of 2026-11-25 stands) | The code scaled by the height and cropped the middle |
| D26 | The facts ledger (owner, 2026-11-25) | Each small-caps head of the land facts is a **collapsible section** (a click or Enter on the head folds or opens it; open by default; the state is kept for the session by the window and never saved) | A long ledger hides the strips' neighbours; the player folds what he does not need |
| D27 | Design review round 3 | The designer's review of the window (findings **H1 to H5**, **M1 to M9** and **L1 to L7**) is fixed in one task, **TW23**, listed as the next polish task; **status: in progress**. TW23 builds D21 to D26 as well | One round, one pull request; each finding is fixed or answered in the pull request by its id |

---

## 3. The rules

"P" names the planted fault the test must catch. The viewer `""` (sandbox, tests) sees everything.

### 3.1 The read models

- **R1** `TileView.of(game, viewer, hex) -> Dictionary` is pure: no nodes, engine calls, luck, `Session`, `Events`. Cached in
  `game.view_cache` by `[&"tile", game.version, viewer, hex]`; `{}` off the map. It is **light**: no `EconomyPreview`, no
  `ImprovePreview`, no raise check. P: a `TileView` that reads `Session.player_tag()`.
- **R2** `case` is one of `unexplored`, `sea`, `own`, `foreign`, `unowned`, `sandbox`, decided in this order: countries and
  `not Knowledge.discovered(viewer, hex)` gives `unexplored` (sea too); sea gives `sea`; no countries gives `sandbox`; owner =
  viewer `own`; no owner `unowned`; else `foreign`. An occupied own tile is `own` with the "Occupied" badge. P: an
  undiscovered sea hex that reads "Sea"; an occupied own tile read as foreign.
- **R3** `unexplored` carries only `{case, hex, sight, header: {title: "Unexplored", subtitle: "Hex x, y"}}`: no picture, no
  strip, no owner, no ground, no badge, no job, no tab facts. P: a place name, a ground word or a picture in it.
- **R4** `sight` is `undiscovered`, `light` or `sight` (`Knowledge.sees`); always `sight` for `""` and on own land in sight.
  Every fogged fact reaches the models through a function that takes the viewer (`Knowledge`, `PeopleView.at`,
  `SiegeView.at`, `ArmyView.visible`, `BattleView.sites`, `WorksView.at`, `HexCard.war_rows_for`, `MapModes.food_year`),
  never `game.player`. Case: viewer Venice in a game whose `game.player` is Genoa. P: `HexCard.war_rows` or `food_text_of`
  (the `game.player` forms) called from a model.
- **R5** **Fog by construction, the twin test.** Two games that differ only in what the fog hides from the viewer give equal
  `TileView`s on every hex (fog spec 3.4: every fact of an undiscovered hex; foreign armies out of sight; battles not
  witnessed; foreign orders, routes, stances; a besieger in light fog). P: an armies count not gated by `sees`; a picture or
  work line on an undiscovered hex; a besieger named in light fog.
- **R6** **Light fog shows the land, exact:** owner, holder, piece and stage, people, goods made (loads), the built pieces
  (and M9.5's slot buildings with their state), the work under way, fortress and garrison, a siege's holder, meter and
  garrison ("Besieged"). No army, no battle unless witnessed. No "about" (`test_fog_exact.gd` scans the new files). P: a
  banded number.
- **R7** **In sight** adds the armies (`ArmyView.visible`): tag, country, army name, men exact; and the besieger. A foreign
  army has no id, order, stance or standing order in any model. P: a foreign army id.
- **R8** **The door scan.** `core/views/tile_*.gd`, `building_card.gd` and `company_card.gd` never name `game.state.`,
  `Armies.`, `Occupation.garrison_of`, `Sight.`, `Session`, `Events` or `game.player`. `test_tile_door.gd` scans them. P: one
  planted line of each kind.
- **R9** **Own-only models.** `TileBuildings.of(game, tag, hex)` and `TileArmy.of(game, tag, hex)` return `{}` unless the hex
  is the tag's own (or the sandbox for `TileBuildings`); `TileArmy`'s "armies here" part reads `ArmyView.visible(tag)`. Tabs
  call them only when live. P: rows for a foreign tile.

### 3.2 Header, chips, queue

- **R10** **The chips** (`StripCells`) are drawn from `TileView.strip`: an array of `{key, value, label, tone}`, four cells or none:

| Case | Cells |
|---|---|
| own (any land) | People (`PeopleView.at`), Food (net a year from `MapModes.food_year(viewer)`, signed, tone), Works ("1 of 3", `WorksView.slots`; M9.5: a settlement shows Slots "3 of 4" instead), Ducats (this tile's income a year, D21; until TW23 the viewer's treasury) |
| foreign, unowned | People, Garrison ("400/400" from `war_rows_for`; "-" without a fortress), Buildings (count of built pieces and slot buildings), Armies (count in sight; "fog" out of sight) |
| sandbox | People, Food |
| sea, unexplored | none |

  P: the owner's treasury on a foreign tile, or (from TW23) in the ducats chip of an own one; Food read through `game.player`.
- **R11** **The header** (`TileView.header`): `title` (place name, else the ground word capitalised; sea "Coastal sea" or
  "Open sea"); `place` ("Walled town · Republic of Genoa", the owner's long name, a link); `subtitle` ("farmland · hex 4, 10";
  sea "<depth> · hex x, y"); `owner {tag, name, relation}` (`yours`, `at_war`, `foreign`, `no_one`); `stars` (settlement level
  1 to 5, else 0; removed in TW23, D22: the emblem reads the picture's `kind`); `picture` (R28; `{}` when none); `badges` in order, each `{text, tone}`: "Occupied by <holder>" (warn),
  "Besieged" / "Besieged by <besieger>" (bad; R6, R7), "Battle here, <season>" (bad; witnessed only), "Enemy army here" (bad)
  or "Foreign army here" (plain). **As drawn:** a title bar (until TW23 with the size stars at the left, drawn and five-pointed; from TW23 without them, D22) with the name
  centred in the display font (25) and the round close button at the right (R39); a teal sub line (the subtitle, the owner's
  place as a link, the food cell's value in its tone); the chips (R10, R40); the picture (R28); the badges as **round icons**
  at the picture's foot, each with its words as tooltip and a bad one rimmed in red. P: a battle badge the viewer did not
  witness.
  or "Foreign army here" (plain). P: a battle badge the viewer did not witness.
- **R12** **The job line** (`JobLine`, built; shown as the **queue**, one row pinned at the foot of the window on every tab: the
  work, its seasons, a small red Cancel at the right; its tooltip names the work and says one work at a time):
  `WorksView.at(game, hex, viewer)`. Own: label, progress, ready, halted, Cancel; foreign or unowned: label and ready, no
  Cancel; own land with no work: "No work under way" (muted); else none. P: a Cancel on another country's work.

### 3.3 Tabs and the registry

- **R13** **The registry** (built, TW3): a tab is a `*_tab.gd` in `shell/panels/tile_tabs/` extending `TileTab` with `ID`,
  `LABEL`, `ORDER`, `static func applies(view) -> bool` (shown in the strip) and `fill(...)`. TW9 adds `static func
  dimmed(view) -> String` to `TileTab` (default `""`: live) and `TileTabs.dimmed_for(view) -> Dictionary` (id to reason).
  `TileTabs.all()` reads the index plus test folders. P (kept): a hard-coded list; two tabs with one `ORDER`.
- **R14** **Which tabs show, and when they are live** (in `ORDER`; the registry holds three tabs and the test fixture's fake one,
  `ORDER` 50):

| Tab | `ID` | `ORDER` | Shown when | Dimmed (with this reason) when |
|---|---|---|---|---|
| Town | `town` | 10 | every case but `unexplored` (land, sea, sandbox) | never |
| Army | `army` | 30 | any land case but `sandbox` | not `raise_offered` and no armies in sight: "Raising needs a village or larger" (own) or "Out of sight: no armies are shown" / "No armies here" (other) |
| Ships | `ships` | 40 | `own_port` | never (absent elsewhere) |

  The first draft's tabs Land (10) and Buildings (20) are the Town tab: `land_facts.gd` and `building_strips.gd` are its parts
  (not `*_tab.gd`, so the registry does not list them). Building is not a tab that can be dimmed any more: on foreign and
  unowned land the Town tab shows the facts alone (no strips). On a foreign tile with armies in sight, Army is live and
  read-only (no raise rows). P: Army live on a foreign tile with no army in sight; Ships on an inland own town; a dimmed tab
  that opens by click or Ctrl+].
- **R15** The tab strip is hidden when only one tab shows (sea: Town alone, with the note "Nothing to build or raise at sea"); an
  undiscovered hex has no tabs and a fog note ("Never discovered"). Order never changes.
- **R16** **Which tab opens** (D7) on `show_hex`; on a refresh where the open tab turns dimmed or absent (the last army
  left, the town was taken), the same fall-back, no toast. P: a dimmed tab left open.
- **R17** **Lazy tabs.** Only the open tab builds its controls; a switch frees the old one's (`PanelKit` retire list); a
  refresh rebuilds header, chips, queue and the open tab; one refresh per burst at the end of the frame.

### 3.4 The tabs

- **R18** **The Town tab** (`town_tab.gd`; live on every case but unexplored), top to bottom: (1) the **siege block** when the
  tile is besieged (`SiegeView.at` for the viewer): "Under siege", "Besieged by <besieger> with <men>" where the fog allows it
  and just "Besieged" where it does not, a `SiegeMeter`, "N of M · season S", "Falls in N seasons if not relieved" where known, and
  a "Show siege" button (the map looks at the hex); the siege is **not** on the Army tab. (2) The **building strips** (R19), on
  land you may build on. (3) The **land facts** ledger (`land_facts.gd`), one line a fact (key, optional quiet note, value, a
  hairline) under small-caps heads, **each head a collapsible section** (from TW23, D26: a click or Enter on the head folds or opens it; open by default; the state is kept for the session and never saved): *People and food* (people with change and outlook for own, exact number for others; food
  made and eaten for own); *Made here a year* (one row per good: loads; own adds the value at price; from the district output
  over four calm seasons, the viewer's tax); *Buildings* (foreign and unowned only: built pieces and slot buildings with their
  state, "working" or "building 2 of 4"); *Ground and defence* (`HexCard.ground_rows`, the war rows: holder, fortress,
  garrison, castle area, the siege meter); the battle row "Battle of X, Spring 1481 [Open the battle]" when witnessed;
  *Armies*: "Out of sight: no armies are shown" on non-own land out of sight; then "Show supply" and "Show the castle area"
  buttons. Sea: depth, relief, winter, coasts, crossings. (4) Under the facts, the **reasons of the dimmed tabs**, once each
  ("Army is closed here" and its reason). The parts keep their own tests; the tab only stacks them and forwards their signals.
- **R19** **Building strips** (own land and the sandbox; none on foreign land, unowned land or the sea): a summary line
  "Buildings here make +N a year · upkeep -M" (from `TileBuildings`), then **one wooden strip per `TileBuildings` group**
  (Settlement, Land, Harbour, Defence; M9.5: Workshops). A strip has at its left a **plaque** (the group's icon, its name, "N
  built of M" of the tiles shown, a tooltip saying what the group is; from TW23 the plaque is **two lines**, the name over "N built of M", D24) and at its right the group's buildings as **40 px icon
  tiles** (48 px until TW23, D24) (`BuildingRow`), which wrap onto more strip rows when they do not fit; the body scrolls. A tile's look is its state:
  **built** = wood tile, gold rim, the level in roman numerals at the corner; **building** = green rim and a thin progress bar;
  **can build** = dark tile, green rim, the whole tile is the hammer; **short** (of ducats or goods) = red rim, and **one red
  line under the strip** names what the first short tile lacks ("cost 300 · you have 204"); **refused or locked** (`slot`,
  `rule`, `gate`) = a lock tile. A tile draws no words: its name, state line, gain, upkeep, cost and reason are its data and
  its **hover card** (R37, `BuildingCard`); a disabled hammer's tooltip carries the verdict ("a work is under way here" while
  one is). Pressing a tile runs `BuildRows`' rule unchanged (`game/confirm_works`, `works_card`, `begin_work`; the request
  names unchanged); the hammer is enabled iff the verdict is ok. A work under way keeps the tiles visible with every hammer
  greyed; Cancel is on the queue. The search box and the filter (All, Can build, Built) exist for the keys and the tests but
  are not shown: a tile has a handful of buildings until M9.5. U begins the first upgrade through the model. **Not built:**
  workers and capacity numbers and bars on the plaque (they need M9.5's slots and workers). P: an enabled hammer on a refused
  tile; a tile that disagrees with `Works.*_check`.
- **R20** **Gain numbers.** A building's gain is the card's `year.gain` (the realm's measure, as the works card's default) for
  a buildable tile, and the hex's yearly worth for a built one; the tiles do not draw it, the hover card and the summary use
  it. The tiles come first without numbers when the full cards are not cached; the numbers fill **one row a frame** (a
  `Callable` queue, `finish_now()` for tests), then the summary. P: the summary not equal to the sum of the built rows.
- **R21** **Army** (own settlement, or any tile with armies in sight), as icon cards: *Armies here* (a card per army: the
  figure on a wooden icon tile, the title (own: its name; foreign: "An army of <country>"), one small line (the men; own adds
  its state), and for **own armies only** a Select button that selects the army; foreign in sight: men exact, no button); then
  on own settlements the head line "Men to levy 800 · 1 of 2 raised this season", the **arms banner** (M9.5: "Arms in stores
  6 · bought arms cost +50%"; absent before), and *Raise a company here* rows (`CompanyRow`, compact): icon (the unit figure),
  name, age badge I / II / III (`UnitDef.era`), a state line ("500 men · 30 ducats + 1 iron · upkeep 6"; M9.5: "+ 1 arms"), "can
  raise N" or "-", and a hammer (raises one company through `Session.act`). Greyed rows carry their reason in bad tone ("needs
  3 horses, you have 1"); `gate` rows are locked. **A refusal every row shares word for word (the season's cap) is said once**
  under the head line; the rows keep their own small line. "Show all" opens `RaiseScreen` (R27). Optional fields `points_text`
  (432) and `arms_text` are shown when present. P: a Select on a foreign army; a hammer enabled where `raise_check` refuses.
- **R22** **`can_raise`** is the largest `n` (0 to `raise_cap` left) with `raise_check(count = n)` ok, found by stepping
  down from the bound `min(cap left, men_at_hand / men, ducats / cost, each good / its need)`. P: off by one (the test
  checks `n` ok and `n + 1` refused).
- **R23** **Ships** shows one empty box: "No ships yet" and, from TW23, in-game wording with no development words (D23; default "No ships here yet. Ships and shipyards will be built in your ports."); until TW23 "Ships and shipyards arrive with a later milestone. This tab is here so
  ports have a place for them." No button, no list.
- **R24** Tabs change the game only through `Session.act` or the window's requests; they never assign to game objects
  (`test_tile_tabs.gd` scans the folder for `game.state.` and `.tag =` style writes). P: a planted write.

### 3.5 Hover cards and the Raise companies window

- **R25** **`BuildingCard.of(game, tag, hex, option)`** -> `{title ("Armourer in Asti"), kind ("Workshop"), sections:
  [{head, lines: [[label, tone, text]]}], verdict {ok, text, tone}}`: *Each year it would*: uses, makes (the changed goods
  of `ImprovePreview.of`), profit (`year.gain`), upkeep; *To build*: cost (ducats, goods), building time (`cost.seasons`),
  payback (`payback.text`); the verdict line: "You can build this: the hammer, or a click." or the reason words in bad tone
  ("You cannot afford this yet: 96 more ducats."). M9.5 adds workers and raw bonus lines as optional sections. Built rows:
  what it makes and its upkeep, no cost. Own-only (R9). P: a card without its cost lines; a refusal not in bad tone.
- **R26** **`CompanyCard.of(game, tag, hex, kind)`** -> the same shape: men, attack / defence, branch; *To raise*: ducats,
  each good (M9.5 arms: "1 (own: 6 in stores)" or "1 bought, 13.5"), men from the people ("500 of 800 available");
  *Afterwards*: upkeep a season; the verdict "You can raise 6 companies here this season." or the refusal. A refused kind
  keeps its whole card. P: a refused card without its cost lines.
- **R27** **`RaiseScreen`** (`shell/screens/raise_screen.gd`, non-opaque, `ModalFrame`): title "Raise companies", the place
  and men to levy, the arms banner, search and filter (All, Can raise), and one **tall row** per kind from the same
  `TileArmy` rows (portrait = the unit figure, name and age badge, men, attack, upkeep, cost lines, "can raise N",
  hammer). Esc closes it; the strip's keys do nothing while it is up. It refreshes on `game.version`. **Not restyled:** it
  keeps the first draft's look and has not had the v4 treatment (deferred). P: a raise from the screen that bypasses
  `Session.act`.

### 3.6 The picture

- **R28** **`TileView.header.picture`** is `{}` on non-settlement tiles, sea and unexplored; on a settlement or castle hex it
  is `{kind, level, harbour, cover, season, climate, seed, owner_tag}`: `kind` is one of `hamlet`, `village`, `town`,
  `walled_town`, `city`, `castle` (castles family; `level` 1 watchtower, 2 castle, 3 fortress); `harbour` 0 to 3 (the
  port picture: any settlement with a harbour addon); `seed` = a fixed mix of the hex's column and row (no luck). **As built**
  the window shows a picture on **every** discovered tile: when `picture` is `{}` it draws the bare land (`LAND`) or, at sea,
  open water (`SEA`); on an unexplored hex a fog box with the word "Unexplored" replaces it.
- **R29** **`SettlementPicture`** (`shell/ui/settlement_picture.gd`, a `Control`, 150 px tall at the window's content width):
  `static func recipe(picture) -> Array[Dictionary]` is pure (shapes: `{shape: &"rect"|&"poly"|&"line", points, fill_token,
  ink: bool}`) and laid out in a logical 296 x 72 box; `_draw()` only walks it. The picture **scales to the Control's
  width so the whole town is visible** (D25: the scale is the Control's width over the recipe box's width, the sky and ground
  bands fill the Control's height, the town sits on the ground band, nothing is cropped at the sides; until TW23 the code
  scales by the height and crops the sides of a wider Control). The recipe: a sky band (by season; snow on roofs in snow climate), a ground band (by
  cover), then the kind: hamlet 2 to 3 houses; village 4 to 5 and a chapel; town 6 to 8, a church tower; walled town the town
  behind a wall with a gate and two towers; city denser roofs, a cathedral, walls and four towers; castle a keep (one tower for
  a watchtower, keep and curtain for a castle, bastions for a fortress); `LAND` and `SEA` have no settlement. Harbour 1 to 3
  adds a water band on the right third, a quay and 1 to 3 masts. A pennant in the owner's colour flies on the tallest tower.
  Flat two-tone faces, ink outlines, token colours only. The name and owner are not drawn over the picture (they are the title bar and sub line above it); from TW23 a **settlement-type
  emblem** (one small round emblem for the picture's kind, with a tooltip that names the type, D22) sits at the picture's top left
  and replaces the size stars; the badges are round icons at its foot. The same picture shows in light fog. The
  owner's note of 2026-11-25 stands: the picture is a placeholder for future stylised backgrounds, with no new kinds. P: a
  recipe that differs for the same input; a walled town without a wall; a port without a mast.


### 3.7 Opening, the menu, the keys

- **R30** **Opening.** A left click on a hex opens the window (as today). A right click with an own army selected is an
  order (unchanged). A right click with no army selected on an own hex opens the small menu; elsewhere it clears the
  selection (unchanged).
- **R31** **The menu** (own hexes), under the place name as its title: "Tile details..." (window on the Town tab); "Build here..."
  (window on the Town tab, its strips on top; shown when building is offered); "Raise companies..." (window on Army; own
  settlement); "Show supply"; "Select <army>" per own army; the war items ("Open the Battle of X", "Show the siege of X", "Show
  the castle area", unchanged); "Cancel <work>" (own work under way; the queue's Cancel). P: an item whose action does not reach
  its target (each item clicked in `test_hex_menu.gd`).
  its target (each item clicked in `test_hex_menu.gd`).
- **R32** **Keys.** Ctrl+] / Ctrl+[ cycle the live tabs (wrapping) while no screen is up; with the Study or `RaiseScreen`
  up they do not reach the window. With focus on the strip, Left and Right switch tabs. Tab stays "Next unit" when focus is
  not in the window. Esc closes the window (ladder step 4) and closes `RaiseScreen` first when it is up. O and Shift+F10
  open the menu (unchanged). U begins the first upgrade row whatever tab is open. P: Ctrl+] with the Study up; Tab with
  focus on the map.

### 3.8 Layout, style, saves, speed

- **R33** **One size.** Dock, `Tokens.TILE_WINDOW_W` x `Tokens.TILE_WINDOW_H` (440 x 640 logical) in the kit's gold frame, on every
  case and every tab: the window never changes size when another tile or tab is picked. The header, the tab strip and the
  queue are pinned; only the tab body scrolls (strips wrap onto more rows, the facts grow, the body scrolls). Only a viewport
  too short for 640 shrinks it, to the room below its top minus `Tokens.S2`, the same for every case and tab. At 1280 x 720
  scale 1 and 2560 x 1440 scale 2: inside the viewport, and the tab strip with **five** labels (the real ones and the
  fixture's) fits the content width in both themes. P: a label long enough to overflow; a window that grows with its content.
- **R34** Studiolo style, tokens only. New widgets go to `shell/ui/` with their own test: `SettlementPicture`, `BuildingRow`
  (the tile, 40 px from TW23), `CompanyRow` (compact and tall forms), `StripCells` (the chips), `TileStyle` (the flat boxes and buttons of
  the window as data for `KitTheme`, the Tile* type variations). Flat tabs with a gold underline on the open tab. No `Color(`
  literal, no `theme_override_` in `.tscn`. The picture's colours are `Tokens` art entries.
- **R35** No save change; nothing of the window is saved. `Game.digest()` unchanged; replay, save, soak and AI tests do not
  move.
- **R36** The window reads models cached per version; opening, switching and the gain fill stay within section 8.
- **R37** **The hover rule.** Every icon and every number the window shows explains itself: a **tooltip** on each chip, the
  emblem (the stars until TW23), each badge icon, each plaque, the food, the queue row, each tab (a dimmed tab keeps its reason), the Show buttons and
  the close button; a **hover card** on every building tile (`BuildingCard`) and company row (`CompanyCard`), through the tab's
  `row_hovered` and the HUD's `RowCard`. `test_tile_window_tips.gd` walks an own settlement, own land with no settlement,
  foreign land, the sea and an unexplored hex, each on every live tab with the real tabs, and fails on a control without one.
  P: a chip or a tile with no tooltip or card.
- **R38** **UI scale.** The size of R33 is in logical pixels: at UI scale 1.25 and 1.5 (a 1920 x 1080 window) the window is
  still 440 x 640 (or the shrunk height of R33) and inside the viewport, for every case and tab. P: a window that changes
  size with the scale.
- **R39** **The close button** is round; its cross is **drawn** (two lines centred on the button's rectangle, no glyph or
  icon, so it sits in the middle whatever the font). It asks the App for `close_tile`, which clears the map's selection (the
  window goes with it); with no App connected the window clears itself. P: a cross off centre.
- **R40** **Chips fit.** The chips share the row by the length of their numbers; the icon sits in a round dot at the left, the
  number is centred in the rest of the pill, and a value too long for its pill **clips with an ellipsis**: it never leaves its
  pill nor widens the window; the tooltip always carries the label and the whole value. Tested at 1280 and 1024 wide, UI
  scales 1, 1.25 and 1.5. P: a number that spills out of its pill.


### 3.9 The cases

| Case | Header | Chips | Queue | Tabs (live; *dimmed*) |
|---|---|---|---|---|
| Own port settlement | picture with harbour and emblem, name | People, Food, Works, Income (ducats a year) | work or "No work under way" | Town, Army, Ships |
| Own inland settlement | picture | as above | as above | Town, Army |
| Own district or wild land | bare-land picture | as above | as above | Town; Army live only with armies |
| Own land occupied | + "Occupied by X" | as above | the work, if any | Town, Army if armies |
| Foreign, light fog | picture (settlement) or bare land | People, Garrison, Buildings, Armies "fog" | the work, no Cancel | Town (facts only); *Army* |
| Foreign, in sight, enemy army | + "Enemy army here" | Armies "1" | as above | Town (facts only), Army (read-only) |
| Siege | + "Besieged" (light) / "Besieged by X" (sight) | as the case | as the case | as the case; the siege block tops the Town tab |
| Witnessed battle site | + "Battle here, Spring 1481" | as the case | as the case | as the case; the facts have "Open the battle" |
| Unowned land | "no one" | People, Garrison, Buildings, Armies | the work, if any | Town (facts only); *Army* |
| Sea | sea picture, "Open sea" / "Coastal sea" | none | none | Town (tab strip hidden) |
| Deep fog | "Unexplored", "Hex x, y"; fog box, no picture | none | none | none |
| Sandbox | bare-land or settlement picture, no owner | People, Food | work or none | Town |

---


## 4. Interfaces

```gdscript
# core/views/tile_view.gd (new): light, every case
static func of(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary
# {case, hex, sight,
#  header: {title, place, subtitle, owner: {tag, name, relation}, stars, picture: {} | {kind, level, harbour, cover,
#           season, climate, seed, owner_tag}, badges: Array[{text, tone}]},
#  strip: Array[{key, value, label, tone}],
#  job: {} | {label, progress, ready, halted, tag, cancel: bool},
#  land: {people: Dictionary, food: {} | {made, eaten}, made: Array[{good, name, loads, value (own) | null}],
#         buildings: Array[{name, state_text}] (non-own), ground_rows, war: bool, battle: {} | {record, name},
#         armies_hidden: bool, supply: bool, castle_area: bool, sea_rows},
#  build: {offered: bool, reason}, army: {raise_offered: bool, reason, armies_seen: int}, own_port: bool}

# core/views/tile_buildings.gd (new): own or sandbox only
static func of(game: Game, tag: StringName, hex: Vector2i) -> Dictionary
# {summary: {make, upkeep} (filled when gains are cached), groups: Array[{id, name, slots: {} | {used, total},
#  rows: Array[{option ({} for built), name, icon, state (&"built"|&"building"|&"ready"|&"short"|&"locked"|&"refused"),
#  state_text, tone, progress (0..1, building only), gain: int | null, hammer: bool, reason}]}]}
static func gain(game: Game, tag: StringName, hex: Vector2i, option: Dictionary) -> int   # the card's year.gain, cached
static func state_of(verdict: Dictionary, blocked_by: StringName) -> StringName          # pure: ok -> ready, ducats/goods -> short,
                                                                                         # gate -> locked, slot/rule -> refused

# core/views/tile_army.gd (new): armies here for any viewer; raise rows own settlement only
static func of(game: Game, tag: StringName, hex: Vector2i) -> Dictionary
# {armies: Array[{own, id (own only), tag, country, name, men, state_text, points_text, arms_text}],
#  raise: {} | {head, arms: {} | {in_stores, premium_text}, rows: Array[{kind, name, figure, era, men, cost_text,
#  upkeep, can_raise, state (&"ready"|&"short"|&"locked"), reason}]}}
static func can_raise(game: Game, tag: StringName, hex: Vector2i, kind: int) -> int

# core/views/building_card.gd, company_card.gd (new)
static func of(game: Game, tag: StringName, hex: Vector2i, option: Dictionary) -> Dictionary   # BuildingCard
static func of(game: Game, tag: StringName, hex: Vector2i, kind: int) -> Dictionary            # CompanyCard
# both: {title, kind, sections: Array[{head, lines: Array[[label, tone, text]]}], verdict: {ok, text, tone}}

# shell/panels/tile_tabs/tile_tab.gd (edit): static func dimmed(view: Dictionary) -> String   # "" = live
# shell/panels/tile_tabs/tile_tabs.gd (edit): static func dimmed_for(view: Dictionary) -> Dictionary
# shell/ui/settlement_picture.gd (new): static func recipe(picture: Dictionary) -> Array[Dictionary]; func show_picture(kind, level, harbour, snow, colour)

# shell/panels/tile_window.gd (new) extends HexPanelContract
signal country_requested(tag: StringName)
signal works_requested(what: StringName, args: Dictionary)
signal app_requested(what: StringName, args: Dictionary)        # a tab's or the header's request to the App (close_tile, ...)
signal row_hovered(card: Dictionary, anchor: Rect2)             # the row's BuildingCard or CompanyCard and the rect to anchor to
signal row_unhovered
signal toast_requested(text: String, tone: StringName)
func show_hex(hex: Vector2i) -> void
func show_tab(id: StringName) -> bool      # the menu's items; false for a dimmed or absent tab
func tab_open() -> StringName
func tab_ids() -> Array[StringName]        # shown; live_tab_ids() the live ones
func next_tab(step: int) -> void           # live tabs only
func begin_option(option: Dictionary, expensive: bool) -> bool   # to the open tab (the Town tab takes it)
func handle_key(event: InputEvent) -> bool # Ctrl+[ / Ctrl+], and Left / Right with the strip focused; nothing while a screen is up


# shell/screens/raise_screen.gd (new) extends Screen
func open_for(hex: Vector2i) -> void
```

Panel signals keep the names of the old panel's where they existed (`country_requested`, `works_requested`, `toast_requested`), so `Hud` and `WarRequests` reconnected to the window as they did to the panel; `row_hovered` carries the card and its anchor rect, and `app_requested` is new.

---

## 5. Fog: what each fact reads

| Fact | Read through | Undiscovered | Light fog | In sight |
|---|---|---|---|---|
| Title, ground, place, piece, picture | gate R2, then `HexCard` map rows, the piece | "Unexplored" only | shown | shown |
| Owner, holder, "Occupied" | `Territory.owner_tag` after the gate; `war_rows_for` | hidden | shown | shown |
| People | `PeopleView.at(viewer)` | hidden | exact | exact |
| Goods made (loads), buildings, work | district output after the gate, `WorksView.at(viewer)` | hidden | exact | exact |
| Food, ducats, works, values at price | own-only (`MapModes.food_year(viewer)`, the viewer's country) | n/a | n/a (not own) | own only |
| Fortress, garrison | `Knowledge.garrison_known` (via `war_rows_for`) | hidden | exact | exact |
| Siege | `SiegeView.at(viewer)` | hidden | "Besieged", meter, garrison | besieger, men |
| Battle badge and row | `BattleView.sites(viewer)` | hidden | if witnessed | if witnessed |
| Armies, men, strip "Armies" | `ArmyView.visible(viewer)` | hidden | hidden ("fog") | exact, no orders |
| Building rows, raise rows, cards | own-only models (R9) | n/a | n/a | own tile only |

---

## 6. Sketches

The approved mockups (Appendix B, and the owner's v4 look of the polish rounds) are the reference for look and spacing; this
sketch fixes the order of parts only (440 x 640 logical).

```
OWN TOWN (Town tab)                            FOREIGN, LIGHT FOG (Town tab)
+------------------------------------+         +------------------------------------+
|             Asti                (x) |         |             Novara             (x) |
| Walled town . hex 4, 10 . Genoa . Food +14 |  | Town . hex 7, 3 . Duchy of Milan   |
| (6,200) (+14) (1 of 3) (+38)       |         | (9,800) (400/400) (2) (fog)        |
| [ picture, 150 px, whole town [W] ]|         | [ picture: town [T] ]              |
|   (o) (o) round badge icons        |         |   (o)                              |
| Town | Army | Ships                |         | Town | Army (dimmed)               |
+------------------------------------+         +------------------------------------+
| (siege block, when besieged)       |         | MADE HERE A YEAR                   |
| SETTLEMENT  [v][#][ ][ ]           |         |  Wool 10 loads   Grain 9 loads     |
|  3 built of 4   (red line if short)|         | BUILDINGS   Weaver . working       |
| LAND        [#][#]                 |         | GROUND AND DEFENCE  ...            |
| HARBOUR     [ ]                    |         | ARMIES  Out of sight: no armies    |
| land facts ledger ...              |         | [Show supply]                      |
| Army is closed here: reason        |         |                                    |
+------------------------------------+         +------------------------------------+
| Building: vineyard, Spring 1481 [Cancel]     | Building: weaver, ready 1482       |
+------------------------------------+         +------------------------------------+
```

[W] and [T] are the settlement-type emblem on the picture (D22, from TW23); the size stars of the first sketches are gone. The
last chip of the own town is the tile's income a year (D21). The heads of the facts ledger fold and open (D26).

---


## 7. Tests

All under `godot/tests/`. Every edited test keeps its planted faults; a task may not delete a P without replacing it.

### 7.1 New tests

| Test | Cases | Planted faults |
|---|---|---|
| `core/test_tile_view.gd` | each row of 3.9 on north Italy (Genoa, Savona port, Asti, Milan) and the sandbox; header, emblem (from TW23; the stars are gone), badge order; strip cells per case; job own and foreign; dimmed reasons; `own_port` on Savona, not Asti; picture kinds | R2, R3, R10, R11, R12, R14's facts |
| `core/test_tile_buildings.gd` | groups and order; each state from a real verdict (ok, ducats, goods, slot, rule) and `state_of` for `gate`; hammer iff ok (the check/act pair over every row); built rows; gains equal the cards; summary = sum; `{}` on foreign | R9, R19, R20 |
| `core/test_tile_army.gd` | armies own and foreign by sight; raise rows; `can_raise` (n ok, n + 1 refused) on 3 towns; era badge; refusals keep words | R7, R9, R21, R22 |
| `core/test_building_card.gd`, `test_company_card.gd` | sections and lines per state; refusal in bad tone; refused card keeps cost lines | R25, R26 |
| `core/test_tile_fog.gd` | on `FogFixture.thin` and `duel_thin`: every case at each sight level; the twin test of R5 over `TileView` and `TileArmy.armies` on every hex (copy B moves unseen armies, changes owners, pieces, works, garrisons of undiscovered hexes); viewer not `game.player` | R4 to R7 |
| `core/test_tile_door.gd` | the scan of R8 | one P per forbidden name |
| `shell/test_settlement_picture.gd` | recipe per kind and harbour level; same input same recipe; walls, masts, keep present; tokens only | R29 |
| `shell/test_tile_tabs.gd` (edit) | `dimmed_for` per case of 3.9; the fake tab; the write scan of R24 | kept + a dimmed tab that opens |
| `shell/test_tile_window.gd`, `test_tile_window_strips.gd`, `test_tile_window_tips.gd`, `test_tile_window_foldin.gd` | frame per case; picture or title bar; chips; strip hidden at sea; R16 choice and fall-back; lazy build; one refresh per burst; Ctrl+] / Ctrl+[ skip dimmed tabs and the Study (R32); Esc; R33 and R38 at both sizes, the UI scales and both themes; the drawn close cross centred (R39); chips inside their pills (R40); the 26-tile fixture wraps with the window keeping its size; every icon and number has a tooltip or card (R37); the fold-in cases of the deleted panel tests | R15, R16, R32, R33, R37 to R40 |
| `shell/test_town_tab.gd`, `test_town_tab_strips.gd` | the Town tab: siege block, strips on own land and none on foreign, the facts, the dimmed reasons; the works cases of `test_hex_panel.gd` moved and adapted (tiles, confirm modes, reasons, U); search, filter (kept for keys and tests); the gain fill (`finish_now`); hover card shows (these replace the first draft's `test_land_tab.gd` and `test_buildings_tab.gd`) | R18, R19's hammer P |
| `shell/test_army_tab.gd` | `test_raise_list.gd` moved; armies own and foreign; read-only on foreign; hover card; Show all opens `RaiseScreen` | R21's P |
| (merged into the Town tab's tests above) | `test_hex_panel_people.gd`, `test_hex_panel_fog.gd` and the details half of `test_hex_panel.gd` live in `test_town_tab.gd`; battle row; out-of-sight line; sea rows | today's |
| `shell/test_ships_tab.gd` | the box on Savona; absent on Asti | Ships inland |
| `shell/test_raise_screen.gd` | rows, search, filter, raise through `Session.act`, Esc, refresh on version | R27's P |
| `shell/test_building_row.gd` | compact row states, built check, progress bar, bad-tone line, disabled hammer tooltip | a hammer enabled while `hammer` is false |

### 7.2 Tests that move or change

| Test | Change | Task |
|---|---|---|
| `shell/test_hex_panel.gd`, `test_hex_panel_people.gd`, `test_hex_panel_fog.gd` | deleted after their cases live in the new files (7.3) | TW16 |
| `shell/test_raise_list.gd` | becomes `test_army_tab.gd` and `test_raise_screen.gd` | TW12 (copy), TW16 (delete) |
| `shell/test_hex_menu.gd` | TW16 its cast; TW17 the new items, inline works rows gone, each item reaches its target | TW16, TW17 |
| `shell/test_tile_tabs.gd`, `fixtures/tile_tabs/fake_tab.gd` | `dimmed_for`; the fixture's comment no longer names Industries | TW9 |
| `shell/test_works_preview.gd` | "left of the tile window"; the focused row loads the Town tab | TW16 |
| `shell/test_hud.gd`, `test_app.gd`, `test_app_flow*.gd`, `test_army_toasts.gd` | `hex_panel()` to `tile_window()`; `show_raise()` to `show_tab(&"army")` | TW16 |
| `shell/monkey_m6.gd`, `monkey_m7.gd` | the Raise step through the Army tab; menu counters kept | TW16 |
| `tools/ui/shot_ui.gd`, `shot_ui_m6.gd`, `shot_ui_fog.gd`, `perf_ui.gd`, `perf_ui_m7.gd` | call `tile_window()`; scene names kept | TW16 |
| `core/test_fog_exact.gd` | its scan lists the new files | TW15 |

**Unchanged, must stay green:** every `core/` rule and AI test, `test_hex_war.gd`, `test_replay*.gd`, `test_save_file.gd`,
`test_snapshot.gd`, `test_fog_views.gd`, the soak.

### 7.3 The fold-in checklist (TW16's pull request)

Every test function of `test_hex_panel.gd` (26), `test_hex_panel_people.gd` (12), `test_hex_panel_fog.gd` (2),
`test_raise_list.gd` (12) and `test_hex_menu.gd` (13) is listed with the new test that covers it, or why it is gone. Every
row of today's panel and item of today's menu is listed with its new place (the inline works rows: "Build here..." and the
Buildings tab). The code reviewer checks the list against the files.

### 7.4 Monkey and pictures

**Monkey** (`tests/shell/monkey_tile.gd`, extends `MonkeyFog`): clicks random hexes (own, foreign, sea, undiscovered on a
thin seed), switches tabs by click (dimmed ones too: nothing happens) and by Ctrl+] / Ctrl+[, hovers rows, opens the menu
and picks its items, opens and closes `RaiseScreen`, raises and builds when a hammer allows. Invariants each frame: the
open tab is live in `TileTabs.dimmed_for(TileView.of(...))`; the strip shows exactly the shown tabs; an undiscovered hex
shows only "Unexplored"; no army row for an army `ArmyView.visible` refuses; the window lies in the viewport. Counters
`tile_opens`, `tile_tab_switches`, `tile_cases` (at least three a seed), `raise_screen_opens` above 0.

**Pictures** (`tools/ui/shot_ui_tile.gd`; 1280 x 720 scale 1, 2560 x 1440 scale 2): own port on each tab, own walled town
on Buildings and Army, both hover cards, `RaiseScreen`, foreign light fog, foreign in sight with an enemy army and a siege,
a battle site, sea, deep fog (thin fixture), the menu, the seven picture kinds on one sheet, the five-label strip. The old
panel scenes of `shot_ui.gd`, `shot_ui_m6.gd`, `shot_ui_fog.gd` are made again. **The owner is asked before any windowed
run.** The art director signs them against the approved mockups.

---

## 8. Performance

TW1 recorded the baseline of the existing rows; TW18 adds the new rows and measures all; both tables in its pull request.

| Row | Class | Limit | Expected | Note |
|---|---|---|---|---|
| **new** `tile_view_ms` (`perf_core`) | cpu | 1.0 mean, 4.0 worst | about 0.3 | every land hex of north Italy for Genoa, cache cleared |
| **new** `tile_buildings_ms` (`perf_core`) | cpu | 2.0 rows; 40 with every gain | rows 0.5; gains 10 to 30 | Genoa city and a wild hex with all build options, cache cleared |
| **new** `tile_army_ms` (`perf_core`) | cpu | 2.0 | about 0.5 | Genoa, `can_raise` for every kind |
| **new** `tile_window_open_ms` (`perf_ui`) | gpu | 16 | under 10 | own city cold, the picture drawn, one forced draw, worst of 3 |
| **new** `tile_tab_switch_ms` (`perf_ui`) | gpu | 16 | under 8 | Land, Buildings, Army, Ships on Savona, worst |
| **new** `gain_fill_frame_ms` (`perf_ui`) | gpu | 16 | under 6 | the worst frame of the one-row-a-frame fill |
| **new** `raise_screen_open_ms` (`perf_ui`) | gpu | 16 | under 8 | |
| `hud_frame_worst_ms`, `hex_menu_war_ms`, `works_card_push_ms`, `army_panel_open_ms` | as today | as today | unchanged | baseline from TW1 |

**As built:** the core rows are `tile_view_ms`, `tile_view_worst_ms`, `tile_army_ms` and `tile_buildings_ms` (with `tile_buildings_gains_ms`, known over its limit, issue 458); the UI rows are `tile_window_open_ms`, `tile_tab_switch_ms`, `gain_fill_frame_ms` and `raise_screen_open_ms` (`tools/ui/perf_ui_tile.gd`; budgets in `tests/perf_core_budget.json` and `tests/perf_ui_budget.json`).

If `tile_window_open_ms` passes its limit: the open tab fills on the frame after the header. If a single gain passes 12 ms
(one fill frame), `TileBuildings.gain` reuses one `EconomyPreview` base per frame for all rows (the M4 cache key).

---

## 9. Risks

- **The swap is wide** (TW16: HUD, menu, app wiring, eleven test files). Tabs are built beside the old panel first; 7.3.
- **Gains are heavy.** A full card per buildable row; the one-row-a-frame fill and its perf row keep frames under 16 ms.
- **The picture looks crude.** The recipe is pure and tested; the art director signs it at both scales before the swap; a
  bake of the same recipe into textures is the fallback (no rule change).
- **Dimmed tabs confuse.** Their tooltip names the reason; the playtest checks it; making them absent is one function.
- **M9.5 lands on this.** It fills `slots`, `arms`, `gate` and adds a Workshops group and rows; it edits no frame file.
  The door scan covers its new models by their names (`tile_*.gd`).
- **Key clashes** with the Study and `RaiseScreen`: R32's tests.
- **Folder listing in exports:** solved by the index (TW3); the export probe runs when export templates exist (plan).

---

## 10. As built (2026-11-25)

The window is built and tested; what is left is TW19 (pictures signed against the mockups at both scales, regenerated goldens,
README, `CLAUDE.md` and the docs) and TW23 (design review round 3, in progress, 10.4). The code is in `godot/shell/panels/` (`tile_window.gd`, `tile_tabs/`), `godot/shell/ui/`,
`godot/shell/screens/raise_screen.gd`, `godot/shell/hud/` and `godot/core/views/`; commits: group A 3950cfa, B 2e1d3be, C
ef7cbc6, D 0f7827f; the rest (TW17, TW18 and the polish rounds TW20 to TW22) was built after 0f7827f. `HexPanel`, `RaiseList` and `HexWar` are
deleted.

### 10.1 Where the build left this spec's first design

| The first design said | As built | Why |
|---|---|---|
| Tabs Land, Buildings, Army, Ships (R14, D8) | **Town** (10: the siege, the strips, the facts), **Army** (30), **Ships** (40, own ports only); the fixture's fake tab is 50 | The owner's decision after playtest: Land and Buildings are one tab (as EU5's Infrastructure); one click less, the facts and the building in one place |
| Width `Tokens.PANEL_W` (296), height from the content (D2, R33) | A fixed 440 x 640 logical on every tile and tab (`TILE_WINDOW_W`, `TILE_WINDOW_H`); shrinks only on a short viewport; the body scrolls | The window jumped in size between tiles and tabs; the icon strips need width |
| The siege meter lives in Land's war block | The **siege block tops the Town tab** (besieger and men where the fog allows, a `SiegeMeter`, the season, "falls in N seasons", Show siege); not on the Army tab | The owner: a siege is a state of the tile, not of its army |
| Compact building rows: icon, name, state line, gain number, hammer (R19) | One wooden strip per group, a plaque (icon, name, "N built of M") and **48 px icon tiles** (40 px from TW23, D24); the state is the rim; one red line under a strip for a short tile; the words moved to the hover card | Mockup v4 (after EU4 and EU5): icon first |
| Summary line, search box and filter shown (R19) | The summary shows; the search and the filter exist for keys and tests but are not drawn | A tile has a handful of buildings until M9.5 |
| Gain number on each row (R20) | Computed one row a frame as before; shown in the hover card and the summary, not on the tile | No room on a 48 px tile |
| Number strip of four cells (R10) | Four **round-icon chips**, sized to their content, number centred, ellipsis with the full value in the tooltip (R40) | Mockup v4; a long number must not widen the window |
| Header: picture with name, kind, owner and stars laid over it; a plain title bar off settlements (R11, R28, R29) | A title bar (stars left, name centred, a drawn round close button right), a teal sub line (ground and hex, owner link, food), the chips, then a **150 px picture on every tile** (`SettlementPicture` gained the `LAND` and `SEA` kinds) with **round badge icons**; "Unexplored" on deep fog (the stars leave the title bar in TW23: an emblem on the picture, D22) | Mockup v4; the same layout on every tile |
| Picture 296 x 72 logical (R29) | 150 px tall at the window's width; the intent is to scale to the width so the whole town is visible | A cropped middle hid the town; the fix is D25, built in TW23 |
| The job line sits under the strip (D11, R12) | The **queue**: one row (work, seasons, red Cancel) pinned at the foot of the window on every tab | The work stays in view while the body scrolls |
| Army rows: compact rows with an open arrow (R21) | Icon cards; a Select button (own armies only); the season's cap said once under the head line | Mockup v4; the same refusal on every row was noise |
| Dimmed tabs: reason as tooltip (R14) | Also **written under the Town tab's facts** ("Army is closed here" and the reason); at sea "Nothing to build or raise at sea" | A tooltip is easy to miss (mockup v4) |
| Buildings could be dimmed on foreign land (R14) | The Town tab is never dimmed; foreign and unowned land show the facts and no strips | Land and Buildings merged |
| Menu items open Land and Buildings (R31) | "Tile details..." and "Build here..." open the Town tab; "Raise companies..." the Army tab | Same merge |
| Hover cards on rows (R25, R26) | Kept, and extended to **every** icon and number by a rule with a walking test (R37, new) | The owner's rule: icon first, so everything explains itself |
| `row_hovered(hex, option)` (section 4) | `row_hovered(card, anchor)`; `app_requested(what, args)` added; `show_tab` and `begin_option` return a bool | The card is built where the row is |
| Close button not specified | Round, its cross drawn and centred, asks the App for `close_tile` (R39, new) | The font glyph sat off centre |
| Window opens on the last tab, else Buildings, else Land (D7) | Last tab, else Town | Merge |
| Ships text "keeps their place at the port" (R23) | "Ships and shipyards arrive with a later milestone. This tab is here so ports have a place for them." until TW23, then in-game wording (D23) | Wording only |

### 10.2 Every requirement

| Rules | State |
|---|---|
| R1 to R9 (the models, the cases, the fog, the door) | **Built**; tests `test_tile_view`, `test_tile_fog`, `test_tile_door`, `test_fog_exact` |
| R10 (chips), R11 (header), R12 (job line) | **Built**, changed as 10.1 says; the ducats chip as income, the emblem and the stars' removal: TW23 (D21, D22), in progress |
| R13 (registry) | **Built**; three tabs, ids and orders in R14 |
| R14 to R17 (tabs, which opens, lazy) | **Built**, changed as 10.1 says |
| R18 to R21 (Town tab, strips, gains, Army) | **Built**, changed as 10.1 says. **Not built:** workers and capacity numbers and bars on the plaque (deferred to M9.5: slots and workers). 40 px tiles, the two-line plaque and the collapsible sections: TW23 (D24, D26), in progress |
| R22 (`can_raise`), R23 (Ships), R24 (no writes) | **Built**; the Ships wording: TW23 (D23), in progress |
| R25, R26 (the cards) | **Built** |
| R27 (`RaiseScreen`) | **Built; restyle deferred** (it keeps the first draft's look) |
| R28, R29 (the picture) | **Built** as a placeholder (owner note); **scale to the window's width: decided (D25), built in TW23, in progress** (not in the code as read); the emblem (D22): TW23; **wild-land trees: deferred** |
| R30 to R32 (opening, menu, keys) | **Built** |
| R33 (one size) | **Built** |
| R34 to R36 (style, saves, speed) | **Built**; the perf rows are in 10.3 |
| R37 to R40 (hover rule, UI scale, close button, chips fit) | **Built** (new) |
| Back button (v4 mockup) | **Not built**, deferred |
| Slots, arms and gates (D16) | The fields are carried and empty; **M9.5 fills them** |
| TW19: pictures signed at both scales against the mockups, goldens, README, `CLAUDE.md` and docs | **Not done** (the plan's remaining task); `tools/ui/shot_ui_tile.gd` is written |
| TW23: design review round 3 (findings H1 to H5, M1 to M9, L1 to L7; D21 to D26) | **In progress** (the next polish task; 10.4) |

### 10.3 Tests and tools that carry it

`tests/core/test_tile_view.gd`, `test_tile_buildings.gd`, `test_tile_army.gd`, `test_building_card.gd`, `test_company_card.gd`,
`test_tile_fog.gd`, `test_tile_door.gd`; `tests/shell/test_tile_window.gd`, `test_tile_window_strips.gd` (a 26-tile fixture:
the strips wrap and the body scrolls), `test_tile_window_tips.gd` (the hover rule), `test_tile_window_foldin.gd`,
`test_town_tab.gd`, `test_town_tab_strips.gd`, `test_army_tab.gd`, `test_ships_tab.gd`, `test_raise_screen.gd`,
`test_building_row.gd`, `test_settlement_picture.gd`, `test_tile_tabs.gd`, `monkey_tile.gd`; tools `tools/build_tile_tabs.gd`
(the generated index `tile_tabs_index.gd` lists `army_tab.gd`, `ships_tab.gd`, `town_tab.gd`), `tools/ui/picture_sheet.gd`,
`tools/ui/perf_ui_tile.gd`, `tools/ui/shot_ui_tile.gd`, `tools/perf_tile_rows.gd`.

### 10.4 Design review round 3 (TW23, in progress)

TW23 is the next polish task after TW22 and is **in progress**. It fixes the designer's findings H1 to H5, M1 to M9 and L1 to
L7 (each by its id in the pull request, or answered there) and builds the owner's decisions of 2026-11-25:

| Decision | What changes | Rules touched |
|---|---|---|
| D21 | the own-tile ducats chip is this tile's income a year | R10 |
| D22 | the size stars go; a settlement-type emblem sits on the picture | R11, R28, R29, R37, `TileView.header` |
| D23 | the Ships tab stays, with in-game wording | R23 |
| D24 | 40 px building tiles and a two-line plaque | R19, R34 |
| D25 | the picture scales to the window's width, the whole town visible | R29 |
| D26 | the facts sections collapse | R18 |

Until TW23 is merged the code is as 10.1 and 10.2 describe it (stars, a treasury chip, 48 px tiles, a one-line plaque, the
first Ships wording, a picture scaled by its height). The pictures of TW19 are made after TW23 so they show the finished
window. Nothing here changes a core rule, a save or the digest.

---


## Appendix A. Amendments to earlier specs

| Spec | Section | Amendment |
|---|---|---|
| ui-family-audit.md | 3.1 to 3.5 | Tabs Town (Land and Buildings in one), Army, Ships (D8, D6); the menu (R31); keys of R32 ("R opens the Army tab" is wrong: R is Continue march) |
| m6-build-spec.md | 6.1, 6.8 | The Raise tab is the Army tab plus `RaiseScreen`; the menu's Raise item opens the Army tab |
| m7-build-spec.md | 6.8 | The war block and battle row live in Land; the menu keeps its war items |
| ui-and-controls-spec.md | bindings | `study_tab_prev`/`next` are "Previous tab"/"Next tab" for the Study and the tile window |
| economy-rethink.md | 3.1, 3.6, 3.7 | **No Industries tab:** slot buildings are tiles of the Town tab's strips (a Workshops strip with "n of m slots"); "opens in 1490" is a locked row (`gate`); the arms banner and "+ 1 arms" are fields of `TileArmy` and `CompanyCard` |

## Appendix B. Owner-approved mockups (2026-11-25)

| Mockup | Link | What was approved |
|---|---|---|
| Tile window tabs | https://claude.ai/artifact/DpLoAJFStBxeRYZo56csdX | The postcard, strip, job line, tabs Land / Buildings / Army / Ships (the Town tab since the polish rounds), light fog and deep fog |
| Buildings rows | https://claude.ai/artifact/4uo4nSxquUcFzj3sMJLdFH | Version 1, compact rows, with the summary line, search and filter |
| Town and army UI | https://claude.ai/artifact/DQHBRjFAqxUznavurRNund | Hover cards, the small menu, the recruiting window's tall rows and arms banner (slot tiles with levels: Appendix C) |

## Appendix C. Later ideas (not in v1)

- **Building levels and workforce:** slot tiles in category rows with + / - level controls and workers bars (mockup 3,
  panel 1). Needs building levels and staffing per building in the economy design first.
- **Market bar** at the foot of the Town tab (surplus, price, buyers): with M10's markets.
- **Goods and Food tabs** (Buildings mockup, version 4): after M10, as files in the tab folder.
- **Pictures for districts** (vineyard, mine, woods) and seasons' light; a baked high-detail picture set.
- **Sortable table** of buildings for big cities (Buildings mockup, version 4).
- **Workers and capacity numbers, and plaque bars** (the v4 mockup's staffing of a strip): need M9.5's slots and workers.
- **A back button** in the header (the v4 mockup): not built.
- **Trees on the wild-land picture:** the bare-land picture has none.
- **A restyled Raise companies window** in the v4 look.
