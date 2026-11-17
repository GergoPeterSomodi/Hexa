"""PNG I/O and deterministic RGBA8 SHA-256 hashing."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path

import numpy as np

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")


def _ensure_pygame():
    import pygame
    if not pygame.get_init():
        pygame.init()
    return pygame


def rgba_sha256(rgba: np.ndarray) -> str:
    arr = np.ascontiguousarray(rgba, dtype=np.uint8)
    return hashlib.sha256(arr.tobytes()).hexdigest()


def float_to_rgba8(arr: np.ndarray) -> np.ndarray:
    """Convert float64 (H, W, 4) in [0, 1] to uint8 (H, W, 4) using deterministic rounding."""
    clamped = np.clip(arr, 0.0, 1.0)
    return np.floor(clamped * 255.0 + 0.5).astype(np.uint8)


def save_png(path: Path, rgba: np.ndarray) -> None:
    pygame = _ensure_pygame()
    arr = np.ascontiguousarray(rgba, dtype=np.uint8)
    h, w, ch = arr.shape
    assert ch == 4, f"Expected RGBA8, got shape {arr.shape}"
    surf = pygame.image.frombuffer(arr.tobytes(), (w, h), "RGBA")
    path.parent.mkdir(parents=True, exist_ok=True)
    pygame.image.save(surf, str(path))


def load_png_rgba(path: Path) -> np.ndarray:
    pygame = _ensure_pygame()
    surf = pygame.image.load(str(path))
    w, h = surf.get_size()
    raw = pygame.image.tobytes(surf, "RGBA")
    return np.frombuffer(raw, dtype=np.uint8).reshape((h, w, 4)).copy()
