# Map thread 1: terrain and relief (draft for the owner, 2026-11-14)

Status: **design draft, nothing is built.** Part of the map design in `00-brief.md`. Mockups in this folder:

| File | What it shows |
|---|---|
| `01_alps_po_relief_by_hand.png` | The western Alps to the Po plain, worked by hand on the real hex grid: heights, levels, crests, valleys, passes, the plain. |
| `01_section_coast_to_plateau.png` | A cut from the Ligurian coast over the Gotthard to the Swiss plateau: the real ground against the one-level-per-hex view. |
| `01_two_hex_sizes.png` | The same ground at 57 km and 28 km hexes: valleys as chains against one-hex ribbons. |
| `01_relief_three_zooms.png` | How the same relief reads at far, middle and close zoom in direction A (rough stand-in art, not final tiles). |

---

## 1. In plain words

Today a hex is **one word** ("hills", "mountains", "snow"...). That is why the Python map has mountains next to
nothing but hills, no valleys, and a Po plain that came out mountainous. The new design gives every hex **two
things**:

1. **How high it is** (a real number of metres, which gives one of seven *levels*: sea, lowland, plain, hills,
   highland, mountains, high peaks).
2. **What covers it** (farmland, grass, woods, marsh, bare rock, snow, tundra...).

"Wooded hills" and "alpine pasture" then exist, a valley can be a lowering inside a range, and a river knows which
way is downhill. The real geography data fixes the big shapes (the Alps, the Apennines, the passes, the valleys), and
the generator fills in the rest around it.

The player still sees simple names on the hex card ("Hills", "Mountains", "Woods", "Farmland"...). The two layers are
for the map builder and the rules, not extra work for the player.

---

## 2. Terrain kinds for Europe

### 2.1 The seven relief levels

The thresholds are numbers in a data file (the first set is below; tuning is expected).

| Level | Name | Metres | Europe examples | Allowed cover |
|---|---|---|---|---|
| 0 | Sea | below 0 | open water (owned by thread 2) | none |
| 1 | Lowland | 0 to 100 | Po delta, Venice lagoon, Dutch coast, Camargue | marsh, farmland, grass, woods |
| 2 | Plain | 100 to 400 | Po plain, Beauce, Hungarian plain | farmland, grass, woods, (marsh by rivers) |
| 3 | Hills | 400 to 900 | Tuscany, Swiss plateau, Bohemian rim | farmland (terraces, vines), grass, woods |
| 4 | Highland | 900 to 1700 | Massif Central, Jura, Meseta rim, Apennine ridges, Alpine foothills | grass (pasture), woods, rock |
| 5 | Mountains | 1700 to 2800 | Alps flanks, Pyrenees, Carpathians | rock, woods (low part), grass (alp) |
| 6 | High peaks | above 2800 (lower in the north) | Mont Blanc, Monte Rosa, Bernina | snow and ice, rock |

Why seven and not today's three (hills 1, mountains 2, snow 2): the Alps climb from 120 m at Milan to 4,000 m in
about 100 km. With only "hills" and "mountains" the map has to jump from plain to a mountain wall in one hex, which
is exactly what the Python rule had to forbid (`mountains` may not touch `plains`). Seven levels give the climb room
and give valleys somewhere to sit (a valley floor is one level below the walls beside it).

### 2.2 Cover kinds

| Cover | Replaces | Notes |
|---|---|---|
| Farmland | plains | fertile open ground; the economy's grain land |
| Grassland | steppe | pasture, heath, moor, alpine meadow, the Pontic steppe |
| Woods | forest, taiga | one kind; a *look* variant by climate (oak and beech in the south, spruce and fir in the north) |
| Marsh | marsh | fens, deltas, lagoon edges; only on lowland and plain |
| Rock | (part of mountains) | bare crags and scree; the surface of mountains |
| Snow and ice | snow | only on high peaks and their top shoulders |
| Tundra | tundra | Lapland, the far north coast |
| Desert, Savanna, Jungle | same | **kept untouched for the later non-European world**, not designed here |

### 2.3 What is dropped or added, and why

