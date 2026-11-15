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

Every panel is 1280x720, drawn by the same code from one record of data per stage. The camera, coast, ground tones,
hills and ranges (places and outlines), torrents, town sites, road lines and palette are the same in all five.

## What changes per stage

| | 1. 1480 | 2. about 1520 | 3. about 1600 | 4a. 1650 trade and wine | 4b. 1650 grain and castles |
|---|---|---|---|---|---|
| Hamlets | 2, three houses each | 4 (one has its church) | 7 villages | 7, three grown large | 7, three grown large |
| Savona | village, no church, no wall | church, wall begun with scaffolding | walled town, jetty | port town: quay, mole, light | walled, garrison flags |
| Chiavari | 4 houses and a church | 6 houses, a jetty | 8 houses, jetty | port town: quay, mole | 9 houses, a flagged tower |
| Woods | down to the valley floors, dense | clearings, stumps, charcoal smoke | today's | thinner; slopes cleared for terraces | as 3, kept on the slopes |
| Coast hills | scrub, no terraces | 2 terrace lines near settlements | 5 lines, olives | 7 lines to the top, vines and olives; ranges terraced on the lower slopes | 3 lines |
| Fields | open strips by Genoa and Savona | blocks along the Polcevera, first groves by hamlets | 20 hedged blocks, mixed | the same blocks in vines and olives, 10 new vineyards | the same blocks in grain, 16 new hedged blocks with trees |
| Landmarks | none | none | none | 5 press houses, an oil mill | 4 water mills, 5 barns with hay |
| Giovi road | mule track | cart road | road | paved highway, milestones | road |
| Pass | cairn | cairn and a hut | hospice | hospice, inn, stable | castle |
| Coast road | cart road, two fords | timber bridge and one ford | two stone bridges | highway | road |
| Genoa harbour | old mole, short quay, 2 piers, strands with boats, old light tower | longer quay, 3 piers, one hull on the slip | full quay, 4 piers, new mole, Lanterna, 2 hulls, crane | both moles longer, 8 piers, warehouses, 3 hulls, 2 cranes, east quay | as panel 2 |
| Genoa town | 4 house rows, 2 churches, gardens inside the wall | 5 rows, 3 churches, 2 houses outside | 6 rows, 4 churches, 5 suburb houses | 9 suburb houses | bastion fortress on the crest, flags on the wall |
| Watchtowers | 1 | 2 | 3 | 3 | 3 with flags |
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
- Hamlets grow on a fixed site (3 houses, then a village with a church, then a large village). Fields keep off a
  site that is not built yet.
- New field blocks in 4a and 4b are placed by score: grain takes the low ground near the torrents, vines the low
  sunny hills; both keep off towns, roads, hills and reserved sites.
- Mills sit beside a torrent, press houses and barns beside a village, cart tracks run from each built hamlet and
  farm to the nearest road, bridges stand where a road crosses a torrent, town quays follow the shore.
- The ground colour shifts with two numbers per stage (how much farm and wood colour shows).

**Placed by hand (as in today's close-up):** Genoa's layout and every harbour work, the 7 hamlet sites, the 8 farm
sites, the 20 field blocks, the road lines, the two torrents, the ships, the pass buildings. The stage record only
says which of them exist and at what level.

**Code:** `tools/worldmap/closeup_2d/stages.py` (the data), `growth.py` (draws a stage), `sheets.py` (sheet and
strips). `closeup.py`, `terrain.py` and `paint.py` gained optional parameters and new pieces. Run
`python tools/worldmap/closeup_2d/growth.py OUT_DIR` for everything, or `closeup.py OUT_DIR --stage 1|2|3|4a|4b|all`.
Without `--stage` the close-up is drawn exactly as before (checked: the file is byte-identical).

## Weak points

- **Panel 3 is close to today's picture, not identical.** Single trees and field parcels differ, because the staged
  panels use the fixed-place dice. Hills, towns, roads and the harbour are the same.
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
