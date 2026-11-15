# Normal-map pieces: the review

Art director, 2026-11-15. **Status: for the owner and the planning session. Nothing in the game is changed.**

All ten families are drawn. This is the review of the eight new ones against `GUIDE.md` (the two reference
families were checked again too), with the findings of the in-map test (`../pieces_in_map/notes.md`) folded in.

**Look at `overview.png` first**: every family and every level on one page (summer on top, six families in winter
below). The per-family sheets (`<family>.png`) show all four seasons and the 50% test.

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
| Settlements (reference) | **Fix (rules only)** | The art is the bar. Its roads run to the hex border (new rule H). The plate strip waits for owner question 1 |
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
  told apart. That is correct (they are the same terrain), and it is the reason for owner question 3.

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

For the planning session, not made:

- **K, relief.** The map's duty, to be written into the map plan: no range, spur or hill inside or in front of a
  piece's footprint; an all-peak hex takes no piece. Recommended as stated in the test notes.
- **N, fields.** Once pieces are in, the map draws no field parcels of its own. Recommended.
- **C, D, G, J, L** are the three owner questions in section 6.

## 4. Fix tasks

Five tasks, no file shared, so they can run in parallel. Each worker: change only the named module(s), run them to
rewrite the sheets, check that no `PIECE PROBLEM` line is printed, look at the sheet at 100% and 50%, then run
`overview.py`. The kit is not edited in a task; report gaps.

**Common to every task (the new rules)**

- C1. **No road to the border.** End every `p.road(...)` at a gate point at least 10 px inside the border and add a
  `GATES = {"south": (x, y), ...}` table to the module. Drop the points beyond it.
- C2. **Overlays.** Replace every scrub or trodden-ground blob whose colour is a mix or shade of the base ground by
  `p.scrub(x, y, w, h, dark)` or `p.blob(x, y, w, h, colour, alpha=)`. `mix(ground, X, t)` becomes
  `p.blob(..., X, alpha=t)`; `shade(ground, f)` becomes `p.scrub(..., dark=1 - f)`. The summer sheet must look the same.
- C3. **10 px margin** for fields, plots, pans, yards, ponds, canals and activity details. Move or shrink what breaks it.
- C4. **No private kit calls** (`p.gp...`, `kit._smoke`). Use `p.smoke(x, y, always=True, foot=y)`, `p.blob(edge=)`,
  `p.over`, `p.jetty([points], snow=True)`, `p.wall(col=)`, `p.pond(col=)`, `p.terrace(face=)`, `p.animal(sc=, col=)`.

**Task 1: `castles.py` and `mines.py`**

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

**Task 2: `vineyard.py` and `olives.py`**

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

**Task 3: `grazing.py` and `timber.py`**

Grazing (the biggest job)
- Meadows are the signature and must carry at 50%. New sizes (before the tilt): 40 x 24 at level 2; two more of
  30 x 20 and 22 x 26 at level 3, so fenced meadow covers about 20% / 45% / 65% with the level 1 trodden patch.
  Keep all 10 px from the border and clear of the byre's front gap.
- Meadow colour: clearly paler than the ground in every season. Summer about `kit.mix(grass, (232, 228, 150), 0.5)`;
  put it in the module as a named token and report it. Winter: `SNOW` inside the fence with two `SNOW_D` hoof-trodden
  blobs, so the fence does not enclose plain background.
- Sheep: at level 1 they stand on a trodden patch that is nearly their own colour. Darken the patch
  (`p.blob(..., p.pal["soil"], alpha=0.3)`) and give sheep the kit's default body; they must show as light dots.
- Level 1 against level 0 at 50%: the herd's patch 36 x 16, the hut's yard as an overlay.
- Young animals: `p.animal(x, y, kind, sc=0.7)`; drop the local `young_animal` and the three colour tokens.
- Smoke: `p.smoke`. Scrub: C2. Track: C1.

Timber
- Smoke of the mound: `p.smoke(x, y, always=True, foot=...)`; the sawmill's too.
- Level 3 clutter: remove the fourth log pile at (38, 17) or move it 6 px left; two standing things there have feet
  closer than 4 px.
- Clearing and work patches: C2 (`p.blob(..., p.pal["soil"], alpha=0.6)`). Track: C1.
- The stream lies at y = +32, inside the 10 px margin at the front, and runs border to border. Leave it for now: it
  depends on owner question 3 (who draws streams). Say so in the module's header.

**Task 4: `salt.py` and `harbour.py`**

Salt
- Level 1: four pans, not three, and a trodden path from the hut to the pans (`p.blob` overlay), so it differs from
  level 0 at 50%.
- Feeder channel: `p.water` in `kit.mix(river, shallow, 0.5)` is not possible, so draw it with `p.over` at alpha 0.8;
  it must not be brighter than the sea. It ends at the shore, not in the sea.
- Winter drifts: fewer and flatter now that the winter sand is pale (kit change). Remove the two top drifts.
- The jetty: straight out from the shore (not diagonal), `p.jetty(a, b, snow=True)`. Scrub: C2. Private `p.gp` glints in
  the pans: `p.over` or drop them.

