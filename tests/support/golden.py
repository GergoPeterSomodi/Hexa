"""Golden screenshots: compare a frame with its reviewed picture in tests/golden/linux/.

    class MyScreens(UITestCase):
        def setUp(self):
            harness.install().reset()                   # pygame up, so the environment can be read
            golden.require_environment(self)            # skip (or fail) unless this is the goldens' environment,
            super().setUp()                             # before the temporary HEXA_HOME a skip would leave behind
        def test_menu(self):
            ...                                         # build the window, draw it
            golden.check(self, "menu_colony", screen)   # max_pixels=0: no pixel may be off by THRESHOLD or more

check(test, name, surface, max_pixels=0) reads the frame's RGB pixels and compares them with <name>.png:
1. exact: the sha256 of the RGB bytes against that of the golden's decoded pixels (PNG bytes are never compared:
   another zlib or libpng encodes the same pixels differently);
2. otherwise with a tolerance: pygame.mask.from_threshold (in C, a few ms) counts the pixels where a channel is off
   by THRESHOLD (8) or more; the frame passes when at most max_pixels of them are;
3. otherwise the test fails and writes <name>.actual.png, <name>.golden.png and <name>.diff.png (the frame darkened,
   the differing pixels magenta) to $HEXA_TEST_ARTIFACTS (default test-artifacts/).

The environment. Text and sprite scaling come out a little differently with another FreeType, SDL or pygame build,
so MANIFEST.json beside the goldens records the environment they were made in (environment(): the OS, Python
major.minor, the pygame, SDL, SDL_ttf and FreeType versions, a hash of pygame's bundled font, the smoothscale
backend, the video driver and the desktop size the windows see). The CPU is left out: with the GENERIC smoothscale
backend linux/arm64 and linux/amd64 draw the same bytes, so goldens made in a linux/arm64 container on a Mac serve
the x86-64 CI runners. Where the running environment differs, require_environment() skips the test and names the
differences; under HEXA_GOLDEN_STRICT=1 it fails instead (for a CI job that must compare), and under
HEXA_GOLDEN_ANY_OS=1 it compares anyway with a loose budget (LOOSE_SHARE of the frame), e.g. for a look on macOS,
whose FreeType moves some glyphs by a pixel.

UPDATE_GOLDEN=1 makes the goldens: every frame whose pixels are not exactly its golden's (or that has none) is
written as the new golden, MANIFEST.json gets this environment, and the module's tearDownModule prints a summary
(also written to <artifacts>/golden-updates.txt). Linux is the reference, so it refuses to run anywhere else: on a
Mac, use the docker one-liner in README.md (Development, Golden screenshots).

pygame is imported only by the functions that need it (it is already loaded by the harness then), so importing this
module never loads it.
"""
import hashlib
import json
import os
import platform
import re
import sys

from tests.support import harness

GOLDEN_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "golden", "linux")
MANIFEST = "MANIFEST.json"
REFERENCE_SYSTEM = "Linux"
THRESHOLD = 8                 # a pixel differs when a channel is off by this much or more
LOOSE_SHARE = 0.005           # HEXA_GOLDEN_ANY_OS=1: this share of a frame's pixels may differ
UPDATE_VAR = "UPDATE_GOLDEN"
STRICT_VAR = "HEXA_GOLDEN_STRICT"
ANY_OS_VAR = "HEXA_GOLDEN_ANY_OS"
SUMMARY_FILE = "golden-updates.txt"
DOCKER_HINT = "see README.md, Development, Golden screenshots, for the docker one-liner"

_updates = []                 # (name, what happened) under UPDATE_GOLDEN=1, for summary()


def _flag(name):
    return os.environ.get(name) == "1"


def updating():
    return _flag(UPDATE_VAR)


def _version(numbers):
    return ".".join(str(n) for n in numbers)


