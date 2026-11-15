"""One town, one hex, drawn inside it: the hex and the site of every settlement of the style frame.

The rule (the owner's, first applied to the close-up of Genoa): every settlement belongs to exactly one hex of the
map, and its picture and name plate are drawn inside that hex, clear of the border. This module
  - resolves the hex of every town from the map data (resolve_hexes) and lists where the data disagree (DATA_NOTES);
  - finds the site of every town: the point nearest to its real position at which the picture and the plate fit in
    the hex (place_sites); a port stands on its own hex's shore;
  - cuts the harbour coves (COVES) that give a port hex a shore of its own, at most COAST_REACH_KM from the coast;
  - holds the lines the frame shares with the close-up of Genoa (SHARED_SITES, COVES, the ROAD_* lines): they are the
    close-up's authored positions (tools/worldmap/closeup_2d/closeup.py, stages.py) in km, so both zooms agree.
The check that every drawn settlement lies inside its hex is Frame.check_sites in render.py.
"""
import math
from geo import *

MARGIN_KM = 0.5          # the picture and the plate keep this far from the hex border (at the close zoom)
COAST_REACH_KM = 3.5     # a cove moves the shore at most this far from the frame's first line
BORDER_KM = 1.5          # a town this near a hex border may go to the hex the exported layers give it
APOTHEM = W_KM / 2.0


def hex_margin_km(x, y, hx):
    """How far (km) a point lies inside hex hx; negative when outside."""
    cx, cy = centre(*hx)
    dx, dy = abs(x - cx), abs(y - cy)
    return APOTHEM - max(dx, dx * 0.5 + dy * 0.8660254)


# ---------------------------------------------------------------- which hex
# Towns that the frame adds and the region file does not have (villages with a role): their hex is the hex of their
# coordinates.
NOT_IN_DATA = ("Serravalle", "Chiavari")
DATA_NOTES = []


def resolve_hexes(towns):
    """towns: dicts with name, real (x, y in km). Sets t["hex"] and t["hex_from"]; fills DATA_NOTES.

    The hex of a town is the hex its real coordinates fall in (the region file). The exported layers snap every town
    to the best-scoring hex within one hex, which moves many of them; the layers hex is taken only for a town that
    lies within BORDER_KM of the border it was moved across.
    """
    del DATA_NOTES[:]
    lay = {p["name"]: (p["x"], p["y"]) for p in L["places"] if p["name"]}
    reg = {p["name"] for p in R["places"]}
    for t in towns:
        real = hex_of_km(*t["real"])
        lh = lay.get(t["name"])
        t["hex"], t["hex_from"] = real, "coordinates"
        if t["name"] not in reg:
            DATA_NOTES.append("%s is not in the region file (a village the frame adds); hex %s from its coordinates" % (t["name"], real))
        if lh is None:
            if t["name"] in reg:
                DATA_NOTES.append("%s is missing from the exported layers; hex %s from its coordinates" % (t["name"], real))
        elif lh != real:
            edge = hex_margin_km(t["real"][0], t["real"][1], real)
            if edge <= BORDER_KM and lh in nbrs(*real) and hex_margin_km(t["real"][0], t["real"][1], lh) >= -BORDER_KM:
                t["hex"], t["hex_from"] = lh, "layers (the town lies %.1f km from the border)" % edge
                DATA_NOTES.append("%s: coordinates give hex %s, the layers %s; the layers hex is used (the town lies %.1f km "
                                  "from their border)" % (t["name"], real, lh, edge))
            else:
                DATA_NOTES.append("%s: the layers put it on hex %s, its coordinates lie in %s (%.1f km inside); the "
                                  "coordinates are used, the layers hex is wrong" % (t["name"], lh, real, edge))
        hx = HEX.get(t["hex"])
        if not hx or not hx.get("land"):
            DATA_NOTES.append("%s: hex %s is not land" % (t["name"], t["hex"]))
        elif hx["level"] >= 5:
            DATA_NOTES.append("%s: its hex %s is high mountain in the data (level %d, %d m)" % (t["name"], t["hex"], hx["level"], hx.get("m", 0)))
        if t["port"] and not any(n in HEX and not HEX[n].get("land") for n in nbrs(*t["hex"])):
            DATA_NOTES.append("%s is a port but hex %s has no sea neighbour" % (t["name"], t["hex"]))
    seen = {}
    for t in towns:
        if t["hex"] in seen:
            DATA_NOTES.append("%s and %s share hex %s" % (seen[t["hex"]], t["name"], t["hex"]))
        seen[t["hex"]] = t["name"]
    for t in towns:
        for o in towns:
            if o["rank"] > t["rank"] and t["rank"] >= 2 and o["hex"] in nbrs(*t["hex"]):
                DATA_NOTES.append("%s stands in a hex next to the bigger %s (rule 5 would drop it)" % (t["name"], o["name"]))
    return DATA_NOTES


