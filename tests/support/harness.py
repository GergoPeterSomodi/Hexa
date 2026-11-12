"""Drive the real pygame windows headless: fake time, pinned fonts and scripted input, through their own run().

    class MyTest(UITestCase):                           # pygame set up, self.driver reset, temp HEXA_HOME
        def test_it(self):
            import play                                 # pygame and window modules: inside the test
            app = play.App(42)
            self.driver.at(0, key("space"))             # handled by the loop's first iteration
            self.driver.at(3, lambda: click(button_rect(app, "Found")))   # callables run when frame 3 comes
            self.driver.run_for(600, until=lambda: app.world.turn == 2)   # then exactly one QUIT
            self.assertEqual(app.run(), "quit")         # the window's real, unmodified loop
            self.assertEqual(app.world.turn, 2)

install() changes these, once per process; uninstall() puts them all back and original(name) returns one:
- the environment, before pygame is imported and again before every pygame.init(): SDL_VIDEODRIVER and
  SDL_AUDIODRIVER default to "dummy" (set one by hand, e.g. SDL_VIDEODRIVER=x11, for a real window; the run is
  not slowed down), PYGAME_HIDE_SUPPORT_PROMPT=1 and TZ=UTC (the save slots show local times);
- pygame.time.Clock: tick() never sleeps; it moves the fake clock on by FRAME_MS and lets the driver post the
  events of the new frame. pygame.time.get_ticks reads that clock, which starts at START_MS, never at 0 (the
  game uses 0 for "not yet", e.g. the F9 quickload confirmation);
- pygame.font.SysFont: always pygame's bundled font (with bold/italic), so text looks the same on every machine;
- pygame.display.get_desktop_sizes: [DESKTOP]. The dummy driver says 1024x768, which shrinks the campaign window;
- pygame.transform.set_smoothscale_backend("GENERIC"): x86-64 would use SSE and scale sprites a little
  differently from arm64.

Frames are Clock.tick() calls since reset(). Events for frame n are posted when tick() reaches n, so the loop
handles them in its next iteration; frame 0, or any frame already reached, posts at once. Once the budget is
spent the driver posts one QUIT and nothing after it, so no event leaks into the next loop or test. A loop that
keeps going anyway raises RunawayLoop instead of hanging.

Event helpers return lists of pygame events: key, click, drag, wheel, hover. Rect helpers read the window's
own state, so tests survive layout changes: button_rect, end_turn_rect, pause_button_rect, menu_option_rect,
menu_start_rect, menu_continue_rect, hex_pixel for the screen position of a map hex, and minimap_pixel for a
hex's cell on the Colonisation minimap.

Held keys: posted key events don't change pygame.key.get_pressed(), which the held-key scrolling reads.
self.hold_keys() (UITestCase) patches it for one test with a HeldKeys, whose press() and release() the script
calls on the frames it wants:

    keys = self.hold_keys()
    self.driver.at(2, lambda: keys.press("right"))       # scroll() sees it from the next loop iteration ...
    self.driver.at(12, lambda: keys.release("right"))    # ... for 10 iterations

pygame is imported lazily, so importing this module (as the pygame-free unit suite does) never loads it.
"""
import os
import re
import sys
import time
from unittest import mock

from tests.support.home import TempHome
from tests.support.pg import REQUIRE_VAR, requires_pygame

FRAME_MS = 16                 # fake milliseconds per frame (about 60 fps)
START_MS = 1000               # pygame.time.get_ticks() right after reset()
DESKTOP = (1920, 1080)
SAFETY_FRAMES = 3000          # without run_for(), a loop that runs this long is a mistake: RunawayLoop
GRACE_FRAMES = 120            # frames a loop gets to stop after its QUIT
ARTIFACTS_VAR = "HEXA_TEST_ARTIFACTS"
ARTIFACTS_DEFAULT = "test-artifacts"
ENV_DEFAULTS = {"SDL_VIDEODRIVER": "dummy", "SDL_AUDIODRIVER": "dummy"}
ENV_FORCED = {"PYGAME_HIDE_SUPPORT_PROMPT": "1", "TZ": "UTC"}

_driver = None
_originals = {}


class RunawayLoop(RuntimeError):
    """A window loop kept running past its frame budget (or SAFETY_FRAMES without one)."""


