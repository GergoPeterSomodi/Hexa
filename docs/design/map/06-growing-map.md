# Thread 6: the growing map (draft, 2026-11-15)

Game designer. **Status: a plan and ideas for the owner to decide. Nothing is built.** All numbers are starting
values for the systems designer and belong in data files, not in code. Read `README.md` in this folder first.

> **Owner's decision (2026-11-15): one city, one hex, drawn inside it.** Every settlement belongs to exactly one hex and
> is drawn entirely inside that hex at every zoom (Genoa at most about half its hex, harbour included). A growing city
> fills more of its own hex and never spills over the border. Each hex is one district with one main use and a stage;
> its fields, woods and landmarks stay inside it. The close zoom is built hex by hex from the same data as the normal
> map (coast, rivers, roads), so what you own, upgrade or capture is exactly what you see.

The owner's idea: *"start from a plain map and the map is to be changed over time as the fields are upgraded OR
villages, towns and cities are raised instead. The terrains should remain somewhat similar but improved with whatever
the player wants to put there."*

## 1. The idea, and what "plain" means in 1480

**In one paragraph.** The map starts as the land of 1480: real mountains, rivers, coasts and the real cities, but with
most of the countryside still rough (woods, pasture, marsh, a few fields near the towns). Over 170 years each hex
(a district of about 28 km) is developed by its owner: fields become rich farmland or vineyards, a hamlet becomes a
town, a track becomes a road, a tower becomes a fortress. The ground underneath stays what it was: a hill is still a
hill, the coast is still the coast. By 1650 two players' Lombardies look different, and you can read a country's
choices from its map. That is the fun: **the map is the score sheet**.

**What exists at the start.** Three options:

| Option | Start | For | Against |
|---|---|---|---|
| A. Empty | No cities, the player founds everything | Most freedom | It is not Europe in 1480; Milan without Milan |
| **B. Lived-in but unfinished (recommended)** | Real cities, ports, passes and main roads at their real 1480 size; the countryside at the lowest stages; nothing at the top stage | History is recognisable, and most hexes still have room to grow | Rich regions (the Po plain, Flanders) start ahead |
| C. Fully dressed | The map as in the close-up mockup today | Prettiest first screen | Nothing left to grow |

With B, Genoa and Milan are there on turn one (Genoa a walled city with its old mole, Milan a great city), about one
hex in four has some development, and at most one in ten is at stage 2. The real history supports it: between 1480
and 1650 Lombardy drained marsh for rice, planted mulberries for silk and dug canals; Genoa built its new mole and
new walls; star forts replaced towers everywhere.

## 2. What can grow on a hex

Each chain has a bare state and three stages. The stage is the **character of the whole district**, not one building.

| Chain | Where | Bare | Stage 1 | Stage 2 | Stage 3 |
|---|---|---|---|---|---|
| **Settlement** (the ladder of thread 3) | Any land but high peaks | Countryside | Hamlet, then village (church) | Town (palisade, gates) | City (stone wall, cathedral), then great city (suburbs) |
| **Fields** | Plain, lowland | Rough grass, a few strips | Strip fields round the farms | Hedged blocks, barns, a mill | Estates: big blocks, canals, windmills |
| **Vineyards** | Sunny hills | Scrub | A few rows by the farms | Rows over the lower slopes, press house | Terraced slopes, a wine estate |
| **Olive terraces** | Warm coast hills | Scrub and pine | Scattered groves | Dry-stone terraces | Terraces to the ridge, oil mill |
| **Pasture** | Highland, poor hills | Rough grazing | Flocks, shepherd huts | Fenced meadows, dairy | Alpine farms, a wool or cheese market |
| **Woods to logging** | Woods | Wild wood | Clearings, charcoal burners | Managed wood, sawmill on the stream | Timber yard, log rafts (shipbuilding wood) |
| **Mine or quarry** | Hills and mountains with ore or stone | Bare rock | Adit and huts | Shaft, wheel, spoil heaps | Works with smelter and a miners' village |
| **Drained marsh** | Marsh, floodplain | Marsh | Dykes and ditches | Wet meadows or rice | Becomes Fields stage 2 |
| **Harbour** | Sheltered coast, lake or big river | Beach, boats | Jetty | Quay, mole, warehouses | Great port: two moles, lighthouse, shipyard |
| **Castle** | Any land | None | Tower | Castle | Bastion fortress (holds an area, see `../castle-areas.md`) |
| **Roads and bridges** | Hex to hex | None | Track, ford or ferry | Road, timber bridge | Highway, stone bridge |

