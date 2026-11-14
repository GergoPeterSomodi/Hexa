# Thread 5: the tile and object library (draft, 2026-11-14)

Art director, design thread 5 of the map design (`00-brief.md`). **Status: draft for the owner. Nothing is built, no game
code was changed.** It reads threads 1 (relief), 2 (water), 3 (settlements and roads) and thread 4's edge record
(`04_sockets.png`) as they stood on 2026-11-14, and follows direction A with the owner's decisions
(`docs/design/godot-look/README.md`, close-ups 07, 07b, 08).

| Mockup | What it shows |
|---|---|
| `05_region_close.png` | The prototype region at the close zoom (hex radius 34): western Alps, Po plain, Liguria, the Duchy of Milan in full dress. Every hex is drawn by the library from its sockets. |
| `05_region_middle.png` | The same library at the middle zoom (radius 21): fewer, larger objects per hex. |
| `05_piece_sheet.png` | 24 example pieces, each in a little map with its edge sockets labelled (rivers, roads, bridges, crests, a pass, a lake, a port, towns 1 to 5, castles 1 to 3, fields, the edge-river variant, the border). |
| `05_milan_look.png` | Milan's dress: three border styles side by side, the arms at three sizes, the pennant, the plates and the country name. |

> **Updated 2026-11-14 for the owner's decisions** (`README.md`, section 10): rivers run along hex edges, so the road's
> side lane is gone; a short list of river cities has the river through the city hex (`04-wfc-model.md` section 3.6);
> lakes follow thread 2's 0.6 rule; socket names and the ground list follow threads 4 and 1; no Kenney art in the new
> map. **The mockups predate this:** `05_region_close.png`, `05_region_middle.png` and the river and "bank lane" cells of
> `05_piece_sheet.png` still draw rivers through hexes. They are not redrawn; the prototype's step 6 picture replaces
> them.

## 1. In plain words

The map is not painted hex by hex. It is built in **layers**, and each layer is built in the way that suits it:

1. **Ground** is a colour per hex (its cover and height), softly blended into the neighbours by a shader. No edge pieces at all.
2. **Water and roads** are lines drawn from the edge records. A river runs *along* its chain of edges, corner to corner
   ("a size 2 river runs along this edge"); a road *crosses* an edge at its middle ("a road crosses here"). Both hexes
   read the same edge record, so the line runs on without a seam. These are drawn as geometry, not as hundreds of
   pictures.
3. **Things that sit across hexes** (forests, mountain peaks, hills, fields, suburbs) are scattered on a grid laid over
   the whole map, not inside a hex. A forest ends where the ground changes, not at a hex edge.
4. **Things that sit on an edge** (ridge crests, passes, cliffs, coasts, bridges, quays, borders) are pieces that live on
   the edge itself, so both hexes show the same one.
5. **Things that sit in a hex** (towns, castles, farmsteads, hospices, mines, monasteries) are single pictures chosen by
   level, placed on the hex's "site": beside the river, at the road junction, facing the harbour.
6. **The country** is drawn last over the ground: a band of its colour inside its border, a dark border line, its arms and
   its name.

Why this way: a hex picture that has to contain everything (ground + coast + river + road + town) multiplies into
thousands of combinations. Kept in separate layers, each family stays small, and a change of level or owner redraws only
its own layer. The whole library is **about 130 new drawn pieces plus 6 drawing recipes**, on top of about 100 objects
reused from the Python game (section 6).

## 2. What can be reused (the inventory)

"Reuse" = baked as it is from the Python art code; "rework" = the same code with a change; "new" = drawn fresh. All of it
stays code-drawn (pygame recipes baked by the art baker, or Godot shaders and lines).

