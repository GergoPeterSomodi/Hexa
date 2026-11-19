# UI style (Studiolo) and feedback screens: the spec

Technical director, 2026-11-17. **Status: a proposal. Design only: nothing is built before the owner's go.** It turns
two approved designs into buildable interfaces: the look (`docs/design/ui/design.md`, "Studiolo") and the feedback
screens (`docs/design/ui/game-feedback-screens.md`). Tasks: `docs/architecture/ui-style-and-feedback-plan.md`. Visual
acceptance reference: the mockup in `docs/design/ui/studiolo/`.

Controls, the screen stack, settings and menu behaviour stay in `ui-and-controls-spec.md` ("the UI spec"); section 2
lists where this page replaces it, and there this page wins.

## 1. Assumed decisions

The open questions of `game-feedback-screens.md` D.7, taken as recommended.

| # | Decision | Cost to reverse |
|---|---|---|
| 1 | The report opens every season: **Full** by default; Brief and Off in Options | One default |
| 2 | **Seasons change output**, stocks carry goods: a requirement on the M4 economy design (7.3) | Free before that design is signed (a flat strip hides itself); an economy redesign (L) after |
| 3 | **M4.5 "Insights I"**, then each study page with its system | A plan re-order (S) before M4.5 starts |
| 4 | Others' numbers: **known countries only, banded** | Two functions of `Knowledge` (S) |
| 5 | **The ledger is the study's Economy page** (L) | One dock panel over the same view (M) |
| 6 | Confirm a work **only when expensive**; `cancel_work` undoes | One default |
| 7 | History: **40 seasons plus a row a year** | `Stats.RING` now; a save upgrade after the first public release (M) |
| 8 | **Districts change their ring**, a little | Zero ring terms; the ring row hides (S) |

**Engineering refinements of the design pages, decided here:**