# ----- installing the patches ----------------------------------------------------------------------------
def _import_pygame():
    try:
        import pygame
    except ImportError as error:
        raise ImportError(f"pygame can't be imported ({error}). Install it (pip install pygame==2.6.1) to run the "
                          f"UI tests, or leave {REQUIRE_VAR} unset so they are skipped.") from error
    return pygame


def install():
    """Set the environment, import and initialise pygame, install the patches and return the Driver.

    Idempotent: later calls just return the same Driver."""
    global _driver
    if _driver is not None:
        return _driver
    env = {name: os.environ.get(name) for name in (*ENV_DEFAULTS, *ENV_FORCED)}
    _set_env()
    try:
        pygame = _import_pygame()
    except ImportError:
        _restore_env(env)
        raise
    pygame.init()
    _originals.update(env=env, Clock=pygame.time.Clock, get_ticks=pygame.time.get_ticks,
                      SysFont=pygame.font.SysFont,
                      get_desktop_sizes=getattr(pygame.display, "get_desktop_sizes", None),
                      smoothscale_backend=pygame.transform.get_smoothscale_backend())
    pygame.time.Clock = FakeClock
    pygame.time.get_ticks = _get_ticks
    pygame.font.SysFont = pinned_sysfont
    pygame.display.get_desktop_sizes = _desktop_sizes
    pygame.transform.set_smoothscale_backend("GENERIC")
    _driver = Driver()
    return _driver


def uninstall():
    """Undo install(): the real Clock, get_ticks, SysFont, desktop sizes, smoothscale backend and environment.

    pygame stays imported and initialised, and any window stays open. A later install() patches again."""
    global _driver
    if _driver is None:
        return
    pygame = sys.modules["pygame"]
    pygame.time.Clock = _originals["Clock"]
    pygame.time.get_ticks = _originals["get_ticks"]
    pygame.font.SysFont = _originals["SysFont"]
    if _originals["get_desktop_sizes"] is None:
        del pygame.display.get_desktop_sizes
    else:
        pygame.display.get_desktop_sizes = _originals["get_desktop_sizes"]
    pygame.transform.set_smoothscale_backend(_originals["smoothscale_backend"])
    _restore_env(_originals["env"])
    _tzset()
    _originals.clear()
    _driver = None


def original(name):
    """What install() replaced: "Clock", "get_ticks", "SysFont", "get_desktop_sizes", "smoothscale_backend"
    (the backend's name) or "env" (the environment variables it changed, None where they were unset)."""
    if name not in _originals:
        raise KeyError(f"{name!r}: the harness is not installed, or this is not something it replaces")
    return _originals[name]


def _set_env():
    """The environment pygame must start in. Again before every pygame.init(): SDL reads it then, and a test
    that patched os.environ (mock.patch.dict) may have taken it away; without it SDL would open a real window."""
    for name, value in ENV_DEFAULTS.items():
        os.environ.setdefault(name, value)
    os.environ.update(ENV_FORCED)
    _tzset()


def _restore_env(env):
    for name, value in env.items():
        if value is None:
            os.environ.pop(name, None)
        else:
            os.environ[name] = value


def _tzset():
    if hasattr(time, "tzset"):          # not on Windows
        time.tzset()


def _get_ticks():
    return _driver.now


def _desktop_sizes():
    return [DESKTOP]


def pinned_sysfont(name, size, bold=False, italic=False, constructor=None):
    """Replaces pygame.font.SysFont: pygame's bundled font whatever the name, so text never depends on the OS."""
    font = sys.modules["pygame"].font.Font(None, size)
    font.set_bold(bool(bold))
    font.set_italic(bool(italic))
    return font


class FakeClock:
    """Replaces pygame.time.Clock. tick() never sleeps: it advances the Driver by one frame."""

    def __init__(self):
        pass

    def tick(self, framerate=0):
        return _driver.tick()

    tick_busy_loop = tick

    def get_time(self):
        return FRAME_MS

    get_rawtime = get_time

    def get_fps(self):
        return 1000 / FRAME_MS


