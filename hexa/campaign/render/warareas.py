"""The war-stack map layer (castle-areas.md section 4, the one map layer of the first version).

While a war stack of the player is selected, the held land of every country at war with the player gets a thin dashed
ink line in the owner's colour, pulled a little inside the hex edge, and a light tint (about 12 %) inside. Only held land
is outlined: a fallen castle's land and open land have no line. Drawn by ``MapView.draw`` after the reach and the stops and
before the units and the names. With no war stack selected nothing is computed or drawn.

The geometry is worked out once per (world.version, zoom radius, viewer, selection, what the player knows) and kept: the
dashes and the tint centres in world coordinates (``MapView.center``). A frame only moves them by the camera offset and
draws the dashes that are in view. The areas come from ``world.area_state``; this module draws and never changes the game.
"""
import math

import pygame

from ...hexgrid import neighbors

INK = (12, 14, 18)
TINT_ALPHA = 31                     # about 12 % of the owner's colour
_CORNERS = [(math.cos(math.radians(60 * i - 30)), math.sin(math.radians(60 * i - 30))) for i in range(6)]


class WarAreas:
    """The held areas of the enemies at war with the viewer, drawn over the map of one MapView."""

    def __init__(self):
        self._key = None
        self._tints = []            # [(rgba, x, y)] world coordinates, one per held hex
        self._dashes = []           # [(colour, [(x, y), ...], (x0, y0, x1, y1))] world coordinates, the dashes of the edges

    def draw(self, screen, view_rect, offset, ui, world, r, centre, known, tint):
        """Draw the layer for the stack selected in ``ui``. ``offset`` is the camera's (x, y) shift of world coordinates,
        ``centre`` the hex centre function of the view, ``tint`` its translucent-hex painter."""
        viewer = world.player
        group = [u for u in getattr(ui, "group", ()) if u in world.units]
        if not viewer or not group or group[0].owner != viewer or not any(u.kind.war for u in group):
            return
        key = (world.version, world.turn, r, viewer, tuple(u.id for u in group), len(known))
        if key != self._key:
            self._key = key
            self._build(world, viewer, r, centre, known)
        ox, oy = offset
        if self._tints:
            tint(screen, [(rgba, x + ox, y + oy) for rgba, x, y in self._tints])
        left, top, right, bottom = view_rect.x, view_rect.y, view_rect.right, view_rect.bottom
        visible = []
        for colour, pts, (x0, y0, x1, y1) in self._dashes:
            if x1 + ox < left or x0 + ox > right or y1 + oy < top or y0 + oy > bottom:
                continue
            visible.append((colour, [(x + ox, y + oy) for x, y in pts]))
        wide, thin = (5, 3) if r >= 20 else (4, 2)
        for _, pts in visible:                      # the ink under every dash, then the owner's colour on top
            pygame.draw.lines(screen, INK, False, pts, wide)
        for colour, pts in visible:
            pygame.draw.lines(screen, colour, False, pts, thin)

    def _build(self, world, viewer, r, centre, known):
        self._tints, self._dashes = [], []
        inset = max(2.0, 0.1 * r)
        for owner, cells in _held_areas(world, viewer, known):
            colour = world.countries[owner].color
            for pos in cells:
                x, y = centre(pos)
                self._tints.append(((*colour, TINT_ALPHA), x, y))
            for loop in _outline(cells, centre, r, inset):
                for seg in _dashes(loop, r):
                    xs, ys = [p[0] for p in seg], [p[1] for p in seg]
                    self._dashes.append((colour, seg, (min(xs), min(ys), max(xs), max(ys))))


def _held_areas(world, viewer, known):
    """[(owner, [held hex, ...])] for each standing castle of a country at war with the viewer: the castle's held land
    the player knows (the castle's own hex when it stands), in the area's order."""
    out = []
    for castle in world.castles():
        if castle.owner == viewer or castle.controller != castle.owner or not world.at_war(viewer, castle.owner):
            continue
        cells = [pos for pos in world.area(castle.pos)
                 if pos in known and world.area_state(pos)["state"] in ("held", "castle")]
        if cells:
            out.append((castle.owner, cells))
    return out


def _outline(cells, centre, r, inset):
    """The outer edges of `cells` as closed loops of world points, each edge pulled `inset` px towards its own hex centre
    so that it never sits on the border. Edges are chained by their corners, each loop in one direction."""
    cset = set(cells)
    starts = {}                                     # corner key -> [(end corner key, a, b), ...]
    k = inset / r
    for pos in cells:
        cx, cy = centre(pos)
        pts = [(cx + r * c, cy + r * s) for c, s in _CORNERS]
        for n in neighbors(pos):
            if n in cset:
                continue
            nx, ny = centre(n)
            i, j = sorted(sorted(range(6), key=lambda q: (pts[q][0] - nx) ** 2 + (pts[q][1] - ny) ** 2)[:2])
            if (i, j) == (0, 5):
                i, j = 5, 0                         # keep the corners in ring order
            a = (pts[i][0] + (cx - pts[i][0]) * k, pts[i][1] + (cy - pts[i][1]) * k)
            b = (pts[j][0] + (cx - pts[j][0]) * k, pts[j][1] + (cy - pts[j][1]) * k)
            starts.setdefault(_key(pts[i]), []).append((_key(pts[j]), a, b))
    loops = []
    while starts:
        key, loop = next(iter(starts)), []
        while key in starts:
            end, a, b = starts[key].pop()
            if not starts[key]:
                del starts[key]
            loop += [a, b]
            key = end
        if loop:
            loops.append(loop)
    return loops


def _key(point):
    return (round(point[0], 2), round(point[1], 2))


def _dashes(loop, r):
    """The dashes of one closed loop: runs of points, a dash then a gap, around the loop. Lengths scale with the radius."""
    dash, gap = max(4.0, 0.42 * r), max(3.0, 0.26 * r)
    pts = loop + loop[:1]
    segs, cur, on, left = [], [], True, dash
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        length = math.hypot(x1 - x0, y1 - y0)
        t = 0.0
        while length > 0 and t < length:
            step = min(left, length - t)
            p0 = (x0 + (x1 - x0) * t / length, y0 + (y1 - y0) * t / length)
            p1 = (x0 + (x1 - x0) * (t + step) / length, y0 + (y1 - y0) * (t + step) / length)
            if on:
                cur += [p0, p1] if not cur else [p1]
            t += step
            left -= step
            if left <= 1e-6:
                if on and cur:
                    segs.append(cur)
                cur = []
                on = not on
                left = dash if on else gap
    if cur:
        segs.append(cur)
    return [seg for seg in segs if len(seg) > 1]
