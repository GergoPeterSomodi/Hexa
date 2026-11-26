# Tile window build plan: one uniform window per tile (issue 436)

Technical director, 2026-11-25. **Status: built 2026-11-25 except TW19 (pictures signed, goldens, README and docs). The gate
(TW0), groups A to E (TW1 to TW18) and three polish rounds added after the owner's playtest (TW20 to TW22: one fixed size,
the Town tab, the mockup v4 look) are done; a fourth round, **TW23** (design review round 3), is **in progress**; the as-built
state is section 10 of the spec.** Builds
`docs/architecture/tilewin-build-spec.md` ("the spec").

**When it runs.** After the fog build (on master) and before M9.5, which adds its workshops as a strip of the Town tab (was: rows of the Buildings tab)
and fills the `slots`, `arms` and `gate` fields the models carry (spec D16). It changes no rule, no save and no AI. Issue
432 (moves in the month) and the battle board are not part of it; the Army rows keep a `points_text` field for 432.

**Task IDs** are `TW0` to `TW23` (`TW20` to `TW22` are the polish rounds, added after TW18; `TW23` is design review round 3, in progress).

---

## 1. Groups, effort, order

S is about half a day of one worker, M a day, L two days.

| Group | Ships | Tasks | Effort |
|---|---|---|---|
| **Gate. The mockup** | **DONE:** three mockups, approved by the owner 2026-11-25 | TW0 | done |
| **A. Seams** | **DONE:** core seams moved, works rows and job line extracted, the tab registry with its generated index | TW1, TW2, TW3 | done |
| **B. Read models and the picture** | **DONE (2e1d3be):** `TileView`, `TileBuildings`, `TileArmy`, the two hover cards, the settlement picture (a shell widget with a pure recipe) | TW4 to TW8 | done |
| **C. Frame and tabs** | **DONE (ef7cbc6):** the window, Land, Buildings, Army, Ships, the fog proofs; built and tested beside the old panel (Land and Buildings became one Town tab in TW21) | TW9 to TW13, TW15 | done |
| **D. Swap and recruiting window** | **DONE (0f7827f):** the window replaces the hex panel; `RaiseScreen` built beside it | TW14, TW16 | done |
| **E. Menu, keys, proofs, finish** | TW17 and TW18 **DONE** (built and tested; in the working tree after 0f7827f, hash to add when committed); **TW19 remains:** pictures, goldens, docs | TW17, TW18, TW19 | TW19: 1 M |
| **Polish rounds** | **DONE** (same state as TW17 and TW18): one fixed size, the Town tab, the mockup v4 look | TW20, TW21, TW22 | done |
| **Polish round 3** | **IN PROGRESS:** design review round 3: findings H1 to H5, M1 to M9, L1 to L7 and the owner's decisions of 2026-11-25 (ducats chip as income, the emblem for the stars, the Ships tab's wording, 40 px tiles and a two-line plaque, collapsible facts, the picture at the window's width) | TW23 | 1 M |

**Remaining: TW19** (1 M, Haiku with the art director): about 1 worker-day, plus the owner's go for the windowed run and the
owner's playtest. **In progress: TW23** (1 M, Sonnet): design review round 3, about 1 worker-day; TW19's pictures come after it.

```
owner's go
  -> B:  TW4  TW5  TW6  TW7  TW8                 DONE (2e1d3be)
  -> C:  TW9  TW10  TW11  TW12  TW13  TW15       DONE (ef7cbc6)
  -> D:  TW14  TW16                              DONE (0f7827f)
  -> E:  TW17  TW18                              DONE (not yet committed)
         TW19                                    REMAINING  -> the owner plays the checklist of section 5
  polish: TW20  TW21  TW22                       DONE (not yet committed; after the owner's playtest of group D)
  round 3: TW23                                  IN PROGRESS (design review round 3; spec D21 to D27)
```

