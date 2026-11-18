"""Slice 1 Studiolo frame textures (spec 4.5): panels, bar, ribbon, toast, cartouche."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Callable

import numpy as np

from .materials import (
    gilt_stops,
    leather_rgb,
    sample_ramp,
    vellum_rgb,
    velvet_stops,
    walnut_rgb,
)
from .shapes import (
    blend_rgb_mask,
    coverage,
    draw_diamond_stud,
    draw_quatrefoil_boss,
    logical_grid,
    sd_box,
    sd_pointed_rect,
    sd_swallowtail,
    stroke_coverage,
)
from .tokens import TokenTable, parse_hex_color


@dataclass(frozen=True)
class PieceSpec:
    name: str
    slice_num: int
    size: tuple[int, int]
    margin: tuple[int, int, int, int]
    content: tuple[int, int, int, int]
    expand: tuple[int, int, int, int]
    axis: str
    fixed_height: bool
    min_width: int
    check: str
    scales: tuple[int, ...]
    out_subdir: str
    render: Callable[[int, TokenTable], np.ndarray]


def _walnut_band_frame(
    w: int,
    h: int,
    s: int,
    tokens: TokenTable,
    box: tuple[float, float, float, float],
    band_w: float = 13.0,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Build walnut border band + gilt fillets + outer drop shadow for a frame box (x0, y0, x1, y1)."""
    lx, ly = logical_grid(w, h, s)
    x0, y0, x1, y1 = box
    cx, cy = 0.5 * (x0 + x1), 0.5 * (y0 + y1)
    hw, hh = 0.5 * (x1 - x0), 0.5 * (y1 - y0)

    out = np.zeros((h * s, w * s, 4), dtype=np.float64)

    sd_outer = sd_box(lx, ly, cx, cy, hw, hh)
    sd_inner = sd_box(lx, ly, cx, cy, hw - band_w, hh - band_w)

    # Outer drop shadow strictly outside the frame box (never darkening the panel interior)
    outer_cov = coverage(sd_outer, s)
    sd_sh = sd_box(lx, ly, cx, cy + 4.0, hw, hh)
    sh_alpha = np.clip(1.0 - np.maximum(sd_sh, 0.0) / 8.0, 0.0, 1.0) * 0.55 * (1.0 - outer_cov)
    out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), sh_alpha)

    # Wood grain: horizontal on top/bottom bands, turned 90 deg on left/right vertical bands
    wood_h = walnut_rgb(lx, ly, tokens, vertical=False, period_x=96, period_y=96, seed=11)
    wood_v = walnut_rgb(lx, ly, tokens, vertical=True, period_x=96, period_y=96, seed=17)
    # Mitred corner split along 45 deg corner diagonals
    dx_edge = np.minimum(lx - x0, x1 - lx)
    dy_edge = np.minimum(ly - y0, y1 - ly)
    is_vert = dx_edge < dy_edge
    wood = np.where(is_vert[..., None], wood_v, wood_h)

    # Tile-seamless walnut tone: constant along border strips (varying only by edge normal, never X/Y gradient)
    # so 9-slice corners and middle strips meet with zero visible step or brightness seam.
    edge_dist = np.minimum(dx_edge, dy_edge)
    top_edge_t = np.clip(1.0 - (ly - y0) / max(1.0, band_w), 0.0, 1.0)
    is_top_band = (ly - y0) <= dx_edge
    bevel_t = np.where(is_top_band, top_edge_t * 0.35, 0.0)
    # Slight warm highlight near outer rim of top border, dark edge rim along inner groove
    wood_hi = np.asarray(parse_hex_color("#7a5230")[:3], dtype=np.float64)
    wood_base = np.asarray(tokens.rgb("WOOD"), dtype=np.float64)
    wood_dk = np.asarray(tokens.rgb("WOOD_DARK"), dtype=np.float64)
    groove_t = np.clip((band_w - edge_dist) / band_w, 0.0, 1.0) * 0.25
    wood_tint = wood_base * (1.0 - bevel_t[..., None]) + wood_hi * bevel_t[..., None]
    wood_tint = wood_tint * (1.0 - groove_t[..., None]) + wood_dk * groove_t[..., None]
    wood = np.clip(0.55 * wood + 0.45 * wood_tint, 0.0, 1.0)

    # Band mask (outer minus inner)
    inner_cov = coverage(sd_inner, s)
    band_cov = np.clip(outer_cov - inner_cov, 0.0, 1.0)
    out = blend_rgb_mask(out, wood, band_cov)

    # Seamless gilt fillets along outer (2.7px inside) and inner (10.0px inside) border
    gilt_outer = (
        0.35 * np.asarray(tokens.rgb("BRASS_HI"), dtype=np.float64)
        + 0.65 * np.asarray(tokens.rgb("BRASS"), dtype=np.float64)
    )
    gilt_inner = np.asarray(tokens.rgb("BRASS"), dtype=np.float64)
    fillet_out = stroke_coverage(sd_outer, -2.7, 0.7, s)
    fillet_in = stroke_coverage(sd_outer, -10.0, 0.5, s)
    out = blend_rgb_mask(out, gilt_outer, fillet_out)
    out = blend_rgb_mask(out, gilt_inner, fillet_in)

    # 1px INK hairline on outer edge and inner edge of walnut band
    ink = np.asarray(tokens.rgb("INK"), dtype=np.float64)
    ink_out = stroke_coverage(sd_outer, -0.5, 0.5, s)
    ink_in = stroke_coverage(sd_inner, 0.5, 0.5, s)
    out = blend_rgb_mask(out, ink, np.maximum(ink_out, ink_in))
    return out, lx, ly


