# M1 trial: the north Italy view on hex tiles

Technical director, 2026-11-15. The first step of milestone M1 (`docs/architecture/godot-architecture.md`, section
11: "the tile look must match the approved style frame; riskiest item"). **Status: waits for the art director's
review and the owner's sign-off.** The build spec is `docs/architecture/m1-build-spec.md`.

- `side_by_side.png`: the whole view. Left: today's Godot map (one baked picture per season, 3,268 placed trees).
  Right: the same view drawn from reusable hex tiles on `TileMapLayer`s. Same hexes, same seed (1480), same pieces.
- `close_crop.png`: Genoa, the plain and the woods at twice the size.

Both pictures are windows of the running engine (Godot 4.7.2, 1280 x 720), not mock-ups.

## What the right-hand picture is made of

A tileset of 614 tiles (3.1 MB), baked in 20 seconds from the Python art code, and **no picture of the map**:

| Layer | Tiles | Where from |
|---|---|---|
| Ground | one per hex by cover and height band, a little larger than the hex with a soft edge | the style frame's colours and stone scatter |
| Relief shade and light | one per hex by slope, blended into a smooth field | the style frame's slope tones, from the hex heights |
| Sea | shelf, sea, deep | the style frame's sea colours and wave marks |
| Coast | one per coast hex by which sides are sea: sand or cliff, foam, light water, a drawn wobble | new, in the style frame's colours |
| Rivers, roads, tracks | drawn at run time from the map data as one mesh per chunk | the style frame's widths and colours |
| Trees | six wedge tiles a hex (so a wood can make way on one side) | the style frame's own tree drawing |
| Hills and ridges | one tile a hex, wider than the hex | the style frame's own hill and range drawing |
| Pieces | ground, shadow, back band, front band | today's baked pieces, unchanged |

## What matches

- **The hex grid:** every hex is where it is today (the two pictures line up hex for hex).
- **The pieces:** towns, fields, harbours are the same pictures in the same places. The back and front bands sort
  correctly with the trees.
- **Colours and drawing style:** ground colours, trees, hills, peaks, rivers and sea are the style frame's own code
  or its numbers.
- **Soft ground:** covers still run into each other softly; the slope light still shows the land's shape.

## What differs, why, and what is planned

| # | Difference | Why | Verdict / fix |
|---|---|---|---|
| 1 | **The coast follows the hex edges** (rounded, with a wobble), not the real shoreline. Genoa's wide bay, the capes and coves of today's picture are gone; land hexes are whole | A tile belongs to a hex. The owner accepted this on 2026-11-15 | Accepted in principle; this picture shows what it means. Fix planned: art director tunes the wobble and where cliffs start. Genoa keeps a small carved bay inside its hex |
| 2 | **Roads are different roads.** Today's nine roads were drawn by hand for the style frame. The trial draws the map data's road network: more roads, and thin tracks to the villages | The standard: lines come from the data | Not a look problem; the network is the game's. The line style matches. Bridges are missing (planned, task T15) |
| 3 | **The Alps read as rows of ridges.** Today a range follows its crest line across hexes with spurs; the trial puts one ridge tile on each high hex | One tile a hex | **The weakest part.** Planned: more variants, a taller form for crest hexes, ridge forms that lean along the crest edge. Art director to judge |
| 4 | **Woods are blockier and a little thinner.** Today each tree is placed by a smooth density field; the trial fills wedges of hexes. A wood's outline follows hex sixths, softened by a fringe | Tiles | Acceptable at play zoom in my judgement; density and fringe are numbers to tune |
| 5 | **Trees thin by wedge, not one by one.** A built hex in a wood keeps a ring of trees; a river or road clears its side of the hex | The standard, section 3.5 | As expected |
| 6 | **No mountains or hills in front of a built hex are cut individually;** a built hex's ridge moves to its back half | Same | As expected |
| 7 | **Ground blends over 34 px on one side of an edge** (the stronger cover spills onto the weaker), where today the blend is about a whole hex wide | A tile can only be so much larger than its hex | Close enough; the rank order of covers is the art director's call |
| 8 | **Marsh is green with pools** (two hexes, top right). Today it is drawn as stone | Today's picture treats every cover after woods as rock (a stand-in) | An improvement; needs the art director's eye |
| 9 | **Cliffs are fewer and shorter** | The trial puts a cliff where the hex is hill country or higher, and never at a port | A rule to tune |
| 10 | **Harbours sit on the hex edge** and reach into the sea hex | The shore moved to the edge | As designed (seaside ports); Genoa's is in its bay |
| 11 | Spring, autumn and winter are not baked in the trial | Summer only, to get to this picture | In the build (task T9) |

