# The map, thread 4: how the map is generated

Technical director, 2026-11-14. **Status: design for the owner. Nothing is built.** Reads with `00-brief.md`,
`01-terrain-and-relief.md`, `02-water.md`, `03-settlements-and-roads.md` and `05-tiles-and-objects.md`. This thread owns the final **socket
vocabulary** (section 3).

| File | What it shows |
|---|---|
| `04_pipeline.png` | The build steps in order, and which kind of method does each. |
| `04_sockets.png` | What one hex edge carries, and why two hexes can never disagree about it. |
| `04_prototype_steps.png` | The prototype region built step by step by a throw-away script, on today's grid (hexes about 57 km). |
| `04_prototype_steps_fine.png` | The same script and data on hexes half as wide (about 28 km). |
| `04_proto/` | The throw-away scripts behind every number here: `proto.py` (the pipeline on the region), `bench.gd` (speed in Godot), `diagrams.py`. Not game code. |

---

## 1. The short version

- **Recommended model: "skeleton first, puzzle last".** The things that must be right over long distances (where the
  mountains stand, where a river reaches the sea, which road joins Milan to Genoa) are **computed** by methods made for
  them. Wave function collapse (WFC, the "puzzle solver") then fills in what is local: the **ground cover** (farmland,
  woods, marsh, rock, snow) and, later, which **picture variant** each hex gets.
- **Why not one big WFC for everything:** WFC only looks at neighbours. It cannot promise that a river arrives at the
  sea or that a road arrives at a city, and the number of tile types it would need runs into the billions (section 4).
  Threads 1, 2 and 3 each reached the same conclusion from their side.
- **One language joins the steps: edge sockets.** Every fact about the border between two hexes (a river runs along it,
  a road crosses it on a bridge, it is a crest, a pass, a shore) is stored **once, on the edge**. Both hexes read the
  same record, so they cannot disagree. Tiles are not solved; they are **looked up** from the six edge records.
- **It works on the prototype region.** A script built the western Alps, the Po plain and the Ligurian coast from the
  repo's geography files plus a few added rivers and towns: 24 builds (8 seeds, 3 hex sizes), every river reached the
  sea or the map edge, every town was on the road network, every pass carried a road, and no check failed.
- **It is fast.** Measured in Godot 4.7.2: the whole of Europe on today's grid in **0.3 to 1.0 second**; on hexes half
  as wide (about 122,000 hexes) in **1.1 to 15 seconds**, depending only on how the road search is written (section 6).
- **Hex size: 28 km is feasible** for generation, memory and file size. Two things were not measured here and are the
  real cost of the smaller hex: drawing the far zoom, and the AI's path searches during play (section 7).

---

## 2. The pipeline

See `04_pipeline.png`. Each step only adds facts. A later step never changes an earlier one; it may only fail a
check, which stops the build and names the hex.

| # | Step | Method | Reads | Writes |
|---|---|---|---|---|
| 0 | **Fixed facts** | Loaded from `godot/data/geography` | The coastline polygons, lakes, the big rivers, mountain lines with heights, named passes, cities | Land or sea per hex; the lines and points as given |
| 1 | **Relief** | Thread 1's height model: the skeleton of ranges, valleys and anchors, plus seeded noise, cut into levels | Step 0 | A height level per hex; crest edges where a range's spine runs between two hexes; pass edges; valley floors |
| 2 | **Water** | Thread 2's river pass: the real rivers snapped onto hex edges; everything else drains downhill | Steps 0-1 | River edges with size and flow direction; lake edges; mouths; shore kinds; sea depth |
| 3 | **Ground cover** | **Wave function collapse** | Level, water, climate | One cover per hex (farmland, grass, woods, marsh, rock, snow...) |
| 4 | **Settlements** | Thread 3's scoring: real cities keep their hex, the rest by site score with spacing | Steps 0-3 | Settlement level, castle, landmark, port per hex |
| 5 | **Roads** | Thread 3's routing: cheapest paths on a cost field | Steps 1-4 | Road level per edge; the crossing kind where a road meets a river, a lake or a pass; quays |
| 6 | **Sockets and checks** | One pass over all edges and corners | Everything | The packed edge records; a list of failed checks (must be empty) |
| 7 | **Art** | Lookup, drawn lines, objects on a map-wide grid (thread 5) | Step 6 only | Pictures. No game state. |

Why this order:

- **Relief before water**, because water runs downhill. Crests are walls for water: a river may not run along a crest
  edge.
- **Water before cover**, because marsh and farmland want wet ground and snow wants height.
- **Cover before settlements and roads**, because woods and marsh cost a road more, and a town wants arable land.
- **Settlements before roads**, because roads join places. **Roads after water**, because every river a road meets
  needs a ford, a bridge or a ferry, and that price steers the road to the good crossing (Pavia, Piacenza).
- **Sockets last**, because they are a summary of the solved map, not a thing to be solved.