A group starts when every task of the group before it is merged. Inside a group no two tasks touch one file and no task
calls code another task of its group writes. Shared fixtures have one owner: `tests/shell/fixtures/tile_tabs/` TW9;
`tests/core/fog_fixture.gd` is the fog build's and is only read here. New `Tokens` entries: the picture's colours TW8, the
row widgets' none (they use existing tokens).

---

## 2. Tasks

*Sonnet* builds the core models, the window, the tabs, the screen, the swap and anything touching `Session`, `Hud` or the
input; *Haiku* builds the Ships tab, the monkey, the perf rows and the pictures. **Every task's done-when includes: lint
(`python tools/lint_godot.py godot`), check_scripts, GUT, both UI `--check`s and `build_tile_tabs.gd --check` green; no
planted fault (P) of an edited test deleted without a replacement; no game window opened without the owner's go.** Paths
without a prefix are under `godot/`; `tools/`, `docs/`, `README.md` at the repository root.

### Gate and group A (done)

| ID | Task | State |
|---|---|---|
| TW0 | **The mockup** | **DONE 2026-11-25.** Three mockups approved (spec Appendix B); the owner's choices are spec D6, D8, D13, D14, D17 |
| TW1 | **Core seams and the perf baseline** | **DONE.** `Improve.is_port`, `Military.raise_offered`, `HexCard.war_rows_for(game, viewer, hex)`; baseline numbers in its pull request |
| TW2 | **Works rows and job line out of the hex panel** | **DONE.** `BuildRows`, `JobLine` |
| TW3 | **Tab registry** | **DONE** with the index fallback (`tile_tabs_index.gd`, `tools/build_tile_tabs.gd --check`): the export probe could not run without export templates. Follow-up, not blocking: run `probe_tile_tabs.gd` on an exported build when templates are installed |

### Group B (done, commit 2e1d3be)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| TW4 | M, Sonnet | **TileView** | new `core/views/tile_view.gd`, `tests/core/test_tile_view.gd` | Spec R1 to R4, R10, R11, R12, R14's facts and reasons, R18's `land` facts, R28's picture facts, 3.9, section 4: each case of 3.9 on north Italy (Genoa, Savona, Asti, Milan) and the sandbox with its planted faults (spec 7.1); cached by `[&"tile", version, viewer, hex]`; light (no preview, no raise check) |
| TW5 | M, Sonnet | **TileBuildings** | new `core/views/tile_buildings.gd`, `tests/core/test_tile_buildings.gd` | Spec R9, R19, R20: groups (Settlement, Land, Harbour, Defence) from `ImprovePreview.options_of` plus the built pieces; every state from a real verdict and `state_of` for `gate`; hammer iff the verdict is ok, checked against `Works.*_check` over every row of three hexes (P); `gain` equals the card's `year.gain`; summary equals the sum (P); `{}` on a foreign tile (P); `tile_buildings_ms` measured once headless, numbers in the pull request |
| TW6 | M, Sonnet | **TileArmy** | new `core/views/tile_army.gd`, `tests/core/test_tile_army.gd` | Spec R7, R9, R21, R22: armies own and foreign by `ArmyView.visible`, no foreign id (P); raise rows with era, cost text, upkeep, state and reason; `can_raise` with n ok and n + 1 refused on three towns (P); the `arms` field empty |
| TW7 | M, Sonnet | **The hover cards** | new `core/views/building_card.gd`, `core/views/company_card.gd`, `tests/core/test_building_card.gd`, `test_company_card.gd` | Spec R25, R26: sections and lines per state; the verdict line; a refusal in bad tone (P); a refused card keeps its cost lines (P); optional M9.5 sections absent |
| TW8 | M, Sonnet (art director reviews) | **The settlement picture** | new `shell/ui/settlement_picture.gd`, `tests/shell/test_settlement_picture.gd`, the picture colours in `shell/ui/tokens.gd` and both themes through `tools/build_theme.gd`, new `godot/tools/ui/picture_sheet.gd` (writes an SVG sheet of the recipe headless, to `mockups/` outside the repository) | Spec R28, R29: the seven kinds, harbour 1 to 3, the castle levels, snow roofs, the pennant; same input same recipe (P); walled town has its wall, port its masts (P); no `Color(` literal; the art director has reviewed the SVG sheet (no game window needed) |

