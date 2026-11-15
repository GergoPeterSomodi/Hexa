"""The growing map: the contact sheet of the five panels and the zoom strips (see growth.py).

The zoom strips are reductions of the close-up drawing to the pixel size the same ground has at the middle zoom
(hex radius 60) and the wide zoom (hex radius 30), with the name plates drawn afterwards at interface size. They are
not a separate set of art for those zooms.
"""
import os
import pygame
import closeup as C
import stages as ST

BG, FG, DIM = (30, 34, 48), (244, 238, 222), (176, 182, 200)
REF_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "design", "map", "style-frame")


def font(size, bold=False):
    return pygame.font.SysFont("segoeui", size, bold=bold)


def text(img, s, pos, size=18, col=FG, bold=False):
    t = font(size, bold).render(s, True, col)
    img.blit(t, pos)
    return t.get_width()


def contact_sheet(pics, path, pw=800, ph=450):
    """All five panels with their labels: the three steps in the top row, the two 1650 outcomes below."""
    gap, head, top = 16, 58, 64
    cols = 3
    w = gap + cols * (pw + gap)
    h = top + 2 * (head + ph + gap) + 8
    img = pygame.Surface((w, h))
    img.fill(BG)
    text(img, "The growing map: the Genoa close-up at five moments in time", (gap, 12), 30, bold=True)
    text(img, "Same camera, coast, hills, torrents and palette in every panel. Only what stands on the land changes.", (gap + 900, 24), 18, DIM)
    slots = {"1": (0, 0), "2": (1, 0), "3": (2, 0), "4a": (0, 1), "4b": (1, 1)}
    for key, (cx, cy) in slots.items():
        st = ST.STAGES[key]
        x, y = gap + cx * (pw + gap), top + cy * (head + ph + gap)
        n = text(img, st["title"], (x + 2, y), 24, bold=True)
        text(img, st["year"], (x + n + 14, y + 5), 19, (232, 200, 120), bold=True)
        text(img, st["sub"], (x + 2, y + 32), 15, DIM)
        img.blit(pygame.transform.smoothscale(pics[key][0], (pw, ph)), (x, y + head))
        pygame.draw.rect(img, (12, 14, 22), (x, y + head, pw, ph), 1)
    # the legend in the free slot
    x, y = gap + 2 * (pw + gap), top + (head + ph + gap) + 6
    text(img, "How to read it", (x + 8, y), 24, bold=True)
    lines = [
        ("Never changes", "coast, ground tones, hill and ridge shapes, torrents,"),
        ("", "town sites, road lines, the camera and the palette"),
        ("Settlement", "hamlet (3 houses) > village (church) > big village;"),
        ("", "Savona and Chiavari: village > walled town or port town"),
        ("Fields", "open strips > hedged blocks > estates (4b: grain, mills, barns)"),
        ("Vines, olives", "scrub > first rows and groves > terraces > to the ridges (4a)"),
        ("Woods", "down to the valley floors > clearings > thinned from the foot up"),
        ("Harbour", "old mole, small quay > full quay, new mole, Lanterna >"),
        ("", "great port: long moles, warehouses, three hulls, twice the ships"),
        ("Roads", "mule track and fords > cart road, timber bridge >"),
        ("", "road, stone bridges, hospice > highway, inn (4a)"),
        ("Castles", "one watchtower > three > bastion fortress, pass castle, flags (4b)"),
        ("1650", "4a and 4b are two different players' maps of the same land"),
    ]
    yy = y + 44
    for a, b in lines:
        if a:
            yy += 6
            text(img, a, (x + 8, yy), 16, (232, 200, 120), bold=True)
        text(img, b, (x + 140, yy), 16, FG)
        yy += 25
    pygame.image.save(img, path)
    return img