| Today (Python and `terrain.json`) | Decision | Reason |
|---|---|---|
| `mountains` | becomes *relief* levels 5 and 6 plus the cover Rock | one word cannot say "mountain in a valley chain", "mountain with woods" |
| `hills` | stays as relief level 3 | |
| `snow` | dropped as a terrain; it is the cover of level 6 | in Europe snow only means high peaks; it also forced silly rules (`snow` not next to `plains`...) |
| `taiga` | merged into Woods (look variant) | the rules treat it as forest; the art can tell them apart by climate |
| `beach` | dropped as a terrain; it is a **coast feature** | a beach is a thin strip, not a 57 km hex. Thread 2 draws it on the `coast:low` edge. The goods that used `beach` (salt, wine, fish) move to "coastal lowland" in the data |
| `lake`, `ocean` | not terrain kinds any more | water belongs to thread 2 |
| `plains` | renamed Farmland (cover) at plain or lowland level | |
| `steppe` | renamed Grassland | now also covers pasture and meadows |
| `forest` | renamed Woods | now also allowed on hills and mountain flanks |
| **new: Highland** (level 4) | added | Massif Central, Scottish and Alpine uplands, the plateau shoulders: 900 to 1700 m is a big part of Europe and fits neither "hills" nor "mountains" |
| **new: Plateau** (a flag, not a kind) | added | a flat top at hill or highland height with a rim (Spanish Meseta, Massif Central) |
| desert, savanna, jungle | kept | outside Europe, later |

Player-facing names (hex card) come from the pair, for example: Farmland, Marsh, Hills, Wooded hills, Highland
pasture, Mountains, High peaks. About twelve names in all for Europe, down from the current fifteen kinds (and
those include two water kinds and three hot-world kinds).

The game rules (move cost, defence, density) are keyed by the pair. Today's numbers (mountains: move 3, defence 0.5;
hills: move 2, defence 0.05; forest: move 2, defence 0.25) are the starting point; this thread does not change rules.

---

## 3. The relief model

### 3.1 In five lines

1. Every hex stores a **height in metres**; its level (0 to 6) is read from thresholds in a data file.
2. A **fixed skeleton from the real geography** (range spines with crest heights, passes, valley floor lines, a few
   height anchors such as city heights) decides where the high and low ground is.
3. Each range is a **ridge profile around its spine**: steep on the inner (Italian) side, gentle on the outer side.
   The spine runs **along hex edges**, which are the *crest edges*; a **pass** is a gap in the crest.
4. **Valleys are carved** along their floor lines, running downhill from a pass to the plain; between ranges the
   foreland (plateaus, plains) rises and falls between the anchor heights.
5. A **slope rule** finishes it: neighbouring land hexes differ by at most two levels (two means a steep face).
   Cover (farmland, woods, snow...) is chosen afterwards, within the cover rules of the table in 2.1.

### 3.2 Pieces

**Height of a hex.** One number, metres. Only the prototype shows these numbers; the player sees the level and the
art. Having a number (not just a level) lets a river know which way is downhill, lets two hexes of the same level
still differ, and keeps the thresholds adjustable.

**Ranges and crests.** A range is a spine (a line with a crest height at each point, taken from the data) plus a
width on each side. The hex takes the highest ground within about 0.4 of a hex of its centre. Crest edges are the
hex edges that run along the spine (the same rule the Python game already uses for its ridge walls, kept). The spine
at the hex scale is a chain of edges, so a range is a *wall between two sets of hexes*, with the crest hexes on
both sides at mountain or peak level.

**Valleys.** A valley has a floor line from its head (a pass or a glacier) to its mouth. Hexes on the line are
lowered to the floor height plus a small rise towards the walls. Rules: the floor never rises downstream; a valley
head is a pass, a lake or a basin; a valley mouth opens onto level 2 or 1 ground (the plain). Valley floors are
where roads, rivers and towns go (threads 2 and 3). In the prototype 13 valleys are carved (section 5).

**Passes.** A pass is a crest edge with a gap: the two hexes beside it are at mountain level, the pass itself is
the lowest point of the crest, and a valley floor runs away from it on each side. The game keeps its pass edges
(movement across a crest only at passes, as in 0.2.x).

**Plains and foreland.** The ground away from ranges follows anchor heights (a city is a free anchor: Milan 120 m,
Turin 240, Bern 540...) blended smoothly. This is how the Po plain falls from Turin (240) to the sea (0), and how the
Swiss plateau stays at 400 to 600 m.

