"""Time the slow parts of the game and compare them with the budgets in tests/perf_budget.json (the nightly job).

    python -m tools.perf                        every metric, the median of 3 runs each, then the table
    python -m tools.perf --only ai_season,mapview_zoom4    some metrics
    python -m tools.perf --runs 5               the median of 5 runs
    python -m tools.perf --no-memory            leave out the memory check of the world caches (--only does too)
    python -m tools.perf --list                 the metrics and their budgets

A time is the CPU time of this process (time.process_time), so waiting for the disk or for other processes doesn't
count, where that clock is fine enough: its resolution must be 1 ms or better (Linux and macOS: 1 ns; CI runs Linux).
Windows' process_time ticks every 15.6 ms, which is coarser than the 4 ms and 5 ms budgets, so there a metric is timed
with time.perf_counter (wall clock, 100 ns). That also counts the time the process waited, so keep the machine idle.
The clock in use is printed first. The median of the runs is compared with the metric's budget. Over the soft limit the table notes it; over the
hard limit the run fails (exit status 1). Shared CI runners are slower and noisier than a desk machine, so the hard
limits are at least 3 times what was measured when they were set. The table goes to the terminal and, as markdown,
to $GITHUB_STEP_SUMMARY when that is set. The unit tests never time anything: only this tool does.

The MapView metrics need pygame (a Python 3.12 or 3.13 venv, see README, Window tests). Without it they are skipped
with a note, or fail under HEXA_REQUIRE_PYGAME=1. The memory row (tracemalloc) shows how much memory stays in the
world module's caches (_SNAPSHOTS, _RANDOM_GEOS) as more random worlds are built (#29). It is information only and
never fails the run, and neither does the table of the render caches under it (entries, memory, hits);
tests/test_memory.py holds the actual check.
"""
import argparse
import gc
import json
import os
import pickle
import platform
import statistics
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUDGET_FILE = os.path.join(ROOT, "tests", "perf_budget.json")
TILES_DIR = os.path.join(ROOT, "hexagon-pack", "PNG", "Tiles")
REQUIRE_VAR = "HEXA_REQUIRE_PYGAME"
RANDOM_SEED = 7               # the random world the golden screenshots show
LATE_SEASONS = 40             # ai_season_late: one season after this many (spring 1490)
MEMORY_SEEDS = (2901, 2902, 2903)
SCREEN = (1280, 720)


class Skip(Exception):
    """A metric that can't be measured here (no pygame)."""


# ----- the metrics ----------------------------------------------------------------------------------------------------
def _tick():
    """The smallest step process_time shows, measured by spinning until it changes. get_clock_info can say 100 ns where
    the clock only ticks every 15.6 ms (Windows, Python 3.13), so the reported resolution is not trusted alone."""
    limit = time.perf_counter() + 0.5
    start = time.process_time()
    while time.perf_counter() < limit:
        now = time.process_time()
        if now != start:
            return now - start
    return float("inf")


def _clock():
    """The clock a metric is timed with (see the docstring): process_time where it ticks in 1 ms or finer steps, else
    perf_counter. Returns (name, function)."""
    step = max(time.get_clock_info("process_time").resolution, _tick())
    if step <= 1e-3:
        return "process_time", time.process_time
    return "perf_counter", time.perf_counter


CLOCK_NAME, CLOCK = _clock()


def _cpu(action):
    """Seconds that action() takes on CLOCK (CPU seconds where the clock allows it)."""
    gc.collect()
    started = CLOCK()
    action()
    return CLOCK() - started


def _world_module():
    from hexa.campaign import world
    return world


def europe_build():
    """CampaignWorld(): the 1480 map built from scratch (the snapshot cache emptied first)."""
    w = _world_module()
    w._SNAPSHOTS.pop(("europe", 1480), None)
    return _cpu(w.CampaignWorld)


def random_build():
    """CampaignWorld(7, map="random"): a random world built from scratch, its geography too."""
    w = _world_module()
    w._SNAPSHOTS.pop(("random", RANDOM_SEED), None)
    w._RANDOM_GEOS.pop(RANDOM_SEED, None)
    return _cpu(lambda: w.CampaignWorld(RANDOM_SEED, map="random"))


