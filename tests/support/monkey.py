"""Seeded monkey sessions: random input into a real window's own run() loop, then the world invariants.

    plan(mode, seed, frames, burst)          a session's input, frame by frame: same arguments, same plan (no pygame)
    run_session(mode, seed, frames, burst)   play that plan through the window headless; returns an Outcome
    repro(mode, seed, frames, burst)         the command that replays one session: python -m tools.monkey ...
    seeds(mode), frames(mode), burst()       what HEXA_MONKEY_SEEDS, HEXA_MONKEY_FRAMES and HEXA_MONKEY_BURST ask for

tests/ui/test_monkey.py and tools/monkey.py both run sessions through run_session(), so a session a test failed
replays exactly with the command it printed.

A session opens one window the way the launcher does: Conquest map #seed; Colonisation map #seed with a start and
a goal drawn from the seed; Age of Discovery on Europe 1480 as a country drawn from the seed (as --nation starts
it). The window's real loop then runs ``frames`` frames of the harness's fake time. Each frame gets one action, or,
with probability ``burst``, a burst of 2 to 6 actions in the same frame (events that arrive together, the races
that found #9). An action is one of: a key from the mode's whitelist (KEYS; never QUIT), Space or Return or a
click on End turn now and then, a left, right or middle click on a random screen point or aimed at the window's
own buttons, units, reachable hexes, attack targets, towns, colonies, villages, provinces or minimap (AIMS), a
drag, a wheel turn, a mouse move, holding or releasing a scroll key, or an idle frame. Aimed actions pick their
target when their frame comes, from what the window shows then; the random numbers are all drawn up front, so the
plan depends on nothing but (mode, seed, burst) and a shorter session is the beginning of a longer one.

When Esc or M (or the pause menu's Main menu and Exit) ends the loop before the budget is used, the same window
runs again, with the same world, until it is. The invariants of tests/support/invariants.py are checked every
CHECK_EVERY frames, at every such restart and at the end.

A session fails on any exception out of the window (it stops there) and on any broken invariant that
invariants.KNOWN_OPEN does not explain; the known-open ones are reported, not failed. Each session has its own
temporary HEXA_HOME (saves and settings.json: F5, F11, autosave and the pause menu write there) and seeds the
global ``random`` module (R starts a new random map), putting both back afterwards.

KNOWN_ISSUES lists the input a session withholds because it would hit a known open crash: the event is dropped
before the window sees it, counted, and logged. Everything else reaches the window.

pygame is imported lazily (in run_session), so plan() and the environment helpers work without it.
"""
import bisect
import collections
import contextlib
import hashlib
import os
import random
import shutil
import sys
import tempfile
import time
import traceback
from unittest import mock

from tests.support import invariants

MODES = ("conquest", "colony", "campaign")
NAMES = {"conquest": "Conquest", "colony": "Colonisation", "campaign": "Age of Discovery"}
SEEDS_VAR, FRAMES_VAR, BURST_VAR = "HEXA_MONKEY_SEEDS", "HEXA_MONKEY_FRAMES", "HEXA_MONKEY_BURST"
DEFAULT_SEEDS = {"conquest": (1, 2), "colony": (1, 2), "campaign": (1, 2)}
DEFAULT_FRAMES = {"conquest": 800, "colony": 800, "campaign": 300}
DEFAULT_BURST = 0.3
BURST_SIZE = (2, 6)           # actions in a burst frame
CHECK_EVERY = 50              # frames between invariant checks
SHOWN_ACTIONS = 12            # the last actions a report shows

