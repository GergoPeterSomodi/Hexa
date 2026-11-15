# Normal-map pieces: the rule book

Art director, 2026-11-15. **Status: the owner answered the three open questions on 2026-11-15 (section 12); this
guide is rewritten to those answers and was made sharper after the second review (coverage, the mirror axis, boat
sizes, coast pieces on every sea side). Round 3 (the same day) adds the owner's two further answers: **two port
modes** (section 10) and **winter by climate** (section 7). Nothing in the game is changed.**

A **piece** is the picture of one hex's improvement at one level in one season, at the normal map zoom (the style
frame's close zoom: hex radius 60 px, one hex = one district). This guide and the drawing kit
(`tools/worldmap/pieces/kit.py`) are everything an artist needs to draw a family of pieces. Two families are the
reference: `wheat.png` and `settlements.png` in this folder (code: `wheat.py`, `settlements.py` next to the kit).
`kit_contract.png` shows the kit's side of the map contract (wild land, coast, footprint, mirror) on one page.
**When this guide and a reference sheet seem to disagree, follow this guide and report the gap**: the reference
sheets were drawn before the owner's answers and are brought up to date in review task 5.

The look itself (camera, light, palette, ink) is the style frame's: `../style-frame/README.md`. The stages follow the
growing-map plan (`../06-growing-map.md`, sections 2 and 5).