What is fixed, what is generated:

| Fixed from real geography | Computed from it (same every build) | Generated from the seed |
|---|---|---|
| Coastline, lakes, big rivers, mountain lines and heights, named passes, cities | Height levels, crest edges, which edge a named pass opens, the edge course of a real river, shore kinds | The noise on the heights, small streams, ground cover, villages, minor roads, picture variants |

A **random world** uses the same steps 1 to 7. Only step 0 changes: a generator invents the coastline, the ranges, the
river sources and the city sites, in the same file shapes. That keeps one pipeline, not two.

### Rulings where the threads differed

1. **Rivers run along hex edges, from corner to corner** (thread 2's recommendation). A river is a line you cross,
   not a hex you stand in. Roads and valley floors run from hex centre to hex centre and cross edges at the middle. So
   an edge has two kinds of place: the **middle** (what crosses) and the two **corners** (what runs along). An earlier
   draft of this thread, thread 3's wording and thread 5's mockups had the river crossing the edge middle and running
   through the hex, as the Python game does. The edge model wins on four counts:
   - **The crossing has one fixed place.** A road over a river edge meets it at the edge middle, so the ford, bridge
     or ferry is a plain edge value (thread 3's `crossing`). With a river through the hex, the bridge is somewhere
     inside the hex and a road that follows a valley must share the river's own crossing point, which needs side
     lanes on every edge (thread 5, section 8, item 2). **With rivers on edges no side lanes are needed.**
   - **The rules get a clean line.** Border, defence line, crossing cost and "which bank is the town on" are all
     answered by one edge record.
   - **The generator is simpler to check.** A river is a walk on corners with six corner words (3.3). Crests already
     work this way, so rivers, crests and shores share one mechanism and one art recipe (thread 5: "the art side is
     slightly simpler").
   - **It was built and measured** in this thread's prototype: 24 builds, no failed check.
   What it costs: a river on edges zigzags and must be smoothed when drawn (thread 2's recipe), and a town is *beside*
   its river (on one or more of its edges), never astride it. This is a look-and-rules choice as well as a technical
   one, so it is question 3 below; thread 2 asks the same question.
2. **Valleys (thread 1) stay a chain of hexes.** Thread 1 asked that mountain rivers follow valleys. With rivers on
   edges this becomes one checkable rule: *a river edge between two hexes of level 3 or higher must have a valley-floor
   hex on at least one side.* The river runs along the flank of the valley; the valley road runs through the hex
   centres beside it and crosses it on a bridge where it changes bank.
3. **Thread 1's edge height codes** (`elev:K`, `scarp_top`, `scarp_foot`) are **worked out, not stored**: relief is
   computed, so the two levels on either side of an edge are known, and the code is their difference. Art reads it the
   same way.
4. **A pass** is an edge value on today's grid. On a 28 km grid thread 1 makes it a saddle hex; then the hex carries the
   tag `saddle` and its two crest-side edges carry `pass`. One vocabulary serves both.
5. **Where a real river and a crest claim the same edge** (it happens: section 8), the river may win only at a
   **gorge that the relief data names**. An unnamed clash fails the build. The prototype lets the river win and reports
   each case, to show how often the present data clashes.

---

## 3. The socket vocabulary (final list)

See `04_sockets.png`. Three kinds of place carry facts: the **edge** (shared by two hexes), the **corner** (shared by
three) and the **hex** itself. Edge records are stored once per edge. A hex "has" six sockets only in the sense that it
reads its six edge records.

Edges are numbered from east, anticlockwise: 0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE (pointy-top hexes, odd rows shifted half
a hex right, as today). The edge a hex calls `e` is the edge its neighbour calls `(e + 3) % 6`.

### 3.1 Edge record

| Field | Values | Runs | Set by | Notes |
|---|---|---|---|---|
| `line` | `none`, `sea`, `shore`, `crest`, `pass`, `river1`, `river2`, `river3`, `lake` | along the edge | steps 0-2 | Exactly one per edge. `sea` is water on both sides, `shore` is land against sea or a lake hex. |
| `flow` | towards corner A or corner B; `still` | along | step 2 | For `river*` and `lake` only. `still` is a lake arm with no through-flow. |
| `shore_kind` | `beach`, `cliff`, `marsh`, `delta`, `lake` | along | steps 1-2 | For `shore` only. `cliff` when the land is level 3 or higher (thread 1's `coast:cliff`), else `beach`; `marsh` and `delta` from thread 2. |
| `lake_width` | `narrow`, `broad` | along | step 2 | For `lake` only. |
| `step` | `level`, `slope`, `scarp` | across | derived from step 1 | Levels equal, one apart, two or more apart. Signed: which side is higher. |
| `floor` | no, or yes with the downhill side | across | step 1 | A valley floor continues across this edge (thread 1's `valley:in/out`). `head` is the same on a pass edge. |
| `road` | 0 none, 1 track, 2 road, 3 highway | across | step 5 | Thread 3's road quality. |
| `crossing` | `none`, `ford`, `bridge_wood`, `bridge_stone`, `ferry`, `pass`, `quay` | across | step 5 | How the road gets over the `line`. Required whenever `road` > 0 and `line` is a river, lake or pass. `quay` sits on a `shore`, a `lake` or a `river2-3` edge of a port hex. |
| `border` | no, or the two country tags | along | later (thread 5 and the game) | Reserved. Follows the same corner rules as a shore. |
| `cover` | `same` or `blend(a, b)` | across | derived from step 3 | Never stored: read from the two hexes. Decides the soft blend between ground colours. |

Sixteen bits hold a record (appendix B).

### 3.2 Which values may share an edge

| `line` | `road` allowed? | `crossing` | `floor` allowed? | Other rules |
|---|---|---|---|---|
| `none` | yes | `none` | yes | |
| `crest` | **no** | | no | Never a river. Water does not drain across it. |
| `pass` | yes | `pass` | yes (`head`) | Only where the data names a pass, or where a pocket of land would otherwise be shut in (today's "join pockets" rule). |
| `river1` | yes | `ford`, `bridge_wood` | yes | |
| `river2` | yes | `ford` (if fordable), `bridge_wood`, `bridge_stone` | yes | |
| `river3` | yes | `bridge_wood`, `bridge_stone`, `ferry` | yes | A bridge only beside a town (thread 3). |
| `lake` | yes | `ferry` | no | |
| `shore` | no (a `quay` only) | `quay` | no | Land on the shore side is level 1 or 2 unless `cliff`. |
| `sea` | no | | no | Depth is a hex tag; neighbouring depths differ by one step at most. |

### 3.3 Corner rules (checked by the build, not by WFC)

Three edges meet at every corner. Lines must continue through corners; that is what makes a river a river.

| Corner word | River edges in / out | Where allowed |
|---|---|---|
| `dry` | 0 / 0 | anywhere |
| `source` | 0 / 1 | hills or mountains, a spring line, or a lake |
| `run` | 1 / 1 | the out end is not higher than the in end |
| `join` | 2 / 1 | anywhere; the size may step up below it |
| `mouth` | 1 / 0 | only at a corner that touches sea or a lake hex |
| `split` | 1 / 2 | only at a delta corner (marsh coast, last corner before the sea) |
| `lake_in`, `lake_out` | as `run` | a `lake` edge begins or ends here; the river keeps its size through the lake |

- **Shore:** every corner has 0 or 2 shore edges (true by construction from land and sea).
- **Crest:** a corner has 0, 2 or 3 crest-or-pass edges; 1 only where a range ends (its levels fall off) or at the sea.
- **River against crest:** a river corner may sit on a crest line only at a named gorge.

### 3.4 Hex facts (not sockets)

Never constrained across an edge by a socket; some are constrained by the cover rules of step 3.

| Owner | Facts |
|---|---|
| Thread 1 | `level` 0 to 6, `height_m`, `valley` (with its axis edges), `saddle`, `cover` (the WFC result), fertility, ore |
| Thread 2 | `sea_depth` (shelf, sea, deep), `bay`, `cape`, `harbour_shelter` 0-2, `marsh` share, `floodplain`, `lake_shore` |
| Thread 3 | `settlement` 0-5, `capital`, `castle` 0-3, `landmark`, `port`, and the art tags (`site`, spill counts, switchback) |

### 3.5 What the earlier proposals became

| Proposed | In the final list |
|---|---|
| Thread 1 `elev:K` | `step` plus the two hex levels (derived) |
| Thread 1 `scarp_top`, `scarp_foot` | `step = scarp` with its sign |
| Thread 1 `crest`, `crest:pass` | `line = crest`, `line = pass` |
| Thread 1 `valley:in`, `valley:out`, `valley:head` | `floor` with its downhill side; `head` on a pass edge |
| Thread 1 `coast:low`, `coast:cliff` | `shore_kind = beach` or `cliff` |
| Thread 2 `edge.dry`, `river.N.cw/ccw` | `line = none`, `line = riverN` with `flow` |
| Thread 2 `lake.n/b.cw/ccw/still` | `line = lake` with `lake_width` and `flow` |
| Thread 2 `coast.beach/cliff/marsh/delta/lake` | `line = shore` with `shore_kind` |
| Thread 2 `sea.shelf/sea/deep`, `ridge` | `line = sea` plus the hex tag `sea_depth`; `line = crest` |
| Thread 2 corner words | section 3.3, unchanged |
| Thread 3 `road` 0-3, `crossing`, `quay` | `road`, `crossing` (with `quay` as one of its values) |
| Thread 3 "river class crossing at the edge midpoint" | The river runs along the edge; the **road** crosses it at the midpoint, where the bridge sits |
| Thread 5 river crossing point (midpoint or along the edge) | Along the edge (its model B) |
| Thread 5 side lane positions | Not needed: a road and a river never run through the same point side by side |
| Thread 5 shore type, corner flags, hex tags | `shore_kind`; the corner words of 3.3 (derived, not solved); 3.4 |

---

## 4. How many tiles, and how it stays small

**If every combination were its own tile:** an edge can be in roughly 9 line states, 3 steps, 4 road levels and 2
floor states. Even after removing the forbidden mixes that is over 100 states per edge and far more than a billion
combinations per hex. Nobody can draw that, and no solver can search it.

**The measured picture.** The prototype counted what actually occurs:

| | 57 km grid (63 land hexes) | 28 km grid (253 land hexes) |
|---|---|---|
| Different river patterns on a hex's six edges | 23 (10 after turning) | 26 (9) |
| Different road patterns | 27 (11) | 31 (11) |
| Different crest patterns | 17 (5) | 18 (5) |
| Different coast patterns | 8 (3) | 10 (4) |
| Different whole hexes (level, cover and all four patterns) | 63: **every hex is unique** | 184 (158 after turning) |

So whole tiles do not repeat, but each **layer on its own** uses only a handful of shapes. Three devices keep it small:

1. **Layers, not tiles.** A hex is drawn as a stack: ground (level and cover), then lines (shore, river, crest), then
   roads and crossings, then objects. Each layer has at most 64 edge patterns (two states on six edges), which is **14
   shapes** once you allow turning by 60 degrees. The stack multiplies on screen, not in the library.
2. **Rules, not tiles, for everything long.** Rivers, crests, shores and roads are never "tiles that must match". They
   are computed as paths, so they match by construction. The corner rules of 3.3 are tests, run once.
3. **WFC only where choice is local.** Ground cover needs about ten kinds and a short list of forbidden neighbours.
   That is a small, fast puzzle (0.1 second for Europe, section 6).

**Turning (rotation).** A pointy-top hex has six turns and six mirror images. Turning is safe for **flat line work**
(a river bend, a road fork). It is **not** safe for anything shaded: the look is lit from the left, and a turned
mountain would be lit from below. So: line layers are drawn by code through the shared points (no stored tiles at
all); shaded objects are never turned, they are placed.

---

## 5. Contradictions, backtracking and the seed

### What can go wrong, and what happens

| Where | What | Response |
|---|---|---|
| Inputs (step 0) | A real river and a crest claim the same edge; a pass point with no crest near it; a city in the sea | **Stop and report** the place. It is a data error; fix the data file. Never patched at build time. |
| Relief (step 1) | Two neighbours differ by more levels than the slope rule allows | Thread 1's limiter smooths it, or marks a `scarp`. |
| Water (step 2) | A hollow with no way out | Cannot happen: the downhill pass fills hollows as it goes (appendix C). A lake is placed there if the data names one. |
| Cover (step 3, WFC) | A hex is left with no allowed cover | See below. |
| Roads (step 5) | A town shut in by crests | One extra pass is opened on the cheapest crest edge and named after the nearest town (today's rule). |
| Final checks (step 6) | Anything | Stop and report. The Europe map is not shipped with a failed check. |

### WFC dead ends

Today's solver (`hexa/campaign/wfc.py`, `godot/core/mapgen/wfc.gd`) never fails: when a hex would be left with no
option it quietly keeps its options, which means a forbidden pair can slip onto the map with no report. On today's
shipped Europe map that has not happened (measured: 0 forbidden pairs on 41,160 land edges), because the priors are
loose. The new model has tighter rules, so it needs a real answer:

1. **Check the inputs first.** Before any choice is made, the rules are applied to the starting options. A dead end
   here means the *relief and the cover rules contradict each other* (for example a level 1 hex beside a level 6 hex,
   with no cover pair allowed between them). It is reported as a data or rule error with its hex. In the stress test,
   **half of all dead ends were of this kind** (151 of 308): no amount of searching could have solved them.
2. **Undo and retry.** Each choice is logged. On a dead end the last choice is undone, that option is struck out and
   another is drawn. The stress test had only this one-step undo: it was used 108 times, and 86 placements still
   had to be relaxed, which is why steps 3 and 4 exist.
3. **Re-solve a small patch.** If a hex has run out of options, the choices within two hexes of it are cleared and
   solved again with a fresh draw (bounded: 8 tries).
4. **Bridge covers.** The rule table always contains a cover that may touch both sides of a hard border (rock between
   snow and pasture, scrub between woods and dry ground), so step 3 nearly always succeeds.
5. **Last resort, counted.** If all that fails the least-bad cover is placed and the hex goes on a list. For the
   Europe map the list must be empty or the build fails. For a random world the list is logged and the map is used.

In the prototype region, with its own cover rules, there were **no dead ends at all** in 24 builds: relief does most
of the separating before the puzzle starts. On the finer grid the stress test also had none (0 of 57,644), because
slopes are gentler when hexes are smaller.

### Same seed, same map

- One seeded source of luck per step, seeded from `hash(map seed, step name)`. Adding a draw to one step never
  shifts another step's luck.
- Ties are broken by hex position, never by the order of a dictionary or a set.
- Costs in the path searches are whole numbers (as today's road builder does).
- Noise comes from an integer hash, not from the engine's noise class, so it cannot change with an engine upgrade.
- **Measured:** the Godot WFC gave the same digest twice for one seed and another digest for another seed; the
  Python pipeline gave byte-identical reports under two different hash seeds.

**The Europe map is built once and shipped as a file** (as `godot/data/maps/europe_1480.json` is today), so every
player has the same checked map and nobody waits. Random worlds are built on the player's machine, with the progress
bar the shell already has.

---

## 6. Speed (measured)

Godot 4.7.2 headless, GDScript, one developer PC, flat packed arrays (no dictionary keyed by position, no object per
hex). `04_proto/bench.gd`; three runs each, typical values.

| Step | Today's grid: 203 x 150 = 30,450 hexes (14,411 land) | Half-width hexes: 406 x 300 = 121,800 (57,644 land) |
|---|---|---|
| Neighbour table | 17 ms | 66 ms |
| Relief from the mountain lines | 70 ms | 280 ms |
| Drainage: downhill pass and flow sums | 36 ms | 125 ms |
| Ground cover WFC, with undo | 109 ms | 450 ms |
| Sockets and checks | 16 to 31 ms | 78 to 93 ms |
| Roads: about 380 / 1,520 searches that stop at the nearest town | 31 ms | 78 ms |
| Roads: the same searches run to their full cost limit (worst case) | 690 to 740 ms | 13,900 to 14,300 ms |
| **Total** | **0.3 to 1.0 s** | **1.1 to 15 s** |
| Memory held by the generator's arrays | 1.0 MB | 3.9 MB |

- Everything except the road search grows in step with the number of hexes (four times).
- The road search is the one step whose cost depends on how it is written. A search that stops when it reaches the
  network costs almost nothing; one that floods its whole reach costs 16 times more on the finer grid (four times the
  searches, each over four times the area). The real figure lies between; the design rule is **always stop at the
  goal, and cap the reach in kilometres, not hexes**.
- For comparison, today's Godot build of the Europe map takes about 4 seconds (the note in `map_build_steps.gd`); it
  uses dictionaries keyed by position and an object per heap entry. The same work on packed arrays is several times
  faster. That is a rule for whoever builds this: **packed arrays inside the generator**.
- The river pass here runs on hexes; on corners (two per hex) it is about twice the work: about 70 ms and 250 ms.
- None of this runs during play. The 16 ms frame budget is not touched by generation.

---

## 7. Hex size: 57 km or 28 km

Threads 1, 2 and 3 all prefer about 28 km. From the generation side:

| | 57 km (today) | 28 km |
|---|---|---|
| Hexes for Europe | 30,450 | about 121,800 |
| Generation in GDScript (measured) | 0.3 to 1.0 s | 1.1 s with stopping road searches; 15 s worst case |
| Generator memory (measured) | 1 MB | 4 MB |
| Map file (estimate, appendix B) | about 0.3 MB packed; today's JSON is 2.6 MB | about 1.2 MB packed; about 10 MB if kept as today's JSON |
| Drawing at play zoom (estimate, not measured) | about 1,900 hexes on a 1920 x 1080 screen | the same: the screen shows the same number of hexes at the same hex size in pixels |
| Drawing the whole map at once (estimate, not measured) | 30,000 hexes, about 9 pixels each | 122,000 hexes, under 5 pixels each: must be pre-drawn in chunks or as one picture |
| Path searches during play, AI (not measured) | as today | about four times the hexes per search, and twice the hexes per day's march |
| In the prototype | 3 cities lost their hex to a bigger neighbour; 2 named passes (Great St Bernard, Simplon) lost their edge to a river | every city has a hex; all 12 passes open |

**Plainly: 28 km is feasible.** Generation, memory and file size are not a concern at either size. Two conditions
come with it:

1. **The map view must draw in chunks** (pre-drawn blocks of hexes, redrawn only when something in them changes), and
   the far zoom must be a prepared picture. This is good practice at 57 km and necessary at 28 km. It needs its own
   measurement before the size is final: *a frame at every zoom under 16 ms on the target PC*.
2. **The game's own searches** (movement, supply, AI) do four times the work. This is where the Python game spent its
   time. It needs a measured AI season on a 122,000-hex map before 0.3.x commits to it.

A middle size is possible (about 40 km: 287 x 212 = 61,000 hexes, twice today's), but it helps less than it costs:
Milan and Como still share a hex, and every distance in the rules must be re-scaled anyway. **Recommendation: design
and mock up at 28 km now; confirm it for all of Europe after the two measurements above.** The model in this document
does not change with the size: only data numbers do.

---

## 8. How the art follows (for thread 5)

The art step reads **only** the output of step 6. It makes no decisions that the game depends on.

1. **Ground.** Level and cover pick the ground colour and texture. Where an edge's `cover` is `blend(a, b)` the two
   colours are blended across the edge; a `scarp` or `shore` edge gets no blend but a drawn face.
2. **Lines drawn along edges.** A river, a crest or a shore is one continuous curve along its chain of edges. Thread
   2's recipe pins the curve to the **middle of every edge** it uses and rounds it off at the corners, so the zigzag
   becomes a meander and a bridge at the edge middle always sits on the water. Width comes from the river size.
   Because the curve is built from points that both neighbouring hexes share, it has no break at a hex border. Crests are a chain of peaks drawn
   on the crest edges, with a saddle at a `pass`.
3. **Routes drawn across edges.** A road is one curve from hex centre to hex centre through the **middle** of each
   edge it uses. A hex with three road edges gets a fork at its centre. The crossing piece (ford, bridge, ferry,
   hospice at a pass, quay) is placed on the edge middle. A valley floor is a pale ribbon through the same middles.
4. **Objects on a map-wide grid.** Trees, peaks, fields and houses are scattered on one grid for the whole map, not
   per hex (as mockup 07 does), so a wood or a range runs across hex borders without a seam. A hex's cover and level
   decide what may stand on the grid points inside it; lines and roads clear a strip.
5. **Settlements** are one piece per level at the hex centre, with thread 3's spill of fields and suburbs on the same
   grid.

What the library needs, at most: about 12 ground looks; line strokes for 3 river sizes, 2 lake widths, 4 shore kinds
and the crest; road strokes for 3 levels; 6 crossing pieces; the object sets. **No piece exists per edge pattern.**
Variants (three looks of a wood, say) are picked by a hash of the hex position and the seed, so they never flicker.

A useful test for thread 5: draw the same hex twice, once from each of two neighbouring chunks. The pixels along the
shared edge must be identical.

---

## 9. The prototype region, step by step

`04_prototype_steps.png` (57 km) and `04_prototype_steps_fine.png` (28 km): the same script, the same data, two hex
sizes. Window: 5.7 to 11.3 east, 43.25 to 47.15 north. The repo's geography has only the Po, Rhone and Rhine here, one
Alpine line, one Apennine line, 9 cities and 6 passes; the script adds the Ticino, Adda, Dora Baltea, Dora Riparia
and Tanaro, three lakes, two mountain lines, 20 towns and 4 passes by hand (listed in `proto.py`). The pictures are
diagrams of the model, not art.

**Step 0, fixed facts (panel 0).** The coastline polygon gives 63 land and 9 sea hexes at 57 km (253 and 35 at
28 km). The Ligurian coast is a straight run of sea hexes from Nice to La Spezia with Genoa at the top of the bay.
Cities are forced to be land.

**Step 1, relief (panel 1).** Height falls off from the mountain lines; a little seeded noise is added; four classes
are cut (the real build uses thread 1's seven levels and its hand-built skeleton, which will look far better than
this stand-in). The crest is every edge the Alpine line passes between two hex centres: 19 crest edges at 57 km, 56 at
28 km, in one unbroken chain from the Maritime Alps round to the Brenner, plus the Ligurian Apennines. Each named
pass opens the crest edge nearest to it (orange).

**Step 2, water (panel 2).** Each real river is snapped to a chain of hex edges that hugs its true course and ends at
a corner on the sea, the map edge or another river. The Po runs east along the edges south of Turin, Pavia and
Piacenza; the Dora Baltea, Ticino and Adda come down from the north and join it at corners; the Tanaro comes up from
the south. Milan's hex lies between the Ticino and the Adda. Lake stretches (Maggiore, Como, Geneva) are river edges
flagged `lake`. Then every other corner is drained downhill and the busy ones become streams (8 stream edges at
57 km). River size comes from the water collected: the Po grows from 1 to 3 on its way east. A mountain hex beside a
real river becomes a valley floor, one class lower than its walls (13 hexes: the Valais, the Val d'Aosta, the
Valtellina, the Ticino valley).

- *Finding:* the script reported 6 places at 57 km (3 at 28 km) where a real river and the crest wanted the same
  edge, for example the Rhone leaving the Valais and the Dora Baltea below the Great St Bernard. At 57 km this cost
  two named passes their edge. These are the "gorges" that thread 1's data must name; at 28 km there is room for
  both.

**Step 3, ground cover (panel 3).** WFC chooses per hex among the covers its class allows: farmland, grass, woods and
(by big rivers) marsh on the plain; downs and wooded hills; alp and rock; rock and snow on top; meadow, woods or
farmland on a valley floor. Like sticks to like, so the Po plain comes out as blocks of farmland and woods and the
high Alps as a snow band. 12 forbidden pairs; no dead end in any run.

**Step 4, settlements (panel 4-5).** The real cities take their hexes. At 57 km three places lose theirs to a bigger
neighbour in the same hex (thread 3 shows them as satellite names); at 28 km none do. Then villages are added by
score (riverside, confluence, coast, lake, flat ground) with a minimum spacing.

**Step 5, roads (panel 4-5).** Each place is joined to the growing network by the cheapest path, nearest to Milan
first; a road already built costs almost nothing to reuse, so trunks form. Crest edges are walls; the passes are the
only gates, and each pass that no road has used pulls one over it (8 extra pass roads). Every road edge that lies on
a river gets a crossing: at 57 km the script placed 7 fords, 7 wooden bridges, 2 stone bridges, 1 ferry and 10 pass
roads. Genoa reaches the plain over the Giovi; Turin reaches France over Mont Cenis; the Gotthard road comes down the
Ticino valley to Bellinzona and Milan. The road levels in the picture are crude (the script only counts how many
routes share an edge); thread 3's rules replace them.

**Step 6, sockets and checks (panel 6).** One record per edge. The checks run: every river edge leads, corner by
corner, to the sea or the map edge; no river on a crest or shore edge; no road over a crest; no road end outside a
settlement or a pass; every road over a river has a crossing. **0 failures in 24 builds.**

**Step 7, art.** Not drawn here. Panel 6 is exactly what thread 5's art would be given.

---

## 10. How to prove it is safe when it is built

Measure, and fail the build on:

| Check | Pass mark |
|---|---|
| The checks of step 6 on the Europe map | 0 failures |
| WFC last-resort placements on the Europe map | 0 |
| Same seed built twice, on Windows and Linux | identical map digest |
| 200 random worlds | 0 failed river or road checks; last-resort list logged, under 0.1 % of hexes |
| Named places: every city, pass and river of the geography files | present, within one hex of its true position |
| Generation time, Europe | under 2 s (57 km) or 5 s (28 km) on the reference PC |
| Seam test (section 8) | identical pixels on shared edges |

The generator keeps the house rules of `godot/README.md`: it lives in `core/`, makes no engine calls beyond data
types, takes its luck only from `core/rng.gd`, and each step is one small module with its own tests. Each step's
output is a plain data block that the next step reads, so a step can be tested alone with a hand-made input.

---

## 11. Risks and what is not finished

- **The prototype's relief is a stand-in** (distance to a line plus noise). Thread 1's skeleton model replaces it; the
  pipeline does not depend on how the levels are made.
- **Zigzag rivers.** A river on hex edges zigzags by nature. Thread 2's smoothing is essential and is not shown in
  this thread's diagrams.
- **Data work.** The geography files need the tributaries, lakes, extra ranges, towns and passes that all four
  threads added by hand, and thread 1's list of named gorges. This is authoring time, not code.
- **Rendering and AI cost at 28 km were not measured** (section 7). They decide the hex size, not this model.
- **Corner storage** (two corners per hex) is new to the code base; today's map has only hexes and edges.
- **Game rules read sockets too** (a river edge costs movement, a crest blocks). Those rules are out of scope here,
  but they must read the same edge records as the art, never a second copy.
- **Delta splits** (one river into two at the sea) are allowed by the vocabulary but were not exercised: the Po's
  mouth lies outside the prototype window.

---

## 12. Questions for the owner

1. **Is "skeleton first, puzzle last" the model?** Mountains, rivers, towns and roads are computed step by step from
   the real geography, and wave function collapse only chooses the ground cover and picture variants.
   - **Recommended: yes.** Every river reaches the sea and every road reaches its town, by construction; the real
     places are where they belong; Europe builds in about a second.
   - Other: one big wave function collapse over full tiles. Closer to the name on the brief, but it cannot promise
     long connections and needs an impossible number of tiles.
2. **Hex size: go to about 28 km?**
   - **Recommended: yes for the design and mockups now, confirmed for all of Europe after two measurements** (a frame
     of the map at every zoom, and one AI season, both on a 122,000-hex map). Generation is not the obstacle: 1 to 15
     seconds, 4 MB.
   - Other: stay at 57 km. Nothing to prove, but Milan, Como and Pavia share hexes and two Alpine passes lose their
     place to a river.
3. **Do rivers run along the borders between hexes?** (Thread 2 asks the same.)
   - **Recommended: yes.** A river is then a line on the map that you cross at a bridge, a ford or a ferry; it can be
     a border and a line of defence; Milan lies between the Ticino and the Adda; the generator and the art are both
     simpler and the prototype already works this way.
   - Other: rivers run through the middle of hexes, as in the Python game. A town can sit astride its river and the
     river art is a little more natural, but a river can never be a border or a crossing, a valley road needs side
     lanes on every edge, and a bridge has no fixed place.

A decision taken here without a question, as the planning session's default: **the Europe map is built once, checked,
and shipped as a file**; random worlds are made fresh from their seed (section 5).

---

## Appendix A. The three models compared

| | A. One WFC over whole tiles | B. A WFC per layer, each with edge sockets | C. Skeleton first, WFC for cover (recommended) |
|---|---|---|---|
| Tile types | over a billion in principle | 14 to 64 per layer | about 10 covers |
| A river reaches the sea | not guaranteed | not guaranteed; needs a repair pass | guaranteed |
| A road joins two given towns | not guaranteed | not guaranteed | guaranteed |
| Real geography respected | only as soft weights | as fixed cells, then luck | exactly |
| Dead ends | frequent, costly | per layer | rare and local |
| Used before in this repo | no | `hexa/campaign/wfctiles.py` did coasts this way and laid rivers and roads as paths anyway | today's terrain WFC is this model's step 3 |

## Appendix B. Data layout

- **Hex index** `i = row * cols + col`. All per-hex facts are packed arrays indexed by `i`.
- **Edges.** Each hex owns three edges: E, NE, NW. Edge index `i * 3 + k`. A hex reads its other three from the
  neighbours that own them. (`bench.gd` does exactly this.)
- **Corners.** Each hex owns two corners: its top (N) and its upper-right (NE). Corner index `i * 2 + k`.
- **Edge record, 16 bits:** `line` 4, `flow` 2, `shore_kind` or `lake_width` 3, `step` with sign 3, `floor` with side
  2, `road` 2. `crossing` (3 bits) goes in a second small array that only road edges fill.
- **File size:** per hex about 4 bytes of hex facts and 6 bytes of edge records: 10 bytes. 30,450 hexes: 0.3 MB.
  121,800 hexes: 1.2 MB, before compression. Names, provinces and countries are extra and do not grow with hex count
  in the same way.
- **Turning a pattern:** a six-bit edge pattern `m` turned by one step is `((m << 1) | (m >> 5)) & 63`; the canonical
  form is the smallest of the six.

## Appendix C. The algorithms

- **Relief.** Thread 1's document. The stand-in used here: height = max over lines of `top * (1 - distance / reach)`,
  plus two octaves of integer-hash value noise.
- **Crest edges.** As `godot/core/mapgen/ridges.gd` today: an edge is a crest when the range's line cuts the segment
  between the two hex centres an odd number of times.
- **Snapping a real river.** A cheapest-path search on the corner graph from the corner nearest the source. An edge
  costs its length times `(1 + 4 * distance from the true course)`; a crest edge costs extra; edges touching sea are
  not allowed. The search may end at any corner on the sea, the map edge or an earlier river, at a price of six times
  the distance from the true mouth, so it ends where the real river does.
- **Drainage.** Priority flood: start from all sea, map-edge and real-river corners in a heap ordered by height; pop
  the lowest; each undrained neighbour drains into it and is pushed at `max(its height, this height + a hair)`.
  Hollows are filled as the flood passes, so every corner gets a way down. Then flow is summed from the tops down.
  Corners above a threshold start streams; thresholds scale with hex area.
- **Ground cover.** Domains as bit masks; the hex with fewest options first (a heap, ties by a hash of position);
  weight = prior * (1 + affinity * neighbours already of that kind), as today; an undo log of (hex, old mask) for
  backtracking.
- **Settlements, roads.** Thread 3's document. Roads: Dijkstra with whole-number costs, stopping at the first network
  hex; a built road edge costs 1.
- **Checks.** Section 9, step 6, plus the corner rules of 3.3.

## Appendix D. The measurements in full

Prototype (`python 04_proto/proto.py SUB SEED`), seed 1480:

| | SUB 1 (57 km) | SUB 2 (28 km) | SUB 3 (19 km) |
|---|---|---|---|
| Hexes (land) | 72 (63) | 288 (253) | 648 (567) |
| Crest edges / passes open | 19 / 10 | 56 / 12 | 99 / 13 |
| River edges (real / streams) | 41 / 8 | 95 / 2 | 144 / 8 |
| River edges by size 1 / 2 / 3 | 17 / 23 / 9 | 40 / 41 / 16 | 75 / 54 / 23 |
| River against crest clashes | 6 | 3 | 3 |
| Settlements (real kept / merged / generated) | 23 / 3 / 3 | 26 / 0 / 8 | 26 / 0 / 21 |
| Road edges | 54 | 127 | 199 |
| WFC dead ends | 0 | 0 | 0 |
| Failed checks | 0 | 0 | 0 |

Stress test of the cover WFC in Godot (14 covers, harsh made-up rules, the real land mask): 14,411 hexes, 308 dead
ends, of which 151 came from the inputs before any choice. After that the one-step undo was used 108 times and 86
placements were relaxed, leaving 33 forbidden pairs on about 41,000 edges (the bench has no deeper undo). On the 28 km grid: 0 dead
ends.
