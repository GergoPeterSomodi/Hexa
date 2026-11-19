# UI, menus and controls: the plan

UI and game-systems designer, 2026-11-17. Builds `docs/architecture/ui-and-controls-spec.md` (the spec). **Status: M1.5 (`U1`–`U17`, `G1`, M1.5b) is implemented and merged on `master`; later-milestone UI rows (section 4) ship with M2–M12 (M2 Groups A–D + `C13` merged, `C14`–`C20` remaining).**

> **Note (2026-11-17, later the same day):** the owner approved the Studiolo look and three feedback screens. `docs/architecture/ui-style-and-feedback-plan.md` re-bases the tasks below (its slice S1 says, task by task, what changes: U4 is replaced, U7 is split, H1 and M1 are added) and adds slices S0 and S2 to S5; the spec is `docs/architecture/ui-style-and-feedback-spec.md`.

The shape: one **UI foundation slice, M1.5**, that ships now on the map-only game (the north Italy sandbox), then the
UI each later milestone adds to that frame. M1.5 is built in five groups; a group starts when the one before it is
merged.

---

## 1. M1.5: what ships now, what waits

**Ships in M1.5** (spec section in brackets):

- Input: trackpad pan and pinch, the wheel's `factor`, Ctrl+wheel, sideways wheel, drags with a slop; every key an
  InputMap action from one table; the zoom model (whole map to 2.0, smoothing, pointer or centre anchor); camera bounds;
  key pan speeds; edge pan (off by default); N wired to the place names; R moves to Ctrl/Cmd+R (4.1 to 4.4).
- The App root with the HUD out of the map scene; the screen stack; pause by the engine's tree pause (3.1, 3.2).
- One generated Theme from a token file, open-licence fonts, the kit (button with verdict, panel frame, modal frame,
  hover card, toast, option row, key cap) (3.4, 3.5).
- The HUD frame: a top bar (map name, Layers, `?`, menu), zoom control, scale bar, the map's hover card, toasts, the
  Layers popover, the F3 panel, the loading overlay, screenshot (F12) and photo mode (H) (7).
- Screens: main menu (Map sandbox, Options, Credits, Quit), sandbox page, pause menu, options (Display, Graphics,
  Controls, Map, Accessibility, Advanced, About with Copy diagnostics), confirm with the 10 s display revert, help
  overlay, credits (5, 6).
- Options now: window mode, presets, remembered place, size and screen, minimum size, vsync, frame cap, background frame
  cap, power saving, UI scale (Auto for Retina), relief shading, grid opacity, preload next season, the controls page,
  reduce motion, tooltip delay, developer tools (6.2 to 6.5).
- The settings file `user://settings.cfg`, the quit question when there are unsaved actions (6.1, 5.3).
- The texture-memory probe G1 on the Mac (6.3).

**Waits** (and why): Save, Load, Continue, autosave recovery, the action log, notifications, "what changed", camera
bookmarks, the season fade, the developer console (M3: they need time and saves); the minimap, map modes, place search,
new game with country, colour-blind palette (M2: they need countries to be worth it); chips, icons, undo (M4); the hex
right-click menu (M6); texture quality and graphics presets (after G1, group E); rebinding, audio, text size, high
contrast, hints, the event frame (M12); water animation and decor density (the map-look milestone).

---

## 2. Tasks

Sonnet-sized unless marked. A task owns its files: **no two tasks of one group touch the same file.** "Done when"
always includes lint, check_scripts and GUT green. Who: *Sonnet* builds anything that touches `Session`, `Events`,
`project.godot`, input, the camera or the App; *Haiku* builds screens from the spec's tables and tests from a list;
*Opus* (this designer) answers design questions during the build; *Fable* (technical director) reviews the interfaces.

**Group A (parallel; no dependencies between them)**

