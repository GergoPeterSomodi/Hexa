# M2 build plan: Countries

Game designer (Opus), 2026-11-17. **Status: in progress (`C1`–`C13` merged through `956446f`; `C14`–`C20` remaining).** Builds
`docs/architecture/m2-build-spec.md` ("the spec").

**Started after M1 (`T16`) and M1.5 / M1.5b closed on `master`.** M2 edits `tile_map_view.gd`, `edge_line_layer.gd`,
`map_labels.gd` and `far_map.gd`, builds on M1's architecture and M1.5's Studiolo UI frame, and ships Countries
across Groups A–H (`C1`–`C20`). The standard's rule holds: M3 starts after M2 closes and passes the owner's playtest.

---

## 1. Slices, effort, order

S is about half a day of one worker, M a day, L two or three days.

| Slice | Ships | Tasks | Effort |
|---|---|---|---|
| **Core and data** | definitions, state, the growth rule, the systems, the home rule, the 1480 data and its CI check | C1, C2, C6, C8, C9 | 1 S, 2 M, 2 L |
| **Map drawing** | borders, the mode overlay and its shader, country names, pennants, the map scene's wiring | C3, C4, C13 | 2 M, 1 L |
| **UI** | bake slice 2, arms, Session and keys, read models, country panel, minimap, screens, HUD, the App | C5, C7, C10, C11, C14, C15, C16, C17, C19 | 8 M, 1 L |
| **Editor** | the scenario editor | C12 | 1 M |
| **Speed and pictures** | the fake scenario and perf rows; monkey, pictures, UI probe | C18, C20 | 1 S, 1 M |

20 tasks: 2 S, 14 M, 4 L, about 25 worker-days; about 14 working days end to end with the groups below (each group
takes as long as its longest task), plus reviews and the owner's playtest.

```
M1 T16 -> M1.5 (the owner's playtest)
  -> A:  C1  C2  C3  C4  C5
  -> B:  C6 (L)  C7
  -> C:  C8 (L)  C9
  -> D:  C10  C11  C12
  -> E:  C13 (L)  C14  C15  C16
  -> F:  C17  C18
  -> G:  C19 (L)
  -> H:  C20  -> the owner plays M2

Critical path: C1 -> C6 -> C8 -> C10 -> C13 -> C17 -> C19 -> C20
```

A group starts when every task of the group before it is merged. Inside a group the tasks run in parallel and no two
touch one file.

---

## 2. Tasks

Who, per the standard's section 9: *Sonnet* builds systems, tools and anything touching `Game`, `Session`, `Events`,
input or the App; *Haiku* builds panels and screens from the spec's tables, data files, and tests from a list; *Opus*
(this designer) answers design questions and reviews the data; *Fable* reviews interfaces. Generated files belong to the
task that changes their source. **Every task's done-when includes: lint (`tools/lint_godot.py godot`), check_scripts and
GUT green**, and from C5 on, `bake_ui.py --check` and `build_theme.gd --check`; from C6 on, `build_scenario.gd --check`.

### Group A (parallel)

