"""Slice 4 icon atlas (spec 4.5; m4-build-spec.md 6.2): 50 two-tone woodcut icons, 24 px cells.

Each icon is an ink line (the INK token, about 0.9 px outside every filled shape) around flat pigment. Everything is
a signed distance in logical pixels, so 2x is the same recipe at s = 2, never an upscale. Pixel paths use only
`+ - x /`, `sqrt`, `floor` and comparisons on float64; the angles are literal constants.

`icons` is 256 x 128 at 1x: 10 columns x 5 rows of 24 px cells, all 50 used, in `ICON_NAMES` order, the cell of
index i at column i % 10, row i // 10. No cell is spare: the next icon needs another atlas or a larger one.
"""
from __future__ import annotations

from typing import Callable

import numpy as np

from .pieces_frames import PieceSpec
from .pieces_m2 import sd_polygon
from .shapes import blend_rgb_mask, coverage, logical_grid, sd_box, sd_circle, sd_rounded_rect, sd_segment
from .tokens import TokenTable, parse_hex_color

CELL = 24
COLUMNS = 10
ATLAS_SIZE = (256, 128)

ICON_NAMES: tuple[str, ...] = (
    # Goods (16)
    "good_grain", "good_fish", "good_oil", "good_wine", "good_salt", "good_hemp", "good_silk", "good_dyes",
    "good_wool", "good_cattle", "good_horses", "good_timber", "good_stone", "good_iron", "good_copper", "good_silver",
    # Money (9)
    "ducats", "stores", "tax", "upkeep", "walls", "port_dues", "spending", "refund", "payback",
    # Land and people (5)
    "people", "jobs", "district", "settlement", "castle",
    # Seasons and weather (6)
    "season_spring", "season_summer", "season_autumn", "season_winter", "weather_good", "weather_poor",
    # Screens (8)
    "study", "pin", "info", "go", "warning", "ring", "chart", "sold",
    # Later chips, baked now (4)
    "food", "army", "research", "prestige",
    # The action log's button (1), baked in the spare cell of the last row
    "log",
    # The barracks tile of the Town tab (recruitment-queue.md 8), a stand-in until the art director approves it
    "barracks",
)

# One flat pigment each (plus a rare accent), lit enough to read on leather and on vellum beside an ink line.
_PIGMENTS: dict[str, str] = {
    "wheat": "#e3b94e", "cream": "#f1e6c8", "white": "#f4efe2", "salt": "#e4ecf0",
    "red": "#cf4a30", "rose": "#d86a5a", "wine": "#8a3a7a", "violet": "#a8509a",
    "green": "#5f9e4a", "leaf": "#82b85a", "olive": "#b0b448", "teal": "#3f9a86",
    "blue": "#4f7fc4", "sky": "#8fb4d8", "indigo": "#3d5fb4",
    "brown": "#9a6034", "wood": "#b9803f", "bark": "#6e4426", "dark": "#4a3a2e",
    "stone": "#b4ab98", "iron": "#8b97a8", "steel": "#c6ced8", "silver": "#d4dbe2",
    "copper": "#d2763a", "orange": "#e08a3a", "amber": "#f0b030", "skin": "#e4b88e",
}


class _Canvas:
    """One icon cell: filled shapes with an ink line, and plain ink or pigment strokes."""

    def __init__(self, s: int, tokens: TokenTable) -> None:
        self.s = s
        self.lx, self.ly = logical_grid(CELL, CELL, s)
        self.out = np.zeros((CELL * s, CELL * s, 4), dtype=np.float64)
        self.ink = np.asarray(tokens.rgb("INK"), dtype=np.float64)
        self.pal: dict[str, np.ndarray] = {k: np.asarray(parse_hex_color(v)[:3], dtype=np.float64) for k, v in _PIGMENTS.items()}
        for tok in ("GOLD", "BRASS", "BRASS_HI", "LAPIS", "VELLUM", "SEAL"):
            self.pal[tok.lower()] = np.asarray(tokens.rgb(tok), dtype=np.float64)
        self.pal["ink"] = self.ink

    def col(self, c: str | np.ndarray) -> np.ndarray:
        return self.pal[c] if isinstance(c, str) else c

    # shapes as signed distances
    def circle(self, cx: float, cy: float, r: float) -> np.ndarray:
        return sd_circle(self.lx, self.ly, cx, cy, r)

    def ell(self, cx: float, cy: float, rx: float, ry: float, cs: float = 1.0, sn: float = 0.0) -> np.ndarray:
        """Ellipse (IQ's bound), optionally turned by the cosine and sine of an angle."""
        dx = self.lx - cx
        dy = self.ly - cy
        u = (dx * cs + dy * sn) / rx
        v = (-dx * sn + dy * cs) / ry
        k0 = np.sqrt(u * u + v * v)
        k1 = np.sqrt((u / rx) ** 2 + (v / ry) ** 2)
        return np.where(k1 > 1e-9, k0 * (k0 - 1.0) / np.maximum(k1, 1e-9), -np.minimum(rx, ry))

    def box(self, x0: float, y0: float, x1: float, y1: float) -> np.ndarray:
        return sd_box(self.lx, self.ly, 0.5 * (x0 + x1), 0.5 * (y0 + y1), 0.5 * (x1 - x0), 0.5 * (y1 - y0))

    def rbox(self, x0: float, y0: float, x1: float, y1: float, r: float) -> np.ndarray:
        return sd_rounded_rect(self.lx, self.ly, 0.5 * (x0 + x1), 0.5 * (y0 + y1), 0.5 * (x1 - x0), 0.5 * (y1 - y0), r)

    def poly(self, pts: list[tuple[float, float]]) -> np.ndarray:
        return sd_polygon(self.lx, self.ly, pts)

    def cap(self, x0: float, y0: float, x1: float, y1: float, w: float) -> np.ndarray:
        return sd_segment(self.lx, self.ly, x0, y0, x1, y1) - 0.5 * w

    def ring(self, cx: float, cy: float, r: float, w: float) -> np.ndarray:
        return np.abs(sd_circle(self.lx, self.ly, cx, cy, r)) - 0.5 * w

    # painting
    def fill(self, sd: np.ndarray, colour: str, ink: bool = True, ow: float = 0.9) -> None:
        if ink:
            self.out = blend_rgb_mask(self.out, self.ink, coverage(sd - ow, self.s))
        self.out = blend_rgb_mask(self.out, self.col(colour), coverage(sd, self.s))

    def stroke(self, sd: np.ndarray, colour: str = "ink", alpha: float = 1.0) -> None:
        """A shape drawn flat, with no outline of its own (ink details, highlights)."""
        self.out = blend_rgb_mask(self.out, self.col(colour), coverage(sd, self.s), alpha=alpha)

    def line(self, x0: float, y0: float, x1: float, y1: float, w: float = 1.3, colour: str = "ink") -> None:
        self.stroke(self.cap(x0, y0, x1, y1, w), colour)

    def dot(self, cx: float, cy: float, r: float, colour: str = "ink") -> None:
        self.stroke(self.circle(cx, cy, r), colour)


