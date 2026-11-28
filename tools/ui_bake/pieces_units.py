"""The unit figures of option D (docs/design/recruitment-queue.md 11 and 12.2, UR1; docs/design/ui/unit-looks/mockup.html,
approved 2026-11-28): the old game's chunky figures, in the country's colour, with more detail.

| Piece | Size (1x) | What |
|---|---|---|
| `unit_figures` | 256 x 128 | the fixed colours of each kind: row 0 full detail (cards, close zoom), row 1 simplified (normal map zoom) |
| `unit_figures_tint` | 256 x 128 | the same cells: where the country's colour goes, white (drawn first, modulated by the colour) |
| `unit_signs` | 96 x 24 | the far-zoom sign of each kind, white (modulated by the country colour darkened by half) |
| `figures` | 128 x 32 | today's 32 px figure cells, now D's small card form (one man; the horse and the gun cropped) in one fixed colour |

A cell of `unit_figures` is the mockup's 64 px box at 0.9, centred (`BOX_K`, `BOX_X`, `BOX_Y`), so the pike butts, the
raised sword and the shot stay inside it: the feet stand on y `FEET_Y` (55.4) at the cell's x centre, and a cell drawn
at 64 / 0.9 = 71 px shows the box at the mockup's 64. The game draws
the tint cell modulated by the country's colour and the figure cell over it (`figure_paint.split_tint`), the same
two-sprite way as today's plate. Each kind is one entry of `KINDS` (its name, its drawing and its sign), so the nine old
types of the next feature are new entries: `d_man` already takes the hat, armour and weapon as options.
"""
from __future__ import annotations

from typing import Callable

import numpy as np

from .checks import BakeCheckError
from .figure_paint import COUNTRY, FigurePainter, compose_tinted, hex_rgb, mix_hex, split_tint, tt
from .tokens import TokenTable

CELL = 64
SMALL_CELL = 32
SIGN_CELL = 24
SIGN_MARGIN = 1.0  # the mockup's 24 px sign box drawn at 22/24, so the gun's trail stays inside the cell
BOX_K = 0.9  # the mockup's 64 px box drawn at 0.9 ...
BOX_X = 3.2  # ... centred in the cell (3.2 px each side), so the pike butts, the raised sword and the shot stay inside it
BOX_Y = 3.2
FEET_Y = BOX_Y + 58.0 * BOX_K  # 55.4: the ground line of the box in the cell
LEVELS: tuple[str, ...] = ("full", "simple")
OW_FULL = 1.6
OW_SIMPLE = 2.5
OW_SMALL_MAN = 2.4
NEUTRAL = "#efe3c4"  # the colour of the coats in the one-layer `figures` cells (the vellum of the cards)

# The mockup's DC palette.
DC = {
    "steel": "#c3cbd5", "wood": "#a8743c", "dwood": "#6e4426", "skin": "#e8b98f", "hair": "#4a2f1e", "leather": "#7a5232",
    "boot": "#8a6a42", "vellum": "#efe3c4", "hose": "#4a3a2e", "felt": "#3a2c22", "gunmetal": "#585e68", "iron": "#6f7884",
    "bronze": "#c08a3e", "stone": "#b4ab98", "bay": "#93552e", "grey": "#b9b3a8", "black": "#3f3229", "darmour": "#4a4f58",
    "gold": "#e8c15a", "shoe": "#2b2219",
}
WHITE = "#ffffff"
BLACK = "#000000"


# ---------------------------------------------------------------- the parts

