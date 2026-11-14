# The map: one design (2026-11-14)

> **Owner's decisions (2026-11-14):** Q1 hex size **about 28 km** (prototype region now; Europe confirmed after measuring
> drawing and AI path cost). Q2 rivers **along hex edges, but some rivers run through cities in some cases**: a short
> authored list of river cities (e.g. Florence on the Arno, Paris on the Seine, Prague on the Vltava, Rome on the Tiber)
> where the river passes through the city hex with the bridge inside the city; everywhere else rivers stay on edges.
> Q3 heights from **real elevation data** (a free dataset after a licence check; nothing is downloaded without the
> owner's go), with only passes, lakes, tributaries, notable places and 1480 fixes written by hand. Q4 **no Kenney art**
> in the new map: our own code-drawn ground. Defaults D1 to D11 stand (not overruled).
>
> **Elevation data (owner approved the download, 2026-11-14):** NOAA ETOPO 2022, 60 arc-second, surface elevation (land
> heights and sea depth), cut to lon -25..60, lat 25..72 from NOAA's ERDDAP server (dataset `ETOPO_2022_v1_60s`) in two
> NetCDF pieces (west 335-360 and east 0-60 degrees, 57 MB together). The raw files stay outside the repo; only derived
> per-hex heights are shipped. ERDDAP's licence line: "The data may be used and redistributed for free but is not
> intended for legal use, since it may contain inaccuracies." Credit in the game's credits: "NOAA National Centers for
> Environmental Information. 2022: ETOPO 2022 15 Arc-Second Global Relief Model. doi:10.25921/fd45-gt74". Land or sea is
> decided by the coastline, not by height below 0 (the Netherlands, the Caspian shore); the 1480 hand fixes (Zuiderzee,
> drained fens and marshes, modern reservoirs) are listed in section 6.

**Status: for the owner to decide. Nothing is built.** This page joins the five map threads into one design. Read
this page first; the thread docs (`01` to `05`) hold the detail and the numbers behind it.

The brief (`00-brief.md`): Hexa restarts in Godot. Before any game code, we plan how the map looks and how it is
built. Europe in 1480, shown first on one region: **northern Italy and the western Alps, with the Duchy of Milan**.

---

## 1. The map in one minute

- **It looks like direction A** (the Hexa look you chose: flat two-tone shading, ink outlines, light from the upper
  left), as in the close-up `../godot-look/07_closeup_view.png`.
- **Every hex has a height and a ground.** Seven heights (sea, lowland, plain, hills, highland, mountains, high
  peaks) and a ground on top (farmland, grass, woods, marsh, rock, snow, tundra). So the map can show *wooded hills*,
  *alpine pasture* and a flat Po plain, and valleys can cut into the Alps.
- **Long things are drawn as lines on the map**, not painted inside hexes: rivers, coasts, mountain crests and
  borders run **along the edges between hexes**; roads run **from hex centre to hex centre**, crossing rivers at a
  bridge, a ford or a ferry.
- **Forests, peaks and fields are scattered over the whole map**, not one per hex, so a forest or a range runs on
  across hex borders without a seam.
- **Towns grow in steps** (hamlet, village, town, city, great city) and each step changes their picture, not their
  place or their roads.
- **The real geography is fixed** (where the Alps, passes, rivers, lakes and cities are); the generator fills in the
  rest. A random world uses the same steps with made-up geography.

### The pictures to look at (in this order)

| Picture | What it shows | Caveat |
|---|---|---|
| `05_region_close.png` | **The look**: the region in full dress at the close zoom, the Duchy of Milan with its border band | Drawn on today's big hexes, with the old map data (too many mountains near Milan) and rivers through the middle of hexes; the final map uses rivers on edges (section 4) |
| `01_alps_po_relief_by_hand.png` | **The ground**: heights, crests, passes and valleys of the region, worked by hand | Diagram, not art |
| `02_region_water.png` | **The water**: the Po and its tributaries on hex edges, lakes, three coast types, sea depth | Stand-in ground colours |
| `03_prototype_network.png` | **Towns and roads** on the smaller 28 km hex: Milan, Pavia, Genoa, the three Alpine passes, bridges | Stand-in ground and lakes |

For how it is built: `04_pipeline.png` (the steps) and `04_prototype_steps_fine.png` (the region built step by step by
a test script). For the pieces: `05_piece_sheet.png`. For Milan's dress: `05_milan_look.png`.

**No single picture yet combines all of it** (thread 1's ground, thread 2's edge rivers, thread 3's towns and thread
5's art, on the small hex). That picture is the first thing the Godot prototype makes (section 8).

---

## 2. How the map is built: "skeleton first, puzzle last"

Think of building a house: first the frame, then the walls, then the paint. Each step only adds; it never changes
what an earlier step made. If a check fails, the build stops and names the hex. Nothing is papered over.

| Step | What happens | In plain words |
|---|---|---|
| 0. Facts | Load the real coastline, rivers, lakes, ranges, passes and cities | The skeleton |
| 1. Ground height | Compute each hex's height from the ranges, valleys and city heights | Where it is high and low |
| 2. Water | Lay the real rivers on hex edges, always downhill; small streams follow the slope | Water finds its way to the sea |
| 3. Ground cover | **Wave function collapse** (the "puzzle solver") picks farmland, woods, marsh, rock, snow | The only real puzzle: local and fast |
| 4. Places | Real cities keep their hex; villages go where land, water and trade meet | Where people live |
| 5. Roads | The cheapest paths between places; crests are walls, passes are gates; bridges where roads meet rivers | How people travel |
| 6. Checks | Every edge gets one record; every river reaches the sea, every road reaches a town | Proof it all joins up |
| 7. Art | Each hex reads its edges and picks its pieces | The paint |

**Why not one big puzzle?** The puzzle solver only looks at neighbours. It cannot promise that the Po reaches the
Adriatic or that a road joins Milan to Genoa over a pass. All five threads came to the same view. So the long
things are computed, and the puzzle only chooses the ground (and later small picture variants).

**Speed (measured in Godot):** all of Europe builds in under a second on today's hexes and in 1 to 15 seconds on
hexes half as wide. The Europe map is built once, checked and shipped as a file, so players never wait for it.

---

## 3. How everything joins up

**The rule that makes it work:** every fact about the border between two hexes is stored **once, on that edge**.
Both hexes read the same record, so they can never disagree. A river cannot stop at a hex border, because the
border *is* where the river is.

An edge has two kinds of place: its **length** (what runs along it: a river, a coast, a crest, a border) and its
**middle point** (what crosses it: a road, a valley floor).

| Feature | Where it sits | How it joins |
|---|---|---|
| **Rivers** | Along edges, corner to corner | Always downhill; two rivers join at a corner; a river splits only in a delta; drawn as a smooth curve so it does not zigzag |
| **Lakes** | A widened stretch of the river line; very big lakes are whole water hexes | The river enters at one end and leaves at the other |
| **Coasts** | Along edges between land and sea | Cliff (no landing), beach (landing, ports) or marsh (salt, shallow boats); the sea has no hex lines |
| **Ridges (crests)** | Along edges, as a chain of peaks | A crest always continues at its corners; water and roads cannot cross it |
| **Passes** | A gap in a crest | The only place a road crosses a range; a hospice and the pass name |
| **Valleys** | A chain of lower hexes running down from a pass to the plain | Roads and rivers follow them; towns sit on their floor |
| **Roads** | Through edge middles, from hex centre to hex centre | Track, road or highway; where a road crosses a river edge it gets a ford, bridge or ferry at that edge's middle |
| **Cities** | Inside a hex, beside their river, at the road junction | Fields and suburbs spill into the neighbours as scattered pictures |
| **Borders** | Along edges | A band of the country's colour inside, a dark line on the edge |

The exact edge record (what one edge stores) is thread 4's final list: `04-wfc-model.md` section 3. It replaces the
socket names proposed in threads 1, 2, 3 and 5.

---

## 4. Where the threads disagreed, and how it is settled

1. **Rivers along edges, not through hexes.** Thread 2 and thread 4 chose edges (the bank, the border, the bridge
   and "which side is the town on" all have one clear answer). Threads 3 and 5 and the close-up mockups still draw
   rivers through the hex middle. **Settled: edges** (owner question 2 confirms it). Follow-up edits are listed in
   section 10.
2. **Hex size.** Threads 1, 3 and 5 drew at today's size (about 57 km; thread 3 says 55, the same grid), thread 3 at
   28 km, thread 4 at both. **Settled for the prototype: 28 km**; for all of Europe after two measurements (owner
   question 1).
3. **Relief levels.** Thread 4's test script used four rough classes as a stand-in. **Settled: thread 1's seven
   levels.**
4. **Where the pass sits.** On today's hexes a pass is an edge; on 28 km hexes it is a *saddle hex* with crest edges
   on both sides. Thread 3 puts the hospice on the pass hex, thread 5 on the edge. **Settled: on the saddle hex**
   (28 km).
5. **Lakes.** Thread 5 makes broad lakes into water hexes; thread 2 makes every lake smaller than 0.6 of a hex a
   ribbon on the river line. **Settled: thread 2's rule**; lakes that are whole hexes use the drawn sea tile (your
   earlier decision).
6. **Valley floors.** Thread 1 makes a valley a flag on a hex; thread 5 a "pale meadow" ground. **Settled: a flag**,
   which the art draws as meadow.
7. **The ground list.** Thread 5 counts nine ground textures, thread 1 lists seven grounds for Europe. **Settled:
   thread 1's list**, plus sand for beaches; desert, savanna and jungle wait for the world outside Europe.
8. **Kenney tiles.** The brief says start from the Kenney pack; thread 5 recommends drawing the ground in code and
   using no Kenney art in the new map. **Open: owner question 4.**

---

## 5. Hex size in plain words

| | Today, about 57 km | Half, about 28 km |
|---|---|---|
| Hexes in Europe | about 30,000 | about 122,000 (four times) |
| Milan, Como, Monza, Lecco, Varese | all in one hex | each nearly its own hex |
| An Alpine valley | invisible | a one-hex ribbon with its own towns |
| Lake Como | a V, drawn twice too wide | a real Y, true width |
| Two famous passes (Great St Bernard, Simplon) | lost to a river in the test | all 12 open |
| Building the map | under a second | 1 to 15 seconds, once |
| Drawing the map, AI path searches | known | **not measured yet** |

Every rule in this design is written in kilometres and edges, so the size is a number in a data file, not a
redesign. The cost is in the game rules: armies, supply, movement and stack limits per hex must be re-scaled
(roughly twice as many hexes per march). That belongs to the systems designer, later.

---

## 6. Data we must add

Today's geography files have one Alpine line, one Apennine line, only the Po (no tributaries), no Alpine lakes, no
pass heights and no city heights. For the region and then Europe we need:

| Data | Region (first) | Europe (later) |
|---|---|---|
| **Tributaries** | Ticino, Adda, Dora Baltea, Dora Riparia, Tanaro, Mincio, Adige, Sesia, Oglio, Lambro | about 70 (Aare, Inn, Saône, Isère, Vltava, Marne...) |
| **Lakes** | Maggiore, Como, Garda, Geneva, Constance (Lugano, Iseo, Orta as small ponds) | Balaton, Neuchâtel, the big northern lakes |
| **Mountain ranges** | Maritime, Cottian, Graian, Pennine, Lepontine, Rhaetian, Bernese Alps, Dolomites, Prealps, Jura, Apennines | about 25 |
| **Passes** with heights | add Splügen, Giovi, Furka, Stelvio, Mont Genèvre, San Bernardino | about 25 more |
| **Valleys** | 13 (Aosta, Susa, Ticino, Valtellina, Adige...) | about 40 |
| **Named gorges** (where a river cuts a range) | Rhône at Martigny, Ticino at the Alpine foot | a short list |
| **City heights** | about 25 | one column on the city list |
| **Notable places** | Como, Monza, Varese, Susa, Brig, Airolo; Bellinzona's castles; the hospices; the Certosa; the Po ferries | about 60 to start |

**A shortcut to consider (owner question 3):** instead of setting heights by hand, we could read them from a **free
real-world elevation map** (public, free-to-use height data of the whole Earth exists). It gives true heights for
all of Europe at once. We would still hand-write what it cannot know: passes, gorges, lakes, notable places, and
fixes where 1480 differs from today (drained marshes, the growing Po delta, the Dutch coast, modern dams). Its
licence must be checked before use.

---

## 7. What we reuse from the existing art

| From | Reused how |
|---|---|
| The Python game's code-drawn nature objects (33: peaks, crags, hills, 18 trees, shrubs, stones) | **As they are**, scattered over the map |
| Its life objects (42: reeds, boats, herds, monastery, windmill, lighthouse...) | **As they are** |
| Its goods objects (25) | As they are, for the goods map mode |
| Its goods tiles and building helpers | **Reworked**: fields go on the scatter grid, buildings stay |
| Its ridge, pass and hospice drawing | **Reworked** into crest and pass pieces |
| Its river, road and coast tile code (about 1,370 small pictures) | Keep the geometry ideas; **replace the pictures** with lines drawn from the edges |
| Its towns and castles | **Replaced** by the new level ladder (`../godot-look/08_closeup_upgrades.png`) |
| Kenney Hexagon Pack ground textures | **Owner question 4** (thread 5 recommends code-drawn ground instead) |

**New art:** about 120 pieces (crests, passes, cliffs, bridges, towns, castles, farms, mines, quays...) and six
drawing recipes (ground blend, coastline, river, road, border, fields). Today's art has 1,859 pictures; most of those
are replaced by the recipes.

---

## 8. Build order of the first Godot map prototype

Small and showable: each step ends with a screenshot for you. The region first, Europe only after the region looks
right.

1. **Region data.** Write the region's ranges, valleys, passes, tributaries, lakes, gorges and notable places (or
   read heights from the elevation map, question 3). *Show:* a plain list and a check that every name is in place.
