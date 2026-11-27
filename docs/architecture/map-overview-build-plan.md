# Map overview build plan: the parchment map (issue 475)

Technical director, 2026-11-27. **Status: a proposal for the planner.** Builds `docs/architecture/map-overview-build-spec.md`
("the spec"), the look the owner approved on 2026-11-27. Task IDs are `PM0` to `PM7`.

---

## 1. Groups, effort, order

S is about half a day of one worker, M a day, L two days.

| Group | Ships | Tasks | Effort |
|---|---|---|---|
| **A. Room and facts** | room in `map_scene.gd`; the pure geometry and views; the Goods mode id; the tokens; the bus signal | PM0, PM1 | 1 S, 1 L |
| **B. Drawing and HUD** | the parchment node, its labels, the goods card, legend, top-bar segment and hover line | PM2, PM3, PM4 | 3 M |
| **C. Wiring** | the scene, the tile view, settings, keys | PM5 | 1 M |
| **D. Proofs and finish** | the fog proofs, perf rows, pictures, player docs | PM6, PM7 | 2 M |

**8 tasks: 1 S, 6 M, 1 L**, about 9 worker-days; about 6 working days end to end, plus reviews and the owner's playtest.

```
planner's go
  -> A:  PM0 (S, refactor alone)   PM1 (L)
  -> B:  PM2   PM3   PM4
  -> C:  PM5
  -> D:  PM6   PM7   -> the owner plays section 5

Critical path: PM1 -> PM2 -> PM5 -> PM6
```

A group starts when every task of the group before it is merged. Inside a group no two tasks touch one file and no task
calls code another task of its group writes.

---

## 2. Tasks

*Sonnet* builds the views, shaders, scene wiring, HUD and perf; *Haiku* builds the pictures and player text from a list.
**Every task's done-when includes: lint (`python tools/lint_godot.py godot`), check_scripts and GUT green, both UI
`--check`s; no planted fault (P) of an edited test is deleted without a replacement; headless runs only (the owner's rule:
no game window without asking).** Paths without a prefix are under `godot/`; `tools/`, `docs/`, `README.md` are at the
repository root.

### Group A (parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| PM0 | S, Sonnet | **Room in the map scene (refactor only)** | edit `shell/map/map_scene.gd`; new `shell/map/map_scene_modes.gd` (the mode store of spec D12) | Spec D12: `map_scene.gd` at 760 lines or fewer; no behaviour change (every existing test green, none edited); the pull request is labelled refactor and carries no other change |
| PM1 | L, Sonnet | **The parchment's facts, the Goods mode id, the tokens, the bus** | new `core/views/parchment_shape.gd`, `core/views/parchment_view.gd`; edit `core/views/map_modes.gd` (`Mode.GOODS`, `MODE_KEYS` `goods`, `legend_title`; **not** `modes()`), `shell/hud/debug_overlay.gd` (`MODE_WORDS` "Goods"), `shell/app/settings_schema.gd` (the `goods` choice of `state/map_mode` only), `shell/autoload/events.gd` (`map_parchment`); new `shell/ui/parchment_tokens.gd`; edit `tools/lint_godot.py` (`UI_STYLE_ALLOWLIST`); new `tests/core/test_parchment_shape.gd`, `test_parchment_view.gd`, `tests/shell/test_parchment_tokens.gd`; edit `tests/core/test_map_modes.gd`, `test_cards_military.gd`, `tests/shell/test_debug_overlay.gd` (the pins 6 to 7) | Spec R3, R5, R7, R8, R13, R20 to R21, R23, R26, R27, D3, D7, D9, D13, section 4: a shared corner and a shared edge middle equal from both hexes on north Italy (P: a hash of the hex instead of the point); edges of north Italy counted by kind against a hand count of one row; `owner_bytes` gives 255 on every undiscovered hex of the thin fixture (P: the raw owner); `goods_bytes` 0 for wild, settlement and castle hexes; country names angle within 55 degrees, from discovered hexes only (P: a region counted with an undiscovered hex); `towns` capitals first; `tip` "Unexplored" on an undiscovered hex (P: its place name); token contrast pairs and ramp lightness steps of R26 and R27 pinned |

