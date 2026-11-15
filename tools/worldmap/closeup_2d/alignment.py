import sys, os
sys.path.insert(0, sys.argv[1] + "/closeup_2d"); sys.path.insert(0, sys.argv[1] + "/style_frame")
import pygame; pygame.init()
import scene
from geo import centre, corners, HEX, R_KM
from frame import X0, Y0, TILT
docs = sys.argv[2]; out = sys.argv[3]
close = pygame.image.load(docs + "/growing/growth_1600.png")
frame = pygame.image.load(docs + "/style-frame/style_frame_close.png")
S60 = 60 / R_KM
def Pf(x, y): return ((x - X0) * S60, (y - Y0) * S60 * TILT)
def Pc(x, y):
    px, py = scene.P(x, y); return (px / scene.SS, py / scene.SS)
f = pygame.font.SysFont("segoeui", 22, bold=True); fs = pygame.font.SysFont("segoeui", 16, bold=True)
over = pygame.Surface(close.get_size(), pygame.SRCALPHA)
fo = pygame.Surface(frame.get_size(), pygame.SRCALPHA)
seen = []
for (c, r), h in HEX.items():
    cx, cy = Pc(*centre(c, r))
    if -150 < cx < 1430 and -150 < cy < 870:
        seen.append((c, r))
        pts = [Pc(*p) for p in corners(c, r)]
        pygame.draw.polygon(over, (255, 240, 120, 255), pts, 4)
        land = h.get("land", False)
        txt = "hex %d,%d  %s" % (c, r, h["cover"] if land else "sea")
        t = fs.render(txt, True, (255, 255, 255)); bg = pygame.Surface((t.get_width() + 12, t.get_height() + 4), pygame.SRCALPHA); bg.fill((20, 22, 34, 200))
        over.blit(bg, (cx - bg.get_width() / 2, cy - 12)); over.blit(t, (cx - t.get_width() / 2, cy - 10))
        fpts = [Pf(*p) for p in corners(c, r)]
        pygame.draw.polygon(fo, (255, 240, 120, 255), fpts, 2)
close.blit(over, (0, 0)); frame.blit(fo, (0, 0))
pygame.draw.rect(frame, (255, 60, 60), (725 - 160, 370 - 90, 320, 180), 3)
W = 1280 * 2 + 30; sheet = pygame.Surface((W, 720 + 70)); sheet.fill((24, 26, 36))
sheet.blit(f.render("The normal game map (wide/close zoom of the style frame): red box = the close-up's area", True, (240, 240, 240)), (10, 12))
sheet.blit(f.render("The closest zoom (growth panel 1600) with the same 28 km hexes drawn on it", True, (240, 240, 240)), (1310, 12))
sheet.blit(frame, (0, 60)); sheet.blit(close, (1310, 60))
pygame.image.save(sheet, out)
print(sorted(seen))
