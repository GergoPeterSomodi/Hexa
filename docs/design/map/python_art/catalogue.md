# Python art for the normal map: the catalogue

Art director, 2026-11-15. The owner: "I liked some of the tile art from the python version. Can you bring some
over? Of course it needs to be blended with the current guidelines, but it would bring variety."

This is the list to pick from. **Nothing is converted yet.** Only our own code-drawn art is listed; Kenney pack art
is left out by the owner's decision.

| Page | What |
|---|---|
| `catalogue_1_goods_new.png` | The 12 goods that have **no family** in the new style, levels 1-5 |
| `catalogue_2_goods_have.png` | The 13 goods whose family exists, next to today's pieces (gold frame) |
| `catalogue_3_towns.png` | Settlements, harbour towns, castles, walls, the 10 landmark cities x 3 stages |
| `catalogue_4_nature_life.png` | Terrain tiles, nature objects, life and sites, farm and pass pieces, water and crossings |

Every picture is drawn by the Python art code and scaled to hex radius 60, the normal map's size
(`python tools/worldmap/python_art/catalogue.py` makes the pages again). The rule book is `../pieces/GUIDE.md`.

**How to read the pages.** A Python tile is a regular hex (106 x 122 px at radius 60). A new piece is drawn on the
tilted hex (104 x 102 px), so a converted picture is about 15% flatter than shown. The ids under the pictures are
the ids used below: `stone3` is the stone tile at level 3, `K1` a castle, `paris2` a landmark, `L-monastery` a life
object, `O-birch` a nature object, `N-...` a terrain tile, `P-...` a landscape piece, `X-...` a water or road
overlay.

## Top 10 recommended

| # | Pick | Ids | Becomes | Effort |
|---|---|---|---|---|
| 1 | **The four ores of the mines** | `iron1-5`, `silver1-5`, `gold1-5`, `copper1-5` | An `ore=` choice in the Mines family (as grazing has `animal=`): own ore colour and own top landmark for each | L (4 x S-M) |
| 2 | **Quarry** | `stone1-5` | New family | M |
| 3 | **Dye works** | `dyes1-5` | New family | M |
| 4 | **Hemp and ropewalk** | `hemp1-5` | New family | M |
| 5 | **Silk** | `silk1-5` | New family | M |
| 6 | **Furs** | `furs1-5` | New family | M |
| 7 | **Cotton** | `cotton1-5` | New family | M |
| 8 | **Landmark cities** | `venice`, `constantinople`, `paris`, `moscow` first; then the other six | A `landmark=` choice in Settlements levels 4-5: the city's own monument in place of the church or cathedral | M each |
| 9 | **Sites** | `L-monastery`, `L-roman_ruins`, `L-aqueduct`, `L-standing_stones`, `L-ruined_castle`, `L-pilgrimage_chapel` | New one-level family for hexes without an improvement | M for the six |
| 10 | **Third layouts from the old tiles** | `wine4-5` (contour terraces, chateau), `wool2-4` (stone-walled pastures, round sheepfold), `horses2-5` (round paddock), `K1` (motte and bailey) | A third layout (`variant=2`) in Vineyard, Grazing and Castles | S-M each |

Why these: 1-7 give hexes that look like nothing on the map today (the old tiles' strongest point was one clear
signature per good). 8 gives the famous cities a face. 9 gives the empty land something to find. 10 breaks up the
most common families at low cost.

**New families this would add:** Quarry, Dye works, Hemp, Silk, Furs, Cotton, Sites (7). In a second batch, if the
owner wants the overseas goods on this map: Sugar, Tobacco, Spices, Cocoa, Coffee, Ivory (6), and a Native village.

## What must change in every converted piece

The old tiles and the new pieces differ in the same ways every time. This is the standard conversion; the tables
below list only what comes on top.