| # | Task | Files (new unless said) | Interfaces | Done when |
|---|---|---|---|---|
| U1 | **App root, a refactor only** (no behaviour change): the main scene becomes the App; the map scene's `Hud` subtree (info box, hex panel) moves into the App unchanged; the App writes the info box's text from the map scene's public getters | `shell/app/app.tscn`, `shell/app/app.gd`; edit `shell/map/map_scene.tscn`, `shell/map/map_scene.gd` (`var panel: HexPanelContract`, injected, null-safe), `project.godot` (`run/main_scene` only), `tests/shell/test_main_scene.gd`, `tests/shell/test_map_scene.gd` (injects a panel); `tests/shell/test_app.gd` | Spec 3.1 (World, Hud only) | Same keys, same look (pictures at fit and zoom 1 before and after, in the PR); the main scene is `app.tscn`; the map scene still runs alone in tests and tools |
| U2 | **Bindings, zoom model, Esc ladder** (pure) | `shell/input/bindings.gd`, `shell/input/zoom_model.gd`, `shell/input/esc_ladder.gd`; `tests/shell/test_bindings.gd`, `test_zoom_model.gd`, `test_esc_ladder.gd` | Spec 4.1 (`DEFAULTS`, `GESTURES`, `ensure()`, `apply_overrides()`, `event_text()`, `parse_event()`), 4.3 (`ZoomModel` static functions), 3.3 (the ladder) | The tests of spec 9 for these three |
| U3 | **Settings, Display, ShellContext** | `shell/app/settings.gd`, `shell/app/display.gd`, `shell/app/shell_context.gd`; `tests/shell/test_settings.gd`, `test_display.gd` | Spec 6.1 (API, `SCHEMA` with every key of 6.2 to 6.5 marked 1.5, `dev/*`, `state/help_seen`), 6.2 (`Display.apply`, pure `auto_scale`, `window_rect`, `logical_size`, `presets_for`), 3.2 (`ShellContext`) | Round trip; broken file, wrong type, unknown key, out of range give defaults; atomic write; platform defaults; the pure display helpers |
| U4 | **Tokens, Theme builder, fonts, lint rule** | `shell/ui/tokens.gd`, `tools/build_theme.gd`, `assets/fonts/cinzel/`, `alegreya/`, `alegreya_sc/`, `alegreya_sans/`, `noto/` (with the OFL texts; Studiolo: this task is replaced by K1, P3 and K5 to K8 of the new plan, which add the baked 9-slice textures); regenerate `shell/ui/theme.tres`; edit `godot/CREDITS.md`, `.github/workflows/godot.yml` (a `build_theme.gd --check` step), `tools/lint_godot.py` (no `theme_override_` in `shell/**/*.tscn`, no `Color(` literal in `shell/hud/` and `shell/screens/`; an allowlist holding today's `shell/map/map_scene.tscn`, `shell/app/app.tscn` and `shell/worldmap/`); `tests/shell/test_theme.gd` | Spec 3.4 (tokens, type scale, variations, `Hex*` aliases), project-wide theme is set in U8 | `--check` passes; every variation exists; the hex panel shows the token colours (picture in the PR: a look change, said so); the art director signs the token table and the fonts |
| G1 | **Probe: texture memory on the Mac** (changes nothing on master but the probe and a note) | `tools/probes/probe_textures.gd`; `docs/architecture/m1.5-texture-probe.md` | Spec 6.3 | The table of 6.3 **measured** (`RENDER_TEXTURE_MEM_USED` per season) on the owner's Mac and on Windows for: as is, `import_etc2_astc`, half sets (both mechanisms of 6.3), preload off; pictures of half against full at zoom 0.5 and 1; a recommendation for U17. The ASTC and half trials run in a scratch copy of the project |

**Group B (after A; parallel)**

| # | Task | Files | Interfaces | Done when |
|---|---|---|---|---|
| U5 | **Screen, ScreenStack, screen ids, UI test harness** | `shell/ui/screen.gd`, `shell/ui/screen_stack.gd`, `shell/screens/screen_ids.gd` (every id of the spec now; a missing scene fails loudly), `tests/shell/ui_harness.gd` (a 1280 x 720 `SubViewport`, `push_input`, a fake context), `tests/shell/test_screen_stack.gd` | Spec 3.2 | Push, pop, remove, replace, clear; `wants_pause`, `hides_world`; one shade under the top modal; focus given back |
| U6 | **CameraRig and MapInput on actions** (a behaviour change: input) | `shell/input/camera_rig.gd`; edit `shell/input/map_input.gd`, `shell/map/map_scene.gd`, `shell/map/map_scene.tscn` (the rig; a `Names` CanvasLayer with `MapLabels`), `shell/mapview/map_labels.gd` (its own key handler goes); `tests/shell/test_camera_rig.gd`, `test_map_input.gd`; edit `test_map_scene.gd`, `test_map_labels.gd` | Spec 3.3 (intents), 4.2 to 4.4; `MapScene.configure(settings)` applies `map/grid`, `map/grid_opacity`, `map/place_names`, `graphics/relief_shading`, `graphics/preload_next_season`, `dev/far_zoom`, `dev/slice_ms`; `MapScene.refused(reason)` signal for a refused key action | Synthetic pan, magnify, wheel with factor, Ctrl+wheel, Shift+wheel, drags inside and past the slop: the expected camera; limits and bounds hold; N shows the names; Ctrl/Cmd+R gives a new seed; R does nothing |
| U7 | **The kit** | `shell/ui/kit_button.gd`, `panel_frame.tscn/.gd`, `modal_frame.tscn/.gd`, `hover_card.tscn/.gd`, `toast_host.tscn/.gd`, `option_row.tscn/.gd`, `key_cap.gd`, `segmented.gd`; `tests/shell/test_kit.gd` | Spec 3.5 | `set_verdict` disables and shows the reason; `OptionRow` builds the right control per schema type and writes the setting; `KeyCap` follows a rebinding; a `HoverCard` lays out amounts right-aligned |
| U8 | **App lifecycle, Session and Events, the display probe** | edit `shell/app/app.gd` (load settings, `Display.apply`, `Bindings.ensure` and overrides, close request, background frame cap, power saving, `-- --sandbox [--seed=N]`), `shell/autoload/session.gd` (`unsaved_actions`, `end_game()`), `shell/autoload/events.gd` (`game_ended`), `project.godot` (stretch `canvas_items`/`expand`, `allow_hidpi`, `gui/theme/custom`, the tooltip delay, `application/run/low_processor_mode`, the custom user folder "Hexa"); `tools/ui/probe_display.gd`; `tests/shell/test_session.gd`; edit `tests/shell/test_app.gd` | Spec 3.6, 5.3 (close request), 6.1, 6.2 | The probe's PASS/FAIL list from the Mac and Windows in the PR (each FAIL with the spec's fallback applied); `unsaved_actions` counts successful acts and resets on a new game; `end_game` emits `game_ended` |
| U9 (Haiku) | **HexCard view**, and the panel's word tables moved into it (a refactor commit first, then the card) | `core/views/hex_card.gd`; `tests/core/test_hex_card.gd`; edit `shell/panels/hex_panel.gd` (reads the words from `HexCard`) | Spec 7 (hover card lines) | Every land and sea hex of north Italy gives a card with its column, row, cover, height, relief, climate and edges; no engine calls (lint) |