# What a frame's action is, with weights, per mode. "end" is Space, Return or a click on End turn / End season:
# rare in the campaign, where a season runs every country's AI at once.
ACTIONS = {
    "conquest": {"key": 20, "end": 4, "click": 12, "aim": 32, "drag": 3, "wheel": 1, "hover": 12, "wait": 16},
    "colony": {"key": 18, "end": 3, "click": 10, "aim": 32, "drag": 6, "wheel": 1, "hover": 10, "hold": 3,
               "release": 2, "wait": 15},
    "campaign": {"key": 16, "end": 1.5, "click": 12, "aim": 34, "drag": 5, "wheel": 5, "hover": 12, "hold": 2,
                 "release": 2, "wait": 10.5},
}
# What an aimed action aims at, with weights. While the campaign's pause menu is open, every aim goes to its buttons.
AIMS = {
    "conquest": {"button": 30, "unit": 22, "reach": 22, "attack": 10, "town": 8, "hex": 8},
    "colony": {"button": 30, "unit": 18, "reach": 18, "attack": 8, "colony": 8, "village": 5, "minimap": 5, "hex": 8},
    "campaign": {"button": 36, "unit": 14, "reach": 14, "attack": 8, "province": 10, "minimap": 4, "hex": 14},
}
# The key whitelist (pygame key names, with weights), besides END_KEYS: every key the window handles, and one it
# ignores ("x"). No QUIT event is ever sent (closing the window would end the session's loop for good).
#   Conquest      Esc (deselect, else quit), M (menu), Tab (next unit), R (new map), B (build/found), 1-4 (train)
#   Colonisation  Esc, M, Tab, R, C (centre), B (build/found), J (join), 1-7 (the selection's buttons)
#   campaign      Esc (close panel, else pause menu), M (pause menu), Tab, 1-4 (map modes; 3 again: goods view),
#                 + = - and the keypad's (zoom), L (ledger), C (country), B (found), F5 (quicksave), F9 twice
#                 (quickload), F11 (fullscreen; settings.json goes to the session's HEXA_HOME)
KEYS = {
    "conquest": {"escape": 3, "m": 1, "tab": 6, "r": 0.1, "b": 3, "1": 2, "2": 2, "3": 2, "4": 2, "x": 0.5},
    "colony": {"escape": 3, "m": 1, "tab": 6, "r": 0.1, "c": 2, "b": 3, "j": 2, "1": 2, "2": 2, "3": 2, "4": 2,
               "5": 1.5, "6": 1.5, "7": 1, "x": 0.5},
    "campaign": {"escape": 4, "m": 1.5, "tab": 4, "1": 2, "2": 2, "3": 2, "4": 2, "+": 1, "=": 1, "-": 2,
                 "[+]": 0.5, "[-]": 0.5, "l": 2, "c": 2, "b": 2, "f5": 0.4, "f9": 1, "f11": 0.3, "x": 0.5},
}
END_KEYS = ("space", "return")
HOLD_KEYS = ("left", "right", "up", "down", "a", "d", "w", "s")      # scrolling reads pygame.key.get_pressed()
CLICK_BUTTONS = {1: 70, 3: 20, 2: 10}
AIM_BUTTONS = {1: 65, 3: 25, 0: 10}                                  # 0: only move the mouse there
DRAG_BUTTONS = {3: 70, 2: 15, 1: 15}

# Input withheld because it would hit a known open crash: (id, mode, what is withheld, symptom, bug). Each id has a
# predicate below (_WITHHOLD) that says, at the moment the window would handle an event, whether that event is it.
# run_session(hit=...) and the tool's --hit let an issue's input through, to reproduce the crash.
KNOWN_ISSUES = (
    ("card-toast", "campaign",
     "left clicks on a greyed-out button whose hover hint is a card rather than a line of text: the troops of "
     "the Raise panel",
     "TypeError: text must be a unicode or bytes in CampaignApp._one_line: left_click() shows a disabled "
     "button's hint as a toast, and draw_hint() renders the toast as one line of text; the troop buttons' hint "
     "is a (title, lines) card",
     "new bug, no GitHub issue filed yet (found by this monkey); pinned by tests/ui/test_monkey.py "
     "NewBugsTest.test_campaign_25_300_burst_0_5"),
)


class MonkeyError(RuntimeError):
    """The monkey itself broke (not the window): a bug in this module."""