**Plateaus.** A group of three or more connected hex at hills or highland level, with open cover and a rim of steep
edges (scarps), is drawn as a plateau. They come from optional data polygons with a height (Meseta, Massif Central).
Unmarked high flat ground is just highland.

**Coast.** A land hex touching the sea is lowland or plain, or **at most hills** when the edge is marked *cliff coast*
(the Ligurian coast at Genoa, Dalmatia, western Norway). Highland and mountains never touch the sea: there is always
one hex of hills or lower between (thread 3 asked for this; the mockup applies it). Venice's lagoon is lowland plus marsh.

**Marsh and deltas.** Lowland near a river mouth or a sea box from the data (Venice, the Camargue, the Dutch coast,
the Pripet) gets marsh cover; deltas are lowland hexes with a river splitting (thread 2).

**Snow line and tree line (cover rules).** Snow only on level 6 and on the top shoulder of level 5 next to it. Woods
stop below level 6. The high-peaks threshold falls with latitude (the data holds the curve), so Norway's peaks can
carry snow although they are lower than the Alps.

### 3.3 What is fixed from the geography data and what is generated

| Kind | Source | Fixed or generated |
|---|---|---|
| Land and sea shape, coasts | `land.json` | fixed |
| Mountain spines and heights | `terrain_shapes.json` (`mountains`) | fixed, but **too thin today** (end of section 5) |
| Named passes with positions | `passes.json` (24) | fixed; heights and about 20 more are **new data** |
| Valley floors | none today | **new data** (about 40 for Europe) |
| Rivers | `rivers.json` | fixed (thread 2); must agree with valleys |
| City heights | none today | **new column** on `cities.json` |
| Hills, marsh boxes, plateaus | `terrain_shapes.json` | fixed, extended |
| Height of every hex | the model | **generated** from the above (no luck except a small noise) |
| Cover (farmland, woods...) | thread 4's WFC | **generated**, within constraints |
| Random worlds | `randomgeo` | spines, valleys and anchors generated by a seed, then the same model |

Recommendation: relief is **computed, then given to the WFC as fixed input**. The WFC chooses cover and the little
edge variants. Reason: the real Alps must be in the right place and have the right passes, which a puzzle solver
choosing locally cannot promise. (Owner question 1.)

---

## 4. How relief reads at three zooms (direction A)

`01_relief_three_zooms.png` shows the same ground at three zooms. The art is a stand-in made for the study; the rule
is what is proposed. Direction A's look (two-tone flat shading, ink outline, light from the upper left, objects laid
on a grid across hexes, soft blends between tints) is kept, as in `docs/design/godot-look/07_closeup_view.png`.

- **Far (hex width about 22 px or less):** flat tint by level (green plain, olive hills, ochre highland, grey
  mountains, white peaks), the tint blurred half way across edges, a faint hex grid, and one thin dark line along
  each crest edge of level 4 or higher (a white thread on high peaks). No objects. Range names in spaced capitals.
  A valley shows only as a lighter notch in the tint.
- **Middle (about 80 px):** one cluster of objects by level, placed on a grid across the hexes (not inside one hex):
  domes for hills, rounded crags for highland, two-tone peaks for mountains, snow caps from 2,300 m, bigger snow
  peaks at level 6. Crest edges get a chain of sharper peaks. Passes get a gold saddle marker and an italic name.
  Valleys read as gaps in the objects with meadow.
- **Close (about 170 px):** the object grid is denser; valley floors are cleared and drawn as pale meadow with a
  river line; trees thicken on the slopes below the tree line; the crest is a chain of three peaks per edge;
  snow only on level 6 and the top of level 5. Objects choose their kind from the *interpolated* height between hex
  centres, so a range does not end at a hex border.
- **Same rule at all zooms:** the picture is built from the stored level, the edge codes (section 8) and the cover,
  never the other way round. Light always from the upper left. No object is drawn if its kind would contradict the
  hex level (no snow on a plain).

How a hex "knows" its look: level and cover choose the object family; the edge codes choose the connected
pieces (crest chain, valley meadow, scarp wall, coast cliff).

---

## 5. The prototype region worked by hand

`01_alps_po_relief_by_hand.png` is the real grid, 16 by 13 hexes, from Dijon to the Dolomites and from Innsbruck to
Florence (a hex is about 57 km across). It is produced by a hand-built skeleton, not noise: the spines, the 13
valley floors, 24 foreland anchors and 9 passes were all placed by hand.