1. Baked textures go to `godot/assets/ui/kit/` (the standard's `assets/ui/`), not `assets/baked/ui/`.
2. `▲ ▼ ✓ ✗` are kit **icons** tinted by tone, not font glyphs. Fonts must carry Latin Extended-A and `→ ↑ ↓ − · ×`.
3. The feedback page's `Vellum*` text styles are `LabelInk*`.
4. `Stats`' system is `StatsSystem` (`core/systems/stats_system.gd`): two `stats.gd` files would share a class name.
5. `cartouche` and the plain `seal` are baked in slice 1 (M1.5's hex panel and confirm use them); the ribbon grows to
   two lines, as `confirm.jpg` shows.
6. `cancel_work` arrives in **M3** with works that take seasons (UI spec: M4); its refund in M4.
7. `InkChart` ships two kinds in M4 (the works card and "This season" need them); M4.5 completes it.
8. From M4, **U opens the works card** with "Begin the work" focused (Enter or U again begins).
9. The bake needs **numpy, pygame and fonttools**, pinned in `tools/requirements-bake.txt`; numpy is new to the repo.
10. The season preview stays in the Layers popover and F3 **until M3**.

## 2. What stays, what this replaces

**Stays:** the scene tree, screens and stack, input routing, "one generated Theme, checked in CI", the token
**names**, the 4 px grid, the 40 px top bar, controls, menu behaviour, options, HUD placement, budgets and tests.

| UI spec | Change |
|---|---|
| 1, 8, 11 Q7; plan 4 M2 | The season preview leaves the Layers popover at **M3** (the plan said M2); keys 1-4 become map modes in M2 |
| 3.1; plan 4 M12 | `menu_bg` from M1.5, not M12 |
| 3.4 | Studiolo token values and new tokens (4.2); Cinzel and the Alegreya family for Gelasio and Selawik (4.3); baked 9-slice `StyleBoxTexture` for "radius 5" `StyleBoxFlat` (4.5, 4.7). The lint also forbids `StyleBoxFlat.new`, `StyleBoxTexture.new` and `assets/ui/kit` paths outside `shell/ui/` |
| 3.5 | Plus section 5; icons come from the kit bake, not `assets/ui/icons.png` |
| 4.1 | The close request is section **5.3**, not 5.4 |
| 5.1 to 5.3, 5.7 | Menu: wordmark, "Anno Domini MCDLXXX", framed column at x = 270, wind rose. Pause: ribbon, `ButtonMenu`, Resume primary, Quit danger. Confirm and credits on `VellumSheet`, the countdown in the seal |
| 6.5 | High contrast is built flat; also the low-memory theme (4.9) |
| 6.7 | 860 x 580; Back in the header; footer Defaults and **Apply** (commits staged window rows, then the 10 s question). Rows follow `Settings.SCHEMA`, not the mockup's samples |
| 7 | The "What changed" card becomes the season report; `season_ended(turn: int)`; `cancel_work` in M3; walnut plank, medallion chips, year medallion, swallow-tail toasts, hexagon minimap frame, key hints (`shell/hud/key_hints.gd`) |
| 8 | "`StyleBoxFlat` and fonts only" becomes baked 9-slices, the flat list and fonts; **no shaders in the UI** (Controls, the Theme, the HUD and screens). Map layers may use a canvas shader that reads only its own textures, never the screen: the M1 shadow group and the M2 map-mode overlay (`m2-build-spec.md` 6.2), which the minimap also draws over its copy of the map |
| plan 4 M3, M4 | `shell/screens/season_report.*` (was `shell/hud/`); the ledger is the study's Economy page (was `shell/panels/ledger.*`) |

## 3. What is there today (master `d28e5e8`)

One hand-written `shell/ui/theme.tres` on the hex panel only; no fonts or `assets/ui/`; `Game` has no turn, version,
action log or season table.

## 4. The style system in Godot

### 4.1 Files

`godot/shell/ui/` (`tokens.gd`, the generated `theme.tres` and `theme_high_contrast.tres`, `kit_theme.gd`,
`motion.gd`), `godot/tools/build_theme.gd`, `godot/assets/ui/kit/` and `menu/`, `godot/assets/fonts/`; in Python
`tools/bake_ui.py`, `tools/ui_bake/`, `tools/requirements-bake.txt`, `tests/test_bake_ui.py`.

### 4.2 Tokens

One constant a line, in a form GDScript and the bake's regex both read: `const BG := Color("#14100c")`. The bake parses
the file; no colour is typed twice. **Values: the colour and material tables of `design.md` 3, unchanged**
(`SHADE #070504b8`, `GLOW #ffd98a73`). Added:

| Group | Tokens |
|---|---|
| Ink on vellum | `GOOD_INK #12605a`, `BAD_INK #a8321a`, `WARN_INK #8f4a08`, `GOLD_INK #75510f`, `INK_LINE #1f181152` |
| Chart inks (ratio on vellum; second cue) | `CHART_IRON #2b2219` (12.2; solid, dot), `CHART_LAPIS #1f3f7a` (8.0; dash, square), `CHART_MADDER #a8321a` (5.3; dotted, triangle), `CHART_VERDIGRIS #12605a` (5.8; dash-dot, diamond), `CHART_OCHRE #75510f` (5.6; long dash, cross) |
| Map | `MAP_SELECT #ffd646` |
| Sizes (px) | `S1` 4 to `S6` 24; `BAR_H` 40; `BUTTON_H` 28 (small 24, menu 42); `MEDAL` 64, `MEDAL_SM` 30; `PANEL_W` 296; `TARGET_MIN` 24; `MENU_COLUMN_X` 270 |
| Sets | `LAPIS_AND_GILT` (the fallback of `design.md` 2). `HIGH_CONTRAST`: fields `#000000`; text and ink `#ffffff`; muted tones `#d0d0d0`; `LINE`, `GOLD`, `BRASS` `#ffd646`; ink tones take `GOOD`, `BAD`, `WARN` |

### 4.3 Type and fonts

Static TTFs, each folder with `OFL.txt`, credited in `godot/CREDITS.md`: `cinzel/Cinzel-Bold`,
`alegreya/Alegreya-MediumItalic`, `alegreya_sc/AlegreyaSC-Bold`, `alegreya_sans/AlegreyaSans-Regular`, `-Medium`,
`-Bold`, `noto/NotoSans-Regular` (the fallback). `CinzelDecorative-Black` is a bake input only
(`tools/ui_bake/fonts/`). Import (committed): grey antialiasing, light hinting, no MSDF, no system fallback.

`build_theme.gd` wraps each face in a `FontVariation`: Alegreya Sans and SC with
`opentype_features = {lnum: 1, tnum: 1}` (`TextServer.name_to_tag`);
Cinzel with `spacing_glyph = round(size x em)` (Godot spaces in pixels): 0.14 em on ribbons and menu buttons, else
0.10. The kit upper-cases Cinzel texts.

| Variation | Font, size | Colour |
|---|---|---|
| `TitleRibbon`, `TitleModal`, `TitleBrand`, `TitlePanel` (cartouche) | Cinzel Bold 20, 19, 17, 16 | `BRASS_HI` |
| `ButtonMenu` text | Cinzel Bold 15 | `TEXT`; `#1c1206` on primary |
| `SectionHead`, `TableHeader` | Alegreya SC Bold 16, 13 | `GOLD` |
| `Number`, `NumberGood`, `NumberBad`, `NumberWarn` | Alegreya Sans Bold 16 | `TEXT`, `GOOD`, `BAD`, `WARN` |
| `Label` (default, buttons); `KeyCap` | Alegreya Sans Bold 14; 12 | `TEXT`; `VELLUM_INK` |
| `Body`, `TableRow`; `Hint`, `Reason` | Alegreya Sans Medium 15, 14; Regular 13 | `TEXT`; `MUTED` |
| `LabelInk`, `LabelInkMuted`; `LabelInkHead` | Alegreya Sans Medium 16, 15; Alegreya SC Bold 16 | `VELLUM_INK`, `VELLUM_MUTED`; `GOLD_INK` |
| `NumberInk`, `NumberInkGood`, `NumberInkBad`, `NumberInkWarn` | Alegreya Sans Bold 16 | the ink tokens |
| `LabelFlavour` | Alegreya Medium Italic 17 | `VELLUM_MUTED` (`MUTED` on leather) |

Cinzel never sets a number. The `Hex*` types stay as aliases until task H1.

### 4.4 The bake tool

```
python tools/bake_ui.py [--out godot/assets/ui] [--only panel_*] [--scale 1,2] [--jobs N] [--sheet out.png]
python tools/bake_ui.py --check     # rebuild in memory, compare with ui_kit.json and the PNGs
```

`tools/ui_bake/` follows the tile bake's conventions (plain modules, one entry, a JSON index, no map input):
`tokens`, `noise`, `light`, `shapes`, `materials`, `checks`, `png` and one `pieces_*` module a slice. A piece is a
function of a scale `s` (1 or 2) registered with its size, margins and slice: **the catalogue in code writes
`ui_kit.json`**. Inputs: `tokens.gd`, the bake fonts, `tools/ui_bake/inputs/menu_map.png` (north Italy at fit, summer,
1920 x 1080; made once by the windowed `godot/tools/ui/shot_menu_map.gd`, committed).

**Determinism.** Pixel paths use only `+ - x /`, `sqrt`, `floor` and comparisons on float64, and uint32 hashing: equal
on every IEEE machine. No trigonometry, `exp` or `pow`: angles are literal constants, ramps piecewise-linear tables,
conic brass uses the diamond angle `y / (|x| + |y|)`, blurs are box passes; 2x is the recipe at `s = 2`, never an
upscale. `--check` compares the **SHA-256 of the RGBA bytes** (PNG bytes vary with zlib); the font-drawn `wordmark`
has a tolerance. CI runs it on Python 3.12 (pygame has no 3.14 wheels).

**Recipes.** Colours and stops are those of `kit.css` (rule or variable named); the look is matched and signed on the
contact sheet, not the SVG filter's bits:

| Material | Recipe |
|---|---|
| Noise | Value noise on an integer lattice (uint32 hash), wrapped at the tile's period (seamless tiling); `3t^2 - 2t^3`; octaves halve |
| Leather (`--t-leather`) | Height: 0.42 cycles a px, 3 octaves, period 96. Normal from central differences x 1.1; light `(-0.332, -0.332, 0.883)` (azimuth 225, elevation 62). Colour `PANEL_BG x (1 + 0.04 x shade)`. Panels add a top glow (7 % at most) and a 22 px inner vignette |
| Walnut (`--t-wood`) | 0.006 x 0.19 cycles a px, 4 octaves, through the CSS's six-stop RGB table; a diagonal `#7a5230`, `WOOD`, `WOOD_DARK`; turned 90 degrees on vertical bands |
| Brass (`--gilt`, `--plate`, `--t-brush`) | The two vertical ramps; streaks 0.012 x 0.85, 2 octaves, warm white at `0.9 n - 0.3` |
| Vellum (`--t-vellum`) | `VELLUM` under blotches `(.45, .32, .14)` at `0.55 n - 0.14` (0.035, 5 octaves, period 320), clamped to 4 %; a 26 px edge burn inside the content margin |
| Velvet, lapis, wax, bone | The ramps of `.ribbon`, `.medal`, `.seal`, `kbd`; the wax outline wobbles 2 % |
| Bevel (`.btn`) | From the shape's signed distance (chamfer 6 px, pointed ends 17, swallow-tail 14, circle, stud, boss): 2 px gilt edge; face with a 1 px lit top line, a 3 px lip, a 1 px inner line. Hot: face x 1.2, a 14 px inner `GLOW`. Pressed: ramp inverted, 7 px top shadow, content 1 px lower. Off: flat `BUTTON_OFF`, pewter edge |
| Wordmark (`.wordmark`) | "HEXA", Cinzel Decorative Black, 0.10 em; pygame.freetype coverage at 4x, box-reduced; the five-stop gilt ramp (horizon at 54 %), 1 px light top edge, 3 px `#4a3209` extrusion, shadow, 26 px glow |
| Menu art | `menu_bg`: `menu_map.png` graded (saturation 0.85, sepia 0.22, brightness 0.82). `menu_shade`: the three static gradients (the map drifts under them) |

**Asserts** (the bake fails; `--check` runs them):

- **Contrast:** every pair of `design.md` 3 reaches its stated ratio; each chart ink and ink tone is 4.5:1 on `VELLUM`.
- **Leather:** inside the content rect of every leather texture, `FAINT` is 4.5:1 or more on **every** texel (lightest
  allowed: about `#2f231a`); this caps the glow.
- **Vellum:** inside the content rect every texel has luminance 0.66 or more (about `#e1d5b8`), so `BAD_INK` and
  `WARN_INK` keep 4.5:1. The mockup's darkest blotch (0.58) would fail.
- **Amplitude:** 4 % or less on every text field.
- **Fonts** (fonttools): each TTF's `cmap` covers Latin-1, Latin Extended-A, `→ ↑ ↓ − · × %` and every character of
  the names in `godot/data/geography/`; Alegreya Sans and SC have `lnum` and `tnum`.
- **Geometry:** a centre of 8 px or more; a tiled centre equals itself shifted by its period; 2x is twice 1x.

### 4.5 The asset catalogue

Sizes at 1x in px. M: 9-slice margin (left, top, right, bottom when they differ); C: content margin; E: expand margin.
All also baked at 2x except the menu art. Import: lossless, no mipmaps; never VRAM-compressed (it breaks hairlines).

| Texture | Size | M / C / E; centre | Slice |
|---|---|---|---|
| `panel_frame` | 160 x 160 | M 32; C 20; E 0, 0, 0, 10; tile | 1 |
| `panel_modal` (bosses overhang) | 192 x 192 | M 48; C 28; E 24; tile | 1 |
| `panel_vellum` | 160 x 160 | M 32; C 24; E 24; tile | 1 |
| `panel_card` | 48 x 48 | M 12; C 10 | 1 |
| `panel_bar` | 128 x 48 | M 8, 4, 8, 10; C 8, 4, 8, 8; E 0, 0, 0, 8; tile x | 1 |
| `button_{secondary,primary,danger,toggle}_{normal,hot,pressed,off}`, `toggle_on`, `focus` | 64 x 40 | M 14; C 14, 4 | 1 |
| `button_menu_{secondary,primary,danger}_{normal,hot,pressed,off}` | 96 x 42 | M 28, 21; C 34, 0; fixed height | 1 |
| `ribbon` | 128 x 40 | M 36, 12; C 36, 8; min width 230 | 1 |
| `toast`; `cartouche` | 128 x 40; 96 x 36 | M 36, 20; M 24, 18; fixed height | 1 |
| `slot`, `plate`, `nav_selected`, `nav_selected_ink` | 32 x 24 | M 10; C 10, 2 | 1 |
| `switch_off`, `switch_on`; `grabber`, `grabber_hot`; `keycap`, `keycap_wait` | 48 x 24; 24 x 24; 32 x 28 | keycap M 10 | 1 |
| `progress_fill`; `seal`; `stud`; `glow_soft`; `rule_diamond` | 32 x 12; 72 x 72; 12 x 12; 64 x 64; 256 x 12 | glow M 24 | 1 |
| `icons_base` (arrows, tick, cross, lock, dash, close, menu, help, zoom) | 128 x 32 | 16 px cells | 1 |
| `wordmark`; `rose`; `menu_shade`; `menu_bg` | 1024 x 256; 512 x 512; 480 x 270; 1920 x 1080 | | 1 |
| `minimap_frame`; `shield_rim`, `shield_rim_sm`; `pennant_pole`, `pennant_cloth` (white, tinted at run time) | 256 x 144; 48 x 56, 20 x 24; 24 x 56, 28 x 20 | frame M 56, 16 | 2 (M2; the arms are polygons drawn in code under the rim, so no mask: `m2-build-spec.md` 7.2) |
| `medallion_64`, `medallion_30`, `dial_quarters`, `dial_hand`, `hourglass` | 64, 30, 64, 64, 24 square | | 3 (M3) |
| `endseason_plate_{normal,hot,pressed,off}`; `seal_good`, `seal_plain`, `seal_cracked` | 160 x 44; 72 x 72 | plate M 28, 22, 44, 22 | 3 (M3) |
| `vellum_inset`; `strip_cell`, `strip_cell_now` | 96 x 96; 48 x 48 | M 16, C 10, tile; M 12, C 6 | 4 (M4) |
| `icons` (about 48 two-tone woodcut icons) | 256 x 128 | 24 px cells | 4 (M4) |

### 4.6 `ui_kit.json`

Schema `hexa-godot/ui-kit/1`: `tokens_sha`, and a piece: `size`, `margin`, `content`, `expand`, `axis`,
`fixed_height`, `min_width`, `slice`, `sha` (`1x`, `2x`), `check` (`exact`, `tolerant`). Lengths are logical px.
`tokens_sha` hashes the constants of `tokens.gd`: a token change without a re-bake fails `--check`.

### 4.7 The generated Theme

`godot/tools/build_theme.gd` is a `SceneTree` script like `build_tileset.gd` (the same `_plain` id stripping and
`--check`). It reads `Tokens`, `ui_kit.json` and the imported fonts and writes the two `.tres` files; each
`StyleBoxTexture` takes its margins and `axis_stretch_*` from the JSON. Single textures (seal, medallions, icons as
`AtlasTexture`s) are Theme **icons** of the type `Kit`: a control asks `get_theme_icon(&"seal", &"Kit")` and never
names a file. `--check` also asserts through the engine that every variation exists, each font `has_char` for the
required set, and `1111` measures as `0000` in `Number`. **Stays `StyleBoxFlat`:** row hover, rules, scrollbars,
`LineEdit` insets, the shade, the F3 panel, the high-contrast theme. Existing variations keep their names.

New variations: `PanelVellum`, `PanelVellumInset`, `PanelSlot`, `PanelStripCell`, `PanelStripCellNow`, `PanelRibbon`,
`PanelCartouche` (each the texture of its name); `ButtonMenu`, `ButtonMenuPrimary`, `ButtonMenuDanger`
(`button_menu_*`); `ButtonEndSeason` (`endseason_plate_*`); `ButtonMedallion` (empty boxes: the medallion is a child);
`ButtonNav`, `ButtonNavInk` (`nav_selected*` when pressed, `ROW_HOVER` on hover); `ButtonTab` (`toggle`, `toggle_on`);
`StudyTree` (a Tree with the `TableHeader` and `TableRow` fonts, `ROW_HOVER`, `LINE` guides); `InkChart` (colours and
a font only: `ink_0` to `ink_4`, `axis`, `grid`, `good`, `bad`, each also in a `_slot` form for dark grounds).

### 4.8 1x or 2x, by UI scale

`KitTheme.load_for(scale: float, kit: StringName) -> Theme`; `kit` is `dev/ui_kit`. `auto`: 2x when
`content_scale_factor` is 1.5 or more, else 1x; `plain` or `accessibility/high_contrast`: the flat theme.
**One Theme file, two texture sets:** for 2x, `KitTheme` duplicates `theme.tres` and swaps each kit texture for its 2x
picture wrapped to **report its 1x size** (`ImageTexture.set_size_override`), so margins stay logical, layouts are
identical, and at scale 2 the 2x pixels are sampled one to one. Probe P2 proves it on the Compatibility renderer.
Fallback B: `StyleBoxKit`, a script `StyleBox` whose `_draw` scales a doubled nine-patch by 0.5. Fallback C: 1x only
(soft at 200 %), with the owner's word. The App sets `get_window().theme` at start and after a UI-scale change;
`project.godot` names `theme.tres`. Fonts need nothing: Godot rasterises them at the real size.

### 4.9 High contrast and low memory

`theme_high_contrast.tres` is built from `Tokens.HIGH_CONTRAST` with `StyleBoxFlat` only: black fields (vellum too),
white text (21:1), 2 px `#ffd646` borders, a 3 px `INFO` focus ring; only the icon atlases load. Built from S0 because
it is also the **fallback when a texture probe fails**; reachable through `dev/ui_kit = plain` and `-- --plain-ui`;
the player's row arrives in M12. Charts follow: `InkChart` reads the Theme.

### 4.10 Memory budget

RGBA8: the 1x kit (slices 1 to 4) is **1.5 MB**, the 2x kit **6.1 MB**; the menu art (2.6 MB, and `menu_bg` 8.3 MB)
is loaded by the main menu (no `preload`) and dropped when a game starts; font atlases are capped at 8 MB. Budgets as
`design.md` 9: **1x under 4 MB, 2x under 16 MB in play**, one kit in memory; `perf_ui.gd` fails past them.

### 4.11 Motion: tweens, no shaders

`Motion` makes every UI tween: bound to its node, running under pause (`TWEEN_PAUSE_PROCESS`), on `modulate`,
`position`, `scale` or `rotation` only. With `accessibility/reduce_motion` every helper sets the end state at once;
the option's first-run default follows the system (`DisplayServer.accessibility_should_reduce_animation()`, to confirm
in P2).

- **Hover glow:** the hot state is a baked texture the Theme swaps at once. Primary, menu, medallion and End season
  buttons add one lazy child `Glow` (a `NinePatchRect` of `glow_soft`, mouse ignored): `modulate.a` 0 to 1 in 120 ms on
  hover or focus, back on exit.
- **Seal press:** pivot at the centre; `scale` 1.15 to 1.0 in 180 ms (cubic out), alpha 0 to 1 in the first 60 ms.
- **Panel enter:** `ScreenStack.push` calls `Motion.enter(frame)`: alpha 0 to 1 and `position.y` +6 to 0 in 120 ms;
  the frame sits in a plain `Control` so no container fights the offset.
- **Page cross-fade:** pages share one plain `Control`; `Motion.cross_fade(out, in)` crosses the alphas over 120 ms,
  then hides `out`. No `CanvasGroup` (it reads the screen).
- **Busy, drift, rose:** End season's `Ring.rotation`, a turn in 2 s (reduce motion: a still `hourglass`); `menu_bg`
  scale 1.0 to 1.06 over 70 s and back; the rose a turn in 120 s.

## 5. The kit pieces

All in `shell/ui/`. Every piece: containers only; colours and fonts through the Theme; HUD instances
`focus_mode = NONE`, screen instances focusable; `accessibility_name` set (to confirm in P2); targets 24 px or more.

| Piece and tree | API | Variations; states, keys, accessibility |
|---|---|---|
| **`VellumSheet`** (`vellum_sheet.tscn`): `PanelContainer` > VBox: `Head` (seal gap, `Lede`), `Main` (HBox: `Nav`, `Body` ScrollContainer > VBox), `Foot`; `Overhang` (Control, mouse ignored): `Ribbon`, `Seal` | `title`, `lede`, `seal_letter`, `seal_tone` (vermilion, good, plain, cracked), `show_nav`; `add_section(id, title) -> VBoxContainer`, `scroll_to(id)`, `press_seal()`, `set_count(n)`; signal `section_shown(id)` | `PanelVellum`, `LabelInk*`, `LabelFlavour`. `Body` takes focus (arrows, PgUp, PgDn, Home, End). Tab: nav, body links, foot |
| **`DeltaChip`** (`delta_chip.gd`, HBox): `Icon`, `Text` | `ink`, `boxed` (a `PanelSlot` plate), `invert` (a rise is bad: upkeep); `set_delta(amount: int, unit := "", label := "")` | `Number*` or `NumberInk*`. Up: arrow, "+86", good. Down: arrow, "−6" (U+2212), bad. Zero: dash. Always icon **and** sign. Name: "up 86 ducats" |
| **`SeasonStrip`** (`season_strip.tscn`, HBox): four `Cell` > VBox: `Head`, `Lines`, `Gain` (DeltaChip) | `set_seasons(cells, now: int)`; cell `{season, note, goods: [{name, before, after}], gain}` | `PanelStripCell`, `PanelStripCellNow`. Calendar order; `now` gilt-edged; zero lines `FAINT`; hidden when the four are equal |
| **`PreviewCard`** (`preview_card.tscn`, 556 px): VBox: `Top` (pinned options, close), `Title`, `Sub`, `Brings`, `SeasonStrip`, `Cols` (`Lands`, `InkChart`), `Cost`, `Requirements`, `Payback`, `Next`, `Refusal`, `Foot` (note, Pin, Begin) | `show_preview(p)`, `show_compare(a, b)`, `treasury_only`; signals `begin_pressed`, `pin_toggled(on)`, `closed`, `look_at_requested(hex)` | `PanelCard`. Refused: title, `Refusal` (a `BAD` bar, the reason in words), close. Compare: two columns, one scale. Opened by key: Begin focused; Esc closes |
| **`InkChart`** (`ink_chart.gd`, Control, `_draw`) | `kind` (`LINE`, `LINE_BARS`, `PAIRED_BARS`, `STACKED_BAR`, `SPARK`), `ground` (`VELLUM`, `SLOT`), `x_labels`, `y_ticks`, `caption`; `set_series([{name, values: PackedInt32Array, ink, role}])`, `set_marks([{index, text, tone}])`, `summary()`; signals `point_hovered(i)`, `point_activated(i)` | `draw_polyline`, `draw_rect`, `draw_dashed_line`, `draw_string`. Redraws only from setters, resize, theme change. Each series: ink **and** dash and marker. 0 points: "No data yet". Left, Right move a cursor; the value is a `HoverCard` (`_make_custom_tooltip`); description `summary()` |
| **`StudyTable`** (`study_table.gd`, extends Tree) | `set_columns([{id, title, kind, align}])`, `set_rows(rows)` (each `id`, optional `hex`), `sort_by(id, descending)`; signals `row_activated(row)`, `sort_changed(id, descending)` | `StudyTree`. `column_title_clicked` sorts: stable, ties by `id`; the title gains `↓` or `↑`. Numbers right, tabular. Enter looks there |
| **`RelationMatrix`** (`relation_matrix.gd`, Control, `_draw`; M9) | `set_matrix(tags, names, cells)`; cell `{state, seasons_left, opinion}`; signal `cell_activated(a, b)` | 64 x 34 cells: an icon and a word, never colour alone; arrows move a cursor |
| **`NavList`** (`nav_list.gd`, VBox): toggle Buttons in a `ButtonGroup`, each with a `Count` | `ink`; `set_items([{id, text, count}])`, `select(id)`; signal `selected(id)` | `ButtonNav`, `ButtonNavInk`. Selected: brass bar left, gold or bold text. Up, Down, Home, End |
| **Medallions** (`medallion.gd`, Button: `Ring`, `Face`, `Dial`, `Hand`, lazy `Glow`; `resource_chip.tscn`: `PanelSlot` > `medallion_30`, name, value, DeltaChip) | `text`, `icon_name`, `dial` (-1 or the lit quarter), `busy`; chip `set_value(n, change)` | `ButtonMedallion`. The date medallion shows the year and lights the season's quarter; busy turns the ring. Chips are buttons named by resource |
| **`Ribbon`**, **`Cartouche`** (PanelContainer > Label) | `text` | `PanelRibbon`: wraps to two lines. `PanelCartouche`: one line, ellipsis, the full name in the tooltip |
| **Toasts** (`toast_host.tscn`: VBox of `Toast` > HBox: `Dot`, `Text`, `KeyCap`) | `toast(text, tone, key_action)`, `drop(kinds)` | `PanelToast`. Up to 3, 3.5 s; tone is a seal dot **and** an icon; mouse ignored; a polite live region |

`KitButton` gains kinds `MENU` and `MEDALLION`, a lock icon and `Reason` line on a refusal, and the lazy `Glow`.
`ModalFrame` gains `ribbon_title`, `PanelFrame` `cartouche_title`. `Segmented`, `KitSwitch`, `KitSlider` and `KeyCap`
wrap Godot's controls.

## 6. The season report

> **M3's build spec refines this section** (`m3-build-spec.md` 1.2, where it wins): the chronicle is its own
> `Chronicle` on `Game`, written only by `Game.emit` (not `stats.chronicle`; `StatsSystem.chronicle` is dropped);
> `SERIES` keeps 35 names with the **14** families of `ImproveRules` plus `works_running` and `works_finished`; M3's
> notices are "a free work slot" and "winter stops works in the snow"; `Knowledge.witnessed` takes the game (a public
> event is seen by countries that know its actor); `Events.chronicled(entry)` joins the typed signals; `view_cache`
> arrives in M3. The M3 season table is works, stats, calendar; the autosave runs in the shell after the report.

### 6.1 How it is fed

No polling. Actions go to `game.action_log`; money moves through `Treasury.move` into the ledger (M4); rules call
`game.emit(kind, data)`, which queues the event and appends notable kinds to `stats.chronicle`; the `stats` phase
closes the ledgers and appends the `Stats` rows; `Session.end_season()` drains after each phase, then emits
`Events.season_ended(turn)`. New on `Game` in M3: `turn`, `version` (plus one for each successful action and season:
the key of every view cache), `action_log`, `stats`, `emit`, `view_cache` (unsaved).

### 6.2 `Stats` and the `stats` phase

```gdscript
class_name Stats extends RefCounted                 # core/state/stats.gd
const SCHEMA := "hexa-godot/stats/1"
const RING := 40
const SERIES: PackedStringArray = [...]             # append-only; a column is found by name
var tags: PackedStringArray                         # id order
var count: int                                      # seasons written
var ring: PackedInt32Array                          # [(c * RING + turn % RING) * S + s]
var years: PackedInt32Array                         # each year's winter row: [(y * C + c) * S + s]
var goods_ring: PackedInt32Array                    # [((c * RING + turn % RING) * G + good) * 3 + (made, used, stock)]
var chronicle: Array[Dictionary]                    # newest 3,000: {turn, kind, tag, others, hex, witnesses, data}
func row(tag: StringName, turn: int) -> PackedInt32Array
func series(tag: StringName, name: StringName, span: int) -> PackedInt32Array
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> Stats       # columns by name; a missing series is zeros
func digest() -> String

class_name StatsSystem extends RefCounted           # core/systems/stats_system.gd
const OWNS: Array[String] = ["stats"]
static func season(game: Game) -> void              # the phase
static func chronicle(game: Game, event: Dictionary) -> void   # kinds in NOTABLE
```

`SERIES` (35): `treasury`, four `income_*` (people, goods, dues, trade), three `upkeep_*` (districts, walls, army),
`spending`, `people`, `food_made`, `food_eaten`, `land`, `army_men`, `losses`, `war_score`, `prestige`, `score`,
`research`, `districts_<family>` (16); zero until its system exists. At 60 countries: ring 0.34 MB, years 1.4 MB by
1650, goods ring 0.92 MB (32 goods), chronicle 0.3 MB.

- **Phase:** after `scores`, before `calendar` (in M3: after `works`), pinned by `test_season.gd`. It writes the ended
  season's row, a year row in winter, calls `Treasury.close_ledger`, trims the chronicle. Under 1 ms a country.
- **Save:** `to_dict()` under `stats` in the body; packed arrays stay packed.
- **Digest:** `Game.digest()` includes `stats.digest()`.

### 6.3 `Treasury.move` and the ledger (M4)

`core/systems/treasury.gd`, `OWNS: ["treasury", "ledger_open", "ledger_closed"]`.
`Treasury.move(game, tag, amount: int, why: StringName, hex := NO_HEX)` is **the only code that changes a treasury**
(a test greps for other writers). It adds to `ledger_open`: lines `{why, hex, amount, count, spending}` merged by
`(why, hex)`; `why` is one of `Treasury.WHY` (`tax_people`, `tax_goods`, `port_dues`, `upkeep_districts`,
`upkeep_walls`, `work`, `refund`, ...); `spending` marks the player's orders. `close_ledger` moves it to
`ledger_closed` with `{opening, closing}`. Property: `closing - opening == sum(amount)`.

### 6.4 `SeasonSummary` (`core/views/season_summary.gd`, pure)

`SeasonSummary.of(game: Game, tag: StringName, turn: int) -> Dictionary`, cached by `(turn, tag)`, under 2 ms:

```
{turn: int, title: String, next: String, lede: String, seal_letter: String,
 quiet: bool, serious: bool, swing_permille: int, toast: String, sections: Array[Dictionary]}
section = {id: StringName, title: String, count: int, total: line, lines: Array[line], more: int, unchanged: String}
line = {text: String, detail: String, amount: int, unit: StringName, tone: StringName (good, bad, warn, plain),
        value: int, from: int, to: int, hex: Vector2i, rank: int, top: bool, sub: bool, action: Array, action_label: String}
```

- Section ids, fixed order: `glance`, `before`, `treasury`, `goods`, `works`, `people`, `armies` (M6,
  `m6-build-spec.md` 4.14), `war` (M7, `m7-build-spec.md` 4.17), `orders`, `befell`, `standing`; one whose system does not
  exist is absent.
- `rank`: size in ducats at the season's prices (men for armies). Lines sort by it; six show, `more` counts the rest;
  the report's three largest have `top`.
- `before`: up to five notices of `Reminders.unfinished(game, tag)` (`core/views/reminders.gd`; in M3 two rules: a
  free work slot, winter closing passes and fields), worst first; `serious` when one has severity 2.
- `action`: `[&"look_at", hex]`, `[&"select", hex]`, `[&"study", page]` or `[&"map_mode", mode]`.
- Inputs, all saved so J works after a load: the two last `Stats` rows, `ledger_closed`, the action log and chronicle
  of `turn`, the reminders. Older season headers in the log open History (M4.5).
- **Quiet** (no work, order or event; every change under 2 %): `glance` (one line) and `before`.

### 6.5 Fog: `core/views/knowledge.gd`

```gdscript
class_name Knowledge extends RefCounted
static func knows(game: Game, viewer: StringName, other: StringName) -> bool   # a shared border; from M6 an explored hex
static func known(game: Game, viewer: StringName) -> Array[StringName]         # id order
static func unknown_count(game: Game, viewer: StringName) -> int
static func band(n: int) -> int                                                # 1,234 -> 1,200
static func band_text(n: int, unit: String) -> String                          # "about 1,200"
static func witnessed(event: Dictionary, viewer: StringName) -> bool           # a party, or in witnesses
```

The only door to another country's facts, for the report, the study, the cards and the AI. `befell` keeps an event
only when `witnessed`; `witnesses` is every country until vision arrives (M6). The viewer `&""` (tests) sees all.

### 6.6 Events to add

Those of `game-feedback-screens.md` D.2, one `Events` signal each, through `game.emit`: `season_ended(turn)` (by
`Session`, after the last drain), `work_started`, `work_finished`, `work_cancelled` (`tag, hex, work`; M3);
`goods_short` (M4); `town_grew`, `district_declined` (M5); `truce_ended` (M9); `price_moved` (M10).

### 6.7 The flow (`shell/app/season_flow.gd`)

A state machine the App owns; the only caller of `Session.end_season()`.

- `IDLE`: accepts `game_end_season` unless `event.is_echo()` or `now < guard_until`.
- `RUNNING`: busy medallion; `Session.end_season()`; drops toasts of `SeasonSummary.COVERED` kinds unless the option
  is Off; until `Events.season_ended`.
- `REPLAY` (M6): the movement replay; Space skips; instant under reduce motion.
- `DECISIONS` (M7 on): the season's queued `MODAL` screens, one at a time: war declared on you (M7), peace offer (M9),
  idea pick (M11).
- `REPORT`: Full pushes `season_report`; Brief pushes when `serious` or `swing_permille` is over 100; otherwise a toast
  of `summary.toast` ("Spring 1480 ended: +86 ducats. J: the report").

Back in `IDLE` the flow sets `guard_until = now + 400 ms` (`GUARD_MS`; an injected clock), tells the map scene to show
the new season, and the autosave runs. **Space, Space never plays two seasons:** the first is the report's focused
primary button (`ui_accept`, consumed by the GUI), a second inside 400 ms is refused.

### 6.8 The screen (`shell/screens/season_report.tscn`, `MODAL`, 900 x 640)

A `ModalFrame` holding a `VellumSheet`: ribbon, seal with the country's initial (pressed on enter), lede, an ink
`NavList` with counts, one scrolling body. Footer: "Open the study" (M4), a `Segmented` Full, Brief, Off bound to the
option, the focused `ButtonMenuPrimary` "Begin Summer". `glance` is up to five boxed chips; `top` lines carry a gilt
bar; a line with a `hex` is a link (the report closes, the camera glides). Space, Enter and Esc close. **J**, the date
medallion or the log's newest season header reopen the last report.

## 7. The works preview

> **M4's build spec refines this section** (`m4-build-spec.md` 1.2 and 4.23, where it wins): the season profile is a field
> of each `FamilyDef` (`season_percent`), not a `season_profiles.tres`; `district_output` takes the tax level as one more
> argument and returns `walls`, `staffing`, `lift`, `good` and `wild` too; goods move through a second door,
> `Stores.move`, beside `Treasury.move`; `expensive` is a quarter of the treasury or **eight** seasons or more (every
> first stage takes four); the card is `shell/screens/works_preview.*`; the tint of the hex and its ring is drawn by
> `PreviewMarks`, not the mode overlay. The six requirements of 7.3 are answered there (no "no" on 1 or 2).

### 7.1 `ImprovePreview` (`core/views/improve_preview.gd`, pure)

`ImprovePreview.of(game, tag: StringName, hex: Vector2i, option: Dictionary) -> Dictionary`; `option` is
`{action: StringName (build, upgrade, clear), family: int}`.

```
{verdict: {ok, reason}, reason_words: String, title: String, subtitle: String,
 cost: {ducats: int, goods: [{good, n}], seasons: int, ready_turn: int, first_yield_turn: int, text: String},
 requirements: [{text, ok}],
 brings: [{field: StringName, label, before: int, after: int, per: StringName (year, season), tone}],
 by_season: [4 x {season: int, now: bool, note: String, goods: [{name, before, after}], before: int, after: int, gain: int}],
 year: {before, after, gain},
 lands: {district: {before, after}, upkeep: int, ring: [{hex, name, text, delta, foreign: bool}], country: {before, after}},
 payback: {seasons: int (-1: never), turn: int, text: String, prestige: bool},
 next_stages: [{level, ok, text}], chips: [up to 3 x {text, amount, tone}], expensive: bool,
 map_marks: {hex: {delta: int, label: String}}, ghost: {hex: Vector2i, tiles: Dictionary}}
```

`verdict` is `game.check` itself; `reason_words` rewrites the rules' string ("Cuneo (5, 13) is a town beside Savona:
two towns may not stand side by side."). **Gain** is goods at this season's prices in the country's market, plus
ducats, less upkeep (ducats alone with `treasury_only`). `expensive`: over a quarter of the treasury, or four seasons
or more. `ghost.tiles` is `MapCells.of_hex` on the what-if view.

### 7.2 One code path

```gdscript
class_name StateView extends RefCounted              # core/state/state_view.gd: MapState plus a what-if overlay
static func of(state: MapState) -> StateView
func with(changes: Dictionary) -> StateView          # hex index -> Vector2i(main_use, level); other reads fall through
func main_use_at(i: int) -> int
func level_at(i: int) -> int

# core/systems/economy.gd (M4)
static func district_output(game: Game, view: StateView, hex: Vector2i, season: int, weather := CALM) -> Dictionary
        # {goods: PackedInt32Array by good id, ducats: int, upkeep: int, jobs: int, room: int}
static func market_prices(game: Game, view: StateView, market: int, supply: PackedInt32Array) -> PackedInt32Array   # thousandths
```

The season calls them on `StateView.of(game.state)`, the preview on an overlay with the work finished.
**Delta method:** country after = country before (cached) + district deltas over the hex and its ring for four seasons
(28 calls an option) + the price change in the markets touched. `EconomyPreview.with(game, tag, changes)`
(`core/views/economy_preview.gd`) is the one what-if, also for the tax hover and "Expected next season".
**Cache:** `game.view_cache` (`core/game/view_cache.gd`), 64 entries, key `(game.version, tag, hex, action, family,
treasury_only)`. **Fog:** another country's ring hex is named only when seen; its gain is a separate line ("Also
helps Milan's district at (9, 11)") outside the totals.

### 7.3 Requirements on the M4 economy design

1. A **season profile** per family and winter slot as data: `data/defs/season_profiles.tres` (`SeasonProfileDef`:
   family x season x climate, whole percent).
2. **Stocks carry goods** across seasons.
3. `district_output` is a **pure function** of the map, a `StateView`, the hex, the season and the definitions; luck
   only through `weather` (`CALM` in previews).
4. Ring effects are terms of `district_output` over the ring, nowhere else.
5. Prices are a function of supply, in whole thousandths.
6. Works live in `MapState` as `{hex, action, family, level_to, started_turn, seasons_left, paid}` with a slot count a
   country (M3); every cost goes through `Treasury.move`.

### 7.4 Where it shows

- **Hex panel rows:** a `KitButton`, an `(i)` button, up to three boxed `DeltaChip`s from `chips`, the cost
  ("40 · 4 seasons"). A refused row is off with its reason.
- **The card** (`shell/screens/works_preview.tscn`, `OVERLAY`, left of the dock): opens after the tooltip delay on a
  row, on `(i)` or on U; Shift holds it; Esc or a new selection closes it; "Pin to compare" keeps it.
- **Confirm** (`game/confirm_works`): `off`: a row click begins the work; `expensive` (default): a click begins a
  cheap work and opens the card for an `expensive` one; `always`: a click opens the card. Undo: `cancel_work {hex}` in
  the season the work began (refund through `Treasury.move`, event `work_cancelled`); the toast offers it.
- **On the map** (`game/preview_on_map`; `shell/map/preview_marks.gd`): the ghost is one more `TileMapLayer` set above
  the standing group at `modulate.a = 0.55`, filled from `ghost.tiles`; up to seven still labels ("+12 wine") from
  `map_marks`; the UI spec's mode overlay tints the hex and its ring by `delta`. The full **Yields** mode is M4.5.

## 8. The Statesman's Study

> **M4.5's build spec refines this section** (`m4-5-build-spec.md` 1.2, where it wins): Rankings is one page with two
> ranked lists side by side and a line of your value under each; Economy's History adds the treasury at each year's end
> from the year rows on its own chart; Districts and Goods have the columns of its 4.3 and 4.4; `InkChart` gains a legend,
> a cursor and fill cues, with the drawing helpers in `InkMarks`; `StudyTable` gains the `delta`, `bar`, `spark` and
> `button` kinds, 100 rows at a time and sorting by keyboard; the timeline is a new kit piece, `TimelineStrip`;
> `StudyWarm` fills the views' caches after a season; the Yields mode colours your land by worth a year (key 4). The five
> questions of M4.5 are its 4.11.

`shell/screens/study.tscn`, `OPAQUE`; one instance for the App's life, so page, tab and scroll are kept. Tree: a
`PanelModal` frame (the window less 30 px) > VBox: `Head` (date, Close with key cap I), `Body` (HBox: `Nav` NavList,
`PageHost`, a plain Control with the pages stacked for the cross-fade), `Hints`; the `Ribbon` over the top band. A
`StudyPage` is a VBox: `Tabs` (`ButtonTab`s), `TabHost`.

- **Pages** are scenes in `shell/screens/study/`, listed in `study_pages.gd`. Only built pages are listed: later ones
  are hidden, not greyed. `StudyPage`: `page_id`, `tabs`, `refresh(game, tag)`, signal
  `action_requested(action: Array)`. Built on first open; refreshed on `season_ended` or a newer `game.version`.
- **Opens:** I (the last page), L (Economy), the top bar's book button, the ducats chip (Economy), the prestige chip
  (Rankings), the report. **Keys:** `[` `]` page; Ctrl+`[` `]` tab; Enter on a row looks there; I or Esc closes.
- **`look_at`:** a row or "Show on map" emits `action_requested([&"look_at", hex])` or `[&"map_mode", mode]`; the
  study sends `ctx.app_requested(&"look_at", {hex, select, mode})`; the App pops the study, glides (0.35 s), selects
  and sets the mode. I returns to the same page and scroll.
- **Read models** (pure, `core/views/study_<page>.gd`, cached by `(game.version, tag)`): `StudyEconomy`
  (`this_season`, `districts`, `goods`, `history(span)`), `StudyRankings`, `StudyHistory`; later one a page.
- **Charts** are `InkChart`s on a `PanelVellumInset`; **tables** are `StudyTable`s. **Stored:** `Stats`, the ledgers,
  the action log, and (M10) each market's 40-season price ring. Nothing else.

| Page | Tabs and widgets | Others' data | Ships |
|---|---|---|---|
| **Economy** | *This season*: money in and out, left over, your spending, expected next season, the tax `Segmented` with its hover preview, Earns most, Costs most, the treasury chart (`LINE_BARS`, 12 seasons). *Districts*, *Goods*: tables (goods with sparklines). *History*: 12 or 40 seasons, stacked in and out. *Debt* | none | This season M4; Districts, Goods, History M4.5; Debt M12 |
| **Rankings** | ranked bars for land and income; your line through time | known, banded; "2 countries unknown" | M4.5; people M5, army M6, score M12 |
| **History** | timeline (a tick a season; marks for works, wars, eras); the chronicle with filters All, War, Money, Works, Mine | what you witnessed | M4.5 |
| People, Military, Diplomacy, Trade, Research | as `game-feedback-screens.md` C.2 | as C.5 | M5; M6 and M7; M9; M10; M11 |

"Show on map" modes: Yields (M4.5), Food (M5), Supply (M6), Relations (M9), Trade flows (M10).

> **M5's build spec** (`m5-build-spec.md` 6.2 to 6.8) specifies the People page (one page, no tabs, between Economy and
> Rankings), the people measure in Rankings and Standing, the report's People section, the People and Food chips and the
> Food mode on key 5 (your land by food made less eaten, a year).
>
> **M6's build spec** (`m6-build-spec.md` 6.9, 6.6, 4.14) specifies the Military page (one page, no tabs, between Economy
> and People), men under arms in Rankings and Standing, the report's Armies section and the Supply mode on key 6.
>
> **M7's build spec** (`m7-build-spec.md` 6.9, 4.17, 6.6) adds to the Military page its Wars and Battles tables and the
> Battle losses (the Diplomacy page of M9 takes the Wars table over), the report's War section and the war alert in
> `DECISIONS`.

