"""Slice 6 war pieces (m7-build-spec.md 6.2): two battle and siege badges, a bone die face, 24 war icons.

| Piece | Size (1x) | What |
|---|---|---|
| `badge_battle` | 40 x 40 | crossed swords on a dark roundel, ink outline (the ring is drawn at run time in the result's tone) |
| `badge_siege` | 40 x 40 | a gate tower on a dark roundel (the amber dial is drawn at run time) |
| `icons_war` | 192 x 72 | 8 columns x 3 rows of 24 px cells, in `WAR_ICON_NAMES` order |
| `die_face` | 28 x 28 | a bone d6 face; the pips are drawn at run time by `DieFace` in `VELLUM_INK` |

Everything is a signed distance in logical pixels, so 2x is the same recipe at `s = 2`, never an upscale; pixel paths use
only `+ - x /`, `sqrt`, `floor` and comparisons on float64. Angles are literal constants (no trigonometry). The icons are
two-tone woodcut like the slice 4 and 5 icons (an ink line round flat pigment).

`standing_hold` is the one name that differs from the spec's list: slice 5's `icons_army` already names `hold` (the army
order), and the theme registers Kit icons by one global name, so the standing icon takes the constant's name
(`STANDING_HOLD`, m7 spec row 17). `write_war_sheet` composes the sheet the art director signs: both badges in three tones
at r8, r13 and r34, the 24 icons, the die faces 1 to 6 and the siege dial on its track.
"""
from __future__ import annotations

from pathlib import Path
from typing import Callable

import numpy as np

from .checks import MIN_CONTRAST, BakeCheckError
from .icons import _Canvas
from .pieces_frames import PieceSpec
from .pieces_m6 import high_contrast_colours
from .png import save_png
from .shapes import blend_rgb_mask, coverage, logical_grid, sd_rounded_rect
from .tokens import TokenTable, contrast_ratio

WAR_ICON_NAMES: tuple[str, ...] = (
    "war", "peace", "truce", "battle", "siege", "storm", "besiege", "attack",
    "standing_hold", "withdraw", "flee", "victory", "defeat", "fortress", "garrison", "area_held",
    "area_open", "routed", "shaken", "fires", "occupied", "uphill", "pass_cross", "river_cross",
)
ICON_CELL = 24
ICON_COLUMNS = 8
ICONS_SIZE = (192, 72)
BADGE_SIZE = (40, 40)
DIE_SIZE = (28, 28)


def _finish(out: np.ndarray) -> np.ndarray:
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _rgb(tokens: TokenTable, name: str) -> np.ndarray:
    return np.asarray(tokens.rgb(name), dtype=np.float64)


class _Cv(_Canvas):
    """`_Canvas` on a cell of any size (the badges and the die face are not 24 px)."""

    def __init__(self, w: int, h: int, s: int, tokens: TokenTable) -> None:
        super().__init__(s, tokens)
        self.lx, self.ly = logical_grid(w, h, s)
        self.out = np.zeros((h * s, w * s, 4), dtype=np.float64)


def _arrow(c: _Cv, x0: float, y0: float, x1: float, y1: float, colour: str, shaft: float = 3.0, head: float = 4.4) -> None:
    """An arrow from (x0, y0) to (x1, y1) with a triangular head (ink line round the whole)."""
    dx, dy = x1 - x0, y1 - y0
    ln = (dx * dx + dy * dy) ** 0.5
    ux, uy = dx / ln, dy / ln
    px, py = -uy, ux
    bx, by = x1 - ux * head * 1.1, y1 - uy * head * 1.1
    body = np.minimum(c.cap(x0, y0, bx + ux * 0.6, by + uy * 0.6, shaft), c.poly([(x1, y1), (bx + px * head, by + py * head), (bx - px * head, by - py * head)]))
    c.fill(body, colour)