# ----- the plan (no pygame) -------------------------------------------------------------------------------------
class Plan:
    """setup: what the window opens with; frames: [(frame, actions)], frame 1 up to frames - 1 (the last frame only
    carries the harness's QUIT)."""

    def __init__(self, mode, seed, burst, setup, frames):
        self.mode, self.seed, self.burst, self.setup, self.frames = mode, seed, burst, setup, frames

    def digest(self):
        return hashlib.sha256(repr((self.setup, self.frames)).encode()).hexdigest()


def _check_mode(mode):
    if mode not in MODES:
        raise ValueError(f"unknown mode {mode!r}: use one of {', '.join(MODES)}")


def _pick(rng, weights, leave_out=None):
    """A weighted choice of a key of weights. Uses only rng.random(), which no Python version has changed."""
    names = [name for name in weights if name != leave_out]
    totals, total = [], 0.0
    for name in names:
        total += weights[name]
        totals.append(total)
    return names[min(bisect.bisect_right(totals, rng.random() * total), len(names) - 1)]


def setup_of(mode, seed):
    """What the session's window opens: the map seed, Colonisation's start and goal, the campaign's country."""
    _check_mode(mode)
    rng = random.Random(f"hexa-monkey/{mode}/{seed}/setup")
    if mode == "conquest":
        return {"map": seed}
    if mode == "colony":
        from hexa.colony.rules import GOAL_NAMES, START_NAMES
        return {"map": seed, "start": rng.choice(sorted(START_NAMES)), "goal": rng.choice(sorted(GOAL_NAMES))}
    from hexa.campaign import geo
    return {"nation": rng.choice(sorted(geo.COUNTRIES))}


def _action(rng, mode, idle):
    kind = _pick(rng, ACTIONS[mode], leave_out=None if idle else "wait")
    if kind == "key":
        return ("key", _pick(rng, KEYS[mode]))
    if kind == "end":
        return ("end", rng.choice(END_KEYS + ("click",)))
    if kind == "click":
        return ("click", rng.random(), rng.random(), _pick(rng, CLICK_BUTTONS))
    if kind == "aim":
        return ("aim", _pick(rng, AIMS[mode]), rng.random(), _pick(rng, AIM_BUTTONS), rng.random(), rng.random())
    if kind == "drag":
        return ("drag", rng.random(), rng.random(), rng.random(), rng.random(), _pick(rng, DRAG_BUTTONS),
                rng.randint(1, 6))
    if kind == "wheel":
        return ("wheel", rng.choice((1, -1)), rng.random(), rng.random())
    if kind == "hover":
        return ("hover", rng.random(), rng.random())
    if kind == "hold":
        return ("hold", rng.choice(HOLD_KEYS))
    return (kind,)                                                    # release, wait


def plan(mode, seed, frames, burst=DEFAULT_BURST):
    """The input of one session. Burst frames never idle; frames only cuts the plan short."""
    _check_mode(mode)
    if not 0 <= burst <= 1:
        raise ValueError(f"burst must be between 0 and 1, not {burst}")
    rng = random.Random(f"hexa-monkey/{mode}/{seed}")
    schedule = []
    for frame in range(1, frames):
        count = rng.randint(*BURST_SIZE) if rng.random() < burst else 1
        schedule.append((frame, tuple(_action(rng, mode, idle=count == 1) for _ in range(count))))
    return Plan(mode, seed, burst, setup_of(mode, seed), schedule)


def keys_of(mode):
    """Every key a session of this mode may press."""
    return set(KEYS[mode]) | set(END_KEYS)


# ----- the environment ------------------------------------------------------------------------------------------
def _number(var, text, kind):
    try:
        return kind(text)
    except ValueError:
        raise ValueError(f"{var}: {text!r} is not a{'n integer' if kind is int else ' number'}") from None


