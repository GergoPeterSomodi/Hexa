# Map thread 2: water (draft for the owner, 2026-11-14)

Rivers from source to sea, lakes, coasts, deltas and the sea itself, and how water joins across hex edges. Worked by hand on
the prototype region (northern Italy and the western Alps, the Duchy of Milan). Nothing here is built; the mockups use stand-in
relief colours, because relief is thread 1's.

| File | What it shows |
|---|---|
| `02_region_water.png` | The prototype region (13 x 11 hexes of today's grid): the Po and six tributaries on the hex corners, three lakes, a delta, three coast types, the sea bands. Numbered notes. |
| `02_river_model.png` | The same small patch with a river through the hex centres (the Python way), along the edges (recommended) and both; the ten corner cases, five allowed and five not. |
| `02_sockets.png` | The edge words, corner words and hex tags I need, drawn. |
| `02_scale_compare.png` | The Ticino, Lake Maggiore, Lake Como, the Adda and the Po at hexes of 57 km and 28 km. |

## 1. In plain words

**The river model in five lines:**

1. A river is a **chain of hex edges** (the line between two hexes), running from hex corner to hex corner, never through a
   hex centre.
2. It only runs **downhill**: every corner on the way is lower than the one before. It starts in hills or mountains and ends
   at a sea or a lake.
3. Every corner has three edges, so a **confluence** is simply two edges flowing into one. The river grows one **size**
   (stream, river, great river) when enough land drains into it. A river **never forks**, except in a delta.
4. A **lake** is a stretch of that chain drawn wide (a "lake edge"). The river enters at one corner and leaves at another.
5. The **named rivers are fixed** from the real geography (the 35 in the data, plus tributaries I add); **small streams are
   generated** from the relief. The sea has **depth bands** and no hex lines; coasts are **cliff, beach or marsh**.

Why edges and not centres: the edge between two hexes is the one place where "which bank am I on?" has an answer. An army
that steps across a river edge crosses the river. A bridge, a ford, a ferry, a siege from the far bank and a border all sit
on that same edge. In 1480 this is exactly how the Duchy of Milan worked: the Ticino was its western frontier, the Adda its
eastern one after the Peace of Lodi (1454), and Milan itself sits between them. On the mockup the Milan hex has the Ticino
on its west side and the Adda on its east side, from the data alone.

## 2. Goal

The player sees water as **roads and walls**. A great river is a wall that can be crossed only at a few bridges and ferries,
so the city at a bridge matters and the army that holds it matters. A river is also the cheapest trade road: goods go
downstream by boat, and the Po carries Piedmont's grain and Lombard cloth to Venice. A lake is a pocket of quiet trade
(Como's silk, Garda's olives). A coast is a choice: cliffs have no landing, beaches do, marsh gives salt and fish and
fevers. Rivers also give the map **memory**: when the player reads "the Adda line" he is reading history.

## 3. Rules

All numbers are named constants in a new data file `godot/data/water.json` (section A.1), never in code.

### 3.1 River edges and corners

- **Edge word:** `river.<size>.<direction>`, where size is 1, 2 or 3 (stream, river, great river) and direction is
  `cw` or `ccw`: the flow runs clockwise or counter-clockwise round the hex that owns the edge, so the hex on the other side
  sees the opposite word. This is how a direction is stored on an edge two hexes share.
- **Corner rules** (checked by the river pass, not by the wave function; see `02_river_model.png`):

  | Corner | In | Out | Allowed where |
  |---|---|---|---|
  | source | 0 | 1 | hills or mountains; at a spring |
  | run on | 1 | 1 | everywhere, strictly downhill |
  | join | 2 | 1 | everywhere; out edge is one size up if the basin crosses a threshold |
  | mouth | 1 | 0 | a corner touching sea or a lake hex |
  | split | 1 | 2 | only a **delta corner** (marsh coast, last corner before the sea) |
  | lake in / out | | | a lake edge begins or ends |

  Not allowed: a fork on dry land, a river going uphill, a river on a ridge edge, a river that vanishes in a wet land
  (dry lands may have wadis that end).
- **Size from the basin.** Each corner collects a weighted drainage area in km2 (rain weight 1.0 on plains, 1.5 on hills,
  1.8 on mountains; 0.3 in deserts). Constants: `SIZE1_KM2 = 1500`, `SIZE2_KM2 = 7000`, `SIZE3_KM2 = 30000`. Kept in km2
  so they do not change with the hex size. A river that leaves a lake is at least size 2. Result in the prototype: the Po is
  a stream for its first two edges, a river from Turin, and a **great river from the Ticino confluence on**; Ticino, Adda,
  Tanaro, Dora Baltea, Mincio and Adige are size 2.
- **Flags** (computed from size and relief, stored per river edge; thread 3 asked for them):
  - `fordable`: size 1 always; size 2 only where neither side is a valley wall or gorge; size 3 never.
  - `navigable`: size 2 downstream of its first lake or town of level 2, and size 3 always (Po from Turin, Ticino from
    Lake Maggiore, Adda from Lake Como, Adige from Verona, in 1480 terms: the Ticino and Adda were navigable by boat; the
    Naviglio canals are a later feature).
  - `confluence`: set on the corner (and on its three edges) where two rivers join: a town site (Turin, Pavia, Alessandria).
  - `crossing`: the **edge midpoint** is the crossing point. The drawn river curve is pinned to pass through every edge
    midpoint (section A.3), so a road that crosses the edge crosses the river at the bridge, with no error.
- **The river is the border between its two hexes.** Provinces on both banks stay separate hexes; a river edge is a natural
  frontier for the country borders thread 5 draws.
- **Hooks for the rules threads (suggested, not decided):** crossing a size 1 edge costs +1 movement point and a size 2 edge
  ends the move unless there is a bridge, ford or ferry; a size 3 edge needs a bridge or ferry. An attacker crossing a river
  edge fights at a penalty and a defender on the far bank gets a bonus. The numbers belong to the war and rules designers.

### 3.2 What is fixed and what is generated

| Water | Source | Fixed or generated |
|---|---|---|
| The 35 named rivers | `rivers.json` (a trunk polyline each; the Po has 6 points) | **Fixed.** Snapped onto the corner lattice (section A.2). |
| Tributaries | **Not in the data today.** A new file `rivers_extra.json` (section A.4): about 70 named tributaries and the prototype's ten | **Fixed** (real courses), same snapping. |
| Lakes | `land.json` has 5 lakes, **all in North America**. The Europe lakes must be added (section A.4) | **Fixed.** |
| Coast shape | `land.json` coastlines | Fixed; smoothed in art within a third of a hex. |
| Small streams (size 1) | none | **Generated** from relief: drainage above `SIZE1_KM2`, only where it rains enough. The real Trebbia, Taro and Panaro come out of the rule; they are not named unless the data names them. |
| Deltas, marsh | `terrain_shapes.json` marsh boxes (Po delta box exists: 11.6 to 12.6 E, 44.5 to 45.6 N) | Fixed boxes; the delta corner is generated inside them. |
| Sea depth | land mask | Generated: distance to land. |
| Random worlds | `randomgeo` | All of it generated: rivers from the relief's drainage, lakes in basins, the same rules. |

### 3.3 Lakes

- A lake is **one or more lake edges** on a river's chain: `lake.n.<dir>` (narrow) or `lake.b.<dir>` (broad), or `lake.n.still`
  for a dead-end arm. The river keeps its size through the lake. The art draws a lens along the chain, fatter for broad.
- A lake whose area is more than `LAKE_HEX_SHARE = 0.6` of a hex (Ladoga, Onega, Peipus, Vanern, Constance at 28 km) becomes
  a **lake hex** (water), drawn with the sea tile as the owner decided. Everything smaller stays an edge lake.
- At 57 km Maggiore (212 km2), Como (146) and Garda (370) are a hex fifth or a hex eighth each: **one or two lake edges**,
  drawn about twice too wide to be seen. At 28 km they are 4 to 6 edges and keep their true width (section 6).
- Small tarns (Lugano, Iseo, Orta, Albano) are art only: a pond object in a hex, carrying the `lake.shore` tag.
- A lake **shore** hex gets fish, ferry traffic and lake trade. Lake ports use the same quay as sea ports.

### 3.4 Coasts

Every land edge next to the sea carries one of three types, chosen from the land hex's relief and marsh share:

- **cliff** (relief level 3 or more behind it, or the data's Ligurian and Dalmatian ranges): no landing, harbours only in a
  bay or cove. The Ligurian Riviera is this; Genoa and Savona are ports because they sit in a cove.
- **beach** (low and dry): landing and port possible; sand rim.
- **marsh or lagoon** (marsh share 0.4 or more): shallow landing, salt, fishing; boats only. The Po delta and Venice's lagoon.

Hex tags, not edges: `coast.bay` (a sea hex with land on 3 or more sides, or a land hex whose coast bends round it),
`coast.harbour_shelter` 0 to 2 (0 open roadstead, 1 cove, 2 sheltered bay or river mouth: **thread 3's bay flag and harbour
shelter**), `coast.cape` (a land hex with 4 or more sea sides). **Islands:** a hex island is a land hex; smaller islands
(Elba, Capraia, the Venetian islets) are art in a shelf hex and do not appear in the rules. The data has 17 island polygons.

### 3.5 The sea

- Each sea hex has a `sea.depth`: **shelf** (up to 1 hex from land), **sea** (2 to 3), **deep** (4 or more); neighbouring
  hexes differ by at most one step. It comes from the distance to land, so it needs no sockets.
- **No hex lines on water.** The colour is a smooth field (light shallows, mid, deep), the coast is a smoothed contour, and
  the faint hex grid is drawn only over land. The coast contour stays within `COAST_SMOOTH = 0.34` hex of the true edge so
  ownership and ports still read right.
- Hooks: galleys keep to shelf and sea; ocean ships may use deep water (naval thread).

### 3.6 Deltas and marsh

A delta is a marsh coast where the river's last corner may **split into two or three mouths** (the only fork allowed): the
Po delta (Venice lagoon to Comacchio), the Rhone (Camargue), the Nile, the Danube, the Mississippi. The delta hex gets marsh
cover from thread 1; the mouths carry `coast.delta` edges. At 57 km the whole Po delta is one hex wide; at 28 km it is
two or three.

## 4. Player and AI

- The player reads rivers on the map (a line, a name, a size), on the hover card of a hex or edge (name, size, ford or
  bridge) and through the movement preview, which shows the crossing cost.
- The AI uses the same edge data: a river edge is a movement cost and a defence value in its path search, a bridge is a
  choke point it knows to hold, and a navigable river is a trade route it can load goods onto. Nothing in water needs
  hidden AI knowledge.

## 5. UI

- **Map:** rivers and lakes are an overlay layer drawn as smooth ink-outlined ribbons in the Kenney two-tone style (mockup
  `02_region_water.png`, sizes 1, 2, 3 at about 6, 10 and 16 px at play zoom). Names in italics along the course; lakes and seas
  in italics too, as in the close-up of `docs/design/godot-look/07_closeup_view.png`.
- **Crossings:** a small bridge, ford or ferry mark on the edge midpoint (thread 3 types them).
- **Hover card on a river edge:** name, size, fordable, navigable, the crossing cost.
- **Filters:** a map toggle "rivers and trade routes" (later), colour-blind safe because rivers are also named.
- No UI proposal in `docs/design/ui/` covers map objects; this adds none.

## 6. Hex size: what 57 km and 28 km mean for water

Thread 3 proposes halving the hex to about 28 km; thread 1 reaches the same finding for valleys. I measured it
(`02_scale_compare.png`, same window, same code, only the grid changed).

| | Hex 57 km (today; edge 33 km) | Hex 28 km (edge 16 km) |
|---|---|---|
| Po, Turin to the sea | 15 edges | 32 edges |
| Ticino / Adda / Dora Baltea / Tanaro | 5 / 6 / 4 / 3 edges | 14 / 17 / 9 / 9 edges |
| How far a snapped river strays from the real course (mean, worst) | 9 to 18 km, 29 km | 6 to 8 km, 19 km |
| Lake Maggiore (65 km long, 4 km wide) | 1 to 2 lake edges, drawn too wide | 4 to 6 lake edges, true width |
| Lake Como | 1 edge plus a dead-end arm: a V, not a Y | about 4 edges: a real Y at the Bellagio corner |
| Lake Garda (52 km, 17 km wide) | 2 broad edges | about 3 edges, wide enough to bulge |
| Tributaries | A chain of 3 to 6 edges: Ticino and Adda are one hex apart | Each has room for its own bend, towns on both banks and a bridge |
| Po delta | 1 hex wide: one mouth plus two stubs | 2 to 3 hexes wide: a real fan |
| Whole Po network (7 rivers) in the frame | 43 edges | about 100 edges |
| Cost | cheap | about double the edges and 4 times the hexes (thread 4 checks feasibility) |

**Answers to thread 3:** at 57 km Lake Maggiore and Lake Como can be **at most one or two edges**, not "more than one hex"; at 28
km they are chains of four to six edges and a lake can have a hex shore all round. Tributaries do not get their own **hexes**
at either size; they get their own **edge chains**, and at 28 km a chain is long enough to have towns on each bank.

**My recommendation for water alone: 28 km.** Rivers and lakes are the features that suffer most at 57 km: lakes cannot be
drawn to scale, Como cannot be a Y, tributaries are stubs, a river strays up to 29 km from where Pavia stands. The design is
the same at both sizes (every rule above is written in edges and km2), so the choice does not block this thread.

## 7. Interactions

- **Economy:** riverside hexes (a hex with a river edge) get fertility +0.15 (thread 1 owns the fertility number); size 2 and
  3 give a mill/fishing slot; **navigable river edges cut trade route cost** (goods move downstream, `RIVER_ROUTE_FACTOR`
  about 0.5). Lake shores get a fish slot. Floodplains of the Nile, Tigris, Euphrates and Niger (the data's
  `fertile_rivers`) get the `floodplain` tag: fertile strip, flood event.
- **War:** rivers are obstacles and defence lines (3.1 hooks); bridges and ferries are chokepoints; a siege can begin from
  the far bank only after a crossing; frozen rivers in winter could open crossings (later).
- **Tech:** a bridging/engineering tech turns fords into bridges cheaper; cartography reveals river names.
- **Debt:** none directly; a bridge's toll could be income later.
- **Naval:** river and lake ships use navigable edges; ocean ships need deep water.
- **Roads (thread 3):** a road crossing a river edge gets its `crossing` type from the river size (thread 3's table).

## 8. Risks

- **Zigzag.** Edges run at 60 degrees, so a river heading east zigzags (the Po in the mockup). The art must bend it through
  edge midpoints with soft corners; if it still looks mechanical, add meander noise (clamped to 0.2 hex). A visual risk, not a rule risk.
- **Lattice error.** At 57 km a river can land up to a hex off the real course, and pass the wrong side of a town (Venice
  touches the Po mouth in the data). At 28 km this is half as bad.
- **Too many rivers cut the map into islands.** If streams are dense they wall off every hex. Mitigation: streams are only size
  1 (always fordable); the generation threshold keeps them to about one per 6 hexes in wet land.
- **The Python data marks the Po valley as mountains.** Rivers must flow downhill, so thread 1's relief has to be right first
  (they report 39 mountain hexes in the frame instead of 82).
- **Rivers as exploits.** An army parked behind a size 3 river with only one bridge is unbeatable. Mitigation: a ferry
  always exists at any town of level 2 or more on a great river; sieges can cut a bridge.
- **Snowballing.** A country that owns a whole navigable river gets cheap trade. The river edge is shared by two hexes, so a
  neighbour holds the other bank. Cap the navigable bonus per route.

## 9. Smallest first version

1. The **river pass** only: the Po and the five tributaries of the prototype snapped onto corners, sizes from the basin,
   flags, rendered as ribbons through edge midpoints. No lakes, no deltas.
2. **Sea bands and the smooth coast** (cheapest big win, and no hex look on water).
3. **Lake edges** for Maggiore, Como and Garda, and the three coast types.
4. Then deltas, generated streams, floodplains, the rest of Europe.

## 10. Sockets I need

Full drawings in `02_sockets.png`. This is the proposal for thread 4's final vocabulary.

**Edge words** (shared by both hexes; the two sides see mirrored words):

| Word | Meaning |
|---|---|
| `edge.dry` | nothing |
| `river.1`, `river.2`, `river.3` + `cw` or `ccw` | river of that size, flow direction round the owning hex |
| `lake.n`, `lake.b` + `cw`, `ccw` or `still` | narrow or broad lake edge; `still` is a dead-end arm |
| `coast.beach`, `coast.cliff`, `coast.marsh` | land next to sea |
| `coast.delta` | a river mouth that may split (needs marsh) |
| `coast.lake` | land next to a lake hex |
| `ridge` (thread 1's) | never carries a river |

**Corner words** (checked by the river pass over the three hexes around a corner, **not by WFC**): `source`, `run`, `join`,
`mouth`, `split`, `lake_in`, `lake_out`.

**Hex tags:** `sea.depth` (shelf, sea, deep), `coast.bay`, `coast.harbour_shelter` (0 to 2), `coast.cape`, `marsh` (0 to 1),
`floodplain`, `lake.shore`.

**Rules for the combination:**

- A river edge needs land on both sides (or land and a lake hex); never sea on both sides.
- A river edge is never a ridge edge and never leaves a lower corner for a higher one.
- A hex may have any number of river edges; a corner has at most one out edge, except on a delta corner.
- Sea next to land: the sea hex's `sea.depth` is shelf. Marsh coast and cliff coast cannot be on the same edge pair.
- **Why not WFC:** a corner involves three hexes and a flow direction. Two-neighbour edge matching cannot enforce "one out,
  strictly downhill". So the rivers are routed **first** and written as fixed edge words; the wave function then collapses
  terrain and cover **around** them (a size 3 river prefers plain; a delta forces marsh).

**What I need from thread 1 (relief):**

1. A **height for every hex** (a number, not only a level) with sea at 0, so corners get a height (the mean of their three
   hexes). My check on a stand-in: 10 of 46 river steps went uphill, so the relief model must **carve** the valley under a
   fixed river (lower the hexes the river touches until it falls) or the river pass must be allowed to lower a corner by at
   most one level.
2. **Valley floor chains** with their axis edges (their `valley:in` and `valley:out`). In mountains a river edge must touch at
   least one valley hex and must not lie between two wall hexes, so rivers follow valleys.
3. **Ridge edges**: no river on them, except at a **gorge corner** (a valley that cuts a range: the Ticino through the Alps'
   foot, the Rhone at Martigny). Say which corners.
4. **Lake basins** at the valley mouths of Maggiore, Como, Garda, Lugano and Iseo, so lakes sit where the floor is flat and
   the hexes around the lake are not lower than its outlet.
5. **Marsh share** where I need delta corners (the Po box, the Camargue, the Nile).

**What thread 3 asked for, with answers:** river class per edge (stream, river, great river) crossing at the edge midpoint:
yes, `river.1/2/3`, and the curve is pinned to the midpoints. Confluence flag: yes. Navigable and fordable flags: yes (3.1).
Bay flag and harbour shelter: yes, hex tags (3.4). Marsh: yes, the `marsh` tag and `coast.marsh`. Po tributaries: not in the
data, which has only the Po trunk; section A.4 lists the ten I worked and the others that need adding.

## 11. How this differs from the Python example

| Python game | This design | Why |
|---|---|---|
| A river is a list of hexes (11 hexes for the Po); `river_at[pos]` | A chain of hex edges (15 edges for the same Po in this frame) | Bank, border, crossing |
| Only the 35 trunks; no tributaries; the Po has 6 points | Trunks plus a tributary file; the Po has 6 tributaries here | Confluences, border rivers (Ticino, Adda) |
| One width; no source, no size, no mouth rules | Three sizes from the basin; source and mouth rules; downhill | A river looks and acts like a river |
| No lakes in Europe | Edge lakes (and lake hexes for big ones), added to the data | Maggiore, Como, Garda, Constance, Geneva |
| Rivers only make a hex cheaper to move through if both hexes are on the same river | Rivers are obstacles on their edge; bridges and fords are chosen per crossing | Defence and trade |
| Coast: land or ocean, one style | Cliff, beach, marsh; bay, harbour shelter; depth bands; smoothed coast | Ports and a better look |
| River art: Chaikin smoothing over hex centres, drawn beside the hex centre | A curve through edge midpoints; towns on a bank | Matches the sockets |

## 12. Questions for the owner

1. **Rivers on the edges between hexes, or through the hex centres?** *Recommended: on the edges* (the border, crossing and
   bridge all sit on the shared edge; confluences and lakes fit; Milan lies between the Ticino and the Adda as in
   history). Other: through the centres as in the Python game (simpler art, but a river can never be a border or a
   crossing). A third, "both" (edge rivers plus decorative brooks through hexes), costs nothing extra: brooks can be added
   as art later.
2. **Hex size: 57 km (today) or 28 km?** *Recommended: 28 km for water*; it lets Como be a Y, lets tributaries have bends and
   towns, and halves the stray from the real course; cost is four times the hexes and double the edges (thread 4 is
   checking). Other: keep 57 km: the rules are the same; lakes are drawn about twice too wide and the Alpine lakes are one
   or two edges.
3. **Alpine lakes as a wide ribbon on the river line, or as whole water hexes?** *Recommended: a ribbon (lake edges)* for any
   lake smaller than 0.6 of a hex, so Maggiore, Como, Garda, Lugano are drawn to scale and the river runs through them; whole
   water hexes only for the big northern lakes (Ladoga, Onega, Peipus, Vanern, Constance at 28 km). Other: all lakes as
   water hexes (simpler rules, but Maggiore would be a whole hex at 28 km, about 3 times too large).

---

# Technical appendix

## A.1 Data: `godot/data/water.json` (proposed)

```json
{
  "schema": "hexa-godot/water/1",
  "river_sizes_km2": {"size1": 1500, "size2": 7000, "size3": 30000},
  "rain_weight": {"plain": 1.0, "hills": 1.5, "mountains": 1.8, "desert": 0.3},
  "lake_hex_share": 0.6,
  "lake_width": {"narrow": 0.40, "broad": 0.78},
  "coast_smooth_hex": 0.34,
  "river_min_clamp_hex": 0.34,
  "sea_depth_hex": {"shelf": 1, "sea": 3},
  "delta": {"min_marsh": 0.4, "max_mouths": 3},
  "hex_km": 57
}
```

Everything in km or km2 so the same file works at both grids; `hex_km` is the only link to the grid.

## A.2 Snapping a real course onto the corners

A corner lattice is the set of hex corners; two corners are joined when they share an edge. Each edge has two hexes; a river
edge is allowed when both are land (or land and a lake hex).

1. Source corner = the corner nearest the data's first point; goal = the nearest corner to the last point, or **any
   corner already on a river** for a tributary (stop there).
2. Dijkstra on the lattice with edge cost `(1 + 7 * d)^1.6`, where `d` is the mean distance of the edge's two corners from
   the real polyline, in hex radii. Thread 1's relief adds a term: +big if the edge is not adjacent to a valley hex in mountains,
   and a bar on ridge edges.
3. Check downhill with the corner heights; carve or reroute where it fails.
4. Sizes by accumulating drainage down the chain (own basin area plus tributaries, rain-weighted).
5. Lake edges: for each lake in the lake file, mark the chain's edges whose midpoint is within `width_km` of the lake axis
   (6 to 12 km); a dead-end arm is routed separately from the nearest corner on the chain.

Measured on the prototype (stand-in relief): Po 15 edges, Ticino 5, Adda 6, Dora Baltea 4, Tanaro 3, Mincio 5, Adige 8 =
**43 edges**; 34 of 114 land hexes touch a river edge. Milan: river edges Ticino (2) and Adda (1); Turin: Po (2) and Dora
Baltea (1). The Python Po in the same frame: 11 hexes.

## A.3 The drawn curve

Start with the corner polyline, densify to four points per edge, then Laplacian-smooth with each point clamped within
`river_min_clamp_hex` of its lattice point; the ends and every join corner are pinned. For the bridge rule the curve is also
pinned to each **edge midpoint** (thread 3), which the clamp then makes cheap. Optional meander: a slowly varying offset
along the normal, amplitude 0.1 hex, deterministic from the river's name. Width by size: 0.17, 0.27, 0.42 hex radii in my
mockup. Lakes: discs along the chain with a sine profile (narrow 0.40, broad 0.78 hex radii wide; the fat end for Garda).
The coast: render the land hexes as a mask, blur by about half a hex, threshold at 50 %; the sea bands come from heavier blurs
of the same mask; coast type rim and teeth from the nearest typed edge. All of this is a shader or a baked texture in Godot;
the mockups do it with plain image blurs.

## A.4 Data to add

**Prototype rivers** (waypoints, lon/lat, source first; extra points by town so the lattice has something to snap to):

| River | Waypoints | Joins |
|---|---|---|
| Po (data trunk refined) | 7.10,44.70; 7.70,45.05; 8.10,45.20; 8.85,45.00; 9.20,45.12; 10.03,45.12; 10.90,45.05; 11.60,44.92; 12.35,44.95 | sea (delta) |
| Ticino | 8.40,46.48; 9.02,46.19; 8.80,46.17 (Maggiore N); 8.57,45.73 (S); 8.86,45.31; 9.20,45.12 | Po |
| Adda | 10.37,46.47; 9.87,46.17; 9.37,46.14 (Como N); 9.40,45.85 (Lecco); 9.52,45.52; 9.82,45.08 | Po |
| Dora Baltea | 7.00,45.85; 7.32,45.74; 7.87,45.47; 7.99,45.20 | Po |
| Tanaro | 7.70,44.10; 8.03,44.70; 8.62,44.91; 8.85,45.00 | Po |
| Mincio (with the Sarca) | 10.55,46.20; 10.84,45.89 (Garda N); 10.69,45.44 (S); 10.90,45.05 | Po |
| Adige | 11.35,46.50; 11.12,46.07; 10.99,45.44; 11.30,45.19; 12.30,45.15 | Po delta zone |
| Trebbia, Taro, Panaro, Scrivia, Dora Riparia | short Apennine and Alpine streams | Po (the "generated" examples) |

**Lakes to add to `land.json`** (axis points and area in km2): Maggiore 8.80,46.17 to 8.57,45.73 (212); Como 9.37,46.14 to 9.26,45.99
to 9.40,45.85 plus an arm to 9.08,45.81 (146); Garda 10.84,45.89 to 10.70,45.45 (370); Lugano, Iseo, Orta (art ponds);
Geneva 6.15,46.2 to 6.9,46.45 (580); Constance 9.4,47.6 (536); Neuchatel; Balaton; and the northern lakes as lake hexes.

**Tributaries to add for Europe** (about 70, the first batch): Rhine: Aare, Mosel, Main, Neckar; Danube: Inn, Drava, Sava, Tisza,
Morava; Rhone: Saone, Isere, Durance; Loire: Allier, Cher; Seine: Marne, Oise; Elbe: Vltava, Saale; Vistula: San, Bug; Oder:
Warta; Po: the ten above; Garonne: Tarn, Lot; Tagus, Douro, Ebro: one or two each; Thames: Severn is separate. The data file
`rivers_extra.json` uses the same shape as `rivers.json` plus `joins` (name of the river it flows into).

## A.5 How I made the mockups

Scratch scripts, not in the repo, using the real data: the land mask from `geo.land_cells`, the projection from `geo.hex_of`
and `geo.lonlat`, a stand-in relief from the data's mountain lines (colours only), the snapping above, plain image blurs for the
smooth coast and the sea bands. The hex grid is the Python game's pointy-top odd-r grid; the what-if at 28 km sets the
projection to `SCALE = 4` and runs the same code. Edge `e` of a hex is its e-th neighbour (E, NE, NW, W, SW, SE), as in `hexgrid.neighbors`.
