"""Exports the real coast lines of the north Italy map: the style frame's coast, carved ports included.

The style frame (tools/worldmap/style_frame/frame.py, Fields) holds the coast as a land field on a 1 km grid: the hex land
blended and pushed in and out by noise (coves and headlands), a low bulge at every port, the coves of sites.py. The
compositor's carve_ports() then cuts Genoa's bay into that field. The shoreline is the 0.5 contour of that field.

The frame only covers its 345 x 228 km window; this script lets the same field run over the whole region (the frame's
window globals are widened before the style frame is imported, and a ring of hexes round the region repeats the edge
hexes, so the coast leaves the map instead of turning at its border). Nothing of the frame is changed on disk.

Writes godot/data/worldmap/shoreline_alps_po.json: lines in km from the region's north-west corner (the grid of
godot/core/hexgrid.gd), each a list of points; a closed line repeats its first point at the end; an open line begins and
ends on the map's edge. The Godot map build (godot/tools/build_map.gd) reads it into MapData.shoreline.

    python tools/worldmap/export_shoreline.py [--layers <layers.json>] [--out <file>] [--preview <png>]

Needs pygame (the style frame imports it); about two minutes. The layers file is the exported output of core/mapgen that
the style frame reads (STYLE_FRAME_LAYERS); the run is deterministic.
"""
import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
DEFAULT_OUT = os.path.join(REPO, "godot", "data", "worldmap", "shoreline_alps_po.json")
DEFAULT_LAYERS = "C:/hxr/mapproto-shots/art/layers.json"
COLS, ROWS = 21, 19
PAD_HEXES = 3
TOLERANCE_KM = 0.12


def _hex_far(w_km):
    r = w_km / math.sqrt(3.0)
    return w_km * (COLS + 0.5), 2.0 * r + 1.5 * r * (ROWS - 1)


def _widen_frame(FR, GEO):
    """The frame's field over the whole region, and a ring of repeated hexes round it."""
    far_x, far_y = _hex_far(GEO.W_KM)
    FR.X0, FR.Y0 = 0.0, 0.0
    FR.FW_KM, FR.FH_KM = int(far_x) + 9, int(far_y) + 9
    present = dict(GEO.HEX)

    def nearest(c, r):
        r2 = min(max(r, 0), ROWS - 1)
        c_hi = COLS - 1 if r2 & 1 == 0 else COLS - 2
        best = None
        for cc in range(0, c_hi + 1):
            if (cc, r2) in present and (best is None or abs(cc - c) < abs(best - c)):
                best = cc
        return present[(best, r2)]
    for r in range(-PAD_HEXES, ROWS + PAD_HEXES):
        for c in range(-PAD_HEXES, COLS + PAD_HEXES):
            if (c, r) not in present:
                hx = dict(nearest(c, r))
                hx["peak"] = None
                GEO.HEX[(c, r)] = hx


def _contours(F, far_x, far_y):
    """Marching squares at 0.5 over the field, inside [0, far_x] x [0, far_y]: a list of (points, closed)."""
    w, h = F.w, F.h
    land = F.land
    x0, y0 = F.x0, F.y0
    segs = []                                           # ((edge id a), (edge id b)) with the points kept in pts
    def at(i, j):
        return land[j * w + i]

    def cross(i0, j0, i1, j1):
        """The point where the field crosses 0.5 between two neighbouring samples (an id and its position)."""
        return (min((i0, j0), (i1, j1)), max((i0, j0), (i1, j1)))
    for j in range(h - 1):
        if y0 + j + 1 < 0.0 or y0 + j > far_y:
            continue
        for i in range(w - 1):
            if x0 + i + 1 < 0.0 or x0 + i > far_x:
                continue
            v = (at(i, j) > 0.5, at(i + 1, j) > 0.5, at(i + 1, j + 1) > 0.5, at(i, j + 1) > 0.5)
            n = sum(v)
            if n == 0 or n == 4:
                continue
            top, right = cross(i, j, i + 1, j), cross(i + 1, j, i + 1, j + 1)
            bottom, left = cross(i, j + 1, i + 1, j + 1), cross(i, j, i, j + 1)
            if n == 1 or n == 3:
                lone = v.index(n == 1) if n == 1 else v.index(False)
                corner = [(left, top), (top, right), (right, bottom), (bottom, left)][lone]
                segs.append(corner)
            elif v[0] == v[1]:
                segs.append((left, right))
            elif v[0] == v[3]:
                segs.append((top, bottom))
            else:                                       # a saddle: join by the centre value
                centre = (at(i, j) + at(i + 1, j) + at(i + 1, j + 1) + at(i, j + 1)) / 4.0 > 0.5
                if centre == v[0]:
                    segs.extend([(left, bottom), (top, right)])
                else:
                    segs.extend([(left, top), (bottom, right)])
    # chain the segments by their shared crossing ids
    nxt = {}
    for a, b in segs:
        nxt.setdefault(a, []).append(b)
        nxt.setdefault(b, []).append(a)
    seen = set()
    lines = []

    def walk(start):
        line, prev, cur = [start], None, start
        while True:
            options = [q for q in nxt[cur] if q != prev and (min(cur, q), max(cur, q)) not in seen]
            if not options:
                break
            q = options[0]
            seen.add((min(cur, q), max(cur, q)))
            line.append(q)
            prev, cur = cur, q
            if cur == start:
                break
        return line
    ends = [k for k, v in nxt.items() if len(v) == 1]
    for k in sorted(ends):
        if any((min(k, q), max(k, q)) in seen for q in nxt[k]):
            continue
        lines.append((walk(k), False))
    for k in sorted(nxt):
        if any((min(k, q), max(k, q)) not in seen for q in nxt[k]):
            line = walk(k)
            lines.append((line, line[0] == line[-1] and len(line) > 3))
    def point(key):
        (i0, j0), (i1, j1) = key
        a, b = at(i0, j0), at(i1, j1)
        t = (0.5 - a) / (b - a)
        return (x0 + i0 + (i1 - i0) * t, y0 + j0 + (j1 - j0) * t)
    return [([point(k) for k in line], closed) for line, closed in lines if len(line) >= 3]


