# The growing map: Genoa at five moments (mockup)

Art director. **Status: a mockup for the owner, for section 7 of `../06-growing-map.md`. Nothing in the game is changed.**

| File | What it shows |
|---|---|
| `growth_1480.png` | Panel 1, the start |
| `growth_1520.png` | Panel 2, early growth |
| `growth_1600.png` | Panel 3, developed (close to today's close-up) |
| `growth_1650_trade.png` | Panel 4a, trade and wine |
| `growth_1650_grain.png` | Panel 4b, grain and castles |
| `growth_sheet.png` | All five, labelled, with a short key |
| `growth_zoom_strips.png` | Panels 1, 3 and 4a at the middle and the wide zoom |
| `alignment.png` | Panel 3 beside the normal map, with the hexes and each district's use and stage |
| `alignment_before.png` | The same sheet before the hex rule, kept for comparison |

Every panel is 1280x720, drawn by the same code from one record of data per stage. The camera, coast, ground tones,
hills and ranges (places and outlines), the torrent, town sites, road lines and palette are the same in all five.

## One city, one hex (2026-11-15)

The owner's rule: **one city, one hex, drawn inside it.** What you own, upgrade or capture is exactly what you see; a
growing city fills more of its own hex and never spills over the border. All panels were redrawn to it.

- **Every 28 km hex of the normal map is one district** with one main use, one seat (its only settlement) and a
  stage per panel. The table is `DISTRICTS` in `stages.py`; a stage (0 wild to 5 great city) decides the seat's
  size, which farms and field blocks stand, how far the woods are thinned and how many terrace lines the hills carry
  (`LOOK`). 4a and 4b differ only in what the rich districts grow (wine or grain) and in Genoa's works.
- **Everything a district owns stands inside its hex**, clear of the border: seat, farms, field parcels, press
  houses, barns, watchtower, harbour works. The code tests it (`growth.check_layout`, and each parcel and house
  when it is placed). Hills and ranges are land, not property, and may cross.
- **Genoa** (hex 8,13 in the map data) stands in the middle of its hex and takes about half its width. Its basin is
  the corner of sea that lies inside the hex; both moles stay inside it, also in the great port of 4a.
- **Savona** (7,13) and **Chiavari** (9,13) stand inside their hexes on their own strand.
- **The coast is the normal map's line.** Only three harbour coves are cut into it (Genoa 2.5 km, Chiavari 1.5 km,
  Savona 3.5 km at the deepest point); the code refuses anything further than 3.5 km from the map's line.
- **The torrent is the map's stream** on the border of Genoa's and Chiavari's hexes (the Bisagno). The Polcevera is
  gone: the map data has no stream there.
- **The roads are the map's roads.** The coast road follows the map's line from Savona to the centre of Genoa's hex
  and on over the bridge to the centre of Chiavari's hex; the Giovi road comes down to the same junction, behind
  Genoa's north gate. A short road leads from Chiavari's hex centre down to the village.

| Hex | District | Main use | Seat | 1480 | 1520 | 1600 | 1650 trade | 1650 grain |
|---|---|---|---|---|---|---|---|---|
| 8,13 | Genoa | city and port | Genoa (city) | 2 | 3 | 4 | 5 | 4 |
| 7,13 | Savona | farmland | Savona (town) | 1 | 2 | 3 | 4 | 4 |
| 9,13 | Chiavari | terraced coast | Chiavari (village) | 1 | 2 | 3 | 4 | 3 |
| 9,12 | Giovi | pass road | pass post | 1 | 2 | 3 | 4 | 4 |
| 8,12 | Stura | woodland | hamlet from stage 2 | 0 | 1 | 1 | 2 | 2 |
| 10,12 | Antola | high woods | none | 0 | 0 | 1 | 1 | 1 |
| 10,13 | Fontanabuona | wooded hills | hamlet from stage 2 | 0 | 1 | 2 | 3 | 3 |
| 8,14 / 9,14 / 10,14 | Savona roads, Gulf of Genoa, Riviera | sea | none | | | | | |