## The two Godot behaviours the standard asked to confirm

1. **Stacked hex layout = our odd-r grid: yes.** `godot/tests/shell/test_tile_grid.gd`: cell centres equal for 4,356
   cells, the hex under 20,000 random points equal, the six neighbours equal.
2. **Y-sorting tall tiles across layers in one group: yes.** `godot/tools/mapview/probe_ysort.gd` on the real
   renderer, four cases, all pass: the lower row is in front whichever layer it is on; on one cell the tile's own
   sort point decides.

## Speed (first reading; the real test is task T12)

A made-up map of 494 x 247 = 122,018 hexes (81,478 land; 474,550 cells on 20 layers; a river every six rows),
trial tileset, window 1920 x 1080, sync off, panning (`godot/tools/mapview/probe_fake_europe.gd`):

| Zoom | Hexes on screen | Mean frame | Worst frame | Draw calls |
|---|---|---|---|---|
| 2.0 | 65 | 2.3 ms | 3.7 ms | 62 |
| 1.0 | 260 | 2.6 ms | 3.8 ms | 108 |
| 0.5 | 1,040 | 3.3 ms | 5.1 ms | 193 |
| 0.25 | 4,170 | 4.7 ms | 6.3 ms | 364 |
| 0.12 | 18,100 | 8.6 ms | 11.7 ms | 759 |

Under the 16 ms budget at every zoom, before the far-zoom picture exists. Filling the map took 2.7 s (the build
slices it, nearest the camera first). The cells cost 269 MB (about 570 bytes a cell, not "a few bytes" as the
standard guessed): inside the budget, but worth watching. The north Italy trial view itself: 0.4 ms a frame
(today's scene: 2.1 ms).

**One finding changed the design:** rivers and roads drawn with canvas commands (`draw_polyline`) cost 18 ms a
frame on a map of only 7,200 hexes, because the engine re-sends them every frame, on screen or not. As one mesh
per chunk they cost nothing measurable. The spec says so (section 6 and 9).

## How to make the pictures again

From the repository root, with `GODOT` set and `LAYERS` the map prototype's exported layers file:

```bash
python tools/worldmap/tileset_bake/trial_map.py --layers "$LAYERS"                      # the facts the trial draws
"$GODOT" --headless --path godot --import
"$GODOT" --headless --path godot -s res://tools/mapview/dump_trial_tiles.gd -- --out=<names.json>
python tools/worldmap/tileset_bake/bake_trial.py --layers "$LAYERS" --needs <names.json>   # the tileset, about 20 s
"$GODOT" --headless --path godot --import
"$GODOT" --path godot -s res://tools/mapview/shot_trial.gd -- --out=<folder>            # the four shots, windowed
python tools/worldmap/tileset_bake/side_by_side.py <folder>                             # writes the two PNGs here
"$GODOT" --path godot -s res://tools/mapview/probe_ysort.gd                             # the y-sort check
"$GODOT" --path godot -s res://tools/mapview/probe_fake_europe.gd                       # the speed reading
```

## Known shortcuts of the trial (the build removes them)

- The facts come from `assets/tiles/trial/trial_map.json`, a copy of the map prototype's layers file, and the
  pieces from today's `meta.json` hex table. The build reads `MapData`.
- Only the coast shapes and pieces this view needs are baked; piece tiles are put together from today's whole-map
  bake instead of drawn from the families.
- The decor bake imports the style frame (which builds its world) to borrow its drawing code.
- No selection, no building, no far zoom, no seasons.