def _sword(c: _Cv, px: float, py: float, tx: float, ty: float) -> None:
    """A sword from its pommel (px, py) to its tip (tx, ty): steel blade, a gilt guard, a bark grip."""
    dx, dy = tx - px, ty - py
    ln = (dx * dx + dy * dy) ** 0.5
    ux, uy = dx / ln, dy / ln
    gx, gy = px + ux * ln * 0.28, py + uy * ln * 0.28
    half = 0.11 * ln
    c.fill(c.cap(px, py, gx, gy, 2.2), "bark")
    c.fill(c.cap(gx - uy * half, gy + ux * half, gx + uy * half, gy - ux * half, 2.0), "gold")
    c.fill(c.cap(gx + ux * 0.8, gy + uy * 0.8, tx, ty, 2.6), "steel")
    c.fill(c.circle(px, py, 1.7), "gold")


# ---------------------------------------------------------------- the badges (40 px)

def _badge_roundel(c: _Cv) -> None:
    c.fill(c.circle(20.0, 20.0, 18.0), "dark")


def _render_badge_battle(s: int, tokens: TokenTable) -> np.ndarray:
    c = _Cv(BADGE_SIZE[0], BADGE_SIZE[1], s, tokens)
    _badge_roundel(c)
    _sword(c, 9.5, 29.5, 29.5, 9.5)
    _sword(c, 30.5, 29.5, 10.5, 9.5)
    return _finish(c.out)


def _render_badge_siege(s: int, tokens: TokenTable) -> np.ndarray:
    c = _Cv(BADGE_SIZE[0], BADGE_SIZE[1], s, tokens)
    _badge_roundel(c)
    for mx in (13.2, 18.4, 23.6):
        c.fill(c.rbox(mx - 2.0, 7.8, mx + 2.0, 12.6, 0.6), "stone")
    c.fill(c.rbox(12.8, 11.4, 27.2, 31.2, 1.2), "stone")
    c.stroke(c.rbox(14.6, 13.0, 25.4, 13.8, 0.2), "salt", 0.45)
    c.fill(c.rbox(17.2, 20.0, 22.8, 31.2, 2.6), "ink", ink=False)
    c.line(20.0, 22.4, 20.0, 30.4, 0.8, "bark")
    c.line(18.2, 22.4, 18.2, 30.4, 0.8, "bark")
    c.line(21.8, 22.4, 21.8, 30.4, 0.8, "bark")
    return _finish(c.out)


# ---------------------------------------------------------------- the die face (28 px)