def parse_seeds(text, var=SEEDS_VAR, count=True):
    """"A-B": seeds A to B; "3,8,12" (items may be ranges): those; "N": seeds 1 to N, or with count=False only N
    (the tool's seed argument). Returns a tuple."""
    text = text.strip()
    if "," not in text and "-" not in text:
        n = _number(var, text, int)
        if count and n < 1:
            raise ValueError(f"{var}: {text!r}: at least 1 seed")
        return tuple(range(1, n + 1)) if count else (n,)
    found = []
    for item in text.split(","):
        first, dash, last = item.strip().partition("-")
        first = _number(var, first, int)
        last = _number(var, last, int) if dash else first
        if last < first:
            raise ValueError(f"{var}: {item.strip()!r} is an empty range")
        found.extend(range(first, last + 1))
    return tuple(found)


def seeds(mode, env=None):
    """The seeds to play for mode: HEXA_MONKEY_SEEDS (see parse_seeds) or DEFAULT_SEEDS."""
    _check_mode(mode)
    text = (os.environ if env is None else env).get(SEEDS_VAR, "").strip()
    return parse_seeds(text) if text else DEFAULT_SEEDS[mode]


def frames(mode, env=None):
    """The frame budget for mode: HEXA_MONKEY_FRAMES as "3000" (every mode), "campaign=600" (one mode) or both
    ("3000,campaign=600"), else DEFAULT_FRAMES."""
    _check_mode(mode)
    text = (os.environ if env is None else env).get(FRAMES_VAR, "").strip()
    budget = DEFAULT_FRAMES[mode]
    for item in filter(None, (part.strip() for part in text.split(","))):
        name, equals, value = item.rpartition("=")
        if equals and name.strip() not in MODES:
            raise ValueError(f"{FRAMES_VAR}: {name.strip()!r} is not a mode ({', '.join(MODES)})")
        if not equals or name.strip() == mode:
            budget = _number(FRAMES_VAR, value.strip(), int)
            if budget < 2:
                raise ValueError(f"{FRAMES_VAR}: {item!r}: at least 2 frames")
    return budget


def burst(env=None):
    """HEXA_MONKEY_BURST (0 to 1) or DEFAULT_BURST."""
    text = (os.environ if env is None else env).get(BURST_VAR, "").strip()
    if not text:
        return DEFAULT_BURST
    value = _number(BURST_VAR, text, float)
    if not 0 <= value <= 1:
        raise ValueError(f"{BURST_VAR}: {text!r} is not between 0 and 1")
    return value


def repro(mode, seed, frames, burst, hit=()):
    """The one-line command that replays a session (hit: the KNOWN_ISSUES ids whose input it let through)."""
    return f"python -m tools.monkey {mode} {seed} {frames} --burst {burst:g}" + "".join(f" --hit {i}" for i in hit)


def issue_ids(mode=None):
    """The KNOWN_ISSUES ids (of one mode), in table order."""
    return tuple(issue[0] for issue in KNOWN_ISSUES if mode is None or issue[1] == mode)