**Group C (after B; parallel)**

| # | Task | Files | Interfaces | Done when |
|---|---|---|---|---|
| U10 (Haiku) | **Pause menu, Confirm, Loading** | `shell/screens/pause_menu.tscn/.gd`, `confirm.tscn/.gd`, `loading.tscn/.gd`; `tests/shell/test_pause_menu.gd`, `test_confirm.gd`, `test_loading.gd` | Spec 5.2, 5.3 (with the countdown variant), 7 (loading) | Each opens in the harness with its focus set; Main menu and Quit ask only with unsaved actions; the countdown picks the timeout choice after 10 s; Esc picks the safe choice |
| U11 (Haiku) | **Options and About** | `shell/screens/options.tscn/.gd`, `about.tscn/.gd`; `tests/shell/test_options.gd`, `test_about.gd` | Spec 6.7, 5.6 | Every schema key of 1.5 has a row and every row a key; "Defaults for this page"; a display change asks to keep; Copy diagnostics puts every line of 5.6 on the clipboard |
| U12 (Haiku) | **Main menu, sandbox page, credits** | `shell/screens/main_menu.tscn/.gd`, `sandbox.tscn/.gd`, `credits.tscn/.gd`; `tests/shell/test_main_menu.gd` | Spec 5.1, 5.7 | The sandbox starts a game with the typed or random seed through `ctx.app_requested`; the sandbox button hides when developer tools are off; Quit quits without a question |
| U13 (Haiku) | **Help overlay** | `shell/screens/help_overlay.tscn/.gd`; `tests/shell/test_help_overlay.gd` | Spec 4.6 | Lists every action of `Bindings.DEFAULTS` with its live keys and the platform's gesture lines; a rebinding shows; opens once by itself (`state/help_seen`) |
| U14 | **The HUD frame** | `shell/hud/hud.tscn/.gd`, `top_bar.tscn/.gd`, `layers_popover.tscn/.gd`, `zoom_control.tscn/.gd`, `scale_bar.gd`, `map_hover.gd`, `debug_overlay.tscn/.gd`; `tests/shell/test_hud.gd`, `test_scale_bar.gd`, `test_debug_overlay.gd` | Spec 3.1 (HUD layout), 3.3 (HUD signals), 7 (top bar, zoom control, scale bar, hover card, Layers, toasts host, F3) | A click on any HUD panel never reaches the map (harness); the zoom cluster moves left of an open dock; the scale bar picks the right length; the F3 panel shows every number of spec 7 and its controls emit their intents |