### Group C (done, commit ef7cbc6; the Land and Buildings tabs became the Town tab in TW21)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| TW9 | M, Sonnet | **The window frame** | new `shell/panels/tile_window.gd`, `.tscn`, `shell/ui/strip_cells.gd`, `tests/shell/test_tile_window.gd`; edit `shell/panels/tile_tabs/tile_tab.gd` (`dimmed`), `tile_tabs.gd` (`dimmed_for`), `tests/shell/test_tile_tabs.gd`, `tests/shell/fixtures/tile_tabs/fake_tab.gd` (comment only) | Spec R13 to R17, R32 (the window's part), R33, R34: picture or title bar with name, place link, stars, badges; the strip; `JobLine`; dimmed tabs with their tooltip, not clickable (P); R16's choice and fall-back (P); only the open tab has children; R33 at both sizes and themes with five labels (P) |
| TW10 | M, Sonnet | **Land tab** | new `shell/panels/tile_tabs/land_tab.gd`, `tests/shell/test_land_tab.gd` (cases of `test_hex_panel_people.gd`, `test_hex_panel_fog.gd`, the details half of `test_hex_panel.gd`, copied and adapted) | Spec R18, R24: the sections in order; the battle row asks `open_battle`; the out-of-sight line; sea and sandbox rows; the write scan over the file |
| TW11 | L, Sonnet | **Buildings tab** | new `shell/panels/tile_tabs/buildings_tab.gd`, `shell/ui/building_row.gd`, `tests/shell/test_buildings_tab.gd`, `tests/shell/test_building_row.gd`; edit `shell/panels/tile_tabs/build_rows.gd` (its click rule becomes a helper the rows call; its drawing is no longer used by the tab) | Spec R19, R20, R25 (shown): summary, search, filter, groups, compact rows in every state; the hammer through `BuildRows`' rule with `game/confirm_works` and the request names unchanged; the gain fill one row a frame with `finish_now()`; the hover card; U; the works cases of `test_hex_panel.gd` copied and green |
| TW12 | M, Sonnet | **Army tab** | new `shell/panels/tile_tabs/army_tab.gd`, `shell/ui/company_row.gd` (compact and tall forms), `tests/shell/test_army_tab.gd` (the cases of `test_raise_list.gd`, copied) | Spec R21, R26 (shown): armies here, the open arrow on own armies only (P); raise rows, hammer through `Session.act`, toasts unchanged; read-only on a foreign tile; the hover card; "Show all" emits `request(&"raise_screen", {hex})` |
| TW13 | S, Haiku | **Ships tab** | new `shell/panels/tile_tabs/ships_tab.gd`, `tests/shell/test_ships_tab.gd` | Spec R23, D5: the box on Savona; absent on Asti (P) |
| TW15 | M, Sonnet | **The fog proofs** | new `tests/core/test_tile_fog.gd`, `tests/core/test_tile_door.gd`; edit `tests/core/test_fog_exact.gd` (scan lists the new files) | Spec R4 to R8: each P of 7.1 for these files; the twin test over `TileView` and `TileArmy.armies` on every hex |

### Group D (done, commit 0f7827f)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| TW14 | M, Sonnet | **Raise companies window** | new `shell/screens/raise_screen.gd`, `tests/shell/test_raise_screen.gd` | Spec R27: tall rows from `TileArmy`, search, filter, the arms banner when present, a raise through `Session.act` (P), Esc, refresh on version; opened in its test by `open_for` (the wiring is TW17's) |
| TW16 | M, Sonnet | **The swap** | edit `shell/hud/hud.tscn`, `hud.gd` (`tile_window()`), `shell/app/war_requests.gd`, `shell/hud/hex_menu.gd` (its cast and the works path through `TileWindow.begin_option`; items unchanged), `shell/map/map_armies.gd` (if it names the panel); delete `shell/panels/hex_panel.gd`, `.tscn`, `shell/panels/raise_list.gd`, `tests/shell/test_hex_panel.gd`, `test_hex_panel_people.gd`, `test_hex_panel_fog.gd`, `test_raise_list.gd`; edit the callers of spec 7.2 | Spec done-when 2, R30, R35: the fold-in checklist (7.3) in the pull request, checked by the code reviewer; the app runs headless (`--quit`); the monkey's existing seeds green; no `HexPanel`, `hex_panel(` or `RaiseList` left in `shell/`, `tests/`, `tools/` |

