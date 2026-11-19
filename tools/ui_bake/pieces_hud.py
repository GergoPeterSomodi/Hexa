"""Slice 3 Studiolo HUD textures (spec 4.5; m3-build-spec.md 6.2): the medallion rims, the dial face and hand,
the hourglass, the End season plate and the seal tones. Medallion rims are rim-only: the face is drawn in code by
`Medallion`'s Dial, so the rim's centre stays transparent.
"""
from __future__ import annotations

from functools import partial

import numpy as np

from .materials import diamond_angle, gilt_stops, sample_ramp
from .noise import fbm_2d
from .pieces_frames import PieceSpec
from .pieces_m2 import sd_polygon
from .shapes import (
    alpha_over,
    blend_rgb_mask,
    coverage,
    logical_grid,
    render_bevel_button,
    sd_box,
    sd_segment,
    sd_swallowtail,
    stroke_coverage,
)
from .tokens import TokenTable, parse_hex_color

# Seal wobble and crack polyline on the 72 px canvas (wax centre 36, 36).
_CRACK: tuple[tuple[float, float], ...] = (
    (6.0, 45.0),
    (19.0, 38.0),
    (28.0, 41.0),
    (37.0, 33.0),
    (46.0, 37.0),
    (66.0, 27.0),
)


def _finish(out: np.ndarray) -> np.ndarray:
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _rgb(tokens: TokenTable, name: str) -> np.ndarray:
    return np.asarray(tokens.rgb(name), dtype=np.float64)


def _hex(value: str) -> np.ndarray:
    return np.asarray(parse_hex_color(value)[:3], dtype=np.float64)


def _render_medallion_rim(s: int, tokens: TokenTable, d: int) -> np.ndarray:
    """Medallion rim (64 or 30 px): ink outer edge, gilt band, ink inner hairline, transparent face."""
    lx, ly = logical_grid(d, d, s)
    out = np.zeros((d * s, d * s, 4), dtype=np.float64)
    c = d * 0.5
    dist = np.sqrt((lx - c) ** 2 + (ly - c) ** 2)

    r_out = c - 0.5
    gilt_w = 6.0 if d >= 64 else 3.0
    ra = r_out - 1.0
    rb = ra - gilt_w

    outside = 1.0 - coverage(dist - r_out, s)
    if d >= 64:
        # Soft drop shadow, one px below the rim, outside the rim only (the face stays transparent).
        sh = np.sqrt((lx - c) ** 2 + (ly - c - 1.5) ** 2)
        out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), coverage(sh - r_out, s) * outside, alpha=0.35)

    # Outer ink hairline: the band one px wide inside the outer edge.
    ink = _rgb(tokens, "INK")
    rim_ink = np.clip(coverage(dist - r_out, s) - coverage(dist - (r_out - 1.0), s), 0.0, 1.0)
    out = blend_rgb_mask(out, ink, rim_ink)

    gilt_cov = coverage(dist - ra, s) * (1.0 - coverage(dist - rb, s))
    y_norm = np.clip(ly / float(d), 0.0, 1.0)
    out = blend_rgb_mask(out, sample_ramp(y_norm, gilt_stops(tokens)), gilt_cov)

    # Lit upper arc of the gilt band.
    lit = np.clip((c - ly) / c, 0.0, 1.0) * gilt_cov
    out = blend_rgb_mask(out, _rgb(tokens, "BRASS_HI"), lit * stroke_coverage(dist, 0.5 * (ra + rb), gilt_w * 0.14, s), alpha=0.55)

    out = blend_rgb_mask(out, ink, stroke_coverage(dist, rb, 0.5, s))
    return _finish(out)


