"""Hex grid maths for a pointy-top, "odd-r" offset layout.

Positions are (col, row) tuples. Odd rows are shifted half a hex to the right,
which matches how the map editor lays out its tiles.
"""
import math

SQRT3 = math.sqrt(3)
HEX_W = 60                      # sprite width in pixels (flat side to flat side)
HEX_H = 70                      # sprite height in pixels
RADIUS = HEX_W / SQRT3          # centre to corner
ROW_H = RADIUS * 1.5            # vertical distance between rows

# (dcol, drow) to the six neighbours, for even rows and for odd rows.
_DIRS = (
    ((+1, 0), (0, -1), (-1, -1), (-1, 0), (-1, +1), (0, +1)),
    ((+1, 0), (+1, -1), (0, -1), (-1, 0), (0, +1), (+1, +1)),
)


def neighbors(pos):
    col, row = pos
    for dc, dr in _DIRS[row & 1]:
        yield col + dc, row + dr


def to_cube(pos):
    col, row = pos
    q = col - (row - (row & 1)) // 2
    return q, row, -q - row


def distance(a, b):
    aq, ar, as_ = to_cube(a)
    bq, br, bs = to_cube(b)
    return max(abs(aq - bq), abs(ar - br), abs(as_ - bs))


def within(pos, radius):
    """All positions within `radius` steps of pos (unbounded grid)."""
    col, row = pos
    for r in range(row - radius, row + radius + 1):
        for c in range(col - radius - 1, col + radius + 2):
            if distance(pos, (c, r)) <= radius:
                yield c, r


def hex_center(pos, origin=(0, 0)):
    col, row = pos
    x = origin[0] + col * HEX_W + (row & 1) * HEX_W / 2 + HEX_W / 2
    y = origin[1] + row * ROW_H + HEX_H / 2
    return x, y


def hex_corners(center, radius=RADIUS):
    cx, cy = center
    return [(cx + radius * math.cos(math.radians(60 * i - 30)),
             cy + radius * math.sin(math.radians(60 * i - 30))) for i in range(6)]


def pixel_to_hex(point, origin=(0, 0)):
    x = point[0] - origin[0] - HEX_W / 2
    y = point[1] - origin[1] - HEX_H / 2
    q = (SQRT3 / 3 * x - y / 3) / RADIUS
    r = (2 / 3 * y) / RADIUS
    # Round fractional cube coordinates to the nearest hex.
    s = -q - r
    rq, rr, rs = round(q), round(r), round(s)
    dq, dr, ds = abs(rq - q), abs(rr - r), abs(rs - s)
    if dq > dr and dq > ds:
        rq = -rr - rs
    elif dr > ds:
        rr = -rq - rs
    col = rq + (rr - (rr & 1)) // 2
    return col, rr
