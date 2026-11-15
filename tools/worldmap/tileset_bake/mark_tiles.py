"""Crossing tiles: the fords, bridges, ferries and pass marks on an edge of the map (spec section 3.3, `mark/<kind>/<d>`).

A crossing stands on the edge between two hexes, where a road meets water or a saddle. Its tile belongs to one of the two
hexes (the one that owns the edge: directions 0 E, 1 NE, 2 NW; all six are baked so a scene may pick either side) and is
drawn in a picture of the usual mark size (flat_tiles.G_W x G_H) with its middle at the middle of that hex: the sprite
itself lies on the middle of the edge in direction `d`, turned along the road (the line between the two hex middles).
The look is the style frame's (tools/worldmap/style_frame/render.py `draw_bridge`, `draw_pass`): flat fills, two tones,
a 1 px ink outline, light from the upper left. The pictures are the same in every set (they go into the shared marks
atlas); nothing here reads a map.

`y_sort` is the edge's height below the middle of the hex, so a crossing stands among the trees and pieces where it is.
"""
import math

import pygame

import lattice as LT
from flat_tiles import G_W, G_H
from tile_atlas import blank

INK = (52, 44, 46)
KINDS = ("ford", "bridge_wood", "bridge_stone", "ferry", "pass")      # MapData.crossing 1 to 5
DIRECTIONS = 6


def tile_name(kind, d):
    return "mark/%s/%d" % (kind, d)


def all_names():
    return [tile_name(k, d) for k in KINDS for d in range(DIRECTIONS)]


def edge_middle(d):
    """px from the middle of the hex to the middle of its edge in direction d."""
    nx, ny = LT.NEIGHBOUR[d]
    return nx / 2.0, ny / 2.0


def y_sort(name):
    """Depth of a mark tile: a crossing's foot is on its edge (a point below the middle of the hex); the others 0."""
    if not name.startswith("mark/") or name.split("/")[1] not in KINDS:
        return 0
    return int(round(edge_middle(int(name.split("/")[2]))[1])) + 1


def crossing_tile(kind, d):
    """One crossing tile (G_W x G_H, straight alpha), the sprite on the middle of the edge in direction d."""
    surf = blank((G_W, G_H))
    ex, ey = edge_middle(d)
    x, y = G_W / 2.0 + ex, G_H / 2.0 + ey
    nx, ny = LT.NEIGHBOUR[d]
    ang = math.atan2(ny, nx)
    if kind == "bridge_stone":
        _bridge(surf, x, y, ang, 9.0, stone=True)
    elif kind == "bridge_wood":
        _bridge(surf, x, y, ang, 7.5, stone=False)
    elif kind == "ford":
        _ford(surf, x, y, ang)
    elif kind == "ferry":
        _ferry(surf, x, y, ang)
    elif kind == "pass":
        _pass(surf, x, y)
    else:
        raise ValueError(kind)
    return surf


def all_tiles():
    """[(name, surface, y_sort)] for every crossing tile."""
    return [(tile_name(k, d), crossing_tile(k, d), y_sort(tile_name(k, d))) for k in KINDS for d in range(DIRECTIONS)]


# ---------------------------------------------------------------- drawing
def _frame(ang):
    """(along, across) unit vectors; across points down the screen (towards the viewer) so the near wall is always below."""
    ca, sa = math.cos(ang), math.sin(ang)
    nx, ny = -sa, ca
    if ny < 0 or (abs(ny) < 1e-6 and nx < 0):
        nx, ny = -nx, -ny
    return (ca, sa), (nx, ny)


def _poly(surf, col, pts, ink=True):
    pygame.draw.polygon(surf, col, pts)
    if ink:
        pygame.draw.polygon(surf, INK, pts, 1)


