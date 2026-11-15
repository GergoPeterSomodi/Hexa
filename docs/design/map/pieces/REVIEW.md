# Normal-map pieces: the review

Art director, 2026-11-15. **Status: the owner answered the three questions on 2026-11-15 (section 6). All six fix
tasks are done and reviewed a second time: all ten families pass ("Round 2" below). Round 3 (the same day) adds
the owner's two further answers, two port modes and winter by climate, to the kit, the guide and the in-map test,
and writes task 9. Round 4 (the same day): task 9 is back, the owner picked the Python art to bring over (the
catalogue's top 10) and answered the two port questions; the guide has the tables, the kit the tools, and section 4
the worker tasks 10 to 25. Nothing in the game is changed.**

All ten families are drawn. This is the review of the eight new ones against `GUIDE.md` (the two reference
families were checked again too), with the findings of the in-map test (`../pieces_in_map/notes.md`) folded in.

**Look at `overview.png` first**: every family and every level on one page (summer on top, six families in winter
below). The per-family sheets (`<family>.png`) show all four seasons and the 50% test. `kit_contract.png` shows what
the owner's answers mean in the kit: wild land, the coast on any side, the footprint, the mirror.

## Round 4: the Python art, the port answers (2026-11-15)

| | The owner's answer | What was done |
|---|---|---|
| Python art (`../python_art/catalogue.md`) | **"Top 10 (Recommended)."** | Guide section 8 has the tables, written in one pass so the signatures cannot collide: Quarry, Dye works, Hemp, Cotton, Silk, Furs, Sites; the four ores (`ore=`); the ten landmark cities (`landmark=`, levels 4-5); the third layouts of vineyard, grazing and castles. Section 4 has the new tokens, the seven new signatures and a table of the pairs that crowd each other with the rule that keeps each apart. Tasks 10 to 25 below |
| The carved bay | **Up to 5 km, carved ports only; the cove limit stays 3.5 km.** | Guide section 10. `kit.BAY_REACH` was 19 px (5 km) already; `kit.COVE_REACH` = 13.3 px is new, for the map |
| A port's mode | **Fixed by the map data: carved from the start; the coast never changes in play.** | Guide section 10 |

**Show the owner:** `../pieces_in_map/summer.png` and `winter.png` (Genoa's harbour is now the carved one: the
guide's bay of 72 px with its horns inside the hex, the quay on the back of the bay, two short moles across the
mouth, the lighthouse on the west horn; nothing stands outside Genoa's hex), `ports.png`, and `kit_additions.png`
(the new kit calls and colours; demonstrations, not designs).

### The art director's calls (guide section 12 has them; the owner may overrule any)

- **The iron furnace glows**: one `GLOW` spot of 2 x 2 px, iron level 3. With the lighthouse lamp it is one of two
  lights on the map; no more.
- **Gold has no fort**; its top landmark is a strongroom. **The fur post's stockade is square and open to the
  front.** Both so that nothing but a castle reads as a castle.
- **Hemp against spring wheat**: near-square blocks of at most two strips, bare earth with dashed rows in spring,
  the darkest green in summer, always a pond.
- **Furs against timber**: no stumps, piles, mound or mill; coverage bands of its own (10-20 / 20-35 / 35-50%).
- The mint has a slate roof (no red in mines). Cotton's strongest season is autumn. Cattle take the sheep's
  walled pastures in the third grazing layout.
- **Venice** is drawn for now as a city at a lagoon shore with its monument; the town on islands is an open
  design question (guide section 12, point 1).

### Kit, guide and tool changes in this round

All 1,754 pictures of the ten modules (every level, season, layout and mirror; grazing's three animals; the two
coast modules on four sea sides, in a bay of 8, 13 and 19 px and as the add-on; every top picture in the frost and
mild winters) and `kit.pick` for one and two layouts on 144 hexes are **equal before and after**, hash for hash.

| Change | What it is for |
|---|---|
| `p.drystone(pts, closed=)` | The dry-stone field wall (grazing's third layout, the monastery's wall) |
| `p.ring(cx, cy, rx, ry=, kind="fence" / "stone", gate=, claim=)` | The round paddock and the round sheepfold; claims its inside |
| `p.arc(cx, cy, rx, ry, a0, a1, col=, lw=, dashed=)` | A curved plant row (vineyard's contour layout) |
| `p.tree(..., "mulberry")` | Silk's pollarded trees |
| Crops `hemp`, `hemp_row`, `cotton_soil`, `cotton`, `mulberry_soil`, each with the frost and mild winters | The new crop families |
| Tokens `MARBLE`, `PIT`, `DYE`, `RET`, `BOLL`, `DOME_TILE`, `PELT`, `GLOW`, `VERDIGRIS`, `ORES`, `BRICK`, `LEAD`, `GILT`, `ONION` (guide section 4) | One place for the new signature colours, so two workers cannot pick the same |
| `kit.pick(col, row, 3)`: with three layouts or more each of the grid's three classes shows its own layout, plain or mirrored by the hash | Third layouts. One and two layouts answer as before |
| `kit.COVE_REACH` | The 3.5 km limit, beside `BAY_REACH` |
| `tools/worldmap/pieces/additions.py` writes `kit_additions.png` | The new calls in four seasons and three winters, the token swatches, `pick` with three layouts |
| `compose.py`: `BAY_WIDTH = kit.BAY_WIDTH` (was 84 px for the stand-in) | Genoa's bay is the guide's now that `harbour.py` has its carved layout |
| `winters.py`: the stale line under `ports.png` | - |

`overview.py`, `winters.py`, `contract.py` and `compose.py` were run again; `overview.png`, `winters.png`,
`ports.png`, `kit_contract.png` and the five in-map pictures are new.

### What the in-map test showed (task 9 in the map)

- **Genoa, carved: good.** A closed basin inside the city's own hex, the lighthouse on the west horn, the wall
  dry. In winter (mild there) the boats are laid up and nothing is white.
- **Four `PIECE PROBLEM` lines on the map's real shores**, all on seaside hexes and all from standing things
  outside the hex margin: harbour level 1 (6 px, hex 5,15), harbour level 2 (15 px, hex 10,13), the level 2 add-on
  (9 px) and **salt level 3 (159 px, hex 13,17, layout 1 mirrored)**. The sheets' straight shores do not show
  them; the map's slanted, curved ones do.
- **Salt, layout 1, south of Pisa:** a wild tree stands between the two blocks of pans (the feeder channel's
  strip is not footprint), and the channel and the pans lie well back from a shore that bends away.
- **Pisa's outport, layout 1:** on that west-facing, curved shore the long mole starts on land and the short
  spur lies across the beach; the lighthouse stands free in the water at the mole's head.
- These are for task 24 (below). Nothing else in the map changed in kind; the pictures differ from round 3's
  everywhere because the second layouts of salt, harbour, olives, mines, settlements and castles are in.

## Round 3: ports in two modes, winter by climate (2026-11-15)

The owner answered the two questions of round 2 and asked for one thing more:

| | The owner's answer | What was done |
|---|---|---|
| Ports | **"Some to carve a port to the tile, and some will need just to add a port to the seaside."** | Two port modes. **Carved**: the map cuts a bay into the port's own hex and the harbour sits in it. **Seaside**: the add-on at the shore as it is. The rule, the bay's shape and its limits: guide section 10. Kit: `kit.carve`, `Piece(bay=)`, `shore.bay`. In the map: Genoa carved, Savona, Nice, Chiavari and Pisa's outport seaside |
| Winter | **"Not all of the map gets snowed. For example south Italy doesn't get that much snow. Might need some in between tiles?"** | Three winters by climate: **snow**, **frost** (the in-between) and **mild**. One rule from latitude, height and distance to the sea: guide section 7. Kit: `take_apart(climate=)`, `kit.winter_of`. No module is called differently |

**Show the owner:** `winters.png` (every family's wild land and top level in the three winters), `ports.png` (the
harbour and the salt pans on an open shore and in a bay), then `../pieces_in_map/winter.png` and `winter_crop.png`
(snow in the Alps and the high Apennines, frost on the Po plain and the hills, the Ligurian coast mild) and
`summer.png` (Genoa's harbour in its bay, inside its own hex).

### What was seen

- **The three winters read at a glance**, on the sheet and in the map, at 100% and 50%: white, pale grey-green
  with snow patches, dull green with red roofs. The frost winter differs from the snow winter by the ground, not
  by the buildings (roofs carry snow in both); that is enough, and it keeps the two from fighting.
- **No module needed a new call.** One line was added to `grazing.py` (a meadow colour for a winter without snow:
  its own colour table had no winter entry). Everything else comes from the kit: the palette, the crops, bare
  trees without snow, open water.
- **The mild winter is still winter**: bare broadleaves and vines, boats laid up, smoke, few animals. It is told
  from autumn by the bare trees and the dark earth.
- **The carved harbour fits its hex.** Genoa's bay moves the shore 13 px (4.2 km) to 18 px from the hex centre,
  just in front of the city wall; the level 3 add-on then lies wholly inside the hex (no standing thing outside
  it; before, the canvas was pushed 18 px into the sea hex). The town piece is clipped at the bay like at any
  shore (71 px of ground detail, one standing thing).
- **For now Genoa's bay is 84 px wide**, the hex's whole front, because `harbour.py` has only its open-shore
  layout (64 px from mole to mole). The bay of the guide is 72 px with its two horns inside the hex; it needs the
  carved layout of task 9.
- Weak spots, all for task 9 or a small later sweep (below): in a mild winter the salt pans are a strong blue
  (the safety net's open-water colour); the olive shelves are a little muddy; the timber raft is still gone.

### Old lines to move from the season to the snow (a small sweep, no layout change)

The kit's safety net covers them, so nothing is wrong on the map today:

| Module | Line | Change |
|---|---|---|
| `salt.py` | `pan_col` returns `kit.ICE` for winter; the channel is `kit.ICE if wi` | Frozen only `if p.frozen`; in a mild winter the pans are filled as in spring (task 9) |
| `olives.py` | `if wi:` mixes the shelves' soil with snow | `if p.winter:` |
| `vineyard.py` | `if wi:` makes the snow strips | `if p.winter:` for the snow strips; the mild winter keeps the soil block with bare stakes |
| `timber.py` | `if not wi:` the raft | `if not p.frozen:` (the pond is open in a mild winter) |

### Kit, guide and tool changes in this round

All 650 pictures of the ten modules (every level, season, layout and mirror, and the coast modules on three more
sea sides) are **pixel-equal** before and after the kit change; the default winter is the snow winter.

| Change | What it is for |
|---|---|
| `kit.CLIMATES`, `kit.WINTER[climate]`, `kit.WINTER_CROPS`, `kit.climate(name)` (a `with` block), `take_apart(climate=)`, `with_wild(climate=)`, `wild(climate=)`, `backdrop(climate=)` | The three winters. `kit.crop(name, "winter")` and `p.pal` follow the hex's winter |
| `p.winter` now means "snow lies" (snow and frost); new `p.frozen`, `p.climate`, `p.cold` | What a module asks before drawing snow or ice |
| `kit.cold_index(lat, m, sea)`, `kit.winter_of(lat, m, sea)`, `kit.MILD_BELOW`, `kit.SNOW_FROM` | The rule: which hex has which winter |
| Trees: bare without the snow dab, a brown bush, in a mild winter; frost ground mottled with snow patches | The kit's own primitives in the new winters |
| `kit.carve(sea, shore, bay)`, `kit.bay_profile`, `kit.BAY_WIDTH`, `BAY_BACK`, `BAY_REACH` | The bay's shape, for the map to cut |
| `Piece(bay=)`, `take_apart(bay=)`, `with_wild(bay=)`, `shore.bay` (a `kit.Bay`: `u0`, `west`, `east`, `pt`, `room`, `uv`) | The piece in a carved port; on the sheets the kit carves the stand-in shore |
| `tools/worldmap/pieces/winters.py` writes `winters.png` and `ports.png` | The two contract sheets of this round |
| `grazing.py`: `MEADOW["winter"]` | The one module line (a meadow colour for the mild winter) |

`compose.py`: `port_mode()`, `carve_ports()`, the `Climate` field (the rule on the frame's km grid), the stand-in
winter ground in three palettes laid over each other through the cold index, and trees, hills, parcels and rivers
by the same index. See `../pieces_in_map/notes.md`, round 4.

## Round 2: the second review (2026-11-15)

Fix tasks 3 to 6 are back. Every sheet (family, variants, sides) was looked at whole and in enlarged crops, each
family was measured (footprint, the 10 px margin, all eight sea sides) and checked against the guide's checklist.
**All ten families pass.** No module prints a `PIECE PROBLEM`, plain or mirrored, on any sea side. The owner's three
answers are now true in every module: no wild land in a piece, the shore from the map, a mirror for all and a second
layout for wheat, grazing, timber and vineyard.

**Show the owner:** `overview.png` (summer, eight families in winter, and a bottom block with layouts, sea sides and
the port add-on), then `../pieces_in_map/summer.png`, `hills_coast_crop.png`, `plain_crop.png` and `winter.png`.

### Verdict per family

| Family | Verdict | Coverage (share of the margin hex, levels up) | Notes |
|---|---|---|---|
| Settlements | **Pass** | 27 / 41 / 66 / 75 / 84% | Roads end at gates, no plate strip. The village green stays. The inside of the ring is now footprint by the kit, so no map tree stands on the wall |
| Wheat | **Pass, after one fix** | 29 / 57 / 82% (layout 1: 31 / 56 / 85%) | Layout 0's four corner blocks poked up to 9 px into the margin (the Po problem of round 1), not 2-5 px: pulled in. The fullest family, on purpose. Sails over a field edge in layout 1 are fine (a mill stands among its fields) |
| Castles | **Pass** | 20 / 31 / 70% | The keep's smoke keeps its side in the mirror: right. The court of the ring is claimed for the footprint |
| Vineyard | **Pass, after one fix** | 21 / 47 / 62% (66%) | The gate point lay 7 px from the border: moved to 10. Presses of the two layouts 11 px apart: accepted, the 14 px rule is for the yard (the hut), which is 37 px away |
| Olives | **Pass** | 22 / 51 / 70% | The clearest signature. One layout so far |
| Grazing | **Pass, after the kit fix** | 17 / 34 / 61% (66%) | Sheep read as grey smudges: the kit's sheep is redrawn (below). Level 2 is at the low edge of its band; accepted, the pale meadow carries |
| Salt | **Pass** | 20 / 38 / 62% | Works on all eight sides. On slanted shores one back-row corner comes 3 px into the margin: accepted |
| Mines | **Pass, after one fix** | 27 / 53 / 68% | The stream ran border to border (missed in round 1 and by the task): now a short wheel race with a pond at each end. Spring = summer by the guide. The one `p.m` aims the headframe's stay at the shaft house: allowed (guide) |
| Timber | **Pass** | 26 / 45 / 71% | Level 3 a little over the table's 65%: inside the band. The irregular clearing reads as a clearing, not a disc |
| Harbour | **Pass, after one fix** | 17 / 31 / 44% of the land side | The worker turned the whole layout round where the lighthouse did not fit; that cancelled the mirror on five sides and failed with the sea in the north. Replaced by the kit's fit calls (below): now all eight sides work, mirrored differs from plain, the lighthouse is there on every side |

### The workers' open points, decided

| Point | Decision |
|---|---|
| Footprint target: whole hex or margin hex? | **The margin hex** (the hex pulled in 10 px). Bands 15-30 / 35-60 / 60-85%. Guide section 6 |
| Wheat layout 0 blocks past the margin | Fixed in the table (blocks pulled in and slightly smaller); the look holds |
| Wheat farmyard blob, settlements' village green and wider ring blob | Pass. The ring blob is no longer needed for clearing: the kit claims the ring |
| Ring wall footprint was only a foot band | Kit: `p.claim(points)`; `p.wall` claims its inside; castles' own ring calls it |
| Vineyard gate outside the margin | Fixed: (-5, 38) |
| `GATES` per module, not per layout | Kept as the rule (all four two-layout families end at one gate). `kit.mirror_gates(GATES, mirror, variant)` also takes a list with one dict per layout |
| Mirror needs `x=` for structures of several parts | Into the guide (section 6) with the `on=` rule beside it |
| Sheep read grey | Kit: no outline, a clean pale body with a dark belly line and head, 3.4 x 2.4 |
| Harbour: sea N fails at level 3; the flip cancels the mirror | Kit: `shore.fits`, `shore.fit`, `shore.first`. Ships slide towards the shore until their sails fit; the lighthouse takes the first spot with room (mole bend, other mole bend, mole roots, land). The flip is gone |
| Boat size 0.7 against the guide's 0.55 | 0.7 is right for a fishing boat; 0.55 is the small boat on the beach. Guide and kit text changed |
| Salt coverage low | In the band on the margin hex (20 / 38 / 62%) |
| Salt's own `at` and `quad` | Now in the kit as `shore.at` and `shore.rect` |
| Mines: moss and snow patches gone | Pass |

### Kit, guide and tool changes in this round

- `kit.py`: the sheep; `Shore.at`, `rect`, `fits`, `fit`, `first`; `Piece.claim` and the ring wall's claim;
  `mirror_gates(..., variant)`. Sheets that changed for it: grazing (sheep), settlements and castles in the kit
  contract's footprint row. Everything else is pixel-equal apart from the module fixes named above.
- `GUIDE.md`: coverage on the margin hex with bands; the margin for corners and on the water; `x=`, `on=` and `p.m`
  in the mirror; boat and sheep sizes; tall things on a coast (the fit calls); all eight sea sides in the checklist;
  the add-on anchored at the shore; the mine's wheel race.
- `overview.py` shows every piece in its wild land, eight winter rows and a bottom block (layouts and mirror for
  wheat and grazing; harbour and salt on four sea sides; the add-on). `contract.py` re-run.
- `compose.py` (the in-map test) now places **every family**: see `../pieces_in_map/notes.md`, round 3.

### What the in-map test showed this time

Vineyards and olives on the hills, grazing and timber in the foothills, two mines in the Alps, castles at Giovi, at
the Col di Tenda and in the Susa valley, salt south of Pisa, two fishing villages, and Genoa, Pisa, Savona, Nice and
Chiavari as town plus harbour add-on. It reads as one countryside; no family looks pasted on. Four things for the
map's side:

1. **A port's hex has too little water** (10-20 px; the basin needs about 25). The add-on is therefore anchored at
   the shore, not at the hex centre, and reaches into the sea hex next door. Recommended as the rule.
2. **Mountains hide pieces.** Relief rule K had to be applied for real: range samples in or up to 30 px in front of
   a footprint are dropped (39 of them), or both mines and the Tenda tower vanish behind peaks.
3. **Pass names sit on the castle** (Giovi). Names and pieces need one placing rule when names are designed.
4. **The castle mound is grass green** also on rock. A mound should take the map's ground colour (a kit change for
   the next round: the mound as an overlay).

### Remaining work, for a later round

- Second layouts for olives, salt, mines, harbour, settlements and castles (on the 5 x 4 blocks of the variants
  sheets these six still show mirror-only repeats; salt and harbour most of all).
- Castle mound and settlement green as ground overlays (point 4 above).
- Grazing level 2: one more small paddock would lift it from 34% into the middle of its band.
- A water depth per level for coast modules (`REACH`, beside `NEED`), so the map can tell a full harbour from a
  jetty before it draws.
- Stronger spring ground tone (still open from round 1), tried on the map.
- Vineyard layout 1 and timber: a few px of ground overlay inside the margin at one corner (15 and 27 px of area):
  trim when the modules are next opened.

## Verdict in one paragraph (round 1, kept as the record)

The families are one hand: the same ink, light, house and tree sizes, and each has its own colour and pattern. No
piece leaves the hex (the kit's check prints nothing for all 192 pieces). **Five families pass with small fixes, five
need a real fix**, and none needs a redraw. The two weakest are grazing (its signature is too faint) and mines (the
low levels look alike). The in-map test showed the pieces work on the map once they are taken apart into layers; its
problems are at the joins (borders, roads, coast, name plates), and they turn into a few rules that every family
must now follow (section 3).

## 1. Verdict per family

| Family | Verdict | Why |
|---|---|---|
| Settlements (reference) | **Fix (rules only)** | The art is the bar. Its roads run to the hex border (new rule H). The plate strip is dropped (owner answer 1) |
| Wheat (reference) | **Fix (rules only)** | The canal runs border to border, the front block lies within 10 px of the border (it lay in the Po in the map test), the track runs to the border |
| Castles | **Pass, small fixes** | The three levels read at once, also at 50%, and never look like a town. Banner tip 1.5 px too tall, moat too bright, a few private kit calls |
| Vineyard | **Fix** | Rows and autumn red are a strong signature. The estate (pale wall, red cone tower) reads as a church, and with three red roofs level 3 reads as a village among fields at 50% |
| Olives | **Pass, small fixes** | The clearest new family: the tree grid on pale shelves reads at every size. Level 0 scrub is five ruled stripes; winter soil stays summer-ochre |
| Grazing (3 animals) | **Fix** | The weakest. The meadow has almost the ground's colour and covers about 25% at level 3 (should be about 70%); sheep nearly vanish; levels 0 and 1 are the same picture at 50% |
| Salt pans | **Pass, small fixes** | Strong signature (white grid on sand). Winter is now snowy (kit palette fix). Level 1 is thin next to level 0 |
| Mines | **Fix** | Headframe and smelter are good landmarks. Levels 0 and 1 differ by one hut and a line; spoil heaps look like the boulders; level 3 covers about a third of the hex |
| Timber | **Pass, small fixes** | Clearing, stumps and the charcoal mound read well; the wood thins from the front as asked. Level 3 is at the clutter limit; uses a private kit call for smoke |
| Harbour | **Fix** | Jetty, quay, warehouses and the striped lighthouse are good. The two moles are short posts at the hex edge and half faded: there is no basin, so level 3 is "level 2 plus a lighthouse" |

Checklist lines that every family passes: one module, one seed, one ground; camera and light; ink never black or
thicker than 1 px; nothing moves between levels or seasons; still water frozen and the sea open in winter; no banner
and at most three houses in goods pieces (harbour's three warehouses are the table's).

## 2. Across the families

- **Look-alikes at 50%.** None between families on colour or pattern. Two landmark clashes: the vineyard estate
  against the church (fix in task 2), and the olive oil mill's slate roof against the mine smelter's (accepted: the
  grounds differ completely; the mill keeps slate so olives do not get a third red roof).
- **One hand.** Yes. The only drift: the mine outcrop and boulders carry a heavier, darker outline than the rest
  (task 1), and the castle moat and salt feeder channel use the full river blue, brighter than the sea (task 1, 4).
- **Spring against summer.** Told apart only where a crop changes colour (wheat, vineyard). On grass, rock and sand
  the two seasons differ by a few points of green; mines are identical by the palette. This is a palette matter, not
  a drawing fault, so it is not sent back to the families. Proposal for the planning session: one stronger spring
  ground tone in the kit (one line, all families), tried in the map test before anyone signs it off.
- **Winter.** Settlements lost their red on snow (map test, problem 9). Fixed in the kit: snow roofs now keep a 1 px
  band of the roof colour at the eave, and winter smoke is grey so it shows on snow.
- **Level 0.** Every family draws a believable wild hex, but six of the ten are "grass with bushes" and cannot be
  told apart. That is correct (they are the same terrain), and it was the reason for owner question 3. Answered:
  level 0 is no piece; the sheets show the kit's wild land there.

## 3. What the in-map test changes

Already done (kit and guide; the sheets look the same unless listed in section 5):

| | Change | Where |
|---|---|---|
| A | A piece can be taken apart into layers for the map: `kit.take_apart(draw, level, season)` gives the ground detail without the base, the shadow layer, and each standing thing with its foot. Works with every module as it is | kit, tools README |
| B | Changes of the ground itself (scrub, trodden or cleared ground, tracks) are half-transparent overlays: `p.scrub`, `p.blob(alpha=)`, `p.over`; tracks are overlays already | kit, guide section 1 |
| E | The ground base is for the sheets only; the map does not draw it | guide section 1 |
| F | No worked ground or activity detail within 10 px of the hex border | guide sections 1 and 11 |
| H | No road or track to the hex border; a piece names its gate points and the map's road layer joins them | guide sections 10 and 11 |
| I | The wheat canal ends in a pond at each end, inside the hex | guide section 8 (the drawing follows in task 5) |
| M | Snow roofs keep a roof-colour eave band | kit, guide section 7 |

Done after the owner's answers (kit, guide and the in-map test; section 5 has the kit list):

| | Change | Where |
|---|---|---|
| G | **No name plates** on the normal map for now; no plate strip in the settlement pieces; the town stays where it was | guide sections 8, 11, 12; `compose.py` |
| D, L | **The map owns the shore.** A coast piece is told the sea side and the shore line and builds there in shore coordinates; on the map the kit draws no sea. A port is a town plus the harbour add-on at the hex's own shore | kit (`coast`, `Shore`), guide sections 8 and 10 |
| J | **The map draws the wild land.** Level 0 is no piece (`take_apart` returns `None`); on the sheets level 0 is `kit.wild()`. Each piece reports its footprint and the map thins its trees there instead of clearing the hex | kit (`footprint`, `wild`, `with_wild`), guide section 6, `compose.py` |
| C | **Mirror and second layout**, chosen by the hex with `kit.pick(col, row)`. The mirror works for every module today, with the light kept from the upper left; second layouts are tasks 3, 5 and 6 | kit (`mirror=`, `pick`, `variant_sheet`), guide section 6 |

For the planning session, not made (the map's side, for when the real map is built):

- **K, relief.** No range, spur or hill inside or in front of a piece's footprint; an all-peak hex takes no piece.
  The footprint mask now says exactly where that is. Recommended as stated in the test notes.
- **N, fields.** Once pieces are in, the map draws no field parcels of its own. Recommended.
- **Wild land.** The map keeps its trees and scrub in a piece hex and drops those whose foot lies in the footprint
  (`kit.in_footprint`). The wild land must be the same at every level and season.
- **Shore.** The map hands `sea=` and `shore=` to every piece of a coastal hex, clips ground detail at the shore
  and leaves out standing things whose foot is in the water. Each coast module lists the land depth its levels
  need (`NEED`); a hex with less takes a lower level.
- **Ports.** Town piece first, then the harbour add-on at the shore; add-on things inside the town's footprint are
  left out.
- **Names.** No plates. Where town names show at this zoom is open (guide section 12, point 7).

## 4. Fix tasks

Six tasks. **All six are done** (tasks 3 to 6 came back and were reviewed in round 2, above). The briefs are kept
as the record:

| Task | Files | What |
|---|---|---|
| 1 (done) | `castles.py`, `mines.py` | The first fixes |
| 2 (done) | `vineyard.py`, `olives.py` | The first fixes |
| 3 | `grazing.py`, `timber.py` | The first fixes, the wild-land rules, **second layouts for both** |
| 4 | `salt.py`, `harbour.py` | The first fixes, the wild-land rules, **the coast contract**, the harbour add-on |
| 5 | `wheat.py`, `settlements.py` | The rule fixes, the wild-land rules, **wheat's second layout**; settlements: roads to gates, no plate strip |
| 6 | `vineyard.py`, `castles.py`, `mines.py`, `olives.py` | **Vineyard's second layout**; the wild-land rules and the mirror check for all four |
| 9 (done, round 3) | `salt.py`, `harbour.py` | **Second layouts for both, the carved port in `harbour.py`**, salt on a lagoon, the three winters. Follow-ups from the map: task 24 |
| 10 to 25 (open, round 4) | one module each | **The Python art**: six new families, the ores, the third layouts, the landmark cities, the sites. The briefs are at the end of this section |

Each worker: read `GUIDE.md` (sections 1, 6, 8, 10, 11) and look at `kit_contract.png` first. Change only the
named modules. Run them to rewrite the sheets, check that no `PIECE PROBLEM` line is printed, and look at every
sheet at 100% and at 50%, whole and in enlarged crops. **Do not edit the kit, the guide, `overview.py` or
`contract.py`, and do not run `overview.py` or `contract.py`** (they write shared pictures; the art director runs
them when all four tasks are back). Report gaps in the kit instead of working round them. Trial pictures go in
your own scratch folder.

**Common to every task: the first rules (unchanged)**

- C1. **No road to the border.** End every `p.road(...)` at a gate point at least 10 px inside the border and add a
  `GATES = {"south": (x, y), ...}` table to the module (unmirrored coordinates). Drop the points beyond it.
- C2. **Overlays.** Trodden or cleared ground is `p.blob(x, y, w, h, colour, alpha=)`, never a colour mixed with the
  base ground. `mix(ground, X, t)` becomes `p.blob(..., X, alpha=t)`.
- C3. **10 px margin** for fields, plots, pans, yards, ponds, canals and activity details. Move or shrink what breaks it.
- C4. **No private kit calls** (`p.gp...`, `kit._smoke`, `p.sh`). They now also break the mirror. Use
  `p.smoke(x, y, always=True, foot=y)`, `p.blob(edge=)`, `p.over`, `p.jetty([points], snow=True)`, `p.wall(col=)`,
  `p.pond(col=)`, `p.terrace(face=)`, `p.animal(sc=, col=)`.

**Common to every task: the owner's answers (new)**

- C5. **Level 0 is no piece; the piece draws no wild land.**
  - `draw(0, season, ...)` returns `kit.wild(season, <the family's ground>, seed=<the family's seed>)` and nothing
    else. Set `NAMES[0] = "wild land (the map's)"`.
  - Delete the wild scatter from levels 1 and up: wild trees and bushes (`WILD_TREES` and the like), scrub patches
    "where work will come", and the terrain's tufts, stones and scree (`p.tufts`, `p.stones`, `p.scree` calls that
    only dress the terrain). Planted things stay: fruit trees by a house, poplars, cypresses, olive trees, hedges.
  - Make the sheet with `kit.sheet(..., ground=..., wild=True)`: it shows each piece in the terrain's wild land,
    thinned by the piece's footprint, as the map will.
  - Look at that sheet: no wild tree on the work or in front of a building; the work not in a bald hex. Where the
    work needs open ground round it, draw it as trodden or cleared ground (`p.blob(..., alpha=0.3` to `0.6)`); that
    is what clears the wild land. Level 1 must be told from level 0 at 50%.
- C6. **The mirror.** The signature becomes `draw(level, season, variant=0, mirror=False, <family keywords>)`; pass
  `mirror=mirror` to `kit.Piece`. Draw in unmirrored coordinates as before; never write `if mirror:`.
  - Landmark functions end with `return p.stand(y, fn)` (the handle).
  - A part of another thing gets `on=`: `p.smoke(x, y, always=True, foot=y0, on=handle)` for a chimney that is not
    in the middle of its building; `p.stand(y, fn2, on=handle)` for a wheel, a door, a lamp drawn separately.
  - Shadows only with `p.cast(x, y, w)`; a hand-placed `p.shadow` shifts with `p.m` (`x + p.m * dx`).
- C7. **The variants sheet.** Add `VARIANTS = 1` (or `2`, see the task) and write the second sheet from `__main__`:
  `kit.variant_sheet(draw, LEVELS, "<Family>: layouts and mirror", ".../<family>_variants.png", NAMES, ground=...)`.
  In the mirrored columns check: buildings lit on the left and shaded on the right, shadows to the lower right,
  smoke on its chimney, nothing collides or leaves the hex.
- C8. **A second layout** (only where the task says so). `VARIANTS = 2`; the tables become
  `LAYOUT = [dict(...), dict(...)]` and `draw` reads `LAYOUT[variant]`. Layout 1 has the same landmarks, counts,
  coverage, signature, seasons and additive rule as layout 0. Its yard stands at least 14 px from layout 0's yard
  **and from the mirror image of layout 0's yard**; blocks and the top landmark lie in other parts of the hex and
  at other angles. At 50% it must be told from layout 0 and from layout 0 mirrored. On the variants sheet the
  block of 5 x 4 hexes must read as countryside, with no two equal neighbours. Layout 0 stays as it is (after the
  task's own fixes).

**Task 1: `castles.py` and `mines.py`** (done; the mirror and wild-land rules for these two follow in task 6)

Castles
- Banner on the keep: the tip stands about 21.5 px high. Shorten the pole (`_banner` h 4.6 to 3.2) for the keep only,
  so nothing passes 20 px.
- Moat: use a quieter water, `kit.mix(p.pal["river"], p.pal["shallow"], 0.5)` with the same edge mixed 50% with the
  fill, and make `MOAT_W` 3.0. It must read as water round a wall, not as a blue outline.
- The trodden yard patch inside the fortress: overlay (C2). Roads: C1 (gate point south, about y = +36).
- Replace the local smoke with `p.smoke(..., always=False)` (winter grey comes from the kit) and the ring wall's
  local copy with `p.wall(..., col=kit.STONE_GREY)` if the result is the same picture; if not, keep the local one and say why.

Mines
- Levels 0 and 1 must differ at 50%: at level 1 make the first spoil heap 14 x 7.5 and put a trodden work yard under
  the adit and the heap (`p.blob(..., p.pal["soil"], alpha=0.35)`, about 30 x 12). Grow that yard under each new
  landmark (headframe, smelter) so worked ground reaches about 20 / 40 / 60% of the hex.
- Spoil heaps must not look like boulders: heaps are smooth cones in `SPOIL` with the 0.5 px ink; boulders keep the
  facets. Give the outcrop and boulders the kit's 0.5 px ink in `INK` (they are heavier and darker than every other family).
- Level 3: move the ore pile out of the smelter's front gap (8 px clear below a landmark).
- Track: C1, and draw it only with `p.road(track=True)` (the extra `p.gp.lines` line goes). Moss and work patches: C2.
- The smelter smoke: `p.smoke(x, y, always=True, foot=...)`.
- Spring and summer stay alike here by the guide; no change.

**Task 2: `vineyard.py` and `olives.py`** (done; the mirror, the wild-land rules and vineyard's second layout follow in task 6)

Vineyard
- The estate must not read as a church. Make it one broad two-storey house: 12 wide, wall 6.5 tall in `PLASTER[1]`
  (ochre), tile roof; the tower in the same ochre, its cone top no more than 2 px above the house ridge, on the
  right-hand end. Keep the two cypresses; they are what says "estate". Check at 50% beside `settlements.png` level 2.
- Red roofs: the hut-turned-house stays thatch at level 3 (so the piece has two tile roofs, not three).
- Terrace walls on the two upper blocks: `p.terrace(pts, face=2)`.
- Level 0 scrub patches: C2. Track: C1.

Olives
- Level 0: replace the five ruled stripes by three or four irregular `p.scrub` patches where the shelves will come.
- Winter: the soil shelves take snow (mix the soil 60% with `kit.SNOW`), the terrace walls stay stone.
- Terrace walls: `p.terrace(pts, face=2)` instead of the local wall, if the picture stays the same.
- The farmhouse stays `STONE` with tile (accepted as drawn). Blossom dots and the millstone: `p.blob`. Track: C1.

**Task 3: `grazing.py` and `timber.py`** (C1 to C8; second layouts for both)

Grazing (the biggest job)
- Meadows are the signature and must carry at 50%. New sizes (before the tilt): 40 x 24 at level 2; two more of
  30 x 20 and 22 x 26 at level 3, so fenced meadow covers about 20% / 45% / 65% with the level 1 trodden patch.
  Keep all 10 px from the border and clear of the byre's front gap.
- Meadow colour: clearly paler than the ground in every season. Summer about `kit.mix(grass, (232, 228, 150), 0.5)`;
  put it in the module as a named token and report it. Winter: `SNOW` inside the fence with two `SNOW_D` hoof-trodden
  blobs, so the fence does not enclose plain background.
- Sheep: at level 1 they stand on a trodden patch that is nearly their own colour. Darken the patch
  (`p.blob(..., p.pal["soil"], alpha=0.3)`, 36 x 16) and give sheep the kit's default body; they must show as light
  dots. This patch is also the level 1 footprint: without it the herd stands among the map's bushes.
- Young animals: `p.animal(x, y, kind, sc=0.7)`; drop the local `young_animal` and the three colour tokens.
- Smoke: `p.smoke`. Track: C1.
- C5: level 0 is `kit.wild(season, "grass", seed=<the module's seed>)`; delete the bushes, round trees, stones, tufts
  and scrub. The byre's and hut's yards are overlays.
- C6: the signature is `draw(level, season, variant=0, mirror=False, animal="sheep")`. `_draw_for(animal)` must
  return a function that takes and passes on `variant` and `mirror` (the kit reads the signature).
- C8, **layout 1** (`VARIANTS = 2`): layout 0 has the hut far left, the byre at the middle, the hall at the back
  right and the meadows in front and to the sides. Layout 1: the byre at the back right (about (+18, -16)) with the
  hut beside it, the big meadow in front of the byre across the middle, the two level 3 meadows on the west side,
  the market hall at the front left (about (-20, +10)) with its 8 px front gap. Same meadow sizes, animals and
  haystacks.
- Sheets: the three animal sheets with `wild=True`, and `grazing_sheep_variants.png` (one animal is enough).

Timber
- **The wood is the map's now (C5).** Delete every tree. The piece is the clearing and the work in it. Level 0 is
  `kit.wild(season, "wood", seed=<the module's seed>)`.
- The clearing: three or four overlapping `p.blob(..., p.pal["soil"], alpha=0.6)` with an irregular outline, growing
  from the front (south) to the back: about 20% / 45% / 65% of the hex at levels 1 / 2 / 3; the back third of the
  hex stays wood at level 3. Stumps stand in it (5 / 9 / 12).
- **The stream goes** (streams are the map's). The sawmill stands on a mill race of its own: `p.water(pts, 1.4)`
  about 34 px long, ending in a small pond at each end (`p.pond`, 8 x 5 and 14 x 8), all 10 px inside the border.
  The raft floats on the larger pond. Winter: race and ponds frozen, no raft, one more log pile.
- Smoke of the mound and of the sawmill: `p.smoke(x, y, always=True, foot=..., on=<its handle>)`; no `kit._smoke`.
- Level 3 clutter: remove the fourth log pile at (38, 17) or move it 6 px left; two standing things there have feet
  closer than 4 px.
- Track: C1. Work patches: C2.
- C8, **layout 1** (`VARIANTS = 2`): layout 0 has the clearing across the front with the mound and the sawmill on
  the right and the hut and shed on the left. Layout 1: the clearing is a tongue from the front centre running up
  to the north-east; the charcoal mound stands at its head near the middle of the hex (about (+4, -6)), the sawmill
  with its race at the front, left of the middle (about (-4, +28)), the hut and the shed on the east flank. The
  share of cleared ground per level is the same.
- Sheets: `timber.png` with `ground="wood", wild=True`, and `timber_variants.png`. Check in both that the map's
  trees come up to the clearing's edge on three sides and that none stands in front of the mound, the mill or the shed.

**Task 4: `salt.py` and `harbour.py`** (C1 to C7, `VARIANTS = 1`; the coast contract)

Both: the coast contract (guide section 10; pattern: `fishing()` in `contract.py`, picture: `kit_contract.png` row 2)
- The signature is `draw(level, season, variant=0, mirror=False, sea=None, shore=None)`; pass `mirror`, `sea` and
  `shore` to `kit.Piece`. Call `shore = p.coast(...)` once, with the keywords used today.
- Turn every layout table into shore coordinates: `u` = the old x, `v` = the old y minus the old shore y. Place
  everything with `shore.pt(u, v)`. Flat shapes (pans, yards, the slip) are polygons of `shore.pt` corners; quays,
  jetties and moles are `p.jetty` between `shore.pt` points. With no sea given the sheet must look as it does now.
- The piece draws no sea, sand or foam of its own (no beach-widening blob over the shore; on the map the shore is
  the map's). Trodden beach round huts is an overlay.
- Level 0 is `kit.wild(season, <ground>, seed=<seed>, coast=dict(<the same keywords as the p.coast() call>))`.
- Add `NEED = {1: px, 2: px, 3: px}`: the land depth behind the shore each level uses (keep level 3 at 46 px or
  less; the sheets' default shore leaves about 60).
- In your scratch folder draw every level with `sea="E"` and with `sea="NW"` (summer and winter) and look: the
  works meet the shore, nothing stands in the water that should not, nothing leaves the hex. Send the two strips
  with your report.

Salt
- Level 1: four pans, not three, in a row along the shore, and a trodden path from the hut to the pans (`p.blob`
  overlay), so it differs from the wild shore at 50%.
- Feeder channel: draw it with `p.over` at alpha 0.8 in `kit.mix(river, shallow, 0.5)`; it must not be brighter than
  the sea. It runs from the pans to the shore (`shore.pt(u, 0)`), not into the sea.
- Winter drifts: fewer and flatter now that the winter sand is pale. Remove the two top drifts.
- The jetty: straight out from the shore (`shore.pt(u, -1)` to `shore.pt(u, 14)`), `p.jetty(a, b, snow=True)`.
- Private `p.gp` glints in the pans: `p.over` or drop them (C4).
- C5: no pools, reeds or stones of the wild shore at levels 1 to 3.

Harbour
- **The moles.** Two real moles with `p.jetty([points], w=3.6, stone=True, snow=True)`, in shore coordinates: the
  first from `pt(-30, -1)` out to `pt(-30, 14)` and curling in to `pt(-18, 18)`; the second from `pt(34, -1)` to
  `pt(34, 14)` and in to `pt(22, 18)`. They close a basin with a mouth about 40 px wide. The lighthouse stands on the
  first mole's bend; ships and boats lie inside the basin.
- Fishing boats: size 0.7, not 0.55 (they read as dots). Keep ships at 1.0.
- The beached boat: it belongs to level 1 now (level 0 is no piece); put it at about `pt(-36, -7)`.
- Quay snow: `snow=True`, drop the local snow lines (C4).
- C5: delete the trees and bushes; hut patches are overlays.
- **The add-on**: `draw(..., addon=False)`. With `addon=True` draw only what stands at the water's edge: jetty,
  quay, moles, lighthouse, the hull on its slip, ships and boats; no huts, warehouses, net rack, people on land or
  ground patches. Same levels, same places. Show the three add-on levels (summer) as an extra strip in your report;
  the family sheet stays the full piece.
- Sheets: `salt.png` (`ground="sand", wild=True`), `harbour.png` (`wild=True`), and both `_variants.png` (mirror only).

**Task 5: `wheat.py` and `settlements.py`** (C1 to C7; wheat also C8)

Wheat
- The canal ends in a small pond at each end at about x = -36 and +36 (`p.pond`, 8 x 5); the three poplars stay
  (planted). Move the front block and its sheaves and reaper up so nothing worked lies below y = +34 or within 10 px
  of the border. Track: C1 (a south gate).
- C5: level 0 is `kit.wild(season, "farm", seed=1)`. Delete `SCRUB`, `WILD_TREES`, the stones and the `p.tufts` call.
  The two fruit trees stay.
- C6: `windmill` and `stooks` return their handles; nothing else is needed.
- C8, **layout 1** (`VARIANTS = 2`): layout 0 has the yard just left of the middle, the windmill behind it and the
  canal across the upper half. Layout 1: the yard in the upper right (about (+16, -14)), the first block in front of
  it to the left, blocks two to five filling the west and south, the canal with its poplars across the lower half,
  the windmill at the front left (about (-22, +14)) with its 8 px front gap. Same six-strip and five-strip blocks,
  hedges on two sides, haystacks by the barn.
- Sheets: `wheat.png` with `ground="farm", wild=True`, and `wheat_variants.png`.

Settlements (rules only, the art stays; `VARIANTS = 1`: its second layout comes in a later round)
- The three roads end at gate points 10 px inside the border: `GATES = {"south": ..., "east": ..., "west": ...}`
  (C1). The map's roads join them. Garden plots: C3.
- **No plate strip** (owner answer 1): remove the sentence about it from the module's header. Do not move the place:
  its middle stays 7 px above the hex centre. The ground in front is ordinary ground.
- C5 (levels start at 1, so there is no level 0 to change): from `TREES` delete the round trees and bushes (wild
  land); keep the fruit trees. Delete the `p.tufts` call. Sheet with `wild=True`.
- C6: `well` returns its handle. Check the mirrored columns of `settlements_variants.png` closely at levels 3 to 5:
  the church tower stays right of the nave, no house stands on the green or in the church, the gate tower and its
  door stay together (`on=`).
- Report the footprint share of each level (`kit.take_apart(draw, lv, "summer")["footprint"].count()` over the hex
  area); the map plan will use it.

**Task 6: `vineyard.py`, `castles.py`, `mines.py`, `olives.py`** (C5 to C7 for all four; vineyard also C8)

These four already have the first fixes (tasks 1 and 2). Do not redo them.

Vineyard
- C5: level 0 is `kit.wild(season, "grass", seed=<seed>)`; delete the bushes, round trees, stones, tufts and scrub.
  The two cypresses stay (planted).
- C8, **layout 1** (`VARIANTS = 2`): layout 0 has the hut left of the middle, the press house at the middle and
  the estate at the back centre. Layout 1: the hut at the back right (about (+12, -18)), the press house with its
  vats in front of it (about (+20, -4)), the estate with its cypresses on the west flank (about (-28, -6)), the two
  terraced blocks at the front, and the other blocks at the other pair of angles. Never fewer than 5 rows per block.
- Sheets: `vineyard.png` with `wild=True`, and `vineyard_variants.png`.

Castles, mines, olives (`VARIANTS = 1`; mirror check only)
- C5 for each. Castles (levels 1 to 3): delete wild trees, bushes and tufts; the mound stays (it is the family's own
  raised ground). Mines: delete the two conifers, the terrain scree, tufts and loose boulders; the outcrop with the
  adit is the piece's own and is drawn from level 1; level 0 is `kit.wild(season, "rock", seed=<seed>)`. Olives:
  delete the pines, bushes, stones and level 0 scrub; level 0 is `kit.wild(season, "grass", seed=<seed>)`.
- C6 for each, then look hard at the mirrored columns of the three `_variants.png` sheets:
  - Castles: `castles.py` places one shadow by hand (`p.shadow(cx + rx * 0.2, ...)`): use `p.m`. The banner still
    flies to the right in the mirrored piece (that is the wind, leave it). The keep, gatehouse and bastions must
    stay joined to their walls: parts drawn in separate `p.stand` calls need `on=`.
  - Mines: `p.shadow(4, ...)` under the outcrop: use `p.m`. The adit must stay in the outcrop, the wheel on the
    headframe and the smoke on the smelter chimney (`on=`).
  - Olives: the terraces and the tree grid mirror as ground and standing things separately; check that every tree
    still stands on its shelf and the millstone in front of the mill.
- Sheets: each family sheet with `wild=True` (`ground="rock"` for mines), and the three `_variants.png`.

**Later round, not now:** second layouts for olives, salt, mines, harbour, settlements and castles (the owner's
"then the rest"), once tasks 3 to 6 show how much variety one second layout buys on the map. (Started in round 3:
olives, mines, settlements and castles by two workers; salt and harbour are task 9.)

**Task 9: `salt.py` and `harbour.py`** (second layouts for both, the carved port in `harbour.py`, the three winters)

Read `GUIDE.md` sections 6 (second layout), 7 (the three winters), 8 (the two tables), 10 (the coast, the two port
modes) and 11, and look at `ports.png` and `winters.png` first. Change only these two modules. Do not edit the kit,
the guide, `overview.py`, `contract.py` or `winters.py`, and do not run those three scripts (they write shared
pictures). Report gaps in the kit instead of working round them. Trial pictures go in your own scratch folder. The
rules C1 to C8 above still hold. **The open-shore pictures of layout 0 must not change**: before you start, save
every level and season of both modules (plain, mirrored, sea S, E and NW) and compare pixel by pixel at the end.

Harbour, part A: the carved port (the new mode)

- The signature becomes `draw(level, season, variant=0, mirror=False, sea=None, shore=None, bay=None,
  addon=False)`. Pass `bay=bay` to `kit.Piece` and to `kit.wild` (level 0). After `s = p.coast(**COAST)` read
  `b = s.bay`. `b is None`: the open shore, today's layout, untouched. `b` set: the **carved layout**, from a table
  of its own (`CARVED = dict(...)`), never as offsets of the open-shore tables.
- What the map gives (guide section 10): a bay `kit.BAY_WIDTH` (72 px) wide from horn `b.west` to horn `b.east`,
  its back straight for 25 px to each side of `b.u0`, 6 to 19 px deep (`b.depth`; `b.room(u)` is the water from
  the back out to the mouth line at u). `s.pt(u, v)` measures from the bay's own shore; `b.pt(u, v)` measures v
  from the **mouth line** (horn to horn). Write every u of the carved table relative to `b.u0`.
- The carved layout, same levels and landmarks as the open shore:
  - Level 1: the jetty from the back of the bay, `s.pt(b.u0 + 6, -1)` out to `min(13, b.room(b.u0 + 6) - 3)`,
    with its T head; two fishing boats and the beached boat inside the bay; huts and net rack on the land behind
    the back (v from -8 to -24, u within 30 px of `b.u0`).
  - Level 2: the stone quay along the straight back, `b.u0 - 24` to `b.u0 + 24` at v = -1.5; the two warehouses
    behind it; the first ship at the quay.
  - Level 3: **two short moles from the horns along the mouth line**, closing the mouth to 26-30 px: west
    `b.pt(b.west + 1, 0)`, `b.pt(b.west + 16, 1.5)`, then turned in to `b.pt(b.west + 21, -2.5)`; east the same
    from `b.east`. `p.jetty([...], None, 3.6, stone=True, snow=True)`. The lighthouse stands on the west mole's
    root, at the horn: choose with `s.first([b.uv(b.west + 3, 0), b.uv(b.east - 3, 0), b.uv(b.west + 16, 1.5), ...],
    *LIGHT_SIZE)`. The slip and its hull on the back shore at `b.u0 + 21` (east of the quay's end: shorten the quay
    to `b.u0 + 16` at level 3 if they touch); the third warehouse; the second ship.
  - Ships and boats: berths inside the bay, at least 3 px from the shore and from the mouth line; the "out at sea"
    berths of spring and summer lie at most 6 px beyond the mouth line. Keep using `afloat()` (`s.fit`).
  - A shallow bay (`b.depth` under 10): the same works; the ships lie nearer the quay, and a boat that does not
    fit is left out. Nothing is laid out by `b.depth` except through `b.room`.
- **The carved mode has one layout**: `variant` is ignored in a bay (the mirror still applies). Say so in the
  module's header.
- `addon=True` in a bay: jetty, quay, moles, lighthouse, slip and hull, ships and boats, as on the open shore.
- Add `BAY = dict(width=kit.BAY_WIDTH, back=COAST["y0"])` (what the harbour asks of the map) and
  `REACH = {1: px, 2: px, 3: px}`: how far out from the shore each level's works and berths reach on an open
  shore (measure it; the map uses it to tell whether a seaside harbour fits its own water).
- Checks, in your scratch folder: every level, full piece and add-on, with `bay=(0, kit.BAY_WIDTH, d)` for
  d = 8, 13 and 19, on all eight sea sides, plain and mirrored, summer and winter: no `PIECE PROBLEM`; nothing of
  the piece more than 6 px beyond the mouth line; the quay lies on the back shore and the moles meet the horns
  (no mole on land, none starting in open water); at 50% level 3 reads as a closed basin with a lighthouse and
  level 1 as a jetty in a cove. `harbour_sides.png` gets three more rows: the carved levels 1 to 3 (summer,
  `bay=(0, kit.BAY_WIDTH, 13)`) on S, E and NW, plain and mirrored.

Harbour, part B: the second layout on the open shore (`VARIANTS = 2`, C8)

- Layout 0 (as it is): huts at the west, the jetty right of the middle, the quay west of the jetty, two bent moles
  of equal size with the lighthouse on the west mole's bend, the slip at the east.
- Layout 1: **one long mole and a spur.** The long mole leaves the shore at the west end (u = -32), runs out 15 px
  and sweeps round in two bends to end at about (8, 21); a short straight spur from the east shore (u = 32) runs
  out 9 px; the mouth is at the east, about 22 px wide. The lighthouse stands at the **head** of the long mole
  (fall-backs as today, through `s.first`). The jetty at u = -14; the quay from u = -4 to +28; the warehouses
  behind it; the slip at the west (u = -24); the first hut at about (0, -23) with the second beside it at
  (10, -19) (the yard: 14 px from layout 0's huts and from their mirror image); the net rack and the beached boat
  at the east end. Same counts: 2 huts, 3 warehouses, 2 ships, 3 boats, the hull on the slip.
- Tables side by side: `LAYOUT = [dict(...), dict(...)]`; the carved table stays apart. At 50% layout 1 must be told
  from layout 0 and from layout 0 mirrored: the single long arm is what does it. All eight sea sides, plain and
  mirrored, both layouts: no `PIECE PROBLEM`, the lighthouse there on every side.

Salt, part A: the second layout (`VARIANTS = 2`, C8)

- Layout 0 (as it is): one block of pans in three rows in the middle, the hut and the sluice at the west, the
  store behind the pans, the heaps in a row in front of them, the jetty at the east.
- Layout 1: **two blocks of pans either side of the feeder channel.** The channel runs from the shore straight
  inland at u = 0 with the sluice on it; west of it a block 3 pans wide, east of it a block 4 pans wide, 2 rows
  each (14 pans, in the same order of levels: level 1 the four pans nearest the shore, two on each side; level 2
  the rest of the first rows and the channel; level 3 the back rows). The heaps stand in a row along the inland
  side of the pans (not in front), the store at the west end near the shore (about (-30, -8)), the hut at the east
  end (about (32, -14)), the jetty at the west (u = -22) with the boat. Same counts: 4 / 8 / 14 pans, 1 / 3 / 5
  heaps, the strict grid inside each block, the same pan size and dykes.
- Coverage in the bands (15-30 / 35-60 / 60-85% of the margin hex); `NEED` true for both layouts. The accepted
  3 px corner on slanted shores holds for layout 1 too, no more.

Salt, part B: the lagoon (no layout of its own)

- The signature takes `bay=None` and passes it to `kit.Piece` and `kit.wild`. On a lagoon the map hands the
  lagoon's shore and its bay; the pans lie at that shore as at any other. Only two things look at `s.bay`: the
  jetty ends at most `b.room(u) - 2` px out, and the boat lies inside the lagoon. Check both layouts with
  `bay=(0, kit.BAY_WIDTH, 10)` on all eight sides.

Both: the three winters (guide section 7)

- Look at every level with `kit.with_wild(draw, lv, "winter", climate=c)` for `"snow"`, `"frost"` and `"mild"`.
  The snow winter must be the picture of today.
- Snow hangs on `p.winter`, ice on `p.frozen`, the season's doings on `season == "winter"`. Salt: `pan_col` and the
  feeder channel are frozen only `if p.frozen`; in a mild winter the pans are filled as in spring
  (`kit.mix(pal["shallow"], pal["sand"], 0.45)`), the heaps stay covered, nobody is out. Harbour: the boats are
  laid up in every winter; nothing is white in the mild one (it is right today; check the lighthouse cap and the
  hull).
- Never read `kit.PAL["winter"]`; colours come from `p.pal` and `kit.crop`.

Sheets and report: `salt.png`, `salt_variants.png`, `salt_sides.png`, `harbour.png`, `harbour_variants.png`,
`harbour_sides.png` (run the two modules). Send with the report: the pixel comparison of layout 0 on the open
shore; a strip of each module in the three winters; the carved harbour at depth 8, 13 and 19; coverage per level
and layout; `REACH`; and every place where the kit's bay was not enough.

### Round 4: tasks 10 to 25, the Python art

Sixteen tasks, sized for one worker each. **Every task touches its own files only**, so tasks in the same group
run side by side.

| Group | Tasks | When |
|---|---|---|
| **A: parallel, now** | 10 Quarry, 11 Dye works, 12 Hemp, 13 Silk, 14 Furs, 15 Cotton, 16 Ores (iron, silver, copper), 18 Vineyard layout 2, 19 Grazing layout 2, 20 Castles layout 2, 21 Landmarks (first four), 23 Sites, 24 Coast follow-ups | All thirteen at once: no two share a file |
| **B: after one task of A** | 17 Gold (after 16: the same file), 22 Landmarks (the other six; after 21: the same file) | When its forerunner is reviewed |
| **C: last** | 25 Overview and in-map test (the art director) | When A and B are reviewed |

If thirteen sheets at once are too many to review well, send a first wave of five that between them try every
kind of task: **10 Quarry, 11 Dye works, 16 Ores, 18 Vineyard layout 2, 23 Sites**; then the rest.

**Common to tasks 10 to 24**

- N1. **Read first:** `GUIDE.md` sections 1 to 7, your family's table in section 8, the signature and crowding
  tables in section 4, and the checklist (section 11). Look at `kit_additions.png`, `overview.png`, `winters.png`
  and the catalogue page named in your task (`../python_art/catalogue_<n>_....png`; the ids are under the
  pictures). `wheat.py` and `settlements.py` are the pattern; `tools/worldmap/pieces/README.md` is the kit on one
  page.
- N2. **The catalogue picture is the model for the idea, not for the drawing.** Nothing of the Python code is
  reused and nothing is copied or scaled: redraw with the kit. What always changes (the catalogue's "standard
  conversion"): no ground fill (coloured soil only as a patch 10 px inside the border); no wild land, relief, sea
  or river; buildings seen from the front in two flat tones; 0.5 px `INK`, none on people, animals, trees or
  ground shapes; a house is 8 px and the tallest thing 20, so the idea becomes **more, smaller units**; three
  levels from the old levels 1, 3 and 5, one new landmark each; fixed layout tables, additive by level; four
  seasons and three winters; coverage 15-30 / 35-60 / 60-85% of the margin hex unless the table says otherwise.
- N3. **Files.** Change or create only the files named in your task. Do not edit `kit.py`, the guide,
  `overview.py`, `contract.py`, `winters.py`, `additions.py` or `compose.py`, and do not run those five scripts.
  If the kit lacks something, say so in the report and draw it locally with `p.stand` and the `pen`.
- N4. **Colours.** The kit's tokens only; your family's signature tokens are already in the kit (guide section 4).
  Any further colour is a named token at the top of your module and a line in your report.
- N5. **The contract.** `LEVELS`, `NAMES`, `VARIANTS`, `LAYOUT = [dict, dict]` (tables side by side), `GATES`,
  `draw(level, season, variant=0, mirror=False, ...)`; level 0 returns `kit.wild(season, <ground>, seed=<seed>)`;
  no wild scatter; `mirror=mirror` to `kit.Piece`, never `if mirror:`; landmarks through `p.stand` (with `x=` on
  every part that shares an axis, `on=` for a part of another thing) and `p.cast`; roads end at gate points;
  ground work 10 px inside the border; snow on `p.winter`, ice on `p.frozen`, the season's doings on
  `season == "winter"`.
- N6. **A new family has two layouts** (guide section 6): the yard 14 px from layout 0's yard and its mirror
  image, told from layout 0 and its mirror at 50%.
- N7. **Sheets.** `<family>.png` (`kit.sheet(..., wild=True)`) and `<family>_variants.png` (`kit.variant_sheet`).
  No `PIECE PROBLEM` line. Look at every sheet at 100% and 50%, whole and in enlarged crops, and at each level in
  the three winters (`kit.with_wild(draw, lv, "winter", climate=c)`).
- N8. **Look-alikes.** Put your top level beside every family named with yours in the crowding table (guide
  section 4), at 50%, and send that strip.
- N9. **An existing module keeps its pictures.** Where a task adds a keyword or a layout to an existing module,
  everything the module drew before must be pixel-equal after (every level, season, layout and mirror): hash them
  before you start and send the comparison.
- N10. **Report:** what you drew; the sheets; coverage per level and layout (the footprint's share of the margin
  hex, summer); the crowding strip; new tokens; every place where the guide's table could not be met and what
  you did instead; kit gaps.

**Task 10 (A1): Quarry.** New file `quarry.py`; sheets `quarry.png`, `quarry_variants.png`.
- Models: `stone1`, `stone3`, `stone5` (catalogue page 1). Guide: "Quarry". Ground `rock`, seed 11.
- What changes from the model: the old tile is a pit seen from straight above with a grey floor. Here it is a
  **stepped face rising to the back**, seen from the front: 1 / 3 / 4 ledges, each a `PIT` top over a `PIT` face
  with a `PIT_D` right quarter, built back to front with `p.stand(..., x=)`. The big crane becomes a 12 px
  treadwheel crane, the marble columns a row of three 9 px columns; blocks are 3 x 2 px `MARBLE` boxes in stacks.
- Watch: it must not read as Mines. No dark opening, no cone heap, no smoke. Pale and angular. Level 1 must be
  told from wild rock at 50% (the white blocks and the pale face do it). Winter: snow on tops, faces bare.
- Layout 1: the face on the west flank, running back to front, the yard and the crane to its east.

**Task 11 (A2): Dye works.** New file `dyes.py`; sheets `dyes.png`, `dyes_variants.png`.
- Models: `dyes1`, `dyes3`, `dyes5` (page 1). Guide: "Dye works". Ground `grass`, seed 12.
- What changes: the coloured stream is dropped (a plain rinsing channel between two ponds, inside the hex); the
  vats are flat ellipses on the ground, 3 / 6 / 9, in `kit.DYE` colours, in rows; the old cloth racks become
  thin standing lines of small cloths; the striped dye house becomes a plain stone building with a chimney.
- Watch: the only many-coloured piece on the map: keep the colours to the vats and the cloth, everything else
  quiet. The vats keep their colour in winter (snow on the rims only): check the three winters. The chimney
  smokes in every season (`always=True`, `on=` the house). Against salt: round, never a grid of squares.
- Layout 1: the vats in one long double row along the channel instead of a block, the dye house at the other end.

**Task 12 (A3): Hemp.** New file `hemp.py`; sheets `hemp.png`, `hemp_variants.png`.
- Models: `hemp1`, `hemp3`, `hemp5` (page 1). Guide: "Hemp and the ropewalk". Ground `farm`, seed 13.
- What changes: the old tile's bushy plant clumps become flat near-square blocks (`p.field(..., kit.crop("hemp",
  season), 2)`), the blue ponds dull-green `RET` ponds (`p.pond(pts, col=kit.RET, edge=kit.RET_D)`), the orange
  stooks thin tripods, and the ropewalk a 28 px open thatched shed.
- Watch: **spring wheat** (the crowding table). Put hemp level 3 beside wheat level 3 in spring, summer and autumn
  at 50%; if they can be confused, make the blocks squarer and fewer-striped, not the colours brighter. Spring:
  bare earth with dashed `hemp_row` rows. Ponds frozen only `if p.frozen`.
- Layout 1: the ropewalk at the back instead of the front (it is a front-view building: it always lies level),
  the blocks in two groups either side of a pond in the middle.

**Task 13 (A4): Silk.** New file `silk.py`; sheets `silk.png`, `silk_variants.png`.
- Models: `silk1`, `silk3`, `silk5` (page 1). Guide: "Silk". Ground `grass`, seed 14.
- What changes: the old tile's hedge bands across the whole hex become single-file rows of `mulberry` trees on
  pale `mulberry_soil` strips, 2 / 4 / 6 rows, inside the margin; the brown sheds become long low thatched sheds
  lying between rows; the big blue-domed hall becomes a small court wall with a 6 px `DOME_TILE` dome.
- Watch: olives (a grid of silver trees on terraces) and the cathedral dome; the rows must read as lines at 50%.
  Summer's stripped trees: draw every second tree of the two newest rows as the kit draws the bare one (ask in
  the report if the kit should offer it; a local copy of the bare pollard is fine). Autumn at 50% must not read
  as a row of haystacks: if it does, say so. Check the mild winter first: it is silk's usual one.
- Layout 1: the rows at another angle (about 20 degrees) and the caravanserai at the front instead of the back.

**Task 14 (A5): Furs.** New file `furs.py`; sheets `furs.png`, `furs_variants.png`.
- Models: `furs1`, `furs3`, `furs5` (page 1). Guide: "Furs". Ground `wood`, seed 15 (`kit.sheet(..., ground="wood",
  wild=True)`: the kit's wild wood shows what the map will do).
- What changes: the snow and the pines of the old tile are the season's and the map's; the round palisade fort
  becomes a **square stockade open to the front** (your own `p.stand` drawing: back side behind, the two sides,
  corner posts; `p.claim` its inside); pelts are small `PELT` diamonds on pale timber frames.
- Watch: Timber and Castle 1 (the crowding table). No stumps, log piles, mound or water. Coverage bands 10-20 /
  20-35 / 35-50%. The clearing is an overlay of two or three blobs, never one ellipse. Winter is the high season
  (all frames full, every cabin smokes, three smokes at most).
- Layout 1: the clearing on the east side, the frames in an L round the cabins instead of rows in front.

**Task 15 (A6): Cotton.** New file `cotton.py`; sheets `cotton.png`, `cotton_variants.png`.
- Models: `cotton1`, `cotton3`, `cotton5` (page 1). Guide: "Cotton". Ground `farm`, seed 16.
- What changes: the red earth filled the hex; here it is 1 / 3 / 5 patches of `cotton_soil` (22 x 16 px) with
  rows along the long side (`p.rows(..., col=kit.crop("cotton", season)[0], soil=kit.crop("cotton_soil",
  season)[0])`); the bolls are 1 px `BOLL` dots on the rows; the white heaps become 2 / 4 banded bales (salt owns
  white cone heaps in a row); the tall gin house is a two-storey plastered house with a hoist beam.
- Watch: the vineyard (the crowding table). Autumn is the white season, summer half white, winter has no white:
  check that mild-winter cotton beside mild-winter vineyard is still told apart at 50% (red earth, big patches,
  the gin house).
- Layout 1: the patches in an L round the gin house in a corner, rows at right angles to layout 0's.

**Task 16 (B1): Ores: iron, silver, copper.** File `mines.py`; sheets `mines_iron.png`, `mines_silver.png`,
`mines_copper.png` (the plain `mines.png` and `mines_variants.png` must come out pixel-equal: N9).
- Models: `iron1`-`iron5`, `silver1`-`silver5`, `copper1`-`copper5` (page 2). Guide: "The four ores".
- Add `ore=None` to `draw` and a constant `ORES = (None, "iron", "silver", "copper")`. The layouts stay. An ore
  changes: the heap colours (`kit.ORES[ore]["spoil"]`, `["spoil_d"]`), the ore pile (`["ore"]`, `["ore_d"]`), one
  detail and the level 3 landmark **on the smelter's foot in both layouts**: the blast furnace with its `GLOW`
  mouth (iron), the mint with its stamp frame (silver), the roasting yard of three smoking heaps (copper).
- What changes from the models: the mountain backdrops, snow peaks, sparkles, the tramway and the red-roofed
  mint go. The copper stain is 3-4 flat `VERDIGRIS` patches on the outcrop's lit faces.
- Watch: the four pictures (plain and three ores) of level 3 side by side at 50% must be four different
  pictures; levels 1 and 2 differ by colour only, and that is accepted. Smoke: the furnace always, the three
  roasting heaps always, the mint never. `on=` for every smoke.
- Write the landmark as one function per ore taking the foot, so task 17 can add gold beside them.

**Task 17 (B2): Ore: gold.** After task 16. File `mines.py`; sheet `mines_gold.png` (all other mines sheets
pixel-equal: N9).
- Models: `gold1`, `gold3`, `gold5` (page 2). Guide: "The four ores", the gold line.
- Gold is the one ore with **its own layout tables** (`GOLD = [dict, dict]`, beside `LAYOUT`): the outcrop and
  adit stay at level 1; tents on the huts' feet at levels 1 and 2; at level 2 **the sluice** (a timber trough on
  trestles, 26-30 px long, along a longer race with a pond at each end, inside the hex) stands where the
  headframe is in the other ores; at level 3 the strongroom, three houses, three gravel heaps, the ore pile.
- What changes from the model: the river is the map's (the race is the piece's own water); the yellow ground
  goes (the map's); the palisade fort is **dropped** (the art director's call: gold has no fort).
- Watch: a castle (no ring of any kind); the timber sawmill's race (gold's race carries the long trough and no
  wheel); the sluice must be the first thing seen at 50%.

**Task 18 (C1): Vineyard, the third layout.** File `vineyard.py`; sheets `vineyard.png`, `vineyard_variants.png`
(layouts 0 and 1 pixel-equal: N9).
- Models: `wine4`, `wine5` (page 2). Guide: "Vineyard", "The third layout: contour rows round the chateau".
- `VARIANTS = 3`, a third dict in `LAYOUT` with its own keys (centre, ring radii, sectors as angle pairs with a
  "from level", hut, press, estate). Rows with `p.arc`; each sector's soil a `p.patch` between two
  `kit.ring_points` lines; the demonstration in `additions.py` (`contour()`) shows the calls, not the design.
- What changes from the model: no hill, no slope shading, no cellar door in a slope; the chateau is the
  family's estate house in the middle of the rings.
- Watch: counts and coverage as layouts 0 and 1 (6 blocks, at least 5 rows each; measure the footprint); the
  press house at level 2 must not hide behind rows; the rows must still read in winter (snow soil, dark stakes)
  and under the mild winter; at 50% it must be told from layouts 0 and 1 and both mirrors (it will be: it is the
  only curved one). If the track ends elsewhere, `GATES` becomes a list of three.

**Task 19 (C2): Grazing, the third layout.** File `grazing.py`; sheets `grazing_sheep.png`, `grazing_cattle.png`,
`grazing_horses.png`, `grazing_sheep_variants.png`, and new `grazing_horses_variants.png` (layouts 0 and 1 of all
three animals pixel-equal: N9).
- Models: `wool2`-`wool4` and `horses2`-`horses5` (page 2). Guide: "Grazing", "The third layout: upland pens".
- `VARIANTS = 3`. Layout 2 has two forms of its meadows, by the animal: sheep and cattle get odd-shaped pastures
  inside `p.drystone` walls and a round stone ring (`p.ring(kind="stone")`); horses get three round paddocks
  (`p.ring`, radius 16, 11, 11). Keep one table with both forms' shapes; hut, byre, hall, haystacks and the herd's
  count are shared, the herd's places may differ by form.
- What changes from the models: the grey paths across the wool tile go (roads are the map's); the striped
  tents, the galloping horses and the red stable roof go; horses stand, at kit size.
- Watch: the meadow colour inside every wall and ring (a wall alone is a thin line and no footprint); animals
  inside the walls from level 2; walls sharing a side must not double; the stone fold must not read as a well;
  10 px margin at every pasture corner; winter's three animals stand in the fold or the paddock by the byre.

**Task 20 (C3): Castles, the third layout.** File `castles.py`; sheets `castles.png`, `castles_variants.png`
(layouts 0 and 1 pixel-equal: N9).
- Model: `K1` (page 3). Guide: "Castles", "The third layout: motte and bailey".
- `VARIANTS = 3`; a third dict in `LAYOUT` and a third in `GATES`. The motte (back left) and the bailey (front
  right) are two places joined by a lane; levels 2 and 3 grow on them as the table says.
- What changes from the model: the old timber keep becomes the family's grey stone tower with slate cone and
  banner; the mound is low (a 22 x 12 px mound with a darker front edge; nothing above 20 px over the keep's
  foot); the palisade is the kit's ring (`p.wall(kind="palisade")`).
- Watch: the level 3 bastion wall must go round both places without leaving the margin (it is the widest thing
  in the family: measure it, mirrored too); the keep must not be hidden by the bailey's back wall; `x=` on every
  part of the motte's tower and of each ring; the banner colour stays the `flag` keyword.

**Task 21 (D1): Landmark cities: Venice, Constantinople, Paris, Moscow.** New file `landmarks.py`, a hook in
`settlements.py`; new sheet `landmarks.png` (`settlements.png` and `settlements_variants.png` pixel-equal: N9).
- Models: `venice2`/`venice3`, `constantinople2`/`3`, `paris2`/`3`, `moscow2`/`3` (page 3): stage 2 is the model
  for level 4, stage 3 for level 5. Guide: "Landmark cities".
- `landmarks.py`: `NAMES`, `draw(p, name, level, x, y)` (returns the handle; every part `p.stand(..., x=x)`, the
  shadow `p.cast`), `CLEAR[name][level]` (the box, in px round the foot, in which the settlement draws no house),
  `WALL[name]` (a ring-wall colour, where the city has one: Moscow `kit.BRICK`). `settlements.py`:
  `draw(..., landmark=None)`; at levels 4 and 5 with a landmark, call it in place of the church or cathedral on
  the same spot **in both layouts**, skip the houses in `CLEAR`, pass `WALL` to `p.wall(col=)`. Below level 4
  and with `None` nothing changes.
- The sheet (write it from `landmarks.py`): one row per city, levels 4 and 5, summer and winter, both layouts,
  and a 50% strip with a plain level 5 city at its head.
- What changes from the models: the water, river, island, sea walls and gondolas are the map's or are dropped;
  the monuments shrink from 40-60 px to at most 20 x 24 px, so each keeps **one silhouette idea**: the campanile
  beside low domes; the wide dome between four needles; two square towers; the cluster of coloured onions over a
  red wall. Venice is drawn at a shore like any city (guide: "Venice and the water"); do not draw water.
- Watch: each monument against the plain cathedral and against the other three at 50%; snow on domes lies on the
  upper left only and the colour must still show; minarets and the campanile are thin: give them 1 px minimum
  and thin ink so they survive the 50% test; no house pokes through a monument.

**Task 22 (D2): Landmark cities: London, Rome, Seville, Lisbon, Cairo, Granada.** After task 21. File
`landmarks.py` only (`landmarks.png` grows by six rows; the first four rows pixel-equal).
- Models: `london2`/`3`, `rome2`/`3`, `seville2`/`3`, `lisbon2`/`3`, `cairo2`/`3`, `granada2`/`3` (page 3). Guide:
  "Landmark cities", the last six lines.
- What changes from the models: London's bridge, Lisbon's ships, Cairo's Nile and desert, Granada's hill and
  snow peaks, Seville's palms all go; Lisbon's tower stands on the church's spot for now.
- Watch: Cairo against Constantinople (Cairo has no great dome), Rome's dome against the plain cathedral's and
  Constantinople's (Rome's stands on a tall drum with a lantern), Granada's and Moscow's red (Granada is a long
  low wall, Moscow a ring with onions), the Giralda and the campanile (bands against a plain shaft with a green
  cap). All ten in one 50% strip.

**Task 23 (E1): Sites.** New file `sites.py`; sheets `sites.png` (one row per site: the wild land, the site in
four seasons, the three winters, 50%) and `sites_variants.png`.
- Models: `L-monastery`, `L-roman_ruins`, `L-aqueduct`, `L-standing_stones`, `L-ruined_castle`,
  `L-pilgrimage_chapel` (page 4). Guide: "Sites".
- `LEVELS = (0, 1)`, `VARIANTS = 6`, `SITES = (...)`: **the variant is the site**. `kit.sheet` shows levels, so
  write the sheet with a small loop of your own over the six variants (`kit.with_wild(draw, 1, season,
  variant=i)` and `kit._cell`, as `winters.py` does); `kit.variant_sheet` works as it is (twelve columns).
- What changes from the models: front view, thin ink, at most 20 px tall; the old pictures are one big object:
  here each is a small group with a footprint of 8-20% of the margin hex, so the wild land stands close round it.
- Watch: the ruined castle against castle 1 and the monastery against a village (the crowding table); the
  chapel against the settlement's level 2; the standing stones against the map's own stones (a clear ring, taller
  stones, the trodden circle); the aqueduct must stay inside the hex mirrored too. Each site gets a `GATES` entry
  only if it has a track (the chapel, the monastery).

**Task 24: Coast follow-ups from the map** (task 9's modules). Files `salt.py`, `harbour.py`; all six coast
sheets again.
- Seen in the in-map test of round 4 (above): `PIECE PROBLEM` on real shores for harbour level 1 (6 px), harbour
  level 2 (15 px) and its add-on (9 px), and salt level 3 (159 px; layout 1, mirrored, sea at 111 degrees). The
  map's shores are curved and slanted and the land is sometimes only a strip.
- Reproduce without the map: call the modules with a bent shore line, `shore=[(-52, 8), (-20, 20), (10, 16),
  (52, -6)]` and its like, on `sea=` angles 16, 66, 77, 111 and 163 degrees, plain and mirrored, both layouts.
  Every thing that would leave the hex is slid in with `shore.fit` or left out (`shore.fits`); nothing may print
  `PIECE PROBLEM`.
- Salt layout 1: `p.claim` the strip of the feeder channel between the two blocks (a wild tree stands there in
  the map), and keep the first row of pans within 6 px of the shore at the channel on a bent shore (the pans
  follow `shore.pt`; the channel must reach the water).
- Harbour layout 1 on a bent shore: the long mole must start at the water's edge (not on land) and the spur must
  not lie across the beach: root both with `shore.pt(u, 0)` at their own `u`, and drop the spur where
  `shore.land` says its far end is on land.
- The straight-shore pictures of the sheets must not change (N9).

**Task 25 (F1): Overview and in-map test with the new families** (the art director, last).
- `overview.py`: the six new families, an ore row, a sites row, a landmark row and the third layouts;
  `winters.py`: the new families. `compose.py`: place a quarry, a dye works and a site in the test region and
  give Genoa no landmark (it has none); render and review. Then the look-alike review of all sixteen families on
  one page, at 50%.

## 5. Kit changes made in this review

All new arguments are optional; modules run unchanged. Pictures were compared before and after, pixel by pixel.

**Round 1 (the in-map test)**

| Change | Effect on existing sheets |
|---|---|
| `take_apart()`, `Piece.layers()`, `Piece(base=)`, `stand(lift=)` | None |
| `over()`, `scrub()`, `blob(alpha=, edge=)`; tracks drawn as 75% overlays | Tracks differ by at most 13 of 255 on a few pixels (not visible) |
| `terrace(face=)`, `jetty([points], snow=)`, `pond(col=, edge=)`, `wall(col=)`, `animal(sc=, col=)`, `smoke(always=, foot=)` | None |
| Winter roofs: 1 px eave band in the roof colour (houses, churches) | **Intended**: every winter piece with a house, most of all `settlements.png` |
| Winter smoke is grey (`SMOKE_SNOW`) | **Intended**: winter pieces with smoke, `wheat.png` and `settlements.png` included |
| Winter `sand` 226,218,186 to 234,230,214 | **Intended**: winter salt and the winter beach in harbour |
| `wheat.py`, `settlements.py`: one scrub and one trodden-ground blob turned into overlays | At most 4 of 255 (not visible) |

**Round 2 (the owner's answers).** All thirteen sheets and the overview were rendered before and after: **every one
is identical, pixel for pixel**. Nothing changes on a sheet until a module asks for it.

| Change | What it is for |
|---|---|
| `Piece(mirror=)`; `p.m`; `p.stand(..., x=, on=)` returns a handle; kit calls return handles; `p.smoke(on=)` | The mirror. Ground detail is drawn turned round; every standing thing is moved to its mirrored place and drawn unflipped, so light and shadow stay. Tested on all ten families: no piece leaves the hex mirrored |
| `kit.pick(col, row, variants)` | The picture of a hex from its coordinates: (layout, mirrored). With two layouts no two neighbours are equal (checked on 40 x 40 hexes) |
| `Piece(sea=, shore=)`, `p.coast()` returns a `Shore` (`pt`, `land`, `out`, `along`, `depth`, `front`); `kit.SIDES` | The coast contract. On the map `coast()` draws nothing. `shore(x)` still works for the sea in front, so salt and harbour run unchanged until task 4 |
| `Piece.footprint()`, `kit.in_footprint`, `layers()["footprint"]` | The area a piece works, for thinning the map's wild land |
| `kit.take_apart(draw, level, season, hex=, variant=, mirror=, sea=, shore=)` | Level 0 returns `None`. Picks layout and mirror from the hex. What a module's `draw` does not take yet is handed to the kit, so mirror and sea side work with today's modules |
| `kit.wild(season, ground, seed, coast=)`, `Piece.wild()`, `WILD_MIX` | The level 0 picture for the sheets: the terrain's generic wild scatter |
| `kit.sheet(..., wild=True)`, `kit.with_wild`, `kit.variant_sheet`, `kit.hex_field`, `kit.mirror_gates` | Sheets that show a piece in thinned wild land; the variants sheet; gate points of a mirrored piece |
| `tools/worldmap/pieces/contract.py` writes `kit_contract.png` | The contract on one page, and `fishing()`: the pattern for a coast piece in shore coordinates |

Not added to the kit, because one family uses them: stumps, raft, hull on a slip, lighthouse, headframe, vats.
They stay local to their modules.

## 6. Owner questions: answered on 2026-11-15

(The two answers of round 3, ports and winters, are in "Round 3" at the top and in the guide's section 12.)

| | Question | Options offered | **The owner's answer** |
|---|---|---|---|
| 1 | Where does a town's name plate go? All 14 plates in the test crossed into the hexes below | (a) move the town up and the plate in; (b) let the plate hang over; (c) smaller plates | **"No plates for now."** The normal map shows no town name plates. The town stays where the guide puts it; no plate strip |
| 2 | Coasts and ports: a piece drew its own sea on the south side; Genoa is a city and a harbour in one hex | (a) the map owns the shore, a port is a town with harbour works; (b) the town wins; (c) port-town pieces | **"Map draws shore."** (a): coast pieces are told the sea side; in a town's hex the harbour is an add-on at its own shore |
| 3 | Who draws the wild land, and how much variety? | (a) the map draws it, mirror and one second layout; (b) mirror only; (c) keep the pieces whole | **"Map + 2nd layout."** (a): the map draws woods and scrub and thins them under the piece; level 0 is no piece; mirror and a second layout by the hex, wheat, grazing, timber and vineyard first |

What the answers changed is in section 3 (rules), section 4 (tasks 3 to 6) and section 5 (kit). The in-map test was
rendered again to the answers: `../pieces_in_map/summer.png`, `winter.png`, `plain_crop.png` (and its notes, round 2).

New, smaller questions the answers raise (none blocks the tasks; guide section 12):

- **Town names without plates.** Recommended for now: nothing at this zoom, names on hover and in the panel.
- **The timber piece's water.** With streams left to the map, the sawmill gets a short mill race with two ponds
  inside the hex (as wheat's canal). Option: no water at all and a horse-driven saw. Recommended: the mill race.

## 7. Risks and open ends

- The fix tasks are written against the sheets and the code as they stand; grazing, timber and harbour are layout
  changes and need a second look when they come back.
- **Timber changes most**: it loses its trees and its stream and becomes a clearing. On the sheet it will only read
  as "wood" through the kit's wild land; if the clearing is too regular it will look like a brown disc.
- **Second layouts are the unknown.** The 14 px rule and "not a mirror of layout 0" are easy to state and hard to
  judge; expect one round of sending back. Whether one second layout is enough on a wide wheat plain shows only on
  the map (the variants sheet's 5 x 4 block is the first look).
- **The mirror moves things, it does not flip them.** A landmark built from several `p.stand` calls comes apart in
  the mirror unless its parts are tied with `on=`. That is what the mirror check in tasks 5 and 6 is for. Seen today
  (modules not yet updated): timber's mound smoke sits about 2 px off in the mirror.
- **The coast on other sides is tested only with the demonstration piece** (`contract.py`), not with salt and
  harbour: they are still written for the south side and fail on another side until task 4. With the sea behind the
  land (north), boats stand behind the buildings; that may need its own look.
- **The harbour add-on is not drawn yet.** The in-map test still uses the style frame's own quay, moles and ships at
  the ports as a stand-in.
- The footprint is measured, not designed: a faint overlay (alpha under 0.25) clears nothing, and a wild tree may
  stand up to the edge of a field. If workers find it too tight or too loose, the two numbers (`grow`, `front`) are
  in one place in the kit.
- The kit's wild land (`kit.wild`) is a stand-in for the map's on the sheets. The real map's woods are denser and
  follow the terrain; the sheets cannot show that.
- The reference sheets (`wheat.png`, `settlements.png`) and the overview still show the pieces before the answers;
  they change with task 5 and the final `overview.py` run.
- The 10 px rule shrinks the usable hex. Level 3 coverage of "about 70%" is now measured inside that margin.
- Spring against summer (section 2) is open until someone tries the stronger spring tone on the map.
- Winter in the map test is still a stand-in.

**Round 3**

- **The carved harbour is not drawn yet.** Until task 9 the open-shore layout stands in Genoa's bay, and the bay
  is cut 84 px wide for it instead of 72. The picture shows that the harbour fits the hex, not the final basin.
- **A carved bay moves the coast further than the style frame's cove rule** (4.2 km against 3.5; 6.8 km from the
  frame's first line with the frame's own cove). **Answered in round 4:** up to 5 km for carved ports only.
- **The bay eats the town's front.** A city fills its hex; the bay's back lies 18 px from the centre, just in
  front of the wall, and the suburb houses and plots there are left out. Settlements' second layout should keep
  the front of the ring free of anything that matters.
- **The winter rule is tuned on one region.** Coastal hexes with high mountains behind them (Savona 758 m,
  the Riviera 1,100 m) are mild only because the height is counted less near the sea; the same trick may be wrong
  for a fjord coast. Tune on the whole map (guide section 12, point 2).
- **A piece takes one winter, the test's ground follows the index point by point.** At the border of two winters
  a snow-roofed piece can stand on ground that is half green (the olives west of Savona). It reads as a
  transition; if it bothers, the map can pull the border to the hex.
- **The safety net hides old lines** (the table in "Round 3"). A new module that paints snow by the season will
  look right on the sheets and wrong only in the mild winter; the checklist now asks for the three winters.
- `winters.png` shows settlements as the module stood while its second layout was being drawn; run
  `winters.py` again when that task is back. `overview.png` was not run in this round for the same reason.

**Round 4**

- **Sixteen families is a crowd.** The crowding table (guide section 4) names the pairs and the rules, but the
  rules are untested until the sheets are back; expect to send hemp, cotton and silk back once (they are all
  "rows or blocks on farm land"). Task 25's one-page look-alike review is the real test.
- **Big ideas, small units.** The old tiles are loved for one bold object filling the hex. At this scale the
  quarry is an 18 px face and Hagia Sophia a 12 px dome. The owner may find them less striking than the tiles he
  picked from; the first wave (quarry, dye works, ores, vineyard, sites) shows it early.
- **Landmarks at 20 x 24 px** carry one silhouette idea each; minarets and the campanile are 1-4 px wide and may
  vanish at 50%. If they do, the fix is a taller limit for landmark cities (an owner question then, not now).
- **Venice is not Venice without water.** It is drawn as a city at a lagoon shore until the island rule is
  designed (guide section 12, point 1).
- **The quarry's stepped face and the fur post's stockade are local drawings** (`p.stand`), not kit calls; their
  mirrors need the `x=` care of section 6. If two families end up wanting a straight palisade, it moves to the kit.
- **Third layouts change `kit.pick` for those families**: with three layouts every hex of a class shows that
  class's layout, so the in-map pictures of vineyard, grazing and castles all change when tasks 18 to 20 land.
- **Mulberry's autumn** (gold and late green by turns) may read as a row of small haystacks at 50%; task 13
  reports on it.
- **Task 9 was reviewed in the map only** this round (Genoa, and the four findings of task 24), not line by line
  against its brief.
- **The tables give counts and sizes that were not drawn first.** Coverage for the contour vineyard, the three
  paddocks and the furs bands is estimated; a worker who cannot meet a number reports it rather than bending
  the picture.
- Whether the map data will place these goods, sites and landmark cities at all is a game question; the pieces
  only wait for it.