Harbour
- **The moles.** Draw two real moles with `p.jetty([points], w=3.6, stone=True, snow=True)`: west from (-30, 12) down
  to (-30, 27) and curling in to (-18, 31); east from (34, 12) to (34, 27) and in to (22, 31). They close a basin
  with a mouth about 40 px wide. The lighthouse stands on the west mole's bend; ships and boats lie inside the basin.
- Fishing boats: size 0.7, not 0.55 (they read as dots). Keep ships at 1.0.
- The beached boat: move it in to about (-36, 6); it sits on the border now.
- Quay snow: `snow=True`, drop the local snow lines. Beach widening and hut patches: C2.
- The shore and the sea side depend on owner question 2; do not rework the coast yet.

**Task 5: `wheat.py` and `settlements.py` (rules only, the art stays)**

- Wheat: the canal ends in a small pond at each end at about x = -36 and +36 (`p.pond`, 8 x 5); the three poplars
  stay. Move the front block and its sheaves and reaper up so nothing worked lies below y = +34 or within 10 px of
  the border. Track: C1.
- Settlements: the three roads end at gate points (south, east, west) 10 px inside the border: C1. Garden plots: C3.
  The plate strip is not touched until owner question 1 is answered.

## 5. Kit changes made in this review

All new arguments are optional; modules run unchanged. Pictures were compared before and after, pixel by pixel.

| Change | Effect on existing sheets |
|---|---|
| `take_apart()`, `Piece.layers()`, `Piece(base=)`, `stand(lift=)` | None |
| `over()`, `scrub()`, `blob(alpha=, edge=)`; tracks drawn as 75% overlays | Tracks differ by at most 13 of 255 on a few pixels (not visible) |
| `terrace(face=)`, `jetty([points], snow=)`, `pond(col=, edge=)`, `wall(col=)`, `animal(sc=, col=)`, `smoke(always=, foot=)` | None |
| Winter roofs: 1 px eave band in the roof colour (houses, churches) | **Intended**: every winter piece with a house, most of all `settlements.png` |
| Winter smoke is grey (`SMOKE_SNOW`) | **Intended**: winter pieces with smoke, `wheat.png` and `settlements.png` included |
| Winter `sand` 226,218,186 to 234,230,214 | **Intended**: winter salt and the winter beach in harbour |
| `wheat.py`, `settlements.py`: one scrub and one trodden-ground blob turned into overlays | At most 4 of 255 (not visible) |

Not added to the kit, because one family uses them: stumps, raft, hull on a slip, lighthouse, headframe, vats.
They stay local to their modules.

## 6. Owner questions

1. **Where does a town's name plate go?** The plates do not fit under the towns: all 14 in the test cross into the
   hexes below.
   - **(a) Recommended: move the town up and the plate in.** The plate starts 10 px below the hex centre; the town's
     middle moves up about 8 px and the two walled levels get a slightly smaller ring. One redraw of the settlement
     layout table.
   - (b) Keep the towns; let the plate hang over the hex's lower point and cover what is below.
   - (c) Smaller plates at this zoom.
2. **Coasts and ports.** A piece draws its own sea on the south side, but the real shore lies wherever the map has
   it, and Genoa is a city and a harbour in one hex.
   - **(a) Recommended: the map owns the shore, and a port is a town with harbour works.** Coast pieces (salt, harbour,
     coastal towns) are told which side the sea is on and stand at the map's shore; in a town's hex the harbour
     family is drawn as an add-on at the shore (quay, moles, lighthouse, ships), not as a second piece. A harbour
     alone stays a fishing-village piece.
   - (b) One piece per hex and the town wins: a port city shows no harbour.
   - (c) A separate set of "port town" pieces (five levels again).
3. **Who draws the wild land, and how much variety?** Today every piece brings its own trees and bushes and clears
   the map's; in woods that leaves a bald hex, and two hexes of the same level are the same picture.
   - **(a) Recommended: the map draws the wild land, the piece only the work.** The map's own trees stay and are
     thinned under the piece; "level 0" is then simply no piece. Each family gets a mirrored version and one second
     layout, picked by the hex, starting with the four most common (wheat, grazing, timber, vineyard).
   - (b) As (a) but mirror only: cheap, and repeats still show where four or more like hexes meet.
   - (c) Keep the pieces whole, as drawn now; accept the hex-shaped clearings and the repeats.

   This one should be answered before task 3 and 4 are finished: it decides whether level 0 pictures and the
   pieces' own streams and scatter are kept.

## 7. Risks and open ends

- The fix tasks are written against the sheets and the code as they stand; grazing and harbour are layout changes
  and need a second look when they come back.
- `take_apart()` was tested on wheat and harbour; the map test's own compositor was not changed and still uses its
  private route. It should switch to the kit's call in its next round.
- The 10 px rule shrinks the usable hex. Level 3 coverage of "about 70%" is now measured inside that margin.
- Spring against summer (section 2) is open until someone tries the stronger spring tone on the map.
- Winter in the map test was a stand-in; the eave band and grey smoke have been seen on the sheets only.