# ----- the driver ------------------------------------------------------------------------------------------
class Driver:
    """The one per process: fake time, scripted events and the frame budget of the window loops.

    frame       Clock.tick() calls since reset()
    now         what pygame.time.get_ticks() returns
    stopped_by  None while no QUIT has been posted, else why it was: "until" or "budget"
    """

    def __init__(self):
        self.reset()

    def reset(self):
        """Forget the script and the budget, restart the clock, (re)initialise pygame and empty its event queue.

        UITestCase calls this before every test. pygame.init() again because play.main() ends with pygame.quit()."""
        self.frame = 0
        self.now = START_MS
        self.stopped_by = None
        self._script = {}
        self._stop_at = None
        self._until = None
        self._limit = SAFETY_FRAMES
        pygame = sys.modules["pygame"]
        _set_env()
        pygame.init()
        pygame.event.clear()

    def at(self, frame, *events):
        """Post events when the loop reaches frame (counted from reset()); a frame already reached posts now.

        Each item is a pygame event, a list of them (what key(), click()... return), or a callable returning
        either. Callables run when their frame comes, so they see the window as it is then: a button's rect
        after the last draw, the Start button after a click changed the menu's rows."""
        if frame <= self.frame:
            self._post(events)
        else:
            self._script.setdefault(frame, []).extend(events)

    def run_for(self, frames, until=None):
        """Let the loop run frames more frames, then post one QUIT.

        With until (a function of no arguments), the QUIT comes as soon as until() is true after a frame.
        Either way stopped_by says why. A loop still going GRACE_FRAMES after its QUIT raises RunawayLoop."""
        self._stop_at = self.frame + frames
        self._until = until
        self._limit = self._stop_at + GRACE_FRAMES
        self.stopped_by = None

    def tick(self):
        """One frame: called by every fake Clock.tick(). Returns the frame time in milliseconds."""
        self.frame += 1
        self.now += FRAME_MS
        if self.frame > self._limit:
            raise RunawayLoop(f"the loop ran {self.frame} frames without stopping: give it a budget with "
                              f"driver.run_for(frames) before run(), and check that the window handles QUIT")
        if self.stopped_by is None:
            for frame in sorted(f for f in self._script if f <= self.frame):
                self._post(self._script.pop(frame))
            if self._until is not None and self._until():
                self._quit("until")
            elif self._stop_at is not None and self.frame >= self._stop_at:
                self._quit("budget")
        return FRAME_MS

    def _quit(self, reason):
        pygame = sys.modules["pygame"]
        pygame.event.post(pygame.event.Event(pygame.QUIT))
        self.stopped_by = reason
        self._limit = self.frame + GRACE_FRAMES     # counts from the QUIT, which may come long before the budget

    def _post(self, items):
        pygame = sys.modules["pygame"]
        for item in items:
            if callable(item):
                item = item()
            if item is None:
                continue
            for event in item if isinstance(item, (list, tuple)) else (item,):
                pygame.event.post(event)


# ----- events ----------------------------------------------------------------------------------------------
def _pygame():
    install()
    return sys.modules["pygame"]


def _point(pos):
    return int(round(pos[0])), int(round(pos[1]))


def key(k, mod=0):
    """A key press, KEYDOWN then KEYUP. k is a key code (pygame.K_SPACE) or name ("space", "escape", "f5", "1")."""
    pygame = _pygame()
    code = pygame.key.key_code(k) if isinstance(k, str) else k
    name = pygame.key.name(code)
    text = {pygame.K_SPACE: " ", pygame.K_RETURN: "\r", pygame.K_TAB: "\t"}.get(code, name if len(name) == 1 else "")
    return [pygame.event.Event(kind, key=code, mod=mod, unicode=text, scancode=0)
            for kind in (pygame.KEYDOWN, pygame.KEYUP)]


def hover(pos, buttons=(0, 0, 0), rel=(0, 0)):
    """The mouse moves to pos (MOUSEMOTION). buttons are the (left, middle, right) buttons held down."""
    pygame = _pygame()
    return [pygame.event.Event(pygame.MOUSEMOTION, pos=_point(pos), rel=_point(rel), buttons=tuple(buttons),
                               touch=False)]


def click(pos, button=1, move=True):
    """A click at pos: the mouse moves there (unless move=False), then MOUSEBUTTONDOWN and MOUSEBUTTONUP.
    button 1 is left, 2 middle, 3 right."""
    pygame = _pygame()
    pos = _point(pos)
    return (hover(pos) if move else []) + [pygame.event.Event(kind, pos=pos, button=button, touch=False)
                                           for kind in (pygame.MOUSEBUTTONDOWN, pygame.MOUSEBUTTONUP)]


