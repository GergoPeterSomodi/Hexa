# Godot bake: the north Italy normal map

Exports the Python prototype's art (style frame + pieces + the compositor `pieces_in_map/compose.py`) into files Godot loads.
The heights under the base are NOAA ETOPO 2022 (60 arc-second, ice surface), through `tools/worldmap/extract_heights.py`.

    python tools/worldmap/godot_bake/bake.py --layers <layers.json>      # or STYLE_FRAME_LAYERS=...; about 40 s
    python tools/worldmap/godot_bake/reassemble.py [--season winter] [--union-shadows]   # sanity picture from the baked files only
    STYLE_FRAME_LAYERS=... python tools/worldmap/godot_bake/grid_check.py                # Godot grid vs prototype grid

Options of bake.py: `--out DIR` (default `godot/assets/worldmap/north_italy`), `--stages frame,pieces`, `--jobs N`,
`--no-landmarks`. Needs pygame only. No `.import`
files are written. Nothing of the style frame, the pieces or compose.py is changed; their steps (carve_ports, move_sites, winter
by climate) are called.

## Frame and km (checked)
Image px (0,0) is km `origin_km` = (70, 214). `px = ((kx - ox) * px_per_km, (ky - oy) * px_per_km * tilt)`, px_per_km =
60 / (28 / sqrt 3) = 3.7115, tilt 0.85, hex radius 60 px, image 1280 x 720 (345 x 228 km).
**The grid matches `core/worldmap/world_grid.gd`**: same `centre_km`, `hex_of_km`, neighbour tables (0 E, 1 NE, 2 NW, 3 W, 4 SW,
5 SE), corners and lon/lat to km. `grid_check.py` ports the GDScript (no Godot on the build machine) and compares all 390 hexes,
20000 points and 2000 lon/lat points: every difference is 0. `centre_px` in meta is the centre rounded to whole pixels (as
compose.py does; within 0.5 px of the formula). No transform is needed.

## Files
| File | What |
|---|---|
| `meta.json` | version, radius_px, tilt, px_per_km, origin_km, size_px, seasons, `hexes` (148: every region hex that overlaps the image) |
| `base_<season>.png` | ground, relief shading, rocks, rivers, roads, bridges, pass marks, coast, sea. No wild objects, towns, parcels, pieces, labels or hex grid. Genoa's bay is carved in |
| `ground_<season>.png`, `overlay_<season>.png` | EXTRA: base = ground + overlay (overlay = rivers, roads, bridges, pass marks, transparent). compose.py lays piece ground **under** rivers and roads: draw ground, piece ground, overlay to match |
| `land_mask.png` | EXTRA: white = land (after the bay). compose.py clips non-coast piece ground to land and drops standing things whose foot is wet |
| `wild.json`, `wild_<season>.png` | every wild object (3268) and its sprites |
| `pieces/index.json`, `pieces/pieces_*.png` | the pieces |
| `placements.json` | EXTRA: compose.py's 59 placements (hex, family, level, variant, mirror, centre px, `keys` per season) |

Seasons: summer and winter are compose.py's. **Spring and autumn have no frame palette**: a stand-in from `kit.PAL` (ground, sea
and river colours, broadleaf colours, autumn's three-colour leaf mix, the greens of hills and ranges scaled). Winter is blended by
climate exactly as compose.py does.

### meta.json hexes
`c, r, land, cover` (farmland, grassland, woods, marsh, rock, snow, tundra, sand; null at sea), `height_m`, `coast` (land hex with
sea inside it), `sea_angle` (screen degrees, 0 E, 90 S) and `shore` (points in px from the hex centre; null if inland; these are the
`sea=` and `shore=` compose gives the kit), `climate` (snow|frost|mild, `kit.winter_of`), `river_edges` (from the data's river
lines), `stream_edges` (extra), `road` (a drawn road passes), `pass`, `place`
`{name, level, port, port_mode, landmark: null, in_prototype}` (`level` is compose's art level for the 14 towns, else the data
level; `port_mode` carved for Genoa only), `centre_px` (extra).