def d_man(p: FigurePainter, o: dict, d: int) -> None:
    """One foot soldier, feet at (0, 0), facing the viewer. o: hat, armour, jack, beard, arms (the mockup's dMan)."""
    c = COUNTRY
    hose = o.get("hose", DC["hose"])
    p.dl(-2.8, -12.0, -3.3, -2.0, 4.2, hose)
    p.dl(2.8, -12.0, 3.3, -2.0, 4.2, mix_hex(hose, BLACK, 0.2))
    p.fill(p.ell(-4.0, -0.9, 3.2, 1.6), DC["shoe"])
    p.fill(p.ell(4.2, -0.9, 3.2, 1.6), DC["shoe"])
    arms = o.get("arms", "")
    if arms == "xbowup" and d > 1:
        # the bolt quiver at the hip
        p.fill(p.rect(7.2, -20.0, 10.4, -11.5, 0.6), DC["leather"])
        p.ln(7.8, -20.5, 7.2, -23.0, 1.0, DC["vellum"])
        p.ln(9.6, -20.5, 10.4, -23.0, 1.0, DC["vellum"])
    p.fill(p.poly([(-7.0, -28.0), (7.0, -28.0), (8.4, -11.0), (-8.4, -11.0)]), tt(c))
    if o.get("jack") and d > 1:
        for x in (-3.6, 0.0, 3.6):
            p.ln(x, -27.0, x * 1.15, -12.4, 0.8, BLACK, 0.3)
    if o.get("armour"):
        p.fill(p.poly([(-6.2, -27.4), (6.2, -27.4), (6.8, -17.6), (0.0, -14.8), (-6.8, -17.6)]), tt(DC["steel"]))
        if d > 1:
            p.ln(0.0, -27.0, 0.0, -15.6, 0.7, WHITE, 0.5)
            p.hl(-4.0, -25.2, -4.6, -19.0)
            p.fill(p.poly([(-7.2, -16.6), (-1.0, -14.4), (-1.4, -11.2), (-7.8, -12.4)]), tt(DC["steel"]))
            p.fill(p.poly([(7.2, -16.6), (1.0, -14.4), (1.4, -11.2), (7.8, -12.4)]), tt(DC["steel"]))
    p.fill(p.rect(-8.4, -14.2, 8.4, -12.0, 0.5), DC["leather"])
    if d > 1:
        p.fill(p.rect(-1.3, -14.4, 1.3, -11.8, 0.3), DC["gold"], ink=False)
    p.fill(p.circle(0.0, -33.0, 4.8), tt(DC["skin"], 0.08, 0.12))
    if d > 1:
        p.dot(-1.6, -33.4, 0.6)
        p.dot(1.6, -33.4, 0.6)
        p.ln(-1.0, -30.4, 1.0, -30.4, 0.7, "INK", 0.6)
        if o.get("beard"):
            p.fill(p.path("M-4.4 -32.2 Q0 -26 4.4 -32.2 Q0 -29.4 -4.4 -32.2 Z"), DC["hair"], ink=False)
    if o.get("hat") == "kettle":
        p.fill(p.path("M-5 -35.4 C-5 -42.8 5 -42.8 5 -35.4 Z"), tt(DC["steel"]))
        p.fill(p.ell(0.0, -35.6, 8.4, 2.1), tt(DC["steel"]))
        if d > 1:
            p.hl(-3.0, -37.2, -2.2, -40.2, 1.0)
    wk = 1.0 if d > 1 else 1.4

    def arm(x1: float, y1: float, x2: float, y2: float) -> None:
        p.dl(x1, y1, x2, y2, 3.8, c)
        p.fill(p.circle(x2, y2, 1.9), DC["skin"])

    if arms == "pike":
        px = 9.6
        p.dl(px, 2.0, px, -52.6, 2.1 * wk, DC["wood"])
        p.fill(p.poly([(px, -57.4), (px + 2.5, -52.6), (px, -48.8), (px - 2.5, -52.6)]), tt(DC["steel"]))
        if d > 1:
            p.fill(p.rect(px - 1.5, -48.6, px + 1.5, -46.4, 0.4), c, ink=False)
        arm(7.0, -26.0, px - 0.4, -21.0)
        arm(-7.0, -26.0, -9.6, -14.8)
        p.dl(-11.6, -13.0, -7.6, -15.6, 1.5, DC["gold"])
        if d > 1:
            p.dl(-9.0, -13.6, -12.8, -2.6, 1.7, DC["dwood"])
    elif arms == "xbow":
        arm(7.0, -26.0, 3.4, -22.4)
        p.dl(-3.4, -22.2, 15.0, -24.6, 2.8 * wk, DC["wood"])
        p.fill(p.polyline("M13 -30.8 Q17.6 -24.6 13 -18.4", 2.3), DC["steel"])
        if d > 1:
            p.line_path("M13 -30.8 L9.4 -24.4 L13 -18.4", 0.7)
            p.fill(p.circle(15.4, -24.8, 0.9), DC["steel"], ow=0.8)
        arm(-7.0, -26.0, 10.4, -24.2)
    elif arms == "xbowup":
        arm(-7.0, -26.0, -9.4, -15.2)
        p.dl(4.6, -17.0, 13.4, -40.4, 2.6 * wk, DC["wood"])
        p.fill(p.polyline("M8.4 -42.6 Q13.6 -44.6 18.2 -38.4", 2.3), DC["steel"])
        if d > 1:
            p.line_path("M8.4 -42.6 L10.8 -35.4 L18.2 -38.4", 0.7)
        arm(7.0, -26.0, 7.4, -21.6)