| # | Status | Size, who | Task | Files (new unless said) | Done when |
|---|---|---|---|---|---|
| C1 | **done** (`84fc767`) | M, Sonnet | **Country definition and colour contrast** | `core/defs/country_def.gd`, `core/defs/colour_contrast.gd`; `tests/core/test_country_defs.gd`, `tests/core/test_colour_contrast.gd` | Spec 5.1 (`CountryDef`, `ColourContrast`) with the formulas of spec 4.6; `CountryDef.validate` and its planted faults (tag form, unknown division, unknown tincture); the contrast test of spec 10 |
| C2 | **done** (`72d8a09`) | S, Sonnet | **Country state and the owner layer** | `core/state/country.gd`; edit `core/state/map_state.gd`; `tests/core/test_country_state.gd`; edit `tests/core/test_map_data.gd` | Spec 5.2: `Country` round trip and `digest_text`; `MapState.owner` sized, copied, saved (schema 2), schema 1 loads with zeros, in the digest |
| C3 | **done** (`4317f42`) | M, Sonnet | **Border lines and their meshes** | `core/views/border_lines.gd`; edit `shell/mapview/edge_line_layer.gd` (kinds `border`, `border_band`), `shell/mapview/tile_map_view.gd` (`Borders` node, `BORDERS_Z`, `set_chunk_borders`, `border_chunks`); `tests/core/test_border_lines.gd`, `tests/shell/test_border_mesh.gd` | Spec 6.3 and the `BorderLines` interface of 5.7, on plain owner bytes and a palette; the two test files of spec 10; rivers and roads draw as before (M1's tests unchanged) |
| C4 | **done** (`0f94f62`) | M, Sonnet | **The mode overlay** | `core/views/map_modes.gd` (the plain-input part of spec 5.7), `shell/map/mode_overlay.gd`, `shell/map/mode_overlay.gdshader`; edit `shell/mapview/far_map.gd` (`texture()`); `godot/tools/map/probe_mode_overlay.gd`; `tests/core/test_map_modes.gd`, `tests/shell/test_mode_overlay.gd` | Spec 6.2 with `setup_from` and `set_palette_colours`; the twin against `local_to_map` on 10,000 points; the probe prints PASS for the three modes on the owner's Mac and in CI, and FAIL with `--plant`; pictures of the three modes on north Italy with a hand-made owner array in the pull request |
| C5 | **done** (`29e29d9`, `82695d0`) | M, Haiku | **UI bake slice 2** | `tools/ui_bake/pieces_m2.py`; edit `tools/bake_ui.py` (slice 2 in the catalogue), `godot/tools/build_theme.gd` (variation `PanelMinimap`, Kit icons `shield_rim`, `shield_rim_sm`, `pennant_pole`, `pennant_cloth`); re-made `godot/assets/ui/kit/` (`ui_kit.json`, `1x/`, `2x/`) and `shell/ui/theme.tres`; edit `tests/test_bake_ui.py`, `tests/shell/test_theme.gd` | `minimap_frame` (256 x 144, M 56, 16), `shield_rim` (48 x 56), `shield_rim_sm` (20 x 24), `pennant_pole` (24 x 56), `pennant_cloth` (28 x 20, white, tinted at run time) at 1x and 2x; the bake's asserts and both `--check`s pass; the art director signs the contact sheet |

### Group B (after A)

| # | Status | Size, who | Task | Files | Done when |
|---|---|---|---|---|---|
| C6 | **done** (`50971c1`) | L, Sonnet | **Scenarios, the definition list, the growth rule, the tool** | `core/defs/scenario_def.gd`, `core/defs/game_defs.gd`, `core/defs/scenario_growth.gd`, `godot/tools/build_scenario.gd`; edit `.github/workflows/godot.yml` (step "Generated scenarios are current"); `tests/core/test_scenario_defs.gd`, `tests/core/test_scenario_growth.gd`; edit `tests/core/test_country_defs.gd` (`GameDefs` cases) | Spec 4.3, 5.1, 8.2, 8.3: every rule of 8.2 has its planted fault; the growth test's fixture costs and ties; the tool writes and `--check`s (CI fails on a flipped owner byte in a scratch copy, shown in the pull request) |
| C7 | **done** (`a850304`) | M, Haiku | **Country arms** | `shell/ui/country_arms.gd`; `tests/shell/test_country_arms.gd`; edit `tests/test_bake_ui.py` (the rim contains `SHIELD`) | Spec 7.2: all 12 divisions at 48 x 56 and small; the arms sheet of the 13 countries of spec 4.7 at 1x and 2x in the pull request; the art director signs it |

### Group C (after B)

| # | Status | Size, who | Task | Files | Done when |
|---|---|---|---|---|---|
| C8 | **done** (`88fc47d`) | L, Sonnet | **Territory, Countries, the Game, the home rule** | `core/systems/territory.gd`, `core/systems/countries.gd`; edit `core/game/game.gd`, `core/game/actions.gd`, `core/systems/improve.gd`; `tests/core/scenario_fixture.gd` (a 9 x 7 map, three countries, defs and scenario built in code), `tests/core/test_territory.gd`, `tests/core/test_countries.gd`; edit `tests/core/test_improve_actions.gd` | Spec 5.3, 5.4, 5.9: every row of both verdict tables; `transfer` queues one event; the 2,000-action property with actors finds no accepted works action off the actor's land; OWNS with its planted fault; a map-only game behaves as in M1 (M1's tests unchanged); `Game.digest` covers the new fields |
| C9 | **done** (`1f652d3`) | M, Haiku (Opus reviews) | **The 1480 data** | `godot/data/defs/game_defs.tres`, `godot/data/defs/countries/{fra,aus,swi,sav,mlo,ven,gen,tus,pap,man,fer,sie,luc}.tres`, `godot/data/scenarios/north_italy_1480.tres` (seeds of spec 4.4 by hand; `owner` and `map_digest` by `build_scenario.gd`); `tests/core/test_scenario_1480.gd`; edit `tests/core/test_country_defs.gd` (every file of `data/defs/` loads), `godot/data/README.md` | Spec 4.1 to 4.7 entered exactly; the tool's printed table equals spec 4.2's districts and towns; `test_scenario_1480.gd` (counts, regions, passes, neighbours, palettes); `build_scenario.gd --check` green |