def snapshot_restore():
    """CampaignWorld(player="POR") once the 1480 map is cached: what tests' fresh() and a new game cost."""
    w = _world_module()
    if ("europe", 1480) not in w._SNAPSHOTS:
        w.CampaignWorld()
    return _cpu(lambda: w.CampaignWorld(player="POR"))


def ai_season():
    """One all-AI season from spring 1480: every country's AI, then end_round()."""
    from tests.support.worlds import play_seasons
    world = _world_module().CampaignWorld()
    return _cpu(lambda: play_seasons(world, 1))


_LATE = {}


def ai_season_late():
    """One all-AI season after 40 (spring 1490): bigger armies, more colonies, more wars."""
    from tests.support.worlds import play_seasons
    w = _world_module()
    if "state" not in _LATE:                      # played once per process, then copied for every run
        _LATE["state"] = pickle.dumps(play_seasons(w.CampaignWorld(), LATE_SEASONS).save_state())
    world = w.CampaignWorld.from_state(pickle.loads(_LATE["state"]))
    return _cpu(lambda: play_seasons(world, 1))


def battle_season():
    """One battles phase with 10 battles of 6 mixed regiments a side (the stack limit without techs: pikes, knights and
    guns, two of each), on 10 pairs of hexes of the 1480 map. Only the phase is timed: the battles are started before the
    clock runs. Pikes only measured the cheapest battle; the army of a real war has all three arms (measured 2026-11-13)."""
    mixed = [("infantry", 1, 2), ("cavalry", 1, 2), ("artillery", 1, 2)]
    return _battle_phase(mixed, mixed)


def battle_season_worst():
    """The worst legal battle phase: 10 battles of 6 mixed regiments a side (pikes, knights and two guns each: the most
    expensive arms at the stack limit of 6), on 10 pairs of hexes of the 1480 map. Only the phase is timed."""
    mixed = [("infantry", 1, 3), ("cavalry", 1, 1), ("artillery", 1, 2)]
    return _battle_phase(mixed, mixed)


def _battle_phase(spec_a, spec_d):
    """Start 10 battles on the 1480 map with the two sides' regiments (spec: (branch, era, count) lists), then time one
    battles phase (every battle is fought to its end in it, 0.2.1)."""
    from hexa.campaign.data import troop
    from hexa.campaign.state import War
    from hexa.campaign.systems import battle as battlesys
    from hexa.hexgrid import neighbors
    w = _world_module().CampaignWorld()
    used, started = set(), 0
    for prov in sorted(w.provinces.values(), key=lambda p: p.pos):
        if started == 10:
            break
        if prov.owner is None or prov.pos in used or not w.is_land(prov.pos):
            continue
        for n in sorted(neighbors(prov.pos)):
            other = w.provinces.get(n)
            if other is None or other.owner in (None, prov.owner) or n in used or not w.is_land(n):
                continue
            a, d = prov.owner, other.owner
            if not w.at_war(a, d):
                w.wars.append(War(a, d, w.turn))
            attackers = [w.add_unit(troop(branch, era), a, prov.pos, moves=0)
                         for branch, era, count in spec_a for _ in range(count)]
            for branch, era, count in spec_d:
                for _ in range(count):
                    w.add_unit(troop(branch, era), d, n, moves=0)
            if w.engage(attackers, n):
                used.update({prov.pos, n})
                started += 1
            break
    return _cpu(lambda: battlesys.battle_season(w))


_SCREEN = {}


def _pygame():
    """pygame on the dummy drivers with a window, imported only here (the rest of this tool doesn't need it)."""
    if "pygame" not in _SCREEN:
        os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
        os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
        os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")
        try:
            import pygame
        except ImportError as error:
            raise Skip(f"pygame is not installed ({error}); run the MapView metrics with a Python 3.12 or 3.13 venv "
                       f"with pygame (README, Window tests)") from None
        pygame.init()
        _SCREEN["screen"] = pygame.display.set_mode(SCREEN)
        pygame.font.SysFont("segoeui,arial", 12, bold=True)      # find the system fonts once, outside the timing
        _SCREEN["pygame"] = pygame
    return _SCREEN["pygame"], _SCREEN["screen"]