| | Python tile | New piece (GUIDE) |
|---|---|---|
| Ground | Fills the whole hex with its own colour (red cotton soil, brown tobacco soil, orange spice ground) | The map paints the ground. Coloured soil only as a patch under the work (`p.patch`, `p.blob(alpha=)`), 10 px inside the border |
| Wild land | Draws its own forest, jungle, palms, rocks | The map's. The piece draws only what people made and reports a footprint |
| Relief | Mountains and hills drawn in the tile (iron, silver, copper, wine) | None, except a family's own low outcrop or mound |
| Water | Own sea, river or stream to the border (fish, salt, gold, dyes, timber) | Sea and rivers are the map's. A piece's own water ends in a pond at each end, inside the hex |
| Camera | Buildings as blocks with a front, a side wall and depth | Seen from the front: front wall and roof slope, two flat tones |
| Light | From the left, two tones | The same, with the soft shadow to the lower right. Little change |
| Ink | 1-2 px, near black (45, 45, 50), on everything | 0.5 px `INK` (52, 44, 46); none on people, animals, trees, ground shapes |
| Scale | A house is 18-24 px, 1-3 big objects fill the hex | A house is 8 px, the tallest thing 20 px. The same idea needs **more, smaller units**: this is a redraw with the kit, not a resize |
| Levels | 5 | 3 (settlements 5). Use the old levels 1, 3 and 5 as the model; one new landmark per level |
| Layout | Random scatter per variant, flipped for variant 1 | A fixed table, additive by level; mirror by the kit; a true second layout |
| Seasons | None | All four. Winter must keep the pattern readable under snow |
| Palette | Own brighter colours | Kit tokens; each new signature colour is a named token in the family module |
| Coverage | Level 1 often fills the hex already | About 20 / 45 / 70% of the margin hex |

**Climate winters.** Several picks live where it does not snow (cotton, silk, dyes in the south; all overseas
goods). This is open question 1 of the GUIDE (a "frost" or dry winter column). It must be answered before the
southern and overseas families are drawn, or their winter column is drawn twice.

## Goods with no family yet (page 1)

| Id | What it is | Fit | On top of the standard conversion | Effort | Verdict |
|---|---|---|---|---|---|
| `stone1-5` | A stepped quarry pit, cut blocks, a treadwheel crane, marble columns at the top | **New family: Quarry.** Ground `rock`. Signature: pale stepped pit and white blocks; landmark: the crane | The pit is a plan view: redraw as 2-4 stepped ledges seen at the tilt (terrace lines, lit left face). Must not read as Mines (grey spoil, dark adit): keep it pale and angular. Winter: snow on ledges, faces bare | M | **Bring** |
| `hemp1-5` | Dark tall plant blocks, blue retting ponds, drying stooks, a very long ropewalk shed | **New family: Hemp and flax.** Ground `farm`. Signature: dark green blocks with small ponds; landmark: the ropewalk (the longest building on the map) | Ponds 10 px inside, frozen in winter. Blocks darker and shorter than wheat strips so it never reads as spring wheat. Ropewalk 26-30 px long, thatch | M | **Bring** |
| `cotton1-5` | Rows of white bolls on red soil, drying sheds, a gin house | **New family: Cotton.** Ground `farm` or `sand`. Signature: white dots in rows; landmark: the gin house | Red soil only as a patch. White dots vanish on snow: winter shows bare brown stalk rows. One new token (boll white on soil). Climate winter | M | **Bring** |
| `silk1-5` | Mulberry hedge rows, long silkworm sheds, a caravanserai with a blue dome | **New family: Silk.** Ground `grass`. Signature: hedge-like tree rows with long low sheds between; landmark: the domed caravanserai | Tree rows as planted `fruit` trees in lines (no hedge look-alike with wheat). The blue dome must differ from the cathedral dome: low, blue, with a courtyard wall. Token: dome blue | M | **Bring** |
| `dyes1-5` | Round vats of blue, red, yellow, purple; cloth on lines; a dye house | **New family: Dye works.** Ground `grass` or `sand`. Signature: the coloured vats (the only many-coloured piece); landmark: the cloth lines, then the dye house | The coloured stream goes: a short own channel between two ponds, plain water. Six colour tokens. Vats as flat ellipses (ground), cloth lines as standing. Winter: vats stay coloured (they are heated), a strong winter picture | M | **Bring** |
| `furs1-5` | A trapper's tent, log cabins, pelts on frames, a round palisade fort in snowy pine wood | **New family: Furs.** Ground `wood` (the map's taiga). Signature: pelt frames (brown diamonds) in a small clearing; landmark: the log post in a palisade | The pines and the snow are the map's and the season's. Must not read as Timber (stumps, log piles) or Castle 1 (palisade ring): no stumps, no banner, pelts in front. Winter is its high season: most pelts, smoke | M | **Bring** |
| `sugar1-5` | Blocks of tall cane, a boiling house with chimneys, a mill with a water wheel | New family: Sugar (overseas) | Cane blocks look like hemp and green wheat: needs its own block shape (tall, light green, cut faces). No winter | M | Maybe (batch 2) |
| `tobacco1-5` | Broad-leaf plants on dark soil, tall curing barns, a warehouse | New family: Tobacco (overseas) | Plants as rows of small rosettes; landmark the tall slatted barn. No winter | M | Maybe (batch 2) |
| `spices1-5` | Heaps of red, orange and yellow spice on mats, palms, a white warehouse with an awning | New family: Spices (overseas, Levant trade) | Coloured heaps are close to the dye vats: keep spices as pointed heaps in a row, dyes as round vats. Palms are wild land unless planted in a row. No winter | S-M | Maybe (batch 2) |
| `cocoa1-5` | Pod trees in a jungle clearing, drying mats, a hacienda | New family: Cocoa (overseas) | The orange pods on the trees are the signature, and the GUIDE says "no fruit drawn on trees": needs the owner's exception or a new signature (drying mats). Jungle is the map's | M | Maybe (batch 2) |
| `coffee1-5` | Shrub rows on red terraces, drying patios, a tower house | New family: Coffee (overseas, Arabia) | Rows on soil are the vineyard's signature: coffee must lean on round shrubs and the pale drying patios. No winter | M | Maybe (batch 2) |
| `ivory1-5` | Elephants on savanna, a hunting camp, tusks, a palisade fort | New family: Ivory (Africa) | Elephant as a new kit animal (about 7 x 5 px). The fort without banner, lower than a castle. No winter | M | Maybe (batch 2); the elephants are the charm |

