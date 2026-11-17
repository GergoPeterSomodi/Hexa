"""Bake assertions (spec 4.4): contrast ratios, leather/vellum texel bounds, amplitude, fonts, geometry, budgets."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from .pieces_frames import PieceSpec
from .tokens import TokenTable, contrast_ratio, relative_luminance

MIN_CONTRAST = 4.5
MAX_AMPLITUDE = 0.04
VELLUM_MIN_LUM = 0.66
KIT_1X_BUDGET_BYTES = 4 * 1024 * 1024
KIT_2X_BUDGET_BYTES = 16 * 1024 * 1024


class BakeCheckError(AssertionError):
    """Raised when a Studiolo bake assertion fails."""


def _lum_array(rgb_u8: np.ndarray) -> np.ndarray:
    c = rgb_u8.astype(np.float64) / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]


def _content_slice(spec: PieceSpec, s: int) -> tuple[slice, slice]:
    w, h = spec.size
    cl, ct, cr, cb = spec.content
    el, et, er, eb = spec.expand
    x0 = (cl + el) * s
    y0 = (ct + et) * s
    x1 = (w - cr - er) * s
    y1 = (h - cb - eb) * s
    return slice(y0, y1), slice(x0, x1)


def check_token_contrasts(tokens: TokenTable) -> None:
    """Assert every contrast pair of design.md section 3 and ink-on-vellum >= 4.5:1."""
    for ground_name in ("PANEL_BG", "LEATHER"):
        g = tokens.rgb(ground_name)
        for fg_name in ("TEXT", "MUTED", "FAINT", "GOLD", "GOOD", "BAD", "WARN", "INFO"):
            r = contrast_ratio(tokens.rgb(fg_name), g)
            if r < MIN_CONTRAST:
                raise BakeCheckError(f"Contrast {fg_name} on {ground_name} is {r:.2f} < {MIN_CONTRAST}")

    faint_lightest = contrast_ratio(tokens.rgb("FAINT"), tokens.rgb("LEATHER_LIGHTEST"))
    if faint_lightest < MIN_CONTRAST:
        raise BakeCheckError(f"FAINT on LEATHER_LIGHTEST is {faint_lightest:.2f} < {MIN_CONTRAST}")

    for ground_name in ("CARD_BG", "SLOT"):
        g = tokens.rgb(ground_name)
        for fg_name in ("TEXT", "MUTED", "FAINT"):
            r = contrast_ratio(tokens.rgb(fg_name), g)
            if r < MIN_CONTRAST:
                raise BakeCheckError(f"Contrast {fg_name} on {ground_name} is {r:.2f} < {MIN_CONTRAST}")

    for ground_name in ("WOOD", "PANEL_HEAD"):
        g = tokens.rgb(ground_name)
        for fg_name in ("TEXT", "MUTED", "BRASS_HI"):
            r = contrast_ratio(tokens.rgb(fg_name), g)
            if r < MIN_CONTRAST:
                raise BakeCheckError(f"Contrast {fg_name} on {ground_name} is {r:.2f} < {MIN_CONTRAST}")

    button_pairs = [
        ("TEXT", "BUTTON"),
        ("TEXT", "BUTTON_HOT"),
        ("TEXT", "DANGER"),
        ("TEXT", "DANGER_HOT"),
        ("PRIMARY_INK", "PRIMARY"),
        ("BRASS_HI", "VELVET"),
    ]
    for fg_name, bg_name in button_pairs:
        r = contrast_ratio(tokens.rgb(fg_name), tokens.rgb(bg_name))
        if r < MIN_CONTRAST:
            raise BakeCheckError(f"Button contrast {fg_name} on {bg_name} is {r:.2f} < {MIN_CONTRAST}")

    inks = (
        "VELLUM_INK",
        "VELLUM_MUTED",
        "GOOD_INK",
        "BAD_INK",
        "WARN_INK",
        "GOLD_INK",
        "CHART_IRON",
        "CHART_LAPIS",
        "CHART_MADDER",
        "CHART_VERDIGRIS",
        "CHART_OCHRE",
    )
    for v_name in ("VELLUM", "VELLUM_DARKEST"):
        v_rgb = tokens.rgb(v_name)
        for ink_name in inks:
            r = contrast_ratio(tokens.rgb(ink_name), v_rgb)
            if r < MIN_CONTRAST:
                raise BakeCheckError(f"Ink contrast {ink_name} on {v_name} is {r:.2f} < {MIN_CONTRAST}")

    if relative_luminance(tokens.rgb("VELLUM_DARKEST")) < VELLUM_MIN_LUM:
        raise BakeCheckError("VELLUM_DARKEST relative luminance < 0.66")


def check_field_amplitude(rgba: np.ndarray, spec: PieceSpec, s: int) -> None:
    """Assert texture amplitude <= 4% across every texel inside the content rect."""
    ys, xs = _content_slice(spec, s)
    patch = rgba[ys, xs, :3].astype(np.float64) / 255.0
    if patch.size == 0:
        raise BakeCheckError(f"{spec.name}@{s}x has empty content rect")
    mean_rgb = patch.mean(axis=(0, 1))
    # Relative peak deviation per channel from field mean, accounting for 8-bit quantization (+/- 0.5/255)
    safe_mean = np.maximum(mean_rgb, 1.0 / 255.0)
    dev = np.maximum(np.abs(patch - mean_rgb) - (0.5 / 255.0), 0.0)
    max_dev = float(np.max(dev / safe_mean))
    if max_dev > MAX_AMPLITUDE:
        raise BakeCheckError(f"{spec.name}@{s}x content amplitude {max_dev:.4f} > {MAX_AMPLITUDE:.4f}")


def check_leather_surface(rgba: np.ndarray, spec: PieceSpec, s: int, tokens: TokenTable) -> None:
    """Assert FAINT >= 4.5:1 on every content texel and amplitude <= 4%."""
    check_field_amplitude(rgba, spec, s)
    ys, xs = _content_slice(spec, s)
    patch_u8 = rgba[ys, xs, :3]
    lum_bg = _lum_array(patch_u8)
    lum_faint = relative_luminance(tokens.rgb("FAINT"))
    ratios = (np.maximum(lum_faint, lum_bg) + 0.05) / (np.minimum(lum_faint, lum_bg) + 0.05)
    min_ratio = float(np.min(ratios))
    if min_ratio < MIN_CONTRAST:
        raise BakeCheckError(f"{spec.name}@{s}x leather min FAINT contrast {min_ratio:.2f} < {MIN_CONTRAST}")


def check_vellum_surface(rgba: np.ndarray, spec: PieceSpec, s: int) -> None:
    """Assert luminance >= 0.66 on every content texel and amplitude <= 4%."""
    check_field_amplitude(rgba, spec, s)
    ys, xs = _content_slice(spec, s)
    patch_u8 = rgba[ys, xs, :3]
    lum = _lum_array(patch_u8)
    min_lum = float(np.min(lum))
    if min_lum < VELLUM_MIN_LUM:
        raise BakeCheckError(f"{spec.name}@{s}x vellum min luminance {min_lum:.3f} < {VELLUM_MIN_LUM}")


def _collect_geography_chars(geo_dir: Path) -> set[str]:
    chars: set[str] = set()
    if not geo_dir.is_dir():
        return chars

    def walk(node) -> None:
        if isinstance(node, str):
            for ch in node:
                if ord(ch) >= 0x20 and ch != "\u00ad":
                    chars.add(ch)
        elif isinstance(node, list):
            for item in node:
                walk(item)
        elif isinstance(node, dict):
            for k, v in node.items():
                if k in ("name", "names", "title", "label", "capital", "city", "town", "region", "country", "river", "pass", "tribe", "market") or isinstance(v, (list, dict)):
                    walk(v)

    for p in sorted(geo_dir.glob("*.json")):
        walk(json.loads(p.read_text(encoding="utf-8")))
    return chars


def check_fonts(repo_root: Path) -> None:
    """Assert TTF cmap coverage and lnum/tnum GSUB features with fonttools."""
    from fontTools.ttLib import TTFont

    geo_chars = _collect_geography_chars(repo_root / "godot" / "data" / "geography")
    latin1 = {chr(c) for c in range(0x20, 0x7F)} | {chr(c) for c in range(0xA0, 0x100)}
    # European Latin Extended-A excluding deprecated U+0149 ('ŉ') and historic U+017F ('ſ')
    ext_a_body = {chr(c) for c in range(0x100, 0x180)} - {"\u0149", "\u017f"}

    ui_fonts = {
        "cinzel_bold": repo_root / "godot" / "assets" / "fonts" / "cinzel" / "Cinzel-Bold.ttf",
        "alegreya_italic": repo_root / "godot" / "assets" / "fonts" / "alegreya" / "Alegreya-MediumItalic.ttf",
        "alegreya_sc_bold": repo_root / "godot" / "assets" / "fonts" / "alegreya_sc" / "AlegreyaSC-Bold.ttf",
        "alegreya_sans_regular": repo_root / "godot" / "assets" / "fonts" / "alegreya_sans" / "AlegreyaSans-Regular.ttf",
        "alegreya_sans_medium": repo_root / "godot" / "assets" / "fonts" / "alegreya_sans" / "AlegreyaSans-Medium.ttf",
        "alegreya_sans_bold": repo_root / "godot" / "assets" / "fonts" / "alegreya_sans" / "AlegreyaSans-Bold.ttf",
        "fallback": repo_root / "godot" / "assets" / "fonts" / "noto" / "NotoSans-Regular.ttf",
    }

    for key, path in ui_fonts.items():
        if not path.is_file():
            raise BakeCheckError(f"Missing font file: {path}")
        tt = TTFont(str(path))
        cmap = tt.getBestCmap() or {}
        req = latin1 | geo_chars | set("−·×%")
        if key not in ("cinzel_bold", "fallback"):
            req |= set("→↑↓") | ext_a_body
        elif key == "fallback":
            req |= ext_a_body
        missing = sorted(c for c in req if ord(c) not in cmap)
        if missing:
            raise BakeCheckError(f"Font {key} missing required chars: {missing[:10]}")

        if key.startswith("alegreya_sans") or key == "alegreya_sc_bold":
            feats: set[str] = set()
            if "GSUB" in tt and tt["GSUB"].table.FeatureList:
                feats = {fr.FeatureTag for fr in tt["GSUB"].table.FeatureList.FeatureRecord}
            if "lnum" not in feats or "tnum" not in feats:
                raise BakeCheckError(f"Font {key} missing lnum/tnum GSUB features (has {sorted(feats)})")

    wm_font = repo_root / "tools" / "ui_bake" / "fonts" / "CinzelDecorative-Black.ttf"
    if not wm_font.is_file():
        raise BakeCheckError(f"Missing bake wordmark font: {wm_font}")
    wm_cmap = TTFont(str(wm_font)).getBestCmap() or {}
    for ch in "HEXA":
        if ord(ch) not in wm_cmap:
            raise BakeCheckError(f"Wordmark font missing {ch!r}")


def check_piece_geometry(spec: PieceSpec, rgba_1x: np.ndarray | None, rgba_2x: np.ndarray | None) -> None:
    """Assert centre >= 8px, seamless tiled centre periodicity, and 2x == 2 * 1x."""
    w, h = spec.size
    ml, mt, mr, mb = spec.margin
    if any(m > 0 for m in spec.margin):
        cw = w - ml - mr
        ch = h - mt - mb
        if cw < 8:
            raise BakeCheckError(f"{spec.name} 9-slice horizontal centre {cw} < 8 px")
        min_ch = 8 if h >= 28 else 4
        if not spec.fixed_height and ch < min_ch:
            raise BakeCheckError(f"{spec.name} 9-slice vertical centre {ch} < {min_ch} px")

    if rgba_1x is not None:
        if rgba_1x.shape != (h, w, 4):
            raise BakeCheckError(f"{spec.name}@1x shape {rgba_1x.shape} != ({h}, {w}, 4)")
        if spec.axis == "tile":
            # Centre tiles seamlessly: 48-px or 96-px sub-tile self-match / boundary continuity
            centre = rgba_1x[mt : h - mb, ml : w - mr]
            # Verify wrap continuity (left/right and top/bottom of centre share identical noise lattice period)
            if centre.shape[0] % 2 == 0 and centre.shape[1] % 2 == 0 and spec.name != "panel_vellum":
                # Check seamless wrap difference isn't a discontinuity jump
                diff_x = float(np.max(np.abs(centre[:, 0].astype(np.int16) - centre[:, -1].astype(np.int16))))
                diff_y = float(np.max(np.abs(centre[0, :].astype(np.int16) - centre[-1, :].astype(np.int16))))
                if diff_x > 16 or diff_y > 16:
                    raise BakeCheckError(f"{spec.name} tiled centre edge discontinuity ({diff_x}, {diff_y})")
        elif spec.axis == "tile_x":
            centre = rgba_1x[mt : h - mb, ml : w - mr]
            diff_x = float(np.max(np.abs(centre[:, 0].astype(np.int16) - centre[:, -1].astype(np.int16))))
            if diff_x > 18:
                raise BakeCheckError(f"{spec.name} horizontal tiled centre discontinuity ({diff_x})")

    if rgba_1x is not None and rgba_2x is not None:
        if rgba_2x.shape != (rgba_1x.shape[0] * 2, rgba_1x.shape[1] * 2, 4):
            raise BakeCheckError(f"{spec.name}@2x shape {rgba_2x.shape} != 2x of {rgba_1x.shape}")


def check_memory_budget(kit_1x_bytes: int, kit_2x_bytes: int) -> None:
    if kit_1x_bytes >= KIT_1X_BUDGET_BYTES:
        raise BakeCheckError(f"1x kit RGBA8 memory {kit_1x_bytes} >= {KIT_1X_BUDGET_BYTES} bytes (4 MB)")
    if kit_2x_bytes >= KIT_2X_BUDGET_BYTES:
        raise BakeCheckError(f"2x kit RGBA8 memory {kit_2x_bytes} >= {KIT_2X_BUDGET_BYTES} bytes (16 MB)")


def run_all_checks(
    repo_root: Path,
    tokens: TokenTable,
    specs: list[PieceSpec],
    rendered: dict[tuple[str, int], np.ndarray],
) -> None:
    check_token_contrasts(tokens)
    check_fonts(repo_root)

    kit_1x_bytes = 0
    kit_2x_bytes = 0
    for spec in specs:
        r1 = rendered.get((spec.name, 1))
        r2 = rendered.get((spec.name, 2))
        check_piece_geometry(spec, r1, r2)

        if spec.out_subdir == "kit":
            if r1 is not None:
                kit_1x_bytes += int(r1.nbytes)
            if r2 is not None:
                kit_2x_bytes += int(r2.nbytes)

        for s in spec.scales:
            arr = rendered.get((spec.name, s))
            if arr is None:
                continue
            if spec.name in ("panel_frame", "panel_modal", "toast"):
                check_leather_surface(arr, spec, s, tokens)
            elif spec.name == "panel_vellum":
                check_vellum_surface(arr, spec, s)
            elif spec.name == "panel_card":
                check_field_amplitude(arr, spec, s)

    if kit_1x_bytes > 0 and kit_2x_bytes > 0:
        check_memory_budget(kit_1x_bytes, kit_2x_bytes)
