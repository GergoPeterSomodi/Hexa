"""Slice 2 Studiolo textures for M2 (docs/architecture/m2-build-spec.md 6.4, 7.2, 7.8):
minimap_frame, shield_rim, shield_rim_sm, pennant_pole, pennant_cloth.
"""
from __future__ import annotations

import math

import numpy as np

from .materials import gilt_stops, sample_ramp, walnut_rgb
from .pieces_frames import PieceSpec
from .shapes import (
    blend_rgb_mask,
    coverage,
    logical_grid,
    sd_circle,
    sd_pointed_rect,
    sd_rounded_rect,
    sd_segment,
    stroke_coverage,
)
from .tokens import TokenTable, parse_hex_color

# Exact 15-vertex heater shield outline from CountryArms.SHIELD (m2-build-spec.md 7.2) at 48 x 56.
SHIELD_OUTLINE: tuple[tuple[float, float], ...] = (
    (0.0, 0.0),
    (48.0, 0.0),
    (48.0, 26.0),
    (47.0, 33.0),
    (45.0, 39.0),
    (41.0, 45.0),
    (36.0, 50.0),
    (30.0, 54.0),
    (24.0, 56.0),
    (18.0, 54.0),
    (12.0, 50.0),
    (7.0, 45.0),
    (3.0, 39.0),
    (1.0, 33.0),
    (0.0, 26.0),
)


def sd_polygon(
    lx: np.ndarray,
    ly: np.ndarray,
    pts: list[tuple[float, float]] | tuple[tuple[float, float], ...],
) -> np.ndarray:
    """Exact Euclidean signed distance (negative inside, positive outside) to a closed simple polygon."""
    n = len(pts)
    d_min = np.full(lx.shape, 1e12, dtype=np.float64)
    inside = np.zeros(lx.shape, dtype=bool)
    for i in range(n):
        ax, ay = pts[i]
        bx, by = pts[(i + 1) % n]
        d_edge = sd_segment(lx, ly, ax, ay, bx, by)
        d_min = np.minimum(d_min, d_edge)
        if ay != by:
            crosses = (ay > ly) != (by > ly)
            x_int = (bx - ax) * (ly - ay) / (by - ay) + ax
            inside ^= crosses & (lx < x_int)
    return np.where(inside, -d_min, d_min)


def _sd_ellipse(lx: np.ndarray, ly: np.ndarray, cx: float, cy: float, rx: float, ry: float) -> np.ndarray:
    dx = (lx - cx) / rx
    dy = (ly - cy) / ry
    r = np.sqrt(dx * dx + dy * dy)
    return (r - 1.0) * min(rx, ry)


