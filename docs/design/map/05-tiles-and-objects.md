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

## 1. In plain words

The map is not painted hex by hex. It is built in **layers**, and each layer is built in the way that suits it:

1. **Ground** is a colour per hex (its cover and height), softly blended into the neighbours by a shader. No edge pieces at all.
2. **Water and roads** are lines and shapes that are drawn from the hex edges they cross. Each edge says "a size 2 river
   crosses here" or "a road crosses here"; both hexes draw their half through the same point at the same width, so the
   line runs on without a seam. These are drawn as geometry, not as hundreds of pictures.
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
its own layer. The whole library is **about 120 new drawn pieces plus 6 drawing recipes**, on top of about 100 objects
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

**Base terrain per kind.** Each hex has a relief level (thread 1: lowland to high peaks) and a cover (farmland, grass,
woods, marsh, rock, snow, tundra; sand and water). The ground colour is the cover's colour, tinted by level (a hill pasture
is a shade darker and warmer than a plain pasture). Each cover has **one tileable texture** drawn in code: flat colour,
seeded tufts and specks in two tones. The texture is sampled in world space, so it never repeats at a hex edge.

**Soft blends across edges: a shader, not edge pieces** (recommended). One small texture holds one texel per hex (cover,
level, a little noise seed). The ground shader, at each pixel, weighs the three hexes nearest the pixel (its own and the two
across the nearest corner) by distance, with the boundary shifted by a noise texture, so the change of ground happens in a
band about a third of a hex wide that wanders across the edge. Hex centres keep their pure colour. This is what the mockups
do (a blur over noisy hex shapes). Cost: one shader, one noise texture, zero pieces, and it handles every pair of grounds,
including future ones.

The alternative, **edge pieces** (a transition picture per pair of grounds and per edge, as `landscape.py` draws today),
needs 9 covers x 9 covers x 6 edges, about 400 pictures, and still shows a straight join. It is kept only where the edge is
a real feature with a face: **cliffs, scarps and coasts** (section 4), which are edge pieces because they are drawn objects,
not blends.

**Hard edges stay crisp.** Sea and lake shores are not blended: the coast shape is cut out of a smoothed land mask (rounded
hex corners, a sand rim, a foam line, a pale shallow band), drawn above the ground. Valley floors (thread 1) are a cover
(pale meadow) along the valley's edges, so they blend like any ground.

## 4. Objects on and across hexes

Every object has an **anchor** (where it stands) and a **continuation rule** (how it joins the next hex).