| Source | What | Verdict for the new map | Why |
|---|---|---|---|
| `nature.py` | 33 objects: snow peak, twin peak, crag, old mountain, foothills, green/dry/terraced hills, outcrop, 18 trees, shrubs, stones | **Reuse as is** (the scatter layer) | Already direction A (two-tone, ink, lit left), anchored at the feet, 3 sizes x 4 seeds. The mockups use them unchanged. |
| `life.py` | 42 objects: reeds, cattails, sea rocks, sea cliff, lighthouse, fishing boat, herds, monastery, wayside cross, ruins, windmill... | **Reuse as is** | Coast life, landmarks (monastery for thread 3), flavour on the world grid. |
| `goodsobjects.py` | 25 goods objects (deposits view) | **Reuse as is** | Map mode only. |
| `goodsart.py` | 25 goods x 5 levels as whole hex tiles | **Rework** | Split each tile into its ground (fields on the world grid) and its buildings (a farmstead, mine or workshop by level, as in mockup 08), so fields join the next hex. The building recipes stay. |
| `goodsart.py` helpers | `building`, `tower`, `flag`, `boat`, `mound` | **Reuse** (as drawing helpers for the new towns) | Same look as mockup 08. |
| `landscape.py` | ridge crests by edge, pass corridors, hospices, ground blend bands, field systems, tree density | **Rework** | The crest and hospice drawing becomes the crest edge pieces; the blend bands become a shader; field systems become the world grid. |
| `wfctiles.py` | coasts (63 masks), rivers (56 masks), roads, bridges, towns, harbours, castles, edge sockets (coast, line, wall) | **Rework the geometry, drop the per-mask sprites** | Its rule "every line crosses an edge at a fixed place at a right angle" is exactly what the library needs, so the curve code and the bridge drawing are kept; the 1,370 baked mask and town sprites are replaced by geometry drawn from the sockets. Towns and castles are replaced (below). |
| `wfctiles.py` towns, harbours, castles | 15 towns, 280 gate variants, 310 harbours, 9 castles | **Replace** | The direction A ladder (mockup 08: hamlet to walled city; tower, keep, star fort) is the new look. |
| `landmarks.py` | 10 famous cities x 3 stages | **Later** | Waits for the town redesign (owner's decision). Milan's Duomo and the Lanterna of Genoa are the first two candidates. |
| `art.py` | unit figures, tokens | Not part of the map library | Pieces belong to 0.3.2. |
| Kenney Hexagon Pack | terrain hex tiles, ground textures (grass, dirt, sand, stone), props, native camp | **Not used by the new map** | The ground is a blend of code-drawn textures; props are `nature.py`. See section 9. |

## 3. The ground

**Base terrain per kind.** Each hex has a relief level (thread 1: lowland to high peaks) and a ground from thread 1's
list (farmland, grass, woods, marsh, rock, snow, tundra), plus sand for beaches: eight textures. Desert, savanna and
jungle wait for the world outside Europe. The ground colour is the cover's colour, tinted by level (a hill pasture
is a shade darker and warmer than a plain pasture). Each cover has **one tileable texture** drawn in code: flat colour,
seeded tufts and specks in two tones. The texture is sampled in world space, so it never repeats at a hex edge.

**Soft blends across edges: a shader, not edge pieces** (recommended). One small texture holds one texel per hex (cover,
level, a little noise seed). The ground shader, at each pixel, weighs the three hexes nearest the pixel (its own and the two
across the nearest corner) by distance, with the boundary shifted by a noise texture, so the change of ground happens in a
band about a third of a hex wide that wanders across the edge. Hex centres keep their pure colour. This is what the mockups
do (a blur over noisy hex shapes). Cost: one shader, one noise texture, zero pieces, and it handles every pair of grounds,
including future ones.

The alternative, **edge pieces** (a transition picture per pair of grounds and per edge, as `landscape.py` draws today),
needs 8 covers x 8 covers x 6 edges, about 400 pictures, and still shows a straight join. It is kept only where the edge is
a real feature with a face: **cliffs, scarps and coasts** (section 4), which are edge pieces because they are drawn objects,
not blends.

**Hard edges stay crisp.** Sea and lake shores are not blended: the coast shape is cut out of a smoothed land mask (rounded
hex corners, a sand rim, a foam line, a pale shallow band), drawn above the ground. A valley floor is a hex flag (thread
1), not a ground: the art draws it as a pale meadow ribbon along the floor, from edge middle to edge middle, over the
hex's own ground.

