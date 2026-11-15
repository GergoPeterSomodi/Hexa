# M1 build spec: the map on the standard

Technical director, 2026-11-15. Builds milestone M1 of `docs/architecture/godot-architecture.md` (the standard). Where
this page is more exact than the standard, this page wins for M1; section 1 lists every place where it refines it.
The look of the tile map is shown in `docs/design/map/m1_trial/` (side by side with today's map) and waits for the
owner's sign-off. **Nothing in sections 3 to 9 is built before that sign-off**, except task T0.

**M1 is done when:**

1. the owner has signed the side-by-side of today's look and the tile look;
2. a frame takes under 16 ms at every zoom on a made-up map of 494 x 247 = 122,018 hexes (section 9);
3. the build rules read `MapData` and `MapState`, not the art bake's `meta.json`;
4. select, build, upgrade and clear work on the tile map through `Session.act`, and the old scene
   (`shell/worldmap/`) and the whole-map bake (`assets/worldmap/north_italy/`) are deleted.

---

## 1. What the trial settled, and where this page refines the standard

The trial code is in the repository and is the starting point, not throw-away: `tools/worldmap/tileset_bake/`
(Python), `godot/core/views/map_tiles.gd` and `edge_lines.gd`, `godot/shell/mapview/`, `godot/tools/mapview/`.

**Checked on the real engine (Godot 4.7.2):**

| Question of the standard (section 11) | Answer | Proof |
|---|---|---|
| Does a hexagon TileSet, stacked, offset axis horizontal, shift odd rows right as our grid does? | **Yes.** Cell (c, r) is hex (c, r): same centres, same hex under a point, same six neighbours | `godot/tests/shell/test_tile_grid.gd` (GUT, every pull request) |
| Are tall tiles on several layers in one y-sorted group drawn in depth order? | **Yes.** Depth is the cell's y plus the tile's `y_sort_origin`, whatever the layers' order in the tree; rows never swap while sort points stay within half a row (38 px) | `godot/tools/mapview/probe_ysort.gd` (windowed, four cases, all pass) |

**Refinements of the standard (decided here):**

| Standard, section 3 | M1 | Why |
|---|---|---|
| Sea and coast are layer 1, under the ground | The sea lies **over** ground and relief shade; the coast lies over the sea | Ground tiles spill softly over their hex edge. With the sea on top, no land colour spills into the water, and a coast tile only has to draw the shore |
| A shade tile per slope direction and steepness, about 20 | A shade tile per **strength** (10 levels) and a light tile (6 levels); each is a smooth bump whose neighbours add up to one | The per-hex shade becomes a smooth field with 16 tiles and no seams. Light needs its own layer because a multiply can only darken |
| One decor tile per hex (cover x density) | **Trees by wedge:** six tree layers, one per sixth of the hex. Hills and ridges stay one tile per hex | A river runs on an edge and a road crosses one; with wedges the wood makes way on that side only, the forest edge stops following the hex outline, and a built hex keeps a ring. 324 small tiles instead of thousands of combinations |
| Coast: 63 shapes | 63 shapes x **6 lattice positions** x 2 styles (beach, cliff), plus a bay form for carved ports | The wobble is a field that repeats every 3 cells and 2 rows, so neighbouring coast tiles join without knowing each other, and a straight coast does not repeat every hex |
| Rivers and roads: one drawn node per chunk, `_draw()` | One node per chunk that draws **one mesh** built when the chunk's lines change | Measured: canvas draw commands are re-sent every frame (18 ms for a small map); a mesh costs nothing while it stands (section 9) |
| A sea hex shows its depth | A sea hex beside land always shows the shelf tile | Only the shelf tile has a hard edge; deeper water spills softly, and must not spill onto a shore |
| Session and Events arrive "with the milestone that needs them" | Both arrive in M1, small (section 8) | The map view must hear "this hex changed" and the panel needs one door; building them later would mean rewiring M1's view |

---

## 2. The grid (fixed, pinned by a test)

- Cell `104 x 102` px. Hexagon, layout *stacked*, offset axis *horizontal*. Row pitch 76.5 px. Odd rows are half a
  cell to the right. The middle of cell (c, r) is `(104 (c + 0.5 + 0.5 (r & 1)), 51 + 76.5 r)`.
- The art is drawn at hex radius 60 px with the tilt 0.85 (103.92 x 102): the cell is 0.08 % wider. No art changes.
- Directions everywhere: 0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE (`core/hexgrid.gd`).
- `MapTiles.cell_centre(hex)` in `core/views` is the same formula for code without nodes; the grid test pins it to
  `TileMapLayer.map_to_local` and to `HexGrid`.
- **Lattice variant** of a cell: `posmod(c, 3) + 3 (r & 1)`, 0 to 5. Fields that must join across tiles repeat with
  period 312 px across and 153 px down.

---

## 3. The tileset bake (Python, `tools/worldmap/tileset_bake/`)

**Rule: the bake never reads a map.** It takes the art code (the kit, the families, the style frame's drawing) and
writes tiles that work on any map.

### 3.1 Files

```
godot/assets/tiles/<set>/            <set> = spring | summer | autumn | winter_snow | winter_frost | winter_mild
    index.json                       the one index (3.2)
    ground.png  shade.png  coast.png  trees.png  relief.png  pieces_<n>.png  marks.png
godot/assets/tiles/tiles_<season>.tres     built by godot/tools/build_tileset.gd from the indexes (3.4)
```

All six sets have **the same tiles at the same places** (same names, same atlas columns and rows). A test compares
the indexes. `shade.png` and `marks.png` are the same picture in every set and are written once and shared.

### 3.2 `index.json`

```json
{"version": 1, "cell": [104, 102], "set": "summer",
 "sources": [
   {"name": "ground", "file": "ground.png", "region": [172, 170], "separation": 2, "size": [w, h],
    "tiles": [{"name": "ground/farmland/0/0", "at": [0, 0], "anchor": [86, 85], "y_sort": 0, "z": 1}]}]}
```

- One source = one `TileSetAtlasSource`: all its tiles have the picture size `region`, laid on a grid with
  `separation` px between them. Sources are listed in a fixed order (ground, shade, coast, trees, relief, pieces_0...,
  marks); a source's id in the TileSet is its place in the list.
- `anchor`: the pixel of the picture that sits on the middle of the cell (the builder turns it into
  `texture_origin = anchor - region / 2`). `y_sort`: px below the middle of the cell where the tile's foot is
  (`y_sort_origin`). `z`: the tile's rank inside a blended layer (`z_index`).
- Pictures are PNG with straight alpha, at most 4096 px a side. Pieces are spread over as many `pieces_<n>` sources as
  needed, grouped by picture size (three sizes: 120, 152 and 184 px square) so little is wasted.

### 3.3 Tile names (the contract between the bake and `core/views/map_tiles.gd`)

| Name | Values | Count a set | Picture | Notes |
|---|---|---|---|---|
| `ground/<cover>/<band>/<v>` | cover: farmland grassland woods marsh rock snow tundra sand; band 0-4 for the four green covers (paler with height; 4 = half stone), 0 otherwise; v 0-2 | 72 | 172 x 170 | Opaque in the hex, fades out over 34 px beyond it. `z` = the cover's rank: sand 0, farmland 1, grassland 2, marsh 3, tundra 4, woods 5, rock 6, snow 7 |
| `sea/<depth>/<v>` | shelf, sea, deep; v 0-2 (v = number of wave marks) | 9 | in `ground` | shelf: hard edge 2 px beyond the hex. sea, deep: soft like ground. `z` 0, 1, 2 |
| `shade/<n>`, `light/<n>` | n 1-10, n 1-6 | 16 | 252 x 216 | `shade`: white picture, the ground is multiplied by `c ^ weight`. `light`: warm colour, alpha = strength x weight, added. The weights of all hexes add up to 1 at every pixel |
| `coast/<style>/<mask>/<lv>[/bay]` | style beach, cliff; mask 1-63 (bit d = neighbour d is sea); lv 0-5; bay only for masks with bits 4 and 5 | 756 + 96 | 172 x 170 | Section 3.5 |
| `trees/<kind>/<option>/<d>/<v>` | kind broad, mixed, conifer; option full thin bank road bankroad outer outerroad fringe sparse; d 0-5; v 0-1 | 324 | 76 x 84 | One wedge. Shadows baked under the trees. `y_sort` -30 (d 1, 2), 0 (d 0, 3), +30 (d 4, 5) |
| `relief/<kind>/<form>/<v>` | kind hills_low hills_high ridge_green ridge_rock ridge_snow; form full, pass, back; v 0-2 | 45 | 236 x 150 | Wider than the hex. `y_sort` +20 (full, pass), -14 (back) |
| `piece/<family>/<level>/<variant>/<mirror>/<extra>/<part>` | the families and levels of `tools/worldmap/pieces/families.py`; extra: `-`, an animal, an ore, a landmark, or the sea side (E SE S SW W NW N NE, or `carved`) for harbour, salt and harbour_addon; part ground, shadow, back, front | about 2,800 | 120 / 152 / 184 square | back: things whose foot is above the middle of the hex, `y_sort` -12; front: the rest, +12. harbour_addon has no back: all its things are `front`, `y_sort` +34 or -34 by sea side, and its picture is shifted so its shore lies on the hex's own (`piece_tiles.addon_shift`) |
| `mark/grid`, `mark/select`, `mark/target`, `mark/white` | | 4 | 172 x 170 | The hex grid line, the selection ring, a build target, and a white hex for tinting (M2) |

Rules for every picture: light from the upper left; nothing that must join a neighbour is drawn by chance (use the
lattice fields of `lattice.py`); a tile's variants differ in detail, never in outline.

### 3.4 The TileSet builder (`godot/tools/build_tileset.gd`, headless)

Reads the six indexes and writes four TileSets, `tiles_spring.tres` ... `tiles_winter.tres`. Each TileSet has **three
climate slots**: for source `s` of the index, the TileSet has sources `3 s + 0` (snow), `3 s + 1` (frost), `3 s + 2`
(mild). In spring, summer and autumn the three slots point at the same texture; in winter at the three winter sets.
A cell always uses the slot of its hex's climate, so **a season change is `layer.tile_set = other` and touches no
cell**. `TilesetBuilder` (`shell/mapview/tileset_builder.gd`, exists) keeps the name table: name ->
`Vector3i(source in the index, column, row)`; the view adds the climate.

The `.tres` files are committed. CI runs the builder and fails when its output differs (as for the map).

### 3.5 Coast tiles (the part that needs care)

`coast_tiles.py` (exists) is the reference. In short: land = this hex and its land neighbours, sea = its sea
neighbours; the shore is where a pixel is as near to one as to the other, bent by the lattice wobble (about 7 px) and
averaged over a ring of 12 px (this rounds the hex corners). A pixel is painted only by the tile whose own hex is the
nearest land. The tile paints: sea where the shore cut into its hex; sand or stone where the shore pushed out; a strip
of sand (5 px) or wet rock (3 px); foam (2.6 px); a light band fading over 20 px; and for `cliff` a rock face up to 11
px tall under land seen from the front. `bay`: a rectangle of water 72 px wide whose back is 20 px south of the
middle of the hex.

No band may be wider than 25 px: a tile does not know the hexes two steps away.

### 3.6 Size

Measured in the trial (summer, 614 tiles): 3.1 MB of PNG. Estimated for a full set: about 40 megapixels (coast 25,
pieces about 12, the rest 5), 15 to 25 MB of PNG, **160 MB on the graphics card uncompressed**. One season is loaded
at a time (winter: three piece and ground sets, about 300 MB). The budget: 512 MB of video memory for the map. T12
measures it; if it is over, the first cuts are 4 lattice positions instead of 6 (coast minus a third) and lossless
packing of the coast tiles to their own box.

---

## 4. `MapData`: the fixed map (`core/defs/map_data.gd`, a Resource)

One file per map in `godot/data/maps/<id>.tres` (north Italy: 21 x 19 hexes; text). Larger maps use `.res`.
Built by `godot/tools/build_map.gd` from the geography and heights through `core/mapgen`; committed; CI rebuilds it
and compares `digest()`.

```gdscript
class_name MapData extends Resource
@export var id: String                       # "north_italy"
@export var cols: int
@export var rows: int
@export var hex_w_km: float                  # 28.0
@export var lon_west: float; lat_north: float; ref_lat: float; deg_km: float     # for HexGrid
# per hex, index = row * cols + col
@export var land: PackedByteArray            # 1 land, 0 sea
@export var height_m: PackedInt32Array       # land: metres; sea: 0
@export var relief: PackedByteArray          # ReliefLevels 0 (sea) to 6
@export var cover: PackedByteArray           # 0 farmland ... 7 sand (the order of the tile names); 255 at sea
@export var depth: PackedByteArray           # sea: 0 shelf, 1 sea, 2 deep; land: 0
@export var climate: PackedByteArray         # 0 snow, 1 frost, 2 mild (the kit's winter_of)
@export var fertility: PackedByteArray       # 0 until M4
@export var ore: PackedByteArray             # 0 until M4
@export var pass_id: PackedInt32Array        # index into passes, -1 none
@export var place_id: PackedInt32Array       # index into places, -1 none
# per edge, index = 3 * hex index + k, k = 0 E, 1 NE, 2 NW (each hex owns three of its six edges)
@export var river: PackedByteArray           # 0 none, 1 to 3 the river's class, 4 a stream
@export var crest: PackedByteArray           # 1 a crest runs along the edge
@export var pass_edge: PackedByteArray       # 1 a pass crosses the edge
@export var road: PackedByteArray            # the STARTING road: 0 none, 1 track, 2 road, 3 highway
@export var crossing: PackedByteArray        # 0 none, 1 ford, 2 bridge_wood, 3 bridge_stone, 4 ferry, 5 pass
# lists
@export var places: Array[Dictionary]        # {name, hex, level, port, port_mode ("", "seaside", "carved"), capital, landmark}
@export var passes: Array[Dictionary]        # {name, hex, metres}
@export var rivers: Array[Dictionary]        # {name, class, corners: PackedVector2Array of hex corners in km}: the drawn course

func index_of(hex: Vector2i) -> int          # -1 off the map
func hex_of(index: int) -> Vector2i
func has(hex: Vector2i) -> bool
func is_land(hex: Vector2i) -> bool          # false off the map
func neighbour(hex: Vector2i, direction: int) -> Vector2i
func edge_index(hex: Vector2i, direction: int) -> int      # the same index from both sides; -1 off the map
func river_on(hex: Vector2i, direction: int) -> int
func road_on(hex: Vector2i, direction: int) -> int
func coast_mask(hex: Vector2i) -> int        # bit d: neighbour d is sea (off the map counts as land)
func grid() -> HexGrid
func validate() -> Array[String]             # sizes match; every river reaches the sea or a river; every road a place
func digest() -> String                      # sha256 of every field in a fixed order
```

`coast` (does the hex touch the sea) and the sea side are **derived** (`coast_mask`, `MapTiles.sea_side`), never
stored. Read-only in play. `road` and `crossing` are the starting network; from M3 the living ones are in `MapState`.

### `MapState` (`core/state/map_state.gd`, RefCounted): what changes

```gdscript
var main_use: PackedByteArray        # ImproveRules family id, 0 = wild
var level: PackedByteArray
func to_dict() -> Dictionary; static func from_dict(d: Dictionary, map: MapData) -> MapState
```

M1 has only these two. `OWNS` of the improvement system lists both.

---

## 5. The layer stack (`shell/mapview/tile_map_view.gd`, exists)

All layers share the season's TileSet. z values are fixed so that a tile's own `z` (0 to 7) never reaches the next layer.

| z | Layer | Kind | Cell holds | Filled by (`core/views/map_cells.gd`) |
|---|---|---|---|---|
| 0 | `ground` | plain | `ground/...` | cover, height |
| 10 | `shade` | multiply | `shade/<n>` | `MapTiles.slope_tone` of the heights |
| 11 | `light` | add | `light/<n>` | the same |
| 20 | `sea` | plain | `sea/...` | depth; shelf beside land |
| 30 | `coast` | plain | `coast/...` | coast mask, relief (cliff from level 3), port, carved |
| 40 | `piece_ground` | plain | `piece/.../ground` | main use, level |
| 41 | `addon_ground` | plain | harbour add-on ground | port and coast |
| 45 | `grid` | plain | `mark/grid` | every hex; hidden by option |
| 50 | lines | one mesh node per chunk of 32 x 32 cells | | section 6 |
| 60 | shadow group (`CanvasGroup`, alpha 0.18): `piece_shadow`, `addon_shadow` | plain, drawn solid | `.../shadow` | so overlapping shadows are no darker than one |
| 70 | standing group (`y_sort_enabled`): `relief`, `trees0` ... `trees5`, `piece_back`, `piece_front`, `addon` (each `y_sort_enabled`); later the army tokens | y-sorted | | depth = cell y + tile `y_sort` |
| 80 | `tint` (M2), `fog` (later) | plain, modulated | `mark/white` | owner |
| 90 | `marks` | plain | `mark/select`, `mark/target` | selection, build targets |
| 100 | names | `Label`s for what is on screen | | places |

Depth inside one hex, back to front: tree wedges 1 and 2 (-30); a `back` ridge (-14); piece back band (-12); tree
wedges 0 and 3 (0); piece front band (+12); a `full` ridge (+20); tree wedges 4 and 5 (+30); a harbour on the south
side (+34). All within 38 px, so a row is always behind the row below it.

**The view holds no facts.** Its whole interface:

```gdscript
func setup(tiles: TilesetBuilder) -> void
func set_tile(layer_name: String, cell: Vector2i, tile_name: String) -> void      # "" clears
func set_cells(cells: Dictionary) -> void       # {layer: {cell: name}} from core/views/map_cells.gd
func set_chunk_lines(chunk: Vector2i, lines: Array[Dictionary]) -> void
func set_season(tiles: TilesetBuilder) -> void  # swaps the TileSet of every layer
func hex_at(map_px: Vector2) -> Vector2i
func centre_of(hex: Vector2i) -> Vector2
func missing_names() -> Array[String]           # asked for, not in the tileset: a test demands it is empty
```

### `core/views/map_cells.gd` (new; today this is inside the trial scene `tile_trial.gd`)

```gdscript
class_name MapCells extends RefCounted
static func of_hex(map: MapData, state: MapState, hex: Vector2i) -> Dictionary     # {layer name: tile name}
static func touched_by(map: MapData, hex: Vector2i) -> Array[Vector2i]             # the hex and its six neighbours
```

`of_hex` calls the rules of `MapTiles` (exists, tested) and is the only place that decides a tile. When the game
says `hex_changed(hex)`, the map scene calls `of_hex` for `touched_by(hex)` and `set_tile` for what differs: about
100 `set_cell` calls, and Godot redraws only the quadrants touched.

Filling a whole map is sliced: 4,000 hexes a frame (about 8 ms), nearest the camera first, so a 122,000-hex map
appears at once where you look and is complete within a second.

---

## 6. Rivers, roads and tracks (`core/views/edge_lines.gd` exists; chunking is new)

```gdscript
static func chunk_of(hex: Vector2i) -> Vector2i                                   # 32 x 32 cells
static func for_chunk(map: MapData, state: MapState, chunk: Vector2i) -> Array[Dictionary]
# a line: {kind: "river" | "stream" | "road" | "track", points: PackedVector2Array (map px), width: float, rank: int}
```

- A **river** is drawn from `MapData.rivers[n].corners` (the edge course): corner-cut three times, a point every 4.4
  px, a slow meander of 2.4 px that depends only on the river's index. Width by class 3.4, 4.6, 6.5 px with a 2 px
  dark edge and a dashed light on the upper-left bank. A **stream** is one edge, bowed.
- A **road** is built from the road edges: steps of one quality are joined into runs between junctions, drawn through
  the middles of the hexes, corner-cut, with a wander of 2.2 px. Quality 2 and 3 are roads (2.5, 3.4 px, dark edge);
  quality 1 is a **track** (1.3 px, no edge) and trees do not make way for it.
- A line is cut where it leaves a chunk (pieces overlap by one point). `EdgeLineLayer` (exists) builds one mesh per
  chunk; a new road rebuilds one chunk's mesh.
- Bridges, fords and pass marks are tiles on a `crossing` layer in the standing group (`mark/bridge_wood/<d>` ...);
  they are **not in M1's first cut** (T13, after the sign-off of the base).

---

## 7. The far zoom (`core/views/far_picture.gd`, `shell/mapview/far_map.gd`)

Below zoom **0.20** the tile layers and lines are hidden and one sprite is shown. (Measured: the tile stack itself
stays fast when zoomed out, so the far picture is for legibility and for M2's country colours, not for speed.)

```gdscript
class_name FarPicture extends RefCounted
const PX := Vector2i(4, 3)                      # picture px a hex; odd rows are shifted 2 px
static func size_of(map: MapData) -> Vector2i   # (4 cols + 2, 3 rows + 1)
static func pixels(map: MapData, state: MapState) -> PackedByteArray      # RGBA8, row by row
static func colour_of(map: MapData, state: MapState, hex: Vector2i) -> Color
```

Colour: the ground tile's base colour for the cover and band, times the slope tone; sea by depth; a built hex a
little warmer (a town: a roof-red dot). Europe is 1,978 x 742 px, one texture, one draw. The sprite is scaled so a hex
covers its cell (26 x 25.5) and filtered linearly. Between zoom 0.20 and 0.25 the two cross-fade. A `hex_changed`
rewrites that hex's 12 pixels and updates the texture.

---

## 8. Select, build, upgrade, clear: the minimal game core

M1 brings the smallest form of the standard's sections 4.3, 4.4 and 5.1. No seasons, no saves, no costs.

```gdscript
# core/game/game.gd
class_name Game extends RefCounted
var map: MapData
var state: MapState
var seed_value: int
var events: Array[Dictionary] = []           # appended by the rules, drained by Session
static func new_game(map: MapData, seed_value: int) -> Game       # runs the improvement search (the WFC)
func act(action: String, args: Dictionary) -> Dictionary          # {ok: bool, reason: String}
func check(action: String, args: Dictionary) -> Dictionary
func digest() -> String

# core/game/actions.gd: the one table
const TABLE := {"build": [Improve.build_check, Improve.build], "upgrade": [...], "clear": [...]}
# args: build {hex: Vector2i, family: int}; upgrade {hex}; clear {hex}

# core/systems/improve.gd (replaces world_improve.gd's public face; the solver and the rules files stay)
const OWNS := ["main_use", "level"]
static func build_check(game: Game, args: Dictionary) -> Dictionary
static func build(game: Game, args: Dictionary) -> Dictionary     # checks again, writes state, appends {kind: "hex_changed", hex}
static func build_options(game: Game, hex: Vector2i) -> Array[Dictionary]     # {family, ok, reason}
static func piece_at(game: Game, hex: Vector2i) -> Dictionary                 # family, level, variant, mirror, extra, addon

# shell/autoload/session.gd (autoload "Session")      # shell/autoload/events.gd (autoload "Events")
var game: Game                                         signal hex_changed(hex: Vector2i)
func new_game(map_id: String, seed_value: int) -> void signal game_started()
func act(action: String, args: Dictionary) -> Dictionary     # calls game.act, then emits one signal per queued event
func check(action: String, args: Dictionary) -> Dictionary
```

**The rules read `MapData`:** `ImproveRules.cell_allowed` and the solver take their facts from a small adapter
`Improve.facts_of(map, hex)` that returns the same keys as today's `meta.json` row (cover, height_m, coast,
climate, river, road, pass, place, port, port_mode). `coast` is `coast_mask != 0`; the sea side is
`MapTiles.sea_side(mask)`; `road` is "a road of quality 2 or 3 leaves this hex" from `MapData.road`.
**This changes the result for a seed** (today the road flag and the shore come from the style frame's hand-drawn
picture). It is the one behaviour change of M1; the pull request says so, records the new counts per family, and
stores the new golden.

**Input and panel:** `shell/input/map_input.gd` turns the mouse into intents (`select(hex)`, `clear_selection()`,
pan, zoom). `shell/panels/hex_panel.tscn` shows the selected hex and its buttons from `Session.check` /
`Improve.build_options`; a button calls `Session.act`. The map scene `shell/map/map_scene.tscn` owns the camera,
the `TileMapView`, the far map, and listens to `Events.hex_changed`. Keys as today (1-4 season, G grid, F whole
map, U upgrade, Esc); R (new seed) calls `Session.new_game`. The V switch (villages off) is dropped.

---

## 9. Speed: the made-up Europe and the budget

`core/mapgen/fake_map.gd`: `static func build(cols: int, rows: int, seed_value: int) -> MapData`: noise heights,
land above a level, cover in patches, a place on one land hex in forty, a river down every valley it finds, roads
between near places. It only has to be Europe-shaped in numbers: about 60 % land, 15 % woods, rivers on 5 % of edges.

`godot/tools/perf_map.gd` (windowed, sync off, 1920 x 1080; grows out of `tools/mapview/probe_fake_europe.gd`):
builds the fake 494 x 247 map, starts a game, and prints and writes JSON for: fill time; frame time (mean and worst
of 240 frames while panning) at zooms 2, 1, 0.5, 0.25 and in the far picture; draw calls; the time of one `build`
action to the next frame; a season swap; static memory and video memory.

| Budget | Limit | First reading in the trial (made-up map, trial tileset, 1920 x 1080; `docs/design/map/m1_trial/notes.md`) |
|---|---|---|
| Frame, every zoom, panning | 16 ms worst, 8 ms mean | zoom 2: 2.3 ms (worst 3.7); zoom 1: 2.6 (3.8); 0.5: 3.3 (5.1); 0.25: 4.7 (6.3); 0.12: 8.6 (11.7) |
| Fill of the whole map | first screen in 100 ms, all in 3 s | 2.7 s in one go for 474,550 cells (not sliced yet) |
| One build action to the screen | 2 ms | not measured yet |
| Season swap | 100 ms | not measured yet |
| Memory of the cells | 400 MB | 269 MB (about 570 bytes a cell: the standard's "a few bytes" was wrong) |

Never assert on time in GUT. `perf_map.gd` runs nightly and before a release and fails past the limit (as
`tools/perf.py` did for the Python game). **Two lessons already paid for:** (1) anything drawn with canvas commands in
`_draw()` over the whole map is re-sent every frame: use tiles or a mesh; (2) a `TileMapLayer` with nothing on
screen costs nothing, so more layers are cheap.

---

## 10. Tests (all in GUT unless said)

| Test | Proves |
|---|---|
| `tests/shell/test_tile_grid.gd` (exists) | Godot's hex layout is our grid |
| `tests/core/test_map_tiles.gd` (exists) | Tile-name rules, river and road lines |
| `tests/core/test_map_data.gd` | Index and edge index from both sides; `validate()`; digest stable; north Italy file loads and validates |
| `tests/core/test_map_build.gd` | `build_map` gives the committed file's digest (CI: the map rebuild check) |
| `tests/core/test_improve_actions.gd` | check and action agree for 2,000 random actions (when the check says no, nothing changes; when yes, it succeeds); every action queues exactly one `hex_changed`; same seed and actions, same `Game.digest()`; `OWNS` |
| `tests/core/test_map_cells.gd` | `of_hex` names only tiles that exist in `assets/tiles/summer/index.json`, for every hex of north Italy and of a 60 x 40 fake map, wild and after 500 random builds (**no missing tile**) |
| `tests/core/test_far_picture.gd` | Size; a sea hex is blue, a wood green; one hex changes 12 pixels |
| `tests/shell/test_tileset.gd` | The six indexes have the same names at the same places; the `.tres` has 3 slots a source; every tile's origin and sort point equal the index |
| `tests/shell/test_map_scene.gd` | The scene opens; a click selects; the panel's Build button changes the state and exactly the cells of `touched_by`; season swap touches no cell |
| `tests/shell/test_layer_stack.gd` | z order and sort points of section 5 (reads the nodes) |
| Python `tests/test_tileset_bake.py` (unittest, no map files) | Names and counts of section 3.3; coast tiles of neighbouring hexes agree on the pixels they share (two masks that describe one shore, compared on the overlap); a tile bake without `STYLE_FRAME_LAYERS` works |
| Goldens `godot/tests/goldens/map_*.png` (windowed job) | North Italy at zoom 1 and 2, summer and winter, and the far picture: within 0.5 % of the stored pictures |
| `tools/mapview/probe_ysort.gd` (windowed job) | The engine still sorts across layers (run on every engine upgrade) |

---

## 11. Tasks

Sonnet-sized unless marked. A task owns its files: **no two tasks of one group touch the same file.** "Done when"
always includes lint, check_scripts and GUT green.

**Group 0 (before the sign-off; nothing else starts)**

| # | Task | Files | Done when |
|---|---|---|---|
| T0 | Art director reviews the trial against the style frame and lists fixes by tile kind (section 12); owner signs | `docs/design/map/m1_trial/` | A signed note in `notes.md`: go, or the list of fixes |

**Group A (parallel; no dependencies between them)**

| # | Task | Files (new unless said) | Interfaces | Done when |
|---|---|---|---|---|
| T1 | `MapData`, `MapState` | `core/defs/map_data.gd`, `core/state/map_state.gd`, `tests/core/test_map_data.gd` | Section 4 | The test of section 10; edge index equal from both sides for every edge of a 7 x 5 map |
| T2 | Art drawing without a world | `tools/worldmap/tileset_bake/art.py` (the style frame's `draw_tree`, `draw_conifer`, `draw_hill`, `draw_range`, `snow`, `style` and the season palettes, moved out of `render.py` / `frame_bake.py` as functions of a surface); edit `decor_tiles.py` to use it | `art.Painter(season, climate)` | `bake_trial.py --only decor` runs with no layers file and gives byte-identical summer `trees.png` and `relief.png` |
| T3 | Edge lines by chunk | edit `core/views/edge_lines.gd`, `shell/mapview/edge_line_layer.gd`; `tests/core/test_edge_lines.gd` (move the line tests out of `test_map_tiles.gd`) | Section 6, with a plain `Array` of edge facts as input until T1 lands (`for_chunk` is wired in T7) | A line cut at chunk borders draws without a gap (golden of a 2 x 2 chunk fixture); one mesh a chunk |
| T4 | Far picture | `core/views/far_picture.gd`, `tests/core/test_far_picture.gd` | Section 7 (takes plain arrays until T1 lands) | The test of section 10 |
| T5 (Haiku) | Marks | edit `tools/worldmap/tileset_bake/flat_tiles.py` (grid line moves to `marks`; add select, target, white) | Section 3.3 | Four tiles in `marks.png`; the trial still draws its grid |

**Group B (after T1; parallel)**

| # | Task | Files | Done when |
|---|---|---|---|
| T6 | Map builder | `godot/tools/build_map.gd`, `godot/data/maps/north_italy.tres`, `core/mapgen/climate.gd` (the kit's `winter_of` ported), `tests/core/test_map_build.gd` | The file validates; rebuilt twice gives one digest; its cover, relief, rivers and road edges equal what `core/mapgen` gives today (compared in the test) |
| T7 | `MapCells` and chunk lines from `MapData` | `core/views/map_cells.gd`, edit `core/views/map_tiles.gd` (cover and depth by number), edit `core/views/edge_lines.gd` (`for_chunk`), `tests/core/test_map_cells.gd` | `of_hex` on the north Italy fixture gives the same names as the trial scene gives today for the same facts (a list written by `dump_trial_tiles.gd` is the fixture) |
| T8 | Fake map | `core/mapgen/fake_map.gd`, `tests/core/test_fake_map.gd` | 494 x 247 built in under 5 s; validates; shares of land, woods and rivers inside the ranges of section 9; same seed, same digest |
| T9 | Full tile bake | `tools/worldmap/tileset_bake/bake.py` (all six sets, all 63 masks, all pieces from `pieces_bake.render`, parallel), edit `coast_tiles.py`, `piece_tiles.py`, `flat_tiles.py`, `tile_atlas.py` (three piece sizes); `tests/test_tileset_bake.py`; `godot/assets/tiles/<set>/` | Section 3; the bake needs no map file; under 15 minutes on 8 cores; sizes reported against 3.6 |

**Group C (after A and B; parallel)**

| # | Task | Files | Done when |
|---|---|---|---|
| T10 | TileSet builder with climate slots, season swap | `godot/tools/build_tileset.gd`, edit `shell/mapview/tileset_builder.gd`, `shell/mapview/tile_map_view.gd` (`set_cells`, `set_chunk_lines`, `set_season`, sliced fill), `godot/assets/tiles/tiles_*.tres`, `tests/shell/test_tileset.gd`, `tests/shell/test_layer_stack.gd` | Section 3.4 and 5; a season swap touches no cell (test counts `set_cell` calls) |
| T11 | Game core and the improvement on `MapData` | `core/game/game.gd`, `core/game/actions.gd`, `core/systems/improve.gd`; edit `core/systems/world_improve.gd` (facts from `Improve.facts_of`), `improve_rules.gd`, `improve_solver.gd` only where they read a row; `tests/core/test_improve_actions.gd`; port `tests/core/test_world_improve.gd` to `MapData` fixtures | Section 8; the property tests of section 10; the new per-family counts for seed 1480 are written in the pull request |
| T12 | Speed tool | `godot/tools/perf_map.gd`, `godot/tests/perf_budget.json`, a nightly job in `.github/workflows/godot.yml` | Prints the table of section 9 for the fake map with the full tileset; fails past a limit |

**Group D (after C; one after another: they share the scene)**

| # | Task | Files | Done when |
|---|---|---|---|
| T13 | The map scene | `shell/autoload/session.gd`, `shell/autoload/events.gd`, `project.godot` (autoloads, main scene), `shell/map/map_scene.tscn` + `.gd`, `shell/input/map_input.gd`, `shell/mapview/far_map.gd`, `tests/shell/test_map_scene.gd` | Section 8: north Italy opens on tiles; select, build, upgrade, clear through `Session.act`; far zoom; seasons; budgets of section 9 met on the fake map |
| T14 (Haiku, from T13's panel contract) | Hex panel | `shell/panels/hex_panel.tscn` + `.gd`, `shell/ui/` kit pieces it needs, `tests/shell/test_hex_panel.gd` | Today's panel content, built from containers and the Theme; refused buttons show the reason |
| T15 | Crossings and names | edit `piece_tiles.py` or new `mark_tiles.py` (bridges, fords, pass marks), `shell/mapview/map_labels.gd` (from `world_labels.gd`) | Bridges where a road crosses a river edge; place names for what is on screen |
| T16 | Retire the prototype | delete `shell/worldmap/`, `shell/mapview/trial/`, `tools/mapview/dump_trial_*.gd`, `shot_trial.gd`, `assets/worldmap/north_italy/`, `assets/tiles/trial/`, `tools/worldmap/godot_bake/` (keep `pieces_bake.py` if T9 imports it), `tileset_bake/bake_trial.py`, `trial_map.py`; update `godot/README.md`, `CLAUDE.md`, `tools/lint_godot.py` `SIZE_REASONS`, goldens | Nothing refers to the deleted files; goldens stored; all checks green; the owner plays the build |

Order of merges: A, then B, then C, then D. The code reviewer reads every task; the technical director reads T1,
T7, T10, T11 and T13.

---

## 12. What the art director checks

Against `docs/design/map/style-frame/` and the side-by-side, tile kind by tile kind, each with a go or a fix:

1. **Coast:** the wobble's size; the sand strip and foam; where a cliff starts; the bay of a carved port; a harbour
   add-on's place on a straight edge and on a corner. This is the look change the standard names.
2. **Ground:** the spill width (34 px) and the rank order of the covers; the height bands; marsh, tundra, sand (not
   on the trial's map).
3. **Relief shade and light:** strength against the style frame's slope tones.
4. **Trees:** density of `full` and `thin`; the mix of broadleaf and conifer by height; the bank and road clearings;
   the fringe into open ground; the ring round a built hex.
5. **Ridges and hills:** one ridge a hex reads as rows in a wide range (the Alps). The fix to try first: two more
   variants and a `tall` form for crest hexes, and letting a ridge follow its crest edge (a left and a right form).
6. **Pieces:** the cut into back and front band at the middle of the hex (a tower in the back band must not be
   overlapped by a house of the front band wrongly: check the 16 families' sheets).
7. **Lines:** river and road widths, the track, bridges (T15).
8. **Seasons:** spring and autumn are still stand-ins from the kit's palettes; winter by climate on tiles.
9. **Video memory versus quality** if T12 asks for compression: compare a compressed atlas at zoom 2.

---

## 13. Risks

- **The look is not signed yet.** Everything waits for T0.
- **Video memory** (3.6): the estimate is 160 MB a season. If compression is needed the art director must agree.
- **The improvement result changes** when its facts come from `MapData` (section 8). Expected, but it is a behaviour
  change inside M1 and gets its own pull request (T11), never mixed with the view.
- **Pure-Python pixel loops** make the full coast bake slow (about 5 s a tile, 850 tiles). T9 runs it in parallel
  and caches by tile name; if it is still too slow, numpy becomes a bake-only requirement.
- **Half-pixel rows** (76.5 px): at zoom 1 odd rows sit on half pixels. With linear filtering no seam showed in the
  trial; the goldens of T16 guard it.
- **One hex of knowledge:** a coast tile cannot know hexes two steps away. Bands wider than 25 px, or a wobble over
  10 px, would break the joins. The Python test of section 10 guards it.

## 14. Owner's decision (2026-11-15): build M1 on the trial look; polish the look later

The owner saw the round-1 side-by-side and decided not to spend more time on the look now: M1 is built on the trial
look as it is (good enough to play on), and the look gets its own **map look milestone** later (after a few game
systems, before the first public release): the real shoreline drawn as chunk meshes (Genoa's bay and the capes back),
ranges along crest chains, a ground shader blending covers by a splat texture with slope shading, trees one by one,
bridges and today's road style. **T0 is replaced by this decision** (no art-director sign-off gate in M1).

So that the later look work is a drawing job only, `MapData` (T1, T6) **also stores** the data it will need:

```gdscript
@export var shoreline: Array[PackedVector2Array]   # the real coast lines in km (the style frame's coast, carved
                                                   # ports included), closed or ending at the map edge
@export var height_grid: PackedInt32Array          # metres on a fine raster: HEIGHT_GRID_STEP samples per hex width
@export var height_grid_size: Vector2i             # raster width x height in samples
@export var height_grid_origin_km: Vector2         # km of sample (0, 0); sample spacing = hex_w_km / HEIGHT_GRID_STEP
const HEIGHT_GRID_STEP := 4
```

Crest chains are the `crest` edges (already stored); rivers keep their drawn course in `rivers`. `validate()` checks
the shoreline is consistent with `land` (a land hex's centre is inside the land side) and the raster covers the map;
`digest()` includes the new fields.
