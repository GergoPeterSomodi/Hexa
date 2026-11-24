# UI, menus and controls: the spec (M1.5 to M12)

UI and game-systems designer, 2026-11-17. **Status: a proposal for the owner. Nothing here is built before the owner's go.**
It builds on the standard (`docs/architecture/godot-architecture.md`) and the M1 build spec
(`docs/architecture/m1-build-spec.md`). Where this page is more exact it wins for the UI; section 1 lists every place
where it refines them. The tasks, groups and merge order are in `docs/architecture/ui-and-controls-plan.md`.

> **Note (2026-11-17, later the same day):** the owner approved the Studiolo look and three feedback screens. The look, the kit additions and the feedback screens are specified in `docs/architecture/ui-style-and-feedback-spec.md` (its section 2 lists every change to this page) and planned in `docs/architecture/ui-style-and-feedback-plan.md`; where the two disagree, that spec wins.

**Why.** The owner opened the M1 build (north Italy) on his MacBook (Apple M2 Pro, Godot 4.7.2, Compatibility renderer)
and found no usable zoom, no UI chrome and no menus: a map you can click on. This page says what the menus, controls,
options and overlays are, the Godot way, using the frozen Python game (v0.2.2) as the feature reference, and stages them:
what ships now on the map-only game (**M1.5, the UI foundation**) and what each later milestone adds.

**M1.5 is done when:**

1. On the owner's MacBook a two-finger scroll pans and a pinch zooms about the fingers; a mouse wheel, `+`/`-` and the
   on-screen buttons zoom. On Windows the wheel, Ctrl+wheel (a touchpad pinch) and drags work. Zoom stops at the whole
   map and at 2.0, and the map cannot be pushed off the screen.
2. The game starts on a main menu. **Map sandbox** opens today's map. Esc opens a pause menu that dims and pauses the
   map. Options (Display, Graphics, Controls, Map, Accessibility, Advanced, About) apply at once and are kept in
   `user://settings.cfg`. A change of window mode, size, screen or UI scale asks "Keep these settings?" and reverts
   after 10 s.
3. F1 (or `?`) shows every key, read from the InputMap. F3 shows frame time, draw calls, memory and chunk counts, and
   holds the season preview and the new seed.
4. One Theme, generated from one token file, with open-licence fonts. No `theme_override_*` in shell scenes (lint).
5. Lint, import, check_scripts and GUT are green with the tests of section 9. The windowed UI probe makes its pictures.
   The owner plays the build on the Mac and on Windows (the checklist is in the plan).

---

## 0. What is there today (read in the code, master `d28e5e8`)

| Finding | Where | What it means |
|---|---|---|
| Zoom reads only `MOUSE_BUTTON_WHEEL_UP/DOWN`. No `InputEventPanGesture`, no `InputEventMagnifyGesture`, and the wheel's `factor` is ignored | `shell/input/map_input.gd` `_on_button` | On a Mac trackpad, two-finger scroll and pinch arrive as gestures and do nothing. This is the owner's "no usable zoom" |
| Zoom 0.03 to 4.0, x1.15 a notch, about the pointer, no smoothing | `map_input.gd` `ZOOM_MIN/MAX/STEP`, `zoom_about` | At 0.03 north Italy is a 67 px stamp. At 4.0 the 1x art is upsampled four times |
| No camera bounds | `map_input.gd`, `map_scene.gd` | The map can be dragged off the screen and lost |
| Keys are hard-coded `KEY_*` constants. No InputMap actions. WASD and the arrows are read with `is_physical_key_pressed` | `map_input.gd` `_on_key`, `_process` | Nothing can be rebound. The help line is a hand-written string (`map_scene.gd` `HELP`) |
| Keys: 1-4 season, R new seed, G grid, F whole map, H HUD, U upgrade, Esc or a right click clears the selection; any button drags; WASD or arrows pan | `map_input.gd` | **V is not handled**: the M1 spec (section 8) dropped it, but `godot/README.md` still lists it |
| N toggles the place names inside `MapLabels` itself (`_unhandled_key_input`), and `MapLabels` is **not in `map_scene.tscn`** | `shell/mapview/map_labels.gd` | N does nothing in the game, and it is a second input path beside the controller |
| The HUD (title, stats, help line, hex panel) is a `CanvasLayer` inside `MapScene` | `shell/map/map_scene.tscn` | The map scene owns the UI. There is no place for menus or screens |
| The Theme is set on the hex panel only (`gui/theme/custom` is unset). `map_scene.tscn` uses `theme_override_font_sizes` and a `LabelSettings` | `shell/panels/hex_panel.tscn`, `map_scene.tscn` | Two looks. The panel's gold (`#E0BD75`) is not the kit's (`GOLD`, section 3.4) |
| `upgrade_selected()` returns the verdict, but nothing shows a refusal | `shell/map/map_scene.gd` | A refused U is silent |
| No stretch mode, no minimum window size, nothing about HiDPI; a 1280 x 720 resizable window | `godot/project.godot` | How a Retina screen sizes the window and the text is left to chance |
| Tiles are imported VRAM-compressed (BPTC, high quality), without mipmaps: 76.1 Mpx a set | `assets/tiles/*/*.png.import` | On the Mac, BPTC becomes RGBA8, four times larger (section 6.3) |
| The next season is requested on a thread right after a swap begins | `map_scene.gd` `set_season`, `_request_next_season` | Two seasons stay in video memory in the steady state |
| `godot/README.md` names `shell/worldmap/north_italy_map.tscn` as the main scene; `project.godot` runs `shell/map/map_scene.tscn` | | A stale doc, fixed in task U15 |

---

## 1. Refinements of the standard and of the M1 spec (decided here)

| Standard / M1 spec | This spec | Why |
|---|---|---|
| Standard 9: menus, options and sound in M12; top bar and ledger in M4; save and load in M3 | A **UI foundation slice, M1.5**, between M1 and M2: controls, Theme and kit, the HUD frame, the screen stack, main, pause, options, help and debug. M3, M4 and M12 add their pages to this frame | The owner cannot use today's build, and every later milestone needs the frame. Building it once avoids rework |
| Standard 4.5: "one input controller turns mouse and keys into intents" | Three small nodes in `shell/input/` share **one bindings table**: `AppInput` (app actions and the Esc ladder; runs under pause), `MapInput` (map actions to intents), `CameraRig` (the only thing that moves the camera) | The contexts differ (app keys must work under pause, map keys must not). Each node stays small and testable |
| Standard 4.5: the kit is "button, panel, row, tooltip, modal" | Adds `Screen`/`ScreenStack`, toast, hover card, option row and key cap. **The Theme is generated** from `shell/ui/tokens.gd` by `tools/build_theme.gd`, and CI checks it is current (as for the tileset and the map) | Tokens live in one place. Nobody hand-edits StyleBoxes that drift apart |
| Standard 4.4: two autoloads | Unchanged. The settings are an object the App owns and hands down (no third autoload). `Session` gains `end_game()` and `unsaved_actions`; `Events` gains `game_ended` | Keeps the autoload rule |
| Godot's usual place for InputMap defaults is `project.godot` | The actions are registered at start from one GDScript table, `Bindings.DEFAULTS`, then the overrides of `settings.cfg` are applied | One reviewable table that the help overlay and the tests read; "reset to defaults" is a reinstall. `Bindings.ensure()` makes them exist in tests and tools too |
| Standard 3.2, layer 9 (names) | `MapLabels` lives in the World under a `CanvasLayer` (layer 5, under the HUD). Its N key moves to `MapInput` | One input path |
| M1 spec 7: the far picture below zoom 0.20 | Thresholds unchanged. The **minimum zoom becomes "the whole map"** (fit x 0.9). North Italy never reaches the far picture (its minimum is about 0.40 at 1280 x 720); the made-up and the real Europe do (minimum about 0.022) | The far picture is for big maps |
| M1 spec 8: keys 1-4 season, R new seed; zoom up to 4.0 | 1-4 stay the season preview in M1.5 and become the map modes in M2 (as in Python); the preview stays in the Layers popover and the F3 panel until M3, then F3 only (section 8). R (new seed) moves to Ctrl/Cmd+R in M1.5, freeing R for "continue march" (M6). Zoom stops at 2.0 | Frees keys for their Python meanings; 1x art past 2x is only blur |
| Python stored options as JSON in `~/.hexa` | `ConfigFile` in `user://settings.cfg`, with a custom user folder named "Hexa" | The Godot way; the Python game is frozen and its options are not carried over |

---

## 2. The Python UI, feature by feature

Verdicts: **keep** (same behaviour, Godot means), **improve** (same purpose, done better), **Godot way** (Python's rule is
replaced by something the engine does), **defer**, **drop**. "M" is the milestone it lands in.