### Group D (after C)

| # | Status | Size, who | Task | Files | Done when |
|---|---|---|---|---|---|
| C10 | **done** (`a48b08e`) | M, Sonnet | **Session, Events, keys and settings** | edit `shell/autoload/session.gd`, `shell/autoload/events.gd`, `shell/app/settings.gd` (the five keys of spec 7.1), `shell/input/bindings.gd` (the M2 actions; the season keys go); edit `tests/shell/test_session.gd`, `tests/shell/test_settings.gd`, `tests/shell/test_bindings.gd` | Spec 5.5, 5.6, 7.1; `drain()` public; `new_scenario` returns its problem; still two autoloads |
| C11 | **done** (`b0d258f`) | M, Sonnet | **Read models** | edit `core/views/map_modes.gd` (`modes`, `palette`, `colour_at`), `core/views/hex_card.gd` (owner line); `core/views/country_names.gd`, `core/views/country_card.gd`, `core/views/place_search.gd`; `tests/core/test_country_names.gd`, `tests/core/test_country_card.gd`, `tests/core/test_place_search.gd`; edit `tests/core/test_hex_card.gd`, `tests/core/test_map_modes.gd` | Spec 5.7 and the tests of spec 10 for these files; no engine calls (lint) |
| C12 | **done** (`d1e29c8`) | M, Sonnet | **The scenario editor** | `shell/editor/scenario_editor.tscn`, `shell/editor/scenario_editor.gd`; `tests/shell/test_scenario_editor.gd` | Spec 8.4: opens `north_italy_1480` in the Godot editor; painting a pin moves the overlay and the border live; Write then Check gives no line; the headless test of spec 10; a short screen recording in the pull request |

### Group E (after D)

| # | Status | Size, who | Task | Files | Done when |
|---|---|---|---|---|---|
| C13 | **done** (`956446f`) | L, Sonnet | **The map scene with countries** | edit `shell/map/map_scene.gd`, `shell/map/map_scene.tscn`, `shell/map/mode_overlay.gd` (`setup(game, colour_blind)`), `shell/mapview/map_labels.gd` (capitals from the game, obstacles), `shell/input/map_input.gd` (`mode_requested`, `country_requested`, `find_place_requested`; `season_requested` goes); `shell/map/capital_marks.gd`, `shell/mapview/country_labels.gd`; edit `tests/shell/test_map_scene.gd`, `tests/shell/test_map_input.gd`, `tests/shell/test_layer_stack.gd`, `tests/shell/test_map_labels.gd`; `tests/shell/test_country_labels.gd` | Spec 6.1, 6.4, 6.5: north Italy shows borders, the three modes, names and pennants; a transfer rebuilds exactly the touched chunks and texels; the picking signals; the pictures of spec 10 for the map (both palettes) signed by the art director |
| C14 | pending | M, Haiku | **Country panel** | `shell/panels/country_panel.tscn`, `shell/panels/country_panel.gd`; `tests/shell/test_country_panel.gd` | Spec 7.4 for Genoa, Milan, France and Lucca, in and out of the pick; links and Play as emit their signals |
| C15 | pending | M, Haiku | **Minimap** | `shell/hud/minimap.tscn`, `shell/hud/minimap.gd`; `tests/shell/test_minimap.gd` | Spec 7.8 against the mockup's minimap slot (`play_m4.jpg`); click glides, drag jumps; the frame follows the view |
| C16 | pending | M, Haiku | **New game, the pick, place search** | `shell/screens/new_game.tscn/.gd`, `shell/screens/country_pick.tscn/.gd`, `shell/screens/find_place.tscn/.gd`; edit `shell/screens/screen_ids.gd`; `tests/shell/test_new_game.gd`, `tests/shell/test_country_pick.gd`, `tests/shell/test_find_place.gd` | Spec 7.5, 7.7, 7.9: each opens in the UI harness with its focus; keys as specified; the pick's `back()` never pops it |