def _mapview(zoom):
    pygame, screen = _pygame()
    from hexa.campaign.app import UI
    from hexa.campaign.mapview import MapView
    world = _world_module().CampaignWorld(player="POR")
    lisbon = world.provinces[world.countries["POR"].capital].pos
    rect = pygame.Rect(0, 0, *SCREEN)

    def draw():
        view = MapView(world, TILES_DIR)
        view.zoom = zoom
        x, y = view.center(lisbon)
        view.draw(screen, rect, (x - rect.w / 2, y - rect.h / 2), UI())
    return _cpu(draw)


def mapview_zoom1():
    """A new MapView's first draw at zoom 1 (flat colours, the whole map rendered), Portugal 1480, 1280x720."""
    return _mapview(1)


def mapview_zoom4():
    """A new MapView's first draw at zoom 4 (tile art around Lisbon), Portugal 1480, 1280x720. The landscape art of
    the close zooms is built a few hexes a frame, within mapview.LAND_BUILD_MS of real time, so this is the cost of
    one such frame, not of the whole picture."""
    return _mapview(4)


METRICS = {f.__name__: f for f in (europe_build, random_build, snapshot_restore, ai_season, ai_season_late,
                                   battle_season, battle_season_worst, mapview_zoom1, mapview_zoom4)}
PYGAME_METRICS = ("mapview_zoom1", "mapview_zoom4")


def what(name):
    return " ".join(METRICS[name].__doc__.split())


# ----- memory (#29) -----------------------------------------------------------------------------------------------
def cache_memory(seeds=MEMORY_SEEDS):
    """Build a random world for each seed under tracemalloc, dropping each one, and return the memory still traced
    after each build (bytes; what the world module's caches keep) with the caches' sizes at the end. The caches are
    put back as they were afterwards."""
    import tracemalloc
    w = _world_module()
    saved = dict(w._SNAPSHOTS), dict(w._RANDOM_GEOS)
    for seed in seeds:
        w._SNAPSHOTS.pop(("random", seed), None)
        w._RANDOM_GEOS.pop(seed, None)
    kept = []
    gc.collect()
    tracemalloc.start()
    try:
        base = tracemalloc.get_traced_memory()[0]
        for seed in seeds:
            w.CampaignWorld(seed, map="random")
            gc.collect()
            kept.append(tracemalloc.get_traced_memory()[0] - base)
    finally:
        tracemalloc.stop()
        caches = (len(w._SNAPSHOTS), len(w._RANDOM_GEOS))
        w._SNAPSHOTS.clear()
        w._SNAPSHOTS.update(saved[0])
        w._RANDOM_GEOS.clear()
        w._RANDOM_GEOS.update(saved[1])
    return kept, caches


def render_cache_rows(zooms=(3, 4, 5), frames=6):
    """What the render caches (hexa/campaign/render/cache.py) hold after a MapView has drawn Portugal 1480 at these
    zooms, `frames` frames each with the build time limit lifted: [(name, caches, entries, max entries, MB, hits,
    misses)]. Information only. Raises Skip without pygame."""
    pygame, screen = _pygame()
    from hexa.campaign import mapview
    from hexa.campaign.app import UI
    from hexa.campaign.render import cache
    cache.clear_all()
    world = _world_module().CampaignWorld(player="POR")
    lisbon = world.provinces[world.countries["POR"].capital].pos
    rect = pygame.Rect(0, 0, *SCREEN)
    limit, mapview.LAND_BUILD_MS = mapview.LAND_BUILD_MS, 1e9
    try:
        for zoom in zooms:
            view = mapview.MapView(world, TILES_DIR)
            view.zoom = zoom
            x, y = view.center(lisbon)
            for _ in range(frames):
                view.draw(screen, rect, (x - rect.w / 2, y - rect.h / 2), UI())
        rows = [(name, r["caches"], r["entries"], r["max_entries"], r["bytes"] / 1e6, r["hits"], r["misses"])
                for name, r in cache.stats(detail=True).items() if r["entries"]]
    finally:
        mapview.LAND_BUILD_MS = limit
    return rows