## 9. Input actions and options

Added to `Bindings.DEFAULTS` (action, default, since): `game_report` J (M3); `game_study` I (M4); `game_ledger` L
(exists; opens the study's Economy page, M4); `study_page_prev`, `study_page_next` `[`, `]` (M4); `study_tab_prev`,
`study_tab_next` Ctrl+`[`, Ctrl+`]` (Cmd on the Mac; M4.5). `game_upgrade` (U) opens the works card from M4;
`game_end_season` is guarded (6.7); `Bindings.GESTURES` gains "Shift: hold the works card".

Added to `Settings.SCHEMA` (`user://settings.cfg`; key, choices, default, since): `game/season_report` (`full`,
`brief`, `off`; `full`; M3); `game/confirm_works` (`off`, `expensive`, `always`; `expensive`; M4);
`game/preview_on_map` (bool; true; M4); `game/gain_treasury_only` (bool; false; the card's switch; M4); `dev/ui_kit`
(`auto`, `1x`, `2x`, `plain`; `auto`; Advanced page; M1.5); `state/study_page` (`economy`; M4) and `state/study_span`
(12 or 40; 12; M4.5), remembered, no row. `accessibility/reduce_motion` takes its first-run default from the system.

## 10. Milestones: a proposal to amend the standard's section 9

Not an edit of `godot-architecture.md`: after the owner's approval its table takes these rows.

| M | Adds | Done when | Design / Build |
|---|---|---|---|
| **M1.5** (new row) | The UI foundation in the Studiolo style: tokens, UI bake, generated Theme (1x, 2x, flat), fonts, kit; controls, HUD frame, menus, options | The mockup's M1.5 scenes match side by side at 1x and 2x; both `--check`s in CI; the owner's playtest on the Mac and Windows | Fable, art director / Sonnet, Haiku |
| **M3** | `Stats`, the `stats` phase, the chronicle, `Knowledge`, `Reminders`, `cancel_work`; the **season report** | Space, Space plays one season; save, load, J shows the same report | Fable / Sonnet, Haiku |
| **M4** | `Treasury.move` and the ledger; the report's money sections; the **works preview**; the study with **Economy, This season** as the ledger (L); the icon set | Every ducat of the report sums to the change; preview equals the season for four calm seasons | Opus (7.3) / Sonnet, Haiku |
| **M4.5 "Insights I"** (new) | The chart and table kit complete; Economy's other tabs; the History and Rankings pages; the Yields map mode | The owner answers five questions from the study in under a minute each; a page opens in under 16 ms | Opus / Sonnet, Haiku |
| **M5 to M12** | Each system brings its study page and report section (section 8); M12 adds score, the Debt tab, text size, the high-contrast row, sounds | The page's numbers equal the system's state, in a test written with the system | as the system |

## 11. Tests

GUT unless said; files under `godot/tests/`.

- **Tokens** (`shell/test_tokens.gd`): every ratio of `design.md` 3; inks 4.5:1 on `VELLUM`; the bake's form parses.
- **Bake** (`tests/test_bake_ui.py`, Python unittest): two runs and any `--jobs` give one hash; names, sizes and
  margins equal the catalogue; each assert fires on a planted fault; `--check` catches a changed token or PNG.
- **Theme** (`shell/test_theme.gd`, `test_kit_theme.gd`): `--check`; every variation exists; margins equal
  `ui_kit.json`; `has_char`; tabular digits; `KitTheme` picks 1x, 2x, plain by scale and reports 1x sizes.
- **Kit** (`shell/test_kit_feedback.gd`, `test_ink_chart.gd`, `test_study_table.gd`, `test_motion.gd`): `DeltaChip`
  has icon and sign; `SeasonStrip` marks `now`, hides when flat; `InkChart` draws 0, 1, 40 points, redraws only on
  new data; `StudyTable` sorts stable, ties by id; `Motion` jumps to the end under reduce motion.
- **`Stats`** (`core/test_stats.gd`, `test_season.gd`): the ring wraps at 40; year rows in winter only; a later series
  loads as zeros; save, load, save equal; the digest moves with a row; `stats` pinned after `scores`.
- **`Knowledge`** (`core/test_knowledge.gd`): unknown countries never listed; banding; `witnessed`.
- **`SeasonSummary`** (`core/test_season_summary.gd`): lines sum to the change; largest first; six then `more`; quiet;
  an unwitnessed event is absent; equal after a load.
- **Ledger** (`core/test_treasury.gd`, property): `closing - opening == sum(lines)`, every country, 40 seasons.
- **`ImprovePreview`** (`core/test_improve_preview.gd`, property, 200 seeded cases): finish the work, play four calm
  seasons: output and gain equal the preview's to the unit; a preview leaves the digest unchanged.
- **Shell** (`shell/test_season_flow.gd`, `test_season_report.gd`, `test_works_preview.gd`, `test_study.gd`): the
  report after the replay and decisions; Space at 399 ms refused, at 401 ms accepted (injected clock); Brief only when
  serious; Off toasts; a report link and a study row request `look_at`; I returns to the same page; U opens the card,
  Enter begins; the three `confirm_works` values.
- **UI probe and pictures** (`godot/tools/ui/shot_ui.gd`, windowed; xvfb in CI): the mockup's nine scenes with its
  sample numbers (`fixtures/ui_sample.gd`) at 1280 x 720 scale 1 and 2560 x 1440 scale 2. (1) A side-by-side sheet a
  scene against `fixtures/mockup/<scene>.png` (the mockup's stage, rendered once), signed by the art director and the
  owner. (2) A coarse check (`tools/ui_compare.py`): both reduced to 64 x 36, mean colour difference under a set
  threshold. (3) After sign-off the Godot pictures are goldens (`goldens/ui_*.png`, 0.5 %).
- **Perf probe** (`godot/tools/ui/perf_ui.gd`, `perf_ui_budget.json`; nightly, never GUT): a screen push under 16 ms;
  `SeasonSummary.of` and a build list with previews under 2 ms; a study page under 16 ms; `stats` under 1 ms a
  country; the HUD frame with textured frames under 16 ms worst on the fake Europe at 1920 x 1080; kit memory under
  4 MB (1x), 16 MB (2x).
- **Monkey** (`shell/test_ui_monkey.gd`): adds J, I, L, `[`, `]`, U, double Space, clicks on links and rows.
  Invariants: one season at most a guard window; paused exactly while the report is up; the World hidden exactly
  while the study is up; digest unchanged by opening the report, the study or a preview.

## 12. Risks, and the probes to run first

| Probe | Question | Fallback |
|---|---|---|
| **G1** (the UI plan's, extended) | Does the Mac's Compatibility driver take **ASTC**? `menu_bg` as RGBA8 against compressed | Half textures (UI spec 6.3); `menu_bg` at 1280 x 720 |
| **P2 frames and HiDPI** | A 9-slice with a tiled centre and expand margins; a 2x texture with a size override sampled one to one at scale 2 (a checker, read back); a live theme swap; the accessibility calls in 4.7.2; **the HUD frame with textured frames** (a stand-in HUD over the fake Europe at 1920 x 1080): added ms and draw calls | `StyleBoxKit`, then 1x only; the plain theme for the HUD alone if the 16 ms frame fails |
| **P3 fonts** | Each `cmap` against the required set; `lnum` and `tnum` through `FontVariation`; Cinzel spacing; the fallback | Alegreya from its upstream repository; numerals from Noto Sans |
| Bake determinism (task K5) | Equal hashes on macOS, Linux and Windows | The check runs only in CI's container |

Other risks, each with its guard above: no seasons in M4's economy (the strip hides), preview drift (one function,
the property test), too much to read (six lines, Brief, the quiet state), AI secrets (`Knowledge`), an HTML mockup
(acceptance is the signed side-by-side, not bits).
