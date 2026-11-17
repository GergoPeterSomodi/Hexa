"""Slice 1 Studiolo art pieces (spec 4.5): seal, stud, glow_soft, rule_diamond, icons_base, wordmark, rose, menu art."""
from __future__ import annotations

import os
from pathlib import Path

import numpy as np

from .light import box_blur
from .materials import diamond_angle, sample_ramp
from .noise import fbm_2d
from .pieces_frames import PieceSpec
from .png import load_png_rgba
from .shapes import (
    blend_rgb_mask,
    coverage,
    draw_diamond_stud,
    logical_grid,
    sd_circle,
    sd_diamond,
    sd_segment,
    stroke_coverage,
)
from .tokens import TokenTable, parse_hex_color

REPO_ROOT = Path(__file__).resolve().parents[2]
WORDMARK_FONT = REPO_ROOT / "tools" / "ui_bake" / "fonts" / "CinzelDecorative-Black.ttf"
ROSE_FONT = REPO_ROOT / "godot" / "assets" / "fonts" / "cinzel" / "Cinzel-Bold.ttf"
MENU_MAP_INPUT = REPO_ROOT / "tools" / "ui_bake" / "inputs" / "menu_map.png"


def _sd_triangle(lx: np.ndarray, ly: np.ndarray, p0: tuple[float, float], p1: tuple[float, float], p2: tuple[float, float]) -> np.ndarray:
    """Exact Euclidean signed distance to triangle (p0, p1, p2) in any winding."""
    pts = [p0, p1, p2]
    d2 = np.full(lx.shape, 1e12, dtype=np.float64)
    sign_sum = np.zeros(lx.shape, dtype=np.float64)
    # Compute orientation sign
    area2 = (p1[0] - p0[0]) * (p2[1] - p0[1]) - (p1[1] - p0[1]) * (p2[0] - p0[0])
    orient = 1.0 if area2 >= 0.0 else -1.0
    for i in range(3):
        ax, ay = pts[i]
        bx, by = pts[(i + 1) % 3]
        ex, ey = bx - ax, by - ay
        px, py = lx - ax, ly - ay
        denom = max(1e-12, ex * ex + ey * ey)
        t = np.clip((px * ex + py * ey) / denom, 0.0, 1.0)
        qx = px - ex * t
        qy = py - ey * t
        d2 = np.minimum(d2, qx * qx + qy * qy)
        cross = (ex * py - ey * px) * orient
        sign_sum = np.where(cross >= 0.0, sign_sum + 1.0, sign_sum)
    dist = np.sqrt(d2)
    return np.where(sign_sum >= 2.99, -dist, dist)