def d_banner(p: FigurePainter, x: float, top: float, d: int) -> None:
    """A swallow-tailed banner in the country's colour on a pole from the ground at y 57 (the mockup's dBanner)."""
    p.dl(x, 57.0, x, top, 1.5, DC["dwood"])
    p.fill(p.circle(x, top - 1.0, 1.6), DC["gold"])
    p.fill(p.poly([(x + 0.8, top + 0.6), (x + 13.0, top + 0.6), (x + 10.0, top + 5.0), (x + 13.0, top + 9.4), (x + 0.8, top + 9.4)]), tt(COUNTRY))
    if d > 1:
        p.ln(x + 1.4, top + 1.8, x + 11.0, top + 1.8, 0.8, DC["gold"], 0.9)
        p.fill(p.circle(x + 5.6, top + 5.0, 1.6), DC["vellum"], ink=False)


def d_horse(p: FigurePainter, hc: str, hair: str, d: int, chanfron: bool = False) -> None:
    """The horse in side view facing right (the mockup's dHorse); hc its coat, hair its mane and tail."""
    h2 = mix_hex(hc, BLACK, 0.25)
    p.dl(22.0, 44.0, 23.5, 51.0, 3.8, h2)
    p.dl(23.5, 51.0, 22.5, 56.6, 2.6, h2)
    p.fill(p.rect(20.6, 56.0, 24.4, 58.4, 0.6), DC["shoe"])
    p.dl(43.0, 44.0, 45.4, 51.0, 3.6, h2)
    p.dl(45.4, 51.0, 45.0, 56.6, 2.6, h2)
    p.fill(p.rect(43.2, 56.0, 47.0, 58.4, 0.6), DC["shoe"])
    p.fill(p.path("M15 35 C8.5 38 8 47 10.5 54 L13.6 53.2 C12.4 47 13.5 42 17.5 39 Z"), hair)
    p.fill(p.circle(18.5, 39.0, 8.2), tt(hc))
    p.fill(p.ell(30.0, 40.0, 15.6, 7.8), tt(hc))
    p.fill(p.circle(42.5, 40.0, 6.6), tt(hc))
    p.fill(p.poly([(38.0, 35.0), (42.5, 26.0), (46.0, 19.5), (50.5, 20.0), (52.0, 26.5), (48.0, 34.5), (47.5, 42.0)]), tt(hc))
    p.fill(p.path("M46.5 18.6 Q49 16.4 52.4 19.6 L58.6 28 Q59.4 31.6 55.6 31.8 L51 29.4 Q49.6 27.2 48.4 25.4 Z"), tt(hc, 0.1, 0.18))
    p.fill(p.poly([(47.2, 19.4), (48.0, 13.8), (50.2, 18.6)]), hc)
    if d > 1:
        p.fill(p.path("M46.6 18 L44.6 21.4 L45.8 22 L43 25.4 L44.4 26 L41.2 29.6 L42.6 30.2 L39 33.6 L42 33.6 Q47 27 48.6 20 Z"), hair)
        p.dot(51.4, 22.6, 0.9, "#1b1510")
        p.dot(57.6, 28.8, 0.7, "#1b1510")
        p.line_path("M55 30.6 Q57 32 58.8 30", 0.6, "#1b1510")
    else:
        p.dl(46.2, 19.6, 40.2, 32.0, 2.6, hair)
    if chanfron:
        p.fill(p.path("M48.8 18.8 L56.8 27.2 L54.8 29 L48.6 22.6 Z"), tt(DC["steel"]))
    p.dl(15.5, 43.5, 14.6, 51.0, 4.2, hc)
    p.dl(14.6, 51.0, 16.8, 56.6, 2.8, hc)
    p.fill(p.rect(14.8, 56.0, 18.8, 58.4, 0.6), DC["shoe"])
    p.dl(40.0, 45.0, 39.0, 51.5, 3.8, hc)
    p.dl(39.0, 51.5, 40.6, 56.6, 2.8, hc)
    p.fill(p.rect(38.6, 56.0, 42.6, 58.4, 0.6), DC["shoe"])