**Who draws what** (the owner's answers in one table):

| Thing | Drawn by | The piece's part |
|---|---|---|
| Ground colour | The map | None. The piece's ground base is for the sheets only |
| Wild land: woods, single trees, bushes, scrub, tufts, stones | **The map** | None. The piece reports its **footprint** and the map thins the wild land there (section 6) |
| Level 0 | **Nobody: it is no piece** | On the sheets the level 0 column is `kit.wild()`: the wild land as the map draws it |
| The coast: sea, sand, foam, the shore line | **The map** | The piece is told where the sea is and builds at that shore (section 10) |
| A port's bay (a carved port) | **The map**, with the kit's bay shape | The harbour is told its bay and builds in it (section 10) |
| The winter of a hex: snow, frost or mild | **The map**, by the hex's climate | None: the piece is drawn `draw(level, "winter")` as always; the kit is told the winter (section 7) |
| Rivers, streams, roads between hexes | The map | Gate points for roads (section 10); no water or road to the hex border |
| Town name plates | **Nobody, for now** | None. No plate, no plate strip |
| Repetition | The map picks by the hex | Every family has a mirrored version and a second layout (section 6) |

Contents: 1 canvas, 2 camera, 3 light and ink, 4 palette, 5 sizes, 6 how a level reads (level 0, footprint,
mirror and second layout), 7 seasons (and the three winters), 8 the family tables, 9 readability, 10 terrain fit,
the coast and the two port modes, 11 the reviewer's checklist, 12 the owner's decisions and what is still open.

---

## 1. Canvas

| Thing | Value |
|---|---|
| Hex | Pointy-top, radius 60 px: **104 px wide, 102 px tall** on screen (the height is already squashed to 85%) |
| Canvas | 112 x 112 px, the hex centred, alpha outside |
| Drawing | At 2x, then smooth-scaled to 1x. The kit does this; you always work in 100% pixels |
| Coordinates | Origin at the hex centre, x to the right, y down. The hex spans x -52 to +52 and y -51 to +51 |
| Ground base | The season colour of the terrain, with soft mottling, fading to transparent over the last **5 px** at the hex border so it blends with the neighbours. **The base is for the sheets only: on the map it is not drawn.** The map paints the ground and takes the piece apart into ground detail, shadows and standing things (`kit.take_apart`) |
| Wild land | **Not drawn by the piece.** No wild trees, bushes, scrub patches, tufts or stones of the terrain: the map has them. A piece draws only what people made (planted trees, hedges, orchards and a family's own rock or mound count as made) |
| Ground work | Fields, plots, pans, yards, canals, ponds and activity details stay **10 px clear of the hex border** (the map's rivers and roads run along the borders). This inner hex is the **margin hex**. Check the **corners** of slanted blocks: they are what pokes out. On the water (jetties, quays, moles, boats) only the 3 px rule for standing things holds: the neighbour there is sea |
| Footprint | The area the piece works. The kit measures it from what you draw (section 6); you never draw it |
| Standing things | Must lie wholly inside the hex, **3 px clear of the border**. The kit checks this and prints `PIECE PROBLEM` if not |
| Safe area | Put the main picture inside x -42 to +42, y -38 to +38. Remember the corners are cut: at y = +/-38 only x -18 to +18 is inside |

- The contract is `draw(level, season, variant=0, mirror=False)`. Start every picture with
  `kit.Piece(season, ground=..., seed=N, mirror=mirror)`. Use **one seed per family**, the same for every level,
  season and layout, so the ground mottling and the sheet's wild land never change.
- `draw(0, season)` returns `kit.wild(season, ground, seed=N)` and nothing else (section 6).
- Ground-plane shapes near the border are faded by the kit; do not try to stop them exactly at the border.
- **A change of the ground itself is an overlay, not a colour.** Trodden ground, cleared ground and tracks are
  laid half-transparent over whatever ground the map has: use `p.blob(..., alpha=)` and `p.road(..., track=True)`.
  Never mix a colour with the base ground colour yourself; the map's ground may differ. Trodden and cleared ground
  of alpha 0.25 or more counts for the footprint; that is how a clearing in a wood is made.
- Never draw outside the kit (no drawing on the returned surface, no own scaling).

## 2. Camera

One slight 3/4 view, the same for every piece.

- **Lying on the ground** (drawn flat, north-south at 85%): fields, plots, pans, yards, roads, tracks, canals, ponds,
  jetties, quays, moles, fences, hedges, terrace walls, the foot of a ring wall. Use the kit's ground calls
  (`field`, `rows`, `patch`, `road`, `water`, `pond`, `jetty`, `fence`, `hedge`, `terrace`). The coast itself is
  the map's; `p.coast()` tells you where it is (section 10).
- **Standing upright, unsquashed**: houses, churches, towers, walls, trees, mills, heaps, haystacks, boats, people,
  animals. They are seen from the front: you see the front wall and the roof slope, never the top. Use the kit's
  standing calls, or `p.stand(y, fn)` for your own landmark.
- **Back to front.** Standing things are drawn in order of the y of their foot; the kit sorts them. Always pass the
  true foot y.
- **Nothing tall in front of the landmark.** Keep a clear gap of at least 8 px below (south of) the level's landmark.
- No rotation of buildings, no second vanishing point, no bird's-eye plans of buildings.

## 3. Light, shadow and ink

- **Light from the upper left.** Every standing shape is two flat tones: lit on the left and front, shaded on the
  right. The shaded tone is the lit colour x 0.84 (walls) or the family's `_D` token (roofs, stone, timber). No
  gradients, no third tone, no highlights except the small light spot on round tree crowns.
- **Shaded strip.** On a box (house, tower) the right 22-24% of the front is the shaded tone (`pen.box` does it).
- **Ground shadow.** One soft dark ellipse to the lower right of the foot, colour (30, 50, 30) at 18% opacity. The
  kit's standing primitives add it; for your own landmark call `p.cast(x, y, foot_width)`. Never draw a hard or
  black shadow, never a shadow to the left.
- **A mirrored piece keeps the light.** Mirroring (section 6) turns the *positions* round, never the drawing: a
  mirrored house stands on the other side of the hex and is still lit on its left and shaded on its right, and its
  shadow still falls to the lower right. The kit does this; a module never tests `mirror` itself and never flips a
  picture.
- **Ink** is the token `INK` (52, 44, 46), never pure black.
  - **0.5 px** (the kit's default): houses, roofs, towers, heaps, boats, field edges.
  - **1 px**: only the outer line of a big mass more than 20 px wide (a mole, a fortress wall).
  - Trees have a dark-green rim instead of ink. Ground shapes have a darker edge of their own colour, not ink.
  - Never outline people, animals, tufts or smoke.

## 4. Palette

Use the kit's named tokens only. **No new colour without asking**; if a family needs one, add it as a named token at
the top of the family module and list it in your report.

**Fixed tokens (the same in every season)**

| Token | RGB | Used for |
|---|---|---|
| `INK` | 52, 44, 46 | Outlines |
| `PLASTER[0..4]` | 240,228,196 / 232,200,140 / 234,192,166 / 246,240,228 / 226,210,170 | House walls (pick by index) |
| `ROOF`, `ROOF_D` | 204,94,62 / 160,70,50 | Tile roofs: towns, farms, warehouses |
| `THATCH`, `THATCH_D` | 198,168,104 / 158,128,78 | Huts, barns, sheds, anything poor or rural |
| `SLATE`, `SLATE_D` | 112,116,132 / 82,86,102 | Castle and tower roofs, the windmill cap |
| `STONE`, `STONE_D` | 214,202,174 / 176,164,140 | Town walls, quays, moles |
| `STONE_GREY`, `STONE_GREY_D` | 176,172,166 / 132,128,126 | Castles, mine buildings, wells |
| `CHURCH` | 236, 226, 204 | Churches, lighthouses, mills |
| `TIMBER`, `TIMBER_D` | 150,110,72 / 112,80,54 | Palisades, jetties, fences, frames, logs |
| `TRUNK`, `DOOR` | 92,70,50 / 70,56,50 | Tree trunks; doors and dark openings |
| `HULL`, `SAIL`, `SAIL_D` | 120,78,52 / 246,240,226 / 214,206,190 | Boats |
| `ROAD`, `ROAD_EDGE` | 226,206,152 / 128,100,66 | Roads and tracks |
| `SNOW`, `SNOW_D` | 242,245,250 / 206,214,228 | Snow, lit and shaded |
| `ICE`, `ICE_D` | 206,226,238 / 172,200,220 | Frozen still water |
| `SALT` | 248, 246, 240 | Salt heaps and crystallising pans |
| `SPOIL`, `SPOIL_D` | 150,140,132 / 112,104,100 | Mine waste heaps |
| `FLAG` | 196, 52, 48 | Castle banners (stand-in for the owner's colour) |
| `SMOKE`, `SMOKE_SNOW` | 236,236,232 / 186,190,202 | Smoke puffs; the winter smoke |

**Season tokens** (`p.pal[...]` or `kit.PAL[season][...]`)

| Token | Spring | Summer | Autumn | Winter |
|---|---|---|---|---|
| `grass` (meadow, hills) | 152,196,92 | 146,186,86 | 172,174,84 | 228,233,238 |
| `farm` (plain, worked land) | 176,202,104 | 178,198,98 | 188,178,98 | 232,236,240 |
| `wood` (forest floor) | 120,172,82 | 112,164,78 | 152,152,76 | 216,224,230 |
| `rock` | 170,156,130 | 170,156,130 | 166,150,126 | 208,208,208 |
| `sand` | 234,216,162 | 234,216,162 | 230,212,160 | 234,230,214 (snow on sand) |
| `soil` / `soil_d` (bare earth) | 152,114,78 / 124,92,64 | 162,126,86 / 132,100,70 | 140,102,70 / 112,80,56 | 176,156,136 / 150,128,110 |
| `sea` / `shallow` | 71,143,192 / 96,168,210 | the same | 66,134,182 / 92,160,202 | 62,122,166 / 104,158,194 |
| `river` | 74,146,206 | 74,146,206 | 70,138,196 | frozen: `ICE` |
| `leaf` (broadleaf: dark, mid, light) | 86,150,66 / 118,180,80 / 156,208,104 | 70,128,60 / 96,158,72 / 130,186,92 | a fixed mix of rust, gold and late green (`LEAF_AUTUMN`) | bare twigs |
| `conifer` (lit, shaded) | 66,120,70 / 46,92,58 | the same | 66,116,68 / 46,90,56 | 62,106,72 / 44,82,60, snow on the left |
| `hedge` / `hedge_d` | 84,140,66 / 56,100,52 | 70,128,60 / 46,92,50 | 150,112,52 / 108,78,44 | 108,96,76 / 78,68,56 |

The winter column is the **snow winter**. The frost and the mild winter have palettes of their own
(`kit.WINTER["frost"]`, `kit.WINTER["mild"]`; section 7). A piece never picks one: `p.pal[...]` and
`kit.crop(name, "winter")` already give the colours of the hex's winter. **Never read `kit.PAL["winter"]` directly.**

**Crop colours** come from `kit.crop(name, season)`: `wheat`, `garden`, `meadow`, `vine_soil`, `vine`, `olive_soil`.

**Each family owns one signature.** No other family may use it, so two hexes never look alike:

| Family | Signature colour and pattern | Signature landmark |
|---|---|---|
| Wheat | Blocks of long gold strips | Windmill |
| Vineyard | Thin dark rows on pale brown soil; red rows in autumn | Press house with vats; the estate house |
| Olives | Silver-green round trees in a grid on pale ochre terraces | Oil mill with a millstone |
| Grazing | One-colour pale meadow inside fences, animal dots | Long low byre or stable |
| Salt | A grid of square pans, white heaps in a row | Salt store |
| Mines | Grey spoil heaps, a dark tunnel mouth | Headframe with wheel; smelter chimney |
| Timber | Stumps and log piles in a clearing | Sawmill with wheel; log raft |
| Harbour | Jetty, quay and moles of pale stone, sails | Lighthouse |
| Settlements | A cluster of red roofs round a church | Church, wall, cathedral dome |
| Castles | Grey stone on a mound, slate roofs, a red banner | The keep |

Banners belong to castles only. Red tile roofs in a cluster of four or more belong to settlements only: goods
families have **at most three** houses, mostly thatch.

## 5. Sizes and scale

The scale is symbolic (a hex is 28 km): a house stands for a hamlet's worth of houses. All sizes in px at 100%.

| Thing | Size | Kit call |
|---|---|---|
| House | 7-8.5 wide, wall 4.4-5 tall, roof 3.2-4 tall (about 8 px in all) | `p.house(x, y, w, h, roof_h)` |
| Tall town house | wall up to 6.5 tall, only inside walled places | the same |
| Barn, warehouse, byre | 9.5-13 wide, wall 5-5.5, roof 4.5, no door, thatch (tile for warehouses) | `p.house(..., door=False)` |
| Hut | 5.5 wide, wall 3.5, roof 3, thatch | `p.house(x, y, 5.5, 3.5, 3.0, roof="thatch")` |
| Chapel / church / cathedral | Tower 8 / 13 / 17 tall (cathedral drawn at scale 1.3) | `p.church(x, y, size, sc)` |
| Round tree | Crown radius 4.4, about 10 tall, at size 1.0. Use sizes 0.85-1.0 | `p.tree(x, y, 1.0, "round", i)` |
| Conifer | 7 wide, 12.5 tall | `"conifer"` |
| Poplar / cypress | 4 wide, 15 tall | `"poplar"` |
| Olive, fruit tree, bush | Crown 7x5 / radius 3.2 / radius 2.6 | `"olive"`, `"fruit"`, `"bush"` |
| Field strip | **3-4.5 px wide**, 28-38 long | `p.field(...)` |
| Field block | 4-6 strips: 28-38 x 18-26 before the tilt | |
| Garden plot | 12-15 x 7-9, 3 strips | `p.field(..., kit.crop("garden", season), 3)` |
| Plant rows (vines) | Rows 1.2 px wide, 4-5 px apart | `p.rows(...)` |
| Ring wall | 4 px tall (palisade 3.4); wall towers 4.2 wide, 7.5 tall | `p.wall(cx, cy, rx, ry, kind)` |
| Free-standing tower | 4-6 wide, 9-18 tall | `p.tower(...)` |
| Tallest thing allowed | 20 px (a keep, a cathedral tower, a lighthouse) | |
| Trading ship / fishing boat / small boat on the beach | 12 long, 13 tall (size 1.0) / size 0.7 / size 0.55, no sail | `p.boat(x, y, sc)` |
| Person | 1.2 wide, 3.4 tall | `p.person(x, y, col)` |
| Sheep / cow / horse | 3.4x2.4 / 4.5x2.5 / 4.5x4. A sheep is a clean pale body with a dark belly line and head, no outline | `p.animal(x, y, kind)` |
| Haystack, heap | 4.6x4.6; heaps 5-12 wide, 4-7 tall | `p.haystack`, `p.heap` |
| Road / track | 2 px with an edge / 1 px, no edge | `p.road(pts, w, track)` |
| Canal, stream | 1.4 / 3 px | `p.water(pts, w)` |

Ring walls are ellipses with ry = 0.55 x rx (the tilt). Keep at least 5.5 px between house feet sideways and 3.4 px
front to back, or roofs merge into one red mass.

## 6. How a level reads

A level is the **character of the whole district**, not one building. Four things grow together:

1. **Coverage.** The share of the hex that is worked: level 1 = about 20%, level 2 = about 45%, level 3 = about
   70% (settlements and castles: the footprint width grows about 12 px per level). **It is measured as the
   footprint's share of the margin hex** (the hex pulled in 10 px: the only ground a piece may work), in summer,
   layout 0. Bands that pass: level 1 15-30%, level 2 35-60%, level 3 60-85%. Of the whole hex that is about
   12-20%, 23-40% and 40-58%, so a full level 3 still leaves a quarter of the hex plain.
2. **Silhouette.** The tallest thing gets taller: level 1 up to 9 px, level 2 up to 13 px, level 3 up to 20 px.
3. **Density.** More of the same unit: blocks, rows, pans, heaps, houses, animals.
4. **One landmark per level.** Each level adds exactly one new landmark that no lower level has. It stands at or
   near the centre with a clear gap in front, and it is the thing a player learns to look for.

**The additive rule (what must stay the same).** Level N is level N-1 plus more. So:

- The **layout is a fixed table** in the module: every block and building has one position and a `from level`.
  Nothing moves, turns or changes size between levels.
- The **yard** (the home building and its place in the hex) is the same at every level.
- The **terrain is the same at every level**: the same `ground`, the same seed.
- A building may be **upgraded in place** (thatch to tile, hut to house on the same foot), never moved.

**The season never changes the layout.** Positions never depend on the season; only colours and the listed season
details do. Do not seed any random number with the season.

### Level 0 is no piece

The owner's answer: **the map draws the wild land**. A hex without an improvement is simply the map's own hex, so
on the map there is no level 0 picture.

- `draw(0, season)` returns `kit.wild(season, ground, seed=N)` with the family's own ground and seed (a coast family
  adds `coast={...}`, the keywords of its `p.coast()` call). It is the generic wild scatter of that terrain and it
  is **for the sheets only**: the level 0 column shows the land the work will be set into.
- `kit.take_apart(draw, 0, ...)` returns `None`: the map asks for no piece.
- Levels 1 and up draw **no wild scatter**: no `WILD_TREES`, no scrub patches where work will come, no terrain tufts
  or stones. Delete those tables. Planted things stay: fruit trees by a house, poplars on a canal, cypresses, olive
  trees, hedges.
- Sheets of a module without wild scatter are made with `kit.sheet(..., wild=True)`: the kit then shows every piece
  standing in the terrain's wild land, thinned by the piece's footprint, as the map will. Check the piece there, not
  on bare ground.

### The footprint: how the wild land is thinned

The piece no longer clears the hex. The map keeps its own trees and scrub in the hex and leaves out only those that
stand **in the piece's footprint** (`kit.take_apart(...)["footprint"]`, a mask of the piece canvas; red in
`kit_contract.png`). You do not draw the footprint; the kit measures it from the piece:

| Counts for the footprint | Does not count |
|---|---|
| Ground detail that is a real surface: fields, plots, pans, yards, ponds, roads, trodden or cleared ground of alpha 0.25 or more. Grown by 3 px | Thin lines: tracks, fences, hedges, terrace lines, canals under 2 px |
| The foot of every standing thing: 2 px to each side and up to 10 px in front of it (so no wild tree stands in front of a building) | Smoke; faint overlays under alpha 0.25 |

What follows for the drawing:

- **In a wood the piece makes its own clearing.** A hamlet in a wooded hex keeps the wood round it; only the houses'
  feet and the yard are cleared. If a family needs open ground round its work (timber's felling, a mine's work
  yard, the trodden ground of a herd), draw it: `p.blob(x, y, w, h, p.pal["soil"], alpha=0.3...0.6)`. No blob, no
  clearing.
- **Coverage is now measured**: the footprint's share of the margin hex should lie in the bands above.
- **The inside of a ring wall is footprint** although little is drawn on it: the kit claims it (`p.wall` does it;
  a family's own ring calls `p.claim(points)`). Use `p.claim` for any court or square that must stay free of the
  map's trees; do not paint a blob only to clear it.
- **Woods thin from the front.** Where a family grows into a wood (timber), the footprint grows from the south
  towards the north with the level; the back of the hex stays wild to the last level.
- The map's duty, not the piece's: the wild land never stands in a footprint, and it is the same in every season
  and at every level, so a level-up only removes wild things, it never moves them.

### Mirror and second layout

The owner's answer: **every family gets a mirror and one second layout, chosen by the hex.** Two hexes of the same
level side by side must not be the same picture.

- **The contract.** `draw(level, season, variant=0, mirror=False)`; the module says `VARIANTS = 2`. The map calls
  `kit.pick(col, row, VARIANTS)` and gets `(variant, mirror)` for the hex: always the same answer for the same hex,
  and with two layouts no two neighbours get the same picture.
- **The mirror comes from the kit.** Pass `mirror=mirror` to `kit.Piece` and draw as always, in unmirrored
  coordinates. The kit turns the ground detail round and moves every standing thing to its mirrored place without
  flipping it (section 3). Rules for your own landmarks:
  - Draw them with `p.stand(y, fn)` and shadow them with `p.cast(x, y, w)`; then they mirror by themselves. If you
    must place a shadow by hand, shift it with `p.m` (`p.shadow(x + p.m * 3, ...)`; `p.m` is -1 in a mirrored piece).
  - A part that belongs to another thing (smoke on an off-centre chimney, a wheel on a mill's side, a door on a
    tower) gets `on=`: `h = p.stand(...)` returns a handle, `p.smoke(x, y, always=True, foot=y0, on=h)` and
    `p.stand(y, fn2, on=h)` move with it.
  - **Give `x=` to every part of a structure that is built from several `p.stand` calls round one axis** (a
    keep and its wall, a gate tower in a ring, a headframe): `p.stand(y, fn, x=<the x of the structure's middle>)`.
    Without `x=` the kit turns each part round the middle of *its own picture*, and a part that is not symmetric
    (a tower with a banner, a frame with a stay) lands a pixel or two off. Kit calls (`house`, `tower`, `tree`...)
    do this themselves. `on=` is for a part that hangs on another thing; `x=` is for parts that share an axis.
  - `p.m` (-1 in a mirrored piece) is for a hand-placed shadow and for a thin line that must point at a
    neighbouring thing (a stay, a rope). Never use it to flip a shape that has a lit side.
  - Smoke on a chimney that is off the middle keeps its side in the mirrored piece (`on=`); that is right.
  - Never write `if mirror:` and never use private kit calls; both break the mirror.
  - The `GATES` table stays unmirrored; the map mirrors it with `kit.mirror_gates(GATES, mirror, variant)`.
    `GATES` is one dict when all layouts end at the same gate points (the rule so far), or a list with one dict
    per layout.
- **The second layout** (`variant=1`) is the same district arranged differently. Same landmarks, same counts, same
  coverage, same signature, same additive rule and seasons inside the layout. Different:
  - the **yard stands somewhere else**: at least 14 px from layout 0's yard and from its mirror image;
  - the blocks, rows or pans lie at other places and angles, and the landmark of the top level stands in another
    part of the hex;
  - at 50% it must be told from layout 0 **and from layout 0 mirrored** at a glance. If it looks like either, it is
    not a second layout.
  Keep both layouts as tables side by side at the top of the module (`LAYOUT = [dict(...), dict(...)]`), never as
  offsets of each other.
- **The second sheet.** `kit.variant_sheet(draw, LEVELS, title, path, NAMES, ground=...)` writes
  `<family>_variants.png`: each level as layout 0, layout 0 mirrored, layout 1, layout 1 mirrored, and a block of
  5 x 4 touching hexes of the top level as `kit.pick` chooses them. Look at the block first: it must read as a
  countryside, not as wallpaper.
- Order of work: wheat, grazing, timber and vineyard first (the most common), then the rest. Until a family has its
  second layout it says `VARIANTS = 1` and the map uses the mirror alone.

## 7. Seasons

One game turn is one season, so the player sees these change every turn. The change must be **strong in colour,
zero in layout**.

| | Spring | Summer | Autumn | Winter |
|---|---|---|---|---|
| Ground | Fresh, slightly yellow green | The style frame's colours | Yellowed olive green | Snow: pale blue-white, mottled with the shaded-snow tone |
| Broadleaves | Light green | Mid green | Rust, gold, late green by tree index | Bare twigs, a dab of snow |
| Conifers, olives | Unchanged | Unchanged | Unchanged | Snow on the lit (left) side |
| Fruit trees | White blossom dots | Green | Autumn colours | Bare |
| Crops | Young and green, some bare soil | Ripe (the family's signature colour at its strongest) | Harvested: stubble, bare soil, red vines | Under snow, with the pattern still showing |
| Roofs | Normal | Normal | Normal | Snow, with a 1 px band of the roof colour at the eave (so a red town stays red-rimmed on snow) |
| Still water, canals, streams | Open | Open | Open | Frozen (`ICE`) |
| Sea | Open | Open | Slightly darker | Darker, **never frozen** |
| Smoke | None | None | From 1 house in 3 | From 1 house in 3; grey (`SMOKE_SNOW`) so it shows on snow |
| People, animals | A few | The most (work in the fields) | A few (harvest, ploughing) | None outdoors, or 1-3 by the buildings |

### Winter by climate: the three winters

The owner's answer (round 3): **not all of the map gets snow.** Winter has three steps, and every hex has one of
them for good. Sheet: `winters.png`.

| | **Snow** (the hard winter) | **Frost** (the light winter) | **Mild** (the Mediterranean winter) |
|---|---|---|---|
| Where | The Alps, high ground, the north and the inland east | Lowlands between: the Po plain, the hills, north-west Europe | The Mediterranean coasts and the south |
| Ground | Snow: pale blue-white | Frosted, pale grey-green, with patches of thin snow | **No snow.** Rain-darkened green-grey; dark wet earth |
| Worked ground | Under snow, the pattern showing | Under a thin snow, the pattern and more earth showing | Bare: young winter corn in dark earth, bare vine stakes on brown soil, dull meadows |
| Roofs, heaps, walls | Snow caps | Snow caps | Their own colours: a red town stays red |
| Broadleaves, fruit trees, vines | Bare, a dab of snow | Bare, a dab of snow | Bare, no snow |
| Conifers, olives | Snow on the lit side | Snow on the lit side | Unchanged: **olives stay green** |
| Still water, canals, streams | Frozen | Frozen | Open |
| Sea | Darker, never frozen | The same | The same |
| Smoke, people, animals, boats | The winter rules of the table above | The same | The same: it is still winter (boats laid up, few animals out, smoke) |

**The contract: a module does not change.** It is still called `draw(level, "winter")`. The map tells the kit the
hex's winter: `kit.take_apart(draw, level, "winter", ..., climate="frost")`; on a sheet
`kit.with_wild(draw, level, "winter", climate="mild")`; around any other call `with kit.climate("mild"): ...`.
Without it the winter is the snow winter, as before, so every existing sheet is the same picture.

What a module must know:

- `p.season == "winter"` (and a module's own `season == "winter"`) is **the season**, in every climate. Hang on it
  what the season does: boats laid up, few animals out, smoke, no people in the fields, the winter log pile.
- `p.winter` is True where **snow lies** (snow and frost winters). Ask it, and nothing else, before drawing snow:
  `kit.SNOW if p.winter else ...`. In a mild winter it is False.
- `p.frozen` is True where still water is frozen (the same two winters). Ask it before using `kit.ICE`.
- `p.climate` is `"snow"`, `"frost"` or `"mild"` in winter and `None` otherwise. A module should not need it.
- Colours: `p.pal[...]` and `kit.crop(name, season)` only. A module that keeps a table of its own colours per
  season needs a winter entry for the mild winter too (grazing's `MEADOW["winter"]`).
- The safety net: while a mild piece is drawn the kit reads `kit.SNOW`, `kit.SNOW_D`, `kit.ICE` and `kit.ICE_D` as
  wet earth and open water, so an older line that paints snow whenever the season is winter cannot turn a
  Mediterranean hex white. It is a net, not a way to draw: such lines are moved to `p.winter` and `p.frozen`
  when the module is next opened (review, "Round 3").

**The rule: which hex has which winter.** From three numbers of the map data, the same in every year:

- `lat`: the latitude of the hex centre (degrees north);
- `m`: the hex's mean height in metres (the ETOPO heights of the map data);
- `sea`: km from the hex centre to the nearest sea.

`kit.winter_of(lat, m, sea)` gives the name; `kit.cold_index(lat, m, sea)` the number behind it:

```
warm = (50 - lat) / 8, kept between 0.25 and 1          the sea warms the south, hardly the north
m'   = m x min(1, sea / 25)                             a coastal hex is settled at sea level
cold = 0.5 x (lat - 36) + m' / 300
       - warm x (3.5 x max(0, 1 - sea / 40) + 2 x max(0, 1 - sea / 15))
       + min(2, sea / 300)                              far from any sea it is colder
mild below 4.5;  frost from 4.5;  snow from 8.0
```

| Hex | lat, m, sea | cold | Winter |
|---|---|---|---|
| Genoa | 44.3, 367 m, 5 km | 1.4 | mild |
| Savona; Pisa | 44.3, 758 m, 13 km; 43.7, 374 m, 12 km | 3.7; 2.2 | mild |
| Pavia, Asti, Turin (the Po plain) | 45.2, 91 m, 104 km ... | 5.2 to 6.3 | frost |
| Serravalle (Apennine foothills) | 44.8, 498 m, 54 km | 6.2 | frost |
| Cuneo; Susa (the Alps) | 44.3, 2062 m; 45.2, 3320 m | 11.2; 16.2 | snow |

The map may let its own ground follow the same number point by point instead of hex by hex, so the snow line
runs along the mountains and not along hex borders (the in-map test does this); a **piece** always takes the one
winter of its hex. The rule is a first cut for this region: on the whole map it is to be tuned against a list of
known places before it is fixed (the Atlantic west and the head of the Adriatic are the doubtful ones).

**Snow rules** (where snow lies: the snow and frost winters).
- Snow is `SNOW` on lit and flat tops and `SNOW_D` on shaded sides. It never covers a wall face, a door, a tower
  shaft, a hull or the sea.
- In a frost winter a piece is drawn as in a snow winter; only its palette is the frost one (thin snow on the
  worked ground, frosted ground between). In a mild winter there is no snow, no ice and no snow cap anywhere.
- A worked pattern must still read under snow: draw strips, rows and pans in two snow tones with their edges, and
  leave **one strip in four showing earth**. Hedges, fences, terrace walls and roads stay visible.
- Heaps, haystacks, battlements, wall tops and log piles get a snow cap. The kit does this for its own primitives.

**Activity details: at most three per piece**, small, and placed on the newest work of the level. Each family's
table lists them. Use them to say what the season *does* here: sheaves at harvest, a plough team, smoke, frozen pans,
boats laid up.

**What not to add.** No falling snow or rain, no weather, no night, no puddles, no flowers on open ground, no
flying birds, no festivals, flags or bunting (banners are for castles), no text or icons, no fruit drawn on trees,
no fallen-leaf carpets, no animals in the fields of crop families beyond the one plough team, no carts on roads
(roads are another layer), no new buildings or scaffolding in any season.

## 8. The family tables

"Landmark" is the one new thing of that level. "Count" numbers are targets, not ranges to explore. **Level 0 is the
same line in every table and is left out: no piece; on the sheet `kit.wild(season, ground, seed)`.** The tables
describe layout 0; layout 1 has the same content in another arrangement (section 6).

### Wheat fields (reference: `wheat.png`). Ground: `farm`

| Level | What is drawn | Landmark |
|---|---|---|
| 1 | A thatched farmhouse with a fruit tree, 1 block of 6 strips, a track | The farmhouse |
| 2 | 3 blocks with hedges on two sides, the house re-roofed in tile, a second fruit tree, a haystack | The thatched barn |
| 3 | 5 blocks, a canal with 3 poplars that **ends in a small pond at each end, inside the hex** (it never runs to the border), a second house, a second haystack | The windmill |

Seasons: spring green shoots with one bare strip in four; summer gold, the newest block half cut, with sheaves and
1-2 reapers; autumn ploughed earth and stubble with furrow lines, a plough team on the first block, smoke; winter
snow strips with furrows. Haystacks stand from summer to winter, not in spring.

### Vineyard and winery. Ground: `grass` (sunny hills)

| Level | What is drawn | Landmark |
|---|---|---|
| 1 | 2 small blocks of young vines (dashed rows), a thatched hut | The hut |
| 2 | 4 blocks of full rows at two different angles, the hut becomes a tiled house | The press house: a wide tiled building with a big dark door and 2 round vats beside it |
| 3 | 6 blocks, the upper two with 2-3 terrace walls; a track | The wine estate: a tall house with a small cone-roofed tower and 2 cypresses (`poplar`) |

Seasons: spring light green rows; summer dark green rows; autumn **red rows**, 2 pickers and a row of 3 baskets on
the newest block, smoke; winter bare brown stakes on snow soil. The rows are the signature: never fewer than 5 per
block.

### Olives. Ground: `grass` (warm coast hills)

| Level | What is drawn | Landmark |
|---|---|---|
| 1 | 7 olive trees in two loose groups, a hut | The hut |
| 2 | 15 olive trees in straight lines on 3 terrace walls, pale ochre soil patches under them | A stone farmhouse (`STONE` walls, tile roof) |
| 3 | 24 olive trees on 5 terrace walls reaching the back of the hex, a track | The oil mill: a long stone building with a round millstone (a pale disc with a dark centre) in front |

Seasons: olives are evergreen, so the **tree colour never changes**; the ground and the soil patches do. Spring
blossom dots on the ground under 1 tree in 3; summer plain; autumn (the harvest) pale cloths under 3 trees and 2
pickers; winter a snow dab on each crown, snow ground, terrace walls still showing.

### Grazing: sheep, cattle or horses. Ground: `grass`

One layout, three animals: `draw(level, season, animal="sheep")`, one sheet per animal.

| Level | What is drawn | Landmark |
|---|---|---|
| 1 | 5 animals loose in one group on a trodden patch (an overlay: it is the footprint), a shepherd, a thatched hut | The hut |
| 2 | 1 fenced meadow (a `meadow` field of one colour inside a `fence`) with 8 animals, a haystack | The byre: a long low thatched barn (horses: a stable with a fenced yard) |
| 3 | 3 fenced meadows, 13 animals, 2 haystacks, a track | The market hall: a wide tiled building on timber posts (sheep: wool hall; cattle: dairy; horses: stud house) |

Seasons: spring 2-3 smaller young animals beside the grown ones; summer all animals out, haymaking (extra
haystack); autumn all out, haystacks; winter **only 3 animals**, close to the byre, smoke, snow-capped haystacks.
Animals always stand inside the fences from level 2.

### Salt pans. Ground: `sand`, at the map's shore (`p.coast()`, section 10)

| Level | What is drawn | Landmark |
|---|---|---|
| 1 | 4 square pans with low dykes in a row along the shore, 1 salt heap, a thatched hut, a trodden path | The hut |
| 2 | 8 pans in 2 rows, a feeder channel from the shore, 3 heaps in a row | A sluice gate on the channel (a small timber frame) |
| 3 | 14 pans in 3 rows, 5 heaps in a row, a short jetty with 1 boat | The salt store: a long warehouse |

Everything is laid out in shore coordinates (`shore.pt(u, v)`): the rows of pans run along the shore, the channel
and the jetty run out to it. **On a lagoon** (a hex the map data marks as lagoon) the map draws a shallow bay with
the same bay shape as a carved port and the pans lie on its shore: no layout of its own, the jetty and the boat
only keep inside the lagoon (`shore.bay.room(u)`). Pans are `p.patch` squares of 9-11 px with a `STONE_D` edge, laid as a strict grid. Seasons: spring pans filled,
blue-grey (mix of `shallow` and `sand`); summer pans white and pale pink as they dry (`SALT`), the heaps at full
size, 2 rakers; autumn grey pans, heaps covered (thatch colour); winter pans frozen (`ICE`) with snow edges, heaps
covered with a snow cap, nobody out.

### Mines. Ground: `rock` (scree and boulders are the map's wild land: the piece draws none)

| Level | What is drawn | Landmark |
|---|---|---|
| 1 | A low rock outcrop at the back (the family's own raised ground, from level 1 on), a hut, 1 spoil heap, a trodden work yard, a track | The adit: a dark arched mouth in the outcrop with a timber frame |
| 2 | 2 huts, 2 spoil heaps, a short wheel race (the piece's own water: 2 px, a small pond at each end, inside the hex) | The headframe over a shaft with a water wheel |
| 3 | A row of 3 miners' houses, 3 spoil heaps, an ore pile | The smelter: a stone building with a tall chimney |

Seasons change little here, on purpose (spring and summer are the same picture): ground palette, snow caps on
roofs and heaps, the race frozen. The
smelter chimney smokes **in every season** (the one exception to the smoke rule). No people.

### Timber and logging. Ground: `wood`

The wood is the map's. The piece draws **the clearing and the work in it**; the map's trees stand everywhere else.

| Level | What is drawn | Landmark |
|---|---|---|
| 1 | A clearing at the front centre (cleared ground, an overlay, about 20% of the hex) with 5 stumps, a hut | The charcoal mound: a dark heap with smoke |
| 2 | The clearing wider (about 45%), 2 log piles, a track, a short mill race ending in a pond at each end, inside the hex | The sawmill on the race: a timber house with a water wheel |
| 3 | The clearing reaches the middle of the hex (about 65%; the back third stays wood), 4 log piles, a long shed | The log raft on the mill pond |

The clearing grows from the front (south) to the back; its outline is irregular (three or four overlapping
`p.blob(..., p.pal["soil"], alpha=0.6)`), never an ellipse. No trees are drawn: on the sheet the kit's wild wood shows
what the map will do (`kit.sheet(..., ground="wood", wild=True)`). The piece draws no stream: streams are the
map's. The mill race is the piece's own water, like the wheat canal: 1.4 px, ending in a small pond at each end,
10 px clear of the border. Seasons: winter is felling time: one more log pile, the race and pond frozen and **no
raft**; the charcoal mound smokes in every season.

### Fishing and harbours. Ground: `grass`, at the map's shore (`p.coast()`, section 10)

| Level | What is drawn | Landmark |
|---|---|---|
| 1 | 2 thatched huts, 2 fishing boats, 1 small boat drawn up on the beach, a net rack (2 posts and a line) | The timber jetty |
| 2 | A stone quay along the shore, 3 fishing boats, 1 ship | The warehouses: 2 long tiled buildings on the quay |
| 3 | Two stone moles round a basin with a mouth about 40 px wide, 3 warehouses, 2 ships, 3 boats, a hull on a slip (the shipyard) | The lighthouse on the bend of the first mole |

Everything is laid out in shore coordinates (`shore.pt(u, v)`): quay and warehouses along the shore, jetty and moles
out from it, huts inland. The sea is wherever the map has it; the sheets show it in front. Seasons: spring and
summer the boats are out at sea with sails; autumn half of them are at the jetty; winter all boats are laid up at
the jetty or quay with bare masts (`sail=False`), snow on roofs and moles, the sea darker. The lighthouse lamp is
yellow in every season.

**Two port modes** (section 10): on an open shore the harbour is built out from it (**seaside**, the table above);
in a bay the map has carved for a great port it is built into the bay (**carved**): the quay along the back of
the bay, two short moles from the bay's horns across its mouth, the lighthouse on a horn, ships and boats inside.
Same levels, same landmarks.

**The harbour as an add-on.** A port town is a settlement piece plus the harbour's works at the hex's own shore
(the owner's answer 2). `draw(level, season, ..., addon=True)` draws only what stands at the water's edge: jetty,
quay, moles, lighthouse, the hull on the slip, ships and boats. No huts, no warehouses, no net rack, no beach
widening, no trees. The add-on has the same three levels and the same layout as the full piece, so a fishing
village that grows into a port town keeps its harbour.

### Settlements (reference: `settlements.png`). Ground: `grass`. Levels 1-5

| Level | Name | What is drawn | Landmark |
|---|---|---|---|
| 1 | Hamlet | 3 thatched houses, 2 garden plots, a track, 2 fruit trees | The well |
| 2 | Village | 7 houses (half thatch), 4 garden plots, 2 tracks | The chapel |
| 3 | Town | 11 tiled houses, 4 plots outside, 2 roads | The palisade ring with a gate, and the church |
| 4 | Walled town | 16 houses (a few taller), 3 roads | The stone wall with 2 towers and a gate tower |
| 5 | City | 24 houses, 4 suburb houses outside the wall | The cathedral dome; 4 wall towers and 2 at the back |

The church and the green in front of it are at the same spot in every level, and the place keeps its middle 7 px
above the hex centre. **There is no name plate and no plate strip** (the owner's answer 1): the ground in front of
the place is ordinary open ground, the south road ends at its gate point, and plots and suburb houses may use it
within the usual margins. The round trees round the place are wild land and are not drawn; the fruit trees by the
houses are planted and stay. A town on the coast is not a coast piece: the map clips it at its shore and adds the
harbour add-on there. Seasons: garden plots follow the season, blossom on fruit trees in spring, 1-2 people on
the green in spring and summer, smoke from 1 house in 3 in autumn and winter, snow roofs and a grey trodden ground
inside the ring in winter.

### Castles. Ground: `grass`. Levels 1-3. `draw(level, season, flag=kit.FLAG)`

All three stand on the same low mound (a darker-edged ellipse about 40 x 20 px) at the centre.

| Level | Name | What is drawn | Landmark |
|---|---|---|---|
| 1 | Watchtower | A small palisade ring (rx 10), a track | One grey stone tower, 14 px tall, with a slate cone roof and the banner |
| 2 | Castle | A grey stone ring wall (rx 17) with 2 corner towers and a gatehouse, a road | The keep: a square tower 18 px tall with battlements and the banner |
| 3 | Fortress | A low, thick, angular outer wall with 4 pointed bastions lying round the castle, a moat (water) round it, 2 banners | The bastions |

Use `STONE_GREY` for castles so they never read as a town. No houses, no red roofs. Seasons: the mound follows the
ground, snow on battlements and roofs, the moat frozen in winter, smoke from the keep in winter only. The banner
colour never changes with the season.

## 9. Readability

- **At 100%**: each level must be told from its neighbours at a glance, without counting. Cover the labels on your
  sheet and name the levels; if you hesitate, raise the difference in coverage or silhouette, not the detail.
- **At 50%** (the right-hand grid of the sheet): the family must still be recognised by its signature, and the wild
  land, the middle levels and the top level must still differ. Level 1 must be told from the wild land at 50%: it
  is the first thing a player builds. Details may vanish; the landmark of the top level may not.
- **Winter** is the hardest column. Check that the worked pattern and every landmark still read on snow.
- **Clutter limits**: no more than 3 houses in a goods piece; no more than 3 activity details; no two standing things
  with feet closer than 4 px unless they are meant as one cluster; keep 25% of a level-3 hex as plain ground.
- **Repetition**: on the variants sheet the block of 5 x 4 hexes must not show a pattern of identical pictures;
  layout 1 must not look like layout 0 or its mirror.
- **Look-alikes**: put your sheet next to the two reference sheets and to any finished family. If a piece could be
  taken for another family or another level at 50%, change it and say so in your report.

## 10. Terrain fit and the coast

| Family | Sits on | `ground=` | Notes |
|---|---|---|---|
| Wheat | Plain, lowland | `farm` | |
| Vineyard | Sunny hills | `grass` | |
| Olives | Warm coast hills | `grass` | Pale `olive_soil` patches under the trees |
| Grazing | Highland, poor hills | `grass` | |
| Salt | Low sandy coast | `sand` + `coast()` | The sea side comes from the map |
| Mines | Hills and mountains with ore | `rock` | Scree and boulders are the map's; the outcrop is the piece's |
| Timber | Woods | `wood` | |
| Harbour | Sheltered coast | `grass` + `coast()` | The sea side comes from the map; also an add-on to a town |
| Settlements, castles | Any land but high peaks | `grass` | |

- The base ground is the **terrain**, never the improvement: it does not change with the level.
- Pieces are flat-land pictures. Hills, ridges and slope shading belong to the landscape layer and are not drawn in
  a piece (the castle's mound and the mine's outcrop are the only raised ground).
- Roads between hexes are another layer. **A piece draws no road or track to the hex border.** It may keep a lane
  inside its yard or ring, ending at a **gate point**: a named spot at least 10 px inside the border on the south,
  east or west side (a `GATES = {"south": (x, y), ...}` table in the module). The map's road layer joins the gate
  points to its roads.
- Pass the family's ground to `kit.sheet(..., ground=..., wild=True)` so the sheet shows the piece on its own
  terrain, in its wild land.

**The coast: the map draws the shore** (the owner's answer 2).

- The map owns the coastline. A piece **never draws sea, sand strip or foam on the map**, and it never decides
  where the sea is. The map tells it: `kit.take_apart(draw, level, season, hex=..., sea=..., shore=...)`.
  - `sea`: the side the sea is on: `"E"`, `"SE"`, `"SW"`, `"W"`, `"NW"`, `"NE"` (the six neighbours of a pointy-top
    hex), `"S"` or `"N"` (both lower or both upper neighbours), several sides as a tuple (`("E", "SE")`), or an
    angle in degrees on screen.
  - `shore`: the map's shore line through the hex, as points in piece px. Without it the kit takes a straight,
    slightly wavy shore on the given side.
- A coast family calls `shore = p.coast(y0, ...)` once and lays out everything at the water's edge in **shore
  coordinates**: `shore.pt(u, v)` is the point `u` px along the shore from its middle and `v` px out to sea (`v < 0`
  is inland). Give that point to any kit call: `p.jetty(shore.pt(12, -1), shore.pt(12, 15))`,
  `p.house(*shore.pt(-6, -5), ...)`, `p.boat(*shore.pt(20, 9))`. The layout tables hold `(u, v)`, not `(x, y)`.
  `fishing()` in `tools/worldmap/pieces/contract.py` is the pattern to copy; `kit_contract.png` row 2 shows it on
  six sea sides.
- Standing things stay upright and lit from the upper left on every side; only their places turn with the shore.
  Pans, quays and other flat shapes are drawn as polygons from `shore.pt` corners, so they turn with it
  (`shore.rect(u, v, w, h)` gives a true rectangle at the shore; `shore.at(u, v, du, dv)` a point on straight axes).
- **Tall things and the sea behind the land.** A sail or a lighthouse stands upright, so with the sea in the north
  (or at the upper end of an east or west shore) it leaves the hex at the top where it fits with the sea in front.
  Never turn the layout round to dodge this (it cancels the mirror). Ask the kit: `shore.fits(u, v, tall, wide)`;
  `shore.fit(u, v, tall, wide)` slides a ship or boat back towards the shore until it fits (or returns `None`:
  leave it out); `shore.first(spots, tall, wide)` picks the first of several spots for a landmark (the lighthouse:
  the first mole's bend, the second mole's bend, the moles' roots, the land). A coast piece must print no
  `PIECE PROBLEM` on any of the eight sides, plain and mirrored.
- With the sea in front (the sheets' default: no `sea` given) `shore.pt(u, v)` is `(u, shore(u) + v)`, so a layout
  written for the south side moves over by subtracting the old shore y.
- `shore.land(x, y)` says if a point is on land; `shore.depth` is the land behind the shore at its middle in px. Each
  coast module lists the land depth its levels use (`NEED = {1: px, 2: px, 3: px}`, at most 46 px); the map gives a
  hex with less land a lower level or no coast piece. `shore.front`
  is True when the sea lies in the south half: only then do boats stand in front of the buildings.
- On the sheets the kit draws a stand-in sea so the piece can be judged. Show the default (sea in front) on the
  family sheet, write `<family>_sides.png` (S, E, NW, plain and mirrored) and check all eight sides in your scratch
  folder before you report. On a slanted shore a strict grid (salt's back row) may come up to 3 px into the margin
  at one corner; that is accepted.
- **The add-on is anchored at the shore, not at the hex centre** (a seaside port). A port's hex often has only a strip of water. The
  map puts the add-on's canvas so that the shore lies where the harbour expects it (`COAST["y0"]` px out from the
  middle); the basin then reaches into the sea hex next door, which is free.
- A piece that is not a coast family (a town, a wheat hex on the coast) does nothing: the map clips its ground
  detail at the shore and leaves out any standing thing whose foot would be in the water.
- **Ports.** A town with a harbour is the settlement piece in the middle of the hex, as always, plus the harbour
  family's add-on at the hex's own shore (section 8). They are two calls; the map leaves out add-on things that
  would stand on land inside the town's footprint.

**Two port modes** (the owner's answer, round 3: "some to carve a port to the tile, and some will need just to add
a port to the seaside"). Sheet: `ports.png`; in the map: Genoa carved, the others seaside.

| | **Carved** | **Seaside** |
|---|---|---|
| What the map does | Cuts a **bay** into the port's own hex, in front of the town | Nothing: the shore stays as it is |
| Where the harbour is | In the bay, **wholly inside the port's hex** | Along the shore; its basin may reach into the sea hex next door |
| The add-on's canvas | The bay's back lies where the harbour expects its shore; the canvas moves at most a few px | Anchored at the shore (above) |
| The town piece | Clipped at the bay like at any shore: plots and houses in the water are left out | Unchanged |

- **Which port is which: from the map data, once, never in play.** A port is **carved** when the place data marks
  it as a great port: on the Europe map a hand-set `harbour: "bay"` flag for the great natural harbours; where the
  flag is missing (and on random worlds), a place that **starts** as a city (the highest rank) and is a sea port.
  Every other port is **seaside**: fishing villages, small and middle ports, a city's outport on an open shore,
  and any harbour built during a game. A seaside port that grows into a city in play keeps its shore: the coast
  never changes during a game.
- Carving also needs room. No bay when the hex already has the water (the shore lies within 20 px of the hex
  centre), or when the bay would leave less than 60% of the hex as land; the port is then seaside.
- **In this map:** Genoa (a city and a sea port) is carved. Savona and Nice (towns) and Chiavari (a village) are
  seaside. Pisa is a city, but the data do not have it as a sea port (it stands on the Arno): its harbour is an
  outport on the open shore, seaside.
- **The bay's shape** is the kit's: `kit.carve(sea, shore, (u0, width, depth))` gives the carved shore, and the map
  turns to sea every point of the port's hex for which `.land(x, y)` is False.
  - Width `kit.BAY_WIDTH` = 72 px horn to horn, the same for every carved port. The back is straight over the
    middle 70% (50 px) and rises in a rounded shoulder to each horn (`kit.bay_profile`): a basin, not a notch.
  - The back lies `kit.BAY_BACK` = 13 px out from the hex centre (the harbour's own `COAST["y0"]`); in front of a
    walled town 16 px and of a city 18 px, so the wall stays dry.
  - **Limits.** The shore moves at most `kit.BAY_REACH` = 19 px (5 km) inland; the bay never leaves the port's
    hex; its horns stay inside the hex as headlands. (The style frame's small coves move a shore at most 3.5 km;
    a basin for a level 3 harbour needs more: Genoa's is 13 px, 4.2 km. The limit is an open question, section 12.)
  - A bay belongs to the hex, not to the harbour's level: it is there from the first day, and a fishing jetty sits
    in it as well as a mole harbour.
- **The piece in a bay.** The map hands the piece the carved shore line and `bay=(u0, width, depth)`
  (`kit.take_apart(..., bay=)`, `kit.Piece(bay=)`). `shore.pt(u, v)` then measures from the bay's own shore, so
  what lies along the shore (the quay, the slip) follows the back of the bay by itself. `shore.bay` (None on an
  open shore) gives the rest: `bay.u0`, `bay.west`, `bay.east` (the horns), `bay.pt(u, v)` (v px out from the
  **mouth line**, the straight line from horn to horn: moles are laid along it), `bay.room(u)` (px of water from
  the shore to the mouth line) and `bay.uv(u, v)` (the same point in shore coordinates, for `shore.fits`).
  A carved harbour keeps every work and every boat inside the bay or at most 6 px beyond the mouth line.
- On the sheets `kit.Piece(bay=...)` (or `kit.with_wild(..., bay=)`) carves the stand-in shore, so a module can
  be judged in a bay on every sea side.

## 11. The reviewer's checklist

Tick every line for every family. One "no" sends the sheet back.

**Kit and canvas**
- [ ] One module, `draw(level, season, variant=0, mirror=False)` returns a 112x112 surface, drawn only with the kit
      (no private calls, no `if mirror:`).
- [ ] The run prints no `PIECE PROBLEM` line.
- [ ] One seed and one `ground` for the whole family.
- [ ] No colour outside the kit's tokens, or each new one is a named token and listed in the report.

**Camera, light, ink**
- [ ] Ground things lie flat; standing things are upright and seen from the front.
- [ ] Lit left, shaded right, on every standing shape; soft shadows to the lower right only.
- [ ] Ink is thin and dark brown, never black, never thicker than 1 px.
- [ ] Nothing tall stands in front of a landmark.

**Levels, wild land and footprint**
- [ ] `draw(0, season)` is `kit.wild(...)` with the family's ground and seed, and nothing else.
- [ ] Levels 1 and up draw no wild scatter (no wild trees, bushes, scrub patches, terrain tufts or stones); the sheet
      is made with `wild=True`.
- [ ] On the sheet no wild tree stands on the work or in front of a building, and the work does not sit in a bald
      hex: the wild land comes up to the footprint. In a wood the piece has made the clearing it needs.
- [ ] Level 1 is told from the wild land at a glance, also at 50%.
- [ ] Each level keeps everything of the level below in the same place (flip between two levels to check).
- [ ] Coverage, height and density all grow with the level; the footprint's share of the margin hex is in the
      bands of section 6 (15-30 / 35-60 / 60-85%).
- [ ] Exactly one new landmark per level, as in the family table.
- [ ] Each level is told apart at a glance at 100%.

**Seasons**
- [ ] Flip between the four seasons of one level: nothing moves, only colours and the listed details change.
- [ ] Spring, summer, autumn and winter are told apart at a glance, also at 50%.
- [ ] Winter: the pattern and the landmark still read on snow; walls, doors, hulls and the sea have no snow.
- [ ] Still water is frozen in winter; the sea is not.
- [ ] **The three winters** (`kit.with_wild(draw, level, "winter", climate=...)` for snow, frost and mild): the
      layout is the same in all three; in the mild winter nothing is white or frozen and the piece is still told
      from autumn (bare trees, bare soil, laid-up boats); snow hangs on `p.winter`, ice on `p.frozen`.
- [ ] Smoke only in autumn and winter (except the listed chimneys). At most three activity details.
- [ ] Nothing from the "what not to add" list.

**Mirror and second layout**
- [ ] `<family>_variants.png` exists (`kit.variant_sheet`). In the mirrored columns every building is lit on the
      left and shaded on the right, shadows fall to the lower right, smoke sits on its chimney, nothing collides.
- [ ] Layout 1 has the same landmarks, counts, coverage and signature as layout 0, with the yard at least 14 px
      from layout 0's yard and from its mirror image.
- [ ] At 50% layout 1 is told from layout 0 and from layout 0 mirrored.
- [ ] The block of 5 x 4 hexes shows no two equal neighbours and reads as countryside, not wallpaper.

**Coast families (salt, harbour)**
- [ ] The piece draws no sea of its own: one `p.coast()` call, everything at the water's edge placed with
      `shore.pt(u, v)`, the tables in shore coordinates.
- [ ] Checked on all eight sea sides, plain and mirrored (`<family>_sides.png` shows S, E, NW): no `PIECE
      PROBLEM`, nothing stands in the water that should not, the works still meet the shore, the mirrored piece
      is not the same picture as the plain one, the top landmark is there on every side.
- [ ] Harbour: `addon=True` draws only the works at the water's edge.
- [ ] **In a bay** (`bay=(0, kit.BAY_WIDTH, depth)` for depth 8, 13 and 19, on all eight sides): no `PIECE
      PROBLEM`; the harbour is a closed basin inside the bay, nothing more than 6 px beyond the mouth line; salt's
      jetty and boat stay inside the lagoon.

**Readability and fit**
- [ ] At 50% the family is recognised by its signature and the top level by its landmark.
- [ ] The piece cannot be mistaken for another family (compare the sheets side by side).
- [ ] In the "side by side" row the hex borders do not show as hard lines on matching terrain.
- [ ] No worked ground or activity detail within 10 px of the hex border (measure the corners of every block,
      in both layouts); no road, track, canal or stream runs to the border; every gate point is 10 px inside.
- [ ] Scrub, trodden ground and tracks are overlays (`scrub`, `blob(alpha=)`, `road(track=True)`), not mixed colours.
- [ ] Goods pieces have at most 3 houses and no banner.
- [ ] No name plate and no space kept for one.

## 12. The owner's decisions, and what is still open

**Decided on 2026-11-15** (the three questions of `REVIEW.md`):

| | Question | The owner's answer | What it means here |
|---|---|---|---|
| 1 | Where does a town's name plate go? | **"No plates for now."** | The normal map shows no town name plates. Pieces keep no plate strip; the town stays where it is (sections 8, 11) |
| 2 | Coasts and ports | **"Map draws shore."** | The map owns the coastline; coast pieces are told the sea side and build at that shore; in a town's hex the harbour is an add-on at its own shore (sections 8, 10) |
| 3 | Wild land and variety | **"Map + 2nd layout."** | The map draws woods and scrub and thins them under the piece's footprint; level 0 is no piece; every family gets a mirror and a second layout chosen by the hex, wheat, grazing, timber and vineyard first (section 6) |

**Decided in round 3** (the same day):

| | Question | The owner's answer | What it means here |
|---|---|---|---|
| 4 | Ports: the harbour did not fit the port's own strip of water | **"Some to carve a port to the tile, and some will need just to add a port to the seaside."** | Two port modes: carved (the map cuts a bay into the port's hex; great ports) and seaside (the add-on at the shore as it is). Section 10 |
| 5 | Winter snow everywhere? | **"Not all of the map gets snowed. For example south Italy doesn't get that much snow. Might need some in between tiles?"** | Three winters by climate: snow, frost (the in-between) and mild. A rule from latitude, height and distance to the sea. Section 7 |

**Still open** (none blocks the fix tasks):

1. **How far may a carved bay move the coast?** As drawn: at most 19 px (5 km); Genoa's bay is 13 px (4.2 km),
   and with the style frame's own cove the coast there lies 6.8 km from the frame's first line. The frame's cove
   rule is 3.5 km. Options: (a) 5 km for carved ports only (recommended: it is what puts a level 3 harbour inside
   its hex; there are few of them); (b) keep 3.5 km: the moles and outer berths then reach about 6 px into the sea
   hex next door.
2. **The winter rule on the whole map.** The three steps and the rule are in (section 7); the numbers are tuned
   on this region only. Before the full map is built: check a list of known places (the rule puts London on the
   edge of snow and Venice in the mild winter) and decide whether the map's ground follows the cold index point
   by point (recommended, as in the test) or hex by hex.
3. **Mild-winter woods.** As drawn: broadleaves are bare in every winter, also on the Mediterranean coast.
   Option: an evergreen broadleaf (holm oak, dull dark green) for the mild zone's woods, in the map's wild land.
4. **Wheat landmarks.** As drawn: barn at level 2, windmill at level 3 (the windmill is the strongest silhouette, so
   it marks the top). The growing-map plan has "a mill" at stage 2; option: a watermill at level 2 and the windmill
   kept for level 3.
5. **A hex with a settlement and a good.** Answered for ports (answer 2: the harbour is an add-on). For the other
   goods the pieces still assume one piece per hex. Options: (a) one piece per hex, the settlement wins
   (recommended for now); (b) half-size goods pieces round a settlement, to be designed later.
6. **Banner colour.** Castles take the owner's colour as a parameter; the sheet shows red.
7. **Where do town names show, if not on plates?** "No plates for now" leaves the normal map without town names.
   Options: (a) nothing at this zoom, names on hover and in the panel (recommended for now: it is what was
   decided); (b) small plain text under the town, no plate, to be tried when the UI round comes.
8. **The timber piece's water.** Streams are the map's, so the sawmill gets a short mill race with a pond at each
   end, inside the hex (as wheat's canal). Option: no water, a horse-driven saw and the raft dropped. Recommended:
   the mill race (it keeps the water wheel and the raft, the family's landmarks).
