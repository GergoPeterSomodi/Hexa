"""Signed-distance primitives, alpha compositing, and bevelled Studiolo controls."""
from __future__ import annotations

import numpy as np

from .materials import (
    brushed_plate_rgb,
    conic_brass,
    gilt_stops,
    sample_ramp,
    walnut_rgb,
)
from .noise import fbm_2d
from .tokens import TokenTable, parse_hex_color

_INV_SQRT2 = 0.7071067811865475


def logical_grid(w: int, h: int, s: int) -> tuple[np.ndarray, np.ndarray]:
    """Return (lx, ly) logical pixel centres for an (h*s, w*s) physical canvas."""
    px = (np.arange(w * s, dtype=np.float64) + 0.5) / float(s)
    py = (np.arange(h * s, dtype=np.float64) + 0.5) / float(s)
    return np.meshgrid(px, py)


def coverage(sdf: np.ndarray, s: int) -> np.ndarray:
    """Anti-aliased interior coverage in [0, 1] from signed distance (negative inside)."""
    return np.clip(0.5 - sdf * float(s), 0.0, 1.0)


def stroke_coverage(sdf: np.ndarray, center_dist: float, half_width: float, s: int) -> np.ndarray:
    """Anti-aliased band coverage around sdf == center_dist."""
    d = np.abs(sdf - center_dist) - half_width
    return np.clip(0.5 - d * float(s), 0.0, 1.0)


def alpha_over(dst: np.ndarray, src: np.ndarray) -> np.ndarray:
    """Composite straight-alpha RGBA float64 src over dst."""
    sa = src[..., 3:4]
    da = dst[..., 3:4]
    out_a = sa + da * (1.0 - sa)
    safe_a = np.where(out_a > 1e-9, out_a, 1.0)
    out_rgb = (src[..., :3] * sa + dst[..., :3] * da * (1.0 - sa)) / safe_a
    out = np.empty_like(dst)
    out[..., :3] = np.where(out_a > 1e-9, out_rgb, 0.0)
    out[..., 3:4] = np.clip(out_a, 0.0, 1.0)
    return out


def blend_rgb_mask(dst: np.ndarray, rgb: np.ndarray, mask: np.ndarray, alpha: float = 1.0) -> np.ndarray:
    """Blend an RGB colour/array over dst RGBA using coverage mask * alpha."""
    src = np.empty_like(dst)
    src[..., :3] = rgb
    src[..., 3] = np.clip(mask * alpha, 0.0, 1.0)
    return alpha_over(dst, src)


def sd_box(lx: np.ndarray, ly: np.ndarray, cx: float, cy: float, hw: float, hh: float) -> np.ndarray:
    dx = np.abs(lx - cx) - hw
    dy = np.abs(ly - cy) - hh
    outside = np.sqrt(np.maximum(dx, 0.0) ** 2 + np.maximum(dy, 0.0) ** 2)
    inside = np.minimum(np.maximum(dx, dy), 0.0)
    return outside + inside


def sd_chamfer_rect(lx: np.ndarray, ly: np.ndarray, cx: float, cy: float, hw: float, hh: float, c: float) -> np.ndarray:
    dx = np.abs(lx - cx)
    dy = np.abs(ly - cy)
    d_box = np.maximum(dx - hw, dy - hh)
    d_chamfer = (dx + dy - (hw + hh - c)) * _INV_SQRT2
    return np.maximum(d_box, d_chamfer)


def sd_pointed_rect(lx: np.ndarray, ly: np.ndarray, cx: float, cy: float, hw: float, hh: float, tip: float) -> np.ndarray:
    """Exact half-hex pointed rectangle: horizontal top/bottom, 2-segment pointed ends of width tip."""
    dx = np.abs(lx - cx)
    dy = np.abs(ly - cy)
    d_y = dy - hh
    # Line through (hw - tip, hh) and (hw, 0): hh * dx + tip * dy - hw * hh = 0
    norm = float(np.sqrt(hh * hh + tip * tip))
    d_tip = (hh * dx + tip * dy - hw * hh) / norm
    return np.maximum(d_y, d_tip)


def sd_swallowtail(lx: np.ndarray, ly: np.ndarray, cx: float, cy: float, hw: float, hh: float, notch: float) -> np.ndarray:
    """Swallow-tailed banner: flat top/bottom, V-notch inward of depth notch on left & right."""
    dx = np.abs(lx - cx)
    dy = np.abs(ly - cy)
    d_rect = np.maximum(dx - hw, dy - hh)
    # Notch cuts out triangle with apex at (hw - notch, 0) and corners (hw, +/-hh):
    # Outside notch triangle (kept): hh * dx - notch * dy <= hh * (hw - notch) ->Wait:
    # At dy=0, dx <= hw - notch; at dy=hh, dx <= hw.
    # So signed distance to the slanted notch edge (pointing outward to right):
    norm = float(np.sqrt(hh * hh + notch * notch))
    d_notch = (hh * dx - notch * dy - hh * (hw - notch)) / norm
    return np.maximum(d_rect, d_notch)


