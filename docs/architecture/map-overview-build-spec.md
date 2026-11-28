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
| Fog | `MapModes.discovered_bytes` / `discovered_key`, `shell/map/deep_fog.gd`, `MapModes.sight_bytes`, `Knowledge.discovered` | the parchment reads the discovered bytes, not the sight bytes (R14, 2026-11-27); nothing on an undiscovered hex (R12 to R15) |
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
  9 px dashes with 6 px gaps, district lines 0.8 px dotted. The hatch spacing is in map pixels; when it would be under
  3 screen px it becomes a flat tint (no moire).
  Amendment (2026-11-27): district lines are 0.8 px (1 px in high contrast). The district and mountain inks are the
  mockup's see-through ones (`#8a7a64` at 0.7, `#7d6a52` at 0.6); high contrast draws them darker and opaque.
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
  Amendment (2026-11-27): the letters are spaced 0.08 em apart (counted in the fitted width). In Goods mode the name and
  its halo are 0.82 opaque, as in the mockup; in the other modes and in high contrast they are opaque.
- **R9** Detail by screen hex width `s` (zoom times 104):
  - `s` under 24 px, the far view: countries and capital dots only, plus goods icons when `s` is 16 px or more;
  - `s` 24 px or more, the town view: also town dots (village or larger, dot size by level), capital and town names
    (towns level 3 or more), mountain marks; district lines from `s` 40 px.
  The town view fades in over 24 to 28 px.
- **R10** Placement without overlaps, in this order: capitals (dot and name); country names (a name may slide along its
  normal by up to one line to clear a capital, else it is drawn anyway: every country is named); goods icons; towns by
  level, then name. A town name that collides with anything placed, or with a HUD cover rect (`Hud.cover_rects`), is
  dropped; its dot stays.
  Amendment (2026-11-27): a country name that cannot fit its room (D7) at 14 px is left out, though R10 names every one. A goods icon with no free spot in its hex because of a country name is drawn over the name; icons still overlap no other icon, capital or cover rect.
  Amendment (2026-11-27): a name that would cover a capital is tried clear of it at full size, then at 75 and 50 % (never
  under 14 px; with larger text also at the size it fits at 100 %). At each size it slides up to one line, or moves the
  capital's name to the other side of its dot, then takes a farther spot on its own known land (again moving capital
  names where needed). Only when no size has such a spot is it drawn over the capital. A goods disc is 56 % of the hex
  wide (12 px at least), with its pips below it.
  Amendment (2026-11-27): the disc stops growing at about 69 px wide (from a hex about 122 px wide), so the 24 px Kit
  icon is never drawn above twice its size; the pips follow the disc.
  Amendment (2026-11-27): where its own known land has room, a country name also keeps clear of the HUD cover rects and
  of the spots the goods icons would take, trying the places just past them too. It gives up the icons first, then the
  capitals (it is drawn under a capital rather than under a cover); it stays under a cover only when no spot on its land
  is clear of it. It may shrink to get out from under a cover, never to get off an icon. Icons are still placed after
  the names.
  Amendment (2026-11-28, owner): a capital's dot and name are a hard obstacle: no country name is drawn on them. This
  replaces "else it is drawn over the capital" and "it is drawn under a capital rather than under a cover" above, and
  the rule that every country is named. A name with no spot at the sizes above is tried at every step of 0.85 of its
  size down to 14 px, there also just clear of the capital in its way (moved along its line or its normal only) and, in
  the town view, at finer places between those above; none of these last places is more than 2.5 lines across, or
  along its line farther than 0.45 of its length or, where that is more, as far as its room (D7) lets it. With no such
  spot on its own known land the country name is left out; its capital's dot and name stand for it. This befalls small
  countries in the farther views (on north Italy at 1280 x 720 Mantua, at the zooms where its three hexes are small),
  and many countries of the made-up Europe in its far view, whose ragged shapes leave one line for the name, over the
  capital's dot. A name still lies over the small dots of towns, which are drawn under it.
  In Goods mode a name that would be left out only because the capitals' names are held off the icons' spots is searched
  for once more with those spots given up: a capital's name may then move onto one (the icon takes another spot, or none).
  Amendment (2026-11-28): the parchment's names and icons (not the tile view's) also keep off the mode legend, the key
  hints with their strip (R30), the log's button and badge, and the "things to do" card (`Hud.name_cover_rects`,
  beside `Hud.cover_rects`), by the cover rules above.
