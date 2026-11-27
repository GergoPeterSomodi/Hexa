# Map overview build spec: the parchment map (issue 475)

Technical director, 2026-11-27. **Status: a proposal for the planner.** The owner approved the look on 2026-11-27 ("Yes,
build the map, keep the current framing style") from the parchment mockup attached to issue 475, which was drawn from the
north Italy data. The plan is `docs/architecture/map-overview-build-plan.md` ("the plan"); task IDs are `PM0` to `PM7`.

**In one line.** When you zoom out, or when the new Goods mode is on, the map turns into a code-drawn parchment map: a sand
sea, a pale land, a dark hand-drawn coast with hatched water, dashed borders, faint mountain marks and big country names
that follow each country's shape. Closer in it adds town dots and names. The parchment is the **map only**: the top bar,
panels, legend, buttons and hover card keep the game's walnut and gold kit frames. There is no globe.

---

## 1. What exists today (read before building)

| Part | Where | What the parchment does with it |
|---|---|---|
| Zoom | `shell/input/zoom_model.gd` (`fit_zoom`, `min_zoom`, `ZOOM_MAX` 2.0), `CameraRig.view_changed` | the fade band is set from the fit zoom and the zoom (D2) |
| Far picture | `shell/mapview/far_map.gd` (`FarMap`, z 75; solid at or below 0.20, gone at 0.25) | kept for the modes and the setting that have no parchment; hidden under a solid parchment |
| Tiles | `shell/mapview/tile_map_view.gd` (ground to z 45, lines 50, areas 82, borders 85, reach 83, marks 90) | the tile layers and lines are hidden under a solid parchment; reach and marks stay on top (D4) |
| Modes | `core/views/map_modes.gd` (`Mode` TERRAIN..SUPPLY, keys 1 to 6, `MODE_KEYS`, `modes(game)`), `shell/map/mode_overlay.gd` (z 80, 796 lines) | one new mode, GOODS (key 7); the overlay is not edited (D5) |
| Fog | `MapModes.discovered_bytes` / `discovered_key`, `shell/map/deep_fog.gd`, `MapModes.sight_bytes`, `Knowledge.discovered` | the parchment reads the same bytes; nothing on an undiscovered hex (R12 to R15) |
| Names | `core/views/country_names.gd` (regions of 3 hexes or more), `shell/mapview/country_labels.gd` (Cinzel, screen space, cover rects), `shell/mapview/map_labels.gd` (plates, off by default) | the parchment has its own names (D7); CountryLabels fades out as it fades in |
| Marks | `CapitalMarks` z 86, `WorkMarks` 87, `ArmyTokens` 88, `WarMarks` 89, `PathMarks` 84, `PreviewMarks` 82 | capitals hide under a solid parchment (it draws its own); every other mark stays above it |
| HUD | `shell/hud/top_bar.gd` (Segmented mode switch), `mode_legend.gd`, `map_hover.gd`, `layers_popover.gd`, `shell/ui/soon_tag.gd`, Kit icons `good_*` | the Goods segment, the goods card, the legend rows, a compact hover line |
| Settings | `shell/app/settings_schema.gd` (`state/map_mode`, `map/*`, `accessibility/*`) | three keys (R24) |
| Size limits | `map_scene.gd` 800 lines, `app.gd` 800, `mode_overlay.gd` 796, `tokens.gd` 776 | PM0 makes room in `map_scene.gd`; `app.gd`, the overlay and `tokens.gd` are not grown (D5, D9, D10) |

---

## 2. Requirements

### The look (the approved mockup)

- **R1** The parchment is drawn in code from the map and the state. Nothing is baked, downloaded or added to the piece
  index; the fonts are the project's own (`Tokens.FONTS`: Alegreya SC Bold for country names, Alegreya Medium Italic for
  towns, Alegreya Sans for numbers).
- **R2** Layers, bottom to top: the sand sea (a flat colour with a faint speckle) covering the map and one screen around
  it; the hatched water, a band of wavy lines along every coast, half a hex wide on each side; the land, one wobbled
  polygon a hex; the dotted district lines inside a country; the mountain marks; the dashed country borders; the coast,
  a dark ink line. Then the names, dots and icons (R8 to R11) in screen space.