`alignment.png` shows panel 3 with the hexes and these labels, next to the normal map; the thin lines are the normal
map's own coast, roads and torrent. `alignment_before.png` is the same sheet before the change (Genoa across the
border of 8,13 and 9,13).

**Where the two zooms still differ, and why.** The normal map (the style frame) draws Genoa and Chiavari at their
real longitude and latitude, which puts Genoa 1.4 km from the border of its hex and Chiavari on a strip of shore that
belongs to a sea hex. The close-up moves both inside their hexes (about 12 km west each), so the last stretch of the
Giovi road and of the road to Chiavari leaves the map's line. The fix belongs to the normal map: draw every town at
its hex's site, not at its coordinates.

## What changes per stage

| | 1. 1480 | 2. about 1520 | 3. about 1600 | 4a. 1650 trade and wine | 4b. 1650 grain and castles |
|---|---|---|---|---|---|
| District seats besides the towns | pass cairn only | pass hut | pass hospice, a hamlet in Fontanabuona | hamlets in Stura and Fontanabuona (a village with its church) | as 4a |
| Savona | village, no church, no wall | church, wall begun with scaffolding | walled town, jetty | port town: quay, mole, light | walled, garrison flags |
| Chiavari | 4 houses and a church | 6 houses, a jetty | 8 houses, jetty | port town: quay, mole | 9 houses, a flagged tower |
| Woods | down to the valley floors, dense | clearings, stumps, charcoal smoke | today's | thinner; slopes cleared for terraces | as 3, kept on the slopes |
| Coast hills | scrub, no terraces | 2 terrace lines near settlements | 5 lines, olives | 7 lines to the top, vines and olives; ranges terraced on the lower slopes | 3 lines |
| Fields | open strips in Savona's and Chiavari's hexes, 3 blocks by Genoa | more blocks, first groves on Chiavari's coast | 23 hedged blocks, mixed, each inside its hex | the rich hexes turn to vines and olives, 9 new vineyards | the rich hexes turn to grain, 14 new hedged blocks with trees |
| Landmarks | none | none | none | press houses by the farms, an oil mill on the Bisagno | 2 water mills, barns with hay |
| Giovi road | mule track | cart road | road | paved highway, milestones | road |
| Pass | cairn | cairn and a hut | hospice | hospice, inn, stable | castle |
| Coast road | cart road, a ford | timber bridge | stone bridge | highway | road |
| Genoa harbour | old mole, short quay, 2 piers, strands with boats, old light tower | longer quay, 3 piers, one hull on the slip | full quay, 4 piers, new mole, Lanterna, 2 hulls, crane | both moles longer (still inside the hex), 8 piers, warehouses on the mole, 3 hulls, 2 cranes | as panel 2 |
| Genoa town | 4 house rows, 2 churches, gardens inside the wall | 5 rows, 3 churches, 2 houses outside | 6 rows, 4 churches, 5 suburb houses | 9 suburb houses, all inside the hex | bastion fortress on the crest, flags on the wall |
| Watchtowers (one to a coastal district) | 1 | 2 | 3 | 3 | 3 with flags |
| Ships | 4 | 7 | 15 | 30 | 7, three of them galleys |
| Road traffic | 1 mule train | 2 | 2 | 8 trains and carts | 3 |
| Ground colour | wild green | a little worked | today's | warmer | warmest |

## Rules and hand placement

**By rule (works for any stage record):**
- The hills are placed once, from the layout of panel 3, and that set is used for every panel. This is why the land
  is recognisable: no hill appears, moves or vanishes.
- Trees, slope woods and field parcels have fixed places and their own dice. A stage only adds or removes them; a
  tree that stands in two panels is the same tree.
- Woods are cleared from the foot of a slope upward, never from the crest. Terraces climb the same way.
- A district's seat grows on a fixed site (3 houses, then a village with a church, then a large village). Fields
  keep off a site that is not built yet.
- New field blocks in 4a and 4b are placed by score, only in districts at stage 4 or more and inside their hex:
  grain takes the low ground near the torrent, vines the low sunny hills; both keep off towns, roads, hills and
  reserved sites.