**Group D (after C; one after the other)**

| # | Task | Files | Interfaces | Done when |
|---|---|---|---|---|
| U15 | **Wire the App** | edit `shell/app/app.tscn`, `shell/app/app.gd` (the HUD, the stack, the screens, intents to the rig, toasts, the 10 s revert, screenshot, photo mode, the World made and freed with the game); `shell/input/app_input.gd`; edit `shell/map/map_scene.gd` (the old info box hooks go), `tools/lint_godot.py` (the allowlist entries of U4 go), `godot/README.md` (layout, keys, gestures, the main scene); `tests/shell/test_app_flow.gd`; edit `tests/shell/test_app.gd` | The whole spec | M1.5's "done when" items 1 to 4 hold in tests: boot to the main menu, sandbox, Esc, options, back, main menu (asks), sandbox again; the Esc ladder end to end |
| U16 (Haiku) | **Monkey, UI pictures, input probe, CI** | `tests/shell/test_ui_monkey.gd`, `tools/ui/shot_ui.gd`, `tools/ui/probe_input.gd`; edit `.github/workflows/godot.yml` (a `ui-shots` job for pull requests touching `shell/app`, `shell/ui`, `shell/hud`, `shell/screens`, `shell/input`: xvfb and Mesa as the perf job, the pictures as artifacts) | Spec 9 | The monkey (3 seeds x 600 events) is green with its invariants; the pictures of spec 9 at both sizes and scales; the first frame of each screen under 16 ms on the runner; the owner's `probe_input` log is in the PR and sets `GESTURE_PAN_PX` |

**Group E (after D and G1; the owner picks from G1's note — also tracked in `godot-architecture.md` 9.2 as M1.5b)**

> Observed on Apple M2 Pro Compatibility renderer: `BPTC_RGBA not supported by hardware, converting to RGBA8` in `tileset_builder.gd` (`load_season`), confirming G1/U17 is needed to fix the macOS image compression format (ASTC via `import_etc2_astc`, or half atlases).

| # | Task | Files | Interfaces | Done when |
|---|---|---|---|---|
| U17 | **Mac image format & texture memory fix** (`BPTC_RGBA` -> ASTC or half atlases as G1 recommends): Texture quality (Full, Half) or `import_etc2_astc` reimport | ASTC: `project.godot` (`import_etc2_astc`), the reimport, a line in `godot/README.md`. Half: edit `tools/build_tileset.gd` (`--half`), `shell/mapview/tileset_builder.gd`, `assets/tiles/tiles_*_half.tres` and the half atlases, `shell/map/map_scene.gd`, `shell/app/settings.gd` (rows), `shell/screens/options.gd` (rows and presets), `tests/shell/test_tileset.gd` | Spec 6.3 | Zero `BPTC_RGBA` decompression fallback and the Mac's winter season under the 512 MB budget (live Mac probe + perf tool); the tileset check in CI covers the half sets / ASTC import; the look at zoom 1 signed by the art director |

**Merge order:** A (U1 first: it moves the main scene), B, C, D (U15, then U16), E. **Reviews:** the code reviewer
reads every task; the technical director reads U2, U5, U6, U8, U15 and U17; the art director signs U4 (tokens, fonts)
and U14 (the HUD pictures from U16). **Pull requests:** U1 and U9's first commit are refactors (no behaviour change,
pictures equal); every other task is a feature and says what changes for the player.

---

## 3. The owner's playtest of M1.5