# ---------------------------------------------------------------- the four kinds of today (64 px box, ground at y 58)

PIKEMAN = {"hat": "kettle", "armour": True, "arms": "pike"}
CROSSBOWMAN = {"hat": "kettle", "jack": True, "arms": "xbow"}


def fig_pikemen(p: FigurePainter, d: int) -> None:
    # Two men in kettle hats and breastplates, pikes upright, swords at the hip, the banner behind them.
    d_banner(p, 5.0, 3.0, d)
    with p.push(20.0, 58.0):
        d_man(p, PIKEMAN, d)
    with p.push(41.0, 58.0):
        d_man(p, {**PIKEMAN, "beard": True}, d)


def fig_crossbowmen(p: FigurePainter, d: int) -> None:
    # Two men in quilted jacks, one spanning his crossbow upright, one aiming, behind a pavise in the country's colour.
    # (2 px left of the mockup's places, so the raised bow stays inside the cell)
    with p.push(44.0, 58.0):
        d_man(p, {"hat": "kettle", "jack": True, "arms": "xbowup"}, d)
    with p.push(20.0, 58.0):
        d_man(p, {**CROSSBOWMAN, "beard": True}, d)
    with p.push(8.0, 58.0):
        p.fill(p.path("M-6.4 0 L-6.4 -27 Q0 -33 6.4 -27 L6.4 0 Z"), tt(COUNTRY, 0.16, 0.3))
        if d > 1:
            p.ln(0.0, -29.6, 0.0, -1.0, 0.8, WHITE, 0.45)
        p.fill(p.circle(0.0, -15.0, 3.6), DC["vellum"])
        if d > 1:
            p.dl(0.0, -17.2, 0.0, -12.8, 1.1, COUNTRY)
            p.dl(-2.2, -15.0, 2.2, -15.0, 1.1, COUNTRY)