# ---------------------------------------------------------------- goods

def _grain(c: _Canvas) -> None:
    c.line(12.0, 22.0, 12.0, 9.0, 1.6, "bark")
    for (x, y) in ((9.4, 18.0), (14.6, 18.0), (9.2, 13.6), (14.8, 13.6), (9.4, 9.2), (14.6, 9.2)):
        sgn = -1.0 if x < 12.0 else 1.0
        c.fill(c.ell(x, y, 1.9, 3.0, 0.9397, sgn * 0.342), "wheat")
    c.fill(c.ell(12.0, 5.6, 1.9, 3.2), "wheat")


def _fish(c: _Canvas) -> None:
    c.fill(c.poly([(16.5, 12.0), (22.5, 6.5), (22.0, 12.0), (22.5, 17.5)]), "sky")
    c.fill(c.ell(10.8, 12.0, 8.4, 5.0), "sky")
    c.fill(c.poly([(8.0, 7.5), (13.0, 7.2), (11.0, 3.8)]), "blue")
    c.stroke(c.ring(10.8, 12.0, 3.2, 1.0), "ink", 0.0)
    c.line(14.0, 8.6, 14.0, 15.4, 1.0)
    c.dot(6.2, 10.8, 1.05)
    c.line(2.8, 13.0, 4.8, 13.4, 1.0)


def _oil(c: _Canvas) -> None:
    c.fill(c.rbox(9.6, 3.0, 14.4, 9.0, 1.2), "bark")
    c.fill(c.ell(12.0, 15.2, 6.6, 6.8), "olive")
    c.fill(c.rbox(10.0, 7.0, 14.0, 10.5, 0.6), "olive")
    c.stroke(c.ell(9.4, 14.0, 1.4, 3.2, 0.94, 0.34), "cream", 0.65)
    c.line(9.6, 5.8, 14.4, 5.8, 1.0)


def _wine(c: _Canvas) -> None:
    c.fill(c.poly([(12.0, 7.5), (16.0, 3.0), (20.0, 4.5), (17.5, 8.0)]), "leaf")
    c.line(12.0, 8.0, 12.0, 4.5, 1.5, "bark")
    for (x, y) in ((8.0, 10.2), (12.0, 10.2), (16.0, 10.2), (10.0, 14.2), (14.0, 14.2), (12.0, 18.2)):
        c.fill(c.circle(x, y, 2.9), "violet")
    for (x, y) in ((7.2, 9.4), (11.2, 9.4), (15.2, 9.4), (9.2, 13.4), (13.2, 13.4), (11.2, 17.4)):
        c.dot(x, y, 0.65, "cream")


def _salt(c: _Canvas) -> None:
    c.fill(c.poly([(2.5, 20.5), (8.0, 9.5), (12.0, 6.0), (16.0, 10.0), (21.5, 20.5)]), "salt")
    c.line(12.0, 6.5, 12.0, 20.0, 1.0)
    c.line(8.2, 10.0, 6.5, 20.0, 1.0)
    c.line(15.8, 10.4, 17.5, 20.0, 1.0)
    c.fill(c.poly([(18.0, 4.0), (19.0, 6.0), (21.0, 7.0), (19.0, 8.0), (18.0, 10.0), (17.0, 8.0), (15.0, 7.0), (17.0, 6.0)]), "white")