## 4. Objects on and across hexes

Every object has an **anchor** (where it stands) and a **continuation rule** (how it joins the next hex).

| Object | Anchor | How it continues into the neighbour | Pieces |
|---|---|---|---|
| **Ground** | hex centre | blend shader | 0 (8 textures) |
| **Forests, scrub, olive groves** | world grid points (about 4 per hex width at close zoom) | the grid ignores hex edges; the cover at each point (with a noise wobble) picks the species; clearings come from a noise mask | reuse `nature.py` |
| **Hills** (domes, outcrops) | coarse world grid | same | reuse |
| **Mountains: three kinds** | coarse world grid | the kind is chosen from the *interpolated* height (thread 1), so a range fades from snowy peaks to rocky ranges to wooded hills across the edges | reuse: high peaks (`snow_peak`, `twin_peak`), rocky ranges (`crag`, `old_mountain`), low mountains (`foothills` + trees) |
| **Ridge crests** | on the crest edge, corner to corner | a crest edge always ends in a corner where another crest continues (thread 1's corner rule); a **corner cap** (one larger peak) sits on any corner shared by two crest edges | 3 edge orientations x 2 variants x snow or rock = 12; caps 3 |
| **Passes** | the saddle hex (28 km grid); its two crest-side edges carry `line = pass` | the saddle is the gap in the crest chain; the road track crosses only here; the hospice and a cairn stand on the saddle hex, beside the track; the name in italics | saddles 3 orientations x 2 = 6; hospice 2, cairn 1 |
| **Scarps and cliffs** | on the edge, facing the lower hex | edge pieces meet at corners like crests | 6 facings x 2 = 12 |
| **Rivers** | along the edges, corner to corner (`line = river1..3`) | the chain of edges fixes the course, the flow and the width; one smoothed curve per river, pinned at the middle of each of its edges and at every join corner | geometry, 0 sprites (appendix C) |
| **Lakes** | a lake smaller than 0.6 of a hex: `line = lake` edges on the river's chain, narrow or broad (thread 2's rule); a larger one: lake hexes | an edge lake is a widened stretch of the river strip with a shore; lake hexes use the coast recipe and the drawn sea tile | geometry |
| **Coasts** | the land mask, cut along the sea edges | the shoreline is one smoothed outline over all hexes; typed by the edge: beach (sand rim), cliff (cliff pieces), marsh (reeds, no rim), delta (river split) | cliff faces 12 (shared with scarps); beach and marsh: 0 |
| **Roads** | edge midpoints, always (a river is along an edge, never through its middle, so there is no side lane) | curves from each road edge to the hex's junction point (the town's site if it has one); quality 1 to 3 changes width and colour; steep hexes draw switchbacks | geometry, 0 sprites |
| **Bridges, fords, ferries** | the middle of the river edge that the road crosses | a bridge lies along the road; the river runs under it along the edge | wooden, stone, boat bridge, ferry: 4 x 3 axes = 12; ford: a pale stripe (0) |
| **Fields by level** | world grid (about 3 parcels per hex width) | parcels spread from each farm's site; the farm level sets how far (level 1 a few strips, level 5 the whole hex and spilling over); parcels of two farms meet and mix | 0 (parcels are generated); 3 parcel styles (vines, orchards, terraces) |
| **Farmsteads, mines, workshops** | the hex's site | level ladder of mockup 08; never more than one per hex | farm 5 levels x 2 = 10; mine 5; workshop 5 (rework from `goodsart`) |
| **Settlements** | the hex's site: beside the river (never on it, except a river city), at the road junction, towards the quay edge | the picture is a pure function of level, sockets and ground (thread 3); streets run to every road socket; from level 3 a gate where each road meets the wall; suburbs and fields spill into ring 1 and 2 on the world grid | towns 5 levels x 2 = 10; gates 3; capital palace 1; suburb houses reuse |
| **River cities** (the authored list, `04-wfc-model.md` 3.6) | the hex centre; the river curve runs through the hex from its in corner to its out corner | `through` form: a city-on-river piece by level and river axis, the town on both banks, the bridge at the centre along a road axis; `loop` form: the ordinary town piece inside the bend, standard bridges where the far roads cross the curve | city on river 3 levels x 3 axes = 9; bridge with houses 3 axes = 3 |
| **Castles** | beside the town, or alone at a chokepoint (pass foot, bridgehead) | none | 3 levels x 2 = 6 |
| **Ports** | the quay edge (sea, lake or river) | the quay lies on the shore of that edge; boats on the water side | quays 3 kinds (rotatable); harbour sets 3 levels; lighthouse reuse |
| **Monasteries, hospices, wayside crosses** | site; a hospice on its saddle hex | none | reuse `life.py` |
| **Borders** | the owner change between two hexes | drawn from owners, not pieces (section 7) | 0 |

