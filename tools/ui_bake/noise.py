"""Deterministic seamless periodic lattice value noise using uint32 hashes and float64 arithmetic only."""
from __future__ import annotations

import numpy as np


def _hash_u32(ix: np.ndarray, iy: np.ndarray, seed: int) -> np.ndarray:
    """Deterministic uint32 hash of 2D integer lattice coordinates."""
    seed_term = np.uint32((seed * 1442695041) & 0xFFFFFFFF)
    with np.errstate(over="ignore"):
        h = ix.astype(np.uint32) * np.uint32(374761393)
        h = h + iy.astype(np.uint32) * np.uint32(668265263) + seed_term
        h = (h ^ (h >> np.uint32(13))) * np.uint32(1274126177)
        h = h ^ (h >> np.uint32(16))
    return h


def value_noise_2d(
    lx: np.ndarray,
    ly: np.ndarray,
    freq_x: float,
    freq_y: float,
    period_x: int,
    period_y: int,
    seed: int,
) -> np.ndarray:
    """Periodic 2D value noise on logical coordinates (lx, ly), wrapping cleanly at (period_x, period_y)."""
    gx = max(1, int(round(freq_x * period_x)))
    gy = max(1, int(round(freq_y * period_y)))
    px = (lx / float(period_x)) * float(gx)
    py = (ly / float(period_y)) * float(gy)

    x0_f = np.floor(px)
    y0_f = np.floor(py)
    fx = px - x0_f
    fy = py - y0_f

    sx = fx * fx * (3.0 - 2.0 * fx)
    sy = fy * fy * (3.0 - 2.0 * fy)

    ix0 = x0_f.astype(np.int64) % gx
    iy0 = y0_f.astype(np.int64) % gy
    ix1 = (ix0 + 1) % gx
    iy1 = (iy0 + 1) % gy

    inv_u32 = 1.0 / 4294967295.0
    v00 = _hash_u32(ix0, iy0, seed).astype(np.float64) * inv_u32
    v10 = _hash_u32(ix1, iy0, seed).astype(np.float64) * inv_u32
    v01 = _hash_u32(ix0, iy1, seed).astype(np.float64) * inv_u32
    v11 = _hash_u32(ix1, iy1, seed).astype(np.float64) * inv_u32

    nx0 = v00 + sx * (v10 - v00)
    nx1 = v01 + sx * (v11 - v01)
    return nx0 + sy * (nx1 - nx0)


def fbm_2d(
    lx: np.ndarray,
    ly: np.ndarray,
    freq_x: float,
    freq_y: float,
    octaves: int,
    period_x: int,
    period_y: int,
    seed: int,
) -> np.ndarray:
    """Periodic fractal Brownian motion in [0, 1]; octave amplitudes halve and frequencies double."""
    total = np.zeros(lx.shape, dtype=np.float64)
    amp = 1.0
    norm = 0.0
    fx = float(freq_x)
    fy = float(freq_y)
    for oct_idx in range(octaves):
        total += amp * value_noise_2d(lx, ly, fx, fy, period_x, period_y, seed + oct_idx * 1013)
        norm += amp
        amp *= 0.5
        fx *= 2.0
        fy *= 2.0
    return total / norm