def _hemp(c: _Canvas) -> None:
    c.fill(c.cap(16.5, 17.0, 21.5, 21.0, 3.0), "wood")
    c.fill(c.ring(12.0, 12.0, 7.4, 4.2), "wood")
    c.fill(c.ring(12.0, 12.0, 2.6, 2.4), "wood")
    for (x0, y0, x1, y1) in ((12.0, 4.0, 12.0, 7.0), (12.0, 17.0, 12.0, 20.0), (4.0, 12.0, 7.0, 12.0), (17.0, 12.0, 20.0, 12.0)):
        c.line(x0, y0, x1, y1, 0.8, "bark")


def _silk(c: _Canvas) -> None:
    top = [(3.0, 6.5), (7.0, 4.6), (12.0, 6.6), (17.0, 4.8), (21.0, 6.2)]
    bot = [(21.0, 17.5), (17.0, 19.2), (12.0, 17.2), (7.0, 19.0), (3.0, 17.4)]
    c.fill(c.poly(top + bot), "violet")
    c.line(8.0, 6.0, 8.0, 18.0, 0.9, "wine")
    c.line(13.0, 6.5, 13.0, 17.6, 0.9, "wine")
    c.line(17.5, 5.6, 17.5, 18.4, 0.9, "wine")
    c.stroke(c.cap(4.6, 8.6, 6.6, 8.2, 1.2), "white", 0.8)


def _dyes(c: _Canvas) -> None:
    bowl = np.maximum(c.circle(12.0, 11.0, 8.6), 11.0 - c.ly)
    c.fill(bowl, "brown")
    c.fill(c.ell(12.0, 11.0, 8.6, 3.0), "indigo")
    c.stroke(c.ell(9.8, 10.4, 2.4, 0.8), "sky", 0.9)
    c.fill(c.poly([(18.5, 2.5), (20.5, 6.0), (18.5, 7.6), (16.5, 6.0)]), "red")
    c.fill(c.rbox(8.0, 19.4, 16.0, 21.4, 0.8), "bark")


def _wool(c: _Canvas) -> None:
    c.line(8.0, 17.0, 8.0, 22.0, 1.8, "dark")
    c.line(15.0, 17.0, 15.0, 22.0, 1.8, "dark")
    c.fill(c.ell(19.6, 13.4, 2.4, 3.0), "dark")
    for (x, y, r) in ((7.0, 12.8, 4.2), (12.0, 9.2, 4.8), (16.4, 12.6, 4.2), (11.8, 15.4, 4.6)):
        c.fill(c.circle(x, y, r), "white")
    c.dot(20.4, 12.6, 0.7, "cream")


def _cattle(c: _Canvas) -> None:
    c.fill(c.cap(8.4, 8.6, 3.4, 4.4, 2.2), "cream")
    c.fill(c.cap(15.6, 8.6, 20.6, 4.4, 2.2), "cream")
    c.fill(c.poly([(8.0, 7.6), (16.0, 7.6), (15.2, 15.5), (12.0, 20.5), (8.8, 15.5)]), "brown")
    c.fill(c.ell(5.8, 9.8, 2.4, 1.4, 0.94, 0.34), "brown")
    c.fill(c.ell(18.2, 9.8, 2.4, 1.4, 0.94, -0.34), "brown")
    c.fill(c.ell(12.0, 17.6, 3.6, 2.7), "skin")
    c.dot(9.7, 11.6, 0.95)
    c.dot(14.3, 11.6, 0.95)
    c.dot(10.8, 17.6, 0.7)
    c.dot(13.2, 17.6, 0.7)


def _horses(c: _Canvas) -> None:
    head = [(14.5, 2.0), (16.0, 6.0), (18.8, 10.0), (20.5, 22.0), (10.5, 22.0), (11.5, 18.5), (8.8, 15.8), (4.6, 17.5),
            (3.2, 15.5), (3.8, 11.5), (8.0, 8.0), (10.8, 5.5), (12.2, 2.5)]
    c.fill(c.poly(head), "brown")
    c.fill(c.poly([(16.0, 6.0), (18.8, 10.0), (20.5, 22.0), (17.0, 22.0), (17.5, 12.0), (14.5, 6.5)]), "bark")
    c.dot(9.6, 9.8, 0.95)
    c.dot(4.7, 15.2, 0.6)


def _timber(c: _Canvas) -> None:
    for (x, y) in ((7.0, 16.4), (17.0, 16.4), (12.0, 7.6)):
        c.fill(c.circle(x, y, 5.0), "bark")
        c.stroke(c.circle(x, y, 3.7), "wood")
        c.stroke(c.ring(x, y, 2.2, 0.8), "bark")
        c.dot(x, y, 0.6, "bark")


def _stone(c: _Canvas) -> None:
    c.fill(c.rbox(2.6, 13.6, 11.6, 21.0, 0.8), "stone")
    c.fill(c.rbox(12.4, 13.6, 21.4, 21.0, 0.8), "stone")
    c.fill(c.rbox(7.0, 5.0, 17.0, 12.8, 0.8), "stone")
    c.line(4.4, 15.4, 7.6, 15.4, 0.8, "white")
    c.line(14.4, 15.4, 17.6, 15.4, 0.8, "white")
    c.line(9.0, 7.0, 12.6, 7.0, 0.8, "white")
    c.line(9.4, 10.4, 10.6, 10.0, 0.8, "dark")