- **R3** Hand-drawn edges: each hex corner and each edge's middle point is moved by an integer hash of its own map
  position (corners up to 10 map px, middles up to 9 px, the mockup's amounts scaled to the 104 px hex). A corner or an
  edge shared by two hexes moves the same way for both, so no gaps or slivers appear. The hash is pure arithmetic, not
  luck: it does not use `core/rng.gd` and gives the same picture on every machine.
- **R4** Line widths and dash lengths are in screen pixels and do not change with the zoom: coast 3 px, borders 2 px in
  9 px dashes with 6 px gaps, district lines 1 px dotted. The hatch spacing is in map pixels; when it would be under
  3 screen px it becomes a flat tint (no moire).
- **R5** Mountain marks: a small ink zig-zag on a hex above 1,400 m, a larger one above 2,400 m (`MapData.height_m`).

### What it shows in each mode

- **R6** Terrain mode: pale land; the owner tint at the Terrain strength when `map/owner_tint` is on. Owner mode: each
  country's colour mixed 46 % into the land, from `MapModes.palette(game, colour_blind)`. Unowned land stays pale.
- **R7** Goods mode (new, key 7, top-bar segment "Goods"): the player picks one good. Each district that makes it is shaded
  by its stage in a one-hue ramp (stage 1 light, 2 medium, 3 dark; R20) and carries the good's Kit icon in a small disc
  with 1 to 3 pips for the stage. A district makes a good when `Economy.good_of` is that good; its stage is
  `MapState.level` (1 to 3). Wild hexes, settlements and castles make none.

### Names, dots and icons (screen space)

- **R8** Country names: one name a region of 3 or more **discovered** hexes of one owner. Placed at the region's centre,
  turned along its long axis (the main axis of its hex centres, kept within plus or minus 55 degrees), sized by its area
  (about 8 px times the square root of its hexes at a 58 px hex, scaled by the hex's screen size) and never longer than
  the region along that axis; 14 to 48 px, scaled by `accessibility/text_size`. Paper halo 4 px.
- **R9** Detail by screen hex width `s` (zoom times 104):
  - `s` under 24 px, the far view: countries and capital dots only, plus goods icons when `s` is 16 px or more;
  - `s` 24 px or more, the town view: also town dots (village or larger, dot size by level), capital and town names
    (towns level 3 or more), mountain marks; district lines from `s` 40 px.
  The town view fades in over 24 to 28 px.
- **R10** Placement without overlaps, in this order: capitals (dot and name); country names (a name may slide along its
  normal by up to one line to clear a capital, else it is drawn anyway: every country is named); goods icons; towns by
  level, then name. A town name that collides with anything placed, or with a HUD cover rect (`Hud.cover_rects`), is
  dropped; its dot stays.
- **R11** Layout runs only when the view changes (`CameraRig.view_changed`), the data changes (owners, discovery, works,
  mode, good) or the cover rects change; never every frame. Only what is on screen is laid out.

### Fog (two fog levels, `docs/architecture/fog-build-spec.md`)

- **R12** An undiscovered hex, land or sea, is drawn with one flat "unknown" paper fill. No coast, border, district line,
  mountain mark, hatch, tint, goods shade, icon, dot or name is drawn on it or from it.
- **R13** A coast edge is drawn when its land hex is discovered. A border or district line is drawn only when **both**
  hexes are discovered. A country name, a legend count and a town list read discovered hexes only.
- **R14** Light fog (discovered, not in sight): owners and goods exact (land facts, as the fog build rules); the sight veil
  is drawn over it when `map/sight_veil` is on, in a parchment tone.
- **R15** The parchment draws no armies. Army tokens, war marks, paths and previews keep their own fog rules and draw above
  it, unchanged.

### Coexistence

- **R16** The parchment shows in Terrain and Owner mode by the zoom (D2), and in Goods mode at every zoom. It never shows in
  Relief, Yields, Food or Supply mode, nor during the country pick: those keep today's tiles, overlay and far picture.
- **R17** Under a solid parchment the tile layers, tile lines, borders, castle areas, `FarMap`, `CapitalMarks` and
  `CountryLabels` are hidden. In the fade band the tile borders and lines fade out as the parchment fades in, and
  `CountryLabels` fades by one minus the parchment's alpha. Reach overlays, the selection and build marks, preview, path,
  work, army and war marks and floaters stay above the parchment at every alpha.
- **R18** `map/parchment` off: Terrain and Owner never turn to parchment (today's look); Goods mode still shows it (it is
  the goods map). `map/borders` off hides the parchment's borders too.

### HUD (the game's own frames)

- **R19** The top bar's mode switch gains a seventh segment, "Goods", where `MapModes.modes` offers Yields (a country game
  with a player). The bar's compact steps are measured again so nothing overflows at 1280 x 720.
- **R20** In Goods mode a kit-framed card ("Goods produced", `PanelFrame`, bottom left of the map area) shows one icon
  button per good that some family makes (Kit `good_*` icons, 6 a row, GameDefs order). The chosen good is marked by the
  kit's selected state, not by colour alone. Each button's tooltip: "Grain: 14 districts you know make it". A good no
  known district makes is shown and pickable, with "none you know". Under the grid, two greyed rows with a `SoonTag`,
  "Population" and "Unrest" (the mockup's "soon" modes; Food balance is the existing Food mode, key 5; plan question 1).
- **R21** `ModeLegend` in Goods mode: the good's name as title; rows "First stage", "Second stage", "Third stage" with their
  ramp swatches and pips, "Not here"; a last line "N districts you know make it".
- **R22** A kit button "Return to default map" in the bottom middle of the map area, clear of the HUD's cover rects, shown
  in every mode but Terrain and not during the pick; it sets Terrain (as key 1 does). Its tooltip names the key.
- **R23** Hover: while the parchment is solid, or in Goods mode, the hover card shows one compact line from
  `ParchmentView.tip`: "Pavia · Milan · Grain, second stage" (place if any, owner, the good and stage in Goods mode, or the
  hex's good in other modes). An undiscovered hex reads "Unexplored"; unowned land "Unclaimed land". Elsewhere the full
  hex card is unchanged.

### Settings, keys, accessibility

- **R24** Settings (`settings_schema.gd`): `state/map_mode` gains the choice `goods`; `state/map_good` (string, a good key,
  default `grain`; an unknown key falls back to the first good); `map/parchment` (bool, default true, page Map, "Parchment
  map when zoomed out", and a row in the Layers popover). The mode and good come back after a restart like the other modes.
  The save file does not change.
- **R25** Keys (`bindings.gd`, rebindable): `view_mode_7` "7" (Goods); `map_good_prev` "[" and `map_good_next` "]" step
  the chosen good in Goods mode. The goods card is keyboard reachable: its buttons take focus, arrows move in the grid,
  Enter or Space picks.
- **R26** Colour-blind safe: the goods ramp is one hue with lightness steps of at least 15 L* between stages, and the stage
  is also given by the pips and the hover line. Country tints follow `accessibility/country_colours`. High contrast
  (`accessibility/high_contrast`) draws the coast and borders 1 px thicker and the ink darker.
- **R27** Text contrast: name ink on its paper halo at least 4.5:1; lines on the land at least 3:1 (a test checks the token
  pairs). Every icon has a tooltip (the card's) or a hover line (the map's). Town names are 13 to 17 px, capitals 17 px,
  all scaled by `accessibility/text_size` and the UI scale.

### Performance (budgets in plan section 4)

- **R28** Static geometry is built once per map (sliced at `MapScene.slice_ms` a frame on a large map). A change of owner,
  discovery, sight, mode, good or works never rebuilds geometry: it writes texels or sets a uniform.
- **R29** On an ownership change only the touched texels are written and the names are laid out again; at most the
  existing `owner_change_frame_ms` (16 ms) with the parchment on.

---

## 3. Decisions

- **D1 One controller node, one label node.** `ParchmentMap` (`shell/map/parchment_map.gd`, a `Node2D` at z 81 in
  `map_scene.tscn`, after `Overlay`) owns the meshes, shaders, data textures and the alpha. `ParchmentLabels`
  (`shell/mapview/parchment_labels.gd`, a `Control` in the `Names` canvas layer after `Labels`) owns names, dots and
  icons. The facts come from two pure views in `core/views/`: `ParchmentShape` (geometry) and `ParchmentView` (goods
  bytes, counts, legend, names, towns, tip). The shell draws; it holds no rules.
- **D2 The fade band follows the fit zoom.** `solid = max(fit, 0.28)` and `gone = solid × 1.3`, where `fit` is
  `ZoomModel.fit_zoom` for the window's free map area. Alpha is 1 at or below `solid`, 0 at or above `gone`, linear
  between. On north Italy at 1920 x 1080 (fit about 0.65) the whole-map view is parchment and two wheel notches in bring
  the tiles back; on a large map the parchment starts at hexes about 38 px wide and is solid at 29 px, above `FarMap`'s band. Goods mode
  forces alpha 1 at every zoom. `reduce_motion` does not matter: the alpha follows the zoom, not time.
- **D3 Static geometry, dynamic textures.** `ParchmentShape` gives, once per map, the land polygons (12 points a hex, every
  hex, sea too, so the unknown fill can cover sea), every edge as 3 points with its two hex indexes and a kind (coast or
  land-land), and the mountain marks with their hex. The shell turns them into one `ArrayMesh` a chunk (64 x 32 hexes)
  with the hex index in a vertex attribute. Textures of one texel a hex carry what changes, **already masked by the fog in
  core**: the known owner (`ParchmentView.owner_bytes`: the owner id, 0 unowned, 255 undiscovered, rebuilt by
  `MapModes.discovered_key` and the owners), sight (`MapModes.sight_bytes`), and the goods bytes (good id plus one, and
  the stage; 0 when undiscovered). So the shaders are never given a fact the viewer may not know, and the fog rules are
  tested on bytes, headless. The shaders decide the rest: 255 is the unknown fill; a land-land edge is a dashed border
  when the owners differ, a dotted district line when they match, nothing when either side is 255; a coast edge is
  drawn when its land side is not 255. Picking a good sets one uniform.
- **D4 Tiles under a solid parchment.** A new `TileMapView.set_ground_shown(on)` hides the tile, line, area and border
  layers but keeps reach and marks; `set_lines_alpha(a)` fades lines and borders in the band. `FarMap` and `CapitalMarks`
  hide when the parchment is solid; a hidden layer costs nothing to draw.
- **D5 Goods is a mode, not a layer.** `MapModes.Mode.GOODS` (value 6, key `goods`) so the top bar, keys, settings and
  restore paths treat it like the others. `ModeOverlay`, `CapitalMarks` and `CountryLabels` are given Terrain while Goods
  is on (the parchment covers them), so `mode_overlay.gd` (796 lines) is not edited.
- **D6 No parchment in the data modes.** Relief, Yields, Food and Supply keep the tiles at every zoom: their colours are
  read hex by hex and are already tuned for the tile art. The parchment can host them later by adding a byte texture.
- **D7 Own names, shared rules.** `ParchmentView.country_names` reuses `CountryNames`' regions restricted to discovered
  hexes and adds the axis angle, the room along it and the hex count. `span_px` is that room: the length of an unbroken
  run, inside the region, of a line at the (clamped) angle (less half a map px at each end), and `at` is the middle of
  that run, on a hex of the region. So a name no longer than `span_px`, centred on `at` along the angle, never runs over
  another country, the sea or unexplored paper (R8, R12), whatever the region's bends and gaps; a name moved off that
  line (R10) is not covered by this. The run is the longest found on lines across the region (38 px apart and 14 at
  most, the two outermost ones, the hex centres of a region of 24 hexes or fewer, then closer beside the best line);
  among runs of 0.9 of the longest or more, the one on the line nearest the middle of the hex centres. `CountryLabels`
  stays for the tile view.
- **D8 Hatched water and sea in shaders.** The hatch is a strip mesh along the coast edges with UVs (along, across) and a
  small shader of wavy lines; the sea is one quad with a hash speckle. Colours reach shaders only as uniforms.
- **D9 Colours as tokens.** A new `shell/ui/parchment_tokens.gd` (`ParchmentTokens`, standard and high-contrast sets: sea,
  speckle, hatch, land, unknown, veil, district line, mountain, border, coast, name ink, halo, the goods ramp, icon disc)
  is added to the lint's `UI_STYLE_ALLOWLIST`; no other new file has a `Color(` literal. `tokens.gd` is not grown.
- **D10 The goods card is new HUD, not a new frame.** `shell/hud/goods_card.gd` and `.tscn` build on `PanelFrame`,
  `KitButton`, `SoonTag` and `PanelKit` labels. The legend is `ModeLegend` with Goods rows from `ParchmentView.legend`.
  The card picks a good by writing `state/map_good`, which `MapScene` already hears through its setting listener; the
  Return button sends the HUD's existing `mode_requested`. So `shell/app/app.gd` (800 lines) is not edited.
- **D11 Hover reuses the hover card.** `MapHover` shows `ParchmentView.tip` as a one-row `HoverCard` in the cases of R23.
- **D12 Room in `map_scene.gd` first.** PM0 moves the mode store (`_mode_from_string`, `_mode_to_string`,
  `_saved_mode_from_settings`, `_clamp_mode_for_game`, the `state/map_mode` writes) into `shell/map/map_scene_modes.gd`,
  a refactor with no behaviour change, so the wiring of PM5 fits under 800 lines.
- **D13 One bus signal.** `Events.map_parchment(solid: bool)`, sent by `MapScene` when the parchment becomes solid or stops
  being solid (not every frame), tells `MapHover` which card to show (R23) without a new path through `app.gd`.
- **D14 Large-map fallbacks** (only if the plan's frame rows fail on the made-up Europe): in the far view use corner
  points only (6 a hex, no edge middles); then draw the far-view fill as one quad that looks up the hex per pixel, as the
  overlay does, keeping the line meshes.

---

## 4. Interfaces

```gdscript
# core/views/parchment_shape.gd (pure; no engine calls)
class_name ParchmentShape extends RefCounted
const CORNER_WOBBLE_PX := 10.0
const MIDDLE_WOBBLE_PX := 9.0
const MOUNTAIN_M := 1400
const MOUNTAIN_BIG_M := 2400
enum Edge { COAST, LAND }
static func hash01(x: int, y: int) -> float                      # integer hash in [0, 1)
static func corner(hex: Vector2i, k: int) -> Vector2              # wobbled; shared corners equal
static func middle(a: Vector2, b: Vector2) -> Vector2             # wobbled; the same for (a, b) and (b, a)
static func polygon(hex: Vector2i) -> PackedVector2Array          # 12 points, corner then middle
static func edges(map: MapData, rows: Vector2i) -> Dictionary     # {points (3 an edge), a, b (hex indexes; b -1 off the map), kind}
static func mountains(map: MapData, rows: Vector2i) -> Dictionary # {points, hex, big}

# core/views/parchment_view.gd (pure)
class_name ParchmentView extends RefCounted
const UNKNOWN := 255
static func owner_bytes(game: Game, viewer: StringName) -> PackedByteArray   # owner id, 0 unowned, UNKNOWN undiscovered
static func goods_bytes(game: Game, viewer: StringName) -> PackedByteArray   # 2 a hex: good id + 1, stage; 0 when undiscovered or none
static func goods_list(game: Game) -> Array[Dictionary]                      # {id, key, name, icon}
static func count_of(game: Game, viewer: StringName, good_id: int) -> int
static func legend(game: Game, viewer: StringName, good_id: int) -> Array[Dictionary]
static func country_names(game: Game, viewer: StringName) -> Array[Dictionary] # {tag, text, at, angle_deg, span_px, hexes}
static func towns(game: Game, viewer: StringName) -> Array[Dictionary]         # {hex, name, level, capital, at}, placement order
static func tip(game: Game, viewer: StringName, hex: Vector2i, mode: int, good_id: int) -> String

# shell/map/parchment_map.gd
class_name ParchmentMap extends Node2D
static func alpha_at(zoom: float, fit: float) -> float
func begin(game: Game) -> void; func step(budget_ms: float) -> void; func is_building() -> bool
func sync(game: Game) -> void                    # texels by key compare; one compare a frame while nothing moves
func owners_changed(hexes: Array[Vector2i]) -> void
func set_mode(mode: int) -> void; func set_good(good_id: int) -> void
func set_options(tint: bool, borders: bool, veil: bool, colour_blind: bool, high_contrast: bool, enabled: bool) -> void
func apply_zoom(zoom: float, fit: float) -> float  # sets modulate and visible; returns the alpha used
var geometry_builds := 0                          # tests: never moves after the first build

# shell/mapview/parchment_labels.gd
class_name ParchmentLabels extends Control
func setup(game: Game, viewer: StringName) -> void
func set_mode(mode: int) -> void; func set_good(good_id: int) -> void; func set_alpha(a: float) -> void
func set_cover(rects: Array[Rect2]) -> void
func relayout(xform: Transform2D, zoom: float, viewport: Vector2) -> void
func placed() -> Array[Dictionary]               # {kind: country|capital|town|icon, hex, text, rect, angle, size}
var layout_count := 0
```

---

## 5. Done when

1. On north Italy at the whole-map view the map is the parchment of the approved mockup in Terrain and Owner mode, inside
   the game's own top bar and HUD; zooming in fades to the tiles; Goods mode shows the goods map at every zoom.
2. Every case of R12 to R15 holds on the thin fog fixture, each with a planted fault (plan section 3).
3. The perf rows of plan section 4 hold on north Italy and the made-up Europe; the old map rows do not get worse.
4. The mode, the good and the parchment switch come back after a restart; the keys of R25 work.
5. The art director signs the pictures of plan section 3 next to the mockup; the owner plays plan section 5.
