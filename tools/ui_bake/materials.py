"""Procedural Studiolo surface materials: leather, walnut, brushed brass, vellum, velvet, lapis, wax, bone."""
from __future__ import annotations

import numpy as np

from .light import directional_shade
from .noise import fbm_2d
from .tokens import TokenTable, parse_hex_color

# CSS six-stop wood transfer tables from docs/design/ui/studiolo/kit.css (--t-wood)
_WOOD_R = [0.14, 0.22, 0.33, 0.21, 0.37, 0.27]
_WOOD_G = [0.08, 0.13, 0.20, 0.12, 0.23, 0.16]
_WOOD_B = [0.045, 0.07, 0.11, 0.065, 0.13, 0.09]

# Literal sin/cos for 20 deg rotation (no trig calls at runtime)
_COS20 = 0.9396926207859084
_SIN20 = 0.3420201433256687


def _rgb_hex(h: str) -> tuple[float, float, float]:
    r, g, b, _ = parse_hex_color(h)
    return (r, g, b)


def sample_ramp(t: np.ndarray, stops: list[tuple[float, tuple[float, float, float]]]) -> np.ndarray:
    """Piecewise-linear RGB ramp for t in [0, 1]. Returns shape (*t.shape, 3) float64."""
    tc = np.clip(t, 0.0, 1.0)
    out = np.empty((*tc.shape, 3), dtype=np.float64)
    p0, c0 = stops[0]
    out[..., 0] = c0[0]
    out[..., 1] = c0[1]
    out[..., 2] = c0[2]
    for i in range(len(stops) - 1):
        pa, ca = stops[i]
        pb, cb = stops[i + 1]
        span = max(1e-9, pb - pa)
        mask = (tc >= pa) & (tc <= pb)
        u = np.where(mask, (tc - pa) / span, 0.0)
        for ch in range(3):
            val = ca[ch] + u * (cb[ch] - ca[ch])
            out[..., ch] = np.where(mask, val, out[..., ch])
    p_end, c_end = stops[-1]
    mask_end = tc >= p_end
    for ch in range(3):
        out[..., ch] = np.where(mask_end, c_end[ch], out[..., ch])
    return out


def _table_1d(t: np.ndarray, values: list[float]) -> np.ndarray:
    n = len(values) - 1
    tc = np.clip(t, 0.0, 1.0) * float(n)
    idx = np.minimum(np.floor(tc).astype(np.int64), n - 1)
    frac = tc - idx.astype(np.float64)
    arr = np.asarray(values, dtype=np.float64)
    return arr[idx] + frac * (arr[idx + 1] - arr[idx])


def gilt_stops(tokens: TokenTable) -> list[tuple[float, tuple[float, float, float]]]:
    return [
        (0.0, tokens.rgb("BRASS_HI")),
        (0.22, _rgb_hex("#d9b25a")),
        (0.52, _rgb_hex("#b08a36")),
        (0.56, _rgb_hex("#8a6621")),
        (1.0, tokens.rgb("BRASS")),
    ]


def plate_stops(tokens: TokenTable) -> list[tuple[float, tuple[float, float, float]]]:
    return [
        (0.0, _rgb_hex("#fbe9a8")),
        (0.30, tokens.rgb("PRIMARY_HOT")),
        (0.62, tokens.rgb("PRIMARY")),
        (1.0, _rgb_hex("#b98a2c")),
    ]


def velvet_stops(tokens: TokenTable) -> list[tuple[float, tuple[float, float, float]]]:
    return [
        (0.0, _rgb_hex("#7d2031")),
        (0.55, tokens.rgb("VELVET")),
        (1.0, _rgb_hex("#370b13")),
    ]


def bone_stops(tokens: TokenTable) -> list[tuple[float, tuple[float, float, float]]]:
    return [
        (0.0, _rgb_hex("#fbf3dc")),
        (0.60, tokens.rgb("VELLUM")),
        (1.0, _rgb_hex("#cdbb8e")),
    ]


def diamond_angle(dx: np.ndarray, dy: np.ndarray) -> np.ndarray:
    """Trig-free angle in [0, 1) around origin using diamond projection y / (|x| + |y|)."""
    ax = np.abs(dx)
    ay = np.abs(dy)
    denom = ax + ay
    safe_denom = np.where(denom > 1e-12, denom, 1.0)
    # In quadrant 0 (x >= 0, y >= 0): d = dy / (ax + ay) in [0, 1] -> [0, 0.25]
    # Standard diamond angle in [0, 4):
    # q1 (x>=0, y>=0): y/(x+y)
    # q2 (x<0, y>=0):  1 + (-x)/(-x+y) = 2 - y/(-x+y)
    # q3 (x<0, y<0):   2 + (-y)/(-x-y)
    # q4 (x>=0, y<0):  4 - (-y)/(x-y) = 4 + y/(x-y)
    t = dy / safe_denom
    ang = np.where(
        dx >= 0.0,
        np.where(dy >= 0.0, t, 4.0 + t),
        np.where(dy >= 0.0, 2.0 - t, 2.0 - t),
    )
    ang = np.where(denom <= 1e-12, 0.0, ang)
    return (ang * 0.25) % 1.0