| Object | Anchor | How it continues into the neighbour | Pieces |
|---|---|---|---|
| **Ground** | hex centre | blend shader | 0 (9 textures) |
| **Forests, scrub, olive groves** | world grid points (about 4 per hex width at close zoom) | the grid ignores hex edges; the cover at each point (with a noise wobble) picks the species; clearings come from a noise mask | reuse `nature.py` |
| **Hills** (domes, outcrops) | coarse world grid | same | reuse |
| **Mountains: three kinds** | coarse world grid | the kind is chosen from the *interpolated* height (thread 1), so a range fades from snowy peaks to rocky ranges to wooded hills across the edges | reuse: high peaks (`snow_peak`, `twin_peak`), rocky ranges (`crag`, `old_mountain`), low mountains (`foothills` + trees) |
| **Ridge crests** | on the crest edge, corner to corner | a crest edge always ends in a corner where another crest continues (thread 1's corner rule); a **corner cap** (one larger peak) sits on any corner shared by two crest edges | 3 edge orientations x 2 variants x snow or rock = 12; caps 3 |
| **Passes** | the crest edge carrying `crest:pass` | the saddle is the gap in the chain; the road track crosses only here; a hospice and a cairn stand at the edge midpoint on the higher side; the name in italics | saddles 3 orientations x 2 = 6; hospice 2, cairn 1 |
| **Scarps and cliffs** | on the edge, facing the lower hex | edge pieces meet at corners like crests | 6 facings x 2 = 12 |
| **Rivers** | through the edge midpoints (thread 4's record) or along the edges (thread 2's option B) | the edge fixes the point, the direction and the width; the curve inside the hex is drawn from the hex's own river edges | geometry, 0 sprites (section 5) |
| **Lakes** | narrow lakes: on edges (thread 2); broad lakes: lake hexes | narrow lakes are a wide river strip with a shore; lake hexes use the coast pieces | geometry |
| **Coasts** | the land mask, cut along the sea edges | the shoreline is one smoothed outline over all hexes; typed by the edge: beach (sand rim), cliff (cliff pieces), marsh (reeds, no rim), delta (river split) | cliff faces 12 (shared with scarps); beach and marsh: 0 |
| **Roads** | edge midpoints, or the side lane where the road shares an edge with a river | curves from each road edge to the hex's junction point (the town's site if it has one); quality 1 to 3 changes width and colour; steep hexes draw switchbacks | geometry, 0 sprites |
| **Bridges, fords, ferries** | where the road curve meets the river (on the edge midpoint in thread 2's model) | a bridge lies along the road; the river runs under it | wooden, stone, boat bridge, ferry: 4 x 3 axes = 12; ford: a pale stripe (0) |
| **Fields by level** | world grid (about 3 parcels per hex width) | parcels spread from each farm's site; the farm level sets how far (level 1 a few strips, level 5 the whole hex and spilling over); parcels of two farms meet and mix | 0 (parcels are generated); 3 parcel styles (vines, orchards, terraces) |
| **Farmsteads, mines, workshops** | the hex's site | level ladder of mockup 08; never more than one per hex | farm 5 levels x 2 = 10; mine 5; workshop 5 (rework from `goodsart`) |
| **Settlements** | the hex's site: beside the river (never on it), at the road junction, towards the quay edge | the picture is a pure function of level, sockets and ground (thread 3); streets run to every road socket; from level 3 a gate where each road meets the wall; suburbs and fields spill into ring 1 and 2 on the world grid | towns 5 levels x 2 = 10; gates 3; capital palace 1; suburb houses reuse |
| **Castles** | beside the town, or alone at a chokepoint (pass foot, bridgehead) | none | 3 levels x 2 = 6 |
| **Ports** | the quay edge (sea, lake or river) | the quay lies on the shore of that edge; boats on the water side | quays 3 kinds (rotatable); harbour sets 3 levels; lighthouse reuse |
| **Monasteries, hospices, wayside crosses** | site, or the pass edge | none | reuse `life.py` |
| **Borders** | the owner change between two hexes | drawn from owners, not pieces (section 7) | 0 |

**The site point** is computed, not stored: it starts at the hex centre, moves a third of a hex away from the river (to
the dry bank), or towards the quay edge for a port; roads end there. It is a function of the sockets, so it never moves on a
level-up (thread 3's rule "sockets never move").

## 5. How the solved sockets pick the pieces

### The edge record (thread 4) and what the library reads

Thread 4 stores one record per edge in four layers: **relief** (level, slope, scarp, floor, crest, pass), **water** (none,
river 1 to 3 with flow, lake, shore, mouth, sea), **road** (none, track, road, highway; middle or bank lane; harbour) and
**cover** (derived blend, never stored). Thread 3 adds `crossing` (ford, wooden or stone bridge, ferry, pass) and `quay`;
thread 2 types the shore (beach, cliff, marsh, delta, lake). The library maps them as follows:

| Layer | Socket values read | Family | How the piece is chosen |
|---|---|---|---|
| cover (hex) | cover, level | ground | texture and tint by cover and level; blend by shader |
| relief (edge) | `crest`, `crest:pass` | crest | the edge's orientation (3 per hex: E, NE, NW are owned by the hex, the other three by the neighbours), a variant by hash |
| relief (edge) | `scarp_top/foot`, `coast:cliff` | cliff | the facing (which side is low) |
| relief (corner) | two or more crests at a corner | crest cap | corner count |
| water (edge) | `river.1..3`, `lake`, `mouth` | river geometry | the set of river edges and their sizes (shape class below) |
| water (edge) | `coast.beach/cliff/marsh/delta/lake` | coast | the sea mask cuts the shore; the type picks rim and pieces |
| road (edge) | quality 1 to 3, lane | road geometry | the set of road edges, their quality and lane |
| road (edge) | `crossing` | bridge sprite | kind x the road's axis (3 axes) |
| road (edge) | `quay` | quay | kind (sea, lake, river) rotated to the edge |
| hex tags | settlement 0 to 5, capital, castle 0 to 3, landmark, farm level | site pieces | level ladder; variant by hash |
| hex tag | owner | border | not a piece |

**No WFC is needed to pick pieces.** Once relief, water and roads are solved (by WFC, routing or both, thread 4), every
hex's look is a lookup: sockets -> (piece, rotation, variant). The variant is a hash of the hex position, so it is stable
between runs and saves. This agrees with thread 3 ("WFC only picks the tile variant").

### Naming

`<layer>.<family>.<key>.<variant>`, with the key spelled per edge in the neighbour order E, NE, NW, W, SW, SE (the order of
`hexgrid.neighbors` and of the bake today):

- `water.river.020020.v1`: a size 2 river through the E and W edges (straight).
- `water.river.100210.v0`: a confluence (two streams in, a size 2 river out).
- `road.way.003030.v0`: a highway through NW and SW, `road.way.0b0b00`: a road on the bank lane.
- `relief.crest.e1.snow.v1`: a crest on the NE edge, snowy.
- `road.bridge.stone.axis0`, `town.4.v1`, `castle.3.v0`, `farm.2.v1`, `port.quay.sea`.

For **flat** families (rivers, roads, quays, field parcels) the key is stored in its **canonical rotation** (the smallest
of its six rotations) with a rotation 0 to 5 applied at draw time, so `020020`, `200200` and `002002` are one shape.
**Lit** families (crests, cliffs, bridges, towns, everything with a left-lit face) are never rotated: light comes from the
upper left on every piece.

### How many shapes

| Family | Distinct shapes | With sizes, kinds, variants | Drawn as |
|---|---|---|---|
| River (through midpoints) | 8 shape classes under rotation: spring 1, two-edge 3 (sharp, bend, straight), three-edge 4 (confluences) | x 3 sizes, widths per edge | geometry (a curve recipe) |
| River (along edges, thread 2) | 5 corner words (source, run, join, mouth, split) x 3 sizes | | geometry |
| Road | the same 8 classes plus 4-edge and more junctions (6 more) | x 3 qualities, 2 lanes | geometry |
| Coast | one outline from the land mask | 4 shore types | shader + 12 cliff faces |
| Crest, pass, cliff | 3 orientations / 6 facings | 2 variants, snow or rock | 12 + 6 + 3 caps + 12 cliffs |
| Bridges | 3 axes | wooden, stone, boat, ferry | 12 sprites |
| Sites | levels | towns 10, castles 6, farms 10, mines 5, workshops 5, gates 3, palace 1, harbours 3, quays 3, hospice 2, cairn 1 | 49 sprites |
| Ground | 9 covers | level tints by shader | 9 textures + 1 noise |
| Field styles | 3 | | 3 |
| Arms | 1 per country | 1 in the prototype, about 60 for Europe and the peoples | code-drawn vector |

**Total for the prototype: about 120 new drawn pieces and 6 recipes** (ground blend, coastline, river strip, road strip,
border ribbon, fields). Reused: 33 `nature.py` objects, 42 `life.py` objects, 25 goods objects and the `goodsart` building
helpers, about 100 in all. For comparison, today's bake has 1,859 sprites, of which about 1,370 are per-mask coast, river,
road and town pictures that this design replaces with the recipes.

**Ways to keep it small, all used above:**

1. **Layers never combine into one picture.** A coast with a river mouth and a road and a town is four layers, not one
   piece. Combinations add, they do not multiply.
2. **Geometry for flat lines.** Rivers and roads are curves built from their edge sockets (the point, the direction and the
   width are fixed per edge), drawn as textured strips. No mask pictures.
3. **Rotation for flat pieces only** (canonical key + rotation), never for lit ones.
4. **Edge pieces have 3 orientations, not 6:** each hex owns its E, NE and NW edges; the opposite three belong to the
   neighbours.
5. **The world grid** for everything that crosses edges (trees, peaks, fields, suburbs): no edge pieces at all.
6. **Level ladders reuse one recipe:** the level n picture is the level n+1 recipe with fewer parts (mockup 08, thread 3).

## 6. Scale: the ~55 km hex today and the ~28 km hex proposed by thread 3

The pieces are sized in **hex units with a floor in screen pixels**, so they work at both sizes. The mockups use today's
55 km hexes (the data as it is). What changes at 28 km:

| | 55 km hex (today) | 28 km hex (thread 3's recommendation) |
|---|---|---|
| Piece shapes and count | as above | the same; nothing new to draw |
| Hexes on screen at one zoom | the same (zoom is in hex radius) | the same; the screen shows half the ground width |
| Ridge crest | 3 peaks per edge at the close zoom | 2 peaks per edge (a 28 km edge is short); the chain gets one cap per corner |
| Towns | a level 5 city fills the middle of its hex; neighbours are other places | the same picture; suburbs and fields spill into ring 1 as thread 3 designs (at 55 km the spill is cut to the own hex) |
| Lakes | Maggiore, Como, Garda are shapes inside one hex (in the mockup) | they become edge lakes (thread 2) two or three hexes long; Geneva and Garda can be lake hexes |
| Valleys | invisible (thread 1) | a one-hex ribbon of meadow cover with the river on its floor |
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

Thread 4 owns the list. The library needs, per edge, exactly what is in thread 4's record plus:

1. **River crossing point:** either at the edge midpoint (thread 4's picture, thread 3's bridges) or along the edge (thread
   2's recommendation B). The library supports both; it needs **one decision**, because the bridge, the town site and the
   road lane depend on it. In model B a bridge sits on the edge midpoint where a road crosses a river edge (a clean, fixed
   place), and the river becomes an edge piece like the crest: the art side is slightly simpler with B.
2. **Side lane positions in world terms:** a road on the bank lane sits a fixed distance along the edge, measured in one
   world direction (towards larger x, then larger y), so both hexes put it at the same point. The mockup uses 0.3 of the
   edge from the midpoint.
3. **Shore type per edge** (thread 2's `coast.beach`, `.cliff`, `.marsh`, `.delta`, `.lake`) and thread 1's `coast:cliff`, merged into
   one value.
4. **Corner flags** for crest caps and river corner words (thread 2's corner words; thread 1's crest corner rule). Derived,
   not solved.
5. **Hex tags, not sockets:** cover, level, settlement level, capital, castle, landmark, farm or works level, quay edge,
   owner. Changing any of them redraws only its own layer.

## 9. The Kenney list (for the new map)

The new map uses **no Kenney art**. Today's uses and their replacements:

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
- **The rivers decision** (section 8, item 1) is open between threads 2 and 4; the mockups draw rivers through the
  midpoints and show the edge model in one cell of the piece sheet.
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
2. **Should the new map be free of Kenney art from the start?** (a) **Yes: draw the nine ground textures in code (about a
   day of art work); the props are already ours (recommended)**, so the new map never needs a replacement pass before Steam;
   (b) use the Kenney ground textures first and replace them before Steam, as today.
3. **What shape should coasts have?** (a) **The hex shape with rounded corners, a sand rim and a foam line, as in the
   approved close-up 07 (recommended):** a coast hex is still easy to read as one hex; (b) a fully natural, wavy coastline
   that ignores the hex shape: prettier but the player cannot see which hexes touch the sea.

---

# Appendix: technical notes

## A. Layers and draw order (Godot)

| Order | Layer | Godot node | Input |
|---|---|---|---|
| 1 | Ground | one quad, ground shader (texel map of cover, level, seed; 9 cover textures as a texture array; noise) | hex tags |
| 2 | Sand rim, shallow band, sea, foam | coastline shader on a land mask texture (signed distance, rounded corners); waves as a scrolling detail | sea and shore sockets |
| 3 | Fields | MultiMesh of parcels on the world grid (colour by hash, angle by low-frequency noise, extent by farm level from the site) | farm levels |
| 4 | Country wash | the owner texel map in the ground shader (alpha about 15%) | owners |
| 5 | Rivers, lakes | textured strip meshes built per hex from the river sockets (bank, water, highlight) | water sockets |
| 6 | Sea cover | the coastline shader draws above river ends (a river ends under the sea) | |
| 7 | Roads | strip meshes per hex from the road sockets, switchbacks on steep hexes | road sockets |
| 8 | Border band | owner texel map + distance to the border edge in a shader | owners |
| 9 | Upright objects (y-sorted) | MultiMesh per atlas page: scatter, crest pieces, bridges, sites; a y-sort by the foot | everything |
| 10 | Border line | Line2D along owner edges | owners |
| 11 | Hex grid, labels, plates | lines, Labels, the UI theme | |

## B. The river and road curve recipe (midpoint model)

Per hex, the edges carrying the line are known. Port P(e) is the edge midpoint (plus the lane offset). A two-edge hex draws
one smooth curve: two cubic Béziers from P(e1) to a hub and from the hub to P(e2), leaving each port along the inward
normal with handle length 0.42 hex units, the hub slightly off centre (a hash of the position, about 0.08). A one-edge
(spring) or three-edge (confluence) hex draws each port to the hub. Width is set per edge (the socket's size), so both
hexes agree at the edge; inside the hex it is interpolated. Bank colour, water and a thin left-lit highlight are three
strips. The bridge test is the intersection of the road and river curves of one hex.

Sizes used in the mockup (hex units, radius 1): stream 0.06, river 0.085, great river 0.115; road 0.06, highway 0.075.

## C. The edge model for rivers (thread 2, option B)

The river is a polyline along hex edges, corner to corner, smoothed within a third of a hex (Chaikin, 3 passes). It is
an edge piece like the crest: it belongs to the edge record, both hexes draw the same strip. A road crossing a river edge
puts its bridge on the edge midpoint along the road's axis. A town site moves to the dry side of its river edges.

## D. Ground blend shader

`w_i = smoothstep(b + n, b - n, d_i)` over the three nearest hex centres, d_i the distance to centre i in hex units, b the
band (0.3) and n a noise sample (amplitude 0.15); colours mixed by normalised weights. The mockup approximates it on the CPU
(blurred noisy hex polygons); the noise must be sampled in world space so both sides of an edge agree (the mockup showed
gaps where a displacement was taken along each hex's own normal: always displace by a world-space vector).

## E. Bake list for the art baker (new map)

New recipes: crest chain pieces (12), caps (3), pass saddles (6), hospice (2), cairn (1), cliffs and scarps (12), bridges
and ferries (12), towns (10), gates (3), palace (1), castles (6), farmsteads (10), mines (5), workshops (5), harbours (3),
quays (3), field styles (3), ground textures (9), noise (1), arms (1 for the prototype). Reused from the Python bake:
`nature.py` objects (33 x 3 sizes x 4 seeds), `life.py` objects (42), goods objects (25). Every sprite keeps the bake's
conventions (2 px extruded border, anchor at the foot for upright pieces, the index with layer and sort offset).

## F. Mockup notes

Drawn by a scratch script (not stored in the repo) with pygame, from the Python game's Europe 1480 data for the frame
(terrain, owners, the data's rivers, roads, ridge edges, passes and cities), with the stand-ins listed in section 10. The
piece sheet builds a small map per piece and runs the same renderer, so each cell shows exactly what the library draws for
those sockets. Measured: close frame 1280 x 720 at radius 34, about 300 hexes on screen; the renderer draws every hex from
its sockets with no per-hex picture.