def _iron(c: _Canvas) -> None:
    anvil = [(2.0, 6.5), (18.5, 6.5), (22.0, 9.0), (16.0, 11.0), (14.5, 13.0), (16.5, 18.5), (19.0, 20.5), (5.0, 20.5),
             (7.5, 18.5), (9.5, 13.0), (8.0, 11.0), (2.0, 9.5)]
    c.fill(c.poly(anvil), "iron")
    c.line(4.0, 8.0, 17.0, 8.0, 0.9, "steel")
    c.line(7.0, 19.0, 17.0, 19.0, 0.9, "dark")


def _copper(c: _Canvas) -> None:
    c.fill(c.poly([(6.5, 12.0), (17.5, 12.0), (20.5, 19.5), (3.5, 19.5)]), "copper")
    c.fill(c.poly([(8.5, 4.5), (15.5, 4.5), (17.5, 12.0), (6.5, 12.0)]), "copper")
    c.line(9.5, 6.4, 14.5, 6.4, 0.9, "amber")
    c.line(5.4, 14.0, 18.6, 14.0, 0.9, "amber")
    c.line(7.0, 16.8, 17.0, 16.8, 0.8, "bark")


def _silver(c: _Canvas) -> None:
    nug = [(3.5, 15.0), (6.0, 8.5), (11.0, 4.5), (17.0, 6.5), (21.0, 12.0), (19.0, 19.5), (11.0, 20.5), (5.5, 19.5)]
    c.fill(c.poly(nug), "silver")
    c.line(7.0, 9.5, 11.0, 12.0, 0.9, "iron")
    c.line(11.0, 12.0, 10.0, 18.5, 0.9, "iron")
    c.line(11.0, 12.0, 18.0, 11.0, 0.9, "iron")
    c.stroke(c.cap(8.0, 6.4, 12.4, 5.8, 1.0), "white")


# ---------------------------------------------------------------- money

def _ducats(c: _Canvas) -> None:
    c.fill(c.circle(12.0, 12.0, 10.0), "gold")
    c.stroke(c.ring(12.0, 12.0, 7.4, 0.9), "bark", 0.9)
    c.fill(c.poly([(12.0, 5.8), (13.6, 10.4), (18.2, 12.0), (13.6, 13.6), (12.0, 18.2), (10.4, 13.6), (5.8, 12.0), (10.4, 10.4)]), "amber", ink=False)
    c.stroke(c.ring(12.0, 12.0, 8.0, 0.0), "ink", 0.0)
    c.stroke(c.poly([(12.0, 7.4), (13.0, 11.0), (16.6, 12.0), (13.0, 13.0), (12.0, 16.6), (11.0, 13.0), (7.4, 12.0), (11.0, 11.0)]), "bark")


def _stores(c: _Canvas) -> None:
    c.fill(c.rbox(2.8, 7.0, 21.2, 21.0, 1.0), "wood")
    c.fill(c.rbox(2.8, 4.0, 21.2, 8.6, 1.0), "brown")
    c.line(3.6, 14.0, 20.4, 14.0, 1.0, "bark")
    c.line(5.0, 9.5, 19.0, 19.5, 1.0, "bark")
    c.line(19.0, 9.5, 5.0, 19.5, 1.0, "bark")
    c.dot(4.6, 5.8, 0.7, "steel")
    c.dot(19.4, 5.8, 0.7, "steel")


def _tax(c: _Canvas) -> None:
    c.fill(c.circle(12.0, 12.0, 10.0), "gold")
    c.fill(c.ring(8.2, 8.2, 2.1, 1.7), "gold", ink=False)
    c.fill(c.ring(15.8, 15.8, 2.1, 1.7), "gold", ink=False)
    c.stroke(c.ring(8.2, 8.2, 2.1, 1.7), "ink")
    c.stroke(c.ring(15.8, 15.8, 2.1, 1.7), "ink")
    c.line(16.4, 6.6, 7.6, 17.4, 1.9)


def _upkeep(c: _Canvas) -> None:
    c.fill(c.cap(6.0, 21.0, 15.0, 9.0, 3.0), "wood")
    head = [(11.0, 3.0), (21.0, 7.0), (19.0, 11.4), (16.6, 10.2), (14.2, 12.6), (9.5, 7.2)]
    c.fill(c.poly(head), "iron")
    c.line(11.6, 4.8, 18.4, 7.6, 0.9, "steel")


def _walls(c: _Canvas) -> None:
    wall = [(2.5, 21.0), (2.5, 7.0), (6.5, 7.0), (6.5, 4.5), (10.0, 4.5), (10.0, 7.0), (14.0, 7.0), (14.0, 4.5), (17.5, 4.5),
            (17.5, 7.0), (21.5, 7.0), (21.5, 21.0)]
    c.fill(c.poly(wall), "stone")
    for y in (11.5, 16.0):
        c.line(2.8, y, 21.2, y, 0.9, "dark")
    for x, ya, yb in ((7.0, 7.0, 11.5), (13.0, 7.0, 11.5), (18.5, 7.0, 11.5), (4.5, 11.5, 16.0), (10.0, 11.5, 16.0), (16.0, 11.5, 16.0),
                      (7.0, 16.0, 20.8), (13.0, 16.0, 20.8), (19.0, 16.0, 20.8)):
        c.line(x, ya, x, yb, 0.9, "dark")


