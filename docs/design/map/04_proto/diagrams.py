"""Throw-away: draws 04_pipeline.png and 04_sockets.png for docs/design/map/04-wfc-model.md."""
import math
import os

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
import pygame

pygame.init()
HERE = os.path.dirname(os.path.abspath(__file__))
INK, PAPER = (40, 36, 32), (246, 241, 229)
F = pygame.font.SysFont("arial", 16, bold=True)
S = pygame.font.SysFont("arial", 13)
FIX, ALG, WFC, CHK = (226, 205, 150), (170, 205, 225), (175, 215, 160), (235, 180, 160)


def text(surf, s, x, y, font=S, col=INK):
    for i, line in enumerate(s.split("\n")):
        surf.blit(font.render(line, True, col), (x, y + i * (font.get_height() + 1)))


# ---------------------------------------------------------------- pipeline
steps = [
    ("0 Fixed facts", FIX, "From the geography files:\ncoastline, lakes, big rivers,\nmountain lines, passes, cities.\nNever changed later."),
    ("1 Relief", ALG, "Height from the mountain and\nhill lines plus seeded noise.\nFour classes. Crest edges where\na mountain line cuts an edge."),
    ("2 Water", ALG, "Rivers run along hex edges.\nReal rivers are snapped first;\nthe rest drains downhill to the\nsea; busy drains become streams."),
    ("3 Ground cover", WFC, "Wave function collapse:\nfarmland, wood, marsh, rock...\ninside what relief and water\nallow. Undo on a dead end."),
    ("4 Settlements", ALG, "Real cities keep their hex.\nTowns and villages by score\n(river, coast, crossing, flat\nland) with spacing."),
    ("5 Roads", ALG, "Cheapest paths on a cost field.\nCrests block, passes are the\ngates, valleys are cheap.\nBridges where a road crosses."),
    ("6 Sockets and checks", CHK, "One record per hex edge with\nall layers. Checked: every\nriver reaches the sea, no road\ndead-ends, no forbidden pair."),
    ("7 Art", FIX, "Each hex reads its six edges\nand picks pieces. Lines are\ndrawn through the edge points,\nobjects on a map-wide grid."),
]
W, H = 1500, 300
surf = pygame.Surface((W, H))
surf.fill(PAPER)
bw, gap = 172, 14
for i, (name, col, body) in enumerate(steps):
    x = 10 + i * (bw + gap)
    pygame.draw.rect(surf, col, (x, 50, bw, 150), border_radius=8)
    pygame.draw.rect(surf, INK, (x, 50, bw, 150), 2, border_radius=8)
    text(surf, name, x + 8, 58, F)
    text(surf, body, x + 8, 84)
    if i < len(steps) - 1:
        ax = x + bw
        pygame.draw.line(surf, INK, (ax, 125), (ax + gap, 125), 3)
        pygame.draw.polygon(surf, INK, [(ax + gap, 125), (ax + gap - 7, 119), (ax + gap - 7, 131)])
text(surf, "How the map is built: each step only adds, and what it adds limits the next step", 10, 14, F)
for i, (col, label) in enumerate([(FIX, "given data / art"), (ALG, "an algorithm made for the job"), (WFC, "wave function collapse"), (CHK, "the shared language and the tests")]):
    pygame.draw.rect(surf, col, (10 + i * 300, 222, 22, 16))
    pygame.draw.rect(surf, INK, (10 + i * 300, 222, 22, 16), 1)
    text(surf, label, 40 + i * 300, 222)
text(surf, "Same seed and same data give the same map. A failed check stops the build and names the hex; it is never papered over.", 10, 256)
pygame.image.save(surf, os.path.join(HERE, "..", "04_pipeline.png"))

# ---------------------------------------------------------------- sockets
W, H = 1500, 640
surf = pygame.Surface((W, H))
surf.fill(PAPER)
text(surf, "What a hex edge carries: one record per edge; lines run along it, routes cross it", 10, 12, F)


def hexpts(cx, cy, R):
    return [(cx + R * math.cos(math.radians(60 * i - 30)), cy + R * math.sin(math.radians(60 * i - 30))) for i in range(6)]


def edge(cx, cy, R, e):          # edge e: 0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE ; returns its two corners and midpoint
    a = math.radians(-60 * e)
    A = R * math.sqrt(3) / 2
    mx, my = cx + A * math.cos(a), cy + A * math.sin(a)
    tx, ty = -math.sin(a) * R / 2, math.cos(a) * R / 2
    return (mx - tx, my - ty), (mx + tx, my + ty), (mx, my)


def lane(p0, p1, t):
    return p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t


def curve(p0, c, p1, col, w):
    pts = [((1 - t) ** 2 * p0[0] + 2 * t * (1 - t) * c[0] + t * t * p1[0], (1 - t) ** 2 * p0[1] + 2 * t * (1 - t) * c[1] + t * t * p1[1]) for t in [i / 20 for i in range(21)]]
    pygame.draw.lines(surf, col, False, pts, w)