# ---------------------------------------------------------------- shared with the close-up of Genoa (km)
# The close-up's town sites: Genoa's quay front, the centres of Savona and Chiavari.
SHARED_SITES = {"Genoa": (252.3, 339.9), "Savona": (230.14, 339.44), "Chiavari": (279.99, 341.98)}
GIOVI_AT = (260.89, 306.08)      # where the road crosses the saddle, in hex 9,12
JUNCTION = (250.85, 330.49)      # the centre of Genoa's hex, behind the north gate: the roads meet here
# Harbour coves and points: ("sea" or "land", x, y, rx, ry). The same ellipses as the close-up's COAST_MODS.
COVES = [
    ("sea", 252.0, 343.56, 5.557, 2.536),      # Genoa's basin
    ("land", 245.94, 342.45, 1.078, 0.792),    # the lighthouse rock, root of the new mole
    ("land", 258.13, 342.38, 1.347, 0.792),    # the old-town point, root of the old mole
    ("sea", 230.31, 345.94, 2.829, 3.091),     # Savona's cove
    ("sea", 279.99, 345.78, 2.762, 1.585),     # Chiavari's cove
    ("sea", 140.2, 407.6, 2.9, 2.7),           # Nice: the bay comes into the east side of its hex
]
ROAD_WEST = [(231.86, 338.89), (233.68, 336.91), (235.56, 334.25), (240.11, 329.85), (243.78, 328.71), (246.24, 328.55),
             (248.83, 329.38), (250.85, 330.49)]
ROAD_EAST = [(250.85, 330.49), (252.94, 330.25), (255.91, 330.33), (258.6, 332.07), (260.96, 334.05), (263.62, 335.72),
             (266.35, 335.05), (269.34, 333.5), (274.06, 329.34), (277.46, 329.22), (280.12, 330.41), (284.2, 330.49),
             (289.25, 330.96), (294.0, 331.4), (299.69, 331.6), (310.47, 331.48)]
EAST_END = (280.12, 330.41)      # the map's coast road ends at the centre of Chiavari's hex (the close-up's lane goes on)
ROAD_GIOVI = [(250.85, 330.49), (252.71, 328.11), (255.23, 326.13), (258.6, 323.36), (261.63, 320.19), (262.81, 314.64),
              (261.7, 309.09), (260.89, 306.08), (260.02, 301.56)]
ROAD_SPUR = [(280.12, 330.41), (280.96, 334.45), (280.56, 338.41), (280.02, 340.87)]
ROAD_GATE = [(250.85, 330.49), (250.72, 332.39), (250.38, 334.13)]


def apply_coves(F, coves=COVES):
    """Cuts the coves into the frame's land field (F.land0 keeps the first line). Returns the largest shift in km."""
    for j in range(F.h):
        for i in range(F.w):
            x, y = F.x0 + i, F.y0 + j
            k = j * F.w + i
            v = F.land[k]
            for kind, hx, hy, rx, ry in coves:
                if abs(x - hx) > rx * 2.5 or abs(y - hy) > ry * 2.5:
                    continue
                d = math.hypot((x - hx) / rx, (y - hy) / ry)
                if d < 2.5:
                    v = min(v, 0.5 + (d - 1) * 0.6) if kind == "sea" else max(v, 0.5 + (1 - d) * 0.6)
            F.land[k] = v
    return coast_shift(F)