def sd_rounded_rect(lx: np.ndarray, ly: np.ndarray, cx: float, cy: float, hw: float, hh: float, r: float) -> np.ndarray:
    qx = np.abs(lx - cx) - (hw - r)
    qy = np.abs(ly - cy) - (hh - r)
    outside = np.sqrt(np.maximum(qx, 0.0) ** 2 + np.maximum(qy, 0.0) ** 2)
    inside = np.minimum(np.maximum(qx, qy), 0.0)
    return outside + inside - r


def sd_circle(lx: np.ndarray, ly: np.ndarray, cx: float, cy: float, r: float) -> np.ndarray:
    dx = lx - cx
    dy = ly - cy
    return np.sqrt(dx * dx + dy * dy) - r


def sd_diamond(lx: np.ndarray, ly: np.ndarray, cx: float, cy: float, rx: float, ry: float) -> np.ndarray:
    dx = np.abs(lx - cx)
    dy = np.abs(ly - cy)
    norm = float(np.sqrt(rx * rx + ry * ry))
    return (ry * dx + rx * dy - rx * ry) / norm


def sd_segment(lx: np.ndarray, ly: np.ndarray, x0: float, y0: float, x1: float, y1: float) -> np.ndarray:
    pax = lx - x0
    pay = ly - y0
    bax = x1 - x0
    bay = y1 - y0
    denom = bax * bax + bay * bay
    if denom <= 1e-12:
        return np.sqrt(pax * pax + pay * pay)
    h = np.clip((pax * bax + pay * bay) / denom, 0.0, 1.0)
    dx = pax - bax * h
    dy = pay - bay * h
    return np.sqrt(dx * dx + dy * dy)


def draw_diamond_stud(dst: np.ndarray, lx: np.ndarray, ly: np.ndarray, cx: float, cy: float, s: int, tokens: TokenTable) -> np.ndarray:
    """Draw a 12x12 brass diamond stud with INK outline and bright #fff3c4 centre dot."""
    sd = sd_diamond(lx, ly, cx, cy, 5.2, 5.2)
    t_grad = np.clip((lx - (cx - 5.2) + ly - (cy - 5.2)) / 20.8, 0.0, 1.0)
    brass = sample_ramp(t_grad, [(0.0, tokens.rgb("BRASS_HI")), (0.5, tokens.rgb("BRASS")), (1.0, tokens.rgb("BRASS_LO"))])
    ink = np.asarray(tokens.rgb("INK"), dtype=np.float64)

    out = blend_rgb_mask(dst, ink, coverage(sd - 0.8, s))
    out = blend_rgb_mask(out, brass, coverage(sd, s))
    dot = coverage(sd_circle(lx, ly, cx, cy, 1.5), s)
    hi = np.asarray(parse_hex_color("#fff3c4")[:3], dtype=np.float64)
    return blend_rgb_mask(out, hi, dot)


def _radial_boss_brass(
    lx: np.ndarray,
    ly: np.ndarray,
    ocx: float,
    ocy: float,
    box_size: float,
    tokens: TokenTable,
) -> np.ndarray:
    """SVG objectBoundingBox radialGradient cx=0.35 cy=0.30 r=0.50."""
    hx = (lx - (ocx - 0.15 * box_size)) / (0.50 * box_size)
    hy = (ly - (ocy - 0.20 * box_size)) / (0.50 * box_size)
    rt = np.clip(np.sqrt(hx * hx + hy * hy), 0.0, 1.0)
    return sample_ramp(
        rt,
        [
            (0.0, parse_hex_color("#fff3c4")[:3]),
            (0.5, tokens.rgb("BRASS")),
            (1.0, parse_hex_color("#6b4c14")[:3]),
        ],
    )


