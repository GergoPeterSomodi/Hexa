"""Drawing primitives the art modules share (goodsart, wfctiles, landmarks, life, nature, goodsobjects).

Everything is drawn at K x (2x) on a 240 x 280 canvas for a 120 x 140 tile and scaled down at the end, in tile
coordinates: `Pen` scales them, `Canvas` is a ground layer plus an object layer that `stamp` commits with a dark ink
outline (the Kenney look), `shadow_at` blits a soft ground shadow, `hex_mask` is the hex the tile is cut to. The
functions are exactly what the modules had drawn before (tests/test_sprite_hashes.py proves the pixels are equal).
Nothing here runs at import time.
"""
import math

import pygame

from ..art import hex_pts
from .cache import BoundedCache

W, H = 120, 140
CX, CY = W / 2, H / 2
R = 69.3                                  # centre to corner of a tile's hex
K = 2                                     # supersampling factor
INK = (45, 45, 50)
OFFS = [(-3, 0), (3, 0), (0, -3), (0, 3), (-2, -2), (2, -2), (-2, 2), (2, 2)]           # the outline's offsets
OFFS_THIN = [(-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, -1), (-1, 1), (1, 1)]


def _w(w):
    return 0 if not w else max(1, round(w * K))


class Pen:
    """Draws in tile coordinates on a K x surface."""

    def __init__(self, surf):
        self.s = surf

    def poly(self, c, pts, w=0):
        if len(pts) > 2:
            pygame.draw.polygon(self.s, c, [(x * K, y * K) for x, y in pts], _w(w))

    def circle(self, c, xy, r, w=0):
        pygame.draw.circle(self.s, c, (xy[0] * K, xy[1] * K), max(0.5, r * K), _w(w))

    def ellipse(self, c, x, y, w, h, wd=0):
        pygame.draw.ellipse(self.s, c, pygame.Rect(round(x * K), round(y * K), max(1, round(w * K)),
                                                   max(1, round(h * K))), _w(wd))

    def oval(self, c, cx, cy, rx, ry, wd=0):
        self.ellipse(c, cx - rx, cy - ry, rx * 2, ry * 2, wd)

    def line(self, c, a, b, w=1):
        pygame.draw.line(self.s, c, (a[0] * K, a[1] * K), (b[0] * K, b[1] * K), max(1, round(w * K)))

    def lines(self, c, pts, w=1, closed=False):
        if len(pts) > 1:
            pygame.draw.lines(self.s, c, closed, [(x * K, y * K) for x, y in pts], max(1, round(w * K)))

    def band(self, c, pts, w):
        """A thick polyline with round joints (rivers, tracks, walls)."""
        self.lines(c, pts, w)
        for x, y in pts:
            self.circle(c, (x, y), w / 2 - 0.25)

    def rect(self, c, x, y, w, h, wd=0, br=0):
        pygame.draw.rect(self.s, c, pygame.Rect(round(x * K), round(y * K), max(1, round(w * K)),
                                                max(1, round(h * K))), _w(wd), round(br * K))


def ell(cx, cy, rx, ry, a0=0, a1=360, n=36):
    """Points on an ellipse from angle a0 to a1 (degrees; 0 = right, 90 = down)."""
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def mix(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def in_poly(x, y, poly, eps=0.0):
    """Is (x, y) inside the polygon (even-odd)? eps keeps a division off zero; callers keep the one they had."""
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + eps) + xi:
            inside = not inside
        j = i
    return inside


@BoundedCache("draw.hex_masks", 8).memo
def _hex_mask(r, k):
    m = pygame.Surface((W * k, H * k), pygame.SRCALPHA)
    pygame.draw.polygon(m, (255, 255, 255, 255), [(x * k, y * k) for x, y in hex_pts(r)])
    return m


def hex_mask(r=R - 0.3, k=K):
    """The hex of radius r at k x as a white SRCALPHA surface: blit it with BLEND_RGBA_MIN to cut a tile to the hex.
    Shared and cached: do not draw on it."""
    return _hex_mask(r, k)


@BoundedCache("draw.shadows", 256).memo
def _shadow(w, h, a):
    sh = pygame.Surface((w, h), pygame.SRCALPHA)
    pygame.draw.ellipse(sh, (0, 0, 0, a), sh.get_rect())
    return sh


def shadow_at(surf, x, y, w, h=None, a=45):
    """A soft ground shadow w wide centred at (x, y) on a K x surface; returns the Rect it covers (not clipped to the
    surface)."""
    h = h or w * 0.35
    sh = _shadow(max(1, int(w * K)), max(1, int(h * K)), a)
    pos = (round((x - w / 2) * K), round((y - h / 2) * K))
    surf.blit(sh, pos)
    return sh.get_rect(topleft=pos)


class Canvas:
    """A 120 x 140 tile at K x: ground layer `surf` with pen `g`, object layer `layer` with pen `o` (stamp commits it
    with a dark outline), cut to the hex and scaled down by finish()."""

    def __init__(self):
        self.surf = pygame.Surface((W * K, H * K), pygame.SRCALPHA)
        self.layer = pygame.Surface((W * K, H * K), pygame.SRCALPHA)
        self.g = Pen(self.surf)
        self.o = Pen(self.layer)

    def shadow(self, x, y, w, h=None, a=45):
        shadow_at(self.surf, x, y, w, h, a)

    def stamp(self, ink=2):
        """Commit the object layer with a dark outline around its silhouette (the Kenney ink look)."""
        r = self.layer.get_bounding_rect(1)
        if not r.w:
            return
        r = r.inflate(8, 8).clip(self.layer.get_rect())
        sub = self.layer.subsurface(r)
        if ink:
            sil = pygame.mask.from_surface(sub, 40).to_surface(setcolor=INK + (255,), unsetcolor=(0, 0, 0, 0))
            for dx, dy in (OFFS if ink >= 2 else OFFS_THIN):
                self.surf.blit(sil, (r.x + dx, r.y + dy))
        self.surf.blit(sub, r.topleft)
        self.layer.fill((0, 0, 0, 0), r)

    def finish(self):
        self.surf.blit(hex_mask(), (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
        out = pygame.transform.smoothscale(self.surf, (W, H))
        return out.convert_alpha() if pygame.display.get_surface() else out