**The site point** is computed, not stored: it starts at the hex centre, moves a third of a hex away from the hex's river
edges (to the dry side), or towards the quay edge for a port; roads end there. A river city's site is the hex centre. It is a function of the sockets, so it never moves on a
level-up (thread 3's rule "sockets never move").

## 5. How the solved sockets pick the pieces

### The edge record (thread 4) and what the library reads

Thread 4 stores one record per edge (`04-wfc-model.md` section 3.1; the names below are its final ones): `line` (what runs
along the edge: `none`, `sea`, `shore`, `crest`, `pass`, `river1` to `river3`, `lake`) with `flow`, `shore_kind` (`beach`,
`cliff`, `marsh`, `delta`, `lake`) and `lake_width`; `step` (`level`, `slope`, `scarp`, with the higher side) and `floor`
(a valley floor crosses here); `road` (0 to 3) with `crossing` (`ford`, `bridge_wood`, `bridge_stone`, `ferry`, `pass`,
`quay`); and `cover`, the blend, which is worked out and never stored. The library maps them as follows:

| Layer | Socket values read | Family | How the piece is chosen |
|---|---|---|---|
| cover (hex) | cover, level | ground | texture and tint by cover and level; blend by shader |
| relief (edge) | `line = crest`, `line = pass` | crest | the edge's orientation (3 per hex: E, NE, NW are owned by the hex, the other three by the neighbours), a variant by hash |
| relief (edge) | `step = scarp`, `shore_kind = cliff` | cliff | the facing (which side is low) |
| relief (corner) | two or more crests at a corner | crest cap | corner count |
| water (edge) | `line = river1..3` or `lake`, with `flow` and `lake_width` | river geometry | the river's chain of edges and their sizes; the corner words (`source`, `run`, `join`, `mouth`...) shape the ends and joins |
| water (edge) | `line = shore` with `shore_kind` | coast | the sea mask cuts the shore; the kind picks rim and pieces |
| road (edge) | `road` 1 to 3 | road geometry | the set of road edges and their quality |
| road (edge) | `crossing` = `ford`, `bridge_wood`, `bridge_stone`, `ferry` | bridge sprite | kind x the road's axis (3 axes) |
| road (edge) | `crossing = quay` | quay | kind (sea, lake, river) rotated to the edge |
| hex fact | `river_through` (in corner, out corner) | river city | form from the two corners; city-on-river piece by level and river axis |
| hex tags | settlement 0 to 5, capital, castle 0 to 3, landmark, farm level | site pieces | level ladder; variant by hash |
| hex tag | owner | border | not a piece |

**No WFC is needed to pick pieces.** Once relief, water and roads are solved (by WFC, routing or both, thread 4), every
hex's look is a lookup: sockets -> (piece, rotation, variant). The variant is a hash of the hex position, so it is stable
between runs and saves. This agrees with thread 3 ("WFC only picks the tile variant").

### Naming

`<layer>.<family>.<key>.<variant>`, with the key spelled per edge in the neighbour order E, NE, NW, W, SW, SE (the order of
`hexgrid.neighbors` and of the bake today):

- Rivers have no per-hex key: a river is one strip along its chain of edges (appendix C).
- `road.way.003030.v0`: a highway through NW and SW.
- `town.4.river.a1.v0`: a level 4 city on its river, river axis 1 (a river city).
- `relief.crest.e1.snow.v1`: a crest on the NE edge, snowy.
- `road.bridge.stone.axis0`, `town.4.v1`, `castle.3.v0`, `farm.2.v1`, `port.quay.sea`.

For **flat** families (roads, quays, field parcels) the key is stored in its **canonical rotation** (the smallest
of its six rotations) with a rotation 0 to 5 applied at draw time, so `020020`, `200200` and `002002` are one shape.
**Lit** families (crests, cliffs, bridges, towns, river cities, everything with a left-lit face) are never rotated: light comes from the
upper left on every piece.

### How many shapes

| Family | Distinct shapes | With sizes, kinds, variants | Drawn as |
|---|---|---|---|
| River (along edges) | no per-hex shape: one strip per chain; 7 corner words (source, run, join, mouth, split, lake in, lake out) and the 2 river-city words | x 3 sizes, 2 lake widths | geometry (appendix C) |
| Road | 8 shape classes under rotation: end 1, two-edge 3 (sharp, bend, straight), three-edge 4 (forks); plus 4-edge and more junctions (6 more) | x 3 qualities | geometry (appendix B) |
| Coast | one outline from the land mask | 4 shore types | shader + 12 cliff faces |
| Crest, pass, cliff | 3 orientations / 6 facings | 2 variants, snow or rock | 12 + 6 + 3 caps + 12 cliffs |
| Bridges | 3 axes | wooden, stone, boat, ferry | 12 sprites |
| Sites | levels | towns 10, castles 6, farms 10, mines 5, workshops 5, gates 3, palace 1, harbours 3, quays 3, hospice 2, cairn 1 | 49 sprites |
| River cities | 3 river axes | city on river 3 levels x 3 axes = 9; bridge with houses x 3 axes = 3 | 12 sprites |
| Ground | 8 covers | level tints by shader | 8 textures + 1 noise |
| Field styles | 3 | | 3 |
| Arms | 1 per country | 1 in the prototype, about 60 for Europe and the peoples | code-drawn vector |

**Total for the prototype: about 130 new drawn pieces and 6 recipes** (ground blend, coastline, river strip, road strip,
border ribbon, fields); it was about 120 before the river cities. Reused: 33 `nature.py` objects, 42 `life.py` objects, 25 goods objects and the `goodsart` building
helpers, about 100 in all. For comparison, today's bake has 1,859 sprites, of which about 1,370 are per-mask coast, river,
road and town pictures that this design replaces with the recipes.

**Ways to keep it small, all used above:**

1. **Layers never combine into one picture.** A coast with a river mouth and a road and a town is four layers, not one
   piece. Combinations add, they do not multiply.
2. **Geometry for flat lines.** A river is a curve along its chain of edges and a road is a curve through edge middles; the
   course and the width are fixed by the edge records, and both are drawn as textured strips. No mask pictures.
3. **Rotation for flat pieces only** (canonical key + rotation), never for lit ones.
4. **Edge pieces have 3 orientations, not 6:** each hex owns its E, NE and NW edges; the opposite three belong to the
   neighbours.
5. **The world grid** for everything that crosses edges (trees, peaks, fields, suburbs): no edge pieces at all.
6. **Level ladders reuse one recipe:** the level n picture is the level n+1 recipe with fewer parts (mockup 08, thread 3).

## 6. Scale: the ~57 km hex today and the ~28 km hex chosen for the prototype

The pieces are sized in **hex units with a floor in screen pixels**, so they work at both sizes. The mockups use today's
57 km hexes (the data as it is). What changes at 28 km:

| | 57 km hex (today) | 28 km hex (the prototype's size) |
|---|---|---|
| Piece shapes and count | as above | the same; nothing new to draw |
| Hexes on screen at one zoom | the same (zoom is in hex radius) | the same; the screen shows half the ground width |
| Ridge crest | 3 peaks per edge at the close zoom | 2 peaks per edge (a 28 km edge is short); the chain gets one cap per corner |
| Towns | a level 5 city fills the middle of its hex; neighbours are other places | the same picture; suburbs and fields spill into ring 1 as thread 3 designs (at 57 km the spill is cut to the own hex) |
| Lakes | Maggiore, Como, Garda are shapes inside one hex (in the mockup); by thread 2's rule each is one or two lake edges | Maggiore, Como and Garda are edge lakes (under 0.6 of a hex), three to six edges long; Geneva and Constance are over 0.6 of a hex and become lake hexes |
| Valleys | invisible (thread 1) | a one-hex ribbon (the valley flag, drawn as meadow) with the river along its flank |
| Scatter | world grid in hex units, so the same objects per hex | same; a real forest covers four times the hexes |
| Cost | | the bake is unchanged; the map holds four times the hexes, so instance counts (trees, parcels) per *map* are four times higher but per *screen* the same; the ground texel map is four times bigger (still small: about 500 x 400 for Europe) |

Recommendation from the art side: the library is neutral; the 28 km hex makes the region read much better (valleys,
lake shores, Pavia and Como as their own places), and the art is built for it.

## 7. The one country's look: the Duchy of Milan

`05_milan_look.png` and both region mockups.

- **Colour:** Milan's map colour from the country table (teal, 60/140/150). A faint wash (about 15%) over its land.
- **Border, recommended style A "ribbon + line":** a band of the country colour about a third of a hex wide inside the
  border, a dark line (the colour darkened by half) on the border itself, drawn above the trees so it reads through forests.
  The band follows the land and stops at the coast. B "wash + thin line" reads weaker on busy ground; C "line only" loses the
  "whose land" read (principle 11). Other countries in the prototype keep a neutral dashed line; in the game every country
  gets the same style in its own colour.
- **Arms:** the Visconti viper (biscione), simplified: a white shield, a blue crowned serpent with a red figure. Code-drawn,
  readable from 22 px (the map plate) to 96 px (the hover card); on the army's swallow-tailed pennant in the country colour.
  It is a sketch to be checked against a heraldry source before it ships.
- **Labels:** the country name in spaced capitals in the darkened country colour with a pale halo ("DUCHY OF MILAN");
  town plates on a navy pill with gold level dots, a crown on the capital and the arms beside the capital's plate; pass
  names in italics; rivers, lakes and seas in italic blue.
- **Calm ground:** under towns, castles and (in play) armies the scatter is cleared, so the pieces stand out (the owner's
  third borrowing).

## 8. Sockets I need

Thread 4 owns the list, and its final names are used here (`04-wfc-model.md` sections 3.1 to 3.5: `line = crest` or `pass`,
`step = scarp`, `shore_kind`). The library needs, per edge, exactly what is in thread 4's record. How the five requests of
the first draft ended:

1. **River crossing point: decided.** Rivers run along the edges (the owner, 2026-11-14; this draft's "model B"). A bridge
   sits on the middle of the river edge that the road crosses, and the river is an edge line like the crest. The one
   exception is a listed river city, where the river runs through the hex and the bridge is in the city piece.
2. **Side lane positions: dropped.** A road and a river never pass through the same point side by side, so a road is
   always on the edge middle and no lane value is stored.
3. **Shore type per edge:** one value, `shore_kind` (`beach`, `cliff`, `marsh`, `delta`, `lake`).
4. **Corner flags** for crest caps and the river corner words (thread 4, section 3.3, with `city_in` and `city_out` for
   river cities). Derived, not solved.
5. **Hex tags, not sockets:** cover, level, valley flag, saddle, settlement level, capital, castle, landmark, farm or works
   level, port, `river_through`, owner. Changing any of them redraws only its own layer.

## 9. The Kenney list (for the new map)

The new map uses **no Kenney art** (decided by the owner on 2026-11-14, question 4 in `README.md`). Today's uses and their
replacements:

| Kenney file(s) | Used today for | In the new map |
|---|---|---|
| Grass grass_05, grass_19 | plains and the ground under forests, hills, mountains at the near zooms (the largest share) | code-drawn farmland, grass and woods textures (new, about 1 day) |
| Grass grass_12, grass_13, grass_15 | zoom 13 forest and hills tiles | not needed: ground blend + `nature.py` scatter |
| Sand sand_07, sand_19 | desert and coast ground | code-drawn sand texture; the coast sand rim is drawn by the coastline recipe |
| Dirt dirt_06, dirt_19 | steppe and savanna | code-drawn grass (steppe) texture |
| Stone stone_07 | alpine and tundra ground | code-drawn rock and tundra textures |
| Props (trees, rocks) | decorations | `nature.py` (already ours) |
| Western native camp | native villages | not in the prototype region; regional native camps later (owner's decision 2026-11-13) |

The 0.3.0 map keeps its Kenney tiles as decided; the list above applies to the new map only.

## 10. Risks and open points

- **Busy ground.** At the close zoom the rocky ranges and forests are dense (as in mockup 07). The density is one number per
  cover; a calmer setting is cheap. Clearings under pieces are in.
- **The rivers decision is closed:** rivers run along edges, with the river-city exception (section 8, item 1). The
  mockups still draw rivers through the midpoints and show the edge model in one cell of the piece sheet; they are
  replaced by the prototype's step 6 picture. No mockup shows a city-on-river piece yet.
- **The mockup relief is a stand-in:** the data marks the Po plain as mountains; the mockup redraws it as farmland and
  marsh (thread 1 fixes it properly). The Ticino, Adda and Mincio and the five lakes are hand-placed (thread 2 gap). The
  village, farm and town levels are made up for the picture.
- **Fonts** are Windows stand-ins (Georgia, Segoe UI); the game needs open-licence fonts.
- **The arms** are a sketch; every country's arms need a check.
- **Star fort and palisade pictures** are rough at the close zoom; they get a proper pass when the town ladder is built.
- **Performance:** the world-grid scatter must be drawn per viewport (MultiMesh in Godot) and the ground texel map kept
  small; at 28 km the instance count per map is four times higher (section 6).

## 11. Questions for the owner

1. **How should a country's border look?** (a) **A band of the country colour inside the border with a dark line on it,
   and a faint wash over the land (recommended):** reads through forests and at every zoom; (b) a stronger wash over the
   whole land with a thin line; (c) a dark line only.
2. **Should the new map be free of Kenney art from the start?** (a) **Yes: draw the ground textures in code (eight by
   thread 1's list; about a day of art work); the props are already ours (recommended)**, so the new map never needs a
   replacement pass before Steam; (b) use the Kenney ground textures first and replace them before Steam, as today.
   *Answered 2026-11-14: (a), no Kenney art in the new map.*
3. **What shape should coasts have?** (a) **The hex shape with rounded corners, a sand rim and a foam line, as in the
   approved close-up 07 (recommended):** a coast hex is still easy to read as one hex; (b) a fully natural, wavy coastline
   that ignores the hex shape: prettier but the player cannot see which hexes touch the sea.

---

# Appendix: technical notes

## A. Layers and draw order (Godot)

| Order | Layer | Godot node | Input |
|---|---|---|---|
| 1 | Ground | one quad, ground shader (texel map of cover, level, seed; 8 cover textures as a texture array; noise) | hex tags |
| 2 | Sand rim, shallow band, sea, foam | coastline shader on a land mask texture (signed distance, rounded corners); waves as a scrolling detail | sea and shore sockets |
| 3 | Fields | MultiMesh of parcels on the world grid (colour by hash, angle by low-frequency noise, extent by farm level from the site) | farm levels |
| 4 | Country wash | the owner texel map in the ground shader (alpha about 15%) | owners |
| 5 | Rivers, lakes | textured strip meshes built per river chain from its edges, cut into the map's chunks (bank, water, highlight) | water sockets, `river_through` |
| 6 | Sea cover | the coastline shader draws above river ends (a river ends under the sea) | |
| 7 | Roads | strip meshes per hex from the road sockets, switchbacks on steep hexes | road sockets |
| 8 | Border band | owner texel map + distance to the border edge in a shader | owners |
| 9 | Upright objects (y-sorted) | MultiMesh per atlas page: scatter, crest pieces, bridges, sites; a y-sort by the foot | everything |
| 10 | Border line | Line2D along owner edges | owners |
| 11 | Hex grid, labels, plates | lines, Labels, the UI theme | |

## B. The road curve recipe

Per hex, the edges carrying a road are known. Port P(e) is the edge midpoint, always: there is no lane offset. A two-edge
hex draws one smooth curve: two cubic Béziers from P(e1) to a hub and from the hub to P(e2), leaving each port along the
inward normal with handle length 0.42 hex units, the hub slightly off centre (a hash of the position, about 0.08), or on the
site point if the hex has a settlement. A one-edge (road end) or three-edge (fork) hex draws each port to the hub. Width
is set per edge (the road's quality), so both hexes agree at the edge; inside the hex it is interpolated. Casing, surface
and a thin left-lit highlight are three strips. Where a road edge is also a river edge, the bridge, ford or ferry piece
sits on the edge midpoint along the road's axis; no curve intersection is needed.

Sizes used in the mockup (hex units, radius 1): road 0.06, highway 0.075.

## C. The river recipe (rivers along edges)

The river is a polyline along hex edges, corner to corner, smoothed within a third of a hex (Chaikin, 3 passes; thread 2's
appendix A.3 has the full recipe: pinned at the middle of each edge it runs along and at every join corner). It is an edge
line like the crest: it belongs to the edge record, and both hexes draw the same strip. Bank colour, water and a thin
left-lit highlight are three strips. An edge lake is the same strip widened (narrow or broad). A town site moves to the
dry side of its river edges.

**In a river-city hex** (`04-wfc-model.md` section 3.6) the same polyline leaves the edges at the hex's in corner, goes to
the hex centre and on to the out corner, and is pinned at all three (for the `loop` form, at a point about 0.45 of the hex
radius beyond the centre instead, so the river swings round the town). The city-on-river piece is drawn over it with its
channel on the curve; the bridge sits at the centre along the road axis that is at right angles to the river, so the
library's three bridge axes are enough.

Sizes used in the mockup (hex units, radius 1): stream 0.06, river 0.085, great river 0.115. Thread 2's mockup draws them
wider (0.17, 0.27, 0.42); the prototype's step 3 picture settles the widths.

## D. Ground blend shader

`w_i = smoothstep(b + n, b - n, d_i)` over the three nearest hex centres, d_i the distance to centre i in hex units, b the
band (0.3) and n a noise sample (amplitude 0.15); colours mixed by normalised weights. The mockup approximates it on the CPU
(blurred noisy hex polygons); the noise must be sampled in world space so both sides of an edge agree (the mockup showed
gaps where a displacement was taken along each hex's own normal: always displace by a world-space vector).

## E. Bake list for the art baker (new map)

New recipes: crest chain pieces (12), caps (3), pass saddles (6), hospice (2), cairn (1), cliffs and scarps (12), bridges
and ferries (12), towns (10), gates (3), palace (1), castles (6), farmsteads (10), mines (5), workshops (5), harbours (3),
quays (3), city-on-river pieces (9), bridges with houses (3), field styles (3), ground textures (8), noise (1), arms (1 for
the prototype). Reused from the Python bake:
`nature.py` objects (33 x 3 sizes x 4 seeds), `life.py` objects (42), goods objects (25). Every sprite keeps the bake's
conventions (2 px extruded border, anchor at the foot for upright pieces, the index with layer and sort offset).

## F. Mockup notes

Drawn by a scratch script (not stored in the repo) with pygame, from the Python game's Europe 1480 data for the frame
(terrain, owners, the data's rivers, roads, ridge edges, passes and cities), with the stand-ins listed in section 10. The
piece sheet builds a small map per piece and runs the same renderer, so each cell shows exactly what the library draws for
those sockets. Measured: close frame 1280 x 720 at radius 34, about 300 hexes on screen; the renderer draws every hex from
its sockets with no per-hex picture.