# ----- the outcome ----------------------------------------------------------------------------------------------
class Outcome:
    """What a session did and found.

    failed      an exception or an unexplained broken invariant
    error       the exception out of the window (None), with trace (its traceback) and error_frame
    problems    {invariant: (frame, text)} broken invariants no open bug explains, as first seen
    known       {invariant: (frame, text, bug)} broken invariants that invariants.KNOWN_OPEN explains
    withheld    Counter of the events withheld per KNOWN_ISSUES id; hit: the ids whose input was let through
    log         every action as it reached the window: (frame, kind, details...); log_hash() digests it
    world       the window's world at the end; world_digest() digests it (tests/support/digests.py)
    """

    def __init__(self, mode, seed, frames, burst, setup, hit=()):
        self.mode, self.seed, self.frames, self.burst, self.setup = mode, seed, frames, burst, setup
        self.hit = tuple(hit)
        self.error, self.trace, self.error_frame = None, "", None
        self.problems, self.known = {}, {}
        self.withheld = collections.Counter()
        self.log = []
        self.frames_run = self.restarts = self.events = 0
        self.world = None
        self.seconds = 0.0

    @property
    def failed(self):
        return self.error is not None or bool(self.problems)

    def log_hash(self):
        return hashlib.sha256(repr(self.log).encode()).hexdigest()

    def world_digest(self):
        from tests.support.digests import world_digest
        return world_digest(self.world)

    def repro(self):
        return repro(self.mode, self.seed, self.frames, self.burst, self.hit)

    def where(self):
        """Mode, seed, setup and budget in words."""
        setup = ", ".join(f"{k} {v}" for k, v in self.setup.items())
        return f"{NAMES[self.mode]} monkey, seed {self.seed} ({setup}), {self.frames} frames, burst {self.burst:g}"

    def turn(self):
        world = self.world
        return getattr(world, "turn", None)

    def summary(self):
        """One line: the result, how far the game got, how long it took."""
        state = "FAILED" if self.failed else "ok"
        if self.error is not None:
            state += f" at frame {self.error_frame}: {type(self.error).__name__}: {self.error}"
        elif self.problems:
            state += f": {len(self.problems)} broken invariant(s)"
        extra = f", {len(self.known)} known open" if self.known else ""
        extra += f", {sum(self.withheld.values())} withheld" if self.withheld else ""
        return (f"{self.mode} seed {self.seed}: {state} ({self.frames_run} frames, {len(self.log)} actions, "
                f"{self.restarts} restarts, turn {self.turn()}{extra}, {self.seconds:.1f} s)")

    def report(self):
        """Everything about a failed (or any) session, ending with the replay command."""
        lines = [f"{self.where()}: {'FAILED' if self.failed else 'passed'} after {self.frames_run} frames "
                 f"({self.restarts} restarts, turn {self.turn()})"]
        if self.error is not None:
            lines.append(f"  {type(self.error).__name__} at frame {self.error_frame}: {self.error}")
            lines.extend("    " + line for line in self.trace.rstrip().splitlines()[-16:])
        if self.problems:
            lines.append("  broken invariants (frame first seen: problem):")
            lines.extend(f"    frame {frame}: {text}" for frame, text in self.problems.values())
        if self.known:
            lines.append("  known open bugs seen (tolerated, see invariants.KNOWN_OPEN):")
            lines.extend(f"    frame {frame}: {text}  [{bug}]" for frame, text, bug in self.known.values())
        if self.withheld:
            lines.append("  input withheld for known open crashes (KNOWN_ISSUES): "
                         + ", ".join(f"{issue} x{n}" for issue, n in sorted(self.withheld.items())))
        if self.hit:
            lines.append(f"  input let through although it hits a known open crash: {', '.join(self.hit)}")
        if self.log:
            lines.append(f"  the last {min(SHOWN_ACTIONS, len(self.log))} actions:")
            lines.extend(f"    {entry}" for entry in self.log[-SHOWN_ACTIONS:])
        lines.append(f"Replay: {self.repro()}")
        return "\n".join(lines)


# ----- the session (pygame) ----------------------------------------------------------------------------------------
def run_session(mode, seed, frames, burst=DEFAULT_BURST, prepare=None, hit=()):
    """Play one session through its window headless and return its Outcome. Never raises for what the window does.

    prepare(app), if given, runs once the window is open, before its loop (the self-tests use it to break things).
    hit: KNOWN_ISSUES ids of this mode whose input is let through instead of withheld ("all": every one)."""
    from tests.support import harness
    driver = harness.install()
    sys.modules["pygame"].display.quit()   # the dummy driver gives a new window the size of the last fullscreen one
    driver.reset()                         # (pygame.init() opens the display again)
    session = _Session(plan(mode, seed, frames, burst), frames, driver, hit)
    return session.run(prepare)