### Group E (TW17 and TW18 done, not yet committed; TW19 remains)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| TW17 | S, Sonnet | **Menu, keys, Show all** | edit `shell/hud/hex_menu.gd` (spec R31's items; inline works rows removed), `shell/input/bindings.gd` (labels), `shell/input/map_input.gd` (Ctrl+[ / Ctrl+] to the window when no screen is up), `shell/hud/hud.gd` (the `raise_screen` request pushes `RaiseScreen`); edit `tests/shell/test_hex_menu.gd`, the bindings and input tests | Spec R31, R32: each item reaches its target (P); Ctrl+] with the Study or `RaiseScreen` up does nothing to the window (P); Tab on the map is still Next unit (P); "Show all" opens the screen |
| TW18 | M, Haiku | **Monkey and perf rows** | new `tests/shell/monkey_tile.gd`; edit `tests/shell/test_ui_monkey.gd`, `godot/tools/perf_core.gd`, `godot/tests/perf_core_budget.json`, new `godot/tools/ui/perf_ui_tile.gd`, `godot/tests/perf_ui_budget.json`, `tools/ui/perf_ui.gd` | Spec 7.4 and 8: invariants green on 3 seeds (one thin), counters above 0; every row within limits against TW1's baseline, both tables in the pull request; a row past its limit takes the fallback of spec 8 in this task |
| TW19 | M, Haiku (art director signs) | **Pictures, goldens, docs** | new `godot/tools/ui/shot_ui_tile.gd`; the regenerated panel scenes of `shot_ui.gd`, `shot_ui_m6.gd`, `shot_ui_fog.gd`; edit `README.md` (the tile window, its tabs and keys), `godot/README.md`, `CLAUDE.md` (`HexPanel` becomes `TileWindow`), `docs/architecture/ui-and-controls-spec.md` (bindings), `docs/design/ui-family-audit.md` (status: section 3 built), `docs/design/economy-rethink.md` 3.1 (no Industries tab: a Workshops group) | Spec 7.4: **the owner is asked before the windowed run**; pictures at both scales signed against the approved mockups; changed goldens reviewed side by side; README matches spec 3.9 in plain words |

**State of group E.**

- **TW17 DONE.** The menu's items open the Town tab ("Tile details..." and "Build here...") or the Army tab ("Raise companies...");
  the labels of `study_tab_prev` and `study_tab_next` say "tile window or Study" (`shell/input/bindings.gd`); the window takes
  Ctrl+[ and Ctrl+] itself (`TileWindow.handle_key`, blocked while a screen is up); "Show all" opens `RaiseScreen`.
- **TW18 DONE.** `tests/shell/monkey_tile.gd` (and its step in `test_ui_monkey.gd`), the core perf rows `tile_view_ms`,
  `tile_view_worst_ms`, `tile_army_ms` and the UI rows `tile_window_open_ms`, `tile_tab_switch_ms`, `gain_fill_frame_ms`,
  `raise_screen_open_ms` (`tools/ui/perf_ui_tile.gd`, both budget files).