### Group F (after E)

| # | Status | Size, who | Task | Files | Done when |
|---|---|---|---|---|---|
| C17 | pending | M, Haiku | **HUD pieces** | edit `shell/hud/hud.tscn/.gd` (dock: `show_country`, `close_dock`; minimap slot), `shell/hud/top_bar.tscn/.gd` (arms, name, mode switch, narrowing), `shell/hud/layers_popover.tscn/.gd` (three switches), `shell/hud/debug_overlay.gd` (the M2 line), `shell/panels/hex_panel.tscn/.gd` (Owner row, home reason); edit `tests/shell/test_hud.gd`, `tests/shell/test_hex_panel.gd` | Spec 7.3, 7.6, 7.10; the top bar against the mockup's M2 bar (`play_m4.jpg`); the hex panel's Owner row as the mockup |
| C18 | pending | M, Sonnet | **Speed: the fake scenario and the M2 rows** | `core/mapgen/fake_scenario.gd`, `tests/core/test_fake_scenario.gd`; edit `godot/tools/perf_map.gd` (the `--countries` pass and the rows), `godot/tests/perf_budget.json` | Spec 9: the table printed and in the job summary; every cpu and mem row within its limit in the nightly job; the gpu rows measured once on the owner's Windows machine and Mac with `--gpu-limits` and written in the pull request |

### Group G (after F)

| # | Status | Size, who | Task | Files | Done when |
|---|---|---|---|---|---|
| C19 | pending | L, Sonnet | **Wire the App** | edit `shell/app/app.gd` (spec 7.11: new game, the pick, country and dock requests, glides, toasts, the command line), `shell/screens/main_menu.tscn/.gd` (New game first), `shell/screens/pause_menu.gd` (subtitle), `godot/README.md` (layout, keys, the editor, `build_scenario`), `CLAUDE.md` (the `build_scenario.gd --check` line); edit `tests/shell/test_app_flow.gd`, `tests/shell/test_main_menu.gd`, `tests/shell/test_pause_menu.gd` | The flow test of spec 10 end to end; `-- --new-game --country=GEN` skips the pick; the sandbox still works as in M1.5 |

### Group H (after G)

| # | Status | Size, who | Task | Files | Done when |
|---|---|---|---|---|---|
| C20 | pending | S, Haiku | **Monkey, pictures, UI probe** | edit `tests/shell/test_ui_monkey.gd`, `godot/tools/ui/shot_ui.gd`, `godot/tools/ui/perf_ui.gd`, `godot/tests/perf_ui_budget.json`; the signed pictures stored as goldens (`godot/tests/goldens/m2_*.png`) | The monkey's new keys and invariants (spec 10) green on 3 seeds; the pictures of spec 10 at 1280 x 720 scale 1 and 2560 x 1440 scale 2; the minimap and the pick inside the HUD frame's 16 ms |

---

## 3. Reviews

- **The code reviewer** reads every task.
- **Fable (technical director)** reads the interfaces of C1, C2, C6, C8, C10 and C13 before they merge, and the
  overlay's shader (C4).
- **The art director** signs C5 (slice 2 sheet), C7 (the arms sheet), C4 and C13 (borders, tint, the three modes, both
  palettes, at fit and zoom 1), C15 (the minimap) and the panels' pictures of C20.
- **Opus (this designer)** walks the reviewer and the owner through the 1480 table (spec 4.4 and 4.5) before C9 starts,
  reviews C9's data against the spec, and answers design questions during the build.
- **Pull requests** say what changes for the player. C2 and C8 change `Game.digest()` (new fields): said in the
  pull request; no test pins a digest value today. C3 adds kinds to the line meshes without changing rivers and roads (the
  M1 line tests stay as they are).

---

## 4. The owner's playtest of M2

On Windows (mouse) and on the MacBook (trackpad):

1. Main menu, **New game**: the page shows "Italy, 1480" with its line; More shows the seed and Random changes it;
   Begin.
2. The map opens in Owner mode with the ribbon "Choose your country": 13 coloured countries, a dark border with a
   coloured edge on every boundary, none along the coast; names on the map; pennants on the ten capitals.