def fig_knights(p: FigurePainter, d: int) -> None:
    # A knight in a great helm, sword raised, shield on the arm, on a horse with a steel face plate and a barding.
    c = COUNTRY
    d_horse(p, DC["bay"], DC["hair"], d, chanfron=True)
    p.fill(p.path("M14.5 33.5 L44 33.5 Q48.5 36 48 42 L47.6 48 L44.4 46.4 L41.2 49 L38 46.4 L34.8 49 L31.6 46.4 L28.4 49 "
                  "L25.2 46.4 L22 49 L18.8 46.4 L15.6 49 L12.6 47 Q10.6 40 14.5 33.5 Z"), tt(c))
    if d > 1:
        p.line_path("M15.6 47.4 L18.8 45 L22 47.4 L25.2 45 L28.4 47.4 L31.6 45 L34.8 47.4 L38 45 L41.2 47.4 L44.4 45 L47 46.4", 0.9, DC["gold"])
        p.fill(p.rect(20.0, 37.0, 22.4, 45.0, 0.2), DC["vellum"])
        p.fill(p.rect(17.2, 39.8, 25.2, 42.2, 0.2), DC["vellum"])
    p.dl(31.0, 33.0, 33.6, 40.5, 4.4, DC["steel"])
    p.dl(33.6, 40.5, 32.0, 46.0, 3.4, DC["steel"])
    p.fill(p.ell(33.2, 46.6, 2.6, 1.4), DC["shoe"])
    p.fill(p.poly([(26.5, 19.5), (35.5, 19.5), (36.5, 33.5), (25.5, 33.5)]), tt(c))
    p.fill(p.path("M22.8 22.5 L31.2 22.5 L31.2 29 Q31.2 34.6 27 37 Q22.8 34.6 22.8 29 Z"), tt(DC["vellum"], 0.05, 0.16))
    p.fill(p.rect(25.8, 22.6, 28.2, 36.0, 0.0), c, ink=False)
    p.fill(p.rect(22.9, 26.6, 31.1, 29.0, 0.0), c, ink=False)
    p.fill(p.path("M27.4 9.6 Q31.5 6.8 35.6 9.6 L35.8 19.6 L27.2 19.6 Z"), tt(DC["steel"]))
    p.ln(30.4, 13.6, 35.6, 13.6, 1.2)
    p.fill(p.path("M28 8.8 Q23.6 2.6 17.8 5.2 Q23.2 6.6 27.4 10.6 Z"), c)
    if d > 1:
        for (x, y) in ((33.6, 16.4), (34.8, 16.4), (33.6, 17.6), (34.8, 17.6)):
            p.dot(x, y, 0.45)
        p.hl(28.8, 11.0, 28.6, 18.0, 1.0)
    p.dl(34.5, 22.0, 40.0, 14.6, 3.6, DC["steel"])
    p.dl(41.0, 13.0, 50.6, 1.6, 2.0, DC["steel"])
    p.dl(38.6, 11.4, 43.2, 15.4, 1.6, DC["gold"])
    p.fill(p.circle(40.4, 14.0, 1.9), DC["leather"])
    if d > 1:
        p.hl(42.4, 11.4, 49.6, 2.6, 0.7, WHITE, 0.7)


def fig_bombards(p: FigurePainter, d: int) -> None:
    # A hooped iron barrel on its timber bed, stone shot beside it, the banner behind.
    d_banner(p, 7.0, 14.0, d)
    p.fill(p.path("M5 48 L49 48 L54 55.6 L7 55.6 Z"), tt(DC["wood"]))
    if d > 1:
        p.ln(6.0, 51.8, 51.6, 51.8, 0.8, BLACK, 0.35)
        for x in (12.0, 30.0, 46.0):
            p.dot(x, 50.0, 0.8, DC["gunmetal"])
    p.fill(p.poly([(9.0, 42.5), (11.6, 35.6), (47.6, 30.2), (51.6, 33.6), (51.6, 42.0), (47.6, 45.6), (11.6, 49.0)]), tt(DC["iron"], 0.18, 0.3))
    for t in ((0.08, 0.22, 0.36, 0.5, 0.64, 0.78, 0.92) if d > 1 else (0.2, 0.5, 0.8)):
        x = 11.6 + t * 36.0
        p.ln(x, 35.6 - 5.4 * t, x, 49.0 - 3.4 * t, 2.0 if d > 1 else 2.4)
        if d > 1:
            p.ln(x - 0.7, 36.2 - 5.4 * t, x - 0.7, 48.4 - 3.4 * t, 0.6, WHITE, 0.4)
    p.fill(p.ell(51.4, 37.8, 3.4, 6.2), tt(DC["iron"]))
    p.fill(p.ell(51.8, 37.8, 2.0, 4.0), "#15110e")
    if d > 1:
        p.hl(14.0, 37.6, 45.0, 32.4, 1.2, WHITE, 0.35)
    p.fill(p.circle(57.6, 54.4, 3.4), tt(DC["stone"]))
    p.fill(p.circle(61.0, 56.2, 2.4), tt(DC["stone"]))
    if d > 1:
        p.fill(p.circle(59.4, 50.8, 2.6), tt(DC["stone"]))