def _bridge(surf, x, y, ang, span, stone):
    (ca, sa), (nx, ny) = _frame(ang)
    hw = 2.1
    a = (x - ca * span, y - sa * span)
    b = (x + ca * span, y + sa * span)
    deck = [(a[0] - nx * hw, a[1] - ny * hw), (b[0] - nx * hw, b[1] - ny * hw),
            (b[0] + nx * hw, b[1] + ny * hw), (a[0] + nx * hw, a[1] + ny * hw)]
    # the wall (stone, with the arches) or the trestle (wood) on the side towards the viewer
    drop = 3.0
    wall = [deck[3], deck[2], (deck[2][0], deck[2][1] + drop), (deck[3][0], deck[3][1] + drop)]
    _poly(surf, (176, 164, 140) if stone else (112, 78, 52), wall)
    if abs(ca) > 0.6:
        n = 3 if stone else 4
        for q in range(n):
            t = (q + 0.5) / n
            cx = a[0] + (b[0] - a[0]) * t + nx * hw
            cy = a[1] + (b[1] - a[1]) * t + ny * hw + drop * 0.62
            if stone:
                r = pygame.Rect(0, 0, span * 2 / n * 0.62, 3.4)
                r.center = (round(cx), round(cy))
                pygame.draw.ellipse(surf, (48, 92, 136), r)
            else:
                pygame.draw.line(surf, INK, (round(cx), round(cy - 1.2)), (round(cx), round(cy + 1.4)), 1)
    if stone:
        _poly(surf, (214, 200, 168), deck)
        lit = [deck[0], deck[1], ((deck[0][0] + deck[3][0]) / 2, (deck[0][1] + deck[3][1]) / 2),
               ((deck[1][0] + deck[2][0]) / 2, (deck[1][1] + deck[2][1]) / 2)]
        pygame.draw.polygon(surf, (232, 220, 190), [lit[0], lit[1], lit[3], lit[2]])
        pygame.draw.polygon(surf, INK, deck, 1)
    else:
        _poly(surf, (172, 126, 82), deck)
        for q in range(1, 6):                                    # planks across the deck
            t = q / 6.0
            p0 = (a[0] + (b[0] - a[0]) * t - nx * hw, a[1] + (b[1] - a[1]) * t - ny * hw)
            p1 = (p0[0] + nx * 2 * hw, p0[1] + ny * 2 * hw)
            pygame.draw.line(surf, (122, 86, 56), p0, p1, 1)
        for e in (a, b):                                          # a post at each end
            pygame.draw.circle(surf, (96, 66, 46), (round(e[0] + nx * hw), round(e[1] + ny * hw)), 1)
        pygame.draw.polygon(surf, INK, deck, 1)


def _ford(surf, x, y, ang):
    (ca, sa), (nx, ny) = _frame(ang)
    for q in range(-2, 3):                                        # stepping stones across the river
        sx, sy = x + ca * q * 4.2, y + sa * q * 4.2 + (q % 2) * 0.6
        r = pygame.Rect(0, 0, 5, 3)
        r.center = (round(sx), round(sy))
        pygame.draw.ellipse(surf, (190, 184, 168), r)
        pygame.draw.ellipse(surf, (132, 124, 112), (r.x + 2, r.y + 1, 3, 2))
        pygame.draw.ellipse(surf, INK, r, 1)
    for q in (-1, 1):                                             # a pale ripple on the downstream side
        sx, sy = x + ca * q * 5.5 + nx * 3.4, y + sa * q * 5.5 + ny * 3.4
        pygame.draw.line(surf, (214, 234, 244), (round(sx - 2), round(sy)), (round(sx + 2), round(sy)), 1)


def _ferry(surf, x, y, ang):
    (ca, sa), (nx, ny) = _frame(ang)
    for s in (-1, 1):                                             # a landing post on each bank, a rope between them
        px, py = x + ca * 9.0 * s, y + sa * 9.0 * s
        pygame.draw.line(surf, INK, (round(px), round(py)), (round(px), round(py - 5)), 2)
        pygame.draw.line(surf, (150, 108, 70), (round(px), round(py)), (round(px), round(py - 4)), 1)
    pygame.draw.line(surf, (176, 160, 128), (round(x - ca * 9), round(y - sa * 9 - 4)), (round(x + ca * 9), round(y + sa * 9 - 4)), 1)
    # the boat (the style frame's hull), lying along the rope's direction, a little off the bank-to-bank line
    bx, by = x + nx * 1.5, y + ny * 1.5
    hull = [(bx - 6, by - 2.5), (bx + 6, by - 2.5), (bx + 4, by + 1), (bx - 4, by + 1)]
    _poly(surf, (120, 78, 52), hull)
    pygame.draw.polygon(surf, (146, 98, 66), [hull[0], hull[1], (bx + 5, by - 1.2), (bx - 5, by - 1.2)])
    pygame.draw.line(surf, INK, (round(bx), round(by - 2.5)), (round(bx), round(by - 9)), 1)
    pygame.draw.line(surf, (240, 244, 248), (round(bx - 6), round(by + 2)), (round(bx - 2), round(by + 2)), 1)


def _pass(surf, x, y):
    for dx, dy, r in ((0, 0, 2.4), (0.3, -2.6, 1.8), (0, -4.4, 1.3)):          # a cairn with a pole on the saddle
        pygame.draw.circle(surf, (150, 140, 128), (round(x + dx), round(y + dy)), round(r + 0.5))
        pygame.draw.circle(surf, INK, (round(x + dx), round(y + dy)), round(r + 0.5), 1)
    pygame.draw.line(surf, INK, (round(x), round(y - 5)), (round(x), round(y - 12)), 1)
    pygame.draw.polygon(surf, (196, 60, 50), [(x, y - 12), (x + 4, y - 11), (x, y - 10)])
    pygame.draw.polygon(surf, INK, [(x, y - 12), (x + 4, y - 11), (x, y - 10)], 1)