On the MacBook (trackpad, then a mouse if there is one) and on Windows (mouse, then a touchpad if there is one):

1. The game opens on the main menu at a sensible size; the text is sharp and readable on Retina.
2. Map sandbox: the whole map shows; two-finger scroll moves the map the way the fingers go; pinch zooms about the
   fingers; a mouse wheel zooms about the pointer; `+`, `-` and the buttons zoom; F fits.
3. Zooming out stops at the whole map; zooming in stops at 2.0; the map cannot be dragged away.
4. Click selects, two-finger click clears; a drag never selects; clicking the panel or the top bar never touches the map.
5. G, N, H, U, 1-4 and Ctrl/Cmd+R do what the help says; a refused U shows why.
6. F1 lists the keys; F3 shows the numbers; F12 saves a picture and says where.
7. Esc: closes the help, then clears the selection, then opens the pause menu; the map is dimmed and still under it.
8. Options: fullscreen and back, a window preset, UI scale 150 %, each asks to keep and reverts after 10 s if ignored;
   quit and start again: everything is remembered, including the window's place.
9. Controls page: Trackpad scroll set to Zoom, Invert scroll, Smooth zoom off: each takes effect at once.
10. Quit with Cmd+Q or the window's button after a build: it asks; without a build: it does not.
11. About: Copy diagnostics, paste it into the report.
12. Leave it still for a minute: the fans stay quiet (power saving); switch to another app: the frame rate drops.

---

## 4. What each later milestone adds to the UI