# A: one hex, its edges and the two kinds of place
cx, cy, R = 230, 320, 170
pygame.draw.polygon(surf, (228, 222, 196), hexpts(cx, cy, R))
pygame.draw.polygon(surf, INK, hexpts(cx, cy, R), 2)
names = ["0 E", "1 NE", "2 NW", "3 W", "4 SW", "5 SE"]
for e in range(6):
    p0, p1, m = edge(cx, cy, R, e)
    pygame.draw.line(surf, (150, 130, 110), (cx, cy), m, 1)
    pygame.draw.rect(surf, (120, 70, 40), (m[0] - 8, m[1] - 8, 16, 16))
    a = math.radians(-60 * e)
    text(surf, names[e], cx + (R * 0.6) * math.cos(a) - 14, cy + (R * 0.6) * math.sin(a) - 8, F)
for c in hexpts(cx, cy, R):
    pygame.draw.circle(surf, (40, 100, 170), c, 8)
pygame.draw.circle(surf, (200, 50, 40), (cx, cy), 9)
text(surf, "A. Six edges, numbered from east, anticlockwise.", 20, 520, F)
text(surf, "Brown squares, the middle of each edge: what CROSSES the edge goes through here (a road, a valley floor).\nBlue dots, the corners: what runs ALONG an edge goes from corner to corner (a river, a crest, a shore).\nRed dot, the centre: the hex's own facts (height level, ground cover, settlement). Roads meet here.", 20, 546)

# B: two hexes sharing an edge
bx, by, r = 720, 250, 120
c1, c2 = (bx, by), (bx + r * math.sqrt(3), by)
for c, col in ((c1, (214, 204, 110)), (c2, (150, 200, 110))):
    pygame.draw.polygon(surf, col, hexpts(c[0], c[1], r))
    pygame.draw.polygon(surf, INK, hexpts(c[0], c[1], r), 2)
p0, p1, m = edge(c1[0], c1[1], r, 0)
n0, n1, nm = edge(c1[0], c1[1], r, 1)
s0, s1, sm = edge(c1[0], c1[1], r, 5)
for a_, b_ in ((n0, n1), (p0, p1), (s0, s1)):
    pygame.draw.line(surf, (40, 100, 170), a_, b_, 9)
for q in (p0, p1, n0, n1, s0, s1):
    pygame.draw.circle(surf, (40, 100, 170), q, 5)
pygame.draw.line(surf, (120, 70, 40), c1, c2, 5)
pygame.draw.rect(surf, (250, 250, 250), (m[0] - 12, m[1] - 9, 24, 18))
pygame.draw.rect(surf, INK, (m[0] - 12, m[1] - 9, 24, 18), 2)
for c in (c1, c2):
    pygame.draw.circle(surf, (200, 50, 40), c, 8)
    pygame.draw.circle(surf, INK, c, 8, 1)
text(surf, "B. The shared edge is stored once, so the two hexes cannot disagree.", 600, 60, F)
text(surf, "Edge record:\n  line          river, size 2, flows south\n  step         level (both hexes are plain)\n  road         2 (cart road)\n  crossing   wooden bridge\n  floor         no", 1010, 150)
text(surf, "The left hex reads the record as its edge 0 (E); the right hex reads the same record as its edge 3 (W).\nThe river runs along the edge and carries on at both corners; the road crosses it in the middle, on a bridge.", 600, 400)

# C: the layer table
text(surf, "C. What an edge record holds", 600, 452, F)
rows = [("line", "runs along the edge: none, shore (beach, cliff, marsh), crest, pass, river 1-3 (with flow direction), lake, sea", (40, 100, 170)),
        ("step", "relief across the edge: level, slope (one level), scarp (two or more)", (160, 142, 112)),
        ("floor", "a valley floor continues across the edge (yes or no, with its downhill direction)", (90, 180, 90)),
        ("road", "crosses the edge: 0 none, 1 track, 2 road, 3 highway", (120, 70, 40)),
        ("crossing", "how the road gets over the line: ford, wooden bridge, stone bridge, ferry, pass; quay on a shore", (250, 250, 250)),
        ("cover", "same or blend of the two hexes' ground cover (worked out, never stored)", (60, 140, 80))]
for i, (k, v, col) in enumerate(rows):
    pygame.draw.rect(surf, col, (600, 480 + i * 25, 18, 18))
    pygame.draw.rect(surf, INK, (600, 480 + i * 25, 18, 18), 1)
    text(surf, k, 628, 480 + i * 25, F)
    text(surf, v, 710, 482 + i * 25)
pygame.image.save(surf, os.path.join(HERE, "..", "04_sockets.png"))
print("ok")