def _port_dues(c: _Canvas) -> None:
    arc = np.maximum(c.ring(12.0, 12.5, 7.6, 2.4), 12.5 - c.ly)
    c.fill(arc, "iron")
    c.fill(c.poly([(1.8, 10.4), (6.6, 11.4), (4.6, 15.2)]), "iron")
    c.fill(c.poly([(22.2, 10.4), (17.4, 11.4), (19.4, 15.2)]), "iron")
    c.fill(c.cap(12.0, 6.5, 12.0, 20.5, 2.6), "iron")
    c.fill(c.cap(7.8, 9.0, 16.2, 9.0, 2.2), "iron")
    c.fill(c.ring(12.0, 4.2, 2.0, 1.6), "iron")


def _spending(c: _Canvas) -> None:
    c.fill(c.poly([(8.5, 9.0), (15.5, 9.0), (14.5, 12.0), (9.5, 12.0)]), "wood")
    c.fill(c.circle(12.0, 16.2, 6.4), "wood")
    c.fill(c.rbox(8.4, 8.2, 15.6, 10.0, 0.8), "bark")
    c.line(10.0, 14.4, 10.0, 18.0, 0.8, "bark")
    c.fill(c.circle(18.2, 5.8, 3.7), "gold")
    c.stroke(c.ring(18.2, 5.8, 2.0, 0.8), "bark")
    c.fill(c.circle(5.8, 4.8, 2.6), "gold")


def _refund(c: _Canvas) -> None:
    c.fill(c.circle(12.0, 14.6, 6.6), "gold")
    c.stroke(c.ring(12.0, 14.6, 3.8, 0.8), "bark")
    c.fill(np.maximum(c.ring(12.0, 12.0, 8.8, 2.2), c.ly - 9.6), "teal")
    c.fill(c.poly([(0.8, 8.6), (5.8, 8.6), (3.3, 13.2)]), "teal")


def _payback(c: _Canvas) -> None:
    c.fill(c.circle(12.0, 12.0, 10.0), "gold")
    c.fill(c.circle(12.0, 12.0, 7.2), "cream")
    c.line(12.0, 12.0, 12.0, 6.6, 1.7)
    c.line(12.0, 12.0, 16.2, 14.6, 1.7)
    c.dot(12.0, 12.0, 1.3)
    c.line(12.0, 5.4, 12.0, 6.2, 1.0)


# ---------------------------------------------------------------- land and people

def _people(c: _Canvas) -> None:
    c.fill(c.circle(15.8, 7.0, 3.3), "skin")
    c.fill(np.maximum(c.circle(15.8, 18.0, 6.6), 12.2 - c.ly), "brown")
    c.fill(c.circle(8.6, 8.4, 3.7), "skin")
    c.fill(np.maximum(c.circle(8.6, 20.5, 7.4), 13.6 - c.ly), "blue")


def _jobs(c: _Canvas) -> None:
    c.fill(c.cap(6.0, 21.0, 17.0, 8.0, 2.6), "wood")
    pick = c.poly([(3.0, 10.0), (8.0, 4.5), (15.0, 3.6), (21.0, 7.0), (18.0, 7.6), (14.0, 6.6), (9.5, 8.0), (6.0, 11.6)])
    c.fill(pick, "iron")
    c.line(8.6, 6.4, 15.0, 5.4, 0.9, "steel")


def _district(c: _Canvas) -> None:
    hexa = [(12.0, 1.8), (21.0, 7.0), (21.0, 17.0), (12.0, 22.2), (3.0, 17.0), (3.0, 7.0)]
    c.fill(c.poly(hexa), "leaf")
    for (y, a, b) in ((9.4, 6.0, 18.0), (12.6, 5.0, 19.0), (15.8, 6.0, 18.0)):
        c.line(a, y, b, y, 1.2, "brown")
    c.line(12.0, 5.2, 12.0, 6.4, 0.8, "green")


def _settlement(c: _Canvas) -> None:
    c.fill(c.rbox(15.4, 14.0, 21.6, 21.0, 0.5), "cream")
    c.fill(c.poly([(14.4, 14.4), (18.5, 9.8), (22.6, 14.4)]), "bark")
    c.fill(c.rbox(5.4, 11.0, 16.4, 21.0, 0.5), "cream")
    c.fill(c.poly([(3.4, 11.4), (10.9, 4.0), (18.4, 11.4)]), "red")
    c.fill(c.rbox(9.0, 15.0, 12.8, 21.0, 0.5), "bark")
    c.stroke(c.box(6.4, 12.6, 8.2, 14.2), "bark")