### wild.json
Item: `id, hex, foot [x,y] (image px), sort_y, sort_x (extra), kind tree|hill|range, species (extra), group (extra), removable, sprite, shadow`.
**Deviation:** `sprite` and `shadow` are dicts per season: `sprite["summer"] = {atlas, rect, offset}` (offset from the foot to the
sprite's top-left; atlas = file stem; winter trees and ranges follow the climate at their foot). Sort by `(sort_y, sort_x)`.
Everything is removable, one thinning model. Trees: drop if the foot is in a piece footprint. Hills: drop if their hex has a piece.
**Ranges** are one object per range sample (283; `group` = the range they came from): the whole range is drawn and cut into vertical
strips halfway between neighbouring samples, so with nothing dropped the strips tile exactly the whole range. `foot` is the sample's
point. Drop a strip when `foot - (0, d)` is in a footprint for d in 0, 10, 20, 30 (compose's rule K; with compose's placements it drops
the same 57 samples). A cut leaves a straight vertical edge where compose redraws a tapered end. Strips never overlap, each sorts by
its own foot. The frame has no scrub and no rock objects: its rocks and scree are ground scatter and are in
the base. Wild shadows are separate sprites (RGBA, alpha 46/255 flat), not in the base.

### pieces/index.json
`{"version", "key", "atlases", "pieces": {key: entry}}`. Key `family|level|season|climate|variant|mirror(0/1)|extra`; climate is
snow/frost/mild in winter, `-` otherwise. Families: the 16 of families.py plus `sites` (variant = the site) and `harbour_addon`.
Extra: grazing animal; mines ore (`-` = default); landmark name (settlements level 4-5; none is on this map); for salt, harbour and
harbour_addon the sea side E SE S SW W NW N NE on the kit's stand-in shore, or `carved` (bay 72 px wide, 13 deep, sea S);
`hex:c,r` (`+addon` for a harbour add-on): EXTRA, the 15 coastal placements of compose.py on the map's own shore line (use these for
those hexes). Entry: `ground`, `shadow` (RGBA, alpha 46/255 already), `footprint` (mask: alpha > 0), each `{atlas, rect, offset}`
(offset from the hex centre to the sprite's top-left, piece px = image px at radius 60) or null; `standing`: list, back to front, of
`{atlas, rect, offset, foot_y, pic_foot_y}`. `foot_y` is the sort key (relative to the centre: sort by `centre_y + foot_y`, ties by
list order); `pic_foot_y` is the picture's own foot (compose's water test uses it). Mirror is baked (nothing is flipped). Ground
sprites are feathered at the hex border like compose.py and saved as straight alpha. Atlases: per season (`pieces_spring`,
`_summer`, `_autumn`, `_winter_<climate>`) plus shared `pieces_shadow` and `pieces_footprint`; 2 px padding, at most 4096 square.
Identical sprites are stored once.

## Reassembly rules (what compose.py does; see reassemble.py)
Ground, piece ground (clipped to land except coast pieces), overlay, shadows, then all standing things sorted by foot y. Wild trees
with their foot in any footprint (add-ons too) are left out; hills in a piece's hex are left out; a non-coast piece's standing thing
whose foot is in water is left out (4 things); coast pieces keep only things inside the hex.

## Size
23 MB in all (4224 piece keys, 3268 wild objects).

## Weak points
A dropped range strip leaves a vertical cut edge. Shadows overlap additively when drawn as separate sprites (compose unions them in one
layer; `reassemble.py --union-shadows` shows that). Spring and autumn are stand-ins. Hexes at the image edge have shore data from
the frame's clamped field. The frame covers 345 x 228 km (the style frame's window), not the whole 21 x 19 hex region: the style
frame's world data (fields, relief, towns) exists only for that window.