def _render_seal(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = 72, 72
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    cx, cy = 36.0, 36.0

    # Organic 2% wobble on wax outline using periodic noise on (dx, dy)
    dx = lx - cx
    dy = ly - cy
    r_dist = np.sqrt(dx * dx + dy * dy)
    ang = diamond_angle(dx, dy)
    wobble = (fbm_2d(ang * 32.0, ang * 0.0 + 1.0, 0.15, 0.05, octaves=2, period_x=32, period_y=8, seed=19) - 0.5) * 1.4
    r_wax = 31.5 + wobble
    sd_wax = r_dist - r_wax

    # Soft drop shadow
    sd_sh = np.sqrt(dx * dx + (dy - 2.0) ** 2) - r_wax
    out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), coverage(sd_sh - 1.5, s), alpha=0.45)

    # Radial wax body (#d8523c -> SEAL -> #6d130c)
    rt = np.clip(np.sqrt(((lx - (cx - 9.0)) / 42.0) ** 2 + ((ly - (cy - 11.0)) / 42.0) ** 2), 0.0, 1.0)
    wax_rgb = sample_ramp(
        rt,
        [(0.0, parse_hex_color("#d8523c")[:3]), (0.45, tokens.rgb("SEAL")), (1.0, parse_hex_color("#6d130c")[:3])],
    )
    wax_cov = coverage(sd_wax, s)
    out = blend_rgb_mask(out, wax_rgb, wax_cov)

    # Inner embossed stamp ring
    ring_dark = wax_cov * stroke_coverage(r_dist, 24.5, 2.0, s)
    ring_hi = wax_cov * stroke_coverage(r_dist, 22.0, 0.7, s)
    out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), ring_dark, alpha=0.18)
    out = blend_rgb_mask(out, parse_hex_color("#ffa082")[:3], ring_hi, alpha=0.28)
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_stud(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = 12, 12
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    out = draw_diamond_stud(out, lx, ly, 6.0, 6.0, s, tokens)
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_glow_soft(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = 64, 64
    lx, ly = logical_grid(w, h, s)
    dx = (lx - 32.0) / 30.0
    dy = (ly - 32.0) / 30.0
    r = np.clip(np.sqrt(dx * dx + dy * dy), 0.0, 1.0)
    # Smooth quadratic falloff to zero at radius 30
    alpha = (1.0 - r) ** 2 * tokens.rgba("GLOW")[3]
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    rgb = tokens.rgb("GLOW")
    out[..., 0] = rgb[0]
    out[..., 1] = rgb[1]
    out[..., 2] = rgb[2]
    out[..., 3] = alpha
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_rule_diamond(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = 256, 12
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    line_rgb = np.asarray(tokens.rgb("LINE"), dtype=np.float64)

    sd_left = sd_segment(lx, ly, 0.0, 6.0, 116.0, 6.0) - 0.75
    sd_right = sd_segment(lx, ly, 140.0, 6.0, 256.0, 6.0) - 0.75
    out = blend_rgb_mask(out, line_rgb, coverage(np.minimum(sd_left, sd_right), s))

    sd_dia = sd_diamond(lx, ly, 128.0, 6.0, 5.0, 5.0)
    out = blend_rgb_mask(out, np.asarray(tokens.rgb("INK"), dtype=np.float64), coverage(sd_dia - 0.8, s))
    out = blend_rgb_mask(out, np.asarray(tokens.rgb("PRIMARY"), dtype=np.float64), coverage(sd_dia, s))
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_icons_base(s: int, tokens: TokenTable) -> np.ndarray:
    """128x32 atlas of 16x16 white SDF icons (8x2 cells) for tone tinting at runtime."""
    _ = tokens
    w, h = 128, 32
    lx, ly = logical_grid(w, h, s)
    alpha = np.zeros(lx.shape, dtype=np.float64)

    def add_cell(col: int, row: int, sd: np.ndarray) -> None:
        in_cell = (lx >= col * 16.0) & (lx < (col + 1) * 16.0) & (ly >= row * 16.0) & (ly < (row + 1) * 16.0)
        alpha[:] = np.maximum(alpha, np.where(in_cell, coverage(sd, s), 0.0))

    # Row 0: arrow_up, arrow_down, arrow_left, arrow_right, tick, cross, lock, dash
    # 0: arrow_up
    cx, cy = 8.0, 8.0
    add_cell(0, 0, _sd_triangle(lx, ly, (cx, cy - 4.5), (cx + 4.8, cy + 3.5), (cx - 4.8, cy + 3.5)))
    # 1: arrow_down
    cx = 16.0 + 8.0
    add_cell(1, 0, _sd_triangle(lx, ly, (cx - 4.8, cy - 3.5), (cx + 4.8, cy - 3.5), (cx, cy + 4.5)))
    # 2: arrow_left
    cx = 32.0 + 8.0
    add_cell(2, 0, _sd_triangle(lx, ly, (cx - 4.5, cy), (cx + 3.5, cy - 4.8), (cx + 3.5, cy + 4.8)))
    # 3: arrow_right
    cx = 48.0 + 8.0
    add_cell(3, 0, _sd_triangle(lx, ly, (cx + 4.5, cy), (cx - 3.5, cy - 4.8), (cx - 3.5, cy + 4.8)))
    # 4: tick
    ox, oy = 64.0, 0.0
    sd_tick = np.minimum(
        sd_segment(lx, ly, ox + 3.2, oy + 8.5, ox + 6.4, oy + 11.7),
        sd_segment(lx, ly, ox + 6.4, oy + 11.7, ox + 12.8, oy + 4.5),
    ) - 1.15
    add_cell(4, 0, sd_tick)
    # 5: cross
    ox = 80.0
    sd_cross = np.minimum(
        sd_segment(lx, ly, ox + 4.0, oy + 4.0, ox + 12.0, oy + 12.0),
        sd_segment(lx, ly, ox + 12.0, oy + 4.0, ox + 4.0, oy + 12.0),
    ) - 1.15
    add_cell(5, 0, sd_cross)
    # 6: lock
    ox = 96.0
    dx_b = np.abs(lx - (ox + 8.0)) - 4.0
    dy_b = np.abs(ly - (oy + 10.2)) - 3.2
    sd_body = np.maximum(dx_b, dy_b)
    sd_shackle = np.maximum(np.abs(sd_circle(lx, ly, ox + 8.0, oy + 6.2, 2.7)) - 0.85, ly - (oy + 7.2))
    add_cell(6, 0, np.minimum(sd_body, sd_shackle))
    # 7: dash
    ox = 112.0
    add_cell(7, 0, sd_segment(lx, ly, ox + 3.5, oy + 8.0, ox + 12.5, oy + 8.0) - 1.1)

    # Row 1: close, menu, help, zoom_in, zoom_out, zoom_fit, study, info
    oy = 16.0
    # 8 (0,1): close (thin crisp X)
    ox = 0.0
    add_cell(
        0,
        1,
        np.minimum(
            sd_segment(lx, ly, ox + 4.2, oy + 4.2, ox + 11.8, oy + 11.8),
            sd_segment(lx, ly, ox + 11.8, oy + 4.2, ox + 4.2, oy + 11.8),
        )
        - 0.95,
    )
    # 9 (1,1): menu (3 horizontal bars)
    ox = 16.0
    sd_menu = np.minimum(
        sd_segment(lx, ly, ox + 3.0, oy + 4.5, ox + 13.0, oy + 4.5),
        np.minimum(
            sd_segment(lx, ly, ox + 3.0, oy + 8.0, ox + 13.0, oy + 8.0),
            sd_segment(lx, ly, ox + 3.0, oy + 11.5, ox + 13.0, oy + 11.5),
        ),
    ) - 0.95
    add_cell(1, 1, sd_menu)
    # 10 (2,1): help (question mark)
    ox = 32.0
    sd_arc = np.maximum(np.abs(sd_circle(lx, ly, ox + 8.0, oy + 5.6, 2.6)) - 0.9, ly - (oy + 7.2))
    sd_stem = sd_segment(lx, ly, ox + 8.0, oy + 7.6, ox + 8.0, oy + 9.5) - 0.9
    sd_dot = sd_circle(lx, ly, ox + 8.0, oy + 12.2, 1.05)
    add_cell(2, 1, np.minimum(sd_arc, np.minimum(sd_stem, sd_dot)))
    # 11 (3,1): zoom_in (+)
    ox = 48.0
    sd_plus = np.minimum(
        sd_segment(lx, ly, ox + 3.5, oy + 8.0, ox + 12.5, oy + 8.0),
        sd_segment(lx, ly, ox + 8.0, oy + 3.5, ox + 8.0, oy + 12.5),
    ) - 1.05
    add_cell(3, 1, sd_plus)
    # 12 (4,1): zoom_out (-)
    ox = 64.0
    add_cell(4, 1, sd_segment(lx, ly, ox + 3.5, oy + 8.0, ox + 12.5, oy + 8.0) - 1.05)
    # 13 (5,1): zoom_fit (4 corner brackets + centre dot)
    ox = 80.0
    sd_fit = np.minimum(
        np.minimum(
            np.minimum(sd_segment(lx, ly, ox + 3.0, oy + 3.0, ox + 6.0, oy + 3.0), sd_segment(lx, ly, ox + 3.0, oy + 3.0, ox + 3.0, oy + 6.0)),
            np.minimum(sd_segment(lx, ly, ox + 10.0, oy + 3.0, ox + 13.0, oy + 3.0), sd_segment(lx, ly, ox + 13.0, oy + 3.0, ox + 13.0, oy + 6.0)),
        ),
        np.minimum(
            np.minimum(sd_segment(lx, ly, ox + 3.0, oy + 13.0, ox + 6.0, oy + 13.0), sd_segment(lx, ly, ox + 3.0, oy + 10.0, ox + 3.0, oy + 13.0)),
            np.minimum(sd_segment(lx, ly, ox + 10.0, oy + 13.0, ox + 13.0, oy + 13.0), sd_segment(lx, ly, ox + 13.0, oy + 10.0, ox + 13.0, oy + 13.0)),
        ),
    ) - 0.85
    add_cell(5, 1, np.minimum(sd_fit, sd_circle(lx, ly, ox + 8.0, oy + 8.0, 1.3)))
    # 14 (6,1): study (open book)
    ox = 96.0
    sd_bk = np.minimum(
        np.minimum(sd_segment(lx, ly, ox + 2.5, oy + 4.2, ox + 8.0, oy + 5.4), sd_segment(lx, ly, ox + 13.5, oy + 4.2, ox + 8.0, oy + 5.4)),
        np.minimum(sd_segment(lx, ly, ox + 2.5, oy + 11.4, ox + 8.0, oy + 12.6), sd_segment(lx, ly, ox + 13.5, oy + 11.4, ox + 8.0, oy + 12.6)),
    )
    sd_bk = np.minimum(
        sd_bk,
        np.minimum(
            sd_segment(lx, ly, ox + 2.5, oy + 4.2, ox + 2.5, oy + 11.4),
            np.minimum(sd_segment(lx, ly, ox + 13.5, oy + 4.2, ox + 13.5, oy + 11.4), sd_segment(lx, ly, ox + 8.0, oy + 5.4, ox + 8.0, oy + 12.6)),
        ),
    ) - 0.8
    add_cell(6, 1, sd_bk)
    # 15 (7,1): info ('i')
    ox = 112.0
    add_cell(7, 1, np.minimum(sd_circle(lx, ly, ox + 8.0, oy + 4.2, 1.0), sd_segment(lx, ly, ox + 8.0, oy + 7.0, ox + 8.0, oy + 12.2) - 0.95))

    out = np.ones((h * s, w * s, 4), dtype=np.float64)
    out[..., 3] = alpha
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _rasterize_text_alpha_4x(text: str, font_path: Path, px_size: int, tracking_em: float, out_w: int, out_h: int) -> np.ndarray:
    """Render centred uppercase text via pygame.freetype at 4x and box-reduce to (out_h, out_w) alpha in [0, 1]."""
    os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
    import pygame
    import pygame.freetype

    if not pygame.get_init():
        pygame.init()
    if not pygame.freetype.get_init():
        pygame.freetype.init()

    ss = 4
    hi_w, hi_h = out_w * ss, out_h * ss
    font = pygame.freetype.Font(str(font_path), px_size * ss)
    font.antialiased = True

    tracking_px = round(px_size * ss * tracking_em)
    glyphs = []
    min_x = 10**9
    max_x = -10**9
    cursor_x = 0
    max_ascent = 0
    max_descent = 0
    for idx, ch in enumerate(text):
        surf, rect = font.render(ch, fgcolor=(255, 255, 255, 255))
        metrics = font.get_metrics(ch)[0]
        adv = round(metrics[4])
        glyphs.append((surf, rect, cursor_x))
        min_x = min(min_x, cursor_x + rect.x)
        max_x = max(max_x, cursor_x + rect.x + rect.width)
        cursor_x += adv + (tracking_px if idx < len(text) - 1 else 0)
        max_ascent = max(max_ascent, rect.y)
        max_descent = max(max_descent, rect.height - rect.y)

    canvas = pygame.Surface((hi_w, hi_h), pygame.SRCALPHA)
    canvas.fill((0, 0, 0, 0))
    baseline_y = (hi_h + max_ascent - max_descent) // 2
    x_offset = (hi_w - (max_x - min_x)) // 2 - min_x
    for surf, rect, gx in glyphs:
        canvas.blit(surf, (x_offset + gx + rect.x, baseline_y - rect.y))

    raw = pygame.image.tobytes(canvas, "RGBA")
    arr = np.frombuffer(raw, dtype=np.uint8).reshape((hi_h, hi_w, 4))[..., 3].astype(np.float64) / 255.0
    # Deterministic 4x4 box reduction
    return arr.reshape(out_h, ss, out_w, ss).mean(axis=(1, 3))


def _render_wordmark(s: int, tokens: TokenTable) -> np.ndarray:
    _ = tokens
    w, h = 1024 * s, 256 * s
    px_size = 132 * s
    mask = _rasterize_text_alpha_4x("HEXA", WORDMARK_FONT, px_size=px_size, tracking_em=0.10, out_w=w, out_h=h)

    # Bounding box of glyph mask for horizon-aligned 5-stop gilt ramp
    ys = np.where(mask.max(axis=1) > 0.05)[0]
    y_top = float(ys[0]) if len(ys) else 0.0
    y_bot = float(ys[-1]) if len(ys) else float(h)
    y_coords = np.arange(h, dtype=np.float64)[:, None]
    t_y = np.clip((y_coords - y_top) / max(1.0, y_bot - y_top), 0.0, 1.0)
    t_grid = np.broadcast_to(t_y, (h, w))

    gilt_stops_wm = [
        (0.10, parse_hex_color("#fff6cf")[:3]),
        (0.40, parse_hex_color("#f0c85a")[:3]),
        (0.54, parse_hex_color("#a87a22")[:3]),
        (0.62, parse_hex_color("#f6e3a1")[:3]),
        (0.88, parse_hex_color("#c9952f")[:3]),
    ]
    face_rgb = sample_ramp(t_grid, gilt_stops_wm)

    # Layers: 26px warm glow -> soft drop shadow -> 3px #4a3209 extrusion -> 1px #fff3c4 top edge -> gilt face
    out = np.zeros((h, w, 4), dtype=np.float64)

    glow_mask = box_blur(mask, radius=13 * s, passes=3)
    out = blend_rgb_mask(out, parse_hex_color("#ffcd6e")[:3], glow_mask, alpha=0.35)

    sh_shift = np.roll(mask, 8 * s, axis=0)
    sh_shift[: 8 * s, :] = 0.0
    sh_mask = box_blur(sh_shift, radius=6 * s, passes=3)
    out = blend_rgb_mask(out, (0.0, 0.0, 0.0), sh_mask, alpha=0.80)

    ext_col = parse_hex_color("#4a3209")[:3]
    for step in range(3 * s, 0, -1):
        shifted = np.roll(mask, step, axis=0)
        shifted[:step, :] = 0.0
        out = blend_rgb_mask(out, ext_col, shifted)

    top_shift = np.roll(mask, -1 * s, axis=0)
    top_shift[-1 * s :, :] = 0.0
    top_edge = np.clip(top_shift - mask, 0.0, 1.0)
    out = blend_rgb_mask(out, parse_hex_color("#fff3c4")[:3], top_edge)

    out = blend_rgb_mask(out, face_rgb, mask)
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_rose(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = 512, 512
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    # Match mockup SVG viewBox="-110 -118 220 228" -> scale ~ 2.15
    cx, cy = 256.0, 266.0
    sc = 2.15

    brass = np.asarray(tokens.rgb("BRASS"), dtype=np.float64)
    brass_hi = np.asarray(tokens.rgb("BRASS_HI"), dtype=np.float64)
    brass_lo = np.asarray(tokens.rgb("BRASS_LO"), dtype=np.float64)
    ink = np.asarray(tokens.rgb("INK"), dtype=np.float64)

    r_dist = np.sqrt((lx - cx) ** 2 + (ly - cy) ** 2)
    # Outer rings (r=100, r=84)
    ring1 = stroke_coverage(r_dist, 100.0 * sc, 1.5, s)
    ring2 = stroke_coverage(r_dist, 84.0 * sc, 1.5, s)
    # Dashed inner ring r=30 using diamond angle
    ang = diamond_angle(lx - cx, ly - cy)
    dash_on = ((ang * 40.0) % 1.0) < 0.55
    ring3 = np.where(dash_on, stroke_coverage(r_dist, 30.0 * sc, 1.4, s), 0.0)
    out = blend_rgb_mask(out, brass, np.maximum(ring1, np.maximum(ring2, ring3)))

    # 4 intercardinal points (BEHIND cardinal)
    for sx, sy in ((1.0, -1.0), (1.0, 1.0), (-1.0, 1.0), (-1.0, -1.0)):
        tip = (cx + 62.0 * sc * sx, cy + 62.0 * sc * sy)
        p_a = (cx + 12.0 * sc * sx, cy - 10.0 * sc * sy) if sx * sy < 0 else (cx + 10.0 * sc * sx, cy + 12.0 * sc * sy)
        p_b = (cx - 12.0 * sc * sx, cy + 10.0 * sc * sy) if sx * sy < 0 else (cx - 10.0 * sc * sx, cy - 12.0 * sc * sy)
        # Simpler: half-triangles along diagonal (0,0)->tip->side
        side_a = (cx + 12.0 * sc * sx, cy)
        side_b = (cx, cy + 12.0 * sc * sy)
        sd_a = _sd_triangle(lx, ly, (cx, cy), tip, side_a)
        sd_b = _sd_triangle(lx, ly, (cx, cy), tip, side_b)
        out = blend_rgb_mask(out, ink, coverage(np.minimum(sd_a, sd_b) - 1.0, s))
        out = blend_rgb_mask(out, brass, coverage(sd_a, s))
        out = blend_rgb_mask(out, brass_lo, coverage(sd_b, s))

    # 4 cardinal points: N, S, E, W
    cardinals = [
        ((0.0, -104.0), (10.0, -10.0), (-10.0, -10.0), brass_hi, brass),
        ((0.0, 104.0), (10.0, 10.0), (-10.0, 10.0), brass_lo, brass),
        ((104.0, 0.0), (10.0, 10.0), (10.0, -10.0), brass_lo, brass),
        ((-104.0, 0.0), (-10.0, 10.0), (-10.0, -10.0), brass_lo, brass),
    ]
    for tip_off, side1_off, side2_off, col_a, col_b in cardinals:
        p_tip = (cx + tip_off[0] * sc, cy + tip_off[1] * sc)
        p_s1 = (cx + side1_off[0] * sc, cy + side1_off[1] * sc)
        p_s2 = (cx + side2_off[0] * sc, cy + side2_off[1] * sc)
        sd1 = _sd_triangle(lx, ly, (cx, cy), p_tip, p_s1)
        sd2 = _sd_triangle(lx, ly, (cx, cy), p_tip, p_s2)
        out = blend_rgb_mask(out, ink, coverage(np.minimum(sd1, sd2) - 1.0, s))
        out = blend_rgb_mask(out, col_a, coverage(sd1, s))
        out = blend_rgb_mask(out, col_b, coverage(sd2, s))

    # "N" label at top of rose
    n_mask = _rasterize_text_alpha_4x("N", ROSE_FONT, px_size=28 * s, tracking_em=0.0, out_w=48 * s, out_h=48 * s)
    y0 = 0
    x0 = (w * s - 48 * s) // 2
    full_n = np.zeros((h * s, w * s), dtype=np.float64)
    full_n[y0 : y0 + 48 * s, x0 : x0 + 48 * s] = n_mask
    out = blend_rgb_mask(out, brass_hi, full_n)
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_menu_shade(s: int, tokens: TokenTable) -> np.ndarray:
    _ = s
    w, h = 480, 270
    lx, ly = logical_grid(w, h, 1)
    u = lx / float(w)
    v = ly / float(h)
    ink = np.asarray(tokens.rgb("INK"), dtype=np.float64)

    out = np.zeros((h, w, 4), dtype=np.float64)
    # 1) Left dark third: 0 -> 0.94, 0.32 -> 0.60, 0.56 -> 0.0
    a_left = np.where(u <= 0.32, 0.94 + (0.60 - 0.94) * (u / 0.32), np.clip(0.60 * (1.0 - (u - 0.32) / 0.24), 0.0, 0.60))
    out = blend_rgb_mask(out, ink, a_left)

    # 2) Oval vignette: ellipse 62% x 72% at (68%, 48%), transparent <= 35% to 0.80 at 100%
    r_ell = np.sqrt(((u - 0.68) / 0.62) ** 2 + ((v - 0.48) / 0.72) ** 2)
    a_vig = np.clip((r_ell - 0.35) / 0.65, 0.0, 1.0) * 0.80
    out = blend_rgb_mask(out, ink, a_vig)

    # 3) Candle glow top right: circle at (80%, 20%), radius 45%
    r_glow = np.sqrt((u - 0.80) ** 2 + ((v - 0.20) * (float(h) / float(w))) ** 2) / 0.45
    a_glow = np.clip(1.0 - r_glow, 0.0, 1.0) ** 2 * 0.20
    out = blend_rgb_mask(out, (1.0, 196.0 / 255.0, 110.0 / 255.0), a_glow)
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_menu_bg(s: int, tokens: TokenTable) -> np.ndarray:
    _ = (s, tokens)
    if not MENU_MAP_INPUT.is_file():
        raise FileNotFoundError(f"Missing menu map input: {MENU_MAP_INPUT}")
    src = load_png_rgba(MENU_MAP_INPUT).astype(np.float64) / 255.0
    rgb = src[..., :3]

    # CSS saturate(0.85) matrix
    sat = 0.85
    m_sat = np.array(
        [
            [0.213 + 0.787 * sat, 0.715 - 0.715 * sat, 0.072 - 0.072 * sat],
            [0.213 - 0.213 * sat, 0.715 + 0.285 * sat, 0.072 - 0.072 * sat],
            [0.213 - 0.213 * sat, 0.715 - 0.715 * sat, 0.072 + 0.928 * sat],
        ],
        dtype=np.float64,
    )
    rgb = np.clip(rgb @ m_sat.T, 0.0, 1.0)

    # CSS sepia(0.22) matrix
    sep = 0.22
    m_sep = np.array(
        [
            [1.0 - 0.607 * sep, 0.769 * sep, 0.189 * sep],
            [0.349 * sep, 1.0 - 0.314 * sep, 0.168 * sep],
            [0.272 * sep, 0.534 * sep, 1.0 - 0.869 * sep],
        ],
        dtype=np.float64,
    )
    rgb = np.clip(rgb @ m_sep.T, 0.0, 1.0)

    # CSS brightness(0.82)
    rgb = np.clip(rgb * 0.82, 0.0, 1.0)

    out = np.ones_like(src)
    out[..., :3] = rgb
    return (np.floor(out * 255.0 + 0.5)).astype(np.uint8)


def art_pieces() -> list[PieceSpec]:
    return [
        PieceSpec(
            name="seal",
            slice_num=1,
            size=(72, 72),
            margin=(0, 0, 0, 0),
            content=(0, 0, 0, 0),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_seal,
        ),
        PieceSpec(
            name="stud",
            slice_num=1,
            size=(12, 12),
            margin=(0, 0, 0, 0),
            content=(0, 0, 0, 0),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_stud,
        ),
        PieceSpec(
            name="glow_soft",
            slice_num=1,
            size=(64, 64),
            margin=(24, 24, 24, 24),
            content=(0, 0, 0, 0),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_glow_soft,
        ),
        PieceSpec(
            name="rule_diamond",
            slice_num=1,
            size=(256, 12),
            margin=(0, 0, 0, 0),
            content=(0, 0, 0, 0),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=True,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_rule_diamond,
        ),
        PieceSpec(
            name="icons_base",
            slice_num=1,
            size=(128, 32),
            margin=(0, 0, 0, 0),
            content=(0, 0, 0, 0),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_icons_base,
        ),
        PieceSpec(
            name="wordmark",
            slice_num=1,
            size=(1024, 256),
            margin=(0, 0, 0, 0),
            content=(0, 0, 0, 0),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=False,
            min_width=0,
            check="tolerant",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_wordmark,
        ),
        PieceSpec(
            name="rose",
            slice_num=1,
            size=(512, 512),
            margin=(0, 0, 0, 0),
            content=(0, 0, 0, 0),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=False,
            min_width=0,
            check="tolerant",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_rose,
        ),
        PieceSpec(
            name="menu_shade",
            slice_num=1,
            size=(480, 270),
            margin=(0, 0, 0, 0),
            content=(0, 0, 0, 0),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1,),
            out_subdir="menu",
            render=_render_menu_shade,
        ),
        PieceSpec(
            name="menu_bg",
            slice_num=1,
            size=(1920, 1080),
            margin=(0, 0, 0, 0),
            content=(0, 0, 0, 0),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1,),
            out_subdir="menu",
            render=_render_menu_bg,
        ),
    ]
