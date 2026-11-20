"""Slice 4 feedback frames (spec 4.5; m4-build-spec.md 6.2): the inset vellum field and the two season-strip cells.

`vellum_inset` (96 x 96, M 16, C 10, tiled centre) is a recessed field on a vellum sheet: a calm vellum, never darker
than `VELLUM_DARKEST`, with its ink hairline and inner shade kept inside the 10 px content margin. `strip_cell` and
`strip_cell_now` (48 x 48, M 12, C 6) are flat cells for `SeasonStrip`; the current season's has a brass border.
`check_feedback_pieces` states the asserts of style spec 4.4 for them (vellum luminance, amplitude, the tile's period).
"""
from __future__ import annotations

import numpy as np

from .checks import BakeCheckError, check_vellum_surface
from .noise import fbm_2d
from .pieces_frames import PieceSpec
from .shapes import blend_rgb_mask, coverage, logical_grid, sd_rounded_rect
from .tokens import TokenTable

INSET_PERIOD = 64  # the tiled centre (96 - 2 x 16) repeats every 64 px


def _finish(out: np.ndarray) -> np.ndarray:
    return (np.floor(np.clip(out, 0.0, 1.0) * 255.0 + 0.5)).astype(np.uint8)


def _rgb(tokens: TokenTable, name: str) -> np.ndarray:
    return np.asarray(tokens.rgb(name), dtype=np.float64)


def _render_vellum_inset(s: int, tokens: TokenTable) -> np.ndarray:
    w = h = 96
    lx, ly = logical_grid(w, h, s)
    darkest = _rgb(tokens, "VELLUM_DARKEST")
    vellum = _rgb(tokens, "VELLUM")
    n = fbm_2d(lx, ly, 0.05, 0.05, octaves=3, period_x=INSET_PERIOD, period_y=INSET_PERIOD, seed=23)
    t = (0.30 + 0.40 * n)[..., None]  # 0.3..0.7 of the way from VELLUM_DARKEST to VELLUM: never darker than the token
    field = darkest + (vellum - darkest) * t

    sd = sd_rounded_rect(lx, ly, 48.0, 48.0, 48.0, 48.0, 5.0)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    out = blend_rgb_mask(out, field, coverage(sd, s))

    ink = _rgb(tokens, "INK")
    inside = coverage(sd, s)
    # Inner shade, strongest at the top-left edge, gone by 8 px (the content margin is 10).
    depth = np.clip(-sd, 0.0, 8.0)
    fade = np.clip(1.0 - depth / 8.0, 0.0, 1.0)
    lit = np.clip((96.0 - lx - ly) / 96.0, 0.0, 1.0) * 0.5 + 0.5  # heavier on the top-left
    out = blend_rgb_mask(out, ink, inside * fade * fade * lit, alpha=0.16)
    # One ink hairline just inside the edge.
    edge = np.clip(coverage(sd, s) - coverage(sd + 1.0, s), 0.0, 1.0)
    out = blend_rgb_mask(out, ink, edge, alpha=0.32)
    return _finish(out)


def _render_strip_cell(s: int, tokens: TokenTable, now: bool) -> np.ndarray:
    w = h = 48
    lx, ly = logical_grid(w, h, s)
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    sd = sd_rounded_rect(lx, ly, 24.0, 24.0, 24.0, 24.0, 5.0)
    vellum = _rgb(tokens, "VELLUM")
    if now:
        # A little warmer and lighter than the sheet, in a brass frame two px wide.
        field = vellum + (_rgb(tokens, "BRASS_HI") - vellum) * 0.22
        out = blend_rgb_mask(out, _rgb(tokens, "BRASS"), coverage(sd, s))
        out = blend_rgb_mask(out, _rgb(tokens, "BRASS_LO"), np.clip(coverage(sd, s) - coverage(sd + 1.0, s), 0.0, 1.0))
        out = blend_rgb_mask(out, field, coverage(sd + 2.0, s))
    else:
        field = vellum
        out = blend_rgb_mask(out, _rgb(tokens, "INK"), coverage(sd, s), alpha=0.32)
        out = blend_rgb_mask(out, field, coverage(sd + 1.0, s))
    return _finish(out)


def feedback_pieces() -> list[PieceSpec]:
    def spec(name, size, margin, content, axis, render) -> PieceSpec:
        return PieceSpec(
            name=name, slice_num=4, size=size, margin=margin, content=content, expand=(0, 0, 0, 0), axis=axis,
            fixed_height=False, min_width=0, check="exact", scales=(1, 2), out_subdir="kit", render=render,
        )

    return [
        spec("vellum_inset", (96, 96), (16, 16, 16, 16), (10, 10, 10, 10), "tile", _render_vellum_inset),
        spec("strip_cell", (48, 48), (12, 12, 12, 12), (6, 6, 6, 6), "stretch", lambda s, t: _render_strip_cell(s, t, False)),
        spec("strip_cell_now", (48, 48), (12, 12, 12, 12), (6, 6, 6, 6), "stretch", lambda s, t: _render_strip_cell(s, t, True)),
    ]


def check_feedback_pieces(specs: list[PieceSpec], rendered: dict[tuple[str, int], np.ndarray]) -> None:
    """Style spec 4.4 asserts for slice 4: vellum luminance and amplitude in the content rect, the tile's period."""
    for spec in specs:
        if spec.name not in ("vellum_inset", "strip_cell", "strip_cell_now"):
            continue
        for s in spec.scales:
            arr = rendered.get((spec.name, s))
            if arr is None:
                continue
            check_vellum_surface(arr, spec, s)
    inset = rendered.get(("vellum_inset", 1))
    if inset is not None:
        # The field repeats every 64 px: compare the two strips of the sheet that are one period apart.
        if not _periodic_in_field(inset, INSET_PERIOD):
            raise BakeCheckError("vellum_inset field is not periodic at 64 px")


def _periodic_in_field(arr: np.ndarray, p: int) -> bool:
    """Compare the vellum field away from the frame (the 8 px edge shade breaks equality near the border)."""
    a = arr[10:86, 10 : 96 - p - 10, :3].astype(np.int16)
    b = arr[10:86, 10 + p : 96 - 10, :3].astype(np.int16)
    if a.shape != b.shape or a.size == 0:
        return True
    return int(np.max(np.abs(a - b))) <= 0
