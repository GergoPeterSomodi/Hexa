"""The painter for the unit figures (docs/design/recruitment-queue.md 11; option D of docs/design/ui/unit-looks/mockup.html).

The figures are drawn in the mockup's own units (a 64 px box, the ground at y 58) with its calls: a filled shape with an
ink line half the line width outside it (`fill`), a line with an ink edge (`dl`), a flat line with no ink (`ln`), and the
two-tone fill of the mockup's `tt` (lit left of 56 % of the shape's width, shaded right of it). `push` places a part
(translate, then scale), so a man is drawn at his feet and moved into place, as in the mockup's `<g transform>`.

A colour is a fixed `#rrggbb`, or a `Tint`: the country colour mixed toward white (lit) or black (shade) by a share, so
it is `base + scale * c`. Each figure is painted twice, with c black and c white; since every blend is linear in c, the
two give the fixed part and the country's share of every texel, and `split_tint` turns them into two layers that are
exact for any country colour with the usual blending:

- the **tint** layer (drawn first, its white modulated by the country colour): alpha `w / (1 - a + w)`;
- the **figure** layer (drawn over it): alpha `a - w`, colour `fixed / (a - w)`.

where `a` is the texel's alpha and `w` the country's share. Pixel paths use only `+ - x /`, `sqrt`, `floor` and
comparisons on float64 (curves are cut into straight pieces with arithmetic only), as the rest of the baker.
"""
from __future__ import annotations

import re
from contextlib import contextmanager
from dataclasses import dataclass
from typing import Iterator, Union

import numpy as np

from .pieces_m2 import sd_polygon
from .shapes import blend_rgb_mask, coverage, logical_grid, sd_rounded_rect, sd_segment
from .tokens import parse_hex_color

CURVE_STEPS = 12
SPLIT = 0.56  # the mockup's `tt`: the lit part ends at 56 % of the shape's width


def hex_rgb(colour: str) -> np.ndarray:
    return np.asarray(parse_hex_color(colour)[:3], dtype=np.float64)


def mix_hex(a: str, b: str, t: float) -> str:
    """The mockup's `mix`: per channel, rounded to a whole 8-bit value."""
    pa, pb = parse_hex_color(a)[:3], parse_hex_color(b)[:3]
    ch = [int(np.floor((pa[i] * 255.0 + 0.5)) * (1.0 - t) + np.floor(pb[i] * 255.0 + 0.5) * t + 0.5) for i in range(3)]
    return "#%02x%02x%02x" % tuple(ch)


@dataclass(frozen=True)
class Tint:
    """The country colour c mixed toward white by `lift` or toward black by `shade` (one of them 0)."""
    lift: float = 0.0
    shade: float = 0.0

    def base(self) -> float:
        return self.lift

    def scale(self) -> float:
        return (1.0 - self.lift) * (1.0 - self.shade)


COUNTRY = Tint()


@dataclass(frozen=True)
class TwoTone:
    """The mockup's `tt(colour, lit, dark)`: lit left of SPLIT of the shape's width, shaded right of it."""
    colour: Union[str, Tint]
    lit: float = 0.14
    dark: float = 0.24


Paint = Union[str, Tint, TwoTone]


def tt(colour: Union[str, Tint], lit: float = 0.14, dark: float = 0.24) -> TwoTone:
    return TwoTone(colour, lit, dark)


_TOKEN = re.compile(r"[MLCQZ]|-?\d*\.?\d+")


def flatten_path(d: str) -> list[list[tuple[float, float]]]:
    """An SVG path of absolute M, L, C, Q and Z as lists of points (one per subpath), curves cut in CURVE_STEPS."""
    toks = _TOKEN.findall(d)
    out: list[list[tuple[float, float]]] = []
    cur: list[tuple[float, float]] = []
    i = 0
    cmd = "M"
    while i < len(toks):
        if toks[i] in "MLCQZ":
            cmd = toks[i]
            i += 1
            if cmd == "Z":
                if cur:
                    out.append(cur)
                cur = []
            continue
        nums = [float(t) for t in toks[i : i + {"M": 2, "L": 2, "C": 6, "Q": 4}[cmd]]]
        i += len(nums)
        if cmd == "M":
            if cur:
                out.append(cur)
            cur = [(nums[0], nums[1])]
            cmd = "L"
        elif cmd == "L":
            cur.append((nums[0], nums[1]))
        else:
            x0, y0 = cur[-1]
            for k in range(1, CURVE_STEPS + 1):
                t = k / CURVE_STEPS
                u = 1.0 - t
                if cmd == "Q":
                    x = u * u * x0 + 2.0 * u * t * nums[0] + t * t * nums[2]
                    y = u * u * y0 + 2.0 * u * t * nums[1] + t * t * nums[3]
                else:
                    x = u * u * u * x0 + 3.0 * u * u * t * nums[0] + 3.0 * u * t * t * nums[2] + t * t * t * nums[4]
                    y = u * u * u * y0 + 3.0 * u * u * t * nums[1] + 3.0 * u * t * t * nums[3] + t * t * t * nums[5]
                cur.append((x, y))
    if cur:
        out.append(cur)
    return out


