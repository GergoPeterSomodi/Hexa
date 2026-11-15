"""Landmark cities: the monuments that take the place of the church (level 4) and the cathedral (level 5) in
settlements.draw(..., landmark="venice"). See docs/design/map/pieces/GUIDE.md ("Landmark cities") and
docs/design/map/pieces/REVIEW.md tasks 21 (these four) and 22 (the other six).

    NAMES                     the cities of this module
    draw(p, name, level, x, y)  draws the monument with its foot at (x, y) (the church's spot); returns the handle
    CLEAR[name][level]        (left, top, right, bottom): the box round the foot (px) in which the settlement draws no
                              house. Left and right are equal: the monument is drawn round the axis x, so the box
                              does not change in a mirrored piece.
    WALL[name]                the ring wall's colour, where the city has one (settlements passes it to p.wall(col=))
    CAPS[name]                the colour of the pointed caps on the ring wall's towers, where the city has them
    caps(p, name, spots, w)   the caps themselves: spots are (x, y_foot, tower_height) of each tower as drawn

A monument is at most 20 px tall and 24 px wide, has the kit's two tones and 0.5 px ink, and is drawn round the axis
x (the middle of its picture is the church's spot, so a mirrored piece moves it like the church: p.stand(..., x=x)).
A part that lies off the axis casts its shadow at x + p.m * offset (the thing is moved, not flipped).

python landmarks.py      writes docs/design/map/pieces/landmarks.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

NAMES = ("venice", "constantinople", "paris", "moscow")
WALL = {"moscow": kit.BRICK}
CAPS = {"moscow": kit.SLATE}
CLEAR = {
    "venice": {4: (-10, -22, 10, 9), 5: (-16, -22, 16, 9)},
    "constantinople": {4: (-14, -20, 14, 9), 5: (-16, -22, 16, 9)},
    "paris": {4: (-11, -22, 11, 9), 5: (-11, -24, 11, 9)},
    "moscow": {4: (-10, -20, 10, 9), 5: (-15, -22, 15, 9)},
}

INK = kit.INK
SNOW, SNOW_D = kit.SNOW, kit.SNOW_D
WHITE = kit.PLASTER[3]                       # Moscow's whitewash
PALACE = kit.PLASTER[2]                      # Venice: the palace front


# ------------------------------------------------------------------ shapes (all in piece px, pen y up = smaller)
def _block(pen, x0, yb, w, h, col, cd, side=0.3, ink=True):
    """An upright wall face, its foot on yb: lit left, a darker strip on the right."""
    pen.rect(x0, yb - h, w, h, col, None)
    pen.rect(x0 + w * (1 - side), yb - h, w * side, h, cd, None)
    if ink:
        pen.rect(x0, yb - h, w, h, None, INK, 0.5)


def _dome(pen, cx, yb, r, ry, col, cd, snow):
    """A dome (half an ellipse) standing on yb: lit left, darker right; snow lies on the upper left only."""
    n = 16
    arc = [(cx + r * math.cos(math.pi * (1 - k / n)), yb - ry * math.sin(math.pi * k / n)) for k in range(n + 1)]
    pen.poly(arc, cd, None)
    a0 = math.acos(0.15)
    lit = [(cx + r * math.cos(t), yb - ry * math.sin(t)) for t in [math.pi - (math.pi - a0) * k / n for k in range(n + 1)]]
    pen.poly(lit + [(cx + r * 0.15, yb)], col, None)
    if snow:
        out = [(cx + r * math.cos(t), yb - ry * math.sin(t)) for t in [math.radians(100 + 62 * k / 8) for k in range(9)]]
        inn = [(cx + 0.66 * r * math.cos(t), yb - 0.66 * ry * math.sin(t)) for t in [math.radians(100 + 62 * k / 8) for k in range(9)]]
        pen.poly(out + inn[::-1], SNOW, None)
    pen.poly(arc, None, INK, 0.5)
    pen.line((cx - r, yb), (cx + r, yb), INK, 0.5)


def _cone(pen, cx, yb, w, h, col, cd, snow, ink=True):
    """A pointed cap on yb: the left half lit, the right half darker, snow on the upper left."""
    pen.poly([(cx - w / 2, yb), (cx, yb), (cx, yb - h)], col, None)
    pen.poly([(cx, yb), (cx + w / 2, yb), (cx, yb - h)], cd, None)
    if snow:
        f = 0.5
        pen.poly([(cx - w / 2 * (1 - f), yb - f * h), (cx, yb - f * h), (cx, yb - h)], SNOW, None)
    if ink:
        pen.poly([(cx - w / 2, yb), (cx + w / 2, yb), (cx, yb - h)], None, INK, 0.5)


def _onion_pts(cx, yb, r, hgt, n=9):
    left = []
    for k in range(n + 1):
        t = k / n
        w = r * (0.42 + 0.58 * math.sin(t / 0.34 * math.pi / 2)) if t <= 0.34 else r * math.cos((t - 0.34) / 0.66 * math.pi / 2) ** 0.8
        left.append((cx - w, yb - t * hgt))
    right = [(2 * cx - q[0], q[1]) for q in left[::-1]]
    return left, right


def _onion(pen, cx, yb, r, hgt, col, snow, cross=False):
    """An onion dome standing on yb: widest a third of the way up, a point on top; lit left, darker right."""
    left, right = _onion_pts(cx, yb, r, hgt)
    pen.poly(left + right, kit.shade(col, 0.78), None)
    pen.poly(left + [(cx + r * 0.2, yb)], col, None)
    if snow:
        i0, i1 = 4, 8
        inn = [(q[0] + (cx - q[0]) * 0.5, q[1]) for q in left[i0:i1 + 1]]
        pen.poly(left[i0:i1 + 1] + inn[::-1], SNOW, None)
    pen.poly(left + right, None, INK, 0.5)
    if cross:
        ty = yb - hgt
        pen.line((cx, ty), (cx, ty - 2.2), kit.GILT, 0.5)
        pen.line((cx - 0.7, ty - 1.4), (cx + 0.7, ty - 1.4), kit.GILT, 0.5)


def _tent(pen, cx, yb, w, h, col, cd, snow):
    pen.poly([(cx - w / 2, yb), (cx, yb), (cx, yb - h)], col, None)
    pen.poly([(cx, yb), (cx + w / 2, yb), (cx, yb - h)], cd, None)
    if snow:
        pen.poly([(cx - w / 2 * 0.5, yb - h * 0.5), (cx, yb - h * 0.5), (cx, yb - h)], SNOW, None)
    pen.poly([(cx - w / 2, yb), (cx + w / 2, yb), (cx, yb - h)], None, INK, 0.5)


def _minaret(pen, cx, yb, h, snow):
    """A thin minaret: a pale shaft 1.6 px wide with a darker right edge, a balcony, a pointed cap."""
    cap = 3.4
    sh = h - cap
    pen.rect(cx - 1.0, yb - sh, 2.0, sh, kit.MARBLE, None)
    pen.rect(cx + 0.1, yb - sh, 0.9, sh, kit.MARBLE_D, None)
    pen.line((cx - 1.0, yb), (cx - 1.0, yb - sh), kit.shade(kit.MARBLE_D, 0.8), 0.5)   # the lit edge: a soft line
    pen.line((cx + 1.0, yb), (cx + 1.0, yb - sh), INK, 0.5)
    by = yb - sh * 0.66                                  # the balcony
    pen.rect(cx - 1.8, by - 0.8, 3.6, 0.8, kit.MARBLE_D, INK, 0.5)
    _cone(pen, cx, yb - sh, 3.0, cap, kit.LEAD, kit.LEAD_D, snow)


# ------------------------------------------------------------------ the monuments
def venice(p, level, x, y):
    """The campanile (a BRICK shaft with a pale belfry and a verdigris cap) at the right of the axis; at level 5
    St Mark's (a low pale front with three lead domes) at its left and the palace front at its right."""
    sn = p.winter
    cx = x + 2.5
    p.cast(x + p.m * 2.5, y, 5.5)
    if level >= 5:
        p.cast(x + p.m * -5.5, y, 12.5)
        p.cast(x + p.m * 8.5, y, 7)

    def fn(pen):
        if level >= 5:
            x0 = x - 12.0                                # St Mark's: x - 12 .. x + 0.5
            for dx, r in ((2.2, 2.0), (10.3, 2.0)):      # the side domes first, the great one over them
                _dome(pen, x0 + dx, y - 5.4, r, r * 0.95, kit.LEAD, kit.LEAD_D, sn)
            _block(pen, x0, y, 12.5, 5.4, kit.MARBLE, kit.MARBLE_D, 0.2)
            for i in range(4):                           # the arcade at the foot
                pen.rect(x0 + 1.2 + i * 3.0, y - 2.6, 1.3, 2.6, kit.DOOR, None)
            pen.line((x0, y - 4.2), (x0 + 12.5, y - 4.2), kit.MARBLE_D, 0.5)
            _dome(pen, x0 + 6.2, y - 5.4, 3.3, 3.1, kit.LEAD, kit.LEAD_D, sn)
            pen.line((x0 + 6.2, y - 8.4), (x0 + 6.2, y - 9.6), kit.GILT, 0.5)
            px0 = x + 5.0                                # the palace front
            _block(pen, px0, y, 6.8, 4.4, PALACE, kit.shade(PALACE, 0.84), 0.22)
            for i in range(5):
                pen.rect(px0 + 0.8 + i * 1.3, y - 1.8, 0.7, 1.8, kit.DOOR, None)
            pen.line((px0, y - 3.0), (px0 + 6.8, y - 3.0), kit.shade(PALACE, 0.7), 0.5)
            if sn:
                pen.rect(px0 - 0.2, y - 5.2, 4.2, 0.9, SNOW, None)
        # the campanile
        _block(pen, cx - 2.8, y, 5.6, 1.3, kit.MARBLE, kit.MARBLE_D, 0.3)             # the plinth
        _block(pen, cx - 2.1, y - 1.3, 4.2, 11.8, kit.BRICK, kit.BRICK_D, 0.32)     # the shaft
        pen.rect(cx - 0.4, y - 8.6, 0.8, 2.0, kit.DOOR, None)
        _block(pen, cx - 2.5, y - 13.1, 5.0, 3.0, kit.MARBLE, kit.MARBLE_D, 0.3)      # the belfry
        pen.rect(cx - 1.4, y - 15.6, 1.5, 2.0, kit.DOOR, None)
        _cone(pen, cx, y - 16.1, 5.6, 3.3, kit.VERDIGRIS, kit.VERDIGRIS_D, sn)         # the cap
        pen.line((cx, y - 19.4), (cx, y - 19.9), kit.GILT, 0.5)
    return p.stand(y, fn, x=x)