| Python v0.2.2 | Where | Godot | Verdict | M |
|---|---|---|---|---|
| Start menu: mode and map choice, Start, Continue (latest save with country and date), Credits, an error line, Enter starts, Esc quits | `hexa/menu.py` | `MainMenu` screen. No mode choice (one game). **Map sandbox** now; New game from M2/M3; Continue and Load from M3; Credits now. Esc does nothing on the main menu (no accidental quit) | improve | 1.5 |
| Pause menu: Resume, Save, Load, Options, Main menu, Exit; Yes/No question before losing progress | `screens/gamemenu.py` `PauseMenu` | `PauseMenu` screen; each page is its own screen on the stack; the question is a `Confirm` screen | Godot way | 1.5 (Save/Load M3) |
| Save and Load pages: 8 slots, quicksave, autosave, "click again to overwrite" | `gamemenu.py`, `saves.py` | `SaveLoad` screen with thumbnails and metadata; overwrite and load-over-progress go through `Confirm` (keyboard friendly) | improve | 3 |
| Options page: 8 options, each cycled by a click | `gamemenu.py` `OPTION_TEXT`, `hexa/settings.py` | `Options` screen with pages and real controls (drop-downs, switches, sliders) | improve | 1.5, then 3, 6, 12 |
| F5 quicksave, F9 quickload (press twice), F11 fullscreen | `app.py` `handle` | Kept, plus Mac-friendly chords (Cmd+S, Cmd+L, Ctrl+Cmd+F) because F-keys need Fn on a MacBook | keep | 1.5 (F11), 3 |
| Toast line | `app.toast` | `ToastHost` in the HUD | keep | 1.5 |
| Hover cards and one-line tips | `ui/kit.py` `hover_card`, `tip`; `panels/cards.py` | Controls: `_make_custom_tooltip` returns a `HoverCard`. The map: a `MapHover` card after the tooltip delay. Card content comes from pure functions in `core/views` | keep | 1.5 (hex), each M adds cards |
| Top bar: resource chips with change and card, date, map modes, Menu, End season; drops items as the window narrows (`plan()`) | `hud/topbar.py`, design `02` option A | `TopBar`: the frame in 1.5 (map name, Layers, Help, Menu); country in M2; date and End season in M3; chips in M4. Narrowing: an `HBoxContainer` whose items have a priority and hide in order | keep | 1.5 frame |
| Task flag under End season, its list, the "Task flag" option | `hud/tasks.py`, `reminders.py` | `TaskFlag` in the HUD; the rules in `core/views/reminders.gd` | keep | 3 frame, 4 rules |
| Action log: collapsible, filters, season groups, links that glide the camera | `hud/actionlog.py`, `feed.py` | `ActionLog` fed by `Events`; a link calls `CameraRig.look_at` | keep | 3 |
| Floating ribbons rising from hexes | `hud/floating.py` | `Floaters`, scenes in world space above the map | keep | 3 (timed with movement in 6) |
| Battle and siege badges, odds card, move card | `hud/battles.py`, `sieges.py`, `odds.py`, `movecard.py` | World-space marks; cards via `MapHover` | keep | 6, 7 |
| Battle panel (a centred window) | `screens/battle.py`; design `18` option A | A docked overlay screen on the left (design section 9, option A) | improve | 7 |
| Tech screen and idea modal | `screens/techscreen.py`, `techlayout.py`, `techdraw.py` | An opaque `Tech` screen; the idea pick is a modal screen | keep | 11 |
| Side panels: province, unit, country, market, raise, ledger | `campaign/panels/` | Province is today's hex panel (M1). Unit and raise M6, country M2, ledger M4, market M10 | keep | per M |
| War alert ("War on you!") | `app.py` via `pause.ask` | `Confirm` screen with "Show <country>" | keep | 7 |
| Minimap: 1 px a hex, click to jump | `app.py` `draw_minimap` | `Minimap` drawing the far picture's texture (no extra memory), viewport frame, click and drag to jump | keep | 2 |
| Map modes on 1-4 (political, terrain, goods, markets) | `app.py`, `mapview.MODES` | `view_mode_1..4` actions and a segmented toggle; modes drawn by a data-texture overlay (section 8) | keep | 2 (owner, relief), 4.5 (yields), 5 (food), 10 (trade) |
| Six fixed zooms (hex radius 3 to 34), wheel and `+`/`-`, anchored at the mouse | `mapview.ZOOMS`, `app.zoom` | Continuous zoom with smoothing, limits from the map's size, gestures (section 4.3) | improve | 1.5 |
| Pan: WASD, arrows, right or middle drag; clamp 200 px past the edge; scroll speed option | `app.scroll`, `app.clamp` | Same inputs plus left drag and trackpad; bounds keep the camera's centre on the map (section 4.4) | improve | 1.5 |
| G grid, the pass-names option | `gamemenu.toggle_grid` | G grid, N place names, a grid opacity slider | keep | 1.5 |
| Movement replay and its speed option | `replay.py` | Replay of `Events.unit_moved` | keep | 6 |
| Fullscreen toggle, window presets, minimum 1024 x 600 | `campaign/display.py` | `Display`: window modes, remembered size, position and screen, presets, minimum size, UI scale (section 6.2) | improve | 1.5 |
| Options in `~/.hexa/settings.json` | `hexa/settings.py` | `user://settings.cfg` (ConfigFile), validated against a schema | Godot way | 1.5 |
| Esc: deselect first, then the menu; M opens the menu | `app.handle` | The Esc ladder (section 3.3); M kept | keep | 1.5 |
| `PRESS` table of action tuples; buttons registered each frame | `app.PRESS`, `ui/kit.button` | Controls emit signals; game actions are `Session.act(name, args)`; app requests go through the shell context | Godot way | 1.5 |
| `Screen`/`ScreenStack` with `opaque` and `handle_event` | `screens/__init__.py` | `Screen` (a Control scene) and `ScreenStack`; modal screens pause the tree (section 3.2) | Godot way | 1.5 |
| `hud.covers(pixel)` so clicks on the HUD do not reach the map | `hud/__init__.py` | `mouse_filter = STOP` on HUD panels; the map reads only unhandled input | Godot way | 1.5 |
| UI kit and colour tokens, fonts through `new_font` | `hexa/ui/kit.py`, `theme.py` | `shell/ui/` kit and one generated Theme (section 3.4) | keep | 1.5 |
| 35 code-drawn icons | `hexa/ui/icons.py` | An icon atlas baked by the Python art kit at 2x | keep | 4 |
| Busy frame while a season runs | `app.end_turn` | A loading pill; input on the map blocked except the camera | keep | 3, 8 |
| "Choose your country" banner on the map | `app.draw_choose_banner` | The country pick on the map with a list for keyboard play | keep | 2 |
| Event pop-up frame | design `15` | The kit's modal with a picture slot | defer | 12 |
| Window tests, monkey, goldens | `tests/ui/`, `tests/support/monkey.py` | GUT tests in a SubViewport, a GUT monkey, a windowed picture probe (section 9) | improve | 1.5 |

---

## 3. The UI architecture

### 3.1 The scene tree

The main scene becomes `shell/app/app.tscn`. The map scene is a child created when a game starts and freed when it ends.

```
App (Node, app.gd)                               process_mode ALWAYS            shell/app/app.tscn (main scene)
+- AppInput (Node, app_input.gd)                 ALWAYS: app keys, the Esc ladder   shell/input/
+- World (MapScene, Node2D)                      PAUSABLE; made at game start   shell/map/map_scene.tscn
|  +- Camera (Camera2D)
|  +- CameraRig (Node)                           wheel, gestures, keys, drag, bounds, smoothing
|  +- View (TileMapView)  Far (FarMap)  [Floaters M3]  [army tokens M6]
|  +- Input (MapInput)                           clicks, hover, map toggles -> intents
|  +- Names (CanvasLayer 5) > MapLabels          place names in screen space, under the HUD
+- Hud (CanvasLayer 10)                          PAUSABLE                       shell/hud/hud.tscn
|  +- Root (MarginContainer, full rect, IGNORE)
|     +- Column (VBoxContainer, IGNORE)
|        +- TopBar (PanelContainer, STOP)
|        +- Main (HBoxContainer, IGNORE, expand)
|           +- MapArea (Control, IGNORE, expand): BottomRight [ZoomControl, ScaleBar, Minimap M2],
|           |    BottomLeft [ActionLog M3], TopLeft [Debug F3], Toasts (bottom centre), MapHover
|           +- Dock (VBoxContainer, STOP children): HexPanel; later country, army, market panels
+- Screens (CanvasLayer 20)                      ALWAYS
|  +- Stack (ScreenStack, full rect, IGNORE when empty)
+- (tooltips and Popup windows are drawn by Godot above everything)
```

- **Containers only.** The HUD is one `MarginContainer` > `VBoxContainer` > `HBoxContainer`. The zoom cluster sits in
  `MapArea`'s corner, so it moves left of the dock by itself when a panel opens. No pixel positions in scenes.
- **One map, one HUD.** The map scene keeps the camera, the view, its input and the names. Everything screen-fixed is
  the HUD's or a screen's.
- **Main menu with no game:** the World does not exist; the main menu is an opaque screen over the window's background
  colour, with Studiolo's baked map backdrop (`menu_bg`) from M1.5.

### 3.2 Screens and the stack

```gdscript
# shell/ui/screen.gd: the root of every screen scene
class_name Screen extends Control
enum Kind { MODAL, OPAQUE, OVERLAY }
@export var kind := Kind.MODAL
@export var default_focus: NodePath          # takes the keyboard focus on enter
signal finished(result: StringName)          # the screen ends itself; the stack pops it
func setup(ctx: ShellContext) -> void        # called once by the stack before on_enter
func on_enter() -> void                      # virtual
func on_exit() -> void                       # virtual
func back() -> bool                          # Esc: true when the screen used it (a sub-step); false: pop me

# shell/ui/screen_stack.gd
class_name ScreenStack extends Control       # full rect; mouse_filter IGNORE
signal changed
func push(screen: Screen) -> void            # setup(ctx), add as the last child, remember the focus owner, on_enter, grab default_focus
func pop() -> Screen                         # on_exit, remove, give the focus back to who had it
func remove(screen: Screen) -> void
func replace(screen: Screen) -> void
func clear() -> void
func top() -> Screen
func count() -> int
func wants_pause() -> bool                   # any MODAL or OPAQUE screen is up
func hides_world() -> bool                   # any OPAQUE screen is up
func back() -> bool                          # the Esc of the ladder: top().back(), else pop; false when empty
```

| Kind | Examples | Under it | Input |
|---|---|---|---|
| `MODAL` | pause menu, options, confirm, save/load, loading, idea pick | the map, dimmed by **one shade the stack keeps under the top modal**; the tree is paused | all of it (the shade stops the mouse) |
| `OPAQUE` | main menu, tech screen | nothing: the World and the HUD are hidden | all of it |
| `OVERLAY` | help, the battle dock (M7) | the live map; not paused | only on its own panels; the rest reaches the map |

- **Pause is the engine's.** After every `changed`, the App sets `get_tree().paused = stack.wants_pause()` and hides
  the World and the HUD when `hides_world()`. The World and the HUD are `PAUSABLE`, so under a modal screen they get
  no input and no `_process` (no camera, no sliced loading, no replay). That replaces Python's `opaque` checks.
