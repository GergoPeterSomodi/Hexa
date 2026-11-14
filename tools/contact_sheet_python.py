"""Render the contact-sheet frames of the frozen Python Europe 1480 map (headless, no HUD).

Run from the repo root:  python tools/contact_sheet_python.py <absolute output folder>

Reads tools/contact_sheet_regions.json and writes, into the output folder:
- <id>-terrain.png and <id>-countries.png for each region (middle zoom, hex radius 13),
- whole-map-terrain.png and whole-map-countries.png (hex radius 3, centre [101, 75]).
Each frame is 1280 x 720 and shows the map alone. Every hex is treated as known (no fog).
Before drawing, the world's city hexes are printed next to the Godot map's hexes for comparison.
"""
import json
import os
import sys
import tempfile
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
os.environ["SDL_VIDEODRIVER"] = "dummy"
os.environ["HEXA_HOME"] = tempfile.mkdtemp(prefix="hexa-contact-sheet-")
sys.path.insert(0, str(ROOT))

import pygame  # noqa: E402

from hexa.campaign import mapview  # noqa: E402
from hexa.campaign.world import CampaignWorld  # noqa: E402

SPEC = ROOT / "tools" / "contact_sheet_regions.json"
TILES = ROOT / "hexagon-pack" / "PNG" / "Tiles"
SEED = 1480
MIDDLE_RADIUS = 13
WHOLE_RADIUS = 3
VIEWS = {"terrain": "terrain", "countries": "political"}      # spec view -> MapView.mode

# The Godot map file's city hexes (from godot/data), for the check before drawing.
GODOT_CITIES = {
    "Lisbon": (124, 61), "Paris": (140, 39), "London": (137, 32), "Cologne": (147, 33), "Milan": (150, 46),
    "Naples": (157, 57), "Prague": (157, 36), "Stockholm": (162, 10), "Vilnius": (172, 23), "Belgrade": (166, 48),
    "Ankara": (183, 58), "Tunis": (151, 65), "Toledo": (131, 59),
}


def zoom_index(radius):
    return mapview.ZOOMS.index(radius)


def city_hexes(world):
    """The Python world's city name -> hex (the name is the first field of each city record)."""
    return {value[0]: pos for pos, value in world.cities.items()}


def check_cities(world):
    found = city_hexes(world)
    print("City hex check (Python world vs Godot map file):")
    print(f"  {'city':<10} {'python':<12} {'godot':<12} result")
    for name, godot in GODOT_CITIES.items():
        py = found.get(name)
        if py is None:
            print(f"  {name:<10} {'(missing)':<12} {str(godot):<12} MISSING IN PYTHON")
            continue
        same = tuple(py) == tuple(godot)
        print(f"  {name:<10} {str(tuple(py)):<12} {str(godot):<12} {'same' if same else 'DIFFERENT'}")
    print()


def render(world, view_name, radius, centre, out_path):
    """One frame: the map centred on `centre` at hex radius `radius`, drawn with the game's own draw call."""
    view = mapview.MapView(world, str(TILES))
    view.mode = VIEWS[view_name]
    view.zoom = zoom_index(radius)
    view.known = lambda: set(world.terrain)           # everything visible: no fog, no unknown world
    ui = SimpleNamespace(selected=None, reach=None, province=None, hover=None, group=[], anim=None)
    frame = pygame.Rect(0, 0, 1280, 720)
    screen = pygame.Surface(frame.size)
    x, y = view.center(tuple(centre))
    camera = [x - frame.w / 2, y - frame.h / 2]      # the game's look_at, without its edge clamp
    view.draw(screen, frame, camera, ui)
    pygame.image.save(screen, str(out_path))
    return view, camera


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: python tools/contact_sheet_python.py <absolute output folder>")
    out = Path(sys.argv[1])
    if not out.is_absolute():
        sys.exit("the output folder must be an absolute path")
    out.mkdir(parents=True, exist_ok=True)
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    assert spec["frame"] == [1280, 720], spec["frame"]
    assert spec["middle_radius"] == MIDDLE_RADIUS and spec["whole_radius"] == WHOLE_RADIUS

    pygame.init()
    pygame.display.set_mode((5, 5))
    world = CampaignWorld(seed=SEED, map="europe")
    check_cities(world)

    jobs = []
    for region in spec["regions"]:
        for view_name in spec["views"]:
            jobs.append((f"{region['id']}-{view_name}.png", view_name, MIDDLE_RADIUS, region["centre"]))
    whole = spec["whole"]
    for view_name in spec["views"]:
        jobs.append((f"{whole['id']}-{view_name}.png", view_name, WHOLE_RADIUS, whole["centre"]))

    for name, view_name, radius, centre in jobs:
        view, camera = render(world, view_name, radius, centre, out / name)
        size = view.size()
        print(f"{name}  centre hex={tuple(centre)}  radius={radius}  mode={VIEWS[view_name]}  "
              f"map px={size[0]}x{size[1]}  camera=({camera[0]:.0f}, {camera[1]:.0f})")
    print(f"wrote {len(jobs)} files to {out}")


if __name__ == "__main__":
    main()