def constantinople(p, level, x, y):
    """The great dome: a wide low LEAD dome on a pale body between two half-domes; at level 5 four thin minarets
    stand at the corners."""
    sn = p.winter
    p.cast(x, y, 18)

    def fn(pen):
        if level >= 5:
            for sx in (-1, 1):                            # the back minarets behind the half-domes
                _minaret(pen, x + sx * 7.8, y - 3.5, 15.0, sn)
        for sx in (-1, 1):                                # half-domes
            _dome(pen, x + sx * 6.3, y - 6.4, 3.6, 3.2, kit.LEAD, kit.LEAD_D, sn)
        _block(pen, x - 7.8, y, 15.6, 6.4, kit.STONE, kit.STONE_D, 0.22)
        for i in range(5):                                # a row of window slits
            pen.rect(x - 5.6 + i * 2.8, y - 4.6, 0.8, 2.0, kit.DOOR, None)
        pen.rect(x - 1.1, y - 2.6, 2.2, 2.6, kit.DOOR, None)
        pen.rect(x - 6.0, y - 7.4, 12.0, 1.1, kit.STONE_D, INK, 0.5)                     # the drum's ring
        _dome(pen, x, y - 7.4, 6.0, 5.4, kit.LEAD, kit.LEAD_D, sn)
        pen.line((x, y - 12.8), (x, y - 14.4), kit.GILT, 0.5)
        if level >= 5:
            for sx in (-1, 1):                            # the front minarets
                _minaret(pen, x + sx * 10.0, y + 1.0, 15.0, sn)
    return p.stand(y, fn, x=x)


