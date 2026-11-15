# Normal-map pieces: the rule book

Art director, 2026-11-15. **Status: the owner answered the three open questions on 2026-11-15 (section 12); this
guide is rewritten to those answers and was made sharper after the second review (coverage, the mirror axis, boat
sizes, coast pieces on every sea side). Round 3 (the same day) adds the owner's two further answers: **two port
modes** (section 10) and **winter by climate** (section 7). Round 4 (the same day) records the owner's pick from
the Python-art catalogue (`../python_art/catalogue.md`, the top 10) and his two port answers, and writes the tables
for it in one pass: six new goods families, the four ores, the landmark cities, the Sites family and the third
layouts (sections 4, 6, 8, 10, 12). Nothing in the game is changed.**

A **piece** is the picture of one hex's improvement at one level in one season, at the normal map zoom (the style
frame's close zoom: hex radius 60 px, one hex = one district). This guide and the drawing kit
(`tools/worldmap/pieces/kit.py`) are everything an artist needs to draw a family of pieces. Two families are the
reference: `wheat.png` and `settlements.png` in this folder (code: `wheat.py`, `settlements.py` next to the kit).
`kit_contract.png` shows the kit's side of the map contract (wild land, coast, footprint, mirror) on one page;
`kit_additions.png` the calls, crops and tokens added for the families of round 4.
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
| Repetition | The map picks by the hex | Every family has a mirrored version and a second layout; vineyard, grazing and castles a third (section 6) |
| Which ore, which landmark city, which site | **The map data** | A keyword or the variant: `ore=`, `landmark=`, the site's number (section 8) |

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

**Signature tokens of the round 4 families** (fixed; in the kit, so no two families can pick the same colour;
swatches on `kit_additions.png`). Each has one owner. A second user is named here or it is not allowed.

| Token | RGB | Owner |
|---|---|---|
| `MARBLE`, `MARBLE_D` | 240,236,226 / 200,196,188 | Quarry: cut blocks, columns. Also Venice's fronts and the Roman ruins |
| `PIT`, `PIT_D` | 212,202,180 / 164,152,132 | Quarry: ledge tops and cut faces |
| `DYE["blue" / "red" / "yellow" / "purple"]` | 58,98,172 / 192,54,60 / 234,192,62 / 128,72,152 | Dye works: vats and cloth. Nothing else on the map is many-coloured |
| `RET`, `RET_D` | 98,132,118 / 64,92,86 | Hemp: the retting pond |
| `BOLL` | 250,248,240 | Cotton: the bolls and the bales |
| `DOME_TILE`, `DOME_TILE_D` | 64,150,168 / 44,112,132 | Silk: the caravanserai's dome |
| `PELT`, `PELT_D` | 146,94,58 / 106,68,46 | Furs: the pelts |
| `ORES[ore]`: `spoil`, `spoil_d`, `ore`, `ore_d` | see the kit | Mines, by ore (section 8) |
| `GLOW` | 250,150,50 | Mines, iron: the furnace mouth |
| `VERDIGRIS`, `VERDIGRIS_D` | 96,160,140 / 66,122,110 | Mines, copper: the stained rock. Also the cap of Venice's campanile |
| `BRICK`, `BRICK_D` | 178,74,60 / 136,56,48 | Landmarks: Moscow, Granada |
| `LEAD`, `LEAD_D` | 118,140,168 / 88,108,136 | Landmarks: the domes of Constantinople and Venice |
| `GILT` | 228,188,84 | Landmarks: a gilded dome or finial, 2 px at most |
| `ONION[0..3]` | gold, green, blue, red | Landmarks: Moscow's onion domes |

**Light sources.** The map has two: the harbour's lighthouse lamp and the iron furnace's mouth (`GLOW`, a spot of
at most 2 x 2 px, iron level 3 only, the same in every season). They are the only exceptions to "no highlights";
no other family may add one.

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

**Crop colours** come from `kit.crop(name, season)`: `wheat`, `garden`, `meadow`, `vine_soil`, `vine`, `olive_soil`,
and for round 4 `hemp`, `hemp_row`, `cotton_soil`, `cotton`, `mulberry_soil` (all with their three winters).

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
| Quarry | A pale stepped rock face and white cut blocks: light, angular, no dark opening | The treadwheel crane; the columns |
| Dye works | Round vats in four strong colours, cloth on lines | The dye house |
| Hemp | Near-square blocks of the darkest green beside dull-green ponds | The ropewalk: the longest building on the map |
| Cotton | White dots in rows on a red-earth patch | The gin house |
| Silk | Single-file rows of low pollarded trees on pale strips, long sheds between | The caravanserai with a small turquoise dome |
| Furs | Brown pelts on frames in a small clearing, the wood left standing | The log post in an open square stockade |
| Sites | One old stone thing alone in the wild land, no fields, no work | The site itself |