## Goods whose family exists (page 2)

| Id | What the old tile has that today's piece has not | Fit | What must change | Effort | Verdict |
|---|---|---|---|---|---|
| `iron1-5` | Rust-brown ore heaps, an ore tramway with carts, a bloomery with a fire glow, a blast furnace | Mines with `ore="iron"`: rust ore pile, top landmark the furnace with glow | The mountain backdrop goes (the outcrop stays). Glow is a new token and the one allowed highlight; ask | S-M | **Bring** |
| `silver1-5` | Pale rock with glints, a stamp mill, the royal mint (a white tiled house) | Mines with `ore="silver"`: pale grey-blue spoil, top landmark the mint | Snow peaks and sparkles go (no icons, no highlights). The mint is one tile-roofed house: allowed (max 3 houses) | S-M | **Bring** |
| `gold1-5` | Panning in a stream, tents, a long sluice, a fortified mine | Mines with `ore="gold"`: its own layout, the sluice run on the piece's own race | The river is the map's: a race with a pond at each end. Works on `sand` or `rock`. The top-level palisade must not read as a castle | M | **Bring** |
| `copper1-5` | Teal-green rock, orange ore heaps, smoking roasting heaps, a smelter | Mines with `ore="copper"`: green-stained outcrop, orange ore, top landmark the roasting yard | Teal and orange tokens. Three smokes at most (the activity limit) | S-M | **Bring** |
| `wine1-5` | Vine rows in rings round a hill, a chateau on top, a cellar door in the slope | **Third layout of Vineyard**: curved contour rows round the estate house | No hill shading (relief is the landscape's). Rows as arcs of `p.rows` segments; chateau = the estate house. Same counts and coverage as layouts 0 and 1 | M | **Bring** |
| `wool1-5` | Dry-stone walls cutting the hex into odd pastures, round sheepfolds, a slate wool barn | **Third layout of Grazing (sheep)**: walled upland pastures | Walls as `terrace`-style stone lines, 10 px inside; the fold a small ring (`p.claim`). Same animal counts | M | **Bring** |
| `horses1-5` | A round paddock with running horses, stables, striped tents at the royal stud | **Third layout of Grazing (horses)**: one big round paddock in place of square meadows | The tents go (no festivals or bunting). Horses standing, not galloping, at kit size | S-M | **Bring** |
| `cattle1-5` | A watering pond with reeds, black-and-white cows, a red barn with a silo | A watering pond for Grazing (cattle), all layouts; spotted cows | The silo and the red barn go (not of the age). Pond frozen in winter | S | Maybe |
| `olives1-5` | Big gnarled trees, rows of terracotta oil jars, a press | Oil jars as the level 2-3 detail of Olives | A row of 3-4 jars (2 px each) by the mill. Nothing else: today's piece is the better picture | S | Maybe |
| `grain1-5` | A patchwork of many crops, a red grange barn, a manor | Nothing: today's wheat is clearer, and a many-coloured patchwork would break the "gold strips" signature | - | - | No |
| `salt1-5` | Pink and blue pans, a grey salt house | Nothing new: today's salt has the pans, the heaps and the store | - | - | No |
| `fish1-5` | Net racks, fish-drying racks, a pier | Drying racks (stockfish) as a northern detail of Harbour level 1 | 2 racks of 5 px | S | Maybe |
| `timber1-5` | A sawpit, pale plank stacks | Plank stacks as a level 3 detail of Timber | A second heap colour (sawn timber) | S | Maybe |

## Settlements, castles, landmarks (page 3)

| Id | What it is | Fit | What must change | Effort | Verdict |
|---|---|---|---|---|---|
| `K1` | Motte and bailey: a timber keep on a green mound with a palisade yard beside it | **Third layout of Castles, level 1** (and the mound and bailey kept under levels 2-3 of that layout) | Mound lower (the 20 px limit), front view of the keep, banner added | S-M | **Bring** |
| `K2`, `K3`, `W1-W3` | Stone castle, fortress in a hexagon wall, palisade, stone wall, star fort | Nothing: today's castles and walls say the same, better tilted | - | - | No |
| `T1-T6` | Hamlet to great city: a market square with coloured stalls, a slate-roofed palace, hexagonal walls | Two details for Settlements: the market stalls on the green (level 3 up), the palace (level 5) | Stalls are close to "festival": keep to 2-3 plain awnings. The hexagon wall is not wanted (ring walls are ellipses) | S | Maybe |
| `TH2-TH6` | Harbour towns with piers | Nothing: the harbour add-on does this | - | - | No |
| `venice1-3` | Campanile, St Mark's domes, palace front, gondolas, on a lagoon island | **Landmark for Settlements**: campanile and domes in place of the cathedral. Venice needs the lagoon from the map | The water is the map's. A special case worth a design of its own (a town on water) | M-L | **Bring** (first four) |
| `constantinople1-3` | Hagia Sophia: a wide grey dome with four minarets, sea walls | Landmark: dome and minarets | Minarets under 20 px; the dome grey-blue so it differs from the cathedral | M | **Bring** (first four) |
| `paris1-3` | Notre-Dame's twin towers on the river island | Landmark: twin-towered church | The river is the map's; no island drawn | S-M | **Bring** (first four) |
| `moscow1-3` | Red Kremlin walls, onion domes in many colours | Landmark: red brick ring wall and onion domes | Onion-dome colours as tokens; the snow comes from the season | M | **Bring** (first four) |
| `london1-3` | The White Tower, a tall spire, the bridge with houses | Landmark: tower and spire | The bridge belongs to the road layer; leave it | M | Maybe (second six) |
| `rome1-3` | St Peter's dome, a round castle by the river | Landmark: big dome and the round castle | - | M | Maybe (second six) |
| `seville1-3` | The Giralda tower, a low white town, palms | Landmark: the striped tower | Palms planted (allowed) | S-M | Maybe (second six) |
| `lisbon1-3` | The Belem tower at the shore, ships | Landmark: a shore tower; placed with the harbour add-on | Shore coordinates | M | Maybe (second six) |
| `cairo1-3` | Minarets and domes by the Nile | Landmark: minarets | Desert and Nile are the map's | M | Maybe (second six) |
| `granada1-3` | The Alhambra, red walls on a hill under snow peaks | Landmark: red palace walls | Hill and peaks go | M | Maybe (second six) |

## Nature, life, sites, water (page 4)

Wild land, relief, sea, rivers and roads are **the map's**, not pieces. These picks cannot become piece families;
they go to the map's own layers (the kit's wild land, the sea, the road layer), which another task owns.