def coast_shift(F):
    """The largest distance (km) from a point where land and sea changed to the frame's first coast line."""
    worst = 0.0
    for j in range(1, F.h - 1):
        for i in range(1, F.w - 1):
            k = j * F.w + i
            if (F.land[k] > 0.5) == (F.land0[k] > 0.5):
                continue
            x, y = F.x0 + i, F.y0 + j
            was = F.land0[k] > 0.5
            d, found = 0.0, False
            while d < 12 and not found:
                d += 0.25
                for a in range(0, 360, 15):
                    if (F.at(F.land0, x + math.cos(math.radians(a)) * d, y + math.sin(math.radians(a)) * d) > 0.5) != was:
                        found = True
                        break
            worst = max(worst, d)
    return worst


# ---------------------------------------------------------------- where in the hex
_FONTS = {}


def plate_size(t, k, mid):
    """The size in px of a town's name plate at a zoom (k = hex radius / 60), and its font and paddings."""
    import pygame
    size = int(max(9, {3: 16, 2: 13.5, 1: 11.5}[t["rank"]] * (k if not mid else 0.72)))
    f = _FONTS.get(size)
    if f is None:
        f = _FONTS[size] = pygame.font.SysFont("segoeui", size, bold=True)
    tw, th = f.size(t["name"])
    pad_x, pad_y = (7 if t["rank"] == 3 else 5) * max(k, 0.6), 1.5 * max(k, 0.6)
    return (tw + pad_x * 2, th + pad_y * 2 - 2, f)


def plate_side(sea_angle):
    """Where a port's plate goes: on the land side, away from the sea (the angle of the sea in degrees, 90 = south)."""
    a = sea_angle % 360
    if 45 <= a <= 135:
        return "above"
    if 225 <= a <= 315:
        return "below"
    return "left" if a < 45 or a > 315 else "right"


def outline(t, tilt, mid=False, side="above", plate=True):
    """The room a town needs round its site at one zoom: the outer points of its picture (wall, roofs, landmark) and
    the corners of its plate, as offsets in km. The numbers follow Frame.towns in render.py; the check there measures
    the real pixels."""
    rank = t["rank"]
    if mid and rank == 1:
        return []
    kz = 0.5 if mid else 1.0
    k = kz * (1.6 if mid else 1.0)
    rx = {3: 26, 2: 15.5, 1: 8}[rank] * k * t.get("scale", 1.0) * (0.5 if mid else 1.0)
    ry = rx * tilt * 0.62
    roof = 11.5 * k                                         # a house stands this high above its foot
    spire = {3: 23, 2: 19, 1: 12}[rank] * k                 # the landmark, at the middle of the town
    pw, ph, _ = plate_size(t, kz, mid)
    pw /= 2.0
    walled = rank >= 2 and not mid
    pts = [(-5 * k, -spire), (5 * k, -spire)]
    if t["port"] and rank == 3:
        wide = 1.45 * rx
        for u in (-1.0, -0.5, 0.0, 0.5, 1.0):
            top = -1.7 * ry * (1 - 0.4 * abs(u))
            pts += [(u * wide - 4.5 * k, top - roof), (u * wide + 4.5 * k, top - roof)]
        pts += [(-wide - 4.5 * k, 0.3 * ry + 2 * k), (wide + 4.5 * k, 0.3 * ry + 2 * k)]
        top = -1.7 * ry - roof
    else:
        for q in range(0, 360, 15):
            ca, sa = math.cos(math.radians(q)), math.sin(math.radians(q))
            pts.append(((rx + 3.5 * k) * ca, (ry + 3 * k) * sa))                   # the wall
            hx, hy = rx * 0.92 * ca, ry * 0.92 * sa                                 # a house on the rim
            pts += [(hx - 5 * k, hy - roof), (hx + 5 * k, hy - roof), (hx - 5 * k, hy), (hx + 5 * k, hy)]
        wide = rx + 4 * k
        top = -ry * 0.92 - roof
    if plate:
        if t["port"]:
            x0, y0, x1, y1 = port_plate(side, wide, min(top, -spire), ry, pw, ph, k)
        else:
            gap = (6 if walled else 4) * k
            x0, y0, x1, y1 = (-pw, ry + gap, pw, ry + gap + ph)
        x0, y0, x1, y1 = x0 - 1, y0 - 1, x1 + 1, y1 + 1          # the plate is drawn on whole pixels
        pts += [(x0, y0), (x1, y0), (x0, y1), (x1, y1)]
    sx = 60.0 * kz / R_KM
    return [(x / sx, y / (sx * tilt)) for x, y in pts]


