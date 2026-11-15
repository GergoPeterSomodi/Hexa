"""Puts the M1 trial's pictures side by side: today's whole-map bake on the left, the tile stack on the right.

    python tools/worldmap/tileset_bake/side_by_side.py <folder with the shots> [out folder]

The shots are written by godot/tools/mapview/shot_trial.gd (today_whole.png, tiles_whole.png, today_close.png,
tiles_close.png). Writes side_by_side.png and close_crop.png (default: docs/design/map/m1_trial).
"""
import os
import sys

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
import pygame

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
GAP, BAR = 12, 34
INK, PAPER = (40, 36, 38), (244, 240, 230)


def pair(left, right, labels, font):
    w, h = left.get_size()
    out = pygame.Surface((2 * w + GAP, h + BAR))
    out.fill(PAPER)
    for i, (img, text) in enumerate(zip((left, right), labels)):
        x = i * (w + GAP)
        out.blit(img, (x, BAR))
        out.blit(font.render(text, True, INK), (x + 10, 7))
    return out


def main(argv):
    shots = argv[1]
    out_dir = argv[2] if len(argv) > 2 else os.path.join(REPO, "docs", "design", "map", "m1_trial")
    os.makedirs(out_dir, exist_ok=True)
    pygame.init()
    font = pygame.font.SysFont("arial", 18, bold=True)
    labels = ("Today: one baked picture per season (north_italy_map)", "Trial: hex tiles on TileMapLayers (the M1 standard)")
    for name, out in (("whole", "side_by_side.png"), ("close", "close_crop.png")):
        left = pygame.image.load(os.path.join(shots, "today_%s.png" % name))
        right = pygame.image.load(os.path.join(shots, "tiles_%s.png" % name))
        pygame.image.save(pair(left, right, labels, font), os.path.join(out_dir, out))
        print("wrote", os.path.join(out_dir, out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
