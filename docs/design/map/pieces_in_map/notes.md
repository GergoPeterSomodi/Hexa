# Pieces in the map: the test

Art director, 2026-11-15. **Status: a test for the owner and the planning session. Nothing in the game, the style
frame or the pieces is changed.**

## Round 6: the families of the Python art (2026-11-15)

Review task 25 (`../pieces/REVIEW.md`, "Round 5"). Tasks 10 to 24 are back, so the test carries what fits north
Italy. All pictures are rendered again; three crops are new: `east_crop.png` (the lower Po plain and the
Apennines), `west_plain_crop.png` (Turin to Asti) and `carrara_crop.png` (the Apuan coast, four times enlarged).

| What | Where (column, row) | Level |
|---|---|---|
| Quarry | The Apuan Alps above Carrara (13, 15) | 3 |
| Hemp | South of Turin (5, 11); the lower Po (13, 9) | 2, 3 |
| Silk | By Turin (6, 9); Emilia (14, 10) | 3, 2 |
| Dye works | By Parma (13, 11) | 3 |
| Sites | A monastery in the Apennines (9, 11); Roman ruins at Luni (12, 15); a ruined castle on a pass (10, 12) | - |
| Ores | Iron (4, 13) and copper (3, 15) in the Maritime Alps | 3, 2 |
| Castles, three layouts | Giovi (9, 12): a watchtower, layout 0. The Col di Tenda (5, 14): motte and bailey, layout 2. Above Parma (13, 12): layout 1. The Susa valley (4, 9): the bastion fortress | 1, 2, 2, 3 |
| Third layouts | The contour vineyard (6, 11); the walled pastures (5, 12) and (11, 12) | 3, 3, 2 |

**Not placed, on purpose.** Furs (a northern forest good) and cotton (a hot-land good) have no place in north
Italy. None of the ten landmark cities lies in the frame; Genoa is a plain city.

- **No `PIECE PROBLEM`**, summer or winter. Rule K drops 57 range samples at footprints; nothing is hidden.
- **It still reads as one countryside**, and it is richer: the plain is no longer wheat only. Hemp's dark squares,
  the silk lines, the vats and the pale quarry are each told at a glance at 100%.
- **The sites sit best of all.** A monastery and a ruin in the frame's own dense wood look found, not placed.
- **Sites: the variant is the site.** The map gives `variant=` from its data and takes only the mirror from
  `kit.pick`. (The compositor loads the pieces' `sites.py` under another name: the style frame has a module of
  the same name.)
- **For the map's side:** the frame's road runs through the dye works' vat yard: roads are led to a town's
  middle but not yet to a goods piece's gate point (rule H wants a road layer that does). The motte at the Col
  di Tenda is a green mound on rock and both pass castles sit under their pass names (both known since round 3).
- **Winter:** the plain's hemp is outlined blocks in the frost (review task 29); the sheep in the snow pasture
  are seen now (the winter fleece).

## Round 5: the carved harbour is in (2026-11-15)

`harbour.py` has its carved layout and `salt.py` and `harbour.py` their second layouts (review task 9), so the
stand-in is gone: `compose.py` cuts Genoa's bay at the guide's width (`kit.BAY_WIDTH`, 72 px; it was 84).
All five pictures are rendered again.

- **Genoa:** the bay is 72 px wide with its horns inside the hex; the shore moved 13 px (4.2 km) to 18 px from
  the hex centre, 91 km2 of land turned to sea. The harbour is a closed basin: the quay on the back of the bay,
  two short moles across the mouth, the lighthouse on the west horn, ships and boats inside. No standing thing
  has its foot outside Genoa's hex. The owner's answer of this round allows a carved bay up to 5 km.
- **On the other shores** the run prints four `PIECE PROBLEM` lines (harbour level 1 and level 2, the level 2
  add-on, salt level 3): standing things outside the hex margin on curved, slanted shores. South of Pisa a wild
  tree stands between the two blocks of salt pans, and at Pisa's outport the long mole of harbour layout 1
  starts on land. Review task 24.
- The pictures differ from round 4's everywhere a family got its second layout since.

## Round 4: two port modes, winter by climate (2026-11-15)

The owner's two answers of round 3 of the pieces (`../pieces/REVIEW.md`, "Round 3"; guide sections 7 and 10).
`summer.png`, `winter.png` and the three crops are rendered again; `winter_crop.png` is new (the Po plain, the
Apennines and the coast, 2x).

**Ports**