@contextlib.contextmanager
def _isolated(mode, seed):
    """A temporary HEXA_HOME, the global random module seeded, and held keys standing in for get_pressed()."""
    import pygame
    from tests.support import harness
    home = tempfile.mkdtemp(prefix="hexa-monkey-")
    old_home = os.environ.get("HEXA_HOME")
    os.environ["HEXA_HOME"] = home
    state = random.getstate()
    random.seed(f"hexa-monkey/{mode}/{seed}/random")
    held = harness.HeldKeys()
    try:
        with mock.patch.object(pygame.key, "get_pressed", held):
            yield held
    finally:
        random.setstate(state)
        if old_home is None:
            os.environ.pop("HEXA_HOME", None)
        else:
            os.environ["HEXA_HOME"] = old_home
        shutil.rmtree(home, ignore_errors=True)


def _open(mode, setup, seed):
    import pygame
    import play
    if mode == "conquest":
        return play.App(setup["map"])
    if mode == "colony":
        from hexa.colony.app import ColonyApp
        from hexa.colony.render import WINDOW_SIZE
        return ColonyApp(pygame.display.set_mode(WINDOW_SIZE), play.TILES_DIR, setup["map"], setup["start"],
                         setup["goal"])
    from hexa.campaign.app import CampaignApp
    if seed % 2:        # odd seeds play with the movement replay on, seeds 1, 5, 9 ... also with the reminders, as the game
        from hexa import settings           # ships: written to the session's HEXA_HOME before the window reads it
        settings.save(dict(settings.DEFAULTS, movement="normal", reminders=seed % 4 == 1))
    return CampaignApp(play.TILES_DIR, setup["nation"])