def _castle(c: _Canvas) -> None:
    c.fill(c.poly([(8.0, 21.0), (8.0, 11.0), (16.0, 11.0), (16.0, 21.0)]), "stone")
    c.fill(c.poly([(2.5, 21.0), (2.5, 8.0), (4.0, 8.0), (4.0, 6.5), (6.0, 6.5), (6.0, 8.0), (8.0, 8.0), (8.0, 21.0)]), "stone")
    c.fill(c.poly([(16.0, 21.0), (16.0, 8.0), (18.0, 8.0), (18.0, 6.5), (20.0, 6.5), (20.0, 8.0), (21.5, 8.0), (21.5, 21.0)]), "stone")
    c.fill(c.poly([(9.0, 11.0), (9.0, 8.6), (10.8, 8.6), (10.8, 10.0), (13.2, 10.0), (13.2, 8.6), (15.0, 8.6), (15.0, 11.0)]), "stone", ink=False)
    c.fill(c.cap(12.0, 10.0, 12.0, 3.0, 1.0), "bark")
    c.fill(c.poly([(12.5, 3.2), (18.0, 5.0), (12.5, 7.0)]), "red")
    c.fill(np.maximum(c.circle(12.0, 16.0, 2.2), 16.0 - c.ly), "ink", ink=False)
    c.stroke(c.box(9.8, 16.0, 14.2, 21.0), "ink")
    c.stroke(c.box(4.0, 12.5, 5.2, 15.0), "dark")
    c.stroke(c.box(18.8, 12.5, 20.0, 15.0), "dark")


def _barracks(c: _Canvas) -> None:
    """A long hall between two upright pikes: wider and lower than the town's houses, with no towers."""
    for x in (3.6, 20.4):
        c.fill(c.cap(x, 7.0, x, 21.2, 1.4), "wood")
        c.fill(c.poly([(x, 1.6), (x + 2.0, 5.2), (x, 8.2), (x - 2.0, 5.2)]), "steel")
    c.fill(c.rbox(6.6, 13.0, 17.4, 21.0, 0.5), "cream")
    c.fill(c.poly([(5.4, 13.4), (8.4, 7.6), (15.6, 7.6), (18.6, 13.4)]), "blue")
    c.fill(np.maximum(c.circle(12.0, 17.6, 2.0), c.ly - 17.6), "bark", ink=False)
    c.fill(c.box(10.0, 17.4, 14.0, 21.0), "bark", ink=False)
    for x in (8.4, 15.6):
        c.stroke(c.box(x - 0.7, 15.2, x + 0.7, 17.4), "dark")


# ---------------------------------------------------------------- seasons and weather

def _spring(c: _Canvas) -> None:
    c.fill(c.ell(12.0, 20.4, 7.6, 2.4), "brown")
    c.line(12.0, 20.0, 12.0, 10.0, 1.7, "green")
    c.fill(c.poly([(12.0, 13.5), (4.0, 12.0), (2.6, 6.0), (8.5, 6.4), (11.6, 9.6)]), "leaf")
    c.fill(c.poly([(12.0, 11.0), (14.0, 5.0), (19.0, 2.8), (21.6, 7.0), (18.5, 11.5), (13.0, 13.0)]), "leaf")
    c.line(11.6, 12.4, 5.0, 8.0, 0.8, "green")
    c.line(13.0, 11.2, 19.0, 5.2, 0.8, "green")


def _summer(c: _Canvas) -> None:
    ray = 0.7071
    for (dx, dy) in ((1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0), (ray, ray), (-ray, ray), (ray, -ray), (-ray, -ray)):
        c.fill(c.cap(12.0 + dx * 8.2, 12.0 + dy * 8.2, 12.0 + dx * 10.6, 12.0 + dy * 10.6, 2.3), "amber")
    c.fill(c.circle(12.0, 12.0, 6.2), "gold")
    c.stroke(c.ell(10.0, 9.8, 2.0, 1.2, 0.94, 0.34), "brass_hi", 0.9)


def _autumn(c: _Canvas) -> None:
    leaf = [(4.0, 20.5), (4.8, 13.0), (8.0, 7.6), (14.0, 4.2), (20.0, 3.6), (20.4, 9.0), (17.0, 15.6), (11.0, 19.4)]
    c.fill(c.poly(leaf), "orange")
    c.line(4.0, 20.5, 17.0, 7.0, 1.0, "bark")
    c.line(9.0, 13.6, 7.0, 9.6, 0.8, "bark")
    c.line(12.4, 10.4, 15.6, 13.4, 0.8, "bark")
    c.line(3.0, 22.0, 5.0, 20.0, 1.4, "bark")


def _winter(c: _Canvas) -> None:
    arms = ((1.0, 0.0), (0.5, 0.866), (-0.5, 0.866))
    for (dx, dy) in arms:
        c.fill(c.cap(12.0 - dx * 10.0, 12.0 - dy * 10.0, 12.0 + dx * 10.0, 12.0 + dy * 10.0, 2.0), "salt")
    for (dx, dy) in arms:
        c.line(12.0 - dx * 9.4, 12.0 - dy * 9.4, 12.0 + dx * 9.4, 12.0 + dy * 9.4, 0.7, "sky")
    c.fill(c.circle(12.0, 12.0, 2.2), "white")


def _cloud(c: _Canvas, dx: float, dy: float, colour: str) -> None:
    c.fill(c.rbox(2.4 + dx, 14.0 + dy, 21.6 + dx, 19.6 + dy, 2.8), colour)
    c.fill(c.circle(8.4 + dx, 13.4 + dy, 4.0), colour, ink=True)
    c.fill(c.circle(14.0 + dx, 11.2 + dy, 5.0), colour, ink=True)
    c.fill(c.rbox(4.0 + dx, 14.6 + dy, 20.4 + dx, 18.8 + dy, 2.0), colour, ink=False)