def draw_quatrefoil_boss(dst: np.ndarray, lx: np.ndarray, ly: np.ndarray, cx: float, cy: float, s: int, tokens: TokenTable) -> np.ndarray:
    """Draw a 34px quatrefoil brass corner boss with layered diamond square and lapis centre jewel (kit.css --boss)."""
    scale = 34.0 / 36.0
    lobe_off = 10.0 * scale
    lobe_r = 6.0 * scale
    diam_r = 11.0 * scale
    jewel_r = 3.2 * scale

    lobes: list[tuple[float, float]] = [
        (cx, cy - lobe_off),
        (cx, cy + lobe_off),
        (cx - lobe_off, cy),
        (cx + lobe_off, cy),
    ]
    sd_diam = sd_diamond(lx, ly, cx, cy, diam_r, diam_r)
    sd_lobes = np.minimum(
        np.minimum(sd_circle(lx, ly, lobes[0][0], lobes[0][1], lobe_r), sd_circle(lx, ly, lobes[1][0], lobes[1][1], lobe_r)),
        np.minimum(sd_circle(lx, ly, lobes[2][0], lobes[2][1], lobe_r), sd_circle(lx, ly, lobes[3][0], lobes[3][1], lobe_r)),
    )
    sd_body = np.minimum(sd_lobes, sd_diam)

    # Drop shadow beneath whole ornament
    sd_shadow = np.minimum(
        np.minimum(sd_circle(lx, ly, lobes[0][0], lobes[0][1] + 2.0, lobe_r), sd_circle(lx, ly, lobes[1][0], lobes[1][1] + 2.0, lobe_r)),
        np.minimum(sd_circle(lx, ly, lobes[2][0], lobes[2][1] + 2.0, lobe_r), sd_circle(lx, ly, lobes[3][0], lobes[3][1] + 2.0, lobe_r)),
    )
    sd_shadow = np.minimum(sd_shadow, sd_diamond(lx, ly, cx, cy + 2.0, diam_r, diam_r))
    out = blend_rgb_mask(dst, np.array([0.0, 0.0, 0.0]), coverage(sd_shadow - 1.0, s), alpha=0.45)

    ink = np.asarray(tokens.rgb("INK"), dtype=np.float64)
    _ = sd_body

    # 1) Four circular lobes stroked with #0b0806 and shaded individually like SVG objectBoundingBox
    for lx_c, ly_c in lobes:
        sd_c = sd_circle(lx, ly, lx_c, ly_c, lobe_r)
        out = blend_rgb_mask(out, ink, coverage(sd_c - 0.95, s))
        c_brass = _radial_boss_brass(lx, ly, lx_c, ly_c, 2.0 * lobe_r, tokens)
        out = blend_rgb_mask(out, c_brass, coverage(sd_c, s))

    # 2) Internal rotated square (diamond) layered on top with its own #0b0806 stroke & brass radial fill
    out = blend_rgb_mask(out, ink, coverage(sd_diam - 0.95, s))
    d_brass = _radial_boss_brass(lx, ly, cx, cy, 2.0 * diam_r, tokens)
    out = blend_rgb_mask(out, d_brass, coverage(sd_diam, s))

    # 3) Lapis jewel in centre
    sd_jewel = sd_circle(lx, ly, cx, cy, jewel_r)
    out = blend_rgb_mask(out, ink, coverage(sd_jewel - 0.9, s))
    lapis = np.asarray(tokens.rgb("LAPIS"), dtype=np.float64)
    lapis_hi = np.asarray(parse_hex_color("#3d6cba")[:3], dtype=np.float64)
    j_t = np.clip(np.sqrt(((lx - (cx - 1.0)) / jewel_r) ** 2 + ((ly - (cy - 1.0)) / jewel_r) ** 2) * 0.6, 0.0, 1.0)
    jewel_col = lapis_hi * (1.0 - j_t[..., None]) + lapis * j_t[..., None]
    out = blend_rgb_mask(out, jewel_col, coverage(sd_jewel, s))
    return out