| Port | Data | Mode | In the picture |
|---|---|---|---|
| Genoa | City, sea port | **Carved** | A bay cut into its hex: the shore moved 13 px (4.2 km) inland, to 18 px from the hex centre, just in front of the city wall. The level 3 add-on lies wholly inside the hex; its canvas moves 5 px (it was 18) |
| Savona, Nice | Towns, sea ports | Seaside | As before: the add-on anchored at the shore, 29 and 36 px from the hex centre, reaching into the sea hex |
| Chiavari | Village, sea port | Seaside | As before (28 px) |
| Pisa | City, no sea port in the data | Seaside | Its outport on the open shore, as before (34 px) |

- `port_mode()` is the rule: a place that is a city and a sea port in the data is carved; every other port is
  seaside. `carve_ports()` cuts the bay with the kit's shape (`kit.carve`) into the frame's land field, once,
  before the frame's trees and fields are built, and only inside the port's own hex.
- The town piece is clipped at the bay like at any shore (71 px of ground detail, one standing thing). An add-on
  thing is left out inside the town's footprint only where that is land: what stands on the water is the
  harbour's.
- **For now the bay is 84 px wide** (the hex's whole front), because the harbour has only its open-shore layout.
  With the carved layout of review task 9 it becomes the guide's 72 px, with two headlands inside the hex.
- The coast at Genoa now lies 6.8 km from the frame's first line (the frame's own cove rule is 3.5 km): an open
  question in the guide (section 12, point 1).

**Winter**

- `Climate` holds the kit's cold index (`kit.cold_index`: latitude, height, km to the sea) on the frame's km
  grid; the distance to the sea is an exact distance transform of the frame's land field.
- **Each piece takes the winter of its hex** (`Climate.of_hex`: the hex centre's latitude, the hex's mean height
  from the height data, the km from its centre to the sea): of the 44 piece hexes 6 are snow (the Alps, one high
  Apennine hex), 29 frost (the Po plain, the hills, the foothills) and 9 mild (every hex on the coast).
- **The stand-in ground follows the same index point by point**: the frame's ground is painted three times, in
  the three winter palettes, and laid over each other through the index with a soft edge, so the snow line runs
  along the mountains. Trees, hills and ranges, the frame's own field parcels and the rivers take the winter of
  the point they stand on (rivers and streams run open in the mild zone, streams are frozen elsewhere). The frost
  ground gets drifts of thin snow, as the kit's sheets show it.
- Seen: snow in the Alps and on the Apennine crest, a frosted Po plain with white roofs, a green-grey Riviera
  with red roofs, bare woods and laid-up boats. The three zones read at a glance. Still a stand-in, not a design
  of the winter map.
- Left for the map's side: a piece has one winter while the ground blends, so at a border a frosted piece can
  stand on half-green ground (the olives west of Savona); the mild zone's hills keep a little too much of their
  summer green; the salt pans south of Pisa are too blue in the mild winter (review task 9).

## Round 3: every family in the map (2026-11-15)

`summer.png`, `winter.png`, `plain_crop.png` and the new `hills_coast_crop.png` (the Alps to Genoa, 2x) now carry
all ten families, each on its own kind of land, with layout and mirror from the hex.

| Where | What |
|---|---|
| Po plain | Wheat, 8 hexes, levels 1 to 3, both layouts |
| Monferrato and Langhe hills | Vineyards, 4 hexes, levels 1 to 3 |
| Riviera di Ponente | Olives, levels 3 and 2 |
| Alpine and Apennine foothills | Grazing: sheep 3 and 1, cattle 2, horses 2 |
| Apennine woods | Timber, 4 hexes, levels 1 to 3: clearings cut into the map's own wood |
| Maritime Alps | Mines, levels 3 and 2 |
| Giovi, Col di Tenda, Susa valley | Castles 2, 1 and 3 |
| South of Pisa | Salt pans 3 |
| Two cliff coasts | Fishing villages (harbour 1 and 2, the full piece) |
| Genoa, Pisa, Savona, Nice, Chiavari | Town piece plus the harbour add-on (levels 3, 3, 2, 2, 1); the frame's own harbour stand-in is gone |

What the compositor learned to do, and what it means for the real map:

- **Coast families are left whole at the shore**: their jetties, moles and boats lie on the water. A hex with less
  land than the module's `NEED` takes a lower level; a hex without a shore takes no coast piece.
- **The harbour add-on is anchored at the shore, not at the hex centre.** The port hexes have 10 to 20 px of water;
  the canvas is moved 18 to 36 px towards the sea so the basin reaches into the sea hex next door. Add-on things
  inside the town's footprint are left out (1 to 2 per port).
