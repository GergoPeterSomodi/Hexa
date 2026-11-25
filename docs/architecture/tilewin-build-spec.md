# Tile window build spec: one uniform window per tile (issue 436)

Technical director, 2026-11-25. **Status: design approved by the owner (2026-11-25) after the mockups of Appendix B; group A
is built; groups B to E wait for the owner's go.** Builds section 3 of `docs/design/ui-family-audit.md` ("the audit") as the
owner answered it (2026-11-24) and as the approved mockups show it, on top of the fog build (`fog-build-spec.md`, on master)
and ready for the economy rethink (`docs/design/economy-rethink.md`, M9.5). Where the audit or the mockups say something
else, this page wins for the build. The tasks are in `tilewin-build-plan.md`.

**What it is, in one paragraph.** Every tile has one window, in the dock on the right where the hex panel is today: a
**postcard**. On a settlement or a castle its header is a code-drawn **picture** of the place with the name, the kind and
owner, and size stars laid over it; elsewhere a plain title bar. Under it a **number strip** (four numbers: people, food,
works or slots, ducats; foreign land: people, garrison, buildings, armies), the **job line** (the work under way, Cancel on
your own) and the **tabs**: **Land**, **Buildings**, **Army**, and **Ships** (your own ports only, empty until ships exist).
Buildings and Army are compact rows (icon, name, a small state line, one number, a hammer), each with a **hover card**; a
**Raise companies** window with tall rows opens from the Army tab's "Show all". Industries are plain buildings in the
Buildings list (no Industry tab). The small right-click menu stays. Every fact comes from pure read models in `core/views/`
(`TileView`, `TileBuildings`, `TileArmy`, `BuildingCard`, `CompanyCard`), which apply the fog and nothing else, so the
tests run headless and the fog is proved in one place.

**The tile window build is done when:**

1. Every rule R1 to R36 holds, each with its GUT case and its planted fault (P) of section 7.
2. `HexPanel`, its Works and Raise segment and its separate sea and unexplored paths are gone; the window replaces them
   behind the same seam (`HexPanelContract`); every case of the old tests has a twin in the new ones (checklist 7.3).
3. The right-click menu offers the items of R31; whatever it offered before has a place (the checklist lists each).
4. A fake tab placed in a test folder shows in the strip with no edit to the window or the registry (R11).
5. `SaveFile.FORMAT`, `Game.digest()` and every core rule are unchanged; the soak and the AI tests do not move.
6. The perf rows of section 8 are within their limits.
7. Lint, import, check_scripts, GUT, both UI `--check`s, `build_tile_tabs.gd --check` green; the pictures of 7.4 signed by
   the art director; the owner has played the plan's checklist.

---

