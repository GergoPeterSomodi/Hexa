"""Unit tests for the Studiolo UI bake (spec 4.4-4.6, 4.10, 11)."""
from __future__ import annotations

import json
import re
import shutil
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path

import os

try:
    import numpy as np
except ImportError:                     # the frozen game's unit suite runs without the bake tools: skip the module
    if os.environ.get("HEXA_REQUIRE_BAKE") == "1":   # the Godot workflow installs tools/requirements-bake.txt and sets it
        raise
    raise unittest.SkipTest("numpy is not installed (pip install -r tools/requirements-bake.txt; HEXA_REQUIRE_BAKE=1 makes this an error)") from None

from tools import bake_ui
from tools.ui_bake.checks import (
    KIT_1X_BUDGET_BYTES,
    KIT_2X_BUDGET_BYTES,
    BakeCheckError,
    check_field_amplitude,
    check_fonts,
    check_leather_surface,
    check_memory_budget,
    check_piece_geometry,
    check_token_contrasts,
    check_vellum_surface,
)
from tools.ui_bake.pieces_feedback import check_feedback_pieces
from tools.ui_bake.pieces_m2 import SHIELD_OUTLINE, sd_polygon
from tools.ui_bake.png import load_png_rgba, rgba_sha256, save_png
from tools.ui_bake.shapes import logical_grid
from tools.ui_bake.tokens import load_tokens

REPO_ROOT = Path(__file__).resolve().parents[1]
KIT_JSON = REPO_ROOT / "godot" / "assets" / "ui" / "kit" / "ui_kit.json"
COUNTRY_ARMS_GD = REPO_ROOT / "godot" / "shell" / "ui" / "country_arms.gd"

_SHIELD_DECL_RE = re.compile(r"const\s+SHIELD\s*:[^=\n]*=\s*\[(.*?)\]", re.DOTALL)
_VEC2_RE = re.compile(r"Vector2\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)")


def load_country_arms_shield(gd_path: Path = COUNTRY_ARMS_GD) -> tuple[tuple[float, float], ...]:
    """Parse CountryArms.SHIELD directly from godot/shell/ui/country_arms.gd."""
    text = gd_path.read_text(encoding="utf-8")
    m = _SHIELD_DECL_RE.search(text)
    if not m:
        raise AssertionError(f"Could not find const SHIELD declaration in {gd_path}")
    pts = tuple((float(vx), float(vy)) for vx, vy in _VEC2_RE.findall(m.group(1)))
    if len(pts) < 3:
        raise AssertionError(f"Parsed too few vertices ({len(pts)}) for SHIELD in {gd_path}")
    return pts