class _Session:
    def __init__(self, plan_, frames, driver, hit):
        self.plan, self.mode, self.driver = plan_, plan_.mode, driver
        ids = issue_ids(self.mode)
        unknown = set(hit) - set(issue_ids()) - {"all"}
        if unknown:
            raise ValueError(f"no known issue {sorted(unknown)}: the ids are {', '.join(issue_ids())}")
        let_through = ids if "all" in hit else tuple(i for i in ids if i in hit)
        self.withhold = tuple(i for i in ids if i not in let_through)
        self.outcome = Outcome(plan_.mode, plan_.seed, frames, plan_.burst, plan_.setup, let_through)
        self.app = self.held = None
        self.base = 0

    def frame(self):
        return self.driver.frame - self.base

    def run(self, prepare):
        out, driver = self.outcome, self.driver
        began = time.perf_counter()
        with _isolated(self.mode, self.plan.seed) as self.held:
            try:
                self.app = app = _open(self.mode, self.plan.setup, self.plan.seed)
                if prepare is not None:
                    prepare(app)
                real = app.handle
                app.handle = lambda event: self._handle(real, event)     # run() looks handle up on the instance
                self.base = driver.frame
                for frame, actions in self.plan.frames:
                    driver.at(self.base + frame, self._poster(frame, actions))
                for frame in range(CHECK_EVERY, out.frames, CHECK_EVERY):
                    driver.at(self.base + frame, self._check)
                driver.run_for(out.frames)
                while True:
                    app.run()
                    if driver.stopped_by is not None:
                        break
                    out.restarts += 1                  # Esc, M or the pause menu ended the loop: play on
                    out.log.append((self.frame(), "restart", app.result))
                    self._check()
                    app.running, app.result = True, None
            except Exception as error:                 # the window (or the monkey) broke: stop and report
                out.error, out.trace, out.error_frame = error, traceback.format_exc(), self.frame()
            else:
                self._check()
            out.frames_run = self.frame()
            out.world = self.app.world if self.app is not None else None
        out.seconds = time.perf_counter() - began
        return out

    # ----- input --------------------------------------------------------------------------------------------
    def _poster(self, frame, actions):
        def events():
            posted = []
            for action in actions:
                try:
                    found, entry = self._resolve(action)
                except Exception as error:
                    raise MonkeyError(f"frame {frame}: could not turn {action!r} into events: {error!r}") from error
                self.outcome.log.append((frame,) + entry)
                posted += found
            self.outcome.events += len(posted)
            return posted
        return events

    def _resolve(self, action):
        """The pygame events of one action, and its log entry."""
        from tests.support.harness import click, drag, hover, key, wheel
        kind = action[0]
        if kind == "key":
            return key(action[1]), action
        if kind == "end":
            if action[1] != "click":
                return key(action[1]), action
            pixel = self._aim("end", 0.0, 0.5, 0.5)
            return click(pixel), ("end", "click", pixel)
        if kind == "click":
            pixel = self._point(action[1], action[2])
            return click(pixel, action[3]), ("click", pixel, action[3])
        if kind == "aim":
            _, target, pick, button, fx, fy = action
            pixel = self._aim(target, pick, fx, fy)
            return (hover(pixel) if button == 0 else click(pixel, button)), ("aim", target, pixel, button)
        if kind == "drag":
            start, end = self._point(action[1], action[2]), self._point(action[3], action[4])
            return drag(start, end, action[5], action[6]), ("drag", start, end, action[5], action[6])
        if kind == "wheel":
            pixel = self._point(action[2], action[3])
            return wheel(action[1], pos=pixel), ("wheel", action[1], pixel)
        if kind == "hover":
            pixel = self._point(action[1], action[2])
            return hover(pixel), ("hover", pixel)
        if kind == "hold":
            self.held.press(action[1])
            return [], action
        if kind == "release":
            self.held.release()
            return [], action
        if kind == "wait":
            return [], action
        raise ValueError(f"unknown action {kind!r}")

    def _point(self, fx, fy, area=None):
        import pygame
        if area is None:
            area = pygame.Rect((0, 0), pygame.display.get_surface().get_size())
        return area.x + min(int(fx * area.w), area.w - 1), area.y + min(int(fy * area.h), area.h - 1)

    def _aim(self, target, pick, fx, fy):
        """A pixel on what target names, as the window shows it now; with nothing to aim at, a random point."""
        found, area = getattr(self, f"_{self.mode}_targets")(target)
        if found:
            return found[min(int(pick * len(found)), len(found) - 1)]
        return self._point(fx, fy, area)

    def _conquest_targets(self, target):
        from hexa.render import END_TURN_RECT
        from hexa.rules import PLAYER
        from tests.support.harness import hex_pixel
        app = self.app
        world, ui = app.world, app.ui
        hexes = {"unit": lambda: [u.pos for u in world.units_of(PLAYER)], "reach": lambda: sorted(ui.reach),
                 "attack": lambda: sorted(ui.attacks), "hex": lambda: sorted(world.terrain),
                 "town": lambda: [t.pos for t in world.towns if t.owner == PLAYER]}
        if target == "button":
            return [b.rect.center for b in ui.buttons], None
        if target == "end":
            return [END_TURN_RECT.center], None
        return [hex_pixel(app, pos) for pos in hexes[target]()], None

    def _colony_targets(self, target):
        import pygame
        from hexa.colony.render import END_TURN_RECT, VIEW_H, WINDOW_SIZE, minimap_rect
        from hexa.colony.rules import PLAYER
        from tests.support.harness import hex_pixel
        app = self.app
        world, ui = app.world, app.ui
        view = pygame.Rect(0, 0, WINDOW_SIZE[0], VIEW_H)
        if target == "button":
            return [b.rect.center for b in ui.buttons], None
        if target == "end":
            return [END_TURN_RECT.center], None
        if target == "minimap":
            return [], minimap_rect(world)
        if target == "hex":
            return [], view
        hexes = {"unit": lambda: [u.pos for u in world.units_of(PLAYER)], "reach": lambda: sorted(ui.reach),
                 "attack": lambda: sorted(ui.attacks),
                 "colony": lambda: [c.pos for c in world.colonies if c.owner == PLAYER],
                 "village": lambda: [v.pos for v in world.villages if not v.burned and v.pos in world.explored]}
        return [p for p in (hex_pixel(app, pos) for pos in hexes[target]()) if view.collidepoint(p)], view

    def _campaign_targets(self, target):
        from tests.support.harness import hex_pixel
        app = self.app
        world, ui = app.world, app.ui
        if app.menu:                                    # the pause menu covers the window: aim at its buttons
            return [rect.center for rect, _, _ in app.menu_buttons], None
        if target == "button":
            return [b.rect.center for b in ui.buttons], None
        if target == "end":
            return [b.rect.center for b in ui.buttons if b.action == ("end",)], None
        if target == "minimap":
            return [], app.minimap_rect()
        if target == "hex":
            return [], app.view_rect()
        tag = app.player
        hexes = {"unit": lambda: [u.pos for u in world.units_of(tag)] if tag else [],
                 "reach": lambda: sorted(ui.reach), "attack": lambda: sorted(ui.attacks),
                 "province": lambda: [p.pos for p in world.provinces_of(tag)] if tag else []}
        view, mini, panel = app.view_rect(), app.minimap_rect(), app.panel_rect() if ui.panel else None
        return [p for p in (hex_pixel(app, pos) for pos in hexes[target]())
                if view.collidepoint(p) and not mini.collidepoint(p) and not (panel and panel.collidepoint(p))], view

    def _handle(self, real, event):
        """The window's own handle(), unless the event would hit a known open crash (KNOWN_ISSUES)."""
        try:
            issue = next((i for i in self.withhold if _WITHHOLD[i](self.app, event)), None)
        except Exception as error:
            raise MonkeyError(f"frame {self.frame()}: the KNOWN_ISSUES check of {_describe(event)} broke: "
                              f"{error!r}") from error
        if issue is None:
            return real(event)
        self.outcome.withheld[issue] += 1
        self.outcome.log.append((self.frame(), "withheld", issue, _describe(event)))
        return None

    # ----- invariants ---------------------------------------------------------------------------------------
    def _check(self):
        out, world = self.outcome, self.app.world
        try:
            problems = getattr(invariants, f"{self.mode}_problems")(world)
        except Exception as error:                                         # noqa: BLE001 - reported as a problem
            problems = [f"checker: {type(error).__name__}: {error}"]
        for text in problems:
            name = text.split(":", 1)[0]
            bug = invariants.known_open(self.mode, text)
            if bug:
                out.known.setdefault(name, (self.frame(), text, bug))
            else:
                out.problems.setdefault(name, (self.frame(), text))


