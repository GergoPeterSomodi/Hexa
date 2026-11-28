"""Slice 5 army pieces (m6-build-spec.md 6.2): the plate, its selection ring, the strength badge, four figures, 16 icons
and the route stop; and the unit figures of option D (UR1, recruitment-queue.md 12.2), drawn in `pieces_units`.

| Piece | Size (1x) | What |
|---|---|---|
| `army_plate` | 56 x 48 | a flat-top hex plate, white with an ink edge (tinted the country's colour at run time) |
| `army_plate_ring` | 64 x 56 | the gold selection ring with a soft glow |
| `army_badge` | 36 x 18 | a brass-rimmed slot for the strength |
| `figures` | 128 x 32 | four 32 px cells: `fig_infantry`, `fig_missile`, `fig_cavalry`, `fig_artillery` (D's small form) |
| `unit_figures` | 256 x 128 | D's figures, `fig_*_full` (row 0) and `fig_*_simple` (row 1): the fixed colours, drawn on top |
| `unit_figures_tint` | 256 x 128 | the same cells, `fig_*_full_tint` / `fig_*_simple_tint`: white, drawn first in the country colour |
| `unit_signs` | 96 x 24 | the far-zoom signs `sign_infantry`... (white; drawn in the country colour darkened by half) |
| `icons_army` | 192 x 48 | 8 columns x 2 rows of 24 px cells, in `ARMY_ICON_NAMES` order |
| `path_stop` | 20 x 20 | a brass ring that holds a season's numeral on the route |

Everything is a signed distance in logical pixels, so 2x is the same recipe at `s = 2`, never an upscale; pixel paths use
only `+ - x /`, `sqrt`, `floor` and comparisons on float64. The figures and icons are two-tone woodcut like the slice 4
icons (an ink line round flat pigment). `write_token_sheet` composes the sheet the art director signs: the plate in every
scenario colour under each figure, the badge, the ring, the route stop and the icons.
"""
from __future__ import annotations

import re
from pathlib import Path
from typing import Callable

import numpy as np

from .checks import MIN_CONTRAST, BakeCheckError
from .icons import _Canvas
from .materials import gilt_stops, sample_ramp
from .pieces_frames import PieceSpec
from .pieces_m2 import sd_polygon
from .pieces_units import (
    FIGURE_NAMES, SIGNS_SIZE, UNIT_FIGURES_SIZE, check_unit_pieces, render_small_figures, render_unit_figures,
    render_unit_figures_tint, render_unit_signs,
)
from .png import save_png
from .shapes import blend_rgb_mask, coverage, logical_grid, sd_rounded_rect, sd_circle
from .tokens import TokenTable, contrast_ratio, parse_hex_color

ARMY_ICON_NAMES: tuple[str, ...] = (
    "march", "hold", "halted", "wait_snow", "muster", "supply_ok", "supply_out", "forage",
    "raise", "disband", "split", "merge", "bridge", "ford", "wade", "pass_mark",
)
FIG_CELL = 32
ICON_CELL = 24
ICON_COLUMNS = 8
FIGURES_SIZE = (128, 32)
ICONS_SIZE = (192, 48)
PLATE_SIZE = (56, 48)
RING_SIZE = (64, 56)
BADGE_SIZE = (36, 18)
STOP_SIZE = (20, 20)

PLATE_APOTHEM = 22.0  # the plate is a flat-top hex 50.8 wide and 44 high, centred, leaving 2 px for its shadow
_SQRT3_2 = 0.8660254037844386


def _finish(out: np.ndarray) -> np.ndarray:
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _rgb(tokens: TokenTable, name: str) -> np.ndarray:
    return np.asarray(tokens.rgb(name), dtype=np.float64)


def sd_hex(lx: np.ndarray, ly: np.ndarray, cx: float, cy: float, apothem: float, round_r: float = 0.0) -> np.ndarray:
    """A flat-top regular hexagon (apothem = distance to a flat side), corners rounded by `round_r`."""
    a = apothem - round_r
    r = a / _SQRT3_2
    pts = [
        (cx + r, cy), (cx + 0.5 * r, cy + a), (cx - 0.5 * r, cy + a),
        (cx - r, cy), (cx - 0.5 * r, cy - a), (cx + 0.5 * r, cy - a),
    ]
    return sd_polygon(lx, ly, pts) - round_r