class TestBakeUI(unittest.TestCase):
    def test_committed_check_passes(self) -> None:
        self.assertEqual(bake_ui.main(["--check"]), 0)

    def test_determinism_across_runs_and_jobs(self) -> None:
        tokens = load_tokens(bake_ui.TOKENS_PATH)
        specs = bake_ui.all_specs()
        run_a = bake_ui.render_pieces(specs, (1, 2), tokens, bake_ui.TOKENS_PATH, jobs=1)
        run_b = bake_ui.render_pieces(specs, (1, 2), tokens, bake_ui.TOKENS_PATH, jobs=1)
        run_p = bake_ui.render_pieces(specs, (1, 2), tokens, bake_ui.TOKENS_PATH, jobs=2)

        for key in run_a:
            sha_a = rgba_sha256(run_a[key])
            self.assertEqual(sha_a, rgba_sha256(run_b[key]), f"repeat mismatch on {key}")
            self.assertEqual(sha_a, rgba_sha256(run_p[key]), f"--jobs 2 mismatch on {key}")

    def test_ui_kit_catalogue_and_budgets(self) -> None:
        doc = json.loads(KIT_JSON.read_text(encoding="utf-8"))
        self.assertEqual(doc["schema"], "hexa-godot/ui-kit/1")
        self.assertEqual(doc["tokens_sha"], load_tokens(bake_ui.TOKENS_PATH).tokens_sha)

        b1 = doc["bytes_rgba"]["kit_1x"]
        b2 = doc["bytes_rgba"]["kit_2x"]
        self.assertGreater(b1, 0)
        self.assertGreater(b2, 0)
        self.assertLess(b1, KIT_1X_BUDGET_BYTES)
        self.assertLess(b2, KIT_2X_BUDGET_BYTES)

        pieces = doc["pieces"]
        expected_slice1 = {
            "panel_frame": ([160, 160], [32, 32, 32, 32], [20, 20, 20, 20], [0, 0, 0, 10], "tile"),
            "panel_modal": ([192, 192], [48, 48, 48, 48], [28, 28, 28, 28], [24, 24, 24, 24], "tile"),
            "panel_vellum": ([160, 160], [32, 32, 32, 32], [24, 24, 24, 24], [24, 24, 24, 24], "tile"),
            "panel_card": ([48, 48], [12, 12, 12, 12], [10, 10, 10, 10], [0, 0, 0, 0], "stretch"),
            "panel_bar": ([128, 48], [8, 4, 8, 10], [8, 4, 8, 8], [0, 0, 0, 8], "tile_x"),
            "ribbon": ([128, 40], [36, 12, 36, 12], [36, 8, 36, 8], [0, 0, 0, 0], "stretch"),
            "toast": ([128, 40], [36, 20, 36, 20], [36, 8, 36, 8], [0, 0, 0, 0], "stretch"),
            "cartouche": ([96, 36], [24, 18, 24, 18], [24, 6, 24, 6], [0, 0, 0, 0], "stretch"),
            "slot": ([32, 24], [10, 10, 10, 10], [10, 2, 10, 2], [0, 0, 0, 0], "stretch"),
            "plate": ([32, 24], [10, 10, 10, 10], [10, 2, 10, 2], [0, 0, 0, 0], "stretch"),
            "nav_selected": ([32, 24], [10, 10, 10, 10], [10, 2, 10, 2], [0, 0, 0, 0], "stretch"),
            "nav_selected_ink": ([32, 24], [10, 10, 10, 10], [10, 2, 10, 2], [0, 0, 0, 0], "stretch"),
            "switch_off": ([48, 24], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "switch_on": ([48, 24], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "grabber": ([24, 24], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "grabber_hot": ([24, 24], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "keycap": ([32, 28], [10, 10, 10, 10], [8, 4, 8, 4], [0, 0, 0, 0], "stretch"),
            "keycap_wait": ([32, 28], [10, 10, 10, 10], [8, 4, 8, 4], [0, 0, 0, 0], "stretch"),
            "progress_fill": ([32, 12], [6, 4, 6, 4], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "seal": ([72, 72], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "stud": ([12, 12], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "glow_soft": ([64, 64], [24, 24, 24, 24], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "rule_diamond": ([256, 12], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "icons_base": ([128, 32], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "wordmark": ([1024, 256], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "rose": ([512, 512], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "menu_shade": ([480, 270], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "menu_bg": ([1920, 1080], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
        }
        for variant in ("secondary", "primary", "danger", "toggle"):
            for state in ("normal", "hot", "pressed", "off"):
                expected_slice1[f"button_{variant}_{state}"] = (
                    [64, 40], [14, 14, 14, 14], [14, 4, 14, 4], [0, 0, 0, 0], "stretch"
                )
        expected_slice1["toggle_on"] = ([64, 40], [14, 14, 14, 14], [14, 4, 14, 4], [0, 0, 0, 0], "stretch")
        expected_slice1["focus"] = ([64, 40], [14, 14, 14, 14], [14, 4, 14, 4], [0, 0, 0, 0], "stretch")
        for variant in ("secondary", "primary", "danger"):
            for state in ("normal", "hot", "pressed", "off"):
                expected_slice1[f"button_menu_{variant}_{state}"] = (
                    [96, 42], [28, 21, 28, 21], [34, 0, 34, 0], [0, 0, 0, 0], "stretch"
                )

        expected_slice2 = {
            "minimap_frame": ([256, 144], [56, 16, 56, 16], [8, 8, 8, 8], [0, 0, 0, 0], "stretch"),
            "shield_rim": ([48, 56], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "shield_rim_sm": ([20, 24], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "pennant_pole": ([24, 56], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "pennant_cloth": ([28, 20], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
        }

        expected_slice3 = {
            "medallion_64": ([64, 64], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "medallion_30": ([30, 30], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "dial_quarters": ([64, 64], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "dial_hand": ([64, 64], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "hourglass": ([24, 24], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "seal_good": ([72, 72], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "seal_plain": ([72, 72], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "seal_cracked": ([72, 72], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
        }
        for state in ("normal", "hot", "pressed", "off"):
            expected_slice3[f"endseason_plate_{state}"] = ([160, 44], [28, 22, 44, 22], [28, 4, 44, 4], [0, 0, 0, 0], "stretch")

        expected_slice4 = {
            "vellum_inset": ([96, 96], [16, 16, 16, 16], [10, 10, 10, 10], [0, 0, 0, 0], "tile"),
            "strip_cell": ([48, 48], [12, 12, 12, 12], [6, 6, 6, 6], [0, 0, 0, 0], "stretch"),
            "strip_cell_now": ([48, 48], [12, 12, 12, 12], [6, 6, 6, 6], [0, 0, 0, 0], "stretch"),
            "icons": ([256, 128], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
        }
        expected_slice5 = {
            "army_plate": ([56, 48], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "army_plate_ring": ([64, 56], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "army_badge": ([36, 18], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "figures": ([128, 32], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "icons_army": ([192, 48], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "path_stop": ([20, 20], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
        }
        expected_slice6 = {
            "badge_battle": ([40, 40], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "badge_siege": ([40, 40], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "icons_war": ([192, 72], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
            "die_face": ([28, 28], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "stretch"),
        }
        expected_all = {**expected_slice1, **expected_slice2, **expected_slice3, **expected_slice4, **expected_slice5, **expected_slice6}
        self.assertEqual(set(pieces.keys()), set(expected_all.keys()))
        for name, (sz, mar, con, exp, axis) in expected_all.items():
            entry = pieces[name]
            self.assertEqual(entry["size"], sz, name)
            self.assertEqual(entry["margin"], mar, name)
            self.assertEqual(entry["content"], con, name)
            self.assertEqual(entry["expand"], exp, name)
            self.assertEqual(entry["axis"], axis, name)
            expected_slice = 2 if name in expected_slice2 else (3 if name in expected_slice3 else (4 if name in expected_slice4 else (5 if name in expected_slice5 else (6 if name in expected_slice6 else 1))))
            self.assertEqual(entry["slice"], expected_slice, name)

    def test_slice2_pieces_geometry_and_apertures(self) -> None:
        kit_dir = REPO_ROOT / "godot" / "assets" / "ui" / "kit"
        expected_dims = {
            "minimap_frame": (256, 144),
            "shield_rim": (48, 56),
            "shield_rim_sm": (20, 24),
            "pennant_pole": (24, 56),
            "pennant_cloth": (28, 20),
        }

        for name, (w, h) in expected_dims.items():
            for s in (1, 2):
                png_path = kit_dir / f"{s}x" / f"{name}.png"
                self.assertTrue(png_path.is_file(), f"missing {png_path}")
                arr = load_png_rgba(png_path)
                self.assertEqual(arr.shape, (h * s, w * s, 4), f"{name}@{s}x shape")
                self.assertTrue(np.any(arr[..., 3] == 255), f"{name}@{s}x has opaque pixels")
                self.assertTrue(np.any(arr[..., 3] == 0), f"{name}@{s}x has transparent pixels")

        # Minimap frame: transparent interior aperture, transparent outer corners, opaque rim edges.
        for s in (1, 2):
            mf = load_png_rgba(kit_dir / f"{s}x" / "minimap_frame.png")
            self.assertTrue(np.all(mf[40 * s : 104 * s, 60 * s : 196 * s, 3] == 0), f"minimap_frame@{s}x aperture")
            self.assertEqual(int(mf[0, 0, 3]), 0, f"minimap_frame@{s}x top-left outside hex")
            self.assertEqual(int(mf[0, 256 * s - 1, 3]), 0, f"minimap_frame@{s}x top-right outside hex")
            self.assertEqual(int(mf[4 * s, 128 * s, 3]), 255, f"minimap_frame@{s}x top bar opaque")
            self.assertEqual(int(mf[140 * s, 128 * s, 3]), 255, f"minimap_frame@{s}x bottom bar opaque")
            self.assertEqual(int(mf[72 * s, 4 * s, 3]), 255, f"minimap_frame@{s}x left tip opaque")
            self.assertEqual(int(mf[72 * s, 252 * s, 3]), 255, f"minimap_frame@{s}x right tip opaque")

        # Shield rims: transparent interior & exterior aligned to CountryArms.SHIELD (parsed from country_arms.gd); 1 px shift fails.
        gd_shield = load_country_arms_shield()
        self.assertEqual(gd_shield, SHIELD_OUTLINE, "CountryArms.SHIELD must match pieces_m2.SHIELD_OUTLINE")
        for name, (w, h), rim_w in (("shield_rim", (48, 56), 3.0), ("shield_rim_sm", (20, 24), 2.0)):
            sx = float(w) / 48.0
            sy = float(h) / 56.0
            pts = [(x * sx, y * sy) for x, y in gd_shield]
            shifted_pts = [(x + 1.0, y) for x, y in pts]
            for s in (1, 2):
                arr = load_png_rgba(kit_dir / f"{s}x" / f"{name}.png")
                lx, ly = logical_grid(w, h, s)
                sd = sd_polygon(lx, ly, pts)
                alpha = arr[..., 3]
                self.assertTrue(np.all(alpha[sd > 0.75] == 0), f"{name}@{s}x exterior transparent")
                self.assertTrue(np.all(alpha[sd < -(rim_w + 0.75)] == 0), f"{name}@{s}x interior transparent")
                ridge = np.abs(sd + rim_w * 0.5) < 0.25
                self.assertTrue(np.all(alpha[ridge] >= 240), f"{name}@{s}x continuous opaque rim")

                # Planted alignment fault: 1 px shifted shield must violate transparency bounds.
                sd_bad = sd_polygon(lx, ly, shifted_pts)
                self.assertFalse(
                    bool(np.all(alpha[sd_bad > 0.75] == 0) and np.all(alpha[sd_bad < -(rim_w + 0.75)] == 0)),
                    f"{name}@{s}x 1px shift must fail alignment",
                )

        # Pennant cloth: neutral white/greyscale for runtime tinting, transparent swallow-tail V-notch.
        for s in (1, 2):
            pc = load_png_rgba(kit_dir / f"{s}x" / "pennant_cloth.png")
            opaque = pc[..., 3] > 200
            rgb = pc[opaque, :3].astype(np.int16)
            max_chroma = int(np.max(np.max(rgb, axis=1) - np.min(rgb, axis=1)))
            self.assertLessEqual(max_chroma, 2, f"pennant_cloth@{s}x must be neutral grayscale")
            self.assertGreaterEqual(int(pc[10 * s, 10 * s, 0]), 210, f"pennant_cloth@{s}x bright white interior")
            self.assertEqual(int(pc[10 * s, 25 * s, 3]), 0, f"pennant_cloth@{s}x swallow-tail notch transparent")

        # Pennant pole: centered finial & shaft opaque, outer side corners transparent.
        for s in (1, 2):
            pp = load_png_rgba(kit_dir / f"{s}x" / "pennant_pole.png")
            self.assertEqual(int(pp[7 * s, 12 * s, 3]), 255, f"pennant_pole@{s}x finial opaque")
            self.assertEqual(int(pp[30 * s, 12 * s, 3]), 255, f"pennant_pole@{s}x shaft opaque")
            self.assertEqual(int(pp[0, 0, 3]), 0, f"pennant_pole@{s}x outer corner transparent")

    def test_slice3_textures_shapes_and_alpha(self) -> None:
        kit_dir = REPO_ROOT / "godot" / "assets" / "ui" / "kit"
        for s in (1, 2):
            # Medallion rims: transparent face (the Dial draws it), opaque gilt band, transparent corner.
            for name, d, band_r in (("medallion_64", 64, 28), ("medallion_30", 30, 12)):
                arr = load_png_rgba(kit_dir / f"{s}x" / f"{name}.png")
                self.assertEqual(arr.shape, (d * s, d * s, 4), f"{name}@{s}x shape")
                c = d // 2
                self.assertEqual(int(arr[c * s, c * s, 3]), 0, f"{name}@{s}x face transparent")
                self.assertEqual(int(arr[c * s, (c + band_r) * s, 3]), 255, f"{name}@{s}x gilt band opaque")
                self.assertEqual(int(arr[0, 0, 3]), 0, f"{name}@{s}x corner transparent")

            # Dial face: opaque lapis with a hub at the centre; the hand points up from the centre.
            face = load_png_rgba(kit_dir / f"{s}x" / "dial_quarters.png")
            self.assertEqual(int(face[32 * s, 32 * s, 3]), 255, f"dial_quarters@{s}x hub opaque")
            self.assertEqual(int(face[12 * s, 32 * s, 3]), 255, f"dial_quarters@{s}x face opaque")
            self.assertEqual(int(face[0, 0, 3]), 0, f"dial_quarters@{s}x corner transparent")
            hand = load_png_rgba(kit_dir / f"{s}x" / "dial_hand.png")
            self.assertEqual(int(hand[20 * s, 32 * s, 3]), 255, f"dial_hand@{s}x needle opaque")
            self.assertEqual(int(hand[56 * s, 32 * s, 3]), 0, f"dial_hand@{s}x below the hub transparent")

            hg = load_png_rgba(kit_dir / f"{s}x" / "hourglass.png")
            self.assertEqual(hg.shape, (24 * s, 24 * s, 4), f"hourglass@{s}x shape")
            self.assertTrue(np.any(hg[..., 3] == 255), f"hourglass@{s}x has opaque pixels")
            self.assertEqual(int(hg[0, 0, 3]), 0, f"hourglass@{s}x corner transparent")

            # End season plate: the swallow-tail notch is cut at the centre line, the body is opaque.
            for state in ("normal", "hot", "pressed", "off"):
                pl = load_png_rgba(kit_dir / f"{s}x" / f"endseason_plate_{state}.png")
                self.assertEqual(pl.shape, (44 * s, 160 * s, 4), f"plate {state}@{s}x shape")
                self.assertEqual(int(pl[22 * s, 2 * s, 3]), 0, f"plate {state}@{s}x notch transparent")
                self.assertEqual(int(pl[22 * s, 80 * s, 3]), 255, f"plate {state}@{s}x body opaque")

            # Seals: good and plain are solid inside the wax; cracked has a gap cut across it.
            lx, ly = logical_grid(72, 72, s)
            disc = (lx - 36.0) ** 2 + (ly - 36.0) ** 2 < 25.0 ** 2
            for tone in ("good", "plain"):
                sl = load_png_rgba(kit_dir / f"{s}x" / f"seal_{tone}.png")
                self.assertEqual(sl.shape, (72 * s, 72 * s, 4), f"seal_{tone}@{s}x shape")
                self.assertTrue(np.all(sl[..., 3][disc] == 255), f"seal_{tone}@{s}x solid inside the wax")
            cr = load_png_rgba(kit_dir / f"{s}x" / "seal_cracked.png")
            # The gap shows the drop shadow beneath it (alpha about 0.45), so it is well below the solid wax.
            self.assertTrue(np.any(cr[..., 3][disc] < 200), f"seal_cracked@{s}x has a gap cut across the wax")

    def test_slice4_icons_and_feedback_frames(self) -> None:
        kit_dir = REPO_ROOT / "godot" / "assets" / "ui" / "kit"
        doc = json.loads(KIT_JSON.read_text(encoding="utf-8"))
        names = doc["pieces"]["icons"]["icons"]
        self.assertEqual(len(names), 48)
        self.assertEqual(len(set(names)), 48)
        self.assertEqual(names[:16], [f"good_{g}" for g in (
            "grain", "fish", "oil", "wine", "salt", "hemp", "silk", "dyes", "wool", "cattle", "horses", "timber",
            "stone", "iron", "copper", "silver")])
        self.assertEqual(doc["pieces"]["icons"]["cell"], [24, 24])
        sheets = {s: load_png_rgba(kit_dir / f"{s}x" / "icons.png") for s in (1, 2)}
        self.assertEqual(sheets[1].shape, (128, 256, 4))
        self.assertEqual(sheets[2].shape, (256, 512, 4))
        for i, name in enumerate(names):
            x, y = (i % 10) * 24, (i // 10) * 24
            for s in (1, 2):
                cell = sheets[s][y * s : (y + 24) * s, x * s : (x + 24) * s]
                alpha = cell[..., 3]
                self.assertGreater(int((alpha == 255).sum()), 24 * 24 * s * s // 6, f"{name}@{s}x has body")
            c1 = sheets[1][y : y + 24, x : x + 24, 3].astype(np.int16)
            c2 = sheets[2][y * 2 : (y + 24) * 2, x * 2 : (x + 24) * 2, 3].astype(np.int16)
            down = c2.reshape(24, 2, 24, 2).mean(axis=(1, 3))
            self.assertLess(float(np.abs(down - c1).mean()), 14.0, f"{name} 2x is the same drawing as 1x")
        # The two spare cells stay empty.
        self.assertTrue(np.all(sheets[1][96:120, 192:240, 3] == 0))
        self.assertTrue(np.all(sheets[1][:, 240:, 3] == 0))

        # Frames: vellum luminance and amplitude hold in the content rect; the field repeats every 64 px.
        tokens = load_tokens(bake_ui.TOKENS_PATH)
        specs = {sp.name: sp for sp in bake_ui.all_specs()}
        for name in ("vellum_inset", "strip_cell", "strip_cell_now"):
            for s in (1, 2):
                check_vellum_surface(load_png_rgba(kit_dir / f"{s}x" / f"{name}.png"), specs[name], s)
        inset = load_png_rgba(kit_dir / "1x" / "vellum_inset.png")
        self.assertTrue(np.array_equal(inset[10:86, 10:22, :3], inset[10:86, 74:86, :3]))
        self.assertEqual(int(inset[0, 0, 3]), 0, "rounded corner transparent")
        # Planted faults: a dark patch fails the vellum rule; a broken period fails the feedback check.
        bad = inset.copy()
        bad[40:60, 40:60, :3] = 150
        with self.assertRaises(BakeCheckError):
            check_vellum_surface(bad, specs["vellum_inset"], 1)
        rendered = {("vellum_inset", 1): bad}
        with self.assertRaises(BakeCheckError):
            check_feedback_pieces([specs["vellum_inset"]], rendered)
        shifted = inset.copy()
        shifted[20:40, 74:86, :3] = 235
        with self.assertRaises(BakeCheckError):
            check_feedback_pieces([specs["vellum_inset"]], {("vellum_inset", 1): shifted})
        self.assertIsNotNone(tokens)

    def test_faults_fire_every_check_assert(self) -> None:
        tokens = load_tokens(bake_ui.TOKENS_PATH)
        specs = {sp.name: sp for sp in bake_ui.all_specs()}

        # 1. Contrast violation
        bad_colors = dict(tokens.colors)
        bad_colors["FAINT"] = bad_colors["PANEL_BG"]
        bad_tokens = replace(tokens, colors=bad_colors)
        with self.assertRaises(BakeCheckError):
            check_token_contrasts(bad_tokens)

        # 2. Vellum luminance violation (< 0.66)
        v_spec = specs["panel_vellum"]
        v_arr = v_spec.render(1, tokens)
        v_dark = v_arr.copy()
        v_dark[48:112, 48:112, :3] = 160  # luminance ~0.35 < 0.66
        with self.assertRaises(BakeCheckError):
            check_vellum_surface(v_dark, v_spec, 1)

        # 3. Leather FAINT contrast violation
        f_spec = specs["panel_frame"]
        f_arr = f_spec.render(1, tokens)
        f_bright = f_arr.copy()
        f_bright[20:130, 20:140, :3] = 90  # far too bright for FAINT >= 4.5:1
        with self.assertRaises(BakeCheckError):
            check_leather_surface(f_bright, f_spec, 1, tokens)

        # 4. Amplitude > 4% violation
        f_noisy = f_arr.copy()
        f_noisy[60:80, 60:80, :3] = 65
        with self.assertRaises(BakeCheckError):
            check_field_amplitude(f_noisy, f_spec, 1)

        # 5. Geometry violations (narrow centre, wrong 2x shape, tile seam)
        bad_spec = replace(f_spec, margin=(78, 32, 78, 32))
        with self.assertRaises(BakeCheckError):
            check_piece_geometry(bad_spec, f_arr, None)
        with self.assertRaises(BakeCheckError):
            check_piece_geometry(f_spec, f_arr, f_arr)  # 2x same shape as 1x
        f_seam = f_arr.copy()
        f_seam[32:128, 32, :3] = 10
        f_seam[32:128, 127, :3] = 200
        with self.assertRaises(BakeCheckError):
            check_piece_geometry(f_spec, f_seam, None)

        # 6. Memory budget violation
        with self.assertRaises(BakeCheckError):
            check_memory_budget(KIT_1X_BUDGET_BYTES, 1024)
        with self.assertRaises(BakeCheckError):
            check_memory_budget(1024, KIT_2X_BUDGET_BYTES)

        # 7. Font check violation on missing directory
        with tempfile.TemporaryDirectory() as td:
            with self.assertRaises(BakeCheckError):
                check_fonts(Path(td))

    def test_check_catches_token_or_png_edit(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            out_dir = tmp / "ui"
            shutil.copytree(REPO_ROOT / "godot" / "assets" / "ui", out_dir)
            tok_copy = tmp / "tokens.gd"
            tok_copy.write_text(bake_ui.TOKENS_PATH.read_text(encoding="utf-8"), encoding="utf-8")

            # Sanity: unmodified copies pass --check
            self.assertEqual(bake_ui.main(["--check", "--out", str(out_dir), "--tokens", str(tok_copy)]), 0)

            # Mutate a token in tokens.gd -> tokens_sha mismatch fails --check
            tok_text = tok_copy.read_text(encoding="utf-8").replace('Color("#221a14")', 'Color("#231b15")')
            tok_copy.write_text(tok_text, encoding="utf-8")
            self.assertNotEqual(bake_ui.main(["--check", "--out", str(out_dir), "--tokens", str(tok_copy)]), 0)

            # Restore tokens, mutate one pixel of a PNG -> SHA mismatch fails --check
            tok_copy.write_text(bake_ui.TOKENS_PATH.read_text(encoding="utf-8"), encoding="utf-8")
            png_path = out_dir / "kit" / "1x" / "panel_card.png"
            arr = load_png_rgba(png_path)
            arr[0, 0, 0] = (int(arr[0, 0, 0]) + 17) % 256
            save_png(png_path, arr)
            self.assertNotEqual(bake_ui.main(["--check", "--out", str(out_dir), "--tokens", str(tok_copy)]), 0)

    def test_slice5_army_pieces(self) -> None:
        from tools.ui_bake import pieces_m6

        kit_dir = REPO_ROOT / "godot" / "assets" / "ui" / "kit"
        doc = json.loads(KIT_JSON.read_text(encoding="utf-8"))
        self.assertEqual(doc["pieces"]["figures"]["icons"], ["fig_infantry", "fig_missile", "fig_cavalry", "fig_artillery"])
        self.assertEqual(doc["pieces"]["figures"]["cell"], [32, 32])
        names = doc["pieces"]["icons_army"]["icons"]
        self.assertEqual(len(names), 16)
        self.assertEqual(names[:3], ["march", "hold", "halted"])
        self.assertEqual(names[-1], "pass_mark")
        sizes = {"army_plate": (56, 48), "army_plate_ring": (64, 56), "army_badge": (36, 18), "figures": (128, 32),
                 "icons_army": (192, 48), "path_stop": (20, 20)}
        sheets = {s: {n: load_png_rgba(kit_dir / f"{s}x" / f"{n}.png") for n in sizes} for s in (1, 2)}
        for n, (w, h) in sizes.items():
            for s in (1, 2):
                self.assertEqual(sheets[s][n].shape, (h * s, w * s, 4), f"{n}@{s}x shape")
        plate = sheets[1]["army_plate"]
        self.assertEqual(int(plate[0, 0, 3]), 0)
        self.assertGreaterEqual(int(plate[16:32, 18:38, :3].min()), 200, "the plate face is near white, so a tint works")
        self.assertEqual(int(sheets[1]["army_plate_ring"][28, 32, 3]), 0, "the ring is open in the middle")
        tokens = load_tokens(bake_ui.TOKENS_PATH)
        mine = [sp for sp in bake_ui.all_specs() if sp.name in sizes]
        rendered = {(sp.name, s): sheets[s][sp.name] for sp in mine for s in (1, 2)}
        pieces_m6.check_m6_pieces(tokens, mine, rendered)
        # Planted faults: a grey plate and an empty figure cell both fail.
        grey = plate.copy()
        grey[16:32, 18:38, :3] = 120
        with self.assertRaises(BakeCheckError):
            pieces_m6.check_m6_pieces(tokens, mine, {**rendered, ("army_plate", 1): grey})
        blank = sheets[1]["figures"].copy()
        blank[:, 32:64] = 0
        with self.assertRaises(BakeCheckError):
            pieces_m6.check_m6_pieces(tokens, mine, {**rendered, ("figures", 1): blank})
        # Planted token faults: a missing token and a low-contrast pair both fail (here and in HIGH_CONTRAST).
        with tempfile.TemporaryDirectory() as tmp:
            src = bake_ui.TOKENS_PATH.read_text(encoding="utf-8")
            for label, text in (
                ("missing", src.replace('const MAP_PATH_INK := Color("#0b0806")\n', "")),
                ("low", src.replace("const MAP_PATH := Color(\"#f6e3a1\")", "const MAP_PATH := Color(\"#1b1410\")")),
                ("hc_low", src.replace('"MAP_PATH": Color("#f6e3a1")', '"MAP_PATH": Color("#101010")')),
                ("hc_missing", src.replace('\t"MAP_PATH_WARN": BAD,\n', "")),
            ):
                tp = Path(tmp) / f"tokens_{label}.gd"
                tp.write_text(text, encoding="utf-8")
                with self.assertRaises(BakeCheckError, msg=label):
                    pieces_m6.check_m6_pieces(load_tokens(tp), mine, rendered, tp)
        # The sheet for the art director: every scenario colour.
        self.assertEqual(len(pieces_m6.scenario_colours(REPO_ROOT)), 13)
        with tempfile.TemporaryDirectory() as tmp:
            sheet = Path(tmp) / "sheet.png"
            pieces_m6.write_token_sheet(sheet, tokens, REPO_ROOT, 1)
            self.assertGreater(load_png_rgba(sheet).shape[0], 13 * 48)

    def test_slice6_war_pieces(self) -> None:
        from tools.ui_bake import pieces_m7

        kit_dir = REPO_ROOT / "godot" / "assets" / "ui" / "kit"
        doc = json.loads(KIT_JSON.read_text(encoding="utf-8"))
        icons = doc["pieces"]["icons_war"]
        self.assertEqual(icons["icons"], list(pieces_m7.WAR_ICON_NAMES))
        self.assertEqual(len(set(icons["icons"])), 24)
        self.assertEqual(icons["cell"], [24, 24])
        sizes = {"badge_battle": (40, 40), "badge_siege": (40, 40), "icons_war": (192, 72), "die_face": (28, 28)}
        sheets = {s: {n: load_png_rgba(kit_dir / f"{s}x" / f"{n}.png") for n in sizes} for s in (1, 2)}
        for n, (w, h) in sizes.items():
            for s in (1, 2):
                self.assertEqual(sheets[s][n].shape, (h * s, w * s, 4), f"{n}@{s}x shape")
        tokens = load_tokens(bake_ui.TOKENS_PATH)
        mine = [sp for sp in bake_ui.all_specs() if sp.name in sizes]
        rendered = {(sp.name, s): sheets[s][sp.name] for sp in mine for s in (1, 2)}
        pieces_m7.check_m7_pieces(tokens, mine, rendered, bake_ui.TOKENS_PATH)
        # Planted token faults: a missing track, a dial the same colour as its track, a high-contrast dial that does not read.
        src = bake_ui.TOKENS_PATH.read_text(encoding="utf-8")
        with tempfile.TemporaryDirectory() as tmp:
            for label, text in (
                ("missing", src.replace('const WAR_DIAL_TRACK := Color("#3a2416")\n', "")),
                ("low", src.replace('const WAR_DIAL := Color("#f0a850")', 'const WAR_DIAL := Color("#3a2416")')),
                ("hc_low", src.replace('"WAR_DIAL": WARN,', '"WAR_DIAL": Color("#101010")')),
                ("hc_track_panel", src.replace('"WAR_DIAL_TRACK": Color("#5b5b5b")', '"WAR_DIAL_TRACK": Color("#000000")')),
            ):
                tp = Path(tmp) / f"tokens_{label}.gd"
                tp.write_text(text, encoding="utf-8")
                with self.assertRaises(BakeCheckError, msg=label):
                    pieces_m7.check_m7_pieces(load_tokens(tp), mine, rendered, tp)
        # Planted pixel faults: a dark die face (the pips would not read), an empty icon cell, a repeated icon.
        dark = rendered[("die_face", 1)].copy()
        dark[6:22, 6:22, :3] = 20
        with self.assertRaises(BakeCheckError):
            pieces_m7.check_m7_pieces(tokens, mine, {**rendered, ("die_face", 1): dark}, bake_ui.TOKENS_PATH)
        blank = rendered[("icons_war", 1)].copy()
        blank[0:24, 0:24] = 0
        with self.assertRaises(BakeCheckError):
            pieces_m7.check_m7_pieces(tokens, mine, {**rendered, ("icons_war", 1): blank}, bake_ui.TOKENS_PATH)
        twin = rendered[("icons_war", 1)].copy()
        twin[0:24, 24:48] = twin[0:24, 0:24]
        with self.assertRaises(BakeCheckError):
            pieces_m7.check_m7_pieces(tokens, mine, {**rendered, ("icons_war", 1): twin}, bake_ui.TOKENS_PATH)
        with tempfile.TemporaryDirectory() as tmp:
            sheet = Path(tmp) / "war.png"
            pieces_m7.write_war_sheet(sheet, tokens, 1)
            self.assertGreater(load_png_rgba(sheet).shape[0], 100)


if __name__ == "__main__":
    unittest.main()