def _render_dial_quarters(s: int, tokens: TokenTable) -> np.ndarray:
    """64 px lapis face with four quarter lines and a gilt hub, inside the medallion rim."""
    d = 64
    lx, ly = logical_grid(d, d, s)
    out = np.zeros((d * s, d * s, 4), dtype=np.float64)
    c = 32.0
    dist = np.sqrt((lx - c) ** 2 + (ly - c) ** 2)
    face_r = 24.0
    face_cov = coverage(dist - face_r, s)
    rt = np.clip(dist / face_r, 0.0, 1.0)
    face = sample_ramp(rt, [(0.0, _hex("#3a6bb5")), (0.6, _rgb(tokens, "LAPIS")), (1.0, _hex("#122a55"))])
    out = blend_rgb_mask(out, face, face_cov)

    quarter_lines = np.maximum(stroke_coverage(lx, c, 0.6, s), stroke_coverage(ly, c, 0.6, s))
    out = blend_rgb_mask(out, _rgb(tokens, "BRASS_LO"), quarter_lines * face_cov, alpha=0.9)

    hub_cov = coverage(dist - 3.5, s)
    out = blend_rgb_mask(out, sample_ramp(np.clip(ly / float(d), 0.0, 1.0), gilt_stops(tokens)), hub_cov)
    out = blend_rgb_mask(out, _rgb(tokens, "INK"), stroke_coverage(dist, 3.5, 0.5, s))
    return _finish(out)


def _render_dial_hand(s: int, tokens: TokenTable) -> np.ndarray:
    """64 px gilt hand pointing up from the centre (the Medallion turns it to the lit quarter)."""
    d = 64
    lx, ly = logical_grid(d, d, s)
    out = np.zeros((d * s, d * s, 4), dtype=np.float64)
    needle = [(32.0, 8.0), (34.6, 31.0), (32.0, 36.0), (29.4, 31.0)]
    sd_n = sd_polygon(lx, ly, needle)
    ink = _rgb(tokens, "INK")
    out = blend_rgb_mask(out, ink, coverage(sd_n - 0.7, s))
    out = blend_rgb_mask(out, sample_ramp(np.clip(ly / float(d), 0.0, 1.0), gilt_stops(tokens)), coverage(sd_n, s))
    dist = np.sqrt((lx - 32.0) ** 2 + (ly - 32.0) ** 2)
    out = blend_rgb_mask(out, ink, coverage(dist - 3.8, s))
    out = blend_rgb_mask(out, _rgb(tokens, "BRASS_HI"), coverage(dist - 2.6, s))
    return _finish(out)


def _render_hourglass(s: int, tokens: TokenTable) -> np.ndarray:
    """24 px hourglass: gilt frame bars, pale glass, gold sand in the lower bulb, ink outlines."""
    w = h = 24
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    ink = _rgb(tokens, "INK")

    glass = [(6.5, 4.5), (17.5, 4.5), (13.2, 12.0), (17.5, 19.5), (6.5, 19.5), (10.8, 12.0)]
    sd_g = sd_polygon(lx, ly, glass)
    glass_cov = coverage(sd_g, s)

    sd_top = sd_box(lx, ly, 12.0, 3.0, 8.0, 1.2)
    sd_bot = sd_box(lx, ly, 12.0, 21.0, 8.0, 1.2)
    frame_sd = np.minimum(sd_top, sd_bot)
    out = blend_rgb_mask(out, ink, coverage(frame_sd - 0.6, s))
    out = blend_rgb_mask(out, sample_ramp(np.clip(ly / float(h), 0.0, 1.0), gilt_stops(tokens)), coverage(frame_sd, s))

    out = blend_rgb_mask(out, _hex("#e9dfc4"), glass_cov, alpha=0.55)
    sand_cov = glass_cov * np.clip(ly - 15.5 + 0.5, 0.0, 1.0)
    out = blend_rgb_mask(out, _rgb(tokens, "GOLD"), sand_cov)
    out = blend_rgb_mask(out, ink, stroke_coverage(sd_g, 0.0, 0.5, s))
    return _finish(out)


def _render_endseason_plate(s: int, tokens: TokenTable, state: str) -> np.ndarray:
    """160 x 44 swallow-tail plate with the primary bevel (spec 4.5 and 6.2)."""
    w, h = 160, 44
    lx, ly = logical_grid(w, h, s)
    sdf = sd_swallowtail(lx, ly, w * 0.5, h * 0.5, w * 0.5, h * 0.5, 14.0)
    rgba = render_bevel_button(w, h, s, sdf, lx, ly, "primary", state, tokens)
    return _finish(rgba)


def _seal_stops(tone: str, tokens: TokenTable) -> list[tuple[float, tuple[float, float, float]]]:
    if tone == "good":
        return [(0.0, _hex("#3f9a86")), (0.45, _rgb(tokens, "GOOD_INK")), (1.0, _hex("#0a3a36"))]
    if tone == "plain":
        return [(0.0, _hex("#c4bcae")), (0.45, _hex("#7d7466")), (1.0, _hex("#3a342c"))]
    return [(0.0, _hex("#d8523c")), (0.45, _rgb(tokens, "SEAL")), (1.0, _hex("#6d130c"))]


