"""Joins the Python and Godot frames of the 0.3.0 contact sheet side by side (Python left, Godot right), each scaled to
640 x 360 under a label strip, one PNG per region and view. The frames come from tools/contact_sheet_python.py and
godot/tools/contact_sheet.gd (both read tools/contact_sheet_regions.json).

Usage: python tools/contact_sheet_compose.py <folder with python/ and godot/> <output folder>
"""
import json
import os
import sys

os.environ["SDL_VIDEODRIVER"] = "dummy"
import pygame  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SCALE_W, SCALE_H = 640, 360
LABEL_H = 34
BG = (18, 20, 24)
INK = (235, 235, 235)


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    frames_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(HERE, "contact_sheet_regions.json"), encoding="utf-8") as fh:
        spec = json.load(fh)
    pygame.init()
    font = pygame.font.Font(None, 26)
    regions = list(spec["regions"]) + [spec["whole"]]
    written = []
    for region in regions:
        for view in spec["views"]:
            name = "%s-%s.png" % (region["id"], view)
            left = os.path.join(frames_dir, "python", name)
            right = os.path.join(frames_dir, "godot", name)
            if not (os.path.exists(left) and os.path.exists(right)):
                print("missing frame for", name)
                return 1
            title = region.get("title", "The whole map")
            sheet = compose(font, left, right, title, view)
            path = os.path.join(out_dir, name)
            pygame.image.save(sheet, path)
            written.append(path)
    for path in written:
        print(path, os.path.getsize(path))
    print("%d sheets" % len(written))
    return 0


def compose(font, left_path, right_path, title, view):
    left = pygame.image.load(left_path)
    right = pygame.image.load(right_path)
    width = SCALE_W * 2 + 10
    sheet = pygame.Surface((width, SCALE_H + LABEL_H), pygame.SRCALPHA)
    sheet.fill(BG)
    label_view = "terrain view" if view == "terrain" else "countries view"
    head = font.render("%s, %s" % (title, label_view), True, INK)
    sheet.blit(head, (8, 8))
    for i, (img, label) in enumerate(((left, "Python v0.2.2"), (right, "Godot 0.3.0"))):
        x = i * (SCALE_W + 10)
        scaled = pygame.transform.smoothscale(img, (SCALE_W, SCALE_H))
        sheet.blit(scaled, (x, LABEL_H))
        tag = font.render(label, True, INK)
        sheet.blit(tag, (x + SCALE_W - tag.get_width() - 8, 8))
    return sheet


if __name__ == "__main__":
    raise SystemExit(main())