Banners belong to castles only. Red tile roofs in a cluster of four or more belong to settlements only: goods
families have **at most three** houses, mostly thatch. A landmark city is a settlement: its monument takes the
church's place and adds no signature of its own to the list.

**Pairs that crowd each other, and what keeps them apart** (round 4; a reviewer checks each pair side by side at
50%):

| Pair | The rule |
|---|---|
| Hemp / spring wheat | Wheat owns long strips (3-4.5 px wide, 28-38 long, 4-6 to a block) and gold. A hemp block is near-square (14 x 12), has **at most two strips** and is never gold or light green: in spring it is **bare earth with dashed rows** (hemp is sown late), in summer the darkest green on the map. Every hemp level shows a pond. No hedges, canal, poplars, haystacks or mill in hemp; stooks are thin three-line tripods, never round stacks |
| Furs / timber | Timber owns stumps, log piles, the sawmill, the smoking mound and a clearing that grows to 65%. Furs has **none of these**, and its clearing stays small (coverage bands 10-20 / 20-35 / 35-50%): the wood is left standing. Furs is told by the pelt frames, always in front |
| Furs / castle 1 | The castle is a **round** ring on a mound with a stone tower and a banner. The fur post's stockade is **square, three-sided and open to the front**, on flat ground, timber only: no tower, no gate tower, no banner, nothing of stone |
| Gold / castle | **Gold has no fort.** The old tile's fortified mine is dropped: gold's top landmark is the strongroom, one small grey stone house with a slate roof, no ring, no tower, no banner. Gold is told by its long sluice and its pale gravel heaps |
| Quarry / mines | Mines own grey spoil cones, the dark adit, the headframe and smoke. The quarry has no opening, no cone heap and **never smokes**; its blocks are boxes, its rock pale |
| Dye works / salt | Salt's pans are square, in a strict grid, white to pale pink. Vats are round, in strong colours, at most nine |
| Cotton / vineyard | Vines: 6 small blocks at changing angles, thin dark rows **across** the short side, pale brown soil. Cotton: at most 5 big patches (22 x 16) of **red** earth, rows **along** the long side with white dots; no terraces |
| Silk / olives | Olives: round silver trees in a grid on ochre terraces with walls. Mulberries: green, flat-topped, on a pale stem, in **single lines** at least 9 px apart with sheds between; no walls |
| Silk's dome / the cathedral dome / Constantinople | The caravanserai's dome is 6 px wide, turquoise, on a courtyard wall. The cathedral's is `DOME` grey-green on a church. Constantinople's is `LEAD` grey-blue, 12 px wide, with minarets |
| Ruined castle (site) / castle 1 | The ruin has a broken, jagged top, a gap in its wall, no roof, no banner, no ring and no mound |
| Monastery (site) / village | The monastery is one joined block round a court, slate roofs, inside a low wall: no single houses, no red roofs |
| Spices / dyes | Not needed now (spices are batch 2). If they come: spices are pointed heaps in a row, dyes stay round vats |

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
| Dry-stone field wall | 1.2 px, grey, a dark foot | `p.drystone(pts, closed=)` |
| Round pen | Sheepfold: radius 5-7 (stone). Paddock: radius 11-17 (post and rail). A gate gap of 4 px | `p.ring(cx, cy, rx, kind="stone" / "fence", gate=)` |
| Contour row | 1.2 px, rows 4-5 px apart, as `rows` | `p.arc(cx, cy, rx, ry, a0, a1, dashed=)` |
| Mulberry | Crown 5.6 x 3.6 on a pale stem, about 6.5 tall; 5 px apart in a row | `p.tree(x, y, 1.0, "mulberry", i)` |

Ring walls are ellipses with ry = 0.55 x rx (the tilt). Keep at least 5.5 px between house feet sideways and 3.4 px
front to back, or roofs merge into one red mass.

## 6. How a level reads

A level is the **character of the whole district**, not one building. Four things grow together:

1. **Coverage.** The share of the hex that is worked: level 1 = about 20%, level 2 = about 45%, level 3 = about
   70% (settlements and castles: the footprint width grows about 12 px per level). **It is measured as the
   footprint's share of the margin hex** (the hex pulled in 10 px: the only ground a piece may work), in summer,
   layout 0. Bands that pass: level 1 15-30%, level 2 35-60%, level 3 60-85%. Of the whole hex that is about
   12-20%, 23-40% and 40-58%, so a full level 3 still leaves a quarter of the hex plain.
   Two families have bands of their own (section 8): **furs** 10-20 / 20-35 / 35-50% and **sites** 8-20% (one
   level).
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
- **A third layout** (`VARIANTS = 3`, `variant=2`; round 4: vineyard, grazing, castles) follows the same rules
  against **both** other layouts: same landmarks, counts, coverage and signature; its yard at least 14 px from the
  yards of layouts 0 and 1 and from their mirror images; told from all four at 50%. A third layout should differ
  in **kind of plan**, not only in place (curved rows where the others are straight, round pens where the others
  are square): that is what it is for. With three layouts `kit.pick` gives each of the grid's three classes its
  own layout, plain or mirrored by the hex, so no two neighbours show the same layout. The variants sheet gets two
  more columns by itself. `GATES` becomes a list of three dicts if the third layout ends elsewhere.
- **A keyword choice is not a layout.** `animal=`, `ore=`, `landmark=`, `flag=` and `addon=` come from the map data
  and keep the layout tables; the default of each keyword is today's picture, pixel for pixel. Where a choice
  needs tables of its own (gold) they are separate tables with the same number of layouts.

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

**The third layout: contour rows round the chateau** (`variant=2`; model: `wine4`, `wine5`). The six blocks are
six **sectors of one set of concentric rows**: 6 curved rows (`p.arc`), 4-5 px apart, round one centre near the
middle of the hex, the rings flattened to about 0.78 (a low knoll seen at the tilt), open at the back over about
100 degrees. No hill is drawn and nothing is shaded as a slope: the curve of the rows is the whole picture; a
faint trodden knoll (`p.blob`, alpha 0.25-0.3) may mark the middle.

| Level | What is drawn | Landmark |
|---|---|---|
| 1 | 2 sectors of young (dashed) rows at the front left, the thatched hut in the front gap between sectors | The hut |
| 2 | 4 sectors of full rows, the hut becomes a tiled house | The press house with its 2 vats, at one end of the opening at the back |
| 3 | 6 sectors; the two outermost bands of the back sectors stand on terrace walls (`p.terrace(face=2)` along the arc); a track from the middle to the gate through the front gap | The chateau **in the middle of the rings**: the estate house with its tower and 2 cypresses |

Same counts as the other layouts (6 blocks, at least 5 rows each, 2 terraced). Each sector's soil is a patch
between two `kit.ring_points` lines, with a 2 px gap of ground between sectors. The seasons are the vineyard's.
The hut stands at least 14 px from (-14, 8), (12, -18) and their mirror images.

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

**The third layout: upland pens** (`variant=2`; models: `wool2`-`wool4`, `horses2`-`horses5`). The same table, the
same counts (5 / 8 / 13 animals, 0 / 1 / 2 haystacks, hut, byre, hall), the meadows enclosed in another way, by
the animal:

| Animal | The meadows of levels 2 and 3 | The round thing |
|---|---|---|
| Sheep | **Odd-shaped pastures inside dry-stone walls** (`p.drystone`): 4 or 5 corners each, no two alike, sharing walls where they touch; the meadow colour inside | A **round stone fold** (`p.ring(kind="stone")`, radius 6) by the byre, from level 2, with 2 of the 8 sheep in it |
| Cattle | The same walled pastures as the sheep | The same ring as a cattle pound, empty in winter |
| Horses | **Round paddocks** (`p.ring`, post and rail): one of radius 16 at level 2 with a trodden middle (`p.blob`, alpha 0.3); two more of radius 11 at level 3. Three rings, no square meadow | The paddocks themselves |

