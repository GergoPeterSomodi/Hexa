"""Parse Studiolo UI tokens directly from godot/shell/ui/tokens.gd without duplicating hex values."""
from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass
from pathlib import Path

ONE_LINE_RE = re.compile(r'^const ([A-Z][A-Z0-9_]*) := (?:Color\("(#[0-9a-f]{6,8})"\)|(\d+))$')


@dataclass(frozen=True)
class TokenTable:
    colors: dict[str, tuple[float, float, float, float]]
    sizes: dict[str, int]
    raw: dict[str, str]
    tokens_sha: str

    def rgb(self, name: str) -> tuple[float, float, float]:
        r, g, b, _ = self.colors[name]
        return (r, g, b)

    def rgba(self, name: str) -> tuple[float, float, float, float]:
        return self.colors[name]


def parse_hex_color(hex_str: str) -> tuple[float, float, float, float]:
    s = hex_str.lstrip("#")
    if len(s) == 6:
        r, g, b = int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)
        a = 255
    elif len(s) == 8:
        r, g, b, a = int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), int(s[6:8], 16)
    else:
        raise ValueError(f"Invalid hex colour: {hex_str!r}")
    return (r / 255.0, g / 255.0, b / 255.0, a / 255.0)


def load_tokens(tokens_path: Path) -> TokenTable:
    text = tokens_path.read_text(encoding="utf-8")
    colors: dict[str, tuple[float, float, float, float]] = {}
    sizes: dict[str, int] = {}
    raw: dict[str, str] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line.startswith("const ") or ":=" not in line:
            continue
        m = ONE_LINE_RE.match(line)
        if not m:
            continue
        name, hex_val, int_val = m.group(1), m.group(2), m.group(3)
        if hex_val is not None:
            colors[name] = parse_hex_color(hex_val)
            raw[name] = hex_val
        elif int_val is not None:
            sizes[name] = int(int_val)
            raw[name] = int_val
    digest_input = "\n".join(f"{k}={raw[k]}" for k in sorted(raw)).encode("utf-8")
    tokens_sha = hashlib.sha256(digest_input).hexdigest()
    return TokenTable(colors=colors, sizes=sizes, raw=raw, tokens_sha=tokens_sha)


def _channel_luminance(c: float) -> float:
    if c <= 0.04045:
        return c / 12.92
    return ((c + 0.055) / 1.055) ** 2.4


def relative_luminance(rgb: tuple[float, float, float]) -> float:
    return (
        0.2126 * _channel_luminance(rgb[0])
        + 0.7152 * _channel_luminance(rgb[1])
        + 0.0722 * _channel_luminance(rgb[2])
    )


def contrast_ratio(a: tuple[float, float, float], b: tuple[float, float, float]) -> float:
    la = relative_luminance(a)
    lb = relative_luminance(b)
    lighter = max(la, lb)
    darker = min(la, lb)
    return (lighter + 0.05) / (darker + 0.05)