- **TW19 REMAINING.** `tools/ui/shot_ui_tile.gd` is written; the rest is not done. **Done when:** the owner has been asked
  and has said go for the windowed run; the pictures are made at both scales and the art director has signed them against the
  approved mockups and the v4 look (the settlement picture shows the whole town at the window's width, not a cropped middle;
  deep fog shows on the thin fixture); the regenerated panel scenes of `shot_ui.gd`, `shot_ui_m6.gd` and `shot_ui_fog.gd` are
  reviewed side by side; `README.md` (the tile window, its tabs Town, Army and Ships, and the keys), `godot/README.md`,
  `CLAUDE.md` (`HexPanel` becomes `TileWindow`), `docs/architecture/ui-and-controls-spec.md` (bindings),
  `docs/design/ui-family-audit.md` and `docs/design/economy-rethink.md` 3.1 (no Industries tab: a Workshops group in the
  Town tab's strips) say what is built. Plain words, matching spec 3.9.

### Polish rounds (done, after the owner's playtest of group D)

| ID | Task | State |
|---|---|---|
| TW20 | **One fixed size** | **DONE.** The window is `Tokens.TILE_WINDOW_W` x `TILE_WINDOW_H` (440 x 640) on every tile and tab; header, tabs and queue pinned, the body scrolls; shrinks only on a viewport shorter than that; tests at 1280 x 720 and at 1920 x 1080 with UI scales 1, 1.25 and 1.5 (spec R33, R38) |
| TW21 | **The Town tab** | **DONE.** Land and Buildings merged into one Town tab (`town_tab.gd` with the parts `building_strips.gd` and `land_facts.gd`); the siege block on top when besieged; one wooden strip per building group with 48 px icon tiles (40 px from TW23) that wrap; the land facts ledger under them; foreign land and sea get the facts alone; `land_tab.gd`, `buildings_tab.gd` and their tests replaced by `test_town_tab.gd`, `test_town_tab_strips.gd`, `test_tile_window_strips.gd`; the menu opens the Town tab; registry now Town 10, Army 30, Ships 40 (spec R14, R18 to R20) |
| TW22 | **The mockup v4 look** | **DONE.** Header: stars at the left (replaced by an emblem on the picture in TW23), name centred, a drawn round close button, a teal sub line, round-icon chips (`StripCells`), a 150 px picture on every tile (`SettlementPicture` gains the LAND and SEA kinds) with round badge icons, "Unexplored" on deep fog; flat tabs with a gold underline; the queue as one row at the foot; Army icon cards with the season's cap said once; `TileStyle` (the flat boxes as data for `KitTheme`); every icon and number has a tooltip or hover card, walked by `test_tile_window_tips.gd` (spec R37, R39, R40) |
| TW23 | **Design review round 3** | **IN PROGRESS** (the next polish task). Fixes the findings **H1 to H5, M1 to M9 and L1 to L7** of the designer's review (each by its id in the pull request, or answered there) and builds the owner's decisions of 2026-11-25 (spec D21 to D27): the header's ducats chip shows this tile's income a year; the settlement-type emblem on the picture replaces the size stars; the Ships tab keeps its place with in-game wording; 40 px building tiles and a two-line plaque for groups with many buildings; collapsible facts sections; the picture scaled to the window's width so the whole town shows. Expected files: `shell/panels/tile_window.gd`, `shell/ui/strip_cells.gd`, `shell/ui/settlement_picture.gd`, `shell/ui/building_row.gd`, `shell/panels/tile_tabs/` (`town_tab.gd`, `building_strips.gd`, `land_facts.gd`, `ships_tab.gd`), `core/views/tile_view.gd` and their tests (the review's findings name the rest). Done when: every finding fixed or answered; spec R10, R11, R18, R19, R23, R29 as written; `test_tile_window_tips.gd` still walks every control, the emblem included; the size and scale tests of R33 and R38 green; no core rule, save or digest changes; TW19's pictures are made after it |


---

## 3. Tests that move

The full table is spec 7.2; by task:

- **Copied in group C, deleted in TW16:** `test_hex_panel.gd` (26: works to `test_buildings_tab.gd`, the rest to
  `test_land_tab.gd` and `test_tile_window.gd`), `test_hex_panel_people.gd` (12, to `test_land_tab.gd`),
  `test_hex_panel_fog.gd` (2, to `test_land_tab.gd`; also `test_tile_fog.gd`), `test_raise_list.gd` (12, to
  `test_army_tab.gd` and `test_raise_screen.gd`). While both exist, the old file tests the old panel.