Each milestone's build spec takes these rows as its UI tasks, on the M1.5 frame. M1.5 ships the components; the
screens below are built with their systems (`godot-architecture.md` 9.1 has the same list in short). The Studiolo
documents add to these rows: the season report (M3), the works card and the study's Economy page (M4), **M4.5
Insights I**, and a study page and report section with each system M5 to M12
(`ui-style-and-feedback-plan.md` S2 to S5 and the spec's section 8).

| M | UI it adds | Files (sketch) | Spec |
|---|---|---|---|
| **M2** Countries | Country arms and name in the top bar; **map modes** 1-3 (Terrain, Owner, Relief; 4 is Supply from M6) with the shader overlay and a `Segmented` group; keys 1-4 leave the season preview (it stays in the Layers popover and F3 until M3); the country panel in the dock (C); the country pick on the map with a banner and a keyboard list; the New game page (scenario 1480, country, seed); the **minimap**; **place search** (Ctrl/Cmd+F); the owner line on the hover card; borders and tint in Layers; the colour-blind palette option | `shell/map/mode_overlay.gd` + `.gdshader`, `core/views/map_modes.gd`, `shell/hud/minimap.*`, `shell/screens/new_game.*`, `shell/screens/find_place.*`, `shell/screens/country_pick.*`, `shell/panels/country_panel.*`, `shell/ui/country_arms.gd`, `shell/editor/scenario_editor.*`; the tasks are C1 to C20 of `m2-build-plan.md` | 2, 6.5, 7, 8; `m2-build-spec.md` |
| **M3** Time | Date, season and **End season** (Space, Enter) with a busy pill; the season preview leaves the Layers popover (F3 only); the "what changed" card (now the season report screen of the new spec); the **action log**, notifications and toasts from `Events`; floating ribbons; the task flag frame; the **Save and Load** screen with thumbnails; quicksave and quickload keys; the autosave option; **Continue** and Load on the main menu; **autosave recovery**; camera bookmarks; the season fade option; the developer console; the Game options page | `shell/hud/date_end.*`, `action_log.*`, `log_feed.gd`, `notifications.*`, `shell/screens/season_report.*`, `task_flag.*`, `shell/map/floaters.gd`, `shell/screens/save_load.*`; `Session.save_game/load_game/list_saves`; the tasks are Y1 to Y18 and R2 to R11 of `m3-build-plan.md` | 5.4, 5.5, 6.3, 6.6, 7; `m3-build-spec.md` |
| **M4** Economy | Resource **chips** with hover cards (click opens the ledger and the like); the icon set (from the kit bake); the **works card** (what an upgrade brings, per field and per season; U); the **ledger, as the Statesman's Study's Economy page** (L, "This season"); costs on the hex panel's buttons (the kit's cost slot); the income section; the task flag's rules; the refund of **cancel work** (the action itself arrives in M3) | `shell/hud/chips.*`, `shell/ui/resource_chip.*`, `shell/screens/works_preview.*`, `shell/screens/study.*` and `study/page_economy.*`, `shell/map/preview_marks.gd`, `core/views/reminders.gd`, `core/views/cards_economy.gd`, `core/views/improve_preview.gd`; the tasks are N1 to N12 and W1 to W12 of `m4-build-plan.md` | 2, 3.5, 7; style spec 7, 8; `m4-build-spec.md` |
| **M4.5** Insights I (new) | The chart and table kit complete (`InkChart`, `StudyTable`); Economy's Districts, Goods and History tabs; the **Rankings** and **History** pages; the **Yields** map mode (key 4) with its legend; older season headers in the log open History | `shell/ui/ink_chart.gd`, `ink_marks.gd`, `study_table.gd`, `timeline_strip.gd`, `shell/screens/study/page_rankings.*`, `page_history.*`, `economy_*_tab.*`, `shell/hud/mode_legend.*`, `shell/app/study_warm.gd`, `core/views/study_*.gd`; the tasks are I1 to I8 and Q1 to Q5 of `m4-5-build-plan.md` | style spec 8, 10; `m4-5-build-spec.md` |
| **M5** People | People and Food chips; growth ribbons; the people and food lines on the hover card; the hex panel's People section; the **Food** map mode (key 5) with its legend; the People study page, people in Rankings and the report's People section | `shell/screens/study/page_people.*`, `core/views/people_view.gd`, `cards_people.gd`, `study_people.gd`, edits to `shell/hud/chips.*`, `shell/map/mode_overlay.*`, `map_scene.gd`, `map_labels.gd`, `floaters.gd`; the tasks are P1 to P18 of `m5-build-plan.md` | 7; `m5-build-spec.md` |
| **M6** Armies | Army tokens; selecting armies; **right-click orders**; reach and path preview on the marks layer; the move card; the army panel and the raise tab; Tab and R; the hex cursor (Alt/Option+arrows); the **movement replay** and its speed option; the hex right-click menu when no army is selected; a Supply map mode; the Military study page; real witnesses in the report | `shell/map/army_tokens.gd`, `army_token.*`, `path_marks.gd`, `shell/hud/move_card.*`, `shell/panels/army_panel.*`, `raise_list.*`, `shell/map/replay.gd`, `shell/hud/hex_menu.gd`, `shell/screens/study/page_military.*`, `core/views/army_view.gd`, `move_preview.gd`, `supply_view.gd`, `replay_plan.gd`; the tasks are L1 to L25 of `m6-build-plan.md` | 4.1, 4.5, 6.6, 7; `m6-build-spec.md` |
| **M7** War | Battle and siege badges; the odds card; the **battle dock** (an overlay screen on the left, design `18` option A); the war alert (`Confirm`); Declare war (a danger button) in the country panel | `shell/map/war_marks.gd`, `shell/hud/odds_card.*`, `shell/screens/battle_dock.*`, `shell/screens/battle/*`, `shell/ui/tug_bar.gd`, `die_face.gd`, `shell/app/decision_queue.gd`, the castle-area chunk lines, `core/views/battle_view.gd`, `odds_view.gd`, `siege_view.gd`, `area_lines.gd`; the tasks are B1 to B29 of `m7-build-plan.md` | 2, 3.2; `m7-build-spec.md` |
| **M8** AI | An AI-turn pill ("Countries are moving 3 / 12") with the map limited to the camera while it runs; the AI's moves replayed | `shell/hud/busy_pill.*`, `shell/app/season_flow.gd`, `shell/input/map_input.gd` (`block_orders`), `core/views/replay_plan.gd` (`set_focus`); the tasks are K10 to K29 of `m8-build-plan.md` (the UI in K15, K16, K25 to K29) | 7; `m8-build-spec.md` |
| **M9** Diplomacy | The peace screen (modal); war goals and relations in the country panel; the Diplomacy study page; the declare-war overlay with the goal on the map; the Relations mode (key 7); the decisions for demands, white offers, requests for peace and leagues | `shell/screens/peace.*`, `peace/lot_row.*`, `declare_war.*`, `study/page_diplomacy.*`, `shell/ui/score_bar.gd`, `relation_matrix.gd`, `shell/app/decision_queue.gd`, `core/views/peace_view.gd`, `goal_view.gd`, `goal_lines.gd`, `study_diplomacy.gd`; the tasks are V1 to V33 of `m9-build-plan.md` (the UI in V16 to V21 and V24 to V30) | 3.2; `m9-build-spec.md` |
| **M10** Trade | The Trade map mode (key 8: catchments, a price lens, the route lines); the market panel (E); merchant orders (the order card, the route menu); trade route lines in Layers; the Trade study page with the price ring; the road card; the Merchants chip | `shell/panels/market_panel.*`, `shell/screens/merchant_order.*`, `shell/screens/study/page_trade.*`, `shell/map/trade_marks.gd`, `core/views/market_view.gd`, `trade_view.gd`, `trade_lines.gd`, `road_preview.gd`, `study_trade.gd`, `cards_trade.gd`; the tasks are X1 to X31 of `m10-build-plan.md` (the UI in X15 to X19 and X23 to X28) | 7, 8; `m10-build-spec.md` |
| **M11** Research | The **tech screen** (opaque, T); the idea pick (modal); the research chip opens it; the Research study page | `shell/screens/tech.*`, `shell/screens/tech/tech_node.*`, `tech_links.gd`, `tech_side.*`, `idea_card.*`, `shell/screens/idea_pick.*`, `shell/screens/study/page_research.*`, `core/views/tech_layout.gd`, `research_view.gd`, `idea_view.gd`, `cards_research.gd`, `study_research.gd`; the tasks are Z1 to Z25 of `m11-build-plan.md` (the UI in Z12, Z13, Z18 to Z22) | 2, 3.2; `m11-build-spec.md` |
| **M12** A whole game | The event pop-up frame (bankruptcy, events); the end-of-game and score screen; the **Audio** page and bus layout; the **Keys** page (rebinding); **text size** and **high contrast**; tutorial hints and the hint level; the "Ask before losing progress" switch; developer tools off by default and the sandbox hidden; final credits | `shell/screens/event.*`, `game_over.*`, `options` pages, `default_bus_layout.tres`, `tools/build_theme.gd --high-contrast` | 6.4 to 6.6, 7 |
| Map-look milestone | Decor density, water and coast animation, a 2x bake for Retina (if the owner asks), mipmaps (per G1) | the bake and the view | 6.3, 8 |