def drag(start, end, button=3, steps=4):
    """Press button at start, move to end in steps motions with it held (each with its rel), release at end."""
    pygame = _pygame()
    start, end = _point(start), _point(end)
    held = tuple(int(b == button) for b in (1, 2, 3))
    events = hover(start) + [pygame.event.Event(pygame.MOUSEBUTTONDOWN, pos=start, button=button, touch=False)]
    last = start
    for i in range(1, steps + 1):
        at = _point((start[0] + (end[0] - start[0]) * i / steps, start[1] + (end[1] - start[1]) * i / steps))
        events += hover(at, held, (at[0] - last[0], at[1] - last[1]))
        last = at
    return events + [pygame.event.Event(pygame.MOUSEBUTTONUP, pos=end, button=button, touch=False)]


def _code(k):
    return _pygame().key.key_code(k) if isinstance(k, str) else k


class _Pressed:
    """What pygame.key.get_pressed() returns: indexed by key code (keys[pygame.K_RIGHT])."""

    def __init__(self, codes):
        self.codes = frozenset(codes)

    def __getitem__(self, code):
        return code in self.codes


class HeldKeys:
    """A stand-in for pygame.key.get_pressed(): the keys in down (key codes) read as held, all others as up.

    Install one with UITestCase.hold_keys(). press() and release() take key codes or names ("right", "d") and
    return None, so the driver can call them on a frame. release() with no keys releases them all. Holding a key
    posts no KEYDOWN: add key(...) to the script too if the window should also see the press."""

    def __init__(self):
        self.down = set()

    def press(self, *keys):
        self.down.update(_code(k) for k in keys)

    def release(self, *keys):
        if keys:
            self.down.difference_update(_code(k) for k in keys)
        else:
            self.down.clear()

    def __call__(self):
        return _Pressed(self.down)


def wheel(dy, dx=0, pos=None):
    """A mouse wheel turn: dy > 0 away from you (zooms in on the campaign map). With pos, the mouse moves
    there first (the campaign zooms around the mouse)."""
    pygame = _pygame()
    events = hover(pos) if pos is not None else []
    return events + [pygame.event.Event(pygame.MOUSEWHEEL, x=dx, y=dy, flipped=False, precise_x=float(dx),
                                        precise_y=float(dy), touch=False, which=0)]


# ----- where things are on screen --------------------------------------------------------------------------
def _matches(found, wanted):
    if wanted is None:
        return True
    if isinstance(wanted, str):
        return bool(found) and found[0] == wanted
    return tuple(found[:len(wanted)]) == tuple(wanted)


def _find(buttons, label, action, where):
    """buttons: (rect, label, action) triples. label matches the start of a label, action the start of an
    action tuple (a string: its first item). The first match in screen order wins."""
    for rect, text, act in buttons:
        if (label is None or (text or "").startswith(label)) and _matches(act, action):
            return rect
    have = ", ".join(f"{text!r} {act!r}" if text is not None else repr(act) for _, text, act in buttons)
    raise LookupError(f"no button with label {label!r} and action {action!r} in {where}: {have or 'none'}")


def button_rect(app, label=None, action=None):
    """The rect of one of the window's buttons (app.ui.buttons), by label and/or action.

    Conquest and Colonisation rebuild their buttons in refresh(), after every action. The campaign rebuilds
    them while drawing, so they exist after a frame (or app.draw()) and are those of the last frame drawn.
    e.g. button_rect(app, "Found"), button_rect(app, action=("train",)), button_rect(app, action="end")."""
    return _find([(b.rect, b.label, b.action) for b in app.ui.buttons], label, action, "app.ui.buttons")


def _kind(app):
    """Which window app is: "campaign", "colony" or "conquest" (play.App)."""
    from hexa.campaign.app import CampaignApp
    from hexa.colony.app import ColonyApp
    return "campaign" if isinstance(app, CampaignApp) else "colony" if isinstance(app, ColonyApp) else "conquest"


def end_turn_rect(app):
    """The End turn button of Conquest or Colonisation, or the campaign's End season button (after a frame)."""
    kind = _kind(app)
    if kind == "campaign":
        return button_rect(app, action="end")
    if kind == "colony":
        from hexa.colony.render import END_TURN_RECT
    else:
        from hexa.render import END_TURN_RECT
    return END_TURN_RECT


