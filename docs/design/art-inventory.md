# Art inventory: how today's art comes to Godot

Art director, 2026-11-14. Release 0.3.0, item 5 (`docs/roadmap/release-0.3.0-brief.md`; the pipeline is
`docs/roadmap/godot-port-plan.md` B7). Every piece of art the Python game draws, and what happens to it in the port.

## How to read it

Each group gets one of four marks:

- **Baked as it is.** The Python art code draws the picture once into an atlas; Godot shows it unchanged.
- **Baked as pieces.** The Python map view composes this per hex while the game runs (one picture from a coast, a
  river, a road and a town). The baker draws each part on its own, for every edge mask; Godot layers them.
- **Redone in Godot.** Lines, tints, text, fog and motion: Godot does these better with shaders, lines and tweens.
- **Later.** Not baked yet; baked or redone in the release that first shows it.

**Release** is the first Godot release that shows the piece. **Redesign** marks the pieces that the owner's redesign
of the game elements for Godot (decision 4 of the brief: units, towns, castles, panels, HUD) will replace. For 0.3.0
today's town and castle look is baked as the basic map art; the redesign replaces it later and is re-baked or drawn
in Godot then.

## The 0.3.0 bake

`python -m tools.bake_art` writes `godot/assets/baked/`: 12 atlas pages, `index.json`, and `kenney/` (the Kenney PNGs
the game shows unchanged, with the pack's CC0 licence). It runs in about 6 seconds.

- **Sizes.** Hex radius 60. The grid tile is 104 x 120 (pointy-top). Every sprite is 106 x 122: one pixel larger than
  the tile on every side, the same overlap the Python map view gives its sprites, so neighbours join without a
  hairline. Its anchor is its centre (53, 61), on the hex centre. Each sprite has a 2 px extruded border in the atlas
  (cells of 110 x 126). Pages are at most 2048 x 2048. Import with mipmaps on and linear filtering.
- **Edge masks.** Bit e of a mask is edge e in `hexgrid.neighbors` order: 0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE. Godot's
  TileMap neighbour order differs; the builder converts.
- **The index** gives each sprite: atlas page, rect, anchor, sort offset, layer, and the Python call that drew it.
  For each page it gives the size and the sha256. The hashes depend on the pygame build, as the sprite hashes do. The
  committed bake was made on Windows; CI's Linux bake replaces it when the CI job exists (plan B7).

| Atlas group | Sprites | Pages (px) | What |
|---|---|---|---|
| ground | 35 | 1 (1980 x 252) | 25 terrain tiles for 13 kinds and the lake, 9 sea tiles (sea, shallow, reef x 3), native camp |
| goods | 375 | 2 (1980 x 2016, 1980 x 630) | 25 goods x 5 levels x 3 variants |
| deco | 16 | 1 (1760 x 126) | trees, rocks, fields, hamlet x 4 seeds |
| coast | 375 | 2 (1980 x 2016, 1980 x 630) | 63 sea masks x 3 variants; 186 river mouths (river edge x sea mask) |
| river | 168 | 1 (1980 x 1260) | 56 masks (1 to 4 edges) x 3 variants |
| road | 216 | 1 (1980 x 1512) | dirt and paved x 63 masks; 90 bridges (2-edge road over 2-edge river) |
| town | 614 | 3 (1980 x 2016, 1980 x 2016, 1980 x 378) | 15 towns, 280 towns with gates, 310 harbours, 9 castles |
| landmark | 60 | 1 (1980 x 504) | 10 famous cities x 3 stages x 2 variants |
| **all** | **1,859** | **12**, about 15 MB | |

### How Godot layers the pieces (back to front)

This is what the Python map view draws at its tile zoom (`MapView._draw_tiles`, `overlay_desc`), split into layers:

1. **Ground:** `terrain/<kind>/<i>` (i as `MapView.land_sprite` picks it), `sea/sea/<v>`, `native_village`, or
   `goods/<good>/<level>/<v>` for a province with works.
2. **Coast:** `coast/<sea mask>/<v>`. A river mouth uses `mouth/<river edge>/<sea mask>` instead (coast included). A
   coastal town skips this layer (its harbour piece holds the coast).
3. **River:** `river/<mask>/<v>` (not on a mouth).
4. **Road:** `road/dirt/<mask>`, or `road/paved/<mask>` in a town of level 3 or more. A 2-edge road crossing a 2-edge
   river in open country uses `bridge/<road mask>/<river mask>` (road and bridges). A town with roads and no sea skips
   this layer (its gates piece holds the streets).
5. **Decoration:** `deco/<kind>/<seed>` on open land with nothing else, as `MapView.decorations_for` picks it.
6. **Town:** `harbour/<level>/<sea mask>` on the coast, else `town/<level>/gates/<road mask>` with roads, else
   `town/<level>/<v>`; `castle/<level>/<v>` for a castle without a town. Town levels as in `overlay_desc`: village 2,
   market town 3, walled town 4, city 5, great city 6.

The variant v is 0 to 2. The Godot builder picks it and stores it in the map file (plan B7). Python's position hash
is not copied.

**Checked by eye.** Five places in Python's Europe (Lisbon, Venice, Paris, Cologne, Constantinople) were drawn from the
Python composite and, next to them, from these pieces on a 104 x 120 grid. They match, with no seams. There are four
small differences, all acceptable for the basic look:
- Where a road runs along a river on the same edges, Python draws plank bridges at every edge. The pieces show the
  road beside the river.
- A town with gates or a harbour always uses variant 0.
- A walled harbour town has no gates.
- The sea tiles are opaque. Python's scaled sea is 1 percent see-through in the middle.

The walled harbour without gates is easiest to see at Constantinople, where the road meets a closed wall. One fault
is in both pictures, so it comes from today's art and not from the bake: a faint hairline in open water where a coast
piece's sea meets a plain sea tile. Fix it in the Python coast art and re-bake (0.3.1, when the map gains its coasts).

## The inventory

### The map at tile zoom (today radius 13): the 0.3.0 look

| Piece | Python source | Mark | Release | Redesign |
|---|---|---|---|---|
| Terrain tiles: plains, steppe, forest, hills, mountains, desert, jungle, tundra (Kenney tiles) | `data.TERRAIN_SPRITES` | Baked as it is | 0.3.0 | no (Kenney list) |
| Terrain tiles: marsh, taiga, snow, savanna, beach (code-built from Kenney props) | `art.make_tile` | Baked as it is | 0.3.0 | no (Kenney list) |
| Lake (flat blue `lake.png` in the Kenney folder) | `TERRAIN_SPRITES["lake"]` | Baked as it is | 0.3.0 | see decision 1 |
| Sea (3 variants); shallow and reef (drawn, not used by the map view) | `wfctiles.sea_tile` | Baked as it is | 0.3.0 | no |
| Native camp (Kenney Western tile) | `NATIVE_VILLAGE_SPRITE` | Baked as it is | 0.3.0 | yes (Kenney list) |
| Goods tiles, 25 goods x 5 levels | `goodsart.good_tile` | Baked as it is | 0.3.1 (province contents) | no |
| Decorations: trees, rocks, fields, hamlet (Kenney props) | `art.decoration` | Baked as it is | 0.3.0 | no (Kenney list) |
| Decorations: smoke, port, town, city | `art.decoration` | Later (not used by the AoD map view) | none | n/a |
| Coast by sea mask, river mouths | `wfctiles.coast_overlay`, `river_overlay(mouth=True)` | Baked as pieces | 0.3.0 | no |
| Rivers by edge mask | `wfctiles.river_overlay` | Baked as pieces | 0.3.0 | no |
| Roads (dirt, paved) by edge mask, bridges | `wfctiles.road_overlay` | Baked as pieces | 0.3.0 | no |
| Fords and ferries | `road_overlay(crossing=...)` | Later (the map view uses bridges only) | none | no |
| Towns, villages to great cities; with gates; harbours | `wfctiles.settlement_tile` | Baked as pieces | 0.3.0 | **yes** |
| Castles 1 to 3 (motte, stone castle, fortress) | `wfctiles.castle_tile` | Baked as pieces | 0.3.0 | **yes** |
| Landmark cities (10 x 3 stages) | `landmarks.draw_city` | Baked as it is (first on the cut list) | 0.3.0 if kept, else 0.3.5 | **yes** (towns) |
| Capital flag on the town | `MapView._flag` | Redone in Godot | 0.3.0 | yes |
| Town, country and pass names (text on a dark box) | `MapView._town_labels`, `_country_names`, `_pass_names` | Redone in Godot (labels) | 0.3.0 | yes (style) |
| Ridges and passes at radius 13 (ink lines) | `landscape.draw_far_ridges` | Redone in Godot (plain marks) | 0.3.0 | no |
| Province borders, owner washes, political marks | `MapView._owner_borders`, `_owner_washes`, `_political_marks` | Redone in Godot (lines, tints) | 0.3.0 | no |
| Winter frost dots and tint in the north | `MapView.overlay("frost")`, `_tint` | Redone in Godot (shader) | 0.3.1 (seasons) | no |
| Fog: black unknown hexes, dimmed unseen hexes | `MapView.overlay("black")`, `DIM` | Redone in Godot (shader, one texel a hex) | 0.3.3 | no |
| Map modes: goods chips, prices, market colours, mode washes | `MapView._mode_layer`, `chip` | Redone in Godot | 0.3.1 | yes (chips) |

### The far map (today radius 3, 5 and 8)

| Piece | Python source | Mark | Release | Redesign |
|---|---|---|---|---|
| Flat terrain and country colours per hex | `MapView._render`, `TERRAIN_TINT` | Redone in Godot (one small texture per mode, plan B8) | 0.3.0 | no |
| Far ridge lines, decorations, country names | `_render`, `_decorations`, `_country_names` | Redone in Godot | 0.3.0 | no |
| Zoom backdrop (old frame scaled while tiles build) | `MapView._zoom_backdrop` | Not needed (Godot zooms smoothly) | none | n/a |

### The close-up landscape (today radius 21 and 34): later, decision 2

| Piece | Python source | Mark | Release | Redesign |
|---|---|---|---|---|
| Ground blend bands by pair of ground kinds and edge; ground detail, clearings, field systems | `landscape.ground` | Baked as pieces | 0.3.1 | no |
| Ground textures (Kenney grass, dirt, sand, stone) | `landscape` `GROUNDS` | Baked as it is | 0.3.1 | no (Kenney list) |
| Ridge crests by edge, pass corridors, hospices, winter snow marks | `landscape.Ridges`, crest drawing | Baked as pieces | 0.3.1 (ridges), 0.3.5 | no |
| Mountains, hills, trees, ground clutter (33 objects x 3 sizes x 4 seeds), nature tiles and scatters | `nature.py` | Baked as it is | 0.3.5 | no |
| Coast and sea life, ruins, holy places (objects and scatters) | `life.py` | Baked as it is; the motion redone (tweens) | 0.3.5 | no |
| Goods objects for the deposits view (25) | `goodsobjects.py` | Baked as it is | 0.3.1 | no |
| Hex grid outline (G key) | `landscape.grid` | Redone in Godot (lines) | 0.3.1 | no |
| Winter versions of ground and objects | `landscape`, `nature` (snowy trees) | Baked as pieces | 0.3.5 | no |

### Units, marks and motion on the map

| Piece | Python source | Mark | Release | Redesign |
|---|---|---|---|---|
| Unit figures (16 kinds), faded figures | `art.figure` | Baked as it is if the redesign keeps them | 0.3.2 | **yes** |
| Unit tokens, eras 1 and 2 | `art.token` | Baked as it is if the redesign keeps them | 0.3.2 | **yes** |
| Stack diorama, shields, count badges, war-stack layer | `MapView._diorama`, `_shield`, `_badge` | Redone in Godot | 0.3.2 | **yes** |
| Marches, path preview, castle zones, war areas | `MapView._movement`, `render/warareas.py` | Redone in Godot (lines) | 0.3.2 | **yes** |
| Battle and siege marks on the map | `render/battlemark.py`, `hud/siegebadge.py` | Redone in Godot | 0.3.2 | **yes** |
| Floating ribbons (gains, losses) | `hud/floating.py` | Redone in Godot (tweens) | 0.3.2 | **yes** |
| Replay of AI moves | `replay.py` | Redone in Godot (tweens) | 0.3.3 | yes |

### Interface

| Piece | Python source | Mark | Release | Redesign |
|---|---|---|---|---|
| Icons (code-drawn glyphs) | `ui/icons.py` | Baked as it is, if the redesign keeps them | 0.3.1 | **yes** |
| Buttons, panels, rows, tooltips, modals, colours and fonts | `ui/kit.py`, `ui/theme.py` | Redone in Godot (one Theme) | 0.3.1 | **yes** |
| Top bar, action log, odds card, move card, tasks, battles and sieges lists | `campaign/hud/` | Redone in Godot | 0.3.1 to 0.3.4 | **yes** |
| Province, country, market, ledger, unit, raise and card panels | `campaign/panels/` | Redone in Godot | 0.3.1 to 0.3.5 | **yes** |
| Battle screen, tech screen, game menu, start menu | `campaign/screens/`, `techdraw.py`, `hexa/menu.py` | Redone in Godot | 0.3.4, 0.3.5 | **yes** |

### Not baked: unused by Age of Discovery today

- `art._TILES` vineyard, pasture, plantation (`data.GOOD_SPRITES` is never read).
- `wfctiles` lake, marsh, mountain and wall overlays, `render_tile` and `render_patch` (the WFC demo and its tests).
- The Conquest and Colonisation modes' art (`hexa/render.py`, `hexa/colony/`): the port is Age of Discovery only.

## The Kenney list

`docs/design/kenney-art-audit.md` is the full audit (owner, 2026-11-13: Kenney stays for now, no new uses,
replacement before Steam). The bake carries Kenney pixels into Godot in these places:

| Where in the bake | Kenney files | Plan to replace before Steam |
|---|---|---|
| `terrain/*` for plains, steppe, forest, hills, mountains, desert, jungle, tundra | 12 tiles: Grass 05, 12, 13, 14, 15, 19; Dirt 06, 19; Sand 07, 19; Stone 05, 12 | Our own ground and terrain tiles in the goodsart style (audit steps 1 to 3), drawn in Python and re-baked, or drawn for Godot by the redesign |
| `terrain/lake/0` | `Terrain/Grass/lake.png` (a flat blue hex; it may be a project addition, the repo history shows it added after the pack) | Decision 1: use the code-drawn sea tile |
| `terrain/marsh, taiga, snow, savanna, beach` | Pack base tiles and props (pines, rocks, logs) inside our code-built tiles | Draw the props with `nature.py` objects instead (already ours) |
| `native_village` | `Western/western_indians.png` | A code-drawn camp that varies by region (owner, 2026-11-13) |
| `deco/*` | Pack trees, rocks, houses, farmland, hay | `nature.py` trees and rocks and our own small houses |

The copies in `godot/assets/baked/kenney/` (with `License.txt`, CC0) are the tiles that are shown unchanged. They are
kept as the record of the source; Godot loads the atlases. When a piece is replaced, it is re-baked and its row
leaves this table.

## Decisions for the owner

1. **The lake.** Today a lake at the tile zoom is a flat, saturated blue hex. It clashes with the drawn sea next to it.
   - A: bake it as it is (today's look).
   - B: show lakes with the code-drawn sea tile (already in the atlas; nothing new to draw).
   - **Recommendation: B.** It is one line in the Godot layer rules and removes a Kenney file.
2. **Landmarks in 0.3.0.** They are baked (60 sprites), but today they only show on the close-up landscape, and they
   are first on the cut list.
   - A: show them at the 0.3.0 map zoom in place of the town piece for those ten cities.
   - B: leave them out of 0.3.0 and let the town redesign decide.
   - **Recommendation: B,** since the redesign replaces towns anyway.
3. **Where the bake lives.** The plan's layout says `godot/assets/atlases/`; this brief said `godot/assets/baked/`. The
   tool takes `--out`.
   - **Recommendation: keep `baked/`** and correct the plan's layout line when the paperwork item (8) is done.