class FigurePainter:
    """One cell (w x h logical px at scale s), painted for one country colour `c` (RGB in [0, 1])."""

    def __init__(self, w: int, h: int, s: int, ink: np.ndarray, c: np.ndarray) -> None:
        self.s = s
        self.gx, self.gy = logical_grid(w, h, s)
        self.out = np.zeros((h * s, w * s, 4), dtype=np.float64)
        self.ink = ink
        self.c = np.asarray(c, dtype=np.float64)
        self.ow = 1.6  # the ink line in box units (the mockup's OW): 1.6 full detail, 2.5 simplified
        self._tf = (0.0, 0.0, 1.0)

    # ------------------------------------------------------------ placing
    @contextmanager
    def push(self, tx: float, ty: float, k: float = 1.0) -> Iterator[None]:
        keep = self._tf
        ox, oy, ok = keep
        self._tf = (ox + ok * tx, oy + ok * ty, ok * k)
        try:
            yield
        finally:
            self._tf = keep

    def _local(self) -> tuple[np.ndarray, np.ndarray, float]:
        ox, oy, k = self._tf
        return (self.gx - ox) / k, (self.gy - oy) / k, k

    # ------------------------------------------------------------ shapes (signed distances in cell px)
    def poly(self, pts: list[tuple[float, float]]) -> np.ndarray:
        x, y, k = self._local()
        return sd_polygon(x, y, pts) * k

    def path(self, d: str) -> np.ndarray:
        x, y, k = self._local()
        sub = flatten_path(d)
        sd = sd_polygon(x, y, sub[0])
        for pts in sub[1:]:
            sd = np.minimum(sd, sd_polygon(x, y, pts))
        return sd * k

    def polyline(self, d: str, w: float) -> np.ndarray:
        """An open path as a line `w` wide with round ends."""
        x, y, k = self._local()
        pts = flatten_path(d)[0]
        sd = sd_segment(x, y, pts[0][0], pts[0][1], pts[1][0], pts[1][1])
        for i in range(1, len(pts) - 1):
            sd = np.minimum(sd, sd_segment(x, y, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1]))
        return (sd - 0.5 * w) * k

    def circle(self, cx: float, cy: float, r: float) -> np.ndarray:
        x, y, k = self._local()
        return (np.sqrt((x - cx) ** 2 + (y - cy) ** 2) - r) * k

    def ell(self, cx: float, cy: float, rx: float, ry: float) -> np.ndarray:
        x, y, k = self._local()
        u = (x - cx) / rx
        v = (y - cy) / ry
        k0 = np.sqrt(u * u + v * v)
        k1 = np.sqrt((u / rx) ** 2 + (v / ry) ** 2)
        return np.where(k1 > 1e-9, k0 * (k0 - 1.0) / np.maximum(k1, 1e-9), -min(rx, ry)) * k

    def rect(self, x0: float, y0: float, x1: float, y1: float, r: float) -> np.ndarray:
        x, y, k = self._local()
        return sd_rounded_rect(x, y, 0.5 * (x0 + x1), 0.5 * (y0 + y1), 0.5 * (x1 - x0), 0.5 * (y1 - y0), min(r, 0.5 * (x1 - x0), 0.5 * (y1 - y0))) * k

    def seg(self, x0: float, y0: float, x1: float, y1: float, w: float) -> np.ndarray:
        x, y, k = self._local()
        return (sd_segment(x, y, x0, y0, x1, y1) - 0.5 * w) * k

    # ------------------------------------------------------------ colour
    def _flat(self, colour: Union[str, Tint]) -> np.ndarray:
        if isinstance(colour, Tint):
            return colour.base() + colour.scale() * self.c
        return hex_rgb(colour)

    def _toned(self, colour: Union[str, Tint], t: float, towards_white: bool) -> np.ndarray:
        if isinstance(colour, Tint):
            # Still `base + scale * c`, so the two paintings stay linear in c.
            return self._flat(colour) * (1.0 - t) + (t if towards_white else 0.0)
        return hex_rgb(mix_hex(colour, "#ffffff" if towards_white else "#000000", t))

    def paint_of(self, paint: Paint, sd: np.ndarray) -> np.ndarray:
        if not isinstance(paint, TwoTone):
            return self._flat(paint)
        inside = sd < 0.0
        if not inside.any():
            inside = sd < 0.5 / self.s
        xs = self.gx[inside]
        x0, x1 = float(xs.min()) - 0.5 / self.s, float(xs.max()) + 0.5 / self.s
        cut = x0 + SPLIT * (x1 - x0)
        lit = self._toned(paint.colour, paint.lit, True)
        dark = self._toned(paint.colour, paint.dark, False)
        t = np.clip((cut - self.gx) * self.s + 0.5, 0.0, 1.0)[..., None]
        return lit * t + dark * (1.0 - t)

    # ------------------------------------------------------------ painting
    def fill(self, sd: np.ndarray, paint: Paint, ink: bool = True, ow: float | None = None, alpha: float = 1.0) -> None:
        """A shape with an ink line `ow` wide (box units, centred on its edge, as SVG's stroke under the fill)."""
        k = self._tf[2]
        if ink:
            line = (self.ow if ow is None else ow) * k
            self.out = blend_rgb_mask(self.out, self.ink, coverage(sd - 0.5 * line, self.s), alpha)
        self.out = blend_rgb_mask(self.out, self.paint_of(paint, sd), coverage(sd, self.s), alpha)

    def dl(self, x0: float, y0: float, x1: float, y1: float, w: float, paint: Paint) -> None:
        """The mockup's `dl`: a round-ended line `w` wide with an ink edge."""
        self.fill(self.seg(x0, y0, x1, y1, w), paint)

    def ln(self, x0: float, y0: float, x1: float, y1: float, w: float = 1.3, colour: str = "INK", op: float = 1.0) -> None:
        """The mockup's `ln`: a flat round-ended line, no ink edge ("INK" is the ink token)."""
        sd = self.seg(x0, y0, x1, y1, w)
        rgb = self.ink if colour == "INK" else self._flat(colour)
        self.out = blend_rgb_mask(self.out, rgb, coverage(sd, self.s), op)

    def hl(self, x0: float, y0: float, x1: float, y1: float, w: float = 1.0, colour: str = "#ffffff", op: float = 0.55) -> None:
        self.ln(x0, y0, x1, y1, w, colour, op)

    def dot(self, cx: float, cy: float, r: float, colour: str = "INK") -> None:
        rgb = self.ink if colour == "INK" else self._flat(colour)
        self.out = blend_rgb_mask(self.out, rgb, coverage(self.circle(cx, cy, r), self.s))

    def line_path(self, d: str, w: float, colour: str = "INK", op: float = 1.0) -> None:
        """An open path drawn as a flat line (no ink edge)."""
        rgb = self.ink if colour == "INK" else self._flat(colour)
        self.out = blend_rgb_mask(self.out, rgb, coverage(self.polyline(d, w), self.s), op)

    def cut(self, sd: np.ndarray) -> None:
        """Clears the shape back to transparent (a hole through what is drawn)."""
        keep = 1.0 - coverage(sd, self.s)
        self.out[..., 3] = self.out[..., 3] * keep


