# World map art (map prototype, step 6)

The art of the new world map, drawn in code and baked by `tools/worldmap/bake_map_art.py`
(`python -m tools.worldmap.bake_map_art`, from the repository root, with `SDL_VIDEODRIVER=dummy`). Do not edit these
files by hand: change the tool and bake again. The bake is reproducible: the same pygame build writes the same bytes.

The look is direction A (`docs/design/godot-look/README.md`): flat two-tone shading lit from the upper left, 1 to
2 px ink outlines. The trees, peaks, hills, rocks, reeds, the monastery and the lighthouse are the Python game's own
objects (`hexa/campaign/nature.py`, `life.py`), redrawn at this map's sizes. Everything else is new. No Kenney art.

## Files

| File | What |
|---|---|
| `index.json` | The contract: every piece, every texture and the rules below |
| `scatter_0.png` | Atlas: trees, mountains, hills, rocks, marsh, field parcels, the calm patch |
| `relief_0.png` | Atlas: crest chains, crest caps, pass saddles, cliffs, beach rims |
| `sites_0.png` | Atlas: towns 1 to 5, the capital's palace, castles 1 to 3, hospice, cairn, bridges, quays, boats, reused landmarks |
| `heraldry_0.png` | Atlas: Milan's arms, the blank arms frame, the pennant, the town plate, level dot, crown |
| `ground_<cover>.png` | The eight ground textures, 256 x 256, tileable |
| `noise_blend.png` | Tileable noise for the ground blend (R broad, G middle, B fine) |
| `strip_*.png` | Line textures that tile along x: border band, neutral border dash, foam, track |

Import the atlases and textures with filter linear and mipmaps on; set the ground textures, the noise and the strips
to repeat.

## Scale

Every piece is drawn for a **hex radius of 60 px** (`base_radius_px`), the closest zoom. A piece is drawn at
`scale = (r / 60) * band.scale_mul[family]`, where `r` is the hex radius on screen and the band is the first entry of
`rules.zoom.bands` with `r >= r_min`:

| Band | r | Pieces | Scatter grid |
|---|---|---|---|
| close | 40 and up | true size | as listed |
| middle | 18 to 40 | scatter x1.35, relief x1.15, sites x1.3 | trees x1.5 apart, mountains x1.25, no loose rocks |
| far | below 18 | scatter x1.8, sites x1.8 | trees x2.6 apart, mountains x1.7, no fields, marsh or rocks; plates only below r 10 |

Sizes at r 60: a level 5 city is about 104 x 68 px (the hex is 104 px wide), a level 3 town 60 x 43, a level 1
hamlet 32 x 20, a broadleaf tree 16 to 30 px wide, a high peak 50 to 70 px, a crest chain piece about 60 px along its
edge.

## index.json

```
format          "hexa-worldmap-art/1"
base_radius_px  60
pages           id -> {file, size, sha256, filter, mipmaps}
textures        name -> {file, size, sha256, tile, ...}       ground.<cover>, noise, strip.*
pieces          name -> {page, rect [x, y, w, h], anchor [x, y], layer, rotate, ...}
rules           zoom, ground, scatter, mountains, fields, sites, edges, border, lines
counts          pieces, textures, pages
```

**Piece names** are `<layer>.<family>.<key>.<variant>` (thread 5's naming): `scatter.broadleaf.oak.m.v2`,
`relief.crest.ne.snow.v1`, `coast.cliff.d4.v0`, `town.3.v1`, `castle.2.v0`, `road.bridge.stone.axis1`,
`port.quay.stone.d5`, `arms.milan.48`, `field.parcel.vines.v0`. The variant is picked by a hash of the position, so
it is stable between runs and saves.

**Anchor** is in pixels inside `rect`. It sits on:

| layer | Anchor | Notes |
|---|---|---|
| `upright` | the feet (bottom centre of the object) | y-sort by the anchor's screen y |
| `edge` | the midpoint of the edge the piece belongs to | crests, saddles, cliffs, quays; y-sort with the uprights |
| `corner` | the hex corner | crest caps |
| `flat`, `edge_flat` | the centre | ground decals (fields, pools, fords, beach rims); drawn under the uprights |
| `ui` | top centre (shields), pole foot (pennant) | heraldry and labels |

`rotate: true` marks flat pieces the renderer may rotate (field parcels, pools). **Lit pieces are never rotated or
mirrored** (D10): crests, cliffs, bridges, quays and towns come in one picture per orientation. Pieces with
`tint: true` are white for the renderer to tint (the arms frame, the pennant, the calm patch).

**Edges.** Directions are 0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE (`WorldGrid.neighbour`); corner k sits at -90 + 60k
degrees. An edge's orientation is `e` (directions 0 and 3, a vertical edge), `ne` (1 and 4) or `nw` (2 and 5); crest
and saddle pieces are chosen by orientation, cliffs, beach rims and quays by the direction from the land (or town) hex
to the other side, bridges by the axis of the road (0 for an E/W edge, 1 for NE/SW, 2 for NW/SE).
`rules.edges` spells each lookup out.

**Rules.** Besides the pieces, `rules` holds what the renderer needs to place them, in hex radii unless the name
says px:

- `zoom`: the bands above.
- `ground`: cover order (WorldCover's), texture repeat in world px, level tints, the blend (the owner's narrow v2
  band: 0.11 r each side of the edge, wobbled by the noise sampled in world space).
- `scatter`: the world grid (step, jitter, half-step offset on odd rows, the five hashes), per-cover density and
  species by level, the southern swap (Liguria, Tuscany), the snow line, and the calm rule (no scatter within 0.55 r
  of a site, 0.12 r of a river or road, 0.22 r of a crest). Everything runs on across hex edges.
- `mountains`: the kind from the interpolated height (high peaks, rocky ranges, low mountains with trees, hills).
- `fields`: farm levels, spread radius and density per level, parcel styles (plain, southern, hill).
- `sites`: where towns, the palace, castles, ports, hospices and cairns stand relative to the site point.
- `border`: style A (D6): band width and alpha, line width and colour, wash, the neutral dash for other countries,
  Milan's colour.
- `lines`: colours and widths for rivers, streams, lakes, sea bands, sand rim, foam and roads (drawn as geometry,
  not sprites).

## Not in this bake (next)

River-city pieces (9 + 3), farmsteads, mines and workshops by level, town gates by road, harbour sets, ferries'
landing stages and the other countries' arms. The arms of Milan are a sketch to be checked against a heraldry source.