def reduce(big, k):
    """The 2x drawing reduced to 1/k of the 1280x720 picture."""
    return pygame.transform.smoothscale(big, (C.OUT_W // k, C.OUT_H // k))


def plates(img, k, e=1):
    """Name plates at interface size on a picture reduced to 1/k and then enlarged e times."""
    def at(x, y):
        return (x * e // k, y * e // k)
    if k <= 4:
        C.plate(img, "Genoa", at(631, 300), 1, "midbottom")
        C.plate(img, "Savona", at(100, 548), 1)
        C.plate(img, "Chiavari", at(1128, 506), 1)
    else:
        C.plate(img, "Genoa", at(631, 310), 1, "midbottom")


def zoom_strips(pics, path, keys=("1", "3", "4a")):
    """Panels 1, 3 and 4a at the middle zoom (hex radius 60) and the wide zoom (hex radius 30): at true pixel size,
    and enlarged without smoothing so that what survives can be judged."""
    gap, top = 16, 64
    mw, mh = C.OUT_W // 4, C.OUT_H // 4          # 320 x 180: the same ground at hex radius 60
    ww, wh = C.OUT_W // 8, C.OUT_H // 8          # 160 x 90: at hex radius 30
    ew, eh = mw * 2, mh * 2                      # the enlarged views
    w = gap + 3 * (ew + gap)
    h = top + 30 + mh + 44 + 3 * (34 + eh) + gap + 30
    img = pygame.Surface((w, h))
    img.fill(BG)
    text(img, "The growing map at the middle and the wide zoom", (gap, 12), 30, bold=True)
    text(img, "Panels 1, 3 and 4a: the close-up drawing reduced to the size the same ground has at each zoom.", (gap + 760, 24), 18, DIM)
    mids, wides = {}, {}
    for key in keys:
        mids[key], wides[key] = reduce(pics[key][1], 4), reduce(pics[key][1], 8)
    # row 1: true size
    y = top
    text(img, "True pixel size", (gap, y), 20, bold=True)
    text(img, "middle zoom (hex radius 60, 320 x 180 px) and wide zoom (hex radius 30, 160 x 90 px); a full screen shows 16 and 64 times this ground",
         (gap + 170, y + 3), 16, DIM)
    y += 30
    for i, key in enumerate(keys):
        st = ST.STAGES[key]
        x = gap + i * (ew + gap)
        m, wd = mids[key].copy(), wides[key].copy()
        plates(m, 4)
        plates(wd, 8)
        img.blit(m, (x, y))
        img.blit(wd, (x + mw + gap, y))
        text(img, st["title"], (x + mw + gap, y + wh + 10), 17, FG, bold=True)
        text(img, st["year"], (x + mw + gap, y + wh + 34), 16, (232, 200, 120), bold=True)
        text(img, "left middle, right wide", (x + mw + gap, y + wh + 58), 14, DIM)
    y += mh + 14
    # rows 2 and 3: enlarged, pixel for pixel
    for label, note, src, k in (("Middle zoom, enlarged 2x", "blocks and patterns: field blocks, terraces, town size, harbour works, the road class", mids, 2),
                                ("Wide zoom, enlarged 4x", "colour and texture only: wild green against worked patchwork, the size of the towns, the fleet", wides, 4)):
        text(img, label, (gap, y), 20, bold=True)
        text(img, note, (gap + 270, y + 3), 16, DIM)
        y += 34
        for i, key in enumerate(keys):
            x = gap + i * (ew + gap)
            big = pygame.transform.scale(src[key], (ew, eh))
            plates(big, 4 if k == 2 else 8, k)
            img.blit(big, (x, y))
            pygame.draw.rect(img, (12, 14, 22), (x, y, ew, eh), 1)
            st = ST.STAGES[key]
            C.plate(img, "%s  %s" % (st["title"], st["year"]), (x + 8, y + 8), 1, "topleft")
        y += eh
    # row 4: what the style frame draws at these zooms today (not staged), for comparison
    text(img, "For comparison: today's style frame of the same ground (not staged)", (gap, y + 4), 20, bold=True)
    y += 34
    ref = []
    for name, rect, k in (("style_frame_close.png", (565, 280, 320, 180), 2), ("style_frame_middle.png", (282, 140, 160, 90), 4)):
        p = os.path.join(REF_DIR, name)
        if os.path.exists(p):
            src = pygame.image.load(p)
            ref.append((pygame.transform.scale(src.subsurface(pygame.Rect(rect)).copy(), (ew, eh)), k))
    for i, (pic, k) in enumerate(ref):
        x = gap + i * (ew + gap)
        img.blit(pic, (x, y))
        pygame.draw.rect(img, (12, 14, 22), (x, y, ew, eh), 1)
        C.plate(img, ("Style frame, hex radius 60, enlarged 2x", "Style frame, hex radius 30, enlarged 4x")[i], (x + 8, y + 8), 1, "topleft")
    x = gap + 2 * (ew + gap) + 8
    notes = ["What to check against section 5 of the design:",
             "Wide: can you tell rich from wild country by colour alone?",
             "Middle: can you tell what each district does (grain, vines,",
             "woods, port) without reading single houses?",
             "The style frame draws fewer, larger pieces at these zooms.",
             "A staged set of those pieces is not drawn yet; this strip",
             "only shows what the close-up's content reduces to."]
    for j, line in enumerate(notes):
        text(img, line, (x, y + 6 + j * 27), 17, FG if j == 0 else DIM, bold=j == 0)
    pygame.image.save(img, path)
    return img