**How the look changes while the terrain stays.** The hills, ridges, river, coast and the hex's height never move.
Growth changes only what stands on them: more of the hex's scatter points become fields, vines or houses and fewer
stay trees or scrub; the palette warms from wild green to worked gold and ochre; one new landmark appears per stage
(a mill, a press house, a wheel). Woods thin from the valley floor upward, never from the crest, so a wooded hill
still reads as a wooded hill.

## 3. Who decides

**Recommended: the player sets the direction, the people fill it in.**

- **The player chooses** each hex's *main use* (one of the land chains above) and pays for the crown's works:
  castles, harbours, roads and bridges, mines, drainage, and every step to stage 3.
- **The people grow** by themselves: in peace, a hex with a road to a market town climbs slowly from bare to
  stage 2 in its main use, and hamlets become villages. Without a player choice the people pick what the land suits.
- **War, plague and neglect push back:** a sacked or looted hex drops a stage and shows it (burnt roofs, fallow
  strips) until it recovers. This is also the brake on snowballing.
- **Limits per hex:** one main use, plus one settlement, one castle, one harbour and its roads. A city of level 4 or
  5 takes most of its own hex, and its farmland shows in the six hexes round it.
- **Costs and time (starting values):** stage 1 about 40 gold and 1 year; stage 2 about 100 and 2 years; stage 3
  about 250 and 4 years, and only next to a town or better. A country runs 1 work at a time plus 1 per city. Each
  stage has a small upkeep, so over-building hurts.
- **AI countries** use the same site score the map generator uses ("what does this land suit, how near is a market")
  plus a temperament in data: a trading republic favours harbours and vines, a border duchy castles and roads. The
  AI obeys the same costs and limits.

Alternatives: *all by hand* (every stage is a player order: full control, far too many clicks on 122,000 hexes) or
*all automatic* (the map grows like a screensaver: pretty, no decisions).

## 4. Does it work on the current kind of map? Yes, with four changes

It fits well, because the design already separates fixed things from things that stand on them.

- **The generator makes the 1480 start, then steps back.** Steps 0 to 7 of the build run once. Growth then changes
  per-hex facts the design already has (`cover`, `settlement`, `castle`, `port`) plus two new ones (`main_use`,
  `stage`). A save game stores only the hexes that differ from the start.
- **The puzzle solver is not re-run in play.** Its neighbour rules are kept as a *checklist*: a change is allowed
  only if the new ground may sit next to its neighbours.
- **Terrain limits what can be built** (the "where" column above), read from height, cover, fertility, ore and
  harbour shelter. Height never changes. Cover changes only one step (woods thinned, marsh drained).
- **Redraw is local.** Objects sit on one map-wide grid and are picked by a fixed hash, so a changed hex redraws
  itself and its six neighbours (the ground colours blend across the edge, and fields spill over it); a city also
  redraws its second ring. Nothing else flickers or moves.
- **Roads join by themselves:** a new road runs centre to centre through edge middles, so it meets the old ones at
  the hex centre, and a bridge appears wherever it crosses a river edge.
- **A stage is a district.** At 28 km a hex holds dozens of villages. "Fields stage 3" means "a rich farming
  district", shown by many small pieces, not one big farm sprite. The Python game's one-sprite levels do not carry
  over.

**What must change in the existing docs:**