def conic_brass(lx: np.ndarray, ly: np.ndarray, cx: float, cy: float, tokens: TokenTable) -> np.ndarray:
    """Conic brass ring texture using diamond angle rotated by 20 deg."""
    dx = lx - cx
    dy = ly - cy
    rx = dx * _COS20 + dy * _SIN20
    ry = -dx * _SIN20 + dy * _COS20
    t = diamond_angle(rx, ry)
    stops = [
        (0.0, tokens.rgb("BRASS_HI")),
        (0.125, _rgb_hex("#8a6621")),
        (0.25, tokens.rgb("GOLD")),
        (0.375, tokens.rgb("BRASS_LO")),
        (0.50, tokens.rgb("BRASS_HI")),
        (0.625, _rgb_hex("#8a6621")),
        (0.75, tokens.rgb("GOLD")),
        (0.875, tokens.rgb("BRASS_LO")),
        (1.0, tokens.rgb("BRASS_HI")),
    ]
    return sample_ramp(t, stops)


def leather_rgb(
    lx: np.ndarray,
    ly: np.ndarray,
    s: int,
    base_rgb: tuple[float, float, float],
    period_x: int = 96,
    period_y: int = 96,
    seed: int = 4,
) -> np.ndarray:
    """Tooled leather RGB (H, W, 3) float64 with amplitude <= 4% and FAINT contrast >= 4.5:1."""
    height = fbm_2d(lx, ly, 0.42, 0.42, octaves=3, period_x=period_x, period_y=period_y, seed=seed)
    # Central difference across +/-1 logical px (= +/-s physical px) for scale consistency
    dx = (np.roll(height, -s, axis=1) - np.roll(height, s, axis=1)) * 0.5
    dy = (np.roll(height, -s, axis=0) - np.roll(height, s, axis=0)) * 0.5
    nx = -dx * 1.1
    ny = -dy * 1.1
    nz = np.ones_like(height)
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    dot = (nx * (-0.332) + ny * (-0.332) + nz * 0.883) * inv_len
    shade = np.clip(dot - 0.883, -0.85, 0.85)
    # 0.04 * shade keeps peak deviation strictly under 3.5% (< 4% budget)
    factor = 1.0 + 0.04 * shade
    out = np.empty((*lx.shape, 3), dtype=np.float64)
    for ch in range(3):
        out[..., ch] = np.clip(base_rgb[ch] * factor, 0.0, 1.0)
    return out


def walnut_rgb(
    lx: np.ndarray,
    ly: np.ndarray,
    tokens: TokenTable,
    vertical: bool = False,
    period_x: int = 112,
    period_y: int = 96,
    seed: int = 11,
) -> np.ndarray:
    """Carved walnut wood grain from kit.css --t-wood six-stop transfer table."""
    fx, fy = (0.19, 0.006) if vertical else (0.006, 0.19)
    n = fbm_2d(lx, ly, fx, fy, octaves=4, period_x=period_x, period_y=period_y, seed=seed)
    grain = np.empty((*lx.shape, 3), dtype=np.float64)
    grain[..., 0] = _table_1d(n, _WOOD_R)
    grain[..., 1] = _table_1d(n, _WOOD_G)
    grain[..., 2] = _table_1d(n, _WOOD_B)
    wood = np.asarray(tokens.rgb("WOOD"), dtype=np.float64)
    return np.clip(0.65 * grain + 0.35 * wood, 0.0, 1.0)


def brushed_plate_rgb(
    lx: np.ndarray,
    ly: np.ndarray,
    y_norm: np.ndarray,
    tokens: TokenTable,
    period_x: int = 240,
    period_y: int = 80,
    seed: int = 3,
) -> np.ndarray:
    """Brushed gilt plate (--plate + --t-brush streaks)."""
    base = sample_ramp(y_norm, plate_stops(tokens))
    n = fbm_2d(lx, ly, 0.012, 0.85, octaves=2, period_x=period_x, period_y=period_y, seed=seed)
    alpha = np.clip(0.9 * n - 0.3, 0.0, 0.32)[..., None]
    streak_rgb = np.array([1.0, 0.95, 0.80], dtype=np.float64)
    return np.clip(base * (1.0 - alpha) + streak_rgb * alpha, 0.0, 1.0)


def vellum_rgb(
    lx: np.ndarray,
    ly: np.ndarray,
    tokens: TokenTable,
    period_x: int = 96,
    period_y: int = 96,
    seed: int = 8,
) -> np.ndarray:
    """Calm aged vellum field keeping luminance >= 0.66 and amplitude <= 4%."""
    base = np.asarray(tokens.rgb("VELLUM"), dtype=np.float64)
    n = fbm_2d(lx, ly, 0.035, 0.035, octaves=5, period_x=period_x, period_y=period_y, seed=seed)
    # Clamp blotch opacity so relative luminance stays >= 0.66 (VELLUM_DARKEST ~ #e1d5b8) and amplitude <= 4%
    blotch_a = np.clip((0.55 * n - 0.14) * 0.22, 0.0, 0.075)[..., None]
    blotch_rgb = np.array([0.45, 0.32, 0.14], dtype=np.float64)
    return np.clip(base * (1.0 - blotch_a) + blotch_rgb * blotch_a, 0.0, 1.0)


# Keep unused import quiet check happy
_ = directional_shade
