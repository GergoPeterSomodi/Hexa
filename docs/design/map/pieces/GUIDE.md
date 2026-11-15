# Normal-map pieces: the rule book

Art director, 2026-11-15. **Status: for the owner to approve. Nothing in the game is changed.**

A **piece** is the picture of one hex's improvement at one level in one season, at the normal map zoom (the style
frame's close zoom: hex radius 60 px, one hex = one district). This guide and the drawing kit
(`tools/worldmap/pieces/kit.py`) are everything an artist needs to draw a family of pieces. Two families are already
drawn to these rules and set the bar: `wheat.png` and `settlements.png` in this folder (code: `wheat.py`,
`settlements.py` next to the kit). **When this guide and a reference sheet seem to disagree, copy the reference sheet
and report the gap.**

The look itself (camera, light, palette, ink) is the style frame's: `../style-frame/README.md`. The stages follow the
growing-map plan (`../06-growing-map.md`, sections 2 and 5).

Contents: 1 canvas, 2 camera, 3 light and ink, 4 palette, 5 sizes, 6 how a level reads, 7 seasons, 8 the family
tables, 9 readability, 10 terrain fit, 11 the reviewer's checklist, 12 for the owner to decide.

---

## 1. Canvas

| Thing | Value |
|---|---|
| Hex | Pointy-top, radius 60 px: **104 px wide, 102 px tall** on screen (the height is already squashed to 85%) |
| Canvas | 112 x 112 px, the hex centred, alpha outside |
| Drawing | At 2x, then smooth-scaled to 1x. The kit does this; you always work in 100% pixels |
| Coordinates | Origin at the hex centre, x to the right, y down. The hex spans x -52 to +52 and y -51 to +51 |
| Ground base | The season colour of the terrain, with soft mottling, fading to transparent over the last **5 px** at the hex border so it blends with the neighbours. **The base is for the sheets only: on the map it is not drawn.** The map paints the ground and takes the piece apart into ground detail, shadows and standing things (`kit.take_apart`) |
| Ground work | Fields, plots, pans, yards, canals, ponds and activity details stay **10 px clear of the hex border** (the map's rivers and roads run along the borders). Soft scrub patches and tufts may come closer |
| Standing things | Must lie wholly inside the hex, **3 px clear of the border**. The kit checks this and prints `PIECE PROBLEM` if not |
| Safe area | Put the main picture inside x -42 to +42, y -38 to +38. Remember the corners are cut: at y = +/-38 only x -18 to +18 is inside |

- Start every picture with `kit.Piece(season, ground=..., seed=N)`. Use **one seed per family**, the same for every
  level and season, so the ground mottling never changes.
- Ground-plane shapes near the border are faded by the kit; do not try to stop them exactly at the border.
- **A change of the ground itself is an overlay, not a colour.** Scrub, rough or trodden ground, cleared ground and
  tracks are laid half-transparent over whatever ground the map has: use `p.scrub(...)`, `p.blob(..., alpha=)` and
  `p.road(..., track=True)`. Never mix a colour with the base ground colour yourself; the map's ground may differ.
- Never draw outside the kit (no drawing on the returned surface, no own scaling).

## 2. Camera

One slight 3/4 view, the same for every piece.

- **Lying on the ground** (drawn flat, north-south at 85%): fields, plots, pans, yards, roads, tracks, canals, ponds,
  the coast, jetties, quays, moles, fences, hedges, terrace walls, the footprint of a ring wall. Use the kit's
  ground calls (`field`, `rows`, `patch`, `road`, `water`, `pond`, `coast`, `jetty`, `fence`, `hedge`, `terrace`).
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
| Trading ship / fishing boat | 12 long, 13 tall (size 1.0) / size 0.55 | `p.boat(x, y, sc)` |
| Person | 1.2 wide, 3.4 tall | `p.person(x, y, col)` |
| Sheep / cow / horse | 3x2 / 4.5x2.5 / 4.5x4 | `p.animal(x, y, kind)` |
| Haystack, heap | 4.6x4.6; heaps 5-12 wide, 4-7 tall | `p.haystack`, `p.heap` |
| Road / track | 2 px with an edge / 1 px, no edge | `p.road(pts, w, track)` |
| Canal, stream | 1.4 / 3 px | `p.water(pts, w)` |

Ring walls are ellipses with ry = 0.55 x rx (the tilt). Keep at least 5.5 px between house feet sideways and 3.4 px
front to back, or roofs merge into one red mass.

## 6. How a level reads

A level is the **character of the whole district**, not one building. Four things grow together:

1. **Coverage.** The share of the hex that is worked: level 0 = 0%, level 1 = about 20%, level 2 = about 45%,
   level 3 = about 70% (settlements and castles: the footprint width grows about 12 px per level).
2. **Silhouette.** The tallest thing gets taller: level 1 up to 9 px, level 2 up to 13 px, level 3 up to 20 px.
3. **Density.** More of the same unit: blocks, rows, pans, heaps, houses, animals.
4. **One landmark per level.** Each level adds exactly one new landmark that no lower level has. It stands at or
   near the centre with a clear gap in front, and it is the thing a player learns to look for.

**The additive rule (what must stay the same).** Level N is level N-1 plus more. So:

- The **layout is a fixed table** in the module: every block, building and tree has one position, and a `from level`
  (and for wild things a `gone from level`). Nothing moves, turns or changes size between levels.
- The **yard** (the home building and its place in the hex) is the same at every level.
- The **terrain is the same at every level**: the same `ground`, the same seed, the same coast or stream line.
- **Wild things thin out**: level 0 has the terrain's own scatter (trees, bushes, tufts, stones); each level removes
  the ones where the new work lies, and keeps the rest where they were. Woods thin from the front (south) first;
  the back (north) row of trees stays to the last level.
- A building may be **upgraded in place** (thatch to tile, hut to house on the same foot), never moved.
- **Level 0 is not empty.** It is the wild version of the terrain, with darker patches where the work will come.

**The season never changes the layout.** Positions never depend on the season; only colours and the listed season
details do. Do not seed any random number with the season.

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

**Snow rules.**
- Snow is `SNOW` on lit and flat tops and `SNOW_D` on shaded sides. It never covers a wall face, a door, a tower
  shaft, a hull or the sea.
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

"Landmark" is the one new thing of that level. "Count" numbers are targets, not ranges to explore.

### Wheat fields (reference: `wheat.png`). Ground: `farm`

| Level | What is drawn | Landmark |
|---|---|---|
| 0 | Rough grass: 6 darker scrub patches, 6 round trees, 5 bushes, stones, tufts | None |
| 1 | A thatched farmhouse with a fruit tree, 1 block of 6 strips, a track | The farmhouse |
| 2 | 3 blocks with hedges on two sides, the house re-roofed in tile, a second fruit tree, a haystack | The thatched barn |
| 3 | 5 blocks, a canal with 3 poplars that **ends in a small pond at each end, inside the hex** (it never runs to the border), a second house, a second haystack | The windmill |

Seasons: spring green shoots with one bare strip in four; summer gold, the newest block half cut, with sheaves and
1-2 reapers; autumn ploughed earth and stubble with furrow lines, a plough team on the first block, smoke; winter
snow strips with furrows. Haystacks stand from summer to winter, not in spring.

### Vineyard and winery. Ground: `grass` (sunny hills)

| Level | What is drawn | Landmark |
|---|---|---|
| 0 | Scrub: 8 bushes, 2 round trees, stones, tufts | None |
| 1 | 2 small blocks of young vines (dashed rows), a thatched hut | The hut |
| 2 | 4 blocks of full rows at two different angles, the hut becomes a tiled house | The press house: a wide tiled building with a big dark door and 2 round vats beside it |
| 3 | 6 blocks, the upper two with 2-3 terrace walls; a track | The wine estate: a tall house with a small cone-roofed tower and 2 cypresses (`poplar`) |

Seasons: spring light green rows; summer dark green rows; autumn **red rows**, 2 pickers and a row of 3 baskets on
the newest block, smoke; winter bare brown stakes on snow soil. The rows are the signature: never fewer than 5 per
block.

### Olives. Ground: `grass` (warm coast hills)

| Level | What is drawn | Landmark |
|---|---|---|
| 0 | Scrub and pine: 4 conifers, 6 bushes, stones | None |
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
| 0 | Rough grazing: 6 bushes, 2 round trees, stones, many tufts | None |
| 1 | 5 animals loose in one group, a shepherd, a thatched hut | The hut |
| 2 | 1 fenced meadow (a `meadow` field of one colour inside a `fence`) with 8 animals, a haystack | The byre: a long low thatched barn (horses: a stable with a fenced yard) |
| 3 | 3 fenced meadows, 13 animals, 2 haystacks, a track | The market hall: a wide tiled building on timber posts (sheep: wool hall; cattle: dairy; horses: stud house) |

Seasons: spring 2-3 smaller young animals beside the grown ones; summer all animals out, haymaking (extra
haystack); autumn all out, haystacks; winter **only 3 animals**, close to the byre, smoke, snow-capped haystacks.
Animals always stand inside the fences from level 2.

### Salt pans. Ground: `sand`, with `p.coast()` in front

| Level | What is drawn | Landmark |
|---|---|---|
| 0 | A bare shore: sand, 2 shallow pools, reeds (tufts), stones | None |
| 1 | 3 square pans with low dykes, 1 salt heap, a thatched hut | The hut |
| 2 | 8 pans in 2 rows, a feeder channel from the sea, 3 heaps in a row | A sluice gate on the channel (a small timber frame) |
| 3 | 14 pans in 3 rows, 5 heaps in a row, a short jetty with 1 boat | The salt store: a long warehouse |

Pans are `p.patch` squares of 9-11 px with a `STONE_D` edge, laid as a strict grid. Seasons: spring pans filled,
blue-grey (mix of `shallow` and `sand`); summer pans white and pale pink as they dry (`SALT`), the heaps at full
size, 2 rakers; autumn grey pans, heaps covered (thatch colour); winter pans frozen (`ICE`) with snow edges, heaps
covered with a snow cap, nobody out.

### Mines. Ground: `rock` (add `p.scree()` and stones: rock is never flat)

| Level | What is drawn | Landmark |
|---|---|---|
| 0 | Bare rock: scree, 4 boulders, one low rock outcrop at the back (it stays at every level), 2 conifers | None |
| 1 | A hut, 1 small spoil heap, a track | The adit: a dark arched mouth in the outcrop with a timber frame |
| 2 | 2 huts, 2 spoil heaps, a short stream | The headframe over a shaft with a water wheel |
| 3 | A row of 3 miners' houses, 3 spoil heaps, an ore pile | The smelter: a stone building with a tall chimney |

Seasons change little here, on purpose: ground palette, snow caps on roofs and heaps, the stream frozen. The
smelter chimney smokes **in every season** (the one exception to the smoke rule). No people.

### Timber and logging. Ground: `wood`

| Level | What is drawn | Landmark |
|---|---|---|
| 0 | Wild wood: about 24 trees (2 conifers to 1 round), a stream across the front | None |
| 1 | About 19 trees; a clearing at the front centre with 5 stumps, a hut | The charcoal mound: a dark heap with smoke |
| 2 | About 15 trees; the clearing wider, 2 log piles, a track | The sawmill on the stream: a timber house with a water wheel |
| 3 | About 11 trees, all in the back half; 4 log piles, a long shed | The log raft on the stream |

Trees are removed from the front; the back row never changes. Seasons: broadleaves follow the season table; winter
is felling time: one more log pile, the stream frozen and **no raft**; the charcoal mound smokes in every season.

### Fishing and harbours. Ground: `grass`, with `p.coast()` in front

| Level | What is drawn | Landmark |
|---|---|---|
| 0 | A beach: sand, 1 small boat drawn up on the sand, tufts, 2 bushes | None |
| 1 | 2 thatched huts, 2 fishing boats, a net rack (2 posts and a line) | The timber jetty |
| 2 | A stone quay along the shore, 3 fishing boats, 1 ship | The warehouses: 2 long tiled buildings on the quay |
| 3 | Two stone moles round a basin, 3 warehouses, 2 ships, 3 boats, a hull on a slip (the shipyard) | The lighthouse on the west mole |

Seasons: spring and summer the boats are out at sea with sails; autumn half of them are at the jetty; winter all
boats are laid up at the jetty or quay with bare masts (`sail=False`), snow on roofs and moles, the sea darker.
The lighthouse lamp is yellow in every season. The sea is always on the south side of the hex.

### Settlements (reference: `settlements.png`). Ground: `grass`. Levels 1-5

| Level | Name | What is drawn | Landmark |
|---|---|---|---|
| 1 | Hamlet | 3 thatched houses, 2 garden plots, a track, the trees around | The well |
| 2 | Village | 7 houses (half thatch), 4 garden plots, 2 tracks | The chapel |
| 3 | Town | 11 tiled houses, 4 plots outside, 2 roads | The palisade ring with a gate, and the church |
| 4 | Walled town | 16 houses (a few taller), 3 roads | The stone wall with 2 towers and a gate tower |
| 5 | City | 24 houses, 4 suburb houses outside the wall | The cathedral dome; 4 wall towers and 2 at the back |

The church and the green in front of it are at the same spot in every level. The strip from y = +26 down is kept
free for the name plate. Seasons: garden plots follow the season, blossom on fruit trees in spring, 1-2 people on
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
- **At 50%** (the right-hand grid of the sheet): the family must still be recognised by its signature, and level 0,
  the middle levels and the top level must still differ. Details may vanish; the landmark of the top level may not.
- **Winter** is the hardest column. Check that the worked pattern and every landmark still read on snow.
- **Clutter limits**: no more than 3 houses in a goods piece; no more than 3 activity details; no two standing things
  with feet closer than 4 px unless they are meant as one cluster; keep 25% of a level-3 hex as plain ground.
- **Look-alikes**: put your sheet next to the two reference sheets and to any finished family. If a piece could be
  taken for another family or another level at 50%, change it and say so in your report.

## 10. Terrain fit

| Family | Sits on | `ground=` | Notes |
|---|---|---|---|
| Wheat | Plain, lowland | `farm` | |
| Vineyard | Sunny hills | `grass` | |
| Olives | Warm coast hills | `grass` | Pale `olive_soil` patches under the trees |
| Grazing | Highland, poor hills | `grass` | |
| Salt | Low sandy coast | `sand` + `coast()` | Sea to the south |
| Mines | Hills and mountains with ore | `rock` | Scree and stones on every level |
| Timber | Woods | `wood` | |
| Harbour | Sheltered coast | `grass` + `coast()` | Sea to the south |
| Settlements, castles | Any land but high peaks | `grass` | |

- The base ground is the **terrain**, never the improvement: it does not change with the level.
- Pieces are flat-land pictures. Hills, ridges and slope shading belong to the landscape layer and are not drawn in
  a piece (the castle's mound and the mine's outcrop are the only raised ground).
- Roads between hexes are another layer. **A piece draws no road or track to the hex border.** It may keep a lane
  inside its yard or ring, ending at a **gate point**: a named spot at least 10 px inside the border on the south,
  east or west side (a `GATES = {"south": (x, y), ...}` table in the module). The map's road layer joins the gate
  points to its roads.
- Pass the family's ground to `kit.sheet(..., ground=...)` so the sheet shows the piece on its own terrain.

## 11. The reviewer's checklist

Tick every line for every family. One "no" sends the sheet back.

**Kit and canvas**
- [ ] One module, `draw(level, season)` returns a 112x112 surface, drawn only with the kit.
- [ ] The run prints no `PIECE PROBLEM` line.
- [ ] One seed and one `ground` for the whole family.
- [ ] No colour outside the kit's tokens, or each new one is a named token and listed in the report.

**Camera, light, ink**
- [ ] Ground things lie flat; standing things are upright and seen from the front.
- [ ] Lit left, shaded right, on every standing shape; soft shadows to the lower right only.
- [ ] Ink is thin and dark brown, never black, never thicker than 1 px.
- [ ] Nothing tall stands in front of a landmark.

**Levels**
- [ ] Level 0 is wild, not empty.
- [ ] Each level keeps everything of the level below in the same place (flip between two levels to check).
- [ ] Coverage, height and density all grow with the level.
- [ ] Exactly one new landmark per level, as in the family table.
- [ ] Each level is told apart at a glance at 100%.

**Seasons**
- [ ] Flip between the four seasons of one level: nothing moves, only colours and the listed details change.
- [ ] Spring, summer, autumn and winter are told apart at a glance, also at 50%.
- [ ] Winter: the pattern and the landmark still read on snow; walls, doors, hulls and the sea have no snow.
- [ ] Still water is frozen in winter; the sea is not.
- [ ] Smoke only in autumn and winter (except the listed chimneys). At most three activity details.
- [ ] Nothing from the "what not to add" list.

**Readability and fit**
- [ ] At 50% the family is recognised by its signature and the top level by its landmark.
- [ ] The piece cannot be mistaken for another family (compare the sheets side by side).
- [ ] In the "side by side" row the hex borders do not show as hard lines on matching terrain.
- [ ] No worked ground or activity detail within 10 px of the hex border; no road or track runs to the border.
- [ ] Scrub, trodden ground and tracks are overlays (`scrub`, `blob(alpha=)`, `road(track=True)`), not mixed colours.
- [ ] Goods pieces have at most 3 houses and no banner.
- [ ] Settlements keep the plate strip (y from +26) free.

## 12. For the owner to decide

1. **Winter snow.** As drawn: full snow on every hex in winter (recommended for a clear season signal). Option:
   full snow only in the north and on high ground, and a "frost" winter (grey-green ground, bare trees, no snow) for
   the Mediterranean families (olives, salt, vineyards). That is one more palette column, no new drawing.
2. **Wheat landmarks.** As drawn: barn at level 2, windmill at level 3 (the windmill is the strongest silhouette, so
   it marks the top). The growing-map plan has "a mill" at stage 2; option: a watermill at level 2 and the windmill
   kept for level 3.
3. **A hex with a settlement and a good.** These pieces assume one piece per hex. Options: (a) one piece per hex,
   the settlement wins (recommended for now); (b) half-size goods pieces round a settlement, to be designed later.
4. **Banner colour.** Castles take the owner's colour as a parameter; the sheet shows red.
