# Normal-map pieces: the tools

The rule book is `docs/design/map/pieces/GUIDE.md`. Read it first, then look at `wheat.py` and `settlements.py`:
they are the pattern to copy.

## Files

| File | What |
|---|---|
| `kit.py` | The shared kit: canvas, hex mask, palette, season colours, primitives, the sheet helper. **Do not edit it** in a family task; report what is missing |
| `wheat.py`, `settlements.py` | The two reference families |
| `<family>.py` | One module per family: `castles`, `vineyard`, `olives`, `grazing`, `salt`, `mines`, `timber`, `harbour` |
| `contract.py` | The kit's map contract on one page (`kit_contract.png`): wild land, coast sides, footprint, mirror, `pick`. Its `fishing()` is the pattern for a coast piece |
| `overview.py` | Every family on one page (`overview.png`) |

## The module contract

```python
LEVELS = range(0, 4)                 # settlements range(1, 6), castles range(1, 4)
NAMES = {0: "wild land (the map's)", 1: "...", ...}    # a short name per level, for the sheet
VARIANTS = 2                         # layouts in this module (1 until the second layout is drawn)
GATES = {"south": (x, y), ...}       # where the piece's lane ends, 10 px inside the border (unmirrored)

def draw(level, season, variant=0, mirror=False):     # season: "spring" | "summer" | "autumn" | "winter"
    if level == 0:                   # no piece on the map; on the sheet: the wild land as the map draws it
        return kit.wild(season, "grass", seed=N)
    p = kit.Piece(season, ground="grass", seed=N, mirror=mirror)   # one seed and one ground per family
    L = LAYOUT[variant]              # the layout tables: one dict per layout
    ...                               # ground-plane calls first, then standing things, then season details
    return p.finish(label="family L%d" % level)     # a 112x112 pygame.Surface with alpha
```

- **The piece draws only the work.** No wild trees, bushes, scrub, tufts or stones: the map draws the wild land and
  thins it under the piece's footprint (the kit measures the footprint from what you draw).
- **Mirror**: pass `mirror=mirror` on and draw in unmirrored coordinates. The kit turns the ground round and moves
  each standing thing to its mirrored place without flipping it, so the light stays upper left. Never write
  `if mirror:`. Landmark functions `return p.stand(y, fn)`; a part of another thing gets `on=<that handle>`.
- **Coast families** also take `sea=None, shore=None`, pass them to `kit.Piece`, call `shore = p.coast(...)` once
  and place everything at the water's edge with `shore.pt(u, v)` (u along the shore, v out to sea).
- Extra keyword arguments with defaults are allowed (`animal="sheep"`, `flag=kit.FLAG`, `addon=False`).
- Positions are fixed tables at the top of the module. No position may depend on the season. Random numbers only
  from a fixed seed, never from the season or the level.
- Running the module writes both sheets: `kit.sheet(draw, LEVELS, title, path, NAMES, ground="...", wild=True)` and
  `kit.variant_sheet(draw, LEVELS, title, "<family>_variants.png", NAMES, ground="...")`.

## Running

Python with pygame is needed; nothing else, and no data files. From the repository root:

```
python tools/worldmap/pieces/wheat.py            # writes docs/design/map/pieces/wheat.png
python tools/worldmap/pieces/wheat.py out.png    # or any other path
```

A line `PIECE PROBLEM <label> <season>: N px ...` means a standing thing leaves the hex margin: move it in.

## Output naming

- Sheets: `docs/design/map/pieces/<family>.png` (grazing: `grazing_sheep.png`, `grazing_cattle.png`,
  `grazing_horses.png`) and `<family>_variants.png`.
- Single pieces, when the game needs them later: `<family>_L<level>_<season>.png`, 112x112, hex centred.
- Trial pictures and crops go in your own scratch folder, not in the repository.

## The kit in one page

Coordinates are 100% pixels from the hex centre (x right, y down; the hex is 104 wide and 102 tall).

**Ground plane** (drawn at once, in call order)

