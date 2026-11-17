"""Slice 1 Studiolo control textures (spec 4.5): buttons, slots, nav, switch, grabber, keycaps, progress."""
from __future__ import annotations

import numpy as np

from .materials import bone_stops, brushed_plate_rgb, sample_ramp
from .pieces_frames import PieceSpec
from .shapes import (
    blend_rgb_mask,
    coverage,
    logical_grid,
    render_bevel_button,
    sd_box,
    sd_chamfer_rect,
    sd_circle,
    sd_diamond,
    sd_pointed_rect,
    sd_rounded_rect,
    stroke_coverage,
)
from .tokens import TokenTable, parse_hex_color


def _make_btn_renderer(variant: str, state: str, menu: bool):
    def _render(s: int, tokens: TokenTable) -> np.ndarray:
        w, h = (96, 42) if menu else (64, 40)
        lx, ly = logical_grid(w, h, s)
        if menu:
            sdf = sd_pointed_rect(lx, ly, w * 0.5, h * 0.5, w * 0.5, h * 0.5, 17.0)
        else:
            sdf = sd_chamfer_rect(lx, ly, w * 0.5, h * 0.5, w * 0.5, h * 0.5, 6.0)
        rgba = render_bevel_button(w, h, s, sdf, lx, ly, variant, state, tokens)
        return (np.floor(np.clip(rgba, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)

    return _render


def _render_focus(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = 64, 40
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    sdf = sd_chamfer_rect(lx, ly, w * 0.5, h * 0.5, w * 0.5, h * 0.5, 6.0)
    inner_sdf = sdf + 2.0
    inner_cov = coverage(inner_sdf, s)

    # 2px INFO inner ring + soft 10px GLOW inside
    ring = stroke_coverage(inner_sdf, -1.0, 1.0, s)
    out = blend_rgb_mask(out, np.asarray(tokens.rgb("INFO"), dtype=np.float64), ring)

    glow_band = inner_cov * np.clip(1.0 + inner_sdf / 10.0, 0.0, 1.0) * 0.45
    out = blend_rgb_mask(out, np.asarray(tokens.rgb("GLOW"), dtype=np.float64), glow_band, alpha=tokens.rgba("GLOW")[3])
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_slot(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = 32, 24
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    sdf = sd_rounded_rect(lx, ly, w * 0.5, h * 0.5, w * 0.5 - 1.0, h * 0.5 - 1.0, 3.0)
    cov = coverage(sdf, s)

    out = blend_rgb_mask(out, np.asarray(tokens.rgb("BRASS_LO"), dtype=np.float64), coverage(sdf - 1.0, s))
    out = blend_rgb_mask(out, np.asarray(tokens.rgb("INK"), dtype=np.float64), stroke_coverage(sdf, 0.0, 0.5, s))
    out = blend_rgb_mask(out, np.asarray(tokens.rgb("SLOT"), dtype=np.float64), cov)

    # Top inner recessed shadow
    top_sh = cov * np.clip(1.0 - (ly - 1.5) / 4.0, 0.0, 1.0)
    out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), top_sh, alpha=0.65)
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_plate(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = 32, 24
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    sdf = sd_rounded_rect(lx, ly, w * 0.5, h * 0.5, w * 0.5 - 1.0, h * 0.5 - 1.0, 2.0)
    cov = coverage(sdf, s)
    y_norm = np.clip(ly / float(h), 0.0, 1.0)

    out = blend_rgb_mask(out, np.asarray(tokens.rgb("INK"), dtype=np.float64), coverage(sdf - 1.0, s))
    plate = brushed_plate_rgb(lx, ly, y_norm, tokens, seed=3)
    out = blend_rgb_mask(out, plate, cov)

    top_hi = cov * np.clip(1.0 - np.abs(ly - 1.5), 0.0, 1.0)
    out = blend_rgb_mask(out, np.array([1.0, 1.0, 1.0]), top_hi, alpha=0.55)
    bot_sh = cov * np.clip(ly - (h - 3.5), 0.0, 1.0)
    out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), bot_sh, alpha=0.28)
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_nav_selected(s: int, tokens: TokenTable, ink_mode: bool) -> np.ndarray:
    w, h = 32, 24
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    sdf = sd_rounded_rect(lx, ly, w * 0.5, h * 0.5, w * 0.5, h * 0.5, 2.5)
    cov = coverage(sdf, s)

    if ink_mode:
        bar_col = np.asarray(tokens.rgb("GOLD_INK"), dtype=np.float64)
        fade_a = np.where(lx < 3.0, 1.0, 0.20)
        out = blend_rgb_mask(out, bar_col, cov * fade_a)
    else:
        brass = np.asarray(tokens.rgb("BRASS"), dtype=np.float64)
        x_norm = np.clip((lx - 3.0) / float(w - 3), 0.0, 1.0)
        fade_a = np.where(lx < 3.0, 1.0, 0.28 * (1.0 - x_norm))
        out = blend_rgb_mask(out, brass, cov * fade_a)
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_switch(s: int, tokens: TokenTable, on: bool) -> np.ndarray:
    w, h = 48, 24
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    # 44x22 track centered in 48x24
    sdf_track = sd_rounded_rect(lx, ly, 24.0, 12.0, 22.0, 11.0, 11.0)
    track_cov = coverage(sdf_track, s)

    out = blend_rgb_mask(out, np.asarray(tokens.rgb("BRASS_LO"), dtype=np.float64), coverage(sdf_track - 1.0, s))
    out = blend_rgb_mask(out, np.asarray(tokens.rgb("INK"), dtype=np.float64), stroke_coverage(sdf_track, 0.0, 0.5, s))

    if on:
        y_norm = np.clip((ly - 1.0) / 22.0, 0.0, 1.0)
        track_rgb = sample_ramp(y_norm, [(0.0, parse_hex_color("#152c58")[:3]), (1.0, tokens.rgb("LAPIS"))])
    else:
        track_rgb = np.broadcast_to(np.asarray(tokens.rgb("SLOT"), dtype=np.float64), (*lx.shape, 3)).copy()
    out = blend_rgb_mask(out, track_rgb, track_cov)

    # Inner shadow
    top_sh = track_cov * np.clip(1.0 - (ly - 1.0) / 4.0, 0.0, 1.0)
    out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), top_sh, alpha=0.55)

    # 18px circular knob
    kx = 35.0 if on else 13.0
    ky = 12.0
    sd_knob = sd_circle(lx, ly, kx, ky, 8.5)
    out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), coverage(sd_circle(lx, ly, kx, ky + 1.0, 8.8), s), alpha=0.5)
    out = blend_rgb_mask(out, np.asarray(tokens.rgb("INK"), dtype=np.float64), coverage(sd_knob - 0.8, s))

    rt = np.clip(np.sqrt(((lx - (kx - 2.5)) / 12.0) ** 2 + ((ly - (ky - 3.0)) / 12.0) ** 2), 0.0, 1.0)
    if on:
        knob_stops = [
            (0.0, parse_hex_color("#fff3c4")[:3]),
            (0.5, tokens.rgb("PRIMARY")),
            (1.0, parse_hex_color("#6b4c14")[:3]),
        ]
    else:
        knob_stops = [
            (0.0, parse_hex_color("#e6e0d0")[:3]),
            (0.5, parse_hex_color("#8c8474")[:3]),
            (1.0, parse_hex_color("#4a443a")[:3]),
        ]
    out = blend_rgb_mask(out, sample_ramp(rt, knob_stops), coverage(sd_knob, s))
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_grabber(s: int, tokens: TokenTable, hot: bool) -> np.ndarray:
    w, h = 24, 24
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    sd = sd_diamond(lx, ly, 12.0, 12.0, 8.5, 8.5)

    if hot:
        glow_a = np.clip(1.0 - np.maximum(sd, 0.0) / 3.5, 0.0, 1.0) * 0.55
        out = blend_rgb_mask(out, np.asarray(tokens.rgb("GLOW"), dtype=np.float64), glow_a)
    else:
        out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), coverage(sd_diamond(lx, ly, 12.0, 13.0, 8.8, 8.8), s), alpha=0.45)

    out = blend_rgb_mask(out, np.asarray(tokens.rgb("INK"), dtype=np.float64), coverage(sd - 0.9, s))
    t_grad = np.clip((lx - 3.5 + ly - 3.5) / 34.0, 0.0, 1.0)
    stops = [(0.0, tokens.rgb("BRASS_HI")), (0.5, tokens.rgb("PRIMARY" if hot else "BRASS")), (1.0, tokens.rgb("BRASS_LO"))]
    brass = sample_ramp(t_grad, stops)
    if hot:
        brass = np.clip(brass * 1.15, 0.0, 1.0)
    out = blend_rgb_mask(out, brass, coverage(sd, s))
    out = blend_rgb_mask(out, np.asarray(parse_hex_color("#fff3c4")[:3], dtype=np.float64), coverage(sd_circle(lx, ly, 12.0, 12.0, 2.0), s))
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_keycap(s: int, tokens: TokenTable, waiting: bool) -> np.ndarray:
    w, h = 32, 28
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    # Bone cap sitting on 3px bottom lip + 1px ink outline
    sdf_full = sd_rounded_rect(lx, ly, 16.0, 14.0, 15.0, 13.0, 4.0)
    sdf_face = sd_rounded_rect(lx, ly, 16.0, 12.5, 15.0, 11.5, 4.0)

    out = blend_rgb_mask(out, np.asarray(tokens.rgb("INK"), dtype=np.float64), coverage(sdf_full - 0.8, s))
    # 3px bottom lip (#5c4d3a)
    out = blend_rgb_mask(out, np.asarray(tokens.rgb("VELLUM_MUTED"), dtype=np.float64), coverage(sdf_full, s))

    y_norm = np.clip((ly - 1.0) / 23.0, 0.0, 1.0)
    bone = sample_ramp(y_norm, bone_stops(tokens))
    face_cov = coverage(sdf_face, s)
    out = blend_rgb_mask(out, bone, face_cov)

    # Top 1px white highlight
    top_hi = face_cov * np.clip(1.0 - np.abs(ly - 1.8), 0.0, 1.0)
    out = blend_rgb_mask(out, np.array([1.0, 1.0, 1.0]), top_hi, alpha=0.80)

    if waiting:
        out = blend_rgb_mask(out, np.asarray(tokens.rgb("GOLD"), dtype=np.float64), stroke_coverage(sdf_full, -0.5, 1.0, s))
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _render_progress_fill(s: int, tokens: TokenTable) -> np.ndarray:
    w, h = 32, 12
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    sdf = sd_rounded_rect(lx, ly, 16.0, 6.0, 15.5, 5.5, 5.0)
    cov = coverage(sdf, s)
    y_norm = np.clip(ly / float(h), 0.0, 1.0)
    plate = brushed_plate_rgb(lx, ly, y_norm, tokens, seed=3)
    out = blend_rgb_mask(out, plate, cov)
    top_hi = cov * np.clip(1.0 - np.abs(ly - 1.3), 0.0, 1.0)
    out = blend_rgb_mask(out, np.array([1.0, 1.0, 1.0]), top_hi, alpha=0.55)
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def control_pieces() -> list[PieceSpec]:
    pieces: list[PieceSpec] = []

    for variant in ("secondary", "primary", "danger", "toggle"):
        for state in ("normal", "hot", "pressed", "off"):
            pieces.append(
                PieceSpec(
                    name=f"button_{variant}_{state}",
                    slice_num=1,
                    size=(64, 40),
                    margin=(14, 14, 14, 14),
                    content=(14, 4, 14, 4),
                    expand=(0, 0, 0, 0),
                    axis="stretch",
                    fixed_height=False,
                    min_width=0,
                    check="exact",
                    scales=(1, 2),
                    out_subdir="kit",
                    render=_make_btn_renderer(variant, state, menu=False),
                )
            )

    pieces.append(
        PieceSpec(
            name="toggle_on",
            slice_num=1,
            size=(64, 40),
            margin=(14, 14, 14, 14),
            content=(14, 4, 14, 4),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_make_btn_renderer("toggle", "on", menu=False),
        )
    )
    pieces.append(
        PieceSpec(
            name="focus",
            slice_num=1,
            size=(64, 40),
            margin=(14, 14, 14, 14),
            content=(14, 4, 14, 4),
            expand=(0, 0, 0, 0),
            axis="stretch",
            fixed_height=False,
            min_width=0,
            check="exact",
            scales=(1, 2),
            out_subdir="kit",
            render=_render_focus,
        )
    )

    for variant in ("secondary", "primary", "danger"):
        for state in ("normal", "hot", "pressed", "off"):
            pieces.append(
                PieceSpec(
                    name=f"button_menu_{variant}_{state}",
                    slice_num=1,
                    size=(96, 42),
                    margin=(28, 21, 28, 21),
                    content=(34, 0, 34, 0),
                    expand=(0, 0, 0, 0),
                    axis="stretch",
                    fixed_height=True,
                    min_width=0,
                    check="exact",
                    scales=(1, 2),
                    out_subdir="kit",
                    render=_make_btn_renderer(variant, state, menu=True),
                )
            )

    pieces.extend(
        [
            PieceSpec(
                name="slot",
                slice_num=1,
                size=(32, 24),
                margin=(10, 10, 10, 10),
                content=(10, 2, 10, 2),
                expand=(0, 0, 0, 0),
                axis="stretch",
                fixed_height=False,
                min_width=0,
                check="exact",
                scales=(1, 2),
                out_subdir="kit",
                render=_render_slot,
            ),
            PieceSpec(
                name="plate",
                slice_num=1,
                size=(32, 24),
                margin=(10, 10, 10, 10),
                content=(10, 2, 10, 2),
                expand=(0, 0, 0, 0),
                axis="stretch",
                fixed_height=False,
                min_width=0,
                check="exact",
                scales=(1, 2),
                out_subdir="kit",
                render=_render_plate,
            ),
            PieceSpec(
                name="nav_selected",
                slice_num=1,
                size=(32, 24),
                margin=(10, 10, 10, 10),
                content=(10, 2, 10, 2),
                expand=(0, 0, 0, 0),
                axis="stretch",
                fixed_height=False,
                min_width=0,
                check="exact",
                scales=(1, 2),
                out_subdir="kit",
                render=lambda s, t: _render_nav_selected(s, t, ink_mode=False),
            ),
            PieceSpec(
                name="nav_selected_ink",
                slice_num=1,
                size=(32, 24),
                margin=(10, 10, 10, 10),
                content=(10, 2, 10, 2),
                expand=(0, 0, 0, 0),
                axis="stretch",
                fixed_height=False,
                min_width=0,
                check="exact",
                scales=(1, 2),
                out_subdir="kit",
                render=lambda s, t: _render_nav_selected(s, t, ink_mode=True),
            ),
            PieceSpec(
                name="switch_off",
                slice_num=1,
                size=(48, 24),
                margin=(0, 0, 0, 0),
                content=(0, 0, 0, 0),
                expand=(0, 0, 0, 0),
                axis="stretch",
                fixed_height=True,
                min_width=0,
                check="exact",
                scales=(1, 2),
                out_subdir="kit",
                render=lambda s, t: _render_switch(s, t, on=False),
            ),
            PieceSpec(
                name="switch_on",
                slice_num=1,
                size=(48, 24),
                margin=(0, 0, 0, 0),
                content=(0, 0, 0, 0),
                expand=(0, 0, 0, 0),
                axis="stretch",
                fixed_height=True,
                min_width=0,
                check="exact",
                scales=(1, 2),
                out_subdir="kit",
                render=lambda s, t: _render_switch(s, t, on=True),
            ),
            PieceSpec(
                name="grabber",
                slice_num=1,
                size=(24, 24),
                margin=(0, 0, 0, 0),
                content=(0, 0, 0, 0),
                expand=(0, 0, 0, 0),
                axis="stretch",
                fixed_height=False,
                min_width=0,
                check="exact",
                scales=(1, 2),
                out_subdir="kit",
                render=lambda s, t: _render_grabber(s, t, hot=False),
            ),
            PieceSpec(
                name="grabber_hot",
                slice_num=1,
                size=(24, 24),
                margin=(0, 0, 0, 0),
                content=(0, 0, 0, 0),
                expand=(0, 0, 0, 0),
                axis="stretch",
                fixed_height=False,
                min_width=0,
                check="exact",
                scales=(1, 2),
                out_subdir="kit",
                render=lambda s, t: _render_grabber(s, t, hot=True),
            ),
            PieceSpec(
                name="keycap",
                slice_num=1,
                size=(32, 28),
                margin=(10, 10, 10, 10),
                content=(8, 4, 8, 4),
                expand=(0, 0, 0, 0),
                axis="stretch",
                fixed_height=True,
                min_width=0,
                check="exact",
                scales=(1, 2),
                out_subdir="kit",
                render=lambda s, t: _render_keycap(s, t, waiting=False),
            ),
            PieceSpec(
                name="keycap_wait",
                slice_num=1,
                size=(32, 28),
                margin=(10, 10, 10, 10),
                content=(8, 4, 8, 4),
                expand=(0, 0, 0, 0),
                axis="stretch",
                fixed_height=True,
                min_width=0,
                check="exact",
                scales=(1, 2),
                out_subdir="kit",
                render=lambda s, t: _render_keycap(s, t, waiting=True),
            ),
            PieceSpec(
                name="progress_fill",
                slice_num=1,
                size=(32, 12),
                margin=(6, 4, 6, 4),
                content=(0, 0, 0, 0),
                expand=(0, 0, 0, 0),
                axis="stretch",
                fixed_height=False,
                min_width=0,
                check="exact",
                scales=(1, 2),
                out_subdir="kit",
                render=_render_progress_fill,
            ),
        ]
    )

    _ = sd_box
    return pieces