def _render_minimap_frame(s: int, tokens: TokenTable) -> np.ndarray:
    """256 x 144 elongated-hexagon walnut & gilt frame with transparent aperture (M 56, 16; C 8)."""
    w, h = 256, 144
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)

    tip = 28.0
    band_w = 8.0
    sd_outer = sd_pointed_rect(lx, ly, w * 0.5, h * 0.5, w * 0.5, h * 0.5, tip)
    sd_inner = sd_outer + band_w

    outer_cov = coverage(sd_outer, s)
    inner_cov = coverage(sd_inner, s)
    band_cov = np.clip(outer_cov - inner_cov, 0.0, 1.0)

    # Mitred walnut grain: horizontal on top/bottom bars, vertical on slanted side arms.
    wood_h = walnut_rgb(lx, ly, tokens, vertical=False, period_x=144, period_y=112, seed=21)
    wood_v = walnut_rgb(lx, ly, tokens, vertical=True, period_x=144, period_y=112, seed=23)
    dx_edge = np.minimum(lx, float(w) - lx)
    dy_edge = np.minimum(ly, float(h) - ly)
    is_side = (dx_edge < tip + 4.0) & (dy_edge >= band_w)
    wood = np.where(is_side[..., None], wood_v, wood_h)

    y_norm = np.clip(ly / float(h), 0.0, 1.0)
    wood_hi = np.asarray(parse_hex_color("#7a5230")[:3], dtype=np.float64)
    wood_dk = np.asarray(tokens.rgb("WOOD_DARK"), dtype=np.float64)
    top_bevel = np.clip(1.0 - y_norm * 2.0, 0.0, 1.0) * 0.25
    bot_shade = np.clip((y_norm - 0.5) * 2.0, 0.0, 1.0) * 0.30
    wood = np.clip(
        wood * (1.0 - top_bevel[..., None] - bot_shade[..., None])
        + wood_hi * top_bevel[..., None]
        + wood_dk * bot_shade[..., None],
        0.0,
        1.0,
    )
    out = blend_rgb_mask(out, wood, band_cov)

    # Outer bevelled gilt fillet + inner gilt fillet, strictly clipped within the frame band.
    gilt_outer = sample_ramp(y_norm, gilt_stops(tokens))
    gilt_inner = (
        0.35 * np.asarray(tokens.rgb("BRASS_HI"), dtype=np.float64)
        + 0.65 * np.asarray(tokens.rgb("BRASS"), dtype=np.float64)
    )
    out = blend_rgb_mask(out, gilt_outer, band_cov * stroke_coverage(sd_outer, -1.8, 0.85, s))
    out = blend_rgb_mask(out, gilt_inner, band_cov * stroke_coverage(sd_outer, -6.5, 0.6, s))

    # Crisp 1 px INK hairlines on outer and inner edges (strictly zero alpha outside outer and inside aperture).
    ink = np.asarray(tokens.rgb("INK"), dtype=np.float64)
    ink_out = band_cov * stroke_coverage(sd_outer, -0.5, 0.5, s)
    ink_in = band_cov * stroke_coverage(sd_inner, 0.5, 0.5, s)
    out = blend_rgb_mask(out, ink, np.maximum(ink_out, ink_in))
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_shield_rim(s: int, tokens: TokenTable, small: bool) -> np.ndarray:
    """Heater shield brass rim matching CountryArms.SHIELD at 48 x 56 (or 20 x 24 when small)."""
    w, h = (20, 24) if small else (48, 56)
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)

    sx = float(w) / 48.0
    sy = float(h) / 56.0
    pts = [(x * sx, y * sy) for x, y in SHIELD_OUTLINE]

    rim_w = 2.0 if small else 3.0
    sd_outer = sd_polygon(lx, ly, pts)
    sd_inner = sd_outer + rim_w

    outer_cov = coverage(sd_outer, s)
    inner_cov = coverage(sd_inner, s)
    rim_cov = np.clip(outer_cov - inner_cov, 0.0, 1.0)

    # Warm directional gilt brass that stays luminous around the entire heater curve.
    light_t = np.clip(0.65 * (ly / float(h)) + 0.35 * (lx / float(w)), 0.0, 1.0)
    rim_stops = [
        (0.0, tokens.rgb("BRASS_HI")),
        (0.35, parse_hex_color("#e0ba63")[:3]),
        (0.75, tokens.rgb("BRASS")),
        (1.0, parse_hex_color("#9c7526")[:3]),
    ]
    brass = sample_ramp(light_t, rim_stops)
    out = blend_rgb_mask(out, brass, rim_cov)

    # Bright specular ridge along the centre of the brass band.
    ridge_center = -1.0 if small else -1.55
    ridge_hw = 0.50 if small else 0.65
    hi_mask = rim_cov * stroke_coverage(sd_outer, ridge_center, ridge_hw, s)
    hi_strength = np.clip(1.0 - light_t * 0.7, 0.30, 0.85)
    out = blend_rgb_mask(out, np.asarray(tokens.rgb("BRASS_HI"), dtype=np.float64), hi_mask * hi_strength)

    # Crisp INK hairlines on both outer and inner edges (3 bands: ink / brass / ink).
    ink = np.asarray(tokens.rgb("INK"), dtype=np.float64)
    if small:
        # 2.0 px rim: ~0.5 px outer INK + ~1.0 px brass ridge + ~0.5 px inner INK.
        ink_out = rim_cov * coverage(-sd_outer - 0.5, s)
        ink_in = rim_cov * coverage(sd_outer + 1.5, s)
        out = blend_rgb_mask(out, ink, np.maximum(ink_out, ink_in))
    else:
        ink_out = rim_cov * coverage(-sd_outer - 0.75, s)
        ink_in = rim_cov * coverage(sd_outer + 2.25, s)
        out = blend_rgb_mask(out, ink, np.maximum(ink_out, ink_in))
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_pennant_pole(s: int, tokens: TokenTable) -> np.ndarray:
    """24 x 56 brass pennant pole with finial, collar, plinth base, and ground shadow."""
    w, h = 24, 56
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    cx = 12.0
    ink = np.asarray(tokens.rgb("INK"), dtype=np.float64)

    # Soft ground shadow under base plinth.
    sd_shadow = _sd_ellipse(lx, ly, cx, 52.0, 7.6, 2.4)
    out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), coverage(sd_shadow, s), alpha=0.42)

    # Base plinth.
    sd_base = _sd_ellipse(lx, ly, cx, 50.2, 6.0, 2.0)
    out = blend_rgb_mask(out, ink, coverage(sd_base - 0.7, s))
    base_t = np.clip((lx - (cx - 6.0)) / 12.0 * 0.6 + (ly - 48.2) / 4.0 * 0.4, 0.0, 1.0)
    out = blend_rgb_mask(out, sample_ramp(base_t, gilt_stops(tokens)), coverage(sd_base, s))

    # Vertical brass pole shaft.
    sd_shaft = sd_segment(lx, ly, cx, 10.5, cx, 49.6) - 1.3
    out = blend_rgb_mask(out, ink, coverage(sd_shaft - 0.75, s))
    cyl_t = np.clip((lx - (cx - 1.3)) / 2.6, 0.0, 1.0)
    cyl_stops = [
        (0.0, tokens.rgb("BRASS")),
        (0.28, tokens.rgb("BRASS_HI")),
        (0.65, tokens.rgb("BRASS")),
        (1.0, tokens.rgb("BRASS_LO")),
    ]
    out = blend_rgb_mask(out, sample_ramp(cyl_t, cyl_stops), coverage(sd_shaft, s))

    # Collar below finial.
    sd_collar = sd_rounded_rect(lx, ly, cx, 11.4, 2.4, 0.85, 0.4)
    out = blend_rgb_mask(out, ink, coverage(sd_collar - 0.65, s))
    out = blend_rgb_mask(out, sample_ramp(cyl_t, cyl_stops), coverage(sd_collar, s))

    # Finial orb at top.
    sd_finial = sd_circle(lx, ly, cx, 7.0, 3.1)
    out = blend_rgb_mask(out, ink, coverage(sd_finial - 0.75, s))
    rt = np.clip(np.sqrt(((lx - (cx - 1.0)) / 4.4) ** 2 + ((ly - 5.9) / 4.4) ** 2), 0.0, 1.0)
    finial_stops = [
        (0.0, parse_hex_color("#fff3c4")[:3]),
        (0.45, tokens.rgb("BRASS")),
        (1.0, parse_hex_color("#6b4c14")[:3]),
    ]
    out = blend_rgb_mask(out, sample_ramp(rt, finial_stops), coverage(sd_finial, s))
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_pennant_cloth(s: int, tokens: TokenTable) -> np.ndarray:
    """28 x 20 white swallow-tailed pennant cloth for runtime colour tinting."""
    _ = tokens
    w, h = 28, 20
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)

    x0, x1 = 1.0, 27.0
    span = x1 - x0
    n_samples = 16
    top_pts: list[tuple[float, float]] = []
    bot_pts: list[tuple[float, float]] = []
    for i in range(n_samples + 1):
        u = float(i) / float(n_samples)
        x = x0 + u * span
        flutter = 0.85 * math.sin(u * math.pi * 1.35)
        y_top = 2.0 + 0.7 * u - flutter
        y_bot = 18.0 - 0.7 * u - flutter
        top_pts.append((x, y_top))
        bot_pts.append((x, y_bot))

    pts = top_pts + [(19.5, 10.0)] + list(reversed(bot_pts))
    sd = sd_polygon(lx, ly, pts)
    cov = coverage(sd, s)

    # Neutral grayscale shading (R == G == B) so Sprite2D.modulate tints faithfully to any palette colour.
    u_x = np.clip((lx - x0) / span, 0.0, 1.0)
    v_y = np.clip((ly - 2.0) / 16.0, 0.0, 1.0)
    fold = 0.055 * np.sin(u_x * np.pi * 2.5)
    vert_shade = 0.045 * (1.0 - v_y) - 0.055 * np.clip(v_y - 0.5, 0.0, 0.5) * 2.0
    cloth_lum = np.clip(0.935 + fold + vert_shade, 0.80, 1.0)
    cloth_rgb = np.stack((cloth_lum, cloth_lum, cloth_lum), axis=-1)

    out = blend_rgb_mask(out, cloth_rgb, cov)
    # Crisp dark neutral border inside outline so tinted pennants stay readable over bright terrain/land.
    border_cov = cov * coverage(-sd - 0.65, s)
    out = blend_rgb_mask(out, np.array([0.12, 0.12, 0.12]), border_cov)
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def m2_pieces() -> list[PieceSpec]:
    return [
        PieceSpec(
            name="minimap_frame",
            slice_num=2,
            size=(256, 144),
            margin=(56, 16, 56, 16),
            content=(8, 8, 8, 8),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_minimap_frame,
        ),
        PieceSpec(
            name="shield_rim",
            slice_num=2,
            size=(48, 56),
            margin=(0, 0, 0, 0),
            content=(0, 0, 0, 0),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=lambda s, t: _render_shield_rim(s, t, small=False),
        ),
        PieceSpec(
            name="shield_rim_sm",
            slice_num=2,
            size=(20, 24),
            margin=(0, 0, 0, 0),
            content=(0, 0, 0, 0),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=lambda s, t: _render_shield_rim(s, t, small=True),
        ),
        PieceSpec(
            name="pennant_pole",
            slice_num=2,
            size=(24, 56),
            margin=(0, 0, 0, 0),
            content=(0, 0, 0, 0),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_pennant_pole,
        ),
        PieceSpec(
            name="pennant_cloth",
            slice_num=2,
            size=(28, 20),
            margin=(0, 0, 0, 0),
            content=(0, 0, 0, 0),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_pennant_cloth,
        ),
    ]