- **Relief rule K, applied**: range samples in or up to 30 px in front of a footprint are dropped and the range is
  cut there (39 samples). Without it both mines and the Tenda tower are hidden behind peaks.
- With the map's own shore line a few standing things of the full coast pieces land outside their hex (2 to 3 per
  piece); they are left out. The kit's eight straight sides do not show this; wavy shores do.

Seen and left for the map's side: the pass name "Giovi" sits on the castle; the castle mound is grass green on
rock; the salt pans south of Pisa lie a little back from the water because the shore crosses only the hex's edge.

## Round 2: after the owner's answers (2026-11-15)

`summer.png`, `winter.png` and `plain_crop.png` were rendered again to the owner's three answers
(`../pieces/REVIEW.md`, section 6). The rest of this file is round 1 and is kept as the record; where it speaks of
plates, cleared hexes and repeats it describes the pictures before this round.

| Answer | What the compositor does now | Seen in the pictures |
|---|---|---|
| "No plates for now" | Draws no town name plate. Towns stand where they stood (the middle 6 px above the hex centre) | The 14 plates are gone; nothing covers rivers, harbours or the hexes below. River, pass and sea names stay |
| "Map draws shore" | Tells every piece where the map has the sea in its hex (`sea=` as an angle, `shore=` as a line: Nice 77, Savona 63, Genoa 90, Chiavari 90, Pisa 163 degrees). No piece draws sea; ground detail is clipped at the shore (4 hexes); a standing thing whose foot would be in the water is left out (1, at Nice). Ports keep the frame's own quay, moles, lighthouse and ships at their shore | Genoa, Savona, Chiavari, Nice and Pisa as before at the shore. The frame's harbour works are the stand-in for the harbour add-on, which `harbour.py` cannot draw yet (review task 4) |
| "Map + 2nd layout" | The frame's trees stay in a piece hex; only those with their foot in the piece's footprint are left out: 142 of the 355 trees in the 23 piece hexes (round 1 dropped all 355). Layout and mirror come from the hex (`kit.pick`): 13 of the 23 pieces are mirrored | Serravalle's hamlet stands in the wood with a small clearing instead of in a bald hex; the woods run up to Genoa's and Chiavari's houses. The two level 3 wheat hexes beside Pavia are no longer the same picture (one is mirrored) |

Still to come, and visible in the pictures: the wheat and settlement modules still draw their own wild trees (so
piece hexes on the plain carry a few trees too many) and their road stubs to the hex border (review task 5); there
is only one layout per family yet, so equal pictures still meet where the mirror does not differ (the level 2
wheat hexes); the hills inside a piece hex are still dropped whole (the map's relief rule, recommendation K).

The compositor now takes its pieces from `kit.take_apart` (it had a private route in round 1) and no longer writes
`base_kept_crop.png`.

## Round 1

The question: each piece is exactly one hex at the normal map's zoom, so can the map use them? The test puts the two
reference families (settlements, wheat) into the style frame's close zoom (hex radius 60, the Gulf of Genoa).

| File | What it shows |
|---|---|
| `summer.png` | The frame, 1280x720, same view as `../style-frame/style_frame_close.png`: all 14 places are settlement pieces, 9 hexes on the Po plain are wheat pieces |
| `winter.png` | The same in winter |
| `plain_crop.png` | The Po plain (Asti to Piacenza) from `summer.png`, enlarged 2x without smoothing |
| `base_kept_crop.png` | The same crop with the pieces' own ground base kept: why the base has to go |

Levels used: Genoa, Turin, Pavia 5; Pisa, Alessandria, Piacenza 4; Asti, Parma, Savona, Nice, Cuneo 3; Susa,
Chiavari 2; Serravalle 1. Wheat: two hexes at level 3, four at level 2, three at level 1, several of them touching
each other or a town.

Code: `tools/worldmap/pieces_in_map/compose.py` (run it with the frame's environment; it writes the four pictures and
prints the measurements). No file of the frame or of the pieces was edited, so the frame's own renders are unchanged.

## Verdict

**Yes, the pieces can be used in the map, and they look like part of it, not like stickers.** Houses, trees, walls and
shadows are the frame's own shapes and sizes, the light agrees, and no hex outline shows. Two conditions had to be met
to get there, and both need a small change to the kit:

1. **The piece's ground base must go.** With the base kept every piece hex shows as a flat coloured hexagon
   (`base_kept_crop.png`): the base is one colour, the map's ground is a blend of the neighbours. With the base
   dropped and only the ground detail (fields, plots, yards, tracks) laid on the map's ground, the border disappears.
2. **The standing things must be handed over one by one.** Each house, tree and wall joins the map's back-to-front
   list by its foot, so a piece's houses and a neighbour's trees and hills cover each other correctly (501 standing
   things in summer). A flat picture per hex cannot do this.

The problems that remain are not in the look of the pieces. They are at the joins with the map's other layers: name
plates, coasts, rivers and roads, mountains, and repetition. They are listed below with numbers.

## How the compositor works

- A hex with a piece loses the frame's own town, field parcels, trees and rounded hills (here 151 parcels, 355 trees
  and 65 hills), so nothing is drawn twice. Ranges, rivers, roads, the coast and names stay: they are other layers.