### Group B (after A, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| PM2 | M, Sonnet | **The parchment node and shaders** | new `shell/map/parchment_map.gd`, `parchment_land.gdshader`, `parchment_line.gdshader`, `parchment_hatch.gdshader`, `parchment_sea.gdshader`; new `tests/shell/test_parchment_map.gd` | Spec R1 to R7, R12 to R14, R16, R18, R26, R28, D1 to D3, D5, D6, D8, D14, section 4: `alpha_at` table (fit 0.65 and 0.04; P: alpha 1 above `gone`); Goods forces 1, Relief/Yields/Food/Supply give 0; the textures hold `owner_bytes`/`goods_bytes` exactly; `set_good` sets a uniform and writes no texel; `geometry_builds` stays 1 after 24 owner changes and 8 good switches (P: a rebuild on `owners_changed`); a north Italy build at once and a sliced build on a small made-up map give equal meshes; no `Color(` outside the tokens |
| PM3 | M, Sonnet | **Names, dots and icons** | new `shell/mapview/parchment_labels.gd`; new `tests/shell/test_parchment_labels.gd` | Spec R8 to R11, R13, R27: the far and town views at `s` 20 and 50 px give the kinds of R9; capitals placed before every town; no town box overlaps another or a cover rect (P: placement without the collision check); nothing placed on an undiscovered hex of the thin fixture (P: a name from the raw places); `layout_count` unchanged over 60 frames with no view change; sizes follow `accessibility/text_size` 150 |
| PM4 | M, Sonnet | **Goods card, legend, top-bar segment, hover line, Layers row** | new `shell/hud/goods_card.gd`, `goods_card.tscn`; edit `shell/hud/mode_legend.gd`, `top_bar.gd` (and `top_bar.tscn` if a node is needed), `hud.gd`, `hud.tscn`, `map_hover.gd`, `layers_popover.gd`, `layers_popover.tscn`; new `tests/shell/test_goods_card.gd`; edit `tests/shell/test_mode_legend.gd`, `test_hud_modes.gd` | Spec R19 to R23, R25 (card focus), D10, D11, D13: one button per good with its tooltip (P: a button without one); picking writes `state/map_good`; the selected state is not colour alone; the legend's rows and count for Grain on north Italy; the Return button sends Terrain and hides in Terrain; the top bar fits at 1280 x 720 with seven segments (its width test); `MapHover` shows the one-line card after `map_parchment(true)` and the hex card after `false`; kit frames only (no new `StyleBox`, no `Color(`) |

### Group C (after B)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| PM5 | M, Sonnet | **Wiring, settings, keys** | edit `shell/map/map_scene.gd`, `map_scene.tscn` (`Parchment` after `Overlay`, `Names/ParchmentLabels` after `Labels`), `shell/map/map_scene_modes.gd` (the good's store), `core/views/map_modes.gd` (`modes()` offers GOODS with a player), `shell/mapview/tile_map_view.gd` (`set_ground_shown`, `set_lines_alpha`), `shell/app/settings_schema.gd` (`state/map_good`, `map/parchment`), `shell/input/bindings.gd` (`view_mode_7`, `map_good_prev`, `map_good_next`), `shell/input/map_input.gd`; new `tests/shell/test_map_scene_parchment.gd`; edit `tests/shell/test_map_scene.gd`, `test_settings.gd`, `test_bindings.gd`, `test_map_input.gd`, `tests/core/test_map_modes.gd`, and any test that frames the whole map in Terrain or Owner and reads tiles (it sets `map/parchment` off, with a comment line) | Spec R16 to R18, R22, R24, R25, R29, D2, D4, D5, D13: at north Italy's fit the tiles' ground is hidden, reach and marks shown, `CapitalMarks` and `FarMap` hidden, `CountryLabels` alpha 0; in the band the lines fade; `map_parchment` sent once a change (P: every frame); `map/parchment` off keeps tiles in Terrain and the parchment in Goods; the pick shows no parchment; Goods and Wine come back after a settings reload; 7, [ and ] work; `map_scene.gd` under 800 lines |