- **A screen is a scene** (`.tscn` laid out with containers, the Theme's types). `shell/screens/screen_ids.gd` maps ids
  to paths (`&"options": "res://shell/screens/options.tscn"`), so a screen opens another with
  `ctx.stack.push(ScreenIds.make(&"options"))` and no scene preloads another (no load cycles).
- **The Python ctx becomes `ShellContext`** (`shell/app/shell_context.gd`, RefCounted), made by the App and given to
  every screen and the HUD: `settings: Settings`, `stack: ScreenStack`, `signal toast_requested(text, tone)`,
  `signal app_requested(what: StringName, args: Dictionary)` (quit, main menu, new sandbox, fullscreen, screenshot,
  look at). A screen never reaches the App or the World by node path; it reads the game through `Session` and asks the
  App for app things through the context. Tests build a context with a plain `ScreenStack` and fake settings.

### 3.3 Input routing

Godot hands an event to `_input`, then to the GUI (the Control under the mouse, or the focused one), then to
`_shortcut_input`, `_unhandled_key_input` and `_unhandled_input`. We use that order instead of Python's hit tests.

| Rule | How |
|---|---|
| **UI covers map** | Every HUD panel and every screen's panel has `mouse_filter = STOP`; full-rect containers are `IGNORE`. The map reads only `_unhandled_input`, so a click, wheel or gesture on the UI never reaches it. A `ScrollContainer` keeps its wheel, so scrolling a list never zooms |
| **Hover only over the map** | `MapInput` clears the hover when `get_viewport().gui_get_hovered_control()` is not null (to confirm in the display probe; the fallback is the HUD's `mouse_entered`/`mouse_exited` on its STOP panels) |
| **HUD buttons never take focus** | `focus_mode = NONE` on HUD controls (as the hex panel contract says), so Space, Enter and the arrows keep their map meaning. Screens use focus for keyboard play |
| **Text fields win** | A focused `LineEdit` eats its keys in the GUI step, so no shortcut fires while typing (save names M3, seed field, search M2) |
| **App keys work under pause** | `AppInput` is `ALWAYS`; `MapInput` and `CameraRig` are `PAUSABLE` |
| **Physical or logical keys** | Camera keys (WASD) are physical (`physical_keycode`), so an AZERTY player gets ZQSD in the same place. Mnemonic keys (G, N, U, F, M) are logical (`keycode`) |
| **Controls never read the mouse for game meaning** | Panels and screens act on their own buttons' signals. The map's meaning (select, command, hover) comes only from `MapInput` |

**Intents** (signals; the App and the map scene connect them):

| Node | Signals |
|---|---|
| `MapInput` | `select_requested(map_px)`, `command_requested(map_px)` (a right click: clears the selection now, orders in M6), `hover_changed(hex)` (`NO_HEX` off the map or over the UI), `season_requested(i)`, `grid_toggled`, `names_toggled`, `hud_toggled`, `upgrade_requested`, `new_seed_requested` |
| `AppInput` | `back_requested` (the Esc ladder), `menu_requested`, `help_toggled`, `debug_toggled`, `fullscreen_toggled`, `screenshot_requested` |
| `CameraRig` | emits `view_changed(zoom, visible_map_rect)` at most once a frame; takes `zoom_by`, `zoom_to`, `pan_by`, `look_at`, `fit` from the HUD and the App |
| HUD | `zoom_step_requested(notches)`, `fit_requested`, `zoom_set_requested(zoom)`, `layer_toggled(name, on)`, `season_preview_requested(i)`, `look_at_requested(map_px)` (minimap M2) |

**The Esc ladder** (`shell/input/esc_ladder.gd`, a pure function of the state, run by the App on `back_requested`):

1. A popover or popup menu is open: Godot closes it itself (the event never reaches us).
2. A screen is up: `stack.back()` (a sub-step, or pop the top screen). The loading screen ignores it.
3. A HUD list is open (the task list, M3): close it.
4. Something is selected or a dock panel is open: clear the selection, close the panel.
5. Otherwise: open the pause menu.

### 3.4 Theme and tokens

**One Theme**, `shell/ui/theme.tres`, set project-wide as `gui/theme/custom`. It is **generated** by
`tools/build_theme.gd` from `shell/ui/tokens.gd` and committed; CI runs `build_theme.gd --check` like `build_tileset`
and `build_map`. Drawing code (map plates, badges, the scale bar) reads `Tokens` constants, never colour literals. A
lint rule forbids `theme_override_` in `.tscn` files under `shell/`, and `Color(` literals in `shell/hud/` and
`shell/screens/` scripts.

Colour tokens (the approved Studiolo values, `docs/design/ui/design.md` section 3; the material, ink and chart tokens
are in `ui-style-and-feedback-spec.md` 4.2):

| Token | Value | Use | Token | Value | Use |
|---|---|---|---|---|---|
| `BG` | `#14100c` | window background | `GOLD` | `#e8c15a` | section heads, selected edge |
| `PANEL_BG` | `#221a14` | panel field | `GOOD` | `#7fc98a` | gains, ok |
| `PANEL_HEAD` | `#3a2416` | panel header band | `BAD` | `#f0806a` | losses, refusals that matter |
| `CARD_BG` | `#15110e` | hover cards, log box | `WARN` | `#f0a850` | sieges, warnings |
| `LINE` | `#6b5637` | rules | `INFO` | `#8fb8ea` | links, focus |
| `TEXT` | `#f2e8d0` | text | `INK` | `#0b0806` | outlines |
| `MUTED` | `#b9a987` | secondary text, reasons | `SHADE` | `#070504` at 72 % | the modal shade |
| `FAINT` | `#9c8c70` | hints, disabled text | `ROW_HOVER` | `#33271c` | a row under the mouse |
| `BUTTON` | `#4a3120` / hot `#5e4029` / off `#2a221b` | secondary button | `TOGGLE` | `#2b221a` / hot `#382c21` | toggle button |
| `PRIMARY` | `#d9a93a` / hot `#f0c85a` | End season, modal OK | `DANGER` | `#8e2618` / hot `#ad3420` | Quit, Declare war |

Type scale (open-licence fonts, all OFL): **Cinzel** for engraved titles (the "HEXA" wordmark is a baked picture in
Cinzel Decorative); **Alegreya SC** for section heads; **Alegreya Sans** with lining, tabular figures for everything
else; **Alegreya** italic for flavour on vellum.

| Variation | Font | Size | Colour |
|---|---|---|---|
| `TitleModal` | Cinzel Bold | 19 | `BRASS_HI` |
| `TitlePanel` | Cinzel Bold | 16 | `BRASS_HI` |
| `SectionHead` | Alegreya SC Bold | 16 | `GOLD` |
| `Number` | Alegreya Sans Bold | 16 | `TEXT` |
| `Label` (default) / button text | Alegreya Sans Bold | 14 | `TEXT` |
| `Body` | Alegreya Sans Medium | 15 | `TEXT` |
| `Hint`, `Reason` | Alegreya Sans Regular | 13 | `MUTED` |
| `KeyCap` | Alegreya Sans Bold | 12 | `VELLUM_INK` on a bone cap |

Button variations: `Button` (secondary, medium 28 px), `ButtonSmall` (24 px), `ButtonPrimary`, `ButtonPrimaryLarge`
(32 px), `ButtonDanger`, `ButtonToggle`, `ButtonIcon`. Shape: baked 9-slice frames
(`StyleBoxTexture`: chamfered corners, gilt edge, lit top line, a lip that drops when pressed), made by
`tools/bake_ui.py`; `StyleBoxFlat` stays for row hover, rules, scrollbars, insets, the shade and the F3 panel
(`ui-style-and-feedback-spec.md` 4.4 to 4.7). Panels: `PanelContainer` (side panel), `PanelBar` (top bar), `PanelCard` (hover card),
`PanelModal`, `PanelToast`; Godot's own `TooltipPanel`/`TooltipLabel` styled as cards. Spacing on a 4 px grid
(`S1` 4 ... `S6` 24). Today's `HexTitle`, `HexSection`, `HexKey`, `HexValue`, `HexReason` stay as aliases until the hex
panel moves to the new names. **The hex panel's colours change** to the tokens (a look change, said in its pull
request).

### 3.5 The kit (`shell/ui/`)

| Piece | File | What it gives |
|---|---|---|
| `Tokens` | `tokens.gd` | colours, sizes, spacing, font paths; read by `build_theme.gd` and by drawing code |
| `KitButton` | `kit_button.gd` (extends Button) | `kind`, `icon_name`, `cost_text`; **`set_verdict(verdict: Dictionary)`**: `{ok, reason}` from `Session.check` disables it, shows a lock and puts the reason in the tooltip; `hotkey_action`: the key from the InputMap is shown in the tooltip |
| `PanelFrame` | `panel_frame.tscn/.gd` | header band (title, subtitle, close), a `ScrollContainer` body, a footer that stays put |
| `ModalFrame` | `modal_frame.tscn/.gd` | a centred `PanelFrame` for modal screens; the shade is the stack's |
| `HoverCard` | `hover_card.tscn/.gd` | `show_card(card: Dictionary)`: a gold title, lines of `[text, tone, amount]` with right-aligned amounts and rules (Python's `hover_card`) |
| `ToastHost` | `toast_host.tscn/.gd` | `toast(text, tone)`: up to 3 lines, 3.5 s each, bottom centre |
| `OptionRow` | `option_row.tscn/.gd` | `bind(settings, key)`: builds an `OptionButton`, `CheckButton` or `HSlider` from the schema; a disabled row shows its reason |
| `KeyCap` | `key_cap.gd` | draws an action's binding as key caps, from the InputMap (so a rebinding shows everywhere) |
| `Screen`, `ScreenStack` | `screen.gd`, `screen_stack.gd` | section 3.2 |
| `PanelKit` | `panel_kit.gd` (exists) | label of a type, reason line, key and value grid; kept |
| `Segmented` | `segmented.gd` | a toggle group (map modes M2, season preview) |
| Icons | `assets/ui/icons.png` + index | M4 (the top bar chips need them); M1.5 uses text glyphs (`+`, `-`, menu) |

Studiolo adds kit pieces (`VellumSheet`, `Ribbon`, `Cartouche`, `NavList`, medallions, `DeltaChip`, `SeasonStrip`,
`PreviewCard`, `InkChart`, `StudyTable`) and moves the icons into the kit bake: `ui-style-and-feedback-spec.md` section 5.

### 3.6 How the UI talks to the game

- **Read** `Session.game` (map, state) and the pure helpers of `core/views` (for example `HexCard.of(game, hex)` for
  the hover card). Never write state, never call a system directly.
- **Act** with `Session.act(name, args)` and pre-check with `Session.check` (a `KitButton` shows the verdict).
- **Listen** to `Events` signals: connect in `_enter_tree` or `on_enter`, disconnect in `_exit_tree` or `on_exit`
  (as `map_scene.gd` does today). Handlers redraw; they never act.
- **Game lifecycle** through `Session`: `new_game(map_id, seed)`, `end_game()` (M1.5), `save_game(slot)`, `load_game(slot)`,
  `list_saves()` (M3; named so in `m3-build-spec.md` 5.5). `Session.unsaved_actions` counts the successful actions since the game started or was saved;
  the App asks before losing them.
- **App things** (settings, toasts, quit, main menu, screenshot) through the `ShellContext`.

---

## 4. Controls

### 4.1 The input map

Every action is an InputMap action registered from `shell/input/bindings.gd` (`Bindings.DEFAULTS`: name, events,
group, milestone). Overrides from `settings.cfg [keys]` are applied on top (the rebinding page is M12; the file
format exists from M1.5). Godot's built-in `ui_*` actions keep their defaults and serve the screens' focus
navigation. Modifier chords use `command_or_control_autoremap`, so "Ctrl" is Cmd on the Mac.

| Action | Default | Mac extra | Group | Since |
|---|---|---|---|---|
| `cam_pan_left` / `right` / `up` / `down` | A / D / W / S (physical), arrows | | Camera | 1 (kept) |
| `cam_pan_fast` | Shift (held) | | Camera | 1.5 |
| `cam_zoom_in` / `cam_zoom_out` | `=` `+` keypad `+` / `-` keypad `-` | | Camera | 1.5 |
| `cam_fit` | F, Home | | Camera | 1 (kept) |
| `map_select` | left click | | Map | 1 |
| `map_command` | right click | two-finger click | Map | 1 (clears now; orders M6) |
| `view_season_1..4` | 1-4 | | View | 1 (becomes `view_mode_1..4` in M2) |
| `view_grid` | G | | View | 1 |
| `view_names` | N | | View | 1.5 (wired) |
| `view_hud` | H (photo mode: hides the HUD) | | View | 1 |
| `game_upgrade` | U | | Game | 1 |
| `dev_new_seed` | Ctrl+R | Cmd+R | Developer | 1.5 (was R) |
| `dev_debug` | F3, `` ` `` | | Developer | 1.5 |
| `app_back` | Esc | | App | 1.5 (the ladder) |
| `app_menu` | M | | App | 1.5 |
| `app_help` | F1, `?` | | App | 1.5 |
| `app_fullscreen` | F11, Alt+Enter | Ctrl+Cmd+F | App | 1.5 |
| `app_screenshot` | F12 | | App | 1.5 |
| `game_end_season` | Space, Enter | | Game | 3 |
| `game_quicksave` / `game_quickload` | F5, Ctrl+S / F9, Ctrl+L | Cmd+S / Cmd+L | Game | 3 |
| `cam_bookmark_go_1..9` / `cam_bookmark_set_1..9` | Ctrl+1..9 / Ctrl+Shift+1..9 | Cmd | Camera | 3 |
| `game_undo_work` | Ctrl+Z (cancels the newest work begun this season; `m3-build-spec.md` 6.1) | Cmd+Z | Game | 3 |
| `dev_console` | F2 (focuses the console at the foot of F3) | | Developer | 3 |
| `view_mode_1..4` | 1 Terrain, 2 Owner, 3 Relief (M2); 4 Yields (M4.5); later modes take 5 and up as they arrive (5 Food in M5, `view_mode_5`, `m5-build-spec.md` 6.1; 6 Supply in M6, `view_mode_6`, `m6-build-spec.md` 6.1; `m4-5-build-spec.md` D15) | | View | 2 |
| `ui_find_place` | Ctrl+F | Cmd+F | View | 2 |
| `game_country` | C | | Game | 2 |
| `game_ledger` | L | | Game | 4 |
| `game_next_unit` / `game_continue_march` | Tab / R | | Game | 6 |
| `map_cursor_*` (move the selected hex; with an army selected, the order cursor) | Alt+arrows | Option+arrows | Map | 6 |
| `map_command_key` (a right click at the cursor: the order, or the hex menu; `m6-build-spec.md` 6.1) | O, Shift+F10 | | Map | 6 |
| `map_command_storm` (storm with the selected army at the cursor; Shift+right click storms at the pointer, read by `MapInput` from the click; `m7-build-spec.md` 6.1) | Shift+O | | Map | 7 |
| `game_battle` (the battle dock on your newest battle) | B | | Game | 7 |
| `view_mode_7` (the Relations mode; `m9-build-spec.md` 6.1) | 7 | | View | 9 |
| `game_peace` (the peace screen: the war with the country shown, else your newest; `m9-build-spec.md` 6.1) | P | | Game | 9 |
| `view_mode_8` (the Trade mode: catchments, prices and the route lines; `m10-build-spec.md` 6.1) | 8 | | View | 10 |
| `game_market` (the market panel: the selected hex's market, else your home market; `m10-build-spec.md` 6.1) | E | | Game | 10 |
| `game_tech` | T | | Game | 11 |

Mac notes: Cmd+Q and the red button arrive as a close request (section 5.3); Ctrl+arrows are taken by macOS (Spaces),
so no binding uses them. Windows notes: Alt+F4 is a close request; Alt+Enter is ours (Godot does not bind it).

### 4.2 Pointer and gestures

| Event (Godot) | Comes from | Default effect | Setting |
|---|---|---|---|
| `InputEventMouseButton` `WHEEL_UP/DOWN`, `factor` | a mouse wheel (Mac and Windows); a Windows touchpad's two-finger scroll | zoom by `notch ^ factor` about the pointer (factor 0 means 1) | `controls/wheel_action`: zoom or pan |
| the same with Ctrl/Cmd | Windows touchpad pinch (sent as Ctrl+wheel) | always zoom | |
| `WHEEL_LEFT/RIGHT`, or Shift+wheel | tilt wheels, touchpad sideways | pan sideways | |
| `InputEventPanGesture` `delta` | Mac trackpad two-finger scroll, Magic Mouse | **pan** by `delta x GESTURE_PAN_PX` screen px (start value 20; the input probe on the owner's MacBook sets it), following the fingers | `controls/gesture_action`: pan or zoom; `controls/invert_scroll` |
| the same with Ctrl/Cmd | | the other action (zoom when the default is pan) | |
| `InputEventMagnifyGesture` `factor` | Mac trackpad pinch | zoom by `factor` about the gesture point, no smoothing (it already follows the fingers) | |
| left press and release within 6 px | click, tap-to-click | select the hex | |
| left, middle or right drag past 6 px | drag, three-finger drag | pan, 1:1 with the pointer; the camera does not move inside the 6 px (today it does) | |
| right click within 6 px | right button, two-finger click; Ctrl-click (Godot's macOS layer reports it as right: to confirm in the input probe) | clear the selection (M6: the order) | |

The device preset (`controls/device`) writes `wheel_action` and `gesture_action`: **Both** (default: wheel zooms,
trackpad scroll pans, pinch zooms), **Mouse** (wheel and Magic Mouse scroll zoom), **Trackpad** (wheel and trackpad
scroll pan, pinch and Ctrl+scroll zoom; for Windows touchpads).

### 4.3 The zoom model (`shell/input/zoom_model.gd`, pure; `CameraRig` uses it)

| Rule | Value |
|---|---|
| Zoom | continuous, camera scale; 1 = the art's size in logical px |
| Fit | `fit = min(free_w / map_w, free_h / map_h) x 0.96`; the free area is the window minus the top bar (the dock is ignored: it comes and goes) |
| Minimum | `fit x 0.9`: the whole map with a margin. North Italy: about 0.40 at 1280 x 720, 0.82 at 2560 x 1440; the made-up Europe about 0.022 |
| Maximum | **2.0** (was 4.0). A UI scale change multiplies the zoom by old/new scale, so the same map stays on screen |
| A wheel notch | `notch = 1.15 ^ zoom_speed` (zoom speed 50 % to 200 %), times the event's `factor` |
| A key press or the `+`/`-` buttons | 2 notches about the free area's centre; key repeat repeats it |
| Pinch | multiply by the gesture's factor at once |
| Smoothing | wheel, keys and buttons ease the zoom towards the target with a time constant of 70 ms, keeping the anchor's map point under the anchor pixel every frame; snap when within 0.1 %. Off with `zoom_smoothing` or `reduce_motion` |
| Anchor | the pointer (default) or the screen centre (`controls/zoom_anchor`) |
| Glide | `look_at` from a link, the minimap or the place search eases over 0.35 s; a jump with `reduce_motion` |
| Bands (`ZoomModel` constants read from `FarMap`) | below 0.20 the far picture alone; 0.20 to 0.25 the cross-fade (unchanged); at and above 0.25 tiles. The grid fades out between 0.45 and 0.30 (thin lines alias when small). Labels keep `MapLabels.font_size(level)` |
| Window resize | keep the centre and zoom, recompute the limits, clamp |

### 4.4 Pan, bounds, edge pan, fit

- **Keys:** `900 x pan_speed` screen px a second (pan speed 50 % to 200 %), Shift x2.5; screen-constant at every zoom.
- **Bounds:** the camera's centre stays inside the map's rectangle. On an axis where the map is smaller than the free
  area, the centre is the map's centre. (Our own clamp in `ZoomModel.clamp_centre`, not `Camera2D.limit_*`, which
  clamp the screen's edges and do not centre a map smaller than the screen.) This replaces Python's "200 px past the
  edge".
- **Edge pan** (`controls/edge_pan`, off by default): an 8 px band at the window's edge pans at the key speed times
  `edge_pan_speed`, only while the window has focus, the pointer is inside it, no drag is on and no Control is under
  the pointer. Off by default because a windowed Mac puts the Dock and the menu bar at the edges.
- **Fit:** F, Home or the fit button frame the whole map (today's `fit()`, against the free area).

### 4.5 Keyboard-only play and accessibility of the controls

- **Every screen** is usable with the keyboard: a `default_focus`, focus neighbours from the containers, Enter accepts,
  Esc goes back, Tab moves on. The stack gives the focus back when a screen closes.
- **Every map toggle** has a key (G, N, H, 1-4, F, `+`/`-`). The hex panel's U works on the selected hex, and a refused
  key action now **toasts its reason** (today it is silent).
- **Selecting a hex with keys** (Alt+arrows move the selection and the camera follows; Tab cycles armies) comes with M6,
  when there is something to cycle. The panel's build list by keyboard (number keys in the open panel) is M12.

### 4.6 The help overlay (`shell/screens/help_overlay.tscn`, an `OVERLAY` screen)

F1, `?` or the top bar's `?` button. A card listing the actions by group with their `KeyCap`s, **generated from
`Bindings.DEFAULTS` and the live InputMap** (so it never drifts from the keys), plus the gesture lines of
`Bindings.GESTURES` for the platform (`OS.get_name()`). It opens by itself the first time the sandbox starts
(`state/help_seen`). The map stays live under it; F1, `?`, Esc or its close button close it.

---

## 5. Menus

**Rule:** what arrives in a later milestone is **hidden**, not greyed. Greyed with a reason is for a state (Save
while a season is running), not for the roadmap.

### 5.1 The main menu (`shell/screens/main_menu.tscn`, `OPAQUE`)

The "HEXA" wordmark (a baked picture), a subtitle, the version bottom right (`application/config/version`), buttons in a
column, the first one focused:

| Button | Does | Since |
|---|---|---|
| Continue | loads the newest save; its line shows the country and the date | 3 |
| New game | the new-game page: scenario (1480), country (picked on the map, with a list for the keyboard), seed under "More" | 2 (country), 3 (a real game with time) |
| **Map sandbox** | the sandbox page: map (north Italy), seed (number field, a "Random" button), Start. Today's map-only game | 1.5; shown while the `dev/developer_tools` option is on; that option's default flips to off at M12 |
| Load game | the save and load screen on its Load tab | 3 |
| Options | the options screen | 1.5 |
| Credits | the credits screen | 1.5 |
| Quit | quits (no question: no game is running) | 1.5 |

The command line skips the menu for tools and quick starts: `-- --sandbox [--seed=N]`
(`OS.get_cmdline_user_args()`). Starting a game pushes the **loading screen** (section 7), waits two frames so it is
drawn, then calls `Session.new_game` (the improvement search is synchronous in `core/`). For a large map (Europe) the
shell may run that search on a `WorkerThreadPool` task; `core/` stays thread-free.

### 5.2 The pause menu (`shell/screens/pause_menu.tscn`, `MODAL`)

Esc (the ladder), M, or the top bar's menu button. The map is dimmed and the tree paused. Subtitle: the map and seed
(sandbox), later the country and the date.

| Button | Does | Since |
|---|---|---|
| Resume | closes (Esc too) | 1.5 |
| Save game / Load game | the save and load screen; Save greyed with "Wait for the season to end" while one runs | 3 |
| Options | pushes the options screen | 1.5 |
| Help and keys | pushes the help overlay | 1.5 |
| Main menu | asks first when `Session.unsaved_actions > 0` ("Leave to the main menu? Unsaved changes are lost."); then `Session.end_game()` | 1.5 |
| Quit to desktop | asks the same way; then saves the settings and quits | 1.5 |

The hint line under the box: "Esc: back to the map    F1: keys    F11: fullscreen" (and F5/F9 from M3).

### 5.3 Confirmations (`shell/screens/confirm.tscn`, `MODAL`)

`Confirm.ask(title, lines, choices)`; a choice is `{label, id, kind}` (`kind` primary, secondary or danger). The safe
choice has the focus and is what Esc picks. A **countdown variant** (`timeout_s`, `timeout_id`) serves the display
revert: "Keep these display settings? Reverting in 10 s" (section 6.2). Used for: leaving or quitting with unsaved
changes, overwriting a save, loading over progress, deleting a save, the war alert (M7), events (M12).

**Closing the window** (Cmd+Q, Alt+F4, the window's close button): `get_tree().auto_accept_quit = false`; the App's
`NOTIFICATION_WM_CLOSE_REQUEST` asks the same question when `Session.unsaved_actions > 0`, else it saves the settings
(the window's place and size) and quits. That Cmd+Q arrives as this request on macOS is confirmed in the display probe.

### 5.4 Save and load (M3; `shell/screens/save_load.tscn`, `MODAL`)

Two tabs, Save and Load. Slots: Autosave, Quicksave, Slot 1 to 8 (as in Python). A row: a **thumbnail** (192 x 108,
taken from the viewport when saving, with the HUD hidden for that frame, stored as `user://saves/<slot>.png`), the
country and game date (from the save's JSON header line, standard 5.5), the map, the real date and time saved, the play
time and the game version. States: empty; ok; **incompatible** (a newer format: greyed, "Made by a newer Hexa"); broken
(greyed, "Cannot be read"). Saving over a used slot, loading over unsaved changes and deleting (the Del key or a small
button) go through `Confirm`. The list reads headers only (`Session.list_saves()`), never whole saves.

### 5.5 Autosave recovery (M3)

The App writes `user://running.lock` when a game starts and removes it at a clean exit or the main menu. At start, if
the lock is there and the autosave is newer than the newest other save: "Hexa did not close properly. Load the
autosave from Spring 1482?" with **Load autosave** and **Not now**.

### 5.6 About and diagnostics (M1.5; the Options screen's last page, also reached from the main menu)

| Line | Source |
|---|---|
| Hexa version | `ProjectSettings application/config/version` |
| Engine | `Engine.get_version_info()` |
| System | `OS.get_name()`, `OS.get_version()`, `OS.get_processor_name()` |
| Renderer | `rendering/renderer/rendering_method`, `OS.get_current_rendering_driver_name()`, `RenderingServer.get_video_adapter_name()`, `get_video_adapter_vendor()`, `get_video_adapter_api_version()` |
| Screen | `DisplayServer.screen_get_size()`, `screen_get_scale()`, `screen_get_dpi()`, the window size, the UI scale |
| Memory | `Performance` `MEMORY_STATIC`, `RENDER_VIDEO_MEM_USED`, `RENDER_TEXTURE_MEM_USED` |
| Game | the map id, its digest (short), the seed, the season |
| Folders | `OS.get_user_data_dir()` |

Buttons: **Copy diagnostics** (`DisplayServer.clipboard_set` of all the lines as text, for bug reports) and **Open data
folder** (`OS.shell_open`).

### 5.7 Credits (M1.5; `shell/screens/credits.tscn`, `MODAL`)

The text of `godot/CREDITS.md` (fonts and their licences, geography sources, art) in a `RichTextLabel`.

---

## 6. Options

### 6.1 Where things are stored

| What | Where | Written by | Notes |
|---|---|---|---|
| Build defaults: base size 1280 x 720, resizable, stretch mode, HiDPI, vsync default, the Theme and font, the tooltip delay default, renderer, texture import, power saving | `project.godot` | developers only | **Never written at run time** (no `ProjectSettings.save`, no `override.cfg`) |
| The player's choices | `user://settings.cfg` (`ConfigFile`), sections `display`, `graphics`, `controls`, `map`, `accessibility`, `game`, `audio`, `keys`, `dev`, `state` | `Settings` (`shell/app/settings.gd`) | Applied over the defaults at start. Every key is checked against `Settings.SCHEMA` (type, choices or range); an unknown key, a wrong type or a value out of range falls back to the default, and a file that does not parse means defaults (Python's rule). Only plain values are accepted. Written to `settings.cfg.tmp`, then renamed; a failed write toasts "Option changed, but it could not be saved" and keeps the old file |
| Saves, thumbnails, the lock | `user://saves/`, `user://running.lock` | `Session` (M3), the App | |
| Screenshots | `user://screenshots/hexa_<date>_<time>.png` | the App | |
| The user folder | `application/config/use_custom_user_dir = true`, name "Hexa": `~/Library/Application Support/Hexa` and `%APPDATA%\Hexa` | | Not Godot's shared `app_userdata` folder |

```gdscript
# shell/app/settings.gd
class_name Settings extends RefCounted
const PATH := "user://settings.cfg"
const SCHEMA := {}                       # "section/key": {type, default, choices or range, page, since, applies}
signal changed(key: String, value: Variant)
static func load_from(path: String = PATH, platform: String = OS.get_name()) -> Settings
func save_to(path: String = PATH) -> bool
func get_value(key: String) -> Variant
func set_value(key: String, value: Variant) -> bool    # validates, emits changed; the App saves (debounced 1 s)
func reset_page(page: String) -> void
```

Platform defaults: `Settings` takes the platform name, so the Mac and Windows can start from different defaults (the
fullscreen chord in the help, and possibly `preload_next_season`, section 6.3).

### 6.2 Display and windowing

All on the **Display** page; the App applies them with `shell/app/display.gd` (`Display.apply(window, settings)`; its
pure helpers are tested headless).

| Option | Choices (default) | Godot | Stored | When |
|---|---|---|---|---|
| Window mode | Windowed, Fullscreen (borderless), Exclusive fullscreen (Windows only, under "Advanced") (Windowed) | `Window.mode` = `MODE_WINDOWED`, `MODE_FULLSCREEN`, `MODE_EXCLUSIVE_FULLSCREEN`; F11 / Alt+Enter / Ctrl+Cmd+F toggle windowed and fullscreen. The Mac's green button changes the mode behind our back: the App reads `Window.mode` on `size_changed` and stores it | `display/window_mode` | **1.5** |
| Resize | free (drag the edge) | `display/window/size/resizable = true` (exists) | | **1.5** |
| Window size presets | Custom (as dragged), 1280 x 720, 1600 x 900, 1920 x 1080, 2560 x 1440, listed only if they fit the screen's usable rect (Custom) | `Window.size` (in points: times the screen scale on a Retina screen) | `display/window_preset` | **1.5** |
| Minimum window size | 1024 x 600 points (Python's) | `Window.min_size`, set at start | | **1.5** |
| Remembered position, size, maximized | the last ones | `Window.position`, `Window.size`, `MODE_MAXIMIZED`; written at quit and 1 s after a move or resize; at start `Display.window_rect()` keeps it on a screen that exists, else centres it on the primary | `display/window_position`, `window_size`, `maximized` | **1.5** |
| Screen | System, Screen 1 (2560 x 1600), Screen 2 ... (System) | `Window.current_screen`; `DisplayServer.get_screen_count()`, `screen_get_size(i)` | `display/screen` | **1.5** |
| Vsync | Off, On, Adaptive (On) | `DisplayServer.window_set_vsync_mode(VSYNC_DISABLED / ENABLED / ADAPTIVE)`; where the driver lacks Adaptive, Godot falls back to On and the row says so (read back with `window_get_vsync_mode`) | `display/vsync` | **1.5** |
| Frame cap | None, 30, 60, 120 (None) | `Engine.max_fps` | `display/fps_cap` | **1.5** |
| Frame cap when the window is in the background | Off, 5, 10, 30 (10) | `Engine.max_fps` on `NOTIFICATION_APPLICATION_FOCUS_OUT`, restored on `FOCUS_IN` | `display/background_fps` | **1.5** |
| Power saving | On, Off (On) | `OS.low_processor_usage_mode`: frames are drawn only when something changed; a still map costs nothing (the MacBook's battery and fans). The perf tool turns it off | `display/power_saving` (Advanced) | **1.5** |
| UI scale | Auto, 75 % to 200 % in steps of 25 (Auto) | stretch mode `canvas_items`, aspect `expand` in `project.godot`; on every `size_changed` the App sets `content_scale_size = window size` and `content_scale_factor = scale`, so the logical screen is the window divided by the scale (a bigger window shows more map, the UI keeps its size). **Auto** = `DisplayServer.screen_get_scale()` on the Mac (2 on Retina), `screen_get_dpi() / 96` rounded to 0.25 on Windows (where `screen_get_scale` is 1). Fonts are rasterised at the real size, so text stays sharp | `display/ui_scale` | **1.5** |
| "Keep these settings?" | after a change of mode, preset, screen or UI scale: a countdown `Confirm`, **10 s**, then the old values come back | `Confirm` countdown variant | | **1.5** |

HiDPI: `display/window/dpi/allow_hidpi = true`. On the first run the window opens at 1280 x 720 *points* (pixels times
the screen scale), clamped to the usable rect. **To confirm in the display probe, not by reading:** that the content
scale mechanism gives the logical size above, how macOS reports window sizes on a Retina screen, and that Cmd+Q is a
close request. If the probe shows `content_scale_factor` alone works in stretch mode `disabled`, we use that instead;
the option and its behaviour do not change.

### 6.3 Graphics, and the Mac's texture memory

**The numbers.** One tile set is 76.1 megapixels (summer: coast 26.1, pieces 40.7, ground 2.7, trees 2.4, relief 1.8,
marks 1.4, shade 0.9). A spring, summer or autumn TileSet uses one set for its three climate slots; winter uses three
sets (they share only marks and shade): 223.8 Mpx. Imported as BPTC, a pixel costs 1 byte on Windows. **The Mac's
Compatibility renderer does not take BPTC, so Godot unpacks it to RGBA8: 4 bytes a pixel.** The map scene also keeps
the next season loaded (requested right after a swap begins).

| Video memory of the tiles (MB) | Spring, summer, autumn | Winter | Steady state with the next season loaded: summer (+autumn) / winter (+spring) |
|---|---|---|---|
| Windows, BPTC | 76 | 224 | 152 / 300 |
| **Mac, RGBA8 (today)** | **304** | **895** | **609 / 1,199** |
| Mac, ASTC 4x4 if the driver takes it | 76 | 224 | 152 / 300 |
| Mac, half resolution (a quarter of the pixels), RGBA8 | 76 | 224 | 152 / 300 |
| Mac, full, next season not preloaded | 304 | 895 | 304 / 895 |

This fits the owner's reading of about 845 MB, against the about 99 MB the budget was checked with (a BPTC season plus
the rest), and it breaks the M1 spec's 512 MB budget in winter on the Mac. Mipmaps are off today; turning them on would
add a third.

**What to do, in order** (probe G1 measures each on the owner's Mac and on Windows before anything ships):

1. **Import ETC2/ASTC as well** (`rendering/textures/vram_compression/import_etc2_astc = true`). If the Mac's
   Compatibility driver accepts ASTC, the Mac drops to the Windows figures with no visible change and no option.
   The Windows export still carries only BPTC.
2. **Preload next season** becomes an Advanced option (`graphics/preload_next_season`). Off saves one season at the cost
   of a disk load when the season changes (the perf tool's `load_ms` measures it). The Mac's default follows G1.
3. **Texture quality: Full or Half.** A half set is the same atlases at half size (a quarter of the memory). The
   TileSets keep their regions in full-size pixels, so the half textures must report the full size: G1 tries
   `PortableCompressedTexture2D.size_override` (written by `build_tileset.gd --half`) and, as a fallback, half
   TileSets drawn by a view scaled x2. Softer at zoom 0.5 and above. Ships only if 1 does not solve the Mac.

| Option | Recommendation | Godot | Stored | Page |
|---|---|---|---|---|
| Texture quality, Full or Half | **later** (after G1, only if ASTC fails; then it also gives the Low preset its meaning) | half atlases, see above; applied at the next season load | `graphics/texture_quality` | Graphics |
| Preload next season | **1.5** | `MapScene.preload_next_season` (exists) | `graphics/preload_next_season` | Advanced |
| Relief shading | **1.5** (On) | `TileMapView.set_layer_visible("shade"/"light")` | `graphics/relief_shading` | Graphics |
| Grid opacity | **1.5** (100 % of the tile's own alpha) | the grid layer's `modulate.a`, times the zoom fade | `map/grid_opacity` | Map |
| Tree and decor density | **later** (the map-look milestone): a density is a view rule in `MapCells` (full, thin, sparse tiles), not a layer switch. A Trees on/off switch for testing lives in the F3 panel now | `MapCells` parameter | `graphics/decor_density` | Graphics |
| Water and coast animation | **skip** until the map-look milestone (nothing animates; it would be a shader on the sea layer, with an option then) | | | |
| Season change, Instant or Fade | **M3** (seasons change by time then). Fade: a picture of the screen (`get_viewport().get_texture().get_image()`) on top, fading out over 0.4 s while the chunks swap below; it also hides the chunk-by-chunk change. Instant with `reduce_motion` | a `TextureRect` in the HUD | `graphics/season_change` | Graphics |
| Texture filtering | **skip** as an option: painted art is always linear. Mipmaps are an import decision that G1 measures (the look at zoom 0.25 to 0.5 against a third more memory) | `CanvasItem.texture_filter`, import `mipmaps/generate` | | |
| Far-zoom switch point | **developer only** (F3 panel): on north Italy the far picture never shows (the minimum zoom is about 0.40) | `FarMap.ZOOM_OFF/ZOOM_ON` made settable | `dev/far_zoom` | F3 |
| Loading slice budget | **developer only** (F3 panel), 2 to 16 ms (5) | `MapScene.SLICE_MS` made settable | `dev/slice_ms` | F3 |
| Presets Low, Medium, High, plus Advanced | **later**, with texture quality: with today's knobs Low and High would differ in almost nothing. Defined now: **Low** = half textures, no relief shading, no preload, frame cap 60; **Medium** = full textures, relief shading, preload per platform; **High** = Medium plus mipmaps if imported. Changing a knob sets the preset to Custom | | `graphics/preset` | Graphics |

### 6.4 Controls (the **Controls** page)

| Option | Choices (default) | Godot | Stored | When |
|---|---|---|---|---|
| Input device | Both, Mouse, Trackpad (Both) | writes the two below (section 4.2) | `controls/device` | **1.5** |
| Mouse wheel | Zoom, Pan (Zoom) | `CameraRig` | `controls/wheel_action` | **1.5** |
| Trackpad scroll | Pan, Zoom (Pan) | `CameraRig`, `InputEventPanGesture` | `controls/gesture_action` | **1.5** |
| Invert scroll direction | Off, On (Off; macOS's own "natural scrolling" is already in the deltas) | sign of the pan from scroll and gestures | `controls/invert_scroll` | **1.5** |
| Pan speed | 50 % to 200 % (100) | keys, edge pan, gesture pan | `controls/pan_speed` | **1.5** |
| Zoom speed | 50 % to 200 % (100) | `notch = 1.15 ^ speed` | `controls/zoom_speed` | **1.5** |
| Smooth zoom | On, Off (On) | section 4.3 | `controls/zoom_smoothing` | **1.5** |
| Zoom towards | Pointer, Screen centre (Pointer) | | `controls/zoom_anchor` | **1.5** |
| Edge pan, and its speed | Off, On (Off); 50 % to 200 % | section 4.4 | `controls/edge_pan`, `edge_pan_speed` | **1.5** |
| Keys (rebinding) | a list of actions, click a key cap and press a key; clashes are refused with the clashing action named; "Reset to defaults" | `InputMap.action_erase_events` / `action_add_event`; written as text with `OS.get_keycode_string`, read with `OS.find_keycode_from_string` | `keys/<action>` | **12** (the file format and `Bindings.apply_overrides` in 1.5) |

### 6.5 Accessibility (the **Accessibility** page)

| Option | Recommendation | Godot | Stored |
|---|---|---|---|
| Reduce motion | **1.5** (Off): no zoom smoothing, no glides; later no rising ribbons (they fade in place), instant replay, instant season change | read by `CameraRig`, `Floaters`, the replay | `accessibility/reduce_motion` |
| Tooltip delay | **1.5**: Short 0.2 s, Normal 0.5 s, Long 1.0 s (Normal) | `ProjectSettings gui/timers/tooltip_delay_sec` set at start and on change (that the engine reads it live is confirmed in the probe; else it applies after a restart and the row says so); the map's hover card uses the same value | `accessibility/tooltip_delay` |
| UI scale | **1.5** (also on Display) | section 6.2 | `display/ui_scale` |
| Keyboard-only play | **1.5** for every screen and map toggle; the hex cursor and unit cycling in M6; the panel's build list by key in M12 | focus, InputMap | |
| Colour-blind safe country colours | **M2** (with the owner colours): a second palette chosen for the common colour-vision types (`m2-build-spec.md` 4.6); the pattern on occupied land comes with occupation (M7) | the mode overlay's palette texture and the border meshes; the minimap and the mode overlay read the same palette | `accessibility/country_colours` |
| Text size | **M12**: 100 % to 150 %. The Theme's sizes are tokens, so the App scales a duplicate of the Theme's font sizes; the containers reflow. Until then UI scale covers it | a runtime copy of the Theme | `accessibility/text_size` |
| High contrast | **M12**: a second token set (`build_theme.gd` writes `theme_high_contrast.tres`): brighter lines, no translucent panels, thicker selection ring and grid | `gui/theme/custom` swapped at start | `accessibility/high_contrast` |

### 6.6 Game and audio (staged)

| Option | Choices (default) | Godot | Stored | When |
|---|---|---|---|---|
| Autosave | Off, Every year, Every 5 years (Every year) | the autosave phase of the season table | `game/autosave` | M3 |
| Task flag | On, Off (On) | `TaskFlag` | `game/task_flag` | M3 (frame), M4 (rules) |
| Movement replay speed | Instant, Normal, Slow (Normal) | the replay of `unit_moved` | `game/movement` | M6 |
| Ask before losing progress | On, Off (On) | the `Confirm`s of 5.2 to 5.4. Always on until M12 | `game/confirm_loss` | M12 (the switch) |
| Hints | Off, Basic, All (Basic) | the tutorial hints layer | `game/hints` | M12 |
| Volumes: master, music, effects, ambient | 0 to 100 % | `default_bus_layout.tres` with buses Master, Music, Effects, Ambient; `AudioServer.set_bus_volume_db(i, linear_to_db(v))` | `audio/*` | M12 |
| Mute when in the background | On, Off (On) | `AudioServer.set_bus_mute(0, ...)` on `NOTIFICATION_APPLICATION_FOCUS_OUT/IN` | `audio/mute_unfocused` | M12 |

### 6.7 The Options screen (`shell/screens/options.tscn`, `MODAL`)

About 760 x 560 logical px. Left, a list of pages: **Display, Graphics, Controls, Map, Accessibility**, Game (M3),
Audio (M12), Keys (M12), **Advanced**, **About**. Right, the page's `OptionRow`s in a scroll body, built from
`Settings.SCHEMA` (the schema says each row's page; a test checks every key has a row and every row a key). Footer:
**Defaults for this page** and **Back**. A change applies at once and is saved (as in Python); display changes go
through the 10 s revert. A row that cannot apply now is disabled with its reason (window size while fullscreen).
Rows of later milestones are not shown. The Map page: grid (G), grid opacity, place names (N). The Advanced page:
power saving, preload next season, exclusive fullscreen (Windows), and **Developer tools** (`dev/developer_tools`: the
sandbox entry, F3 and Ctrl/Cmd+R; On until M12).

---

## 7. The HUD and the overlays

Placement uses the layout of 3.1. "Contract" says what the piece reads and what it sends. Recommendation: **1.5** (the
first slice), a milestone, or **skip**.

| Overlay | Placement | Contract | When |
|---|---|---|---|
| Top bar | full width, 40 px, under nothing | 1.5: map name and "Sandbox, seed N"; right: Layers, `?`, menu. M2: country arms and name, map-mode toggles. M3: date, season, End season (primary, Space). M4: resource chips (Ducats, Stores). M5: the People and Food chips. Reads `Session.game`, `Events`; sends intents and `ctx.app_requested` | **1.5** frame |
| Zoom control | bottom right of `MapArea` | `+`, a vertical slider (log scale between the limits), `-`, fit. Sends `zoom_step_requested`, `zoom_set_requested`, `fit_requested`; listens to `CameraRig.view_changed` | **1.5** |
| Scale bar | bottom right, left of the zoom control | km per logical px = `map.hex_w_km / (104 x zoom)` (a hex is 28 km across its 104 px cell); the bar takes the longest of 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000 km that fits in 120 px. Pure `ScaleBar.pick(km_per_px, max_px)` | **1.5** |
| Hover card on the map | next to the pointer, kept inside `MapArea` | after the tooltip delay with the pointer still on one hex, not over the UI, not dragging: `HexCard.of(game, hex)` from `core/views` (hex column and row, place, cover, height in metres, relief level, winter climate, rivers, roads, pass, what stands and its level; the owner from M2, people M5, army M6). Listens to `MapInput.hover_changed` and `Events.hex_changed` | **1.5** |
| Layers popover | a top-bar button opening a `PopupPanel` | grid, place names, relief shading, season preview (Spring, Summer, Autumn, Winter); borders and owner tint in M2. Writes `Settings` (or `season_preview_requested`); the map scene applies | **1.5** |
| Villages switch | | dropped by the M1 spec (all villages show) | **skip** (unless the owner wants it back) |
| Map-mode switcher | top bar, a `Segmented` group, keys 1-4 (more as modes arrive) | Terrain (the tiles), Owner, Relief (a height tint); later Yields (M4.5, key 4: your land by worth a year, `m4-5-build-spec.md` 4.8), Food (M5, key 5: your land by food made less eaten, a year, `m5-build-spec.md` 6.5), Supply (M6, key 6: your land by where your armies are fed, `m6-build-spec.md` 6.6) and Trade (M10). A mode is drawn by **one overlay node**: a full-map quad with a shader that finds the hex under each pixel (odd-r) and reads two one-byte-a-hex textures (owner id, height band) and a palette (`core/views/map_modes.gd` builds them; `m2-build-spec.md` 6.2). One draw for any mode; a mode switch is a uniform; an owner change rewrites one texel | M2 |
| Minimap | bottom right, above the zoom control | draws the far picture's `ImageTexture` (shared with `FarMap`; no extra memory), the camera's rectangle from `view_changed`; a click or drag sends `look_at_requested`. On north Italy the whole map fits the screen, so it matters from Europe on; with owner colours from M2 it is useful earlier | M2 |
| Place search ("go to") | a `LineEdit` popup, Ctrl/Cmd+F | matches `MapData.places` by name (prefix first, then substring, then accent-free); Enter glides there and selects the hex | M2 |
| Camera bookmarks | Ctrl/Cmd+1..9 jump, Ctrl/Cmd+Shift+1..9 set | stored with the game (the save's UI block), so they follow the map and the country; a toast "Bookmark 3 set" | M3 |
| Hex menu on right click | a `PopupMenu` (not a radial: Godot's menu is keyboard-ready and themed) | the selected hex's actions from `Session.check` (build, upgrade, clear), each acting through `Session.act`. Only when no army of yours is selected (then a right click is an order); M6 adds "Raise companies here", the armies on the hex and "Show supply" (`m6-build-spec.md` 6.8) | M6; **skip** the radial |
| Toasts | bottom centre, above the log | `ctx.toast_requested(text, tone)`: refused key actions now, events from M3 | **1.5** |
| Notifications | top right under the bar, a short stack | from `Events` (war declared, a battle, a work finished); click goes to the place | M3, M7 |
| Action log | bottom left, above the key hints: closed, a 40 px icon button (kit `log`, tooltip "Log", badge of unread lines, takes no room); opening slides the card up from it (160 ms, reduce motion sets it at once); the icon or Esc closes it | `Events` to lines (`shell/hud/log_feed.gd`), filters All, War, Money, Mine; links glide the camera | M3 |
| "What changed" after a season | a card centred low, dismissed by Space, Esc or a click | built from the season's events (`Events.season_ended(summary)`): income, works finished, growth, battles; the task flag beside it | M3 |
| Undo the last build this season | "Cancel the work" in the hex panel; Ctrl/Cmd+Z, shown as a key cap in the toast (toasts take no clicks) | **not Godot's `UndoRedo`**: game state changes only through actions. A rules action pair `cancel_work_check` / `cancel_work` (a work started this season is cancelled with a full refund) | M3 (the action, with works that take seasons; `m3-build-spec.md` 4.3); the refund M4 |
| Pause dim | the stack's shade | section 3.2 | **1.5** |
| Confirm modals | centred | section 5.3 | **1.5** |
| AI-turn pill | top centre under the bar (the mockup's pill) | `BusyPill`: "Countries are moving 3 / 12" while the other countries think in slices, "The season ends", then "The moves of Summer 1480 · Space skips them" in the replay; meanwhile the map takes only camera moves (`MapInput.block_orders`) | M8 (`m8-build-spec.md` 6.1, 6.2) |
| Loading overlay | new game: the `Loading` screen ("Building the map", then "Drawing the map 63 %" from `MapScene.fill_progress()`); a season swap that takes over 200 ms: a small pill at the top, "Changing season 40 %" | reads the map scene's progress | **1.5** |
| Help overlay | centred card | section 4.6 | **1.5** |
| Tutorial hints | bubbles anchored to Controls by node path, from a hint table (`.tres`) | the hints option | M12 |
| Screenshot | F12 | `get_viewport().get_texture().get_image().save_png(...)` to `user://screenshots/`; a toast with the file name | **1.5** |
| Photo mode | H | hides the HUD (exists); names stay as set | **1.5** (kept) |
| F3 debug panel | top left under the bar (developer tools on) | four times a second: frames a second and the worst frame of the last second; `Performance` `TIME_PROCESS`, `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_OBJECTS_IN_FRAME`, `MEMORY_STATIC`, `RENDER_VIDEO_MEM_USED`, `RENDER_TEXTURE_MEM_USED`; from the view: chunks, layers, cells, line chunks, hexes on screen, fill and swap progress; zoom, season, seed, map digest (short), renderer. Controls: season preview, New seed, layer switches (grid, shade, light, trees, lines, far picture locked), far-zoom switch point, slice budget | **1.5** |
| Developer console | a `LineEdit` at the foot of the F3 panel, F2 | commands are `Session.act` names with arguments (`build 12 7 wheat`), plus `end n`, `goto c r`, `look`, `give`, `digest`, `seed`; a history (`m3-build-spec.md` 6.13) | M3 (with the action log and its replay), developer tools only |

---

## 8. Rendering controls and performance

- **Layer switches** are view state, kept in `Settings` (`map/grid`, `map/place_names`, `graphics/relief_shading`) and
  applied by the map scene with `TileMapView.set_layer_visible`. They never touch the game.
- **The season picker** is a look preview until M3 (keys 1-4 until M2, when they become the map modes; the Layers
  popover and the F3 panel until M3). From M3 the season is the calendar's, and the preview lives only in the F3 panel
  (developer tools).
- **The minimap** is M2, drawn from the far picture's texture.
- **Map modes** are one shader overlay with a data texture (section 7), not one `TileMapLayer` per mode: one draw,
  any number of modes, a pixel a changed hex.
- **Budget.** The UI must keep the 16 ms frame of the standard at every zoom. Rules: the HUD redraws on events and on
  `view_changed`, never builds nodes every frame; labels that change (the F3 panel) update four times a second; a
  screen push takes under 16 ms (measured by the UI probe); tooltips and cards are made once and refilled. The perf tool
  (`tools/perf_map.gd`) runs without the HUD; the UI probe measures the frame with the HUD up.
- **Compatibility renderer.** No 3D, no shaders in the UI: baked 9-slice textures (`StyleBoxTexture`), `StyleBoxFlat`
  for the flat pieces, and fonts (`ui-style-and-feedback-spec.md` section 4). The mode overlay
  shader is plain GLSL ES 3.0 that the Compatibility renderer runs; it is a map layer, reads only its own textures and
  never the screen, and the minimap uses the same material on its copy of the map (`m2-build-spec.md` 1.2).
- **Stretch and HiDPI** as in 6.2. The art is baked at 1x, so on a Retina screen at UI scale 2 the map is upsampled x2 at
  zoom 1; a 2x bake is a question for the map-look milestone (section 11).
- **Power.** `OS.low_processor_usage_mode` on by default: a still map draws nothing (section 6.2). The background
  frame cap does the rest.

---

## 9. Testing

| What | How | Where |
|---|---|---|
| `ZoomModel`: fit, limits, notch, anchor (the map point under the pointer does not move), bounds, smoothing converges | GUT, pure functions | `tests/shell/test_zoom_model.gd` |
| `Bindings`: every action exists after `ensure()`; no event bound twice in one group; overrides applied and reset; text round trip of every default event | GUT | `test_bindings.gd` |
| `EscLadder`: each state gives the right step | GUT, a table of cases | `test_esc_ladder.gd` |
| `CameraRig`: synthetic `InputEventPanGesture`, `InputEventMagnifyGesture`, wheel with `factor`, Ctrl+wheel, Shift+wheel, drags past and inside the slop, keys; limits and bounds hold | GUT, events sent to the node's `_unhandled_input` (as `test_map_scene.gd` does) | `test_camera_rig.gd` |
| `MapInput`: click selects, right click clears, hover changes only on a new hex, N, G, U | GUT | `test_map_input.gd` |
| UI covers the map: a click on the hex panel or the top bar selects nothing; the wheel over a scroll list does not zoom | GUT in a 1280 x 720 `SubViewport` with `push_input` (the GUT window is 64 px square) | `test_app.gd` |
| `ScreenStack`: push, pop, remove, replace, clear; `wants_pause` and `hides_world`; the shade under the top modal; focus given back | GUT | `test_screen_stack.gd` |
| `Settings`: round trip; a broken file, a wrong type, an unknown key, an out-of-range value give the defaults; atomic write; platform defaults | GUT on `user://test_settings_*.cfg` | `test_settings.gd` |
| `Display` pure helpers: auto scale per platform; a remembered rectangle off every screen is moved on; presets filtered by the usable rect; the logical size | GUT | `test_display.gd` |
| Theme: every variation the screens use exists; `build_theme.gd --check` | GUT, CI | `test_theme.gd` |
| Kit: `set_verdict` disables and puts the reason in the tooltip; `OptionRow` per type; `KeyCap` shows a rebinding | GUT | `test_kit.gd` |
| Screens: each opens in the `SubViewport`, its default focus is set, Esc does what the ladder says, every button does its thing (pause: Main menu with unsaved actions asks first); Options: every schema key has a row; Help lists every action | GUT, GUT's `InputSender` for keys | `test_pause_menu.gd`, `test_options.gd`, `test_help_overlay.gd`, `test_main_menu.gd` |
| `HexCard`, `ScaleBar.pick` | GUT, pure | `tests/core/test_hex_card.gd`, `test_scale_bar.gd` |
| The flow: boot, main menu, sandbox, Esc, options, back, main menu (asks), sandbox again | GUT on the App in a `SubViewport`; tests check `App.wants_pause()` rather than pausing GUT's own tree | `test_app_flow.gd` |
| **Monkey**: seeded (`core/rng.gd`) random events from a whitelist (bound keys but quit, clicks anywhere and on visible buttons, wheel with factors, gestures, drags), 600 a seed, 3 seeds. After each: no error, the stack is consistent, zoom inside the limits, centre inside the bounds, paused exactly when a modal is up, the game's digest changes only after a successful action. A `KNOWN_ISSUES` table as in Python's monkey | GUT | `test_ui_monkey.gd` |
| **Pictures and frame times** with the UI: main menu, sandbox fitted, zoom 1 with a hex selected and its card, pause, every options page, help, F3, a confirm; at 1280 x 720 scale 1 and 2560 x 1440 scale 2; the frame time of each screen's first frame | windowed tool, like `tools/worldmap/shot_north_italy.gd`; CI runs it under xvfb with Mesa (as the perf job) and keeps the pictures as artifacts. Goldens come when the look is signed (standard section 6) | `tools/ui/shot_ui.gd` |
| **Engine facts** that this spec relies on: the content scale gives the logical size; vsync fallback; minimum size; tooltip delay read live; window mode round trip; Cmd+Q is a close request; `gui_get_hovered_control` | windowed probe, prints PASS or FAIL per fact; run on the Mac and on Windows by hand, on Linux in CI | `tools/ui/probe_display.gd` |
| **Trackpad** | cannot be scripted. `tools/ui/probe_input.gd` prints every raw input event; the owner runs it once on the MacBook (scroll, pinch, two-finger click, Ctrl-click) and the log sets `GESTURE_PAN_PX` and the signs. Then the playtest checklist in the plan | by hand |

**From Python's `tests/ui`:** `UITestCase` with `driver.at(frame, key(...))` becomes GUT tests with `InputSender` and
`wait_frames`; the monkey's whitelist, invariants, seeds and `KNOWN_ISSUES` carry over; the goldens become the windowed
picture tool now and true goldens later.

---

## 10. Risks

- **Engine facts not yet seen working** (HiDPI window units on macOS, the content-scale mechanism, Ctrl-click as right
  click, tooltip delay live, ASTC on the Mac's Compatibility driver, Cmd+Q as close request). Guard: the display probe
  (U8) and G1 run before the screens are built on them; each has a stated fallback.
- **Trackpad feel** cannot be tested in CI. Guard: the input probe log and the owner's playtest on the MacBook.
- **Texture memory on the Mac** (up to about 1.2 GB with the next season loaded). Guard: G1 in the first slice; the
  preload option ships now.
- **Pausing the tree halts the sliced loading** under a modal screen. Accepted: loading resumes when the screen closes.
- **The first slice is large** (17 build tasks and one probe). Guard: groups that run in parallel; group E (texture
  quality) waits for the probe and may not be needed.
- **The Theme is generated:** a hand edit in the editor is overwritten. Guard: the CI check and a header comment.
- **Settings files are user input.** `ConfigFile` can parse objects; the schema accepts only plain types.
- **Retina sharpness:** the 1x art is upsampled on a Retina screen at zoom 1.

---

## 11. Questions for the owner

The recommendation comes first. Defaults are taken as recommended until the owner says otherwise.

1. **Trackpad two-finger scroll:** *pan, and pinch to zoom* (as in Maps), or zoom (as the wheel does).
2. **What the game opens on:** *the main menu* (Map sandbox one click away; `-- --sandbox` skips it), or straight onto
   the map as today.
3. **Zoom range:** *from the whole map to 2.0* (today 0.03 to 4.0).
4. **Fonts:** answered by the owner's approval of Studiolo (2026-11-17): *Cinzel and the Alegreya family*, all OFL
   (section 3.4).
5. **The hex panel's colours move to the kit's tokens** (its gold becomes the kit's brighter gold): *yes*.
6. **Minimap:** *M2* (with owner colours), or now, or with Europe.
7. **Keys 1-4:** *the season preview now, the map modes from M2* (as in Python); the preview stays in the Layers
   popover until M3, then F3 only.
8. **The Mac's texture memory:** *try the ASTC import first*, add Texture quality (Half) only if it fails; and should
   the Mac skip preloading the next season by default?
9. **Retina sharpness:** accept the 1x art upsampled on Retina for now, *and ask for a 2x bake in the map-look
   milestone*?
10. **Power saving on by default** (a still map draws nothing): *yes*.
11. **Map sandbox** stays on the main menu *until M12, behind the Developer tools option*.
12. **Undo** is *"cancel a work started this season, with a refund" (M4)*, not a general undo.