def paris(p, level, x, y):
    """The twin-towered front: two square CHURCH towers with flat tops and a slate nave between them; at level 5
    the towers rise to 18 px, a thin spire stands behind them and a rose window shows on the nave."""
    sn = p.winter
    th = 15.0 if level < 5 else 18.0
    p.cast(x, y, 14)
    cd = kit.shade(kit.CHURCH, 0.84)

    def fn(pen):
        roof, roof_d = kit.SLATE, kit.SLATE_D
        pen.poly([(x - 3.4, y - 8), (x, y - 12.6), (x, y - 8)], roof, None)           # the nave roof behind
        pen.poly([(x, y - 12.6), (x + 3.4, y - 8), (x, y - 8)], roof_d, None)
        if sn:
            pen.poly([(x - 2.0, y - 10.4), (x, y - 12.6), (x, y - 10.4)], SNOW, None)
        pen.poly([(x - 3.4, y - 8), (x + 3.4, y - 8), (x, y - 12.6)], None, INK, 0.5)
        if level >= 5:                                    # the spire behind the towers
            pen.poly([(x - 1.5, y - 11), (x, y - 19.4), (x, y - 11)], kit.LEAD, None)
            pen.poly([(x, y - 19.4), (x + 1.5, y - 11), (x, y - 11)], kit.LEAD_D, None)
            pen.poly([(x - 1.5, y - 11), (x + 1.5, y - 11), (x, y - 19.4)], None, INK, 0.5)
        _block(pen, x - 1.9, y, 3.8, 8.0, kit.CHURCH, cd, 0.3)                      # the nave front
        pen.poly([(x - 0.9, y), (x - 0.9, y - 2.4), (x, y - 3.4), (x + 0.9, y - 2.4), (x + 0.9, y)], kit.DOOR, None)
        if level >= 5:
            pen.circle(x, y - 5.6, 1.2, kit.DOOR)
        for sx in (-1, 1):                                # the towers
            x0 = x - 7.4 if sx < 0 else x + 1.9
            _block(pen, x0, y, 5.5, th, kit.CHURCH, cd, 0.32)
            pen.rect(x0 - 0.4, y - th - 0.9, 5.5 + 0.8, 1.2, cd, INK, 0.5)            # the flat top
            if sn:
                pen.rect(x0 - 0.4, y - th - 1.3, 3.8, 0.9, SNOW, None)
            pen.rect(x0 + 1.5, y - th + 2.0, 1.0, 3.2, kit.DOOR, None)                # the belfry louvre
            pen.line((x0, y - th + 6.6), (x0 + 5.5, y - th + 6.6), cd, 0.5)           # the gallery band
            pen.line((x0, y - 8.6), (x0 + 5.5, y - 8.6), cd, 0.5)
            for k in (0, 1):                                                           # lancets
                pen.poly([(x0 + 1.2 + k * 1.9, y - 5.0), (x0 + 1.2 + k * 1.9, y - 7.0), (x0 + 1.7 + k * 1.9, y - 7.9),
                          (x0 + 2.2 + k * 1.9, y - 7.0), (x0 + 2.2 + k * 1.9, y - 5.0)], kit.DOOR, None)
            for k in range(3):                                                         # the crenels on the flat top
                pen.rect(x0 + 0.6 + k * 2.0, y - th - 0.9, 0.9, 0.6, kit.shade(kit.CHURCH, 0.62), None)
        # the towers' flat tops are the level's silhouette: nothing stands higher than 20 px
    return p.stand(y, fn, x=x)