def cache_text(rows):
    lines = ["render caches after Portugal 1480 at zooms 3-5 (information only):",
             f"  {'cache':24}{'entries':>8}{'max':>7}{'MB':>8}{'hits':>9}{'misses':>8}"]
    lines += [f"  {n:24}{e:8}{m:7}{mb:8.2f}{h:9}{x:8}" for n, _c, e, m, mb, h, x in rows]
    lines.append(f"  {'total':24}{sum(r[2] for r in rows):8}{'':7}{sum(r[4] for r in rows):8.2f}")
    return "\n".join(lines)


def cache_markdown(rows):
    lines = ["", "### Render caches (information only)", "",
             "What `hexa/campaign/render/cache.py` caches hold after drawing Portugal 1480 at zooms 3-5.", "",
             "| Cache | Entries | Max | MB | Hits | Misses |", "|---|--:|--:|--:|--:|--:|"]
    lines += [f"| `{n}` | {e} | {m} | {mb:.2f} | {h} | {x} |" for n, _c, e, m, mb, h, x in rows]
    return "\n".join(lines) + "\n"


# ----- budgets and the table ------------------------------------------------------------------------------------------
def load_budget(path=BUDGET_FILE):
    with open(path, encoding="utf-8") as f:
        return json.load(f)["metrics"]


def judge(median, limits):
    """"ok", "over soft" (noted) or "OVER HARD" (fails the run) for a median against {"soft": s, "hard": h}."""
    if limits is None:
        return "no budget"
    if median > limits["hard"]:
        return "OVER HARD"
    if median > limits["soft"]:
        return "over soft"
    return "ok"


class Result:
    def __init__(self, name, runs=(), limits=None, skipped=""):
        self.name, self.runs, self.limits, self.skipped = name, list(runs), limits, skipped
        self.median = statistics.median(self.runs) if self.runs else None
        self.status = f"skipped: {skipped}" if skipped else judge(self.median, limits)

    @property
    def failed(self):
        return self.status == "OVER HARD"


def measure(names, runs, budget, require_pygame=False, out=print):
    """Results for these metrics: runs runs each. A metric that can't run here is skipped (an error with
    require_pygame for the pygame ones)."""
    results = []
    for name in names:
        times = []
        try:
            for _ in range(runs):
                times.append(METRICS[name]())
        except Skip as skip:
            if require_pygame and name in PYGAME_METRICS:
                raise SystemExit(f"{name}: {skip} ({REQUIRE_VAR}=1 makes this an error)") from None
            result = Result(name, limits=budget.get(name), skipped=str(skip).split(";")[0])
            out(f"{name}: skipped: {skip}")
        else:
            result = Result(name, times, budget.get(name))
            out(f"{name}: {result.median:.3f} s ({', '.join(f'{t:.3f}' for t in times)}) {result.status}")
        results.append(result)
    return results


def _limit(results_limits, key):
    return f"{results_limits[key]:g}" if results_limits else "-"


def markdown(results, memory=None, runs=3):
    lines = ["## Performance (CPU seconds, median of %d runs)" % runs, "",
             f"Python {platform.python_version()} on {platform.system()} {platform.machine()}, "
             f"budgets from `tests/perf_budget.json`: over the soft limit is noted, over the hard limit fails.", "",
             "| Metric | Median | Runs | Soft | Hard | Status | What |", "|---|--:|---|--:|--:|---|---|"]
    for r in results:
        median = f"{r.median:.3f}" if r.median is not None else "-"
        status = {"OVER HARD": "**OVER HARD LIMIT**", "over soft": "over soft limit"}.get(r.status, r.status)
        lines.append(f"| `{r.name}` | {median} | {', '.join(f'{t:.3f}' for t in r.runs) or '-'} | "
                     f"{_limit(r.limits, 'soft')} | {_limit(r.limits, 'hard')} | {status} | {what(r.name)} |")
    if memory is not None:
        lines.append(memory_row(*memory))
    return "\n".join(lines) + "\n"