- **Adapted, not copied word for word:** the works cases change their row words (compact rows: name and state line instead
  of "Build vineyard · 40 · 4 seasons"); each adapted case keeps its assertion on the verdict, the request name and the
  confirm mode. The reviewer compares each copy with its source.
- **Edited:** `test_tile_tabs.gd` and the fake tab's comment (TW9); `test_hex_menu.gd` (TW16 cast, TW17 items);
  `test_works_preview.gd`, `test_hud.gd`, `test_app.gd`, `test_app_flow*.gd`, `test_army_toasts.gd`, `monkey_m6.gd`,
  `monkey_m7.gd` (TW16, names only); `test_fog_exact.gd` (TW15).
- **Unchanged, must stay green:** `test_hex_war.gd`, every `core/` rule and AI test, `test_replay*.gd`,
  `test_save_file.gd`, `test_snapshot.gd`, `test_fog_views.gd`, the soak.

---

## 4. Monkey and performance

**Monkey (TW18).** `MonkeyTile` adds one step and its invariants to the fog monkey (spec 7.4): random hexes of each case,
tab switches by click (dimmed tabs too) and keys, row hovers, the menu's items, `RaiseScreen` open and close, a raise or a
build when a hammer allows. Counters `tile_opens`, `tile_tab_switches`, `tile_cases`, `raise_screen_opens` above 0.

**Perf.** TW1 recorded the baseline; TW5 measures `tile_buildings_ms` once so the gain fill is chosen on numbers; TW18 adds
all new rows of spec 8 and runs every row after. A row more than 5 % slower than the baseline, or past its limit, takes the
spec's fallback in TW18's pull request.

---

## 5. Reviews and the owner's playtest

- **The code reviewer** reads every task; for TW11 it checks the hammer against `Works.*_check`; for TW16 the checklist.
- **The technical director** reads TW4's and TW5's interfaces before they merge, TW15's twin test with TW4, TW16's
  checklist, TW18's perf tables.
- **The art director** reviews TW8's SVG sheet and signs TW19's pictures against the approved mockups.
- **Pull requests say what changes for the player:** TW16 replaces the hex panel with the window; TW17 changes the menu
  and adds the tab keys and "Show all"; nothing the player sees changes before TW16.

**The owner's playtest** (Windows, fresh user folder):