def moscow(p, level, x, y):
    """A white church with one GILT onion; at level 5 it grows into a cluster of four onion domes in the ONION
    colours at different heights (the ring wall in BRICK is the settlement's)."""
    sn = p.winter
    p.cast(x, y, 9)
    if level >= 5:
        p.cast(x + p.m * -8.2, y, 4.4)
        p.cast(x + p.m * 8.2, y, 4.4)
    wd = kit.shade(WHITE, 0.86)

    def chapel(pen, cx, yb, bw, bh, dh, dr, col):
        _block(pen, cx - bw / 2, yb, bw, bh, WHITE, wd, 0.3)
        pen.rect(cx - 0.4, yb - bh * 0.7, 0.8, bh * 0.55, kit.DOOR, None)
        _block(pen, cx - dr * 0.62, yb - bh, dr * 1.24, dh, WHITE, wd, 0.3)
        _onion(pen, cx, yb - bh - dh, dr, dr * 2.0, col, sn)

    def fn(pen):
        if level >= 5:
            chapel(pen, x + 4.2, y - 4.5, 3.6, 4.2, 5.0, 1.9, kit.ONION[3])           # the red one, higher at the back
            chapel(pen, x - 8.2, y - 1.2, 4.2, 3.6, 1.4, 2.0, kit.ONION[1])
            chapel(pen, x + 8.2, y - 0.8, 4.4, 4.2, 1.6, 2.2, kit.ONION[2])
        _block(pen, x - 4.5, y, 9.0, 5.4, WHITE, wd, 0.3)
        pen.poly([(x - 0.8, y), (x - 0.8, y - 2.2), (x, y - 3.0), (x + 0.8, y - 2.2), (x + 0.8, y)], kit.DOOR, None)
        for sx in (-2.8, 2.4):
            pen.rect(x + sx - 0.3, y - 4.0, 0.7, 1.8, kit.DOOR, None)
        _block(pen, x - 1.9, y - 5.4, 3.8, 2.4, WHITE, wd, 0.3)                       # the drum
        pen.rect(x - 0.3, y - 7.2, 0.7, 1.2, kit.DOOR, None)
        _onion(pen, x, y - 7.8, 2.9, 5.6, kit.ONION[0], sn, cross=True)
    return p.stand(y, fn, x=x)