| Id | What it is | Fit | What must change | Effort | Verdict |
|---|---|---|---|---|---|
| `L-monastery`, `L-roman_ruins`, `L-aqueduct`, `L-standing_stones`, `L-ruined_castle`, `L-pilgrimage_chapel` | Six set pieces of the old landscape | **New family: Sites.** One level each (`draw(1, season, variant=site)`), on hexes without an improvement, placed by the map from the real geography or at random | Front view, 0.5 px ink, at most 20 px tall, a small footprint. The ruined castle in `STONE_GREY`, no banner. Not gameplay marks: decoration only, unless the design says otherwise | M for six | **Bring** |
| `L-burial_mound`, `L-wayside_cross`, `L-watchtower`, `L-windmill_post`, `L-lighthouse` | Smaller set pieces | More Sites later. The windmill and the lighthouse are landmarks of Wheat and Harbour: not as sites | Small | S each | Maybe |
| `L-native_village` | Wigwams and a longhouse | A Settlements look for native peoples (it would replace the Kenney native camp, which is on the Kenney list) | Three levels to design; overseas only | M | Maybe (batch 2) |
| `O-birch`, `O-umbrella`, `O-cypress`, `O-date_palm`, `O-oak_autumn`, `O-dead_tree`, `O-olive` | Tree species | Species for the map's wild land (the kit's `tree` kinds), by climate | Dark-green rim in place of ink; kit sizes; four seasons each | S each | Maybe (wild-land task) |
| `O-volcano`, `O-mesa` | A smoking cone; a striped table mountain | Landmark relief for a few real places (Etna, Vesuvius) | Relief is the landscape layer's; needs that plan first | M | Maybe (later) |
| `O-snow_peak`, `O-twin_peak`, `O-crag`, `O-old_mountain`, `O-foothills`, `O-hill_*`, `X-mountains`, `X-pass` | Mountains and hills as objects | None for now: the map's relief is planned as slope shading | - | - | No (parked with the relief plan) |
| `N-*` (12 terrain tiles) | Whole-hex terrain with big trees and rocks | None: the map draws terrain. Useful only as a mood reference for the wild land per climate | - | - | No |
| `L-iceberg`, `L-sea_stack`, `L-sea_rocks`, `L-shipwreck`, `L-whale_spout`, `L-sandbar`, `L-reef_surf`, `L-coral_patch`, `X-shallow`, `X-reef` | Things in the sea | Details for the map's sea layer | The sea is the map's; needs a sea-detail task | S each | Maybe (later) |
| `L-reeds`, `L-cattails`, `L-lily_pond`, `X-marsh` | Marsh and pond plants | Wild land of marsh hexes | The kit has no marsh ground yet | S-M | Maybe (wild-land task) |
| `L-deer_family`, `L-wild_boar`, `L-goat_herd` | Wild animals | Wild-land dots in woods and hills | No ink, kit animal size (3-5 px) | S | Maybe |
| `L-cattle_herd`, `L-sheep_flock`, `L-horse_herd`, `L-shepherd`, `L-peasants_field`, `L-storks_roof` | Herds and people | Covered by Grazing and the activity details | - | - | No |
| `L-bird_flock`, `L-seabirds`, `L-market_fair`, `L-camel_caravan`, `L-battlefield`, `L-gallows_hill` | Birds, a fair, a caravan, a battlefield, a gallows | On the GUIDE's "what not to add" list (flying birds, festivals, traffic), or a game mark, not land | - | - | No |
| `L-waterfall`, `L-rapids`, `X-lake`, `X-pond`, `X-confluence`, `X-river-mouth`, `X-islet`, `X-sea` | Water | The map's water | - | - | No |
| `X-bridge`, `X-ford`, `X-ferry` | River crossings | The road layer, when it is designed: the three kinds are worth keeping | Tilt, thin ink | S each | Maybe (road layer) |
| `P-hospice` | A stone house with a chapel tower at a mountain pass | A Site, placed at named passes | As the other sites | S | Maybe |
| `P-barn`, `P-windmill`, `P-farmhouse`, `P-haystack`, `P-stump`, `P-snowmark` | Farm buildings; a snow sign | Covered by the kit; the snow sign is an icon | - | - | No |