---

## 5. The owner's addendum of 2026-11-17: where each item went

| Item | Spec | In M1.5 | Later |
|---|---|---|---|
| 1. Display and windowing | 6.2 | window modes (exclusive on Windows under Advanced), resize, presets, minimum size, remembered place and size and screen, screen choice, vsync, frame cap, background cap, UI scale with Auto for Retina, the 10 s revert | |
| 2. Graphics quality | 6.3 | relief shading, grid opacity, preload next season; far-zoom point and slice budget in F3; probe G1 with the memory table | texture quality and presets (group E, after G1); season fade (M3); decor density, water animation (map-look milestone); filtering skipped (mipmaps decided by G1) |
| 3. Controls | 4.2 to 4.4, 6.4 | device preset, wheel and trackpad actions, pan and zoom speed, invert scroll, edge pan and speed, smoothing, zoom anchor; the keys file format | the rebinding page (M12) |
| 4. Accessibility | 4.5, 6.5 | reduce motion, tooltip delay, UI scale, keyboard play of every screen and toggle | colour-blind palette (M2), hex cursor (M6), text size and high contrast (M12) |
| 5. Gameplay and audio | 6.6 | the quit and leave questions (always on) | autosave, task flag (M3, M4), movement replay (M6), the confirm switch, hints, audio (M12) |
| 6. Overlays and HUD | 7 | zoom control, scale bar, hover card, Layers popover, toasts, pause dim, confirm, loading, help, screenshot, photo mode, F3 | minimap, map modes, place search (M2); bookmarks, log, notifications, "what changed", console (M3); undo as cancel work (M4); hex menu (M6), tutorial hints (M12). Villages switch and radial menu skipped |
| 7. Menus | 5 | main menu with Map sandbox, Options, Credits, Quit; pause menu; About and diagnostics with Copy | New game with country (M2); Continue, Load, Save with thumbnails, autosave recovery (M3) |