def pause_button_rect(app, action):
    """A button of the campaign's pause menu (Esc), by action: "resume", ("page", "save"), ("save", 2),
    ("option", "fullscreen"), "menu", "exit"... The page is laid out when drawn, so call it after a frame."""
    return _find([(rect, None, act) for rect, act, _ in app.menu_buttons], None, action, "app.menu_buttons")


def menu_option_rect(menu, key, value):
    """The start menu's option button, e.g. menu_option_rect(menu, "mode", "colony"), for its current rows."""
    buttons, _ = menu._layout()
    return _find([(rect, None, (k, v)) for rect, k, v in buttons], None, (key, value), "the menu's options")


def menu_start_rect(menu):
    """The start menu's Start game button (it moves when the rows change, e.g. after picking a mode)."""
    return menu._layout()[1]


def menu_continue_rect(menu):
    """The start menu's Continue button, or None when there is no save to continue."""
    return menu._continue_rect(menu._layout()[1])


def hex_pixel(app, pos):
    """The screen pixel at the centre of map hex pos (col, row), with the window's camera as it is now.
    It may be off screen: scroll there first (e.g. app.look_at(pos) in the campaign or Colonisation)."""
    kind = _kind(app)
    if kind == "campaign":                             # MapView geometry, a camera, the top bar
        x, y = app.view.center(pos)
        rect = app.view_rect()
        return _point((x - app.camera[0] + rect.x, y - app.camera[1] + rect.y))
    if kind == "colony":                               # the camera is in renderer.origin
        return _point(app.renderer.center(pos))
    from hexa.hexgrid import hex_center                # Conquest: the whole map is on screen
    from hexa.render import MAP_ORIGIN
    return _point(hex_center(pos, MAP_ORIGIN))


def minimap_pixel(app, pos):
    """Colonisation: the centre of hex pos's cell on the minimap (top right) as it is drawn, odd rows half a
    cell to the right: the pixel a player clicks to look at that hex."""
    from hexa.colony.render import MINI_CELL, minimap_rect
    rect = minimap_rect(app.world)
    col, row = pos
    return (rect.x + col * MINI_CELL + (row & 1) * (MINI_CELL // 2) + MINI_CELL // 2,
            rect.y + row * MINI_CELL + MINI_CELL // 2)


# ----- tests -----------------------------------------------------------------------------------------------
def artifacts_dir():
    """The folder for files that explain a failure ($HEXA_TEST_ARTIFACTS, default test-artifacts/); CI keeps it."""
    path = os.environ.get(ARTIFACTS_VAR) or ARTIFACTS_DEFAULT
    os.makedirs(path, exist_ok=True)
    return path


def save_screen(name):
    """Save the window as it is now to <artifacts>/<name>.png and return the path (None without a window).
    Characters other than letters, digits, ".", "-" and "_" in name become "_"."""
    pygame = sys.modules.get("pygame")
    if pygame is None or not pygame.display.get_init() or pygame.display.get_surface() is None:
        return None
    path = os.path.join(artifacts_dir(), re.sub(r"[^\w.-]", "_", name) + ".png")
    try:
        pygame.image.save(pygame.display.get_surface(), path)
    except (pygame.error, OSError):        # e.g. a path too long for Windows: report the failure, not this
        return None
    return path


def _problems(result):
    return len(result.errors) + len(result.failures) if result is not None else 0


@requires_pygame
class UITestCase(TempHome):
    """Base class for tests that drive a window: skipped without pygame (see tests/support/pg.py); pygame is
    headless and patched; self.driver is reset; HEXA_HOME is a new temporary folder (self.home).
    When a test fails or errors, the last frame on screen is saved to the artifacts folder."""

    def setUp(self):
        self.driver = install()         # first: without pygame there is nothing to clean up
        self.driver.reset()
        super().setUp()

    def hold_keys(self, *keys):
        """Patch pygame.key.get_pressed() with a HeldKeys until the test ends, keys held from the start;
        return it, to press() and release() keys on the frames the test wants."""
        held = HeldKeys()
        held.press(*keys)
        patcher = mock.patch.object(sys.modules["pygame"].key, "get_pressed", held)
        patcher.start()
        self.addCleanup(patcher.stop)
        return held

    def run(self, result=None):
        before = _problems(result)
        result = super().run(result)
        if _problems(result) > before:
            path = save_screen(self.id())
            if path:
                print(f"\nThe last frame of {self.id()} is in {path}", file=sys.stderr)
        return result