**The ranges (spine peak heights used):** Maritime and Cottian Alps (about 3,300), Graian and Pennine Alps (Mont
Blanc 4,200 to Monte Rosa 4,300), Lepontine Alps around the Gotthard (3,100), Rhaetian Alps (Bernina 3,800, Ortler
3,600), Dolomites (2,800), Bernese Alps (3,800), the Apennines (1,100 to 2,100), the Jura (1,300 to 1,600), the
Lombard Prealps (1,500 to 2,200).

**The valleys and passes.**

| Valley (floor) | Head | Runs to | Floor town |
|---|---|---|---|
| Aosta (Dora Baltea) | Great St Bernard 2,469 m | Po near Chivasso | Aosta 580 m |
| Susa (Dora Riparia) | Mont Cenis 2,083 m | Turin | Susa 500 m |
| Maurienne (Arc) | Mont Cenis (west side) | the Isere | |
| Ticino (Leventina) | Gotthard 2,106 m | Lake Maggiore, then the Po | Bellinzona 240 m |
| Ossola | Simplon 2,005 m | Lake Maggiore | Domodossola 277 m |
| Valais (Rhone) | Furka (not in data) | Lake Geneva | Sion 500 m |
| Valtellina (Adda) | Stelvio side | Lake Como, then the Po | Sondrio 300 m |
| Chiavenna | Splügen 2,113 m (not in data) | Lake Como | |
| Adige | Brenner 1,374 m | Verona and the sea | Bolzano 262 m, Trento 194 m |
| Stura | Col de Larche 1,991 m | Cuneo | Cuneo 534 m |
| Taro | Cisa 1,041 m | Parma | |
| Polcevera | Giovi 472 m (not in data) | Genoa to the Po plain | |

**What the hand work shows.**

- The Po plain is a clean band of level 2 hexes from Turin (240 m) to Verona and down to level 1 hexes at the
  delta (4 hexes, with the Venice lagoon marsh box).
- The Alps are 3 to 4 hexes thick; the long chain of high peaks (level 6) runs from the Pennine Alps through the
  Lepontine and Rhaetian Alps. Foothills at highland level (level 4) form a ring around the plain: the slope rule
  forces that ring, because a level-2 hex may not touch a level-6 hex.
- At 57 km per hex a valley is narrower than a hex. So a valley is a **chain of hexes along the floor line**, each one
  level lower than the walls: Aosta runs from level 5 at the pass to level 4 and 3 and out onto the plain.
- Genoa shows the cliff coast: sea next to level 3 hills behind it, and the Apennines at level 5 a little inland.
- `01_section_coast_to_plateau.png` makes the climb visible: sea, hills (Giovi), three plain hexes (Pavia, Milan,
  Lake Maggiore), highland, a level-6 crest, mountains, highland, plain. Plain to highland in one step (the Alpine
  foot) is a two-level step, drawn as a scarp.
- Counts in the frame (176 land hexes): lowland 4, plain 55, hills 33, highland 45, mountains 26, high peaks 13.

### What today's data lacks for this region

- **Only one Alpine spine** (`mountains` line 3, five points, one height 1.0) and one Apennine line (0.5). The
  Pennine, Lepontine, Bernese, Rhaetian and Dolomite ranges are not separate; there is no Jura, Prealps or
  Dauphine line.
- **No valleys at all.** Only three rivers in the frame (Rhine, Rhone, Po); the Ticino, Adda, Adige, Dora Baltea and
  the rest are missing.
- **Pass heights missing**; 9 of the 24 named passes lie in this frame; Splügen, Giovi, Furka, Stelvio, Mont
  Genèvre, San Bernardino and others are not in the data.
- **No Alpine lakes** (Maggiore, Como, Garda, Geneva, Constance); the data's `lakes` list holds five North American
  lakes only. Thread 2 owns lakes; this thread needs them on valley floors.
- **No city heights.**

---

## 6. Hex size: 57 km or 28 km

Thread 3 proposes halving the hex to about 28 km so an Alpine valley (Aosta, Susa, Ticino) becomes a one-hex ribbon
and towns near each other get their own hexes. The relief model is written to work at **both** sizes: only
numbers change, no rule. `01_two_hex_sizes.png` shows the same ground, same skeleton and same thresholds at both
sizes (Mont Blanc to Lake Maggiore, Turin to the Gotthard).