# ---------------------------------------------------------------- the far-zoom signs (24 px box, the mockup's `sign`)

def sign_xpike(p: FigurePainter) -> None:
    p.fill(p.seg(5.0, 21.4, 18.0, 4.4, 2.4), WHITE, ink=False)
    p.fill(p.seg(19.0, 21.4, 6.0, 4.4, 2.4), WHITE, ink=False)
    p.fill(p.poly([(20.2, 1.2), (15.6, 3.8), (18.8, 7.0)]), WHITE, ink=False)
    p.fill(p.poly([(3.8, 1.2), (8.4, 3.8), (5.2, 7.0)]), WHITE, ink=False)


def sign_bow(p: FigurePainter) -> None:
    p.fill(p.polyline("M2.4 10.4 Q12 2.8 21.6 10.4", 3.0), WHITE, ink=False)
    p.fill(p.polyline("M3 10.6 L12 15 L21 10.6", 1.1), WHITE, ink=False)
    p.fill(p.rect(10.5, 6.0, 13.5, 22.8, 1.0), WHITE, ink=False)
    p.fill(p.poly([(12.0, 1.2), (14.0, 5.6), (10.0, 5.6)]), WHITE, ink=False)
    p.fill(p.rect(8.6, 19.6, 15.4, 22.2, 1.0), WHITE, ink=False)


def sign_horse(p: FigurePainter) -> None:
    p.fill(p.path("M5.2 22.6 L6.2 17.2 C6.4 13.2 8.2 10 10.8 7.6 L11.2 2.6 L13.8 5.4 L15.8 3.2 L16.6 6.4 C19.2 8.2 21 10.8 "
                  "21.8 13.6 C22.2 15.2 20.8 16.6 19.2 15.8 L15.8 14 C14.6 14.8 14.4 16.2 15.4 17.8 L18.4 22.6 Z"), WHITE, ink=False)
    p.cut(p.circle(15.6, 9.0, 1.2))


def sign_gun(p: FigurePainter) -> None:
    p.fill(p.seg(6.0, 15.4, 19.6, 7.4, 6.4), WHITE, ink=False)
    p.fill(p.circle(20.2, 7.0, 3.8), WHITE, ink=False)
    p.cut(p.circle(20.6, 6.8, 1.5))
    p.fill(np.abs(p.circle(8.6, 16.4, 5.0)) - 1.15 * p._tf[2], WHITE, ink=False)
    p.fill(p.circle(8.6, 16.4, 1.6), WHITE, ink=False)
    p.fill(p.seg(4.2, 19.8, 1.6, 22.4, 2.3), WHITE, ink=False)


# ---------------------------------------------------------------- the small card form (32 px, the mockup's portrait < 56 px)

def small_man(o: dict, vb: tuple[float, float, float, float]) -> Callable[[FigurePainter], None]:
    def draw(p: FigurePainter) -> None:
        p.ow = OW_SMALL_MAN
        x0, y0, w, h = vb
        k = SMALL_CELL / max(w, h)
        with p.push(0.5 * (SMALL_CELL - w * k) - x0 * k, 0.5 * (SMALL_CELL - h * k) - y0 * k, k):
            d_man(p, o, 1)
    return draw


def small_whole(fig: Callable[[FigurePainter, int], None], vb: tuple[float, float, float, float]) -> Callable[[FigurePainter], None]:
    def draw(p: FigurePainter) -> None:
        p.ow = OW_SIMPLE
        x0, y0, w, h = vb
        k = SMALL_CELL / max(w, h)
        with p.push(0.5 * (SMALL_CELL - w * k) - x0 * k, 0.5 * (SMALL_CELL - h * k) - y0 * k, k):
            fig(p, 1)
    return draw


