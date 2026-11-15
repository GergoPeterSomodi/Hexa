"""The alignment sheet: the normal map and the close-up side by side, with the same 28 km hexes drawn on both.

    python tools/worldmap/closeup_2d/alignment.py TOOLS_DIR DOCS_MAP_DIR OUT.png [PANEL]

TOOLS_DIR is tools/worldmap, DOCS_MAP_DIR is docs/design/map. PANEL is the growth panel shown (default 3). Every hex
of the close-up is labelled with its district: name, main use and stage in that panel (stages.DISTRICTS). The thin
lines on the close-up are the normal map's own coast (white), roads (red) and torrent (light blue), and the red rings
are the normal map's town sites and pass, for comparison. Since the normal map follows "one town, one hex, drawn
inside it" (style_frame/sites.py) they coincide with the close-up's own coast, roads and towns.
"""
import sys, os
sys.path.insert(0, sys.argv[1] + "/closeup_2d"); sys.path.insert(0, sys.argv[1] + "/style_frame")
import pygame; pygame.init()
import scene
import stages as ST
from geo import centre, corners, HEX, R_KM
from frame import X0, Y0, TILT
docs = sys.argv[2]; out = sys.argv[3]
panel = sys.argv[4] if len(sys.argv) > 4 else "3"
st = ST.STAGES[panel]
close = pygame.image.load(docs + "/growing/" + st["file"] + ".png")
frame = pygame.image.load(docs + "/style-frame/style_frame_close.png")
S60 = 60 / R_KM
def Pf(x, y): return ((x - X0) * S60, (y - Y0) * S60 * TILT)
def Pc(x, y):
    px, py = scene.P(x, y); return (px / scene.SS, py / scene.SS)
f = pygame.font.SysFont("segoeui", 22, bold=True); fs = pygame.font.SysFont("segoeui", 15, bold=True); ft = pygame.font.SysFont("segoeui", 14)
over = pygame.Surface(close.get_size(), pygame.SRCALPHA)
fo = pygame.Surface(frame.get_size(), pygame.SRCALPHA)
# the normal map's own lines, drawn thin on the close-up
for lp in scene.contours(scene.frame_land, scene.VX - 6, scene.VY - 6, scene.VX + scene.VW_KM + 6, scene.VY + scene.VH_KM + 6, 0.4):
    pygame.draw.lines(over, (255, 255, 255, 230), True, [Pc(*p) for p in lp], 1)
for ln in scene.FRAME_ROADS:
    pygame.draw.lines(over, (230, 60, 60, 230), False, [(x / scene.SS, y / scene.SS) for x, y in ln], 1)
for ln in scene.FRAME_STREAMS:
    pygame.draw.lines(over, (170, 230, 255, 240), False, [(x / scene.SS, y / scene.SS) for x, y in ln], 1)
for name, (x, y) in scene.FRAME_SITES.items():
    pygame.draw.circle(over, (255, 255, 255, 255), (x / scene.SS, y / scene.SS), 9, 4)
    pygame.draw.circle(over, (230, 60, 60, 255), (x / scene.SS, y / scene.SS), 8, 2)
seen = []
labels = []
for (c, r), h in HEX.items():
    cx, cy = Pc(*centre(c, r))
    if -150 < cx < 1430 and -150 < cy < 870:
        seen.append((c, r))
        pts = [Pc(*p) for p in corners(c, r)]
        pygame.draw.polygon(over, (255, 240, 120, 255), pts, 3)
        d = ST.DISTRICTS.get((c, r))
        if d:
            stage = d["stage"][panel] if d["stage"] else None
            lines = ["%s  (hex %d,%d)" % (d["name"], c, r), d["use"] + (", stage %d" % stage if stage is not None else "")]
            labels.append((cx, cy, lines, h.get("land", False)))
        fpts = [Pf(*p) for p in corners(c, r)]
        pygame.draw.polygon(fo, (255, 240, 120, 255), fpts, 2)
close.blit(over, (0, 0)); frame.blit(fo, (0, 0))
for cx, cy, lines, land in labels:
    y = cy - 150 if land and cy > 200 else cy       # above the seat in the coast row, at the centre elsewhere
    imgs = [fs.render(lines[0], True, (255, 255, 255)), ft.render(lines[1], True, (255, 236, 170))]
    w = max(t.get_width() for t in imgs) + 14
    hgt = sum(t.get_height() for t in imgs) + 6
    x0 = min(max(cx - w / 2, 4), close.get_width() - w - 4)
    y0 = min(max(y - hgt / 2, 4), close.get_height() - hgt - 4)
    bg = pygame.Surface((w, hgt), pygame.SRCALPHA); bg.fill((20, 22, 34, 215))
    close.blit(bg, (x0, y0))
    yy = y0 + 3
    for t in imgs:
        close.blit(t, (x0 + 7, yy)); yy += t.get_height()
pygame.draw.rect(frame, (255, 60, 60), (725 - 160, 370 - 90, 320, 180), 3)
W = 1280 * 2 + 30; sheet = pygame.Surface((W, 720 + 96)); sheet.fill((24, 26, 36))
sheet.blit(f.render("The normal game map (wide/close zoom of the style frame): red box = the close-up's area", True, (240, 240, 240)), (10, 12))
sheet.blit(f.render("The closest zoom (%s, %s) with the same 28 km hexes: one district, one seat, one stage per hex" % (st["title"], st["year"]), True, (240, 240, 240)), (1310, 12))
sheet.blit(frame, (0, 60)); sheet.blit(close, (1310, 60))
note = "Thin lines on the close-up: the normal map's own coast (white), roads (red) and torrent (light blue); red rings: its town sites and pass. Both zooms now draw every town inside its own hex."
sheet.blit(ft.render(note, True, (200, 204, 216)), (1310, 60 + 720 + 8))
pygame.image.save(sheet, out)
print(sorted(seen))