def _clicked_button(app, event):
    """The campaign button a left click lands on, as left_click() finds it (None: the pause menu is open, no left
    click, or no button there)."""
    import pygame
    if app.menu or event.type != pygame.MOUSEBUTTONDOWN or event.button != 1:
        return None
    return next((b for b in app.ui.buttons if b.rect.collidepoint(event.pos)), None)


def _card_toast(app, event):
    """Would this left click show a disabled button's hover card as a toast (KNOWN_ISSUES "card-toast")?"""
    button = _clicked_button(app, event)
    return button is not None and not button.enabled and bool(button.hint) and not isinstance(button.hint, str)


_WITHHOLD = {"card-toast": _card_toast}


def _describe(event):
    import pygame
    name = pygame.event.event_name(event.type)
    if hasattr(event, "key"):
        return f"{name} {pygame.key.name(event.key)}"
    if hasattr(event, "button"):
        return f"{name} {event.button} at {event.pos}"
    if event.type == pygame.MOUSEWHEEL:
        return f"{name} {event.y}"
    return name


# ----- reporting -----------------------------------------------------------------------------------------------
def save_artifacts(outcome):
    """Write the report and the last frame on screen to the artifacts folder (CI keeps it); return the paths."""
    from tests.support import harness
    name = f"monkey-{outcome.mode}-{outcome.seed}"
    path = os.path.join(harness.artifacts_dir(), name + ".txt")
    with open(path, "w", encoding="utf-8") as f:
        f.write(outcome.report() + "\n")
    return [p for p in (path, harness.save_screen(name)) if p]


def issues_table():
    """KNOWN_ISSUES as text, for reports and the tool's --issues."""
    return "\n".join(f"{issue} ({mode}): withholds {what}.\n    Symptom: {symptom}.\n    {bug}."
                     for issue, mode, what, symptom, bug in KNOWN_ISSUES)