def _weather_good(c: _Canvas) -> None:
    ray = 0.7071
    for (dx, dy) in ((0.0, -1.0), (-1.0, 0.0), (ray, -ray), (-ray, -ray), (1.0, 0.0)):
        c.fill(c.cap(9.0 + dx * 6.4, 8.4 + dy * 6.4, 9.0 + dx * 8.6, 8.4 + dy * 8.6, 2.0), "amber")
    c.fill(c.circle(9.0, 8.4, 5.0), "gold")
    _cloud(c, 1.0, 2.4, "white")


def _weather_poor(c: _Canvas) -> None:
    _cloud(c, 0.0, -3.0, "iron")
    for x in (6.0, 12.0, 18.0):
        c.fill(c.cap(x, 18.4, x - 1.4, 22.0, 1.6), "sky")


# ---------------------------------------------------------------- screens

def _study(c: _Canvas) -> None:
    c.fill(c.poly([(2.0, 6.0), (12.0, 8.6), (22.0, 6.0), (22.0, 19.6), (12.0, 22.0), (2.0, 19.6)]), "brown")
    c.fill(c.poly([(3.6, 5.4), (11.4, 8.0), (11.4, 20.0), (3.6, 17.4)]), "cream", ink=False)
    c.fill(c.poly([(20.4, 5.4), (12.6, 8.0), (12.6, 20.0), (20.4, 17.4)]), "cream", ink=False)
    c.stroke(c.cap(12.0, 8.0, 12.0, 21.6, 1.0), "ink")
    for k in (0.0, 2.6, 5.2):
        c.line(5.2, 8.4 + k, 10.0, 10.0 + k, 0.8, "bark")
        c.line(18.8, 8.4 + k, 14.0, 10.0 + k, 0.8, "bark")


def _log_icon(c: _Canvas) -> None:
    """A ledger: a cream sheet with three ruled lines, a bark roll at each end."""
    c.fill(c.rbox(5.0, 5.0, 19.0, 19.0, 1.0), "cream")
    for y in (9.0, 12.4, 15.8):
        c.line(8.0, y, 16.0, y, 0.9, "bark")
    c.fill(c.rbox(2.0, 3.6, 6.4, 20.4, 1.6), "bark")
    c.fill(c.rbox(17.6, 3.6, 22.0, 20.4, 1.6), "bark")


def _pin(c: _Canvas) -> None:
    c.fill(c.poly([(6.8, 11.0), (17.2, 11.0), (12.0, 22.4)]), "red")
    c.fill(c.circle(12.0, 9.4, 6.8), "red")
    c.fill(c.circle(12.0, 9.2, 2.6), "cream", ink=False)
    c.stroke(c.ring(12.0, 9.2, 2.6, 0.9), "ink")


def _info(c: _Canvas) -> None:
    c.fill(c.circle(12.0, 12.0, 10.0), "blue")
    c.fill(c.circle(12.0, 6.9, 1.7), "cream", ink=False)
    c.stroke(c.box(10.4, 10.0, 13.6, 18.0), "cream")
    c.stroke(c.box(9.2, 17.0, 14.8, 18.6), "cream")
    c.stroke(c.box(9.2, 10.0, 11.6, 11.2), "cream")


def _go(c: _Canvas) -> None:
    c.fill(c.poly([(2.5, 8.2), (12.5, 8.2), (12.5, 3.6), (21.5, 12.0), (12.5, 20.4), (12.5, 15.8), (2.5, 15.8)]), "green")
    c.stroke(c.cap(4.6, 10.0, 11.0, 10.0, 1.0), "leaf")


def _warning(c: _Canvas) -> None:
    c.fill(c.poly([(12.0, 2.4), (22.4, 20.6), (1.6, 20.6)]), "amber")
    c.line(12.0, 9.0, 12.0, 14.4, 2.4)
    c.dot(12.0, 17.6, 1.4)


def _ring(c: _Canvas) -> None:
    c.fill(c.ring(12.0, 12.0, 7.6, 3.4), "gold")
    c.stroke(c.ring(12.0, 12.0, 7.6, 1.0), "brass_hi", 0.9)


def _chart(c: _Canvas) -> None:
    c.fill(c.box(3.6, 13.0, 8.6, 20.0), "blue")
    c.fill(c.box(9.6, 8.0, 14.6, 20.0), "blue")
    c.fill(c.box(15.6, 3.6, 20.6, 20.0), "blue")
    c.line(2.4, 20.8, 22.0, 20.8, 1.4)
    c.line(2.4, 2.4, 2.4, 20.8, 1.4)


def _sold(c: _Canvas) -> None:
    c.fill(c.poly([(2.4, 12.0), (10.8, 3.4), (21.4, 3.4), (21.4, 12.8), (12.6, 21.2)]), "cream")
    c.fill(c.circle(17.0, 7.8, 1.6), "cream", ink=False)
    c.stroke(c.ring(17.0, 7.8, 1.6, 0.9), "ink")
    c.line(8.0, 12.6, 11.0, 15.4, 2.0, "green")
    c.line(11.0, 15.4, 16.0, 11.0, 2.0, "green")


# ---------------------------------------------------------------- later chips