No stripes, tents or bunting at the stud (the old tile's tents are dropped), horses stand, the walls and rings stay
10 px inside the border. The hut stands at least 14 px from (-32, -17), (34, -12) and their mirror images.
Winter: walls and rings carry a snow line; the three animals left out stand in the fold or the paddock by the byre.

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

**The four ores**: `mines.draw(level, season, variant=0, mirror=False, ore=None)`. `ore=None` is the table above
and today's picture, pixel for pixel. An ore keeps the layout, the outcrop, the adit, the headframe, the race and
the houses, and changes three things: the colour of the spoil heaps and the ore pile (`kit.ORES[ore]`), one
detail, and the **level 3 landmark, which stands on the smelter's foot**. One sheet per ore
(`mines_iron.png` ...).

| `ore=` | Spoil and ore | Detail | Level 3 landmark (in the smelter's place) | Smoke |
|---|---|---|---|---|
| `None` | `SPOIL`, the module's `ORE` | - | The smelter with its chimney | The chimney, always |
| `"iron"` | Brown-grey spoil, rust-red ore | From level 2 a second, small rust ore pile by the headframe | **The blast furnace**: a tapered grey stone stack, 15 px tall and 7 wide at the foot, a charging bridge (a timber ramp) on its right, the mouth at its foot glowing (`GLOW`, 2 x 2 px) | The stack, always |
| `"silver"` | Pale blue-grey spoil, near-white ore | No sparkles, no glints, no snow peaks | **The mint**: a white house (`PLASTER[3]`), 10 wide, on a grey stone base, **slate** roof, a barred dark door; beside it a stamp frame (2 timber posts and a beam, 6 px) | None; the usual house smoke in autumn and winter |
| `"copper"` | Grey-green spoil, orange ore | The outcrop's lit faces carry 3-4 `VERDIGRIS` stains (flat patches, no gradient) from level 1 | **The roasting yard**: three low dark heaps in a row (7 x 4 px, an orange line at the foot) on a trodden yard | The three heaps, always (three smokes: the activity limit) |
| `"gold"` | Pale ochre gravel heaps, a small ochre ore pile | **Its own layout tables** (two, for the two layouts): tents in place of the huts at levels 1 and 2 (pale cones 5 wide, 6 tall, on the huts' feet; houses at level 3) | Level 2's landmark is **the sluice** in place of the headframe: a timber trough on trestles, 26-30 px long, 4 tall, lying along the piece's own race (the race and its two ponds are longer; no stream to the border). Level 3: **the strongroom**: one small grey stone house, slate roof, a barred door. No fort, no ring, no tower | None |

Gold keeps the outcrop and the adit at level 1 (the family's signature); the river of the old tile is the map's
and is not drawn. Seasons as the family's; the race and the sluice's water are frozen where water freezes. No
people. No ore has a mountain, a peak or a tramway to the border.

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

### Quarry. Ground: `rock`. Seed 11. Models: `stone1`, `stone3`, `stone5`

The pit is **not** drawn from above. It is a stepped rock face rising to the back, like a wide stair seen from
the front: each ledge is a flat top (`PIT`) over a cut face (`PIT`, with the right quarter `PIT_D`), 4-5 px tall.
It is the family's own raised ground, as the mine's outcrop is, and is built with `p.stand` (give `x=`).

| Level | What is drawn | Landmark |
|---|---|---|
| 1 | One ledge at the back, 24 px wide; 2 cut blocks (`MARBLE` boxes, 3 x 2 px) on a trodden yard; a thatched hut; a track | The cut face |
| 2 | 3 ledges, 40 px wide, stepping back and up; 5 blocks in one neat stack; a second hut; a ramp (a pale track up the first ledge) | The treadwheel crane: a timber A-frame with a wheel at its foot, 12 px tall, on the lowest ledge's edge |
| 3 | 4 ledges, 56 px wide (18 px tall in all); 8 blocks in two stacks; a long thatched masons' lodge | The column yard in front: 3 standing `MARBLE` columns, 9 px tall, and one lying |

Seasons change little, as in mines (spring and summer are one picture): the ground palette; snow on ledge tops,
block tops and roofs, **the cut faces bare**; 2 masons in summer, nobody in winter. No smoke in any season, no
water, no heap. Coverage: the usual bands; the trodden yard is what clears the ground.

### Dye works. Ground: `grass`. Seed 12. Models: `dyes1`, `dyes3`, `dyes5`

| Level | What is drawn | Landmark |
|---|---|---|
| 1 | 3 round vats (flat ellipses 6 x 4 px with a `STONE_D` rim: blue, red, yellow) on a trodden yard; a thatched hut; a rinsing channel of plain water between two small ponds, inside the hex | The cloth line: 2 posts and a line with 3 hanging cloths (2.5 x 4 px each, in the vats' colours) |
| 2 | 6 vats in two rows of three (purple added); 2 cloth lines; the hut becomes a tiled house | The drying loft: a tall open timber frame, 10 wide and 11 tall, hung with long cloths in the four colours |
| 3 | 9 vats in a 3 x 3 grid; 3 cloth lines; a second house | The dye house: a wide stone building (`STONE` walls, tile roof, 13 px) with a chimney |

The vats lie on the ground; cloth lines and the loft stand. The old tile's coloured stream is dropped: the channel
is plain water. Seasons: the vats **keep their colours in every season, also under snow** (they are heated: no ice
and no snow on the liquor, snow only on the rims), which makes this family's winter its strongest picture; the
cloth lines are hung from spring to autumn and bare in winter, the loft is hung in every season; 2 dyers in
summer; the channel freezes where water freezes; the dye house chimney smokes **in every season** (a listed
chimney). Never more than nine vats, never square, never in pale colours (salt's pans).

### Hemp and the ropewalk. Ground: `farm`. Seed 13. Models: `hemp1`, `hemp3`, `hemp5`

| Level | What is drawn | Landmark |
|---|---|---|
| 1 | 2 blocks (14 x 12 px, 2 strips, `kit.crop("hemp", season)`), 1 retting pond (`RET`, about 9 x 6 px) touching a block, a thatched hut, a track | The hut |
| 2 | 5 blocks, 2 ponds, a row of 4 stooks (thin tripods of three lines, 2.4 wide, 4.5 tall) | The scutching barn: a thatched barn, 11 px |
| 3 | 8 blocks, 3 ponds, 6 stooks, a second house | The ropewalk: an open thatched shed **28 px long**, wall 4, roof 3, on posts, with a rope (one thin line) running 10 px out of its end to a post |

Blocks are near-square and lie at two or three slightly different angles, in loose groups with a pond between;
never in a row of long strips (the crowding table, section 4). Seasons: **spring** bare earth blocks with dashed
young rows (`hemp_row`) and full ponds; **summer** the darkest green, with a 1 px darker band along each block's
front edge (the crop stands tall), 1-2 workers; **autumn** cut: pale stubble, the stooks on the newest blocks, two
pale lines on each pond (bundles steeping), smoke; **winter** blocks in two snow tones with their edges, ponds
frozen where water freezes, no stooks. In a mild winter: bare dark earth, open ponds. Stooks stand in summer
(few) and autumn (all) only.

### Cotton. Ground: `farm`. Seed 16. Models: `cotton1`, `cotton3`, `cotton5`

| Level | What is drawn | Landmark |
|---|---|---|
| 1 | 1 patch of red earth (22 x 16 px, `cotton_soil`) with 5 plant rows along its long side, a thatched hut | The hut |
| 2 | 3 patches, 2 bales (`BOLL` boxes 3 x 2.5 px with two dark bands) by the shed | The drying shed: a thatched roof on posts, 12 px wide, open sides, white under it |
| 3 | 5 patches, 4 bales, a track | The gin house: a two-storey plastered house (`PLASTER[1]`), 9 wide and 8 tall, tile roof, a hoist beam on its right |

The red earth is a patch under the work only; the hex's ground is the map's. Seasons: spring young green dashed
rows on red earth; summer green rows, bolls (1 px `BOLL` dots) on every second row; **autumn is the harvest and
the signature at its strongest**: every row white with dots, 2 pickers, the bales out; winter no white at all:
bare brown stalk rows. Cotton grows where the winter is mild, and there its winter is bare stalks on dark red
earth; in a frost or snow winter the patch is snow soil with one row in four showing earth. Bales stand in
autumn and winter only.

### Silk. Ground: `grass`. Seed 14. Models: `silk1`, `silk3`, `silk5`

| Level | What is drawn | Landmark |
|---|---|---|
| 1 | 2 rows of 6 mulberries (`p.tree(..., "mulberry")`, 5 px apart) on pale strips (`mulberry_soil`, 3 px wide), a thatched hut | The hut |
| 2 | 4 rows of 7 | The silkworm shed: a long low thatched shed, 16 px, wall 3.5, with 4 dark window slots |
| 3 | 6 rows, a second shed | The caravanserai: a square court wall (`STONE`, 14 wide, 5 tall, an arched gate) with a small turquoise dome (`DOME_TILE`, 6 px wide) over the gate; 13 px tall in all |

The rows are straight, parallel and at least 9 px apart, with the sheds lying between them; the old tile's hedge
bands are not used (hedges are wheat's). Seasons: spring light green; **summer the leaves are picked**: every
second tree of the two newest rows stands stripped, 2 pickers with baskets; autumn gold and late green; winter
bare pollards with a snow dab; smoke from the sheds in autumn and winter. The dome keeps its colour in every
season; snow lies only on its upper left. Silk is mostly a warm-land good: check the mild winter first.

### Furs. Ground: `wood`. Seed 15. Models: `furs1`, `furs3`, `furs5`

The wood is the map's and stays. Coverage bands of its own: **10-20 / 20-35 / 35-50%**.

| Level | What is drawn | Landmark |
|---|---|---|
| 1 | A small clearing at the front (2 overlapping `p.blob`, alpha 0.5), 2 pelt frames (a pale timber square 4 x 4.5 px with a `PELT` diamond in it), a fire ring | The trapper's tent: a pale hide cone, 6 wide and 7 tall, its poles crossing at the top |
| 2 | The clearing wider; 5 frames in a row at the front | The log cabin: `TIMBER` walls with two log lines, a dark plank roof (`TIMBER_D`), 8 px |
| 3 | 8 frames in two rows, a second cabin, a stack of fur bales (`PELT` boxes) | The trading post: a long log house (13 px) inside a **square stockade open to the front** (three straight palisade sides, corner posts, about 30 px wide; the kit's ring wall is not used) |

No stumps, no log piles, no mound, no water (timber's), no stone, no banner (the castle's); the crowding table,
section 4. The pelt frames always stand in front of the buildings, nothing in front of them. Seasons: **winter is
the high season**: every frame carries a pelt and every cabin smokes (three smokes at most); in spring and summer
every second frame is empty and 1 trapper stands by the tent; autumn smoke from the tent's fire. The snow and the
pines are the season's and the map's.

### Sites. Ground: `grass`. Seed 17. One level. Models: the six `L-...` pictures of catalogue page 4

A site is a thing to find in land without an improvement. It is decoration: it marks no rule of the game.
`sites.draw(level, season, variant=0, mirror=False)` with `LEVELS = (0, 1)`; **the variant is the site**
(`VARIANTS = 6`, `SITES = ("monastery", "roman_ruins", "aqueduct", "standing_stones", "ruined_castle",
"pilgrimage_chapel")`). The map data says which hex has which site, so the map gives `variant=` itself and takes
only the mirror from `kit.pick`. Footprint **8-20%** of the margin hex, so the wild land comes close; at most
20 px tall; inside the safe area.

| Variant | Site | What is drawn |
|---|---|---|
| 0 | Monastery | A church (the kit's `church`, 13 px) with three low wings round a court (`p.claim`), all slate-roofed, inside a low stone wall; one garden plot, 2 fruit trees |
| 1 | Roman ruins | 4 broken columns of different heights (5-10 px, `MARBLE_D`), a lintel across two of them, 2 fallen drums, a pale paved patch (an overlay) |
| 2 | Aqueduct | A run of 5 arches (`STONE`, 9 px tall, 34 long), the last pier broken, both ends inside the hex |
| 3 | Standing stones | A ring of 7 grey stones (`STONE_GREY`, 3-6 px tall) on an ellipse of radius 12, one taller, one fallen; a faint trodden circle (alpha 0.25) |
| 4 | Ruined castle | A square tower stump (12 px) with a jagged top, a length of wall with a gap; `STONE_GREY`; 2 patches of ivy (`hedge`); no roof, banner, ring or mound |
| 5 | Pilgrimage chapel | The kit's `chapel` alone on a pale trodden knoll, a stone cross, 2 cypresses, a track to the south gate |

Seasons: the palette, snow caps on tops and roofs, the ivy rust in autumn. Smoke only from the monastery (autumn
and winter). People: 1-2 pilgrims at the chapel in summer, nobody else. No fields beyond the monastery's plot, no
animals, no heaps. Later sites (burial mound, wayside cross, hospice) get further variant numbers; the windmill
and the lighthouse are never sites (they are landmarks of wheat and harbour).

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

**Landmark cities**: `settlements.draw(level, season, variant=0, mirror=False, landmark=None)`. A famous city
shows its own monument **in place of the church (level 4) and the cathedral (level 5)**, on the same spot, with
the same green in front. Below level 4 the keyword does nothing: a famous city that is still a town looks like a
town. `landmark=None` is today's picture, pixel for pixel. The monuments live in one module, `landmarks.py`
(`NAMES`, `draw(p, name, level, x, y)` with `p.stand`, `x=` on every part); `settlements.py` only calls it, leaves
out the houses whose feet lie under the monument (`landmarks.CLEAR[name]`, a box per level) and takes the ring
wall's colour from `landmarks.WALL` where a city has one. A monument is at most **20 px tall and 24 px wide**, has
the kit's two tones and thin ink, and keeps the clear gap in front. Model pictures: `<city>2` for level 4 and
`<city>3` for level 5.

| `landmark=` | Level 4 | Level 5 adds | Notes |
|---|---|---|---|
| `"venice"` | The campanile: a `BRICK` shaft 4 px wide, 17 tall, a pale belfry, a pointed `VERDIGRIS` cap | St Mark's beside it: a low wide front (`MARBLE`) with 3 small `LEAD` domes, and the palace front (a pale block with an arcade line) | **The water is the map's** (below) |
| `"constantinople"` | The great dome: a wide low `LEAD` dome (12 px) on a pale stone body with two half-domes | 4 thin minarets (1.2 px wide, 16 tall, pointed caps) at its corners | The sea walls of the old tile are the settlement's own wall |
| `"paris"` | The twin-towered front: two square `CHURCH` towers, 15 tall, flat tops, a slate nave between them | The towers at 18 px, a thin spire behind them, a dark rose-window dot | No island, no river: they are the map's |
| `"moscow"` | The ring wall in `BRICK` (`WALL`), its towers with pointed slate caps; a white church with one `GILT` onion dome | A cluster of 4 onion domes in the `ONION` colours at different heights | Snow comes from the season, not from the piece |
| `"london"` | The White Tower: a square white keep (`PLASTER[3]`) with 4 corner turrets | The tall thin spire of the old cathedral | The bridge is the road layer's |
| `"rome"` | The round castle: a low wide drum (`STONE`) with a small block on top | The great dome (`LEAD`, on a drum with a lantern) | |
| `"seville"` | The Giralda: a tall pale tower, 20 px, with 3 dark bands and a belfry | A long low cathedral body at its foot; 2 planted palms are **not** drawn (poplars instead) | |
| `"lisbon"` | The shore tower: a white tower with corner turrets and a balcony line | A long monastery front beside it | Stands on the church's spot for now; at the shore with the harbour add-on is a later step |
| `"cairo"` | 2 minarets of different heights and a small ribbed dome, in banded `STONE` | A third and fourth minaret | No great dome: that is Constantinople's |
| `"granada"` | The red palace wall: a long low `BRICK` wall with 3 square towers | A taller square tower behind it | No hill, no snow peaks |

- **Venice and the water.** A town on islands needs the map: the hex would be lagoon, the town an island, there
  would be no wall and no south road. That is a design of its own (open, section 12). **Until then Venice is
  drawn as any city at a lagoon shore**: the settlement piece with `landmark="venice"`, clipped at the shore like
  every town, with the harbour add-on. The monument is drawn now; the island comes later and will not change it.
- A landmark city keeps the settlement's signature (red roofs round the monument, the wall). No monument may be a
  second castle: no banner, no bastion.
- The first four are Venice, Constantinople, Paris and Moscow; the other six follow in a second task.

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

**The third layout: motte and bailey** (`variant=2`; model: `K1`). The mound and the ring are **two places side
by side** instead of one inside the other: a small steep motte at the back left (about (-12, -16); a mound 22 x 12
px with a visibly darker front edge) and a bailey in front of it to the right (a ring of radius about 19 round
(9, 6)), joined by a short lane. The family's signature stays: grey stone, slate, the banner.

| Level | What is drawn | Landmark |
|---|---|---|
| 1 | The motte; the bailey as a palisade ring with a gate; a track to the gate point | The tower on the motte: grey stone, 14 px, slate cone, the banner (not the old tile's timber keep) |
| 2 | The bailey's ring in grey stone with 2 towers and a gatehouse; a small palisade round the motte's top | The keep on the motte: the tower grown in place to a square keep, 18 px with the motte's rise, battlements, the banner |
| 3 | The angular outer wall with bastions and the moat round **both**, 2 banners | The bastions |

The tallest point stays within 20 px above the keep's foot. The keep stands at least 14 px from (0, -3),
(15, -4) and (-15, -4). The bailey holds no houses (castles have none): a well or a timber shed at most.

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
| Settlements, castles | Any land but high peaks | `grass` | A landmark city is a settlement |
| Quarry | Hills and mountains with good stone | `rock` | The stepped face is the piece's own raised ground |
| Dye works | Lowland by water, near towns | `grass` | Its channel is its own water, inside the hex |
| Hemp | Wet lowland, river plains | `farm` | |
| Cotton | Warm dry plains (mostly the mild winter) | `farm` | Red earth only as a patch |
| Silk | Warm hills and plains (mostly the mild winter) | `grass` | |
| Furs | Northern woods | `wood` | Small footprint: the wood stays |
| Sites | Any land without an improvement | `grass` | Placed by the map data; one level |

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
  - **Limits (the owner's answer, round 4).** A carved bay may move the shore **up to 5 km** inland:
    `kit.BAY_REACH` = 19 px. This holds **for carved ports only**. Every other change the map makes to a coast
    (the style frame's coves, a lagoon's shore) keeps the old limit of **3.5 km** (`kit.COVE_REACH` = 13.3 px).
    The bay never leaves the port's hex; its horns stay inside the hex as headlands. Genoa's bay is 13 px (4.2 km).
  - **Fixed by the map data.** A port is carved from the first day of a game or never: the mode is read from the
    place data when the map is built, and the coast does not change in play (the owner's answer, round 4).
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

- [ ] **Three layouts** (vineyard, grazing, castles): layout 2 keeps the counts and landmarks, its yard is 14 px
      from both other yards and their mirror images, and at 50% it is told from all four other pictures.

**Keyword choices (ores, landmark cities) and sites**
- [ ] The default (`ore=None`, `landmark=None`) is pixel-equal to the picture before the task, for every level,
      season, layout and mirror (send the comparison).
- [ ] Each ore is told from the other three and from the default at 50% by its spoil and its level 3 landmark;
      the landmark stands on the smelter's foot; gold has no ring wall; only iron glows.
- [ ] Each landmark city is told from a plain city and from the other landmark cities at 50%; the monument is
      at most 20 px tall and 24 wide and stands on the church's spot; no house pokes through it.
- [ ] Each site is told from the other five at 50%, cannot be taken for a castle, a hamlet or a village, and its
      footprint is 8-20% of the margin hex.
- [ ] Every pair of the crowding table (section 4) that the family is in was put side by side at 50%.

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

**Decided in round 4** (the same day):

| | Question | The owner's answer | What it means here |
|---|---|---|---|
| 6 | Which Python art comes over? (`../python_art/catalogue.md`) | **"Top 10 (Recommended)."** | The four ores in Mines (`ore=`); new families Quarry, Dye works, Hemp, Silk, Furs, Cotton; landmark cities in Settlements levels 4-5 (`landmark=`; Venice, Constantinople, Paris, Moscow first, then the other six); a one-level Sites family; third layouts for vineyard, grazing and castles. Tables: section 8; signatures and crowding: section 4. The overseas batch is not picked |
| 7 | How far may a carved bay move the coast? | **Up to 5 km, carved ports only; the normal cove limit stays 3.5 km.** | `kit.BAY_REACH` = 19 px, `kit.COVE_REACH` = 13.3 px. Section 10 |
| 8 | When is a port's mode decided? | **By the map data: carved from the start; the coast never changes in play.** | Section 10 |

**The art director's calls in round 4** (recorded so they are not asked twice; the owner may overrule any):

- **The iron furnace glows.** One `GLOW` spot of 2 x 2 px in the furnace mouth, iron level 3, in every season. With
  the lighthouse lamp it is one of the map's two lights; no further ones (section 4).
- **Gold has no fort** (it would read as a castle); **the fur post's stockade is square and open** (section 4).
- **The mint has a slate roof**, not tile, so mines stay free of red roofs.
- **Cotton's strongest season is autumn**, not summer: the harvest is the white field.
- **The winter of warm-land families** (the catalogue's side question) is answered by the three winters: cotton,
  silk and dye works are drawn for all three and checked in the mild one first.
- **Cattle take the sheep's walled pastures** in the third grazing layout; only horses get round paddocks.
- **Cocoa's pods** (fruit on trees) need no answer: the overseas batch was not picked.

**Still open** (none blocks the tasks):

1. **Venice on the water.** Drawn for now as a city at a lagoon shore with its monument. A town on islands needs
   a rule for the map: (a) a **lagoon hex**: the map floods the hex with shallow water round the town's footprint
   and the piece drops its wall and south road for a quay edge (recommended, as a design task of its own after the
   first four monuments are seen); (b) leave Venice at the shore for good.
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