def environment():
    """What the goldens depend on, as MANIFEST.json stores it. Needs pygame initialised (the harness does that)."""
    pygame = sys.modules["pygame"]
    try:
        import pygame.freetype
        freetype = _version(pygame.freetype.get_version(linked=True))
    except (ImportError, AttributeError, TypeError):
        freetype = None
    font = pygame.font.get_default_font()
    with open(os.path.join(os.path.dirname(pygame.__file__), font), "rb") as f:
        font_hash = hashlib.sha256(f.read()).hexdigest()
    sizes = pygame.display.get_desktop_sizes() if hasattr(pygame.display, "get_desktop_sizes") else []
    return {"system": platform.system(),
            "python": f"{sys.version_info.major}.{sys.version_info.minor}",
            "pygame": pygame.version.ver,
            "sdl": _version(pygame.get_sdl_version(linked=True)),
            "sdl_ttf": _version(pygame.font.get_sdl_ttf_version(linked=True)),
            "freetype": freetype,
            "font": font,
            "font_sha256": font_hash,
            "smoothscale": pygame.transform.get_smoothscale_backend(),
            "video_driver": pygame.display.get_driver(),
            "desktop": "x".join(str(n) for n in sizes[0]) if sizes else None}


def manifest_path():
    return os.path.join(GOLDEN_DIR, MANIFEST)