def _simplify(points, tol):
    """Douglas-Peucker on an open polyline (the ends stay)."""
    if len(points) < 3:
        return points
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        a, b = stack.pop()
        ax, ay = points[a]
        bx, by = points[b]
        dx, dy = bx - ax, by - ay
        norm = math.hypot(dx, dy)
        worst, at = 0.0, -1
        for k in range(a + 1, b):
            px, py = points[k]
            d = math.hypot(px - ax, py - ay) if norm < 1e-9 else abs(dx * (py - ay) - dy * (px - ax)) / norm
            if d > worst:
                worst, at = d, k
        if worst > tol:
            keep[at] = True
            stack.extend([(a, at), (at, b)])
    return [p for p, k in zip(points, keep) if k]


def _clip_line(points, far_x, far_y):
    """The parts of a polyline inside the map rectangle (cut where it crosses the border)."""
    def inside(p):
        return 0.0 <= p[0] <= far_x and 0.0 <= p[1] <= far_y

    def cut(p, q):                                      # the point of the segment p (outside) -> q (inside) on the border
        best = 1.0
        for axis, lo, hi in ((0, 0.0, far_x), (1, 0.0, far_y)):
            for edge in (lo, hi):
                d = q[axis] - p[axis]
                if abs(d) < 1e-12:
                    continue
                t = (edge - p[axis]) / d
                if 0.0 <= t <= 1.0:
                    pt = (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)
                    if -1e-6 <= pt[0] <= far_x + 1e-6 and -1e-6 <= pt[1] <= far_y + 1e-6:
                        best = min(best, t)
        return (p[0] + (q[0] - p[0]) * best, p[1] + (q[1] - p[1]) * best)
    out, run = [], []
    for k, p in enumerate(points):
        if inside(p):
            if not run and k > 0:
                run.append(cut(points[k - 1], p))
            run.append(p)
        elif run:
            run.append(cut(p, points[k - 1]))
            out.append(run)
            run = []
    if run:
        out.append(run)
    return [r for r in out if len(r) >= 2]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--layers", default=os.environ.get("STYLE_FRAME_LAYERS", DEFAULT_LAYERS))
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--preview", default=None, help="write a picture of the shoreline over the hexes")
    a = ap.parse_args(argv)
    os.environ["STYLE_FRAME_LAYERS"] = os.path.abspath(a.layers)
    os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
    os.environ.setdefault("STYLE_FRAME_SLOPES", "0")
    sys.path[:0] = [os.path.join(HERE, "pieces_in_map"), os.path.join(HERE, "pieces"), os.path.join(HERE, "style_frame")]
    import geo as GEO
    import frame as FR
    _widen_frame(FR, GEO)
    import compose as CP                            # builds the frame's world and fields (widened)
    CP.carve_ports()                                # Genoa's bay, cut into the land field
    F = CP.FIELDS
    far_x, far_y = _hex_far(GEO.W_KM)
    lines = []
    for points, closed in _contours(F, far_x, far_y):
        if closed:
            body = _simplify(points[:-1] + [points[0]], TOLERANCE_KM)
            if len(body) >= 4:
                lines.append((body, True))
        else:
            for run in _clip_line(points, far_x, far_y):
                s = _simplify(run, TOLERANCE_KM)
                if len(s) >= 2:
                    lines.append((s, False))
    lines.sort(key=lambda l: (-len(l[0]), l[0][0]))
    doc = {"schema": "hexa-godot/worldmap-shoreline/1",
           "source": "the style frame's land field (tools/worldmap/style_frame/frame.py Fields) with the coves of sites.py and "
                     "the carved ports of compose.carve_ports, contour 0.5, widened to the whole region; "
                     "tools/worldmap/export_shoreline.py",
           "grid": {"hex_w_km": GEO.W_KM, "cols": COLS, "rows": ROWS},
           "lines": [{"closed": c, "pts": [[round(p[0], 2), round(p[1], 2)] for p in pts]} for pts, c in lines]}
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, separators=(",", ":"))
        f.write("\n")
    total = sum(len(pts) for pts, _ in lines)
    print("wrote %s: %d lines, %d points, %d bytes" % (a.out, len(lines), total, os.path.getsize(a.out)))
    if a.preview:
        _preview(a.preview, doc, GEO, far_x, far_y)
    return 0


def _preview(path, doc, GEO, far_x, far_y):
    import pygame
    pygame.init()
    s = 2.0
    surf = pygame.Surface((int(far_x * s), int(far_y * s)))
    surf.fill((66, 130, 178))
    for (c, r), hx in sorted(GEO.HEX.items()):
        if 0 <= c < COLS and 0 <= r < ROWS:
            x, y = GEO.centre(c, r)
            col = (150, 190, 110) if hx.get("land") else (66, 130, 178)
            pygame.draw.polygon(surf, col, [(p[0] * s, p[1] * s) for p in GEO.corners(c, r)])
            pygame.draw.polygon(surf, (90, 90, 90), [(p[0] * s, p[1] * s) for p in GEO.corners(c, r)], 1)
    for line in doc["lines"]:
        pygame.draw.lines(surf, (20, 20, 20), False, [(p[0] * s, p[1] * s) for p in line["pts"]], 2)
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    pygame.image.save(surf, path)
    print("preview", path)


if __name__ == "__main__":
    raise SystemExit(main())
