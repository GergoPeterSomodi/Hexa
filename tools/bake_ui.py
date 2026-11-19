"""Bake Studiolo UI textures and ui_kit.json (spec: docs/architecture/ui-style-and-feedback-spec.md 4.4-4.6).

Usage:
    python tools/bake_ui.py [--out godot/assets/ui] [--only panel_*] [--scale 1,2] [--jobs N] [--sheet out.png]
    python tools/bake_ui.py --check
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import multiprocessing
import os
import sys
import time
from pathlib import Path

import numpy as np

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.ui_bake.checks import BakeCheckError, run_all_checks
from tools.ui_bake.pieces_art import art_pieces
from tools.ui_bake.pieces_controls import control_pieces
from tools.ui_bake.pieces_frames import PieceSpec, frame_pieces
from tools.ui_bake.pieces_hud import hud_pieces
from tools.ui_bake.pieces_m2 import m2_pieces
from tools.ui_bake.png import load_png_rgba, rgba_sha256, save_png
from tools.ui_bake.tokens import TokenTable, load_tokens

SCHEMA = "hexa-godot/ui-kit/1"
TOKENS_PATH = REPO_ROOT / "godot" / "shell" / "ui" / "tokens.gd"
DEFAULT_OUT = REPO_ROOT / "godot" / "assets" / "ui"
TOLERANT_MAX_MAD = 2.5


def all_specs() -> list[PieceSpec]:
    return frame_pieces() + control_pieces() + art_pieces() + m2_pieces() + hud_pieces()


def _spec_map() -> dict[str, PieceSpec]:
    return {sp.name: sp for sp in all_specs()}


def _render_worker(task: tuple[str, int, str]) -> tuple[str, int, bytes, tuple[int, int, int]]:
    name, scale, tokens_path = task
    tokens = load_tokens(Path(tokens_path))
    spec = _spec_map()[name]
    arr = spec.render(scale, tokens)
    return name, scale, arr.tobytes(), arr.shape


def render_pieces(
    specs: list[PieceSpec],
    scales: tuple[int, ...],
    tokens: TokenTable,
    tokens_path: Path,
    jobs: int = 1,
) -> dict[tuple[str, int], np.ndarray]:
    tasks: list[tuple[str, int, str]] = []
    for sp in specs:
        for s in sp.scales:
            if s in scales:
                tasks.append((sp.name, s, str(tokens_path)))

    out: dict[tuple[str, int], np.ndarray] = {}
    if jobs <= 1 or len(tasks) <= 1:
        for name, scale, tp in tasks:
            sp = _spec_map()[name]
            out[(name, scale)] = sp.render(scale, tokens)
        return out

    with multiprocessing.Pool(processes=jobs) as pool:
        for name, scale, raw, shape in pool.map(_render_worker, tasks):
            out[(name, scale)] = np.frombuffer(raw, dtype=np.uint8).reshape(shape).copy()
    return out


def piece_out_path(out_dir: Path, spec: PieceSpec, scale: int) -> Path:
    if spec.out_subdir == "menu":
        return out_dir / "menu" / f"{spec.name}.png"
    return out_dir / "kit" / f"{scale}x" / f"{spec.name}.png"


def build_kit_index(
    specs: list[PieceSpec],
    rendered: dict[tuple[str, int], np.ndarray],
    tokens: TokenTable,
) -> dict:
    pieces_doc: dict[str, dict] = {}
    kit_1x_bytes = 0
    kit_2x_bytes = 0
    menu_bytes = 0

    for sp in specs:
        shas: dict[str, str] = {}
        for s in sp.scales:
            arr = rendered.get((sp.name, s))
            if arr is not None:
                shas[f"{s}x"] = rgba_sha256(arr)
                if sp.out_subdir == "kit":
                    if s == 1:
                        kit_1x_bytes += int(arr.nbytes)
                    elif s == 2:
                        kit_2x_bytes += int(arr.nbytes)
                else:
                    menu_bytes += int(arr.nbytes)

        entry: dict = {
            "size": list(sp.size),
            "margin": list(sp.margin),
            "content": list(sp.content),
            "expand": list(sp.expand),
            "axis": sp.axis,
            "fixed_height": sp.fixed_height,
            "min_width": sp.min_width,
            "slice": sp.slice_num,
            "scales": list(sp.scales),
            "subdir": sp.out_subdir,
            "sha": shas,
            "check": sp.check,
        }
        if sp.name == "icons_base":
            entry["cell"] = [16, 16]
            entry["icons"] = [
                "arrow_up",
                "arrow_down",
                "arrow_left",
                "arrow_right",
                "tick",
                "cross",
                "lock",
                "dash",
                "close",
                "menu",
                "help",
                "zoom_in",
                "zoom_out",
                "zoom_fit",
                "study",
                "info",
            ]
        pieces_doc[sp.name] = entry

    return {
        "schema": SCHEMA,
        "tokens_sha": tokens.tokens_sha,
        "bytes_rgba": {
            "kit_1x": kit_1x_bytes,
            "kit_2x": kit_2x_bytes,
            "menu": menu_bytes,
        },
        "pieces": pieces_doc,
    }


def write_contact_sheet(
    sheet_path: Path,
    specs: list[PieceSpec],
    rendered: dict[tuple[str, int], np.ndarray],
) -> None:
    """Compose a labelled visual contact sheet of all 1x pieces."""
    tiles: list[tuple[str, np.ndarray]] = []
    for sp in specs:
        arr = rendered.get((sp.name, 1))
        if arr is None:
            continue
        # Downscale huge menu_bg for the sheet preview so sheet remains manageable
        if sp.name == "menu_bg":
            arr = arr[::4, ::4, :]
        elif sp.name == "wordmark":
            arr = arr[::2, ::2, :]
        tiles.append((sp.name, arr))

    pad = 12
    cols = 4
    col_w = max(a.shape[1] for _, a in tiles) + pad * 2
    rows = (len(tiles) + cols - 1) // cols
    row_hs: list[int] = []
    for r in range(rows):
        chunk = tiles[r * cols : (r + 1) * cols]
        row_hs.append(max(a.shape[0] for _, a in chunk) + pad * 2)

    canvas = np.zeros((sum(row_hs) + pad, cols * col_w + pad, 4), dtype=np.uint8)
    canvas[..., 0] = 20
    canvas[..., 1] = 16
    canvas[..., 2] = 12
    canvas[..., 3] = 255

    y_cur = pad
    for r in range(rows):
        rh = row_hs[r]
        for c in range(cols):
            idx = r * cols + c
            if idx >= len(tiles):
                break
            _, arr = tiles[idx]
            h, w, _ = arr.shape
            x0 = pad + c * col_w + (col_w - w) // 2
            y0 = y_cur + (rh - h) // 2
            dst = canvas[y0 : y0 + h, x0 : x0 + w]
            sa = arr[..., 3:4].astype(np.float64) / 255.0
            rgb = arr[..., :3].astype(np.float64) * sa + dst[..., :3].astype(np.float64) * (1.0 - sa)
            dst[..., :3] = np.floor(rgb + 0.5).astype(np.uint8)
        y_cur += rh

    save_png(sheet_path, canvas)


def verify_committed(
    out_dir: Path,
    tokens: TokenTable,
    specs: list[PieceSpec],
    rendered: dict[tuple[str, int], np.ndarray],
) -> None:
    kit_json_path = out_dir / "kit" / "ui_kit.json"
    if not kit_json_path.is_file():
        raise BakeCheckError(f"Missing {kit_json_path}")
    committed = json.loads(kit_json_path.read_text(encoding="utf-8"))
    if committed.get("schema") != SCHEMA:
        raise BakeCheckError(f"Schema mismatch: {committed.get('schema')} != {SCHEMA}")
    if committed.get("tokens_sha") != tokens.tokens_sha:
        raise BakeCheckError(
            f"tokens_sha mismatch: ui_kit.json has {committed.get('tokens_sha')}, tokens.gd has {tokens.tokens_sha}"
        )

    committed_pieces = committed.get("pieces", {})
    for sp in specs:
        if sp.name not in committed_pieces:
            raise BakeCheckError(f"Missing piece {sp.name!r} in ui_kit.json")
        meta = committed_pieces[sp.name]
        for s in sp.scales:
            arr = rendered[(sp.name, s)]
            png_path = piece_out_path(out_dir, sp, s)
            if not png_path.is_file():
                raise BakeCheckError(f"Missing committed PNG: {png_path}")
            disk_arr = load_png_rgba(png_path)
            if disk_arr.shape != arr.shape:
                raise BakeCheckError(f"{png_path} shape {disk_arr.shape} != {arr.shape}")

            expected_sha = meta.get("sha", {}).get(f"{s}x")
            disk_sha = rgba_sha256(disk_arr)
            if disk_sha != expected_sha:
                raise BakeCheckError(f"{png_path} RGBA SHA mismatch vs ui_kit.json ({disk_sha} != {expected_sha})")

            built_sha = rgba_sha256(arr)
            if built_sha != disk_sha:
                if sp.check == "tolerant":
                    mad = float(np.mean(np.abs(arr.astype(np.float64) - disk_arr.astype(np.float64))))
                    if mad > TOLERANT_MAX_MAD:
                        raise BakeCheckError(f"{png_path} tolerant diff MAD={mad:.2f} > {TOLERANT_MAX_MAD}")
                else:
                    raise BakeCheckError(f"{png_path} RGBA SHA mismatch vs fresh bake ({disk_sha} != {built_sha})")


def _filter_specs(specs: list[PieceSpec], only_arg: str) -> list[PieceSpec]:
    if not only_arg:
        return specs
    patterns = [p.strip() for p in only_arg.split(",") if p.strip()]
    return [sp for sp in specs if any(fnmatch.fnmatch(sp.name, pat) for pat in patterns)]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Bake Studiolo UI textures and ui_kit.json")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="Output directory (default: godot/assets/ui)")
    parser.add_argument("--tokens", type=Path, default=TOKENS_PATH, help="Path to tokens.gd")
    parser.add_argument("--only", type=str, default="", help="Comma-separated glob filter of piece names")
    parser.add_argument("--scale", type=str, default="1,2", help="Scales to bake (1, 2, or 1,2)")
    parser.add_argument("--jobs", type=int, default=1, help="Worker processes")
    parser.add_argument("--sheet", type=Path, default=None, help="Optional contact sheet PNG path")
    parser.add_argument("--check", action="store_true", help="Rebuild in memory and verify against committed kit")
    args = parser.parse_args(argv)

    t0 = time.monotonic()
    scales = tuple(sorted({int(x.strip()) for x in args.scale.split(",") if x.strip()}))
    tokens = load_tokens(args.tokens)
    specs = _filter_specs(all_specs(), args.only)
    if not specs:
        print("bake_ui: no pieces matched --only", file=sys.stderr)
        return 2

    rendered = render_pieces(specs, scales, tokens, args.tokens, jobs=max(1, args.jobs))

    try:
        run_all_checks(REPO_ROOT, tokens, specs, rendered)
        if args.check:
            verify_committed(args.out, tokens, specs, rendered)
    except BakeCheckError as exc:
        print(f"bake_ui: FAIL: {exc}", file=sys.stderr)
        return 1

    if args.check:
        dt = time.monotonic() - t0
        print(f"bake_ui: CHECK PASS ({len(rendered)} images verified in {dt:.2f}s)")
        return 0

    for sp in specs:
        for s in sp.scales:
            if s not in scales:
                continue
            save_png(piece_out_path(args.out, sp, s), rendered[(sp.name, s)])

    if not args.only and scales == (1, 2):
        index = build_kit_index(specs, rendered, tokens)
        kit_json = args.out / "kit" / "ui_kit.json"
        kit_json.parent.mkdir(parents=True, exist_ok=True)
        kit_json.write_text(json.dumps(index, indent=2) + "\n", encoding="utf-8")
        mb_1x = index["bytes_rgba"]["kit_1x"] / (1024 * 1024)
        mb_2x = index["bytes_rgba"]["kit_2x"] / (1024 * 1024)
        mb_menu = index["bytes_rgba"]["menu"] / (1024 * 1024)
        print(f"bake_ui: wrote {len(rendered)} PNGs + ui_kit.json (1x={mb_1x:.2f} MB, 2x={mb_2x:.2f} MB, menu={mb_menu:.2f} MB) in {time.monotonic() - t0:.2f}s")
    else:
        print(f"bake_ui: wrote {len(rendered)} PNGs in {time.monotonic() - t0:.2f}s")

    if args.sheet is not None:
        write_contact_sheet(args.sheet, specs, rendered)
        print(f"bake_ui: wrote contact sheet {args.sheet}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