## The conversion plan

**1. A converted pick is a normal family or a normal variant. There is no import.** Nothing of the Python drawing
code is reused: the worker redraws the idea with the kit, with the catalogue picture as the model. The result must
pass the GUIDE's checklist like any other family.

| The pick is | It becomes | Contract |
|---|---|---|
| A new family (Quarry, Dye works, Hemp, Silk, Furs, Cotton) | One module `tools/worldmap/pieces/<family>.py` with `LEVELS = (0, 1, 2, 3)`, `NAMES`, `VARIANTS = 2`, `LAYOUT = [dict, dict]`, `GATES`, and `draw(level, season, variant=0, mirror=False)`; a line in the GUIDE's signature table and a family table in section 8 | Old levels 1, 3, 5 are the models for new levels 1, 2, 3 |
| A choice inside a family (the ores) | A keyword, as grazing's `animal=`: `mines.draw(level, season, variant, mirror, ore="iron")`. The layout stays; the ore sets the spoil and ore colours and the level 3 landmark. Gold has its own layout table | One sheet per ore |
| A third layout (wine, wool, horses, K1) | `VARIANTS = 3` and a third dict in `LAYOUT`. Same landmarks, counts, coverage; yard 14 px from both other yards. `kit.pick` already takes the number of variants | The variants sheet gains two columns |
| A landmark city | A keyword in Settlements: `draw(level, season, variant, mirror, landmark="paris")` swaps the church or cathedral (levels 4-5) for the monument, drawn with `p.stand` at the same spot, 20 px at most. One small module `landmarks.py` holds the ten monuments | One sheet of all monuments at levels 4 and 5 |
| A site | One module `sites.py`: `draw(level, season, variant=0, mirror=False)` with `LEVELS = (0, 1)`, the variant picks the site (`VARIANTS = 6`), footprint small | The map places sites; no levels |
| A wild-land or sea thing | Not a piece: a note to the task that owns the kit's wild land or the map's sea | - |