# One entry per kind, in UnitDef.FIGURE_NAMES order: the figure, its far sign, its small card form (the mockup's DSINGLE
# one man and DVB crop, with view boxes grown to the whole drawing plus 1.5 units, so nothing is cut at the cell edge).
KINDS: tuple[tuple[str, Callable[[FigurePainter, int], None], Callable[[FigurePainter], None], Callable[[FigurePainter], None]], ...] = (
    ("fig_infantry", fig_pikemen, sign_xpike, small_man(PIKEMAN, (-15.5, -60.5, 30.5, 67.0))),
    ("fig_missile", fig_crossbowmen, sign_bow, small_man(CROSSBOWMAN, (-12.0, -44.0, 32.0, 47.5))),
    ("fig_cavalry", fig_knights, sign_horse, small_whole(fig_knights, (6.0, -2.5, 55.5, 64.0))),
    ("fig_artillery", fig_bombards, sign_gun, small_whole(fig_bombards, (2.0, 8.5, 64.5, 53.0))),
)
FIGURE_NAMES: tuple[str, ...] = tuple(k[0] for k in KINDS)
UNIT_FIGURE_NAMES: tuple[str, ...] = tuple(f"{n}_{lv}" for lv in LEVELS for n in FIGURE_NAMES)
UNIT_TINT_NAMES: tuple[str, ...] = tuple(f"{n}_tint" for n in UNIT_FIGURE_NAMES)
SIGN_NAMES: tuple[str, ...] = tuple("sign_" + n[len("fig_"):] for n in FIGURE_NAMES)
UNIT_FIGURES_SIZE = (CELL * len(KINDS), CELL * len(LEVELS))
SIGNS_SIZE = (SIGN_CELL * len(KINDS), SIGN_CELL)
SMALL_SIZE = (SMALL_CELL * len(KINDS), SMALL_CELL)


def _finish(out: np.ndarray) -> np.ndarray:
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _ink(tokens: TokenTable) -> np.ndarray:
    return np.asarray(tokens.rgb("INK"), dtype=np.float64)


def paint_figure(index: int, level: str, s: int, tokens: TokenTable, c: np.ndarray) -> np.ndarray:
    """One 64 px cell of kind `index` at `level`, painted for the country colour c (straight-alpha float RGBA)."""
    p = FigurePainter(CELL, CELL, s, _ink(tokens), c)
    full = level == "full"
    p.ow = OW_FULL if full else OW_SIMPLE
    with p.push(BOX_X, BOX_Y, BOX_K):
        KINDS[index][1](p, 2 if full else 1)
    return p.out


def figure_layers(index: int, level: str, s: int, tokens: TokenTable) -> tuple[np.ndarray, np.ndarray]:
    """The figure and tint layers of one cell (float RGBA)."""
    black = paint_figure(index, level, s, tokens, np.zeros(3))
    white = paint_figure(index, level, s, tokens, np.ones(3))
    return split_tint(black, white)


def _atlas(s: int, tokens: TokenTable, layer: int) -> np.ndarray:
    w, h = UNIT_FIGURES_SIZE
    atlas = np.zeros((h * s, w * s, 4), dtype=np.float64)
    for row, level in enumerate(LEVELS):
        for i in range(len(KINDS)):
            atlas[row * CELL * s : (row + 1) * CELL * s, i * CELL * s : (i + 1) * CELL * s] = figure_layers(i, level, s, tokens)[layer]
    return _finish(atlas)


def render_unit_figures(s: int, tokens: TokenTable) -> np.ndarray:
    return _atlas(s, tokens, 0)


def render_unit_figures_tint(s: int, tokens: TokenTable) -> np.ndarray:
    return _atlas(s, tokens, 1)