1. `README.md` default D4 and `03-settlements-and-roads.md` ("roads are fixed when the map is made", "sockets never
   move"): roads and bridges can be built and improved in play. A new road adds a socket on both sides of an edge,
   so both hexes redraw.
2. `03` section 7: the field and suburb "spill" round a town "holds no state". It now follows the neighbours'
   own `main_use` and `stage`, with the town's size as a bonus.
3. `04-wfc-model.md` sections 3.4 and 8: add the two hex facts, the checklist use of the cover rules, and the
   redraw rule (hex plus ring 1, city plus ring 2).
4. `05-tiles-and-objects.md`: the piece list grows by the stage pieces (about 11 chains x 3 stages, at three zooms),
   and the generator must be told to start the countryside *under-dressed*.

**Honest risks.** The art cost is the big one: every stage at every zoom, and the close zoom of Genoa was partly
placed by hand; growth needs rules instead. Drawing 122,000 hexes with changing content is not measured yet. And a
map that only ever gets fuller can get noisy; stage 3 must stay rare.

## 5. The three zooms

| Zoom | What growth looks like |
|---|---|
| **Wide** (all of a country) | Colour and texture only: wild land is deep green, worked land a lighter patchwork; town plates get bigger; roads thicken; one small mark for a mine, castle or port. You see *where* a country is rich. |
| **Middle** (the play zoom) | Blocks: field blocks, vine rows and terraces as patterns, one landmark piece per stage, town pictures by level, bridges. You see *what* each district does. |
| **Close** | Everything in the Genoa close-up: single farms, hedges, terraces, mills, quays, ships, carts on the roads, and scaffolding or fresh earth on a work in progress. You see *how* it looks, as a reward. |

## 6. Mountains with real depth (to be decided later)

Three options to mock up when the owner wants; no decision now.

- **A. Stronger light.** Keep today's ranges, add long cast shadows into the valleys, darker shaded faces and
  paler, hazier ridges behind. Cheapest.
- **B. Relief shading under the art.** Bake a light-and-shadow layer from the real height data, so valleys, spurs
  and the fall of the land show even where no peak is drawn. Medium cost; fits the 2D decision.
- **C. Stepped land.** High ground is drawn lifted, with a visible scarp face where it rises from the plain, like
  a raised board. Strongest depth; changes how every piece on high ground is placed.

## 7. Mockup spec for the art director

The Genoa close-up (same camera, coast, ridges, torrents, town sites, palette and rules), drawn four times. The
picture that exists today is close to panel 3.

| Panel | Year | What differs |
|---|---|---|
| **1. Start** | 1480 | Genoa as a walled city with the old mole only and a small quay; Savona and Chiavari as villages without walls; 2 hamlets, not 7; woods down to the valley floors; scrub and rough pasture on the coast hills, no terraces; strip fields only beside Genoa and Savona; the Giovi a mule track with a ford, no hospice; 1 watchtower; 3 or 4 ships. |
| **2. Early growth** | about 1520 | 4 hamlets; clearings in the lower woods; first olive groves and vine rows near the hamlets; field blocks along the Polcevera; a timber bridge; a jetty at Chiavari; Savona gets its church and wall begun (scaffolding); the Giovi a cart road. |
| **3. Developed** | about 1600 | Today's picture: terraces, vineyards, 7 hamlets, stone bridges, hospice, new mole and Lanterna, shipyard, watchtowers along the coast. |
| **4a. Trade and wine** | 1650 | Great port (both moles, long quay, warehouses, twice the ships, shipyard with three hulls); terraced vines and olives up to the ridges; press houses; Savona and Chiavari as port towns; highway over the Giovi with mule trains; few walls beyond Genoa's. |
| **4b. Grain and castles** | 1650 | Harbour as in panel 2; valley floors and low hills in hedged grain blocks with mills on the torrents; woods kept on the slopes; a bastion fortress above Genoa and a castle at the Giovi; Savona walled; garrison flags; fewer ships. |

In every panel the same hills must be recognisable at a glance. Please also give panels 1, 3 and 4a at the middle
and wide zoom as small strips, to test section 5.

## 8. Questions for the owner

1. **How plain is the start?** *Recommended: B, lived-in but unfinished* (real cities and main roads at 1480 size,
   rough countryside). Or A, an empty land; or C, the fully dressed map.
2. **Who makes the map grow?** *Recommended: both*: you pick each district's use and pay for the big works; the
   people fill in the first stages in peacetime. Or every step by hand; or all automatic.
3. **May the ground itself change?** *Recommended: one step only*: woods can be thinned and marsh drained, but
   heights, rivers and coasts never change. Or nothing changes under the improvements; or free clearing (any wood
   can become open farmland).