3. Move the pointer over Milan's land: all of Milan brightens and its row lights in the list. Click: Milan's panel shows
   52 districts, 20 towns, its passes, its neighbours and "Play as Milan".
4. In the list, Up, Down and Enter move and show each country without the mouse. France, Austria and the Papal States
   are under "Outside powers"; their panel's Play button is locked with "its capital, Paris, is off this map".
5. Play as Genoa: the ribbon goes, the camera glides to Genoa, a toast names your country, the top bar shows the shield
   and "Republic of Genoa", the map returns to Terrain with a light tint.
6. Select a Genoese hex: Owner: Republic of Genoa, and the works buttons; build something. Select a Milanese hex: the
   panel says "not your land: the Duchy of Milan holds it" and shows no buttons; press U on a Milanese town: the toast
   gives the same reason.
7. Press 1, 2, 3: Terrain, Owner, Relief; the top bar switch follows; in Relief the Alps are grey and white, the Po plain
   green. Click the switch: the same.
8. Layers: Borders off and on, Country tint off and on, Minimap off and on.
9. C opens Genoa's panel; click Milan in its neighbours: Milan's panel; "Show on the map" glides there in Owner mode; Esc
   closes the panel.
10. Ctrl/Cmd+F, type "ver": Verona and Vercelli; Enter glides to Verona and selects it. Again, type "mant": Mantua the
    country and the town.
11. The minimap: a click moves the view there, a drag pans; the gold frame follows when you pan the map.
12. Options, Accessibility, "Colour-blind safe country colours": tint, borders and minimap change at once; neighbours
    stay apart; turn it off again.
13. Zoom out to the whole map: country names are large and readable; zoom in to 1: country names give way to place names.
14. Esc: the pause menu's subtitle is "Republic of Genoa"; Main menu asks before leaving (you built something); New game
    again, pick Lucca: two districts, and you can build only on those.
15. Map sandbox (developer tools): no countries, no Owner button, building works anywhere as before.
16. In the Godot editor: open `shell/editor/scenario_editor.tscn`, select the Pins layer, paint Florence's colour on a
    Sienese hex: the border moves at once; press Check: nothing reported; press Write, then restore the file with git.
17. The same steps on the Mac: pinch and two-finger scroll still work; the overlay looks as on Windows.

---

## 5. Definition of done

1. The spec's "M2 is done when" items 1 to 6 hold.
2. Tasks C1 to C20 merged; CI green, with `build_scenario.gd --check`, both UI `--check`s, the probe and the nightly perf
   job.
3. The pictures of spec 10 are signed and stored as goldens.
4. The owner has played the checklist of section 4 on Windows and the Mac.
5. `godot-architecture.md` 9.2 marks M2 done; `godot/README.md` describes the M2 game.
6. Section 7 below is handed to the M3 build spec's author.

---

## 6. How to start

On the day M1.5 closes:

1. Opus presents the 1480 table (spec 4.2 to 4.5) to the owner and Fable in 20 minutes; a change is a seed line now,
   not a task later.
2. Start group A together: **C1, C2, C3, C4** (Sonnet) and **C5** (Haiku). C4 writes its shader and probe first and
   asks the owner to run the probe on the Mac within its first day (spec 11, the first two risks), so a fallback is
   chosen before anything is built on the overlay.
3. Fable reads C1 and C2's interfaces on their first day; C6 starts as soon as group A merges.

---

## 7. What M2 hands to M3

- **Save:** `MapState.owner` (schema 2), `Game.countries`, `Game.player`, the scenario's id and digest (spec 5.9);
  the round trips exist per piece; M3 adds the whole save, its header (country long name, arms tag) and the old-save
  rule.
- **Events:** `owners_changed` and `country_chosen` for the action log and the report's "What befell" and "Your orders".
- **Words:** `CountryDef.name`, `long_name`, `adjective`; the seal's initial is the short name's first letter.
- **Knowledge:** `Territory.neighbours` is "a shared border" for `Knowledge.knows` (style spec 6.5).
- **The flow:** M3's End season check refuses before a country is chosen, with the home rule's words ("choose your
  country first"); the pick screen stays the way a scenario game begins.
- **The top bar:** the date medallion and End season sit right of the mode switch.
- **Drain:** `Session.drain()` is public; the season calls it after each phase (standard 4.4).