**What is size-independent (kept in the data, in metres and kilometres):** the level thresholds, the spine
heights, the valley floor heights, the pass heights, the range widths (stored in km, turned into hexes by a
`hex_km` constant), the valley half-width (half a hex), the snow line.

**What each size means:**

| | Hex about 57 km (today's grid) | Hex about 28 km |
|---|---|---|
| Hexes in the Europe map | about 30,000 (203 by 150) | about 120,000 (four times) |
| Alps thickness | 3 to 4 hexes | 6 to 8 hexes |
| A valley | a chain of hexes along the floor, narrower than a hex: the valley and its walls share the same hex, so a valley hex looks like a highland hex with a valley flag | a ribbon one hex wide, one level lower than the hexes beside it; the walls get their own hexes |
| Climb from the plain to the crest | one or two levels per hex (steep faces common) | mostly one level per hex; scarps become rare and meaningful (real rims, plateau edges) |
| A pass | a gap in a crest **edge** (a pass is between two hexes) | a **saddle hex**: the lowest hex of the crest, with crest edges on both sides |
| Towns in a valley | Aosta, Ivrea and Susa each need their own hex in the plain; in the valley the hex holds the valley and a town | each town on the valley floor can have its own hex (Aosta 580 m, Susa 500 m) |
| Po plain, Milan to Turin | about 2 to 3 hexes | about 5 to 6 hexes |
| Height pass cost | well under a second (estimate) | about four times that; still computed once per map |
| Slope rule | at most 2 levels between neighbours | at most 2 allowed, 1 normal; a data switch makes it 1 everywhere |

The mockup is honest about its limits: at 28 km the valley chains zigzag because the floor line passes between
hex centres. A real build would draw the chain along edges in a smoother way (thread 4's sockets do that). The valley
is still a stylised widening: a real Alpine valley floor is only 2 to 5 km wide.

**My recommendation for the relief model alone:** 28 km is better for valleys and passes, but the model does not
need it. Choose by what threads 3 and 4 report on towns and WFC cost. If the hex shrinks, the game rules per hex
(stack limits, movement, supply, tile levels) must be re-scaled; that is not decided here.

### What thread 3 needs from relief (one record per hex or per edge)

| Wanted | What relief supplies |
|---|---|
| Terrain kind | `level` (0 to 6) and `cover`, plus the derived name for the hex card |
| Elevation | `height_m` (metres) and `level` |
| Fertility | a number from 0 to 1, computed from cover, level, valley floor and river nearness: farmland on plain or lowland about 1.0; hills 0.7; highland 0.35; mountains 0.1; peaks 0; marsh 0.3; a valley floor gets +0.25 (alluvial soil); a river bonus is thread 2's. The economy thread owns the final numbers |
| Ore flag | a flag on hills, highland and mountain hexes that lie in a mining district from the data (the Tyrol silver, the Erzgebirge, Slovak gold... already coded in today's `special_good`) or beside a crest edge by a seeded roll. Which metal is the goods thread's choice |
| Valley flag and its two axis edges | `valley = {up: [edges], down: edge}`: the edges where the floor enters and leaves the hex (the `valley:in` and `valley:out` sockets). A head has no `up`; a confluence has two or three |
| Ridge edges | the `crest` flag on each of the six edges, and for the hex the highest crest level beside it |
| Pass saddles with names | per pass: `name`, `metres`, and (57 km) the crest edge or (28 km) the saddle hex, plus its two valley axis edges (one each side) |
| Slope step between hexes | per edge: `step` = level of the far hex minus level of this hex (signed), the metre difference, the `elev:K` code, and the `scarp` flag |
| Land touching the sea at most hills | adopted: a land hex touching the sea is level 3 or lower, level 3 only with `coast:cliff` |

---

## 7. How this differs from the Python example, and why

| Python (frozen v0.2.2) | This design | Why |
|---|---|---|
| One word per hex, 15 kinds | Relief (7 levels) plus cover | "wooded hills", valleys, plateaus; fewer rules to remember |
| Elevation only for 3 kinds (hills 1, mountains 2, snow 2) | A height in metres for every hex | rivers downhill, adjustable levels |
| A band of 0.8 degrees round each mountain line: every hex inside is mountain. In this frame that is **82 of 176** land hexes | Spine plus profile plus valleys: **39** hexes at mountain or peak level, 45 at highland | the band was why northern Italy looked mountainous; Milan and Turin sit only 0.04 and 0.07 degrees outside it |
| `mountains` may not touch `plains`, `marsh`, `beach` or `steppe` (hills ring forced by a forbidden list) | The slope rule: at most two levels between neighbours | one rule instead of a list; also works for any cover |
| `snow` is a terrain with five forbidden neighbours | Snow is cover of high peaks | |
| No valleys; passes are extra edges added after generation | Valleys and passes are part of the relief, joined by sockets | the brief's core question: join naturally |
| Ridge walls from the polyline crossing centres | Same rule, kept | already works; becomes the `crest` socket |
| `beach` terrain | coast feature | thread 2 |
| Terrain chosen by WFC from priors | Relief computed first; WFC only chooses cover | the real Alps must be where they are |

---

## 8. Sockets I need

For thread 4 to merge. Everything is on a hex edge unless said otherwise. Names are proposals.

1. **`elev:K` (edge height code).** K runs 0, 0.5, 1 ... 6. Both hexes on an edge show the same code. A hex of
   level L has edges in {L-0.5, L, L+0.5}: an edge to a neighbour of the same level shows L; to a neighbour one
   level higher shows L+0.5 (and that neighbour shows the same L+0.5). This carries the "one level per step" slope
   rule through the WFC with no extra logic.
2. **`scarp_top:L` and `scarp_foot:L`.** A steep face: the high hex is two levels (or one level at a flagged
   plateau rim) above the low hex. The pair matches only each other, never `elev`.
3. **`crest`** on an edge between two hexes that are both at the crest level for their range (5 or 6; 4 for low
   ranges such as the Apennines and Jura). A crest edge must continue at both its corners into another crest edge
   (or end at the sea or at a range end where the levels fall off). Needs thread 4's decision: corner
   constraints (three hexes share a corner), see risks.
4. **`crest:pass`** a crest edge with a gap, carrying a pass height. Both neighbours must have a `valley:out`
   leaving the pass on their side. Roads cross a crest only here (thread 3).
5. **`valley:in`, `valley:out`, `valley:head`** at the midpoint of an edge: a valley floor passes through the edge
   going downhill (`out` on the upper hex matches `in` on the lower). The floor height never rises downstream; each
   valley hex has exactly one `out` (except mouths and lake outlets) and at most three `in`. `valley:head` is on a
   pass edge, a lake hex or a basin. At a mouth the lower hex is level 1 or 2.
6. **`coast:low`** (sea next to level 1 or 2) **and `coast:cliff`** (sea next to level 3 hills: Genoa). A land
   hex touching the sea is at most level 3, and level 3 only with `coast:cliff`. (Thread 2 owns the coast art; I need these two
   as the relief side of it.)
7. **From thread 2, wanted by relief:** rivers on level 3 and higher must follow `valley` chains (a river and a
   valley floor share the hex edges); on level 1 and 2 a river is free. A lake on a valley chain keeps the chain
   through it (inflow and outflow). So thread 2's river and lake sockets must be able to *coincide* with
   `valley:in/out`.
8. **Not an edge socket, a cell rule:** cover compatibility. Snow only on level 6 (and the top shoulder of 5);
   woods not on 6; marsh only on 1 and 2; farmland not above 4 (terraced farmland on 3). Cover neighbours: snow only
   beside snow, rock or highland; desert never beside marsh or woods (kept from today's forbidden pairs, appendix E).

Not needed from relief: roads, rivers, towns (their sockets belong to threads 2 and 3).

---

## 9. Risks and open points

- **Corners.** A crest is a chain of edges; at a corner three hexes meet. An edge-only WFC cannot check that a
  crest continues. Proposal: the relief pass computes crests directly (it already does, from the spine), and the WFC
  treats `crest` as fixed input. If thread 4 wants the WFC to place crests, it needs vertex constraints.
- **Hex scale blur.** A pass and a peak can sit in the same 57 km hex; a hex is one level. The crest-on-edges rule
  and the "highest ground near the centre" rule keep the Alps looking right, but a hex is a coarse picture of a
  valley. Do not promise detailed gorges.
- **Highland count.** 45 of 176 hexes in the frame are highland, many forced by the slope rule. It may be too many.
  Tuning knobs: the thresholds, and allowing a two-level step more widely.
- **The Alps as an impassable wall.** Level 5 and 6 hexes cost a lot to cross. There are 9 named passes in this frame
  (the game derives 72 pass edges in all). Keep every historical pass; do not generate relief that closes a pass.
- **Random worlds.** They need generated spines and valleys; those are less pretty. Acceptable for the first
  version: ranges as noisy lines, valleys from rivers.
- **Performance (estimate, not measured).** Height for about 30,000 hexes from 24 anchors, ranges of a few hundred
  segments and 40 valleys: bounding boxes make it well under a second; compute once per map and cache.
- **Art cost.** Highland, scarp, crest chain, cliff coast, valley meadow are new art families (thread 5).

---

## 10. Smallest first version

Worth shipping before everything else:

1. A height in metres for every land hex, from the **existing** data only: the Alps and Apennine lines (widened by a
   profile), the 24 passes and a handful of anchors. 7 levels, thresholds in a data file.
2. The slope rule (at most two levels), replacing the forbidden pairs for mountains.
3. Cover on top (farmland, grass, woods, marsh, rock, snow, tundra) with the cover table.
4. Crest edges from the spines, pass edges as today.
5. Art: reuse today's hills, mountain and snow tiles for levels 3, 5, 6; highland gets the hills art plus rock (no new
   art yet); no scarps, plateaus or valley meadows.

Second step: the hand-authored data for all of Europe (about 25 ranges, 40 valleys, 25 passes, city heights),
valley chains, cliff coast, plateaus and the new art.

---

## 11. Questions for the owner

1. **Relief first, then the puzzle solver?** Should mountains, hills and valleys be **computed from the real
   geography first** and given to the wave function collapse as fixed ground (it then only chooses woods, farmland
   and edge details)?
   - **Recommended: yes.** The real Alps, passes and valleys come out where history put them, and random worlds
     use the same model with generated spines.
   - Alternative: let the puzzle solver also grow the relief. More variety, but no promise the Gotthard is where it
     belongs.
2. **Two layers instead of one terrain word?** Are you happy that a hex is *height level plus cover* (about twelve
   names the player sees: Farmland, Wooded hills, Highland pasture, Mountains, High peaks...), with **Highland** as a
   new level and snow, beach, taiga, lake and ocean no longer being terrain kinds?
   - **Recommended: yes.** It is what makes valleys, wooded mountains and plateaus possible.
   - Alternative: keep the one-word list and add only Highland and Valley. Simpler rules, but no wooded hills, and
     the Alps stay a jump from plain to wall.
3. **How much real geography data do we write by hand?**
   - **Recommended: all of Europe**: about 25 ranges with crest heights, 40 valley floors, 25 passes with heights,
     city heights, the Alpine lakes. It is data work, not code, and it decides how true the map is.
   - Alternative: hand-author only the prototype region (Alps and the Apennines) and let the rest be generated from
     today's thin lines. Faster, but the Pyrenees, the Carpathians and the Balkans stay a band of mountains.

---

# Appendix: technical detail

## A. Level thresholds (first values, data file)

`relief_levels`: lower bounds in metres for levels 1 to 6: `[1, 100, 400, 900, 1700, 2800]` (sea is level 0 by the
land mask; a land hex below 100 m is level 1). `snow_line_by_latitude`: level 6 starts at 2,800 m at 45 degrees
north and 35 m lower per degree north, but not below 1,500 m. The frame's mockup uses the fixed first row.

## B. The height model (as built for the mockup)

For a hex centre P with lon and lat, in hex-width units of the Europe 1480 projection (so one unit is one hex
width, and the real grid is used: `unit = ((lon - LON0)/COL_DEG, (Y_TOP - merc(lat))/COL_DEG)`; centre of hex
(c, r) = (c + 0.5 if r odd, r * 0.866)):

1. `base` = inverse-distance-squared mean of the anchors' heights (the city heights and a few extra points).
2. For each range: for each spine segment, the distance d from the sample point to the segment, the side (inner:
   closer to the arc centre than the nearest spine point; outer: farther), and the width w (inner 1.7 hexes and outer
   2.7 for the Alps; 0.6 to 0.9 for the others). The range's height at the point = spine height (linear along the
   segment) times (1 - d/w) to the power 0.9, if d < w.
3. Sample seven points (the centre and six at 0.4 of a hex) and take the highest range value: `hmax`. Hex height
   = max(base, hmax).
4. Valleys: for each valley polyline, d to the nearest segment; if d < 0.6 hex and the point is not within 0.9 hex
   of the valley's head (so the crest beside a pass keeps its height), limit = floor height at that point + 1,300 m
   per hex of distance. Height = min(height, limit) taken at the centre.
5. Noise of plus or minus 5 percent, from a hash of (col, row), not a random stream.
6. Slope rule: repeat up to 8 times: if a land hex is more than two levels above a land neighbour, the neighbour is
   lifted to the lowest height of (level - 2). This produces the foothill ring.
7. Sea hexes (from the land mask) are height 0. A land hex touching the sea is capped at 890 m (coast cap), before step 6.
8. For the half-size grid: `hex_km` halves, range widths and the valley head distance double in hexes, the valley
   half-width stays half a hex, the carve rate per hex halves; nothing else changes.

Crest edges: for each pair of adjacent hexes, if the spine polyline crosses the segment between the two centres an
odd number of times (the same test as the existing ridge walls), the shared edge is a crest edge. A pass is the crest
edge nearest to the pass position.

Inputs placed by hand for the frame: 6 range spines (about 40 points), 13 valley floors (about 45 points), 24
anchors, 9 passes (7 in today's data, 2 new), 5 lakes (none in today's data).

## C. New data proposed (JSON, in `godot/data/geography/`)

```
relief.json
  levels:        [1, 100, 400, 900, 1700, 2800]
  snow_line:     {base_lat: 45, base_m: 2800, per_degree: -35, floor_m: 1500}
  ranges:        [{name, width_inner, width_outer, crest_level, points: [[lon, lat, metres], ...]}]
  valleys:       [{name, points: [[lon, lat, floor_metres], ...], head: "pass name"}]
  plateaus:      [{name, polygon: [[lon, lat], ...], metres, rim: "scarp"}]
  anchors:       [[lon, lat, metres]]            # or a height column on cities.json
  passes.json:   add "metres" to each pass; add the missing passes (Splugen, Giovi, Mont Genevre, Stelvio, ...)
  lakes:         Alpine lakes (thread 2 owns the shape)
```

The old `mountains` lines stay for random-world compatibility until the new data replaces them.

## D. Pipeline order (hand-offs to the other threads)

1. Land and sea mask. 2. Height pass (this thread): heights, levels, crest edges, pass edges, valley chains.
3. Water (thread 2): rivers follow the valley chains; lakes on chains. 4. Cover and edge details (thread 4's WFC)
with relief fixed. 5. Settlements and roads (thread 3), passing only at pass edges. 6. Tiles (thread 5).

## E. Cover rules carried over from today's forbidden pairs

Today's `FORBIDDEN` pairs that are about cover and stay (for the non-European world too): desert not beside jungle,
marsh, taiga (woods in the north), snow, forest, or tundra; jungle not beside tundra or steppe; marsh not beside
savanna; tundra not beside jungle or savanna. The pairs with `mountains` and `snow` and `plains`/`beach` are
replaced by the slope rule and the snow rule.

## F. Checks that the build should pass (suggested tests)

- No two land neighbours differ by more than two levels; two-level steps are marked `scarp`.
- Every `crest` edge has crest edges at both corners (or ends at the sea).
- Every named pass has a crest gap and a valley floor on each side that reaches level 1 or 2 ground without rising.
- Every valley chain is non-increasing in height downstream.
- No snow cover below level 6 (and its top shoulder); no woods on level 6; no marsh above level 2.
- Milan, Turin and the Po plain hexes are level 1 or 2.
- Determinism: the same data gives the same heights.

## G. Mockup notes

The three images were drawn with a throwaway script from the hand-built skeleton described in B (not stored in the
repo). Hex positions use the real projection numbers in `godot/data/geography/projection.json`. The numbers on the
hexes are heights in metres from the model, rounded to 10 m. The object art in the zoom study is a rough stand-in
for thread 5's tiles.