def render_bevel_button(
    w: int,
    h: int,
    s: int,
    sdf: np.ndarray,
    lx: np.ndarray,
    ly: np.ndarray,
    variant: str,
    state: str,
    tokens: TokenTable,
) -> np.ndarray:
    """Render a chamfered or pointed bevelled button (secondary/primary/danger/toggle x normal/hot/pressed/off)."""
    out = np.zeros((h * s, w * s, 4), dtype=np.float64)
    y_norm = np.clip(ly / float(h), 0.0, 1.0)

    # Outer 1px dark rim? Wait: in kit.css the outer 2px edge IS the gilt/bronze/pewter edge, clipped cleanly
    outer_cov = coverage(sdf, s)
    inner_sdf = sdf + 2.0  # inset 2 px
    inner_cov = coverage(inner_sdf, s)

    # 1) Edge ramp
    if state == "off":
        edge_rgb = sample_ramp(y_norm, [(0.0, parse_hex_color("#4b4033")[:3]), (1.0, parse_hex_color("#2e261d")[:3])])
    elif variant == "primary":
        edge_rgb = sample_ramp(y_norm, [(0.0, parse_hex_color("#6b4a10")[:3]), (1.0, parse_hex_color("#2c1c04")[:3])])
    elif variant == "toggle" and state == "on":
        edge_rgb = sample_ramp(y_norm, [(0.0, parse_hex_color("#fbe9a8")[:3]), (0.62, tokens.rgb("PRIMARY")), (1.0, parse_hex_color("#b98a2c")[:3])])
    else:
        edge_rgb = sample_ramp(y_norm, gilt_stops(tokens))

    out = blend_rgb_mask(out, edge_rgb, outer_cov)

    # 2) Face fill inside 2px edge
    if state == "off":
        face_rgb = np.broadcast_to(np.asarray(tokens.rgb("BUTTON_OFF"), dtype=np.float64), (*lx.shape, 3)).copy()
    elif variant == "primary":
        face_rgb = brushed_plate_rgb(lx, ly, y_norm, tokens, seed=3)
        if state == "pressed":
            face_rgb = brushed_plate_rgb(lx, ly, 1.0 - y_norm, tokens, seed=3) * 0.88
    elif variant == "danger":
        if state == "pressed":
            face_rgb = sample_ramp(y_norm, [(0.0, parse_hex_color("#5c150c")[:3]), (0.5, tokens.rgb("DANGER")), (1.0, tokens.rgb("DANGER_HOT"))])
        else:
            face_rgb = sample_ramp(y_norm, [(0.0, tokens.rgb("DANGER_HOT")), (0.5, tokens.rgb("DANGER")), (1.0, parse_hex_color("#5c150c")[:3])])
    elif variant == "toggle":
        if state == "on":
            face_rgb = sample_ramp(y_norm, [(0.0, parse_hex_color("#1b140f")[:3]), (1.0, parse_hex_color("#2b2017")[:3])])
        elif state == "pressed":
            face_rgb = sample_ramp(y_norm, [(0.0, tokens.rgb("TOGGLE")), (1.0, tokens.rgb("TOGGLE_HOT"))])
        else:
            face_rgb = sample_ramp(y_norm, [(0.0, tokens.rgb("TOGGLE_HOT")), (1.0, tokens.rgb("TOGGLE"))])
    else:  # secondary
        if state == "pressed":
            face_rgb = sample_ramp(y_norm, [(0.0, parse_hex_color("#2a190c")[:3]), (1.0, tokens.rgb("BUTTON"))])
        else:
            face_rgb = sample_ramp(
                y_norm,
                [(0.0, tokens.rgb("BUTTON_HOT")), (0.48, tokens.rgb("BUTTON")), (1.0, parse_hex_color("#34200f")[:3])],
            )

    if state == "hot":
        face_rgb = np.clip(face_rgb * 1.20, 0.0, 1.0)

    out = blend_rgb_mask(out, face_rgb, inner_cov)

    # 3) Inner bevel highlights / shadows inside inner_sdf <= 0
    if state == "off":
        # Flat off-face with 1px dark inner border
        rim_mask = inner_cov * coverage(-inner_sdf - 1.0, s)
        out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), rim_mask, alpha=0.50)
    elif state == "pressed":
        # 7px top shadow + 1px dark inner border
        top_sh = inner_cov * np.clip(1.0 - (ly - 2.0) / 7.0, 0.0, 1.0)
        out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), top_sh, alpha=0.65)
        rim_mask = inner_cov * coverage(-inner_sdf - 1.0, s)
        out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), rim_mask, alpha=0.45)
    else:
        # 1px inner dark hairline
        rim_mask = inner_cov * coverage(-inner_sdf - 1.0, s)
        out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), rim_mask, alpha=0.50)

        # 1px lit top line (at y ~ 2..3 inside edge)
        top_line = inner_cov * np.clip(1.0 - np.abs(ly - 2.5), 0.0, 1.0)
        lit_col = np.array([1.0, 0.92, 0.745], dtype=np.float64)
        lit_alpha = 0.50 if state == "hot" else 0.38
        out = blend_rgb_mask(out, lit_col, top_line, alpha=lit_alpha)

        # 3px dark bottom lip
        bot_lip = inner_cov * np.clip((ly - (float(h) - 5.5)) / 1.0, 0.0, 1.0) * np.clip((float(h) - 2.0 - ly), 0.0, 1.0)
        out = blend_rgb_mask(out, np.array([0.0, 0.0, 0.0]), bot_lip, alpha=0.42)

        # Hot: 14px inner GLOW
        if state == "hot":
            glow_rgb = tokens.rgb("GLOW")
            glow_a = tokens.rgba("GLOW")[3]
            glow_band = inner_cov * np.clip(1.0 + inner_sdf / 14.0, 0.0, 1.0)
            out = blend_rgb_mask(out, glow_rgb, glow_band, alpha=glow_a * 0.85)

    return out


# Keep fbm_2d / walnut_rgb / conic_brass available cleanly
_ = (fbm_2d, walnut_rgb, conic_brass)