_DRAW = {"venice": venice, "constantinople": constantinople, "paris": paris, "moscow": moscow}


def draw(p, name, level, x, y):
    """The monument `name` at `level` (4 or 5), its foot at (x, y); every part is queued round the axis x."""
    assert level in (4, 5), "a landmark replaces the church (level 4) and the cathedral (level 5) only"
    return _DRAW[name](p, level, x, y)


def caps(p, name, spots, w=4.6, h=5.0):
    """Pointed caps on the ring wall's towers (Moscow). spots: (x, foot_y, tower_height) as the tower is drawn in
    the piece (already mirrored: the same numbers the wall used). Queued with x=0: they are not moved again."""
    col = CAPS[name]
    sn = p.winter
    for qx, qy, th in spots:
        def fn(pen, qx=qx, qy=qy, th=th):
            _cone(pen, qx, qy - th, w, h, col, kit.shade(col, 0.74), sn)
        p.stand(qy + 0.1, fn, x=0)


# ------------------------------------------------------------------ the sheet
def sheet(path):
    import pygame
    import settlements
    seasons = (("summer", None), ("winter", "snow"))
    rows = []
    for name in NAMES:
        cells = []
        for v in (0, 1):
            for lv in (4, 5):
                for se, cl in seasons:
                    cells.append((lv, se, cl, v, kit.with_wild(settlements.draw, lv, se, variant=v, landmark=name, climate=cl)))
        rows.append((name, cells))
    pad, gap, left, top = 4, 4, 150, 70
    cw = kit.SIZE + pad * 2
    n = 8
    W = left + n * (cw + gap) + 16
    strip_h = 2 * (cw // 2 + gap) + 56
    H = top + len(rows) * (cw + gap) + 30 + strip_h
    out = pygame.Surface((W, H))
    out.fill(kit.SHEET_BG)
    f_t, f_h, f_s = kit._font(30, True), kit._font(22), kit._font(16)
    out.blit(f_t.render("Landmark cities: levels 4 and 5, summer and winter, both layouts", True, kit.SHEET_TEXT), (16, 12))
    heads = ["L%d %s" % (lv, se[:3]) for v in (0, 1) for lv in (4, 5) for se in ("summer", "winter")]
    for j in range(n):
        x = left + j * (cw + gap)
        out.blit(f_s.render(heads[j], True, kit.SHEET_DIM), (x + 6, top - 22))
        if j in (0, 4):
            out.blit(f_s.render("layout %d" % (j // 4), True, kit.SHEET_TEXT), (x + 6, top - 40))
    for i, (name, cells) in enumerate(rows):
        y = top + i * (cw + gap)
        out.blit(f_h.render(name.capitalize(), True, kit.SHEET_TEXT), (12, y + 52))
        for j, (lv, se, cl, v, img) in enumerate(cells):
            out.blit(kit._cell(img, se, 1.0, pad, "grass", cl), (left + j * (cw + gap), y))
    # the 50% strip: a plain level 5 city at its head, then every monument at level 4 and 5 (summer, layout 0)
    sy = top + len(rows) * (cw + gap) + 8
    out.blit(f_h.render("50%: a plain level 5 city, then each city's levels 4 and 5 (summer, layout 0; below: winter)", True, kit.SHEET_TEXT), (12, sy))
    hw = cw // 2
    for r, (se, cl) in enumerate(seasons):
        y = sy + 30 + r * (hw + gap)
        x = 12
        items = [("plain", kit.with_wild(settlements.draw, 5, se, climate=cl))]
        for name in NAMES:
            for lv in (4, 5):
                items.append((name, kit.with_wild(settlements.draw, lv, se, landmark=name, climate=cl)))
        for k, (nm, img) in enumerate(items):
            out.blit(kit._cell(img, se, 0.5, pad, "grass", cl), (x + k * (hw + 3), y))
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    pygame.image.save(out, path)
    return out


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "design", "map", "pieces", "landmarks.png")
    sheet(out)
    print("wrote", os.path.normpath(out))
