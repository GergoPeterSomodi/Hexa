# Pieces in the map: the test

Art director, 2026-11-15. **Status: a test for the owner and the planning session. Nothing in the game, the style
frame or the pieces is changed.**

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