def _render_die(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = DIE_SIZE
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    sd = sd_rounded_rect(lx, ly, 14.0, 14.0, 11.5, 11.5, 4.5)
    ink = _rgb(tokens, "INK")
    out = blend_rgb_mask(out, ink, coverage(sd, s))
    bone = _rgb(tokens, "VELLUM")
    # The face: bone, lit at the top, 8 % darker at the foot and the right, as a worn ivory cube.
    t = np.clip((ly - 3.0) / 22.0, 0.0, 1.0)
    u = np.clip((lx - 3.0) / 22.0, 0.0, 1.0)
    shade = 1.0 - 0.08 * (0.5 * t + 0.5 * u)
    face = bone[None, None, :] * shade[..., None]
    out = blend_rgb_mask(out, face, coverage(sd - 0.9, s))
    lit = np.clip(1.0 - (ly - 3.2) / 2.2, 0.0, 1.0) * 0.8
    out = blend_rgb_mask(out, np.ones(3), coverage(sd - 1.6, s) * lit, alpha=0.7)
    return _finish(out)


# ---------------------------------------------------------------- the 24 icons

def _i_war(c: _Cv) -> None:
    c.fill(c.cap(12.0, 3.0, 12.0, 15.0, 2.6), "steel")
    c.fill(c.cap(7.0, 15.0, 17.0, 15.0, 2.2), "gold")
    c.fill(c.cap(12.0, 15.0, 12.0, 19.2, 2.0), "bark")
    c.fill(c.circle(12.0, 20.4, 1.5), "gold")


def _leaf(c: _Cv, x: float, y: float, rx: float, ry: float, cs: float, sn: float) -> None:
    c.fill(c.ell(x, y, rx, ry, cs, sn), "leaf")


def _i_peace(c: _Cv) -> None:
    c.fill(c.cap(12.0, 21.0, 12.0, 4.0, 1.4), "bark")
    _leaf(c, 8.0, 9.0, 3.6, 1.7, 0.866, 0.5)
    _leaf(c, 16.0, 9.0, 3.6, 1.7, 0.866, -0.5)
    _leaf(c, 8.0, 15.0, 3.6, 1.7, 0.866, 0.5)
    _leaf(c, 16.0, 15.0, 3.6, 1.7, 0.866, -0.5)
    _leaf(c, 12.0, 4.5, 1.6, 2.6, 1.0, 0.0)


def _i_truce(c: _Cv) -> None:
    c.fill(c.cap(6.0, 21.0, 6.0, 3.0, 1.6), "bark")
    c.fill(c.poly([(6.6, 4.0), (19.5, 6.6), (15.4, 10.8), (19.5, 15.2), (6.6, 15.4)]), "white")


def _i_battle(c: _Cv) -> None:
    _sword(c, 4.0, 20.0, 20.0, 4.0)
    _sword(c, 20.0, 20.0, 4.0, 4.0)


def _i_siege(c: _Cv) -> None:
    for mx in (7.6, 11.6, 15.6):
        c.fill(c.rbox(mx - 1.6, 3.6, mx + 1.6, 7.0, 0.4), "stone")
    c.fill(c.rbox(6.0, 6.4, 18.0, 22.0, 1.0), "stone")
    c.fill(c.rbox(9.6, 14.4, 14.4, 22.0, 2.2), "dark")
    c.line(12.0, 16.2, 12.0, 21.0, 0.8, "bark")


def _i_storm(c: _Cv) -> None:
    cloud = np.minimum(np.minimum(c.circle(8.5, 10.5, 4.0), c.circle(14.0, 8.5, 5.0)), np.minimum(c.circle(18.5, 11.8, 3.4), c.rbox(5.0, 10.0, 19.5, 15.0, 2.0)))
    c.fill(cloud, "stone")
    c.fill(c.poly([(13.2, 13.4), (8.6, 18.6), (12.4, 18.4), (10.2, 21.6), (16.2, 16.2), (12.4, 16.4), (15.2, 13.4)]), "amber")


def _i_besiege(c: _Cv) -> None:
    c.fill(np.abs(c.circle(11.0, 13.0, 7.6)) - 1.8, "stone")
    _arrow(c, 21.0, 3.0, 13.0, 11.0, "red", 2.6, 3.4)


def _i_attack(c: _Cv) -> None:
    _arrow(c, 4.0, 19.5, 20.0, 4.0, "red", 3.2, 4.6)


def _i_standing_hold(c: _Cv) -> None:
    c.fill(c.ring(12.0, 5.0, 2.4, 1.8), "steel")
    c.fill(c.cap(12.0, 7.0, 12.0, 20.0, 2.2), "steel")
    c.fill(c.cap(7.0, 9.0, 17.0, 9.0, 2.0), "steel")
    for (x0, y0, x1, y1) in ((4.5, 13.5, 7.8, 18.2), (7.8, 18.2, 12.0, 20.4), (12.0, 20.4, 16.2, 18.2), (16.2, 18.2, 19.5, 13.5)):
        c.fill(c.cap(x0, y0, x1, y1, 2.2), "steel")


def _i_withdraw(c: _Cv) -> None:
    _arrow(c, 19.5, 12.0, 3.5, 12.0, "wheat", 3.2, 4.4)


def _i_flee(c: _Cv) -> None:
    _arrow(c, 18.0, 15.0, 6.0, 6.0, "amber", 3.0, 4.2)
    c.line(3.0, 14.0, 7.0, 14.0, 1.2, "bark")
    c.line(5.0, 19.0, 10.0, 19.0, 1.2, "bark")


def _i_victory(c: _Cv) -> None:
    c.fill(c.poly([(12.0, 2.5), (14.4, 8.8), (21.0, 9.1), (17.6, 19.7), (12.0, 16.0), (6.4, 19.7), (3.0, 9.1), (9.6, 8.8)]), "gold")


def _i_defeat(c: _Cv) -> None:
    c.fill(c.cap(5.0, 3.0, 5.0, 21.0, 1.4), "bark")
    c.fill(c.poly([(5.6, 3.6), (19.0, 4.2), (16.2, 10.0), (19.0, 16.0), (5.6, 13.6)]), "iron")


def _i_fortress(c: _Cv) -> None:
    c.fill(c.rbox(8.0, 3.0, 10.6, 7.0, 0.4), "stone")
    c.fill(c.rbox(13.4, 3.0, 16.0, 7.0, 0.4), "stone")
    c.fill(c.rbox(8.0, 6.0, 16.0, 22.0, 0.8), "stone")
    c.fill(c.rbox(10.6, 15.0, 13.4, 22.0, 1.4), "dark")
    c.dot(12.0, 11.0, 1.2, "dark")


def _i_garrison(c: _Cv) -> None:
    c.fill(c.poly([(11.0, 8.6), (12.2, 3.0), (18.4, 4.2), (15.2, 8.6)]), "red")
    c.fill(c.ell(12.0, 14.0, 7.6, 6.2), "steel")
    c.fill(c.rbox(7.4, 13.4, 16.6, 17.4, 1.0), "dark")


def _i_area_held(c: _Cv) -> None:
    c.fill(c.ell(12.0, 19.4, 9.0, 2.6), "leaf")
    c.fill(c.cap(9.0, 19.4, 9.0, 3.5, 1.4), "bark")
    c.fill(c.poly([(9.6, 4.2), (19.6, 7.0), (9.6, 11.4)]), "red")


def _i_area_open(c: _Cv) -> None:
    pts = [(20.0, 12.0), (17.66, 17.66), (12.0, 20.0), (6.34, 17.66), (4.0, 12.0), (6.34, 6.34), (12.0, 4.0), (17.66, 6.34)]
    for k in range(len(pts)):
        ax, ay = pts[k]
        bx, by = pts[(k + 1) % len(pts)]
        c.line(ax + 0.15 * (bx - ax), ay + 0.15 * (by - ay), ax + 0.7 * (bx - ax), ay + 0.7 * (by - ay), 2.8, "ink")


def _i_routed(c: _Cv) -> None:
    c.fill(c.poly([(5.0, 4.0), (19.0, 4.0), (19.0, 12.0), (12.0, 21.0), (5.0, 12.0)]), "steel")
    c.stroke(c.cap(9.0, 6.0, 13.0, 11.0, 1.6), "red")
    c.stroke(c.cap(13.0, 11.0, 11.0, 14.0, 1.6), "red")
    c.stroke(c.cap(11.0, 14.0, 15.0, 19.0, 1.6), "red")


def _i_shaken(c: _Cv) -> None:
    c.fill(c.poly([(12.0, 3.0), (22.0, 20.0), (2.0, 20.0)]), "amber")
    c.fill(c.rbox(10.8, 8.0, 13.2, 15.0, 1.0), "ink", ink=False)
    c.dot(12.0, 18.0, 1.4, "ink")


def _i_fires(c: _Cv) -> None:
    c.fill(c.poly([(6.0, 22.0), (3.5, 16.0), (7.0, 11.0), (9.5, 5.0), (12.5, 12.0), (14.0, 9.0), (16.5, 15.0), (12.0, 22.0)]), "red")
    c.fill(c.poly([(9.0, 22.0), (7.5, 17.0), (10.0, 14.0), (11.5, 17.0), (13.5, 15.0), (12.5, 22.0)]), "amber", ink=False)


def _i_occupied(c: _Cv) -> None:
    c.fill(c.cap(5.0, 3.0, 5.0, 21.0, 1.4), "bark")
    c.fill(c.rbox(6.0, 4.0, 19.5, 15.0, 0.5), "red")
    c.fill(c.box(6.0, 8.4, 19.5, 10.0), "white", ink=False)
    c.fill(c.box(6.0, 11.6, 19.5, 13.2), "white", ink=False)


def _i_uphill(c: _Cv) -> None:
    c.fill(c.poly([(2.0, 21.0), (10.0, 9.0), (14.0, 14.0), (17.0, 11.0), (22.0, 21.0)]), "stone")
    _arrow(c, 4.0, 19.0, 19.0, 6.0, "amber", 2.8, 3.8)


def _i_pass_cross(c: _Cv) -> None:
    c.fill(c.poly([(1.5, 21.0), (8.0, 7.0), (11.0, 12.0), (14.0, 5.0), (22.5, 21.0)]), "stone")
    for x in (7.0, 11.0, 15.0):
        c.dot(x, 17.0, 1.1, "cream")


def _i_river_cross(c: _Cv) -> None:
    pts = [(1.5, 14.0)]
    x = 1.5
    up = True
    while x < 22.4:
        x += 3.0
        pts.append((x, 14.0 + (-1.4 if up else 1.4)))
        up = not up
    pts += [(22.5, 22.5), (1.5, 22.5)]
    c.fill(c.poly(pts), "blue")
    _arrow(c, 3.0, 5.0, 16.0, 11.0, "amber", 2.6, 3.4)


_ICONS: dict[str, Callable[[_Cv], None]] = {
    "war": _i_war, "peace": _i_peace, "truce": _i_truce, "battle": _i_battle, "siege": _i_siege,
    "storm": _i_storm, "besiege": _i_besiege, "attack": _i_attack, "standing_hold": _i_standing_hold,
    "withdraw": _i_withdraw, "flee": _i_flee, "victory": _i_victory, "defeat": _i_defeat,
    "fortress": _i_fortress, "garrison": _i_garrison, "area_held": _i_area_held, "area_open": _i_area_open,
    "routed": _i_routed, "shaken": _i_shaken, "fires": _i_fires, "occupied": _i_occupied,
    "uphill": _i_uphill, "pass_cross": _i_pass_cross, "river_cross": _i_river_cross,
}


def war_icon_cell(name: str, s: int, tokens: TokenTable) -> np.ndarray:
    c = _Cv(ICON_CELL, ICON_CELL, s, tokens)
    _ICONS[name](c)
    return c.out


def render_icons_war(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = ICONS_SIZE
    atlas = np.zeros((h * s, w * s, 4), dtype=np.float64)
    for i, name in enumerate(WAR_ICON_NAMES):
        x, y = (i % ICON_COLUMNS) * ICON_CELL, (i // ICON_COLUMNS) * ICON_CELL
        atlas[y * s : (y + ICON_CELL) * s, x * s : (x + ICON_CELL) * s] = war_icon_cell(name, s, tokens)
    return _finish(atlas)


# ---------------------------------------------------------------- the catalogue and the asserts

def m7_pieces() -> list[PieceSpec]:
    zero = (0, 0, 0, 0)

    def spec(name: str, size: tuple[int, int], render: Callable[[int, TokenTable], np.ndarray]) -> PieceSpec:
        return PieceSpec(
            name=name, slice_num=6, size=size, margin=zero, content=zero, expand=zero, axis="stretch",
            fixed_height=False, min_width=0, check="exact", scales=(1, 2), out_subdir="kit", render=render,
        )

    return [
        spec("badge_battle", BADGE_SIZE, _render_badge_battle),
        spec("badge_siege", BADGE_SIZE, _render_badge_siege),
        spec("icons_war", ICONS_SIZE, render_icons_war),
        spec("die_face", DIE_SIZE, _render_die),
    ]


# The war token pairs (m7 spec 6.2): the siege dial on its track, in both themes.
WAR_PAIRS: tuple[tuple[str, str], ...] = (("WAR_DIAL", "WAR_DIAL_TRACK"),)
# WCAG 1.4.11 non-text floor: the high-contrast dial and its track are graphics, not text (4.5 stays for studiolo).
MIN_GRAPHIC = 3.0


def check_m7_pieces(
    tokens: TokenTable,
    specs: list[PieceSpec],
    rendered: dict[tuple[str, int], np.ndarray],
    tokens_path: Path,
) -> None:
    """Style spec 4.4 asserts for slice 6: dial contrast in both themes, a bone face the pips read on, drawn badges and cells."""
    hc = high_contrast_colours(tokens_path, tokens)
    for fg, bg in WAR_PAIRS:
        for name in (fg, bg):
            if name not in tokens.colors:
                raise BakeCheckError(f"Token {name} is missing from tokens.gd")
            if name not in hc:
                raise BakeCheckError(f"HIGH_CONTRAST {name} is missing from tokens.gd")
        r = contrast_ratio(tokens.rgb(fg), tokens.rgb(bg))
        if r < MIN_CONTRAST:
            raise BakeCheckError(f"Contrast {fg} on {bg} is {r:.2f} < {MIN_CONTRAST}")
        r_hc = contrast_ratio(hc[fg], hc[bg])
        if r_hc < MIN_GRAPHIC:
            raise BakeCheckError(f"HIGH_CONTRAST contrast {fg} on {bg} is {r_hc:.2f} < {MIN_GRAPHIC}")
    r_track = contrast_ratio(hc["WAR_DIAL_TRACK"], hc["PANEL_BG"])
    if r_track < MIN_GRAPHIC:
        raise BakeCheckError(f"HIGH_CONTRAST WAR_DIAL_TRACK on PANEL_BG is {r_track:.2f} < {MIN_GRAPHIC}: the empty dial would vanish")

    names = {sp.name for sp in specs}
    for s in (1, 2):
        for badge in ("badge_battle", "badge_siege"):
            arr = rendered.get((badge, s))
            if arr is None:
                continue
            if int(arr[0, 0, 3]) != 0 or int(arr[-1, -1, 3]) != 0:
                raise BakeCheckError(f"{badge}@{s}x corner is not transparent")
            c0 = arr.shape[0] // 2
            if int(arr[c0, c0, 3]) != 255:
                raise BakeCheckError(f"{badge}@{s}x centre is not drawn")
        die = rendered.get(("die_face", s))
        if die is not None:
            # The pips are VELLUM_INK: the darkest texel of the face's interior keeps 4.5:1 against them.
            inner = die[int(6 * s) : int(22 * s), int(6 * s) : int(22 * s)]
            if int(inner[..., 3].min()) != 255:
                raise BakeCheckError(f"die_face@{s}x interior is not opaque")
            darkest = tuple(float(v) / 255.0 for v in inner[..., :3].reshape(-1, 3)[int(np.argmin(inner[..., :3].reshape(-1, 3).sum(axis=1)))])
            r_pip = contrast_ratio(tokens.rgb("VELLUM_INK"), darkest)
            if r_pip < MIN_CONTRAST:
                raise BakeCheckError(f"die_face@{s}x pips (VELLUM_INK) on the face are {r_pip:.2f} < {MIN_CONTRAST}")
        if "icons_war" in names:
            arr = rendered.get(("icons_war", s))
            if arr is not None:
                cell = ICON_CELL * s
                hashes: set[bytes] = set()
                for i in range(len(WAR_ICON_NAMES)):
                    x, y = (i % ICON_COLUMNS) * cell, (i // ICON_COLUMNS) * cell
                    part = arr[y : y + cell, x : x + cell, 3]
                    if int((part == 255).sum()) < ICON_CELL * ICON_CELL * s * s // 8:
                        raise BakeCheckError(f"icons_war cell {WAR_ICON_NAMES[i]}@{s}x is hardly drawn")
                    if max(int(part[0].max()), int(part[-1].max()), int(part[:, 0].max()), int(part[:, -1].max())) > 200:
                        raise BakeCheckError(f"icons_war cell {WAR_ICON_NAMES[i]}@{s}x touches its cell edge")
                    hashes.add(part.tobytes())
                if len(hashes) != len(WAR_ICON_NAMES):
                    raise BakeCheckError("icons_war has two cells with the same silhouette")


# ---------------------------------------------------------------- the war sheet

def _scaled_badge(badge: np.ndarray, diameter: int) -> np.ndarray:
    """A nearest-neighbour resize of a square badge to `diameter` px (a preview only: the bake never resizes)."""
    idx = (np.arange(diameter) * badge.shape[0] // diameter)
    return badge[idx][:, idx]


def _dial(size: int, tokens: TokenTable, fraction: float) -> np.ndarray:
    """The siege dial for the sheet: WAR_DIAL clockwise from the top over WAR_DIAL_TRACK (a dev preview)."""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    cx = cy = (size - 1) / 2.0
    r = np.hypot(xx - cx, yy - cy)
    track = _rgb(tokens, "WAR_DIAL_TRACK")
    amber = _rgb(tokens, "WAR_DIAL")
    ang = np.mod(np.arctan2(xx - cx, -(yy - cy)), 2.0 * np.pi)
    out = np.zeros((size, size, 4), dtype=np.float64)
    ring = (r <= size / 2.0 - 1.0) & (r >= size / 2.0 - 4.0)
    out[ring, :3] = track
    out[ring, 3] = 1.0
    fill = ring & (ang <= 2.0 * np.pi * fraction)
    out[fill, :3] = amber
    return _finish(out)


def write_war_sheet(path: Path, tokens: TokenTable, s: int = 2) -> None:
    """The war sheet for the art director (m7 spec 6.2): badges in three tones at r8, r13, r34; the 24 icons; the die faces;
    the siege dial. Dev output only: the bake never reads it."""
    badge_b = _render_badge_battle(1, tokens)
    badge_s = _render_badge_siege(1, tokens)
    icons = render_icons_war(s, tokens)
    die = _render_die(s, tokens)
    dial_px = 26 * s
    radii = (8, 13, 34)
    tones = ("GOOD", "BAD", "FAINT")
    pad = 12 * s
    row_badges_w = sum(2 * ((2 * r + 6) * s + pad) for r in radii) * len(tones) + pad
    icon_w = ICONS_SIZE[0] * s
    die_w = 6 * (DIE_SIZE[0] * s + pad)
    width = max(row_badges_w, icon_w + 2 * pad, die_w + pad) + pad
    rows = []
    rows.append(int(2 * max(radii) * s + 2 * pad + 6 * s))
    rows.append(ICONS_SIZE[1] * s + 2 * pad)
    rows.append(DIE_SIZE[1] * s + 2 * pad)
    height = sum(rows) + 2 * pad + dial_px + pad
    canvas = np.zeros((height, width, 4), dtype=np.uint8)
    canvas[:] = np.asarray([int(v * 255.0 + 0.5) for v in tokens.rgb("PANEL_BG")] + [255], dtype=np.uint8)

    def put(arr: np.ndarray, x: int, y: int) -> None:
        h, w, _ = arr.shape
        dst = canvas[y : y + h, x : x + w]
        a = arr[..., 3:4].astype(np.float64) / 255.0
        dst[..., :3] = np.floor(arr[..., :3].astype(np.float64) * a + dst[..., :3].astype(np.float64) * (1.0 - a) + 0.5).astype(np.uint8)

    y0 = pad
    x = pad
    for tone in tones:
        col = _rgb(tokens, tone)
        for r in radii:
            d = 2 * r * s
            for badge in (badge_b, badge_s):
                grow = (d + 6 * s)
                ring = np.zeros((grow, grow, 4), dtype=np.float64)
                yy, xx = np.mgrid[0:grow, 0:grow].astype(np.float64)
                rr = np.hypot(xx + 0.5 - grow / 2.0, yy + 0.5 - grow / 2.0)
                band = np.clip(1.0 - np.abs(rr - (d / 2.0 + 2.0 * s)) / (1.5 * s), 0.0, 1.0)
                ring[..., :3] = col * 255.0
                ring[..., 3] = band * 255.0
                put(ring.astype(np.uint8), x, y0)
                put(_scaled_badge(badge, d), x + 3 * s, y0 + 3 * s)
                x += grow + pad
    y0 += rows[0]
    x = pad
    put(icons, x, y0 + pad)
    y0 += rows[1]
    for i in range(6):
        put(die, pad + i * (DIE_SIZE[0] * s + pad), y0 + pad)
        pips = i + 1
        face_x = pad + i * (DIE_SIZE[0] * s + pad)
        for p in range(pips):
            px = face_x + (6 + 4 * (p % 3) + 2) * s
            py = y0 + pad + (6 + 4 * (p // 3) + 2) * s
            yy, xx = np.mgrid[0:6 * s, 0:6 * s].astype(np.float64)
            disc = np.hypot(xx + 0.5 - 3.0 * s, yy + 0.5 - 3.0 * s) <= 2.0 * s
            pip = np.zeros((6 * s, 6 * s, 4), dtype=np.uint8)
            pip[disc, :3] = np.floor(_rgb(tokens, "VELLUM_INK") * 255.0 + 0.5).astype(np.uint8)
            pip[disc, 3] = 255
            put(pip, px - 3 * s, py - 3 * s)
    y0 += rows[2] + pad
    put(_dial(dial_px, tokens, 0.6), pad, y0)
    save_png(path, canvas)
