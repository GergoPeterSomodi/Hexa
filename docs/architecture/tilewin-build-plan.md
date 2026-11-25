# Tile window build plan: one uniform window per tile (issue 436)

Technical director, 2026-11-25. **Status: design approved by the owner (2026-11-25, mockups in the spec's Appendix B); the
gate (TW0) and group A (TW1 to TW3) are done; groups B to E wait for the owner's go.** Builds
`docs/architecture/tilewin-build-spec.md` ("the spec").

**When it runs.** After the fog build (on master) and before M9.5, which adds its workshops as rows of the Buildings tab
and fills the `slots`, `arms` and `gate` fields the models carry (spec D16). It changes no rule, no save and no AI. Issue
432 (moves in the month) and the battle board are not part of it; the Army rows keep a `points_text` field for 432.

**Task IDs** are `TW0` to `TW19`.

---

## 1. Groups, effort, order

S is about half a day of one worker, M a day, L two days.

| Group | Ships | Tasks | Effort |
|---|---|---|---|
| **Gate. The mockup** | **DONE:** three mockups, approved by the owner 2026-11-25 | TW0 | done |
| **A. Seams** | **DONE:** core seams moved, works rows and job line extracted, the tab registry with its generated index | TW1, TW2, TW3 | done |
| **B. Read models and the picture** | `TileView`, `TileBuildings`, `TileArmy`, the two hover cards, the settlement picture (a shell widget with a pure recipe) | TW4 to TW8 | 5 M |
| **C. Frame and tabs** | the window, Land, Buildings, Army, Ships, the fog proofs; built and tested beside the old panel | TW9 to TW13, TW15 | 4 M, 1 L, 1 S |
| **D. Swap and recruiting window** | the window replaces the hex panel; `RaiseScreen` built beside it | TW14, TW16 | 2 M |
| **E. Menu, keys, proofs, finish** | the menu's items, the tab keys, "Show all" wired, the monkey, perf rows, pictures, docs | TW17, TW18, TW19 | 2 M, 1 S |

**Remaining: 16 tasks: 13 M, 1 L, 2 S**, about 16.5 worker-days; about 6 working days end to end (each group as long as
its longest task), plus reviews and the owner's playtest.

```
owner's go
  -> B:  TW4  TW5  TW6  TW7  TW8                 (all parallel; TW8 needs only the picture contract of spec R28)
  -> C:  TW9  TW10  TW11 (L)  TW12  TW13 (S)  TW15
  -> D:  TW14  TW16                              (the fold-in checklist, spec 7.3)
  -> E:  TW17 (S)  TW18  TW19   -> the owner plays the checklist of section 5

Critical path: TW5 -> TW11 -> TW16 -> TW18 -> TW19
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

### Group B (parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| TW4 | M, Sonnet | **TileView** | new `core/views/tile_view.gd`, `tests/core/test_tile_view.gd` | Spec R1 to R4, R10, R11, R12, R14's facts and reasons, R18's `land` facts, R28's picture facts, 3.9, section 4: each case of 3.9 on north Italy (Genoa, Savona, Asti, Milan) and the sandbox with its planted faults (spec 7.1); cached by `[&"tile", version, viewer, hex]`; light (no preview, no raise check) |
| TW5 | M, Sonnet | **TileBuildings** | new `core/views/tile_buildings.gd`, `tests/core/test_tile_buildings.gd` | Spec R9, R19, R20: groups (Settlement, Land, Harbour, Defence) from `ImprovePreview.options_of` plus the built pieces; every state from a real verdict and `state_of` for `gate`; hammer iff the verdict is ok, checked against `Works.*_check` over every row of three hexes (P); `gain` equals the card's `year.gain`; summary equals the sum (P); `{}` on a foreign tile (P); `tile_buildings_ms` measured once headless, numbers in the pull request |
| TW6 | M, Sonnet | **TileArmy** | new `core/views/tile_army.gd`, `tests/core/test_tile_army.gd` | Spec R7, R9, R21, R22: armies own and foreign by `ArmyView.visible`, no foreign id (P); raise rows with era, cost text, upkeep, state and reason; `can_raise` with n ok and n + 1 refused on three towns (P); the `arms` field empty |
| TW7 | M, Sonnet | **The hover cards** | new `core/views/building_card.gd`, `core/views/company_card.gd`, `tests/core/test_building_card.gd`, `test_company_card.gd` | Spec R25, R26: sections and lines per state; the verdict line; a refusal in bad tone (P); a refused card keeps its cost lines (P); optional M9.5 sections absent |
| TW8 | M, Sonnet (art director reviews) | **The settlement picture** | new `shell/ui/settlement_picture.gd`, `tests/shell/test_settlement_picture.gd`, the picture colours in `shell/ui/tokens.gd` and both themes through `tools/build_theme.gd`, new `godot/tools/ui/picture_sheet.gd` (writes an SVG sheet of the recipe headless, to `mockups/` outside the repository) | Spec R28, R29: the seven kinds, harbour 1 to 3, the castle levels, snow roofs, the pennant; same input same recipe (P); walled town has its wall, port its masts (P); no `Color(` literal; the art director has reviewed the SVG sheet (no game window needed) |

### Group C (after B, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| TW9 | M, Sonnet | **The window frame** | new `shell/panels/tile_window.gd`, `.tscn`, `shell/ui/strip_cells.gd`, `tests/shell/test_tile_window.gd`; edit `shell/panels/tile_tabs/tile_tab.gd` (`dimmed`), `tile_tabs.gd` (`dimmed_for`), `tests/shell/test_tile_tabs.gd`, `tests/shell/fixtures/tile_tabs/fake_tab.gd` (comment only) | Spec R13 to R17, R32 (the window's part), R33, R34: picture or title bar with name, place link, stars, badges; the strip; `JobLine`; dimmed tabs with their tooltip, not clickable (P); R16's choice and fall-back (P); only the open tab has children; R33 at both sizes and themes with five labels (P) |
| TW10 | M, Sonnet | **Land tab** | new `shell/panels/tile_tabs/land_tab.gd`, `tests/shell/test_land_tab.gd` (cases of `test_hex_panel_people.gd`, `test_hex_panel_fog.gd`, the details half of `test_hex_panel.gd`, copied and adapted) | Spec R18, R24: the sections in order; the battle row asks `open_battle`; the out-of-sight line; sea and sandbox rows; the write scan over the file |
| TW11 | L, Sonnet | **Buildings tab** | new `shell/panels/tile_tabs/buildings_tab.gd`, `shell/ui/building_row.gd`, `tests/shell/test_buildings_tab.gd`, `tests/shell/test_building_row.gd`; edit `shell/panels/tile_tabs/build_rows.gd` (its click rule becomes a helper the rows call; its drawing is no longer used by the tab) | Spec R19, R20, R25 (shown): summary, search, filter, groups, compact rows in every state; the hammer through `BuildRows`' rule with `game/confirm_works` and the request names unchanged; the gain fill one row a frame with `finish_now()`; the hover card; U; the works cases of `test_hex_panel.gd` copied and green |
| TW12 | M, Sonnet | **Army tab** | new `shell/panels/tile_tabs/army_tab.gd`, `shell/ui/company_row.gd` (compact and tall forms), `tests/shell/test_army_tab.gd` (the cases of `test_raise_list.gd`, copied) | Spec R21, R26 (shown): armies here, the open arrow on own armies only (P); raise rows, hammer through `Session.act`, toasts unchanged; read-only on a foreign tile; the hover card; "Show all" emits `request(&"raise_screen", {hex})` |
| TW13 | S, Haiku | **Ships tab** | new `shell/panels/tile_tabs/ships_tab.gd`, `tests/shell/test_ships_tab.gd` | Spec R23, D5: the box on Savona; absent on Asti (P) |
| TW15 | M, Sonnet | **The fog proofs** | new `tests/core/test_tile_fog.gd`, `tests/core/test_tile_door.gd`; edit `tests/core/test_fog_exact.gd` (scan lists the new files) | Spec R4 to R8: each P of 7.1 for these files; the twin test over `TileView` and `TileArmy.armies` on every hex |

### Group D (after C, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| TW14 | M, Sonnet | **Raise companies window** | new `shell/screens/raise_screen.gd`, `tests/shell/test_raise_screen.gd` | Spec R27: tall rows from `TileArmy`, search, filter, the arms banner when present, a raise through `Session.act` (P), Esc, refresh on version; opened in its test by `open_for` (the wiring is TW17's) |
| TW16 | M, Sonnet | **The swap** | edit `shell/hud/hud.tscn`, `hud.gd` (`tile_window()`), `shell/app/war_requests.gd`, `shell/hud/hex_menu.gd` (its cast and the works path through `TileWindow.begin_option`; items unchanged), `shell/map/map_armies.gd` (if it names the panel); delete `shell/panels/hex_panel.gd`, `.tscn`, `shell/panels/raise_list.gd`, `tests/shell/test_hex_panel.gd`, `test_hex_panel_people.gd`, `test_hex_panel_fog.gd`, `test_raise_list.gd`; edit the callers of spec 7.2 | Spec done-when 2, R30, R35: the fold-in checklist (7.3) in the pull request, checked by the code reviewer; the app runs headless (`--quit`); the monkey's existing seeds green; no `HexPanel`, `hex_panel(` or `RaiseList` left in `shell/`, `tests/`, `tools/` |

### Group E (after D, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| TW17 | S, Sonnet | **Menu, keys, Show all** | edit `shell/hud/hex_menu.gd` (spec R31's items; inline works rows removed), `shell/input/bindings.gd` (labels), `shell/input/map_input.gd` (Ctrl+[ / Ctrl+] to the window when no screen is up), `shell/hud/hud.gd` (the `raise_screen` request pushes `RaiseScreen`); edit `tests/shell/test_hex_menu.gd`, the bindings and input tests | Spec R31, R32: each item reaches its target (P); Ctrl+] with the Study or `RaiseScreen` up does nothing to the window (P); Tab on the map is still Next unit (P); "Show all" opens the screen |
| TW18 | M, Haiku | **Monkey and perf rows** | new `tests/shell/monkey_tile.gd`; edit `tests/shell/test_ui_monkey.gd`, `godot/tools/perf_core.gd`, `godot/tests/perf_core_budget.json`, new `godot/tools/ui/perf_ui_tile.gd`, `godot/tests/perf_ui_budget.json`, `tools/ui/perf_ui.gd` | Spec 7.4 and 8: invariants green on 3 seeds (one thin), counters above 0; every row within limits against TW1's baseline, both tables in the pull request; a row past its limit takes the fallback of spec 8 in this task |
| TW19 | M, Haiku (art director signs) | **Pictures, goldens, docs** | new `godot/tools/ui/shot_ui_tile.gd`; the regenerated panel scenes of `shot_ui.gd`, `shot_ui_m6.gd`, `shot_ui_fog.gd`; edit `README.md` (the tile window, its tabs and keys), `godot/README.md`, `CLAUDE.md` (`HexPanel` becomes `TileWindow`), `docs/architecture/ui-and-controls-spec.md` (bindings), `docs/design/ui-family-audit.md` (status: section 3 built), `docs/design/economy-rethink.md` 3.1 (no Industries tab: a Workshops group) | Spec 7.4: **the owner is asked before the windowed run**; pictures at both scales signed against the approved mockups; changed goldens reviewed side by side; README matches spec 3.9 in plain words |

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

1. New game, Italy 1480, play as Genoa. Click Asti: the postcard shows its picture, name, stars, the strip, and opens on
   Buildings. Rows show their state; hover one for its card; a too-dear row says what you have in red.
2. Start a building with the hammer: the job line shows it on every tab; its row shows "building 1 of 4" with a bar; Cancel
   works from the job line and from the menu.
3. Ctrl+] and Ctrl+[ go through the tabs; Esc closes the window.
4. Army tab at Asti: raise a company with the hammer; hover a row for its card; the army appears under "Armies here"; its
   arrow selects it. "Show all" opens the Raise companies window; Esc closes it.
5. Click Savona: a fourth tab, Ships, says no ships yet; the picture shows the harbour.
6. Click a Milanese town far away: exact people, goods, buildings and garrison; Buildings and Army dimmed with their reason;
   "Out of sight: no armies are shown".
7. As Savoy at war with Milan, march next to a Milanese army: its tile shows "Enemy army here" and a live, read-only Army
   tab; a besieged castle out of sight shows "Besieged" and no besieger.
8. Right-click your own town: Tile details, Build here, Raise companies, Show supply, Select army, Cancel work each do
   what they say.
9. Look at TW19's signed pictures (deep fog shows on the thin test fixture).

---

## 6. Definition of done

1. The spec's done-when items 1 to 7 hold.
2. TW4 to TW19 merged; CI green with the nightly `perf_core` and `perf_ui` jobs within limits; the soak unchanged.
3. Issue 436 closed by TW19's pull request, with the approved mockups and the signed pictures linked.
4. The owner has played section 5.

---

## 7. Risks

| Risk | Where it shows | Answer |
|---|---|---|
| The swap breaks a caller nobody listed | TW16 | the grep of its done-when; the monkey's existing seeds; the checklist |
| A copied test drifts from its source | group C | the old tests stay untouched until TW16; the reviewer compares each copy |
| Gains make the Buildings tab slow | TW11, TW18 | TW5 measures first; one row a frame; the shared preview base (spec 8) |
| The picture looks crude | TW8, TW19 | the SVG sheet review before the frame uses it; the bake fallback (spec 9) |
| Dimmed tabs read as broken | playtest | the tooltip reason; absent instead is one function (`dimmed` returns, `applies` false) |
| M9.5 needs more than fields | M9.5 | its Workshops group, slot line and arms banner are already in the models and the rows; it adds a group id and fills fields |
| Windowed runs needed for pictures | TW19 | the owner's go first; TW8's sheet needs no window |
| Ctrl+[ / Ctrl+] clash with the Study and `RaiseScreen` | TW17 | keys reach the window only with no screen up (pinned) |

---

## 8. Defaults taken (none blocks the build; the owner may change any before group C)

| Default | Alternative |
|---|---|
| On land, Land, Buildings and Army always show; a tab that does not apply is dimmed with its reason (the approved mockup) | absent tabs, as the earlier draft |
| The strip is the same on every tab (four cells by case) | per-tab cells as the mockup's sketches varied |
| Before M9.5 the strip's third cell is Works (crews in use of the limit); M9.5 turns it into Slots on settlements | an empty cell until M9.5 |
| Size stars = settlement level, 1 (hamlet) to 5 (city); castles show no stars | stars from people bands |
| Pictures only on settlements and castles; other tiles get a title bar | a ground picture on every land tile |
| The menu loses its inline works rows ("Build here..." opens the Buildings tab), as the approved menu shows | keep the works rows in the menu too |
| Gains fill one row a frame after the rows appear | compute every gain before the first draw |
| Window opens on the last tab picked, else Buildings, else Land | always Land first |
| `RaiseScreen` is a non-opaque screen over the map | a second dock panel |

---

## Owner note, 2026-11-25: the settlement picture is a placeholder

The owner said to ignore the settlement picture for now: TW8's code-drawn picture stays in the window as a placeholder for
future stylised backgrounds. No more art work on it in this build (no art director pass, no new kinds); its weak points (dark
water, arrow-like masts, small hamlets and villages) are not to be fixed now. When real backgrounds arrive they replace the
`SettlementPicture` Control behind the same `TileView` picture facts, so nothing else changes.