- The piece's ground detail is feathered at the hex border as the kit does, clipped to the land, and laid on the
  frame's ground **under** the rivers and roads. The piece's soft shadows go into the frame's one shadow pass.
- A town stands at the middle of its piece (6 px above the hex centre); the frame's roads are led there and its trees,
  hills and fields are built again round the new sites. Genoa, Savona and Chiavari keep the road lines they share with
  the close-up.
- The name plate goes where the guide says: the strip from 26 px below the hex centre.
- A port keeps the frame's quay, moles, lighthouse and ships, at the shore.
- **Winter is a stand-in.** The frame has no winter. The compositor paints the frame's ground with the pieces' winter
  palette, draws bare broadleaves and snowed conifers as the kit does, and turns the green of hills and wooded ranges
  to snow. It is good enough to judge the pieces on snow; it is not a design for the winter map.

## What works

- **No hex outline, no seam.** Neither round a single piece nor between touching pieces (the wheat hexes west and east
  of Pavia, wheat next to Asti and Turin).
- **Scale.** Piece trees and houses are the same size as the frame's. The windmill (17 px) and the cathedral stand
  clear above the frame's rounded hills (5-12 px) and well below its ranges.
- **Reading.** The five settlement levels are told apart on the map at a glance (Serravalle, Susa, Asti,
  Alessandria, Pavia). Wheat levels 1, 2 and 3 are told apart too. The gold blocks carry further than the frame's own
  small parcels.
- **Winter.** The wheat strips read well on snow (the one earth strip in four does the work). Walls, plaster and the
  trodden ground keep the towns readable, though weaker than in summer (see 9).
- **Drawing technique.** The kit draws at 2x and scales down (soft edges, 0.5 px ink); the frame draws at 1x with hard
  1 px lines. At 100% the difference is not noticeable; at 3x the pieces are a little softer. No change needed now.

## What does not work yet

1. **Name plates do not fit the plate strip.** All 14 plates cross the hex border when they start 26 px below the
   centre: by 2.7 px (Asti) to 14.3 px (Alessandria); the four cities by 9.5-13.3 px. The hex narrows to a point
   there. A 23 px tall city plate fits inside the hex only if it starts about **10 px** below the centre, but a level 5
   city's front wall stands at +14.5 and its suburbs reach +22. On the map the plates of Pavia, Asti and Parma lie on
   rivers and on the trees of the hexes below.
2. **Coasts.** A piece assumes a whole land hex with the place in the middle. Four settlement hexes have sea in them.
   Savona's piece stands in the middle of its hex, about 50 px from its own quay on the shore; Genoa's plate covers its harbour (the frame's rule puts a
   port's plate on the land side); Nice has one standing thing with its foot in the water; ground detail had to be clipped at
   the shore in four hexes. The sea lies south-east of Savona, east of Nice and west of Pisa: a piece that draws its
   own sea on the south side will not meet the map's coast.
3. **Rivers.** The map's rivers run along the hex borders, wandering a few px to either side. Pieces work the ground right up to the
   border. The level 3 wheat piece's front block, its sheaves and a reaper lie in the Po in both level 3 hexes. The
   level 3 canal has the same blue as the map's streams and stops dead at both hex borders.
4. **Roads.** The piece's own road stubs end at the hex border where no map road goes on (the south stub runs under
   the plate into nothing). Where a map road does arrive, it does not use them: east of Asti the stub and the map's road
   run side by side as two roads. The map's road enters the ring wall wherever it comes from, not
   at a gate.
5. **Mountains and hills.** Pieces are flat-land pictures. The frame's ranges stay, so: a peak stands in front of
   Cuneo and hides half the town; Susa's village sits on scree under the Mont Cenis crest (its hex is a 3,320 m peak
   hex, a known data problem); a spur lies across the fields of the wheat hex south of Parma. Dropping the rounded
   hills inside piece hexes leaves those hexes flatter than their neighbours.