def read_manifest():
    """MANIFEST.json as a dict; None when it is missing or unreadable."""
    try:
        with open(manifest_path(), encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return None
    return data if isinstance(data, dict) else None


def write_manifest(env):
    os.makedirs(GOLDEN_DIR, exist_ok=True)
    with open(manifest_path(), "w", encoding="utf-8", newline="\n") as f:
        json.dump(env, f, indent=2, sort_keys=True)
        f.write("\n")


def differences(manifest, env):
    """The keys whose values differ, as "key: golden value -> value here" strings ([] when none do)."""
    if manifest is None:
        return [f"no readable {MANIFEST}"]
    return [f"{key}: {manifest.get(key)!r} -> {env.get(key)!r}"
            for key in sorted(set(manifest) | set(env)) if manifest.get(key) != env.get(key)]


def _only_on_reference(test):
    if platform.system() != REFERENCE_SYSTEM:
        test.fail(f"{UPDATE_VAR}=1: the goldens are made on {REFERENCE_SYSTEM} (CI's reference), "
                  f"not on {platform.system()}; {DOCKER_HINT}")


def _loose():
    """True when frames are compared despite a different environment (HEXA_GOLDEN_ANY_OS=1)."""
    return not updating() and _flag(ANY_OS_VAR) and bool(differences(read_manifest(), environment()))


def require_environment(test):
    """Call first thing in setUp, once the harness has set pygame up and before anything a skip would leave behind
    (tearDown doesn't run after a skip in setUp). Skips test when this environment is not the one the goldens were
    made in; fails it instead under HEXA_GOLDEN_STRICT=1. Under HEXA_GOLDEN_ANY_OS=1 the test goes on and check()
    uses a loose budget. Under UPDATE_GOLDEN=1 it fails anywhere but on Linux, and on Linux it writes this
    environment to MANIFEST.json unless that already says the same."""
    env = environment()
    if updating():
        _only_on_reference(test)
        if read_manifest() != env:
            write_manifest(env)
        return
    diff = differences(read_manifest(), env)
    if not diff:
        return
    reason = (f"the goldens in {os.path.relpath(GOLDEN_DIR)} were made in another environment ({'; '.join(diff)}) "
              f"and are compared only in their own ({ANY_OS_VAR}=1 compares anyway, loosely); {DOCKER_HINT}")
    if _flag(STRICT_VAR):
        test.fail(f"{reason}. {STRICT_VAR}=1 makes that a failure")
    if _flag(ANY_OS_VAR):
        return
    test.skipTest(reason)


def path(name):
    return os.path.join(GOLDEN_DIR, f"{name}.png")


def _rgb_surface(surface):
    """(a copy of surface as a 24-bit RGB surface, its RGB bytes)."""
    pygame = sys.modules["pygame"]
    data = pygame.image.tobytes(surface, "RGB")
    return pygame.image.frombytes(data, surface.get_size(), "RGB"), data


def _sha(data):
    return hashlib.sha256(data).hexdigest()


def _load(file):
    """The golden at file as (RGB surface, RGB bytes), or None when there is no such file."""
    if not os.path.exists(file):
        return None
    return _rgb_surface(sys.modules["pygame"].image.load(file))


def compare(actual, golden, threshold=THRESHOLD):
    """The mask of pixels where a channel of actual is off from golden by threshold or more (same size)."""
    pygame = sys.modules["pygame"]
    # from_threshold marks the pixels whose channels are all within the threshold (closer than it) of golden's
    mask = pygame.mask.from_threshold(actual, (0, 0, 0), (threshold, threshold, threshold, 255), othersurface=golden)
    mask.invert()
    return mask


def diff_image(actual, differ):
    """The frame darkened, with the differing pixels (the mask differ) in magenta."""
    pygame = sys.modules["pygame"]
    image = actual.copy()
    image.fill((80, 80, 80), special_flags=pygame.BLEND_RGB_MULT)
    differ.to_surface(image, setcolor=(255, 0, 255), unsetcolor=None)
    return image


def _artifact(name, kind, surface):
    pygame = sys.modules["pygame"]
    file = os.path.join(harness.artifacts_dir(), re.sub(r"[^\w.-]", "_", f"{name}.{kind}") + ".png")
    pygame.image.save(surface, file)
    return file


def _where(differ):
    rects = differ.get_bounding_rects()
    if not rects:
        return ""
    box = rects[0].unionall(rects[1:])
    regions = f"{len(rects)} region{'s' * (len(rects) != 1)}"
    return f" in {regions} within x {box.x}-{box.right - 1}, y {box.y}-{box.bottom - 1}"


def check(test, name, surface, max_pixels=0):
    """Compare surface (a frame, usually the window) with the golden <name>.png; see the module docstring."""
    pygame = sys.modules["pygame"]
    actual, data = _rgb_surface(surface)
    file = path(name)
    golden = _load(file)
    if golden is not None and golden[0].get_size() == actual.get_size() and _sha(golden[1]) == _sha(data):
        if updating():
            _updates.append((name, "unchanged"))
        return
    if updating():
        _only_on_reference(test)
        what = "new" if golden is None else "changed"
        if golden is not None and golden[0].get_size() == actual.get_size():
            what += f", {compare(actual, golden[0]).count()} pixels off by {THRESHOLD} or more"
        elif golden is not None:
            what += f", size {golden[0].get_size()} -> {actual.get_size()}"
        os.makedirs(GOLDEN_DIR, exist_ok=True)
        pygame.image.save(actual, file)
        _updates.append((name, what))
        print(f"\ngolden {name}: written ({what})", file=sys.stderr)
        return
    if golden is None:
        test.fail(f"golden {name}: there is no {os.path.relpath(file)}; make it with {UPDATE_VAR}=1 on Linux "
                  f"({DOCKER_HINT})")
    golden_surface = golden[0]
    if golden_surface.get_size() != actual.get_size():
        files = [_artifact(name, "actual", actual), _artifact(name, "golden", golden_surface)]
        test.fail(f"golden {name}: the frame is {actual.get_size()}, the golden {golden_surface.get_size()}. "
                  f"Frames: {', '.join(files)}")
    differ = compare(actual, golden_surface)
    count = differ.count()
    total = actual.get_width() * actual.get_height()
    budget = max(max_pixels, int(total * LOOSE_SHARE)) if _loose() else max_pixels
    if count <= budget:
        return
    files = [_artifact(name, "actual", actual), _artifact(name, "golden", golden_surface),
             _artifact(name, "diff", diff_image(actual, differ))]
    test.fail(f"golden {name}: {count} of {total} pixels ({100 * count / total:.2f} %) are off by {THRESHOLD} or more "
              f"in a channel{_where(differ)}; {budget} may be. Look at {', '.join(files)}. If the change is "
              f"intended, make new goldens with {UPDATE_VAR}=1 on Linux ({DOCKER_HINT}) and review them.")


def summary():
    """What UPDATE_GOLDEN=1 did in this process, one line a golden (empty when it didn't run). Also written to
    <artifacts>/golden-updates.txt, where the goldens workflow picks it up."""
    if not _updates:
        return ""
    changed = sum(1 for _, what in _updates if what != "unchanged")
    lines = [f"{UPDATE_VAR}=1: {changed} of {len(_updates)} goldens written in {os.path.relpath(GOLDEN_DIR)}"]
    lines += [f"  {name}: {what}" for name, what in _updates]
    text = "\n".join(lines) + "\n"
    with open(os.path.join(harness.artifacts_dir(), SUMMARY_FILE), "w", encoding="utf-8") as f:
        f.write(text)
    return text
