# Normal-map pieces: the review

Art director, 2026-11-15. **Status: the owner answered the three questions on 2026-11-15 (section 6). The kit, the
guide and the in-map test follow the answers; fix tasks 1 and 2 are done; tasks 3 to 6 are written to the answers
and wait for workers (section 4). Nothing in the game is changed.**

All ten families are drawn. This is the review of the eight new ones against `GUIDE.md` (the two reference
families were checked again too), with the findings of the in-map test (`../pieces_in_map/notes.md`) folded in.

**Look at `overview.png` first**: every family and every level on one page (summer on top, six families in winter
below). The per-family sheets (`<family>.png`) show all four seasons and the 50% test. `kit_contract.png` shows what
the owner's answers mean in the kit: wild land, the coast on any side, the footprint, the mirror.

## Verdict in one paragraph

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
- **Names.** No plates. Where town names show at this zoom is open (guide section 12, point 5).

## 4. Fix tasks

Six tasks. **Tasks 1 and 2 are done.** Tasks 3 to 6 are open, share no file and can run in parallel:

| Task | Files | What |
|---|---|---|
| 1 (done) | `castles.py`, `mines.py` | The first fixes |
| 2 (done) | `vineyard.py`, `olives.py` | The first fixes |
| 3 | `grazing.py`, `timber.py` | The first fixes, the wild-land rules, **second layouts for both** |
| 4 | `salt.py`, `harbour.py` | The first fixes, the wild-land rules, **the coast contract**, the harbour add-on |
| 5 | `wheat.py`, `settlements.py` | The rule fixes, the wild-land rules, **wheat's second layout**; settlements: roads to gates, no plate strip |
| 6 | `vineyard.py`, `castles.py`, `mines.py`, `olives.py` | **Vineyard's second layout**; the wild-land rules and the mirror check for all four |

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
"then the rest"), once tasks 3 to 6 show how much variety one second layout buys on the map.

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
