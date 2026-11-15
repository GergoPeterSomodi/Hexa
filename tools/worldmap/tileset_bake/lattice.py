"""The tile grid of the Godot map (docs/architecture/m1-build-spec.md, section 2) and the helpers every tile needs.

The cell is 104 x 102 px: a pointy-top hex of radius 60 px squashed to 85 % (the art's tilt), rows 76.5 px apart, odd
rows half a cell to the right (Godot: hexagon, stacked, horizontal offset axis). Everything here is in px from the
middle of a cell, y down. No pygame, no map.
"""
import math
import random

CELL_W, CELL_H = 104, 102
HALF_W, HALF_H = CELL_W / 2.0, CELL_H / 2.0
ROW = CELL_H * 0.75
TILT = 0.85

# Edge directions as core/hexgrid.gd: 0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE. The middle of the neighbour in each direction.
NEIGHBOUR = [(CELL_W, 0.0), (HALF_W, -ROW), (-HALF_W, -ROW), (-CELL_W, 0.0), (-HALF_W, ROW), (HALF_W, ROW)]
# Corners: 0 top, then anticlockwise (as HexGrid.corners_km): top, upper left, lower left, bottom, lower right, upper right.
CORNER = [(0.0, -HALF_H), (-HALF_W, -HALF_H / 2), (-HALF_W, HALF_H / 2), (0.0, HALF_H), (HALF_W, HALF_H / 2), (HALF_W, -HALF_H / 2)]
# The outward unit normal and offset of each edge's half-plane: a point p is inside the hex when n.p <= d for all six.
_PLANES = []
for _d, (_nx, _ny) in enumerate(NEIGHBOUR):
    _l = math.hypot(_nx, _ny)
    _PLANES.append((_nx / _l, _ny / _l, _l / 2.0))
# The lattice-periodic fields repeat every 3 cells and every 2 rows: 6 lattice positions (the "lattice variant").
PERIOD_X, PERIOD_Y = 3 * CELL_W, 2 * ROW
LATTICE_VARIANTS = 6


def cell_centre(c, r):
    return (CELL_W * (c + 0.5 + 0.5 * (r & 1)), HALF_H + ROW * r)


def lattice_variant(c, r):
    """Which of the 6 lattice positions a cell is: the periodic fields look the same for cells with one variant."""
    return (c % 3) + 3 * (r & 1)


def variant_centre(v):
    return cell_centre(v % 3, v // 3)


def hex_h(x, y):
    """The largest half-plane value of the cell's hex at a point: <= 0 inside, and outside about the distance to it."""
    best = -1e9
    for nx, ny, d in _PLANES:
        v = nx * x + ny * y - d
        if v > best:
            best = v
    return best


def hex_points(grow=0.0):
    k = 1.0 + grow / HALF_W
    return [(x * k, y * k) for x, y in CORNER]


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


class Waves:
    """A smooth 2D field that repeats exactly on the lattice (PERIOD_X, PERIOD_Y): a sum of sines whose wave vectors
    are whole multiples of the lattice's. Two tiles that meet see the same field, so what it bends joins."""

    def __init__(self, seed, terms, amp):
        rnd = random.Random(seed)
        self.t = []
        total = 0.0
        for m, n in terms:
            a = 1.0 / math.hypot(m / 3.0, n / 2.0)
            total += a
            self.t.append((2 * math.pi * m / PERIOD_X, 2 * math.pi * n / PERIOD_Y, rnd.random() * 2 * math.pi, a))
        self.k = amp / total

    def at(self, x, y):
        s = 0.0
        for kx, ky, ph, a in self.t:
            s += a * math.sin(kx * x + ky * y + ph)
        return s * self.k


class ValueNoise:
    """Plain value noise (the style frame's vnoise), for textures that need not join."""

    def __init__(self, seed):
        rnd = random.Random(seed)
        self.lat = [rnd.random() for _ in range(4096)]

    def at(self, x, y, scale):
        x /= scale
        y /= scale
        xi, yi = math.floor(x), math.floor(y)
        fx, fy = x - xi, y - yi
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        lat = self.lat
        a0 = lat[((xi * 73856093) ^ (yi * 19349663)) & 4095]
        a1 = lat[(((xi + 1) * 73856093) ^ (yi * 19349663)) & 4095]
        b0 = lat[((xi * 73856093) ^ ((yi + 1) * 19349663)) & 4095]
        b1 = lat[(((xi + 1) * 73856093) ^ ((yi + 1) * 19349663)) & 4095]
        a = a0 + (a1 - a0) * fx
        b = b0 + (b1 - b0) * fx
        return a + (b - a) * fy


def pixel_hash(x, y):
    return ((x * 73856093) ^ (y * 19349663) ^ (x * y * 83492791)) & 255