- Mills sit beside the torrent, press houses and barns beside a farm, cart tracks run from each built hamlet and
  farm to the nearest road of its own hex, the bridge stands where the road crosses the torrent, town quays follow
  the shore.
- The ground colour shifts with two numbers per stage (how much farm and wood colour shows).

**Placed by hand:** Genoa's layout and every harbour work, the seat sites, the 14 farm sites, the 29 field blocks
(each with the stage that builds it), the last stretch of each road inside a settlement's hex, the ships, the pass
buildings. The district table says which of them exist and at what level. The coast, the torrent and the road
lines come from the normal map.

**Code:** `tools/worldmap/closeup_2d/stages.py` (the data), `growth.py` (draws a stage), `sheets.py` (sheet and
strips). `closeup.py`, `terrain.py` and `paint.py` gained optional parameters and new pieces. Run
`python tools/worldmap/closeup_2d/growth.py OUT_DIR` for everything, or `closeup.py OUT_DIR --stage 1|2|3|4a|4b|all`.
Without `--stage` the close-up is panel 3 (one layout, no second copy). `alignment.py` makes the alignment sheet.

## Weak points

- **Genoa is smaller than before** (about 15 km of the hex's 28 instead of 19 km across two hexes), with a tighter
  basin; the town hill hardly shows behind the houses now.
- **The country is less lush**: three seats in view besides the towns instead of seven hamlets, one torrent
  instead of two, no hairpins on the Giovi road.
- **Savona's hex has almost no sea of its own** on the map's coast, so its cove is the deepest cut (3.5 km) and its
  harbour is a short quay, not a jetty or mole. Chiavari's mole in 4a is a stub for the same reason.
- **The stage of a hex also steps the woods at the border** (thinner on the developed side). It reads as a soft
  change in these panels; with very unequal neighbours it could show as a line.
- **The ground colour is still one setting per panel**, not per hex.
- **4b does not follow from 3.** The spec asks for the harbour of panel 2, so the new mole and the Lanterna of
  panel 3 are missing. Read 4a and 4b as two players' maps, each branching off before 1600.
- **The zoom strips are reductions of the close-up**, with name plates added afterwards. They are not art made for
  those zooms. The wide strip does show wild against worked land by colour; the middle strip shows town size, the
  fleet and the field patchwork, but terraces, mills and press houses are too small to read. The style frame row
  shows that the real middle zoom draws fewer, larger pieces; staged versions of those are not drawn yet.
- **Savona's wall in work is hard to see**: the scaffolding stands on the far side of the town, behind the houses.
- **The first vines and olives in panel 2 are few and small**; the step from 2 to 3 is larger than from 1 to 2.
- **4a is busy.** Thirty ships and three ports fill the sea; it reads as rich, but it is near the limit.
- **The bastion fortress is half hidden** by the top house rows, and it is one new piece, not a set.
- **Rule-placed fields can look scattered** on the western hills in 4a and 4b; a real rule would group them into
  estates round a farm.
- **Unbuilt sites are invisible.** A reserved hamlet site in panel 1 is just wood; nothing tells the player that
  something can stand there.
- **Still hand-made:** Genoa and the site lists. The staging proves the idea for one hex group, not the cost of
  rules for the whole map.
- New pieces (mill, press house, warehouse, barn, fort, timber bridge, ford, scaffolding, cart) are first drafts.

## For the owner to decide

1. **Is the start plain enough?** Panel 1 is option B of the design (lived-in but unfinished). Wilder (fewer strips,
   no coast road) or fuller are both one data change.
2. **Is the land recognisable enough?** If yes, the rule "hills are placed once and never depend on what is built"
   should go into the design.
3. **Middle and wide zoom:** accept reduction as the test, or ask for staged pieces at the middle zoom (blocks and
   one landmark per stage) as the next mockup (recommended before any build).
4. **4b's harbour:** keep as specified (panel 2's harbour), or let 4b keep panel 3's mole and Lanterna.