def memory_row(kept, caches):
    """The table row of the memory check (information only)."""
    mb = [k / 1e6 for k in kept]
    growth = mb[-1] - mb[-2] if len(mb) > 1 else mb[0]
    return (f"| `world_cache_memory` (#29) | {growth:+.1f} MB | {', '.join(f'{m:.1f}' for m in mb)} MB | - | - | "
            f"info | Memory still held after building {len(mb)} random worlds one after another (tracemalloc); "
            f"the median column is what the last one added. The caches end with {caches[0]} snapshots and "
            f"{caches[1]} random geographies |")


def text_table(results, memory=None):
    rows = [("metric", "median", "soft", "hard", "status")]
    for r in results:
        rows.append((r.name, f"{r.median:.3f}" if r.median is not None else "-", _limit(r.limits, "soft"),
                     _limit(r.limits, "hard"), r.status))
    widths = [max(len(row[i]) for row in rows) for i in range(len(rows[0]))]
    lines = ["  ".join(c.ljust(w) if i in (0, 4) else c.rjust(w) for i, (c, w) in enumerate(zip(row, widths)))
             for row in rows]
    if memory is not None:
        kept, caches = memory
        mb = ", ".join(f"{k / 1e6:.1f}" for k in kept)
        lines.append(f"world caches (#29, information only): {mb} MB still held after each of {len(kept)} random "
                     f"worlds; {caches[0]} snapshots and {caches[1]} geographies kept")
    return "\n".join(lines)


def write_step_summary(text, env=None):
    path = (os.environ if env is None else env).get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as summary:
            summary.write(text + "\n")


# ----- the command ------------------------------------------------------------------------------------------------
def _parser():
    parser = argparse.ArgumentParser(prog="python -m tools.perf",
                                     description="Time the slow parts of the game against tests/perf_budget.json.")
    parser.add_argument("--only", help="comma-separated metrics (default: all): " + ", ".join(METRICS))
    parser.add_argument("--runs", type=int, default=3, help="runs per metric; the median counts (default 3)")
    parser.add_argument("--no-memory", action="store_true", help="leave out the memory check of the world caches")
    parser.add_argument("--budget", default=BUDGET_FILE, help="the budget file (default tests/perf_budget.json)")
    parser.add_argument("--list", action="store_true", help="print the metrics and their budgets and exit")
    return parser


def main(argv=None, out=print):
    parser = _parser()
    args = parser.parse_args(argv)
    budget = load_budget(args.budget)
    if args.list:
        for name in METRICS:
            limits = budget.get(name)
            out(f"{name}: soft {_limit(limits, 'soft')} s, hard {_limit(limits, 'hard')} s - {what(name)}")
        return 0
    names = list(METRICS)
    if args.only:
        names = [n.strip() for n in args.only.split(",") if n.strip()]
        unknown = [n for n in names if n not in METRICS]
        if unknown:
            parser.error(f"--only: no metric {', '.join(unknown)} (there are {', '.join(METRICS)})")
    if args.runs < 1:
        parser.error("--runs: at least 1")
    out(f"clock: {CLOCK_NAME} ({'CPU seconds' if CLOCK_NAME == 'process_time' else 'wall seconds: process_time ticks too coarsely here'})")
    results = measure(names, args.runs, budget, require_pygame=os.environ.get(REQUIRE_VAR) == "1", out=out)
    memory, rows = None, []
    if not args.no_memory and not args.only:
        memory = cache_memory()
        try:
            rows = render_cache_rows()
        except Skip:
            pass
    out("")
    out(text_table(results, memory))
    if rows:
        out(cache_text(rows))
    write_step_summary(markdown(results, memory, args.runs) + (cache_markdown(rows) if rows else ""))
    failed = [r for r in results if r.failed]
    for r in failed:
        out(f"FAILED: {r.name} took {r.median:.3f} s, over its hard limit of {r.limits['hard']:g} s. "
            f"Replay: python -m tools.perf --only {r.name}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