### Group D (after C, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| PM6 | M, Sonnet | **Fog proofs and perf rows** | new `tests/core/test_parchment_fog.gd`; edit `tests/shell/monkey_fog.gd` (the parchment invariant); new `tools/perf_parchment.gd`; edit `tools/perf_map.gd` (one call), `tests/perf_budget.json` (the rows of section 4) | Spec R12 to R15, done-when 2 and 3: on the thin fixture every `ParchmentView` output and `ParchmentLabels.placed()` shows nothing of an undiscovered hex in Terrain, Owner and Goods, and owners and goods exact on light fog (P: a border between a discovered and an undiscovered hex; P: a goods count with an undiscovered district); the monkey's fog seed counts parchment checks above 0; `perf_map.gd --dry-run` (headless) gives the CPU rows within limits on the made-up Europe and north Italy, both tables in the pull request; the frame rows from the nightly CI run |
| PM7 | M, Haiku (art director signs) | **Pictures, goldens, player docs** | new `tools/ui/shot_ui_parchment.gd`; edit `tools/ui/shot_ui.gd` (the hook; the older scenes that frame the whole map set `map/parchment` off so their goldens hold); new goldens `tests/goldens/pm_*.png`; edit `README.md` (the parchment, Goods mode, keys 7, [ and ]), `godot/README.md` (the map's layer list) | The pictures of section 3, made by the CI golden job (or a windowed run only on the owner's go), signed by the art director next to the approved mockup; no older golden changed; README words match spec R7, R16, R24, R25 |

---

## 3. Tests and pictures

- **New:** `test_parchment_shape.gd`, `test_parchment_view.gd`, `test_parchment_fog.gd` (core, headless, fast);
  `test_parchment_tokens.gd`, `test_parchment_map.gd`, `test_parchment_labels.gd`, `test_goods_card.gd`,
  `test_map_scene_parchment.gd` (shell). Every fog case runs on `FogFixture.thin` (north Italy has no deep fog).
- **Pins that move:** the mode count 6 to 7 (`test_map_modes.gd`, `test_cards_military.gd`, `test_debug_overlay.gd`,
  `test_hud_modes.gd`); `test_settings.gd` and `test_bindings.gd` for the new keys.
- **Unchanged, must stay green:** the far map, overlay, border, country label and fog tests; every golden made before this
  build.