def _render_panel_frame(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = 160, 160
    box = (0.0, 0.0, 160.0, 150.0)
    frame, lx, ly = _walnut_band_frame(w, h, s, tokens, box, band_w=13.0)

    # Leather field inside box (period 96 matches the 32..128 9-slice centre)
    leather = leather_rgb(lx, ly, s, tokens.rgb("PANEL_BG"), period_x=96, period_y=96, seed=4)
    sd_field = sd_box(lx, ly, 80.0, 75.0, 67.0, 62.0)
    field_cov = coverage(sd_field, s)

    # Top glow (<= 7% outside content rect, <= 3.5% inside) and bezel shadow in 13..20px margin
    in_margin = (lx < 32.0) | (lx >= 128.0) | (ly < 32.0) | (ly >= 128.0)
    dist_in = np.maximum(0.0, -sd_field)
    # 13..19px bezel shadow (strictly outside C=20 content rect)
    bezel_sh = np.where(in_margin, np.clip(1.0 - dist_in / 6.0, 0.0, 1.0) * 0.35, 0.0)
    # Warm top glow in top margin (y 13..20, <= 7%), keeping content rect (C=20) within 3.5% amplitude
    gx = (lx - 80.0) / 55.0
    gy = (ly - 13.0) / 7.0
    top_r = np.sqrt(gx * gx + gy * gy)
    top_glow = np.where(in_margin & (ly < 20.0), np.clip(1.0 - top_r, 0.0, 1.0) * 0.07, 0.0)

    field_rgb = np.clip(leather * (1.0 - bezel_sh[..., None]) * (1.0 + top_glow[..., None]), 0.0, 1.0)

    # Place field under walnut frame
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    out = blend_rgb_mask(out, field_rgb, field_cov)
    # Alpha-over frame onto field
    sa = frame[..., 3:4]
    out[..., :3] = frame[..., :3] * sa + out[..., :3] * (1.0 - sa)
    out[..., 3:4] = np.clip(sa + out[..., 3:4] * (1.0 - sa), 0.0, 1.0)

    # Four corner diamond studs
    for sx, sy in ((6.5, 6.5), (153.5, 6.5), (6.5, 143.5), (153.5, 143.5)):
        out = draw_diamond_stud(out, lx, ly, sx, sy, s, tokens)
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_panel_modal(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = 192, 192
    box = (24.0, 24.0, 168.0, 168.0)
    frame, lx, ly = _walnut_band_frame(w, h, s, tokens, box, band_w=13.0)

    leather = leather_rgb(lx, ly, s, tokens.rgb("PANEL_BG"), period_x=96, period_y=96, seed=4)
    sd_field = sd_box(lx, ly, 96.0, 96.0, 59.0, 59.0)
    field_cov = coverage(sd_field, s)
    in_margin = (lx < 48.0) | (lx >= 144.0) | (ly < 48.0) | (ly >= 144.0)
    dist_in = np.maximum(0.0, -sd_field)
    bezel_sh = np.where(in_margin, np.clip(1.0 - dist_in / 12.0, 0.0, 1.0) * 0.35, 0.0)
    field_rgb = np.clip(leather * (1.0 - bezel_sh[..., None]), 0.0, 1.0)

    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    out = blend_rgb_mask(out, field_rgb, field_cov)
    sa = frame[..., 3:4]
    out[..., :3] = frame[..., :3] * sa + out[..., :3] * (1.0 - sa)
    out[..., 3:4] = np.clip(sa + out[..., 3:4] * (1.0 - sa), 0.0, 1.0)

    # Quatrefoil bosses centered on the 13px walnut corner miters (24+6.5 .. 168-6.5), overhanging cleanly inside E=24
    for bx, by in ((30.5, 30.5), (161.5, 30.5), (30.5, 161.5), (161.5, 161.5)):
        out = draw_quatrefoil_boss(out, lx, ly, bx, by, s, tokens)
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_panel_vellum(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = 160, 160
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)

    # Soft outer drop shadow in E=24 overhang
    sd_sheet = sd_box(lx, ly, 80.0, 80.0, 56.0, 56.0)
    sd_sh = sd_box(lx, ly, 80.0, 84.0, 56.0, 56.0)
    sh_alpha = np.clip(1.0 - np.maximum(sd_sh, 0.0) / 14.0, 0.0, 1.0) * 0.55
    out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), sh_alpha)

    vellum = vellum_rgb(lx, ly, tokens, period_x=96, period_y=96, seed=8)
    sheet_cov = coverage(sd_sheet, s)

    # Edge burn inside margin (24..32), keeping 32..128 tiled centre seamless and >= 0.66 luminance
    in_margin = (lx < 32.0) | (lx >= 128.0) | (ly < 32.0) | (ly >= 128.0)
    dist_in = np.maximum(0.0, -sd_sheet)
    burn = np.where(in_margin, np.clip(1.0 - dist_in / 8.0, 0.0, 1.0) * 0.16, 0.0)[..., None]
    burn_rgb = np.array([120.0 / 255.0, 84.0 / 255.0, 30.0 / 255.0], dtype=np.float64)
    vellum = np.clip(vellum * (1.0 - burn) + burn_rgb * burn, 0.0, 1.0)

    out = blend_rgb_mask(out, vellum, sheet_cov)
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_panel_card(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = 48, 48
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)

    sd_outer = sd_box(lx, ly, 24.0, 24.0, 24.0, 24.0)
    out = blend_rgb_mask(out, np.asarray(tokens.rgb("CARD_BG"), dtype=np.float64), coverage(sd_outer, s))

    ink = np.asarray(tokens.rgb("INK"), dtype=np.float64)
    brass = np.asarray(tokens.rgb("BRASS"), dtype=np.float64)

    # 1px INK outer, 1px BRASS, 1px INK, 1px faint BRASS (0.35)
    out = blend_rgb_mask(out, ink, stroke_coverage(sd_outer, -0.5, 0.5, s))
    out = blend_rgb_mask(out, brass, stroke_coverage(sd_outer, -1.5, 0.5, s))
    out = blend_rgb_mask(out, ink, stroke_coverage(sd_outer, -2.5, 0.5, s))
    out = blend_rgb_mask(out, brass, stroke_coverage(sd_outer, -3.5, 0.5, s), alpha=0.35)
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_panel_bar(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = 128, 48
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)

    # Bottom 8px drop shadow (expand bottom = 8)
    sh_a = np.where((ly >= 40.0) & (ly < 48.0), (1.0 - (ly - 40.0) / 8.0) * 0.55, 0.0)
    out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), sh_a)

    # Carved walnut plank y = 0..40, period_x = 112 (matches M_L=8, M_R=8 -> 112px tiled centre)
    wood = walnut_rgb(lx, ly, tokens, vertical=False, period_x=112, period_y=40, seed=11)
    y_norm = np.clip(ly / 40.0, 0.0, 1.0)
    # Subtle top warm light (0.12) to bottom shade (0.40)
    top_hi = np.clip(1.0 - y_norm, 0.0, 1.0) * 0.12
    bot_sh = y_norm * 0.40
    plank_rgb = np.clip(wood * (1.0 - bot_sh[..., None]) + np.array([1.0, 0.86, 0.67]) * top_hi[..., None], 0.0, 1.0)

    plank_mask = np.where(ly < 40.0, 1.0, 0.0)
    out = blend_rgb_mask(out, plank_rgb, plank_mask)

    # Top 1px warm highlight
    out = blend_rgb_mask(out, np.array([1.0, 0.88, 0.71]), np.where(ly < 1.0, 1.0, 0.0), alpha=0.30)
    # Bottom brass moulding (kit.css .topbar): 35=ink, 36=brass-hi, 37..39=brass-lo, 39..40=ink
    ink = np.asarray(tokens.rgb("INK"), dtype=np.float64)
    out = blend_rgb_mask(out, ink, np.where((ly >= 35.0) & (ly < 36.0), 1.0, 0.0))
    out = blend_rgb_mask(out, np.asarray(tokens.rgb("BRASS_HI"), dtype=np.float64), np.where((ly >= 36.0) & (ly < 37.0), 1.0, 0.0))
    out = blend_rgb_mask(out, np.asarray(tokens.rgb("BRASS_LO"), dtype=np.float64), np.where((ly >= 37.0) & (ly < 39.0), 1.0, 0.0))
    out = blend_rgb_mask(out, ink, np.where((ly >= 39.0) & (ly < 40.0), 1.0, 0.0))
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_ribbon(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = 128, 40
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    sdf = sd_swallowtail(lx, ly, w * 0.5, h * 0.5, w * 0.5, h * 0.5, 14.0)
    cov = coverage(sdf, s)

    velvet = sample_ramp(np.clip(ly / float(h), 0.0, 1.0), velvet_stops(tokens))
    out = blend_rgb_mask(out, velvet, cov)

    # Top 2px brass, 1px dark under top brass; bottom 2px brass_lo
    out = blend_rgb_mask(out, np.asarray(tokens.rgb("BRASS"), dtype=np.float64), cov * np.where(ly < 2.0, 1.0, 0.0))
    out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), cov * np.where((ly >= 2.0) & (ly < 3.0), 1.0, 0.0), alpha=0.50)
    out = blend_rgb_mask(out, np.asarray(tokens.rgb("BRASS_LO"), dtype=np.float64), cov * np.where(ly >= float(h) - 2.0, 1.0, 0.0))
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_toast(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = 128, 40
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    sdf = sd_swallowtail(lx, ly, w * 0.5, h * 0.5, w * 0.5, h * 0.5, 12.0)
    cov = coverage(sdf, s)

    leather = leather_rgb(lx, ly, s, tokens.rgb("LEATHER"), period_x=56, period_y=40, seed=5)
    # Keep content rect (y 8..32) calm (<= 3.5% amplitude), darken slightly near top/bottom brass trim
    edge_sh = np.where((ly < 8.0) | (ly >= 32.0), 0.14, 0.0)[..., None]
    out = blend_rgb_mask(out, leather * (1.0 - edge_sh), cov)

    # Brass top/bottom lines + 1px INK inner line
    ink = np.asarray(tokens.rgb("INK"), dtype=np.float64)
    out = blend_rgb_mask(out, np.asarray(tokens.rgb("BRASS"), dtype=np.float64), cov * np.where(ly < 2.0, 1.0, 0.0))
    out = blend_rgb_mask(out, ink, cov * np.where((ly >= 2.0) & (ly < 3.0), 1.0, 0.0))
    out = blend_rgb_mask(out, ink, cov * np.where((ly >= float(h) - 3.0) & (ly < float(h) - 2.0), 1.0, 0.0))
    out = blend_rgb_mask(out, np.asarray(tokens.rgb("BRASS_LO"), dtype=np.float64), cov * np.where(ly >= float(h) - 2.0, 1.0, 0.0))
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_cartouche(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = 96, 36
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    sdf = sd_pointed_rect(lx, ly, w * 0.5, h * 0.5, w * 0.5, h * 0.5, 12.0)
    outer_cov = coverage(sdf, s)
    inner_cov = coverage(sdf + 2.0, s)

    y_norm = np.clip(ly / float(h), 0.0, 1.0)
    gilt = sample_ramp(y_norm, gilt_stops(tokens))
    out = blend_rgb_mask(out, gilt, outer_cov)

    wood = walnut_rgb(lx, ly, tokens, vertical=False, period_x=96, period_y=36, seed=13)
    shade = np.clip(1.0 - (0.05 + 0.45 * y_norm), 0.5, 1.0)[..., None]
    out = blend_rgb_mask(out, wood * shade, inner_cov)
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def frame_pieces() -> list[PieceSpec]:
    return [
        PieceSpec(
            name="panel_frame",
            slice_num=1,
            size=(160, 160),
            margin=(32, 32, 32, 32),
            content=(20, 20, 20, 20),
            expand=(0, 0, 0, 10),
            axis="tile",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_panel_frame,
        ),
        PieceSpec(
            name="panel_modal",
            slice_num=1,
            size=(192, 192),
            margin=(48, 48, 48, 48),
            content=(28, 28, 28, 28),
            expand=(24, 24, 24, 24),
            axis="tile",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_panel_modal,
        ),
        PieceSpec(
            name="panel_vellum",
            slice_num=1,
            size=(160, 160),
            margin=(32, 32, 32, 32),
            content=(24, 24, 24, 24),
            expand=(24, 24, 24, 24),
            axis="tile",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_panel_vellum,
        ),
        PieceSpec(
            name="panel_card",
            slice_num=1,
            size=(48, 48),
            margin=(12, 12, 12, 12),
            content=(10, 10, 10, 10),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_panel_card,
        ),
        PieceSpec(
            name="panel_bar",
            slice_num=1,
            size=(128, 48),
            margin=(8, 4, 8, 10),
            content=(8, 4, 8, 8),
            expand=(0, 0, 0, 8),
            axis="tile_x",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_panel_bar,
        ),
        PieceSpec(
            name="ribbon",
            slice_num=1,
            size=(128, 40),
            margin=(36, 12, 36, 12),
            content=(36, 8, 36, 8),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=False,
            min_width=230,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_ribbon,
        ),
        PieceSpec(
            name="toast",
            slice_num=1,
            size=(128, 40),
            margin=(36, 20, 36, 20),
            content=(36, 8, 36, 8),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=True,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_toast,
        ),
        PieceSpec(
            name="cartouche",
            slice_num=1,
            size=(96, 36),
            margin=(24, 18, 24, 18),
            content=(24, 6, 24, 6),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=True,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_cartouche,
        ),
    ]