6. **Repetition.** Two wheat hexes of the same level are the same picture. Pavia has the same windmill, the same three
   poplars and the same canal on both sides; the level 2 hexes repeat as well. It reads as copy and paste.
7. **Two field scales.** A piece's field block is 36 x 26 px with 4 px strips; the frame's own parcels are about
   10 x 4 px. Where both show, the frame's look like another map. The pieces' scale is the better one.
8. **Clearing the whole hex.** The compositor removes every map tree in a piece hex and the piece brings its own
   fixed scatter. On the plain this is invisible. In wooded hexes (Serravalle, Genoa, Chiavari) the wood ends along
   the hex border, and a hamlet of three huts sits in a bald hex.
9. **Settlements in winter.** With full snow roofs the red signature is gone; a town reads as a pale beige disc. It is
   still found, mostly through the plate.
10. **Ground detail assumes the piece's own ground colour.** The trodden ground, tracks and scrub patches are opaque
    mixes with the piece's base colour. On another terrain (Susa and Cuneo on stone, Genoa on woodland ground) they
    are slightly off. Small, but it will show more with the rock and sand families.

## Recommended changes (for the planning session to decide; none is made)

**Kit**

- A. **Layers instead of one flat picture.** Add to the contract a way to get a piece as layers: the ground detail
  without the base, the shadow layer, and the list of standing things with the y of their foot. For example
  `draw(level, season, base=False)` and `Piece.layers()`. The test gets them by subclassing `Piece`; the kit should
  offer it. The flat 112x112 picture stays for the sheets.
- B. **Ground detail as overlays.** Trodden ground, tracks and scrub should be drawn half-transparent over whatever
  ground is there, not as opaque mixes with the base colour (problem 10).
- C. **Layout variants.** A `variant` argument: mirrored layout tables (x to -x, with the light kept from the left)
  and two or three layouts per family, chosen by the hex's coordinates (problem 6).
- D. **The coast comes from the map.** `p.coast()` should take the map's shore for that hex (a land mask or a shore
  line and a side), not draw its own sea on the south side. Needed by salt, harbour and every coastal settlement
  (problem 2).

**Guide**

- E. **Section 1, ground base:** say that on the map the base is not drawn; it exists for the sheets only.
- F. **Section 1, safe area for ground work:** no fields, plots, canals or activity details within 10 px of the hex
  border, so a border river or road never cuts through worked ground (problem 3). Today only standing things have a
  margin (3 px).
- G. **Name plate:** choose one.
  - G1 (recommended): the plate strip starts 10 px below the centre. The settlement's middle moves up about 8 px and
    the level 4 and 5 rings shrink (rx 38 to about 33, ry 20.5 to about 17) so the gate clears the plate.
  - G2: keep the pieces; allow the plate to hang over the hex's south point. It then covers whatever lies in the two
    hexes below, which the frame's one-hex rule forbids.
  - G3: smaller plates at this zoom.
- H. **Roads, section 10:** a piece draws no road to the hex border. It names its gate points (south, east, west) and
  the map's road layer connects them. Inside the yard or ring it may keep its lane (problem 4).
- I. **Canal, wheat level 3:** end the canal in a pond inside the hex, or draw it only when the map has a river on
  that hex (problem 3).
- J. **Wild scatter, section 6:** the terrain's own trees come from the map, thinned by the piece's footprint (one
  ellipse per level, listed in the family table), not from the piece. Level 0 is then no piece at all (problem 8).
  This is the largest change and touches every family; decide it before the other families are finished.
- K. **Relief, section 10:** state the map's duty: no range, spur or hill may stand inside or in front of a piece's
  footprint, and a hex that is all peak takes no piece. Families for hill ground (vineyard, olives, mines) should
  keep their footprint to the lower half of the hex (problem 5).
- L. **Ports:** owner question 3 in the guide (a settlement and a good in one hex) has to be answered for ports first:
  Genoa is a city and a harbour. Either a settlement piece takes a `coast side` and stands at the shore with the
  harbour drawn round it, or the harbour is an overlay family (problem 2).
- M. **Settlement roofs in winter:** keep the shaded roof side in the roof colour, or a 1 px eave line, so the red
  cluster survives the snow (problem 9).
- N. **Fields:** once pieces are in, the map draws no field parcels of its own (problem 7).

## Limits of this test

- Only two families were tested; the others were still being drawn.
- The frame is drawn without the slope rule, like the checked-in close frame. With slope shading the pieces' flat
  field colours would need the slope tone too.
- The winter map is a stand-in (see above); the high Alps keep some bare stone that a real winter map would not.
- The towns were moved to the middle of their hexes for this test only. Nothing was written back to the frame.