def _render_seal_tone(s: int, tokens: TokenTable, tone: str) -> np.ndarray:
    """72 px wax seal: good (green), plain (pewter) or cracked (vermilion with a gap cut across it)."""
    w = h = 72
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    cx, cy = 36.0, 36.0
    dx = lx - cx
    dy = ly - cy
    r_dist = np.sqrt(dx * dx + dy * dy)
    ang = diamond_angle(dx, dy)
    wobble = (fbm_2d(ang * 32.0, ang * 0.0 + 1.0, 0.15, 0.05, octaves=2, period_x=32, period_y=8, seed=19) - 0.5) * 1.4
    r_wax = 31.5 + wobble
    sd_wax = r_dist - r_wax

    sd_sh = np.sqrt(dx * dx + (dy - 2.0) ** 2) - r_wax
    out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), coverage(sd_sh - 1.5, s), alpha=0.45)

    rt = np.clip(np.sqrt(((lx - (cx - 9.0)) / 42.0) ** 2 + ((ly - (cy - 11.0)) / 42.0) ** 2), 0.0, 1.0)
    wax_cov = coverage(sd_wax, s)
    wax = blend_rgb_mask(np.zeros_like(out), sample_ramp(rt, _seal_stops(tone, tokens)), wax_cov)

    ring_dark = wax_cov * stroke_coverage(r_dist, 24.5, 2.0, s)
    ring_hi = wax_cov * stroke_coverage(r_dist, 22.0, 0.7, s)
    wax = blend_rgb_mask(wax, np.array([0.0, 0.0, 0.0]), ring_dark, alpha=0.18)
    wax = blend_rgb_mask(wax, _hex("#ffa082"), ring_hi, alpha=0.28)

    if tone == "cracked":
        d_crack = np.full(lx.shape, 1e12, dtype=np.float64)
        for (x0, y0), (x1, y1) in zip(_CRACK[:-1], _CRACK[1:]):
            d_crack = np.minimum(d_crack, sd_segment(lx, ly, x0, y0, x1, y1))
        edge = coverage(d_crack - 1.9, s) * wax_cov
        gap = coverage(d_crack - 1.2, s)
        wax = blend_rgb_mask(wax, np.array([0.0, 0.0, 0.0]), edge, alpha=0.45)
        wax[..., 3] = wax[..., 3] * (1.0 - gap)

    out = alpha_over(out, wax)
    return _finish(out)


def _spec(
    name: str,
    size: tuple[int, int],
    margin: tuple[int, int, int, int],
    content: tuple[int, int, int, int],
    fixed_height: bool,
    render,
) -> PieceSpec:
    return PieceSpec(
        name=name,
        slice_num=3,
        size=size,
        margin=margin,
        content=content,
        expand=(0, 0, 0, 0),
        axis="stretch",
        fixed_height=fixed_height,
        min_width=0,
        check="exact",
        scales=(1, 2),
        out_subdir="kit",
        render=render,
    )


def hud_pieces() -> list[PieceSpec]:
    zero = (0, 0, 0, 0)
    plate_margin = (28, 22, 44, 22)
    plate_content = (28, 4, 44, 4)
    pieces = [
        _spec("medallion_64", (64, 64), zero, zero, False, partial(_render_medallion_rim, d=64)),
        _spec("medallion_30", (30, 30), zero, zero, False, partial(_render_medallion_rim, d=30)),
        _spec("dial_quarters", (64, 64), zero, zero, False, _render_dial_quarters),
        _spec("dial_hand", (64, 64), zero, zero, False, _render_dial_hand),
        _spec("hourglass", (24, 24), zero, zero, False, _render_hourglass),
    ]
    for state in ("normal", "hot", "pressed", "off"):
        pieces.append(
            _spec(
                f"endseason_plate_{state}",
                (160, 44),
                plate_margin,
                plate_content,
                True,
                partial(_render_endseason_plate, state=state),
            )
        )
    for tone in ("good", "plain", "cracked"):
        pieces.append(_spec(f"seal_{tone}", (72, 72), zero, zero, False, partial(_render_seal_tone, tone=tone)))
    return pieces
