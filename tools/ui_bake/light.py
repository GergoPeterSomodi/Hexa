"""Deterministic directional lighting and box blurs (float64 + - * / sqrt floor only)."""
from __future__ import annotations

import numpy as np

# Azimuth 225 deg, elevation 62 deg from spec 4.4: (-0.332, -0.332, 0.883)
LIGHT_DIR = (-0.332, -0.332, 0.883)


def directional_shade(
    height: np.ndarray,
    surface_scale: float = 1.1,
    step: float = 1.0,
    wrap: bool = True,
) -> np.ndarray:
    """Compute centered directional diffuse shade around 0.0 from a heightfield using central differences."""
    if wrap:
        dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) / (2.0 * step)
        dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) / (2.0 * step)
    else:
        dx = np.empty_like(height)
        dy = np.empty_like(height)
        dx[:, 1:-1] = (height[:, 2:] - height[:, :-2]) / (2.0 * step)
        dx[:, 0] = (height[:, 1] - height[:, 0]) / step
        dx[:, -1] = (height[:, -1] - height[:, -2]) / step
        dy[1:-1, :] = (height[2:, :] - height[:-2, :]) / (2.0 * step)
        dy[0, :] = (height[1, :] - height[0, :]) / step
        dy[-1, :] = (height[-1, :] - height[-2, :]) / step

    nx = -dx * surface_scale
    ny = -dy * surface_scale
    nz = np.ones_like(height)
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    nx *= inv_len
    ny *= inv_len
    nz *= inv_len

    dot = nx * LIGHT_DIR[0] + ny * LIGHT_DIR[1] + nz * LIGHT_DIR[2]
    # Center around the flat-surface diffuse value (0, 0, 1) . L = LIGHT_DIR[2]
    return np.clip(dot - LIGHT_DIR[2], -1.0, 1.0)


def _box_blur_1d_axis(arr: np.ndarray, radius: int, axis: int) -> np.ndarray:
    if radius <= 0:
        return arr
    pad_w = [(0, 0)] * arr.ndim
    pad_w[axis] = (radius, radius)
    padded = np.pad(arr, pad_w, mode="edge")
    cs = np.cumsum(padded, axis=axis, dtype=np.float64)
    zero_shape = list(padded.shape)
    zero_shape[axis] = 1
    cs = np.concatenate([np.zeros(zero_shape, dtype=np.float64), cs], axis=axis)
    n = arr.shape[axis]
    k = 2 * radius + 1
    sl_hi = [slice(None)] * arr.ndim
    sl_lo = [slice(None)] * arr.ndim
    sl_hi[axis] = slice(k, k + n)
    sl_lo[axis] = slice(0, n)
    return (cs[tuple(sl_hi)] - cs[tuple(sl_lo)]) / float(k)


def box_blur(arr: np.ndarray, radius: int, passes: int = 3) -> np.ndarray:
    """Separable multi-pass box blur in float64."""
    if radius <= 0:
        return arr.astype(np.float64, copy=True)
    out = arr.astype(np.float64, copy=True)
    for _ in range(passes):
        out = _box_blur_1d_axis(out, radius, axis=1)
        out = _box_blur_1d_axis(out, radius, axis=0)
    return out
