"""Unit tests for the Studiolo UI bake (spec 4.4-4.6, 4.10, 11)."""
from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path

import numpy as np

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
from tools.ui_bake.png import load_png_rgba, rgba_sha256, save_png
from tools.ui_bake.tokens import load_tokens

REPO_ROOT = Path(__file__).resolve().parents[1]
KIT_JSON = REPO_ROOT / "godot" / "assets" / "ui" / "kit" / "ui_kit.json"


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

        self.assertEqual(set(pieces.keys()), set(expected_slice1.keys()))
        for name, (sz, mar, con, exp, axis) in expected_slice1.items():
            entry = pieces[name]
            self.assertEqual(entry["size"], sz, name)
            self.assertEqual(entry["margin"], mar, name)
            self.assertEqual(entry["content"], con, name)
            self.assertEqual(entry["expand"], exp, name)
            self.assertEqual(entry["axis"], axis, name)

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


if __name__ == "__main__":
    unittest.main()