# ---------------------------------------------------------------- the plate, ring, badge and stop

def _render_plate(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = PLATE_SIZE
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    cx, cy = 28.0, 22.5
    sd = sd_hex(lx, ly, cx, cy, PLATE_APOTHEM, 3.0)
    ink = _rgb(tokens, "INK")
    # A soft shadow one and a half px below (kept inside the canvas).
    sh = sd_hex(lx, ly - 1.5, cx, cy, PLATE_APOTHEM, 3.0)
    out = blend_rgb_mask(out, ink, coverage(sh, s), alpha=0.28)
    out = blend_rgb_mask(out, ink, coverage(sd, s))
    # White face: lit on the top, 8 % darker at the foot, so a tint keeps a little roundness.
    t = np.clip((ly - 0.0) / float(h), 0.0, 1.0)
    face = (1.0 - 0.10 * t)[..., None] * np.ones(3)
    face_cov = coverage(sd + 1.6, s)
    out = blend_rgb_mask(out, face, face_cov)
    # A lit rim just inside the ink and a fine inner line, as on a struck coin.
    rim = np.clip(coverage(sd + 1.6, s) - coverage(sd + 2.8, s), 0.0, 1.0)
    out = blend_rgb_mask(out, np.ones(3), rim, alpha=0.9)
    line = np.clip(coverage(sd + 5.0, s) - coverage(sd + 6.0, s), 0.0, 1.0)
    out = blend_rgb_mask(out, np.full(3, 0.74), line, alpha=0.6)
    return _finish(out)


def _render_ring(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = RING_SIZE
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    cx, cy = 32.0, 28.0
    centre = sd_hex(lx, ly, cx, cy, 24.2, 7.0)  # ring centre line
    ring_sd = np.abs(centre) - 1.4
    gold = _rgb(tokens, "GOLD")
    # The glow: GOLD fading linearly over 2.6 px outside the ring, 1.8 px of it inside.
    outside = np.clip(1.0 - np.clip(ring_sd, 0.0, 2.6) / 2.6, 0.0, 1.0)
    glow = np.where(ring_sd > 0.0, outside * outside * 0.55, 0.0)
    out = blend_rgb_mask(out, gold, glow)
    ink = _rgb(tokens, "INK")
    out = blend_rgb_mask(out, ink, coverage(ring_sd - 0.9, s))
    ramp = sample_ramp(np.clip((ly - 2.0) / 52.0, 0.0, 1.0), gilt_stops(tokens))
    out = blend_rgb_mask(out, ramp, coverage(ring_sd, s))
    out = blend_rgb_mask(out, _rgb(tokens, "BRASS_HI"), np.clip(coverage(ring_sd + 0.9, s) - coverage(ring_sd + 1.4, s), 0.0, 1.0), alpha=0.7)
    return _finish(out)


def _render_badge(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = BADGE_SIZE
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    sd = sd_rounded_rect(lx, ly, 18.0, 9.0, 18.0, 9.0, 5.0)
    ink = _rgb(tokens, "INK")
    out = blend_rgb_mask(out, ink, coverage(sd, s))
    ramp = sample_ramp(np.clip(ly / float(h), 0.0, 1.0), gilt_stops(tokens))
    out = blend_rgb_mask(out, ramp, coverage(sd + 1.0, s))
    slot_sd = sd + 3.0
    out = blend_rgb_mask(out, ink, coverage(slot_sd, s), alpha=0.9)
    slot = _rgb(tokens, "SLOT")
    out = blend_rgb_mask(out, slot, coverage(slot_sd + 1.0, s))
    # The top of the slot is in shade, as if cut into the rim.
    shade = np.clip(1.0 - (ly - 3.5) / 5.0, 0.0, 1.0)
    out = blend_rgb_mask(out, ink, coverage(slot_sd + 1.0, s) * shade, alpha=0.35)
    return _finish(out)


def _render_stop(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = STOP_SIZE
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    sd = sd_circle(lx, ly, 10.0, 10.0, 9.6)
    ink = _rgb(tokens, "INK")
    out = blend_rgb_mask(out, ink, coverage(sd, s))
    ramp = sample_ramp(np.clip(ly / float(h), 0.0, 1.0), gilt_stops(tokens))
    out = blend_rgb_mask(out, ramp, coverage(sd + 0.9, s))
    inner = sd + 3.0
    out = blend_rgb_mask(out, ink, coverage(inner, s), alpha=0.85)
    out = blend_rgb_mask(out, _rgb(tokens, "VELLUM"), coverage(inner + 0.8, s))
    return _finish(out)


# ---------------------------------------------------------------- the canvas for figures

class _Cv(_Canvas):
    """`_Canvas` on a cell of any size."""

    def __init__(self, w: int, h: int, s: int, tokens: TokenTable) -> None:
        super().__init__(s, tokens)
        self.lx, self.ly = logical_grid(w, h, s)
        self.out = np.zeros((h * s, w * s, 4), dtype=np.float64)

    def outlined_line(self, x0: float, y0: float, x1: float, y1: float, w: float, colour: str) -> None:
        self.fill(self.cap(x0, y0, x1, y1, w), colour)


# ---------------------------------------------------------------- figures (32 px cells): D's small card form, see pieces_units

def render_figures(s: int, tokens: TokenTable) -> np.ndarray:
    return render_small_figures(s, tokens)


# ---------------------------------------------------------------- icons (24 px)

def _arrow(c: _Cv, x0: float, y0: float, x1: float, y1: float, colour: str, shaft: float = 3.0, head: float = 4.4) -> None:
    """An arrow from (x0, y0) to (x1, y1) with a triangular head (ink line round the whole)."""
    dx, dy = x1 - x0, y1 - y0
    ln = (dx * dx + dy * dy) ** 0.5
    ux, uy = dx / ln, dy / ln
    px, py = -uy, ux
    bx, by = x1 - ux * head * 1.1, y1 - uy * head * 1.1
    c.fill(np.minimum(c.cap(x0, y0, bx + ux * 0.6, by + uy * 0.6, shaft), c.poly([(x1, y1), (bx + px * head, by + py * head), (bx - px * head, by - py * head)])), colour)


def _i_march(c: _Cv) -> None:
    c.fill(c.poly([(2.5, 5.0), (9.0, 5.0), (15.5, 12.0), (9.0, 19.0), (2.5, 19.0), (9.0, 12.0)]), "amber")
    c.fill(c.poly([(10.0, 5.0), (16.0, 5.0), (22.0, 12.0), (16.0, 19.0), (10.0, 19.0), (16.0, 12.0)]), "wheat")


def _i_hold(c: _Cv) -> None:
    c.fill(c.poly([(4.5, 3.5), (19.5, 3.5), (19.5, 12.0), (17.0, 17.5), (12.0, 21.5), (7.0, 17.5), (4.5, 12.0)]), "steel")
    c.fill(c.rbox(4.5, 9.0, 19.5, 12.4, 0.5), "red", ink=False)
    c.line(4.6, 8.9, 19.4, 8.9, 0.9)
    c.line(4.6, 12.5, 19.4, 12.5, 0.9)
    c.line(12.0, 4.0, 12.0, 8.6, 1.0)
    c.stroke(c.cap(6.4, 5.8, 6.4, 7.6, 1.2), "white", 0.8)


def _i_halted(c: _Cv) -> None:
    pts = [(8.2, 2.5), (15.8, 2.5), (21.5, 8.2), (21.5, 15.8), (15.8, 21.5), (8.2, 21.5), (2.5, 15.8), (2.5, 8.2)]
    c.fill(c.poly(pts), "red")
    c.fill(c.rbox(6.0, 10.0, 18.0, 14.0, 0.6), "white", ink=False)
    c.line(6.0, 9.9, 18.0, 9.9, 0.7)
    c.line(6.0, 14.1, 18.0, 14.1, 0.7)


def _i_wait_snow(c: _Cv) -> None:
    arms = ((0.0, 1.0), (0.8660254, 0.5), (0.8660254, -0.5))
    for k in (0, 1):
        for (ux, uy) in arms:
            x0, y0, x1, y1 = 12.0 - 9.6 * ux, 12.0 - 9.6 * uy, 12.0 + 9.6 * ux, 12.0 + 9.6 * uy
            if k == 0:
                c.stroke(c.cap(x0, y0, x1, y1, 3.8), "ink")
            else:
                c.stroke(c.cap(x0, y0, x1, y1, 1.9), "salt")
    for k in (0, 1):
        for (ux, uy) in arms:
            for sg in (-1.0, 1.0):
                bx, by = 12.0 + sg * 6.0 * ux, 12.0 + sg * 6.0 * uy
                px, py = -uy, ux
                x0, y0, x1, y1 = bx - px * 2.3 + sg * ux * 1.8, by - py * 2.3 + sg * uy * 1.8, bx + px * 2.3 + sg * ux * 1.8, by + py * 2.3 + sg * uy * 1.8
                if k == 0:
                    c.stroke(c.cap(bx, by, x0, y0, 2.8), "ink")
                    c.stroke(c.cap(bx, by, x1, y1, 2.8), "ink")
                else:
                    c.stroke(c.cap(bx, by, x0, y0, 1.1), "sky")
                    c.stroke(c.cap(bx, by, x1, y1, 1.1), "sky")
    c.stroke(c.circle(12.0, 12.0, 2.0), "white")


def _i_muster(c: _Cv) -> None:
    # A war banner on its pole: swallow-tail cloth, a gilt finial.
    c.fill(c.cap(6.0, 21.5, 6.0, 4.5, 1.8), "wood")
    c.fill(c.circle(6.0, 3.6, 1.7), "gold")
    c.fill(c.poly([(7.0, 5.5), (21.5, 5.5), (18.0, 10.5), (21.5, 15.5), (7.0, 15.5)]), "red")
    c.line(9.5, 9.4, 17.0, 9.4, 1.0, "gold")
    c.line(9.5, 11.8, 15.0, 11.8, 1.0, "gold")


def _sack(c: _Cv) -> None:
    c.fill(c.ell(11.0, 15.0, 8.6, 7.2), "wood")
    c.fill(c.poly([(8.0, 9.0), (14.0, 9.0), (15.4, 5.6), (6.6, 5.6)]), "wood")
    c.line(7.2, 8.6, 14.8, 8.6, 1.1, "bark")
    c.stroke(c.ell(7.6, 14.0, 1.2, 3.0, 0.94, 0.34), "cream", 0.55)


def _i_supply_ok(c: _Cv) -> None:
    _sack(c)
    c.fill(c.circle(17.4, 17.4, 5.4), "leaf")
    c.line(14.6, 17.6, 16.6, 19.6, 1.8, "white")
    c.line(16.6, 19.6, 20.4, 15.0, 1.8, "white")


def _i_supply_out(c: _Cv) -> None:
    _sack(c)
    c.fill(c.circle(17.4, 17.4, 5.4), "red")
    c.line(14.8, 14.8, 20.0, 20.0, 1.8, "white")
    c.line(20.0, 14.8, 14.8, 20.0, 1.8, "white")


def _i_forage(c: _Cv) -> None:
    # A sheaf of three wheat ears bound with a cord.
    c.line(12.0, 22.0, 12.0, 9.0, 1.4, "bark")
    c.line(12.0, 22.0, 6.0, 10.0, 1.4, "bark")
    c.line(12.0, 22.0, 18.0, 10.0, 1.4, "bark")
    for (x, y, cs, sn) in ((12.0, 6.2, 1.0, 0.0), (6.0, 7.6, 0.94, -0.34), (18.0, 7.6, 0.94, 0.34)):
        c.fill(c.ell(x, y, 2.0, 3.8, cs, sn), "wheat")
    c.fill(c.rbox(8.0, 15.4, 16.0, 17.8, 0.8), "red")


def _i_raise(c: _Cv) -> None:
    # A kettle hat with a green plus: soldiers raised.
    c.fill(c.poly([(6.4, 13.0), (7.5, 7.0), (12.0, 3.0), (16.5, 7.0), (17.6, 13.0)]), "steel")
    c.fill(c.ell(12.0, 13.6, 10.0, 2.4), "steel")
    c.line(12.0, 4.6, 12.0, 11.6, 0.9)
    c.fill(c.circle(17.4, 17.4, 4.8), "leaf")
    c.line(17.4, 14.8, 17.4, 20.0, 1.7, "white")
    c.line(14.8, 17.4, 20.0, 17.4, 1.7, "white")


def _i_disband(c: _Cv) -> None:
    # A snapped sword: two halves with a gap between them.
    c.fill(c.poly([(3.0, 21.0), (5.6, 21.0), (13.0, 13.4), (11.4, 11.8)]), "steel")
    c.fill(c.cap(11.0, 17.0, 6.0, 12.0, 1.8), "gold")
    c.fill(c.cap(5.0, 19.0, 3.4, 20.6, 2.4), "bark")
    c.fill(c.poly([(21.0, 3.0), (21.0, 5.6), (14.6, 11.4), (13.4, 10.2)]), "steel")
    c.fill(c.poly([(13.0, 7.0), (15.4, 9.4), (13.8, 10.6)]), "red")
    c.line(14.0, 11.0, 12.4, 12.6, 0.9, "red")


def _i_split(c: _Cv) -> None:
    c.fill(c.cap(12.0, 20.4, 12.0, 14.0, 3.0), "amber")
    _arrow(c, 12.0, 15.0, 5.0, 4.5, "amber", 3.0, 3.6)
    _arrow(c, 12.0, 15.0, 19.0, 4.5, "amber", 3.0, 3.6)


def _i_merge(c: _Cv) -> None:
    c.fill(c.cap(12.0, 10.0, 12.0, 17.0, 3.0), "amber")
    _arrow(c, 4.5, 2.5, 10.0, 11.0, "amber", 2.6, 3.2)
    _arrow(c, 19.5, 2.5, 14.0, 11.0, "amber", 2.6, 3.2)
    c.fill(c.poly([(12.0, 22.5), (7.6, 16.5), (16.4, 16.5)]), "amber")


def _water(c: _Cv, y: float, colour: str = "blue") -> None:
    pts = [(1.5, y)]
    x = 1.5
    up = True
    while x < 22.4:
        x += 3.0
        pts.append((x, y + (-1.4 if up else 1.4)))
        up = not up
    pts += [(22.5, 22.5), (1.5, 22.5)]
    c.fill(c.poly(pts), colour)


def _i_bridge(c: _Cv) -> None:
    _water(c, 17.0)
    c.fill(c.poly([(1.5, 8.5), (22.5, 8.5), (22.5, 12.0), (20.5, 12.0), (20.0, 18.5), (15.5, 18.5), (15.0, 15.0), (12.0, 13.4), (9.0, 15.0), (8.5, 18.5), (4.0, 18.5), (3.5, 12.0), (1.5, 12.0)]), "stone")
    c.fill(c.rbox(1.5, 6.5, 22.5, 9.0, 0.6), "cream")
    _water(c, 19.2)


def _i_ford(c: _Cv) -> None:
    _water(c, 9.0, "sky")
    _water(c, 14.5, "blue")
    c.fill(c.ell(6.0, 12.0, 2.6, 1.6), "stone")
    c.fill(c.ell(12.0, 12.0, 2.6, 1.6), "stone")
    c.fill(c.ell(18.0, 12.0, 2.6, 1.6), "stone")
    c.line(4.0, 6.0, 9.0, 4.0, 1.0, "ink")


def _i_wade(c: _Cv) -> None:
    c.fill(c.cap(8.0, 4.0, 8.5, 14.0, 3.2), "dark")
    c.fill(c.cap(15.0, 4.0, 14.5, 14.0, 3.2), "dark")
    c.fill(c.cap(8.5, 14.0, 12.0, 15.0, 3.0), "dark")
    c.fill(c.cap(14.5, 14.0, 18.0, 15.0, 3.0), "dark")
    c.fill(c.ell(11.5, 4.0, 6.0, 2.4), "cream")
    _water(c, 12.5)
    c.stroke(c.cap(3.0, 15.6, 7.0, 15.6, 1.0), "sky", 0.9)
    c.stroke(c.cap(10.0, 18.2, 15.0, 18.2, 1.0), "sky", 0.9)


def _i_pass_mark(c: _Cv) -> None:
    c.fill(c.poly([(1.5, 21.0), (8.0, 7.0), (12.0, 13.0), (16.0, 5.0), (22.5, 21.0)]), "stone")
    c.fill(c.poly([(6.2, 11.0), (8.0, 7.0), (9.8, 10.2), (8.4, 11.0), (7.2, 10.0)]), "white", ink=False)
    c.fill(c.poly([(14.4, 8.2), (16.0, 5.0), (17.8, 8.6), (16.4, 8.0), (15.4, 9.2)]), "white", ink=False)
    c.line(12.0, 13.0, 12.0, 4.2, 1.4, "bark")
    c.fill(c.poly([(12.4, 3.6), (17.0, 5.4), (12.4, 7.2)]), "red")


_ICONS: dict[str, Callable[[_Cv], None]] = {
    "march": _i_march, "hold": _i_hold, "halted": _i_halted, "wait_snow": _i_wait_snow, "muster": _i_muster,
    "supply_ok": _i_supply_ok, "supply_out": _i_supply_out, "forage": _i_forage, "raise": _i_raise,
    "disband": _i_disband, "split": _i_split, "merge": _i_merge, "bridge": _i_bridge, "ford": _i_ford,
    "wade": _i_wade, "pass_mark": _i_pass_mark,
}


def army_icon_cell(name: str, s: int, tokens: TokenTable) -> np.ndarray:
    c = _Cv(ICON_CELL, ICON_CELL, s, tokens)
    _ICONS[name](c)
    return c.out


def render_icons_army(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = ICONS_SIZE
    atlas = np.zeros((h * s, w * s, 4), dtype=np.float64)
    for i, name in enumerate(ARMY_ICON_NAMES):
        x, y = (i % ICON_COLUMNS) * ICON_CELL, (i // ICON_COLUMNS) * ICON_CELL
        atlas[y * s : (y + ICON_CELL) * s, x * s : (x + ICON_CELL) * s] = army_icon_cell(name, s, tokens)
    return _finish(atlas)


# ---------------------------------------------------------------- the catalogue and the asserts

def m6_pieces() -> list[PieceSpec]:
    zero = (0, 0, 0, 0)

    def spec(name: str, size: tuple[int, int], render: Callable[[int, TokenTable], np.ndarray]) -> PieceSpec:
        return PieceSpec(
            name=name, slice_num=5, size=size, margin=zero, content=zero, expand=zero, axis="stretch",
            fixed_height=False, min_width=0, check="exact", scales=(1, 2), out_subdir="kit", render=render,
        )

    return [
        spec("army_plate", PLATE_SIZE, _render_plate),
        spec("army_plate_ring", RING_SIZE, _render_ring),
        spec("army_badge", BADGE_SIZE, _render_badge),
        spec("figures", FIGURES_SIZE, render_figures),
        spec("icons_army", ICONS_SIZE, render_icons_army),
        spec("path_stop", STOP_SIZE, _render_stop),
        # UR1 (recruitment-queue.md 12.2): option D's figures in two layers and two levels, and the far-zoom signs.
        spec("unit_figures", UNIT_FIGURES_SIZE, render_unit_figures),
        spec("unit_figures_tint", UNIT_FIGURES_SIZE, render_unit_figures_tint),
        spec("unit_signs", SIGNS_SIZE, render_unit_signs),
    ]


TOKENS_FILE = Path(__file__).resolve().parents[2] / "godot" / "shell" / "ui" / "tokens.gd"
_HC_RE = re.compile(r'^\s*"([A-Z][A-Z0-9_]*)":\s*(?:Color\("(#[0-9a-f]{6,8})"\)|([A-Z][A-Z0-9_]*)),?\s*$')


def high_contrast_colours(tokens_path: Path, tokens: TokenTable) -> dict[str, tuple[float, float, float]]:
    """The `HIGH_CONTRAST` dictionary of tokens.gd (its entries are not one-line consts, so `load_tokens` skips them)."""
    out: dict[str, tuple[float, float, float]] = {}
    inside = False
    for line in tokens_path.read_text(encoding="utf-8").splitlines():
        if line.startswith("const HIGH_CONTRAST"):
            inside = True
            continue
        if inside and line.startswith("}"):
            break
        m = _HC_RE.match(line) if inside else None
        if m is None:
            continue
        if m.group(2):
            out[m.group(1)] = parse_hex_color(m.group(2))[:3]
        elif m.group(3) in tokens.colors:
            out[m.group(1)] = tokens.rgb(m.group(3))
    return out


def check_m6_pieces(
    tokens: TokenTable,
    specs: list[PieceSpec],
    rendered: dict[tuple[str, int], np.ndarray],
    tokens_path: Path | None = None,
) -> None:
    """Style spec 4.4 asserts for slice 5: route ink contrast, a white plate, glow inside its canvas, drawn cells."""
    for fg, bg in (("MAP_PATH", "MAP_PATH_INK"), ("MAP_PATH_WARN", "MAP_PATH_INK")):
        for name in (fg, bg):
            if name not in tokens.colors:
                raise BakeCheckError(f"Token {name} is missing from tokens.gd")
        r = contrast_ratio(tokens.rgb(fg), tokens.rgb(bg))
        if r < MIN_CONTRAST:
            raise BakeCheckError(f"Contrast {fg} on {bg} is {r:.2f} < {MIN_CONTRAST}")
    hc = high_contrast_colours(tokens_path or TOKENS_FILE, tokens)
    for fg, bg in (("MAP_PATH", "MAP_PATH_INK"), ("MAP_PATH_WARN", "MAP_PATH_INK")):
        for name in (fg, bg):
            if name not in hc:
                raise BakeCheckError(f"HIGH_CONTRAST {name} is missing from tokens.gd")
        r = contrast_ratio(hc[fg], hc[bg])
        if r < MIN_CONTRAST:
            raise BakeCheckError(f"HIGH_CONTRAST contrast {fg} on {bg} is {r:.2f} < {MIN_CONTRAST}")
    names = {sp.name for sp in specs}
    for s in (1, 2):
        plate = rendered.get(("army_plate", s))
        if plate is not None:
            # The face must be near-white (a tint multiplies it): every texel of the opaque interior is 200 or more in each channel.
            inner = plate[int(14 * s) : int(32 * s), int(18 * s) : int(38 * s)]
            if int(inner[..., :3].min()) < 200 or int(inner[..., 3].min()) != 255:
                raise BakeCheckError(f"army_plate@{s}x face is not an opaque near-white")
            if int(plate[0, 0, 3]) != 0:
                raise BakeCheckError(f"army_plate@{s}x corner is not transparent")
        ring = rendered.get(("army_plate_ring", s))
        if ring is not None:
            edge = np.concatenate([ring[0], ring[-1], ring[:, 0], ring[:, -1]])
            if int(edge[..., 3].max()) > 12:
                raise BakeCheckError(f"army_plate_ring@{s}x glow is clipped by its canvas")
            cx, cy = 32 * s, 28 * s
            if int(ring[cy, cx, 3]) != 0:
                raise BakeCheckError(f"army_plate_ring@{s}x centre is not clear")
        for name, cell, cols, count in (("figures", FIG_CELL, 4, len(FIGURE_NAMES)), ("icons_army", ICON_CELL, ICON_COLUMNS, len(ARMY_ICON_NAMES))):
            if name not in names:
                continue
            arr = rendered.get((name, s))
            if arr is None:
                continue
            for i in range(count):
                x, y = (i % cols) * cell * s, (i // cols) * cell * s
                part = arr[y : y + cell * s, x : x + cell * s, 3]
                if int((part == 255).sum()) < cell * cell * s * s // 8:
                    raise BakeCheckError(f"{name} cell {i}@{s}x is hardly drawn")
                if max(int(part[0].max()), int(part[-1].max()), int(part[:, 0].max()), int(part[:, -1].max())) > 200:
                    raise BakeCheckError(f"{name} cell {i}@{s}x touches its cell edge")
    check_unit_pieces({k: v for k, v in rendered.items() if k[0] in names})


# ---------------------------------------------------------------- the token sheet

def scenario_colours(repo_root: Path) -> list[tuple[str, tuple[int, int, int]]]:
    """The 13 country colours of the north Italy scenario, in its order, read from `data/defs/countries/`."""
    base = repo_root / "godot" / "data"
    scenario = (base / "scenarios" / "north_italy_1480.tres").read_text(encoding="utf-8")
    m = re.search(r"^countries = Array\[StringName\]\(\[(.*?)\]\)", scenario, re.MULTILINE)
    tags = re.findall(r'&"([A-Z]+)"', m.group(1)) if m else []
    out: list[tuple[str, tuple[int, int, int]]] = []
    for tag in tags:
        text = (base / "defs" / "countries" / f"{tag.lower()}.tres").read_text(encoding="utf-8")
        cm = re.search(r"^colour = Color\(([\d.]+), ([\d.]+), ([\d.]+)", text, re.MULTILINE)
        if cm:
            out.append((tag, tuple(int(float(v) * 255.0 + 0.5) for v in cm.groups())))  # type: ignore[arg-type]
    return out


def write_token_sheet(path: Path, tokens: TokenTable, repo_root: Path, s: int = 2) -> None:
    """The sheet for the art director: 13 plates x 4 figures, the badge, the ring, the stop and the icons (on leather)."""
    colours = scenario_colours(repo_root)
    pad = 10 * s
    pw, ph = PLATE_SIZE[0] * s, PLATE_SIZE[1] * s
    cols = len(FIGURE_NAMES)
    grid_w = cols * pw + (cols + 1) * pad
    icons_w = ICONS_SIZE[0] * s + 2 * pad
    width = max(grid_w, icons_w)
    top_h = RING_SIZE[1] * s + 2 * pad
    icon_h = ICONS_SIZE[1] * s + 2 * pad
    height = top_h + len(colours) * (ph + pad) + pad + icon_h
    canvas = np.zeros((height, width, 4), dtype=np.uint8)
    bg = np.asarray([int(v * 255.0 + 0.5) for v in tokens.rgb("PANEL_BG")] + [255], dtype=np.uint8)
    canvas[:] = bg

    def put(arr: np.ndarray, x: int, y: int, tint: tuple[int, int, int] | None = None) -> None:
        h, w, _ = arr.shape
        dst = canvas[y : y + h, x : x + w]
        rgb = arr[..., :3].astype(np.float64)
        if tint is not None:
            rgb = rgb * (np.asarray(tint, dtype=np.float64) / 255.0)
        a = arr[..., 3:4].astype(np.float64) / 255.0
        dst[..., :3] = np.floor(rgb * a + dst[..., :3].astype(np.float64) * (1.0 - a) + 0.5).astype(np.uint8)

    plate = _render_plate(s, tokens)
    ring = _render_ring(s, tokens)
    badge = _render_badge(s, tokens)
    stop = _render_stop(s, tokens)
    figs = render_figures(s, tokens)
    icons = render_icons_army(s, tokens)

    x = pad
    put(ring, x, pad)
    put(plate, x + 4 * s, pad + 4 * s, (214, 170, 60))
    x += RING_SIZE[0] * s + pad
    put(badge, x, pad + 19 * s)
    x += BADGE_SIZE[0] * s + pad
    put(stop, x, pad + 18 * s)

    for r, (_tag, col) in enumerate(colours):
        y = top_h + r * (ph + pad)
        for i in range(cols):
            px = pad + i * (pw + pad)
            put(plate, px, y, col)
            fx = px + (pw - FIG_CELL * s) // 2
            fy = y + (ph - FIG_CELL * s) // 2 - 1 * s
            put(figs[:, i * FIG_CELL * s : (i + 1) * FIG_CELL * s], fx, fy)
    put(icons, pad, top_h + len(colours) * (ph + pad) + pad)
    save_png(path, canvas)