## 1. What is there (master after the fog build, plus group A)

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
| D2 | Width | `Tokens.PANEL_W` (296). Four real labels: Land, Buildings, Army, Ships | One width for the family; R33 proves five labels fit (the fixture's fifth) |
| D3 | Where "which tab, live or dimmed" is decided | `TileView` gives facts and reasons; each tab's static `applies(view)` and `dimmed(view)` read only that dictionary | Core cannot know the shell's tabs; the choice stays testable headless |
| D4 | How a later milestone adds a tab | One `*_tab.gd` file in `shell/panels/tile_tabs/` plus `build_tile_tabs.gd` (the index; CI `--check`). Built in TW3 | "Add a file" kept; the index is safe in exports |
| D5 | Ships tab | Own port settlements only (`Improve.is_port`), one empty line; never dimmed elsewhere | Owner's answer; a dead tab on most of the map otherwise |
| D6 | Industries | **No Industry tab.** Industries are buildings in the Buildings list (M9.5 adds rows, not a tab); `ORDER` 30 is free | Owner, 2026-11-25; economy-rethink: industries are buildings in slots |
| D7 | Which tab opens | The last tab picked if it is live on the new tile; else Buildings if live; else Land. Not saved | Building is the common act on own land; a player on Army stays on Army |
| D8 | Tabs that do not apply on land | On any discovered land tile the strip always shows **Land, Buildings, Army**; a tab that does not apply is **dimmed** (not clickable, its reason as tooltip). Ships is shown only on own ports. Sea: Land only, strip hidden. Unexplored: no strip | The approved mockup shows dimmed tabs on foreign land; a stable strip reads better than tabs that come and go |
| D9 | Tab keys | Ctrl+] / Ctrl+[ ("Next tab", "Previous tab") cycle the **live** tabs when no screen is up; Left/Right only while the strip has focus | Tab is Next unit; arrows pan; the Study is a screen |
| D10 | The number strip | Four cells chosen by the case (R10), **the same on every tab** | Stable layout; the Army tab's men and arms sit in its own head line and banner |
| D11 | The job line | The work under way; siege, battle, occupation are header badges | One job per settlement shows on every tab |
| D12 | Hover cards | `BuildingCard.of` and `CompanyCard.of` in `core/views/`, fed by `ImprovePreview.of` and `Military`; the shell shows them in `HoverCard`. `RaiseCard` of the earlier draft is renamed `CompanyCard` and takes the hex | One card model per row kind, testable headless |
| D13 | Raise companies window | The **Army tab holds the compact rows**; "Show all" opens `RaiseScreen`, a non-opaque screen on the `ScreenStack` (`ModalFrame`) with tall rows, search and filter, for long lists | Owner, 2026-11-25 |
| D14 | Building rows in v1 | Compact rows grouped by category (Settlement, Land, Harbour, Defence; M9.5 adds Workshops) with "3 of 4 slots" on a category that has slots. **No building levels with + / -, no workforce bars** (Appendix C) | The economy design has neither |
| D15 | Settlement picture | Code-drawn in a `Control` (`SettlementPicture._draw`) from a pure recipe; no baked files (R28) | Cheapest honest way: no import, no atlas, sharp at scale 2, in the Kenney flat look; a bake can come later from the same recipe |
| D16 | Slots, arms, gates (M9.5, M11) | The row and card models carry `slots`, `arms`, `gate` fields now, empty until those builds fill them; before M9.5 the strip's third cell is the country's **Works** (crews in use of the limit) | The window does not change when M9.5 lands; M9.5 fills fields and adds rows |
| D17 | The right-click menu | Stays, own hexes only, with the approved items (R31); the inline works rows leave the menu for "Build here..." | The approved mockup; one click more for a build, the same confirm rule |
| D18 | Names | `TileWindow` replaces `HexPanel`; `Hud.tile_window()` replaces `Hud.hex_panel()` (no alias); `HexPanelContract` keeps its name | No deprecated alias |
| D19 | Sandbox (no countries) | Land and Buildings as today; no Army, no Ships; strip: people and food | The map sandbox keeps working |
| D20 | Task IDs | `TW0` to `TW19` | T, F, FG, K are taken |

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

### 3.2 Header, strip, job line

- **R10** **The strip** is `TileView.strip`: an array of `{key, value, label, tone}`, four cells or none:

| Case | Cells |
|---|---|
| own (any land) | People (`PeopleView.at`), Food (net a year from `MapModes.food_year(viewer)`, signed, tone), Works ("1 of 3", `WorksView.slots`; M9.5: a settlement shows Slots "3 of 4" instead), Ducats (the viewer's treasury) |
| foreign, unowned | People, Garrison ("400/400" from `war_rows_for`; "-" without a fortress), Buildings (count of built pieces and slot buildings), Armies (count in sight; "fog" out of sight) |
| sandbox | People, Food |
| sea, unexplored | none |

  P: the owner's treasury on a foreign tile; Food read through `game.player`.
- **R11** **The header** (`TileView.header`): `title` (place name, else the ground word capitalised; sea "Coastal sea" or
  "Open sea"); `place` ("Walled town · Republic of Genoa", the owner's long name, a link); `subtitle` ("farmland · hex 4, 10";
  sea "<depth> · hex x, y"); `owner {tag, name, relation}` (`yours`, `at_war`, `foreign`, `no_one`); `stars` (settlement level
  1 to 5, else 0); `picture` (R28; `{}` when none); `badges` in order, each `{text, tone}`: "Occupied by <holder>" (warn),
  "Besieged" / "Besieged by <besieger>" (bad; R6, R7), "Battle here, <season>" (bad; witnessed only), "Enemy army here" (bad)
  or "Foreign army here" (plain). P: a battle badge the viewer did not witness.
- **R12** **The job line** (`JobLine`, built): `WorksView.at(game, hex, viewer)`. Own: label, progress, ready, halted,
  Cancel; foreign or unowned: label and ready, no Cancel; own land with no work: "No work under way" (muted); else none.
  P: a Cancel on another country's work.

### 3.3 Tabs and the registry

- **R13** **The registry** (built, TW3): a tab is a `*_tab.gd` in `shell/panels/tile_tabs/` extending `TileTab` with `ID`,
  `LABEL`, `ORDER`, `static func applies(view) -> bool` (shown in the strip) and `fill(...)`. TW9 adds `static func
  dimmed(view) -> String` to `TileTab` (default `""`: live) and `TileTabs.dimmed_for(view) -> Dictionary` (id to reason).
  `TileTabs.all()` reads the index plus test folders. P (kept): a hard-coded list; two tabs with one `ORDER`.
- **R14** **Which tabs show, and when they are live** (in `ORDER`):

| Tab | `ID` | `ORDER` | Shown when | Dimmed (with this reason) when |
|---|---|---|---|---|
| Land | `land` | 10 | every case but `unexplored` | never |
| Buildings | `buildings` | 20 | any land case | not `build.offered`: reason from `Territory.at_home_check` ("Not your land: the Duchy of Milan holds it") |
| Army | `army` | 40 | any land case but `sandbox` | not `raise_offered` and no armies in sight: "Raising needs a village or larger" (own) or "Out of sight: no armies are shown" / "No armies here" (other) |
| Ships | `ships` | 50 | `own_port` | never (absent elsewhere) |

  On a foreign tile with armies in sight, Army is live and read-only (no raise rows). P: Army live on a foreign tile with no
  army in sight; Ships on an inland own town; a dimmed tab that opens by click or Ctrl+].
- **R15** The strip is hidden when only Land shows (sea). Order never changes.
- **R16** **Which tab opens** (D7) on `show_hex`; on a refresh where the open tab turns dimmed or absent (the last army
  left, the town was taken), the same fall-back, no toast. P: a dimmed tab left open.
- **R17** **Lazy tabs.** Only the open tab builds its controls; a switch frees the old one's (`PanelKit` retire list); a
  refresh rebuilds header, strip, job line and the open tab; one refresh per burst at the end of the frame.

### 3.4 The tabs

- **R18** **Land**, sections as the mockup: *People and food* (people with change and outlook for own, exact number for
  others; food made and eaten for own); *Made here a year* (one row per good: loads; own adds the value at price; from the
  district output over four calm seasons, the viewer's tax); *Buildings* (foreign and unowned only: built pieces and slot
  buildings with their state, "working" or "building 2 of 4"); *Ground and defence* (`HexCard.ground_rows`, the war block
  through `HexWar.fill`: holder, fortress, garrison, castle area, siege meter); the battle row "Battle of X, Spring 1481
  [Open the battle]" when witnessed; *Armies*: "Out of sight: no armies are shown" on non-own land out of sight; then "Show
  supply" and "Show the castle area" buttons as today. Sea: depth, relief, winter, coasts, crossings.
- **R19** **Buildings** (own, sandbox): a summary line "Buildings here make +N a year · upkeep -M" (from `TileBuildings`), a
  search box and a filter (`Segmented`: All, Can build, Built), then the rows grouped by category, each group headed by its
  name and, when it has slots, "3 of 4 slots". A **compact row** (`BuildingRow`, shell/ui): icon, name, a small state line,
  the yearly gain as one signed number, and a hammer button; a built row has a check instead of the hammer and a darker
  ground. State lines: "working · upkeep 6"; "building · 2 of 4 seasons" with a progress bar; "cost 120 · upkeep 8";
  "cost 300 · you have 204" (bad tone, from `blocked_by` `ducats` or `goods`); "all works crews busy (3 of 3)" (`slot`);
  "opens in 1495" or "needs Guilds" (`gate`, a lock icon; M9.5, M11); any other refusal: its reason words (bad). The
  hammer runs `BuildRows`' rule unchanged (`game/confirm_works`, `works_card`, `begin_work`); the hammer is enabled iff
  the verdict is ok. A work under way keeps the rows visible, every hammer greyed "a work is under way here"; Cancel is on
  the job line. U begins the first upgrade row through the model. P: an enabled hammer on a refused row; a row that
  disagrees with `Works.*_check`.
- **R20** **Gain numbers.** A row's number is the card's `year.gain` (the realm's measure, as the works card's default) for
  a buildable row, and the hex's yearly worth for a built one. The rows come first without numbers when the full cards are
  not cached; the numbers fill **one row a frame** (a `Callable` queue, `finish_now()` for tests), then the summary. P: the
  summary not equal to the sum of the built rows.
- **R21** **Army** (own settlement, or any tile with armies in sight): *Armies here* (own: name, men, state line "holding ·
  fed from the stores", an open arrow that selects the army; foreign in sight: country and army name, men exact, no arrow);
  then on own settlements the head line "Men to levy 800 · 1 of 2 raised this season", the **arms banner** (M9.5: "Arms in
  stores 6 · bought arms cost +50%"; absent before), and *Raise a company here* rows (`CompanyRow`): icon (the unit
  figure), name, age badge I / II / III (`UnitDef.era`), state line "500 men · 30 ducats + 1 iron · upkeep 6" (M9.5: "+ 1
  arms"), "can raise N" or "-", hammer (raises one company through `Session.act`). Greyed rows carry their reason in bad
  tone ("needs 3 horses, you have 1"); `gate` rows are locked ("opens with the Age of Arquebus"). A "Show all" button opens
  `RaiseScreen` (R26). Optional fields `points_text` (432) and `arms_text` are shown when present. P: an arrow or a Select
  on a foreign army; a hammer enabled where `raise_check` refuses.
- **R22** **`can_raise`** is the largest `n` (0 to `raise_cap` left) with `raise_check(count = n)` ok, found by stepping
  down from the bound `min(cap left, men_at_hand / men, ducats / cost, each good / its need)`. P: off by one (the test
  checks `n` ok and `n + 1` refused).
- **R23** **Ships** shows one empty box: "No ships yet" and "Ships and shipyards come with a later milestone. This tab
  keeps their place at the port." No button, no list.
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
  hammer). Esc closes it; the strip's keys do nothing while it is up. It refreshes on `game.version`. P: a raise from the
  screen that bypasses `Session.act`.

### 3.6 The picture

- **R28** **`TileView.header.picture`** is `{}` on non-settlement tiles, sea and unexplored; on a settlement or castle hex it
  is `{kind, level, harbour, cover, season, climate, seed, owner_tag}`: `kind` is one of `hamlet`, `village`, `town`,
  `walled_town`, `city`, `castle` (castles family; `level` 1 watchtower, 2 castle, 3 fortress); `harbour` 0 to 3 (the
  port picture: any settlement with a harbour addon); `seed` = a fixed mix of the hex's column and row (no luck).
- **R29** **`SettlementPicture`** (`shell/ui/settlement_picture.gd`, a `Control`, 296 x 72 logical): `static func
  recipe(picture) -> Array[Dictionary]` is pure (shapes: `{shape: &"rect"|&"poly"|&"line", points, fill_token,
  ink: bool}`), and `_draw()` only walks it. The recipe: a sky band (by season; snow on roofs in snow climate), a ground band
  (by cover), then the kind: hamlet 2 to 3 houses; village 4 to 5 and a chapel; town 6 to 8, a church tower; walled town the
  town behind a wall with a gate and two towers; city denser roofs, a cathedral, walls and four towers; castle a keep (one
  tower for a watchtower, keep and curtain for a castle, bastions for a fortress). Harbour 1 to 3 adds a water band on the
  right third, a quay and 1 to 3 masts. A pennant in the owner's colour flies on the tallest tower. Flat two-tone faces,
  ink outlines, token colours only. The name, kind, owner and stars sit over a dark fade at the foot of the picture. The
  same picture shows in light fog. P: a recipe that differs for the same input; a walled town without a wall; a port
  without a mast.

### 3.7 Opening, the menu, the keys

- **R30** **Opening.** A left click on a hex opens the window (as today). A right click with an own army selected is an
  order (unchanged). A right click with no army selected on an own hex opens the small menu; elsewhere it clears the
  selection (unchanged).
- **R31** **The menu** (own hexes), under the place name as its title: "Tile details..." (window on Land); "Build here..."
  (window on Buildings; shown when building is offered); "Raise companies..." (window on Army; own settlement); "Show
  supply"; "Select <army>" per own army; the war items ("Open the Battle of X", "Show the siege of X", "Show the castle
  area", unchanged); "Cancel <work>" (own work under way; the job line's Cancel). P: an item whose action does not reach
  its target (each item clicked in `test_hex_menu.gd`).
- **R32** **Keys.** Ctrl+] / Ctrl+[ cycle the live tabs (wrapping) while no screen is up; with the Study or `RaiseScreen`
  up they do not reach the window. With focus on the strip, Left and Right switch tabs. Tab stays "Next unit" when focus is
  not in the window. Esc closes the window (ladder step 4) and closes `RaiseScreen` first when it is up. O and Shift+F10
  open the menu (unchanged). U begins the first upgrade row whatever tab is open. P: Ctrl+] with the Study up; Tab with
  focus on the map.

### 3.8 Layout, style, saves, speed

- **R33** Dock, width `Tokens.PANEL_W`; picture or title bar, strip, job line and tab strip fixed; the body scrolls; never
  taller than the viewport below its top minus `Tokens.S2`. At 1280 x 720 scale 1 and 2560 x 1440 scale 2: inside the
  viewport, and the tab strip with **five** labels (the four real ones and the fixture's) fits the content width in both
  themes. P: a label long enough to overflow.
- **R34** Studiolo style, tokens only. New widgets go to `shell/ui/` with their own test: `SettlementPicture`,
  `BuildingRow`, `CompanyRow` (compact and tall forms), `StripCells`. Badges are `TableRow` labels in their tone. No
  `Color(` literal, no `theme_override_` in `.tscn`. The picture's colours are new `Tokens` art entries.
- **R35** No save change; nothing of the window is saved. `Game.digest()` unchanged; replay, save, soak and AI tests do not
  move.
- **R36** The window reads models cached per version; opening, switching and the gain fill stay within section 8.

### 3.9 The cases

| Case | Header | Strip | Job line | Tabs (live; *dimmed*) |
|---|---|---|---|---|
| Own port settlement | picture with harbour, name, stars | People, Food, Works, Ducats | work or "No work under way" | Land, Buildings, Army, Ships |
| Own inland settlement | picture | as above | as above | Land, Buildings, Army |
| Own district or wild land | title bar | as above | as above | Land, Buildings; Army live only with armies |
| Own land occupied | + "Occupied by X" | as above | the work, if any | Land, Buildings (if `at_home_check`), Army if armies |
| Foreign, light fog | picture (settlement) or title bar | People, Garrison, Buildings, Armies "fog" | the work, no Cancel | Land; *Buildings*, *Army* |
| Foreign, in sight, enemy army | + "Enemy army here" | Armies "1" | as above | Land, Army (read-only); *Buildings* |
| Siege | + "Besieged" (light) / "Besieged by X" (sight) | as the case | as the case | as the case; Land shows the meter |
| Witnessed battle site | + "Battle here, Spring 1481" | as the case | as the case | as the case; Land has "Open the battle" |
| Unowned land | "no one" | People, Garrison, Buildings, Armies | the work, if any | Land; *Buildings*, *Army* |
| Sea | "Open sea" / "Coastal sea" | none | none | Land (strip hidden) |
| Deep fog | "Unexplored", "Hex x, y" | none | none | none |
| Sandbox | title bar or picture, no owner | People, Food | work or none | Land, Buildings |

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
# shell/ui/settlement_picture.gd (new): static func recipe(picture: Dictionary) -> Array[Dictionary]; func show(picture)

# shell/panels/tile_window.gd (new) extends HexPanelContract
signal country_requested(tag: StringName)
signal works_requested(what: StringName, args: Dictionary)
signal row_hovered(hex: Vector2i, option: Dictionary)
signal row_unhovered
signal toast_requested(text: String, tone: StringName)
func show_hex(hex: Vector2i) -> void
func show_tab(id: StringName) -> void      # the menu's items
func tab_open() -> StringName
func tab_ids() -> Array[StringName]        # shown; live_tab_ids() the live ones
func next_tab(step: int) -> void           # live tabs only
func begin_option(option: Dictionary, expensive: bool) -> void

# shell/screens/raise_screen.gd (new) extends Screen
func open_for(hex: Vector2i) -> void
```

Panel signals keep their names, so `Hud` and `WarRequests` reconnect to the window as they did to the panel.

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

The approved mockups (Appendix B) are the reference for look and spacing; this sketch fixes the order of parts only.

```
OWN TOWN (Buildings)                          FOREIGN, LIGHT FOG (Land)
+----------------------------------+          +----------------------------------+
| [picture: houses, wall, pennant] |          | [picture: town]                  |
| Asti                       *** [x]          | Novara                      ** [x]
| Walled town . Republic of Genoa  |          | Town . Duchy of Milan            |
+----------------------------------+          +----------------------------------+
| 6,200  | +14  | 1 of 3 | 204     |          | 9,800  |400/400|  2   |  fog     |
| PEOPLE | FOOD | WORKS  | DUCATS  |          | PEOPLE |GARRISN|BUILDS| ARMIES   |
+----------------------------------+          +----------------------------------+
| Building: vineyard, Spring 1481 [Cancel]    | Building: weaver, ready 1482     |
+----------------------------------+          +----------------------------------+
| Land |[Buildings]| Army          |          |[Land]| Buildings | Army  (dimmed) |
+----------------------------------+          +----------------------------------+
| Make +141 a year   upkeep -14    |          | MADE HERE A YEAR                 |
| [Search...]  All|Can build|Built |          |  Wool 10 loads   Grain 9 loads   |
| SETTLEMENT                       |          | BUILDINGS   Weaver . working     |
| (v) Walled town  working.up 6 +38|          | GROUND AND DEFENCE  ...          |
| (#) City  cost 300 . you have 204|          | ARMIES  Out of sight: no armies  |
|           (red)            +88 [h]          |   are shown                      |
| LAND                             |          | [Show supply]                    |
| (#) Vineyard building 2 of 4 ==  |          +----------------------------------+
+----------------------------------+
```

---

## 7. Tests

All under `godot/tests/`. Every edited test keeps its planted faults; a task may not delete a P without replacing it.

### 7.1 New tests

| Test | Cases | Planted faults |
|---|---|---|
| `core/test_tile_view.gd` | each row of 3.9 on north Italy (Genoa, Savona port, Asti, Milan) and the sandbox; header, stars, badge order; strip cells per case; job own and foreign; dimmed reasons; `own_port` on Savona, not Asti; picture kinds | R2, R3, R10, R11, R12, R14's facts |
| `core/test_tile_buildings.gd` | groups and order; each state from a real verdict (ok, ducats, goods, slot, rule) and `state_of` for `gate`; hammer iff ok (the check/act pair over every row); built rows; gains equal the cards; summary = sum; `{}` on foreign | R9, R19, R20 |
| `core/test_tile_army.gd` | armies own and foreign by sight; raise rows; `can_raise` (n ok, n + 1 refused) on 3 towns; era badge; refusals keep words | R7, R9, R21, R22 |
| `core/test_building_card.gd`, `test_company_card.gd` | sections and lines per state; refusal in bad tone; refused card keeps cost lines | R25, R26 |
| `core/test_tile_fog.gd` | on `FogFixture.thin` and `duel_thin`: every case at each sight level; the twin test of R5 over `TileView` and `TileArmy.armies` on every hex (copy B moves unseen armies, changes owners, pieces, works, garrisons of undiscovered hexes); viewer not `game.player` | R4 to R7 |
| `core/test_tile_door.gd` | the scan of R8 | one P per forbidden name |
| `shell/test_settlement_picture.gd` | recipe per kind and harbour level; same input same recipe; walls, masts, keep present; tokens only | R29 |
| `shell/test_tile_tabs.gd` (edit) | `dimmed_for` per case of 3.9; the fake tab; the write scan of R24 | kept + a dimmed tab that opens |
| `shell/test_tile_window.gd` | frame per case; picture or title bar; strip cells; strip hidden at sea; R16 choice and fall-back; lazy build; one refresh per burst; Ctrl+] / Ctrl+[ skip dimmed tabs and the Study (R32); Esc; R33 at both sizes and themes | R15, R16, R32, R33 |
| `shell/test_buildings_tab.gd` | the works cases of `test_hex_panel.gd` moved and adapted (rows, confirm modes, reasons, U); search, filter; the gain fill (`finish_now`); hover card shows | R19's hammer P |
| `shell/test_army_tab.gd` | `test_raise_list.gd` moved; armies own and foreign; read-only on foreign; hover card; Show all opens `RaiseScreen` | R21's P |
| `shell/test_land_tab.gd` | `test_hex_panel_people.gd`, `test_hex_panel_fog.gd` and the details half of `test_hex_panel.gd` moved; battle row; out-of-sight line; sea rows | today's |
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
| `shell/test_works_preview.gd` | "left of the tile window"; the focused row loads the Buildings tab | TW16 |
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

## Appendix A. Amendments to earlier specs

| Spec | Section | Amendment |
|---|---|---|
| ui-family-audit.md | 3.1 to 3.5 | Tabs Land, Buildings, Army, Ships (D8, D6); the menu (R31); keys of R32 ("R opens the Army tab" is wrong: R is Continue march) |
| m6-build-spec.md | 6.1, 6.8 | The Raise tab is the Army tab plus `RaiseScreen`; the menu's Raise item opens the Army tab |
| m7-build-spec.md | 6.8 | The war block and battle row live in Land; the menu keeps its war items |
| ui-and-controls-spec.md | bindings | `study_tab_prev`/`next` are "Previous tab"/"Next tab" for the Study and the tile window |
| economy-rethink.md | 3.1, 3.6, 3.7 | **No Industries tab:** slot buildings are rows of the Buildings tab (a Workshops group with "n of m slots"); "opens in 1490" is a locked row (`gate`); the arms banner and "+ 1 arms" are fields of `TileArmy` and `CompanyCard` |

## Appendix B. Owner-approved mockups (2026-11-25)

| Mockup | Link | What was approved |
|---|---|---|
| Tile window tabs | https://claude.ai/artifact/DpLoAJFStBxeRYZo56csdX | The postcard, strip, job line, tabs Land / Buildings / Army / Ships, light fog and deep fog |
| Buildings rows | https://claude.ai/artifact/4uo4nSxquUcFzj3sMJLdFH | Version 1, compact rows, with the summary line, search and filter |
| Town and army UI | https://claude.ai/artifact/DQHBRjFAqxUznavurRNund | Hover cards, the small menu, the recruiting window's tall rows and arms banner (slot tiles with levels: Appendix C) |

## Appendix C. Later ideas (not in v1)

- **Building levels and workforce:** slot tiles in category rows with + / - level controls and workers bars (mockup 3,
  panel 1). Needs building levels and staffing per building in the economy design first.
- **Market bar** at the foot of the Buildings tab (surplus, price, buyers): with M10's markets.
- **Goods and Food tabs** (Buildings mockup, version 4): after M10, as files in the tab folder.
- **Pictures for districts** (vineyard, mine, woods) and seasons' light; a baked high-detail picture set.
- **Sortable table** of buildings for big cities (Buildings mockup, version 4).