- **R11** Layout runs only when the view changes (`CameraRig.view_changed`), the data changes (owners, discovery, works,
  mode, good) or the cover rects change; never every frame. Only what is on screen is laid out.

### Fog (two fog levels, `docs/architecture/fog-build-spec.md`)

- **R12** An undiscovered hex, land or sea, is drawn with one flat "unknown" paper fill. No coast, border, district line,
  mountain mark, hatch, tint, goods shade, icon, dot or name is drawn on it or from it.
- **R13** A coast edge is drawn when its land hex is discovered. A border or district line is drawn only when **both**
  hexes are discovered. A country name, a legend count and a town list read discovered hexes only.
- **R14** Light fog (discovered, not in sight): owners and goods exact (land facts, as the fog build rules), and drawn as
  land in sight is. The parchment does not dim it and lays no sight veil, whatever `map/sight_veil` says (owner's
  decision, 2026-11-27; the tile view's veil is unchanged). Only undiscovered hexes differ (R12).
- **R15** The parchment draws no armies. Army tokens, war marks, paths and previews keep their own fog rules and draw above
  it, unchanged.
  Amendment (2026-11-28): while the parchment shows, the hexes the selected army reaches next season but not this one
  are hatched (the tile view's 8 % fill cannot be seen on the paper): diagonal stripes in screen px, a dark ink stripe 2.5 px wide (3.5 px in high
  contrast) and a pale one of 1.5 px beside it, every 9 px, so the land shows between them and one of the two is 3:1 or
  more against every land colour of the three modes, in both country palettes. This season's reach stays its flat fill:
  the two are told apart by pattern. The hatched hexes have a layer of their own (`reach_ahead`) that comes in with the
  cross-fade and is not drawn with the parchment hidden; the tile view's two reach layers are untouched
  (`ParchmentReach`).
  Amendment (2026-11-28): while the parchment shows (the cross-fade too), no reach of any layer lies on a hex the viewer
  has not discovered: on the unknown paper it would draw the coast of unknown land (R12). `MapArmies` fills the layers so
  and fills them again as the parchment comes or goes and as the viewer's discovery moves. On the tiles the reach is as
  before.

### Coexistence

- **R16** The parchment shows in Terrain and Owner mode by the zoom (D2), and in Goods mode at every zoom. It never shows in
  Relief, Yields, Food or Supply mode, nor during the country pick: those keep today's tiles, overlay and far picture.
- **R17** Under a solid parchment the tile layers, tile lines, borders, castle areas, `FarMap`, `CapitalMarks` and
  `CountryLabels` are hidden. In the fade band the tile borders and lines fade out as the parchment fades in, and
  `CountryLabels` fades by one minus the parchment's alpha. Reach overlays, the selection and build marks, preview, path,
  work, army and war marks and floaters stay above the parchment at every alpha.
  Amendment (2026-11-27, owner's playtest): the parchment lies solid only past the switch of D2. At the whole-map view
  and one default notch past it the tiles show whole, with their own borders, names and pennants; on a large map that is
  the far picture, and the tile view's reach and selection marks are hidden with it, as in the data modes.
  Amendment (2026-11-27): there is no resting fade band (D2); the same fades run during the 0.25 s cross-fade only. The
  place plates (`MapLabels`, key N) fade by one minus the alpha like `CountryLabels`, and names faded out block no plate.
  With `map/parchment` on the tile view itself is never hidden (showing it again builds every tile layer): its ground is
  switched off, and at the far zoom of the data modes its reach and marks are hidden with it. The army tokens, paths and
  reach draw over the parchment's names too (D1).
- **R18** `map/parchment` off: Terrain and Owner never turn to parchment (today's look); Goods mode still shows it (it is
  the goods map). `map/borders` off hides the parchment's borders too.

### HUD (the game's own frames)

- **R19** The top bar's mode switch gains a seventh segment, "Goods", where `MapModes.modes` offers Yields (a country game
  with a player). The bar's compact steps are measured again so nothing overflows at 1280 x 720.
- **R20** In Goods mode a kit-framed card ("Goods produced", `PanelFrame`, bottom left of the map area) shows one icon
  button per good that some family makes (Kit `good_*` icons, 6 a row, GameDefs order). The chosen good is marked by the
  kit's selected state, not by colour alone.
  Amendment (2026-11-27): the chosen good's button is filled with the kit's gold plate with its thick border, as in the
  mockup (the kit variation `ButtonChoice`, made of the primary button's pieces), and keeps its tick. In a small window
  the card stays bottom left: the legend moves out of its way before the card leaves its place, and the toasts move off
  it. Each button's tooltip: "Grain: 14 districts you know make it". A good no
  known district makes is shown and pickable, with "none you know". Under the grid, two greyed rows with a `SoonTag`,
  "Population" and "Unrest" (the mockup's "soon" modes; Food balance is the existing Food mode, key 5; plan question 1).
- **R21** `ModeLegend` in Goods mode: the good's name as title; rows "First stage", "Second stage", "Third stage" with their
  ramp swatches and pips, "Not here"; a last line "N districts you know make it".
- **R22** A kit button "Return to default map" in the bottom middle of the map area, clear of the HUD's cover rects, shown
  in every mode but Terrain and not during the pick; it sets Terrain (as key 1 does). Its tooltip names the key.
- **R30** (2026-11-28) While the parchment shows, the key hints at the foot of the map (the keys, and the line that army
  moves are final) stand on a thin strip of the kit's card (`PanelCard`; in high contrast its black field with the gold
  line), as wide as the hints shown, as solid as the parchment (it fades with it) and clear of the zoom control, the
  minimap, the scale bar, the log's button and the Return button. The tile view has no strip (`HintStrip`).
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
  Amendment (2026-11-27): a mouse press on the map (left, right or middle) gives the keyboard back to the map.
- **R26** Colour-blind safe: the goods ramp is one hue with lightness steps of at least 15 L* between stages, and the stage
  is also given by the pips and the hover line. Country tints follow `accessibility/country_colours`. High contrast
  (`accessibility/high_contrast`) draws the coast and borders 1 px thicker and the ink darker.
- **R27** Text contrast: name ink on its paper halo at least 4.5:1; lines on the land at least 3:1 (a test checks the token
  pairs). Every icon has a tooltip (the card's) or a hover line (the map's). Town names are 13 to 17 px, capitals 17 px,
  all scaled by `accessibility/text_size` and the UI scale.
  Amendment (2026-11-27): the district and mountain inks are decoration, about 2.1:1 on the land in the standard set.
  3:1 is kept for them in high contrast, and for all other line pairs in both sets.

### Performance (budgets in plan section 4)

- **R28** Static geometry is built once per map (sliced at `MapScene.slice_ms` a frame on a large map). A change of owner,
  discovery, sight, mode, good or works never rebuilds geometry: it writes texels or sets a uniform.
  Amendment (2026-11-27): a change of sight alone writes no texel (R14).
- **R29** On an ownership change only the touched texels are written and the names are laid out again; at most the
  existing `owner_change_frame_ms` (16 ms) with the parchment on.
  Amendment (2026-11-28): the parchment's speed rows are measured where it shows under D2, at zooms taken from the fit
  zoom, and the fade-band row during the cross-fade (plan section 4, the amendment of this date).

---

## 3. Decisions

- **D1 One controller node, one label node.** `ParchmentMap` (`shell/map/parchment_map.gd`, a `Node2D` at z 81 in
  `map_scene.tscn`, after `Overlay`) owns the meshes, shaders, data textures and the alpha. `ParchmentLabels`
  (`shell/mapview/parchment_labels.gd`, a `Control` in the `Names` canvas layer after `Labels`) owns names, dots and
  icons. The facts come from two pure views in `core/views/`: `ParchmentShape` (geometry) and `ParchmentView` (goods
  bytes, counts, legend, names, towns, tip). The shell draws; it holds no rules.
- **D2 The switch follows the fit zoom.** Amended 2026-11-27, owner's playtest (the parchment came too early): it shows
  only well past the whole-map view. With `fit` = `ZoomModel.fit_zoom` for the window's free map area, and no floor under
  it, zooming out the parchment comes under `fit × 0.80` and zooming in the tiles take over at `fit × 0.84`
  (`ParchmentSwitch.PARCHMENT_UNDER_FIT` and `TILES_FROM_FIT`, the pair to tune; a zoom between the two keeps what it
  shows). The zoom-out limit is `fit × 0.65` (`ZoomModel.MIN_MARGIN`; ui-and-controls-spec.md 4.3), so every map,
  however small its fit, reaches the parchment.

  | Zoom speed | Wheel notches out from the whole map to the parchment | Notches in from the limit to the tiles | Notches from the whole map to the limit |
  |---|---|---|---|
  | 50 % | 4 | 4 | 7 |
  | 100 % | 2 | 2 | 4 (the third stops at 0.66, the fourth adds 1 %) |
  | 200 % | 1 | 1 | 2 |

  A `+` or `-` key press or button is two notches: at 100 % one press from the whole map shows the parchment. The Fit
  button always shows the tiles. Only the camera's zooming chooses: a change of the free map area (the HUD hidden or
  shown, the window resized; no panel changes it), which moves the fit and may push the zoom up to the new limit, keeps
  what shows until the next zoom. A crossing cross-fades over 0.25 s of time; at rest the alpha is exactly 0 or 1. It
  switches at once on a load (also while a large map is still loading: the zoom alone says what shows, from the tiles'
  side), on a change of mode or setting, at the end of the country pick and under `reduce_motion`. Goods mode forces
  alpha 1 at every zoom. (Earlier the same day: `max(fit, 0.28)` times 1.2 and 1.24, the whole-map view parchment.)
  Amendment to D1 (2026-11-27): `ParchmentLabels` stands in the map scene's world just after `Parchment`, at its z, not
  in the `Names` canvas layer, so army tokens, war marks, paths, previews and reach are drawn over its names; it lays out
  in screen px and draws through the view's inverse transform. Its name spots and icon spots are
  `ParchmentNameSpots` and `ParchmentIconSpots`.
  Amendment (2026-11-28): the room a country name needs from the capitals is `ParchmentCapitalRoom`; the hatched reach is
  `shell/map/parchment_reach.gd` with its shader, driven by `MapSceneParchment`; the strip behind the key hints is
  `shell/hud/hint_strip.gd`, which reads the parchment's alpha from the node the HUD is bound to (no new bus signal).
  Amendment to D1 (2026-11-27): it is a `Node2D`, so the renderer culls it by what it draws. A `Control` of size 0 gave
  the renderer an empty rect, and the layer was dropped once the map's point (0, 0) left the screen.
- **D3 Static geometry, dynamic textures.** `ParchmentShape` gives, once per map, the land polygons (12 points a hex, every
  hex, sea too, so the unknown fill can cover sea), every edge as 3 points with its two hex indexes and a kind (coast or
  land-land), and the mountain marks with their hex. The shell turns them into one `ArrayMesh` a chunk (64 x 32 hexes)
  with the hex index in a vertex attribute. Textures of one texel a hex carry what changes, **already masked by the fog in
  core**: the known owner (`ParchmentView.owner_bytes`: the owner id, 0 unowned, 255 undiscovered, rebuilt by
  `MapModes.discovered_key` and the owners) and the goods bytes (good id plus one, and the stage; 0 when undiscovered);
  no sight texture (R14, 2026-11-27). So the shaders are never given a fact the viewer may not know, and the fog rules are
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
  speckle, hatch, land, unknown, district line, mountain, border, coast, name ink, halo, the goods ramp, icon disc, the
  reach's two stripes (2026-11-28);
  no veil, R14, 2026-11-27)
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
func set_options(tint: bool, borders: bool, colour_blind: bool, high_contrast: bool, enabled: bool) -> void  # no veil (R14)
func apply_zoom(zoom: float, fit: float) -> float  # sets visible and the picture's alpha; returns the alpha used
func picture() -> CanvasGroup                     # holds the layers and fades them as one (its self_modulate)
func is_fading() -> bool                          # true only while the alpha is between 0 and 1
var geometry_builds := 0                          # tests: never moves after the first build

# shell/mapview/parchment_labels.gd
class_name ParchmentLabels extends Node2D
func setup(game: Game) -> void                    # the viewer is game.player, read with the facts
func set_mode(mode: int) -> void; func set_good(good_id: int) -> void; func set_alpha(a: float) -> void
func set_cover(rects: Array[Rect2]) -> void
func relayout(xform: Transform2D, zoom: float, viewport: Vector2) -> void
func placed() -> Array[Dictionary]               # {kind: country|capital|town|icon, hex, text, rect, angle, size}
var layout_count := 0
```

---

## 5. Done when

1. On north Italy two wheel notches past the whole-map view the map is the parchment of the approved mockup in Terrain
   and Owner mode, inside the game's own top bar and HUD; the whole-map view and closer show the tiles, with a fade
   between (amended 2026-11-27, owner's playtest); Goods mode shows the goods map at every zoom.
2. Every case of R12 to R15 holds on the thin fog fixture, each with a planted fault (plan section 3).
3. The perf rows of plan section 4 hold on north Italy and the made-up Europe; the old map rows do not get worse.
4. The mode, the good and the parchment switch come back after a restart; the keys of R25 work.
5. The art director signs the pictures of plan section 3 next to the mockup; the owner plays plan section 5.