**2. Order.** (a) The owner picks. (b) The art director writes the family table for each pick (three levels,
landmarks, seasons, signature, new tokens) into the GUIDE, in one pass, so signatures cannot collide. The climate
winter question is answered here. (c) Workers draw. (d) The art director reviews each sheet against the checklist
and against all other sheets for look-alikes. (e) The in-map test is run again with the new families.

**3. Worker tasks (Sonnet).** One task = one module and its sheets; tasks touch different files, so they can run
side by side. Each brief holds: the catalogue picture, the family table from the GUIDE, the files allowed, the
sheets to deliver (`<family>.png`, `<family>_variants.png`), and the checklist.

| Task | Files | Size | After |
|---|---|---|---|
| A1 Quarry | `quarry.py` | M | step (b) |
| A2 Dye works | `dyes.py` | M | step (b) |
| A3 Hemp | `hemp.py` | M | step (b) |
| A4 Silk | `silk.py` | M | step (b), winter answer |
| A5 Furs | `furs.py` | M | step (b) |
| A6 Cotton | `cotton.py` | M | step (b), winter answer |
| B1 Ores: iron, silver, copper | `mines.py` | M | step (b) |
| B2 Ore: gold (own layout) | `mines.py` | M | B1 (same file) |
| C1 Vineyard third layout | `vineyard.py` | S-M | step (b) |
| C2 Grazing third layouts (walled sheep pastures, round horse paddock) | `grazing.py` | M | step (b) |
| C3 Castle third layout (motte and bailey) | `castles.py` | S-M | step (b) |
| D1 Landmarks: Venice, Constantinople, Paris, Moscow | `landmarks.py`, a hook in `settlements.py` | M-L | step (b); Venice needs the map's answer on a town in water |
| D2 Landmarks: the other six | `landmarks.py` | M | D1 |
| E1 Sites: the six | `sites.py` | M | step (b) |
| F1 Overview and in-map test with the new families | `overview.py`, the in-map tool | S | all of the above |

Kit changes are kept out of the worker tasks (the kit has one owner at a time). Known kit needs, to be gathered in
step (b) and done as one kit task first: an elephant for `p.animal` (batch 2 only), a round fence or paddock ring,
a stone field wall, colour tokens for the new signatures.

**4. Risks.**
- Signature crowding: 10 families today, 16-17 after. Hemp against spring wheat, furs against timber, gold's fort
  against a castle, spices against dyes are the pairs to watch.
- The old tiles are loved for their big, bold objects. At the new scale the same idea is many small units; the
  owner may find a converted piece less striking than the tile he remembers. One trial family (the quarry or the
  dye works) before the rest would show this early.
- Whether the map places these goods at all on the normal map is a game question, not an art one.

## The question for the owner

Which of these should come over?

- **A. The top 10** (recommended): six new families, the four ores, four landmark cities, six sites, four third
  layouts. About 14 worker tasks.
- **B. A trial first**: the quarry and the dye works only, shown in the map, then decide on the rest.
- **C. A. plus the overseas batch**: sugar, tobacco, spices, cocoa, coffee, ivory and the native village.
- Or name the ids you liked; anything on the four pages can be asked for.

Two side questions come with the pick: the winter of warm lands (snow everywhere, or a dry winter in the south and
overseas), and whether cocoa may show its pods (the GUIDE forbids fruit on trees).