def premultiplied(out: np.ndarray) -> np.ndarray:
    p = out.copy()
    p[..., :3] = out[..., :3] * out[..., 3:4]
    return p


def split_tint(black: np.ndarray, white: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """The figure layer and the tint layer (both straight-alpha float RGBA) from the paintings with c black and c white."""
    pb = premultiplied(black)
    pw = premultiplied(white)
    a = np.clip(black[..., 3], 0.0, 1.0)
    w = np.clip(np.mean(pw[..., :3] - pb[..., :3], axis=-1), 0.0, None)
    w = np.minimum(w, a)
    fa = a - w
    fig = np.zeros_like(black)
    safe = np.where(fa > 1e-6, fa, 1.0)[..., None]
    fig[..., :3] = np.where(fa[..., None] > 1e-6, np.clip(pb[..., :3] / safe, 0.0, 1.0), 0.0)
    fig[..., 3] = fa
    denom = 1.0 - a + w
    tint = np.zeros_like(black)
    tint[..., :3] = 1.0
    tint[..., 3] = np.where(denom > 1e-6, w / np.where(denom > 1e-6, denom, 1.0), 0.0)
    tint[..., :3] = np.where(tint[..., 3:4] > 0.0, 1.0, 0.0)
    return fig, tint


def compose_tinted(fig: np.ndarray, tint: np.ndarray, c: np.ndarray) -> np.ndarray:
    """What the game draws: the tint layer modulated by c, the figure layer over it (straight-alpha float RGBA)."""
    under = tint.copy()
    under[..., :3] = tint[..., :3] * np.asarray(c, dtype=np.float64)
    sa = fig[..., 3:4]
    da = under[..., 3:4]
    oa = sa + da * (1.0 - sa)
    out = np.zeros_like(fig)
    safe = np.where(oa > 1e-9, oa, 1.0)
    out[..., :3] = np.where(oa > 1e-9, (fig[..., :3] * sa + under[..., :3] * da * (1.0 - sa)) / safe, 0.0)
    out[..., 3:4] = oa
    return out