def port_plate(side, wide, top, ry, pw, ph, k):
    """A port's plate box in px round the site: above the roofs, below the quay, or beside the town."""
    if side == "above":
        return (-pw, top - 3 * k - ph, pw, top - 3 * k)
    if side == "below":
        return (-pw, ry + 6 * k, pw, ry + 6 * k + ph)
    mid_y = (top + ry) / 2.0
    if side == "left":
        return (-wide - 3 * k - 2 * pw, mid_y - ph / 2.0, -wide - 3 * k, mid_y + ph / 2.0)
    return (wide + 3 * k, mid_y - ph / 2.0, wide + 3 * k + 2 * pw, mid_y + ph / 2.0)


def fit(x, y, hx, pts):
    """The smallest distance (km) from the outline at site (x, y) to the border of hex hx; negative when it crosses."""
    return min(hex_margin_km(x + px, y + py, hx) for px, py in pts)


def place_sites(world, F, tilt):
    """Sets x, y of every town: the point nearest to its real position where it fits in its hex at both zooms.
    A port also needs a shore of its own hex within reach; its plate goes on the land side (t["plate_side"])."""
    need = MARGIN_KM + 0.25

    def room_at(t, x, y, mid_plate=False):
        side = "above"
        if t["port"]:
            sh = shore_room(F, x, y, t["hex"])
            if sh is None:
                return None, side
            side = plate_side(sh[1])
        elif not F.is_land(x, y, 0.2):
            return None, side
        # The plate must fit at the close zoom. At the middle zoom the picture must, and the plate where it can: a
        # readable plate is often wider than a hex there (the check lists those that hang over).
        close = fit(x, y, t["hex"], outline(t, tilt, False, side))
        middle = outline(t, tilt, True, side, plate=mid_plate)
        return (min(close, fit(x, y, t["hex"], middle) - 0.7) if middle else close), side

    for t in world["towns"].values():
        hx = t["hex"]
        cx, cy = centre(*hx)
        if t["name"] in SHARED_SITES:
            t["x"], t["y"] = SHARED_SITES[t["name"]]
        else:
            best = None
            step = 0.25
            n = int(R_KM / step) + 1
            for j in range(-n, n + 1):
                for i in range(-n, n + 1):
                    x, y = cx + i * step, cy + j * step
                    if hex_margin_km(x, y, hx) < 1.0:
                        continue
                    room, side = room_at(t, x, y)
                    if room is None:
                        continue
                    d = math.hypot(x - t["real"][0], y - t["real"][1])
                    if room < need:
                        key = (2, -room)
                    elif room_at(t, x, y, True)[0] >= need:
                        key = (0, d)            # everything fits, the middle zoom's plate too
                    else:
                        key = (1, d)
                    if best is None or key < best[0]:
                        best = (key, x, y)
            if best is None:
                best = (None, cx, cy)
            t["x"], t["y"] = best[1], best[2]
        room, t["plate_side"] = room_at(t, t["x"], t["y"])
        t["fit_km"] = -9.0 if room is None else room
        t["moved_km"] = math.hypot(t["x"] - t["real"][0], t["y"] - t["real"][1])
    for p in world["passes"].values():
        p["hex"] = hex_of_km(p["x"], p["y"])


def shore_room(F, x, y, hx):
    """For a port at (x, y): the nearest shore point of its own hex, as (distance, angle in degrees), or None."""
    if not F.is_land(x, y, 0.06):
        return None
    best = None
    for a in range(0, 360, 10):
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        d = 0.4
        while d <= 4.6:
            px, py = x + ca * d, y + sa * d
            if not F.is_land(px, py, -0.05):
                if hex_margin_km(px, py, hx) >= MARGIN_KM * 0.5 and (best is None or d < best[0]):
                    best = (d, a)
                break
            d += 0.2
    return best