def render_unit_signs(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = SIGNS_SIZE
    atlas = np.zeros((h * s, w * s, 4), dtype=np.float64)
    for i, kind in enumerate(KINDS):
        p = FigurePainter(SIGN_CELL, SIGN_CELL, s, _ink(tokens), np.ones(3))
        with p.push(SIGN_MARGIN, SIGN_MARGIN, (SIGN_CELL - 2.0 * SIGN_MARGIN) / SIGN_CELL):
            kind[2](p)
        atlas[:, i * SIGN_CELL * s : (i + 1) * SIGN_CELL * s] = p.out
    return _finish(atlas)


def render_small_figures(s: int, tokens: TokenTable) -> np.ndarray:
    """Today's `figures` atlas: D's small card form, the coats in NEUTRAL (one layer, drawn as today's figures were)."""
    w, h = SMALL_SIZE
    atlas = np.zeros((h * s, w * s, 4), dtype=np.float64)
    for i, kind in enumerate(KINDS):
        p = FigurePainter(SMALL_CELL, SMALL_CELL, s, _ink(tokens), hex_rgb(NEUTRAL))
        kind[3](p)
        atlas[:, i * SMALL_CELL * s : (i + 1) * SMALL_CELL * s] = p.out
    return _finish(atlas)


# ---------------------------------------------------------------- the asserts

def check_unit_pieces(rendered: dict[tuple[str, int], np.ndarray]) -> None:
    """Each cell is drawn and clear of its edge; the tint layer is white with country colour in every figure; the
    two layers put back the painting for a country colour; full and simplified differ. Errors are gathered, then raised once."""
    problems: list[str] = []
    for s in (1, 2):
        figs = rendered.get(("unit_figures", s))
        tint = rendered.get(("unit_figures_tint", s))
        signs = rendered.get(("unit_signs", s))
        for name, arr, cell, cols, rows in (("unit_figures", figs, CELL, len(KINDS), len(LEVELS)),
                                            ("unit_signs", signs, SIGN_CELL, len(KINDS), 1)):
            if arr is None:
                continue
            n = cell * s
            cells = arr[..., 3].reshape(rows, n, cols, n).transpose(0, 2, 1, 3).reshape(rows * cols, n, n)
            drawn = (cells == 255).sum(axis=(1, 2))
            edge = np.maximum.reduce([cells[:, 0, :].max(axis=1), cells[:, -1, :].max(axis=1), cells[:, :, 0].max(axis=1), cells[:, :, -1].max(axis=1)])
            for idx in np.flatnonzero(drawn < n * n // 16):
                problems.append(f"{name} cell {idx}@{s}x is hardly drawn")
            for idx in np.flatnonzero(edge > 200):
                problems.append(f"{name} cell {idx}@{s}x touches its cell edge")
        if tint is not None:
            n = CELL * s
            a = tint[..., 3].reshape(len(LEVELS), n, len(KINDS), n).transpose(0, 2, 1, 3).reshape(-1, n, n)
            for idx in np.flatnonzero((a > 128).sum(axis=(1, 2)) < n * n // 64):
                problems.append(f"unit_figures_tint cell {idx}@{s}x has hardly any country colour")
            if int(tint[..., :3][tint[..., 3] > 0].min(initial=255)) != 255:
                problems.append(f"unit_figures_tint@{s}x is not white where it is drawn")
        if figs is not None:
            n = CELL * s
            full = figs[:n].astype(np.int32)
            simple = figs[n : 2 * n].astype(np.int32)
            same = [i for i in range(len(KINDS)) if np.array_equal(full[:, i * n : (i + 1) * n], simple[:, i * n : (i + 1) * n])]
            problems += [f"unit_figures kind {i}@{s}x: full and simplified are the same" for i in same]
    if problems:
        raise BakeCheckError("; ".join(problems))


def check_split_exact(tokens: TokenTable, colours: list[tuple[int, int, int]], s: int = 1, index: int = 0, level: str = "full") -> float:
    """The largest 8-bit error between the painting for a colour and the two baked layers drawn the game's way."""
    fig, tint = figure_layers(index, level, s, tokens)
    fig8 = _finish(fig).astype(np.float64) / 255.0
    tint8 = _finish(tint).astype(np.float64) / 255.0
    worst = 0.0
    for col in colours:
        c = np.asarray(col, dtype=np.float64) / 255.0
        want = paint_figure(index, level, s, tokens, c)
        got = compose_tinted(fig8, tint8, c)
        wp = want[..., :3] * want[..., 3:4]
        gp = got[..., :3] * got[..., 3:4]
        worst = max(worst, float(np.abs(wp - gp).max()) * 255.0, float(np.abs(want[..., 3] - got[..., 3]).max()) * 255.0)
    return worst