2. **Ground height on 28 km hexes.** The region in flat colours by height, with crests and passes. *Show:* the
   Godot version of `01_alps_po_relief_by_hand.png`.
3. **Water.** Rivers on edges with smooth curves, lakes, the three coasts, sea depth. *Show:* the Po network over the
   height colours.
4. **Ground cover.** The puzzle solver picks the grounds; the blend between grounds. *Show:* the region with soft
   ground colours.
5. **Places and roads.** Cities, villages, roads, bridges, the three Alpine pass routes. *Show:* the Godot version
   of `03_prototype_network.png`.
6. **The art.** Scattered trees and peaks, crest chains, towns by level, bridges, Milan's border band, arms and
   name, at the far, middle and close zoom. *Show:* the one combined picture of section 1.
7. **The two measurements** (they decide the hex size for Europe): drawing time at every zoom on a 122,000-hex map,
   and one AI season of path searches. *Show:* the numbers.
8. **Europe.** Author the rest of the data, build, run every check, ship the file.

Steps 1 to 6 are the prototype. Game rules, units and the AI are not in it.

---

## 9. Decisions for the owner

The five threads asked 15 questions. Eleven have a clear answer and become **defaults** (they stand unless you
overrule one). Four are real questions.

### The four questions

**Q1. Hex size: go to about 28 km (half today's)?**
- **Recommended: yes for the region prototype now; confirmed for all of Europe after the two measurements**
  (step 7).
- Why it matters: it decides whether valleys, lake shapes and Milan's neighbour towns can exist at all. The price is
  four times the hexes, which may make the map slower to draw and the AI slower to think, and every movement and
  supply number must be re-scaled.
- Other: keep 57 km. Nothing to prove, but Milan, Como and Monza share one hex and valleys vanish.

**Q2. Rivers along the borders between hexes?**
- **Recommended: yes.** A river is a line you cross at a bridge, ford or ferry; it can be a frontier (the Ticino and
  the Adda framed the Duchy of Milan); the generator and the art are both simpler.
- Why it matters: it changes the look (a town sits *beside* its river, never astride it) and the rules (a river
  becomes an obstacle and a defence line).
- Other: through the middle of hexes, as in the Python game. A town can straddle its river, but a river can never be
  a border or a crossing, and a bridge has no fixed place.

**Q3. Where do the heights come from, and how much do we write by hand?**
- **Recommended: read heights from a free elevation map, and hand-write only what it cannot know** (passes, gorges,
  lakes, tributaries, notable places, the 1480 fixes), first for the region, then for all of Europe.
- Why it matters: hand-setting every range, valley and pass for Europe is weeks of data work and decides how true the
  map is. The elevation map gives the shapes for free; hand work then goes into what makes the map *historical*.
- Other: hand-set the skeleton (thread 1's method, proven on the region): full control, no licence question, but slow
  for all of Europe. Or hand-set only the region and let the rest come from today's thin lines: fast, but the
  Pyrenees and Carpathians stay a band of mountains.

**Q4. Should the new map use no Kenney art from the start?**
- **Recommended: yes.** Draw the ground textures in code (about a day of art work); the trees, peaks and props are
  already ours. The new map then never needs a replacement pass before Steam.
- Why it matters: the brief says "start from the Kenney tiles", and you kept Kenney on 2026-11-13. This changes that
  for the new map only (the 0.3.0 map keeps its Kenney tiles).
- Other: use the Kenney ground textures first and replace them before Steam.

### The defaults (overrule any of them)

| # | Default | From |
|---|---|---|
| D1 | **Skeleton first, puzzle last**: heights, rivers, towns and roads are computed; the puzzle solver only chooses the ground cover and picture variants | threads 1 and 4 |
| D2 | **A hex is height level plus ground** (seven levels, with the new *Highland*); snow, beach, taiga, lake and ocean stop being terrain kinds; the player sees about twelve simple names | thread 1 |
| D3 | **Lakes are a wide ribbon on the river line**; only lakes bigger than 0.6 of a hex are whole water hexes, drawn like the sea | thread 2 |
| D4 | **Roads are fixed when the map is made** in the first version; a town's level-up changes its picture and surroundings only | thread 3 |
| D5 | **A notable places list** (about 60 hand-written entries: missing towns, castles, hospices, the Po ferries) | thread 3 |
| D6 | **Borders: a band of the country colour inside the border, a dark line on it, a faint wash** over the land | thread 5 |
| D7 | **Coasts keep the hex shape with rounded corners**, a sand rim and a foam line; the sea has no hex lines | threads 2 and 5 |
| D8 | **The Europe map is built once, checked and shipped as a file**; random worlds are built from their seed | thread 4 |
| D9 | Crests come from the height step; a river may cut a crest only at a **named gorge**; any other clash stops the build | threads 1 and 4 |
| D10 | Lit pieces (mountains, towns, bridges) are never rotated; light always from the upper left | thread 5 |
| D11 | Game effects (river crossing cost, road speed, fertility, ferries) are **suggestions for the systems designer**, not decided here | all threads |

How the 15 thread questions map: thread 1 Q1 to D1, Q2 to D2, Q3 to Q3; thread 2 Q1 to Q2, Q2 to Q1, Q3 to D3;
thread 3 Q1 to Q1, Q2 to D4, Q3 to D5 and Q3; thread 4 Q1 to D1, Q2 to Q1, Q3 to Q2; thread 5 Q1 to D6, Q2 to Q4,
Q3 to D7.

---

## 10. Follow-up edits to the thread docs (after your decisions)

The thread docs stay as the record of each thread's work. These edits bring them in line with this page:

- **`03-settlements-and-roads.md`**: section 10 asks for a "river class crossing at the edge midpoint": reword to
  "the road crosses the river's edge at that edge's middle". Replace "elevation 0 to 1" and the four terrain kinds
  with thread 1's height and levels. Hospice on the saddle hex. Call the grid 57 km, not 55.
- **`05-tiles-and-objects.md`**: section 4 (rivers, roads, bridges rows), section 5 (river shapes "through
  midpoints", road "2 lanes") and section 8 items 1 and 2: rivers run along edges, so the road side lane is dropped.
  Appendix B becomes the road recipe only, appendix C the river recipe. The lakes row follows thread 2's 0.6 rule.
  Socket names follow thread 4's list (`line = crest/pass`, `step = scarp`, `shore_kind`). Ground list follows
  thread 1. Section 10's "rivers decision open" is closed.
- **`05_region_close.png`, `05_region_middle.png`, `05_piece_sheet.png`** (river cells and "road on the bank lane")
  and **`../godot-look/07_closeup_view.png`**: they show rivers through hexes. They are replaced by the prototype's
  step 6 picture, not redrawn now.
- **`01-terrain-and-relief.md`** section 8 and **`02-water.md`** section 10: socket names superseded by
  `04-wfc-model.md` section 3.5 (add a one-line note). In `02-water.md`, "pinned to every edge midpoint" means the
  middle of the river's own edge, where a road would cross it.
- **`00-brief.md`**: the Kenney line follows the answer to Q4.

---

## 11. Creative review

**Verdict: approve with changes.** The model is sound and the five threads now agree on it. The changes are the
follow-up edits of section 10 and one combined mockup (prototype step 6) before Europe-wide data work starts.

**Fun principles it is for:**
- **14, feels like 1480 to 1650**: real passes, hospices, the Ticino and Adda as Milan's frontiers, the Po ferries.
  The strongest gain of the design.
- **11, readable**: "where can I march, where can I trade" is answered by the picture: crests are walls, passes
  are gates, bridges are chokepoints.
- **9, remembered moments**: named places to fight over ("the bridge at Pavia", "the Gotthard") make better stories
  than nameless hexes.
- It also feeds **6, the world pushes back for reasons you can name** ("across the Alps", "beyond the Po").

**Fun risks:**
- **More clicking (principle 11).** At 28 km a march takes about twice as many hexes. Movement, supply and armies must
  be re-scaled so a season's orders do not double; otherwise the bigger map becomes busywork.
- **Stalemates.** A great river with one bridge, or a one-hex valley under a pass, can become a wall nobody can
  break. Ferries at every town on a great river, and sieges that can cut a bridge, are the counters; the war designer
  must test them.
- **Snowball.** A country holding a whole navigable river gets cheap trade. Cap the bonus per route.
- **Busy picture.** The close zoom is already dense (mockup 07). Calm ground under towns and armies is in the design;
  the density must be tuned at the play zoom, which no mockup shows yet.
- **Principle 16 (hard line).** The Europe region raises no sensitive topic. When the map grows beyond Europe, place
  names, the arms of non-European peoples and tribal lands need care: real names, no invented emblems, no map that
  shows their land as empty.

**Still unproven:**
- **Drawing cost at 28 km**: the far zoom of 122,000 hexes and four times the scattered trees and fields. It must be
  drawn in pre-drawn blocks; target under 16 ms a frame at every zoom.
- **AI path cost at 28 km**: four times the hexes per search and twice the hexes per march. The Python game spent its
  time here. One measured AI season is needed before 28 km is final.
- **River curves on edges**: no mockup in the final art shows them yet; the zigzag must be smoothed into a believable
  river.
- **The elevation map** (if chosen): a true height map may give a lumpier picture than a hand-set skeleton; the
  region test will show it.
