# Normal-map pieces: the tools

The rule book is `docs/design/map/pieces/GUIDE.md`. Read it first, then look at `wheat.py` and `settlements.py`:
they are the pattern to copy.

## Files

| File | What |
|---|---|
| `kit.py` | The shared kit: canvas, hex mask, palette, season colours, primitives, the sheet helper. **Do not edit it** in a family task; report what is missing |
| `wheat.py`, `settlements.py` | The two reference families |
| `<family>.py` | One module per family: `castles`, `vineyard`, `olives`, `grazing`, `salt`, `mines`, `timber`, `harbour` |

## The module contract

```python
LEVELS = range(0, 4)                 # settlements range(1, 6), castles range(1, 4)
NAMES = {0: "...", 1: "...", ...}    # a short name per level, for the sheet

def draw(level, season):             # season: "spring" | "summer" | "autumn" | "winter"
    p = kit.Piece(season, ground="grass", seed=N)   # one seed and one ground per family
    ...                               # ground-plane calls first, then standing things, then season details
    return p.finish(label="family L%d" % level)     # a 112x112 pygame.Surface with alpha
```

- Extra keyword arguments with defaults are allowed (`animal="sheep"`, `flag=kit.FLAG`).
- Positions are fixed tables at the top of the module (see `BLOCKS`, `WILD_TREES` in `wheat.py`). No position may
  depend on the season. Random numbers only from a fixed seed, never from the season or the level.
- Running the module writes the sheet: `kit.sheet(draw, LEVELS, title, path, NAMES, ground="...")`.

## Running

Python with pygame is needed; nothing else, and no data files. From the repository root:

```
python tools/worldmap/pieces/wheat.py            # writes docs/design/map/pieces/wheat.png
python tools/worldmap/pieces/wheat.py out.png    # or any other path
```

A line `PIECE PROBLEM <label> <season>: N px ...` means a standing thing leaves the hex margin: move it in.

## Output naming

- Sheets: `docs/design/map/pieces/<family>.png` (grazing: `grazing_sheep.png`, `grazing_cattle.png`,
  `grazing_horses.png`).
- Single pieces, when the game needs them later: `<family>_L<level>_<season>.png`, 112x112, hex centred.
- Trial pictures and crops go in your own scratch folder, not in the repository.

## The kit in one page

Coordinates are 100% pixels from the hex centre (x right, y down; the hex is 104 wide and 102 tall).

**Ground plane** (drawn at once, in call order)

| Call | Draws |
|---|---|
| `p.blob(x, y, w, h, col)` | A soft patch (scrub, trodden ground) |
| `p.patch(pts, col, ink)` | A flat shape (a yard, a pan) |
| `p.field(cx, cy, w, h, angle, cols, strips, furrows=)` | A block of strips; returns its corners |
| `p.rows(cx, cy, w, h, angle, n, dashed=)` | Plant rows on a soil block |
| `p.hedge(pts)`, `p.fence(pts)`, `p.terrace(pts)` | Lines on the ground |
| `p.road(pts, w, track=)`, `p.water(pts, w)`, `p.pond(pts)` | Roads, streams and canals (frozen in winter), ponds |
| `p.coast(y0)` | The sea on the south side; returns `shore(x)` |
| `p.jetty(a, b, stone=)` | A jetty, quay or mole |
| `p.tufts(n, avoid=)`, `p.stones(spots)`, `p.scree(n)` | Ground scatter |
| `p.snow_patch(x, y, w, h)` | A drift (winter only) |

**Standing** (queued, drawn back to front by foot y)

| Call | Draws |
|---|---|
| `p.tree(x, y, sc, kind, i)` | `round`, `conifer`, `poplar`, `bush`, `olive`, `fruit` |
| `p.house(x, y, w, h, roof_h, wall, kind, roof, door, smoke)` | `kind`: `ridge` or `gable`; `roof`: `tile`, `thatch`, `slate` |
| `p.church(x, y, size, sc)` | `chapel`, `church`, `cathedral` |
| `p.tower(x, y, w, h, col, top, flag)` | `top`: `battlement`, `cone`, `flat` |
| `p.wall(cx, cy, rx, ry, kind, towers, gate, back_towers)` | A ring wall: `palisade` or `stone` |
| `p.boat(x, y, sc, sail)` | A ship (1.0) or fishing boat (0.55) |
| `p.person(x, y, col)`, `p.animal(x, y, kind, flip)` | `sheep`, `cow`, `horse` |
| `p.haystack(x, y)`, `p.heap(x, y, w, h, col)`, `p.logs(x, y, n)` | Stacks, cone heaps, log piles |
| `p.smoke(x, y)` | Smoke (autumn and winter only) |
| `p.stand(y, fn)` | Your own landmark: `fn(pen)` draws with `pen.poly`, `pen.rect`, `pen.box`, `pen.line`, `pen.lines`, `pen.circle`, `pen.ellipse`, `pen.dot` |
| `p.cast(x, y, w)` | The ground shadow for your own landmark |

**Colours**: fixed tokens `kit.INK`, `kit.ROOF`, `kit.STONE` ...; season tokens `p.pal["grass"]` ...; crops
`kit.crop("wheat", season)`; helpers `kit.mix(c1, c2, t)`, `kit.shade(c, f)`; flags `p.winter`, `p.season`.

For a landmark of your own, copy the shape of `windmill()` in `wheat.py`: call `p.cast`, define `fn(pen)`, draw the
lit body, the shaded right part, the snow variant, then the ink, and queue it with `p.stand(foot_y, fn)`.