def _food(c: _Canvas) -> None:
    c.fill(c.ell(12.0, 13.4, 9.6, 6.4), "wood")
    for x in (7.2, 12.0, 16.8):
        c.line(x - 1.2, 10.4, x + 1.2, 15.0, 1.5, "cream")
    c.stroke(c.ell(12.0, 13.4, 8.2, 5.0), "ink", 0.0)


def _sword(c: _Canvas, tip: tuple[float, float], pommel: tuple[float, float]) -> None:
    dx = pommel[0] - tip[0]
    dy = pommel[1] - tip[1]
    ln = float(np.sqrt(dx * dx + dy * dy))
    ux, uy = dx / ln, dy / ln
    gx, gy = pommel[0] - 4.4 * ux, pommel[1] - 4.4 * uy
    c.fill(c.cap(tip[0], tip[1], gx, gy, 2.4), "steel")
    c.fill(c.cap(gx - uy * 3.4, gy + ux * 3.4, gx + uy * 3.4, gy - ux * 3.4, 1.8), "gold")
    c.fill(c.cap(gx, gy, pommel[0], pommel[1], 2.0), "brown")


def _army(c: _Canvas) -> None:
    _sword(c, (3.4, 3.4), (20.2, 20.2))
    _sword(c, (20.6, 3.4), (3.8, 20.2))


def _research(c: _Canvas) -> None:
    c.fill(c.poly([(20.6, 2.6), (21.6, 9.0), (17.0, 14.4), (11.0, 16.6), (9.2, 15.0), (11.0, 9.0), (15.4, 4.6)]), "cream")
    c.line(21.0, 2.8, 4.6, 19.4, 1.1, "bark")
    c.line(16.6, 7.8, 12.6, 10.6, 0.8, "bark")
    c.line(14.0, 10.8, 11.8, 12.4, 0.8, "bark")
    c.fill(c.poly([(4.0, 21.4), (5.0, 17.0), (7.4, 19.4)]), "ink", ink=False)
    c.fill(c.rbox(12.0, 18.6, 21.4, 22.4, 1.2), "indigo")


def _prestige(c: _Canvas) -> None:
    c.fill(c.poly([(3.0, 18.5), (2.4, 7.4), (8.0, 12.2), (12.0, 5.0), (16.0, 12.2), (21.6, 7.4), (21.0, 18.5)]), "gold")
    c.fill(c.rbox(3.0, 16.0, 21.0, 20.6, 0.8), "amber")
    for (x, y) in ((2.8, 6.0), (12.0, 3.6), (21.2, 6.0)):
        c.fill(c.circle(x, y, 1.8), "red")
    for x in (8.0, 12.0, 16.0):
        c.dot(x, 18.3, 0.8, "bark")


_DRAW: dict[str, Callable[[_Canvas], None]] = {
    "good_grain": _grain, "good_fish": _fish, "good_oil": _oil, "good_wine": _wine, "good_salt": _salt,
    "good_hemp": _hemp, "good_silk": _silk, "good_dyes": _dyes, "good_wool": _wool, "good_cattle": _cattle,
    "good_horses": _horses, "good_timber": _timber, "good_stone": _stone, "good_iron": _iron,
    "good_copper": _copper, "good_silver": _silver,
    "ducats": _ducats, "stores": _stores, "tax": _tax, "upkeep": _upkeep, "walls": _walls, "port_dues": _port_dues,
    "spending": _spending, "refund": _refund, "payback": _payback,
    "people": _people, "jobs": _jobs, "district": _district, "settlement": _settlement, "castle": _castle,
    "season_spring": _spring, "season_summer": _summer, "season_autumn": _autumn, "season_winter": _winter,
    "weather_good": _weather_good, "weather_poor": _weather_poor,
    "study": _study, "pin": _pin, "info": _info, "go": _go, "warning": _warning, "ring": _ring, "chart": _chart,
    "sold": _sold,
    "food": _food, "army": _army, "research": _research, "prestige": _prestige,
    "log": _log_icon, "barracks": _barracks,
}


def icon_cell(name: str, s: int, tokens: TokenTable) -> np.ndarray:
    """One icon as a (24 s, 24 s, 4) float64 RGBA cell."""
    c = _Canvas(s, tokens)
    _DRAW[name](c)
    return c.out


def cell_origin(name: str) -> tuple[int, int]:
    """Logical (x, y) of an icon's cell in the atlas."""
    i = ICON_NAMES.index(name)
    return (i % COLUMNS) * CELL, (i // COLUMNS) * CELL


def render_icons(s: int, tokens: TokenTable) -> np.ndarray:
    """The `icons` atlas (256 x 128 logical px) as uint8 RGBA."""
    w, h = ATLAS_SIZE
    atlas = np.zeros((h * s, w * s, 4), dtype=np.float64)
    for name in ICON_NAMES:
        x, y = cell_origin(name)
        atlas[y * s : (y + CELL) * s, x * s : (x + CELL) * s] = icon_cell(name, s, tokens)
    return np.floor(np.clip(atlas, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)


def icon_pieces() -> list[PieceSpec]:
    zero = (0, 0, 0, 0)
    return [
        PieceSpec(
            name="icons",
            slice_num=4,
            size=ATLAS_SIZE,
            margin=zero,
            content=zero,
            expand=zero,
            axis="stretch",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=render_icons,
        )
    ]