- **Pictures** (`pm_*`, 1x and 2x, Genoa on seed 1480): `pm_fit_terrain`, `pm_fit_owner`, `pm_fit_owner_colour_blind`,
  `pm_band` (the fade, half way), `pm_goods_wine` (card and legend), `pm_goods_close` (Goods at zoom 1), `pm_hover`
  (the one-line card), `pm_fog_thin` (the thin fixture: unknown paper, no names there), `pm_high_contrast`,
  `pm_text_150`, `pm_army_over` (a selected army's reach and path over the parchment).

---

## 4. Performance rows (`tests/perf_budget.json`, read by `tools/perf_map.gd`)

| Row | Class | Limit | What |
|---|---|---|---|
| `parchment_build_ms` | cpu | 1500 | made-up Europe (494 x 247): `ParchmentShape` and the chunk meshes, total CPU of the 5 ms slices |
| `parchment_build_ni_ms` | cpu | 20 | north Italy: the same, at once |
| `parchment_slice_worst_ms` | cpu | 16 | worst frame while the made-up Europe builds |
| `parchment_goods_bytes_ms` | cpu | 80 | `ParchmentView.goods_bytes` for the whole made-up Europe, cold |
| `parchment_good_switch_ms` | cpu | 2 | `set_good` plus legend and icon layout to the next frame, worst of 8 |
| `parchment_owner_change_ms` | cpu | 16 | a 1-hex transfer with the parchment solid: texel, `owner_bytes`, names laid out; worst of 24 |
| `parchment_labels_ms` | cpu | 4 | `ParchmentLabels.relayout` for one view change at zoom 0.30, 1920 x 1080, worst (north Italy at fit: 1) |
| `parchment_frame_worst_ms` | gpu | 16 | panning at zooms 0.36, 0.28, 0.12, 0.05 in Terrain, Owner and Goods, 60 countries, 1920 x 1080 |
| `parchment_frame_mean_ms` | gpu | 8 | the mean of the same |
| `parchment_band_frame_worst_ms` | gpu | 16 | in the fade band (tiles and parchment both drawn), zoom 0.32 |
| `parchment_mem_mb` | mem | 80 | meshes and textures on the made-up Europe |

Amendment (2026-11-27): `parchment_mem_mb` is raised from 32 to 80 (measured 62 MB on the made-up Europe, accepted).

The made-up Europe is larger than any planned map, so a pass there covers the real Europe. The old rows
(`owner_frame_*`, `mode_switch_ms`, `owner_change_frame_ms`, `owner_change_200_ms`) must not get worse by more than 5 %.
A failing frame row is fixed by spec D14's fallbacks in PM6's pull request.

---

## 5. Reviews and the owner's playtest

- **The code reviewer** reads every task. **The technical director** reads PM1's interfaces and PM2's shaders before they
  merge, and PM0 as a pure refactor. **The art director** signs PM2's first picture (a debug shot from the CI artifact)
  before group C, and PM7's pictures.

**The owner's playtest** (Windows, fresh user folder, the build from CI):

1. New game, seed 1480, play as Genoa. Zoom out to the whole map: the parchment fades in (sand sea, hatched coast, dashed
   borders, country names along their shapes, towns and names). The top bar, panels and buttons are the usual walnut and gold.
2. Zoom in two notches: the tiles are back, with no second set of borders left over.
3. Press 2 (Owner) at the whole-map view: countries tinted. Turn on colour-blind country colours: the tints change.
4. Press 7 (Goods): the goods card sits bottom left. Pick Wine: wine districts shaded by stage, an icon with pips on each, the
   legend with its count. [ and ] step through the goods. Hover a district: "place · owner · Wine, second stage".
5. In Goods mode zoom all the way in: still the parchment. Press "Return to default map" (or 1): Terrain tiles.
6. At the whole-map view select an army: its token, reach and path show over the parchment; give a move order.
7. Relief, Yields, Food, Supply (3 to 6): no parchment at any zoom.
8. Options, Map: turn off "Parchment map when zoomed out": the whole-map view shows tiles; Goods mode still shows the parchment.
9. Quit and Continue: Goods mode and Wine come back.
10. Text size 150 % and high contrast: names larger, coast thicker.
11. Look at the signed `pm_fog_thin` picture (deep fog comes into play with the Europe map).

---

## 6. Risks

| Risk | Where it shows | Answer |
|---|---|---|
| Large meshes on the made-up Europe (about 1.6 million vertices at the far view) | `parchment_frame_*` | spec D14's fallbacks; chunks off screen are culled |
| Old tests and goldens frame the whole map and now get parchment | PM5, PM7 | they set `map/parchment` off, each with a comment line; no older golden may change |
| Seven top-bar segments overflow a small window | PM4 | the compact steps re-measured; the width test at 1280 x 720 |
| A fog leak through a shader | PM2, PM6 | the bytes are masked in core (spec D3) and tested headless; shaders get no raw owner |
| Cracks between wobbled hexes | PM1 | shared points hashed by position, pinned by a test |
| `map_scene.gd` and `app.gd` at 800 lines | PM0, PM4, PM5 | PM0 makes room; the HUD talks through a setting and the bus, so `app.gd` is untouched |
| Pictures and frame rows need a window | PM6, PM7 | CI makes them (xvfb); a local windowed run only on the owner's go |

---

## 7. Defaults taken (say so in the pull requests)

1. The fade band and the detail steps of spec D2 and R9.
2. Goods mode is a map of one **good** (the economy's `good_of`, 16 Kit icons), not of a family; the stage words are the
   game's ("First stage" and so on) rather than the mockup's "Level 1".
3. The Owner mode keeps its name "Owner" (the mockup's "Countries"); no country legend (the names are on the map).
4. Occupation is not drawn on the parchment (the owner's colour only, as the far picture); war marks still show sieges above it.
5. The parchment does not change with the season; the minimap is unchanged.
6. The Return button goes to Terrain; it is hidden in Terrain and during the pick. No parchment during the pick.
7. Goods mode is offered where Yields is (a country game with a player). The save file does not change.

---

## 8. Owner answers (2026-11-27: both recommendations accepted; nothing open)

1. **The "soon" modes.** Only Population and Unrest, as greyed "soon" rows at the foot of the goods card (the Food mode already
   exists on key 5).
2. **North Italy's whole-map view.** With the fade band of spec D2 the whole-map view (and the zoom-out limit) is the parchment;
   the tiles return two wheel notches in.