| Call | Draws |
|---|---|
| `p.scrub(x, y, w, h, dark=0.07)` | A darker patch of the ground itself (scrub, where work will come): an overlay |
| `p.blob(x, y, w, h, col, alpha=, edge=)` | A soft ellipse: trodden or cleared ground (give `alpha`), a mound or disc (give `edge`) |
| `p.over(fn, alpha)` | Any ground drawing `fn(pen)` laid half-transparent |
| `p.patch(pts, col, ink)` | A flat shape (a yard, a pan) |
| `p.field(cx, cy, w, h, angle, cols, strips, furrows=)` | A block of strips; returns its corners |
| `p.rows(cx, cy, w, h, angle, n, dashed=)` | Plant rows on a soil block |
| `p.hedge(pts)`, `p.fence(pts)`, `p.terrace(pts, face=)` | Lines on the ground; `face=2` gives a terrace wall a visible front |
| `p.road(pts, w, track=)`, `p.water(pts, w)`, `p.pond(pts, col=, edge=)` | Roads, streams and canals (frozen in winter), ponds. Tracks are overlays |
| `p.coast(y0)` | The shore the map gave (`Piece(sea=, shore=)`; in front on the sheets). Returns a `Shore`: `pt(u, v)`, `land(x, y)`, `depth`, `front`. Draws a sea on the sheets only |
| `p.jetty(a, b, stone=, snow=)` or `p.jetty([pts], ...)` | A jetty, quay or mole; a list of points makes a bent mole; `snow=True` caps it in winter |
| `p.tufts(n, avoid=)`, `p.stones(spots)`, `p.scree(n)` | Ground scatter |
| `p.snow_patch(x, y, w, h)` | A drift (winter only) |

**Standing** (queued, drawn back to front by foot y)

| Call | Draws |
|---|---|
| `p.tree(x, y, sc, kind, i)` | `round`, `conifer`, `poplar`, `bush`, `olive`, `fruit` |
| `p.house(x, y, w, h, roof_h, wall, kind, roof, door, smoke)` | `kind`: `ridge` or `gable`; `roof`: `tile`, `thatch`, `slate` |
| `p.church(x, y, size, sc)` | `chapel`, `church`, `cathedral` |
| `p.tower(x, y, w, h, col, top, flag)` | `top`: `battlement`, `cone`, `flat` |
| `p.wall(cx, cy, rx, ry, kind, towers, gate, back_towers, col=)` | A ring wall: `palisade` or `stone`; `col=kit.STONE_GREY` for castles |
| `p.boat(x, y, sc, sail)` | A ship (1.0) or fishing boat (0.55) |
| `p.person(x, y, col)`, `p.animal(x, y, kind, flip, sc=, col=)` | `sheep`, `cow`, `horse`; `sc=0.7` for young, `col` for another coat |
| `p.haystack(x, y)`, `p.heap(x, y, w, h, col)`, `p.logs(x, y, n)` | Stacks, cone heaps, log piles |
| `p.smoke(x, y, always=, foot=)` | Smoke (autumn and winter only; `always=True` for the listed chimneys). Never call `kit._smoke` |
| `p.stand(y, fn, lift=, x=, on=)` | Returns a handle. Your own landmark: `fn(pen)` draws with `pen.poly`, `pen.rect`, `pen.box`, `pen.line`, `pen.lines`, `pen.circle`, `pen.ellipse`, `pen.dot` |
| `p.cast(x, y, w)` | The ground shadow for your own landmark |

**For the map.**

| Call | Gives |
|---|---|
| `kit.take_apart(draw, level, season, hex=(col, row), sea=, shore=)` | The piece without its ground base, as layers: `ground` (the detail, 2x), `shadow`, `standing` (`(foot_y, order_y, fn)` back to front), `footprint` (a mask: the map draws no wild tree or bush with its foot in it), `shore`, `mirror`, `variant`. **Level 0 gives `None`.** Layout and mirror come from the hex. Works with every module as it is |
| `kit.pick(col, row, variants)` | `(variant, mirror)` for a hex: always the same; with two layouts no two neighbours equal |
| `kit.in_footprint(mask, x, y)` | True if the piece-px point is in the footprint |
| `kit.mirror_gates(GATES, mirror)` | The gate points as they lie in a mirrored piece |

**For the sheets.** `kit.wild(season, ground, seed, coast=)` is the level 0 picture; `kit.sheet(..., wild=True)`
shows every piece in the terrain's wild land thinned by its footprint; `kit.variant_sheet(...)` shows the layouts,
their mirrors and a block of hexes chosen by `pick`; `kit.with_wild(draw, level, season, variant=, mirror=)` gives
one such picture.

**Colours**: fixed tokens `kit.INK`, `kit.ROOF`, `kit.STONE` ...; season tokens `p.pal["grass"]` ...; crops
`kit.crop("wheat", season)`; helpers `kit.mix(c1, c2, t)`, `kit.shade(c, f)`; flags `p.winter`, `p.season`.

For a landmark of your own, copy the shape of `windmill()` in `wheat.py`: call `p.cast`, define `fn(pen)`, draw the
lit body, the shaded right part, the snow variant, then the ink, and queue it with `p.stand(foot_y, fn)`.