1. New game, Italy 1480, play as Genoa. Click Asti: the window shows its picture with the settlement emblem, the name, the chips (the last one is the tile's income a year), and opens on
   the Town tab. The strips show each building's state; hover a tile for its card; a too-dear tile has a red rim and a red line.
2. Start a building with the hammer (press its tile): the queue at the foot shows it on every tab; its tile shows a green rim
   and a bar; Cancel works from the queue and from the menu.
3. Ctrl+] and Ctrl+[ go through the tabs; Esc closes the window.
4. Army tab at Asti: raise a company with the hammer; hover a row for its card; the army appears under "Armies here"; its
   arrow selects it. "Show all" opens the Raise companies window; Esc closes it.
5. Click Savona: a third tab, Ships, says no ships yet; the picture shows the harbour.
6. Click a Milanese town far away: exact people, goods, buildings and garrison on the Town tab; Army dimmed, its reason under
   the facts and as the tab's tooltip; "Out of sight: no armies are shown".
7. As Savoy at war with Milan, march next to a Milanese army: its tile shows "Enemy army here" and a live, read-only Army
   tab; a besieged castle out of sight shows "Besieged" and no besieger, with the siege block at the top of the Town tab.
8. Right-click your own town: Tile details and Build here (the Town tab), Raise companies (the Army tab), Show supply, Select
   army, Cancel work each do what they say. The close button clears the selection.
9. Look at TW19's signed pictures (deep fog shows on the thin test fixture).
10. Fold and open a section of the facts on the Town tab; on a town with many buildings the 40 px tiles and the two-line plaques fit,
    and the picture shows the whole town at the window's width.

---

## 6. Definition of done

1. The spec's done-when items 1 to 7 hold.
2. TW4 to TW23 merged (TW4 to TW16 are, TW17, TW18 and TW20 to TW22 are built and wait for their commit, TW19 remains, TW23 is in progress); CI green with the nightly `perf_core` and `perf_ui` jobs within limits; the soak unchanged.
3. Issue 436 closed by TW19's pull request, with the approved mockups and the signed pictures linked.
4. The owner has played section 5.

---

## 7. Risks

| Risk | Where it shows | Answer |
|---|---|---|
| The swap breaks a caller nobody listed | TW16 | the grep of its done-when; the monkey's existing seeds; the checklist |
| A copied test drifts from its source | group C | the old tests stay untouched until TW16; the reviewer compares each copy |
| Gains make the Town tab's strips slow | TW11, TW18 | TW5 measures first; one row a frame; the shared preview base (spec 8) |
| The picture looks crude | TW8, TW19 | the SVG sheet review before the frame uses it; the bake fallback (spec 9) |
| Dimmed tabs read as broken | playtest | the tooltip reason; absent instead is one function (`dimmed` returns, `applies` false) |
| M9.5 needs more than fields | M9.5 | its Workshops group, slot line and arms banner are already in the models and the rows; it adds a group id and fills fields |
| Windowed runs needed for pictures | TW19 | the owner's go first; TW8's sheet needs no window |
| Ctrl+[ / Ctrl+] clash with the Study and `RaiseScreen` | TW17 | keys reach the window only with no screen up (pinned) |

---

## 8. Defaults taken (none blocks the build; the owner may change any before group C)

| Default | Alternative |
|---|---|
| On land the Town and Army tabs always show; a tab that does not apply is dimmed with its reason (the approved mockup); as built, Land and Buildings are one Town tab, so only Army is ever dimmed | absent tabs, as the earlier draft |
| The chips are the same on every tab (four cells by case) | per-tab cells as the mockup's sketches varied |
| Before M9.5 the strip's third cell is Works (crews in use of the limit); M9.5 turns it into Slots on settlements | an empty cell until M9.5 |
| A settlement-type emblem on the picture shows the size; the size stars are removed (owner, 2026-11-25; spec D22) | size stars from the settlement level, as TW22 built them |
| As built: a 150 px picture on every tile (a settlement, the bare land or the sea); the first draft gave a title bar to other tiles | a title bar and no picture off settlements |
| The menu loses its inline works rows ("Build here..." opens the Town tab), as the approved menu shows | keep the works rows in the menu too |
| Gains fill one row a frame after the rows appear | compute every gain before the first draw |
| Window opens on the last tab picked, else Town | always the first tab |
| `RaiseScreen` is a non-opaque screen over the map | a second dock panel |
| The header's ducats chip is this tile's income a year (owner, 2026-11-25; spec D21) | the viewer's treasury, as built |
| The Ships tab is kept for own ports, with in-game wording (owner, 2026-11-25; spec D23) | hide the tab until ships exist |
| Building tiles are 40 px and the plaque has two lines (owner, 2026-11-25; spec D24) | 48 px tiles and a one-line plaque, as built |
| The picture scales to the window's width so the whole town shows (owner, 2026-11-25; spec D25) | scale by the height and crop the sides, as built |
| The facts sections collapse, open by default, the state kept for the session and not saved (owner, 2026-11-25; spec D26) | always open |

---

## Owner note, 2026-11-25: the settlement picture is a placeholder

The owner said to ignore the settlement picture for now: TW8's code-drawn picture stays in the window as a placeholder for
future stylised backgrounds. No more art work on it in this build (no art director pass, no new kinds); its weak points (dark
water, arrow-like masts, small hamlets and villages) are not to be fixed now. When real backgrounds arrive they replace the
`SettlementPicture` Control behind the same `TileView` picture facts, so nothing else changes. The scale-to-width fix and the emblem of round 3 (spec D25, D22) are layout, not art work, and are built in TW23.
