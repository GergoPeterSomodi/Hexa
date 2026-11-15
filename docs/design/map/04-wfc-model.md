# The map, thread 4: how the map is generated

Technical director, 2026-11-14. **Status: design for the owner. Nothing is built.** **Updated the same day for the
owner's decisions** (quoted at the top of `README.md`): rivers run along hex edges, with the river-city exception of
section 3.6. Reads with `00-brief.md`,
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
- **One exception, decided by the owner: river cities.** In a short hand-written list of cities (Florence, Paris,
  Prague, Rome...) the river runs *through* the city hex, corner to corner over the centre, with the bridge inside
  the city. Everywhere else rivers stay on edges. It costs one hex fact and two corner words, and no new edge value
  (section 3.6). The prototype script has not been run with it yet.
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
| 0 | **Fixed facts** | Loaded from `godot/data/geography` | The coastline polygons, lakes, the big rivers, mountain lines with heights, named passes, cities, the river-city list (3.6) | Land or sea per hex; the lines and points as given; the pinned hex of each river city |
| 1 | **Relief** | Thread 1's height model: the skeleton of ranges, valleys and anchors, plus seeded noise, cut into levels | Step 0 | A height level per hex; crest edges where a range's spine runs between two hexes; pass edges; valley floors |
| 2 | **Water** | Thread 2's river pass: the real rivers snapped onto hex edges, and through the hex of each listed river city (3.6); everything else drains downhill | Steps 0-1 | River edges with size and flow direction; lake edges; mouths; shore kinds; sea depth; `river_through` on the river-city hexes |
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
| Coastline, lakes, big rivers, mountain lines and heights, named passes, cities, the river-city list | Height levels, crest edges, which edge a named pass opens, the edge course of a real river, the two corners a river city's river uses, shore kinds | The noise on the heights, small streams, ground cover, villages, minor roads, picture variants |

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
   one, so it was question 3 below. **The owner decided it on 2026-11-14: edges, except in a short list of river
   cities** (ruling 6).
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
6. **River cities (the owner's exception to ruling 1).** In a city on the authored list the river leaves the edges
   at a corner of the city hex, runs over the hex centre to another corner and returns to the edges. The city and
   its bridge sit on the river. The rule is section 3.6. It is built so that none of the four gains of ruling 1 is
   lost: crossings elsewhere keep their fixed place, the six edges of the city hex stay free for roads (no side
   lanes), the river is still a walk on corners, and the frontier rule holds everywhere outside the city.

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

Sixteen bits hold a record (appendix B). River cities (3.6) add **no edge value**: their river is a hex fact.

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

**River-city hexes** (3.6): none of the six edges of such a hex may have `line` = `river*` or `lake`. So a road into
the city never needs a river `crossing` on those edges: the bridge is inside the hex.

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
| `city_in` | 1 / 0 | only at the in corner of a river-city hex (3.6); the river goes on through the hex, so this is not a `mouth` |
| `city_out` | 0 / 1 | only at the out corner of a river-city hex; the out edge has the size of the in edge, so this is not a `source` |

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
| Thread 4 | `river_through` (in corner, out corner), only on the hexes of the river-city list (3.6) |

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
| The owner's exception: a river through a city (first sketched as edge values `river_in`, `river_out`) | The hex fact `river_through` and the corner words `city_in`, `city_out` (3.6); no edge value |

### 3.6 River cities (the owner's exception to "rivers on edges")

**In plain words.** In a few famous cities the river does not run past the city, it runs through it: Florence on the
Arno, Paris on the Seine, Prague on the Vltava, Rome on the Tiber. For those cities only, the river leaves the hex
edges at one corner of the city hex, crosses the hex over its centre and goes back onto the edges at another corner.
The city stands on both banks and its bridge is inside the hex. The list is written by hand and stays short. Everywhere
else ruling 1 holds: rivers on edges.

**The geometry.** Corners are numbered like edges: corner `k` lies between edge `k` and edge `k + 1` (0 upper right,
1 top, 2 upper left, 3 lower left, 4 bottom, 5 lower right). Three edges meet at a corner of a hex H. Two are H's own
edges. The third lies between two of H's neighbours and points straight at H's centre: call it the corner's **spoke**.
A river that comes down a spoke arrives at the corner already heading for the city centre. So the river chain:

1. comes down the spoke of the **in corner** (a river or lake edge like any other),
2. runs corner, centre, corner inside H,
3. leaves by the spoke of the **out corner**.

Nothing touches H's six edges or their middles.

**Two forms**, written per city in the list:

| Form | Corners | Picture | For |
|---|---|---|---|
| `through` (the default) | opposite: `out = in + 3` | The river runs straight across; the city is on both banks; the bridge is at the centre | Florence, Paris, Prague |
| `loop` | two apart: `out = in + 2` or `in - 2` | The river swings round the far side of the centre; the city sits inside the bend | Toledo, Verona |

Neighbouring corners are never used: that would be the edge between them, which is the normal model.

**Through may bend (2026-11-14, coordinator's ruling, Florence).** A `through` city may also take corners two apart (`out = in + 2` or `in + 4`): the river bends inside the hex, the city stays on both banks and the bridge stays at the centre. The opposite corner is preferred when both fit; `loop` keeps its own meaning (the city sits inside the bend) and is the art form for loops.

**Why at the corners, and not across the edge middles.** The first sketch of this exception had the river cross two
of H's edges at their middles (`river_in` and `river_out` as new edge values). Both were weighed:

| | A. In and out at corners (chosen) | B. In and out across edge middles |
|---|---|---|
| Joining the edge river | Direct: a river on edges is always at a corner | Needs a half edge: the river must run half way along one of H's edges and turn in |
| Roads into the city | All six edge middles stay free for roads | A road entering by the river's edge shares its point: the side lane comes back |
| New edge values | None; the 16-bit record is unchanged | Two, each with a flow sense across the edge |
| Banks | Each of H's edges lies wholly on one bank | The in and out edges lie on both banks at once |
| Seams in the art | The river passes a point that three hexes already share | A new shared point on the edge middle |

A is the model here. B stays possible if the owner prefers its look; it costs the items in its column.

**What is stored.**

- A hex fact `river_through` = (`in` corner, `out` corner), on the listed hexes only. The form follows from the two
  corners and the size from the in spoke. It lives in a small side table, not in the per-hex arrays (appendix B).
- Two corner words, `city_in` and `city_out` (3.3). Like all corner words they are worked out and checked, not stored.
- **No edge value.** The art tag `site = river_city` (thread 3's `site` list) picks the town piece.
- In the authored list: the city, its river, the form, and the bridge kind inside the city (`bridge_stone` unless the
  entry says `bridge_wood`).

**Rules.**

1. **Listed only.** A hex has `river_through` if and only if it is the hex of a city on the list. The generator never
   adds one on the Europe map. (A random world's step 0 may write its own list, in the same shape.)
2. **Pinned hex.** A river city's hex is the hex that contains its true position. It is fixed in step 0, before the
   water step, and step 4 does not move it. (Other real cities are snapped within one hex after the water is known;
   a river city cannot wait for that, because the water needs its hex.)
3. **Clean edges and corners.** None of H's six edges has `line` = `river*` or `lake`, and H's four other corners are
   `dry`. So there is no second river beside the city, no confluence in it, and no stream starts at it. `shore`,
   `crest` and `pass` edges are allowed on H; the in and out corners follow the crest rule of 3.3.
4. **In corner:** exactly one river or lake edge, the spoke, flowing towards the corner. Or the **lake outlet** case:
   the corner touches a lake hex and has no river edge (Geneva, where the Rhone leaves its lake through the city).
5. **Out corner:** exactly one river edge, the spoke, flowing away, of the same size as the in spoke. Or the
   **estuary** case: the corner touches sea or a lake hex and has no river edge; it is then the river's mouth (Pisa,
   and Rome if its hex reaches the sea).
6. **Downhill:** the out corner is not higher than the in corner. Thread 1's carving under a fixed river applies to H
   as to any hex the river touches.
7. **In the mountains:** an H of level 3 or higher must carry the `valley` flag (ruling 2, said for a hex).
8. **A real town:** H holds a settlement of level 3 or more (town, city, great city). If not, the build stops and the
   list is fixed.

**Borders.** Borders run on edges, so a hex is never split: a river city has one owner, on both banks. Outside the
city the river edge is still the natural frontier, as before. Where a frontier follows the river past a river city,
the border leaves the river at the in corner, goes round the city hex on one side (three edges for a `through` city)
and rejoins the river at the out corner. The owner of the city then holds a bridgehead on the far bank, which is
what such cities were. No new border value and no new check: the border keeps the corner rules of a shore.

**Crossings and roads.** By rule 3 no edge of H is a river edge, so **no `crossing` is ever placed on H's edges** for
the river. Roads from both banks meet at the centre; the bridge is part of the city's picture. For the road builder,
entering or leaving H costs no river crossing, so trunk roads are drawn through river cities, as in history. The
direct step between the two neighbours on either side of a spoke is an ordinary river edge with the ordinary crossing
rules. Which bank an edge of H lies on is worked out from the corners:

| Form | One side | Other side |
|---|---|---|
| `through`, in corner `i` | edges `i + 1`, `i + 2`, `i + 3` | edges `i + 4`, `i + 5`, `i` |
| `loop`, corners `i` and `i + 2` | edges `i + 1`, `i + 2`: the dry neck | the other four: across the river |

A river city that is a port has its quay inside the hex too (there is no river edge to put it on): `port` together
with `river_through` means a river quay in the city piece. The river stays navigable through H if it is navigable on
both spokes.

**Suggestions for the rules (default D11, not decided here).** Moving into or out of a river city never crosses a
river. Whoever holds the city holds the crossing. An attacker reaches the city from either bank without the river
penalty, because a quarter of the city stands on his bank; so a river city is a prize, not a stronger fortress. River
boats pass through the hex, and its owner can close the river to them.

**The river pass (step 2).** For every listed city on a river, before that river is snapped:

1. H's six edges are taken out of the corner graph, and a node for H's centre is added, joined to H's six corners.
   Each of H's corners can now be reached only by its spoke or from the centre.
2. The river is snapped in legs: source to H's centre, then H's centre to the next river city or to the mouth, with
   the usual cost (appendix C). The two corners used at H must fit the form. The pass tries the pairs the form allows
   (6 for `through`, 12 for `loop`) and keeps the cheapest that runs downhill; ties go to the lower corner number.
3. If no pair works (a crest, the sea, uphill), the build stops and reports the city. It is a data error.
4. The drainage pass that makes the small streams treats H's edges as closed and H's four other corners as dry.

**Checks (step 6).** Added to the list of section 9 and to the table of section 10:

- The list and the `river_through` records match one to one; each hex is land and lies on the city's true position.
- Rules 3 to 8, each by name, with the hex.
- The two corners fit the form.
- The river walk (every river edge leads, corner by corner, to the sea) steps from the in corner to the out corner of
  a river-city hex as one step.
- No edge of a river-city hex has a `crossing` of `ford`, `bridge_wood`, `bridge_stone` or `ferry`.

**The art (for thread 5).**

- **The river inside the hex** is the same strip recipe as on the edges: one curve pinned at the in corner, at the
  centre and at the out corner (for a `loop`, at a point about 0.45 of the hex radius beyond the centre, away from the
  neck). No sprite. The curve passes the two corners, which both neighbours share, so the seam test holds.
- **The `through` city** is the town recipe of levels 3, 4 and 5 run with a clear channel for the river: 3 levels x 3
  river axes (corners 1-4 upright, 0-3, 2-5) = **9 baked pieces**. They are lit, so they are baked per axis and never
  turned. The flow direction does not change the picture.
- **The bridge** sits at the centre. The river axis of a `through` city is at right angles to one of the three road
  axes, so the three bridge sprites per kind that the library already has fit as they are. One new piece: a bridge
  with houses on it for a great city, 3 axes = **3 pieces**. Embankment walls are an edging in the strip recipe.
- **The `loop` city** is the ordinary town piece at the centre, moved a little towards the neck, with the river curve
  round it and standard bridges where the roads of the four far edges cross the curve. No new piece.
- **Level-ups** never change the corners ("sockets never move", thread 3): the picture changes, the river does not.
- Named bridges (the Ponte Vecchio, the Charles Bridge, London Bridge) belong to the later landmark-cities work.

**How a city gets on the list.** All five must hold in 1480:

1. The walled city stood on both banks, on a river island, or inside a loop of the river.
2. It had at least one permanent bridge.
3. The river was not a frontier between countries at the city (a river city hides the river as a frontier).
4. It is not at a confluence or in a delta (rule 3 needs clean corners).
5. It is a town or more (level 3 and up), and its river is in the river data.

**The first list for Europe** (12; a cap of about 25 for all of Europe is suggested):

| City | River | Form | Bridge | Why |
|---|---|---|---|---|
| Florence | Arno | through | stone | Four stone bridges in 1480, the Ponte Vecchio among them; the Oltrarno quarter inside the walls. Named by the owner. |
| Pisa | Arno | through | stone | Walled on both banks, bridges in the middle of the city. Close to the sea: the estuary case. |
| Rome | Tiber | through | stone | Trastevere and the Borgo walled on the far bank; Ponte Sant'Angelo, Ponte Sisto (1470s), the island bridges. Named by the owner. |
| Verona | Adige | loop | stone | The old city lies inside a tight bend of the Adige; the Roman Ponte Pietra and the Castelvecchio bridge. |
| Paris | Seine | through | stone | The Ile de la Cite with bridges to both banks; the walls take in both banks. Named by the owner. |
| London | Thames | through | stone | London Bridge, with houses on it, and Southwark as its bridgehead; the lowest bridge on the Thames. |
| Prague | Vltava | through | stone | The Old Town and the Lesser Town, joined by the stone bridge. Named by the owner. |
| Basel | Rhine | through | stone | Great Basel and Little Basel, both walled, joined since 1225 by the one bridge on that stretch of the Rhine. |
| Toledo | Tagus | loop | stone | The Tagus gorge wraps the city on three sides; the Alcantara and San Martin bridges. |
| Geneva | Rhone | through | wood | The Rhone leaves Lake Geneva through the city, with bridges over its island: the lake outlet case. |
| Novgorod | Volkhov | through | wood | The Sophia side and the Trade side, joined by the Great Bridge. |
| Liege | Meuse | through | stone | The Meuse runs through the city; the Pont des Arches joins the two parts. |

In today's data the cities Pisa, Verona, Basel, Geneva and Liege are missing (they go on the notable places list), and
so are the rivers Arno, Tiber, Adige, Vltava, Volkhov and Meuse (they go in the tributary file). Second wave, same
test: Bern (a loop; it must first be a level 3 town), Zurich, Lucerne, Maastricht, Wurzburg, Nuremberg, Salzburg,
Besancon, Dresden.

**Cities that stay beside their river**, and why:

| City | River | Why it stays on the edge |
|---|---|---|
| Cologne | Rhine | No bridge in 1480 (the Roman one was long gone); the city lies wholly on the left bank. A ferry. |
| Vienna | Danube | The city stood back from the main stream, among side arms with wooden bridges. `bridge_wood`. |
| Buda | Danube | Buda and Pest were two towns with no permanent bridge between them. A ferry. |
| Seville | Guadalquivir | The city is on one bank, joined to Triana by a bridge of boats; and it is a port for ocean ships, which needs its quay on a river edge. |
| Lyon | Rhone and Saone | A confluence: the join needs its corner (test 4). A "confluence city" form with two in corners is possible later. |
| Avignon | Rhone | The Rhone there was the frontier of France: it must stay an edge (test 3). |
| Regensburg | Danube | The city is on the south bank; its Stone Bridge is a typed crossing, an authored `bridge_stone` on a great river. |
| Milan, Venice | | No river through them: Milan's canals and Venice's lagoon are art and later features. |

**In the prototype region** (5.7 to 11.3 east, 43.25 to 47.15 north):

| City | River | Ruling | Why |
|---|---|---|---|
| Verona | Adige | **River city, `loop`** | The clearest case in the region, and the Adige is already on the region's tributary list. |
| Florence | Arno | **River city, `through`** | At the south-east corner of the window; the owner's own example. The Arno must be added. |
| Pisa | Arno | River city, second step | Tests the estuary case once Florence works. |
| Geneva | Rhone | River city, second step | Tests the lake outlet case. |
| Turin | Po | **Stays beside** | In 1480 a small town on the left bank, at the join of the Po and the Dora Riparia: a confluence site (test 4), with a wooden bridge outside the walls. |
| Pavia | Ticino | **Stays beside** | The city is on the left bank; its covered bridge leads to a small suburb. The Ticino is a frontier and "the bridge at Pavia" is the region's showpiece of a typed crossing; the join with the Po is one corner away. |
| Piacenza, Cremona | Po | Stay beside | South-bank towns with a ferry or a boat bridge; the Po is the region's great barrier. |

So the prototype shows both forms (Florence and Verona) and keeps its edge showpieces (Pavia, Turin, the Adda and
Ticino frontiers).

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
   on the crest edges, with a saddle at a `pass`. In a river-city hex the same river curve leaves the edges at the
   in corner, passes the hex centre and rejoins the edges at the out corner (3.6).
3. **Routes drawn across edges.** A road is one curve from hex centre to hex centre through the **middle** of each
   edge it uses. A hex with three road edges gets a fork at its centre. The crossing piece (ford, bridge, ferry,
   hospice at a pass, quay) is placed on the edge middle. A valley floor is a pale ribbon through the same middles.
4. **Objects on a map-wide grid.** Trees, peaks, fields and houses are scattered on one grid for the whole map, not
   per hex (as mockup 07 does), so a wood or a range runs across hex borders without a seam. A hex's cover and level
   decide what may stand on the grid points inside it; lines and roads clear a strip.
5. **Settlements** are one piece per level at the hex centre, with thread 3's spill of fields and suburbs on the same
   grid. A river city uses the city-on-river piece for its level and river axis, with the bridge at the centre (3.6).

What the library needs, at most: about 12 ground looks; line strokes for 3 river sizes, 2 lake widths, 4 shore kinds
and the crest; road strokes for 3 levels; 6 crossing pieces; 12 river-city pieces (3.6); the object sets. **No piece
exists per edge pattern.**
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
settlement or a pass; every road over a river has a crossing. **0 failures in 24 builds.** (The script has no river
cities: the checks of 3.6 are designed, not yet run. Verona and Florence are the first two to add.)

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
| River cities: the list against the map (3.6) | every listed city has its river through its own hex; 0 failed rules |
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
- **River cities (3.6) are designed on paper only.** The prototype script was not re-run with them. Before the Godot
  water step is called done: Verona (`loop`) and Florence (`through`) built at 28 km over 8 seeds with 0 failed
  checks, and one build with a wrong entry (a river city on a confluence) that must stop and name the city. The
  lake outlet and estuary cases (Geneva, Pisa) are allowed by the rules and need the same proof.
- **A river city pulls roads.** Its crossing is free for the road builder, so trunks will bend towards it. That is
  intended, but the list must stay short or every river gets a free bridge every few hexes.

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
3. **Do rivers run along the borders between hexes?** (Thread 2 asks the same.) *Answered 2026-11-14: yes, along the
   edges, but through the city in a short authored list of river cities (section 3.6).*
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
- **River cities:** a side table of (hex index, in corner, out corner), one entry per listed city: a few dozen
  entries for Europe, so no per-hex array and no change to the edge record.
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
  the distance from the true mouth, so it ends where the real river does. A river with a listed river city is
  searched in legs through that city's hex centre (3.6, "The river pass").
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
